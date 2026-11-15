-- ============================================================================
-- Migration 466: Azure DevOps-Grade Work Management System Enhancements
-- 1. Precision Status Change Audit Trail (who changed what to what)
-- 2. Effort Tracking: Story Points, Estimated Hours, Remaining Hours, Completed/Actual Hours
-- 3. Automatic Progress Percentage calculation based on effort & status
-- 4. Create Copy / Clone of Task / Story / Bug with links & attachments
-- 5. Linking Related Work: Multiple Tasks, Bugs, Dependencies (Child, Parent, Related, Blocks)
-- 6. Comments with User Mentions & Activity Logging
-- 7. Document / Attachment Management with Audit Trail
-- 8. Move Work Items seamlessly between Boards and Sprints
-- ============================================================================

-- 1. Ensure columns exist on public.work_items
ALTER TABLE public.work_items 
    ADD COLUMN IF NOT EXISTS story_points NUMERIC DEFAULT 0,
    ADD COLUMN IF NOT EXISTS estimated_hours NUMERIC DEFAULT 0,
    ADD COLUMN IF NOT EXISTS remaining_hours NUMERIC DEFAULT 0,
    ADD COLUMN IF NOT EXISTS actual_hours NUMERIC DEFAULT 0,
    ADD COLUMN IF NOT EXISTS severity VARCHAR(50) DEFAULT 'Medium',
    ADD COLUMN IF NOT EXISTS reason VARCHAR(255);

-- 2. Ensure actor_id exists in activity_logs
ALTER TABLE public.work_item_activity_logs
    ADD COLUMN IF NOT EXISTS actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS old_value TEXT,
    ADD COLUMN IF NOT EXISTS new_value TEXT,
    ADD COLUMN IF NOT EXISTS field_name VARCHAR(100);

-- ----------------------------------------------------------------------------
-- 3. STORED PROCEDURE: sp_transition_work_item_status (Enhanced with Actor Audit)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_transition_work_item_status(
    p_item_id UUID,
    p_new_status VARCHAR,
    p_actor_id UUID DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_old_status VARCHAR;
    v_school_id UUID;
    v_item_number VARCHAR;
    v_item_title VARCHAR;
    v_new_progress INT;
    v_actor_name VARCHAR;
    v_actor_avatar VARCHAR;
    v_remaining_hours NUMERIC;
    v_actual_hours NUMERIC;
    v_estimated_hours NUMERIC;
    v_log_id UUID := uuid_generate_v4();
BEGIN
    SELECT status, school_id, item_number, title, remaining_hours, actual_hours, estimated_hours
    INTO v_old_status, v_school_id, v_item_number, v_item_title, v_remaining_hours, v_actual_hours, v_estimated_hours
    FROM public.work_items
    WHERE id = p_item_id;

    IF v_old_status IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Work item not found');
    END IF;

    -- Lookup actor details
    IF p_actor_id IS NOT NULL THEN
        SELECT full_name, avatar_url INTO v_actor_name, v_actor_avatar
        FROM public.profiles WHERE id = p_actor_id;
    END IF;
    v_actor_name := COALESCE(v_actor_name, 'System');

    -- Auto-calculate progress based on status and hours
    IF UPPER(p_new_status) IN ('COMPLETED', 'RESOLVED') THEN
        v_new_progress := 100;
        v_remaining_hours := 0;
        IF v_actual_hours IS NULL OR v_actual_hours = 0 THEN
            v_actual_hours := COALESCE(v_estimated_hours, 8.0);
        END IF;
    ELSIF UPPER(p_new_status) = 'NEW' THEN
        v_new_progress := 0;
        v_remaining_hours := COALESCE(v_estimated_hours, 8.0);
    ELSE
        -- ACTIVE / IN_PROGRESS
        IF (COALESCE(v_actual_hours, 0) + COALESCE(v_remaining_hours, 0)) > 0 THEN
            v_new_progress := ROUND((COALESCE(v_actual_hours, 0) / (COALESCE(v_actual_hours, 0) + COALESCE(v_remaining_hours, 0))) * 100);
        ELSE
            v_new_progress := 50;
        END IF;
    END IF;

    -- Update work item
    UPDATE public.work_items
    SET status = UPPER(p_new_status),
        progress_percentage = v_new_progress,
        remaining_hours = v_remaining_hours,
        actual_hours = v_actual_hours,
        completed_at = CASE WHEN UPPER(p_new_status) IN ('COMPLETED', 'RESOLVED') THEN NOW() ELSE NULL END,
        updated_at = NOW(),
        updated_by = p_actor_id
    WHERE id = p_item_id;

    -- Log detailed audit trail
    IF UPPER(v_old_status) != UPPER(p_new_status) THEN
        INSERT INTO public.work_item_activity_logs (
            id, work_item_id, school_id, actor_id, action_type, field_name, old_value, new_value, message, created_at
        ) VALUES (
            v_log_id, p_item_id, v_school_id, p_actor_id, 'STATUS_CHANGE', 'status', v_old_status, UPPER(p_new_status),
            v_actor_name || ' changed status from ' || v_old_status || ' to ' || UPPER(p_new_status) || COALESCE(' (' || p_notes || ')', ''),
            NOW()
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'item_id', p_item_id,
        'item_number', v_item_number,
        'old_status', v_old_status,
        'new_status', UPPER(p_new_status),
        'actor_name', v_actor_name,
        'progress_percentage', v_new_progress,
        'remaining_hours', v_remaining_hours,
        'actual_hours', v_actual_hours
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 4. STORED PROCEDURE: sp_reorder_kanban (Enhanced with Actor Tracking)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_reorder_kanban(
    p_school_id UUID,
    p_board_id UUID,
    p_item_id UUID,
    p_new_status VARCHAR,
    p_new_rank NUMERIC,
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_old_status VARCHAR;
    v_actor_name VARCHAR := 'System';
    v_new_progress INT;
BEGIN
    SELECT status INTO v_old_status FROM public.work_items WHERE id = p_item_id AND school_id = p_school_id;

    IF v_old_status IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Item not found');
    END IF;

    IF p_actor_id IS NOT NULL THEN
        SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = p_actor_id;
        v_actor_name := COALESCE(v_actor_name, 'System');
    END IF;

    IF UPPER(p_new_status) IN ('COMPLETED', 'RESOLVED') THEN
        v_new_progress := 100;
    ELSIF UPPER(p_new_status) = 'NEW' THEN
        v_new_progress := 0;
    ELSE
        v_new_progress := 50;
    END IF;

    UPDATE public.work_items
    SET status = UPPER(p_new_status),
        rank = p_new_rank,
        progress_percentage = v_new_progress,
        updated_at = NOW(),
        updated_by = p_actor_id
    WHERE id = p_item_id;

    IF UPPER(v_old_status) != UPPER(p_new_status) THEN
        INSERT INTO public.work_item_activity_logs (
            work_item_id, school_id, actor_id, action_type, field_name, old_value, new_value, message
        ) VALUES (
            p_item_id, p_school_id, p_actor_id, 'STATUS_CHANGE', 'status', v_old_status, UPPER(p_new_status),
            v_actor_name || ' moved ' || v_old_status || ' to ' || UPPER(p_new_status)
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'item_id', p_item_id,
        'status', UPPER(p_new_status),
        'rank', p_new_rank,
        'actor_name', v_actor_name,
        'progress_percentage', v_new_progress
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. STORED PROCEDURE: sp_copy_work_item (Azure DevOps Create Copy Feature)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_copy_work_item(
    p_school_id UUID,
    p_source_item_id UUID,
    p_new_title VARCHAR DEFAULT NULL,
    p_include_children BOOLEAN DEFAULT TRUE,
    p_include_attachments BOOLEAN DEFAULT TRUE,
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_source RECORD;
    v_new_id UUID := uuid_generate_v4();
    v_new_number VARCHAR;
    v_prefix VARCHAR;
    v_next_val INT;
    v_child RECORD;
    v_child_new_id UUID;
    v_child_new_number VARCHAR;
    v_actor_name VARCHAR := 'System';
BEGIN
    SELECT * INTO v_source FROM public.work_items WHERE id = p_source_item_id AND school_id = p_school_id;
    IF v_source.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Source work item not found');
    END IF;

    IF p_actor_id IS NOT NULL THEN
        SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = p_actor_id;
        v_actor_name := COALESCE(v_actor_name, 'System');
    END IF;

    -- Generate sequence number based on work_type
    IF v_source.work_type = 'STORY' THEN v_prefix := 'ST';
    ELSIF v_source.work_type = 'BUG' THEN v_prefix := 'BG';
    ELSIF v_source.work_type = 'TASK' THEN v_prefix := 'TK';
    ELSIF v_source.work_type = 'EPIC' THEN v_prefix := 'EP';
    ELSE v_prefix := 'WM';
    END IF;

    SELECT COALESCE(MAX(SUBSTRING(item_number FROM '[0-9]+')::INT), 1080) + 1 INTO v_next_val
    FROM public.work_items
    WHERE school_id = p_school_id AND item_number LIKE v_prefix || '-%';

    v_new_number := v_prefix || '-' || v_next_val;

    -- Clone primary work item
    INSERT INTO public.work_items (
        id, school_id, board_id, sprint_id, parent_id, item_number, title, description,
        work_type, priority, status, category, story_points, estimated_hours, remaining_hours, actual_hours,
        progress_percentage, rank, reporter_id, start_date, due_date, created_by, is_archived
    ) VALUES (
        v_new_id, p_school_id, v_source.board_id, v_source.sprint_id, v_source.parent_id,
        v_new_number, COALESCE(p_new_title, 'Copy of ' || v_source.title), v_source.description,
        v_source.work_type, v_source.priority, 'NEW', v_source.category,
        v_source.story_points, v_source.estimated_hours, v_source.estimated_hours, 0,
        0, v_source.rank + 1, p_actor_id, CURRENT_DATE, v_source.due_date, p_actor_id, FALSE
    );

    -- Copy Labels
    INSERT INTO public.work_item_labels (id, work_item_id, label)
    SELECT uuid_generate_v4(), v_new_id, label
    FROM public.work_item_labels WHERE work_item_id = p_source_item_id;

    -- Copy Checklists
    INSERT INTO public.work_item_checklists (id, work_item_id, title, is_completed, sort_order)
    SELECT uuid_generate_v4(), v_new_id, title, FALSE, sort_order
    FROM public.work_item_checklists WHERE work_item_id = p_source_item_id;

    -- Copy Attachments if requested
    IF p_include_attachments THEN
        INSERT INTO public.work_item_attachments (id, work_item_id, file_name, file_url, file_size_bytes, file_type, uploaded_by)
        SELECT uuid_generate_v4(), v_new_id, file_name, file_url, file_size_bytes, file_type, p_actor_id
        FROM public.work_item_attachments WHERE work_item_id = p_source_item_id;
    END IF;

    -- Link as Related / Duplicate
    INSERT INTO public.work_item_dependencies (id, work_item_id, depends_on_item_id, dependency_type)
    VALUES (uuid_generate_v4(), v_new_id, p_source_item_id, 'RELATED');

    -- Copy Children if requested
    IF p_include_children THEN
        FOR v_child IN SELECT * FROM public.work_items WHERE parent_id = p_source_item_id AND is_archived = FALSE LOOP
            v_next_val := v_next_val + 1;
            v_child_new_id := uuid_generate_v4();
            v_child_new_number := 'TK-' || v_next_val;

            INSERT INTO public.work_items (
                id, school_id, board_id, sprint_id, parent_id, item_number, title, description,
                work_type, priority, status, category, story_points, estimated_hours, remaining_hours, actual_hours,
                progress_percentage, rank, reporter_id, created_by, is_archived
            ) VALUES (
                v_child_new_id, p_school_id, v_child.board_id, v_child.sprint_id, v_new_id,
                v_child_new_number, 'Copy of ' || v_child.title, v_child.description,
                v_child.work_type, v_child.priority, 'NEW', v_child.category,
                v_child.story_points, v_child.estimated_hours, v_child.estimated_hours, 0,
                0, v_child.rank, p_actor_id, p_actor_id, FALSE
            );
        END LOOP;
    END IF;

    -- Log Activity
    INSERT INTO public.work_item_activity_logs (
        work_item_id, school_id, actor_id, action_type, message
    ) VALUES (
        v_new_id, p_school_id, p_actor_id, 'CREATED',
        v_actor_name || ' created a copy from ' || v_source.item_number || ' (' || v_source.title || ')'
    );

    RETURN jsonb_build_object(
        'success', true,
        'new_id', v_new_id,
        'item_number', v_new_number,
        'title', COALESCE(p_new_title, 'Copy of ' || v_source.title),
        'work_type', v_source.work_type
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 6. STORED PROCEDURE: sp_update_work_item_azure (Comprehensive Azure DevOps Edit)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_update_work_item_azure(
    p_school_id UUID,
    p_item_id UUID,
    p_actor_id UUID DEFAULT NULL,
    p_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_old RECORD;
    v_actor_name VARCHAR := 'System';
    v_title VARCHAR;
    v_desc TEXT;
    v_status VARCHAR;
    v_priority VARCHAR;
    v_category VARCHAR;
    v_work_type VARCHAR;
    v_board_id UUID;
    v_sprint_id UUID;
    v_parent_id UUID;
    v_story_points NUMERIC;
    v_estimated_hours NUMERIC;
    v_remaining_hours NUMERIC;
    v_actual_hours NUMERIC;
    v_progress INT;
    v_due_date DATE;
    v_start_date DATE;
    v_assignee_ids JSONB;
    v_labels JSONB;
    v_assignee_id TEXT;
    v_label_str TEXT;
BEGIN
    SELECT * INTO v_old FROM public.work_items WHERE id = p_item_id AND school_id = p_school_id;
    IF v_old.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Work item not found');
    END IF;

    IF p_actor_id IS NOT NULL THEN
        SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = p_actor_id;
        v_actor_name := COALESCE(v_actor_name, 'System');
    END IF;

    v_title := COALESCE(p_payload->>'title', v_old.title);
    v_desc := COALESCE(p_payload->>'description', v_old.description);
    v_status := UPPER(COALESCE(p_payload->>'status', v_old.status));
    v_priority := UPPER(COALESCE(p_payload->>'priority', v_old.priority));
    v_category := COALESCE(p_payload->>'category', v_old.category);
    v_work_type := UPPER(COALESCE(p_payload->>'work_type', v_old.work_type));

    IF p_payload ? 'board_id' THEN
        v_board_id := (p_payload->>'board_id')::UUID;
    ELSE
        v_board_id := v_old.board_id;
    END IF;

    IF p_payload ? 'sprint_id' THEN
        v_sprint_id := (p_payload->>'sprint_id')::UUID;
    ELSE
        v_sprint_id := v_old.sprint_id;
    END IF;

    IF p_payload ? 'parent_id' THEN
        v_parent_id := (p_payload->>'parent_id')::UUID;
    ELSE
        v_parent_id := v_old.parent_id;
    END IF;

    -- Effort
    v_story_points := COALESCE((p_payload->>'story_points')::NUMERIC, v_old.story_points, 0);
    v_estimated_hours := COALESCE((p_payload->>'estimated_hours')::NUMERIC, v_old.estimated_hours, 0);
    v_remaining_hours := COALESCE((p_payload->>'remaining_hours')::NUMERIC, v_old.remaining_hours, 0);
    v_actual_hours := COALESCE((p_payload->>'actual_hours')::NUMERIC, (p_payload->>'completed_hours')::NUMERIC, v_old.actual_hours, 0);

    -- Progress calculation
    IF v_status IN ('COMPLETED', 'RESOLVED') THEN
        v_progress := 100;
        v_remaining_hours := 0;
    ELSIF (v_actual_hours + v_remaining_hours) > 0 THEN
        v_progress := ROUND((v_actual_hours / (v_actual_hours + v_remaining_hours)) * 100);
    ELSIF v_estimated_hours > 0 AND v_remaining_hours >= 0 THEN
        v_progress := ROUND(((v_estimated_hours - v_remaining_hours) / v_estimated_hours) * 100);
    ELSE
        v_progress := COALESCE((p_payload->>'progress_percentage')::INT, v_old.progress_percentage, 0);
    END IF;
    v_progress := LEAST(GREATEST(v_progress, 0), 100);

    IF p_payload ? 'due_date' THEN
        v_due_date := (p_payload->>'due_date')::DATE;
    ELSE
        v_due_date := v_old.due_date;
    END IF;

    IF p_payload ? 'start_date' THEN
        v_start_date := (p_payload->>'start_date')::DATE;
    ELSE
        v_start_date := v_old.start_date;
    END IF;

    -- Apply update
    UPDATE public.work_items
    SET title = v_title,
        description = v_desc,
        status = v_status,
        priority = v_priority,
        category = v_category,
        work_type = v_work_type,
        board_id = v_board_id,
        sprint_id = v_sprint_id,
        parent_id = v_parent_id,
        story_points = v_story_points,
        estimated_hours = v_estimated_hours,
        remaining_hours = v_remaining_hours,
        actual_hours = v_actual_hours,
        progress_percentage = v_progress,
        due_date = v_due_date,
        start_date = v_start_date,
        updated_at = NOW(),
        updated_by = p_actor_id
    WHERE id = p_item_id;

    -- Audit Log for Status Change
    IF UPPER(v_old.status) != v_status THEN
        INSERT INTO public.work_item_activity_logs (
            work_item_id, school_id, actor_id, action_type, field_name, old_value, new_value, message
        ) VALUES (
            p_item_id, p_school_id, p_actor_id, 'STATUS_CHANGE', 'status', v_old.status, v_status,
            v_actor_name || ' changed status from ' || v_old.status || ' to ' || v_status
        );
    END IF;

    -- Audit Log for Sprint Change
    IF v_old.sprint_id IS DISTINCT FROM v_sprint_id THEN
        INSERT INTO public.work_item_activity_logs (
            work_item_id, school_id, actor_id, action_type, field_name, message
        ) VALUES (
            p_item_id, p_school_id, p_actor_id, 'MOVED_SPRINT', 'sprint_id',
            v_actor_name || ' moved item to ' || COALESCE((SELECT name FROM public.work_sprints WHERE id = v_sprint_id), 'Backlog')
        );
    END IF;

    -- Audit Log for Board Change
    IF v_old.board_id IS DISTINCT FROM v_board_id THEN
        INSERT INTO public.work_item_activity_logs (
            work_item_id, school_id, actor_id, action_type, field_name, message
        ) VALUES (
            p_item_id, p_school_id, p_actor_id, 'MOVED_BOARD', 'board_id',
            v_actor_name || ' moved item to board ' || COALESCE((SELECT name FROM public.work_boards WHERE id = v_board_id), 'Default')
        );
    END IF;

    -- Update Assignees if array provided
    IF p_payload ? 'assignee_ids' THEN
        DELETE FROM public.work_item_assignees WHERE work_item_id = p_item_id;
        FOR v_assignee_id IN SELECT jsonb_array_elements_text(p_payload->'assignee_ids') LOOP
            IF v_assignee_id IS NOT NULL AND v_assignee_id != '' THEN
                INSERT INTO public.work_item_assignees (id, work_item_id, user_id, role_type)
                VALUES (uuid_generate_v4(), p_item_id, v_assignee_id::UUID, 'PRIMARY')
                ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;
    END IF;

    -- Update Labels if array provided
    IF p_payload ? 'labels' THEN
        DELETE FROM public.work_item_labels WHERE work_item_id = p_item_id;
        FOR v_label_str IN SELECT jsonb_array_elements_text(p_payload->'labels') LOOP
            IF v_label_str IS NOT NULL AND v_label_str != '' THEN
                INSERT INTO public.work_item_labels (id, work_item_id, label)
                VALUES (uuid_generate_v4(), p_item_id, v_label_str);
            END IF;
        END LOOP;
    END IF;

    RETURN public.sp_get_work_item_detail(p_item_id);
END;
$$;

-- ----------------------------------------------------------------------------
-- 7. STORED PROCEDURE: sp_link_work_items (Child, Parent, Related, Blocks)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_link_work_items(
    p_school_id UUID,
    p_source_id UUID,
    p_target_id UUID,
    p_link_type VARCHAR,
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_source_num VARCHAR;
    v_target_num VARCHAR;
    v_actor_name VARCHAR := 'System';
BEGIN
    SELECT item_number INTO v_source_num FROM public.work_items WHERE id = p_source_id AND school_id = p_school_id;
    SELECT item_number INTO v_target_num FROM public.work_items WHERE id = p_target_id AND school_id = p_school_id;

    IF v_source_num IS NULL OR v_target_num IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'One or both work items not found');
    END IF;

    IF p_actor_id IS NOT NULL THEN
        SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = p_actor_id;
        v_actor_name := COALESCE(v_actor_name, 'System');
    END IF;

    -- Handle Parent-Child hierarchy
    IF UPPER(p_link_type) = 'CHILD' THEN
        UPDATE public.work_items SET parent_id = p_source_id, updated_at = NOW() WHERE id = p_target_id;
    ELSIF UPPER(p_link_type) = 'PARENT' THEN
        UPDATE public.work_items SET parent_id = p_target_id, updated_at = NOW() WHERE id = p_source_id;
    END IF;

    -- Insert dependency record
    INSERT INTO public.work_item_dependencies (id, work_item_id, depends_on_item_id, dependency_type)
    VALUES (uuid_generate_v4(), p_source_id, p_target_id, UPPER(p_link_type))
    ON CONFLICT DO NOTHING;

    -- Audit Log
    INSERT INTO public.work_item_activity_logs (
        work_item_id, school_id, actor_id, action_type, message
    ) VALUES (
        p_source_id, p_school_id, p_actor_id, 'LINK_ADDED',
        v_actor_name || ' linked ' || v_target_num || ' as ' || UPPER(p_link_type)
    );

    RETURN jsonb_build_object('success', true, 'source_number', v_source_num, 'target_number', v_target_num, 'link_type', p_link_type);
END;
$$;

-- ----------------------------------------------------------------------------
-- 8. STORED PROCEDURE: sp_unlink_work_items
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_unlink_work_items(
    p_school_id UUID,
    p_source_id UUID,
    p_target_id UUID,
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_source_num VARCHAR;
    v_target_num VARCHAR;
    v_actor_name VARCHAR := 'System';
BEGIN
    SELECT item_number INTO v_source_num FROM public.work_items WHERE id = p_source_id;
    SELECT item_number INTO v_target_num FROM public.work_items WHERE id = p_target_id;

    IF p_actor_id IS NOT NULL THEN
        SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = p_actor_id;
        v_actor_name := COALESCE(v_actor_name, 'System');
    END IF;

    -- Clear parent if it was linked
    UPDATE public.work_items SET parent_id = NULL WHERE id = p_target_id AND parent_id = p_source_id;
    UPDATE public.work_items SET parent_id = NULL WHERE id = p_source_id AND parent_id = p_target_id;

    -- Delete dependency
    DELETE FROM public.work_item_dependencies
    WHERE (work_item_id = p_source_id AND depends_on_item_id = p_target_id)
       OR (work_item_id = p_target_id AND depends_on_item_id = p_source_id);

    -- Log
    INSERT INTO public.work_item_activity_logs (
        work_item_id, school_id, actor_id, action_type, message
    ) VALUES (
        p_source_id, p_school_id, p_actor_id, 'LINK_REMOVED',
        v_actor_name || ' unlinked ' || COALESCE(v_target_num, 'item')
    );

    RETURN jsonb_build_object('success', true);
END;
$$;

-- ----------------------------------------------------------------------------
-- 9. STORED PROCEDURE: sp_get_work_item_detail (Enhanced with Azure Effort & Relations)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_get_work_item_detail(
    p_item_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item RECORD;
    v_assignees JSONB;
    v_checklists JSONB;
    v_attachments JSONB;
    v_comments JSONB;
    v_activity JSONB;
    v_dependencies JSONB;
    v_children JSONB;
    v_labels JSONB;
BEGIN
    SELECT
        w.*,
        b.name AS board_name,
        b.code AS board_code,
        s.name AS sprint_name,
        s.sprint_number,
        p_rep.full_name AS reporter_name,
        p_rep.avatar_url AS reporter_avatar,
        p_parent.item_number AS parent_code,
        p_parent.title AS parent_title,
        to_char(w.start_date, 'Mon DD, YYYY') AS start_date_fmt,
        to_char(w.due_date, 'Mon DD, YYYY') AS due_date_fmt,
        to_char(w.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS created_at_iso,
        to_char(w.updated_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS updated_at_iso
    INTO v_item
    FROM public.work_items w
    LEFT JOIN public.work_boards b ON b.id = w.board_id
    LEFT JOIN public.work_sprints s ON s.id = w.sprint_id
    LEFT JOIN public.profiles p_rep ON p_rep.id = w.reporter_id
    LEFT JOIN public.work_items p_parent ON p_parent.id = w.parent_id
    WHERE w.id = p_item_id;

    IF v_item.id IS NULL THEN
        RETURN '{}'::jsonb;
    END IF;

    -- Assignees
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'user_id', p.id,
                'full_name', p.full_name,
                'role', p.role,
                'role_type', a.role_type,
                'avatar_url', p.avatar_url
            ) ORDER BY a.assigned_at ASC
        ), '[]'::jsonb
    ) INTO v_assignees
    FROM public.work_item_assignees a
    JOIN public.profiles p ON p.id = a.user_id
    WHERE a.work_item_id = p_item_id;

    -- Checklists
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', c.id,
                'title', c.title,
                'is_completed', c.is_completed,
                'sort_order', c.sort_order
            ) ORDER BY c.sort_order ASC, c.created_at ASC
        ), '[]'::jsonb
    ) INTO v_checklists
    FROM public.work_item_checklists c
    WHERE c.work_item_id = p_item_id;

    -- Attachments
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', a.id,
                'file_name', a.file_name,
                'file_url', a.file_url,
                'file_size_bytes', a.file_size_bytes,
                'file_type', a.file_type,
                'uploaded_by', a.uploaded_by,
                'uploaded_by_name', COALESCE(p.full_name, 'User'),
                'created_at', to_char(a.created_at, 'Mon DD, YYYY')
            ) ORDER BY a.created_at DESC
        ), '[]'::jsonb
    ) INTO v_attachments
    FROM public.work_item_attachments a
    LEFT JOIN public.profiles p ON p.id = a.uploaded_by
    WHERE a.work_item_id = p_item_id;

    -- Comments
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', c.id,
                'user_id', c.user_id,
                'author_name', COALESCE(p.full_name, 'User'),
                'author_avatar', p.avatar_url,
                'author_role', p.role,
                'comment_text', c.comment_text,
                'created_at', to_char(c.created_at, 'Mon DD, YYYY at HH24:MI'),
                'created_at_iso', to_char(c.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
            ) ORDER BY c.created_at DESC
        ), '[]'::jsonb
    ) INTO v_comments
    FROM public.work_item_comments c
    LEFT JOIN public.profiles p ON p.id = c.user_id
    WHERE c.work_item_id = p_item_id;

    -- Activity Logs (who changed what to what)
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', l.id,
                'action_type', l.action_type,
                'field_name', l.field_name,
                'old_value', l.old_value,
                'new_value', l.new_value,
                'message', l.message,
                'actor_name', COALESCE(p.full_name, 'System'),
                'actor_avatar', p.avatar_url,
                'actor_role', p.role,
                'created_at', to_char(l.created_at, 'Mon DD, YYYY at HH24:MI'),
                'created_at_iso', to_char(l.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
            ) ORDER BY l.created_at DESC
        ), '[]'::jsonb
    ) INTO v_activity
    FROM public.work_item_activity_logs l
    LEFT JOIN public.profiles p ON p.id = l.actor_id
    WHERE l.work_item_id = p_item_id;

    -- Children (Multiple tasks/bugs attached to this Story)
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', ch.id,
                'item_number', ch.item_number,
                'title', ch.title,
                'work_type', ch.work_type,
                'status', ch.status,
                'priority', ch.priority,
                'estimated_hours', COALESCE(ch.estimated_hours, 0),
                'remaining_hours', COALESCE(ch.remaining_hours, 0),
                'actual_hours', COALESCE(ch.actual_hours, 0),
                'progress_percentage', COALESCE(ch.progress_percentage, 0)
            ) ORDER BY ch.rank ASC, ch.item_number ASC
        ), '[]'::jsonb
    ) INTO v_children
    FROM public.work_items ch
    WHERE ch.parent_id = p_item_id AND ch.is_archived = FALSE;

    -- Dependencies & Related Links
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', dep.id,
                'linked_item_id', rel.id,
                'item_number', rel.item_number,
                'title', rel.title,
                'work_type', rel.work_type,
                'status', rel.status,
                'priority', rel.priority,
                'dependency_type', dep.dependency_type
            )
        ), '[]'::jsonb
    ) INTO v_dependencies
    FROM public.work_item_dependencies dep
    JOIN public.work_items rel ON rel.id = dep.depends_on_item_id
    WHERE dep.work_item_id = p_item_id AND rel.is_archived = FALSE;

    -- Labels / Tags
    SELECT COALESCE(
        jsonb_agg(l.label), '[]'::jsonb
    ) INTO v_labels
    FROM public.work_item_labels l
    WHERE l.work_item_id = p_item_id;

    RETURN jsonb_build_object(
        'id', v_item.id,
        'item_number', v_item.item_number,
        'title', v_item.title,
        'description', v_item.description,
        'work_type', v_item.work_type,
        'priority', v_item.priority,
        'status', v_item.status,
        'category', v_item.category,
        'board_id', v_item.board_id,
        'board_name', v_item.board_name,
        'board_code', v_item.board_code,
        'sprint_id', v_item.sprint_id,
        'sprint_name', v_item.sprint_name,
        'parent_id', v_item.parent_id,
        'parent_code', v_item.parent_code,
        'parent_title', v_item.parent_title,
        'story_points', COALESCE(v_item.story_points, 0),
        'estimated_hours', COALESCE(v_item.estimated_hours, 0),
        'remaining_hours', COALESCE(v_item.remaining_hours, 0),
        'actual_hours', COALESCE(v_item.actual_hours, 0),
        'progress_percentage', COALESCE(v_item.progress_percentage, 0),
        'rank', v_item.rank,
        'reporter_id', v_item.reporter_id,
        'reporter_name', v_item.reporter_name,
        'reporter_avatar', v_item.reporter_avatar,
        'start_date', v_item.start_date,
        'due_date', v_item.due_date,
        'start_date_fmt', v_item.start_date_fmt,
        'due_date_fmt', v_item.due_date_fmt,
        'created_at_iso', v_item.created_at_iso,
        'updated_at_iso', v_item.updated_at_iso,
        'assignees', v_assignees,
        'labels', v_labels,
        'checklists', v_checklists,
        'attachments', v_attachments,
        'comments', v_comments,
        'activity_logs', v_activity,
        'children', v_children,
        'dependencies', v_dependencies
    );
END;
$$;


-- Overload for 4 or 5 arguments without board_id
CREATE OR REPLACE FUNCTION public.sp_reorder_kanban(
    p_school_id UUID,
    p_item_id UUID,
    p_new_status VARCHAR,
    p_new_rank NUMERIC,
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN public.sp_reorder_kanban(p_school_id, NULL, p_item_id, p_new_status, p_new_rank, p_actor_id);
END;
$$;
