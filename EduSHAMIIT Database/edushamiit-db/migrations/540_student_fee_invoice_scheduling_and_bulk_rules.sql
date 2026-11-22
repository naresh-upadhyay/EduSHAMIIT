-- ============================================================================
-- EduSHAMIIT Database Migration: 540_student_fee_invoice_scheduling_and_bulk_rules.sql
-- Description: Automated Invoice Generation Scheduling Engine & Enhanced Bulk Invoicing
-- Features:
--   1. student_fee_schedule_rules: Recurring & scheduled invoice generation rules
--   2. student_fee_schedule_runs: Execution audit log and telemetry for bulk & scheduled runs
--   3. Foreign key link on student_fee_invoices(schedule_rule_id)
--   4. Stored procedures for next run calculation, rule execution, due schedule runner,
--      and advanced bulk generation with student targeting and duplicate prevention.
-- ============================================================================

-- 1. Create table: student_fee_schedule_rules
CREATE TABLE IF NOT EXISTS public.student_fee_schedule_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    rule_name VARCHAR(150) NOT NULL,
    target_type VARCHAR(30) NOT NULL DEFAULT 'CLASS', -- 'ALL', 'CLASS', 'INDIVIDUALS'
    target_class VARCHAR(50),
    target_section VARCHAR(20),
    student_ids JSONB DEFAULT '[]'::jsonb,
    fee_type VARCHAR(100) NOT NULL DEFAULT 'Tuition Fee',
    fee_plan VARCHAR(50) NOT NULL DEFAULT 'Monthly',
    amount NUMERIC(12,2) NOT NULL DEFAULT 4500.00,
    title_template VARCHAR(255) NOT NULL DEFAULT 'Tuition Fee - {MONTH} {YEAR}',
    notes TEXT,
    frequency VARCHAR(30) NOT NULL DEFAULT 'MONTHLY', -- 'MONTHLY', 'QUARTERLY', 'HALF_YEARLY', 'ANNUALLY', 'ONE_TIME'
    schedule_day_of_month INT NOT NULL DEFAULT 25, -- Day of the month to trigger (1-31)
    due_days_offset INT NOT NULL DEFAULT 10, -- Number of days after generation until due date (e.g. 10 days)
    billing_period_target VARCHAR(30) NOT NULL DEFAULT 'NEXT_MONTH', -- 'CURRENT_MONTH', 'NEXT_MONTH', 'NEXT_QUARTER'
    academic_year VARCHAR(30) NOT NULL DEFAULT '2026 - 2027',
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_run_at TIMESTAMPTZ,
    next_run_at TIMESTAMPTZ,
    total_runs INT NOT NULL DEFAULT 0,
    total_invoices_generated INT NOT NULL DEFAULT 0,
    total_amount_generated NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexing for fast query and scheduler lookup
CREATE INDEX IF NOT EXISTS idx_fee_rules_school_active 
ON public.student_fee_schedule_rules(school_id, is_active, next_run_at);

-- 2. Link student_fee_invoices to schedule rule
ALTER TABLE public.student_fee_invoices 
ADD COLUMN IF NOT EXISTS schedule_rule_id UUID REFERENCES public.student_fee_schedule_rules(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_student_fee_invoices_schedule_rule 
ON public.student_fee_invoices(schedule_rule_id);

-- 3. Create table: student_fee_schedule_runs
CREATE TABLE IF NOT EXISTS public.student_fee_schedule_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID REFERENCES public.student_fee_schedule_rules(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    rule_name VARCHAR(150),
    triggered_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    triggered_by_name VARCHAR(150) DEFAULT 'Automated System Scheduler',
    trigger_type VARCHAR(30) NOT NULL DEFAULT 'SCHEDULED', -- 'SCHEDULED', 'MANUAL_TRIGGER', 'BULK_EXECUTE'
    status VARCHAR(30) NOT NULL DEFAULT 'SUCCESS', -- 'SUCCESS', 'PARTIAL', 'FAILED'
    invoices_created INT NOT NULL DEFAULT 0,
    students_targeted INT NOT NULL DEFAULT 0,
    duplicates_skipped INT NOT NULL DEFAULT 0,
    total_amount_billed NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    billing_period TEXT,
    due_date DATE,
    execution_notes TEXT,
    executed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fee_schedule_runs_rule 
ON public.student_fee_schedule_runs(rule_id, executed_at DESC);

CREATE INDEX IF NOT EXISTS idx_fee_schedule_runs_school 
ON public.student_fee_schedule_runs(school_id, executed_at DESC);


-- 4. HELPER FUNCTION: fn_calculate_next_fee_schedule_run
CREATE OR REPLACE FUNCTION public.fn_calculate_next_fee_schedule_run(
    p_frequency TEXT,
    p_schedule_day INT,
    p_from_time TIMESTAMPTZ DEFAULT NOW()
)
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_target_day INT := GREATEST(1, LEAST(31, COALESCE(p_schedule_day, 25)));
    v_cand DATE;
    v_curr_year INT := EXTRACT(YEAR FROM p_from_time)::INT;
    v_curr_month INT := EXTRACT(MONTH FROM p_from_time)::INT;
    v_curr_day INT := EXTRACT(DAY FROM p_from_time)::INT;
    v_next_month INT;
    v_next_year INT;
BEGIN
    IF UPPER(p_frequency) = 'ONE_TIME' THEN
        RETURN NULL;
    ELSIF UPPER(p_frequency) = 'QUARTERLY' THEN
        -- Add 3 months
        RETURN (p_from_time + INTERVAL '3 months');
    ELSIF UPPER(p_frequency) = 'HALF_YEARLY' THEN
        -- Add 6 months
        RETURN (p_from_time + INTERVAL '6 months');
    ELSIF UPPER(p_frequency) = 'ANNUALLY' THEN
        -- Add 1 year
        RETURN (p_from_time + INTERVAL '1 year');
    ELSE
        -- Default MONTHLY
        IF v_curr_day < v_target_day THEN
            -- Can run this month on v_target_day
            BEGIN
                v_cand := MAKE_DATE(v_curr_year, v_curr_month, v_target_day);
            EXCEPTION WHEN OTHERS THEN
                -- If day exceeds month max (e.g. 31 in Feb), take last day of month
                v_cand := (DATE_TRUNC('month', p_from_time::DATE) + INTERVAL '1 month - 1 day')::DATE;
            END;
        ELSE
            -- Run next month on v_target_day
            v_next_month := v_curr_month + 1;
            v_next_year := v_curr_year;
            IF v_next_month > 12 THEN
                v_next_month := 1;
                v_next_year := v_curr_year + 1;
            END IF;
            BEGIN
                v_cand := MAKE_DATE(v_next_year, v_next_month, v_target_day);
            EXCEPTION WHEN OTHERS THEN
                v_cand := (MAKE_DATE(v_next_year, v_next_month, 1) + INTERVAL '1 month - 1 day')::DATE;
            END;
        END IF;
        RETURN (v_cand::TIMESTAMP + TIME '06:00:00') AT TIME ZONE 'UTC';
    END IF;
END;
$$;


-- 5. FUNCTION: fn_execute_fee_schedule_rule
-- Executes a single schedule rule, generates invoices for eligible students,
-- prevents duplicate billing, logs run telemetrics, and advances next_run_at.
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
    v_student_count INT := 0;
    v_invoices_created INT := 0;
    v_duplicates_skipped INT := 0;
    v_total_billed NUMERIC(12,2) := 0.0;
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
    v_already_exists BOOLEAN;
BEGIN
    SELECT * INTO v_rule
    FROM public.student_fee_schedule_rules
    WHERE id = p_rule_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Rule not found');
    END IF;

    -- Lookup performer profile details if triggered by user
    IF p_triggered_by IS NOT NULL THEN
        SELECT COALESCE(full_name, 'Admin'), COALESCE(email, ''), COALESCE(role, 'admin')
        INTO v_actor_name, v_actor_email, v_actor_role
        FROM public.profiles
        WHERE id = p_triggered_by;
    END IF;

    -- Determine billing period and title parameters
    IF v_rule.billing_period_target = 'NEXT_MONTH' THEN
        v_month_name := TO_CHAR(CURRENT_DATE + INTERVAL '1 month', 'FMMonth');
        v_year_name := TO_CHAR(CURRENT_DATE + INTERVAL '1 month', 'YYYY');
    ELSE
        v_month_name := TO_CHAR(CURRENT_DATE, 'FMMonth');
        v_year_name := TO_CHAR(CURRENT_DATE, 'YYYY');
    END IF;
    v_quarter_name := 'Q' || EXTRACT(QUARTER FROM CURRENT_DATE)::TEXT;
    v_billing_period := v_month_name || ' ' || v_year_name;

    -- Replace template variables in title
    v_title := v_rule.title_template;
    v_title := REPLACE(v_title, '{MONTH}', v_month_name);
    v_title := REPLACE(v_title, '{YEAR}', v_year_name);
    v_title := REPLACE(v_title, '{QUARTER}', v_quarter_name);
    v_title := REPLACE(v_title, '{CLASS}', COALESCE(v_rule.target_class, 'All'));

    -- Calculate due date: Generation Date + due_days_offset
    v_due_date := CURRENT_DATE + (COALESCE(v_rule.due_days_offset, 10) || ' days')::INTERVAL;

    -- Loop over target students
    FOR v_sid IN 
        SELECT p.id 
        FROM public.profiles p
        WHERE p.school_id = v_rule.school_id 
          AND p.role = 'student'
          AND (
            v_rule.target_type = 'ALL'
            OR (v_rule.target_type = 'CLASS' AND (
                v_rule.target_class IS NULL 
                OR v_rule.target_class IN ('All Classes', 'All', '')
                OR p.class = v_rule.target_class
                OR REPLACE(LOWER(COALESCE(p.class, '')), ' ', '') = REPLACE(LOWER(v_rule.target_class), ' ', '')
            ))
            OR (v_rule.target_type = 'INDIVIDUALS' AND (
                v_rule.student_ids ? p.id::TEXT
            ))
          )
    LOOP
        v_student_count := v_student_count + 1;

        -- Check duplicate: Same student, same fee type, same title, same academic year
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
            -- Generate invoice
            SELECT COUNT(*) + 1 INTO v_seq
            FROM public.student_fee_invoices
            WHERE school_id = v_rule.school_id;
            v_inv_num := 'INV-2026-' || LPAD(v_seq::text, 5, '0');

            INSERT INTO public.student_fee_invoices (
                school_id, student_id, invoice_number, title, fee_type, fee_plan,
                academic_year, billing_date, due_date, subtotal, total_billed,
                paid_amount, balance_amount, status, notes, schedule_rule_id, created_at, updated_at
            ) VALUES (
                v_rule.school_id, v_sid, v_inv_num, v_title, v_rule.fee_type, v_rule.fee_plan,
                v_rule.academic_year, CURRENT_DATE, v_due_date, v_rule.amount, v_rule.amount,
                0.0, v_rule.amount, 'Pending', 
                COALESCE(v_rule.notes, 'Automated generation rule: ' || v_rule.rule_name),
                v_rule.id, NOW(), NOW()
            ) RETURNING id INTO v_inv_id;

            -- Audit log
            INSERT INTO public.student_fee_audit_logs (
                school_id, student_id, entity_type, entity_id, action,
                description, old_status, new_status, amount,
                performed_by_id, performed_by_name, performed_by_email, performed_by_role
            ) VALUES (
                v_rule.school_id, v_sid, 'INVOICE', v_inv_id, 'INVOICE_GENERATED',
                'Generated invoice ' || v_inv_num || ' for ' || v_title || ' of ₹' || TO_CHAR(v_rule.amount, 'FM99,99,990.00') || ' via rule: ' || v_rule.rule_name,
                NULL, 'Pending', v_rule.amount,
                p_triggered_by, v_actor_name, v_actor_email, v_actor_role
            );

            v_invoices_created := v_invoices_created + 1;
            v_total_billed := v_total_billed + v_rule.amount;
        END IF;
    END LOOP;

    -- Calculate next run time
    v_next_run := public.fn_calculate_next_fee_schedule_run(v_rule.frequency, v_rule.schedule_day_of_month, NOW() + INTERVAL '1 day');

    -- Record execution log in student_fee_schedule_runs
    INSERT INTO public.student_fee_schedule_runs (
        rule_id, school_id, rule_name, triggered_by, triggered_by_name, trigger_type,
        status, invoices_created, students_targeted, duplicates_skipped,
        total_amount_billed, billing_period, due_date, execution_notes, executed_at
    ) VALUES (
        v_rule.id, v_rule.school_id, v_rule.rule_name, p_triggered_by, v_actor_name, v_trigger_type,
        CASE WHEN v_invoices_created > 0 OR v_duplicates_skipped > 0 THEN 'SUCCESS' ELSE 'FAILED' END,
        v_invoices_created, v_student_count, v_duplicates_skipped,
        v_total_billed, v_billing_period, v_due_date,
        'Generated ' || v_invoices_created || ' invoices (Total ₹' || TO_CHAR(v_total_billed, 'FM99,99,990.00') || '). Skipped ' || v_duplicates_skipped || ' existing invoices.',
        NOW()
    );

    -- Update rule statistics and next_run_at
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
        'due_date', v_due_date,
        'billing_period', v_billing_period,
        'next_run_at', v_next_run,
        'message', 'Successfully generated ' || v_invoices_created || ' invoices for ' || v_rule.rule_name
    );
END;
$$;


-- 6. FUNCTION: fn_process_due_fee_schedules
-- Batch processor called by background scheduler cron.
CREATE OR REPLACE FUNCTION public.fn_process_due_fee_schedules()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    r RECORD;
    v_results JSONB := '[]'::jsonb;
    v_run_res JSONB;
    v_count INT := 0;
BEGIN
    FOR r IN 
        SELECT id, rule_name 
        FROM public.student_fee_schedule_rules
        WHERE is_active = true 
          AND (next_run_at IS NULL OR next_run_at <= NOW())
        ORDER BY next_run_at ASC NULLS FIRST
    LOOP
        v_run_res := public.fn_execute_fee_schedule_rule(r.id, NULL, 'Automated System Scheduler');
        v_results := v_results || jsonb_build_array(v_run_res);
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'rules_processed_count', v_count,
        'results', v_results
    );
END;
$$;


-- 7. FUNCTION: fn_bulk_generate_student_invoices_v2
-- Flexible on-demand bulk invoice generator.
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
    p_skip_duplicates BOOLEAN DEFAULT true
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sid UUID;
    v_student_count INT := 0;
    v_invoices_created INT := 0;
    v_duplicates_skipped INT := 0;
    v_total_billed NUMERIC(12,2) := 0.0;
    v_seq INT := 0;
    v_inv_num TEXT;
    v_inv_id UUID;
    v_actor_name TEXT := COALESCE(p_user_name, 'Admin');
    v_actor_email TEXT := '';
    v_actor_role TEXT := 'admin';
    v_already_exists BOOLEAN;
BEGIN
    IF p_user_id IS NOT NULL THEN
        SELECT COALESCE(full_name, 'Admin'), COALESCE(email, ''), COALESCE(role, 'admin')
        INTO v_actor_name, v_actor_email, v_actor_role
        FROM public.profiles
        WHERE id = p_user_id;
    END IF;

    FOR v_sid IN 
        SELECT p.id 
        FROM public.profiles p
        WHERE p.school_id = p_school_id 
          AND p.role = 'student'
          AND (
            p_target_type = 'ALL'
            OR (p_target_type = 'CLASS' AND (
                p_target_class IS NULL 
                OR p_target_class IN ('All Classes', 'All', '')
                OR p.class = p_target_class
                OR REPLACE(LOWER(COALESCE(p.class, '')), ' ', '') = REPLACE(LOWER(p_target_class), ' ', '')
            ))
            OR (p_target_type = 'INDIVIDUALS' AND (
                p_student_ids ? p.id::TEXT
            ))
          )
    LOOP
        v_student_count := v_student_count + 1;

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
            SELECT COUNT(*) + 1 INTO v_seq
            FROM public.student_fee_invoices
            WHERE school_id = p_school_id;
            v_inv_num := 'INV-2026-' || LPAD(v_seq::text, 5, '0');

            INSERT INTO public.student_fee_invoices (
                school_id, student_id, invoice_number, title, fee_type, fee_plan,
                academic_year, billing_date, due_date, subtotal, total_billed,
                paid_amount, balance_amount, status, notes, created_at, updated_at
            ) VALUES (
                p_school_id, v_sid, v_inv_num, p_title, p_fee_type, COALESCE(p_fee_plan, 'Monthly'),
                COALESCE(p_academic_year, '2026 - 2027'), CURRENT_DATE, p_due_date, p_amount, p_amount,
                0.0, p_amount, 'Pending', p_notes, NOW(), NOW()
            ) RETURNING id INTO v_inv_id;

            INSERT INTO public.student_fee_audit_logs (
                school_id, student_id, entity_type, entity_id, action,
                description, old_status, new_status, amount,
                performed_by_id, performed_by_name, performed_by_email, performed_by_role
            ) VALUES (
                p_school_id, v_sid, 'INVOICE', v_inv_id, 'INVOICE_GENERATED',
                'Bulk generated invoice ' || v_inv_num || ' for ' || p_title || ' of ₹' || TO_CHAR(p_amount, 'FM99,99,990.00'),
                NULL, 'Pending', p_amount,
                p_user_id, v_actor_name, v_actor_email, v_actor_role
            );

            v_invoices_created := v_invoices_created + 1;
            v_total_billed := v_total_billed + p_amount;
        END IF;
    END LOOP;

    -- Record run telemetry
    INSERT INTO public.student_fee_schedule_runs (
        school_id, rule_name, triggered_by, triggered_by_name, trigger_type,
        status, invoices_created, students_targeted, duplicates_skipped,
        total_amount_billed, billing_period, due_date, execution_notes, executed_at
    ) VALUES (
        p_school_id, 'On-Demand Bulk Invoicing (' || COALESCE(p_target_class, p_target_type) || ')',
        p_user_id, v_actor_name, 'BULK_EXECUTE',
        CASE WHEN v_invoices_created > 0 OR v_duplicates_skipped > 0 THEN 'SUCCESS' ELSE 'FAILED' END,
        v_invoices_created, v_student_count, v_duplicates_skipped,
        v_total_billed, TO_CHAR(CURRENT_DATE, 'FMMonth YYYY'), p_due_date,
        'Bulk generated ' || v_invoices_created || ' invoices (Total ₹' || TO_CHAR(v_total_billed, 'FM99,99,990.00') || '). Skipped ' || v_duplicates_skipped || ' duplicates.',
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'invoices_created', v_invoices_created,
        'students_targeted', v_student_count,
        'duplicates_skipped', v_duplicates_skipped,
        'total_amount_billed', v_total_billed,
        'message', 'Generated ' || v_invoices_created || ' invoices. Skipped ' || v_duplicates_skipped || ' duplicates.'
    );
END;
$$;


-- 8. SEED DEFAULT AUTOMATION RULES
DO $$
DECLARE
    v_sch UUID;
    v_admin_id UUID;
BEGIN
    SELECT id INTO v_sch FROM public.schools LIMIT 1;
    SELECT id INTO v_admin_id FROM public.profiles WHERE role = 'super_admin' LIMIT 1;

    IF v_sch IS NOT NULL THEN
        -- Rule 1: Monthly Tuition Fee for Class 10A
        IF NOT EXISTS (SELECT 1 FROM public.student_fee_schedule_rules WHERE school_id = v_sch AND rule_name = 'Monthly Tuition Auto-Billing - Class 10A') THEN
            INSERT INTO public.student_fee_schedule_rules (
                school_id, rule_name, target_type, target_class, fee_type, fee_plan,
                amount, title_template, notes, frequency, schedule_day_of_month, due_days_offset,
                billing_period_target, academic_year, is_active, next_run_at, created_by
            ) VALUES (
                v_sch, 'Monthly Tuition Auto-Billing - Class 10A', 'CLASS', '10 A', 'Tuition Fee', 'Monthly',
                4500.00, 'Tuition & Academic Amenities - {MONTH} {YEAR}',
                'Automated monthly tuition billing with 10 days payment window',
                'MONTHLY', 25, 10, 'NEXT_MONTH', '2026 - 2027', true,
                public.fn_calculate_next_fee_schedule_run('MONTHLY', 25, NOW()),
                v_admin_id
            );
        END IF;

        -- Rule 2: Monthly Tuition Fee for Entire High School (All Classes)
        IF NOT EXISTS (SELECT 1 FROM public.student_fee_schedule_rules WHERE school_id = v_sch AND rule_name = 'School-Wide Monthly Composite Tuition') THEN
            INSERT INTO public.student_fee_schedule_rules (
                school_id, rule_name, target_type, target_class, fee_type, fee_plan,
                amount, title_template, notes, frequency, schedule_day_of_month, due_days_offset,
                billing_period_target, academic_year, is_active, next_run_at, created_by
            ) VALUES (
                v_sch, 'School-Wide Monthly Composite Tuition', 'ALL', 'All Classes', 'Tuition Fee', 'Monthly',
                4500.00, 'Monthly Tuition & Campus Facilities - {MONTH} {YEAR}',
                'Recurring monthly tuition invoice for all enrolled students',
                'MONTHLY', 25, 10, 'NEXT_MONTH', '2026 - 2027', true,
                public.fn_calculate_next_fee_schedule_run('MONTHLY', 25, NOW()),
                v_admin_id
            );
        END IF;

        -- Rule 3: Quarterly Science & Computer Lab Fee
        IF NOT EXISTS (SELECT 1 FROM public.student_fee_schedule_rules WHERE school_id = v_sch AND rule_name = 'Quarterly STEM & Computing Lab Access') THEN
            INSERT INTO public.student_fee_schedule_rules (
                school_id, rule_name, target_type, target_class, fee_type, fee_plan,
                amount, title_template, notes, frequency, schedule_day_of_month, due_days_offset,
                billing_period_target, academic_year, is_active, next_run_at, created_by
            ) VALUES (
                v_sch, 'Quarterly STEM & Computing Lab Access', 'CLASS', 'Class 9 - 12', 'Science & Computer Lab Fee', 'Quarterly',
                2500.00, 'Quarterly Lab & Tech Fee - {QUARTER} {YEAR}',
                'Quarterly lab access fee for senior students with 15 days due window',
                'QUARTERLY', 1, 15, 'NEXT_QUARTER', '2026 - 2027', false,
                public.fn_calculate_next_fee_schedule_run('QUARTERLY', 1, NOW()),
                v_admin_id
            );
        END IF;
    END IF;
END $$;
