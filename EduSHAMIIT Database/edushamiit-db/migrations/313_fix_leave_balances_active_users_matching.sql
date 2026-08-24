-- ============================================================================
-- Migration 313: Fix Leave Balances Active Users Count & Global/Multi-School Support
-- Ensures leave balances count and users precisely match Active Users in User Management / Roles
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_leave_balances_paginated(
    p_school_id UUID DEFAULT NULL,
    p_academic_year VARCHAR DEFAULT '2026-2027',
    p_department VARCHAR DEFAULT 'ALL',
    p_role VARCHAR DEFAULT 'ALL',
    p_search VARCHAR DEFAULT '',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB AS $function$
DECLARE
    v_offset INT;
    v_search_pattern TEXT;
    v_total_employees INT;
    v_employees JSONB;
BEGIN
    v_offset := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);
    v_search_pattern := '%' || LOWER(TRIM(COALESCE(p_search, ''))) || '%';

    -- 1. Fast count matching ACTIVE employees
    SELECT COUNT(p.id)::INT
    INTO v_total_employees
    FROM public.profiles p
    WHERE (p_school_id IS NULL OR p.school_id = p_school_id OR p.school_id IS NULL)
      AND LOWER(COALESCE(p.status, 'active')) = 'active'
      AND (UPPER(COALESCE(p_department, 'ALL')) = 'ALL' OR UPPER(COALESCE(p.department, 'General')) = UPPER(p_department))
      AND (UPPER(COALESCE(p_role, 'ALL')) = 'ALL' OR UPPER(COALESCE(p.role, 'staff')) = UPPER(p_role))
      AND (
          p_search IS NULL OR p_search = '' OR
          LOWER(COALESCE(p.full_name, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(p.email, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(p.employee_id, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(p.department, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(p.role, '')) LIKE v_search_pattern
      );

    -- 2. Single-pass CTE joining active leave types and user balances
    WITH paginated_users AS (
        SELECT p.id, p.full_name, p.role, p.avatar_url,
               COALESCE(p.employee_id, 'EMP-' || SUBSTRING(p.id::TEXT FROM 1 FOR 4)) AS employee_code,
               COALESCE(p.department, 'General') AS department,
               COALESCE(p.designation, p.role) AS designation
        FROM public.profiles p
        WHERE (p_school_id IS NULL OR p.school_id = p_school_id OR p.school_id IS NULL)
          AND LOWER(COALESCE(p.status, 'active')) = 'active'
          AND (UPPER(COALESCE(p_department, 'ALL')) = 'ALL' OR UPPER(COALESCE(p.department, 'General')) = UPPER(p_department))
          AND (UPPER(COALESCE(p_role, 'ALL')) = 'ALL' OR UPPER(COALESCE(p.role, 'staff')) = UPPER(p_role))
          AND (
              p_search IS NULL OR p_search = '' OR
              LOWER(COALESCE(p.full_name, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(p.email, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(p.employee_id, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(p.department, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(p.role, '')) LIKE v_search_pattern
          )
        ORDER BY p.full_name ASC, p.id ASC
        LIMIT p_page_size OFFSET v_offset
    ),
    active_types AS (
        SELECT lt.id, lt.name, lt.code, lt.color_hex, lt.annual_entitlement
        FROM public.leave_types lt
        WHERE (p_school_id IS NULL OR lt.school_id = p_school_id OR lt.school_id IS NULL)
          AND lt.is_active = TRUE
        ORDER BY lt.name ASC, lt.id ASC
    ),
    user_balances AS (
        SELECT
            pu.id AS user_id,
            pu.full_name,
            pu.role,
            pu.avatar_url,
            pu.employee_code,
            pu.department,
            pu.designation,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'id', COALESCE(lb.id, gen_random_uuid()),
                        'leave_type_id', at.id,
                        'leave_type_name', at.name,
                        'leave_type_code', at.code,
                        'color_hex', COALESCE(at.color_hex, '#4F46E5'),
                        'allocated_days', COALESCE(lb.allocated_days, at.annual_entitlement),
                        'used_days', COALESCE(lb.used_days, 0.0),
                        'pending_days', COALESCE(lb.pending_days, 0.0),
                        'carried_forward_days', COALESCE(lb.carried_forward_days, 0.0),
                        'available_days', GREATEST(COALESCE(lb.allocated_days, at.annual_entitlement) - COALESCE(lb.used_days, 0.0) - COALESCE(lb.pending_days, 0.0), 0.0)
                    ) ORDER BY at.name ASC, at.id ASC
                ) FILTER (WHERE at.id IS NOT NULL),
                '[]'::jsonb
            ) AS balances,
            COALESCE(SUM(COALESCE(lb.allocated_days, at.annual_entitlement)), 0.0) AS total_allocated,
            COALESCE(SUM(COALESCE(lb.used_days, 0.0)), 0.0) AS total_used,
            COALESCE(SUM(GREATEST(COALESCE(lb.allocated_days, at.annual_entitlement) - COALESCE(lb.used_days, 0.0) - COALESCE(lb.pending_days, 0.0), 0.0)), 0.0) AS total_available
        FROM paginated_users pu
        CROSS JOIN active_types at
        LEFT JOIN public.leave_balances lb ON (lb.leave_type_id = at.id AND lb.user_id = pu.id AND lb.academic_year = p_academic_year)
        GROUP BY pu.id, pu.full_name, pu.role, pu.avatar_url, pu.employee_code, pu.department, pu.designation
        ORDER BY pu.full_name ASC, pu.id ASC
    )
    SELECT COALESCE(jsonb_agg(to_jsonb(ub)), '[]'::jsonb)
    INTO v_employees
    FROM user_balances ub;

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
$function$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Stored Procedure: fn_get_leave_dashboard_and_requests with Global & Multi-School Support
CREATE OR REPLACE FUNCTION public.fn_get_leave_dashboard_and_requests(
    p_school_id uuid DEFAULT NULL,
    p_user_id uuid DEFAULT NULL,
    p_user_type character varying DEFAULT 'ALL'::character varying,
    p_department character varying DEFAULT 'ALL'::character varying,
    p_status character varying DEFAULT 'ALL'::character varying,
    p_leave_type character varying DEFAULT 'ALL'::character varying,
    p_search character varying DEFAULT ''::character varying,
    p_from_date date DEFAULT NULL::date,
    p_to_date date DEFAULT NULL::date,
    p_page integer DEFAULT 1,
    p_page_size integer DEFAULT 10,
    p_manager_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_offset INT;
    v_total_requests INT := 0;
    v_approved_count INT := 0;
    v_pending_count INT := 0;
    v_rejected_count INT := 0;
    v_cancelled_count INT := 0;
    v_filtered_count INT := 0;
    v_search_pattern TEXT;
    v_requests JSONB;
    v_balance_summary JSONB;
    v_upcoming_leaves JSONB;
    v_user_role VARCHAR;
BEGIN
    v_offset := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);
    v_search_pattern := '%' || LOWER(TRIM(COALESCE(p_search, ''))) || '%';

    IF p_user_id IS NOT NULL THEN
        SELECT role INTO v_user_role FROM public.profiles WHERE id = p_user_id;
    END IF;

    -- 1. Total Counts for KPI
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
    WHERE (p_school_id IS NULL OR la.school_id = p_school_id OR la.school_id IS NULL)
      AND (p_manager_id IS NULL OR p.manager_id = p_manager_id);

    -- 2. Count Matching Filtered Records
    SELECT COUNT(*)::INT
    INTO v_filtered_count
    FROM public.leave_applications la
    JOIN public.profiles p ON p.id = la.applicant_id
    WHERE (p_school_id IS NULL OR la.school_id = p_school_id OR la.school_id IS NULL)
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
            COALESCE(p.employee_id, SUBSTRING(p.id::TEXT FROM 1 FOR 8)) AS employee_id,
            COALESCE(p.department, 'General') AS department,
            COALESCE(la.applicant_role, p.role) AS role,
            la.leave_type_id,
            la.leave_type,
            COALESCE(lt.color_hex, '#4F46E5') AS color_hex,
            la.start_date,
            la.end_date,
            COALESCE(la.billable_days, CASE WHEN la.half_day_type IN ('FIRST_HALF', 'SECOND_HALF') THEN 0.5 ELSE (la.end_date - la.start_date + 1)::NUMERIC(5, 1) END) AS days_count,
            (la.end_date - la.start_date + 1)::INT AS total_calendar_days,
            COALESCE(la.holidays_count, 0) AS holidays_count,
            COALESCE(la.overlap_days_count, 0) AS overlap_days_count,
            la.half_day_type,
            la.reason,
            la.status,
            la.attachment_url,
            la.contact_number,
            la.created_at,
            la.approved_at,
            la.approved_by,
            la.rejection_reason
        FROM public.leave_applications la
        JOIN public.profiles p ON p.id = la.applicant_id
        LEFT JOIN public.leave_types lt ON lt.id = la.leave_type_id
        WHERE (p_school_id IS NULL OR la.school_id = p_school_id OR la.school_id IS NULL)
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

    -- 4. Balance Summary (Scoped to p_user_id & user role)
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
            GREATEST(COALESCE(lb.allocated_days, lt.annual_entitlement) + COALESCE(lb.carried_forward_days, 0.0) - COALESCE(lb.used_days, 0.0) - COALESCE(lb.pending_days, 0.0), 0.0) AS available_days,
            lt.applicable_roles
        FROM public.leave_types lt
        LEFT JOIN public.leave_balances lb ON (lb.leave_type_id = lt.id AND (p_user_id IS NULL OR lb.user_id = p_user_id) AND lb.academic_year = '2026-2027')
        WHERE (p_school_id IS NULL OR lt.school_id = p_school_id OR lt.school_id IS NULL)
          AND lt.is_active = TRUE
          AND (
              p_user_id IS NULL
              OR v_user_role IS NULL
              OR lt.applicable_roles IS NULL 
              OR array_length(lt.applicable_roles, 1) IS NULL 
              OR array_length(lt.applicable_roles, 1) = 0
              OR 'all' = ANY(lt.applicable_roles)
              OR LOWER(v_user_role) = ANY(ARRAY(SELECT LOWER(r) FROM unnest(lt.applicable_roles) r))
          )
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
        WHERE (p_school_id IS NULL OR la.school_id = p_school_id OR la.school_id IS NULL)
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
                'pending_approvals', v_pending_count,
                'rejected_leaves', v_rejected_count,
                'cancelled_leaves', v_cancelled_count,
                'filtered_count', v_filtered_count
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
$function$;
