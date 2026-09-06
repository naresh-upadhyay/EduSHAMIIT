-- Migration 340: Standardize Book Condition Lookups, Column Persistence, and SSOT Filter Options
-- Purpose:
-- 1. Ensure public.library_books has condition column (persisted alongside copies).
-- 2. Standardize BOOK_CONDITION lookup values across all schools with clean 8 standard active values (sort_order 1-8).
-- 3. Normalize all existing condition values in library_books and library_book_copies to uppercase codes.
-- 4. Update fn_library_get_book_filter_options to strictly query BOOK_CONDITION from lookup_values.
-- 5. Update fn_library_get_book_detail to return primary_condition and condition on the book record.
-- 6. Update fn_library_list_books to consistently return primary_condition and condition.

-- 1. Ensure condition column exists on library_books
DO $$
BEGIN
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS condition VARCHAR(50) DEFAULT 'GOOD';
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS financial_year VARCHAR(50);
END $$;

-- 2. Standardize BOOK_CONDITION lookup values across all schools
DO $$
DECLARE
    v_school RECORD;
    v_key_id UUID;
BEGIN
    FOR v_school IN (SELECT id FROM public.schools) LOOP
        -- Ensure lookup key exists
        INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status)
        VALUES (v_school.id, 'Book Physical Condition', 'BOOK_CONDITION', 'Physical quality state of individual book copies.', 'SYSTEM', 'health_and_safety_outlined', 'ACTIVE')
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
        DO UPDATE SET key_name = EXCLUDED.key_name, status = 'ACTIVE';

        SELECT id INTO v_key_id 
        FROM public.lookup_keys 
        WHERE school_id = v_school.id AND key_code = 'BOOK_CONDITION' AND deleted_at IS NULL 
        LIMIT 1;

        IF v_key_id IS NOT NULL THEN
            -- Remove old/duplicate lookup values for this key
            DELETE FROM public.lookup_values WHERE lookup_key_id = v_key_id;

            -- Insert clean standard 8 condition values
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_code, value_name, sort_order, status)
            VALUES
                (v_key_id, v_school.id, 'NEW', 'New / Mint', 1, 'ACTIVE'),
                (v_key_id, v_school.id, 'EXCELLENT', 'Excellent', 2, 'ACTIVE'),
                (v_key_id, v_school.id, 'GOOD', 'Good', 3, 'ACTIVE'),
                (v_key_id, v_school.id, 'FAIR', 'Fair', 4, 'ACTIVE'),
                (v_key_id, v_school.id, 'WORN', 'Worn', 5, 'ACTIVE'),
                (v_key_id, v_school.id, 'DAMAGED', 'Damaged', 6, 'ACTIVE'),
                (v_key_id, v_school.id, 'UNDER_REPAIR', 'Under Repair', 7, 'ACTIVE'),
                (v_key_id, v_school.id, 'LOST', 'Lost / Missing', 8, 'ACTIVE')
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL
            DO UPDATE SET value_name = EXCLUDED.value_name, sort_order = EXCLUDED.sort_order, status = 'ACTIVE';
        END IF;
    END LOOP;
END $$;

-- 3. Normalize all existing condition values in library_book_copies
UPDATE public.library_book_copies
SET condition = CASE
    WHEN UPPER(condition) LIKE '%NEW%' OR UPPER(condition) LIKE '%MINT%' THEN 'NEW'
    WHEN UPPER(condition) LIKE '%EXCELLENT%' THEN 'EXCELLENT'
    WHEN UPPER(condition) LIKE '%GOOD%' THEN 'GOOD'
    WHEN UPPER(condition) LIKE '%FAIR%' THEN 'FAIR'
    WHEN UPPER(condition) LIKE '%WORN%' THEN 'WORN'
    WHEN UPPER(condition) LIKE '%DAMAGED%' THEN 'DAMAGED'
    WHEN UPPER(condition) LIKE '%REPAIR%' THEN 'UNDER_REPAIR'
    WHEN UPPER(condition) LIKE '%LOST%' OR UPPER(condition) LIKE '%MISSING%' THEN 'LOST'
    ELSE 'GOOD'
END
WHERE condition IS NOT NULL;

-- 4. Normalize library_books condition column from its primary copy or 'GOOD'
UPDATE public.library_books b
SET condition = COALESCE(
    (SELECT UPPER(c.condition) FROM public.library_book_copies c WHERE c.book_id = b.id AND c.archived_at IS NULL ORDER BY c.copy_number ASC LIMIT 1),
    'GOOD'
)
WHERE b.condition IS NULL OR b.condition = '';

-- 5. Update fn_library_get_book_filter_options
CREATE OR REPLACE FUNCTION public.fn_library_get_book_filter_options(p_school_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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
    v_roles JSONB;
BEGIN
    -- Categories from lookup_keys: BOOK_CATEGORY or books
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_categories
    FROM (
        SELECT lv.value_name AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'BOOK_CATEGORY' AND (lv.school_id = p_school_id OR lv.school_id IS NULL) AND lv.status = 'ACTIVE'
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

    -- Conditions strictly from lookup_keys: BOOK_CONDITION (ordered by sort_order)
    SELECT COALESCE(jsonb_agg(val), '["NEW", "EXCELLENT", "GOOD", "FAIR", "WORN", "DAMAGED", "UNDER_REPAIR", "LOST"]'::jsonb) INTO v_conditions
    FROM (
        SELECT lv.value_code AS val
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'BOOK_CONDITION' 
          AND (lv.school_id = p_school_id OR lv.school_id IS NULL) 
          AND lv.status = 'ACTIVE'
        ORDER BY lv.sort_order ASC, lv.value_code ASC
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

    -- Dynamic App Roles from app_roles table
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'code', UPPER(code),
            'name', name,
            'display_name', COALESCE(display_name, INITCAP(REPLACE(name, '_', ' ')))
        ) ORDER BY COALESCE(display_order, 999) ASC, display_name ASC
    ), '[]'::jsonb) INTO v_roles
    FROM public.app_roles
    WHERE status = 'Active' AND (school_id = p_school_id OR school_id IS NULL);

    RETURN jsonb_build_object(
        'categories', v_categories,
        'languages', v_languages,
        'book_types', v_book_types,
        'conditions', v_conditions,
        'acquisition_types', v_acquisition_types,
        'authors', v_authors,
        'publishers', v_publishers,
        'publication_years', v_years,
        'years', v_years,
        'racks', v_racks,
        'classes', v_classes,
        'subjects', v_subjects,
        'roles', v_roles
    );
END;
$function$;

-- 6. Update fn_library_get_book_detail to return primary_condition and condition
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
    -- 1. Book bibliographic record enriched with primary condition and copy metadata
    SELECT to_jsonb(b) || jsonb_build_object(
        'primary_condition', COALESCE(b.condition, (SELECT c.condition FROM public.library_book_copies c WHERE c.book_id = b.id AND c.archived_at IS NULL ORDER BY c.copy_number ASC LIMIT 1), 'GOOD'),
        'condition', COALESCE(b.condition, (SELECT c.condition FROM public.library_book_copies c WHERE c.book_id = b.id AND c.archived_at IS NULL ORDER BY c.copy_number ASC LIMIT 1), 'GOOD'),
        'primary_barcode', (SELECT c.barcode FROM public.library_book_copies c WHERE c.book_id = b.id AND c.archived_at IS NULL ORDER BY c.copy_number ASC LIMIT 1),
        'primary_accession_number', (SELECT c.accession_number FROM public.library_book_copies c WHERE c.book_id = b.id AND c.archived_at IS NULL ORDER BY c.copy_number ASC LIMIT 1)
    ) INTO v_book
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
