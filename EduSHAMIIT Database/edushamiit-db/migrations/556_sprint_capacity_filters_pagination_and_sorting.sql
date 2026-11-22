-- 556_sprint_capacity_filters_pagination_and_sorting.sql
-- Enterprise Sprint Capacity Management: Enhanced Filtering, Sorting & Pagination for DB/API

DROP FUNCTION IF EXISTS public.sp_get_sprint_capacity_dashboard(UUID, UUID, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS public.sp_get_sprint_capacity_dashboard(UUID, UUID, VARCHAR, VARCHAR, INT, INT, VARCHAR, VARCHAR, VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION public.sp_get_sprint_capacity_dashboard(
    p_school_id UUID,
    p_sprint_id UUID DEFAULT NULL,
    p_team_name VARCHAR DEFAULT 'Digital Campus Team',
    p_search VARCHAR DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_limit INT DEFAULT NULL,
    p_sort_by VARCHAR DEFAULT 'name',
    p_sort_order VARCHAR DEFAULT 'asc',
    p_role_filter VARCHAR DEFAULT NULL,
    p_status_filter VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sprint_id UUID := p_sprint_id;
    v_sprint_row RECORD;
    v_team_name VARCHAR := COALESCE(NULLIF(p_team_name, ''), 'Digital Campus Team');
    v_total_capacity NUMERIC(10,2) := 280.0;
    v_planned_work NUMERIC(10,2) := 257.0;
    v_actual_work NUMERIC(10,2) := 217.0;
    v_remaining_capacity NUMERIC(10,2) := 23.0;
    v_utilization_pct NUMERIC(5,2) := 91.8;
    v_over_allocation NUMERIC(10,2) := 0.0;
    v_team_members_count INT := 0;
    v_total_filtered_count INT := 0;
    v_overloaded_count INT := 0;
    v_members_list JSONB := '[]'::jsonb;
    v_daily_chart JSONB := '[]'::jsonb;
    v_teams_list JSONB := '[]'::jsonb;
    v_all_sprints_list JSONB := '[]'::jsonb;
    v_insights JSONB := '[]'::jsonb;
    v_page INT := GREATEST(COALESCE(p_page, 1), 1);
    v_limit INT := p_limit;
    v_offset INT := 0;
    v_total_pages INT := 1;
BEGIN
    -- 1. Identify Target Sprint
    IF v_sprint_id IS NULL THEN
        SELECT id INTO v_sprint_id
        FROM public.work_sprints
        WHERE school_id = p_school_id AND status = 'ACTIVE'
        ORDER BY start_date DESC LIMIT 1;

        IF v_sprint_id IS NULL THEN
            SELECT id INTO v_sprint_id
            FROM public.work_sprints
            WHERE school_id = p_school_id
            ORDER BY start_date DESC LIMIT 1;
        END IF;
    END IF;

    -- Fetch Sprint Details
    SELECT s.*,
           to_char(s.start_date, 'Mon DD, YYYY') AS start_date_fmt,
           to_char(s.end_date, 'Mon DD, YYYY') AS end_date_fmt,
           b.name AS board_name
    INTO v_sprint_row
    FROM public.work_sprints s
    LEFT JOIN public.work_boards b ON b.id = s.board_id
    WHERE s.id = v_sprint_id AND s.school_id = p_school_id;

    -- 2. Fetch Teams List for Searchable Dropdown
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', t.id,
            'name', t.name,
            'department', t.department,
            'icon', t.icon,
            'is_selected', (t.name = v_team_name)
        ) ORDER BY t.name ASC
    ) INTO v_teams_list
    FROM public.work_teams t
    WHERE t.school_id = p_school_id AND t.is_active = TRUE;

    IF v_teams_list IS NULL THEN
        v_teams_list := '[]'::jsonb;
    END IF;

    -- Fetch Sprints List for Quick Sprint Filter Dropdown
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', s.id,
            'name', s.name,
            'status', s.status,
            'start_date', to_char(s.start_date, 'Mon DD, YYYY'),
            'end_date', to_char(s.end_date, 'Mon DD, YYYY'),
            'is_selected', (s.id = v_sprint_id)
        ) ORDER BY s.start_date DESC
    ) INTO v_all_sprints_list
    FROM public.work_sprints s
    WHERE s.school_id = p_school_id;

    IF v_all_sprints_list IS NULL THEN
        v_all_sprints_list := '[]'::jsonb;
    END IF;

    -- 3. Calculate Aggregated Team Capacity Record / KPIs from DB
    SELECT COUNT(*) INTO v_team_members_count
    FROM public.sprint_members sm
    WHERE sm.sprint_id = v_sprint_id
      AND (v_team_name = 'All Teams' OR sm.team_name = v_team_name);

    SELECT
        COALESCE(SUM(sm.available_hours), 0.0),
        COALESCE(SUM(sm.planned_hours), 0.0),
        COALESCE(SUM(sm.actual_hours), 0.0),
        COALESCE(SUM(sm.remaining_hours), 0.0),
        COUNT(*) FILTER (WHERE sm.workload_status = 'Overloaded' OR (sm.available_hours > 0 AND sm.planned_hours > sm.available_hours))
    INTO
        v_total_capacity,
        v_planned_work,
        v_actual_work,
        v_remaining_capacity,
        v_overloaded_count
    FROM public.sprint_members sm
    WHERE sm.sprint_id = v_sprint_id
      AND (v_team_name = 'All Teams' OR sm.team_name = v_team_name);

    IF v_total_capacity > 0 THEN
        v_utilization_pct := ROUND((v_planned_work / v_total_capacity) * 100, 1);
        v_over_allocation := GREATEST(v_planned_work - v_total_capacity, 0.0);
    ELSE
        SELECT
            COALESCE(stc.total_capacity_hours, 280.0),
            COALESCE(stc.planned_work_hours, 257.0),
            COALESCE(stc.actual_work_hours, 217.0),
            COALESCE(stc.remaining_capacity_hours, 23.0),
            COALESCE(stc.utilization_pct, 91.8),
            COALESCE(stc.over_allocation_hours, 0.0),
            COALESCE(stc.overloaded_members_count, 1)
        INTO
            v_total_capacity,
            v_planned_work,
            v_actual_work,
            v_remaining_capacity,
            v_utilization_pct,
            v_over_allocation,
            v_overloaded_count
        FROM public.sprint_team_capacities stc
        WHERE stc.sprint_id = v_sprint_id AND stc.team_name = v_team_name;
    END IF;

    -- 4. Count Filtered Members for Pagination
    SELECT COUNT(*) INTO v_total_filtered_count
    FROM public.sprint_members sm
    JOIN public.profiles p ON p.id = sm.user_id
    WHERE sm.sprint_id = v_sprint_id
      AND (v_team_name = 'All Teams' OR sm.team_name = v_team_name)
      AND (p_search IS NULL OR p_search = '' OR p.full_name ILIKE '%' || p_search || '%' OR p.email ILIKE '%' || p_search || '%' OR sm.role ILIKE '%' || p_search || '%')
      AND (p_role_filter IS NULL OR p_role_filter = '' OR p_role_filter = 'All' OR sm.role = p_role_filter)
      AND (p_status_filter IS NULL OR p_status_filter = '' OR p_status_filter = 'All' OR UPPER(sm.workload_status) = UPPER(p_status_filter));

    -- Calculate total pages and offset
    IF v_limit IS NOT NULL AND v_limit > 0 THEN
        v_total_pages := GREATEST(CEIL(v_total_filtered_count::NUMERIC / v_limit)::INT, 1);
        v_offset := (v_page - 1) * v_limit;
    ELSE
        v_total_pages := 1;
        v_offset := 0;
    END IF;

    -- 5. Fetch Filtered, Sorted and Paginated Members
    SELECT jsonb_agg(member_obj) INTO v_members_list
    FROM (
        SELECT jsonb_build_object(
            'id', sm.id,
            'user_id', p.id,
            'full_name', p.full_name,
            'avatar_url', p.avatar_url,
            'email', p.email,
            'role', sm.role,
            'department', COALESCE(p.department, 'Information Tech'),
            'capacity_hours', COALESCE(sm.available_hours, 40.0),
            'planned_hours', COALESCE(sm.planned_hours, 0.0),
            'actual_hours', COALESCE(sm.actual_hours, 0.0),
            'remaining_hours', COALESCE(sm.remaining_hours, 0.0),
            'utilization_pct', CASE WHEN COALESCE(sm.available_hours, 40.0) > 0
                THEN ROUND((COALESCE(sm.planned_hours, 0.0) / sm.available_hours) * 100, 1)
                ELSE 0.0 END,
            'work_items_count', COALESCE(sm.work_items_count, 0),
            'status', COALESCE(sm.workload_status, 'Balanced'),
            'daily_working_hours', COALESCE(sm.daily_working_hours, 8.0),
            'working_days', COALESCE(sm.working_days, 5),
            'override_value', sm.override_value,
            'override_reason', sm.override_reason,
            'notes', sm.notes
        ) AS member_obj
        FROM public.sprint_members sm
        JOIN public.profiles p ON p.id = sm.user_id
        WHERE sm.sprint_id = v_sprint_id
          AND (v_team_name = 'All Teams' OR sm.team_name = v_team_name)
          AND (p_search IS NULL OR p_search = '' OR p.full_name ILIKE '%' || p_search || '%' OR p.email ILIKE '%' || p_search || '%' OR sm.role ILIKE '%' || p_search || '%')
          AND (p_role_filter IS NULL OR p_role_filter = '' OR p_role_filter = 'All' OR sm.role = p_role_filter)
          AND (p_status_filter IS NULL OR p_status_filter = '' OR p_status_filter = 'All' OR UPPER(sm.workload_status) = UPPER(p_status_filter))
        ORDER BY
            CASE WHEN LOWER(p_sort_by) = 'name' AND LOWER(p_sort_order) = 'desc' THEN p.full_name END DESC,
            CASE WHEN LOWER(p_sort_by) = 'name' AND LOWER(p_sort_order) != 'desc' THEN p.full_name END ASC,
            CASE WHEN LOWER(p_sort_by) = 'role' AND LOWER(p_sort_order) = 'desc' THEN sm.role END DESC,
            CASE WHEN LOWER(p_sort_by) = 'role' AND LOWER(p_sort_order) != 'desc' THEN sm.role END ASC,
            CASE WHEN LOWER(p_sort_by) = 'capacity' AND LOWER(p_sort_order) = 'desc' THEN sm.available_hours END DESC,
            CASE WHEN LOWER(p_sort_by) = 'capacity' AND LOWER(p_sort_order) != 'desc' THEN sm.available_hours END ASC,
            CASE WHEN LOWER(p_sort_by) = 'planned' AND LOWER(p_sort_order) = 'desc' THEN sm.planned_hours END DESC,
            CASE WHEN LOWER(p_sort_by) = 'planned' AND LOWER(p_sort_order) != 'desc' THEN sm.planned_hours END ASC,
            CASE WHEN LOWER(p_sort_by) = 'actual' AND LOWER(p_sort_order) = 'desc' THEN sm.actual_hours END DESC,
            CASE WHEN LOWER(p_sort_by) = 'actual' AND LOWER(p_sort_order) != 'desc' THEN sm.actual_hours END ASC,
            CASE WHEN LOWER(p_sort_by) = 'remaining' AND LOWER(p_sort_order) = 'desc' THEN sm.remaining_hours END DESC,
            CASE WHEN LOWER(p_sort_by) = 'remaining' AND LOWER(p_sort_order) != 'desc' THEN sm.remaining_hours END ASC,
            CASE WHEN LOWER(p_sort_by) = 'utilization' AND LOWER(p_sort_order) = 'desc' THEN (COALESCE(sm.planned_hours, 0.0) / NULLIF(sm.available_hours, 0)) END DESC,
            CASE WHEN LOWER(p_sort_by) = 'utilization' AND LOWER(p_sort_order) != 'desc' THEN (COALESCE(sm.planned_hours, 0.0) / NULLIF(sm.available_hours, 0)) END ASC,
            CASE WHEN LOWER(p_sort_by) = 'work_items' AND LOWER(p_sort_order) = 'desc' THEN sm.work_items_count END DESC,
            CASE WHEN LOWER(p_sort_by) = 'work_items' AND LOWER(p_sort_order) != 'desc' THEN sm.work_items_count END ASC,
            CASE WHEN LOWER(p_sort_by) = 'status' AND LOWER(p_sort_order) = 'desc' THEN sm.workload_status END DESC,
            CASE WHEN LOWER(p_sort_by) = 'status' AND LOWER(p_sort_order) != 'desc' THEN sm.workload_status END ASC,
            p.full_name ASC
        LIMIT v_limit OFFSET v_offset
    ) sub;

    IF v_members_list IS NULL THEN
        v_members_list := '[]'::jsonb;
    END IF;

    -- 6. Fetch Daily Capacity Breakdown Points
    SELECT jsonb_agg(
        jsonb_build_object(
            'date_fmt', sdc.date_fmt,
            'full_date', sdc.full_date,
            'capacity_hours', sdc.capacity_hours,
            'planned_hours', sdc.planned_hours,
            'actual_hours', sdc.actual_hours
        ) ORDER BY sdc.sort_order ASC
    ) INTO v_daily_chart
    FROM public.sprint_daily_capacities sdc
    WHERE sdc.sprint_id = v_sprint_id
      AND (v_team_name = 'All Teams' OR sdc.team_name = v_team_name);

    IF v_daily_chart IS NULL THEN
        v_daily_chart := '[]'::jsonb;
    END IF;

    -- 7. Construct Smart Recommendation Insights
    v_insights := jsonb_build_array(
        jsonb_build_object(
            'type', 'SUCCESS',
            'icon', 'check_circle',
            'text', 'Team is within capacity (' || COALESCE(v_utilization_pct, 0.0)::TEXT || '% utilization).'
        ),
        jsonb_build_object(
            'type', 'WARNING',
            'icon', 'warning',
            'text', COALESCE(v_overloaded_count, 0)::TEXT || ' member(s) over-allocated.'
        ),
        jsonb_build_object(
            'type', 'INFO',
            'icon', 'info',
            'text', COALESCE(v_remaining_capacity, 0.0)::TEXT || ' h capacity available for additional work.'
        ),
        jsonb_build_object(
            'type', 'INFO',
            'icon', 'info',
            'text', 'Total team members enrolled: ' || v_team_members_count::TEXT || '.'
        )
    );

    -- 8. Return Comprehensive Dashboard JSON with Pagination Metadata
    RETURN jsonb_build_object(
        'success', true,
        'sprint_id', v_sprint_id,
        'sprint_name', COALESCE(v_sprint_row.name, 'Sprint 8'),
        'sprint_duration', COALESCE(v_sprint_row.start_date_fmt, 'Jan 01, 2025') || ' - ' || COALESCE(v_sprint_row.end_date_fmt, 'Jan 14, 2025'),
        'selected_team', v_team_name,
        'board_name', COALESCE(v_sprint_row.board_name, 'Institute Work Board'),
        'teams', v_teams_list,
        'sprints', v_all_sprints_list,
        'pagination', jsonb_build_object(
            'page', v_page,
            'limit', COALESCE(v_limit, v_total_filtered_count),
            'total_members', v_total_filtered_count,
            'total_pages', v_total_pages
        ),
        'kpis', jsonb_build_object(
            'team_members', v_team_members_count,
            'total_capacity_hours', COALESCE(v_total_capacity, 0.0),
            'planned_work_hours', COALESCE(v_planned_work, 0.0),
            'actual_work_hours', COALESCE(v_actual_work, 0.0),
            'remaining_capacity_hours', COALESCE(v_remaining_capacity, 0.0),
            'utilization_pct', COALESCE(v_utilization_pct, 0.0),
            'over_allocation_hours', COALESCE(v_over_allocation, 0.0),
            'overloaded_members_count', COALESCE(v_overloaded_count, 0)
        ),
        'daily_chart', v_daily_chart,
        'members', v_members_list,
        'capacity_utilization', jsonb_build_object(
            'planned_hours', COALESCE(v_planned_work, 0.0),
            'planned_pct', COALESCE(v_utilization_pct, 0.0),
            'available_hours', COALESCE(v_remaining_capacity, 0.0),
            'available_pct', ROUND(GREATEST(100.0 - COALESCE(v_utilization_pct, 0.0), 0.0), 1),
            'total_capacity_hours', COALESCE(v_total_capacity, 0.0)
        ),
        'capacity_summary', jsonb_build_object(
            'total_team_capacity', (COALESCE(v_total_capacity, 0.0)::INT)::TEXT || ' h',
            'planned_committed_work', (COALESCE(v_planned_work, 0.0)::INT)::TEXT || ' h',
            'actual_work_completed', (COALESCE(v_actual_work, 0.0)::INT)::TEXT || ' h',
            'remaining_capacity', (COALESCE(v_remaining_capacity, 0.0)::INT)::TEXT || ' h',
            'utilization', COALESCE(v_utilization_pct, 0.0)::TEXT || '%',
            'over_allocation', (COALESCE(v_over_allocation, 0.0)::INT)::TEXT || ' h'
        ),
        'insights', v_insights
    );
END;
$$;
