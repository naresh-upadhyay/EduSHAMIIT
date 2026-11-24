-- ============================================================================
-- Migration 574: Enhance Work Teams Directory, Details Drawer & Departments
-- Ensures member emails are returned in team rosters, standardizes department lookups,
-- dynamic KPI calculation, and full CRUD support.
-- ============================================================================

-- 1. Ensure sp_get_teams_directory returns email in member objects and lead objects
CREATE OR REPLACE FUNCTION public.sp_get_teams_directory(
    p_school_id UUID,
    p_sprint_id UUID DEFAULT NULL,
    p_status VARCHAR DEFAULT 'ALL',
    p_department VARCHAR DEFAULT 'ALL',
    p_search VARCHAR DEFAULT NULL,
    p_sort_by VARCHAR DEFAULT 'NAME_ASC',
    p_limit INT DEFAULT 10,
    p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sprint UUID := p_sprint_id;
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
    IF v_sprint IS NULL THEN
        SELECT id INTO v_sprint FROM public.work_sprints
        WHERE school_id = p_school_id AND status = 'ACTIVE' LIMIT 1;
        IF v_sprint IS NULL THEN
            SELECT id INTO v_sprint FROM public.work_sprints WHERE school_id = p_school_id LIMIT 1;
        END IF;
    END IF;

    -- Aggregate Global KPIs for non-archived teams
    SELECT
        COUNT(t.id),
        COALESCE(COUNT(t.id) FILTER (WHERE t.is_active = TRUE AND t.status = 'ACTIVE'), 0),
        COALESCE(COUNT(t.id) FILTER (WHERE t.is_active = FALSE OR t.status != 'ACTIVE'), 0)
    INTO v_total_teams, v_active_teams, v_inactive_teams
    FROM public.work_teams t
    WHERE t.school_id = p_school_id AND t.status != 'ARCHIVED';

    SELECT COUNT(DISTINCT wtm.user_id) INTO v_total_members
    FROM public.work_team_members wtm
    JOIN public.work_teams t ON t.id = wtm.team_id
    WHERE t.school_id = p_school_id AND t.status != 'ARCHIVED';

    -- Dynamic Capacity calculation
    SELECT
        COALESCE(SUM(COALESCE(stc.total_capacity_hours, NULLIF((SELECT COUNT(wtm.id) * 40.0 FROM public.work_team_members wtm WHERE wtm.team_id = t.id), 0), t.default_capacity_hours, 280.0)), 0.0),
        COALESCE(SUM(COALESCE(stc.planned_work_hours, 0.0)), 0.0)
    INTO v_total_capacity, v_total_allocated
    FROM public.work_teams t
    LEFT JOIN public.sprint_team_capacities stc ON stc.team_name = t.name AND (v_sprint IS NULL OR stc.sprint_id = v_sprint)
    WHERE t.school_id = p_school_id AND t.is_active = TRUE AND t.status = 'ACTIVE';

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

    -- Build Filtered & Sorted Teams List with members including email
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
            COALESCE(stc.total_capacity_hours, NULLIF((SELECT COUNT(wtm.id) * 40.0 FROM public.work_team_members wtm WHERE wtm.team_id = t.id), 0), t.default_capacity_hours, 280.0) AS capacity_hours,
            COALESCE(stc.planned_work_hours, 0.0) AS planned_hours,
            COALESCE(stc.remaining_capacity_hours, 0.0) AS remaining_hours,
            COALESCE(stc.utilization_pct, 0.0) AS utilization_pct,
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
        LEFT JOIN public.sprint_team_capacities stc ON stc.team_name = t.name AND (v_sprint IS NULL OR stc.sprint_id = v_sprint)
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
        GROUP BY t.id, p.id, p.full_name, p.email, p.avatar_url, stc.total_capacity_hours, stc.planned_work_hours, stc.remaining_capacity_hours, stc.utilization_pct
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
            'remaining_hours', ft.remaining_hours,
            'utilization_pct', ft.utilization_pct
        )
    ), '[]'::jsonb) INTO v_teams_json
    FROM filtered_teams ft;

    RETURN jsonb_build_object(
        'success', TRUE,
        'sprint_id', v_sprint,
        'kpis', v_kpis_json,
        'total_count', v_total_filtered,
        'teams', v_teams_json
    );
END;
$$;


-- 2. Ensure sp_get_team_detail_drawer returns email, avatar, role in members and lead
CREATE OR REPLACE FUNCTION public.sp_get_team_detail_drawer(
    p_school_id UUID,
    p_team_id UUID,
    p_sprint_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sprint UUID := p_sprint_id;
    v_team RECORD;
    v_lead RECORD;
    v_capacity_stat RECORD;
    v_members JSONB := '[]'::jsonb;
    v_activities JSONB := '[]'::jsonb;
    v_work_items JSONB := '[]'::jsonb;
BEGIN
    IF v_sprint IS NULL THEN
        SELECT id INTO v_sprint FROM public.work_sprints
        WHERE school_id = p_school_id AND status = 'ACTIVE' LIMIT 1;
        IF v_sprint IS NULL THEN
            SELECT id INTO v_sprint FROM public.work_sprints WHERE school_id = p_school_id LIMIT 1;
        END IF;
    END IF;

    -- Fetch Team Master
    SELECT * INTO v_team FROM public.work_teams WHERE id = p_team_id AND school_id = p_school_id;
    IF v_team.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Team not found');
    END IF;

    -- Fetch Lead
    SELECT id, full_name, email, avatar_url INTO v_lead
    FROM public.profiles WHERE id = v_team.lead_id;

    -- Fetch Capacity Stats
    SELECT
        COALESCE(stc.total_capacity_hours, NULLIF((SELECT COUNT(wtm.id) * 40.0 FROM public.work_team_members wtm WHERE wtm.team_id = v_team.id), 0), v_team.default_capacity_hours, 280.0) AS capacity_hours,
        COALESCE(stc.planned_work_hours, 0.0) AS planned_hours,
        COALESCE(stc.remaining_capacity_hours, 0.0) AS remaining_hours,
        COALESCE(stc.utilization_pct, 0.0) AS utilization_pct
    INTO v_capacity_stat
    FROM (SELECT 1) _
    LEFT JOIN public.sprint_team_capacities stc ON stc.team_name = v_team.name AND (v_sprint IS NULL OR stc.sprint_id = v_sprint);

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
            'is_lead', COALESCE(m.is_lead, FALSE),
            'joined_at', m.joined_at
        ) ORDER BY m.is_lead DESC, p.full_name ASC
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
        LIMIT 10
    ) a;

    -- Fetch Assigned Work Items: Returns ALL work items assigned to this team across sprints & backlog
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
$$;
