-- ============================================================================
-- MIGRATION 330: LIBRARY MANAGEMENT STORED PROCEDURES & OPTIMIZED FUNCTIONS
-- Description: High-performance PostgreSQL PL/pgSQL stored functions for
--              Books, Physical Copies, Barcodes, Members, Fines, and Analytics.
-- ============================================================================

-- ============================================================================
-- 1. BOOKS MODULE STORED FUNCTIONS
-- ============================================================================

-- 1.1 Aggregated Books KPI Stats Function
CREATE OR REPLACE FUNCTION public.fn_library_get_book_stats(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_stats JSONB;
BEGIN
    SELECT jsonb_build_object(
        'total_titles', COALESCE((SELECT COUNT(*) FROM public.library_books WHERE school_id = p_school_id AND archived_at IS NULL), 0),
        'total_copies', COALESCE((SELECT COUNT(*) FROM public.library_book_copies WHERE school_id = p_school_id AND status != 'ARCHIVED'), 0),
        'available_copies', COALESCE((SELECT COUNT(*) FROM public.library_book_copies WHERE school_id = p_school_id AND status = 'AVAILABLE'), 0),
        'issued_copies', COALESCE((SELECT COUNT(*) FROM public.library_book_copies WHERE school_id = p_school_id AND status = 'ISSUED'), 0),
        'reserved_copies', COALESCE((SELECT COUNT(*) FROM public.library_book_copies WHERE school_id = p_school_id AND status = 'RESERVED'), 0),
        'lost_damaged_copies', COALESCE((SELECT COUNT(*) FROM public.library_book_copies WHERE school_id = p_school_id AND status IN ('LOST', 'DAMAGED')), 0),
        'overdue_copies', COALESCE((SELECT COUNT(*) FROM public.library_book_copies WHERE school_id = p_school_id AND status = 'OVERDUE'), 0),
        'archived_titles', COALESCE((SELECT COUNT(*) FROM public.library_books WHERE school_id = p_school_id AND archived_at IS NOT NULL), 0)
    ) INTO v_stats;

    RETURN v_stats;
END;
$$;


-- 1.2 Dynamic Books Dropdown Filter Options
CREATE OR REPLACE FUNCTION public.fn_library_get_book_filter_options(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_categories JSONB;
    v_languages JSONB;
    v_book_types JSONB;
    v_authors JSONB;
    v_publishers JSONB;
    v_years JSONB;
BEGIN
    -- Categories from lookups or books
    SELECT COALESCE(jsonb_agg(DISTINCT val), '[]'::jsonb) INTO v_categories
    FROM (
        SELECT lv.value_name AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code IN ('BOOK_CATEGORY', 'LIBRARY_BOOK_CATEGORY') AND (lv.school_id = p_school_id OR lv.school_id IS NULL)
        UNION
        SELECT DISTINCT category_name AS val FROM public.library_books WHERE school_id = p_school_id AND category_name IS NOT NULL AND category_name != ''
    ) sub;

    -- Languages
    SELECT COALESCE(jsonb_agg(DISTINCT val), '["English", "Hindi", "Sanskrit"]'::jsonb) INTO v_languages
    FROM (
        SELECT lv.value_name AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'BOOK_LANGUAGE' AND (lv.school_id = p_school_id OR lv.school_id IS NULL)
        UNION
        SELECT DISTINCT language_name AS val FROM public.library_books WHERE school_id = p_school_id AND language_name IS NOT NULL AND language_name != ''
    ) sub;

    -- Book Types
    SELECT COALESCE(jsonb_agg(DISTINCT val), '["Paperback", "Hardcover", "Reference", "E-Book"]'::jsonb) INTO v_book_types
    FROM (
        SELECT lv.value_name AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'BOOK_TYPE' AND (lv.school_id = p_school_id OR lv.school_id IS NULL)
        UNION
        SELECT DISTINCT book_type_name AS val FROM public.library_books WHERE school_id = p_school_id AND book_type_name IS NOT NULL AND book_type_name != ''
    ) sub;

    -- Authors
    SELECT COALESCE(jsonb_agg(DISTINCT author ORDER BY author ASC), '[]'::jsonb) INTO v_authors
    FROM public.library_books
    WHERE school_id = p_school_id AND author IS NOT NULL AND author != '';

    -- Publishers
    SELECT COALESCE(jsonb_agg(DISTINCT publisher ORDER BY publisher ASC), '[]'::jsonb) INTO v_publishers
    FROM public.library_books
    WHERE school_id = p_school_id AND publisher IS NOT NULL AND publisher != '';

    -- Publication Years
    SELECT COALESCE(jsonb_agg(DISTINCT publication_year::text ORDER BY publication_year::text DESC), '[]'::jsonb) INTO v_years
    FROM public.library_books
    WHERE school_id = p_school_id AND publication_year IS NOT NULL;

    RETURN jsonb_build_object(
        'categories', v_categories,
        'languages', v_languages,
        'book_types', v_book_types,
        'authors', v_authors,
        'publishers', v_publishers,
        'publication_years', v_years
    );
END;
$$;


-- 1.3 Super-Fast Multi-Filtered Paginated Books Function
CREATE OR REPLACE FUNCTION public.fn_library_list_books(
    p_school_id UUID,
    p_search TEXT DEFAULT NULL,
    p_category TEXT DEFAULT NULL,
    p_author TEXT DEFAULT NULL,
    p_publisher TEXT DEFAULT NULL,
    p_language TEXT DEFAULT NULL,
    p_book_type TEXT DEFAULT NULL,
    p_rack TEXT DEFAULT NULL,
    p_status TEXT DEFAULT 'ACTIVE',
    p_availability TEXT DEFAULT 'ALL',
    p_year_min INT DEFAULT NULL,
    p_year_max INT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'title',
    p_sort_order TEXT DEFAULT 'ASC',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT;
    v_total INT;
    v_items JSONB;
    v_total_pages INT;
    v_sql TEXT;
    v_where TEXT := 'b.school_id = $1';
    v_order_col TEXT;
    v_order_dir TEXT;
BEGIN
    v_offset := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);

    -- Status condition
    IF UPPER(p_status) = 'ARCHIVED' THEN
        v_where := v_where || ' AND b.archived_at IS NOT NULL';
    ELSE
        v_where := v_where || ' AND b.archived_at IS NULL';
    END IF;

    -- Search filter
    IF p_search IS NOT NULL AND TRIM(p_search) != '' THEN
        v_where := v_where || format(' AND (b.title ILIKE %L OR b.author ILIKE %L OR b.isbn13 ILIKE %L OR b.isbn10 ILIKE %L OR EXISTS (SELECT 1 FROM public.library_book_copies c WHERE c.book_id = b.id AND (c.barcode ILIKE %L OR c.accession_number ILIKE %L)))',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%'
        );
    END IF;

    -- Category filter
    IF p_category IS NOT NULL AND TRIM(p_category) != '' AND UPPER(p_category) != 'ALL' AND UPPER(p_category) != 'ALL CATEGORIES' THEN
        v_where := v_where || format(' AND (b.category_name ILIKE %L)', '%' || TRIM(p_category) || '%');
    END IF;

    -- Author filter
    IF p_author IS NOT NULL AND TRIM(p_author) != '' AND UPPER(p_author) != 'ALL' AND UPPER(p_author) != 'ALL AUTHORS' THEN
        v_where := v_where || format(' AND (b.author ILIKE %L)', '%' || TRIM(p_author) || '%');
    END IF;

    -- Publisher filter
    IF p_publisher IS NOT NULL AND TRIM(p_publisher) != '' AND UPPER(p_publisher) != 'ALL' AND UPPER(p_publisher) != 'ALL PUBLISHERS' THEN
        v_where := v_where || format(' AND (b.publisher ILIKE %L)', '%' || TRIM(p_publisher) || '%');
    END IF;

    -- Language filter
    IF p_language IS NOT NULL AND TRIM(p_language) != '' AND UPPER(p_language) != 'ALL' THEN
        v_where := v_where || format(' AND (b.language_name ILIKE %L)', '%' || TRIM(p_language) || '%');
    END IF;

    -- Book type filter
    IF p_book_type IS NOT NULL AND TRIM(p_book_type) != '' AND UPPER(p_book_type) != 'ALL' THEN
        v_where := v_where || format(' AND (b.book_type_name ILIKE %L)', '%' || TRIM(p_book_type) || '%');
    END IF;

    -- Rack location filter
    IF p_rack IS NOT NULL AND TRIM(p_rack) != '' AND UPPER(p_rack) != 'ALL' THEN
        v_where := v_where || format(' AND (b.rack_location ILIKE %L)', '%' || TRIM(p_rack) || '%');
    END IF;

    -- Publication Year range
    IF p_year_min IS NOT NULL THEN
        v_where := v_where || format(' AND b.publication_year >= %s', p_year_min);
    END IF;
    IF p_year_max IS NOT NULL THEN
        v_where := v_where || format(' AND b.publication_year <= %s', p_year_max);
    END IF;

    -- Availability filter
    IF UPPER(p_availability) = 'AVAILABLE' THEN
        v_where := v_where || ' AND b.available_copies > 0';
    ELSIF UPPER(p_availability) = 'ISSUED' THEN
        v_where := v_where || ' AND b.issued_copies > 0';
    ELSIF UPPER(p_availability) = 'OVERDUE' THEN
        v_where := v_where || ' AND EXISTS (SELECT 1 FROM public.library_book_copies c WHERE c.book_id = b.id AND c.archived_at IS NULL AND (c.status = ''OVERDUE'' OR (c.status = ''ISSUED'' AND c.due_date IS NOT NULL AND c.due_date < CURRENT_DATE)))';
    ELSIF UPPER(p_availability) = 'OUT_OF_STOCK' THEN
        v_where := v_where || ' AND b.available_copies = 0';
    END IF;

    -- Sort column map
    CASE LOWER(COALESCE(p_sort_by, 'title'))
        WHEN 'author' THEN v_order_col := 'b.author';
        WHEN 'category' THEN v_order_col := 'b.category_name';
        WHEN 'publication_year' THEN v_order_col := 'b.publication_year';
        WHEN 'total_copies' THEN v_order_col := 'b.total_copies';
        WHEN 'available_copies' THEN v_order_col := 'b.available_copies';
        WHEN 'created_at' THEN v_order_col := 'b.created_at';
        ELSE v_order_col := 'b.title';
    END CASE;

    IF LOWER(COALESCE(p_sort_order, 'asc')) = 'desc' THEN
        v_order_dir := 'DESC';
    ELSE
        v_order_dir := 'ASC';
    END IF;

    -- 1. Get Count
    EXECUTE 'SELECT COUNT(*) FROM public.library_books b WHERE ' || v_where
    USING p_school_id
    INTO v_total;

    v_total_pages := GREATEST(CEIL(v_total::NUMERIC / GREATEST(p_page_size, 1)), 1);

    -- 2. Get Paginated Items as JSONB
    v_sql := format(
        'SELECT COALESCE(jsonb_agg(row_to_json(t)), ''[]''::jsonb)
         FROM (
             SELECT
                 b.id,
                 b.school_id,
                 b.title,
                 b.subtitle,
                 b.author,
                 b.co_authors,
                 b.publisher,
                 b.edition,
                 b.publication_year,
                 b.pages,
                 b.description,
                 b.isbn10,
                 b.isbn13,
                 b.isbn,
                 b.category_id,
                 b.category_name,
                 b.language_id,
                 b.language_name,
                 b.book_type_id,
                 b.book_type_name,
                 b.rack_location,
                 b.shelf_location,
                 b.cover_url,
                 b.total_copies,
                 b.available_copies,
                 b.issued_copies,
                 b.reserved_copies,
                 b.status,
                 b.created_at,
                 b.updated_at,
                 b.archived_at,
                 (
                     SELECT c.barcode FROM public.library_book_copies c 
                     WHERE c.book_id = b.id AND c.archived_at IS NULL 
                     ORDER BY c.copy_number ASC LIMIT 1
                 ) AS primary_barcode,
                 (
                     SELECT c.accession_number FROM public.library_book_copies c 
                     WHERE c.book_id = b.id AND c.archived_at IS NULL 
                     ORDER BY c.copy_number ASC LIMIT 1
                 ) AS primary_accession_number,
                 (
                     SELECT COUNT(*) FROM public.library_book_copies c 
                     WHERE c.book_id = b.id AND c.archived_at IS NULL 
                       AND (c.status = ''OVERDUE'' OR (c.status = ''ISSUED'' AND c.due_date IS NOT NULL AND c.due_date < CURRENT_DATE))
                 ) AS overdue_copies_count,
                 b.supplier,
                 b.purchase_price,
                 b.acquisition_type,
                 b.invoice_ref,
                 b.purchase_date
             FROM public.library_books b
             WHERE %s
             ORDER BY %s %s, b.id ASC
             LIMIT %s OFFSET %s
         ) t',
        v_where,
        v_order_col,
        v_order_dir,
        p_page_size,
        v_offset
    );

    EXECUTE v_sql USING p_school_id INTO v_items;

    RETURN jsonb_build_object(
        'items', v_items,
        'pagination', jsonb_build_object(
            'page', p_page,
            'page_size', p_page_size,
            'total', v_total,
            'total_items', v_total,
            'total_pages', v_total_pages,
            'pages', v_total_pages
        )
    );
END;
$$;


-- 1.4 Single-Trip Book Detail Function (Book + Copies + Active Borrows)
CREATE OR REPLACE FUNCTION public.fn_library_get_book_detail(
    p_school_id UUID,
    p_book_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_book JSONB;
    v_copies JSONB;
    v_active_borrows JSONB;
BEGIN
    -- 1. Book bibliographic record
    SELECT to_jsonb(b) INTO v_book
    FROM public.library_books b
    WHERE b.id = p_book_id AND b.school_id = p_school_id;

    IF v_book IS NULL THEN
        RETURN NULL;
    END IF;

    -- 2. Physical copies with barcodes
    SELECT COALESCE(jsonb_agg(to_jsonb(c) ORDER BY c.copy_number ASC), '[]'::jsonb) INTO v_copies
    FROM public.library_book_copies c
    WHERE c.book_id = p_book_id AND c.school_id = p_school_id;

    -- 3. Active borrow records
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'borrow_id', br.id,
            'copy_id', br.copy_id,
            'member_id', br.member_id,
            'member_code', m.member_code,
            'member_name', p.full_name,
            'member_type', m.membership_type,
            'issue_date', br.issue_date,
            'due_date', br.due_date,
            'status', br.status,
            'fine_amount', br.fine_amount,
            'is_overdue', (br.due_date < CURRENT_DATE AND br.status = 'ISSUED')
        )
    ), '[]'::jsonb) INTO v_active_borrows
    FROM public.library_borrows br
    JOIN public.library_members m ON br.member_id = m.id
    JOIN public.profiles p ON m.profile_id = p.id
    WHERE br.book_id = p_book_id AND br.school_id = p_school_id AND br.status = 'ISSUED';

    RETURN jsonb_build_object(
        'book', v_book,
        'copies', v_copies,
        'active_borrows', v_active_borrows
    );
END;
$$;


-- ============================================================================
-- 2. MEMBERS MODULE STORED FUNCTIONS
-- ============================================================================

-- 2.1 Aggregated Members KPI Stats Function
CREATE OR REPLACE FUNCTION public.fn_library_get_member_stats(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_stats JSONB;
BEGIN
    SELECT jsonb_build_object(
        'total_members', COALESCE((SELECT COUNT(*) FROM public.library_members WHERE school_id = p_school_id AND archived_at IS NULL), 0),
        'active_members', COALESCE((SELECT COUNT(*) FROM public.library_members WHERE school_id = p_school_id AND status = 'ACTIVE' AND archived_at IS NULL), 0),
        'new_this_month', COALESCE((SELECT COUNT(*) FROM public.library_members WHERE school_id = p_school_id AND archived_at IS NULL AND created_at >= date_trunc('month', CURRENT_DATE)), 0),
        'members_with_books', COALESCE((SELECT COUNT(*) FROM public.library_members WHERE school_id = p_school_id AND archived_at IS NULL AND current_borrowed_count > 0), 0),
        'total_outstanding_fine', COALESCE((SELECT SUM(outstanding_fine) FROM public.library_members WHERE school_id = p_school_id AND archived_at IS NULL), 0.0),
        'students_count', COALESCE((SELECT COUNT(*) FROM public.library_members WHERE school_id = p_school_id AND archived_at IS NULL AND membership_type ILIKE '%student%'), 0),
        'teachers_count', COALESCE((SELECT COUNT(*) FROM public.library_members WHERE school_id = p_school_id AND archived_at IS NULL AND membership_type ILIKE '%teacher%'), 0),
        'staff_count', COALESCE((SELECT COUNT(*) FROM public.library_members WHERE school_id = p_school_id AND archived_at IS NULL AND membership_type ILIKE '%staff%'), 0),
        'suspended_count', COALESCE((SELECT COUNT(*) FROM public.library_members WHERE school_id = p_school_id AND archived_at IS NULL AND status = 'SUSPENDED'), 0),
        'inactive_count', COALESCE((SELECT COUNT(*) FROM public.library_members WHERE school_id = p_school_id AND archived_at IS NULL AND status = 'INACTIVE'), 0),
        'expiring_soon_count', COALESCE((SELECT COUNT(*) FROM public.library_members WHERE school_id = p_school_id AND archived_at IS NULL AND membership_expiry_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '30 days')), 0)
    ) INTO v_stats;

    RETURN v_stats;
END;
$$;


-- 2.2 Dynamic Members Filter Options Function
CREATE OR REPLACE FUNCTION public.fn_library_get_member_filter_options(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_types JSONB;
    v_classes JSONB;
    v_departments JSONB;
BEGIN
    -- Membership Types from lookups or members table
    SELECT COALESCE(jsonb_agg(DISTINCT val), '["Student", "Teacher", "Staff", "Librarian", "Special / Research"]'::jsonb) INTO v_types
    FROM (
        SELECT lv.value_name AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code IN ('LIBRARY_MEMBERSHIP_TYPE', 'MEMBERSHIP_TYPE') AND (lv.school_id = p_school_id OR lv.school_id IS NULL)
        UNION
        SELECT DISTINCT membership_type AS val FROM public.library_members WHERE school_id = p_school_id AND membership_type IS NOT NULL AND membership_type != ''
    ) sub;

    -- Distinct Classes
    SELECT COALESCE(jsonb_agg(DISTINCT p.class ORDER BY p.class ASC), '[]'::jsonb) INTO v_classes
    FROM public.profiles p
    WHERE p.school_id = p_school_id AND p.class IS NOT NULL AND p.class != '';

    -- Distinct Departments
    SELECT COALESCE(jsonb_agg(DISTINCT p.department ORDER BY p.department ASC), '[]'::jsonb) INTO v_departments
    FROM public.profiles p
    WHERE p.school_id = p_school_id AND p.department IS NOT NULL AND p.department != '';

    RETURN jsonb_build_object(
        'member_types', v_types,
        'classes', v_classes,
        'departments', v_departments,
        'statuses', '["ACTIVE", "INACTIVE", "SUSPENDED", "EXPIRED", "EXPIRING_SOON"]'::jsonb
    );
END;
$$;


-- 2.3 Live Search Existing Profiles for Add Member Dialog
CREATE OR REPLACE FUNCTION public.fn_library_search_profiles_for_member(
    p_school_id UUID,
    p_query TEXT DEFAULT NULL,
    p_role TEXT DEFAULT NULL,
    p_limit INT DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_results JSONB;
    v_where TEXT := 'p.school_id = $1';
    v_sql TEXT;
BEGIN
    IF p_role IS NOT NULL AND TRIM(p_role) != '' AND UPPER(p_role) != 'ALL' THEN
        v_where := v_where || format(' AND p.role ILIKE %L', '%' || TRIM(p_role) || '%');
    END IF;

    IF p_query IS NOT NULL AND TRIM(p_query) != '' THEN
        v_where := v_where || format(' AND (p.full_name ILIKE %L OR p.email ILIKE %L OR p.phone ILIKE %L OR p.admission_number ILIKE %L OR p.employee_id ILIKE %L)',
            '%' || TRIM(p_query) || '%',
            '%' || TRIM(p_query) || '%',
            '%' || TRIM(p_query) || '%',
            '%' || TRIM(p_query) || '%',
            '%' || TRIM(p_query) || '%'
        );
    END IF;

    v_sql := format(
        'SELECT COALESCE(jsonb_agg(row_to_json(t)), ''[]''::jsonb)
         FROM (
             SELECT
                 p.id,
                 p.full_name,
                 p.email,
                 p.phone,
                 p.role,
                 p.class,
                 p.department,
                 p.admission_number,
                 p.employee_id,
                 p.avatar_url,
                 (m.id IS NOT NULL) AS is_already_member,
                 m.id AS existing_member_id,
                 m.member_code AS existing_member_code,
                 m.status AS existing_member_status
             FROM public.profiles p
             LEFT JOIN public.library_members m ON p.id = m.profile_id AND m.school_id = p.school_id AND m.archived_at IS NULL
             WHERE %s
             ORDER BY is_already_member ASC, p.full_name ASC
             LIMIT %s
         ) t',
        v_where,
        p_limit
    );

    EXECUTE v_sql USING p_school_id INTO v_results;
    RETURN v_results;
END;
$$;


-- 2.4 Super-Fast Multi-Filtered Paginated Members List Function
CREATE OR REPLACE FUNCTION public.fn_library_list_members(
    p_school_id UUID,
    p_search TEXT DEFAULT NULL,
    p_member_type TEXT DEFAULT NULL,
    p_class_name TEXT DEFAULT NULL,
    p_department TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_membership_filter TEXT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'member_code',
    p_sort_order TEXT DEFAULT 'ASC',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT;
    v_total INT;
    v_items JSONB;
    v_total_pages INT;
    v_sql TEXT;
    v_where TEXT := 'm.school_id = $1 AND m.archived_at IS NULL';
    v_order_col TEXT;
    v_order_dir TEXT;
BEGIN
    v_offset := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);

    -- Search filter
    IF p_search IS NOT NULL AND TRIM(p_search) != '' THEN
        v_where := v_where || format(' AND (m.member_code ILIKE %L OR p.full_name ILIKE %L OR p.email ILIKE %L OR p.phone ILIKE %L OR p.admission_number ILIKE %L OR p.employee_id ILIKE %L)',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%'
        );
    END IF;

    -- Member Type
    IF p_member_type IS NOT NULL AND TRIM(p_member_type) != '' AND UPPER(p_member_type) != 'ALL' AND UPPER(p_member_type) != 'ALL MEMBER TYPES' THEN
        v_where := v_where || format(' AND (m.membership_type ILIKE %L)', '%' || TRIM(p_member_type) || '%');
    END IF;

    -- Class
    IF p_class_name IS NOT NULL AND TRIM(p_class_name) != '' AND UPPER(p_class_name) != 'ALL' AND UPPER(p_class_name) != 'ALL CLASSES' THEN
        v_where := v_where || format(' AND (p.class ILIKE %L)', '%' || TRIM(p_class_name) || '%');
    END IF;

    -- Department
    IF p_department IS NOT NULL AND TRIM(p_department) != '' AND UPPER(p_department) != 'ALL' AND UPPER(p_department) != 'ALL DEPARTMENTS' THEN
        v_where := v_where || format(' AND (p.department ILIKE %L)', '%' || TRIM(p_department) || '%');
    END IF;

    -- Status
    IF p_status IS NOT NULL AND TRIM(p_status) != '' AND UPPER(p_status) != 'ALL' AND UPPER(p_status) != 'STATUS: ALL' THEN
        IF UPPER(p_status) = 'EXPIRED' THEN
            v_where := v_where || ' AND (m.status = ''EXPIRED'' OR (m.membership_expiry_date IS NOT NULL AND m.membership_expiry_date < CURRENT_DATE))';
        ELSIF UPPER(p_status) = 'EXPIRING_SOON' THEN
            v_where := v_where || ' AND (m.membership_expiry_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL ''30 days''))';
        ELSE
            v_where := v_where || format(' AND m.status = %L', UPPER(p_status));
        END IF;
    END IF;

    -- Membership specialized filter
    IF p_membership_filter IS NOT NULL AND TRIM(p_membership_filter) != '' AND UPPER(p_membership_filter) != 'ALL' AND UPPER(p_membership_filter) != 'MEMBERSHIP: ALL' THEN
        IF UPPER(p_membership_filter) = 'HAS_ACTIVE_BOOKS' THEN
            v_where := v_where || ' AND m.current_borrowed_count > 0';
        ELSIF UPPER(p_membership_filter) = 'HAS_OVERDUE' THEN
            v_where := v_where || ' AND EXISTS (SELECT 1 FROM public.library_borrows br WHERE br.member_id = m.id AND br.due_date < CURRENT_DATE AND br.status = ''ISSUED'')';
        ELSIF UPPER(p_membership_filter) = 'HAS_FINES' THEN
            v_where := v_where || ' AND m.outstanding_fine > 0';
        END IF;
    END IF;

    -- Sort column map
    CASE LOWER(COALESCE(p_sort_by, 'member_code'))
        WHEN 'member_name' THEN v_order_col := 'p.full_name';
        WHEN 'member_type' THEN v_order_col := 'm.membership_type';
        WHEN 'class' THEN v_order_col := 'p.class';
        WHEN 'books_issued' THEN v_order_col := 'm.current_borrowed_count';
        WHEN 'outstanding_fine' THEN v_order_col := 'm.outstanding_fine';
        WHEN 'membership_expiry_date' THEN v_order_col := 'm.membership_expiry_date';
        WHEN 'status' THEN v_order_col := 'm.status';
        WHEN 'created_at' THEN v_order_col := 'm.created_at';
        ELSE v_order_col := 'm.member_code';
    END CASE;

    IF LOWER(COALESCE(p_sort_order, 'asc')) = 'desc' THEN
        v_order_dir := 'DESC';
    ELSE
        v_order_dir := 'ASC';
    END IF;

    -- 1. Get Count
    EXECUTE 'SELECT COUNT(*) FROM public.library_members m JOIN public.profiles p ON m.profile_id = p.id WHERE ' || v_where
    USING p_school_id
    INTO v_total;

    v_total_pages := GREATEST(CEIL(v_total::NUMERIC / GREATEST(p_page_size, 1)), 1);

    -- 2. Get Paginated Items as JSONB
    v_sql := format(
        'SELECT COALESCE(jsonb_agg(row_to_json(t)), ''[]''::jsonb)
         FROM (
             SELECT
                 m.id,
                 m.school_id,
                 m.profile_id,
                 m.member_code,
                 m.membership_type,
                 m.membership_start_date,
                 m.membership_expiry_date,
                 m.borrowing_limit,
                 m.max_issue_duration_days,
                 m.renewal_allowed,
                 m.max_renewals,
                 m.current_borrowed_count,
                 m.total_borrowed_count,
                 m.outstanding_fine,
                 m.status,
                 m.notes,
                 m.created_at,
                 m.updated_at,
                 p.full_name AS member_name,
                 p.email,
                 p.phone,
                 p.role,
                 p.class AS class_name,
                 p.department,
                 p.admission_number,
                 p.employee_id,
                 p.avatar_url,
                 (SELECT COUNT(*) FROM public.library_borrows br WHERE br.member_id = m.id AND br.due_date < CURRENT_DATE AND br.status = ''ISSUED'') AS overdue_count
             FROM public.library_members m
             JOIN public.profiles p ON m.profile_id = p.id
             WHERE %s
             ORDER BY %s %s, m.id ASC
             LIMIT %s OFFSET %s
         ) t',
        v_where,
        v_order_col,
        v_order_dir,
        p_page_size,
        v_offset
    );

    EXECUTE v_sql USING p_school_id INTO v_items;

    RETURN jsonb_build_object(
        'items', v_items,
        'meta', jsonb_build_object(
            'page', p_page,
            'page_size', p_page_size,
            'total', v_total,
            'total_items', v_total,
            'total_pages', v_total_pages,
            'pages', v_total_pages
        )
    );
END;
$$;


-- 2.5 Single-Trip Member Detail Function (Member + Issued Books + Fines + Audits + History)
CREATE OR REPLACE FUNCTION public.fn_library_get_member_detail(
    p_school_id UUID,
    p_member_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_member JSONB;
    v_current_books JSONB;
    v_fines JSONB;
    v_history JSONB;
    v_audits JSONB;
    v_summary JSONB;
BEGIN
    -- 1. Member Profile & Parameters
    SELECT jsonb_build_object(
        'id', m.id,
        'school_id', m.school_id,
        'profile_id', m.profile_id,
        'member_code', m.member_code,
        'membership_type', m.membership_type,
        'membership_start_date', m.membership_start_date,
        'membership_expiry_date', m.membership_expiry_date,
        'borrowing_limit', m.borrowing_limit,
        'max_issue_duration_days', m.max_issue_duration_days,
        'renewal_allowed', m.renewal_allowed,
        'max_renewals', m.max_renewals,
        'current_borrowed_count', m.current_borrowed_count,
        'total_borrowed_count', m.total_borrowed_count,
        'outstanding_fine', m.outstanding_fine,
        'status', m.status,
        'notes', m.notes,
        'created_at', m.created_at,
        'updated_at', m.updated_at,
        'member_name', p.full_name,
        'full_name', p.full_name,
        'email', p.email,
        'phone', p.phone,
        'role', p.role,
        'class_name', p.class,
        'department', p.department,
        'admission_number', p.admission_number,
        'employee_id', p.employee_id,
        'avatar_url', p.avatar_url
    ) INTO v_member
    FROM public.library_members m
    JOIN public.profiles p ON m.profile_id = p.id
    WHERE m.id = p_member_id AND m.school_id = p_school_id AND m.archived_at IS NULL;

    IF v_member IS NULL THEN
        RETURN NULL;
    END IF;

    -- 2. Currently Issued Books
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'borrow_id', br.id,
            'book_id', br.book_id,
            'copy_id', br.copy_id,
            'title', b.title,
            'author', b.author,
            'cover_url', b.cover_url,
            'isbn13', b.isbn13,
            'accession_number', c.accession_number,
            'barcode', c.barcode,
            'location', c.location,
            'issue_date', br.issue_date,
            'due_date', br.due_date,
            'status', br.status,
            'fine_amount', br.fine_amount,
            'is_overdue', (br.due_date < CURRENT_DATE),
            'days_overdue', GREATEST(0, (CURRENT_DATE - br.due_date))
        ) ORDER BY br.issue_date DESC
    ), '[]'::jsonb) INTO v_current_books
    FROM public.library_borrows br
    JOIN public.library_books b ON br.book_id = b.id
    LEFT JOIN public.library_book_copies c ON br.copy_id = c.id
    WHERE br.member_id = p_member_id AND br.school_id = p_school_id AND br.status = 'ISSUED';

    -- 3. Itemized Fines
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', f.id,
            'amount', f.amount,
            'paid_amount', f.paid_amount,
            'waived_amount', f.waived_amount,
            'outstanding_amount', (f.amount - f.paid_amount - f.waived_amount),
            'reason', f.reason,
            'status', f.status,
            'created_at', f.created_at,
            'book_title', b.title,
            'issue_date', br.issue_date,
            'due_date', br.due_date
        ) ORDER BY f.created_at DESC
    ), '[]'::jsonb) INTO v_fines
    FROM public.library_fines f
    LEFT JOIN public.library_borrows br ON f.borrow_id = br.id
    LEFT JOIN public.library_books b ON br.book_id = b.id
    WHERE f.member_id = p_member_id AND f.school_id = p_school_id;

    -- 4. Borrowing History
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'borrow_id', br.id,
            'book_id', br.book_id,
            'copy_id', br.copy_id,
            'title', b.title,
            'author', b.author,
            'cover_url', b.cover_url,
            'accession_number', c.accession_number,
            'barcode', c.barcode,
            'issue_date', br.issue_date,
            'due_date', br.due_date,
            'return_date', br.return_date,
            'status', br.status,
            'fine_amount', br.fine_amount
        ) ORDER BY br.issue_date DESC
    ), '[]'::jsonb) INTO v_history
    FROM public.library_borrows br
    JOIN public.library_books b ON br.book_id = b.id
    LEFT JOIN public.library_book_copies c ON br.copy_id = c.id
    WHERE br.member_id = p_member_id AND br.school_id = p_school_id AND br.status != 'ISSUED';

    -- 5. Audit logs
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', a.id,
            'action_type', a.action_type,
            'description', a.description,
            'created_at', a.created_at,
            'performed_by_name', p_performer.full_name
        ) ORDER BY a.created_at DESC
    ), '[]'::jsonb) INTO v_audits
    FROM public.library_member_audits a
    LEFT JOIN public.profiles p_performer ON a.performed_by = p_performer.id
    WHERE a.member_id = p_member_id AND a.school_id = p_school_id;

    -- 6. Summary metrics
    v_summary := jsonb_build_object(
        'current_issued_count', jsonb_array_length(v_current_books),
        'total_overdue_count', (SELECT COUNT(*) FROM jsonb_array_elements(v_current_books) elem WHERE (elem->>'is_overdue')::boolean = true),
        'total_fines_unpaid', COALESCE((SELECT SUM((f->>'outstanding_amount')::numeric) FROM jsonb_array_elements(v_fines) f), 0.0),
        'total_history_count', jsonb_array_length(v_history)
    );

    RETURN jsonb_build_object(
        'member', v_member,
        'current_books', v_current_books,
        'fines', v_fines,
        'history', v_history,
        'audits', v_audits,
        'summary', v_summary
    );
END;
$$;


-- 2.6 Atomic Member Creation Stored Function
CREATE OR REPLACE FUNCTION public.fn_library_create_member(
    p_school_id UUID,
    p_user_id UUID,
    p_profile_id UUID,
    p_member_code TEXT DEFAULT NULL,
    p_membership_type TEXT DEFAULT 'Student',
    p_membership_type_id UUID DEFAULT NULL,
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_expiry_date DATE DEFAULT NULL,
    p_borrowing_limit INT DEFAULT 3,
    p_max_issue_duration_days INT DEFAULT 14,
    p_renewal_allowed BOOLEAN DEFAULT TRUE,
    p_max_renewals INT DEFAULT 2,
    p_status TEXT DEFAULT 'ACTIVE',
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile RECORD;
    v_existing_id UUID;
    v_existing_code TEXT;
    v_code TEXT := p_member_code;
    v_expiry DATE := p_expiry_date;
    v_member_id UUID;
    v_max_num INT;
BEGIN
    -- 1. Check profile exists
    SELECT id, full_name, role INTO v_profile
    FROM public.profiles
    WHERE id = p_profile_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Selected profile does not exist in this institution.';
    END IF;

    -- 2. Check no active membership exists
    SELECT id, member_code INTO v_existing_id, v_existing_code
    FROM public.library_members
    WHERE profile_id = p_profile_id AND school_id = p_school_id AND archived_at IS NULL;

    IF FOUND THEN
        RAISE EXCEPTION 'This user already has an active library membership (%).', v_existing_code;
    END IF;

    -- 3. Auto-generate sequential code if empty
    IF v_code IS NULL OR TRIM(v_code) = '' THEN
        SELECT COALESCE(MAX(NULLIF(regexp_replace(member_code, '\D', '', 'g'), '')::integer), 0)
        INTO v_max_num
        FROM public.library_members
        WHERE school_id = p_school_id AND member_code ~ '^LIBM-\d+$';

        v_code := format('LIBM-%s', lpad((v_max_num + 1)::text, 4, '0'));
    END IF;

    -- 4. Default 1-year expiry
    IF v_expiry IS NULL THEN
        v_expiry := p_start_date + INTERVAL '1 year';
    END IF;

    -- 5. Insert Member
    INSERT INTO public.library_members (
        school_id, profile_id, member_code, membership_type, membership_type_id,
        membership_start_date, membership_expiry_date, borrowing_limit,
        max_issue_duration_days, renewal_allowed, max_renewals, status, notes,
        created_by, updated_by
    ) VALUES (
        p_school_id, p_profile_id, v_code, p_membership_type, p_membership_type_id,
        p_start_date, v_expiry, p_borrowing_limit,
        p_max_issue_duration_days, p_renewal_allowed, p_max_renewals, p_status, p_notes,
        p_user_id, p_user_id
    )
    RETURNING id INTO v_member_id;

    -- 6. Audit Log
    INSERT INTO public.library_member_audits (
        school_id, member_id, action_type, description, performed_by
    ) VALUES (
        p_school_id, v_member_id, 'CREATED', format('Library membership created with code %s', v_code), p_user_id
    );

    RETURN jsonb_build_object(
        'success', true,
        'member_id', v_member_id,
        'member_code', v_code,
        'message', format('Library member created successfully (%s).', v_code)
    );
END;
$$;


-- 2.7 Atomic Member Renewal Function
CREATE OR REPLACE FUNCTION public.fn_library_renew_membership(
    p_school_id UUID,
    p_member_id UUID,
    p_user_id UUID,
    p_new_expiry DATE,
    p_renewal_period TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_member RECORD;
    v_desc TEXT;
BEGIN
    SELECT id, member_code, membership_expiry_date, status INTO v_member
    FROM public.library_members
    WHERE id = p_member_id AND school_id = p_school_id AND archived_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Library member not found.';
    END IF;

    UPDATE public.library_members
    SET membership_expiry_date = p_new_expiry,
        status = 'ACTIVE',
        suspension_reason = NULL,
        suspended_at = NULL,
        suspended_by = NULL,
        notes = CASE WHEN p_notes IS NOT NULL AND TRIM(p_notes) != '' THEN p_notes ELSE notes END,
        updated_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_member_id AND school_id = p_school_id;

    v_desc := format('Membership renewed till %s (Prior expiry: %s)', p_new_expiry, v_member.membership_expiry_date);
    IF p_notes IS NOT NULL AND TRIM(p_notes) != '' THEN
        v_desc := v_desc || format('. Note: %s', p_notes);
    END IF;

    INSERT INTO public.library_member_audits (
        school_id, member_id, action_type, description, performed_by
    ) VALUES (
        p_school_id, p_member_id, 'RENEWED', v_desc, p_user_id
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', format('Membership renewed successfully till %s.', p_new_expiry),
        'new_expiry_date', p_new_expiry
    );
END;
$$;


-- 2.8 Atomic Member Suspension Function
CREATE OR REPLACE FUNCTION public.fn_library_suspend_member(
    p_school_id UUID,
    p_member_id UUID,
    p_user_id UUID,
    p_reason TEXT DEFAULT 'Administrative suspension'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.library_members WHERE id = p_member_id AND school_id = p_school_id AND archived_at IS NULL) THEN
        RAISE EXCEPTION 'Library member not found.';
    END IF;

    UPDATE public.library_members
    SET status = 'SUSPENDED',
        suspension_reason = p_reason,
        suspended_at = NOW(),
        suspended_by = p_user_id,
        updated_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_member_id AND school_id = p_school_id;

    INSERT INTO public.library_member_audits (
        school_id, member_id, action_type, description, performed_by
    ) VALUES (
        p_school_id, p_member_id, 'SUSPENDED', format('Membership suspended. Reason: %s', p_reason), p_user_id
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Member suspended successfully.'
    );
END;
$$;


-- 2.9 Atomic Member Reactivation Function
CREATE OR REPLACE FUNCTION public.fn_library_activate_member(
    p_school_id UUID,
    p_member_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.library_members WHERE id = p_member_id AND school_id = p_school_id AND archived_at IS NULL) THEN
        RAISE EXCEPTION 'Library member not found.';
    END IF;

    UPDATE public.library_members
    SET status = 'ACTIVE',
        suspension_reason = NULL,
        suspended_at = NULL,
        suspended_by = NULL,
        updated_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_member_id AND school_id = p_school_id;

    INSERT INTO public.library_member_audits (
        school_id, member_id, action_type, description, performed_by
    ) VALUES (
        p_school_id, p_member_id, 'ACTIVATED', 'Membership reactivated to ACTIVE status.', p_user_id
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Member reactivated successfully.'
    );
END;
$$;


-- 2.10 Atomic Member Soft-Deletion with Active Books Check
CREATE OR REPLACE FUNCTION public.fn_library_delete_member(
    p_school_id UUID,
    p_member_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_issued INT;
    v_code TEXT;
BEGIN
    SELECT current_borrowed_count, member_code INTO v_issued, v_code
    FROM public.library_members
    WHERE id = p_member_id AND school_id = p_school_id AND archived_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Library member not found.';
    END IF;

    IF v_issued > 0 THEN
        RAISE EXCEPTION 'Cannot delete member % with % active issued book(s). Return all books first.', v_code, v_issued;
    END IF;

    UPDATE public.library_members
    SET archived_at = NOW(),
        status = 'INACTIVE',
        updated_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_member_id AND school_id = p_school_id;

    INSERT INTO public.library_member_audits (
        school_id, member_id, action_type, description, performed_by
    ) VALUES (
        p_school_id, p_member_id, 'ARCHIVED', format('Library member %s archived.', v_code), p_user_id
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', format('Library member %s archived successfully.', v_code)
    );
END;
$$;
