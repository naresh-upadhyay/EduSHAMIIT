-- ----------------------------------------------------------------------------
-- 3. STORED PROCEDURE: fn_hostel_get_overview_analytics (TAB 0: OVERVIEW)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_hostel_get_overview_analytics(
    p_school_id UUID,
    p_academic_year TEXT DEFAULT '2024 - 2025'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_buildings INT := 0;
    v_total_rooms INT := 0;
    v_total_beds INT := 0;
    v_occupied_beds INT := 0;
    v_available_beds INT := 0;
    v_maintenance_beds INT := 0;
    v_occupancy_rate NUMERIC := 0.0;
    v_active_residents INT := 0;
    v_staff_count INT := 0;
    v_staff_on_duty INT := 0;
    v_pending_leaves INT := 0;
    v_currently_out INT := 0;
    v_open_complaints INT := 0;
    v_urgent_complaints INT := 0;
    v_total_billed NUMERIC := 0.0;
    v_total_paid NUMERIC := 0.0;
    v_recovery_rate NUMERIC := 0.0;
    v_buildings_data JSONB := '[]'::JSONB;
    v_room_types_data JSONB := '[]'::JSONB;
    v_recent_movements JSONB := '[]'::JSONB;
    v_recent_complaints JSONB := '[]'::JSONB;
BEGIN
    -- 1. Building and Capacity Counts
    SELECT COUNT(*) INTO v_total_buildings
    FROM public.hostel_buildings
    WHERE school_id = p_school_id AND deleted_at IS NULL;

    SELECT COUNT(*) INTO v_total_rooms
    FROM public.hostel_rooms
    WHERE school_id = p_school_id AND deleted_at IS NULL;

    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'OCCUPIED'),
        COUNT(*) FILTER (WHERE status = 'AVAILABLE'),
        COUNT(*) FILTER (WHERE status = 'MAINTENANCE')
    INTO v_total_beds, v_occupied_beds, v_available_beds, v_maintenance_beds
    FROM public.hostel_beds
    WHERE school_id = p_school_id AND deleted_at IS NULL;

    IF v_total_beds > 0 THEN
        v_occupancy_rate := ROUND((v_occupied_beds::NUMERIC / v_total_beds::NUMERIC) * 100.0, 1);
    ELSE
        v_occupancy_rate := 0.0;
    END IF;

    -- 2. Resident & Staff Counts
    SELECT COUNT(*) INTO v_active_residents
    FROM public.hostel_allocations
    WHERE school_id = p_school_id 
      AND allocation_status IN ('CHECKED_IN', 'CONFIRMED', 'RESERVED') 
      AND deleted_at IS NULL;

    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE duty_status = 'ON_DUTY' OR assignment_status = 'ACTIVE')
    INTO v_staff_count, v_staff_on_duty
    FROM public.hostel_staff_assignments
    WHERE school_id = p_school_id AND deleted_at IS NULL;

    -- 3. Leaves & Movement
    SELECT 
        COUNT(*) FILTER (WHERE status = 'PENDING'),
        COUNT(*) FILTER (WHERE status = 'APPROVED' AND actual_return_at IS NULL AND start_at <= NOW())
    INTO v_pending_leaves, v_currently_out
    FROM public.hostel_leave_outing_requests
    WHERE school_id = p_school_id AND deleted_at IS NULL;

    -- 4. Complaints
    SELECT 
        COUNT(*) FILTER (WHERE status IN ('PENDING', 'ASSIGNED', 'IN_PROGRESS', 'OPEN')),
        COUNT(*) FILTER (WHERE status IN ('PENDING', 'ASSIGNED', 'IN_PROGRESS', 'OPEN') AND priority IN ('HIGH', 'URGENT'))
    INTO v_open_complaints, v_urgent_complaints
    FROM public.hostel_complaints
    WHERE school_id = p_school_id AND deleted_at IS NULL;

    -- 5. Financial Overview
    SELECT 
        COALESCE(SUM(net_amount), 0),
        COALESCE(SUM(paid_amount), 0)
    INTO v_total_billed, v_total_paid
    FROM public.hostel_invoices
    WHERE school_id = p_school_id AND academic_year = p_academic_year;

    IF v_total_billed > 0 THEN
        v_recovery_rate := ROUND((v_total_paid / v_total_billed) * 100.0, 1);
    ELSE
        v_recovery_rate := 0.0;
    END IF;

    -- 6. Buildings Breakdown
    SELECT COALESCE(jsonb_agg(b_row), '[]'::JSONB) INTO v_buildings_data
    FROM (
        SELECT 
            b.id AS building_id,
            b.name AS building_name,
            b.code,
            b.gender_policy,
            COUNT(DISTINCT r.id) AS total_rooms,
            COUNT(DISTINCT bd.id) AS total_beds,
            COUNT(DISTINCT bd.id) FILTER (WHERE bd.status = 'OCCUPIED') AS occupied_beds,
            CASE 
                WHEN COUNT(DISTINCT bd.id) > 0 
                THEN ROUND((COUNT(DISTINCT bd.id) FILTER (WHERE bd.status = 'OCCUPIED')::NUMERIC / COUNT(DISTINCT bd.id)::NUMERIC) * 100.0, 1)
                ELSE 0.0 
            END AS occupancy_rate
        FROM public.hostel_buildings b
        LEFT JOIN public.hostel_rooms r ON r.building_id = b.id AND r.deleted_at IS NULL
        LEFT JOIN public.hostel_beds bd ON bd.room_id = r.id AND bd.deleted_at IS NULL
        WHERE b.school_id = p_school_id AND b.deleted_at IS NULL
        GROUP BY b.id, b.name, b.code, b.gender_policy
        ORDER BY b.name ASC
    ) b_row;

    -- 7. Room Types Distribution
    SELECT COALESCE(jsonb_agg(rt_row), '[]'::JSONB) INTO v_room_types_data
    FROM (
        SELECT 
            r.room_type,
            COUNT(DISTINCT r.id) AS room_count,
            COUNT(DISTINCT bd.id) AS bed_count,
            COUNT(DISTINCT bd.id) FILTER (WHERE bd.status = 'OCCUPIED') AS occupied_beds
        FROM public.hostel_rooms r
        LEFT JOIN public.hostel_beds bd ON bd.room_id = r.id AND bd.deleted_at IS NULL
        WHERE r.school_id = p_school_id AND r.deleted_at IS NULL
        GROUP BY r.room_type
        ORDER BY room_count DESC
    ) rt_row;

    -- 8. Recent Movement Logs (Top 6)
    SELECT COALESCE(jsonb_agg(m_row), '[]'::JSONB) INTO v_recent_movements
    FROM (
        SELECT 
            lr.id,
            COALESCE(p.full_name, 'Resident') AS student_name,
            lr.request_type,
            lr.request_subtype,
            lr.reason AS purpose,
            lr.start_at::TEXT AS departure_date,
            lr.expected_return_at::TEXT AS expected_return,
            lr.actual_return_at::TEXT AS actual_return,
            lr.status,
            lr.request_number AS gate_pass_code
        FROM public.hostel_leave_outing_requests lr
        LEFT JOIN public.profiles p ON p.id = lr.student_id
        WHERE lr.school_id = p_school_id AND lr.deleted_at IS NULL
        ORDER BY lr.created_at DESC
        LIMIT 6
    ) m_row;

    -- 9. Priority Complaints (Top 6)
    SELECT COALESCE(jsonb_agg(c_row), '[]'::JSONB) INTO v_recent_complaints
    FROM (
        SELECT 
            c.id,
            c.complaint_number AS ticket_number,
            c.title,
            c.category,
            c.priority,
            c.status,
            COALESCE(p.full_name, 'Resident') AS student_name,
            c.room_number,
            c.created_at::TEXT AS created_at
        FROM public.hostel_complaints c
        LEFT JOIN public.profiles p ON p.id = c.reported_by_user_id
        WHERE c.school_id = p_school_id AND c.deleted_at IS NULL
        ORDER BY 
            CASE c.priority WHEN 'URGENT' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 ELSE 4 END,
            c.created_at DESC
        LIMIT 6
    ) c_row;

    -- Construct Final Comprehensive Payload
    RETURN jsonb_build_object(
        'kpis', jsonb_build_object(
            'total_buildings', v_total_buildings,
            'total_rooms', v_total_rooms,
            'total_beds', v_total_beds,
            'occupied_beds', v_occupied_beds,
            'available_beds', v_available_beds,
            'maintenance_beds', v_maintenance_beds,
            'occupancy_rate', v_occupancy_rate,
            'active_residents', v_active_residents,
            'staff_count', v_staff_count,
            'staff_on_duty', v_staff_on_duty,
            'pending_leaves', v_pending_leaves,
            'currently_out', v_currently_out,
            'open_complaints', v_open_complaints,
            'urgent_complaints', v_urgent_complaints,
            'total_billed', v_total_billed,
            'total_paid', v_total_paid,
            'total_dues', GREATEST(v_total_billed - v_total_paid, 0),
            'recovery_rate', v_recovery_rate
        ),
        'building_occupancy', v_buildings_data,
        'room_types', v_room_types_data,
        'recent_movements', v_recent_movements,
        'priority_complaints', v_recent_complaints
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 4. STORED PROCEDURE: fn_hostel_get_reports_data (TAB 8: REPORTS & EXPORTS)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_hostel_get_reports_data(
    p_school_id UUID,
    p_report_type TEXT,
    p_academic_year TEXT DEFAULT '2024 - 2025',
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB := '[]'::JSONB;
BEGIN
    IF p_report_type = 'occupancy' THEN
        SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_result
        FROM (
            SELECT 
                b.name AS building_name,
                f.floor_name AS floor_name,
                r.room_number,
                r.room_type,
                r.target_capacity AS capacity,
                COALESCE(r.current_occupancy, 0) AS occupied_beds,
                GREATEST(r.target_capacity - COALESCE(r.current_occupancy, 0), 0) AS vacant_beds,
                r.operational_status AS room_status,
                r.monthly_fee,
                r.gender_restriction
            FROM public.hostel_rooms r
            JOIN public.hostel_buildings b ON b.id = r.building_id
            JOIN public.hostel_floors f ON f.id = r.floor_id
            WHERE r.school_id = p_school_id AND r.deleted_at IS NULL
            ORDER BY b.name, f.floor_number, r.room_number
        ) row_data;

    ELSIF p_report_type = 'residents' THEN
        SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_result
        FROM (
            SELECT 
                p.admission_number AS roll_no,
                COALESCE(p.full_name, 'Student') AS student_name,
                p.gender,
                COALESCE(p.class, 'N/A') AS class_name,
                b.name AS building_name,
                r.room_number,
                bd.bed_code AS bed_label,
                ha.check_in_date::DATE::TEXT AS admission_date,
                ha.monthly_fee,
                ha.fee_status,
                ha.allocation_status AS resident_status,
                p.father_name,
                p.mother_name,
                p.phone AS student_phone,
                p.emergency_contact_phone AS guardian_phone
            FROM public.hostel_allocations ha
            JOIN public.profiles p ON p.id = ha.student_id
            LEFT JOIN public.hostel_rooms r ON r.id = ha.room_id
            LEFT JOIN public.hostel_buildings b ON b.id = ha.building_id
            LEFT JOIN public.hostel_beds bd ON bd.id = ha.bed_id
            WHERE ha.school_id = p_school_id 
              AND ha.allocation_status IN ('CHECKED_IN', 'CONFIRMED', 'RESERVED') 
              AND ha.deleted_at IS NULL
            ORDER BY b.name, r.room_number, p.full_name
        ) row_data;

    ELSIF p_report_type = 'fee_defaulters' THEN
        SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_result
        FROM (
            SELECT 
                p.admission_number AS roll_no,
                COALESCE(p.full_name, 'Student') AS student_name,
                b.name AS building_name,
                r.room_number,
                inv.invoice_number,
                inv.academic_year,
                inv.net_amount AS billed_amount,
                inv.paid_amount,
                inv.balance_amount AS pending_due,
                inv.due_date::TEXT AS due_date,
                inv.status AS payment_status,
                GREATEST(CURRENT_DATE - inv.due_date, 0) AS overdue_days
            FROM public.hostel_invoices inv
            JOIN public.profiles p ON p.id = inv.student_id
            LEFT JOIN public.hostel_allocations ha ON ha.student_id = inv.student_id 
                AND ha.allocation_status IN ('CHECKED_IN', 'CONFIRMED') 
                AND ha.deleted_at IS NULL
            LEFT JOIN public.hostel_rooms r ON r.id = ha.room_id
            LEFT JOIN public.hostel_buildings b ON b.id = ha.building_id
            WHERE inv.school_id = p_school_id 
              AND inv.balance_amount > 0
              AND (p_academic_year IS NULL OR inv.academic_year = p_academic_year)
            ORDER BY overdue_days DESC, pending_due DESC
        ) row_data;

    ELSIF p_report_type = 'movement' THEN
        SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_result
        FROM (
            SELECT 
                p.admission_number AS roll_no,
                COALESCE(p.full_name, 'Student') AS student_name,
                lr.building_name,
                lr.room_number,
                lr.request_type,
                lr.request_subtype,
                lr.reason AS purpose,
                lr.destination,
                lr.start_at::TEXT AS departure_date,
                lr.expected_return_at::TEXT AS expected_return,
                lr.actual_return_at::TEXT AS actual_return,
                lr.request_number AS gate_pass_code,
                lr.status,
                lr.guardian_confirmed
            FROM public.hostel_leave_outing_requests lr
            JOIN public.profiles p ON p.id = lr.student_id
            WHERE lr.school_id = p_school_id AND lr.deleted_at IS NULL
              AND (p_start_date IS NULL OR lr.start_at::DATE >= p_start_date)
              AND (p_end_date IS NULL OR lr.start_at::DATE <= p_end_date)
            ORDER BY lr.start_at DESC, lr.created_at DESC
        ) row_data;

    ELSIF p_report_type = 'complaints' THEN
        SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_result
        FROM (
            SELECT 
                c.complaint_number AS ticket_number,
                c.title,
                c.category,
                c.priority,
                c.status,
                c.room_number,
                c.building_name,
                COALESCE(p.full_name, 'Resident') AS student_name,
                c.primary_assignee_name AS assigned_staff,
                c.created_at::TEXT AS lodged_date,
                c.resolved_at::TEXT AS resolved_date,
                c.resolution_summary
            FROM public.hostel_complaints c
            LEFT JOIN public.profiles p ON p.id = c.reported_by_user_id
            WHERE c.school_id = p_school_id AND c.deleted_at IS NULL
              AND (p_start_date IS NULL OR c.created_at::DATE >= p_start_date)
              AND (p_end_date IS NULL OR c.created_at::DATE <= p_end_date)
            ORDER BY c.created_at DESC
        ) row_data;

    ELSE
        v_result := '[]'::JSONB;
    END IF;

    RETURN jsonb_build_object(
        'report_type', p_report_type,
        'record_count', jsonb_array_length(v_result),
        'records', v_result
    );
END;
$$;
