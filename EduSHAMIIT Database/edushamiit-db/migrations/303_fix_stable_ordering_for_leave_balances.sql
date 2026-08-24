-- ============================================================================
-- Migration 303: Fix 100% Deterministic Stable Ordering for Leave Balances & Types
-- ============================================================================

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

    -- Fetch paginated employees with their grouped leave balances in strictly deterministic order
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
            ORDER BY p.full_name ASC, p.id ASC
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
                ) ORDER BY lt.name ASC, lt.id ASC)
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
        ORDER BY pu.full_name ASC, pu.id ASC
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
