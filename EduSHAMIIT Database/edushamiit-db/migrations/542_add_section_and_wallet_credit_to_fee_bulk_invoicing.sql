-- ============================================================================
-- EduSHAMIIT Database Migration: 542_add_section_and_wallet_credit_to_fee_bulk_invoicing.sql
-- Description: Multi-Section Targeting, Advance Credit Wallet Auto-Deductions,
--              and Enhanced Parent Email Notifications for Bulk & Scheduled Invoicing
-- Features:
--   1. Add target_section, auto_deduct_advance_credit, send_parent_email to student_fee_schedule_rules
--   2. Add target_section, advance_credits_applied, net_amount_due, emails_sent to student_fee_schedule_runs
--   3. Update fn_bulk_generate_student_invoices_v2 with section filtering,
--      automatic overpayment/advance credit wallet deduction, net payable calculation,
--      and detailed telemetry.
--   4. Update fn_execute_fee_schedule_rule with section filtering and advance credit deduction.
--   5. Update fn_student_fee_metadata to return class_sections_map.
-- ============================================================================

-- 1. Ensure columns on student_fee_schedule_rules
ALTER TABLE public.student_fee_schedule_rules
ADD COLUMN IF NOT EXISTS target_section VARCHAR(50) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS auto_deduct_advance_credit BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN IF NOT EXISTS send_parent_email BOOLEAN NOT NULL DEFAULT true;

-- 2. Ensure columns on student_fee_schedule_runs
ALTER TABLE public.student_fee_schedule_runs
ADD COLUMN IF NOT EXISTS target_section VARCHAR(50) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS advance_credits_applied NUMERIC(12,2) NOT NULL DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS net_amount_due NUMERIC(12,2) NOT NULL DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS emails_sent INT NOT NULL DEFAULT 0;

-- 3. Enhance fn_student_fee_metadata to return classes with sections
CREATE OR REPLACE FUNCTION public.fn_student_fee_metadata(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_classes TEXT[];
    v_years TEXT[];
    v_fee_types TEXT[];
    v_payment_modes TEXT[];
    v_concession_types TEXT[];
    v_penalty_types TEXT[];
    v_classes_with_sections JSONB := '[]'::jsonb;
    rec RECORD;
BEGIN
    -- Classes from academic_classes and profiles
    SELECT ARRAY_AGG(DISTINCT c) INTO v_classes
    FROM (
        SELECT name AS c FROM public.academic_classes WHERE school_id = p_school_id AND status = 'ACTIVE'
        UNION
        SELECT DISTINCT class AS c FROM public.profiles WHERE school_id = p_school_id AND role = 'student' AND class IS NOT NULL AND class != ''
    ) sub
    WHERE c IS NOT NULL AND c != '';

    IF v_classes IS NULL OR ARRAY_LENGTH(v_classes, 1) = 0 THEN
        v_classes := ARRAY['Class 9', 'Class 10', 'Class 11', 'Class 12'];
    END IF;

    -- Build classes_with_sections JSON
    FOR rec IN
        SELECT 
            ac.name AS class_name,
            COALESCE(
                jsonb_agg(DISTINCT sec.name) FILTER (WHERE sec.name IS NOT NULL),
                '["10-A", "10-B", "10-C", "10-D"]'::jsonb
            ) AS sections
        FROM public.academic_classes ac
        LEFT JOIN public.academic_sections sec ON sec.class_id = ac.id AND sec.status = 'ACTIVE'
        WHERE ac.school_id = p_school_id AND ac.status = 'ACTIVE'
        GROUP BY ac.name
        ORDER BY ac.name
    LOOP
        v_classes_with_sections := v_classes_with_sections || jsonb_build_array(
            jsonb_build_object(
                'class_name', rec.class_name,
                'sections', rec.sections
            )
        );
    END LOOP;

    -- If empty, provide sensible defaults
    IF jsonb_array_length(v_classes_with_sections) = 0 THEN
        v_classes_with_sections := jsonb_build_array(
            jsonb_build_object('class_name', 'Class 9', 'sections', jsonb_build_array('9-A', '9-B', '9-C', '9-D')),
            jsonb_build_object('class_name', 'Class 10', 'sections', jsonb_build_array('10-A', '10-B', '10-C', '10-D')),
            jsonb_build_object('class_name', 'Class 11', 'sections', jsonb_build_array('11-A', '11-B', '11-C')),
            jsonb_build_object('class_name', 'Class 12', 'sections', jsonb_build_array('12-A', '12-B', '12-C'))
        );
    END IF;

    -- Academic Years
    SELECT ARRAY_AGG(DISTINCT academic_year) INTO v_years
    FROM public.student_fee_invoices
    WHERE school_id = p_school_id AND academic_year IS NOT NULL;

    IF v_years IS NULL OR ARRAY_LENGTH(v_years, 1) = 0 THEN
        v_years := ARRAY['2026 - 2027', '2025 - 2026'];
    END IF;

    -- Fee Types
    SELECT ARRAY_AGG(v.value_name) INTO v_fee_types
    FROM public.lookup_values v
    JOIN public.lookup_keys k ON v.lookup_key_id = k.id
    WHERE k.key_code = 'STUDENT_FEE_TYPE'
      AND v.school_id = p_school_id
      AND v.status = 'ACTIVE'
      AND v.deleted_at IS NULL;

    IF v_fee_types IS NULL OR ARRAY_LENGTH(v_fee_types, 1) = 0 THEN
        v_fee_types := ARRAY['Tuition Fee', 'Admission Fee', 'Examination Fee', 'Science & Computer Lab Fee', 'Library & Digital Resources Fee', 'Sports & Fitness Fee', 'Annual Campus Development Fee', 'Transportation Fee'];
    END IF;

    -- Payment Modes
    SELECT ARRAY_AGG(v.value_name) INTO v_payment_modes
    FROM public.lookup_values v
    JOIN public.lookup_keys k ON v.lookup_key_id = k.id
    WHERE k.key_code = 'PAYMENT_MODE'
      AND v.school_id = p_school_id
      AND v.status = 'ACTIVE'
      AND v.deleted_at IS NULL;

    IF v_payment_modes IS NULL OR ARRAY_LENGTH(v_payment_modes, 1) = 0 THEN
        v_payment_modes := ARRAY['Cash', 'UPI', 'Net Banking', 'Debit Card', 'Credit Card', 'Cheque', 'Demand Draft'];
    END IF;

    -- Concession Types
    SELECT ARRAY_AGG(v.value_name) INTO v_concession_types
    FROM public.lookup_values v
    JOIN public.lookup_keys k ON v.lookup_key_id = k.id
    WHERE k.key_code = 'STUDENT_FEE_CONCESSION_TYPE'
      AND v.school_id = p_school_id
      AND v.status = 'ACTIVE'
      AND v.deleted_at IS NULL;

    IF v_concession_types IS NULL OR ARRAY_LENGTH(v_concession_types, 1) = 0 THEN
        v_concession_types := ARRAY['Academic Merit Scholarship', 'Sibling Concession', 'Staff Ward Concession', 'Sports Excellence Quota'];
    END IF;

    -- Penalty Types
    SELECT ARRAY_AGG(v.value_name) INTO v_penalty_types
    FROM public.lookup_values v
    JOIN public.lookup_keys k ON v.lookup_key_id = k.id
    WHERE k.key_code = 'STUDENT_FEE_PENALTY_TYPE'
      AND v.school_id = p_school_id
      AND v.status = 'ACTIVE'
      AND v.deleted_at IS NULL;

    IF v_penalty_types IS NULL OR ARRAY_LENGTH(v_penalty_types, 1) = 0 THEN
        v_penalty_types := ARRAY['Late Payment Fine', 'Cheque Bounce Charge', 'Administrative Surcharge'];
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'classes', v_classes,
        'classes_with_sections', v_classes_with_sections,
        'academic_years', v_years,
        'fee_types', v_fee_types,
        'payment_modes', v_payment_modes,
        'concession_types', v_concession_types,
        'penalty_types', v_penalty_types
    );
END;
$$;


-- 4. FUNCTION: fn_bulk_generate_student_invoices_v2
-- High-performance bulk invoicing procedure with multi-section targeting,
-- automatic student advance credit wallet deductions, and net pending fee calculation.
CREATE OR REPLACE FUNCTION public.fn_bulk_generate_student_invoices_v2(
    p_school_id UUID,
    p_target_type TEXT, -- 'ALL', 'CLASS', 'INDIVIDUALS'
    p_target_class TEXT,
    p_student_ids JSONB,
    p_fee_type TEXT,
    p_fee_plan TEXT,
    p_academic_year TEXT,
    p_amount NUMERIC(12,2),
    p_due_date DATE,
    p_title TEXT,
    p_notes TEXT DEFAULT NULL,
    p_user_id UUID DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Admin',
    p_skip_duplicates BOOLEAN DEFAULT true,
    p_target_section TEXT DEFAULT NULL,
    p_auto_deduct_advance BOOLEAN DEFAULT true
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
    v_actor_name TEXT := COALESCE(p_user_name, 'Admin');
    v_actor_email TEXT := '';
    v_actor_role TEXT := 'admin';
    v_already_exists BOOLEAN;
    v_generated_invoices JSONB := '[]'::jsonb;
    v_clean_class TEXT := TRIM(COALESCE(p_target_class, ''));
    v_clean_sec TEXT := TRIM(COALESCE(p_target_section, ''));
    v_filter_section BOOLEAN := (v_clean_sec != '' AND v_clean_sec != 'All Sections' AND v_clean_sec != 'All');
BEGIN
    -- Performer lookup
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
            COALESCE(p.class, ''),
            COALESCE(p.roll_number::text, '-'),
            COALESCE(p.admission_number, 'ADM-' || UPPER(SUBSTRING(p.id::text, 1, 6)))
        FROM public.profiles p
        WHERE p.school_id = p_school_id 
          AND p.role = 'student'
          AND (
            p_target_type = 'ALL'
            OR (p_target_type = 'CLASS' AND (
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
            OR (p_target_type = 'INDIVIDUALS' AND (
                p_student_ids ? p.id::TEXT
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

        -- Check duplicate
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
            -- 1. Calculate student's existing advance credit wallet balance
            SELECT GREATEST(0.0,
                COALESCE((
                    SELECT SUM(pay.amount_paid)
                    FROM public.student_fee_payments pay
                    WHERE pay.student_id = v_sid 
                      AND pay.school_id = p_school_id
                      AND (pay.status IS NULL OR pay.status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS'))
                ), 0.0) 
                - 
                COALESCE((
                    SELECT SUM(inv.total_billed)
                    FROM public.student_fee_invoices inv
                    WHERE inv.student_id = v_sid 
                      AND inv.school_id = p_school_id 
                      AND inv.status != 'Cancelled'
                ), 0.0)
            ) INTO v_student_advance;

            -- 2. Determine advance credit auto-deduction
            IF p_auto_deduct_advance AND v_student_advance > 0 THEN
                v_deduct_amount := LEAST(p_amount, v_student_advance);
                v_balance := p_amount - v_deduct_amount;
                v_paid := v_deduct_amount;
                v_status := CASE WHEN v_balance = 0.0 THEN 'Paid' ELSE 'Partial' END;
                
                v_inv_notes := 'Auto-deducted ₹' || TO_CHAR(v_deduct_amount, 'FM99,99,990.00') 
                    || ' from Advance Credit Wallet. Net fee payable: ₹' || TO_CHAR(v_balance, 'FM99,99,990.00')
                    || CASE WHEN COALESCE(p_notes, '') != '' THEN ' | ' || p_notes ELSE '' END;
            ELSE
                v_deduct_amount := 0.0;
                v_balance := p_amount;
                v_paid := 0.0;
                v_status := 'Pending';
                v_inv_notes := p_notes;
            END IF;

            -- 3. Generate sequential invoice number
            v_seq := v_seq + 1;
            v_inv_num := 'INV-2026-' || LPAD(v_seq::text, 5, '0');

            -- 4. Insert Invoice
            INSERT INTO public.student_fee_invoices (
                school_id, student_id, invoice_number, title, fee_type, fee_plan,
                academic_year, billing_date, due_date, subtotal, total_billed,
                paid_amount, balance_amount, status, notes, created_at, updated_at
            ) VALUES (
                p_school_id, v_sid, v_inv_num, p_title, p_fee_type, COALESCE(p_fee_plan, 'Monthly'),
                COALESCE(p_academic_year, '2026 - 2027'), CURRENT_DATE, p_due_date, p_amount, p_amount,
                v_paid, v_balance, v_status, v_inv_notes, NOW(), NOW()
            ) RETURNING id INTO v_inv_id;

            -- 5. If advance credit was deducted, record payment transaction
            IF v_deduct_amount > 0 THEN
                v_rec_num := 'REC-WAL-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || LPAD(v_seq::text, 4, '0');
                
                INSERT INTO public.student_fee_payments (
                    school_id, student_id, invoice_id, receipt_number,
                    amount_paid, payment_method, payment_date, transaction_reference,
                    status, remarks, recorded_by, created_at, updated_at
                ) VALUES (
                    p_school_id, v_sid, v_inv_id, v_rec_num,
                    v_deduct_amount, 'Advance Credit Wallet', NOW(), 'AUTO-WALLET-DEDUCT',
                    'COMPLETED', 'Auto-applied from student advance credit wallet balance on invoice generation',
                    p_user_id, NOW(), NOW()
                );
            END IF;

            -- 6. Record Audit Log
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

            -- 7. Accumulate statistics
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

            -- Add to generated list for email dispatch
            v_generated_invoices := v_generated_invoices || jsonb_build_array(
                jsonb_build_object(
                    'invoice_id', v_inv_id,
                    'invoice_number', v_inv_num,
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
                    'status', v_status
                )
            );
        END IF;
    END LOOP;

    -- Record run telemetry in student_fee_schedule_runs
    INSERT INTO public.student_fee_schedule_runs (
        school_id, rule_name, triggered_by, triggered_by_name, trigger_type,
        status, invoices_created, students_targeted, duplicates_skipped,
        total_amount_billed, advance_credits_applied, net_amount_due, target_section,
        billing_period, due_date, execution_notes, executed_at
    ) VALUES (
        p_school_id, 
        'On-Demand Bulk Invoicing (' || COALESCE(p_target_class, p_target_type) || CASE WHEN v_filter_section THEN ' - ' || v_clean_sec ELSE '' END || ')',
        p_user_id, v_actor_name, 'BULK_EXECUTE',
        CASE WHEN v_invoices_created > 0 OR v_duplicates_skipped > 0 THEN 'SUCCESS' ELSE 'FAILED' END,
        v_invoices_created, v_student_count, v_duplicates_skipped,
        v_total_billed, v_total_advance_deducted, v_net_amount_due, v_clean_sec,
        TO_CHAR(CURRENT_DATE, 'FMMonth YYYY'), p_due_date,
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
        'generated_invoices', v_generated_invoices,
        'message', 'Generated ' || v_invoices_created || ' invoices (Gross ₹' || TO_CHAR(v_total_billed, 'FM99,99,990.00') 
            || ', Advance Deducted ₹' || TO_CHAR(v_total_advance_deducted, 'FM99,99,990.00')
            || ', Net Due ₹' || TO_CHAR(v_net_amount_due, 'FM99,99,990.00')
            || '). Skipped ' || v_duplicates_skipped || ' duplicates.'
    );
END;
$$;


-- 5. FUNCTION: fn_execute_fee_schedule_rule
-- Enhanced rule executor with section targeting, advance credit auto-deductions,
-- and run telemetry recording.
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

            INSERT INTO public.student_fee_invoices (
                school_id, student_id, invoice_number, title, fee_type, fee_plan,
                academic_year, billing_date, due_date, subtotal, total_billed,
                paid_amount, balance_amount, status, notes, schedule_rule_id, created_at, updated_at
            ) VALUES (
                v_rule.school_id, v_sid, v_inv_num, v_title, v_rule.fee_type, v_rule.fee_plan,
                v_rule.academic_year, CURRENT_DATE, v_due_date, v_rule.amount, v_rule.amount,
                v_paid, v_balance, v_status, v_inv_notes, v_rule.id, NOW(), NOW()
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
                    'status', v_status
                )
            );
        END IF;
    END LOOP;

    -- Calculate next run
    v_next_run := public.fn_calculate_next_fee_schedule_run(v_rule.frequency, v_rule.schedule_day_of_month, NOW() + INTERVAL '1 day');

    -- Record execution telemetry
    INSERT INTO public.student_fee_schedule_runs (
        rule_id, school_id, rule_name, triggered_by, triggered_by_name, trigger_type,
        status, invoices_created, students_targeted, duplicates_skipped,
        total_amount_billed, advance_credits_applied, net_amount_due, target_section,
        billing_period, due_date, execution_notes, executed_at
    ) VALUES (
        v_rule.id, v_rule.school_id, v_rule.rule_name, p_triggered_by, v_actor_name, v_trigger_type,
        CASE WHEN v_invoices_created > 0 OR v_duplicates_skipped > 0 THEN 'SUCCESS' ELSE 'FAILED' END,
        v_invoices_created, v_student_count, v_duplicates_skipped,
        v_total_billed, v_total_advance_deducted, v_net_amount_due, v_clean_sec,
        v_billing_period, v_due_date,
        'Generated ' || v_invoices_created || ' invoices (Gross ₹' || TO_CHAR(v_total_billed, 'FM99,99,990.00') 
        || ', Advance Deducted ₹' || TO_CHAR(v_total_advance_deducted, 'FM99,99,990.00')
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
