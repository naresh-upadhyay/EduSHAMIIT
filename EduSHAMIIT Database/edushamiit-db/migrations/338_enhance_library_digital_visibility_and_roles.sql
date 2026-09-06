-- Migration 338: Enhance Library Digital Visibility, Dynamic App Roles Integration, and DRM Rules
-- Purpose:
-- 1. Integrate dynamic roles from public.app_roles into fn_library_get_book_filter_options.
-- 2. Standardize digital_visibility options: 'PUBLIC', 'INTERNAL', 'RESTRICTED'.
-- 3. Support allowed_roles, age_group (minimum student age limit), and DRM rules across fn_library_list_books.

-- 1. Standardize existing digital_visibility records
UPDATE public.library_books 
SET digital_visibility = 'INTERNAL' 
WHERE digital_visibility = 'UNLISTED' OR digital_visibility IS NULL;

-- 2. Update fn_library_get_book_filter_options with dynamic app_roles
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
    -- 1. Categories from lookup_keys: BOOK_CATEGORY / LIBRARY_BOOK_CATEGORY ordered by sort_order
    SELECT COALESCE(jsonb_agg(val), '[]'::jsonb) INTO v_categories
    FROM (
        SELECT lv.value_name AS val, MIN(COALESCE(lv.sort_order, 999)) AS min_sort
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code IN ('BOOK_CATEGORY', 'LIBRARY_BOOK_CATEGORY') 
          AND (lv.school_id = p_school_id OR lv.school_id IS NULL) 
          AND UPPER(COALESCE(lv.status, 'ACTIVE')) = 'ACTIVE'
          AND lv.deleted_at IS NULL
          AND UPPER(COALESCE(lk.status, 'ACTIVE')) = 'ACTIVE'
          AND lk.deleted_at IS NULL
        GROUP BY lv.value_name
        ORDER BY min_sort ASC, lv.value_name ASC
    ) sub;

    -- 2. Languages from lookup_keys: BOOK_LANGUAGE ordered by sort_order
    SELECT COALESCE(jsonb_agg(val), '[]'::jsonb) INTO v_languages
    FROM (
        SELECT lv.value_name AS val, MIN(COALESCE(lv.sort_order, 999)) AS min_sort
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'BOOK_LANGUAGE' 
          AND (lv.school_id = p_school_id OR lv.school_id IS NULL) 
          AND UPPER(COALESCE(lv.status, 'ACTIVE')) = 'ACTIVE'
          AND lv.deleted_at IS NULL
          AND UPPER(COALESCE(lk.status, 'ACTIVE')) = 'ACTIVE'
          AND lk.deleted_at IS NULL
        GROUP BY lv.value_name
        ORDER BY min_sort ASC, lv.value_name ASC
    ) sub;

    -- 3. Book Types / Formats from lookup_keys: BOOK_TYPE ordered by sort_order
    SELECT COALESCE(jsonb_agg(val), '[]'::jsonb) INTO v_book_types
    FROM (
        SELECT lv.value_name AS val, MIN(COALESCE(lv.sort_order, 999)) AS min_sort
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'BOOK_TYPE' 
          AND (lv.school_id = p_school_id OR lv.school_id IS NULL) 
          AND UPPER(COALESCE(lv.status, 'ACTIVE')) = 'ACTIVE'
          AND lv.deleted_at IS NULL
          AND UPPER(COALESCE(lk.status, 'ACTIVE')) = 'ACTIVE'
          AND lk.deleted_at IS NULL
        GROUP BY lv.value_name
        ORDER BY min_sort ASC, lv.value_name ASC
    ) sub;

    -- 4. Conditions from lookup_keys: BOOK_CONDITION ordered by sort_order
    SELECT COALESCE(jsonb_agg(val), '[]'::jsonb) INTO v_conditions
    FROM (
        SELECT lv.value_code AS val, MIN(COALESCE(lv.sort_order, 999)) AS min_sort
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'BOOK_CONDITION' 
          AND (lv.school_id = p_school_id OR lv.school_id IS NULL) 
          AND UPPER(COALESCE(lv.status, 'ACTIVE')) = 'ACTIVE'
          AND lv.deleted_at IS NULL
          AND UPPER(COALESCE(lk.status, 'ACTIVE')) = 'ACTIVE'
          AND lk.deleted_at IS NULL
        GROUP BY lv.value_code
        ORDER BY min_sort ASC, lv.value_code ASC
    ) sub;

    -- 5. Acquisition Types from lookup_keys: ACQUISITION_TYPE ordered by sort_order
    SELECT COALESCE(jsonb_agg(val), '[]'::jsonb) INTO v_acquisition_types
    FROM (
        SELECT lv.value_code AS val, MIN(COALESCE(lv.sort_order, 999)) AS min_sort
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'ACQUISITION_TYPE' 
          AND (lv.school_id = p_school_id OR lv.school_id IS NULL) 
          AND UPPER(COALESCE(lv.status, 'ACTIVE')) = 'ACTIVE'
          AND lv.deleted_at IS NULL
          AND UPPER(COALESCE(lk.status, 'ACTIVE')) = 'ACTIVE'
          AND lk.deleted_at IS NULL
        GROUP BY lv.value_code
        ORDER BY min_sort ASC, lv.value_code ASC
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
        SELECT lv.value_name AS val, MIN(COALESCE(lv.sort_order, 999)) AS min_sort
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
        WHERE lk.key_code = 'FINANCIAL_YEAR' 
          AND (lv.school_id = p_school_id OR lv.school_id IS NULL) 
          AND UPPER(COALESCE(lv.status, 'ACTIVE')) = 'ACTIVE'
          AND lv.deleted_at IS NULL
          AND UPPER(COALESCE(lk.status, 'ACTIVE')) = 'ACTIVE'
          AND lk.deleted_at IS NULL
        GROUP BY lv.value_name
        ORDER BY min_sort ASC, lv.value_name DESC
    ) sub;

    -- Racks
    SELECT COALESCE(jsonb_agg(DISTINCT rack_location ORDER BY rack_location ASC), '[]'::jsonb) INTO v_racks
    FROM public.library_books
    WHERE school_id = p_school_id AND rack_location IS NOT NULL AND rack_location != '';

    -- Classes from Class Management (academic_classes and classes)
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_classes
    FROM (
        SELECT name AS val FROM public.academic_classes WHERE school_id = p_school_id AND UPPER(COALESCE(status, 'ACTIVE')) = 'ACTIVE' AND deleted_at IS NULL
        UNION
        SELECT name AS val FROM public.classes WHERE school_id = p_school_id
    ) sub_c;

    -- Subjects from Class Management (academic_subjects and subjects)
    SELECT COALESCE(jsonb_agg(DISTINCT val ORDER BY val ASC), '[]'::jsonb) INTO v_subjects
    FROM (
        SELECT name AS val FROM public.academic_subjects WHERE school_id = p_school_id AND UPPER(COALESCE(status, 'ACTIVE')) = 'ACTIVE' AND deleted_at IS NULL
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
    WHERE UPPER(COALESCE(status, 'ACTIVE')) = 'ACTIVE' AND (school_id = p_school_id OR school_id IS NULL);

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
        'subjects', v_subjects,
        'roles', v_roles
    );
END;
$function$;
