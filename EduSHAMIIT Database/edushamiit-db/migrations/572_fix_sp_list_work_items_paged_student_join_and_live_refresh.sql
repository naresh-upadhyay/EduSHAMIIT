-- ============================================================================
-- Migration 572: Fix sp_list_work_items_paged Student Join & Live Tab Data Visibility
-- ============================================================================

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
AS $$
DECLARE
    v_total_count INT := 0;
    v_offset INT := 0;
    v_items JSONB := '[]'::jsonb;
    v_kpis JSONB := '{}'::jsonb;
    v_clean_type VARCHAR := NULLIF(TRIM(p_type), '');
    v_clean_status VARCHAR := NULLIF(TRIM(p_status), '');
    v_clean_priority VARCHAR := NULLIF(TRIM(p_priority), '');
    v_clean_search VARCHAR := NULLIF(TRIM(p_search), '');
BEGIN
    v_offset := GREATEST(0, (COALESCE(p_page, 1) - 1) * COALESCE(p_page_size, 100));

    -- Total count & KPI counts
    SELECT
        COUNT(*),
        jsonb_build_object(
            'total', COUNT(*),
            'new', COUNT(*) FILTER (WHERE UPPER(w.status) = 'NEW'),
            'active', COUNT(*) FILTER (WHERE UPPER(w.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS')),
            'resolved', COUNT(*) FILTER (WHERE UPPER(w.status) = 'RESOLVED'),
            'completed', COUNT(*) FILTER (WHERE UPPER(w.status) = 'COMPLETED'),
            'overdue', COUNT(*) FILTER (WHERE w.due_date IS NOT NULL AND w.due_date < CURRENT_DATE AND UPPER(w.status) NOT IN ('COMPLETED', 'RESOLVED'))
        )
    INTO v_total_count, v_kpis
    FROM public.work_items w
    WHERE w.school_id = p_school_id
      AND w.is_archived = FALSE
      AND (p_board_id IS NULL OR w.board_id = p_board_id)
      AND (p_sprint_id IS NULL OR w.sprint_id = p_sprint_id)
      AND (v_clean_type IS NULL OR LOWER(v_clean_type) = 'all' OR UPPER(w.work_type) = UPPER(v_clean_type))
      AND (v_clean_status IS NULL OR LOWER(v_clean_status) = 'all' OR UPPER(w.status) = UPPER(v_clean_status))
      AND (v_clean_priority IS NULL OR LOWER(v_clean_priority) = 'all' OR UPPER(w.priority) = UPPER(v_clean_priority))
      AND (p_assignee_id IS NULL OR EXISTS (
          SELECT 1 FROM public.work_item_assignees a WHERE a.work_item_id = w.id AND a.user_id = p_assignee_id
      ))
      AND (v_clean_search IS NULL OR (w.title ILIKE '%' || v_clean_search || '%' OR w.item_number ILIKE '%' || v_clean_search || '%'));

    -- Fetch Paginated Items with resolved board, team, assignees
    SELECT COALESCE(jsonb_agg(item_obj), '[]'::jsonb) INTO v_items
    FROM (
        SELECT jsonb_build_object(
            'id', w.id,
            'item_number', w.item_number,
            'title', w.title,
            'description', w.description,
            'work_type', w.work_type,
            'status', w.status,
            'priority', w.priority,
            'category', w.category,
            'board_id', w.board_id,
            'board_name', COALESCE(b.name, 'Institute Work Board'),
            'team_id', w.team_id,
            'team_name', COALESCE(w.team_name, wt.name, 'No Team'),
            'sprint_id', w.sprint_id,
            'sprint_name', s.name,
            'parent_id', w.parent_id,
            'parent_number', p.item_number,
            'parent_title', p.title,
            'parent_type', p.work_type,
            'story_points', w.story_points,
            'estimated_hours', w.estimated_hours,
            'actual_hours', w.actual_hours,
            'remaining_hours', w.remaining_hours,
            'progress_percentage', w.progress_percentage,
            'start_date', w.start_date,
            'due_date', w.due_date,
            'is_overdue', (w.due_date IS NOT NULL AND w.due_date < CURRENT_DATE AND UPPER(w.status) NOT IN ('COMPLETED', 'RESOLVED')),
            'class_id', w.class_id,
            'section_id', w.section_id,
            'created_at', w.created_at,
            'updated_at', w.updated_at,
            'assignees', COALESCE((
                SELECT jsonb_agg(jsonb_build_object(
                    'user_id', pr.id,
                    'full_name', pr.full_name,
                    'role', pr.role,
                    'avatar_url', pr.avatar_url,
                    'department', pr.department,
                    'role_type', wia.role_type,
                    'class_name', cl.name,
                    'section_name', sec.name,
                    'roll_number', sca.roll_number
                ))
                FROM public.work_item_assignees wia
                JOIN public.profiles pr ON pr.id = wia.user_id
                LEFT JOIN LATERAL (
                    SELECT sca_in.class_id, sca_in.section_id, sca_in.roll_number
                    FROM public.student_class_assignments sca_in
                    WHERE sca_in.student_id = pr.id AND (sca_in.status = 'ACTIVE' OR sca_in.status IS NULL)
                    ORDER BY sca_in.assigned_at DESC NULLS LAST
                    LIMIT 1
                ) sca ON TRUE
                LEFT JOIN public.academic_classes cl ON cl.id = sca.class_id
                LEFT JOIN public.academic_sections sec ON sec.id = sca.section_id
                WHERE wia.work_item_id = w.id
            ), '[]'::jsonb),
            'comments_count', (SELECT COUNT(*) FROM public.work_item_comments c WHERE c.work_item_id = w.id)
        ) AS item_obj
        FROM public.work_items w
        LEFT JOIN public.work_boards b ON b.id = w.board_id
        LEFT JOIN public.work_teams wt ON wt.id = w.team_id
        LEFT JOIN public.work_sprints s ON s.id = w.sprint_id
        LEFT JOIN public.work_items p ON p.id = w.parent_id
        WHERE w.school_id = p_school_id
          AND w.is_archived = FALSE
          AND (p_board_id IS NULL OR w.board_id = p_board_id)
          AND (p_sprint_id IS NULL OR w.sprint_id = p_sprint_id)
          AND (v_clean_type IS NULL OR LOWER(v_clean_type) = 'all' OR UPPER(w.work_type) = UPPER(v_clean_type))
          AND (v_clean_status IS NULL OR LOWER(v_clean_status) = 'all' OR UPPER(w.status) = UPPER(v_clean_status))
          AND (v_clean_priority IS NULL OR LOWER(v_clean_priority) = 'all' OR UPPER(w.priority) = UPPER(v_clean_priority))
          AND (p_assignee_id IS NULL OR EXISTS (
              SELECT 1 FROM public.work_item_assignees a WHERE a.work_item_id = w.id AND a.user_id = p_assignee_id
          ))
          AND (v_clean_search IS NULL OR (w.title ILIKE '%' || v_clean_search || '%' OR w.item_number ILIKE '%' || v_clean_search || '%'))
        ORDER BY
            CASE WHEN LOWER(p_sort_col) = 'title' AND UPPER(p_sort_dir) = 'ASC' THEN w.title END ASC,
            CASE WHEN LOWER(p_sort_col) = 'title' AND UPPER(p_sort_dir) != 'ASC' THEN w.title END DESC,
            CASE WHEN LOWER(p_sort_col) = 'item_number' AND UPPER(p_sort_dir) = 'ASC' THEN w.item_number END ASC,
            CASE WHEN LOWER(p_sort_col) = 'item_number' AND UPPER(p_sort_dir) != 'ASC' THEN w.item_number END DESC,
            CASE WHEN LOWER(p_sort_col) = 'priority' AND UPPER(p_sort_dir) = 'ASC' THEN w.priority END ASC,
            CASE WHEN LOWER(p_sort_col) = 'priority' AND UPPER(p_sort_dir) != 'ASC' THEN w.priority END DESC,
            CASE WHEN LOWER(p_sort_col) = 'status' AND UPPER(p_sort_dir) = 'ASC' THEN w.status END ASC,
            CASE WHEN LOWER(p_sort_col) = 'status' AND UPPER(p_sort_dir) != 'ASC' THEN w.status END DESC,
            CASE WHEN LOWER(p_sort_col) = 'created_at' AND UPPER(p_sort_dir) = 'ASC' THEN w.created_at END ASC,
            w.created_at DESC
        LIMIT COALESCE(p_page_size, 100)
        OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'success', TRUE,
        'total', v_total_count,
        'page', COALESCE(p_page, 1),
        'page_size', COALESCE(p_page_size, 100),
        'kpis', v_kpis,
        'items', v_items
    );
END;
$$;
