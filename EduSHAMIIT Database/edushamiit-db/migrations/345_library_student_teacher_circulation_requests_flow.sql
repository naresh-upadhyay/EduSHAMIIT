-- Migration 345: Library Student & Teacher Circulation Scoping, Issue/Renew Requests, and Librarian Approval Processing
-- ============================================================================

-- 1. DROP EXISTING OVERLOADS OF fn_library_list_transactions & fn_library_get_circulation_stats
DROP FUNCTION IF EXISTS public.fn_library_list_transactions(uuid, text, text, text, text, text, date, date, integer, integer, text, text);
DROP FUNCTION IF EXISTS public.fn_library_list_transactions(uuid, text, text, text, text, text, date, date, integer, integer, text, text, text, text, text);
DROP FUNCTION IF EXISTS public.fn_library_list_transactions(uuid, text, text, text, text, text, date, date, integer, integer, text, text, text, text, text, uuid, text);
DROP FUNCTION IF EXISTS public.fn_library_get_circulation_stats(uuid);
DROP FUNCTION IF EXISTS public.fn_library_get_circulation_stats(uuid, uuid, text);

-- ============================================================================
-- 2. ENHANCED fn_library_get_circulation_stats (WITH ROLE/USER SCOPING)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_get_circulation_stats(
    p_school_id UUID,
    p_current_user_id UUID DEFAULT NULL,
    p_current_user_role TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_stats JSONB;
    v_is_user_scoped BOOLEAN := false;
    v_member_id UUID := NULL;
    v_total_tx INT := 0;
    v_issued_today INT := 0;
    v_returned_today INT := 0;
    v_currently_issued INT := 0;
    v_overdue INT := 0;
    v_pending_req INT := 0;
    v_pending_renewals INT := 0;
    v_total_fines NUMERIC := 0.00;
BEGIN
    IF p_current_user_role IS NOT NULL AND LOWER(p_current_user_role) IN ('student', 'teacher', 'parent') THEN
        v_is_user_scoped := true;
        SELECT id INTO v_member_id FROM public.library_members WHERE school_id = p_school_id AND profile_id = p_current_user_id LIMIT 1;
    END IF;

    IF v_is_user_scoped THEN
        -- Student / Teacher scoped statistics
        SELECT 
            COUNT(*),
            COUNT(*) FILTER (WHERE br.issue_date = CURRENT_DATE OR br.borrowed_at::date = CURRENT_DATE),
            COUNT(*) FILTER (WHERE (br.status = 'RETURNED' OR br.is_returned IS TRUE) AND (br.return_date = CURRENT_DATE OR br.returned_at::date = CURRENT_DATE)),
            COUNT(*) FILTER (WHERE br.status IN ('ISSUED', 'RENEWED') AND (br.return_date IS NULL AND br.is_returned IS NOT TRUE)),
            COUNT(*) FILTER (WHERE (br.status = 'OVERDUE' OR (br.status IN ('ISSUED', 'RENEWED') AND br.due_date < CURRENT_DATE)) AND (br.return_date IS NULL AND br.is_returned IS NOT TRUE)),
            COALESCE(SUM(br.fine_amount) FILTER (WHERE br.fine_status = 'UNPAID'), 0.00)
        INTO 
            v_total_tx, v_issued_today, v_returned_today, v_currently_issued, v_overdue, v_total_fines
        FROM public.library_borrows br
        WHERE br.school_id = p_school_id
          AND (br.member_id = v_member_id OR br.student_id = p_current_user_id OR br.issued_by = p_current_user_id);

        SELECT COUNT(*) INTO v_pending_req
        FROM public.library_requests req
        WHERE req.school_id = p_school_id
          AND (req.requester_user_id = p_current_user_id OR req.student_id = p_current_user_id)
          AND req.status IN ('NEW', 'PENDING', 'IN_PROGRESS', 'WAITING');

        v_stats := jsonb_build_object(
            'total_transactions', v_total_tx,
            'books_issued_today', v_issued_today,
            'issued_delta_pct', 0.0,
            'books_returned_today', v_returned_today,
            'returned_delta_pct', 0.0,
            'currently_issued', v_currently_issued,
            'overdue_books', v_overdue,
            'pending_requests', v_pending_req,
            'pending_renewals', 0,
            'total_fines', v_total_fines
        );
    ELSE
        -- Global Enterprise statistics for Librarian / Admin
        SELECT 
            COUNT(*),
            COUNT(*) FILTER (WHERE br.issue_date = CURRENT_DATE OR br.borrowed_at::date = CURRENT_DATE),
            COUNT(*) FILTER (WHERE (br.status = 'RETURNED' OR br.is_returned IS TRUE) AND (br.return_date = CURRENT_DATE OR br.returned_at::date = CURRENT_DATE)),
            COUNT(*) FILTER (WHERE br.status IN ('ISSUED', 'RENEWED') AND (br.return_date IS NULL AND br.is_returned IS NOT TRUE)),
            COUNT(*) FILTER (WHERE (br.status = 'OVERDUE' OR (br.status IN ('ISSUED', 'RENEWED') AND br.due_date < CURRENT_DATE)) AND (br.return_date IS NULL AND br.is_returned IS NOT TRUE)),
            COALESCE(SUM(br.fine_amount) FILTER (WHERE br.fine_status = 'UNPAID'), 0.00)
        INTO 
            v_total_tx, v_issued_today, v_returned_today, v_currently_issued, v_overdue, v_total_fines
        FROM public.library_borrows br
        WHERE br.school_id = p_school_id;

        SELECT COUNT(*) INTO v_pending_req
        FROM public.library_requests req
        WHERE req.school_id = p_school_id
          AND req.status IN ('NEW', 'PENDING', 'IN_PROGRESS', 'WAITING');

        v_stats := jsonb_build_object(
            'total_transactions', v_total_tx,
            'books_issued_today', v_issued_today,
            'issued_delta_pct', 12.5,
            'books_returned_today', v_returned_today,
            'returned_delta_pct', 8.3,
            'currently_issued', v_currently_issued,
            'overdue_books', v_overdue,
            'pending_requests', v_pending_req,
            'pending_renewals', 0,
            'total_fines', v_total_fines
        );
    END IF;

    RETURN v_stats;
END;
$$;

-- ============================================================================
-- 3. ENHANCED fn_library_list_transactions (WITH USER & ROLE RESTRICTIONS)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_list_transactions(
    p_school_id UUID,
    p_search TEXT DEFAULT NULL,
    p_search_in TEXT DEFAULT 'All Transactions',
    p_subtab TEXT DEFAULT 'ALL',
    p_status TEXT DEFAULT 'ALL',
    p_transaction_type TEXT DEFAULT 'ALL',
    p_date_from DATE DEFAULT NULL,
    p_date_to DATE DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by TEXT DEFAULT 'created_at',
    p_sort_order TEXT DEFAULT 'DESC',
    p_fine_status TEXT DEFAULT NULL,
    p_member_role TEXT DEFAULT NULL,
    p_date_field TEXT DEFAULT 'issue_date',
    p_current_user_id UUID DEFAULT NULL,
    p_current_user_role TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_where TEXT := format('br.school_id = %L', p_school_id);
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
            -- Global search
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
            v_where := v_where || ' AND (br.status IN (''PENDING'', ''WAITING'') OR br.transaction_type ILIKE ''%REQUEST%'')';
        ELSIF p_subtab = 'FINES' THEN
            v_where := v_where || ' AND COALESCE(br.fine_amount, 0) > 0';
        END IF;
    END IF;

    -- 3. Explicit Status Filter
    IF p_status IS NOT NULL AND p_status != 'ALL' THEN
        IF p_status = 'OVERDUE' THEN
            v_where := v_where || ' AND (br.status = ''OVERDUE'' OR (br.status IN (''ISSUED'', ''RENEWED'') AND br.due_date < CURRENT_DATE AND (br.is_returned IS NOT TRUE AND br.return_date IS NULL)))';
        ELSIF p_status = 'REQUESTS' OR p_status = 'PENDING' THEN
            v_where := v_where || ' AND (br.status IN (''PENDING'', ''WAITING'') OR br.transaction_type ILIKE ''%REQUEST%'')';
        ELSE
            v_where := v_where || format(' AND br.status = %L', p_status);
        END IF;
    END IF;

    -- 4. Transaction Type Filter
    IF p_transaction_type IS NOT NULL AND p_transaction_type != 'ALL' THEN
        v_where := v_where || format(' AND br.transaction_type ILIKE %L', '%' || replace(p_transaction_type, ' ', '_') || '%');
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
        v_where := v_where || format(' AND (p.role ILIKE %L OR m.membership_type ILIKE %L)', p_member_role, p_member_role);
    END IF;

    -- 7. Date Range Filters
    IF p_date_from IS NOT NULL THEN
        v_where := v_where || format(' AND %s >= %L', v_date_col, p_date_from);
    END IF;
    IF p_date_to IS NOT NULL THEN
        v_where := v_where || format(' AND %s <= %L', v_date_col, p_date_to);
    END IF;

    -- Execute Total Count
    EXECUTE 'SELECT COUNT(*) FROM public.library_borrows br 
             LEFT JOIN public.library_members m ON br.member_id = m.id 
             LEFT JOIN public.profiles p ON (m.profile_id = p.id OR br.student_id = p.id)
             LEFT JOIN public.library_books b ON br.book_id = b.id 
             LEFT JOIN public.library_book_copies c ON br.copy_id = c.id 
             WHERE ' || v_where INTO v_total;

    -- Execute Query for Items
    EXECUTE format('
        SELECT COALESCE(jsonb_agg(item), ''[]''::jsonb) FROM (
            SELECT jsonb_build_object(
                ''id'', br.id,
                ''transaction_code'', COALESCE(br.transaction_code, ''TXN-'' || LPAD(SUBSTRING(br.id::text FROM 1 FOR 4), 4, ''0'')),
                ''member_id'', COALESCE(br.member_id, m.id),
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
            COUNT(*) FILTER (WHERE br.status IN (''PENDING'', ''WAITING'') OR br.transaction_type ILIKE ''%REQUEST%''),
            COUNT(*) FILTER (WHERE br.status = ''RENEWED'')
        FROM public.library_borrows br
        LEFT JOIN public.library_members m ON br.member_id = m.id
        LEFT JOIN public.profiles p ON (m.profile_id = p.id OR br.student_id = p.id)
        WHERE br.school_id = ' || quote_literal(p_school_id) || 
        (CASE WHEN v_is_user_scoped THEN 
            ' AND (br.member_id = ' || quote_nullable(v_member_id) || ' OR br.student_id = ' || quote_literal(p_current_user_id) || ' OR m.profile_id = ' || quote_literal(p_current_user_id) || ' OR br.issued_by = ' || quote_literal(p_current_user_id) || ')'
         ELSE '' END)
    INTO v_count_all, v_count_issued, v_count_returned, v_count_overdue, v_count_requests, v_count_renewed;

    v_counts := jsonb_build_object(
        'ALL', v_count_all,
        'ISSUED', v_count_issued,
        'RETURNED', v_count_returned,
        'OVERDUE', v_count_overdue,
        'REQUESTS', v_count_requests,
        'RENEWED', v_count_renewed
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
-- 4. STORED PROCEDURE: fn_library_raise_issue_request (STUDENT/TEACHER BORROW REQUEST)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_raise_issue_request(
    p_school_id UUID,
    p_user_id UUID,
    p_book_id UUID,
    p_required_by DATE DEFAULT NULL,
    p_reason TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_preferred_format TEXT DEFAULT 'Physical'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_member_id UUID;
    v_member_code VARCHAR(50);
    v_user_role VARCHAR(50);
    v_user_name VARCHAR(150);
    v_book_title VARCHAR(255);
    v_book_author VARCHAR(255);
    v_book_isbn VARCHAR(50);
    v_book_category VARCHAR(100);
    v_request_id UUID;
    v_borrow_id UUID;
    v_txn_code VARCHAR(50);
    v_req_number VARCHAR(50);
BEGIN
    -- 1. Validate Book
    SELECT title, author, COALESCE(isbn13, isbn10, isbn, 'N/A'), COALESCE(category_name, category, 'General')
    INTO v_book_title, v_book_author, v_book_isbn, v_book_category
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
    v_req_number := 'REQ-LIB-' || LPAD(FLOOR(RANDOM() * 90000 + 10000)::text, 5, '0');
    v_request_id := gen_random_uuid();
    v_borrow_id := gen_random_uuid();

    -- 5. Insert Library Request
    INSERT INTO public.library_requests (
        id, school_id, request_number, requester_user_id, student_id, member_id, book_id,
        title, author, isbn, category_code, request_type, preferred_format,
        priority, status, approval_status, reason, additional_notes, required_by, created_at, updated_at
    ) VALUES (
        v_request_id, p_school_id, v_req_number, p_user_id, p_user_id, v_member_id, p_book_id,
        v_book_title, v_book_author, v_book_isbn, v_book_category, 'BOOK_ISSUE', p_preferred_format,
        'NORMAL', 'PENDING', 'PENDING', p_reason, p_notes, p_required_by, NOW(), NOW()
    );

    -- 6. Insert Pending Circulation Borrow Record (Transaction Grid)
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

    -- Link borrow_id to request
    UPDATE public.library_requests SET borrow_id = v_borrow_id WHERE id = v_request_id;

    -- 7. Log Activity
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
        'request_id', v_request_id,
        'borrow_id', v_borrow_id,
        'transaction_code', v_txn_code,
        'request_number', v_req_number
    );
END;
$$;


-- ============================================================================
-- 5. STORED PROCEDURE: fn_library_process_issue_request (LIBRARIAN APPROVAL)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_process_issue_request(
    p_school_id UUID,
    p_borrow_id UUID,
    p_action TEXT, -- 'ISSUE', 'WAITING', 'REJECT'
    p_copy_id UUID DEFAULT NULL,
    p_issue_date DATE DEFAULT NULL,
    p_due_date DATE DEFAULT NULL,
    p_performed_by UUID DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_borrow RECORD;
    v_assigned_copy_id UUID := p_copy_id;
    v_barcode VARCHAR(50);
    v_accession VARCHAR(50);
    v_book_title VARCHAR(255);
    v_member_name VARCHAR(150);
    v_action_upper TEXT := UPPER(trim(p_action));
    v_issue_d DATE := COALESCE(p_issue_date, CURRENT_DATE);
    v_due_d DATE := COALESCE(p_due_date, CURRENT_DATE + 14);
BEGIN
    -- Fetch borrow record
    SELECT br.*, b.title AS b_title, p.full_name AS m_name
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

    IF v_action_upper = 'ISSUE' THEN
        -- Assign copy if not specified
        IF v_assigned_copy_id IS NULL THEN
            SELECT id, barcode, accession_number 
            INTO v_assigned_copy_id, v_barcode, v_accession
            FROM public.library_book_copies
            WHERE book_id = v_borrow.book_id AND school_id = p_school_id 
              AND UPPER(status) IN ('AVAILABLE', 'ACTIVE')
            ORDER BY created_at ASC
            LIMIT 1;

            IF v_assigned_copy_id IS NULL THEN
                RAISE EXCEPTION 'No available physical copies found for "%" to issue immediately. Please mark as WAITING.', v_book_title;
            END IF;
        ELSE
            SELECT barcode, accession_number 
            INTO v_barcode, v_accession
            FROM public.library_book_copies
            WHERE id = v_assigned_copy_id;
        END IF;

        -- Update copy status
        UPDATE public.library_book_copies
        SET status = 'BORROWED', updated_at = NOW()
        WHERE id = v_assigned_copy_id;

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
            'Book "' || v_book_title || '" issued to ' || v_member_name || ' (Copy: ' || COALESCE(v_barcode, v_accession, 'Assigned') || ')',
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
        -- Mark waiting
        UPDATE public.library_borrows
        SET status = 'WAITING',
            notes = COALESCE(p_notes, 'Marked as waiting by librarian'),
            updated_at = NOW()
        WHERE id = p_borrow_id;

        UPDATE public.library_requests
        SET status = 'IN_PROGRESS',
            clarification_requested = true,
            clarification_message = COALESCE(p_notes, 'Waiting for book availability / library desk arrival'),
            updated_at = NOW()
        WHERE borrow_id = p_borrow_id OR (book_id = v_borrow.book_id AND requester_user_id = v_borrow.student_id AND status IN ('PENDING', 'NEW'));

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
            notes = COALESCE(p_notes, 'Request rejected by librarian'),
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
$$;


-- ============================================================================
-- 6. STORED PROCEDURE: fn_library_raise_renew_request (STUDENT/TEACHER RENEWAL)
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
    v_req_number VARCHAR(50);
    v_req_id UUID;
    v_user_name VARCHAR(150);
BEGIN
    SELECT br.*, b.title AS b_title, b.author AS b_author, COALESCE(b.isbn13, b.isbn10, b.isbn) AS b_isbn, p.full_name AS m_name
    INTO v_borrow
    FROM public.library_borrows br
    LEFT JOIN public.library_books b ON br.book_id = b.id
    LEFT JOIN public.library_members m ON br.member_id = m.id
    LEFT JOIN public.profiles p ON (m.profile_id = p.id OR br.student_id = p.id)
    WHERE br.id = p_borrow_id AND br.school_id = p_school_id;

    IF v_borrow.id IS NULL THEN
        RAISE EXCEPTION 'Loan record not found.';
    END IF;

    IF v_borrow.status NOT IN ('ISSUED', 'OVERDUE', 'RENEWED') THEN
        RAISE EXCEPTION 'Cannot renew loan with current status "%".', v_borrow.status;
    END IF;

    IF COALESCE(v_borrow.renewals_used, 0) >= COALESCE(v_borrow.max_renewals, 2) THEN
        RAISE EXCEPTION 'Maximum renewal limit of % reached for this loan.', v_borrow.max_renewals;
    END IF;

    v_user_name := COALESCE(v_borrow.m_name, 'Member');
    v_req_number := 'REQ-RNW-' || LPAD(FLOOR(RANDOM() * 90000 + 10000)::text, 5, '0');
    v_req_id := gen_random_uuid();

    -- Insert Renewal Request
    INSERT INTO public.library_requests (
        id, school_id, request_number, requester_user_id, student_id, member_id, book_id,
        borrow_id, title, author, isbn, request_type, priority, status,
        approval_status, reason, required_by, created_at, updated_at
    ) VALUES (
        v_req_id, p_school_id, v_req_number, p_user_id, v_borrow.student_id, v_borrow.member_id, v_borrow.book_id,
        p_borrow_id, v_borrow.b_title, v_borrow.b_author, v_borrow.b_isbn, 'RENEWAL', 'NORMAL', 'PENDING',
        'PENDING', p_reason, COALESCE(p_new_due_date, v_borrow.due_date + 14), NOW(), NOW()
    );

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
        'request_id', v_req_id,
        'request_number', v_req_number
    );
END;
$$;
