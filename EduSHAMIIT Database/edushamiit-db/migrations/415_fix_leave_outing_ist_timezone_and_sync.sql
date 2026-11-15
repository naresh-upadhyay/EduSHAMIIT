-- Migration 415: Fix Leave & Outing IST Timezone Formatting & Activity Logs Sync
-- Converts all formatted dates and timestamps to Indian Standard Time (Asia/Kolkata, UTC +5:30).

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
    v_doc_name TEXT := TRIM(COALESCE(p_doc->>'document_name', p_doc->>'name', 'supporting_document.pdf'));
    v_doc_type TEXT := COALESCE(p_doc->>'document_type', p_doc->>'type', 'Parent Consent');
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

    -- Build document JSONB object with IST timestamp
    v_new_doc := jsonb_build_object(
        'id', v_doc_id::TEXT,
        'document_name', v_doc_name,
        'document_type', v_doc_type,
        'file_url', v_file_url,
        'file_size_bytes', v_file_size,
        'file_size_formatted', v_size_fmt,
        'content_type', v_content_type,
        'notes', v_notes,
        'uploaded_at', to_char(NOW() AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD"T"HH24:MI:SS"+05:30"'),
        'formatted_time', to_char(NOW() AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM'),
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
        'created_at', to_char(NOW() AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD"T"HH24:MI:SS"+05:30"'),
        'formatted_time', to_char(NOW() AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM'),
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
        'message', 'Internal note added successfully',
        'data', v_new_note,
        'internal_notes', v_updated_notes
    );
END;
$$;


CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_list(
    p_school_id UUID,
    p_filters JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_academic_year TEXT := p_filters->>'academic_year';
    v_student_id UUID := NULLIF(p_filters->>'student_id', '')::UUID;
    v_hostel_id UUID := NULLIF(p_filters->>'hostel_id', '')::UUID;
    v_hostel_name TEXT := NULLIF(TRIM(p_filters->>'hostel_name'), '');
    v_request_type TEXT := NULLIF(TRIM(p_filters->>'request_type'), '');
    v_status TEXT := NULLIF(TRIM(p_filters->>'status'), '');
    v_from_date DATE := NULLIF(p_filters->>'from_date', '')::DATE;
    v_to_date DATE := NULLIF(p_filters->>'to_date', '')::DATE;
    v_currently_out BOOLEAN := COALESCE((p_filters->>'currently_out')::BOOLEAN, false);
    v_overdue_only BOOLEAN := COALESCE((p_filters->>'overdue_only')::BOOLEAN, false);
    v_emergency_only BOOLEAN := COALESCE((p_filters->>'emergency_only')::BOOLEAN, false);
    v_search TEXT := LOWER(TRIM(COALESCE(p_filters->>'search', '')));
    v_page INT := GREATEST(1, COALESCE((p_filters->>'page')::INT, 1));
    v_page_size INT := GREATEST(1, LEAST(100, COALESCE((p_filters->>'page_size')::INT, 10)));
    v_offset INT := (v_page - 1) * v_page_size;

    v_total_records INT := 0;
    v_items JSONB := '[]'::JSONB;
BEGIN
    WITH base_query AS (
        SELECT 
            ROW_NUMBER() OVER(
                ORDER BY 
                    r.created_at DESC
            ) AS display_index,
            r.id,
            r.request_number,
            p.id AS student_id,
            p.full_name AS student_name,
            p.avatar_url AS student_avatar,
            COALESCE(p.admission_number, 'ADM-0101') AS admission_number,
            COALESCE(p.roll_number::TEXT, '0101') AS roll_number,
            COALESCE(p.class, '10 A') AS class_name,
            COALESCE(split_part(p.class, ' ', 2), '') AS section_name,
            COALESCE(b.name, r.building_name, 'Boys Hostel A') AS hostel_name,
            COALESCE(r.room_number, 'A-101') AS room_number,
            COALESCE(r.bed_code, 'Bed 1') AS bed_number,
            r.request_type,
            r.request_subtype,
            r.reason,
            r.destination,
            to_char(r.start_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM') AS from_date_formatted,
            to_char(r.expected_return_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM') AS to_date_formatted,
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
            to_char(r.created_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY') AS requested_on_formatted,
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
            COALESCE(r.documents, '[]'::JSONB) AS documents,
            COALESCE(r.internal_notes, '[]'::JSONB) AS internal_notes,
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
                    'requested_on_formatted', requested_on_formatted
                ) || jsonb_build_object(
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
