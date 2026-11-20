-- ============================================================================
-- Migration 543: Enforce Approval Visibility and Automatic Approval Conflict Handling
-- ============================================================================
-- 1. In fn_space_booking_get_availability_timeline:
--    Ensure ONLY approved/confirmed bookings appear on the availability timeline grid
--    Unapproved/Pending bookings are strictly NOT visible on the public schedule.
-- 2. In fn_space_booking_check_conflict:
--    Support checking against approved bookings only by default (or all active if flag set).
-- 3. In fn_space_booking_decide_approval:
--    On APPROVE: rigorously check against other approved bookings and blackouts.
--    If conflict exists:
--      - Block approval.
--      - Automatically update status to 'Conflict' (is_approved = FALSE).
--      - Log rejection_reason & status history with details of the conflicting booking.
--      - Return structured conflict payload.
-- 4. In fn_space_booking_list:
--    Ensure 'Conflict' status is properly supported in status filters and 'All'.
-- ============================================================================

-- 1. fn_space_booking_check_conflict
CREATE OR REPLACE FUNCTION public.fn_space_booking_check_conflict(
    p_school_id UUID,
    p_room_id UUID,
    p_start_datetime TIMESTAMPTZ,
    p_end_datetime TIMESTAMPTZ,
    p_exclude_booking_id UUID DEFAULT NULL,
    p_approved_only BOOLEAN DEFAULT TRUE
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
STABLE
AS $$
BEGIN
    -- Check against Blackout Dates first
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
      AND (b.room_id = p_room_id OR b.room_id IS NULL)
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
      AND sb.room_id = p_room_id
      AND sb.deleted_at IS NULL
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


-- 2. fn_space_booking_get_availability_timeline
CREATE OR REPLACE FUNCTION public.fn_space_booking_get_availability_timeline(
    p_school_id UUID,
    p_date DATE,
    p_building_id UUID DEFAULT NULL,
    p_room_type VARCHAR(50) DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
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
                        'duration_minutes', sb.duration_minutes,
                        'organizer_name', sb.organizer_name,
                        'organizer_role', sb.organizer_role,
                        'status', sb.status
                    ) ORDER BY sb.start_datetime ASC
                ) FILTER (WHERE sb.id IS NOT NULL),
                '[]'::JSONB
            ) AS bookings
        FROM public.rooms r
        JOIN public.buildings b ON r.building_id = b.id
        LEFT JOIN public.building_floors f ON r.floor_id = f.id
        LEFT JOIN public.space_bookings sb
            ON sb.room_id = r.id
            AND sb.booking_date = p_date
            AND sb.deleted_at IS NULL
            AND sb.is_approved = TRUE
            AND sb.status IN ('Approved', 'Confirmed', 'Checked In', 'In Use')
        WHERE r.school_id = p_school_id
          AND r.deleted_at IS NULL
          AND r.is_bookable = TRUE
          AND (p_building_id IS NULL OR r.building_id = p_building_id)
          AND (p_room_type IS NULL OR p_room_type = 'All' OR r.room_type ILIKE p_room_type)
        GROUP BY r.id, r.name, r.room_number, r.room_code, r.room_type, r.max_capacity,
                 b.id, b.name, b.code, f.id, f.name
        ORDER BY
            CASE
                WHEN r.name = 'G-101' THEN 1
                WHEN r.name = 'G-102' THEN 2
                WHEN r.name ILIKE '%Seminar Hall%' THEN 3
                WHEN r.name ILIKE '%Conference Room%' THEN 4
                WHEN r.name ILIKE '%Computer Lab - 1%' THEN 5
                ELSE 10
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


-- 3. fn_space_booking_decide_approval
CREATE OR REPLACE FUNCTION public.fn_space_booking_decide_approval(
    p_booking_id UUID,
    p_school_id UUID,
    p_action VARCHAR(30),
    p_user_id UUID,
    p_comments TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_old_status VARCHAR(30);
    v_new_status VARCHAR(30);
    v_user_name VARCHAR(150);
    v_booking RECORD;
    v_conflict RECORD;
BEGIN
    SELECT * INTO v_booking
    FROM public.space_bookings
    WHERE id = p_booking_id AND school_id = p_school_id;

    IF v_booking.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Booking not found');
    END IF;

    v_old_status := v_booking.status;

    SELECT full_name INTO v_user_name
    FROM public.profiles
    WHERE id = p_user_id;

    IF v_user_name IS NULL THEN
        v_user_name := 'Administrator';
    END IF;

    IF UPPER(p_action) = 'APPROVE' THEN
        -- Run conflict detection against all other APPROVED bookings and blackouts
        SELECT * INTO v_conflict
        FROM public.fn_space_booking_check_conflict(
            p_school_id,
            v_booking.room_id,
            v_booking.buffer_start_datetime,
            v_booking.buffer_end_datetime,
            p_booking_id,
            TRUE -- approved_only
        );

        IF v_conflict.has_conflict THEN
            -- Conflict detected! Automatically mark booking status as 'Conflict' and block approval
            UPDATE public.space_bookings SET
                status = 'Conflict',
                is_approved = FALSE,
                rejection_reason = 'Approval conflicted with ' || COALESCE(v_conflict.conflicting_title, 'existing booking') || 
                    ' (' || TO_CHAR(v_conflict.conflicting_start, 'HH12:MI AM') || ' - ' || TO_CHAR(v_conflict.conflicting_end, 'HH12:MI AM') || ')',
                updated_at = NOW()
            WHERE id = p_booking_id;

            UPDATE public.space_booking_approvals SET
                status = 'Conflict',
                approver_user_id = p_user_id,
                comments = 'Automated conflict detection: Space is already booked by ' || COALESCE(v_conflict.conflicting_title, 'another booking'),
                decided_at = NOW()
            WHERE booking_id = p_booking_id;

            INSERT INTO public.space_booking_status_history (
                school_id, booking_id, previous_status, new_status, changed_by, changed_by_name, remarks
            ) VALUES (
                p_school_id, p_booking_id, v_old_status, 'Conflict', p_user_id, v_user_name,
                'Approval blocked due to time slot conflict with ' || COALESCE(v_conflict.conflicting_title, 'approved booking')
            );

            RETURN jsonb_build_object(
                'success', FALSE,
                'conflict', TRUE,
                'booking_id', p_booking_id,
                'previous_status', v_old_status,
                'new_status', 'Conflict',
                'message', 'Cannot approve: Space is already booked by "' || COALESCE(v_conflict.conflicting_title, 'existing booking') || '" (' || TO_CHAR(v_conflict.conflicting_start, 'HH12:MI AM') || ' - ' || TO_CHAR(v_conflict.conflicting_end, 'HH12:MI AM') || ')',
                'conflicting_ref', v_conflict.conflicting_ref,
                'conflicting_title', v_conflict.conflicting_title,
                'conflicting_start', TO_CHAR(v_conflict.conflicting_start, 'HH12:MI AM'),
                'conflicting_end', TO_CHAR(v_conflict.conflicting_end, 'HH12:MI AM')
            );
        END IF;

        v_new_status := 'Approved';

        UPDATE public.space_bookings SET
            status = 'Approved',
            is_approved = TRUE,
            approved_by = p_user_id,
            approved_at = NOW(),
            updated_at = NOW()
        WHERE id = p_booking_id;

        UPDATE public.space_booking_approvals SET
            status = 'Approved',
            approver_user_id = p_user_id,
            comments = p_comments,
            decided_at = NOW()
        WHERE booking_id = p_booking_id;

    ELSIF UPPER(p_action) = 'REJECT' THEN
        v_new_status := 'Rejected';

        UPDATE public.space_bookings SET
            status = 'Rejected',
            is_approved = FALSE,
            rejection_reason = p_comments,
            updated_at = NOW()
        WHERE id = p_booking_id;

        UPDATE public.space_booking_approvals SET
            status = 'Rejected',
            approver_user_id = p_user_id,
            comments = p_comments,
            decided_at = NOW()
        WHERE booking_id = p_booking_id;

    ELSIF UPPER(p_action) = 'CANCEL' THEN
        v_new_status := 'Cancelled';

        UPDATE public.space_bookings SET
            status = 'Cancelled',
            cancelled_by = p_user_id,
            cancelled_at = NOW(),
            cancellation_reason = p_comments,
            updated_at = NOW()
        WHERE id = p_booking_id;
    ELSE
        RETURN jsonb_build_object('success', FALSE, 'message', 'Invalid approval action');
    END IF;

    -- Log Status History
    INSERT INTO public.space_booking_status_history (
        school_id, booking_id, previous_status, new_status, changed_by, changed_by_name, remarks
    ) VALUES (
        p_school_id, p_booking_id, v_old_status, v_new_status, p_user_id, v_user_name, p_comments
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'conflict', FALSE,
        'booking_id', p_booking_id,
        'previous_status', v_old_status,
        'new_status', v_new_status
    );
END;
$$;


-- 4. fn_space_booking_list: support 'Conflict' status
CREATE OR REPLACE FUNCTION public.fn_space_booking_list(
    p_school_id UUID,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_status VARCHAR(30) DEFAULT NULL,
    p_building_id UUID DEFAULT NULL,
    p_room_type VARCHAR(50) DEFAULT NULL,
    p_date_from DATE DEFAULT NULL,
    p_date_to DATE DEFAULT NULL,
    p_search VARCHAR(100) DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_offset INT;
    v_total_records INT;
    v_records JSONB;
BEGIN
    v_offset := GREATEST((p_page - 1) * p_page_size, 0);

    -- Get total count matching criteria
    SELECT COUNT(*) INTO v_total_records
    FROM public.space_bookings sb
    JOIN public.rooms r ON sb.room_id = r.id
    JOIN public.buildings b ON sb.building_id = b.id
    WHERE sb.school_id = p_school_id
      AND sb.deleted_at IS NULL
      AND (
          (p_status IS NULL OR p_status = '' OR p_status = 'All') AND sb.status != 'Cancelled'
          OR (p_status = 'Pending' AND sb.status IN ('Pending', 'Submitted'))
          OR (p_status = 'Approved' AND sb.status IN ('Approved', 'Confirmed', 'Checked In', 'In Use', 'Completed'))
          OR (p_status = 'Rejected' AND sb.status = 'Rejected')
          OR (p_status = 'Conflict' AND sb.status = 'Conflict')
          OR (p_status = 'Cancelled' AND sb.status = 'Cancelled')
          OR (p_status NOT IN ('All', 'Pending', 'Approved', 'Rejected', 'Conflict', 'Cancelled') AND sb.status ILIKE p_status)
      )
      AND (p_building_id IS NULL OR sb.building_id = p_building_id)
      AND (p_room_type IS NULL OR p_room_type = 'All' OR r.room_type ILIKE p_room_type)
      AND (p_date_from IS NULL OR sb.booking_date >= p_date_from)
      AND (p_date_to IS NULL OR sb.booking_date <= p_date_to)
      AND (
          p_search IS NULL OR p_search = '' 
          OR sb.title ILIKE '%' || p_search || '%'
          OR sb.booking_ref ILIKE '%' || p_search || '%'
          OR sb.organizer_name ILIKE '%' || p_search || '%'
          OR r.name ILIKE '%' || p_search || '%'
          OR r.room_number ILIKE '%' || p_search || '%'
      );

    -- Fetch paginated items
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
                'start_time', TO_CHAR(q.start_time, 'HH12:MI AM'),
                'end_time', TO_CHAR(q.end_time, 'HH12:MI AM'),
                'room_id', q.room_id,
                'room_name', q.room_name,
                'room_number', q.room_number,
                'room_type', q.room_type,
                'building_id', q.building_id,
                'building_name', q.building_name,
                'floor_name', q.floor_name,
                'organizer_name', q.organizer_name,
                'organizer_role', q.organizer_role,
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
            sb.status, sb.is_approved, sb.booking_date, sb.start_time, sb.end_time,
            sb.attendee_count, sb.is_recurring, sb.rejection_reason, sb.created_at,
            r.id AS room_id, r.name AS room_name, r.room_number, r.room_type,
            b.id AS building_id, b.name AS building_name,
            f.name AS floor_name,
            sb.organizer_name, sb.organizer_role
        FROM public.space_bookings sb
        JOIN public.rooms r ON sb.room_id = r.id
        JOIN public.buildings b ON sb.building_id = b.id
        LEFT JOIN public.building_floors f ON sb.floor_id = f.id
        WHERE sb.school_id = p_school_id
          AND sb.deleted_at IS NULL
          AND (
              (p_status IS NULL OR p_status = '' OR p_status = 'All') AND sb.status != 'Cancelled'
              OR (p_status = 'Pending' AND sb.status IN ('Pending', 'Submitted'))
              OR (p_status = 'Approved' AND sb.status IN ('Approved', 'Confirmed', 'Checked In', 'In Use', 'Completed'))
              OR (p_status = 'Rejected' AND sb.status = 'Rejected')
              OR (p_status = 'Conflict' AND sb.status = 'Conflict')
              OR (p_status = 'Cancelled' AND sb.status = 'Cancelled')
              OR (p_status NOT IN ('All', 'Pending', 'Approved', 'Rejected', 'Conflict', 'Cancelled') AND sb.status ILIKE p_status)
          )
          AND (p_building_id IS NULL OR sb.building_id = p_building_id)
          AND (p_room_type IS NULL OR p_room_type = 'All' OR r.room_type ILIKE p_room_type)
          AND (p_date_from IS NULL OR sb.booking_date >= p_date_from)
          AND (p_date_to IS NULL OR sb.booking_date <= p_date_to)
          AND (
              p_search IS NULL OR p_search = '' 
              OR sb.title ILIKE '%' || p_search || '%'
              OR sb.booking_ref ILIKE '%' || p_search || '%'
              OR sb.organizer_name ILIKE '%' || p_search || '%'
              OR r.name ILIKE '%' || p_search || '%'
              OR r.room_number ILIKE '%' || p_search || '%'
          )
        ORDER BY sb.booking_date ASC, sb.start_time ASC
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
