-- ============================================================================
-- Migration 476: Enterprise Work Management Boards, Sprints, Dynamic Grouping,
--                and Advanced Filter Procedures
-- ============================================================================

-- 1. Ensure Multi-Board System Exists for Institute
INSERT INTO public.work_boards (id, school_id, name, code, board_type, is_active)
VALUES 
    ('31dacd93-15ee-4eed-8994-56973fd81245'::UUID, '11111111-1111-1111-1111-111111111111'::UUID, 'Institute Work Board', 'IWB', 'KANBAN', TRUE),
    ('a1111111-2222-3333-4444-555555555551'::UUID, '11111111-1111-1111-1111-111111111111'::UUID, 'Academic Board', 'ACB', 'KANBAN', TRUE),
    ('a1111111-2222-3333-4444-555555555552'::UUID, '11111111-1111-1111-1111-111111111111'::UUID, 'IT & Infra Board', 'ITB', 'KANBAN', TRUE)
ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name,
    code = EXCLUDED.code,
    is_active = TRUE;

-- 2. Associate items appropriately across boards
UPDATE public.work_items
SET board_id = 'a1111111-2222-3333-4444-555555555551'::UUID
WHERE school_id = '11111111-1111-1111-1111-111111111111'::UUID
  AND (
    category ILIKE '%Academic%' 
    OR category ILIKE '%Student%' 
    OR category ILIKE '%Exam%'
    OR work_type IN ('HOMEWORK', 'ASSIGNMENT')
  );

UPDATE public.work_items
SET board_id = 'a1111111-2222-3333-4444-555555555552'::UUID
WHERE school_id = '11111111-1111-1111-1111-111111111111'::UUID
  AND (
    category ILIKE '%IT%' 
    OR category ILIKE '%Facilit%' 
    OR category ILIKE '%Infra%'
    OR category ILIKE '%Tech%'
  );

-- 3. Stored Procedure: sp_list_board_kanban with dynamic multi-grouping and filter engine
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
BEGIN
    -- Resolve Board ID (by UUID or name)
    IF p_board_id IS NOT NULL AND p_board_id != '' AND LOWER(p_board_id) NOT IN ('default', 'all', 'institute work board') THEN
        BEGIN
            v_board_id := p_board_id::UUID;
        EXCEPTION WHEN OTHERS THEN
            IF p_board_id ILIKE '%Academic%' THEN
                v_board_id := 'a1111111-2222-3333-4444-555555555551'::UUID;
            ELSIF p_board_id ILIKE '%IT%' THEN
                v_board_id := 'a1111111-2222-3333-4444-555555555552'::UUID;
            ELSE
                SELECT id INTO v_board_id FROM public.work_boards
                WHERE school_id = p_school_id AND name ILIKE '%' || p_board_id || '%' LIMIT 1;
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

    -- Fetch Raw Items with pre-aggregated assignees
    WITH item_assignees AS (
        SELECT
            wia.work_item_id,
            jsonb_agg(
                jsonb_build_object(
                    'user_id', p.id,
                    'full_name', p.full_name,
                    'role', p.role,
                    'avatar_url', p.avatar_url
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
            -- Match condition by group mode
            CASE 
                WHEN v_group ILIKE '%Type%' THEN
                    UPPER(i.work_type) = col.status_key
                WHEN v_group ILIKE '%Priority%' THEN
                    (col.status_key = 'CRITICAL' AND UPPER(i.priority) IN ('CRITICAL', 'URGENT')) OR
                    (col.status_key = 'HIGH' AND UPPER(i.priority) = 'HIGH') OR
                    (col.status_key = 'MEDIUM' AND UPPER(i.priority) = 'MEDIUM') OR
                    (col.status_key = 'LOW' AND UPPER(i.priority) = 'LOW')
                ELSE -- Status (Default)
                    (col.status_key = 'NEW' AND UPPER(i.status) = 'NEW') OR
                    (col.status_key = 'ACTIVE' AND UPPER(i.status) IN ('ACTIVE', 'IN_PROGRESS')) OR
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

-- 4. Overloaded sp_reorder_kanban supporting flexible drag-and-drop across Status, Type, and Priority
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
    v_old_type VARCHAR;
    v_old_priority VARCHAR;
    v_actor_name VARCHAR := 'System';
    v_new_progress INT;
    v_target VARCHAR := UPPER(TRIM(p_new_status));
BEGIN
    SELECT status, work_type, priority INTO v_old_status, v_old_type, v_old_priority 
    FROM public.work_items 
    WHERE id = p_item_id AND school_id = p_school_id;

    IF v_old_status IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Item not found');
    END IF;

    IF p_actor_id IS NOT NULL THEN
        SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = p_actor_id;
        v_actor_name := COALESCE(v_actor_name, 'System');
    END IF;

    -- Check if target is a Work Type transition
    IF v_target IN ('STORY', 'TASK', 'BUG', 'EPIC', 'HOMEWORK', 'ASSIGNMENT') THEN
        UPDATE public.work_items
        SET work_type = v_target,
            rank = COALESCE(p_new_rank, rank),
            updated_at = NOW()
        WHERE id = p_item_id;

        INSERT INTO public.work_item_activity_logs (
            school_id, work_item_id, actor_id, actor_name, action_type, field_changed, old_value, new_value, description
        ) VALUES (
            p_school_id, p_item_id, p_actor_id, v_actor_name, 'TYPE_CHANGED', 'work_type', v_old_type, v_target,
            v_actor_name || ' changed work type from ' || v_old_type || ' to ' || v_target
        );

        RETURN jsonb_build_object('success', true, 'item_id', p_item_id, 'field', 'work_type', 'new_value', v_target);
    END IF;

    -- Check if target is a Priority transition
    IF v_target IN ('CRITICAL', 'URGENT', 'HIGH', 'MEDIUM', 'LOW') THEN
        UPDATE public.work_items
        SET priority = v_target,
            rank = COALESCE(p_new_rank, rank),
            updated_at = NOW()
        WHERE id = p_item_id;

        INSERT INTO public.work_item_activity_logs (
            school_id, work_item_id, actor_id, actor_name, action_type, field_changed, old_value, new_value, description
        ) VALUES (
            p_school_id, p_item_id, p_actor_id, v_actor_name, 'PRIORITY_CHANGED', 'priority', v_old_priority, v_target,
            v_actor_name || ' changed priority from ' || v_old_priority || ' to ' || v_target
        );

        RETURN jsonb_build_object('success', true, 'item_id', p_item_id, 'field', 'priority', 'new_value', v_target);
    END IF;

    -- Standard Status transition
    IF v_target = 'COMPLETED' THEN
        v_new_progress := 100;
    ELSIF v_target = 'RESOLVED' THEN
        v_new_progress := 100;
    ELSIF v_target = 'NEW' THEN
        v_new_progress := 0;
    ELSE
        v_new_progress := 50;
    END IF;

    UPDATE public.work_items
    SET status = v_target,
        rank = COALESCE(p_new_rank, rank),
        progress_percentage = CASE 
            WHEN v_target IN ('COMPLETED', 'RESOLVED') THEN 100 
            WHEN v_target = 'NEW' THEN 0 
            ELSE COALESCE(progress_percentage, 50) 
        END,
        completed_at = CASE WHEN v_target IN ('COMPLETED', 'RESOLVED') THEN NOW() ELSE NULL END,
        updated_at = NOW()
    WHERE id = p_item_id;

    IF UPPER(v_old_status) != v_target THEN
        INSERT INTO public.work_item_activity_logs (
            school_id, work_item_id, actor_id, actor_name, action_type, field_changed, old_value, new_value, description
        ) VALUES (
            p_school_id, p_item_id, p_actor_id, v_actor_name, 'STATUS_CHANGED', 'status', v_old_status, v_target,
            v_actor_name || ' moved item from ' || v_old_status || ' to ' || v_target
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'item_id', p_item_id,
        'old_status', v_old_status,
        'new_status', v_target,
        'progress_percentage', v_new_progress
    );
END;
$$;
