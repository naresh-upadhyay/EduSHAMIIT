-- ============================================================================
-- Migration 410: Fix Bulk Invoice Generation, Fee Reminders, and Parity for Export
-- Author: Senior Enterprise Architect
-- Date: 2026-11-04
-- Context: 
--   1. Bulk invoice generation must scope strictly to current academic year (2026 - 2027)
--      and support targeted student_ids filter so non-visible students are never invoiced.
--   2. Line items automatically sync with student-assigned fee heads (hostel_student_fee_heads).
--   3. Invoice creation respects Over Paid balance mathematics.
-- ============================================================================

-- 1. Enhanced Single Invoice Procedure with Dynamic Fee Heads & Overpaid Support
CREATE OR REPLACE FUNCTION public.fn_hostel_generate_invoice(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student_id UUID := (p_data->>'student_id')::UUID;
    v_billing_period VARCHAR := COALESCE(p_data->>'billing_period', p_data->>'title', TO_CHAR(CURRENT_DATE, 'Month YYYY'));
    v_academic_year VARCHAR := COALESCE(p_data->>'academic_year', '2026 - 2027');
    v_due_date DATE := COALESCE((p_data->>'due_date')::DATE, CURRENT_DATE + INTERVAL '15 days');
    v_gross_amount NUMERIC(12,2) := (p_data->>'gross_amount')::NUMERIC;
    v_discount NUMERIC(12,2) := COALESCE((p_data->>'discount_amount')::NUMERIC, 0.00);
    v_net_amount NUMERIC(12,2);
    v_invoice_id UUID;
    v_invoice_number VARCHAR;
    v_fee_plan_id UUID := (p_data->>'fee_plan_id')::UUID;
    v_cur_balance NUMERIC(12,2) := 0;
    v_items JSONB := p_data->'items';
    v_item JSONB;
    v_head_rec RECORD;
    v_has_custom_heads BOOLEAN := FALSE;
    v_calc_heads_gross NUMERIC(12,2) := 0;
BEGIN
    -- Ensure p_user_id exists in profiles or fallback to a valid user in school
    IF p_user_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
        SELECT id INTO p_user_id FROM public.profiles WHERE school_id = p_school_id ORDER BY created_at ASC LIMIT 1;
    END IF;

    -- Check if active invoice already exists for this billing period
    IF EXISTS (
        SELECT 1 FROM public.hostel_invoices
        WHERE school_id = p_school_id 
          AND student_id = v_student_id 
          AND billing_period = v_billing_period 
          AND deleted_at IS NULL 
          AND status NOT IN ('CANCELLED', 'VOID')
    ) THEN
        RETURN jsonb_build_object(
            'success', FALSE, 
            'message', 'An invoice already exists for this student for period ' || v_billing_period
        );
    END IF;

    -- Derive fee plan from student account or fee plans if not provided
    IF v_fee_plan_id IS NULL THEN
        SELECT acc.fee_plan_id
        INTO v_fee_plan_id 
        FROM public.hostel_student_accounts acc
        WHERE acc.school_id = p_school_id 
          AND acc.student_id = v_student_id 
          AND acc.academic_year = v_academic_year
        LIMIT 1;

        IF v_fee_plan_id IS NULL THEN
            SELECT fp.id INTO v_fee_plan_id
            FROM public.hostel_fee_plans fp
            JOIN public.hostel_admissions adm ON (adm.fee_plan ILIKE '%' || fp.billing_cycle || '%' OR adm.fee_plan ILIKE '%' || fp.name || '%')
            WHERE adm.school_id = p_school_id 
              AND adm.student_id = v_student_id 
              AND adm.academic_year = v_academic_year
            LIMIT 1;
        END IF;
    END IF;

    -- Check if student has assigned fee heads in hostel_student_fee_heads
    SELECT COUNT(*) > 0, COALESCE(SUM(amount), 0)
    INTO v_has_custom_heads, v_calc_heads_gross
    FROM public.hostel_student_fee_heads
    WHERE school_id = p_school_id AND student_id = v_student_id;

    -- Determine gross amount
    IF v_gross_amount IS NULL OR v_gross_amount <= 0 THEN
        IF v_has_custom_heads AND v_calc_heads_gross > 0 THEN
            v_gross_amount := v_calc_heads_gross;
        ELSE
            SELECT COALESCE(adm.monthly_fee, 6000.00)
            INTO v_gross_amount
            FROM public.hostel_admissions adm
            WHERE adm.school_id = p_school_id 
              AND adm.student_id = v_student_id 
              AND adm.academic_year = v_academic_year
              AND adm.deleted_at IS NULL
            LIMIT 1;
            
            IF v_gross_amount IS NULL OR v_gross_amount <= 0 THEN
                v_gross_amount := 6000.00;
            END IF;
        END IF;
    END IF;

    v_net_amount := GREATEST(0, v_gross_amount - v_discount);
    v_invoice_number := 'HINV-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 9000 + 1000)::TEXT, 4, '0');

    -- Insert Invoice Master Record
    INSERT INTO public.hostel_invoices (
        school_id, academic_year, student_id, fee_plan_id, invoice_number,
        billing_period, invoice_date, due_date, gross_amount, discount_amount,
        net_amount, paid_amount, balance_amount, status, created_by
    ) VALUES (
        p_school_id, v_academic_year, v_student_id, v_fee_plan_id, v_invoice_number,
        v_billing_period, CURRENT_DATE, v_due_date, v_gross_amount, v_discount,
        v_net_amount, 0.00, v_net_amount, 'GENERATED', p_user_id
    ) RETURNING id INTO v_invoice_id;

    -- Insert invoice line items
    IF v_items IS NOT NULL AND jsonb_typeof(v_items) = 'array' AND jsonb_array_length(v_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_items)
        LOOP
            INSERT INTO public.hostel_invoice_items (
                invoice_id, fee_head_code, fee_head_name, amount, discount_amount, net_amount
            ) VALUES (
                v_invoice_id,
                COALESCE(v_item->>'fee_head_code', 'CUSTOM_FEE'),
                COALESCE(v_item->>'head_name', v_item->>'fee_head_name', 'Hostel Fee Head'),
                (v_item->>'amount')::NUMERIC,
                COALESCE((v_item->>'discount_amount')::NUMERIC, 0.00),
                COALESCE((v_item->>'net_amount')::NUMERIC, (v_item->>'amount')::NUMERIC)
            );
        END LOOP;
    ELSIF v_has_custom_heads THEN
        -- Insert from student's assigned fee heads
        FOR v_head_rec IN 
            SELECT head_name, amount, is_mandatory
            FROM public.hostel_student_fee_heads
            WHERE school_id = p_school_id AND student_id = v_student_id
            ORDER BY created_at ASC
        LOOP
            INSERT INTO public.hostel_invoice_items (
                invoice_id, fee_head_code, fee_head_name, amount, discount_amount, net_amount
            ) VALUES (
                v_invoice_id,
                UPPER(REPLACE(v_head_rec.head_name, ' ', '_')),
                v_head_rec.head_name,
                v_head_rec.amount,
                0.00,
                v_head_rec.amount
            );
        END LOOP;
    ELSE
        -- Default line items breakdown
        INSERT INTO public.hostel_invoice_items (invoice_id, fee_head_code, fee_head_name, amount, discount_amount, net_amount)
        VALUES 
            (v_invoice_id, 'ROOM_FEE', 'Hostel Room Accommodation', ROUND(v_net_amount * 0.60, 2), 0, ROUND(v_net_amount * 0.60, 2)),
            (v_invoice_id, 'MESS_FEE', 'Mess & Dining Charges', ROUND(v_net_amount * 0.30, 2), 0, ROUND(v_net_amount * 0.30, 2)),
            (v_invoice_id, 'UTILITIES_FEE', 'Electricity & Utilities', ROUND(v_net_amount * 0.10, 2), 0, ROUND(v_net_amount * 0.10, 2));
    END IF;

    -- Update running ledger with strict non-null safety
    SELECT COALESCE(running_balance, 0.00) INTO v_cur_balance
    FROM public.hostel_fee_ledger
    WHERE school_id = p_school_id AND student_id = v_student_id
    ORDER BY transaction_date DESC, created_at DESC LIMIT 1;

    IF v_cur_balance IS NULL THEN
        v_cur_balance := 0.00;
    END IF;

    v_cur_balance := v_cur_balance + v_net_amount;

    INSERT INTO public.hostel_fee_ledger (
        school_id, student_id, entry_type, reference_id, reference_number,
        debit, credit, running_balance, description, transaction_date, created_by
    ) VALUES (
        p_school_id, v_student_id, 'INVOICE', v_invoice_id, v_invoice_number,
        v_net_amount, 0.00, v_cur_balance,
        'Hostel Invoice Generated for ' || v_billing_period || ' (' || v_invoice_number || ')',
        NOW(), p_user_id
    );

    -- Ensure hostel_student_accounts exists and update with proper Over Paid mathematics
    INSERT INTO public.hostel_student_accounts (
        id, school_id, student_id, academic_year, fee_plan_id, fee_plan_name,
        total_billed, total_paid, total_due, total_overdue, payment_status, next_due_date
    ) VALUES (
        gen_random_uuid(), p_school_id, v_student_id, v_academic_year, v_fee_plan_id, 'Monthly',
        v_net_amount, 0.00, v_net_amount, 0.00, 'PENDING', v_due_date
    )
    ON CONFLICT (school_id, student_id, academic_year) DO UPDATE
    SET total_billed = public.hostel_student_accounts.total_billed + v_net_amount,
        total_due = GREATEST(0.00, (public.hostel_student_accounts.total_billed + v_net_amount) - public.hostel_student_accounts.total_paid),
        payment_status = CASE 
            WHEN public.hostel_student_accounts.total_paid > (public.hostel_student_accounts.total_billed + v_net_amount) THEN 'OVERPAID'
            WHEN public.hostel_student_accounts.total_paid = (public.hostel_student_accounts.total_billed + v_net_amount) THEN 'PAID'
            WHEN public.hostel_student_accounts.total_paid > 0 THEN 'PARTIAL'
            ELSE 'PENDING'
        END,
        next_due_date = v_due_date,
        updated_at = NOW();

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Invoice generated successfully',
        'data', jsonb_build_object(
            'invoice_id', v_invoice_id,
            'invoice_number', v_invoice_number,
            'net_amount', v_net_amount,
            'billing_period', v_billing_period
        )
    );
END;
$$;


-- 2. Enhanced Bulk Invoice Generation Procedure with Student Filtering & Year Scoping
CREATE OR REPLACE FUNCTION public.fn_hostel_bulk_generate_invoices(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_hostel_id UUID := (p_data->>'hostel_id')::UUID;
    v_billing_period VARCHAR := COALESCE(p_data->>'billing_period', p_data->>'title', TO_CHAR(CURRENT_DATE, 'Month YYYY'));
    v_academic_year VARCHAR := COALESCE(p_data->>'academic_year', '2026 - 2027');
    v_due_date DATE := COALESCE((p_data->>'due_date')::DATE, CURRENT_DATE + INTERVAL '15 days');
    v_student_rec RECORD;
    v_created_count INT := 0;
    v_skipped_count INT := 0;
    v_target_students UUID[];
    v_invoices JSONB := '[]'::JSONB;
    v_inv_res JSONB;
BEGIN
    -- Check if specific target student IDs or admission IDs are passed
    IF p_data ? 'student_ids' AND jsonb_array_length(p_data->'student_ids') > 0 THEN
        SELECT ARRAY_AGG((elem)::UUID)
        INTO v_target_students
        FROM jsonb_array_elements_text(p_data->'student_ids') elem;
    END IF;

    FOR v_student_rec IN 
        SELECT a.student_id, a.id as admission_id, a.monthly_fee, p.full_name as student_name
        FROM public.hostel_admissions a
        JOIN public.profiles p ON a.student_id = p.id
        WHERE a.school_id = p_school_id
          AND a.academic_year = v_academic_year
          AND a.admission_status = 'ACTIVE'
          AND a.deleted_at IS NULL
          AND (v_hostel_id IS NULL OR a.hostel_id = v_hostel_id)
          AND (
              v_target_students IS NULL 
              OR a.student_id = ANY(v_target_students) 
              OR a.id = ANY(v_target_students)
          )
        ORDER BY p.full_name ASC
    LOOP
        -- Check if already invoiced for this billing period
        IF EXISTS (
            SELECT 1 FROM public.hostel_invoices
            WHERE school_id = p_school_id
              AND student_id = v_student_rec.student_id
              AND billing_period = v_billing_period
              AND deleted_at IS NULL
              AND status NOT IN ('CANCELLED', 'VOID')
        ) THEN
            v_skipped_count := v_skipped_count + 1;
        ELSE
            SELECT public.fn_hostel_generate_invoice(
                p_school_id, p_user_id,
                jsonb_build_object(
                    'student_id', v_student_rec.student_id,
                    'billing_period', v_billing_period,
                    'academic_year', v_academic_year,
                    'due_date', v_due_date,
                    'gross_amount', COALESCE(v_student_rec.monthly_fee, 6000.00),
                    'fee_plan_id', p_data->>'fee_plan_id'
                )
            ) INTO v_inv_res;

            IF (v_inv_res->>'success')::BOOLEAN IS TRUE THEN
                v_created_count := v_created_count + 1;
                v_invoices := v_invoices || jsonb_build_object(
                    'student_id', v_student_rec.student_id,
                    'student_name', v_student_rec.student_name,
                    'invoice_id', v_inv_res->'data'->>'invoice_id',
                    'invoice_number', v_inv_res->'data'->>'invoice_number',
                    'net_amount', v_inv_res->'data'->>'net_amount'
                );
            ELSE
                v_skipped_count := v_skipped_count + 1;
            END IF;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Bulk invoice generation completed for ' || v_academic_year || '. Created: ' || v_created_count || ', Skipped: ' || v_skipped_count,
        'created_count', v_created_count,
        'skipped_count', v_skipped_count,
        'academic_year', v_academic_year,
        'invoices', v_invoices
    );
END;
$$;
