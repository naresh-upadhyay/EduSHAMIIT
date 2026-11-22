-- ============================================================================
-- Migration: 541_sync_student_fee_kpis_and_class_filtering.sql
-- Description:
--   1. Enhances public.fn_student_fee_dashboard_kpis to accept optional
--      p_class_name parameter so that when a specific class is selected,
--      all KPI cards (Billed, Collected, Dues, Overdue) and status badges
--      filter accurately to that specific class.
--   2. Dynamically includes fee_structures_count, invoices_count, and
--      payments_count from DB into the KPIs payload so zero numbers are
--      hardcoded in any UI sub-tab.
--   3. Synchronizes status classification between fn_student_fee_dashboard_kpis
--      and fn_student_fee_roster with 100% mathematical precision.
-- ============================================================================

DROP FUNCTION IF EXISTS public.fn_student_fee_dashboard_kpis(UUID, TEXT);

CREATE OR REPLACE FUNCTION public.fn_student_fee_dashboard_kpis(
    p_school_id UUID,
    p_academic_year TEXT DEFAULT '2026 - 2027',
    p_class_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_students INT := 0;
    v_total_billed NUMERIC(14,2) := 0.0;
    v_total_collected NUMERIC(14,2) := 0.0;
    v_pending_dues NUMERIC(14,2) := 0.0;
    v_overdue_amount NUMERIC(14,2) := 0.0;
    v_advance_amount NUMERIC(14,2) := 0.0;
    v_paid_count INT := 0;
    v_partial_count INT := 0;
    v_pending_count INT := 0;
    v_overdue_count INT := 0;
    v_overpaid_count INT := 0;
    v_unbilled_count INT := 0;
    v_structures_count INT := 0;
    v_invoices_count INT := 0;
    v_payments_count INT := 0;
    v_coll_rate NUMERIC(5,1) := 0.0;
BEGIN
    -- 1. Total Student Headcount matching class filter
    SELECT COUNT(*) INTO v_total_students
    FROM public.profiles
    WHERE school_id = p_school_id 
      AND role = 'student'
      AND (p_class_name IS NULL OR p_class_name IN ('All Classes', 'All', '') OR class = p_class_name);

    -- 2. Aggregate Invoices and Payments per student
    WITH student_finances AS (
        SELECT 
            p.id AS student_id,
            COALESCE(NULLIF(p.class, ''), '10A') AS class_name,
            COALESCE(SUM(i.total_billed), 0.0) AS billed,
            COALESCE(SUM(i.paid_amount), 0.0) + COALESCE((
                SELECT SUM(pay.amount_paid) 
                FROM public.student_fee_payments pay 
                WHERE pay.student_id = p.id AND pay.school_id = p.school_id 
                  AND pay.invoice_id IS NULL
                  AND (pay.status IS NULL OR pay.status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS'))
            ), 0.0) AS paid,
            MAX(i.due_date) AS max_due_date,
            COUNT(i.id) AS invoices_count
        FROM public.profiles p
        LEFT JOIN public.student_fee_invoices i 
            ON p.id = i.student_id 
           AND i.school_id = p.school_id 
           AND (p_academic_year IS NULL OR p_academic_year = '' OR REPLACE(i.academic_year, ' ', '') = REPLACE(p_academic_year, ' ', ''))
        WHERE p.school_id = p_school_id 
          AND p.role = 'student'
          AND (p_class_name IS NULL OR p_class_name IN ('All Classes', 'All', '') OR p.class = p_class_name)
        GROUP BY p.id, p.school_id, p.class
    ),
    classified AS (
        SELECT 
            student_id,
            billed,
            paid,
            GREATEST(0.0, billed - paid) AS balance,
            GREATEST(0.0, paid - billed) AS advance,
            CASE 
                WHEN billed = 0.0 AND paid = 0.0 THEN 'Unbilled'
                WHEN paid > billed THEN 'Overpaid'
                WHEN (billed - paid) <= 0.0 AND billed > 0.0 THEN 'Paid'
                WHEN paid > 0.0 AND (billed - paid) > 0.0 AND (max_due_date IS NULL OR max_due_date >= CURRENT_DATE) THEN 'Partial'
                WHEN max_due_date < CURRENT_DATE AND (billed - paid) > 0.0 THEN 'Overdue'
                WHEN paid = 0.0 AND (billed - paid) > 0.0 AND (max_due_date IS NULL OR max_due_date >= CURRENT_DATE) THEN 'Pending'
                ELSE 'Pending'
            END AS computed_status
        FROM student_finances
    )
    SELECT 
        COALESCE(SUM(billed), 0.0),
        COALESCE(SUM(paid), 0.0),
        COALESCE(SUM(CASE WHEN computed_status IN ('Partial', 'Pending') THEN balance ELSE 0.0 END), 0.0),
        COALESCE(SUM(CASE WHEN computed_status = 'Overdue' THEN balance ELSE 0.0 END), 0.0),
        COALESCE(SUM(advance), 0.0),
        COUNT(CASE WHEN computed_status = 'Paid' THEN 1 END),
        COUNT(CASE WHEN computed_status = 'Partial' THEN 1 END),
        COUNT(CASE WHEN computed_status = 'Pending' THEN 1 END),
        COUNT(CASE WHEN computed_status = 'Overdue' THEN 1 END),
        COUNT(CASE WHEN computed_status = 'Overpaid' THEN 1 END),
        COUNT(CASE WHEN computed_status = 'Unbilled' THEN 1 END)
    INTO 
        v_total_billed,
        v_total_collected,
        v_pending_dues,
        v_overdue_amount,
        v_advance_amount,
        v_paid_count,
        v_partial_count,
        v_pending_count,
        v_overdue_count,
        v_overpaid_count,
        v_unbilled_count
    FROM classified;

    -- 3. Dynamic counts for other sub-tabs from DB
    SELECT COUNT(*) INTO v_structures_count
    FROM public.student_fee_structures
    WHERE school_id = p_school_id;

    SELECT COUNT(*) INTO v_invoices_count
    FROM public.student_fee_invoices inv
    JOIN public.profiles pr ON pr.id = inv.student_id AND pr.school_id = inv.school_id
    WHERE inv.school_id = p_school_id
      AND (p_academic_year IS NULL OR p_academic_year = '' OR REPLACE(inv.academic_year, ' ', '') = REPLACE(p_academic_year, ' ', ''))
      AND (p_class_name IS NULL OR p_class_name IN ('All Classes', 'All', '') OR pr.class = p_class_name);

    SELECT COUNT(*) INTO v_payments_count
    FROM public.student_fee_payments pay
    JOIN public.profiles pr ON pr.id = pay.student_id AND pr.school_id = pay.school_id
    WHERE pay.school_id = p_school_id
      AND (p_class_name IS NULL OR p_class_name IN ('All Classes', 'All', '') OR pr.class = p_class_name);

    -- 4. Collection Rate
    IF v_total_billed > 0 THEN
        v_coll_rate := ROUND((LEAST(v_total_collected, v_total_billed) / v_total_billed * 100)::numeric, 1);
    ELSE
        v_coll_rate := 0.0;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'kpis', jsonb_build_object(
            'total_billed', v_total_billed,
            'total_collected', v_total_collected,
            'pending_dues', v_pending_dues,
            'overdue_amount', v_overdue_amount,
            'advance_amount', v_advance_amount,
            'collection_rate', v_coll_rate,
            'collection_rate_formatted', v_coll_rate::text || '% Collection',
            'total_students', v_total_students,
            'paid_students_count', v_paid_count,
            'partial_students_count', v_partial_count,
            'pending_students_count', v_pending_count,
            'overdue_students_count', v_overdue_count,
            'overpaid_students_count', v_overpaid_count,
            'unbilled_students_count', v_unbilled_count,
            'fee_structures_count', v_structures_count,
            'invoices_count', v_invoices_count,
            'payments_count', v_payments_count
        )
    );
END;
$$;
