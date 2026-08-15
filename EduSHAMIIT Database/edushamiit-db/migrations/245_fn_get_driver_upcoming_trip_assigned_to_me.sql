-- ============================================================================
-- Migration: 245_fn_get_driver_upcoming_trip_assigned_to_me.sql
-- Description:
--   Updates `fn_get_driver_upcoming_trip` to properly resolve the next upcoming
--   trip assigned to the logged-in user / driver across:
--   1. Active/ongoing trips in 'in_progress' or 'paused' status
--   2. Schedules where the driver is a participant (schedule_participants)
--   3. Schedules where the route is assigned to the driver
--   4. Schedules where the driver is organizer or creator
-- ============================================================================

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
    v_est_mins NUMERIC := 30;
    v_trip_id UUID;
    v_route_id UUID;
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

    -- 1. Check for any ONGOING / ACTIVE Trip (in_progress or paused) for this driver / assigned to this driver
    SELECT vt.* INTO v_trip
    FROM public.vehicle_trips vt
    LEFT JOIN public.transport_routes tr ON tr.id = vt.route_id
    WHERE (
        (tr.driver_id IS NOT NULL AND (tr.driver_id = v_driver_id OR tr.driver_id = p_user_id))
        OR vt.schedule_id IN (
            SELECT sp.schedule_id FROM public.schedule_participants sp 
            WHERE sp.user_id = p_user_id OR sp.user_id = v_driver_id
        )
        OR vt.schedule_id IN (
            SELECT s_sub.id FROM public.schedules s_sub 
            WHERE s_sub.organizer_id = p_user_id OR s_sub.created_by = p_user_id
        )
    )
    AND vt.status IN ('in_progress', 'paused')
    ORDER BY vt.updated_at DESC
    LIMIT 1;

    -- 2. If no active in_progress or paused trip, find the next legitimate upcoming schedule assigned to this user / driver
    IF v_trip.id IS NULL THEN
        SELECT s.* INTO v_sched
        FROM public.schedules s
        LEFT JOIN public.transport_routes tr ON tr.id = s.route_id
        WHERE s.deleted_at IS NULL
          AND s.status NOT IN ('cancelled', 'completed')
          AND (s.end_time >= (NOW() - INTERVAL '15 minutes') OR s.start_time >= (NOW() - INTERVAL '15 minutes'))
          AND (
              -- Route assigned to driver
              (tr.driver_id IS NOT NULL AND (tr.driver_id = v_driver_id OR tr.driver_id = p_user_id))
              -- OR Assigned in schedule_participants
              OR s.id IN (
                  SELECT sp.schedule_id FROM public.schedule_participants sp 
                  WHERE sp.user_id = p_user_id OR sp.user_id = v_driver_id
              )
              -- OR Organizer / Creator
              OR s.organizer_id = p_user_id OR s.created_by = p_user_id
          )
        ORDER BY s.start_time ASC, s.created_at ASC
        LIMIT 1;

        IF v_sched.id IS NOT NULL THEN
            v_route_id := v_sched.route_id;
            IF v_route_id IS NULL THEN
                SELECT id INTO v_route_id
                FROM public.transport_routes
                WHERE driver_id = v_driver_id OR driver_id = p_user_id
                LIMIT 1;
            END IF;
            IF v_route_id IS NULL THEN
                SELECT id INTO v_route_id
                FROM public.transport_routes
                WHERE school_id = COALESCE(v_sched.school_id, p_school_id)
                LIMIT 1;
            END IF;
            IF v_route_id IS NULL THEN
                SELECT id INTO v_route_id
                FROM public.transport_routes
                LIMIT 1;
            END IF;

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
                    v_trip_id, COALESCE(v_sched.school_id, p_school_id), v_route_id,
                    (SELECT vehicle_id FROM public.transport_routes WHERE id = v_route_id LIMIT 1),
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
