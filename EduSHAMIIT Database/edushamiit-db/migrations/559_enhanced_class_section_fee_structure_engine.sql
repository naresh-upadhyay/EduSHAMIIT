-- ==============================================================================
-- Migration: 559_enhanced_class_section_fee_structure_engine.sql
-- Description: Comprehensive Class & Section Fee Structure Hierarchy with 
--              multi-parameter frequency (One-Time, Monthly, Quarterly, Half-Yearly, Annual),
--              due day schedule, late fine policy, 1-click cohort cloning, and 
--              student-applicable fee structure resolution for invoicing and collection.
-- ==============================================================================

-- 1. Schema Enhancements on public.student_fee_structures
ALTER TABLE public.student_fee_audit_logs ALTER COLUMN student_id DROP NOT NULL;

ALTER TABLE public.student_fee_structures
    ADD COLUMN IF NOT EXISTS section_name VARCHAR(50) DEFAULT 'All Sections',
    ADD COLUMN IF NOT EXISTS frequency_type VARCHAR(50) DEFAULT 'Monthly',
    ADD COLUMN IF NOT EXISTS due_day_of_cycle INT DEFAULT 10,
    ADD COLUMN IF NOT EXISTS grace_period_days INT DEFAULT 5,
    ADD COLUMN IF NOT EXISTS late_fine_amount NUMERIC(10,2) DEFAULT 0.0,
    ADD COLUMN IF NOT EXISTS late_fine_type VARCHAR(20) DEFAULT 'FLAT',
    ADD COLUMN IF NOT EXISTS is_refundable BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS academic_year VARCHAR(50) DEFAULT '2026 - 2027';

-- Backfill frequency_type for existing records based on billing_cycle
UPDATE public.student_fee_structures
SET frequency_type = CASE
    WHEN billing_cycle ILIKE '%one%' THEN 'One-Time'
    WHEN billing_cycle ILIKE '%quarter%' THEN 'Quarterly'
    WHEN billing_cycle ILIKE '%half%' OR billing_cycle ILIKE '%term%' THEN 'Half-Yearly'
    WHEN billing_cycle ILIKE '%annual%' THEN 'Annual'
    ELSE 'Monthly'
END
WHERE frequency_type IS NULL OR frequency_type = '' OR frequency_type = 'Monthly';

-- Create index for class and section lookup
CREATE INDEX IF NOT EXISTS idx_student_fee_struct_cohort 
ON public.student_fee_structures (school_id, class_grade, section_name, status);


-- 2. Enhanced fn_list_student_fee_structures with filtering, annual liability, and cohort summary
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
    -- Query matching structures with computed annual liability
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
            CASE COALESCE(s.frequency_type, 'Monthly')
                WHEN 'One-Time' THEN COALESCE(s.amount, 0.0) * 1.0
                WHEN 'Monthly' THEN COALESCE(s.amount, 0.0) * 12.0
                WHEN 'Quarterly' THEN COALESCE(s.amount, 0.0) * 4.0
                WHEN 'Half-Yearly' THEN COALESCE(s.amount, 0.0) * 2.0
                WHEN 'Annual' THEN COALESCE(s.amount, 0.0) * 1.0
                ELSE COALESCE(s.amount, 0.0) * 1.0
            END AS annual_liability,
            COALESCE(s.due_day_of_cycle, 10) AS due_day_of_cycle,
            COALESCE(s.grace_period_days, 5) AS grace_period_days,
            COALESCE(s.late_fine_amount, 0.0) AS late_fine_amount,
            COALESCE(s.late_fine_type, 'FLAT') AS late_fine_type,
            COALESCE(s.is_mandatory, true) AS is_mandatory,
            COALESCE(s.is_refundable, false) AS is_refundable,
            COALESCE(s.description, '') AS description,
            COALESCE(s.status, 'ACTIVE') AS status,
            COALESCE(s.academic_year, '2026 - 2027') AS academic_year,
            s.created_at
        FROM public.student_fee_structures s
        WHERE s.school_id = p_school_id
          AND s.status = 'ACTIVE'
          AND (p_class_grade IS NULL OR p_class_grade IN ('All Classes', 'All', '') OR s.class_grade = p_class_grade OR s.class_grade = 'All Classes')
          AND (p_section_name IS NULL OR p_section_name IN ('All Sections', 'All', '') OR s.section_name = p_section_name OR s.section_name = 'All Sections')
          AND (p_frequency_type IS NULL OR p_frequency_type IN ('All Frequencies', 'All', '') OR s.frequency_type = p_frequency_type)
          AND (
              p_search IS NULL OR p_search = '' OR
              s.fee_name ILIKE '%' || p_search || '%' OR
              s.fee_type ILIKE '%' || p_search || '%' OR
              s.class_grade ILIKE '%' || p_search || '%' OR
              s.description ILIKE '%' || p_search || '%'
          )
        ORDER BY 
            CASE s.frequency_type
                WHEN 'One-Time' THEN 1
                WHEN 'Annual' THEN 2
                WHEN 'Half-Yearly' THEN 3
                WHEN 'Quarterly' THEN 4
                WHEN 'Monthly' THEN 5
                ELSE 6
            END,
            s.fee_name ASC
    )
    SELECT 
        COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', m.id,
                'fee_name', m.fee_name,
                'fee_type', m.fee_type,
                'class_grade', m.class_grade,
                'section_name', m.section_name,
                'billing_cycle', m.billing_cycle,
                'frequency_type', m.frequency_type,
                'amount', m.amount,
                'annual_liability', m.annual_liability,
                'due_day_of_cycle', m.due_day_of_cycle,
                'grace_period_days', m.grace_period_days,
                'late_fine_amount', m.late_fine_amount,
                'late_fine_type', m.late_fine_type,
                'is_mandatory', m.is_mandatory,
                'is_refundable', m.is_refundable,
                'description', m.description,
                'status', m.status,
                'academic_year', m.academic_year
            )
        ), '[]'::jsonb),
        COUNT(*),
        COALESCE(SUM(m.annual_liability), 0.0),
        COALESCE(SUM(CASE WHEN m.frequency_type = 'Monthly' THEN m.annual_liability ELSE 0 END), 0.0),
        COALESCE(SUM(CASE WHEN m.frequency_type = 'Quarterly' THEN m.annual_liability ELSE 0 END), 0.0),
        COALESCE(SUM(CASE WHEN m.frequency_type = 'Half-Yearly' THEN m.annual_liability ELSE 0 END), 0.0),
        COALESCE(SUM(CASE WHEN m.frequency_type = 'Annual' THEN m.annual_liability ELSE 0 END), 0.0),
        COALESCE(SUM(CASE WHEN m.frequency_type = 'One-Time' THEN m.annual_liability ELSE 0 END), 0.0)
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


-- 3. Enhanced fn_save_student_fee_structure with Class, Section, Frequency, Due Day, and Late Fine Rules
CREATE OR REPLACE FUNCTION public.fn_save_student_fee_structure(
    p_school_id UUID,
    p_structure_id UUID,
    p_fee_name TEXT,
    p_fee_type TEXT,
    p_class_grade TEXT,
    p_billing_cycle TEXT,
    p_amount NUMERIC,
    p_description TEXT DEFAULT NULL,
    p_is_mandatory BOOLEAN DEFAULT true,
    p_section_name TEXT DEFAULT 'All Sections',
    p_frequency_type TEXT DEFAULT 'Monthly',
    p_due_day_of_cycle INT DEFAULT 10,
    p_grace_period_days INT DEFAULT 5,
    p_late_fine_amount NUMERIC DEFAULT 0.0,
    p_late_fine_type TEXT DEFAULT 'FLAT',
    p_is_refundable BOOLEAN DEFAULT false,
    p_academic_year TEXT DEFAULT '2026 - 2027'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID := p_structure_id;
    v_freq TEXT := COALESCE(NULLIF(p_frequency_type, ''), 'Monthly');
    v_cycle TEXT := COALESCE(NULLIF(p_billing_cycle, ''), 'Monthly');
BEGIN
    -- Synchronize billing cycle and frequency if one is generic
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
            updated_at = NOW()
        WHERE id = v_id AND school_id = p_school_id;
    ELSE
        INSERT INTO public.student_fee_structures (
            school_id, fee_name, fee_type, class_grade, section_name,
            billing_cycle, frequency_type, amount, due_day_of_cycle,
            grace_period_days, late_fine_amount, late_fine_type,
            is_mandatory, is_refundable, description, academic_year
        ) VALUES (
            p_school_id, p_fee_name, p_fee_type, COALESCE(NULLIF(p_class_grade, ''), 'All Classes'),
            COALESCE(NULLIF(p_section_name, ''), 'All Sections'),
            v_cycle, v_freq, COALESCE(p_amount, 0.0), COALESCE(p_due_day_of_cycle, 10),
            COALESCE(p_grace_period_days, 5), COALESCE(p_late_fine_amount, 0.0),
            COALESCE(p_late_fine_type, 'FLAT'), COALESCE(p_is_mandatory, true),
            COALESCE(p_is_refundable, false), p_description, COALESCE(p_academic_year, '2026 - 2027')
        ) RETURNING id INTO v_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Fee structure saved successfully',
        'structure_id', v_id
    );
END;
$$;


-- 4. 1-Click Cohort Fee Structure Cloning Engine
CREATE OR REPLACE FUNCTION public.fn_clone_fee_structure_to_cohort(
    p_school_id UUID,
    p_source_class TEXT,
    p_source_section TEXT DEFAULT 'All Sections',
    p_target_class TEXT DEFAULT NULL,
    p_target_section TEXT DEFAULT 'All Sections',
    p_markup_percent NUMERIC DEFAULT 0.0,
    p_user_id UUID DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Finance Administrator'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    rec RECORD;
    v_cloned_count INT := 0;
    v_clean_target_class TEXT := COALESCE(NULLIF(p_target_class, ''), p_source_class);
    v_clean_target_section TEXT := COALESCE(NULLIF(p_target_section, ''), 'All Sections');
    v_new_amount NUMERIC(12,2);
BEGIN
    IF p_source_class IS NULL OR p_source_class = '' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Source class is required for cloning');
    END IF;

    IF v_clean_target_class = p_source_class AND v_clean_target_section = p_source_section THEN
        RETURN jsonb_build_object('success', false, 'message', 'Target class and section cannot be identical to source');
    END IF;

    FOR rec IN 
        SELECT *
        FROM public.student_fee_structures
        WHERE school_id = p_school_id
          AND status = 'ACTIVE'
          AND class_grade = p_source_class
          AND (p_source_section = 'All Sections' OR section_name = p_source_section OR section_name = 'All Sections')
    LOOP
        v_new_amount := ROUND(rec.amount * (1.0 + (COALESCE(p_markup_percent, 0.0) / 100.0)), 2);

        INSERT INTO public.student_fee_structures (
            school_id, fee_name, fee_type, class_grade, section_name,
            billing_cycle, frequency_type, amount, due_day_of_cycle,
            grace_period_days, late_fine_amount, late_fine_type,
            is_mandatory, is_refundable, description, academic_year
        ) VALUES (
            p_school_id,
            rec.fee_name,
            rec.fee_type,
            v_clean_target_class,
            v_clean_target_section,
            rec.billing_cycle,
            rec.frequency_type,
            v_new_amount,
            rec.due_day_of_cycle,
            rec.grace_period_days,
            rec.late_fine_amount,
            rec.late_fine_type,
            rec.is_mandatory,
            rec.is_refundable,
            COALESCE(rec.description, '') || ' (Cloned from ' || p_source_class || ' ' || p_source_section || ')',
            rec.academic_year
        );

        v_cloned_count := v_cloned_count + 1;
    END LOOP;

    -- Audit log
    INSERT INTO public.student_fee_audit_logs (
        school_id, student_id, action, entity_type,
        performed_by_id, performed_by_name, description
    ) VALUES (
        p_school_id, NULL, 'FEE_STRUCTURE_CLONED', 'FEE_STRUCTURE',
        p_user_id, p_user_name,
        'Cloned ' || v_cloned_count || ' fee heads from ' || p_source_class || ' (' || p_source_section || ') to ' || v_clean_target_class || ' (' || v_clean_target_section || ') with ' || COALESCE(p_markup_percent, 0.0) || '% adjustment'
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Successfully cloned ' || v_cloned_count || ' fee heads to ' || v_clean_target_class || ' (' || v_clean_target_section || ')',
        'cloned_count', v_cloned_count,
        'target_class', v_clean_target_class,
        'target_section', v_clean_target_section
    );
END;
$$;


-- 5. Student-Applicable Fee Structure Resolution Engine
-- Used by Invoicing dialog, Bulk Invoice generator, and Payment collection
CREATE OR REPLACE FUNCTION public.fn_get_student_applicable_fee_structure(
    p_school_id UUID,
    p_student_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student RECORD;
    v_class TEXT := '';
    v_section TEXT := '';
    v_advance_credit NUMERIC(14,2) := 0.0;
    v_fee_heads JSONB := '[]'::jsonb;
    v_total_annual NUMERIC(14,2) := 0.0;
    v_monthly_rate NUMERIC(14,2) := 0.0;
    v_quarterly_rate NUMERIC(14,2) := 0.0;
    v_one_time_total NUMERIC(14,2) := 0.0;
BEGIN
    -- 1. Identify student profile
    SELECT p.id, p.full_name, p.email, p.roll_number, p.admission_number, p.class, p.avatar_url
    INTO v_student
    FROM public.profiles p
    WHERE p.id = p_student_id AND p.school_id = p_school_id;

    IF v_student.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Student record not found');
    END IF;

    -- 2. Resolve Class and Section from student_class_assignments or profile
    SELECT 
        COALESCE(ac.name, v_student.class, 'All Classes'),
        COALESCE(asec.name, '')
    INTO v_class, v_section
    FROM public.student_class_assignments sca
    LEFT JOIN public.academic_classes ac ON ac.id = sca.class_id
    LEFT JOIN public.academic_sections asec ON asec.id = sca.section_id
    WHERE sca.student_id = p_student_id AND sca.school_id = p_school_id AND sca.status = 'ACTIVE'
    LIMIT 1;

    IF v_class IS NULL OR v_class = '' THEN
        v_class := COALESCE(v_student.class, 'Class 10');
    END IF;

    -- Extract section from class string if necessary (e.g. "10A" or "Class 10-A")
    IF (v_section IS NULL OR v_section = '') AND v_class ~* '[0-9]+[ -]*[A-D]' THEN
        v_section := SUBSTRING(v_class FROM '[A-D]$');
    END IF;
    IF v_section IS NULL OR v_section = '' THEN
        v_section := 'All Sections';
    END IF;

    -- 3. Get Student Advance Credit Wallet Balance
    SELECT COALESCE(GREATEST(0.0, (
        COALESCE((SELECT SUM(amount_paid) FROM public.student_fee_payments WHERE student_id = p_student_id AND school_id = p_school_id AND status = 'COMPLETED'), 0.0)
        -
        COALESCE((SELECT SUM(total_billed) FROM public.student_fee_invoices WHERE student_id = p_student_id AND school_id = p_school_id AND status != 'CANCELLED'), 0.0)
    )), 0.0) INTO v_advance_credit;

    -- 4. Match all applicable fee structures for this student's class and section
    WITH matched_heads AS (
        SELECT 
            s.id,
            s.fee_name,
            s.fee_type,
            s.class_grade,
            s.section_name,
            s.billing_cycle,
            s.frequency_type,
            s.amount,
            CASE s.frequency_type
                WHEN 'One-Time' THEN s.amount * 1.0
                WHEN 'Monthly' THEN s.amount * 12.0
                WHEN 'Quarterly' THEN s.amount * 4.0
                WHEN 'Half-Yearly' THEN s.amount * 2.0
                WHEN 'Annual' THEN s.amount * 1.0
                ELSE s.amount * 1.0
            END AS annual_liability,
            s.due_day_of_cycle,
            s.grace_period_days,
            s.late_fine_amount,
            s.late_fine_type,
            s.is_mandatory,
            s.is_refundable,
            s.description
        FROM public.student_fee_structures s
        WHERE s.school_id = p_school_id
          AND s.status = 'ACTIVE'
          AND (
              s.class_grade = 'All Classes' OR 
              s.class_grade = v_class OR 
              v_class ILIKE s.class_grade || '%' OR
              s.class_grade ILIKE v_class || '%'
          )
          AND (
              s.section_name = 'All Sections' OR 
              s.section_name = v_section OR
              v_section = 'All Sections' OR
              s.section_name IS NULL
          )
        ORDER BY 
            CASE s.frequency_type
                WHEN 'One-Time' THEN 1
                WHEN 'Annual' THEN 2
                WHEN 'Half-Yearly' THEN 3
                WHEN 'Quarterly' THEN 4
                WHEN 'Monthly' THEN 5
                ELSE 6
            END,
            s.fee_name ASC
    )
    SELECT 
        COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', m.id,
                'fee_name', m.fee_name,
                'fee_type', m.fee_type,
                'class_grade', m.class_grade,
                'section_name', m.section_name,
                'billing_cycle', m.billing_cycle,
                'frequency_type', m.frequency_type,
                'amount', m.amount,
                'annual_liability', m.annual_liability,
                'due_day_of_cycle', m.due_day_of_cycle,
                'grace_period_days', m.grace_period_days,
                'late_fine_amount', m.late_fine_amount,
                'late_fine_type', m.late_fine_type,
                'is_mandatory', m.is_mandatory,
                'is_refundable', m.is_refundable,
                'description', m.description
            )
        ), '[]'::jsonb),
        COALESCE(SUM(m.annual_liability), 0.0),
        COALESCE(SUM(CASE WHEN m.frequency_type = 'Monthly' THEN m.amount ELSE 0 END), 0.0),
        COALESCE(SUM(CASE WHEN m.frequency_type = 'Quarterly' THEN m.amount ELSE 0 END), 0.0),
        COALESCE(SUM(CASE WHEN m.frequency_type = 'One-Time' THEN m.amount ELSE 0 END), 0.0)
    INTO 
        v_fee_heads,
        v_total_annual,
        v_monthly_rate,
        v_quarterly_rate,
        v_one_time_total
    FROM matched_heads m;

    RETURN jsonb_build_object(
        'success', true,
        'student', jsonb_build_object(
            'id', v_student.id,
            'name', v_student.full_name,
            'email', v_student.email,
            'roll_number', v_student.roll_number,
            'admission_number', v_student.admission_number,
            'class', v_class,
            'section', v_section,
            'avatar_url', v_student.avatar_url,
            'advance_credit_wallet', v_advance_credit
        ),
        'applicable_heads', v_fee_heads,
        'totals', jsonb_build_object(
            'total_annual_commitment', v_total_annual,
            'monthly_recurring_tuition', v_monthly_rate,
            'quarterly_composite_rate', v_quarterly_rate,
            'one_time_admission_charges', v_one_time_total,
            'advance_credit_available', v_advance_credit
        )
    );
END;
$$;
