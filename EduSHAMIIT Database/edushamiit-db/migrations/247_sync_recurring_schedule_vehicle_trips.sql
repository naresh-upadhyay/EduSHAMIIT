-- ============================================================================
-- Migration: 247_sync_recurring_schedule_vehicle_trips.sql
-- Description:
--   1. Implements fn_sync_schedule_vehicle_trips to generate distinct vehicle_trips
--      with unique trip_ids for every occurrence day of recurring schedules.
--   2. Ensures proper timezone conversion (Asia/Kolkata / schedule timezone).
--   3. Implements triggers to auto-generate, update, and cascade-delete vehicle_trips
--      when schedules or recurrences are created, updated, soft-deleted, or hard-deleted.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_sync_schedule_vehicle_trips(p_schedule_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sched public.schedules%ROWTYPE;
    v_route public.transport_routes%ROWTYPE;
    v_rec public.schedule_recurrence%ROWTYPE;
    v_tz TEXT;
    v_local_start TIMESTAMP;
    v_local_end TIMESTAMP;
    v_start_time_str TEXT;
    v_end_time_str TEXT;
    v_trip_type TEXT;
    v_cur_date DATE;
    v_end_horizon DATE;
    v_max_count INT := 1000;
    v_gen_count INT := 0;
    v_interval INT := 1;
    v_freq TEXT := 'daily';
    v_end_type TEXT := 'never';
    v_days_of_week JSONB;
    v_exceptions JSONB;
    v_exc_text TEXT[];
    v_valid_dates DATE[] := ARRAY[]::DATE[];
    v_should_create BOOLEAN;
    v_wkday INT; -- 0=Sun, 1=Mon, ..., 6=Sat in Postgres extract(DOW) or 1=Mon..7=Sun in isodow
    v_inst_utc_start TIMESTAMPTZ;
    v_existing_id UUID;
BEGIN
    -- 1. Fetch schedule
    SELECT * INTO v_sched FROM public.schedules WHERE id = p_schedule_id;

    -- If schedule does not exist, or is soft-deleted, or has no route_id, or is cancelled:
    IF v_sched.id IS NULL OR v_sched.deleted_at IS NOT NULL OR v_sched.status IN ('cancelled', 'declined') OR v_sched.route_id IS NULL THEN
        DELETE FROM public.vehicle_trips
        WHERE schedule_id = p_schedule_id
          AND status = 'scheduled';
        RETURN;
    END IF;

    -- 2. Fetch route & vehicle
    SELECT * INTO v_route FROM public.transport_routes WHERE id = v_sched.route_id;
    IF v_route.id IS NULL THEN
        DELETE FROM public.vehicle_trips WHERE schedule_id = p_schedule_id AND status = 'scheduled';
        RETURN;
    END IF;

    -- 3. Determine local timezone and formatting
    v_tz := COALESCE(NULLIF(v_sched.timezone, ''), 'Asia/Kolkata');
    v_local_start := v_sched.start_time AT TIME ZONE v_tz;
    v_local_end := v_sched.end_time AT TIME ZONE v_tz;
    v_start_time_str := to_char(v_local_start, 'HH12:MI AM');
    v_end_time_str := to_char(v_local_end, 'HH12:MI AM');

    v_trip_type := CASE 
        WHEN EXTRACT(HOUR FROM v_local_start) < 12 THEN 'morning'
        WHEN EXTRACT(HOUR FROM v_local_start) < 16 THEN 'afternoon'
        ELSE 'evening'
    END;

    -- 4. Check if single occurrence or recurring
    IF NOT COALESCE(v_sched.is_recurring, FALSE) THEN
        -- Single occurrence trip
        v_cur_date := v_local_start::DATE;
        v_valid_dates := ARRAY[v_cur_date];

        SELECT id INTO v_existing_id
        FROM public.vehicle_trips
        WHERE schedule_id = p_schedule_id
          AND (schedule_instance_date = v_cur_date OR start_date = v_cur_date::TEXT)
        LIMIT 1;

        IF v_existing_id IS NOT NULL THEN
            UPDATE public.vehicle_trips
            SET route_id = v_sched.route_id,
                vehicle_id = v_route.vehicle_id,
                trip_type = v_trip_type,
                start_time = v_start_time_str,
                end_time = v_end_time_str,
                start_date = v_cur_date::TEXT,
                end_date = v_cur_date::TEXT,
                schedule_instance_date = v_cur_date,
                scheduled_start = (v_cur_date + (v_local_start::TIME)) AT TIME ZONE v_tz,
                updated_at = NOW()
            WHERE id = v_existing_id;
        ELSE
            INSERT INTO public.vehicle_trips (
                id, school_id, route_id, vehicle_id, schedule_id,
                schedule_instance_date, start_date, start_time, end_date, end_time,
                trip_type, status, scheduled_start, created_at, updated_at
            ) VALUES (
                gen_random_uuid(), v_sched.school_id, v_sched.route_id, v_route.vehicle_id, p_schedule_id,
                v_cur_date, v_cur_date::TEXT, v_start_time_str, v_cur_date::TEXT, v_end_time_str,
                v_trip_type, 'scheduled', (v_cur_date + (v_local_start::TIME)) AT TIME ZONE v_tz, NOW(), NOW()
            );
        END IF;

        -- Clean any extra trips for other dates
        DELETE FROM public.vehicle_trips
        WHERE schedule_id = p_schedule_id
          AND status = 'scheduled'
          AND (schedule_instance_date != v_cur_date OR schedule_instance_date IS NULL);

        RETURN;
    END IF;

    -- 5. Handle Recurring Schedule
    SELECT * INTO v_rec FROM public.schedule_recurrence WHERE schedule_id = p_schedule_id;
    v_cur_date := v_local_start::DATE;
    v_end_horizon := v_cur_date + INTERVAL '120 days';

    IF v_rec.id IS NOT NULL THEN
        v_freq := lower(COALESCE(v_rec.frequency, 'daily'));
        v_interval := GREATEST(COALESCE(v_rec.interval, 1), 1);
        v_end_type := lower(COALESCE(v_rec.end_type, 'never'));
        v_days_of_week := COALESCE(v_rec.days_of_week, '[]'::jsonb);
        v_exceptions := COALESCE(v_rec.exceptions, '[]'::jsonb);

        IF v_end_type = 'after_count' AND v_rec.end_count IS NOT NULL AND v_rec.end_count > 0 THEN
            v_max_count := v_rec.end_count;
        ELSIF (v_end_type = 'until_date' OR v_end_type = 'on_date') AND v_rec.end_date IS NOT NULL THEN
            v_end_horizon := LEAST(v_end_horizon, v_rec.end_date);
        END IF;
    END IF;

    -- Build exception array
    IF jsonb_array_length(v_exceptions) > 0 THEN
        SELECT array_agg(trim(both '"' from elem::text)) INTO v_exc_text
        FROM jsonb_array_elements(v_exceptions) AS elem;
    END IF;

    -- Loop through potential occurrence dates
    WHILE v_cur_date <= v_end_horizon LOOP
        v_should_create := FALSE;
        v_wkday := EXTRACT(ISODOW FROM v_cur_date)::INT; -- 1=Mon .. 7=Sun

        -- Check frequency rules
        IF v_freq = 'daily' THEN
            IF (v_cur_date - v_local_start::DATE) % v_interval = 0 THEN
                v_should_create := TRUE;
            END IF;
        ELSIF v_freq = 'weekdays' THEN
            IF v_wkday IN (1, 2, 3, 4, 5) THEN
                v_should_create := TRUE;
            END IF;
        ELSIF v_freq = 'weekly' THEN
            IF ((v_cur_date - v_local_start::DATE) / 7) % v_interval = 0 THEN
                IF jsonb_array_length(v_days_of_week) > 0 THEN
                    -- Check if v_wkday is in days_of_week JSON (e.g. ["MO", "TU"] or [1, 2])
                    IF (v_wkday = 1 AND (v_days_of_week @> '["MO"]'::jsonb OR v_days_of_week @> '["MON"]'::jsonb OR v_days_of_week @> '["MONDAY"]'::jsonb OR v_days_of_week @> '[1]'::jsonb))
                       OR (v_wkday = 2 AND (v_days_of_week @> '["TU"]'::jsonb OR v_days_of_week @> '["TUE"]'::jsonb OR v_days_of_week @> '["TUESDAY"]'::jsonb OR v_days_of_week @> '[2]'::jsonb))
                       OR (v_wkday = 3 AND (v_days_of_week @> '["WE"]'::jsonb OR v_days_of_week @> '["WED"]'::jsonb OR v_days_of_week @> '["WEDNESDAY"]'::jsonb OR v_days_of_week @> '[3]'::jsonb))
                       OR (v_wkday = 4 AND (v_days_of_week @> '["TH"]'::jsonb OR v_days_of_week @> '["THU"]'::jsonb OR v_days_of_week @> '["THURSDAY"]'::jsonb OR v_days_of_week @> '[4]'::jsonb))
                       OR (v_wkday = 5 AND (v_days_of_week @> '["FR"]'::jsonb OR v_days_of_week @> '["FRI"]'::jsonb OR v_days_of_week @> '["FRIDAY"]'::jsonb OR v_days_of_week @> '[5]'::jsonb))
                       OR (v_wkday = 6 AND (v_days_of_week @> '["SA"]'::jsonb OR v_days_of_week @> '["SAT"]'::jsonb OR v_days_of_week @> '["SATURDAY"]'::jsonb OR v_days_of_week @> '[6]'::jsonb))
                       OR (v_wkday = 7 AND (v_days_of_week @> '["SU"]'::jsonb OR v_days_of_week @> '["SUN"]'::jsonb OR v_days_of_week @> '["SUNDAY"]'::jsonb OR v_days_of_week @> '[7]'::jsonb)) THEN
                        v_should_create := TRUE;
                    END IF;
                ELSE
                    IF v_wkday = EXTRACT(ISODOW FROM v_local_start)::INT THEN
                        v_should_create := TRUE;
                    END IF;
                END IF;
            END IF;
        ELSIF v_freq = 'custom' THEN
            IF jsonb_array_length(v_days_of_week) > 0 THEN
                IF ((v_cur_date - v_local_start::DATE) / 7) % v_interval = 0 THEN
                    IF (v_wkday = 1 AND (v_days_of_week @> '["MO"]'::jsonb OR v_days_of_week @> '["MON"]'::jsonb OR v_days_of_week @> '["MONDAY"]'::jsonb OR v_days_of_week @> '[1]'::jsonb))
                       OR (v_wkday = 2 AND (v_days_of_week @> '["TU"]'::jsonb OR v_days_of_week @> '["TUE"]'::jsonb OR v_days_of_week @> '["TUESDAY"]'::jsonb OR v_days_of_week @> '[2]'::jsonb))
                       OR (v_wkday = 3 AND (v_days_of_week @> '["WE"]'::jsonb OR v_days_of_week @> '["WED"]'::jsonb OR v_days_of_week @> '["WEDNESDAY"]'::jsonb OR v_days_of_week @> '[3]'::jsonb))
                       OR (v_wkday = 4 AND (v_days_of_week @> '["TH"]'::jsonb OR v_days_of_week @> '["THU"]'::jsonb OR v_days_of_week @> '["THURSDAY"]'::jsonb OR v_days_of_week @> '[4]'::jsonb))
                       OR (v_wkday = 5 AND (v_days_of_week @> '["FR"]'::jsonb OR v_days_of_week @> '["FRI"]'::jsonb OR v_days_of_week @> '["FRIDAY"]'::jsonb OR v_days_of_week @> '[5]'::jsonb))
                       OR (v_wkday = 6 AND (v_days_of_week @> '["SA"]'::jsonb OR v_days_of_week @> '["SAT"]'::jsonb OR v_days_of_week @> '["SATURDAY"]'::jsonb OR v_days_of_week @> '[6]'::jsonb))
                       OR (v_wkday = 7 AND (v_days_of_week @> '["SU"]'::jsonb OR v_days_of_week @> '["SUN"]'::jsonb OR v_days_of_week @> '["SUNDAY"]'::jsonb OR v_days_of_week @> '[7]'::jsonb)) THEN
                        v_should_create := TRUE;
                    END IF;
                END IF;
            ELSE
                IF (v_cur_date - v_local_start::DATE) % v_interval = 0 THEN
                    v_should_create := TRUE;
                END IF;
            END IF;
        ELSIF v_freq = 'monthly' THEN
            IF EXTRACT(DAY FROM v_cur_date) = EXTRACT(DAY FROM v_local_start) THEN
                v_should_create := TRUE;
            END IF;
        END IF;

        -- Check if excluded
        IF v_should_create AND v_exc_text IS NOT NULL AND v_cur_date::TEXT = ANY(v_exc_text) THEN
            v_should_create := FALSE;
        END IF;

        IF v_should_create THEN
            v_gen_count := v_gen_count + 1;
            IF v_end_type = 'after_count' AND v_gen_count > v_max_count THEN
                EXIT;
            END IF;

            v_valid_dates := array_append(v_valid_dates, v_cur_date);
            v_inst_utc_start := (v_cur_date + (v_local_start::TIME)) AT TIME ZONE v_tz;

            -- Check existing trip row for this specific occurrence date
            SELECT id INTO v_existing_id
            FROM public.vehicle_trips
            WHERE schedule_id = p_schedule_id
              AND (schedule_instance_date = v_cur_date OR start_date = v_cur_date::TEXT)
            LIMIT 1;

            IF v_existing_id IS NOT NULL THEN
                UPDATE public.vehicle_trips
                SET route_id = v_sched.route_id,
                    vehicle_id = v_route.vehicle_id,
                    trip_type = v_trip_type,
                    start_time = v_start_time_str,
                    end_time = v_end_time_str,
                    start_date = v_cur_date::TEXT,
                    end_date = v_cur_date::TEXT,
                    schedule_instance_date = v_cur_date,
                    scheduled_start = v_inst_utc_start,
                    updated_at = NOW()
                WHERE id = v_existing_id;
            ELSE
                INSERT INTO public.vehicle_trips (
                    id, school_id, route_id, vehicle_id, schedule_id,
                    schedule_instance_date, start_date, start_time, end_date, end_time,
                    trip_type, status, scheduled_start, created_at, updated_at
                ) VALUES (
                    gen_random_uuid(), v_sched.school_id, v_sched.route_id, v_route.vehicle_id, p_schedule_id,
                    v_cur_date, v_cur_date::TEXT, v_start_time_str, v_cur_date::TEXT, v_end_time_str,
                    v_trip_type, 'scheduled', v_inst_utc_start, NOW(), NOW()
                );
            END IF;
        END IF;

        v_cur_date := v_cur_date + INTERVAL '1 day';
    END LOOP;

    -- Delete any vehicle trips for dates that are no longer part of this recurring series
    DELETE FROM public.vehicle_trips
    WHERE schedule_id = p_schedule_id
      AND status = 'scheduled'
      AND (schedule_instance_date != ALL(v_valid_dates) OR schedule_instance_date IS NULL);

END;
$$;


-- Trigger function on public.schedules
CREATE OR REPLACE FUNCTION public.fn_trg_sync_schedule_vehicle_trips()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        DELETE FROM public.vehicle_trips WHERE schedule_id = OLD.id;
        RETURN OLD;
    END IF;

    -- Call sync function for NEW schedule
    PERFORM public.fn_sync_schedule_vehicle_trips(NEW.id);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_schedule_vehicle_trips ON public.schedules;
CREATE TRIGGER trg_sync_schedule_vehicle_trips
AFTER INSERT OR UPDATE OF route_id, start_time, end_time, is_recurring, status, deleted_at
ON public.schedules
FOR EACH ROW
EXECUTE FUNCTION public.fn_trg_sync_schedule_vehicle_trips();


-- Trigger function on public.schedule_recurrence
CREATE OR REPLACE FUNCTION public.fn_trg_sync_recurrence_vehicle_trips()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM public.fn_sync_schedule_vehicle_trips(OLD.schedule_id);
        RETURN OLD;
    END IF;

    PERFORM public.fn_sync_schedule_vehicle_trips(NEW.schedule_id);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_recurrence_vehicle_trips ON public.schedule_recurrence;
CREATE TRIGGER trg_sync_recurrence_vehicle_trips
AFTER INSERT OR UPDATE OR DELETE
ON public.schedule_recurrence
FOR EACH ROW
EXECUTE FUNCTION public.fn_trg_sync_recurrence_vehicle_trips();


-- Sync all existing recurring schedules with routes in the database right now!
DO $$
DECLARE
    v_s UUID;
BEGIN
    FOR v_s IN SELECT id FROM public.schedules WHERE route_id IS NOT NULL AND deleted_at IS NULL LOOP
        PERFORM public.fn_sync_schedule_vehicle_trips(v_s);
    END LOOP;
END;
$$;
