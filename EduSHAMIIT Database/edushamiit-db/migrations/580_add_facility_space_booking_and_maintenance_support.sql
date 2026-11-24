-- ============================================================================
-- Migration 580: Add Facility Space Booking and Maintenance Support
-- Enables booking institutional campus facilities (grounds, gym, pool, dispensary,
-- auditorium, labs) alongside rooms, with conflict detection and unified reporting.
-- ============================================================================

-- 1. Alter space_bookings table to support campus facilities
ALTER TABLE public.space_bookings 
    ADD COLUMN IF NOT EXISTS facility_id UUID REFERENCES public.campus_facilities(id) ON DELETE SET NULL;

ALTER TABLE public.space_bookings 
    ADD COLUMN IF NOT EXISTS space_target_type VARCHAR(50) DEFAULT 'room' NOT NULL;

ALTER TABLE public.space_bookings ALTER COLUMN building_id DROP NOT NULL;
ALTER TABLE public.space_bookings ALTER COLUMN floor_id DROP NOT NULL;
ALTER TABLE public.space_bookings ALTER COLUMN room_id DROP NOT NULL;

CREATE INDEX IF NOT EXISTS idx_space_bookings_facility_id 
    ON public.space_bookings(facility_id) WHERE deleted_at IS NULL AND facility_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_space_bookings_facility_buffer 
    ON public.space_bookings(facility_id, buffer_start_datetime, buffer_end_datetime) 
    WHERE deleted_at IS NULL AND facility_id IS NOT NULL;

-- 2. Drop existing overload if needed and redefine fn_space_booking_check_conflict
DROP FUNCTION IF EXISTS public.fn_space_booking_check_conflict(uuid, uuid, timestamp with time zone, timestamp with time zone, uuid, boolean);
DROP FUNCTION IF EXISTS public.fn_space_booking_check_conflict(uuid, uuid, timestamp with time zone, timestamp with time zone, uuid, boolean, uuid);

CREATE OR REPLACE FUNCTION public.fn_space_booking_check_conflict(
    p_school_id UUID,
    p_room_id UUID,
    p_start_datetime TIMESTAMPTZ,
    p_end_datetime TIMESTAMPTZ,
    p_exclude_booking_id UUID DEFAULT NULL,
    p_approved_only BOOLEAN DEFAULT TRUE,
    p_facility_id UUID DEFAULT NULL
)
RETURNS TABLE (
    has_conflict BOOLEAN,
    conflict_type VARCHAR(50),
    conflicting_ref VARCHAR(50),
    conflicting_title VARCHAR(250),
    conflicting_start TIMESTAMPTZ,
    conflicting_end TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check against Blackout Dates
    RETURN QUERY
    SELECT
        TRUE AS has_conflict,
        'BLACKOUT'::VARCHAR(50) AS conflict_type,
        'BLACKOUT'::VARCHAR(50) AS conflicting_ref,
        b.title AS conflicting_title,
        b.start_datetime AS conflicting_start,
        b.end_datetime AS conflicting_end
    FROM public.space_booking_blackout_dates b
    WHERE b.school_id = p_school_id
      AND (
          (p_room_id IS NOT NULL AND (b.room_id = p_room_id OR b.room_id IS NULL))
          OR
          (p_room_id IS NULL AND b.room_id IS NULL)
      )
      AND b.start_datetime < p_end_datetime
      AND b.end_datetime > p_start_datetime
    LIMIT 1;

    IF FOUND THEN
        RETURN;
    END IF;

    -- Check against existing approved bookings (or all active bookings if p_approved_only is FALSE)
    RETURN QUERY
    SELECT
        TRUE AS has_conflict,
        'BOOKING'::VARCHAR(50) AS conflict_type,
        sb.booking_ref AS conflicting_ref,
        sb.title AS conflicting_title,
        sb.buffer_start_datetime AS conflicting_start,
        sb.buffer_end_datetime AS conflicting_end
    FROM public.space_bookings sb
    WHERE sb.school_id = p_school_id
      AND sb.deleted_at IS NULL
      AND (
          (p_room_id IS NOT NULL AND sb.room_id = p_room_id)
          OR
          (p_facility_id IS NOT NULL AND sb.facility_id = p_facility_id)
      )
      AND (
          (p_approved_only = TRUE AND sb.is_approved = TRUE AND sb.status IN ('Approved', 'Confirmed', 'Checked In', 'In Use'))
          OR
          (p_approved_only = FALSE AND sb.status NOT IN ('Rejected', 'Cancelled', 'Expired', 'Conflict'))
      )
      AND (p_exclude_booking_id IS NULL OR sb.id <> p_exclude_booking_id)
      AND sb.buffer_start_datetime < p_end_datetime
      AND sb.buffer_end_datetime > p_start_datetime
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            FALSE AS has_conflict,
            NULL::VARCHAR(50) AS conflict_type,
            NULL::VARCHAR(50) AS conflicting_ref,
            NULL::VARCHAR(250) AS conflicting_title,
            NULL::TIMESTAMPTZ AS conflicting_start,
            NULL::TIMESTAMPTZ AS conflicting_end;
    END IF;
END;
$$;


-- 3. Redefine fn_space_booking_create_or_update to support both rooms and facilities
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
    v_facility_id UUID;
    v_space_target_type VARCHAR(50);
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
    v_room_id := NULLIF(p_payload->>'room_id', '')::UUID;
    v_facility_id := NULLIF(p_payload->>'facility_id', '')::UUID;
    v_space_target_type := COALESCE(
        NULLIF(p_payload->>'space_target_type', ''),
        CASE WHEN v_facility_id IS NOT NULL THEN 'facility' ELSE 'room' END
    );
    v_user_id := NULLIF(p_payload->>'user_id', '')::UUID;
    v_allow_conflict := COALESCE((p_payload->>'allow_conflict')::BOOLEAN, FALSE);

    -- Extract building and floor
    IF (p_payload->>'building_id') IS NOT NULL AND (p_payload->>'building_id') <> '' THEN
        v_building_id := (p_payload->>'building_id')::UUID;
    ELSIF v_room_id IS NOT NULL THEN
        SELECT building_id, floor_id INTO v_building_id, v_floor_id
        FROM public.rooms WHERE id = v_room_id;
    ELSIF v_facility_id IS NOT NULL THEN
        SELECT building_id, floor_id INTO v_building_id, v_floor_id
        FROM public.campus_facilities WHERE id = v_facility_id;
    END IF;

    IF (p_payload->>'floor_id') IS NOT NULL AND (p_payload->>'floor_id') <> '' THEN
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

    -- Conflict Check supporting both room_id and facility_id
    SELECT * INTO v_conflict
    FROM public.fn_space_booking_check_conflict(
        v_school_id, v_room_id, v_buf_start, v_buf_end, 
        CASE WHEN v_is_new THEN NULL::UUID ELSE v_id END,
        TRUE,
        v_facility_id
    );

    IF v_conflict.has_conflict THEN
        IF NOT v_allow_conflict THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'error', 'CONFLICT',
                'message', 'Selected space has a conflict with ' || v_conflict.conflicting_ref || ' (' || v_conflict.conflicting_title || ')'
            );
        ELSE
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
            facility_id, space_target_type,
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
            COALESCE(p_payload->>'visibility', 'Public'), NULLIF(p_payload->>'campus_id', '')::UUID,
            v_building_id, v_floor_id, v_room_id,
            v_facility_id, v_space_target_type,
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
                 THEN 'Booking submitted with conflict acknowledged as Pending for review' 
                 ELSE 'Initial booking requested' END
        );
    ELSE
        UPDATE public.space_bookings
        SET
            title = COALESCE(p_payload->>'title', title),
            description = COALESCE(p_payload->>'description', description),
            purpose = COALESCE(p_payload->>'purpose', purpose),
            category = COALESCE(p_payload->>'category', category),
            priority = COALESCE(p_payload->>'priority', priority),
            building_id = COALESCE(v_building_id, building_id),
            floor_id = COALESCE(v_floor_id, floor_id),
            room_id = v_room_id,
            facility_id = v_facility_id,
            space_target_type = v_space_target_type,
            booking_date = v_booking_date,
            start_time = v_start_time,
            end_time = v_end_time,
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


-- 4. Redefine fn_space_booking_create_recurring to support facilities
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
    v_facility_id UUID;
    v_space_target_type VARCHAR(50);
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
    v_allow_conflict BOOLEAN := FALSE;
BEGIN
    v_school_id := (p_payload->>'school_id')::UUID;
    v_user_id := (p_payload->>'user_id')::UUID;
    v_existing_booking_id := NULLIF(p_payload->>'existing_booking_id', '')::UUID;
    v_title := COALESCE(p_payload->>'title', p_payload->>'series_title', 'Recurring Class/Event Series');
    v_desc := p_payload->>'description';
    v_room_id := NULLIF(p_payload->>'room_id', '')::UUID;
    v_facility_id := NULLIF(p_payload->>'facility_id', '')::UUID;
    v_space_target_type := COALESCE(
        NULLIF(p_payload->>'space_target_type', ''),
        CASE WHEN v_facility_id IS NOT NULL THEN 'facility' ELSE 'room' END
    );
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
        v_max_occurrences := LEAST(v_max_occurrences, 60);
        v_end_date := COALESCE((p_payload->>'end_date')::DATE, v_start_date + 180);
    END IF;

    IF v_user_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user_id) THEN
        SELECT id INTO v_user_id FROM public.profiles WHERE role IN ('admin', 'super_admin', 'teacher') LIMIT 1;
    END IF;

    v_duration_min := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) / 60;
    IF v_duration_min <= 0 THEN
        v_duration_min := 60;
    END IF;

    IF v_room_id IS NOT NULL THEN
        SELECT building_id, floor_id INTO v_building_id, v_floor_id
        FROM public.rooms WHERE id = v_room_id;
    ELSIF v_facility_id IS NOT NULL THEN
        SELECT building_id, floor_id INTO v_building_id, v_floor_id
        FROM public.campus_facilities WHERE id = v_facility_id;
    END IF;

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

    INSERT INTO public.space_booking_recurring_series (
        school_id, title, recurrence_type, start_date, end_date, days_of_week, "interval", created_by
    ) VALUES (
        v_school_id, v_title, UPPER(v_frequency), v_start_date, v_end_date, v_days_of_week, v_interval, v_user_id
    ) RETURNING id INTO v_series_id;

    v_curr_date := v_start_date;
    WHILE v_curr_date <= v_end_date AND v_created_count < v_max_occurrences LOOP
        v_dow := EXTRACT(ISODOW FROM v_curr_date)::INT;
        IF v_dow = ANY(v_days_of_week) THEN
            SELECT COUNT(*) INTO v_existing_conflict
            FROM public.space_bookings
            WHERE (
                (v_room_id IS NOT NULL AND room_id = v_room_id)
                OR
                (v_facility_id IS NOT NULL AND facility_id = v_facility_id)
            )
              AND booking_date = v_curr_date
              AND status IN ('Confirmed', 'Approved', 'In Use', 'Checked In')
              AND deleted_at IS NULL
              AND id <> COALESCE(v_existing_booking_id, '00000000-0000-0000-0000-000000000000'::UUID)
              AND (start_time, end_time) OVERLAPS (v_start_time, v_end_time);

            IF v_existing_conflict = 0 OR v_allow_conflict THEN
                LOOP
                    v_booking_ref := 'BK-REC-' || TO_CHAR(v_curr_date, 'YYMMDD') || '-' || LPAD((v_created_count + 1)::TEXT, 2, '0') || '-' || UPPER(SUBSTRING(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 4));
                    EXIT WHEN NOT EXISTS (
                        SELECT 1 FROM public.space_bookings 
                        WHERE school_id = v_school_id AND booking_ref = v_booking_ref
                    );
                END LOOP;

                INSERT INTO public.space_bookings (
                    school_id, booking_ref, title, description, room_id, facility_id, space_target_type,
                    building_id, floor_id,
                    booking_date, start_time, end_time, start_datetime, end_datetime,
                    setup_minutes, cleanup_minutes, buffer_start_datetime, buffer_end_datetime,
                    duration_minutes, purpose, category, priority, status, is_approved,
                    organizer_name, organizer_role, organizer_email, organizer_phone, attendee_count,
                    is_recurring, recurring_series_id, recurrence_index, created_by
                ) VALUES (
                    v_school_id, v_booking_ref, v_title, v_desc, v_room_id, v_facility_id, v_space_target_type,
                    v_building_id, v_floor_id,
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


-- 5. Redefine fn_space_booking_list with LEFT JOINS to seamlessly handle both rooms and campus facilities
CREATE OR REPLACE FUNCTION public.fn_space_booking_list(
    p_school_id UUID,
    p_status VARCHAR DEFAULT NULL,
    p_building_id UUID DEFAULT NULL,
    p_room_type VARCHAR DEFAULT NULL,
    p_search VARCHAR DEFAULT NULL,
    p_date_from DATE DEFAULT NULL,
    p_date_to DATE DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_purpose VARCHAR DEFAULT NULL,
    p_priority VARCHAR DEFAULT NULL,
    p_sort_by VARCHAR DEFAULT 'booking_date',
    p_sort_order VARCHAR DEFAULT 'ASC'
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_offset INT;
    v_total_records INT;
    v_records JSONB;
    v_sort_col VARCHAR;
    v_is_desc BOOLEAN;
BEGIN
    v_offset := GREATEST((p_page - 1) * p_page_size, 0);
    v_sort_col := LOWER(COALESCE(p_sort_by, 'booking_date'));
    v_is_desc := (LOWER(COALESCE(p_sort_order, 'asc')) = 'desc');

    -- Count total records matching criteria
    SELECT COUNT(*) INTO v_total_records
    FROM public.space_bookings sb
    LEFT JOIN public.rooms r ON sb.room_id = r.id
    LEFT JOIN public.campus_facilities cf ON sb.facility_id = cf.id
    LEFT JOIN public.buildings b ON COALESCE(sb.building_id, cf.building_id) = b.id
    WHERE (sb.school_id = p_school_id OR p_school_id IS NULL)
      AND sb.deleted_at IS NULL
      AND (
          (p_status IS NULL OR p_status = '' OR p_status = 'All')
          OR (p_status = 'Pending' AND sb.status IN ('Pending', 'Submitted'))
          OR (p_status = 'Approved' AND sb.status IN ('Approved', 'Confirmed', 'Checked In', 'In Use', 'Completed'))
          OR (p_status = 'Rejected' AND sb.status = 'Rejected')
          OR (p_status = 'Conflict' AND sb.status = 'Conflict')
          OR (p_status = 'Cancelled' AND sb.status = 'Cancelled')
          OR (p_status NOT IN ('All', 'Pending', 'Approved', 'Rejected', 'Conflict', 'Cancelled') AND sb.status ILIKE p_status)
      )
      AND (p_building_id IS NULL OR COALESCE(sb.building_id, cf.building_id) = p_building_id)
      AND (p_room_type IS NULL OR p_room_type = '' OR p_room_type = 'All' OR r.room_type ILIKE p_room_type OR cf.category ILIKE p_room_type)
      AND (p_purpose IS NULL OR p_purpose = '' OR p_purpose = 'All' OR sb.purpose ILIKE p_purpose)
      AND (p_priority IS NULL OR p_priority = '' OR p_priority = 'All' OR sb.priority ILIKE p_priority)
      AND (p_date_from IS NULL OR sb.booking_date >= p_date_from)
      AND (p_date_to IS NULL OR sb.booking_date <= p_date_to)
      AND (
          p_search IS NULL OR p_search = '' 
          OR sb.title ILIKE '%' || p_search || '%'
          OR sb.booking_ref ILIKE '%' || p_search || '%'
          OR sb.organizer_name ILIKE '%' || p_search || '%'
          OR r.name ILIKE '%' || p_search || '%'
          OR r.room_number ILIKE '%' || p_search || '%'
          OR cf.name ILIKE '%' || p_search || '%'
          OR cf.code ILIKE '%' || p_search || '%'
          OR b.name ILIKE '%' || p_search || '%'
      );

    -- Fetch paginated items with formatted display strings for grid rendering
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', q.id,
                'booking_ref', q.booking_ref,
                'title', q.title,
                'purpose', q.purpose,
                'category', q.category,
                'priority', q.priority,
                'status', q.status,
                'is_approved', q.is_approved,
                'booking_date', q.booking_date,
                'start_time', q.start_time,
                'end_time', q.end_time,
                'formatted_schedule', q.formatted_schedule,
                'room_id', q.room_id,
                'room_name', q.room_name,
                'room_number', q.room_number,
                'room_type', q.room_type,
                'facility_id', q.facility_id,
                'facility_name', q.facility_name,
                'facility_category', q.facility_category,
                'space_target_type', q.space_target_type,
                'space_display', q.space_display,
                'building_id', q.building_id,
                'building_name', q.building_name,
                'floor_name', q.floor_name,
                'organizer_name', q.organizer_name,
                'organizer_role', q.organizer_role,
                'requested_by_display', q.requested_by_display,
                'attendee_count', q.attendee_count,
                'is_recurring', q.is_recurring,
                'rejection_reason', q.rejection_reason,
                'created_at', q.created_at
            )
        ),
        '[]'::JSONB
    ) INTO v_records
    FROM (
        SELECT 
            sb.id, sb.booking_ref, sb.title, sb.purpose, sb.category, sb.priority,
            sb.status, sb.is_approved, sb.booking_date,
            TO_CHAR(sb.start_time, 'HH12:MI AM') AS start_time,
            TO_CHAR(sb.end_time, 'HH12:MI AM') AS end_time,
            TO_CHAR(sb.booking_date, 'DD Mon') || ', ' || 
            TO_CHAR(sb.start_time, 'HH12:MI AM') || ' - ' || 
            TO_CHAR(sb.end_time, 'HH12:MI AM') AS formatted_schedule,
            sb.room_id,
            COALESCE(r.name, cf.name, 'Campus Space') AS room_name,
            COALESCE(r.room_number, cf.code, '') AS room_number,
            COALESCE(r.room_type, cf.category, 'General Space') AS room_type,
            sb.facility_id,
            cf.name AS facility_name,
            cf.category AS facility_category,
            COALESCE(sb.space_target_type, CASE WHEN sb.facility_id IS NOT NULL THEN 'facility' ELSE 'room' END) AS space_target_type,
            CASE 
                WHEN sb.facility_id IS NOT NULL THEN cf.name || ' (' || COALESCE(cf.category, 'Facility') || ')'
                ELSE COALESCE(r.name || ' (' || COALESCE(r.room_type, 'Classroom') || ')', 'Campus Space')
            END AS space_display,
            COALESCE(sb.building_id, cf.building_id) AS building_id,
            COALESCE(b.name, 'Main Campus Grounds') AS building_name,
            f.name AS floor_name,
            COALESCE(sb.organizer_name, 'Staff Lead') AS organizer_name,
            COALESCE(sb.organizer_role, 'Faculty') AS organizer_role,
            COALESCE(sb.organizer_name, 'Staff Lead') || ' (' || COALESCE(sb.organizer_role, 'Faculty') || ')' AS requested_by_display,
            sb.attendee_count, sb.is_recurring, sb.rejection_reason, sb.created_at
        FROM public.space_bookings sb
        LEFT JOIN public.rooms r ON sb.room_id = r.id
        LEFT JOIN public.campus_facilities cf ON sb.facility_id = cf.id
        LEFT JOIN public.buildings b ON COALESCE(sb.building_id, cf.building_id) = b.id
        LEFT JOIN public.building_floors f ON COALESCE(sb.floor_id, cf.floor_id) = f.id
        WHERE (sb.school_id = p_school_id OR p_school_id IS NULL)
          AND sb.deleted_at IS NULL
          AND (
              (p_status IS NULL OR p_status = '' OR p_status = 'All')
              OR (p_status = 'Pending' AND sb.status IN ('Pending', 'Submitted'))
              OR (p_status = 'Approved' AND sb.status IN ('Approved', 'Confirmed', 'Checked In', 'In Use', 'Completed'))
              OR (p_status = 'Rejected' AND sb.status = 'Rejected')
              OR (p_status = 'Conflict' AND sb.status = 'Conflict')
              OR (p_status = 'Cancelled' AND sb.status = 'Cancelled')
              OR (p_status NOT IN ('All', 'Pending', 'Approved', 'Rejected', 'Conflict', 'Cancelled') AND sb.status ILIKE p_status)
          )
          AND (p_building_id IS NULL OR COALESCE(sb.building_id, cf.building_id) = p_building_id)
          AND (p_room_type IS NULL OR p_room_type = '' OR p_room_type = 'All' OR r.room_type ILIKE p_room_type OR cf.category ILIKE p_room_type)
          AND (p_purpose IS NULL OR p_purpose = '' OR p_purpose = 'All' OR sb.purpose ILIKE p_purpose)
          AND (p_priority IS NULL OR p_priority = '' OR p_priority = 'All' OR sb.priority ILIKE p_priority)
          AND (p_date_from IS NULL OR sb.booking_date >= p_date_from)
          AND (p_date_to IS NULL OR sb.booking_date <= p_date_to)
          AND (
              p_search IS NULL OR p_search = '' 
              OR sb.title ILIKE '%' || p_search || '%'
              OR sb.booking_ref ILIKE '%' || p_search || '%'
              OR sb.organizer_name ILIKE '%' || p_search || '%'
              OR r.name ILIKE '%' || p_search || '%'
              OR r.room_number ILIKE '%' || p_search || '%'
              OR cf.name ILIKE '%' || p_search || '%'
              OR cf.code ILIKE '%' || p_search || '%'
              OR b.name ILIKE '%' || p_search || '%'
          )
        ORDER BY
            -- Ascending Cases
            CASE WHEN NOT v_is_desc AND (v_sort_col = 'title') THEN LOWER(sb.title) END ASC,
            CASE WHEN NOT v_is_desc AND (v_sort_col IN ('room_name', 'space')) THEN LOWER(COALESCE(r.name, cf.name, '')) END ASC,
            CASE WHEN NOT v_is_desc AND (v_sort_col IN ('organizer_name', 'requested_by')) THEN LOWER(sb.organizer_name) END ASC,
            CASE WHEN NOT v_is_desc AND (v_sort_col = 'purpose') THEN LOWER(sb.purpose) END ASC,
            CASE WHEN NOT v_is_desc AND (v_sort_col = 'status') THEN LOWER(sb.status) END ASC,
            CASE WHEN NOT v_is_desc AND (v_sort_col = 'booking_date') THEN sb.booking_date END ASC,
            CASE WHEN NOT v_is_desc AND (v_sort_col = 'booking_date') THEN sb.start_time END ASC,
            CASE WHEN NOT v_is_desc AND (v_sort_col = 'created_at') THEN sb.created_at END ASC,

            -- Descending Cases
            CASE WHEN v_is_desc AND (v_sort_col = 'title') THEN LOWER(sb.title) END DESC,
            CASE WHEN v_is_desc AND (v_sort_col IN ('room_name', 'space')) THEN LOWER(COALESCE(r.name, cf.name, '')) END DESC,
            CASE WHEN v_is_desc AND (v_sort_col IN ('organizer_name', 'requested_by')) THEN LOWER(sb.organizer_name) END DESC,
            CASE WHEN v_is_desc AND (v_sort_col = 'purpose') THEN LOWER(sb.purpose) END DESC,
            CASE WHEN v_is_desc AND (v_sort_col = 'status') THEN LOWER(sb.status) END DESC,
            CASE WHEN v_is_desc AND (v_sort_col = 'booking_date') THEN sb.booking_date END DESC,
            CASE WHEN v_is_desc AND (v_sort_col = 'booking_date') THEN sb.start_time END DESC,
            CASE WHEN v_is_desc AND (v_sort_col = 'created_at') THEN sb.created_at END DESC,

            sb.created_at DESC
        LIMIT p_page_size
        OFFSET v_offset
    ) q;

    RETURN jsonb_build_object(
        'items', v_records,
        'total_count', v_total_records,
        'page', p_page,
        'page_size', p_page_size,
        'total_pages', CEIL(v_total_records::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)
    );
END;
$$;


-- 6. Redefine fn_space_booking_get_details supporting both rooms and facilities
CREATE OR REPLACE FUNCTION public.fn_space_booking_get_details(
    p_booking_id UUID,
    p_school_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_details JSONB;
    v_approvals JSONB;
    v_history JSONB;
BEGIN
    SELECT
        jsonb_build_object(
            'id', sb.id,
            'booking_ref', sb.booking_ref,
            'title', sb.title,
            'description', sb.description,
            'purpose', sb.purpose,
            'category', sb.category,
            'booking_type', sb.booking_type,
            'priority', sb.priority,
            'visibility', sb.visibility,
            'status', sb.status,
            'is_approved', sb.is_approved,
            'booking_date', sb.booking_date,
            'start_time', TO_CHAR(sb.start_time, 'HH12:MI AM'),
            'end_time', TO_CHAR(sb.end_time, 'HH12:MI AM'),
            'start_datetime', sb.start_datetime,
            'end_datetime', sb.end_datetime,
            'setup_minutes', sb.setup_minutes,
            'cleanup_minutes', sb.cleanup_minutes,
            'duration_minutes', sb.duration_minutes,
            'room_id', sb.room_id,
            'room_name', COALESCE(r.name, cf.name, 'Campus Space'),
            'room_number', COALESCE(r.room_number, cf.code, ''),
            'room_code', COALESCE(r.room_code, cf.code, ''),
            'room_type', COALESCE(r.room_type, cf.category, 'General Space'),
            'room_capacity', COALESCE(r.max_capacity, cf.capacity, 50),
            'facility_id', sb.facility_id,
            'facility_name', cf.name,
            'facility_category', cf.category,
            'space_target_type', COALESCE(sb.space_target_type, CASE WHEN sb.facility_id IS NOT NULL THEN 'facility' ELSE 'room' END)
        ) || jsonb_build_object(
            'building_id', COALESCE(sb.building_id, cf.building_id),
            'building_name', COALESCE(b.name, 'Main Campus Grounds'),
            'floor_id', COALESCE(sb.floor_id, cf.floor_id),
            'floor_name', f.name,
            'organizer_name', sb.organizer_name,
            'organizer_email', sb.organizer_email,
            'organizer_phone', sb.organizer_phone,
            'organizer_role', sb.organizer_role,
            'organizer_department', sb.organizer_department,
            'attendee_count', sb.attendee_count,
            'rejection_reason', sb.rejection_reason,
            'cancellation_reason', sb.cancellation_reason,
            'checked_in_at', sb.checked_in_at,
            'checked_out_at', sb.checked_out_at,
            'space_condition_on_checkout', sb.space_condition_on_checkout,
            'checkout_remarks', sb.checkout_remarks,
            'is_recurring', sb.is_recurring,
            'recurring_series_id', sb.recurring_series_id,
            'special_instructions', sb.special_instructions,
            'amenities_required', sb.amenities_required,
            'created_at', sb.created_at,
            'updated_at', sb.updated_at
        ) INTO v_details
    FROM public.space_bookings sb
    LEFT JOIN public.rooms r ON sb.room_id = r.id
    LEFT JOIN public.campus_facilities cf ON sb.facility_id = cf.id
    LEFT JOIN public.buildings b ON COALESCE(sb.building_id, cf.building_id) = b.id
    LEFT JOIN public.building_floors f ON COALESCE(sb.floor_id, cf.floor_id) = f.id
    WHERE sb.id = p_booking_id
      AND sb.school_id = p_school_id
      AND sb.deleted_at IS NULL;

    IF v_details IS NULL THEN
        RETURN NULL;
    END IF;

    -- Fetch Approvals
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', a.id,
                'step_number', a.step_number,
                'approver_role', a.approver_role,
                'status', a.status,
                'comments', a.comments,
                'decided_at', a.decided_at,
                'approver_user_id', a.approver_user_id
            ) ORDER BY a.step_number ASC
        ),
        '[]'::JSONB
    ) INTO v_approvals
    FROM public.space_booking_approvals a
    WHERE a.booking_id = p_booking_id;

    -- Fetch History
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', h.id,
                'previous_status', h.previous_status,
                'new_status', h.new_status,
                'changed_by_name', h.changed_by_name,
                'reason', h.reason,
                'remarks', h.remarks,
                'created_at', h.created_at
            ) ORDER BY h.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_history
    FROM public.space_booking_status_history h
    WHERE h.booking_id = p_booking_id;

    RETURN v_details || jsonb_build_object(
        'approvals', v_approvals,
        'status_history', v_history
    );
END;
$$;
