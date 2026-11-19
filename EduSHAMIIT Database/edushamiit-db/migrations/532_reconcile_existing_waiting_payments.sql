-- ============================================================================
-- Migration: 531_reconcile_existing_waiting_payments.sql
-- Description: Auto-reconcile payment bridge confirmed transactions:
--              1. Transition existing WAITING_CONFIRMATION student_fee_payments to SUCCESS
--              2. Preserve exact floating amount / paise (e.g. 1.53)
--              3. Insert PAYMENT_CONFIRMED audit log in student_fee_audit_logs
-- ============================================================================

DO $$
DECLARE
    r RECORD;
    v_pay_id UUID;
    v_amt NUMERIC(12, 2);
BEGIN
    FOR r IN
        SELECT 
            pt.id as tx_id,
            pt.school_id,
            pt.student_id,
            pt.invoice_id,
            pt.receipt_number,
            pt.amount_paise,
            pt.transaction_reference,
            pt.verified_at,
            pi.intent_reference
        FROM public.payment_transactions pt
        JOIN public.payment_intents pi ON pi.id = pt.payment_intent_id
        WHERE pt.payment_status = 'VERIFIED_SUCCESS'
          AND pt.student_id IS NOT NULL
    LOOP
        v_amt := ROUND((r.amount_paise / 100.0)::numeric, 2);

        -- Find matching WAITING_CONFIRMATION or existing student_fee_payments record
        SELECT id INTO v_pay_id
        FROM public.student_fee_payments
        WHERE school_id = r.school_id 
          AND (
              receipt_number = r.receipt_number
              OR transaction_reference = r.intent_reference 
              OR transaction_reference = r.transaction_reference 
              OR (invoice_id = r.invoice_id AND status = 'WAITING_CONFIRMATION')
          )
        ORDER BY (receipt_number = r.receipt_number) DESC, created_at DESC LIMIT 1;

        IF v_pay_id IS NOT NULL THEN
            UPDATE public.student_fee_payments
            SET status = 'SUCCESS',
                receipt_number = r.receipt_number,
                amount_paid = v_amt,
                transaction_reference = COALESCE(r.transaction_reference, r.intent_reference),
                payment_date = COALESCE(r.verified_at, NOW()),
                status_remarks = 'Auto-verified via EduSHAMIIT Payment Bridge UPI notification',
                status_updated_at = NOW(),
                updated_at = NOW()
            WHERE id = v_pay_id;
        ELSE
            INSERT INTO public.student_fee_payments (
                school_id, student_id, invoice_id, receipt_number, amount_paid,
                payment_method, transaction_reference, payment_date, status, remarks, created_at, updated_at
            ) VALUES (
                r.school_id, r.student_id, r.invoice_id, r.receipt_number,
                v_amt, 'UPI',
                COALESCE(r.transaction_reference, r.intent_reference),
                COALESCE(r.verified_at, NOW()), 'SUCCESS',
                'Auto-verified via EduSHAMIIT Payment Bridge UPI notification',
                COALESCE(r.verified_at, NOW()), NOW()
            ) RETURNING id INTO v_pay_id;
        END IF;

        -- Ensure audit log exists in student_fee_audit_logs for the History tab
        IF NOT EXISTS (
            SELECT 1 FROM public.student_fee_audit_logs
            WHERE school_id = r.school_id 
              AND student_id = r.student_id 
              AND action = 'PAYMENT_CONFIRMED'
              AND (
                  description ILIKE '%' || r.receipt_number || '%' 
                  OR description ILIKE '%' || r.intent_reference || '%'
              )
        ) THEN
            INSERT INTO public.student_fee_audit_logs (
                school_id, student_id, entity_type, entity_id, action,
                description, old_status, new_status, amount,
                performed_by_name, performed_by_role, created_at
            ) VALUES (
                r.school_id, r.student_id, 'PAYMENT', v_pay_id, 'PAYMENT_CONFIRMED',
                'UPI payment ' || r.receipt_number || ' verified and settled for ₹' || TRIM(TO_CHAR(v_amt, '999999990.99')) || ' (Ref: ' || COALESCE(r.transaction_reference, r.intent_reference) || ')',
                'WAITING_CONFIRMATION', 'SUCCESS', v_amt,
                'EduSHAMIIT Payment Bridge', 'Automated Gateway',
                COALESCE(r.verified_at, NOW())
            );
        END IF;
    END LOOP;
END $$;
