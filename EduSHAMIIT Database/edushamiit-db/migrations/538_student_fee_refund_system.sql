-- Migration 538: Student Fee Refund System for Overpaid / Advance Surpluses
-- Supports issuing refunds for accidental overpayments, wallet surplus drawdowns,
-- atomic rebalancing of payments/invoices, full audit logging, and 360-drawer integration.

-- 1. Create table public.student_fee_refunds
CREATE TABLE IF NOT EXISTS public.student_fee_refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    invoice_id UUID REFERENCES public.student_fee_invoices(id) ON DELETE SET NULL,
    payment_id UUID REFERENCES public.student_fee_payments(id) ON DELETE SET NULL,
    refund_number VARCHAR(100) NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    refund_mode VARCHAR(50) NOT NULL DEFAULT 'Bank Transfer',
    reference_number VARCHAR(150),
    reason TEXT NOT NULL,
    refunded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    refunded_by_name VARCHAR(150) DEFAULT 'Finance Officer',
    status VARCHAR(50) NOT NULL DEFAULT 'COMPLETED',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_student_fee_refunds_student ON public.student_fee_refunds(school_id, student_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_student_fee_refund_number ON public.student_fee_refunds(school_id, refund_number);


-- 2. Stored Procedure: fn_refund_student_fee
DROP FUNCTION IF EXISTS public.fn_refund_student_fee(UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, UUID, TEXT, TEXT, UUID, UUID);
DROP FUNCTION IF EXISTS public.fn_refund_student_fee(UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, UUID, UUID, UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.fn_refund_student_fee(
    p_school_id UUID,
    p_student_id UUID,
    p_amount NUMERIC(12,2),
    p_refund_mode TEXT DEFAULT 'Bank Transfer',
    p_reference_number TEXT DEFAULT NULL,
    p_reason TEXT DEFAULT 'Excess fee overpayment refund',
    p_invoice_id UUID DEFAULT NULL,
    p_payment_id UUID DEFAULT NULL,
    p_user_id UUID DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Finance Officer',
    p_user_role TEXT DEFAULT 'Finance Officer'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_seq INT := 0;
    v_ref_num TEXT;
    v_ref_id UUID;
    v_remaining NUMERIC(12,2) := p_amount;
    v_deduct NUMERIC(12,2) := 0.0;
    r_pay RECORD;
    r_inv RECORD;
    v_new_paid NUMERIC(12,2);
    v_new_bal NUMERIC(12,2);
    v_new_status TEXT;
    v_total_paid NUMERIC(12,2) := 0.0;
    v_total_billed NUMERIC(12,2) := 0.0;
    v_advance NUMERIC(12,2) := 0.0;
BEGIN
    IF p_amount <= 0.0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Refund amount must be greater than zero');
    END IF;

    -- Calculate current financial position of the student
    SELECT 
        COALESCE(SUM(i.total_billed), 0.0),
        COALESCE(SUM(i.paid_amount), 0.0) + COALESCE((
            SELECT SUM(pay.amount_paid) 
            FROM public.student_fee_payments pay 
            WHERE pay.student_id = p_student_id AND pay.school_id = p_school_id 
              AND pay.invoice_id IS NULL
              AND (pay.status IS NULL OR pay.status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS'))
        ), 0.0)
    INTO v_total_billed, v_total_paid
    FROM public.student_fee_invoices i
    WHERE i.student_id = p_student_id AND i.school_id = p_school_id;

    v_advance := GREATEST(0.0, v_total_paid - v_total_billed);

    -- If neither invoice nor payment is specified, this is a student surplus / overpayment refund
    IF p_invoice_id IS NULL AND p_payment_id IS NULL THEN
        IF v_advance <= 0.0 THEN
            RETURN jsonb_build_object('success', false, 'message', 'This student has no advance credit or overpayment surplus balance to refund.');
        END IF;
        IF p_amount > v_advance THEN
            RETURN jsonb_build_object('success', false, 'message', 'Refund amount cannot exceed available advance credit of ₹' || TO_CHAR(v_advance, 'FM99,99,999.00'));
        END IF;
    END IF;

    -- Sequence number for refund receipt
    SELECT COUNT(*) + 1 INTO v_seq
    FROM public.student_fee_refunds
    WHERE school_id = p_school_id;

    v_ref_num := 'REF-2026-' || LPAD(v_seq::text, 5, '0');

    -- Insert refund record
    INSERT INTO public.student_fee_refunds (
        school_id, student_id, invoice_id, payment_id, refund_number,
        amount, refund_mode, reference_number, reason,
        refunded_by, refunded_by_name, status, created_at
    ) VALUES (
        p_school_id, p_student_id, p_invoice_id, p_payment_id, v_ref_num,
        p_amount, COALESCE(p_refund_mode, 'Bank Transfer'), p_reference_number,
        COALESCE(p_reason, 'Overpayment refund'),
        p_user_id, COALESCE(p_user_name, 'Finance Officer'), 'COMPLETED', NOW()
    ) RETURNING id INTO v_ref_id;

    -- Rebalance payments & invoices
    -- Case 1: Specific payment requested
    IF p_payment_id IS NOT NULL THEN
        SELECT id, amount_paid, invoice_id, status INTO r_pay
        FROM public.student_fee_payments
        WHERE id = p_payment_id AND school_id = p_school_id;

        IF r_pay.id IS NOT NULL THEN
            IF r_pay.amount_paid <= p_amount THEN
                UPDATE public.student_fee_payments
                SET status = 'REFUNDED',
                    status_remarks = 'Refunded: ' || COALESCE(p_reason, 'Overpaid amount refund'),
                    status_updated_by = p_user_id,
                    status_updated_at = NOW(),
                    updated_at = NOW()
                WHERE id = r_pay.id;

                v_deduct := r_pay.amount_paid;
            ELSE
                UPDATE public.student_fee_payments
                SET amount_paid = amount_paid - p_amount,
                    status_remarks = 'Partially refunded: ₹' || p_amount::text || '. ' || COALESCE(p_reason, ''),
                    updated_at = NOW()
                WHERE id = r_pay.id;

                v_deduct := p_amount;
            END IF;

            -- If this payment was tied to an invoice, rebalance it
            IF r_pay.invoice_id IS NOT NULL THEN
                SELECT total_billed, paid_amount INTO r_inv
                FROM public.student_fee_invoices
                WHERE id = r_pay.invoice_id;

                IF r_inv.total_billed IS NOT NULL THEN
                    v_new_paid := GREATEST(0.0, r_inv.paid_amount - v_deduct);
                    v_new_bal := GREATEST(0.0, r_inv.total_billed - v_new_paid);
                    v_new_status := CASE 
                        WHEN v_new_paid > r_inv.total_billed THEN 'Overpaid'
                        WHEN v_new_bal <= 0.0 AND r_inv.total_billed > 0.0 THEN 'Paid'
                        WHEN v_new_paid > 0.0 THEN 'Partial'
                        ELSE 'Pending'
                    END;

                    UPDATE public.student_fee_invoices
                    SET paid_amount = v_new_paid,
                        balance_amount = v_new_bal,
                        status = v_new_status,
                        updated_at = NOW()
                    WHERE id = r_pay.invoice_id;
                END IF;
            END IF;

            v_remaining := GREATEST(0.0, v_remaining - v_deduct);
        END IF;
    END IF;

    -- Case 2: Deduct remaining from unallocated advance payments first
    IF v_remaining > 0.0 THEN
        FOR r_pay IN 
            SELECT id, amount_paid
            FROM public.student_fee_payments
            WHERE student_id = p_student_id AND school_id = p_school_id 
              AND invoice_id IS NULL
              AND status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS')
            ORDER BY created_at DESC
        LOOP
            IF r_pay.amount_paid <= v_remaining THEN
                v_deduct := r_pay.amount_paid;
                UPDATE public.student_fee_payments
                SET status = 'REFUNDED',
                    status_remarks = 'Refunded: ' || COALESCE(p_reason, 'Overpaid amount refund'),
                    status_updated_by = p_user_id,
                    status_updated_at = NOW(),
                    updated_at = NOW()
                WHERE id = r_pay.id;
            ELSE
                v_deduct := v_remaining;
                UPDATE public.student_fee_payments
                SET amount_paid = amount_paid - v_deduct,
                    status_remarks = 'Partially refunded: ₹' || v_deduct::text || '. ' || COALESCE(p_reason, ''),
                    updated_at = NOW()
                WHERE id = r_pay.id;
            END IF;

            v_remaining := v_remaining - v_deduct;
            EXIT WHEN v_remaining <= 0.0;
        END LOOP;
    END IF;

    -- Case 3: Deduct remaining from overpaid invoices (surplus paid amount)
    IF v_remaining > 0.0 THEN
        FOR r_inv IN 
            SELECT id, total_billed, paid_amount
            FROM public.student_fee_invoices
            WHERE student_id = p_student_id AND school_id = p_school_id
              AND paid_amount > total_billed
            ORDER BY created_at DESC
        LOOP
            v_deduct := LEAST(v_remaining, r_inv.paid_amount - r_inv.total_billed);
            v_new_paid := r_inv.paid_amount - v_deduct;
            v_new_bal := GREATEST(0.0, r_inv.total_billed - v_new_paid);
            v_new_status := CASE 
                WHEN v_new_paid > r_inv.total_billed THEN 'Overpaid'
                WHEN v_new_bal <= 0.0 AND r_inv.total_billed > 0.0 THEN 'Paid'
                WHEN v_new_paid > 0.0 THEN 'Partial'
                ELSE 'Pending'
            END;

            UPDATE public.student_fee_invoices
            SET paid_amount = v_new_paid,
                balance_amount = v_new_bal,
                status = v_new_status,
                updated_at = NOW()
            WHERE id = r_inv.id;

            v_remaining := v_remaining - v_deduct;
            EXIT WHEN v_remaining <= 0.0;
        END LOOP;
    END IF;

    -- Case 4: If still remaining, deduct from any paid invoices
    IF v_remaining > 0.0 THEN
        FOR r_inv IN 
            SELECT id, total_billed, paid_amount
            FROM public.student_fee_invoices
            WHERE student_id = p_student_id AND school_id = p_school_id
              AND paid_amount > 0.0
            ORDER BY created_at DESC
        LOOP
            v_deduct := LEAST(v_remaining, r_inv.paid_amount);
            v_new_paid := r_inv.paid_amount - v_deduct;
            v_new_bal := GREATEST(0.0, r_inv.total_billed - v_new_paid);
            v_new_status := CASE 
                WHEN v_new_paid > r_inv.total_billed THEN 'Overpaid'
                WHEN v_new_bal <= 0.0 AND r_inv.total_billed > 0.0 THEN 'Paid'
                WHEN v_new_paid > 0.0 THEN 'Partial'
                ELSE 'Pending'
            END;

            UPDATE public.student_fee_invoices
            SET paid_amount = v_new_paid,
                balance_amount = v_new_bal,
                status = v_new_status,
                updated_at = NOW()
            WHERE id = r_inv.id;

            v_remaining := v_remaining - v_deduct;
            EXIT WHEN v_remaining <= 0.0;
        END LOOP;
    END IF;

    -- Audit Log Entry
    INSERT INTO public.student_fee_audit_logs (
        school_id, student_id, entity_type, entity_id, action,
        description, old_status, new_status, amount,
        performed_by_id, performed_by_name, performed_by_role, metadata, created_at
    ) VALUES (
        p_school_id, p_student_id, 'REFUND', v_ref_id, 'REFUND_PROCESSED',
        'Fee refund of ₹' || TO_CHAR(p_amount, 'FM99,99,990.00') || ' processed (' || COALESCE(p_refund_mode, 'Bank Transfer') || '). Reason: ' || COALESCE(p_reason, 'Overpayment refund') || ' (Voucher: ' || v_ref_num || ')',
        'OVERPAID', 'REFUNDED', p_amount,
        p_user_id, COALESCE(p_user_name, 'Finance Officer'), COALESCE(p_user_role, 'Finance Officer'),
        jsonb_build_object(
            'refund_number', v_ref_num,
            'refund_mode', p_refund_mode,
            'reference_number', p_reference_number,
            'initial_advance', v_advance
        ),
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'refund_id', v_ref_id,
        'refund_number', v_ref_num,
        'amount', p_amount,
        'message', 'Fee refund of ₹' || TO_CHAR(p_amount, 'FM99,99,990.00') || ' processed successfully'
    );
END;
$$;


-- 3. Update fn_student_fee_account_details to include Refunds in 360 view
CREATE OR REPLACE FUNCTION public.fn_student_fee_account_details(
    p_school_id UUID,
    p_student_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile RECORD;
    v_invoices JSONB;
    v_payments JSONB;
    v_refunds JSONB;
    v_concessions JSONB;
    v_penalties JSONB;
    v_audit_logs JSONB;
    v_total_billed NUMERIC(12,2) := 0.0;
    v_total_paid NUMERIC(12,2) := 0.0;
    v_balance NUMERIC(12,2) := 0.0;
    v_advance NUMERIC(12,2) := 0.0;
    v_status TEXT := 'Pending';
BEGIN
    SELECT id, full_name, email, phone, class, roll_number, admission_number, avatar_url
    INTO v_profile
    FROM public.profiles
    WHERE id = p_student_id AND school_id = p_school_id;

    IF v_profile.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Student not found');
    END IF;

    -- Invoices
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', i.id,
                'invoice_number', i.invoice_number,
                'title', i.title,
                'fee_type', i.fee_type,
                'fee_plan', i.fee_plan,
                'academic_year', i.academic_year,
                'billing_date', i.billing_date,
                'due_date', i.due_date,
                'subtotal', i.subtotal,
                'concession_amount', i.concession_amount,
                'penalty_amount', i.penalty_amount,
                'total_billed', i.total_billed,
                'paid_amount', i.paid_amount,
                'balance_amount', i.balance_amount,
                'status', i.status,
                'created_at', i.created_at
            ) ORDER BY i.created_at DESC
        ), '[]'::jsonb
    ) INTO v_invoices
    FROM public.student_fee_invoices i
    WHERE i.student_id = p_student_id AND i.school_id = p_school_id;

    -- Payments
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', pay.id,
                'receipt_number', pay.receipt_number,
                'amount_paid', pay.amount_paid,
                'payment_method', pay.payment_method,
                'transaction_reference', pay.transaction_reference,
                'status', pay.status,
                'created_at', pay.created_at,
                'remarks', pay.remarks
            ) ORDER BY pay.created_at DESC
        ), '[]'::jsonb
    ) INTO v_payments
    FROM public.student_fee_payments pay
    WHERE pay.student_id = p_student_id AND pay.school_id = p_school_id;

    -- Refunds
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', ref.id,
                'refund_number', ref.refund_number,
                'amount', ref.amount,
                'refund_mode', ref.refund_mode,
                'reference_number', ref.reference_number,
                'reason', ref.reason,
                'refunded_by_name', ref.refunded_by_name,
                'status', ref.status,
                'created_at', ref.created_at
            ) ORDER BY ref.created_at DESC
        ), '[]'::jsonb
    ) INTO v_refunds
    FROM public.student_fee_refunds ref
    WHERE ref.student_id = p_student_id AND ref.school_id = p_school_id;

    -- Concessions
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', c.id,
                'concession_type', c.concession_type,
                'amount', c.amount,
                'reason', c.reason,
                'created_at', c.created_at
            ) ORDER BY c.created_at DESC
        ), '[]'::jsonb
    ) INTO v_concessions
    FROM public.student_fee_concessions c
    WHERE c.student_id = p_student_id AND c.school_id = p_school_id;

    -- Penalties
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', pen.id,
                'penalty_type', pen.penalty_type,
                'amount', pen.amount,
                'reason', pen.reason,
                'created_at', pen.created_at
            ) ORDER BY pen.created_at DESC
        ), '[]'::jsonb
    ) INTO v_penalties
    FROM public.student_fee_penalties pen
    WHERE pen.student_id = p_student_id AND pen.school_id = p_school_id;

    -- Audit Logs
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', a.id,
                'action', a.action,
                'description', a.description,
                'amount', a.amount,
                'performed_by_name', a.performed_by_name,
                'created_at', a.created_at
            ) ORDER BY a.created_at DESC
        ), '[]'::jsonb
    ) INTO v_audit_logs
    FROM public.student_fee_audit_logs a
    WHERE a.student_id = p_student_id AND a.school_id = p_school_id
    LIMIT 25;

    -- Compute overall student finance
    SELECT 
        COALESCE(SUM(i.total_billed), 0.0),
        COALESCE(SUM(i.paid_amount), 0.0) + COALESCE((
            SELECT SUM(pay.amount_paid) 
            FROM public.student_fee_payments pay 
            WHERE pay.student_id = p_student_id AND pay.school_id = p_school_id 
              AND pay.invoice_id IS NULL
              AND (pay.status IS NULL OR pay.status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS'))
        ), 0.0)
    INTO v_total_billed, v_total_paid
    FROM public.student_fee_invoices i
    WHERE i.student_id = p_student_id AND i.school_id = p_school_id;

    v_balance := GREATEST(0.0, v_total_billed - v_total_paid);
    v_advance := GREATEST(0.0, v_total_paid - v_total_billed);

    IF v_total_billed = 0.0 AND v_total_paid = 0.0 THEN
        v_status := 'Unbilled';
    ELSIF v_total_paid > v_total_billed THEN
        v_status := 'Overpaid';
    ELSIF v_balance <= 0.0 AND v_total_billed > 0 THEN
        v_status := 'Paid';
    ELSIF v_total_paid > 0 THEN
        v_status := 'Partial';
    ELSE
        v_status := 'Pending';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'student', jsonb_build_object(
            'id', v_profile.id,
            'name', v_profile.full_name,
            'email', v_profile.email,
            'phone', v_profile.phone,
            'class_name', COALESCE(v_profile.class, '10A'),
            'roll_number', COALESCE(v_profile.roll_number::text, '-'),
            'admission_number', COALESCE(v_profile.admission_number, 'ADM-' || UPPER(SUBSTRING(v_profile.id::text, 1, 6))),
            'avatar_url', v_profile.avatar_url,
            'total_billed', v_total_billed,
            'paid_amount', v_total_paid,
            'balance_amount', v_balance,
            'advance_amount', v_advance,
            'status', v_status
        ),
        'invoices', v_invoices,
        'payments', v_payments,
        'refunds', v_refunds,
        'concessions', v_concessions,
        'penalties', v_penalties,
        'audit_logs', v_audit_logs
    );
END;
$$;
