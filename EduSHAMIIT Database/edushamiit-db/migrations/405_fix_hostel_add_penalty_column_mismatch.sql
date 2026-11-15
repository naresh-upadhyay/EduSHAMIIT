-- =========================================================================
-- Migration 405: Fix fn_hostel_add_penalty Column Mismatch
-- Author: Antigravity Team
-- Date: 2026-11-04
-- Purpose:
--   Fix public.hostel_penalties column mismatch in fn_hostel_add_penalty:
--   table columns are (charge_type, description, added_by, added_by_name)
--   not (penalty_type, reason, applied_by).
-- =========================================================================

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
    v_cur_balance NUMERIC(12,2) := 0;
BEGIN
    IF v_amount <= 0 THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Penalty amount must be greater than zero.');
    END IF;

    SELECT full_name INTO v_user_name FROM public.profiles WHERE id = p_user_id;

    INSERT INTO public.hostel_penalties (
        school_id, student_id, invoice_id, charge_type, description,
        amount, status, added_by, added_by_name
    ) VALUES (
        p_school_id, v_student_id, v_invoice_id, v_charge_type, v_description,
        v_amount, 'APPLIED', p_user_id, COALESCE(v_user_name, 'Admin')
    ) RETURNING id INTO v_penalty_id;

    SELECT COALESCE(running_balance, 0) INTO v_cur_balance
    FROM public.hostel_fee_ledger
    WHERE school_id = p_school_id AND student_id = v_student_id
    ORDER BY transaction_date DESC, created_at DESC LIMIT 1;

    v_cur_balance := v_cur_balance + v_amount;

    INSERT INTO public.hostel_fee_ledger (
        school_id, student_id, entry_type, reference_id, reference_number,
        debit, credit, running_balance, description, transaction_date, created_by
    ) VALUES (
        p_school_id, v_student_id, 'PENALTY', v_penalty_id, 'PEN-' || TO_CHAR(NOW(), 'YYYYMMDD'),
        v_amount, 0.00, v_cur_balance,
        'Penalty / Damage Charge: ' || v_description || ' (₹' || v_amount || ')',
        NOW(), p_user_id
    );

    -- Update student account with exact Over Paid mathematics
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
    WHERE school_id = p_school_id AND student_id = v_student_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Penalty added successfully',
        'penalty_id', v_penalty_id
    );
END;
$$;

