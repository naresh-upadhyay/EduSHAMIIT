-- Migration 573: Fix sp_get_backlog_tree Epics Hierarchy Board Filtering and KPIs
-- Description:
-- 1. Drops any ambiguous overloaded signatures of sp_get_backlog_tree.
-- 2. Updates sp_get_backlog_tree so that when filtered by board:
--    - Epics KPI count accurately counts all epics that belong to the board or have stories/tasks on the board.
--    - Epics sidebar list (v_epics) only returns epics relevant to the board, with accurate items_count for that board.
--    - Total items under the selected epic (v_total_items) accurately counts items on that board.
--    - Dynamic KPIs accurately reflect the board partition without 0 epics discrepancy.

DROP FUNCTION IF EXISTS public.sp_get_backlog_tree(uuid, uuid, uuid, character varying, character varying, uuid, integer, integer);
DROP FUNCTION IF EXISTS public.sp_get_backlog_tree(uuid, uuid, uuid, text, text, uuid, integer, integer);

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
    -- If board_id specified, ensure selected epic belongs to or has items on this board
    IF v_epic_id IS NOT NULL AND v_board_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.work_items e
            WHERE e.id = v_epic_id AND e.school_id = p_school_id AND e.work_type = 'EPIC' AND e.is_archived = FALSE
              AND (e.board_id = v_board_id OR EXISTS (
                  SELECT 1 FROM public.work_items s
                  WHERE s.parent_id = e.id AND s.is_archived = FALSE
                    AND (s.board_id = v_board_id OR EXISTS (
                        SELECT 1 FROM public.work_items tk
                        WHERE tk.parent_id = s.id AND tk.board_id = v_board_id AND tk.is_archived = FALSE
                    ))
              ))
        ) THEN
            v_epic_id := NULL;
        END IF;
    END IF;

    -- Pick first Epic if none selected or invalid for board
    IF v_epic_id IS NULL THEN
        SELECT id INTO v_epic_id FROM public.work_items e
        WHERE e.school_id = p_school_id AND e.work_type = 'EPIC' AND e.is_archived = FALSE
          AND (v_board_id IS NULL OR e.board_id = v_board_id OR EXISTS (
              SELECT 1 FROM public.work_items s
              WHERE s.parent_id = e.id AND s.is_archived = FALSE
                AND (s.board_id = v_board_id OR EXISTS (
                    SELECT 1 FROM public.work_items tk
                    WHERE tk.parent_id = s.id AND tk.board_id = v_board_id AND tk.is_archived = FALSE
                ))
          ))
        ORDER BY e.rank ASC, e.item_number ASC LIMIT 1;
    END IF;

    -- Selected Epic details
    IF v_epic_id IS NOT NULL THEN
        SELECT id, item_number, title, description, category, priority, status
        INTO v_selected_epic_row
        FROM public.work_items
        WHERE id = v_epic_id;
    END IF;

    -- Epics list with dynamic count of stories + child tasks matching this board
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
                    LEFT JOIN public.work_items tk ON tk.parent_id = s.id AND tk.is_archived = FALSE AND (v_board_id IS NULL OR tk.board_id = v_board_id OR s.board_id = v_board_id)
                    WHERE s.parent_id = e.id AND s.work_type = 'STORY' AND s.is_archived = FALSE
                      AND (v_board_id IS NULL OR s.board_id = v_board_id OR EXISTS (SELECT 1 FROM public.work_items tk2 WHERE tk2.parent_id = s.id AND tk2.board_id = v_board_id AND tk2.is_archived = FALSE))
                ),
                0
            ) AS items_count
        FROM public.work_items e
        WHERE e.school_id = p_school_id
          AND e.work_type = 'EPIC'
          AND e.is_archived = FALSE
          AND (v_board_id IS NULL OR e.board_id = v_board_id OR EXISTS (
              SELECT 1 FROM public.work_items s
              WHERE s.parent_id = e.id AND s.is_archived = FALSE
                AND (s.board_id = v_board_id OR EXISTS (
                    SELECT 1 FROM public.work_items tk
                    WHERE tk.parent_id = s.id AND tk.board_id = v_board_id AND tk.is_archived = FALSE
                ))
          ))
        ORDER BY e.rank ASC, e.item_number ASC
    ) epic_item;

    -- Calculate total items under this selected epic on this board
    IF v_epic_id IS NOT NULL THEN
        SELECT COALESCE(
            (
                SELECT COUNT(DISTINCT s.id) + COUNT(DISTINCT tk.id)
                FROM public.work_items s
                LEFT JOIN public.work_items tk ON tk.parent_id = s.id AND tk.is_archived = FALSE AND (v_board_id IS NULL OR tk.board_id = v_board_id OR s.board_id = v_board_id)
                WHERE s.parent_id = v_epic_id AND s.work_type = 'STORY' AND s.is_archived = FALSE
                  AND (v_board_id IS NULL OR s.board_id = v_board_id OR EXISTS (SELECT 1 FROM public.work_items tk2 WHERE tk2.parent_id = s.id AND tk2.board_id = v_board_id AND tk2.is_archived = FALSE))
                  AND (p_search IS NULL OR p_search = '' OR s.title ILIKE '%' || p_search || '%' OR s.item_number ILIKE '%' || p_search || '%')
            ),
            0
        ) INTO v_total_items;
    ELSE
        v_total_items := 0;
    END IF;

    -- Stories and their children under the selected Epic on this board
    IF v_epic_id IS NOT NULL THEN
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
                                'class_id', tk.class_id,
                                'class_name', tk_ac.name,
                                'section_id', tk.section_id,
                                'section_name', tk_sec.name,
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
                                                'department', tp.department,
                                                'class_name', COALESCE(tac.name, tp.class),
                                                'section_name', tsec.name,
                                                'roll_number', COALESCE(tsca.roll_number::VARCHAR, tp.roll_number::TEXT, '')::VARCHAR
                                            )
                                        )
                                        FROM public.work_item_assignees ta
                                        JOIN public.profiles tp ON tp.id = ta.user_id
                                        LEFT JOIN LATERAL (
                                            SELECT tsca_in.class_id, tsca_in.section_id, tsca_in.roll_number
                                            FROM public.student_class_assignments tsca_in
                                            WHERE tsca_in.student_id = tp.id AND (tsca_in.status = 'ACTIVE' OR tsca_in.status IS NULL)
                                            ORDER BY tsca_in.assigned_at DESC NULLS LAST
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
                          AND (v_board_id IS NULL OR tk.board_id = v_board_id OR s.board_id = v_board_id)
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
              AND (v_board_id IS NULL OR s.board_id = v_board_id OR EXISTS (SELECT 1 FROM public.work_items tk WHERE tk.parent_id = s.id AND tk.board_id = v_board_id AND tk.is_archived = FALSE))
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
    ELSE
        v_stories := '[]'::jsonb;
    END IF;

    -- Dynamic Mockup-Aligned Backlog KPIs from live DB
    SELECT jsonb_build_object(
        'total_backlog', (
            SELECT COUNT(*) FROM public.work_items
            WHERE school_id = p_school_id AND is_archived = FALSE
              AND (v_board_id IS NULL OR board_id = v_board_id)
        ),
        'epics', (
            SELECT COUNT(*) FROM public.work_items e
            WHERE e.school_id = p_school_id AND e.work_type = 'EPIC' AND e.is_archived = FALSE
              AND (v_board_id IS NULL OR e.board_id = v_board_id OR EXISTS (
                  SELECT 1 FROM public.work_items s
                  WHERE s.parent_id = e.id AND s.is_archived = FALSE
                    AND (s.board_id = v_board_id OR EXISTS (
                        SELECT 1 FROM public.work_items tk
                        WHERE tk.parent_id = s.id AND tk.board_id = v_board_id AND tk.is_archived = FALSE
                    ))
              ))
        ),
        'stories', (
            SELECT COUNT(*) FROM public.work_items
            WHERE school_id = p_school_id AND work_type = 'STORY' AND is_archived = FALSE
              AND (v_board_id IS NULL OR board_id = v_board_id)
        ),
        'tasks', (
            SELECT COUNT(*) FROM public.work_items
            WHERE school_id = p_school_id AND work_type = 'TASK' AND is_archived = FALSE
              AND (v_board_id IS NULL OR board_id = v_board_id)
        ),
        'bugs', (
            SELECT COUNT(*) FROM public.work_items
            WHERE school_id = p_school_id AND work_type = 'BUG' AND is_archived = FALSE
              AND (v_board_id IS NULL OR board_id = v_board_id)
        ),
        'issues', (
            SELECT COUNT(*) FROM public.work_items
            WHERE school_id = p_school_id AND work_type = 'ISSUE' AND is_archived = FALSE
              AND (v_board_id IS NULL OR board_id = v_board_id)
        )
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
$function$;
