-- ============================================================================
-- Migration 344: Prevent Duplicate Library Members & Duplicate Candidates
-- Purpose:
-- 1. Exclude profiles whose name/email/phone already has an active library member.
-- 2. Deduplicate candidate profiles by full_name.
-- 3. In fn_library_create_member, prevent creating duplicate active members with
--    the same name or profile in the same institution.
-- ============================================================================

-- 1. Search candidate profiles: Strict anti-duplicate filtering & distinct names
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
    v_where TEXT := 'p.school_id = $1 
      AND NOT EXISTS (
          SELECT 1 
          FROM public.library_members m
          JOIN public.profiles existing_p ON m.profile_id = existing_p.id
          WHERE m.school_id = p.school_id 
            AND m.archived_at IS NULL
            AND (
                m.profile_id = p.id
                OR (
                    p.full_name IS NOT NULL AND TRIM(p.full_name) != ''''
                    AND LOWER(TRIM(existing_p.full_name)) = LOWER(TRIM(p.full_name))
                )
                OR (
                    p.email IS NOT NULL AND TRIM(p.email) != ''''
                    AND LOWER(TRIM(existing_p.email)) = LOWER(TRIM(p.email))
                )
                OR (
                    p.phone IS NOT NULL AND TRIM(p.phone) != ''''
                    AND existing_p.phone = p.phone
                )
            )
      )';
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
             SELECT DISTINCT ON (LOWER(TRIM(p.full_name)))
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
             ORDER BY LOWER(TRIM(p.full_name)) ASC, p.created_at ASC
             LIMIT %s
         ) t',
        v_where,
        GREATEST(p_limit, 1)
    );

    EXECUTE v_sql USING p_school_id INTO v_results;
    RETURN COALESCE(v_results, '[]'::jsonb);
END;
$$;


-- 2. Stored Procedure: Create or Re-activate Member with Strict Duplicate Protection
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
    v_duplicate_name TEXT;
    v_code TEXT := TRIM(COALESCE(p_member_code, ''));
    v_expiry DATE := p_expiry_date;
    v_member_id UUID;
    v_max_num BIGINT;
BEGIN
    -- 1. Check profile exists in institution
    SELECT id, full_name, email, phone, role INTO v_profile
    FROM public.profiles
    WHERE id = p_profile_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Selected profile does not exist in this institution.';
    END IF;

    -- 2. Check if an ACTIVE membership already exists for this exact profile_id
    SELECT id, member_code INTO v_existing_id, v_existing_code
    FROM public.library_members
    WHERE profile_id = p_profile_id AND school_id = p_school_id AND archived_at IS NULL;

    IF FOUND THEN
        RAISE EXCEPTION 'This user already has an active library membership (%).', v_existing_code;
    END IF;

    -- 3. Check if an ACTIVE membership already exists with the same Full Name or Email
    SELECT m.id, m.member_code, existing_p.full_name INTO v_existing_id, v_existing_code, v_duplicate_name
    FROM public.library_members m
    JOIN public.profiles existing_p ON m.profile_id = existing_p.id
    WHERE m.school_id = p_school_id 
      AND m.archived_at IS NULL
      AND (
          (v_profile.full_name IS NOT NULL AND TRIM(v_profile.full_name) != '' AND LOWER(TRIM(existing_p.full_name)) = LOWER(TRIM(v_profile.full_name)))
          OR (v_profile.email IS NOT NULL AND TRIM(v_profile.email) != '' AND LOWER(TRIM(existing_p.email)) = LOWER(TRIM(v_profile.email)))
      )
    LIMIT 1;

    IF FOUND THEN
        RAISE EXCEPTION 'A library member with the name "%" is already registered as an active member (%). Cannot add duplicate member.', v_duplicate_name, v_existing_code;
    END IF;

    -- 4. Default 1-year expiry if not specified
    IF v_expiry IS NULL THEN
        v_expiry := p_start_date + INTERVAL '1 year';
    END IF;

    -- 5. Check if an ARCHIVED membership exists for this profile
    SELECT id, member_code INTO v_existing_id, v_existing_code
    FROM public.library_members
    WHERE profile_id = p_profile_id AND school_id = p_school_id AND archived_at IS NOT NULL
    ORDER BY created_at DESC LIMIT 1;

    -- 6. Determine member code
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

    -- 7. Re-enroll or Insert
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
