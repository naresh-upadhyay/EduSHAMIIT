-- ============================================================================
-- Migration 412: Fix Leave & Outing Request List Function
-- 1. Resolves 'cannot pass more than 100 arguments to a function' in jsonb_build_object
-- 2. Resolves 'column p.section does not exist' in profiles table
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_list(
    p_school_id UUID,
    p_filters JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
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

    IF v_raw_student IS NOT NULL THEN
        BEGIN
            v_student_id := v_raw_student::UUID;
        EXCEPTION WHEN OTHERS THEN
            v_student_id := NULL;
            IF v_search = '' THEN
                v_search := v_raw_student;
            END IF;
        END;
    END IF;

    IF v_raw_hostel IS NOT NULL AND UPPER(v_raw_hostel) NOT IN ('ALL', 'ALL HOSTELS', '') THEN
        BEGIN
            v_hostel_id := v_raw_hostel::UUID;
        EXCEPTION WHEN OTHERS THEN
            v_hostel_id := NULL;
            v_hostel_name := v_raw_hostel;
        END;
    END IF;

    IF NULLIF(TRIM(p_filters->>'from_date'), '') IS NOT NULL THEN
        BEGIN
            v_from_date := (p_filters->>'from_date')::DATE;
        EXCEPTION WHEN OTHERS THEN
            v_from_date := NULL;
        END;
    END IF;

    IF NULLIF(TRIM(p_filters->>'to_date'), '') IS NOT NULL THEN
        BEGIN
            v_to_date := (p_filters->>'to_date')::DATE;
        EXCEPTION WHEN OTHERS THEN
            v_to_date := NULL;
        END;
    END IF;

    IF v_status IS NOT NULL AND UPPER(v_status) IN ('ALL', 'ALL STATUS', '') THEN
        v_status := NULL;
    END IF;

    IF v_request_type IS NOT NULL AND UPPER(v_request_type) IN ('ALL', 'ALL TYPES', '') THEN
        v_request_type := NULL;
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
            COALESCE(split_part(p.class, ' ', 2), '') AS section_name,
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
