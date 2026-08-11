-- ============================================================================
-- Migration: 232_driver_trip_status_and_pause_constraints.sql
-- Description:
--   1. Ensures default status column constraint on `public.vehicle_trips` is 'scheduled'.
--   2. Updates `fn_get_driver_upcoming_trip` to properly handle 'scheduled', 'in_progress',
--      'paused', and 'completed' statuses without forced status overrides.
-- ============================================================================

-- 1. Table Constraints & Default Column Value
ALTER TABLE public.vehicle_trips 
ALTER COLUMN status SET DEFAULT 'scheduled';

UPDATE public.vehicle_trips
SET status = 'scheduled'
WHERE status IS NULL OR status = '';

-- 2. Updated Stored Function fn_get_driver_upcoming_trip
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

    -- Check for any ONGOING / ACTIVE Trip (in_progress or paused) for routes assigned to this driver
    SELECT vt.* INTO v_trip
    FROM public.vehicle_trips vt
    JOIN public.transport_routes tr ON tr.id = vt.route_id
    WHERE (tr.driver_id = v_driver_id OR tr.driver_id = p_user_id)
      AND vt.status IN ('in_progress', 'paused')
    ORDER BY vt.updated_at DESC
    LIMIT 1;

    -- If no active in_progress or paused trip, find the next legitimate schedule from public.schedules
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
            -- Ensure a synchronized vehicle_trips record exists and retains its current status
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
                -- Do NOT override status if already set by driver (scheduled, paused, in_progress, completed)
                IF v_trip.status IS NULL THEN
                    UPDATE public.vehicle_trips
                    SET status = 'scheduled',
                        updated_at = NOW()
                    WHERE id = v_trip.id
                    RETURNING * INTO v_trip;
                END IF;
            ELSE
                -- Insert missing trip for this schedule in 'scheduled' status
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
            'id', trs.id,
            'route_id', trs.route_id,
            'stop_name', trs.stop_name,
            'stop_order', trs.stop_order,
            'latitude', trs.latitude,
            'longitude', trs.longitude,
            'status', COALESCE(tsl.status, 'pending'),
            'actual_arrival', tsl.actual_arrival
        ) ORDER BY trs.stop_order ASC
    ), '[]'::jsonb) INTO v_stops
    FROM public.transport_route_stops trs
    LEFT JOIN public.trip_stop_logs tsl ON tsl.stop_id = trs.id AND tsl.trip_id = v_trip.id
    WHERE trs.route_id = v_trip.route_id AND trs.status != 'Deleted';

    -- Fetch Students assigned to this route
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'student_id', p.id,
            'full_name', p.full_name,
            'class_name', p.class,
            'roll_number', p.roll_number,
            'phone', p.phone,
            'avatar_url', p.avatar_url,
            'stop_id', st.transport_stop_id,
            'seat_no', st.seat_no,
            'status', COALESCE(stl.status, 'yet_to_pick'),
            'drop_stop_id', stl.drop_stop_id
        )
    ), '[]'::jsonb) INTO v_students
    FROM public.student_transport st
    JOIN public.profiles p ON p.id = st.student_id
    LEFT JOIN public.student_trip_logs stl ON stl.student_id = p.id AND stl.trip_id = v_trip.id
    WHERE st.transport_route_id = v_trip.route_id;

    -- Construct Result JSON
    v_result := jsonb_build_object(
        'trip', jsonb_build_object(
            'id', v_trip.id,
            'schedule_id', v_trip.schedule_id,
            'route_id', v_trip.route_id,
            'vehicle_id', v_trip.vehicle_id,
            'status', v_trip.status,
            'start_time', v_trip.start_time,
            'end_time', v_trip.end_time,
            'bus_position_ratio', COALESCE(v_trip.bus_position_ratio, 0.0),
            'current_stop_index', COALESCE(v_trip.current_stop_index, 0),
            'elapsed_seconds', COALESCE(v_trip.elapsed_seconds, 0),
            'distance_km', COALESCE(v_trip.distance_km, 0.0),
            'students_count', jsonb_array_length(v_students)
        ),
        'route', jsonb_build_object(
            'id', v_route.id,
            'route_name', v_route.route_name,
            'route_code', v_route.route_code,
            'start_time', COALESCE(v_route.start_time::text, '08:00 AM'),
            'end_time', COALESCE(v_route.end_time::text, '09:00 AM'),
            'travel_time_mins', v_est_mins,
            'bus_number', COALESCE(v_vehicle.bus_number, v_vehicle.registration_no, 'Assigned Bus'),
            'registration_no', COALESCE(v_vehicle.registration_no, v_vehicle.bus_number, 'Assigned Bus'),
            'assigned_bus', COALESCE(v_vehicle.bus_number, 'Assigned Bus')
        ),
        'stops', v_stops,
        'students', v_students
    );

    RETURN v_result;
END;
$$;
