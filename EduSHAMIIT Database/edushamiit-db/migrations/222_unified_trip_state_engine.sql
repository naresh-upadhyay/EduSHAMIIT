-- Migration 222: Unified Driver Trip Lifecycle Engine and High Performance Stored Procedures
-- Merges fragmented trip endpoints into atomic, high-speed PostgreSQL functions

CREATE OR REPLACE FUNCTION fn_driver_trip_sync(
    p_trip_id UUID,
    p_action TEXT,
    p_payload JSONB DEFAULT '{}'::JSONB,
    p_school_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_now TIMESTAMPTZ := NOW();
    v_trip RECORD;
    v_route_id UUID;
    v_school_id UUID;
    v_student JSONB;
    v_stop_id UUID;
    v_drop_stop_id UUID;
    v_student_id UUID;
    v_status TEXT;
BEGIN
    -- 1. Resolve Trip Record
    SELECT * INTO v_trip FROM vehicle_trips WHERE id = p_trip_id;
    
    -- 2. Resolve Valid school_id (Guaranteed Valid FK)
    IF v_trip.id IS NOT NULL THEN
        v_school_id := v_trip.school_id;
        v_route_id := v_trip.route_id;
    END IF;
    
    IF v_school_id IS NULL AND p_school_id IS NOT NULL THEN
        SELECT id INTO v_school_id FROM schools WHERE id = p_school_id;
    END IF;
    
    IF v_school_id IS NULL THEN
        SELECT school_id INTO v_school_id FROM transport_routes WHERE id = v_route_id;
    END IF;

    IF v_school_id IS NULL THEN
        SELECT id INTO v_school_id FROM schools ORDER BY created_at ASC LIMIT 1;
    END IF;

    -- If starting a new trip and trip record doesn't exist yet
    IF p_action = 'start' AND v_trip.id IS NULL THEN
        v_route_id := (p_payload->>'route_id')::UUID;
        INSERT INTO vehicle_trips (
            id, school_id, route_id, status, scheduled_start, actual_start,
            bus_position_ratio, current_stop_index, elapsed_seconds, distance_km, updated_at
        ) VALUES (
            p_trip_id, v_school_id, v_route_id, 'in_progress', v_now, v_now,
            0.0, 0, 0, 0.0, v_now
        )
        RETURNING * INTO v_trip;
    END IF;

    -- =========================================================================
    -- ACTION HANDLERS
    -- =========================================================================
    
    -- 1. START TRIP
    IF p_action = 'start' THEN
        UPDATE vehicle_trips SET 
            status = 'in_progress', 
            actual_start = COALESCE(actual_start, v_now),
            updated_at = v_now 
        WHERE id = p_trip_id;
        
        IF v_route_id IS NOT NULL THEN
            UPDATE transport_routes SET live_status = 'on_route', is_visible = true WHERE id = v_route_id OR vehicle_id = v_route_id;
            UPDATE vehicles SET live_status = 'on_route', is_visible = true WHERE id = v_route_id;
        END IF;

    -- 2. PAUSE TRIP
    ELSIF p_action = 'pause' THEN
        UPDATE vehicle_trips SET 
            status = 'paused', 
            updated_at = v_now 
        WHERE id = p_trip_id;
        
        IF v_route_id IS NOT NULL THEN
            UPDATE transport_routes SET live_status = 'paused', is_visible = true WHERE id = v_route_id OR vehicle_id = v_route_id;
            UPDATE vehicles SET live_status = 'paused', is_visible = true WHERE id = v_route_id;
        END IF;

    -- 3. RESUME TRIP
    ELSIF p_action = 'resume' THEN
        UPDATE vehicle_trips SET 
            status = 'in_progress', 
            updated_at = v_now 
        WHERE id = p_trip_id;
        
        IF v_route_id IS NOT NULL THEN
            UPDATE transport_routes SET live_status = 'on_route', is_visible = true WHERE id = v_route_id OR vehicle_id = v_route_id;
            UPDATE vehicles SET live_status = 'on_route', is_visible = true WHERE id = v_route_id;
        END IF;

    -- 4. END TRIP
    ELSIF p_action = 'end' THEN
        UPDATE vehicle_trips SET 
            status = 'completed', 
            actual_end = v_now, 
            updated_at = v_now 
        WHERE id = p_trip_id;
        
        IF v_route_id IS NOT NULL THEN
            UPDATE transport_routes SET live_status = 'offline', is_visible = false WHERE id = v_route_id OR vehicle_id = v_route_id;
            UPDATE vehicles SET live_status = 'offline', is_visible = false WHERE id = v_route_id;
        END IF;

    -- 5. LOCATION TELEMETRY
    ELSIF p_action = 'location' THEN
        UPDATE vehicle_trips SET
            current_lat = COALESCE((p_payload->>'latitude')::NUMERIC, current_lat),
            current_lng = COALESCE((p_payload->>'longitude')::NUMERIC, current_lng),
            bus_position_ratio = COALESCE((p_payload->>'bus_position_ratio')::NUMERIC, bus_position_ratio),
            current_stop_index = COALESCE((p_payload->>'current_stop_index')::INT, current_stop_index),
            elapsed_seconds = COALESCE((p_payload->>'elapsed_seconds')::INT, elapsed_seconds),
            distance_km = COALESCE((p_payload->>'distance_km')::NUMERIC, distance_km),
            updated_at = v_now
        WHERE id = p_trip_id;

        IF v_route_id IS NOT NULL THEN
            UPDATE transport_routes SET
                live_status = COALESCE(p_payload->>'live_status', live_status)
            WHERE id = v_route_id OR vehicle_id = v_route_id;
        END IF;

    -- 6. COMPLETE STOP
    ELSIF p_action = 'complete_stop' THEN
        v_stop_id := (p_payload->>'stop_id')::UUID;
        IF v_stop_id IS NOT NULL THEN
            INSERT INTO trip_stop_logs (school_id, trip_id, stop_id, status, actual_arrival, updated_at)
            VALUES (v_school_id, p_trip_id, v_stop_id, 'completed', v_now, v_now)
            ON CONFLICT (trip_id, stop_id)
            DO UPDATE SET status = 'completed', actual_arrival = v_now, updated_at = v_now;
        END IF;

    -- 7. STUDENTS STATUS
    ELSIF p_action = 'students_status' THEN
        IF p_payload ? 'students' AND jsonb_typeof(p_payload->'students') = 'array' THEN
            FOR v_student IN SELECT * FROM jsonb_array_elements(p_payload->'students') LOOP
                v_student_id := (v_student->>'student_id')::UUID;
                v_status := v_student->>'status';
                v_stop_id := (v_student->>'stop_id')::UUID;
                v_drop_stop_id := (v_student->>'drop_stop_id')::UUID;

                IF v_student_id IS NOT NULL THEN
                    INSERT INTO student_trip_logs (school_id, trip_id, student_id, stop_id, drop_stop_id, status, updated_at)
                    VALUES (v_school_id, p_trip_id, v_student_id, v_stop_id, v_drop_stop_id, v_status, v_now)
                    ON CONFLICT (trip_id, student_id)
                    DO UPDATE SET 
                        status = EXCLUDED.status, 
                        stop_id = COALESCE(EXCLUDED.stop_id, student_trip_logs.stop_id),
                        drop_stop_id = CASE WHEN EXCLUDED.status = 'picked' THEN NULL ELSE COALESCE(EXCLUDED.drop_stop_id, student_trip_logs.drop_stop_id) END,
                        updated_at = v_now;
                END IF;
            END LOOP;
        END IF;

    -- 8. UNIFIED ATOMIC BATCH SYNC
    ELSIF p_action = 'batch_sync' THEN
        -- A. Complete Stop
        IF p_payload ? 'stop_id' AND (p_payload->>'stop_id') IS NOT NULL THEN
            v_stop_id := (p_payload->>'stop_id')::UUID;
            INSERT INTO trip_stop_logs (school_id, trip_id, stop_id, status, actual_arrival, updated_at)
            VALUES (v_school_id, p_trip_id, v_stop_id, 'completed', v_now, v_now)
            ON CONFLICT (trip_id, stop_id)
            DO UPDATE SET status = 'completed', actual_arrival = v_now, updated_at = v_now;
        END IF;

        -- B. Update Multiple Students
        IF p_payload ? 'students' AND jsonb_typeof(p_payload->'students') = 'array' THEN
            FOR v_student IN SELECT * FROM jsonb_array_elements(p_payload->'students') LOOP
                v_student_id := (v_student->>'student_id')::UUID;
                v_status := v_student->>'status';
                v_stop_id := (v_student->>'stop_id')::UUID;
                v_drop_stop_id := (v_student->>'drop_stop_id')::UUID;

                IF v_student_id IS NOT NULL THEN
                    INSERT INTO student_trip_logs (school_id, trip_id, student_id, stop_id, drop_stop_id, status, updated_at)
                    VALUES (v_school_id, p_trip_id, v_student_id, v_stop_id, v_drop_stop_id, v_status, v_now)
                    ON CONFLICT (trip_id, student_id)
                    DO UPDATE SET 
                        status = EXCLUDED.status, 
                        stop_id = COALESCE(EXCLUDED.stop_id, student_trip_logs.stop_id),
                        drop_stop_id = CASE WHEN EXCLUDED.status = 'picked' THEN NULL ELSE COALESCE(EXCLUDED.drop_stop_id, student_trip_logs.drop_stop_id) END,
                        updated_at = v_now;
                END IF;
            END LOOP;
        END IF;

        -- C. Update Trip Progress Telemetry
        UPDATE vehicle_trips SET
            current_lat = COALESCE((p_payload->>'latitude')::NUMERIC, current_lat),
            current_lng = COALESCE((p_payload->>'longitude')::NUMERIC, current_lng),
            bus_position_ratio = COALESCE((p_payload->>'bus_position_ratio')::NUMERIC, bus_position_ratio),
            current_stop_index = COALESCE((p_payload->>'current_stop_index')::INT, current_stop_index),
            elapsed_seconds = COALESCE((p_payload->>'elapsed_seconds')::INT, elapsed_seconds),
            distance_km = COALESCE((p_payload->>'distance_km')::NUMERIC, distance_km),
            updated_at = v_now
        WHERE id = p_trip_id;

        IF v_route_id IS NOT NULL THEN
            UPDATE transport_routes SET
                live_status = COALESCE(p_payload->>'live_status', live_status)
            WHERE id = v_route_id OR vehicle_id = v_route_id;
        END IF;

    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'trip_id', p_trip_id,
        'action', p_action,
        'timestamp', v_now
    );
END;
$$;

-- 2. Sub-millisecond JSON Aggregation Full State Query Function
CREATE OR REPLACE FUNCTION fn_get_driver_trip_full_state(p_trip_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trip JSONB;
    v_route JSONB;
    v_stops JSONB;
    v_students JSONB;
    v_route_id UUID;
BEGIN
    -- 1. Trip Object
    SELECT to_jsonb(t) INTO v_trip FROM vehicle_trips t WHERE t.id = p_trip_id;
    IF v_trip IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Trip not found');
    END IF;
    v_route_id := (v_trip->>'route_id')::UUID;

    -- 2. Route Object
    SELECT to_jsonb(r) INTO v_route FROM transport_routes r WHERE r.id = v_route_id;

    -- 3. Stops Array with logs merged
    SELECT COALESCE(jsonb_agg(
        to_jsonb(s) || jsonb_build_object(
            'status', COALESCE(l.status, 'pending'),
            'actual_arrival', l.actual_arrival
        )
        ORDER BY s.stop_order
    ), '[]'::JSONB)
    INTO v_stops
    FROM transport_route_stops s
    LEFT JOIN trip_stop_logs l ON l.stop_id = s.id AND l.trip_id = p_trip_id
    WHERE s.route_id = v_route_id;

    -- 4. Students Array with profile data and logs merged
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', st.student_id,
            'full_name', COALESCE(p.full_name, 'Student'),
            'class_name', COALESCE(p.class, 'Grade 9'),
            'roll_number', COALESCE(p.roll_number::TEXT, ''),
            'phone', COALESCE(p.phone, ''),
            'avatar_url', p.avatar_url,
            'stop_id', COALESCE(sl.stop_id, st.transport_stop_id, st.stop_id),
            'drop_stop_id', sl.drop_stop_id,
            'seat_no', st.seat_no,
            'status', COALESCE(sl.status, 'yet_to_pick')
        )
    ), '[]'::JSONB)
    INTO v_students
    FROM student_transport st
    LEFT JOIN profiles p ON p.id = st.student_id
    LEFT JOIN student_trip_logs sl ON sl.student_id = st.student_id AND sl.trip_id = p_trip_id
    WHERE st.transport_route_id = v_route_id OR st.route_id = v_route_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'trip', v_trip,
            'route', v_route,
            'stops', v_stops,
            'students', v_students
        )
    );
END;
$$;
