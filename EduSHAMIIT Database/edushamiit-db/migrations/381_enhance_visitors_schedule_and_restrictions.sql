-- Migration 381: Enhance visitor schedule and restrictions functions
-- 1. Enhance fn_visitors_schedule_appointment to support direct visitor_id, profile sync, expected_count, vehicle, and exact local date alignment.
-- 2. Enhance fn_visitors_create_restriction to support existing profile selection, duration_days, valid_till, and scope types.
-- 3. Enhance fn_visitors_list_restrictions to support date_from and date_to filtering.
-- 4. Enhance fn_visitors_get_blacklisted_kpis to support date_from and date_to filtering.

-- 1. Schedule Appointment Function
CREATE OR REPLACE FUNCTION public.fn_visitors_schedule_appointment(
    p_school_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_phone VARCHAR := TRIM(COALESCE(p_payload->>'phone', ''));
    v_full_name VARCHAR := TRIM(COALESCE(p_payload->>'full_name', p_payload->>'visitor_name', ''));
    v_visitor_id UUID := NULLIF(p_payload->>'visitor_id', '')::UUID;
    v_next_seq INT;
    v_appointment_number VARCHAR;
    v_apt_id UUID;
    v_scheduled_start TIMESTAMPTZ;
    v_scheduled_end TIMESTAMPTZ;
    v_scheduled_date DATE;
BEGIN
    -- If visitor_id provided, fetch name/phone if empty
    IF v_visitor_id IS NOT NULL THEN
        SELECT full_name, phone INTO v_full_name, v_phone
        FROM public.visitor_profiles
        WHERE id = v_visitor_id;
    END IF;

    IF v_phone = '' OR v_full_name = '' THEN
        RETURN jsonb_build_object('success', false, 'detail', 'Phone number and name are required.');
    END IF;

    -- Lookup or create visitor profile
    IF v_visitor_id IS NULL THEN
        SELECT id INTO v_visitor_id
        FROM public.visitor_profiles
        WHERE school_id = p_school_id AND phone = v_phone AND archived_at IS NULL;

        IF v_visitor_id IS NULL THEN
            INSERT INTO public.visitor_profiles (
                school_id, full_name, phone, email, company, visitor_type, photo_url, id_type, id_number_masked
            ) VALUES (
                p_school_id, v_full_name, v_phone, p_payload->>'email',
                p_payload->>'company', COALESCE(p_payload->>'visitor_type', 'Parent'),
                p_payload->>'photo_url', COALESCE(p_payload->>'id_type', 'Aadhaar Card'),
                COALESCE(p_payload->>'id_number_masked', 'XXXX-XXXX-1234')
            ) RETURNING id INTO v_visitor_id;
        END IF;
    END IF;

    -- Update photo or ID if provided
    IF p_payload->>'photo_url' IS NOT NULL AND p_payload->>'photo_url' != '' THEN
        UPDATE public.visitor_profiles
        SET photo_url = p_payload->>'photo_url'
        WHERE id = v_visitor_id AND (photo_url IS NULL OR photo_url = '');
    END IF;

    -- Time calculations
    v_scheduled_start := COALESCE((p_payload->>'scheduled_start_at')::TIMESTAMPTZ, NOW() + interval '1 day');
    v_scheduled_end := COALESCE((p_payload->>'scheduled_end_at')::TIMESTAMPTZ, v_scheduled_start + interval '1 hour');
    v_scheduled_date := COALESCE((p_payload->>'scheduled_date')::DATE, (v_scheduled_start AT TIME ZONE 'Asia/Kolkata')::DATE, CURRENT_DATE);

    -- Generate sequence number
    SELECT COALESCE(MAX(SUBSTRING(appointment_number FROM '[0-9]+$')::INT), 0) + 1 INTO v_next_seq
    FROM public.visitor_appointments
    WHERE school_id = p_school_id;

    v_appointment_number := 'APT-' || to_char(NOW(), 'YYYY') || '-' || LPAD(v_next_seq::TEXT, 4, '0');

    INSERT INTO public.visitor_appointments (
        school_id, appointment_number, visitor_id, host_name, host_department,
        purpose, destination, scheduled_date, scheduled_start_at, scheduled_end_at,
        status, notes, expected_count, expected_visitors_text, vehicle_number
    ) VALUES (
        p_school_id, v_appointment_number, v_visitor_id,
        COALESCE(p_payload->>'host_name', 'Principal Office'),
        p_payload->>'host_department',
        COALESCE(p_payload->>'purpose', 'Meeting'),
        COALESCE(p_payload->>'destination', 'Main Gate'),
        v_scheduled_date,
        v_scheduled_start,
        v_scheduled_end,
        'AWAITING_APPROVAL',
        COALESCE(p_payload->>'notes', p_payload->>'remarks'),
        COALESCE((p_payload->>'expected_count')::INT, 1),
        COALESCE(p_payload->>'expected_visitors_text', (COALESCE((p_payload->>'expected_count')::INT, 1) || ' (Expected)')),
        p_payload->>'vehicle_number'
    ) RETURNING id INTO v_apt_id;

    RETURN jsonb_build_object(
        'success', true,
        'appointment_id', v_apt_id,
        'appointment_number', v_appointment_number,
        'status', 'AWAITING_APPROVAL'
    );
END;
$$;


-- 2. Create Restriction / Blacklist Function
CREATE OR REPLACE FUNCTION public.fn_visitors_create_restriction(
    p_school_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_visitor_id UUID := NULLIF(p_payload->>'visitor_id', '')::UUID;
    v_phone VARCHAR := TRIM(COALESCE(p_payload->>'phone', ''));
    v_full_name VARCHAR := TRIM(COALESCE(p_payload->>'full_name', p_payload->>'visitor_name', ''));
    v_scope_type VARCHAR := COALESCE(p_payload->>'scope_type', 'CAMPUS');
    v_scope_name VARCHAR;
    v_reason_cat VARCHAR := COALESCE(NULLIF(TRIM(p_payload->>'reason_category'), ''), NULLIF(TRIM(p_payload->>'reason_code'), ''), 'Security Incident');
    v_review_at TIMESTAMPTZ;
    v_restriction_id UUID;
BEGIN
    -- If visitor_id provided, fetch name/phone if empty
    IF v_visitor_id IS NOT NULL THEN
        SELECT full_name, phone INTO v_full_name, v_phone
        FROM public.visitor_profiles
        WHERE id = v_visitor_id;
    END IF;

    -- If visitor_id not passed, locate or create profile
    IF v_visitor_id IS NULL THEN
        IF v_phone = '' OR v_full_name = '' THEN
            RETURN jsonb_build_object('success', false, 'detail', 'Phone number and full name are required to blacklist.');
        END IF;

        SELECT id INTO v_visitor_id
        FROM public.visitor_profiles
        WHERE school_id = p_school_id AND phone = v_phone AND archived_at IS NULL;

        IF v_visitor_id IS NULL THEN
            INSERT INTO public.visitor_profiles (
                school_id, full_name, phone, visitor_type, is_blacklisted, photo_url, id_type, id_number_masked
            ) VALUES (
                p_school_id, v_full_name, v_phone, COALESCE(p_payload->>'visitor_type', 'Parent'),
                TRUE, p_payload->>'photo_url', COALESCE(p_payload->>'id_type', 'Aadhaar Card'),
                COALESCE(p_payload->>'id_number_masked', 'XXXX-XXXX-1234')
            ) RETURNING id INTO v_visitor_id;
        END IF;
    END IF;

    -- Mark visitor profile as blacklisted
    UPDATE public.visitor_profiles
    SET is_blacklisted = TRUE,
        photo_url = COALESCE(p_payload->>'photo_url', photo_url),
        updated_at = NOW()
    WHERE id = v_visitor_id;

    -- Calculate review date / expiration
    v_review_at := COALESCE(
        (p_payload->>'valid_till')::TIMESTAMPTZ,
        (p_payload->>'expires_at')::TIMESTAMPTZ,
        NOW() + (COALESCE(p_payload->>'duration_days', '30') || ' days')::INTERVAL
    );

    -- Format human readable scope name
    v_scope_name := CASE
        WHEN v_scope_type = 'CAMPUS' THEN 'Entire Campus'
        WHEN v_scope_type = 'INSTITUTION' THEN 'All Institution Facilities'
        WHEN v_scope_type = 'BUILDING' THEN COALESCE(p_payload->>'scope_name', 'Specific Building (Hostel/Lab/Library)')
        WHEN v_scope_type = 'DEPARTMENT' THEN COALESCE(p_payload->>'scope_name', 'Specific Department/Floor')
        ELSE COALESCE(p_payload->>'scope_name', 'Entire Campus')
    END;

    -- Insert restriction record
    INSERT INTO public.visitor_restrictions (
        school_id, visitor_id, visitor_name, visitor_phone,
        scope_type, scope_name, reason_category, confidential_notes,
        status, requested_by_name, approved_by_name, review_at, created_at
    ) VALUES (
        p_school_id, v_visitor_id, v_full_name, v_phone,
        v_scope_type, v_scope_name, v_reason_cat,
        COALESCE(p_payload->>'confidential_notes', 'Security restriction applied.'),
        'ACTIVE',
        COALESCE(p_payload->>'requested_by_name', 'Security Officer'),
        COALESCE(p_payload->>'approved_by_name', 'Director / Principal'),
        v_review_at,
        NOW()
    ) RETURNING id INTO v_restriction_id;

    -- Log activity
    INSERT INTO public.visitor_activity_logs (
        school_id, entity_type, entity_id, action, details
    ) VALUES (
        p_school_id, 'RESTRICTION', v_restriction_id, 'BLACKLISTED',
        jsonb_build_object('visitor_id', v_visitor_id, 'reason', v_reason_cat)
    );

    RETURN jsonb_build_object('success', true, 'restriction_id', v_restriction_id, 'status', 'ACTIVE');
END;
$$;


-- 3. List Restrictions with Date Range Filtering
CREATE OR REPLACE FUNCTION public.fn_visitors_list_restrictions(
    p_school_id UUID,
    p_params JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search VARCHAR := TRIM(COALESCE(p_params->>'search', ''));
    v_status VARCHAR := TRIM(COALESCE(p_params->>'status', 'All'));
    v_page INT := GREATEST(1, COALESCE((p_params->>'page')::INT, 1));
    v_page_size INT := GREATEST(1, LEAST(100, COALESCE((p_params->>'page_size')::INT, 10)));
    v_offset INT := (v_page - 1) * v_page_size;
    v_total_records INT := 0;
    v_records JSONB := '[]'::JSONB;
    v_date_from TIMESTAMPTZ := NULL;
    v_date_to TIMESTAMPTZ := NULL;
BEGIN
    IF p_params->>'date_from' IS NOT NULL AND p_params->>'date_from' != '' THEN
        v_date_from := (p_params->>'date_from')::TIMESTAMPTZ;
    END IF;
    IF p_params->>'date_to' IS NOT NULL AND p_params->>'date_to' != '' THEN
        v_date_to := (p_params->>'date_to')::TIMESTAMPTZ;
    END IF;

    SELECT COUNT(*) INTO v_total_records
    FROM public.visitor_restrictions r
    JOIN public.visitor_profiles p ON r.visitor_id = p.id
    WHERE r.school_id = p_school_id
      AND (
          v_search = ''
          OR p.full_name ILIKE '%' || v_search || '%'
          OR p.phone ILIKE '%' || v_search || '%'
          OR r.reason_category ILIKE '%' || v_search || '%'
          OR r.scope_name ILIKE '%' || v_search || '%'
      )
      AND (
          v_status = 'All'
          OR v_status = 'All Status'
          OR r.status = v_status
      )
      AND (
          v_date_from IS NULL
          OR r.created_at >= v_date_from
      )
      AND (
          v_date_to IS NULL
          OR r.created_at <= v_date_to
      );

    SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_records
    FROM (
        SELECT jsonb_build_object(
            'id', r.id,
            'visitor_id', r.visitor_id,
            'visitor_name', p.full_name,
            'visitor_phone', p.phone,
            'photo_url', p.photo_url,
            'scope_type', r.scope_type,
            'scope_name', r.scope_name,
            'reason_category', r.reason_category,
            'confidential_notes', r.confidential_notes,
            'status', r.status,
            'effective_from', to_char(r.effective_from, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'review_at', to_char(r.review_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'requested_by_name', r.requested_by_name,
            'approved_by_name', r.approved_by_name,
            'lifted_by_name', r.lifted_by_name,
            'lift_reason', r.lift_reason,
            'created_at', to_char(r.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        ) AS row_data
        FROM public.visitor_restrictions r
        JOIN public.visitor_profiles p ON r.visitor_id = p.id
        WHERE r.school_id = p_school_id
          AND (
              v_search = ''
              OR p.full_name ILIKE '%' || v_search || '%'
              OR p.phone ILIKE '%' || v_search || '%'
              OR r.reason_category ILIKE '%' || v_search || '%'
              OR r.scope_name ILIKE '%' || v_search || '%'
          )
          AND (
              v_status = 'All'
              OR v_status = 'All Status'
              OR r.status = v_status
          )
          AND (
              v_date_from IS NULL
              OR r.created_at >= v_date_from
          )
          AND (
              v_date_to IS NULL
              OR r.created_at <= v_date_to
          )
        ORDER BY r.created_at DESC
        LIMIT v_page_size OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'records', v_records,
        'pagination', jsonb_build_object(
            'total_records', v_total_records,
            'page', v_page,
            'page_size', v_page_size,
            'total_pages', CEIL(v_total_records::NUMERIC / GREATEST(1, v_page_size))
        )
    );
END;
$$;


-- 4. Blacklisted Visitors KPIs with Date Range Support
CREATE OR REPLACE FUNCTION public.fn_visitors_get_blacklisted_kpis(
    p_school_id UUID,
    p_date_from TIMESTAMPTZ DEFAULT NULL,
    p_date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_blacklisted INT := 0;
    v_active_blocks INT := 0;
    v_expired_blocks INT := 0;
    v_attempted_entries INT := 0;
BEGIN
    SELECT COUNT(*) INTO v_total_blacklisted
    FROM public.visitor_restrictions
    WHERE school_id = p_school_id
      AND (p_date_from IS NULL OR created_at >= p_date_from)
      AND (p_date_to IS NULL OR created_at <= p_date_to);

    SELECT COUNT(*) INTO v_active_blocks
    FROM public.visitor_restrictions
    WHERE school_id = p_school_id
      AND status = 'ACTIVE'
      AND (p_date_from IS NULL OR created_at >= p_date_from)
      AND (p_date_to IS NULL OR created_at <= p_date_to);

    SELECT COUNT(*) INTO v_expired_blocks
    FROM public.visitor_restrictions
    WHERE school_id = p_school_id
      AND status IN ('EXPIRED', 'LIFTED')
      AND (p_date_from IS NULL OR created_at >= p_date_from)
      AND (p_date_to IS NULL OR created_at <= p_date_to);

    SELECT COUNT(*) INTO v_attempted_entries
    FROM public.visitor_access_attempts
    WHERE school_id = p_school_id
      AND outcome = 'Blocked'
      AND (p_date_from IS NULL OR attempt_at >= p_date_from)
      AND (p_date_to IS NULL OR attempt_at <= p_date_to);

    RETURN jsonb_build_object(
        'total_blacklisted', v_total_blacklisted,
        'total_subtitle', 'Restricted from entry',
        'active_blocks', v_active_blocks,
        'active_subtitle', 'Currently restricted',
        'expired_blocks', v_expired_blocks,
        'expired_subtitle', 'Restriction ended',
        'attempted_entries', v_attempted_entries,
        'attempted_subtitle', 'Blocked at gate'
    );
END;
$$;
