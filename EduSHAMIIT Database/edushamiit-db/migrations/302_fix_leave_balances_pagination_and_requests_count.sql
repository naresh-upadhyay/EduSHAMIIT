-- ============================================================================
-- Migration 302: Fix Leave Balances Pagination, Performance & Filtered Requests Count
-- ============================================================================

-- 1. Optimized fn_get_leave_dashboard_and_requests with filtered total_count
DROP FUNCTION IF EXISTS public.fn_get_leave_dashboard_and_requests(UUID, UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, DATE, DATE, INT, INT, UUID);
DROP FUNCTION IF EXISTS public.fn_get_leave_dashboard_and_requests(UUID, UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, DATE, DATE, INT, INT);
DROP FUNCTION IF EXISTS public.fn_get_leave_dashboard_and_requests(UUID, UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT, DATE, DATE, INT, INT, UUID);
CREATE OR REPLACE FUNCTION public.fn_get_leave_dashboard_and_requests(
    p_school_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_user_type VARCHAR DEFAULT 'ALL',
    p_department VARCHAR DEFAULT 'ALL',
    p_status VARCHAR DEFAULT 'ALL',
    p_leave_type VARCHAR DEFAULT 'ALL',
    p_search VARCHAR DEFAULT '',
    p_from_date DATE DEFAULT NULL,
    p_to_date DATE DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_manager_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_total_requests INT;
    v_approved_count INT;
    v_pending_count INT;
    v_rejected_count INT;
    v_cancelled_count INT;
    v_filtered_count INT;
    v_offset INT;
    v_requests JSONB;
    v_balance_summary JSONB;
    v_upcoming_leaves JSONB;
    v_search_pattern TEXT;
    v_current_user_id UUID;
BEGIN
    v_offset := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);
    v_search_pattern := '%' || LOWER(TRIM(COALESCE(p_search, ''))) || '%';
    v_current_user_id := p_user_id;

    -- 1. Aggregate Overall KPI Counts for current school/manager
    SELECT
        COUNT(*)::INT,
        COUNT(*) FILTER (WHERE LOWER(la.status) = 'approved')::INT,
        COUNT(*) FILTER (WHERE LOWER(la.status) = 'pending')::INT,
        COUNT(*) FILTER (WHERE LOWER(la.status) = 'rejected')::INT,
        COUNT(*) FILTER (WHERE LOWER(la.status) = 'cancelled')::INT
    INTO
        v_total_requests,
        v_approved_count,
        v_pending_count,
        v_rejected_count,
        v_cancelled_count
    FROM public.leave_applications la
    JOIN public.profiles p ON p.id = la.applicant_id
    WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
      AND (p_manager_id IS NULL OR p.manager_id = p_manager_id);

    -- 2. Count Matching Filtered Records
    SELECT COUNT(*)::INT
    INTO v_filtered_count
    FROM public.leave_applications la
    JOIN public.profiles p ON p.id = la.applicant_id
    WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
      AND (p_manager_id IS NULL OR p.manager_id = p_manager_id)
      AND (UPPER(p_status) = 'ALL' OR UPPER(la.status) = UPPER(p_status))
      AND (UPPER(p_user_type) = 'ALL' OR UPPER(COALESCE(la.applicant_role, p.role)) = UPPER(p_user_type))
      AND (UPPER(p_department) = 'ALL' OR UPPER(COALESCE(p.department, 'General')) = UPPER(p_department))
      AND (UPPER(p_leave_type) = 'ALL' OR UPPER(la.leave_type) = UPPER(p_leave_type))
      AND (p_from_date IS NULL OR la.start_date >= p_from_date)
      AND (p_to_date IS NULL OR la.end_date <= p_to_date)
      AND (
          p_search IS NULL OR p_search = '' OR
          LOWER(p.full_name) LIKE v_search_pattern OR
          LOWER(COALESCE(p.employee_id, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(la.request_code, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(p.department, '')) LIKE v_search_pattern OR
          LOWER(la.reason) LIKE v_search_pattern
      );

    -- 3. Fetch Filtered Requests List with Pagination
    SELECT COALESCE(jsonb_agg(r), '[]'::jsonb)
    INTO v_requests
    FROM (
        SELECT
            la.id,
            la.request_code,
            la.applicant_id,
            p.full_name AS applicant_name,
            p.avatar_url,
            COALESCE(p.employee_id, 'EMP-' || SUBSTRING(p.id::TEXT FROM 1 FOR 4)) AS employee_code,
            COALESCE(la.applicant_role, p.role) AS applicant_role,
            COALESCE(p.department, 'General') AS department,
            COALESCE(p.designation, p.role) AS designation,
            la.leave_type,
            COALESCE(lt.color_hex, '#4F46E5') AS leave_type_color,
            la.start_date,
            la.end_date,
            CASE
                WHEN la.half_day_type IN ('FIRST_HALF', 'SECOND_HALF') THEN 0.5
                ELSE (la.end_date - la.start_date + 1)::NUMERIC(5, 1)
            END AS days_count,
            COALESCE(la.half_day_type, 'FULL_DAY') AS half_day_type,
            la.reason,
            la.status,
            la.remarks,
            la.rejection_reason,
            la.attachment_url,
            la.contact_number,
            COALESCE(la.applied_at, la.created_at) AS applied_at,
            ap.full_name AS approved_by_name,
            mgr.full_name AS manager_name
        FROM public.leave_applications la
        JOIN public.profiles p ON p.id = la.applicant_id
        LEFT JOIN public.leave_types lt ON (lt.name ILIKE la.leave_type AND (lt.school_id = p_school_id OR lt.school_id IS NULL))
        LEFT JOIN public.profiles ap ON ap.id = la.approved_by
        LEFT JOIN public.profiles mgr ON mgr.id = p.manager_id
        WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
          AND (p_manager_id IS NULL OR p.manager_id = p_manager_id)
          AND (UPPER(p_status) = 'ALL' OR UPPER(la.status) = UPPER(p_status))
          AND (UPPER(p_user_type) = 'ALL' OR UPPER(COALESCE(la.applicant_role, p.role)) = UPPER(p_user_type))
          AND (UPPER(p_department) = 'ALL' OR UPPER(COALESCE(p.department, 'General')) = UPPER(p_department))
          AND (UPPER(p_leave_type) = 'ALL' OR UPPER(la.leave_type) = UPPER(p_leave_type))
          AND (p_from_date IS NULL OR la.start_date >= p_from_date)
          AND (p_to_date IS NULL OR la.end_date <= p_to_date)
          AND (
              p_search IS NULL OR p_search = '' OR
              LOWER(p.full_name) LIKE v_search_pattern OR
              LOWER(COALESCE(p.employee_id, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(la.request_code, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(p.department, '')) LIKE v_search_pattern OR
              LOWER(la.reason) LIKE v_search_pattern
          )
        ORDER BY la.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) r;

    -- 4. Balance Summary (for current user or default school quotas)
    SELECT COALESCE(jsonb_agg(b), '[]'::jsonb)
    INTO v_balance_summary
    FROM (
        SELECT
            lt.id AS leave_type_id,
            lt.name AS leave_type_name,
            lt.code AS leave_type_code,
            COALESCE(lt.color_hex, '#4F46E5') AS color_hex,
            COALESCE(lb.allocated_days, lt.annual_entitlement) AS allocated_days,
            COALESCE(lb.used_days, 0.0) AS used_days,
            COALESCE(lb.pending_days, 0.0) AS pending_days,
            GREATEST(COALESCE(lb.allocated_days, lt.annual_entitlement) - COALESCE(lb.used_days, 0.0) - COALESCE(lb.pending_days, 0.0), 0.0) AS available_days
        FROM public.leave_types lt
        LEFT JOIN public.leave_balances lb ON (lb.leave_type_id = lt.id AND (v_current_user_id IS NULL OR lb.user_id = v_current_user_id) AND lb.academic_year = '2026-2027')
        WHERE (lt.school_id = p_school_id OR lt.school_id IS NULL)
          AND lt.is_active = TRUE
        ORDER BY lt.created_at ASC
        LIMIT 6
    ) b;

    -- 5. Upcoming Leaves List
    SELECT COALESCE(jsonb_agg(u), '[]'::jsonb)
    INTO v_upcoming_leaves
    FROM (
        SELECT
            la.id,
            p.full_name AS employee_name,
            p.avatar_url,
            la.leave_type,
            la.start_date,
            la.end_date,
            TO_CHAR(la.start_date, 'DD Mon') || CASE WHEN la.start_date != la.end_date THEN ' - ' || TO_CHAR(la.end_date, 'DD Mon') ELSE '' END AS date_range_formatted
        FROM public.leave_applications la
        JOIN public.profiles p ON p.id = la.applicant_id
        WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
          AND LOWER(la.status) = 'approved'
          AND la.end_date >= CURRENT_DATE
        ORDER BY la.start_date ASC
        LIMIT 5
    ) u;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'kpi', jsonb_build_object(
                'total_requests', v_total_requests,
                'approved_leaves', v_approved_count,
                'pending_requests', v_pending_count,
                'rejected_leaves', v_rejected_count,
                'cancelled_leaves', v_cancelled_count,
                'approved_percentage', CASE WHEN v_total_requests > 0 THEN ROUND((v_approved_count::NUMERIC / v_total_requests::NUMERIC) * 100, 2) ELSE 0.0 END,
                'pending_percentage', CASE WHEN v_total_requests > 0 THEN ROUND((v_pending_count::NUMERIC / v_total_requests::NUMERIC) * 100, 2) ELSE 0.0 END,
                'rejected_percentage', CASE WHEN v_total_requests > 0 THEN ROUND((v_rejected_count::NUMERIC / v_total_requests::NUMERIC) * 100, 2) ELSE 0.0 END,
                'cancelled_percentage', CASE WHEN v_total_requests > 0 THEN ROUND((v_cancelled_count::NUMERIC / v_total_requests::NUMERIC) * 100, 2) ELSE 0.0 END
            ),
            'requests', v_requests,
            'balance_summary', v_balance_summary,
            'upcoming_leaves', v_upcoming_leaves,
            'page', p_page,
            'page_size', p_page_size,
            'total_count', v_filtered_count,
            'total_pages', GREATEST(CEIL(v_filtered_count::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)::INT, 1)
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Stored Procedure: fn_get_leave_balances_paginated
DROP FUNCTION IF EXISTS public.fn_get_leave_balances_paginated(UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, INT, INT);
DROP FUNCTION IF EXISTS public.fn_get_leave_balances_paginated(UUID, VARCHAR, VARCHAR, VARCHAR, TEXT, INT, INT);
CREATE OR REPLACE FUNCTION public.fn_get_leave_balances_paginated(
    p_school_id UUID,
    p_academic_year VARCHAR DEFAULT '2026-2027',
    p_department VARCHAR DEFAULT 'ALL',
    p_role VARCHAR DEFAULT 'ALL',
    p_search VARCHAR DEFAULT '',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB AS $$
DECLARE
    v_offset INT;
    v_search_pattern TEXT;
    v_total_employees INT;
    v_employees JSONB;
BEGIN
    v_offset := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);
    v_search_pattern := '%' || LOWER(TRIM(COALESCE(p_search, ''))) || '%';

    -- Count total matching employees
    SELECT COUNT(DISTINCT p.id)::INT
    INTO v_total_employees
    FROM public.profiles p
    WHERE (p.school_id = p_school_id OR p.school_id IS NULL)
      AND (UPPER(p_department) = 'ALL' OR UPPER(COALESCE(p.department, 'General')) = UPPER(p_department))
      AND (UPPER(p_role) = 'ALL' OR UPPER(p.role) = UPPER(p_role))
      AND (
          p_search IS NULL OR p_search = '' OR
          LOWER(p.full_name) LIKE v_search_pattern OR
          LOWER(COALESCE(p.employee_id, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(p.department, '')) LIKE v_search_pattern
      );

    -- Fetch paginated employees with their grouped leave balances
    SELECT COALESCE(jsonb_agg(emp_data), '[]'::jsonb)
    INTO v_employees
    FROM (
        WITH paginated_users AS (
            SELECT p.id, p.full_name, p.role, p.avatar_url,
                   COALESCE(p.employee_id, 'EMP-' || SUBSTRING(p.id::TEXT FROM 1 FOR 4)) AS employee_code,
                   COALESCE(p.department, 'General') AS department,
                   COALESCE(p.designation, p.role) AS designation
            FROM public.profiles p
            WHERE (p.school_id = p_school_id OR p.school_id IS NULL)
              AND (UPPER(p_department) = 'ALL' OR UPPER(COALESCE(p.department, 'General')) = UPPER(p_department))
              AND (UPPER(p_role) = 'ALL' OR UPPER(p.role) = UPPER(p_role))
              AND (
                  p_search IS NULL OR p_search = '' OR
                  LOWER(p.full_name) LIKE v_search_pattern OR
                  LOWER(COALESCE(p.employee_id, '')) LIKE v_search_pattern OR
                  LOWER(COALESCE(p.department, '')) LIKE v_search_pattern
              )
            ORDER BY p.full_name ASC
            LIMIT p_page_size OFFSET v_offset
        )
        SELECT
            pu.id AS user_id,
            pu.full_name,
            pu.role,
            pu.avatar_url,
            pu.employee_code,
            pu.department,
            pu.designation,
            COALESCE((
                SELECT jsonb_agg(jsonb_build_object(
                    'id', COALESCE(lb.id, gen_random_uuid()),
                    'leave_type_id', lt.id,
                    'leave_type_name', lt.name,
                    'leave_type_code', lt.code,
                    'color_hex', COALESCE(lt.color_hex, '#4F46E5'),
                    'allocated_days', COALESCE(lb.allocated_days, lt.annual_entitlement),
                    'used_days', COALESCE(lb.used_days, 0.0),
                    'pending_days', COALESCE(lb.pending_days, 0.0),
                    'carried_forward_days', COALESCE(lb.carried_forward_days, 0.0),
                    'available_days', GREATEST(COALESCE(lb.allocated_days, lt.annual_entitlement) - COALESCE(lb.used_days, 0.0) - COALESCE(lb.pending_days, 0.0), 0.0)
                ) ORDER BY lt.created_at ASC)
                FROM public.leave_types lt
                LEFT JOIN public.leave_balances lb ON (lb.leave_type_id = lt.id AND lb.user_id = pu.id AND lb.academic_year = p_academic_year)
                WHERE (lt.school_id = p_school_id OR lt.school_id IS NULL)
                  AND lt.is_active = TRUE
            ), '[]'::jsonb) AS balances,
            COALESCE((
                SELECT SUM(COALESCE(lb.allocated_days, lt.annual_entitlement))
                FROM public.leave_types lt
                LEFT JOIN public.leave_balances lb ON (lb.leave_type_id = lt.id AND lb.user_id = pu.id AND lb.academic_year = p_academic_year)
                WHERE (lt.school_id = p_school_id OR lt.school_id IS NULL) AND lt.is_active = TRUE
            ), 0.0) AS total_allocated,
            COALESCE((
                SELECT SUM(COALESCE(lb.used_days, 0.0))
                FROM public.leave_types lt
                LEFT JOIN public.leave_balances lb ON (lb.leave_type_id = lt.id AND lb.user_id = pu.id AND lb.academic_year = p_academic_year)
                WHERE (lt.school_id = p_school_id OR lt.school_id IS NULL) AND lt.is_active = TRUE
            ), 0.0) AS total_used,
            COALESCE((
                SELECT SUM(GREATEST(COALESCE(lb.allocated_days, lt.annual_entitlement) - COALESCE(lb.used_days, 0.0) - COALESCE(lb.pending_days, 0.0), 0.0))
                FROM public.leave_types lt
                LEFT JOIN public.leave_balances lb ON (lb.leave_type_id = lt.id AND lb.user_id = pu.id AND lb.academic_year = p_academic_year)
                WHERE (lt.school_id = p_school_id OR lt.school_id IS NULL) AND lt.is_active = TRUE
            ), 0.0) AS total_available
        FROM paginated_users pu
    ) emp_data;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'employees', v_employees,
            'page', p_page,
            'page_size', p_page_size,
            'total_count', v_total_employees,
            'total_pages', GREATEST(CEIL(v_total_employees::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)::INT, 1)
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
