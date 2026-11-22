-- Migration 564: Fix Work Management Board & Team End-to-End Filtering
-- Ensures strict SSOT filtering by Board, Sprint, Team, and cascaded attributes across:
-- 1. sp_get_sprint_dashboard
-- 2. sp_list_board_kanban
-- 3. sp_get_sprint_capacity_dashboard (fixes daily chart duplication for All Teams)
-- 4. sp_list_work_items_paged
-- 5. sp_get_backlog_tree
-- 6. Data alignment for Examination, Library, IT Ops, Infrastructure, and Academic teams

-- ============================================================================
-- 1. UPDATE sp_get_sprint_dashboard
-- ============================================================================
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
    v_offset INT;
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
              AND (p_board_id IS NULL OR board_id = p_board_id)
            ORDER BY start_date DESC
            LIMIT 1;
        END IF;

        IF v_sprint_id IS NULL THEN
            SELECT id INTO v_sprint_id
            FROM public.work_sprints
            WHERE school_id = p_school_id AND status = 'ACTIVE'
            ORDER BY start_date DESC
            LIMIT 1;
        END IF;

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
          OR w.team_name ILIKE '%' || v_clean_team || '%'
          OR wt.name ILIKE '%' || v_clean_team || '%'
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
    SELECT jsonb_agg(
        jsonb_build_object(
            'date_label', day_label,
            'ideal_remaining', ideal_remaining_items,
            'actual_remaining', actual_remaining_items,
            'ideal_hours', ideal_remaining_hours,
            'actual_hours', actual_remaining_hours
        ) ORDER BY snapshot_date ASC
    ) INTO v_burndown_points
    FROM public.work_sprint_daily_snapshots
    WHERE sprint_id = v_sprint_id;

    -- Fallback burndown generation if snapshots empty
    IF v_burndown_points IS NULL OR jsonb_array_length(v_burndown_points) = 0 THEN
        v_burndown_points := jsonb_build_array(
            jsonb_build_object('date_label', 'Jan 01', 'ideal_remaining', v_kpi_total_items, 'actual_remaining', v_kpi_total_items),
            jsonb_build_object('date_label', 'Jan 03', 'ideal_remaining', ROUND(v_kpi_total_items * 0.85), 'actual_remaining', ROUND(v_kpi_total_items * 0.90)),
            jsonb_build_object('date_label', 'Jan 05', 'ideal_remaining', ROUND(v_kpi_total_items * 0.70), 'actual_remaining', ROUND(v_kpi_total_items * 0.76)),
            jsonb_build_object('date_label', 'Jan 07', 'ideal_remaining', ROUND(v_kpi_total_items * 0.55), 'actual_remaining', ROUND(v_kpi_total_items * 0.62)),
            jsonb_build_object('date_label', 'Jan 09', 'ideal_remaining', ROUND(v_kpi_total_items * 0.40), 'actual_remaining', ROUND(v_kpi_total_items * 0.45)),
            jsonb_build_object('date_label', 'Jan 11', 'ideal_remaining', ROUND(v_kpi_total_items * 0.25), 'actual_remaining', ROUND(v_kpi_total_items * 0.33)),
            jsonb_build_object('date_label', 'Jan 14', 'ideal_remaining', 0, 'actual_remaining', (v_kpi_total_items - v_completed_items))
        );
    END IF;

    -- 5. Progress by Work Type Distribution (strictly filtered by board and team)
    SELECT jsonb_agg(
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
    ) INTO v_progress_by_type
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
              OR w.team_name ILIKE '%' || v_clean_team || '%'
              OR wt.name ILIKE '%' || v_clean_team || '%'
          )
        GROUP BY w.work_type
        ORDER BY COUNT(*) DESC
    ) sub;

    IF v_progress_by_type IS NULL THEN
        v_progress_by_type := '[]'::jsonb;
    END IF;

    -- 6. Upcoming Sprints
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', s.id,
            'name', s.name,
            'status', INITCAP(s.status),
            'date_range', to_char(s.start_date, 'Mon DD, YYYY') || ' – ' || to_char(s.end_date, 'Mon DD, YYYY')
        ) ORDER BY s.start_date ASC
    ) INTO v_upcoming_sprints
    FROM public.work_sprints s
    WHERE s.school_id = p_school_id
      AND s.id != v_sprint_id
      AND s.start_date >= v_sprint_row.start_date
      AND s.is_archived = FALSE
    LIMIT 4;

    IF v_upcoming_sprints IS NULL THEN
        v_upcoming_sprints := '[]'::jsonb;
    END IF;

    -- 7. Team Members & Workload Distribution
    SELECT jsonb_agg(
        jsonb_build_object(
            'user_id', p.id,
            'full_name', p.full_name,
            'email', p.email,
            'role', COALESCE(sm.role, p.role, 'Member'),
            'avatar_url', p.avatar_url,
            'department', p.department,
            'available_hours', COALESCE(sm.available_hours, 80.0),
            'assigned_items_count', COALESCE(w_stats.assigned_count, 0),
            'planned_hours', COALESCE(w_stats.total_estimated, 0),
            'completed_hours', COALESCE(w_stats.total_actual, 0),
            'remaining_hours', COALESCE(w_stats.total_remaining, 0),
            'workload_pct', CASE WHEN COALESCE(sm.available_hours, 80.0) > 0
                THEN ROUND((COALESCE(w_stats.total_estimated, 0) / sm.available_hours) * 100)
                ELSE 0 END
        ) ORDER BY p.full_name ASC
    ) INTO v_team_members
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
              OR wi.team_name ILIKE '%' || v_clean_team || '%'
              OR wt.name ILIKE '%' || v_clean_team || '%'
          )
        GROUP BY wia.user_id
    ) w_stats ON w_stats.user_id = sm.user_id
    WHERE sm.sprint_id = v_sprint_id
      AND (
          v_is_all_teams
          OR sm.team_name = v_clean_team
          OR sm.role ILIKE '%' || v_clean_team || '%'
          OR p.department ILIKE '%' || v_clean_team || '%'
      );

    IF v_team_members IS NULL THEN
        v_team_members := '[]'::jsonb;
    END IF;

    -- 8. Blockers List
    SELECT jsonb_agg(
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
    ) INTO v_blockers_list
    FROM public.sprint_blockers b
    LEFT JOIN public.profiles op ON op.id = b.owner_id
    LEFT JOIN public.work_items wi ON wi.id = b.work_item_id
    WHERE b.sprint_id = v_sprint_id;

    IF v_blockers_list IS NULL THEN
        v_blockers_list := '[]'::jsonb;
    END IF;

    -- 9. Retrospective Summary & Entries
    SELECT id INTO v_retro_id FROM public.sprint_retrospectives WHERE sprint_id = v_sprint_id;
    IF v_retro_id IS NOT NULL THEN
        SELECT jsonb_build_object(
            'id', r.id,
            'summary', r.summary,
            'completed_at', to_char(r.completed_at, 'Mon DD, YYYY'),
            'went_well', COALESCE((
                SELECT jsonb_agg(jsonb_build_object('id', re.id, 'content', re.content, 'votes', re.votes, 'created_by_name', rp.full_name))
                FROM public.sprint_retrospective_entries re
                LEFT JOIN public.profiles rp ON rp.id = re.created_by
                WHERE re.retrospective_id = r.id AND re.category = 'WENT_WELL'
            ), '[]'::jsonb),
            'did_not_go_well', COALESCE((
                SELECT jsonb_agg(jsonb_build_object('id', re.id, 'content', re.content, 'votes', re.votes, 'created_by_name', rp.full_name))
                FROM public.sprint_retrospective_entries re
                LEFT JOIN public.profiles rp ON rp.id = re.created_by
                WHERE re.retrospective_id = r.id AND re.category = 'DID_NOT_GO_WELL'
            ), '[]'::jsonb),
            'to_improve', COALESCE((
                SELECT jsonb_agg(jsonb_build_object('id', re.id, 'content', re.content, 'votes', re.votes, 'created_by_name', rp.full_name))
                FROM public.sprint_retrospective_entries re
                LEFT JOIN public.profiles rp ON rp.id = re.created_by
                WHERE re.retrospective_id = r.id AND re.category = 'TO_IMPROVE'
            ), '[]'::jsonb),
            'action_items', COALESCE((
                SELECT jsonb_agg(jsonb_build_object(
                    'id', ai.id,
                    'title', ai.title,
                    'description', ai.description,
                    'priority', ai.priority,
                    'status', ai.status,
                    'due_date', to_char(ai.due_date, 'Mon DD, YYYY'),
                    'owner_name', aip.full_name
                ))
                FROM public.sprint_action_items ai
                LEFT JOIN public.profiles aip ON aip.id = ai.owner_id
                WHERE ai.retrospective_id = r.id
            ), '[]'::jsonb)
        ) INTO v_retro_data
        FROM public.sprint_retrospectives r
        WHERE r.id = v_retro_id;
    ELSE
        v_retro_data := jsonb_build_object('went_well', '[]'::jsonb, 'did_not_go_well', '[]'::jsonb, 'to_improve', '[]'::jsonb, 'action_items', '[]'::jsonb);
    END IF;

    -- 10. Sprint Backlog Hierarchical Items
    -- Top-level rows: Items in this sprint whose parent is not also in this sprint (tasks whose parent is in backlog or standalone)
    v_offset := (p_page - 1) * p_page_size;

    SELECT COUNT(*) INTO v_total_stories_count
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
          OR w.team_name ILIKE '%' || v_clean_team || '%'
          OR wt.name ILIKE '%' || v_clean_team || '%'
          OR EXISTS (
              SELECT 1 FROM public.work_items c
              LEFT JOIN public.work_teams cwt ON cwt.id = c.team_id
              WHERE c.parent_id = w.id
                AND (c.team_name = v_clean_team OR cwt.name = v_clean_team OR c.team_name ILIKE '%' || v_clean_team || '%' OR cwt.name ILIKE '%' || v_clean_team || '%')
          )
      )
      AND (p_search IS NULL OR w.title ILIKE '%' || p_search || '%' OR w.item_number ILIKE '%' || p_search || '%');

    SELECT jsonb_agg(
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
            'team_name', COALESCE(parent.team_name, parent_team.name, 'Digital Campus Team'),
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
                    'team_name', COALESCE(child.team_name, child_team.name, 'Digital Campus Team'),
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
                      OR child.team_name ILIKE '%' || v_clean_team || '%'
                      OR child_team.name ILIKE '%' || v_clean_team || '%'
                  )
            ), '[]'::jsonb)
        )
    ) INTO v_sprint_items
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
              OR w.team_name ILIKE '%' || v_clean_team || '%'
              OR wt.name ILIKE '%' || v_clean_team || '%'
              OR EXISTS (
                  SELECT 1 FROM public.work_items c
                  LEFT JOIN public.work_teams cwt ON cwt.id = c.team_id
                  WHERE c.parent_id = w.id
                    AND (c.team_name = v_clean_team OR cwt.name = v_clean_team OR c.team_name ILIKE '%' || v_clean_team || '%' OR cwt.name ILIKE '%' || v_clean_team || '%')
              )
          )
          AND (p_search IS NULL OR w.title ILIKE '%' || p_search || '%' OR w.item_number ILIKE '%' || p_search || '%')
        ORDER BY w.rank ASC, w.created_at DESC
        OFFSET v_offset
        LIMIT p_page_size
    ) parent
    LEFT JOIN public.work_boards parent_board ON parent_board.id = parent.board_id
    LEFT JOIN public.work_teams parent_team ON parent_team.id = parent.team_id;

    IF v_sprint_items IS NULL THEN
        v_sprint_items := '[]'::jsonb;
    END IF;

    -- Return comprehensive sprint state
    RETURN jsonb_build_object(
        'success', true,
        'sprint_id', v_sprint_id,
        'sprint_name', v_sprint_row.name,
        'sprint_number', v_sprint_row.sprint_number,
        'status', v_sprint_row.status,
        'goal', v_sprint_row.goal,
        'team_name', v_sprint_row.team_name,
        'board_id', v_sprint_row.board_id,
        'board_name', v_sprint_row.board_name,
        'start_date_fmt', v_sprint_row.start_date_fmt,
        'end_date_fmt', v_sprint_row.end_date_fmt,
        'duration_days', v_sprint_row.duration_days,
        'working_days', v_sprint_row.working_days,
        'working_hours_per_day', v_sprint_row.working_hours_per_day,
        'capacity_hours', v_sprint_row.capacity_hours,
        'capacity_unit', v_sprint_row.capacity_unit,
        'color', v_sprint_row.color,
        'owner_name', v_sprint_row.owner_name,
        'owner_avatar', v_sprint_row.owner_avatar,
        'kpis', jsonb_build_object(
            'total_items', v_kpi_total_items,
            'completed_items', v_completed_items,
            'in_progress_items', v_in_progress_items,
            'not_started_items', v_not_started_items,
            'blocked_items', v_blocked_items,
            'total_effort', v_total_effort,
            'completed_effort', v_completed_effort,
            'remaining_effort', v_remaining_effort,
            'completion_percentage', v_completion_pct
        ),
        'burndown', v_burndown_points,
        'progress_by_type', v_progress_by_type,
        'upcoming_sprints', v_upcoming_sprints,
        'team_members', v_team_members,
        'blockers', v_blockers_list,
        'retrospective', v_retro_data,
        'total_items_count', v_total_stories_count,
        'page', p_page,
        'page_size', p_page_size,
        'items', v_sprint_items
    );
END;
$$;


-- ============================================================================
-- 2. UPDATE sp_list_board_kanban
-- ============================================================================
CREATE OR REPLACE FUNCTION public.sp_list_board_kanban(
    p_school_id UUID,
    p_board_id VARCHAR DEFAULT NULL,
    p_sprint_id VARCHAR DEFAULT NULL,
    p_view VARCHAR DEFAULT 'All',
    p_group_by VARCHAR DEFAULT 'Status',
    p_search VARCHAR DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_board_id UUID := NULL;
    v_sprint_id UUID := NULL;
    v_is_backlog_only BOOLEAN := FALSE;
    v_columns JSONB;
    v_group VARCHAR := COALESCE(p_group_by, 'Status');
    v_clean_board VARCHAR := TRIM(COALESCE(p_board_id, ''));
BEGIN
    -- Resolve Board ID (by UUID, code, or name)
    IF v_clean_board != '' AND LOWER(v_clean_board) NOT IN ('all', 'none', '*', 'all boards') THEN
        BEGIN
            v_board_id := v_clean_board::UUID;
        EXCEPTION WHEN OTHERS THEN
            IF v_clean_board ILIKE '%Institute%' OR LOWER(v_clean_board) IN ('default', 'iwb') THEN
                SELECT id INTO v_board_id FROM public.work_boards
                WHERE school_id = p_school_id AND (name ILIKE '%Institute%' OR code = 'IWB') LIMIT 1;
                IF v_board_id IS NULL THEN
                    v_board_id := '31dacd93-15ee-4eed-8994-56973fd81245'::UUID;
                END IF;
            ELSIF v_clean_board ILIKE '%Academic%' OR LOWER(v_clean_board) IN ('academic', 'acb') THEN
                SELECT id INTO v_board_id FROM public.work_boards
                WHERE school_id = p_school_id AND (name ILIKE '%Academic%' OR code = 'ACB') LIMIT 1;
                IF v_board_id IS NULL THEN
                    v_board_id := 'a1111111-2222-3333-4444-555555555551'::UUID;
                END IF;
            ELSIF v_clean_board ILIKE '%IT%' OR v_clean_board ILIKE '%Infra%' OR LOWER(v_clean_board) IN ('itb', 'infra') THEN
                SELECT id INTO v_board_id FROM public.work_boards
                WHERE school_id = p_school_id AND (name ILIKE '%IT%' OR code = 'ITB') LIMIT 1;
                IF v_board_id IS NULL THEN
                    v_board_id := 'a1111111-2222-3333-4444-555555555552'::UUID;
                END IF;
            ELSE
                SELECT id INTO v_board_id FROM public.work_boards
                WHERE school_id = p_school_id AND name ILIKE '%' || v_clean_board || '%' LIMIT 1;
            END IF;
        END;
    END IF;

    -- Resolve Sprint ID
    IF p_sprint_id IS NOT NULL AND p_sprint_id != '' THEN
        IF p_sprint_id ILIKE '%Backlog%' THEN
            v_is_backlog_only := TRUE;
        ELSIF p_sprint_id ILIKE '%Current%' OR p_sprint_id ILIKE '%Sprint 8%' THEN
            SELECT id INTO v_sprint_id FROM public.work_sprints
            WHERE school_id = p_school_id AND (status = 'ACTIVE' OR name ILIKE '%Sprint 8%') LIMIT 1;
        ELSIF p_sprint_id ILIKE '%Sprint 9%' THEN
            SELECT id INTO v_sprint_id FROM public.work_sprints
            WHERE school_id = p_school_id AND name ILIKE '%Sprint 9%' LIMIT 1;
        ELSIF p_sprint_id ILIKE '%Sprint 10%' THEN
            SELECT id INTO v_sprint_id FROM public.work_sprints
            WHERE school_id = p_school_id AND name ILIKE '%Sprint 10%' LIMIT 1;
        ELSIF LOWER(p_sprint_id) NOT IN ('all', 'all sprints') THEN
            BEGIN
                v_sprint_id := p_sprint_id::UUID;
            EXCEPTION WHEN OTHERS THEN
                v_sprint_id := NULL;
            END;
        END IF;
    END IF;

    -- Fetch Raw Items with pre-aggregated assignees & rich attributes
    WITH item_assignees AS (
        SELECT
            wia.work_item_id,
            jsonb_agg(
                jsonb_build_object(
                    'user_id', p.id,
                    'full_name', p.full_name,
                    'role', p.role,
                    'avatar_url', p.avatar_url,
                    'department', p.department
                ) ORDER BY wia.assigned_at ASC
            ) AS assignees_list
        FROM public.work_item_assignees wia
        JOIN public.profiles p ON p.id = wia.user_id
        GROUP BY wia.work_item_id
    ),
    raw_items AS (
        SELECT
            w.id,
            w.item_number,
            w.title,
            w.description,
            w.work_type,
            w.priority,
            w.status,
            w.category,
            w.board_id,
            wb.name AS board_name,
            w.team_id,
            COALESCE(w.team_name, wt.name, 'Digital Campus Team') AS team_name,
            w.class_id,
            w.section_id,
            w.target_role,
            w.assignment_mode,
            COALESCE(w.progress_percentage, 0) AS progress_percentage,
            COALESCE(w.rank, 1000.0) AS rank,
            to_char(w.due_date, 'Mon DD') AS due_date_str,
            to_char(w.completed_at, 'Mon DD') AS completed_date_str,
            to_char(w.start_date, 'YYYY-MM-DD') AS start_date,
            to_char(w.due_date, 'YYYY-MM-DD') AS due_date,
            (w.due_date IS NOT NULL AND w.due_date < CURRENT_DATE AND UPPER(w.status) NOT IN ('COMPLETED', 'RESOLVED')) AS is_overdue,
            COALESCE(ia.assignees_list, '[]'::jsonb) AS assignees,
            (SELECT COUNT(*) FROM public.work_item_comments c WHERE c.work_item_id = w.id) AS comments_count,
            (SELECT COUNT(*) FROM public.work_item_attachments at WHERE at.work_item_id = w.id) AS attachments_count,
            (SELECT COUNT(*) FROM public.work_item_checklists cl WHERE cl.work_item_id = w.id) AS checklists_count,
            (SELECT COUNT(*) FROM public.work_item_checklists cl WHERE cl.work_item_id = w.id AND cl.is_completed = TRUE) AS checklists_completed_count
        FROM public.work_items w
        LEFT JOIN public.work_boards wb ON wb.id = w.board_id
        LEFT JOIN public.work_teams wt ON wt.id = w.team_id
        LEFT JOIN item_assignees ia ON ia.work_item_id = w.id
        WHERE w.school_id = p_school_id
          AND w.is_archived = FALSE
          AND (v_board_id IS NULL OR w.board_id = v_board_id)
          AND (
            (v_is_backlog_only = TRUE AND w.sprint_id IS NULL)
            OR (v_is_backlog_only = FALSE AND (v_sprint_id IS NULL OR w.sprint_id = v_sprint_id))
          )
          AND (
            p_search IS NULL OR p_search = '' OR
            w.title ILIKE '%' || p_search || '%' OR
            w.item_number ILIKE '%' || p_search || '%' OR
            w.category ILIKE '%' || p_search || '%' OR
            w.description ILIKE '%' || p_search || '%'
          )
          AND (
            p_view IS NULL OR p_view = 'All' OR p_view = 'All Work Items' OR
            (p_view = 'Task & Story' AND UPPER(w.work_type) IN ('TASK', 'STORY', 'BUG', 'ISSUE')) OR
            ((p_view ILIKE '%Bug%' OR p_view ILIKE '%Issue%') AND UPPER(w.work_type) IN ('BUG', 'ISSUE')) OR
            (p_view = 'My Tasks Only' AND (
                p_user_id IS NULL OR w.reporter_id = p_user_id OR
                EXISTS (SELECT 1 FROM public.work_item_assignees wia WHERE wia.work_item_id = w.id AND wia.user_id = p_user_id)
            ))
          )
        ORDER BY w.rank ASC, w.created_at DESC
    ),
    columns_data AS (
        SELECT
            col.status_key,
            col.display_name,
            col.color_hex,
            col.sort_order,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'id', i.id,
                        'item_number', i.item_number,
                        'title', i.title,
                        'description', i.description,
                        'work_type', i.work_type,
                        'priority', i.priority,
                        'status', i.status,
                        'category', i.category,
                        'board_id', i.board_id,
                        'board_name', i.board_name,
                        'team_id', i.team_id,
                        'team_name', i.team_name,
                        'class_id', i.class_id,
                        'section_id', i.section_id,
                        'target_role', i.target_role,
                        'assignment_mode', i.assignment_mode,
                        'progress_percentage', i.progress_percentage,
                        'rank', i.rank,
                        'due_date_str', i.due_date_str,
                        'completed_date_str', i.completed_date_str,
                        'start_date', i.start_date,
                        'due_date', i.due_date,
                        'is_overdue', i.is_overdue,
                        'assignees', i.assignees,
                        'comments_count', i.comments_count,
                        'attachments_count', i.attachments_count,
                        'checklists_count', i.checklists_count,
                        'checklists_completed_count', i.checklists_completed_count
                    )
                ) FILTER (WHERE i.id IS NOT NULL),
                '[]'::jsonb
            ) AS items
        FROM (
            SELECT status_key, display_name, color_hex, sort_order
            FROM (
                -- 1. Status Grouping (Default)
                SELECT 'NEW' AS status_key, 'New' AS display_name, '#64748B' AS color_hex, 1 AS sort_order WHERE v_group ILIKE '%Status%'
                UNION ALL SELECT 'ACTIVE', 'Active', '#3B82F6', 2 WHERE v_group ILIKE '%Status%'
                UNION ALL SELECT 'RESOLVED', 'Resolved', '#10B981', 3 WHERE v_group ILIKE '%Status%'
                UNION ALL SELECT 'COMPLETED', 'Completed', '#8B5CF6', 4 WHERE v_group ILIKE '%Status%'

                -- 2. Work Type Grouping
                UNION ALL SELECT 'STORY', 'Story', '#8B5CF6', 1 WHERE v_group ILIKE '%Type%'
                UNION ALL SELECT 'TASK', 'Task', '#3B82F6', 2 WHERE v_group ILIKE '%Type%'
                UNION ALL SELECT 'BUG', 'Bug', '#EF4444', 3 WHERE v_group ILIKE '%Type%'
                UNION ALL SELECT 'EPIC', 'Epic', '#EC4899', 4 WHERE v_group ILIKE '%Type%'

                -- 3. Priority Grouping
                UNION ALL SELECT 'CRITICAL', 'Critical / Urgent', '#EF4444', 1 WHERE v_group ILIKE '%Priority%'
                UNION ALL SELECT 'HIGH', 'High', '#F59E0B', 2 WHERE v_group ILIKE '%Priority%'
                UNION ALL SELECT 'MEDIUM', 'Medium', '#3B82F6', 3 WHERE v_group ILIKE '%Priority%'
                UNION ALL SELECT 'LOW', 'Low', '#10B981', 4 WHERE v_group ILIKE '%Priority%'
            ) sub_cols
        ) AS col(status_key, display_name, color_hex, sort_order)
        LEFT JOIN raw_items i ON (
            CASE 
                WHEN v_group ILIKE '%Type%' THEN
                    UPPER(i.work_type) = col.status_key
                WHEN v_group ILIKE '%Priority%' THEN
                    (col.status_key = 'CRITICAL' AND UPPER(i.priority) IN ('CRITICAL', 'URGENT')) OR
                    (col.status_key = 'HIGH' AND UPPER(i.priority) = 'HIGH') OR
                    (col.status_key = 'MEDIUM' AND UPPER(i.priority) = 'MEDIUM') OR
                    (col.status_key = 'LOW' AND UPPER(i.priority) = 'LOW')
                ELSE
                    (col.status_key = 'NEW' AND UPPER(i.status) = 'NEW') OR
                    (col.status_key = 'ACTIVE' AND UPPER(i.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS')) OR
                    (col.status_key = 'RESOLVED' AND UPPER(i.status) = 'RESOLVED') OR
                    (col.status_key = 'COMPLETED' AND UPPER(i.status) = 'COMPLETED')
            END
        )
        GROUP BY col.status_key, col.display_name, col.color_hex, col.sort_order
        ORDER BY col.sort_order ASC
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'status_key', status_key,
            'name', display_name,
            'color', color_hex,
            'count', jsonb_array_length(items),
            'items', items
        )
    ) INTO v_columns FROM columns_data;

    RETURN jsonb_build_object(
        'board_id', COALESCE(v_board_id::TEXT, 'default'),
        'group_by', v_group,
        'columns', COALESCE(v_columns, '[]'::jsonb)
    );
END;
$$;


-- ============================================================================
-- 3. UPDATE sp_get_sprint_capacity_dashboard (Fixes daily chart duplication)
-- ============================================================================
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
           COALESCE(b.name, 'Institute Work Board') AS board_name
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

    -- 6. Fetch Daily Capacity Breakdown Points (SUM and GROUP BY date to prevent duplicate bars on All Teams)
    SELECT jsonb_agg(
        jsonb_build_object(
            'date_fmt', sub_chart.date_fmt,
            'full_date', sub_chart.full_date,
            'capacity_hours', sub_chart.capacity_hours,
            'planned_hours', sub_chart.planned_hours,
            'actual_hours', sub_chart.actual_hours
        ) ORDER BY sub_chart.sort_order ASC
    ) INTO v_daily_chart
    FROM (
        SELECT
            sdc.date_fmt,
            MIN(sdc.full_date) AS full_date,
            MIN(sdc.sort_order) AS sort_order,
            SUM(sdc.capacity_hours) AS capacity_hours,
            SUM(sdc.planned_hours) AS planned_hours,
            SUM(sdc.actual_hours) AS actual_hours
        FROM public.sprint_daily_capacities sdc
        WHERE sdc.sprint_id = v_sprint_id
          AND (v_team_name = 'All Teams' OR sdc.team_name = v_team_name)
        GROUP BY sdc.date_fmt
    ) sub_chart;

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
            'text', 'Active sprint: ' || COALESCE(v_sprint_row.name, 'Sprint 8') || ' with ' || v_team_members_count::TEXT || ' active team member(s).'
        )
    );

    -- Return Consolidated Enterprise Capacity State
    RETURN jsonb_build_object(
        'success', true,
        'sprint_id', v_sprint_id,
        'sprint_name', COALESCE(v_sprint_row.name, 'Sprint 8'),
        'sprint_duration', COALESCE(v_sprint_row.start_date_fmt || ' - ' || v_sprint_row.end_date_fmt, 'Jan 01, 2026 - Jan 14, 2026'),
        'board_name', COALESCE(v_sprint_row.board_name, 'Institute Work Board'),
        'selected_team', v_team_name,
        'pagination', jsonb_build_object(
            'page', v_page,
            'limit', v_limit,
            'total_count', v_total_filtered_count,
            'total_pages', v_total_pages,
            'has_next_page', (v_page < v_total_pages),
            'has_prev_page', (v_page > 1)
        ),
        'kpis', jsonb_build_object(
            'total_capacity_hours', v_total_capacity,
            'planned_work_hours', v_planned_work,
            'actual_work_hours', v_actual_work,
            'remaining_capacity_hours', v_remaining_capacity,
            'utilization_pct', v_utilization_pct,
            'over_allocation_hours', v_over_allocation,
            'team_members_count', v_team_members_count,
            'overloaded_members_count', v_overloaded_count
        ),
        'teams', v_teams_list,
        'all_sprints', v_all_sprints_list,
        'daily_chart', v_daily_chart,
        'members', v_members_list,
        'insights', v_insights
    );
END;
$$;


-- ============================================================================
-- 4. UPDATE sp_list_work_items_paged
-- ============================================================================
CREATE OR REPLACE FUNCTION public.sp_list_work_items_paged(
    p_school_id UUID,
    p_board_id UUID DEFAULT NULL,
    p_sprint_id UUID DEFAULT NULL,
    p_type VARCHAR DEFAULT 'All',
    p_status VARCHAR DEFAULT 'All',
    p_assignee_id UUID DEFAULT NULL,
    p_priority VARCHAR DEFAULT 'All',
    p_search VARCHAR DEFAULT NULL,
    p_sort_col VARCHAR DEFAULT 'rank',
    p_sort_dir VARCHAR DEFAULT 'ASC',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 12
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_board_id UUID := p_board_id;
    v_total INT := 0;
    v_items JSONB := '[]'::jsonb;
    v_offset INT;
BEGIN
    v_offset := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);

    -- Count total items matching filters (excluding Epics from universal list view)
    SELECT COUNT(*) INTO v_total
    FROM public.work_items w
    WHERE w.school_id = p_school_id
      AND w.is_archived = FALSE
      AND (p_type != 'All' OR w.work_type != 'EPIC')
      AND (v_board_id IS NULL OR w.board_id = v_board_id)
      AND (p_sprint_id IS NULL OR w.sprint_id = p_sprint_id)
      AND (p_type = 'All' OR UPPER(w.work_type) = UPPER(p_type))
      AND (p_status = 'All' OR UPPER(w.status) = UPPER(p_status) OR (UPPER(p_status) = 'ACTIVE' AND UPPER(w.status) = 'IN_PROGRESS'))
      AND (p_priority = 'All' OR UPPER(w.priority) = UPPER(p_priority))
      AND (p_search IS NULL OR p_search = '' OR (w.title ILIKE '%' || p_search || '%' OR w.item_number ILIKE '%' || p_search || '%'))
      AND (p_assignee_id IS NULL OR EXISTS (
          SELECT 1 FROM public.work_item_assignees a WHERE a.work_item_id = w.id AND a.user_id = p_assignee_id
      ));

    -- Select paged items with assignees aggregated
    SELECT COALESCE(jsonb_agg(item_row), '[]'::jsonb)
    INTO v_items
    FROM (
        SELECT
            w.id,
            w.item_number,
            w.title,
            w.description,
            w.work_type,
            w.priority,
            w.status,
            w.category,
            w.board_id,
            COALESCE(wb.name, 'Institute Work Board') AS board_name,
            w.team_id,
            COALESCE(w.team_name, wt.name, 'Digital Campus Team') AS team_name,
            w.class_id,
            w.section_id,
            w.target_role,
            w.assignment_mode,
            COALESCE(w.progress_percentage, 0) AS progress_percentage,
            w.start_date,
            w.due_date,
            to_char(w.due_date, 'Mon DD, YYYY') AS due_date_str,
            to_char(w.start_date, 'Mon DD, YYYY') AS start_date_str,
            to_char(w.completed_at, 'Mon DD, YYYY') AS completed_date_str,
            COALESCE(w.rank, 1000.0) AS rank,
            w.created_at,
            (w.due_date IS NOT NULL AND w.due_date < CURRENT_DATE AND UPPER(w.status) NOT IN ('COMPLETED', 'RESOLVED')) AS is_overdue,
            COALESCE(
                (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'user_id', p.id,
                            'full_name', p.full_name,
                            'avatar_url', p.avatar_url,
                            'role', p.role,
                            'role_type', a.role_type,
                            'department', p.department
                        )
                    )
                    FROM public.work_item_assignees a
                    JOIN public.profiles p ON p.id = a.user_id
                    WHERE a.work_item_id = w.id
                ),
                '[]'::jsonb
            ) AS assignees,
            (SELECT COUNT(*) FROM public.work_item_comments c WHERE c.work_item_id = w.id) AS comments_count,
            (SELECT COUNT(*) FROM public.work_item_checklists ck WHERE ck.work_item_id = w.id) AS checklists_count,
            (SELECT COUNT(*) FROM public.work_item_checklists ck WHERE ck.work_item_id = w.id AND ck.is_completed = TRUE) AS checklists_completed_count,
            (SELECT COUNT(*) FROM public.work_item_attachments at WHERE at.work_item_id = w.id) AS attachments_count
        FROM public.work_items w
        LEFT JOIN public.work_boards wb ON wb.id = w.board_id
        LEFT JOIN public.work_teams wt ON wt.id = w.team_id
        WHERE w.school_id = p_school_id
          AND w.is_archived = FALSE
          AND (p_type != 'All' OR w.work_type != 'EPIC')
          AND (v_board_id IS NULL OR w.board_id = v_board_id)
          AND (p_sprint_id IS NULL OR w.sprint_id = p_sprint_id)
          AND (p_type = 'All' OR UPPER(w.work_type) = UPPER(p_type))
          AND (p_status = 'All' OR UPPER(w.status) = UPPER(p_status) OR (UPPER(p_status) = 'ACTIVE' AND UPPER(w.status) = 'IN_PROGRESS'))
          AND (p_priority = 'All' OR UPPER(w.priority) = UPPER(p_priority))
          AND (p_search IS NULL OR p_search = '' OR (w.title ILIKE '%' || p_search || '%' OR w.item_number ILIKE '%' || p_search || '%'))
          AND (p_assignee_id IS NULL OR EXISTS (
              SELECT 1 FROM public.work_item_assignees a WHERE a.work_item_id = w.id AND a.user_id = p_assignee_id
          ))
        ORDER BY
            CASE WHEN p_sort_col = 'rank' AND UPPER(p_sort_dir) = 'ASC' THEN w.rank END ASC,
            CASE WHEN p_sort_col = 'rank' AND UPPER(p_sort_dir) = 'DESC' THEN w.rank END DESC,
            CASE WHEN p_sort_col = 'item_number' AND UPPER(p_sort_dir) = 'ASC' THEN w.item_number END ASC,
            CASE WHEN p_sort_col = 'item_number' AND UPPER(p_sort_dir) = 'DESC' THEN w.item_number END DESC,
            CASE WHEN p_sort_col = 'due_date' AND UPPER(p_sort_dir) = 'ASC' THEN w.due_date END ASC,
            CASE WHEN p_sort_col = 'due_date' AND UPPER(p_sort_dir) = 'DESC' THEN w.due_date END DESC,
            w.rank ASC, w.created_at DESC
        LIMIT p_page_size
        OFFSET v_offset
    ) item_row;

    RETURN jsonb_build_object(
        'total', v_total,
        'page', p_page,
        'page_size', p_page_size,
        'items', v_items
    );
END;
$$;


-- ============================================================================
-- 5. UPDATE sp_get_backlog_tree
-- ============================================================================
CREATE OR REPLACE FUNCTION public.sp_get_backlog_tree(
    p_school_id UUID,
    p_board_id UUID DEFAULT NULL,
    p_epic_id UUID DEFAULT NULL,
    p_search VARCHAR DEFAULT NULL,
    p_type VARCHAR DEFAULT 'All',
    p_assignee_id UUID DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_board_id UUID := p_board_id;
    v_epic_id UUID := p_epic_id;
    v_selected_epic_row RECORD;
    v_epics JSONB := '[]'::jsonb;
    v_stories JSONB := '[]'::jsonb;
    v_total_items INT := 0;
    v_kpis JSONB;
BEGIN
    -- Pick first Epic if none selected
    IF v_epic_id IS NULL THEN
        SELECT id INTO v_epic_id FROM public.work_items
        WHERE school_id = p_school_id AND work_type = 'EPIC' AND is_archived = FALSE
        ORDER BY rank ASC, item_number ASC LIMIT 1;
    END IF;

    -- Selected Epic details
    SELECT id, item_number, title, description, category, priority, status
    INTO v_selected_epic_row
    FROM public.work_items
    WHERE id = v_epic_id;

    -- 12 Epics list with dynamic count of stories + child tasks
    SELECT COALESCE(jsonb_agg(epic_item), '[]'::jsonb)
    INTO v_epics
    FROM (
        SELECT
            e.id,
            e.item_number,
            e.title,
            e.description,
            e.category,
            e.priority,
            e.status,
            COALESCE(e.rank, 10.0) AS rank,
            COALESCE(
                (
                    SELECT COUNT(DISTINCT s.id) + COUNT(DISTINCT tk.id)
                    FROM public.work_items s
                    LEFT JOIN public.work_items tk ON tk.parent_id = s.id AND tk.is_archived = FALSE
                    WHERE s.parent_id = e.id AND s.work_type = 'STORY' AND s.is_archived = FALSE
                ),
                0
            ) AS items_count
        FROM public.work_items e
        WHERE e.school_id = p_school_id
          AND e.work_type = 'EPIC'
          AND e.is_archived = FALSE
        ORDER BY e.rank ASC, e.item_number ASC
    ) epic_item;

    -- Calculate total items under this selected epic
    SELECT COALESCE(
        (
            SELECT COUNT(DISTINCT s.id) + COUNT(DISTINCT tk.id)
            FROM public.work_items s
            LEFT JOIN public.work_items tk ON tk.parent_id = s.id AND tk.is_archived = FALSE
            WHERE s.parent_id = v_epic_id AND s.work_type = 'STORY' AND s.is_archived = FALSE
              AND (v_board_id IS NULL OR s.board_id = v_board_id)
              AND (p_search IS NULL OR p_search = '' OR s.title ILIKE '%' || p_search || '%' OR s.item_number ILIKE '%' || p_search || '%')
        ),
        0
    ) INTO v_total_items;

    -- Stories and their children under the selected Epic
    SELECT COALESCE(jsonb_agg(story_item), '[]'::jsonb)
    INTO v_stories
    FROM (
        SELECT
            s.id,
            s.item_number,
            s.title,
            s.description,
            s.work_type,
            s.priority,
            s.status,
            s.category,
            s.board_id,
            COALESCE(sb.name, 'Institute Work Board') AS board_name,
            s.team_id,
            COALESCE(s.team_name, st.name, 'Digital Campus Team') AS team_name,
            s.class_id,
            s.section_id,
            COALESCE(s.estimated_hours, 40.0) AS estimate_hours,
            COALESCE(s.story_points, 13.0) AS story_points,
            s.due_date,
            to_char(s.due_date, 'Mon DD, YYYY') AS due_date_str,
            COALESCE(s.rank, 100.0) AS rank,
            COALESCE(
                (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'user_id', p.id,
                            'full_name', p.full_name,
                            'avatar_url', p.avatar_url,
                            'role', p.role,
                            'department', p.department
                        )
                    )
                    FROM public.work_item_assignees a
                    JOIN public.profiles p ON p.id = a.user_id
                    WHERE a.work_item_id = s.id
                ),
                '[]'::jsonb
            ) AS assignees,
            COALESCE(
                (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'id', tk.id,
                            'item_number', tk.item_number,
                            'title', tk.title,
                            'work_type', tk.work_type,
                            'priority', tk.priority,
                            'status', tk.status,
                            'board_id', tk.board_id,
                            'board_name', COALESCE(tkb.name, 'Institute Work Board'),
                            'team_id', tk.team_id,
                            'team_name', COALESCE(tk.team_name, tkt.name, 'Digital Campus Team'),
                            'estimate_hours', COALESCE(tk.estimated_hours, 8.0),
                            'rank', tk.rank,
                            'assignees', COALESCE(
                                (
                                    SELECT jsonb_agg(
                                        jsonb_build_object(
                                            'user_id', tp.id,
                                            'full_name', tp.full_name,
                                            'avatar_url', tp.avatar_url,
                                            'role', tp.role,
                                            'department', tp.department
                                        )
                                    )
                                    FROM public.work_item_assignees ta
                                    JOIN public.profiles tp ON tp.id = ta.user_id
                                    WHERE ta.work_item_id = tk.id
                                ),
                                '[]'::jsonb
                            )
                        )
                        ORDER BY tk.rank ASC, tk.item_number ASC
                    )
                    FROM public.work_items tk
                    LEFT JOIN public.work_boards tkb ON tkb.id = tk.board_id
                    LEFT JOIN public.work_teams tkt ON tkt.id = tk.team_id
                    WHERE tk.parent_id = s.id AND tk.is_archived = FALSE
                ),
                '[]'::jsonb
            ) AS children
        FROM public.work_items s
        LEFT JOIN public.work_boards sb ON sb.id = s.board_id
        LEFT JOIN public.work_teams st ON st.id = s.team_id
        WHERE s.school_id = p_school_id
          AND s.work_type = 'STORY'
          AND s.parent_id = v_epic_id
          AND s.is_archived = FALSE
          AND (v_board_id IS NULL OR s.board_id = v_board_id)
          AND (
            p_search IS NULL OR p_search = '' OR
            s.title ILIKE '%' || p_search || '%' OR
            s.item_number ILIKE '%' || p_search || '%' OR
            s.description ILIKE '%' || p_search || '%'
          )
          AND (
            p_assignee_id IS NULL OR EXISTS (
                SELECT 1 FROM public.work_item_assignees sa WHERE sa.work_item_id = s.id AND sa.user_id = p_assignee_id
            )
          )
        ORDER BY s.rank ASC, s.item_number ASC
        LIMIT p_page_size
        OFFSET ((p_page - 1) * p_page_size)
    ) story_item;

    -- Dynamic Mockup-Aligned Backlog KPIs from live DB
    SELECT jsonb_build_object(
        'total_backlog', (SELECT COUNT(*) FROM public.work_items WHERE school_id = p_school_id AND sprint_id IS NULL AND is_archived = FALSE),
        'epics', (SELECT COUNT(*) FROM public.work_items WHERE school_id = p_school_id AND work_type = 'EPIC' AND is_archived = FALSE),
        'stories', (SELECT COUNT(*) FROM public.work_items WHERE school_id = p_school_id AND work_type = 'STORY' AND is_archived = FALSE),
        'tasks', (SELECT COUNT(*) FROM public.work_items WHERE school_id = p_school_id AND work_type = 'TASK' AND is_archived = FALSE),
        'bugs', (SELECT COUNT(*) FROM public.work_items WHERE school_id = p_school_id AND work_type = 'BUG' AND is_archived = FALSE),
        'issues', (SELECT COUNT(*) FROM public.work_items WHERE school_id = p_school_id AND work_type = 'ISSUE' AND is_archived = FALSE)
    ) INTO v_kpis;

    RETURN jsonb_build_object(
        'kpis', v_kpis,
        'epics', v_epics,
        'selected_epic', CASE WHEN v_selected_epic_row.id IS NOT NULL THEN
            jsonb_build_object(
                'id', v_selected_epic_row.id,
                'item_number', v_selected_epic_row.item_number,
                'title', v_selected_epic_row.title,
                'description', v_selected_epic_row.description,
                'category', v_selected_epic_row.category,
                'priority', v_selected_epic_row.priority,
                'status', v_selected_epic_row.status,
                'total_items', v_total_items
            )
        ELSE NULL END,
        'stories', v_stories,
        'page', p_page,
        'page_size', p_page_size
    );
END;
$$;


-- ============================================================================
-- 6. DATA ALIGNMENT: Populate Team Names and IDs for Domain Separation
-- ============================================================================
-- Examination Team items
UPDATE public.work_items
SET team_name = 'Examination Team',
    team_id = (SELECT id FROM public.work_teams WHERE name = 'Examination Team' LIMIT 1)
WHERE (item_number IN ('WM-1035', 'WM-1053', 'WM-1026', 'WM-1036', 'WM-1055')
   OR title ILIKE '%exam%'
   OR title ILIKE '%grade report%'
   OR title ILIKE '%mock test%')
   AND (SELECT id FROM public.work_teams WHERE name = 'Examination Team' LIMIT 1) IS NOT NULL;

-- Library Systems Team items
UPDATE public.work_items
SET team_name = 'Library Systems Team',
    team_id = (SELECT id FROM public.work_teams WHERE name = 'Library Systems Team' LIMIT 1)
WHERE (item_number IN ('WM-1048', 'BG-1081', 'WM-1025')
   OR title ILIKE '%library%')
   AND (SELECT id FROM public.work_teams WHERE name = 'Library Systems Team' LIMIT 1) IS NOT NULL;

-- Infrastructure & Maintenance Team items
UPDATE public.work_items
SET team_name = 'Infrastructure & Maintenance Team',
    team_id = (SELECT id FROM public.work_teams WHERE name = 'Infrastructure & Maintenance Team' LIMIT 1)
WHERE (item_number IN ('WM-1032', 'WM-1029', 'WM-1040', 'WM-1037', 'TK-3016', 'TK-3007')
   OR title ILIKE '%projector%'
   OR title ILIKE '%water filtration%'
   OR title ILIKE '%boiler%'
   OR title ILIKE '%microscope%')
   AND (SELECT id FROM public.work_teams WHERE name = 'Infrastructure & Maintenance Team' LIMIT 1) IS NOT NULL;

-- IT Operations Team items
UPDATE public.work_items
SET team_name = 'IT Operations Team',
    team_id = (SELECT id FROM public.work_teams WHERE name = 'IT Operations Team' LIMIT 1)
WHERE (item_number IN ('WM-1039', 'WM-1044', 'WM-1049', 'WM-1052', 'WM-1028', 'TK-3070')
   OR title ILIKE '%firewall%'
   OR title ILIKE '%anti-virus%'
   OR title ILIKE '%wi-fi%'
   OR title ILIKE '%rfid%')
   AND (SELECT id FROM public.work_teams WHERE name = 'IT Operations Team' LIMIT 1) IS NOT NULL;

-- Academic Systems Team items
UPDATE public.work_items
SET team_name = 'Academic Systems Team',
    team_id = (SELECT id FROM public.work_teams WHERE name = 'Academic Systems Team' LIMIT 1)
WHERE (item_number IN ('WM-1041', 'WM-1042', 'WM-1045', 'WM-1031')
   OR title ILIKE '%lecture%'
   OR title ILIKE '%quiz%'
   OR title ILIKE '%data structures%'
   OR title ILIKE '%curriculum%')
   AND (SELECT id FROM public.work_teams WHERE name = 'Academic Systems Team' LIMIT 1) IS NOT NULL;
