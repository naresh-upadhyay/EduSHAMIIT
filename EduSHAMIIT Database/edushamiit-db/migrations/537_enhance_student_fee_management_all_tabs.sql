-- Migration 537: Complete Enhancement for Student Fee Management All-Tabs & Financial Engine
-- Solves duplicate student displays, handles Overpaid/Advance credits, separates Partial & Pending,
-- accurately tracks dues vs overdue, and adds admission number sorting and display.

-- ============================================================================
-- 1. FUNCTION: fn_student_fee_dashboard_kpis
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_student_fee_dashboard_kpis(
    p_school_id UUID,
    p_academic_year TEXT DEFAULT '2026 - 2027'
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
    v_coll_rate NUMERIC(5,1) := 0.0;
BEGIN
    SELECT COUNT(*) INTO v_total_students
    FROM public.profiles
    WHERE school_id = p_school_id AND role = 'student';

    WITH student_finances AS (
        SELECT 
            p.id AS student_id,
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
        WHERE p.school_id = p_school_id AND p.role = 'student'
        GROUP BY p.id, p.school_id
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
            'unbilled_students_count', v_unbilled_count
        )
    );
END;
$$;


-- ============================================================================
-- 2. FUNCTION: fn_student_fee_roster
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_student_fee_roster(
    p_school_id UUID,
    p_academic_year TEXT DEFAULT '2026 - 2027',
    p_search TEXT DEFAULT NULL,
    p_class_name TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'name',
    p_sort_order TEXT DEFAULT 'ASC',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_items INT := 0;
    v_total_pages INT := 1;
    v_offset INT := 0;
    v_students JSONB := '[]'::jsonb;
    v_clean_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_clean_size INT := GREATEST(1, LEAST(100, COALESCE(p_page_size, 10)));
BEGIN
    v_offset := (v_clean_page - 1) * v_clean_size;

    WITH student_calc AS (
        SELECT 
            p.id AS student_id,
            p.full_name AS student_name,
            COALESCE(p.email, '') AS student_email,
            COALESCE(p.phone, '') AS student_phone,
            COALESCE(NULLIF(p.class, ''), '10A') AS class_name,
            COALESCE(NULLIF(p.roll_number::text, ''), '-') AS roll_number,
            COALESCE(p.admission_number, 'ADM-' || UPPER(SUBSTRING(p.id::text, 1, 6))) AS admission_number,
            p.avatar_url,
            COALESCE(MAX(i.fee_plan), 'Monthly') AS fee_plan,
            COALESCE(SUM(i.total_billed), 0.0) AS total_billed,
            COALESCE(SUM(i.paid_amount), 0.0) + COALESCE((
                SELECT SUM(pay.amount_paid) 
                FROM public.student_fee_payments pay 
                WHERE pay.student_id = p.id AND pay.school_id = p.school_id 
                  AND pay.invoice_id IS NULL
                  AND (pay.status IS NULL OR pay.status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS'))
            ), 0.0) AS paid_amount,
            MAX(i.due_date) AS max_due_date,
            MAX(i.id::text) AS latest_invoice_id,
            MAX(i.invoice_number) AS latest_invoice_number,
            COUNT(i.id) AS invoices_count
        FROM public.profiles p
        LEFT JOIN public.student_fee_invoices i 
            ON p.id = i.student_id 
           AND i.school_id = p.school_id 
           AND (p_academic_year IS NULL OR p_academic_year = '' OR REPLACE(i.academic_year, ' ', '') = REPLACE(p_academic_year, ' ', ''))
        WHERE p.school_id = p_school_id 
          AND p.role = 'student'
          AND (p_search IS NULL OR p_search = '' OR (
              p.full_name ILIKE '%' || p_search || '%' OR
              p.email ILIKE '%' || p_search || '%' OR
              p.roll_number::text ILIKE '%' || p_search || '%' OR
              p.admission_number ILIKE '%' || p_search || '%'
          ))
          AND (p_class_name IS NULL OR p_class_name IN ('All Classes', 'All', '') OR p.class = p_class_name)
        GROUP BY p.id, p.full_name, p.email, p.phone, p.class, p.roll_number, p.admission_number, p.avatar_url
    ),
    student_classified AS (
        SELECT 
            sc.*,
            GREATEST(0.0, sc.total_billed - sc.paid_amount) AS balance_amount,
            GREATEST(0.0, sc.paid_amount - sc.total_billed) AS advance_amount,
            CASE 
                WHEN sc.total_billed = 0.0 AND sc.paid_amount = 0.0 THEN 'Unbilled'
                WHEN sc.paid_amount > sc.total_billed THEN 'Overpaid'
                WHEN (sc.total_billed - sc.paid_amount) <= 0.0 AND sc.total_billed > 0.0 THEN 'Paid'
                WHEN sc.paid_amount > 0.0 AND (sc.total_billed - sc.paid_amount) > 0.0 AND (sc.max_due_date IS NULL OR sc.max_due_date >= CURRENT_DATE) THEN 'Partial'
                WHEN sc.max_due_date < CURRENT_DATE AND (sc.total_billed - sc.paid_amount) > 0.0 THEN 'Overdue'
                WHEN sc.paid_amount = 0.0 AND (sc.total_billed - sc.paid_amount) > 0.0 AND (sc.max_due_date IS NULL OR sc.max_due_date >= CURRENT_DATE) THEN 'Pending'
                ELSE 'Pending'
            END AS computed_status
        FROM student_calc sc
    ),
    filtered AS (
        SELECT * FROM student_classified
        WHERE (
            p_status IS NULL OR p_status IN ('All Status', 'All Fees', 'All', '') 
            OR (LOWER(p_status) IN ('overpaid', 'over paid', 'advance', 'credit') AND computed_status = 'Overpaid')
            OR (LOWER(p_status) = 'paid' AND computed_status = 'Paid')
            OR (LOWER(p_status) = 'partial' AND computed_status = 'Partial')
            OR (LOWER(p_status) = 'pending' AND computed_status = 'Pending')
            OR (LOWER(p_status) = 'overdue' AND computed_status = 'Overdue')
            OR (LOWER(p_status) = 'unbilled' AND computed_status = 'Unbilled')
            OR (computed_status ILIKE p_status)
        )
    ),
    counted AS (
        SELECT COUNT(*) AS total_items FROM filtered
    ),
    sorted_page AS (
        SELECT *
        FROM filtered f
        ORDER BY
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'name' THEN f.student_name END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'name' THEN f.student_name END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'billed' THEN f.total_billed END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'billed' THEN f.total_billed END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'paid' THEN f.paid_amount END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'paid' THEN f.paid_amount END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'balance' THEN f.balance_amount END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'balance' THEN f.balance_amount END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'advance' THEN f.advance_amount END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'advance' THEN f.advance_amount END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'status' THEN f.computed_status END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'status' THEN f.computed_status END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'class' THEN f.class_name END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'class' THEN f.class_name END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'admission_number' THEN f.admission_number END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'admission_number' THEN f.admission_number END DESC NULLS LAST,
            f.student_name ASC
        LIMIT v_clean_size OFFSET v_offset
    )
    SELECT 
        (SELECT total_items FROM counted),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'student_id', sp.student_id,
                    'student_name', sp.student_name,
                    'student_email', sp.student_email,
                    'student_phone', sp.student_phone,
                    'class_name', sp.class_name,
                    'roll_number', sp.roll_number,
                    'admission_number', sp.admission_number,
                    'avatar_url', sp.avatar_url,
                    'fee_plan', sp.fee_plan,
                    'total_billed', sp.total_billed,
                    'total_billed_formatted', '₹ ' || TO_CHAR(sp.total_billed, 'FM99,99,990.00'),
                    'paid_amount', sp.paid_amount,
                    'paid_amount_formatted', '₹ ' || TO_CHAR(sp.paid_amount, 'FM99,99,990.00'),
                    'balance_amount', sp.balance_amount,
                    'balance_amount_formatted', CASE WHEN sp.balance_amount = 0 THEN '₹ 0.00' ELSE '₹ ' || TO_CHAR(sp.balance_amount, 'FM99,99,990.00') END,
                    'advance_amount', sp.advance_amount,
                    'advance_amount_formatted', CASE WHEN sp.advance_amount = 0 THEN '₹ 0.00' ELSE '+₹ ' || TO_CHAR(sp.advance_amount, 'FM99,99,990.00') END,
                    'status', sp.computed_status,
                    'latest_invoice_id', sp.latest_invoice_id,
                    'latest_invoice_number', sp.latest_invoice_number,
                    'due_date', sp.max_due_date,
                    'invoices_count', sp.invoices_count
                )
            ), '[]'::jsonb
        )
    INTO v_total_items, v_students
    FROM sorted_page sp;

    v_total_items := COALESCE(v_total_items, 0);
    IF v_total_items > 0 THEN
        v_total_pages := CEIL(v_total_items::numeric / v_clean_size);
    ELSE
        v_total_pages := 1;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'students', v_students,
        'pagination', jsonb_build_object(
            'page', v_clean_page,
            'page_size', v_clean_size,
            'total_items', v_total_items,
            'total_pages', v_total_pages,
            'sort_by', p_sort_by,
            'sort_order', p_sort_order
        )
    );
END;
$$;


-- ============================================================================
-- 3. FUNCTION: fn_student_fee_account_details
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_student_fee_account_details(
    p_school_id UUID,
    p_student_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile RECORD;
    v_invoices JSONB;
    v_payments JSONB;
    v_concessions JSONB;
    v_penalties JSONB;
    v_audit_logs JSONB;
    v_total_billed NUMERIC(12,2) := 0.0;
    v_total_paid NUMERIC(12,2) := 0.0;
    v_balance NUMERIC(12,2) := 0.0;
    v_advance NUMERIC(12,2) := 0.0;
    v_status TEXT := 'Pending';
BEGIN
    SELECT id, full_name, email, phone, class, roll_number, admission_number, avatar_url
    INTO v_profile
    FROM public.profiles
    WHERE id = p_student_id AND school_id = p_school_id;

    IF v_profile.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Student not found');
    END IF;

    -- Invoices
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', i.id,
                'invoice_number', i.invoice_number,
                'title', i.title,
                'fee_type', i.fee_type,
                'fee_plan', i.fee_plan,
                'academic_year', i.academic_year,
                'billing_date', i.billing_date,
                'due_date', i.due_date,
                'subtotal', i.subtotal,
                'concession_amount', i.concession_amount,
                'penalty_amount', i.penalty_amount,
                'total_billed', i.total_billed,
                'paid_amount', i.paid_amount,
                'balance_amount', i.balance_amount,
                'status', i.status,
                'created_at', i.created_at
            ) ORDER BY i.created_at DESC
        ), '[]'::jsonb
    ) INTO v_invoices
    FROM public.student_fee_invoices i
    WHERE i.student_id = p_student_id AND i.school_id = p_school_id;

    -- Payments
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', pay.id,
                'receipt_number', pay.receipt_number,
                'amount_paid', pay.amount_paid,
                'payment_method', pay.payment_method,
                'transaction_reference', pay.transaction_reference,
                'status', pay.status,
                'created_at', pay.created_at,
                'remarks', pay.remarks
            ) ORDER BY pay.created_at DESC
        ), '[]'::jsonb
    ) INTO v_payments
    FROM public.student_fee_payments pay
    WHERE pay.student_id = p_student_id AND pay.school_id = p_school_id;

    -- Concessions
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', c.id,
                'concession_type', c.concession_type,
                'amount', c.amount,
                'reason', c.reason,
                'created_at', c.created_at
            ) ORDER BY c.created_at DESC
        ), '[]'::jsonb
    ) INTO v_concessions
    FROM public.student_fee_concessions c
    WHERE c.student_id = p_student_id AND c.school_id = p_school_id;

    -- Penalties
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', pen.id,
                'penalty_type', pen.penalty_type,
                'amount', pen.amount,
                'reason', pen.reason,
                'created_at', pen.created_at
            ) ORDER BY pen.created_at DESC
        ), '[]'::jsonb
    ) INTO v_penalties
    FROM public.student_fee_penalties pen
    WHERE pen.student_id = p_student_id AND pen.school_id = p_school_id;

    -- Audit Logs
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', a.id,
                'action', a.action,
                'description', a.description,
                'amount', a.amount,
                'performed_by_name', a.performed_by_name,
                'created_at', a.created_at
            ) ORDER BY a.created_at DESC
        ), '[]'::jsonb
    ) INTO v_audit_logs
    FROM public.student_fee_audit_logs a
    WHERE a.student_id = p_student_id AND a.school_id = p_school_id
    LIMIT 25;

    -- Compute overall student finance
    SELECT 
        COALESCE(SUM(i.total_billed), 0.0),
        COALESCE(SUM(i.paid_amount), 0.0) + COALESCE((
            SELECT SUM(pay.amount_paid) 
            FROM public.student_fee_payments pay 
            WHERE pay.student_id = p_student_id AND pay.school_id = p_school_id 
              AND pay.invoice_id IS NULL
              AND (pay.status IS NULL OR pay.status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS'))
        ), 0.0)
    INTO v_total_billed, v_total_paid
    FROM public.student_fee_invoices i
    WHERE i.student_id = p_student_id AND i.school_id = p_school_id;

    v_balance := GREATEST(0.0, v_total_billed - v_total_paid);
    v_advance := GREATEST(0.0, v_total_paid - v_total_billed);

    IF v_total_billed = 0.0 AND v_total_paid = 0.0 THEN
        v_status := 'Unbilled';
    ELSIF v_total_paid > v_total_billed THEN
        v_status := 'Overpaid';
    ELSIF v_balance <= 0.0 AND v_total_billed > 0 THEN
        v_status := 'Paid';
    ELSIF v_total_paid > 0 THEN
        v_status := 'Partial';
    ELSE
        v_status := 'Pending';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'student', jsonb_build_object(
            'id', v_profile.id,
            'name', v_profile.full_name,
            'email', v_profile.email,
            'phone', v_profile.phone,
            'class_name', COALESCE(v_profile.class, '10A'),
            'roll_number', COALESCE(v_profile.roll_number::text, '-'),
            'admission_number', COALESCE(v_profile.admission_number, 'ADM-' || UPPER(SUBSTRING(v_profile.id::text, 1, 6))),
            'avatar_url', v_profile.avatar_url,
            'total_billed', v_total_billed,
            'paid_amount', v_total_paid,
            'balance_amount', v_balance,
            'advance_amount', v_advance,
            'status', v_status
        ),
        'invoices', v_invoices,
        'payments', v_payments,
        'concessions', v_concessions,
        'penalties', v_penalties,
        'audit_logs', v_audit_logs
    );
END;
$$;
