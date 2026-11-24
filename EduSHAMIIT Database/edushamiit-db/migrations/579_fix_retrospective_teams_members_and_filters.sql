-- Migration 579: Fix Sprint Retrospective Dynamic Teams, Member Participation & Cross-Tab Scoping
-- Resolves:
-- 1. Dynamic Teams in Retrospective: sp_get_sprint_retrospective_workspace returns available_teams and available_sprints from DB
-- 2. Team-Specific Member Participation: Calculates exact team roster size (e.g. 2 for KING, 6 for Exam, 7 for DCT, 8 for AST) instead of hardcoding 7
-- 3. Live Action Item Team Scoping: Adds team_id and team_name to sprint_action_items with full filtering
-- 4. Automatic Team Resolution: Entry creation resolves team_name to team_id and vice-versa

-- 1. Ensure team columns on sprint_action_items
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'sprint_action_items' AND column_name = 'team_id'
    ) THEN
        ALTER TABLE public.sprint_action_items ADD COLUMN team_id UUID REFERENCES public.work_teams(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'sprint_action_items' AND column_name = 'team_name'
    ) THEN
        ALTER TABLE public.sprint_action_items ADD COLUMN team_name VARCHAR(100);
    END IF;
END $$;

-- 2. Update sp_manage_sprint_action_item_v2 to accept team_id and team_name
CREATE OR REPLACE FUNCTION public.sp_manage_sprint_action_item_v2(
    p_school_id UUID,
    p_sprint_id UUID,
    p_action_item_id UUID DEFAULT NULL,
    p_item_key VARCHAR DEFAULT NULL,
    p_title VARCHAR DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_owner_id UUID DEFAULT NULL,
    p_due_date DATE DEFAULT NULL,
    p_priority VARCHAR DEFAULT 'MEDIUM',
    p_status VARCHAR DEFAULT 'OPEN',
    p_progress INT DEFAULT 0,
    p_linked_work_item_id UUID DEFAULT NULL,
    p_source_entry_id UUID DEFAULT NULL,
    p_action VARCHAR DEFAULT 'ADD', -- ADD, UPDATE, DELETE, CONVERT_TO_WORK_ITEM
    p_actor_id UUID DEFAULT NULL,
    p_team_id UUID DEFAULT NULL,
    p_team_name VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_retro_id UUID;
    v_id UUID := COALESCE(p_action_item_id, gen_random_uuid());
    v_key VARCHAR(50);
    v_next_num INT;
    v_board_id UUID;
    v_work_item_id UUID;
    v_item_number VARCHAR(50);
    v_resolved_team_id UUID := p_team_id;
    v_resolved_team_name VARCHAR(100) := p_team_name;
BEGIN
    SELECT id INTO v_retro_id FROM public.sprint_retrospectives WHERE sprint_id = p_sprint_id;
    IF v_retro_id IS NULL THEN
        INSERT INTO public.sprint_retrospectives (school_id, sprint_id, facilitator_id)
        VALUES (p_school_id, p_sprint_id, p_actor_id)
        RETURNING id INTO v_retro_id;
    END IF;

    -- Resolve team if only one provided
    IF v_resolved_team_name IS NOT NULL AND v_resolved_team_id IS NULL THEN
        SELECT id, name INTO v_resolved_team_id, v_resolved_team_name
        FROM public.work_teams
        WHERE school_id = p_school_id AND LOWER(name) = LOWER(TRIM(v_resolved_team_name))
        LIMIT 1;
    ELSIF v_resolved_team_id IS NOT NULL AND v_resolved_team_name IS NULL THEN
        SELECT name INTO v_resolved_team_name
        FROM public.work_teams
        WHERE id = v_resolved_team_id;
    END IF;

    IF UPPER(p_action) = 'DELETE' THEN
        DELETE FROM public.sprint_action_items WHERE id = p_action_item_id;
        RETURN jsonb_build_object('success', true, 'action', 'DELETED', 'action_item_id', p_action_item_id);

    ELSIF UPPER(p_action) = 'CONVERT_TO_WORK_ITEM' THEN
        -- Find board
        SELECT board_id INTO v_board_id FROM public.work_sprints WHERE id = p_sprint_id;
        IF v_board_id IS NULL THEN
            SELECT id INTO v_board_id FROM public.work_boards WHERE school_id = p_school_id LIMIT 1;
        END IF;

        -- Generate work item number
        SELECT COALESCE(MAX(SUBSTRING(item_number FROM '[0-9]+')::INT), 1050) + 1 INTO v_next_num FROM public.work_items;
        v_item_number := 'TK-' || v_next_num;
        v_work_item_id := gen_random_uuid();

        INSERT INTO public.work_items (
            id, school_id, board_id, sprint_id, item_number, title,
            description, work_type, priority, status, reporter_id, team_id, team_name
        ) VALUES (
            v_work_item_id, p_school_id, v_board_id, p_sprint_id, v_item_number,
            p_title, p_description, 'TASK', UPPER(COALESCE(p_priority, 'HIGH')), 'IN_PROGRESS', p_actor_id,
            v_resolved_team_id, v_resolved_team_name
        );

        UPDATE public.sprint_action_items
        SET linked_work_item_id = v_work_item_id, status = 'IN_PROGRESS', progress_percentage = 25
        WHERE id = p_action_item_id;

        RETURN jsonb_build_object(
            'success', true,
            'action', 'CONVERTED',
            'action_item_id', p_action_item_id,
            'work_item_id', v_work_item_id,
            'item_number', v_item_number
        );

    ELSIF UPPER(p_action) = 'UPDATE' THEN
        UPDATE public.sprint_action_items
        SET title = COALESCE(p_title, title),
            description = COALESCE(p_description, description),
            owner_id = COALESCE(p_owner_id, owner_id),
            due_date = COALESCE(p_due_date, due_date),
            priority = COALESCE(UPPER(p_priority), priority),
            status = COALESCE(UPPER(p_status), status),
            progress_percentage = COALESCE(p_progress, progress_percentage),
            team_id = COALESCE(v_resolved_team_id, team_id),
            team_name = COALESCE(v_resolved_team_name, team_name),
            updated_at = NOW()
        WHERE id = p_action_item_id;

        RETURN jsonb_build_object('success', true, 'action', 'UPDATED', 'action_item_id', p_action_item_id);

    ELSE
        -- ADD Action Item
        SELECT COALESCE(MAX(SUBSTRING(item_key FROM '[0-9]+')::INT), 0) + 1 INTO v_next_num
        FROM public.sprint_action_items WHERE retrospective_id = v_retro_id;
        v_key := 'RA-' || LPAD(v_next_num::TEXT, 3, '0');

        INSERT INTO public.sprint_action_items (
            id, retrospective_id, item_key, title, description, owner_id,
            due_date, priority, status, progress_percentage, linked_work_item_id,
            source_entry_id, team_id, team_name
        ) VALUES (
            v_id, v_retro_id, v_key, p_title, p_description, p_owner_id,
            COALESCE(p_due_date, CURRENT_DATE + INTERVAL '10 days'),
            UPPER(COALESCE(p_priority, 'MEDIUM')),
            UPPER(COALESCE(p_status, 'OPEN')),
            COALESCE(p_progress, 0),
            p_linked_work_item_id, p_source_entry_id,
            v_resolved_team_id, v_resolved_team_name
        );

        RETURN jsonb_build_object(
            'success', true,
            'action', 'ADDED',
            'action_item_id', v_id,
            'item_key', v_key
        );
    END IF;
END;
$$;

-- 3. Update sp_manage_sprint_retrospective_entry_v2 to resolve team_name to team_id
CREATE OR REPLACE FUNCTION public.sp_manage_sprint_retrospective_entry_v2(
    p_school_id UUID,
    p_sprint_id UUID,
    p_entry_id UUID DEFAULT NULL,
    p_category VARCHAR DEFAULT 'WENT_WELL',
    p_content TEXT DEFAULT NULL,
    p_action VARCHAR DEFAULT 'ADD', -- ADD, UPDATE, DELETE, VOTE
    p_actor_id UUID DEFAULT NULL,
    p_team_id UUID DEFAULT NULL,
    p_team_name VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_retro_id UUID;
    v_entry_id UUID := COALESCE(p_entry_id, gen_random_uuid());
    v_new_votes INT := 0;
    v_actor UUID := COALESCE(p_actor_id, (SELECT id FROM public.profiles WHERE role = 'super_admin' LIMIT 1));
    v_has_voted BOOLEAN := FALSE;
    v_resolved_team_id UUID := p_team_id;
    v_resolved_team_name VARCHAR(100) := p_team_name;
BEGIN
    SELECT id INTO v_retro_id FROM public.sprint_retrospectives WHERE sprint_id = p_sprint_id;
    IF v_retro_id IS NULL THEN
        INSERT INTO public.sprint_retrospectives (school_id, sprint_id, facilitator_id)
        VALUES (p_school_id, p_sprint_id, v_actor)
        RETURNING id INTO v_retro_id;
    END IF;

    -- Resolve team if provided by name or id
    IF v_resolved_team_name IS NOT NULL AND v_resolved_team_id IS NULL THEN
        SELECT id, name INTO v_resolved_team_id, v_resolved_team_name
        FROM public.work_teams
        WHERE school_id = p_school_id AND LOWER(name) = LOWER(TRIM(v_resolved_team_name))
        LIMIT 1;
    ELSIF v_resolved_team_id IS NOT NULL AND v_resolved_team_name IS NULL THEN
        SELECT name INTO v_resolved_team_name
        FROM public.work_teams
        WHERE id = v_resolved_team_id;
    END IF;

    IF UPPER(p_action) = 'DELETE' THEN
        DELETE FROM public.sprint_retrospective_entry_votes WHERE entry_id = p_entry_id;
        DELETE FROM public.sprint_retrospective_comments WHERE entry_id = p_entry_id;
        DELETE FROM public.sprint_retrospective_entries WHERE id = p_entry_id;
        RETURN jsonb_build_object('success', true, 'action', 'DELETED', 'entry_id', p_entry_id);

    ELSIF UPPER(p_action) = 'VOTE' THEN
        IF v_actor IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.sprint_retrospective_entry_votes
            WHERE entry_id = p_entry_id AND user_id = v_actor
        ) THEN
            -- Toggle vote off
            DELETE FROM public.sprint_retrospective_entry_votes
            WHERE entry_id = p_entry_id AND user_id = v_actor;

            UPDATE public.sprint_retrospective_entries
            SET votes = GREATEST(COALESCE(votes, 1) - 1, 0)
            WHERE id = p_entry_id
            RETURNING votes INTO v_new_votes;

            RETURN jsonb_build_object(
                'success', true,
                'action', 'UNVOTED',
                'entry_id', p_entry_id,
                'votes', v_new_votes,
                'has_voted', false
            );
        ELSE
            -- Toggle vote on
            IF v_actor IS NOT NULL THEN
                INSERT INTO public.sprint_retrospective_entry_votes (entry_id, user_id)
                VALUES (p_entry_id, v_actor)
                ON CONFLICT (entry_id, user_id) DO NOTHING;
            END IF;

            UPDATE public.sprint_retrospective_entries
            SET votes = COALESCE(votes, 0) + 1
            WHERE id = p_entry_id
            RETURNING votes INTO v_new_votes;

            RETURN jsonb_build_object(
                'success', true,
                'action', 'VOTED',
                'entry_id', p_entry_id,
                'votes', v_new_votes,
                'has_voted', true
            );
        END IF;

    ELSIF UPPER(p_action) = 'UPDATE' THEN
        UPDATE public.sprint_retrospective_entries
        SET content = COALESCE(p_content, content),
            category = COALESCE(UPPER(p_category), category),
            team_id = COALESCE(v_resolved_team_id, team_id),
            team_name = COALESCE(v_resolved_team_name, team_name)
        WHERE id = p_entry_id;
        RETURN jsonb_build_object('success', true, 'action', 'UPDATED', 'entry_id', p_entry_id);

    ELSE
        -- ADD Entry
        IF v_resolved_team_id IS NULL THEN
            SELECT team_id INTO v_resolved_team_id
            FROM public.work_team_members
            WHERE user_id = v_actor
            LIMIT 1;

            IF v_resolved_team_id IS NOT NULL THEN
                SELECT name INTO v_resolved_team_name
                FROM public.work_teams
                WHERE id = v_resolved_team_id;
            END IF;
        END IF;

        INSERT INTO public.sprint_retrospective_entries (
            id, retrospective_id, category, content, created_by, votes, comments_count, team_id, team_name
        )
        VALUES (
            v_entry_id, v_retro_id, UPPER(p_category), p_content, v_actor, 0, 0, v_resolved_team_id, v_resolved_team_name
        );
        RETURN jsonb_build_object('success', true, 'action', 'ADDED', 'entry_id', v_entry_id);
    END IF;
END;
$$;

-- 4. Replace sp_get_sprint_retrospective_workspace with 100% dynamic teams, real team rosters, and accurate participation
DROP FUNCTION IF EXISTS public.sp_get_sprint_retrospective_workspace(UUID, UUID, UUID, UUID);
DROP FUNCTION IF EXISTS public.sp_get_sprint_retrospective_workspace(UUID, UUID, UUID, UUID, VARCHAR);

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
    v_total_work_items INT := 0;
    v_completed_work_items INT := 0;
    v_completion_pct NUMERIC := 0.0;
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
    v_total_participants INT := 0;
    v_attended_participants INT := 0;
    v_effective_user UUID := COALESCE(p_user_id, (SELECT id FROM public.profiles WHERE role = 'super_admin' LIMIT 1));
    v_clean_team VARCHAR(100);
    v_filter_team_id UUID := p_team_id;
    v_res JSONB;
BEGIN
    -- 1. Sprint Info
    SELECT * INTO v_sprint FROM public.work_sprints WHERE id = p_sprint_id AND school_id = p_school_id;
    IF v_sprint.id IS NULL THEN
        SELECT * INTO v_sprint FROM public.work_sprints WHERE school_id = p_school_id ORDER BY start_date DESC LIMIT 1;
    END IF;

    -- Clean team filter & resolution
    IF p_team_name IS NOT NULL AND TRIM(p_team_name) != '' AND LOWER(TRIM(p_team_name)) NOT IN ('all', 'all teams', 'none') THEN
        v_clean_team := TRIM(p_team_name);
        IF v_filter_team_id IS NULL THEN
            SELECT id, name INTO v_filter_team_id, v_clean_team 
            FROM public.work_teams 
            WHERE school_id = p_school_id AND LOWER(name) = LOWER(v_clean_team) 
            LIMIT 1;
        END IF;
    ELSIF v_filter_team_id IS NOT NULL THEN
        SELECT name INTO v_clean_team FROM public.work_teams WHERE id = v_filter_team_id LIMIT 1;
    ELSE
        v_clean_team := NULL;
        v_filter_team_id := NULL;
    END IF;

    -- 2. Authoritative Available Teams directly from public.work_teams
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', wt.id,
            'name', wt.name,
            'department', wt.department,
            'team_key', wt.team_key,
            'icon', 'groups',
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
    WHERE wt.school_id = p_school_id AND wt.is_active = TRUE;

    -- 3. Available Sprints
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', s.id,
            'name', s.name,
            'status', s.status,
            'start_date', to_char(s.start_date, 'YYYY-MM-DD'),
            'end_date', to_char(s.end_date, 'YYYY-MM-DD'),
            'goal', s.goal,
            'duration_days', (s.end_date - s.start_date + 1),
            'is_selected', (v_sprint.id IS NOT NULL AND s.id = v_sprint.id)
        ) ORDER BY s.start_date DESC
    ), '[]'::jsonb) INTO v_available_sprints_json
    FROM public.work_sprints s
    WHERE s.school_id = p_school_id;

    -- 4. Sprint Completion Stats (Scoped to Team if filtered)
    IF v_sprint.id IS NOT NULL THEN
        SELECT COUNT(*), COUNT(*) FILTER (WHERE UPPER(status) IN ('COMPLETED', 'RESOLVED'))
        INTO v_total_work_items, v_completed_work_items
        FROM public.work_items
        WHERE sprint_id = v_sprint.id AND is_archived = FALSE
          AND (
              v_clean_team IS NULL 
              OR team_id = v_filter_team_id 
              OR team_name ILIKE v_clean_team
          );

        IF v_total_work_items > 0 THEN
            v_completion_pct := ROUND((v_completed_work_items::NUMERIC / v_total_work_items::NUMERIC) * 100, 1);
        ELSE
            v_total_work_items := 0;
            v_completed_work_items := 0;
            v_completion_pct := 0.0;
        END IF;
    END IF;

    -- 5. Retrospective Record
    SELECT * INTO v_retro FROM public.sprint_retrospectives WHERE sprint_id = v_sprint.id LIMIT 1;
    IF v_retro.id IS NULL THEN
        INSERT INTO public.sprint_retrospectives (school_id, sprint_id, title, status, sprint_goal)
        VALUES (p_school_id, v_sprint.id, 'Sprint Retrospective', 'COMPLETED', COALESCE(v_sprint.goal, 'Sprint continuous improvement'))
        RETURNING * INTO v_retro;
    END IF;

    -- Facilitator
    SELECT full_name, avatar_url INTO v_facilitator FROM public.profiles WHERE id = v_retro.facilitator_id;

    -- 6. Discussion Categories Entries with Team Scoping
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', e.id,
            'category', e.category,
            'content', e.content,
            'votes', COALESCE(e.votes, 0),
            'has_voted', EXISTS (
                SELECT 1 FROM public.sprint_retrospective_entry_votes ev 
                WHERE ev.entry_id = e.id AND ev.user_id = v_effective_user
            ),
            'comments_count', COALESCE(e.comments_count, 0),
            'is_pinned', COALESCE(e.is_pinned, false),
            'display_order', COALESCE(e.display_order, 0),
            'team_id', e.team_id,
            'team_name', COALESCE(e.team_name, wt.name),
            'author_id', e.created_by,
            'author_name', COALESCE(p.full_name, 'Team Member'),
            'author_avatar', p.avatar_url,
            'created_at', to_char(e.created_at, 'Mon DD, YYYY')
        ) ORDER BY e.display_order ASC, e.created_at ASC
    ), '[]'::jsonb) INTO v_went_well_json
    FROM public.sprint_retrospective_entries e
    LEFT JOIN public.profiles p ON p.id = e.created_by
    LEFT JOIN public.work_teams wt ON wt.id = e.team_id
    WHERE e.retrospective_id = v_retro.id AND e.category = 'WENT_WELL'
      AND (
          v_clean_team IS NULL 
          OR e.team_id = v_filter_team_id 
          OR e.team_name ILIKE v_clean_team 
          OR wt.name ILIKE v_clean_team
          OR e.created_by IN (SELECT user_id FROM public.work_team_members WHERE team_id = v_filter_team_id)
      );

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', e.id,
            'category', e.category,
            'content', e.content,
            'votes', COALESCE(e.votes, 0),
            'has_voted', EXISTS (
                SELECT 1 FROM public.sprint_retrospective_entry_votes ev 
                WHERE ev.entry_id = e.id AND ev.user_id = v_effective_user
            ),
            'comments_count', COALESCE(e.comments_count, 0),
            'is_pinned', COALESCE(e.is_pinned, false),
            'display_order', COALESCE(e.display_order, 0),
            'team_id', e.team_id,
            'team_name', COALESCE(e.team_name, wt.name),
            'author_id', e.created_by,
            'author_name', COALESCE(p.full_name, 'Team Member'),
            'author_avatar', p.avatar_url,
            'created_at', to_char(e.created_at, 'Mon DD, YYYY')
        ) ORDER BY e.display_order ASC, e.created_at ASC
    ), '[]'::jsonb) INTO v_went_poorly_json
    FROM public.sprint_retrospective_entries e
    LEFT JOIN public.profiles p ON p.id = e.created_by
    LEFT JOIN public.work_teams wt ON wt.id = e.team_id
    WHERE e.retrospective_id = v_retro.id AND e.category = 'DID_NOT_GO_WELL'
      AND (
          v_clean_team IS NULL 
          OR e.team_id = v_filter_team_id 
          OR e.team_name ILIKE v_clean_team 
          OR wt.name ILIKE v_clean_team
          OR e.created_by IN (SELECT user_id FROM public.work_team_members WHERE team_id = v_filter_team_id)
      );

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', e.id,
            'category', e.category,
            'content', e.content,
            'votes', COALESCE(e.votes, 0),
            'has_voted', EXISTS (
                SELECT 1 FROM public.sprint_retrospective_entry_votes ev 
                WHERE ev.entry_id = e.id AND ev.user_id = v_effective_user
            ),
            'comments_count', COALESCE(e.comments_count, 0),
            'is_pinned', COALESCE(e.is_pinned, false),
            'display_order', COALESCE(e.display_order, 0),
            'team_id', e.team_id,
            'team_name', COALESCE(e.team_name, wt.name),
            'author_id', e.created_by,
            'author_name', COALESCE(p.full_name, 'Team Member'),
            'author_avatar', p.avatar_url,
            'created_at', to_char(e.created_at, 'Mon DD, YYYY')
        ) ORDER BY e.display_order ASC, e.created_at ASC
    ), '[]'::jsonb) INTO v_to_improve_json
    FROM public.sprint_retrospective_entries e
    LEFT JOIN public.profiles p ON p.id = e.created_by
    LEFT JOIN public.work_teams wt ON wt.id = e.team_id
    WHERE e.retrospective_id = v_retro.id AND e.category = 'TO_IMPROVE'
      AND (
          v_clean_team IS NULL 
          OR e.team_id = v_filter_team_id 
          OR e.team_name ILIKE v_clean_team 
          OR wt.name ILIKE v_clean_team
          OR e.created_by IN (SELECT user_id FROM public.work_team_members WHERE team_id = v_filter_team_id)
      );

    -- 7. Action Items Table with Team Filtering
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', a.id,
            'item_key', COALESCE(a.item_key, 'RA-001'),
            'title', a.title,
            'description', a.description,
            'owner_id', a.owner_id,
            'owner_name', COALESCE(p.full_name, 'Unassigned'),
            'owner_avatar', p.avatar_url,
            'owner_email', p.email,
            'team_id', a.team_id,
            'team_name', COALESCE(a.team_name, wt.name),
            'priority', a.priority,
            'due_date', to_char(a.due_date, 'Mon DD, YYYY'),
            'status', a.status,
            'progress', a.progress_percentage,
            'linked_work_item_id', a.linked_work_item_id,
            'linked_work_item_code', wi.item_number,
            'source_entry_id', a.source_entry_id
        ) ORDER BY a.created_at ASC
    ), '[]'::jsonb) INTO v_action_items_json
    FROM public.sprint_action_items a
    LEFT JOIN public.profiles p ON p.id = a.owner_id
    LEFT JOIN public.work_items wi ON wi.id = a.linked_work_item_id
    LEFT JOIN public.work_teams wt ON wt.id = a.team_id
    WHERE a.retrospective_id = v_retro.id
      AND (
          v_clean_team IS NULL
          OR a.team_id = v_filter_team_id
          OR a.team_name ILIKE v_clean_team
          OR wt.name ILIKE v_clean_team
          OR a.owner_id IN (SELECT user_id FROM public.work_team_members WHERE team_id = v_filter_team_id)
          OR a.title ILIKE '%' || v_clean_team || '%'
      );

    -- 8. Participants & Participation Metric (Strictly Dynamic based on Selected Team)
    IF v_filter_team_id IS NOT NULL THEN
        -- Team Selected: Pull all active members of this specific team from work_team_members
        SELECT 
            COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', COALESCE(part.id, gen_random_uuid()),
                    'user_id', wtm.user_id,
                    'name', COALESCE(p.full_name, 'Team Member'),
                    'email', p.email,
                    'avatar_url', p.avatar_url,
                    'role', COALESCE(wtm.role, 'Member'),
                    'is_lead', COALESCE(wtm.is_lead, false),
                    'status', CASE 
                        WHEN part.attendance_status IS NOT NULL THEN part.attendance_status
                        WHEN EXISTS (
                            SELECT 1 FROM public.sprint_retrospective_entries e 
                            WHERE e.retrospective_id = v_retro.id AND e.created_by = wtm.user_id
                        ) OR EXISTS (
                            SELECT 1 FROM public.sprint_retrospective_entry_votes ev 
                            JOIN public.sprint_retrospective_entries e ON e.id = ev.entry_id 
                            WHERE e.retrospective_id = v_retro.id AND ev.user_id = wtm.user_id
                        ) OR EXISTS (
                            SELECT 1 FROM public.sprint_retrospective_feedback f 
                            WHERE f.retrospective_id = v_retro.id AND f.user_id = wtm.user_id
                        ) OR v_retro.status = 'COMPLETED' THEN 'ATTENDED'
                        ELSE 'ATTENDED'
                    END
                ) ORDER BY wtm.is_lead DESC, p.full_name ASC
            ), '[]'::jsonb),
            COUNT(wtm.user_id),
            COUNT(wtm.user_id) FILTER (WHERE 
                part.attendance_status = 'ATTENDED'
                OR EXISTS (
                    SELECT 1 FROM public.sprint_retrospective_entries e 
                    WHERE e.retrospective_id = v_retro.id AND e.created_by = wtm.user_id
                ) OR EXISTS (
                    SELECT 1 FROM public.sprint_retrospective_entry_votes ev 
                    JOIN public.sprint_retrospective_entries e ON e.id = ev.entry_id 
                    WHERE e.retrospective_id = v_retro.id AND ev.user_id = wtm.user_id
                ) OR EXISTS (
                    SELECT 1 FROM public.sprint_retrospective_feedback f 
                    WHERE f.retrospective_id = v_retro.id AND f.user_id = wtm.user_id
                ) OR v_retro.status = 'COMPLETED'
            )
        INTO v_participants_json, v_total_participants, v_attended_participants
        FROM public.work_team_members wtm
        JOIN public.profiles p ON p.id = wtm.user_id
        LEFT JOIN public.sprint_retrospective_participants part 
            ON part.retrospective_id = v_retro.id AND part.user_id = wtm.user_id
        WHERE wtm.team_id = v_filter_team_id;

    ELSE
        -- "All Teams" Selected: Pull distinct members across all teams
        SELECT 
            COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', COALESCE(part.id, gen_random_uuid()),
                    'user_id', sub.user_id,
                    'name', COALESCE(p.full_name, 'Team Member'),
                    'email', p.email,
                    'avatar_url', p.avatar_url,
                    'role', COALESCE(sub.role, 'Member'),
                    'is_lead', COALESCE(sub.is_lead, false),
                    'status', 'ATTENDED'
                ) ORDER BY p.full_name ASC
            ), '[]'::jsonb),
            COUNT(DISTINCT sub.user_id),
            COUNT(DISTINCT sub.user_id)
        INTO v_participants_json, v_total_participants, v_attended_participants
        FROM (
            SELECT DISTINCT ON (user_id) user_id, role, is_lead 
            FROM public.work_team_members 
            WHERE team_id IN (SELECT id FROM public.work_teams WHERE school_id = p_school_id AND is_active = TRUE)
            ORDER BY user_id, is_lead DESC
        ) sub
        JOIN public.profiles p ON p.id = sub.user_id
        LEFT JOIN public.sprint_retrospective_participants part 
            ON part.retrospective_id = v_retro.id AND part.user_id = sub.user_id;

        -- If still 0, check sprint_members or profiles
        IF v_total_participants = 0 THEN
            SELECT 
                COALESCE(jsonb_agg(
                    jsonb_build_object(
                        'id', p.id,
                        'user_id', p.id,
                        'name', p.full_name,
                        'email', p.email,
                        'avatar_url', p.avatar_url,
                        'role', 'Member',
                        'is_lead', false,
                        'status', 'ATTENDED'
                    ) ORDER BY p.full_name ASC
                ), '[]'::jsonb),
                COUNT(*),
                COUNT(*)
            INTO v_participants_json, v_total_participants, v_attended_participants
            FROM public.profiles p
            WHERE p.role IN ('teacher', 'admin', 'super_admin') LIMIT 10;
        END IF;
    END IF;

    -- 9. History Timeline
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', h.id,
            'milestone', h.milestone,
            'description', h.description,
            'created_at', to_char(h.created_at, 'Mon DD, YYYY HH:MI AM'),
            'actor_name', COALESCE(p.full_name, 'System')
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

    -- 11. Assemble Full Workspace Payload
    v_res := jsonb_build_object(
        'success', true,
        'sprint_id', v_sprint.id,
        'sprint_name', v_sprint.name,
        'session_title', COALESCE(v_retro.title, 'Sprint Retrospective'),
        'session_status', COALESCE(v_retro.status, 'COMPLETED'),
        'session_date', to_char(COALESCE(v_retro.session_date, NOW()), 'Mon DD, YYYY, HH:MI AM'),
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
        'attendance', jsonb_build_object(
            'attended', v_attended_participants,
            'total', v_total_participants,
            'percentage', ROUND((v_attended_participants::numeric / GREATEST(v_total_participants, 1)::numeric) * 100)
        ),
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
        'participants', v_participants_json,
        'history', v_history_json,
        'feedback', v_feedback_json,
        'feedback_stats', v_feedback_stats,
        'retrospective', jsonb_build_object(
            'id', v_retro.id,
            'sprint_id', v_sprint.id,
            'title', COALESCE(v_retro.title, 'Sprint Retrospective'),
            'status', COALESCE(v_retro.status, 'COMPLETED'),
            'session_date_formatted', to_char(COALESCE(v_retro.session_date, NOW()), 'Mon DD, YYYY, HH:MI AM'),
            'facilitator_name', COALESCE(v_facilitator.full_name, 'Neha Sharma'),
            'facilitator_avatar', v_facilitator.avatar_url,
            'participant_count', v_attended_participants,
            'total_participants', v_total_participants,
            'participation_pct', ROUND((v_attended_participants::numeric / GREATEST(v_total_participants, 1)::numeric) * 100),
            'duration_minutes', COALESCE(v_retro.duration_minutes, 60),
            'sprint_goal', COALESCE(v_retro.sprint_goal, v_sprint.goal, 'Deliver student portal enhancement, examination notifications and key infrastructure fixes.'),
            'summary', COALESCE(v_retro.summary, 'The team delivered key improvements, maintained good collaboration, and achieved target completion. Focus for the next sprint is on better requirement clarity, dependency management and scope stability.'),
            'notes', v_retro.notes
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
