-- Migration 503: Dynamic Backlog Tree and KPIs Procedure
-- Ensures left sidebar epic counts match center grid counts exactly,
-- resolves epics dynamically, and calculates live KPIs for Work Management Backlog.

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
    IF v_board_id IS NULL THEN
        SELECT id INTO v_board_id FROM public.work_boards
        WHERE school_id = p_school_id AND is_active = TRUE
        ORDER BY created_at ASC LIMIT 1;
    END IF;

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
                            'role', p.role
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
                            'estimate_hours', COALESCE(tk.estimated_hours, 8.0),
                            'rank', tk.rank,
                            'assignees', COALESCE(
                                (
                                    SELECT jsonb_agg(
                                        jsonb_build_object(
                                            'user_id', tp.id,
                                            'full_name', tp.full_name,
                                            'avatar_url', tp.avatar_url,
                                            'role', tp.role
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
                    WHERE tk.parent_id = s.id AND tk.is_archived = FALSE
                ),
                '[]'::jsonb
            ) AS children
        FROM public.work_items s
        WHERE s.school_id = p_school_id
          AND s.work_type = 'STORY'
          AND s.parent_id = v_epic_id
          AND s.is_archived = FALSE
          AND (p_search IS NULL OR p_search = '' OR s.title ILIKE '%' || p_search || '%' OR s.item_number ILIKE '%' || p_search || '%')
        ORDER BY s.rank ASC, s.item_number ASC
        LIMIT p_page_size
        OFFSET (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1)
    ) story_item;

    -- Calculate dynamic KPIs
    SELECT jsonb_build_object(
        'total_backlog', (SELECT COUNT(*) FROM public.work_items WHERE school_id = p_school_id AND is_archived = FALSE),
        'epics', (SELECT COUNT(*) FROM public.work_items WHERE school_id = p_school_id AND work_type = 'EPIC' AND is_archived = FALSE),
        'stories', (SELECT COUNT(*) FROM public.work_items WHERE school_id = p_school_id AND work_type = 'STORY' AND is_archived = FALSE),
        'tasks', (SELECT COUNT(*) FROM public.work_items WHERE school_id = p_school_id AND work_type = 'TASK' AND is_archived = FALSE),
        'bugs', (SELECT COUNT(*) FROM public.work_items WHERE school_id = p_school_id AND work_type = 'BUG' AND is_archived = FALSE),
        'issues', (SELECT COUNT(*) FROM public.work_items WHERE school_id = p_school_id AND (work_type IN ('ISSUE', 'INCIDENT') OR parent_id IS NULL) AND is_archived = FALSE)
    ) INTO v_kpis;

    RETURN jsonb_build_object(
        'kpis', v_kpis,
        'epics', v_epics,
        'selected_epic', jsonb_build_object(
            'id', v_selected_epic_row.id,
            'item_number', COALESCE(v_selected_epic_row.item_number, 'EP-001'),
            'title', COALESCE(v_selected_epic_row.title, 'Campus Digitalization'),
            'description', COALESCE(v_selected_epic_row.description, ''),
            'total_items', v_total_items
        ),
        'total_items', v_total_items,
        'page', p_page,
        'page_size', p_page_size,
        'items', v_stories
    );
END;
$$;
