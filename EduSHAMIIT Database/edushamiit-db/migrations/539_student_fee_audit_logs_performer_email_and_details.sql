-- ============================================================================
-- Migration: 539_student_fee_audit_logs_performer_email_and_details.sql
-- Description: Enhance Student Fee Audit Logs to store and return exact performer
--              name, email address, and role.
-- ============================================================================

-- 1. Add performed_by_email column to student_fee_audit_logs
ALTER TABLE public.student_fee_audit_logs 
ADD COLUMN IF NOT EXISTS performed_by_email VARCHAR(255);

CREATE INDEX IF NOT EXISTS idx_student_fee_audit_logs_performer 
ON public.student_fee_audit_logs(performed_by_id);

-- 2. Backfill existing logs with email, full name, and role from profiles table
UPDATE public.student_fee_audit_logs a
SET 
    performed_by_email = p.email,
    performed_by_name = CASE 
        WHEN a.performed_by_name IN ('Finance Officer', 'System / Admin', 'Admin', 'Registrar', 'Super Admin') AND p.full_name IS NOT NULL AND p.full_name <> ''
        THEN p.full_name 
        ELSE a.performed_by_name 
    END,
    performed_by_role = CASE 
        WHEN (a.performed_by_role IS NULL OR a.performed_by_role IN ('Registrar', 'Finance Officer')) AND p.role IS NOT NULL AND p.role <> ''
        THEN p.role 
        ELSE a.performed_by_role 
    END
FROM public.profiles p
WHERE a.performed_by_id = p.id;

-- 3. Stored Procedure: fn_refund_student_fee (Updated with User Email & Profile Lookup)
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
    r_user RECORD;
    v_new_paid NUMERIC(12,2);
    v_new_bal NUMERIC(12,2);
    v_new_status TEXT;
    v_total_paid NUMERIC(12,2) := 0.0;
    v_total_billed NUMERIC(12,2) := 0.0;
    v_advance NUMERIC(12,2) := 0.0;
    v_user_name TEXT := p_user_name;
    v_user_email TEXT := NULL;
    v_user_role TEXT := p_user_role;
BEGIN
    IF p_amount <= 0.0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Refund amount must be greater than zero');
    END IF;

    -- Look up exact performer profile (Name, Email, Role)
    IF p_user_id IS NOT NULL THEN
        SELECT full_name, email, role INTO r_user
        FROM public.profiles
        WHERE id = p_user_id;

        IF r_user.full_name IS NOT NULL AND r_user.full_name <> '' THEN
            v_user_name := r_user.full_name;
        END IF;
        IF r_user.email IS NOT NULL AND r_user.email <> '' THEN
            v_user_email := r_user.email;
        END IF;
        IF r_user.role IS NOT NULL AND r_user.role <> '' THEN
            v_user_role := r_user.role;
        END IF;
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
        p_user_id, COALESCE(v_user_name, 'Finance Officer'), 'COMPLETED', NOW()
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
                    status_remarks = 'Partially refunded ₹' || p_amount || ': ' || COALESCE(p_reason, 'Overpaid amount refund'),
                    status_updated_by = p_user_id,
                    status_updated_at = NOW(),
                    updated_at = NOW()
                WHERE id = r_pay.id;

                v_deduct := p_amount;
            END IF;

            -- If attached to an invoice, rebalance invoice paid amount
            IF r_pay.invoice_id IS NOT NULL THEN
                UPDATE public.student_fee_invoices
                SET paid_amount = GREATEST(0.0, paid_amount - v_deduct),
                    balance_amount = GREATEST(0.0, total_billed - (paid_amount - v_deduct)),
                    status = CASE 
                        WHEN GREATEST(0.0, paid_amount - v_deduct) >= total_billed THEN 'Paid'
                        WHEN GREATEST(0.0, paid_amount - v_deduct) > 0 THEN 'Partial'
                        ELSE 'Pending'
                    END,
                    updated_at = NOW()
                WHERE id = r_pay.invoice_id AND school_id = p_school_id;
            END IF;

            v_remaining := v_remaining - v_deduct;
        END IF;
    END IF;

    -- Case 2: Specific invoice requested
    IF p_invoice_id IS NOT NULL AND v_remaining > 0.0 THEN
        SELECT id, total_billed, paid_amount, balance_amount INTO r_inv
        FROM public.student_fee_invoices
        WHERE id = p_invoice_id AND school_id = p_school_id;

        IF r_inv.id IS NOT NULL AND r_inv.paid_amount > 0.0 THEN
            v_deduct := LEAST(r_inv.paid_amount, v_remaining);
            v_new_paid := r_inv.paid_amount - v_deduct;
            v_new_bal := GREATEST(0.0, r_inv.total_billed - v_new_paid);
            v_new_status := CASE 
                WHEN v_new_paid >= r_inv.total_billed THEN 'Paid'
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
        END IF;
    END IF;

    -- Case 3: General overpayment refund - First exhaust unallocated payments
    IF v_remaining > 0.0 THEN
        FOR r_pay IN 
            SELECT id, amount_paid, status
            FROM public.student_fee_payments
            WHERE student_id = p_student_id AND school_id = p_school_id
              AND invoice_id IS NULL
              AND (status IS NULL OR status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS'))
            ORDER BY created_at DESC
        LOOP
            IF r_pay.amount_paid <= v_remaining THEN
                UPDATE public.student_fee_payments
                SET status = 'REFUNDED',
                    status_remarks = 'Refunded ₹' || r_pay.amount_paid || ' to student (Ref: ' || v_ref_num || ')',
                    status_updated_by = p_user_id,
                    status_updated_at = NOW(),
                    updated_at = NOW()
                WHERE id = r_pay.id;

                v_deduct := r_pay.amount_paid;
            ELSE
                UPDATE public.student_fee_payments
                SET amount_paid = amount_paid - v_remaining,
                    status_remarks = 'Refunded partial ₹' || v_remaining || ' (Ref: ' || v_ref_num || ')',
                    status_updated_by = p_user_id,
                    status_updated_at = NOW(),
                    updated_at = NOW()
                WHERE id = r_pay.id;

                v_deduct := v_remaining;
            END IF;

            v_remaining := v_remaining - v_deduct;
            EXIT WHEN v_remaining <= 0.0;
        END LOOP;
    END IF;

    -- Case 4: General overpayment refund - If still remaining, deduct from overpaid invoices
    IF v_remaining > 0.0 THEN
        FOR r_inv IN 
            SELECT id, total_billed, paid_amount, balance_amount
            FROM public.student_fee_invoices
            WHERE student_id = p_student_id AND school_id = p_school_id
              AND paid_amount > total_billed
            ORDER BY created_at DESC
        LOOP
            v_deduct := LEAST(r_inv.paid_amount - r_inv.total_billed, v_remaining);
            IF v_deduct <= 0.0 THEN
                v_deduct := LEAST(r_inv.paid_amount, v_remaining);
            END IF;

            v_new_paid := r_inv.paid_amount - v_deduct;
            v_new_bal := GREATEST(0.0, r_inv.total_billed - v_new_paid);
            v_new_status := CASE 
                WHEN v_new_paid >= r_inv.total_billed THEN 'Paid'
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

    -- Audit Log Entry with User Name, Email, and Role
    INSERT INTO public.student_fee_audit_logs (
        school_id, student_id, entity_type, entity_id, action,
        description, old_status, new_status, amount,
        performed_by_id, performed_by_name, performed_by_email, performed_by_role, metadata, created_at
    ) VALUES (
        p_school_id, p_student_id, 'REFUND', v_ref_id, 'REFUND_PROCESSED',
        'Fee refund of ₹' || TO_CHAR(p_amount, 'FM99,99,990.00') || ' processed (' || COALESCE(p_refund_mode, 'Bank Transfer') || '). Reason: ' || COALESCE(p_reason, 'Overpayment refund') || ' (Voucher: ' || v_ref_num || ')',
        'OVERPAID', 'REFUNDED', p_amount,
        p_user_id, COALESCE(v_user_name, 'Finance Officer'), v_user_email, COALESCE(v_user_role, 'Finance Officer'),
        jsonb_build_object(
            'refund_number', v_ref_num,
            'refund_mode', p_refund_mode,
            'reference_number', p_reference_number,
            'initial_advance', v_advance,
            'performed_by_email', v_user_email
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


-- 4. Stored Procedure: fn_student_fee_account_details (Returns Performer Name, Email, Role)
CREATE OR REPLACE FUNCTION public.fn_student_fee_account_details(
    p_school_id UUID,
    p_student_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student JSONB;
    v_invoices JSONB;
    v_payments JSONB;
    v_concessions JSONB;
    v_penalties JSONB;
    v_audit_logs JSONB;
    v_refunds JSONB;
    v_total_billed NUMERIC(12,2) := 0.0;
    v_total_paid NUMERIC(12,2) := 0.0;
    v_balance NUMERIC(12,2) := 0.0;
    v_advance NUMERIC(12,2) := 0.0;
    v_status TEXT := 'Pending';
BEGIN
    -- Student Profile
    SELECT jsonb_build_object(
        'id', p.id,
        'name', p.full_name,
        'class_name', COALESCE(p.class, '10A'),
        'roll_number', COALESCE(p.roll_number::text, '-'),
        'admission_number', COALESCE(p.admission_number, ''),
        'email', p.email,
        'phone', p.phone,
        'avatar_url', p.avatar_url
    ) INTO v_student
    FROM public.profiles p
    WHERE p.id = p_student_id AND p.school_id = p_school_id;

    IF v_student IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Student profile not found');
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
                'remarks', pay.remarks,
                'created_at', pay.created_at
            ) ORDER BY pay.created_at DESC
        ), '[]'::jsonb
    ) INTO v_payments
    FROM public.student_fee_payments pay
    WHERE pay.student_id = p_student_id AND pay.school_id = p_school_id;

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

    -- Refunds
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', r.id,
                'refund_number', r.refund_number,
                'amount', r.amount,
                'refund_mode', r.refund_mode,
                'reference_number', r.reference_number,
                'reason', r.reason,
                'refunded_by_name', r.refunded_by_name,
                'status', r.status,
                'created_at', r.created_at
            ) ORDER BY r.created_at DESC
        ), '[]'::jsonb
    ) INTO v_refunds
    FROM public.student_fee_refunds r
    WHERE r.student_id = p_student_id AND r.school_id = p_school_id;

    -- Audit Logs (With Full Performer Name, Email, and Role)
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', a.id,
                'action', a.action,
                'description', a.description,
                'amount', a.amount,
                'performed_by_id', a.performed_by_id,
                'performed_by_name', COALESCE(NULLIF(p.full_name, ''), a.performed_by_name, 'System'),
                'performed_by_email', COALESCE(a.performed_by_email, p.email, ''),
                'performed_by_role', COALESCE(NULLIF(p.role, ''), a.performed_by_role, 'Staff'),
                'created_at', a.created_at
            ) ORDER BY a.created_at DESC
        ), '[]'::jsonb
    ) INTO v_audit_logs
    FROM public.student_fee_audit_logs a
    LEFT JOIN public.profiles p ON p.id = a.performed_by_id
    WHERE a.student_id = p_student_id AND a.school_id = p_school_id
    LIMIT 50;

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
    ELSIF EXISTS (SELECT 1 FROM public.student_fee_invoices WHERE student_id = p_student_id AND school_id = p_school_id AND due_date < CURRENT_DATE AND balance_amount > 0) THEN
        v_status := 'Overdue';
    ELSE
        v_status := 'Pending';
    END IF;

    v_student := v_student || jsonb_build_object(
        'total_billed', v_total_billed,
        'paid_amount', v_total_paid,
        'balance_amount', v_balance,
        'advance_amount', v_advance,
        'status', v_status
    );

    RETURN jsonb_build_object(
        'success', true,
        'student', v_student,
        'invoices', v_invoices,
        'payments', v_payments,
        'concessions', v_concessions,
        'penalties', v_penalties,
        'refunds', v_refunds,
        'audit_logs', v_audit_logs
    );
END;
$$;
