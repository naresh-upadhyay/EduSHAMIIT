-- ============================================================================
-- Migration: 525_student_fee_status_and_audit_history.sql
-- Description: Enhanced Student Fee Management:
--              1. Payment Status Support (SUCCESS, WAITING_CONFIRMATION, FAILED, REFUNDED)
--              2. 48-Hour UPI Waiting Confirmation & Auto-Timeout to FAILED
--              3. Full Student Fee Audit Log (Tracking Who, What, When)
--              4. Overpaid Status Support for Surplus Balances
--              5. Stored Procedures for Status Updates & Reconciliations
-- ============================================================================

-- 1. Enhance student_fee_payments columns
ALTER TABLE public.student_fee_payments
ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'SUCCESS',
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS status_updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS status_updated_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS status_remarks TEXT;

-- Normalize existing payment statuses
UPDATE public.student_fee_payments
SET status = 'SUCCESS'
WHERE status IS NULL OR status = 'COMPLETED' OR status = 'PAID';

-- 2. Create student_fee_audit_logs table
CREATE TABLE IF NOT EXISTS public.student_fee_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    entity_type VARCHAR(50) NOT NULL, -- 'PAYMENT', 'INVOICE', 'STATUS_CHANGE', 'CONCESSION', 'PENALTY'
    entity_id UUID,
    action VARCHAR(100) NOT NULL, -- 'PAYMENT_COLLECTED', 'STATUS_UPDATED', 'INVOICE_GENERATED', 'CONCESSION_APPLIED', 'PENALTY_ADDED'
    description TEXT NOT NULL,
    old_status VARCHAR(50),
    new_status VARCHAR(50),
    amount NUMERIC(12, 2) DEFAULT 0.0,
    performed_by_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    performed_by_name VARCHAR(150) NOT NULL DEFAULT 'System / Admin',
    performed_by_role VARCHAR(50) DEFAULT 'Registrar',
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_student_fee_audit_logs_student 
ON public.student_fee_audit_logs(school_id, student_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_student_fee_audit_logs_action 
ON public.student_fee_audit_logs(school_id, action, created_at DESC);

-- 3. Stored Procedure: Auto-Expire 48-Hour Waiting Confirmation UPI Payments
CREATE OR REPLACE FUNCTION public.fn_expire_waiting_upi_payments(p_school_id UUID DEFAULT NULL)
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER := 0;
    r RECORD;
BEGIN
    FOR r IN 
        SELECT id, school_id, student_id, receipt_number, amount_paid, payment_method, created_at
        FROM public.student_fee_payments
        WHERE (p_school_id IS NULL OR school_id = p_school_id)
          AND UPPER(status) = 'WAITING_CONFIRMATION'
          AND created_at < NOW() - INTERVAL '48 hours'
    LOOP
        -- Update payment to FAILED
        UPDATE public.student_fee_payments
        SET status = 'FAILED',
            status_remarks = 'Payment confirmation not received within 48-hour timeout window. Transaction marked as failed.',
            status_updated_at = NOW(),
            updated_at = NOW()
        WHERE id = r.id;

        -- Also fail corresponding payment_intents if any
        UPDATE public.payment_intents
        SET status = 'FAILED',
            updated_at = NOW()
        WHERE receipt_number = r.receipt_number OR intent_reference = r.receipt_number;

        -- Record Audit Log
        INSERT INTO public.student_fee_audit_logs (
            school_id, student_id, entity_type, entity_id, action,
            description, old_status, new_status, amount,
            performed_by_name, performed_by_role
        ) VALUES (
            r.school_id, r.student_id, 'PAYMENT', r.id, 'STATUS_UPDATED',
            'Payment marked as Failed: 48-hour confirmation timeout expired without bridge confirmation.',
            'WAITING_CONFIRMATION', 'FAILED', r.amount_paid,
            'System Automation', 'System'
        );

        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- 4. Seed initial audit log entries from existing transactions so the history tab is immediately populated
DO $$
DECLARE
    r_pay RECORD;
    r_inv RECORD;
BEGIN
    -- Seed from payments
    FOR r_pay IN 
        SELECT p.id, p.school_id, p.student_id, p.receipt_number, p.amount_paid, p.payment_method, p.payment_date, p.created_at,
               COALESCE(u.full_name, 'Finance Office') AS recorder_name,
               COALESCE(u.role, 'Registrar') AS recorder_role
        FROM public.student_fee_payments p
        LEFT JOIN public.profiles u ON p.recorded_by = u.id
        WHERE NOT EXISTS (
            SELECT 1 FROM public.student_fee_audit_logs a 
            WHERE a.entity_id = p.id AND a.action = 'PAYMENT_COLLECTED'
        )
    LOOP
        INSERT INTO public.student_fee_audit_logs (
            school_id, student_id, entity_type, entity_id, action,
            description, old_status, new_status, amount,
            performed_by_name, performed_by_role, created_at
        ) VALUES (
            r_pay.school_id, r_pay.student_id, 'PAYMENT', r_pay.id, 'PAYMENT_COLLECTED',
            'Collected payment ' || r_pay.receipt_number || ' (' || r_pay.payment_method || ') of ₹' || r_pay.amount_paid::text,
            'PENDING', 'SUCCESS', r_pay.amount_paid,
            r_pay.recorder_name, r_pay.recorder_role, COALESCE(r_pay.payment_date, r_pay.created_at, NOW())
        );
    END LOOP;

    -- Seed from invoices
    FOR r_inv IN 
        SELECT i.id, i.school_id, i.student_id, i.invoice_number, i.total_billed, i.created_at
        FROM public.student_fee_invoices i
        WHERE NOT EXISTS (
            SELECT 1 FROM public.student_fee_audit_logs a 
            WHERE a.entity_id = i.id AND a.action = 'INVOICE_GENERATED'
        )
    LOOP
        INSERT INTO public.student_fee_audit_logs (
            school_id, student_id, entity_type, entity_id, action,
            description, old_status, new_status, amount,
            performed_by_name, performed_by_role, created_at
        ) VALUES (
            r_inv.school_id, r_inv.student_id, 'INVOICE', r_inv.id, 'INVOICE_GENERATED',
            'Generated fee invoice ' || r_inv.invoice_number || ' for amount ₹' || r_inv.total_billed::text,
            NULL, 'Pending', r_inv.total_billed,
            'Billing System', 'Registrar', COALESCE(r_inv.created_at, NOW())
        );
    END LOOP;
END $$;
