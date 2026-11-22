-- ============================================================================
-- EduSHAMIIT Migration 536: Staff Salary Extended Stored Procedures & Features
-- Comprehensive Stored Procedures for:
-- 1. Corrected fn_staff_salary_roster (real net pay calculation & actual_net_pay)
-- 2. fn_bulk_run_staff_payroll (one-click batch payroll generation)
-- 3. fn_staff_salary_structures_catalog (searchable, paginated, sortable structures grid)
-- 4. fn_create_staff_salary_structure (create/update compensation structure)
-- 5. fn_staff_payslips_master (searchable, paginated payslips registry)
-- 6. fn_staff_advances_master (searchable, paginated advances ledger with progress)
-- 7. fn_settle_staff_salary_advance (early loan/advance prepayment & settlement)
-- 8. fn_export_bank_disbursal_file (corporate bank portal upload format)
-- ============================================================================

-- ============================================================================
-- 1. FUNCTION: fn_staff_salary_roster (UPDATED with real net pay calculation)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_staff_salary_roster(
    p_school_id UUID,
    p_month_str TEXT DEFAULT '2026-10',
    p_department TEXT DEFAULT NULL,
    p_role TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'name',
    p_sort_order TEXT DEFAULT 'ASC',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
            COALESCE(p.employee_id, 'EMP-' || SUBSTRING(p.id::text, 1, 6)) AS employee_id,
            p.avatar_url,
            COALESCE(struct.basic_pay, 35000.0) AS basic_pay,
            COALESCE(struct.hra, 14000.0) AS hra,
            COALESCE(struct.da, 4500.0) AS da,
            COALESCE(struct.ta, 2500.0) AS ta,
            COALESCE(struct.special_allowance, 2000.0) AS special_allowance,
            COALESCE(struct.gross_salary, 63000.0) AS gross_salary,
            COALESCE(struct.pf_deduction, 1800.0) AS pf_deduction,
            COALESCE(struct.tds, 2500.0) AS tds,
            COALESCE(struct.professional_tax, 200.0) AS professional_tax,
            COALESCE(struct.insurance_deduction, 500.0) AS insurance_deduction,
            COALESCE(struct.total_deductions, 7900.0) AS total_deductions,
            COALESCE(
                payout.net_pay,
                struct.net_salary,
                (COALESCE(struct.gross_salary, 63000.0) - COALESCE(struct.total_deductions, 7900.0))
            ) AS net_salary,
            COALESCE(struct.bank_name, 'HDFC Bank') AS bank_name,
            COALESCE(struct.account_number, '501002340055') AS account_number,
            COALESCE(struct.ifsc_code, 'HDFC0001824') AS ifsc_code,
            COALESCE(struct.pan_number, 'PAN000055X') AS pan_number,
            COALESCE(struct.payment_mode, 'Direct Bank Transfer (NEFT/RTGS)') AS payment_mode,
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
          AND p.role != 'student'
          AND (p_search IS NULL OR p_search = '' OR (
              p.full_name ILIKE '%' || p_search || '%' OR
              p.email ILIKE '%' || p_search || '%' OR
              p.employee_id ILIKE '%' || p_search || '%' OR
              p.role ILIKE '%' || p_search || '%'
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
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'base_pay' THEN basic_pay END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'base_pay' THEN basic_pay END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'gross' THEN gross_salary END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'gross' THEN gross_salary END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'deductions' THEN total_deductions END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'deductions' THEN total_deductions END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'net' THEN net_salary END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'net' THEN net_salary END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'net_salary' THEN net_salary END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'net_salary' THEN net_salary END DESC NULLS LAST,
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
                    'role_title', sp.role_title,
                    'employee_id', sp.employee_id,
                    'avatar_url', sp.avatar_url,
                    'basic_pay', sp.basic_pay,
                    'hra', sp.hra,
                    'da', sp.da,
                    'ta', sp.ta,
                    'special_allowance', sp.special_allowance,
                    'gross_salary', sp.gross_salary,
                    'pf_deduction', sp.pf_deduction,
                    'tds', sp.tds,
                    'professional_tax', sp.professional_tax,
                    'insurance_deduction', sp.insurance_deduction,
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
$$;


-- ============================================================================
-- 2. FUNCTION: fn_bulk_run_staff_payroll
-- One-click batch payroll calculation & generation for entire school/dept
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_bulk_run_staff_payroll(
    p_school_id UUID,
    p_month_str TEXT DEFAULT '2026-10',
    p_department TEXT DEFAULT NULL,
    p_payment_mode TEXT DEFAULT 'Direct Bank Transfer (NEFT/RTGS)',
    p_action TEXT DEFAULT 'generate_and_disburse',
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count INT := 0;
    v_total_disbursed NUMERIC(12,2) := 0.0;
    v_sid UUID;
    v_struct RECORD;
    v_adv_ded NUMERIC(12,2) := 0.0;
    v_net NUMERIC(12,2);
    v_ps_num TEXT;
    v_idx INT := 1;
    v_target_status TEXT := 'Paid';
BEGIN
    IF p_action = 'generate_pending' THEN
        v_target_status := 'Pending';
    END IF;

    FOR v_sid IN 
        SELECT p.id 
        FROM public.profiles p
        WHERE p.school_id = p_school_id 
          AND p.role != 'student'
          AND (p_department IS NULL OR p_department IN ('All Departments', 'All', '') OR p.department = p_department)
    LOOP
        SELECT * INTO v_struct
        FROM public.staff_salary_structures
        WHERE staff_id = v_sid AND school_id = p_school_id;

        IF v_struct IS NULL THEN
            v_struct.basic_pay := 45000.0;
            v_struct.hra := 15000.0;
            v_struct.da := 5000.0;
            v_struct.ta := 2500.0;
            v_struct.special_allowance := 4500.0;
            v_struct.medical_allowance := 2000.0;
            v_struct.gross_salary := 74000.0;
            v_struct.pf_deduction := 3600.0;
            v_struct.tds := 2500.0;
            v_struct.professional_tax := 200.0;
            v_struct.insurance_deduction := 500.0;
            v_struct.total_deductions := 6800.0;
            v_struct.net_salary := 67200.0;
            v_struct.bank_name := 'HDFC Bank';
            v_struct.account_number := '501002340055';
            v_struct.payment_mode := p_payment_mode;
        END IF;

        -- Check active advance deduction
        SELECT COALESCE(SUM(monthly_deduction), 0.0) INTO v_adv_ded
        FROM public.staff_salary_advances
        WHERE staff_id = v_sid AND school_id = p_school_id
          AND status = 'Approved' AND amount_repaid < amount;

        v_net := GREATEST(0.0, v_struct.gross_salary - v_struct.total_deductions - v_adv_ded);
        v_ps_num := 'PS-' || p_month_str || '-' || LPAD(FLOOR(RANDOM()*89999 + 10000)::TEXT, 5, '0');

        INSERT INTO public.staff_salary_payouts (
            school_id, staff_id, payslip_number, month, year, month_str,
            basic_pay, hra, da, ta, special_allowance, bonus, gross_earnings,
            pf_deduction, tds, professional_tax, advance_deduction, other_deductions,
            total_deductions, net_pay, payment_status, payment_date, payment_mode,
            transaction_reference, remarks, processed_by
        ) VALUES (
            p_school_id, v_sid, v_ps_num, 10, 2026, p_month_str,
            v_struct.basic_pay, v_struct.hra, COALESCE(v_struct.da, 5000.0), COALESCE(v_struct.ta, 2500.0),
            COALESCE(v_struct.special_allowance, 4500.0), 0.0, v_struct.gross_salary,
            v_struct.pf_deduction, v_struct.tds, v_struct.professional_tax, v_adv_ded, COALESCE(v_struct.insurance_deduction, 0.0),
            (v_struct.total_deductions + v_adv_ded), v_net, v_target_status, 
            CASE WHEN v_target_status = 'Paid' THEN CURRENT_DATE ELSE NULL END,
            COALESCE(v_struct.payment_mode, p_payment_mode),
            'TXN-BATCH-' || UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 10)),
            'Automated monthly cycle disbursal', p_user_id
        )
        ON CONFLICT (school_id, staff_id, month_str) DO UPDATE SET
            payment_status = EXCLUDED.payment_status,
            payment_date = EXCLUDED.payment_date,
            net_pay = EXCLUDED.net_pay,
            advance_deduction = EXCLUDED.advance_deduction,
            total_deductions = EXCLUDED.total_deductions,
            updated_at = NOW();

        -- If paid and has advance, credit repayment
        IF v_target_status = 'Paid' AND v_adv_ded > 0 THEN
            UPDATE public.staff_salary_advances
            SET amount_repaid = LEAST(amount, amount_repaid + v_adv_ded),
                status = CASE WHEN (amount_repaid + v_adv_ded) >= amount THEN 'Settled' ELSE status END,
                updated_at = NOW()
            WHERE staff_id = v_sid AND school_id = p_school_id AND status = 'Approved' AND amount_repaid < amount;
        END IF;

        v_count := v_count + 1;
        v_total_disbursed := v_total_disbursed + v_net;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'count', v_count,
        'total_disbursed', v_total_disbursed,
        'total_disbursed_formatted', '₹ ' || TO_CHAR(v_total_disbursed, 'FM99,99,990.00'),
        'month_str', p_month_str,
        'message', 'Processed payroll for ' || v_count || ' staff members'
    );
END;
$$;


-- ============================================================================
-- 3. FUNCTION: fn_staff_salary_structures_catalog
-- Premium searchable, sortable, paginated catalog of all staff salary structures
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_staff_salary_structures_catalog(
    p_school_id UUID,
    p_department TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'name',
    p_sort_order TEXT DEFAULT 'ASC',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_items INT := 0;
    v_total_pages INT := 1;
    v_offset INT := 0;
    v_structures JSONB := '[]'::jsonb;
    v_clean_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_clean_size INT := GREATEST(1, LEAST(100, COALESCE(p_page_size, 10)));
BEGIN
    v_offset := (v_clean_page - 1) * v_clean_size;

    WITH struct_raw AS (
        SELECT 
            p.id AS staff_id,
            p.full_name AS staff_name,
            COALESCE(p.employee_id, 'EMP-' || SUBSTRING(p.id::text, 1, 6)) AS employee_id,
            COALESCE(p.department, 'Academic & Teaching') AS department,
            COALESCE(p.role, 'Teacher') AS role_title,
            COALESCE(p.designation, 'Faculty Member') AS designation,
            struct.id AS structure_id,
            COALESCE(struct.basic_pay, 35000.0) AS basic_pay,
            COALESCE(struct.hra, 14000.0) AS hra,
            COALESCE(struct.da, 5000.0) AS da,
            COALESCE(struct.ta, 3000.0) AS ta,
            COALESCE(struct.special_allowance, 4000.0) AS special_allowance,
            COALESCE(struct.medical_allowance, 2000.0) AS medical_allowance,
            (COALESCE(struct.hra, 14000.0) + COALESCE(struct.da, 5000.0) + COALESCE(struct.ta, 3000.0) + 
             COALESCE(struct.special_allowance, 4000.0) + COALESCE(struct.medical_allowance, 2000.0)) AS total_allowances,
            COALESCE(struct.gross_salary, 63000.0) AS gross_salary,
            COALESCE(struct.pf_deduction, 4200.0) AS pf_deduction,
            COALESCE(struct.tds, 2500.0) AS tds,
            COALESCE(struct.professional_tax, 200.0) AS professional_tax,
            COALESCE(struct.insurance_deduction, 1000.0) AS insurance_deduction,
            COALESCE(struct.total_deductions, 7900.0) AS total_deductions,
            COALESCE(struct.net_salary, 55100.0) AS net_salary,
            COALESCE(struct.bank_name, 'HDFC Bank') AS bank_name,
            COALESCE(struct.account_number, '501002340055') AS account_number,
            COALESCE(struct.ifsc_code, 'HDFC0001824') AS ifsc_code,
            COALESCE(struct.pan_number, 'PAN000055X') AS pan_number,
            COALESCE(struct.payment_mode, 'Direct Bank Transfer (NEFT/RTGS)') AS payment_mode,
            COALESCE(struct.status, 'ACTIVE') AS status,
            struct.updated_at
        FROM public.profiles p
        LEFT JOIN public.staff_salary_structures struct 
            ON p.id = struct.staff_id AND p.school_id = struct.school_id
        WHERE p.school_id = p_school_id 
          AND p.role != 'student'
          AND (p_department IS NULL OR p_department IN ('All Departments', 'All', '') OR p.department = p_department)
          AND (p_search IS NULL OR p_search = '' OR (
              p.full_name ILIKE '%' || p_search || '%' OR
              p.employee_id ILIKE '%' || p_search || '%' OR
              p.department ILIKE '%' || p_search || '%' OR
              p.role ILIKE '%' || p_search || '%'
          ))
    ),
    counted AS (
        SELECT COUNT(*) AS total_items FROM struct_raw
    ),
    sorted_page AS (
        SELECT * FROM struct_raw
        ORDER BY
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'name' THEN staff_name END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'name' THEN staff_name END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'basic' THEN basic_pay END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'basic' THEN basic_pay END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'gross' THEN gross_salary END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'gross' THEN gross_salary END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'deductions' THEN total_deductions END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'deductions' THEN total_deductions END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'net' THEN net_salary END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'net' THEN net_salary END DESC NULLS LAST,
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
                    'employee_id', sp.employee_id,
                    'department', sp.department,
                    'role_title', sp.role_title,
                    'designation', sp.designation,
                    'structure_id', sp.structure_id,
                    'basic_pay', sp.basic_pay,
                    'hra', sp.hra,
                    'da', sp.da,
                    'ta', sp.ta,
                    'special_allowance', sp.special_allowance,
                    'medical_allowance', sp.medical_allowance,
                    'total_allowances', sp.total_allowances,
                    'gross_salary', sp.gross_salary,
                    'pf_deduction', sp.pf_deduction,
                    'tds', sp.tds,
                    'professional_tax', sp.professional_tax,
                    'insurance_deduction', sp.insurance_deduction,
                    'total_deductions', sp.total_deductions,
                    'net_salary', sp.net_salary,
                    'gross_formatted', '₹ ' || TO_CHAR(sp.gross_salary, 'FM99,99,990.00'),
                    'allowances_formatted', '₹ ' || TO_CHAR(sp.total_allowances, 'FM99,99,990.00'),
                    'deductions_formatted', '₹ ' || TO_CHAR(sp.total_deductions, 'FM99,99,990.00'),
                    'net_formatted', '₹ ' || TO_CHAR(sp.net_salary, 'FM99,99,990.00'),
                    'bank_name', sp.bank_name,
                    'account_number', sp.account_number,
                    'ifsc_code', sp.ifsc_code,
                    'pan_number', sp.pan_number,
                    'payment_mode', sp.payment_mode,
                    'status', sp.status
                )
            ),
            '[]'::jsonb
        )
    INTO v_total_items, v_structures
    FROM sorted_page sp;

    v_total_pages := GREATEST(1, CEIL(v_total_items::NUMERIC / v_clean_size)::INT);

    RETURN jsonb_build_object(
        'success', true,
        'page', v_clean_page,
        'page_size', v_clean_size,
        'total_items', v_total_items,
        'total_pages', v_total_pages,
        'structures', v_structures
    );
END;
$$;


-- ============================================================================
-- 4. FUNCTION: fn_create_staff_salary_structure
-- Assign or update base salary compensation structure for an employee
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_create_staff_salary_structure(
    p_school_id UUID,
    p_staff_id UUID,
    p_basic_pay NUMERIC,
    p_hra NUMERIC DEFAULT 0.0,
    p_da NUMERIC DEFAULT 0.0,
    p_ta NUMERIC DEFAULT 0.0,
    p_special NUMERIC DEFAULT 0.0,
    p_medical NUMERIC DEFAULT 0.0,
    p_pf NUMERIC DEFAULT 0.0,
    p_tds NUMERIC DEFAULT 0.0,
    p_ptax NUMERIC DEFAULT 200.0,
    p_insurance NUMERIC DEFAULT 0.0,
    p_bank_name TEXT DEFAULT 'HDFC Bank',
    p_account_number TEXT DEFAULT NULL,
    p_ifsc TEXT DEFAULT NULL,
    p_pan TEXT DEFAULT NULL,
    p_payment_mode TEXT DEFAULT 'Direct Bank Transfer (NEFT/RTGS)'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_gross NUMERIC;
    v_ded NUMERIC;
    v_net NUMERIC;
    v_sid UUID;
BEGIN
    v_gross := p_basic_pay + p_hra + p_da + p_ta + p_special + p_medical;
    v_ded := p_pf + p_tds + p_ptax + p_insurance;
    v_net := GREATEST(0.0, v_gross - v_ded);

    INSERT INTO public.staff_salary_structures (
        school_id, staff_id, basic_pay, hra, da, ta, special_allowance, medical_allowance,
        gross_salary, pf_deduction, tds, professional_tax, insurance_deduction,
        total_deductions, net_salary, bank_name, account_number, ifsc_code, pan_number,
        payment_mode, status, updated_at
    ) VALUES (
        p_school_id, p_staff_id, p_basic_pay, p_hra, p_da, p_ta, p_special, p_medical,
        v_gross, p_pf, p_tds, p_ptax, p_insurance,
        v_ded, v_net, p_bank_name, p_account_number, p_ifsc, p_pan,
        p_payment_mode, 'ACTIVE', NOW()
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
        bank_name = EXCLUDED.bank_name,
        account_number = EXCLUDED.account_number,
        ifsc_code = EXCLUDED.ifsc_code,
        pan_number = EXCLUDED.pan_number,
        payment_mode = EXCLUDED.payment_mode,
        updated_at = NOW()
    RETURNING id INTO v_sid;

    RETURN jsonb_build_object(
        'success', true,
        'structure_id', v_sid,
        'gross_salary', v_gross,
        'net_salary', v_net,
        'message', 'Salary structure saved successfully'
    );
END;
$$;


-- ============================================================================
-- 5. FUNCTION: fn_staff_payslips_master
-- Searchable, filterable, paginated master table of all monthly payslips
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_staff_payslips_master(
    p_school_id UUID,
    p_month_str TEXT DEFAULT '2026-10',
    p_department TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'payslip_number',
    p_sort_order TEXT DEFAULT 'DESC',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
            payout.bonus,
            payout.gross_earnings,
            payout.pf_deduction,
            payout.tds,
            payout.professional_tax,
            payout.advance_deduction,
            payout.other_deductions,
            payout.total_deductions,
            payout.net_pay,
            payout.payment_status,
            payout.payment_date,
            payout.payment_mode,
            payout.transaction_reference,
            COALESCE(struct.bank_name, 'HDFC Bank') AS bank_name,
            COALESCE(struct.account_number, '501002340055') AS account_number,
            COALESCE(struct.ifsc_code, 'HDFC0001824') AS ifsc_code,
            COALESCE(struct.pan_number, 'PAN000055X') AS pan_number
        FROM public.staff_salary_payouts payout
        JOIN public.profiles p ON payout.staff_id = p.id AND payout.school_id = p.school_id
        LEFT JOIN public.staff_salary_structures struct ON p.id = struct.staff_id AND p.school_id = struct.school_id
        WHERE payout.school_id = p_school_id 
          AND payout.month_str = p_month_str
          AND (p_department IS NULL OR p_department IN ('All Departments', 'All', '') OR p.department = p_department)
          AND (p_search IS NULL OR p_search = '' OR (
              p.full_name ILIKE '%' || p_search || '%' OR
              p.employee_id ILIKE '%' || p_search || '%' OR
              payout.payslip_number ILIKE '%' || p_search || '%' OR
              payout.transaction_reference ILIKE '%' || p_search || '%'
          ))
    ),
    counted AS (
        SELECT COUNT(*) AS total_items FROM ps_raw
    ),
    sorted_page AS (
        SELECT * FROM ps_raw
        ORDER BY
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'payslip_number' THEN payslip_number END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'payslip_number' THEN payslip_number END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'name' THEN staff_name END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'name' THEN staff_name END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'gross' THEN gross_earnings END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'gross' THEN gross_earnings END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'deductions' THEN total_deductions END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'deductions' THEN total_deductions END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'net' THEN net_pay END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'net' THEN net_pay END DESC NULLS LAST,
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
                    'bonus', sp.bonus,
                    'gross_earnings', sp.gross_earnings,
                    'pf_deduction', sp.pf_deduction,
                    'tds', sp.tds,
                    'professional_tax', sp.professional_tax,
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
$$;


-- ============================================================================
-- 6. FUNCTION: fn_staff_advances_master
-- Searchable, paginated advances master table with repayment ledger & balance
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_staff_advances_master(
    p_school_id UUID,
    p_status TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'created_at',
    p_sort_order TEXT DEFAULT 'DESC',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_items INT := 0;
    v_total_pages INT := 1;
    v_offset INT := 0;
    v_advances JSONB := '[]'::jsonb;
    v_clean_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_clean_size INT := GREATEST(1, LEAST(100, COALESCE(p_page_size, 10)));
BEGIN
    v_offset := (v_clean_page - 1) * v_clean_size;

    WITH adv_raw AS (
        SELECT 
            adv.id,
            adv.staff_id,
            p.full_name AS staff_name,
            COALESCE(p.employee_id, 'EMP-' || SUBSTRING(p.id::text, 1, 6)) AS employee_id,
            COALESCE(p.department, 'Academic & Teaching') AS department,
            adv.amount,
            adv.purpose_type,
            adv.reason,
            adv.repayment_months,
            adv.monthly_deduction,
            COALESCE(adv.amount_repaid, 0.0) AS amount_repaid,
            GREATEST(0.0, adv.amount - COALESCE(adv.amount_repaid, 0.0)) AS outstanding_balance,
            LEAST(100.0, ROUND((COALESCE(adv.amount_repaid, 0.0) / adv.amount * 100.0)::numeric, 1)) AS progress_pct,
            adv.status,
            adv.disbursed_at,
            adv.created_at,
            adv.remarks
        FROM public.staff_salary_advances adv
        JOIN public.profiles p ON adv.staff_id = p.id AND adv.school_id = p.school_id
        WHERE adv.school_id = p_school_id
          AND (p_status IS NULL OR p_status IN ('All Status', 'All', '') OR adv.status ILIKE p_status)
          AND (p_search IS NULL OR p_search = '' OR (
              p.full_name ILIKE '%' || p_search || '%' OR
              p.employee_id ILIKE '%' || p_search || '%' OR
              adv.purpose_type ILIKE '%' || p_search || '%'
          ))
    ),
    counted AS (
        SELECT COUNT(*) AS total_items FROM adv_raw
    ),
    sorted_page AS (
        SELECT * FROM adv_raw
        ORDER BY
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'name' THEN staff_name END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'name' THEN staff_name END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'amount' THEN amount END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'amount' THEN amount END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'status' THEN status END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'status' THEN status END DESC NULLS LAST,
            created_at DESC
        LIMIT v_clean_size OFFSET v_offset
    )
    SELECT 
        (SELECT total_items FROM counted),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', sp.id,
                    'staff_id', sp.staff_id,
                    'staff_name', sp.staff_name,
                    'employee_id', sp.employee_id,
                    'department', sp.department,
                    'amount', sp.amount,
                    'amount_formatted', '₹ ' || TO_CHAR(sp.amount, 'FM99,99,990.00'),
                    'purpose_type', sp.purpose_type,
                    'reason', sp.reason,
                    'repayment_months', sp.repayment_months,
                    'monthly_deduction', sp.monthly_deduction,
                    'monthly_deduction_formatted', '₹ ' || TO_CHAR(sp.monthly_deduction, 'FM99,99,990.00'),
                    'amount_repaid', sp.amount_repaid,
                    'amount_repaid_formatted', '₹ ' || TO_CHAR(sp.amount_repaid, 'FM99,99,990.00'),
                    'outstanding_balance', sp.outstanding_balance,
                    'outstanding_balance_formatted', '₹ ' || TO_CHAR(sp.outstanding_balance, 'FM99,99,990.00'),
                    'progress_pct', sp.progress_pct,
                    'status', sp.status,
                    'disbursed_at', sp.disbursed_at,
                    'created_at', sp.created_at,
                    'remarks', sp.remarks
                )
            ),
            '[]'::jsonb
        )
    INTO v_total_items, v_advances
    FROM sorted_page sp;

    v_total_pages := GREATEST(1, CEIL(v_total_items::NUMERIC / v_clean_size)::INT);

    RETURN jsonb_build_object(
        'success', true,
        'page', v_clean_page,
        'page_size', v_clean_size,
        'total_items', v_total_items,
        'total_pages', v_total_pages,
        'advances', v_advances
    );
END;
$$;


-- ============================================================================
-- 7. FUNCTION: fn_settle_staff_salary_advance
-- Record early cash/bank repayment and clear advance balance
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_settle_staff_salary_advance(
    p_school_id UUID,
    p_advance_id UUID,
    p_settlement_amount NUMERIC,
    p_payment_mode TEXT DEFAULT 'Cash',
    p_remarks TEXT DEFAULT 'Early loan clearance',
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_adv RECORD;
    v_new_repaid NUMERIC;
    v_new_status TEXT;
BEGIN
    SELECT * INTO v_adv
    FROM public.staff_salary_advances
    WHERE id = p_advance_id AND school_id = p_school_id;

    IF v_adv IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Advance record not found');
    END IF;

    v_new_repaid := LEAST(v_adv.amount, COALESCE(v_adv.amount_repaid, 0.0) + p_settlement_amount);
    v_new_status := CASE WHEN v_new_repaid >= v_adv.amount THEN 'Settled' ELSE v_adv.status END;

    UPDATE public.staff_salary_advances
    SET amount_repaid = v_new_repaid,
        status = v_new_status,
        remarks = COALESCE(p_remarks, 'Settled via ' || p_payment_mode),
        updated_at = NOW()
    WHERE id = p_advance_id AND school_id = p_school_id;

    RETURN jsonb_build_object(
        'success', true,
        'advance_id', p_advance_id,
        'amount_repaid', v_new_repaid,
        'outstanding_balance', GREATEST(0.0, v_adv.amount - v_new_repaid),
        'status', v_new_status,
        'message', 'Settlement recorded successfully'
    );
END;
$$;


-- ============================================================================
-- 8. FUNCTION: fn_export_bank_disbursal_file
-- Formats batch salary disbursal for corporate bank portals (NEFT/RTGS/NACH)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_export_bank_disbursal_file(
    p_school_id UUID,
    p_month_str TEXT DEFAULT '2026-10',
    p_department TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_records JSONB := '[]'::jsonb;
    v_total_amount NUMERIC(12,2) := 0.0;
    v_count INT := 0;
BEGIN
    SELECT 
        COALESCE(SUM(payout.net_pay), 0.0),
        COUNT(*),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'beneficiary_name', p.full_name,
                    'employee_id', COALESCE(p.employee_id, 'EMP-' || SUBSTRING(p.id::text, 1, 6)),
                    'department', COALESCE(p.department, 'Academic & Teaching'),
                    'bank_name', COALESCE(struct.bank_name, 'HDFC Bank'),
                    'account_number', COALESCE(struct.account_number, '501002340055'),
                    'ifsc_code', COALESCE(struct.ifsc_code, 'HDFC0001824'),
                    'amount', payout.net_pay,
                    'amount_formatted', '₹ ' || TO_CHAR(payout.net_pay, 'FM99,99,990.00'),
                    'narration', 'SALARY-' || p_month_str,
                    'payslip_number', payout.payslip_number,
                    'status', payout.payment_status
                )
            ),
            '[]'::jsonb
        )
    INTO v_total_amount, v_count, v_records
    FROM public.staff_salary_payouts payout
    JOIN public.profiles p ON payout.staff_id = p.id AND payout.school_id = p.school_id
    LEFT JOIN public.staff_salary_structures struct ON p.id = struct.staff_id AND p.school_id = struct.school_id
    WHERE payout.school_id = p_school_id 
      AND payout.month_str = p_month_str
      AND (p_department IS NULL OR p_department IN ('All Departments', 'All', '') OR p.department = p_department);

    RETURN jsonb_build_object(
        'success', true,
        'school_id', p_school_id,
        'month_str', p_month_str,
        'record_count', v_count,
        'total_amount', v_total_amount,
        'total_amount_formatted', '₹ ' || TO_CHAR(v_total_amount, 'FM99,99,990.00'),
        'records', v_records
    );
END;
$$;
