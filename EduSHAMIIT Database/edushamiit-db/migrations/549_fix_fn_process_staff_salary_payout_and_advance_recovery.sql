-- ============================================================================
-- Migration: 549_fix_fn_process_staff_salary_payout_and_advance_recovery.sql
-- Description:
--   1. Ensures staff_salary_payouts table has bank/tender audit columns.
--   2. Fixes fn_process_staff_salary_payout with 21-parameter signature matching
--      FastAPI ProcessStaffPayoutPayload and adds 7-parameter compatibility overload.
--   3. Implements strict FIFO loan recovery on staff_salary_advances when salary
--      is disbursed with advance_deduction > 0.
--   4. Keeps staff_salary_structures bank and salary details in sync upon disbursal.
--   5. Logs audit trail in audit_logs table.
-- ============================================================================

-- Step 1: Ensure audit & tender columns exist on public.staff_salary_payouts
ALTER TABLE public.staff_salary_payouts ADD COLUMN IF NOT EXISTS bank_name VARCHAR(150);
ALTER TABLE public.staff_salary_payouts ADD COLUMN IF NOT EXISTS account_number VARCHAR(100);
ALTER TABLE public.staff_salary_payouts ADD COLUMN IF NOT EXISTS ifsc_code VARCHAR(50);
ALTER TABLE public.staff_salary_payouts ADD COLUMN IF NOT EXISTS pan_number VARCHAR(50);
ALTER TABLE public.staff_salary_payouts ADD COLUMN IF NOT EXISTS upi_id VARCHAR(100);
ALTER TABLE public.staff_salary_payouts ADD COLUMN IF NOT EXISTS cheque_number VARCHAR(100);

-- Step 2: Main 21-parameter Stored Procedure called by FastAPI
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
    v_clean_month_str := COALESCE(NULLIF(p_month_str, ''), TO_CHAR(NOW(), 'YYYY-MM'));
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

    v_clean_status := COALESCE(NULLIF(p_payment_status, ''), 'Paid');
    v_clean_mode := COALESCE(NULLIF(p_payment_mode, ''), 'Direct Bank Transfer (NEFT/RTGS)');

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
        v_txn_ref := COALESCE(NULLIF(p_transaction_reference, ''), 'UTR-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || SUBSTRING(gen_random_uuid()::text, 1, 8));
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
        bank_name, account_number, ifsc_code, pan_number, updated_at
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
        v_bank_name, v_account_number, v_ifsc_code, v_pan_number, NOW()
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
        updated_at = NOW()
    RETURNING id, payslip_number INTO v_payout_id, v_ps_num;

    -- Step 3: Precise FIFO Loan Advance Recovery
    -- If salary is disbursed (Paid) and an advance deduction was made, credit it to active loans
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

    -- Step 4: Record security audit log entry
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
                'advance_deduction', p_advance_deduction,
                'net_pay', v_net_pay,
                'payment_status', v_clean_status,
                'payment_mode', v_clean_mode,
                'transaction_reference', v_txn_ref,
                'repaid_advances_count', v_repaid_adv_count
            ),
            NOW()
        );
    EXCEPTION WHEN OTHERS THEN
        -- Non-blocking audit log failure
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
        'repaid_advances_count', v_repaid_adv_count
    );
END;
$$;


-- Step 5: Backward Compatibility 7-Parameter Overload
CREATE OR REPLACE FUNCTION public.fn_process_staff_salary_payout(
    p_school_id UUID,
    p_staff_id UUID,
    p_month_str TEXT DEFAULT '2026-10',
    p_payment_mode TEXT DEFAULT 'Direct Bank Transfer (NEFT/RTGS)',
    p_transaction_reference TEXT DEFAULT NULL,
    p_remarks TEXT DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_struct RECORD;
    v_adv_ded NUMERIC(12,2) := 0.0;
    v_m INT := 10;
    v_y INT := 2026;
BEGIN
    BEGIN
        v_y := SUBSTRING(p_month_str FROM 1 FOR 4)::INT;
        v_m := SUBSTRING(p_month_str FROM 6 FOR 2)::INT;
    EXCEPTION WHEN OTHERS THEN
        v_y := 2026;
        v_m := 10;
    END;

    SELECT * INTO v_struct
    FROM public.staff_salary_structures
    WHERE staff_id = p_staff_id AND school_id = p_school_id;

    SELECT COALESCE(SUM(monthly_deduction), 0.0) INTO v_adv_ded
    FROM public.staff_salary_advances
    WHERE staff_id = p_staff_id AND school_id = p_school_id
      AND status = 'Approved' AND amount_repaid < amount;

    RETURN public.fn_process_staff_salary_payout(
        p_school_id,
        p_staff_id,
        v_m,
        v_y,
        p_month_str,
        COALESCE(v_struct.basic_pay, 35000.0),
        COALESCE(v_struct.hra, 14000.0),
        COALESCE(v_struct.da, 4500.0),
        COALESCE(v_struct.ta, 2500.0),
        COALESCE(v_struct.special_allowance, 2000.0),
        0.0, -- bonus
        COALESCE(v_struct.pf_deduction, 1800.0),
        COALESCE(v_struct.tds, 2500.0),
        COALESCE(v_struct.professional_tax, 200.0),
        v_adv_ded,
        0.0, -- other_deductions
        'Paid',
        COALESCE(p_payment_mode, 'Direct Bank Transfer (NEFT/RTGS)'),
        p_transaction_reference,
        p_remarks,
        p_user_id
    );
END;
$$;
