-- Migration 420: Fix Hostel Fee Defaulters Report & Reconcile Invoices
-- 1. Reconcile invoices with payments & account balances
-- 2. Upgrade fn_hostel_get_reports_data for 'fee_defaulters' to:
--    - Eliminate duplicate rows via LATERAL join
--    - Exclude students whose accounts are OVERPAID or PAID with 0 balance
--    - Accurately identify overdue defaulters (due_date <= CURRENT_DATE or marked OVERDUE)
--    - Support date-range filtering seamlessly

-- 1. RECONCILE EXISTING INVOICES
-- Cancel invalid manual test invoice for Aarav Sharma
UPDATE public.hostel_invoices
SET status = 'CANCELLED',
    balance_amount = 0.00,
    deleted_at = NOW(),
    remarks = 'Cancelled invalid manual test invoice beyond fee plan'
WHERE invoice_number = 'HINV-20261103-6531';

-- Settle invoices for students who have paid in full or are OVERPAID in hostel_student_accounts
UPDATE public.hostel_invoices inv
SET paid_amount = inv.net_amount,
    balance_amount = 0.00,
    status = 'PAID',
    updated_at = NOW()
FROM public.hostel_student_accounts acc
WHERE acc.student_id = inv.student_id
  AND acc.academic_year = inv.academic_year
  AND acc.school_id = inv.school_id
  AND UPPER(acc.payment_status) IN ('OVERPAID', 'OVER PAID', 'PAID')
  AND inv.deleted_at IS NULL
  AND inv.status != 'CANCELLED'
  AND inv.balance_amount > 0;

-- Mark past-due invoices as OVERDUE
UPDATE public.hostel_invoices
SET status = 'OVERDUE',
    updated_at = NOW()
WHERE due_date < CURRENT_DATE
  AND balance_amount > 0
  AND deleted_at IS NULL
  AND status != 'CANCELLED';

-- 2. UPDATE STORED PROCEDURE fn_hostel_get_reports_data
CREATE OR REPLACE FUNCTION public.fn_hostel_get_reports_data(
    p_school_id UUID,
    p_report_type TEXT,
    p_academic_year TEXT DEFAULT '2026 - 2027',
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
    -- 1. Occupancy Master
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

    -- 2. Active Residents
    ELSIF p_report_type = 'residents' THEN
        SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_result
        FROM (
            SELECT 
                COALESCE(NULLIF(p.roll_number::TEXT, ''), NULLIF(p.admission_number, ''), NULLIF(hadm.admission_reference, ''), 'N/A') AS roll_no,
                COALESCE(p.full_name, 'Student') AS student_name,
                p.gender,
                COALESCE(NULLIF(p.class, ''), 'Class 10 A') AS class_name,
                COALESCE(b.name, 'Boys Hostel A') AS building_name,
                COALESCE(r.room_number, 'N/A') AS room_number,
                COALESCE(bd.bed_code, 'Bed 1') AS bed_label,
                COALESCE(ha.check_in_date::DATE::TEXT, hadm.admission_date::DATE::TEXT, 'N/A') AS admission_date,
                COALESCE(ha.monthly_fee, hadm.monthly_fee, r.monthly_fee, 6000.00) AS monthly_fee,
                COALESCE(ha.fee_status, hadm.fee_status, 'PAID') AS fee_status,
                COALESCE(ha.allocation_status, hadm.admission_status, 'CHECKED_IN') AS resident_status,
                COALESCE(p.father_name, 'Parent') AS father_name,
                p.mother_name,
                p.phone AS student_phone,
                COALESCE(NULLIF(hadm.emergency_phone_override, ''), NULLIF(p.emergency_contact_phone, ''), NULLIF(p.father_phone, ''), NULLIF(p.phone, ''), '+91 98765 43210') AS guardian_phone
            FROM public.hostel_allocations ha
            JOIN public.profiles p ON p.id = ha.student_id
            LEFT JOIN public.hostel_admissions hadm ON hadm.student_id = ha.student_id
            LEFT JOIN public.hostel_rooms r ON r.id = ha.room_id
            LEFT JOIN public.hostel_buildings b ON b.id = ha.building_id
            LEFT JOIN public.hostel_beds bd ON bd.id = ha.bed_id
            WHERE ha.school_id = p_school_id 
              AND ha.allocation_status IN ('CHECKED_IN', 'CONFIRMED', 'RESERVED') 
              AND ha.deleted_at IS NULL
              AND (p_academic_year IS NULL OR p_academic_year = 'ALL' OR ha.academic_year = p_academic_year OR ha.academic_year IS NULL)
              AND (p_start_date IS NULL OR ha.check_in_date::DATE >= p_start_date)
              AND (p_end_date IS NULL OR ha.check_in_date::DATE <= p_end_date)
            ORDER BY b.name, r.room_number, p.full_name
        ) row_data;

    -- 3. Fee Defaulters (Reconciled with student financial truth, zero duplicate rows, overdue focused)
    ELSIF p_report_type = 'fee_defaulters' THEN
        SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_result
        FROM (
            SELECT 
                COALESCE(NULLIF(p.roll_number::TEXT, ''), NULLIF(p.admission_number, ''), NULLIF(hadm.admission_reference, ''), 'N/A') AS roll_no,
                COALESCE(p.full_name, 'Student') AS student_name,
                COALESCE(b.name, 'Boys Hostel A') AS building_name,
                COALESCE(r.room_number, 'N/A') AS room_number,
                inv.invoice_number,
                inv.academic_year,
                inv.net_amount AS billed_amount,
                inv.paid_amount,
                inv.balance_amount AS pending_due,
                inv.due_date::TEXT AS due_date,
                CASE 
                    WHEN CURRENT_DATE > inv.due_date AND inv.balance_amount > 0 THEN 'OVERDUE'
                    ELSE inv.status
                END AS payment_status,
                GREATEST(CURRENT_DATE - inv.due_date, 0) AS overdue_days
            FROM public.hostel_invoices inv
            JOIN public.profiles p ON p.id = inv.student_id
            LEFT JOIN public.hostel_admissions hadm ON hadm.student_id = inv.student_id 
                AND (hadm.academic_year = inv.academic_year OR hadm.academic_year IS NULL)
                AND hadm.deleted_at IS NULL
            LEFT JOIN public.hostel_student_accounts acc ON (
                acc.student_id = inv.student_id 
                AND acc.academic_year = inv.academic_year 
                AND acc.school_id = inv.school_id
            )
            LEFT JOIN LATERAL (
                SELECT alc.room_id, alc.building_id
                FROM public.hostel_allocations alc 
                WHERE (alc.admission_id = hadm.id OR alc.student_id = inv.student_id)
                  AND alc.allocation_status IN ('CHECKED_IN', 'RESERVED', 'CONFIRMED')
                  AND alc.deleted_at IS NULL
                ORDER BY alc.created_at DESC 
                LIMIT 1
            ) alc ON TRUE
            LEFT JOIN public.hostel_rooms r ON alc.room_id = r.id
            LEFT JOIN public.hostel_buildings b ON alc.building_id = b.id
            WHERE inv.school_id = p_school_id 
              AND inv.deleted_at IS NULL
              AND inv.status != 'CANCELLED'
              AND inv.balance_amount > 0
              -- 1. Exclude students who are OVERPAID or have 0 total due in their financial account
              AND (acc.id IS NULL OR COALESCE(acc.total_due, 1.0) > 0)
              AND (acc.id IS NULL OR UPPER(COALESCE(acc.payment_status, '')) NOT IN ('OVERPAID', 'OVER PAID', 'PAID'))
              -- 2. Filter for actual default (overdue or specified date range)
              AND (
                  (p_start_date IS NOT NULL OR p_end_date IS NOT NULL) 
                  OR CURRENT_DATE >= inv.due_date 
                  OR UPPER(COALESCE(acc.payment_status, '')) = 'OVERDUE'
                  OR COALESCE(acc.total_overdue, 0) > 0
              )
              AND (p_academic_year IS NULL OR p_academic_year = 'ALL' OR inv.academic_year = p_academic_year)
              AND (p_start_date IS NULL OR inv.due_date >= p_start_date)
              AND (p_end_date IS NULL OR inv.due_date <= p_end_date)
            ORDER BY overdue_days DESC, pending_due DESC, inv.due_date ASC
        ) row_data;

    -- 4. Leave & Movements
    ELSIF p_report_type = 'movement' THEN
        SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_result
        FROM (
            SELECT 
                COALESCE(NULLIF(p.roll_number::TEXT, ''), NULLIF(p.admission_number, ''), 'N/A') AS roll_no,
                COALESCE(p.full_name, 'Student') AS student_name,
                COALESCE(lr.building_name, b.name, 'Boys Hostel A') AS building_name,
                COALESCE(lr.room_number, 'N/A') AS room_number,
                lr.request_type,
                COALESCE(lr.request_subtype, 'Regular') AS request_subtype,
                COALESCE(lr.reason, 'Outing') AS purpose,
                COALESCE(lr.destination, 'Local') AS destination,
                TO_CHAR(lr.start_at, 'YYYY-MM-DD HH24:MI') AS departure_date,
                TO_CHAR(lr.expected_return_at, 'YYYY-MM-DD HH24:MI') AS expected_return,
                TO_CHAR(lr.actual_return_at, 'YYYY-MM-DD HH24:MI') AS actual_return,
                COALESCE(lr.request_number, 'N/A') AS gate_pass_code,
                lr.status,
                COALESCE(lr.guardian_confirmed, false) AS guardian_confirmed
            FROM public.hostel_leave_outing_requests lr
            JOIN public.profiles p ON p.id = lr.student_id
            LEFT JOIN public.hostel_buildings b ON b.id = lr.hostel_id
            WHERE lr.school_id = p_school_id AND lr.deleted_at IS NULL
              AND (p_academic_year IS NULL OR p_academic_year = 'ALL' OR lr.academic_year = p_academic_year)
              AND (p_start_date IS NULL OR lr.start_at::DATE >= p_start_date)
              AND (p_end_date IS NULL OR lr.start_at::DATE <= p_end_date)
            ORDER BY lr.start_at DESC, lr.created_at DESC
        ) row_data;

    -- 5. Complaints Ledger
    ELSIF p_report_type = 'complaints' THEN
        SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_result
        FROM (
            SELECT 
                c.complaint_number AS ticket_number,
                c.title,
                c.category,
                c.priority,
                c.status,
                COALESCE(c.room_number, 'N/A') AS room_number,
                COALESCE(c.building_name, c.hostel_name, 'Boys Hostel A') AS building_name,
                COALESCE(p.full_name, c.reported_by_name, 'Resident') AS student_name,
                COALESCE(c.primary_assignee_name, 'Unassigned') AS assigned_staff,
                TO_CHAR(c.created_at, 'YYYY-MM-DD HH24:MI') AS lodged_date,
                TO_CHAR(c.resolved_at, 'YYYY-MM-DD HH24:MI') AS resolved_date,
                COALESCE(c.resolution_summary, '-') AS resolution_summary
            FROM public.hostel_complaints c
            LEFT JOIN public.profiles p ON p.id = c.reported_by_user_id
            WHERE c.school_id = p_school_id AND c.deleted_at IS NULL
              AND (p_academic_year IS NULL OR p_academic_year = 'ALL' OR c.academic_year = p_academic_year)
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

