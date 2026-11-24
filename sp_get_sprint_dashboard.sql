CREATE OR REPLACE FUNCTION public.sp_get_sprint_dashboard(p_school_id uuid, p_board_id uuid DEFAULT NULL::uuid, p_sprint_id uuid DEFAULT NULL::uuid, p_team character varying DEFAULT 'All Teams'::character varying, p_search character varying DEFAULT NULL::character varying, p_page integer DEFAULT 1, p_page_size integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
        COUNT(*) FILTER (WHERE UPPER(w.status) IN ('COMPLETED', 'RESOLVED', 'CLOSED', 'DONE')),
        COUNT(*) FILTER (WHERE UPPER(w.status) IN ('ACTIVE', 'IN PROGRESS', 'IN_PROGRESS', 'DOING', 'CRITICAL')),
        COUNT(*) FILTER (WHERE UPPER(w.status) IN ('NEW', 'OPEN', 'PLANNED', 'NOT STARTED', 'NOT_STARTED', 'TODO')),
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
            'date_label', d.dt_label,
            'day_index', d.day_idx,
            'ideal_remaining', ROUND(GREATEST(0, v_total_effort - ((v_total_effort / GREATEST(1, v_sprint_row.duration_days)) * d.day_idx)), 1),
            'actual_remaining', CASE
                WHEN d.dt <= CURRENT_DATE THEN ROUND(GREATEST(0, v_total_effort - (v_completed_effort * (d.day_idx::NUMERIC / GREATEST(1, v_sprint_row.duration_days)))), 1)
                ELSE NULL
            END
        ) ORDER BY d.day_idx ASC
    ), '[]'::jsonb) INTO v_burndown_points
    FROM (
        SELECT
            (v_sprint_row.start_date + (i || ' day')::INTERVAL)::DATE AS dt,
            to_char((v_sprint_row.start_date + (i || ' day')::INTERVAL)::DATE, 'Mon DD') AS dt_label,
            i AS day_idx
        FROM generate_series(0, LEAST(14, GREATEST(1, v_sprint_row.duration_days))) i
    ) d;

    -- 5. Progress by Work Type (Donut data)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'work_type', t.work_type,
            'count', t.cnt,
            'completed_count', t.comp_cnt,
            'percentage', CASE WHEN t.cnt > 0 THEN ROUND((t.comp_cnt::NUMERIC / t.cnt::NUMERIC) * 100) ELSE 0 END
        )
    ), '[]'::jsonb) INTO v_progress_by_type
    FROM (
        SELECT
            w.work_type,
            COUNT(*) AS cnt,
            COUNT(*) FILTER (WHERE UPPER(w.status) IN ('COMPLETED', 'RESOLVED', 'CLOSED', 'DONE')) AS comp_cnt
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
    ) t;

    -- 6. Team Members
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'name', p.full_name,
            'role', p.role,
            'avatar_url', p.avatar_url,
            'assigned_items_count', COALESCE(am.cnt, 0),
            'capacity_hours', COALESCE(sm.available_hours, 80.0),
            'assigned_hours', COALESCE(am.effort, 0.0),
            'completed_hours', COALESCE(am.comp_effort, 0.0)
        )
    ), '[]'::jsonb) INTO v_team_members
    FROM public.sprint_members sm
    JOIN public.profiles p ON p.id = sm.user_id
    LEFT JOIN (
        SELECT wia.user_id,
               COUNT(DISTINCT w.id) AS cnt,
               COALESCE(SUM(w.estimated_hours), 0) AS effort,
               COALESCE(SUM(CASE WHEN UPPER(w.status) IN ('COMPLETED', 'RESOLVED', 'CLOSED', 'DONE') THEN w.actual_hours ELSE 0 END), 0) AS comp_effort
        FROM public.work_item_assignees wia
        JOIN public.work_items w ON w.id = wia.work_item_id
        LEFT JOIN public.work_teams wt ON wt.id = w.team_id
        WHERE w.sprint_id = v_sprint_id AND w.is_archived = FALSE
          AND (p_board_id IS NULL OR w.board_id = p_board_id)
          AND (v_is_all_teams OR w.team_name = v_clean_team OR wt.name = v_clean_team OR w.team_id::TEXT = v_clean_team)
        GROUP BY wia.user_id
    ) am ON am.user_id = sm.user_id
    WHERE sm.sprint_id = v_sprint_id;

    -- 7. Sprint Blockers
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', b.id,
            'work_item_id', b.work_item_id,
            'title', b.title,
            'description', b.description,
            'severity', b.severity,
            'status', b.status,
            'owner_name', p.full_name,
            'owner_avatar', p.avatar_url,
            'created_at', to_char(b.created_at, 'Mon DD, YYYY')
        )
    ), '[]'::jsonb) INTO v_blockers_list
    FROM public.sprint_blockers b
    LEFT JOIN public.profiles p ON p.id = b.owner_id
    WHERE b.sprint_id = v_sprint_id;

    -- 8. Sprint Backlog Hierarchical Items
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', parent.id,
            'item_number', parent.item_number,
            'title', parent.title,
            'description', parent.description,
            'work_type', parent.work_type,
            'status', parent.status,
            'priority', parent.priority,
            'category', parent.category,
            'board_id', parent.board_id,
            'board_name', COALESCE(parent_board.name, 'Institute Work Board'),
            'team_id', parent.team_id,
            'team_name', COALESCE(parent.team_name, parent_team.name, 'No Team'),
            'rank', parent.rank,
            'story_points', parent.story_points,
            'estimated_hours', parent.estimated_hours,
            'actual_hours', parent.actual_hours,
            'remaining_hours', parent.remaining_hours,
            'progress_percentage', parent.progress_percentage,
            'due_date_fmt', to_char(parent.due_date, 'Mon DD, YYYY'),
            'start_date_fmt', to_char(parent.start_date, 'Mon DD, YYYY'),
            'is_overdue', (parent.due_date IS NOT NULL AND parent.due_date < CURRENT_DATE AND UPPER(parent.status) NOT IN ('COMPLETED', 'RESOLVED', 'CLOSED', 'DONE')),
            'assignees', COALESCE((
                SELECT jsonb_agg(jsonb_build_object(
                    'user_id', pp.id,
                    'full_name', pp.full_name,
                    'role', pp.role,
                    'avatar_url', pp.avatar_url,
                    'department', pp.department
                ))
                FROM public.work_item_assignees pwia
                JOIN public.profiles pp ON pp.id = pwia.user_id
                WHERE pwia.work_item_id = parent.id
            ), '[]'::jsonb),
            'children', COALESCE((
                SELECT jsonb_agg(jsonb_build_object(
                    'id', child.id,
                    'item_number', child.item_number,
                    'title', child.title,
                    'work_type', child.work_type,
                    'status', child.status,
                    'priority', child.priority,
                    'category', child.category,
                    'board_id', child.board_id,
                    'board_name', COALESCE(child_board.name, 'Institute Work Board'),
                    'team_id', child.team_id,
                    'team_name', COALESCE(child.team_name, child_team.name, 'No Team'),
                    'rank', child.rank,
                    'progress_percentage', child.progress_percentage,
                    'estimated_hours', child.estimated_hours,
                    'actual_hours', child.actual_hours,
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
$function$
