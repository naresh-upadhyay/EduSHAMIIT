-- ============================================================================
-- Migration: 257_fix_timezone_updates_and_single_event_isolation.sql
-- Description:
--   1. Ensures non-recurring single events are always updated in place without
--      spawning duplicate child rows or corrupting start dates on timezone changes.
--   2. Ensures timezone changes accurately update start_time, end_time, and timezone.
--   3. Cleans up orphan / duplicate child rows created from single-event edits.
-- ============================================================================

-- Clean up any duplicate non-recurring child rows created on non-recurring parents
UPDATE public.schedules child
SET deleted_at = NOW(), updated_at = NOW()
FROM public.schedules parent
WHERE child.recurring_parent_id = parent.id
  AND parent.is_recurring = FALSE
  AND child.deleted_at IS NULL;

CREATE OR REPLACE FUNCTION public.fn_update_schedule(
    p_schedule_id uuid,
    p_school_id uuid,
    p_user_id uuid,
    p_data jsonb,
    p_recurrence_scope text DEFAULT 'entire_series'::text,
    p_target_instance_date date DEFAULT NULL::date
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_old public.schedules%ROWTYPE;
    v_updated public.schedules%ROWTYPE;
    v_target_series_id UUID;
    v_new_id UUID := gen_random_uuid();
    v_master_start TIMESTAMPTZ;
    v_master_end TIMESTAMPTZ;
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_tz TEXT;
    v_effective_scope TEXT := p_recurrence_scope;
    v_freq TEXT := 'none';
    v_interval INT := 1;
    v_end_type TEXT := 'never';
    v_end_count INT;
    v_end_date DATE;
    v_days JSONB := '[]'::jsonb;
    v_p_elem JSONB;
    v_r_elem JSONB;
    v_rem_elem JSONB;
    v_aud_type TEXT;
    v_target_roles JSONB := '[]'::jsonb;
    v_target_classes JSONB := '[]'::jsonb;
    v_target_users JSONB := '[]'::jsonb;
    v_duration INTERVAL;
    v_new_start TIMESTAMP WITH TIME ZONE;
    v_new_end TIMESTAMP WITH TIME ZONE;
    v_new_payload_start TIMESTAMP WITH TIME ZONE;
    v_new_payload_end TIMESTAMP WITH TIME ZONE;
    v_target_date DATE;
    v_rec_obj JSONB;
    v_has_recurrence_in_payload BOOLEAN := FALSE;
    v_status TEXT;
    v_cancel_reason TEXT;
BEGIN
    -- Fetch original schedule
    SELECT * INTO v_old FROM public.schedules WHERE id = p_schedule_id AND deleted_at IS NULL;
    IF v_old.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Schedule not found or deleted.');
    END IF;

    v_tz := COALESCE(p_data->>'timezone', v_old.timezone, 'Asia/Kolkata');
    
    -- Extract recurrence details robustly from nested 'recurrence' object or top-level keys
    IF jsonb_typeof(p_data->'recurrence') = 'object' THEN
        v_rec_obj := p_data->'recurrence';
        v_has_recurrence_in_payload := TRUE;
        v_freq := COALESCE(v_rec_obj->>'frequency', 'none');
        v_interval := COALESCE((v_rec_obj->>'interval')::INT, 1);
        v_days := COALESCE(v_rec_obj->'days_of_week', '[]'::jsonb);
        v_end_type := COALESCE(v_rec_obj->>'end_type', 'never');
        v_end_count := (v_rec_obj->>'end_count')::INT;
        IF v_rec_obj->>'end_date' IS NOT NULL AND v_rec_obj->>'end_date' != '' THEN
            v_end_date := (v_rec_obj->>'end_date')::DATE;
        END IF;
    ELSIF p_data->>'frequency' IS NOT NULL THEN
        v_has_recurrence_in_payload := TRUE;
        v_freq := p_data->>'frequency';
        v_interval := COALESCE((p_data->>'interval')::INT, 1);
        v_days := COALESCE(p_data->'days_of_week', '[]'::jsonb);
        v_end_type := COALESCE(p_data->>'end_type', 'never');
        v_end_count := (p_data->>'end_count')::INT;
        IF p_data->>'end_date' IS NOT NULL AND p_data->>'end_date' != '' THEN
            v_end_date := (p_data->>'end_date')::DATE;
        END IF;
    ELSIF p_data->>'is_recurring' IS NOT NULL AND (p_data->>'is_recurring')::BOOLEAN = FALSE THEN
        v_has_recurrence_in_payload := TRUE;
        v_freq := 'none';
    END IF;

    -- If target is a single non-recurring event and remains non-recurring, force entire_series scope
    IF NOT v_old.is_recurring AND v_old.recurring_parent_id IS NULL AND v_freq = 'none' THEN
        v_effective_scope := 'entire_series';
    END IF;

    -- If v_old is a recurring series, target series is v_old.id itself!
    -- If v_old is a single-event override row (not recurring), target series is its recurring_parent_id.
    IF v_old.is_recurring THEN
        v_target_series_id := v_old.id;
    ELSE
        v_target_series_id := COALESCE(v_old.recurring_parent_id, v_old.id);
    END IF;

    v_target_date := COALESCE(p_target_instance_date, v_old.original_instance_date, (v_old.start_time AT TIME ZONE v_tz)::DATE);

    v_status := COALESCE(p_data->>'status', v_old.status, 'scheduled');
    v_cancel_reason := COALESCE(p_data->>'cancellation_reason', v_old.cancellation_reason);

    -- Parse audience targets
    v_aud_type := COALESCE(p_data->>'audience_type', v_old.audience_type, 'individual');
    v_target_roles := COALESCE(p_data->'target_roles', v_old.target_roles, '[]'::jsonb);
    v_target_classes := COALESCE(p_data->'target_classes', v_old.target_classes, '[]'::jsonb);
    v_target_users := COALESCE(p_data->'target_user_ids', v_old.target_user_ids, '[]'::jsonb);

    -- If no recurrence was specified in payload, preserve existing recurrence rule from target series
    IF NOT v_has_recurrence_in_payload THEN
        SELECT frequency, interval, days_of_week, end_type, end_count, end_date
        INTO v_freq, v_interval, v_days, v_end_type, v_end_count, v_end_date
        FROM public.schedule_recurrence
        WHERE schedule_id = v_target_series_id;

        IF v_freq IS NULL THEN
            v_freq := CASE WHEN v_old.is_recurring THEN 'daily' ELSE 'none' END;
        END IF;
    END IF;

    -- Normalize days of week ONLY for weekly recurrence if empty (do NOT overwrite custom intervals!)
    IF v_freq = 'weekly' AND (v_days IS NULL OR jsonb_array_length(v_days) = 0) THEN
        v_days := jsonb_build_array(UPPER(SUBSTRING(to_char((COALESCE(v_old.start_time, NOW()) AT TIME ZONE v_tz), 'Day') FROM 1 FOR 2)));
    ELSIF v_freq = 'weekdays' THEN
        v_days := '["MO", "TU", "WE", "TH", "FR"]'::jsonb;
    END IF;

    -- ========================================================================
    -- 1. SCOPE: THIS EVENT ONLY ('this_event')
    -- ========================================================================
    IF v_effective_scope = 'this_event' AND v_target_date IS NOT NULL THEN
        v_duration := COALESCE(v_old.end_time - v_old.start_time, INTERVAL '1 hour');

        IF p_data->>'start_time' IS NOT NULL AND p_data->>'start_time' != '' THEN
            v_new_start := public.parse_tz_timestamp(p_data->>'start_time', v_tz);
        ELSE
            v_new_start := (v_target_date::TEXT || ' ' || to_char((v_old.start_time AT TIME ZONE v_tz)::TIME, 'HH24:MI:SS'))::TIMESTAMP AT TIME ZONE v_tz;
        END IF;

        IF p_data->>'end_time' IS NOT NULL AND p_data->>'end_time' != '' THEN
            v_new_end := public.parse_tz_timestamp(p_data->>'end_time', v_tz);
        ELSE
            v_new_end := v_new_start + v_duration;
        END IF;

        -- Insert override row on new date/time with original_instance_date pointing to v_target_date
        INSERT INTO public.schedules (
            id, school_id, calendar_id, route_id, title, description, schedule_type, category, color, priority,
            status, approval_status, cancellation_reason, cancelled_at, cancelled_by,
            start_time, end_time, is_all_day, timezone,
            location_name, location_address, building, room, virtual_meeting_url, virtual_meeting_provider,
            organizer_id, created_by, visibility, is_recurring, recurring_parent_id, original_instance_date,
            recurrence_exception_type, metadata, audience_type, target_roles, target_classes, target_user_ids, created_at, updated_at
        ) VALUES (
            v_new_id, p_school_id, COALESCE((p_data->>'calendar_id')::UUID, v_old.calendar_id),
            CASE WHEN p_data->>'route_id' IS NOT NULL AND p_data->>'route_id' != '' THEN (p_data->>'route_id')::UUID ELSE v_old.route_id END,
            COALESCE(p_data->>'title', v_old.title), COALESCE(p_data->>'description', v_old.description),
            COALESCE(p_data->>'schedule_type', v_old.schedule_type), COALESCE(p_data->>'category', v_old.category),
            COALESCE(p_data->>'color', v_old.color), COALESCE(p_data->>'priority', v_old.priority),
            v_status, COALESCE(p_data->>'approval_status', v_old.approval_status, 'approved'),
            v_cancel_reason,
            CASE WHEN v_status = 'cancelled' THEN NOW() ELSE NULL END,
            CASE WHEN v_status = 'cancelled' THEN p_user_id ELSE NULL END,
            v_new_start, v_new_end, COALESCE((p_data->>'is_all_day')::BOOLEAN, v_old.is_all_day),
            v_tz, COALESCE(p_data->>'location_name', v_old.location_name),
            COALESCE(p_data->>'location_address', v_old.location_address), COALESCE(p_data->>'building', v_old.building),
            COALESCE(p_data->>'room', v_old.room), COALESCE(p_data->>'virtual_meeting_url', v_old.virtual_meeting_url),
            COALESCE(p_data->>'virtual_meeting_provider', v_old.virtual_meeting_provider),
            v_old.organizer_id, p_user_id, COALESCE(p_data->>'visibility', v_old.visibility),
            FALSE, v_target_series_id, v_target_date, 'override',
            COALESCE(p_data->'metadata', v_old.metadata), v_aud_type, v_target_roles, v_target_classes, v_target_users, NOW(), NOW()
        ) RETURNING * INTO v_updated;

        -- Transfer existing vehicle_trips for this date to v_new_id and new date
        UPDATE public.vehicle_trips
        SET schedule_id = v_new_id,
            route_id = v_updated.route_id,
            vehicle_id = (SELECT vehicle_id FROM public.transport_routes WHERE id = v_updated.route_id),
            start_date = (v_new_start AT TIME ZONE v_tz)::DATE::TEXT,
            end_date = (v_new_end AT TIME ZONE v_tz)::DATE::TEXT,
            schedule_instance_date = (v_new_start AT TIME ZONE v_tz)::DATE,
            start_time = to_char(v_new_start AT TIME ZONE v_tz, 'HH12:MI AM'),
            end_time = to_char(v_new_end AT TIME ZONE v_tz, 'HH12:MI AM'),
            scheduled_start = v_new_start,
            status = CASE WHEN v_status = 'cancelled' THEN 'cancelled' ELSE status END,
            updated_at = NOW()
        WHERE (schedule_id = v_target_series_id OR schedule_id = p_schedule_id OR schedule_id IN (SELECT id FROM public.schedules WHERE recurring_parent_id = v_target_series_id))
          AND (schedule_instance_date = v_target_date OR start_date = v_target_date::TEXT);

        -- Exclude the original instance date from target series recurrence
        PERFORM public.exclude_recurring_occurrence(v_target_series_id, v_target_date);
        IF p_schedule_id != v_target_series_id THEN
            PERFORM public.exclude_recurring_occurrence(p_schedule_id, v_target_date);
        END IF;

        UPDATE public.schedules SET is_recurring = TRUE WHERE id = v_target_series_id;

        -- Soft delete ONLY previous single-event override rows for this date (NEVER recurring series!)
        UPDATE public.schedules
        SET deleted_at = NOW(), status = 'cancelled', updated_at = NOW()
        WHERE (recurring_parent_id = v_target_series_id OR recurring_parent_id = p_schedule_id OR id = p_schedule_id)
          AND (original_instance_date = v_target_date OR DATE(start_time AT TIME ZONE v_tz) = v_target_date)
          AND (recurrence_exception_type = 'override' OR is_recurring = FALSE)
          AND id != v_new_id;

        IF jsonb_array_length(COALESCE(p_data->'participants', '[]'::jsonb)) > 0 THEN
            FOR v_p_elem IN SELECT * FROM jsonb_array_elements(p_data->'participants') LOOP
                INSERT INTO public.schedule_participants (
                    id, schedule_id, user_id, target_role, target_department, target_class, target_section,
                    participant_type, participation_role, permission, rsvp_status, created_at
                ) VALUES (
                    gen_random_uuid(), v_new_id,
                    CASE WHEN v_p_elem->>'user_id' IS NOT NULL AND v_p_elem->>'user_id' != '' THEN (v_p_elem->>'user_id')::UUID ELSE NULL END,
                    v_p_elem->>'target_role', v_p_elem->>'target_department', v_p_elem->>'target_class', v_p_elem->>'target_section',
                    COALESCE(v_p_elem->>'participant_type', 'individual'),
                    COALESCE(v_p_elem->>'participation_role', 'required'),
                    COALESCE(v_p_elem->>'permission', 'can_view'),
                    'pending', NOW()
                );
            END LOOP;
        END IF;

        IF jsonb_array_length(COALESCE(p_data->'resources', '[]'::jsonb)) > 0 THEN
            FOR v_r_elem IN SELECT * FROM jsonb_array_elements(p_data->'resources') LOOP
                IF v_r_elem->>'resource_id' IS NOT NULL AND v_r_elem->>'resource_id' != '' THEN
                    INSERT INTO public.resource_bookings (
                        id, schedule_id, resource_id, start_time, end_time, status, created_at
                    ) VALUES (
                        gen_random_uuid(), v_new_id, (v_r_elem->>'resource_id')::UUID, v_new_start, v_new_end, 'confirmed', NOW()
                    );
                END IF;
            END LOOP;
        END IF;

        IF jsonb_array_length(COALESCE(p_data->'reminders', '[]'::jsonb)) > 0 THEN
            FOR v_rem_elem IN SELECT * FROM jsonb_array_elements(p_data->'reminders') LOOP
                INSERT INTO public.schedule_reminders (
                    id, schedule_id, user_id, minutes_before, channel, is_sent, created_at
                ) VALUES (
                    gen_random_uuid(), v_new_id, p_user_id, COALESCE((v_rem_elem->>'minutes_before')::INT, 15),
                    COALESCE(v_rem_elem->>'channel', 'in_app'), FALSE, NOW()
                );
            END LOOP;
        END IF;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Updated this event occurrence successfully.', 'data', to_jsonb(v_updated));

    -- ========================================================================
    -- 2. SCOPE: THIS AND FOLLOWING EVENTS ('this_and_following' / 'following_events')
    -- ========================================================================
    ELSIF v_effective_scope IN ('this_and_following', 'following_events') AND v_target_date IS NOT NULL THEN
        v_duration := COALESCE(v_old.end_time - v_old.start_time, INTERVAL '1 hour');

        IF p_data->>'start_time' IS NOT NULL AND p_data->>'start_time' != '' THEN
            v_new_start := public.parse_tz_timestamp(p_data->>'start_time', v_tz);
        ELSE
            v_new_start := (v_target_date::TEXT || ' ' || to_char((v_old.start_time AT TIME ZONE v_tz)::TIME, 'HH24:MI:SS'))::TIMESTAMP AT TIME ZONE v_tz;
        END IF;

        IF p_data->>'end_time' IS NOT NULL AND p_data->>'end_time' != '' THEN
            v_new_end := public.parse_tz_timestamp(p_data->>'end_time', v_tz);
        ELSE
            v_new_end := v_new_start + v_duration;
        END IF;

        -- Calculate remaining after_count if inheriting count from master
        IF NOT v_has_recurrence_in_payload AND v_end_type = 'after_count' AND v_end_count IS NOT NULL THEN
            IF v_freq IN ('daily', 'custom') THEN
                v_end_count := GREATEST(1, v_end_count - ((v_target_date - (v_old.start_time AT TIME ZONE v_tz)::DATE) / GREATEST(1, v_interval))::INT);
            ELSIF v_freq = 'weekdays' THEN
                SELECT GREATEST(1, v_end_count - count(*)::INT) INTO v_end_count
                FROM generate_series((v_old.start_time AT TIME ZONE v_tz)::DATE, v_target_date - INTERVAL '1 day', INTERVAL '1 day') AS d
                WHERE EXTRACT(ISODOW FROM d) BETWEEN 1 AND 5;
            ELSIF v_freq = 'weekly' THEN
                SELECT GREATEST(1, v_end_count - count(*)::INT) INTO v_end_count
                FROM generate_series((v_old.start_time AT TIME ZONE v_tz)::DATE, v_target_date - INTERVAL '1 day', INTERVAL '1 day') AS d
                WHERE UPPER(SUBSTRING(to_char(d, 'Day') FROM 1 FOR 2)) = ANY(ARRAY(SELECT jsonb_array_elements_text(v_days)));
            END IF;
        END IF;

        INSERT INTO public.schedules (
            id, school_id, calendar_id, route_id, title, description, schedule_type, category, color, priority,
            status, approval_status, cancellation_reason, cancelled_at, cancelled_by,
            start_time, end_time, is_all_day, timezone,
            location_name, location_address, building, room, virtual_meeting_url, virtual_meeting_provider,
            organizer_id, created_by, visibility, is_recurring, recurring_parent_id, original_instance_date,
            recurrence_exception_type, metadata, audience_type, target_roles, target_classes, target_user_ids, created_at, updated_at
        ) VALUES (
            v_new_id, p_school_id, COALESCE((p_data->>'calendar_id')::UUID, v_old.calendar_id),
            CASE WHEN p_data->>'route_id' IS NOT NULL AND p_data->>'route_id' != '' THEN (p_data->>'route_id')::UUID ELSE v_old.route_id END,
            COALESCE(p_data->>'title', v_old.title), COALESCE(p_data->>'description', v_old.description),
            COALESCE(p_data->>'schedule_type', v_old.schedule_type), COALESCE(p_data->>'category', v_old.category),
            COALESCE(p_data->>'color', v_old.color), COALESCE(p_data->>'priority', v_old.priority),
            v_status, COALESCE(p_data->>'approval_status', v_old.approval_status, 'approved'),
            v_cancel_reason,
            CASE WHEN v_status = 'cancelled' THEN NOW() ELSE NULL END,
            CASE WHEN v_status = 'cancelled' THEN p_user_id ELSE NULL END,
            v_new_start, v_new_end, COALESCE((p_data->>'is_all_day')::BOOLEAN, v_old.is_all_day),
            v_tz, COALESCE(p_data->>'location_name', v_old.location_name),
            COALESCE(p_data->>'location_address', v_old.location_address), COALESCE(p_data->>'building', v_old.building),
            COALESCE(p_data->>'room', v_old.room), COALESCE(p_data->>'virtual_meeting_url', v_old.virtual_meeting_url),
            COALESCE(p_data->>'virtual_meeting_provider', v_old.virtual_meeting_provider),
            v_old.organizer_id, p_user_id, COALESCE(p_data->>'visibility', v_old.visibility),
            (v_freq != 'none'), v_target_series_id, NULL, 'none',
            COALESCE(p_data->'metadata', v_old.metadata), v_aud_type, v_target_roles, v_target_classes, v_target_users, NOW(), NOW()
        ) RETURNING * INTO v_updated;

        -- Transfer existing vehicle_trips from target_date onwards to v_new_id so trip_ids are preserved!
        UPDATE public.vehicle_trips
        SET schedule_id = v_new_id,
            route_id = v_updated.route_id,
            vehicle_id = (SELECT vehicle_id FROM public.transport_routes WHERE id = v_updated.route_id),
            status = CASE WHEN v_status = 'cancelled' THEN 'cancelled' ELSE status END,
            updated_at = NOW()
        WHERE (schedule_id = v_target_series_id OR schedule_id = p_schedule_id OR schedule_id IN (SELECT id FROM public.schedules WHERE recurring_parent_id = v_target_series_id))
          AND (schedule_instance_date >= v_target_date OR start_date >= v_target_date::TEXT);

        UPDATE public.schedule_recurrence
        SET end_type = 'until_date',
            end_date = v_target_date - INTERVAL '1 day',
            updated_at = NOW()
        WHERE schedule_id = v_target_series_id OR schedule_id = p_schedule_id;

        -- Soft delete ONLY previous override rows from target_date onwards (NEVER recurring series!)
        UPDATE public.schedules
        SET deleted_at = NOW(), status = 'cancelled', updated_at = NOW()
        WHERE (recurring_parent_id = v_target_series_id OR recurring_parent_id = p_schedule_id)
          AND (original_instance_date >= v_target_date OR DATE(start_time AT TIME ZONE v_tz) >= v_target_date)
          AND (recurrence_exception_type = 'override' OR is_recurring = FALSE)
          AND id != v_new_id;

        IF v_freq != 'none' THEN
            INSERT INTO public.schedule_recurrence (
                id, schedule_id, frequency, interval, days_of_week, end_type, end_count, end_date, exceptions, created_at, updated_at
            ) VALUES (
                gen_random_uuid(), v_new_id, v_freq, v_interval, v_days, v_end_type, v_end_count, v_end_date, '[]'::jsonb, NOW(), NOW()
            );
        END IF;

        IF jsonb_array_length(COALESCE(p_data->'participants', '[]'::jsonb)) > 0 THEN
            FOR v_p_elem IN SELECT * FROM jsonb_array_elements(p_data->'participants') LOOP
                INSERT INTO public.schedule_participants (
                    id, schedule_id, user_id, target_role, target_department, target_class, target_section,
                    participant_type, participation_role, permission, rsvp_status, created_at
                ) VALUES (
                    gen_random_uuid(), v_new_id,
                    CASE WHEN v_p_elem->>'user_id' IS NOT NULL AND v_p_elem->>'user_id' != '' THEN (v_p_elem->>'user_id')::UUID ELSE NULL END,
                    v_p_elem->>'target_role', v_p_elem->>'target_department', v_p_elem->>'target_class', v_p_elem->>'target_section',
                    COALESCE(v_p_elem->>'participant_type', 'individual'),
                    COALESCE(v_p_elem->>'participation_role', 'required'),
                    COALESCE(v_p_elem->>'permission', 'can_view'),
                    'pending', NOW()
                );
            END LOOP;
        END IF;

        IF jsonb_array_length(COALESCE(p_data->'resources', '[]'::jsonb)) > 0 THEN
            FOR v_r_elem IN SELECT * FROM jsonb_array_elements(p_data->'resources') LOOP
                IF v_r_elem->>'resource_id' IS NOT NULL AND v_r_elem->>'resource_id' != '' THEN
                    INSERT INTO public.resource_bookings (
                        id, schedule_id, resource_id, start_time, end_time, status, created_at
                    ) VALUES (
                        gen_random_uuid(), v_new_id, (v_r_elem->>'resource_id')::UUID, v_new_start, v_new_end, 'confirmed', NOW()
                    );
                END IF;
            END LOOP;
        END IF;

        IF jsonb_array_length(COALESCE(p_data->'reminders', '[]'::jsonb)) > 0 THEN
            FOR v_rem_elem IN SELECT * FROM jsonb_array_elements(p_data->'reminders') LOOP
                INSERT INTO public.schedule_reminders (
                    id, schedule_id, user_id, minutes_before, channel, is_sent, created_at
                ) VALUES (
                    gen_random_uuid(), v_new_id, p_user_id, COALESCE((v_rem_elem->>'minutes_before')::INT, 15),
                    COALESCE(v_rem_elem->>'channel', 'in_app'), FALSE, NOW()
                );
            END LOOP;
        END IF;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Updated this and following events successfully.', 'data', to_jsonb(v_updated));

    -- ========================================================================
    -- 3. SCOPE: ALL EVENTS IN SERIES ('all_events' / 'entire_series') OR SINGLE EVENT
    -- ========================================================================
    ELSE
        SELECT start_time, end_time INTO v_master_start, v_master_end
        FROM public.schedules
        WHERE id = v_target_series_id;

        IF v_master_start IS NULL THEN
            v_master_start := v_old.start_time;
            v_master_end := v_old.end_time;
        END IF;

        IF p_data->>'start_time' IS NOT NULL AND p_data->>'start_time' != '' THEN
            v_new_payload_start := public.parse_tz_timestamp(p_data->>'start_time', v_tz);
            IF p_data->>'end_time' IS NOT NULL AND p_data->>'end_time' != '' THEN
                v_new_payload_end := public.parse_tz_timestamp(p_data->>'end_time', v_tz);
            ELSE
                v_new_payload_end := v_new_payload_start + COALESCE(v_master_end - v_master_start, INTERVAL '1 hour');
            END IF;
            v_duration := COALESCE(v_new_payload_end - v_new_payload_start, v_master_end - v_master_start, INTERVAL '1 hour');

            IF NOT v_old.is_recurring THEN
                -- Single non-recurring event: update start and end time directly to new timezone
                v_start_time := v_new_payload_start;
                v_end_time := v_new_payload_end;
            ELSIF v_old.timezone != v_tz OR (v_master_start AT TIME ZONE v_old.timezone)::DATE = (v_new_payload_start AT TIME ZONE v_tz)::DATE THEN
                -- Master start date or timezone changed for recurring series:
                v_start_time := v_new_payload_start;
                v_end_time := v_new_payload_end;
            ELSE
                -- Future instance clicked (e.g. Day 3) in same timezone: preserve Day 1 start date
                v_start_time := (((v_master_start AT TIME ZONE v_tz)::DATE)::TEXT || ' ' || to_char((v_new_payload_start AT TIME ZONE v_tz)::TIME, 'HH24:MI:SS'))::TIMESTAMP AT TIME ZONE v_tz;
                v_end_time := v_start_time + v_duration;
            END IF;
        ELSE
            v_start_time := v_master_start;
            v_end_time := v_master_end;
        END IF;

        -- Update the targeted schedule series (v_target_series_id)
        UPDATE public.schedules
        SET calendar_id = COALESCE((p_data->>'calendar_id')::UUID, calendar_id),
            title = COALESCE(p_data->>'title', title),
            description = COALESCE(p_data->>'description', description),
            schedule_type = COALESCE(p_data->>'schedule_type', schedule_type),
            category = COALESCE(p_data->>'category', category),
            color = COALESCE(p_data->>'color', color),
            priority = COALESCE(p_data->>'priority', priority),
            status = v_status,
            approval_status = COALESCE(p_data->>'approval_status', approval_status),
            cancellation_reason = v_cancel_reason,
            cancelled_at = CASE WHEN v_status = 'cancelled' THEN NOW() ELSE cancelled_at END,
            cancelled_by = CASE WHEN v_status = 'cancelled' THEN p_user_id ELSE cancelled_by END,
            start_time = v_start_time,
            end_time = v_end_time,
            is_all_day = COALESCE((p_data->>'is_all_day')::BOOLEAN, is_all_day),
            timezone = v_tz,
            location_name = COALESCE(p_data->>'location_name', location_name),
            location_address = COALESCE(p_data->>'location_address', location_address),
            building = COALESCE(p_data->>'building', building),
            room = COALESCE(p_data->>'room', room),
            virtual_meeting_url = COALESCE(p_data->>'virtual_meeting_url', virtual_meeting_url),
            virtual_meeting_provider = COALESCE(p_data->>'virtual_meeting_provider', virtual_meeting_provider),
            visibility = COALESCE(p_data->>'visibility', visibility),
            is_recurring = (v_freq != 'none'),
            route_id = CASE WHEN p_data->>'route_id' IS NOT NULL AND p_data->>'route_id' != '' THEN (p_data->>'route_id')::UUID ELSE route_id END,
            metadata = COALESCE(p_data->'metadata', metadata),
            audience_type = v_aud_type,
            target_roles = v_target_roles,
            target_classes = v_target_classes,
            target_user_ids = v_target_users,
            updated_at = NOW()
        WHERE id = v_target_series_id
        RETURNING * INTO v_updated;

        -- If status is cancelled, also update child overrides and trips of this specific series
        IF v_status = 'cancelled' THEN
            UPDATE public.schedules
            SET status = 'cancelled',
                cancellation_reason = v_cancel_reason,
                cancelled_at = NOW(),
                cancelled_by = p_user_id,
                updated_at = NOW()
            WHERE recurring_parent_id = v_target_series_id;

            UPDATE public.vehicle_trips
            SET status = 'cancelled', updated_at = NOW()
            WHERE schedule_id = v_target_series_id
               OR schedule_id IN (SELECT id FROM public.schedules WHERE recurring_parent_id = v_target_series_id);
        END IF;

        -- Update vehicle trips for single event or series start
        UPDATE public.vehicle_trips
        SET route_id = v_updated.route_id,
            vehicle_id = (SELECT vehicle_id FROM public.transport_routes WHERE id = v_updated.route_id),
            start_date = (v_start_time AT TIME ZONE v_tz)::DATE::TEXT,
            end_date = (v_end_time AT TIME ZONE v_tz)::DATE::TEXT,
            schedule_instance_date = (v_start_time AT TIME ZONE v_tz)::DATE,
            start_time = to_char(v_start_time AT TIME ZONE v_tz, 'HH12:MI AM'),
            end_time = to_char(v_end_time AT TIME ZONE v_tz, 'HH12:MI AM'),
            scheduled_start = v_start_time,
            status = CASE WHEN v_status = 'cancelled' THEN 'cancelled' ELSE status END,
            updated_at = NOW()
        WHERE schedule_id = v_target_series_id
          AND (schedule_instance_date = (v_old.start_time AT TIME ZONE v_old.timezone)::DATE OR schedule_instance_date = (v_start_time AT TIME ZONE v_tz)::DATE OR v_old.is_recurring = FALSE);

        -- Update or insert recurrence details for this specific series while PRESERVING exceptions
        IF v_freq != 'none' THEN
            IF EXISTS (SELECT 1 FROM public.schedule_recurrence WHERE schedule_id = v_target_series_id) THEN
                UPDATE public.schedule_recurrence
                SET frequency = v_freq,
                    interval = v_interval,
                    days_of_week = v_days,
                    end_type = v_end_type,
                    end_count = v_end_count,
                    end_date = v_end_date,
                    exceptions = COALESCE(exceptions, '[]'::jsonb),
                    updated_at = NOW()
                WHERE schedule_id = v_target_series_id;
            ELSE
                INSERT INTO public.schedule_recurrence (
                    id, schedule_id, frequency, interval, days_of_week, end_type, end_count, end_date, exceptions, created_at, updated_at
                ) VALUES (
                    gen_random_uuid(), v_target_series_id, v_freq, v_interval, v_days, v_end_type, v_end_count, v_end_date, '[]'::jsonb, NOW(), NOW()
                );
            END IF;
        ELSE
            DELETE FROM public.schedule_recurrence WHERE schedule_id = v_target_series_id;
        END IF;

        -- Update participants
        IF jsonb_array_length(COALESCE(p_data->'participants', '[]'::jsonb)) > 0 THEN
            DELETE FROM public.schedule_participants WHERE schedule_id = v_target_series_id;
            FOR v_p_elem IN SELECT * FROM jsonb_array_elements(p_data->'participants') LOOP
                INSERT INTO public.schedule_participants (
                    id, schedule_id, user_id, target_role, target_department, target_class, target_section,
                    participant_type, participation_role, permission, rsvp_status, created_at
                ) VALUES (
                    gen_random_uuid(), v_target_series_id,
                    CASE WHEN v_p_elem->>'user_id' IS NOT NULL AND v_p_elem->>'user_id' != '' THEN (v_p_elem->>'user_id')::UUID ELSE NULL END,
                    v_p_elem->>'target_role', v_p_elem->>'target_department', v_p_elem->>'target_class', v_p_elem->>'target_section',
                    COALESCE(v_p_elem->>'participant_type', 'individual'),
                    COALESCE(v_p_elem->>'participation_role', 'required'),
                    COALESCE(v_p_elem->>'permission', 'can_view'),
                    'pending', NOW()
                );
            END LOOP;
        END IF;

        -- Update resources
        IF jsonb_array_length(COALESCE(p_data->'resources', '[]'::jsonb)) > 0 THEN
            DELETE FROM public.resource_bookings WHERE schedule_id = v_target_series_id;
            FOR v_r_elem IN SELECT * FROM jsonb_array_elements(p_data->'resources') LOOP
                IF v_r_elem->>'resource_id' IS NOT NULL AND v_r_elem->>'resource_id' != '' THEN
                    INSERT INTO public.resource_bookings (
                        id, schedule_id, resource_id, start_time, end_time, status, created_at
                    ) VALUES (
                        gen_random_uuid(), v_target_series_id, (v_r_elem->>'resource_id')::UUID, v_start_time, v_end_time, 'confirmed', NOW()
                    );
                END IF;
            END LOOP;
        END IF;

        -- Update reminders
        IF jsonb_array_length(COALESCE(p_data->'reminders', '[]'::jsonb)) > 0 THEN
            DELETE FROM public.schedule_reminders WHERE schedule_id = v_target_series_id;
            FOR v_rem_elem IN SELECT * FROM jsonb_array_elements(p_data->'reminders') LOOP
                INSERT INTO public.schedule_reminders (
                    id, schedule_id, user_id, minutes_before, channel, is_sent, created_at
                ) VALUES (
                    gen_random_uuid(), v_target_series_id, p_user_id, COALESCE((v_rem_elem->>'minutes_before')::INT, 15),
                    COALESCE(v_rem_elem->>'channel', 'in_app'), FALSE, NOW()
                );
            END LOOP;
        END IF;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Schedule series updated successfully.', 'data', to_jsonb(v_updated));
    END IF;
END;
$function$;
