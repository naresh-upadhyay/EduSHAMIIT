-- Migration 578: Enhance Sprint Member Capacity, Dynamic Burndown & Team Synchronization
-- Solves:
-- 1. Automatic population of all team members for newly selected / copied teams in sprint capacity.
-- 2. Per-sprint member capacity tracking with days off, daily hours, roles from app_roles, and working days.
-- 3. Dynamic work items count, actual hours, remaining hours, and planned hours directly from work_items and work_item_assignees.
-- 4. Dynamic Azure DevOps-style Sprint Burndown & Workload tracking (Ideal Burndown, Remaining Work, Completed Work, Capacity).
-- 5. Full support for app_roles table dropdown synchronization.

-- 1. Create table public.sprint_member_capacities
CREATE TABLE IF NOT EXISTS public.sprint_member_capacities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    sprint_id UUID NOT NULL REFERENCES public.work_sprints(id) ON DELETE CASCADE,
    team_id UUID REFERENCES public.work_teams(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role VARCHAR(100),
    daily_working_hours NUMERIC(6,2) DEFAULT 8.0,
    working_days INT DEFAULT 10,
    days_off NUMERIC(6,2) DEFAULT 0.0,
    available_hours NUMERIC(10,2) DEFAULT 80.0,
    override_value NUMERIC(10,2) DEFAULT NULL,
    override_reason TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_sprint_team_member_cap UNIQUE (sprint_id, team_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_smc_sprint_team ON public.sprint_member_capacities(sprint_id, team_id);
CREATE INDEX IF NOT EXISTS idx_smc_user ON public.sprint_member_capacities(user_id);

-- Seed initial records into sprint_member_capacities from work_team_members for existing sprints
INSERT INTO public.sprint_member_capacities (
    school_id, sprint_id, team_id, user_id, role, daily_working_hours, working_days, days_off, available_hours
)
SELECT
    s.school_id,
    s.id AS sprint_id,
    wtm.team_id,
    wtm.user_id,
    COALESCE(wtm.role, 'Member'),
    COALESCE(wtm.daily_hours, 8.0),
    GREATEST(1, ROUND(COALESCE(GREATEST(1, (s.end_date - s.start_date + 1)), 14) * 5.0 / 7.0)::INT),
    0.0,
    GREATEST(1, ROUND(COALESCE(GREATEST(1, (s.end_date - s.start_date + 1)), 14) * 5.0 / 7.0)::INT) * COALESCE(wtm.daily_hours, 8.0)
FROM public.work_sprints s
CROSS JOIN public.work_team_members wtm
JOIN public.work_teams t ON t.id = wtm.team_id AND t.school_id = s.school_id
ON CONFLICT (sprint_id, team_id, user_id) DO NOTHING;

-- 2. Stored Procedure: sp_manage_member_capacity
CREATE OR REPLACE FUNCTION public.sp_manage_member_capacity(
    p_school_id UUID,
    p_sprint_id UUID,
    p_user_id UUID,
    p_role VARCHAR DEFAULT NULL,
    p_team_name VARCHAR DEFAULT 'Digital Campus Team',
    p_available_hours NUMERIC DEFAULT 40.0,
    p_daily_hours NUMERIC DEFAULT 8.0,
    p_working_days INT DEFAULT 5,
    p_override_value NUMERIC DEFAULT NULL,
    p_override_reason TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_action VARCHAR DEFAULT 'UPSERT',
    p_days_off NUMERIC DEFAULT 0.0,
    p_team_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_team_id UUID := p_team_id;
    v_team_name VARCHAR := p_team_name;
    v_effective_hours NUMERIC(10,2);
    v_daily_hours NUMERIC(6,2) := COALESCE(p_daily_hours, 8.0);
    v_working_days INT := COALESCE(p_working_days, 10);
    v_days_off NUMERIC(6,2) := COALESCE(p_days_off, 0.0);
BEGIN
    -- If p_team_name is provided, always resolve team_id from p_team_name first
    IF v_team_name IS NOT NULL AND LOWER(v_team_name) NOT IN ('all', 'all teams') THEN
        SELECT id, name INTO v_team_id, v_team_name
        FROM public.work_teams
        WHERE school_id = p_school_id
          AND (id::text = v_team_name OR name ILIKE v_team_name)
        LIMIT 1;
    END IF;

    -- If still null and p_team_id is provided, use it
    IF v_team_id IS NULL AND p_team_id IS NOT NULL THEN
        SELECT id, name INTO v_team_id, v_team_name
        FROM public.work_teams
        WHERE id = p_team_id AND school_id = p_school_id
        LIMIT 1;
    END IF;

    -- If still null, try finding team from work_team_members for this user
    IF v_team_id IS NULL THEN
        SELECT wtm.team_id, t.name INTO v_team_id, v_team_name
        FROM public.work_team_members wtm
        JOIN public.work_teams t ON t.id = wtm.team_id
        WHERE wtm.user_id = p_user_id AND t.school_id = p_school_id
        LIMIT 1;
    END IF;

    -- Calculate effective available capacity hours:
    -- (working_days - days_off) * daily_hours, with manual override precedence
    v_effective_hours := COALESCE(
        p_override_value,
        p_available_hours,
        GREATEST(0.0, (v_working_days - v_days_off) * v_daily_hours)
    );

    IF UPPER(p_action) = 'REMOVE' THEN
        DELETE FROM public.sprint_member_capacities
        WHERE sprint_id = p_sprint_id AND user_id = p_user_id
          AND (v_team_id IS NULL OR team_id = v_team_id);

        DELETE FROM public.sprint_members
        WHERE sprint_id = p_sprint_id AND user_id = p_user_id;

        RETURN jsonb_build_object('success', true, 'action', 'REMOVED');
    ELSE
        -- Upsert into sprint_member_capacities
        IF v_team_id IS NOT NULL THEN
            INSERT INTO public.sprint_member_capacities (
                school_id, sprint_id, team_id, user_id, role,
                daily_working_hours, working_days, days_off, available_hours,
                override_value, override_reason, notes, updated_at
            ) VALUES (
                p_school_id, p_sprint_id, v_team_id, p_user_id, COALESCE(p_role, 'Member'),
                v_daily_hours, v_working_days, v_days_off, v_effective_hours,
                p_override_value, p_override_reason, p_notes, NOW()
            )
            ON CONFLICT (sprint_id, team_id, user_id) DO UPDATE SET
                role = COALESCE(EXCLUDED.role, sprint_member_capacities.role),
                daily_working_hours = EXCLUDED.daily_working_hours,
                working_days = EXCLUDED.working_days,
                days_off = EXCLUDED.days_off,
                available_hours = EXCLUDED.available_hours,
                override_value = EXCLUDED.override_value,
                override_reason = EXCLUDED.override_reason,
                notes = EXCLUDED.notes,
                updated_at = NOW();
        END IF;

        -- Also keep sprint_members updated for backward compatibility
        INSERT INTO public.sprint_members (
            school_id, sprint_id, user_id, role, team_name, available_hours,
            daily_working_hours, working_days, override_value, override_reason, notes
        ) VALUES (
            p_school_id, p_sprint_id, p_user_id, COALESCE(p_role, 'Member'), COALESCE(v_team_name, 'Digital Campus Team'),
            v_effective_hours, v_daily_hours, v_working_days, p_override_value, p_override_reason, p_notes
        )
        ON CONFLICT (sprint_id, user_id) DO UPDATE SET
            role = COALESCE(EXCLUDED.role, sprint_members.role),
            team_name = COALESCE(EXCLUDED.team_name, sprint_members.team_name),
            available_hours = EXCLUDED.available_hours,
            daily_working_hours = EXCLUDED.daily_working_hours,
            working_days = EXCLUDED.working_days,
            override_value = EXCLUDED.override_value,
            override_reason = EXCLUDED.override_reason,
            notes = EXCLUDED.notes;

        RETURN jsonb_build_object(
            'success', true,
            'action', 'UPSERTED',
            'effective_hours', v_effective_hours,
            'role', p_role,
            'user_id', p_user_id,
            'sprint_id', p_sprint_id
        );
    END IF;
END;
$$;


-- 3. Stored Procedure: sp_get_sprint_capacity_dashboard
CREATE OR REPLACE FUNCTION public.sp_get_sprint_capacity_dashboard(
    p_school_id UUID,
    p_sprint_id UUID DEFAULT NULL,
    p_team_name VARCHAR DEFAULT 'All Teams',
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

    -- Fetch Available Roles directly from app_roles table
    SELECT jsonb_agg(
        jsonb_build_object(
            'code', r.code,
            'name', r.name,
            'label', COALESCE(r.display_name, r.name)
        ) ORDER BY COALESCE(r.display_order, 99) ASC, COALESCE(r.display_name, r.name) ASC
    ) INTO v_available_roles
    FROM public.app_roles r
    WHERE LOWER(r.status) = 'active';

    IF v_available_roles IS NULL THEN
        v_available_roles := '[]'::jsonb;
    END IF;

    -- 3. Dynamic Member Workload & Capacity Aggregation CTE
    -- Joins work_team_members -> profiles -> sprint_member_capacities -> work_items
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
            ), 0.0) AS actual_hours,
            COALESCE((
                SELECT SUM(COALESCE(wi.remaining_hours, GREATEST(0.0, COALESCE(wi.estimated_hours, 0.0) - COALESCE(wi.actual_hours, 0.0))))
                FROM public.work_items wi
                JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                WHERE wi.sprint_id = v_sprint_id
                  AND wia.user_id = wtm.user_id
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0.0) AS remaining_hours
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
        COALESCE(SUM(remaining_hours), 0.0),
        COUNT(*) FILTER (WHERE workload_status = 'Overloaded')
    INTO
        v_team_members_count,
        v_total_capacity,
        v_planned_work,
        v_actual_work,
        v_remaining_capacity,
        v_overloaded_count
    FROM computed_members;

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
            p.email,
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
    filtered AS (
        SELECT bm.*,
            CASE
                WHEN bm.capacity_hours <= 0 THEN 'Balanced'
                WHEN bm.planned_hours > bm.capacity_hours THEN 'Overloaded'
                WHEN bm.planned_hours >= (bm.capacity_hours * 0.8) THEN 'Balanced'
                WHEN bm.planned_hours > 0 THEN 'Underallocated'
                ELSE 'Available'
            END AS workload_status
        FROM base_members bm
        WHERE (p_search IS NULL OR p_search = '' OR bm.full_name ILIKE '%' || p_search || '%' OR bm.email ILIKE '%' || p_search || '%' OR bm.member_role ILIKE '%' || p_search || '%')
          AND (p_role_filter IS NULL OR p_role_filter = '' OR p_role_filter = 'All' OR bm.member_role = p_role_filter)
    )
    SELECT COUNT(*) INTO v_total_filtered_count
    FROM filtered
    WHERE (p_status_filter IS NULL OR p_status_filter = '' OR p_status_filter = 'All' OR UPPER(workload_status) = UPPER(p_status_filter));

    -- Calculate pagination
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
                ), 0.0) AS actual_hours,
                COALESCE((
                    SELECT SUM(COALESCE(wi.remaining_hours, GREATEST(0.0, COALESCE(wi.estimated_hours, 0.0) - COALESCE(wi.actual_hours, 0.0))))
                    FROM public.work_items wi
                    JOIN public.work_item_assignees wia ON wia.work_item_id = wi.id
                    WHERE wi.sprint_id = v_sprint_id
                      AND wia.user_id = wtm.user_id
                      AND COALESCE(wi.is_archived, FALSE) = FALSE
                ), 0.0) AS remaining_hours
            FROM public.work_team_members wtm
            JOIN public.work_teams t ON t.id = wtm.team_id
            JOIN public.profiles p ON p.id = wtm.user_id
            LEFT JOIN public.sprint_member_capacities smc
                   ON smc.sprint_id = v_sprint_id
                  AND smc.team_id = wtm.team_id
                  AND smc.user_id = wtm.user_id
            WHERE t.school_id = p_school_id
              AND (v_is_all_teams OR (v_team_id IS NOT NULL AND wtm.team_id = v_team_id) OR t.name = v_team_name)
        ),
        computed AS (
            SELECT
                bm.*,
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
            WHERE (p_search IS NULL OR p_search = '' OR bm.full_name ILIKE '%' || p_search || '%' OR bm.email ILIKE '%' || p_search || '%' OR bm.member_role ILIKE '%' || p_search || '%')
              AND (p_role_filter IS NULL OR p_role_filter = '' OR p_role_filter = 'All' OR bm.member_role = p_role_filter)
        )
        SELECT jsonb_build_object(
            'id', c.user_id,
            'user_id', c.user_id,
            'team_id', c.team_id,
            'team_name', c.team_name,
            'full_name', c.full_name,
            'email', c.email,
            'avatar_url', c.avatar_url,
            'role', c.member_role,
            'department', c.department,
            'capacity_hours', c.capacity_hours,
            'planned_hours', c.planned_hours,
            'actual_hours', c.actual_hours,
            'remaining_hours', c.remaining_hours,
            'utilization_pct', c.utilization_pct,
            'work_items_count', c.work_items_count,
            'status', c.workload_status,
            'daily_working_hours', c.daily_hours,
            'working_days', c.working_days,
            'days_off', c.days_off,
            'override_value', c.override_value,
            'override_reason', c.override_reason,
            'notes', c.notes
        ) AS member_obj
        FROM computed c
        WHERE (p_status_filter IS NULL OR p_status_filter = '' OR p_status_filter = 'All' OR UPPER(c.workload_status) = UPPER(p_status_filter))
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
            CASE WHEN LOWER(p_sort_by) = 'work_items' AND LOWER(p_sort_order) = 'desc' THEN c.work_items_count END DESC,
            CASE WHEN LOWER(p_sort_by) = 'work_items' AND LOWER(p_sort_order) != 'desc' THEN c.work_items_count END ASC,
            CASE WHEN LOWER(p_sort_by) = 'status' AND LOWER(p_sort_order) = 'desc' THEN c.workload_status END DESC,
            CASE WHEN LOWER(p_sort_by) = 'status' AND LOWER(p_sort_order) != 'desc' THEN c.workload_status END ASC,
            c.full_name ASC
        LIMIT v_limit OFFSET v_offset
    ) sub;

    IF v_members_list IS NULL THEN
        v_members_list := '[]'::jsonb;
    END IF;

    -- 6. Dynamic Sprint Burndown & Workload Burn Points (Daily timeline)
    v_daily_cap := ROUND(v_total_capacity / GREATEST(1, v_working_days), 1);
    v_burndown_chart := '[]'::jsonb;

    FOR v_day_idx IN 1..v_sprint_days LOOP
        v_curr_date := (v_sprint_row.start_date + (v_day_idx - 1) * INTERVAL '1 day')::DATE;
        v_date_fmt := to_char(v_curr_date, 'Mon DD');

        -- Ideal burndown linear slope: Planned Work at Day 1 down to 0 at Day N
        v_ideal_remain := ROUND(GREATEST(0.0, v_planned_work * (1.0 - ((v_day_idx - 1)::NUMERIC / GREATEST(1, v_sprint_days - 1)))), 1);

        -- Estimated actual burndown tracking
        IF v_day_idx <= GREATEST(1, (CURRENT_DATE - v_sprint_row.start_date + 1)) THEN
            -- Elapsed or current day
            v_cum_completed := ROUND(LEAST(v_actual_work, (v_actual_work / GREATEST(1, (CURRENT_DATE - v_sprint_row.start_date + 1))) * v_day_idx), 1);
            v_actual_remain := ROUND(GREATEST(0.0, v_planned_work - v_cum_completed), 1);
        ELSE
            -- Future sprint day projection
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

    -- Daily bar chart for backward compatibility with existing views
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
            'text', 'Sprint ' || COALESCE(v_sprint_row.name, '') || ' (' || v_sprint_days::TEXT || ' days) with ' || v_team_members_count::TEXT || ' team member(s).'
        )
    );

    -- Return Consolidated Enterprise Capacity State
    RETURN jsonb_build_object(
        'success', true,
        'sprint_id', v_sprint_id,
        'sprint_name', COALESCE(v_sprint_row.name, 'Sprint 8'),
        'sprint_duration', COALESCE(v_sprint_row.start_date_fmt || ' - ' || v_sprint_row.end_date_fmt, 'Jan 01, 2026 - Jan 14, 2026'),
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
        'available_roles', v_available_roles,
        'daily_chart', v_daily_chart,
        'burndown_chart', v_burndown_chart,
        'members', v_members_list,
        'insights', v_insights
    );
END;
$$;
