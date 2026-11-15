-- ============================================================================
-- Migration: 375_visitor_documents_and_history_enhancements.sql
-- Description: 
--   1. Enlarge visitor_documents file_url column to TEXT for data URLs and base64.
--   2. Stored procedure: fn_visitors_sync_documents (bulk upsert / sync visitor documents).
--   3. Enhanced fn_visitors_get_visit_details (returns all visits for visitor history with is_current flag).
--   4. Enhanced fn_visitors_get_analytics (today's location breakdown with fallback).
-- ============================================================================

-- 1. Alter visitor_documents table
ALTER TABLE IF EXISTS public.visitor_documents
    ALTER COLUMN file_url TYPE TEXT;

-- 2. Stored Procedure: fn_visitors_sync_documents
CREATE OR REPLACE FUNCTION public.fn_visitors_sync_documents(
    p_school_id UUID,
    p_visitor_id UUID,
    p_visit_id UUID,
    p_documents JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_doc JSONB;
    v_doc_id UUID;
    v_doc_name TEXT;
    v_doc_type TEXT;
    v_file_url TEXT;
    v_file_size INT;
    v_status TEXT;
    v_retained_ids UUID[] := ARRAY[]::UUID[];
    v_new_count INT := 0;
BEGIN
    IF p_visitor_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'visitor_id is required');
    END IF;

    IF p_documents IS NOT NULL AND jsonb_typeof(p_documents) = 'array' THEN
        FOR v_doc IN SELECT * FROM jsonb_array_elements(p_documents)
        LOOP
            v_doc_id := NULL;
            IF (v_doc->>'id') IS NOT NULL AND (v_doc->>'id') ~ '^[0-9a-fA-F-]{36}$' THEN
                v_doc_id := (v_doc->>'id')::UUID;
            END IF;

            v_doc_name := COALESCE(NULLIF(TRIM(v_doc->>'document_name'), ''), NULLIF(TRIM(v_doc->>'name'), ''), 'Document');
            v_doc_type := COALESCE(NULLIF(TRIM(v_doc->>'document_type'), ''), NULLIF(TRIM(v_doc->>'type'), ''), 'ID Proof');
            v_file_url := COALESCE(v_doc->>'file_url', v_doc->>'url', '');
            v_file_size := COALESCE((v_doc->>'file_size_bytes')::INT, (v_doc->>'file_size')::INT, 0);
            v_status := COALESCE(v_doc->>'verification_status', v_doc->>'status', 'VERIFIED');

            IF v_doc_id IS NOT NULL THEN
                -- Update existing document
                UPDATE public.visitor_documents
                SET document_name = v_doc_name,
                    document_type = v_doc_type,
                    file_url = CASE WHEN v_file_url <> '' THEN v_file_url ELSE file_url END,
                    file_size_bytes = CASE WHEN v_file_size > 0 THEN v_file_size ELSE file_size_bytes END,
                    verification_status = v_status,
                    visit_id = COALESCE(p_visit_id, visit_id)
                WHERE id = v_doc_id AND school_id = p_school_id AND visitor_id = p_visitor_id;

                v_retained_ids := array_append(v_retained_ids, v_doc_id);
            ELSE
                -- Insert new document
                INSERT INTO public.visitor_documents (
                    school_id, visitor_id, visit_id, document_name, document_type,
                    file_url, file_size_bytes, verification_status, uploaded_at
                ) VALUES (
                    p_school_id, p_visitor_id, p_visit_id, v_doc_name, v_doc_type,
                    v_file_url, v_file_size, v_status, NOW()
                ) RETURNING id INTO v_doc_id;

                v_retained_ids := array_append(v_retained_ids, v_doc_id);
                v_new_count := v_new_count + 1;
            END IF;
        END LOOP;

        -- Optionally remove documents that were removed in the edit payload
        IF array_length(v_retained_ids, 1) > 0 THEN
            DELETE FROM public.visitor_documents
            WHERE school_id = p_school_id
              AND visitor_id = p_visitor_id
              AND NOT (id = ANY(v_retained_ids));
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'retained_count', coalesce(array_length(v_retained_ids, 1), 0),
        'new_count', v_new_count
    );
END;
$$;


-- 3. Enhanced fn_visitors_get_visit_details (returns full visit history with is_current flag)
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
        'status', status,
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
            'status', v_visit.status,
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


-- 4. Enhanced fn_visitors_get_analytics (ensures live today's location counts)
CREATE OR REPLACE FUNCTION public.fn_visitors_get_analytics(
    p_school_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_categories JSONB;
    v_locations JSONB;
    v_recent JSONB;
    v_total_visits INT;
BEGIN
    SELECT COUNT(*) INTO v_total_visits
    FROM public.visitor_visits
    WHERE school_id = p_school_id;

    IF v_total_visits = 0 THEN
        v_total_visits := 1;
    END IF;

    -- Category percentages
    SELECT COALESCE(jsonb_agg(cat_item), '[]'::JSONB) INTO v_categories
    FROM (
        SELECT jsonb_build_object(
            'category', category,
            'count', COUNT(*),
            'percentage', ROUND((COUNT(*)::NUMERIC / v_total_visits * 100)::NUMERIC, 0)::INT
        ) AS cat_item
        FROM public.visitor_visits
        WHERE school_id = p_school_id
        GROUP BY category
        ORDER BY COUNT(*) DESC
    ) c;

    -- Location breakdown: prioritize today's visits if available, fallback to all visits
    SELECT COALESCE(jsonb_agg(loc_item), '[]'::JSONB) INTO v_locations
    FROM (
        WITH today_counts AS (
            SELECT destination AS location, COUNT(*) AS cnt
            FROM public.visitor_visits
            WHERE school_id = p_school_id
              AND (check_in_at >= CURRENT_DATE OR created_at >= CURRENT_DATE)
            GROUP BY destination
        ),
        fallback_counts AS (
            SELECT destination AS location, COUNT(*) AS cnt
            FROM public.visitor_visits
            WHERE school_id = p_school_id
            GROUP BY destination
        ),
        chosen_counts AS (
            SELECT location, cnt FROM today_counts
            UNION ALL
            SELECT location, cnt FROM fallback_counts
            WHERE NOT EXISTS (SELECT 1 FROM today_counts)
        )
        SELECT jsonb_build_object(
            'location', location,
            'count', cnt
        ) AS loc_item
        FROM chosen_counts
        ORDER BY cnt DESC
        LIMIT 7
    ) l;

    -- Recent visits live from DB
    SELECT COALESCE(jsonb_agg(rec_item), '[]'::JSONB) INTO v_recent
    FROM (
        SELECT jsonb_build_object(
            'id', v.id,
            'visitor_name', p.full_name,
            'photo_url', p.photo_url,
            'purpose', v.purpose,
            'destination', v.destination,
            'time', to_char(COALESCE(v.check_in_at, v.created_at), 'HH12:MI AM'),
            'status', v.status
        ) AS rec_item
        FROM public.visitor_visits v
        JOIN public.visitor_profiles p ON v.visitor_id = p.id
        WHERE v.school_id = p_school_id
        ORDER BY v.check_in_at DESC NULLS LAST, v.created_at DESC
        LIMIT 5
    ) r;

    RETURN jsonb_build_object(
        'categories', v_categories,
        'locations', v_locations,
        'recent_visitors', v_recent
    );
END;
$$;
