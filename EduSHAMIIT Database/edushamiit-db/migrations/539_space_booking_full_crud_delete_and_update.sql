-- 539_space_booking_full_crud_delete_and_update.sql
-- Enables full CRUD: reliable edit/update and safe delete/cancel of single or recurring space bookings

CREATE OR REPLACE FUNCTION public.fn_space_booking_delete(
    p_school_id uuid,
    p_booking_id uuid,
    p_user_id uuid,
    p_delete_series boolean DEFAULT false,
    p_reason text DEFAULT 'Deleted by user'
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    v_series_id UUID;
    v_booking_ref VARCHAR(50);
    v_status VARCHAR(30);
    v_user_name VARCHAR(150);
    v_deleted_count INT := 0;
BEGIN
    SELECT recurring_series_id, booking_ref, status INTO v_series_id, v_booking_ref, v_status
    FROM public.space_bookings
    WHERE id = p_booking_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_booking_ref IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Booking not found or already deleted'
        );
    END IF;

    SELECT full_name INTO v_user_name FROM public.profiles WHERE id = p_user_id;
    IF v_user_name IS NULL THEN
        v_user_name := 'Administrator';
    END IF;

    IF p_delete_series AND v_series_id IS NOT NULL THEN
        -- Delete all bookings in series
        UPDATE public.space_bookings
        SET deleted_at = NOW(),
            status = 'Cancelled',
            cancelled_by = p_user_id,
            cancelled_at = NOW(),
            cancellation_reason = COALESCE(p_reason, 'Recurring series deleted'),
            updated_at = NOW()
        WHERE school_id = p_school_id 
          AND recurring_series_id = v_series_id 
          AND deleted_at IS NULL;

        GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

        -- Deactivate recurring series parent record
        UPDATE public.space_booking_recurring_series
        SET is_active = FALSE,
            updated_at = NOW()
        WHERE id = v_series_id AND school_id = p_school_id;

        -- Status history for target booking
        INSERT INTO public.space_booking_status_history (
            school_id, booking_id, previous_status, new_status, changed_by, changed_by_name, remarks
        ) VALUES (
            p_school_id, p_booking_id, v_status, 'Cancelled', p_user_id, v_user_name,
            COALESCE(p_reason, 'Recurring series deleted (' || v_deleted_count || ' occurrences)')
        );
    ELSE
        -- Delete single booking
        UPDATE public.space_bookings
        SET deleted_at = NOW(),
            status = 'Cancelled',
            cancelled_by = p_user_id,
            cancelled_at = NOW(),
            cancellation_reason = COALESCE(p_reason, 'Deleted by user'),
            updated_at = NOW()
        WHERE id = p_booking_id AND school_id = p_school_id;

        v_deleted_count := 1;

        -- Record status history
        INSERT INTO public.space_booking_status_history (
            school_id, booking_id, previous_status, new_status, changed_by, changed_by_name, remarks
        ) VALUES (
            p_school_id, p_booking_id, v_status, 'Cancelled', p_user_id, v_user_name, COALESCE(p_reason, 'Deleted by user')
        );
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Booking deleted successfully',
        'deleted_count', v_deleted_count,
        'booking_id', p_booking_id,
        'booking_ref', v_booking_ref
    );
END;
$$;


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
BEGIN
    v_school_id := (p_payload->>'school_id')::UUID;
    v_room_id := (p_payload->>'room_id')::UUID;
    v_user_id := (p_payload->>'user_id')::UUID;
    
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

    -- Conflict Check
    SELECT * INTO v_conflict
    FROM public.fn_space_booking_check_conflict(
        v_school_id, v_room_id, v_buf_start, v_buf_end, 
        CASE WHEN v_is_new THEN NULL ELSE v_id END
    );

    IF v_conflict.has_conflict THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'CONFLICT',
            'message', 'Selected space has a conflict with ' || v_conflict.conflicting_ref || ' (' || v_conflict.conflicting_title || ')'
        );
    END IF;

    IF v_is_new THEN
        -- Generate Ref
        v_booking_ref := 'BK-' || TO_CHAR(v_booking_date, 'YYYYMM') || '-' || LPAD(FLOOR(RANDOM() * 9000 + 1000)::TEXT, 4, '0');
        v_status := COALESCE(p_payload->>'status', 'Pending');

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
            v_school_id, v_id, NULL, v_status, v_user_id, p_payload->>'organizer_name', 'Initial booking submission'
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
            v_school_id, v_id, v_status, v_status, v_user_id, v_user_name, 'Schedule details modified'
        );
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'booking_id', v_id,
        'booking_ref', v_booking_ref
    );
END;
$$;
