-- ============================================================================
-- MIGRATION 333: Library Management Dynamic Lookups, App Roles & Live Calculations
-- Description:
--   1. fn_library_get_book_filter_options: Dynamic lookups for categories,
--      languages, formats, physical conditions, acquisition types, and financial years.
--   2. fn_library_get_member_filter_options: Dynamic lookup member types, active classes,
--      lookup departments, and dynamic platform roles from app_roles.
--   3. fn_library_get_circulation_filter_options: Dynamic platform roles, active classes,
--      and transaction choices.
--   4. fn_library_get_request_kpis: Real calculated request type distribution joined with
--      lookup_values, dynamic status percentages, and live recent requests feed.
-- ============================================================================

-- 1. Dynamic Book Filter Options
CREATE OR REPLACE FUNCTION public.fn_library_get_book_filter_options(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_categories JSONB;
    v_languages JSONB;
    v_book_types JSONB;
    v_conditions JSONB;
    v_acquisition_types JSONB;
    v_authors JSONB;
    v_publishers JSONB;
    v_years JSONB;
    v_racks JSONB;
BEGIN
    -- Categories from lookup_keys: BOOK_CATEGORY / LIBRARY_BOOK_CATEGORY / LIBRARY_REQUEST_CATEGORY or books
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_categories
    FROM (
        SELECT lv.value_name AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code IN ('BOOK_CATEGORY', 'LIBRARY_BOOK_CATEGORY', 'LIBRARY_REQUEST_CATEGORY') 
          AND (lv.school_id = p_school_id OR lv.school_id IS NULL)
          AND lv.status = 'ACTIVE'
        UNION
        SELECT DISTINCT category_name AS val FROM public.library_books WHERE school_id = p_school_id AND category_name IS NOT NULL AND category_name != ''
    ) sub;

    -- Languages from lookup_keys: BOOK_LANGUAGE or books
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '["English", "Hindi", "Sanskrit"]'::jsonb) INTO v_languages
    FROM (
        SELECT lv.value_name AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'BOOK_LANGUAGE' AND (lv.school_id = p_school_id OR lv.school_id IS NULL) AND lv.status = 'ACTIVE'
        UNION
        SELECT DISTINCT language_name AS val FROM public.library_books WHERE school_id = p_school_id AND language_name IS NOT NULL AND language_name != ''
    ) sub;

    -- Book Types / Formats from lookup_keys: BOOK_TYPE or books
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '["Paperback", "Hardcover", "Reference", "E-Book"]'::jsonb) INTO v_book_types
    FROM (
        SELECT lv.value_name AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'BOOK_TYPE' AND (lv.school_id = p_school_id OR lv.school_id IS NULL) AND lv.status = 'ACTIVE'
        UNION
        SELECT DISTINCT book_type_name AS val FROM public.library_books WHERE school_id = p_school_id AND book_type_name IS NOT NULL AND book_type_name != ''
    ) sub;

    -- Conditions from lookup_keys: BOOK_CONDITION
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '["NEW", "EXCELLENT", "GOOD", "FAIR", "DAMAGED"]'::jsonb) INTO v_conditions
    FROM (
        SELECT lv.value_code AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'BOOK_CONDITION' AND (lv.school_id = p_school_id OR lv.school_id IS NULL) AND lv.status = 'ACTIVE'
        UNION
        SELECT DISTINCT condition AS val FROM public.library_book_copies WHERE school_id = p_school_id AND condition IS NOT NULL AND condition != ''
    ) sub;

    -- Acquisition Types from lookup_keys: ACQUISITION_TYPE
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '["PURCHASE", "DONATION", "GRANT", "INTER_LIBRARY_LOAN"]'::jsonb) INTO v_acquisition_types
    FROM (
        SELECT lv.value_code AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'ACQUISITION_TYPE' AND (lv.school_id = p_school_id OR lv.school_id IS NULL) AND lv.status = 'ACTIVE'
        UNION
        SELECT DISTINCT acquisition_type AS val FROM public.library_books WHERE school_id = p_school_id AND acquisition_type IS NOT NULL AND acquisition_type != ''
    ) sub;

    -- Authors
    SELECT COALESCE(jsonb_agg(DISTINCT author ORDER BY author ASC), '[]'::jsonb) INTO v_authors
    FROM public.library_books
    WHERE school_id = p_school_id AND author IS NOT NULL AND author != '';

    -- Publishers
    SELECT COALESCE(jsonb_agg(DISTINCT publisher ORDER BY publisher ASC), '[]'::jsonb) INTO v_publishers
    FROM public.library_books
    WHERE school_id = p_school_id AND publisher IS NOT NULL AND publisher != '';

    -- Financial Years EXCLUSIVELY from lookup_keys where key_code = 'FINANCIAL_YEAR'
    SELECT COALESCE(jsonb_agg(val), '[]'::jsonb) INTO v_years
    FROM (
        SELECT lv.value_name AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'FINANCIAL_YEAR' 
          AND (lv.school_id = p_school_id OR lv.school_id IS NULL) 
          AND lv.status = 'ACTIVE'
        ORDER BY lv.sort_order ASC, lv.value_name DESC
    ) sub;

    -- Racks
    SELECT COALESCE(jsonb_agg(DISTINCT rack_location ORDER BY rack_location ASC), '[]'::jsonb) INTO v_racks
    FROM public.library_books
    WHERE school_id = p_school_id AND rack_location IS NOT NULL AND rack_location != '';

    RETURN jsonb_build_object(
        'categories', v_categories,
        'languages', v_languages,
        'book_types', v_book_types,
        'conditions', v_conditions,
        'acquisition_types', v_acquisition_types,
        'authors', v_authors,
        'publishers', v_publishers,
        'publication_years', v_years,
        'racks', v_racks
    );
END;
$$;


-- 2. Dynamic Member Filter Options
CREATE OR REPLACE FUNCTION public.fn_library_get_member_filter_options(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_types JSONB;
    v_classes JSONB;
    v_departments JSONB;
    v_roles JSONB;
BEGIN
    -- Membership Types from lookups or members table
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '["Student", "Teacher", "Staff", "Librarian", "Special / Research"]'::jsonb) INTO v_types
    FROM (
        SELECT lv.value_name AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code IN ('LIBRARY_MEMBERSHIP_TYPE', 'MEMBERSHIP_TYPE', 'USER_CATEGORY') AND (lv.school_id = p_school_id OR lv.school_id IS NULL) AND lv.status = 'ACTIVE'
        UNION
        SELECT DISTINCT membership_type AS val FROM public.library_members WHERE school_id = p_school_id AND membership_type IS NOT NULL AND membership_type != ''
    ) sub;

    -- Distinct Classes from academic_classes & profiles
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_classes
    FROM (
        SELECT name AS val FROM public.academic_classes WHERE school_id = p_school_id AND status = 'ACTIVE'
        UNION
        SELECT DISTINCT class AS val FROM public.profiles WHERE school_id = p_school_id AND class IS NOT NULL AND class != ''
    ) sub;

    -- Distinct Departments from lookups (DEPARTMENT) & profiles
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_departments
    FROM (
        SELECT lv.value_name AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'DEPARTMENT' AND (lv.school_id = p_school_id OR lv.school_id IS NULL) AND lv.status = 'ACTIVE'
        UNION
        SELECT DISTINCT department AS val FROM public.profiles WHERE school_id = p_school_id AND department IS NOT NULL AND department != ''
    ) sub;

    -- Platform Roles from app_roles (ONLY ACTIVE ROLES)
    SELECT COALESCE(jsonb_agg(DISTINCT COALESCE(display_name, INITCAP(name)) ORDER BY COALESCE(display_name, INITCAP(name)) ASC), '["Student", "Teacher", "Staff", "Parent"]'::jsonb) INTO v_roles
    FROM public.app_roles
    WHERE UPPER(COALESCE(status, 'ACTIVE')) = 'ACTIVE'
      AND (school_id = p_school_id OR school_id IS NULL);

    RETURN jsonb_build_object(
        'member_types', v_types,
        'classes', v_classes,
        'departments', v_departments,
        'roles', v_roles,
        'statuses', '["ACTIVE", "INACTIVE", "SUSPENDED", "EXPIRED", "EXPIRING_SOON"]'::jsonb
    );
END;
$$;


-- 3. Dynamic Circulation Filter Options
CREATE OR REPLACE FUNCTION public.fn_library_get_circulation_filter_options(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_roles JSONB;
    v_classes JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(DISTINCT COALESCE(display_name, INITCAP(name)) ORDER BY COALESCE(display_name, INITCAP(name)) ASC), '["Student", "Teacher", "Staff", "Parent"]'::jsonb) INTO v_roles
    FROM public.app_roles
    WHERE UPPER(COALESCE(status, 'ACTIVE')) = 'ACTIVE'
      AND (school_id = p_school_id OR school_id IS NULL);


    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_classes
    FROM (
        SELECT name AS val FROM public.academic_classes WHERE school_id = p_school_id AND status = 'ACTIVE'
        UNION
        SELECT DISTINCT class AS val FROM public.profiles WHERE school_id = p_school_id AND class IS NOT NULL AND class != ''
    ) sub;

    RETURN jsonb_build_object(
        'transaction_types', jsonb_build_array('All', 'Manual Issue', 'Request Approved', 'Manual Return', 'Renewed', 'Lost / Damaged'),
        'statuses', jsonb_build_array('All', 'Issued', 'Returned', 'Overdue', 'Renewed', 'Pending', 'Lost', 'Damaged'),
        'search_in_fields', jsonb_build_array('All Transactions', 'Member Name', 'Member Code', 'Book Title', 'ISBN', 'Barcode', 'Transaction ID'),
        'roles', v_roles,
        'classes', v_classes
    );
END;
$$;


-- 3b. Dynamic Live Circulation Stats & Accurate KPI Calculations
CREATE OR REPLACE FUNCTION public.fn_library_get_circulation_stats(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_transactions BIGINT := 0;
    v_issued_today BIGINT := 0;
    v_issued_yesterday BIGINT := 0;
    v_issued_delta NUMERIC := 0.0;
    v_returned_today BIGINT := 0;
    v_returned_yesterday BIGINT := 0;
    v_returned_delta NUMERIC := 0.0;
    v_currently_issued BIGINT := 0;
    v_overdue_count BIGINT := 0;
    v_pending_requests BIGINT := 0;
    v_pending_renewals BIGINT := 0;
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
    WHERE school_id = p_school_id 
      AND (return_date = CURRENT_DATE OR returned_at::date = CURRENT_DATE) 
      AND (status = 'RETURNED' OR is_returned = TRUE);

    SELECT COALESCE(COUNT(*), 0) INTO v_returned_yesterday
    FROM public.library_borrows
    WHERE school_id = p_school_id 
      AND (return_date = (CURRENT_DATE - INTERVAL '1 day')::date OR returned_at::date = (CURRENT_DATE - INTERVAL '1 day')::date)
      AND (status = 'RETURNED' OR is_returned = TRUE);

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


-- 4. Dynamic Live Request KPIs & Type Counts
CREATE OR REPLACE FUNCTION public.fn_library_get_request_kpis(

    p_school_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_role TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
      AND (NOT v_is_requester_only OR r.requester_user_id = p_user_id OR r.student_id = p_user_id);

    -- Request Types Breakdown (Deduplicated lookup types + any existing types in requests with REAL calculated counts)
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
            UNION ALL
            SELECT DISTINCT r.request_type AS type_name, 999 AS sort_ord
            FROM public.library_requests r
            WHERE r.school_id = p_school_id AND r.request_type IS NOT NULL AND r.request_type != ''
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
        ORDER BY r.created_at DESC
        LIMIT 5
    ) r
    LEFT JOIN public.profiles p ON (r.requester_user_id = p.id OR r.student_id = p.id);

    RETURN jsonb_build_object(
        'total_requests', v_total,
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
$$;


-- ============================================================================
-- 5. IDEMPOTENT INSERT SCRIPTS FOR ALL LIBRARY LOOKUP KEYS AND VALUES
-- ============================================================================
DO $$
DECLARE
    s_record RECORD;
    admin_id UUID;
    v_key_id UUID;
BEGIN
    -- Resolve a default admin user ID for audit columns
    SELECT id INTO admin_id FROM public.profiles WHERE role IN ('admin', 'super_admin') LIMIT 1;
    IF admin_id IS NULL THEN
        SELECT id INTO admin_id FROM public.profiles LIMIT 1;
    END IF;

    FOR s_record IN (SELECT id FROM public.schools) LOOP
        -- --------------------------------------------------------------------
        -- 1. LIBRARY REQUEST TYPE
        -- --------------------------------------------------------------------
        INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (s_record.id, 'Library Request Type', 'LIBRARY_REQUEST_TYPE', 'Types of specific requests (Book, Audiobook, E-Book, etc.)', 'SYSTEM', 'format_list_bulleted', 'ACTIVE', admin_id)
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
        RETURNING id INTO v_key_id;

        IF v_key_id IS NULL THEN
            SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s_record.id AND key_code = 'LIBRARY_REQUEST_TYPE' AND deleted_at IS NULL LIMIT 1;
        END IF;

        IF v_key_id IS NOT NULL AND admin_id IS NOT NULL THEN
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by)
            VALUES 
                (v_key_id, s_record.id, 'Book', 'Book', 1, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'E-Book', 'E-Book', 2, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Digital Resource', 'Digital Resource', 3, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Audiobook', 'Audiobook', 4, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Journal / Magazine', 'Journal / Magazine', 5, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Other', 'Other', 6, 'ACTIVE', admin_id)
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO UPDATE 
            SET value_name = EXCLUDED.value_name, sort_order = EXCLUDED.sort_order, status = 'ACTIVE';
        END IF;

        -- --------------------------------------------------------------------
        -- 2. LIBRARY REQUEST PRIORITY
        -- --------------------------------------------------------------------
        INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (s_record.id, 'Library Request Priority', 'LIBRARY_REQUEST_PRIORITY', 'Priority levels for resource and material requests', 'SYSTEM', 'priority_high', 'ACTIVE', admin_id)
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
        RETURNING id INTO v_key_id;

        IF v_key_id IS NULL THEN
            SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s_record.id AND key_code = 'LIBRARY_REQUEST_PRIORITY' AND deleted_at IS NULL LIMIT 1;
        END IF;

        IF v_key_id IS NOT NULL AND admin_id IS NOT NULL THEN
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by)
            VALUES 
                (v_key_id, s_record.id, 'Low', 'Low', 1, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Normal', 'Normal', 2, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'High', 'High', 3, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Urgent', 'Urgent', 4, 'ACTIVE', admin_id)
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO UPDATE 
            SET value_name = EXCLUDED.value_name, sort_order = EXCLUDED.sort_order, status = 'ACTIVE';
        END IF;

        -- --------------------------------------------------------------------
        -- 3. LIBRARY REQUEST REJECTION REASON
        -- --------------------------------------------------------------------
        INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (s_record.id, 'Library Request Rejection Reason', 'LIBRARY_REQUEST_REJECTION_REASON', 'Standardized cancellation and rejection reasons for library requests', 'SYSTEM', 'cancel_outlined', 'ACTIVE', admin_id)
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
        RETURNING id INTO v_key_id;

        IF v_key_id IS NULL THEN
            SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s_record.id AND key_code = 'LIBRARY_REQUEST_REJECTION_REASON' AND deleted_at IS NULL LIMIT 1;
        END IF;

        IF v_key_id IS NOT NULL AND admin_id IS NOT NULL THEN
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by)
            VALUES 
                (v_key_id, s_record.id, 'Already Available in Library', 'ALREADY_AVAILABLE', 1, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Out of Print / Unavailable', 'OUT_OF_PRINT', 2, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Duplicate Request', 'DUPLICATE', 3, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Exceeds Academic Budget', 'BUDGET_EXCEEDED', 4, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Not Recommended for Curriculum', 'NOT_RECOMMENDED', 5, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Non-Academic / Out of Scope', 'OUT_OF_SCOPE', 6, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Other Reason', 'OTHER', 7, 'ACTIVE', admin_id)
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO UPDATE 
            SET value_name = EXCLUDED.value_name, sort_order = EXCLUDED.sort_order, status = 'ACTIVE';
        END IF;

        -- --------------------------------------------------------------------
        -- 4. BOOK CATEGORIES (BOOK_CATEGORY & LIBRARY_REQUEST_CATEGORY)
        -- --------------------------------------------------------------------
        INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (s_record.id, 'Book Category', 'BOOK_CATEGORY', 'Standard classifications and genres for library cataloguing.', 'SYSTEM', 'auto_stories_outlined', 'ACTIVE', admin_id)
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
        RETURNING id INTO v_key_id;

        IF v_key_id IS NULL THEN
            SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s_record.id AND key_code = 'BOOK_CATEGORY' AND deleted_at IS NULL LIMIT 1;
        END IF;

        IF v_key_id IS NOT NULL AND admin_id IS NOT NULL THEN
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by) VALUES
                (v_key_id, s_record.id, 'Computer Science', 'COMPUTER_SCIENCE', 1, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Data Structures & Algorithms', 'DSA', 2, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Software Engineering', 'SOFTWARE_ENG', 3, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Artificial Intelligence', 'AI', 4, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Machine Learning', 'ML', 5, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Mathematics & Statistics', 'MATHEMATICS', 6, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Physics', 'PHYSICS', 7, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Chemistry', 'CHEMISTRY', 8, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Biology', 'BIOLOGY', 9, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Environmental Science', 'ENV_SCIENCE', 10, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'History', 'HISTORY', 11, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Geography', 'GEOGRAPHY', 12, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Political Science', 'POLITICAL_SCIENCE', 13, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Economics', 'ECONOMICS', 14, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Business Studies', 'BUSINESS_STUDIES', 15, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Accounting & Finance', 'FINANCE', 16, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'English Literature', 'ENGLISH', 17, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Hindi Literature', 'HINDI_LIT', 18, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Psychology', 'PSYCHOLOGY', 19, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Sociology', 'SOCIOLOGY', 20, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Philosophy', 'PHILOSOPHY', 21, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Self Help & Productivity', 'SELF_HELP', 22, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Fiction & Novels', 'FICTION', 23, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Non-Fiction & Biography', 'BIOGRAPHY', 24, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'General Knowledge', 'GK', 25, 'ACTIVE', admin_id)
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO UPDATE 
            SET value_name = EXCLUDED.value_name, sort_order = EXCLUDED.sort_order, status = 'ACTIVE';
        END IF;

        -- --------------------------------------------------------------------
        -- 5. BOOK LANGUAGES (BOOK_LANGUAGE)
        -- --------------------------------------------------------------------
        INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (s_record.id, 'Book Language', 'BOOK_LANGUAGE', 'Primary languages for published library materials.', 'SYSTEM', 'translate_outlined', 'ACTIVE', admin_id)
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
        RETURNING id INTO v_key_id;

        IF v_key_id IS NULL THEN
            SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s_record.id AND key_code = 'BOOK_LANGUAGE' AND deleted_at IS NULL LIMIT 1;
        END IF;

        IF v_key_id IS NOT NULL AND admin_id IS NOT NULL THEN
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by) VALUES
                (v_key_id, s_record.id, 'English', 'ENGLISH', 1, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Hindi', 'HINDI', 2, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Sanskrit', 'SANSKRIT', 3, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'French', 'FRENCH', 4, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'German', 'GERMAN', 5, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Spanish', 'SPANISH', 6, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Bengali', 'BENGALI', 7, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Marathi', 'MARATHI', 8, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Tamil', 'TAMIL', 9, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Telugu', 'TELUGU', 10, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Gujarati', 'GUJARATI', 11, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Other Regional', 'OTHER', 12, 'ACTIVE', admin_id)
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO UPDATE 
            SET value_name = EXCLUDED.value_name, sort_order = EXCLUDED.sort_order, status = 'ACTIVE';
        END IF;

        -- --------------------------------------------------------------------
        -- 6. BOOK TYPES / FORMATS (BOOK_TYPE)
        -- --------------------------------------------------------------------
        INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (s_record.id, 'Book Type / Format', 'BOOK_TYPE', 'Physical format and binding of library catalogue records.', 'SYSTEM', 'book_outlined', 'ACTIVE', admin_id)
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
        RETURNING id INTO v_key_id;

        IF v_key_id IS NULL THEN
            SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s_record.id AND key_code = 'BOOK_TYPE' AND deleted_at IS NULL LIMIT 1;
        END IF;

        IF v_key_id IS NOT NULL AND admin_id IS NOT NULL THEN
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by) VALUES
                (v_key_id, s_record.id, 'Paperback', 'PAPERBACK', 1, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Hardcover', 'HARDCOVER', 2, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Reference', 'REFERENCE', 3, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'E-Book', 'EBOOK', 4, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Audiobook', 'AUDIOBOOK', 5, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Journal / Magazine', 'JOURNAL_MAGAZINE', 6, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Digital Resource', 'DIGITAL_RESOURCE', 7, 'ACTIVE', admin_id)
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO UPDATE 
            SET value_name = EXCLUDED.value_name, sort_order = EXCLUDED.sort_order, status = 'ACTIVE';
        END IF;

        -- --------------------------------------------------------------------
        -- 7. BOOK CONDITIONS (BOOK_CONDITION)
        -- --------------------------------------------------------------------
        INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (s_record.id, 'Book Physical Condition', 'BOOK_CONDITION', 'Physical quality state of individual book copies.', 'SYSTEM', 'health_and_safety_outlined', 'ACTIVE', admin_id)
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
        RETURNING id INTO v_key_id;

        IF v_key_id IS NULL THEN
            SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s_record.id AND key_code = 'BOOK_CONDITION' AND deleted_at IS NULL LIMIT 1;
        END IF;

        IF v_key_id IS NOT NULL AND admin_id IS NOT NULL THEN
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by) VALUES
                (v_key_id, s_record.id, 'NEW', 'NEW', 1, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'EXCELLENT', 'EXCELLENT', 2, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'GOOD', 'GOOD', 3, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'FAIR', 'FAIR', 4, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'DAMAGED', 'DAMAGED', 5, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'LOST', 'LOST', 6, 'ACTIVE', admin_id)
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO UPDATE 
            SET value_name = EXCLUDED.value_name, sort_order = EXCLUDED.sort_order, status = 'ACTIVE';
        END IF;

        -- --------------------------------------------------------------------
        -- 8. ACQUISITION TYPES (ACQUISITION_TYPE)
        -- --------------------------------------------------------------------
        INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (s_record.id, 'Book Acquisition Type', 'ACQUISITION_TYPE', 'Method by which the library acquired the material.', 'SYSTEM', 'inventory_2_outlined', 'ACTIVE', admin_id)
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
        RETURNING id INTO v_key_id;

        IF v_key_id IS NULL THEN
            SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s_record.id AND key_code = 'ACQUISITION_TYPE' AND deleted_at IS NULL LIMIT 1;
        END IF;

        IF v_key_id IS NOT NULL AND admin_id IS NOT NULL THEN
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by) VALUES
                (v_key_id, s_record.id, 'PURCHASE', 'PURCHASE', 1, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'DONATION', 'DONATION', 2, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'GRANT', 'GRANT', 3, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'INTER_LIBRARY_LOAN', 'INTER_LIBRARY_LOAN', 4, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'GIFT', 'GIFT', 5, 'ACTIVE', admin_id)
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO UPDATE 
            SET value_name = EXCLUDED.value_name, sort_order = EXCLUDED.sort_order, status = 'ACTIVE';
        END IF;

        -- --------------------------------------------------------------------
        -- 9. LIBRARY MEMBERSHIP TYPES (LIBRARY_MEMBERSHIP_TYPE)
        -- --------------------------------------------------------------------
        INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
        VALUES (s_record.id, 'Library Membership Type', 'LIBRARY_MEMBERSHIP_TYPE', 'Member types with customized issue quota policies.', 'SYSTEM', 'badge_outlined', 'ACTIVE', admin_id)
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
        RETURNING id INTO v_key_id;

        IF v_key_id IS NULL THEN
            SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s_record.id AND key_code = 'LIBRARY_MEMBERSHIP_TYPE' AND deleted_at IS NULL LIMIT 1;
        END IF;

        IF v_key_id IS NOT NULL AND admin_id IS NOT NULL THEN
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, sort_order, status, created_by) VALUES
                (v_key_id, s_record.id, 'Student', 'STUDENT', 1, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Teacher', 'TEACHER', 2, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Staff', 'STAFF', 3, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Librarian', 'LIBRARIAN', 4, 'ACTIVE', admin_id),
                (v_key_id, s_record.id, 'Special / Research', 'SPECIAL_RESEARCH', 5, 'ACTIVE', admin_id)
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO UPDATE 
            SET value_name = EXCLUDED.value_name, sort_order = EXCLUDED.sort_order, status = 'ACTIVE';
        END IF;

    END LOOP;
END $$;

