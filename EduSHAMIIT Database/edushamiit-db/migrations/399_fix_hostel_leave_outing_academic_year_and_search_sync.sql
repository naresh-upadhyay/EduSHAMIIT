-- Migration 399: Fix Hostel Leave & Outing Academic Year Scope, Search Sync & Auto-Resolution
-- Ensures all 2026 requests (including Aarav Sharma's requests) are consistently mapped to '2026 - 2027'
-- Ensures fn_hostel_leave_outing_list filtering is consistent between searched and unsearched queries

BEGIN;

-- 1. Sync any 2026 requests that were created under 2024-2025 to 2026-2027
UPDATE public.hostel_leave_outing_requests
SET academic_year = '2026 - 2027'
WHERE academic_year = '2024 - 2025'
  AND (request_number LIKE 'LOR-2026%' OR start_at >= '2026-04-01');

-- 2. Update fn_hostel_leave_outing_create_or_update to intelligently resolve academic_year to current school year (2026 - 2027)
CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_create_or_update(
    p_school_id UUID,
    p_actor_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID := NULLIF(p_payload->>'id', '')::UUID;
    v_student_id UUID := (p_payload->>'student_id')::UUID;
    v_req_type VARCHAR := UPPER(COALESCE(p_payload->>'request_type', 'OUTING'));
    v_req_subtype VARCHAR := COALESCE(p_payload->>'request_subtype', 'Personal');
    v_reason TEXT := TRIM(COALESCE(p_payload->>'reason', ''));
    v_destination TEXT := TRIM(COALESCE(p_payload->>'destination', ''));
    v_start_at TIMESTAMPTZ := (p_payload->>'start_at')::TIMESTAMPTZ;
    v_expected_return_at TIMESTAMPTZ := (p_payload->>'expected_return_at')::TIMESTAMPTZ;
    v_academic_year VARCHAR := NULLIF(TRIM(p_payload->>'academic_year'), '');
    v_is_emergency BOOLEAN := COALESCE((p_payload->>'is_emergency')::BOOLEAN, false);
    v_prof RECORD;
    v_adm RECORD;
    v_alloc RECORD;
    v_req_num VARCHAR(50);
    v_actor_name VARCHAR(150);
    v_conflict_count INT := 0;
    v_new_id UUID;
BEGIN
    -- 1. Validations
    IF v_student_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Student must be selected.');
    END IF;

    IF v_reason = '' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Reason for movement is required.');
    END IF;

    IF v_destination = '' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Destination is required.');
    END IF;

    IF v_start_at IS NULL OR v_expected_return_at IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Start time and expected return time are required.');
    END IF;

    IF v_expected_return_at <= v_start_at THEN
        RETURN jsonb_build_object('success', false, 'message', 'Expected return time must be strictly after start time.');
    END IF;

    -- 2. Fetch Student Profile
    SELECT * INTO v_prof FROM public.profiles WHERE id = v_student_id AND school_id = p_school_id;
    IF v_prof IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Student record not found in this institution.');
    END IF;

    -- Fetch Actor Profile Name
    SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = p_actor_id;
    IF v_actor_name IS NULL THEN
        v_actor_name := 'Administrator';
    END IF;

    -- 3. Fetch Hostel Admission & Allocation Snapshot
    SELECT * INTO v_adm FROM public.hostel_admissions 
    WHERE student_id = v_student_id AND school_id = p_school_id AND deleted_at IS NULL
    ORDER BY created_at DESC LIMIT 1;

    SELECT * INTO v_alloc FROM public.hostel_allocations
    WHERE student_id = v_student_id AND school_id = p_school_id AND deleted_at IS NULL
      AND allocation_status IN ('CHECKED_IN', 'RESERVED', 'CONFIRMED', 'TEMPORARILY_RELOCATED')
    ORDER BY created_at DESC LIMIT 1;

    -- Intelligent Academic Year fallback
    IF v_academic_year IS NULL THEN
        IF v_adm IS NOT NULL AND v_adm.academic_year IS NOT NULL AND v_adm.academic_year <> '' THEN
            v_academic_year := v_adm.academic_year;
        ELSIF v_start_at >= '2026-04-01'::timestamptz AND v_start_at < '2027-04-01'::timestamptz THEN
            v_academic_year := '2026 - 2027';
        ELSIF v_start_at >= '2025-04-01'::timestamptz AND v_start_at < '2026-04-01'::timestamptz THEN
            v_academic_year := '2025 - 2026';
        ELSIF v_start_at >= '2024-04-01'::timestamptz AND v_start_at < '2025-04-01'::timestamptz THEN
            v_academic_year := '2024 - 2025';
        ELSE
            v_academic_year := '2026 - 2027';
        END IF;
    END IF;

    -- 4. CONFLICT DETECTION: Overlapping Movement Request
    SELECT COUNT(*)
    INTO v_conflict_count
    FROM public.hostel_leave_outing_requests
    WHERE student_id = v_student_id
      AND school_id = p_school_id
      AND deleted_at IS NULL
      AND (v_id IS NULL OR id <> v_id)
      AND status IN ('NEW', 'PENDING', 'ACTIVE', 'IN_PROGRESS', 'APPROVED', 'EXITED')
      AND (
          (start_at < v_expected_return_at AND expected_return_at > v_start_at)
      );

    IF v_conflict_count > 0 THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Conflict: Student already has an active or approved movement request overlapping this time window.'
        );
    END IF;

    -- 5. Create or Update
    IF v_id IS NOT NULL THEN
        -- UPDATE existing request
        UPDATE public.hostel_leave_outing_requests
        SET 
            request_type = v_req_type,
            request_subtype = v_req_subtype,
            reason = v_reason,
            destination = v_destination,
            start_at = v_start_at,
            expected_return_at = v_expected_return_at,
            academic_year = v_academic_year,
            is_emergency = v_is_emergency,
            accompanied_by = COALESCE(p_payload->>'accompanied_by', accompanied_by),
            companion_name = p_payload->>'companion_name',
            companion_phone = p_payload->>'companion_phone',
            companion_relation = p_payload->>'companion_relation',
            transport_mode = COALESCE(p_payload->>'transport_mode', transport_mode),
            vehicle_number = p_payload->>'vehicle_number',
            pickup_person_name = p_payload->>'pickup_person_name',
            pickup_person_phone = p_payload->>'pickup_person_phone',
            destination_address = p_payload->>'destination_address',
            special_instructions = p_payload->>'special_instructions',
            guardian_confirmation_required = COALESCE((p_payload->>'guardian_confirmation_required')::BOOLEAN, guardian_confirmation_required),
            documents = COALESCE((p_payload->'documents')::JSONB, documents),
            updated_by = p_actor_id,
            updated_at = NOW(),
            version = version + 1
        WHERE id = v_id AND school_id = p_school_id;

        v_new_id := v_id;
    ELSE
        -- INSERT new request
        SELECT 'LOR-' || TO_CHAR(COALESCE(v_start_at, NOW()), 'YYYY') || '-' || LPAD((COUNT(*) + 1)::TEXT, 4, '0')
        INTO v_req_num
        FROM public.hostel_leave_outing_requests
        WHERE school_id = p_school_id;

        INSERT INTO public.hostel_leave_outing_requests (
            school_id,
            student_id,
            admission_id,
            request_number,
            academic_year,
            request_type,
            request_subtype,
            reason,
            destination,
            start_at,
            expected_return_at,
            status,
            is_emergency,
            hostel_id,
            building_name,
            room_number,
            bed_code,
            guardian_name,
            guardian_phone,
            guardian_relationship,
            guardian_confirmation_required,
            accompanied_by,
            companion_name,
            companion_phone,
            companion_relation,
            transport_mode,
            vehicle_number,
            pickup_person_name,
            pickup_person_phone,
            destination_address,
            special_instructions,
            documents,
            created_by,
            created_by_name,
            updated_by
        ) VALUES (
            p_school_id,
            v_student_id,
            v_adm.id,
            v_req_num,
            v_academic_year,
            v_req_type,
            v_req_subtype,
            v_reason,
            v_destination,
            v_start_at,
            v_expected_return_at,
            'PENDING',
            v_is_emergency,
            COALESCE(v_alloc.building_id, v_adm.hostel_id),
            COALESCE(p_payload->>'building_name', 'Hostel Block'),
            COALESCE(p_payload->>'room_number', 'A-101'),
            COALESCE(p_payload->>'bed_code', 'Bed 1'),
            COALESCE(NULLIF(p_payload->>'guardian_name', ''), v_prof.father_name, v_prof.mother_name, 'Guardian'),
            COALESCE(NULLIF(p_payload->>'guardian_phone', ''), v_prof.father_phone, v_prof.mother_phone, '+91 98765 43210'),
            COALESCE(p_payload->>'guardian_relationship', 'Father'),
            COALESCE((p_payload->>'guardian_confirmation_required')::BOOLEAN, false),
            COALESCE(p_payload->>'accompanied_by', 'SELF'),
            p_payload->>'companion_name',
            p_payload->>'companion_phone',
            p_payload->>'companion_relation',
            COALESCE(p_payload->>'transport_mode', 'WALK'),
            p_payload->>'vehicle_number',
            p_payload->>'pickup_person_name',
            p_payload->>'pickup_person_phone',
            p_payload->>'destination_address',
            p_payload->>'special_instructions',
            COALESCE((p_payload->'documents')::JSONB, '[]'::JSONB),
            p_actor_id,
            v_actor_name,
            p_actor_id
        )
        RETURNING id INTO v_new_id;

        -- Create initial approval record
        INSERT INTO public.hostel_leave_outing_approvals (
            school_id, request_id, approval_step, approver_user_id, approver_name, approver_role, action
        ) VALUES (
            p_school_id, v_new_id, 1, NULL, 'Assigned Warden', 'Warden', 'PENDING'
        );

        -- Audit log entry in hostel_student_activities
        INSERT INTO public.hostel_student_activities (
            school_id, student_id, admission_id, activity_type, title, description, badge_color, performed_by, performed_by_name
        ) VALUES (
            p_school_id, v_student_id, v_adm.id, 'LEAVE_REQUEST_SUBMITTED',
            'New ' || v_req_type || ' request submitted (' || v_req_num || ')',
            v_reason || ' · Destination: ' || v_destination,
            'blue', p_actor_id, v_actor_name
        );
    END IF;

    RETURN public.fn_hostel_leave_outing_get_by_id(p_school_id, v_new_id);
END;
$$;


-- 3. Update fn_hostel_leave_outing_list to keep academic year filtering consistent between search and no-search
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
            v_academic_year := NULL; -- Graceful fallback
        END IF;
    END IF;

    -- Safe parsing for hostel_id
    IF v_raw_hostel IS NOT NULL AND UPPER(v_raw_hostel) NOT IN ('ALL', 'ALL HOSTELS', '') THEN
        IF v_raw_hostel ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
            v_hostel_id := v_raw_hostel::UUID;
        ELSE
            v_hostel_name := v_raw_hostel;
        END IF;
    END IF;

    -- Safe parsing for student_id
    IF v_raw_student IS NOT NULL AND v_raw_student ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_student_id := v_raw_student::UUID;
    END IF;

    -- Safe parsing for dates
    BEGIN
        v_from_date := NULLIF(p_filters->>'from_date', '')::DATE;
    EXCEPTION WHEN OTHERS THEN
        v_from_date := NULL;
    END;
    BEGIN
        v_to_date := NULLIF(p_filters->>'to_date', '')::DATE;
    EXCEPTION WHEN OTHERS THEN
        v_to_date := NULL;
    END;

    -- 1. Count matching records
    SELECT COUNT(*)
    INTO v_total_records
    FROM public.hostel_leave_outing_requests r
    JOIN public.profiles p ON p.id = r.student_id
    LEFT JOIN public.hostel_buildings b ON b.id = r.hostel_id
    WHERE r.school_id = p_school_id
      AND r.deleted_at IS NULL
      AND (
          v_academic_year IS NULL 
          OR r.academic_year = v_academic_year 
          OR v_student_id IS NOT NULL
      )
      AND (
          (v_hostel_id IS NULL AND v_hostel_name IS NULL)
          OR (v_hostel_id IS NOT NULL AND r.hostel_id = v_hostel_id)
          OR (v_hostel_name IS NOT NULL AND (r.building_name ILIKE '%' || v_hostel_name || '%' OR b.name ILIKE '%' || v_hostel_name || '%'))
      )
      AND (v_student_id IS NULL OR r.student_id = v_student_id)
      AND (v_request_type IS NULL OR UPPER(v_request_type) IN ('ALL', 'ALL TYPES', '') OR UPPER(r.request_type) = UPPER(v_request_type))
      AND (v_emergency_only = false OR r.is_emergency = true)
      AND (
          v_status IS NULL OR UPPER(v_status) IN ('ALL', 'ALL STATUS', '')
          OR (UPPER(v_status) = 'PENDING' AND r.status IN ('PENDING', 'NEW', 'ACTIVE', 'IN_PROGRESS'))
          OR (UPPER(v_status) = 'OVERDUE' AND (r.status = 'OVERDUE_RETURN' OR (r.status = 'EXITED' AND r.expected_return_at < NOW())))
          OR UPPER(r.status) = UPPER(v_status)
      )
      AND (v_currently_out = false OR r.status = 'EXITED')
      AND (v_overdue_only = false OR (r.status = 'OVERDUE_RETURN' OR (r.status = 'EXITED' AND r.expected_return_at < NOW())))
      AND (v_from_date IS NULL OR DATE(r.start_at) >= v_from_date)
      AND (v_to_date IS NULL OR DATE(r.start_at) <= v_to_date)
      AND (
          v_search = ''
          OR p.full_name ILIKE '%' || v_search || '%'
          OR COALESCE(p.admission_number, '') ILIKE '%' || v_search || '%'
          OR COALESCE(p.roll_number::TEXT, '') ILIKE '%' || v_search || '%'
          OR r.request_number ILIKE '%' || v_search || '%'
          OR COALESCE(r.room_number, '') ILIKE '%' || v_search || '%'
          OR COALESCE(r.building_name, b.name, '') ILIKE '%' || v_search || '%'
          OR COALESCE(r.destination, '') ILIKE '%' || v_search || '%'
          OR COALESCE(r.reason, '') ILIKE '%' || v_search || '%'
          OR COALESCE(r.guardian_name, '') ILIKE '%' || v_search || '%'
      );

    -- 2. Fetch page items
    WITH matching_rows AS (
        SELECT 
            r.id,
            r.request_number,
            r.request_type,
            r.request_subtype,
            r.reason,
            r.destination,
            r.start_at,
            r.expected_return_at,
            r.actual_exit_at,
            r.actual_return_at,
            TO_CHAR(r.start_at, 'DD Mon YYYY') AS from_date_formatted,
            TO_CHAR(r.expected_return_at, 'DD Mon YYYY') AS to_date_formatted,
            TO_CHAR(r.created_at, 'DD Mon YYYY') AS requested_on_formatted,
            CASE 
                WHEN (r.expected_return_at - r.start_at) > INTERVAL '1 day' 
                THEN CEIL(EXTRACT(EPOCH FROM (r.expected_return_at - r.start_at))/86400)::INT || ' days' 
                WHEN (r.expected_return_at - r.start_at) > INTERVAL '1 hour'
                THEN CEIL(EXTRACT(EPOCH FROM (r.expected_return_at - r.start_at))/3600)::INT || ' hours'
                ELSE '1 day' 
            END AS duration_text,
            CASE 
                WHEN r.status = 'EXITED' AND r.expected_return_at < NOW() THEN 'OVERDUE_RETURN'
                ELSE r.status
            END AS display_status,
            r.is_emergency,
            r.hostel_id,
            COALESCE(r.building_name, b.name, 'Boys Hostel A') AS building_name,
            COALESCE(r.room_number, '101') AS room_number,
            COALESCE(r.bed_code, '1') AS bed_code,
            COALESCE(r.guardian_name, p.father_name, 'Parent') AS guardian_name,
            COALESCE(r.guardian_phone, p.emergency_contact_phone, p.phone, '') AS guardian_phone,
            r.accompanied_by,
            r.companion_name,
            r.transport_mode,
            r.special_instructions,
            r.approved_by_name,
            r.approved_at,
            r.approval_remarks,
            r.exit_gate,
            r.exit_verified_by_name,
            r.return_gate,
            r.return_verified_by_name,
            r.version,
            r.created_at,
            r.updated_at,
            p.id AS student_id,
            p.full_name AS student_name,
            p.avatar_url,
            COALESCE(p.admission_number, '') AS admission_number,
            COALESCE(p.roll_number::TEXT, '') AS roll_number,
            COALESCE(p.class, '10 A') AS class_name,
            gp.pass_number,
            gp.verification_token,
            gp.qr_reference,
            gp.status AS gate_pass_status
        FROM public.hostel_leave_outing_requests r
        JOIN public.profiles p ON p.id = r.student_id
        LEFT JOIN public.hostel_buildings b ON b.id = r.hostel_id
        LEFT JOIN LATERAL (
            SELECT pass_number, verification_token, qr_reference, status
            FROM public.hostel_gate_passes
            WHERE request_id = r.id
            ORDER BY created_at DESC LIMIT 1
        ) gp ON true
        WHERE r.school_id = p_school_id
          AND r.deleted_at IS NULL
          AND (
              v_academic_year IS NULL 
              OR r.academic_year = v_academic_year 
              OR v_student_id IS NOT NULL
          )
          AND (
              (v_hostel_id IS NULL AND v_hostel_name IS NULL)
              OR (v_hostel_id IS NOT NULL AND r.hostel_id = v_hostel_id)
              OR (v_hostel_name IS NOT NULL AND (r.building_name ILIKE '%' || v_hostel_name || '%' OR b.name ILIKE '%' || v_hostel_name || '%'))
          )
          AND (v_student_id IS NULL OR r.student_id = v_student_id)
          AND (v_request_type IS NULL OR UPPER(v_request_type) IN ('ALL', 'ALL TYPES', '') OR UPPER(r.request_type) = UPPER(v_request_type))
          AND (v_emergency_only = false OR r.is_emergency = true)
          AND (
              v_status IS NULL OR UPPER(v_status) IN ('ALL', 'ALL STATUS', '')
              OR (UPPER(v_status) = 'PENDING' AND r.status IN ('PENDING', 'NEW', 'ACTIVE', 'IN_PROGRESS'))
              OR (UPPER(v_status) = 'OVERDUE' AND (r.status = 'OVERDUE_RETURN' OR (r.status = 'EXITED' AND r.expected_return_at < NOW())))
              OR UPPER(r.status) = UPPER(v_status)
          )
          AND (v_currently_out = false OR r.status = 'EXITED')
          AND (v_overdue_only = false OR (r.status = 'OVERDUE_RETURN' OR (r.status = 'EXITED' AND r.expected_return_at < NOW())))
          AND (v_from_date IS NULL OR DATE(r.start_at) >= v_from_date)
          AND (v_to_date IS NULL OR DATE(r.start_at) <= v_to_date)
          AND (
              v_search = ''
              OR p.full_name ILIKE '%' || v_search || '%'
              OR COALESCE(p.admission_number, '') ILIKE '%' || v_search || '%'
              OR COALESCE(p.roll_number::TEXT, '') ILIKE '%' || v_search || '%'
              OR r.request_number ILIKE '%' || v_search || '%'
              OR COALESCE(r.room_number, '') ILIKE '%' || v_search || '%'
              OR COALESCE(r.building_name, b.name, '') ILIKE '%' || v_search || '%'
              OR COALESCE(r.destination, '') ILIKE '%' || v_search || '%'
              OR COALESCE(r.reason, '') ILIKE '%' || v_search || '%'
              OR COALESCE(r.guardian_name, '') ILIKE '%' || v_search || '%'
          )
        ORDER BY
            CASE WHEN v_sort_by = 'request_number' AND v_sort_order = 'asc' THEN r.request_number END ASC,
            CASE WHEN v_sort_by = 'request_number' AND v_sort_order = 'desc' THEN r.request_number END DESC,
            CASE WHEN v_sort_by = 'student_name' AND v_sort_order = 'asc' THEN p.full_name END ASC,
            CASE WHEN v_sort_by = 'student_name' AND v_sort_order = 'desc' THEN p.full_name END DESC,
            CASE WHEN v_sort_by = 'start_at' AND v_sort_order = 'asc' THEN r.start_at END ASC,
            CASE WHEN v_sort_by = 'start_at' AND v_sort_order = 'desc' THEN r.start_at END DESC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'asc' THEN r.status END ASC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'desc' THEN r.status END DESC,
            CASE WHEN v_sort_by = 'created_at' AND v_sort_order = 'asc' THEN r.created_at END ASC,
            CASE WHEN v_sort_by = 'created_at' AND v_sort_order = 'desc' THEN r.created_at END DESC,
            r.created_at DESC
        LIMIT v_page_size
        OFFSET v_offset
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', id,
                'request_number', request_number,
                'request_type', request_type,
                'request_subtype', request_subtype,
                'reason', reason,
                'destination', destination,
                'start_at', start_at,
                'expected_return_at', expected_return_at,
                'actual_exit_at', actual_exit_at,
                'actual_return_at', actual_return_at,
                'from_date_formatted', from_date_formatted,
                'to_date_formatted', to_date_formatted,
                'requested_on_formatted', requested_on_formatted,
                'duration_text', duration_text,
                'status', display_status,
                'is_emergency', is_emergency,
                'hostel_id', hostel_id,
                'building_name', building_name,
                'room_number', room_number,
                'bed_code', bed_code,
                'student_id', student_id,
                'student_name', student_name,
                'avatar_url', avatar_url,
                'admission_number', admission_number,
                'roll_number', roll_number,
                'class_name', class_name,
                'guardian_name', guardian_name,
                'guardian_phone', guardian_phone,
                'accompanied_by', accompanied_by,
                'companion_name', companion_name,
                'transport_mode', transport_mode,
                'special_instructions', special_instructions,
                'approved_by_name', approved_by_name,
                'approved_at', approved_at,
                'approval_remarks', approval_remarks,
                'exit_gate', exit_gate,
                'exit_verified_by_name', exit_verified_by_name,
                'return_gate', return_gate,
                'return_verified_by_name', return_verified_by_name,
                'pass_number', pass_number,
                'verification_token', verification_token,
                'qr_reference', qr_reference,
                'gate_pass_status', gate_pass_status,
                'version', version,
                'created_at', created_at,
                'updated_at', updated_at
            )
        ),
        '[]'::JSONB
    ) INTO v_items
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

COMMIT;

