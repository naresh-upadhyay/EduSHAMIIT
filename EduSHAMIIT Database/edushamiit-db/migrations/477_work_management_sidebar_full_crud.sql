-- ============================================================================
-- Migration 477: Work Management Sidebar Full CRUD Stored Procedures
-- Supports Assignee updates, Checklist CRUD, Attachment upload/delete,
-- Inline Field Edits (Title, Description, Dates, Labels, Priority), and Archive
-- ============================================================================

-- 1. Enhance sp_get_work_item_detail to include formatted file sizes on attachments
CREATE OR REPLACE FUNCTION public.sp_get_work_item_detail(p_item_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
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
                'id', p.id,
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
                'file_size_fmt', CASE
                    WHEN a.file_size_bytes >= 1048576 THEN ROUND(a.file_size_bytes::numeric / 1048576.0, 1)::text || ' MB'
                    WHEN a.file_size_bytes >= 1024 THEN ROUND(a.file_size_bytes::numeric / 1024.0, 1)::text || ' KB'
                    ELSE COALESCE(a.file_size_bytes, 0)::text || ' B'
                END,
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

    -- Activity Logs
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

    -- Children
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

    -- Labels
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
$function$;


-- 2. Enhance sp_update_work_item_azure with safe casts and audit logging
CREATE OR REPLACE FUNCTION public.sp_update_work_item_azure(
    p_school_id uuid,
    p_item_id uuid,
    p_actor_id uuid DEFAULT NULL::uuid,
    p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
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
    v_assignee_id TEXT;
    v_label_str TEXT;
    v_assignee_names TEXT;
BEGIN
    SELECT * INTO v_old FROM public.work_items WHERE id = p_item_id AND school_id = p_school_id;
    IF v_old.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Work item not found');
    END IF;

    IF p_actor_id IS NOT NULL THEN
        SELECT full_name INTO v_actor_name FROM public.profiles WHERE id = p_actor_id;
        v_actor_name := COALESCE(v_actor_name, 'System');
    END IF;

    v_title := COALESCE(NULLIF(BTRIM(p_payload->>'title'), ''), v_old.title);
    IF p_payload ? 'description' THEN
        v_desc := COALESCE(p_payload->>'description', '');
    ELSE
        v_desc := v_old.description;
    END IF;
    v_status := UPPER(COALESCE(NULLIF(p_payload->>'status', ''), v_old.status));
    v_priority := UPPER(COALESCE(NULLIF(p_payload->>'priority', ''), v_old.priority));
    v_category := COALESCE(NULLIF(p_payload->>'category', ''), v_old.category);
    v_work_type := UPPER(COALESCE(NULLIF(p_payload->>'work_type', ''), v_old.work_type));

    IF p_payload ? 'board_id' THEN
        v_board_id := COALESCE(NULLIF(p_payload->>'board_id', '')::UUID, v_old.board_id);
    ELSE
        v_board_id := v_old.board_id;
    END IF;

    IF p_payload ? 'sprint_id' THEN
        v_sprint_id := NULLIF(p_payload->>'sprint_id', '')::UUID;
    ELSE
        v_sprint_id := v_old.sprint_id;
    END IF;

    IF p_payload ? 'parent_id' THEN
        v_parent_id := NULLIF(p_payload->>'parent_id', '')::UUID;
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
    ELSIF v_estimated_hours > 0 AND v_remaining_hours > 0 THEN
        v_progress := ROUND(((v_estimated_hours - v_remaining_hours) / v_estimated_hours) * 100);
    ELSE
        v_progress := COALESCE((p_payload->>'progress_percentage')::INT, v_old.progress_percentage, 0);
    END IF;
    v_progress := LEAST(GREATEST(v_progress, 0), 100);

    IF p_payload ? 'due_date' THEN
        v_due_date := NULLIF(p_payload->>'due_date', '')::DATE;
    ELSE
        v_due_date := v_old.due_date;
    END IF;

    IF p_payload ? 'start_date' THEN
        v_start_date := NULLIF(p_payload->>'start_date', '')::DATE;
    ELSE
        v_start_date := v_old.start_date;
    END IF;

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

    -- Audit Logs
    IF UPPER(v_old.status) != v_status THEN
        INSERT INTO public.work_item_activity_logs (
            work_item_id, school_id, actor_id, action_type, field_name, old_value, new_value, message
        ) VALUES (
            p_item_id, p_school_id, p_actor_id, 'STATUS_CHANGE', 'status', v_old.status, v_status,
            v_actor_name || ' changed status from ' || v_old.status || ' to ' || v_status
        );
    END IF;

    IF UPPER(v_old.priority) != v_priority THEN
        INSERT INTO public.work_item_activity_logs (
            work_item_id, school_id, actor_id, action_type, field_name, old_value, new_value, message
        ) VALUES (
            p_item_id, p_school_id, p_actor_id, 'PRIORITY_CHANGE', 'priority', v_old.priority, v_priority,
            v_actor_name || ' changed priority from ' || v_old.priority || ' to ' || v_priority
        );
    END IF;

    IF v_old.title IS DISTINCT FROM v_title THEN
        INSERT INTO public.work_item_activity_logs (
            work_item_id, school_id, actor_id, action_type, field_name, old_value, new_value, message
        ) VALUES (
            p_item_id, p_school_id, p_actor_id, 'FIELD_UPDATE', 'title', v_old.title, v_title,
            v_actor_name || ' updated title'
        );
    END IF;

    IF v_old.description IS DISTINCT FROM v_desc AND p_payload ? 'description' THEN
        INSERT INTO public.work_item_activity_logs (
            work_item_id, school_id, actor_id, action_type, field_name, message
        ) VALUES (
            p_item_id, p_school_id, p_actor_id, 'FIELD_UPDATE', 'description',
            v_actor_name || ' updated description'
        );
    END IF;

    IF v_old.sprint_id IS DISTINCT FROM v_sprint_id THEN
        INSERT INTO public.work_item_activity_logs (
            work_item_id, school_id, actor_id, action_type, field_name, message
        ) VALUES (
            p_item_id, p_school_id, p_actor_id, 'MOVED_SPRINT', 'sprint_id',
            v_actor_name || ' moved item to ' || COALESCE((SELECT name FROM public.work_sprints WHERE id = v_sprint_id), 'Backlog')
        );
    END IF;

    IF v_old.board_id IS DISTINCT FROM v_board_id THEN
        INSERT INTO public.work_item_activity_logs (
            work_item_id, school_id, actor_id, action_type, field_name, message
        ) VALUES (
            p_item_id, p_school_id, p_actor_id, 'MOVED_BOARD', 'board_id',
            v_actor_name || ' moved item to board ' || COALESCE((SELECT name FROM public.work_boards WHERE id = v_board_id), 'Default')
        );
    END IF;

    -- Update Assignees if array provided
    IF p_payload ? 'assignee_ids' AND jsonb_typeof(p_payload->'assignee_ids') = 'array' THEN
        DELETE FROM public.work_item_assignees WHERE work_item_id = p_item_id;
        FOR v_assignee_id IN SELECT jsonb_array_elements_text(p_payload->'assignee_ids') LOOP
            IF v_assignee_id IS NOT NULL AND BTRIM(v_assignee_id) != '' THEN
                INSERT INTO public.work_item_assignees (id, work_item_id, user_id, role_type)
                VALUES (uuid_generate_v4(), p_item_id, v_assignee_id::UUID, 'PRIMARY')
                ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;

        SELECT STRING_AGG(p.full_name, ', ' ORDER BY a.assigned_at ASC)
        INTO v_assignee_names
        FROM public.work_item_assignees a
        JOIN public.profiles p ON p.id = a.user_id
        WHERE a.work_item_id = p_item_id;

        INSERT INTO public.work_item_activity_logs (
            work_item_id, school_id, actor_id, action_type, field_name, new_value, message
        ) VALUES (
            p_item_id, p_school_id, p_actor_id, 'ASSIGNEE_CHANGE', 'assignee_ids',
            COALESCE(v_assignee_names, 'Unassigned'),
            v_actor_name || ' updated assignees to ' || COALESCE(v_assignee_names, 'Unassigned')
        );
    END IF;

    -- Update Labels if array provided
    IF p_payload ? 'labels' AND jsonb_typeof(p_payload->'labels') = 'array' THEN
        DELETE FROM public.work_item_labels WHERE work_item_id = p_item_id;
        FOR v_label_str IN SELECT jsonb_array_elements_text(p_payload->'labels') LOOP
            IF v_label_str IS NOT NULL AND BTRIM(v_label_str) != '' THEN
                INSERT INTO public.work_item_labels (id, work_item_id, label)
                VALUES (uuid_generate_v4(), p_item_id, BTRIM(v_label_str))
                ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;
    END IF;

    RETURN public.sp_get_work_item_detail(p_item_id);
END;
$function$;


-- 3. Checklist CRUD Stored Procedures
CREATE OR REPLACE FUNCTION public.sp_add_checklist_entry(
    p_school_id uuid,
    p_item_id uuid,
    p_title character varying,
    p_actor_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_item_school uuid;
    v_next_order int;
    v_new_id uuid;
    v_actor_name varchar := 'User';
    v_total int;
    v_completed int;
    v_new_progress int;
BEGIN
    SELECT school_id INTO v_item_school FROM public.work_items WHERE id = p_item_id;
    IF v_item_school IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Work item not found');
    END IF;

    IF BTRIM(COALESCE(p_title, '')) = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Checklist title cannot be empty');
    END IF;

    IF p_actor_id IS NOT NULL THEN
        SELECT COALESCE(full_name, 'User') INTO v_actor_name FROM public.profiles WHERE id = p_actor_id;
    END IF;

    SELECT COALESCE(MAX(sort_order), 0) + 1 INTO v_next_order
    FROM public.work_item_checklists
    WHERE work_item_id = p_item_id;

    v_new_id := uuid_generate_v4();
    INSERT INTO public.work_item_checklists (id, work_item_id, title, is_completed, sort_order, created_at)
    VALUES (v_new_id, p_item_id, BTRIM(p_title), FALSE, v_next_order, NOW());

    SELECT COUNT(*), COUNT(*) FILTER (WHERE is_completed = TRUE)
    INTO v_total, v_completed
    FROM public.work_item_checklists
    WHERE work_item_id = p_item_id;

    v_new_progress := ROUND((v_completed::numeric / GREATEST(v_total, 1)::numeric) * 100);
    UPDATE public.work_items SET progress_percentage = v_new_progress, updated_at = NOW()
    WHERE id = p_item_id AND status NOT IN ('COMPLETED', 'RESOLVED');

    INSERT INTO public.work_item_activity_logs (
        work_item_id, school_id, actor_id, action_type, field_name, new_value, message
    ) VALUES (
        p_item_id, COALESCE(p_school_id, v_item_school), p_actor_id, 'CHECKLIST_ADDED', 'checklists', BTRIM(p_title),
        v_actor_name || ' added checklist item: "' || BTRIM(p_title) || '"'
    );

    RETURN jsonb_build_object(
        'success', true,
        'entry', jsonb_build_object(
            'id', v_new_id,
            'work_item_id', p_item_id,
            'title', BTRIM(p_title),
            'is_completed', FALSE,
            'sort_order', v_next_order
        ),
        'completed_count', v_completed,
        'total_count', v_total,
        'progress_percentage', v_new_progress
    );
END;
$function$;


CREATE OR REPLACE FUNCTION public.sp_update_checklist_entry(
    p_checklist_id uuid,
    p_title character varying DEFAULT NULL::character varying,
    p_is_completed boolean DEFAULT NULL::boolean,
    p_actor_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_work_item_id uuid;
    v_total int;
    v_completed int;
    v_new_progress int;
BEGIN
    UPDATE public.work_item_checklists
    SET title = COALESCE(NULLIF(BTRIM(p_title), ''), title),
        is_completed = COALESCE(p_is_completed, is_completed),
        completed_at = CASE
            WHEN p_is_completed IS TRUE THEN NOW()
            WHEN p_is_completed IS FALSE THEN NULL
            ELSE completed_at
        END
    WHERE id = p_checklist_id
    RETURNING work_item_id INTO v_work_item_id;

    IF v_work_item_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Checklist entry not found');
    END IF;

    SELECT COUNT(*), COUNT(*) FILTER (WHERE is_completed = TRUE)
    INTO v_total, v_completed
    FROM public.work_item_checklists
    WHERE work_item_id = v_work_item_id;

    v_new_progress := ROUND((v_completed::numeric / GREATEST(v_total, 1)::numeric) * 100);
    UPDATE public.work_items SET progress_percentage = v_new_progress, updated_at = NOW()
    WHERE id = v_work_item_id AND status NOT IN ('COMPLETED', 'RESOLVED');

    RETURN jsonb_build_object(
        'success', true,
        'work_item_id', v_work_item_id,
        'completed_count', v_completed,
        'total_count', v_total,
        'progress_percentage', v_new_progress
    );
END;
$function$;


CREATE OR REPLACE FUNCTION public.sp_delete_checklist_entry(
    p_checklist_id uuid,
    p_actor_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_row RECORD;
    v_item_school uuid;
    v_actor_name varchar := 'User';
    v_total int;
    v_completed int;
    v_new_progress int;
BEGIN
    DELETE FROM public.work_item_checklists
    WHERE id = p_checklist_id
    RETURNING * INTO v_row;

    IF v_row.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Checklist entry not found');
    END IF;

    SELECT school_id INTO v_item_school FROM public.work_items WHERE id = v_row.work_item_id;
    IF p_actor_id IS NOT NULL THEN
        SELECT COALESCE(full_name, 'User') INTO v_actor_name FROM public.profiles WHERE id = p_actor_id;
    END IF;

    SELECT COUNT(*), COUNT(*) FILTER (WHERE is_completed = TRUE)
    INTO v_total, v_completed
    FROM public.work_item_checklists
    WHERE work_item_id = v_row.work_item_id;

    v_new_progress := CASE WHEN v_total > 0 THEN ROUND((v_completed::numeric / v_total::numeric) * 100) ELSE 0 END;
    UPDATE public.work_items SET progress_percentage = v_new_progress, updated_at = NOW()
    WHERE id = v_row.work_item_id AND status NOT IN ('COMPLETED', 'RESOLVED');

    INSERT INTO public.work_item_activity_logs (
        work_item_id, school_id, actor_id, action_type, field_name, old_value, message
    ) VALUES (
        v_row.work_item_id, v_item_school, p_actor_id, 'CHECKLIST_REMOVED', 'checklists', v_row.title,
        v_actor_name || ' removed checklist item: "' || v_row.title || '"'
    );

    RETURN jsonb_build_object(
        'success', true,
        'work_item_id', v_row.work_item_id,
        'completed_count', v_completed,
        'total_count', v_total,
        'progress_percentage', v_new_progress
    );
END;
$function$;


-- 4. Attachment Stored Procedures
CREATE OR REPLACE FUNCTION public.sp_add_work_item_attachment(
    p_school_id uuid,
    p_item_id uuid,
    p_file_name character varying,
    p_file_url text,
    p_file_size_bytes bigint DEFAULT 0,
    p_file_type character varying DEFAULT 'document'::character varying,
    p_uploaded_by uuid DEFAULT NULL::uuid,
    p_attachment_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_att_id uuid;
    v_item_school uuid;
    v_actor_name varchar := 'User';
BEGIN
    SELECT school_id INTO v_item_school FROM public.work_items WHERE id = p_item_id;
    IF v_item_school IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Work item not found');
    END IF;

    v_att_id := COALESCE(p_attachment_id, uuid_generate_v4());

    INSERT INTO public.work_item_attachments (
        id, work_item_id, file_name, file_url, file_size_bytes, file_type, uploaded_by, created_at
    ) VALUES (
        v_att_id, p_item_id, p_file_name, p_file_url, COALESCE(p_file_size_bytes, 0),
        COALESCE(NULLIF(p_file_type, ''), 'document'), p_uploaded_by, NOW()
    );

    IF p_uploaded_by IS NOT NULL THEN
        SELECT COALESCE(full_name, 'User') INTO v_actor_name FROM public.profiles WHERE id = p_uploaded_by;
    END IF;

    INSERT INTO public.work_item_activity_logs (
        work_item_id, school_id, actor_id, action_type, field_name, new_value, message
    ) VALUES (
        p_item_id, COALESCE(p_school_id, v_item_school), p_uploaded_by, 'ATTACHMENT_ADDED', 'attachments', p_file_name,
        v_actor_name || ' attached ' || p_file_name
    );

    RETURN jsonb_build_object(
        'success', true,
        'attachment_id', v_att_id,
        'file_name', p_file_name,
        'file_url', p_file_url,
        'file_size_bytes', COALESCE(p_file_size_bytes, 0)
    );
END;
$function$;


CREATE OR REPLACE FUNCTION public.sp_delete_work_item_attachment(
    p_attachment_id uuid,
    p_actor_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_row RECORD;
    v_item_school uuid;
    v_actor_name varchar := 'User';
BEGIN
    DELETE FROM public.work_item_attachments
    WHERE id = p_attachment_id
    RETURNING * INTO v_row;

    IF v_row.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Attachment not found');
    END IF;

    SELECT school_id INTO v_item_school FROM public.work_items WHERE id = v_row.work_item_id;
    IF p_actor_id IS NOT NULL THEN
        SELECT COALESCE(full_name, 'User') INTO v_actor_name FROM public.profiles WHERE id = p_actor_id;
    END IF;

    INSERT INTO public.work_item_activity_logs (
        work_item_id, school_id, actor_id, action_type, field_name, old_value, message
    ) VALUES (
        v_row.work_item_id, v_item_school, p_actor_id, 'ATTACHMENT_REMOVED', 'attachments', v_row.file_name,
        v_actor_name || ' removed attachment ' || v_row.file_name
    );

    RETURN jsonb_build_object(
        'success', true,
        'attachment_id', v_row.id,
        'work_item_id', v_row.work_item_id,
        'file_name', v_row.file_name,
        'file_url', v_row.file_url
    );
END;
$function$;


CREATE OR REPLACE FUNCTION public.sp_get_work_item_attachment(p_attachment_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_row RECORD;
BEGIN
    SELECT a.*, w.school_id
    INTO v_row
    FROM public.work_item_attachments a
    JOIN public.work_items w ON w.id = a.work_item_id
    WHERE a.id = p_attachment_id;

    IF v_row.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Attachment not found');
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'id', v_row.id,
        'work_item_id', v_row.work_item_id,
        'school_id', v_row.school_id,
        'file_name', v_row.file_name,
        'file_url', v_row.file_url,
        'file_size_bytes', v_row.file_size_bytes,
        'file_type', v_row.file_type
    );
END;
$function$;


-- 5. Archive / Soft Delete Work Item Stored Procedure
CREATE OR REPLACE FUNCTION public.sp_delete_work_item(
    p_school_id uuid,
    p_item_id uuid,
    p_actor_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_row RECORD;
    v_actor_name varchar := 'User';
BEGIN
    UPDATE public.work_items
    SET is_archived = TRUE,
        updated_at = NOW(),
        updated_by = p_actor_id
    WHERE id = p_item_id AND school_id = p_school_id
    RETURNING id, item_number, title INTO v_row;

    IF v_row.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Work item not found');
    END IF;

    IF p_actor_id IS NOT NULL THEN
        SELECT COALESCE(full_name, 'User') INTO v_actor_name FROM public.profiles WHERE id = p_actor_id;
    END IF;

    INSERT INTO public.work_item_activity_logs (
        work_item_id, school_id, actor_id, action_type, message
    ) VALUES (
        v_row.id, p_school_id, p_actor_id, 'ARCHIVED',
        v_actor_name || ' deleted/archived work item ' || v_row.item_number
    );

    RETURN jsonb_build_object(
        'success', true,
        'item_id', v_row.id,
        'item_number', v_row.item_number
    );
END;
$function$;
