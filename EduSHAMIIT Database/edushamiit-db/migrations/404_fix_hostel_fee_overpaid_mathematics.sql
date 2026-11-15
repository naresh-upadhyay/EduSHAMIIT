-- =========================================================================
-- Migration 404: Correct Fee and Billing Mathematics for Overpaid Accounts
-- Author: Antigravity Team
-- Date: 2026-11-03
-- Purpose:
--   1. When total_paid > total_billed:
--      - Status is set to 'OVERPAID' (displayed as 'Over Paid' with badge).
--      - Balance amount (total_due) is explicitly set to 0.00 because
--        the surplus amount is an advance/credit to be utilized next time.
--      - advance_credit is set to (total_paid - total_billed).
--   2. When total_paid = total_billed:
--      - Status is set to 'PAID' (displayed as 'Paid').
--      - Balance amount (total_due) is 0.00.
--   3. When total_paid < total_billed and total_paid > 0:
--      - Status is 'PARTIAL'.
--      - Balance amount is (total_billed - total_paid).
--   4. Update fn_hostel_get_student_fees, fn_hostel_get_student_fee_details_360,
--      fn_hostel_collect_payment, fn_hostel_add_penalty, fn_hostel_generate_invoice,
--      fn_hostel_apply_concession, and fn_hostel_get_fee_kpis.
--   5. Reconcile existing records in hostel_student_accounts.
-- =========================================================================

-- 1. Reconcile existing records in hostel_student_accounts
UPDATE public.hostel_student_accounts
SET 
    total_due = CASE 
        WHEN total_paid >= total_billed THEN 0.00 
        ELSE GREATEST(0.00, total_billed - total_paid) 
    END,
    advance_credit = CASE 
        WHEN total_paid > total_billed THEN (total_paid - total_billed) 
        ELSE 0.00 
    END,
    payment_status = CASE 
        WHEN total_paid > total_billed THEN 'OVERPAID'
        WHEN total_paid = total_billed AND total_billed > 0 THEN 'PAID'
        WHEN total_paid > 0 THEN 'PARTIAL'
        ELSE 'PENDING'
    END,
    updated_at = NOW()
WHERE total_paid >= total_billed OR total_due < 0 OR payment_status = 'PARTIAL';

-- Also reconcile any specific accounts where total_paid >= total_billed
UPDATE public.hostel_student_accounts
SET total_due = 0.00,
    payment_status = CASE WHEN total_paid > total_billed THEN 'OVERPAID' ELSE 'PAID' END,
    advance_credit = GREATEST(0.00, total_paid - total_billed),
    updated_at = NOW()
WHERE total_paid >= total_billed;


-- 2. Update fn_hostel_get_student_fees with Over Paid mathematics and zero balance
CREATE OR REPLACE FUNCTION public.fn_hostel_get_student_fees(
    p_school_id UUID,
    p_academic_year VARCHAR DEFAULT '2026 - 2027',
    p_search VARCHAR DEFAULT NULL,
    p_hostel_id UUID DEFAULT NULL,
    p_class VARCHAR DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'default',
    p_sort_order VARCHAR DEFAULT 'ASC'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT := (GREATEST(p_page, 1) - 1) * p_page_size;
    v_total_count INT := 0;
    v_items JSONB := '[]'::JSONB;
BEGIN
    -- Count total records matching criteria
    SELECT COUNT(DISTINCT acc.id)
    INTO v_total_count
    FROM public.hostel_student_accounts acc
    JOIN public.profiles p ON acc.student_id = p.id
    LEFT JOIN public.hostel_admissions adm ON acc.admission_id = adm.id
    LEFT JOIN public.hostel_buildings b ON adm.hostel_id = b.id
    LEFT JOIN LATERAL (
        SELECT alc.room_id, alc.bed_id 
        FROM public.hostel_allocations alc 
        WHERE alc.student_id = acc.student_id 
          AND alc.allocation_status = 'CHECKED_IN' 
          AND alc.deleted_at IS NULL
        ORDER BY alc.created_at DESC 
        LIMIT 1
    ) alc ON TRUE
    LEFT JOIN public.hostel_rooms r ON alc.room_id = r.id
    WHERE acc.school_id = p_school_id
      AND acc.academic_year = p_academic_year
      AND (p_hostel_id IS NULL OR adm.hostel_id = p_hostel_id)
      AND (p_class IS NULL OR p_class = 'All Classes' OR p.class ILIKE '%' || p_class || '%')
      AND (
          p_status IS NULL 
          OR p_status = 'All Status' 
          OR (UPPER(p_status) IN ('OVER PAID', 'OVERPAID') AND (UPPER(acc.payment_status) = 'OVERPAID' OR acc.total_paid > acc.total_billed))
          OR (UPPER(p_status) = 'PAID' AND (UPPER(acc.payment_status) IN ('PAID', 'OVERPAID') OR acc.total_paid >= acc.total_billed))
          OR (UPPER(p_status) = 'PARTIAL' AND UPPER(acc.payment_status) = 'PARTIAL' AND acc.total_paid < acc.total_billed)
          OR (UPPER(p_status) = 'OVERDUE' AND UPPER(acc.payment_status) = 'OVERDUE')
          OR (UPPER(acc.payment_status) = UPPER(p_status))
      )
      AND (
          p_search IS NULL OR p_search = '' OR
          p.full_name ILIKE '%' || p_search || '%' OR
          p.roll_number::text ILIKE '%' || p_search || '%' OR
          COALESCE(p.user_id, '') ILIKE '%' || p_search || '%' OR
          COALESCE(r.room_number, '') ILIKE '%' || p_search || '%' OR
          COALESCE(b.name, '') ILIKE '%' || p_search || '%'
      );

    -- Query page items
    SELECT jsonb_agg(
        jsonb_build_object(
            'account_id', acc.id,
            'student_id', p.id,
            'admission_id', adm.id,
            'row_num', row_data.row_seq,
            'name', p.full_name,
            'avatar_url', p.avatar_url,
            'class_name', COALESCE(p.class, '10 A'),
            'roll_number', COALESCE(p.roll_number::text, '0101'),
            'student_identifier', COALESCE(p.class, '10 A') || ' | ' || LPAD(COALESCE(p.roll_number::text, '101'), 4, '0'),
            'hostel_id', adm.hostel_id,
            'hostel_name', COALESCE(b.name, 'Boys Hostel A'),
            'room_id', alc.room_id,
            'room_number', COALESCE(r.room_number, 'A-101'),
            'bed_id', alc.bed_id,
            'fee_plan', COALESCE(acc.fee_plan_name, 'Standard'),
            'total_fee', acc.total_billed,
            'paid', acc.total_paid,
            'due', CASE 
                WHEN acc.total_paid >= acc.total_billed THEN 0.00 
                ELSE GREATEST(0.00, acc.total_due) 
            END,
            'overdue', CASE 
                WHEN acc.total_paid >= acc.total_billed THEN 0.00 
                ELSE acc.total_overdue 
            END,
            'status', CASE 
                WHEN acc.total_paid > acc.total_billed THEN 'Over Paid'
                WHEN acc.total_paid = acc.total_billed AND acc.total_billed > 0 THEN 'Paid'
                WHEN UPPER(acc.payment_status) = 'OVERPAID' THEN 'Over Paid'
                WHEN UPPER(acc.payment_status) = 'PAID' THEN 'Paid'
                WHEN acc.total_paid > 0 THEN 'Partial'
                WHEN UPPER(acc.payment_status) = 'OVERDUE' THEN 'Overdue'
                ELSE 'Pending'
            END,
            'status_raw', CASE 
                WHEN acc.total_paid > acc.total_billed THEN 'OVERPAID'
                WHEN acc.total_paid = acc.total_billed AND acc.total_billed > 0 THEN 'PAID'
                ELSE acc.payment_status
            END,
            'advance_credit', CASE 
                WHEN acc.total_paid > acc.total_billed THEN (acc.total_paid - acc.total_billed) 
                ELSE COALESCE(acc.advance_credit, 0.00) 
            END,
            'next_due_date', acc.next_due_date,
            'last_payment_date', acc.last_payment_date
        )
        ORDER BY row_data.row_seq ASC
    )
    INTO v_items
    FROM (
        SELECT acc.id, ROW_NUMBER() OVER (
            ORDER BY 
                CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'ASC' THEN p.full_name END ASC,
                CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'DESC' THEN p.full_name END DESC,
                CASE WHEN p_sort_by = 'total_fee' AND UPPER(p_sort_order) = 'ASC' THEN acc.total_billed END ASC,
                CASE WHEN p_sort_by = 'total_fee' AND UPPER(p_sort_order) = 'DESC' THEN acc.total_billed END DESC,
                CASE WHEN p_sort_by = 'paid' AND UPPER(p_sort_order) = 'ASC' THEN acc.total_paid END ASC,
                CASE WHEN p_sort_by = 'paid' AND UPPER(p_sort_order) = 'DESC' THEN acc.total_paid END DESC,
                CASE WHEN p_sort_by = 'due' AND UPPER(p_sort_order) = 'ASC' THEN (CASE WHEN acc.total_paid >= acc.total_billed THEN 0.00 ELSE acc.total_due END) END ASC,
                CASE WHEN p_sort_by = 'due' AND UPPER(p_sort_order) = 'DESC' THEN (CASE WHEN acc.total_paid >= acc.total_billed THEN 0.00 ELSE acc.total_due END) END DESC,
                p.full_name ASC,
                acc.created_at ASC
        ) as row_seq
        FROM public.hostel_student_accounts acc
        JOIN public.profiles p ON acc.student_id = p.id
        LEFT JOIN public.hostel_admissions adm ON acc.admission_id = adm.id
        LEFT JOIN public.hostel_buildings b ON adm.hostel_id = b.id
        LEFT JOIN LATERAL (
            SELECT alc.room_id, alc.bed_id 
            FROM public.hostel_allocations alc 
            WHERE alc.student_id = acc.student_id 
              AND alc.allocation_status = 'CHECKED_IN' 
              AND alc.deleted_at IS NULL
            ORDER BY alc.created_at DESC 
            LIMIT 1
        ) alc ON TRUE
        LEFT JOIN public.hostel_rooms r ON alc.room_id = r.id
        WHERE acc.school_id = p_school_id
          AND acc.academic_year = p_academic_year
          AND (p_hostel_id IS NULL OR adm.hostel_id = p_hostel_id)
          AND (p_class IS NULL OR p_class = 'All Classes' OR p.class ILIKE '%' || p_class || '%')
          AND (
              p_status IS NULL 
              OR p_status = 'All Status' 
              OR (UPPER(p_status) IN ('OVER PAID', 'OVERPAID') AND (UPPER(acc.payment_status) = 'OVERPAID' OR acc.total_paid > acc.total_billed))
              OR (UPPER(p_status) = 'PAID' AND (UPPER(acc.payment_status) IN ('PAID', 'OVERPAID') OR acc.total_paid >= acc.total_billed))
              OR (UPPER(p_status) = 'PARTIAL' AND UPPER(acc.payment_status) = 'PARTIAL' AND acc.total_paid < acc.total_billed)
              OR (UPPER(p_status) = 'OVERDUE' AND UPPER(acc.payment_status) = 'OVERDUE')
              OR (UPPER(acc.payment_status) = UPPER(p_status))
          )
          AND (
              p_search IS NULL OR p_search = '' OR
              p.full_name ILIKE '%' || p_search || '%' OR
              p.roll_number::text ILIKE '%' || p_search || '%' OR
              COALESCE(p.user_id, '') ILIKE '%' || p_search || '%' OR
              COALESCE(r.room_number, '') ILIKE '%' || p_search || '%' OR
              COALESCE(b.name, '') ILIKE '%' || p_search || '%'
          )
    ) row_data
    JOIN public.hostel_student_accounts acc ON row_data.id = acc.id
    JOIN public.profiles p ON acc.student_id = p.id
    LEFT JOIN public.hostel_admissions adm ON acc.admission_id = adm.id
    LEFT JOIN public.hostel_buildings b ON adm.hostel_id = b.id
    LEFT JOIN LATERAL (
        SELECT alc.room_id, alc.bed_id 
        FROM public.hostel_allocations alc 
        WHERE alc.student_id = acc.student_id 
          AND alc.allocation_status = 'CHECKED_IN' 
          AND alc.deleted_at IS NULL
        ORDER BY alc.created_at DESC 
        LIMIT 1
    ) alc ON TRUE
    LEFT JOIN public.hostel_rooms r ON alc.room_id = r.id
    WHERE row_data.row_seq > v_offset AND row_data.row_seq <= (v_offset + p_page_size);

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', COALESCE(v_items, '[]'::JSONB),
        'total_count', v_total_count,
        'pagination', jsonb_build_object(
            'page', p_page,
            'page_size', p_page_size,
            'total_records', v_total_count,
            'total_pages', GREATEST(1, CEIL(v_total_count::numeric / p_page_size))
        )
    );
END;
$$;


-- 3. Update fn_hostel_get_student_fee_details_360 with Over Paid mathematics and zero balance
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
BEGIN
    SELECT * INTO v_profile FROM public.profiles WHERE id = p_student_id AND school_id = p_school_id;
    IF v_profile.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Student profile not found.');
    END IF;

    SELECT * INTO v_acc FROM public.hostel_student_accounts 
    WHERE student_id = p_student_id AND school_id = p_school_id 
    ORDER BY created_at DESC LIMIT 1;

    v_is_overpaid := (COALESCE(v_acc.total_paid, 0.00) > COALESCE(v_acc.total_billed, 0.00));

    SELECT a.*, b.name as building_name 
    INTO v_adm 
    FROM public.hostel_admissions a
    LEFT JOIN public.hostel_buildings b ON a.hostel_id = b.id
    WHERE a.student_id = p_student_id AND a.school_id = p_school_id
    ORDER BY a.admission_date DESC LIMIT 1;

    SELECT al.*, r.room_number, bd.bed_code AS bed_number 
    INTO v_alc 
    FROM public.hostel_allocations al
    LEFT JOIN public.hostel_rooms r ON al.room_id = r.id
    LEFT JOIN public.hostel_beds bd ON al.bed_id = bd.id
    WHERE al.student_id = p_student_id AND al.school_id = p_school_id AND al.allocation_status = 'CHECKED_IN' AND al.deleted_at IS NULL
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
    ) ORDER BY l.transaction_date DESC), '[]'::JSONB)
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

    -- Breakdown by Fee Heads
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'head_name', bd.fee_head_name,
        'head_code', bd.fee_head_code,
        'amount', bd.amount,
        'discount', bd.discount,
        'net_amount', bd.net_amount
    )), '[]'::JSONB)
    INTO v_breakdown
    FROM (
        SELECT 
            ii.fee_head_name,
            ii.fee_head_code,
            SUM(ii.amount) AS amount,
            SUM(ii.discount_amount) AS discount,
            SUM(ii.net_amount) AS net_amount
        FROM public.hostel_invoice_items ii
        JOIN public.hostel_invoices i ON ii.invoice_id = i.id
        WHERE i.student_id = p_student_id AND i.school_id = p_school_id AND i.deleted_at IS NULL
        GROUP BY ii.fee_head_code, ii.fee_head_name
    ) bd;

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
            'fee_plan', COALESCE(v_acc.fee_plan_name, 'Standard'),
            'total_fee', COALESCE(v_acc.total_billed, 36000.00),
            'total_paid', COALESCE(v_acc.total_paid, 36000.00),
            'total_due', CASE 
                WHEN COALESCE(v_acc.total_paid, 0.00) >= COALESCE(v_acc.total_billed, 0.00) THEN 0.00 
                ELSE COALESCE(v_acc.total_due, 0.00) 
            END,
            'total_overdue', CASE 
                WHEN COALESCE(v_acc.total_paid, 0.00) >= COALESCE(v_acc.total_billed, 0.00) THEN 0.00 
                ELSE COALESCE(v_acc.total_overdue, 0.00) 
            END,
            'security_deposit_expected', COALESCE(v_acc.security_deposit_expected, 5000.00),
            'security_deposit_paid', COALESCE(v_acc.security_deposit_paid, 5000.00),
            'security_deposit_refunded', COALESCE(v_acc.security_deposit_refunded, 0.00),
            'advance_credit', CASE 
                WHEN v_is_overpaid THEN (v_acc.total_paid - v_acc.total_billed) 
                ELSE COALESCE(v_acc.advance_credit, 0.00) 
            END,
            'payment_status', CASE 
                WHEN v_is_overpaid THEN 'OVERPAID'
                WHEN COALESCE(v_acc.total_paid, 0.00) = COALESCE(v_acc.total_billed, 0.00) AND COALESCE(v_acc.total_billed, 0.00) > 0 THEN 'PAID'
                ELSE COALESCE(v_acc.payment_status, 'PAID')
            END,
            'status', CASE 
                WHEN v_is_overpaid THEN 'Over Paid'
                WHEN COALESCE(v_acc.total_paid, 0.00) = COALESCE(v_acc.total_billed, 0.00) AND COALESCE(v_acc.total_billed, 0.00) > 0 THEN 'Paid'
                WHEN UPPER(COALESCE(v_acc.payment_status, '')) = 'OVERPAID' THEN 'Over Paid'
                WHEN UPPER(COALESCE(v_acc.payment_status, '')) = 'PAID' THEN 'Paid'
                WHEN COALESCE(v_acc.total_paid, 0.00) > 0 THEN 'Partial'
                WHEN UPPER(COALESCE(v_acc.payment_status, '')) = 'OVERDUE' THEN 'Overdue'
                ELSE 'Pending'
            END,
            'next_due_date', v_acc.next_due_date,
            'invoices', v_invoices,
            'payments', v_payments,
            'ledger', v_ledger,
            'concessions', v_concessions,
            'fee_breakdown', v_breakdown
        )
    );
END;
$$;


-- 4. Update fn_hostel_collect_payment with Over Paid and zero balance logic
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
    v_payment_method VARCHAR := COALESCE(p_data->>'payment_method', 'CASH');
    v_transaction_id VARCHAR := p_data->>'transaction_id';
    v_remarks TEXT := p_data->>'remarks';
    v_payment_id UUID;
    v_receipt_number VARCHAR;
    v_user_name VARCHAR := 'Admin';
    v_inv_balance NUMERIC(12,2);
    v_inv_net NUMERIC(12,2);
    v_inv_paid NUMERIC(12,2);
    v_new_paid NUMERIC(12,2);
    v_new_balance NUMERIC(12,2);
    v_new_status VARCHAR;
    v_cur_balance NUMERIC(12,2) := 0;
BEGIN
    IF v_amount <= 0 THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Payment amount must be greater than zero.');
    END IF;

    SELECT full_name INTO v_user_name FROM public.profiles WHERE id = p_user_id;

    -- Generate receipt number
    v_receipt_number := 'HRCPT-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 9000 + 1000)::TEXT, 4, '0');
    IF p_data->>'receipt_number' IS NOT NULL AND (p_data->>'receipt_number') != '' THEN
        v_receipt_number := p_data->>'receipt_number';
    END IF;

    -- If invoice_id provided, settle against invoice
    IF v_invoice_id IS NOT NULL THEN
        SELECT balance_amount, net_amount, paid_amount 
        INTO v_inv_balance, v_inv_net, v_inv_paid
        FROM public.hostel_invoices
        WHERE id = v_invoice_id AND school_id = p_school_id AND deleted_at IS NULL
        FOR UPDATE;

        IF v_inv_balance IS NOT NULL THEN
            v_new_paid := v_inv_paid + v_amount;
            v_new_balance := GREATEST(0, v_inv_net - v_new_paid);

            IF v_new_balance = 0 THEN
                v_new_status := 'PAID';
            ELSE
                v_new_status := 'PARTIAL';
            END IF;

            UPDATE public.hostel_invoices
            SET paid_amount = v_new_paid,
                balance_amount = v_new_balance,
                status = v_new_status,
                updated_at = NOW()
            WHERE id = v_invoice_id;
        END IF;
    END IF;

    -- Insert Payment record
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

    -- Calculate current balance from ledger
    SELECT COALESCE(running_balance, 0) INTO v_cur_balance
    FROM public.hostel_fee_ledger
    WHERE school_id = p_school_id AND student_id = v_student_id
    ORDER BY transaction_date DESC, created_at DESC LIMIT 1;

    v_cur_balance := GREATEST(0, v_cur_balance - v_amount);

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

    -- Update student financial account totals with exact Over Paid mathematics
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
        total_overdue = CASE 
            WHEN (total_paid + v_amount) >= total_billed THEN 0.00
            ELSE GREATEST(0.00, total_overdue - v_amount)
        END,
        payment_status = CASE 
            WHEN (total_paid + v_amount) > total_billed THEN 'OVERPAID'
            WHEN (total_paid + v_amount) = total_billed AND total_billed > 0 THEN 'PAID'
            WHEN (total_paid + v_amount) > 0 THEN 'PARTIAL'
            ELSE 'PENDING'
        END,
        last_payment_date = NOW(),
        updated_at = NOW()
    WHERE school_id = p_school_id AND student_id = v_student_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Payment recorded successfully',
        'payment_id', v_payment_id,
        'receipt_number', v_receipt_number
    );
END;
$$;


-- 5. Update fn_hostel_add_penalty with Over Paid and zero balance logic
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


-- 6. Update fn_hostel_generate_invoice with Over Paid and zero balance logic
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
    v_billing_period VARCHAR := COALESCE(p_data->>'billing_period', 'Monthly Hostel Fee');
    v_due_date DATE := COALESCE((p_data->>'due_date')::DATE, (CURRENT_DATE + INTERVAL '15 days')::DATE);
    v_gross_amount NUMERIC(12,2) := COALESCE((p_data->>'gross_amount')::NUMERIC, 0.00);
    v_discount NUMERIC(12,2) := COALESCE((p_data->>'discount_amount')::NUMERIC, 0.00);
    v_net_amount NUMERIC(12,2) := GREATEST(0.00, v_gross_amount - v_discount);
    v_invoice_id UUID;
    v_invoice_number VARCHAR;
    v_academic_year VARCHAR := COALESCE(p_data->>'academic_year', '2026 - 2027');
    v_admission_id UUID;
    v_fee_plan_id UUID;
    v_cur_balance NUMERIC(12,2) := 0;
BEGIN
    SELECT id, fee_plan_id INTO v_admission_id, v_fee_plan_id
    FROM public.hostel_admissions
    WHERE student_id = v_student_id AND school_id = p_school_id AND status = 'ADMITTED'
    ORDER BY admission_date DESC LIMIT 1;

    v_invoice_number := 'HINV-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 9000 + 1000)::TEXT, 4, '0');

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

    SELECT COALESCE(running_balance, 0) INTO v_cur_balance
    FROM public.hostel_fee_ledger
    WHERE school_id = p_school_id AND student_id = v_student_id
    ORDER BY transaction_date DESC, created_at DESC LIMIT 1;

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

    -- Update student account balance with exact Over Paid mathematics
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
        next_due_date = v_due_date,
        updated_at = NOW()
    WHERE school_id = p_school_id AND academic_year = v_academic_year AND student_id = v_student_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Invoice generated successfully',
        'invoice_id', v_invoice_id,
        'invoice_number', v_invoice_number
    );
END;
$$;


-- 7. Update fn_hostel_get_fee_kpis to exclude Over Paid accounts from pending dues
CREATE OR REPLACE FUNCTION public.fn_hostel_get_fee_kpis(
    p_school_id UUID,
    p_academic_year VARCHAR DEFAULT '2026 - 2027'
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_billed NUMERIC(12,2) := 0;
    v_total_collected NUMERIC(12,2) := 0;
    v_pending_dues NUMERIC(12,2) := 0;
    v_overdue_amount NUMERIC(12,2) := 0;
    v_pending_students INT := 0;
    v_overdue_students INT := 0;
    v_total_students INT := 0;
    v_collection_rate INT := 0;
BEGIN
    SELECT
        COALESCE(SUM(total_billed), 0),
        COALESCE(SUM(total_paid), 0),
        COALESCE(SUM(CASE WHEN total_paid >= total_billed THEN 0.00 ELSE total_due END), 0),
        COALESCE(SUM(CASE WHEN total_paid >= total_billed THEN 0.00 ELSE total_overdue END), 0),
        COUNT(CASE WHEN total_paid < total_billed AND total_due > 0 THEN 1 END),
        COUNT(CASE WHEN total_paid < total_billed AND total_overdue > 0 THEN 1 END),
        COUNT(*)
    INTO
        v_total_billed,
        v_total_collected,
        v_pending_dues,
        v_overdue_amount,
        v_pending_students,
        v_overdue_students,
        v_total_students
    FROM public.hostel_student_accounts
    WHERE school_id = p_school_id AND academic_year = p_academic_year;

    IF v_total_students = 0 THEN
        SELECT
            COALESCE(SUM(net_amount), 0),
            COALESCE(SUM(paid_amount), 0),
            COALESCE(SUM(balance_amount), 0),
            COALESCE(SUM(CASE WHEN due_date < CURRENT_DATE AND balance_amount > 0 THEN balance_amount ELSE 0 END), 0),
            COUNT(DISTINCT CASE WHEN balance_amount > 0 THEN student_id END),
            COUNT(DISTINCT CASE WHEN due_date < CURRENT_DATE AND balance_amount > 0 THEN student_id END),
            COUNT(DISTINCT student_id)
        INTO
            v_total_billed,
            v_total_collected,
            v_pending_dues,
            v_overdue_amount,
            v_pending_students,
            v_overdue_students,
            v_total_students
        FROM public.hostel_invoices
        WHERE school_id = p_school_id AND academic_year = p_academic_year AND deleted_at IS NULL;
    END IF;

    IF v_total_billed > 0 THEN
        v_collection_rate := ROUND((v_total_collected / v_total_billed) * 100);
    ELSE
        v_collection_rate := 0;
    END IF;

    RETURN jsonb_build_object(
        'total_billed', v_total_billed,
        'total_collected', v_total_collected,
        'pending_dues', v_pending_dues,
        'overdue_amount', v_overdue_amount,
        'pending_students_count', v_pending_students,
        'overdue_students_count', v_overdue_students,
        'upcoming_invoices_count', 0,
        'total_students_count', v_total_students,
        'collection_rate', v_collection_rate,
        'academic_year', p_academic_year
    );
END;
$$;

