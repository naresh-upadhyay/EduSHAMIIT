-- Migration 337: Remove ACADEMIC_YEAR lookup key, standardize FINANCIAL_YEAR, and enforce strict lookup SSOT
-- Purpose: 
-- 1. Remove duplicate ACADEMIC_YEAR lookup keys and duplicate lookup values across all schools.
-- 2. Standardize FINANCIAL_YEAR with the clean 7 active institutional years (FY_2026_27 to FY_2020_21).
-- 3. Update fn_library_get_book_filter_options to strictly query FINANCIAL_YEAR from lookup_values and dynamic classes/subjects.
-- 4. Ensure fn_library_list_books returns primary_condition and pages.

DO $$
DECLARE
    v_school RECORD;
    v_fy_key_id UUID;
BEGIN
    -- 1. Remove all lookup values belonging to ACADEMIC_YEAR
    DELETE FROM public.lookup_values
    WHERE lookup_key_id IN (
        SELECT id FROM public.lookup_keys WHERE key_code = 'ACADEMIC_YEAR'
    );

    -- 2. Remove all ACADEMIC_YEAR lookup keys
    DELETE FROM public.lookup_keys
    WHERE key_code = 'ACADEMIC_YEAR';

    -- 3. Ensure FINANCIAL_YEAR exists for every school with standard 7 values
    FOR v_school IN (SELECT id FROM public.schools) LOOP
        INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status)
        VALUES (v_school.id, 'Financial Year', 'FINANCIAL_YEAR', 'Fiscal budgeting and institutional procurement years', 'SYSTEM', 'calendar_today', 'ACTIVE')
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO NOTHING;

        SELECT id INTO v_fy_key_id 
        FROM public.lookup_keys 
        WHERE school_id = v_school.id AND key_code = 'FINANCIAL_YEAR' AND deleted_at IS NULL 
        LIMIT 1;

        IF v_fy_key_id IS NOT NULL THEN
            -- Clean duplicate values if any
            DELETE FROM public.lookup_values lv1
            WHERE lookup_key_id = v_fy_key_id
              AND id NOT IN (
                  SELECT id FROM (
                      SELECT DISTINCT ON (value_name) id
                      FROM public.lookup_values
                      WHERE lookup_key_id = v_fy_key_id
                      ORDER BY value_name, sort_order ASC
                  ) sub
              );

            -- Ensure the 7 standard financial years exist with active status
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_code, value_name, sort_order, status)
            VALUES
                (v_fy_key_id, v_school.id, 'FY_2026_27', '2026-27', 1, 'ACTIVE'),
                (v_fy_key_id, v_school.id, 'FY_2025_26', '2025-26', 2, 'ACTIVE'),
                (v_fy_key_id, v_school.id, 'FY_2024_25', '2024-25', 3, 'ACTIVE'),
                (v_fy_key_id, v_school.id, 'FY_2023_24', '2023-24', 4, 'ACTIVE'),
                (v_fy_key_id, v_school.id, 'FY_2022_23', '2022-23', 5, 'ACTIVE'),
                (v_fy_key_id, v_school.id, 'FY_2021_22', '2021-22', 6, 'ACTIVE'),
                (v_fy_key_id, v_school.id, 'FY_2020_21', '2020-21', 7, 'ACTIVE')
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL
            DO UPDATE SET value_name = EXCLUDED.value_name, sort_order = EXCLUDED.sort_order, status = 'ACTIVE';
        END IF;
    END LOOP;
END $$;

-- 4. Update fn_library_get_book_filter_options to strictly query FINANCIAL_YEAR and dynamic Class/Subject lookups
CREATE OR REPLACE FUNCTION public.fn_library_get_book_filter_options(p_school_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
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
    v_classes JSONB;
    v_subjects JSONB;
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
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_languages
    FROM (
        SELECT lv.value_name AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'BOOK_LANGUAGE' AND (lv.school_id = p_school_id OR lv.school_id IS NULL) AND lv.status = 'ACTIVE'
        UNION
        SELECT DISTINCT language_name AS val FROM public.library_books WHERE school_id = p_school_id AND language_name IS NOT NULL AND language_name != ''
    ) sub;

    -- Book Types / Formats from lookup_keys: BOOK_TYPE or books
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_book_types
    FROM (
        SELECT lv.value_name AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'BOOK_TYPE' AND (lv.school_id = p_school_id OR lv.school_id IS NULL) AND lv.status = 'ACTIVE'
        UNION
        SELECT DISTINCT book_type_name AS val FROM public.library_books WHERE school_id = p_school_id AND book_type_name IS NOT NULL AND book_type_name != ''
    ) sub;

    -- Conditions from lookup_keys: BOOK_CONDITION
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_conditions
    FROM (
        SELECT lv.value_code AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'BOOK_CONDITION' AND (lv.school_id = p_school_id OR lv.school_id IS NULL) AND lv.status = 'ACTIVE'
        UNION
        SELECT DISTINCT condition AS val FROM public.library_book_copies WHERE school_id = p_school_id AND condition IS NOT NULL AND condition != ''
    ) sub;

    -- Acquisition Types from lookup_keys: ACQUISITION_TYPE
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_acquisition_types
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

    -- Classes from Class Management (academic_classes and classes)
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_classes
    FROM (
        SELECT name AS val FROM public.academic_classes WHERE school_id = p_school_id AND status = 'ACTIVE' AND deleted_at IS NULL
        UNION
        SELECT name AS val FROM public.classes WHERE school_id = p_school_id
    ) sub_c;

    -- Subjects from Class Management (academic_subjects and subjects)
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_subjects
    FROM (
        SELECT name AS val FROM public.academic_subjects WHERE school_id = p_school_id AND status = 'ACTIVE' AND deleted_at IS NULL
        UNION
        SELECT name AS val FROM public.subjects WHERE school_id = p_school_id
    ) sub_s;

    RETURN jsonb_build_object(
        'categories', v_categories,
        'languages', v_languages,
        'book_types', v_book_types,
        'conditions', v_conditions,
        'acquisition_types', v_acquisition_types,
        'authors', v_authors,
        'publishers', v_publishers,
        'publication_years', v_years,
        'racks', v_racks,
        'classes', v_classes,
        'subjects', v_subjects
    );
END;
$function$;

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
    v_clean_type TEXT;
BEGIN
    v_offset := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);

    -- Status condition
    IF UPPER(COALESCE(p_status, 'ACTIVE')) = 'ARCHIVED' THEN
        v_where := v_where || ' AND b.archived_at IS NOT NULL';
    ELSIF UPPER(COALESCE(p_status, 'ACTIVE')) = 'ACTIVE' THEN
        v_where := v_where || ' AND b.archived_at IS NULL';
    END IF;

    -- Search filter
    IF p_search IS NOT NULL AND TRIM(p_search) != '' THEN
        v_where := v_where || format(' AND (b.title ILIKE %L OR b.subtitle ILIKE %L OR b.author ILIKE %L OR b.isbn13 ILIKE %L OR b.isbn10 ILIKE %L OR b.isbn ILIKE %L OR b.subject ILIKE %L OR b.description ILIKE %L OR EXISTS (SELECT 1 FROM public.library_book_copies c WHERE c.book_id = b.id AND (c.barcode ILIKE %L OR c.accession_number ILIKE %L)))',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%',
            '%' || TRIM(p_search) || '%',
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

    -- Book Type / Digital Format filter
    IF p_book_type IS NOT NULL AND TRIM(p_book_type) != '' AND UPPER(p_book_type) != 'ALL' THEN
        v_clean_type := UPPER(TRIM(p_book_type));
        IF v_clean_type = 'DIGITAL' OR v_clean_type = 'ALL DIGITAL' THEN
            v_where := v_where || ' AND (b.is_digital = TRUE OR EXISTS (SELECT 1 FROM public.library_digital_files df WHERE df.book_id = b.id))';
        ELSIF v_clean_type = 'PHYSICAL' OR v_clean_type = 'PHYSICAL BOOK' OR v_clean_type = 'PHYSICAL BOOKS' THEN
            v_where := v_where || ' AND (b.is_digital IS NOT TRUE OR b.book_type_name ILIKE ''%Physical%'' OR b.book_type_name ILIKE ''%Paperback%'' OR b.book_type_name ILIKE ''%Hardcover%'')';
        ELSIF v_clean_type = 'EBOOK' OR v_clean_type = 'E-BOOK' OR v_clean_type = 'EBOOKS' OR v_clean_type ILIKE '%EBOOK%' OR v_clean_type ILIKE '%E-BOOK%' THEN
            v_where := v_where || ' AND (b.book_type_name ILIKE ''%E-Book%'' OR b.book_type_name ILIKE ''%eBook%'' OR b.book_type_name ILIKE ''%Digital%'' OR EXISTS (SELECT 1 FROM public.library_digital_files df WHERE df.book_id = b.id AND (df.file_type ILIKE ''%EBOOK%'' OR df.file_type ILIKE ''%PDF%'')))';
        ELSIF v_clean_type = 'AUDIOBOOK' OR v_clean_type = 'AUDIOBOOKS' OR v_clean_type ILIKE '%AUDIO%' THEN
            v_where := v_where || ' AND (b.book_type_name ILIKE ''%Audio%'' OR EXISTS (SELECT 1 FROM public.library_digital_files df WHERE df.book_id = b.id AND df.file_type ILIKE ''%AUDIO%''))';
        ELSIF v_clean_type = 'VIDEOBOOK' OR v_clean_type = 'VIDEOBOOKS' OR v_clean_type = 'VIDEO BOOKS' OR v_clean_type ILIKE '%VIDEO%' THEN
            v_where := v_where || ' AND (b.book_type_name ILIKE ''%Video%'' OR EXISTS (SELECT 1 FROM public.library_digital_files df WHERE df.book_id = b.id AND (df.file_type ILIKE ''%VIDEO%'' OR df.is_live_stream = TRUE)))';
        ELSE
            v_where := v_where || format(' AND (b.book_type_name ILIKE %L)', '%' || TRIM(p_book_type) || '%');
        END IF;
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
        v_where := v_where || ' AND (b.available_copies > 0 OR b.is_digital = TRUE)';
    ELSIF UPPER(p_availability) = 'ISSUED' OR UPPER(p_availability) = 'FULLY_ISSUED' THEN
        v_where := v_where || ' AND b.issued_copies > 0';
    ELSIF UPPER(p_availability) = 'OVERDUE' THEN
        v_where := v_where || ' AND EXISTS (SELECT 1 FROM public.library_book_copies c WHERE c.book_id = b.id AND c.archived_at IS NULL AND (c.status = ''OVERDUE'' OR (c.status = ''ISSUED'' AND c.due_date IS NOT NULL AND c.due_date < CURRENT_DATE)))';
    ELSIF UPPER(p_availability) = 'OUT_OF_STOCK' THEN
        v_where := v_where || ' AND b.available_copies = 0 AND b.is_digital IS NOT TRUE';
    END IF;

    -- Sort column map
    CASE LOWER(COALESCE(p_sort_by, 'title'))
        WHEN 'author' THEN v_order_col := 'b.author';
        WHEN 'category' THEN v_order_col := 'b.category_name';
        WHEN 'publication_year' THEN v_order_col := 'b.publication_year';
        WHEN 'total_copies' THEN v_order_col := 'b.total_copies';
        WHEN 'available_copies' THEN v_order_col := 'b.available_copies';
        WHEN 'rating' THEN v_order_col := 'b.rating';
        WHEN 'reads' THEN v_order_col := 'b.read_count';
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
                 b.preview_url,
                 b.total_copies,
                 b.available_copies,
                 b.issued_copies,
                 b.reserved_copies,
                 b.is_digital,
                 b.digital_visibility,
                 b.access_mode,
                 b.requires_permission,
                 b.allowed_roles,
                 b.allowed_grades,
                 b.allowed_departments,
                 b.default_access_duration_days,
                 b.allow_notes,
                 b.allow_highlights,
                 b.allow_bookmarks,
                 b.allow_copy_text,
                 b.allow_screenshots,
                 b.max_concurrent_devices,
                 b.rating,
                 b.total_reviews,
                 b.view_count,
                 b.read_count,
                 b.listen_count,
                 b.watch_count,
                 b.total_reading_seconds,
                 b.total_listening_seconds,
                 b.total_watching_seconds,
                 b.subject,
                 b.grade_level,
                 b.curriculum,
                 b.difficulty_level,
                 b.age_group,
                 b.published_at,
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
                     SELECT c.condition FROM public.library_book_copies c 
                     WHERE c.book_id = b.id AND c.archived_at IS NULL 
                     ORDER BY c.copy_number ASC LIMIT 1
                 ) AS primary_condition,
                 (
                     SELECT COUNT(*) FROM public.library_book_copies c 
                     WHERE c.book_id = b.id AND c.archived_at IS NULL 
                       AND (c.status = ''OVERDUE'' OR (c.status = ''ISSUED'' AND c.due_date IS NOT NULL AND c.due_date < CURRENT_DATE))
                 ) AS overdue_copies_count,
                 (
                     SELECT COALESCE(jsonb_agg(row_to_json(df)), ''[]''::jsonb)
                     FROM (
                         SELECT * FROM public.library_digital_files 
                         WHERE book_id = b.id 
                         ORDER BY is_primary DESC, sort_order ASC, created_at ASC
                     ) df
                 ) AS digital_files,
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
        GREATEST(p_page_size, 1),
        v_offset
    );

    EXECUTE v_sql
    USING p_school_id
    INTO v_items;

    RETURN jsonb_build_object(
        'items', COALESCE(v_items, '[]'::jsonb),
        'pagination', jsonb_build_object(
            'total', v_total,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', v_total_pages,
            'has_next', p_page < v_total_pages,
            'has_prev', p_page > 1
        )
    );
END;
$$;

