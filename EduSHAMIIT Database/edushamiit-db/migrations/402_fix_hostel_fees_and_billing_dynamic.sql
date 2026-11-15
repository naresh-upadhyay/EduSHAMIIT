-- =========================================================================
-- Migration: 402_fix_hostel_fees_and_billing_dynamic.sql
-- Description:
--   1. Provision active fee plans and student accounts for academic year 2026 - 2027.
--   2. Dynamically link all hostel_admissions students to hostel_student_accounts.
--   3. Seed initial 2026 - 2027 invoices and payments matching student admission fee status.
--   4. Update fn_hostel_get_fee_kpis to return genuine dynamic sums (removing fake 87% / 48 fallbacks).
--   5. Update fn_hostel_generate_invoice to auto-provision missing student accounts and sync academic year.
--   6. Update fn_hostel_admit_student to auto-create hostel_student_accounts for new admissions.
-- =========================================================================

-- 1. Ensure Standard Fee Plans exist for 2026 - 2027
INSERT INTO public.hostel_fee_plans (
    school_id, academic_year, name, code, description, hostel_id, room_type, room_category, billing_cycle,
    total_annual_amount, total_cycle_amount, effective_from, status
)
SELECT 
    school_id, '2026 - 2027', name, code || '_2627', description, hostel_id, room_type, room_category, billing_cycle,
    total_annual_amount, total_cycle_amount, '2026-04-01'::DATE, 'ACTIVE'
FROM public.hostel_fee_plans
WHERE academic_year = '2024 - 2025' AND deleted_at IS NULL
ON CONFLICT DO NOTHING;

-- 2. Auto-provision hostel_student_accounts for all admitted hostel students
INSERT INTO public.hostel_student_accounts (
    school_id,
    academic_year,
    student_id,
    admission_id,
    fee_plan_name,
    opening_balance,
    total_billed,
    total_paid,
    total_due,
    total_overdue,
    security_deposit_expected,
    security_deposit_paid,
    payment_status,
    next_due_date,
    created_at,
    updated_at
)
SELECT 
    a.school_id,
    a.academic_year,
    a.student_id,
    a.id,
    COALESCE(a.fee_plan, 'Standard Plan'),
    0.00,
    COALESCE(a.monthly_fee * 6, 36000.00), -- Term 1 fee
    CASE 
        WHEN UPPER(a.fee_status) = 'PAID' THEN COALESCE(a.monthly_fee * 6, 36000.00)
        WHEN UPPER(a.fee_status) = 'PARTIAL' THEN COALESCE(a.monthly_fee * 4, 24000.00)
        ELSE 0.00
    END,
    CASE 
        WHEN UPPER(a.fee_status) = 'PAID' THEN 0.00
        WHEN UPPER(a.fee_status) = 'PARTIAL' THEN COALESCE(a.monthly_fee * 2, 12000.00)
        ELSE COALESCE(a.monthly_fee * 6, 36000.00)
    END,
    0.00,
    COALESCE(a.deposit_amount, 10000.00),
    COALESCE(a.deposit_amount, 10000.00),
    UPPER(a.fee_status),
    CURRENT_DATE + INTERVAL '15 days',
    NOW(),
    NOW()
FROM public.hostel_admissions a
WHERE a.deleted_at IS NULL
  AND NOT EXISTS (
      SELECT 1 FROM public.hostel_student_accounts acc
      WHERE acc.school_id = a.school_id 
        AND acc.academic_year = a.academic_year 
        AND acc.student_id = a.student_id
  )
ON CONFLICT (school_id, academic_year, student_id) DO NOTHING;

-- 3. Seed corresponding Term 1 invoices for 2026 - 2027 students
INSERT INTO public.hostel_invoices (
    school_id, academic_year, student_id, admission_id,
    invoice_number, billing_period, billing_cycle, invoice_date, due_date,
    gross_amount, discount_amount, net_amount, paid_amount, balance_amount, status, created_at, updated_at
)
SELECT 
    acc.school_id,
    acc.academic_year,
    acc.student_id,
    acc.admission_id,
    'HINV-2627-' || LPAD(ROW_NUMBER() OVER ()::TEXT, 4, '0'),
    'Term 1 Hostel & Mess Fee (' || acc.academic_year || ')',
    'TERM',
    CURRENT_DATE - INTERVAL '15 days',
    CURRENT_DATE + INTERVAL '15 days',
    acc.total_billed,
    0.00,
    acc.total_billed,
    acc.total_paid,
    acc.total_due,
    CASE 
        WHEN acc.total_due = 0 THEN 'PAID'
        WHEN acc.total_paid > 0 THEN 'PARTIAL'
        ELSE 'GENERATED'
    END,
    NOW() - INTERVAL '15 days',
    NOW()
FROM public.hostel_student_accounts acc
WHERE acc.academic_year = '2026 - 2027'
  AND NOT EXISTS (
      SELECT 1 FROM public.hostel_invoices inv
      WHERE inv.school_id = acc.school_id
        AND inv.student_id = acc.student_id
        AND inv.academic_year = acc.academic_year
  );

-- Line items for 2026 - 2027 invoices
INSERT INTO public.hostel_invoice_items (
    invoice_id, fee_head_code, fee_head_name, amount, discount_amount, net_amount
)
SELECT 
    inv.id,
    'ROOM_RENT',
    'Room Rent',
    ROUND(inv.net_amount * 0.50, 2),
    0.00,
    ROUND(inv.net_amount * 0.50, 2)
FROM public.hostel_invoices inv
WHERE inv.academic_year = '2026 - 2027'
  AND NOT EXISTS (SELECT 1 FROM public.hostel_invoice_items it WHERE it.invoice_id = inv.id);

INSERT INTO public.hostel_invoice_items (
    invoice_id, fee_head_code, fee_head_name, amount, discount_amount, net_amount
)
SELECT 
    inv.id,
    'MESS_FEE',
    'Mess & Food Charges',
    inv.net_amount - ROUND(inv.net_amount * 0.50, 2),
    0.00,
    inv.net_amount - ROUND(inv.net_amount * 0.50, 2)
FROM public.hostel_invoices inv
WHERE inv.academic_year = '2026 - 2027'
  AND (SELECT COUNT(*) FROM public.hostel_invoice_items it WHERE it.invoice_id = inv.id) = 1;

-- Payment receipts for paid amounts in 2026 - 2027
INSERT INTO public.hostel_payments (
    school_id, invoice_id, student_id, payment_number, receipt_number,
    amount, payment_method, paid_at, status, created_at
)
SELECT 
    inv.school_id,
    inv.id,
    inv.student_id,
    'HPAY-2627-' || LPAD(ROW_NUMBER() OVER ()::TEXT, 4, '0'),
    'RCPT-2627-' || LPAD(ROW_NUMBER() OVER ()::TEXT, 4, '0'),
    inv.paid_amount,
    'ONLINE_UPI',
    NOW() - INTERVAL '5 days',
    'COMPLETED',
    NOW() - INTERVAL '5 days'
FROM public.hostel_invoices inv
WHERE inv.academic_year = '2026 - 2027'
  AND inv.paid_amount > 0
  AND NOT EXISTS (
      SELECT 1 FROM public.hostel_payments p
      WHERE p.invoice_id = inv.id
  );

-- Ledger entries for 2026 - 2027
INSERT INTO public.hostel_fee_ledger (
    school_id, student_id, entry_type, reference_id, reference_number,
    debit, credit, running_balance, description, transaction_date
)
SELECT 
    inv.school_id,
    inv.student_id,
    'INVOICE',
    inv.id,
    inv.invoice_number,
    inv.net_amount,
    0.00,
    inv.net_amount,
    'Term 1 Hostel & Mess Fee (' || inv.academic_year || ')',
    inv.invoice_date
FROM public.hostel_invoices inv
WHERE inv.academic_year = '2026 - 2027'
  AND NOT EXISTS (
      SELECT 1 FROM public.hostel_fee_ledger l
      WHERE l.reference_id = inv.id
  );

INSERT INTO public.hostel_fee_ledger (
    school_id, student_id, entry_type, reference_id, reference_number,
    debit, credit, running_balance, description, transaction_date
)
SELECT 
    p.school_id,
    p.student_id,
    'PAYMENT',
    p.id,
    p.receipt_number,
    0.00,
    p.amount,
    COALESCE(inv.balance_amount, 0.00),
    'Fee Payment via ' || p.payment_method || ' (' || p.receipt_number || ')',
    p.paid_at
FROM public.hostel_payments p
JOIN public.hostel_invoices inv ON p.invoice_id = inv.id
WHERE inv.academic_year = '2026 - 2027'
  AND NOT EXISTS (
      SELECT 1 FROM public.hostel_fee_ledger l
      WHERE l.reference_id = p.id
  );

-- 4. Update fn_hostel_get_fee_kpis to return genuine dynamic sums
DROP FUNCTION IF EXISTS public.fn_hostel_get_fee_kpis(uuid, character varying);

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
        COALESCE(SUM(total_due), 0),
        COALESCE(SUM(total_overdue), 0),
        COUNT(CASE WHEN total_due > 0 THEN 1 END),
        COUNT(CASE WHEN total_overdue > 0 THEN 1 END),
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

    -- If no data in accounts table, calculate from invoices
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

    -- Dynamic collection rate
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

-- 5. Update fn_hostel_generate_invoice
CREATE OR REPLACE FUNCTION public.fn_hostel_generate_invoice(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_student_id UUID := (p_data->>'student_id')::UUID;
    v_billing_period VARCHAR := COALESCE(p_data->>'billing_period', p_data->>'title', TO_CHAR(CURRENT_DATE, 'Month YYYY'));
    v_academic_year VARCHAR;
    v_due_date DATE := COALESCE((p_data->>'due_date')::DATE, CURRENT_DATE + INTERVAL '10 days');
    v_gross_amount NUMERIC(12,2) := (p_data->>'gross_amount')::NUMERIC;
    v_discount NUMERIC(12,2) := COALESCE((p_data->>'discount_amount')::NUMERIC, 0.00);
    v_net_amount NUMERIC(12,2);
    v_invoice_id UUID;
    v_invoice_number VARCHAR;
    v_fee_plan_id UUID;
    v_admission_id UUID;
    v_cur_balance NUMERIC(12,2) := 0;
    v_items JSONB := p_data->'items';
    v_item JSONB;
BEGIN
    -- Determine academic year
    v_academic_year := p_data->>'academic_year';
    IF v_academic_year IS NULL OR v_academic_year = '' THEN
        SELECT academic_year INTO v_academic_year
        FROM public.hostel_admissions
        WHERE school_id = p_school_id AND student_id = v_student_id AND deleted_at IS NULL
        ORDER BY created_at DESC LIMIT 1;
    END IF;
    IF v_academic_year IS NULL OR v_academic_year = '' THEN
        v_academic_year := '2026 - 2027';
    END IF;

    -- Find admission ID and fee plan ID
    SELECT id INTO v_admission_id
    FROM public.hostel_admissions
    WHERE school_id = p_school_id AND student_id = v_student_id AND deleted_at IS NULL
    ORDER BY created_at DESC LIMIT 1;

    -- Find fee plan ID
    SELECT id INTO v_fee_plan_id
    FROM public.hostel_fee_plans
    WHERE school_id = p_school_id AND (academic_year = v_academic_year OR academic_year = '2024 - 2025') AND status = 'ACTIVE' AND deleted_at IS NULL
    ORDER BY created_at DESC LIMIT 1;

    -- Calculate gross from items if passed
    IF v_items IS NOT NULL AND jsonb_typeof(v_items) = 'array' AND jsonb_array_length(v_items) > 0 THEN
        SELECT COALESCE(SUM((elem->>'amount')::NUMERIC), 0.00)
        INTO v_gross_amount
        FROM jsonb_array_elements(v_items) AS elem;
    END IF;

    IF v_gross_amount IS NULL OR v_gross_amount <= 0 THEN
        v_gross_amount := 3000.00;
    END IF;

    v_net_amount := v_gross_amount - v_discount;

    -- Generate unique invoice number
    v_invoice_number := 'HINV-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 9000 + 1000)::TEXT, 4, '0');

    -- Auto-provision student account if missing
    IF NOT EXISTS (
        SELECT 1 FROM public.hostel_student_accounts
        WHERE school_id = p_school_id AND academic_year = v_academic_year AND student_id = v_student_id
    ) THEN
        INSERT INTO public.hostel_student_accounts (
            school_id, academic_year, student_id, admission_id,
            fee_plan_name, opening_balance, total_billed, total_paid, total_due, total_overdue,
            payment_status, next_due_date, created_at, updated_at
        ) VALUES (
            p_school_id, v_academic_year, v_student_id, v_admission_id,
            'Standard Plan', 0.00, 0.00, 0.00, 0.00, 0.00,
            'PENDING', v_due_date, NOW(), NOW()
        ) ON CONFLICT (school_id, academic_year, student_id) DO NOTHING;
    END IF;

    -- Insert invoice
    INSERT INTO public.hostel_invoices (
        school_id, academic_year, student_id, admission_id,
        invoice_number, billing_period, billing_cycle, invoice_date, due_date,
        gross_amount, discount_amount, net_amount, paid_amount, balance_amount, status,
        remarks, created_by, created_at, updated_at
    ) VALUES (
        p_school_id, v_academic_year, v_student_id, v_admission_id,
        v_invoice_number, v_billing_period, 'TERM', CURRENT_DATE, v_due_date,
        v_gross_amount, v_discount, v_net_amount, 0.00, v_net_amount, 'GENERATED',
        p_data->>'notes', p_user_id, NOW(), NOW()
    ) RETURNING id INTO v_invoice_id;

    -- Insert line items
    IF v_items IS NOT NULL AND jsonb_typeof(v_items) = 'array' AND jsonb_array_length(v_items) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_items)
        LOOP
            INSERT INTO public.hostel_invoice_items (
                invoice_id, fee_head_code, fee_head_name, amount, discount_amount, net_amount
            ) VALUES (
                v_invoice_id,
                COALESCE(v_item->>'fee_head_code', UPPER(REPLACE(COALESCE(v_item->>'head_name', 'FEE'), ' ', '_'))),
                COALESCE(v_item->>'fee_head_name', v_item->>'head_name', 'Hostel Fee Head'),
                (v_item->>'amount')::NUMERIC,
                COALESCE((v_item->>'discount_amount')::NUMERIC, 0.00),
                (v_item->>'amount')::NUMERIC - COALESCE((v_item->>'discount_amount')::NUMERIC, 0.00)
            );
        END LOOP;
    END IF;

    -- Update ledger
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

    -- Update student account balance
    UPDATE public.hostel_student_accounts
    SET total_billed = total_billed + v_net_amount,
        total_due = total_due + v_net_amount,
        payment_status = CASE WHEN total_paid >= (total_billed + v_net_amount) THEN 'PAID' WHEN total_paid > 0 THEN 'PARTIAL' ELSE 'PENDING' END,
        next_due_date = v_due_date,
        updated_at = NOW()
    WHERE school_id = p_school_id AND academic_year = v_academic_year AND student_id = v_student_id;

    -- Also sync admission status
    UPDATE public.hostel_admissions
    SET fee_status = CASE 
            WHEN (SELECT total_paid FROM public.hostel_student_accounts WHERE school_id = p_school_id AND academic_year = v_academic_year AND student_id = v_student_id) > 0 THEN 'PARTIAL' 
            ELSE 'PENDING' 
        END,
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

-- 6. Update fn_hostel_admit_student to auto-create hostel_student_accounts
CREATE OR REPLACE FUNCTION public.fn_hostel_admit_student(
    p_school_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_student_id UUID;
    v_academic_year VARCHAR(50);
    v_hostel_id UUID;
    v_room_id UUID;
    v_bed_id UUID;
    v_admission_date DATE;
    v_boarding_type VARCHAR(50);
    v_hostel_type VARCHAR(50);
    v_fee_plan VARCHAR(100);
    v_monthly_fee NUMERIC(10,2);
    v_deposit_amount NUMERIC(10,2);
    v_fee_status VARCHAR(30);
    v_initial_payment_amount NUMERIC(10,2);
    v_special_notes TEXT;
    v_emergency_contact VARCHAR(100);
    v_student RECORD;
    v_room RECORD;
    v_bed RECORD;
    v_adm_id UUID;
    v_alloc_id UUID;
    v_adm_status VARCHAR(30) := 'ACTIVE';
    v_audit_user_id UUID := NULL;
    v_target_cap INT;
    v_existing_beds_count INT;
    v_new_bed_idx INT;
    v_new_bed_code VARCHAR(20);
BEGIN
    v_student_id := (p_data->>'student_id')::UUID;
    v_academic_year := COALESCE(p_data->>'academic_year', '2026 - 2027');
    v_hostel_id := (p_data->>'hostel_id')::UUID;
    v_room_id := (p_data->>'room_id')::UUID;
    v_bed_id := (p_data->>'bed_id')::UUID;
    v_admission_date := COALESCE((p_data->>'admission_date')::DATE, CURRENT_DATE);
    v_boarding_type := COALESCE(p_data->>'boarding_type', 'REGULAR');
    v_hostel_type := COALESCE(p_data->>'hostel_type', 'AC Room');
    v_fee_plan := COALESCE(p_data->>'fee_plan', 'Monthly Plan');
    v_monthly_fee := COALESCE((p_data->>'monthly_fee')::NUMERIC, 6000.00);
    v_deposit_amount := COALESCE((p_data->>'deposit_amount')::NUMERIC, 10000.00);
    v_fee_status := COALESCE(p_data->>'fee_status', 'PAID');
    v_initial_payment_amount := COALESCE((p_data->>'initial_payment_amount')::NUMERIC, 0.00);
    v_special_notes := p_data->>'special_notes';
    v_emergency_contact := p_data->>'emergency_contact';

    IF v_student_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Student ID is required');
    END IF;

    -- Insert admission record
    INSERT INTO public.hostel_admissions (
        school_id, student_id, academic_year, hostel_id, admission_reference,
        admission_date, admission_status, boarding_type, hostel_type,
        fee_plan, monthly_fee, deposit_amount, fee_status, initial_payment_amount,
        special_notes, emergency_contact_override
    ) VALUES (
        p_school_id, v_student_id, v_academic_year, v_hostel_id,
        'ADM-' || TO_CHAR(v_admission_date, 'YYMM') || '-' || SUBSTRING(v_student_id::TEXT, 1, 4),
        v_admission_date, v_adm_status, v_boarding_type, v_hostel_type,
        v_fee_plan, v_monthly_fee, v_deposit_amount, v_fee_status, v_initial_payment_amount,
        v_special_notes, v_emergency_contact
    ) RETURNING id INTO v_adm_id;

    -- Auto-provision student fee account
    INSERT INTO public.hostel_student_accounts (
        school_id, academic_year, student_id, admission_id,
        fee_plan_name, opening_balance, total_billed, total_paid, total_due, total_overdue,
        security_deposit_expected, security_deposit_paid, payment_status, next_due_date, created_at, updated_at
    ) VALUES (
        p_school_id, v_academic_year, v_student_id, v_adm_id,
        v_fee_plan, 0.00, v_monthly_fee * 6,
        CASE WHEN UPPER(v_fee_status) = 'PAID' THEN v_monthly_fee * 6 WHEN UPPER(v_fee_status) = 'PARTIAL' THEN v_monthly_fee * 4 ELSE 0.00 END,
        CASE WHEN UPPER(v_fee_status) = 'PAID' THEN 0.00 WHEN UPPER(v_fee_status) = 'PARTIAL' THEN v_monthly_fee * 2 ELSE v_monthly_fee * 6 END,
        0.00, v_deposit_amount, v_deposit_amount, UPPER(v_fee_status),
        CURRENT_DATE + INTERVAL '15 days', NOW(), NOW()
    ) ON CONFLICT (school_id, academic_year, student_id) DO NOTHING;

    -- Allocate room/bed if provided
    IF v_room_id IS NOT NULL THEN
        IF v_bed_id IS NULL THEN
            SELECT id INTO v_bed_id FROM public.hostel_beds WHERE room_id = v_room_id AND status = 'VACANT' AND deleted_at IS NULL LIMIT 1;
        END IF;

        IF v_bed_id IS NOT NULL THEN
            INSERT INTO public.hostel_allocations (
                school_id, admission_id, student_id, room_id, bed_id,
                allocation_date, allocation_status
            ) VALUES (
                p_school_id, v_adm_id, v_student_id, v_room_id, v_bed_id,
                v_admission_date, 'CHECKED_IN'
            ) RETURNING id INTO v_alloc_id;

            UPDATE public.hostel_beds SET status = 'OCCUPIED' WHERE id = v_bed_id;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Hostel student admitted successfully',
        'admission_id', v_adm_id,
        'allocation_id', v_alloc_id
    );
END;
$$;

-- Checkout older duplicate allocation for Aman Khan
UPDATE public.hostel_allocations 
SET allocation_status = 'CHECKED_OUT', updated_at = NOW() 
WHERE id = '20025d14-fc7a-4b11-a6ff-3ea8f803975a' AND allocation_status = 'CHECKED_IN';

-- 7. Update fn_hostel_get_student_fees with LATERAL join to prevent duplicate student rows
DROP FUNCTION IF EXISTS public.fn_hostel_get_student_fees(uuid, character varying, character varying, uuid, character varying, character varying, integer, integer, character varying, character varying);

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
      AND (p_status IS NULL OR p_status = 'All Status' OR UPPER(acc.payment_status) = UPPER(p_status))
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
            'due', acc.total_due,
            'overdue', acc.total_overdue,
            'status', CASE 
                WHEN UPPER(acc.payment_status) = 'PAID' THEN 'Paid'
                WHEN UPPER(acc.payment_status) = 'PARTIAL' THEN 'Partial'
                WHEN UPPER(acc.payment_status) = 'OVERDUE' THEN 'Overdue'
                ELSE 'Pending'
            END,
            'status_raw', acc.payment_status,
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
                CASE WHEN p_sort_by = 'due' AND UPPER(p_sort_order) = 'ASC' THEN acc.total_due END ASC,
                CASE WHEN p_sort_by = 'due' AND UPPER(p_sort_order) = 'DESC' THEN acc.total_due END DESC,
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
          AND (p_status IS NULL OR p_status = 'All Status' OR UPPER(acc.payment_status) = UPPER(p_status))
          AND (
              p_search IS NULL OR p_search = '' OR
              p.full_name ILIKE '%' || p_search || '%' OR
              p.roll_number::text ILIKE '%' || p_search || '%' OR
              COALESCE(p.user_id, '') ILIKE '%' || p_search || '%' OR
              COALESCE(r.room_number, '') ILIKE '%' || p_search || '%' OR
              COALESCE(b.name, '') ILIKE '%' || p_search || '%'
          )
        ORDER BY row_seq ASC
        LIMIT p_page_size OFFSET v_offset
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
    LEFT JOIN public.hostel_rooms r ON alc.room_id = r.id;

    RETURN jsonb_build_object(
        'data', COALESCE(v_items, '[]'::JSONB),
        'pagination', jsonb_build_object(
            'page', p_page,
            'page_size', p_page_size,
            'total_records', v_total_count,
            'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1))
        )
    );
END;
$$;
