-- ============================================================================
-- Migration: 550_staff_payroll_global_search_and_period_logging.sql
-- Description:
--   1. Adds bonus_type, bonus_remarks, other_deductions_remarks to staff_salary_payouts.
--   2. Enforces unique index on (school_id, staff_id, month_str) for staff_salary_payouts.
--   3. Implements fn_search_all_staff_for_payroll(p_school_id, p_search, p_month_str)
--      returning all staff members with contract structures, advance loan balance,
--      and historical payout status for the requested period.
--   4. Upgrades fn_process_staff_salary_payout to support bonus classifications,
--      remarks, and p_update_permanent_structure toggle (saving base increments
--      while resetting variable bonuses and ad-hoc deductions in future cycles).
-- ============================================================================

-- Step 1: Ensure columns exist on public.staff_salary_payouts
ALTER TABLE public.staff_salary_payouts ADD COLUMN IF NOT EXISTS bank_name VARCHAR(150);
ALTER TABLE public.staff_salary_payouts ADD COLUMN IF NOT EXISTS account_number VARCHAR(100);
ALTER TABLE public.staff_salary_payouts ADD COLUMN IF NOT EXISTS ifsc_code VARCHAR(50);
ALTER TABLE public.staff_salary_payouts ADD COLUMN IF NOT EXISTS pan_number VARCHAR(50);
ALTER TABLE public.staff_salary_payouts ADD COLUMN IF NOT EXISTS upi_id VARCHAR(100);
ALTER TABLE public.staff_salary_payouts ADD COLUMN IF NOT EXISTS cheque_number VARCHAR(100);
ALTER TABLE public.staff_salary_payouts ADD COLUMN IF NOT EXISTS bonus_type VARCHAR(50) DEFAULT 'NONE';
ALTER TABLE public.staff_salary_payouts ADD COLUMN IF NOT EXISTS bonus_remarks TEXT DEFAULT NULL;
ALTER TABLE public.staff_salary_payouts ADD COLUMN IF NOT EXISTS other_deductions_remarks TEXT DEFAULT NULL;

-- Step 2: Ensure unique index on (school_id, staff_id, month_str)
CREATE UNIQUE INDEX IF NOT EXISTS uq_staff_salary_payouts_school_staff_month 
ON public.staff_salary_payouts (school_id, staff_id, month_str);

-- Step 3: Stored Procedure for Global Staff Payroll Search
CREATE OR REPLACE FUNCTION public.fn_search_all_staff_for_payroll(
    p_school_id UUID,
    p_search TEXT DEFAULT '',
    p_month_str TEXT DEFAULT '2026-10'
)
RETURNS TABLE (
    staff_id UUID,
    full_name TEXT,
    employee_id TEXT,
    designation TEXT,
    department TEXT,
    email TEXT,
    phone TEXT,
    has_structure BOOLEAN,
    basic_pay NUMERIC,
    hra NUMERIC,
    da NUMERIC,
    ta NUMERIC,
    special_allowance NUMERIC,
    gross_salary NUMERIC,
    pf_deduction NUMERIC,
    tds NUMERIC,
    professional_tax NUMERIC,
    total_deductions NUMERIC,
    net_salary NUMERIC,
    payment_mode TEXT,
    bank_name TEXT,
    account_number TEXT,
    ifsc_code TEXT,
    pan_number TEXT,
    active_advance_balance NUMERIC,
    advance_monthly_emi NUMERIC,
    payout_id UUID,
    payout_status TEXT,
    payout_date TIMESTAMPTZ,
    payout_txn_ref TEXT,
    payout_payslip_number TEXT,
    payout_net_pay NUMERIC,
    payout_bonus NUMERIC,
    payout_bonus_type TEXT,
    payout_bonus_remarks TEXT,
    payout_other_deductions NUMERIC,
    payout_other_deductions_remarks TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_month_str TEXT;
BEGIN
    v_clean_month_str := COALESCE(NULLIF(TRIM(p_month_str), ''), TO_CHAR(NOW(), 'YYYY-MM'));

    RETURN QUERY
    WITH staff_advances AS (
        SELECT
            a.staff_id,
            COALESCE(SUM(GREATEST(0.0, a.amount - COALESCE(a.amount_repaid, 0.0))), 0.0) AS active_balance,
            COALESCE(SUM(CASE WHEN a.amount_repaid < a.amount THEN COALESCE(a.monthly_deduction, 0.0) ELSE 0.0 END), 0.0) AS monthly_emi
        FROM public.staff_salary_advances a
        WHERE a.school_id = p_school_id
          AND a.status = 'Approved'
          AND COALESCE(a.amount_repaid, 0.0) < a.amount
        GROUP BY a.staff_id
    )
    SELECT
        p.id AS staff_id,
        p.full_name::TEXT,
        COALESCE(p.employee_id, 'EMP-' || SUBSTRING(p.id::text, 1, 6))::TEXT AS employee_id,
        COALESCE(p.designation, 'Faculty Member')::TEXT AS designation,
        COALESCE(p.department, 'Academic & Teaching')::TEXT AS department,
        COALESCE(p.email, '')::TEXT AS email,
        COALESCE(p.phone, '')::TEXT AS phone,
        (s.id IS NOT NULL) AS has_structure,
        COALESCE(s.basic_pay, 35000.0) AS basic_pay,
        COALESCE(s.hra, 14000.0) AS hra,
        COALESCE(s.da, 5000.0) AS da,
        COALESCE(s.ta, 2500.0) AS ta,
        COALESCE(s.special_allowance, 3000.0) AS special_allowance,
        COALESCE(s.gross_salary, 59500.0) AS gross_salary,
        COALESCE(s.pf_deduction, 4200.0) AS pf_deduction,
        COALESCE(s.tds, 2500.0) AS tds,
        COALESCE(s.professional_tax, 200.0) AS professional_tax,
        COALESCE(s.total_deductions, 6900.0) AS total_deductions,
        COALESCE(s.net_salary, 52600.0) AS net_salary,
        COALESCE(s.payment_mode, 'Direct Bank Transfer (NEFT/RTGS)')::TEXT AS payment_mode,
        COALESCE(s.bank_name, 'State Bank of India')::TEXT AS bank_name,
        COALESCE(s.account_number, '')::TEXT AS account_number,
        COALESCE(s.ifsc_code, '')::TEXT AS ifsc_code,
        COALESCE(s.pan_number, '')::TEXT AS pan_number,
        COALESCE(adv.active_balance, 0.0) AS active_advance_balance,
        COALESCE(adv.monthly_emi, 0.0) AS advance_monthly_emi,
        pay.id AS payout_id,
        COALESCE(pay.payment_status, 'Pending')::TEXT AS payout_status,
        pay.payment_date AS payout_date,
        pay.transaction_reference::TEXT AS payout_txn_ref,
        pay.payslip_number::TEXT AS payout_payslip_number,
        pay.net_pay AS payout_net_pay,
        COALESCE(pay.bonus, 0.0) AS payout_bonus,
        COALESCE(pay.bonus_type, 'NONE')::TEXT AS payout_bonus_type,
        pay.bonus_remarks::TEXT AS payout_bonus_remarks,
        COALESCE(pay.other_deductions, 0.0) AS payout_other_deductions,
        pay.other_deductions_remarks::TEXT AS payout_other_deductions_remarks
    FROM public.profiles p
    LEFT JOIN public.staff_salary_structures s
        ON s.staff_id = p.id AND s.school_id = p_school_id
    LEFT JOIN staff_advances adv
        ON adv.staff_id = p.id
    LEFT JOIN public.staff_salary_payouts pay
        ON pay.staff_id = p.id AND pay.school_id = p_school_id AND pay.month_str = v_clean_month_str
    WHERE p.school_id = p_school_id
      AND (
          p.role IN ('staff', 'teacher', 'admin', 'principal', 'accountant', 'driver', 'librarian', 'faculty')
          OR p.employee_id IS NOT NULL
      )
      AND (
          NULLIF(TRIM(p_search), '') IS NULL
          OR p.full_name ILIKE '%' || TRIM(p_search) || '%'
          OR COALESCE(p.employee_id, '') ILIKE '%' || TRIM(p_search) || '%'
          OR COALESCE(p.email, '') ILIKE '%' || TRIM(p_search) || '%'
          OR COALESCE(p.phone, '') ILIKE '%' || TRIM(p_search) || '%'
          OR COALESCE(p.department, '') ILIKE '%' || TRIM(p_search) || '%'
          OR COALESCE(p.designation, '') ILIKE '%' || TRIM(p_search) || '%'
      )
    ORDER BY p.full_name ASC
    LIMIT 100;
END;
$$;


-- Step 4: Enhanced fn_process_staff_salary_payout with 25 parameters
CREATE OR REPLACE FUNCTION public.fn_process_staff_salary_payout(
    p_school_id UUID,
    p_staff_id UUID,
    p_month INT,
    p_year INT,
    p_month_str TEXT,
    p_basic_pay NUMERIC(12,2),
    p_hra NUMERIC(12,2),
    p_da NUMERIC(12,2),
    p_ta NUMERIC(12,2),
    p_special_allowance NUMERIC(12,2),
    p_bonus NUMERIC(12,2),
    p_pf_deduction NUMERIC(12,2),
    p_tds NUMERIC(12,2),
    p_professional_tax NUMERIC(12,2),
    p_advance_deduction NUMERIC(12,2),
    p_other_deductions NUMERIC(12,2),
    p_payment_status TEXT DEFAULT 'Paid',
    p_payment_mode TEXT DEFAULT 'Direct Bank Transfer (NEFT/RTGS)',
    p_transaction_reference TEXT DEFAULT NULL,
    p_remarks TEXT DEFAULT NULL,
    p_user_id UUID DEFAULT NULL,
    p_bonus_type TEXT DEFAULT 'NONE',
    p_bonus_remarks TEXT DEFAULT NULL,
    p_other_deductions_remarks TEXT DEFAULT NULL,
    p_update_permanent_structure BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_gross_earnings NUMERIC(12,2);
    v_total_deductions NUMERIC(12,2);
    v_net_pay NUMERIC(12,2);
    v_ps_num TEXT;
    v_txn_ref TEXT;
    v_payout_id UUID;
    v_staff_name TEXT;
    v_emp_id TEXT;
    v_clean_month_str TEXT;
    v_clean_month INT;
    v_clean_year INT;
    v_clean_status TEXT;
    v_clean_mode TEXT;
    v_remaining_deduction NUMERIC(12,2);
    v_alloc NUMERIC(12,2);
    v_adv RECORD;
    v_repaid_adv_count INT := 0;
    v_bank_name VARCHAR(150);
    v_account_number VARCHAR(100);
    v_ifsc_code VARCHAR(50);
    v_pan_number VARCHAR(50);
BEGIN
    -- Validate staff existence
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

    -- Fetch current bank/tax structure for this staff if available
    SELECT bank_name, account_number, ifsc_code, pan_number
    INTO v_bank_name, v_account_number, v_ifsc_code, v_pan_number
    FROM public.staff_salary_structures
    WHERE staff_id = p_staff_id AND school_id = p_school_id;

    -- Sanitize dates and period
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

    -- Real financial calculations
    v_gross_earnings := COALESCE(p_basic_pay, 0.0) +
                        COALESCE(p_hra, 0.0) +
                        COALESCE(p_da, 0.0) +
                        COALESCE(p_ta, 0.0) +
                        COALESCE(p_special_allowance, 0.0) +
                        COALESCE(p_bonus, 0.0);

    v_total_deductions := COALESCE(p_pf_deduction, 0.0) +
                          COALESCE(p_tds, 0.0) +
                          COALESCE(p_professional_tax, 0.0) +
                          COALESCE(p_advance_deduction, 0.0) +
                          COALESCE(p_other_deductions, 0.0);

    v_net_pay := GREATEST(0.0, v_gross_earnings - v_total_deductions);

    -- Format / retrieve unique payslip number
    SELECT payslip_number INTO v_ps_num
    FROM public.staff_salary_payouts
    WHERE school_id = p_school_id AND staff_id = p_staff_id AND month_str = v_clean_month_str;

    IF v_ps_num IS NULL OR v_ps_num = '' THEN
        v_ps_num := 'PS-' || v_clean_month_str || '-' || v_emp_id;
    END IF;

    -- Generate transaction reference if disbursing and not provided
    IF v_clean_status = 'Paid' THEN
        v_txn_ref := COALESCE(NULLIF(TRIM(p_transaction_reference), ''), 'UTR-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || SUBSTRING(gen_random_uuid()::text, 1, 8));
    ELSE
        v_txn_ref := p_transaction_reference;
    END IF;

    -- Upsert payout record with atomic financial totals
    INSERT INTO public.staff_salary_payouts (
        school_id, staff_id, payslip_number, month, year, month_str,
        basic_pay, hra, da, ta, special_allowance, bonus, gross_earnings,
        pf_deduction, tds, professional_tax, advance_deduction, other_deductions,
        total_deductions, net_pay, payment_status, payment_date, payment_mode,
        transaction_reference, remarks, processed_by,
        bank_name, account_number, ifsc_code, pan_number,
        bonus_type, bonus_remarks, other_deductions_remarks, updated_at
    ) VALUES (
        p_school_id, p_staff_id, v_ps_num, v_clean_month, v_clean_year, v_clean_month_str,
        COALESCE(p_basic_pay, 0.0), COALESCE(p_hra, 0.0), COALESCE(p_da, 0.0),
        COALESCE(p_ta, 0.0), COALESCE(p_special_allowance, 0.0), COALESCE(p_bonus, 0.0),
        v_gross_earnings,
        COALESCE(p_pf_deduction, 0.0), COALESCE(p_tds, 0.0), COALESCE(p_professional_tax, 200.0),
        COALESCE(p_advance_deduction, 0.0), COALESCE(p_other_deductions, 0.0),
        v_total_deductions, v_net_pay, v_clean_status,
        CASE WHEN v_clean_status = 'Paid' THEN NOW() ELSE NULL END,
        v_clean_mode, v_txn_ref,
        COALESCE(p_remarks, 'Monthly salary disbursal for ' || v_clean_month_str),
        p_user_id,
        v_bank_name, v_account_number, v_ifsc_code, v_pan_number,
        COALESCE(p_bonus_type, 'NONE'), p_bonus_remarks, p_other_deductions_remarks, NOW()
    )
    ON CONFLICT (school_id, staff_id, month_str) DO UPDATE SET
        basic_pay = EXCLUDED.basic_pay,
        hra = EXCLUDED.hra,
        da = EXCLUDED.da,
        ta = EXCLUDED.ta,
        special_allowance = EXCLUDED.special_allowance,
        bonus = EXCLUDED.bonus,
        gross_earnings = EXCLUDED.gross_earnings,
        pf_deduction = EXCLUDED.pf_deduction,
        tds = EXCLUDED.tds,
        professional_tax = EXCLUDED.professional_tax,
        advance_deduction = EXCLUDED.advance_deduction,
        other_deductions = EXCLUDED.other_deductions,
        total_deductions = EXCLUDED.total_deductions,
        net_pay = EXCLUDED.net_pay,
        payment_status = EXCLUDED.payment_status,
        payment_date = CASE WHEN EXCLUDED.payment_status = 'Paid' THEN COALESCE(staff_salary_payouts.payment_date, NOW()) ELSE NULL END,
        payment_mode = EXCLUDED.payment_mode,
        transaction_reference = COALESCE(EXCLUDED.transaction_reference, staff_salary_payouts.transaction_reference),
        remarks = EXCLUDED.remarks,
        processed_by = COALESCE(EXCLUDED.processed_by, staff_salary_payouts.processed_by),
        bank_name = COALESCE(EXCLUDED.bank_name, staff_salary_payouts.bank_name),
        account_number = COALESCE(EXCLUDED.account_number, staff_salary_payouts.account_number),
        ifsc_code = COALESCE(EXCLUDED.ifsc_code, staff_salary_payouts.ifsc_code),
        pan_number = COALESCE(EXCLUDED.pan_number, staff_salary_payouts.pan_number),
        bonus_type = EXCLUDED.bonus_type,
        bonus_remarks = EXCLUDED.bonus_remarks,
        other_deductions_remarks = EXCLUDED.other_deductions_remarks,
        updated_at = NOW()
    RETURNING id, payslip_number INTO v_payout_id, v_ps_num;

    -- Step 4A: Update permanent base salary structure if requested
    -- IMPORTANT: Bonus and other_deductions are intentionally EXCLUDED here so that
    -- permanent structure only retains contracted base compensation, and variable
    -- performance bonuses or ad-hoc deductions reset every month.
    IF p_update_permanent_structure IS TRUE THEN
        INSERT INTO public.staff_salary_structures (
            school_id, staff_id, basic_pay, hra, da, ta, special_allowance,
            gross_salary, pf_deduction, tds, professional_tax, total_deductions,
            net_salary, payment_mode, bank_name, account_number, ifsc_code, pan_number,
            status, effective_date, updated_at
        ) VALUES (
            p_school_id, p_staff_id,
            COALESCE(p_basic_pay, 0.0), COALESCE(p_hra, 0.0), COALESCE(p_da, 0.0),
            COALESCE(p_ta, 0.0), COALESCE(p_special_allowance, 0.0),
            (COALESCE(p_basic_pay, 0.0) + COALESCE(p_hra, 0.0) + COALESCE(p_da, 0.0) + COALESCE(p_ta, 0.0) + COALESCE(p_special_allowance, 0.0)),
            COALESCE(p_pf_deduction, 0.0), COALESCE(p_tds, 0.0), COALESCE(p_professional_tax, 200.0),
            (COALESCE(p_pf_deduction, 0.0) + COALESCE(p_tds, 0.0) + COALESCE(p_professional_tax, 200.0)),
            (COALESCE(p_basic_pay, 0.0) + COALESCE(p_hra, 0.0) + COALESCE(p_da, 0.0) + COALESCE(p_ta, 0.0) + COALESCE(p_special_allowance, 0.0)) - (COALESCE(p_pf_deduction, 0.0) + COALESCE(p_tds, 0.0) + COALESCE(p_professional_tax, 200.0)),
            v_clean_mode, v_bank_name, v_account_number, v_ifsc_code, v_pan_number,
            'Active', CURRENT_DATE, NOW()
        )
        ON CONFLICT (school_id, staff_id) DO UPDATE SET
            basic_pay = EXCLUDED.basic_pay,
            hra = EXCLUDED.hra,
            da = EXCLUDED.da,
            ta = EXCLUDED.ta,
            special_allowance = EXCLUDED.special_allowance,
            gross_salary = EXCLUDED.gross_salary,
            pf_deduction = EXCLUDED.pf_deduction,
            tds = EXCLUDED.tds,
            professional_tax = EXCLUDED.professional_tax,
            total_deductions = EXCLUDED.total_deductions,
            net_salary = EXCLUDED.net_salary,
            payment_mode = COALESCE(EXCLUDED.payment_mode, staff_salary_structures.payment_mode),
            bank_name = COALESCE(EXCLUDED.bank_name, staff_salary_structures.bank_name),
            account_number = COALESCE(EXCLUDED.account_number, staff_salary_structures.account_number),
            ifsc_code = COALESCE(EXCLUDED.ifsc_code, staff_salary_structures.ifsc_code),
            pan_number = COALESCE(EXCLUDED.pan_number, staff_salary_structures.pan_number),
            effective_date = CURRENT_DATE,
            updated_at = NOW();
    END IF;

    -- Step 4B: Precise FIFO Loan Advance Recovery
    IF v_clean_status = 'Paid' AND COALESCE(p_advance_deduction, 0.0) > 0.0 THEN
        v_remaining_deduction := p_advance_deduction;

        FOR v_adv IN
            SELECT id, amount, COALESCE(amount_repaid, 0.0) AS amount_repaid
            FROM public.staff_salary_advances
            WHERE staff_id = p_staff_id
              AND school_id = p_school_id
              AND status = 'Approved'
              AND amount_repaid < amount
            ORDER BY created_at ASC
            FOR UPDATE
        LOOP
            IF v_remaining_deduction <= 0.0 THEN
                EXIT;
            END IF;

            v_alloc := LEAST(v_remaining_deduction, (v_adv.amount - v_adv.amount_repaid));

            UPDATE public.staff_salary_advances
            SET amount_repaid = amount_repaid + v_alloc,
                status = CASE WHEN (amount_repaid + v_alloc) >= amount THEN 'Settled' ELSE 'Approved' END,
                updated_at = NOW()
            WHERE id = v_adv.id;

            v_remaining_deduction := v_remaining_deduction - v_alloc;
            v_repaid_adv_count := v_repaid_adv_count + 1;
        END LOOP;
    END IF;

    -- Step 4C: Security audit log entry
    BEGIN
        INSERT INTO public.audit_logs (
            school_id, user_id, event_type, module, action, resource, resource_type, status, changes, created_at
        ) VALUES (
            p_school_id, p_user_id, 'STAFF_SALARY_PAYOUT', 'Staff Salary Management', 'Disburse Salary', v_payout_id::text, 'staff_salary_payouts', 'Success',
            jsonb_build_object(
                'staff_id', p_staff_id,
                'staff_name', v_staff_name,
                'month_str', v_clean_month_str,
                'gross_earnings', v_gross_earnings,
                'total_deductions', v_total_deductions,
                'bonus', p_bonus,
                'bonus_type', p_bonus_type,
                'bonus_remarks', p_bonus_remarks,
                'advance_deduction', p_advance_deduction,
                'other_deductions', p_other_deductions,
                'other_deductions_remarks', p_other_deductions_remarks,
                'net_pay', v_net_pay,
                'payment_status', v_clean_status,
                'payment_mode', v_clean_mode,
                'transaction_reference', v_txn_ref,
                'repaid_advances_count', v_repaid_adv_count,
                'permanent_structure_updated', p_update_permanent_structure
            ),
            NOW()
        );
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Salary payout for ' || v_staff_name || ' processed successfully',
        'payout_id', v_payout_id,
        'payslip_number', v_ps_num,
        'staff_id', p_staff_id,
        'staff_name', v_staff_name,
        'month_str', v_clean_month_str,
        'gross_earnings', v_gross_earnings,
        'total_deductions', v_total_deductions,
        'net_pay', v_net_pay,
        'payment_status', v_clean_status,
        'payment_mode', v_clean_mode,
        'transaction_reference', v_txn_ref,
        'repaid_advances_count', v_repaid_adv_count,
        'bonus_type', p_bonus_type,
        'bonus_remarks', p_bonus_remarks,
        'other_deductions_remarks', p_other_deductions_remarks,
        'permanent_structure_updated', p_update_permanent_structure
    );
END;
$$;

-- Step 5: Backward Compatibility 21-Parameter Overload
CREATE OR REPLACE FUNCTION public.fn_process_staff_salary_payout(
    p_school_id UUID,
    p_staff_id UUID,
    p_month INT,
    p_year INT,
    p_month_str TEXT,
    p_basic_pay NUMERIC(12,2),
    p_hra NUMERIC(12,2),
    p_da NUMERIC(12,2),
    p_ta NUMERIC(12,2),
    p_special_allowance NUMERIC(12,2),
    p_bonus NUMERIC(12,2),
    p_pf_deduction NUMERIC(12,2),
    p_tds NUMERIC(12,2),
    p_professional_tax NUMERIC(12,2),
    p_advance_deduction NUMERIC(12,2),
    p_other_deductions NUMERIC(12,2),
    p_payment_status TEXT DEFAULT 'Paid',
    p_payment_mode TEXT DEFAULT 'Direct Bank Transfer (NEFT/RTGS)',
    p_transaction_reference TEXT DEFAULT NULL,
    p_remarks TEXT DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN public.fn_process_staff_salary_payout(
        p_school_id, p_staff_id, p_month, p_year, p_month_str,
        p_basic_pay, p_hra, p_da, p_ta, p_special_allowance, p_bonus,
        p_pf_deduction, p_tds, p_professional_tax, p_advance_deduction, p_other_deductions,
        p_payment_status, p_payment_mode, p_transaction_reference, p_remarks, p_user_id,
        'NONE', NULL, NULL, FALSE
    );
END;
$$;
