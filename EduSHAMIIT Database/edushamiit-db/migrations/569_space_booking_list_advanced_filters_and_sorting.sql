-- ============================================================================
-- Migration 569: Advanced Filters and Server-Side Sorting for Space Booking Requests
-- ============================================================================

-- 1. Drop old conflicting overloads
DROP FUNCTION IF EXISTS public.fn_space_booking_list(uuid, integer, integer, character varying, uuid, character varying, date, date, character varying);
DROP FUNCTION IF EXISTS public.fn_space_booking_list(uuid, character varying, uuid, character varying, character varying, date, date, integer, integer);

-- 2. Create single unified procedure with full filtering & multi-column sorting
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
      AND (p_room_type IS NULL OR p_room_type = '' OR p_room_type = 'All' OR r.room_type ILIKE p_room_type)
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
          OR b.name ILIKE '%' || p_search || '%'
      );

    -- Fetch paginated items with dynamic sorting
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
          AND (p_room_type IS NULL OR p_room_type = '' OR p_room_type = 'All' OR r.room_type ILIKE p_room_type)
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
              OR b.name ILIKE '%' || p_search || '%'
          )
        ORDER BY
            -- Ascending Cases
            CASE WHEN NOT v_is_desc AND (v_sort_col = 'title') THEN LOWER(sb.title) END ASC,
            CASE WHEN NOT v_is_desc AND (v_sort_col IN ('room_name', 'space')) THEN LOWER(r.name) END ASC,
            CASE WHEN NOT v_is_desc AND (v_sort_col IN ('organizer_name', 'requested_by')) THEN LOWER(sb.organizer_name) END ASC,
            CASE WHEN NOT v_is_desc AND (v_sort_col = 'purpose') THEN LOWER(sb.purpose) END ASC,
            CASE WHEN NOT v_is_desc AND (v_sort_col = 'status') THEN LOWER(sb.status) END ASC,
            CASE WHEN NOT v_is_desc AND (v_sort_col = 'booking_date') THEN sb.booking_date END ASC,
            CASE WHEN NOT v_is_desc AND (v_sort_col = 'booking_date') THEN sb.start_time END ASC,
            CASE WHEN NOT v_is_desc AND (v_sort_col = 'created_at') THEN sb.created_at END ASC,

            -- Descending Cases
            CASE WHEN v_is_desc AND (v_sort_col = 'title') THEN LOWER(sb.title) END DESC,
            CASE WHEN v_is_desc AND (v_sort_col IN ('room_name', 'space')) THEN LOWER(r.name) END DESC,
            CASE WHEN v_is_desc AND (v_sort_col IN ('organizer_name', 'requested_by')) THEN LOWER(sb.organizer_name) END DESC,
            CASE WHEN v_is_desc AND (v_sort_col = 'purpose') THEN LOWER(sb.purpose) END DESC,
            CASE WHEN v_is_desc AND (v_sort_col = 'status') THEN LOWER(sb.status) END DESC,
            CASE WHEN v_is_desc AND (v_sort_col = 'booking_date') THEN sb.booking_date END DESC,
            CASE WHEN v_is_desc AND (v_sort_col = 'booking_date') THEN sb.start_time END DESC,
            CASE WHEN v_is_desc AND (v_sort_col = 'created_at') THEN sb.created_at END DESC,

            -- Fallback tiebreaker
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
