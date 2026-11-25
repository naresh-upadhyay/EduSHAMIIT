-- ============================================================================
-- Migration 590: Library Joined-Column Sorting Fix & Requests Multi-Column Sort
-- ============================================================================

-- 1. Fix fn_library_list_transactions:
-- Previously used `ORDER BY br.%I %s`, which crashes on joined/computed sort keys
-- such as `member_name` (p.full_name) and `book_title` (b.title).
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
    v_order_col TEXT := 'br.created_at';
    v_order_dir TEXT := 'DESC';
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

    -- Safe sort column whitelist across base & joined tables
    CASE LOWER(TRIM(COALESCE(p_sort_by, 'created_at')))
        WHEN 'transaction_code' THEN v_order_col := 'COALESCE(br.transaction_code, '''')';
        WHEN 'member_name' THEN v_order_col := 'COALESCE(p.full_name, '''')';
        WHEN 'book_title' THEN v_order_col := 'COALESCE(b.title, '''')';
        WHEN 'issue_date' THEN v_order_col := 'br.issue_date';
        WHEN 'due_date' THEN v_order_col := 'br.due_date';
        WHEN 'return_date' THEN v_order_col := 'br.return_date';
        WHEN 'status' THEN v_order_col := 'br.status';
        WHEN 'fine_amount' THEN v_order_col := 'COALESCE(br.fine_amount, 0)';
        WHEN 'transaction_type' THEN v_order_col := 'COALESCE(br.transaction_type, '''')';
        ELSE v_order_col := 'br.created_at';
    END CASE;

    IF UPPER(TRIM(COALESCE(p_sort_order, 'DESC'))) = 'ASC' THEN
        v_order_dir := 'ASC';
    ELSE
        v_order_dir := 'DESC';
    END IF;

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

    -- Fetch paginated items ordered before LIMIT/OFFSET
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
            ORDER BY %s %s NULLS LAST, br.id ASC
            LIMIT %s OFFSET %s
        ) sub;
    ', v_where, v_order_col, v_order_dir, p_page_size, v_offset) INTO v_items;

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


-- 2. Enhance fn_library_list_requests:
-- Support all UI columns (request_number, title, request_type, requester_name, priority, status, created_at, updated_at) ASC & DESC
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
    v_sort_by TEXT := LOWER(TRIM(COALESCE(p_sort_by, 'created_at')));
    v_sort_order TEXT := UPPER(TRIM(COALESCE(p_sort_order, 'DESC')));
BEGIN
    IF p_current_user_role IS NOT NULL AND LOWER(p_current_user_role) IN ('student', 'parent') THEN
        v_is_requester_only := true;
    END IF;

    v_offset := GREATEST(0, (p_page - 1) * p_page_size);

    -- Count total matching records
    SELECT COUNT(*)
    INTO v_total
    FROM public.library_requests r
    LEFT JOIN public.library_members m ON r.member_id = m.id
    LEFT JOIN public.profiles p ON (r.requester_user_id = p.id OR r.student_id = p.id OR m.profile_id = p.id)
    LEFT JOIN public.library_books b ON r.book_id = b.id
    LEFT JOIN public.profiles a ON r.assigned_to = a.id
    WHERE r.school_id = p_school_id
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
      AND (
          p_request_type IS NULL
          OR UPPER(p_request_type) = 'ALL'
          OR UPPER(COALESCE(r.request_type, 'Book')) = UPPER(p_request_type)
      )
      AND (
          p_status IS NULL
          OR UPPER(p_status) = 'ALL'
          OR (UPPER(p_status) = 'NEW' AND UPPER(r.status) IN ('NEW', 'PENDING'))
          OR (UPPER(p_status) = 'IN_PROGRESS' AND UPPER(r.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS'))
          OR (UPPER(p_status) = 'CANCELLED' AND UPPER(r.status) IN ('CANCELED', 'CANCELLED'))
          OR UPPER(r.status) = UPPER(p_status)
      )
      AND (
          p_priority IS NULL
          OR UPPER(p_priority) = 'ALL'
          OR UPPER(COALESCE(r.priority, 'NORMAL')) = UPPER(p_priority)
      )
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
      AND (p_date_from IS NULL OR r.created_at::date >= p_date_from)
      AND (p_date_to IS NULL OR r.created_at::date <= p_date_to)
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
            COALESCE(p.id, r.requester_user_id) AS requester_id,
            COALESCE(p.full_name, 'Member') AS requester_name,
            COALESCE(p.email, '') AS requester_email,
            COALESCE(p.avatar_url, '') AS requester_avatar,
            COALESCE(p.role, 'Student') AS requester_role,
            COALESCE(p.class, p.department, 'Class 9-A') AS requester_class,
            m.member_code,
            b.id AS book_id,
            b.title AS linked_book_title,
            COALESCE(b.cover_url, '') AS cover_url,
            COALESCE(b.available_copies, 0) AS book_available_copies,
            COALESCE(b.total_copies, 0) AS book_total_copies,
            COALESCE(b.shelf_location, 'A-12') AS shelf_location,
            a.id AS assigned_to_id,
            COALESCE(a.full_name, 'Unassigned') AS assigned_to_name,
            COALESCE(a.avatar_url, '') AS assigned_to_avatar
        FROM public.library_requests r
        LEFT JOIN public.library_members m ON r.member_id = m.id
        LEFT JOIN public.profiles p ON (r.requester_user_id = p.id OR r.student_id = p.id OR m.profile_id = p.id)
        LEFT JOIN public.library_books b ON r.book_id = b.id
        LEFT JOIN public.profiles a ON r.assigned_to = a.id
        WHERE r.school_id = p_school_id
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
          AND (
              p_request_type IS NULL
              OR UPPER(p_request_type) = 'ALL'
              OR UPPER(COALESCE(r.request_type, 'Book')) = UPPER(p_request_type)
          )
          AND (
              p_status IS NULL
              OR UPPER(p_status) = 'ALL'
              OR (UPPER(p_status) = 'NEW' AND UPPER(r.status) IN ('NEW', 'PENDING'))
              OR (UPPER(p_status) = 'IN_PROGRESS' AND UPPER(r.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS'))
              OR (UPPER(p_status) = 'CANCELLED' AND UPPER(r.status) IN ('CANCELED', 'CANCELLED'))
              OR UPPER(r.status) = UPPER(p_status)
          )
          AND (
              p_priority IS NULL
              OR UPPER(p_priority) = 'ALL'
              OR UPPER(COALESCE(r.priority, 'NORMAL')) = UPPER(p_priority)
          )
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
          AND (p_date_from IS NULL OR r.created_at::date >= p_date_from)
          AND (p_date_to IS NULL OR r.created_at::date <= p_date_to)
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
            CASE WHEN v_sort_by = 'request_number' AND v_sort_order = 'ASC' THEN COALESCE(r.request_number, '') END ASC,
            CASE WHEN v_sort_by = 'request_number' AND v_sort_order = 'DESC' THEN COALESCE(r.request_number, '') END DESC,
            CASE WHEN v_sort_by = 'title' AND v_sort_order = 'ASC' THEN COALESCE(r.title, '') END ASC,
            CASE WHEN v_sort_by = 'title' AND v_sort_order = 'DESC' THEN COALESCE(r.title, '') END DESC,
            CASE WHEN v_sort_by = 'request_type' AND v_sort_order = 'ASC' THEN COALESCE(r.request_type, '') END ASC,
            CASE WHEN v_sort_by = 'request_type' AND v_sort_order = 'DESC' THEN COALESCE(r.request_type, '') END DESC,
            CASE WHEN v_sort_by = 'requester_name' AND v_sort_order = 'ASC' THEN COALESCE(p.full_name, '') END ASC,
            CASE WHEN v_sort_by = 'requester_name' AND v_sort_order = 'DESC' THEN COALESCE(p.full_name, '') END DESC,
            CASE WHEN v_sort_by = 'priority' AND v_sort_order = 'ASC' THEN COALESCE(r.priority, '') END ASC,
            CASE WHEN v_sort_by = 'priority' AND v_sort_order = 'DESC' THEN COALESCE(r.priority, '') END DESC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'ASC' THEN COALESCE(r.status, '') END ASC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'DESC' THEN COALESCE(r.status, '') END DESC,
            CASE WHEN v_sort_by = 'created_at' AND v_sort_order = 'ASC' THEN r.created_at END ASC,
            CASE WHEN v_sort_by = 'created_at' AND v_sort_order = 'DESC' THEN r.created_at END DESC,
            CASE WHEN v_sort_by = 'updated_at' AND v_sort_order = 'ASC' THEN r.updated_at END ASC,
            CASE WHEN v_sort_by = 'updated_at' AND v_sort_order = 'DESC' THEN r.updated_at END DESC,
            r.created_at DESC, r.id ASC
        LIMIT p_page_size OFFSET v_offset
    ) t;

    RETURN jsonb_build_object(
        'items', COALESCE(v_items, '[]'::jsonb),
        'total', v_total,
        'page', p_page,
        'page_size', p_page_size,
        'total_pages', GREATEST(1, CEIL(v_total::numeric / GREATEST(p_page_size, 1)::numeric)::int)
    );
END;
$function$;

-- 3. Visitors List Functions: Add deterministic ID tie-breakers to prevent tied-row page drift
CREATE OR REPLACE FUNCTION public.fn_visitors_list_visits(
    p_school_id UUID,
    p_params JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search VARCHAR := TRIM(COALESCE(p_params->>'search', ''));
    v_location VARCHAR := TRIM(COALESCE(p_params->>'location', 'All'));
    v_category VARCHAR := TRIM(COALESCE(p_params->>'category', 'All'));
    v_status VARCHAR := TRIM(COALESCE(p_params->>'status', 'All'));
    v_sort_by VARCHAR := LOWER(TRIM(COALESCE(p_params->>'sort_by', 'created_at')));
    v_sort_order VARCHAR := UPPER(TRIM(COALESCE(p_params->>'sort_order', 'DESC')));
    v_page INT := GREATEST(1, COALESCE((p_params->>'page')::INT, 1));
    v_page_size INT := GREATEST(1, LEAST(100, COALESCE((p_params->>'page_size')::INT, 10)));
    v_offset INT := (v_page - 1) * v_page_size;
    v_total INT := 0;
    v_records JSONB := '[]'::JSONB;
    v_date_from TIMESTAMPTZ := NULL;
    v_date_to TIMESTAMPTZ := NULL;
    v_now TIMESTAMPTZ := NOW();
BEGIN
    IF p_params->>'date_from' IS NOT NULL AND p_params->>'date_from' != '' THEN
        v_date_from := (p_params->>'date_from')::TIMESTAMPTZ;
    END IF;
    IF p_params->>'date_to' IS NOT NULL AND p_params->>'date_to' != '' THEN
        v_date_to := (p_params->>'date_to')::TIMESTAMPTZ;
    END IF;

    SELECT COUNT(*) INTO v_total
    FROM public.visitor_visits v
    JOIN public.visitor_profiles p ON v.visitor_id = p.id
    WHERE v.school_id = p_school_id
      AND (
          v_search = ''
          OR p.full_name ILIKE '%' || v_search || '%'
          OR p.phone ILIKE '%' || v_search || '%'
          OR v.visit_number ILIKE '%' || v_search || '%'
          OR v.purpose ILIKE '%' || v_search || '%'
          OR COALESCE(v.host_name, '') ILIKE '%' || v_search || '%'
          OR COALESCE(v.vehicle_number, '') ILIKE '%' || v_search || '%'
          OR COALESCE(v.pass_reference, '') ILIKE '%' || v_search || '%'
      )
      AND (
          v_location = 'All'
          OR v_location = 'All Locations'
          OR LOWER(TRIM(COALESCE(v.destination, ''))) = LOWER(TRIM(v_location))
          OR (COALESCE(v.destination, '') = '' AND LOWER(TRIM(COALESCE(v.entry_location, ''))) = LOWER(TRIM(v_location)))
      )
      AND (
          v_category = 'All'
          OR v_category = 'All Visitor Types'
          OR v.category = v_category
          OR p.visitor_type = v_category
      )
      AND (
          v_status = 'All'
          OR v_status = 'All Status'
          OR (v_status = 'Blocked' AND (
              v.actual_check_out_at IS NULL AND (
                  p.is_blacklisted = TRUE
                  OR EXISTS (
                      SELECT 1 FROM public.visitor_restrictions vr
                      WHERE vr.visitor_id = v.visitor_id
                        AND vr.school_id = v.school_id
                        AND vr.status = 'ACTIVE'
                        AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)
                  )
              )
          ))
          OR (v_status = 'Inside' AND v.actual_check_out_at IS NULL AND (v.status IN ('Inside', 'Overstay') OR (v.status = 'Blocked' AND v.check_in_at IS NOT NULL)) AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = v.visitor_id AND vr.school_id = v.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)))
          OR (v_status = 'Checked In' AND v.check_in_at IS NOT NULL)
          OR (v_status = 'Checked Out' AND (v.status = 'Checked Out' OR v.actual_check_out_at IS NOT NULL))
          OR (v_status = 'Overstay' AND v.actual_check_out_at IS NULL AND (v.status = 'Overstay' OR (v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < v_now)) AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = v.visitor_id AND vr.school_id = v.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)))
          OR (v_status = 'Scheduled' AND (v.status = 'Scheduled' OR (v.status = 'Blocked' AND v.check_in_at IS NULL)) AND v.actual_check_out_at IS NULL AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = v.visitor_id AND vr.school_id = v.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)))
          OR (v.status = v_status AND p.is_blacklisted IS NOT TRUE)
      )
      AND (
          v_date_from IS NULL
          OR (
              CASE
                  WHEN v_status = 'Checked Out' THEN COALESCE(v.actual_check_out_at, v.check_in_at, v.created_at) >= v_date_from
                  WHEN v_status = 'Checked In' THEN v.check_in_at >= v_date_from
                  ELSE COALESCE(v.check_in_at, v.created_at) >= v_date_from
              END
          )
      )
      AND (
          v_date_to IS NULL
          OR (
              CASE
                  WHEN v_status = 'Checked Out' THEN COALESCE(v.actual_check_out_at, v.check_in_at, v.created_at) <= v_date_to
                  WHEN v_status = 'Checked In' THEN v.check_in_at <= v_date_to
                  ELSE COALESCE(v.check_in_at, v.created_at) <= v_date_to
              END
          )
      );

    SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_records
    FROM (
        SELECT jsonb_build_object(
            'id', v.id,
            'visit_number', v.visit_number,
            'visitor_id', v.visitor_id,
            'visitor_name', p.full_name,
            'photo_url', p.photo_url,
            'phone', p.phone,
            'visitor_type', v.category,
            'category', v.category,
            'purpose', v.purpose,
            'location', COALESCE(v.destination, v.entry_location, 'Main Gate'),
            'destination', v.destination,
            'host_name', COALESCE(v.host_name, 'Staff Member'),
            'host_department', v.host_department,
            'check_in_at', to_char(v.check_in_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
            'expected_out_at', to_char(v.expected_out_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
            'actual_check_out_at', to_char(v.actual_check_out_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
            'status', CASE 
                WHEN v.actual_check_out_at IS NOT NULL THEN 'Checked Out'
                WHEN v.actual_check_out_at IS NULL AND (
                    p.is_blacklisted = TRUE 
                    OR EXISTS (
                        SELECT 1 FROM public.visitor_restrictions vr 
                        WHERE vr.visitor_id = v.visitor_id 
                          AND vr.school_id = v.school_id 
                          AND vr.status = 'ACTIVE' 
                          AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)
                    )
                ) THEN 'Blocked'
                WHEN v.status = 'Overstay' OR (v.status = 'Inside' AND v.actual_check_out_at IS NULL AND v.expected_out_at IS NOT NULL AND v.expected_out_at < v_now) THEN 'Overstay'
                WHEN v.status = 'Blocked' THEN CASE WHEN v.check_in_at IS NOT NULL THEN 'Inside' ELSE 'Scheduled' END
                ELSE v.status
            END,
            'vehicle_number', v.vehicle_number,
            'pass_reference', v.pass_reference,
            'remarks', v.remarks
        ) AS row_data
        FROM public.visitor_visits v
        JOIN public.visitor_profiles p ON v.visitor_id = p.id
        WHERE v.school_id = p_school_id
          AND (
              v_search = ''
              OR p.full_name ILIKE '%' || v_search || '%'
              OR p.phone ILIKE '%' || v_search || '%'
              OR v.visit_number ILIKE '%' || v_search || '%'
              OR v.purpose ILIKE '%' || v_search || '%'
              OR COALESCE(v.host_name, '') ILIKE '%' || v_search || '%'
              OR COALESCE(v.vehicle_number, '') ILIKE '%' || v_search || '%'
              OR COALESCE(v.pass_reference, '') ILIKE '%' || v_search || '%'
          )
          AND (
              v_location = 'All'
              OR v_location = 'All Locations'
              OR LOWER(TRIM(COALESCE(v.destination, ''))) = LOWER(TRIM(v_location))
              OR (COALESCE(v.destination, '') = '' AND LOWER(TRIM(COALESCE(v.entry_location, ''))) = LOWER(TRIM(v_location)))
          )
          AND (
              v_category = 'All'
              OR v_category = 'All Visitor Types'
              OR v.category = v_category
              OR p.visitor_type = v_category
          )
          AND (
              v_status = 'All'
              OR v_status = 'All Status'
              OR (v_status = 'Blocked' AND (
                  v.actual_check_out_at IS NULL AND (
                      p.is_blacklisted = TRUE
                      OR EXISTS (
                          SELECT 1 FROM public.visitor_restrictions vr
                          WHERE vr.visitor_id = v.visitor_id
                            AND vr.school_id = v.school_id
                            AND vr.status = 'ACTIVE'
                            AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)
                      )
                  )
              ))
              OR (v_status = 'Inside' AND v.actual_check_out_at IS NULL AND (v.status IN ('Inside', 'Overstay') OR (v.status = 'Blocked' AND v.check_in_at IS NOT NULL)) AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = v.visitor_id AND vr.school_id = v.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)))
              OR (v_status = 'Checked Out' AND (v.status = 'Checked Out' OR v.actual_check_out_at IS NOT NULL))
              OR (v_status = 'Overstay' AND v.actual_check_out_at IS NULL AND (v.status = 'Overstay' OR (v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < v_now)) AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = v.visitor_id AND vr.school_id = v.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)))
              OR (v_status = 'Scheduled' AND (v.status = 'Scheduled' OR (v.status = 'Blocked' AND v.check_in_at IS NULL)) AND v.actual_check_out_at IS NULL AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = v.visitor_id AND vr.school_id = v.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)))
              OR (v.status = v_status AND p.is_blacklisted IS NOT TRUE)
          )
          AND (
              v_date_from IS NULL
              OR (
                  CASE
                      WHEN v_status = 'Checked Out' THEN COALESCE(v.actual_check_out_at, v.check_in_at, v.created_at) >= v_date_from
                      ELSE COALESCE(v.check_in_at, v.created_at) >= v_date_from
                  END
              )
          )
          AND (
              v_date_to IS NULL
              OR (
                  CASE
                      WHEN v_status = 'Checked Out' THEN COALESCE(v.actual_check_out_at, v.check_in_at, v.created_at) <= v_date_to
                      ELSE COALESCE(v.check_in_at, v.created_at) <= v_date_to
                  END
              )
          )
        ORDER BY 
            CASE WHEN v_sort_by = 'visitor_name' AND v_sort_order = 'ASC' THEN p.full_name END ASC,
            CASE WHEN v_sort_by = 'visitor_name' AND v_sort_order = 'DESC' THEN p.full_name END DESC,
            CASE WHEN v_sort_by IN ('visitor_type', 'type') AND v_sort_order = 'ASC' THEN v.category END ASC,
            CASE WHEN v_sort_by IN ('visitor_type', 'type') AND v_sort_order = 'DESC' THEN v.category END DESC,
            CASE WHEN v_sort_by = 'purpose' AND v_sort_order = 'ASC' THEN v.purpose END ASC,
            CASE WHEN v_sort_by = 'purpose' AND v_sort_order = 'DESC' THEN v.purpose END DESC,
            CASE WHEN v_sort_by IN ('location', 'destination') AND v_sort_order = 'ASC' THEN v.destination END ASC,
            CASE WHEN v_sort_by IN ('location', 'destination') AND v_sort_order = 'DESC' THEN v.destination END DESC,
            CASE WHEN v_sort_by IN ('host_name', 'host') AND v_sort_order = 'ASC' THEN v.host_name END ASC,
            CASE WHEN v_sort_by IN ('host_name', 'host') AND v_sort_order = 'DESC' THEN v.host_name END DESC,
            CASE WHEN v_sort_by = 'check_in_at' AND v_sort_order = 'ASC' THEN v.check_in_at END ASC NULLS LAST,
            CASE WHEN v_sort_by = 'check_in_at' AND v_sort_order = 'DESC' THEN v.check_in_at END DESC NULLS LAST,
            CASE WHEN v_sort_by = 'expected_out_at' AND v_sort_order = 'ASC' THEN v.expected_out_at END ASC NULLS LAST,
            CASE WHEN v_sort_by = 'expected_out_at' AND v_sort_order = 'DESC' THEN v.expected_out_at END DESC NULLS LAST,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'ASC' THEN v.status END ASC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'DESC' THEN v.status END DESC,
            v.created_at DESC, v.id ASC
        LIMIT v_page_size OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'records', v_records,
        'pagination', jsonb_build_object(
            'page', v_page,
            'page_size', v_page_size,
            'total', v_total,
            'total_pages', CEIL(v_total::NUMERIC / v_page_size)::INT
        )
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_visitors_list_appointments(
    p_school_id UUID,
    p_params JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search VARCHAR := TRIM(COALESCE(p_params->>'search', ''));
    v_location VARCHAR := TRIM(COALESCE(p_params->>'location', 'All Locations'));
    v_category VARCHAR := TRIM(COALESCE(p_params->>'category', 'All Visitor Types'));
    v_status VARCHAR := TRIM(COALESCE(p_params->>'status', 'All Status'));
    v_sort_by VARCHAR := LOWER(TRIM(COALESCE(p_params->>'sort_by', 'scheduled_date')));
    v_sort_order VARCHAR := UPPER(TRIM(COALESCE(p_params->>'sort_order', 'ASC')));
    v_page INT := GREATEST(1, COALESCE((p_params->>'page')::INT, 1));
    v_page_size INT := GREATEST(1, LEAST(100, COALESCE((p_params->>'page_size')::INT, 10)));
    v_offset INT := (v_page - 1) * v_page_size;
    v_total_records INT := 0;
    v_records JSONB := '[]'::JSONB;
    v_date_from TIMESTAMPTZ := NULL;
    v_date_to TIMESTAMPTZ := NULL;
BEGIN
    IF p_params->>'date_from' IS NOT NULL AND p_params->>'date_from' != '' THEN
        v_date_from := (p_params->>'date_from')::TIMESTAMPTZ;
    END IF;
    IF p_params->>'date_to' IS NOT NULL AND p_params->>'date_to' != '' THEN
        v_date_to := (p_params->>'date_to')::TIMESTAMPTZ;
    END IF;

    SELECT COUNT(*) INTO v_total_records
    FROM public.visitor_appointments a
    JOIN public.visitor_profiles p ON a.visitor_id = p.id
    WHERE a.school_id = p_school_id
      AND (
          v_search = ''
          OR p.full_name ILIKE '%' || v_search || '%'
          OR p.phone ILIKE '%' || v_search || '%'
          OR a.appointment_number ILIKE '%' || v_search || '%'
          OR a.host_name ILIKE '%' || v_search || '%'
          OR a.purpose ILIKE '%' || v_search || '%'
          OR a.destination ILIKE '%' || v_search || '%'
      )
      AND (
          v_location = 'All Locations'
          OR v_location = 'All'
          OR v_location = ''
          OR LOWER(TRIM(COALESCE(a.destination, ''))) = LOWER(TRIM(v_location))
          OR a.destination ILIKE '%' || v_location || '%'
      )
      AND (
          v_category = 'All Visitor Types'
          OR v_category = 'All'
          OR v_category = ''
          OR p.visitor_type = v_category
      )
      AND (
          v_status = 'All Status'
          OR v_status = 'All'
          OR (v_status ILIKE 'Blocked' AND (
              p.is_blacklisted = TRUE
              OR EXISTS (
                  SELECT 1 FROM public.visitor_restrictions vr
                  WHERE vr.visitor_id = a.visitor_id
                    AND vr.school_id = a.school_id
                    AND vr.status = 'ACTIVE'
                    AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())
              )
          ))
          OR (v_status ILIKE 'Confirmed' AND a.status IN ('APPROVED', 'CONFIRMED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
          OR (v_status ILIKE 'Pending' AND a.status IN ('AWAITING_APPROVAL', 'PENDING') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
          OR (v_status ILIKE 'Today' AND a.scheduled_date = CURRENT_DATE AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
          OR (v_status ILIKE 'This Week' AND a.scheduled_date >= CURRENT_DATE AND a.scheduled_date <= (CURRENT_DATE + interval '7 days') AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
          OR (v_status ILIKE 'Expected' AND a.scheduled_date >= CURRENT_DATE AND a.scheduled_date <= (CURRENT_DATE + interval '7 days') AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
          OR (a.status ILIKE v_status AND p.is_blacklisted IS NOT TRUE)
      )
      AND (v_date_from IS NULL OR a.scheduled_date >= v_date_from::DATE)
      AND (v_date_to IS NULL OR a.scheduled_date <= v_date_to::DATE);

    SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_records
    FROM (
        SELECT jsonb_build_object(
            'id', a.id,
            'appointment_number', a.appointment_number,
            'visitor_id', a.visitor_id,
            'visitor_name', p.full_name,
            'photo_url', p.photo_url,
            'phone', p.phone,
            'visitor_type', p.visitor_type,
            'purpose', a.purpose,
            'location', a.destination,
            'destination', a.destination,
            'host_name', a.host_name,
            'host_department', a.host_department,
            'scheduled_date', to_char(a.scheduled_date, 'YYYY-MM-DD'),
            'scheduled_start_at', to_char(a.scheduled_start_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'scheduled_end_at', to_char(a.scheduled_end_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'status', CASE 
                WHEN p.is_blacklisted = TRUE 
                     OR EXISTS (
                         SELECT 1 FROM public.visitor_restrictions vr 
                         WHERE vr.visitor_id = a.visitor_id 
                           AND vr.school_id = a.school_id 
                           AND vr.status = 'ACTIVE' 
                           AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())
                     ) THEN 'Blocked'
                WHEN a.status IN ('APPROVED', 'CONFIRMED') THEN 'Confirmed'
                WHEN a.status IN ('AWAITING_APPROVAL', 'PENDING') THEN 'Pending'
                ELSE a.status
            END,
            'notes', a.notes,
            'remarks', a.notes,
            'rejection_reason', a.rejection_reason,
            'created_at', to_char(a.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        ) AS row_data
        FROM public.visitor_appointments a
        JOIN public.visitor_profiles p ON a.visitor_id = p.id
        WHERE a.school_id = p_school_id
          AND (
              v_search = ''
              OR p.full_name ILIKE '%' || v_search || '%'
              OR p.phone ILIKE '%' || v_search || '%'
              OR a.appointment_number ILIKE '%' || v_search || '%'
              OR a.host_name ILIKE '%' || v_search || '%'
              OR a.purpose ILIKE '%' || v_search || '%'
              OR a.destination ILIKE '%' || v_search || '%'
          )
          AND (
              v_location = 'All Locations'
              OR v_location = 'All'
              OR v_location = ''
              OR LOWER(TRIM(COALESCE(a.destination, ''))) = LOWER(TRIM(v_location))
              OR a.destination ILIKE '%' || v_location || '%'
          )
          AND (
              v_category = 'All Visitor Types'
              OR v_category = 'All'
              OR v_category = ''
              OR p.visitor_type = v_category
          )
          AND (
              v_status = 'All Status'
              OR v_status = 'All'
              OR (v_status ILIKE 'Blocked' AND (
                  p.is_blacklisted = TRUE
                  OR EXISTS (
                      SELECT 1 FROM public.visitor_restrictions vr
                      WHERE vr.visitor_id = a.visitor_id
                        AND vr.school_id = a.school_id
                        AND vr.status = 'ACTIVE'
                        AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())
                  )
              ))
              OR (v_status ILIKE 'Confirmed' AND a.status IN ('APPROVED', 'CONFIRMED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
              OR (v_status ILIKE 'Pending' AND a.status IN ('AWAITING_APPROVAL', 'PENDING') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
              OR (v_status ILIKE 'Today' AND a.scheduled_date = CURRENT_DATE AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
              OR (v_status ILIKE 'This Week' AND a.scheduled_date >= CURRENT_DATE AND a.scheduled_date <= (CURRENT_DATE + interval '7 days') AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
              OR (v_status ILIKE 'Expected' AND a.scheduled_date >= CURRENT_DATE AND a.scheduled_date <= (CURRENT_DATE + interval '7 days') AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
              OR (a.status ILIKE v_status AND p.is_blacklisted IS NOT TRUE)
          )
          AND (v_date_from IS NULL OR a.scheduled_date >= v_date_from::DATE)
          AND (v_date_to IS NULL OR a.scheduled_date <= v_date_to::DATE)
        ORDER BY 
            CASE WHEN v_sort_by = 'visitor_name' AND v_sort_order = 'ASC' THEN p.full_name END ASC,
            CASE WHEN v_sort_by = 'visitor_name' AND v_sort_order = 'DESC' THEN p.full_name END DESC,
            CASE WHEN v_sort_by IN ('visitor_type', 'type') AND v_sort_order = 'ASC' THEN p.visitor_type END ASC,
            CASE WHEN v_sort_by IN ('visitor_type', 'type') AND v_sort_order = 'DESC' THEN p.visitor_type END DESC,
            CASE WHEN v_sort_by = 'purpose' AND v_sort_order = 'ASC' THEN a.purpose END ASC,
            CASE WHEN v_sort_by = 'purpose' AND v_sort_order = 'DESC' THEN a.purpose END DESC,
            CASE WHEN v_sort_by IN ('location', 'destination') AND v_sort_order = 'ASC' THEN a.destination END ASC,
            CASE WHEN v_sort_by IN ('location', 'destination') AND v_sort_order = 'DESC' THEN a.destination END DESC,
            CASE WHEN v_sort_by IN ('host_name', 'host') AND v_sort_order = 'ASC' THEN a.host_name END ASC,
            CASE WHEN v_sort_by IN ('host_name', 'host') AND v_sort_order = 'DESC' THEN a.host_name END DESC,
            CASE WHEN v_sort_by IN ('scheduled_date', 'date', 'scheduled_start_at', 'scheduled_start') AND v_sort_order = 'ASC' THEN a.scheduled_start_at END ASC,
            CASE WHEN v_sort_by IN ('scheduled_date', 'date', 'scheduled_start_at', 'scheduled_start') AND v_sort_order = 'DESC' THEN a.scheduled_start_at END DESC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'ASC' THEN a.status END ASC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'DESC' THEN a.status END DESC,
            a.scheduled_date ASC, a.scheduled_start_at ASC, a.id ASC
        LIMIT v_page_size OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'records', v_records,
        'pagination', jsonb_build_object(
            'page', v_page,
            'page_size', v_page_size,
            'total_records', v_total_records,
            'total_pages', CEIL(v_total_records::NUMERIC / GREATEST(1, v_page_size))
        )
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_visitors_list_restrictions(
    p_school_id UUID,
    p_params JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search VARCHAR := TRIM(COALESCE(p_params->>'search', ''));
    v_status VARCHAR := TRIM(COALESCE(p_params->>'status', 'All'));
    v_location VARCHAR := TRIM(COALESCE(p_params->>'location', 'All'));
    v_reason VARCHAR := TRIM(COALESCE(p_params->>'reason', p_params->>'category', 'All'));
    v_sort_by VARCHAR := LOWER(TRIM(COALESCE(p_params->>'sort_by', 'created_at')));
    v_sort_order VARCHAR := UPPER(TRIM(COALESCE(p_params->>'sort_order', 'DESC')));
    v_page INT := GREATEST(1, COALESCE((p_params->>'page')::INT, 1));
    v_page_size INT := GREATEST(1, LEAST(100, COALESCE((p_params->>'page_size')::INT, 10)));
    v_offset INT := (v_page - 1) * v_page_size;
    v_total_records INT := 0;
    v_records JSONB := '[]'::JSONB;
    v_date_from TIMESTAMPTZ := NULL;
    v_date_to TIMESTAMPTZ := NULL;
BEGIN
    IF p_params->>'date_from' IS NOT NULL AND p_params->>'date_from' != '' THEN
        v_date_from := (p_params->>'date_from')::TIMESTAMPTZ;
    END IF;
    IF p_params->>'date_to' IS NOT NULL AND p_params->>'date_to' != '' THEN
        v_date_to := (p_params->>'date_to')::TIMESTAMPTZ;
    END IF;

    WITH unique_restrictions AS (
        SELECT DISTINCT ON (
            RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10),
            COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')), ''), 'NONE'),
            COALESCE(NULLIF(TRIM(LOWER(p.email)), ''), 'NONE')
        )
            r.id,
            r.visitor_id,
            r.school_id,
            r.scope_type,
            r.scope_name,
            r.reason_category,
            r.confidential_notes,
            r.remarks,
            r.status,
            r.effective_from,
            r.blocked_on,
            r.valid_till_text,
            r.is_permanent,
            r.expires_at,
            r.review_at,
            r.requested_by_name,
            r.approved_by_name,
            r.lifted_by_name,
            r.lift_reason,
            r.created_at,
            p.full_name,
            p.phone,
            p.photo_url,
            p.email,
            p.id_type,
            p.id_number_masked
        FROM public.visitor_restrictions r
        JOIN public.visitor_profiles p ON r.visitor_id = p.id
        WHERE r.school_id = p_school_id
        ORDER BY RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10),
                 COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')), ''), 'NONE'),
                 COALESCE(NULLIF(TRIM(LOWER(p.email)), ''), 'NONE'),
                 CASE WHEN UPPER(r.status) = 'ACTIVE' THEN 1 ELSE 2 END,
                 r.created_at DESC
    )
    SELECT COUNT(*) INTO v_total_records
    FROM unique_restrictions ur
    WHERE (
          v_search = ''
          OR ur.full_name ILIKE '%' || v_search || '%'
          OR ur.phone ILIKE '%' || v_search || '%'
          OR ur.reason_category ILIKE '%' || v_search || '%'
          OR ur.scope_name ILIKE '%' || v_search || '%'
      )
      AND (
          v_status = 'All'
          OR v_status = 'All Status'
          OR (v_status ILIKE 'Ended' AND UPPER(ur.status) IN ('EXPIRED', 'LIFTED'))
          OR (v_status ILIKE 'Attempted' AND EXISTS (
              SELECT 1 FROM public.visitor_access_attempts aa
              WHERE aa.school_id = ur.school_id
                AND (aa.restriction_id = ur.id OR aa.visitor_id = ur.visitor_id)
                AND aa.outcome ILIKE 'Blocked%'
          ))
          OR UPPER(ur.status) = UPPER(v_status)
      )
      AND (
          v_location = 'All'
          OR v_location = 'All Locations'
          OR v_location = ''
          OR LOWER(TRIM(COALESCE(ur.scope_name, ''))) = LOWER(TRIM(v_location))
          OR ur.scope_name ILIKE '%' || v_location || '%'
          OR (v_location = 'Entire Campus' AND ur.scope_type = 'CAMPUS')
      )
      AND (
          v_reason = 'All'
          OR v_reason = 'All Block Reasons'
          OR v_reason = 'All Visitor Types'
          OR v_reason = ''
          OR LOWER(TRIM(COALESCE(ur.reason_category, ''))) = LOWER(TRIM(v_reason))
          OR ur.reason_category ILIKE '%' || v_reason || '%'
      )
      AND (v_date_from IS NULL OR ur.created_at >= v_date_from)
      AND (v_date_to IS NULL OR ur.created_at <= v_date_to);

    WITH unique_restrictions AS (
        SELECT DISTINCT ON (
            RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10),
            COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')), ''), 'NONE'),
            COALESCE(NULLIF(TRIM(LOWER(p.email)), ''), 'NONE')
        )
            r.id,
            r.visitor_id,
            r.school_id,
            r.scope_type,
            r.scope_name,
            r.reason_category,
            r.confidential_notes,
            r.remarks,
            r.status,
            r.effective_from,
            r.blocked_on,
            r.valid_till_text,
            r.is_permanent,
            r.expires_at,
            r.review_at,
            r.requested_by_name,
            r.approved_by_name,
            r.lifted_by_name,
            r.lift_reason,
            r.created_at,
            p.full_name,
            p.phone,
            p.photo_url,
            p.email,
            p.id_type,
            p.id_number_masked
        FROM public.visitor_restrictions r
        JOIN public.visitor_profiles p ON r.visitor_id = p.id
        WHERE r.school_id = p_school_id
        ORDER BY RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10),
                 COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')), ''), 'NONE'),
                 COALESCE(NULLIF(TRIM(LOWER(p.email)), ''), 'NONE'),
                 CASE WHEN UPPER(r.status) = 'ACTIVE' THEN 1 ELSE 2 END,
                 r.created_at DESC
    )
    SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_records
    FROM (
        SELECT jsonb_build_object(
            'id', ur.id,
            'visitor_id', ur.visitor_id,
            'visitor_name', ur.full_name,
            'visitor_phone', ur.phone,
            'photo_url', ur.photo_url,
            'mobile_no', ur.phone,
            'phone', ur.phone,
            'email', COALESCE(ur.email, ''),
            'id_type', COALESCE(ur.id_type, 'Aadhaar Card'),
            'id_number', COALESCE(ur.id_number_masked, 'XXXX-XXXX-1234'),
            'id_number_masked', COALESCE(ur.id_number_masked, 'XXXX-XXXX-1234'),
            'scope_type', ur.scope_type,
            'scope_name', ur.scope_name,
            'reason_category', ur.reason_category,
            'confidential_notes', ur.confidential_notes,
            'remarks', ur.remarks,
            'status', ur.status,
            'effective_from', to_char(ur.effective_from, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'blocked_on', to_char(COALESCE(ur.blocked_on, ur.created_at), 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'valid_till', ur.valid_till_text,
            'valid_till_text', ur.valid_till_text,
            'is_permanent', ur.is_permanent,
            'expires_at', to_char(ur.expires_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'review_at', to_char(ur.review_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'requested_by_name', ur.requested_by_name,
            'approved_by_name', ur.approved_by_name,
            'blocked_by_name', COALESCE(ur.requested_by_name, 'Rahul Sharma (Security)'),
            'lifted_by_name', ur.lifted_by_name,
            'lift_reason', ur.lift_reason,
            'created_at', to_char(ur.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        ) AS row_data
        FROM unique_restrictions ur
        WHERE (
              v_search = ''
              OR ur.full_name ILIKE '%' || v_search || '%'
              OR ur.phone ILIKE '%' || v_search || '%'
              OR ur.reason_category ILIKE '%' || v_search || '%'
              OR ur.scope_name ILIKE '%' || v_search || '%'
          )
          AND (
              v_status = 'All'
              OR v_status = 'All Status'
              OR (v_status ILIKE 'Ended' AND UPPER(ur.status) IN ('EXPIRED', 'LIFTED'))
              OR (v_status ILIKE 'Attempted' AND EXISTS (
                  SELECT 1 FROM public.visitor_access_attempts aa
                  WHERE aa.school_id = ur.school_id
                    AND (aa.restriction_id = ur.id OR aa.visitor_id = ur.visitor_id)
                    AND aa.outcome ILIKE 'Blocked%'
              ))
              OR UPPER(ur.status) = UPPER(v_status)
          )
          AND (
              v_location = 'All'
              OR v_location = 'All Locations'
              OR v_location = ''
              OR LOWER(TRIM(COALESCE(ur.scope_name, ''))) = LOWER(TRIM(v_location))
              OR ur.scope_name ILIKE '%' || v_location || '%'
              OR (v_location = 'Entire Campus' AND ur.scope_type = 'CAMPUS')
          )
          AND (
              v_reason = 'All'
              OR v_reason = 'All Block Reasons'
              OR v_reason = 'All Visitor Types'
              OR v_reason = ''
              OR LOWER(TRIM(COALESCE(ur.reason_category, ''))) = LOWER(TRIM(v_reason))
              OR ur.reason_category ILIKE '%' || v_reason || '%'
          )
          AND (v_date_from IS NULL OR ur.created_at >= v_date_from)
          AND (v_date_to IS NULL OR ur.created_at <= v_date_to)
        ORDER BY 
            CASE WHEN v_sort_by IN ('name', 'visitor_name') AND v_sort_order = 'ASC' THEN ur.full_name END ASC,
            CASE WHEN v_sort_by IN ('name', 'visitor_name') AND v_sort_order = 'DESC' THEN ur.full_name END DESC,
            CASE WHEN v_sort_by IN ('phone', 'mobile_no') AND v_sort_order = 'ASC' THEN ur.phone END ASC,
            CASE WHEN v_sort_by IN ('phone', 'mobile_no') AND v_sort_order = 'DESC' THEN ur.phone END DESC,
            CASE WHEN v_sort_by IN ('id_number', 'id_number_masked') AND v_sort_order = 'ASC' THEN ur.id_number_masked END ASC,
            CASE WHEN v_sort_by IN ('id_number', 'id_number_masked') AND v_sort_order = 'DESC' THEN ur.id_number_masked END DESC,
            CASE WHEN v_sort_by IN ('reason', 'reason_category', 'block_reason') AND v_sort_order = 'ASC' THEN ur.reason_category END ASC,
            CASE WHEN v_sort_by IN ('reason', 'reason_category', 'block_reason') AND v_sort_order = 'DESC' THEN ur.reason_category END DESC,
            CASE WHEN v_sort_by IN ('location', 'scope_name') AND v_sort_order = 'ASC' THEN ur.scope_name END ASC,
            CASE WHEN v_sort_by IN ('location', 'scope_name') AND v_sort_order = 'DESC' THEN ur.scope_name END DESC,
            CASE WHEN v_sort_by = 'blocked_on' AND v_sort_order = 'ASC' THEN ur.blocked_on END ASC,
            CASE WHEN v_sort_by = 'blocked_on' AND v_sort_order = 'DESC' THEN ur.blocked_on END DESC,
            CASE WHEN v_sort_by = 'valid_till' AND v_sort_order = 'ASC' THEN ur.valid_till_text END ASC,
            CASE WHEN v_sort_by = 'valid_till' AND v_sort_order = 'DESC' THEN ur.valid_till_text END DESC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'ASC' THEN ur.status END ASC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'DESC' THEN ur.status END DESC,
            CASE WHEN UPPER(ur.status) = 'ACTIVE' THEN 1 ELSE 2 END,
            ur.created_at DESC, ur.id ASC
        LIMIT v_page_size OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'records', v_records,
        'pagination', jsonb_build_object(
            'total_records', v_total_records,
            'page', v_page,
            'page_size', v_page_size,
            'total_pages', CEIL(v_total_records::NUMERIC / GREATEST(1, v_page_size))
        )
    );
END;
$$;
