-- Migration 235: Driver trip operations stored procedures to boost performance and reduce DB roundtrips

CREATE OR REPLACE FUNCTION public.fn_driver_start_trip(
    p_school_id UUID,
    p_route_id UUID,
    p_user_id UUID,
    p_trip_id UUID DEFAULT NULL,
    p_trip_type VARCHAR DEFAULT 'pickup'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_vehicle_id UUID;
    v_route_name TEXT;
    v_existing_trip RECORD;
    v_active_trip RECORD;
    v_actual_trip_id UUID;
    v_now TIMESTAMPTZ := NOW();
    v_students_count INT := 0;
    v_res_trip RECORD;
BEGIN
    -- 1. Validate route
    SELECT vehicle_id, route_name INTO v_vehicle_id, v_route_name
    FROM public.transport_routes
    WHERE id = p_route_id;

    IF v_vehicle_id IS NULL THEN
        RAISE EXCEPTION 'Route % not found or has no vehicle assigned', p_route_id;
    END IF;

    -- 2. If p_trip_id is passed, check existing trip or schedule
    IF p_trip_id IS NOT NULL THEN
        SELECT * INTO v_existing_trip
        FROM public.vehicle_trips
        WHERE id = p_trip_id OR schedule_id = p_trip_id
        ORDER BY created_at DESC LIMIT 1;

        IF v_existing_trip.id IS NOT NULL THEN
            v_actual_trip_id := v_existing_trip.id;

            -- Pause other in-progress trips for this vehicle
            UPDATE public.vehicle_trips
            SET status = 'paused', updated_at = v_now
            WHERE vehicle_id = v_vehicle_id AND status = 'in_progress' AND id != v_actual_trip_id;

            -- Start existing trip
            UPDATE public.vehicle_trips
            SET status = 'in_progress', actual_start = v_now, route_id = p_route_id, vehicle_id = v_vehicle_id, updated_at = v_now
            WHERE id = v_actual_trip_id;

            UPDATE public.transport_routes SET live_status = 'on_route', is_visible = TRUE WHERE id = p_route_id;
            UPDATE public.vehicles SET live_status = 'on_route', is_visible = TRUE WHERE id = v_vehicle_id;

            -- Ensure trip_stop_logs exist
            INSERT INTO public.trip_stop_logs (school_id, trip_id, stop_id, status)
            SELECT p_school_id, v_actual_trip_id, s.id, 'pending'
            FROM public.transport_route_stops s
            WHERE s.route_id = p_route_id
            ON CONFLICT (trip_id, stop_id) DO NOTHING;

            -- Ensure student_trip_logs exist
            INSERT INTO public.student_trip_logs (school_id, trip_id, student_id, stop_id, status)
            SELECT p_school_id, v_actual_trip_id, st.student_id, COALESCE(st.transport_stop_id, st.stop_id), 'yet_to_pick'
            FROM public.student_transport st
            WHERE st.transport_route_id = p_route_id OR st.route_id = p_route_id
            ON CONFLICT (trip_id, student_id) DO NOTHING;

            SELECT * INTO v_res_trip FROM public.vehicle_trips WHERE id = v_actual_trip_id;
            RETURN jsonb_build_object('success', true, 'message', 'Scheduled trip started successfully', 'data', to_jsonb(v_res_trip));
        END IF;
    END IF;

    -- 3. Check for existing in_progress or paused trips on this route
    SELECT * INTO v_active_trip
    FROM public.vehicle_trips
    WHERE route_id = p_route_id AND status IN ('in_progress', 'paused')
    ORDER BY created_at DESC LIMIT 1;

    IF v_active_trip.id IS NOT NULL THEN
        IF v_active_trip.status = 'paused' THEN
            UPDATE public.vehicle_trips SET status = 'paused', updated_at = v_now WHERE vehicle_id = v_vehicle_id AND status = 'in_progress' AND id != v_active_trip.id;
            UPDATE public.vehicle_trips SET status = 'in_progress', updated_at = v_now WHERE id = v_active_trip.id;
        END IF;
        UPDATE public.transport_routes SET live_status = 'on_route', is_visible = TRUE WHERE id = p_route_id;
        SELECT * INTO v_res_trip FROM public.vehicle_trips WHERE id = v_active_trip.id;
        RETURN jsonb_build_object('success', true, 'message', 'Resuming active trip', 'data', to_jsonb(v_res_trip));
    END IF;

    -- 4. Create brand new trip
    UPDATE public.vehicle_trips SET status = 'paused', updated_at = v_now WHERE vehicle_id = v_vehicle_id AND status = 'in_progress';

    SELECT COUNT(*) INTO v_students_count
    FROM public.student_transport
    WHERE transport_route_id = p_route_id OR route_id = p_route_id;

    v_actual_trip_id := COALESCE(p_trip_id, gen_random_uuid());

    INSERT INTO public.vehicle_trips (
        id, school_id, route_id, vehicle_id, trip_type, status,
        scheduled_start, actual_start, students_count, distance_km,
        bus_position_ratio, current_stop_index, elapsed_seconds, delay_minutes,
        incident_count, notes, updated_at
    ) VALUES (
        v_actual_trip_id, p_school_id, p_route_id, v_vehicle_id, COALESCE(p_trip_type, 'pickup'), 'in_progress',
        v_now, v_now, v_students_count, 0.0,
        0.0, 0, 0, 0,
        0, 'Trip started for route ' || COALESCE(v_route_name, ''), v_now
    );

    UPDATE public.transport_routes SET live_status = 'on_route', is_visible = TRUE WHERE id = p_route_id;
    UPDATE public.vehicles SET live_status = 'on_route', is_visible = TRUE WHERE id = v_vehicle_id;

    -- Populate stop logs
    INSERT INTO public.trip_stop_logs (school_id, trip_id, stop_id, status)
    SELECT p_school_id, v_actual_trip_id, s.id, 'pending'
    FROM public.transport_route_stops s
    WHERE s.route_id = p_route_id
    ON CONFLICT (trip_id, stop_id) DO NOTHING;

    -- Populate student trip logs
    INSERT INTO public.student_trip_logs (school_id, trip_id, student_id, stop_id, status)
    SELECT p_school_id, v_actual_trip_id, st.student_id, COALESCE(st.transport_stop_id, st.stop_id), 'yet_to_pick'
    FROM public.student_transport st
    WHERE st.transport_route_id = p_route_id OR st.route_id = p_route_id
    ON CONFLICT (trip_id, student_id) DO NOTHING;

    SELECT * INTO v_res_trip FROM public.vehicle_trips WHERE id = v_actual_trip_id;
    RETURN jsonb_build_object('success', true, 'message', 'Trip started successfully', 'data', to_jsonb(v_res_trip));
END;
$$;


CREATE OR REPLACE FUNCTION public.fn_driver_trip_action(
    p_trip_id UUID,
    p_action VARCHAR,
    p_payload JSONB DEFAULT '{}'::jsonb,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trip RECORD;
    v_route_id UUID;
    v_vehicle_id UUID;
    v_now TIMESTAMPTZ := NOW();
    v_total_stops INT;
    v_completed_stops INT;
    v_stop_id UUID;
    v_students JSONB;
    v_st JSONB;
    v_st_id UUID;
    v_st_status TEXT;
    v_st_stop_id UUID;
BEGIN
    SELECT * INTO v_trip FROM public.vehicle_trips WHERE id = p_trip_id;
    IF v_trip.id IS NULL THEN
        RAISE EXCEPTION 'Trip not found: %', p_trip_id;
    END IF;

    v_route_id := v_trip.route_id;
    v_vehicle_id := v_trip.vehicle_id;

    IF lower(p_action) = 'pause' THEN
        UPDATE public.vehicle_trips SET status = 'paused', updated_at = v_now WHERE id = p_trip_id;
        IF v_route_id IS NOT NULL THEN
            UPDATE public.transport_routes SET live_status = 'paused' WHERE id = v_route_id;
        END IF;
        RETURN jsonb_build_object('success', true, 'message', 'Trip paused');

    ELSIF lower(p_action) = 'resume' THEN
        IF v_vehicle_id IS NOT NULL THEN
            UPDATE public.vehicle_trips SET status = 'paused', updated_at = v_now WHERE vehicle_id = v_vehicle_id AND status = 'in_progress' AND id != p_trip_id;
        END IF;
        UPDATE public.vehicle_trips SET status = 'in_progress', updated_at = v_now WHERE id = p_trip_id;
        IF v_route_id IS NOT NULL THEN
            UPDATE public.transport_routes SET live_status = 'on_route' WHERE id = v_route_id;
        END IF;
        RETURN jsonb_build_object('success', true, 'message', 'Trip resumed');

    ELSIF lower(p_action) = 'end' THEN
        IF v_route_id IS NOT NULL THEN
            SELECT COUNT(*) INTO v_total_stops FROM public.transport_route_stops WHERE route_id = v_route_id AND (status IS NULL OR status != 'Deleted');
            IF v_total_stops > 0 THEN
                SELECT COUNT(*) INTO v_completed_stops FROM public.trip_stop_logs WHERE trip_id = p_trip_id AND status = 'completed';
                IF v_completed_stops < v_total_stops THEN
                    RETURN jsonb_build_object('success', false, 'message', 'Cannot end trip: Only ' || v_completed_stops || ' of ' || v_total_stops || ' stops are completed.');
                END IF;
            END IF;
        END IF;

        UPDATE public.vehicle_trips SET status = 'completed', actual_end = v_now, updated_at = v_now WHERE id = p_trip_id;
        IF v_route_id IS NOT NULL THEN
            UPDATE public.transport_routes SET live_status = 'completed' WHERE id = v_route_id;
        END IF;
        RETURN jsonb_build_object('success', true, 'message', 'Trip completed successfully');

    ELSIF lower(p_action) = 'batch_sync' THEN
        v_stop_id := (p_payload->>'stop_id')::UUID;
        v_students := p_payload->'students';

        -- 1. Update stop status if stop_id provided
        IF v_stop_id IS NOT NULL THEN
            INSERT INTO public.trip_stop_logs (school_id, trip_id, stop_id, status, actual_arrival, updated_at)
            VALUES (v_trip.school_id, p_trip_id, v_stop_id, 'completed', v_now, v_now)
            ON CONFLICT (trip_id, stop_id) DO UPDATE SET status = 'completed', actual_arrival = COALESCE(trip_stop_logs.actual_arrival, v_now), updated_at = v_now;
        END IF;

        -- 2. Update students trip logs in batch
        IF v_students IS NOT NULL AND jsonb_array_length(v_students) > 0 THEN
            FOR v_st IN SELECT * FROM jsonb_array_elements(v_students)
            LOOP
                v_st_id := (v_st->>'student_id')::UUID;
                v_st_status := v_st->>'status';
                v_st_stop_id := COALESCE((v_st->>'stop_id')::UUID, v_stop_id);

                IF v_st_id IS NOT NULL AND v_st_status IS NOT NULL THEN
                    INSERT INTO public.student_trip_logs (school_id, trip_id, student_id, stop_id, status, updated_at)
                    VALUES (v_trip.school_id, p_trip_id, v_st_id, v_st_stop_id, v_st_status, v_now)
                    ON CONFLICT (trip_id, student_id) DO UPDATE SET status = EXCLUDED.status, stop_id = COALESCE(EXCLUDED.stop_id, student_trip_logs.stop_id), updated_at = v_now;
                END IF;
            END LOOP;
        END IF;

        -- 3. Auto-complete trip if all stops completed
        IF v_route_id IS NOT NULL THEN
            SELECT COUNT(*) INTO v_total_stops FROM public.transport_route_stops WHERE route_id = v_route_id AND (status IS NULL OR status != 'Deleted');
            IF v_total_stops > 0 THEN
                SELECT COUNT(*) INTO v_completed_stops FROM public.trip_stop_logs WHERE trip_id = p_trip_id AND status = 'completed';
                IF v_completed_stops >= v_total_stops THEN
                    UPDATE public.vehicle_trips SET status = 'completed', actual_end = COALESCE(actual_end, v_now), updated_at = v_now WHERE id = p_trip_id;
                    UPDATE public.transport_routes SET live_status = 'completed' WHERE id = v_route_id;
                END IF;
            END IF;
        END IF;

        RETURN jsonb_build_object('success', true, 'message', 'Batch sync completed successfully');

    ELSE
        RETURN jsonb_build_object('success', false, 'message', 'Unknown trip action: ' || p_action);
    END IF;
END;
$$;


CREATE OR REPLACE FUNCTION public.fn_get_full_trip_state(p_trip_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trip JSONB;
    v_route JSONB;
    v_vehicle JSONB;
    v_stops JSONB;
    v_students JSONB;
    v_route_id UUID;
    v_vehicle_id UUID;
BEGIN
    -- 1. Fetch trip
    SELECT to_jsonb(t) INTO v_trip FROM public.vehicle_trips t WHERE t.id = p_trip_id;
    IF v_trip IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Trip not found');
    END IF;

    v_route_id := (v_trip->>'route_id')::UUID;
    v_vehicle_id := (v_trip->>'vehicle_id')::UUID;

    -- 2. Fetch route & vehicle
    IF v_route_id IS NOT NULL THEN
        SELECT to_jsonb(r) INTO v_route FROM public.transport_routes r WHERE r.id = v_route_id;
    END IF;

    IF v_vehicle_id IS NOT NULL THEN
        SELECT to_jsonb(v) INTO v_vehicle FROM public.vehicles v WHERE v.id = v_vehicle_id;
    END IF;

    -- 3. Fetch stops with trip_stop_logs status
    IF v_route_id IS NOT NULL THEN
        SELECT jsonb_agg(
            to_jsonb(s) || jsonb_build_object(
                'status', COALESCE(l.status, 'pending'),
                'actual_arrival', l.actual_arrival
            )
            ORDER BY s.stop_order
        ) INTO v_stops
        FROM public.transport_route_stops s
        LEFT JOIN public.trip_stop_logs l ON l.stop_id = s.id AND l.trip_id = p_trip_id
        WHERE s.route_id = v_route_id AND (s.status IS NULL OR s.status != 'Deleted');
    END IF;

    -- 4. Fetch assigned students with student_trip_logs status
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', st.student_id,
            'student_id', st.student_id,
            'full_name', COALESCE(p.full_name, 'Student'),
            'stop_id', COALESCE(stl.stop_id, st.transport_stop_id, st.stop_id),
            'status', COALESCE(stl.status, 'yet_to_pick'),
            'avatar_url', p.avatar_url,
            'roll_number', COALESCE(p.roll_number::text, '—'),
            'phone', COALESCE(p.phone, '—')
        )
    ) INTO v_students
    FROM public.student_transport st
    LEFT JOIN public.profiles p ON p.id = st.student_id
    LEFT JOIN public.student_trip_logs stl ON stl.student_id = st.student_id AND stl.trip_id = p_trip_id
    WHERE st.transport_route_id = v_route_id OR st.route_id = v_route_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'trip', v_trip,
            'route', COALESCE(v_route, '{}'::jsonb),
            'vehicle', COALESCE(v_vehicle, '{}'::jsonb),
            'stops', COALESCE(v_stops, '[]'::jsonb),
            'students', COALESCE(v_students, '[]'::jsonb)
        )
    );
END;
$$;
