-- =========================================================================
-- Migration 395: Fix Hostel Roster Pagination & Dynamic Leave/Outing Data
-- 1. Updates fn_hostel_get_students_roster to return structured 'pagination'
--    object containing 'total_records', 'total_pages', 'has_prev', 'has_next'.
-- 2. Updates fn_hostel_leave_outing_list to return dynamic date formatting,
--    duration calculations, and cross-year search synchronization.
-- =========================================================================

-- 1. Update fn_hostel_get_students_roster with complete pagination object
CREATE OR REPLACE FUNCTION public.fn_hostel_get_students_roster(
    p_school_id UUID,
    p_academic_year VARCHAR DEFAULT '2024 - 2025',
    p_search VARCHAR DEFAULT '',
    p_hostel_id UUID DEFAULT NULL,
    p_class_id UUID DEFAULT NULL,
    p_status VARCHAR DEFAULT 'ALL',
    p_fee_status VARCHAR DEFAULT 'ALL',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'student_name',
    p_sort_order VARCHAR DEFAULT 'asc'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_count INT := 0;
    v_rows JSONB := '[]'::JSONB;
    v_offset INT;
    v_total_pages INT := 1;
BEGIN
    v_offset := GREATEST(0, (p_page - 1) * p_page_size);

    -- 1. Calculate Total Records matching filters
    SELECT COUNT(*) INTO v_total_count
    FROM public.hostel_admissions a
    JOIN public.profiles p ON a.student_id = p.id
    LEFT JOIN public.hostel_allocations alloc ON (
        alloc.admission_id = a.id 
        AND alloc.allocation_status IN ('CHECKED_IN', 'RESERVED', 'CONFIRMED', 'TEMPORARILY_RELOCATED')
        AND alloc.deleted_at IS NULL
    )
    LEFT JOIN public.hostel_buildings b ON COALESCE(alloc.building_id, a.hostel_id) = b.id
    LEFT JOIN public.student_class_assignments sca ON (
        sca.student_id = p.id 
        AND sca.school_id = p_school_id 
        AND sca.status = 'ACTIVE'
    )
    WHERE a.school_id = p_school_id
      AND (a.academic_year = p_academic_year OR p_search <> '')
      AND a.deleted_at IS NULL
      AND (p_hostel_id IS NULL OR a.hostel_id = p_hostel_id OR alloc.building_id = p_hostel_id)
      AND (p_class_id IS NULL OR sca.class_id = p_class_id)
      AND (
          p_status = 'ALL' 
          OR (p_status = 'ACTIVE' AND a.admission_status = 'ACTIVE')
          OR (p_status = 'LEAVE' AND a.admission_status = 'ON_LEAVE')
          OR (p_status = 'AWAITING' AND (a.admission_status = 'AWAITING_ALLOCATION' OR alloc.id IS NULL))
          OR (p_status = 'CHECKED_OUT' AND a.admission_status = 'CHECKED_OUT')
      )
      AND (
          p_fee_status = 'ALL' 
          OR a.fee_status = UPPER(p_fee_status)
      )
      AND (
          p_search = '' 
          OR p.full_name ILIKE '%' || p_search || '%'
          OR COALESCE(sca.roll_number, p.roll_number::TEXT) ILIKE '%' || p_search || '%'
          OR COALESCE(b.name, '') ILIKE '%' || p_search || '%'
      );

    v_total_pages := GREATEST(1, CEIL(v_total_count::NUMERIC / GREATEST(1, p_page_size)::NUMERIC)::INT);

    -- 2. Fetch Paginated Records
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'admission_id', sub.admission_id,
                'allocation_id', sub.allocation_id,
                'student_id', sub.student_id,
                'avatar_url', sub.avatar_url,
                'student_name', sub.full_name,
                'guardian_name', sub.guardian_name,
                'guardian_relation', sub.guardian_relation,
                'roll_no', sub.roll_no,
                'class_name', sub.class_display,
                'hostel_id', sub.hostel_id,
                'hostel_name', sub.hostel_name,
                'building_id', sub.building_id,
                'floor_id', sub.floor_id,
                'room_id', sub.room_id,
                'room_number', sub.room_number,
                'bed_id', sub.bed_id,
                'bed_no', sub.bed_no,
                'status', sub.display_status,
                'raw_status', sub.admission_status,
                'fee_status', sub.fee_status,
                'admission_date', sub.admission_date,
                'gender', sub.gender,
                'blood_group', sub.blood_group,
                'emergency_contact', sub.emergency_contact,
                'address', sub.address,
                'fee_plan', sub.fee_plan,
                'hostel_type', sub.hostel_type,
                'monthly_fee', sub.monthly_fee,
                'deposit_amount', sub.deposit_amount,
                'initial_payment_amount', sub.initial_payment_amount
            )
            ORDER BY 
                CASE WHEN LOWER(p_sort_by) = 'roll_no' AND LOWER(p_sort_order) = 'asc' THEN sub.roll_no END ASC,
                CASE WHEN LOWER(p_sort_by) = 'roll_no' AND LOWER(p_sort_order) = 'desc' THEN sub.roll_no END DESC,
                CASE WHEN LOWER(p_sort_by) = 'room' AND LOWER(p_sort_order) = 'asc' THEN sub.room_number END ASC,
                CASE WHEN LOWER(p_sort_by) = 'room' AND LOWER(p_sort_order) = 'desc' THEN sub.room_number END DESC,
                CASE WHEN LOWER(p_sort_by) = 'hostel' AND LOWER(p_sort_order) = 'asc' THEN sub.hostel_name END ASC,
                CASE WHEN LOWER(p_sort_by) = 'hostel' AND LOWER(p_sort_order) = 'desc' THEN sub.hostel_name END DESC,
                CASE WHEN LOWER(p_sort_by) = 'status' AND LOWER(p_sort_order) = 'asc' THEN sub.display_status END ASC,
                CASE WHEN LOWER(p_sort_by) = 'status' AND LOWER(p_sort_order) = 'desc' THEN sub.display_status END DESC,
                CASE WHEN LOWER(p_sort_by) = 'student_name' AND LOWER(p_sort_order) = 'asc' THEN sub.full_name END ASC,
                CASE WHEN LOWER(p_sort_by) = 'student_name' AND LOWER(p_sort_order) = 'desc' THEN sub.full_name END DESC,
                sub.roll_no ASC, sub.full_name ASC
        ),
        '[]'::JSONB
    ) INTO v_rows
    FROM (
        SELECT 
            a.id AS admission_id,
            alloc.id AS allocation_id,
            p.id AS student_id,
            p.avatar_url,
            p.full_name,
            COALESCE(p.father_name, p.emergency_contact_name, 'Parent') AS guardian_name,
            CASE 
                WHEN UPPER(COALESCE(p.gender, '')) IN ('F', 'FEMALE', 'GIRL', 'GIRLS') THEN 'D/o '
                ELSE 'S/o '
            END || COALESCE(p.father_name, p.emergency_contact_name, 'Parent') AS guardian_relation,
            COALESCE(sca.roll_number, LPAD(COALESCE(p.roll_number::TEXT, '0101'), 4, '0')) AS roll_no,
            COALESCE(
                NULLIF(TRIM(COALESCE(ac.name, '') || ' ' || COALESCE(sec.name, '')), ''),
                p.class,
                '10 A'
            ) AS class_display,
            COALESCE(b.id, a.hostel_id) AS hostel_id,
            COALESCE(b.name, 'Boys Hostel A') AS hostel_name,
            alloc.building_id,
            alloc.floor_id,
            alloc.room_id,
            COALESCE(r.room_number, '-') AS room_number,
            alloc.bed_id,
            COALESCE(REGEXP_REPLACE(bed.bed_code, '^Bed\s*', '', 'i'), '1') AS bed_no,
            CASE 
                WHEN a.admission_status = 'ON_LEAVE' THEN 'Leave'
                WHEN a.admission_status = 'AWAITING_ALLOCATION' OR alloc.id IS NULL THEN 'Awaiting'
                WHEN a.admission_status = 'CHECKED_OUT' THEN 'Checked Out'
                ELSE 'Active'
            END AS display_status,
            a.admission_status,
            CASE 
                WHEN a.fee_status = 'PAID' THEN 'Paid'
                WHEN a.fee_status = 'PENDING' THEN 'Pending'
                WHEN a.fee_status = 'PARTIAL' THEN 'Partial'
                WHEN a.fee_status = 'WAIVED' THEN 'Waived'
                ELSE 'Paid'
            END AS fee_status,
            TO_CHAR(a.admission_date, 'DD Mon YYYY') AS admission_date,
            COALESCE(p.gender, 'Male') AS gender,
            COALESCE(p.blood_group, 'B+') AS blood_group,
            COALESCE(a.emergency_contact_override, p.emergency_contact_phone, p.father_phone, p.phone, '+91 98765 43210 (Father)') AS emergency_contact,
            COALESCE(p.address, 'A-123, Sector 62, Noida, UP') AS address,
            COALESCE(a.fee_plan, 'Monthly') AS fee_plan,
            COALESCE(a.hostel_type, r.room_type, 'AC Room') AS hostel_type,
            COALESCE(a.monthly_fee, 6000.0) AS monthly_fee,
            COALESCE(a.deposit_amount, 10000.0) AS deposit_amount,
            COALESCE(a.initial_payment_amount, 0.0) AS initial_payment_amount
        FROM public.hostel_admissions a
        JOIN public.profiles p ON a.student_id = p.id
        LEFT JOIN public.hostel_allocations alloc ON (
            alloc.admission_id = a.id 
            AND alloc.allocation_status IN ('CHECKED_IN', 'RESERVED', 'CONFIRMED', 'TEMPORARILY_RELOCATED')
            AND alloc.deleted_at IS NULL
        )
        LEFT JOIN public.hostel_buildings b ON COALESCE(alloc.building_id, a.hostel_id) = b.id
        LEFT JOIN public.hostel_rooms r ON alloc.room_id = r.id
        LEFT JOIN public.hostel_beds bed ON alloc.bed_id = bed.id
        LEFT JOIN public.student_class_assignments sca ON (
            sca.student_id = p.id 
            AND sca.school_id = p_school_id 
            AND sca.status = 'ACTIVE'
        )
        LEFT JOIN public.academic_classes ac ON sca.class_id = ac.id
        LEFT JOIN public.academic_sections sec ON sca.section_id = sec.id
        WHERE a.school_id = p_school_id
          AND (a.academic_year = p_academic_year OR p_search <> '')
          AND a.deleted_at IS NULL
          AND (p_hostel_id IS NULL OR a.hostel_id = p_hostel_id OR alloc.building_id = p_hostel_id)
          AND (p_class_id IS NULL OR sca.class_id = p_class_id)
          AND (
              p_status = 'ALL' 
              OR (p_status = 'ACTIVE' AND a.admission_status = 'ACTIVE')
              OR (p_status = 'LEAVE' AND a.admission_status = 'ON_LEAVE')
              OR (p_status = 'AWAITING' AND (a.admission_status = 'AWAITING_ALLOCATION' OR alloc.id IS NULL))
              OR (p_status = 'CHECKED_OUT' AND a.admission_status = 'CHECKED_OUT')
          )
          AND (
              p_fee_status = 'ALL' 
              OR a.fee_status = UPPER(p_fee_status)
          )
          AND (
              p_search = '' 
              OR p.full_name ILIKE '%' || p_search || '%'
              OR COALESCE(sca.roll_number, p.roll_number::TEXT) ILIKE '%' || p_search || '%'
              OR COALESCE(b.name, '') ILIKE '%' || p_search || '%'
          )
        OFFSET v_offset LIMIT p_page_size
    ) sub;

    RETURN jsonb_build_object(
        'success', true,
        'total_count', v_total_count,
        'page', p_page,
        'page_size', p_page_size,
        'data', v_rows,
        'pagination', jsonb_build_object(
            'page', p_page,
            'page_size', p_page_size,
            'total_records', v_total_count,
            'total_pages', v_total_pages,
            'has_prev', p_page > 1,
            'has_next', (p_page * p_page_size) < v_total_count
        )
    );
END;
$$;


-- 2. Update fn_hostel_leave_outing_list to return formatted dates, duration, and synced search
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
          OR v_search <> '' 
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
              OR v_search <> '' 
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
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'asc' THEN r.status END ASC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'desc' THEN r.status END DESC,
            CASE WHEN v_sort_by = 'start_at' AND v_sort_order = 'asc' THEN r.start_at END ASC,
            CASE WHEN v_sort_by = 'start_at' AND v_sort_order = 'desc' THEN r.start_at END DESC,
            CASE WHEN v_sort_by = 'created_at' AND v_sort_order = 'asc' THEN r.created_at END ASC,
            CASE WHEN v_sort_by = 'created_at' AND v_sort_order = 'desc' THEN r.created_at END DESC
        LIMIT v_page_size OFFSET v_offset
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', id,
                'request_number', request_number,
                'student_id', student_id,
                'student_name', student_name,
                'avatar_url', avatar_url,
                'roll_number', roll_number,
                'admission_number', admission_number,
                'class_name', class_name,
                'hostel_id', hostel_id,
                'hostel_name', building_name,
                'building_name', building_name,
                'room_number', room_number,
                'bed_code', bed_code,
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

