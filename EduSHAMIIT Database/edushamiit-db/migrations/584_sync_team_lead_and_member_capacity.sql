-- Migration: 584_sync_team_lead_and_member_capacity.sql
-- Description: Ensure members list in sp_get_team_detail_drawer calculates dynamic sprint capacity matching sprint duration and capacity exceptions

CREATE OR REPLACE FUNCTION public.sp_get_team_detail_drawer(
    p_school_id uuid,
    p_team_id uuid,
    p_sprint_id uuid DEFAULT NULL::uuid
)
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

    -- Fetch Members with Avatar, Email, Role, and Dynamic Sprint Capacity
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', m.id,
            'user_id', p.id,
            'name', p.full_name,
            'email', p.email,
            'role', COALESCE(m.role, p.role, 'Member'),
            'designation', COALESCE(p.designation, m.role, p.role, 'Staff'),
            'avatar_url', p.avatar_url,
            'capacity_hours', COALESCE(
                smc.override_value,
                smc.available_hours,
                GREATEST(0.0, (COALESCE(smc.working_days, v_working_days) - COALESCE(smc.days_off, 0.0)) * COALESCE(smc.daily_working_hours, m.daily_hours, 8.0)),
                (v_working_days * COALESCE(m.daily_hours, 8.0)),
                80.0
            ),
            'daily_hours', COALESCE(m.daily_hours, 8.0),
            'is_lead', COALESCE(m.is_lead, (v_team.lead_id = p.id), FALSE),
            'joined_at', m.joined_at
        ) ORDER BY (CASE WHEN COALESCE(m.is_lead, (v_team.lead_id = p.id), FALSE) THEN 1 ELSE 0 END) DESC, p.full_name ASC
    ), '[]'::jsonb) INTO v_members
    FROM public.work_team_members m
    JOIN public.profiles p ON p.id = m.user_id
    LEFT JOIN public.sprint_member_capacities smc
           ON smc.sprint_id = v_sprint
          AND (smc.team_id = m.team_id OR smc.team_id IS NULL)
          AND smc.user_id = m.user_id
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
$function$;
