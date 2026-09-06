-- ============================================================================
-- Migration 331: Library Circulation & Issue / Return Transaction System
-- High-Performance PostgreSQL Stored Procedures, Multi-Tenant Architecture,
-- Real-Time Activity Feeds, Overdue Fine Calculations, and Atomic Lifecycles.
-- ============================================================================

-- 1. ENHANCE LIBRARY_BORROWS TABLE
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_borrows' AND column_name = 'transaction_code') THEN
        ALTER TABLE public.library_borrows ADD COLUMN transaction_code VARCHAR(50);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_borrows' AND column_name = 'transaction_type') THEN
        ALTER TABLE public.library_borrows ADD COLUMN transaction_type VARCHAR(50) DEFAULT 'MANUAL_ISSUE';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_borrows' AND column_name = 'fine_status') THEN
        ALTER TABLE public.library_borrows ADD COLUMN fine_status VARCHAR(30) DEFAULT 'NONE';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_borrows' AND column_name = 'damage_charge') THEN
        ALTER TABLE public.library_borrows ADD COLUMN damage_charge NUMERIC(10,2) DEFAULT 0.00;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_borrows' AND column_name = 'lost_charge') THEN
        ALTER TABLE public.library_borrows ADD COLUMN lost_charge NUMERIC(10,2) DEFAULT 0.00;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_borrows' AND column_name = 'last_renewed_at') THEN
        ALTER TABLE public.library_borrows ADD COLUMN last_renewed_at TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_borrows' AND column_name = 'last_renewed_by') THEN
        ALTER TABLE public.library_borrows ADD COLUMN last_renewed_by UUID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_borrows' AND column_name = 'created_at') THEN
        ALTER TABLE public.library_borrows ADD COLUMN created_at TIMESTAMPTZ DEFAULT NOW();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_borrows' AND column_name = 'updated_at') THEN
        ALTER TABLE public.library_borrows ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    END IF;
END $$;

-- 2. CREATE CIRCULATION ACTIVITIES TABLE
CREATE TABLE IF NOT EXISTS public.library_circulation_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    activity_type VARCHAR(50) NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    member_id UUID REFERENCES public.library_members(id) ON DELETE SET NULL,
    book_id UUID REFERENCES public.library_books(id) ON DELETE SET NULL,
    copy_id UUID REFERENCES public.library_book_copies(id) ON DELETE SET NULL,
    borrow_id UUID REFERENCES public.library_borrows(id) ON DELETE SET NULL,
    performed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_circ_activities_school ON public.library_circulation_activities(school_id, created_at DESC);

-- 3. CREATE FINE PAYMENTS TABLE
CREATE TABLE IF NOT EXISTS public.library_fine_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    fine_id UUID REFERENCES public.library_fines(id) ON DELETE SET NULL,
    borrow_id UUID REFERENCES public.library_borrows(id) ON DELETE SET NULL,
    member_id UUID NOT NULL REFERENCES public.library_members(id) ON DELETE CASCADE,
    amount_paid NUMERIC(10,2) NOT NULL,
    payment_method VARCHAR(50) DEFAULT 'CASH',
    transaction_reference VARCHAR(100),
    receipt_number VARCHAR(50),
    notes TEXT,
    collected_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fine_payments_school ON public.library_fine_payments(school_id, member_id);

-- 4. ENHANCE LIBRARY_REQUESTS TABLE
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'member_id') THEN
        ALTER TABLE public.library_requests ADD COLUMN member_id UUID REFERENCES public.library_members(id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'book_id') THEN
        ALTER TABLE public.library_requests ADD COLUMN book_id UUID REFERENCES public.library_books(id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'copy_id') THEN
        ALTER TABLE public.library_requests ADD COLUMN copy_id UUID REFERENCES public.library_book_copies(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'request_type') THEN
        ALTER TABLE public.library_requests ADD COLUMN request_type VARCHAR(30) DEFAULT 'ISSUE';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'priority') THEN
        ALTER TABLE public.library_requests ADD COLUMN priority VARCHAR(20) DEFAULT 'NORMAL';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'requested_due_date') THEN
        ALTER TABLE public.library_requests ADD COLUMN requested_due_date DATE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'rejection_reason') THEN
        ALTER TABLE public.library_requests ADD COLUMN rejection_reason TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'processed_by') THEN
        ALTER TABLE public.library_requests ADD COLUMN processed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'processed_at') THEN
        ALTER TABLE public.library_requests ADD COLUMN processed_at TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'updated_at') THEN
        ALTER TABLE public.library_requests ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    END IF;
END $$;

-- 5. POPULATE TRANSACTION CODES FOR EXISTING BORROWS
UPDATE public.library_borrows
SET transaction_code = 'TXN-' || LPAD(SUBSTRING(id::text FROM 1 FOR 4), 4, '0')
WHERE transaction_code IS NULL;

-- Create Indexes
CREATE INDEX IF NOT EXISTS idx_library_borrows_school_status ON public.library_borrows(school_id, status);
CREATE INDEX IF NOT EXISTS idx_library_borrows_member ON public.library_borrows(school_id, member_id);
CREATE INDEX IF NOT EXISTS idx_library_borrows_due_date ON public.library_borrows(school_id, due_date);
CREATE INDEX IF NOT EXISTS idx_library_borrows_txn_code ON public.library_borrows(school_id, transaction_code);

-- ============================================================================
-- STORED FUNCTION 1: Aggregated Circulation Stats
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_get_circulation_stats(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_transactions INT := 0;
    v_issued_today INT := 0;
    v_issued_yesterday INT := 0;
    v_issued_delta NUMERIC := 0.0;
    v_returned_today INT := 0;
    v_returned_yesterday INT := 0;
    v_returned_delta NUMERIC := 0.0;
    v_currently_issued INT := 0;
    v_overdue_count INT := 0;
    v_pending_requests INT := 0;
    v_pending_renewals INT := 0;
    v_total_fines NUMERIC := 0.0;
BEGIN
    -- 0. Total Issue / Return Transactions
    SELECT COALESCE(COUNT(*), 0) INTO v_total_transactions
    FROM public.library_borrows
    WHERE school_id = p_school_id;

    -- 1. Issued today vs yesterday
    SELECT COALESCE(COUNT(*), 0) INTO v_issued_today
    FROM public.library_borrows
    WHERE school_id = p_school_id AND issue_date = CURRENT_DATE;

    SELECT COALESCE(COUNT(*), 0) INTO v_issued_yesterday
    FROM public.library_borrows
    WHERE school_id = p_school_id AND issue_date = (CURRENT_DATE - INTERVAL '1 day')::date;

    IF v_issued_yesterday > 0 THEN
        v_issued_delta := ROUND(((v_issued_today - v_issued_yesterday)::numeric / v_issued_yesterday::numeric) * 100, 1);
    ELSE
        v_issued_delta := CASE WHEN v_issued_today > 0 THEN 100.0 ELSE 0.0 END;
    END IF;

    -- 2. Returned today vs yesterday
    SELECT COALESCE(COUNT(*), 0) INTO v_returned_today
    FROM public.library_borrows
    WHERE school_id = p_school_id AND return_date = CURRENT_DATE AND (status = 'RETURNED' OR is_returned = TRUE);

    SELECT COALESCE(COUNT(*), 0) INTO v_returned_yesterday
    FROM public.library_borrows
    WHERE school_id = p_school_id AND return_date = (CURRENT_DATE - INTERVAL '1 day')::date AND (status = 'RETURNED' OR is_returned = TRUE);

    IF v_returned_yesterday > 0 THEN
        v_returned_delta := ROUND(((v_returned_today - v_returned_yesterday)::numeric / v_returned_yesterday::numeric) * 100, 1);
    ELSE
        v_returned_delta := CASE WHEN v_returned_today > 0 THEN 100.0 ELSE 0.0 END;
    END IF;

    -- 3. Currently issued (Active non-overdue loans matching the Issued subtab)
    SELECT COALESCE(COUNT(*), 0) INTO v_currently_issued
    FROM public.library_borrows
    WHERE school_id = p_school_id 
      AND (status = 'ISSUED' OR (status IS NULL AND is_returned IS NOT TRUE))
      AND (due_date >= CURRENT_DATE OR due_date IS NULL)
      AND is_returned IS NOT TRUE;

    -- 4. Overdue count
    SELECT COALESCE(COUNT(*), 0) INTO v_overdue_count
    FROM public.library_borrows
    WHERE school_id = p_school_id 
      AND (status = 'OVERDUE' OR (status IN ('ISSUED', 'RENEWED') AND due_date < CURRENT_DATE))
      AND is_returned IS NOT TRUE;

    -- 5. Pending requests (All pending library requests)
    SELECT COALESCE(COUNT(*), 0) INTO v_pending_requests
    FROM public.library_requests
    WHERE school_id = p_school_id AND UPPER(status) IN ('NEW', 'PENDING');

    -- 6. Pending renewals
    SELECT COALESCE(COUNT(*), 0) INTO v_pending_renewals
    FROM public.library_requests
    WHERE school_id = p_school_id AND UPPER(status) IN ('NEW', 'PENDING') AND UPPER(request_type) LIKE '%RENEW%';

    -- 7. Total Outstanding Fines
    SELECT COALESCE(SUM(outstanding_amount), 0.0) INTO v_total_fines
    FROM public.library_fines
    WHERE school_id = p_school_id AND status IN ('UNPAID', 'PARTIALLY_PAID');

    RETURN jsonb_build_object(
        'total_transactions', v_total_transactions,
        'books_issued_today', v_issued_today,
        'issued_delta_pct', v_issued_delta,
        'books_returned_today', v_returned_today,
        'returned_delta_pct', v_returned_delta,
        'currently_issued', v_currently_issued,
        'overdue_books', v_overdue_count,
        'pending_requests', v_pending_requests,
        'pending_renewals', v_pending_renewals,
        'total_fines', v_total_fines
    );

END;
$$;


-- ============================================================================
-- STORED FUNCTION 2: Filter Options for Circulation
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_get_circulation_filter_options(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN jsonb_build_object(
        'transaction_types', jsonb_build_array('All', 'Manual Issue', 'Request Approved', 'Manual Return', 'Renewed', 'Lost / Damaged'),
        'statuses', jsonb_build_array('All', 'Issued', 'Returned', 'Overdue', 'Renewed', 'Pending', 'Lost', 'Damaged'),
        'search_in_fields', jsonb_build_array('All Transactions', 'Member Name', 'Member Code', 'Book Title', 'ISBN', 'Barcode', 'Transaction ID')
    );
END;
$$;


-- ============================================================================
-- STORED FUNCTION 3: List Circulation Transactions with Dynamic Filters & Pagination
-- ============================================================================
DROP FUNCTION IF EXISTS public.fn_library_list_transactions(uuid, text, text, text, text, text, date, date, integer, integer, text, text);
DROP FUNCTION IF EXISTS public.fn_library_list_transactions(uuid, text, text, text, text, text, date, date, integer, integer, text, text, text, text, text);

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
    p_date_field TEXT DEFAULT 'issue_date'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_where TEXT := format('br.school_id = %L', p_school_id);
    v_offset INT;
    v_total INT;
    v_results JSONB;
    v_counts JSONB;
    v_date_col TEXT := 'br.issue_date';
BEGIN
    v_offset := GREATEST(0, (p_page - 1) * p_page_size);

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
            -- Global search across all fields
            v_where := v_where || format(' AND (br.transaction_code ILIKE %L OR p.full_name ILIKE %L OR m.member_code ILIKE %L OR b.title ILIKE %L OR b.isbn13 ILIKE %L OR b.isbn10 ILIKE %L OR c.barcode ILIKE %L OR c.accession_number ILIKE %L OR p.phone ILIKE %L)',
                '%' || trim(p_search) || '%', '%' || trim(p_search) || '%', '%' || trim(p_search) || '%', '%' || trim(p_search) || '%', '%' || trim(p_search) || '%', '%' || trim(p_search) || '%', '%' || trim(p_search) || '%', '%' || trim(p_search) || '%', '%' || trim(p_search) || '%'
            );
        END IF;
    END IF;

    -- 2. Subtab Filter (All, Issued, Returned, Overdue, Requests, Renewed, Lost / Damaged, Issued Today, Returned Today, Fines)
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
            v_where := v_where || ' AND (br.status = ''OVERDUE'' OR (br.status IN (''ISSUED'', ''RENEWED'') AND br.due_date < CURRENT_DATE))';
        ELSIF p_subtab = 'RENEWED' THEN
            v_where := v_where || ' AND br.status = ''RENEWED''';
        ELSIF p_subtab = 'LOST_DAMAGED' OR p_subtab = 'LOST / DAMAGED' THEN
            v_where := v_where || ' AND br.status IN (''LOST'', ''DAMAGED'')';
        ELSIF p_subtab = 'REQUESTS' THEN
            v_where := v_where || ' AND br.status = ''PENDING''';
        ELSIF p_subtab = 'FINES' THEN
            v_where := v_where || ' AND COALESCE(br.fine_amount, 0) > 0';
        END IF;
    END IF;


    -- 3. Explicit Status Filter
    IF p_status IS NOT NULL AND p_status != 'ALL' THEN
        IF p_status = 'OVERDUE' THEN
            v_where := v_where || ' AND (br.status = ''OVERDUE'' OR (br.status IN (''ISSUED'', ''RENEWED'') AND br.due_date < CURRENT_DATE))';
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
        v_where := v_where || format(' AND p.role ILIKE %L', p_member_role);
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
             JOIN public.library_members m ON br.member_id = m.id 
             JOIN public.profiles p ON m.profile_id = p.id 
             JOIN public.library_books b ON br.book_id = b.id 
             LEFT JOIN public.library_book_copies c ON br.copy_id = c.id 
             WHERE ' || v_where INTO v_total;

    -- Execute Query for Paginated Items
    EXECUTE format('
        SELECT COALESCE(jsonb_agg(item), ''[]''::jsonb) FROM (
            SELECT jsonb_build_object(
                ''id'', br.id,
                ''transaction_code'', COALESCE(br.transaction_code, ''TXN-'' || LPAD(SUBSTRING(br.id::text FROM 1 FOR 4), 4, ''0'')),
                ''member_id'', br.member_id,
                ''member_name'', p.full_name,
                ''member_code'', m.member_code,
                ''member_type'', m.membership_type,
                ''member_role'', p.role,
                ''member_class'', COALESCE(p.class, p.department, ''N/A''),
                ''member_avatar'', p.avatar_url,
                ''member_phone'', p.phone,
                ''member_email'', p.email,
                ''book_id'', br.book_id,
                ''book_title'', b.title,
                ''book_isbn'', COALESCE(b.isbn13, b.isbn10, b.isbn, ''N/A''),
                ''book_cover_url'', b.cover_url,
                ''book_author'', b.author,
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
            JOIN public.library_members m ON br.member_id = m.id
            JOIN public.profiles p ON m.profile_id = p.id
            JOIN public.library_books b ON br.book_id = b.id
            LEFT JOIN public.library_book_copies c ON br.copy_id = c.id
            WHERE %s
            ORDER BY br.created_at DESC
            LIMIT %s OFFSET %s
        ) sub
    ', v_where, p_page_size, v_offset) INTO v_results;

    -- Subtab counts for badges
    SELECT jsonb_build_object(
        'all', (SELECT COUNT(*) FROM public.library_borrows WHERE school_id = p_school_id),
        'issued', (SELECT COUNT(*) FROM public.library_borrows WHERE school_id = p_school_id AND status = 'ISSUED' AND (due_date >= CURRENT_DATE OR due_date IS NULL)),
        'returned', (SELECT COUNT(*) FROM public.library_borrows WHERE school_id = p_school_id AND (status = 'RETURNED' OR is_returned = TRUE)),
        'overdue', (SELECT COUNT(*) FROM public.library_borrows WHERE school_id = p_school_id AND (status = 'OVERDUE' OR (status IN ('ISSUED', 'RENEWED') AND due_date < CURRENT_DATE))),
        'renewed', (SELECT COUNT(*) FROM public.library_borrows WHERE school_id = p_school_id AND status = 'RENEWED'),
        'requests', (SELECT COUNT(*) FROM public.library_requests WHERE school_id = p_school_id AND status = 'PENDING'),
        'lost_damaged', (SELECT COUNT(*) FROM public.library_borrows WHERE school_id = p_school_id AND status IN ('LOST', 'DAMAGED'))
    ) INTO v_counts;

    RETURN jsonb_build_object(
        'items', COALESCE(v_results, '[]'::jsonb),
        'total', v_total,
        'page', p_page,
        'page_size', p_page_size,
        'total_pages', CEIL(v_total::numeric / GREATEST(1, p_page_size)::numeric),
        'counts', v_counts
    );
END;
$$;


-- ============================================================================
-- STORED FUNCTION 4: Get Full Transaction Detail & Timeline
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_get_transaction_detail(
    p_school_id UUID,
    p_transaction_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'id', br.id,
        'transaction_code', COALESCE(br.transaction_code, 'TXN-' || SUBSTRING(br.id::text FROM 1 FOR 6)),
        'issue_date', br.issue_date,
        'borrowed_at', br.borrowed_at,
        'due_date', br.due_date,
        'due_at', br.due_at,
        'return_date', br.return_date,
        'returned_at', br.returned_at,
        'status', CASE 
            WHEN (br.status = 'ISSUED' OR br.status = 'RENEWED' OR br.status IS NULL) AND br.due_date < CURRENT_DATE AND (br.is_returned IS NOT TRUE AND br.return_date IS NULL) THEN 'OVERDUE'
            ELSE COALESCE(br.status, CASE WHEN br.is_returned THEN 'RETURNED' ELSE 'ISSUED' END)
        END,
        'days_overdue', GREATEST(0, CASE 
            WHEN (br.is_returned IS TRUE OR br.return_date IS NOT NULL) THEN 0
            WHEN br.due_date < CURRENT_DATE THEN (CURRENT_DATE - br.due_date)
            ELSE 0
        END),
        'fine_amount', COALESCE(br.fine_amount, 0.0),
        'fine_status', COALESCE(br.fine_status, 'NONE'),
        'damage_charge', COALESCE(br.damage_charge, 0.0),
        'lost_charge', COALESCE(br.lost_charge, 0.0),
        'transaction_type', COALESCE(br.transaction_type, 'MANUAL_ISSUE'),
        'renewals_used', COALESCE(br.renewals_used, 0),
        'max_renewals', COALESCE(br.max_renewals, 2),
        'return_condition', br.return_condition,
        'issued_by_name', (SELECT full_name FROM public.profiles WHERE id = br.issued_by),
        'received_by_name', (SELECT full_name FROM public.profiles WHERE id = br.received_by),
        'notes', br.notes,
        'created_at', br.created_at,
        'book', jsonb_build_object(
            'id', b.id,
            'title', b.title,
            'isbn', COALESCE(b.isbn13, b.isbn10, b.isbn, 'N/A'),
            'cover_url', b.cover_url,
            'author', b.author,
            'category', COALESCE(b.category_name, b.category, 'General'),
            'publisher', b.publisher
        ),
        'member', jsonb_build_object(
            'id', m.id,
            'name', p.full_name,
            'member_code', m.member_code,
            'type', m.membership_type,
            'role', p.role,
            'class', COALESCE(p.class, p.department, 'N/A'),
            'avatar_url', p.avatar_url,
            'phone', p.phone,
            'email', p.email,
            'borrowing_limit', m.borrowing_limit,
            'currently_borrowed', m.current_borrowed_count
        ),
        'copy', jsonb_build_object(
            'id', c.id,
            'accession_number', COALESCE(c.accession_number, 'N/A'),
            'barcode', COALESCE(c.barcode, 'N/A'),
            'condition', COALESCE(c.condition, 'GOOD'),
            'shelf_location', COALESCE(c.location, b.shelf_location, 'N/A'),
            'rack', c.rack,
            'shelf', c.shelf
        ),
        'fine', jsonb_build_object(
            'id', f.id,
            'amount', COALESCE(f.amount, br.fine_amount, 0.0),
            'outstanding_amount', COALESCE(f.outstanding_amount, br.fine_amount, 0.0),
            'status', COALESCE(f.status, br.fine_status, 'NONE')
        ),
        'timeline', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'action', a.title,
                    'description', a.description,
                    'created_at', a.created_at,
                    'actor_name', (SELECT full_name FROM public.profiles WHERE id = a.performed_by)
                ) ORDER BY a.created_at DESC
            )
            FROM public.library_circulation_activities a
            WHERE a.borrow_id = br.id
        ), '[]'::jsonb)
    ) INTO v_result
    FROM public.library_borrows br
    JOIN public.library_members m ON br.member_id = m.id
    JOIN public.profiles p ON m.profile_id = p.id
    JOIN public.library_books b ON br.book_id = b.id
    LEFT JOIN public.library_book_copies c ON br.copy_id = c.id
    LEFT JOIN public.library_fines f ON f.borrow_id = br.id
    WHERE br.school_id = p_school_id AND br.id = p_transaction_id;

    RETURN v_result;
END;
$$;


-- ============================================================================
-- STORED FUNCTION 5: Atomic Multi-Book Issue
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_issue_books(
    p_school_id UUID,
    p_member_id UUID,
    p_items JSONB,
    p_issued_by UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_member RECORD;
    v_profile RECORD;
    v_item JSONB;
    v_book_id UUID;
    v_copy_id UUID;
    v_due_date DATE;
    v_copy RECORD;
    v_book RECORD;
    v_txn_code VARCHAR(50);
    v_new_borrow_id UUID;
    v_issued_items JSONB := '[]'::jsonb;
    v_item_count INT;
    v_seq_num INT;
BEGIN
    -- 1. Lock and validate member eligibility
    SELECT * INTO v_member FROM public.library_members 
    WHERE id = p_member_id AND school_id = p_school_id AND archived_at IS NULL
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Library member not found or archived.';
    END IF;

    IF v_member.status != 'ACTIVE' THEN
        RAISE EXCEPTION 'Member status is % (must be ACTIVE to issue books).', v_member.status;
    END IF;

    IF v_member.membership_expiry_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Membership has expired on %. Please renew membership first.', v_member.membership_expiry_date;
    END IF;

    v_item_count := jsonb_array_length(p_items);
    IF v_item_count = 0 THEN
        RAISE EXCEPTION 'No books specified for issue.';
    END IF;

    IF (v_member.current_borrowed_count + v_item_count) > v_member.borrowing_limit THEN
        RAISE EXCEPTION 'Member borrowing limit exceeded (Allowed: %, Currently Borrowed: %, Requesting: %).', 
            v_member.borrowing_limit, v_member.current_borrowed_count, v_item_count;
    END IF;

    -- Check for overdue block
    IF EXISTS (
        SELECT 1 FROM public.library_borrows 
        WHERE member_id = p_member_id AND school_id = p_school_id 
          AND status IN ('ISSUED', 'RENEWED', 'OVERDUE') AND is_returned IS NOT TRUE 
          AND due_date < CURRENT_DATE
    ) THEN
        RAISE EXCEPTION 'Member has overdue books. Overdue items must be returned before new issues.';
    END IF;

    SELECT full_name INTO v_profile FROM public.profiles WHERE id = v_member.profile_id;

    -- 2. Process each book copy with row lock
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_book_id := (v_item->>'book_id')::uuid;
        v_copy_id := NULL;
        IF (v_item->>'copy_id') IS NOT NULL AND (v_item->>'copy_id') != '' THEN
            v_copy_id := (v_item->>'copy_id')::uuid;
        END IF;

        IF (v_item->>'due_date') IS NOT NULL AND (v_item->>'due_date') != '' THEN
            v_due_date := (v_item->>'due_date')::date;
        ELSE
            v_due_date := (CURRENT_DATE + (COALESCE(v_member.max_issue_duration_days, 14) || ' days')::interval)::date;
        END IF;

        -- If specific copy requested, lock it
        IF v_copy_id IS NOT NULL THEN
            SELECT * INTO v_copy FROM public.library_book_copies 
            WHERE id = v_copy_id AND school_id = p_school_id AND archived_at IS NULL
            FOR UPDATE;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Selected book copy was not found.';
            END IF;

            IF v_copy.status != 'AVAILABLE' THEN
                RAISE EXCEPTION 'Copy % (%) is not available (Current status: %).', v_copy.accession_number, v_copy.barcode, v_copy.status;
            END IF;
        ELSE
            -- Select any available copy of the book
            SELECT * INTO v_copy FROM public.library_book_copies 
            WHERE book_id = v_book_id AND school_id = p_school_id AND status = 'AVAILABLE' AND archived_at IS NULL
            LIMIT 1
            FOR UPDATE SKIP LOCKED;

            IF NOT FOUND THEN
                SELECT title INTO v_book FROM public.library_books WHERE id = v_book_id;
                RAISE EXCEPTION 'No available physical copy for book "%".', COALESCE(v_book.title, 'Unknown');
            END IF;
            v_copy_id := v_copy.id;
        END IF;

        -- Generate unique TXN code safely
        v_txn_code := 'TXN-' || LPAD(COALESCE((SELECT COUNT(*) + 1 FROM public.library_borrows WHERE school_id = p_school_id), 1)::text, 5, '0');


        -- Create Borrow Record
        INSERT INTO public.library_borrows (
            school_id, book_id, copy_id, member_id, transaction_code,
            issue_date, due_date, due_at, borrowed_at, status,
            transaction_type, renewals_used, max_renewals,
            fine_amount, fine_status, issued_by, notes, is_returned, created_at, updated_at
        ) VALUES (
            p_school_id, v_book_id, v_copy_id, p_member_id, v_txn_code,
            CURRENT_DATE, v_due_date, (v_due_date || ' 23:59:59')::timestamptz, NOW(), 'ISSUED',
            'MANUAL_ISSUE', 0, COALESCE(v_member.max_renewals, 2),
            0.00, 'NONE', p_issued_by, p_notes, FALSE, NOW(), NOW()
        ) RETURNING id INTO v_new_borrow_id;

        -- Update Copy Status
        UPDATE public.library_book_copies
        SET status = 'ISSUED',
            current_borrower_id = v_member.profile_id,
            borrowed_at = NOW(),
            due_date = (v_due_date || ' 23:59:59')::timestamptz,
            last_issued_date = NOW(),
            updated_at = NOW()
        WHERE id = v_copy_id;

        -- Update Book available count
        UPDATE public.library_books
        SET available_copies = GREATEST(0, available_copies - 1),
            issued_copies = issued_copies + 1,
            updated_at = NOW()
        WHERE id = v_book_id;

        -- Log Activity
        SELECT title INTO v_book FROM public.library_books WHERE id = v_book_id;
        INSERT INTO public.library_circulation_activities (
            school_id, activity_type, title, description,
            member_id, book_id, copy_id, borrow_id, performed_by, created_at
        ) VALUES (
            p_school_id, 'ISSUE',
            'Book issued to ' || COALESCE(v_profile.full_name, v_member.member_code),
            'Issued "' || COALESCE(v_book.title, 'Book') || '" (Due: ' || to_char(v_due_date, 'DD Mon YYYY') || ')',
            p_member_id, v_book_id, v_copy_id, v_new_borrow_id, p_issued_by, NOW()
        );

        v_issued_items := v_issued_items || jsonb_build_object(
            'borrow_id', v_new_borrow_id,
            'transaction_code', v_txn_code,
            'book_id', v_book_id,
            'book_title', v_book.title,
            'copy_id', v_copy_id,
            'copy_barcode', v_copy.barcode,
            'due_date', v_due_date
        );
    END LOOP;

    -- Update Member current borrowed count & total borrowed
    UPDATE public.library_members
    SET current_borrowed_count = current_borrowed_count + v_item_count,
        total_borrowed_count = total_borrowed_count + v_item_count,
        updated_at = NOW()
    WHERE id = p_member_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', format('Successfully issued %s book(s) to %s.', v_item_count, v_profile.full_name),
        'items', v_issued_items,
        'borrow_ids', (SELECT jsonb_agg((x->>'borrow_id')::uuid) FROM jsonb_array_elements(v_issued_items) x),
        'issued_count', v_item_count
    );
END;
$$;



-- ============================================================================
-- STORED FUNCTION 6: Atomic Return Books with Fine & Condition Handling
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
    v_copy RECORD;
    v_member RECORD;
    v_book RECORD;
    v_profile RECORD;
    v_days_overdue INT;
    v_fine_rate NUMERIC := 10.00; -- 10 INR per day
    v_calculated_fine NUMERIC := 0.00;
    v_damage_charge NUMERIC := 0.00;
    v_lost_charge NUMERIC := 0.00;
    v_total_item_fine NUMERIC := 0.00;
    v_fine_id UUID;
    v_receipt_no VARCHAR(50);
    v_returned_count INT := 0;
    v_processed_items JSONB := '[]'::jsonb;
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
                WHEN v_condition = 'MAJOR_DAMAGE' THEN 'DAMAGED' 
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
                    WHEN v_condition = 'MAJOR_DAMAGE' THEN 'DAMAGED'
                    ELSE 'AVAILABLE'
                END,
                condition = CASE 
                    WHEN v_condition IN ('MINOR_DAMAGE', 'MAJOR_DAMAGE') THEN 'DAMAGED'
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
                WHEN v_condition IN ('LOST', 'MAJOR_DAMAGE') THEN available_copies
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
            'Returned "' || COALESCE(v_book.title, 'Book') || '" (Fine: ₹' || v_total_item_fine || ')',
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
-- STORED FUNCTION 7: Atomic Book Loan Renewal
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_renew_book(
    p_school_id UUID,
    p_borrow_id UUID,
    p_renewed_by UUID,
    p_new_due_date DATE DEFAULT NULL,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_borrow RECORD;
    v_member RECORD;
    v_book RECORD;
    v_profile RECORD;
    v_new_due DATE;
    v_extension_days INT;
BEGIN
    SELECT * INTO v_borrow FROM public.library_borrows 
    WHERE id = p_borrow_id AND school_id = p_school_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transaction record not found.';
    END IF;

    IF v_borrow.is_returned IS TRUE OR v_borrow.status = 'RETURNED' THEN
        RAISE EXCEPTION 'Cannot renew a book that has already been returned.';
    END IF;

    SELECT * INTO v_member FROM public.library_members 
    WHERE id = v_borrow.member_id AND school_id = p_school_id;

    IF v_borrow.renewals_used >= COALESCE(v_borrow.max_renewals, v_member.max_renewals, 2) THEN
        RAISE EXCEPTION 'Maximum renewal limit reached (%/% renewals used).', v_borrow.renewals_used, COALESCE(v_borrow.max_renewals, 2);
    END IF;

    IF p_new_due_date IS NOT NULL THEN
        v_new_due := p_new_due_date;
    ELSE
        v_extension_days := COALESCE(v_member.max_issue_duration_days, 14);
        v_new_due := (GREATEST(CURRENT_DATE, v_borrow.due_date) + (v_extension_days || ' days')::interval)::date;
    END IF;

    -- Update Borrow Record
    UPDATE public.library_borrows
    SET due_date = v_new_due,
        due_at = (v_new_due || ' 23:59:59')::timestamptz,
        renewals_used = renewals_used + 1,
        last_renewed_at = NOW(),
        last_renewed_by = p_renewed_by,
        status = 'RENEWED',
        notes = CASE WHEN p_reason IS NOT NULL THEN COALESCE(notes || E'\n', '') || 'Renewed: ' || p_reason ELSE notes END,
        updated_at = NOW()
    WHERE id = p_borrow_id;

    -- Update Copy due date
    IF v_borrow.copy_id IS NOT NULL THEN
        UPDATE public.library_book_copies
        SET due_date = (v_new_due || ' 23:59:59')::timestamptz,
            updated_at = NOW()
        WHERE id = v_borrow.copy_id;
    END IF;

    -- Log Activity
    SELECT full_name INTO v_profile FROM public.profiles WHERE id = v_member.profile_id;
    SELECT title INTO v_book FROM public.library_books WHERE id = v_borrow.book_id;

    INSERT INTO public.library_circulation_activities (
        school_id, activity_type, title, description,
        member_id, book_id, copy_id, borrow_id, performed_by, created_at
    ) VALUES (
        p_school_id, 'RENEW',
        'Book renewed for ' || COALESCE(v_profile.full_name, 'Member'),
        'Renewed "' || COALESCE(v_book.title, 'Book') || '" until ' || to_char(v_new_due, 'DD Mon YYYY'),
        v_borrow.member_id, v_borrow.book_id, v_borrow.copy_id, p_borrow_id, p_renewed_by, NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', format('Book renewed until %s (%s renewals used).', to_char(v_new_due, 'DD Mon YYYY'), v_borrow.renewals_used + 1),
        'new_due_date', v_new_due,
        'renewals_used', v_borrow.renewals_used + 1
    );
END;
$$;


-- ============================================================================
-- STORED FUNCTION 8: Real-Time Circulation Activity Feed
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_get_circulation_activity(
    p_school_id UUID,
    p_limit INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_results JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(act), '[]'::jsonb) INTO v_results FROM (
        SELECT jsonb_build_object(
            'id', a.id,
            'activity_type', a.activity_type,
            'title', a.title,
            'description', a.description,
            'member_id', a.member_id,
            'member_name', p.full_name,
            'book_id', a.book_id,
            'book_title', b.title,
            'created_at', a.created_at,
            'time_ago', to_char(a.created_at, 'HH12:MI AM')
        ) AS act
        FROM public.library_circulation_activities a
        LEFT JOIN public.library_members m ON a.member_id = m.id
        LEFT JOIN public.profiles p ON m.profile_id = p.id
        LEFT JOIN public.library_books b ON a.book_id = b.id
        WHERE a.school_id = p_school_id
        ORDER BY a.created_at DESC
        LIMIT p_limit
    ) sub;

    RETURN v_results;
END;
$$;


-- ============================================================================
-- STORED FUNCTION 9: Overdue Brackets Summary Breakdown
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_get_overdue_summary(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_1_3_count INT;
    v_1_3_fines NUMERIC;
    v_4_7_count INT;
    v_4_7_fines NUMERIC;
    v_8_15_count INT;
    v_8_15_fines NUMERIC;
    v_15_plus_count INT;
    v_15_plus_fines NUMERIC;
BEGIN
    -- 1-3 Days Overdue
    SELECT COALESCE(COUNT(*), 0), COALESCE(SUM((CURRENT_DATE - due_date) * 10), 0.0)
    INTO v_1_3_count, v_1_3_fines
    FROM public.library_borrows
    WHERE school_id = p_school_id AND is_returned IS NOT TRUE
      AND status IN ('ISSUED', 'RENEWED', 'OVERDUE')
      AND (CURRENT_DATE - due_date) BETWEEN 1 AND 3;

    -- 4-7 Days Overdue
    SELECT COALESCE(COUNT(*), 0), COALESCE(SUM((CURRENT_DATE - due_date) * 10), 0.0)
    INTO v_4_7_count, v_4_7_fines
    FROM public.library_borrows
    WHERE school_id = p_school_id AND is_returned IS NOT TRUE
      AND status IN ('ISSUED', 'RENEWED', 'OVERDUE')
      AND (CURRENT_DATE - due_date) BETWEEN 4 AND 7;

    -- 8-15 Days Overdue
    SELECT COALESCE(COUNT(*), 0), COALESCE(SUM((CURRENT_DATE - due_date) * 10), 0.0)
    INTO v_8_15_count, v_8_15_fines
    FROM public.library_borrows
    WHERE school_id = p_school_id AND is_returned IS NOT TRUE
      AND status IN ('ISSUED', 'RENEWED', 'OVERDUE')
      AND (CURRENT_DATE - due_date) BETWEEN 8 AND 15;

    -- 15+ Days Overdue
    SELECT COALESCE(COUNT(*), 0), COALESCE(SUM((CURRENT_DATE - due_date) * 10), 0.0)
    INTO v_15_plus_count, v_15_plus_fines
    FROM public.library_borrows
    WHERE school_id = p_school_id AND is_returned IS NOT TRUE
      AND status IN ('ISSUED', 'RENEWED', 'OVERDUE')
      AND (CURRENT_DATE - due_date) > 15;

    RETURN jsonb_build_array(
        jsonb_build_object('bracket', '1-3 Days', 'min_days', 1, 'max_days', 3, 'books_count', v_1_3_count, 'estimated_fines', v_1_3_fines),
        jsonb_build_object('bracket', '4-7 Days', 'min_days', 4, 'max_days', 7, 'books_count', v_4_7_count, 'estimated_fines', v_4_7_fines),
        jsonb_build_object('bracket', '8-15 Days', 'min_days', 8, 'max_days', 15, 'books_count', v_8_15_count, 'estimated_fines', v_8_15_fines),
        jsonb_build_object('bracket', '15+ Days', 'min_days', 16, 'max_days', 9999, 'books_count', v_15_plus_count, 'estimated_fines', v_15_plus_fines)
    );

END;
$$;


-- ============================================================================
-- STORED FUNCTION 10: Barcode / QR Entity Scan Lookup
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_scan_lookup(
    p_school_id UUID,
    p_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean TEXT := trim(p_code);
    v_copy RECORD;
    v_book RECORD;
    v_member RECORD;
    v_profile RECORD;
    v_active_borrow RECORD;
BEGIN
    -- 1. Check if it's a Book Copy (Barcode or Accession Number)
    SELECT c.*, b.title, b.author, b.isbn13, b.isbn10, b.isbn, b.cover_url, b.category_name, b.shelf_location
    INTO v_copy
    FROM public.library_book_copies c
    JOIN public.library_books b ON c.book_id = b.id
    WHERE c.school_id = p_school_id AND (c.barcode ILIKE v_clean OR c.accession_number ILIKE v_clean)
    LIMIT 1;

    IF FOUND THEN
        -- Check if currently issued
        SELECT br.*, p.full_name AS member_name, m.member_code
        INTO v_active_borrow
        FROM public.library_borrows br
        JOIN public.library_members m ON br.member_id = m.id
        JOIN public.profiles p ON m.profile_id = p.id
        WHERE br.copy_id = v_copy.id AND br.is_returned IS NOT TRUE
        LIMIT 1;

        RETURN jsonb_build_object(
            'entity_type', 'BOOK_COPY',
            'id', v_copy.id,
            'book_id', v_copy.book_id,
            'title', v_copy.title,
            'author', v_copy.author,
            'isbn', COALESCE(v_copy.isbn13, v_copy.isbn10, v_copy.isbn),
            'cover_url', v_copy.cover_url,
            'barcode', v_copy.barcode,
            'accession_number', v_copy.accession_number,
            'status', v_copy.status,
            'condition', v_copy.condition,
            'location', COALESCE(v_copy.location, v_copy.shelf_location, 'N/A'),
            'rack', v_copy.rack,
            'shelf', v_copy.shelf,
            'active_borrow', CASE WHEN v_active_borrow.id IS NOT NULL THEN jsonb_build_object(
                'borrow_id', v_active_borrow.id,
                'transaction_code', v_active_borrow.transaction_code,
                'member_id', v_active_borrow.member_id,
                'member_name', v_active_borrow.member_name,
                'member_code', v_active_borrow.member_code,
                'issue_date', v_active_borrow.issue_date,
                'due_date', v_active_borrow.due_date,
                'days_overdue', GREATEST(0, CURRENT_DATE - v_active_borrow.due_date)
            ) ELSE NULL END
        );
    END IF;

    -- 2. Check if it's a Library Member Card (Member Code, Phone, or Admission No)
    SELECT m.*, p.full_name, p.role, COALESCE(p.class, p.department, 'N/A') AS class_or_dept, p.phone, p.email, p.avatar_url
    INTO v_member
    FROM public.library_members m
    JOIN public.profiles p ON m.profile_id = p.id
    WHERE m.school_id = p_school_id AND m.archived_at IS NULL
      AND (m.member_code ILIKE v_clean OR p.phone ILIKE v_clean OR p.admission_number ILIKE v_clean OR p.employee_id ILIKE v_clean)
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'entity_type', 'MEMBER',
            'id', v_member.id,
            'member_code', v_member.member_code,
            'full_name', v_member.full_name,
            'role', v_member.role,
            'membership_type', v_member.membership_type,
            'class_or_dept', v_member.class_or_dept,
            'phone', v_member.phone,
            'email', v_member.email,
            'avatar_url', v_member.avatar_url,
            'borrowing_limit', v_member.borrowing_limit,
            'current_borrowed_count', v_member.current_borrowed_count,
            'outstanding_fine', v_member.outstanding_fine,
            'status', v_member.status,
            'membership_expiry_date', v_member.membership_expiry_date,
            'is_eligible', (v_member.status = 'ACTIVE' AND v_member.membership_expiry_date >= CURRENT_DATE AND v_member.current_borrowed_count < v_member.borrowing_limit)
        );
    END IF;

    -- 3. Check if it's an ISBN of a Book
    SELECT b.* INTO v_book FROM public.library_books b
    WHERE b.school_id = p_school_id AND (b.isbn13 ILIKE v_clean OR b.isbn10 ILIKE v_clean OR b.isbn ILIKE v_clean)
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'entity_type', 'BOOK_TITLE',
            'id', v_book.id,
            'title', v_book.title,
            'author', v_book.author,
            'isbn', COALESCE(v_book.isbn13, v_book.isbn10, v_book.isbn),
            'cover_url', v_book.cover_url,
            'available_copies', v_book.available_copies,
            'total_copies', v_book.total_copies,
            'category', COALESCE(v_book.category_name, v_book.category)
        );
    END IF;

    RETURN NULL;
END;
$$;


-- ============================================================================
-- STORED FUNCTION 11: Collect Fine Payment with Receipt
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_collect_fine(
    p_school_id UUID,
    p_fine_id UUID,
    p_amount NUMERIC,
    p_payment_method VARCHAR(50),
    p_reference VARCHAR(100),
    p_collected_by UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_fine RECORD;
    v_receipt_no VARCHAR(50);
    v_new_paid NUMERIC;
    v_new_outstanding NUMERIC;
BEGIN
    SELECT * INTO v_fine FROM public.library_fines 
    WHERE id = p_fine_id AND school_id = p_school_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Fine record not found.';
    END IF;

    IF v_fine.status = 'PAID' OR v_fine.outstanding_amount <= 0 THEN
        RAISE EXCEPTION 'This fine has already been fully settled.';
    END IF;

    IF p_amount > v_fine.outstanding_amount THEN
        RAISE EXCEPTION 'Payment amount (₹%) exceeds outstanding balance (₹%).', p_amount, v_fine.outstanding_amount;
    END IF;

    v_new_paid := v_fine.paid_amount + p_amount;
    v_new_outstanding := v_fine.outstanding_amount - p_amount;
    v_receipt_no := 'RCP-' || LPAD((FLOOR(RANDOM() * 90000) + 10000)::text, 5, '0');

    -- Create Payment Record
    INSERT INTO public.library_fine_payments (
        school_id, fine_id, borrow_id, member_id, amount_paid,
        payment_method, transaction_reference, receipt_number, notes, collected_by, created_at
    ) VALUES (
        p_school_id, p_fine_id, v_fine.borrow_id, v_fine.member_id, p_amount,
        COALESCE(p_payment_method, 'CASH'), p_reference, v_receipt_no, p_notes, p_collected_by, NOW()
    );

    -- Update Fine Record
    UPDATE public.library_fines
    SET paid_amount = v_new_paid,
        outstanding_amount = v_new_outstanding,
        status = CASE WHEN v_new_outstanding = 0 THEN 'PAID' ELSE 'PARTIALLY_PAID' END,
        paid_at = CASE WHEN v_new_outstanding = 0 THEN NOW() ELSE paid_at END,
        updated_at = NOW()
    WHERE id = p_fine_id;

    -- Update Member Balance
    UPDATE public.library_members
    SET outstanding_fine = GREATEST(0.0, outstanding_fine - p_amount),
        total_fines_paid = total_fines_paid + p_amount,
        updated_at = NOW()
    WHERE id = v_fine.member_id;

    -- Update Borrow Fine Status
    IF v_fine.borrow_id IS NOT NULL THEN
        UPDATE public.library_borrows
        SET fine_status = CASE WHEN v_new_outstanding = 0 THEN 'PAID' ELSE 'PARTIALLY_PAID' END,
            updated_at = NOW()
        WHERE id = v_fine.borrow_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', format('Payment of ₹%s recorded successfully. Receipt #%s generated.', p_amount, v_receipt_no),
        'receipt_number', v_receipt_no,
        'remaining_outstanding', v_new_outstanding
    );
END;
$$;


-- ============================================================================
-- STORED FUNCTION 12: Fine Waiver with Audit Reason
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_waive_fine(
    p_school_id UUID,
    p_fine_id UUID,
    p_amount NUMERIC,
    p_reason TEXT,
    p_waived_by UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_fine RECORD;
    v_waive_amount NUMERIC;
    v_new_outstanding NUMERIC;
BEGIN
    SELECT * INTO v_fine FROM public.library_fines 
    WHERE id = p_fine_id AND school_id = p_school_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Fine record not found.';
    END IF;

    IF v_fine.status = 'PAID' OR v_fine.outstanding_amount <= 0 THEN
        RAISE EXCEPTION 'This fine has already been paid and cannot be waived.';
    END IF;

    v_waive_amount := LEAST(p_amount, v_fine.outstanding_amount);
    v_new_outstanding := v_fine.outstanding_amount - v_waive_amount;

    UPDATE public.library_fines
    SET waived_amount = waived_amount + v_waive_amount,
        outstanding_amount = v_new_outstanding,
        status = CASE WHEN v_new_outstanding = 0 THEN 'WAIVED' ELSE 'PARTIALLY_PAID' END,
        waived_at = NOW(),
        waived_by = p_waived_by,
        waiver_reason = p_reason,
        updated_at = NOW()
    WHERE id = p_fine_id;

    UPDATE public.library_members
    SET outstanding_fine = GREATEST(0.0, outstanding_fine - v_waive_amount),
        updated_at = NOW()
    WHERE id = v_fine.member_id;

    IF v_fine.borrow_id IS NOT NULL THEN
        UPDATE public.library_borrows
        SET fine_status = CASE WHEN v_new_outstanding = 0 THEN 'WAIVED' ELSE fine_status END,
            updated_at = NOW()
        WHERE id = v_fine.borrow_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', format('Fine waiver of ₹%s processed successfully.', v_waive_amount),
        'remaining_outstanding', v_new_outstanding
    );
END;
$$;
