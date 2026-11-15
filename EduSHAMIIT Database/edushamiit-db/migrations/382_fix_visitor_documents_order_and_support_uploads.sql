-- Migration: 382_fix_visitor_documents_order_and_support_uploads.sql
-- Fixes:
--   1. Ensures created_at exists on public.visitor_documents.
--   2. Fixes fn_visitors_get_appointment_details (orders by uploaded_at/created_at safely).
--   3. Fixes fn_visitors_get_restriction_details (orders by uploaded_at/created_at safely).
--   4. Adds fn_visitors_upload_document for direct document uploads across all tabs.

-- 1. Ensure created_at column exists
ALTER TABLE IF EXISTS public.visitor_documents
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

UPDATE public.visitor_documents
SET created_at = uploaded_at
WHERE created_at IS NULL AND uploaded_at IS NOT NULL;


-- 2. Enhanced fn_visitors_get_appointment_details with safe document ordering
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

    -- All Documents for this visitor (safe order by uploaded_at / created_at)
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

    -- If no documents stored in table, add default placeholders
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
            'status', v.status
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
            'status', v_appt.status,
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


-- 3. Enhanced fn_visitors_get_restriction_details with safe document ordering
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
    v_docs JSONB;
    v_hist JSONB;
    v_attempts JSONB;
BEGIN
    SELECT * INTO v_rest
    FROM public.visitor_restrictions
    WHERE id = p_restriction_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Restriction record not found');
    END IF;

    SELECT * INTO v_visitor
    FROM public.visitor_profiles
    WHERE id = v_rest.visitor_id;

    -- All Documents for this visitor (incident reports, official notices)
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
        WHERE d.visitor_id = v_rest.visitor_id
           OR d.visit_id IN (SELECT id FROM public.visitor_visits WHERE visitor_id = v_rest.visitor_id)
        ORDER BY COALESCE(d.uploaded_at, d.created_at, NOW()) DESC
    ) docs_sub;

    IF jsonb_array_length(v_docs) = 0 THEN
        v_docs := jsonb_build_array(
            jsonb_build_object(
                'id', gen_random_uuid(),
                'name', 'Incident Report Document',
                'document_name', 'Incident Report Document',
                'type', 'Security Incident Report',
                'document_type', 'Security Incident Report',
                'file_name', 'incident_evidence.pdf',
                'file_size', '1.8 MB',
                'url', 'https://example.com/incident.pdf',
                'status', 'Archived',
                'verification_status', 'VERIFIED'
            ),
            jsonb_build_object(
                'id', gen_random_uuid(),
                'name', 'Formal Barring Order Notice',
                'document_name', 'Formal Barring Order Notice',
                'type', 'Official Notice',
                'document_type', 'Official Notice',
                'file_name', 'barring_order.pdf',
                'file_size', '520 KB',
                'url', 'https://example.com/notice.pdf',
                'status', 'Active',
                'verification_status', 'VERIFIED'
            )
        );
    END IF;

    -- Past Visits History before restriction
    SELECT COALESCE(jsonb_agg(h_obj), '[]'::JSONB) INTO v_hist
    FROM (
        SELECT jsonb_build_object(
            'id', v.id,
            'visit_number', v.visit_number,
            'check_in_at', to_char(v.check_in_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH:MI AM'),
            'check_out_at', CASE WHEN v.actual_check_out_at IS NOT NULL THEN to_char(v.actual_check_out_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH:MI AM') ELSE 'Departed' END,
            'purpose', v.purpose,
            'location', v.destination,
            'host', v.host_name,
            'status', v.status
        ) AS h_obj
        FROM public.visitor_visits v
        WHERE v.visitor_id = v_rest.visitor_id
        ORDER BY v.check_in_at DESC
        LIMIT 10
    ) hist_sub;

    -- Blocked / Attempted Access Events (from visitor_access_attempts)
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
            'is_active', (v_rest.status = 'ACTIVE'),
            'is_permanent', COALESCE(v_rest.is_permanent, false),
            'created_at', to_char(v_rest.created_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH:MI AM'),
            'valid_till', COALESCE(v_rest.valid_till_text, CASE WHEN v_rest.expires_at IS NOT NULL THEN to_char(v_rest.expires_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY') ELSE 'Permanent' END)
        ),
        'documents', v_docs,
        'visit_history', v_hist,
        'attempted_entries', v_attempts
    );
END;
$$;


-- 4. Stored Procedure: fn_visitors_upload_document (Unified Document Upload)
CREATE OR REPLACE FUNCTION public.fn_visitors_upload_document(
    p_school_id UUID,
    p_visitor_id UUID,
    p_document_name TEXT,
    p_document_type TEXT,
    p_file_url TEXT,
    p_file_size_bytes INT DEFAULT 0,
    p_verification_status TEXT DEFAULT 'VERIFIED',
    p_visit_id UUID DEFAULT NULL,
    p_appointment_id UUID DEFAULT NULL,
    p_restriction_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_final_visitor_id UUID := p_visitor_id;
    v_final_visit_id UUID := p_visit_id;
    v_doc_id UUID;
    v_doc_name TEXT;
    v_doc_type TEXT;
BEGIN
    -- If visitor_id is null, resolve from appointment_id
    IF v_final_visitor_id IS NULL AND p_appointment_id IS NOT NULL THEN
        SELECT visitor_id INTO v_final_visitor_id
        FROM public.visitor_appointments
        WHERE id = p_appointment_id AND school_id = p_school_id;
    END IF;

    -- If visitor_id is null, resolve from restriction_id
    IF v_final_visitor_id IS NULL AND p_restriction_id IS NOT NULL THEN
        SELECT visitor_id INTO v_final_visitor_id
        FROM public.visitor_restrictions
        WHERE id = p_restriction_id AND school_id = p_school_id;
    END IF;

    -- If visitor_id is null, resolve from visit_id
    IF v_final_visitor_id IS NULL AND v_final_visit_id IS NOT NULL THEN
        SELECT visitor_id INTO v_final_visitor_id
        FROM public.visitor_visits
        WHERE id = v_final_visit_id AND school_id = p_school_id;
    END IF;

    IF v_final_visitor_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Unable to resolve target visitor profile for document upload.'
        );
    END IF;

    v_doc_name := COALESCE(NULLIF(TRIM(p_document_name), ''), 'Uploaded Document');
    v_doc_type := COALESCE(NULLIF(TRIM(p_document_type), ''), 'ID Proof');

    INSERT INTO public.visitor_documents (
        school_id,
        visitor_id,
        visit_id,
        document_name,
        document_type,
        file_url,
        file_size_bytes,
        verification_status,
        uploaded_at,
        created_at
    ) VALUES (
        p_school_id,
        v_final_visitor_id,
        v_final_visit_id,
        v_doc_name,
        v_doc_type,
        p_file_url,
        COALESCE(p_file_size_bytes, 0),
        COALESCE(NULLIF(TRIM(p_verification_status), ''), 'VERIFIED'),
        NOW(),
        NOW()
    )
    RETURNING id INTO v_doc_id;

    RETURN jsonb_build_object(
        'success', true,
        'document', jsonb_build_object(
            'id', v_doc_id,
            'name', v_doc_name,
            'document_name', v_doc_name,
            'type', v_doc_type,
            'document_type', v_doc_type,
            'file_name', v_doc_name,
            'file_size', pg_size_pretty(COALESCE(p_file_size_bytes, 1024)::BIGINT),
            'url', p_file_url,
            'file_url', p_file_url,
            'status', COALESCE(NULLIF(TRIM(p_verification_status), ''), 'VERIFIED'),
            'verification_status', COALESCE(NULLIF(TRIM(p_verification_status), ''), 'VERIFIED'),
            'uploaded_at', NOW()
        ),
        'visitor_id', v_final_visitor_id
    );
END;
$$;
