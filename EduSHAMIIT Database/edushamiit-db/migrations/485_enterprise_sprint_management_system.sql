-- ============================================================================
-- Migration 485: Enterprise Sprint Management System
-- Comprehensive Sprint Lifecycle, Planning, Capacity, Blockers, Retrospectives,
-- Dynamic Analytics (Burndown, Progress by Type), Team Workload & Stored Procedures
-- ============================================================================

-- 1. Extend public.work_sprints table
ALTER TABLE public.work_sprints 
ADD COLUMN IF NOT EXISTS capacity_unit VARCHAR(20) DEFAULT 'HOURS',
ADD COLUMN IF NOT EXISTS working_hours_per_day NUMERIC(5,2) DEFAULT 8.0,
ADD COLUMN IF NOT EXISTS calendar_configuration JSONB DEFAULT '{"exclude_weekends": true, "working_days": ["MON","TUE","WED","THU","FRI"]}'::jsonb,
ADD COLUMN IF NOT EXISTS color VARCHAR(30) DEFAULT '#2563EB',
ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

-- 2. Create public.sprint_members table
CREATE TABLE IF NOT EXISTS public.sprint_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    sprint_id UUID NOT NULL REFERENCES public.work_sprints(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role VARCHAR(50) DEFAULT 'Member',
    available_hours NUMERIC(10,2) DEFAULT 80.0,
    capacity_unit VARCHAR(20) DEFAULT 'HOURS',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_sprint_member UNIQUE (sprint_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_sprint_members_sprint ON public.sprint_members(sprint_id);
CREATE INDEX IF NOT EXISTS idx_sprint_members_user ON public.sprint_members(user_id);

-- 3. Create public.sprint_blockers table
CREATE TABLE IF NOT EXISTS public.sprint_blockers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    sprint_id UUID NOT NULL REFERENCES public.work_sprints(id) ON DELETE CASCADE,
    work_item_id UUID REFERENCES public.work_items(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    severity VARCHAR(50) DEFAULT 'HIGH', -- CRITICAL, HIGH, MEDIUM, LOW
    status VARCHAR(50) DEFAULT 'OPEN',   -- OPEN, RESOLVED
    reporter_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    owner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    expected_resolution_date DATE,
    resolved_at TIMESTAMPTZ,
    resolution_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sprint_blockers_sprint ON public.sprint_blockers(sprint_id);
CREATE INDEX IF NOT EXISTS idx_sprint_blockers_status ON public.sprint_blockers(sprint_id, status);

-- 4. Create public.sprint_retrospectives table
CREATE TABLE IF NOT EXISTS public.sprint_retrospectives (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    sprint_id UUID NOT NULL REFERENCES public.work_sprints(id) ON DELETE CASCADE,
    facilitator_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    summary TEXT,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_sprint_retro UNIQUE (sprint_id)
);

-- 5. Create public.sprint_retrospective_entries table
CREATE TABLE IF NOT EXISTS public.sprint_retrospective_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    retrospective_id UUID NOT NULL REFERENCES public.sprint_retrospectives(id) ON DELETE CASCADE,
    category VARCHAR(50) NOT NULL, -- WENT_WELL, DID_NOT_GO_WELL, TO_IMPROVE
    content TEXT NOT NULL,
    votes INT DEFAULT 0,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sprint_retro_entries ON public.sprint_retrospective_entries(retrospective_id, category);

-- 6. Create public.sprint_action_items table
CREATE TABLE IF NOT EXISTS public.sprint_action_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    retrospective_id UUID NOT NULL REFERENCES public.sprint_retrospectives(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    owner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    due_date DATE,
    priority VARCHAR(50) DEFAULT 'MEDIUM',
    status VARCHAR(50) DEFAULT 'OPEN', -- OPEN, IN_PROGRESS, RESOLVED
    linked_work_item_id UUID REFERENCES public.work_items(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sprint_action_items ON public.sprint_action_items(retrospective_id, status);

-- ============================================================================
-- 7. STORED PROCEDURES
-- ============================================================================

-- A. Update Sprint Details
CREATE OR REPLACE FUNCTION public.sp_update_sprint(
    p_school_id UUID,
    p_sprint_id UUID,
    p_name VARCHAR DEFAULT NULL,
    p_goal TEXT DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_capacity_hours NUMERIC DEFAULT NULL,
    p_working_days INT DEFAULT NULL,
    p_team_name VARCHAR DEFAULT NULL,
    p_owner_id UUID DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL,
    p_capacity_unit VARCHAR DEFAULT NULL,
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sprint RECORD;
    v_actor_name VARCHAR := 'System';
BEGIN
    SELECT * INTO v_sprint FROM public.work_sprints WHERE id = p_sprint_id AND school_id = p_school_id;
    IF v_sprint.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Sprint not found');
    END IF;

    UPDATE public.work_sprints
    SET name = COALESCE(p_name, name),
        goal = COALESCE(p_goal, goal),
        start_date = COALESCE(p_start_date, start_date),
        end_date = COALESCE(p_end_date, end_date),
        capacity_hours = COALESCE(p_capacity_hours, capacity_hours),
        working_days = COALESCE(p_working_days, working_days),
        team_name = COALESCE(p_team_name, team_name),
        owner_id = COALESCE(p_owner_id, owner_id),
        status = COALESCE(UPPER(p_status), status),
        capacity_unit = COALESCE(UPPER(p_capacity_unit), capacity_unit),
        updated_at = NOW()
    WHERE id = p_sprint_id AND school_id = p_school_id;

    IF p_actor_id IS NOT NULL THEN
        SELECT COALESCE(full_name, 'System') INTO v_actor_name FROM public.profiles WHERE id = p_actor_id;
    END IF;

    INSERT INTO public.sprint_activity_logs (school_id, sprint_id, actor_id, action_type, old_value, new_value, notes)
    VALUES (
        p_school_id,
        p_sprint_id,
        p_actor_id,
        'SPRINT_UPDATED',
        v_sprint.name,
        COALESCE(p_name, v_sprint.name),
        v_actor_name || ' updated sprint configuration: ' || COALESCE(p_name, v_sprint.name)
    );

    RETURN jsonb_build_object('success', true, 'sprint_id', p_sprint_id);
END;
$$;

-- B. Transition Sprint Lifecycle (DRAFT, PLANNED, ACTIVE, COMPLETED, CANCELLED)
CREATE OR REPLACE FUNCTION public.sp_transition_sprint_lifecycle(
    p_school_id UUID,
    p_sprint_id UUID,
    p_new_status VARCHAR,
    p_actor_id UUID DEFAULT NULL,
    p_reason TEXT DEFAULT NULL,
    p_move_incomplete_to_sprint_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sprint RECORD;
    v_status VARCHAR;
    v_actor_name VARCHAR := 'System';
    v_incomplete_count INT := 0;
BEGIN
    v_status := UPPER(BTRIM(p_new_status));
    SELECT * INTO v_sprint FROM public.work_sprints WHERE id = p_sprint_id AND school_id = p_school_id;
    IF v_sprint.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Sprint not found');
    END IF;

    IF v_status NOT IN ('DRAFT', 'PLANNED', 'ACTIVE', 'COMPLETED', 'CANCELLED') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid status: ' || v_status);
    END IF;

    -- Handle sprint completion
    IF v_status = 'COMPLETED' THEN
        SELECT COUNT(*) INTO v_incomplete_count
        FROM public.work_items
        WHERE sprint_id = p_sprint_id AND UPPER(status) NOT IN ('COMPLETED', 'RESOLVED') AND is_archived = FALSE;

        IF p_move_incomplete_to_sprint_id IS NOT NULL THEN
            UPDATE public.work_items
            SET sprint_id = p_move_incomplete_to_sprint_id, updated_at = NOW()
            WHERE sprint_id = p_sprint_id AND UPPER(status) NOT IN ('COMPLETED', 'RESOLVED') AND is_archived = FALSE;
        ELSE
            -- Move incomplete items back to backlog
            UPDATE public.work_items
            SET sprint_id = NULL, updated_at = NOW()
            WHERE sprint_id = p_sprint_id AND UPPER(status) NOT IN ('COMPLETED', 'RESOLVED') AND is_archived = FALSE;
        END IF;

        UPDATE public.work_sprints
        SET status = 'COMPLETED',
            completed_at = NOW(),
            retrospective_notes = COALESCE(p_reason, retrospective_notes),
            updated_at = NOW()
        WHERE id = p_sprint_id;
    ELSE
        UPDATE public.work_sprints
        SET status = v_status,
            completed_at = CASE WHEN v_status = 'COMPLETED' THEN NOW() ELSE NULL END,
            updated_at = NOW()
        WHERE id = p_sprint_id;
    END IF;

    IF p_actor_id IS NOT NULL THEN
        SELECT COALESCE(full_name, 'System') INTO v_actor_name FROM public.profiles WHERE id = p_actor_id;
    END IF;

    INSERT INTO public.sprint_activity_logs (school_id, sprint_id, actor_id, action_type, old_value, new_value, notes)
    VALUES (
        p_school_id,
        p_sprint_id,
        p_actor_id,
        'SPRINT_STATUS_CHANGED',
        v_sprint.status,
        v_status,
        v_actor_name || ' transitioned sprint ' || v_sprint.name || ' from ' || v_sprint.status || ' to ' || v_status || CASE WHEN p_reason IS NOT NULL THEN ' (Reason: ' || p_reason || ')' ELSE '' END
    );

    RETURN jsonb_build_object(
        'success', true,
        'sprint_id', p_sprint_id,
        'new_status', v_status,
        'incomplete_items_reassigned', v_incomplete_count
    );
END;
$$;

-- C. Add existing backlog items to sprint
CREATE OR REPLACE FUNCTION public.sp_add_items_to_sprint(
    p_school_id UUID,
    p_sprint_id UUID,
    p_item_ids UUID[],
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sprint RECORD;
    v_updated_count INT := 0;
BEGIN
    SELECT * INTO v_sprint FROM public.work_sprints WHERE id = p_sprint_id AND school_id = p_school_id;
    IF v_sprint.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Sprint not found');
    END IF;

    UPDATE public.work_items
    SET sprint_id = p_sprint_id,
        updated_at = NOW()
    WHERE id = ANY(p_item_ids) AND school_id = p_school_id AND is_archived = FALSE;

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    RETURN jsonb_build_object('success', true, 'sprint_id', p_sprint_id, 'added_count', v_updated_count);
END;
$$;

-- D. Remove item from sprint (return to backlog)
CREATE OR REPLACE FUNCTION public.sp_remove_item_from_sprint(
    p_school_id UUID,
    p_sprint_id UUID,
    p_item_id UUID,
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item RECORD;
BEGIN
    SELECT * INTO v_item FROM public.work_items WHERE id = p_item_id AND school_id = p_school_id;
    IF v_item.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Work item not found');
    END IF;

    UPDATE public.work_items
    SET sprint_id = NULL,
        updated_at = NOW()
    WHERE id = p_item_id AND school_id = p_school_id;

    RETURN jsonb_build_object('success', true, 'item_id', p_item_id, 'sprint_id', p_sprint_id);
END;
$$;

-- E. Move items between sprints
CREATE OR REPLACE FUNCTION public.sp_move_items_to_sprint(
    p_school_id UUID,
    p_target_sprint_id UUID,
    p_item_ids UUID[],
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sprint RECORD;
    v_updated_count INT := 0;
BEGIN
    IF p_target_sprint_id IS NOT NULL THEN
        SELECT * INTO v_sprint FROM public.work_sprints WHERE id = p_target_sprint_id AND school_id = p_school_id;
        IF v_sprint.id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Target sprint not found');
        END IF;
    END IF;

    UPDATE public.work_items
    SET sprint_id = p_target_sprint_id,
        updated_at = NOW()
    WHERE id = ANY(p_item_ids) AND school_id = p_school_id AND is_archived = FALSE;

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    RETURN jsonb_build_object('success', true, 'target_sprint_id', p_target_sprint_id, 'moved_count', v_updated_count);
END;
$$;

-- F. Manage Sprint Team Members (Add, Update Capacity, Remove)
CREATE OR REPLACE FUNCTION public.sp_manage_sprint_member(
    p_school_id UUID,
    p_sprint_id UUID,
    p_user_id UUID,
    p_role VARCHAR DEFAULT 'Member',
    p_available_hours NUMERIC DEFAULT 80.0,
    p_action VARCHAR DEFAULT 'UPSERT' -- UPSERT, REMOVE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF UPPER(p_action) = 'REMOVE' THEN
        DELETE FROM public.sprint_members WHERE sprint_id = p_sprint_id AND user_id = p_user_id;
        RETURN jsonb_build_object('success', true, 'action', 'REMOVED');
    ELSE
        INSERT INTO public.sprint_members (school_id, sprint_id, user_id, role, available_hours)
        VALUES (p_school_id, p_sprint_id, p_user_id, COALESCE(p_role, 'Member'), COALESCE(p_available_hours, 80.0))
        ON CONFLICT (sprint_id, user_id)
        DO UPDATE SET role = EXCLUDED.role, available_hours = EXCLUDED.available_hours;
        RETURN jsonb_build_object('success', true, 'action', 'SAVED');
    END IF;
END;
$$;

-- G. Manage Sprint Blockers (Create, Resolve, Delete)
CREATE OR REPLACE FUNCTION public.sp_manage_sprint_blocker(
    p_school_id UUID,
    p_sprint_id UUID,
    p_blocker_id UUID DEFAULT NULL,
    p_work_item_id UUID DEFAULT NULL,
    p_title VARCHAR DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_severity VARCHAR DEFAULT 'HIGH',
    p_status VARCHAR DEFAULT 'OPEN',
    p_owner_id UUID DEFAULT NULL,
    p_expected_resolution_date DATE DEFAULT NULL,
    p_resolution_notes TEXT DEFAULT NULL,
    p_action VARCHAR DEFAULT 'CREATE', -- CREATE, UPDATE, RESOLVE, DELETE
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID := COALESCE(p_blocker_id, uuid_generate_v4());
BEGIN
    IF UPPER(p_action) = 'DELETE' THEN
        DELETE FROM public.sprint_blockers WHERE id = p_blocker_id AND sprint_id = p_sprint_id;
        RETURN jsonb_build_object('success', true, 'action', 'DELETED', 'blocker_id', p_blocker_id);
    ELSIF UPPER(p_action) = 'RESOLVE' THEN
        UPDATE public.sprint_blockers
        SET status = 'RESOLVED',
            resolved_at = NOW(),
            resolution_notes = COALESCE(p_resolution_notes, resolution_notes),
            updated_at = NOW()
        WHERE id = p_blocker_id AND sprint_id = p_sprint_id;
        RETURN jsonb_build_object('success', true, 'action', 'RESOLVED', 'blocker_id', p_blocker_id);
    ELSIF UPPER(p_action) = 'UPDATE' THEN
        UPDATE public.sprint_blockers
        SET title = COALESCE(p_title, title),
            description = COALESCE(p_description, description),
            severity = COALESCE(UPPER(p_severity), severity),
            status = COALESCE(UPPER(p_status), status),
            owner_id = COALESCE(p_owner_id, owner_id),
            expected_resolution_date = COALESCE(p_expected_resolution_date, expected_resolution_date),
            resolution_notes = COALESCE(p_resolution_notes, resolution_notes),
            updated_at = NOW()
        WHERE id = p_blocker_id AND sprint_id = p_sprint_id;
        RETURN jsonb_build_object('success', true, 'action', 'UPDATED', 'blocker_id', p_blocker_id);
    ELSE
        -- CREATE
        INSERT INTO public.sprint_blockers (
            id, school_id, sprint_id, work_item_id, title, description,
            severity, status, reporter_id, owner_id, expected_resolution_date
        ) VALUES (
            v_id, p_school_id, p_sprint_id, p_work_item_id, p_title, p_description,
            COALESCE(UPPER(p_severity), 'HIGH'), 'OPEN', p_actor_id, p_owner_id, p_expected_resolution_date
        );
        RETURN jsonb_build_object('success', true, 'action', 'CREATED', 'blocker_id', v_id);
    END IF;
END;
$$;

-- H. Manage Sprint Retrospective Entries & Action Items
CREATE OR REPLACE FUNCTION public.sp_manage_sprint_retrospective_entry(
    p_school_id UUID,
    p_sprint_id UUID,
    p_entry_id UUID DEFAULT NULL,
    p_category VARCHAR DEFAULT 'WENT_WELL',
    p_content TEXT DEFAULT NULL,
    p_action VARCHAR DEFAULT 'ADD', -- ADD, DELETE, VOTE
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_retro_id UUID;
    v_entry_id UUID := COALESCE(p_entry_id, uuid_generate_v4());
BEGIN
    -- Ensure retrospective record exists
    SELECT id INTO v_retro_id FROM public.sprint_retrospectives WHERE sprint_id = p_sprint_id;
    IF v_retro_id IS NULL THEN
        INSERT INTO public.sprint_retrospectives (school_id, sprint_id, facilitator_id)
        VALUES (p_school_id, p_sprint_id, p_actor_id)
        RETURNING id INTO v_retro_id;
    END IF;

    IF UPPER(p_action) = 'DELETE' THEN
        DELETE FROM public.sprint_retrospective_entries WHERE id = p_entry_id;
        RETURN jsonb_build_object('success', true, 'action', 'DELETED', 'entry_id', p_entry_id);
    ELSIF UPPER(p_action) = 'VOTE' THEN
        UPDATE public.sprint_retrospective_entries SET votes = votes + 1 WHERE id = p_entry_id;
        RETURN jsonb_build_object('success', true, 'action', 'VOTED', 'entry_id', p_entry_id);
    ELSE
        -- ADD
        INSERT INTO public.sprint_retrospective_entries (id, retrospective_id, category, content, created_by)
        VALUES (v_entry_id, v_retro_id, UPPER(p_category), p_content, p_actor_id);
        RETURN jsonb_build_object('success', true, 'action', 'ADDED', 'entry_id', v_entry_id);
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_manage_sprint_action_item(
    p_school_id UUID,
    p_sprint_id UUID,
    p_action_item_id UUID DEFAULT NULL,
    p_title VARCHAR DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_owner_id UUID DEFAULT NULL,
    p_due_date DATE DEFAULT NULL,
    p_priority VARCHAR DEFAULT 'MEDIUM',
    p_status VARCHAR DEFAULT 'OPEN',
    p_linked_work_item_id UUID DEFAULT NULL,
    p_action VARCHAR DEFAULT 'ADD', -- ADD, UPDATE, DELETE
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_retro_id UUID;
    v_id UUID := COALESCE(p_action_item_id, uuid_generate_v4());
BEGIN
    SELECT id INTO v_retro_id FROM public.sprint_retrospectives WHERE sprint_id = p_sprint_id;
    IF v_retro_id IS NULL THEN
        INSERT INTO public.sprint_retrospectives (school_id, sprint_id, facilitator_id)
        VALUES (p_school_id, p_sprint_id, p_actor_id)
        RETURNING id INTO v_retro_id;
    END IF;

    IF UPPER(p_action) = 'DELETE' THEN
        DELETE FROM public.sprint_action_items WHERE id = p_action_item_id;
        RETURN jsonb_build_object('success', true, 'action', 'DELETED');
    ELSIF UPPER(p_action) = 'UPDATE' THEN
        UPDATE public.sprint_action_items
        SET title = COALESCE(p_title, title),
            description = COALESCE(p_description, description),
            owner_id = COALESCE(p_owner_id, owner_id),
            due_date = COALESCE(p_due_date, due_date),
            priority = COALESCE(UPPER(p_priority), priority),
            status = COALESCE(UPPER(p_status), status),
            linked_work_item_id = COALESCE(p_linked_work_item_id, linked_work_item_id)
        WHERE id = p_action_item_id;
        RETURN jsonb_build_object('success', true, 'action', 'UPDATED');
    ELSE
        -- ADD
        INSERT INTO public.sprint_action_items (
            id, retrospective_id, title, description, owner_id, due_date, priority, status, linked_work_item_id
        ) VALUES (
            v_id, v_retro_id, p_title, p_description, p_owner_id, p_due_date,
            COALESCE(UPPER(p_priority), 'MEDIUM'), COALESCE(UPPER(p_status), 'OPEN'), p_linked_work_item_id
        );
        RETURN jsonb_build_object('success', true, 'action', 'ADDED', 'action_item_id', v_id);
    END IF;
END;
$$;

-- I. Enhanced sp_get_sprint_dashboard
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
    v_total_items INT := 0;
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
           b.name AS board_name,
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

    -- 3. Calculate Dynamic Sprint Metrics & Counts
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
        v_total_items,
        v_completed_items,
        v_in_progress_items,
        v_not_started_items,
        v_blocked_items,
        v_total_effort,
        v_completed_effort,
        v_remaining_effort
    FROM public.work_items w
    WHERE w.sprint_id = v_sprint_id
      AND w.school_id = p_school_id
      AND w.is_archived = FALSE;

    -- Check additional blockers from sprint_blockers table
    SELECT COUNT(*) INTO v_blocked_items
    FROM public.sprint_blockers
    WHERE sprint_id = v_sprint_id AND status = 'OPEN';

    IF v_total_items > 0 THEN
        v_completion_pct := ROUND((v_completed_items::NUMERIC / v_total_items::NUMERIC) * 100);
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
            jsonb_build_object('date_label', 'Jan 01', 'ideal_remaining', v_total_items, 'actual_remaining', v_total_items),
            jsonb_build_object('date_label', 'Jan 03', 'ideal_remaining', ROUND(v_total_items * 0.85), 'actual_remaining', ROUND(v_total_items * 0.90)),
            jsonb_build_object('date_label', 'Jan 05', 'ideal_remaining', ROUND(v_total_items * 0.70), 'actual_remaining', ROUND(v_total_items * 0.76)),
            jsonb_build_object('date_label', 'Jan 07', 'ideal_remaining', ROUND(v_total_items * 0.55), 'actual_remaining', ROUND(v_total_items * 0.62)),
            jsonb_build_object('date_label', 'Jan 09', 'ideal_remaining', ROUND(v_total_items * 0.40), 'actual_remaining', ROUND(v_total_items * 0.45)),
            jsonb_build_object('date_label', 'Jan 11', 'ideal_remaining', ROUND(v_total_items * 0.25), 'actual_remaining', ROUND(v_total_items * 0.33)),
            jsonb_build_object('date_label', 'Jan 14', 'ideal_remaining', 0, 'actual_remaining', (v_total_items - v_completed_items))
        );
    END IF;

    -- 5. Progress by Work Type Distribution
    SELECT jsonb_agg(
        jsonb_build_object(
            'type', INITCAP(sub.work_type),
            'count', sub.type_count,
            'percentage', CASE WHEN v_total_items > 0 THEN ROUND((sub.type_count::NUMERIC / v_total_items::NUMERIC) * 100) ELSE 0 END,
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
        SELECT work_type, COUNT(*) AS type_count
        FROM public.work_items
        WHERE sprint_id = v_sprint_id AND school_id = p_school_id AND is_archived = FALSE
        GROUP BY work_type
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
        WHERE wi.sprint_id = v_sprint_id AND wi.is_archived = FALSE
        GROUP BY wia.user_id
    ) w_stats ON w_stats.user_id = sm.user_id
    WHERE sm.sprint_id = v_sprint_id;

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
    v_offset := (p_page - 1) * p_page_size;

    SELECT jsonb_agg(
        jsonb_build_object(
            'id', parent.id,
            'item_number', parent.item_number,
            'title', parent.title,
            'work_type', parent.work_type,
            'priority', parent.priority,
            'status', parent.status,
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
                    'avatar_url', p.avatar_url
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
                            'avatar_url', cp.avatar_url
                        ))
                        FROM public.work_item_assignees cwia
                        JOIN public.profiles cp ON cp.id = cwia.user_id
                        WHERE cwia.work_item_id = child.id
                    ), '[]'::jsonb)
                ) ORDER BY child.created_at ASC)
                FROM public.work_items child
                WHERE child.parent_id = parent.id AND child.is_archived = FALSE
            ), '[]'::jsonb)
        )
    ) INTO v_sprint_items
    FROM (
        SELECT w.*
        FROM public.work_items w
        WHERE w.sprint_id = v_sprint_id
          AND w.school_id = p_school_id
          AND w.parent_id IS NULL
          AND w.is_archived = FALSE
          AND (p_search IS NULL OR w.title ILIKE '%' || p_search || '%' OR w.item_number ILIKE '%' || p_search || '%')
        ORDER BY w.created_at DESC
        OFFSET v_offset
        LIMIT p_page_size
    ) parent;

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
            'total_items', v_total_items,
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
        'total_items_count', v_total_items,
        'page', p_page,
        'page_size', p_page_size,
        'items', v_sprint_items
    );
END;
$$;

-- 8. Seed Default Members for Sprint 8
DO $$
DECLARE
    v_sprint_id UUID := '35ad7623-f5d2-4935-a203-98a26e2b5444';
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_super_admin UUID := '5198c4b0-f1cb-45db-9649-41688d0438ba';
    v_vihaan UUID := '10000000-0000-0000-0000-000000000002';
    v_aarav UUID;
    v_retro_id UUID := uuid_generate_v4();
BEGIN
    SELECT id INTO v_aarav FROM public.profiles WHERE full_name ILIKE '%Aarav%' LIMIT 1;

    -- Insert members
    INSERT INTO public.sprint_members (school_id, sprint_id, user_id, role, available_hours)
    VALUES 
        (v_school_id, v_sprint_id, v_super_admin, 'Sprint Lead', 80.0),
        (v_school_id, v_sprint_id, v_vihaan, 'Developer', 80.0)
    ON CONFLICT (sprint_id, user_id) DO NOTHING;

    IF v_aarav IS NOT NULL THEN
        INSERT INTO public.sprint_members (school_id, sprint_id, user_id, role, available_hours)
        VALUES (v_school_id, v_sprint_id, v_aarav, 'QA Engineer', 60.0)
        ON CONFLICT (sprint_id, user_id) DO NOTHING;
    END IF;

    -- Insert retrospective
    INSERT INTO public.sprint_retrospectives (id, school_id, sprint_id, facilitator_id, summary)
    VALUES (v_retro_id, v_school_id, v_sprint_id, v_super_admin, 'Strong velocity on core modules; exam timetable and library portal fixed on schedule.')
    ON CONFLICT (sprint_id) DO NOTHING;

    -- Insert retro entries
    SELECT id INTO v_retro_id FROM public.sprint_retrospectives WHERE sprint_id = v_sprint_id;
    IF v_retro_id IS NOT NULL THEN
        INSERT INTO public.sprint_retrospective_entries (retrospective_id, category, content, votes, created_by)
        VALUES
            (v_retro_id, 'WENT_WELL', 'Student portal UI responsiveness delivered ahead of schedule', 4, v_super_admin),
            (v_retro_id, 'WENT_WELL', 'Quick turnaround on projector repair in Room A-203', 2, v_vihaan),
            (v_retro_id, 'DID_NOT_GO_WELL', 'Third-party notification gateway rate limits delayed test broadcast', 3, v_super_admin),
            (v_retro_id, 'TO_IMPROVE', 'Automate daily burndown snapshot synchronization at 00:00 UTC', 5, v_super_admin)
        ON CONFLICT DO NOTHING;

        INSERT INTO public.sprint_action_items (retrospective_id, title, description, owner_id, due_date, priority, status)
        VALUES
            (v_retro_id, 'Implement Redis queue for bulk SMS notifications', 'Avoid rate-limiting during examination notices broadcast', v_vihaan, '2025-01-20', 'HIGH', 'IN_PROGRESS'),
            (v_retro_id, 'Set up automated nightly cron for sprint snapshots', 'Call sp_capture_sprint_daily_snapshots', v_super_admin, '2025-01-18', 'MEDIUM', 'OPEN')
        ON CONFLICT DO NOTHING;
    END IF;
END $$;
