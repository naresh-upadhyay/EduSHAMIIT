-- ============================================================================
-- Migration 343: Allow Re-enrollment of Archived/Deleted Library Members
-- Purpose:
-- 1. Replace rigid unique constraints with partial unique indexes on active members.
-- 2. Update fn_library_create_member to seamlessly handle re-enrolling previously
--    archived/deleted members with collision-safe code allocation.
-- 3. Ensure fn_library_search_profiles_for_member makes archived members available.
-- ============================================================================

-- 1. Convert rigid unique constraints on library_members to partial unique indexes (active only)
ALTER TABLE public.library_members DROP CONSTRAINT IF EXISTS uq_library_members_school_profile;
ALTER TABLE public.library_members DROP CONSTRAINT IF EXISTS uq_library_members_school_code;

DROP INDEX IF EXISTS public.uq_library_members_school_profile_active;
CREATE UNIQUE INDEX uq_library_members_school_profile_active 
ON public.library_members (school_id, profile_id) 
WHERE archived_at IS NULL;

DROP INDEX IF EXISTS public.uq_library_members_school_code_active;
CREATE UNIQUE INDEX uq_library_members_school_code_active 
ON public.library_members (school_id, member_code) 
WHERE archived_at IS NULL;


-- 2. Stored procedure: Search candidate profiles (includes profiles with no active membership)
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


-- 3. Stored Procedure: Create or Re-activate/Re-enroll Library Member
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
    v_code TEXT := TRIM(COALESCE(p_member_code, ''));
    v_expiry DATE := p_expiry_date;
    v_member_id UUID;
    v_max_num BIGINT;
BEGIN
    -- 1. Check profile exists in institution
    SELECT id, full_name, role INTO v_profile
    FROM public.profiles
    WHERE id = p_profile_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Selected profile does not exist in this institution.';
    END IF;

    -- 2. Check if an ACTIVE membership currently exists
    SELECT id, member_code INTO v_existing_id, v_existing_code
    FROM public.library_members
    WHERE profile_id = p_profile_id AND school_id = p_school_id AND archived_at IS NULL;

    IF FOUND THEN
        RAISE EXCEPTION 'This user already has an active library membership (%).', v_existing_code;
    END IF;

    -- 3. Default 1-year expiry if not specified
    IF v_expiry IS NULL THEN
        v_expiry := p_start_date + INTERVAL '1 year';
    END IF;

    -- 4. Check if an ARCHIVED membership exists for this profile
    SELECT id, member_code INTO v_existing_id, v_existing_code
    FROM public.library_members
    WHERE profile_id = p_profile_id AND school_id = p_school_id AND archived_at IS NOT NULL
    ORDER BY created_at DESC LIMIT 1;

    -- 5. Determine member code
    IF v_code != '' THEN
        -- If custom code provided, ensure it's not taken by another active member
        IF EXISTS (
            SELECT 1 FROM public.library_members 
            WHERE school_id = p_school_id 
              AND member_code = v_code 
              AND archived_at IS NULL 
              AND (v_existing_id IS NULL OR id != v_existing_id)
        ) THEN
            RAISE EXCEPTION 'Member code % is already in use by another active library member.', v_code;
        END IF;
    ELSE
        -- No custom code provided:
        -- If re-enrolling, check if previous code is free among active members
        IF v_existing_code IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM public.library_members 
            WHERE school_id = p_school_id AND member_code = v_existing_code AND archived_at IS NULL AND id != v_existing_id
        ) THEN
            v_code := v_existing_code;
        ELSE
            -- Generate next sequential collision-free code
            SELECT COALESCE(MAX(NULLIF(regexp_replace(member_code, '\D', '', 'g'), '')::bigint), 0)
            INTO v_max_num
            FROM public.library_members
            WHERE school_id = p_school_id AND member_code ~ '^LIBM-\d+$';

            v_max_num := v_max_num + 1;
            v_code := format('LIBM-%s', lpad(v_max_num::text, 4, '0'));

            WHILE EXISTS (
                SELECT 1 FROM public.library_members 
                WHERE school_id = p_school_id AND member_code = v_code AND archived_at IS NULL
            ) LOOP
                v_max_num := v_max_num + 1;
                v_code := format('LIBM-%s', lpad(v_max_num::text, 4, '0'));
            END LOOP;
        END IF;
    END IF;

    -- 6. Re-enroll or Insert
    IF v_existing_id IS NOT NULL THEN
        -- Re-enroll / Reactivate existing member record
        UPDATE public.library_members
        SET archived_at = NULL,
            archived_by = NULL,
            member_code = v_code,
            membership_type = p_membership_type,
            membership_type_id = p_membership_type_id,
            membership_start_date = p_start_date,
            membership_expiry_date = v_expiry,
            borrowing_limit = p_borrowing_limit,
            max_issue_duration_days = p_max_issue_duration_days,
            renewal_allowed = p_renewal_allowed,
            max_renewals = p_max_renewals,
            status = p_status,
            suspension_reason = NULL,
            suspended_at = NULL,
            suspended_by = NULL,
            notes = p_notes,
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = v_existing_id
        RETURNING id INTO v_member_id;

        -- Audit Log
        INSERT INTO public.library_member_audits (
            school_id, member_id, action_type, description, performed_by
        ) VALUES (
            p_school_id, v_member_id, 'RE_ENROLLED', format('Library membership re-activated/created for member %s', v_code), p_user_id
        );

        RETURN jsonb_build_object(
            'success', true,
            'member_id', v_member_id,
            'member_code', v_code,
            'message', format('Library member re-enrolled successfully (%s).', v_code)
        );
    ELSE
        -- Fresh Insert
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

        -- Audit Log
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
    END IF;
END;
$$;


-- 4. Stored Procedure: Soft-delete / Archive member
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
        archived_by = p_user_id,
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
