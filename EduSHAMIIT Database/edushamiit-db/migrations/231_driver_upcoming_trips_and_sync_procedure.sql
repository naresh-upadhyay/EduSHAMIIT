-- ============================================================================
-- Migration: 231_driver_upcoming_trips_and_sync_procedure.sql
-- Description: 
--   1. Cleans up orphan and desynchronized past vehicle trips.
--   2. Provides high-performance database function `fn_get_driver_upcoming_trip`
--      that returns ONLY legitimate ongoing or future upcoming trips for the driver,
--      automatically auto-synchronizing `schedules` and `vehicle_trips`.
--   3. Adds database triggers on `schedules` to automatically cascade cancellation
--      and deletion to associated `vehicle_trips`.
-- ============================================================================

-- 0. ENSURE VEHICLE TRIPS COLUMNS EXIST
ALTER TABLE IF EXISTS public.vehicle_trips
  ADD COLUMN IF NOT EXISTS schedule_id UUID REFERENCES public.schedules(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS schedule_instance_date DATE;

CREATE INDEX IF NOT EXISTS idx_vehicle_trips_schedule_id ON public.vehicle_trips(schedule_id);

-- 1. CLEANUP ORPHAN & DESYNCHRONIZED TRIPS
DELETE FROM public.vehicle_trips vt
WHERE vt.schedule_id IS NOT NULL 
  AND vt.schedule_id NOT IN (
    SELECT id FROM public.schedules WHERE deleted_at IS NULL AND status != 'cancelled'
  );

-- 2. HIGH PERFORMANCE STORED FUNCTION FOR UPCOMING & ONGOING TRIPS
DROP FUNCTION IF EXISTS public.fn_get_driver_upcoming_trip(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.fn_get_driver_upcoming_trip(UUID) CASCADE;
CREATE OR REPLACE FUNCTION public.fn_get_driver_upcoming_trip(
    p_user_id UUID,
    p_school_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_driver_id UUID;
    v_trip RECORD;
    v_sched RECORD;
    v_route RECORD;
    v_vehicle RECORD;
    v_stops JSONB;
    v_students JSONB;
    v_result JSONB;
    v_today_date DATE := CURRENT_DATE;
    v_est_mins NUMERIC := 30;
    v_trip_id UUID;
    v_st_time_str TEXT;
    v_end_time_str TEXT;
    v_trip_type TEXT := 'morning';
BEGIN
    -- Resolve Driver ID
    SELECT id INTO v_driver_id
    FROM public.drivers
    WHERE id = p_user_id OR profile_id = p_user_id
    LIMIT 1;

    IF v_driver_id IS NULL THEN
        v_driver_id := p_user_id;
    END IF;

    -- Check for any ONGOING Trip (in_progress or paused) for routes assigned to this driver
    SELECT vt.* INTO v_trip
    FROM public.vehicle_trips vt
    JOIN public.transport_routes tr ON tr.id = vt.route_id
    WHERE (tr.driver_id = v_driver_id OR tr.driver_id = p_user_id)
      AND vt.status IN ('in_progress', 'paused')
    ORDER BY vt.updated_at DESC
    LIMIT 1;

    -- If no active trip, find the next legitimate UPCOMING schedule from public.schedules
    IF v_trip.id IS NULL THEN
        SELECT s.* INTO v_sched
        FROM public.schedules s
        JOIN public.transport_routes tr ON tr.id = s.route_id
        WHERE (tr.driver_id = v_driver_id OR tr.driver_id = p_user_id)
          AND s.status = 'scheduled'
          AND s.deleted_at IS NULL
          AND s.end_time >= (NOW() - INTERVAL '15 minutes')
        ORDER BY s.start_time ASC, s.created_at ASC
        LIMIT 1;

        IF v_sched.id IS NOT NULL THEN
            -- Ensure a synchronized vehicle_trips record exists and is in 'scheduled' status
            SELECT vt.* INTO v_trip
            FROM public.vehicle_trips vt
            WHERE vt.schedule_id = v_sched.id
            LIMIT 1;

            v_st_time_str := TO_CHAR(v_sched.start_time AT TIME ZONE 'UTC', 'HH12:MI AM');
            v_end_time_str := TO_CHAR(v_sched.end_time AT TIME ZONE 'UTC', 'HH12:MI AM');

            IF EXTRACT(HOUR FROM (v_sched.start_time AT TIME ZONE 'UTC')) >= 12 AND EXTRACT(HOUR FROM (v_sched.start_time AT TIME ZONE 'UTC')) < 16 THEN
                v_trip_type := 'afternoon';
            ELSIF EXTRACT(HOUR FROM (v_sched.start_time AT TIME ZONE 'UTC')) >= 16 THEN
                v_trip_type := 'evening';
            END IF;

            IF v_trip.id IS NOT NULL THEN
                -- If trip exists but status was wrongly marked completed/cancelled, reset it to scheduled to match active calendar schedule!
                IF v_trip.status NOT IN ('in_progress', 'paused') THEN
                    UPDATE public.vehicle_trips
                    SET status = 'scheduled',
                        route_id = v_sched.route_id,
                        schedule_instance_date = DATE(v_sched.start_time AT TIME ZONE 'UTC'),
                        start_date = DATE(v_sched.start_time AT TIME ZONE 'UTC')::text,
                        start_time = v_st_time_str,
                        end_time = v_end_time_str,
                        scheduled_start = v_sched.start_time,
                        updated_at = NOW()
                    WHERE id = v_trip.id
                    RETURNING * INTO v_trip;
                END IF;
            ELSE
                -- Insert missing trip for this schedule
                v_trip_id := gen_random_uuid();
                INSERT INTO public.vehicle_trips (
                    id, school_id, route_id, vehicle_id, schedule_id,
                    schedule_instance_date, start_date, start_time, end_date, end_time,
                    trip_type, status, scheduled_start, created_at, updated_at
                ) VALUES (
                    v_trip_id, COALESCE(v_sched.school_id, p_school_id), v_sched.route_id,
                    (SELECT vehicle_id FROM public.transport_routes WHERE id = v_sched.route_id LIMIT 1),
                    v_sched.id, DATE(v_sched.start_time AT TIME ZONE 'UTC'), DATE(v_sched.start_time AT TIME ZONE 'UTC')::text,
                    v_st_time_str, DATE(v_sched.end_time AT TIME ZONE 'UTC')::text, v_end_time_str,
                    v_trip_type, 'scheduled', v_sched.start_time, NOW(), NOW()
                )
                RETURNING * INTO v_trip;
            END IF;
        END IF;
    END IF;

    -- If still no trip found, return NULL
    IF v_trip.id IS NULL THEN
        RETURN NULL;
    END IF;

    -- Fetch Route Details
    SELECT tr.* INTO v_route
    FROM public.transport_routes tr
    WHERE tr.id = v_trip.route_id;

    -- Calculate estimated duration in minutes
    IF v_route.end_time IS NOT NULL AND v_route.start_time IS NOT NULL THEN
        v_est_mins := ROUND((EXTRACT(EPOCH FROM (v_route.end_time - v_route.start_time)) / 60)::numeric);
        IF v_est_mins <= 0 THEN
            v_est_mins := 30;
        END IF;
    END IF;

    -- Fetch Vehicle Details
    SELECT v.* INTO v_vehicle
    FROM public.vehicles v
    WHERE v.id = COALESCE(v_trip.vehicle_id, v_route.vehicle_id);

    -- Fetch Stops and Stop Logs
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', s.id,
            'route_id', s.route_id,
            'school_id', s.school_id,
            'stop_name', s.stop_name,
            'latitude', s.latitude,
            'longitude', s.longitude,
            'stop_order', s.stop_order,
            'estimated_arrival', s.estimated_arrival,
            'distance_from_prev_km', s.distance_from_prev_km,
            'travel_time_mins', s.travel_time_mins,
            'status', COALESCE(sl.status, 'pending'),
            'actual_arrival', sl.actual_arrival
        ) ORDER BY s.stop_order
    ), '[]'::jsonb) INTO v_stops
    FROM public.transport_route_stops s
    LEFT JOIN public.trip_stop_logs sl ON sl.stop_id = s.id AND sl.trip_id = v_trip.id
    WHERE s.route_id = v_trip.route_id;

    -- Fetch Students and Student Logs
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', st.student_id,
            'full_name', COALESCE(p.full_name, 'Student'),
            'class_name', COALESCE(p.class, 'N/A'),
            'roll_number', COALESCE(p.roll_number::text, ''),
            'phone', COALESCE(p.phone, ''),
            'avatar_url', p.avatar_url,
            'stop_id', st.transport_stop_id,
            'seat_no', st.seat_no,
            'status', COALESCE(stl.status, 'yet_to_pick'),
            'drop_stop_id', stl.drop_stop_id
        )
    ), '[]'::jsonb) INTO v_students
    FROM public.student_transport st
    LEFT JOIN public.profiles p ON p.id = st.student_id
    LEFT JOIN public.student_trip_logs stl ON stl.student_id = st.student_id AND stl.trip_id = v_trip.id
    WHERE st.transport_route_id = v_trip.route_id;

    -- Construct Full State JSON
    v_result := jsonb_build_object(
        'trip', to_jsonb(v_trip) || jsonb_build_object(
            'registration_no', COALESCE(v_vehicle.registration_no, v_vehicle.bus_number, 'Assigned Bus'),
            'bus_number', COALESCE(v_vehicle.bus_number, v_vehicle.registration_no, 'Assigned Bus')
        ),
        'route', to_jsonb(v_route) || jsonb_build_object(
            'registration_no', COALESCE(v_vehicle.registration_no, v_vehicle.bus_number, 'Assigned Bus'),
            'bus_number', COALESCE(v_vehicle.bus_number, v_vehicle.registration_no, 'Assigned Bus'),
            'assigned_bus', COALESCE(v_vehicle.registration_no, v_vehicle.bus_number, 'Assigned Bus'),
            'travel_time_mins', v_est_mins,
            'estimated_duration_mins', v_est_mins,
            'vehicles', to_jsonb(v_vehicle)
        ),
        'stops', v_stops,
        'students', v_students
    );

    RETURN v_result;
END;
$$;


-- 3. TRIGGERS ON SCHEDULES TO AUTOMATICALLY SYNC WITH VEHICLE TRIPS
CREATE OR REPLACE FUNCTION public.fn_trg_sync_schedule_cancellation_to_trips()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- If schedule deleted or cancelled, delete/cancel associated upcoming trips
    IF (NEW.deleted_at IS NOT NULL OR NEW.status = 'cancelled') AND (OLD.deleted_at IS NULL AND OLD.status != 'cancelled') THEN
        DELETE FROM public.vehicle_trips
        WHERE schedule_id = NEW.id AND status = 'scheduled';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_schedule_cancellation_to_trips ON public.schedules;
CREATE TRIGGER trg_sync_schedule_cancellation_to_trips
AFTER UPDATE OF deleted_at, status ON public.schedules
FOR EACH ROW
EXECUTE FUNCTION public.fn_trg_sync_schedule_cancellation_to_trips();

CREATE OR REPLACE FUNCTION public.fn_trg_sync_schedule_deletion_to_trips()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM public.vehicle_trips
    WHERE schedule_id = OLD.id AND status = 'scheduled';
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_schedule_deletion_to_trips ON public.schedules;
CREATE TRIGGER trg_sync_schedule_deletion_to_trips
AFTER DELETE ON public.schedules
FOR EACH ROW
EXECUTE FUNCTION public.fn_trg_sync_schedule_deletion_to_trips();
