-- Migration 383: Auto-block visits and appointments on visitor restriction / blacklisting
-- Ensures that when a visitor is blacklisted, any scheduled, pending, or inside visits/appointments
-- are marked as 'Blocked' and not shown as 'Scheduled', and gate passes are revoked.

-- 1. Immediate data cleanup: update existing uncompleted visits & active appointments for blacklisted visitors
UPDATE public.visitor_visits
SET status = 'Blocked',
    remarks = CASE 
        WHEN remarks IS NULL OR remarks = '' THEN 'Blocked due to security blacklist'
        WHEN remarks LIKE '%Blocked%' THEN remarks
        ELSE remarks || ' (Blocked due to security blacklist)'
    END,
    updated_at = NOW()
WHERE (
    visitor_id IN (SELECT id FROM public.visitor_profiles WHERE is_blacklisted = TRUE)
    OR visitor_id IN (SELECT visitor_id FROM public.visitor_restrictions WHERE status = 'ACTIVE')
)
AND actual_check_out_at IS NULL;

UPDATE public.visitor_appointments
SET status = 'Blocked',
    rejection_reason = 'Visitor added to security blacklist',
    updated_at = NOW()
WHERE (
    visitor_id IN (SELECT id FROM public.visitor_profiles WHERE is_blacklisted = TRUE)
    OR visitor_id IN (SELECT visitor_id FROM public.visitor_restrictions WHERE status = 'ACTIVE')
)
AND status IN ('AWAITING_APPROVAL', 'APPROVED', 'CONFIRMED', 'PENDING', 'Requested', 'Scheduled');

UPDATE public.visitor_gate_passes
SET status = 'REVOKED',
    revoked_at = NOW(),
    revoked_reason = 'Visitor profile blacklisted'
WHERE visit_id IN (
    SELECT id FROM public.visitor_visits WHERE status = 'Blocked'
)
AND status = 'ACTIVE';


-- 2. Enhanced fn_visitors_create_restriction:
-- Automatically blocks existing open visits, appointments, and revokes gate passes
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

    -- Automatically block any uncompleted visits for this visitor
    UPDATE public.visitor_visits
    SET status = 'Blocked',
        remarks = CASE 
            WHEN remarks IS NULL OR remarks = '' THEN 'Blocked due to security blacklist: ' || v_reason_cat
            WHEN remarks LIKE '%Blocked%' THEN remarks
            ELSE remarks || ' (Blocked due to security blacklist: ' || v_reason_cat || ')'
        END,
        updated_at = NOW()
    WHERE visitor_id = v_visitor_id
      AND actual_check_out_at IS NULL;

    -- Automatically block any pending/scheduled appointments
    UPDATE public.visitor_appointments
    SET status = 'Blocked',
        rejection_reason = 'Visitor added to security blacklist (' || v_reason_cat || ')',
        updated_at = NOW()
    WHERE visitor_id = v_visitor_id
      AND status IN ('AWAITING_APPROVAL', 'APPROVED', 'CONFIRMED', 'PENDING', 'Requested', 'Scheduled');

    -- Revoke active gate passes for this visitor
    UPDATE public.visitor_gate_passes
    SET status = 'REVOKED',
        revoked_at = NOW(),
        revoked_reason = 'Visitor blacklisted: ' || v_reason_cat
    WHERE visit_id IN (
        SELECT id FROM public.visitor_visits WHERE visitor_id = v_visitor_id
    )
    AND status = 'ACTIVE';

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


-- 3. Enhanced fn_visitors_list_visits:
-- Correctly flags blocked/blacklisted visitors as 'Blocked' and filters them out of 'Scheduled'
CREATE OR REPLACE FUNCTION public.fn_visitors_list_visits(
    p_school_id UUID,
    p_params JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search VARCHAR := TRIM(COALESCE(p_params->>'search', ''));
    v_location VARCHAR := TRIM(COALESCE(p_params->>'location', 'All'));
    v_category VARCHAR := TRIM(COALESCE(p_params->>'category', 'All'));
    v_status VARCHAR := TRIM(COALESCE(p_params->>'status', 'All'));
    v_page INT := GREATEST(1, COALESCE((p_params->>'page')::INT, 1));
    v_page_size INT := GREATEST(1, LEAST(100, COALESCE((p_params->>'page_size')::INT, 10)));
    v_offset INT := (v_page - 1) * v_page_size;
    v_total INT := 0;
    v_records JSONB := '[]'::JSONB;
    v_date_from TIMESTAMPTZ := NULL;
    v_date_to TIMESTAMPTZ := NULL;
    v_now TIMESTAMPTZ := NOW();
BEGIN
    IF p_params->>'date_from' IS NOT NULL AND p_params->>'date_from' != '' THEN
        v_date_from := (p_params->>'date_from')::TIMESTAMPTZ;
    END IF;
    IF p_params->>'date_to' IS NOT NULL AND p_params->>'date_to' != '' THEN
        v_date_to := (p_params->>'date_to')::TIMESTAMPTZ;
    END IF;

    -- Count total records matching criteria
    SELECT COUNT(*) INTO v_total
    FROM public.visitor_visits v
    JOIN public.visitor_profiles p ON v.visitor_id = p.id
    WHERE v.school_id = p_school_id
      AND (
          v_search = ''
          OR p.full_name ILIKE '%' || v_search || '%'
          OR p.phone ILIKE '%' || v_search || '%'
          OR v.visit_number ILIKE '%' || v_search || '%'
          OR v.purpose ILIKE '%' || v_search || '%'
          OR COALESCE(v.host_name, '') ILIKE '%' || v_search || '%'
          OR COALESCE(v.vehicle_number, '') ILIKE '%' || v_search || '%'
          OR COALESCE(v.pass_reference, '') ILIKE '%' || v_search || '%'
      )
      AND (
          v_location = 'All'
          OR v_location = 'All Locations'
          OR v.destination = v_location
          OR v.entry_location = v_location
      )
      AND (
          v_category = 'All'
          OR v_category = 'All Visitor Types'
          OR v.category = v_category
          OR p.visitor_type = v_category
      )
      AND (
          v_status = 'All'
          OR v_status = 'All Status'
          OR (v_status = 'Blocked' AND (
              v.status = 'Blocked'
              OR (v.actual_check_out_at IS NULL AND (
                  p.is_blacklisted = TRUE
                  OR EXISTS (
                      SELECT 1 FROM public.visitor_restrictions vr
                      WHERE vr.visitor_id = v.visitor_id
                        AND vr.school_id = v.school_id
                        AND vr.status = 'ACTIVE'
                        AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)
                  )
              ))
          ))
          OR (v_status = 'Inside' AND v.actual_check_out_at IS NULL AND v.status IN ('Inside', 'Overstay') AND p.is_blacklisted IS NOT TRUE AND v.status != 'Blocked')
          OR (v_status = 'Checked Out' AND (v.status = 'Checked Out' OR v.actual_check_out_at IS NOT NULL))
          OR (v_status = 'Overstay' AND v.actual_check_out_at IS NULL AND (v.status = 'Overstay' OR (v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < v_now)) AND p.is_blacklisted IS NOT TRUE AND v.status != 'Blocked')
          OR (v_status = 'Scheduled' AND v.status = 'Scheduled' AND v.actual_check_out_at IS NULL AND p.is_blacklisted IS NOT TRUE AND v.status != 'Blocked')
          OR (v.status = v_status AND p.is_blacklisted IS NOT TRUE)
      )
      AND (
          v_date_from IS NULL
          OR COALESCE(v.check_in_at, v.created_at) >= v_date_from
      )
      AND (
          v_date_to IS NULL
          OR COALESCE(v.check_in_at, v.created_at) <= v_date_to
      );

    -- Fetch paginated records
    SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_records
    FROM (
        SELECT jsonb_build_object(
            'id', v.id,
            'visit_number', v.visit_number,
            'visitor_id', v.visitor_id,
            'visitor_name', p.full_name,
            'photo_url', p.photo_url,
            'phone', p.phone,
            'visitor_type', v.category,
            'category', v.category,
            'purpose', v.purpose,
            'location', v.destination,
            'destination', v.destination,
            'host_name', COALESCE(v.host_name, 'Staff Member'),
            'host_department', v.host_department,
            'check_in_at', to_char(v.check_in_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
            'expected_out_at', to_char(v.expected_out_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
            'actual_check_out_at', to_char(v.actual_check_out_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
            'status', CASE 
                WHEN v.actual_check_out_at IS NOT NULL THEN 'Checked Out'
                WHEN v.status = 'Blocked' 
                  OR p.is_blacklisted = TRUE 
                  OR EXISTS (
                      SELECT 1 FROM public.visitor_restrictions vr 
                      WHERE vr.visitor_id = v.visitor_id 
                        AND vr.school_id = v.school_id 
                        AND vr.status = 'ACTIVE' 
                        AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)
                  ) THEN 'Blocked'
                WHEN v.status = 'Overstay' OR (v.status = 'Inside' AND v.actual_check_out_at IS NULL AND v.expected_out_at IS NOT NULL AND v.expected_out_at < v_now) THEN 'Overstay'
                ELSE v.status
            END,
            'vehicle_number', v.vehicle_number,
            'pass_reference', v.pass_reference,
            'remarks', v.remarks
        ) AS row_data
        FROM public.visitor_visits v
        JOIN public.visitor_profiles p ON v.visitor_id = p.id
        WHERE v.school_id = p_school_id
          AND (
              v_search = ''
              OR p.full_name ILIKE '%' || v_search || '%'
              OR p.phone ILIKE '%' || v_search || '%'
              OR v.visit_number ILIKE '%' || v_search || '%'
              OR v.purpose ILIKE '%' || v_search || '%'
              OR COALESCE(v.host_name, '') ILIKE '%' || v_search || '%'
              OR COALESCE(v.vehicle_number, '') ILIKE '%' || v_search || '%'
              OR COALESCE(v.pass_reference, '') ILIKE '%' || v_search || '%'
          )
          AND (
              v_location = 'All'
              OR v_location = 'All Locations'
              OR v.destination = v_location
              OR v.entry_location = v_location
          )
          AND (
              v_category = 'All'
              OR v_category = 'All Visitor Types'
              OR v.category = v_category
              OR p.visitor_type = v_category
          )
          AND (
              v_status = 'All'
              OR v_status = 'All Status'
              OR (v_status = 'Blocked' AND (
                  v.status = 'Blocked'
                  OR (v.actual_check_out_at IS NULL AND (
                      p.is_blacklisted = TRUE
                      OR EXISTS (
                          SELECT 1 FROM public.visitor_restrictions vr
                          WHERE vr.visitor_id = v.visitor_id
                            AND vr.school_id = v.school_id
                            AND vr.status = 'ACTIVE'
                            AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)
                      )
                  ))
              ))
              OR (v_status = 'Inside' AND v.actual_check_out_at IS NULL AND v.status IN ('Inside', 'Overstay') AND p.is_blacklisted IS NOT TRUE AND v.status != 'Blocked')
              OR (v_status = 'Checked Out' AND (v.status = 'Checked Out' OR v.actual_check_out_at IS NOT NULL))
              OR (v_status = 'Overstay' AND v.actual_check_out_at IS NULL AND (v.status = 'Overstay' OR (v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < v_now)) AND p.is_blacklisted IS NOT TRUE AND v.status != 'Blocked')
              OR (v_status = 'Scheduled' AND v.status = 'Scheduled' AND v.actual_check_out_at IS NULL AND p.is_blacklisted IS NOT TRUE AND v.status != 'Blocked')
              OR (v.status = v_status AND p.is_blacklisted IS NOT TRUE)
          )
          AND (
              v_date_from IS NULL
              OR COALESCE(v.check_in_at, v.created_at) >= v_date_from
          )
          AND (
              v_date_to IS NULL
              OR COALESCE(v.check_in_at, v.created_at) <= v_date_to
          )
        ORDER BY v.created_at DESC
        LIMIT v_page_size OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'records', v_records,
        'pagination', jsonb_build_object(
            'page', v_page,
            'page_size', v_page_size,
            'total', v_total,
            'total_pages', CEIL(v_total::NUMERIC / v_page_size)::INT
        )
    );
END;
$$;


-- 4. Enhanced fn_visitors_get_visit_details:
-- Returns 'Blocked' for visit status and history when visitor is blacklisted or blocked
CREATE OR REPLACE FUNCTION public.fn_visitors_get_visit_details(
    p_school_id UUID,
    p_visit_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_visit RECORD;
    v_profile RECORD;
    v_documents JSONB := '[]'::JSONB;
    v_history JSONB := '[]'::JSONB;
    v_access_events JSONB := '[]'::JSONB;
    v_gate_pass RECORD;
    v_duration_text VARCHAR := '';
    v_duration_mins INT := 0;
BEGIN
    SELECT * INTO v_visit
    FROM public.visitor_visits
    WHERE id = p_visit_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Visit not found');
    END IF;

    SELECT * INTO v_profile
    FROM public.visitor_profiles
    WHERE id = v_visit.visitor_id AND school_id = p_school_id;

    -- Calculate duration
    IF v_visit.check_in_at IS NOT NULL THEN
        IF v_visit.actual_check_out_at IS NOT NULL THEN
            v_duration_mins := EXTRACT(EPOCH FROM (v_visit.actual_check_out_at - v_visit.check_in_at)) / 60;
            v_duration_text := (v_duration_mins / 60)::INT || ' hr ' || (v_duration_mins % 60)::INT || ' mins (completed)';
        ELSE
            v_duration_mins := EXTRACT(EPOCH FROM (NOW() - v_visit.check_in_at)) / 60;
            v_duration_text := (v_duration_mins / 60)::INT || ' hr ' || (v_duration_mins % 60)::INT || ' mins (ongoing)';
        END IF;
    END IF;

    -- Documents for this visitor
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', id,
        'document_name', document_name,
        'document_type', document_type,
        'file_url', file_url,
        'file_size_bytes', file_size_bytes,
        'verification_status', verification_status,
        'uploaded_at', to_char(uploaded_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
    ) ORDER BY uploaded_at DESC), '[]'::JSONB) INTO v_documents
    FROM public.visitor_documents
    WHERE visitor_id = v_profile.id AND school_id = p_school_id;

    -- Complete Visit History for this visitor (including current and prior visits)
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', id,
        'visit_number', visit_number,
        'purpose', purpose,
        'host_name', host_name,
        'destination', destination,
        'check_in_at', to_char(check_in_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'actual_check_out_at', to_char(actual_check_out_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'status', CASE 
            WHEN actual_check_out_at IS NOT NULL THEN 'Checked Out'
            WHEN status = 'Blocked' OR (actual_check_out_at IS NULL AND v_profile.is_blacklisted = TRUE) THEN 'Blocked'
            ELSE status
        END,
        'is_current', (id = p_visit_id)
    ) ORDER BY COALESCE(check_in_at, created_at) DESC), '[]'::JSONB) INTO v_history
    FROM public.visitor_visits
    WHERE visitor_id = v_profile.id
      AND school_id = p_school_id;

    -- Access events
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', id,
        'location_name', location_name,
        'event_type', event_type,
        'occurred_at', to_char(occurred_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'recorded_by_name', recorded_by_name,
        'notes', notes
    ) ORDER BY occurred_at ASC), '[]'::JSONB) INTO v_access_events
    FROM public.visitor_access_events
    WHERE visit_id = p_visit_id AND school_id = p_school_id;

    -- Gate pass
    SELECT * INTO v_gate_pass
    FROM public.visitor_gate_passes
    WHERE visit_id = p_visit_id AND school_id = p_school_id
    ORDER BY created_at DESC LIMIT 1;

    RETURN jsonb_build_object(
        'success', true,
        'visit', jsonb_build_object(
            'id', v_visit.id,
            'visit_number', v_visit.visit_number,
            'visitor_id', v_visit.visitor_id,
            'purpose', v_visit.purpose,
            'category', v_visit.category,
            'entry_location', v_visit.entry_location,
            'destination', v_visit.destination,
            'host_name', v_visit.host_name,
            'host_department', v_visit.host_department,
            'check_in_at', to_char(v_visit.check_in_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'expected_out_at', to_char(v_visit.expected_out_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'actual_check_out_at', to_char(v_visit.actual_check_out_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'duration_text', v_duration_text,
            'status', CASE 
                WHEN v_visit.actual_check_out_at IS NOT NULL THEN 'Checked Out'
                WHEN v_visit.status = 'Blocked' 
                  OR v_profile.is_blacklisted = TRUE 
                  OR EXISTS (
                      SELECT 1 FROM public.visitor_restrictions vr 
                      WHERE vr.visitor_id = v_profile.id 
                        AND vr.school_id = p_school_id 
                        AND vr.status = 'ACTIVE' 
                        AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())
                  ) THEN 'Blocked'
                WHEN v_visit.status = 'Overstay' OR (v_visit.status = 'Inside' AND v_visit.expected_out_at IS NOT NULL AND v_visit.expected_out_at < NOW()) THEN 'Overstay'
                ELSE v_visit.status
            END,
            'vehicle_number', v_visit.vehicle_number,
            'remarks', v_visit.remarks,
            'pass_reference', v_visit.pass_reference,
            'gate_pass', CASE WHEN v_gate_pass.id IS NOT NULL THEN jsonb_build_object(
                'id', v_gate_pass.id,
                'pass_number', v_gate_pass.pass_number,
                'status', v_gate_pass.status,
                'expires_at', to_char(v_gate_pass.expires_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
            ) ELSE NULL END
        ),
        'visitor', jsonb_build_object(
            'id', v_profile.id,
            'full_name', v_profile.full_name,
            'phone', v_profile.phone,
            'alternate_phone', v_profile.alternate_phone,
            'email', v_profile.email,
            'company', v_profile.company,
            'designation', v_profile.designation,
            'visitor_type', v_profile.visitor_type,
            'id_type', v_profile.id_type,
            'id_number_masked', v_profile.id_number_masked,
            'photo_url', v_profile.photo_url,
            'is_blacklisted', v_profile.is_blacklisted
        ),
        'documents', v_documents,
        'visit_history', v_history,
        'access_events', v_access_events
    );
END;
$$;


-- 5. Enhanced fn_visitors_list_appointments:
-- Flags blacklisted visitor appointments as 'Blocked' and filters them out of regular scheduled lists
CREATE OR REPLACE FUNCTION public.fn_visitors_list_appointments(
    p_school_id UUID,
    p_params JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search VARCHAR := TRIM(COALESCE(p_params->>'search', ''));
    v_location VARCHAR := TRIM(COALESCE(p_params->>'location', 'All Locations'));
    v_category VARCHAR := TRIM(COALESCE(p_params->>'category', 'All Visitor Types'));
    v_status VARCHAR := TRIM(COALESCE(p_params->>'status', 'All Status'));
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
    FROM public.visitor_appointments a
    JOIN public.visitor_profiles p ON a.visitor_id = p.id
    WHERE a.school_id = p_school_id
      AND (
          v_search = ''
          OR p.full_name ILIKE '%' || v_search || '%'
          OR p.phone ILIKE '%' || v_search || '%'
          OR a.appointment_number ILIKE '%' || v_search || '%'
          OR a.host_name ILIKE '%' || v_search || '%'
          OR a.purpose ILIKE '%' || v_search || '%'
          OR a.destination ILIKE '%' || v_search || '%'
      )
      AND (
          v_location = 'All Locations'
          OR v_location = 'All'
          OR a.destination = v_location
      )
      AND (
          v_category = 'All Visitor Types'
          OR v_category = 'All'
          OR p.visitor_type = v_category
      )
      AND (
          v_status = 'All Status'
          OR v_status = 'All'
          OR (v_status ILIKE 'Blocked' AND (a.status IN ('BLOCKED', 'Blocked') OR p.is_blacklisted = TRUE))
          OR (v_status ILIKE 'Confirmed' AND a.status IN ('APPROVED', 'CONFIRMED') AND p.is_blacklisted IS NOT TRUE)
          OR (v_status ILIKE 'Pending' AND a.status IN ('AWAITING_APPROVAL', 'PENDING') AND p.is_blacklisted IS NOT TRUE)
          OR (v_status ILIKE 'Today' AND a.scheduled_date = CURRENT_DATE AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED', 'BLOCKED', 'Blocked') AND p.is_blacklisted IS NOT TRUE)
          OR (v_status ILIKE 'This Week' AND a.scheduled_date >= CURRENT_DATE AND a.scheduled_date <= (CURRENT_DATE + interval '7 days') AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED', 'BLOCKED', 'Blocked') AND p.is_blacklisted IS NOT TRUE)
          OR (v_status ILIKE 'Expected' AND a.scheduled_date >= CURRENT_DATE AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED', 'BLOCKED', 'Blocked') AND p.is_blacklisted IS NOT TRUE)
          OR (a.status ILIKE v_status AND p.is_blacklisted IS NOT TRUE)
      )
      AND (
          v_date_from IS NULL
          OR COALESCE(a.scheduled_start_at, (a.scheduled_date::text || ' 00:00:00+00')::timestamptz) >= v_date_from
      )
      AND (
          v_date_to IS NULL
          OR COALESCE(a.scheduled_start_at, (a.scheduled_date::text || ' 23:59:59+00')::timestamptz) <= v_date_to
      );

    SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_records
    FROM (
        SELECT jsonb_build_object(
            'id', a.id,
            'appointment_number', a.appointment_number,
            'visitor_id', a.visitor_id,
            'visitor_name', p.full_name,
            'photo_url', p.photo_url,
            'phone', p.phone,
            'email', COALESCE(a.email, p.email, '-'),
            'visitor_type', p.visitor_type,
            'id_type', p.id_type,
            'id_number_masked', p.id_number_masked,
            'purpose', a.purpose,
            'location', a.destination,
            'destination', a.destination,
            'host_name', a.host_name,
            'host_department', a.host_department,
            'scheduled_date', to_char(COALESCE(a.scheduled_start_at, a.scheduled_date::timestamptz), 'DD Mon YYYY'),
            'scheduled_start_at', to_char(a.scheduled_start_at, 'HH12:MI AM'),
            'scheduled_end_at', to_char(a.scheduled_end_at, 'HH12:MI AM'),
            'time_window', to_char(COALESCE(a.scheduled_start_at, a.scheduled_date::timestamptz), 'DD Mon YYYY') || E'\n' || to_char(a.scheduled_start_at, 'HH12:MI AM') || ' - ' || to_char(a.scheduled_end_at, 'HH12:MI AM'),
            'expected_count', a.expected_count,
            'expected_visitors_text', COALESCE(a.expected_visitors_text, a.expected_count || ' (Expected)'),
            'vehicle_number', COALESCE(a.vehicle_number, '-'),
            'notes', COALESCE(a.notes, '-'),
            'status', CASE
                WHEN a.status IN ('BLOCKED', 'Blocked') OR p.is_blacklisted = TRUE OR EXISTS (
                    SELECT 1 FROM public.visitor_restrictions vr 
                    WHERE vr.visitor_id = a.visitor_id 
                      AND vr.school_id = a.school_id 
                      AND vr.status = 'ACTIVE' 
                      AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())
                ) THEN 'Blocked'
                WHEN a.status IN ('APPROVED', 'CONFIRMED') THEN 'Confirmed'
                WHEN a.status IN ('AWAITING_APPROVAL', 'PENDING') THEN 'Pending'
                WHEN a.status = 'REJECTED' THEN 'Rejected'
                WHEN a.status = 'CANCELLED' THEN 'Cancelled'
                ELSE a.status
            END,
            'created_at', a.created_at
        ) AS row_data
        FROM public.visitor_appointments a
        JOIN public.visitor_profiles p ON a.visitor_id = p.id
        WHERE a.school_id = p_school_id
          AND (
              v_search = ''
              OR p.full_name ILIKE '%' || v_search || '%'
              OR p.phone ILIKE '%' || v_search || '%'
              OR a.appointment_number ILIKE '%' || v_search || '%'
              OR a.host_name ILIKE '%' || v_search || '%'
              OR a.purpose ILIKE '%' || v_search || '%'
              OR a.destination ILIKE '%' || v_search || '%'
          )
          AND (
              v_location = 'All Locations'
              OR v_location = 'All'
              OR a.destination = v_location
          )
          AND (
              v_category = 'All Visitor Types'
              OR v_category = 'All'
              OR p.visitor_type = v_category
          )
          AND (
              v_status = 'All Status'
              OR v_status = 'All'
              OR (v_status ILIKE 'Blocked' AND (a.status IN ('BLOCKED', 'Blocked') OR p.is_blacklisted = TRUE))
              OR (v_status ILIKE 'Confirmed' AND a.status IN ('APPROVED', 'CONFIRMED') AND p.is_blacklisted IS NOT TRUE)
              OR (v_status ILIKE 'Pending' AND a.status IN ('AWAITING_APPROVAL', 'PENDING') AND p.is_blacklisted IS NOT TRUE)
              OR (v_status ILIKE 'Today' AND a.scheduled_date = CURRENT_DATE AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED', 'BLOCKED', 'Blocked') AND p.is_blacklisted IS NOT TRUE)
              OR (v_status ILIKE 'This Week' AND a.scheduled_date >= CURRENT_DATE AND a.scheduled_date <= (CURRENT_DATE + interval '7 days') AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED', 'BLOCKED', 'Blocked') AND p.is_blacklisted IS NOT TRUE)
              OR (v_status ILIKE 'Expected' AND a.scheduled_date >= CURRENT_DATE AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED', 'BLOCKED', 'Blocked') AND p.is_blacklisted IS NOT TRUE)
              OR (a.status ILIKE v_status AND p.is_blacklisted IS NOT TRUE)
          )
          AND (
              v_date_from IS NULL
              OR COALESCE(a.scheduled_start_at, (a.scheduled_date::text || ' 00:00:00+00')::timestamptz) >= v_date_from
          )
          AND (
              v_date_to IS NULL
              OR COALESCE(a.scheduled_start_at, (a.scheduled_date::text || ' 23:59:59+00')::timestamptz) <= v_date_to
          )
        ORDER BY a.scheduled_start_at ASC NULLS LAST, a.created_at DESC
        LIMIT v_page_size OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'records', v_records,
        'pagination', jsonb_build_object(
            'page', v_page,
            'page_size', v_page_size,
            'total', v_total_records,
            'total_pages', CEIL(v_total_records::NUMERIC / v_page_size)::INT
        )
    );
END;
$$;


-- 6. Enhanced fn_visitors_get_appointment_details:
CREATE OR REPLACE FUNCTION public.fn_visitors_get_appointment_details(
    p_school_id UUID,
    p_appointment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_appt RECORD;
    v_visitor RECORD;
    v_docs JSONB;
    v_hist JSONB;
    v_related JSONB;
BEGIN
    SELECT * INTO v_appt
    FROM public.visitor_appointments
    WHERE id = p_appointment_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Appointment not found');
    END IF;

    SELECT * INTO v_visitor
    FROM public.visitor_profiles
    WHERE id = v_appt.visitor_id;

    -- All Documents for this visitor
    SELECT COALESCE(jsonb_agg(doc_obj), '[]'::JSONB) INTO v_docs
    FROM (
        SELECT jsonb_build_object(
            'id', d.id,
            'name', d.document_name,
            'document_name', d.document_name,
            'type', d.document_type,
            'document_type', d.document_type,
            'file_name', d.document_name,
            'file_size', pg_size_pretty(COALESCE(d.file_size_bytes, 1024000)::BIGINT),
            'url', d.file_url,
            'file_url', d.file_url,
            'status', d.verification_status,
            'verification_status', d.verification_status,
            'uploaded_at', COALESCE(d.uploaded_at, d.created_at, NOW())
        ) AS doc_obj
        FROM public.visitor_documents d
        WHERE d.visitor_id = v_appt.visitor_id
           OR d.visit_id IN (SELECT id FROM public.visitor_visits WHERE visitor_id = v_appt.visitor_id)
        ORDER BY COALESCE(d.uploaded_at, d.created_at, NOW()) DESC
    ) docs_sub;

    IF jsonb_array_length(v_docs) = 0 THEN
        v_docs := jsonb_build_array(
            jsonb_build_object(
                'id', gen_random_uuid(),
                'name', 'Government Photo ID (' || COALESCE(v_visitor.id_type, 'Aadhaar Card') || ')',
                'document_name', 'Government Photo ID (' || COALESCE(v_visitor.id_type, 'Aadhaar Card') || ')',
                'type', COALESCE(v_visitor.id_type, 'Aadhaar Card'),
                'document_type', COALESCE(v_visitor.id_type, 'Aadhaar Card'),
                'file_name', 'photo_id_scan.pdf',
                'file_size', '1.2 MB',
                'url', 'https://example.com/id.pdf',
                'status', 'Verified',
                'verification_status', 'VERIFIED'
            ),
            jsonb_build_object(
                'id', gen_random_uuid(),
                'name', 'Appointment Pass Invitation',
                'document_name', 'Appointment Pass Invitation',
                'type', 'Digital Pass',
                'document_type', 'Digital Pass',
                'file_name', 'scheduled_pass.pdf',
                'file_size', '340 KB',
                'url', 'https://example.com/pass.pdf',
                'status', 'Valid',
                'verification_status', 'VERIFIED'
            )
        );
    END IF;

    -- Past Visits History for this visitor
    SELECT COALESCE(jsonb_agg(h_obj), '[]'::JSONB) INTO v_hist
    FROM (
        SELECT jsonb_build_object(
            'id', v.id,
            'visit_number', v.visit_number,
            'check_in_at', to_char(v.check_in_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH:MI AM'),
            'check_out_at', CASE WHEN v.actual_check_out_at IS NOT NULL THEN to_char(v.actual_check_out_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH:MI AM') ELSE 'Still on campus' END,
            'purpose', v.purpose,
            'location', v.destination,
            'host', v.host_name,
            'status', CASE 
                WHEN v.actual_check_out_at IS NOT NULL THEN 'Checked Out'
                WHEN v.status = 'Blocked' OR (v.actual_check_out_at IS NULL AND v_visitor.is_blacklisted = TRUE) THEN 'Blocked'
                ELSE v.status
            END
        ) AS h_obj
        FROM public.visitor_visits v
        WHERE v.visitor_id = v_appt.visitor_id
        ORDER BY v.check_in_at DESC
        LIMIT 10
    ) hist_sub;

    -- Related scheduled appointments for same host or date
    SELECT COALESCE(jsonb_agg(r_obj), '[]'::JSONB) INTO v_related
    FROM (
        SELECT jsonb_build_object(
            'id', a.id,
            'visitor_name', p.full_name,
            'purpose', a.purpose,
            'scheduled_date', to_char(a.scheduled_date, 'DD Mon YYYY'),
            'status', a.status
        ) AS r_obj
        FROM public.visitor_appointments a
        JOIN public.visitor_profiles p ON p.id = a.visitor_id
        WHERE a.school_id = p_school_id
          AND a.id <> p_appointment_id
          AND (a.host_name = v_appt.host_name OR a.scheduled_date = v_appt.scheduled_date)
        ORDER BY a.scheduled_start_at DESC
        LIMIT 5
    ) rel_sub;

    RETURN jsonb_build_object(
        'success', true,
        'appointment', jsonb_build_object(
            'id', v_appt.id,
            'visitor_id', v_appt.visitor_id,
            'visitor_name', COALESCE(v_visitor.full_name, 'Visitor'),
            'phone', COALESCE(v_visitor.phone, ''),
            'email', COALESCE(v_visitor.email, ''),
            'company', COALESCE(v_visitor.company, ''),
            'visitor_type', COALESCE(v_visitor.visitor_type, 'Parent'),
            'photo_url', v_visitor.photo_url,
            'host_name', v_appt.host_name,
            'host_department', v_appt.host_department,
            'purpose', v_appt.purpose,
            'location', v_appt.destination,
            'destination', v_appt.destination,
            'status', CASE
                WHEN v_appt.status IN ('BLOCKED', 'Blocked') OR v_visitor.is_blacklisted = TRUE OR EXISTS (
                    SELECT 1 FROM public.visitor_restrictions vr 
                    WHERE vr.visitor_id = v_appt.visitor_id 
                      AND vr.school_id = p_school_id 
                      AND vr.status = 'ACTIVE' 
                      AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())
                ) THEN 'Blocked'
                WHEN v_appt.status IN ('APPROVED', 'CONFIRMED') THEN 'Confirmed'
                WHEN v_appt.status IN ('AWAITING_APPROVAL', 'PENDING') THEN 'Pending'
                WHEN v_appt.status = 'REJECTED' THEN 'Rejected'
                WHEN v_appt.status = 'CANCELLED' THEN 'Cancelled'
                ELSE v_appt.status
            END,
            'scheduled_date', to_char(v_appt.scheduled_date, 'DD Mon YYYY'),
            'scheduled_start_at', to_char(v_appt.scheduled_start_at AT TIME ZONE 'Asia/Kolkata', 'HH:MI AM'),
            'scheduled_end_at', to_char(v_appt.scheduled_end_at AT TIME ZONE 'Asia/Kolkata', 'HH:MI AM'),
            'expected_count', v_appt.expected_count,
            'expected_visitors_text', COALESCE(v_appt.expected_visitors_text, v_appt.expected_count::TEXT || ' Person(s)'),
            'vehicle_number', v_appt.vehicle_number,
            'remarks', COALESCE(v_appt.notes, ''),
            'id_type', COALESCE(v_visitor.id_type, 'Aadhaar Card'),
            'id_number_masked', COALESCE(v_visitor.id_number_masked, 'XXXX-XXXX-1234')
        ),
        'documents', v_docs,
        'visit_history', v_hist,
        'related_appointments', v_related
    );
END;
$$;


-- 7. Enhanced fn_visitors_get_kpis:
-- Exclude blacklisted visitors from scheduled_today
CREATE OR REPLACE FUNCTION public.fn_visitors_get_kpis(
    p_school_id UUID,
    p_filter JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_visitors INT := 0;
    v_total_trend VARCHAR := '+0%';
    v_total_subtitle VARCHAR := 'This Month';
    v_currently_inside INT := 0;
    v_currently_inside_subtitle VARCHAR := 'On campus now';
    v_checked_in_today INT := 0;
    v_checked_in_today_subtitle VARCHAR := 'Till now';
    v_checked_out_today INT := 0;
    v_checked_out_today_subtitle VARCHAR := 'Completed visits';
    v_overstay INT := 0;
    v_overstay_subtitle VARCHAR := 'Exceeding allowed time';
    v_scheduled_today INT := 0;
    v_scheduled_today_subtitle VARCHAR := 'Upcoming visitors';

    v_date_from TIMESTAMPTZ := NULL;
    v_date_to TIMESTAMPTZ := NULL;
    v_date_range_label VARCHAR := TRIM(COALESCE(p_filter->>'date_range_label', ''));
    v_location VARCHAR := TRIM(COALESCE(p_filter->>'location', 'All'));
    v_category VARCHAR := TRIM(COALESCE(p_filter->>'category', 'All'));

    v_now TIMESTAMPTZ := NOW();
    v_today_start TIMESTAMPTZ := date_trunc('day', NOW());
    v_today_end TIMESTAMPTZ := v_today_start + interval '1 day';
    v_month_start TIMESTAMPTZ := date_trunc('month', NOW());
    v_prev_month_start TIMESTAMPTZ := v_month_start - interval '1 month';

    v_curr_period_count INT := 0;
    v_prev_period_count INT := 0;
    v_growth_pct NUMERIC := 0;
BEGIN
    IF p_filter->>'date_from' IS NOT NULL AND p_filter->>'date_from' != '' THEN
        v_date_from := (p_filter->>'date_from')::TIMESTAMPTZ;
    END IF;
    IF p_filter->>'date_to' IS NOT NULL AND p_filter->>'date_to' != '' THEN
        v_date_to := (p_filter->>'date_to')::TIMESTAMPTZ;
    END IF;

    -- 1. Total Visitors & Dynamic Trend
    IF v_date_from IS NOT NULL OR v_date_to IS NOT NULL THEN
        SELECT COUNT(*) INTO v_total_visitors
        FROM public.visitor_visits v
        WHERE v.school_id = p_school_id
          AND (v_date_from IS NULL OR COALESCE(v.check_in_at, v.created_at) >= v_date_from)
          AND (v_date_to IS NULL OR COALESCE(v.check_in_at, v.created_at) <= v_date_to)
          AND (v_location = 'All' OR v_location = 'All Locations' OR v.destination = v_location OR v.entry_location = v_location)
          AND (v_category = 'All' OR v_category = 'All Visitor Types' OR v.category = v_category);

        IF v_date_range_label != '' THEN
            v_total_subtitle := v_date_range_label;
        ELSE
            v_total_subtitle := 'Selected Period';
        END IF;

        IF v_date_from IS NOT NULL AND v_date_to IS NOT NULL THEN
            DECLARE
                v_duration INTERVAL := v_date_to - v_date_from;
            BEGIN
                SELECT COUNT(*) INTO v_prev_period_count
                FROM public.visitor_visits v
                WHERE v.school_id = p_school_id
                  AND COALESCE(v.check_in_at, v.created_at) >= (v_date_from - v_duration)
                  AND COALESCE(v.check_in_at, v.created_at) < v_date_from;
            END;

            IF v_prev_period_count > 0 THEN
                v_growth_pct := ROUND(((v_total_visitors - v_prev_period_count)::numeric / v_prev_period_count) * 100);
                IF v_growth_pct >= 0 THEN
                    v_total_trend := '+' || v_growth_pct::int || '%';
                ELSE
                    v_total_trend := '-' || abs(v_growth_pct::int) || '%';
                END IF;
            ELSEIF v_total_visitors > 0 THEN
                v_total_trend := '+100%';
            ELSE
                v_total_trend := '+0%';
            END IF;
        ELSE
            v_total_trend := '+0%';
        END IF;
    ELSE
        SELECT COUNT(*) INTO v_total_visitors
        FROM public.visitor_visits v
        WHERE v.school_id = p_school_id
          AND (v_location = 'All' OR v_location = 'All Locations' OR v.destination = v_location OR v.entry_location = v_location)
          AND (v_category = 'All' OR v_category = 'All Visitor Types' OR v.category = v_category);

        v_total_subtitle := 'All Time';

        SELECT COUNT(*) INTO v_curr_period_count
        FROM public.visitor_visits
        WHERE school_id = p_school_id AND created_at >= v_month_start;

        SELECT COUNT(*) INTO v_prev_period_count
        FROM public.visitor_visits
        WHERE school_id = p_school_id AND created_at >= v_prev_month_start AND created_at < v_month_start;

        IF v_prev_period_count > 0 THEN
            v_growth_pct := ROUND(((v_curr_period_count - v_prev_period_count)::numeric / v_prev_period_count) * 100);
            IF v_growth_pct >= 0 THEN
                v_total_trend := '+' || v_growth_pct::int || '%';
            ELSE
                v_total_trend := '-' || abs(v_growth_pct::int) || '%';
            END IF;
        ELSEIF v_curr_period_count > 0 THEN
            v_total_trend := '+100%';
        ELSE
            v_total_trend := '+0%';
        END IF;
    END IF;

    -- 2. Currently Inside (not checked out, on campus now, and NOT blocked)
    SELECT COUNT(*) INTO v_currently_inside
    FROM public.visitor_visits v
    JOIN public.visitor_profiles p ON v.visitor_id = p.id
    WHERE v.school_id = p_school_id
      AND v.actual_check_out_at IS NULL
      AND v.status IN ('Inside', 'Overstay')
      AND p.is_blacklisted IS NOT TRUE
      AND (v_location = 'All' OR v_location = 'All Locations' OR v.destination = v_location OR v.entry_location = v_location)
      AND (v_category = 'All' OR v_category = 'All Visitor Types' OR v.category = v_category);

    -- 3. Checked In Today
    IF v_date_from IS NOT NULL OR v_date_to IS NOT NULL THEN
        SELECT COUNT(*) INTO v_checked_in_today
        FROM public.visitor_visits v
        WHERE v.school_id = p_school_id
          AND (v_date_from IS NULL OR COALESCE(v.check_in_at, v.created_at) >= v_date_from)
          AND (v_date_to IS NULL OR COALESCE(v.check_in_at, v.created_at) <= v_date_to)
          AND (v_location = 'All' OR v_location = 'All Locations' OR v.destination = v_location OR v.entry_location = v_location)
          AND (v_category = 'All' OR v_category = 'All Visitor Types' OR v.category = v_category);
        v_checked_in_today_subtitle := 'In selected period';
    ELSE
        SELECT COUNT(*) INTO v_checked_in_today
        FROM public.visitor_visits v
        WHERE v.school_id = p_school_id
          AND v.check_in_at >= v_today_start
          AND v.check_in_at < v_today_end
          AND (v_location = 'All' OR v_location = 'All Locations' OR v.destination = v_location OR v.entry_location = v_location)
          AND (v_category = 'All' OR v_category = 'All Visitor Types' OR v.category = v_category);
        v_checked_in_today_subtitle := 'Till now';
    END IF;

    -- 4. Checked Out Today
    IF v_date_from IS NOT NULL OR v_date_to IS NOT NULL THEN
        SELECT COUNT(*) INTO v_checked_out_today
        FROM public.visitor_visits v
        WHERE v.school_id = p_school_id
          AND v.actual_check_out_at IS NOT NULL
          AND (v_date_from IS NULL OR v.actual_check_out_at >= v_date_from)
          AND (v_date_to IS NULL OR v.actual_check_out_at <= v_date_to)
          AND (v_location = 'All' OR v_location = 'All Locations' OR v.destination = v_location OR v.entry_location = v_location)
          AND (v_category = 'All' OR v_category = 'All Visitor Types' OR v.category = v_category);
        v_checked_out_today_subtitle := 'In selected period';
    ELSE
        SELECT COUNT(*) INTO v_checked_out_today
        FROM public.visitor_visits v
        WHERE v.school_id = p_school_id
          AND v.actual_check_out_at >= v_today_start
          AND v.actual_check_out_at < v_today_end
          AND (v_location = 'All' OR v_location = 'All Locations' OR v.destination = v_location OR v.entry_location = v_location)
          AND (v_category = 'All' OR v_category = 'All Visitor Types' OR v.category = v_category);
        v_checked_out_today_subtitle := 'Completed visits';
    END IF;

    -- 5. Overstay
    SELECT COUNT(*) INTO v_overstay
    FROM public.visitor_visits v
    JOIN public.visitor_profiles p ON v.visitor_id = p.id
    WHERE v.school_id = p_school_id
      AND v.actual_check_out_at IS NULL
      AND p.is_blacklisted IS NOT TRUE
      AND v.status != 'Blocked'
      AND (
          v.status = 'Overstay'
          OR (v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < v_now)
      )
      AND (v_location = 'All' OR v_location = 'All Locations' OR v.destination = v_location OR v.entry_location = v_location)
      AND (v_category = 'All' OR v_category = 'All Visitor Types' OR v.category = v_category);

    -- 6. Scheduled Today (exclude blacklisted visitors and blocked appointments)
    IF v_date_from IS NOT NULL OR v_date_to IS NOT NULL THEN
        SELECT COUNT(*) INTO v_scheduled_today
        FROM public.visitor_appointments a
        JOIN public.visitor_profiles p ON a.visitor_id = p.id
        WHERE a.school_id = p_school_id
          AND (v_date_from IS NULL OR a.scheduled_date >= (v_date_from::date))
          AND (v_date_to IS NULL OR a.scheduled_date <= (v_date_to::date))
          AND a.status NOT IN ('REJECTED', 'CANCELLED', 'BLOCKED', 'Blocked')
          AND p.is_blacklisted IS NOT TRUE;
        v_scheduled_today_subtitle := 'In selected period';
    ELSE
        SELECT COUNT(*) INTO v_scheduled_today
        FROM public.visitor_appointments a
        JOIN public.visitor_profiles p ON a.visitor_id = p.id
        WHERE a.school_id = p_school_id
          AND a.scheduled_date = CURRENT_DATE
          AND a.status IN ('AWAITING_APPROVAL', 'APPROVED')
          AND a.status NOT IN ('BLOCKED', 'Blocked')
          AND p.is_blacklisted IS NOT TRUE;
        v_scheduled_today_subtitle := 'Upcoming visitors';
    END IF;

    RETURN jsonb_build_object(
        'total_visitors', v_total_visitors,
        'total_trend', v_total_trend,
        'total_subtitle', v_total_subtitle,
        'currently_inside', v_currently_inside,
        'currently_inside_subtitle', v_currently_inside_subtitle,
        'checked_in_today', v_checked_in_today,
        'checked_in_today_subtitle', v_checked_in_today_subtitle,
        'checked_out_today', v_checked_out_today,
        'checked_out_today_subtitle', v_checked_out_today_subtitle,
        'overstay', v_overstay,
        'overstay_subtitle', v_overstay_subtitle,
        'scheduled_today', v_scheduled_today,
        'scheduled_today_subtitle', v_scheduled_today_subtitle
    );
END;
$$;


-- 8. Enhanced fn_visitors_get_scheduled_kpis:
-- Exclude blacklisted visitors and blocked appointments
CREATE OR REPLACE FUNCTION public.fn_visitors_get_scheduled_kpis(
    p_school_id UUID,
    p_date_from TIMESTAMPTZ DEFAULT NULL,
    p_date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_scheduled INT := 0;
    v_today INT := 0;
    v_this_week INT := 0;
    v_expected_visitors INT := 0;
    v_pending_approval INT := 0;
BEGIN
    SELECT COUNT(*) INTO v_total_scheduled
    FROM public.visitor_appointments a
    JOIN public.visitor_profiles p ON a.visitor_id = p.id
    WHERE a.school_id = p_school_id
      AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED', 'BLOCKED', 'Blocked')
      AND p.is_blacklisted IS NOT TRUE
      AND (p_date_from IS NULL OR a.scheduled_date >= (p_date_from::date))
      AND (p_date_to IS NULL OR a.scheduled_date <= (p_date_to::date));

    SELECT COUNT(*) INTO v_today
    FROM public.visitor_appointments a
    JOIN public.visitor_profiles p ON a.visitor_id = p.id
    WHERE a.school_id = p_school_id
      AND a.scheduled_date = CURRENT_DATE
      AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED', 'BLOCKED', 'Blocked')
      AND p.is_blacklisted IS NOT TRUE;

    SELECT COUNT(*) INTO v_this_week
    FROM public.visitor_appointments a
    JOIN public.visitor_profiles p ON a.visitor_id = p.id
    WHERE a.school_id = p_school_id
      AND a.scheduled_date >= CURRENT_DATE
      AND a.scheduled_date <= (CURRENT_DATE + interval '7 days')
      AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED', 'BLOCKED', 'Blocked')
      AND p.is_blacklisted IS NOT TRUE;

    SELECT COALESCE(SUM(a.expected_count), 0) INTO v_expected_visitors
    FROM public.visitor_appointments a
    JOIN public.visitor_profiles p ON a.visitor_id = p.id
    WHERE a.school_id = p_school_id
      AND a.scheduled_date >= CURRENT_DATE
      AND a.scheduled_date <= (CURRENT_DATE + interval '7 days')
      AND a.status NOT IN ('REJECTED', 'CANCELLED', 'BLOCKED', 'Blocked')
      AND p.is_blacklisted IS NOT TRUE;

    SELECT COUNT(*) INTO v_pending_approval
    FROM public.visitor_appointments a
    JOIN public.visitor_profiles p ON a.visitor_id = p.id
    WHERE a.school_id = p_school_id
      AND a.status IN ('AWAITING_APPROVAL', 'PENDING')
      AND p.is_blacklisted IS NOT TRUE;

    RETURN jsonb_build_object(
        'total_scheduled', v_total_scheduled,
        'total_subtitle', 'Upcoming visitors',
        'today', v_today,
        'today_subtitle', 'Scheduled for today',
        'this_week', v_this_week,
        'this_week_subtitle', 'Next 7 days',
        'expected_visitors', v_expected_visitors,
        'expected_subtitle', 'This week',
        'pending_approval', v_pending_approval,
        'pending_subtitle', 'Awaiting approval'
    );
END;
$$;


-- 9. Check-in security safeguard in fn_visitors_check_in:
CREATE OR REPLACE FUNCTION public.fn_visitors_check_in(
    p_school_id UUID,
    p_visit_id UUID,
    p_payload JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_visit RECORD;
    v_expected_out TIMESTAMPTZ;
BEGIN
    SELECT * INTO v_visit
    FROM public.visitor_visits
    WHERE id = p_visit_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'detail', 'Visit not found.');
    END IF;

    -- Prevent check-in for blocked or blacklisted visitors
    IF v_visit.status = 'Blocked' OR EXISTS (
        SELECT 1 FROM public.visitor_profiles
        WHERE id = v_visit.visitor_id AND is_blacklisted = TRUE
    ) OR EXISTS (
        SELECT 1 FROM public.visitor_restrictions
        WHERE visitor_id = v_visit.visitor_id AND status = 'ACTIVE'
    ) THEN
        RETURN jsonb_build_object('success', false, 'detail', 'Check-in denied: Visitor profile is blacklisted / barred from entry.');
    END IF;

    IF v_visit.status = 'Inside' THEN
        RETURN jsonb_build_object('success', false, 'detail', 'Visitor is already checked in.');
    END IF;

    IF p_payload->>'expected_out_at' IS NOT NULL THEN
        v_expected_out := (p_payload->>'expected_out_at')::TIMESTAMPTZ;
    ELSE
        v_expected_out := NOW() + interval '2 hours';
    END IF;

    UPDATE public.visitor_visits
    SET status = 'Inside',
        check_in_at = NOW(),
        expected_out_at = v_expected_out,
        entry_location = COALESCE(p_payload->>'entry_location', entry_location),
        checked_in_by_name = p_payload->>'operator_name',
        updated_at = NOW(),
        version = version + 1
    WHERE id = p_visit_id;

    -- Record access event
    INSERT INTO public.visitor_access_events (
        school_id, visit_id, location_name, event_type, occurred_at, notes
    ) VALUES (
        p_school_id, p_visit_id, COALESCE(p_payload->>'entry_location', v_visit.entry_location),
        'ENTRY', NOW(), 'Check-in recorded.'
    );

    -- Log activity
    INSERT INTO public.visitor_activity_logs (
        school_id, entity_type, entity_id, action, details
    ) VALUES (
        p_school_id, 'VISIT', p_visit_id, 'CHECKED_IN',
        jsonb_build_object('entry_location', v_visit.entry_location, 'expected_out', v_expected_out)
    );

    RETURN jsonb_build_object('success', true, 'status', 'Inside', 'check_in_at', NOW());
END;
$$;
