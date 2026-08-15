-- ============================================================================
-- Migration: 254_fix_fn_cancel_schedule_timezone_and_scopes.sql
-- Description:
--   1. Fixes timezone offset in fn_cancel_schedule so single instance cancellation
--      calculates the exact wall-clock start/end timestamp in the schedule's timezone.
--   2. Correctly updates or inserts the cancelled override row on the target date.
--   3. Synchronizes vehicle_trips status and cancellations.
-- ============================================================================

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
    v_parent_id UUID;
    v_clean_role TEXT;
    v_is_owner BOOLEAN;
    v_has_edit_perm BOOLEAN := FALSE;
    v_is_recurring BOOLEAN := FALSE;
    v_rec_id UUID;
    v_target_date_str TEXT;
    v_ov_id UUID;
    v_inst_start TIMESTAMPTZ;
    v_inst_end TIMESTAMPTZ;
    v_duration INTERVAL;
    v_cutoff_date DATE;
    v_updated_record JSONB;
    v_tz TEXT;
BEGIN
    v_clean_role := lower(replace(replace(COALESCE(p_user_role, ''), '_', ''), ' ', ''));

    SELECT * INTO v_sched
    FROM public.schedules
    WHERE id = p_schedule_id AND (school_id = p_school_id OR school_id IS NULL) AND deleted_at IS NULL;

    IF v_sched.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Schedule not found or deleted');
    END IF;

    v_tz := COALESCE(v_sched.timezone, 'Asia/Kolkata');
    v_parent_id := COALESCE(v_sched.recurring_parent_id, v_sched.id);

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
    SELECT id INTO v_rec_id
    FROM public.schedule_recurrence
    WHERE schedule_id = v_parent_id OR schedule_id = p_schedule_id;

    v_is_recurring := COALESCE(v_sched.is_recurring, FALSE) 
                   OR (v_sched.recurring_parent_id IS NOT NULL) 
                   OR (v_rec_id IS NOT NULL);

    -- ========================================================================
    -- 1. SCOPE: THIS EVENT ONLY
    -- ========================================================================
    IF p_recurrence_scope = 'this_event' AND p_target_instance_date IS NOT NULL AND v_is_recurring THEN
        v_target_date_str := to_char(p_target_instance_date, 'YYYY-MM-DD');
        v_duration := COALESCE(v_sched.end_time - v_sched.start_time, INTERVAL '1 hour');

        -- Compute local start and end in local timezone, then convert to timestamptz
        v_inst_start := (p_target_instance_date::TEXT || ' ' || to_char((v_sched.start_time AT TIME ZONE v_tz)::TIME, 'HH24:MI:SS'))::TIMESTAMP AT TIME ZONE v_tz;
        v_inst_end := v_inst_start + v_duration;

        -- Add exception date to parent recurrence(s)
        PERFORM public.exclude_recurring_occurrence(v_parent_id, p_target_instance_date);
        IF p_schedule_id != v_parent_id THEN
            PERFORM public.exclude_recurring_occurrence(p_schedule_id, p_target_instance_date);
        END IF;

        UPDATE public.schedules SET is_recurring = TRUE WHERE id = v_parent_id;

        -- Check existing override record
        SELECT id INTO v_ov_id
        FROM public.schedules
        WHERE (recurring_parent_id = v_parent_id OR recurring_parent_id = p_schedule_id OR id = p_schedule_id)
          AND (original_instance_date = p_target_instance_date OR DATE(start_time AT TIME ZONE v_tz) = p_target_instance_date)
          AND (recurrence_exception_type = 'override' OR recurrence_exception_type = 'cancelled' OR is_recurring = FALSE)
          AND deleted_at IS NULL
        LIMIT 1;

        IF v_ov_id IS NOT NULL THEN
            UPDATE public.schedules
            SET status = 'cancelled',
                start_time = v_inst_start,
                end_time = v_inst_end,
                recurrence_exception_type = 'cancelled',
                cancellation_reason = p_cancellation_reason,
                cancelled_by = p_user_id,
                cancelled_at = NOW(),
                updated_at = NOW()
            WHERE id = v_ov_id;

            SELECT to_jsonb(s.*) INTO v_updated_record FROM public.schedules s WHERE id = v_ov_id;
        ELSE
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
                'cancelled', 'approved', v_inst_start, v_inst_end, v_sched.is_all_day, v_tz,
                v_sched.location_name, v_sched.location_address, v_sched.building, v_sched.room, v_sched.landmark, v_sched.latitude, v_sched.longitude,
                v_sched.virtual_meeting_url, v_sched.virtual_meeting_provider, v_sched.organizer_id, p_user_id, v_sched.visibility,
                FALSE, v_parent_id, p_target_instance_date, 'cancelled',
                p_cancellation_reason, p_user_id, NOW(), v_sched.route_id, v_sched.audience_type,
                COALESCE(v_sched.target_roles, '[]'::jsonb), COALESCE(v_sched.target_classes, '[]'::jsonb), COALESCE(v_sched.target_user_ids, '[]'::jsonb),
                COALESCE(v_sched.metadata, '{}'::jsonb), NOW(), NOW()
            );

            SELECT to_jsonb(s.*) INTO v_updated_record FROM public.schedules s WHERE id = v_ov_id;
        END IF;

        -- Cancel specific vehicle trip
        UPDATE public.vehicle_trips
        SET status = 'cancelled', cancellation_reason = p_cancellation_reason, updated_at = NOW()
        WHERE (schedule_id = v_parent_id OR schedule_id = p_schedule_id OR schedule_id = v_ov_id OR route_id = v_sched.route_id)
          AND (schedule_instance_date = p_target_instance_date OR start_date = v_target_date_str OR DATE(scheduled_start AT TIME ZONE v_tz) = p_target_instance_date);

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Single event instance on ' || v_target_date_str || ' cancelled successfully.',
            'data', v_updated_record
        );

    -- ========================================================================
    -- 2. SCOPE: FOLLOWING EVENTS
    -- ========================================================================
    ELSIF p_recurrence_scope IN ('this_and_following', 'following_events') AND p_target_instance_date IS NOT NULL AND v_is_recurring THEN
        v_cutoff_date := p_target_instance_date - INTERVAL '1 day';

        UPDATE public.schedule_recurrence
        SET end_type = 'until_date', end_date = v_cutoff_date, updated_at = NOW()
        WHERE schedule_id = v_parent_id OR schedule_id = p_schedule_id;

        -- Mark any existing child overrides from target date onwards as cancelled
        UPDATE public.schedules
        SET status = 'cancelled', cancellation_reason = p_cancellation_reason, cancelled_by = p_user_id, cancelled_at = NOW(), updated_at = NOW()
        WHERE (recurring_parent_id = v_parent_id OR recurring_parent_id = p_schedule_id)
          AND (original_instance_date >= p_target_instance_date OR DATE(start_time AT TIME ZONE v_tz) >= p_target_instance_date);

        UPDATE public.vehicle_trips
        SET status = 'cancelled', cancellation_reason = p_cancellation_reason, updated_at = NOW()
        WHERE (schedule_id = v_parent_id OR schedule_id = p_schedule_id OR route_id = v_sched.route_id)
          AND (schedule_instance_date >= p_target_instance_date OR start_date >= to_char(p_target_instance_date, 'YYYY-MM-DD') OR DATE(scheduled_start AT TIME ZONE v_tz) >= p_target_instance_date);

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Recurring series cancelled from ' || to_char(p_target_instance_date, 'YYYY-MM-DD') || ' onwards.',
            'data', to_jsonb(v_sched)
        );

    -- ========================================================================
    -- 3. SCOPE: ENTIRE SERIES
    -- ========================================================================
    ELSE
        UPDATE public.schedules
        SET status = 'cancelled', cancellation_reason = p_cancellation_reason, cancelled_by = p_user_id, cancelled_at = NOW(), updated_at = NOW()
        WHERE (id = v_parent_id OR id = p_schedule_id OR recurring_parent_id = v_parent_id OR recurring_parent_id = p_schedule_id)
          AND (school_id = p_school_id OR school_id IS NULL);

        UPDATE public.resource_bookings
        SET status = 'cancelled'
        WHERE schedule_id = v_parent_id OR schedule_id = p_schedule_id OR schedule_id IN (SELECT id FROM public.schedules WHERE recurring_parent_id = v_parent_id);

        UPDATE public.vehicle_trips
        SET status = 'cancelled', cancellation_reason = p_cancellation_reason, updated_at = NOW()
        WHERE schedule_id = v_parent_id OR schedule_id = p_schedule_id OR schedule_id IN (SELECT id FROM public.schedules WHERE recurring_parent_id = v_parent_id) OR (route_id IS NOT NULL AND route_id = v_sched.route_id);

        SELECT to_jsonb(s.*) INTO v_updated_record FROM public.schedules s WHERE id = v_parent_id;

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Entire schedule series cancelled successfully.',
            'data', v_updated_record
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
