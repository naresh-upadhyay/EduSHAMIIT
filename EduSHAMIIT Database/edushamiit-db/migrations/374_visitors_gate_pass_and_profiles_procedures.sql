-- ============================================================================
-- Migration: 374_visitors_gate_pass_and_profiles_procedures.sql
-- Description: Production-Grade Stored Procedures and Schema Hardening for:
--              1. Batch Gate Pass Generation (fn_visitors_generate_batch_gate_passes)
--              2. Gate Pass Verification & Authorization (fn_visitors_verify_gate_pass)
--              3. Gate Pass Check-In / Check-Out QR Action (fn_visitors_scan_gate_pass_action)
--              4. Visitor Profiles Listing with Visit Counts (fn_visitors_list_profiles)
--              5. Inline Visitor Profile Creation / Upsert (fn_visitors_upsert_profile)
--              6. Campus Checkpoints / Locations Query (fn_visitors_get_locations)
--              7. Schema columns, constraints, and case-insensitive performance indexes
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Schema Hardening & Column Guarantees
-- ----------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.visitor_visits
    ADD COLUMN IF NOT EXISTS photo_url TEXT;

ALTER TABLE IF EXISTS public.visitor_profiles
    ALTER COLUMN photo_url TYPE TEXT;

-- High-performance case-insensitive indexes for instant QR scanning and lookups
CREATE INDEX IF NOT EXISTS idx_visitor_visits_pass_ref_lower
    ON public.visitor_visits (school_id, LOWER(pass_reference));

CREATE INDEX IF NOT EXISTS idx_visitor_visits_number_lower
    ON public.visitor_visits (school_id, LOWER(visit_number));

CREATE INDEX IF NOT EXISTS idx_visitor_gate_passes_num_lower
    ON public.visitor_gate_passes (school_id, LOWER(pass_number));

CREATE INDEX IF NOT EXISTS idx_visitor_gate_passes_token_hash
    ON public.visitor_gate_passes (token_hash);


-- ----------------------------------------------------------------------------
-- 2. Stored Procedure: Batch Gate Pass Generation
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_visitors_generate_batch_gate_passes(
    p_school_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_visitor_ids JSONB;
    v_vid_text TEXT;
    v_vid UUID;
    v_prof RECORD;
    v_duration INT;
    v_location TEXT;
    v_host_name TEXT;
    v_host_dept TEXT;
    v_host_phone TEXT;
    v_purpose TEXT;
    v_auto_check_in BOOLEAN;
    v_year TEXT;
    v_base_seq INT;
    v_visit_number TEXT;
    v_pass_number TEXT;
    v_expires_at TIMESTAMPTZ;
    v_status TEXT;
    v_check_in_time TIMESTAMPTZ;
    v_visit_id UUID;
    v_pass_id UUID;
    v_token_raw TEXT;
    v_token_hash TEXT;
    v_created_passes JSONB := '[]'::JSONB;
    v_pass_item JSONB;
BEGIN
    v_visitor_ids := p_payload->'visitor_ids';
    IF v_visitor_ids IS NULL OR jsonb_array_length(v_visitor_ids) = 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'At least one visitor profile must be selected.'
        );
    END IF;

    v_duration := COALESCE(
        (p_payload->>'duration_hours')::INT,
        (p_payload->>'expected_duration_hours')::INT,
        4
    );
    v_location := COALESCE(
        p_payload->>'destination',
        p_payload->>'location',
        p_payload->>'entry_location',
        'Main Gate'
    );
    v_host_name := COALESCE(p_payload->>'host_name', 'Administration');
    v_host_dept := COALESCE(p_payload->>'host_department', 'General');
    v_host_phone := p_payload->>'host_phone';
    v_purpose := COALESCE(p_payload->>'purpose', 'Official Visit');
    v_auto_check_in := COALESCE((p_payload->>'auto_check_in')::BOOLEAN, false);

    v_year := to_char(NOW(), 'YYYY');

    -- Calculate base sequence for visits in this institution
    SELECT COALESCE(MAX(SUBSTRING(visit_number FROM '[0-9]+$')::INT), 0)
    INTO v_base_seq
    FROM public.visitor_visits
    WHERE school_id = p_school_id;

    FOR v_vid_text IN SELECT jsonb_array_elements_text(v_visitor_ids)
    LOOP
        BEGIN
            v_vid := v_vid_text::UUID;
        EXCEPTION WHEN OTHERS THEN
            CONTINUE;
        END;

        SELECT * INTO v_prof
        FROM public.visitor_profiles
        WHERE id = v_vid AND school_id = p_school_id AND archived_at IS NULL;

        IF NOT FOUND THEN
            CONTINUE;
        END IF;

        IF v_prof.is_blacklisted THEN
            -- Skip restricted visitors from automated batch issuance
            CONTINUE;
        END IF;

        v_base_seq := v_base_seq + 1;
        v_visit_number := 'VIS-' || v_year || '-' || lpad(v_base_seq::TEXT, 4, '0');
        v_pass_number := 'GP-' || v_year || '-' || lpad(v_base_seq::TEXT, 4, '0');
        v_expires_at := NOW() + (v_duration || ' hours')::INTERVAL;
        v_status := CASE WHEN v_auto_check_in THEN 'Inside' ELSE 'Scheduled' END;
        v_check_in_time := CASE WHEN v_auto_check_in THEN NOW() ELSE NULL END;

        -- 1. Insert Visit Record
        INSERT INTO public.visitor_visits (
            school_id, visit_number, visitor_id, visit_type, purpose, category,
            entry_location, destination, host_name, host_department, host_phone,
            check_in_at, expected_out_at, status, vehicle_number, vehicle_type,
            accompanying_count, remarks, pass_reference, photo_url
        ) VALUES (
            p_school_id, v_visit_number, v_vid, 'PRE_SCHEDULED', v_purpose, COALESCE(v_prof.visitor_type, 'Parent'),
            v_location, v_location, v_host_name, v_host_dept, v_host_phone,
            v_check_in_time, v_expires_at, v_status, p_payload->>'vehicle_number', p_payload->>'vehicle_type',
            0, p_payload->>'remarks', v_pass_number, v_prof.photo_url
        ) RETURNING id INTO v_visit_id;

        -- 2. Insert Gate Pass Record
        v_token_raw := v_pass_number || '-' || v_visit_id::TEXT || '-' || p_school_id::TEXT;
        v_token_hash := encode(digest(v_token_raw::BYTEA, 'sha256'), 'hex');

        INSERT INTO public.visitor_gate_passes (
            school_id, visit_id, pass_number, token_hash, status,
            issued_at, expires_at, print_count
        ) VALUES (
            p_school_id, v_visit_id, v_pass_number, v_token_hash, 'ACTIVE',
            NOW(), v_expires_at, 1
        ) RETURNING id INTO v_pass_id;

        -- 3. Record Initial Access Event if Auto Check-In
        IF v_auto_check_in THEN
            INSERT INTO public.visitor_access_events (
                school_id, visit_id, location_name, event_type, occurred_at, notes
            ) VALUES (
                p_school_id, v_visit_id, v_location, 'ENTRY', NOW(), 'Checked in at gate pass batch issuance.'
            );
        END IF;

        -- Build serialized pass object
        v_pass_item := jsonb_build_object(
            'pass_id', v_pass_id::TEXT,
            'pass_number', v_pass_number,
            'visit_id', v_visit_id::TEXT,
            'visit_number', v_visit_number,
            'visitor_id', v_vid::TEXT,
            'visitor_name', v_prof.full_name,
            'visitor_type', COALESCE(v_prof.visitor_type, 'Parent'),
            'phone', v_prof.phone,
            'company', COALESCE(v_prof.company, ''),
            'photo_url', v_prof.photo_url,
            'destination', v_location,
            'host_name', v_host_name,
            'purpose', v_purpose,
            'issued_at', to_char(NOW(), 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
            'expires_at', to_char(v_expires_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
            'check_in_at', CASE WHEN v_check_in_time IS NOT NULL THEN to_char(v_check_in_time, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') ELSE NULL END,
            'status', 'ACTIVE',
            'visit_status', v_status,
            'qr_code_url', '/api/visitors/gate-passes/' || v_pass_number || '/qr.png'
        );

        v_created_passes := v_created_passes || jsonb_build_array(v_pass_item);
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Successfully generated ' || jsonb_array_length(v_created_passes) || ' official gate passes.',
        'data', v_created_passes
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 3. Stored Procedure: Unified Gate Pass Verification
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_visitors_verify_gate_pass(
    p_school_id UUID,
    p_token_or_ref TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_token TEXT;
    v_json JSONB;
    v_rec RECORD;
    v_action TEXT;
    v_data JSONB;
BEGIN
    v_token := TRIM(p_token_or_ref);
    IF v_token ILIKE '%.png' THEN
        v_token := SUBSTRING(v_token FROM 1 FOR LENGTH(v_token) - 4);
    END IF;

    -- Handle raw JSON strings passed from camera scanners
    IF v_token LIKE '{%' THEN
        BEGIN
            v_json := v_token::JSONB;
            v_token := COALESCE(
                v_json->>'pass_number',
                v_json->>'passReference',
                v_json->>'visit_number',
                v_json->>'id',
                v_token
            );
            v_token := TRIM(v_token);
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

    -- Unified LEFT JOIN lookup on passes and visits
    SELECT COALESCE(gp.id, v.id) as id,
           COALESCE(gp.pass_number, v.pass_reference, v.visit_number) as pass_number,
           COALESCE(gp.status, 'ACTIVE') as pass_status,
           COALESCE(gp.expires_at, v.expected_out_at, NOW() + INTERVAL '1 day') as expires_at,
           COALESCE(gp.issued_at, v.created_at) as issued_at,
           v.id as visit_id, v.visit_number, v.status as visit_status, v.destination,
           v.check_in_at, v.expected_out_at, v.actual_check_out_at, v.host_name, v.purpose,
           p.id as visitor_id, p.full_name as visitor_name, p.phone, p.visitor_type,
           p.company, p.photo_url, p.is_blacklisted
    INTO v_rec
    FROM public.visitor_visits v
    LEFT JOIN public.visitor_gate_passes gp ON (gp.visit_id = v.id OR gp.pass_number = v.pass_reference)
    JOIN public.visitor_profiles p ON v.visitor_id = p.id
    WHERE v.school_id = p_school_id
      AND (
          gp.pass_number ILIKE v_token
          OR gp.token_hash = v_token
          OR v.pass_reference ILIKE v_token
          OR v.visit_number ILIKE v_token
          OR v.id::TEXT = v_token
      )
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'is_valid', false,
            'message', 'Invalid or unrecognized gate pass ''' || v_token || '''.'
        );
    END IF;

    v_data := jsonb_build_object(
        'id', v_rec.id::TEXT,
        'pass_number', v_rec.pass_number,
        'pass_status', v_rec.pass_status,
        'expires_at', to_char(v_rec.expires_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
        'issued_at', to_char(v_rec.issued_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
        'visit_id', v_rec.visit_id::TEXT,
        'visit_number', v_rec.visit_number,
        'visit_status', v_rec.visit_status,
        'destination', v_rec.destination,
        'check_in_at', CASE WHEN v_rec.check_in_at IS NOT NULL THEN to_char(v_rec.check_in_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') ELSE NULL END,
        'expected_out_at', CASE WHEN v_rec.expected_out_at IS NOT NULL THEN to_char(v_rec.expected_out_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') ELSE NULL END,
        'actual_check_out_at', CASE WHEN v_rec.actual_check_out_at IS NOT NULL THEN to_char(v_rec.actual_check_out_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') ELSE NULL END,
        'host_name', v_rec.host_name,
        'purpose', v_rec.purpose,
        'visitor_id', v_rec.visitor_id::TEXT,
        'visitor_name', v_rec.visitor_name,
        'phone', v_rec.phone,
        'visitor_type', v_rec.visitor_type,
        'company', v_rec.company,
        'photo_url', v_rec.photo_url,
        'is_blacklisted', v_rec.is_blacklisted
    );

    IF v_rec.is_blacklisted THEN
        RETURN jsonb_build_object(
            'success', false,
            'is_valid', false,
            'is_blacklisted', true,
            'message', 'Security Alert: Visitor has an active restriction!',
            'data', v_data
        );
    END IF;

    IF v_rec.pass_status IN ('REVOKED', 'CANCELLED', 'BLOCKED') THEN
        RETURN jsonb_build_object(
            'success', false,
            'is_valid', false,
            'message', 'Gate pass has been ' || LOWER(v_rec.pass_status) || '.',
            'data', v_data
        );
    END IF;

    IF v_rec.expires_at < NOW() THEN
        RETURN jsonb_build_object(
            'success', false,
            'is_valid', false,
            'message', 'Gate pass has expired.',
            'data', v_data
        );
    END IF;

    IF v_rec.visit_status = 'Inside' OR (v_rec.check_in_at IS NOT NULL AND v_rec.actual_check_out_at IS NULL) THEN
        v_action := 'CHECK_OUT';
    ELSIF v_rec.visit_status = 'Checked Out' THEN
        v_action := 'CHECK_IN';
    ELSE
        v_action := 'CHECK_IN';
    END IF;

    v_data := v_data || jsonb_build_object('suggested_action', v_action);

    RETURN jsonb_build_object(
        'success', true,
        'is_valid', true,
        'suggested_action', v_action,
        'message', 'Gate pass ' || v_rec.pass_number || ' verified successfully for ' || v_rec.visitor_name || '.',
        'data', v_data
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 4. Stored Procedure: Execute Gate Pass Check-In / Check-Out Action
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_visitors_scan_gate_pass_action(
    p_school_id UUID,
    p_pass_number TEXT,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pass TEXT;
    v_action TEXT;
    v_visit_id UUID;
    v_visitor_name TEXT;
    v_location TEXT;
    v_operator TEXT;
    v_remarks TEXT;
    v_res JSONB;
BEGIN
    v_pass := TRIM(p_pass_number);
    IF v_pass ILIKE '%.png' THEN
        v_pass := SUBSTRING(v_pass FROM 1 FOR LENGTH(v_pass) - 4);
    END IF;

    v_action := UPPER(COALESCE(p_payload->>'action', ''));
    IF v_action NOT IN ('CHECK_IN', 'CHECK_OUT') THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Action must be CHECK_IN or CHECK_OUT.'
        );
    END IF;

    SELECT v.id, p.full_name
    INTO v_visit_id, v_visitor_name
    FROM public.visitor_visits v
    LEFT JOIN public.visitor_gate_passes gp ON (gp.visit_id = v.id OR gp.pass_number = v.pass_reference)
    JOIN public.visitor_profiles p ON v.visitor_id = p.id
    WHERE v.school_id = p_school_id
      AND (
          gp.pass_number ILIKE v_pass
          OR gp.token_hash = v_pass
          OR v.pass_reference ILIKE v_pass
          OR v.visit_number ILIKE v_pass
          OR v.id::TEXT = v_pass
      )
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Gate pass ' || v_pass || ' not found.'
        );
    END IF;

    v_location := COALESCE(
        p_payload->>'gate',
        p_payload->>'location',
        p_payload->>'entry_location',
        p_payload->>'exit_location',
        'Main Gate'
    );
    v_operator := COALESCE(p_payload->>'operator_name', 'Gate Security');
    v_remarks := p_payload->>'remarks';

    IF v_action = 'CHECK_IN' THEN
        v_res := public.fn_visitors_check_in(
            p_school_id,
            v_visit_id,
            jsonb_build_object(
                'entry_location', v_location,
                'operator_name', v_operator,
                'remarks', v_remarks
            )
        );
        IF v_res IS NOT NULL AND (v_res->>'success')::BOOLEAN = true THEN
            UPDATE public.visitor_gate_passes
            SET status = 'ACTIVE'
            WHERE visit_id = v_visit_id AND school_id = p_school_id;
        END IF;
    ELSE
        v_res := public.fn_visitors_check_out(
            p_school_id,
            v_visit_id,
            jsonb_build_object(
                'exit_location', v_location,
                'operator_name', v_operator,
                'remarks', v_remarks
            )
        );
    END IF;

    IF v_res IS NOT NULL AND (v_res->>'success')::BOOLEAN = true THEN
        RETURN jsonb_build_object(
            'success', true,
            'action', v_action,
            'message', 'Visitor ' || v_visitor_name || ' ' || (CASE WHEN v_action = 'CHECK_IN' THEN 'checked in' ELSE 'checked out' END) || ' successfully at ' || v_location || '.',
            'data', v_res
        );
    ELSE
        RETURN jsonb_build_object(
            'success', false,
            'message', COALESCE(v_res->>'detail', v_res->>'message', 'Failed to execute gate action.')
        );
    END IF;
END;
$$;


-- ----------------------------------------------------------------------------
-- 5. Stored Procedure: List Visitor Profiles with Visit Counts
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_visitors_list_profiles(
    p_school_id UUID,
    p_search TEXT DEFAULT NULL,
    p_visitor_type TEXT DEFAULT 'All',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search TEXT;
    v_type TEXT;
    v_page INT;
    v_page_size INT;
    v_offset INT;
    v_total_records INT;
    v_total_pages INT;
    v_profiles JSONB;
BEGIN
    v_search := CASE WHEN p_search IS NOT NULL AND TRIM(p_search) <> '' THEN '%' || TRIM(p_search) || '%' ELSE '%' END;
    v_type := CASE WHEN p_visitor_type IS NOT NULL AND TRIM(p_visitor_type) <> '' AND TRIM(p_visitor_type) <> 'All' THEN TRIM(p_visitor_type) ELSE 'All' END;
    v_page := GREATEST(COALESCE(p_page, 1), 1);
    v_page_size := LEAST(GREATEST(COALESCE(p_page_size, 20), 1), 100);
    v_offset := (v_page - 1) * v_page_size;

    SELECT COUNT(*) INTO v_total_records
    FROM public.visitor_profiles p
    WHERE p.school_id = p_school_id AND p.archived_at IS NULL
      AND (
          v_search = '%' OR
          p.full_name ILIKE v_search OR
          p.phone ILIKE v_search OR
          COALESCE(p.company, '') ILIKE v_search
      )
      AND (
          v_type = 'All' OR p.visitor_type = v_type
      );

    v_total_pages := CASE WHEN v_total_records > 0 THEN ((v_total_records + v_page_size - 1) / v_page_size) ELSE 1 END;

    SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::JSONB) INTO v_profiles
    FROM (
        SELECT p.id::TEXT as id,
               p.school_id::TEXT as school_id,
               p.full_name,
               p.phone,
               p.alternate_phone,
               p.email,
               p.company,
               p.designation,
               p.visitor_type,
               p.id_type,
               p.id_number_masked,
               p.verification_status,
               p.photo_url,
               p.notes,
               p.is_blacklisted,
               to_char(p.created_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') as created_at,
               to_char(p.updated_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') as updated_at,
               COALESCE((SELECT COUNT(*) FROM public.visitor_visits v WHERE v.visitor_id = p.id), 0) as total_visits,
               (SELECT to_char(MAX(check_in_at), 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') FROM public.visitor_visits v WHERE v.visitor_id = p.id) as last_visit_at
        FROM public.visitor_profiles p
        WHERE p.school_id = p_school_id AND p.archived_at IS NULL
          AND (
              v_search = '%' OR
              p.full_name ILIKE v_search OR
              p.phone ILIKE v_search OR
              COALESCE(p.company, '') ILIKE v_search
          )
          AND (
              v_type = 'All' OR p.visitor_type = v_type
          )
        ORDER BY p.updated_at DESC, p.created_at DESC
        LIMIT v_page_size OFFSET v_offset
    ) t;

    RETURN jsonb_build_object(
        'success', true,
        'data', v_profiles,
        'pagination', jsonb_build_object(
            'page', v_page,
            'page_size', v_page_size,
            'total_records', v_total_records,
            'total_pages', v_total_pages
        )
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 6. Stored Procedure: Create or Upsert Visitor Profile
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_visitors_upsert_profile(
    p_school_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_phone TEXT;
    v_name TEXT;
    v_company TEXT;
    v_type TEXT;
    v_id_type TEXT;
    v_id_num TEXT;
    v_photo TEXT;
    v_notes TEXT;
    v_existing_id UUID;
    v_rec RECORD;
BEGIN
    v_phone := TRIM(p_payload->>'phone');
    v_name := TRIM(p_payload->>'full_name');
    v_company := COALESCE(p_payload->>'company', p_payload->>'organization');
    v_type := COALESCE(p_payload->>'visitor_type', p_payload->>'category', 'Parent');
    v_id_type := COALESCE(p_payload->>'id_type', 'Aadhaar Card');
    v_id_num := COALESCE(p_payload->>'id_number_masked', p_payload->>'id_number', 'XXXX-XXXX-1234');
    v_photo := p_payload->>'photo_url';
    v_notes := p_payload->>'notes';

    IF p_payload->>'address' IS NOT NULL AND TRIM(p_payload->>'address') <> '' THEN
        IF v_notes IS NOT NULL AND TRIM(v_notes) <> '' THEN
            v_notes := v_notes || E'\nAddress: ' || TRIM(p_payload->>'address');
        ELSE
            v_notes := 'Address: ' || TRIM(p_payload->>'address');
        END IF;
    END IF;

    SELECT id INTO v_existing_id
    FROM public.visitor_profiles
    WHERE school_id = p_school_id AND phone = v_phone AND archived_at IS NULL
    LIMIT 1;

    IF FOUND THEN
        UPDATE public.visitor_profiles
        SET full_name = v_name,
            alternate_phone = COALESCE(p_payload->>'alternate_phone', alternate_phone),
            email = COALESCE(p_payload->>'email', email),
            company = COALESCE(v_company, company),
            designation = COALESCE(p_payload->>'designation', designation),
            visitor_type = COALESCE(v_type, visitor_type),
            id_type = COALESCE(v_id_type, id_type),
            id_number_masked = COALESCE(v_id_num, id_number_masked),
            photo_url = COALESCE(v_photo, photo_url),
            notes = COALESCE(v_notes, notes),
            updated_at = NOW()
        WHERE id = v_existing_id AND school_id = p_school_id
        RETURNING * INTO v_rec;
    ELSE
        INSERT INTO public.visitor_profiles (
            school_id, full_name, phone, alternate_phone, email,
            company, designation, visitor_type, id_type, id_number_masked,
            photo_url, notes, verification_status
        ) VALUES (
            p_school_id, v_name, v_phone, p_payload->>'alternate_phone', p_payload->>'email',
            v_company, p_payload->>'designation', v_type, v_id_type, v_id_num,
            v_photo, v_notes, 'VERIFIED'
        )
        RETURNING * INTO v_rec;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Visitor profile saved successfully.',
        'data', jsonb_build_object(
            'id', v_rec.id::TEXT,
            'school_id', v_rec.school_id::TEXT,
            'full_name', v_rec.full_name,
            'phone', v_rec.phone,
            'alternate_phone', v_rec.alternate_phone,
            'email', v_rec.email,
            'company', v_rec.company,
            'designation', v_rec.designation,
            'visitor_type', v_rec.visitor_type,
            'id_type', v_rec.id_type,
            'id_number_masked', v_rec.id_number_masked,
            'photo_url', v_rec.photo_url,
            'notes', v_rec.notes,
            'verification_status', v_rec.verification_status,
            'created_at', to_char(v_rec.created_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
            'updated_at', to_char(v_rec.updated_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
        )
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 7. Stored Procedure: Campus Checkpoints / Locations Query
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_visitors_get_locations(
    p_school_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_locations JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::JSONB) INTO v_locations
    FROM (
        SELECT id::TEXT as id,
               location_name,
               location_code,
               location_type,
               is_entry_point,
               is_exit_point
        FROM public.visitor_access_locations
        WHERE school_id = p_school_id AND is_active = TRUE
        ORDER BY is_entry_point DESC, location_name ASC
    ) t;

    RETURN jsonb_build_object(
        'success', true,
        'data', v_locations
    );
END;
$$;
