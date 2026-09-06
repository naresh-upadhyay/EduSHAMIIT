-- ============================================================================
-- Migration 342: Exclude Existing Library Members from Add Member Profile Search
-- Purpose:
-- Ensure that users who are already library members are NOT shown in the 
-- "Add Library Member — Select Profile" search results.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_library_search_profiles_for_member(
    p_school_id UUID,
    p_query TEXT DEFAULT NULL,
    p_role TEXT DEFAULT NULL,
    p_limit INT DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_results JSONB;
    v_where TEXT := 'p.school_id = $1 AND NOT EXISTS (SELECT 1 FROM public.library_members m WHERE m.profile_id = p.id AND m.school_id = p.school_id AND m.archived_at IS NULL)';
    v_sql TEXT;
BEGIN
    -- Optional role filter (student, teacher, staff, etc.)
    IF p_role IS NOT NULL AND TRIM(p_role) != '' AND UPPER(p_role) != 'ALL' THEN
        v_where := v_where || format(' AND p.role ILIKE %L', '%' || TRIM(p_role) || '%');
    END IF;

    -- Query search in full_name, email, phone, admission_number, employee_id
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
                 FALSE AS is_already_member,
                 NULL::UUID AS existing_member_id,
                 NULL::TEXT AS existing_member_code,
                 NULL::TEXT AS existing_member_status
             FROM public.profiles p
             WHERE %s
             ORDER BY p.full_name ASC
             LIMIT %s
         ) t',
        v_where,
        GREATEST(p_limit, 1)
    );

    EXECUTE v_sql USING p_school_id INTO v_results;
    RETURN COALESCE(v_results, '[]'::jsonb);
END;
$$;
