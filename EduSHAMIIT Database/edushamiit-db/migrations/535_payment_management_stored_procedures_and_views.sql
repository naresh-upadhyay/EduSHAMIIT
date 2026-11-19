-- ============================================================================
-- Migration 535: Payment Management Stored Procedures, Functions & Financial Reconciliations
-- Authoritative Single Source of Truth for Student Fee & Staff Salary
-- Encapsulates all FastAPI direct queries into robust PostgreSQL Stored Procedures.
-- Fixes: Overdue vs Overpaid status isolation, Database Sorting & Pagination,
-- Complete CRUD operations with atomic transactions and audit trails.
-- ============================================================================

-- Step 1: Authoritative Reconciliation of Invoices with Verified Payments
DO $$
BEGIN
    -- Synchronize invoices where payments exist with invoice_id
    UPDATE public.student_fee_invoices i
    SET paid_amount = sub.total_paid,
        balance_amount = GREATEST(0.0, i.total_billed - sub.total_paid),
        status = CASE 
            WHEN sub.total_paid > i.total_billed THEN 'Overpaid'
            WHEN (i.total_billed - sub.total_paid) <= 0 AND i.total_billed > 0 THEN 'Paid'
            WHEN sub.total_paid > 0 THEN 'Partial'
            WHEN i.due_date < CURRENT_DATE AND (i.total_billed - sub.total_paid) > 0 THEN 'Overdue'
            ELSE 'Pending'
        END,
        updated_at = NOW()
    FROM (
        SELECT invoice_id, SUM(amount_paid) AS total_paid
        FROM public.student_fee_payments
        WHERE invoice_id IS NOT NULL 
          AND (status IS NULL OR status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS'))
        GROUP BY invoice_id
    ) sub
    WHERE i.id = sub.invoice_id;

    -- Synchronize unlinked payments to latest student invoice
    UPDATE public.student_fee_invoices i
    SET paid_amount = GREATEST(i.paid_amount, sub.total_paid),
        balance_amount = GREATEST(0.0, i.total_billed - GREATEST(i.paid_amount, sub.total_paid)),
        status = CASE 
            WHEN GREATEST(i.paid_amount, sub.total_paid) > i.total_billed THEN 'Overpaid'
            WHEN (i.total_billed - GREATEST(i.paid_amount, sub.total_paid)) <= 0 AND i.total_billed > 0 THEN 'Paid'
            WHEN GREATEST(i.paid_amount, sub.total_paid) > 0 THEN 'Partial'
            WHEN i.due_date < CURRENT_DATE AND (i.total_billed - GREATEST(i.paid_amount, sub.total_paid)) > 0 THEN 'Overdue'
            ELSE 'Pending'
        END,
        updated_at = NOW()
    FROM (
        SELECT student_id, SUM(amount_paid) AS total_paid
        FROM public.student_fee_payments
        WHERE (status IS NULL OR status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS'))
        GROUP BY student_id
    ) sub
    WHERE i.student_id = sub.student_id
      AND i.id = (
          SELECT id FROM public.student_fee_invoices 
          WHERE student_id = sub.student_id 
          ORDER BY created_at DESC LIMIT 1
      );

    -- Ensure any overpaid or zero balance invoices are never marked Overdue
    UPDATE public.student_fee_invoices
    SET status = 'Overpaid', balance_amount = 0.0, updated_at = NOW()
    WHERE paid_amount > total_billed AND status != 'Overpaid';

    UPDATE public.student_fee_invoices
    SET status = 'Paid', balance_amount = 0.0, updated_at = NOW()
    WHERE balance_amount <= 0.0 AND total_billed > 0 AND paid_amount <= total_billed AND status NOT IN ('Paid', 'Overpaid');
END $$;


-- ============================================================================
-- 1. FUNCTION: fn_student_fee_dashboard_kpis
-- Dynamically computes exact financial KPIs across all student accounts.
-- Overpaid students are strictly excluded from Overdue amounts & counts.
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
    v_paid_count INT := 0;
    v_pending_count INT := 0;
    v_overdue_count INT := 0;
    v_overpaid_count INT := 0;
    v_coll_rate NUMERIC(5,1) := 0.0;
BEGIN
    SELECT COUNT(*) INTO v_total_students
    FROM public.profiles
    WHERE school_id = p_school_id AND role = 'student';

    WITH student_finances AS (
        SELECT 
            p.id AS student_id,
            COALESCE(SUM(i.total_billed), 0.0) AS billed,
            GREATEST(
                COALESCE(SUM(i.paid_amount), 0.0),
                COALESCE((
                    SELECT SUM(pay.amount_paid) 
                    FROM public.student_fee_payments pay 
                    WHERE pay.student_id = p.id AND pay.school_id = p.school_id 
                      AND (pay.status IS NULL OR pay.status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS'))
                ), 0.0)
            ) AS paid,
            MAX(i.due_date) AS max_due_date
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
            CASE 
                WHEN paid > billed THEN 'Overpaid'
                WHEN (billed - paid) <= 0 AND billed > 0 THEN 'Paid'
                WHEN paid > 0 AND (billed - paid) > 0 AND (max_due_date IS NULL OR max_due_date >= CURRENT_DATE) THEN 'Partial'
                WHEN max_due_date < CURRENT_DATE AND (billed - paid) > 0 THEN 'Overdue'
                WHEN paid > 0 AND (billed - paid) > 0 THEN 'Partial'
                ELSE 'Pending'
            END AS computed_status
        FROM student_finances
    )
    SELECT 
        COALESCE(SUM(billed), 0.0),
        COALESCE(SUM(paid), 0.0),
        COALESCE(SUM(CASE WHEN computed_status IN ('Partial', 'Pending') THEN balance ELSE 0.0 END), 0.0),
        COALESCE(SUM(CASE WHEN computed_status = 'Overdue' THEN balance ELSE 0.0 END), 0.0),
        COUNT(CASE WHEN computed_status = 'Paid' THEN 1 END),
        COUNT(CASE WHEN computed_status IN ('Partial', 'Pending') THEN 1 END),
        COUNT(CASE WHEN computed_status = 'Overdue' THEN 1 END),
        COUNT(CASE WHEN computed_status = 'Overpaid' THEN 1 END)
    INTO 
        v_total_billed,
        v_total_collected,
        v_pending_dues,
        v_overdue_amount,
        v_paid_count,
        v_pending_count,
        v_overdue_count,
        v_overpaid_count
    FROM classified;

    IF v_total_billed > 0 THEN
        v_coll_rate := ROUND((v_total_collected / v_total_billed * 100)::numeric, 1);
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
            'collection_rate', v_coll_rate,
            'collection_rate_formatted', v_coll_rate::text || '% Collection',
            'total_students', v_total_students,
            'paid_students_count', v_paid_count,
            'pending_students_count', v_pending_count,
            'overdue_students_count', v_overdue_count,
            'overpaid_students_count', v_overpaid_count
        )
    );
END;
$$;


-- ============================================================================
-- 2. FUNCTION: fn_student_fee_roster
-- Full database-level filtering, sorting and pagination for Student Fee Grid.
-- Strictly isolates Overdue from Overpaid status.
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
            COALESCE(p.admission_number, 'ADM-' || SUBSTRING(p.id::text, 1, 6)) AS admission_number,
            p.avatar_url,
            COALESCE(MAX(i.fee_plan), 'Monthly') AS fee_plan,
            COALESCE(SUM(i.total_billed), 0.0) AS total_billed,
            GREATEST(
                COALESCE(SUM(i.paid_amount), 0.0),
                COALESCE((
                    SELECT SUM(pay.amount_paid) 
                    FROM public.student_fee_payments pay 
                    WHERE pay.student_id = p.id AND pay.school_id = p.school_id 
                      AND (pay.status IS NULL OR pay.status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS'))
                ), 0.0)
            ) AS paid_amount,
            MAX(i.due_date) AS max_due_date,
            MAX(i.id::text) AS latest_invoice_id,
            MAX(i.invoice_number) AS latest_invoice_number
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
            CASE 
                WHEN sc.paid_amount > sc.total_billed THEN 'Overpaid'
                WHEN (sc.total_billed - sc.paid_amount) <= 0 AND sc.total_billed > 0 THEN 'Paid'
                WHEN sc.paid_amount > 0 AND (sc.total_billed - sc.paid_amount) > 0 AND (sc.max_due_date IS NULL OR sc.max_due_date >= CURRENT_DATE) THEN 'Partial'
                WHEN sc.max_due_date < CURRENT_DATE AND (sc.total_billed - sc.paid_amount) > 0 THEN 'Overdue'
                WHEN sc.paid_amount > 0 AND (sc.total_billed - sc.paid_amount) > 0 THEN 'Partial'
                ELSE 'Pending'
            END AS computed_status
        FROM student_calc sc
    ),
    filtered AS (
        SELECT * FROM student_classified
        WHERE (
            p_status IS NULL OR p_status IN ('All Status', 'All Fees', 'All', '') 
            OR (LOWER(p_status) IN ('overpaid', 'over paid') AND computed_status = 'Overpaid')
            OR (LOWER(p_status) = 'paid' AND computed_status = 'Paid')
            OR (LOWER(p_status) = 'partial' AND computed_status = 'Partial')
            OR (LOWER(p_status) = 'overdue' AND computed_status = 'Overdue')
            OR (LOWER(p_status) = 'pending' AND computed_status = 'Pending')
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
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'status' THEN f.computed_status END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'status' THEN f.computed_status END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'class' THEN f.class_name END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'class' THEN f.class_name END DESC NULLS LAST,
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
                    'status', sp.computed_status,
                    'latest_invoice_id', sp.latest_invoice_id,
                    'latest_invoice_number', sp.latest_invoice_number,
                    'due_date', sp.max_due_date
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
-- 3. FUNCTION: fn_staff_salary_dashboard_kpis
-- Dynamically computes real-time Staff Salary & Payroll KPIs.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_staff_salary_dashboard_kpis(
    p_school_id UUID,
    p_month_str TEXT DEFAULT '2026-10'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_staff INT := 0;
    v_total_budget NUMERIC(14,2) := 0.0;
    v_total_disbursed NUMERIC(14,2) := 0.0;
    v_pending_disbursal NUMERIC(14,2) := 0.0;
    v_on_hold NUMERIC(14,2) := 0.0;
    v_disbursed_count INT := 0;
    v_pending_count INT := 0;
    v_on_hold_count INT := 0;
    v_disbursal_rate NUMERIC(5,1) := 0.0;
BEGIN
    SELECT COUNT(*) INTO v_total_staff
    FROM public.profiles
    WHERE school_id = p_school_id AND role != 'student';

    SELECT COALESCE(SUM(struct.gross_salary), 0.0) INTO v_total_budget
    FROM public.profiles p
    JOIN public.staff_salary_structures struct ON p.id = struct.staff_id AND p.school_id = struct.school_id
    WHERE p.school_id = p_school_id AND p.role != 'student';

    SELECT 
        COALESCE(SUM(CASE WHEN p.payment_status = 'Paid' THEN p.net_pay ELSE 0.0 END), 0.0),
        COALESCE(SUM(CASE WHEN p.payment_status IN ('Pending', 'Approved') THEN p.net_pay ELSE 0.0 END), 0.0),
        COALESCE(SUM(CASE WHEN p.payment_status IN ('On-Hold', 'On Hold', 'Review', 'Rejected') THEN p.net_pay ELSE 0.0 END), 0.0),
        COUNT(CASE WHEN p.payment_status = 'Paid' THEN 1 END),
        COUNT(CASE WHEN p.payment_status IN ('Pending', 'Approved') THEN 1 END),
        COUNT(CASE WHEN p.payment_status IN ('On-Hold', 'On Hold', 'Review', 'Rejected') THEN 1 END)
    INTO 
        v_total_disbursed,
        v_pending_disbursal,
        v_on_hold,
        v_disbursed_count,
        v_pending_count,
        v_on_hold_count
    FROM public.staff_salary_payouts p
    WHERE p.school_id = p_school_id AND p.month_str = p_month_str;

    IF v_pending_disbursal = 0.0 AND v_total_disbursed < v_total_budget THEN
        v_pending_disbursal := GREATEST(0.0, v_total_budget - v_total_disbursed);
        v_pending_count := GREATEST(0, v_total_staff - v_disbursed_count - v_on_hold_count);
    END IF;

    IF v_total_budget > 0 THEN
        v_disbursal_rate := ROUND((v_total_disbursed / v_total_budget * 100)::numeric, 1);
    ELSE
        v_disbursal_rate := 0.0;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'kpis', jsonb_build_object(
            'total_monthly_budget', v_total_budget,
            'total_disbursed', v_total_disbursed,
            'pending_disbursal', v_pending_disbursal,
            'on_hold_amount', v_on_hold,
            'disbursal_rate', v_disbursal_rate,
            'disbursal_rate_formatted', v_disbursal_rate::text || '% Disbursed',
            'total_staff', v_total_staff,
            'paid_staff_count', v_disbursed_count,
            'pending_staff_count', v_pending_count,
            'on_hold_staff_count', v_on_hold_count
        )
    );
END;
$$;


-- ============================================================================
-- 4. FUNCTION: fn_staff_salary_roster
-- Full database-level filtering, sorting and pagination for Staff Salary Grid.
-- Unified CTE ensures counting and sorted paging stay perfectly in scope.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_staff_salary_roster(
    p_school_id UUID,
    p_month_str TEXT DEFAULT '2026-10',
    p_department TEXT DEFAULT NULL,
    p_role TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
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
    v_staff JSONB := '[]'::jsonb;
    v_clean_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_clean_size INT := GREATEST(1, LEAST(100, COALESCE(p_page_size, 10)));
BEGIN
    v_offset := (v_clean_page - 1) * v_clean_size;

    WITH staff_raw AS (
        SELECT 
            p.id AS staff_id,
            p.full_name AS staff_name,
            COALESCE(p.email, '') AS staff_email,
            COALESCE(p.phone, '') AS staff_phone,
            COALESCE(NULLIF(p.department, ''), 'Academic & Teaching') AS department,
            COALESCE(NULLIF(p.role, ''), 'Teacher') AS role_title,
            COALESCE(p.employee_id, 'EMP-' || SUBSTRING(p.id::text, 1, 6)) AS employee_id,
            p.avatar_url,
            COALESCE(struct.basic_pay, 35000.0) AS basic_pay,
            COALESCE(struct.hra, 14000.0) AS hra,
            COALESCE(struct.da, 4500.0) AS da,
            COALESCE(struct.ta, 2500.0) AS ta,
            COALESCE(struct.special_allowance, 2000.0) AS special_allowance,
            COALESCE(struct.gross_salary, 63000.0) AS gross_salary,
            COALESCE(struct.pf_deduction, 1800.0) AS pf_deduction,
            COALESCE(struct.tds, 2500.0) AS tds,
            COALESCE(struct.professional_tax, 200.0) AS professional_tax,
            COALESCE(struct.insurance_deduction, 500.0) AS insurance_deduction,
            COALESCE(struct.total_deductions, 7900.0) AS total_deductions,
            COALESCE(struct.net_salary, 55100.0) AS net_salary,
            COALESCE(struct.bank_name, 'HDFC Bank') AS bank_name,
            COALESCE(struct.account_number, '501002340055') AS account_number,
            COALESCE(struct.ifsc_code, 'HDFC0001824') AS ifsc_code,
            COALESCE(struct.pan_number, 'PAN000055X') AS pan_number,
            COALESCE(struct.payment_mode, 'Direct Bank Transfer (NEFT/RTGS)') AS payment_mode,
            COALESCE(payout.payment_status, 'Pending') AS payout_status,
            payout.id AS payout_id,
            payout.payslip_number,
            payout.payment_date,
            payout.transaction_reference,
            COALESCE((
                SELECT SUM(adv.monthly_deduction)
                FROM public.staff_salary_advances adv
                WHERE adv.staff_id = p.id AND adv.school_id = p.school_id 
                  AND adv.status = 'Approved' AND adv.amount_repaid < adv.amount
            ), 0.0) AS active_advance_deduction
        FROM public.profiles p
        LEFT JOIN public.staff_salary_structures struct 
            ON p.id = struct.staff_id AND p.school_id = struct.school_id
        LEFT JOIN public.staff_salary_payouts payout 
            ON p.id = payout.staff_id AND p.school_id = payout.school_id AND payout.month_str = p_month_str
        WHERE p.school_id = p_school_id 
          AND p.role != 'student'
          AND (p_search IS NULL OR p_search = '' OR (
              p.full_name ILIKE '%' || p_search || '%' OR
              p.email ILIKE '%' || p_search || '%' OR
              p.employee_id ILIKE '%' || p_search || '%' OR
              p.role ILIKE '%' || p_search || '%'
          ))
          AND (p_department IS NULL OR p_department IN ('All Departments', 'All', '') OR p.department = p_department)
          AND (p_role IS NULL OR p_role IN ('All Roles', 'All', '') OR p.role = p_role)
    ),
    filtered AS (
        SELECT * FROM staff_raw
        WHERE (
            p_status IS NULL OR p_status IN ('All Status', 'All', 'All Staff', '')
            OR (LOWER(p_status) = 'paid' AND payout_status = 'Paid')
            OR (LOWER(p_status) = 'pending' AND payout_status IN ('Pending', 'Approved'))
            OR (LOWER(p_status) IN ('on-hold', 'on hold', 'review', 'on-hold / review') AND payout_status IN ('On-Hold', 'On Hold', 'Review', 'Rejected'))
            OR (payout_status ILIKE p_status)
        )
    ),
    counted AS (
        SELECT COUNT(*) AS total_items FROM filtered
    ),
    sorted_page AS (
        SELECT * FROM filtered
        ORDER BY
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'name' THEN staff_name END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'name' THEN staff_name END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'base_pay' THEN basic_pay END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'base_pay' THEN basic_pay END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'gross' THEN gross_salary END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'gross' THEN gross_salary END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'deductions' THEN total_deductions END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'deductions' THEN total_deductions END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'net_salary' THEN net_salary END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'net_salary' THEN net_salary END DESC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'ASC' AND LOWER(p_sort_by) = 'status' THEN payout_status END ASC NULLS LAST,
            CASE WHEN UPPER(p_sort_order) = 'DESC' AND LOWER(p_sort_by) = 'status' THEN payout_status END DESC NULLS LAST,
            staff_name ASC
        LIMIT v_clean_size OFFSET v_offset
    )
    SELECT 
        (SELECT total_items FROM counted),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'staff_id', sp.staff_id,
                    'staff_name', sp.staff_name,
                    'staff_email', sp.staff_email,
                    'staff_phone', sp.staff_phone,
                    'department', sp.department,
                    'role_title', sp.role_title,
                    'employee_id', sp.employee_id,
                    'avatar_url', sp.avatar_url,
                    'basic_pay', sp.basic_pay,
                    'hra', sp.hra,
                    'da', sp.da,
                    'ta', sp.ta,
                    'special_allowance', sp.special_allowance,
                    'gross_salary', sp.gross_salary,
                    'pf_deduction', sp.pf_deduction,
                    'tds', sp.tds,
                    'professional_tax', sp.professional_tax,
                    'insurance_deduction', sp.insurance_deduction,
                    'total_deductions', sp.total_deductions,
                    'net_salary', sp.net_salary,
                    'gross_salary_formatted', '₹ ' || TO_CHAR(sp.gross_salary, 'FM99,99,990.00'),
                    'total_deductions_formatted', '₹ ' || TO_CHAR(sp.total_deductions, 'FM99,99,990.00'),
                    'net_salary_formatted', '₹ ' || TO_CHAR(sp.net_salary, 'FM99,99,990.00'),
                    'bank_name', sp.bank_name,
                    'account_number', sp.account_number,
                    'ifsc_code', sp.ifsc_code,
                    'pan_number', sp.pan_number,
                    'payment_mode', sp.payment_mode,
                    'status', sp.payout_status,
                    'payout_id', sp.payout_id,
                    'payslip_number', sp.payslip_number,
                    'payment_date', sp.payment_date,
                    'transaction_reference', sp.transaction_reference,
                    'active_advance_deduction', sp.active_advance_deduction
                )
            ), '[]'::jsonb
        ) INTO v_total_items, v_staff
    FROM sorted_page sp;

    v_total_items := COALESCE(v_total_items, 0);
    IF v_total_items > 0 THEN
        v_total_pages := CEIL(v_total_items::numeric / v_clean_size);
    ELSE
        v_total_pages := 1;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'staff', v_staff,
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
-- 5. FUNCTION: fn_student_fee_metadata
-- Dynamic metadata for class dropdown, fee types, payment modes from lookups.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_student_fee_metadata(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_classes JSONB;
    v_years JSONB;
    v_fee_types JSONB;
    v_payment_modes JSONB;
    v_concession_types JSONB;
    v_penalty_types JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(DISTINCT c), '["Class 9", "Class 10", "Class 11", "Class 12"]'::jsonb)
    INTO v_classes
    FROM (
        SELECT class AS c FROM public.profiles 
        WHERE school_id = p_school_id AND role = 'student' AND class IS NOT NULL AND class != ''
        UNION
        SELECT name AS c FROM public.classes
        WHERE school_id = p_school_id AND (is_active IS NULL OR is_active = true)
        ORDER BY c ASC
    ) cls;

    SELECT COALESCE(jsonb_agg(v.value_name ORDER BY v.sort_order), '["2026 - 2027", "2025 - 2026"]'::jsonb)
    INTO v_years
    FROM public.lookup_values v
    JOIN public.lookup_keys k ON v.lookup_key_id = k.id
    WHERE k.key_code = 'ACADEMIC_YEAR' AND v.school_id = p_school_id AND v.status = 'ACTIVE';

    SELECT COALESCE(jsonb_agg(DISTINCT ft), '["Tuition Fee", "Exam Fee", "Hostel Fee", "Transport Fee", "Library Fee", "Laboratory Fee"]'::jsonb)
    INTO v_fee_types
    FROM (
        SELECT v.value_name AS ft
        FROM public.lookup_values v
        JOIN public.lookup_keys k ON v.lookup_key_id = k.id
        WHERE k.key_code = 'STUDENT_FEE_TYPE' AND v.school_id = p_school_id AND v.status = 'ACTIVE'
        UNION
        SELECT fee_type AS ft FROM public.student_fee_invoices WHERE school_id = p_school_id
    ) t;

    SELECT COALESCE(jsonb_agg(v.value_name ORDER BY v.sort_order), '["UPI", "Direct Bank Transfer (NEFT/RTGS)", "Cash Counter", "Cheque / DD", "POS Terminal / Debit Card"]'::jsonb)
    INTO v_payment_modes
    FROM public.lookup_values v
    JOIN public.lookup_keys k ON v.lookup_key_id = k.id
    WHERE k.key_code = 'STUDENT_FEE_PAYMENT_MODE' AND v.school_id = p_school_id AND v.status = 'ACTIVE';

    SELECT COALESCE(jsonb_agg(v.value_name ORDER BY v.sort_order), '["Merit Scholarship", "Staff Ward Concession", "Sibling Discount", "Financial Aid / EWS", "Sports Excellence Waiver"]'::jsonb)
    INTO v_concession_types
    FROM public.lookup_values v
    JOIN public.lookup_keys k ON v.lookup_key_id = k.id
    WHERE k.key_code = 'STUDENT_FEE_CONCESSION_TYPE' AND v.school_id = p_school_id AND v.status = 'ACTIVE';

    SELECT COALESCE(jsonb_agg(v.value_name ORDER BY v.sort_order), '["Late Fee Surcharge", "Bounced Cheque Penalty", "Library Overdue Fine", "Hostel Property Damage Surcharge"]'::jsonb)
    INTO v_penalty_types
    FROM public.lookup_values v
    JOIN public.lookup_keys k ON v.lookup_key_id = k.id
    WHERE k.key_code = 'STUDENT_FEE_PENALTY_TYPE' AND v.school_id = p_school_id AND v.status = 'ACTIVE';

    RETURN jsonb_build_object(
        'success', true,
        'classes', v_classes,
        'academic_years', v_years,
        'fee_types', v_fee_types,
        'payment_modes', v_payment_modes,
        'concession_types', v_concession_types,
        'penalty_types', v_penalty_types
    );
END;
$$;


-- ============================================================================
-- 6. FUNCTION: fn_staff_salary_metadata
-- Dynamic metadata for departments, roles, payment modes from lookups.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_staff_salary_metadata(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_depts JSONB;
    v_roles JSONB;
    v_modes JSONB;
    v_purposes JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(DISTINCT d), '["Academic & Teaching", "Administration", "Finance & Accounts", "Transport & Fleet", "Security & Safety"]'::jsonb)
    INTO v_depts
    FROM (
        SELECT v.value_name AS d
        FROM public.lookup_values v
        JOIN public.lookup_keys k ON v.lookup_key_id = k.id
        WHERE k.key_code = 'DEPARTMENT' AND v.school_id = p_school_id AND v.status = 'ACTIVE'
        UNION
        SELECT department AS d FROM public.profiles WHERE school_id = p_school_id AND department IS NOT NULL AND department != ''
    ) depts;

    SELECT COALESCE(jsonb_agg(DISTINCT r), '["Teacher", "Accountant", "Admin", "Librarian", "Hostel Warden", "Driver", "Staff"]'::jsonb)
    INTO v_roles
    FROM (
        SELECT role AS r FROM public.profiles 
        WHERE school_id = p_school_id AND role != 'student' AND role IS NOT NULL AND role != ''
    ) roles;

    SELECT COALESCE(jsonb_agg(v.value_name ORDER BY v.sort_order), '["Direct Bank Transfer (NEFT/RTGS)", "IMPS Instant Transfer", "UPI Auto-Payout", "Company Cheque", "Cash Disbursal"]'::jsonb)
    INTO v_modes
    FROM public.lookup_values v
    JOIN public.lookup_keys k ON v.lookup_key_id = k.id
    WHERE k.key_code = 'STAFF_SALARY_PAYMENT_MODE' AND v.school_id = p_school_id AND v.status = 'ACTIVE';

    SELECT COALESCE(jsonb_agg(v.value_name ORDER BY v.sort_order), '["Medical Emergency", "Family Event / Wedding", "Home Renovation / Repair", "Education & Higher Learning", "Travel & Urgent Relocation"]'::jsonb)
    INTO v_purposes
    FROM public.lookup_values v
    JOIN public.lookup_keys k ON v.lookup_key_id = k.id
    WHERE k.key_code = 'STAFF_ADVANCE_PURPOSE' AND v.school_id = p_school_id AND v.status = 'ACTIVE';

    RETURN jsonb_build_object(
        'success', true,
        'departments', v_depts,
        'roles', v_roles,
        'payment_modes', v_modes,
        'advance_purposes', v_purposes,
        'available_months', jsonb_build_array(
            '2026-10', '2026-09', '2026-08', '2026-07', '2026-06', '2026-05',
            '2026-04', '2026-03', '2026-02', '2026-01', '2025-12', '2025-11'
        )
    );
END;
$$;


-- ============================================================================
-- 7. FUNCTION: fn_collect_student_fee_payment
-- Atomic fee collection with auto invoice balance reconciliation and audit logging.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_collect_student_fee_payment(
    p_school_id UUID,
    p_student_id UUID,
    p_invoice_id UUID,
    p_amount NUMERIC(12,2),
    p_payment_method TEXT,
    p_transaction_reference TEXT,
    p_remarks TEXT,
    p_user_id UUID,
    p_user_name TEXT DEFAULT 'Finance Officer',
    p_user_role TEXT DEFAULT 'Finance Officer'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_rec_seq INT := 0;
    v_rec_num TEXT;
    v_inv_id UUID := p_invoice_id;
    v_pay_id UUID;
    v_tb NUMERIC(12,2);
    v_cur_paid NUMERIC(12,2);
    v_new_paid NUMERIC(12,2);
    v_new_bal NUMERIC(12,2);
    v_new_status TEXT;
BEGIN
    SELECT COUNT(*) + 1 INTO v_rec_seq
    FROM public.student_fee_payments
    WHERE school_id = p_school_id;
    v_rec_num := 'REC-2026-' || LPAD(v_rec_seq::text, 5, '0');

    -- Auto allocate invoice if not specified
    IF v_inv_id IS NULL THEN
        SELECT id INTO v_inv_id
        FROM public.student_fee_invoices
        WHERE student_id = p_student_id AND school_id = p_school_id AND status NOT IN ('Paid', 'Overpaid')
        ORDER BY due_date ASC, created_at ASC
        LIMIT 1;

        IF v_inv_id IS NULL THEN
            SELECT id INTO v_inv_id
            FROM public.student_fee_invoices
            WHERE student_id = p_student_id AND school_id = p_school_id
            ORDER BY created_at DESC
            LIMIT 1;
        END IF;
    END IF;

    -- Record Payment
    INSERT INTO public.student_fee_payments (
        school_id, student_id, invoice_id, receipt_number, amount_paid,
        payment_method, transaction_reference, status, remarks, recorded_by, created_at
    ) VALUES (
        p_school_id, p_student_id, v_inv_id, v_rec_num, p_amount,
        p_payment_method, p_transaction_reference, 'SUCCESS', p_remarks, p_user_id, NOW()
    ) RETURNING id INTO v_pay_id;

    -- Reconcile Invoice
    IF v_inv_id IS NOT NULL THEN
        SELECT total_billed, paid_amount INTO v_tb, v_cur_paid
        FROM public.student_fee_invoices
        WHERE id = v_inv_id AND school_id = p_school_id;

        IF v_tb IS NOT NULL THEN
            v_new_paid := v_cur_paid + p_amount;
            v_new_bal := GREATEST(0.0, v_tb - v_new_paid);
            v_new_status := CASE 
                WHEN v_new_paid > v_tb THEN 'Overpaid'
                WHEN v_new_bal <= 0.0 AND v_tb > 0 THEN 'Paid'
                ELSE 'Partial'
            END;

            UPDATE public.student_fee_invoices
            SET paid_amount = v_new_paid,
                balance_amount = v_new_bal,
                status = v_new_status,
                updated_at = NOW()
            WHERE id = v_inv_id AND school_id = p_school_id;
        END IF;
    END IF;

    -- Audit Log
    INSERT INTO public.student_fee_audit_logs (
        school_id, student_id, entity_type, entity_id, action,
        description, old_status, new_status, amount,
        performed_by_id, performed_by_name, performed_by_role
    ) VALUES (
        p_school_id, p_student_id, 'PAYMENT', v_pay_id, 'PAYMENT_COLLECTED',
        'Collected payment ' || v_rec_num || ' (' || p_payment_method || ') of ₹' || TO_CHAR(p_amount, 'FM99,99,990.00'),
        'Pending', 'SUCCESS', p_amount,
        p_user_id, p_user_name, p_user_role
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Payment recorded successfully',
        'receipt', jsonb_build_object(
            'id', v_pay_id,
            'receipt_number', v_rec_num,
            'amount_paid', p_amount,
            'invoice_id', v_inv_id
        )
    );
END;
$$;


-- ============================================================================
-- ============================================================================
-- Drop existing bulk functions to allow altering signature
DROP FUNCTION IF EXISTS public.fn_bulk_student_fee_action(uuid, text, uuid[], text, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.fn_bulk_student_fee_action(uuid, text, uuid[], uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.fn_bulk_staff_salary_action(uuid, text, uuid[], text, text, text, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.fn_bulk_staff_salary_action(uuid, text, uuid[], text, text, uuid) CASCADE;

-- 8. FUNCTION: fn_bulk_student_fee_action
-- Executes bulk operations: send_reminder, mark_paid, void_invoices
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_bulk_student_fee_action(
    p_school_id UUID,
    p_action TEXT,
    p_student_ids UUID[],
    p_user_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count INT := 0;
    v_sid UUID;
BEGIN
    IF p_action = 'send_reminder' THEN
        FOREACH v_sid IN ARRAY p_student_ids LOOP
            INSERT INTO public.student_fee_audit_logs (
                school_id, student_id, entity_type, entity_id, action,
                description, performed_by_id, performed_by_name, performed_by_role
            ) VALUES (
                p_school_id, v_sid, 'INVOICE', v_sid, 'REMINDER_SENT',
                'Payment reminder queued: ' || COALESCE(p_notes, 'Standard Fee Due Notice'),
                p_user_id, 'System Scheduler', 'System'
            );
            v_count := v_count + 1;
        END LOOP;
        RETURN jsonb_build_object('success', true, 'count', v_count, 'message', 'Payment reminders queued for ' || v_count || ' students');

    ELSIF p_action = 'mark_paid' THEN
        UPDATE public.student_fee_invoices
        SET paid_amount = total_billed,
            balance_amount = 0.0,
            status = 'Paid',
            updated_at = NOW()
        WHERE school_id = p_school_id 
          AND student_id = ANY(p_student_ids) 
          AND status IN ('Pending', 'Partial', 'Overdue');
        
        GET DIAGNOSTICS v_count = ROW_COUNT;
        RETURN jsonb_build_object('success', true, 'count', v_count, 'message', 'Marked invoices as Paid for selected students');

    ELSIF p_action = 'void_invoices' THEN
        DELETE FROM public.student_fee_invoices
        WHERE school_id = p_school_id 
          AND student_id = ANY(p_student_ids) 
          AND status IN ('Pending', 'Overdue');
        
        GET DIAGNOSTICS v_count = ROW_COUNT;
        RETURN jsonb_build_object('success', true, 'count', v_count, 'message', 'Voided ' || v_count || ' pending/overdue invoices');
    END IF;

    RETURN jsonb_build_object('success', false, 'message', 'Unknown bulk action: ' || p_action);
END;
$$;

-- Overload for backwards compatibility
CREATE OR REPLACE FUNCTION public.fn_bulk_student_fee_action(
    p_school_id UUID,
    p_action TEXT,
    p_student_ids UUID[],
    p_notes TEXT,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN public.fn_bulk_student_fee_action(p_school_id, p_action, p_student_ids, p_user_id, p_notes);
END;
$$;


-- ============================================================================
-- 9. FUNCTION: fn_bulk_staff_salary_action
-- Executes bulk operations: disburse_selected, hold_selected, approve_selected
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_bulk_staff_salary_action(
    p_school_id UUID,
    p_action TEXT,
    p_staff_ids UUID[],
    p_month_str TEXT DEFAULT '2026-10',
    p_payment_mode TEXT DEFAULT 'Direct Bank Transfer (NEFT/RTGS)',
    p_notes TEXT DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count INT := 0;
    v_sid UUID;
    v_idx INT := 1;
    v_ps_num TEXT;
    v_struct RECORD;
BEGIN
    IF p_action IN ('disburse_selected', 'disburse', 'pay') THEN
        FOREACH v_sid IN ARRAY p_staff_ids LOOP
            SELECT * INTO v_struct
            FROM public.staff_salary_structures
            WHERE staff_id = v_sid AND school_id = p_school_id;

            v_ps_num := 'PS-' || p_month_str || '-' || LPAD(v_idx::text, 4, '0');
            v_idx := v_idx + 1;

            INSERT INTO public.staff_salary_payouts (
                school_id, staff_id, payslip_number, month, year, month_str,
                basic_pay, hra, da, ta, special_allowance, bonus, gross_earnings,
                pf_deduction, tds, professional_tax, advance_deduction, other_deductions,
                total_deductions, net_pay, payment_status, payment_date, payment_mode,
                transaction_reference, remarks, processed_by
            ) VALUES (
                p_school_id, v_sid, v_ps_num, 10, 2026, p_month_str,
                COALESCE(v_struct.basic_pay, 45000.0), COALESCE(v_struct.hra, 8000.0), 
                COALESCE(v_struct.da, 4500.0), COALESCE(v_struct.ta, 2500.0),
                COALESCE(v_struct.special_allowance, 2000.0), 0.0, COALESCE(v_struct.gross_salary, 62000.0),
                COALESCE(v_struct.pf_deduction, 1800.0), COALESCE(v_struct.tds, 2500.0), 
                COALESCE(v_struct.professional_tax, 200.0), 0.0, 0.0,
                COALESCE(v_struct.total_deductions, 5000.0), COALESCE(v_struct.net_salary, 57000.0),
                'Paid', NOW(), p_payment_mode,
                'TXN-BULK-' || SUBSTRING(v_sid::text, 1, 8), COALESCE(p_notes, 'Batch payroll automated disbarment'), p_user_id
            )
            ON CONFLICT (school_id, staff_id, month_str) DO UPDATE SET
                payment_status = 'Paid',
                payment_date = NOW(),
                transaction_reference = EXCLUDED.transaction_reference,
                remarks = EXCLUDED.remarks,
                updated_at = NOW();

            v_count := v_count + 1;
        END LOOP;
        RETURN jsonb_build_object('success', true, 'count', v_count, 'message', 'Disbursed salary for ' || v_count || ' staff members');

    ELSIF p_action IN ('hold_selected', 'hold') THEN
        UPDATE public.staff_salary_payouts
        SET payment_status = 'On-Hold',
            remarks = COALESCE(p_notes, 'Marked on-hold during review'),
            updated_at = NOW()
        WHERE school_id = p_school_id 
          AND staff_id = ANY(p_staff_ids) 
          AND month_str = p_month_str;
        
        GET DIAGNOSTICS v_count = ROW_COUNT;
        RETURN jsonb_build_object('success', true, 'count', v_count, 'message', 'Placed salary on hold for ' || v_count || ' staff members');

    ELSIF p_action IN ('approve_selected', 'approve') THEN
        UPDATE public.staff_salary_payouts
        SET payment_status = 'Approved',
            remarks = COALESCE(p_notes, 'Approved by Finance Admin'),
            processed_by = p_user_id,
            updated_at = NOW()
        WHERE school_id = p_school_id 
          AND staff_id = ANY(p_staff_ids) 
          AND month_str = p_month_str;
        
        GET DIAGNOSTICS v_count = ROW_COUNT;
        RETURN jsonb_build_object('success', true, 'count', v_count, 'message', 'Approved payout for ' || v_count || ' staff members');
    END IF;

    RETURN jsonb_build_object('success', false, 'message', 'Unknown bulk action: ' || p_action);
END;
$$;

-- Overload for 6 parameters (without p_notes)
CREATE OR REPLACE FUNCTION public.fn_bulk_staff_salary_action(
    p_school_id UUID,
    p_action TEXT,
    p_staff_ids UUID[],
    p_month_str TEXT,
    p_payment_mode TEXT,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN public.fn_bulk_staff_salary_action(p_school_id, p_action, p_staff_ids, p_month_str, p_payment_mode, NULL, p_user_id);
END;
$$;


-- 10. FUNCTION: fn_student_fee_account_details
-- Full financial profile for single student: details, invoices, payments,
-- concessions, penalties and audit history.
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
    LIMIT 20;

    -- Compute overall student finance
    SELECT 
        COALESCE(SUM(i.total_billed), 0.0),
        GREATEST(
            COALESCE(SUM(i.paid_amount), 0.0),
            COALESCE((
                SELECT SUM(amount_paid) FROM public.student_fee_payments 
                WHERE student_id = p_student_id AND school_id = p_school_id 
                  AND (status IS NULL OR status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS'))
            ), 0.0)
        )
    INTO v_total_billed, v_total_paid
    FROM public.student_fee_invoices i
    WHERE i.student_id = p_student_id AND i.school_id = p_school_id;

    v_balance := GREATEST(0.0, v_total_billed - v_total_paid);
    IF v_total_paid > v_total_billed THEN
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
            'admission_number', COALESCE(v_profile.admission_number, 'ADM-' || SUBSTRING(v_profile.id::text, 1, 6)),
            'avatar_url', v_profile.avatar_url,
            'total_billed', v_total_billed,
            'paid_amount', v_total_paid,
            'balance_amount', v_balance,
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


-- ============================================================================
-- 11. FUNCTION: fn_create_student_fee_invoice
-- Single invoice creation with audit log.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_create_student_fee_invoice(
    p_school_id UUID,
    p_student_id UUID,
    p_fee_type TEXT,
    p_fee_plan TEXT,
    p_academic_year TEXT,
    p_amount NUMERIC(12,2),
    p_due_date DATE,
    p_title TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_user_id UUID DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_seq INT := 0;
    v_inv_num TEXT;
    v_inv_id UUID;
    v_title TEXT := COALESCE(p_title, p_fee_type || ' - ' || p_academic_year);
BEGIN
    SELECT COUNT(*) + 1 INTO v_seq
    FROM public.student_fee_invoices
    WHERE school_id = p_school_id;
    v_inv_num := 'INV-2026-' || LPAD(v_seq::text, 5, '0');

    INSERT INTO public.student_fee_invoices (
        school_id, student_id, invoice_number, title, fee_type, fee_plan,
        academic_year, billing_date, due_date, subtotal, total_billed,
        paid_amount, balance_amount, status, notes
    ) VALUES (
        p_school_id, p_student_id, v_inv_num, v_title, p_fee_type, COALESCE(p_fee_plan, 'Monthly'),
        COALESCE(p_academic_year, '2026 - 2027'), CURRENT_DATE, p_due_date, p_amount, p_amount,
        0.0, p_amount, 'Pending', p_notes
    ) RETURNING id INTO v_inv_id;

    -- Audit Log
    INSERT INTO public.student_fee_audit_logs (
        school_id, student_id, entity_type, entity_id, action,
        description, old_status, new_status, amount, performed_by_id, performed_by_name
    ) VALUES (
        p_school_id, p_student_id, 'INVOICE', v_inv_id, 'INVOICE_GENERATED',
        'Generated invoice ' || v_inv_num || ' for ' || p_fee_type || ' of ₹' || TO_CHAR(p_amount, 'FM99,99,990.00'),
        NULL, 'Pending', p_amount, p_user_id, p_user_name
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Invoice generated successfully',
        'invoice_id', v_inv_id,
        'invoice_number', v_inv_num
    );
END;
$$;


-- ============================================================================
-- 12. FUNCTION: fn_bulk_create_student_fee_invoices
-- Class-wide bulk invoice generation.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_bulk_create_student_fee_invoices(
    p_school_id UUID,
    p_class_name TEXT,
    p_fee_type TEXT,
    p_fee_plan TEXT,
    p_academic_year TEXT,
    p_amount NUMERIC(12,2),
    p_due_date DATE,
    p_title TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_user_id UUID DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sid UUID;
    v_count INT := 0;
BEGIN
    FOR v_sid IN 
        SELECT id FROM public.profiles
        WHERE school_id = p_school_id AND role = 'student'
          AND (p_class_name IS NULL OR p_class_name IN ('All Classes', 'All', '') OR class = p_class_name)
    LOOP
        PERFORM public.fn_create_student_fee_invoice(
            p_school_id, v_sid, p_fee_type, p_fee_plan, p_academic_year,
            p_amount, p_due_date, p_title, p_notes, p_user_id, p_user_name
        );
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'count', v_count,
        'message', 'Generated ' || v_count || ' invoices for class ' || COALESCE(p_class_name, 'All')
    );
END;
$$;


-- ============================================================================
-- 13. FUNCTION: fn_apply_student_concession
-- Applies concession waiver and adjusts invoice balance atomically.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_apply_student_concession(
    p_school_id UUID,
    p_student_id UUID,
    p_invoice_id UUID,
    p_concession_type TEXT,
    p_amount NUMERIC(12,2),
    p_reason TEXT,
    p_user_id UUID DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_conc_id UUID;
    v_inv_id UUID := p_invoice_id;
BEGIN
    IF v_inv_id IS NULL THEN
        SELECT id INTO v_inv_id
        FROM public.student_fee_invoices
        WHERE student_id = p_student_id AND school_id = p_school_id AND balance_amount > 0
        ORDER BY due_date ASC LIMIT 1;
    END IF;

    INSERT INTO public.student_fee_concessions (
        school_id, student_id, invoice_id, concession_type, amount, reason, approved_by
    ) VALUES (
        p_school_id, p_student_id, v_inv_id, p_concession_type, p_amount, p_reason, p_user_id
    ) RETURNING id INTO v_conc_id;

    IF v_inv_id IS NOT NULL THEN
        UPDATE public.student_fee_invoices
        SET concession_amount = concession_amount + p_amount,
            total_billed = GREATEST(0.0, total_billed - p_amount),
            balance_amount = GREATEST(0.0, GREATEST(0.0, total_billed - p_amount) - paid_amount),
            status = CASE 
                WHEN paid_amount >= GREATEST(0.0, total_billed - p_amount) AND GREATEST(0.0, total_billed - p_amount) > 0 THEN 'Paid'
                WHEN GREATEST(0.0, GREATEST(0.0, total_billed - p_amount) - paid_amount) = 0.0 THEN 'Paid'
                WHEN paid_amount > 0 THEN 'Partial'
                ELSE status
            END,
            updated_at = NOW()
        WHERE id = v_inv_id AND school_id = p_school_id;
    END IF;

    -- Audit Log
    INSERT INTO public.student_fee_audit_logs (
        school_id, student_id, entity_type, entity_id, action,
        description, amount, performed_by_id, performed_by_name
    ) VALUES (
        p_school_id, p_student_id, 'CONCESSION', v_conc_id, 'CONCESSION_APPLIED',
        'Applied ' || p_concession_type || ' of ₹' || TO_CHAR(p_amount, 'FM99,99,990.00'),
        p_amount, p_user_id, p_user_name
    );

    RETURN jsonb_build_object(
        'success', true,
        'concession_id', v_conc_id,
        'message', 'Fee concession applied successfully'
    );
END;
$$;


-- ============================================================================
-- 14. FUNCTION: fn_reverse_student_concession
-- Reverses a concession and restores invoice total/balance.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_reverse_student_concession(
    p_school_id UUID,
    p_concession_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_conc RECORD;
BEGIN
    SELECT * INTO v_conc
    FROM public.student_fee_concessions
    WHERE id = p_concession_id AND school_id = p_school_id;

    IF v_conc.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Concession not found');
    END IF;

    IF v_conc.invoice_id IS NOT NULL THEN
        UPDATE public.student_fee_invoices
        SET concession_amount = GREATEST(0.0, concession_amount - v_conc.amount),
            total_billed = total_billed + v_conc.amount,
            balance_amount = balance_amount + v_conc.amount,
            status = CASE 
                WHEN due_date < CURRENT_DATE AND (balance_amount + v_conc.amount) > 0 THEN 'Overdue'
                WHEN paid_amount > 0 THEN 'Partial'
                ELSE 'Pending'
            END,
            updated_at = NOW()
        WHERE id = v_conc.invoice_id AND school_id = p_school_id;
    END IF;

    DELETE FROM public.student_fee_concessions WHERE id = p_concession_id;

    -- Audit Log
    INSERT INTO public.student_fee_audit_logs (
        school_id, student_id, entity_type, entity_id, action,
        description, amount, performed_by_id, performed_by_name
    ) VALUES (
        p_school_id, v_conc.student_id, 'CONCESSION', p_concession_id, 'CONCESSION_REVERSED',
        'Reversed concession ' || v_conc.concession_type || ' of ₹' || TO_CHAR(v_conc.amount, 'FM99,99,990.00'),
        v_conc.amount, p_user_id, p_user_name
    );

    RETURN jsonb_build_object('success', true, 'message', 'Concession reversed successfully');
END;
$$;


-- ============================================================================
-- 15. FUNCTION: fn_apply_student_penalty
-- Adds late penalty surcharge to student invoice atomically.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_apply_student_penalty(
    p_school_id UUID,
    p_student_id UUID,
    p_invoice_id UUID,
    p_penalty_type TEXT,
    p_amount NUMERIC(12,2),
    p_reason TEXT,
    p_user_id UUID DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pen_id UUID;
    v_inv_id UUID := p_invoice_id;
BEGIN
    IF v_inv_id IS NULL THEN
        SELECT id INTO v_inv_id
        FROM public.student_fee_invoices
        WHERE student_id = p_student_id AND school_id = p_school_id
        ORDER BY due_date ASC LIMIT 1;
    END IF;

    INSERT INTO public.student_fee_penalties (
        school_id, student_id, invoice_id, penalty_type, amount, reason, applied_by
    ) VALUES (
        p_school_id, p_student_id, v_inv_id, p_penalty_type, p_amount, p_reason, p_user_id
    ) RETURNING id INTO v_pen_id;

    IF v_inv_id IS NOT NULL THEN
        UPDATE public.student_fee_invoices
        SET penalty_amount = penalty_amount + p_amount,
            total_billed = total_billed + p_amount,
            balance_amount = balance_amount + p_amount,
            status = CASE 
                WHEN due_date < CURRENT_DATE AND (balance_amount + p_amount) > 0 THEN 'Overdue'
                WHEN paid_amount > 0 THEN 'Partial'
                ELSE status
            END,
            updated_at = NOW()
        WHERE id = v_inv_id AND school_id = p_school_id;
    END IF;

    -- Audit Log
    INSERT INTO public.student_fee_audit_logs (
        school_id, student_id, entity_type, entity_id, action,
        description, amount, performed_by_id, performed_by_name
    ) VALUES (
        p_school_id, p_student_id, 'PENALTY', v_pen_id, 'PENALTY_APPLIED',
        'Applied ' || p_penalty_type || ' fine of ₹' || TO_CHAR(p_amount, 'FM99,99,990.00'),
        p_amount, p_user_id, p_user_name
    );

    RETURN jsonb_build_object(
        'success', true,
        'penalty_id', v_pen_id,
        'message', 'Penalty applied successfully'
    );
END;
$$;


-- ============================================================================
-- 16. FUNCTION: fn_reverse_student_penalty
-- Reverses a penalty and deducts from invoice balance.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_reverse_student_penalty(
    p_school_id UUID,
    p_penalty_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_user_name TEXT DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pen RECORD;
BEGIN
    SELECT * INTO v_pen
    FROM public.student_fee_penalties
    WHERE id = p_penalty_id AND school_id = p_school_id;

    IF v_pen.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Penalty not found');
    END IF;

    IF v_pen.invoice_id IS NOT NULL THEN
        UPDATE public.student_fee_invoices
        SET penalty_amount = GREATEST(0.0, penalty_amount - v_pen.amount),
            total_billed = GREATEST(0.0, total_billed - v_pen.amount),
            balance_amount = GREATEST(0.0, balance_amount - v_pen.amount),
            status = CASE 
                WHEN balance_amount - v_pen.amount <= 0 AND total_billed - v_pen.amount > 0 THEN 'Paid'
                WHEN paid_amount > 0 THEN 'Partial'
                ELSE status
            END,
            updated_at = NOW()
        WHERE id = v_pen.invoice_id AND school_id = p_school_id;
    END IF;

    DELETE FROM public.student_fee_penalties WHERE id = p_penalty_id;

    -- Audit Log
    INSERT INTO public.student_fee_audit_logs (
        school_id, student_id, entity_type, entity_id, action,
        description, amount, performed_by_id, performed_by_name
    ) VALUES (
        p_school_id, v_pen.student_id, 'PENALTY', p_penalty_id, 'PENALTY_REVERSED',
        'Reversed penalty ' || v_pen.penalty_type || ' of ₹' || TO_CHAR(v_pen.amount, 'FM99,99,990.00'),
        v_pen.amount, p_user_id, p_user_name
    );

    RETURN jsonb_build_object('success', true, 'message', 'Penalty reversed successfully');
END;
$$;


-- ============================================================================
-- 17. FUNCTION: fn_staff_salary_account_details
-- Retrieves comprehensive salary profile, structure, past payouts and advances.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_staff_salary_account_details(
    p_school_id UUID,
    p_staff_id UUID,
    p_month_str TEXT DEFAULT '2026-10'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile RECORD;
    v_struct RECORD;
    v_payout RECORD;
    v_payouts JSONB;
    v_advances JSONB;
BEGIN
    SELECT id, full_name, email, phone, department, role, employee_id, avatar_url
    INTO v_profile
    FROM public.profiles
    WHERE id = p_staff_id AND school_id = p_school_id;

    IF v_profile.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Staff member not found');
    END IF;

    SELECT * INTO v_struct
    FROM public.staff_salary_structures
    WHERE staff_id = p_staff_id AND school_id = p_school_id;

    SELECT * INTO v_payout
    FROM public.staff_salary_payouts
    WHERE staff_id = p_staff_id AND school_id = p_school_id AND month_str = p_month_str;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', p.id,
                'month_str', p.month_str,
                'payslip_number', p.payslip_number,
                'basic_pay', p.basic_pay,
                'gross_earnings', p.gross_earnings,
                'total_deductions', p.total_deductions,
                'net_pay', p.net_pay,
                'payment_status', p.payment_status,
                'payment_date', p.payment_date,
                'payment_mode', p.payment_mode,
                'transaction_reference', p.transaction_reference
            ) ORDER BY p.year DESC, p.month DESC
        ), '[]'::jsonb
    ) INTO v_payouts
    FROM public.staff_salary_payouts p
    WHERE p.staff_id = p_staff_id AND p.school_id = p_school_id;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', a.id,
                'amount', a.amount,
                'purpose_type', a.purpose_type,
                'reason', a.reason,
                'repayment_months', a.repayment_months,
                'monthly_deduction', a.monthly_deduction,
                'amount_repaid', a.amount_repaid,
                'status', a.status,
                'disbursed_at', a.disbursed_at
            ) ORDER BY a.created_at DESC
        ), '[]'::jsonb
    ) INTO v_advances
    FROM public.staff_salary_advances a
    WHERE a.staff_id = p_staff_id AND a.school_id = p_school_id;

    RETURN jsonb_build_object(
        'success', true,
        'profile', jsonb_build_object(
            'id', v_profile.id,
            'name', v_profile.full_name,
            'email', v_profile.email,
            'phone', v_profile.phone,
            'department', COALESCE(v_profile.department, 'Academic & Teaching'),
            'role_title', COALESCE(v_profile.role, 'Teacher'),
            'employee_id', COALESCE(v_profile.employee_id, 'EMP-' || SUBSTRING(v_profile.id::text, 1, 6)),
            'avatar_url', v_profile.avatar_url
        ),
        'structure', jsonb_build_object(
            'basic_pay', COALESCE(v_struct.basic_pay, 35000.0),
            'hra', COALESCE(v_struct.hra, 14000.0),
            'da', COALESCE(v_struct.da, 4500.0),
            'ta', COALESCE(v_struct.ta, 2500.0),
            'special_allowance', COALESCE(v_struct.special_allowance, 2000.0),
            'gross_salary', COALESCE(v_struct.gross_salary, 58000.0),
            'pf_deduction', COALESCE(v_struct.pf_deduction, 1800.0),
            'tds', COALESCE(v_struct.tds, 2500.0),
            'professional_tax', COALESCE(v_struct.professional_tax, 200.0),
            'insurance_deduction', COALESCE(v_struct.insurance_deduction, 500.0),
            'total_deductions', COALESCE(v_struct.total_deductions, 5000.0),
            'net_salary', COALESCE(v_struct.net_salary, 53000.0),
            'bank_name', COALESCE(v_struct.bank_name, 'HDFC Bank'),
            'account_number', COALESCE(v_struct.account_number, '501002340055'),
            'ifsc_code', COALESCE(v_struct.ifsc_code, 'HDFC0001824'),
            'pan_number', COALESCE(v_struct.pan_number, 'PAN000055X'),
            'payment_mode', COALESCE(v_struct.payment_mode, 'Direct Bank Transfer (NEFT/RTGS)')
        ),
        'current_payout', jsonb_build_object(
            'status', COALESCE(v_payout.payment_status, 'Pending'),
            'payslip_number', v_payout.payslip_number,
            'payment_date', v_payout.payment_date,
            'transaction_reference', v_payout.transaction_reference,
            'net_pay', COALESCE(v_payout.net_pay, v_struct.net_salary, 53000.0)
        ),
        'payout_history', v_payouts,
        'advances', v_advances
    );
END;
$$;


-- ============================================================================
-- 18. FUNCTION: fn_save_staff_salary_structure
-- Upserts salary structure with automatic calculation of gross, deductions, net.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_save_staff_salary_structure(
    p_school_id UUID,
    p_staff_id UUID,
    p_basic_pay NUMERIC(12,2),
    p_hra NUMERIC(12,2),
    p_da NUMERIC(12,2),
    p_ta NUMERIC(12,2),
    p_special_allowance NUMERIC(12,2),
    p_pf_deduction NUMERIC(12,2),
    p_tds NUMERIC(12,2),
    p_professional_tax NUMERIC(12,2),
    p_insurance_deduction NUMERIC(12,2),
    p_bank_name TEXT,
    p_account_number TEXT,
    p_ifsc_code TEXT,
    p_pan_number TEXT,
    p_payment_mode TEXT DEFAULT 'Direct Bank Transfer (NEFT/RTGS)',
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_gross NUMERIC(12,2);
    v_deductions NUMERIC(12,2);
    v_net NUMERIC(12,2);
    v_struct_id UUID;
BEGIN
    v_gross := p_basic_pay + p_hra + p_da + p_ta + p_special_allowance;
    v_deductions := p_pf_deduction + p_tds + p_professional_tax + p_insurance_deduction;
    v_net := GREATEST(0.0, v_gross - v_deductions);

    INSERT INTO public.staff_salary_structures (
        school_id, staff_id, basic_pay, hra, da, ta, special_allowance,
        gross_salary, pf_deduction, tds, professional_tax, insurance_deduction,
        total_deductions, net_salary, bank_name, account_number, ifsc_code,
        pan_number, payment_mode, status, effective_date, updated_at
    ) VALUES (
        p_school_id, p_staff_id, p_basic_pay, p_hra, p_da, p_ta, p_special_allowance,
        v_gross, p_pf_deduction, p_tds, p_professional_tax, p_insurance_deduction,
        v_deductions, v_net, p_bank_name, p_account_number, p_ifsc_code,
        p_pan_number, p_payment_mode, 'ACTIVE', CURRENT_DATE, NOW()
    )
    ON CONFLICT (school_id, staff_id) DO UPDATE SET
        basic_pay = EXCLUDED.basic_pay,
        hra = EXCLUDED.hra,
        da = EXCLUDED.da,
        ta = EXCLUDED.ta,
        special_allowance = EXCLUDED.special_allowance,
        gross_salary = EXCLUDED.gross_salary,
        pf_deduction = EXCLUDED.pf_deduction,
        tds = EXCLUDED.tds,
        professional_tax = EXCLUDED.professional_tax,
        insurance_deduction = EXCLUDED.insurance_deduction,
        total_deductions = EXCLUDED.total_deductions,
        net_salary = EXCLUDED.net_salary,
        bank_name = EXCLUDED.bank_name,
        account_number = EXCLUDED.account_number,
        ifsc_code = EXCLUDED.ifsc_code,
        pan_number = EXCLUDED.pan_number,
        payment_mode = EXCLUDED.payment_mode,
        updated_at = NOW()
    RETURNING id INTO v_struct_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Staff salary structure saved successfully',
        'structure_id', v_struct_id,
        'gross_salary', v_gross,
        'total_deductions', v_deductions,
        'net_salary', v_net
    );
END;
$$;


-- ============================================================================
-- 19. FUNCTION: fn_process_staff_salary_payout
-- Executes single staff payroll payout with advance deduction & payslip generation.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_process_staff_salary_payout(
    p_school_id UUID,
    p_staff_id UUID,
    p_month_str TEXT DEFAULT '2026-10',
    p_payment_mode TEXT DEFAULT 'Direct Bank Transfer (NEFT/RTGS)',
    p_transaction_reference TEXT DEFAULT NULL,
    p_remarks TEXT DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_struct RECORD;
    v_adv_ded NUMERIC(12,2) := 0.0;
    v_net NUMERIC(12,2);
    v_ps_num TEXT;
    v_payout_id UUID;
    v_m INT := 10;
    v_y INT := 2026;
BEGIN
    -- Parse month_str (YYYY-MM)
    BEGIN
        v_y := SUBSTRING(p_month_str FROM 1 FOR 4)::int;
        v_m := SUBSTRING(p_month_str FROM 6 FOR 2)::int;
    EXCEPTION WHEN OTHERS THEN
        v_y := 2026;
        v_m := 10;
    END;

    SELECT * INTO v_struct
    FROM public.staff_salary_structures
    WHERE staff_id = p_staff_id AND school_id = p_school_id;

    -- Active advance deduction
    SELECT COALESCE(SUM(monthly_deduction), 0.0) INTO v_adv_ded
    FROM public.staff_salary_advances
    WHERE staff_id = p_staff_id AND school_id = p_school_id
      AND status = 'Approved' AND amount_repaid < amount;

    v_net := GREATEST(0.0, COALESCE(v_struct.net_salary, 55100.0) - v_adv_ded);
    v_ps_num := 'PS-' || p_month_str || '-' || SUBSTRING(p_staff_id::text, 1, 4);

    INSERT INTO public.staff_salary_payouts (
        school_id, staff_id, payslip_number, month, year, month_str,
        basic_pay, hra, da, ta, special_allowance, bonus, gross_earnings,
        pf_deduction, tds, professional_tax, advance_deduction, other_deductions,
        total_deductions, net_pay, payment_status, payment_date, payment_mode,
        transaction_reference, remarks, processed_by
    ) VALUES (
        p_school_id, p_staff_id, v_ps_num, v_m, v_y, p_month_str,
        COALESCE(v_struct.basic_pay, 35000.0), COALESCE(v_struct.hra, 14000.0),
        COALESCE(v_struct.da, 4500.0), COALESCE(v_struct.ta, 2500.0),
        COALESCE(v_struct.special_allowance, 2000.0), 0.0, COALESCE(v_struct.gross_salary, 63000.0),
        COALESCE(v_struct.pf_deduction, 1800.0), COALESCE(v_struct.tds, 2500.0),
        COALESCE(v_struct.professional_tax, 200.0), v_adv_ded, 0.0,
        COALESCE(v_struct.total_deductions, 7900.0) + v_adv_ded, v_net,
        'Paid', NOW(), p_payment_mode,
        COALESCE(p_transaction_reference, 'TXN-' || TO_CHAR(NOW(), 'YYYYMMDD-HH24MISS')),
        COALESCE(p_remarks, 'Monthly salary disbursed successfully'), p_user_id
    )
    ON CONFLICT (school_id, staff_id, month_str) DO UPDATE SET
        payment_status = 'Paid',
        payment_date = NOW(),
        advance_deduction = EXCLUDED.advance_deduction,
        total_deductions = EXCLUDED.total_deductions,
        net_pay = EXCLUDED.net_pay,
        payment_mode = EXCLUDED.payment_mode,
        transaction_reference = EXCLUDED.transaction_reference,
        remarks = EXCLUDED.remarks,
        updated_at = NOW()
    RETURNING id INTO v_payout_id;

    -- Update repaid amount on active advances
    IF v_adv_ded > 0 THEN
        UPDATE public.staff_salary_advances
        SET amount_repaid = LEAST(amount, amount_repaid + monthly_deduction),
            status = CASE WHEN (amount_repaid + monthly_deduction) >= amount THEN 'Repaid' ELSE status END,
            updated_at = NOW()
        WHERE staff_id = p_staff_id AND school_id = p_school_id AND status = 'Approved' AND amount_repaid < amount;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Salary disbursed successfully',
        'payout_id', v_payout_id,
        'payslip_number', v_ps_num,
        'net_pay', v_net
    );
END;
$$;


-- ============================================================================
-- 20. FUNCTION: fn_request_staff_salary_advance
-- Creates staff advance request with automatic monthly installment deduction.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_request_staff_salary_advance(
    p_school_id UUID,
    p_staff_id UUID,
    p_amount NUMERIC(12,2),
    p_purpose_type TEXT,
    p_reason TEXT,
    p_repayment_months INT DEFAULT 3,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_adv_id UUID;
    v_monthly_ded NUMERIC(12,2);
    v_months INT := GREATEST(1, COALESCE(p_repayment_months, 3));
BEGIN
    v_monthly_ded := ROUND(p_amount / v_months, 2);

    INSERT INTO public.staff_salary_advances (
        school_id, staff_id, amount, purpose_type, reason,
        repayment_months, monthly_deduction, amount_repaid, status,
        disbursed_at, approved_by
    ) VALUES (
        p_school_id, p_staff_id, p_amount, p_purpose_type, p_reason,
        v_months, v_monthly_ded, 0.0, 'Approved',
        NOW(), p_user_id
    ) RETURNING id INTO v_adv_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Salary advance approved and scheduled for deduction',
        'advance_id', v_adv_id,
        'monthly_deduction', v_monthly_ded
    );
END;
$$;


-- ============================================================================
-- 21. FUNCTION: fn_update_staff_salary_advance_status
-- Approves, rejects, or marks repaid on staff advances.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_update_staff_salary_advance_status(
    p_school_id UUID,
    p_advance_id UUID,
    p_status TEXT,
    p_notes TEXT DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.staff_salary_advances
    SET status = p_status,
        remarks = COALESCE(p_notes, remarks),
        approved_by = COALESCE(p_user_id, approved_by),
        updated_at = NOW()
    WHERE id = p_advance_id AND school_id = p_school_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Advance status updated to ' || p_status
    );
END;
$$;


-- ============================================================================
-- 22. FUNCTION: fn_update_staff_payout_status
-- Updates salary payout status (Pending, Approved, On-Hold, Review, Paid).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_update_staff_payout_status(
    p_school_id UUID,
    p_payout_id UUID,
    p_status TEXT,
    p_notes TEXT DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.staff_salary_payouts
    SET payment_status = p_status,
        remarks = COALESCE(p_notes, remarks),
        processed_by = COALESCE(p_user_id, processed_by),
        updated_at = NOW()
    WHERE id = p_payout_id AND school_id = p_school_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Payout status updated to ' || p_status
    );
END;
$$;


-- ============================================================================
-- 23. FUNCTION: fn_list_all_student_invoices
-- Master invoice list with pagination and search.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_list_all_student_invoices(
    p_school_id UUID,
    p_search TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 15
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_clean_size INT := GREATEST(1, LEAST(100, COALESCE(p_page_size, 15)));
    v_offset INT := (v_clean_page - 1) * v_clean_size;
    v_total_items INT := 0;
    v_total_pages INT := 1;
    v_invoices JSONB := '[]'::jsonb;
BEGIN
    WITH filtered AS (
        SELECT 
            i.id, i.invoice_number, i.title, i.fee_type, i.fee_plan, i.due_date,
            i.total_billed, i.paid_amount, i.balance_amount, i.status,
            p.full_name AS student_name, p.roll_number, p.class AS class_name,
            i.created_at
        FROM public.student_fee_invoices i
        JOIN public.profiles p ON i.student_id = p.id
        WHERE i.school_id = p_school_id
          AND (p_search IS NULL OR p_search = '' OR (
              i.invoice_number ILIKE '%' || p_search || '%' OR
              p.full_name ILIKE '%' || p_search || '%' OR
              i.title ILIKE '%' || p_search || '%'
          ))
          AND (p_status IS NULL OR p_status IN ('All Status', 'All', '') OR i.status = p_status)
    ),
    counted AS (
        SELECT COUNT(*) AS total_items FROM filtered
    ),
    sorted_page AS (
        SELECT * FROM filtered
        ORDER BY created_at DESC
        LIMIT v_clean_size OFFSET v_offset
    )
    SELECT 
        (SELECT total_items FROM counted),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', sp.id,
                    'invoice_number', sp.invoice_number,
                    'title', sp.title,
                    'fee_type', sp.fee_type,
                    'fee_plan', sp.fee_plan,
                    'due_date', sp.due_date,
                    'total_billed', sp.total_billed,
                    'paid_amount', sp.paid_amount,
                    'balance_amount', sp.balance_amount,
                    'status', sp.status,
                    'student_name', sp.student_name,
                    'roll_number', sp.roll_number,
                    'class_name', sp.class_name,
                    'created_at', sp.created_at
                )
            ), '[]'::jsonb
        ) INTO v_total_items, v_invoices
    FROM sorted_page sp;

    v_total_items := COALESCE(v_total_items, 0);
    IF v_total_items > 0 THEN
        v_total_pages := CEIL(v_total_items::numeric / v_clean_size);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'invoices', v_invoices,
        'pagination', jsonb_build_object(
            'page', v_clean_page,
            'page_size', v_clean_size,
            'total_items', v_total_items,
            'total_pages', v_total_pages
        )
    );
END;
$$;


-- ============================================================================
-- 24. FUNCTION: fn_list_all_student_payments
-- Master payment list with pagination and search.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_list_all_student_payments(
    p_school_id UUID,
    p_search TEXT DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 15
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_clean_size INT := GREATEST(1, LEAST(100, COALESCE(p_page_size, 15)));
    v_offset INT := (v_clean_page - 1) * v_clean_size;
    v_total_items INT := 0;
    v_total_pages INT := 1;
    v_payments JSONB := '[]'::jsonb;
BEGIN
    WITH filtered AS (
        SELECT 
            pay.id, pay.receipt_number, pay.amount_paid, pay.payment_method,
            pay.transaction_reference, pay.payment_date, pay.status, pay.remarks,
            pay.created_at, p.full_name AS student_name, p.roll_number, p.class AS class_name,
            i.invoice_number
        FROM public.student_fee_payments pay
        JOIN public.profiles p ON pay.student_id = p.id
        LEFT JOIN public.student_fee_invoices i ON pay.invoice_id = i.id
        WHERE pay.school_id = p_school_id
          AND (p_search IS NULL OR p_search = '' OR (
              pay.receipt_number ILIKE '%' || p_search || '%' OR
              p.full_name ILIKE '%' || p_search || '%' OR
              pay.transaction_reference ILIKE '%' || p_search || '%' OR
              i.invoice_number ILIKE '%' || p_search || '%'
          ))
    ),
    counted AS (
        SELECT COUNT(*) AS total_items FROM filtered
    ),
    sorted_page AS (
        SELECT * FROM filtered
        ORDER BY created_at DESC
        LIMIT v_clean_size OFFSET v_offset
    )
    SELECT 
        (SELECT total_items FROM counted),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', sp.id,
                    'receipt_number', sp.receipt_number,
                    'amount_paid', sp.amount_paid,
                    'payment_method', sp.payment_method,
                    'transaction_reference', sp.transaction_reference,
                    'payment_date', sp.payment_date,
                    'status', sp.status,
                    'remarks', sp.remarks,
                    'created_at', sp.created_at,
                    'student_name', sp.student_name,
                    'roll_number', sp.roll_number,
                    'class_name', sp.class_name,
                    'invoice_number', sp.invoice_number
                )
            ), '[]'::jsonb
        ) INTO v_total_items, v_payments
    FROM sorted_page sp;

    v_total_items := COALESCE(v_total_items, 0);
    IF v_total_items > 0 THEN
        v_total_pages := CEIL(v_total_items::numeric / v_clean_size);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'payments', v_payments,
        'pagination', jsonb_build_object(
            'page', v_clean_page,
            'page_size', v_clean_size,
            'total_items', v_total_items,
            'total_pages', v_total_pages
        )
    );
END;
$$;


-- ============================================================================
-- 25. FUNCTION: fn_list_all_staff_payslips
-- Master list of monthly staff payslips with breakdown and pagination.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_list_all_staff_payslips(
    p_school_id UUID,
    p_month_str TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 15
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_clean_size INT := GREATEST(1, LEAST(100, COALESCE(p_page_size, 15)));
    v_offset INT := (v_clean_page - 1) * v_clean_size;
    v_total_items INT := 0;
    v_total_pages INT := 1;
    v_payslips JSONB := '[]'::jsonb;
BEGIN
    WITH filtered AS (
        SELECT 
            pay.*,
            s.full_name AS staff_name, s.employee_id, s.department, s.role, s.email, s.phone,
            COALESCE(struct.bank_name, 'HDFC Bank') AS bank_name,
            COALESCE(struct.account_number, '501002340055') AS account_number,
            COALESCE(struct.ifsc_code, 'HDFC0001824') AS ifsc_code,
            COALESCE(struct.pan_number, 'PAN000055X') AS pan_number
        FROM public.staff_salary_payouts pay
        JOIN public.profiles s ON pay.staff_id = s.id
        LEFT JOIN public.staff_salary_structures struct ON pay.staff_id = struct.staff_id AND pay.school_id = struct.school_id
        WHERE pay.school_id = p_school_id
          AND (p_month_str IS NULL OR p_month_str = '' OR pay.month_str = p_month_str)
          AND (p_search IS NULL OR p_search = '' OR (
              s.full_name ILIKE '%' || p_search || '%' OR
              s.employee_id ILIKE '%' || p_search || '%' OR
              pay.payslip_number ILIKE '%' || p_search || '%'
          ))
    ),
    counted AS (
        SELECT COUNT(*) AS total_items FROM filtered
    ),
    sorted_page AS (
        SELECT * FROM filtered
        ORDER BY year DESC, month DESC, staff_name ASC
        LIMIT v_clean_size OFFSET v_offset
    )
    SELECT 
        (SELECT total_items FROM counted),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', sp.id,
                    'payslip_number', sp.payslip_number,
                    'month_str', sp.month_str,
                    'staff_name', sp.staff_name,
                    'employee_id', sp.employee_id,
                    'department', sp.department,
                    'role', sp.role,
                    'basic_pay', sp.basic_pay,
                    'gross_earnings', sp.gross_earnings,
                    'total_deductions', sp.total_deductions,
                    'net_pay', sp.net_pay,
                    'payment_status', sp.payment_status,
                    'payment_date', sp.payment_date,
                    'payment_mode', sp.payment_mode,
                    'transaction_reference', sp.transaction_reference,
                    'bank_name', sp.bank_name,
                    'account_number', sp.account_number,
                    'ifsc_code', sp.ifsc_code,
                    'pan_number', sp.pan_number
                )
            ), '[]'::jsonb
        ) INTO v_total_items, v_payslips
    FROM sorted_page sp;

    v_total_items := COALESCE(v_total_items, 0);
    IF v_total_items > 0 THEN
        v_total_pages := CEIL(v_total_items::numeric / v_clean_size);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'payslips', v_payslips,
        'pagination', jsonb_build_object(
            'page', v_clean_page,
            'page_size', v_clean_size,
            'total_items', v_total_items,
            'total_pages', v_total_pages
        )
    );
END;
$$;


-- ============================================================================
-- 26. FUNCTION: fn_list_all_staff_advances
-- Master list of staff salary advances with pagination and search.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_list_all_staff_advances(
    p_school_id UUID,
    p_search TEXT DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 15
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_clean_size INT := GREATEST(1, LEAST(100, COALESCE(p_page_size, 15)));
    v_offset INT := (v_clean_page - 1) * v_clean_size;
    v_total_items INT := 0;
    v_total_pages INT := 1;
    v_advances JSONB := '[]'::jsonb;
BEGIN
    WITH filtered AS (
        SELECT 
            adv.*,
            s.full_name AS staff_name, s.employee_id, s.department, s.role
        FROM public.staff_salary_advances adv
        JOIN public.profiles s ON adv.staff_id = s.id
        WHERE adv.school_id = p_school_id
          AND (p_search IS NULL OR p_search = '' OR (
              s.full_name ILIKE '%' || p_search || '%' OR
              s.employee_id ILIKE '%' || p_search || '%' OR
              adv.purpose_type ILIKE '%' || p_search || '%'
          ))
    ),
    counted AS (
        SELECT COUNT(*) AS total_items FROM filtered
    ),
    sorted_page AS (
        SELECT * FROM filtered
        ORDER BY created_at DESC
        LIMIT v_clean_size OFFSET v_offset
    )
    SELECT 
        (SELECT total_items FROM counted),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', sp.id,
                    'staff_id', sp.staff_id,
                    'staff_name', sp.staff_name,
                    'employee_id', sp.employee_id,
                    'department', sp.department,
                    'amount', sp.amount,
                    'purpose_type', sp.purpose_type,
                    'reason', sp.reason,
                    'repayment_months', sp.repayment_months,
                    'monthly_deduction', sp.monthly_deduction,
                    'amount_repaid', sp.amount_repaid,
                    'status', sp.status,
                    'disbursed_at', sp.disbursed_at,
                    'created_at', sp.created_at
                )
            ), '[]'::jsonb
        ) INTO v_total_items, v_advances
    FROM sorted_page sp;

    v_total_items := COALESCE(v_total_items, 0);
    IF v_total_items > 0 THEN
        v_total_pages := CEIL(v_total_items::numeric / v_clean_size);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'advances', v_advances,
        'pagination', jsonb_build_object(
            'page', v_clean_page,
            'page_size', v_clean_size,
            'total_items', v_total_items,
            'total_pages', v_total_pages
        )
    );
END;
$$;


-- ============================================================================
-- 27. FUNCTION: fn_list_student_fee_structures
-- Catalog of fee structure templates.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_list_student_fee_structures(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_structures JSONB;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s.id,
                'fee_name', s.fee_name,
                'fee_type', s.fee_type,
                'class_grade', s.class_grade,
                'billing_cycle', s.billing_cycle,
                'amount', s.amount,
                'description', s.description,
                'is_mandatory', s.is_mandatory,
                'status', s.status
            ) ORDER BY s.created_at ASC
        ), '[]'::jsonb
    ) INTO v_structures
    FROM public.student_fee_structures s
    WHERE s.school_id = p_school_id;

    RETURN jsonb_build_object(
        'success', true,
        'structures', v_structures
    );
END;
$$;


-- ============================================================================
-- 28. FUNCTION: fn_save_student_fee_structure
-- Create or update fee structure template.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_save_student_fee_structure(
    p_school_id UUID,
    p_structure_id UUID,
    p_fee_name TEXT,
    p_fee_type TEXT,
    p_class_grade TEXT,
    p_billing_cycle TEXT,
    p_amount NUMERIC(12,2),
    p_description TEXT DEFAULT NULL,
    p_is_mandatory BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID := p_structure_id;
BEGIN
    IF v_id IS NOT NULL THEN
        UPDATE public.student_fee_structures
        SET fee_name = p_fee_name,
            fee_type = p_fee_type,
            class_grade = p_class_grade,
            billing_cycle = p_billing_cycle,
            amount = p_amount,
            description = p_description,
            is_mandatory = p_is_mandatory,
            updated_at = NOW()
        WHERE id = v_id AND school_id = p_school_id;
    ELSE
        INSERT INTO public.student_fee_structures (
            school_id, fee_name, fee_type, class_grade,
            billing_cycle, amount, description, is_mandatory
        ) VALUES (
            p_school_id, p_fee_name, p_fee_type, p_class_grade,
            p_billing_cycle, p_amount, p_description, p_is_mandatory
        ) RETURNING id INTO v_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Fee structure saved successfully',
        'structure_id', v_id
    );
END;
$$;


-- ============================================================================
-- 29. FUNCTION: fn_delete_student_fee_structure
-- Deletes a fee structure template.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_delete_student_fee_structure(
    p_school_id UUID,
    p_structure_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.student_fee_structures
    WHERE id = p_structure_id AND school_id = p_school_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Fee structure deleted successfully'
    );
END;
$$;
