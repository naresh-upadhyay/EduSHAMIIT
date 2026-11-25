-- Migration 583: Single source of truth for Team Capacity and Member Counts

CREATE OR REPLACE FUNCTION public.sp_get_sprint_capacity_dashboard(p_school_id uuid, p_sprint_id uuid DEFAULT NULL::uuid, p_team_name character varying DEFAULT 'All Teams'::character varying, p_search character varying DEFAULT NULL::character varying, p_page integer DEFAULT 1, p_limit integer DEFAULT NULL::integer, p_sort_by character varying DEFAULT 'name'::character varying, p_sort_order character varying DEFAULT 'asc'::character varying, p_role_filter character varying DEFAULT NULL::character varying, p_status_filter character varying DEFAULT NULL::character varying)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_sprint_id UUID := p_sprint_id;
    v_sprint_row RECORD;
    v_team_name VARCHAR := COALESCE(NULLIF(TRIM(p_team_name), ''), 'All Teams');
    v_is_all_teams BOOLEAN := (LOWER(v_team_name) IN ('all', 'all teams', 'none', '*'));
    v_team_id UUID := NULL;
    v_sprint_days INT := 14;
    v_working_days INT := 10;
    v_total_capacity NUMERIC(10,2) := 0.0;
    v_planned_work NUMERIC(10,2) := 0.0;
    v_actual_work NUMERIC(10,2) := 0.0;
    v_remaining_capacity NUMERIC(10,2) := 0.0;
    v_utilization_pct NUMERIC(5,2) := 0.0;
    v_over_allocation NUMERIC(10,2) := 0.0;
    v_team_members_count INT := 0;
    v_total_filtered_count INT := 0;
    v_overloaded_count INT := 0;
    v_members_list JSONB := '[]'::jsonb;
    v_daily_chart JSONB := '[]'::jsonb;
    v_burndown_chart JSONB := '[]'::jsonb;
    v_teams_list JSONB := '[]'::jsonb;
    v_all_sprints_list JSONB := '[]'::jsonb;
    v_available_roles JSONB := '[]'::jsonb;
    v_insights JSONB := '[]'::jsonb;
    v_page INT := GREATEST(COALESCE(p_page, 1), 1);
    v_limit INT := p_limit;
    v_offset INT := 0;
    v_total_pages INT := 1;
    v_day_idx INT;
    v_curr_date DATE;
    v_date_fmt VARCHAR;
    v_ideal_remain NUMERIC(10,2);
    v_actual_remain NUMERIC(10,2);
    v_cum_completed NUMERIC(10,2);
    v_daily_cap NUMERIC(10,2);
BEGIN
    -- 1. Identify Target Sprint (default to latest ACTIVE sprint)
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
           COALESCE(GREATEST(1, (s.end_date - s.start_date + 1)), 14) AS calc_duration_days,
           b.name AS board_name
    INTO v_sprint_row
    FROM public.work_sprints s
    LEFT JOIN public.work_boards b ON b.id = s.board_id
    WHERE s.id = v_sprint_id AND s.school_id = p_school_id;

    IF v_sprint_row.calc_duration_days IS NOT NULL THEN
        v_sprint_days := v_sprint_row.calc_duration_days;
        v_working_days := GREATEST(1, ROUND(v_sprint_days * 5.0 / 7.0)::INT);
    END IF;

    -- Resolve selected team ID if specific team requested
    IF NOT v_is_all_teams THEN
        SELECT id, name INTO v_team_id, v_team_name
        FROM public.work_teams
        WHERE school_id = p_school_id
          AND (id::text = v_team_name OR name ILIKE v_team_name)
        LIMIT 1;
    END IF;

    -- 2. Fetch Teams List from work_teams table
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', t.id,
            'name', t.name,
            'department', t.department,
            'icon', t.icon,
            'member_count', (SELECT COUNT(*) FROM public.work_team_members wtm WHERE wtm.team_id = t.id),
            'is_selected', (v_team_id IS NOT NULL AND t.id = v_team_id) OR (v_is_all_teams AND t.name = v_team_name)
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
            'duration_days', COALESCE(GREATEST(1, (s.end_date - s.start_date + 1)), 14),
            'is_selected', (s.id = v_sprint_id)
        ) ORDER BY s.start_date DESC
    ) INTO v_all_sprints_list
    FROM public.work_sprints s
    WHERE s.school_id = p_school_id;

    IF v_all_sprints_list IS NULL THEN
        v_all_sprints_list := '[]'::jsonb;
    END IF;

    -- Fetch Roles
    SELECT jsonb_agg(
        jsonb_build_object('id', r.id, 'role_name', COALESCE(r.display_name, r.name))
        ORDER BY COALESCE(r.display_name, r.name) ASC
    ) INTO v_available_roles
    FROM public.app_roles r
    WHERE LOWER(r.status) = 'active';

    IF v_available_roles IS NULL THEN
        v_available_roles := '[]'::jsonb;
    END IF;

    -- 3. Dynamic Member Workload & Capacity Aggregation CTE
    WITH base_members AS (
        SELECT DISTINCT ON (wtm.user_id, CASE WHEN v_is_all_teams THEN NULL ELSE wtm.team_id END)
            wtm.user_id,
            wtm.team_id,
            t.name AS team_name,
            p.full_name,
            p.email,
            p.avatar_url,
            COALESCE(p.department, t.department, 'Academics') AS department,
            COALESCE(smc.role, wtm.role, 'Member') AS member_role,
            COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0) AS daily_hours,
            COALESCE(smc.working_days, v_working_days) AS working_days,
            COALESCE(smc.days_off, 0.0) AS days_off,
            COALESCE(
                smc.override_value,
                smc.available_hours,
                GREATEST(0.0, (COALESCE(smc.working_days, v_working_days) - COALESCE(smc.days_off, 0.0)) * COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0)),
                wtm.capacity_hours,
                80.0
            ) AS capacity_hours,
            smc.override_value,
            smc.override_reason,
            smc.notes,
            -- Live work item metrics for this sprint & user
            COALESCE((
                SELECT COUNT(DISTINCT wi.id)
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                WHERE wi.sprint_id = v_sprint_id
                  AND wia.user_id = wtm.user_id
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0) AS work_items_count,
            COALESCE((
                SELECT SUM(COALESCE(wi.estimated_hours, 0.0))
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                WHERE wi.sprint_id = v_sprint_id
                  AND wia.user_id = wtm.user_id
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0.0) AS planned_hours,
            COALESCE((
                SELECT SUM(COALESCE(wi.actual_hours, 0.0))
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                WHERE wi.sprint_id = v_sprint_id
                  AND wia.user_id = wtm.user_id
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0.0) AS actual_hours
        FROM public.work_team_members wtm
        JOIN public.work_teams t ON t.id = wtm.team_id
        JOIN public.profiles p ON p.id = wtm.user_id
        LEFT JOIN public.sprint_member_capacities smc
               ON smc.sprint_id = v_sprint_id
              AND (smc.team_id = wtm.team_id OR smc.team_id IS NULL)
              AND smc.user_id = wtm.user_id
        WHERE t.school_id = p_school_id
          AND (v_is_all_teams OR (v_team_id IS NOT NULL AND wtm.team_id = v_team_id) OR t.name = v_team_name)
    ),
    computed_members AS (
        SELECT
            bm.*,
            GREATEST(0.0, bm.capacity_hours - bm.planned_hours) AS remaining_hours,
            CASE
                WHEN bm.capacity_hours > 0 THEN ROUND((bm.planned_hours / bm.capacity_hours) * 100.0, 1)
                ELSE 0.0
            END AS utilization_pct,
            CASE
                WHEN bm.capacity_hours <= 0 THEN 'Balanced'
                WHEN bm.planned_hours > bm.capacity_hours THEN 'Overloaded'
                WHEN bm.planned_hours >= (bm.capacity_hours * 0.8) THEN 'Balanced'
                WHEN bm.planned_hours > 0 THEN 'Underallocated'
                ELSE 'Available'
            END AS workload_status
        FROM base_members bm
    )
    SELECT
        COUNT(*),
        COALESCE(SUM(capacity_hours), 0.0),
        COALESCE(SUM(planned_hours), 0.0),
        COALESCE(SUM(actual_hours), 0.0),
        COUNT(*) FILTER (WHERE workload_status = 'Overloaded')
    INTO
        v_team_members_count,
        v_total_capacity,
        v_planned_work,
        v_actual_work,
        v_overloaded_count
    FROM computed_members;

    v_remaining_capacity := GREATEST(0.0, v_total_capacity - v_planned_work);

    IF v_total_capacity > 0 THEN
        v_utilization_pct := ROUND((v_planned_work / v_total_capacity) * 100.0, 1);
        v_over_allocation := GREATEST(v_planned_work - v_total_capacity, 0.0);
    ELSE
        v_utilization_pct := 0.0;
        v_over_allocation := 0.0;
    END IF;

    -- 4. Count Filtered Members for Pagination
    WITH base_members AS (
        SELECT DISTINCT ON (wtm.user_id, CASE WHEN v_is_all_teams THEN NULL ELSE wtm.team_id END)
            wtm.user_id,
            p.full_name,
            COALESCE(smc.role, wtm.role, 'Member') AS member_role,
            COALESCE(
                smc.override_value,
                smc.available_hours,
                GREATEST(0.0, (COALESCE(smc.working_days, v_working_days) - COALESCE(smc.days_off, 0.0)) * COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0)),
                wtm.capacity_hours,
                80.0
            ) AS capacity_hours,
            COALESCE((
                SELECT SUM(COALESCE(wi.estimated_hours, 0.0))
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                WHERE wi.sprint_id = v_sprint_id
                  AND wia.user_id = wtm.user_id
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0.0) AS planned_hours
        FROM public.work_team_members wtm
        JOIN public.work_teams t ON t.id = wtm.team_id
        JOIN public.profiles p ON p.id = wtm.user_id
        LEFT JOIN public.sprint_member_capacities smc
               ON smc.sprint_id = v_sprint_id
              AND (smc.team_id = wtm.team_id OR smc.team_id IS NULL)
              AND smc.user_id = wtm.user_id
        WHERE t.school_id = p_school_id
          AND (v_is_all_teams OR (v_team_id IS NOT NULL AND wtm.team_id = v_team_id) OR t.name = v_team_name)
    ),
    computed_members AS (
        SELECT
            bm.*,
            CASE
                WHEN bm.capacity_hours <= 0 THEN 'Balanced'
                WHEN bm.planned_hours > bm.capacity_hours THEN 'Overloaded'
                WHEN bm.planned_hours >= (bm.capacity_hours * 0.8) THEN 'Balanced'
                WHEN bm.planned_hours > 0 THEN 'Underallocated'
                ELSE 'Available'
            END AS workload_status
        FROM base_members bm
    )
    SELECT COUNT(*) INTO v_total_filtered_count
    FROM computed_members c
    WHERE (p_search IS NULL OR p_search = '' OR c.full_name ILIKE '%' || p_search || '%' OR c.member_role ILIKE '%' || p_search || '%')
      AND (p_role_filter IS NULL OR p_role_filter = 'All' OR c.member_role ILIKE '%' || p_role_filter || '%')
      AND (p_status_filter IS NULL OR p_status_filter = 'All' OR c.workload_status ILIKE p_status_filter);

    IF v_limit IS NOT NULL AND v_limit > 0 THEN
        v_total_pages := GREATEST(1, CEIL(v_total_filtered_count::NUMERIC / v_limit::NUMERIC)::INT);
        v_offset := (v_page - 1) * v_limit;
    ELSE
        v_limit := 500;
        v_offset := 0;
        v_total_pages := 1;
    END IF;

    -- 5. Paginated & Sorted Members List
    WITH base_members AS (
        SELECT DISTINCT ON (wtm.user_id, CASE WHEN v_is_all_teams THEN NULL ELSE wtm.team_id END)
            wtm.id AS member_id,
            wtm.user_id,
            wtm.team_id,
            t.name AS team_name,
            p.full_name,
            p.email,
            p.avatar_url,
            COALESCE(p.department, t.department, 'Academics') AS department,
            COALESCE(smc.role, wtm.role, 'Member') AS member_role,
            COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0) AS daily_hours,
            COALESCE(smc.working_days, v_working_days) AS working_days,
            COALESCE(smc.days_off, 0.0) AS days_off,
            COALESCE(
                smc.override_value,
                smc.available_hours,
                GREATEST(0.0, (COALESCE(smc.working_days, v_working_days) - COALESCE(smc.days_off, 0.0)) * COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0)),
                wtm.capacity_hours,
                80.0
            ) AS capacity_hours,
            smc.override_value,
            smc.override_reason,
            smc.notes,
            COALESCE((
                SELECT COUNT(DISTINCT wi.id)
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                WHERE wi.sprint_id = v_sprint_id
                  AND wia.user_id = wtm.user_id
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0) AS work_items_count,
            COALESCE((
                SELECT SUM(COALESCE(wi.estimated_hours, 0.0))
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                WHERE wi.sprint_id = v_sprint_id
                  AND wia.user_id = wtm.user_id
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0.0) AS planned_hours,
            COALESCE((
                SELECT SUM(COALESCE(wi.actual_hours, 0.0))
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                WHERE wi.sprint_id = v_sprint_id
                  AND wia.user_id = wtm.user_id
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0.0) AS actual_hours
        FROM public.work_team_members wtm
        JOIN public.work_teams t ON t.id = wtm.team_id
        JOIN public.profiles p ON p.id = wtm.user_id
        LEFT JOIN public.sprint_member_capacities smc
               ON smc.sprint_id = v_sprint_id
              AND (smc.team_id = wtm.team_id OR smc.team_id IS NULL)
              AND smc.user_id = wtm.user_id
        WHERE t.school_id = p_school_id
          AND (v_is_all_teams OR (v_team_id IS NOT NULL AND wtm.team_id = v_team_id) OR t.name = v_team_name)
    ),
    computed_members AS (
        SELECT
            bm.*,
            GREATEST(0.0, bm.capacity_hours - bm.planned_hours) AS remaining_hours,
            CASE
                WHEN bm.capacity_hours > 0 THEN ROUND((bm.planned_hours / bm.capacity_hours) * 100.0, 1)
                ELSE 0.0
            END AS utilization_pct,
            CASE
                WHEN bm.capacity_hours <= 0 THEN 'Balanced'
                WHEN bm.planned_hours > bm.capacity_hours THEN 'Overloaded'
                WHEN bm.planned_hours >= (bm.capacity_hours * 0.8) THEN 'Balanced'
                WHEN bm.planned_hours > 0 THEN 'Underallocated'
                ELSE 'Available'
            END AS workload_status
        FROM base_members bm
    )
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', sub.member_id,
            'user_id', sub.user_id,
            'full_name', sub.full_name,
            'email', sub.email,
            'avatar_url', sub.avatar_url,
            'department', sub.department,
            'team_id', sub.team_id,
            'team_name', sub.team_name,
            'role', sub.member_role,
            'daily_working_hours', sub.daily_hours,
            'working_days', sub.working_days,
            'days_off', sub.days_off,
            'capacity_hours', sub.capacity_hours,
            'planned_hours', sub.planned_hours,
            'actual_hours', sub.actual_hours,
            'remaining_hours', sub.remaining_hours,
            'utilization_pct', sub.utilization_pct,
            'work_items_count', sub.work_items_count,
            'workload_status', sub.workload_status,
            'override_value', sub.override_value,
            'override_reason', sub.override_reason,
            'notes', sub.notes
        )
    ), '[]'::jsonb) INTO v_members_list
    FROM (
        SELECT * FROM computed_members c
        WHERE (p_search IS NULL OR p_search = '' OR c.full_name ILIKE '%' || p_search || '%' OR c.member_role ILIKE '%' || p_search || '%')
          AND (p_role_filter IS NULL OR p_role_filter = 'All' OR c.member_role ILIKE '%' || p_role_filter || '%')
          AND (p_status_filter IS NULL OR p_status_filter = 'All' OR c.workload_status ILIKE p_status_filter)
        ORDER BY
            CASE WHEN LOWER(p_sort_by) = 'name' AND LOWER(p_sort_order) = 'desc' THEN c.full_name END DESC,
            CASE WHEN LOWER(p_sort_by) = 'name' AND LOWER(p_sort_order) != 'desc' THEN c.full_name END ASC,
            CASE WHEN LOWER(p_sort_by) = 'role' AND LOWER(p_sort_order) = 'desc' THEN c.member_role END DESC,
            CASE WHEN LOWER(p_sort_by) = 'role' AND LOWER(p_sort_order) != 'desc' THEN c.member_role END ASC,
            CASE WHEN LOWER(p_sort_by) = 'capacity' AND LOWER(p_sort_order) = 'desc' THEN c.capacity_hours END DESC,
            CASE WHEN LOWER(p_sort_by) = 'capacity' AND LOWER(p_sort_order) != 'desc' THEN c.capacity_hours END ASC,
            CASE WHEN LOWER(p_sort_by) = 'planned' AND LOWER(p_sort_order) = 'desc' THEN c.planned_hours END DESC,
            CASE WHEN LOWER(p_sort_by) = 'planned' AND LOWER(p_sort_order) != 'desc' THEN c.planned_hours END ASC,
            CASE WHEN LOWER(p_sort_by) = 'actual' AND LOWER(p_sort_order) = 'desc' THEN c.actual_hours END DESC,
            CASE WHEN LOWER(p_sort_by) = 'actual' AND LOWER(p_sort_order) != 'desc' THEN c.actual_hours END ASC,
            CASE WHEN LOWER(p_sort_by) = 'remaining' AND LOWER(p_sort_order) = 'desc' THEN c.remaining_hours END DESC,
            CASE WHEN LOWER(p_sort_by) = 'remaining' AND LOWER(p_sort_order) != 'desc' THEN c.remaining_hours END ASC,
            CASE WHEN LOWER(p_sort_by) = 'utilization' AND LOWER(p_sort_order) = 'desc' THEN c.utilization_pct END DESC,
            CASE WHEN LOWER(p_sort_by) = 'utilization' AND LOWER(p_sort_order) != 'desc' THEN c.utilization_pct END ASC,
            CASE WHEN LOWER(p_sort_by) = 'status' AND LOWER(p_sort_order) = 'desc' THEN c.workload_status END DESC,
            CASE WHEN LOWER(p_sort_by) = 'status' AND LOWER(p_sort_order) != 'desc' THEN c.workload_status END ASC,
            c.full_name ASC
        LIMIT v_limit OFFSET v_offset
    ) sub;

    IF v_members_list IS NULL THEN
        v_members_list := '[]'::jsonb;
    END IF;

    -- 6. Dynamic Sprint Burndown
    v_daily_cap := ROUND(v_total_capacity / GREATEST(1, v_working_days), 1);
    v_burndown_chart := '[]'::jsonb;

    FOR v_day_idx IN 1..v_sprint_days LOOP
        v_curr_date := (v_sprint_row.start_date + (v_day_idx - 1) * INTERVAL '1 day')::DATE;
        v_date_fmt := to_char(v_curr_date, 'Mon DD');
        v_ideal_remain := ROUND(GREATEST(0.0, v_planned_work * (1.0 - ((v_day_idx - 1)::NUMERIC / GREATEST(1, v_sprint_days - 1)))), 1);

        IF v_day_idx <= GREATEST(1, (CURRENT_DATE - v_sprint_row.start_date + 1)) THEN
            v_cum_completed := ROUND(LEAST(v_actual_work, (v_actual_work / GREATEST(1, (CURRENT_DATE - v_sprint_row.start_date + 1))) * v_day_idx), 1);
            v_actual_remain := ROUND(GREATEST(0.0, v_planned_work - v_cum_completed), 1);
        ELSE
            v_cum_completed := v_actual_work;
            v_actual_remain := v_remaining_capacity;
        END IF;

        v_burndown_chart := v_burndown_chart || jsonb_build_array(
            jsonb_build_object(
                'day_index', v_day_idx,
                'date_fmt', v_date_fmt,
                'full_date', to_char(v_curr_date, 'YYYY-MM-DD'),
                'capacity_hours', v_daily_cap,
                'ideal_remaining', v_ideal_remain,
                'remaining_hours', v_actual_remain,
                'completed_hours', v_cum_completed,
                'planned_hours', ROUND(v_planned_work / GREATEST(1, v_working_days), 1),
                'actual_hours', ROUND(v_actual_work / GREATEST(1, v_sprint_days), 1)
            )
        );
    END LOOP;

    v_daily_chart := v_burndown_chart;

    -- 7. Construct Smart Recommendation Insights
    v_insights := jsonb_build_array(
        jsonb_build_object(
            'type', 'SUCCESS',
            'icon', 'check_circle',
            'text', 'Team is operating at ' || COALESCE(v_utilization_pct, 0.0)::TEXT || '% planned utilization.'
        ),
        jsonb_build_object(
            'type', CASE WHEN v_overloaded_count > 0 THEN 'WARNING' ELSE 'INFO' END,
            'icon', CASE WHEN v_overloaded_count > 0 THEN 'warning' ELSE 'info' END,
            'text', COALESCE(v_overloaded_count, 0)::TEXT || ' member(s) currently over-allocated for this sprint.'
        ),
        jsonb_build_object(
            'type', 'INFO',
            'icon', 'info',
            'text', COALESCE(v_sprint_row.name, 'Sprint') || ' (' || v_sprint_days::TEXT || ' days) with ' || v_team_members_count::TEXT || ' team member(s).'
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'sprint_id', v_sprint_id,
        'sprint_name', COALESCE(v_sprint_row.name, 'Sprint 103'),
        'sprint_duration', COALESCE(v_sprint_row.start_date_fmt || ' - ' || v_sprint_row.end_date_fmt, 'Nov 15, 2026 - Nov 28, 2026'),
        'sprint_days', v_sprint_days,
        'working_days', v_working_days,
        'board_name', COALESCE(v_sprint_row.board_name, 'Institute Work Board'),
        'selected_team', v_team_name,
        'selected_team_id', v_team_id,
        'pagination', jsonb_build_object(
            'page', v_page,
            'limit', v_limit,
            'total_count', v_total_filtered_count,
            'total_pages', v_total_pages,
            'has_next_page', (v_page < v_total_pages),
            'has_prev_page', (v_page > 1)
        ),
        'kpis', jsonb_build_object(
            'team_members', v_team_members_count,
            'team_members_count', v_team_members_count,
            'total_capacity_hours', v_total_capacity,
            'planned_work_hours', v_planned_work,
            'actual_work_hours', v_actual_work,
            'remaining_capacity_hours', v_remaining_capacity,
            'utilization_pct', v_utilization_pct,
            'over_allocation_hours', v_over_allocation,
            'overloaded_members_count', v_overloaded_count
        ),
        'teams', v_teams_list,
        'all_sprints', v_all_sprints_list,
        'available_roles', v_available_roles,
        'daily_chart', v_daily_chart,
        'burndown_chart', v_burndown_chart,
        'members', v_members_list,
        'insights', v_insights
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.sp_get_team_detail_drawer(p_school_id uuid, p_team_id uuid, p_sprint_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_sprint UUID := p_sprint_id;
    v_sprint_row RECORD;
    v_sprint_days INT := 14;
    v_working_days INT := 10;
    v_team RECORD;
    v_lead RECORD;
    v_capacity_stat RECORD;
    v_members JSONB := '[]'::jsonb;
    v_activities JSONB := '[]'::jsonb;
    v_work_items JSONB := '[]'::jsonb;
BEGIN
    -- Resolve to latest ACTIVE sprint if not specified
    IF v_sprint IS NULL THEN
        SELECT id INTO v_sprint FROM public.work_sprints
        WHERE school_id = p_school_id AND status = 'ACTIVE'
        ORDER BY start_date DESC LIMIT 1;

        IF v_sprint IS NULL THEN
            SELECT id INTO v_sprint FROM public.work_sprints
            WHERE school_id = p_school_id
            ORDER BY start_date DESC LIMIT 1;
        END IF;
    END IF;

    -- Fetch Sprint Details
    SELECT s.*,
           COALESCE(GREATEST(1, (s.end_date - s.start_date + 1)), 14) AS calc_duration_days
    INTO v_sprint_row
    FROM public.work_sprints s
    WHERE s.id = v_sprint;

    IF v_sprint_row.calc_duration_days IS NOT NULL THEN
        v_sprint_days := v_sprint_row.calc_duration_days;
        v_working_days := GREATEST(1, ROUND(v_sprint_days * 5.0 / 7.0)::INT);
    END IF;

    -- Fetch Team Master
    SELECT * INTO v_team FROM public.work_teams WHERE id = p_team_id AND school_id = p_school_id;
    IF v_team.id IS NULL THEN
        SELECT * INTO v_team FROM public.work_teams WHERE id = p_team_id;
        IF v_team.id IS NULL THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Team not found');
        END IF;
    END IF;

    -- Fetch Lead
    SELECT id, full_name, email, avatar_url INTO v_lead
    FROM public.profiles WHERE id = v_team.lead_id;

    -- Dynamic Capacity Stats matching Capacity Screen calculation for v_sprint
    WITH member_caps AS (
        SELECT
            wtm.user_id,
            COALESCE(
                smc.override_value,
                smc.available_hours,
                GREATEST(0.0, (COALESCE(smc.working_days, v_working_days) - COALESCE(smc.days_off, 0.0)) * COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0)),
                wtm.capacity_hours,
                80.0
            ) AS cap_h,
            COALESCE((
                SELECT SUM(COALESCE(wi.estimated_hours, 0.0))
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                WHERE wi.sprint_id = v_sprint
                  AND wia.user_id = wtm.user_id
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0.0) AS plan_h
        FROM public.work_team_members wtm
        LEFT JOIN public.sprint_member_capacities smc
               ON smc.sprint_id = v_sprint
              AND (smc.team_id = wtm.team_id OR smc.team_id IS NULL)
              AND smc.user_id = wtm.user_id
        WHERE wtm.team_id = v_team.id
    )
    SELECT
        COALESCE(SUM(cap_h), v_team.default_capacity_hours, 0.0) AS capacity_hours,
        COALESCE(SUM(plan_h), 0.0) AS planned_hours,
        GREATEST(0.0, COALESCE(SUM(cap_h), 0.0) - COALESCE(SUM(plan_h), 0.0)) AS remaining_hours,
        CASE
            WHEN COALESCE(SUM(cap_h), 0.0) > 0 THEN ROUND((COALESCE(SUM(plan_h), 0.0) / SUM(cap_h)) * 100.0, 1)
            ELSE 0.0
        END AS utilization_pct
    INTO v_capacity_stat
    FROM member_caps;

    -- Fetch Members with Avatar, Email, Role, Capacity
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', m.id,
            'user_id', p.id,
            'name', p.full_name,
            'email', p.email,
            'role', COALESCE(m.role, p.role, 'Member'),
            'designation', COALESCE(p.designation, m.role, p.role, 'Staff'),
            'avatar_url', p.avatar_url,
            'capacity_hours', COALESCE(m.capacity_hours, 40.0),
            'daily_hours', COALESCE(m.daily_hours, 8.0),
            'is_lead', COALESCE(m.is_lead, (v_team.lead_id = p.id), FALSE),
            'joined_at', m.joined_at
        ) ORDER BY (CASE WHEN COALESCE(m.is_lead, (v_team.lead_id = p.id), FALSE) THEN 1 ELSE 0 END) DESC, p.full_name ASC
    ), '[]'::jsonb) INTO v_members
    FROM public.work_team_members m
    JOIN public.profiles p ON p.id = m.user_id
    WHERE m.team_id = p_team_id;

    -- Fetch Recent Activities
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', a.id,
            'activity_type', a.activity_type,
            'description', a.description,
            'actor_name', a.actor_name,
            'created_at', a.created_at
        ) ORDER BY a.created_at DESC
    ), '[]'::jsonb) INTO v_activities
    FROM (
        SELECT * FROM public.work_team_activities
        WHERE team_id = p_team_id
        ORDER BY created_at DESC
        LIMIT 15
    ) a;

    -- Fetch Assigned Work Items: all items assigned to this team across sprints & backlog
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', wi.id,
            'item_key', wi.item_number,
            'title', wi.title,
            'type', wi.work_type,
            'priority', wi.priority,
            'status', wi.status,
            'progress_percentage', wi.progress_percentage,
            'sprint_id', wi.sprint_id,
            'sprint_name', COALESCE(ws.name, 'Backlog'),
            'assignee_name', COALESCE(ap.full_name, 'Unassigned'),
            'assignee_email', ap.email,
            'assignee_avatar', ap.avatar_url,
            'created_at', wi.created_at
        ) ORDER BY wi.created_at DESC
    ), '[]'::jsonb) INTO v_work_items
    FROM (
        SELECT * FROM public.work_items
        WHERE (school_id = p_school_id OR school_id = v_team.school_id)
          AND (team_id = p_team_id OR LOWER(team_name) = LOWER(v_team.name))
        LIMIT 100
    ) wi
    LEFT JOIN public.work_sprints ws ON ws.id = wi.sprint_id
    LEFT JOIN LATERAL (
        SELECT p2.full_name, p2.email, p2.avatar_url
        FROM public.work_item_assignees wia
        JOIN public.profiles p2 ON p2.id = wia.user_id
        WHERE wia.work_item_id = wi.id
        LIMIT 1
    ) ap ON TRUE;

    RETURN jsonb_build_object(
        'success', TRUE,
        'team', jsonb_build_object(
            'id', v_team.id,
            'name', v_team.name,
            'team_key', COALESCE(v_team.team_key, 'DCT'),
            'department', COALESCE(v_team.department, 'IT & Digitalization'),
            'description', COALESCE(v_team.description, ''),
            'icon', COALESCE(v_team.icon, 'layers'),
            'color', COALESCE(v_team.color, '#2563EB'),
            'is_active', v_team.is_active,
            'status', v_team.status,
            'tags', COALESCE(v_team.tags, ARRAY[]::TEXT[]),
            'goal', COALESCE(v_team.goal, ''),
            'created_at', v_team.created_at,
            'updated_at', v_team.updated_at,
            'lead', jsonb_build_object(
                'id', v_lead.id,
                'name', COALESCE(v_lead.full_name, 'Unassigned'),
                'email', v_lead.email,
                'avatar_url', v_lead.avatar_url
            ),
            'capacity', jsonb_build_object(
                'sprint_id', v_sprint,
                'sprint_name', COALESCE(v_sprint_row.name, 'Sprint 103'),
                'total_capacity_hours', v_capacity_stat.capacity_hours,
                'planned_hours', v_capacity_stat.planned_hours,
                'remaining_hours', v_capacity_stat.remaining_hours,
                'utilization_pct', v_capacity_stat.utilization_pct
            ),
            'members', COALESCE(v_members, '[]'::jsonb),
            'activities', COALESCE(v_activities, '[]'::jsonb),
            'work_items', COALESCE(v_work_items, '[]'::jsonb)
        )
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.sp_get_teams_directory(p_school_id uuid, p_sprint_id uuid DEFAULT NULL::uuid, p_status character varying DEFAULT 'ALL'::character varying, p_department character varying DEFAULT 'ALL'::character varying, p_search character varying DEFAULT NULL::character varying, p_sort_by character varying DEFAULT 'NAME_ASC'::character varying, p_limit integer DEFAULT 10, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_sprint UUID := p_sprint_id;
    v_sprint_row RECORD;
    v_sprint_days INT := 14;
    v_working_days INT := 10;
    v_total_teams INT := 0;
    v_total_members INT := 0;
    v_total_capacity NUMERIC(10,2) := 0.0;
    v_total_allocated NUMERIC(10,2) := 0.0;
    v_avg_utilization NUMERIC(5,2) := 0.0;
    v_active_teams INT := 0;
    v_inactive_teams INT := 0;
    v_teams_json JSONB := '[]'::jsonb;
    v_kpis_json JSONB;
    v_total_filtered INT := 0;
BEGIN
    -- Resolve to latest ACTIVE sprint if not specified
    IF v_sprint IS NULL THEN
        SELECT id INTO v_sprint FROM public.work_sprints
        WHERE school_id = p_school_id AND status = 'ACTIVE'
        ORDER BY start_date DESC LIMIT 1;

        IF v_sprint IS NULL THEN
            SELECT id INTO v_sprint FROM public.work_sprints
            WHERE school_id = p_school_id
            ORDER BY start_date DESC LIMIT 1;
        END IF;
    END IF;

    -- Fetch Sprint Details
    SELECT s.*,
           COALESCE(GREATEST(1, (s.end_date - s.start_date + 1)), 14) AS calc_duration_days
    INTO v_sprint_row
    FROM public.work_sprints s
    WHERE s.id = v_sprint;

    IF v_sprint_row.calc_duration_days IS NOT NULL THEN
        v_sprint_days := v_sprint_row.calc_duration_days;
        v_working_days := GREATEST(1, ROUND(v_sprint_days * 5.0 / 7.0)::INT);
    END IF;

    -- Aggregate Global KPIs for non-archived teams
    SELECT
        COUNT(t.id),
        COALESCE(COUNT(t.id) FILTER (WHERE t.is_active = TRUE AND t.status = 'ACTIVE'), 0),
        COALESCE(COUNT(t.id) FILTER (WHERE t.is_active = FALSE OR t.status != 'ACTIVE'), 0)
    INTO v_total_teams, v_active_teams, v_inactive_teams
    FROM public.work_teams t
    WHERE t.school_id = p_school_id AND t.status != 'ARCHIVED';

    SELECT COUNT(wtm.id) INTO v_total_members
    FROM public.work_team_members wtm
    JOIN public.work_teams t ON t.id = wtm.team_id
    WHERE t.school_id = p_school_id AND t.status != 'ARCHIVED';

    -- Dynamic Capacity calculation per team for v_sprint
    WITH team_calc AS (
        SELECT
            t.id AS team_id,
            COALESCE(SUM(
                COALESCE(
                    smc.override_value,
                    smc.available_hours,
                    GREATEST(0.0, (COALESCE(smc.working_days, v_working_days) - COALESCE(smc.days_off, 0.0)) * COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0)),
                    wtm.capacity_hours,
                    80.0
                )
            ), t.default_capacity_hours, 0.0) AS team_cap,
            COALESCE((
                SELECT SUM(COALESCE(wi.estimated_hours, 0.0))
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                JOIN public.work_team_members wtm2 ON wtm2.user_id = wia.user_id AND wtm2.team_id = t.id
                WHERE wi.sprint_id = v_sprint
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0.0) AS team_plan
        FROM public.work_teams t
        LEFT JOIN public.work_team_members wtm ON wtm.team_id = t.id
        LEFT JOIN public.sprint_member_capacities smc
               ON smc.sprint_id = v_sprint
              AND (smc.team_id = t.id OR smc.team_id IS NULL)
              AND smc.user_id = wtm.user_id
        WHERE t.school_id = p_school_id AND t.is_active = TRUE AND t.status = 'ACTIVE'
        GROUP BY t.id, t.default_capacity_hours
    )
    SELECT
        COALESCE(SUM(team_cap), 0.0),
        COALESCE(SUM(team_plan), 0.0)
    INTO v_total_capacity, v_total_allocated
    FROM team_calc;

    IF v_total_capacity > 0 THEN
        v_avg_utilization := ROUND((v_total_allocated / v_total_capacity) * 100.0, 1);
    ELSE
        v_avg_utilization := 0.0;
    END IF;

    v_kpis_json := jsonb_build_object(
        'total_teams', v_total_teams,
        'total_members', v_total_members,
        'total_capacity_hours', v_total_capacity,
        'allocated_work_hours', v_total_allocated,
        'capacity_utilization_pct', v_avg_utilization,
        'active_teams', v_active_teams,
        'inactive_teams', v_inactive_teams
    );

    -- Count total filtered teams for pagination
    SELECT COUNT(*) INTO v_total_filtered
    FROM public.work_teams t
    LEFT JOIN public.profiles p ON p.id = t.lead_id
    WHERE t.school_id = p_school_id
      AND t.status != 'ARCHIVED'
      AND (p_status IS NULL OR p_status = 'ALL' OR (p_status = 'ACTIVE' AND t.is_active = TRUE AND t.status = 'ACTIVE') OR (p_status = 'INACTIVE' AND (t.is_active = FALSE OR t.status = 'INACTIVE')))
      AND (p_department IS NULL OR p_department = 'ALL' OR t.department ILIKE '%' || p_department || '%')
      AND (p_search IS NULL OR p_search = '' OR (
          t.name ILIKE '%' || p_search || '%' OR
          t.team_key ILIKE '%' || p_search || '%' OR
          t.department ILIKE '%' || p_search || '%' OR
          p.full_name ILIKE '%' || p_search || '%' OR
          p.email ILIKE '%' || p_search || '%'
      ));

    -- Build Filtered & Sorted Teams List with dynamic capacity matching Capacity Screen
    WITH filtered_teams AS (
        SELECT
            t.id,
            t.name,
            t.team_key,
            t.department,
            t.description,
            t.icon,
            t.color,
            t.is_active,
            t.status,
            t.tags,
            t.goal,
            t.created_at,
            t.updated_at,
            p.id AS lead_id,
            p.full_name AS lead_name,
            p.email AS lead_email,
            p.avatar_url AS lead_avatar,
            COALESCE(SUM(
                COALESCE(
                    smc.override_value,
                    smc.available_hours,
                    GREATEST(0.0, (COALESCE(smc.working_days, v_working_days) - COALESCE(smc.days_off, 0.0)) * COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0)),
                    wtm.capacity_hours,
                    80.0
                )
            ), t.default_capacity_hours, 0.0) AS capacity_hours,
            COALESCE((
                SELECT SUM(COALESCE(wi.estimated_hours, 0.0))
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                JOIN public.work_team_members wtm2 ON wtm2.user_id = wia.user_id AND wtm2.team_id = t.id
                WHERE wi.sprint_id = v_sprint
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0.0) AS planned_hours,
            COUNT(wtm.id) AS member_count,
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', mem_p.id,
                        'name', mem_p.full_name,
                        'email', mem_p.email,
                        'avatar_url', mem_p.avatar_url,
                        'role', COALESCE(mem_m.role, mem_p.role, 'Member'),
                        'is_lead', COALESCE(mem_m.is_lead, FALSE)
                    ) ORDER BY mem_m.is_lead DESC, mem_p.full_name ASC
                )
                FROM public.work_team_members mem_m
                JOIN public.profiles mem_p ON mem_p.id = mem_m.user_id
                WHERE mem_m.team_id = t.id
            ) AS members_json
        FROM public.work_teams t
        LEFT JOIN public.profiles p ON p.id = t.lead_id
        LEFT JOIN public.work_team_members wtm ON wtm.team_id = t.id
        LEFT JOIN public.sprint_member_capacities smc
               ON smc.sprint_id = v_sprint
              AND (smc.team_id = t.id OR smc.team_id IS NULL)
              AND smc.user_id = wtm.user_id
        WHERE t.school_id = p_school_id
          AND t.status != 'ARCHIVED'
          AND (p_status IS NULL OR p_status = 'ALL' OR (p_status = 'ACTIVE' AND t.is_active = TRUE AND t.status = 'ACTIVE') OR (p_status = 'INACTIVE' AND (t.is_active = FALSE OR t.status = 'INACTIVE')))
          AND (p_department IS NULL OR p_department = 'ALL' OR t.department ILIKE '%' || p_department || '%')
          AND (p_search IS NULL OR p_search = '' OR (
              t.name ILIKE '%' || p_search || '%' OR
              t.team_key ILIKE '%' || p_search || '%' OR
              t.department ILIKE '%' || p_search || '%' OR
              p.full_name ILIKE '%' || p_search || '%' OR
              p.email ILIKE '%' || p_search || '%'
          ))
        GROUP BY t.id, p.id, p.full_name, p.email, p.avatar_url
        ORDER BY
            CASE WHEN p_sort_by = 'NAME_ASC' THEN t.name END ASC,
            CASE WHEN p_sort_by = 'NAME_DESC' THEN t.name END DESC,
            CASE WHEN p_sort_by = 'CODE_ASC' THEN t.team_key END ASC,
            CASE WHEN p_sort_by = 'DEPT_ASC' THEN t.department END ASC,
            CASE WHEN p_sort_by = 'CREATED_DESC' THEN t.created_at END DESC,
            t.created_at DESC
        LIMIT p_limit OFFSET p_offset
    )
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', ft.id,
            'name', ft.name,
            'team_key', ft.team_key,
            'department', ft.department,
            'description', ft.description,
            'icon', ft.icon,
            'color', ft.color,
            'is_active', ft.is_active,
            'status', ft.status,
            'tags', COALESCE(ft.tags, ARRAY[]::TEXT[]),
            'goal', COALESCE(ft.goal, ''),
            'created_at', ft.created_at,
            'updated_at', ft.updated_at,
            'lead', jsonb_build_object(
                'id', ft.lead_id,
                'name', COALESCE(ft.lead_name, 'Unassigned'),
                'email', ft.lead_email,
                'avatar_url', ft.lead_avatar
            ),
            'member_count', ft.member_count,
            'members', COALESCE(ft.members_json, '[]'::jsonb),
            'capacity_hours', ft.capacity_hours,
            'planned_hours', ft.planned_hours,
            'remaining_hours', GREATEST(0.0, ft.capacity_hours - ft.planned_hours),
            'utilization_pct', CASE WHEN ft.capacity_hours > 0 THEN ROUND((ft.planned_hours / ft.capacity_hours) * 100.0, 1) ELSE 0.0 END
        )
    ), '[]'::jsonb) INTO v_teams_json
    FROM filtered_teams ft;

    RETURN jsonb_build_object(
        'success', TRUE,
        'sprint_id', v_sprint,
        'sprint_name', v_sprint_row.name,
        'kpis', v_kpis_json,
        'total_count', v_total_filtered,
        'teams', v_teams_json
    );
END;
$function$
;

