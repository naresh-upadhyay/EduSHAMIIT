-- ============================================================================
-- Migration 577: Fix Sprint Duration Days & Exact Timeline Calculation
-- Ensures inclusive duration days (end_date - start_date + 1) are always returned
-- by sprint queries and stored procedures.
-- ============================================================================

-- 1. Create or replace public.sp_list_work_sprints function
CREATE OR REPLACE FUNCTION public.sp_list_work_sprints(
    p_school_id UUID,
    p_board_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s.id,
                'name', s.name,
                'sprint_number', s.sprint_number,
                'goal', s.goal,
                'status', s.status,
                'team_id', s.team_id,
                'team_name', COALESCE(s.team_name, t.name, 'All Teams'),
                'start_date_fmt', to_char(s.start_date, 'Mon DD, YYYY'),
                'end_date_fmt', to_char(s.end_date, 'Mon DD, YYYY'),
                'start_date', s.start_date,
                'end_date', s.end_date,
                'duration_days', COALESCE(GREATEST(1, (s.end_date - s.start_date + 1)), 14),
                'capacity_hours', s.capacity_hours,
                'total_points', s.total_points,
                'color', COALESCE(s.color, '#2563EB'),
                'total_items', COALESCE(items_stat.total_count, 0),
                'completed_items', COALESCE(items_stat.completed_count, 0)
            ) ORDER BY s.sprint_number ASC, s.start_date ASC
        ),
        '[]'::jsonb
    ) INTO v_result
    FROM public.work_sprints s
    LEFT JOIN public.work_teams t ON t.id = s.team_id
    LEFT JOIN LATERAL (
        SELECT 
            COUNT(DISTINCT w.id) AS total_count,
            COUNT(DISTINCT CASE WHEN UPPER(w.status) IN ('COMPLETED', 'RESOLVED', 'CLOSED', 'DONE') THEN w.id END) AS completed_count
        FROM public.work_items w
        WHERE w.sprint_id = s.id AND COALESCE(w.is_archived, FALSE) = FALSE
    ) items_stat ON TRUE
    WHERE s.school_id = p_school_id 
      AND COALESCE(s.is_archived, FALSE) = FALSE 
      AND (p_board_id IS NULL OR s.board_id = p_board_id);

    RETURN v_result;
END;
$$;
