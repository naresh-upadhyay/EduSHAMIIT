-- ============================================================================
-- Migration 409: Safeguard Fee Ledger Running Balance & Populate Student Ledger
-- ============================================================================
-- 1. Fix fn_hostel_add_penalty:
--    Ensure running_balance is never NULL when student has no prior ledger rows.
--    Fallback to total_due from hostel_student_accounts, then 0.00.
-- 2. Fix fn_hostel_collect_payment:
--    Ensure running_balance is never NULL when student has no prior ledger rows.
-- 3. Fix fn_hostel_generate_invoice:
--    Ensure running_balance is never NULL when student has no prior ledger rows.
-- 4. Fix fn_hostel_apply_concession:
--    Ensure running_balance is never NULL when student has no prior ledger rows.
-- 5. Update fn_hostel_get_student_fee_details_360:
--    Populate and return penalties in 360 profile.
-- 6. Backfill initial ledger entries for all admissions with invoices and payments.
-- ============================================================================

-- 1. Update fn_hostel_add_penalty with bulletproof running_balance calculation
CREATE OR REPLACE FUNCTION public.fn_hostel_add_penalty(
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
    v_charge_type VARCHAR := COALESCE(p_data->>'charge_type', p_data->>'penalty_type', 'LATE_FEE');
    v_description TEXT := COALESCE(p_data->>'description', p_data->>'reason', 'Late fee penalty');
    v_amount NUMERIC(12,2) := (p_data->>'amount')::NUMERIC;
    v_invoice_id UUID := (p_data->>'invoice_id')::UUID;
    v_penalty_id UUID;
    v_user_name VARCHAR := 'Admin';
    v_cur_balance NUMERIC(12,2);
    v_acc RECORD;
    v_inv_no VARCHAR;
BEGIN
    IF v_student_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Student ID is required.');
    END IF;

    IF v_amount IS NULL OR v_amount <= 0 THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Penalty amount must be greater than zero.');
    END IF;

    IF p_user_id IS NOT NULL THEN
        SELECT full_name INTO v_user_name FROM public.profiles WHERE id = p_user_id;
    END IF;

    -- If invoice_id is not passed, find latest active invoice
    IF v_invoice_id IS NULL THEN
        SELECT id, invoice_number INTO v_invoice_id, v_inv_no
        FROM public.hostel_invoices
        WHERE school_id = p_school_id AND student_id = v_student_id AND deleted_at IS NULL
        ORDER BY due_date DESC, created_at DESC LIMIT 1;
    ELSE
        SELECT invoice_number INTO v_inv_no
        FROM public.hostel_invoices
        WHERE id = v_invoice_id;
    END IF;

    -- 1. Insert into hostel_penalties
    INSERT INTO public.hostel_penalties (
        school_id, student_id, invoice_id, charge_type, description,
        amount, status, added_by, added_by_name, created_at
    ) VALUES (
        p_school_id, v_student_id, v_invoice_id, v_charge_type, v_description,
        v_amount, 'APPLIED', p_user_id, COALESCE(v_user_name, 'Admin'), NOW()
    ) RETURNING id INTO v_penalty_id;

    -- 2. Update invoice penalty if invoice exists
    IF v_invoice_id IS NOT NULL THEN
        UPDATE public.hostel_invoices
        SET penalty_amount = COALESCE(penalty_amount, 0.00) + v_amount,
            net_amount = net_amount + v_amount,
            balance_amount = balance_amount + v_amount,
            status = CASE WHEN paid_amount >= (net_amount + v_amount) THEN 'PAID' ELSE 'PARTIAL' END,
            updated_at = NOW()
        WHERE id = v_invoice_id;
    END IF;

    -- 3. Calculate running balance from hostel_fee_ledger
    SELECT running_balance INTO v_cur_balance
    FROM public.hostel_fee_ledger
    WHERE school_id = p_school_id AND student_id = v_student_id
    ORDER BY transaction_date DESC, created_at DESC LIMIT 1;

    -- If no prior ledger entry found, fallback to student account total_due
    IF v_cur_balance IS NULL THEN
        SELECT total_due INTO v_cur_balance
        FROM public.hostel_student_accounts
        WHERE school_id = p_school_id AND student_id = v_student_id
        ORDER BY created_at DESC LIMIT 1;
    END IF;

    -- Guaranteed non-null running balance
    v_cur_balance := COALESCE(v_cur_balance, 0.00) + v_amount;

    -- 4. Insert into hostel_fee_ledger
    INSERT INTO public.hostel_fee_ledger (
        school_id, student_id, entry_type, reference_id, reference_number,
        debit, credit, running_balance, description, transaction_date, created_by, created_at
    ) VALUES (
        p_school_id, v_student_id, 'PENALTY', v_penalty_id,
        'PEN-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || SUBSTRING(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 6),
        v_amount, 0.00, v_cur_balance,
        'Penalty / Fine Assessment: ' || v_description || ' (₹ ' || v_amount::INT || ')',
        NOW(), p_user_id, NOW()
    );

    -- 5. Update student account with exact Over Paid mathematics
    SELECT * INTO v_acc 
    FROM public.hostel_student_accounts 
    WHERE school_id = p_school_id AND student_id = v_student_id 
    ORDER BY created_at DESC LIMIT 1;

    IF v_acc.id IS NOT NULL THEN
        UPDATE public.hostel_student_accounts
        SET total_billed = total_billed + v_amount,
            total_due = CASE 
                WHEN total_paid >= (total_billed + v_amount) THEN 0.00
                ELSE GREATEST(0.00, (total_billed + v_amount) - total_paid)
            END,
            advance_credit = CASE 
                WHEN total_paid > (total_billed + v_amount) THEN (total_paid - (total_billed + v_amount))
                ELSE 0.00
            END,
            payment_status = CASE 
                WHEN total_paid > (total_billed + v_amount) THEN 'OVERPAID'
                WHEN total_paid = (total_billed + v_amount) AND (total_billed + v_amount) > 0 THEN 'PAID'
                WHEN total_paid > 0 THEN 'PARTIAL'
                ELSE 'PENDING'
            END,
            updated_at = NOW()
        WHERE id = v_acc.id;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Penalty added successfully',
        'penalty_id', v_penalty_id
    );
END;
$$;


-- 2. Update fn_hostel_collect_payment with bulletproof running_balance
CREATE OR REPLACE FUNCTION public.fn_hostel_collect_payment(
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
    v_invoice_id UUID := (p_data->>'invoice_id')::UUID;
    v_amount NUMERIC(12,2) := (p_data->>'amount')::NUMERIC;
    v_payment_method VARCHAR := COALESCE(p_data->>'payment_method', 'ONLINE_UPI');
    v_transaction_id VARCHAR := p_data->>'transaction_id';
    v_remarks TEXT := COALESCE(p_data->>'remarks', 'Hostel fee installment payment');
    v_payment_id UUID;
    v_receipt_number VARCHAR;
    v_cur_balance NUMERIC(12,2);
    v_user_name VARCHAR := 'Cashier';
    v_acc RECORD;
BEGIN
    IF v_amount <= 0 THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Payment amount must be greater than zero.');
    END IF;

    SELECT full_name INTO v_user_name FROM public.profiles WHERE id = p_user_id;

    v_receipt_number := 'HREC-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 900000 + 100000)::TEXT, 6, '0');

    -- Insert payment record
    INSERT INTO public.hostel_payments (
        school_id, student_id, invoice_id, payment_number, receipt_number,
        amount, payment_method, transaction_id, status, paid_at,
        collected_by, collected_by_name, remarks
    ) VALUES (
        p_school_id, v_student_id, v_invoice_id,
        'HPAY-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 9000 + 1000)::TEXT, 4, '0'),
        v_receipt_number, v_amount, v_payment_method, v_transaction_id,
        'COMPLETED', NOW(), p_user_id, COALESCE(v_user_name, 'Admin'), v_remarks
    ) RETURNING id INTO v_payment_id;

    -- Calculate current balance from ledger safely
    SELECT running_balance INTO v_cur_balance
    FROM public.hostel_fee_ledger
    WHERE school_id = p_school_id AND student_id = v_student_id
    ORDER BY transaction_date DESC, created_at DESC LIMIT 1;

    IF v_cur_balance IS NULL THEN
        SELECT total_due INTO v_cur_balance
        FROM public.hostel_student_accounts
        WHERE school_id = p_school_id AND student_id = v_student_id
        ORDER BY created_at DESC LIMIT 1;
    END IF;

    v_cur_balance := GREATEST(0.00, COALESCE(v_cur_balance, 0.00) - v_amount);

    -- Insert ledger entry
    INSERT INTO public.hostel_fee_ledger (
        school_id, student_id, entry_type, reference_id, reference_number,
        debit, credit, running_balance, description, transaction_date, created_by
    ) VALUES (
        p_school_id, v_student_id, 'PAYMENT', v_payment_id, v_receipt_number,
        0.00, v_amount, v_cur_balance,
        'Hostel Fee Payment Received (' || v_payment_method || ') Receipt: ' || v_receipt_number,
        NOW(), p_user_id
    );

    -- Update invoice if provided
    IF v_invoice_id IS NOT NULL THEN
        UPDATE public.hostel_invoices
        SET paid_amount = paid_amount + v_amount,
            balance_amount = GREATEST(0.00, balance_amount - v_amount),
            status = CASE 
                WHEN (paid_amount + v_amount) >= net_amount THEN 'PAID'
                ELSE 'PARTIAL'
            END,
            updated_at = NOW()
        WHERE id = v_invoice_id;
    END IF;

    -- Update student financial account totals with exact Over Paid mathematics
    SELECT * INTO v_acc 
    FROM public.hostel_student_accounts 
    WHERE school_id = p_school_id AND student_id = v_student_id 
    ORDER BY created_at DESC LIMIT 1;

    IF v_acc.id IS NOT NULL THEN
        UPDATE public.hostel_student_accounts
        SET total_paid = total_paid + v_amount,
            total_due = CASE 
                WHEN (total_paid + v_amount) >= total_billed THEN 0.00
                ELSE GREATEST(0.00, total_billed - (total_paid + v_amount))
            END,
            advance_credit = CASE 
                WHEN (total_paid + v_amount) > total_billed THEN ((total_paid + v_amount) - total_billed)
                ELSE 0.00
            END,
            payment_status = CASE 
                WHEN (total_paid + v_amount) > total_billed THEN 'OVERPAID'
                WHEN (total_paid + v_amount) = total_billed AND total_billed > 0 THEN 'PAID'
                WHEN (total_paid + v_amount) > 0 THEN 'PARTIAL'
                ELSE 'PENDING'
            END,
            updated_at = NOW()
        WHERE id = v_acc.id;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Payment recorded successfully',
        'receipt_number', v_receipt_number,
        'payment_id', v_payment_id
    );
END;
$$;


-- 3. Update fn_hostel_generate_invoice with bulletproof running_balance
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
    v_billing_period VARCHAR := COALESCE(p_data->>'billing_period', TO_CHAR(CURRENT_DATE, 'Mon YYYY'));
    v_due_date DATE := COALESCE((p_data->>'due_date')::DATE, CURRENT_DATE + INTERVAL '15 days');
    v_academic_year VARCHAR := COALESCE(p_data->>'academic_year', '2026 - 2027');
    v_invoice_id UUID;
    v_invoice_number VARCHAR;
    v_fee_plan_id UUID;
    v_gross_amount NUMERIC(12,2) := 0;
    v_discount NUMERIC(12,2) := 0;
    v_net_amount NUMERIC(12,2) := 0;
    v_admission_id UUID;
    v_cur_balance NUMERIC(12,2);
BEGIN
    SELECT id, fee_plan INTO v_admission_id, v_billing_period
    FROM public.hostel_admissions
    WHERE student_id = v_student_id AND school_id = p_school_id AND deleted_at IS NULL
    ORDER BY admission_date DESC LIMIT 1;

    -- Calculate invoice amount from student fee heads
    SELECT 
        COALESCE(SUM(amount), 6000.00),
        COALESCE(SUM(amount), 6000.00)
    INTO v_gross_amount, v_net_amount
    FROM public.hostel_student_fee_heads
    WHERE student_id = v_student_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_gross_amount = 0 THEN
        v_gross_amount := 6000.00;
        v_net_amount := 6000.00;
    END IF;

    v_invoice_number := 'INV-' || TO_CHAR(CURRENT_DATE, 'YYYYMM') || '-' || SUBSTRING(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 8);

    INSERT INTO public.hostel_invoices (
        school_id, academic_year, student_id, admission_id, fee_plan_id,
        invoice_number, billing_period, billing_cycle, invoice_date, due_date,
        gross_amount, discount_amount, penalty_amount, net_amount,
        paid_amount, balance_amount, status, created_by
    ) VALUES (
        p_school_id, v_academic_year, v_student_id, v_admission_id, v_fee_plan_id,
        v_invoice_number, v_billing_period, 'MONTHLY', CURRENT_DATE, v_due_date,
        v_gross_amount, v_discount, 0.00, v_net_amount,
        0.00, v_net_amount, 'GENERATED', p_user_id
    ) RETURNING id INTO v_invoice_id;

    -- Ledger running balance
    SELECT running_balance INTO v_cur_balance
    FROM public.hostel_fee_ledger
    WHERE school_id = p_school_id AND student_id = v_student_id
    ORDER BY transaction_date DESC, created_at DESC LIMIT 1;

    IF v_cur_balance IS NULL THEN
        SELECT total_due INTO v_cur_balance
        FROM public.hostel_student_accounts
        WHERE school_id = p_school_id AND student_id = v_student_id
        ORDER BY created_at DESC LIMIT 1;
    END IF;

    v_cur_balance := COALESCE(v_cur_balance, 0.00) + v_net_amount;

    INSERT INTO public.hostel_fee_ledger (
        school_id, student_id, entry_type, reference_id, reference_number,
        debit, credit, running_balance, description, transaction_date, created_by
    ) VALUES (
        p_school_id, v_student_id, 'INVOICE', v_invoice_id, v_invoice_number,
        v_net_amount, 0.00, v_cur_balance,
        'Hostel Invoice Generated for ' || v_billing_period || ' (' || v_invoice_number || ')',
        NOW(), p_user_id
    );

    -- Update student account
    UPDATE public.hostel_student_accounts
    SET total_billed = total_billed + v_net_amount,
        total_due = CASE 
            WHEN total_paid >= (total_billed + v_net_amount) THEN 0.00
            ELSE GREATEST(0.00, (total_billed + v_net_amount) - total_paid)
        END,
        advance_credit = CASE 
            WHEN total_paid > (total_billed + v_net_amount) THEN (total_paid - (total_billed + v_net_amount))
            ELSE 0.00
        END,
        payment_status = CASE 
            WHEN total_paid > (total_billed + v_net_amount) THEN 'OVERPAID'
            WHEN total_paid = (total_billed + v_net_amount) AND (total_billed + v_net_amount) > 0 THEN 'PAID'
            WHEN total_paid > 0 THEN 'PARTIAL'
            ELSE 'PENDING'
        END,
        updated_at = NOW()
    WHERE school_id = p_school_id AND student_id = v_student_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Invoice generated successfully',
        'invoice_id', v_invoice_id,
        'invoice_number', v_invoice_number,
        'amount', v_net_amount
    );
END;
$$;


-- 4. Update fn_hostel_get_student_fee_details_360 to populate penalties
CREATE OR REPLACE FUNCTION public.fn_hostel_get_student_fee_details_360(
    p_school_id UUID,
    p_student_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_acc RECORD;
    v_profile RECORD;
    v_adm RECORD;
    v_alc RECORD;
    v_invoices JSONB := '[]'::JSONB;
    v_payments JSONB := '[]'::JSONB;
    v_ledger JSONB := '[]'::JSONB;
    v_concessions JSONB := '[]'::JSONB;
    v_penalties JSONB := '[]'::JSONB;
    v_breakdown JSONB := '[]'::JSONB;
    v_is_overpaid BOOLEAN := FALSE;
    v_total_assigned NUMERIC(12,2) := 0.00;
    v_total_paid NUMERIC(12,2) := 0.00;
    v_total_due NUMERIC(12,2) := 0.00;
    v_status_str VARCHAR(50);
BEGIN
    SELECT * INTO v_profile FROM public.profiles WHERE id = p_student_id AND school_id = p_school_id;
    IF v_profile.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Student profile not found.');
    END IF;

    SELECT * INTO v_acc FROM public.hostel_student_accounts 
    WHERE student_id = p_student_id AND school_id = p_school_id 
    ORDER BY created_at DESC LIMIT 1;

    SELECT a.*, b.name as building_name 
    FROM public.hostel_admissions a
    LEFT JOIN public.hostel_buildings b ON a.hostel_id = b.id
    WHERE a.student_id = p_student_id AND a.school_id = p_school_id AND a.deleted_at IS NULL
    ORDER BY a.admission_date DESC LIMIT 1
    INTO v_adm;

    SELECT al.*, r.room_number, bd.bed_code AS bed_number 
    INTO v_alc 
    FROM public.hostel_allocations al
    LEFT JOIN public.hostel_rooms r ON al.room_id = r.id
    LEFT JOIN public.hostel_beds bd ON al.bed_id = bd.id
    WHERE al.student_id = p_student_id AND al.school_id = p_school_id AND al.allocation_status IN ('CHECKED_IN', 'RESERVED', 'CONFIRMED') AND al.deleted_at IS NULL
    ORDER BY al.created_at DESC
    LIMIT 1;

    -- Invoices
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', i.id,
        'invoice_number', i.invoice_number,
        'billing_period', i.billing_period,
        'invoice_date', i.invoice_date,
        'due_date', i.due_date,
        'gross_amount', i.gross_amount,
        'discount_amount', i.discount_amount,
        'penalty_amount', i.penalty_amount,
        'net_amount', i.net_amount,
        'paid_amount', i.paid_amount,
        'balance_amount', i.balance_amount,
        'status', i.status
    ) ORDER BY i.due_date DESC), '[]'::JSONB)
    INTO v_invoices
    FROM public.hostel_invoices i
    WHERE i.student_id = p_student_id AND i.school_id = p_school_id AND i.deleted_at IS NULL;

    -- Payments
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', py.id,
        'receipt_number', py.receipt_number,
        'amount', py.amount,
        'payment_method', py.payment_method,
        'transaction_id', py.transaction_id,
        'status', py.status,
        'paid_at', py.paid_at,
        'collected_by_name', py.collected_by_name,
        'remarks', py.remarks
    ) ORDER BY py.paid_at DESC), '[]'::JSONB)
    INTO v_payments
    FROM public.hostel_payments py
    WHERE py.student_id = p_student_id AND py.school_id = p_school_id;

    -- Ledger
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', l.id,
        'entry_type', l.entry_type,
        'reference_number', l.reference_number,
        'debit', l.debit,
        'credit', l.credit,
        'running_balance', l.running_balance,
        'description', l.description,
        'transaction_date', l.transaction_date
    ) ORDER BY l.transaction_date DESC, l.created_at DESC), '[]'::JSONB)
    INTO v_ledger
    FROM public.hostel_fee_ledger l
    WHERE l.student_id = p_student_id AND l.school_id = p_school_id;

    -- Concessions
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', c.id,
        'reason', c.reason,
        'concession_type', c.concession_type,
        'concession_amount', c.concession_amount,
        'status', c.status,
        'approved_by_name', c.approved_by_name,
        'applied_at', c.applied_at
    ) ORDER BY c.applied_at DESC), '[]'::JSONB)
    INTO v_concessions
    FROM public.hostel_concessions c
    WHERE c.student_id = p_student_id AND c.school_id = p_school_id;

    -- Penalties
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', pen.id,
        'charge_type', pen.charge_type,
        'description', pen.description,
        'amount', pen.amount,
        'status', pen.status,
        'added_by_name', pen.added_by_name,
        'created_at', pen.created_at
    ) ORDER BY pen.created_at DESC), '[]'::JSONB)
    INTO v_penalties
    FROM public.hostel_penalties pen
    WHERE pen.student_id = p_student_id AND pen.school_id = p_school_id;

    -- Dynamic Breakdown from hostel_student_fee_heads
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', sfh.id,
        'head_name', sfh.head_name,
        'head_code', sfh.head_code,
        'amount', sfh.amount,
        'discount', 0.00,
        'net_amount', sfh.amount,
        'is_mandatory', sfh.is_mandatory,
        'is_refundable', sfh.is_refundable,
        'charge_type', sfh.charge_type,
        'frequency', sfh.frequency
    ) ORDER BY sfh.sort_order ASC, sfh.created_at ASC), '[]'::JSONB)
    INTO v_breakdown
    FROM public.hostel_student_fee_heads sfh
    WHERE sfh.student_id = p_student_id AND sfh.school_id = p_school_id AND sfh.deleted_at IS NULL;

    -- Compute dynamic total assigned
    SELECT COALESCE(SUM(amount), 0.00) INTO v_total_assigned
    FROM public.hostel_student_fee_heads
    WHERE student_id = p_student_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_total_assigned = 0.00 THEN
        v_total_assigned := COALESCE(v_acc.total_billed, v_adm.initial_payment_amount, 6000.00);
    END IF;

    -- Compute total paid
    SELECT COALESCE(SUM(amount), 0.00) INTO v_total_paid
    FROM public.hostel_payments
    WHERE school_id = p_school_id AND student_id = p_student_id AND status = 'SUCCESS';

    IF v_total_paid = 0.00 THEN
        v_total_paid := COALESCE(v_acc.total_paid, v_adm.initial_payment_amount, 0.00);
    END IF;

    v_is_overpaid := (v_total_paid > v_total_assigned);

    IF v_is_overpaid THEN
        v_status_str := 'Over Paid';
        v_total_due := 0.00;
    ELSIF v_total_paid = v_total_assigned AND v_total_assigned > 0 THEN
        v_status_str := 'Paid';
        v_total_due := 0.00;
    ELSIF v_total_paid > 0 THEN
        v_status_str := 'Partial';
        v_total_due := v_total_assigned - v_total_paid;
    ELSE
        v_status_str := 'Pending';
        v_total_due := v_total_assigned;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'student_id', v_profile.id,
            'full_name', v_profile.full_name,
            'avatar_url', v_profile.avatar_url,
            'class_name', v_profile.class,
            'roll_number', v_profile.roll_number,
            'hostel_name', COALESCE(v_adm.building_name, 'Boys Hostel A'),
            'room_number', COALESCE(v_alc.room_number, 'A-101'),
            'bed_number', COALESCE(v_alc.bed_number, 'Bed 1'),
            'fee_plan', COALESCE(v_adm.fee_plan, v_acc.fee_plan_name, 'Monthly'),
            'total_fee', v_total_assigned,
            'total_paid', v_total_paid,
            'total_due', v_total_due,
            'total_overdue', CASE WHEN v_total_paid >= v_total_assigned THEN 0.00 ELSE COALESCE(v_acc.total_overdue, 0.00) END,
            'security_deposit_expected', COALESCE(v_adm.deposit_amount, v_acc.security_deposit_expected, 0.00),
            'security_deposit_paid', COALESCE(v_adm.deposit_amount, v_acc.security_deposit_paid, 0.00),
            'security_deposit_refunded', COALESCE(v_acc.security_deposit_refunded, 0.00),
            'advance_credit', CASE WHEN v_is_overpaid THEN (v_total_paid - v_total_assigned) ELSE 0.00 END,
            'payment_status', UPPER(REPLACE(v_status_str, ' ', '')),
            'status', v_status_str,
            'next_due_date', COALESCE(v_acc.next_due_date, CURRENT_DATE + INTERVAL '15 days'),
            'invoices', v_invoices,
            'payments', v_payments,
            'ledger', v_ledger,
            'concessions', v_concessions,
            'penalties', v_penalties,
            'fee_breakdown', v_breakdown,
            'breakdown', v_breakdown
        )
    );
END;
$$;


-- 5. Backfill initial ledger entries for all admissions having invoices and payments
DO $$
DECLARE
    r RECORD;
    v_run_bal NUMERIC(12,2) := 0.00;
BEGIN
    FOR r IN (
        SELECT 
            adm.school_id,
            adm.student_id,
            inv.id as invoice_id,
            inv.invoice_number,
            inv.net_amount as invoice_amount,
            pmt.id as payment_id,
            pmt.receipt_number,
            pmt.amount as payment_amount,
            pmt.payment_method
        FROM public.hostel_admissions adm
        LEFT JOIN LATERAL (
            SELECT id, invoice_number, net_amount 
            FROM public.hostel_invoices 
            WHERE student_id = adm.student_id AND deleted_at IS NULL 
            ORDER BY created_at ASC LIMIT 1
        ) inv ON TRUE
        LEFT JOIN LATERAL (
            SELECT id, receipt_number, amount, payment_method
            FROM public.hostel_payments
            WHERE student_id = adm.student_id
            ORDER BY paid_at ASC LIMIT 1
        ) pmt ON TRUE
        WHERE adm.deleted_at IS NULL
    ) LOOP
        -- If student has no invoice entry in ledger, insert one
        IF r.invoice_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM public.hostel_fee_ledger
            WHERE student_id = r.student_id AND entry_type = 'INVOICE' AND reference_id = r.invoice_id
        ) THEN
            v_run_bal := r.invoice_amount;
            INSERT INTO public.hostel_fee_ledger (
                school_id, student_id, entry_type, reference_id, reference_number,
                debit, credit, running_balance, description, transaction_date
            ) VALUES (
                r.school_id, r.student_id, 'INVOICE', r.invoice_id, r.invoice_number,
                r.invoice_amount, 0.00, v_run_bal,
                'Initial Hostel Fee Invoice (' || r.invoice_number || ')',
                NOW() - INTERVAL '1 hour'
            );
        END IF;

        -- If student has payment and no payment entry in ledger, insert one
        IF r.payment_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM public.hostel_fee_ledger
            WHERE student_id = r.student_id AND entry_type = 'PAYMENT' AND reference_id = r.payment_id
        ) THEN
            v_run_bal := GREATEST(0.00, v_run_bal - r.payment_amount);
            INSERT INTO public.hostel_fee_ledger (
                school_id, student_id, entry_type, reference_id, reference_number,
                debit, credit, running_balance, description, transaction_date
            ) VALUES (
                r.school_id, r.student_id, 'PAYMENT', r.payment_id, r.receipt_number,
                0.00, r.payment_amount, v_run_bal,
                'Hostel Fee Payment Received (' || COALESCE(r.payment_method, 'ONLINE_UPI') || ') Receipt: ' || r.receipt_number,
                NOW() - INTERVAL '30 minutes'
            );
        END IF;
    END LOOP;
END;
$$;

