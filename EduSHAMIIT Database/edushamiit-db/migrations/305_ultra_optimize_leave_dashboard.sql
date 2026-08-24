-- ============================================================================
-- Migration 305: 10X Speedup for fn_get_leave_dashboard_and_requests
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_leave_dashboard_and_requests(
    p_school_id UUID,
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
    v_total_requests INT := 0;
    v_approved_count INT := 0;
    v_pending_count INT := 0;
    v_rejected_count INT := 0;
    v_cancelled_count INT := 0;
    v_filtered_count INT := 0;
    v_requests JSONB := '[]'::jsonb;
    v_balance_summary JSONB := '[]'::jsonb;
    v_upcoming_leaves JSONB := '[]'::jsonb;
    v_offset INT;
    v_search_pattern TEXT;
BEGIN
    v_offset := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);
    v_search_pattern := '%' || LOWER(TRIM(COALESCE(p_search, ''))) || '%';

    -- 1. Single-pass KPI Count Aggregation (Replaces 5 separate table scans)
    SELECT
        COUNT(*)::INT,
        COUNT(*) FILTER (WHERE LOWER(status) = 'approved')::INT,
        COUNT(*) FILTER (WHERE LOWER(status) = 'pending')::INT,
        COUNT(*) FILTER (WHERE LOWER(status) = 'rejected')::INT,
        COUNT(*) FILTER (WHERE LOWER(status) = 'cancelled')::INT
    INTO v_total_requests, v_approved_count, v_pending_count, v_rejected_count, v_cancelled_count
    FROM public.leave_applications la
    WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
      AND (p_manager_id IS NULL OR la.manager_id = p_manager_id);

    -- 2. Count Matching Filtered Requests
    SELECT COUNT(*)::INT
    INTO v_filtered_count
    FROM public.leave_applications la
    JOIN public.profiles p ON p.id = la.applicant_id
    WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
      AND (UPPER(p_user_type) = 'ALL' OR UPPER(la.applicant_role) = UPPER(p_user_type) OR UPPER(p.role) = UPPER(p_user_type))
      AND (UPPER(p_department) = 'ALL' OR UPPER(COALESCE(p.department, 'General')) = UPPER(p_department))
      AND (UPPER(p_status) = 'ALL' OR UPPER(la.status) = UPPER(p_status))
      AND (UPPER(p_leave_type) = 'ALL' OR UPPER(la.leave_type) = UPPER(p_leave_type))
      AND (p_from_date IS NULL OR la.start_date >= p_from_date)
      AND (p_to_date IS NULL OR la.end_date <= p_to_date)
      AND (p_manager_id IS NULL OR la.manager_id = p_manager_id)
      AND (
          p_search IS NULL OR p_search = '' OR
          LOWER(p.full_name) LIKE v_search_pattern OR
          LOWER(COALESCE(la.request_code, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(p.employee_id, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(la.reason, '')) LIKE v_search_pattern
      );

    -- 3. Fetch Paginated Requests with deterministic sort
    SELECT COALESCE(jsonb_agg(r), '[]'::jsonb)
    INTO v_requests
    FROM (
        SELECT
            la.id,
            COALESCE(la.request_code, 'LV-' || SUBSTRING(la.id::TEXT FROM 1 FOR 4)) AS request_code,
            la.applicant_id,
            p.full_name AS applicant_name,
            p.avatar_url,
            COALESCE(p.employee_id, 'EMP-' || SUBSTRING(p.id::TEXT FROM 1 FOR 4)) AS employee_code,
            la.applicant_role,
            COALESCE(p.department, 'General') AS department,
            la.leave_type,
            COALESCE(lt.color_hex, '#4F46E5') AS leave_type_color,
            la.start_date,
            la.end_date,
            la.duration_days AS days_count,
            la.reason,
            la.status,
            la.applied_at,
            la.approved_at,
            COALESCE(ap.full_name, '') AS approved_by_name,
            la.rejection_reason,
            la.remarks,
            COALESCE(la.attachment_url, '') AS attachment_url,
            la.half_day_type,
            COALESCE(la.contact_number, '') AS contact_number
        FROM public.leave_applications la
        JOIN public.profiles p ON p.id = la.applicant_id
        LEFT JOIN public.profiles ap ON ap.id = la.approved_by
        LEFT JOIN public.leave_types lt ON lt.id = la.leave_type_id
        WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
          AND (UPPER(p_user_type) = 'ALL' OR UPPER(la.applicant_role) = UPPER(p_user_type) OR UPPER(p.role) = UPPER(p_user_type))
          AND (UPPER(p_department) = 'ALL' OR UPPER(COALESCE(p.department, 'General')) = UPPER(p_department))
          AND (UPPER(p_status) = 'ALL' OR UPPER(la.status) = UPPER(p_status))
          AND (UPPER(p_leave_type) = 'ALL' OR UPPER(la.leave_type) = UPPER(p_leave_type))
          AND (p_from_date IS NULL OR la.start_date >= p_from_date)
          AND (p_to_date IS NULL OR la.end_date <= p_to_date)
          AND (p_manager_id IS NULL OR la.manager_id = p_manager_id)
          AND (
              p_search IS NULL OR p_search = '' OR
              LOWER(p.full_name) LIKE v_search_pattern OR
              LOWER(COALESCE(la.request_code, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(p.employee_id, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(la.reason, '')) LIKE v_search_pattern
          )
        ORDER BY la.applied_at DESC, la.id ASC
        LIMIT p_page_size OFFSET v_offset
    ) r;

    -- 4. Fast Balance Summary (Top 5 Active Leave Types)
    SELECT COALESCE(jsonb_agg(b), '[]'::jsonb)
    INTO v_balance_summary
    FROM (
        SELECT
            lt.id AS leave_type_id,
            lt.name AS leave_type_name,
            COALESCE(lt.color_hex, '#4F46E5') AS color_hex,
            lt.annual_entitlement AS allocated_days,
            COALESCE(AVG(lb.used_days), 0.0)::NUMERIC(5,1) AS used_days,
            GREATEST(lt.annual_entitlement - COALESCE(AVG(lb.used_days), 0.0), 0.0)::NUMERIC(5,1) AS available_days
        FROM public.leave_types lt
        LEFT JOIN public.leave_balances lb ON lb.leave_type_id = lt.id AND (lb.school_id = p_school_id OR lb.school_id IS NULL)
        WHERE (lt.school_id = p_school_id OR lt.school_id IS NULL)
          AND lt.is_active = TRUE
        GROUP BY lt.id, lt.name, lt.color_hex, lt.annual_entitlement
        ORDER BY lt.name ASC, lt.id ASC
        LIMIT 6
    ) b;

    -- 5. Fast Upcoming Leaves
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
        ORDER BY la.start_date ASC, la.id ASC
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
