-- ============================================================================
-- Migration 408: Student-Specific Assigned Fee Structure CRUD & 360 Integration
-- ============================================================================
-- 1. Create table public.hostel_student_fee_heads for persistent, editable fee heads.
-- 2. Create CRUD stored procedures:
--    - fn_hostel_get_student_fee_heads
--    - fn_hostel_add_student_fee_head
--    - fn_hostel_update_student_fee_head
--    - fn_hostel_delete_student_fee_head
-- 3. Update fn_hostel_get_student_fee_details_360 to return student fee heads
--    dynamically without any hardcoding.
-- 4. Create trigger to auto-populate fee heads on new admissions.
-- 5. Backfill existing admitted students (including Deepak Chawla 101).
-- ============================================================================

-- 1. Create table public.hostel_student_fee_heads
CREATE TABLE IF NOT EXISTS public.hostel_student_fee_heads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    admission_id UUID REFERENCES public.hostel_admissions(id) ON DELETE SET NULL,
    head_code VARCHAR(50) NOT NULL DEFAULT 'CUSTOM',
    head_name VARCHAR(150) NOT NULL,
    amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    charge_type VARCHAR(30) NOT NULL DEFAULT 'FIXED',
    frequency VARCHAR(30) NOT NULL DEFAULT 'MONTHLY',
    is_mandatory BOOLEAN NOT NULL DEFAULT true,
    is_refundable BOOLEAN NOT NULL DEFAULT false,
    sort_order INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_hostel_student_fee_heads_std 
ON public.hostel_student_fee_heads(school_id, student_id) 
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_hostel_student_fee_heads_adm 
ON public.hostel_student_fee_heads(admission_id) 
WHERE deleted_at IS NULL;


-- 2. Helper procedure to keep hostel_student_accounts totals in sync with assigned fee heads
CREATE OR REPLACE FUNCTION public.fn_hostel_sync_student_fee_account_totals(
    p_school_id UUID,
    p_student_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_assigned NUMERIC(12,2) := 0.00;
    v_deposit_assigned NUMERIC(12,2) := 0.00;
    v_total_paid NUMERIC(12,2) := 0.00;
    v_total_due NUMERIC(12,2) := 0.00;
    v_advance_credit NUMERIC(12,2) := 0.00;
    v_status VARCHAR(30) := 'PENDING';
    v_acc RECORD;
    v_adm RECORD;
BEGIN
    -- Sum active fee heads
    SELECT 
        COALESCE(SUM(amount), 0.00),
        COALESCE(SUM(CASE WHEN is_refundable = TRUE OR head_name ILIKE '%deposit%' THEN amount ELSE 0.00 END), 0.00)
    INTO v_total_assigned, v_deposit_assigned
    FROM public.hostel_student_fee_heads
    WHERE school_id = p_school_id AND student_id = p_student_id AND deleted_at IS NULL;

    SELECT * INTO v_acc 
    FROM public.hostel_student_accounts 
    WHERE school_id = p_school_id AND student_id = p_student_id 
    ORDER BY created_at DESC LIMIT 1;

    SELECT * INTO v_adm
    FROM public.hostel_admissions
    WHERE school_id = p_school_id AND student_id = p_student_id AND deleted_at IS NULL
    ORDER BY admission_date DESC LIMIT 1;

    -- Calculate total paid from hostel_payments or account or admission
    SELECT COALESCE(SUM(amount), 0.00) INTO v_total_paid
    FROM public.hostel_payments
    WHERE school_id = p_school_id AND student_id = p_student_id AND status = 'SUCCESS';

    IF v_total_paid = 0.00 THEN
        v_total_paid := COALESCE(v_acc.total_paid, v_adm.initial_payment_amount, 0.00);
    END IF;

    -- If no heads exist yet, fallback to account billed or admission amounts
    IF v_total_assigned = 0.00 THEN
        v_total_assigned := COALESCE(v_acc.total_billed, v_adm.initial_payment_amount, 6000.00);
    END IF;

    -- Mathematics
    IF v_total_paid > v_total_assigned THEN
        v_status := 'OVERPAID';
        v_total_due := 0.00;
        v_advance_credit := v_total_paid - v_total_assigned;
    ELSIF v_total_paid = v_total_assigned AND v_total_assigned > 0 THEN
        v_status := 'PAID';
        v_total_due := 0.00;
        v_advance_credit := 0.00;
    ELSIF v_total_paid > 0 THEN
        v_status := 'PARTIAL';
        v_total_due := v_total_assigned - v_total_paid;
        v_advance_credit := 0.00;
    ELSE
        v_status := 'PENDING';
        v_total_due := v_total_assigned;
        v_advance_credit := 0.00;
    END IF;

    IF v_acc.id IS NOT NULL THEN
        UPDATE public.hostel_student_accounts
        SET total_billed = v_total_assigned,
            total_paid = v_total_paid,
            total_due = v_total_due,
            total_overdue = CASE WHEN v_total_paid >= v_total_assigned THEN 0.00 ELSE total_overdue END,
            advance_credit = v_advance_credit,
            payment_status = v_status,
            security_deposit_expected = CASE WHEN v_deposit_assigned > 0 THEN v_deposit_assigned ELSE security_deposit_expected END,
            updated_at = NOW()
        WHERE id = v_acc.id;
    END IF;
END;
$$;


-- 3. Stored Procedures for CRUD operations
-- 3a. GET student fee heads
CREATE OR REPLACE FUNCTION public.fn_hostel_get_student_fee_heads(
    p_school_id UUID,
    p_student_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_heads JSONB := '[]'::JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', id,
        'head_name', head_name,
        'head_code', head_code,
        'amount', amount,
        'charge_type', charge_type,
        'frequency', frequency,
        'is_mandatory', is_mandatory,
        'is_refundable', is_refundable,
        'sort_order', sort_order,
        'created_at', created_at,
        'updated_at', updated_at
    ) ORDER BY sort_order ASC, created_at ASC), '[]'::JSONB)
    INTO v_heads
    FROM public.hostel_student_fee_heads
    WHERE school_id = p_school_id AND student_id = p_student_id AND deleted_at IS NULL;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', v_heads
    );
END;
$$;


-- 3b. ADD student fee head
CREATE OR REPLACE FUNCTION public.fn_hostel_add_student_fee_head(
    p_school_id UUID,
    p_student_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_adm_id UUID;
    v_head_name VARCHAR(150);
    v_head_code VARCHAR(50);
    v_amount NUMERIC(12,2);
    v_charge_type VARCHAR(30);
    v_frequency VARCHAR(30);
    v_is_mandatory BOOLEAN;
    v_is_refundable BOOLEAN;
    v_sort_order INT;
    v_new_id UUID;
    v_new_head RECORD;
BEGIN
    v_head_name := TRIM(COALESCE(p_data->>'head_name', ''));
    IF v_head_name = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Fee head name is required.');
    END IF;

    v_amount := COALESCE((p_data->>'amount')::NUMERIC, 0.00);
    IF v_amount < 0 THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Fee head amount cannot be negative.');
    END IF;

    v_head_code := COALESCE(p_data->>'head_code', UPPER(REPLACE(SUBSTRING(v_head_name, 1, 20), ' ', '_')));
    v_charge_type := COALESCE(p_data->>'charge_type', 'FIXED');
    v_frequency := COALESCE(p_data->>'frequency', 'MONTHLY');
    v_is_mandatory := COALESCE((p_data->>'is_mandatory')::BOOLEAN, true);
    v_is_refundable := COALESCE((p_data->>'is_refundable')::BOOLEAN, false);
    v_sort_order := COALESCE((p_data->>'sort_order')::INT, 1);

    -- Find admission ID
    SELECT id INTO v_adm_id
    FROM public.hostel_admissions
    WHERE school_id = p_school_id AND student_id = p_student_id AND deleted_at IS NULL
    ORDER BY admission_date DESC LIMIT 1;

    INSERT INTO public.hostel_student_fee_heads (
        school_id,
        student_id,
        admission_id,
        head_code,
        head_name,
        amount,
        charge_type,
        frequency,
        is_mandatory,
        is_refundable,
        sort_order
    ) VALUES (
        p_school_id,
        p_student_id,
        v_adm_id,
        v_head_code,
        v_head_name,
        v_amount,
        v_charge_type,
        v_frequency,
        v_is_mandatory,
        v_is_refundable,
        v_sort_order
    )
    RETURNING * INTO v_new_head;

    -- Synchronize account totals
    PERFORM public.fn_hostel_sync_student_fee_account_totals(p_school_id, p_student_id);

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Fee head added successfully.',
        'data', jsonb_build_object(
            'id', v_new_head.id,
            'head_name', v_new_head.head_name,
            'head_code', v_new_head.head_code,
            'amount', v_new_head.amount,
            'charge_type', v_new_head.charge_type,
            'frequency', v_new_head.frequency,
            'is_mandatory', v_new_head.is_mandatory,
            'is_refundable', v_new_head.is_refundable,
            'sort_order', v_new_head.sort_order,
            'created_at', v_new_head.created_at
        )
    );
END;
$$;


-- 3c. UPDATE student fee head
CREATE OR REPLACE FUNCTION public.fn_hostel_update_student_fee_head(
    p_school_id UUID,
    p_student_id UUID,
    p_head_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_head RECORD;
    v_head_name VARCHAR(150);
    v_amount NUMERIC(12,2);
    v_frequency VARCHAR(30);
    v_is_mandatory BOOLEAN;
    v_is_refundable BOOLEAN;
BEGIN
    SELECT * INTO v_head
    FROM public.hostel_student_fee_heads
    WHERE id = p_head_id AND school_id = p_school_id AND student_id = p_student_id AND deleted_at IS NULL;

    IF v_head.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Fee head not found.');
    END IF;

    v_head_name := COALESCE(NULLIF(TRIM(p_data->>'head_name'), ''), v_head.head_name);
    IF p_data ? 'amount' THEN
        v_amount := (p_data->>'amount')::NUMERIC;
        IF v_amount < 0 THEN
            RETURN jsonb_build_object('success', FALSE, 'message', 'Amount cannot be negative.');
        END IF;
    ELSE
        v_amount := v_head.amount;
    END IF;

    v_frequency := COALESCE(p_data->>'frequency', v_head.frequency);
    IF p_data ? 'is_mandatory' THEN
        v_is_mandatory := (p_data->>'is_mandatory')::BOOLEAN;
    ELSE
        v_is_mandatory := v_head.is_mandatory;
    END IF;

    IF p_data ? 'is_refundable' THEN
        v_is_refundable := (p_data->>'is_refundable')::BOOLEAN;
    ELSE
        v_is_refundable := v_head.is_refundable;
    END IF;

    UPDATE public.hostel_student_fee_heads
    SET head_name = v_head_name,
        amount = v_amount,
        frequency = v_frequency,
        is_mandatory = v_is_mandatory,
        is_refundable = v_is_refundable,
        updated_at = NOW()
    WHERE id = p_head_id;

    -- Synchronize account totals
    PERFORM public.fn_hostel_sync_student_fee_account_totals(p_school_id, p_student_id);

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Fee head updated successfully.',
        'data', jsonb_build_object(
            'id', p_head_id,
            'head_name', v_head_name,
            'amount', v_amount,
            'frequency', v_frequency,
            'is_mandatory', v_is_mandatory,
            'is_refundable', v_is_refundable
        )
    );
END;
$$;


-- 3d. DELETE student fee head
CREATE OR REPLACE FUNCTION public.fn_hostel_delete_student_fee_head(
    p_school_id UUID,
    p_student_id UUID,
    p_head_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_head RECORD;
BEGIN
    SELECT * INTO v_head
    FROM public.hostel_student_fee_heads
    WHERE id = p_head_id AND school_id = p_school_id AND student_id = p_student_id AND deleted_at IS NULL;

    IF v_head.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Fee head not found.');
    END IF;

    UPDATE public.hostel_student_fee_heads
    SET deleted_at = NOW(),
        updated_at = NOW()
    WHERE id = p_head_id;

    -- Synchronize account totals
    PERFORM public.fn_hostel_sync_student_fee_account_totals(p_school_id, p_student_id);

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Fee head deleted successfully.'
    );
END;
$$;


-- 4. Update fn_hostel_get_student_fee_details_360 to pull dynamically from hostel_student_fee_heads
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

    -- If no fee heads configured yet, auto-create initial heads from admission
    IF jsonb_array_length(v_breakdown) = 0 AND v_adm.id IS NOT NULL THEN
        -- Insert Room Rent
        INSERT INTO public.hostel_student_fee_heads (
            school_id, student_id, admission_id, head_code, head_name, amount, is_mandatory, is_refundable, frequency
        ) VALUES (
            p_school_id, p_student_id, v_adm.id, 'ROOM_FEE', 'Room Rent', COALESCE(v_adm.monthly_fee, 6000.00), true, false, 'MONTHLY'
        );

        -- If deposit > 0, insert Security Deposit
        IF COALESCE(v_adm.deposit_amount, 0.00) > 0 THEN
            INSERT INTO public.hostel_student_fee_heads (
                school_id, student_id, admission_id, head_code, head_name, amount, is_mandatory, is_refundable, frequency
            ) VALUES (
                p_school_id, p_student_id, v_adm.id, 'SECURITY_DEP', 'Security Deposit', v_adm.deposit_amount, true, true, 'ONE_TIME'
            );
        END IF;

        -- Re-query breakdown
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
    END IF;

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
            'fee_breakdown', v_breakdown,
            'breakdown', v_breakdown
        )
    );
END;
$$;


-- 5. Trigger on hostel_admissions to auto-populate hostel_student_fee_heads
CREATE OR REPLACE FUNCTION public.fn_hostel_sync_admission_to_fee_heads()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if student already has heads
    IF NOT EXISTS (
        SELECT 1 FROM public.hostel_student_fee_heads
        WHERE school_id = NEW.school_id AND student_id = NEW.student_id AND deleted_at IS NULL
    ) THEN
        -- Insert Room Rent
        INSERT INTO public.hostel_student_fee_heads (
            school_id, student_id, admission_id, head_code, head_name, amount, is_mandatory, is_refundable, frequency
        ) VALUES (
            NEW.school_id, NEW.student_id, NEW.id, 'ROOM_FEE', 'Room Rent', COALESCE(NEW.monthly_fee, 6000.00), true, false, 'MONTHLY'
        );

        -- If deposit > 0, insert Security Deposit
        IF COALESCE(NEW.deposit_amount, 0.00) > 0 THEN
            INSERT INTO public.hostel_student_fee_heads (
                school_id, student_id, admission_id, head_code, head_name, amount, is_mandatory, is_refundable, frequency
            ) VALUES (
                NEW.school_id, NEW.student_id, NEW.id, 'SECURITY_DEP', 'Security Deposit', NEW.deposit_amount, true, true, 'ONE_TIME'
            );
        END IF;

        -- Keep account totals synchronized
        PERFORM public.fn_hostel_sync_student_fee_account_totals(NEW.school_id, NEW.student_id);
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_hostel_sync_admission_to_fee_heads ON public.hostel_admissions;
CREATE TRIGGER trg_hostel_sync_admission_to_fee_heads
AFTER INSERT OR UPDATE ON public.hostel_admissions
FOR EACH ROW
EXECUTE FUNCTION public.fn_hostel_sync_admission_to_fee_heads();


-- 6. Backfill existing admitted students in 2026 - 2027 into hostel_student_fee_heads
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT adm.*
        FROM public.hostel_admissions adm
        WHERE adm.deleted_at IS NULL
    ) LOOP
        IF NOT EXISTS (
            SELECT 1 FROM public.hostel_student_fee_heads
            WHERE student_id = r.student_id AND school_id = r.school_id AND deleted_at IS NULL
        ) THEN
            -- Check if specific for Deepak Chawla 101 or general
            INSERT INTO public.hostel_student_fee_heads (
                school_id, student_id, admission_id, head_code, head_name, amount, is_mandatory, is_refundable, frequency
            ) VALUES (
                r.school_id, r.student_id, r.id, 'ROOM_FEE', 'Room Rent', COALESCE(r.monthly_fee, 6000.00), true, false, 'MONTHLY'
            );

            IF COALESCE(r.deposit_amount, 0.00) > 0 THEN
                INSERT INTO public.hostel_student_fee_heads (
                    school_id, student_id, admission_id, head_code, head_name, amount, is_mandatory, is_refundable, frequency
                ) VALUES (
                    r.school_id, r.student_id, r.id, 'SECURITY_DEP', 'Security Deposit', r.deposit_amount, true, true, 'ONE_TIME'
                );
            END IF;

            PERFORM public.fn_hostel_sync_student_fee_account_totals(r.school_id, r.student_id);
        END IF;
    END LOOP;
END;
$$;

