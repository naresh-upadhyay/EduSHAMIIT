-- ============================================================================
-- Migration: 566_staff_salary_ssot_unconfigured_catalog_and_automation.sql
-- Description:
--   1. Ensures profiles table has PAN, Bank Name, Account Number, IFSC (SSOT).
--   2. Syncs existing banking/tax credentials from staff_salary_structures to profiles.
--   3. Implements fn_get_unconfigured_salary_staff to fetch ONLY staff without
--      existing salary structures for the "+ Add Structure" workflow.
--   4. Updates fn_staff_salary_structures_catalog to show strictly CONFIGURED
--      structures with SSOT profile metadata (designation, department, employee_id).
--   5. Implements fn_save_staff_salary_structure with atomic profile credential sync.
--   6. Implements fn_auto_generate_monthly_payroll_payslips for one-click bulk
--      payroll automation with FIFO advance recovery.
-- ============================================================================

-- Step 1: Ensure profiles table holds canonical PAN & banking attributes (SSOT)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS pan_number VARCHAR(50);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bank_name VARCHAR(150);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS account_number VARCHAR(100);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS ifsc_code VARCHAR(50);

-- Sync banking details from structures to profiles where profile doesn't have them
UPDATE public.profiles p
SET 
    pan_number = COALESCE(NULLIF(p.pan_number, ''), s.pan_number),
    bank_name = COALESCE(NULLIF(p.bank_name, ''), s.bank_name),
    account_number = COALESCE(NULLIF(p.account_number, ''), s.account_number),
    ifsc_code = COALESCE(NULLIF(p.ifsc_code, ''), s.ifsc_code)
FROM public.staff_salary_structures s
WHERE p.id = s.staff_id AND p.school_id = s.school_id;

-- Step 2: Function to get staff members who do NOT yet have a salary structure
CREATE OR REPLACE FUNCTION public.fn_get_unconfigured_salary_staff(
    p_school_id UUID,
    p_search TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB := '[]'::jsonb;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'staff_id', p.id,
                'staff_name', p.full_name,
                'employee_id', COALESCE(p.employee_id, 'EMP-' || SUBSTRING(p.id::text, 1, 6)),
                'department', COALESCE(p.department, 'Academic & Teaching'),
                'designation', COALESCE(p.designation, p.role, 'Faculty Member'),
                'role', COALESCE(p.role, 'teacher'),
                'email', COALESCE(p.email, ''),
                'phone', COALESCE(p.phone, ''),
                'pan_number', COALESCE(p.pan_number, ''),
                'bank_name', COALESCE(p.bank_name, 'HDFC Bank'),
                'account_number', COALESCE(p.account_number, ''),
                'ifsc_code', COALESCE(p.ifsc_code, '')
            )
            ORDER BY p.full_name ASC
        ),
        '[]'::jsonb
    )
    INTO v_result
    FROM public.profiles p
    WHERE p.school_id = p_school_id
      AND p.role != 'student'
      AND p.id NOT IN (
          SELECT staff_id 
          FROM public.staff_salary_structures 
          WHERE school_id = p_school_id
      )
      AND (
          p_search IS NULL OR p_search = '' OR
          p.full_name ILIKE '%' || p_search || '%' OR
          p.employee_id ILIKE '%' || p_search || '%' OR
          p.department ILIKE '%' || p_search || '%' OR
          p.designation ILIKE '%' || p_search || '%' OR
          p.role ILIKE '%' || p_search || '%'
      );

    RETURN jsonb_build_object(
        'success', true,
        'count', jsonb_array_length(v_result),
        'staff', v_result
    );
END;
$$;

-- Step 3: Atomic Stored Procedure to Save or Update a Staff Salary Structure
CREATE OR REPLACE FUNCTION public.fn_save_staff_salary_structure(
    p_school_id UUID,
    p_staff_id UUID,
    p_basic_pay NUMERIC(12,2),
    p_hra NUMERIC(12,2),
    p_da NUMERIC(12,2),
    p_ta NUMERIC(12,2),
    p_special_allowance NUMERIC(12,2),
    p_medical_allowance NUMERIC(12,2),
    p_pf_deduction NUMERIC(12,2),
    p_tds NUMERIC(12,2),
    p_professional_tax NUMERIC(12,2),
    p_insurance_deduction NUMERIC(12,2),
    p_payment_mode TEXT DEFAULT 'Direct Bank Transfer (NEFT/RTGS)',
    p_bank_name TEXT DEFAULT NULL,
    p_account_number TEXT DEFAULT NULL,
    p_ifsc_code TEXT DEFAULT NULL,
    p_pan_number TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_gross NUMERIC(12,2);
    v_total_deductions NUMERIC(12,2);
    v_net NUMERIC(12,2);
    v_staff_name TEXT;
    v_struct_id UUID;
BEGIN
    SELECT full_name INTO v_staff_name
    FROM public.profiles
    WHERE id = p_staff_id AND school_id = p_school_id;

    IF v_staff_name IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Staff member profile not found for school'
        );
    END IF;

    v_gross := COALESCE(p_basic_pay, 0) + COALESCE(p_hra, 0) + COALESCE(p_da, 0) +
               COALESCE(p_ta, 0) + COALESCE(p_special_allowance, 0) + COALESCE(p_medical_allowance, 0);

    v_total_deductions := COALESCE(p_pf_deduction, 0) + COALESCE(p_tds, 0) +
                          COALESCE(p_professional_tax, 0) + COALESCE(p_insurance_deduction, 0);

    v_net := v_gross - v_total_deductions;

    -- Upsert salary structure
    INSERT INTO public.staff_salary_structures (
        school_id,
        staff_id,
        basic_pay,
        hra,
        da,
        ta,
        special_allowance,
        medical_allowance,
        gross_salary,
        pf_deduction,
        tds,
        professional_tax,
        insurance_deduction,
        total_deductions,
        net_salary,
        payment_mode,
        bank_name,
        account_number,
        ifsc_code,
        pan_number,
        status,
        updated_at
    ) VALUES (
        p_school_id,
        p_staff_id,
        COALESCE(p_basic_pay, 35000.0),
        COALESCE(p_hra, 14000.0),
        COALESCE(p_da, 5000.0),
        COALESCE(p_ta, 3000.0),
        COALESCE(p_special_allowance, 4000.0),
        COALESCE(p_medical_allowance, 2000.0),
        v_gross,
        COALESCE(p_pf_deduction, 4200.0),
        COALESCE(p_tds, 2500.0),
        COALESCE(p_professional_tax, 200.0),
        COALESCE(p_insurance_deduction, 1000.0),
        v_total_deductions,
        v_net,
        COALESCE(NULLIF(p_payment_mode, ''), 'Direct Bank Transfer (NEFT/RTGS)'),
        NULLIF(p_bank_name, ''),
        NULLIF(p_account_number, ''),
        NULLIF(p_ifsc_code, ''),
        NULLIF(p_pan_number, ''),
        'ACTIVE',
        NOW()
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
        payment_mode = EXCLUDED.payment_mode,
        bank_name = COALESCE(EXCLUDED.bank_name, public.staff_salary_structures.bank_name),
        account_number = COALESCE(EXCLUDED.account_number, public.staff_salary_structures.account_number),
        ifsc_code = COALESCE(EXCLUDED.ifsc_code, public.staff_salary_structures.ifsc_code),
        pan_number = COALESCE(EXCLUDED.pan_number, public.staff_salary_structures.pan_number),
        status = 'ACTIVE',
        updated_at = NOW()
    RETURNING id INTO v_struct_id;

    -- Keep profiles table SSOT banking/tax attributes in sync
    UPDATE public.profiles
    SET
        bank_name = COALESCE(NULLIF(p_bank_name, ''), bank_name),
        account_number = COALESCE(NULLIF(p_account_number, ''), account_number),
        ifsc_code = COALESCE(NULLIF(p_ifsc_code, ''), ifsc_code),
        pan_number = COALESCE(NULLIF(p_pan_number, ''), pan_number),
        updated_at = NOW()
    WHERE id = p_staff_id AND school_id = p_school_id;

    RETURN jsonb_build_object(
        'success', true,
        'structure_id', v_struct_id,
        'staff_id', p_staff_id,
        'staff_name', v_staff_name,
        'gross_salary', v_gross,
        'total_deductions', v_total_deductions,
        'net_salary', v_net,
        'message', 'Salary structure saved and profile credentials synchronized successfully.'
    );
END;
$$;

-- Step 4: Refined fn_staff_salary_structures_catalog (Strictly Configured Structures + Profile SSOT)
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
            COALESCE(p.designation, p.role, 'Faculty Member') AS designation,
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
            COALESCE(struct.bank_name, p.bank_name, 'HDFC Bank') AS bank_name,
            COALESCE(struct.account_number, p.account_number, '') AS account_number,
            COALESCE(struct.ifsc_code, p.ifsc_code, '') AS ifsc_code,
            COALESCE(struct.pan_number, p.pan_number, '') AS pan_number,
            COALESCE(struct.payment_mode, 'Direct Bank Transfer (NEFT/RTGS)') AS payment_mode,
            COALESCE(struct.status, 'ACTIVE') AS status,
            struct.updated_at
        FROM public.staff_salary_structures struct
        INNER JOIN public.profiles p 
            ON struct.staff_id = p.id AND struct.school_id = p.school_id
        WHERE struct.school_id = p_school_id 
          AND p.role != 'student'
          AND (p_department IS NULL OR p_department IN ('All Departments', 'All', '') OR p.department = p_department)
          AND (p_search IS NULL OR p_search = '' OR (
              p.full_name ILIKE '%' || p_search || '%' OR
              p.employee_id ILIKE '%' || p_search || '%' OR
              p.department ILIKE '%' || p_search || '%' OR
              p.designation ILIKE '%' || p_search || '%' OR
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
                    'role', sp.role_title,
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
                    'bank_name', sp.bank_name,
                    'account_number', sp.account_number,
                    'ifsc_code', sp.ifsc_code,
                    'pan_number', sp.pan_number,
                    'payment_mode', sp.payment_mode,
                    'status', sp.status,
                    'updated_at', sp.updated_at
                )
            ),
            '[]'::jsonb
        )
    INTO v_total_items, v_structures
    FROM sorted_page sp;

    v_total_items := COALESCE(v_total_items, 0);
    v_total_pages := GREATEST(1, CEIL(v_total_items::NUMERIC / v_clean_size));

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

-- Step 5: Automated Monthly Payroll Run Engine (Batch Payslip Generation & Advance FIFO Recovery)
CREATE OR REPLACE FUNCTION public.fn_auto_generate_monthly_payroll_payslips(
    p_school_id UUID,
    p_month_str TEXT,
    p_payment_mode TEXT DEFAULT 'Direct Bank Transfer (NEFT/RTGS)',
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_month_str TEXT := TRIM(p_month_str);
    v_year INT;
    v_month INT;
    v_rec RECORD;
    v_generated_count INT := 0;
    v_already_processed_count INT := 0;
    v_total_eligible INT := 0;
    v_total_gross_disbursed NUMERIC(12,2) := 0.0;
    v_total_net_disbursed NUMERIC(12,2) := 0.0;
    v_generated_payslips JSONB := '[]'::jsonb;
    v_ps_num TEXT;
    v_seq_num INT := 1;
    v_txn_ref TEXT;
    v_adv RECORD;
    v_adv_deduction NUMERIC(12,2);
    v_remaining_deduction NUMERIC(12,2);
    v_alloc NUMERIC(12,2);
    v_gross NUMERIC(12,2);
    v_total_ded NUMERIC(12,2);
    v_net NUMERIC(12,2);
BEGIN
    IF v_clean_month_str ~ '^\d{4}-\d{2}$' THEN
        v_year := SUBSTRING(v_clean_month_str FROM 1 FOR 4)::INT;
        v_month := SUBSTRING(v_clean_month_str FROM 6 FOR 2)::INT;
    ELSE
        v_clean_month_str := TO_CHAR(CURRENT_DATE, 'YYYY-MM');
        v_year := EXTRACT(YEAR FROM CURRENT_DATE)::INT;
        v_month := EXTRACT(MONTH FROM CURRENT_DATE)::INT;
    END IF;

    -- Sequence base for payslips
    SELECT COALESCE(MAX(SUBSTRING(payslip_number FROM 'PS-\d{4}-\d{2}-(\d+)')::INT), 0) + 1
    INTO v_seq_num
    FROM public.staff_salary_payouts
    WHERE school_id = p_school_id AND month_str = v_clean_month_str;

    -- Loop through all active staff salary structures
    FOR v_rec IN (
        SELECT 
            s.staff_id,
            p.full_name,
            COALESCE(p.email, '') AS email,
            COALESCE(p.employee_id, 'EMP-' || SUBSTRING(p.id::text, 1, 6)) AS employee_id,
            COALESCE(p.department, 'Academic & Teaching') AS department,
            COALESCE(p.designation, p.role, 'Faculty Member') AS designation,
            s.basic_pay,
            s.hra,
            s.da,
            s.ta,
            s.special_allowance,
            s.medical_allowance,
            s.gross_salary,
            s.pf_deduction,
            s.tds,
            s.professional_tax,
            s.insurance_deduction,
            COALESCE(s.bank_name, p.bank_name, 'HDFC Bank') AS bank_name,
            COALESCE(s.account_number, p.account_number, '') AS account_number,
            COALESCE(s.ifsc_code, p.ifsc_code, '') AS ifsc_code,
            COALESCE(s.pan_number, p.pan_number, '') AS pan_number,
            COALESCE(s.payment_mode, p_payment_mode) AS payment_mode
        FROM public.staff_salary_structures s
        INNER JOIN public.profiles p ON s.staff_id = p.id AND s.school_id = p.school_id
        WHERE s.school_id = p_school_id
          AND s.status = 'ACTIVE'
          AND p.role != 'student'
        ORDER BY p.full_name ASC
    ) LOOP
        v_total_eligible := v_total_eligible + 1;

        -- Check if payout already exists for this staff in target month
        IF EXISTS (
            SELECT 1 FROM public.staff_salary_payouts
            WHERE school_id = p_school_id 
              AND staff_id = v_rec.staff_id 
              AND month_str = v_clean_month_str
        ) THEN
            v_already_processed_count := v_already_processed_count + 1;
            CONTINUE;
        END IF;

        -- Check for any active advances with outstanding balance
        v_adv_deduction := 0.0;
        SELECT COALESCE(SUM(monthly_deduction), 0.0)
        INTO v_adv_deduction
        FROM public.staff_salary_advances
        WHERE school_id = p_school_id 
          AND staff_id = v_rec.staff_id 
          AND status = 'Approved' 
          AND (amount - COALESCE(amount_repaid, 0.0)) > 0;

        -- Calculate earnings & deductions
        v_gross := v_rec.gross_salary;
        v_total_ded := v_rec.pf_deduction + v_rec.tds + v_rec.professional_tax + 
                       v_rec.insurance_deduction + v_adv_deduction;
        v_net := GREATEST(0.0, v_gross - v_total_ded);

        v_ps_num := 'PS-' || v_clean_month_str || '-' || LPAD(v_seq_num::TEXT, 4, '0');
        v_txn_ref := 'BATCH-PAY-' || v_clean_month_str || '-' || LPAD(v_seq_num::TEXT, 4, '0');
        v_seq_num := v_seq_num + 1;

        -- Create payout record
        INSERT INTO public.staff_salary_payouts (
            school_id,
            staff_id,
            payslip_number,
            month,
            year,
            month_str,
            basic_pay,
            hra,
            da,
            ta,
            special_allowance,
            bonus,
            gross_earnings,
            pf_deduction,
            tds,
            professional_tax,
            advance_deduction,
            other_deductions,
            total_deductions,
            net_pay,
            payment_status,
            payment_date,
            payment_mode,
            transaction_reference,
            remarks,
            processed_by,
            bank_name,
            account_number,
            ifsc_code,
            pan_number,
            bonus_type,
            bonus_remarks,
            other_deductions_remarks,
            created_at,
            updated_at
        ) VALUES (
            p_school_id,
            v_rec.staff_id,
            v_ps_num,
            v_month,
            v_year,
            v_clean_month_str,
            v_rec.basic_pay,
            v_rec.hra,
            v_rec.da,
            v_rec.ta,
            v_rec.special_allowance,
            0.0,
            v_gross,
            v_rec.pf_deduction,
            v_rec.tds,
            v_rec.professional_tax,
            v_adv_deduction,
            v_rec.insurance_deduction,
            v_total_ded,
            v_net,
            'Paid',
            NOW(),
            v_rec.payment_mode,
            v_txn_ref,
            'Automated institutional batch payroll run for ' || v_clean_month_str,
            p_user_id,
            v_rec.bank_name,
            v_rec.account_number,
            v_rec.ifsc_code,
            v_rec.pan_number,
            'NONE',
            NULL,
            NULL,
            NOW(),
            NOW()
        );

        -- Apply FIFO advance recovery if advance deduction was made
        IF v_adv_deduction > 0 THEN
            v_remaining_deduction := v_adv_deduction;
            FOR v_adv IN (
                SELECT id, amount, COALESCE(amount_repaid, 0.0) AS repaid,
                       (amount - COALESCE(amount_repaid, 0.0)) AS balance
                FROM public.staff_salary_advances
                WHERE school_id = p_school_id 
                  AND staff_id = v_rec.staff_id 
                  AND status = 'Approved' 
                  AND (amount - COALESCE(amount_repaid, 0.0)) > 0
                ORDER BY created_at ASC
            ) LOOP
                IF v_remaining_deduction <= 0 THEN
                    EXIT;
                END IF;

                v_alloc := LEAST(v_remaining_deduction, v_adv.balance);
                UPDATE public.staff_salary_advances
                SET amount_repaid = amount_repaid + v_alloc,
                    status = CASE WHEN (amount_repaid + v_alloc) >= amount THEN 'Recovered' ELSE 'Approved' END,
                    updated_at = NOW()
                WHERE id = v_adv.id;

                v_remaining_deduction := v_remaining_deduction - v_alloc;
            END LOOP;
        END IF;

        v_generated_count := v_generated_count + 1;
        v_total_gross_disbursed := v_total_gross_disbursed + v_gross;
        v_total_net_disbursed := v_total_net_disbursed + v_net;

        -- Record for client email notification trigger
        v_generated_payslips := v_generated_payslips || jsonb_build_object(
            'staff_id', v_rec.staff_id,
            'staff_name', v_rec.full_name,
            'email', v_rec.email,
            'employee_id', v_rec.employee_id,
            'department', v_rec.department,
            'designation', v_rec.designation,
            'payslip_number', v_ps_num,
            'month_str', v_clean_month_str,
            'basic_pay', v_rec.basic_pay,
            'hra', v_rec.hra,
            'da', v_rec.da,
            'ta', v_rec.ta,
            'special_allowance', v_rec.special_allowance,
            'gross_earnings', v_gross,
            'pf_deduction', v_rec.pf_deduction,
            'tds', v_rec.tds,
            'professional_tax', v_rec.professional_tax,
            'advance_deduction', v_adv_deduction,
            'total_deductions', v_total_ded,
            'net_pay', v_net,
            'bank_name', v_rec.bank_name,
            'account_number', v_rec.account_number,
            'ifsc_code', v_rec.ifsc_code,
            'pan_number', v_rec.pan_number,
            'transaction_reference', v_txn_ref
        );
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'month_str', v_clean_month_str,
        'eligible_count', v_total_eligible,
        'already_processed_count', v_already_processed_count,
        'generated_count', v_generated_count,
        'total_gross_disbursed', v_total_gross_disbursed,
        'total_net_disbursed', v_total_net_disbursed,
        'payslips_generated', v_generated_payslips,
        'message', 'Automated monthly payroll run completed successfully. ' || 
                   v_generated_count || ' payslips generated, ' || 
                   v_already_processed_count || ' were already processed.'
    );
END;
$$;

-- Step 6: Update fn_create_staff_salary_structure to use fn_save_staff_salary_structure and sync profiles
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
BEGIN
    RETURN public.fn_save_staff_salary_structure(
        p_school_id,
        p_staff_id,
        p_basic_pay,
        p_hra,
        p_da,
        p_ta,
        p_special,
        p_medical,
        p_pf,
        p_tds,
        p_ptax,
        p_insurance,
        p_payment_mode,
        p_bank_name,
        p_account_number,
        p_ifsc,
        p_pan
    );
END;
$$;

