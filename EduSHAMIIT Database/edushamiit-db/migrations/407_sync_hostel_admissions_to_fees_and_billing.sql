-- ==============================================================================
-- Migration: 407_sync_hostel_admissions_to_fees_and_billing.sql
-- Description: Unify Hostel Students and Fees & Billing. Make hostel_admissions
--              the canonical Single Source of Truth across the system.
--              Automatically sync hostel_student_accounts, hostel_invoices, and
--              hostel_payments on student admission, and make fn_hostel_get_student_fees
--              drive from hostel_admissions so no admitted student is ever missing.
-- ==============================================================================

-- 1. Sync function and trigger from hostel_admissions to hostel_student_accounts
CREATE OR REPLACE FUNCTION public.fn_hostel_sync_admission_to_fee_account()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_multiplier INT := 1;
    v_term_fee NUMERIC(12,2);
    v_deposit NUMERIC(12,2);
    v_total_billed NUMERIC(12,2);
    v_initial_paid NUMERIC(12,2);
    v_due NUMERIC(12,2);
    v_status VARCHAR(30);
    v_inv_no VARCHAR(100);
    v_pay_no VARCHAR(100);
    v_rec_no VARCHAR(100);
    v_existing_inv_id UUID;
    v_existing_acc RECORD;
BEGIN
    IF NEW.deleted_at IS NOT NULL THEN
        -- If admission is deleted, mark account or soft-delete
        RETURN NEW;
    END IF;

    -- Determine plan multiplier
    IF NEW.fee_plan ILIKE '%Annual%' OR NEW.fee_plan ILIKE '%Year%' THEN
        v_multiplier := 12;
    ELSIF NEW.fee_plan ILIKE '%Quarter%' THEN
        v_multiplier := 3;
    ELSIF NEW.fee_plan ILIKE '%Half%' OR NEW.fee_plan ILIKE '%Bi%' THEN
        v_multiplier := 6;
    ELSE
        v_multiplier := 1;
    END IF;

    v_term_fee := COALESCE(NEW.monthly_fee, 6000.00) * v_multiplier;
    v_deposit := COALESCE(NEW.deposit_amount, 10000.00);
    v_total_billed := v_term_fee + v_deposit;

    -- Initial paid amount
    IF NEW.initial_payment_amount IS NOT NULL AND NEW.initial_payment_amount > 0 THEN
        v_initial_paid := NEW.initial_payment_amount;
    ELSIF UPPER(COALESCE(NEW.fee_status, '')) = 'PAID' THEN
        v_initial_paid := v_total_billed;
    ELSIF UPPER(COALESCE(NEW.fee_status, '')) = 'PARTIAL' THEN
        v_initial_paid := v_term_fee;
    ELSE
        v_initial_paid := 0.00;
    END IF;

    -- Due & Status
    IF v_initial_paid >= v_total_billed THEN
        v_due := 0.00;
        IF v_initial_paid > v_total_billed THEN
            v_status := 'OVERPAID';
        ELSE
            v_status := 'PAID';
        END IF;
    ELSIF v_initial_paid > 0 THEN
        v_due := v_total_billed - v_initial_paid;
        v_status := 'PARTIAL';
    ELSE
        v_due := v_total_billed;
        v_status := 'PENDING';
    END IF;

    -- Upsert hostel_student_accounts
    SELECT * INTO v_existing_acc
    FROM public.hostel_student_accounts
    WHERE school_id = NEW.school_id 
      AND academic_year = NEW.academic_year 
      AND student_id = NEW.student_id;

    IF v_existing_acc IS NULL THEN
        INSERT INTO public.hostel_student_accounts (
            school_id, academic_year, student_id, admission_id,
            fee_plan_name, opening_balance, total_billed, total_paid, total_due, total_overdue,
            total_concession, advance_credit, security_deposit_expected, security_deposit_paid,
            payment_status, next_due_date, created_at, updated_at
        ) VALUES (
            NEW.school_id, NEW.academic_year, NEW.student_id, NEW.id,
            COALESCE(NEW.fee_plan, 'Monthly'), 0.00, v_total_billed, v_initial_paid, v_due, 0.00,
            0.00, CASE WHEN v_initial_paid > v_total_billed THEN (v_initial_paid - v_total_billed) ELSE 0.00 END,
            v_deposit, LEAST(v_initial_paid, v_deposit),
            v_status, CURRENT_DATE + INTERVAL '15 days', NOW(), NOW()
        );
    ELSE
        UPDATE public.hostel_student_accounts
        SET admission_id = NEW.id,
            fee_plan_name = COALESCE(NEW.fee_plan, fee_plan_name),
            total_billed = GREATEST(total_billed, v_total_billed),
            total_paid = GREATEST(total_paid, v_initial_paid),
            total_due = CASE 
                WHEN GREATEST(total_paid, v_initial_paid) >= GREATEST(total_billed, v_total_billed) THEN 0.00 
                ELSE (GREATEST(total_billed, v_total_billed) - GREATEST(total_paid, v_initial_paid)) 
            END,
            advance_credit = CASE 
                WHEN GREATEST(total_paid, v_initial_paid) > GREATEST(total_billed, v_total_billed) THEN (GREATEST(total_paid, v_initial_paid) - GREATEST(total_billed, v_total_billed)) 
                ELSE advance_credit 
            END,
            payment_status = CASE 
                WHEN GREATEST(total_paid, v_initial_paid) > GREATEST(total_billed, v_total_billed) THEN 'OVERPAID'
                WHEN GREATEST(total_paid, v_initial_paid) = GREATEST(total_billed, v_total_billed) AND GREATEST(total_billed, v_total_billed) > 0 THEN 'PAID'
                WHEN GREATEST(total_paid, v_initial_paid) > 0 THEN 'PARTIAL'
                ELSE 'PENDING'
            END,
            updated_at = NOW()
        WHERE id = v_existing_acc.id;
    END IF;

    -- Ensure an initial invoice exists in hostel_invoices
    SELECT id INTO v_existing_inv_id
    FROM public.hostel_invoices
    WHERE student_id = NEW.student_id 
      AND academic_year = NEW.academic_year 
      AND deleted_at IS NULL
    LIMIT 1;

    IF v_existing_inv_id IS NULL THEN
        v_inv_no := 'INV-' || TO_CHAR(CURRENT_DATE, 'YYYYMM') || '-' || SUBSTRING(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 8);
        INSERT INTO public.hostel_invoices (
            school_id, academic_year, student_id, admission_id,
            invoice_number, billing_period, billing_cycle, invoice_date, due_date,
            gross_amount, discount_amount, penalty_amount, net_amount, paid_amount, balance_amount,
            status, remarks
        ) VALUES (
            NEW.school_id, NEW.academic_year, NEW.student_id, NEW.id,
            v_inv_no, TO_CHAR(CURRENT_DATE, 'Mon YYYY'), 'MONTHLY', CURRENT_DATE, CURRENT_DATE + INTERVAL '15 days',
            v_total_billed, 0.00, 0.00, v_total_billed, v_initial_paid, v_due,
            v_status, 'Hostel admission fee invoice'
        ) 
        ON CONFLICT (school_id, invoice_number) WHERE deleted_at IS NULL DO NOTHING
        RETURNING id INTO v_existing_inv_id;
    END IF;

    -- Ensure initial payment exists if paid amount > 0
    IF v_initial_paid > 0 AND NOT EXISTS (
        SELECT 1 FROM public.hostel_payments 
        WHERE student_id = NEW.student_id AND school_id = NEW.school_id
    ) THEN
        v_pay_no := 'PAY-' || TO_CHAR(CURRENT_DATE, 'YYYYMM') || '-' || SUBSTRING(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 8);
        v_rec_no := 'REC-' || TO_CHAR(CURRENT_DATE, 'YYYYMM') || '-' || SUBSTRING(REPLACE(gen_random_uuid()::TEXT, '-', ''), 1, 8);
        INSERT INTO public.hostel_payments (
            school_id, student_id, invoice_id, payment_number, receipt_number,
            amount, payment_method, status, remarks, paid_at
        ) VALUES (
            NEW.school_id, NEW.student_id, v_existing_inv_id,
            v_pay_no, v_rec_no, v_initial_paid, 'ONLINE_UPI', 'COMPLETED',
            'Hostel admission initial payment', NOW()
        )
        ON CONFLICT (school_id, receipt_number) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_hostel_sync_admission_to_fee_account ON public.hostel_admissions;
CREATE TRIGGER trg_hostel_sync_admission_to_fee_account
AFTER INSERT OR UPDATE ON public.hostel_admissions
FOR EACH ROW
EXECUTE FUNCTION public.fn_hostel_sync_admission_to_fee_account();


-- 2. Update fn_hostel_get_student_fees to drive from hostel_admissions
--    Guarantees every student admitted to hostel appears in Fees & Billing
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
    -- Count total records matching criteria directly from hostel_admissions
    SELECT COUNT(DISTINCT adm.id)
    INTO v_total_count
    FROM public.hostel_admissions adm
    JOIN public.profiles p ON adm.student_id = p.id
    LEFT JOIN public.hostel_buildings b ON adm.hostel_id = b.id
    LEFT JOIN public.hostel_student_accounts acc ON (
        acc.student_id = adm.student_id 
        AND acc.academic_year = adm.academic_year 
        AND acc.school_id = adm.school_id
    )
    LEFT JOIN LATERAL (
        SELECT alc.room_id, alc.bed_id 
        FROM public.hostel_allocations alc 
        WHERE (alc.admission_id = adm.id OR alc.student_id = adm.student_id)
          AND alc.allocation_status IN ('CHECKED_IN', 'RESERVED', 'CONFIRMED')
          AND alc.deleted_at IS NULL
        ORDER BY alc.created_at DESC 
        LIMIT 1
    ) alc ON TRUE
    LEFT JOIN public.hostel_rooms r ON alc.room_id = r.id
    WHERE adm.school_id = p_school_id
      AND adm.academic_year = p_academic_year
      AND adm.deleted_at IS NULL
      AND (p_hostel_id IS NULL OR adm.hostel_id = p_hostel_id)
      AND (p_class IS NULL OR p_class = 'All Classes' OR p.class ILIKE '%' || p_class || '%')
      AND (
          p_status IS NULL 
          OR p_status = 'All Status' 
          OR (UPPER(p_status) IN ('OVER PAID', 'OVERPAID') AND (
              UPPER(COALESCE(acc.payment_status, adm.fee_status)) = 'OVERPAID' 
              OR COALESCE(acc.total_paid, adm.initial_payment_amount, 0) > COALESCE(acc.total_billed, adm.initial_payment_amount, adm.monthly_fee, 0)
          ))
          OR (UPPER(p_status) = 'PAID' AND (
              UPPER(COALESCE(acc.payment_status, adm.fee_status)) IN ('PAID', 'OVERPAID') 
              OR COALESCE(acc.total_paid, adm.initial_payment_amount, 0) >= COALESCE(acc.total_billed, adm.initial_payment_amount, adm.monthly_fee, 0)
          ))
          OR (UPPER(p_status) = 'PARTIAL' AND (
              UPPER(COALESCE(acc.payment_status, adm.fee_status)) = 'PARTIAL'
              OR (COALESCE(acc.total_paid, adm.initial_payment_amount, 0) > 0 AND COALESCE(acc.total_paid, adm.initial_payment_amount, 0) < COALESCE(acc.total_billed, adm.monthly_fee + adm.deposit_amount, 16000.00))
          ))
          OR (UPPER(p_status) = 'OVERDUE' AND UPPER(COALESCE(acc.payment_status, '')) = 'OVERDUE')
          OR (UPPER(COALESCE(acc.payment_status, adm.fee_status)) = UPPER(p_status))
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
            'account_id', COALESCE(acc.id, adm.id),
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
            'fee_plan', COALESCE(adm.fee_plan, acc.fee_plan_name, 'Monthly'),
            'total_fee', final_totals.calc_billed,
            'paid', final_totals.calc_paid,
            'due', CASE 
                WHEN final_totals.calc_paid >= final_totals.calc_billed THEN 0.00 
                ELSE GREATEST(0.00, final_totals.calc_billed - final_totals.calc_paid) 
            END,
            'overdue', CASE 
                WHEN final_totals.calc_paid >= final_totals.calc_billed THEN 0.00 
                ELSE COALESCE(acc.total_overdue, 0.00) 
            END,
            'status', CASE 
                WHEN final_totals.calc_paid > final_totals.calc_billed THEN 'Over Paid'
                WHEN final_totals.calc_paid = final_totals.calc_billed AND final_totals.calc_billed > 0 THEN 'Paid'
                WHEN UPPER(COALESCE(acc.payment_status, adm.fee_status)) = 'OVERPAID' THEN 'Over Paid'
                WHEN UPPER(COALESCE(acc.payment_status, adm.fee_status)) = 'PAID' THEN 'Paid'
                WHEN final_totals.calc_paid > 0 THEN 'Partial'
                WHEN UPPER(COALESCE(acc.payment_status, '')) = 'OVERDUE' THEN 'Overdue'
                ELSE 'Pending'
            END,
            'status_raw', CASE 
                WHEN final_totals.calc_paid > final_totals.calc_billed THEN 'OVERPAID'
                WHEN final_totals.calc_paid = final_totals.calc_billed AND final_totals.calc_billed > 0 THEN 'PAID'
                WHEN final_totals.calc_paid > 0 THEN 'PARTIAL'
                ELSE COALESCE(acc.payment_status, adm.fee_status, 'PENDING')
            END,
            'advance_credit', CASE 
                WHEN final_totals.calc_paid > final_totals.calc_billed THEN (final_totals.calc_paid - final_totals.calc_billed) 
                ELSE COALESCE(acc.advance_credit, 0.00) 
            END,
            'next_due_date', COALESCE(acc.next_due_date, CURRENT_DATE + INTERVAL '15 days'),
            'last_payment_date', COALESCE(acc.last_payment_date, adm.created_at)
        )
    )
    INTO v_items
    FROM (
        SELECT 
            adm.id AS adm_id,
            ROW_NUMBER() OVER(
                ORDER BY 
                    CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'ASC' THEN p.full_name END ASC,
                    CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'DESC' THEN p.full_name END DESC,
                    adm.created_at ASC
            ) AS row_seq
        FROM public.hostel_admissions adm
        JOIN public.profiles p ON adm.student_id = p.id
        LEFT JOIN public.hostel_buildings b ON adm.hostel_id = b.id
        LEFT JOIN public.hostel_student_accounts acc ON (
            acc.student_id = adm.student_id 
            AND acc.academic_year = adm.academic_year 
            AND acc.school_id = adm.school_id
        )
        LEFT JOIN LATERAL (
            SELECT alc.room_id, alc.bed_id 
            FROM public.hostel_allocations alc 
            WHERE (alc.admission_id = adm.id OR alc.student_id = adm.student_id)
              AND alc.allocation_status IN ('CHECKED_IN', 'RESERVED', 'CONFIRMED')
              AND alc.deleted_at IS NULL
            ORDER BY alc.created_at DESC 
            LIMIT 1
        ) alc ON TRUE
        LEFT JOIN public.hostel_rooms r ON alc.room_id = r.id
        WHERE adm.school_id = p_school_id
          AND adm.academic_year = p_academic_year
          AND adm.deleted_at IS NULL
          AND (p_hostel_id IS NULL OR adm.hostel_id = p_hostel_id)
          AND (p_class IS NULL OR p_class = 'All Classes' OR p.class ILIKE '%' || p_class || '%')
          AND (
              p_status IS NULL 
              OR p_status = 'All Status' 
              OR (UPPER(p_status) IN ('OVER PAID', 'OVERPAID') AND (
                  UPPER(COALESCE(acc.payment_status, adm.fee_status)) = 'OVERPAID' 
                  OR COALESCE(acc.total_paid, adm.initial_payment_amount, 0) > COALESCE(acc.total_billed, adm.initial_payment_amount, adm.monthly_fee, 0)
              ))
              OR (UPPER(p_status) = 'PAID' AND (
                  UPPER(COALESCE(acc.payment_status, adm.fee_status)) IN ('PAID', 'OVERPAID') 
                  OR COALESCE(acc.total_paid, adm.initial_payment_amount, 0) >= COALESCE(acc.total_billed, adm.initial_payment_amount, adm.monthly_fee, 0)
              ))
              OR (UPPER(p_status) = 'PARTIAL' AND (
                  UPPER(COALESCE(acc.payment_status, adm.fee_status)) = 'PARTIAL'
                  OR (COALESCE(acc.total_paid, adm.initial_payment_amount, 0) > 0 AND COALESCE(acc.total_paid, adm.initial_payment_amount, 0) < COALESCE(acc.total_billed, adm.monthly_fee + adm.deposit_amount, 16000.00))
              ))
              OR (UPPER(p_status) = 'OVERDUE' AND UPPER(COALESCE(acc.payment_status, '')) = 'OVERDUE')
              OR (UPPER(COALESCE(acc.payment_status, adm.fee_status)) = UPPER(p_status))
          )
          AND (
              p_search IS NULL OR p_search = '' OR
              p.full_name ILIKE '%' || p_search || '%' OR
              p.roll_number::text ILIKE '%' || p_search || '%' OR
              COALESCE(p.user_id, '') ILIKE '%' || p_search || '%' OR
              COALESCE(r.room_number, '') ILIKE '%' || p_search || '%' OR
              COALESCE(b.name, '') ILIKE '%' || p_search || '%'
          )
        ORDER BY 
            CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'ASC' THEN p.full_name END ASC,
            CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'DESC' THEN p.full_name END DESC,
            adm.created_at ASC
        LIMIT p_page_size
        OFFSET v_offset
    ) row_data
    JOIN public.hostel_admissions adm ON adm.id = row_data.adm_id
    JOIN public.profiles p ON adm.student_id = p.id
    LEFT JOIN public.hostel_buildings b ON adm.hostel_id = b.id
    LEFT JOIN public.hostel_student_accounts acc ON (
        acc.student_id = adm.student_id 
        AND acc.academic_year = adm.academic_year 
        AND acc.school_id = adm.school_id
    )
    LEFT JOIN LATERAL (
        SELECT alc.room_id, alc.bed_id 
        FROM public.hostel_allocations alc 
        WHERE (alc.admission_id = adm.id OR alc.student_id = adm.student_id)
          AND alc.allocation_status IN ('CHECKED_IN', 'RESERVED', 'CONFIRMED')
          AND alc.deleted_at IS NULL
        ORDER BY alc.created_at DESC 
        LIMIT 1
    ) alc ON TRUE
    LEFT JOIN public.hostel_rooms r ON alc.room_id = r.id
    CROSS JOIN LATERAL (
        SELECT 
            COALESCE(
                acc.total_billed,
                (SELECT SUM(inv.net_amount) FROM public.hostel_invoices inv WHERE inv.student_id = adm.student_id AND inv.academic_year = adm.academic_year AND inv.deleted_at IS NULL),
                CASE 
                    WHEN UPPER(adm.fee_status) = 'PAID' AND adm.initial_payment_amount > 0 THEN adm.initial_payment_amount
                    ELSE (COALESCE(adm.monthly_fee, 6000.00) * (CASE WHEN adm.fee_plan ILIKE '%Annual%' THEN 12 WHEN adm.fee_plan ILIKE '%Quarter%' THEN 3 ELSE 1 END)) + COALESCE(adm.deposit_amount, 10000.00)
                END
            ) AS calc_billed,
            COALESCE(
                acc.total_paid,
                (SELECT SUM(pmt.amount) FROM public.hostel_payments pmt WHERE pmt.student_id = adm.student_id AND pmt.status = 'SUCCESS'),
                adm.initial_payment_amount,
                CASE WHEN UPPER(adm.fee_status) = 'PAID' THEN (COALESCE(adm.monthly_fee, 6000.00) + COALESCE(adm.deposit_amount, 10000.00)) ELSE 0.00 END
            ) AS calc_paid
    ) final_totals;

    RETURN jsonb_build_object(
        'data', COALESCE(v_items, '[]'::JSONB),
        'pagination', jsonb_build_object(
            'page', p_page,
            'page_size', p_page_size,
            'total_records', v_total_count,
            'total_pages', CEIL(v_total_count::FLOAT / GREATEST(1, p_page_size))
        )
    );
END;
$$;


-- 3. Update fn_hostel_get_fee_kpis to aggregate accurately across all admitted students
CREATE OR REPLACE FUNCTION public.fn_hostel_get_fee_kpis(
    p_school_id UUID,
    p_academic_year VARCHAR DEFAULT '2026 - 2027'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
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
        COALESCE(SUM(calc.billed), 0),
        COALESCE(SUM(calc.paid), 0),
        COALESCE(SUM(CASE WHEN calc.paid >= calc.billed THEN 0.00 ELSE (calc.billed - calc.paid) END), 0),
        COALESCE(SUM(CASE WHEN calc.paid >= calc.billed THEN 0.00 ELSE COALESCE(acc.total_overdue, 0.00) END), 0),
        COUNT(CASE WHEN calc.paid < calc.billed THEN 1 END),
        COUNT(CASE WHEN calc.paid < calc.billed AND COALESCE(acc.total_overdue, 0) > 0 THEN 1 END),
        COUNT(*)
    INTO
        v_total_billed,
        v_total_collected,
        v_pending_dues,
        v_overdue_amount,
        v_pending_students,
        v_overdue_students,
        v_total_students
    FROM public.hostel_admissions adm
    LEFT JOIN public.hostel_student_accounts acc ON (
        acc.student_id = adm.student_id 
        AND acc.academic_year = adm.academic_year 
        AND acc.school_id = adm.school_id
    )
    CROSS JOIN LATERAL (
        SELECT 
            COALESCE(
                acc.total_billed,
                (SELECT SUM(inv.net_amount) FROM public.hostel_invoices inv WHERE inv.student_id = adm.student_id AND inv.academic_year = adm.academic_year AND inv.deleted_at IS NULL),
                CASE 
                    WHEN UPPER(adm.fee_status) = 'PAID' AND adm.initial_payment_amount > 0 THEN adm.initial_payment_amount
                    ELSE (COALESCE(adm.monthly_fee, 6000.00) * (CASE WHEN adm.fee_plan ILIKE '%Annual%' THEN 12 WHEN adm.fee_plan ILIKE '%Quarter%' THEN 3 ELSE 1 END)) + COALESCE(adm.deposit_amount, 10000.00)
                END
            ) AS billed,
            COALESCE(
                acc.total_paid,
                (SELECT SUM(pmt.amount) FROM public.hostel_payments pmt WHERE pmt.student_id = adm.student_id AND pmt.status = 'SUCCESS'),
                adm.initial_payment_amount,
                CASE WHEN UPPER(adm.fee_status) = 'PAID' THEN (COALESCE(adm.monthly_fee, 6000.00) + COALESCE(adm.deposit_amount, 10000.00)) ELSE 0.00 END
            ) AS paid
    ) calc
    WHERE adm.school_id = p_school_id 
      AND adm.academic_year = p_academic_year 
      AND adm.deleted_at IS NULL;

    IF v_total_billed > 0 THEN
        v_collection_rate := LEAST(100, ROUND((v_total_collected / v_total_billed) * 100));
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


-- 4. Update both overloads of fn_hostel_admit_student to trigger synchronization
CREATE OR REPLACE FUNCTION public.fn_hostel_admit_student(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
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
    v_existing_adm RECORD;
    v_room RECORD;
    v_bed RECORD;
    v_adm_id UUID;
    v_alloc_id UUID;
    v_adm_status VARCHAR(30) := 'ACTIVE';
BEGIN
    v_student_id := (p_data->>'student_id')::UUID;
    v_academic_year := COALESCE(p_data->>'academic_year', '2026 - 2027');
    v_hostel_id := (p_data->>'hostel_id')::UUID;
    v_room_id := (p_data->>'room_id')::UUID;
    v_bed_id := (p_data->>'bed_id')::UUID;
    v_admission_date := COALESCE((p_data->>'admission_date')::DATE, CURRENT_DATE);
    v_boarding_type := COALESCE(p_data->>'boarding_type', 'REGULAR');
    v_hostel_type := COALESCE(p_data->>'hostel_type', 'Standard');
    v_fee_plan := COALESCE(p_data->>'fee_plan', 'Monthly');
    v_monthly_fee := COALESCE((p_data->>'monthly_fee')::NUMERIC, 6000.00);
    v_deposit_amount := COALESCE((p_data->>'deposit_amount')::NUMERIC, 10000.00);
    v_fee_status := COALESCE(p_data->>'fee_status', 'PAID');
    v_initial_payment_amount := COALESCE((p_data->>'initial_payment_amount')::NUMERIC, 0.00);
    v_special_notes := p_data->>'special_notes';
    v_emergency_contact := p_data->>'emergency_contact';

    IF v_student_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Student ID is required');
    END IF;

    -- Upsert admission record
    SELECT * INTO v_existing_adm
    FROM public.hostel_admissions
    WHERE student_id = v_student_id 
      AND academic_year = v_academic_year 
      AND deleted_at IS NULL;

    IF v_existing_adm IS NOT NULL THEN
        UPDATE public.hostel_admissions
        SET hostel_id = COALESCE(v_hostel_id, hostel_id),
            fee_plan = v_fee_plan,
            monthly_fee = v_monthly_fee,
            deposit_amount = v_deposit_amount,
            fee_status = v_fee_status,
            initial_payment_amount = v_initial_payment_amount,
            admission_status = v_adm_status,
            special_notes = v_special_notes,
            emergency_contact_override = v_emergency_contact,
            updated_at = NOW()
        WHERE id = v_existing_adm.id
        RETURNING id INTO v_adm_id;
    ELSE
        INSERT INTO public.hostel_admissions (
            school_id, student_id, academic_year, hostel_id, admission_reference,
            admission_date, admission_status, boarding_type, hostel_type,
            fee_plan, monthly_fee, deposit_amount, fee_status, initial_payment_amount,
            special_notes, emergency_contact_override, created_by
        ) VALUES (
            p_school_id, v_student_id, v_academic_year, v_hostel_id,
            'ADM-' || TO_CHAR(v_admission_date, 'YYMM') || '-' || SUBSTRING(v_student_id::TEXT, 1, 4),
            v_admission_date, v_adm_status, v_boarding_type, v_hostel_type,
            v_fee_plan, v_monthly_fee, v_deposit_amount, v_fee_status, v_initial_payment_amount,
            v_special_notes, v_emergency_contact, p_user_id
        ) RETURNING id INTO v_adm_id;
    END IF;

    -- Allocate room/bed if provided
    IF v_room_id IS NOT NULL THEN
        IF v_bed_id IS NULL THEN
            SELECT id INTO v_bed_id 
            FROM public.hostel_beds 
            WHERE room_id = v_room_id AND status = 'AVAILABLE' AND deleted_at IS NULL 
            ORDER BY bed_code ASC LIMIT 1;
        END IF;

        IF v_bed_id IS NOT NULL THEN
            INSERT INTO public.hostel_allocations (
                school_id, admission_id, student_id, academic_year,
                building_id, floor_id, room_id, bed_id,
                allocation_status, check_in_date, monthly_fee, deposit_amount, fee_status,
                initial_payment_amount, allocation_reason, created_by, updated_by
            ) VALUES (
                p_school_id, v_adm_id, v_student_id, v_academic_year,
                COALESCE(v_hostel_id, (SELECT building_id FROM public.hostel_rooms WHERE id = v_room_id)),
                (SELECT floor_id FROM public.hostel_rooms WHERE id = v_room_id),
                v_room_id, v_bed_id,
                'CHECKED_IN', NOW(), v_monthly_fee, v_deposit_amount, v_fee_status,
                v_initial_payment_amount, 'New Admission Allocation', p_user_id, p_user_id
            )
            ON CONFLICT (school_id, student_id, academic_year) WHERE deleted_at IS NULL
            DO UPDATE SET
                room_id = EXCLUDED.room_id,
                bed_id = EXCLUDED.bed_id,
                admission_id = EXCLUDED.admission_id,
                allocation_status = 'CHECKED_IN',
                updated_at = NOW()
            RETURNING id INTO v_alloc_id;

            UPDATE public.hostel_beds SET status = 'OCCUPIED', updated_at = NOW() WHERE id = v_bed_id;
            PERFORM public.fn_hostel_recalculate_room_occupancy(v_room_id);
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

-- 2-argument overload delegating to 3-argument version
CREATE OR REPLACE FUNCTION public.fn_hostel_admit_student(
    p_school_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN public.fn_hostel_admit_student(p_school_id, NULL, p_data);
END;
$$;


-- 5. Backfill/synchronize all existing admissions to fee accounts, invoices, and payments right now
UPDATE public.hostel_admissions 
SET updated_at = NOW() 
WHERE deleted_at IS NULL;
