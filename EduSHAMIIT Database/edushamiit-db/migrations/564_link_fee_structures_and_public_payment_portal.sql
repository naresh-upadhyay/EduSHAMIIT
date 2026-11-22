-- Migration: 564_link_fee_structures_and_public_payment_portal.sql
-- 1. Add payment_token and fee_structure_id to student_fee_invoices
-- 2. Add fee_structure_id and auto_generate_all_cohort_heads to student_fee_schedule_rules
-- 3. Add fee_structure_id to student_fee_schedule_runs
-- 4. Backfill payment_token for existing invoices
-- 5. Upgrade fn_bulk_generate_student_invoices_v2 to generate payment_token and link fee_structure_id
-- 6. Clean up Class 5 fee structure section names from 'a' / 'NEWSUB2' to '5-A' / '5-B'

BEGIN;

-- 1. Invoices columns
ALTER TABLE public.student_fee_invoices
    ADD COLUMN IF NOT EXISTS payment_token VARCHAR(64) UNIQUE,
    ADD COLUMN IF NOT EXISTS payment_token_created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS fee_structure_id UUID REFERENCES public.student_fee_structures(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_student_fee_invoices_payment_token 
    ON public.student_fee_invoices(payment_token);

CREATE INDEX IF NOT EXISTS idx_student_fee_invoices_fee_structure_id 
    ON public.student_fee_invoices(fee_structure_id);

-- 2. Schedule rules columns
ALTER TABLE public.student_fee_schedule_rules
    ADD COLUMN IF NOT EXISTS fee_structure_id UUID REFERENCES public.student_fee_structures(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS auto_generate_all_cohort_heads BOOLEAN DEFAULT FALSE;

-- 3. Schedule runs columns
ALTER TABLE public.student_fee_schedule_runs
    ADD COLUMN IF NOT EXISTS fee_structure_id UUID REFERENCES public.student_fee_structures(id) ON DELETE SET NULL;

-- 4. Backfill tokens for existing invoices
UPDATE public.student_fee_invoices
SET payment_token = 'pay_' || encode(gen_random_bytes(24), 'hex'),
    payment_token_created_at = NOW()
WHERE payment_token IS NULL;

-- 5. Clean up section names in student_fee_structures for Class 5
UPDATE public.student_fee_structures
SET section_name = '5-A'
WHERE class_grade = 'Class 5' AND section_name = 'NEWSUB2';

UPDATE public.student_fee_structures
SET section_name = '5-B'
WHERE class_grade = 'Class 5' AND section_name = 'a';

-- 6. Upgrade fn_bulk_generate_student_invoices_v2 to accept p_fee_structure_id and generate payment_token
CREATE OR REPLACE FUNCTION public.fn_bulk_generate_student_invoices_v2(
    p_school_id uuid,
    p_target_type text,
    p_target_class text,
    p_student_ids jsonb,
    p_fee_type text,
    p_fee_plan text,
    p_academic_year text,
    p_amount numeric,
    p_due_date date,
    p_title text,
    p_notes text DEFAULT NULL::text,
    p_user_id uuid DEFAULT NULL::uuid,
    p_user_name text DEFAULT 'Admin'::text,
    p_skip_duplicates boolean DEFAULT true,
    p_target_section text DEFAULT NULL::text,
    p_auto_deduct_advance boolean DEFAULT true,
    p_fee_structure_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_sid UUID;
    v_s_name TEXT;
    v_s_email TEXT;
    v_s_class TEXT;
    v_s_roll TEXT;
    v_s_adm TEXT;
    v_student_count INT := 0;
    v_invoices_created INT := 0;
    v_duplicates_skipped INT := 0;
    v_total_billed NUMERIC(12,2) := 0.0;
    v_total_advance_deducted NUMERIC(12,2) := 0.0;
    v_net_amount_due NUMERIC(12,2) := 0.0;
    v_fully_settled_count INT := 0;
    v_partial_settled_count INT := 0;
    v_pending_count INT := 0;
    v_student_advance NUMERIC(12,2) := 0.0;
    v_deduct_amount NUMERIC(12,2) := 0.0;
    v_paid NUMERIC(12,2) := 0.0;
    v_balance NUMERIC(12,2) := 0.0;
    v_status TEXT := 'Pending';
    v_inv_notes TEXT;
    v_seq INT := 0;
    v_inv_num TEXT;
    v_inv_id UUID;
    v_rec_num TEXT;
    v_pay_token TEXT;
    v_actor_name TEXT := COALESCE(p_user_name, 'Admin');
    v_actor_email TEXT := '';
    v_actor_role TEXT := 'admin';
    v_already_exists BOOLEAN;
    v_generated_invoices JSONB := '[]'::jsonb;
    v_clean_class TEXT := TRIM(COALESCE(p_target_class, ''));
    v_clean_sec TEXT := TRIM(COALESCE(p_target_section, ''));
    v_filter_section BOOLEAN := (v_clean_sec != '' AND v_clean_sec != 'All Sections' AND v_clean_sec != 'All');
BEGIN
    -- Actor lookup
    IF p_user_id IS NOT NULL THEN
        SELECT COALESCE(full_name, 'Admin'), COALESCE(email, ''), COALESCE(role, 'admin')
        INTO v_actor_name, v_actor_email, v_actor_role
        FROM public.profiles
        WHERE id = p_user_id;
    END IF;

    -- Compute starting invoice sequence from MAX
    SELECT COALESCE(MAX(
        CASE 
            WHEN invoice_number ~ '^INV-[0-9]{4}-[0-9]+$' 
            THEN SUBSTRING(invoice_number FROM 10)::INT 
            ELSE 0 
        END
    ), 0) INTO v_seq
    FROM public.student_fee_invoices
    WHERE school_id = p_school_id;

    -- Iterate targeted students
    FOR v_sid, v_s_name, v_s_email, v_s_class, v_s_roll, v_s_adm IN 
        SELECT 
            p.id,
            p.full_name,
            COALESCE(p.email, ''),
            COALESCE(ac.name, p.class, ''),
            COALESCE(p.roll_number::text, '-'),
            COALESCE(p.admission_number, 'ADM-' || UPPER(SUBSTRING(p.id::text, 1, 6)))
        FROM public.profiles p
        LEFT JOIN public.student_class_assignments sca ON sca.student_id = p.id AND sca.school_id = p.school_id
        LEFT JOIN public.academic_classes ac ON ac.id = sca.class_id
        WHERE p.school_id = p_school_id 
          AND p.role = 'student'
          AND (
            p_target_type = 'ALL'
            OR (p_target_type = 'CLASS' AND (
                v_clean_class = '' OR v_clean_class IN ('All Classes', 'All')
                OR p.class = v_clean_class
                OR REPLACE(LOWER(COALESCE(p.class, '')), ' ', '') = REPLACE(LOWER(v_clean_class), ' ', '')
                OR ac.name = v_clean_class
                OR REPLACE(LOWER(COALESCE(ac.name, '')), ' ', '') = REPLACE(LOWER(v_clean_class), ' ', '')
                OR (
                    REGEXP_REPLACE(COALESCE(p.class, ''), '[^0-9]', '', 'g') <> ''
                    AND REGEXP_REPLACE(COALESCE(p.class, ''), '[^0-9]', '', 'g') = REGEXP_REPLACE(v_clean_class, '[^0-9]', '', 'g')
                )
            ))
            OR (p_target_type = 'INDIVIDUALS' AND (
                p_student_ids ? p.id::TEXT
            ))
          )
          AND (
            p_target_type IN ('ALL', 'INDIVIDUALS')
            OR NOT v_filter_section
            OR p.class ILIKE '%' || v_clean_sec || '%'
            OR EXISTS (
                SELECT 1 
                FROM public.student_class_assignments sca_sec 
                JOIN public.academic_sections sec ON sec.id = sca_sec.section_id 
                WHERE sca_sec.student_id = p.id 
                  AND (sec.name ILIKE v_clean_sec OR sec.code ILIKE v_clean_sec OR sec.name ILIKE '%' || v_clean_sec || '%')
            )
          )
        ORDER BY p.full_name ASC
    LOOP
        v_student_count := v_student_count + 1;

        -- Duplicate check
        IF p_skip_duplicates THEN
            SELECT EXISTS (
                SELECT 1 FROM public.student_fee_invoices
                WHERE student_id = v_sid
                  AND fee_type = p_fee_type
                  AND title = p_title
                  AND academic_year = p_academic_year
                  AND status != 'Cancelled'
            ) INTO v_already_exists;
        ELSE
            v_already_exists := false;
        END IF;

        IF v_already_exists THEN
            v_duplicates_skipped := v_duplicates_skipped + 1;
        ELSE
            v_seq := v_seq + 1;
            v_inv_num := 'INV-2026-' || LPAD(v_seq::text, 5, '0');
            v_pay_token := 'pay_' || encode(gen_random_bytes(24), 'hex');

            -- 1. Compute student's available advance credit balance
            v_student_advance := 0.0;
            IF p_auto_deduct_advance THEN
                SELECT GREATEST(0.0, 
                    COALESCE((
                        SELECT SUM(amount_paid) 
                        FROM public.student_fee_payments 
                        WHERE student_id = v_sid 
                          AND school_id = p_school_id 
                          AND (status IS NULL OR status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS'))
                    ), 0.0) 
                    - 
                    COALESCE((
                        SELECT SUM(total_billed) 
                        FROM public.student_fee_invoices 
                        WHERE student_id = v_sid 
                          AND school_id = p_school_id 
                          AND status != 'Cancelled'
                    ), 0.0)
                ) INTO v_student_advance;
            END IF;

            -- 2. Deduct advance credit
            IF v_student_advance > 0.0 THEN
                v_deduct_amount := LEAST(p_amount, v_student_advance);
            ELSE
                v_deduct_amount := 0.0;
            END IF;

            -- 3. Calculate net balance and status
            v_paid := v_deduct_amount;
            v_balance := p_amount - v_deduct_amount;

            IF v_balance <= 0.0 THEN
                v_status := 'Paid';
            ELSIF v_paid > 0.0 THEN
                v_status := 'Partial';
            ELSE
                v_status := 'Pending';
            END IF;

            -- Build invoice notes
            v_inv_notes := COALESCE(p_notes, 'Bulk Invoiced by ' || v_actor_name);
            IF v_deduct_amount > 0 THEN
                v_inv_notes := v_inv_notes || ' [Auto-deducted ₹' || TO_CHAR(v_deduct_amount, 'FM99,99,990.00') || ' from student advance credit wallet]';
            END IF;

            -- 4. Insert Invoice with payment_token and fee_structure_id
            INSERT INTO public.student_fee_invoices (
                school_id, student_id, invoice_number, title, fee_type, fee_plan,
                academic_year, billing_date, due_date, subtotal, total_billed,
                paid_amount, balance_amount, status, notes, payment_token,
                payment_token_created_at, fee_structure_id, created_at, updated_at
            ) VALUES (
                p_school_id, v_sid, v_inv_num, p_title, p_fee_type, COALESCE(p_fee_plan, 'Monthly'),
                COALESCE(p_academic_year, '2026 - 2027'), CURRENT_DATE, p_due_date, p_amount, p_amount,
                v_paid, v_balance, v_status, v_inv_notes, v_pay_token,
                NOW(), p_fee_structure_id, NOW(), NOW()
            ) RETURNING id INTO v_inv_id;

            -- 5. Advance payment receipt if wallet was applied
            IF v_deduct_amount > 0 THEN
                v_rec_num := 'REC-ADV-2026-' || LPAD(ROUND(RANDOM() * 89999 + 10000)::TEXT, 5, '0');

                INSERT INTO public.student_fee_payments (
                    school_id, student_id, invoice_id, receipt_number,
                    payment_date, payment_method, amount_paid, transaction_reference,
                    remarks, status, recorded_by, created_at, updated_at
                ) VALUES (
                    p_school_id, v_sid, v_inv_id, v_rec_num,
                    CURRENT_DATE, 'Advance Credit Wallet', v_deduct_amount, 'ADV-WALLET-' || SUBSTRING(v_inv_id::text, 1, 8),
                    'Automatic wallet deduction against bulk invoice ' || v_inv_num, 'SUCCESS', p_user_id, NOW(), NOW()
                );

                INSERT INTO public.student_fee_audit_logs (
                    school_id, student_id, entity_type, entity_id, action,
                    description, old_status, new_status, amount,
                    performed_by_id, performed_by_name, performed_by_email, performed_by_role
                ) VALUES (
                    p_school_id, v_sid, 'PAYMENT', v_inv_id, 'PAYMENT_RECORDED',
                    'Auto-deducted advance credit of ₹' || TO_CHAR(v_deduct_amount, 'FM99,99,990.00') || ' for invoice ' || v_inv_num,
                    NULL, 'SUCCESS', v_deduct_amount,
                    p_user_id, v_actor_name, v_actor_email, v_actor_role
                );
            END IF;

            -- 6. Audit log for invoice
            INSERT INTO public.student_fee_audit_logs (
                school_id, student_id, entity_type, entity_id, action,
                description, old_status, new_status, amount,
                performed_by_id, performed_by_name, performed_by_email, performed_by_role
            ) VALUES (
                p_school_id, v_sid, 'INVOICE', v_inv_id, 'INVOICE_GENERATED',
                'Bulk generated invoice ' || v_inv_num || ' for ' || p_title || ' of ₹' || TO_CHAR(p_amount, 'FM99,99,990.00')
                || CASE WHEN v_deduct_amount > 0 THEN ' (Auto-deducted ₹' || TO_CHAR(v_deduct_amount, 'FM99,99,990.00') || ' from advance wallet; net due: ₹' || TO_CHAR(v_balance, 'FM99,99,990.00') || ')' ELSE '' END,
                NULL, v_status, p_amount,
                p_user_id, v_actor_name, v_actor_email, v_actor_role
            );

            -- 7. Statistics
            v_invoices_created := v_invoices_created + 1;
            v_total_billed := v_total_billed + p_amount;
            v_total_advance_deducted := v_total_advance_deducted + v_deduct_amount;
            v_net_amount_due := v_net_amount_due + v_balance;

            IF v_status = 'Paid' THEN
                v_fully_settled_count := v_fully_settled_count + 1;
            ELSIF v_status = 'Partial' THEN
                v_partial_settled_count := v_partial_settled_count + 1;
            ELSE
                v_pending_count := v_pending_count + 1;
            END IF;

            -- Add to generated list with payment_token and public payment url
            v_generated_invoices := v_generated_invoices || jsonb_build_array(
                jsonb_build_object(
                    'invoice_id', v_inv_id,
                    'invoice_number', v_inv_num,
                    'payment_token', v_pay_token,
                    'student_id', v_sid,
                    'student_name', v_s_name,
                    'student_email', v_s_email,
                    'class_name', v_s_class,
                    'roll_number', v_s_roll,
                    'admission_number', v_s_adm,
                    'gross_amount', p_amount,
                    'advance_deducted', v_deduct_amount,
                    'net_payable', v_balance,
                    'remaining_advance', GREATEST(0.0, v_student_advance - v_deduct_amount),
                    'due_date', p_due_date,
                    'status', v_status,
                    'fee_structure_id', p_fee_structure_id
                )
            );
        END IF;
    END LOOP;

    -- Record run telemetry in student_fee_schedule_runs
    INSERT INTO public.student_fee_schedule_runs (
        school_id, rule_name, triggered_by, triggered_by_name, trigger_type,
        status, invoices_created, students_targeted, duplicates_skipped,
        total_amount_billed, advance_credits_applied, net_amount_due, target_section,
        billing_period, due_date, fee_structure_id, execution_notes, executed_at
    ) VALUES (
        p_school_id, 
        'On-Demand Bulk Invoicing (' || COALESCE(p_target_class, p_target_type) || CASE WHEN v_filter_section THEN ' - ' || v_clean_sec ELSE '' END || ')',
        p_user_id, v_actor_name, 'BULK_EXECUTE',
        CASE WHEN v_invoices_created > 0 OR v_duplicates_skipped > 0 THEN 'SUCCESS' ELSE 'FAILED' END,
        v_invoices_created, v_student_count, v_duplicates_skipped,
        v_total_billed, v_total_advance_deducted, v_net_amount_due, v_clean_sec,
        TO_CHAR(CURRENT_DATE, 'FMMonth YYYY'), p_due_date, p_fee_structure_id,
        'Bulk generated ' || v_invoices_created || ' invoices (Gross ₹' || TO_CHAR(v_total_billed, 'FM99,99,990.00') 
        || ', Advance Wallet Deducted ₹' || TO_CHAR(v_total_advance_deducted, 'FM99,99,990.00')
        || ', Net Due ₹' || TO_CHAR(v_net_amount_due, 'FM99,99,990.00')
        || '). Skipped ' || v_duplicates_skipped || ' duplicates.',
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'invoices_created', v_invoices_created,
        'students_targeted', v_student_count,
        'duplicates_skipped', v_duplicates_skipped,
        'total_amount_billed', v_total_billed,
        'total_advance_credits_applied', v_total_advance_deducted,
        'net_amount_due', v_net_amount_due,
        'fully_settled_count', v_fully_settled_count,
        'partial_settled_count', v_partial_settled_count,
        'pending_count', v_pending_count,
        'target_section', v_clean_sec,
        'fee_structure_id', p_fee_structure_id,
        'generated_invoices', v_generated_invoices,
        'message', 'Generated ' || v_invoices_created || ' invoices (Gross ₹' || TO_CHAR(v_total_billed, 'FM99,99,990.00') 
            || ', Advance Deducted ₹' || TO_CHAR(v_total_advance_deducted, 'FM99,99,990.00')
            || ', Net Due ₹' || TO_CHAR(v_net_amount_due, 'FM99,99,990.00')
            || '). Skipped ' || v_duplicates_skipped || ' duplicates.'
    );
END;
$function$;

COMMIT;
