-- ============================================================================
-- Migration 346: Segregate Circulation Requests (Issue/Return/Renew) to Issue/Return Tab
-- and Preserve Global Requests Tab for Generic Catalog Acquisition Requests
-- ============================================================================

-- 1. CLEANUP PREVIOUS CIRCULATION TEST ROWS FROM library_requests
DELETE FROM public.library_requests
WHERE request_type IN ('BOOK_ISSUE', 'ISSUE', 'RENEWAL', 'BOOK_RETURN', 'RETURN');

-- ============================================================================
-- 2. ENHANCE fn_library_list_requests
-- Excludes circulation transactions so only generic material requests appear
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_list_requests(
    p_school_id uuid,
    p_search text DEFAULT NULL::text,
    p_subtab text DEFAULT 'ALL'::text,
    p_request_type text DEFAULT 'ALL'::text,
    p_status text DEFAULT 'ALL'::text,
    p_priority text DEFAULT 'ALL'::text,
    p_requested_by_role text DEFAULT 'ALL'::text,
    p_date_from date DEFAULT NULL::date,
    p_date_to date DEFAULT NULL::date,
    p_page integer DEFAULT 1,
    p_page_size integer DEFAULT 10,
    p_sort_by text DEFAULT 'created_at'::text,
    p_sort_order text DEFAULT 'DESC'::text,
    p_current_user_id uuid DEFAULT NULL::uuid,
    p_current_user_role text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_offset INT;
    v_total INT := 0;
    v_items JSONB;
    v_is_requester_only BOOLEAN := false;
BEGIN
    IF p_current_user_role IS NOT NULL AND LOWER(p_current_user_role) IN ('student', 'parent') THEN
        v_is_requester_only := true;
    END IF;

    v_offset := (p_page - 1) * p_page_size;

    -- Count total matching records
    SELECT COUNT(*)
    INTO v_total
    FROM public.library_requests r
    LEFT JOIN public.library_members m ON r.member_id = m.id
    LEFT JOIN public.profiles p ON (r.requester_user_id = p.id OR r.student_id = p.id OR m.profile_id = p.id)
    LEFT JOIN public.library_books b ON r.book_id = b.id
    LEFT JOIN public.profiles a ON r.assigned_to = a.id
    WHERE r.school_id = p_school_id
      -- Strictly exclude circulation requests
      AND (r.borrow_id IS NULL)
      AND UPPER(COALESCE(r.request_type, '')) NOT IN (
          'BOOK_ISSUE', 'ISSUE', 'RENEWAL', 'BOOK_RETURN', 'RETURN', 
          'REQUEST_TO_ISSUE', 'RENEW_REQUEST', 'RETURN_REQUEST'
      )
      AND (
          NOT v_is_requester_only
          OR r.requester_user_id = p_current_user_id
          OR r.student_id = p_current_user_id
      )
      -- Subtab Filter
      AND (
          p_subtab IS NULL
          OR UPPER(p_subtab) = 'ALL'
          OR (UPPER(p_subtab) = 'MY_REQUESTS' AND (r.requester_user_id = p_current_user_id OR r.student_id = p_current_user_id))
          OR (UPPER(p_subtab) = 'NEEDS_REVIEW' AND UPPER(r.status) IN ('NEW', 'PENDING'))
          OR (UPPER(p_subtab) = 'ASSIGNED_TO_ME' AND r.assigned_to = p_current_user_id)
          OR (UPPER(p_subtab) = 'NEW' AND UPPER(r.status) IN ('NEW', 'PENDING'))
          OR (UPPER(p_subtab) = 'ACTIVE' AND UPPER(r.status) = 'ACTIVE')
          OR (UPPER(p_subtab) = 'IN_PROGRESS' AND UPPER(r.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS'))
          OR (UPPER(p_subtab) = 'RESOLVED' AND UPPER(r.status) = 'RESOLVED')
          OR (UPPER(p_subtab) = 'COMPLETED' AND UPPER(r.status) = 'COMPLETED')
          OR (UPPER(p_subtab) = 'REJECTED' AND UPPER(r.status) = 'REJECTED')
          OR (UPPER(p_subtab) = 'CANCELED' AND UPPER(r.status) IN ('CANCELED', 'CANCELLED'))
      )
      -- Type Filter
      AND (
          p_request_type IS NULL
          OR UPPER(p_request_type) = 'ALL'
          OR UPPER(COALESCE(r.request_type, 'Book')) = UPPER(p_request_type)
      )
      -- Status Filter
      AND (
          p_status IS NULL
          OR UPPER(p_status) = 'ALL'
          OR (UPPER(p_status) = 'NEW' AND UPPER(r.status) IN ('NEW', 'PENDING'))
          OR (UPPER(p_status) = 'IN_PROGRESS' AND UPPER(r.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS'))
          OR (UPPER(p_status) = 'CANCELLED' AND UPPER(r.status) IN ('CANCELED', 'CANCELLED'))
          OR UPPER(r.status) = UPPER(p_status)
      )
      -- Priority Filter
      AND (
          p_priority IS NULL
          OR UPPER(p_priority) = 'ALL'
          OR UPPER(COALESCE(r.priority, 'NORMAL')) = UPPER(p_priority)
      )
      -- Role Filter
      AND (
          p_requested_by_role IS NULL
          OR UPPER(p_requested_by_role) = 'ALL'
          OR UPPER(COALESCE(p.role, 'student')) = UPPER(p_requested_by_role)
          OR UPPER(REPLACE(COALESCE(p.role, 'student'), '_', ' ')) = UPPER(REPLACE(p_requested_by_role, '_', ' '))
          OR EXISTS (
              SELECT 1 FROM public.app_roles ar
              WHERE UPPER(COALESCE(ar.status, 'ACTIVE')) = 'ACTIVE'
                AND (ar.name = p.role OR ar.code = p.role)
                AND (
                    UPPER(ar.name) = UPPER(p_requested_by_role)
                    OR UPPER(ar.display_name) = UPPER(p_requested_by_role)
                    OR UPPER(ar.code) = UPPER(p_requested_by_role)
                    OR UPPER(REPLACE(ar.name, '_', ' ')) = UPPER(REPLACE(p_requested_by_role, '_', ' '))
                )
          )
      )
      -- Date Range Filter
      AND (p_date_from IS NULL OR r.created_at::date >= p_date_from)
      AND (p_date_to IS NULL OR r.created_at::date <= p_date_to)
      -- Search query
      AND (
          p_search IS NULL
          OR r.title ILIKE '%' || p_search || '%'
          OR COALESCE(r.request_number, '') ILIKE '%' || p_search || '%'
          OR COALESCE(r.author, '') ILIKE '%' || p_search || '%'
          OR COALESCE(r.isbn, '') ILIKE '%' || p_search || '%'
          OR COALESCE(p.full_name, '') ILIKE '%' || p_search || '%'
          OR COALESCE(m.member_code, '') ILIKE '%' || p_search || '%'
      );

    -- Fetch paginated items
    SELECT jsonb_agg(to_jsonb(t))
    INTO v_items
    FROM (
        SELECT 
            r.id,
            COALESCE(r.request_number, 'REQ-' || LPAD(r.id::text, 6, '0')) AS request_number,
            r.title,
            COALESCE(r.author, b.author, 'Unknown') AS author,
            r.isbn,
            r.publisher,
            r.edition,
            r.language,
            COALESCE(r.preferred_format, 'Physical') AS preferred_format,
            r.quantity,
            r.required_by,
            COALESCE(r.category_code, 'BOOK') AS category_code,
            COALESCE(r.request_type, 'Book') AS request_type,
            COALESCE(r.priority, 'Normal') AS priority,
            r.status,
            COALESCE(r.availability_status, 'CHECKING') AS availability_status,
            COALESCE(r.approval_status, 'NOT_REQUIRED') AS approval_status,
            r.reason,
            r.description,
            r.rejection_reason,
            r.cancellation_reason,
            r.clarification_requested,
            r.clarification_message,
            r.clarification_response,
            r.created_at,
            r.updated_at,
            r.resolved_at,
            r.completed_at,
            -- Requester details
            COALESCE(p.id, r.requester_user_id) AS requester_id,
            COALESCE(p.full_name, 'Member') AS requester_name,
            COALESCE(p.email, '') AS requester_email,
            COALESCE(p.avatar_url, '') AS requester_avatar,
            COALESCE(p.role, 'Student') AS requester_role,
            COALESCE(p.class, p.department, 'Class 9-A') AS requester_class,
            m.member_code,
            -- Book details if linked
            b.id AS book_id,
            b.title AS linked_book_title,
            COALESCE(b.cover_url, '') AS cover_url,
            COALESCE(b.available_copies, 0) AS book_available_copies,
            COALESCE(b.total_copies, 0) AS book_total_copies,
            COALESCE(b.shelf_location, 'A-12') AS shelf_location,
            -- Assigned Librarian details
            a.id AS assigned_to_id,
            COALESCE(a.full_name, 'Unassigned') AS assigned_to_name,
            COALESCE(a.avatar_url, '') AS assigned_to_avatar
        FROM public.library_requests r
        LEFT JOIN public.library_members m ON r.member_id = m.id
        LEFT JOIN public.profiles p ON (r.requester_user_id = p.id OR r.student_id = p.id OR m.profile_id = p.id)
        LEFT JOIN public.library_books b ON r.book_id = b.id
        LEFT JOIN public.profiles a ON r.assigned_to = a.id
        WHERE r.school_id = p_school_id
          -- Strictly exclude circulation requests
          AND (r.borrow_id IS NULL)
          AND UPPER(COALESCE(r.request_type, '')) NOT IN (
              'BOOK_ISSUE', 'ISSUE', 'RENEWAL', 'BOOK_RETURN', 'RETURN', 
              'REQUEST_TO_ISSUE', 'RENEW_REQUEST', 'RETURN_REQUEST'
          )
          AND (
              NOT v_is_requester_only
              OR r.requester_user_id = p_current_user_id
              OR r.student_id = p_current_user_id
          )
          -- Subtab Filter
          AND (
              p_subtab IS NULL
              OR UPPER(p_subtab) = 'ALL'
              OR (UPPER(p_subtab) = 'MY_REQUESTS' AND (r.requester_user_id = p_current_user_id OR r.student_id = p_current_user_id))
              OR (UPPER(p_subtab) = 'NEEDS_REVIEW' AND UPPER(r.status) IN ('NEW', 'PENDING'))
              OR (UPPER(p_subtab) = 'ASSIGNED_TO_ME' AND r.assigned_to = p_current_user_id)
              OR (UPPER(p_subtab) = 'NEW' AND UPPER(r.status) IN ('NEW', 'PENDING'))
              OR (UPPER(p_subtab) = 'ACTIVE' AND UPPER(r.status) = 'ACTIVE')
              OR (UPPER(p_subtab) = 'IN_PROGRESS' AND UPPER(r.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS'))
              OR (UPPER(p_subtab) = 'RESOLVED' AND UPPER(r.status) = 'RESOLVED')
              OR (UPPER(p_subtab) = 'COMPLETED' AND UPPER(r.status) = 'COMPLETED')
              OR (UPPER(p_subtab) = 'REJECTED' AND UPPER(r.status) = 'REJECTED')
              OR (UPPER(p_subtab) = 'CANCELED' AND UPPER(r.status) IN ('CANCELED', 'CANCELLED'))
          )
          -- Type Filter
          AND (
              p_request_type IS NULL
              OR UPPER(p_request_type) = 'ALL'
              OR UPPER(COALESCE(r.request_type, 'Book')) = UPPER(p_request_type)
          )
          -- Status Filter
          AND (
              p_status IS NULL
              OR UPPER(p_status) = 'ALL'
              OR (UPPER(p_status) = 'NEW' AND UPPER(r.status) IN ('NEW', 'PENDING'))
              OR (UPPER(p_status) = 'IN_PROGRESS' AND UPPER(r.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS'))
              OR (UPPER(p_status) = 'CANCELLED' AND UPPER(r.status) IN ('CANCELED', 'CANCELLED'))
              OR UPPER(r.status) = UPPER(p_status)
          )
          -- Priority Filter
          AND (
              p_priority IS NULL
              OR UPPER(p_priority) = 'ALL'
              OR UPPER(COALESCE(r.priority, 'NORMAL')) = UPPER(p_priority)
          )
          -- Role Filter
          AND (
              p_requested_by_role IS NULL
              OR UPPER(p_requested_by_role) = 'ALL'
              OR UPPER(COALESCE(p.role, 'student')) = UPPER(p_requested_by_role)
              OR UPPER(REPLACE(COALESCE(p.role, 'student'), '_', ' ')) = UPPER(REPLACE(p_requested_by_role, '_', ' '))
              OR EXISTS (
                  SELECT 1 FROM public.app_roles ar
                  WHERE UPPER(COALESCE(ar.status, 'ACTIVE')) = 'ACTIVE'
                    AND (ar.name = p.role OR ar.code = p.role)
                    AND (
                        UPPER(ar.name) = UPPER(p_requested_by_role)
                        OR UPPER(ar.display_name) = UPPER(p_requested_by_role)
                        OR UPPER(ar.code) = UPPER(p_requested_by_role)
                        OR UPPER(REPLACE(ar.name, '_', ' ')) = UPPER(REPLACE(p_requested_by_role, '_', ' '))
                    )
              )
          )
          -- Date Range Filter
          AND (p_date_from IS NULL OR r.created_at::date >= p_date_from)
          AND (p_date_to IS NULL OR r.created_at::date <= p_date_to)
          -- Search query
          AND (
              p_search IS NULL
              OR r.title ILIKE '%' || p_search || '%'
              OR COALESCE(r.request_number, '') ILIKE '%' || p_search || '%'
              OR COALESCE(r.author, '') ILIKE '%' || p_search || '%'
              OR COALESCE(r.isbn, '') ILIKE '%' || p_search || '%'
              OR COALESCE(p.full_name, '') ILIKE '%' || p_search || '%'
              OR COALESCE(m.member_code, '') ILIKE '%' || p_search || '%'
          )
        ORDER BY
            CASE WHEN p_sort_by = 'request_number' AND p_sort_order = 'ASC' THEN r.request_number END ASC,
            CASE WHEN p_sort_by = 'request_number' AND p_sort_order = 'DESC' THEN r.request_number END DESC,
            CASE WHEN p_sort_by = 'title' AND p_sort_order = 'ASC' THEN r.title END ASC,
            CASE WHEN p_sort_by = 'title' AND p_sort_order = 'DESC' THEN r.title END DESC,
            CASE WHEN p_sort_by = 'status' AND p_sort_order = 'ASC' THEN r.status END ASC,
            CASE WHEN p_sort_by = 'status' AND p_sort_order = 'DESC' THEN r.status END DESC,
            CASE WHEN p_sort_by = 'created_at' AND p_sort_order = 'ASC' THEN r.created_at END ASC,
            r.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) t;

    RETURN jsonb_build_object(
        'items', COALESCE(v_items, '[]'::jsonb),
        'total', v_total,
        'page', p_page,
        'page_size', p_page_size,
        'total_pages', CEIL(v_total::numeric / GREATEST(p_page_size, 1)::numeric)::int
    );
END;
$function$;

-- ============================================================================
-- 3. ENHANCE fn_library_get_request_kpis
-- Only counts and aggregates generic material/acquisition requests
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_get_request_kpis(
    p_school_id uuid,
    p_user_id uuid DEFAULT NULL::uuid,
    p_role text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_total BIGINT := 0;
    v_new BIGINT := 0;
    v_in_progress BIGINT := 0;
    v_resolved BIGINT := 0;
    v_rejected BIGINT := 0;
    v_canceled BIGINT := 0;
    v_type_counts JSONB;
    v_status_dist JSONB;
    v_recent_requests JSONB;
    v_is_requester_only BOOLEAN := false;
BEGIN
    IF p_role IS NOT NULL AND LOWER(p_role) IN ('student', 'parent') THEN
        v_is_requester_only := true;
    END IF;

    -- Total & Status counts
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE UPPER(r.status) IN ('NEW', 'PENDING')),
        COUNT(*) FILTER (WHERE UPPER(r.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS')),
        COUNT(*) FILTER (WHERE UPPER(r.status) IN ('RESOLVED', 'COMPLETED')),
        COUNT(*) FILTER (WHERE UPPER(r.status) = 'REJECTED'),
        COUNT(*) FILTER (WHERE UPPER(r.status) IN ('CANCELED', 'CANCELLED'))
    INTO v_total, v_new, v_in_progress, v_resolved, v_rejected, v_canceled
    FROM public.library_requests r
    WHERE r.school_id = p_school_id
      AND (NOT v_is_requester_only OR r.requester_user_id = p_user_id OR r.student_id = p_user_id)
      -- Strictly exclude circulation requests
      AND (r.borrow_id IS NULL)
      AND UPPER(COALESCE(r.request_type, '')) NOT IN (
          'BOOK_ISSUE', 'ISSUE', 'RENEWAL', 'BOOK_RETURN', 'RETURN', 
          'REQUEST_TO_ISSUE', 'RENEW_REQUEST', 'RETURN_REQUEST'
      );

    -- Request Types Breakdown (Deduplicated lookup types + existing generic types with real counts)
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'type', t.type_name,
        'count', t.type_count
    )), '[]'::jsonb)
    INTO v_type_counts
    FROM (
        WITH raw_types AS (
            SELECT lv.value_name AS type_name, lv.sort_order AS sort_ord
            FROM public.lookup_values lv
            JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
            WHERE lk.key_code = 'LIBRARY_REQUEST_TYPE'
              AND (lv.school_id = p_school_id OR lv.school_id IS NULL)
              AND lv.status = 'ACTIVE'
              AND UPPER(lv.value_name) NOT IN (
                  'BOOK_ISSUE', 'ISSUE', 'RENEWAL', 'BOOK_RETURN', 'RETURN', 
                  'REQUEST_TO_ISSUE', 'RENEW_REQUEST', 'RETURN_REQUEST'
              )
            UNION ALL
            SELECT DISTINCT r.request_type AS type_name, 999 AS sort_ord
            FROM public.library_requests r
            WHERE r.school_id = p_school_id 
              AND r.request_type IS NOT NULL 
              AND r.request_type != ''
              AND (r.borrow_id IS NULL)
              AND UPPER(r.request_type) NOT IN (
                  'BOOK_ISSUE', 'ISSUE', 'RENEWAL', 'BOOK_RETURN', 'RETURN', 
                  'REQUEST_TO_ISSUE', 'RENEW_REQUEST', 'RETURN_REQUEST'
              )
        ),
        all_types AS (
            SELECT type_name, MIN(sort_ord) AS sort_ord
            FROM raw_types
            GROUP BY type_name
        )
        SELECT 
            at.type_name,
            COUNT(r.id) AS type_count
        FROM all_types at
        LEFT JOIN public.library_requests r ON (
            (LOWER(TRIM(r.request_type)) = LOWER(TRIM(at.type_name)))
            AND r.school_id = p_school_id
            AND (NOT v_is_requester_only OR r.requester_user_id = p_user_id OR r.student_id = p_user_id)
            AND (r.borrow_id IS NULL)
            AND UPPER(COALESCE(r.request_type, '')) NOT IN (
                'BOOK_ISSUE', 'ISSUE', 'RENEWAL', 'BOOK_RETURN', 'RETURN', 
                'REQUEST_TO_ISSUE', 'RENEW_REQUEST', 'RETURN_REQUEST'
            )
        )
        GROUP BY at.type_name, at.sort_ord
        ORDER BY at.sort_ord ASC, type_count DESC, at.type_name ASC
    ) t;

    -- Status Distribution with Percentages calculated directly from DB
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'status', s.status_name,
        'count', s.status_count,
        'percentage', CASE WHEN v_total > 0 THEN ROUND((s.status_count::numeric / v_total::numeric) * 100, 1) ELSE 0.0 END
    )), '[]'::jsonb)
    INTO v_status_dist
    FROM (
        SELECT 
            CASE 
                WHEN UPPER(r.status) IN ('NEW', 'PENDING') THEN 'New'
                WHEN UPPER(r.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS') THEN 'In Progress'
                WHEN UPPER(r.status) IN ('RESOLVED', 'COMPLETED') THEN 'Resolved'
                WHEN UPPER(r.status) = 'REJECTED' THEN 'Rejected'
                WHEN UPPER(r.status) IN ('CANCELED', 'CANCELLED') THEN 'Cancelled'
                ELSE INITCAP(r.status)
            END AS status_name,
            COUNT(*) AS status_count
        FROM public.library_requests r
        WHERE r.school_id = p_school_id
          AND (NOT v_is_requester_only OR r.requester_user_id = p_user_id OR r.student_id = p_user_id)
          AND (r.borrow_id IS NULL)
          AND UPPER(COALESCE(r.request_type, '')) NOT IN (
              'BOOK_ISSUE', 'ISSUE', 'RENEWAL', 'BOOK_RETURN', 'RETURN', 
              'REQUEST_TO_ISSUE', 'RENEW_REQUEST', 'RETURN_REQUEST'
          )
        GROUP BY 1
        ORDER BY status_count DESC
    ) s;

    -- Recent Requests for Side Panel (real records from DB)
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', r.id,
        'request_number', COALESCE(r.request_number, 'REQ-' || LPAD(r.id::text, 6, '0')),
        'title', r.title,
        'author', r.author,
        'requester_name', COALESCE(p.full_name, 'Member'),
        'request_type', COALESCE(r.request_type, 'Book'),
        'status', r.status,
        'priority', COALESCE(r.priority, 'Normal'),
        'created_at', r.created_at
    )), '[]'::jsonb)
    INTO v_recent_requests
    FROM (
        SELECT r.*
        FROM public.library_requests r
        WHERE r.school_id = p_school_id
          AND (NOT v_is_requester_only OR r.requester_user_id = p_user_id OR r.student_id = p_user_id)
          AND (r.borrow_id IS NULL)
          AND UPPER(COALESCE(r.request_type, '')) NOT IN (
              'BOOK_ISSUE', 'ISSUE', 'RENEWAL', 'BOOK_RETURN', 'RETURN', 
              'REQUEST_TO_ISSUE', 'RENEW_REQUEST', 'RETURN_REQUEST'
          )
        ORDER BY r.created_at DESC
        LIMIT 5
    ) r
    LEFT JOIN public.profiles p ON (r.requester_user_id = p.id OR r.student_id = p.id);

    RETURN jsonb_build_object(
        'total', v_total,
        'total_requests', v_total,
        'new', v_new,
        'new_requests', v_new,
        'in_progress', v_in_progress,
        'resolved', v_resolved,
        'rejected', v_rejected,
        'canceled', v_canceled,
        'type_counts', COALESCE(v_type_counts, '[]'::jsonb),
        'status_distribution', COALESCE(v_status_dist, '[]'::jsonb),
        'recent_requests', COALESCE(v_recent_requests, '[]'::jsonb)
    );
END;
$function$;

-- ============================================================================
-- 4. UPDATE fn_library_raise_issue_request
-- Creates circulation borrow transaction ONLY (does not pollute library_requests)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_raise_issue_request(
    p_school_id UUID,
    p_user_id UUID,
    p_book_id UUID,
    p_required_by DATE DEFAULT NULL,
    p_reason TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_preferred_format TEXT DEFAULT 'Physical Book'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_book_title VARCHAR(255);
    v_book_author VARCHAR(255);
    v_user_role VARCHAR(50);
    v_user_name VARCHAR(150);
    v_member_id UUID;
    v_member_code VARCHAR(50);
    v_txn_code VARCHAR(50);
    v_borrow_id UUID;
BEGIN
    -- 1. Validate Book
    SELECT title, author
    INTO v_book_title, v_book_author
    FROM public.library_books
    WHERE id = p_book_id AND school_id = p_school_id;

    IF v_book_title IS NULL THEN
        RAISE EXCEPTION 'Book not found in library catalogue.';
    END IF;

    -- 2. Validate / Fetch Profile
    SELECT role, full_name INTO v_user_role, v_user_name
    FROM public.profiles
    WHERE id = p_user_id;

    -- 3. Resolve or Auto-Create Library Member
    SELECT id, member_code INTO v_member_id, v_member_code
    FROM public.library_members
    WHERE school_id = p_school_id AND profile_id = p_user_id
    LIMIT 1;

    IF v_member_id IS NULL THEN
        v_member_code := 'LIB-' || LPAD(SUBSTRING(p_user_id::text FROM 1 FOR 4), 4, '0');
        INSERT INTO public.library_members (
            school_id, profile_id, member_code, membership_type, status, borrowing_limit, created_at
        ) VALUES (
            p_school_id, p_user_id, v_member_code, 
            CASE WHEN LOWER(COALESCE(v_user_role, 'student')) = 'teacher' THEN 'Faculty' ELSE 'Student' END,
            'ACTIVE', 5, NOW()
        )
        RETURNING id INTO v_member_id;
    END IF;

    -- 4. Generate Codes
    v_txn_code := 'TXN-REQ-' || LPAD(FLOOR(RANDOM() * 9000 + 1000)::text, 4, '0');
    v_borrow_id := gen_random_uuid();

    -- 5. Insert Circulation Borrow Record directly (Goes to Issue/Return -> Requests subtab)
    INSERT INTO public.library_borrows (
        id, school_id, member_id, student_id, book_id, transaction_code,
        transaction_type, status, issue_date, due_date, due_at, notes, created_at, updated_at
    ) VALUES (
        v_borrow_id, p_school_id, v_member_id, p_user_id, p_book_id, v_txn_code,
        'REQUEST_TO_ISSUE', 'PENDING', CURRENT_DATE, 
        COALESCE(p_required_by, CURRENT_DATE + 14),
        COALESCE(p_required_by::timestamp with time zone, NOW() + INTERVAL '14 days'),
        COALESCE(p_reason, 'Borrow request raised by ' || COALESCE(v_user_name, 'member')),
        NOW(), NOW()
    );

    -- 6. Log Circulation Activity
    INSERT INTO public.library_circulation_activities (
        school_id, activity_type, title, description, borrow_id, performed_by, created_at
    ) VALUES (
        p_school_id, 'REQUEST', 'Book Issue Request Raised',
        COALESCE(v_user_name, 'Member') || ' requested to borrow "' || v_book_title || '"',
        v_borrow_id, p_user_id, NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Book issue request submitted successfully.',
        'borrow_id', v_borrow_id,
        'transaction_code', v_txn_code,
        'request_id', v_borrow_id,
        'request_number', v_txn_code
    );
END;
$$;

-- ============================================================================
-- 5. UPDATE fn_library_raise_renew_request
-- Updates circulation borrow transaction directly (does not pollute library_requests)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_raise_renew_request(
    p_school_id UUID,
    p_borrow_id UUID,
    p_user_id UUID,
    p_reason TEXT DEFAULT NULL,
    p_new_due_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_borrow RECORD;
    v_user_name VARCHAR(150);
BEGIN
    SELECT br.*, b.title AS b_title, b.author AS b_author, p.full_name AS m_name
    INTO v_borrow
    FROM public.library_borrows br
    LEFT JOIN public.library_books b ON br.book_id = b.id
    LEFT JOIN public.library_members m ON br.member_id = m.id
    LEFT JOIN public.profiles p ON (m.profile_id = p.id OR br.student_id = p.id)
    WHERE br.id = p_borrow_id AND br.school_id = p_school_id;

    IF v_borrow.id IS NULL THEN
        RAISE EXCEPTION 'Loan record not found.';
    END IF;

    -- Strict logical validation: MUST be in an issued state!
    IF UPPER(COALESCE(v_borrow.status, '')) NOT IN ('ISSUED', 'BORROWED', 'OVERDUE', 'RENEWED') THEN
        RAISE EXCEPTION 'Cannot request renewal. Book must be in an issued/active borrowed state (Current status: "%").', v_borrow.status;
    END IF;

    -- Cannot renew if return request is already pending
    IF UPPER(COALESCE(v_borrow.status, '')) = 'PENDING_RETURN' OR UPPER(COALESCE(v_borrow.transaction_type, '')) = 'RETURN_REQUEST' THEN
        RAISE EXCEPTION 'Cannot request renewal while a return request is already pending.';
    END IF;

    -- Check renewal limits
    IF COALESCE(v_borrow.renewals_used, 0) >= COALESCE(v_borrow.max_renewals, 2) THEN
        RAISE EXCEPTION 'Maximum renewal limit of % reached for this loan.', v_borrow.max_renewals;
    END IF;

    v_user_name := COALESCE(v_borrow.m_name, 'Member');

    -- Transition status to PENDING_RENEW
    UPDATE public.library_borrows
    SET status = 'PENDING_RENEW',
        transaction_type = 'RENEW_REQUEST',
        notes = COALESCE(p_reason, notes),
        due_date = COALESCE(p_new_due_date, due_date),
        due_at = COALESCE(p_new_due_date::timestamp with time zone, due_at),
        updated_at = NOW()
    WHERE id = p_borrow_id;

    -- Log Activity
    INSERT INTO public.library_circulation_activities (
        school_id, activity_type, title, description, borrow_id, performed_by, created_at
    ) VALUES (
        p_school_id, 'RENEW_REQUEST', 'Book Renewal Requested',
        v_user_name || ' requested renewal for "' || v_borrow.b_title || '": ' || COALESCE(p_reason, 'Loan extension requested'),
        p_borrow_id, p_user_id, NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Renewal request submitted successfully.',
        'borrow_id', p_borrow_id
    );
END;
$$;

-- ============================================================================
-- 6. ENHANCE fn_library_list_transactions
-- In subtab = 'REQUESTS', precisely captures pending issue, renewal, and return requests
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_list_transactions(
    p_school_id uuid,
    p_search text DEFAULT NULL::text,
    p_search_in text DEFAULT 'All Transactions'::text,
    p_subtab text DEFAULT 'ALL'::text,
    p_status text DEFAULT 'ALL'::text,
    p_transaction_type text DEFAULT 'ALL'::text,
    p_date_from date DEFAULT NULL::date,
    p_date_to date DEFAULT NULL::date,
    p_page integer DEFAULT 1,
    p_page_size integer DEFAULT 10,
    p_sort_by text DEFAULT 'created_at'::text,
    p_sort_order text DEFAULT 'DESC'::text,
    p_fine_status text DEFAULT NULL::text,
    p_member_role text DEFAULT NULL::text,
    p_date_field text DEFAULT 'issue_date'::text,
    p_current_user_id uuid DEFAULT NULL::uuid,
    p_current_user_role text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_where TEXT := 'br.school_id = ' || quote_literal(p_school_id);
    v_offset INT;
    v_total INT;
    v_items JSONB;
    v_counts JSONB;
    v_date_col TEXT := 'br.issue_date';
    v_is_user_scoped BOOLEAN := false;
    v_member_id UUID := NULL;
    v_count_all INT := 0;
    v_count_issued INT := 0;
    v_count_returned INT := 0;
    v_count_overdue INT := 0;
    v_count_requests INT := 0;
    v_count_renewed INT := 0;
    v_count_lost_damaged INT := 0;
BEGIN
    v_offset := GREATEST(0, (p_page - 1) * p_page_size);

    -- Role scoping check
    IF p_current_user_role IS NOT NULL AND LOWER(p_current_user_role) IN ('student', 'teacher', 'parent') THEN
        v_is_user_scoped := true;
        SELECT id INTO v_member_id FROM public.library_members WHERE school_id = p_school_id AND profile_id = p_current_user_id LIMIT 1;
        
        IF v_member_id IS NOT NULL THEN
            v_where := v_where || format(' AND (br.member_id = %L OR br.student_id = %L OR m.profile_id = %L OR br.issued_by = %L)', v_member_id, p_current_user_id, p_current_user_id, p_current_user_id);
        ELSE
            v_where := v_where || format(' AND (br.student_id = %L OR m.profile_id = %L OR br.issued_by = %L)', p_current_user_id, p_current_user_id, p_current_user_id);
        END IF;
    END IF;

    IF p_date_field = 'due_date' THEN
        v_date_col := 'br.due_date';
    ELSIF p_date_field = 'return_date' THEN
        v_date_col := 'br.return_date';
    ELSE
        v_date_col := 'br.issue_date';
    END IF;

    -- 1. Search filter
    IF p_search IS NOT NULL AND trim(p_search) != '' THEN
        IF p_search_in = 'Member Name' THEN
            v_where := v_where || format(' AND p.full_name ILIKE %L', '%' || trim(p_search) || '%');
        ELSIF p_search_in = 'Member Code' THEN
            v_where := v_where || format(' AND m.member_code ILIKE %L', '%' || trim(p_search) || '%');
        ELSIF p_search_in = 'Book Title' THEN
            v_where := v_where || format(' AND b.title ILIKE %L', '%' || trim(p_search) || '%');
        ELSIF p_search_in = 'ISBN' THEN
            v_where := v_where || format(' AND (b.isbn13 ILIKE %L OR b.isbn10 ILIKE %L OR b.isbn ILIKE %L)', '%' || trim(p_search) || '%', '%' || trim(p_search) || '%', '%' || trim(p_search) || '%');
        ELSIF p_search_in = 'Barcode' THEN
            v_where := v_where || format(' AND (c.barcode ILIKE %L OR c.accession_number ILIKE %L)', '%' || trim(p_search) || '%', '%' || trim(p_search) || '%');
        ELSIF p_search_in = 'Transaction ID' THEN
            v_where := v_where || format(' AND (br.transaction_code ILIKE %L OR br.id::text ILIKE %L)', '%' || trim(p_search) || '%', '%' || trim(p_search) || '%');
        ELSE
            v_where := v_where || format(' AND (br.transaction_code ILIKE %L OR p.full_name ILIKE %L OR m.member_code ILIKE %L OR b.title ILIKE %L OR b.isbn13 ILIKE %L OR b.isbn10 ILIKE %L OR c.barcode ILIKE %L OR c.accession_number ILIKE %L OR p.phone ILIKE %L)',
                '%' || trim(p_search) || '%', '%' || trim(p_search) || '%', '%' || trim(p_search) || '%', '%' || trim(p_search) || '%', '%' || trim(p_search) || '%', '%' || trim(p_search) || '%', '%' || trim(p_search) || '%', '%' || trim(p_search) || '%', '%' || trim(p_search) || '%'
            );
        END IF;
    END IF;

    -- 2. Subtab Filter
    IF p_subtab IS NOT NULL AND p_subtab != 'ALL' THEN
        IF p_subtab = 'ISSUED' THEN
            v_where := v_where || ' AND (br.status = ''ISSUED'' AND (br.due_date >= CURRENT_DATE OR br.due_date IS NULL))';
        ELSIF p_subtab = 'ISSUED_TODAY' THEN
            v_where := v_where || ' AND (br.status = ''ISSUED'' OR br.status = ''RENEWED'' OR br.issue_date = CURRENT_DATE OR br.borrowed_at::date = CURRENT_DATE)';
        ELSIF p_subtab = 'RETURNED_TODAY' THEN
            v_where := v_where || ' AND (br.status = ''RETURNED'' OR br.is_returned = TRUE) AND (br.return_date = CURRENT_DATE OR br.returned_at::date = CURRENT_DATE)';
        ELSIF p_subtab = 'RETURNED' THEN
            v_where := v_where || ' AND (br.status = ''RETURNED'' OR br.is_returned = TRUE)';
        ELSIF p_subtab = 'OVERDUE' THEN
            v_where := v_where || ' AND (br.status = ''OVERDUE'' OR (br.status IN (''ISSUED'', ''RENEWED'') AND br.due_date < CURRENT_DATE AND (br.is_returned IS NOT TRUE AND br.return_date IS NULL)))';
        ELSIF p_subtab = 'RENEWED' THEN
            v_where := v_where || ' AND br.status = ''RENEWED''';
        ELSIF p_subtab = 'REQUESTS' THEN
            -- Only active pending circulation requests (Issue, Renewal, Return) awaiting librarian action
            v_where := v_where || ' AND (UPPER(br.status) IN (''PENDING'', ''WAITING'', ''REQUESTED'', ''PENDING_RENEW'', ''PENDING_RETURN'') OR (br.transaction_type ILIKE ''%REQUEST%'' AND UPPER(br.status) NOT IN (''ISSUED'', ''RETURNED'', ''REJECTED'', ''CANCELLED'', ''CANCELED'')))';
        ELSIF p_subtab = 'FINES' THEN
            v_where := v_where || ' AND COALESCE(br.fine_amount, 0) > 0';
        ELSIF p_subtab IN ('LOST_DAMAGED', 'LOST / DAMAGED', 'LOST', 'DAMAGED') THEN
            v_where := v_where || ' AND (UPPER(br.status) IN (''LOST'', ''DAMAGED'') OR UPPER(COALESCE(br.return_condition, '''')) IN (''DAMAGED'', ''LOST'', ''MAJOR_DAMAGE'') OR UPPER(COALESCE(br.transaction_type, '''')) = ''LOST_DAMAGED'')';
        END IF;
    END IF;

    -- 3. Explicit Status Filter
    IF p_status IS NOT NULL AND p_status != 'ALL' THEN
        IF p_status = 'OVERDUE' THEN
            v_where := v_where || ' AND (br.status = ''OVERDUE'' OR (br.status IN (''ISSUED'', ''RENEWED'') AND br.due_date < CURRENT_DATE AND (br.is_returned IS NOT TRUE AND br.return_date IS NULL)))';
        ELSIF p_status = 'REQUESTS' OR p_status = 'PENDING' THEN
            v_where := v_where || ' AND (UPPER(br.status) IN (''PENDING'', ''WAITING'', ''REQUESTED'', ''PENDING_RENEW'', ''PENDING_RETURN'') OR (br.transaction_type ILIKE ''%REQUEST%'' AND UPPER(br.status) NOT IN (''ISSUED'', ''RETURNED'', ''REJECTED'', ''CANCELLED'', ''CANCELED'')))';
        ELSIF UPPER(p_status) IN ('LOST_DAMAGED', 'LOST / DAMAGED') THEN
            v_where := v_where || ' AND (UPPER(br.status) IN (''LOST'', ''DAMAGED'') OR UPPER(COALESCE(br.return_condition, '''')) IN (''DAMAGED'', ''LOST'', ''MAJOR_DAMAGE'') OR UPPER(COALESCE(br.transaction_type, '''')) = ''LOST_DAMAGED'')';
        ELSIF UPPER(p_status) = 'LOST' THEN
            v_where := v_where || ' AND (UPPER(br.status) = ''LOST'' OR UPPER(COALESCE(br.return_condition, '''')) = ''LOST'')';
        ELSIF UPPER(p_status) = 'DAMAGED' THEN
            v_where := v_where || ' AND (UPPER(br.status) = ''DAMAGED'' OR UPPER(COALESCE(br.return_condition, '''')) IN (''DAMAGED'', ''MAJOR_DAMAGE''))';
        ELSE
            v_where := v_where || format(' AND UPPER(br.status) = UPPER(%L)', p_status);
        END IF;
    END IF;

    -- 4. Transaction Type Filter
    IF p_transaction_type IS NOT NULL AND p_transaction_type != 'ALL' THEN
        IF UPPER(p_transaction_type) IN ('LOST_DAMAGED', 'LOST / DAMAGED') THEN
            v_where := v_where || ' AND (UPPER(br.status) IN (''LOST'', ''DAMAGED'') OR UPPER(COALESCE(br.return_condition, '''')) IN (''DAMAGED'', ''LOST'', ''MAJOR_DAMAGE'') OR UPPER(COALESCE(br.transaction_type, '''')) = ''LOST_DAMAGED'')';
        ELSE
            v_where := v_where || format(' AND br.transaction_type ILIKE %L', '%' || replace(p_transaction_type, ' ', '_') || '%');
        END IF;
    END IF;

    -- 5. Fine Status Filter
    IF p_fine_status IS NOT NULL AND p_fine_status != 'ALL' THEN
        IF p_fine_status = 'HAS_FINE' THEN
            v_where := v_where || ' AND COALESCE(br.fine_amount, 0) > 0';
        ELSIF p_fine_status = 'NO_FINE' THEN
            v_where := v_where || ' AND COALESCE(br.fine_amount, 0) = 0';
        ELSE
            v_where := v_where || format(' AND br.fine_status = %L', p_fine_status);
        END IF;
    END IF;

    -- 6. Member Role Filter
    IF p_member_role IS NOT NULL AND p_member_role != 'ALL' THEN
        v_where := v_where || format(' AND LOWER(p.role) = LOWER(%L)', p_member_role);
    END IF;

    -- 7. Date Range Filter
    IF p_date_from IS NOT NULL THEN
        v_where := v_where || format(' AND %s >= %L', v_date_col, p_date_from);
    END IF;
    IF p_date_to IS NOT NULL THEN
        v_where := v_where || format(' AND %s <= %L', v_date_col, p_date_to);
    END IF;

    -- Count total matching rows
    EXECUTE '
        SELECT COUNT(*)
        FROM public.library_borrows br
        LEFT JOIN public.library_members m ON br.member_id = m.id
        LEFT JOIN public.profiles p ON (m.profile_id = p.id OR br.student_id = p.id)
        LEFT JOIN public.library_books b ON br.book_id = b.id
        LEFT JOIN public.library_book_copies c ON br.copy_id = c.id
        WHERE ' || v_where
    INTO v_total;

    -- Fetch paginated items using jsonb_build_object consistent with migration 345
    EXECUTE format('
        SELECT COALESCE(jsonb_agg(item), ''[]''::jsonb) FROM (
            SELECT jsonb_build_object(
                ''id'', br.id,
                ''transaction_code'', COALESCE(br.transaction_code, ''TXN-'' || LPAD(SUBSTRING(br.id::text FROM 1 FOR 4), 4, ''0'')),
                ''member_id'', COALESCE(br.member_id, m.id),
                ''member_user_id'', COALESCE(p.id, br.student_id, m.profile_id),
                ''member_name'', COALESCE(p.full_name, ''Library Member''),

                ''member_code'', COALESCE(m.member_code, ''N/A''),
                ''member_type'', COALESCE(m.membership_type, ''Student''),
                ''member_role'', COALESCE(p.role, ''student''),
                ''member_class'', COALESCE(p.class, p.department, ''N/A''),
                ''member_avatar'', p.avatar_url,
                ''member_phone'', p.phone,
                ''member_email'', p.email,
                ''book_id'', br.book_id,
                ''book_title'', COALESCE(b.title, ''Book''),
                ''book_isbn'', COALESCE(b.isbn13, b.isbn10, b.isbn, ''N/A''),
                ''book_cover_url'', b.cover_url,
                ''book_author'', COALESCE(b.author, ''Unknown''),
                ''book_category'', COALESCE(b.category_name, b.category, ''General''),
                ''copy_id'', br.copy_id,
                ''copy_accession'', COALESCE(c.accession_number, ''N/A''),
                ''copy_barcode'', COALESCE(c.barcode, ''N/A''),
                ''shelf_location'', COALESCE(c.location, b.shelf_location, ''N/A''),
                ''issue_date'', br.issue_date,
                ''borrowed_at'', br.borrowed_at,
                ''due_date'', br.due_date,
                ''due_at'', br.due_at,
                ''return_date'', br.return_date,
                ''returned_at'', br.returned_at,
                ''status'', CASE 
                    WHEN UPPER(br.status) IN (''LOST'', ''DAMAGED'') THEN UPPER(br.status)
                    WHEN UPPER(COALESCE(br.return_condition, '''')) IN (''DAMAGED'', ''MAJOR_DAMAGE'') THEN ''DAMAGED''
                    WHEN UPPER(COALESCE(br.return_condition, '''')) = ''LOST'' THEN ''LOST''
                    WHEN (br.status = ''ISSUED'' OR br.status = ''RENEWED'' OR br.status IS NULL) AND br.due_date < CURRENT_DATE AND (br.is_returned IS NOT TRUE AND br.return_date IS NULL) THEN ''OVERDUE''
                    ELSE COALESCE(br.status, CASE WHEN br.is_returned THEN ''RETURNED'' ELSE ''ISSUED'' END)
                END,
                ''days_overdue'', GREATEST(0, CASE 
                    WHEN (br.is_returned IS TRUE OR br.return_date IS NOT NULL) THEN 0
                    WHEN br.due_date < CURRENT_DATE THEN (CURRENT_DATE - br.due_date)
                    ELSE 0
                END),
                ''fine_amount'', COALESCE(br.fine_amount, 0.0),
                ''fine_status'', COALESCE(br.fine_status, ''NONE''),
                ''transaction_type'', COALESCE(br.transaction_type, ''MANUAL_ISSUE''),
                ''renewals_used'', COALESCE(br.renewals_used, 0),
                ''max_renewals'', COALESCE(br.max_renewals, 2),
                ''return_condition'', br.return_condition,
                ''issued_by'', br.issued_by,
                ''issued_by_name'', (SELECT full_name FROM public.profiles WHERE id = br.issued_by),
                ''received_by'', br.received_by,
                ''received_by_name'', (SELECT full_name FROM public.profiles WHERE id = br.received_by),
                ''notes'', br.notes,
                ''created_at'', br.created_at
            ) AS item
            FROM public.library_borrows br 
            LEFT JOIN public.library_members m ON br.member_id = m.id 
            LEFT JOIN public.profiles p ON (m.profile_id = p.id OR br.student_id = p.id)
            LEFT JOIN public.library_books b ON br.book_id = b.id 
            LEFT JOIN public.library_book_copies c ON br.copy_id = c.id 
            WHERE %s
            ORDER BY br.%I %s
            LIMIT %s OFFSET %s
        ) sub;
    ', v_where, p_sort_by, p_sort_order, p_page_size, v_offset) INTO v_items;

    -- Calculate subtab counts
    EXECUTE '
        SELECT 
            COUNT(*),
            COUNT(*) FILTER (WHERE br.status = ''ISSUED'' AND (br.due_date >= CURRENT_DATE OR br.due_date IS NULL)),
            COUNT(*) FILTER (WHERE br.status = ''RETURNED'' OR br.is_returned = TRUE),
            COUNT(*) FILTER (WHERE br.status = ''OVERDUE'' OR (br.status IN (''ISSUED'', ''RENEWED'') AND br.due_date < CURRENT_DATE AND (br.is_returned IS NOT TRUE AND br.return_date IS NULL))),
            COUNT(*) FILTER (WHERE UPPER(br.status) IN (''PENDING'', ''WAITING'', ''REQUESTED'', ''PENDING_RENEW'', ''PENDING_RETURN'') OR (br.transaction_type ILIKE ''%REQUEST%'' AND UPPER(br.status) NOT IN (''ISSUED'', ''RETURNED'', ''REJECTED'', ''CANCELLED'', ''CANCELED''))),
            COUNT(*) FILTER (WHERE br.status = ''RENEWED''),
            COUNT(*) FILTER (WHERE UPPER(br.status) IN (''LOST'', ''DAMAGED'') OR UPPER(COALESCE(br.return_condition, '''')) IN (''DAMAGED'', ''LOST'', ''MAJOR_DAMAGE'') OR UPPER(COALESCE(br.transaction_type, '''')) = ''LOST_DAMAGED'')
        FROM public.library_borrows br
        LEFT JOIN public.library_members m ON br.member_id = m.id
        LEFT JOIN public.profiles p ON (m.profile_id = p.id OR br.student_id = p.id)
        WHERE br.school_id = ' || quote_literal(p_school_id) || 
        (CASE WHEN v_is_user_scoped THEN 
            ' AND (br.member_id = ' || quote_nullable(v_member_id) || ' OR br.student_id = ' || quote_literal(p_current_user_id) || ' OR m.profile_id = ' || quote_literal(p_current_user_id) || ' OR br.issued_by = ' || quote_literal(p_current_user_id) || ')'
         ELSE '' END)
    INTO v_count_all, v_count_issued, v_count_returned, v_count_overdue, v_count_requests, v_count_renewed, v_count_lost_damaged;

    v_counts := jsonb_build_object(
        'ALL', v_count_all,
        'ISSUED', v_count_issued,
        'RETURNED', v_count_returned,
        'OVERDUE', v_count_overdue,
        'REQUESTS', v_count_requests,
        'RENEWED', v_count_renewed,
        'LOST_DAMAGED', v_count_lost_damaged
    );

    RETURN jsonb_build_object(
        'items', COALESCE(v_items, '[]'::jsonb),
        'total', v_total,
        'page', p_page,
        'page_size', p_page_size,
        'total_pages', GREATEST(1, CEIL(v_total::float / p_page_size)),
        'counts', v_counts
    );
END;
$$;

-- ============================================================================
-- 6. ENHANCE fn_library_process_issue_request
-- Preserves copy_id, issue_date, due_date and notes on WAITING/REJECT actions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_process_issue_request(
    p_school_id uuid,
    p_borrow_id uuid,
    p_action text,
    p_copy_id uuid DEFAULT NULL::uuid,
    p_issue_date date DEFAULT NULL::date,
    p_due_date date DEFAULT NULL::date,
    p_performed_by uuid DEFAULT NULL::uuid,
    p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_borrow RECORD;
    v_assigned_copy_id UUID := p_copy_id;
    v_barcode VARCHAR(50);
    v_accession VARCHAR(50);
    v_book_title VARCHAR(255);
    v_member_name VARCHAR(150);
    v_is_digital BOOLEAN := false;
    v_action_upper TEXT := UPPER(trim(p_action));
    v_issue_d DATE := COALESCE(p_issue_date, CURRENT_DATE);
    v_due_d DATE := COALESCE(p_due_date, CURRENT_DATE + 14);
BEGIN
    -- Fetch borrow record
    SELECT br.*, b.title AS b_title, b.is_digital AS b_is_digital, p.full_name AS m_name
    INTO v_borrow
    FROM public.library_borrows br
    LEFT JOIN public.library_books b ON br.book_id = b.id
    LEFT JOIN public.library_members m ON br.member_id = m.id
    LEFT JOIN public.profiles p ON (m.profile_id = p.id OR br.student_id = p.id)
    WHERE br.id = p_borrow_id AND br.school_id = p_school_id;

    IF v_borrow.id IS NULL THEN
        RAISE EXCEPTION 'Circulation transaction record not found.';
    END IF;

    v_book_title := COALESCE(v_borrow.b_title, 'Book');
    v_member_name := COALESCE(v_borrow.m_name, 'Member');
    v_is_digital := COALESCE(v_borrow.b_is_digital, false);

    IF v_action_upper = 'ISSUE' THEN
        -- If copy not specified:
        IF v_assigned_copy_id IS NULL THEN
            -- Try to find an available physical copy
            SELECT id, barcode, accession_number
            INTO v_assigned_copy_id, v_barcode, v_accession
            FROM public.library_book_copies
            WHERE book_id = v_borrow.book_id AND school_id = p_school_id
              AND UPPER(status) IN ('AVAILABLE', 'ACTIVE')
              AND is_deleted IS NOT TRUE
            ORDER BY created_at ASC
            LIMIT 1;

            -- If still null, check if book is digital format (eBook, Audiobook, Videobook)
            IF v_assigned_copy_id IS NULL THEN
                IF v_is_digital OR (SELECT COUNT(*) FROM public.library_digital_files WHERE book_id = v_borrow.book_id) > 0 THEN
                    -- Digital edition access granted without physical copy
                    v_barcode := 'DIGITAL';
                    v_accession := 'DIGITAL';
                ELSE
                    RAISE EXCEPTION 'No available physical copies found for "%" to issue immediately. Please mark as WAITING.', v_book_title;
                END IF;
            END IF;
        ELSE
            SELECT barcode, accession_number
            INTO v_barcode, v_accession
            FROM public.library_book_copies
            WHERE id = v_assigned_copy_id;
        END IF;

        -- Update copy status only if physical copy was assigned
        IF v_assigned_copy_id IS NOT NULL THEN
            UPDATE public.library_book_copies
            SET status = 'BORROWED', updated_at = NOW()
            WHERE id = v_assigned_copy_id;
        END IF;

        -- Update borrow row
        UPDATE public.library_borrows
        SET status = 'ISSUED',
            transaction_type = 'REQUEST_APPROVED',
            copy_id = v_assigned_copy_id,
            issue_date = v_issue_d,
            due_date = v_due_d,
            issued_by = p_performed_by,
            notes = COALESCE(p_notes, v_borrow.notes),
            updated_at = NOW()
        WHERE id = p_borrow_id;

        -- Update request table
        UPDATE public.library_requests
        SET status = 'COMPLETED',
            approval_status = 'APPROVED',
            approved_by = p_performed_by,
            approved_at = NOW(),
            approval_comments = p_notes,
            updated_at = NOW()
        WHERE borrow_id = p_borrow_id OR (book_id = v_borrow.book_id AND requester_user_id = v_borrow.student_id AND status = 'PENDING');

        -- Activity log
        INSERT INTO public.library_circulation_activities (
            school_id, activity_type, title, description, borrow_id, performed_by, created_at
        ) VALUES (
            p_school_id, 'ISSUE', 'Issue Request Approved & Issued',
            'Book "' || v_book_title || '" issued to ' || v_member_name || ' (Copy: ' || COALESCE(v_barcode, v_accession, 'Digital Access') || ')',
            p_borrow_id, p_performed_by, NOW()
        );

        RETURN jsonb_build_object(
            'success', true,
            'message', 'Book successfully issued to ' || v_member_name || '.',
            'status', 'ISSUED',
            'copy_barcode', v_barcode,
            'due_date', v_due_d
        );

    ELSIF v_action_upper = 'WAITING' THEN
        -- Mark waiting and preserve copy, dates, notes
        UPDATE public.library_borrows
        SET status = 'WAITING',
            notes = COALESCE(p_notes, notes, 'Marked as waiting by librarian'),
            copy_id = COALESCE(v_assigned_copy_id, copy_id),
            issue_date = COALESCE(v_issue_d, issue_date),
            due_date = COALESCE(v_due_d, due_date),
            updated_at = NOW()
        WHERE id = p_borrow_id;

        UPDATE public.library_requests
        SET status = 'IN_PROGRESS',
            clarification_requested = true,
            clarification_message = COALESCE(p_notes, 'Waiting for book availability / library desk arrival'),
            additional_notes = COALESCE(p_notes, additional_notes),
            updated_at = NOW()
        WHERE borrow_id = p_borrow_id OR (book_id = v_borrow.book_id AND requester_user_id = v_borrow.student_id AND status IN ('PENDING', 'NEW', 'IN_PROGRESS'));

        INSERT INTO public.library_circulation_activities (
            school_id, activity_type, title, description, borrow_id, performed_by, created_at
        ) VALUES (
            p_school_id, 'WAITING', 'Request Status: Waiting',
            'Request for "' || v_book_title || '" by ' || v_member_name || ' marked as Waiting: ' || COALESCE(p_notes, 'Pending collection/copy'),
            p_borrow_id, p_performed_by, NOW()
        );

        RETURN jsonb_build_object(
            'success', true,
            'message', 'Request status set to Waiting.',
            'status', 'WAITING',
            'notes', p_notes
        );

    ELSIF v_action_upper = 'REJECT' THEN
        -- Reject request
        UPDATE public.library_borrows
        SET status = 'REJECTED',
            notes = COALESCE(p_notes, notes, 'Request rejected by librarian'),
            updated_at = NOW()
        WHERE id = p_borrow_id;

        UPDATE public.library_requests
        SET status = 'REJECTED',
            approval_status = 'REJECTED',
            approved_by = p_performed_by,
            approved_at = NOW(),
            approval_comments = p_notes,
            updated_at = NOW()
        WHERE borrow_id = p_borrow_id OR (book_id = v_borrow.book_id AND requester_user_id = v_borrow.student_id AND status IN ('PENDING', 'NEW', 'IN_PROGRESS'));

        INSERT INTO public.library_circulation_activities (
            school_id, activity_type, title, description, borrow_id, performed_by, created_at
        ) VALUES (
            p_school_id, 'REJECT', 'Issue Request Rejected',
            'Request for "' || v_book_title || '" rejected: ' || COALESCE(p_notes, 'No reason provided'),
            p_borrow_id, p_performed_by, NOW()
        );

        RETURN jsonb_build_object(
            'success', true,
            'message', 'Request has been rejected.',
            'status', 'REJECTED'
        );

    ELSE
        RAISE EXCEPTION 'Invalid action "%". Supported actions: ISSUE, WAITING, REJECT.', p_action;
    END IF;
END;
$function$;

-- ============================================================================
-- 8. ENHANCE fn_library_return_books
-- Properly handles DAMAGED and LOST return conditions and copies
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_return_books(
    p_school_id UUID,
    p_items JSONB,
    p_received_by UUID,
    p_collect_fine BOOLEAN DEFAULT FALSE,
    p_payment_method VARCHAR(50) DEFAULT 'CASH',
    p_payment_ref VARCHAR(100) DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item JSONB;
    v_borrow_id UUID;
    v_condition VARCHAR(50);
    v_notes TEXT;
    v_borrow RECORD;
    v_days_overdue INT;
    v_fine_rate NUMERIC := 10.00;
    v_calculated_fine NUMERIC := 0.00;
    v_damage_charge NUMERIC := 0.00;
    v_lost_charge NUMERIC := 0.00;
    v_total_item_fine NUMERIC := 0.00;
    v_fine_id UUID;
    v_receipt_no VARCHAR(50);
    v_returned_count INT := 0;
    v_processed_items JSONB := '[]'::jsonb;
    v_book RECORD;
    v_profile RECORD;
BEGIN
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_borrow_id := (v_item->>'borrow_id')::uuid;
        v_condition := COALESCE(v_item->>'condition', 'GOOD');
        v_notes := v_item->>'notes';
        v_damage_charge := COALESCE((v_item->>'damage_charge')::numeric, 0.00);
        v_lost_charge := COALESCE((v_item->>'lost_charge')::numeric, 0.00);

        SELECT * INTO v_borrow FROM public.library_borrows 
        WHERE id = v_borrow_id AND school_id = p_school_id
        FOR UPDATE;

        IF NOT FOUND THEN
            CONTINUE;
        END IF;

        IF v_borrow.is_returned IS TRUE OR v_borrow.status = 'RETURNED' THEN
            RAISE EXCEPTION 'Transaction % has already been returned.', v_borrow.transaction_code;
        END IF;

        -- Calculate overdue days & fine
        v_days_overdue := GREATEST(0, CURRENT_DATE - v_borrow.due_date);
        v_calculated_fine := v_days_overdue * v_fine_rate;
        v_total_item_fine := v_calculated_fine + v_damage_charge + v_lost_charge;

        SELECT full_name INTO v_profile FROM public.profiles p 
        JOIN public.library_members m ON m.profile_id = p.id WHERE m.id = v_borrow.member_id;

        -- If fine generated, record in library_fines
        IF v_total_item_fine > 0 THEN
            INSERT INTO public.library_fines (
                school_id, member_id, borrow_id, amount, paid_amount, waived_amount,
                outstanding_amount, reason, status, created_at, updated_at
            ) VALUES (
                p_school_id, v_borrow.member_id, v_borrow_id, v_total_item_fine,
                CASE WHEN p_collect_fine THEN v_total_item_fine ELSE 0.00 END,
                0.00,
                CASE WHEN p_collect_fine THEN 0.00 ELSE v_total_item_fine END,
                format('Overdue: %s days (₹%s), Condition: %s', v_days_overdue, v_calculated_fine, v_condition),
                CASE WHEN p_collect_fine THEN 'PAID' ELSE 'UNPAID' END,
                NOW(), NOW()
            ) RETURNING id INTO v_fine_id;

            -- Record fine payment if collected immediately
            IF p_collect_fine THEN
                v_receipt_no := 'RCP-' || LPAD((FLOOR(RANDOM() * 90000) + 10000)::text, 5, '0');
                INSERT INTO public.library_fine_payments (
                    school_id, fine_id, borrow_id, member_id, amount_paid,
                    payment_method, transaction_reference, receipt_number,
                    notes, collected_by, created_at
                ) VALUES (
                    p_school_id, v_fine_id, v_borrow_id, v_borrow.member_id, v_total_item_fine,
                    p_payment_method, p_payment_ref, v_receipt_no,
                    'Instant fine payment upon return', p_received_by, NOW()
                );
            END IF;

            -- Update Member outstanding fine if unpaid
            IF NOT p_collect_fine THEN
                UPDATE public.library_members
                SET outstanding_fine = outstanding_fine + v_total_item_fine,
                    total_fines_incurred = total_fines_incurred + v_total_item_fine,
                    updated_at = NOW()
                WHERE id = v_borrow.member_id;
            ELSE
                UPDATE public.library_members
                SET total_fines_paid = total_fines_paid + v_total_item_fine,
                    total_fines_incurred = total_fines_incurred + v_total_item_fine,
                    updated_at = NOW()
                WHERE id = v_borrow.member_id;
            END IF;
        END IF;

        -- Update Borrow Record
        UPDATE public.library_borrows
        SET is_returned = TRUE,
            return_date = CURRENT_DATE,
            returned_at = NOW(),
            status = CASE 
                WHEN v_condition = 'LOST' THEN 'LOST' 
                WHEN v_condition IN ('DAMAGED', 'MAJOR_DAMAGE') THEN 'DAMAGED' 
                ELSE 'RETURNED' 
            END,
            return_condition = v_condition,
            fine_amount = v_total_item_fine,
            fine_status = CASE 
                WHEN v_total_item_fine = 0 THEN 'NONE'
                WHEN p_collect_fine THEN 'PAID'
                ELSE 'UNPAID'
            END,
            damage_charge = v_damage_charge,
            lost_charge = v_lost_charge,
            received_by = p_received_by,
            notes = COALESCE(v_notes, notes),
            updated_at = NOW()
        WHERE id = v_borrow_id;

        -- Update Copy Status
        IF v_borrow.copy_id IS NOT NULL THEN
            UPDATE public.library_book_copies
            SET status = CASE 
                    WHEN v_condition = 'LOST' THEN 'LOST'
                    WHEN v_condition IN ('DAMAGED', 'MAJOR_DAMAGE') THEN 'DAMAGED'
                    ELSE 'AVAILABLE'
                END,
                condition = CASE 
                    WHEN v_condition IN ('MINOR_DAMAGE', 'MAJOR_DAMAGE', 'DAMAGED') THEN 'DAMAGED'
                    ELSE condition
                END,
                current_borrower_id = NULL,
                last_returned_date = NOW(),
                updated_at = NOW()
            WHERE id = v_borrow.copy_id;
        END IF;

        -- Update Book available count
        UPDATE public.library_books
        SET available_copies = CASE 
                WHEN v_condition IN ('LOST', 'DAMAGED', 'MAJOR_DAMAGE') THEN available_copies
                ELSE available_copies + 1 
            END,
            issued_copies = GREATEST(0, issued_copies - 1),
            updated_at = NOW()
        WHERE id = v_borrow.book_id;

        -- Decrement Member current borrowed count
        UPDATE public.library_members
        SET current_borrowed_count = GREATEST(0, current_borrowed_count - 1),
            updated_at = NOW()
        WHERE id = v_borrow.member_id;

        -- Log Activity
        SELECT title INTO v_book FROM public.library_books WHERE id = v_borrow.book_id;
        INSERT INTO public.library_circulation_activities (
            school_id, activity_type, title, description,
            member_id, book_id, copy_id, borrow_id, performed_by, created_at
        ) VALUES (
            p_school_id, 'RETURN',
            'Book returned by ' || COALESCE(v_profile.full_name, 'Member'),
            'Returned "' || COALESCE(v_book.title, 'Book') || '" (Fine: ₹' || v_total_item_fine || ', Condition: ' || v_condition || ')',
            v_borrow.member_id, v_borrow.book_id, v_borrow.copy_id, v_borrow_id, p_received_by, NOW()
        );

        v_returned_count := v_returned_count + 1;
        v_processed_items := v_processed_items || jsonb_build_object(
            'borrow_id', v_borrow_id,
            'transaction_code', v_borrow.transaction_code,
            'fine_amount', v_total_item_fine,
            'condition', v_condition
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'message', format('Successfully processed return of %s book(s).', v_returned_count),
        'returned_count', v_returned_count,
        'items', v_processed_items
    );
END;
$$;

-- ============================================================================
-- 9. CREATE fn_library_delete_borrow_request
-- Allows users who raised a circulation request (or admins) to delete it 
-- ONLY IF no action has been taken by the librarian yet (PENDING/REQUESTED/NEW).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_delete_borrow_request(
    p_school_id uuid,
    p_borrow_id uuid,
    p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_borrow RECORD;
    v_member_profile_id UUID := NULL;
    v_is_admin BOOLEAN := FALSE;
    v_book_title TEXT := 'Book';
BEGIN
    SELECT * INTO v_borrow
    FROM public.library_borrows
    WHERE id = p_borrow_id AND school_id = p_school_id
    FOR UPDATE;

    IF v_borrow.id IS NULL THEN
        RAISE EXCEPTION 'Loan request not found.';
    END IF;

    -- Check if caller is an admin
    SELECT EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = p_user_id AND LOWER(role) IN ('super_admin', 'school_admin', 'branch_admin', 'librarian')
    ) INTO v_is_admin;

    -- If not admin, verify ownership
    IF NOT v_is_admin THEN
        IF v_borrow.member_id IS NOT NULL THEN
            SELECT profile_id INTO v_member_profile_id 
            FROM public.library_members 
            WHERE id = v_borrow.member_id;
        END IF;

        IF COALESCE(v_borrow.student_id, '00000000-0000-0000-0000-000000000000'::uuid) != p_user_id
           AND COALESCE(v_member_profile_id, '00000000-0000-0000-0000-000000000000'::uuid) != p_user_id
           AND COALESCE(v_borrow.issued_by, '00000000-0000-0000-0000-000000000000'::uuid) != p_user_id THEN
            RAISE EXCEPTION 'You are not authorized to delete this request.';
        END IF;
    END IF;

    -- Check status: Only allow deletion if NO ACTION has been taken by librarian
    -- Allowed: PENDING, REQUESTED, NEW, PENDING_RENEW, PENDING_RETURN
    -- If WAITING, ISSUED, REJECTED, RETURNED, OVERDUE, etc. -> Cannot delete
    IF UPPER(COALESCE(v_borrow.status, '')) NOT IN ('PENDING', 'REQUESTED', 'NEW', 'PENDING_RENEW', 'PENDING_RETURN') THEN
        RAISE EXCEPTION 'Cannot delete request. Librarian has already taken action on it (Current status: "%").', v_borrow.status;
    END IF;

    -- Fetch book title for activity log
    SELECT COALESCE(title, 'Book') INTO v_book_title FROM public.library_books WHERE id = v_borrow.book_id;

    -- If this was a renewal request on an already borrowed book, revert status to ISSUED or OVERDUE
    IF UPPER(COALESCE(v_borrow.transaction_type, '')) = 'RENEW_REQUEST' OR UPPER(COALESCE(v_borrow.status, '')) = 'PENDING_RENEW' THEN
        UPDATE public.library_borrows
        SET status = CASE WHEN due_date < CURRENT_DATE THEN 'OVERDUE' ELSE 'ISSUED' END,
            transaction_type = 'MANUAL_ISSUE',
            notes = NULL,
            updated_at = NOW()
        WHERE id = p_borrow_id;

        INSERT INTO public.library_circulation_activities (
            school_id, activity_type, title, description, borrow_id, performed_by, created_at
        ) VALUES (
            p_school_id, 'CANCEL_RENEW', 'Renewal Request Cancelled',
            'Renewal request for "' || v_book_title || '" was cancelled by requester.',
            p_borrow_id, p_user_id, NOW()
        );

        RETURN jsonb_build_object(
            'success', true,
            'message', 'Renewal request cancelled successfully.',
            'borrow_id', p_borrow_id
        );

    -- If this was a return request, revert status to ISSUED or OVERDUE
    ELSIF UPPER(COALESCE(v_borrow.transaction_type, '')) = 'RETURN_REQUEST' OR UPPER(COALESCE(v_borrow.status, '')) = 'PENDING_RETURN' THEN
        UPDATE public.library_borrows
        SET status = CASE WHEN due_date < CURRENT_DATE THEN 'OVERDUE' ELSE 'ISSUED' END,
            transaction_type = 'MANUAL_ISSUE',
            notes = NULL,
            updated_at = NOW()
        WHERE id = p_borrow_id;

        INSERT INTO public.library_circulation_activities (
            school_id, activity_type, title, description, borrow_id, performed_by, created_at
        ) VALUES (
            p_school_id, 'CANCEL_RETURN', 'Return Request Cancelled',
            'Return request for "' || v_book_title || '" was cancelled by requester.',
            p_borrow_id, p_user_id, NOW()
        );

        RETURN jsonb_build_object(
            'success', true,
            'message', 'Return request cancelled successfully.',
            'borrow_id', p_borrow_id
        );

    ELSE
        -- Initial Issue Request: Hard delete the pending borrow row
        DELETE FROM public.library_requests WHERE borrow_id = p_borrow_id;
        DELETE FROM public.library_circulation_activities WHERE borrow_id = p_borrow_id;
        DELETE FROM public.library_borrows WHERE id = p_borrow_id;

        INSERT INTO public.library_circulation_activities (
            school_id, activity_type, title, description, performed_by, created_at
        ) VALUES (
            p_school_id, 'CANCEL_ISSUE', 'Issue Request Deleted',
            'Book issue request for "' || v_book_title || '" was deleted by requester.',
            p_user_id, NOW()
        );

        RETURN jsonb_build_object(
            'success', true,
            'message', 'Issue request deleted successfully.',
            'borrow_id', p_borrow_id
        );
    END IF;
END;
$$;

-- ============================================================================
-- 10. CREATE fn_library_delete_request
-- Allows users who raised a generic library acquisition request (or admins) to delete it
-- ONLY IF no action has been taken by the librarian yet (NEW/PENDING).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_delete_request(
    p_school_id uuid,
    p_request_id uuid,
    p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req RECORD;
    v_is_admin BOOLEAN := FALSE;
    v_req_title TEXT := 'Request';
BEGIN
    SELECT * INTO v_req
    FROM public.library_requests
    WHERE id = p_request_id AND school_id = p_school_id
    FOR UPDATE;

    IF v_req.id IS NULL THEN
        RAISE EXCEPTION 'Library request not found.';
    END IF;

    -- Check if caller is an admin
    SELECT EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = p_user_id AND LOWER(role) IN ('super_admin', 'school_admin', 'branch_admin', 'librarian')
    ) INTO v_is_admin;

    -- If not admin, verify ownership
    IF NOT v_is_admin THEN
        IF COALESCE(v_req.student_id, '00000000-0000-0000-0000-000000000000'::uuid) != p_user_id
           AND COALESCE(v_req.requester_user_id, '00000000-0000-0000-0000-000000000000'::uuid) != p_user_id THEN
            RAISE EXCEPTION 'You are not authorized to delete this request.';
        END IF;
    END IF;

    -- Check status: Only allow deletion if NO ACTION has been taken by librarian
    -- Allowed: NEW, PENDING
    -- If IN_PROGRESS, ACTIVE, APPROVED, RESOLVED, REJECTED, ORDERED, COMPLETED, WAITING -> Cannot delete
    IF UPPER(COALESCE(v_req.status, '')) NOT IN ('NEW', 'PENDING') THEN
        RAISE EXCEPTION 'Cannot delete request. Librarian has already taken action on it (Current status: "%").', v_req.status;
    END IF;

    v_req_title := COALESCE(v_req.title, 'Request');

    -- Delete cascading dependencies
    DELETE FROM public.library_request_attachments WHERE request_id = p_request_id;
    DELETE FROM public.library_request_comments WHERE request_id = p_request_id;
    DELETE FROM public.library_request_status_history WHERE request_id = p_request_id;
    DELETE FROM public.library_requests WHERE id = p_request_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Library request "' || v_req_title || '" deleted successfully.',
        'request_id', p_request_id
    );
END;
$$;

-- ============================================================================
-- 11. CREATE fn_library_raise_return_request
-- A book MUST be in an active issued state (ISSUED, BORROWED, OVERDUE, RENEWED) before return can be requested!
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_raise_return_request(
    p_school_id UUID,
    p_borrow_id UUID,
    p_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_borrow RECORD;
    v_user_name VARCHAR(150);
BEGIN
    SELECT br.*, b.title AS b_title, b.author AS b_author, p.full_name AS m_name
    INTO v_borrow
    FROM public.library_borrows br
    LEFT JOIN public.library_books b ON br.book_id = b.id
    LEFT JOIN public.library_members m ON br.member_id = m.id
    LEFT JOIN public.profiles p ON (m.profile_id = p.id OR br.student_id = p.id)
    WHERE br.id = p_borrow_id AND br.school_id = p_school_id;

    IF v_borrow.id IS NULL THEN
        RAISE EXCEPTION 'Loan record not found.';
    END IF;

    -- Strict logical validation: MUST be in an issued state!
    IF UPPER(COALESCE(v_borrow.status, '')) NOT IN ('ISSUED', 'BORROWED', 'OVERDUE', 'RENEWED') THEN
        RAISE EXCEPTION 'Cannot request return. Book must be in an issued/active borrowed state (Current status: "%").', v_borrow.status;
    END IF;

    -- If already pending return
    IF UPPER(COALESCE(v_borrow.status, '')) = 'PENDING_RETURN' THEN
        RAISE EXCEPTION 'A return request is already pending for this loan.';
    END IF;

    v_user_name := COALESCE(v_borrow.m_name, 'Member');

    -- Transition status to PENDING_RETURN
    UPDATE public.library_borrows
    SET status = 'PENDING_RETURN',
        transaction_type = 'RETURN_REQUEST',
        notes = COALESCE(p_reason, notes),
        updated_at = NOW()
    WHERE id = p_borrow_id;

    -- Log Activity
    INSERT INTO public.library_circulation_activities (
        school_id, activity_type, title, description, borrow_id, performed_by, created_at
    ) VALUES (
        p_school_id, 'RETURN_REQUEST', 'Book Return Requested',
        v_user_name || ' requested return for "' || v_borrow.b_title || '": ' || COALESCE(p_reason, 'Return requested'),
        p_borrow_id, p_user_id, NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Return request submitted successfully. Please submit the physical book at the library counter.',
        'borrow_id', p_borrow_id
    );
END;
$$;

-- ============================================================================
-- 12. CREATE fn_library_reject_borrow_request
-- Librarian rejects an Issue, Renewal, or Return request
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_reject_borrow_request(
    p_school_id UUID,
    p_borrow_id UUID,
    p_user_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_borrow RECORD;
    v_book_title VARCHAR(255);
    v_member_name VARCHAR(150);
BEGIN
    SELECT br.*, b.title AS b_title, p.full_name AS m_name
    INTO v_borrow
    FROM public.library_borrows br
    LEFT JOIN public.library_books b ON br.book_id = b.id
    LEFT JOIN public.library_members m ON br.member_id = m.id
    LEFT JOIN public.profiles p ON (m.profile_id = p.id OR br.student_id = p.id)
    WHERE br.id = p_borrow_id AND br.school_id = p_school_id;

    IF v_borrow.id IS NULL THEN
        RAISE EXCEPTION 'Transaction record not found.';
    END IF;

    v_book_title := COALESCE(v_borrow.b_title, 'Book');
    v_member_name := COALESCE(v_borrow.m_name, 'Member');

    -- Handle Rejection according to current request type:
    IF UPPER(COALESCE(v_borrow.status, '')) = 'PENDING_RENEW' OR UPPER(COALESCE(v_borrow.transaction_type, '')) = 'RENEW_REQUEST' THEN
        -- Revert renewal request back to active loan
        UPDATE public.library_borrows
        SET status = CASE WHEN due_date < CURRENT_DATE THEN 'OVERDUE' ELSE 'ISSUED' END,
            transaction_type = 'MANUAL_ISSUE',
            notes = COALESCE(p_notes, notes),
            updated_at = NOW()
        WHERE id = p_borrow_id;

        INSERT INTO public.library_circulation_activities (
            school_id, activity_type, title, description, borrow_id, performed_by, created_at
        ) VALUES (
            p_school_id, 'REJECT_RENEW', 'Renewal Request Rejected',
            'Renewal request for "' || v_book_title || '" by ' || v_member_name || ' was rejected: ' || COALESCE(p_notes, 'Rejected by librarian'),
            p_borrow_id, p_user_id, NOW()
        );

        RETURN jsonb_build_object(
            'success', true,
            'message', 'Renewal request rejected. Book remains in issued state.',
            'borrow_id', p_borrow_id
        );

    ELSIF UPPER(COALESCE(v_borrow.status, '')) = 'PENDING_RETURN' OR UPPER(COALESCE(v_borrow.transaction_type, '')) = 'RETURN_REQUEST' THEN
        -- Revert return request back to active loan
        UPDATE public.library_borrows
        SET status = CASE WHEN due_date < CURRENT_DATE THEN 'OVERDUE' ELSE 'ISSUED' END,
            transaction_type = 'MANUAL_ISSUE',
            notes = COALESCE(p_notes, notes),
            updated_at = NOW()
        WHERE id = p_borrow_id;

        INSERT INTO public.library_circulation_activities (
            school_id, activity_type, title, description, borrow_id, performed_by, created_at
        ) VALUES (
            p_school_id, 'REJECT_RETURN', 'Return Request Rejected',
            'Return request for "' || v_book_title || '" by ' || v_member_name || ' was rejected: ' || COALESCE(p_notes, 'Physical book not received or condition check failed'),
            p_borrow_id, p_user_id, NOW()
        );

        RETURN jsonb_build_object(
            'success', true,
            'message', 'Return request rejected. Book remains in issued state.',
            'borrow_id', p_borrow_id
        );

    ELSE
        -- Initial Issue Request rejected:
        UPDATE public.library_borrows
        SET status = 'REJECTED',
            notes = COALESCE(p_notes, notes, 'Request rejected by librarian'),
            updated_at = NOW()
        WHERE id = p_borrow_id;

        UPDATE public.library_requests
        SET status = 'REJECTED',
            approval_status = 'REJECTED',
            approved_by = p_user_id,
            approved_at = NOW(),
            approval_comments = p_notes,
            updated_at = NOW()
        WHERE borrow_id = p_borrow_id;

        INSERT INTO public.library_circulation_activities (
            school_id, activity_type, title, description, borrow_id, performed_by, created_at
        ) VALUES (
            p_school_id, 'REJECT_ISSUE', 'Issue Request Rejected',
            'Issue request for "' || v_book_title || '" by ' || v_member_name || ' was rejected: ' || COALESCE(p_notes, 'Rejected by librarian'),
            p_borrow_id, p_user_id, NOW()
        );

        RETURN jsonb_build_object(
            'success', true,
            'message', 'Issue request has been rejected.',
            'borrow_id', p_borrow_id
        );
    END IF;
END;
$$;



