-- ============================================================================
-- Migration 585: Strictly Exclude Archived and Deleted Teams Everywhere
-- Single Source of Truth: All dropdowns, filters, retrospectives, capacity dashboards,
-- directory views and item tagging must NEVER display or include archived/deleted teams.
-- ============================================================================

-- 1. Update sp_get_sprint_retrospective_workspace
CREATE OR REPLACE FUNCTION public.sp_get_sprint_retrospective_workspace(
    p_school_id UUID,
    p_sprint_id UUID,
    p_team_id UUID DEFAULT NULL,
    p_user_id UUID DEFAULT NULL,
    p_team_name VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sprint RECORD;
    v_retro RECORD;
    v_facilitator RECORD;
    v_clean_team VARCHAR(100) := NULL;
    v_filter_team_id UUID := NULL;
    v_total_work_items INT := 0;
    v_completed_work_items INT := 0;
    v_completion_pct INT := 0;
    v_total_participants INT := 0;
    v_attended_participants INT := 0;
    v_went_well_json JSONB := '[]'::jsonb;
    v_went_poorly_json JSONB := '[]'::jsonb;
    v_to_improve_json JSONB := '[]'::jsonb;
    v_action_items_json JSONB := '[]'::jsonb;
    v_participants_json JSONB := '[]'::jsonb;
    v_history_json JSONB := '[]'::jsonb;
    v_feedback_json JSONB := '[]'::jsonb;
    v_feedback_stats JSONB := '{}'::jsonb;
    v_available_teams_json JSONB := '[]'::jsonb;
    v_available_sprints_json JSONB := '[]'::jsonb;
    v_res JSONB;
BEGIN
    -- 1. Resolve Target Sprint
    SELECT * INTO v_sprint
    FROM public.work_sprints
    WHERE id = p_sprint_id AND school_id = p_school_id;

    IF v_sprint.id IS NULL THEN
        SELECT * INTO v_sprint
        FROM public.work_sprints
        WHERE school_id = p_school_id
        ORDER BY created_at DESC LIMIT 1;
    END IF;

    IF v_sprint.id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'No sprints found for this school.'
        );
    END IF;

    -- 2. Resolve Retrospective Master Record
    SELECT * INTO v_retro
    FROM public.sprint_retrospectives
    WHERE sprint_id = v_sprint.id;

    IF v_retro.id IS NULL THEN
        INSERT INTO public.sprint_retrospectives (
            school_id, sprint_id, title, status, session_date, duration_minutes,
            sprint_goal, summary
        ) VALUES (
            p_school_id, v_sprint.id, 'Sprint Retrospective', 'COMPLETED',
            NOW(), 60, COALESCE(v_sprint.goal, 'Sprint Goal'),
            'Retrospective session initialized.'
        ) RETURNING * INTO v_retro;
    END IF;

    -- 3. Resolve Team Filter (STRICT: Exclude archived / deleted teams)
    IF p_team_name IS NOT NULL AND LOWER(TRIM(p_team_name)) NOT IN ('all', 'all teams', '') THEN
        SELECT id, name INTO v_filter_team_id, v_clean_team
        FROM public.work_teams
        WHERE school_id = p_school_id
          AND LOWER(TRIM(name)) = LOWER(TRIM(p_team_name))
          AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
          AND COALESCE(is_active, TRUE) = TRUE
        LIMIT 1;
    ELSIF p_team_id IS NOT NULL THEN
        SELECT id, name INTO v_filter_team_id, v_clean_team
        FROM public.work_teams
        WHERE id = p_team_id
          AND school_id = p_school_id
          AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
          AND COALESCE(is_active, TRUE) = TRUE
        LIMIT 1;
    END IF;

    -- 4. Authoritative Available Teams (STRICT: Exclude archived / deleted teams)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', wt.id,
            'name', wt.name,
            'department', wt.department,
            'team_key', wt.team_key,
            'icon', COALESCE(wt.icon, 'groups'),
            'status', UPPER(COALESCE(wt.status, 'ACTIVE')),
            'is_active', COALESCE(wt.is_active, TRUE),
            'lead_name', (
                SELECT p.full_name FROM public.work_team_members wtm 
                JOIN public.profiles p ON p.id = wtm.user_id 
                WHERE wtm.team_id = wt.id AND wtm.is_lead = TRUE 
                LIMIT 1
            ),
            'members_count', (SELECT COUNT(*) FROM public.work_team_members wtm WHERE wtm.team_id = wt.id),
            'is_selected', (v_filter_team_id IS NOT NULL AND wt.id = v_filter_team_id)
        ) ORDER BY wt.name ASC
    ), '[]'::jsonb) INTO v_available_teams_json
    FROM public.work_teams wt
    WHERE wt.school_id = p_school_id
      AND COALESCE(wt.status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
      AND COALESCE(wt.is_active, TRUE) = TRUE;

    -- Available Sprints
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', id,
            'name', name,
            'status', UPPER(status),
            'start_date', to_char(start_date, 'YYYY-MM-DD'),
            'end_date', to_char(end_date, 'YYYY-MM-DD')
        ) ORDER BY start_date DESC
    ), '[]'::jsonb) INTO v_available_sprints_json
    FROM public.work_sprints
    WHERE school_id = p_school_id;

    -- 5. Facilitator
    SELECT * INTO v_facilitator
    FROM public.profiles
    WHERE id = v_retro.facilitator_id;

    IF v_facilitator.id IS NULL THEN
        SELECT * INTO v_facilitator
        FROM public.profiles
        WHERE role = 'super_admin' AND school_id = p_school_id
        LIMIT 1;
    END IF;

    -- 6. Sprint Completion Metrics
    SELECT COUNT(*), COUNT(*) FILTER (WHERE UPPER(status) IN ('COMPLETED', 'RESOLVED', 'DONE'))
    INTO v_total_work_items, v_completed_work_items
    FROM public.work_items
    WHERE sprint_id = v_sprint.id
      AND COALESCE(is_archived, FALSE) = FALSE;

    IF v_total_work_items > 0 THEN
        v_completion_pct := ROUND((v_completed_work_items::numeric / v_total_work_items::numeric) * 100);
    ELSE
        v_completion_pct := 0;
    END IF;

    -- 7. Agile Feedback Cards (Went Well, Poorly, Improve)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', e.id,
            'category', e.category,
            'content', e.content,
            'votes', COALESCE(e.votes, 0),
            'comments_count', COALESCE(e.comments_count, 0),
            'author_name', COALESCE(p.full_name, 'Anonymous Contributor'),
            'author_avatar', p.avatar_url,
            'team_id', e.team_id,
            'team_name', e.team_name,
            'created_at', to_char(e.created_at, 'Mon DD, YYYY'),
            'has_voted', CASE WHEN p_user_id IS NOT NULL THEN EXISTS (
                SELECT 1 FROM public.sprint_retrospective_entry_votes v
                WHERE v.entry_id = e.id AND v.user_id = p_user_id
            ) ELSE FALSE END
        ) ORDER BY e.votes DESC, e.created_at ASC
    ), '[]'::jsonb) INTO v_went_well_json
    FROM public.sprint_retrospective_entries e
    LEFT JOIN public.profiles p ON p.id = e.created_by
    WHERE e.retrospective_id = v_retro.id
      AND e.category = 'WENT_WELL'
      AND (v_clean_team IS NULL OR LOWER(e.team_name) = LOWER(v_clean_team));

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', e.id,
            'category', e.category,
            'content', e.content,
            'votes', COALESCE(e.votes, 0),
            'comments_count', COALESCE(e.comments_count, 0),
            'author_name', COALESCE(p.full_name, 'Anonymous Contributor'),
            'author_avatar', p.avatar_url,
            'team_id', e.team_id,
            'team_name', e.team_name,
            'created_at', to_char(e.created_at, 'Mon DD, YYYY'),
            'has_voted', CASE WHEN p_user_id IS NOT NULL THEN EXISTS (
                SELECT 1 FROM public.sprint_retrospective_entry_votes v
                WHERE v.entry_id = e.id AND v.user_id = p_user_id
            ) ELSE FALSE END
        ) ORDER BY e.votes DESC, e.created_at ASC
    ), '[]'::jsonb) INTO v_went_poorly_json
    FROM public.sprint_retrospective_entries e
    LEFT JOIN public.profiles p ON p.id = e.created_by
    WHERE e.retrospective_id = v_retro.id
      AND e.category = 'DID_NOT_GO_WELL'
      AND (v_clean_team IS NULL OR LOWER(e.team_name) = LOWER(v_clean_team));

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', e.id,
            'category', e.category,
            'content', e.content,
            'votes', COALESCE(e.votes, 0),
            'comments_count', COALESCE(e.comments_count, 0),
            'author_name', COALESCE(p.full_name, 'Anonymous Contributor'),
            'author_avatar', p.avatar_url,
            'team_id', e.team_id,
            'team_name', e.team_name,
            'created_at', to_char(e.created_at, 'Mon DD, YYYY'),
            'has_voted', CASE WHEN p_user_id IS NOT NULL THEN EXISTS (
                SELECT 1 FROM public.sprint_retrospective_entry_votes v
                WHERE v.entry_id = e.id AND v.user_id = p_user_id
            ) ELSE FALSE END
        ) ORDER BY e.votes DESC, e.created_at ASC
    ), '[]'::jsonb) INTO v_to_improve_json
    FROM public.sprint_retrospective_entries e
    LEFT JOIN public.profiles p ON p.id = e.created_by
    WHERE e.retrospective_id = v_retro.id
      AND e.category = 'TO_IMPROVE'
      AND (v_clean_team IS NULL OR LOWER(e.team_name) = LOWER(v_clean_team));

    -- 8. Action Items Table
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', a.id,
            'item_key', a.item_key,
            'title', a.title,
            'description', a.description,
            'owner_id', a.owner_id,
            'owner_name', COALESCE(p.full_name, 'Unassigned'),
            'owner_avatar', p.avatar_url,
            'due_date', to_char(a.due_date, 'Mon DD, YYYY'),
            'priority', UPPER(COALESCE(a.priority, 'MEDIUM')),
            'status', UPPER(COALESCE(a.status, 'OPEN')),
            'progress_percentage', COALESCE(a.progress_percentage, 0),
            'linked_work_item_id', a.linked_work_item_id,
            'linked_work_item_key', wi.item_number,
            'source_entry_id', a.source_entry_id,
            'team_id', a.team_id,
            'team_name', a.team_name
        ) ORDER BY a.created_at ASC
    ), '[]'::jsonb) INTO v_action_items_json
    FROM public.sprint_action_items a
    LEFT JOIN public.profiles p ON p.id = a.owner_id
    LEFT JOIN public.work_items wi ON wi.id = a.linked_work_item_id
    WHERE a.retrospective_id = v_retro.id;

    -- 9. History Timeline (ANONYMIZED FOR FEEDBACK, LATEST ON TOP)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', h.id,
            'milestone', h.milestone,
            'description', h.description,
            'created_at', to_char(h.created_at, 'Mon DD, YYYY, HH12:MI AM'),
            'actor_id', CASE 
                WHEN LOWER(h.milestone) LIKE '%feedback%' OR LOWER(h.description) LIKE '%feedback%' THEN NULL 
                ELSE h.actor_id 
            END,
            'actor_name', CASE 
                WHEN LOWER(h.milestone) LIKE '%feedback%' OR LOWER(h.description) LIKE '%feedback%' THEN 'Anonymous Contributor' 
                ELSE COALESCE(p.full_name, 'System') 
            END
        ) ORDER BY h.created_at DESC
    ), '[]'::jsonb) INTO v_history_json
    FROM public.sprint_retrospective_history h
    LEFT JOIN public.profiles p ON p.id = h.actor_id
    WHERE h.retrospective_id = v_retro.id;

    -- 10. Feedback Tab Responses & Stats
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', f.id,
            'category', f.category,
            'rating', f.rating,
            'content', f.content,
            'suggested_improvement', f.suggested_improvement,
            'is_anonymous', f.is_anonymous,
            'user_id', f.user_id,
            'author_name', CASE WHEN f.is_anonymous THEN 'Anonymous Contributor' ELSE COALESCE(p.full_name, 'Team Member') END,
            'author_avatar', CASE WHEN f.is_anonymous THEN NULL ELSE p.avatar_url END,
            'created_at', to_char(f.created_at, 'Mon DD, YYYY')
        ) ORDER BY f.created_at DESC
    ), '[]'::jsonb) INTO v_feedback_json
    FROM public.sprint_retrospective_feedback f
    LEFT JOIN public.profiles p ON p.id = f.user_id
    WHERE f.retrospective_id = v_retro.id;

    SELECT jsonb_build_object(
        'average_rating', COALESCE(ROUND(AVG(rating)::numeric, 1), 4.6),
        'total_feedback', COUNT(*),
        'five_star_pct', ROUND((COUNT(*) FILTER (WHERE rating = 5)::numeric / GREATEST(COUNT(*), 1)::numeric) * 100),
        'four_star_pct', ROUND((COUNT(*) FILTER (WHERE rating = 4)::numeric / GREATEST(COUNT(*), 1)::numeric) * 100)
    ) INTO v_feedback_stats
    FROM public.sprint_retrospective_feedback
    WHERE retrospective_id = v_retro.id;

    -- 11. Participants Roster based on Team Filter / Sprint (STRICT: Exclude archived / deleted teams)
    IF v_clean_team IS NOT NULL THEN
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', tm.id,
                'user_id', tm.user_id,
                'name', COALESCE(p.full_name, 'Team Member'),
                'email', p.email,
                'avatar_url', p.avatar_url,
                'role', COALESCE(tm.role, 'Member'),
                'attendance_status', 'ATTENDED'
            ) ORDER BY tm.is_lead DESC, p.full_name ASC
        ), '[]'::jsonb) INTO v_participants_json
        FROM public.work_team_members tm
        JOIN public.profiles p ON p.id = tm.user_id
        JOIN public.work_teams wt ON wt.id = tm.team_id
        WHERE tm.team_id = (
            SELECT id FROM public.work_teams 
            WHERE school_id = p_school_id 
              AND LOWER(TRIM(name)) = LOWER(TRIM(v_clean_team)) 
              AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
              AND COALESCE(is_active, TRUE) = TRUE
            LIMIT 1
        )
        AND COALESCE(wt.status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
        AND COALESCE(wt.is_active, TRUE) = TRUE;
    ELSE
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', tm.id,
                'user_id', tm.user_id,
                'name', COALESCE(p.full_name, 'Team Member'),
                'email', p.email,
                'avatar_url', p.avatar_url,
                'role', COALESCE(tm.role, 'Member'),
                'attendance_status', 'ATTENDED'
            ) ORDER BY tm.is_lead DESC, p.full_name ASC
        ), '[]'::jsonb) INTO v_participants_json
        FROM (
            SELECT DISTINCT ON (tm.user_id) tm.id, tm.user_id, tm.role, tm.is_lead
            FROM public.work_team_members tm
            JOIN public.work_teams wt ON wt.id = tm.team_id
            WHERE tm.team_id IN (
                SELECT team_id FROM public.work_sprints WHERE id = v_sprint.id AND team_id IS NOT NULL
                UNION
                SELECT DISTINCT team_id FROM public.work_items WHERE sprint_id = v_sprint.id AND team_id IS NOT NULL
            )
            AND COALESCE(wt.status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
            AND COALESCE(wt.is_active, TRUE) = TRUE
        ) tm
        JOIN public.profiles p ON p.id = tm.user_id;
    END IF;

    -- Fallback if no specific team members found
    IF jsonb_array_length(v_participants_json) = 0 THEN
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', tm.id,
                'user_id', tm.user_id,
                'name', COALESCE(p.full_name, 'Team Member'),
                'email', p.email,
                'avatar_url', p.avatar_url,
                'role', COALESCE(tm.role, 'Member'),
                'attendance_status', 'ATTENDED'
            ) ORDER BY tm.is_lead DESC, p.full_name ASC
        ), '[]'::jsonb) INTO v_participants_json
        FROM (
            SELECT DISTINCT ON (tm.user_id) tm.id, tm.user_id, tm.role, tm.is_lead
            FROM public.work_team_members tm
            JOIN public.work_teams wt ON wt.id = tm.team_id
            WHERE tm.school_id = p_school_id
              AND COALESCE(wt.status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
              AND COALESCE(wt.is_active, TRUE) = TRUE
            LIMIT 8
        ) tm
        JOIN public.profiles p ON p.id = tm.user_id;
    END IF;

    v_total_participants := jsonb_array_length(v_participants_json);
    v_attended_participants := v_total_participants;

    -- 12. Assemble Full Workspace Payload
    v_res := jsonb_build_object(
        'success', true,
        'sprint_id', v_sprint.id,
        'sprint_name', v_sprint.name,
        'session_title', COALESCE(v_retro.title, 'Sprint Retrospective'),
        'session_status', COALESCE(v_retro.status, 'COMPLETED'),
        'session_date', to_char(COALESCE(v_retro.session_date, NOW()), 'Mon DD, YYYY, HH12:MI AM'),
        'duration_minutes', COALESCE(v_retro.duration_minutes, 60),
        'facilitator_name', COALESCE(v_facilitator.full_name, 'Neha Sharma'),
        'facilitator_avatar', v_facilitator.avatar_url,
        'sprint_goal', COALESCE(v_retro.sprint_goal, v_sprint.goal, 'Deliver student portal enhancement, examination notifications and key infrastructure fixes.'),
        'team_name', COALESCE(v_clean_team, 'All Teams'),
        'duration_window', to_char(v_sprint.start_date, 'Mon DD, YYYY') || ' - ' || to_char(v_sprint.end_date, 'Mon DD, YYYY') || ' (' || (COALESCE(v_sprint.end_date - v_sprint.start_date, 13) + 1)::TEXT || ' days)',
        'available_teams', v_available_teams_json,
        'available_sprints', v_available_sprints_json,
        'completion', jsonb_build_object(
            'completed', v_completed_work_items,
            'total', v_total_work_items,
            'percentage', v_completion_pct
        ),
        'total_participants', v_total_participants,
        'participant_count', v_attended_participants,
        'attendance', jsonb_build_object(
            'attended', v_attended_participants,
            'total', v_total_participants,
            'percentage', CASE WHEN v_total_participants > 0 THEN ROUND((v_attended_participants::numeric / v_total_participants::numeric) * 100) ELSE 100 END
        ),
        'participants', v_participants_json,
        'went_well', jsonb_build_object(
            'title', 'What Went Well? (' || jsonb_array_length(v_went_well_json) || ')',
            'key', 'WENT_WELL',
            'count', jsonb_array_length(v_went_well_json),
            'entries', v_went_well_json
        ),
        'did_not_go_well', jsonb_build_object(
            'title', 'What Didn''t Go Well? (' || jsonb_array_length(v_went_poorly_json) || ')',
            'key', 'DID_NOT_GO_WELL',
            'count', jsonb_array_length(v_went_poorly_json),
            'entries', v_went_poorly_json
        ),
        'should_improve', jsonb_build_object(
            'title', 'What Should Improve? (' || jsonb_array_length(v_to_improve_json) || ')',
            'key', 'TO_IMPROVE',
            'count', jsonb_array_length(v_to_improve_json),
            'entries', v_to_improve_json
        ),
        'action_items', v_action_items_json,
        'history', v_history_json,
        'feedback', v_feedback_json,
        'feedback_stats', v_feedback_stats,
        'retrospective', jsonb_build_object(
            'id', v_retro.id,
            'sprint_id', v_sprint.id,
            'title', COALESCE(v_retro.title, 'Sprint Retrospective'),
            'status', COALESCE(v_retro.status, 'COMPLETED'),
            'session_date_formatted', to_char(COALESCE(v_retro.session_date, NOW()), 'Mon DD, YYYY, HH12:MI AM'),
            'facilitator_name', COALESCE(v_facilitator.full_name, 'Neha Sharma'),
            'facilitator_avatar', v_facilitator.avatar_url,
            'duration_minutes', COALESCE(v_retro.duration_minutes, 60),
            'sprint_goal', COALESCE(v_retro.sprint_goal, v_sprint.goal, 'Deliver student portal enhancement, examination notifications and key infrastructure fixes.'),
            'summary', COALESCE(v_retro.summary, 'The team delivered key improvements, maintained good collaboration, and achieved target completion.'),
            'notes', v_retro.notes,
            'total_participants', v_total_participants,
            'participant_count', v_attended_participants,
            'participation_pct', CASE WHEN v_total_participants > 0 THEN ROUND((v_attended_participants::numeric / v_total_participants::numeric) * 100) ELSE 100 END
        ),
        'sprint_overview', jsonb_build_object(
            'sprint_name', v_sprint.name,
            'status', UPPER(v_sprint.status),
            'date_range', to_char(v_sprint.start_date, 'Mon DD, YYYY') || ' - ' || to_char(v_sprint.end_date, 'Mon DD, YYYY') || ' (' || (COALESCE(v_sprint.end_date - v_sprint.start_date, 13) + 1)::TEXT || ' days)',
            'team_name', COALESCE(v_clean_team, 'All Teams'),
            'completed_work', v_completed_work_items || ' of ' || v_total_work_items || ' (' || v_completion_pct || '%)',
            'sprint_goal', COALESCE(v_retro.sprint_goal, v_sprint.goal, 'Faculty management modules and attendance auto-sync rollout.')
        )
    );

    RETURN v_res;
END;
$$;


-- 2. Update sp_get_sprint_capacity_dashboard
CREATE OR REPLACE FUNCTION public.sp_get_sprint_capacity_dashboard(
    p_school_id UUID,
    p_sprint_id UUID,
    p_team_name VARCHAR DEFAULT 'Digital Campus Team',
    p_search VARCHAR DEFAULT NULL,
    p_role VARCHAR DEFAULT 'ALL',
    p_status VARCHAR DEFAULT 'ALL',
    p_sort_by VARCHAR DEFAULT 'NAME_ASC',
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sprint_id UUID := p_sprint_id;
    v_sprint_row RECORD;
    v_team_id UUID := NULL;
    v_team_name VARCHAR := TRIM(COALESCE(p_team_name, 'Digital Campus Team'));
    v_is_all_teams BOOLEAN := (UPPER(v_team_name) IN ('ALL', 'ALL TEAMS', ''));
    v_sprint_days INT := 14;
    v_working_days INT := 10;
    
    v_teams_list JSONB;
    v_all_sprints_list JSONB;
    v_roles_list JSONB;
    v_metrics JSONB;
    v_workload_dist JSONB;
    v_members_list JSONB;
    v_total_members_count INT := 0;
BEGIN
    -- 1. Fetch Sprint details
    SELECT s.*,
           COALESCE(GREATEST(1, (s.end_date - s.start_date + 1)), 14) AS calc_duration_days
    INTO v_sprint_row
    FROM public.work_sprints s
    LEFT JOIN public.work_boards b ON b.id = s.board_id
    WHERE s.id = v_sprint_id AND s.school_id = p_school_id;

    IF v_sprint_row.calc_duration_days IS NOT NULL THEN
        v_sprint_days := v_sprint_row.calc_duration_days;
        v_working_days := GREATEST(1, ROUND(v_sprint_days * 5.0 / 7.0)::INT);
    END IF;

    -- Resolve selected team ID if specific team requested (STRICT: exclude archived/deleted)
    IF NOT v_is_all_teams THEN
        SELECT id, name INTO v_team_id, v_team_name
        FROM public.work_teams
        WHERE school_id = p_school_id
          AND (id::text = v_team_name OR name ILIKE v_team_name)
          AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
          AND COALESCE(is_active, TRUE) = TRUE
        LIMIT 1;
    END IF;

    -- 2. Fetch Teams List from work_teams table (STRICT: exclude archived/deleted)
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', t.id,
            'name', t.name,
            'department', t.department,
            'icon', t.icon,
            'status', UPPER(COALESCE(t.status, 'ACTIVE')),
            'is_active', COALESCE(t.is_active, TRUE),
            'member_count', (SELECT COUNT(*) FROM public.work_team_members wtm WHERE wtm.team_id = t.id),
            'is_selected', (v_team_id IS NOT NULL AND t.id = v_team_id) OR (v_is_all_teams AND t.name = v_team_name)
        ) ORDER BY t.name ASC
    ) INTO v_teams_list
    FROM public.work_teams t
    WHERE t.school_id = p_school_id 
      AND COALESCE(t.status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
      AND COALESCE(t.is_active, TRUE) = TRUE;

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

    -- Fetch Distinct Roles for Filter Dropdown (Active non-archived teams only)
    SELECT jsonb_agg(DISTINCT wtm.role)
    INTO v_roles_list
    FROM public.work_team_members wtm
    JOIN public.work_teams t ON t.id = wtm.team_id
    WHERE t.school_id = p_school_id
      AND COALESCE(t.status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
      AND COALESCE(t.is_active, TRUE) = TRUE
      AND (v_is_all_teams OR (v_team_id IS NOT NULL AND wtm.team_id = v_team_id) OR t.name = v_team_name);

    IF v_roles_list IS NULL THEN
        v_roles_list := '["All Roles"]'::jsonb;
    ELSE
        v_roles_list := jsonb_build_array('All Roles') || v_roles_list;
    END IF;

    -- 3. Calculate Global KPI Metrics across team members (Active non-archived teams only)
    WITH member_capacity_calc AS (
        SELECT
            wtm.user_id,
            wtm.team_id,
            t.name AS team_name,
            p.full_name AS member_name,
            wtm.role AS member_role,
            COALESCE(smc.working_days, v_working_days) AS working_days,
            COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0) AS daily_hours,
            COALESCE(smc.days_off, 0.0) AS days_off,
            COALESCE(
                smc.override_value,
                smc.available_hours,
                GREATEST(0.0, (COALESCE(smc.working_days, v_working_days) - COALESCE(smc.days_off, 0.0)) * COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0))
            ) AS effective_capacity_hours,
            COALESCE((
                SELECT SUM(COALESCE(wi.estimated_hours, wi.story_points, 0.0))
                FROM public.work_items wi
                WHERE (wi.sprint_id = v_sprint_id OR wi.sprint_id IS NULL)
                  AND (wi.assignee_id = wtm.user_id OR wi.assignee_name ILIKE p.full_name)
                  AND (wi.team_id = wtm.team_id OR wi.team_name ILIKE t.name)
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0.0) AS actual_hours
        FROM public.work_team_members wtm
        JOIN public.work_teams t ON t.id = wtm.team_id
        JOIN public.profiles p ON p.id = wtm.user_id
        LEFT JOIN public.sprint_member_capacities smc
               ON smc.sprint_id = v_sprint_id
              AND (smc.team_id = wtm.team_id OR smc.team_id IS NULL)
              AND smc.user_id = wtm.user_id
        WHERE t.school_id = p_school_id
          AND COALESCE(t.status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
          AND COALESCE(t.is_active, TRUE) = TRUE
          AND (v_is_all_teams OR (v_team_id IS NOT NULL AND wtm.team_id = v_team_id) OR t.name = v_team_name)
    ),
    summary AS (
        SELECT
            COUNT(DISTINCT user_id) AS total_members,
            COALESCE(SUM(effective_capacity_hours), 0.0) AS total_capacity,
            COALESCE(SUM(actual_hours), 0.0) AS total_allocated,
            ROUND(
                CASE WHEN SUM(effective_capacity_hours) > 0
                     THEN (SUM(actual_hours) / SUM(effective_capacity_hours) * 100.0)
                     ELSE 0.0 END, 1
            ) AS avg_utilization
        FROM member_capacity_calc
    )
    SELECT jsonb_build_object(
        'total_capacity_hours', s.total_capacity,
        'allocated_hours', s.total_allocated,
        'available_hours', GREATEST(0.0, s.total_capacity - s.total_allocated),
        'capacity_utilization_pct', s.avg_utilization,
        'total_members', s.total_members
    ) INTO v_metrics
    FROM summary s;

    -- 4. Workload Distribution breakdown
    WITH member_capacity_calc AS (
        SELECT
            wtm.user_id,
            COALESCE(
                smc.override_value,
                smc.available_hours,
                GREATEST(0.0, (COALESCE(smc.working_days, v_working_days) - COALESCE(smc.days_off, 0.0)) * COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0))
            ) AS effective_capacity_hours,
            COALESCE((
                SELECT SUM(COALESCE(wi.estimated_hours, wi.story_points, 0.0))
                FROM public.work_items wi
                WHERE (wi.sprint_id = v_sprint_id OR wi.sprint_id IS NULL)
                  AND (wi.assignee_id = wtm.user_id OR wi.assignee_name ILIKE p.full_name)
                  AND (wi.team_id = wtm.team_id OR wi.team_name ILIKE t.name)
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
          AND COALESCE(t.status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
          AND COALESCE(t.is_active, TRUE) = TRUE
          AND (v_is_all_teams OR (v_team_id IS NOT NULL AND wtm.team_id = v_team_id) OR t.name = v_team_name)
    ),
    dist AS (
        SELECT
            COUNT(*) FILTER (WHERE effective_capacity_hours > 0 AND (planned_hours / effective_capacity_hours) > 1.0) AS overloaded_count,
            COUNT(*) FILTER (WHERE effective_capacity_hours > 0 AND (planned_hours / effective_capacity_hours) BETWEEN 0.8 AND 1.0) AS optimal_count,
            COUNT(*) FILTER (WHERE effective_capacity_hours > 0 AND (planned_hours / effective_capacity_hours) < 0.8) AS underutilized_count
        FROM member_capacity_calc
    )
    SELECT jsonb_build_object(
        'overloaded', d.overloaded_count,
        'optimal', d.optimal_count,
        'underutilized', d.underutilized_count
    ) INTO v_workload_dist
    FROM dist d;

    -- 5. Paginated and Sorted Member Capacity List
    WITH raw_members AS (
        SELECT
            wtm.user_id,
            p.full_name AS member_name,
            p.avatar_url,
            p.email,
            wtm.role AS member_role,
            t.name AS team_name,
            wtm.is_lead,
            COALESCE(smc.working_days, v_working_days) AS working_days,
            COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0) AS daily_hours,
            COALESCE(smc.days_off, 0.0) AS days_off,
            COALESCE(
                smc.override_value,
                smc.available_hours,
                GREATEST(0.0, (COALESCE(smc.working_days, v_working_days) - COALESCE(smc.days_off, 0.0)) * COALESCE(smc.daily_working_hours, wtm.daily_hours, 8.0))
            ) AS effective_capacity_hours,
            COALESCE((
                SELECT SUM(COALESCE(wi.estimated_hours, wi.story_points, 0.0))
                FROM public.work_items wi
                WHERE (wi.sprint_id = v_sprint_id OR wi.sprint_id IS NULL)
                  AND (wi.assignee_id = wtm.user_id OR wi.assignee_name ILIKE p.full_name)
                  AND (wi.team_id = wtm.team_id OR wi.team_name ILIKE t.name)
                  AND COALESCE(wi.is_archived, FALSE) = FALSE
            ), 0.0) AS actual_hours
        FROM public.work_team_members wtm
        JOIN public.work_teams t ON t.id = wtm.team_id
        JOIN public.profiles p ON p.id = wtm.user_id
        LEFT JOIN public.sprint_member_capacities smc
               ON smc.sprint_id = v_sprint_id
              AND (smc.team_id = wtm.team_id OR smc.team_id IS NULL)
              AND smc.user_id = wtm.user_id
        WHERE t.school_id = p_school_id
          AND COALESCE(t.status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
          AND COALESCE(t.is_active, TRUE) = TRUE
          AND (v_is_all_teams OR (v_team_id IS NOT NULL AND wtm.team_id = v_team_id) OR t.name = v_team_name)
          AND (p_search IS NULL OR p_search = '' OR p.full_name ILIKE '%' || p_search || '%' OR wtm.role ILIKE '%' || p_search || '%')
          AND (p_role IS NULL OR p_role = 'ALL' OR p_role = 'All Roles' OR wtm.role ILIKE p_role)
    ),
    classified_members AS (
        SELECT
            m.*,
            ROUND(
                CASE WHEN m.effective_capacity_hours > 0
                     THEN (m.actual_hours / m.effective_capacity_hours * 100.0)
                     ELSE 0.0 END, 1
            ) AS utilization_pct,
            CASE
                WHEN m.effective_capacity_hours > 0 AND (m.actual_hours / m.effective_capacity_hours) > 1.0 THEN 'OVERLOADED'
                WHEN m.effective_capacity_hours > 0 AND (m.actual_hours / m.effective_capacity_hours) >= 0.8 THEN 'OPTIMAL'
                ELSE 'UNDERUTILIZED'
            END AS load_status
        FROM raw_members m
        WHERE (
            p_status IS NULL OR p_status = 'ALL' OR p_status = 'All Status'
            OR (p_status = 'OVERLOADED' AND m.effective_capacity_hours > 0 AND (m.actual_hours / m.effective_capacity_hours) > 1.0)
            OR (p_status = 'OPTIMAL' AND m.effective_capacity_hours > 0 AND (m.actual_hours / m.effective_capacity_hours) BETWEEN 0.8 AND 1.0)
            OR (p_status = 'UNDERUTILIZED' AND (m.effective_capacity_hours = 0 OR (m.actual_hours / m.effective_capacity_hours) < 0.8))
        )
    )
    SELECT COUNT(*) INTO v_total_members_count FROM classified_members;

    WITH paged_members AS (
        SELECT *
        FROM classified_members
        ORDER BY
            CASE WHEN p_sort_by = 'NAME_ASC' THEN member_name END ASC,
            CASE WHEN p_sort_by = 'NAME_DESC' THEN member_name END DESC,
            CASE WHEN p_sort_by = 'ROLE_ASC' THEN member_role END ASC,
            CASE WHEN p_sort_by = 'CAPACITY_DESC' THEN effective_capacity_hours END DESC,
            CASE WHEN p_sort_by = 'ALLOCATED_DESC' THEN actual_hours END DESC,
            CASE WHEN p_sort_by = 'UTILIZATION_DESC' THEN utilization_pct END DESC,
            member_name ASC
        LIMIT p_limit OFFSET p_offset
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'user_id', pm.user_id,
            'name', pm.member_name,
            'avatar_url', pm.avatar_url,
            'email', pm.email,
            'role', pm.member_role,
            'team_name', pm.team_name,
            'is_lead', pm.is_lead,
            'working_days', pm.working_days,
            'daily_working_hours', pm.daily_hours,
            'days_off', pm.days_off,
            'available_hours', pm.effective_capacity_hours,
            'allocated_hours', pm.actual_hours,
            'capacity_utilization_pct', pm.utilization_pct,
            'status', pm.load_status,
            'sprint_days', v_sprint_days
        )
    ) INTO v_members_list
    FROM paged_members pm;

    IF v_members_list IS NULL THEN
        v_members_list := '[]'::jsonb;
    END IF;

    -- Return consolidated JSON response
    RETURN jsonb_build_object(
        'success', TRUE,
        'sprint', jsonb_build_object(
            'id', v_sprint_row.id,
            'name', v_sprint_row.name,
            'status', v_sprint_row.status,
            'start_date', to_char(v_sprint_row.start_date, 'Mon DD, YYYY'),
            'end_date', to_char(v_sprint_row.end_date, 'Mon DD, YYYY'),
            'working_days', v_working_days,
            'sprint_days', v_sprint_days
        ),
        'team_name', v_team_name,
        'teams', v_teams_list,
        'sprints', v_all_sprints_list,
        'roles', v_roles_list,
        'metrics', v_metrics,
        'workload_distribution', v_workload_dist,
        'members', v_members_list,
        'total_members_count', v_total_members_count
    );
END;
$$;


-- 3. Update sp_manage_sprint_retrospective_entry_v2
CREATE OR REPLACE FUNCTION public.sp_manage_sprint_retrospective_entry_v2(
    p_school_id UUID,
    p_sprint_id UUID,
    p_user_id UUID,
    p_action VARCHAR,
    p_entry_id UUID DEFAULT NULL,
    p_category VARCHAR DEFAULT 'WENT_WELL',
    p_content TEXT DEFAULT NULL,
    p_team_id UUID DEFAULT NULL,
    p_team_name VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_retro_id UUID;
    v_user_role VARCHAR;
    v_entry_creator UUID;
    v_resolved_team_id UUID := p_team_id;
    v_resolved_team_name VARCHAR := p_team_name;
    v_res RECORD;
    v_old_content TEXT;
    v_old_category VARCHAR;
BEGIN
    SELECT id INTO v_retro_id FROM public.sprint_retrospectives WHERE sprint_id = p_sprint_id LIMIT 1;
    IF v_retro_id IS NULL THEN
        INSERT INTO public.sprint_retrospectives (school_id, sprint_id, title, status)
        VALUES (p_school_id, p_sprint_id, 'Sprint Retrospective', 'COMPLETED')
        RETURNING id INTO v_retro_id;
    END IF;

    SELECT role INTO v_user_role FROM public.profiles WHERE id = p_user_id;

    -- Resolve team strictly excluding archived/deleted
    IF v_resolved_team_id IS NULL AND v_resolved_team_name IS NOT NULL AND LOWER(TRIM(v_resolved_team_name)) NOT IN ('all', 'all teams', '') THEN
        SELECT id INTO v_resolved_team_id
        FROM public.work_teams
        WHERE school_id = p_school_id 
          AND LOWER(name) = LOWER(TRIM(v_resolved_team_name))
          AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
          AND COALESCE(is_active, TRUE) = TRUE
        LIMIT 1;
    ELSIF v_resolved_team_id IS NOT NULL AND v_resolved_team_name IS NULL THEN
        SELECT name INTO v_resolved_team_name
        FROM public.work_teams
        WHERE id = v_resolved_team_id
          AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
          AND COALESCE(is_active, TRUE) = TRUE;
    END IF;

    IF UPPER(p_action) = 'DELETE' THEN
        SELECT content, category INTO v_old_content, v_old_category
        FROM public.sprint_retrospective_entries
        WHERE id = p_entry_id;

        IF p_entry_id IS NOT NULL THEN
            SELECT created_by INTO v_entry_creator FROM public.sprint_retrospective_entries WHERE id = p_entry_id;
            IF v_entry_creator != p_user_id AND v_user_role NOT IN ('super_admin', 'admin') THEN
                RETURN jsonb_build_object('success', false, 'message', 'You can only delete your own feedback.');
            END IF;
        END IF;

        DELETE FROM public.sprint_retrospective_entries WHERE id = p_entry_id;

        INSERT INTO public.sprint_retrospective_history (
            retrospective_id, milestone, description, actor_id, changes
        ) VALUES (
            v_retro_id,
            'Discussion Note Deleted',
            'Deleted ' || COALESCE(v_old_category, 'item') || ': ' || LEFT(COALESCE(v_old_content, ''), 50),
            p_user_id,
            jsonb_build_object('action', 'DELETE_ENTRY', 'entry_id', p_entry_id)
        );

        RETURN jsonb_build_object('success', true, 'action', 'DELETE');

    ELSIF UPPER(p_action) = 'UPDATE' THEN
        SELECT content, category INTO v_old_content, v_old_category
        FROM public.sprint_retrospective_entries
        WHERE id = p_entry_id;

        IF p_entry_id IS NOT NULL THEN
            SELECT created_by INTO v_entry_creator FROM public.sprint_retrospective_entries WHERE id = p_entry_id;
            IF v_entry_creator != p_user_id AND v_user_role NOT IN ('super_admin', 'admin') THEN
                RETURN jsonb_build_object('success', false, 'message', 'You can only edit your own feedback.');
            END IF;
        END IF;

        UPDATE public.sprint_retrospective_entries
        SET content = COALESCE(p_content, content),
            category = COALESCE(p_category, category),
            team_id = COALESCE(v_resolved_team_id, team_id),
            team_name = COALESCE(v_resolved_team_name, team_name),
            updated_at = NOW()
        WHERE id = p_entry_id
        RETURNING * INTO v_res;

        INSERT INTO public.sprint_retrospective_history (
            retrospective_id, milestone, description, actor_id, changes
        ) VALUES (
            v_retro_id,
            'Discussion Note Updated',
            'Updated ' || COALESCE(p_category, v_old_category, 'item') || ': ' || LEFT(COALESCE(p_content, v_old_content, ''), 50),
            p_user_id,
            jsonb_build_object('action', 'UPDATE_ENTRY', 'entry_id', p_entry_id, 'old_content', v_old_content, 'new_content', p_content)
        );

        RETURN jsonb_build_object('success', true, 'action', 'UPDATE', 'entry', row_to_json(v_res));

    ELSIF UPPER(p_action) = 'CREATE' THEN
        IF v_resolved_team_name IS NOT NULL AND v_resolved_team_id IS NULL THEN
            SELECT id INTO v_resolved_team_id 
            FROM public.work_teams 
            WHERE school_id = p_school_id 
              AND LOWER(name) = LOWER(TRIM(v_resolved_team_name))
              AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
              AND COALESCE(is_active, TRUE) = TRUE
            LIMIT 1;
        ELSIF v_resolved_team_id IS NOT NULL AND v_resolved_team_name IS NULL THEN
            SELECT name INTO v_resolved_team_name 
            FROM public.work_teams 
            WHERE id = v_resolved_team_id
              AND COALESCE(status, 'ACTIVE') NOT IN ('ARCHIVED', 'DELETED')
              AND COALESCE(is_active, TRUE) = TRUE;
        END IF;

        INSERT INTO public.sprint_retrospective_entries (
            retrospective_id, category, content, created_by, team_id, team_name
        ) VALUES (
            v_retro_id, p_category, p_content, p_user_id, v_resolved_team_id, v_resolved_team_name
        ) RETURNING * INTO v_res;

        INSERT INTO public.sprint_retrospective_history (
            retrospective_id, milestone, description, actor_id, changes
        ) VALUES (
            v_retro_id,
            'New Discussion Note Added',
            'Added note to ' || p_category || ': ' || LEFT(p_content, 50),
            p_user_id,
            jsonb_build_object('action', 'CREATE_ENTRY', 'entry_id', v_res.id, 'category', p_category)
        );

        RETURN jsonb_build_object('success', true, 'action', 'CREATE', 'entry', row_to_json(v_res));
    END IF;

    RETURN jsonb_build_object('success', false, 'message', 'Invalid action');
END;
$$;
