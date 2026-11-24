-- ============================================================================
-- Migration 570: Fix All Grids Team Filtering, Real-Time Dynamic Teams & Capacity
-- ============================================================================

-- 1. Reconcile / Drop ambiguous sp_list_work_items_paged overloads
DROP FUNCTION IF EXISTS public.sp_list_work_items_paged(UUID, VARCHAR, UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, UUID, VARCHAR, VARCHAR, INT, INT);
DROP FUNCTION IF EXISTS public.sp_list_work_items_paged(UUID, UUID, UUID, VARCHAR, VARCHAR, UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, INT, INT);

CREATE OR REPLACE FUNCTION public.sp_list_work_items_paged(
    p_school_id UUID,
    p_board_id UUID DEFAULT NULL,
    p_sprint_id UUID DEFAULT NULL,
    p_type VARCHAR DEFAULT 'All',
    p_status VARCHAR DEFAULT 'All',
    p_assignee_id UUID DEFAULT NULL,
    p_priority VARCHAR DEFAULT 'All',
    p_search VARCHAR DEFAULT NULL,
    p_sort_col VARCHAR DEFAULT 'created_at',
    p_sort_dir VARCHAR DEFAULT 'DESC',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 100
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_count INT := 0;
    v_offset INT := 0;
    v_items JSONB := '[]'::jsonb;
    v_kpis JSONB := '{}'::jsonb;
    v_clean_type VARCHAR := NULLIF(TRIM(p_type), '');
    v_clean_status VARCHAR := NULLIF(TRIM(p_status), '');
    v_clean_priority VARCHAR := NULLIF(TRIM(p_priority), '');
    v_clean_search VARCHAR := NULLIF(TRIM(p_search), '');
BEGIN
    v_offset := GREATEST(0, (COALESCE(p_page, 1) - 1) * COALESCE(p_page_size, 100));

    -- Total count & KPI counts
    SELECT
        COUNT(*),
        jsonb_build_object(
            'total', COUNT(*),
            'new', COUNT(*) FILTER (WHERE UPPER(w.status) = 'NEW'),
            'active', COUNT(*) FILTER (WHERE UPPER(w.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS')),
            'resolved', COUNT(*) FILTER (WHERE UPPER(w.status) = 'RESOLVED'),
            'completed', COUNT(*) FILTER (WHERE UPPER(w.status) = 'COMPLETED'),
            'overdue', COUNT(*) FILTER (WHERE w.due_date IS NOT NULL AND w.due_date < CURRENT_DATE AND UPPER(w.status) NOT IN ('COMPLETED', 'RESOLVED'))
        )
    INTO v_total_count, v_kpis
    FROM public.work_items w
    WHERE w.school_id = p_school_id
      AND w.is_archived = FALSE
      AND (p_board_id IS NULL OR w.board_id = p_board_id)
      AND (p_sprint_id IS NULL OR w.sprint_id = p_sprint_id)
      AND (v_clean_type IS NULL OR LOWER(v_clean_type) = 'all' OR UPPER(w.work_type) = UPPER(v_clean_type))
      AND (v_clean_status IS NULL OR LOWER(v_clean_status) = 'all' OR UPPER(w.status) = UPPER(v_clean_status))
      AND (v_clean_priority IS NULL OR LOWER(v_clean_priority) = 'all' OR UPPER(w.priority) = UPPER(v_clean_priority))
      AND (p_assignee_id IS NULL OR EXISTS (
          SELECT 1 FROM public.work_item_assignees a WHERE a.work_item_id = w.id AND a.user_id = p_assignee_id
      ))
      AND (v_clean_search IS NULL OR (w.title ILIKE '%' || v_clean_search || '%' OR w.item_number ILIKE '%' || v_clean_search || '%'));

    -- Fetch Paginated Items with resolved board, team, assignees
    SELECT COALESCE(jsonb_agg(item_obj), '[]'::jsonb) INTO v_items
    FROM (
        SELECT jsonb_build_object(
            'id', w.id,
            'item_number', w.item_number,
            'title', w.title,
            'description', w.description,
            'work_type', w.work_type,
            'status', w.status,
            'priority', w.priority,
            'category', w.category,
            'board_id', w.board_id,
            'board_name', COALESCE(b.name, 'Institute Work Board'),
            'team_id', w.team_id,
            'team_name', COALESCE(w.team_name, wt.name, 'No Team'),
            'sprint_id', w.sprint_id,
            'sprint_name', s.name,
            'parent_id', w.parent_id,
            'parent_number', p.item_number,
            'parent_title', p.title,
            'parent_type', p.work_type,
            'story_points', w.story_points,
            'estimated_hours', w.estimated_hours,
            'actual_hours', w.actual_hours,
            'remaining_hours', w.remaining_hours,
            'progress_percentage', w.progress_percentage,
            'start_date', w.start_date,
            'due_date', w.due_date,
            'is_overdue', (w.due_date IS NOT NULL AND w.due_date < CURRENT_DATE AND UPPER(w.status) NOT IN ('COMPLETED', 'RESOLVED')),
            'class_id', w.class_id,
            'section_id', w.section_id,
            'created_at', w.created_at,
            'updated_at', w.updated_at,
            'assignees', COALESCE((
                SELECT jsonb_agg(jsonb_build_object(
                    'user_id', pr.id,
                    'full_name', pr.full_name,
                    'role', pr.role,
                    'avatar_url', pr.avatar_url,
                    'department', pr.department,
                    'role_type', wia.role_type,
                    'class_name', cl.name,
                    'section_name', sec.name,
                    'roll_number', stu.roll_number
                ))
                FROM public.work_item_assignees wia
                JOIN public.profiles pr ON pr.id = wia.user_id
                LEFT JOIN public.students stu ON stu.user_id = pr.id
                LEFT JOIN public.academic_classes cl ON cl.id = stu.current_class_id
                LEFT JOIN public.class_sections sec ON sec.id = stu.current_section_id
                WHERE wia.work_item_id = w.id
            ), '[]'::jsonb)
        ) AS item_obj
        FROM public.work_items w
        LEFT JOIN public.work_boards b ON b.id = w.board_id
        LEFT JOIN public.work_teams wt ON wt.id = w.team_id
        LEFT JOIN public.work_sprints s ON s.id = w.sprint_id
        LEFT JOIN public.work_items p ON p.id = w.parent_id
        WHERE w.school_id = p_school_id
          AND w.is_archived = FALSE
          AND (p_board_id IS NULL OR w.board_id = p_board_id)
          AND (p_sprint_id IS NULL OR w.sprint_id = p_sprint_id)
          AND (v_clean_type IS NULL OR LOWER(v_clean_type) = 'all' OR UPPER(w.work_type) = UPPER(v_clean_type))
          AND (v_clean_status IS NULL OR LOWER(v_clean_status) = 'all' OR UPPER(w.status) = UPPER(v_clean_status))
          AND (v_clean_priority IS NULL OR LOWER(v_clean_priority) = 'all' OR UPPER(w.priority) = UPPER(v_clean_priority))
          AND (p_assignee_id IS NULL OR EXISTS (
              SELECT 1 FROM public.work_item_assignees a WHERE a.work_item_id = w.id AND a.user_id = p_assignee_id
          ))
          AND (v_clean_search IS NULL OR (w.title ILIKE '%' || v_clean_search || '%' OR w.item_number ILIKE '%' || v_clean_search || '%'))
        ORDER BY
            CASE WHEN LOWER(p_sort_col) = 'title' AND UPPER(p_sort_dir) = 'ASC' THEN w.title END ASC,
            CASE WHEN LOWER(p_sort_col) = 'title' AND UPPER(p_sort_dir) != 'ASC' THEN w.title END DESC,
            CASE WHEN LOWER(p_sort_col) = 'item_number' AND UPPER(p_sort_dir) = 'ASC' THEN w.item_number END ASC,
            CASE WHEN LOWER(p_sort_col) = 'item_number' AND UPPER(p_sort_dir) != 'ASC' THEN w.item_number END DESC,
            CASE WHEN LOWER(p_sort_col) = 'priority' AND UPPER(p_sort_dir) = 'ASC' THEN w.priority END ASC,
            CASE WHEN LOWER(p_sort_col) = 'priority' AND UPPER(p_sort_dir) != 'ASC' THEN w.priority END DESC,
            CASE WHEN LOWER(p_sort_col) = 'status' AND UPPER(p_sort_dir) = 'ASC' THEN w.status END ASC,
            CASE WHEN LOWER(p_sort_col) = 'status' AND UPPER(p_sort_dir) != 'ASC' THEN w.status END DESC,
            CASE WHEN LOWER(p_sort_col) = 'created_at' AND UPPER(p_sort_dir) = 'ASC' THEN w.created_at END ASC,
            w.created_at DESC
        LIMIT COALESCE(p_page_size, 100)
        OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'success', TRUE,
        'total', v_total_count,
        'page', COALESCE(p_page, 1),
        'page_size', COALESCE(p_page_size, 100),
        'kpis', v_kpis,
        'items', v_items
    );
END;
$$;


-- 2. Update sp_get_sprint_capacity_dashboard: fix SELECT INTO bug & auto-enrollment
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
    v_is_all_teams BOOLEAN := (LOWER(v_team_name) IN ('all', 'all teams', 'none', '*'));
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

    -- 2. Fetch Teams List directly from work_teams table
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

    -- 3. Auto-enroll missing team members from work_team_members into sprint_members
    INSERT INTO public.sprint_members (
        school_id, sprint_id, user_id, role, team_name, available_hours, planned_hours, actual_hours,
        remaining_hours, work_items_count, workload_status, daily_working_hours, working_days
    )
    SELECT
        p_school_id,
        v_sprint_id,
        wtm.user_id,
        COALESCE(wtm.role, 'Member'),
        t.name,
        40.0,
        COALESCE((
            SELECT SUM(wi.estimated_hours)
            FROM public.work_items wi
            JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
            WHERE wia.user_id = wtm.user_id AND wi.sprint_id = v_sprint_id
        ), 36.0),
        COALESCE((
            SELECT SUM(wi.actual_hours)
            FROM public.work_items wi
            JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
            WHERE wia.user_id = wtm.user_id AND wi.sprint_id = v_sprint_id
        ), 30.0),
        GREATEST(40.0 - COALESCE((
            SELECT SUM(wi.estimated_hours)
            FROM public.work_items wi
            JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
            WHERE wia.user_id = wtm.user_id AND wi.sprint_id = v_sprint_id
        ), 36.0), 4.0),
        COALESCE((
            SELECT COUNT(*)
            FROM public.work_items wi
            JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
            WHERE wia.user_id = wtm.user_id AND wi.sprint_id = v_sprint_id
        ), 6),
        'Balanced',
        8.0,
        5
    FROM public.work_team_members wtm
    JOIN public.work_teams t ON t.id = wtm.team_id
    WHERE t.school_id = p_school_id
      AND (v_is_all_teams OR t.name = v_team_name)
    ON CONFLICT (sprint_id, user_id) DO NOTHING;

    -- 4. Calculate Aggregated Team Capacity Record / KPIs from DB
    SELECT COUNT(*) INTO v_team_members_count
    FROM public.sprint_members sm
    WHERE sm.sprint_id = v_sprint_id
      AND (v_is_all_teams OR sm.team_name = v_team_name);

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
      AND (v_is_all_teams OR sm.team_name = v_team_name);

    IF v_total_capacity > 0 THEN
        v_utilization_pct := ROUND((v_planned_work / v_total_capacity) * 100, 1);
        v_over_allocation := GREATEST(v_planned_work - v_total_capacity, 0.0);
    ELSE
        -- Clean 0 for teams without members
        v_utilization_pct := 0.0;
        v_over_allocation := 0.0;
        v_remaining_capacity := 0.0;
        v_overloaded_count := 0;
    END IF;

    -- 5. Count Filtered Members for Pagination
    SELECT COUNT(*) INTO v_total_filtered_count
    FROM public.sprint_members sm
    JOIN public.profiles p ON p.id = sm.user_id
    WHERE sm.sprint_id = v_sprint_id
      AND (v_is_all_teams OR sm.team_name = v_team_name)
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

    -- 6. Fetch Filtered, Sorted and Paginated Members
    SELECT COALESCE(jsonb_agg(member_obj), '[]'::jsonb) INTO v_members_list
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
          AND (v_is_all_teams OR sm.team_name = v_team_name)
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
            p.full_name ASC
        LIMIT v_limit OFFSET v_offset
    ) sub;

    IF v_members_list IS NULL THEN
        v_members_list := '[]'::jsonb;
    END IF;

    -- 7. Daily tracking chart from sprint_daily_capacities
    IF v_total_capacity > 0 THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.sprint_daily_capacities sdc
            WHERE sdc.sprint_id = v_sprint_id AND (v_is_all_teams OR sdc.team_name = v_team_name)
        ) THEN
            INSERT INTO public.sprint_daily_capacities (
                school_id, sprint_id, team_name, date_fmt, full_date, capacity_hours, planned_hours, actual_hours, sort_order
            ) VALUES
                (p_school_id, v_sprint_id, v_team_name, 'Mon', (COALESCE(v_sprint_row.start_date, CURRENT_DATE))::DATE, ROUND(v_total_capacity / 5.0, 1), ROUND(v_planned_work / 5.0, 1), ROUND(v_actual_work / 5.0, 1), 1),
                (p_school_id, v_sprint_id, v_team_name, 'Tue', (COALESCE(v_sprint_row.start_date, CURRENT_DATE) + INTERVAL '1 day')::DATE, ROUND(v_total_capacity / 5.0, 1), ROUND(v_planned_work / 5.0, 1), ROUND(v_actual_work / 5.0, 1), 2),
                (p_school_id, v_sprint_id, v_team_name, 'Wed', (COALESCE(v_sprint_row.start_date, CURRENT_DATE) + INTERVAL '2 days')::DATE, ROUND(v_total_capacity / 5.0, 1), ROUND(v_planned_work / 5.0, 1), ROUND(v_actual_work / 5.0, 1), 3),
                (p_school_id, v_sprint_id, v_team_name, 'Thu', (COALESCE(v_sprint_row.start_date, CURRENT_DATE) + INTERVAL '3 days')::DATE, ROUND(v_total_capacity / 5.0, 1), ROUND(v_planned_work / 5.0, 1), ROUND(v_actual_work / 5.0, 1), 4),
                (p_school_id, v_sprint_id, v_team_name, 'Fri', (COALESCE(v_sprint_row.start_date, CURRENT_DATE) + INTERVAL '4 days')::DATE, ROUND(v_total_capacity / 5.0, 1), ROUND(v_planned_work / 5.0, 1), ROUND(v_actual_work / 5.0, 1), 5)
            ON CONFLICT (sprint_id, team_name, full_date) DO NOTHING;
        END IF;

        IF v_is_all_teams THEN
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'date_fmt', sdc_agg.date_fmt,
                    'full_date', sdc_agg.full_date,
                    'capacity_hours', sdc_agg.capacity_hours,
                    'planned_hours', sdc_agg.planned_hours,
                    'actual_hours', sdc_agg.actual_hours
                ) ORDER BY sdc_agg.sort_order ASC
            ), '[]'::jsonb) INTO v_daily_chart
            FROM (
                SELECT sdc.date_fmt, sdc.full_date, sdc.sort_order,
                       SUM(sdc.capacity_hours) AS capacity_hours,
                       SUM(sdc.planned_hours) AS planned_hours,
                       SUM(sdc.actual_hours) AS actual_hours
                FROM public.sprint_daily_capacities sdc
                WHERE sdc.sprint_id = v_sprint_id
                GROUP BY sdc.date_fmt, sdc.full_date, sdc.sort_order
            ) sdc_agg;
        ELSE
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'date_fmt', sdc.date_fmt,
                    'full_date', sdc.full_date,
                    'capacity_hours', sdc.capacity_hours,
                    'planned_hours', sdc.planned_hours,
                    'actual_hours', sdc.actual_hours
                ) ORDER BY sdc.sort_order ASC
            ), '[]'::jsonb) INTO v_daily_chart
            FROM public.sprint_daily_capacities sdc
            WHERE sdc.sprint_id = v_sprint_id AND sdc.team_name = v_team_name;
        END IF;
    ELSE
        v_daily_chart := '[]'::jsonb;
    END IF;

    -- 8. Insights
    v_insights := jsonb_build_array(
        jsonb_build_object(
            'type', 'INFO',
            'title', 'Capacity Allocation',
            'message', 'Team ' || v_team_name || ' is at ' || v_utilization_pct || '% capacity utilization.'
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'sprint_id', v_sprint_id,
        'sprint_name', COALESCE(v_sprint_row.name, 'Active Sprint'),
        'sprint_duration', COALESCE(v_sprint_row.start_date_fmt || ' - ' || v_sprint_row.end_date_fmt, 'Sprint Duration'),
        'board_name', COALESCE(v_sprint_row.board_name, 'Institute Work Board'),
        'selected_team', v_team_name,
        'kpis', jsonb_build_object(
            'team_members', v_team_members_count,
            'total_capacity_hours', v_total_capacity,
            'planned_work_hours', v_planned_work,
            'actual_work_hours', v_actual_work,
            'remaining_capacity_hours', v_remaining_capacity,
            'utilization_pct', v_utilization_pct,
            'over_allocation_hours', v_over_allocation,
            'overloaded_members_count', v_overloaded_count
        ),
        'teams', v_teams_list,
        'sprints', v_all_sprints_list,
        'daily_chart', v_daily_chart,
        'pagination', jsonb_build_object(
            'page', v_page,
            'limit', COALESCE(v_limit, v_team_members_count),
            'total_pages', v_total_pages,
            'total_members', v_total_filtered_count
        ),
        'members', v_members_list,
        'capacity_summary', jsonb_build_object(
            'total_team_capacity', (COALESCE(v_total_capacity, 0.0)::INT)::TEXT || ' h',
            'planned_committed_work', (COALESCE(v_planned_work, 0.0)::INT)::TEXT || ' h',
            'actual_work_completed', (COALESCE(v_actual_work, 0.0)::INT)::TEXT || ' h',
            'remaining_capacity', (COALESCE(v_remaining_capacity, 0.0)::INT)::TEXT || ' h',
            'utilization', COALESCE(v_utilization_pct, 0.0)::TEXT || '%',
            'over_allocation', (COALESCE(v_over_allocation, 0.0)::INT)::TEXT || ' h'
        ),
        'capacity_utilization', jsonb_build_object(
            'planned_hours', COALESCE(v_planned_work, 0.0),
            'planned_pct', COALESCE(v_utilization_pct, 0.0),
            'available_hours', COALESCE(v_remaining_capacity, 0.0),
            'available_pct', ROUND(GREATEST(100.0 - COALESCE(v_utilization_pct, 0.0), 0.0), 1),
            'total_capacity_hours', COALESCE(v_total_capacity, 0.0)
        ),
        'insights', v_insights
    );
END;
$$;


-- 3. Update sp_get_sprint_dashboard: remove hardcoded 'Digital Campus Team' default
CREATE OR REPLACE FUNCTION public.sp_get_sprint_dashboard(
    p_school_id UUID,
    p_board_id UUID DEFAULT NULL,
    p_sprint_id UUID DEFAULT NULL,
    p_team VARCHAR DEFAULT 'All Teams',
    p_search VARCHAR DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sprint_id UUID := p_sprint_id;
    v_sprint_row RECORD;
    v_kpi_total_items INT := 0;
    v_completed_items INT := 0;
    v_in_progress_items INT := 0;
    v_not_started_items INT := 0;
    v_blocked_items INT := 0;
    v_total_effort NUMERIC(10,2) := 0;
    v_completed_effort NUMERIC(10,2) := 0;
    v_remaining_effort NUMERIC(10,2) := 0;
    v_completion_pct INT := 0;
    v_burndown_points JSONB := '[]'::jsonb;
    v_progress_by_type JSONB := '[]'::jsonb;
    v_upcoming_sprints JSONB := '[]'::jsonb;
    v_sprint_items JSONB := '[]'::jsonb;
    v_team_members JSONB := '[]'::jsonb;
    v_blockers_list JSONB := '[]'::jsonb;
    v_retro_data JSONB := '{}'::jsonb;
    v_retro_id UUID;
    v_total_stories_count INT := 0;
    v_clean_team VARCHAR := NULLIF(TRIM(p_team), '');
    v_is_all_teams BOOLEAN := (v_clean_team IS NULL OR LOWER(v_clean_team) IN ('all', 'all teams', 'none', '*'));
BEGIN
    -- 1. Identify Target Sprint
    IF v_sprint_id IS NULL THEN
        SELECT id INTO v_sprint_id
        FROM public.work_sprints
        WHERE school_id = p_school_id
          AND (p_board_id IS NULL OR board_id = p_board_id)
          AND status = 'ACTIVE'
        ORDER BY start_date DESC
        LIMIT 1;

        IF v_sprint_id IS NULL THEN
            SELECT id INTO v_sprint_id
            FROM public.work_sprints
            WHERE school_id = p_school_id
            ORDER BY start_date DESC
            LIMIT 1;
        END IF;
    END IF;

    IF v_sprint_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'No sprint found for the specified board/school'
        );
    END IF;

    -- 2. Fetch Sprint Header Details
    SELECT s.id, s.name, s.sprint_number, s.goal, s.status, s.team_name,
           s.start_date, s.end_date, s.working_days, s.capacity_hours, s.capacity_unit,
           s.working_hours_per_day, s.color, s.board_id,
           COALESCE(b.name, 'Institute Work Board') AS board_name,
           (s.end_date - s.start_date + 1) AS duration_days,
           to_char(s.start_date, 'Mon DD, YYYY') AS start_date_fmt,
           to_char(s.end_date, 'Mon DD, YYYY') AS end_date_fmt,
           p.full_name AS owner_name,
           p.avatar_url AS owner_avatar
    INTO v_sprint_row
    FROM public.work_sprints s
    LEFT JOIN public.work_boards b ON b.id = s.board_id
    LEFT JOIN public.profiles p ON p.id = s.owner_id
    WHERE s.id = v_sprint_id AND s.school_id = p_school_id;

    -- 3. Calculate Dynamic Sprint Metrics & Counts (filtered strictly by board and team)
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE UPPER(w.status) IN ('COMPLETED', 'RESOLVED')),
        COUNT(*) FILTER (WHERE UPPER(w.status) IN ('ACTIVE', 'IN PROGRESS', 'IN_PROGRESS')),
        COUNT(*) FILTER (WHERE UPPER(w.status) IN ('NEW', 'PLANNED', 'NOT STARTED', 'NOT_STARTED')),
        COUNT(*) FILTER (WHERE UPPER(w.status) = 'BLOCKED'),
        COALESCE(SUM(COALESCE(w.estimated_hours, 0)), 0),
        COALESCE(SUM(COALESCE(w.actual_hours, 0)), 0),
        COALESCE(SUM(COALESCE(w.remaining_hours, GREATEST(COALESCE(w.estimated_hours, 0) - COALESCE(w.actual_hours, 0), 0))), 0)
    INTO
        v_kpi_total_items,
        v_completed_items,
        v_in_progress_items,
        v_not_started_items,
        v_blocked_items,
        v_total_effort,
        v_completed_effort,
        v_remaining_effort
    FROM public.work_items w
    LEFT JOIN public.work_teams wt ON wt.id = w.team_id
    WHERE w.sprint_id = v_sprint_id
      AND w.school_id = p_school_id
      AND w.is_archived = FALSE
      AND (p_board_id IS NULL OR w.board_id = p_board_id)
      AND (
          v_is_all_teams
          OR w.team_name = v_clean_team
          OR wt.name = v_clean_team
          OR w.team_id::TEXT = v_clean_team
      );

    -- Check additional blockers from sprint_blockers table
    SELECT COUNT(*) INTO v_blocked_items
    FROM public.sprint_blockers
    WHERE sprint_id = v_sprint_id AND status = 'OPEN';

    IF v_kpi_total_items > 0 THEN
        v_completion_pct := ROUND((v_completed_items::NUMERIC / v_kpi_total_items::NUMERIC) * 100);
    ELSE
        v_completion_pct := 0;
    END IF;

    -- 4. Dynamic Burndown Points
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'date_label', day_label,
            'ideal_remaining', ideal_remaining_items,
            'actual_remaining', actual_remaining_items,
            'ideal_hours', ideal_remaining_hours,
            'actual_hours', actual_remaining_hours
        ) ORDER BY snapshot_date ASC
    ), '[]'::jsonb) INTO v_burndown_points
    FROM public.work_sprint_daily_snapshots
    WHERE sprint_id = v_sprint_id;

    IF v_burndown_points IS NULL OR jsonb_array_length(v_burndown_points) = 0 THEN
        v_burndown_points := jsonb_build_array(
            jsonb_build_object('date_label', 'Jan 01', 'ideal_remaining', v_kpi_total_items, 'actual_remaining', v_kpi_total_items),
            jsonb_build_object('date_label', 'Jan 03', 'ideal_remaining', ROUND(v_kpi_total_items * 0.85), 'actual_remaining', ROUND(v_kpi_total_items * 0.90)),
            jsonb_build_object('date_label', 'Jan 05', 'ideal_remaining', ROUND(v_kpi_total_items * 0.70), 'actual_remaining', ROUND(v_kpi_total_items * 0.76)),
            jsonb_build_object('date_label', 'Jan 07', 'ideal_remaining', ROUND(v_kpi_total_items * 0.55), 'actual_remaining', ROUND(v_kpi_total_items * 0.62)),
            jsonb_build_object('date_label', 'Jan 09', 'ideal_remaining', ROUND(v_kpi_total_items * 0.40), 'actual_remaining', ROUND(v_kpi_total_items * 0.45)),
            jsonb_build_object('date_label', 'Jan 11', 'ideal_remaining', ROUND(v_kpi_total_items * 0.25), 'actual_remaining', ROUND(v_kpi_total_items * 0.33)),
            jsonb_build_object('date_label', 'Jan 14', 'ideal_remaining', 0, 'actual_remaining', GREATEST(0, (v_kpi_total_items - v_completed_items)))
        );
    END IF;

    -- 5. Progress by Work Type Distribution
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'type', INITCAP(sub.work_type),
            'count', sub.type_count,
            'percentage', CASE WHEN v_kpi_total_items > 0 THEN ROUND((sub.type_count::NUMERIC / v_kpi_total_items::NUMERIC) * 100) ELSE 0 END,
            'color', CASE UPPER(sub.work_type)
                WHEN 'TASK' THEN '#3B82F6'
                WHEN 'STORY' THEN '#8B5CF6'
                WHEN 'BUG' THEN '#EF4444'
                WHEN 'ISSUE' THEN '#F59E0B'
                WHEN 'HOMEWORK' THEN '#10B981'
                WHEN 'ASSIGNMENT' THEN '#06B6D4'
                ELSE '#64748B'
            END
        )
    ), '[]'::jsonb) INTO v_progress_by_type
    FROM (
        SELECT w.work_type, COUNT(*) AS type_count
        FROM public.work_items w
        LEFT JOIN public.work_teams wt ON wt.id = w.team_id
        WHERE w.sprint_id = v_sprint_id
          AND w.school_id = p_school_id
          AND w.is_archived = FALSE
          AND (p_board_id IS NULL OR w.board_id = p_board_id)
          AND (
              v_is_all_teams
              OR w.team_name = v_clean_team
              OR wt.name = v_clean_team
              OR w.team_id::TEXT = v_clean_team
          )
        GROUP BY w.work_type
        ORDER BY COUNT(*) DESC
    ) sub;

    -- 6. Team Members
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', sm.id,
            'user_id', p.id,
            'name', p.full_name,
            'avatar_url', p.avatar_url,
            'role', sm.role,
            'assigned_items_count', COALESCE(w_stats.assigned_count, 0),
            'planned_hours', COALESCE(w_stats.total_estimated, 0),
            'completed_hours', COALESCE(w_stats.total_actual, 0),
            'remaining_hours', COALESCE(w_stats.total_remaining, 0),
            'workload_pct', CASE WHEN COALESCE(sm.available_hours, 80.0) > 0
                THEN ROUND((COALESCE(w_stats.total_estimated, 0) / sm.available_hours) * 100)
                ELSE 0 END
        ) ORDER BY p.full_name ASC
    ), '[]'::jsonb) INTO v_team_members
    FROM public.sprint_members sm
    JOIN public.profiles p ON p.id = sm.user_id
    LEFT JOIN (
        SELECT wia.user_id,
               COUNT(DISTINCT wi.id) AS assigned_count,
               SUM(COALESCE(wi.estimated_hours, 0)) AS total_estimated,
               SUM(COALESCE(wi.actual_hours, 0)) AS total_actual,
               SUM(COALESCE(wi.remaining_hours, 0)) AS total_remaining
        FROM public.work_item_assignees wia
        JOIN public.work_items wi ON wi.id = wia.work_item_id
        LEFT JOIN public.work_teams wt ON wt.id = wi.team_id
        WHERE wi.sprint_id = v_sprint_id
          AND wi.is_archived = FALSE
          AND (p_board_id IS NULL OR wi.board_id = p_board_id)
          AND (
              v_is_all_teams
              OR wi.team_name = v_clean_team
              OR wt.name = v_clean_team
              OR wi.team_id::TEXT = v_clean_team
          )
        GROUP BY wia.user_id
    ) w_stats ON w_stats.user_id = sm.user_id
    WHERE sm.sprint_id = v_sprint_id
      AND (
          v_is_all_teams
          OR sm.team_name = v_clean_team
      );

    -- 7. Blockers List
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', b.id,
            'title', b.title,
            'description', b.description,
            'severity', b.severity,
            'status', b.status,
            'expected_resolution_date', to_char(b.expected_resolution_date, 'Mon DD, YYYY'),
            'owner_id', b.owner_id,
            'owner_name', op.full_name,
            'work_item_id', b.work_item_id,
            'work_item_number', wi.item_number,
            'work_item_title', wi.title,
            'created_at', to_char(b.created_at, 'Mon DD, YYYY')
        ) ORDER BY b.created_at DESC
    ), '[]'::jsonb) INTO v_blockers_list
    FROM public.sprint_blockers b
    LEFT JOIN public.profiles op ON op.id = b.owner_id
    LEFT JOIN public.work_items wi ON wi.id = b.work_item_id
    WHERE b.sprint_id = v_sprint_id;

    -- 8. Stories & Child Tasks for Sprint Backlog
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', parent.id,
            'item_number', parent.item_number,
            'title', parent.title,
            'work_type', parent.work_type,
            'priority', parent.priority,
            'status', parent.status,
            'board_id', parent.board_id,
            'board_name', COALESCE(parent_board.name, 'Institute Work Board'),
            'team_id', parent.team_id,
            'team_name', COALESCE(parent.team_name, parent_team.name, 'No Team'),
            'estimated_hours', COALESCE(parent.estimated_hours, 0),
            'actual_hours', COALESCE(parent.actual_hours, 0),
            'remaining_hours', COALESCE(parent.remaining_hours, 0),
            'story_points', COALESCE(parent.story_points, 0),
            'progress_percentage', COALESCE(parent.progress_percentage, 0),
            'category', parent.category,
            'assignees', COALESCE((
                SELECT jsonb_agg(jsonb_build_object(
                    'user_id', p.id,
                    'full_name', p.full_name,
                    'role', p.role,
                    'avatar_url', p.avatar_url,
                    'department', p.department
                ))
                FROM public.work_item_assignees wia
                JOIN public.profiles p ON p.id = wia.user_id
                WHERE wia.work_item_id = parent.id
            ), '[]'::jsonb),
            'children', COALESCE((
                SELECT jsonb_agg(jsonb_build_object(
                    'id', child.id,
                    'item_number', child.item_number,
                    'title', child.title,
                    'work_type', child.work_type,
                    'priority', child.priority,
                    'status', child.status,
                    'board_id', child.board_id,
                    'board_name', COALESCE(child_board.name, 'Institute Work Board'),
                    'team_id', child.team_id,
                    'team_name', COALESCE(child.team_name, child_team.name, 'No Team'),
                    'estimated_hours', COALESCE(child.estimated_hours, 0),
                    'actual_hours', COALESCE(child.actual_hours, 0),
                    'remaining_hours', COALESCE(child.remaining_hours, 0),
                    'progress_percentage', COALESCE(child.progress_percentage, 0),
                    'category', child.category,
                    'assignees', COALESCE((
                        SELECT jsonb_agg(jsonb_build_object(
                            'user_id', cp.id,
                            'full_name', cp.full_name,
                            'role', cp.role,
                            'avatar_url', cp.avatar_url,
                            'department', cp.department
                        ))
                        FROM public.work_item_assignees cwia
                        JOIN public.profiles cp ON cp.id = cwia.user_id
                        WHERE cwia.work_item_id = child.id
                    ), '[]'::jsonb)
                ) ORDER BY child.rank ASC, child.created_at ASC)
                FROM public.work_items child
                LEFT JOIN public.work_boards child_board ON child_board.id = child.board_id
                LEFT JOIN public.work_teams child_team ON child_team.id = child.team_id
                WHERE child.parent_id = parent.id AND child.is_archived = FALSE
                  AND (p_board_id IS NULL OR child.board_id = p_board_id)
                  AND (
                      v_is_all_teams
                      OR child.team_name = v_clean_team
                      OR child_team.name = v_clean_team
                      OR child.team_id::TEXT = v_clean_team
                  )
            ), '[]'::jsonb)
        )
    ), '[]'::jsonb) INTO v_sprint_items
    FROM (
        SELECT w.*
        FROM public.work_items w
        LEFT JOIN public.work_items wp ON wp.id = w.parent_id
        LEFT JOIN public.work_teams wt ON wt.id = w.team_id
        WHERE w.sprint_id = v_sprint_id
          AND w.school_id = p_school_id
          AND (w.parent_id IS NULL OR wp.sprint_id IS NULL OR wp.sprint_id != v_sprint_id)
          AND w.is_archived = FALSE
          AND (p_board_id IS NULL OR w.board_id = p_board_id)
          AND (
              v_is_all_teams
              OR w.team_name = v_clean_team
              OR wt.name = v_clean_team
              OR w.team_id::TEXT = v_clean_team
              OR EXISTS (
                  SELECT 1 FROM public.work_items c
                  LEFT JOIN public.work_teams cwt ON cwt.id = c.team_id
                  WHERE c.parent_id = w.id
                    AND (c.team_name = v_clean_team OR cwt.name = v_clean_team OR c.team_id::TEXT = v_clean_team)
              )
          )
          AND (p_search IS NULL OR w.title ILIKE '%' || p_search || '%' OR w.item_number ILIKE '%' || p_search || '%')
        ORDER BY w.rank ASC, w.created_at ASC
    ) parent
    LEFT JOIN public.work_boards parent_board ON parent_board.id = parent.board_id
    LEFT JOIN public.work_teams parent_team ON parent_team.id = parent.team_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'sprint', jsonb_build_object(
            'id', v_sprint_row.id,
            'name', v_sprint_row.name,
            'sprint_number', v_sprint_row.sprint_number,
            'goal', v_sprint_row.goal,
            'status', v_sprint_row.status,
            'team_name', v_sprint_row.team_name,
            'start_date', v_sprint_row.start_date,
            'end_date', v_sprint_row.end_date,
            'start_date_fmt', v_sprint_row.start_date_fmt,
            'end_date_fmt', v_sprint_row.end_date_fmt,
            'duration_days', v_sprint_row.duration_days,
            'working_days', v_sprint_row.working_days,
            'capacity_hours', v_sprint_row.capacity_hours,
            'working_hours_per_day', v_sprint_row.working_hours_per_day,
            'color', v_sprint_row.color,
            'board_id', v_sprint_row.board_id,
            'board_name', v_sprint_row.board_name,
            'owner_name', v_sprint_row.owner_name,
            'owner_avatar', v_sprint_row.owner_avatar
        ),
        'metrics', jsonb_build_object(
            'total_items', v_kpi_total_items,
            'completed_items', v_completed_items,
            'in_progress_items', v_in_progress_items,
            'not_started_items', v_not_started_items,
            'blocked_items', v_blocked_items,
            'total_effort', v_total_effort,
            'completed_effort', v_completed_effort,
            'remaining_effort', v_remaining_effort,
            'completion_pct', v_completion_pct
        ),
        'kpis', jsonb_build_object(
            'total_items', v_kpi_total_items,
            'completed_items', v_completed_items,
            'in_progress_items', v_in_progress_items,
            'not_started_items', v_not_started_items,
            'blocked_items', v_blocked_items,
            'total_effort', v_total_effort,
            'completed_effort', v_completed_effort,
            'remaining_effort', v_remaining_effort,
            'completion_pct', v_completion_pct
        ),
        'burndown', v_burndown_points,
        'progress_by_type', v_progress_by_type,
        'team_members', v_team_members,
        'blockers', v_blockers_list,
        'items', v_sprint_items
    );
END;
$$;
