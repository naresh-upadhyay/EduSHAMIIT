-- Migration 384: Complete end-to-end unblocking on lifting restriction and fix valid till date handling
-- 1. Unblocks visits and appointments when a visitor restriction is lifted.
-- 2. Restores past blocked visits and appointments for visitors whose restrictions were already lifted.
-- 3. Correctly handles Valid Till Date selection, Permanent toggle, and date parsing for restrictions.
-- 4. Ensures visits and appointments dynamically reflect unblocked status in All Visitors and Scheduled Visitors tabs.

-- ============================================================================
-- 1. DATA CLEANUP: Unblock any visits & appointments for un-blacklisted visitors
-- ============================================================================
UPDATE public.visitor_visits v
SET status = CASE WHEN v.check_in_at IS NOT NULL THEN 'Inside' ELSE 'Scheduled' END,
    remarks = TRIM(REGEXP_REPLACE(
        COALESCE(v.remarks, ''), 
        '(\s*\([^\)]*Blocked due to security blacklist[^\)]*\)|\s*Blocked due to security blacklist[^\.]*\.?)', 
        '', 
        'gi'
    )),
    updated_at = NOW()
FROM public.visitor_profiles p
WHERE v.visitor_id = p.id
  AND v.status = 'Blocked'
  AND v.actual_check_out_at IS NULL
  AND (p.is_blacklisted IS NOT TRUE OR p.is_blacklisted IS NULL)
  AND NOT EXISTS (
      SELECT 1 FROM public.visitor_restrictions vr
      WHERE vr.visitor_id = v.visitor_id
        AND vr.status = 'ACTIVE'
        AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())
  );

UPDATE public.visitor_appointments a
SET status = 'Scheduled',
    rejection_reason = NULL,
    updated_at = NOW()
FROM public.visitor_profiles p
WHERE a.visitor_id = p.id
  AND a.status IN ('BLOCKED', 'Blocked')
  AND (p.is_blacklisted IS NOT TRUE OR p.is_blacklisted IS NULL)
  AND NOT EXISTS (
      SELECT 1 FROM public.visitor_restrictions vr
      WHERE vr.visitor_id = a.visitor_id
        AND vr.status = 'ACTIVE'
        AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())
  );


-- ============================================================================
-- 2. Enhanced fn_visitors_lift_restriction: Unblocks visits & appointments
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_visitors_lift_restriction(
    p_school_id UUID,
    p_restriction_id UUID,
    p_lifted_by_name VARCHAR,
    p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_visitor_id UUID;
    v_other_active INT := 0;
BEGIN
    SELECT visitor_id INTO v_visitor_id
    FROM public.visitor_restrictions
    WHERE id = p_restriction_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'detail', 'Restriction not found.');
    END IF;

    -- Update restriction status to LIFTED
    UPDATE public.visitor_restrictions
    SET status = 'LIFTED',
        lifted_by_name = p_lifted_by_name,
        lifted_at = NOW(),
        lift_reason = p_reason,
        updated_at = NOW()
    WHERE id = p_restriction_id;

    -- Check if any other active restrictions exist for this visitor
    SELECT COUNT(*) INTO v_other_active
    FROM public.visitor_restrictions
    WHERE school_id = p_school_id 
      AND visitor_id = v_visitor_id 
      AND status = 'ACTIVE'
      AND (expires_at IS NULL OR expires_at >= NOW());

    IF v_other_active = 0 THEN
        -- Mark profile as no longer blacklisted
        UPDATE public.visitor_profiles
        SET is_blacklisted = FALSE, 
            updated_at = NOW()
        WHERE id = v_visitor_id;

        -- Unblock uncompleted visits
        UPDATE public.visitor_visits
        SET status = CASE 
                WHEN check_in_at IS NOT NULL THEN 'Inside' 
                ELSE 'Scheduled' 
            END,
            remarks = TRIM(REGEXP_REPLACE(
                COALESCE(remarks, ''), 
                '(\s*\([^\)]*Blocked due to security blacklist[^\)]*\)|\s*Blocked due to security blacklist[^\.]*\.?)', 
                '', 
                'gi'
            )),
            updated_at = NOW()
        WHERE visitor_id = v_visitor_id
          AND status = 'Blocked'
          AND actual_check_out_at IS NULL;

        -- Unblock appointments
        UPDATE public.visitor_appointments
        SET status = 'Scheduled',
            rejection_reason = NULL,
            updated_at = NOW()
        WHERE visitor_id = v_visitor_id
          AND status IN ('BLOCKED', 'Blocked');
    END IF;

    -- Log activity
    INSERT INTO public.visitor_activity_logs (
        school_id, entity_type, entity_id, action, details
    ) VALUES (
        p_school_id, 'RESTRICTION', p_restriction_id, 'LIFTED',
        jsonb_build_object('lifted_by', p_lifted_by_name, 'reason', p_reason)
    );

    RETURN jsonb_build_object('success', true, 'status', 'LIFTED');
END;
$$;


-- ============================================================================
-- 3. Enhanced fn_visitors_update_restriction: Supports date picker & permanent toggle
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_visitors_update_restriction(
    p_school_id UUID,
    p_restriction_id UUID,
    p_params JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_is_permanent BOOLEAN := NULL;
    v_expires_at TIMESTAMPTZ := NULL;
    v_valid_till_text VARCHAR := NULL;
    v_valid_till_val TEXT := COALESCE(p_params->>'valid_till', p_params->>'valid_till_text');
BEGIN
    -- Determine permanent flag
    IF p_params->>'is_permanent' IS NOT NULL THEN
        v_is_permanent := (p_params->>'is_permanent')::BOOLEAN;
    ELSIF v_valid_till_val ILIKE 'Permanent' THEN
        v_is_permanent := TRUE;
    END IF;

    IF v_is_permanent IS TRUE THEN
        v_valid_till_text := 'Permanent';
        v_expires_at := NULL;
    ELSIF v_valid_till_val IS NOT NULL AND v_valid_till_val != '' AND v_valid_till_val NOT ILIKE 'Permanent' THEN
        BEGIN
            v_expires_at := v_valid_till_val::TIMESTAMPTZ;
        EXCEPTION WHEN OTHERS THEN
            BEGIN
                v_expires_at := to_timestamp(v_valid_till_val, 'DD Mon YYYY');
            EXCEPTION WHEN OTHERS THEN
                v_expires_at := NULL;
            END;
        END;
        v_valid_till_text := COALESCE(NULLIF(p_params->>'valid_till_text', ''), CASE WHEN v_expires_at IS NOT NULL THEN to_char(v_expires_at, 'DD Mon YYYY') ELSE v_valid_till_val END);
    END IF;

    UPDATE public.visitor_restrictions
    SET reason_category = COALESCE(NULLIF(p_params->>'reason_category', ''), reason_category),
        scope_name = COALESCE(NULLIF(p_params->>'scope_name', ''), scope_name),
        remarks = COALESCE(p_params->>'remarks', remarks),
        confidential_notes = COALESCE(p_params->>'confidential_notes', p_params->>'remarks', confidential_notes),
        is_permanent = COALESCE(v_is_permanent, is_permanent),
        valid_till_text = COALESCE(v_valid_till_text, valid_till_text),
        expires_at = CASE 
            WHEN v_is_permanent IS TRUE THEN NULL 
            WHEN v_expires_at IS NOT NULL THEN v_expires_at 
            ELSE expires_at 
        END,
        review_at = CASE 
            WHEN v_is_permanent IS TRUE THEN NULL 
            WHEN v_expires_at IS NOT NULL THEN v_expires_at 
            ELSE review_at 
        END,
        updated_at = NOW()
    WHERE id = p_restriction_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'detail', 'Restriction record not found.');
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Restriction updated successfully.');
END;
$$;


-- ============================================================================
-- 4. Enhanced fn_visitors_create_restriction: Safe date parsing & permanent handling
-- ============================================================================
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
    v_review_at TIMESTAMPTZ := NULL;
    v_expires_at TIMESTAMPTZ := NULL;
    v_is_permanent BOOLEAN := FALSE;
    v_valid_till_text VARCHAR;
    v_valid_till_val TEXT := COALESCE(p_payload->>'valid_till', p_payload->>'valid_till_text');
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

    -- Calculate review date / expiration safely
    IF (p_payload->>'is_permanent')::BOOLEAN IS TRUE 
       OR v_valid_till_val ILIKE 'Permanent' THEN
        v_is_permanent := TRUE;
        v_expires_at := NULL;
        v_review_at := NULL;
        v_valid_till_text := 'Permanent';
    ELSE
        v_is_permanent := FALSE;
        IF v_valid_till_val IS NOT NULL AND v_valid_till_val != '' THEN
            BEGIN
                v_expires_at := v_valid_till_val::TIMESTAMPTZ;
            EXCEPTION WHEN OTHERS THEN
                BEGIN
                    v_expires_at := to_timestamp(v_valid_till_val, 'DD Mon YYYY');
                EXCEPTION WHEN OTHERS THEN
                    v_expires_at := NULL;
                END;
            END;
        END IF;
        IF v_expires_at IS NULL AND p_payload->>'expires_at' IS NOT NULL THEN
            BEGIN
                v_expires_at := (p_payload->>'expires_at')::TIMESTAMPTZ;
            EXCEPTION WHEN OTHERS THEN
                v_expires_at := NULL;
            END;
        END IF;
        IF v_expires_at IS NULL THEN
            v_expires_at := NOW() + (COALESCE(p_payload->>'duration_days', '30') || ' days')::INTERVAL;
        END IF;
        v_review_at := v_expires_at;
        v_valid_till_text := COALESCE(NULLIF(p_payload->>'valid_till_text', ''), to_char(v_expires_at, 'DD Mon YYYY'));
    END IF;

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
        status, requested_by_name, approved_by_name, review_at, expires_at,
        is_permanent, valid_till_text, created_at
    ) VALUES (
        p_school_id, v_visitor_id, v_full_name, v_phone,
        v_scope_type, v_scope_name, v_reason_cat,
        COALESCE(p_payload->>'confidential_notes', 'Security restriction applied.'),
        'ACTIVE',
        COALESCE(p_payload->>'requested_by_name', 'Security Officer'),
        COALESCE(p_payload->>'approved_by_name', 'Director / Principal'),
        v_review_at, v_expires_at,
        v_is_permanent, v_valid_till_text,
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


-- ============================================================================
-- 5. Enhanced fn_visitors_list_visits: Dynamic status display & filter accuracy
-- ============================================================================
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
              v.actual_check_out_at IS NULL AND (
                  p.is_blacklisted = TRUE
                  OR EXISTS (
                      SELECT 1 FROM public.visitor_restrictions vr
                      WHERE vr.visitor_id = v.visitor_id
                        AND vr.school_id = v.school_id
                        AND vr.status = 'ACTIVE'
                        AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)
                  )
              )
          ))
          OR (v_status = 'Inside' AND v.actual_check_out_at IS NULL AND (v.status IN ('Inside', 'Overstay') OR (v.status = 'Blocked' AND v.check_in_at IS NOT NULL)) AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = v.visitor_id AND vr.school_id = v.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)))
          OR (v_status = 'Checked Out' AND (v.status = 'Checked Out' OR v.actual_check_out_at IS NOT NULL))
          OR (v_status = 'Overstay' AND v.actual_check_out_at IS NULL AND (v.status = 'Overstay' OR (v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < v_now)) AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = v.visitor_id AND vr.school_id = v.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)))
          OR (v_status = 'Scheduled' AND (v.status = 'Scheduled' OR (v.status = 'Blocked' AND v.check_in_at IS NULL)) AND v.actual_check_out_at IS NULL AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = v.visitor_id AND vr.school_id = v.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)))
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
                WHEN v.actual_check_out_at IS NULL AND (
                    p.is_blacklisted = TRUE 
                    OR EXISTS (
                        SELECT 1 FROM public.visitor_restrictions vr 
                        WHERE vr.visitor_id = v.visitor_id 
                          AND vr.school_id = v.school_id 
                          AND vr.status = 'ACTIVE' 
                          AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)
                    )
                ) THEN 'Blocked'
                WHEN v.status = 'Overstay' OR (v.status = 'Inside' AND v.actual_check_out_at IS NULL AND v.expected_out_at IS NOT NULL AND v.expected_out_at < v_now) THEN 'Overstay'
                WHEN v.status = 'Blocked' THEN CASE WHEN v.check_in_at IS NOT NULL THEN 'Inside' ELSE 'Scheduled' END
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
                  v.actual_check_out_at IS NULL AND (
                      p.is_blacklisted = TRUE
                      OR EXISTS (
                          SELECT 1 FROM public.visitor_restrictions vr
                          WHERE vr.visitor_id = v.visitor_id
                            AND vr.school_id = v.school_id
                            AND vr.status = 'ACTIVE'
                            AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)
                      )
                  )
              ))
              OR (v_status = 'Inside' AND v.actual_check_out_at IS NULL AND (v.status IN ('Inside', 'Overstay') OR (v.status = 'Blocked' AND v.check_in_at IS NOT NULL)) AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = v.visitor_id AND vr.school_id = v.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)))
              OR (v_status = 'Checked Out' AND (v.status = 'Checked Out' OR v.actual_check_out_at IS NOT NULL))
              OR (v_status = 'Overstay' AND v.actual_check_out_at IS NULL AND (v.status = 'Overstay' OR (v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < v_now)) AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = v.visitor_id AND vr.school_id = v.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)))
              OR (v_status = 'Scheduled' AND (v.status = 'Scheduled' OR (v.status = 'Blocked' AND v.check_in_at IS NULL)) AND v.actual_check_out_at IS NULL AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = v.visitor_id AND vr.school_id = v.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)))
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


-- ============================================================================
-- 6. Enhanced fn_visitors_list_appointments: Dynamic status display & filter
-- ============================================================================
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
          OR (v_status ILIKE 'Blocked' AND (
              p.is_blacklisted = TRUE
              OR EXISTS (
                  SELECT 1 FROM public.visitor_restrictions vr
                  WHERE vr.visitor_id = a.visitor_id
                    AND vr.school_id = a.school_id
                    AND vr.status = 'ACTIVE'
                    AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())
              )
          ))
          OR (v_status ILIKE 'Confirmed' AND a.status IN ('APPROVED', 'CONFIRMED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
          OR (v_status ILIKE 'Pending' AND a.status IN ('AWAITING_APPROVAL', 'PENDING') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
          OR (v_status ILIKE 'Today' AND a.scheduled_date = CURRENT_DATE AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
          OR (v_status ILIKE 'This Week' AND a.scheduled_date >= CURRENT_DATE AND a.scheduled_date <= (CURRENT_DATE + interval '7 days') AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
          OR (v_status ILIKE 'Expected' AND a.scheduled_date >= CURRENT_DATE AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
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
                WHEN (
                    p.is_blacklisted = TRUE OR EXISTS (
                        SELECT 1 FROM public.visitor_restrictions vr 
                        WHERE vr.visitor_id = a.visitor_id 
                          AND vr.school_id = a.school_id 
                          AND vr.status = 'ACTIVE' 
                          AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())
                    )
                ) THEN 'Blocked'
                WHEN a.status IN ('APPROVED', 'CONFIRMED') THEN 'Confirmed'
                WHEN a.status IN ('AWAITING_APPROVAL', 'PENDING') THEN 'Pending'
                WHEN a.status = 'REJECTED' THEN 'Rejected'
                WHEN a.status = 'CANCELLED' THEN 'Cancelled'
                WHEN a.status IN ('BLOCKED', 'Blocked') THEN 'Scheduled'
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
              OR (v_status ILIKE 'Blocked' AND (
                  p.is_blacklisted = TRUE
                  OR EXISTS (
                      SELECT 1 FROM public.visitor_restrictions vr 
                      WHERE vr.visitor_id = a.visitor_id 
                        AND vr.school_id = a.school_id 
                        AND vr.status = 'ACTIVE' 
                        AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())
                  )
              ))
              OR (v_status ILIKE 'Confirmed' AND a.status IN ('APPROVED', 'CONFIRMED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
              OR (v_status ILIKE 'Pending' AND a.status IN ('AWAITING_APPROVAL', 'PENDING') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
              OR (v_status ILIKE 'Today' AND a.scheduled_date = CURRENT_DATE AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
              OR (v_status ILIKE 'This Week' AND a.scheduled_date >= CURRENT_DATE AND a.scheduled_date <= (CURRENT_DATE + interval '7 days') AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
              OR (v_status ILIKE 'Expected' AND a.scheduled_date >= CURRENT_DATE AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
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


-- ============================================================================
-- 7. Enhanced fn_visitors_get_visit_details: Dynamic status display
-- ============================================================================
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

    -- Complete Visit History for this visitor
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
            WHEN actual_check_out_at IS NULL AND (
                v_profile.is_blacklisted = TRUE OR EXISTS (
                    SELECT 1 FROM public.visitor_restrictions vr 
                    WHERE vr.visitor_id = v_profile.id 
                      AND vr.school_id = p_school_id 
                      AND vr.status = 'ACTIVE' 
                      AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())
                )
            ) THEN 'Blocked'
            WHEN status = 'Blocked' THEN CASE WHEN check_in_at IS NOT NULL THEN 'Inside' ELSE 'Scheduled' END
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
                WHEN v_visit.actual_check_out_at IS NULL AND (
                    v_profile.is_blacklisted = TRUE 
                    OR EXISTS (
                        SELECT 1 FROM public.visitor_restrictions vr 
                        WHERE vr.visitor_id = v_profile.id 
                          AND vr.school_id = p_school_id 
                          AND vr.status = 'ACTIVE' 
                          AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())
                    )
                ) THEN 'Blocked'
                WHEN v_visit.status = 'Overstay' OR (v_visit.status = 'Inside' AND v_visit.expected_out_at IS NOT NULL AND v_visit.expected_out_at < NOW()) THEN 'Overstay'
                WHEN v_visit.status = 'Blocked' THEN CASE WHEN v_visit.check_in_at IS NOT NULL THEN 'Inside' ELSE 'Scheduled' END
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
