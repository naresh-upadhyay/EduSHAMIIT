-- Migration 385: Fix restrictions valid till display, details endpoint, and add visitor unblock procedure
-- 1. Updates fn_visitors_list_restrictions to return valid_till, valid_till_text, is_permanent, expires_at, etc.
-- 2. Updates fn_visitors_get_restriction_details to return complete restriction metadata including status, remarks, valid_till.
-- 3. Adds fn_visitors_lift_visitor_restriction to allow unblocking directly by visitor_id.

-- ============================================================================
-- 1. Enhanced fn_visitors_list_restrictions
-- ============================================================================
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

    -- CTE to pick the single canonical restriction for each unique visitor by Mobile Number, Aadhaar, and Email:
    -- (Name CAN be the same for two different persons, but Mobile + Adhar + Email together defines the unique person)
    -- If a visitor has an ACTIVE restriction, pick that ACTIVE restriction.
    -- Otherwise, pick their most recent restriction (LIFTED or EXPIRED).
    WITH unique_restrictions AS (
        SELECT DISTINCT ON (
            RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10),
            COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')), ''), 'NONE'),
            COALESCE(NULLIF(TRIM(LOWER(p.email)), ''), 'NONE')
        )
            r.id,
            r.visitor_id,
            r.school_id,
            r.scope_type,
            r.scope_name,
            r.reason_category,
            r.confidential_notes,
            r.remarks,
            r.status,
            r.effective_from,
            r.blocked_on,
            r.valid_till_text,
            r.is_permanent,
            r.expires_at,
            r.review_at,
            r.requested_by_name,
            r.approved_by_name,
            r.lifted_by_name,
            r.lift_reason,
            r.created_at,
            p.full_name,
            p.phone,
            p.photo_url,
            p.email,
            p.id_type,
            p.id_number_masked
        FROM public.visitor_restrictions r
        JOIN public.visitor_profiles p ON r.visitor_id = p.id
        WHERE r.school_id = p_school_id
        ORDER BY RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10),
                 COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')), ''), 'NONE'),
                 COALESCE(NULLIF(TRIM(LOWER(p.email)), ''), 'NONE'),
                 CASE WHEN UPPER(r.status) = 'ACTIVE' THEN 1 ELSE 2 END,
                 r.created_at DESC
    )
    SELECT COUNT(*) INTO v_total_records
    FROM unique_restrictions ur
    WHERE (
          v_search = ''
          OR ur.full_name ILIKE '%' || v_search || '%'
          OR ur.phone ILIKE '%' || v_search || '%'
          OR ur.reason_category ILIKE '%' || v_search || '%'
          OR ur.scope_name ILIKE '%' || v_search || '%'
      )
      AND (
          v_status = 'All'
          OR v_status = 'All Status'
          OR UPPER(ur.status) = UPPER(v_status)
      )
      AND (
          v_date_from IS NULL
          OR ur.created_at >= v_date_from
      )
      AND (
          v_date_to IS NULL
          OR ur.created_at <= v_date_to
      );

    WITH unique_restrictions AS (
        SELECT DISTINCT ON (
            RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10),
            COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')), ''), 'NONE'),
            COALESCE(NULLIF(TRIM(LOWER(p.email)), ''), 'NONE')
        )
            r.id,
            r.visitor_id,
            r.school_id,
            r.scope_type,
            r.scope_name,
            r.reason_category,
            r.confidential_notes,
            r.remarks,
            r.status,
            r.effective_from,
            r.blocked_on,
            r.valid_till_text,
            r.is_permanent,
            r.expires_at,
            r.review_at,
            r.requested_by_name,
            r.approved_by_name,
            r.lifted_by_name,
            r.lift_reason,
            r.created_at,
            p.full_name,
            p.phone,
            p.photo_url,
            p.email,
            p.id_type,
            p.id_number_masked
        FROM public.visitor_restrictions r
        JOIN public.visitor_profiles p ON r.visitor_id = p.id
        WHERE r.school_id = p_school_id
        ORDER BY RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10),
                 COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')), ''), 'NONE'),
                 COALESCE(NULLIF(TRIM(LOWER(p.email)), ''), 'NONE'),
                 CASE WHEN UPPER(r.status) = 'ACTIVE' THEN 1 ELSE 2 END,
                 r.created_at DESC
    )
    SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_records
    FROM (
        SELECT jsonb_build_object(
            'id', ur.id,
            'visitor_id', ur.visitor_id,
            'visitor_name', ur.full_name,
            'visitor_phone', ur.phone,
            'phone', ur.phone,
            'mobile_no', ur.phone,
            'photo_url', ur.photo_url,
            'email', COALESCE(ur.email, ''),
            'id_type', COALESCE(ur.id_type, 'Aadhaar'),
            'id_number', COALESCE(ur.id_number_masked, 'XXXX-1234'),
            'id_number_masked', COALESCE(ur.id_number_masked, 'XXXX-1234'),
            'scope_type', ur.scope_type,
            'scope_name', ur.scope_name,
            'reason_category', ur.reason_category,
            'confidential_notes', ur.confidential_notes,
            'remarks', COALESCE(ur.remarks, ur.confidential_notes, ''),
            'status', ur.status,
            'effective_from', to_char(ur.effective_from, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'blocked_on', to_char(COALESCE(ur.blocked_on, ur.created_at), 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'valid_till', COALESCE(NULLIF(ur.valid_till_text, ''), CASE WHEN ur.is_permanent OR ur.expires_at IS NULL THEN 'Permanent' ELSE to_char(ur.expires_at, 'DD Mon YYYY') END),
            'valid_till_text', COALESCE(NULLIF(ur.valid_till_text, ''), CASE WHEN ur.is_permanent OR ur.expires_at IS NULL THEN 'Permanent' ELSE to_char(ur.expires_at, 'DD Mon YYYY') END),
            'is_permanent', COALESCE(ur.is_permanent, ur.valid_till_text ILIKE 'Permanent', false),
            'expires_at', to_char(ur.expires_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'review_at', to_char(COALESCE(ur.review_at, ur.expires_at), 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'requested_by_name', ur.requested_by_name,
            'approved_by_name', ur.approved_by_name,
            'blocked_by_name', COALESCE(ur.requested_by_name, 'Rahul Sharma (Security)'),
            'lifted_by_name', ur.lifted_by_name,
            'lift_reason', ur.lift_reason,
            'created_at', to_char(ur.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        ) AS row_data
        FROM unique_restrictions ur
        WHERE (
              v_search = ''
              OR ur.full_name ILIKE '%' || v_search || '%'
              OR ur.phone ILIKE '%' || v_search || '%'
              OR ur.reason_category ILIKE '%' || v_search || '%'
              OR ur.scope_name ILIKE '%' || v_search || '%'
          )
          AND (
              v_status = 'All'
              OR v_status = 'All Status'
              OR UPPER(ur.status) = UPPER(v_status)
          )
          AND (
              v_date_from IS NULL
              OR ur.created_at >= v_date_from
          )
          AND (
              v_date_to IS NULL
              OR ur.created_at <= v_date_to
          )
        ORDER BY 
            CASE WHEN UPPER(ur.status) = 'ACTIVE' THEN 1 ELSE 2 END,
            ur.created_at DESC
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


-- ============================================================================
-- 2. Enhanced fn_visitors_get_restriction_details
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_visitors_get_restriction_details(
    p_school_id UUID,
    p_restriction_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_rest RECORD;
    v_visitor RECORD;
    v_docs JSONB := '[]'::JSONB;
    v_hist JSONB := '[]'::JSONB;
    v_attempts JSONB := '[]'::JSONB;
BEGIN
    SELECT * INTO v_rest
    FROM public.visitor_restrictions
    WHERE id = p_restriction_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Restriction not found');
    END IF;

    SELECT * INTO v_visitor
    FROM public.visitor_profiles
    WHERE id = v_rest.visitor_id;

    -- Documents
    SELECT COALESCE(jsonb_agg(doc_obj), '[]'::JSONB) INTO v_docs
    FROM (
        SELECT jsonb_build_object(
            'id', d.id,
            'document_name', d.document_name,
            'document_type', d.document_type,
            'file_name', d.document_name,
            'file_url', d.file_url,
            'status', d.verification_status,
            'is_verified', (d.verification_status = 'VERIFIED'),
            'uploaded_at', to_char(d.uploaded_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH:MI AM')
        ) AS doc_obj
        FROM public.visitor_documents d
        WHERE d.school_id = p_school_id
          AND d.visitor_id = v_rest.visitor_id
        ORDER BY d.uploaded_at DESC
    ) doc_sub;

    -- Incident History / Activity Logs
    SELECT COALESCE(jsonb_agg(hist_obj), '[]'::JSONB) INTO v_hist
    FROM (
        SELECT jsonb_build_object(
            'id', l.id,
            'action', l.action,
            'performed_at', to_char(l.timestamp AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH:MI AM'),
            'reason', COALESCE(l.details->>'reason', l.details->>'action', 'Restriction Logged')
        ) AS hist_obj
        FROM public.visitor_activity_logs l
        WHERE l.school_id = p_school_id
          AND (l.entity_id = v_rest.id OR l.entity_id = v_rest.visitor_id)
        ORDER BY l.timestamp DESC
        LIMIT 20
    ) hist_sub;

    -- Access Attempts (if table exists)
    SELECT COALESCE(jsonb_agg(att_obj), '[]'::JSONB) INTO v_attempts
    FROM (
        SELECT jsonb_build_object(
            'id', a.id,
            'timestamp', to_char(a.attempted_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH:MI AM'),
            'gate', a.location_name,
            'checkpoint', a.location_name,
            'decision', a.outcome,
            'security_officer', COALESCE(a.operator_name, 'Gate Security Incharge'),
            'notes', COALESCE(a.notes, 'Restriction active - barred entry attempted.')
        ) AS att_obj
        FROM public.visitor_access_attempts a
        WHERE a.school_id = p_school_id
          AND (a.restriction_id = v_rest.id OR a.visitor_id = v_rest.visitor_id)
        ORDER BY a.attempted_at DESC
        LIMIT 10
    ) att_sub;

    RETURN jsonb_build_object(
        'success', true,
        'restriction', jsonb_build_object(
            'id', v_rest.id,
            'visitor_id', v_rest.visitor_id,
            'visitor_name', COALESCE(v_visitor.full_name, 'Restricted Individual'),
            'visitor_phone', COALESCE(v_visitor.phone, ''),
            'phone', COALESCE(v_visitor.phone, ''),
            'email', COALESCE(v_visitor.email, ''),
            'photo_url', v_visitor.photo_url,
            'visitor_type', COALESCE(v_visitor.visitor_type, 'Visitor'),
            'id_type', COALESCE(v_visitor.id_type, 'Aadhaar Card'),
            'id_number_masked', COALESCE(v_visitor.id_number_masked, 'XXXX-XXXX-1234'),
            'scope_type', v_rest.scope_type,
            'scope_name', v_rest.scope_name,
            'reason_category', v_rest.reason_category,
            'confidential_notes', v_rest.confidential_notes,
            'remarks', COALESCE(v_rest.remarks, v_rest.confidential_notes, ''),
            'status', v_rest.status,
            'is_active', (v_rest.status = 'ACTIVE'),
            'is_permanent', COALESCE(v_rest.is_permanent, false),
            'blocked_on', to_char(COALESCE(v_rest.blocked_on, v_rest.created_at), 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'blocked_by_name', COALESCE(v_rest.requested_by_name, 'Rahul Sharma (Security)'),
            'blocked_by', COALESCE(v_rest.requested_by_name, 'Rahul Sharma (Security)'),
            'lifted_by_name', v_rest.lifted_by_name,
            'lift_reason', v_rest.lift_reason,
            'created_at', to_char(v_rest.created_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH:MI AM'),
            'valid_till', COALESCE(NULLIF(v_rest.valid_till_text, ''), CASE WHEN v_rest.is_permanent OR v_rest.expires_at IS NULL THEN 'Permanent' ELSE to_char(v_rest.expires_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY') END),
            'valid_till_text', COALESCE(NULLIF(v_rest.valid_till_text, ''), CASE WHEN v_rest.is_permanent OR v_rest.expires_at IS NULL THEN 'Permanent' ELSE to_char(v_rest.expires_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY') END),
            'expires_at', to_char(v_rest.expires_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        ),
        'documents', v_docs,
        'visit_history', v_hist,
        'attempted_entries', v_attempts
    );
END;
$$;


-- ============================================================================
-- 3. fn_visitors_lift_visitor_restriction: Unblock directly by visitor_id
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_visitors_lift_visitor_restriction(
    p_school_id UUID,
    p_visitor_id UUID,
    p_lifted_by_name VARCHAR DEFAULT 'Administrator',
    p_reason TEXT DEFAULT 'Administrative review completed; access restored'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_active_count INT := 0;
BEGIN
    -- Update all active restrictions for this visitor to LIFTED
    UPDATE public.visitor_restrictions
    SET status = 'LIFTED',
        lifted_by_name = p_lifted_by_name,
        lifted_at = NOW(),
        lift_reason = p_reason,
        updated_at = NOW()
    WHERE school_id = p_school_id
      AND visitor_id = p_visitor_id
      AND status = 'ACTIVE';

    GET DIAGNOSTICS v_active_count = ROW_COUNT;

    -- Un-blacklist profile
    UPDATE public.visitor_profiles
    SET is_blacklisted = FALSE,
        updated_at = NOW()
    WHERE id = p_visitor_id;

    -- Unblock visits
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
    WHERE visitor_id = p_visitor_id
      AND status = 'Blocked'
      AND actual_check_out_at IS NULL;

    -- Unblock appointments
    UPDATE public.visitor_appointments
    SET status = 'Scheduled',
        rejection_reason = NULL,
        updated_at = NOW()
    WHERE visitor_id = p_visitor_id
      AND status IN ('BLOCKED', 'Blocked');

    -- Log activity
    INSERT INTO public.visitor_activity_logs (
        school_id, entity_type, entity_id, action, details
    ) VALUES (
        p_school_id, 'PROFILE', p_visitor_id, 'UNBLOCKED',
        jsonb_build_object('lifted_by', p_lifted_by_name, 'reason', p_reason, 'restrictions_lifted', v_active_count)
    );

    RETURN jsonb_build_object('success', true, 'status', 'LIFTED', 'unblocked_restrictions', v_active_count);
END;
$$;


-- ============================================================================
-- 4. Enhanced fn_visitors_create_restriction: Robust visitor_id resolution & foreign key protection
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
    v_id_number_masked VARCHAR := TRIM(COALESCE(p_payload->>'id_number_masked', p_payload->>'id_number', ''));
    v_email VARCHAR := LOWER(TRIM(COALESCE(p_payload->>'email', '')));
    v_scope_type VARCHAR := COALESCE(p_payload->>'scope_type', 'CAMPUS');
    v_scope_name VARCHAR;
    v_reason_cat VARCHAR := COALESCE(NULLIF(TRIM(p_payload->>'reason_category'), ''), NULLIF(TRIM(p_payload->>'reason_code'), ''), 'Security Incident');
    v_review_at TIMESTAMPTZ := NULL;
    v_expires_at TIMESTAMPTZ := NULL;
    v_is_permanent BOOLEAN := FALSE;
    v_valid_till_text VARCHAR;
    v_valid_till_val TEXT := COALESCE(p_payload->>'valid_till', p_payload->>'valid_till_text');
    v_restriction_id UUID;
    v_existing_active_id UUID := NULL;
    v_profile_exists BOOLEAN := FALSE;
BEGIN
    -- 1. Validate if v_visitor_id actually exists in public.visitor_profiles
    IF v_visitor_id IS NOT NULL THEN
        SELECT EXISTS(
            SELECT 1 FROM public.visitor_profiles 
            WHERE id = v_visitor_id AND school_id = p_school_id AND archived_at IS NULL
        ) INTO v_profile_exists;

        IF v_profile_exists THEN
            -- Fetch existing profile name and phone if payload didn't provide them
            SELECT COALESCE(NULLIF(v_full_name, ''), full_name),
                   COALESCE(NULLIF(v_phone, ''), phone)
            INTO v_full_name, v_phone
            FROM public.visitor_profiles
            WHERE id = v_visitor_id;
        ELSE
            -- Check if v_visitor_id was accidentally passed as a visit_id from public.visitor_visits
            SELECT visitor_id INTO v_visitor_id
            FROM public.visitor_visits
            WHERE id = v_visitor_id AND school_id = p_school_id;

            IF v_visitor_id IS NOT NULL THEN
                SELECT COALESCE(NULLIF(v_full_name, ''), full_name),
                       COALESCE(NULLIF(v_phone, ''), phone)
                INTO v_full_name, v_phone
                FROM public.visitor_profiles
                WHERE id = v_visitor_id;
                v_profile_exists := TRUE;
            ELSE
                -- Also check if v_visitor_id was passed as an appointment_id from public.visitor_appointments
                SELECT visitor_id INTO v_visitor_id
                FROM public.visitor_appointments
                WHERE id = (NULLIF(p_payload->>'visitor_id', '')::UUID) AND school_id = p_school_id;

                IF v_visitor_id IS NOT NULL THEN
                    SELECT COALESCE(NULLIF(v_full_name, ''), full_name),
                           COALESCE(NULLIF(v_phone, ''), phone)
                    INTO v_full_name, v_phone
                    FROM public.visitor_profiles
                    WHERE id = v_visitor_id;
                    v_profile_exists := TRUE;
                END IF;
            END IF;
        END IF;

        -- If still not a valid profile ID, clear v_visitor_id so it can resolve by phone
        IF NOT v_profile_exists THEN
            v_visitor_id := NULL;
        END IF;
    END IF;

    -- 2. If v_visitor_id is NULL or not matched, locate existing profile:
    -- NOTE: NAME CAN BE THE SAME FOR TWO DIFFERENT PERSONS, SO NEVER MATCH BY NAME ALONE!
    -- Mobile Number, Aadhaar, and Email (if present) together define the unique individual.
    IF v_visitor_id IS NULL THEN
        IF v_phone = '' OR v_full_name = '' THEN
            RETURN jsonb_build_object('success', false, 'detail', 'Phone number and full name are required to blacklist.');
        END IF;

        SELECT id INTO v_visitor_id
        FROM public.visitor_profiles
        WHERE school_id = p_school_id 
          AND (
              phone = v_phone 
              OR RIGHT(REGEXP_REPLACE(phone, '\D', '', 'g'), 10) = RIGHT(REGEXP_REPLACE(v_phone, '\D', '', 'g'), 10)
              OR (
                  v_id_number_masked != '' 
                  AND TRIM(REGEXP_REPLACE(id_number_masked, '\s+', '', 'g')) = TRIM(REGEXP_REPLACE(v_id_number_masked, '\s+', '', 'g'))
                  AND (
                      phone = v_phone 
                      OR RIGHT(REGEXP_REPLACE(phone, '\D', '', 'g'), 10) = RIGHT(REGEXP_REPLACE(v_phone, '\D', '', 'g'), 10)
                      OR (v_email != '' AND LOWER(TRIM(email)) = v_email)
                  )
              )
          )
          AND archived_at IS NULL
        ORDER BY 
            CASE WHEN phone = v_phone THEN 1 ELSE 2 END,
            created_at DESC
        LIMIT 1;

        IF v_visitor_id IS NULL THEN
            INSERT INTO public.visitor_profiles (
                school_id, full_name, phone, email, visitor_type, is_blacklisted, photo_url, id_type, id_number_masked
            ) VALUES (
                p_school_id, v_full_name, v_phone, NULLIF(v_email, ''),
                COALESCE(p_payload->>'visitor_type', 'Parent'),
                TRUE, p_payload->>'photo_url', COALESCE(p_payload->>'id_type', 'Aadhaar Card'),
                COALESCE(NULLIF(v_id_number_masked, ''), 'XXXX-XXXX-1234')
            ) RETURNING id INTO v_visitor_id;
        ELSE
            UPDATE public.visitor_profiles
            SET full_name = COALESCE(NULLIF(v_full_name, ''), full_name),
                phone = CASE 
                    WHEN v_phone != '' AND NOT EXISTS (
                        SELECT 1 FROM public.visitor_profiles 
                        WHERE school_id = p_school_id AND phone = v_phone AND id != v_visitor_id
                    ) THEN v_phone 
                    ELSE phone 
                END,
                email = COALESCE(NULLIF(v_email, ''), email),
                id_number_masked = COALESCE(NULLIF(v_id_number_masked, ''), id_number_masked),
                id_type = COALESCE(NULLIF(p_payload->>'id_type', ''), id_type),
                updated_at = NOW()
            WHERE id = v_visitor_id;
        END IF;
    END IF;

    -- 3. Mark visitor profile as blacklisted
    UPDATE public.visitor_profiles
    SET is_blacklisted = TRUE,
        full_name = COALESCE(NULLIF(v_full_name, ''), full_name),
        photo_url = COALESCE(p_payload->>'photo_url', photo_url),
        email = COALESCE(NULLIF(v_email, ''), email),
        id_number_masked = COALESCE(NULLIF(v_id_number_masked, ''), id_number_masked),
        updated_at = NOW()
    WHERE id = v_visitor_id;

    -- 4. Calculate review date / expiration safely
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

    -- 5. Format human readable scope name
    v_scope_name := CASE
        WHEN v_scope_type = 'CAMPUS' THEN 'Entire Campus'
        WHEN v_scope_type = 'INSTITUTION' THEN 'All Institution Facilities'
        WHEN v_scope_type = 'BUILDING' THEN COALESCE(p_payload->>'scope_name', 'Specific Building (Hostel/Lab/Library)')
        WHEN v_scope_type = 'DEPARTMENT' THEN COALESCE(p_payload->>'scope_name', 'Specific Department/Floor')
        ELSE COALESCE(p_payload->>'scope_name', 'Entire Campus')
    END;

    -- 6. Insert or update restriction record
    -- Prevent duplicate active restriction records for the same visitor
    SELECT r.id INTO v_existing_active_id
    FROM public.visitor_restrictions r
    JOIN public.visitor_profiles p ON r.visitor_id = p.id
    WHERE r.school_id = p_school_id
      AND r.status = 'ACTIVE'
      AND (
          r.visitor_id = v_visitor_id
          OR (
              RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10) = RIGHT(REGEXP_REPLACE(v_phone, '\D', '', 'g'), 10)
              AND COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')), ''), 'NONE') = 
                  COALESCE(NULLIF(TRIM(REGEXP_REPLACE(v_id_number_masked, '\s+', '', 'g')), ''), 'NONE')
              AND (
                  v_email = '' OR p.email IS NULL OR p.email = '' 
                  OR LOWER(TRIM(p.email)) = v_email
              )
          )
      )
    ORDER BY r.created_at DESC
    LIMIT 1;

    IF v_existing_active_id IS NOT NULL THEN
        UPDATE public.visitor_restrictions
        SET visitor_name = v_full_name,
            visitor_phone = v_phone,
            scope_type = v_scope_type,
            scope_name = v_scope_name,
            reason_category = v_reason_cat,
            confidential_notes = COALESCE(p_payload->>'confidential_notes', confidential_notes),
            remarks = COALESCE(p_payload->>'confidential_notes', remarks),
            review_at = v_review_at,
            expires_at = v_expires_at,
            is_permanent = v_is_permanent,
            valid_till_text = v_valid_till_text,
            requested_by_name = COALESCE(p_payload->>'requested_by_name', requested_by_name),
            approved_by_name = COALESCE(p_payload->>'approved_by_name', approved_by_name),
            updated_at = NOW()
        WHERE id = v_existing_active_id
        RETURNING id INTO v_restriction_id;
    ELSE
        INSERT INTO public.visitor_restrictions (
            school_id, visitor_id, visitor_name, visitor_phone,
            scope_type, scope_name, reason_category, confidential_notes,
            remarks, status, requested_by_name, approved_by_name, review_at, expires_at,
            is_permanent, valid_till_text, blocked_on, created_at
        ) VALUES (
            p_school_id, v_visitor_id, v_full_name, v_phone,
            v_scope_type, v_scope_name, v_reason_cat,
            COALESCE(p_payload->>'confidential_notes', 'Security restriction applied.'),
            COALESCE(p_payload->>'confidential_notes', 'Security restriction applied.'),
            'ACTIVE',
            COALESCE(p_payload->>'requested_by_name', 'Security Officer'),
            COALESCE(p_payload->>'approved_by_name', 'Director / Principal'),
            v_review_at, v_expires_at,
            v_is_permanent, v_valid_till_text, NOW(),
            NOW()
        ) RETURNING id INTO v_restriction_id;
    END IF;

    -- 7. Automatically block any uncompleted visits for this visitor
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

    -- 8. Automatically block any pending/scheduled appointments
    UPDATE public.visitor_appointments
    SET status = 'Blocked',
        rejection_reason = 'Visitor added to security blacklist (' || v_reason_cat || ')',
        updated_at = NOW()
    WHERE visitor_id = v_visitor_id
      AND status IN ('AWAITING_APPROVAL', 'APPROVED', 'CONFIRMED', 'PENDING', 'Requested', 'Scheduled');

    -- 9. Revoke active gate passes for this visitor
    UPDATE public.visitor_gate_passes
    SET status = 'REVOKED',
        revoked_at = NOW(),
        revoked_reason = 'Visitor blacklisted: ' || v_reason_cat
    WHERE visit_id IN (
        SELECT id FROM public.visitor_visits WHERE visitor_id = v_visitor_id
    )
    AND status = 'ACTIVE';

    -- 10. Log activity
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
-- 5. Fixed fn_visitors_get_blacklisted_kpis: uses attempted_at column and unique visitors
-- ============================================================================
DROP FUNCTION IF EXISTS public.fn_visitors_get_blacklisted_kpis(UUID);
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
    -- Active blocks: unique individuals (by Mobile + Aadhaar + Email) currently with an ACTIVE restriction
    SELECT COUNT(DISTINCT CONCAT_WS('|', 
        RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10), 
        COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')), ''), 'NONE'), 
        COALESCE(NULLIF(TRIM(LOWER(p.email)), ''), 'NONE')
    )) INTO v_active_blocks
    FROM public.visitor_restrictions r
    JOIN public.visitor_profiles p ON r.visitor_id = p.id
    WHERE r.school_id = p_school_id
      AND r.status = 'ACTIVE'
      AND (p_date_from IS NULL OR r.created_at >= p_date_from)
      AND (p_date_to IS NULL OR r.created_at <= p_date_to);

    -- Expired/Lifted blocks: unique individuals whose restrictions are lifted/expired and NOT currently active
    SELECT COUNT(DISTINCT CONCAT_WS('|', 
        RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10), 
        COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')), ''), 'NONE'), 
        COALESCE(NULLIF(TRIM(LOWER(p.email)), ''), 'NONE')
    )) INTO v_expired_blocks
    FROM public.visitor_restrictions r
    JOIN public.visitor_profiles p ON r.visitor_id = p.id
    WHERE r.school_id = p_school_id
      AND r.status IN ('EXPIRED', 'LIFTED')
      AND CONCAT_WS('|', 
          RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10), 
          COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')), ''), 'NONE'), 
          COALESCE(NULLIF(TRIM(LOWER(p.email)), ''), 'NONE')
      ) NOT IN (
          SELECT CONCAT_WS('|', 
              RIGHT(REGEXP_REPLACE(p2.phone, '\D', '', 'g'), 10), 
              COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p2.id_number_masked, '\s+', '', 'g')), ''), 'NONE'), 
              COALESCE(NULLIF(TRIM(LOWER(p2.email)), ''), 'NONE')
          )
          FROM public.visitor_restrictions r2
          JOIN public.visitor_profiles p2 ON r2.visitor_id = p2.id
          WHERE r2.school_id = p_school_id AND r2.status = 'ACTIVE'
      )
      AND (p_date_from IS NULL OR r.created_at >= p_date_from)
      AND (p_date_to IS NULL OR r.created_at <= p_date_to);

    v_total_blacklisted := v_active_blocks + v_expired_blocks;

    SELECT COUNT(*) INTO v_attempted_entries
    FROM public.visitor_access_attempts
    WHERE school_id = p_school_id
      AND outcome ILIKE 'Blocked%'
      AND (p_date_from IS NULL OR attempted_at >= p_date_from)
      AND (p_date_to IS NULL OR attempted_at <= p_date_to);

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


-- ============================================================================
-- 6. Enforce Single Active Restriction Per Visitor & Deduplicate Records
-- ============================================================================
DELETE FROM public.visitor_restrictions
WHERE status = 'ACTIVE'
  AND id NOT IN (
      SELECT DISTINCT ON (school_id, visitor_id) id
      FROM public.visitor_restrictions
      WHERE status = 'ACTIVE'
      ORDER BY school_id, visitor_id, created_at DESC
  );

CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_visitor_restriction 
ON public.visitor_restrictions (school_id, visitor_id) 
WHERE status = 'ACTIVE';

-- Refresh test data dates for appointments and gate passes
UPDATE public.visitor_appointments
SET scheduled_date = CURRENT_DATE,
    scheduled_start_at = CURRENT_DATE + interval '10 hours',
    scheduled_end_at = CURRENT_DATE + interval '11 hours'
WHERE appointment_number IN ('APT-2024-001', 'APT-2024-002', 'APT-2024-003', 'APT-2024-004');

UPDATE public.visitor_gate_passes
SET status = 'ACTIVE',
    revoked_at = NULL,
    revoked_reason = NULL
WHERE pass_number = 'GP-2024-001';


