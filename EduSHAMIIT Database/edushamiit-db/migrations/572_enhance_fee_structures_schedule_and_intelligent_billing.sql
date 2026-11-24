-- ============================================================================
-- Migration 572: Enhanced Fee Structure Schedules, Installment Dates & Intelligent Billing
-- ============================================================================

-- 1. Add columns to public.student_fee_structures
ALTER TABLE public.student_fee_structures
ADD COLUMN IF NOT EXISTS academic_start_date DATE DEFAULT '2026-04-01',
ADD COLUMN IF NOT EXISTS installment_dates JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS reminder_stages JSONB DEFAULT '{"d_10": true, "d_5": true, "d_2": true, "d_1": true, "d_due": true, "d_overdue": true}'::jsonb;

-- 2. Backfill existing fee structures with default academic_start_date and installment_dates
DO $$
DECLARE
    r RECORD;
    v_dates JSONB;
    v_cycle TEXT;
    v_freq TEXT;
    v_amt NUMERIC;
BEGIN
    FOR r IN SELECT id, billing_cycle, frequency_type, amount, due_day_of_cycle, installment_dates FROM public.student_fee_structures LOOP
        v_cycle := COALESCE(r.billing_cycle, 'Monthly');
        v_freq := COALESCE(r.frequency_type, v_cycle);
        v_amt := COALESCE(r.amount, 0.0);

        -- If installment_dates is empty or '[]'::jsonb, generate sensible defaults for 2026-2027
        IF r.installment_dates IS NULL OR jsonb_array_length(r.installment_dates) = 0 THEN
            IF v_freq IN ('Monthly', 'monthly') OR v_cycle IN ('Monthly', 'monthly') THEN
                v_dates := jsonb_build_array(
                    jsonb_build_object('seq', 1, 'label', 'Apr 2026', 'date', '2026-04-30', 'amount', v_amt),
                    jsonb_build_object('seq', 2, 'label', 'May 2026', 'date', '2026-05-31', 'amount', v_amt),
                    jsonb_build_object('seq', 3, 'label', 'Jun 2026', 'date', '2026-06-30', 'amount', v_amt),
                    jsonb_build_object('seq', 4, 'label', 'Jul 2026', 'date', '2026-07-31', 'amount', v_amt),
                    jsonb_build_object('seq', 5, 'label', 'Aug 2026', 'date', '2026-08-31', 'amount', v_amt),
                    jsonb_build_object('seq', 6, 'label', 'Sep 2026', 'date', '2026-09-30', 'amount', v_amt),
                    jsonb_build_object('seq', 7, 'label', 'Oct 2026', 'date', '2026-10-31', 'amount', v_amt),
                    jsonb_build_object('seq', 8, 'label', 'Nov 2026', 'date', '2026-11-30', 'amount', v_amt),
                    jsonb_build_object('seq', 9, 'label', 'Dec 2026', 'date', '2026-12-31', 'amount', v_amt),
                    jsonb_build_object('seq', 10, 'label', 'Jan 2027', 'date', '2027-01-31', 'amount', v_amt),
                    jsonb_build_object('seq', 11, 'label', 'Feb 2027', 'date', '2027-02-28', 'amount', v_amt),
                    jsonb_build_object('seq', 12, 'label', 'Mar 2027', 'date', '2027-03-31', 'amount', v_amt)
                );
            ELSIF v_freq IN ('Quarterly', 'quarterly') OR v_cycle IN ('Quarterly', 'quarterly', 'Term-Wise') THEN
                v_dates := jsonb_build_array(
                    jsonb_build_object('seq', 1, 'label', 'Q1 (Apr-Jun)', 'date', '2026-06-30', 'amount', v_amt),
                    jsonb_build_object('seq', 2, 'label', 'Q2 (Jul-Sep)', 'date', '2026-09-30', 'amount', v_amt),
                    jsonb_build_object('seq', 3, 'label', 'Q3 (Oct-Dec)', 'date', '2026-12-31', 'amount', v_amt),
                    jsonb_build_object('seq', 4, 'label', 'Q4 (Jan-Mar)', 'date', '2027-03-31', 'amount', v_amt)
                );
            ELSIF v_freq IN ('Half-Yearly', 'half-yearly') OR v_cycle IN ('Half-Yearly', 'half-yearly') THEN
                v_dates := jsonb_build_array(
                    jsonb_build_object('seq', 1, 'label', 'Semester 1', 'date', '2026-09-30', 'amount', v_amt),
                    jsonb_build_object('seq', 2, 'label', 'Semester 2', 'date', '2027-03-31', 'amount', v_amt)
                );
            ELSIF v_freq IN ('Annual', 'annual') OR v_cycle IN ('Annual', 'annual') THEN
                v_dates := jsonb_build_array(
                    jsonb_build_object('seq', 1, 'label', 'Academic Year Fee', 'date', '2026-04-30', 'amount', v_amt)
                );
            ELSE
                v_dates := jsonb_build_array(
                    jsonb_build_object('seq', 1, 'label', 'One-Time Enrollment', 'date', '2026-04-30', 'amount', v_amt)
                );
            END IF;

            UPDATE public.student_fee_structures
            SET academic_start_date = COALESCE(academic_start_date, '2026-04-01'::date),
                installment_dates = v_dates,
                reminder_stages = COALESCE(reminder_stages, '{"d_10": true, "d_5": true, "d_2": true, "d_1": true, "d_due": true, "d_overdue": true}'::jsonb)
            WHERE id = r.id;
        END IF;
    END LOOP;
END $$;

-- 3. Stored Procedure: Save Student Fee Structure (Extended with Start Date, Installment Dates & Reminders)
CREATE OR REPLACE FUNCTION public.fn_save_student_fee_structure(
    p_school_id UUID,
    p_structure_id UUID,
    p_fee_name TEXT,
    p_fee_type TEXT,
    p_class_grade TEXT,
    p_billing_cycle TEXT,
    p_amount NUMERIC,
    p_description TEXT,
    p_is_mandatory BOOLEAN,
    p_section_name TEXT,
    p_frequency_type TEXT,
    p_due_day_of_cycle INT,
    p_grace_period_days INT,
    p_late_fine_amount NUMERIC,
    p_late_fine_type TEXT,
    p_is_refundable BOOLEAN,
    p_academic_year TEXT,
    p_academic_start_date DATE DEFAULT '2026-04-01',
    p_installment_dates JSONB DEFAULT '[]'::jsonb,
    p_reminder_stages JSONB DEFAULT '{"d_10": true, "d_5": true, "d_2": true, "d_1": true, "d_due": true, "d_overdue": true}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID := p_structure_id;
    v_freq TEXT := COALESCE(NULLIF(p_frequency_type, ''), 'Monthly');
    v_cycle TEXT := COALESCE(NULLIF(p_billing_cycle, ''), 'Monthly');
    v_start_date DATE := COALESCE(p_academic_start_date, '2026-04-01'::date);
    v_dates JSONB := COALESCE(p_installment_dates, '[]'::jsonb);
    v_reminders JSONB := COALESCE(p_reminder_stages, '{"d_10": true, "d_5": true, "d_2": true, "d_1": true, "d_due": true, "d_overdue": true}'::jsonb);
BEGIN
    IF v_freq IN ('One-Time', 'Monthly', 'Quarterly', 'Half-Yearly', 'Annual') AND v_cycle = 'Monthly' THEN
        v_cycle := v_freq;
    END IF;

    IF v_id IS NOT NULL THEN
        UPDATE public.student_fee_structures
        SET fee_name = p_fee_name,
            fee_type = p_fee_type,
            class_grade = COALESCE(NULLIF(p_class_grade, ''), 'All Classes'),
            section_name = COALESCE(NULLIF(p_section_name, ''), 'All Sections'),
            billing_cycle = v_cycle,
            frequency_type = v_freq,
            amount = COALESCE(p_amount, 0.0),
            description = p_description,
            is_mandatory = COALESCE(p_is_mandatory, true),
            is_refundable = COALESCE(p_is_refundable, false),
            due_day_of_cycle = COALESCE(p_due_day_of_cycle, 10),
            grace_period_days = COALESCE(p_grace_period_days, 5),
            late_fine_amount = COALESCE(p_late_fine_amount, 0.0),
            late_fine_type = COALESCE(p_late_fine_type, 'FLAT'),
            academic_year = COALESCE(p_academic_year, '2026 - 2027'),
            academic_start_date = v_start_date,
            installment_dates = v_dates,
            reminder_stages = v_reminders,
            updated_at = NOW()
        WHERE id = v_id AND school_id = p_school_id;
    ELSE
        INSERT INTO public.student_fee_structures (
            school_id, fee_name, fee_type, class_grade, section_name,
            billing_cycle, frequency_type, amount, due_day_of_cycle,
            grace_period_days, late_fine_amount, late_fine_type,
            is_mandatory, is_refundable, description, academic_year,
            academic_start_date, installment_dates, reminder_stages
        ) VALUES (
            p_school_id, p_fee_name, p_fee_type, COALESCE(NULLIF(p_class_grade, ''), 'All Classes'),
            COALESCE(NULLIF(p_section_name, ''), 'All Sections'),
            v_cycle, v_freq, COALESCE(p_amount, 0.0), COALESCE(p_due_day_of_cycle, 10),
            COALESCE(p_grace_period_days, 5), COALESCE(p_late_fine_amount, 0.0),
            COALESCE(p_late_fine_type, 'FLAT'), COALESCE(p_is_mandatory, true),
            COALESCE(p_is_refundable, false), p_description, COALESCE(p_academic_year, '2026 - 2027'),
            v_start_date, v_dates, v_reminders
        ) RETURNING id INTO v_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Fee structure saved successfully',
        'structure_id', v_id
    );
END;
$$;

-- 4. Stored Procedure: List Student Fee Structures (Enriched with Start Date & Installment Dates)
CREATE OR REPLACE FUNCTION public.fn_list_student_fee_structures(
    p_school_id UUID,
    p_class_grade TEXT DEFAULT NULL,
    p_section_name TEXT DEFAULT NULL,
    p_frequency_type TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_structures JSONB := '[]'::jsonb;
    v_summary JSONB;
    v_total_annual NUMERIC(14,2) := 0.0;
    v_monthly_annual NUMERIC(14,2) := 0.0;
    v_quarterly_annual NUMERIC(14,2) := 0.0;
    v_half_yearly_annual NUMERIC(14,2) := 0.0;
    v_annual_total NUMERIC(14,2) := 0.0;
    v_one_time_total NUMERIC(14,2) := 0.0;
    v_total_heads INT := 0;
BEGIN
    WITH matching_heads AS (
        SELECT
            s.id,
            s.school_id,
            s.fee_name,
            s.fee_type,
            COALESCE(s.class_grade, 'All Classes') AS class_grade,
            COALESCE(s.section_name, 'All Sections') AS section_name,
            COALESCE(s.billing_cycle, 'Monthly') AS billing_cycle,
            COALESCE(s.frequency_type, 'Monthly') AS frequency_type,
            COALESCE(s.amount, 0.0) AS amount,
            -- Calculate annual commitment based on custom installment count if present, else standard multiplier
            CASE 
                WHEN s.installment_dates IS NOT NULL AND jsonb_array_length(s.installment_dates) > 0 
                    THEN COALESCE(s.amount, 0.0) * jsonb_array_length(s.installment_dates)
                WHEN COALESCE(s.frequency_type, 'Monthly') = 'One-Time' THEN COALESCE(s.amount, 0.0)
                WHEN COALESCE(s.frequency_type, 'Monthly') = 'Monthly' THEN COALESCE(s.amount, 0.0) * 12.0
                WHEN COALESCE(s.frequency_type, 'Monthly') = 'Quarterly' THEN COALESCE(s.amount, 0.0) * 4.0
                WHEN COALESCE(s.frequency_type, 'Monthly') = 'Half-Yearly' THEN COALESCE(s.amount, 0.0) * 2.0
                WHEN COALESCE(s.frequency_type, 'Monthly') = 'Annual' THEN COALESCE(s.amount, 0.0)
                ELSE COALESCE(s.amount, 0.0) * 12.0
            END AS annual_commitment,
            COALESCE(s.due_day_of_cycle, 10) AS due_day_of_cycle,
            COALESCE(s.grace_period_days, 5) AS grace_period_days,
            COALESCE(s.late_fine_amount, 0.0) AS late_fine_amount,
            COALESCE(s.late_fine_type, 'FLAT') AS late_fine_type,
            COALESCE(s.is_mandatory, true) AS is_mandatory,
            COALESCE(s.is_refundable, false) AS is_refundable,
            s.description,
            COALESCE(s.status, 'ACTIVE') AS status,
            COALESCE(s.academic_year, '2026 - 2027') AS academic_year,
            COALESCE(s.academic_start_date, '2026-04-01'::date) AS academic_start_date,
            COALESCE(s.installment_dates, '[]'::jsonb) AS installment_dates,
            COALESCE(s.reminder_stages, '{"d_10": true, "d_5": true, "d_2": true, "d_1": true, "d_due": true, "d_overdue": true}'::jsonb) AS reminder_stages,
            CASE 
                WHEN s.installment_dates IS NOT NULL AND jsonb_array_length(s.installment_dates) > 0 
                    THEN jsonb_array_length(s.installment_dates)
                WHEN COALESCE(s.frequency_type, 'Monthly') = 'Monthly' THEN 12
                WHEN COALESCE(s.frequency_type, 'Monthly') = 'Quarterly' THEN 4
                WHEN COALESCE(s.frequency_type, 'Monthly') = 'Half-Yearly' THEN 2
                ELSE 1
            END AS installment_count,
            s.created_at,
            s.updated_at
        FROM public.student_fee_structures s
        WHERE s.school_id = p_school_id
          AND s.status = 'ACTIVE'
          AND (p_class_grade IS NULL OR p_class_grade = '' OR p_class_grade = 'All Classes' 
               OR s.class_grade = 'All Classes' OR s.class_grade = p_class_grade)
          AND (p_section_name IS NULL OR p_section_name = '' OR p_section_name = 'All Sections' 
               OR s.section_name = 'All Sections' OR s.section_name = p_section_name)
          AND (p_frequency_type IS NULL OR p_frequency_type = '' OR p_frequency_type = 'All' 
               OR s.frequency_type = p_frequency_type)
          AND (p_search IS NULL OR p_search = '' 
               OR s.fee_name ILIKE '%' || p_search || '%' 
               OR s.fee_type ILIKE '%' || p_search || '%'
               OR s.class_grade ILIKE '%' || p_search || '%')
        ORDER BY 
            CASE WHEN s.class_grade = 'All Classes' THEN 2 ELSE 1 END,
            s.fee_name ASC
    )
    SELECT
        COALESCE(jsonb_agg(to_jsonb(m)), '[]'::jsonb),
        COUNT(*),
        COALESCE(SUM(m.annual_commitment), 0.0),
        COALESCE(SUM(CASE WHEN m.frequency_type = 'Monthly' THEN m.annual_commitment ELSE 0.0 END), 0.0),
        COALESCE(SUM(CASE WHEN m.frequency_type = 'Quarterly' THEN m.annual_commitment ELSE 0.0 END), 0.0),
        COALESCE(SUM(CASE WHEN m.frequency_type = 'Half-Yearly' THEN m.annual_commitment ELSE 0.0 END), 0.0),
        COALESCE(SUM(CASE WHEN m.frequency_type = 'Annual' THEN m.annual_commitment ELSE 0.0 END), 0.0),
        COALESCE(SUM(CASE WHEN m.frequency_type = 'One-Time' THEN m.annual_commitment ELSE 0.0 END), 0.0)
    INTO
        v_structures,
        v_total_heads,
        v_total_annual,
        v_monthly_annual,
        v_quarterly_annual,
        v_half_yearly_annual,
        v_annual_total,
        v_one_time_total
    FROM matching_heads m;

    v_summary := jsonb_build_object(
        'cohort_class', COALESCE(p_class_grade, 'All Classes'),
        'cohort_section', COALESCE(p_section_name, 'All Sections'),
        'total_fee_heads', v_total_heads,
        'total_annual_liability', v_total_annual,
        'monthly_annual_total', v_monthly_annual,
        'monthly_rate', ROUND(v_monthly_annual / 12.0, 2),
        'quarterly_annual_total', v_quarterly_annual,
        'quarterly_rate', ROUND(v_quarterly_annual / 4.0, 2),
        'half_yearly_annual_total', v_half_yearly_annual,
        'annual_charges_total', v_annual_total,
        'one_time_admission_total', v_one_time_total
    );

    RETURN jsonb_build_object(
        'success', true,
        'structures', v_structures,
        'summary', v_summary
    );
END;
$$;

-- 5. Stored Procedure: Intelligent Cohort Due Fee Evaluation
-- Automatically assesses which fee heads and specific installment dates are due RIGHT NOW for a cohort,
-- and which fee heads (like Exams 3 months away) should be skipped/protected.
CREATE OR REPLACE FUNCTION public.fn_evaluate_cohort_due_fee_heads(
    p_school_id UUID,
    p_class_grade TEXT,
    p_section_name TEXT DEFAULT 'All Sections',
    p_academic_year TEXT DEFAULT '2026 - 2027',
    p_reference_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_cls TEXT := COALESCE(NULLIF(p_class_grade, ''), 'All Classes');
    v_sec TEXT := COALESCE(NULLIF(p_section_name, ''), 'All Sections');
    v_ref_date DATE := COALESCE(p_reference_date, CURRENT_DATE);
    v_ref_month_start DATE := date_trunc('month', v_ref_date)::date;
    v_ref_month_end DATE := (date_trunc('month', v_ref_date) + interval '1 month - 1 day')::date;
    
    v_due_heads JSONB := '[]'::jsonb;
    v_future_heads JSONB := '[]'::jsonb;
    v_completed_heads JSONB := '[]'::jsonb;

    v_head RECORD;
    v_inst RECORD;
    v_inst_date DATE;
    v_inst_label TEXT;
    v_inst_seq INT;
    v_inst_amount NUMERIC;
    v_is_due BOOLEAN;
    v_days_diff INT;
    v_already_billed BOOLEAN;
    v_late_penalty_note TEXT;
BEGIN
    FOR v_head IN
        WITH ranked_heads AS (
            SELECT 
                s.id, s.fee_name, s.fee_type, s.class_grade, s.section_name,
                s.billing_cycle, s.frequency_type, s.amount, s.due_day_of_cycle,
                s.grace_period_days, s.late_fine_amount, s.late_fine_type,
                s.is_mandatory, s.is_refundable, s.status, s.academic_year,
                s.academic_start_date, s.installment_dates, s.reminder_stages,
                CASE 
                    WHEN LOWER(TRIM(s.class_grade)) = LOWER(TRIM(v_cls)) 
                         AND LOWER(TRIM(s.section_name)) = LOWER(TRIM(v_sec)) THEN 1
                    WHEN LOWER(TRIM(s.class_grade)) = LOWER(TRIM(v_cls)) 
                         AND (LOWER(TRIM(s.section_name)) IN ('all sections', 'all', '') OR s.section_name IS NULL) THEN 2
                    WHEN LOWER(TRIM(s.class_grade)) IN ('all classes', 'all', '') OR s.class_grade IS NULL THEN 3
                    ELSE 99
                END AS cohort_rank,
                ROW_NUMBER() OVER (
                    PARTITION BY LOWER(TRIM(s.fee_name)) 
                    ORDER BY 
                        CASE 
                            WHEN LOWER(TRIM(s.class_grade)) = LOWER(TRIM(v_cls)) 
                                 AND LOWER(TRIM(s.section_name)) = LOWER(TRIM(v_sec)) THEN 1
                            WHEN LOWER(TRIM(s.class_grade)) = LOWER(TRIM(v_cls)) 
                                 AND (LOWER(TRIM(s.section_name)) IN ('all sections', 'all', '') OR s.section_name IS NULL) THEN 2
                            WHEN LOWER(TRIM(s.class_grade)) IN ('all classes', 'all', '') OR s.class_grade IS NULL THEN 3
                            ELSE 99
                        END ASC,
                        s.updated_at DESC
                ) AS rank_in_name
            FROM public.student_fee_structures s
            WHERE s.school_id = p_school_id
              AND s.status = 'ACTIVE'
              AND (s.academic_year = p_academic_year OR s.academic_year IS NULL)
              AND (
                  (LOWER(TRIM(s.class_grade)) = LOWER(TRIM(v_cls)) AND (LOWER(TRIM(s.section_name)) = LOWER(TRIM(v_sec)) OR LOWER(TRIM(s.section_name)) IN ('all sections', 'all', '') OR s.section_name IS NULL))
                  OR (LOWER(TRIM(s.class_grade)) = LOWER(TRIM(v_cls)))
                  OR (LOWER(TRIM(s.class_grade)) IN ('all classes', 'all', '') OR s.class_grade IS NULL)
              )
        )
        SELECT * FROM ranked_heads WHERE rank_in_name = 1 ORDER BY cohort_rank ASC, fee_name ASC
    LOOP
        -- Penalty formatting note
        IF v_head.late_fine_amount > 0 THEN
            v_late_penalty_note := 'Late fee of ₹' || v_head.late_fine_amount::text || ' (' || v_head.late_fine_type || ') applies after ' || v_head.grace_period_days::text || ' days grace period.';
        ELSE
            v_late_penalty_note := 'No late fine surcharge configured.';
        END IF;

        -- Iterate through the installment dates of this fee head
        v_is_due := FALSE;
        IF v_head.installment_dates IS NOT NULL AND jsonb_array_length(v_head.installment_dates) > 0 THEN
            FOR v_inst IN 
                SELECT 
                    (item->>'seq')::int AS seq,
                    item->>'label' AS label,
                    COALESCE(NULLIF(item->>'date', ''), NULLIF(item->>'due_date', ''))::date AS due_date,
                    COALESCE((item->>'amount')::numeric, v_head.amount) AS inst_amount
                FROM jsonb_array_elements(v_head.installment_dates) AS item
                WHERE COALESCE(NULLIF(item->>'date', ''), NULLIF(item->>'due_date', '')) IS NOT NULL
                ORDER BY COALESCE(NULLIF(item->>'date', ''), NULLIF(item->>'due_date', ''))::date ASC
            LOOP
                v_inst_date := v_inst.due_date;
                v_days_diff := v_inst_date - v_ref_date;

                -- Check if an invoice was already generated for this cohort for this fee head and installment date
                SELECT EXISTS (
                    SELECT 1 FROM public.student_fee_invoices inv
                    JOIN public.profiles st ON st.id = inv.student_id
                    WHERE inv.school_id = p_school_id
                      AND (inv.fee_structure_id = v_head.id OR LOWER(TRIM(inv.title)) = LOWER(TRIM(v_head.fee_name || ' (' || v_inst.label || ')')))
                      AND inv.due_date = v_inst_date
                      AND inv.status != 'CANCELLED'
                      AND (v_cls = 'All Classes' OR st.class = v_cls OR EXISTS (
                          SELECT 1 FROM public.student_class_assignments sca
                          JOIN public.academic_classes ac ON ac.id = sca.class_id
                          WHERE sca.student_id = st.id AND ac.name = v_cls
                      ))
                    LIMIT 1
                ) INTO v_already_billed;

                -- If installment falls within current month or within next 30 days or is overdue but not billed
                IF NOT v_already_billed AND (
                    (v_inst_date >= v_ref_month_start AND v_inst_date <= v_ref_month_end)
                    OR (v_days_diff >= -30 AND v_days_diff <= 35)
                ) THEN
                    v_is_due := TRUE;
                    v_due_heads := v_due_heads || jsonb_build_object(
                        'fee_structure_id', v_head.id,
                        'fee_name', v_head.fee_name,
                        'fee_type', v_head.fee_type,
                        'billing_cycle', v_head.billing_cycle,
                        'frequency_type', v_head.frequency_type,
                        'installment_seq', v_inst.seq,
                        'installment_label', v_inst.label,
                        'due_date', v_inst.due_date,
                        'days_diff', v_days_diff,
                        'amount', v_inst.inst_amount,
                        'suggested_title', v_head.fee_name || ' (' || v_inst.label || ')',
                        'late_fine_amount', v_head.late_fine_amount,
                        'late_fine_type', v_head.late_fine_type,
                        'late_penalty_note', v_late_penalty_note,
                        'grace_period_days', v_head.grace_period_days,
                        'is_mandatory', v_head.is_mandatory,
                        'cohort_rank', v_head.cohort_rank
                    );
                    -- Handled current active installment, don't double count for this head
                    EXIT;
                ELSIF v_already_billed THEN
                    v_completed_heads := v_completed_heads || jsonb_build_object(
                        'fee_structure_id', v_head.id,
                        'fee_name', v_head.fee_name,
                        'installment_label', v_inst.label,
                        'due_date', v_inst.due_date,
                        'amount', v_inst.inst_amount,
                        'status', 'ALREADY_BILLED'
                    );
                ELSIF v_days_diff > 35 THEN
                    v_future_heads := v_future_heads || jsonb_build_object(
                        'fee_structure_id', v_head.id,
                        'fee_name', v_head.fee_name,
                        'installment_label', v_inst.label,
                        'due_date', v_inst.due_date,
                        'amount', v_inst.inst_amount,
                        'days_until_due', v_days_diff,
                        'status', 'FUTURE_SCHEDULED',
                        'skip_reason', 'Scheduled for ' || to_char(v_inst.due_date, 'DD Mon YYYY') || ' (' || v_days_diff::text || ' days away - protected from early billing)'
                    );
                END IF;
            END LOOP;
        ELSE
            -- Fallback if no installment_dates defined: standard monthly assessment
            v_due_heads := v_due_heads || jsonb_build_object(
                'fee_structure_id', v_head.id,
                'fee_name', v_head.fee_name,
                'fee_type', v_head.fee_type,
                'billing_cycle', v_head.billing_cycle,
                'frequency_type', v_head.frequency_type,
                'installment_seq', 1,
                'installment_label', to_char(v_ref_date, 'Mon YYYY'),
                'due_date', (v_ref_month_end),
                'days_diff', (v_ref_month_end - v_ref_date),
                'amount', v_head.amount,
                'suggested_title', v_head.fee_name || ' - ' || to_char(v_ref_date, 'Mon YYYY'),
                'late_fine_amount', v_head.late_fine_amount,
                'late_fine_type', v_head.late_fine_type,
                'late_penalty_note', v_late_penalty_note,
                'grace_period_days', v_head.grace_period_days,
                'is_mandatory', v_head.is_mandatory,
                'cohort_rank', v_head.cohort_rank
            );
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'reference_date', v_ref_date,
        'cohort_class', v_cls,
        'cohort_section', v_sec,
        'due_heads_count', jsonb_array_length(v_due_heads),
        'due_heads', v_due_heads,
        'future_heads_count', jsonb_array_length(v_future_heads),
        'future_heads', v_future_heads,
        'completed_heads_count', jsonb_array_length(v_completed_heads),
        'completed_heads', v_completed_heads
    );
END;
$$;
