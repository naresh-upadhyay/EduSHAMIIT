-- ============================================================================
-- Migration 589: Hostel Management Grids — True DB-Side Sorting, Pagination &
-- Bulk Operations SSOT Fixes
-- ============================================================================
-- Fixes:
--   1. fn_hostel_get_rooms: Support ALL UI sort keys (room_number, room_type,
--      capacity, occupied, status, facilities) before LIMIT/OFFSET.
--   2. fn_hostel_get_students_roster: Fix broken post-pagination ORDER BY by
--      sorting BEFORE LIMIT/OFFSET, and add class, bed_no, fee_status sort keys.
--   3. fn_hostel_get_staff_roster: Add assigned_area & contact sort branches.
--   4. fn_hostel_get_student_fees: Support all UI sort keys (student_name,
--      room_number, plan_name, total_billed, total_paid, balance_due, fee_status)
--      alongside legacy keys (name, total_fee, paid, due).
--   5. fn_hostel_leave_outing_list: Restore sort_by / sort_order DB sorting
--      across all UI column keys (dropped in Migration 557).
--   6. fn_hostel_complaints_list: Add category, hostel, room_number, reported_by
--      sort branches before LIMIT/OFFSET.
-- ============================================================================

-- 1. fn_hostel_get_rooms
CREATE OR REPLACE FUNCTION public.fn_hostel_get_rooms(
    p_school_id UUID,
    p_search VARCHAR DEFAULT '',
    p_building_id UUID DEFAULT NULL,
    p_floor_id UUID DEFAULT NULL,
    p_room_type VARCHAR DEFAULT 'ALL',
    p_status VARCHAR DEFAULT 'ALL',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'room_number',
    p_sort_order VARCHAR DEFAULT 'ASC'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);
    v_total_records INT := 0;
    v_rooms JSONB := '[]'::JSONB;
    v_selected_context TEXT := 'All Rooms';
    v_sort_by TEXT := LOWER(TRIM(COALESCE(p_sort_by, 'room_number')));
    v_sort_order TEXT := UPPER(TRIM(COALESCE(p_sort_order, 'ASC')));
BEGIN
    IF p_floor_id IS NOT NULL THEN
        SELECT (f.floor_name || ', ' || b.name) INTO v_selected_context
        FROM public.hostel_floors f
        JOIN public.hostel_buildings b ON f.building_id = b.id
        WHERE f.id = p_floor_id;
    ELSIF p_building_id IS NOT NULL THEN
        SELECT b.name INTO v_selected_context
        FROM public.hostel_buildings b
        WHERE b.id = p_building_id;
    END IF;

    SELECT COUNT(*) INTO v_total_records
    FROM public.hostel_rooms r
    JOIN public.hostel_buildings b ON r.building_id = b.id
    JOIN public.hostel_floors f ON r.floor_id = f.id
    WHERE r.school_id = p_school_id
      AND r.deleted_at IS NULL
      AND (p_building_id IS NULL OR r.building_id = p_building_id)
      AND (p_floor_id IS NULL OR r.floor_id = p_floor_id)
      AND (
          p_search = ''
          OR r.room_number ILIKE '%' || p_search || '%'
          OR r.room_code ILIKE '%' || p_search || '%'
          OR r.room_type ILIKE '%' || p_search || '%'
          OR b.name ILIKE '%' || p_search || '%'
          OR f.floor_name ILIKE '%' || p_search || '%'
      )
      AND (p_room_type = 'ALL' OR p_room_type = '' OR UPPER(TRIM(r.room_type)) = UPPER(TRIM(p_room_type)))
      AND (p_status = 'ALL' OR p_status = '' OR UPPER(TRIM(r.operational_status)) = UPPER(TRIM(p_status)));

    WITH base_rooms AS (
        SELECT
            r.id,
            r.building_id,
            b.name AS building_name,
            r.floor_id,
            f.floor_name,
            r.room_number,
            r.room_code,
            r.room_name,
            r.room_type,
            r.is_residential,
            CASE
                WHEN r.is_residential THEN GREATEST(
                    r.target_capacity,
                    COALESCE((SELECT COUNT(*) FROM public.hostel_beds bd WHERE bd.room_id = r.id AND bd.deleted_at IS NULL), 0)
                )
                ELSE 0
            END AS calc_capacity,
            CASE
                WHEN r.is_residential THEN (
                    SELECT COUNT(*) FROM public.hostel_beds bd
                    WHERE bd.room_id = r.id AND bd.deleted_at IS NULL
                      AND (bd.status = 'OCCUPIED' OR EXISTS (
                          SELECT 1 FROM public.hostel_allocations alc
                          WHERE alc.bed_id = bd.id AND alc.deleted_at IS NULL
                            AND alc.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
                      ))
                )
                ELSE 0
            END AS calc_occupied,
            CASE
                WHEN r.is_residential THEN (
                    SELECT COUNT(*) FROM public.hostel_beds bd
                    WHERE bd.room_id = r.id AND bd.deleted_at IS NULL
                      AND bd.status = 'AVAILABLE'
                      AND NOT EXISTS (
                          SELECT 1 FROM public.hostel_allocations alc
                          WHERE alc.bed_id = bd.id AND alc.deleted_at IS NULL
                            AND alc.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
                      )
                )
                ELSE 0
            END AS calc_available,
            (
                SELECT COUNT(*)
                FROM public.hostel_room_equipment eq
                WHERE eq.room_id = r.id AND eq.deleted_at IS NULL
            ) AS facilities_count,
            r.operational_status,
            r.cleanliness_status,
            r.condition_status,
            r.room_size_sqm,
            r.monthly_fee,
            r.gender_restriction,
            r.photos
        FROM public.hostel_rooms r
        JOIN public.hostel_buildings b ON r.building_id = b.id
        JOIN public.hostel_floors f ON r.floor_id = f.id
        WHERE r.school_id = p_school_id
          AND r.deleted_at IS NULL
          AND (p_building_id IS NULL OR r.building_id = p_building_id)
          AND (p_floor_id IS NULL OR r.floor_id = p_floor_id)
          AND (
              p_search = ''
              OR r.room_number ILIKE '%' || p_search || '%'
              OR r.room_code ILIKE '%' || p_search || '%'
              OR r.room_type ILIKE '%' || p_search || '%'
              OR b.name ILIKE '%' || p_search || '%'
              OR f.floor_name ILIKE '%' || p_search || '%'
          )
          AND (p_room_type = 'ALL' OR p_room_type = '' OR UPPER(TRIM(r.room_type)) = UPPER(TRIM(p_room_type)))
          AND (p_status = 'ALL' OR p_status = '' OR UPPER(TRIM(r.operational_status)) = UPPER(TRIM(p_status)))
    ),
    paged_rooms AS (
        SELECT
            br.*,
            ROW_NUMBER() OVER (
                ORDER BY
                    CASE WHEN v_sort_by = 'room_number' AND v_sort_order = 'ASC' THEN br.room_number END ASC,
                    CASE WHEN v_sort_by = 'room_number' AND v_sort_order = 'DESC' THEN br.room_number END DESC,
                    CASE WHEN v_sort_by = 'room_type' AND v_sort_order = 'ASC' THEN br.room_type END ASC,
                    CASE WHEN v_sort_by = 'room_type' AND v_sort_order = 'DESC' THEN br.room_type END DESC,
                    CASE WHEN v_sort_by = 'capacity' AND v_sort_order = 'ASC' THEN br.calc_capacity END ASC,
                    CASE WHEN v_sort_by = 'capacity' AND v_sort_order = 'DESC' THEN br.calc_capacity END DESC,
                    CASE WHEN v_sort_by = 'occupied' AND v_sort_order = 'ASC' THEN br.calc_occupied END ASC,
                    CASE WHEN v_sort_by = 'occupied' AND v_sort_order = 'DESC' THEN br.calc_occupied END DESC,
                    CASE WHEN v_sort_by = 'status' AND v_sort_order = 'ASC' THEN br.operational_status END ASC,
                    CASE WHEN v_sort_by = 'status' AND v_sort_order = 'DESC' THEN br.operational_status END DESC,
                    CASE WHEN v_sort_by = 'facilities' AND v_sort_order = 'ASC' THEN br.facilities_count END ASC,
                    CASE WHEN v_sort_by = 'facilities' AND v_sort_order = 'DESC' THEN br.facilities_count END DESC,
                    br.room_number ASC
            ) AS row_seq
        FROM base_rooms br
        LIMIT GREATEST(p_page_size, 1)
        OFFSET v_offset
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', r.id,
                'building_id', r.building_id,
                'building_name', r.building_name,
                'floor_id', r.floor_id,
                'floor_name', r.floor_name,
                'room_number', r.room_number,
                'room_code', r.room_code,
                'room_name', r.room_name,
                'room_type', r.room_type,
                'is_residential', r.is_residential,
                'capacity', CASE WHEN r.is_residential THEN r.calc_capacity ELSE NULL END,
                'occupied', CASE WHEN r.is_residential THEN r.calc_occupied ELSE NULL END,
                'available_beds', CASE WHEN r.is_residential THEN r.calc_available ELSE NULL END,
                'capacity_label', CASE WHEN r.is_residential THEN r.calc_capacity::TEXT ELSE '-' END,
                'occupied_label', CASE WHEN r.is_residential THEN r.calc_occupied::TEXT ELSE '-' END,
                'status', r.operational_status,
                'cleanliness_status', r.cleanliness_status,
                'condition_status', r.condition_status,
                'room_size_sqm', r.room_size_sqm,
                'monthly_fee', r.monthly_fee,
                'gender_restriction', r.gender_restriction,
                'photos_count', jsonb_array_length(r.photos),
                'photos', r.photos,
                'facilities_summary', (
                    SELECT COALESCE(
                        jsonb_agg(
                            jsonb_build_object(
                                'name', eq.equipment_name,
                                'status', eq.status,
                                'quantity', eq.quantity
                            )
                        ),
                        '[]'::JSONB
                    )
                    FROM public.hostel_room_equipment eq
                    WHERE eq.room_id = r.id AND eq.deleted_at IS NULL
                )
            )
            ORDER BY r.row_seq ASC
        ),
        '[]'::JSONB
    ) INTO v_rooms
    FROM paged_rooms r;

    RETURN jsonb_build_object(
        'data', v_rooms,
        'pagination', jsonb_build_object(
            'page', p_page,
            'page_size', GREATEST(p_page_size, 1),
            'total_records', v_total_records,
            'total_pages', GREATEST(1, CEIL(v_total_records::FLOAT / GREATEST(p_page_size, 1)))
        ),
        'context_title', v_selected_context
    );
END;
$$;


-- 2. fn_hostel_get_students_roster (Sort BEFORE OFFSET/LIMIT + all 8 columns)
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
    v_page_size INT := GREATEST(1, LEAST(100, COALESCE(p_page_size, 10)));
    v_offset INT := GREATEST(0, (GREATEST(p_page, 1) - 1) * v_page_size);
    v_total_pages INT := 1;
    v_sort_by TEXT := LOWER(TRIM(COALESCE(p_sort_by, 'student_name')));
    v_sort_order TEXT := UPPER(TRIM(COALESCE(p_sort_order, 'ASC')));
BEGIN
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

    v_total_pages := GREATEST(1, CEIL(v_total_count::NUMERIC / v_page_size::NUMERIC)::INT);

    WITH base_students AS (
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
    ),
    paged_students AS (
        SELECT
            bs.*,
            ROW_NUMBER() OVER (
                ORDER BY
                    CASE WHEN v_sort_by = 'roll_no' AND v_sort_order = 'ASC' THEN bs.roll_no END ASC,
                    CASE WHEN v_sort_by = 'roll_no' AND v_sort_order = 'DESC' THEN bs.roll_no END DESC,
                    CASE WHEN v_sort_by IN ('class', 'class_name') AND v_sort_order = 'ASC' THEN bs.class_display END ASC,
                    CASE WHEN v_sort_by IN ('class', 'class_name') AND v_sort_order = 'DESC' THEN bs.class_display END DESC,
                    CASE WHEN v_sort_by IN ('room', 'room_number') AND v_sort_order = 'ASC' THEN bs.room_number END ASC,
                    CASE WHEN v_sort_by IN ('room', 'room_number') AND v_sort_order = 'DESC' THEN bs.room_number END DESC,
                    CASE WHEN v_sort_by = 'bed_no' AND v_sort_order = 'ASC' THEN bs.bed_no END ASC,
                    CASE WHEN v_sort_by = 'bed_no' AND v_sort_order = 'DESC' THEN bs.bed_no END DESC,
                    CASE WHEN v_sort_by IN ('hostel', 'hostel_name') AND v_sort_order = 'ASC' THEN bs.hostel_name END ASC,
                    CASE WHEN v_sort_by IN ('hostel', 'hostel_name') AND v_sort_order = 'DESC' THEN bs.hostel_name END DESC,
                    CASE WHEN v_sort_by = 'status' AND v_sort_order = 'ASC' THEN bs.display_status END ASC,
                    CASE WHEN v_sort_by = 'status' AND v_sort_order = 'DESC' THEN bs.display_status END DESC,
                    CASE WHEN v_sort_by = 'fee_status' AND v_sort_order = 'ASC' THEN bs.fee_status END ASC,
                    CASE WHEN v_sort_by = 'fee_status' AND v_sort_order = 'DESC' THEN bs.fee_status END DESC,
                    CASE WHEN v_sort_by = 'student_name' AND v_sort_order = 'ASC' THEN bs.full_name END ASC,
                    CASE WHEN v_sort_by = 'student_name' AND v_sort_order = 'DESC' THEN bs.full_name END DESC,
                    bs.roll_no ASC, bs.full_name ASC
            ) AS row_seq
        FROM base_students bs
        LIMIT v_page_size OFFSET v_offset
    )
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
            ORDER BY sub.row_seq ASC
        ),
        '[]'::JSONB
    ) INTO v_rows
    FROM paged_students sub;

    RETURN jsonb_build_object(
        'success', true,
        'total_count', v_total_count,
        'page', p_page,
        'page_size', v_page_size,
        'data', v_rows,
        'pagination', jsonb_build_object(
            'page', p_page,
            'page_size', v_page_size,
            'total_records', v_total_count,
            'total_pages', v_total_pages,
            'has_prev', p_page > 1,
            'has_next', (p_page * v_page_size) < v_total_count
        )
    );
END;
$$;


-- 3. fn_hostel_get_staff_roster (Add assigned_area and contact sort branches)
CREATE OR REPLACE FUNCTION public.fn_hostel_get_staff_roster(
    p_school_id UUID,
    p_academic_year VARCHAR DEFAULT '2024 - 2025',
    p_search VARCHAR DEFAULT '',
    p_hostel_id UUID DEFAULT NULL,
    p_role VARCHAR DEFAULT 'ALL',
    p_status VARCHAR DEFAULT 'ALL',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'default',
    p_sort_order VARCHAR DEFAULT 'ASC'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_ist_today DATE := (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;
    v_offset INT := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);
    v_total_records INT := 0;
    v_total_pages INT := 1;
    v_rows JSONB := '[]'::JSONB;
    v_sort_by TEXT := LOWER(TRIM(COALESCE(p_sort_by, 'default')));
    v_sort_order TEXT := UPPER(TRIM(COALESCE(p_sort_order, 'ASC')));
BEGIN
    PERFORM public.fn_hostel_sync_staff_leave_statuses_ist(p_school_id);

    SELECT COUNT(*) INTO v_total_records
    FROM public.hostel_staff_assignments a
    JOIN public.profiles p ON a.profile_id = p.id
    LEFT JOIN public.hostel_buildings b ON a.hostel_id = b.id
    WHERE a.school_id = p_school_id
      AND a.deleted_at IS NULL
      AND (
          p_academic_year = ''
          OR a.academic_year = p_academic_year
          OR a.academic_year = '2026 - 2027'
          OR a.academic_year = '2024 - 2025'
      )
      AND (p_hostel_id IS NULL OR a.hostel_id = p_hostel_id)
      AND (
          p_role = 'ALL'
          OR a.hostel_role ILIKE '%' || p_role || '%'
      )
      AND (
          p_status = 'ALL'
          OR (
              p_status = 'Active'
              AND a.assignment_status = 'ACTIVE'
              AND a.duty_status != 'ON_LEAVE'
              AND NOT EXISTS (
                  SELECT 1 FROM public.hostel_staff_leaves l
                  WHERE l.school_id = p_school_id
                    AND (l.profile_id = a.profile_id OR l.assignment_id = a.id)
                    AND l.status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
                    AND v_ist_today BETWEEN l.start_date AND l.end_date
                    AND l.deleted_at IS NULL
              )
          )
          OR (
              p_status = 'On Leave'
              AND (
                  a.assignment_status = 'ON_LEAVE'
                  OR a.duty_status = 'ON_LEAVE'
                  OR EXISTS (
                      SELECT 1 FROM public.hostel_staff_leaves l
                      WHERE l.school_id = p_school_id
                        AND (l.profile_id = a.profile_id OR l.assignment_id = a.id)
                        AND l.status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
                        AND v_ist_today BETWEEN l.start_date AND l.end_date
                        AND l.deleted_at IS NULL
                  )
              )
          )
          OR (p_status = 'Pending' AND a.assignment_status = 'PENDING')
          OR (p_status = a.assignment_status)
      )
      AND (
          p_search = ''
          OR p.full_name ILIKE '%' || p_search || '%'
          OR COALESCE(p.employee_id, '') ILIKE '%' || p_search || '%'
          OR COALESCE(p.phone, '') ILIKE '%' || p_search || '%'
          OR a.hostel_role ILIKE '%' || p_search || '%'
          OR COALESCE(b.name, '') ILIKE '%' || p_search || '%'
          OR a.assigned_area_text ILIKE '%' || p_search || '%'
      );

    v_total_pages := GREATEST(CEIL(v_total_records::NUMERIC / GREATEST(p_page_size, 1)), 1);

    WITH ordered_staff AS (
        SELECT
            a.id AS assignment_id,
            p.id AS profile_id,
            p.full_name AS name,
            COALESCE(p.employee_id, '') AS employee_id,
            COALESCE(p.avatar_url, '') AS photo_url,
            a.hostel_role AS role,
            a.hostel_id,
            COALESCE(b.name, 'Unassigned') AS hostel_name,
            COALESCE(b.code, '') AS hostel_code,
            a.assigned_area_text AS assigned_area,
            COALESCE(p.phone, '') AS contact,
            COALESCE(p.email, '') AS email,
            CASE
                WHEN EXISTS (
                    SELECT 1 FROM public.hostel_staff_leaves l
                    WHERE l.school_id = p_school_id
                      AND (l.profile_id = a.profile_id OR l.assignment_id = a.id)
                      AND l.status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
                      AND v_ist_today BETWEEN l.start_date AND l.end_date
                      AND l.deleted_at IS NULL
                ) OR a.assignment_status = 'ON_LEAVE' OR a.duty_status = 'ON_LEAVE' THEN 'On Leave'
                WHEN a.assignment_status = 'PENDING' THEN 'Pending'
                WHEN a.assignment_status = 'ACTIVE' THEN 'Active'
                ELSE a.assignment_status
            END AS status,
            a.shift_timings,
            COALESCE(TO_CHAR(p.joining_date, 'DD Mon YYYY'), TO_CHAR(a.start_date, 'DD Mon YYYY')) AS joining_date,
            a.created_at,
            ROW_NUMBER() OVER (
                ORDER BY
                    CASE WHEN v_sort_by = 'name' AND v_sort_order = 'ASC' THEN p.full_name END ASC,
                    CASE WHEN v_sort_by = 'name' AND v_sort_order = 'DESC' THEN p.full_name END DESC,
                    CASE WHEN v_sort_by = 'role' AND v_sort_order = 'ASC' THEN a.hostel_role END ASC,
                    CASE WHEN v_sort_by = 'role' AND v_sort_order = 'DESC' THEN a.hostel_role END DESC,
                    CASE WHEN v_sort_by = 'hostel' AND v_sort_order = 'ASC' THEN b.name END ASC,
                    CASE WHEN v_sort_by = 'hostel' AND v_sort_order = 'DESC' THEN b.name END DESC,
                    CASE WHEN v_sort_by = 'assigned_area' AND v_sort_order = 'ASC' THEN a.assigned_area_text END ASC,
                    CASE WHEN v_sort_by = 'assigned_area' AND v_sort_order = 'DESC' THEN a.assigned_area_text END DESC,
                    CASE WHEN v_sort_by = 'contact' AND v_sort_order = 'ASC' THEN COALESCE(p.phone, '') END ASC,
                    CASE WHEN v_sort_by = 'contact' AND v_sort_order = 'DESC' THEN COALESCE(p.phone, '') END DESC,
                    CASE WHEN v_sort_by = 'status' AND v_sort_order = 'ASC' THEN a.assignment_status END ASC,
                    CASE WHEN v_sort_by = 'status' AND v_sort_order = 'DESC' THEN a.assignment_status END DESC,
                    p.employee_id ASC NULLS LAST,
                    a.created_at ASC
            ) AS row_num
        FROM public.hostel_staff_assignments a
        JOIN public.profiles p ON a.profile_id = p.id
        LEFT JOIN public.hostel_buildings b ON a.hostel_id = b.id
        WHERE a.school_id = p_school_id
          AND a.deleted_at IS NULL
          AND (
              p_academic_year = ''
              OR a.academic_year = p_academic_year
              OR a.academic_year = '2026 - 2027'
              OR a.academic_year = '2024 - 2025'
          )
          AND (p_hostel_id IS NULL OR a.hostel_id = p_hostel_id)
          AND (
              p_role = 'ALL'
              OR a.hostel_role ILIKE '%' || p_role || '%'
          )
          AND (
              p_status = 'ALL'
              OR (
                  p_status = 'Active'
                  AND a.assignment_status = 'ACTIVE'
                  AND a.duty_status != 'ON_LEAVE'
                  AND NOT EXISTS (
                      SELECT 1 FROM public.hostel_staff_leaves l
                      WHERE l.school_id = p_school_id
                        AND (l.profile_id = a.profile_id OR l.assignment_id = a.id)
                        AND l.status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
                        AND v_ist_today BETWEEN l.start_date AND l.end_date
                        AND l.deleted_at IS NULL
                  )
              )
              OR (
                  p_status = 'On Leave'
                  AND (
                      a.assignment_status = 'ON_LEAVE'
                      OR a.duty_status = 'ON_LEAVE'
                      OR EXISTS (
                          SELECT 1 FROM public.hostel_staff_leaves l
                          WHERE l.school_id = p_school_id
                            AND (l.profile_id = a.profile_id OR l.assignment_id = a.id)
                            AND l.status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
                            AND v_ist_today BETWEEN l.start_date AND l.end_date
                            AND l.deleted_at IS NULL
                      )
                  )
              )
              OR (p_status = 'Pending' AND a.assignment_status = 'PENDING')
              OR (p_status = a.assignment_status)
          )
          AND (
              p_search = ''
              OR p.full_name ILIKE '%' || p_search || '%'
              OR COALESCE(p.employee_id, '') ILIKE '%' || p_search || '%'
              OR COALESCE(p.phone, '') ILIKE '%' || p_search || '%'
              OR a.hostel_role ILIKE '%' || p_search || '%'
              OR COALESCE(b.name, '') ILIKE '%' || p_search || '%'
              OR a.assigned_area_text ILIKE '%' || p_search || '%'
          )
    )
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'row_num', row_num,
            'assignment_id', assignment_id,
            'profile_id', profile_id,
            'name', name,
            'employee_id', employee_id,
            'photo_url', photo_url,
            'role', role,
            'hostel_id', hostel_id,
            'hostel_name', hostel_name,
            'hostel_code', hostel_code,
            'assigned_area', assigned_area,
            'contact', contact,
            'email', email,
            'status', status,
            'shift_timings', shift_timings,
            'joining_date', joining_date
        )
        ORDER BY row_num ASC
    ), '[]'::JSONB) INTO v_rows
    FROM ordered_staff
    WHERE row_num > v_offset AND row_num <= (v_offset + p_page_size);

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', v_rows,
        'pagination', jsonb_build_object(
            'page', p_page,
            'page_size', p_page_size,
            'total_records', v_total_records,
            'total_pages', v_total_pages,
            'has_prev', p_page > 1,
            'has_next', p_page < v_total_pages
        )
    );
END;
$$;


-- 4. fn_hostel_get_student_fees (Align ALL UI sort keys + legacy keys)
CREATE OR REPLACE FUNCTION public.fn_hostel_get_student_fees(
    p_school_id uuid,
    p_academic_year character varying DEFAULT '2026 - 2027'::character varying,
    p_search character varying DEFAULT NULL::character varying,
    p_hostel_id uuid DEFAULT NULL::uuid,
    p_class character varying DEFAULT NULL::character varying,
    p_status character varying DEFAULT NULL::character varying,
    p_page integer DEFAULT 1,
    p_page_size integer DEFAULT 10,
    p_sort_by character varying DEFAULT 'default'::character varying,
    p_sort_order character varying DEFAULT 'ASC'::character varying
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_offset INT := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);
    v_total_count INT := 0;
    v_items JSONB := '[]'::JSONB;
    v_sort_by TEXT := LOWER(TRIM(COALESCE(p_sort_by, 'default')));
    v_sort_order TEXT := UPPER(TRIM(COALESCE(p_sort_order, 'ASC')));
BEGIN
    SELECT COUNT(DISTINCT acc.id)
    INTO v_total_count
    FROM public.hostel_student_accounts acc
    JOIN public.profiles p ON acc.student_id = p.id
    LEFT JOIN public.hostel_admissions adm ON acc.admission_id = adm.id
    LEFT JOIN public.hostel_buildings b ON adm.hostel_id = b.id
    LEFT JOIN LATERAL (
        SELECT alc.room_id, alc.bed_id
        FROM public.hostel_allocations alc
        WHERE alc.student_id = acc.student_id
          AND alc.allocation_status = 'CHECKED_IN'
          AND alc.deleted_at IS NULL
        ORDER BY alc.created_at DESC
        LIMIT 1
    ) alc ON TRUE
    LEFT JOIN public.hostel_rooms r ON alc.room_id = r.id
    WHERE acc.school_id = p_school_id
      AND acc.academic_year = p_academic_year
      AND (p_hostel_id IS NULL OR adm.hostel_id = p_hostel_id)
      AND (p_class IS NULL OR p_class = 'All Classes' OR p.class ILIKE '%' || p_class || '%')
      AND (
          p_status IS NULL OR
          p_status = 'All Status' OR
          UPPER(acc.payment_status) = UPPER(p_status) OR
          (UPPER(p_status) IN ('OVERPAID', 'OVER PAID') AND UPPER(acc.payment_status) = 'OVERPAID')
      )
      AND (
          p_search IS NULL OR p_search = '' OR
          p.full_name ILIKE '%' || p_search || '%' OR
          p.roll_number::text ILIKE '%' || p_search || '%' OR
          COALESCE(p.user_id, '') ILIKE '%' || p_search || '%' OR
          COALESCE(r.room_number, '') ILIKE '%' || p_search || '%' OR
          COALESCE(b.name, '') ILIKE '%' || p_search || '%'
      );

    SELECT jsonb_agg(
        jsonb_build_object(
            'account_id', acc.id,
            'student_id', p.id,
            'admission_id', adm.id,
            'row_num', row_data.row_seq,
            'name', p.full_name,
            'avatar_url', p.avatar_url,
            'class_name', COALESCE(p.class, '10 A'),
            'roll_number', COALESCE(p.roll_number::text, '0101'),
            'student_identifier', COALESCE(p.class, '10 A') || ' | ' || LPAD(COALESCE(p.roll_number::text, '101'), 4, '0'),
            'hostel_id', adm.hostel_id,
            'hostel_name', COALESCE(b.name, 'Boys Hostel A'),
            'room_id', alc.room_id,
            'room_number', COALESCE(r.room_number, 'A-101'),
            'bed_id', alc.bed_id,
            'fee_plan', COALESCE(acc.fee_plan_name, 'Standard'),
            'total_fee', acc.total_billed,
            'paid', acc.total_paid,
            'due', acc.total_due,
            'overdue', acc.total_overdue,
            'status', CASE
                WHEN UPPER(acc.payment_status) = 'PAID' THEN 'Paid'
                WHEN UPPER(acc.payment_status) = 'PARTIAL' THEN 'Partial'
                WHEN UPPER(acc.payment_status) = 'OVERDUE' THEN 'Overdue'
                WHEN UPPER(acc.payment_status) = 'OVERPAID' THEN 'Over Paid'
                ELSE 'Pending'
            END,
            'status_raw', acc.payment_status,
            'next_due_date', acc.next_due_date,
            'last_payment_date', acc.last_payment_date
        )
        ORDER BY row_data.row_seq ASC
    )
    INTO v_items
    FROM (
        SELECT acc.id, ROW_NUMBER() OVER (
            ORDER BY
                CASE WHEN v_sort_by IN ('name', 'student_name') AND v_sort_order = 'ASC' THEN p.full_name END ASC,
                CASE WHEN v_sort_by IN ('name', 'student_name') AND v_sort_order = 'DESC' THEN p.full_name END DESC,
                CASE WHEN v_sort_by IN ('room', 'room_number') AND v_sort_order = 'ASC' THEN COALESCE(r.room_number, '') END ASC,
                CASE WHEN v_sort_by IN ('room', 'room_number') AND v_sort_order = 'DESC' THEN COALESCE(r.room_number, '') END DESC,
                CASE WHEN v_sort_by IN ('plan_name', 'fee_plan') AND v_sort_order = 'ASC' THEN COALESCE(acc.fee_plan_name, '') END ASC,
                CASE WHEN v_sort_by IN ('plan_name', 'fee_plan') AND v_sort_order = 'DESC' THEN COALESCE(acc.fee_plan_name, '') END DESC,
                CASE WHEN v_sort_by IN ('total_fee', 'total_billed') AND v_sort_order = 'ASC' THEN acc.total_billed END ASC,
                CASE WHEN v_sort_by IN ('total_fee', 'total_billed') AND v_sort_order = 'DESC' THEN acc.total_billed END DESC,
                CASE WHEN v_sort_by IN ('paid', 'total_paid') AND v_sort_order = 'ASC' THEN acc.total_paid END ASC,
                CASE WHEN v_sort_by IN ('paid', 'total_paid') AND v_sort_order = 'DESC' THEN acc.total_paid END DESC,
                CASE WHEN v_sort_by IN ('due', 'balance_due') AND v_sort_order = 'ASC' THEN acc.total_due END ASC,
                CASE WHEN v_sort_by IN ('due', 'balance_due') AND v_sort_order = 'DESC' THEN acc.total_due END DESC,
                CASE WHEN v_sort_by IN ('fee_status', 'status') AND v_sort_order = 'ASC' THEN acc.payment_status END ASC,
                CASE WHEN v_sort_by IN ('fee_status', 'status') AND v_sort_order = 'DESC' THEN acc.payment_status END DESC,
                p.full_name ASC,
                acc.created_at ASC
        ) AS row_seq
        FROM public.hostel_student_accounts acc
        JOIN public.profiles p ON acc.student_id = p.id
        LEFT JOIN public.hostel_admissions adm ON acc.admission_id = adm.id
        LEFT JOIN public.hostel_buildings b ON adm.hostel_id = b.id
        LEFT JOIN LATERAL (
            SELECT alc.room_id, alc.bed_id
            FROM public.hostel_allocations alc
            WHERE alc.student_id = acc.student_id
              AND alc.allocation_status = 'CHECKED_IN'
              AND alc.deleted_at IS NULL
            ORDER BY alc.created_at DESC
            LIMIT 1
        ) alc ON TRUE
        LEFT JOIN public.hostel_rooms r ON alc.room_id = r.id
        WHERE acc.school_id = p_school_id
          AND acc.academic_year = p_academic_year
          AND (p_hostel_id IS NULL OR adm.hostel_id = p_hostel_id)
          AND (p_class IS NULL OR p_class = 'All Classes' OR p.class ILIKE '%' || p_class || '%')
          AND (
              p_status IS NULL OR
              p_status = 'All Status' OR
              UPPER(acc.payment_status) = UPPER(p_status) OR
              (UPPER(p_status) IN ('OVERPAID', 'OVER PAID') AND UPPER(acc.payment_status) = 'OVERPAID')
          )
          AND (
              p_search IS NULL OR p_search = '' OR
              p.full_name ILIKE '%' || p_search || '%' OR
              p.roll_number::text ILIKE '%' || p_search || '%' OR
              COALESCE(p.user_id, '') ILIKE '%' || p_search || '%' OR
              COALESCE(r.room_number, '') ILIKE '%' || p_search || '%' OR
              COALESCE(b.name, '') ILIKE '%' || p_search || '%'
          )
        ORDER BY row_seq ASC
        LIMIT GREATEST(p_page_size, 1) OFFSET v_offset
    ) row_data
    JOIN public.hostel_student_accounts acc ON row_data.id = acc.id
    JOIN public.profiles p ON acc.student_id = p.id
    LEFT JOIN public.hostel_admissions adm ON acc.admission_id = adm.id
    LEFT JOIN public.hostel_buildings b ON adm.hostel_id = b.id
    LEFT JOIN LATERAL (
        SELECT alc.room_id, alc.bed_id
        FROM public.hostel_allocations alc
        WHERE alc.student_id = acc.student_id
          AND alc.allocation_status = 'CHECKED_IN'
          AND alc.deleted_at IS NULL
        ORDER BY alc.created_at DESC
        LIMIT 1
    ) alc ON TRUE
    LEFT JOIN public.hostel_rooms r ON alc.room_id = r.id;

    RETURN jsonb_build_object(
        'data', COALESCE(v_items, '[]'::JSONB),
        'pagination', jsonb_build_object(
            'page', p_page,
            'page_size', p_page_size,
            'total_records', v_total_count,
            'total_pages', GREATEST(1, CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1)))
        )
    );
END;
$function$;


-- 5. fn_hostel_leave_outing_list (Restore sort_by / sort_order across all UI keys)
CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_list(p_school_id uuid, p_filters jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_academic_year TEXT := p_filters->>'academic_year';
    v_student_id UUID := NULLIF(p_filters->>'student_id', '')::UUID;
    v_raw_hostel_id TEXT := NULLIF(TRIM(p_filters->>'hostel_id'), '');
    v_hostel_id UUID := NULL;
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
    v_sort_by TEXT := LOWER(TRIM(COALESCE(p_filters->>'sort_by', 'created_at')));
    v_sort_order TEXT := UPPER(TRIM(COALESCE(p_filters->>'sort_order', 'DESC')));
    v_offset INT := (v_page - 1) * v_page_size;

    v_total_records INT := 0;
    v_items JSONB := '[]'::JSONB;
BEGIN
    IF v_raw_hostel_id IS NOT NULL THEN
        IF v_raw_hostel_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
            v_hostel_id := v_raw_hostel_id::UUID;
        ELSE
            IF v_hostel_name IS NULL THEN
                v_hostel_name := v_raw_hostel_id;
            END IF;
        END IF;
    END IF;

    WITH base_query AS (
        SELECT
            ROW_NUMBER() OVER(
                ORDER BY
                    CASE WHEN v_sort_by = 'request_number' AND v_sort_order = 'ASC' THEN r.request_number END ASC,
                    CASE WHEN v_sort_by = 'request_number' AND v_sort_order = 'DESC' THEN r.request_number END DESC,
                    CASE WHEN v_sort_by = 'student_name' AND v_sort_order = 'ASC' THEN p.full_name END ASC,
                    CASE WHEN v_sort_by = 'student_name' AND v_sort_order = 'DESC' THEN p.full_name END DESC,
                    CASE WHEN v_sort_by IN ('hostel', 'hostel_name') AND v_sort_order = 'ASC' THEN COALESCE(b.name, r.building_name, '') END ASC,
                    CASE WHEN v_sort_by IN ('hostel', 'hostel_name') AND v_sort_order = 'DESC' THEN COALESCE(b.name, r.building_name, '') END DESC,
                    CASE WHEN v_sort_by = 'room_number' AND v_sort_order = 'ASC' THEN COALESCE(r.room_number, '') END ASC,
                    CASE WHEN v_sort_by = 'room_number' AND v_sort_order = 'DESC' THEN COALESCE(r.room_number, '') END DESC,
                    CASE WHEN v_sort_by = 'request_type' AND v_sort_order = 'ASC' THEN r.request_type END ASC,
                    CASE WHEN v_sort_by = 'request_type' AND v_sort_order = 'DESC' THEN r.request_type END DESC,
                    CASE WHEN v_sort_by IN ('departure_date', 'start_at', 'from') AND v_sort_order = 'ASC' THEN r.start_at END ASC,
                    CASE WHEN v_sort_by IN ('departure_date', 'start_at', 'from') AND v_sort_order = 'DESC' THEN r.start_at END DESC,
                    CASE WHEN v_sort_by IN ('expected_return', 'expected_return_at', 'to') AND v_sort_order = 'ASC' THEN r.expected_return_at END ASC,
                    CASE WHEN v_sort_by IN ('expected_return', 'expected_return_at', 'to') AND v_sort_order = 'DESC' THEN r.expected_return_at END DESC,
                    CASE WHEN v_sort_by = 'duration' AND v_sort_order = 'ASC' THEN (r.expected_return_at - r.start_at) END ASC,
                    CASE WHEN v_sort_by = 'duration' AND v_sort_order = 'DESC' THEN (r.expected_return_at - r.start_at) END DESC,
                    CASE WHEN v_sort_by = 'status' AND v_sort_order = 'ASC' THEN
                        CASE WHEN r.status = 'EXITED' AND NOW() > r.expected_return_at THEN 'OVERDUE' ELSE r.status END END ASC,
                    CASE WHEN v_sort_by = 'status' AND v_sort_order = 'DESC' THEN
                        CASE WHEN r.status = 'EXITED' AND NOW() > r.expected_return_at THEN 'OVERDUE' ELSE r.status END END DESC,
                    CASE WHEN v_sort_by = 'created_at' AND v_sort_order = 'ASC' THEN r.created_at END ASC,
                    CASE WHEN v_sort_by = 'created_at' AND v_sort_order = 'DESC' THEN r.created_at END DESC,
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
          AND (NOT v_currently_out OR r.status = 'EXITED')
          AND (NOT v_overdue_only OR (r.status = 'OVERDUE' OR (r.status = 'EXITED' AND NOW() > r.expected_return_at)))
          AND (NOT v_emergency_only OR r.is_emergency = true)
          AND (
              v_search = ''
              OR LOWER(p.full_name) LIKE '%' || v_search || '%'
              OR LOWER(COALESCE(p.admission_number, '')) LIKE '%' || v_search || '%'
              OR LOWER(COALESCE(p.roll_number::TEXT, '')) LIKE '%' || v_search || '%'
              OR LOWER(COALESCE(r.request_number, '')) LIKE '%' || v_search || '%'
              OR LOWER(COALESCE(r.room_number, '')) LIKE '%' || v_search || '%'
              OR LOWER(COALESCE(r.destination, '')) LIKE '%' || v_search || '%'
              OR LOWER(COALESCE(r.reason, '')) LIKE '%' || v_search || '%'
          )
    ),
    matching_rows AS (
        SELECT
            COUNT(*) OVER() AS total_count,
            *
        FROM base_query
        ORDER BY display_index ASC
        LIMIT v_page_size
        OFFSET v_offset
    )
    SELECT
        COALESCE(MAX(total_count), 0),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', id,
                    'display_index', display_index,
                    'request_number', request_number,
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
                ORDER BY display_index ASC
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
$function$;


-- 6. fn_hostel_complaints_list (Add category, hostel, room_number, reported_by sort keys)
CREATE OR REPLACE FUNCTION public.fn_hostel_complaints_list(
    p_school_id UUID,
    p_filters JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search TEXT := TRIM(COALESCE(p_filters->>'search', ''));
    v_hostel_filter TEXT := TRIM(COALESCE(p_filters->>'hostel', 'All Hostels'));
    v_category_filter TEXT := TRIM(COALESCE(p_filters->>'category', 'All Categories'));
    v_priority_filter TEXT := TRIM(COALESCE(p_filters->>'priority', 'All Priorities'));
    v_status_filter TEXT := TRIM(COALESCE(p_filters->>'status', 'All Status'));
    v_subtab_filter TEXT := TRIM(COALESCE(p_filters->>'subtab', 'All Complaints'));
    v_from_date TEXT := TRIM(COALESCE(p_filters->>'from_date', ''));
    v_to_date TEXT := TRIM(COALESCE(p_filters->>'to_date', ''));
    v_user_id TEXT := TRIM(COALESCE(p_filters->>'user_id', ''));
    v_page INT := GREATEST(COALESCE((p_filters->>'page')::INT, 1), 1);
    v_page_size INT := LEAST(GREATEST(COALESCE((p_filters->>'page_size')::INT, 10), 1), 100);
    v_sort_by TEXT := LOWER(TRIM(COALESCE(p_filters->>'sort_by', 'created_at')));
    v_sort_order TEXT := UPPER(TRIM(COALESCE(p_filters->>'sort_order', 'DESC')));
    v_academic_year TEXT := COALESCE(p_filters->>'academic_year', '2024 - 2025');
    v_offset INT := (v_page - 1) * v_page_size;
    v_total_records INT := 0;
    v_total_pages INT := 1;
    v_records JSONB := '[]'::JSONB;
BEGIN
    DROP TABLE IF EXISTS tmp_complaint_results;

    CREATE TEMP TABLE tmp_complaint_results ON COMMIT DROP AS
    SELECT
        c.id,
        c.complaint_number,
        c.title,
        c.description,
        c.category,
        c.subcategory,
        c.priority,
        c.status,
        c.reported_by_user_id,
        c.reported_by_name,
        c.reported_by_role,
        c.reported_by_class,
        c.reported_by_phone,
        c.reported_by_email,
        c.reported_by_avatar,
        c.hostel_id,
        c.hostel_name,
        c.building_name,
        c.floor_name,
        c.room_id,
        c.room_number,
        c.bed_code,
        c.facility_type,
        c.equipment_id,
        c.equipment_name,
        c.location_text,
        c.primary_assignee_user_id,
        c.primary_assignee_name,
        c.primary_assignee_role,
        c.source,
        c.response_due_at,
        c.resolution_due_at,
        c.first_response_at,
        c.resolved_at,
        c.completed_at,
        c.resolution_summary,
        c.resolution_type,
        c.rejection_reason,
        c.cancellation_reason,
        c.parts_used,
        c.resolution_cost,
        c.equipment_status_after,
        c.room_entry_permission,
        c.is_reopened,
        c.reopen_count,
        c.sla_status,
        c.escalation_level,
        c.thumbnail_url,
        c.attachments,
        c.version,
        c.created_at,
        c.updated_at,
        CASE
            WHEN c.status IN ('RESOLVED', 'COMPLETED') THEN 'Resolved'
            WHEN c.status = 'REJECTED' THEN 'Rejected'
            WHEN c.status = 'CANCELED' THEN 'Canceled'
            WHEN c.resolution_due_at IS NULL THEN 'No SLA'
            WHEN c.resolution_due_at < NOW() THEN
                CONCAT('Overdue by ',
                       EXTRACT(DAY FROM (NOW() - c.resolution_due_at))::INT, 'd ',
                       EXTRACT(HOUR FROM (NOW() - c.resolution_due_at))::INT, 'h')
            ELSE
                CONCAT(EXTRACT(HOUR FROM (c.resolution_due_at - NOW()))::INT, 'h remaining')
        END AS sla_display
    FROM public.hostel_complaints c
    WHERE c.school_id = p_school_id
      AND c.deleted_at IS NULL
      AND (v_academic_year = 'ALL' OR c.academic_year = v_academic_year)
      AND (v_from_date = '' OR c.created_at >= v_from_date::TIMESTAMP)
      AND (v_to_date = '' OR c.created_at < (v_to_date::DATE + INTERVAL '1 day'))
      AND (
          v_search = ''
          OR c.complaint_number ILIKE '%' || v_search || '%'
          OR c.title ILIKE '%' || v_search || '%'
          OR c.description ILIKE '%' || v_search || '%'
          OR c.reported_by_name ILIKE '%' || v_search || '%'
          OR c.reported_by_class ILIKE '%' || v_search || '%'
          OR c.room_number ILIKE '%' || v_search || '%'
          OR c.hostel_name ILIKE '%' || v_search || '%'
          OR c.category ILIKE '%' || v_search || '%'
          OR c.primary_assignee_name ILIKE '%' || v_search || '%'
          OR c.equipment_name ILIKE '%' || v_search || '%'
      )
      AND (v_hostel_filter IN ('All Hostels', 'ALL', '') OR c.hostel_name = v_hostel_filter)
      AND (v_category_filter IN ('All Categories', 'ALL', '') OR c.category ILIKE v_category_filter)
      AND (v_priority_filter IN ('All Priorities', 'ALL', '') OR c.priority = UPPER(v_priority_filter))
      AND (
          v_status_filter IN ('All Status', 'ALL', '')
          OR (v_status_filter = 'Open' AND c.status IN ('NEW', 'ACTIVE'))
          OR (v_status_filter = 'In Progress' AND c.status = 'IN_PROGRESS')
          OR (v_status_filter = 'Pending' AND c.status IN ('NEW', 'ACTIVE', 'IN_PROGRESS', 'ON_HOLD'))
          OR (c.status = UPPER(v_status_filter))
      )
      AND (
          v_subtab_filter IN ('All Complaints', 'Total Complaints', 'ALL', '')
          OR (v_subtab_filter = 'My Complaints' AND (v_user_id = '' OR c.reported_by_user_id::TEXT = v_user_id OR c.primary_assignee_user_id::TEXT = v_user_id))
          OR (v_subtab_filter = 'Pending' AND c.status IN ('NEW', 'ACTIVE', 'IN_PROGRESS', 'ON_HOLD'))
          OR (v_subtab_filter = 'Overdue' AND c.status IN ('NEW', 'ACTIVE', 'IN_PROGRESS', 'ON_HOLD') AND (c.resolution_due_at IS NOT NULL AND c.resolution_due_at < NOW() OR c.sla_status = 'OVERDUE'))
          OR (v_subtab_filter = 'Resolved' AND c.status IN ('RESOLVED', 'COMPLETED'))
          OR (v_subtab_filter IN ('High Priority', 'HIGH_PRIORITY') AND c.priority IN ('HIGH', 'URGENT', 'CRITICAL') AND c.status NOT IN ('RESOLVED', 'COMPLETED', 'REJECTED', 'CANCELED'))
          OR (v_subtab_filter IN ('Maintenance', 'Maintenance Related') AND c.category IN ('Plumbing', 'Electrical', 'Housekeeping', 'Furniture', 'AC/Heating', 'Pest Control', 'Maintenance', 'Equipment'))
          OR (v_subtab_filter = 'Room Related' AND c.room_number IS NOT NULL AND c.room_number != '' AND c.room_number NOT ILIKE '%gate%' AND c.room_number NOT ILIKE '%mess%')
          OR (v_subtab_filter = 'Facility Related' AND (c.facility_type != 'Room' OR c.room_number ILIKE '%gate%' OR c.room_number ILIKE '%mess%'))
      );

    SELECT COUNT(*) INTO v_total_records FROM tmp_complaint_results;
    v_total_pages := GREATEST(CEIL(v_total_records::NUMERIC / v_page_size::NUMERIC)::INT, 1);

    SELECT jsonb_agg(
        jsonb_build_object(
            'id', r.id,
            'complaint_number', r.complaint_number,
            'title', r.title,
            'description', r.description,
            'category', r.category,
            'subcategory', r.subcategory,
            'priority', r.priority,
            'status', r.status,
            'reported_by_user_id', r.reported_by_user_id,
            'reported_by_name', r.reported_by_name,
            'reported_by_role', r.reported_by_role,
            'reported_by_class', r.reported_by_class,
            'reported_by_phone', r.reported_by_phone,
            'reported_by_avatar', r.reported_by_avatar,
            'hostel_id', r.hostel_id,
            'hostel_name', r.hostel_name,
            'building_name', r.building_name,
            'floor_name', r.floor_name,
            'room_id', r.room_id,
            'room_number', r.room_number,
            'bed_code', r.bed_code,
            'facility_type', r.facility_type,
            'equipment_id', r.equipment_id,
            'equipment_name', r.equipment_name,
            'location_text', r.location_text,
            'primary_assignee_user_id', r.primary_assignee_user_id,
            'primary_assignee_name', r.primary_assignee_name,
            'primary_assignee_role', r.primary_assignee_role,
            'source', r.source,
            'response_due_at', r.response_due_at,
            'resolution_due_at', r.resolution_due_at,
            'resolved_at', r.resolved_at,
            'completed_at', r.completed_at,
            'resolution_summary', r.resolution_summary,
            'resolution_type', r.resolution_type,
            'rejection_reason', r.rejection_reason,
            'cancellation_reason', r.cancellation_reason,
            'sla_status', r.sla_status,
            'sla_display', r.sla_display,
            'thumbnail_url', r.thumbnail_url,
            'attachments', r.attachments,
            'version', r.version,
            'created_at', r.created_at,
            'updated_at', r.updated_at
        )
        ORDER BY r.row_seq ASC
    ) INTO v_records
    FROM (
        SELECT
            tmp.*,
            ROW_NUMBER() OVER (
                ORDER BY
                    CASE WHEN v_sort_by = 'priority' AND v_sort_order = 'ASC' THEN
                        CASE priority WHEN 'CRITICAL' THEN 1 WHEN 'URGENT' THEN 2 WHEN 'HIGH' THEN 3 WHEN 'MEDIUM' THEN 4 ELSE 5 END END ASC,
                    CASE WHEN v_sort_by = 'priority' AND v_sort_order = 'DESC' THEN
                        CASE priority WHEN 'CRITICAL' THEN 1 WHEN 'URGENT' THEN 2 WHEN 'HIGH' THEN 3 WHEN 'MEDIUM' THEN 4 ELSE 5 END END DESC,
                    CASE WHEN v_sort_by = 'title' AND v_sort_order = 'ASC' THEN title END ASC,
                    CASE WHEN v_sort_by = 'title' AND v_sort_order = 'DESC' THEN title END DESC,
                    CASE WHEN v_sort_by = 'category' AND v_sort_order = 'ASC' THEN category END ASC,
                    CASE WHEN v_sort_by = 'category' AND v_sort_order = 'DESC' THEN category END DESC,
                    CASE WHEN v_sort_by IN ('hostel', 'hostel_name') AND v_sort_order = 'ASC' THEN COALESCE(hostel_name, '') END ASC,
                    CASE WHEN v_sort_by IN ('hostel', 'hostel_name') AND v_sort_order = 'DESC' THEN COALESCE(hostel_name, '') END DESC,
                    CASE WHEN v_sort_by = 'room_number' AND v_sort_order = 'ASC' THEN COALESCE(room_number, '') END ASC,
                    CASE WHEN v_sort_by = 'room_number' AND v_sort_order = 'DESC' THEN COALESCE(room_number, '') END DESC,
                    CASE WHEN v_sort_by IN ('reported_by', 'reported_by_name') AND v_sort_order = 'ASC' THEN COALESCE(reported_by_name, '') END ASC,
                    CASE WHEN v_sort_by IN ('reported_by', 'reported_by_name') AND v_sort_order = 'DESC' THEN COALESCE(reported_by_name, '') END DESC,
                    CASE WHEN v_sort_by = 'status' AND v_sort_order = 'ASC' THEN status END ASC,
                    CASE WHEN v_sort_by = 'status' AND v_sort_order = 'DESC' THEN status END DESC,
                    CASE WHEN v_sort_by = 'created_at' AND v_sort_order = 'ASC' THEN created_at END ASC,
                    CASE WHEN v_sort_by = 'created_at' AND v_sort_order = 'DESC' THEN created_at END DESC,
                    created_at DESC
            ) AS row_seq
        FROM tmp_complaint_results tmp
        LIMIT v_page_size OFFSET v_offset
    ) r;

    RETURN jsonb_build_object(
        'success', true,
        'records', COALESCE(v_records, '[]'::JSONB),
        'pagination', jsonb_build_object(
            'total_records', v_total_records,
            'page', v_page,
            'page_size', v_page_size,
            'total_pages', v_total_pages,
            'has_next', v_page < v_total_pages,
            'has_prev', v_page > 1
        )
    );
END;
$$;
