-- Migration 568: Fix Space Booking Unique Reference Collision, Ambiguous Conflict Function, and Support Allow Conflict Submit Anyway
-- Date: 2026-11-22

-- 0. Drop ambiguous 5-argument overload of fn_space_booking_check_conflict
DROP FUNCTION IF EXISTS public.fn_space_booking_check_conflict(uuid, uuid, timestamp with time zone, timestamp with time zone, uuid);

-- 1. Fix fn_space_booking_create_recurring with Collision-Proof booking_ref and allow_conflict support
CREATE OR REPLACE FUNCTION public.fn_space_booking_create_recurring(p_payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_school_id UUID;
    v_user_id UUID;
    v_existing_booking_id UUID;
    v_title VARCHAR(250);
    v_desc TEXT;
    v_room_id UUID;
    v_building_id UUID;
    v_floor_id UUID;
    v_frequency VARCHAR(50);
    v_start_date DATE;
    v_end_date DATE;
    v_start_time TIME;
    v_end_time TIME;
    v_setup_min INT := 10;
    v_cleanup_min INT := 10;
    v_duration_min INT := 60;
    v_purpose VARCHAR(100);
    v_category VARCHAR(100);
    v_priority VARCHAR(50);
    v_organizer_name VARCHAR(250);
    v_organizer_role VARCHAR(100);
    v_organizer_email VARCHAR(250);
    v_organizer_phone VARCHAR(50);
    v_attendee_count INT := 30;
    v_interval INT := 1;
    v_end_type VARCHAR(50) := 'never';
    v_max_occurrences INT := 30;
    v_days_of_week INT[];
    v_series_id UUID;
    v_curr_date DATE;
    v_dow INT;
    v_created_count INT := 0;
    v_conflict_count INT := 0;
    v_booking_ref VARCHAR(50);
    v_existing_conflict INT;
    v_anchor_conflict INT := 0;
    v_should_book BOOLEAN;
    v_week_start_date DATE;
    v_allow_conflict BOOLEAN := FALSE;
BEGIN
    v_school_id := (p_payload->>'school_id')::UUID;
    v_user_id := (p_payload->>'user_id')::UUID;
    v_existing_booking_id := NULLIF(p_payload->>'existing_booking_id', '')::UUID;
    v_title := COALESCE(p_payload->>'title', p_payload->>'series_title', 'Recurring Class/Event Series');
    v_desc := p_payload->>'description';
    v_room_id := (p_payload->>'room_id')::UUID;
    v_frequency := LOWER(COALESCE(p_payload->>'frequency', 'weekly'));
    v_start_date := COALESCE((p_payload->>'start_date')::DATE, CURRENT_DATE);
    v_start_time := (p_payload->>'start_time')::TIME;
    v_end_time := (p_payload->>'end_time')::TIME;
    v_setup_min := COALESCE((p_payload->>'setup_minutes')::INT, 10);
    v_cleanup_min := COALESCE((p_payload->>'cleanup_minutes')::INT, 10);
    v_purpose := COALESCE(p_payload->>'purpose', 'Academic');
    v_category := COALESCE(p_payload->>'category', 'Academic');
    v_priority := COALESCE(p_payload->>'priority', 'Normal');
    v_organizer_name := COALESCE(p_payload->>'organizer_name', 'Faculty');
    v_organizer_role := COALESCE(p_payload->>'organizer_role', 'Faculty');
    v_organizer_email := p_payload->>'organizer_email';
    v_organizer_phone := p_payload->>'organizer_phone';
    v_attendee_count := COALESCE((p_payload->>'attendee_count')::INT, 30);
    v_interval := GREATEST(COALESCE((p_payload->>'interval')::INT, 1), 1);
    v_end_type := LOWER(COALESCE(p_payload->>'end_type', 'never'));
    v_max_occurrences := COALESCE((p_payload->>'max_occurrences')::INT, 30);
    v_allow_conflict := COALESCE((p_payload->>'allow_conflict')::BOOLEAN, FALSE);

    -- Calculate default end date based on end_type
    IF v_end_type = 'date' AND p_payload->>'until_date' IS NOT NULL THEN
        v_end_date := (p_payload->>'until_date')::DATE;
    ELSIF v_end_type = 'count' THEN
        v_max_occurrences := GREATEST(COALESCE((p_payload->>'count')::INT, v_max_occurrences), 1);
        IF v_frequency = 'daily' THEN
            v_end_date := v_start_date + (v_max_occurrences * v_interval + 7);
        ELSIF v_frequency IN ('weekly', 'weekdays', 'custom') THEN
            v_end_date := v_start_date + ((v_max_occurrences * v_interval * 7) + 14);
        ELSIF v_frequency = 'monthly' THEN
            v_end_date := v_start_date + ((v_max_occurrences * v_interval * 32) + 30);
        ELSE
            v_end_date := v_start_date + 365;
        END IF;
    ELSE
        -- 'never' repeats up to max 60 occurrences or 180 days
        v_max_occurrences := LEAST(v_max_occurrences, 60);
        v_end_date := COALESCE((p_payload->>'end_date')::DATE, v_start_date + 180);
    END IF;

    -- Validate user_id against profiles foreign key
    IF v_user_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user_id) THEN
        SELECT id INTO v_user_id FROM public.profiles WHERE role IN ('admin', 'super_admin', 'teacher') LIMIT 1;
    END IF;

    -- Duration in minutes
    v_duration_min := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) / 60;
    IF v_duration_min <= 0 THEN
        v_duration_min := 60;
    END IF;

    -- Lookup building and floor
    SELECT building_id, floor_id INTO v_building_id, v_floor_id
    FROM public.rooms
    WHERE id = v_room_id;

    -- Resolve days of week
    IF v_frequency = 'daily' THEN
        v_days_of_week := ARRAY[1, 2, 3, 4, 5, 6, 7];
    ELSIF v_frequency = 'weekdays' THEN
        v_days_of_week := ARRAY[1, 2, 3, 4, 5];
    ELSIF p_payload->'days_of_week' IS NOT NULL AND jsonb_array_length(p_payload->'days_of_week') > 0 THEN
        SELECT ARRAY_AGG(x::INT) INTO v_days_of_week FROM jsonb_array_elements_text(p_payload->'days_of_week') AS x;
    ELSE
        v_dow := EXTRACT(ISODOW FROM v_start_date)::INT;
        v_days_of_week := ARRAY[v_dow];
    END IF;

    -- Create Series Header
    INSERT INTO public.space_booking_recurring_series (
        school_id, title, recurrence_type, start_date, end_date, days_of_week, "interval", created_by
    ) VALUES (
        v_school_id, v_title, UPPER(v_frequency), v_start_date, v_end_date, v_days_of_week, v_interval, v_user_id
    ) RETURNING id INTO v_series_id;

    -- Handle existing booking conversion: Occurrence #1
    IF v_existing_booking_id IS NOT NULL THEN
        -- Check if anchor occurrence has conflict with other bookings
        SELECT COUNT(*) INTO v_anchor_conflict
        FROM public.space_bookings
        WHERE room_id = v_room_id
          AND booking_date = v_start_date
          AND status IN ('Confirmed', 'Approved', 'In Use', 'Checked In')
          AND deleted_at IS NULL
          AND id <> v_existing_booking_id
          AND (start_time, end_time) OVERLAPS (v_start_time, v_end_time);

        IF v_anchor_conflict > 0 AND NOT v_allow_conflict THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'error', 'CONFLICT',
                'message', 'Selected space has a conflict on anchor date ' || TO_CHAR(v_start_date, 'YYYY-MM-DD')
            );
        END IF;

        UPDATE public.space_bookings
        SET title = v_title,
            description = COALESCE(v_desc, description),
            purpose = v_purpose,
            category = v_category,
            priority = v_priority,
            room_id = v_room_id,
            building_id = v_building_id,
            floor_id = v_floor_id,
            booking_date = v_start_date,
            start_time = v_start_time,
            end_time = v_end_time,
            start_datetime = (v_start_date + v_start_time)::TIMESTAMPTZ,
            end_datetime = (v_start_date + v_end_time)::TIMESTAMPTZ,
            buffer_start_datetime = (v_start_date + v_start_time - (v_setup_min || ' minutes')::INTERVAL)::TIMESTAMPTZ,
            buffer_end_datetime = (v_start_date + v_end_time + (v_cleanup_min || ' minutes')::INTERVAL)::TIMESTAMPTZ,
            setup_minutes = v_setup_min,
            cleanup_minutes = v_cleanup_min,
            duration_minutes = v_duration_min,
            organizer_name = v_organizer_name,
            organizer_role = v_organizer_role,
            attendee_count = v_attendee_count,
            is_recurring = TRUE,
            recurring_series_id = v_series_id,
            recurrence_index = 1,
            status = CASE WHEN v_anchor_conflict > 0 THEN 'Pending' ELSE 'Confirmed' END,
            is_approved = (v_anchor_conflict = 0),
            updated_at = NOW()
        WHERE id = v_existing_booking_id;

        IF FOUND THEN
            v_created_count := 1;
            IF v_anchor_conflict > 0 THEN
                v_conflict_count := v_conflict_count + 1;
            END IF;
        END IF;
    END IF;

    -- Loop to generate series occurrences
    v_curr_date := v_start_date;
    IF v_existing_booking_id IS NOT NULL THEN
        IF v_frequency = 'daily' THEN
            v_curr_date := v_curr_date + v_interval;
        ELSE
            v_curr_date := v_curr_date + 1;
        END IF;
    END IF;

    v_week_start_date := v_start_date - (EXTRACT(ISODOW FROM v_start_date)::INT - 1);

    WHILE v_curr_date <= v_end_date AND v_created_count < v_max_occurrences LOOP
        v_dow := EXTRACT(ISODOW FROM v_curr_date)::INT;
        v_should_book := FALSE;

        IF v_frequency = 'daily' THEN
            v_should_book := TRUE;
        ELSIF v_frequency = 'weekdays' THEN
            v_should_book := (v_dow >= 1 AND v_dow <= 5);
        ELSIF v_frequency IN ('weekly', 'custom') THEN
            IF v_dow = ANY(v_days_of_week) THEN
                IF v_interval = 1 THEN
                    v_should_book := TRUE;
                ELSE
                    IF ((v_curr_date - v_week_start_date) / 7) % v_interval = 0 THEN
                        v_should_book := TRUE;
                    END IF;
                END IF;
            END IF;
        ELSIF v_frequency = 'monthly' THEN
            IF EXTRACT(DAY FROM v_curr_date) = EXTRACT(DAY FROM v_start_date) THEN
                v_should_book := TRUE;
            END IF;
        END IF;

        IF v_should_book THEN
            -- Check for conflict excluding current series and the existing booking
            SELECT COUNT(*) INTO v_existing_conflict
            FROM public.space_bookings
            WHERE room_id = v_room_id
              AND booking_date = v_curr_date
              AND status IN ('Confirmed', 'Approved', 'In Use', 'Checked In')
              AND deleted_at IS NULL
              AND id <> COALESCE(v_existing_booking_id, '00000000-0000-0000-0000-000000000000'::UUID)
              AND (start_time, end_time) OVERLAPS (v_start_time, v_end_time);

            IF v_existing_conflict = 0 OR v_allow_conflict THEN
                -- Collision-proof unique booking reference
                LOOP
                    v_booking_ref := 'BK-REC-' || TO_CHAR(v_curr_date, 'YYMMDD') || '-' || LPAD((v_created_count + 1)::TEXT, 2, '0') || '-' || UPPER(SUBSTRING(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 4));
                    EXIT WHEN NOT EXISTS (
                        SELECT 1 FROM public.space_bookings 
                        WHERE school_id = v_school_id AND booking_ref = v_booking_ref
                    );
                END LOOP;

                INSERT INTO public.space_bookings (
                    school_id, booking_ref, title, description, room_id, building_id, floor_id,
                    booking_date, start_time, end_time, start_datetime, end_datetime,
                    setup_minutes, cleanup_minutes, buffer_start_datetime, buffer_end_datetime,
                    duration_minutes, purpose, category, priority, status, is_approved,
                    organizer_name, organizer_role, organizer_email, organizer_phone, attendee_count,
                    is_recurring, recurring_series_id, recurrence_index, created_by
                ) VALUES (
                    v_school_id, v_booking_ref, v_title, v_desc, v_room_id, v_building_id, v_floor_id,
                    v_curr_date, v_start_time, v_end_time, (v_curr_date + v_start_time)::TIMESTAMPTZ, (v_curr_date + v_end_time)::TIMESTAMPTZ,
                    v_setup_min, v_cleanup_min, (v_curr_date + v_start_time - (v_setup_min || ' minutes')::INTERVAL)::TIMESTAMPTZ, (v_curr_date + v_end_time + (v_cleanup_min || ' minutes')::INTERVAL)::TIMESTAMPTZ,
                    v_duration_min, v_purpose, v_category, v_priority, 
                    CASE WHEN v_existing_conflict > 0 THEN 'Pending' ELSE 'Confirmed' END, 
                    (v_existing_conflict = 0),
                    v_organizer_name, v_organizer_role, v_organizer_email, v_organizer_phone, v_attendee_count,
                    TRUE, v_series_id, v_created_count + 1, v_user_id
                );
                v_created_count := v_created_count + 1;
                IF v_existing_conflict > 0 THEN
                    v_conflict_count := v_conflict_count + 1;
                END IF;
            ELSE
                v_conflict_count := v_conflict_count + 1;
            END IF;
        END IF;

        -- Step forward
        IF v_frequency = 'daily' THEN
            v_curr_date := v_curr_date + v_interval;
        ELSE
            v_curr_date := v_curr_date + 1;
        END IF;
    END LOOP;

    IF v_created_count = 0 AND NOT v_allow_conflict THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'CONFLICT',
            'message', 'All requested dates had conflicts and could not be booked.'
        );
    END IF;

    -- Update total occurrences count in series header
    UPDATE public.space_booking_recurring_series
    SET total_occurrences = v_created_count
    WHERE id = v_series_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'series_id', v_series_id,
        'created_count', v_created_count,
        'conflict_count', v_conflict_count,
        'start_date', v_start_date,
        'end_date', v_end_date,
        'message', CASE 
            WHEN v_conflict_count > 0 AND v_allow_conflict THEN
                'Successfully registered ' || v_created_count || ' recurring bookings (' || v_conflict_count || ' submitted as Pending for review due to time clashes).'
            ELSE
                'Successfully generated ' || v_created_count || ' recurring space bookings (' || v_conflict_count || ' skipped due to conflicts).'
        END
    );
END;
$$;


-- 2. Fix fn_space_booking_create_or_update with Collision-Proof booking_ref and allow_conflict support
CREATE OR REPLACE FUNCTION public.fn_space_booking_create_or_update(
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_id UUID;
    v_school_id UUID;
    v_booking_ref VARCHAR(50);
    v_room_id UUID;
    v_building_id UUID;
    v_floor_id UUID;
    v_booking_date DATE;
    v_start_time TIME;
    v_end_time TIME;
    v_start_dt TIMESTAMPTZ;
    v_end_dt TIMESTAMPTZ;
    v_setup_min INT;
    v_cleanup_min INT;
    v_buf_start TIMESTAMPTZ;
    v_buf_end TIMESTAMPTZ;
    v_duration_min INT;
    v_conflict RECORD;
    v_user_id UUID;
    v_user_name VARCHAR(150);
    v_status VARCHAR(30);
    v_is_new BOOLEAN;
    v_allow_conflict BOOLEAN := FALSE;
BEGIN
    v_school_id := (p_payload->>'school_id')::UUID;
    v_room_id := (p_payload->>'room_id')::UUID;
    v_user_id := (p_payload->>'user_id')::UUID;
    v_allow_conflict := COALESCE((p_payload->>'allow_conflict')::BOOLEAN, FALSE);
    
    -- Extract building and floor from room if not provided
    IF (p_payload->>'building_id') IS NOT NULL THEN
        v_building_id := (p_payload->>'building_id')::UUID;
    ELSE
        SELECT building_id, floor_id INTO v_building_id, v_floor_id
        FROM public.rooms WHERE id = v_room_id;
    END IF;

    IF (p_payload->>'floor_id') IS NOT NULL THEN
        v_floor_id := (p_payload->>'floor_id')::UUID;
    END IF;

    v_booking_date := (p_payload->>'booking_date')::DATE;
    v_start_time := (p_payload->>'start_time')::TIME;
    v_end_time := (p_payload->>'end_time')::TIME;

    v_start_dt := (v_booking_date || ' ' || v_start_time)::TIMESTAMPTZ;
    v_end_dt := (v_booking_date || ' ' || v_end_time)::TIMESTAMPTZ;
    
    v_setup_min := COALESCE((p_payload->>'setup_minutes')::INT, 0);
    v_cleanup_min := COALESCE((p_payload->>'cleanup_minutes')::INT, 0);

    v_buf_start := v_start_dt - (v_setup_min || ' minutes')::INTERVAL;
    v_buf_end := v_end_dt + (v_cleanup_min || ' minutes')::INTERVAL;
    v_duration_min := EXTRACT(EPOCH FROM (v_end_dt - v_start_dt)) / 60;

    IF (p_payload->>'id') IS NOT NULL AND (p_payload->>'id') <> '' THEN
        v_id := (p_payload->>'id')::UUID;
        v_is_new := FALSE;
        SELECT booking_ref, status INTO v_booking_ref, v_status
        FROM public.space_bookings WHERE id = v_id AND school_id = v_school_id;
    ELSE
        v_id := gen_random_uuid();
        v_is_new := TRUE;
    END IF;

    -- Conflict Check calling 6-argument signature explicitly
    SELECT * INTO v_conflict
    FROM public.fn_space_booking_check_conflict(
        v_school_id, v_room_id, v_buf_start, v_buf_end, 
        CASE WHEN v_is_new THEN NULL::UUID ELSE v_id END,
        TRUE
    );

    IF v_conflict.has_conflict THEN
        IF NOT v_allow_conflict THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'error', 'CONFLICT',
                'message', 'Selected space has a conflict with ' || v_conflict.conflicting_ref || ' (' || v_conflict.conflicting_title || ')'
            );
        ELSE
            -- Force status to Pending because conflict was acknowledged by submitter
            v_status := 'Pending';
        END IF;
    END IF;

    IF v_is_new THEN
        -- Generate Collision-Proof Unique Booking Ref
        LOOP
            v_booking_ref := 'BK-' || TO_CHAR(v_booking_date, 'YYYYMM') || '-' || LPAD(FLOOR(RANDOM() * 90000 + 10000)::TEXT, 5, '0');
            EXIT WHEN NOT EXISTS (
                SELECT 1 FROM public.space_bookings 
                WHERE school_id = v_school_id AND booking_ref = v_booking_ref
            );
        END LOOP;

        v_status := COALESCE(v_status, p_payload->>'status', 'Pending');

        INSERT INTO public.space_bookings (
            id, school_id, booking_ref, title, description, purpose, category,
            booking_type, priority, visibility, campus_id, building_id, floor_id, room_id,
            booking_date, start_time, end_time, start_datetime, end_datetime,
            setup_minutes, cleanup_minutes, buffer_start_datetime, buffer_end_datetime,
            duration_minutes, organizer_name, organizer_email, organizer_phone,
            organizer_role, organizer_department, requested_by, attendee_count,
            status, is_approved, special_instructions, amenities_required,
            created_by, updated_by
        ) VALUES (
            v_id, v_school_id, v_booking_ref, p_payload->>'title', p_payload->>'description',
            COALESCE(p_payload->>'purpose', 'Academic'), COALESCE(p_payload->>'category', 'Academic'),
            COALESCE(p_payload->>'booking_type', 'Internal'), COALESCE(p_payload->>'priority', 'Normal'),
            COALESCE(p_payload->>'visibility', 'Public'), (p_payload->>'campus_id')::UUID,
            v_building_id, v_floor_id, v_room_id,
            v_booking_date, v_start_time, v_end_time, v_start_dt, v_end_dt,
            v_setup_min, v_cleanup_min, v_buf_start, v_buf_end,
            v_duration_min, p_payload->>'organizer_name', p_payload->>'organizer_email', p_payload->>'organizer_phone',
            COALESCE(p_payload->>'organizer_role', 'Faculty'), p_payload->>'organizer_department',
            CASE WHEN (p_payload->>'requested_by') IS NOT NULL AND (p_payload->>'requested_by') <> ''
                 THEN (p_payload->>'requested_by')::UUID ELSE v_user_id END,
            COALESCE((p_payload->>'attendee_count')::INT, 1),
            v_status, (v_status = 'Approved' OR v_status = 'Confirmed'),
            p_payload->>'special_instructions', COALESCE(p_payload->'amenities_required', '[]'::JSONB),
            v_user_id, v_user_id
        );

        -- Insert initial history
        INSERT INTO public.space_booking_status_history (
            school_id, booking_id, previous_status, new_status, changed_by, changed_by_name, remarks
        ) VALUES (
            v_school_id, v_id, NULL, v_status, v_user_id, p_payload->>'organizer_name', 
            CASE WHEN v_conflict.has_conflict AND v_allow_conflict 
                 THEN 'Submitted with conflict acknowledged as Pending for review' 
                 ELSE 'Initial booking submission' END
        );

        -- Insert Initial Approval Step
        INSERT INTO public.space_booking_approvals (
            school_id, booking_id, step_number, approver_role, status
        ) VALUES (
            v_school_id, v_id, 1, 'Campus Administrator', 'Pending'
        );
    ELSE
        -- Update existing
        UPDATE public.space_bookings SET
            title = COALESCE(p_payload->>'title', title),
            description = COALESCE(p_payload->>'description', description),
            purpose = COALESCE(p_payload->>'purpose', purpose),
            priority = COALESCE(p_payload->>'priority', priority),
            building_id = COALESCE(v_building_id, building_id),
            floor_id = COALESCE(v_floor_id, floor_id),
            room_id = COALESCE(v_room_id, room_id),
            booking_date = COALESCE(v_booking_date, booking_date),
            start_time = COALESCE(v_start_time, start_time),
            end_time = COALESCE(v_end_time, end_time),
            start_datetime = v_start_dt,
            end_datetime = v_end_dt,
            setup_minutes = v_setup_min,
            cleanup_minutes = v_cleanup_min,
            buffer_start_datetime = v_buf_start,
            buffer_end_datetime = v_buf_end,
            duration_minutes = v_duration_min,
            organizer_name = COALESCE(p_payload->>'organizer_name', organizer_name),
            organizer_email = COALESCE(p_payload->>'organizer_email', organizer_email),
            organizer_phone = COALESCE(p_payload->>'organizer_phone', organizer_phone),
            organizer_role = COALESCE(p_payload->>'organizer_role', organizer_role),
            attendee_count = COALESCE((p_payload->>'attendee_count')::INT, attendee_count),
            special_instructions = COALESCE(p_payload->>'special_instructions', special_instructions),
            requested_by = CASE WHEN (p_payload->>'requested_by') IS NOT NULL AND (p_payload->>'requested_by') <> ''
                                THEN (p_payload->>'requested_by')::UUID ELSE requested_by END,
            amenities_required = COALESCE(p_payload->'amenities_required', amenities_required),
            status = CASE WHEN v_conflict.has_conflict AND v_allow_conflict THEN 'Pending' ELSE status END,
            is_approved = CASE WHEN v_conflict.has_conflict AND v_allow_conflict THEN FALSE ELSE is_approved END,
            updated_by = v_user_id,
            updated_at = NOW()
        WHERE id = v_id AND school_id = v_school_id;

        SELECT full_name INTO v_user_name FROM public.profiles WHERE id = v_user_id;
        IF v_user_name IS NULL THEN
            v_user_name := 'Administrator';
        END IF;

        -- Record modification history
        INSERT INTO public.space_booking_status_history (
            school_id, booking_id, previous_status, new_status, changed_by, changed_by_name, remarks
        ) VALUES (
            v_school_id, v_id, v_status, 
            CASE WHEN v_conflict.has_conflict AND v_allow_conflict THEN 'Pending' ELSE v_status END, 
            v_user_id, v_user_name, 
            CASE WHEN v_conflict.has_conflict AND v_allow_conflict 
                 THEN 'Schedule modified with conflict acknowledged as Pending for review' 
                 ELSE 'Schedule details modified' END
        );
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'booking_id', v_id,
        'booking_ref', v_booking_ref,
        'status', CASE WHEN v_conflict.has_conflict AND v_allow_conflict THEN 'Pending' ELSE v_status END
    );
END;
$$;
