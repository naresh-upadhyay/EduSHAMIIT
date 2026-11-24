-- Migration 568: Fix Work Grids, KPIs, and Backlog Tree Multi-Board Visibility
-- Description:
-- 1. Updates sp_get_backlog_tree to return both 'stories' and 'items' keys, and ensures stories of selected epics
--    remain visible regardless of whether the child story board partition differs from the parent epic board.
-- 2. Updates sp_list_work_items_paged to return dynamic 'kpis' (total, new, active, resolved, completed, overdue)
--    and populates class_name and section_name.

-- 1. DROP and CREATE sp_get_backlog_tree
CREATE OR REPLACE FUNCTION public.sp_get_backlog_tree(
    p_school_id UUID,
    p_board_id UUID DEFAULT NULL,
    p_epic_id UUID DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_type TEXT DEFAULT 'All',
    p_assignee_id UUID DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
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
              AND (v_board_id IS NULL OR s.board_id = v_board_id OR EXISTS (SELECT 1 FROM public.work_items ep WHERE ep.id = s.parent_id AND ep.board_id = v_board_id))
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
            s_ac.name AS class_name,
            s.section_id,
            s_sec.name AS section_name,
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
                            'department', p.department,
                            'class_name', COALESCE(ac.name, p.class),
                            'section_name', sec.name,
                            'roll_number', COALESCE(sca.roll_number::VARCHAR, p.roll_number::TEXT, '')::VARCHAR
                        )
                    )
                    FROM public.work_item_assignees a
                    JOIN public.profiles p ON p.id = a.user_id
                    LEFT JOIN LATERAL (
                        SELECT sca_in.class_id, sca_in.section_id, sca_in.roll_number
                        FROM public.student_class_assignments sca_in
                        WHERE sca_in.student_id = p.id AND (sca_in.status = 'ACTIVE' OR sca_in.status IS NULL)
                        ORDER BY sca_in.assigned_at DESC NULLS LAST
                        LIMIT 1
                    ) sca ON TRUE
                    LEFT JOIN public.academic_classes ac ON ac.id = sca.class_id
                    LEFT JOIN public.academic_sections sec ON sec.id = sca.section_id
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
                            'class_id', tk.class_id,
                            'class_name', tk_ac.name,
                            'section_id', tk.section_id,
                            'section_name', tk_sec.name,
                            'assignees', COALESCE(
                                (
                                    SELECT jsonb_agg(
                                        jsonb_build_object(
                                            'user_id', tp.id,
                                            'full_name', tp.full_name,
                                            'avatar_url', tp.avatar_url,
                                            'role', tp.role,
                                            'department', tp.department,
                                            'class_name', COALESCE(tac.name, tp.class),
                                            'section_name', tsec.name,
                                            'roll_number', COALESCE(tsca.roll_number::VARCHAR, tp.roll_number::TEXT, '')::VARCHAR
                                        )
                                    )
                                    FROM public.work_item_assignees ta
                                    JOIN public.profiles tp ON tp.id = ta.user_id
                                    LEFT JOIN LATERAL (
                                        SELECT sca_in.class_id, sca_in.section_id, sca_in.roll_number
                                        FROM public.student_class_assignments sca_in
                                        WHERE sca_in.student_id = tp.id AND (sca_in.status = 'ACTIVE' OR sca_in.status IS NULL)
                                        ORDER BY sca_in.assigned_at DESC NULLS LAST
                                        LIMIT 1
                                    ) tsca ON TRUE
                                    LEFT JOIN public.academic_classes tac ON tac.id = tsca.class_id
                                    LEFT JOIN public.academic_sections tsec ON tsec.id = tsca.section_id
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
                    LEFT JOIN public.academic_classes tk_ac ON tk_ac.id = tk.class_id
                    LEFT JOIN public.academic_sections tk_sec ON tk_sec.id = tk.section_id
                    WHERE tk.parent_id = s.id AND tk.is_archived = FALSE
                ),
                '[]'::jsonb
            ) AS children
        FROM public.work_items s
        LEFT JOIN public.work_boards sb ON sb.id = s.board_id
        LEFT JOIN public.work_teams st ON st.id = s.team_id
        LEFT JOIN public.academic_classes s_ac ON s_ac.id = s.class_id
        LEFT JOIN public.academic_sections s_sec ON s_sec.id = s.section_id
        WHERE s.school_id = p_school_id
          AND s.work_type = 'STORY'
          AND s.parent_id = v_epic_id
          AND s.is_archived = FALSE
          AND (v_board_id IS NULL OR s.board_id = v_board_id OR EXISTS (SELECT 1 FROM public.work_items ep WHERE ep.id = s.parent_id AND ep.board_id = v_board_id))
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
        'items', v_stories,
        'total_items', v_total_items,
        'page', p_page,
        'page_size', p_page_size
    );
END;
$function$;

-- 2. CREATE OR REPLACE sp_list_work_items_paged with dynamic KPIs and enriched metadata
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
AS $function$
DECLARE
    v_board_id UUID := p_board_id;
    v_total INT := 0;
    v_items JSONB := '[]'::jsonb;
    v_offset INT;
    v_kpis JSONB;
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

    -- Select paged items with assignees aggregated and enriched academic metadata
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
            w_ac.name AS class_name,
            w.section_id,
            w_sec.name AS section_name,
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
                            'department', p.department,
                            'class_name', COALESCE(ac.name, p.class),
                            'section_name', sec.name,
                            'roll_number', COALESCE(sca.roll_number::VARCHAR, p.roll_number::TEXT, '')::VARCHAR
                        )
                    )
                    FROM public.work_item_assignees a
                    JOIN public.profiles p ON p.id = a.user_id
                    LEFT JOIN LATERAL (
                        SELECT sca_in.class_id, sca_in.section_id, sca_in.roll_number
                        FROM public.student_class_assignments sca_in
                        WHERE sca_in.student_id = p.id AND (sca_in.status = 'ACTIVE' OR sca_in.status IS NULL)
                        ORDER BY sca_in.assigned_at DESC NULLS LAST
                        LIMIT 1
                    ) sca ON TRUE
                    LEFT JOIN public.academic_classes ac ON ac.id = sca.class_id
                    LEFT JOIN public.academic_sections sec ON sec.id = sca.section_id
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
        LEFT JOIN public.academic_classes w_ac ON w_ac.id = w.class_id
        LEFT JOIN public.academic_sections w_sec ON w_sec.id = w.section_id
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

    -- Dynamic Live KPIs for the current board / scope
    SELECT jsonb_build_object(
        'total', (SELECT COUNT(*) FROM public.work_items WHERE school_id = p_school_id AND is_archived = FALSE AND work_type != 'EPIC' AND (v_board_id IS NULL OR board_id = v_board_id)),
        'new', (SELECT COUNT(*) FROM public.work_items WHERE school_id = p_school_id AND is_archived = FALSE AND work_type != 'EPIC' AND UPPER(status) = 'NEW' AND (v_board_id IS NULL OR board_id = v_board_id)),
        'active', (SELECT COUNT(*) FROM public.work_items WHERE school_id = p_school_id AND is_archived = FALSE AND work_type != 'EPIC' AND UPPER(status) IN ('ACTIVE', 'IN_PROGRESS') AND (v_board_id IS NULL OR board_id = v_board_id)),
        'resolved', (SELECT COUNT(*) FROM public.work_items WHERE school_id = p_school_id AND is_archived = FALSE AND work_type != 'EPIC' AND UPPER(status) = 'RESOLVED' AND (v_board_id IS NULL OR board_id = v_board_id)),
        'completed', (SELECT COUNT(*) FROM public.work_items WHERE school_id = p_school_id AND is_archived = FALSE AND work_type != 'EPIC' AND UPPER(status) = 'COMPLETED' AND (v_board_id IS NULL OR board_id = v_board_id)),
        'overdue', (SELECT COUNT(*) FROM public.work_items WHERE school_id = p_school_id AND is_archived = FALSE AND work_type != 'EPIC' AND due_date IS NOT NULL AND due_date < CURRENT_DATE AND UPPER(status) NOT IN ('COMPLETED', 'RESOLVED') AND (v_board_id IS NULL OR board_id = v_board_id))
    ) INTO v_kpis;

    RETURN jsonb_build_object(
        'total', v_total,
        'total_count', v_total,
        'page', p_page,
        'page_size', p_page_size,
        'kpis', v_kpis,
        'items', v_items
    );
END;
$function$;
