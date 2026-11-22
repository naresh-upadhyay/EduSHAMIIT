-- Migration: 565_update_fee_schedule_rule_token_and_structure.sql
-- Upgrades fn_execute_fee_schedule_rule to generate payment_token, link fee_structure_id, and include public payment link

CREATE OR REPLACE FUNCTION public.fn_execute_fee_schedule_rule(
    p_rule_id UUID,
    p_triggered_by UUID DEFAULT NULL,
    p_triggered_by_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_rule RECORD;
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
    v_student_advance NUMERIC(12,2) := 0.0;
    v_deduct_amount NUMERIC(12,2) := 0.0;
    v_paid NUMERIC(12,2) := 0.0;
    v_balance NUMERIC(12,2) := 0.0;
    v_status TEXT := 'Pending';
    v_inv_notes TEXT;
    v_due_date DATE;
    v_billing_period TEXT;
    v_title TEXT;
    v_next_run TIMESTAMPTZ;
    v_actor_name TEXT := COALESCE(p_triggered_by_name, 'Automated System Scheduler');
    v_actor_email TEXT := '';
    v_actor_role TEXT := 'System';
    v_trigger_type TEXT := CASE WHEN p_triggered_by IS NOT NULL THEN 'MANUAL_TRIGGER' ELSE 'SCHEDULED' END;
    v_month_name TEXT;
    v_year_name TEXT;
    v_quarter_name TEXT;
    v_seq INT := 0;
    v_inv_num TEXT;
    v_inv_id UUID;
    v_pay_token TEXT;
    v_rec_num TEXT;
    v_already_exists BOOLEAN;
    v_generated_invoices JSONB := '[]'::jsonb;
    v_clean_class TEXT;
    v_clean_sec TEXT;
    v_filter_section BOOLEAN;
BEGIN
    SELECT * INTO v_rule
    FROM public.student_fee_schedule_rules
    WHERE id = p_rule_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Rule not found');
    END IF;

    v_clean_class := TRIM(COALESCE(v_rule.target_class, ''));
    v_clean_sec := TRIM(COALESCE(v_rule.target_section, ''));
    v_filter_section := (v_clean_sec != '' AND v_clean_sec != 'All Sections' AND v_clean_sec != 'All');

    -- Lookup performer details
    IF p_triggered_by IS NOT NULL THEN
        SELECT COALESCE(full_name, 'Admin'), COALESCE(email, ''), COALESCE(role, 'admin')
        INTO v_actor_name, v_actor_email, v_actor_role
        FROM public.profiles
        WHERE id = p_triggered_by;
    END IF;

    -- Billing period computation
    IF v_rule.billing_period_target = 'NEXT_MONTH' THEN
        v_month_name := TO_CHAR(CURRENT_DATE + INTERVAL '1 month', 'FMMonth');
        v_year_name := TO_CHAR(CURRENT_DATE + INTERVAL '1 month', 'YYYY');
    ELSE
        v_month_name := TO_CHAR(CURRENT_DATE, 'FMMonth');
        v_year_name := TO_CHAR(CURRENT_DATE, 'YYYY');
    END IF;
    v_quarter_name := 'Q' || EXTRACT(QUARTER FROM CURRENT_DATE)::TEXT;
    v_billing_period := v_month_name || ' ' || v_year_name;

    -- Template substitution
    v_title := v_rule.title_template;
    v_title := REPLACE(v_title, '{MONTH}', v_month_name);
    v_title := REPLACE(v_title, '{YEAR}', v_year_name);
    v_title := REPLACE(v_title, '{QUARTER}', v_quarter_name);
    v_title := REPLACE(v_title, '{CLASS}', COALESCE(v_rule.target_class, 'All'));
    v_title := REPLACE(v_title, '{SECTION}', COALESCE(v_rule.target_section, 'All'));

    -- Due date calculation
    v_due_date := CURRENT_DATE + (COALESCE(v_rule.due_days_offset, 10) || ' days')::INTERVAL;

    -- Compute starting sequence from MAX to prevent any unique constraint collisions
    SELECT COALESCE(MAX(
        CASE 
            WHEN invoice_number ~ '^INV-[0-9]{4}-[0-9]+$' 
            THEN SUBSTRING(invoice_number FROM 10)::INT 
            ELSE 0 
        END
    ), 0) INTO v_seq
    FROM public.student_fee_invoices
    WHERE school_id = v_rule.school_id;

    -- Iterate students matching class AND section criteria
    FOR v_sid, v_s_name, v_s_email, v_s_class, v_s_roll, v_s_adm IN 
        SELECT 
            p.id,
            p.full_name,
            COALESCE(p.email, ''),
            COALESCE(p.class, ''),
            COALESCE(p.roll_number::text, '-'),
            COALESCE(p.admission_number, 'ADM-' || UPPER(SUBSTRING(p.id::text, 1, 6)))
        FROM public.profiles p
        WHERE p.school_id = v_rule.school_id 
          AND p.role = 'student'
          AND (
            v_rule.target_type = 'ALL'
            OR (v_rule.target_type = 'CLASS' AND (
                v_clean_class = '' OR v_clean_class IN ('All Classes', 'All')
                OR p.class = v_clean_class
                OR REPLACE(LOWER(COALESCE(p.class, '')), ' ', '') = REPLACE(LOWER(v_clean_class), ' ', '')
                OR EXISTS (
                    SELECT 1 
                    FROM public.student_class_assignments sca 
                    JOIN public.academic_classes ac ON ac.id = sca.class_id 
                    WHERE sca.student_id = p.id 
                      AND (ac.name = v_clean_class OR REPLACE(LOWER(ac.name), ' ', '') = REPLACE(LOWER(v_clean_class), ' ', ''))
                )
            ))
            OR (v_rule.target_type = 'INDIVIDUALS' AND (
                v_rule.student_ids ? p.id::TEXT
            ))
          )
          AND (
            NOT v_filter_section
            OR p.class ILIKE '%' || v_clean_sec || '%'
            OR EXISTS (
                SELECT 1 
                FROM public.student_class_assignments sca 
                JOIN public.academic_sections sec ON sec.id = sca.section_id 
                WHERE sca.student_id = p.id 
                  AND (sec.name ILIKE v_clean_sec OR sec.code ILIKE v_clean_sec OR sec.name ILIKE '%' || v_clean_sec || '%')
            )
          )
        ORDER BY p.full_name ASC
    LOOP
        v_student_count := v_student_count + 1;

        SELECT EXISTS (
            SELECT 1 FROM public.student_fee_invoices
            WHERE student_id = v_sid
              AND fee_type = v_rule.fee_type
              AND title = v_title
              AND academic_year = v_rule.academic_year
              AND status != 'Cancelled'
        ) INTO v_already_exists;

        IF v_already_exists THEN
            v_duplicates_skipped := v_duplicates_skipped + 1;
        ELSE
            -- Advance wallet calculation
            SELECT GREATEST(0.0,
                COALESCE((
                    SELECT SUM(pay.amount_paid)
                    FROM public.student_fee_payments pay
                    WHERE pay.student_id = v_sid 
                      AND pay.school_id = v_rule.school_id
                      AND (pay.status IS NULL OR pay.status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS'))
                ), 0.0) 
                - 
                COALESCE((
                    SELECT SUM(inv.total_billed)
                    FROM public.student_fee_invoices inv
                    WHERE inv.student_id = v_sid 
                      AND inv.school_id = v_rule.school_id 
                      AND inv.status != 'Cancelled'
                ), 0.0)
            ) INTO v_student_advance;

            IF v_rule.auto_deduct_advance_credit AND v_student_advance > 0 THEN
                v_deduct_amount := LEAST(v_rule.amount, v_student_advance);
                v_balance := v_rule.amount - v_deduct_amount;
                v_paid := v_deduct_amount;
                v_status := CASE WHEN v_balance = 0.0 THEN 'Paid' ELSE 'Partial' END;
                
                v_inv_notes := 'Auto-deducted ₹' || TO_CHAR(v_deduct_amount, 'FM99,99,990.00') 
                    || ' from Advance Credit Wallet. Net due: ₹' || TO_CHAR(v_balance, 'FM99,99,990.00')
                    || ' via recurring rule: ' || v_rule.rule_name;
            ELSE
                v_deduct_amount := 0.0;
                v_balance := v_rule.amount;
                v_paid := 0.0;
                v_status := 'Pending';
                v_inv_notes := COALESCE(v_rule.notes, 'Automated generation rule: ' || v_rule.rule_name);
            END IF;

            v_seq := v_seq + 1;
            v_inv_num := 'INV-2026-' || LPAD(v_seq::text, 5, '0');
            v_pay_token := 'pay_' || encode(gen_random_bytes(24), 'hex');

            INSERT INTO public.student_fee_invoices (
                school_id, student_id, invoice_number, title, fee_type, fee_plan,
                academic_year, billing_date, due_date, subtotal, total_billed,
                paid_amount, balance_amount, status, notes, schedule_rule_id,
                payment_token, payment_token_created_at, fee_structure_id,
                created_at, updated_at
            ) VALUES (
                v_rule.school_id, v_sid, v_inv_num, v_title, v_rule.fee_type, v_rule.fee_plan,
                v_rule.academic_year, CURRENT_DATE, v_due_date, v_rule.amount, v_rule.amount,
                v_paid, v_balance, v_status, v_inv_notes, v_rule.id,
                v_pay_token, NOW(), v_rule.fee_structure_id,
                NOW(), NOW()
            ) RETURNING id INTO v_inv_id;

            IF v_deduct_amount > 0 THEN
                v_rec_num := 'REC-WAL-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || LPAD(v_seq::text, 4, '0');
                
                INSERT INTO public.student_fee_payments (
                    school_id, student_id, invoice_id, receipt_number,
                    amount_paid, payment_method, payment_date, transaction_reference,
                    status, remarks, recorded_by, created_at, updated_at
                ) VALUES (
                    v_rule.school_id, v_sid, v_inv_id, v_rec_num,
                    v_deduct_amount, 'Advance Credit Wallet', NOW(), 'AUTO-WALLET-RULE',
                    'COMPLETED', 'Auto-applied from advance credit wallet via rule: ' || v_rule.rule_name,
                    p_triggered_by, NOW(), NOW()
                );
            END IF;

            INSERT INTO public.student_fee_audit_logs (
                school_id, student_id, entity_type, entity_id, action,
                description, old_status, new_status, amount,
                performed_by_id, performed_by_name, performed_by_email, performed_by_role
            ) VALUES (
                v_rule.school_id, v_sid, 'INVOICE', v_inv_id, 'INVOICE_GENERATED',
                'Generated invoice ' || v_inv_num || ' for ' || v_title || ' of ₹' || TO_CHAR(v_rule.amount, 'FM99,99,990.00')
                || CASE WHEN v_deduct_amount > 0 THEN ' (Auto-deducted ₹' || TO_CHAR(v_deduct_amount, 'FM99,99,990.00') || ' from advance wallet; net due: ₹' || TO_CHAR(v_balance, 'FM99,99,990.00') || ')' ELSE '' END
                || ' via rule: ' || v_rule.rule_name,
                NULL, v_status, v_rule.amount,
                p_triggered_by, v_actor_name, v_actor_email, v_actor_role
            );

            v_invoices_created := v_invoices_created + 1;
            v_total_billed := v_total_billed + v_rule.amount;
            v_total_advance_deducted := v_total_advance_deducted + v_deduct_amount;
            v_net_amount_due := v_net_amount_due + v_balance;

            IF v_status = 'Paid' THEN
                v_fully_settled_count := v_fully_settled_count + 1;
            END IF;

            v_generated_invoices := v_generated_invoices || jsonb_build_array(
                jsonb_build_object(
                    'invoice_id', v_inv_id,
                    'invoice_number', v_inv_num,
                    'payment_token', v_pay_token,
                    'public_payment_url', '/pay/invoice/' || v_pay_token,
                    'student_id', v_sid,
                    'student_name', v_s_name,
                    'student_email', v_s_email,
                    'class_name', v_s_class,
                    'roll_number', v_s_roll,
                    'admission_number', v_s_adm,
                    'gross_amount', v_rule.amount,
                    'advance_deducted', v_deduct_amount,
                    'net_payable', v_balance,
                    'remaining_advance', GREATEST(0.0, v_student_advance - v_deduct_amount),
                    'due_date', v_due_date,
                    'status', v_status,
                    'fee_structure_id', v_rule.fee_structure_id
                )
            );
        END IF;
    END LOOP;

    -- Calculate next run
    SELECT public.fn_calculate_next_fee_schedule_run(v_rule.frequency, v_rule.schedule_day_of_month, CURRENT_DATE)
    INTO v_next_run;

    -- Record run telemetry
    INSERT INTO public.student_fee_schedule_runs (
        school_id, rule_id, rule_name, triggered_by, triggered_by_name,
        trigger_type, status, invoices_created, students_targeted,
        duplicates_skipped, total_amount_billed, advance_credits_applied,
        net_amount_due, target_section, fee_structure_id, billing_period, due_date,
        execution_notes, executed_at
    ) VALUES (
        v_rule.school_id, v_rule.id, v_rule.rule_name, p_triggered_by, v_actor_name,
        v_trigger_type, 
        CASE WHEN v_invoices_created > 0 OR v_duplicates_skipped > 0 THEN 'SUCCESS' ELSE 'FAILED' END,
        v_invoices_created, v_student_count, v_duplicates_skipped,
        v_total_billed, v_total_advance_deducted, v_net_amount_due,
        v_clean_sec, v_rule.fee_structure_id, v_billing_period, v_due_date,
        'Generated ' || v_invoices_created || ' invoices (Gross ₹' || TO_CHAR(v_total_billed, 'FM99,99,990.00')
        || ', Advance Wallet Deducted ₹' || TO_CHAR(v_total_advance_deducted, 'FM99,99,990.00')
        || ', Net Due ₹' || TO_CHAR(v_net_amount_due, 'FM99,99,990.00')
        || '). Skipped ' || v_duplicates_skipped || ' duplicates.',
        NOW()
    );

    -- Update rule statistics
    UPDATE public.student_fee_schedule_rules
    SET last_run_at = NOW(),
        next_run_at = v_next_run,
        total_runs = total_runs + 1,
        total_invoices_generated = total_invoices_generated + v_invoices_created,
        total_amount_generated = total_amount_generated + v_total_billed,
        updated_at = NOW()
    WHERE id = p_rule_id;

    RETURN jsonb_build_object(
        'success', true,
        'rule_id', v_rule.id,
        'rule_name', v_rule.rule_name,
        'invoices_created', v_invoices_created,
        'students_targeted', v_student_count,
        'duplicates_skipped', v_duplicates_skipped,
        'total_amount_billed', v_total_billed,
        'total_advance_credits_applied', v_total_advance_deducted,
        'net_amount_due', v_net_amount_due,
        'fully_settled_count', v_fully_settled_count,
        'due_date', v_due_date,
        'billing_period', v_billing_period,
        'next_run_at', v_next_run,
        'send_parent_email', v_rule.send_parent_email,
        'generated_invoices', v_generated_invoices,
        'message', 'Successfully generated ' || v_invoices_created || ' invoices for ' || v_rule.rule_name
    );
END;
$$;
