-- ==============================================================================
-- Migration 568: Staff Salary Comprehensive Mathematical Consistency & SSOT
-- Fixes:
-- 1. Double counting of other_deductions vs insurance_deduction
-- 2. Medical allowance and insurance deduction inclusion in all SPs and models
-- 3. Elimination of role / designation discrepancies across screens (King Doe & all staff)
-- 4. Payout status reflection (On Hold vs Pending vs Paid) in all dialogs
-- 5. KPI card counts excluding parents/students
-- 6. Canonical fn_update_staff_payout_status overload support
-- ==============================================================================

-- Step 1: Sanitize King Doe and all staff designations in public.profiles
UPDATE public.profiles
SET 
    designation = 'Executive Director & Super Admin',
    department = 'Administration',
    employee_id = 'EMP-5198C4'
WHERE id = '5198c4b0-f1cb-45db-9649-41688d0438ba';

-- Step 2: Remove any non-staff from salary structures and payouts
DELETE FROM public.staff_salary_payouts 
WHERE staff_id IN (SELECT id FROM public.profiles WHERE role IN ('parent', 'student', 'view_only'));

DELETE FROM public.staff_salary_structures 
WHERE staff_id IN (SELECT id FROM public.profiles WHERE role IN ('parent', 'student', 'view_only'));

-- Step 3: Clean up duplicated other_deductions in staff_salary_payouts
UPDATE public.staff_salary_payouts
SET other_deductions = 0.0
WHERE other_deductions = insurance_deduction
   OR (other_deductions_remarks IS NULL OR other_deductions_remarks = '');

-- Step 4: Ensure medical_allowance and insurance_deduction are populated from structures
UPDATE public.staff_salary_payouts p
SET 
    medical_allowance = COALESCE(NULLIF(p.medical_allowance, 0.0), s.medical_allowance, 0.0),
    insurance_deduction = COALESCE(NULLIF(p.insurance_deduction, 0.0), s.insurance_deduction, 0.0)
FROM public.staff_salary_structures s
WHERE p.staff_id = s.staff_id AND p.school_id = s.school_id;

-- Step 5: Recalculate all staff_salary_payouts to exact mathematical truth
UPDATE public.staff_salary_payouts
SET 
    gross_earnings = (
        COALESCE(basic_pay, 0.0) + 
        COALESCE(hra, 0.0) + 
        COALESCE(da, 0.0) + 
        COALESCE(ta, 0.0) + 
        COALESCE(special_allowance, 0.0) + 
        COALESCE(medical_allowance, 0.0) + 
        COALESCE(bonus, 0.0)
    ),
    total_deductions = (
        COALESCE(pf_deduction, 0.0) + 
        COALESCE(tds, 0.0) + 
        COALESCE(professional_tax, 0.0) + 
        COALESCE(insurance_deduction, 0.0) + 
        COALESCE(advance_deduction, 0.0) + 
        COALESCE(other_deductions, 0.0)
    ),
    net_pay = (
        COALESCE(basic_pay, 0.0) + 
        COALESCE(hra, 0.0) + 
        COALESCE(da, 0.0) + 
        COALESCE(ta, 0.0) + 
        COALESCE(special_allowance, 0.0) + 
        COALESCE(medical_allowance, 0.0) + 
        COALESCE(bonus, 0.0)
    ) - (
        COALESCE(pf_deduction, 0.0) + 
        COALESCE(tds, 0.0) + 
        COALESCE(professional_tax, 0.0) + 
        COALESCE(insurance_deduction, 0.0) + 
        COALESCE(advance_deduction, 0.0) + 
        COALESCE(other_deductions, 0.0)
    );

-- Step 6: Recalculate all staff_salary_structures to exact mathematical truth
UPDATE public.staff_salary_structures
SET 
    gross_salary = (
        COALESCE(basic_pay, 0.0) + 
        COALESCE(hra, 0.0) + 
        COALESCE(da, 0.0) + 
        COALESCE(ta, 0.0) + 
        COALESCE(special_allowance, 0.0) + 
        COALESCE(medical_allowance, 0.0)
    ),
    total_deductions = (
        COALESCE(pf_deduction, 0.0) + 
        COALESCE(tds, 0.0) + 
        COALESCE(professional_tax, 0.0) + 
        COALESCE(insurance_deduction, 0.0)
    ),
    net_salary = (
        COALESCE(basic_pay, 0.0) + 
        COALESCE(hra, 0.0) + 
        COALESCE(da, 0.0) + 
        COALESCE(ta, 0.0) + 
        COALESCE(special_allowance, 0.0) + 
        COALESCE(medical_allowance, 0.0)
    ) - (
        COALESCE(pf_deduction, 0.0) + 
        COALESCE(tds, 0.0) + 
        COALESCE(professional_tax, 0.0) + 
        COALESCE(insurance_deduction, 0.0)
    );

-- Step 7: Update fn_staff_payslips_master with medical_allowance, insurance_deduction, and authentic designation
CREATE OR REPLACE FUNCTION public.fn_staff_payslips_master(
    p_school_id uuid,
    p_month_str text DEFAULT '2026-10'::text,
    p_department text DEFAULT NULL::text,
    p_search text DEFAULT NULL::text,
    p_sort_by text DEFAULT 'payslip_number'::text,
    p_sort_order text DEFAULT 'DESC'::text,
    p_page integer DEFAULT 1,
    p_page_size integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_total_items INT := 0;
    v_total_pages INT := 1;
    v_offset INT := 0;
    v_payslips JSONB := '[]'::jsonb;
    v_clean_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_clean_size INT := GREATEST(1, LEAST(100, COALESCE(p_page_size, 10)));
BEGIN
    v_offset := (v_clean_page - 1) * v_clean_size;

    WITH ps_raw AS (
        SELECT 
            payout.id,
            payout.payslip_number,
            payout.staff_id,
            p.full_name AS staff_name,
            COALESCE(p.employee_id, 'EMP-' || SUBSTRING(p.id::text, 1, 6)) AS employee_id,
            COALESCE(p.department, 'Academic & Teaching') AS department,
            COALESCE(p.role, 'Teacher') AS role_title,
            COALESCE(p.designation, 'Faculty Member') AS designation,
            COALESCE(p.email, '') AS email,
            COALESCE(p.phone, '') AS phone,
            payout.month,
            payout.year,
            payout.month_str,
            payout.basic_pay,
            payout.hra,
            payout.da,
            payout.ta,
            payout.special_allowance,
            COALESCE(payout.medical_allowance, 0.0) AS medical_allowance,
            payout.bonus,
            (COALESCE(payout.basic_pay,0) + COALESCE(payout.hra,0) + COALESCE(payout.da,0) + 
             COALESCE(payout.ta,0) + COALESCE(payout.special_allowance,0) + 
             COALESCE(payout.medical_allowance,0) + COALESCE(payout.bonus,0)) AS gross_earnings,
            payout.pf_deduction,
            payout.tds,
            payout.professional_tax,
            COALESCE(payout.insurance_deduction, 0.0) AS insurance_deduction,
            COALESCE(payout.advance_deduction, 0.0) AS advance_deduction,
            COALESCE(payout.other_deductions, 0.0) AS other_deductions,
            (COALESCE(payout.pf_deduction,0) + COALESCE(payout.tds,0) + COALESCE(payout.professional_tax,0) + 
             COALESCE(payout.insurance_deduction,0) + COALESCE(payout.advance_deduction,0) + 
             COALESCE(payout.other_deductions,0)) AS total_deductions,
            ((COALESCE(payout.basic_pay,0) + COALESCE(payout.hra,0) + COALESCE(payout.da,0) + 
              COALESCE(payout.ta,0) + COALESCE(payout.special_allowance,0) + 
              COALESCE(payout.medical_allowance,0) + COALESCE(payout.bonus,0)) -
             (COALESCE(payout.pf_deduction,0) + COALESCE(payout.tds,0) + COALESCE(payout.professional_tax,0) + 
              COALESCE(payout.insurance_deduction,0) + COALESCE(payout.advance_deduction,0) + 
              COALESCE(payout.other_deductions,0))) AS net_pay,
            payout.payment_status,
            payout.payment_date,
            payout.payment_mode,
            payout.transaction_reference,
            COALESCE(struct.bank_name, p.bank_name, 'HDFC Bank') AS bank_name,
            COALESCE(struct.account_number, p.account_number, '') AS account_number,
            COALESCE(struct.ifsc_code, p.ifsc_code, '') AS ifsc_code,
            COALESCE(struct.pan_number, p.pan_number, '') AS pan_number
        FROM public.staff_salary_payouts payout
        INNER JOIN public.profiles p ON payout.staff_id = p.id AND payout.school_id = p.school_id
        LEFT JOIN public.staff_salary_structures struct ON payout.staff_id = struct.staff_id AND payout.school_id = struct.school_id
        WHERE payout.school_id = p_school_id 
          AND payout.month_str = p_month_str
          AND p.role NOT IN ('student', 'parent', 'view_only')
          AND (p_department IS NULL OR p_department IN ('All Departments', 'All', '') OR p.department = p_department)
          AND (p_search IS NULL OR p_search = '' OR (
              p.full_name ILIKE '%' || p_search || '%' OR
              COALESCE(p.employee_id, '') ILIKE '%' || p_search || '%' OR
              payout.payslip_number ILIKE '%' || p_search || '%'
          ))
    ),
    counted AS (
        SELECT COUNT(*) AS total_items FROM ps_raw
    ),
    sorted_page AS (
        SELECT * FROM ps_raw
        ORDER BY
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'payslip_number' THEN payslip_number END ASC,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'payslip_number' THEN payslip_number END DESC,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'name' THEN staff_name END ASC,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'name' THEN staff_name END DESC,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'gross' THEN gross_earnings END ASC,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'gross' THEN gross_earnings END DESC,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'net' THEN net_pay END ASC,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'net' THEN net_pay END DESC,
            payslip_number DESC
        LIMIT v_clean_size OFFSET v_offset
    )
    SELECT 
        (SELECT total_items FROM counted),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', sp.id,
                    'payslip_number', sp.payslip_number,
                    'staff_id', sp.staff_id,
                    'staff_name', sp.staff_name,
                    'employee_id', sp.employee_id,
                    'department', sp.department,
                    'role', sp.role_title,
                    'designation', sp.designation,
                    'email', sp.email,
                    'phone', sp.phone,
                    'month', sp.month,
                    'year', sp.year,
                    'month_str', sp.month_str,
                    'basic_pay', sp.basic_pay,
                    'hra', sp.hra,
                    'da', sp.da,
                    'ta', sp.ta,
                    'special_allowance', sp.special_allowance,
                    'medical_allowance', sp.medical_allowance,
                    'bonus', sp.bonus,
                    'gross_earnings', sp.gross_earnings,
                    'pf_deduction', sp.pf_deduction,
                    'tds', sp.tds,
                    'professional_tax', sp.professional_tax,
                    'insurance_deduction', sp.insurance_deduction,
                    'advance_deduction', sp.advance_deduction,
                    'other_deductions', sp.other_deductions,
                    'total_deductions', sp.total_deductions,
                    'net_pay', sp.net_pay,
                    'gross_formatted', '₹ ' || TO_CHAR(sp.gross_earnings, 'FM99,99,990.00'),
                    'total_deductions_formatted', '₹ ' || TO_CHAR(sp.total_deductions, 'FM99,99,990.00'),
                    'net_formatted', '₹ ' || TO_CHAR(sp.net_pay, 'FM99,99,990.00'),
                    'payment_status', sp.payment_status,
                    'payment_date', sp.payment_date,
                    'payment_mode', sp.payment_mode,
                    'transaction_reference', sp.transaction_reference,
                    'bank_name', sp.bank_name,
                    'account_number', sp.account_number,
                    'ifsc_code', sp.ifsc_code,
                    'pan_number', sp.pan_number
                )
            ),
            '[]'::jsonb
        )
    INTO v_total_items, v_payslips
    FROM sorted_page sp;

    v_total_pages := GREATEST(1, CEIL(v_total_items::NUMERIC / v_clean_size)::INT);

    RETURN jsonb_build_object(
        'success', true,
        'page', v_clean_page,
        'page_size', v_clean_size,
        'total_items', v_total_items,
        'total_pages', v_total_pages,
        'payslips', v_payslips
    );
END;
$function$;

-- Step 8: Update fn_staff_salary_roster with medical_allowance, insurance_deduction, and authentic designation
CREATE OR REPLACE FUNCTION public.fn_staff_salary_roster(
    p_school_id uuid,
    p_month_str text DEFAULT '2026-10'::text,
    p_department text DEFAULT NULL::text,
    p_role text DEFAULT NULL::text,
    p_status text DEFAULT NULL::text,
    p_search text DEFAULT NULL::text,
    p_sort_by text DEFAULT 'name'::text,
    p_sort_order text DEFAULT 'ASC'::text,
    p_page integer DEFAULT 1,
    p_page_size integer DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_total_items INT := 0;
    v_total_pages INT := 1;
    v_offset INT := 0;
    v_staff JSONB := '[]'::jsonb;
    v_clean_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_clean_size INT := GREATEST(1, LEAST(100, COALESCE(p_page_size, 10)));
BEGIN
    v_offset := (v_clean_page - 1) * v_clean_size;

    WITH staff_raw AS (
        SELECT 
            p.id AS staff_id,
            p.full_name AS staff_name,
            COALESCE(p.email, '') AS staff_email,
            COALESCE(p.phone, '') AS staff_phone,
            COALESCE(NULLIF(p.department, ''), 'Academic & Teaching') AS department,
            COALESCE(NULLIF(p.role, ''), 'Teacher') AS role_title,
            COALESCE(p.designation, 'Faculty Member') AS designation,
            COALESCE(p.employee_id, 'EMP-' || SUBSTRING(p.id::text, 1, 6)) AS employee_id,
            p.avatar_url,
            COALESCE(payout.basic_pay, struct.basic_pay, 35000.0) AS basic_pay,
            COALESCE(payout.hra, struct.hra, 14000.0) AS hra,
            COALESCE(payout.da, struct.da, 4500.0) AS da,
            COALESCE(payout.ta, struct.ta, 2500.0) AS ta,
            COALESCE(payout.special_allowance, struct.special_allowance, 2000.0) AS special_allowance,
            COALESCE(payout.medical_allowance, struct.medical_allowance, 0.0) AS medical_allowance,
            COALESCE(payout.bonus, 0.0) AS bonus,
            (COALESCE(payout.basic_pay, struct.basic_pay, 35000.0) +
             COALESCE(payout.hra, struct.hra, 14000.0) +
             COALESCE(payout.da, struct.da, 4500.0) +
             COALESCE(payout.ta, struct.ta, 2500.0) +
             COALESCE(payout.special_allowance, struct.special_allowance, 2000.0) +
             COALESCE(payout.medical_allowance, struct.medical_allowance, 0.0) +
             COALESCE(payout.bonus, 0.0)) AS gross_salary,
            COALESCE(payout.pf_deduction, struct.pf_deduction, 1800.0) AS pf_deduction,
            COALESCE(payout.tds, struct.tds, 2500.0) AS tds,
            COALESCE(payout.professional_tax, struct.professional_tax, 200.0) AS professional_tax,
            COALESCE(payout.insurance_deduction, struct.insurance_deduction, 0.0) AS insurance_deduction,
            COALESCE(payout.advance_deduction, 0.0) AS advance_deduction,
            COALESCE(payout.other_deductions, 0.0) AS other_deductions,
            (COALESCE(payout.pf_deduction, struct.pf_deduction, 1800.0) +
             COALESCE(payout.tds, struct.tds, 2500.0) +
             COALESCE(payout.professional_tax, struct.professional_tax, 200.0) +
             COALESCE(payout.insurance_deduction, struct.insurance_deduction, 0.0) +
             COALESCE(payout.advance_deduction, 0.0) +
             COALESCE(payout.other_deductions, 0.0)) AS total_deductions,
            ((COALESCE(payout.basic_pay, struct.basic_pay, 35000.0) +
              COALESCE(payout.hra, struct.hra, 14000.0) +
              COALESCE(payout.da, struct.da, 4500.0) +
              COALESCE(payout.ta, struct.ta, 2500.0) +
              COALESCE(payout.special_allowance, struct.special_allowance, 2000.0) +
              COALESCE(payout.medical_allowance, struct.medical_allowance, 0.0) +
              COALESCE(payout.bonus, 0.0)) -
             (COALESCE(payout.pf_deduction, struct.pf_deduction, 1800.0) +
              COALESCE(payout.tds, struct.tds, 2500.0) +
              COALESCE(payout.professional_tax, struct.professional_tax, 200.0) +
              COALESCE(payout.insurance_deduction, struct.insurance_deduction, 0.0) +
              COALESCE(payout.advance_deduction, 0.0) +
              COALESCE(payout.other_deductions, 0.0))) AS net_salary,
            COALESCE(payout.bank_name, struct.bank_name, p.bank_name, 'HDFC Bank') AS bank_name,
            COALESCE(payout.account_number, struct.account_number, p.account_number, '') AS account_number,
            COALESCE(payout.ifsc_code, struct.ifsc_code, p.ifsc_code, '') AS ifsc_code,
            COALESCE(payout.pan_number, struct.pan_number, p.pan_number, '') AS pan_number,
            COALESCE(payout.payment_mode, struct.payment_mode, 'Direct Bank Transfer (NEFT/RTGS)') AS payment_mode,
            COALESCE(payout.payment_status, 'Pending') AS payout_status,
            payout.id AS payout_id,
            payout.payslip_number,
            payout.payment_date,
            payout.transaction_reference,
            COALESCE((
                SELECT SUM(adv.monthly_deduction)
                FROM public.staff_salary_advances adv
                WHERE adv.staff_id = p.id AND adv.school_id = p.school_id 
                  AND adv.status = 'Approved' AND adv.amount_repaid < adv.amount
            ), 0.0) AS active_advance_deduction
        FROM public.profiles p
        LEFT JOIN public.staff_salary_structures struct 
            ON p.id = struct.staff_id AND p.school_id = struct.school_id
        LEFT JOIN public.staff_salary_payouts payout 
            ON p.id = payout.staff_id AND p.school_id = payout.school_id AND payout.month_str = p_month_str
        WHERE p.school_id = p_school_id 
          AND p.role NOT IN ('student', 'parent', 'view_only')
          AND (p_search IS NULL OR p_search = '' OR (
              p.full_name ILIKE '%' || p_search || '%' OR
              p.email ILIKE '%' || p_search || '%' OR
              COALESCE(p.employee_id, '') ILIKE '%' || p_search || '%' OR
              COALESCE(p.designation, '') ILIKE '%' || p_search || '%' OR
              COALESCE(p.department, '') ILIKE '%' || p_search || '%'
          ))
          AND (p_department IS NULL OR p_department IN ('All Departments', 'All', '') OR p.department = p_department)
          AND (p_role IS NULL OR p_role IN ('All Roles', 'All', '') OR p.role = p_role)
    ),
    filtered AS (
        SELECT * FROM staff_raw
        WHERE (
            p_status IS NULL OR p_status IN ('All Status', 'All', 'All Staff', '')
            OR (LOWER(p_status) = 'paid' AND payout_status = 'Paid')
            OR (LOWER(p_status) = 'pending' AND payout_status IN ('Pending', 'Approved'))
            OR (LOWER(p_status) IN ('on-hold', 'on hold', 'review', 'on-hold / review') AND payout_status IN ('On-Hold', 'On Hold', 'Review', 'Rejected'))
            OR (payout_status ILIKE p_status)
        )
    ),
    counted AS (
        SELECT COUNT(*) AS total_items FROM filtered
    ),
    sorted_page AS (
        SELECT * FROM filtered
        ORDER BY
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'name' THEN staff_name END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'name' THEN staff_name END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'gross' THEN gross_salary END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'gross' THEN gross_salary END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'deductions' THEN total_deductions END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'deductions' THEN total_deductions END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) IN ('net', 'net_salary') THEN net_salary END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) IN ('net', 'net_salary') THEN net_salary END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'status' THEN payout_status END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'status' THEN payout_status END DESC NULLS LAST,
            staff_name ASC
        LIMIT v_clean_size OFFSET v_offset
    )
    SELECT 
        (SELECT total_items FROM counted),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'staff_id', sp.staff_id,
                    'staff_name', sp.staff_name,
                    'staff_email', sp.staff_email,
                    'staff_phone', sp.staff_phone,
                    'department', sp.department,
                    'role', sp.role_title,
                    'role_title', sp.role_title,
                    'designation', sp.designation,
                    'employee_id', sp.employee_id,
                    'avatar_url', sp.avatar_url,
                    'basic_pay', sp.basic_pay,
                    'hra', sp.hra,
                    'da', sp.da,
                    'ta', sp.ta,
                    'special_allowance', sp.special_allowance,
                    'medical_allowance', sp.medical_allowance,
                    'bonus', sp.bonus,
                    'gross_salary', sp.gross_salary,
                    'pf_deduction', sp.pf_deduction,
                    'tds', sp.tds,
                    'professional_tax', sp.professional_tax,
                    'insurance_deduction', sp.insurance_deduction,
                    'advance_deduction', sp.advance_deduction,
                    'other_deductions', sp.other_deductions,
                    'total_deductions', sp.total_deductions,
                    'net_salary', sp.net_salary,
                    'actual_net_pay', sp.net_salary,
                    'gross_salary_formatted', '₹ ' || TO_CHAR(sp.gross_salary, 'FM99,99,990.00'),
                    'total_deductions_formatted', '₹ ' || TO_CHAR(sp.total_deductions, 'FM99,99,990.00'),
                    'net_salary_formatted', '₹ ' || TO_CHAR(sp.net_salary, 'FM99,99,990.00'),
                    'bank_name', sp.bank_name,
                    'account_number', sp.account_number,
                    'ifsc_code', sp.ifsc_code,
                    'pan_number', sp.pan_number,
                    'payment_mode', sp.payment_mode,
                    'status', sp.payout_status,
                    'payout_id', sp.payout_id,
                    'payslip_number', sp.payslip_number,
                    'payment_date', sp.payment_date,
                    'transaction_reference', sp.transaction_reference,
                    'active_advance_deduction', sp.active_advance_deduction
                )
            ),
            '[]'::jsonb
        )
    INTO v_total_items, v_staff
    FROM sorted_page sp;

    v_total_pages := GREATEST(1, CEIL(v_total_items::NUMERIC / v_clean_size)::INT);

    RETURN jsonb_build_object(
        'success', true,
        'page', v_clean_page,
        'page_size', v_clean_size,
        'total_items', v_total_items,
        'total_pages', v_total_pages,
        'staff', v_staff
    );
END;
$function$;

-- Step 9: Update fn_staff_salary_account_details (360 Drawer)
CREATE OR REPLACE FUNCTION public.fn_staff_salary_account_details(
    p_school_id uuid,
    p_staff_id uuid,
    p_month_str text DEFAULT '2026-10'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_profile RECORD;
    v_struct RECORD;
    v_payout RECORD;
    v_payouts JSONB;
    v_advances JSONB;
BEGIN
    SELECT id, full_name, email, phone, department, role, designation, employee_id, avatar_url
    INTO v_profile
    FROM public.profiles
    WHERE id = p_staff_id AND school_id = p_school_id;

    IF v_profile.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Staff member not found');
    END IF;

    SELECT * INTO v_struct
    FROM public.staff_salary_structures
    WHERE staff_id = p_staff_id AND school_id = p_school_id;

    SELECT * INTO v_payout
    FROM public.staff_salary_payouts
    WHERE staff_id = p_staff_id AND school_id = p_school_id AND month_str = p_month_str;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', p.id,
                'month_str', p.month_str,
                'payslip_number', p.payslip_number,
                'basic_pay', p.basic_pay,
                'hra', p.hra,
                'da', p.da,
                'ta', p.ta,
                'special_allowance', p.special_allowance,
                'medical_allowance', COALESCE(p.medical_allowance, 0.0),
                'gross_earnings', p.gross_earnings,
                'pf_deduction', p.pf_deduction,
                'tds', p.tds,
                'professional_tax', p.professional_tax,
                'insurance_deduction', COALESCE(p.insurance_deduction, 0.0),
                'advance_deduction', p.advance_deduction,
                'other_deductions', p.other_deductions,
                'total_deductions', p.total_deductions,
                'net_pay', p.net_pay,
                'payment_status', p.payment_status,
                'payment_date', p.payment_date,
                'payment_mode', p.payment_mode,
                'transaction_reference', p.transaction_reference
            ) ORDER BY p.year DESC, p.month DESC
        ), '[]'::jsonb
    ) INTO v_payouts
    FROM public.staff_salary_payouts p
    WHERE p.staff_id = p_staff_id AND p.school_id = p_school_id;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', a.id,
                'amount', a.amount,
                'amount_repaid', a.amount_repaid,
                'outstanding_balance', GREATEST(0.0, a.amount - COALESCE(a.amount_repaid, 0.0)),
                'repayment_months', a.repayment_months,
                'monthly_deduction', a.monthly_deduction,
                'purpose_type', a.purpose_type,
                'reason', a.reason,
                'status', a.status,
                'disbursed_at', a.disbursed_at
            ) ORDER BY a.created_at DESC
        ), '[]'::jsonb
    ) INTO v_advances
    FROM public.staff_salary_advances a
    WHERE a.staff_id = p_staff_id AND a.school_id = p_school_id;

    RETURN jsonb_build_object(
        'success', true,
        'profile', jsonb_build_object(
            'id', v_profile.id,
            'name', v_profile.full_name,
            'email', v_profile.email,
            'phone', v_profile.phone,
            'department', COALESCE(v_profile.department, 'Academic & Teaching'),
            'role_title', COALESCE(v_profile.role, 'Teacher'),
            'designation', COALESCE(v_profile.designation, 'Faculty Member'),
            'employee_id', COALESCE(v_profile.employee_id, 'EMP-' || SUBSTRING(v_profile.id::text, 1, 6)),
            'avatar_url', v_profile.avatar_url
        ),
        'structure', jsonb_build_object(
            'basic_pay', COALESCE(v_struct.basic_pay, 35000.0),
            'hra', COALESCE(v_struct.hra, 14000.0),
            'da', COALESCE(v_struct.da, 4500.0),
            'ta', COALESCE(v_struct.ta, 2500.0),
            'special_allowance', COALESCE(v_struct.special_allowance, 2000.0),
            'medical_allowance', COALESCE(v_struct.medical_allowance, 0.0),
            'gross_salary', COALESCE(v_struct.gross_salary, 58000.0),
            'pf_deduction', COALESCE(v_struct.pf_deduction, 1800.0),
            'tds', COALESCE(v_struct.tds, 2500.0),
            'professional_tax', COALESCE(v_struct.professional_tax, 200.0),
            'insurance_deduction', COALESCE(v_struct.insurance_deduction, 0.0),
            'total_deductions', COALESCE(v_struct.total_deductions, 5000.0),
            'net_salary', COALESCE(v_struct.net_salary, 53000.0),
            'bank_name', COALESCE(v_struct.bank_name, 'HDFC Bank'),
            'account_number', COALESCE(v_struct.account_number, ''),
            'ifsc_code', COALESCE(v_struct.ifsc_code, ''),
            'pan_number', COALESCE(v_struct.pan_number, ''),
            'payment_mode', COALESCE(v_struct.payment_mode, 'Direct Bank Transfer (NEFT/RTGS)')
        ),
        'current_payout', jsonb_build_object(
            'status', COALESCE(v_payout.payment_status, 'Pending'),
            'payslip_number', v_payout.payslip_number,
            'payment_date', v_payout.payment_date,
            'transaction_reference', v_payout.transaction_reference,
            'net_pay', COALESCE(v_payout.net_pay, v_struct.net_salary, 53000.0),
            'gross_earnings', COALESCE(v_payout.gross_earnings, v_struct.gross_salary, 58000.0),
            'total_deductions', COALESCE(v_payout.total_deductions, v_struct.total_deductions, 5000.0),
            'medical_allowance', COALESCE(v_payout.medical_allowance, v_struct.medical_allowance, 0.0),
            'insurance_deduction', COALESCE(v_payout.insurance_deduction, v_struct.insurance_deduction, 0.0)
        ),
        'payout_history', v_payouts,
        'advances', v_advances
    );
END;
$function$;

-- Step 10: Update fn_staff_salary_dashboard_kpis
CREATE OR REPLACE FUNCTION public.fn_staff_salary_dashboard_kpis(
    p_school_id uuid,
    p_month_str text DEFAULT '2026-10'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_total_staff INT := 0;
    v_total_budget NUMERIC(14,2) := 0.0;
    v_total_disbursed NUMERIC(14,2) := 0.0;
    v_pending_disbursal NUMERIC(14,2) := 0.0;
    v_on_hold NUMERIC(14,2) := 0.0;
    v_disbursed_count INT := 0;
    v_pending_count INT := 0;
    v_on_hold_count INT := 0;
    v_disbursal_rate NUMERIC(5,1) := 0.0;
BEGIN
    -- Strict institutional staff count (no parents, no students)
    SELECT COUNT(*) INTO v_total_staff
    FROM public.profiles
    WHERE school_id = p_school_id 
      AND role NOT IN ('student', 'parent', 'view_only');

    -- Total monthly budget from all active structures
    SELECT COALESCE(SUM(struct.gross_salary), 0.0) INTO v_total_budget
    FROM public.profiles p
    JOIN public.staff_salary_structures struct ON p.id = struct.staff_id AND p.school_id = struct.school_id
    WHERE p.school_id = p_school_id 
      AND p.role NOT IN ('student', 'parent', 'view_only');

    -- Payout metrics for target month
    SELECT 
        COALESCE(SUM(CASE WHEN p.payment_status = 'Paid' THEN p.net_pay ELSE 0.0 END), 0.0),
        COALESCE(SUM(CASE WHEN p.payment_status IN ('Pending', 'Approved') THEN p.net_pay ELSE 0.0 END), 0.0),
        COALESCE(SUM(CASE WHEN p.payment_status IN ('On-Hold', 'On Hold', 'Review', 'Rejected') THEN p.net_pay ELSE 0.0 END), 0.0),
        COUNT(CASE WHEN p.payment_status = 'Paid' THEN 1 END),
        COUNT(CASE WHEN p.payment_status IN ('Pending', 'Approved') THEN 1 END),
        COUNT(CASE WHEN p.payment_status IN ('On-Hold', 'On Hold', 'Review', 'Rejected') THEN 1 END)
    INTO 
        v_total_disbursed,
        v_pending_disbursal,
        v_on_hold,
        v_disbursed_count,
        v_pending_count,
        v_on_hold_count
    FROM public.staff_salary_payouts p
    JOIN public.profiles pr ON pr.id = p.staff_id AND pr.school_id = p.school_id
    WHERE p.school_id = p_school_id 
      AND p.month_str = p_month_str
      AND pr.role NOT IN ('student', 'parent', 'view_only');

    IF v_total_budget > 0 THEN
        v_disbursal_rate := ROUND((v_total_disbursed / v_total_budget * 100)::numeric, 1);
    ELSE
        v_disbursal_rate := 0.0;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'kpis', jsonb_build_object(
            'total_monthly_budget', v_total_budget,
            'total_disbursed', v_total_disbursed,
            'pending_disbursal', v_pending_disbursal,
            'on_hold_amount', v_on_hold,
            'disbursal_rate', v_disbursal_rate,
            'disbursal_rate_formatted', v_disbursal_rate || '% Disbursed',
            'total_staff', v_total_staff,
            'paid_staff_count', v_disbursed_count,
            'pending_staff_count', v_pending_count,
            'on_hold_staff_count', v_on_hold_count
        )
    );
END;
$function$;

-- Step 11: Create fn_update_staff_payout_status overload matching payments_management.py
CREATE OR REPLACE FUNCTION public.fn_update_staff_payout_status(
    p_school_id uuid,
    p_staff_id uuid,
    p_month_str text,
    p_status text,
    p_payment_mode text DEFAULT NULL::text,
    p_transaction_reference text DEFAULT NULL::text,
    p_comments text DEFAULT NULL::text,
    p_approver_name text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_clean_status TEXT := TRIM(p_status);
    v_count INT := 0;
BEGIN
    UPDATE public.staff_salary_payouts
    SET payment_status = v_clean_status,
        payment_mode = COALESCE(NULLIF(p_payment_mode, ''), payment_mode),
        transaction_reference = COALESCE(NULLIF(p_transaction_reference, ''), transaction_reference),
        remarks = COALESCE(NULLIF(p_comments, ''), remarks),
        payment_date = CASE WHEN v_clean_status = 'Paid' THEN NOW() ELSE payment_date END,
        updated_at = NOW()
    WHERE school_id = p_school_id 
      AND staff_id = p_staff_id 
      AND month_str = p_month_str;

    GET DIAGNOSTICS v_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'count', v_count,
        'status', v_clean_status,
        'message', 'Salary payout status successfully updated to ' || v_clean_status
    );
END;
$function$;

-- Step 12: Drop outdated and existing overloads of fn_process_staff_salary_payout
DROP FUNCTION IF EXISTS public.fn_process_staff_salary_payout(uuid, uuid, text, text, text, text, uuid);
DROP FUNCTION IF EXISTS public.fn_process_staff_salary_payout(uuid, uuid, integer, integer, text, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, text, text, text, text, uuid);
DROP FUNCTION IF EXISTS public.fn_process_staff_salary_payout(uuid, uuid, integer, integer, text, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, text, text, text, text, uuid, text, text, text, boolean);
DROP FUNCTION IF EXISTS public.fn_process_staff_salary_payout(uuid, uuid, integer, integer, text, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric, text, text, text, text, uuid, text, text, text, boolean, numeric, numeric);

-- Step 13: Recreate canonical 27-parameter fn_process_staff_salary_payout
CREATE OR REPLACE FUNCTION public.fn_process_staff_salary_payout(
    p_school_id uuid,
    p_staff_id uuid,
    p_month integer,
    p_year integer,
    p_month_str text,
    p_basic_pay numeric,
    p_hra numeric,
    p_da numeric,
    p_ta numeric,
    p_special_allowance numeric,
    p_bonus numeric,
    p_pf_deduction numeric,
    p_tds numeric,
    p_professional_tax numeric,
    p_advance_deduction numeric,
    p_other_deductions numeric,
    p_payment_status text,
    p_payment_mode text,
    p_transaction_reference text,
    p_remarks text,
    p_user_id uuid,
    p_bonus_type text DEFAULT 'NONE'::text,
    p_bonus_remarks text DEFAULT NULL::text,
    p_other_deductions_remarks text DEFAULT NULL::text,
    p_update_permanent_structure boolean DEFAULT false,
    p_medical_allowance numeric DEFAULT 0.0,
    p_insurance_deduction numeric DEFAULT 0.0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_clean_month_str TEXT;
    v_clean_month INT;
    v_clean_year INT;
    v_clean_status TEXT;
    v_clean_mode TEXT;
    v_staff_name TEXT;
    v_emp_id TEXT;
    v_gross_earnings NUMERIC(12,2);
    v_total_deductions NUMERIC(12,2);
    v_net_pay NUMERIC(12,2);
    v_ps_num TEXT;
    v_txn_ref TEXT;
    v_payout_id UUID;
    v_adv_ded NUMERIC(12,2) := COALESCE(p_advance_deduction, 0.0);
    v_alloc NUMERIC(12,2);
    v_adv RECORD;
    v_repaid_adv_count INT := 0;
    v_bank_name VARCHAR(150);
    v_account_number VARCHAR(100);
    v_ifsc_code VARCHAR(50);
    v_pan_number VARCHAR(50);
BEGIN
    SELECT full_name, COALESCE(employee_id, 'EMP-' || SUBSTRING(id::text, 1, 6))
    INTO v_staff_name, v_emp_id
    FROM public.profiles
    WHERE id = p_staff_id AND school_id = p_school_id;

    IF v_staff_name IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Staff profile not found for this institution'
        );
    END IF;

    SELECT bank_name, account_number, ifsc_code, pan_number
    INTO v_bank_name, v_account_number, v_ifsc_code, v_pan_number
    FROM public.staff_salary_structures
    WHERE staff_id = p_staff_id AND school_id = p_school_id;

    v_clean_month_str := COALESCE(NULLIF(TRIM(p_month_str), ''), TO_CHAR(NOW(), 'YYYY-MM'));
    IF p_month IS NOT NULL AND p_month BETWEEN 1 AND 12 THEN
        v_clean_month := p_month;
    ELSE
        BEGIN
            v_clean_month := SUBSTRING(v_clean_month_str FROM 6 FOR 2)::INT;
        EXCEPTION WHEN OTHERS THEN
            v_clean_month := EXTRACT(MONTH FROM NOW())::INT;
        END;
    END IF;

    IF p_year IS NOT NULL AND p_year >= 2020 THEN
        v_clean_year := p_year;
    ELSE
        BEGIN
            v_clean_year := SUBSTRING(v_clean_month_str FROM 1 FOR 4)::INT;
        EXCEPTION WHEN OTHERS THEN
            v_clean_year := EXTRACT(YEAR FROM NOW())::INT;
        END;
    END IF;

    v_clean_status := COALESCE(NULLIF(TRIM(p_payment_status), ''), 'Paid');
    v_clean_mode := COALESCE(NULLIF(TRIM(p_payment_mode), ''), 'Direct Bank Transfer (NEFT/RTGS)');

    -- Exact mathematical computation without duplicate other_deductions
    v_gross_earnings := COALESCE(p_basic_pay, 0.0) +
                        COALESCE(p_hra, 0.0) +
                        COALESCE(p_da, 0.0) +
                        COALESCE(p_ta, 0.0) +
                        COALESCE(p_special_allowance, 0.0) +
                        COALESCE(p_medical_allowance, 0.0) +
                        COALESCE(p_bonus, 0.0);

    v_total_deductions := COALESCE(p_pf_deduction, 0.0) +
                          COALESCE(p_tds, 0.0) +
                          COALESCE(p_professional_tax, 0.0) +
                          COALESCE(p_insurance_deduction, 0.0) +
                          COALESCE(p_advance_deduction, 0.0) +
                          COALESCE(p_other_deductions, 0.0);

    v_net_pay := GREATEST(0.0, v_gross_earnings - v_total_deductions);

    SELECT payslip_number INTO v_ps_num
    FROM public.staff_salary_payouts
    WHERE school_id = p_school_id AND staff_id = p_staff_id AND month_str = v_clean_month_str;

    IF v_ps_num IS NULL OR v_ps_num = '' THEN
        v_ps_num := 'PS-' || v_clean_month_str || '-' || v_emp_id;
    END IF;

    IF v_clean_status = 'Paid' THEN
        v_txn_ref := COALESCE(NULLIF(TRIM(p_transaction_reference), ''), 'UTR-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || SUBSTRING(gen_random_uuid()::text, 1, 8));
    ELSE
        v_txn_ref := p_transaction_reference;
    END IF;

    INSERT INTO public.staff_salary_payouts (
        school_id, staff_id, payslip_number, month, year, month_str,
        basic_pay, hra, da, ta, special_allowance, medical_allowance, bonus, gross_earnings,
        pf_deduction, tds, professional_tax, insurance_deduction, advance_deduction, other_deductions,
        total_deductions, net_pay, payment_status, payment_date, payment_mode,
        transaction_reference, remarks, processed_by,
        bank_name, account_number, ifsc_code, pan_number,
        bonus_type, bonus_remarks, other_deductions_remarks, updated_at
    ) VALUES (
        p_school_id, p_staff_id, v_ps_num, v_clean_month, v_clean_year, v_clean_month_str,
        COALESCE(p_basic_pay, 0.0), COALESCE(p_hra, 0.0), COALESCE(p_da, 0.0),
        COALESCE(p_ta, 0.0), COALESCE(p_special_allowance, 0.0), COALESCE(p_medical_allowance, 0.0), COALESCE(p_bonus, 0.0),
        v_gross_earnings,
        COALESCE(p_pf_deduction, 0.0), COALESCE(p_tds, 0.0), COALESCE(p_professional_tax, 200.0),
        COALESCE(p_insurance_deduction, 0.0), COALESCE(p_advance_deduction, 0.0), COALESCE(p_other_deductions, 0.0),
        v_total_deductions, v_net_pay, v_clean_status,
        CASE WHEN v_clean_status = 'Paid' THEN NOW() ELSE NULL END,
        v_clean_mode, v_txn_ref, p_remarks, p_user_id,
        COALESCE(v_bank_name, 'HDFC Bank'), v_account_number, v_ifsc_code, v_pan_number,
        p_bonus_type, p_bonus_remarks, p_other_deductions_remarks, NOW()
    )
    ON CONFLICT (school_id, staff_id, month_str) DO UPDATE SET
        basic_pay = EXCLUDED.basic_pay,
        hra = EXCLUDED.hra,
        da = EXCLUDED.da,
        ta = EXCLUDED.ta,
        special_allowance = EXCLUDED.special_allowance,
        medical_allowance = EXCLUDED.medical_allowance,
        bonus = EXCLUDED.bonus,
        gross_earnings = EXCLUDED.gross_earnings,
        pf_deduction = EXCLUDED.pf_deduction,
        tds = EXCLUDED.tds,
        professional_tax = EXCLUDED.professional_tax,
        insurance_deduction = EXCLUDED.insurance_deduction,
        advance_deduction = EXCLUDED.advance_deduction,
        other_deductions = EXCLUDED.other_deductions,
        total_deductions = EXCLUDED.total_deductions,
        net_pay = EXCLUDED.net_pay,
        payment_status = EXCLUDED.payment_status,
        payment_date = CASE WHEN EXCLUDED.payment_status = 'Paid' THEN NOW() ELSE staff_salary_payouts.payment_date END,
        payment_mode = EXCLUDED.payment_mode,
        transaction_reference = COALESCE(EXCLUDED.transaction_reference, staff_salary_payouts.transaction_reference),
        remarks = COALESCE(EXCLUDED.remarks, staff_salary_payouts.remarks),
        processed_by = COALESCE(EXCLUDED.processed_by, staff_salary_payouts.processed_by),
        bonus_type = EXCLUDED.bonus_type,
        bonus_remarks = EXCLUDED.bonus_remarks,
        other_deductions_remarks = EXCLUDED.other_deductions_remarks,
        updated_at = NOW()
    RETURNING id INTO v_payout_id;

    -- Advance repayments if Paid
    IF v_clean_status = 'Paid' AND v_adv_ded > 0 THEN
        FOR v_adv IN 
            SELECT id, amount, amount_repaid
            FROM public.staff_salary_advances
            WHERE school_id = p_school_id AND staff_id = p_staff_id 
              AND status = 'Approved' AND amount_repaid < amount
            ORDER BY created_at ASC
        LOOP
            IF v_adv_ded <= 0 THEN
                EXIT;
            END IF;

            v_alloc := LEAST(v_adv_ded, (v_adv.amount - v_adv.amount_repaid));
            IF v_alloc > 0 THEN
                UPDATE public.staff_salary_advances
                SET amount_repaid = amount_repaid + v_alloc,
                    status = CASE WHEN (amount_repaid + v_alloc) >= amount THEN 'Settled' ELSE status END,
                    updated_at = NOW()
                WHERE id = v_adv.id;

                v_adv_ded := v_adv_ded - v_alloc;
                v_repaid_adv_count := v_repaid_adv_count + 1;
            END IF;
        END LOOP;
    END IF;

    -- Update permanent structure if requested
    IF p_update_permanent_structure IS TRUE THEN
        INSERT INTO public.staff_salary_structures (
            school_id, staff_id, basic_pay, hra, da, ta, special_allowance, medical_allowance,
            gross_salary, pf_deduction, tds, professional_tax, insurance_deduction,
            total_deductions, net_salary, payment_mode, bank_name, account_number, ifsc_code, pan_number, updated_at
        ) VALUES (
            p_school_id, p_staff_id, p_basic_pay, p_hra, p_da, p_ta, p_special_allowance, p_medical_allowance,
            v_gross_earnings - COALESCE(p_bonus, 0.0),
            p_pf_deduction, p_tds, p_professional_tax, p_insurance_deduction,
            (COALESCE(p_pf_deduction,0) + COALESCE(p_tds,0) + COALESCE(p_professional_tax,0) + COALESCE(p_insurance_deduction,0)),
            (v_gross_earnings - COALESCE(p_bonus, 0.0)) - (COALESCE(p_pf_deduction,0) + COALESCE(p_tds,0) + COALESCE(p_professional_tax,0) + COALESCE(p_insurance_deduction,0)),
            v_clean_mode, v_bank_name, v_account_number, v_ifsc_code, v_pan_number, NOW()
        )
        ON CONFLICT (school_id, staff_id) DO UPDATE SET
            basic_pay = EXCLUDED.basic_pay,
            hra = EXCLUDED.hra,
            da = EXCLUDED.da,
            ta = EXCLUDED.ta,
            special_allowance = EXCLUDED.special_allowance,
            medical_allowance = EXCLUDED.medical_allowance,
            gross_salary = EXCLUDED.gross_salary,
            pf_deduction = EXCLUDED.pf_deduction,
            tds = EXCLUDED.tds,
            professional_tax = EXCLUDED.professional_tax,
            insurance_deduction = EXCLUDED.insurance_deduction,
            total_deductions = EXCLUDED.total_deductions,
            net_salary = EXCLUDED.net_salary,
            updated_at = NOW();
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Salary payout successfully saved with complete SSOT math',
        'payout_id', v_payout_id,
        'payslip_number', v_ps_num,
        'status', v_clean_status,
        'gross_earnings', v_gross_earnings,
        'total_deductions', v_total_deductions,
        'net_pay', v_net_pay,
        'advances_settled_count', v_repaid_adv_count
    );
END;
$function$;

-- Step 14: Recreate fn_bulk_staff_salary_action with medical_allowance, insurance_deduction, and zeroed other_deductions
CREATE OR REPLACE FUNCTION public.fn_bulk_staff_salary_action(
    p_school_id uuid,
    p_action text,
    p_staff_ids uuid[],
    p_month_str text DEFAULT '2026-10'::text,
    p_payment_mode text DEFAULT 'Direct Bank Transfer (NEFT/RTGS)'::text,
    p_notes text DEFAULT NULL::text,
    p_user_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_count INT := 0;
    v_sid UUID;
    v_idx INT := 1;
    v_ps_num TEXT;
    v_struct RECORD;
    v_gross NUMERIC(12,2);
    v_ded NUMERIC(12,2);
    v_net NUMERIC(12,2);
BEGIN
    IF p_action IN ('disburse_selected', 'disburse', 'pay') THEN
        FOREACH v_sid IN ARRAY p_staff_ids LOOP
            SELECT * INTO v_struct
            FROM public.staff_salary_structures
            WHERE staff_id = v_sid AND school_id = p_school_id;

            v_ps_num := 'PS-' || p_month_str || '-' || LPAD(v_idx::text, 4, '0');
            v_idx := v_idx + 1;

            v_gross := (COALESCE(v_struct.basic_pay, 45000.0) + COALESCE(v_struct.hra, 8000.0) + 
                        COALESCE(v_struct.da, 4500.0) + COALESCE(v_struct.ta, 2500.0) + 
                        COALESCE(v_struct.special_allowance, 2000.0) + COALESCE(v_struct.medical_allowance, 0.0));
            v_ded := (COALESCE(v_struct.pf_deduction, 1800.0) + COALESCE(v_struct.tds, 2500.0) + 
                      COALESCE(v_struct.professional_tax, 200.0) + COALESCE(v_struct.insurance_deduction, 0.0));
            v_net := v_gross - v_ded;

            INSERT INTO public.staff_salary_payouts (
                school_id, staff_id, payslip_number, month, year, month_str,
                basic_pay, hra, da, ta, special_allowance, medical_allowance, bonus, gross_earnings,
                pf_deduction, tds, professional_tax, insurance_deduction, advance_deduction, other_deductions,
                total_deductions, net_pay, payment_status, payment_date, payment_mode,
                transaction_reference, remarks, processed_by
            ) VALUES (
                p_school_id, v_sid, v_ps_num, 10, 2026, p_month_str,
                COALESCE(v_struct.basic_pay, 45000.0), COALESCE(v_struct.hra, 8000.0), 
                COALESCE(v_struct.da, 4500.0), COALESCE(v_struct.ta, 2500.0),
                COALESCE(v_struct.special_allowance, 2000.0), COALESCE(v_struct.medical_allowance, 0.0), 0.0, v_gross,
                COALESCE(v_struct.pf_deduction, 1800.0), COALESCE(v_struct.tds, 2500.0), 
                COALESCE(v_struct.professional_tax, 200.0), COALESCE(v_struct.insurance_deduction, 0.0), 0.0, 0.0,
                v_ded, v_net,
                'Paid', NOW(), p_payment_mode,
                'TXN-BULK-' || SUBSTRING(v_sid::text, 1, 8), COALESCE(p_notes, 'Batch payroll automated disbarment'), p_user_id
            )
            ON CONFLICT (school_id, staff_id, month_str) DO UPDATE SET
                payment_status = 'Paid',
                payment_date = NOW(),
                transaction_reference = EXCLUDED.transaction_reference,
                remarks = EXCLUDED.remarks,
                updated_at = NOW();

            v_count := v_count + 1;
        END LOOP;
        RETURN jsonb_build_object('success', true, 'count', v_count, 'message', 'Disbursed salary for ' || v_count || ' staff members');

    ELSIF p_action IN ('hold_selected', 'hold') THEN
        UPDATE public.staff_salary_payouts
        SET payment_status = 'On-Hold',
            remarks = COALESCE(p_notes, 'Marked on-hold during review'),
            updated_at = NOW()
        WHERE school_id = p_school_id 
          AND staff_id = ANY(p_staff_ids) 
          AND month_str = p_month_str;
        
        GET DIAGNOSTICS v_count = ROW_COUNT;
        RETURN jsonb_build_object('success', true, 'count', v_count, 'message', 'Placed salary on hold for ' || v_count || ' staff members');

    ELSIF p_action IN ('approve_selected', 'approve') THEN
        UPDATE public.staff_salary_payouts
        SET payment_status = 'Approved',
            remarks = COALESCE(p_notes, 'Approved by Finance Admin'),
            processed_by = p_user_id,
            updated_at = NOW()
        WHERE school_id = p_school_id 
          AND staff_id = ANY(p_staff_ids) 
          AND month_str = p_month_str;
        
        GET DIAGNOSTICS v_count = ROW_COUNT;
        RETURN jsonb_build_object('success', true, 'count', v_count, 'message', 'Approved payout for ' || v_count || ' staff members');
    END IF;

    RETURN jsonb_build_object('success', false, 'message', 'Unknown bulk action: ' || p_action);
END;
$function$;
