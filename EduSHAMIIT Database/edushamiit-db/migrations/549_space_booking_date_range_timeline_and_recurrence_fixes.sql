-- Migration 549: Space Booking Date-Range Timeline & Multi-Scenario Recurrence Engine
-- Enables availability timeline to fetch full multi-day date ranges (Day, Week, Month)
-- and fixes recurrence generation across daily, weekdays, weekly, monthly, and custom intervals.

-- 1. Drop existing overloaded functions to avoid signature ambiguity
DROP FUNCTION IF EXISTS public.fn_space_booking_get_availability_timeline(UUID, UUID, VARCHAR, DATE);
DROP FUNCTION IF EXISTS public.fn_space_booking_get_availability_timeline(UUID, DATE, UUID, VARCHAR);
DROP FUNCTION IF EXISTS public.fn_space_booking_get_availability_timeline(UUID, DATE, DATE, UUID, VARCHAR);

-- 2. Master fn_space_booking_get_availability_timeline supporting Date Range (Day, Week, Month)
CREATE OR REPLACE FUNCTION public.fn_space_booking_get_availability_timeline(
    p_school_id UUID,
    p_start_date DATE,
    p_end_date DATE DEFAULT NULL,
    p_building_id UUID DEFAULT NULL,
    p_room_type VARCHAR(50) DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_start_date DATE := COALESCE(p_start_date, CURRENT_DATE);
    v_end_date DATE := COALESCE(p_end_date, v_start_date);
    v_result JSONB;
BEGIN
    WITH room_data AS (
        SELECT
            r.id AS room_id,
            r.name AS room_name,
            r.room_number,
            r.room_code,
            r.room_type,
            r.max_capacity,
            b.id AS building_id,
            b.name AS building_name,
            b.code AS building_code,
            f.id AS floor_id,
            f.name AS floor_name,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'id', sb.id,
                        'booking_ref', sb.booking_ref,
                        'title', sb.title,
                        'purpose', sb.purpose,
                        'start_time', TO_CHAR(sb.start_time, 'HH12:MI AM'),
                        'end_time', TO_CHAR(sb.end_time, 'HH12:MI AM'),
                        'start_datetime', sb.start_datetime,
                        'end_datetime', sb.end_datetime,
                        'booking_date', TO_CHAR(sb.booking_date, 'YYYY-MM-DD'),
                        'duration_minutes', sb.duration_minutes,
                        'organizer_name', sb.organizer_name,
                        'organizer_role', sb.organizer_role,
                        'status', sb.status,
                        'is_approved', sb.is_approved
                    ) ORDER BY sb.start_datetime ASC
                ) FILTER (WHERE sb.id IS NOT NULL),
                '[]'::JSONB
            ) AS bookings
        FROM public.rooms r
        JOIN public.buildings b ON r.building_id = b.id
        LEFT JOIN public.building_floors f ON r.floor_id = f.id
        LEFT JOIN public.space_bookings sb
            ON sb.room_id = r.id
            AND sb.booking_date >= v_start_date
            AND sb.booking_date <= v_end_date
            AND sb.deleted_at IS NULL
            AND sb.is_approved = TRUE
            AND sb.status IN ('Approved', 'Confirmed', 'Checked In', 'In Use')
        WHERE (r.school_id = p_school_id OR p_school_id IS NULL)
          AND r.deleted_at IS NULL
          AND r.is_bookable = TRUE
          AND (p_building_id IS NULL OR r.building_id = p_building_id)
          AND (p_room_type IS NULL OR p_room_type = 'All' OR r.room_type ILIKE p_room_type)
        GROUP BY r.id, r.name, r.room_number, r.room_code, r.room_type, r.max_capacity,
                 b.id, b.name, b.code, f.id, f.name
        ORDER BY
            CASE
                WHEN r.name ILIKE '%Grade 4%' OR r.room_number = '201' THEN 0
                WHEN r.name ILIKE '%Classroom%' THEN 1
                WHEN r.name ILIKE '%Lab%' THEN 2
                ELSE 3
            END ASC,
            jsonb_array_length(COALESCE(
                jsonb_agg(sb.id) FILTER (WHERE sb.id IS NOT NULL), '[]'::jsonb
            )) DESC,
            r.room_number ASC
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'room_id', rd.room_id,
            'room_name', rd.room_name,
            'room_number', rd.room_number,
            'room_code', rd.room_code,
            'room_type', rd.room_type,
            'capacity', rd.max_capacity,
            'building_id', rd.building_id,
            'building_name', rd.building_name,
            'building_code', rd.building_code,
            'floor_id', rd.floor_id,
            'floor_name', rd.floor_name,
            'bookings', rd.bookings
        )
    ) INTO v_result
    FROM room_data rd;

    RETURN COALESCE(v_result, '[]'::JSONB);
END;
$$;

-- 3. Compatibility Overloads for 1-day legacy calls
CREATE OR REPLACE FUNCTION public.fn_space_booking_get_availability_timeline(
    p_school_id UUID,
    p_building_id UUID,
    p_room_type VARCHAR,
    p_date DATE
)
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
    SELECT public.fn_space_booking_get_availability_timeline(p_school_id, p_date, p_date, p_building_id, p_room_type);
$$;

CREATE OR REPLACE FUNCTION public.fn_space_booking_get_availability_timeline(
    p_school_id UUID,
    p_date DATE,
    p_building_id UUID DEFAULT NULL,
    p_room_type VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
    SELECT public.fn_space_booking_get_availability_timeline(p_school_id, p_date, p_date, p_building_id, p_room_type);
$$;

-- 4. Enhanced Recurrence Generation Procedure: Multi-Scenario Engine
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
    v_should_book BOOLEAN;
    v_week_start_date DATE;
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
            status = 'Confirmed',
            is_approved = TRUE,
            updated_at = NOW()
        WHERE id = v_existing_booking_id;

        IF FOUND THEN
            v_created_count := 1;
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
            -- Only Monday through Friday
            v_should_book := (v_dow >= 1 AND v_dow <= 5);
        ELSIF v_frequency IN ('weekly', 'custom') THEN
            -- Check if dow matches and interval week matches
            IF v_dow = ANY(v_days_of_week) THEN
                IF v_interval = 1 THEN
                    v_should_book := TRUE;
                ELSE
                    -- Check if current week is an Nth interval week from start
                    IF ((v_curr_date - v_week_start_date) / 7) % v_interval = 0 THEN
                        v_should_book := TRUE;
                    END IF;
                END IF;
            END IF;
        ELSIF v_frequency = 'monthly' THEN
            -- Book on the same day of month
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

            IF v_existing_conflict = 0 THEN
                v_booking_ref := 'BK-REC-' || TO_CHAR(v_curr_date, 'YYMMDD') || '-' || LPAD((v_created_count + 1)::TEXT, 3, '0');

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
                    v_duration_min, v_purpose, v_category, v_priority, 'Confirmed', TRUE,
                    v_organizer_name, v_organizer_role, v_organizer_email, v_organizer_phone, v_attendee_count,
                    TRUE, v_series_id, v_created_count + 1, v_user_id
                );
                v_created_count := v_created_count + 1;
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

    -- Update total occurrences count in series header
    UPDATE public.space_booking_recurring_series
    SET total_occurrences = v_created_count
    WHERE id = v_series_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'series_id', v_series_id,
        'created_count', v_created_count,
        'conflict_skipped_count', v_conflict_count,
        'start_date', v_start_date,
        'end_date', v_end_date,
        'message', 'Successfully generated ' || v_created_count || ' recurring space bookings (' || v_conflict_count || ' skipped due to conflicts).'
    );
END;
$$;
