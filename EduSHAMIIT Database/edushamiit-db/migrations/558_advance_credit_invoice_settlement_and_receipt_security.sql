-- Migration 558: Advance Credit Invoice Settlement Engine and Receipt Deletion Audit Protection

-- 1. Create Stored Procedure to safely void only uncompleted/voidable payment records
CREATE OR REPLACE FUNCTION public.fn_void_student_payment(
    p_school_id UUID,
    p_payment_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_status TEXT;
    v_amt NUMERIC(12,2);
    v_inv_id UUID;
    v_rcpt TEXT;
    v_student_id UUID;
BEGIN
    SELECT status, amount_paid, invoice_id, receipt_number, student_id
    INTO v_status, v_amt, v_inv_id, v_rcpt, v_student_id
    FROM public.student_fee_payments
    WHERE id = p_payment_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Payment receipt not found');
    END IF;

    -- Strict Anti-Fraud Guard: Completed/cleared payments cannot be deleted
    IF UPPER(COALESCE(v_status, '')) IN ('COMPLETED', 'SUCCESS', 'CLEARED', 'PAID') OR v_amt > 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Completed payment receipts are audit-locked and cannot be deleted to prevent fraud and maintain financial compliance.'
        );
    END IF;

    IF v_inv_id IS NOT NULL THEN
        UPDATE public.student_fee_invoices
        SET paid_amount = GREATEST(0, paid_amount - v_amt),
            balance_amount = balance_amount + v_amt,
            status = 'Pending',
            updated_at = NOW()
        WHERE id = v_inv_id;
    END IF;

    DELETE FROM public.student_fee_payments WHERE id = p_payment_id;

    RETURN jsonb_build_object('success', true, 'message', 'Payment record voided successfully');
END;
$function$;

-- 2. Stored Procedure: Settle a specific invoice using student's available Advance Credit Wallet
CREATE OR REPLACE FUNCTION public.fn_settle_invoice_from_advance(
    p_school_id UUID,
    p_invoice_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Admin',
    p_user_email TEXT DEFAULT '',
    p_user_role TEXT DEFAULT 'Staff'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_inv RECORD;
    v_student_id UUID;
    v_total_paid NUMERIC(12,2) := 0.0;
    v_total_billed NUMERIC(12,2) := 0.0;
    v_advance_avail NUMERIC(12,2) := 0.0;
    v_deduct NUMERIC(12,2) := 0.0;
    v_new_paid NUMERIC(12,2);
    v_new_bal NUMERIC(12,2);
    v_new_status TEXT;
    v_receipt_num TEXT;
    v_pay_id UUID;
BEGIN
    SELECT * INTO v_inv
    FROM public.student_fee_invoices
    WHERE id = p_invoice_id AND school_id = p_school_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invoice not found');
    END IF;

    IF v_inv.balance_amount <= 0 OR v_inv.status = 'Paid' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invoice is already fully settled');
    END IF;

    v_student_id := v_inv.student_id;

    -- Live unallocated advance credit calculation
    SELECT 
        COALESCE(SUM(i.total_billed), 0.0),
        COALESCE(SUM(i.paid_amount), 0.0) + COALESCE((
            SELECT SUM(pay.amount_paid) 
            FROM public.student_fee_payments pay 
            WHERE pay.student_id = v_student_id AND pay.school_id = p_school_id 
              AND pay.invoice_id IS NULL
              AND (pay.status IS NULL OR pay.status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS'))
        ), 0.0)
    INTO v_total_billed, v_total_paid
    FROM public.student_fee_invoices i
    WHERE i.student_id = v_student_id AND i.school_id = p_school_id;

    v_advance_avail := GREATEST(0.0, v_total_paid - v_total_billed);

    IF v_advance_avail <= 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Student does not have any advance credit wallet balance available'
        );
    END IF;

    v_deduct := LEAST(v_inv.balance_amount, v_advance_avail);
    v_new_paid := v_inv.paid_amount + v_deduct;
    v_new_bal := GREATEST(0.0, v_inv.total_billed - v_new_paid);
    IF v_new_bal <= 0 THEN
        v_new_status := 'Paid';
    ELSE
        v_new_status := 'Partial';
    END IF;

    -- Update invoice
    UPDATE public.student_fee_invoices
    SET paid_amount = v_new_paid,
        balance_amount = v_new_bal,
        status = v_new_status,
        updated_at = NOW()
    WHERE id = p_invoice_id;

    -- Generate receipt number
    v_receipt_num := 'REC-ADV-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD((FLOOR(RANDOM() * 90000 + 10000))::TEXT, 5, '0');

    -- Insert payment record with Advance Credit Wallet mode
    INSERT INTO public.student_fee_payments (
        school_id, student_id, invoice_id, receipt_number, amount_paid,
        payment_method, transaction_reference, status, remarks, recorded_by
    ) VALUES (
        p_school_id, v_student_id, p_invoice_id, v_receipt_num, v_deduct,
        'Advance Credit Wallet', 'ADV-WALLET-' || SUBSTRING(p_invoice_id::TEXT, 1, 8),
        'COMPLETED', 'Auto-settled from student advance credit wallet balance', p_user_id
    ) RETURNING id INTO v_pay_id;

    -- Insert audit log
    INSERT INTO public.student_fee_audit_logs (
        school_id, student_id, entity_type, entity_id, action,
        description, amount, performed_by_id, performed_by_name,
        performed_by_email, performed_by_role
    ) VALUES (
        p_school_id, v_student_id, 'PAYMENT', v_pay_id, 'PAYMENT_COLLECTED',
        'Settled ₹' || TO_CHAR(v_deduct, 'FM99,99,990.00') || ' from Advance Credit Wallet for invoice ' || v_inv.invoice_number,
        v_deduct, p_user_id, p_user_name, p_user_email, p_user_role
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Successfully settled ₹' || TO_CHAR(v_deduct, 'FM99,99,990.00') || ' from advance credit',
        'deducted_amount', v_deduct,
        'remaining_balance', v_new_bal,
        'new_status', v_new_status,
        'receipt_number', v_receipt_num,
        'remaining_advance', GREATEST(0.0, v_advance_avail - v_deduct)
    );
END;
$function$;

-- 3. Stored Procedure: Auto-settle ALL pending invoices for a student using advance credit
CREATE OR REPLACE FUNCTION public.fn_settle_student_invoices_from_advance(
    p_school_id UUID,
    p_student_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Admin',
    p_user_email TEXT DEFAULT '',
    p_user_role TEXT DEFAULT 'Staff'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_inv RECORD;
    v_total_paid NUMERIC(12,2) := 0.0;
    v_total_billed NUMERIC(12,2) := 0.0;
    v_advance_avail NUMERIC(12,2) := 0.0;
    v_settled_count INT := 0;
    v_total_deducted NUMERIC(12,2) := 0.0;
    v_res JSONB;
BEGIN
    -- Live unallocated advance credit calculation
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

    v_advance_avail := GREATEST(0.0, v_total_paid - v_total_billed);

    IF v_advance_avail <= 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Student does not have any advance credit wallet balance available'
        );
    END IF;

    -- Iterate over pending/partial invoices ordered by due date
    FOR v_inv IN (
        SELECT id, invoice_number, balance_amount
        FROM public.student_fee_invoices
        WHERE student_id = p_student_id 
          AND school_id = p_school_id 
          AND balance_amount > 0
        ORDER BY due_date ASC, created_at ASC
    ) LOOP
        IF v_advance_avail <= 0 THEN
            EXIT;
        END IF;

        v_res := public.fn_settle_invoice_from_advance(
            p_school_id, v_inv.id, p_user_id, p_user_name, p_user_email, p_user_role
        );

        IF (v_res->>'success')::BOOLEAN = true THEN
            v_settled_count := v_settled_count + 1;
            v_total_deducted := v_total_deducted + (v_res->>'deducted_amount')::NUMERIC;
            v_advance_avail := (v_res->>'remaining_advance')::NUMERIC;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Auto-settled ' || v_settled_count::TEXT || ' invoice(s) using ₹' || TO_CHAR(v_total_deducted, 'FM99,99,990.00') || ' of advance credit',
        'invoices_settled', v_settled_count,
        'total_deducted', v_total_deducted,
        'remaining_advance', v_advance_avail
    );
END;
$function$;

-- 4. Update fn_create_student_fee_invoice to auto-deduct available advance credit
CREATE OR REPLACE FUNCTION public.fn_create_student_fee_invoice(
    p_school_id uuid,
    p_student_id uuid,
    p_fee_type text,
    p_fee_plan text,
    p_academic_year text,
    p_amount numeric,
    p_due_date date,
    p_title text DEFAULT NULL::text,
    p_notes text DEFAULT NULL::text,
    p_user_id uuid DEFAULT NULL::uuid,
    p_user_name text DEFAULT 'Admin'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_seq INT := 0;
    v_inv_num TEXT;
    v_inv_id UUID;
    v_title TEXT := COALESCE(p_title, p_fee_type || ' - ' || p_academic_year);
    v_total_paid NUMERIC(12,2) := 0.0;
    v_total_billed NUMERIC(12,2) := 0.0;
    v_advance_avail NUMERIC(12,2) := 0.0;
    v_deduct NUMERIC(12,2) := 0.0;
    v_balance NUMERIC(12,2) := p_amount;
    v_status TEXT := 'Pending';
    v_receipt_num TEXT;
    v_pay_id UUID;
BEGIN
    SELECT COALESCE(
        MAX(NULLIF(regexp_replace(invoice_number, '^INV-[0-9]{4}-', ''), '')::INT),
        0
    ) + 1 INTO v_seq
    FROM public.student_fee_invoices
    WHERE school_id = p_school_id
      AND invoice_number ~ '^INV-[0-9]{4}-[0-9]+$';

    LOOP
        v_inv_num := 'INV-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(v_seq::TEXT, 5, '0');
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM public.student_fee_invoices 
            WHERE school_id = p_school_id AND invoice_number = v_inv_num
        );
        v_seq := v_seq + 1;
    END LOOP;

    -- Check if student has advance credit wallet balance
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

    v_advance_avail := GREATEST(0.0, v_total_paid - v_total_billed);

    IF v_advance_avail > 0 THEN
        v_deduct := LEAST(p_amount, v_advance_avail);
        v_balance := p_amount - v_deduct;
        IF v_balance <= 0 THEN
            v_status := 'Paid';
        ELSE
            v_status := 'Partial';
        END IF;
    END IF;

    INSERT INTO public.student_fee_invoices (
        school_id, student_id, invoice_number, title, fee_type,
        fee_plan, academic_year, billing_date, due_date, subtotal,
        total_billed, paid_amount, balance_amount, status, notes
    ) VALUES (
        p_school_id, p_student_id, v_inv_num, v_title, p_fee_type,
        p_fee_plan, p_academic_year, CURRENT_DATE, p_due_date, p_amount,
        p_amount, v_deduct, v_balance, v_status, p_notes
    ) RETURNING id INTO v_inv_id;

    -- If advance credit was deducted, record a payment receipt and audit log
    IF v_deduct > 0 THEN
        v_receipt_num := 'REC-ADV-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD((FLOOR(RANDOM() * 90000 + 10000))::TEXT, 5, '0');
        
        INSERT INTO public.student_fee_payments (
            school_id, student_id, invoice_id, receipt_number, amount_paid,
            payment_method, transaction_reference, status, remarks, recorded_by
        ) VALUES (
            p_school_id, p_student_id, v_inv_id, v_receipt_num, v_deduct,
            'Advance Credit Wallet', 'ADV-NEW-INV-' || SUBSTRING(v_inv_id::TEXT, 1, 8),
            'COMPLETED', 'Auto-settled from advance credit on invoice generation', p_user_id
        ) RETURNING id INTO v_pay_id;

        INSERT INTO public.student_fee_audit_logs (
            school_id, student_id, entity_type, entity_id, action,
            description, amount, performed_by_id, performed_by_name
        ) VALUES (
            p_school_id, p_student_id, 'PAYMENT', v_pay_id, 'PAYMENT_COLLECTED',
            'Auto-applied ₹' || TO_CHAR(v_deduct, 'FM99,99,990.00') || ' from Advance Credit Wallet on invoice ' || v_inv_num,
            v_deduct, p_user_id, p_user_name
        );
    END IF;

    -- Audit log for invoice creation
    INSERT INTO public.student_fee_audit_logs (
        school_id, student_id, entity_type, entity_id, action,
        description, amount, performed_by_id, performed_by_name
    ) VALUES (
        p_school_id, p_student_id, 'INVOICE', v_inv_id, 'INVOICE_GENERATED',
        'Generated invoice ' || v_inv_num || ' for ' || p_fee_type || ' of ₹' || TO_CHAR(p_amount, 'FM99,99,990.00') || 
        (CASE WHEN v_deduct > 0 THEN ' (₹' || TO_CHAR(v_deduct, 'FM99,99,990.00') || ' settled via advance credit)' ELSE '' END),
        p_amount, p_user_id, p_user_name
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Invoice generated successfully' || (CASE WHEN v_deduct > 0 THEN ' and settled via advance credit' ELSE '' END),
        'invoice_id', v_inv_id,
        'invoice_number', v_inv_num,
        'advance_deducted', v_deduct,
        'balance_remaining', v_balance,
        'status', v_status
    );
END;
$function$;

-- 6. Enhance fn_list_all_student_invoices to return live student_advance_balance for each invoice
CREATE OR REPLACE FUNCTION public.fn_list_all_student_invoices(
    p_school_id uuid,
    p_search text DEFAULT NULL::text,
    p_status text DEFAULT NULL::text,
    p_page integer DEFAULT 1,
    p_page_size integer DEFAULT 15
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_clean_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_clean_size INT := GREATEST(1, LEAST(100, COALESCE(p_page_size, 15)));
    v_offset INT := (v_clean_page - 1) * v_clean_size;
    v_total_items INT := 0;
    v_total_pages INT := 1;
    v_invoices JSONB := '[]'::jsonb;
BEGIN
    WITH filtered AS (
        SELECT 
            i.id, i.invoice_number, i.title, i.fee_type, i.fee_plan, i.due_date,
            i.total_billed, i.paid_amount, i.balance_amount, i.status,
            i.student_id, p.full_name AS student_name, p.roll_number, p.class AS class_name,
            i.created_at,
            GREATEST(0.0, 
                COALESCE((
                    SELECT SUM(pay.amount_paid) 
                    FROM public.student_fee_payments pay 
                    WHERE pay.student_id = i.student_id AND pay.school_id = p_school_id 
                      AND pay.invoice_id IS NULL
                      AND (pay.status IS NULL OR pay.status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS'))
                ), 0.0) +
                COALESCE((
                    SELECT SUM(inv2.paid_amount) 
                    FROM public.student_fee_invoices inv2 
                    WHERE inv2.student_id = i.student_id AND inv2.school_id = p_school_id
                ), 0.0) -
                COALESCE((
                    SELECT SUM(inv3.total_billed) 
                    FROM public.student_fee_invoices inv3 
                    WHERE inv3.student_id = i.student_id AND inv3.school_id = p_school_id
                ), 0.0)
            ) AS student_advance_balance
        FROM public.student_fee_invoices i
        JOIN public.profiles p ON i.student_id = p.id
        WHERE i.school_id = p_school_id
          AND (p_status IS NULL OR p_status = 'All Status' OR p_status = 'All' OR i.status = p_status)
          AND (
              p_search IS NULL OR p_search = '' OR (
                  i.invoice_number ILIKE '%' || p_search || '%' OR
                  p.full_name ILIKE '%' || p_search || '%' OR
                  p.roll_number::text ILIKE '%' || p_search || '%' OR
                  i.title ILIKE '%' || p_search || '%'
              )
          )
    ),
    counted AS (
        SELECT COUNT(*) AS total_count FROM filtered
    ),
    sorted_page AS (
        SELECT f.*, c.total_count
        FROM filtered f
        CROSS JOIN counted c
        ORDER BY f.created_at DESC
        LIMIT v_clean_size OFFSET v_offset
    )
    SELECT 
        MAX(sp.total_count),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', sp.id,
                    'invoice_number', sp.invoice_number,
                    'title', sp.title,
                    'fee_type', sp.fee_type,
                    'fee_plan', sp.fee_plan,
                    'due_date', sp.due_date,
                    'total_billed', sp.total_billed,
                    'paid_amount', sp.paid_amount,
                    'balance_amount', sp.balance_amount,
                    'status', sp.status,
                    'student_id', sp.student_id,
                    'student_name', sp.student_name,
                    'roll_number', sp.roll_number,
                    'class_name', sp.class_name,
                    'created_at', sp.created_at,
                    'student_advance_balance', sp.student_advance_balance
                )
            ), '[]'::jsonb
        ) INTO v_total_items, v_invoices
    FROM sorted_page sp;

    v_total_items := COALESCE(v_total_items, 0);
    IF v_total_items > 0 THEN
        v_total_pages := CEIL(v_total_items::numeric / v_clean_size);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'invoices', v_invoices,
        'pagination', jsonb_build_object(
            'page', v_clean_page,
            'page_size', v_clean_size,
            'total_items', v_total_items,
            'total_pages', v_total_pages
        )
    );
END;
$function$;


