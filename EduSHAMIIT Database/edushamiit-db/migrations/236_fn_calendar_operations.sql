-- ============================================================================
-- EduSHAMIIT ERP - Migration 236: Calendar Operations Stored Procedures
-- Moves multi-query calendar operations from FastAPI to PostgreSQL stored functions:
-- 1. fn_get_calendar_summary: Aggregates dashboard counts, categories, and invitations in 1 DB call.
-- 2. fn_cancel_schedule: Handles Google Calendar-grade single instance, following, and series cancellations.
-- 3. fn_duplicate_schedule: Atomically duplicates schedule with route, target audience, and participants.
-- 4. fn_submit_schedule_rsvp: Submits or updates participant RSVP status.
-- 5. fn_add_schedule_comment: Adds comment and returns formatted comment profile payload.
-- 6. fn_sync_vehicle_trips_for_schedule: Synchronizes vehicle trips for calendar schedules.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. fn_get_calendar_summary
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_get_calendar_summary(
    p_school_id UUID,
    p_user_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_today_count INT;
    v_week_count INT;
    v_now TIMESTAMPTZ := NOW();
    v_monday TIMESTAMPTZ := date_trunc('week', NOW());
    v_sunday TIMESTAMPTZ := v_monday + INTERVAL '6 days 23 hours 59 minutes 59 seconds';
    v_categories JSONB;
    v_assigned_to_me JSONB;
    v_pending_invitations JSONB;
    v_result JSONB;
BEGIN
    -- 1. Today's schedules count
    SELECT COUNT(*) INTO v_today_count
    FROM public.schedules
    WHERE school_id = p_school_id
      AND deleted_at IS NULL
      AND DATE(start_time) = CURRENT_DATE;

    -- 2. This week's schedules count
    SELECT COUNT(*) INTO v_week_count
    FROM public.schedules
    WHERE school_id = p_school_id
      AND deleted_at IS NULL
      AND start_time >= v_monday
      AND start_time <= v_sunday;

    -- 3. Category breakdown
    SELECT jsonb_object_agg(COALESCE(category, 'General'), count_val)
    INTO v_categories
    FROM (
        SELECT category, COUNT(*) AS count_val
        FROM public.schedules
        WHERE school_id = p_school_id AND deleted_at IS NULL
        GROUP BY category
    ) sub;

    IF v_categories IS NULL THEN
        v_categories := '{"Meetings": 0, "Tasks": 0, "Events": 0, "Reminders": 0}'::jsonb;
    END IF;

    -- 4. Assigned to me & Pending invitations
    SELECT jsonb_agg(sub.item)
    INTO v_assigned_to_me
    FROM (
        SELECT jsonb_build_object(
            'id', s.id,
            'title', s.title,
            'description', s.description,
            'schedule_type', s.schedule_type,
            'category', s.category,
            'color', s.color,
            'priority', s.priority,
            'status', s.status,
            'start_time', s.start_time,
            'end_time', s.end_time,
            'location_name', s.location_name,
            'room', s.room,
            'assigner_name', p.full_name,
            'rsvp_status', sp.rsvp_status
        ) AS item
        FROM public.schedule_participants sp
        JOIN public.schedules s ON s.id = sp.schedule_id
        LEFT JOIN public.profiles p ON p.id = s.created_by
        WHERE sp.user_id = p_user_id
          AND s.deleted_at IS NULL
          AND s.end_time >= NOW()
        ORDER BY s.start_time ASC
        LIMIT 10
    ) sub;

    IF v_assigned_to_me IS NULL THEN
        v_assigned_to_me := '[]'::jsonb;
    END IF;

    SELECT jsonb_agg(elem)
    INTO v_pending_invitations
    FROM jsonb_array_elements(v_assigned_to_me) AS elem
    WHERE elem->>'rsvp_status' = 'pending';

    IF v_pending_invitations IS NULL THEN
        v_pending_invitations := '[]'::jsonb;
    END IF;

    v_result := jsonb_build_object(
        'today_count', COALESCE(v_today_count, 0),
        'week_count', COALESCE(v_week_count, 0),
        'categories', v_categories,
        'assigned_to_me', v_assigned_to_me,
        'pending_invitations', v_pending_invitations,
        'timezone', 'Asia/Kolkata (IST)'
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ----------------------------------------------------------------------------
-- 2. fn_cancel_schedule
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_cancel_schedule(
    p_school_id UUID,
    p_user_id UUID,
    p_user_role TEXT,
    p_schedule_id UUID,
    p_cancellation_reason TEXT,
    p_recurrence_scope TEXT DEFAULT 'entire_series',
    p_target_instance_date DATE DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_sched public.schedules%ROWTYPE;
    v_parent_id UUID := p_schedule_id;
    v_clean_role TEXT;
    v_is_owner BOOLEAN;
    v_has_edit_perm BOOLEAN := FALSE;
    v_is_recurring BOOLEAN := FALSE;
    v_rec_id UUID;
    v_existing_exc JSONB;
    v_new_exc JSONB;
    v_target_date_str TEXT;
    v_ov_id UUID;
    v_inst_start TIMESTAMPTZ;
    v_inst_end TIMESTAMPTZ;
    v_duration INTERVAL;
    v_cutoff_date DATE;
    v_result JSONB;
    v_updated_record JSONB;
BEGIN
    v_clean_role := lower(replace(replace(COALESCE(p_user_role, ''), '_', ''), ' ', ''));

    SELECT * INTO v_sched
    FROM public.schedules
    WHERE id = p_schedule_id AND (school_id = p_school_id OR school_id IS NULL);

    IF v_sched.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Schedule not found');
    END IF;

    v_is_owner := (v_sched.organizer_id = p_user_id) 
               OR (v_sched.created_by = p_user_id) 
               OR (v_clean_role IN ('superadmin', 'admin', 'owner', 'principal', 'director', 'staff'));

    v_has_edit_perm := v_is_owner;
    IF NOT v_has_edit_perm THEN
        SELECT EXISTS (
            SELECT 1 FROM public.schedule_participants
            WHERE schedule_id = p_schedule_id AND user_id = p_user_id
              AND lower(permission) IN ('read_write', 'can_edit', 'can_manage')
        ) INTO v_has_edit_perm;
    END IF;

    IF NOT v_has_edit_perm THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Permission denied');
    END IF;

    -- Check recurrence
    SELECT id, COALESCE(exceptions, '[]'::jsonb)
    INTO v_rec_id, v_existing_exc
    FROM public.schedule_recurrence
    WHERE schedule_id = p_schedule_id;

    v_is_recurring := COALESCE(v_sched.is_recurring, FALSE) 
                   OR (v_sched.recurring_parent_id IS NOT NULL) 
                   OR (v_rec_id IS NOT NULL);

    -- 1. SCOPE: THIS EVENT ONLY
    IF p_recurrence_scope = 'this_event' AND p_target_instance_date IS NOT NULL AND v_is_recurring THEN
        v_target_date_str := to_char(p_target_instance_date, 'YYYY-MM-DD');

        -- Add exception date to parent recurrence
        IF v_rec_id IS NOT NULL THEN
            SELECT jsonb_agg(DISTINCT elem)
            INTO v_new_exc
            FROM (
                SELECT jsonb_array_elements_text(v_existing_exc) AS elem
                UNION
                SELECT v_target_date_str
            ) sub;

            UPDATE public.schedule_recurrence
            SET exceptions = COALESCE(v_new_exc, '[]'::jsonb), updated_at = NOW()
            WHERE id = v_rec_id;
        END IF;

        -- Check existing override record
        SELECT id INTO v_ov_id
        FROM public.schedules
        WHERE recurring_parent_id = p_schedule_id AND original_instance_date = p_target_instance_date;

        IF v_ov_id IS NOT NULL THEN
            UPDATE public.schedules
            SET status = 'cancelled',
                recurrence_exception_type = 'cancelled',
                cancellation_reason = p_cancellation_reason,
                cancelled_by = p_user_id,
                cancelled_at = NOW(),
                updated_at = NOW()
            WHERE id = v_ov_id;

            SELECT to_jsonb(s.*) INTO v_updated_record FROM public.schedules s WHERE id = v_ov_id;
        ELSE
            v_duration := v_sched.end_time - v_sched.start_time;
            v_inst_start := (p_target_instance_date::TEXT || ' ' || to_char(v_sched.start_time, 'HH24:MI:SS'))::TIMESTAMPTZ;
            v_inst_end := v_inst_start + v_duration;
            v_ov_id := gen_random_uuid();

            INSERT INTO public.schedules (
                id, school_id, calendar_id, title, description, schedule_type, category, color, priority,
                status, approval_status, start_time, end_time, is_all_day, timezone,
                location_name, location_address, building, room, landmark, latitude, longitude,
                virtual_meeting_url, virtual_meeting_provider, organizer_id, created_by, visibility,
                is_recurring, recurring_parent_id, original_instance_date, recurrence_exception_type,
                cancellation_reason, cancelled_by, cancelled_at, route_id, audience_type,
                target_roles, target_classes, target_user_ids, metadata, created_at, updated_at
            ) VALUES (
                v_ov_id, p_school_id, v_sched.calendar_id, v_sched.title, v_sched.description, v_sched.schedule_type, v_sched.category, v_sched.color, v_sched.priority,
                'cancelled', 'approved', v_inst_start, v_inst_end, v_sched.is_all_day, v_sched.timezone,
                v_sched.location_name, v_sched.location_address, v_sched.building, v_sched.room, v_sched.landmark, v_sched.latitude, v_sched.longitude,
                v_sched.virtual_meeting_url, v_sched.virtual_meeting_provider, v_sched.organizer_id, p_user_id, v_sched.visibility,
                FALSE, p_schedule_id, p_target_instance_date, 'cancelled',
                p_cancellation_reason, p_user_id, NOW(), v_sched.route_id, v_sched.audience_type,
                COALESCE(v_sched.target_roles, '[]'::jsonb), COALESCE(v_sched.target_classes, '[]'::jsonb), COALESCE(v_sched.target_user_ids, '[]'::jsonb),
                COALESCE(v_sched.metadata, '{}'::jsonb), NOW(), NOW()
            );

            SELECT to_jsonb(s.*) INTO v_updated_record FROM public.schedules s WHERE id = v_ov_id;
        END IF;

        -- Cancel specific vehicle trip
        UPDATE public.vehicle_trips
        SET status = 'cancelled', cancellation_reason = p_cancellation_reason, updated_at = NOW()
        WHERE (schedule_id = p_schedule_id OR route_id = v_sched.route_id)
          AND (schedule_instance_date = p_target_instance_date OR start_date = v_target_date_str OR scheduled_start::date = p_target_instance_date);

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Single event instance on ' || v_target_date_str || ' cancelled successfully.',
            'data', v_updated_record
        );

    -- 2. SCOPE: FOLLOWING EVENTS
    ELSIF p_recurrence_scope = 'following_events' AND p_target_instance_date IS NOT NULL AND v_is_recurring THEN
        v_cutoff_date := p_target_instance_date - INTERVAL '1 day';

        UPDATE public.schedule_recurrence
        SET end_type = 'until_date', end_date = v_cutoff_date, updated_at = NOW()
        WHERE schedule_id = p_schedule_id;

        UPDATE public.vehicle_trips
        SET status = 'cancelled', cancellation_reason = p_cancellation_reason, updated_at = NOW()
        WHERE (schedule_id = p_schedule_id OR route_id = v_sched.route_id)
          AND (schedule_instance_date >= p_target_instance_date OR scheduled_start::date >= p_target_instance_date);

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Recurring series truncated before ' || to_char(p_target_instance_date, 'YYYY-MM-DD') || '.',
            'data', to_jsonb(v_sched)
        );

    -- 3. SCOPE: ENTIRE SERIES
    ELSE
        UPDATE public.schedules
        SET status = 'cancelled', cancellation_reason = p_cancellation_reason, cancelled_by = p_user_id, cancelled_at = NOW(), updated_at = NOW()
        WHERE (id = p_schedule_id OR recurring_parent_id = p_schedule_id)
          AND (school_id = p_school_id OR school_id IS NULL);

        UPDATE public.resource_bookings
        SET status = 'cancelled'
        WHERE schedule_id = p_schedule_id OR schedule_id IN (SELECT id FROM public.schedules WHERE recurring_parent_id = p_schedule_id);

        UPDATE public.vehicle_trips
        SET status = 'cancelled', cancellation_reason = p_cancellation_reason, updated_at = NOW()
        WHERE schedule_id = p_schedule_id OR schedule_id IN (SELECT id FROM public.schedules WHERE recurring_parent_id = p_schedule_id) OR (route_id IS NOT NULL AND route_id = v_sched.route_id);

        SELECT to_jsonb(s.*) INTO v_updated_record FROM public.schedules s WHERE id = p_schedule_id;

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Entire schedule series cancelled successfully.',
            'data', v_updated_record
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ----------------------------------------------------------------------------
-- 3. fn_duplicate_schedule
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_duplicate_schedule(
    p_school_id UUID,
    p_user_id UUID,
    p_schedule_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_src public.schedules%ROWTYPE;
    v_new_id UUID := gen_random_uuid();
    v_new_title TEXT;
    v_dup_rec public.schedules%ROWTYPE;
BEGIN
    SELECT * INTO v_src
    FROM public.schedules
    WHERE id = p_schedule_id AND school_id = p_school_id;

    IF v_src.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Schedule not found');
    END IF;

    v_new_title := v_src.title || ' (Copy)';

    INSERT INTO public.schedules (
        id, school_id, calendar_id, title, description, schedule_type, category, color, priority,
        status, approval_status, start_time, end_time, is_all_day, timezone,
        location_name, location_address, building, room, landmark, latitude, longitude,
        virtual_meeting_url, virtual_meeting_provider, organizer_id, created_by, visibility,
        is_recurring, route_id, audience_type, target_roles, target_classes, target_user_ids,
        metadata, created_at, updated_at
    ) VALUES (
        v_new_id, p_school_id, v_src.calendar_id, v_new_title, v_src.description, v_src.schedule_type,
        v_src.category, v_src.color, v_src.priority, 'confirmed', 'approved',
        v_src.start_time, v_src.end_time, v_src.is_all_day, v_src.timezone,
        v_src.location_name, v_src.location_address, v_src.building, v_src.room, v_src.landmark, v_src.latitude, v_src.longitude,
        v_src.virtual_meeting_url, v_src.virtual_meeting_provider, p_user_id, p_user_id, v_src.visibility,
        FALSE, v_src.route_id, COALESCE(v_src.audience_type, 'individual'),
        COALESCE(v_src.target_roles, '[]'::jsonb), COALESCE(v_src.target_classes, '[]'::jsonb), COALESCE(v_src.target_user_ids, '[]'::jsonb),
        COALESCE(v_src.metadata, '{}'::jsonb), NOW(), NOW()
    ) RETURNING * INTO v_dup_rec;

    -- Duplicate participants
    INSERT INTO public.schedule_participants (
        id, schedule_id, user_id, target_role, target_department, target_class, target_section,
        participant_type, participation_role, permission, rsvp_status, created_at
    )
    SELECT gen_random_uuid(), v_new_id, user_id, target_role, target_department, target_class, target_section,
           participant_type, participation_role, permission, 'pending', NOW()
    FROM public.schedule_participants
    WHERE schedule_id = p_schedule_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Schedule duplicated successfully.',
        'data', to_jsonb(v_dup_rec)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ----------------------------------------------------------------------------
-- 4. fn_submit_schedule_rsvp
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_submit_schedule_rsvp(
    p_school_id UUID,
    p_user_id UUID,
    p_schedule_id UUID,
    p_status TEXT,
    p_decline_reason TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_part_id UUID;
BEGIN
    SELECT id INTO v_part_id
    FROM public.schedule_participants
    WHERE schedule_id = p_schedule_id AND user_id = p_user_id;

    IF v_part_id IS NOT NULL THEN
        UPDATE public.schedule_participants
        SET rsvp_status = p_status,
            decline_reason = p_decline_reason,
            rsvp_at = NOW()
        WHERE id = v_part_id;
    ELSE
        INSERT INTO public.schedule_participants (
            id, schedule_id, user_id, participant_type, participation_role, permission, rsvp_status, decline_reason, rsvp_at, created_at
        ) VALUES (
            gen_random_uuid(), p_schedule_id, p_user_id, 'individual', 'required', 'can_view', p_status, p_decline_reason, NOW(), NOW()
        );
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'RSVP updated successfully.'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ----------------------------------------------------------------------------
-- 5. fn_add_schedule_comment
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_add_schedule_comment(
    p_school_id UUID,
    p_user_id UUID,
    p_schedule_id UUID,
    p_comment_text TEXT
) RETURNS JSONB AS $$
DECLARE
    v_comment_id UUID := gen_random_uuid();
    v_prof_name TEXT;
    v_prof_avatar TEXT;
    v_res JSONB;
BEGIN
    SELECT full_name, avatar_url INTO v_prof_name, v_prof_avatar
    FROM public.profiles WHERE id = p_user_id;

    INSERT INTO public.schedule_comments (
        id, schedule_id, user_id, comment_text, created_at
    ) VALUES (
        v_comment_id, p_schedule_id, p_user_id, p_comment_text, NOW()
    );

    v_res := jsonb_build_object(
        'id', v_comment_id,
        'schedule_id', p_schedule_id,
        'user_id', p_user_id,
        'comment_text', p_comment_text,
        'full_name', v_prof_name,
        'avatar_url', v_prof_avatar,
        'created_at', NOW()
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Comment added successfully.',
        'data', v_res
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ----------------------------------------------------------------------------
-- 6. fn_create_schedule
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_create_schedule(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
) RETURNS JSONB AS $$
DECLARE
    v_cal_id UUID;
    v_sched_id UUID := gen_random_uuid();
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_force_override BOOLEAN;
    v_conflicts JSONB := '[]'::jsonb;
    v_res_conflict RECORD;
    v_usr_conflict RECORD;
    v_route_id UUID;
    v_aud_type TEXT := 'individual';
    v_target_roles JSONB := '[]'::jsonb;
    v_target_classes JSONB := '[]'::jsonb;
    v_target_users JSONB := '[]'::jsonb;
    v_p_elem JSONB;
    v_r_elem JSONB;
    v_rem_elem JSONB;
    v_sched_rec public.schedules%ROWTYPE;
BEGIN
    v_start_time := public.parse_tz_timestamp(p_data->>'start_time', COALESCE(p_data->>'timezone', 'Asia/Kolkata'));
    v_end_time := public.parse_tz_timestamp(p_data->>'end_time', COALESCE(p_data->>'timezone', 'Asia/Kolkata'));
    v_force_override := COALESCE((p_data->>'force_override_conflicts')::BOOLEAN, FALSE);

    -- 1. Calendar resolution
    IF p_data->>'calendar_id' IS NOT NULL AND (p_data->>'calendar_id') != '' THEN
        v_cal_id := (p_data->>'calendar_id')::UUID;
    ELSE
        SELECT id INTO v_cal_id
        FROM public.calendars
        WHERE school_id = p_school_id AND (owner_id = p_user_id OR is_default = TRUE)
        LIMIT 1;

        IF v_cal_id IS NULL THEN
            v_cal_id := gen_random_uuid();
            INSERT INTO public.calendars (id, school_id, name, color, type, is_default, owner_id, created_at)
            VALUES (v_cal_id, p_school_id, 'My Calendar', '#4F46E5', 'personal', TRUE, p_user_id, NOW());
        END IF;
    END IF;

    -- 2. Smart Conflict Detection
    IF NOT v_force_override THEN
        -- Resource collisions
        IF jsonb_array_length(COALESCE(p_data->'resources', '[]'::jsonb)) > 0 THEN
            FOR v_r_elem IN SELECT * FROM jsonb_array_elements(p_data->'resources') LOOP
                SELECT rb.*, s.title AS sched_title, cr.name AS resource_name
                INTO v_res_conflict
                FROM public.resource_bookings rb
                JOIN public.schedules s ON s.id = rb.schedule_id
                JOIN public.calendar_resources cr ON cr.id = rb.resource_id
                WHERE rb.resource_id = (v_r_elem->>'resource_id')::UUID
                  AND cr.is_exclusive = TRUE
                  AND s.deleted_at IS NULL
                  AND s.status NOT IN ('cancelled', 'declined')
                  AND s.start_time < v_end_time AND s.end_time > v_start_time
                LIMIT 1;

                IF v_res_conflict.schedule_id IS NOT NULL THEN
                    v_conflicts := v_conflicts || jsonb_build_object(
                        'type', 'resource',
                        'resource_id', v_r_elem->>'resource_id',
                        'resource_name', v_res_conflict.resource_name,
                        'conflicting_title', v_res_conflict.sched_title,
                        'start_time', v_res_conflict.start_time,
                        'end_time', v_res_conflict.end_time,
                        'message', 'Resource ''' || v_res_conflict.resource_name || ''' is already booked for ''' || v_res_conflict.sched_title || '''.'
                    );
                END IF;
            END LOOP;
        END IF;

        -- Participant collisions
        IF jsonb_array_length(COALESCE(p_data->'participants', '[]'::jsonb)) > 0 THEN
            FOR v_p_elem IN SELECT * FROM jsonb_array_elements(p_data->'participants') LOOP
                IF v_p_elem->>'user_id' IS NOT NULL THEN
                    SELECT s.title AS sched_title, s.start_time, s.end_time, prof.full_name
                    INTO v_usr_conflict
                    FROM public.schedule_participants sp
                    JOIN public.schedules s ON s.id = sp.schedule_id
                    JOIN public.profiles prof ON prof.id = sp.user_id
                    WHERE sp.user_id = (v_p_elem->>'user_id')::UUID
                      AND s.deleted_at IS NULL
                      AND s.status NOT IN ('cancelled', 'declined')
                      AND sp.rsvp_status != 'declined'
                      AND s.start_time < v_end_time AND s.end_time > v_start_time
                    LIMIT 1;

                    IF v_usr_conflict.sched_title IS NOT NULL THEN
                        v_conflicts := v_conflicts || jsonb_build_object(
                            'type', 'user',
                            'user_id', v_p_elem->>'user_id',
                            'user_name', v_usr_conflict.full_name,
                            'conflicting_title', v_usr_conflict.sched_title,
                            'start_time', v_usr_conflict.start_time,
                            'end_time', v_usr_conflict.end_time,
                            'message', 'User ''' || v_usr_conflict.full_name || ''' already has schedule ''' || v_usr_conflict.sched_title || ''' during this time.'
                        );
                    END IF;
                END IF;
            END LOOP;
        END IF;

        IF jsonb_array_length(v_conflicts) > 0 THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'error', jsonb_build_object(
                    'code', 'SCHEDULE_CONFLICT',
                    'message', 'Scheduling conflict detected. Another schedule or resource is booked during this time.',
                    'conflicts', v_conflicts
                )
            );
        END IF;
    END IF;

    -- 3. Target audience resolution
    IF jsonb_array_length(COALESCE(p_data->'participants', '[]'::jsonb)) > 0 THEN
        FOR v_p_elem IN SELECT * FROM jsonb_array_elements(p_data->'participants') LOOP
            IF v_p_elem->>'user_id' IS NOT NULL THEN
                v_target_users := v_target_users || to_jsonb(v_p_elem->>'user_id');
            END IF;
            IF v_p_elem->>'target_role' IS NOT NULL THEN
                v_target_roles := v_target_roles || to_jsonb(v_p_elem->>'target_role');
            END IF;
            IF v_p_elem->>'target_class' IS NOT NULL THEN
                v_target_classes := v_target_classes || to_jsonb(v_p_elem->>'target_class');
            END IF;
        END LOOP;
    END IF;

    IF (p_data->>'visibility') = 'institution_wide' THEN
        v_aud_type := 'institution_wide';
    ELSIF jsonb_array_length(v_target_roles) > 0 THEN
        v_aud_type := 'role';
    ELSIF jsonb_array_length(v_target_classes) > 0 THEN
        v_aud_type := 'class';
    ELSE
        v_aud_type := 'individual';
    END IF;

    IF p_data->>'route_id' IS NOT NULL AND (p_data->>'route_id') != '' THEN
        v_route_id := (p_data->>'route_id')::UUID;
    END IF;

    -- 4. Insert Schedule
    INSERT INTO public.schedules (
        id, school_id, calendar_id, route_id, title, description, schedule_type, category, color, priority,
        status, approval_status, start_time, end_time, is_all_day, timezone,
        location_name, location_address, building, room, landmark, latitude, longitude,
        virtual_meeting_url, virtual_meeting_provider, organizer_id, created_by,
        visibility, is_recurring, metadata, audience_type, target_roles, target_classes, target_user_ids, created_at, updated_at
    ) VALUES (
        v_sched_id, p_school_id, v_cal_id, v_route_id, p_data->>'title', p_data->>'description',
        COALESCE(p_data->>'schedule_type', 'Meeting'), COALESCE(p_data->>'category', 'General'),
        COALESCE(p_data->>'color', '#4F46E5'), COALESCE(p_data->>'priority', 'normal'),
        'confirmed', 'approved', v_start_time, v_end_time, COALESCE((p_data->>'is_all_day')::BOOLEAN, FALSE),
        COALESCE(p_data->>'timezone', 'Asia/Kolkata'),
        p_data->>'location_name', p_data->>'location_address', p_data->>'building', p_data->>'room', p_data->>'landmark',
        (p_data->>'latitude')::DOUBLE PRECISION, (p_data->>'longitude')::DOUBLE PRECISION,
        p_data->>'virtual_meeting_url', p_data->>'virtual_meeting_provider', p_user_id, p_user_id,
        COALESCE(p_data->>'visibility', 'shared'), COALESCE((p_data->>'is_recurring')::BOOLEAN, FALSE),
        COALESCE(p_data->'metadata', '{}'::jsonb), v_aud_type, v_target_roles, v_target_classes, v_target_users, NOW(), NOW()
    ) RETURNING * INTO v_sched_rec;

    -- 5. Insert Recurrence Rule
    IF COALESCE((p_data->>'is_recurring')::BOOLEAN, FALSE) AND p_data->'recurrence' IS NOT NULL THEN
        INSERT INTO public.schedule_recurrence (
            id, schedule_id, frequency, interval, days_of_week, day_of_month, month_of_year,
            end_type, end_count, end_date, exceptions, created_at
        ) VALUES (
            gen_random_uuid(), v_sched_id,
            p_data->'recurrence'->>'frequency',
            COALESCE((p_data->'recurrence'->>'interval')::INT, 1),
            COALESCE(p_data->'recurrence'->'days_of_week', '[]'::jsonb),
            (p_data->'recurrence'->>'day_of_month')::INT,
            (p_data->'recurrence'->>'month_of_year')::INT,
            COALESCE(p_data->'recurrence'->>'end_type', 'never'),
            (p_data->'recurrence'->>'end_count')::INT,
            (p_data->'recurrence'->>'end_date')::DATE,
            '[]'::jsonb, NOW()
        );
    END IF;

    -- 6. Insert Participants
    IF jsonb_array_length(COALESCE(p_data->'participants', '[]'::jsonb)) > 0 THEN
        FOR v_p_elem IN SELECT * FROM jsonb_array_elements(p_data->'participants') LOOP
            INSERT INTO public.schedule_participants (
                id, schedule_id, user_id, target_role, target_department, target_class, target_section,
                participant_type, participation_role, permission, rsvp_status, created_at
            ) VALUES (
                gen_random_uuid(), v_sched_id,
                CASE WHEN v_p_elem->>'user_id' IS NOT NULL THEN (v_p_elem->>'user_id')::UUID ELSE NULL END,
                v_p_elem->>'target_role', v_p_elem->>'target_department', v_p_elem->>'target_class', v_p_elem->>'target_section',
                COALESCE(v_p_elem->>'participant_type', CASE WHEN v_p_elem->>'user_id' IS NOT NULL THEN 'individual' ELSE 'role' END),
                COALESCE(v_p_elem->>'participation_role', 'required'),
                COALESCE(v_p_elem->>'permission', 'can_view'),
                'pending', NOW()
            );
        END LOOP;
    END IF;

    -- 7. Insert Resource Bookings
    IF jsonb_array_length(COALESCE(p_data->'resources', '[]'::jsonb)) > 0 THEN
        FOR v_r_elem IN SELECT * FROM jsonb_array_elements(p_data->'resources') LOOP
            INSERT INTO public.resource_bookings (
                id, schedule_id, resource_id, start_time, end_time, status, created_at
            ) VALUES (
                gen_random_uuid(), v_sched_id, (v_r_elem->>'resource_id')::UUID, v_start_time, v_end_time, 'confirmed', NOW()
            );
        END LOOP;
    END IF;

    -- 8. Insert Reminders
    IF jsonb_array_length(COALESCE(p_data->'reminders', '[]'::jsonb)) > 0 THEN
        FOR v_rem_elem IN SELECT * FROM jsonb_array_elements(p_data->'reminders') LOOP
            INSERT INTO public.schedule_reminders (
                id, schedule_id, user_id, minutes_before, channel, is_sent, created_at
            ) VALUES (
                gen_random_uuid(), v_sched_id, p_user_id, COALESCE((v_rem_elem->>'minutes_before')::INT, 15),
                COALESCE(v_rem_elem->>'channel', 'in_app'), FALSE, NOW()
            );
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Schedule created successfully.',
        'data', to_jsonb(v_sched_rec)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ----------------------------------------------------------------------------
-- 0. Helper: parse_tz_timestamp
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.parse_tz_timestamp(p_str TEXT, p_tz TEXT DEFAULT 'Asia/Kolkata')
RETURNS TIMESTAMPTZ AS $$
BEGIN
    IF p_str IS NULL OR p_str = '' THEN
        RETURN NULL;
    END IF;
    IF p_str ~ '([Zz]|\+\d{2}:?\d{2}|-\d{2}:?\d{2})$' THEN
        RETURN p_str::TIMESTAMPTZ;
    ELSE
        RETURN (p_str::TIMESTAMP AT TIME ZONE COALESCE(NULLIF(p_tz, ''), 'Asia/Kolkata'));
    END IF;
EXCEPTION WHEN OTHERS THEN
    RETURN p_str::TIMESTAMPTZ;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- ----------------------------------------------------------------------------
-- 7. fn_update_schedule
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_update_schedule(
    p_school_id UUID,
    p_user_id UUID,
    p_user_role TEXT,
    p_schedule_id UUID,
    p_recurrence_scope TEXT DEFAULT 'entire_series',
    p_target_instance_date DATE DEFAULT NULL,
    p_data JSONB DEFAULT '{}'::jsonb
) RETURNS JSONB AS $$
DECLARE
    v_old public.schedules%ROWTYPE;
    v_master_parent_id UUID;
    v_is_already_override BOOLEAN;
    v_clean_role TEXT;
    v_is_owner BOOLEAN;
    v_has_edit_perm BOOLEAN := FALSE;
    v_tz TEXT;
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_duration INTERVAL;
    v_new_start TIMESTAMPTZ;
    v_new_end TIMESTAMPTZ;
    v_updated public.schedules%ROWTYPE;
    v_ov_id UUID := gen_random_uuid();
    v_p_elem JSONB;
    v_r_elem JSONB;
    v_rem_elem JSONB;
    v_target_roles JSONB := '[]'::jsonb;
    v_target_classes JSONB := '[]'::jsonb;
    v_target_users JSONB := '[]'::jsonb;
    v_aud_type TEXT;
    v_rec_id UUID;
BEGIN
    v_clean_role := lower(replace(replace(COALESCE(p_user_role, ''), '_', ''), ' ', ''));

    SELECT * INTO v_old
    FROM public.schedules
    WHERE id = p_schedule_id AND (school_id = p_school_id OR school_id IS NULL);

    IF v_old.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Schedule not found');
    END IF;

    v_tz := COALESCE(p_data->>'timezone', v_old.timezone, 'Asia/Kolkata');
    v_master_parent_id := COALESCE(v_old.recurring_parent_id, v_old.id);
    v_is_already_override := (v_old.recurring_parent_id IS NOT NULL) OR (v_old.recurrence_exception_type = 'override');

    v_is_owner := (v_old.organizer_id = p_user_id)
               OR (v_old.created_by = p_user_id)
               OR (v_clean_role IN ('superadmin', 'admin', 'owner', 'principal', 'director', 'staff'));

    v_has_edit_perm := v_is_owner;
    IF NOT v_has_edit_perm THEN
        SELECT EXISTS (
            SELECT 1 FROM public.schedule_participants
            WHERE schedule_id = p_schedule_id AND user_id = p_user_id
              AND lower(permission) IN ('read_write', 'can_edit', 'can_manage')
        ) INTO v_has_edit_perm;
    END IF;

    IF NOT v_has_edit_perm THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Permission denied');
    END IF;

    -- Audience & Target Array Resolution from Participants
    IF jsonb_array_length(COALESCE(p_data->'participants', '[]'::jsonb)) > 0 THEN
        FOR v_p_elem IN SELECT * FROM jsonb_array_elements(p_data->'participants') LOOP
            IF v_p_elem->>'user_id' IS NOT NULL AND v_p_elem->>'user_id' != '' THEN
                v_target_users := v_target_users || to_jsonb(v_p_elem->>'user_id');
            END IF;
            IF v_p_elem->>'target_role' IS NOT NULL AND v_p_elem->>'target_role' != '' THEN
                v_target_roles := v_target_roles || to_jsonb(v_p_elem->>'target_role');
            END IF;
            IF v_p_elem->>'target_class' IS NOT NULL AND v_p_elem->>'target_class' != '' THEN
                v_target_classes := v_target_classes || to_jsonb(v_p_elem->>'target_class');
            END IF;
        END LOOP;
    ELSE
        v_target_roles := COALESCE(v_old.target_roles, '[]'::jsonb);
        v_target_classes := COALESCE(v_old.target_classes, '[]'::jsonb);
        v_target_users := COALESCE(v_old.target_user_ids, '[]'::jsonb);
    END IF;

    IF (p_data->>'visibility') = 'institution_wide' THEN
        v_aud_type := 'institution_wide';
    ELSIF jsonb_array_length(v_target_roles) > 0 THEN
        v_aud_type := 'role';
    ELSIF jsonb_array_length(v_target_classes) > 0 THEN
        v_aud_type := 'class';
    ELSE
        v_aud_type := COALESCE(v_old.audience_type, 'individual');
    END IF;

    -- 1. ALREADY OVERRIDE OR STANDALONE
    IF v_is_already_override THEN
        v_start_time := CASE WHEN p_data->>'start_time' IS NOT NULL AND p_data->>'start_time' != '' THEN public.parse_tz_timestamp(p_data->>'start_time', v_tz) ELSE v_old.start_time END;
        v_end_time := CASE WHEN p_data->>'end_time' IS NOT NULL AND p_data->>'end_time' != '' THEN public.parse_tz_timestamp(p_data->>'end_time', v_tz) ELSE v_old.end_time END;

        UPDATE public.schedules
        SET calendar_id = CASE WHEN p_data->>'calendar_id' IS NOT NULL AND p_data->>'calendar_id' != '' THEN (p_data->>'calendar_id')::UUID ELSE calendar_id END,
            title = COALESCE(p_data->>'title', title),
            description = COALESCE(p_data->>'description', description),
            schedule_type = COALESCE(p_data->>'schedule_type', schedule_type),
            category = COALESCE(p_data->>'category', category),
            color = COALESCE(p_data->>'color', color),
            priority = COALESCE(p_data->>'priority', priority),
            status = COALESCE(p_data->>'status', status),
            start_time = v_start_time,
            end_time = v_end_time,
            is_all_day = COALESCE((p_data->>'is_all_day')::BOOLEAN, is_all_day),
            timezone = v_tz,
            location_name = COALESCE(p_data->>'location_name', location_name),
            location_address = COALESCE(p_data->>'location_address', location_address),
            building = COALESCE(p_data->>'building', building),
            room = COALESCE(p_data->>'room', room),
            virtual_meeting_url = COALESCE(p_data->>'virtual_meeting_url', virtual_meeting_url),
            virtual_meeting_provider = COALESCE(p_data->>'virtual_meeting_provider', virtual_meeting_provider),
            visibility = COALESCE(p_data->>'visibility', visibility),
            is_recurring = COALESCE((p_data->>'is_recurring')::BOOLEAN, is_recurring),
            route_id = CASE WHEN p_data->>'route_id' IS NOT NULL AND p_data->>'route_id' != '' THEN (p_data->>'route_id')::UUID ELSE route_id END,
            metadata = COALESCE(p_data->'metadata', metadata),
            audience_type = v_aud_type,
            target_roles = v_target_roles,
            target_classes = v_target_classes,
            target_user_ids = v_target_users,
            updated_at = NOW()
        WHERE id = p_schedule_id
        RETURNING * INTO v_updated;

        -- Update participants if provided
        IF jsonb_array_length(COALESCE(p_data->'participants', '[]'::jsonb)) > 0 THEN
            DELETE FROM public.schedule_participants WHERE schedule_id = p_schedule_id;
            FOR v_p_elem IN SELECT * FROM jsonb_array_elements(p_data->'participants') LOOP
                INSERT INTO public.schedule_participants (
                    id, schedule_id, user_id, target_role, target_department, target_class, target_section,
                    participant_type, participation_role, permission, rsvp_status, created_at
                ) VALUES (
                    gen_random_uuid(), p_schedule_id,
                    CASE WHEN v_p_elem->>'user_id' IS NOT NULL AND v_p_elem->>'user_id' != '' THEN (v_p_elem->>'user_id')::UUID ELSE NULL END,
                    v_p_elem->>'target_role', v_p_elem->>'target_department', v_p_elem->>'target_class', v_p_elem->>'target_section',
                    COALESCE(v_p_elem->>'participant_type', 'individual'),
                    COALESCE(v_p_elem->>'participation_role', 'required'),
                    COALESCE(v_p_elem->>'permission', 'can_view'),
                    'pending', NOW()
                );
            END LOOP;
        END IF;

        -- Update resource bookings if provided
        IF p_data->'resources' IS NOT NULL AND jsonb_array_length(p_data->'resources') >= 0 THEN
            DELETE FROM public.resource_bookings WHERE schedule_id = p_schedule_id;
            IF jsonb_array_length(p_data->'resources') > 0 THEN
                FOR v_r_elem IN SELECT * FROM jsonb_array_elements(p_data->'resources') LOOP
                    IF v_r_elem->>'resource_id' IS NOT NULL AND v_r_elem->>'resource_id' != '' THEN
                        INSERT INTO public.resource_bookings (
                            id, schedule_id, resource_id, start_time, end_time, status, created_at
                        ) VALUES (
                            gen_random_uuid(), p_schedule_id, (v_r_elem->>'resource_id')::UUID, v_start_time, v_end_time, 'confirmed', NOW()
                        );
                    END IF;
                END LOOP;
            END IF;
        END IF;

        -- Update reminders if provided
        IF p_data->'reminders' IS NOT NULL AND jsonb_array_length(p_data->'reminders') >= 0 THEN
            DELETE FROM public.schedule_reminders WHERE schedule_id = p_schedule_id;
            IF jsonb_array_length(p_data->'reminders') > 0 THEN
                FOR v_rem_elem IN SELECT * FROM jsonb_array_elements(p_data->'reminders') LOOP
                    INSERT INTO public.schedule_reminders (
                        id, schedule_id, user_id, minutes_before, channel, is_sent, created_at
                    ) VALUES (
                        gen_random_uuid(), p_schedule_id, p_user_id, COALESCE((v_rem_elem->>'minutes_before')::INT, 15),
                        COALESCE(v_rem_elem->>'channel', 'in_app'), FALSE, NOW()
                    );
                END LOOP;
            END IF;
        END IF;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Schedule updated successfully.', 'data', to_jsonb(v_updated));

    -- 2. SCOPE: THIS EVENT ONLY
    ELSIF p_recurrence_scope = 'this_event' AND p_target_instance_date IS NOT NULL THEN
        PERFORM public.exclude_recurring_occurrence(v_master_parent_id, p_target_instance_date);

        -- Delete duplicate override for this date if present
        UPDATE public.schedules
        SET deleted_at = NOW(), status = 'cancelled', updated_at = NOW()
        WHERE recurring_parent_id = v_master_parent_id
          AND (original_instance_date = p_target_instance_date OR DATE(start_time) = p_target_instance_date);

        v_duration := COALESCE(v_old.end_time - v_old.start_time, INTERVAL '1 hour');

        IF p_data->>'start_time' IS NOT NULL AND p_data->>'start_time' != '' THEN
            v_new_start := public.parse_tz_timestamp(p_data->>'start_time', v_tz);
        ELSE
            v_new_start := (p_target_instance_date::TEXT || ' ' || to_char((v_old.start_time AT TIME ZONE v_tz)::TIME, 'HH24:MI:SS'))::TIMESTAMP AT TIME ZONE v_tz;
        END IF;

        IF p_data->>'end_time' IS NOT NULL AND p_data->>'end_time' != '' THEN
            v_new_end := public.parse_tz_timestamp(p_data->>'end_time', v_tz);
        ELSE
            v_new_end := v_new_start + v_duration;
        END IF;

        INSERT INTO public.schedules (
            id, school_id, calendar_id, route_id, title, description, schedule_type, category, color, priority,
            status, approval_status, start_time, end_time, is_all_day, timezone,
            location_name, location_address, building, room, virtual_meeting_url, virtual_meeting_provider,
            organizer_id, created_by, visibility, is_recurring, recurring_parent_id, original_instance_date,
            recurrence_exception_type, metadata, audience_type, target_roles, target_classes, target_user_ids, created_at, updated_at
        ) VALUES (
            v_ov_id, p_school_id, COALESCE((p_data->>'calendar_id')::UUID, v_old.calendar_id),
            CASE WHEN p_data->>'route_id' IS NOT NULL AND p_data->>'route_id' != '' THEN (p_data->>'route_id')::UUID ELSE v_old.route_id END,
            COALESCE(p_data->>'title', v_old.title), COALESCE(p_data->>'description', v_old.description),
            COALESCE(p_data->>'schedule_type', v_old.schedule_type), COALESCE(p_data->>'category', v_old.category),
            COALESCE(p_data->>'color', v_old.color), COALESCE(p_data->>'priority', v_old.priority),
            'scheduled', 'approved', v_new_start, v_new_end, COALESCE((p_data->>'is_all_day')::BOOLEAN, v_old.is_all_day),
            v_tz, COALESCE(p_data->>'location_name', v_old.location_name),
            COALESCE(p_data->>'location_address', v_old.location_address), COALESCE(p_data->>'building', v_old.building),
            COALESCE(p_data->>'room', v_old.room), COALESCE(p_data->>'virtual_meeting_url', v_old.virtual_meeting_url),
            COALESCE(p_data->>'virtual_meeting_provider', v_old.virtual_meeting_provider),
            v_old.organizer_id, p_user_id, COALESCE(p_data->>'visibility', v_old.visibility),
            FALSE, v_master_parent_id, p_target_instance_date, 'override',
            COALESCE(p_data->'metadata', v_old.metadata), v_aud_type, v_target_roles, v_target_classes, v_target_users, NOW(), NOW()
        ) RETURNING * INTO v_updated;

        -- Insert participants for this occurrence override
        IF jsonb_array_length(COALESCE(p_data->'participants', '[]'::jsonb)) > 0 THEN
            FOR v_p_elem IN SELECT * FROM jsonb_array_elements(p_data->'participants') LOOP
                INSERT INTO public.schedule_participants (
                    id, schedule_id, user_id, target_role, target_department, target_class, target_section,
                    participant_type, participation_role, permission, rsvp_status, created_at
                ) VALUES (
                    gen_random_uuid(), v_ov_id,
                    CASE WHEN v_p_elem->>'user_id' IS NOT NULL AND v_p_elem->>'user_id' != '' THEN (v_p_elem->>'user_id')::UUID ELSE NULL END,
                    v_p_elem->>'target_role', v_p_elem->>'target_department', v_p_elem->>'target_class', v_p_elem->>'target_section',
                    COALESCE(v_p_elem->>'participant_type', 'individual'),
                    COALESCE(v_p_elem->>'participation_role', 'required'),
                    COALESCE(v_p_elem->>'permission', 'can_view'),
                    'pending', NOW()
                );
            END LOOP;
        END IF;

        -- Insert resource bookings for occurrence override
        IF jsonb_array_length(COALESCE(p_data->'resources', '[]'::jsonb)) > 0 THEN
            FOR v_r_elem IN SELECT * FROM jsonb_array_elements(p_data->'resources') LOOP
                IF v_r_elem->>'resource_id' IS NOT NULL AND v_r_elem->>'resource_id' != '' THEN
                    INSERT INTO public.resource_bookings (
                        id, schedule_id, resource_id, start_time, end_time, status, created_at
                    ) VALUES (
                        gen_random_uuid(), v_ov_id, (v_r_elem->>'resource_id')::UUID, v_new_start, v_new_end, 'confirmed', NOW()
                    );
                END IF;
            END LOOP;
        END IF;

        -- Insert reminders for occurrence override
        IF jsonb_array_length(COALESCE(p_data->'reminders', '[]'::jsonb)) > 0 THEN
            FOR v_rem_elem IN SELECT * FROM jsonb_array_elements(p_data->'reminders') LOOP
                INSERT INTO public.schedule_reminders (
                    id, schedule_id, user_id, minutes_before, channel, is_sent, created_at
                ) VALUES (
                    gen_random_uuid(), v_ov_id, p_user_id, COALESCE((v_rem_elem->>'minutes_before')::INT, 15),
                    COALESCE(v_rem_elem->>'channel', 'in_app'), FALSE, NOW()
                );
            END LOOP;
        END IF;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Updated this event occurrence successfully.', 'data', to_jsonb(v_updated));

    -- 3. SCOPE: ENTIRE SERIES (DEFAULT)
    ELSE
        IF p_target_instance_date IS NOT NULL AND p_data->>'start_time' IS NOT NULL AND p_data->>'start_time' != '' THEN
            v_start_time := public.parse_tz_timestamp(p_data->>'start_time', v_tz);
            v_new_start := (((v_old.start_time AT TIME ZONE v_tz)::DATE)::TEXT || ' ' || to_char((v_start_time AT TIME ZONE v_tz)::TIME, 'HH24:MI:SS'))::TIMESTAMP AT TIME ZONE v_tz;
            IF p_data->>'end_time' IS NOT NULL AND p_data->>'end_time' != '' THEN
                v_end_time := public.parse_tz_timestamp(p_data->>'end_time', v_tz);
                v_new_end := (((v_old.end_time AT TIME ZONE v_tz)::DATE)::TEXT || ' ' || to_char((v_end_time AT TIME ZONE v_tz)::TIME, 'HH24:MI:SS'))::TIMESTAMP AT TIME ZONE v_tz;
            ELSE
                v_new_end := v_new_start + COALESCE(v_old.end_time - v_old.start_time, INTERVAL '1 hour');
            END IF;
        ELSE
            v_new_start := CASE WHEN p_data->>'start_time' IS NOT NULL AND p_data->>'start_time' != '' THEN public.parse_tz_timestamp(p_data->>'start_time', v_tz) ELSE v_old.start_time END;
            v_new_end := CASE WHEN p_data->>'end_time' IS NOT NULL AND p_data->>'end_time' != '' THEN public.parse_tz_timestamp(p_data->>'end_time', v_tz) ELSE v_old.end_time END;
        END IF;

        UPDATE public.schedules
        SET calendar_id = CASE WHEN p_data->>'calendar_id' IS NOT NULL AND p_data->>'calendar_id' != '' THEN (p_data->>'calendar_id')::UUID ELSE calendar_id END,
            title = COALESCE(p_data->>'title', title),
            description = COALESCE(p_data->>'description', description),
            schedule_type = COALESCE(p_data->>'schedule_type', schedule_type),
            category = COALESCE(p_data->>'category', category),
            color = COALESCE(p_data->>'color', color),
            priority = COALESCE(p_data->>'priority', priority),
            status = COALESCE(p_data->>'status', status),
            start_time = v_new_start,
            end_time = v_new_end,
            is_all_day = COALESCE((p_data->>'is_all_day')::BOOLEAN, is_all_day),
            timezone = v_tz,
            location_name = COALESCE(p_data->>'location_name', location_name),
            location_address = COALESCE(p_data->>'location_address', location_address),
            building = COALESCE(p_data->>'building', building),
            room = COALESCE(p_data->>'room', room),
            virtual_meeting_url = COALESCE(p_data->>'virtual_meeting_url', virtual_meeting_url),
            virtual_meeting_provider = COALESCE(p_data->>'virtual_meeting_provider', virtual_meeting_provider),
            visibility = COALESCE(p_data->>'visibility', visibility),
            is_recurring = COALESCE((p_data->>'is_recurring')::BOOLEAN, is_recurring),
            route_id = CASE WHEN p_data->>'route_id' IS NOT NULL AND p_data->>'route_id' != '' THEN (p_data->>'route_id')::UUID ELSE route_id END,
            metadata = COALESCE(p_data->'metadata', metadata),
            audience_type = v_aud_type,
            target_roles = v_target_roles,
            target_classes = v_target_classes,
            target_user_ids = v_target_users,
            updated_at = NOW()
        WHERE id = v_master_parent_id
        RETURNING * INTO v_updated;

        -- Update recurrence rules if provided
        IF p_data->'recurrence' IS NOT NULL THEN
            SELECT id INTO v_rec_id FROM public.schedule_recurrence WHERE schedule_id = v_master_parent_id LIMIT 1;
            IF v_rec_id IS NOT NULL THEN
                UPDATE public.schedule_recurrence
                SET frequency = COALESCE(p_data->'recurrence'->>'frequency', frequency),
                    interval = COALESCE((p_data->'recurrence'->>'interval')::INT, interval),
                    days_of_week = COALESCE(p_data->'recurrence'->'days_of_week', days_of_week),
                    day_of_month = (p_data->'recurrence'->>'day_of_month')::INT,
                    month_of_year = (p_data->'recurrence'->>'month_of_year')::INT,
                    end_type = COALESCE(p_data->'recurrence'->>'end_type', end_type),
                    end_count = (p_data->'recurrence'->>'end_count')::INT,
                    end_date = (p_data->'recurrence'->>'end_date')::DATE,
                    updated_at = NOW()
                WHERE id = v_rec_id;
            ELSE
                INSERT INTO public.schedule_recurrence (
                    id, schedule_id, frequency, interval, days_of_week, day_of_month, month_of_year,
                    end_type, end_count, end_date, exceptions, created_at
                ) VALUES (
                    gen_random_uuid(), v_master_parent_id,
                    COALESCE(p_data->'recurrence'->>'frequency', 'daily'),
                    COALESCE((p_data->'recurrence'->>'interval')::INT, 1),
                    COALESCE(p_data->'recurrence'->'days_of_week', '[]'::jsonb),
                    (p_data->'recurrence'->>'day_of_month')::INT,
                    (p_data->'recurrence'->>'month_of_year')::INT,
                    COALESCE(p_data->'recurrence'->>'end_type', 'never'),
                    (p_data->'recurrence'->>'end_count')::INT,
                    (p_data->'recurrence'->>'end_date')::DATE,
                    '[]'::jsonb, NOW()
                );
            END IF;
        END IF;

        -- Update participants if provided
        IF jsonb_array_length(COALESCE(p_data->'participants', '[]'::jsonb)) > 0 THEN
            DELETE FROM public.schedule_participants WHERE schedule_id = v_master_parent_id;
            FOR v_p_elem IN SELECT * FROM jsonb_array_elements(p_data->'participants') LOOP
                INSERT INTO public.schedule_participants (
                    id, schedule_id, user_id, target_role, target_department, target_class, target_section,
                    participant_type, participation_role, permission, rsvp_status, created_at
                ) VALUES (
                    gen_random_uuid(), v_master_parent_id,
                    CASE WHEN v_p_elem->>'user_id' IS NOT NULL AND v_p_elem->>'user_id' != '' THEN (v_p_elem->>'user_id')::UUID ELSE NULL END,
                    v_p_elem->>'target_role', v_p_elem->>'target_department', v_p_elem->>'target_class', v_p_elem->>'target_section',
                    COALESCE(v_p_elem->>'participant_type', 'individual'),
                    COALESCE(v_p_elem->>'participation_role', 'required'),
                    COALESCE(v_p_elem->>'permission', 'can_view'),
                    'pending', NOW()
                );
            END LOOP;
        END IF;

        -- Update resource bookings if provided
        IF p_data->'resources' IS NOT NULL AND jsonb_array_length(p_data->'resources') >= 0 THEN
            DELETE FROM public.resource_bookings WHERE schedule_id = v_master_parent_id;
            IF jsonb_array_length(p_data->'resources') > 0 THEN
                FOR v_r_elem IN SELECT * FROM jsonb_array_elements(p_data->'resources') LOOP
                    IF v_r_elem->>'resource_id' IS NOT NULL AND v_r_elem->>'resource_id' != '' THEN
                        INSERT INTO public.resource_bookings (
                            id, schedule_id, resource_id, start_time, end_time, status, created_at
                        ) VALUES (
                            gen_random_uuid(), v_master_parent_id, (v_r_elem->>'resource_id')::UUID, v_new_start, v_new_end, 'confirmed', NOW()
                        );
                    END IF;
                END LOOP;
            END IF;
        END IF;

        -- Update reminders if provided
        IF p_data->'reminders' IS NOT NULL AND jsonb_array_length(p_data->'reminders') >= 0 THEN
            DELETE FROM public.schedule_reminders WHERE schedule_id = v_master_parent_id;
            IF jsonb_array_length(p_data->'reminders') > 0 THEN
                FOR v_rem_elem IN SELECT * FROM jsonb_array_elements(p_data->'reminders') LOOP
                    INSERT INTO public.schedule_reminders (
                        id, schedule_id, user_id, minutes_before, channel, is_sent, created_at
                    ) VALUES (
                        gen_random_uuid(), v_master_parent_id, p_user_id, COALESCE((v_rem_elem->>'minutes_before')::INT, 15),
                        COALESCE(v_rem_elem->>'channel', 'in_app'), FALSE, NOW()
                    );
                END LOOP;
            END IF;
        END IF;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Entire schedule series updated successfully.', 'data', to_jsonb(v_updated));
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
