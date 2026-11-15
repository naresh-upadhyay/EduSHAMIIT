-- ============================================================================
-- Migration 411: Full CRUD Operations for Hostel Leave & Outing Drawer Tabs
-- Features:
-- 1. Document Management: Add/Upload, Delete, List, and Download supporting documents
-- 2. Activity & Notes: Add and Delete internal notes and audit trail entries
-- 3. Overview Actions: Edit Request details and Delete/Cancel requests
-- 4. Approval Actions: Approve, Reject, Revoke Approval, and Confirm Guardian
-- 5. Movement Management: Record Exit, Record Return, Update Movement, and Reset Movement
-- 6. Gate Pass Actions: Generate, Invalidate/Revoke Gate Pass
-- 7. Update fn_hostel_leave_outing_list to include documents and internal_notes in payload
-- ============================================================================

-- 1. Add Document Function
CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_add_document(
    p_school_id UUID,
    p_user_id UUID,
    p_request_id UUID,
    p_doc JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req RECORD;
    v_doc_id UUID := COALESCE(NULLIF(p_doc->>'id', '')::UUID, gen_random_uuid());
    v_doc_name TEXT := TRIM(COALESCE(p_doc->>'document_name', p_doc->>'title', 'Document.pdf'));
    v_doc_type TEXT := TRIM(COALESCE(p_doc->>'document_type', 'Parent Consent'));
    v_file_url TEXT := COALESCE(p_doc->>'file_url', p_doc->>'url', '');
    v_file_size INT := COALESCE((p_doc->>'file_size_bytes')::INT, 150000);
    v_size_fmt TEXT := COALESCE(p_doc->>'file_size_formatted', '150 KB');
    v_content_type TEXT := COALESCE(p_doc->>'content_type', 'application/pdf');
    v_notes TEXT := p_doc->>'notes';
    v_actor_name VARCHAR(150);
    v_new_doc JSONB;
    v_updated_docs JSONB;
BEGIN
    SELECT * INTO v_req
    FROM public.hostel_leave_outing_requests
    WHERE id = p_request_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_req IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Leave/Outing request not found');
    END IF;

    SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = p_user_id;
    IF v_actor_name IS NULL THEN
        v_actor_name := 'Hostel Staff';
    END IF;

    -- Build document JSONB object
    v_new_doc := jsonb_build_object(
        'id', v_doc_id::TEXT,
        'document_name', v_doc_name,
        'document_type', v_doc_type,
        'file_url', v_file_url,
        'file_size_bytes', v_file_size,
        'file_size_formatted', v_size_fmt,
        'content_type', v_content_type,
        'notes', v_notes,
        'uploaded_at', to_char(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'uploaded_by', p_user_id::TEXT,
        'uploaded_by_name', v_actor_name
    );

    -- Append to existing documents array
    v_updated_docs := COALESCE(v_req.documents, '[]'::JSONB) || jsonb_build_array(v_new_doc);

    UPDATE public.hostel_leave_outing_requests
    SET documents = v_updated_docs,
        updated_by = p_user_id,
        updated_at = NOW(),
        version = version + 1
    WHERE id = p_request_id AND school_id = p_school_id;

    -- Insert student activity audit
    INSERT INTO public.hostel_student_activities (
        school_id, student_id, admission_id, activity_type, title, description, badge_color, performed_by, performed_by_name
    ) VALUES (
        p_school_id, v_req.student_id, v_req.admission_id, 'LEAVE_DOCUMENT_UPLOADED',
        'Document attached to ' || v_req.request_number,
        v_doc_name || ' (' || v_doc_type || ') uploaded by ' || v_actor_name,
        'indigo', p_user_id, v_actor_name
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Document uploaded successfully',
        'data', v_new_doc,
        'documents', v_updated_docs
    );
END;
$$;

-- 2. Delete Document Function
CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_delete_document(
    p_school_id UUID,
    p_user_id UUID,
    p_request_id UUID,
    p_doc_id TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req RECORD;
    v_updated_docs JSONB := '[]'::JSONB;
    v_elem JSONB;
    v_actor_name VARCHAR(150);
    v_deleted_title TEXT := 'Document';
BEGIN
    SELECT * INTO v_req
    FROM public.hostel_leave_outing_requests
    WHERE id = p_request_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_req IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Leave/Outing request not found');
    END IF;

    SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = p_user_id;
    IF v_actor_name IS NULL THEN
        v_actor_name := 'Hostel Staff';
    END IF;

    -- Filter out the document with matching id
    FOR v_elem IN SELECT * FROM jsonb_array_elements(COALESCE(v_req.documents, '[]'::JSONB))
    LOOP
        IF (v_elem->>'id') = p_doc_id THEN
            v_deleted_title := COALESCE(v_elem->>'document_name', 'Document');
        ELSE
            v_updated_docs := v_updated_docs || jsonb_build_array(v_elem);
        END IF;
    END LOOP;

    UPDATE public.hostel_leave_outing_requests
    SET documents = v_updated_docs,
        updated_by = p_user_id,
        updated_at = NOW(),
        version = version + 1
    WHERE id = p_request_id AND school_id = p_school_id;

    -- Insert student activity audit
    INSERT INTO public.hostel_student_activities (
        school_id, student_id, admission_id, activity_type, title, description, badge_color, performed_by, performed_by_name
    ) VALUES (
        p_school_id, v_req.student_id, v_req.admission_id, 'LEAVE_DOCUMENT_DELETED',
        'Document removed from ' || v_req.request_number,
        v_deleted_title || ' deleted by ' || v_actor_name,
        'red', p_user_id, v_actor_name
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Document deleted successfully',
        'documents', v_updated_docs
    );
END;
$$;

-- 3. Add Internal Note Function
CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_add_note(
    p_school_id UUID,
    p_user_id UUID,
    p_request_id UUID,
    p_note JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req RECORD;
    v_note_id UUID := COALESCE(NULLIF(p_note->>'id', '')::UUID, gen_random_uuid());
    v_note_text TEXT := TRIM(COALESCE(p_note->>'note', p_note->>'content', ''));
    v_category TEXT := COALESCE(p_note->>'category', 'General');
    v_actor_name VARCHAR(150);
    v_new_note JSONB;
    v_updated_notes JSONB;
BEGIN
    IF v_note_text = '' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Note text cannot be empty');
    END IF;

    SELECT * INTO v_req
    FROM public.hostel_leave_outing_requests
    WHERE id = p_request_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_req IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Leave/Outing request not found');
    END IF;

    SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = p_user_id;
    IF v_actor_name IS NULL THEN
        v_actor_name := 'Hostel Staff';
    END IF;

    v_new_note := jsonb_build_object(
        'id', v_note_id::TEXT,
        'note', v_note_text,
        'category', v_category,
        'created_at', to_char(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'created_by', p_user_id::TEXT,
        'author_name', v_actor_name
    );

    v_updated_notes := COALESCE(v_req.internal_notes, '[]'::JSONB) || jsonb_build_array(v_new_note);

    UPDATE public.hostel_leave_outing_requests
    SET internal_notes = v_updated_notes,
        updated_by = p_user_id,
        updated_at = NOW(),
        version = version + 1
    WHERE id = p_request_id AND school_id = p_school_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Note added successfully',
        'data', v_new_note,
        'internal_notes', v_updated_notes
    );
END;
$$;

-- 4. Delete Internal Note Function
CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_delete_note(
    p_school_id UUID,
    p_user_id UUID,
    p_request_id UUID,
    p_note_id TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req RECORD;
    v_updated_notes JSONB := '[]'::JSONB;
    v_elem JSONB;
BEGIN
    SELECT * INTO v_req
    FROM public.hostel_leave_outing_requests
    WHERE id = p_request_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_req IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Leave/Outing request not found');
    END IF;

    FOR v_elem IN SELECT * FROM jsonb_array_elements(COALESCE(v_req.internal_notes, '[]'::JSONB))
    LOOP
        IF (v_elem->>'id') <> p_note_id THEN
            v_updated_notes := v_updated_notes || jsonb_build_array(v_elem);
        END IF;
    END LOOP;

    UPDATE public.hostel_leave_outing_requests
    SET internal_notes = v_updated_notes,
        updated_by = p_user_id,
        updated_at = NOW(),
        version = version + 1
    WHERE id = p_request_id AND school_id = p_school_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Note deleted successfully',
        'internal_notes', v_updated_notes
    );
END;
$$;

-- 5. Delete / Cancel Leave Request Function
CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_delete_request(
    p_school_id UUID,
    p_user_id UUID,
    p_request_id UUID
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req RECORD;
    v_actor_name VARCHAR(150);
BEGIN
    SELECT * INTO v_req
    FROM public.hostel_leave_outing_requests
    WHERE id = p_request_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_req IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Leave/Outing request not found or already deleted');
    END IF;

    SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = p_user_id;
    IF v_actor_name IS NULL THEN
        v_actor_name := 'Hostel Staff';
    END IF;

    -- Soft delete
    UPDATE public.hostel_leave_outing_requests
    SET deleted_at = NOW(),
        deleted_by = p_user_id,
        status = 'CANCELED',
        cancellation_reason = 'Deleted by ' || v_actor_name,
        updated_by = p_user_id,
        updated_at = NOW(),
        version = version + 1
    WHERE id = p_request_id AND school_id = p_school_id;

    -- Invalidate gate pass if any
    UPDATE public.hostel_gate_passes
    SET status = 'CANCELED'
    WHERE request_id = p_request_id AND school_id = p_school_id AND status = 'ACTIVE';

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Leave/Outing request ' || v_req.request_number || ' deleted successfully'
    );
END;
$$;

-- 6. Confirm Guardian Function
CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_confirm_guardian(
    p_school_id UUID,
    p_user_id UUID,
    p_request_id UUID,
    p_confirmed BOOLEAN
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req RECORD;
    v_actor_name VARCHAR(150);
BEGIN
    SELECT * INTO v_req
    FROM public.hostel_leave_outing_requests
    WHERE id = p_request_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_req IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Leave/Outing request not found');
    END IF;

    SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = p_user_id;
    IF v_actor_name IS NULL THEN
        v_actor_name := 'Hostel Staff';
    END IF;

    UPDATE public.hostel_leave_outing_requests
    SET guardian_confirmed = p_confirmed,
        updated_by = p_user_id,
        updated_at = NOW(),
        version = version + 1
    WHERE id = p_request_id AND school_id = p_school_id;

    -- Add audit
    INSERT INTO public.hostel_student_activities (
        school_id, student_id, admission_id, activity_type, title, description, badge_color, performed_by, performed_by_name
    ) VALUES (
        p_school_id, v_req.student_id, v_req.admission_id, 'LEAVE_GUARDIAN_VERIFICATION',
        CASE WHEN p_confirmed THEN 'Guardian Confirmed' ELSE 'Guardian Confirmation Cleared' END,
        'Recorded by ' || v_actor_name || ' for ' || v_req.request_number,
        CASE WHEN p_confirmed THEN 'green' ELSE 'amber' END, p_user_id, v_actor_name
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Guardian confirmation status updated',
        'guardian_confirmed', p_confirmed
    );
END;
$$;

-- 7. Revoke Approval Function
CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_revoke_approval(
    p_school_id UUID,
    p_user_id UUID,
    p_request_id UUID,
    p_reason TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req RECORD;
    v_actor_name VARCHAR(150);
BEGIN
    SELECT * INTO v_req
    FROM public.hostel_leave_outing_requests
    WHERE id = p_request_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_req IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Leave/Outing request not found');
    END IF;

    SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = p_user_id;
    IF v_actor_name IS NULL THEN
        v_actor_name := 'Hostel Staff';
    END IF;

    -- Revoke approval, set back to PENDING
    UPDATE public.hostel_leave_outing_requests
    SET status = 'PENDING',
        approved_by = NULL,
        approved_by_name = NULL,
        approved_at = NULL,
        approval_remarks = COALESCE(p_reason, 'Approval revoked by ' || v_actor_name),
        updated_by = p_user_id,
        updated_at = NOW(),
        version = version + 1
    WHERE id = p_request_id AND school_id = p_school_id;

    -- Cancel gate pass
    UPDATE public.hostel_gate_passes
    SET status = 'CANCELED'
    WHERE request_id = p_request_id AND school_id = p_school_id AND status = 'ACTIVE';

    -- Record in approval history
    INSERT INTO public.hostel_leave_outing_approvals (
        school_id, request_id, approval_step, approver_user_id, approver_name, approver_role, action, remarks, decided_at
    ) VALUES (
        p_school_id, p_request_id, 1, p_user_id, v_actor_name, 'Warden', 'REVOKED', p_reason, NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Approval revoked, request status reset to Pending',
        'status', 'PENDING'
    );
END;
$$;

-- 8. Reset Movement Function
CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_reset_movement(
    p_school_id UUID,
    p_user_id UUID,
    p_request_id UUID
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req RECORD;
BEGIN
    SELECT * INTO v_req
    FROM public.hostel_leave_outing_requests
    WHERE id = p_request_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_req IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Leave/Outing request not found');
    END IF;

    UPDATE public.hostel_leave_outing_requests
    SET actual_exit_at = NULL,
        actual_return_at = NULL,
        exit_gate = NULL,
        exit_remarks = NULL,
        exit_verified_by = NULL,
        exit_verified_by_name = NULL,
        return_gate = NULL,
        return_remarks = NULL,
        return_verified_by = NULL,
        return_verified_by_name = NULL,
        status = 'APPROVED',
        updated_by = p_user_id,
        updated_at = NOW(),
        version = version + 1
    WHERE id = p_request_id AND school_id = p_school_id;

    -- Clear movement logs for this request
    DELETE FROM public.hostel_movement_logs
    WHERE request_id = p_request_id AND school_id = p_school_id;

    -- Reactivate gate pass if present
    UPDATE public.hostel_gate_passes
    SET status = 'ACTIVE',
        used_exit_at = NULL,
        used_return_at = NULL
    WHERE request_id = p_request_id AND school_id = p_school_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Movement records reset, status returned to Approved',
        'status', 'APPROVED'
    );
END;
$$;

-- 9. Update Movement Log Function
CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_update_movement(
    p_school_id UUID,
    p_user_id UUID,
    p_request_id UUID,
    p_payload JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req RECORD;
    v_exit_at TIMESTAMPTZ := NULLIF(p_payload->>'actual_exit_at', '')::TIMESTAMPTZ;
    v_return_at TIMESTAMPTZ := NULLIF(p_payload->>'actual_return_at', '')::TIMESTAMPTZ;
    v_exit_gate TEXT := p_payload->>'exit_gate';
    v_exit_remarks TEXT := p_payload->>'exit_remarks';
    v_return_gate TEXT := p_payload->>'return_gate';
    v_return_remarks TEXT := p_payload->>'return_remarks';
    v_new_status VARCHAR := NULL;
BEGIN
    SELECT * INTO v_req
    FROM public.hostel_leave_outing_requests
    WHERE id = p_request_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_req IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Leave/Outing request not found');
    END IF;

    -- Determine appropriate status
    IF v_return_at IS NOT NULL THEN
        v_new_status := 'RETURNED';
    ELSIF v_exit_at IS NOT NULL THEN
        IF NOW() > v_req.expected_return_at THEN
            v_new_status := 'OVERDUE';
        ELSE
            v_new_status := 'EXITED';
        END IF;
    ELSE
        v_new_status := v_req.status;
    END IF;

    UPDATE public.hostel_leave_outing_requests
    SET actual_exit_at = COALESCE(v_exit_at, actual_exit_at),
        actual_return_at = COALESCE(v_return_at, actual_return_at),
        exit_gate = COALESCE(v_exit_gate, exit_gate),
        exit_remarks = COALESCE(v_exit_remarks, exit_remarks),
        return_gate = COALESCE(v_return_gate, return_gate),
        return_remarks = COALESCE(v_return_remarks, return_remarks),
        status = COALESCE(v_new_status, status),
        updated_by = p_user_id,
        updated_at = NOW(),
        version = version + 1
    WHERE id = p_request_id AND school_id = p_school_id;

    RETURN public.fn_hostel_leave_outing_get_by_id(p_school_id, p_request_id);
END;
$$;

-- 10. Also update fn_hostel_leave_outing_list to include documents and internal_notes in item JSON
CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_list(
    p_school_id UUID,
    p_filters JSONB DEFAULT '{}'::JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search TEXT := TRIM(COALESCE(p_filters->>'search', ''));
    v_raw_hostel TEXT := NULLIF(TRIM(p_filters->>'hostel_id'), '');
    v_hostel_id UUID := NULL;
    v_hostel_name TEXT := NULL;
    v_raw_student TEXT := NULLIF(TRIM(p_filters->>'student_id'), '');
    v_student_id UUID := NULL;
    v_request_type VARCHAR := NULLIF(TRIM(p_filters->>'request_type'), '');
    v_status VARCHAR := NULLIF(TRIM(p_filters->>'status'), '');
    v_from_date DATE := NULL;
    v_to_date DATE := NULL;
    v_currently_out BOOLEAN := COALESCE((p_filters->>'currently_out')::BOOLEAN, false);
    v_overdue_only BOOLEAN := COALESCE((p_filters->>'overdue_only')::BOOLEAN, false);
    v_emergency_only BOOLEAN := COALESCE((p_filters->>'is_emergency')::BOOLEAN, false);
    v_raw_year VARCHAR := NULLIF(TRIM(p_filters->>'academic_year'), '');
    v_academic_year VARCHAR := NULL;
    v_page INT := GREATEST(COALESCE((p_filters->>'page')::INT, 1), 1);
    v_page_size INT := LEAST(GREATEST(COALESCE((p_filters->>'page_size')::INT, 10), 1), 100);
    v_sort_by VARCHAR := LOWER(COALESCE(NULLIF(TRIM(p_filters->>'sort_by'), ''), 'created_at'));
    v_sort_order VARCHAR := LOWER(COALESCE(NULLIF(TRIM(p_filters->>'sort_order'), ''), 'desc'));
    v_offset INT := (v_page - 1) * v_page_size;
    v_total_records INT := 0;
    v_items JSONB := '[]'::JSONB;
    v_check_count INT := 0;
BEGIN
    IF v_raw_year IS NOT NULL AND UPPER(v_raw_year) NOT IN ('ALL', 'ALL ACADEMIC YEARS', 'ALL YEARS', '') THEN
        v_academic_year := v_raw_year;
        SELECT COUNT(*) INTO v_check_count 
        FROM public.hostel_leave_outing_requests 
        WHERE school_id = p_school_id AND academic_year = v_academic_year AND deleted_at IS NULL;
        IF v_check_count = 0 THEN
            v_academic_year := NULL;
        END IF;
    END IF;

    IF v_raw_hostel IS NOT NULL THEN
        IF v_raw_hostel ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
            v_hostel_id := v_raw_hostel::UUID;
        ELSE
            v_hostel_name := v_raw_hostel;
        END IF;
    END IF;

    IF v_raw_student IS NOT NULL AND v_raw_student ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_student_id := v_raw_student::UUID;
    END IF;

    IF NULLIF(p_filters->>'from_date', '') IS NOT NULL THEN
        v_from_date := (p_filters->>'from_date')::DATE;
    END IF;
    IF NULLIF(p_filters->>'to_date', '') IS NOT NULL THEN
        v_to_date := (p_filters->>'to_date')::DATE;
    END IF;

    WITH base_query AS (
        SELECT 
            r.id,
            r.request_number,
            ROW_NUMBER() OVER (
                ORDER BY 
                    CASE WHEN v_sort_by = 'request_number' AND v_sort_order = 'asc' THEN r.request_number END ASC,
                    CASE WHEN v_sort_by = 'request_number' AND v_sort_order = 'desc' THEN r.request_number END DESC,
                    CASE WHEN v_sort_by = 'student_name' AND v_sort_order = 'asc' THEN p.full_name END ASC,
                    CASE WHEN v_sort_by = 'student_name' AND v_sort_order = 'desc' THEN p.full_name END DESC,
                    CASE WHEN v_sort_by = 'start_at' AND v_sort_order = 'asc' THEN r.start_at END ASC,
                    CASE WHEN v_sort_by = 'start_at' AND v_sort_order = 'desc' THEN r.start_at END DESC,
                    CASE WHEN v_sort_by = 'status' AND v_sort_order = 'asc' THEN r.status END ASC,
                    CASE WHEN v_sort_by = 'status' AND v_sort_order = 'desc' THEN r.status END DESC,
                    r.created_at DESC
            ) AS display_index,
            p.id AS student_id,
            p.full_name AS student_name,
            p.avatar_url AS student_avatar,
            COALESCE(p.admission_number, 'ADM-0101') AS admission_number,
            COALESCE(p.roll_number::TEXT, '0101') AS roll_number,
            COALESCE(p.class, '10 A') AS class_name,
            COALESCE(p.section, '') AS section_name,
            COALESCE(b.name, r.building_name, 'Boys Hostel A') AS hostel_name,
            COALESCE(r.room_number, 'A-101') AS room_number,
            COALESCE(r.bed_code, 'Bed 1') AS bed_number,
            r.request_type,
            r.request_subtype,
            r.reason,
            r.destination,
            to_char(r.start_at AT TIME ZONE 'UTC', 'DD Mon YYYY, HH12:MI AM') AS from_date_formatted,
            to_char(r.expected_return_at AT TIME ZONE 'UTC', 'DD Mon YYYY, HH12:MI AM') AS to_date_formatted,
            r.start_at,
            r.expected_return_at,
            r.actual_exit_at,
            r.actual_return_at,
            CASE 
                WHEN r.expected_return_at - r.start_at >= INTERVAL '1 day' 
                THEN CEIL(EXTRACT(EPOCH FROM (r.expected_return_at - r.start_at)) / 86400)::TEXT || ' days'
                ELSE CEIL(EXTRACT(EPOCH FROM (r.expected_return_at - r.start_at)) / 3600)::TEXT || ' hours'
            END AS duration_text,
            CASE 
                WHEN r.status = 'EXITED' AND NOW() > r.expected_return_at THEN 'OVERDUE'
                ELSE r.status
            END AS status,
            r.is_emergency,
            to_char(r.created_at AT TIME ZONE 'UTC', 'DD Mon YYYY') AS requested_on_formatted,
            r.guardian_name,
            r.guardian_phone,
            r.guardian_confirmed,
            r.accompanied_by,
            r.transport_mode,
            r.special_instructions,
            r.approved_by_name,
            r.approved_at,
            r.approval_remarks,
            r.exit_gate,
            r.exit_verified_by_name,
            r.exit_remarks,
            r.return_gate,
            r.return_verified_by_name,
            r.return_remarks,
            gp.pass_number,
            gp.verification_token,
            gp.qr_reference,
            gp.status AS gate_pass_status,
            r.documents,
            r.internal_notes,
            r.version,
            r.created_at,
            r.updated_at
        FROM public.hostel_leave_outing_requests r
        JOIN public.profiles p ON p.id = r.student_id
        LEFT JOIN public.hostel_buildings b ON b.id = r.hostel_id
        LEFT JOIN public.hostel_gate_passes gp ON gp.request_id = r.id AND gp.status = 'ACTIVE'
        WHERE r.school_id = p_school_id 
          AND r.deleted_at IS NULL
          AND (v_academic_year IS NULL OR r.academic_year = v_academic_year)
          AND (v_student_id IS NULL OR r.student_id = v_student_id)
          AND (v_hostel_id IS NULL OR r.hostel_id = v_hostel_id)
          AND (v_hostel_name IS NULL OR COALESCE(b.name, r.building_name) ILIKE '%' || v_hostel_name || '%')
          AND (v_request_type IS NULL OR UPPER(r.request_type) = UPPER(v_request_type))
          AND (v_status IS NULL OR (
                CASE 
                    WHEN UPPER(v_status) = 'OVERDUE' THEN (r.status = 'OVERDUE' OR (r.status = 'EXITED' AND NOW() > r.expected_return_at))
                    ELSE UPPER(r.status) = UPPER(v_status)
                END
          ))
          AND (v_from_date IS NULL OR r.start_at::DATE >= v_from_date)
          AND (v_to_date IS NULL OR r.expected_return_at::DATE <= v_to_date)
          AND (NOT v_currently_out OR r.status IN ('EXITED', 'OVERDUE'))
          AND (NOT v_overdue_only OR (r.status = 'OVERDUE' OR (r.status = 'EXITED' AND NOW() > r.expected_return_at)))
          AND (NOT v_emergency_only OR r.is_emergency = true)
          AND (
              v_search = '' OR (
                  p.full_name ILIKE '%' || v_search || '%'
                  OR p.admission_number ILIKE '%' || v_search || '%'
                  OR p.roll_number::TEXT ILIKE '%' || v_search || '%'
                  OR r.request_number ILIKE '%' || v_search || '%'
                  OR r.destination ILIKE '%' || v_search || '%'
                  OR r.reason ILIKE '%' || v_search || '%'
                  OR r.room_number ILIKE '%' || v_search || '%'
              )
          )
    ),
    counted AS (
        SELECT COUNT(*) AS total FROM base_query
    ),
    matching_rows AS (
        SELECT * FROM base_query
        ORDER BY display_index ASC
        LIMIT v_page_size OFFSET v_offset
    )
    SELECT 
        COALESCE((SELECT total FROM counted), 0),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', id,
                    'request_number', request_number,
                    'display_index', display_index,
                    'student_id', student_id,
                    'student_name', student_name,
                    'student_avatar', student_avatar,
                    'admission_number', admission_number,
                    'roll_number', roll_number,
                    'class_name', class_name,
                    'section_name', section_name,
                    'hostel_name', hostel_name,
                    'room_number', room_number,
                    'bed_number', bed_number,
                    'request_type', request_type,
                    'request_subtype', request_subtype,
                    'reason', reason,
                    'destination', destination,
                    'from_date_formatted', from_date_formatted,
                    'to_date_formatted', to_date_formatted,
                    'start_at', start_at,
                    'expected_return_at', expected_return_at,
                    'actual_exit_at', actual_exit_at,
                    'actual_return_at', actual_return_at,
                    'duration_text', duration_text,
                    'status', status,
                    'is_emergency', is_emergency,
                    'requested_on_formatted', requested_on_formatted,
                    'guardian_name', guardian_name,
                    'guardian_phone', guardian_phone,
                    'guardian_confirmed', guardian_confirmed,
                    'accompanied_by', accompanied_by,
                    'transport_mode', transport_mode,
                    'special_instructions', special_instructions,
                    'approved_by_name', approved_by_name,
                    'approved_at', approved_at,
                    'approval_remarks', approval_remarks,
                    'exit_gate', exit_gate,
                    'exit_verified_by_name', exit_verified_by_name,
                    'exit_remarks', exit_remarks,
                    'return_gate', return_gate,
                    'return_verified_by_name', return_verified_by_name,
                    'return_remarks', return_remarks,
                    'pass_number', pass_number,
                    'verification_token', verification_token,
                    'qr_reference', qr_reference,
                    'gate_pass_status', gate_pass_status,
                    'documents', documents,
                    'internal_notes', internal_notes,
                    'version', version,
                    'created_at', created_at,
                    'updated_at', updated_at
                )
            ),
            '[]'::JSONB
        )
    INTO v_total_records, v_items
    FROM matching_rows;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'total', v_total_records,
            'page', v_page,
            'page_size', v_page_size,
            'total_pages', GREATEST(1, CEIL(v_total_records::NUMERIC / GREATEST(1, v_page_size)::NUMERIC)::INT),
            'items', v_items
        )
    );
END;
$$;

-- Seed initial supporting documents and notes for sample requests
UPDATE public.hostel_leave_outing_requests
SET documents = jsonb_build_array(
    jsonb_build_object(
        'id', 'd1000001-0000-0000-0000-000000000001',
        'document_name', 'Parent Consent Letter.pdf',
        'document_type', 'Parent Consent',
        'file_url', 'https://edushamiit.edu/documents/parent_consent.pdf',
        'file_size_bytes', 184320,
        'file_size_formatted', '180 KB',
        'content_type', 'application/pdf',
        'notes', 'Signed consent letter from guardian via email',
        'uploaded_at', to_char(NOW() - INTERVAL '1 day', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'uploaded_by_name', 'Hostel Warden'
    ),
    jsonb_build_object(
        'id', 'd1000001-0000-0000-0000-000000000002',
        'document_name', 'Confirmed Travel Ticket.pdf',
        'document_type', 'Travel Ticket',
        'file_url', 'https://edushamiit.edu/documents/travel_ticket.pdf',
        'file_size_bytes', 420000,
        'file_size_formatted', '410 KB',
        'content_type', 'application/pdf',
        'notes', 'Confirmed return train ticket attached',
        'uploaded_at', to_char(NOW() - INTERVAL '1 day', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'uploaded_by_name', 'Student Self'
    )
),
internal_notes = jsonb_build_array(
    jsonb_build_object(
        'id', 'n1000001-0000-0000-0000-000000000001',
        'note', 'Spoke to father Mr. Rajesh Singh on phone (+91 98765 43220). Confirmed travel details and emergency contact.',
        'category', 'Guardian Verification',
        'created_at', to_char(NOW() - INTERVAL '1 day', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'author_name', 'Warden Amit Chouhan'
    )
)
WHERE id IN ('93f832d4-5885-437f-8b02-f8d893d103a0', 'b00fe615-4570-4226-afed-0b946e2a9353', '2af186af-61ba-49c6-a688-d09f8f04800f');

