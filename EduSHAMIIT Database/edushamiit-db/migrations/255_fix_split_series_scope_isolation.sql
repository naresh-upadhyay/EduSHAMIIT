-- ============================================================================
-- Migration: 255_fix_split_series_scope_isolation.sql
-- Description:
--   1. Ensures that editing or cancelling a split child recurring series (is_recurring = TRUE)
--      with 'entire_series' ('all_events') updates ONLY that split series, and NEVER
--      overwrites or deletes the parent series (before the split).
--   2. Ensures parent series (e.g. Days 1-3) and split series (e.g. Days 4-6) remain
--      cleanly isolated when applying 'entire_series' updates or cancellations.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_update_schedule(
    p_schedule_id uuid,
    p_school_id uuid,
    p_user_id uuid,
    p_data jsonb,
    p_recurrence_scope text DEFAULT 'entire_series'::text,
    p_target_instance_date date DEFAULT NULL::date
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_old public.schedules%ROWTYPE;
    v_updated public.schedules%ROWTYPE;
    v_target_series_id UUID;
    v_new_id UUID := gen_random_uuid();
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_tz TEXT;
    v_freq TEXT := 'none';
    v_interval INT := 1;
    v_end_type TEXT := 'never';
    v_end_count INT;
    v_end_date DATE;
    v_days JSONB := '[]'::jsonb;
    v_p_elem JSONB;
    v_r_elem JSONB;
    v_rem_elem JSONB;
    v_aud_type TEXT;
    v_target_roles JSONB := '[]'::jsonb;
    v_target_classes JSONB := '[]'::jsonb;
    v_target_users JSONB := '[]'::jsonb;
    v_duration INTERVAL;
    v_new_start TIMESTAMP WITH TIME ZONE;
    v_new_end TIMESTAMP WITH TIME ZONE;
    v_target_date DATE;
    v_rec_obj JSONB;
    v_has_recurrence_in_payload BOOLEAN := FALSE;
    v_status TEXT;
    v_cancel_reason TEXT;
BEGIN
    -- Fetch original schedule
    SELECT * INTO v_old FROM public.schedules WHERE id = p_schedule_id AND deleted_at IS NULL;
    IF v_old.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Schedule not found or deleted.');
    END IF;

    v_tz := COALESCE(p_data->>'timezone', v_old.timezone, 'Asia/Kolkata');
    
    -- If v_old is a recurring series, target series is v_old.id itself!
    -- If v_old is a single-event override row (not recurring), target series is its recurring_parent_id.
    IF v_old.is_recurring THEN
        v_target_series_id := v_old.id;
    ELSE
        v_target_series_id := COALESCE(v_old.recurring_parent_id, v_old.id);
    END IF;

    v_target_date := COALESCE(p_target_instance_date, v_old.original_instance_date, (v_old.start_time AT TIME ZONE v_tz)::DATE);

    v_status := COALESCE(p_data->>'status', v_old.status, 'scheduled');
    v_cancel_reason := COALESCE(p_data->>'cancellation_reason', v_old.cancellation_reason);

    -- Parse audience targets
    v_aud_type := COALESCE(p_data->>'audience_type', v_old.audience_type, 'individual');
    v_target_roles := COALESCE(p_data->'target_roles', v_old.target_roles, '[]'::jsonb);
    v_target_classes := COALESCE(p_data->'target_classes', v_old.target_classes, '[]'::jsonb);
    v_target_users := COALESCE(p_data->'target_user_ids', v_old.target_user_ids, '[]'::jsonb);

    -- Extract recurrence details robustly from nested 'recurrence' object or top-level keys
    IF jsonb_typeof(p_data->'recurrence') = 'object' THEN
        v_rec_obj := p_data->'recurrence';
        v_has_recurrence_in_payload := TRUE;
        v_freq := COALESCE(v_rec_obj->>'frequency', 'none');
        v_interval := COALESCE((v_rec_obj->>'interval')::INT, 1);
        v_days := COALESCE(v_rec_obj->'days_of_week', '[]'::jsonb);
        v_end_type := COALESCE(v_rec_obj->>'end_type', 'never');
        v_end_count := (v_rec_obj->>'end_count')::INT;
        IF v_rec_obj->>'end_date' IS NOT NULL AND v_rec_obj->>'end_date' != '' THEN
            v_end_date := (v_rec_obj->>'end_date')::DATE;
        END IF;
    ELSIF p_data->>'frequency' IS NOT NULL THEN
        v_has_recurrence_in_payload := TRUE;
        v_freq := p_data->>'frequency';
        v_interval := COALESCE((p_data->>'interval')::INT, 1);
        v_days := COALESCE(p_data->'days_of_week', '[]'::jsonb);
        v_end_type := COALESCE(p_data->>'end_type', 'never');
        v_end_count := (p_data->>'end_count')::INT;
        IF p_data->>'end_date' IS NOT NULL AND p_data->>'end_date' != '' THEN
            v_end_date := (p_data->>'end_date')::DATE;
        END IF;
    ELSIF p_data->>'is_recurring' IS NOT NULL AND (p_data->>'is_recurring')::BOOLEAN = FALSE THEN
        v_has_recurrence_in_payload := TRUE;
        v_freq := 'none';
    END IF;

    -- If no recurrence was specified in payload, preserve existing recurrence rule from target series
    IF NOT v_has_recurrence_in_payload THEN
        SELECT frequency, interval, days_of_week, end_type, end_count, end_date
        INTO v_freq, v_interval, v_days, v_end_type, v_end_count, v_end_date
        FROM public.schedule_recurrence
        WHERE schedule_id = v_target_series_id;

        IF v_freq IS NULL THEN
            v_freq := CASE WHEN v_old.is_recurring THEN 'daily' ELSE 'none' END;
        END IF;
    END IF;

    -- Normalize days of week ONLY for weekly recurrence if empty (do NOT overwrite custom intervals!)
    IF v_freq = 'weekly' AND (v_days IS NULL OR jsonb_array_length(v_days) = 0) THEN
        v_days := jsonb_build_array(UPPER(SUBSTRING(to_char((COALESCE(v_old.start_time, NOW()) AT TIME ZONE v_tz), 'Day') FROM 1 FOR 2)));
    ELSIF v_freq = 'weekdays' THEN
        v_days := '["MO", "TU", "WE", "TH", "FR"]'::jsonb;
    END IF;

    -- ========================================================================
    -- 1. SCOPE: THIS EVENT ONLY ('this_event')
    -- ========================================================================
    IF p_recurrence_scope = 'this_event' AND v_target_date IS NOT NULL THEN
        v_duration := COALESCE(v_old.end_time - v_old.start_time, INTERVAL '1 hour');

        IF p_data->>'start_time' IS NOT NULL AND p_data->>'start_time' != '' THEN
            v_new_start := public.parse_tz_timestamp(p_data->>'start_time', v_tz);
        ELSE
            v_new_start := (v_target_date::TEXT || ' ' || to_char((v_old.start_time AT TIME ZONE v_tz)::TIME, 'HH24:MI:SS'))::TIMESTAMP AT TIME ZONE v_tz;
        END IF;

        IF p_data->>'end_time' IS NOT NULL AND p_data->>'end_time' != '' THEN
            v_new_end := public.parse_tz_timestamp(p_data->>'end_time', v_tz);
        ELSE
            v_new_end := v_new_start + v_duration;
        END IF;

        -- Insert override row
        INSERT INTO public.schedules (
            id, school_id, calendar_id, route_id, title, description, schedule_type, category, color, priority,
            status, approval_status, cancellation_reason, cancelled_at, cancelled_by,
            start_time, end_time, is_all_day, timezone,
            location_name, location_address, building, room, virtual_meeting_url, virtual_meeting_provider,
            organizer_id, created_by, visibility, is_recurring, recurring_parent_id, original_instance_date,
            recurrence_exception_type, metadata, audience_type, target_roles, target_classes, target_user_ids, created_at, updated_at
        ) VALUES (
            v_new_id, p_school_id, COALESCE((p_data->>'calendar_id')::UUID, v_old.calendar_id),
            CASE WHEN p_data->>'route_id' IS NOT NULL AND p_data->>'route_id' != '' THEN (p_data->>'route_id')::UUID ELSE v_old.route_id END,
            COALESCE(p_data->>'title', v_old.title), COALESCE(p_data->>'description', v_old.description),
            COALESCE(p_data->>'schedule_type', v_old.schedule_type), COALESCE(p_data->>'category', v_old.category),
            COALESCE(p_data->>'color', v_old.color), COALESCE(p_data->>'priority', v_old.priority),
            v_status, COALESCE(p_data->>'approval_status', v_old.approval_status, 'approved'),
            v_cancel_reason,
            CASE WHEN v_status = 'cancelled' THEN NOW() ELSE NULL END,
            CASE WHEN v_status = 'cancelled' THEN p_user_id ELSE NULL END,
            v_new_start, v_new_end, COALESCE((p_data->>'is_all_day')::BOOLEAN, v_old.is_all_day),
            v_tz, COALESCE(p_data->>'location_name', v_old.location_name),
            COALESCE(p_data->>'location_address', v_old.location_address), COALESCE(p_data->>'building', v_old.building),
            COALESCE(p_data->>'room', v_old.room), COALESCE(p_data->>'virtual_meeting_url', v_old.virtual_meeting_url),
            COALESCE(p_data->>'virtual_meeting_provider', v_old.virtual_meeting_provider),
            v_old.organizer_id, p_user_id, COALESCE(p_data->>'visibility', v_old.visibility),
            FALSE, v_target_series_id, v_target_date, 'override',
            COALESCE(p_data->'metadata', v_old.metadata), v_aud_type, v_target_roles, v_target_classes, v_target_users, NOW(), NOW()
        ) RETURNING * INTO v_updated;

        -- Transfer existing vehicle_trips for this date to v_new_id so trip_id is 100% PRESERVED!
        UPDATE public.vehicle_trips
        SET schedule_id = v_new_id,
            route_id = v_updated.route_id,
            vehicle_id = (SELECT vehicle_id FROM public.transport_routes WHERE id = v_updated.route_id),
            start_date = v_target_date::TEXT,
            end_date = v_target_date::TEXT,
            schedule_instance_date = v_target_date,
            start_time = to_char(v_new_start AT TIME ZONE v_tz, 'HH12:MI AM'),
            end_time = to_char(v_new_end AT TIME ZONE v_tz, 'HH12:MI AM'),
            scheduled_start = v_new_start,
            status = CASE WHEN v_status = 'cancelled' THEN 'cancelled' ELSE status END,
            updated_at = NOW()
        WHERE (schedule_id = v_target_series_id OR schedule_id = p_schedule_id OR schedule_id IN (SELECT id FROM public.schedules WHERE recurring_parent_id = v_target_series_id))
          AND (schedule_instance_date = v_target_date OR start_date = v_target_date::TEXT);

        -- Exclude this date from target series
        PERFORM public.exclude_recurring_occurrence(v_target_series_id, v_target_date);
        IF p_schedule_id != v_target_series_id THEN
            PERFORM public.exclude_recurring_occurrence(p_schedule_id, v_target_date);
        END IF;

        UPDATE public.schedules SET is_recurring = TRUE WHERE id = v_target_series_id;

        -- Soft delete ONLY previous single-event override rows for this date (NEVER recurring series!)
        UPDATE public.schedules
        SET deleted_at = NOW(), status = 'cancelled', updated_at = NOW()
        WHERE (recurring_parent_id = v_target_series_id OR recurring_parent_id = p_schedule_id OR id = p_schedule_id)
          AND (original_instance_date = v_target_date OR DATE(start_time AT TIME ZONE v_tz) = v_target_date)
          AND (recurrence_exception_type = 'override' OR is_recurring = FALSE)
          AND id != v_new_id;

        IF jsonb_array_length(COALESCE(p_data->'participants', '[]'::jsonb)) > 0 THEN
            FOR v_p_elem IN SELECT * FROM jsonb_array_elements(p_data->'participants') LOOP
                INSERT INTO public.schedule_participants (
                    id, schedule_id, user_id, target_role, target_department, target_class, target_section,
                    participant_type, participation_role, permission, rsvp_status, created_at
                ) VALUES (
                    gen_random_uuid(), v_new_id,
                    CASE WHEN v_p_elem->>'user_id' IS NOT NULL AND v_p_elem->>'user_id' != '' THEN (v_p_elem->>'user_id')::UUID ELSE NULL END,
                    v_p_elem->>'target_role', v_p_elem->>'target_department', v_p_elem->>'target_class', v_p_elem->>'target_section',
                    COALESCE(v_p_elem->>'participant_type', 'individual'),
                    COALESCE(v_p_elem->>'participation_role', 'required'),
                    COALESCE(v_p_elem->>'permission', 'can_view'),
                    'pending', NOW()
                );
            END LOOP;
        END IF;

        IF jsonb_array_length(COALESCE(p_data->'resources', '[]'::jsonb)) > 0 THEN
            FOR v_r_elem IN SELECT * FROM jsonb_array_elements(p_data->'resources') LOOP
                IF v_r_elem->>'resource_id' IS NOT NULL AND v_r_elem->>'resource_id' != '' THEN
                    INSERT INTO public.resource_bookings (
                        id, schedule_id, resource_id, start_time, end_time, status, created_at
                    ) VALUES (
                        gen_random_uuid(), v_new_id, (v_r_elem->>'resource_id')::UUID, v_new_start, v_new_end, 'confirmed', NOW()
                    );
                END IF;
            END LOOP;
        END IF;

        IF jsonb_array_length(COALESCE(p_data->'reminders', '[]'::jsonb)) > 0 THEN
            FOR v_rem_elem IN SELECT * FROM jsonb_array_elements(p_data->'reminders') LOOP
                INSERT INTO public.schedule_reminders (
                    id, schedule_id, user_id, minutes_before, channel, is_sent, created_at
                ) VALUES (
                    gen_random_uuid(), v_new_id, p_user_id, COALESCE((v_rem_elem->>'minutes_before')::INT, 15),
                    COALESCE(v_rem_elem->>'channel', 'in_app'), FALSE, NOW()
                );
            END LOOP;
        END IF;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Updated this event occurrence successfully.', 'data', to_jsonb(v_updated));

    -- ========================================================================
    -- 2. SCOPE: THIS AND FOLLOWING EVENTS ('this_and_following' / 'following_events')
    -- ========================================================================
    ELSIF p_recurrence_scope IN ('this_and_following', 'following_events') AND v_target_date IS NOT NULL THEN
        v_duration := COALESCE(v_old.end_time - v_old.start_time, INTERVAL '1 hour');

        IF p_data->>'start_time' IS NOT NULL AND p_data->>'start_time' != '' THEN
            v_new_start := public.parse_tz_timestamp(p_data->>'start_time', v_tz);
        ELSE
            v_new_start := (v_target_date::TEXT || ' ' || to_char((v_old.start_time AT TIME ZONE v_tz)::TIME, 'HH24:MI:SS'))::TIMESTAMP AT TIME ZONE v_tz;
        END IF;

        IF p_data->>'end_time' IS NOT NULL AND p_data->>'end_time' != '' THEN
            v_new_end := public.parse_tz_timestamp(p_data->>'end_time', v_tz);
        ELSE
            v_new_end := v_new_start + v_duration;
        END IF;

        -- Calculate remaining after_count if inheriting count from master
        IF NOT v_has_recurrence_in_payload AND v_end_type = 'after_count' AND v_end_count IS NOT NULL THEN
            IF v_freq IN ('daily', 'custom') THEN
                v_end_count := GREATEST(1, v_end_count - ((v_target_date - (v_old.start_time AT TIME ZONE v_tz)::DATE) / GREATEST(1, v_interval))::INT);
            ELSIF v_freq = 'weekdays' THEN
                SELECT GREATEST(1, v_end_count - count(*)::INT) INTO v_end_count
                FROM generate_series((v_old.start_time AT TIME ZONE v_tz)::DATE, v_target_date - INTERVAL '1 day', INTERVAL '1 day') AS d
                WHERE EXTRACT(ISODOW FROM d) BETWEEN 1 AND 5;
            ELSIF v_freq = 'weekly' THEN
                SELECT GREATEST(1, v_end_count - count(*)::INT) INTO v_end_count
                FROM generate_series((v_old.start_time AT TIME ZONE v_tz)::DATE, v_target_date - INTERVAL '1 day', INTERVAL '1 day') AS d
                WHERE UPPER(SUBSTRING(to_char(d, 'Day') FROM 1 FOR 2)) = ANY(ARRAY(SELECT jsonb_array_elements_text(v_days)));
            END IF;
        END IF;

        INSERT INTO public.schedules (
            id, school_id, calendar_id, route_id, title, description, schedule_type, category, color, priority,
            status, approval_status, cancellation_reason, cancelled_at, cancelled_by,
            start_time, end_time, is_all_day, timezone,
            location_name, location_address, building, room, virtual_meeting_url, virtual_meeting_provider,
            organizer_id, created_by, visibility, is_recurring, recurring_parent_id, original_instance_date,
            recurrence_exception_type, metadata, audience_type, target_roles, target_classes, target_user_ids, created_at, updated_at
        ) VALUES (
            v_new_id, p_school_id, COALESCE((p_data->>'calendar_id')::UUID, v_old.calendar_id),
            CASE WHEN p_data->>'route_id' IS NOT NULL AND p_data->>'route_id' != '' THEN (p_data->>'route_id')::UUID ELSE v_old.route_id END,
            COALESCE(p_data->>'title', v_old.title), COALESCE(p_data->>'description', v_old.description),
            COALESCE(p_data->>'schedule_type', v_old.schedule_type), COALESCE(p_data->>'category', v_old.category),
            COALESCE(p_data->>'color', v_old.color), COALESCE(p_data->>'priority', v_old.priority),
            v_status, COALESCE(p_data->>'approval_status', v_old.approval_status, 'approved'),
            v_cancel_reason,
            CASE WHEN v_status = 'cancelled' THEN NOW() ELSE NULL END,
            CASE WHEN v_status = 'cancelled' THEN p_user_id ELSE NULL END,
            v_new_start, v_new_end, COALESCE((p_data->>'is_all_day')::BOOLEAN, v_old.is_all_day),
            v_tz, COALESCE(p_data->>'location_name', v_old.location_name),
            COALESCE(p_data->>'location_address', v_old.location_address), COALESCE(p_data->>'building', v_old.building),
            COALESCE(p_data->>'room', v_old.room), COALESCE(p_data->>'virtual_meeting_url', v_old.virtual_meeting_url),
            COALESCE(p_data->>'virtual_meeting_provider', v_old.virtual_meeting_provider),
            v_old.organizer_id, p_user_id, COALESCE(p_data->>'visibility', v_old.visibility),
            (v_freq != 'none'), v_target_series_id, NULL, 'none',
            COALESCE(p_data->'metadata', v_old.metadata), v_aud_type, v_target_roles, v_target_classes, v_target_users, NOW(), NOW()
        ) RETURNING * INTO v_updated;

        -- Transfer existing vehicle_trips from target_date onwards to v_new_id so trip_ids are preserved!
        UPDATE public.vehicle_trips
        SET schedule_id = v_new_id,
            route_id = v_updated.route_id,
            vehicle_id = (SELECT vehicle_id FROM public.transport_routes WHERE id = v_updated.route_id),
            status = CASE WHEN v_status = 'cancelled' THEN 'cancelled' ELSE status END,
            updated_at = NOW()
        WHERE (schedule_id = v_target_series_id OR schedule_id = p_schedule_id OR schedule_id IN (SELECT id FROM public.schedules WHERE recurring_parent_id = v_target_series_id))
          AND (schedule_instance_date >= v_target_date OR start_date >= v_target_date::TEXT);

        UPDATE public.schedule_recurrence
        SET end_type = 'until_date',
            end_date = v_target_date - INTERVAL '1 day',
            updated_at = NOW()
        WHERE schedule_id = v_target_series_id OR schedule_id = p_schedule_id;

        -- Soft delete ONLY previous override rows from target_date onwards (NEVER recurring series!)
        UPDATE public.schedules
        SET deleted_at = NOW(), status = 'cancelled', updated_at = NOW()
        WHERE (recurring_parent_id = v_target_series_id OR recurring_parent_id = p_schedule_id)
          AND (original_instance_date >= v_target_date OR DATE(start_time AT TIME ZONE v_tz) >= v_target_date)
          AND (recurrence_exception_type = 'override' OR is_recurring = FALSE)
          AND id != v_new_id;

        IF v_freq != 'none' THEN
            INSERT INTO public.schedule_recurrence (
                id, schedule_id, frequency, interval, days_of_week, end_type, end_count, end_date, exceptions, created_at, updated_at
            ) VALUES (
                gen_random_uuid(), v_new_id, v_freq, v_interval, v_days, v_end_type, v_end_count, v_end_date, '[]'::jsonb, NOW(), NOW()
            );
        END IF;

        IF jsonb_array_length(COALESCE(p_data->'participants', '[]'::jsonb)) > 0 THEN
            FOR v_p_elem IN SELECT * FROM jsonb_array_elements(p_data->'participants') LOOP
                INSERT INTO public.schedule_participants (
                    id, schedule_id, user_id, target_role, target_department, target_class, target_section,
                    participant_type, participation_role, permission, rsvp_status, created_at
                ) VALUES (
                    gen_random_uuid(), v_new_id,
                    CASE WHEN v_p_elem->>'user_id' IS NOT NULL AND v_p_elem->>'user_id' != '' THEN (v_p_elem->>'user_id')::UUID ELSE NULL END,
                    v_p_elem->>'target_role', v_p_elem->>'target_department', v_p_elem->>'target_class', v_p_elem->>'target_section',
                    COALESCE(v_p_elem->>'participant_type', 'individual'),
                    COALESCE(v_p_elem->>'participation_role', 'required'),
                    COALESCE(v_p_elem->>'permission', 'can_view'),
                    'pending', NOW()
                );
            END LOOP;
        END IF;

        IF jsonb_array_length(COALESCE(p_data->'resources', '[]'::jsonb)) > 0 THEN
            FOR v_r_elem IN SELECT * FROM jsonb_array_elements(p_data->'resources') LOOP
                IF v_r_elem->>'resource_id' IS NOT NULL AND v_r_elem->>'resource_id' != '' THEN
                    INSERT INTO public.resource_bookings (
                        id, schedule_id, resource_id, start_time, end_time, status, created_at
                    ) VALUES (
                        gen_random_uuid(), v_new_id, (v_r_elem->>'resource_id')::UUID, v_new_start, v_new_end, 'confirmed', NOW()
                    );
                END IF;
            END LOOP;
        END IF;

        IF jsonb_array_length(COALESCE(p_data->'reminders', '[]'::jsonb)) > 0 THEN
            FOR v_rem_elem IN SELECT * FROM jsonb_array_elements(p_data->'reminders') LOOP
                INSERT INTO public.schedule_reminders (
                    id, schedule_id, user_id, minutes_before, channel, is_sent, created_at
                ) VALUES (
                    gen_random_uuid(), v_new_id, p_user_id, COALESCE((v_rem_elem->>'minutes_before')::INT, 15),
                    COALESCE(v_rem_elem->>'channel', 'in_app'), FALSE, NOW()
                );
            END LOOP;
        END IF;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Updated this and following events successfully.', 'data', to_jsonb(v_updated));

    -- ========================================================================
    -- 3. SCOPE: ALL EVENTS IN SERIES ('all_events' / 'entire_series')
    -- ========================================================================
    ELSE
        IF p_data->>'start_time' IS NOT NULL AND p_data->>'start_time' != '' THEN
            v_start_time := public.parse_tz_timestamp(p_data->>'start_time', v_tz);
        ELSE
            v_start_time := v_old.start_time;
        END IF;

        IF p_data->>'end_time' IS NOT NULL AND p_data->>'end_time' != '' THEN
            v_end_time := public.parse_tz_timestamp(p_data->>'end_time', v_tz);
        ELSE
            v_end_time := v_old.end_time;
        END IF;

        -- Update the targeted schedule series (v_target_series_id)
        UPDATE public.schedules
        SET calendar_id = COALESCE((p_data->>'calendar_id')::UUID, calendar_id),
            title = COALESCE(p_data->>'title', title),
            description = COALESCE(p_data->>'description', description),
            schedule_type = COALESCE(p_data->>'schedule_type', schedule_type),
            category = COALESCE(p_data->>'category', category),
            color = COALESCE(p_data->>'color', color),
            priority = COALESCE(p_data->>'priority', priority),
            status = v_status,
            approval_status = COALESCE(p_data->>'approval_status', approval_status),
            cancellation_reason = v_cancel_reason,
            cancelled_at = CASE WHEN v_status = 'cancelled' THEN NOW() ELSE cancelled_at END,
            cancelled_by = CASE WHEN v_status = 'cancelled' THEN p_user_id ELSE cancelled_by END,
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
            is_recurring = (v_freq != 'none'),
            route_id = CASE WHEN p_data->>'route_id' IS NOT NULL AND p_data->>'route_id' != '' THEN (p_data->>'route_id')::UUID ELSE route_id END,
            metadata = COALESCE(p_data->'metadata', metadata),
            audience_type = v_aud_type,
            target_roles = v_target_roles,
            target_classes = v_target_classes,
            target_user_ids = v_target_users,
            updated_at = NOW()
        WHERE id = v_target_series_id
        RETURNING * INTO v_updated;

        -- If status is cancelled, also update child overrides and trips of this specific series
        IF v_status = 'cancelled' THEN
            UPDATE public.schedules
            SET status = 'cancelled',
                cancellation_reason = v_cancel_reason,
                cancelled_at = NOW(),
                cancelled_by = p_user_id,
                updated_at = NOW()
            WHERE recurring_parent_id = v_target_series_id;

            UPDATE public.vehicle_trips
            SET status = 'cancelled', updated_at = NOW()
            WHERE schedule_id = v_target_series_id
               OR schedule_id IN (SELECT id FROM public.schedules WHERE recurring_parent_id = v_target_series_id);
        END IF;

        -- Update or insert recurrence details for this specific series
        IF v_freq != 'none' THEN
            IF EXISTS (SELECT 1 FROM public.schedule_recurrence WHERE schedule_id = v_target_series_id) THEN
                UPDATE public.schedule_recurrence
                SET frequency = v_freq,
                    interval = v_interval,
                    days_of_week = v_days,
                    end_type = v_end_type,
                    end_count = v_end_count,
                    end_date = v_end_date,
                    updated_at = NOW()
                WHERE schedule_id = v_target_series_id;
            ELSE
                INSERT INTO public.schedule_recurrence (
                    id, schedule_id, frequency, interval, days_of_week, end_type, end_count, end_date, exceptions, created_at, updated_at
                ) VALUES (
                    gen_random_uuid(), v_target_series_id, v_freq, v_interval, v_days, v_end_type, v_end_count, v_end_date, '[]'::jsonb, NOW(), NOW()
                );
            END IF;
        ELSE
            DELETE FROM public.schedule_recurrence WHERE schedule_id = v_target_series_id;
        END IF;

        -- Update participants
        IF jsonb_array_length(COALESCE(p_data->'participants', '[]'::jsonb)) > 0 THEN
            DELETE FROM public.schedule_participants WHERE schedule_id = v_target_series_id;
            FOR v_p_elem IN SELECT * FROM jsonb_array_elements(p_data->'participants') LOOP
                INSERT INTO public.schedule_participants (
                    id, schedule_id, user_id, target_role, target_department, target_class, target_section,
                    participant_type, participation_role, permission, rsvp_status, created_at
                ) VALUES (
                    gen_random_uuid(), v_target_series_id,
                    CASE WHEN v_p_elem->>'user_id' IS NOT NULL AND v_p_elem->>'user_id' != '' THEN (v_p_elem->>'user_id')::UUID ELSE NULL END,
                    v_p_elem->>'target_role', v_p_elem->>'target_department', v_p_elem->>'target_class', v_p_elem->>'target_section',
                    COALESCE(v_p_elem->>'participant_type', 'individual'),
                    COALESCE(v_p_elem->>'participation_role', 'required'),
                    COALESCE(v_p_elem->>'permission', 'can_view'),
                    'pending', NOW()
                );
            END LOOP;
        END IF;

        -- Update resources
        IF jsonb_array_length(COALESCE(p_data->'resources', '[]'::jsonb)) > 0 THEN
            DELETE FROM public.resource_bookings WHERE schedule_id = v_target_series_id;
            FOR v_r_elem IN SELECT * FROM jsonb_array_elements(p_data->'resources') LOOP
                IF v_r_elem->>'resource_id' IS NOT NULL AND v_r_elem->>'resource_id' != '' THEN
                    INSERT INTO public.resource_bookings (
                        id, schedule_id, resource_id, start_time, end_time, status, created_at
                    ) VALUES (
                        gen_random_uuid(), v_target_series_id, (v_r_elem->>'resource_id')::UUID, v_start_time, v_end_time, 'confirmed', NOW()
                    );
                END IF;
            END LOOP;
        END IF;

        -- Update reminders
        IF jsonb_array_length(COALESCE(p_data->'reminders', '[]'::jsonb)) > 0 THEN
            DELETE FROM public.schedule_reminders WHERE schedule_id = v_target_series_id;
            FOR v_rem_elem IN SELECT * FROM jsonb_array_elements(p_data->'reminders') LOOP
                INSERT INTO public.schedule_reminders (
                    id, schedule_id, user_id, minutes_before, channel, is_sent, created_at
                ) VALUES (
                    gen_random_uuid(), v_target_series_id, p_user_id, COALESCE((v_rem_elem->>'minutes_before')::INT, 15),
                    COALESCE(v_rem_elem->>'channel', 'in_app'), FALSE, NOW()
                );
            END LOOP;
        END IF;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Schedule series updated successfully.', 'data', to_jsonb(v_updated));
    END IF;
END;
$function$;


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
    v_target_series_id UUID;
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
    
    IF v_sched.is_recurring THEN
        v_target_series_id := v_sched.id;
    ELSE
        v_target_series_id := COALESCE(v_sched.recurring_parent_id, v_sched.id);
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
    SELECT id INTO v_rec_id
    FROM public.schedule_recurrence
    WHERE schedule_id = v_target_series_id;

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

        -- Add exception date to target recurrence
        PERFORM public.exclude_recurring_occurrence(v_target_series_id, p_target_instance_date);
        IF p_schedule_id != v_target_series_id THEN
            PERFORM public.exclude_recurring_occurrence(p_schedule_id, p_target_instance_date);
        END IF;

        UPDATE public.schedules SET is_recurring = TRUE WHERE id = v_target_series_id;

        -- Check existing override record
        SELECT id INTO v_ov_id
        FROM public.schedules
        WHERE (recurring_parent_id = v_target_series_id OR recurring_parent_id = p_schedule_id OR id = p_schedule_id)
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
                FALSE, v_target_series_id, p_target_instance_date, 'cancelled',
                p_cancellation_reason, p_user_id, NOW(), v_sched.route_id, v_sched.audience_type,
                COALESCE(v_sched.target_roles, '[]'::jsonb), COALESCE(v_sched.target_classes, '[]'::jsonb), COALESCE(v_sched.target_user_ids, '[]'::jsonb),
                COALESCE(v_sched.metadata, '{}'::jsonb), NOW(), NOW()
            );

            SELECT to_jsonb(s.*) INTO v_updated_record FROM public.schedules s WHERE id = v_ov_id;
        END IF;

        -- Cancel specific vehicle trip
        UPDATE public.vehicle_trips
        SET status = 'cancelled', cancellation_reason = p_cancellation_reason, updated_at = NOW()
        WHERE (schedule_id = v_target_series_id OR schedule_id = p_schedule_id OR schedule_id = v_ov_id OR route_id = v_sched.route_id)
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
        WHERE schedule_id = v_target_series_id OR schedule_id = p_schedule_id;

        -- Mark any existing child overrides from target date onwards as cancelled
        UPDATE public.schedules
        SET status = 'cancelled', cancellation_reason = p_cancellation_reason, cancelled_by = p_user_id, cancelled_at = NOW(), updated_at = NOW()
        WHERE (recurring_parent_id = v_target_series_id OR recurring_parent_id = p_schedule_id)
          AND (original_instance_date >= p_target_instance_date OR DATE(start_time AT TIME ZONE v_tz) >= p_target_instance_date);

        UPDATE public.vehicle_trips
        SET status = 'cancelled', cancellation_reason = p_cancellation_reason, updated_at = NOW()
        WHERE (schedule_id = v_target_series_id OR schedule_id = p_schedule_id OR route_id = v_sched.route_id)
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
        WHERE (id = v_target_series_id OR recurring_parent_id = v_target_series_id)
          AND (school_id = p_school_id OR school_id IS NULL);

        UPDATE public.resource_bookings
        SET status = 'cancelled'
        WHERE schedule_id = v_target_series_id OR schedule_id IN (SELECT id FROM public.schedules WHERE recurring_parent_id = v_target_series_id);

        UPDATE public.vehicle_trips
        SET status = 'cancelled', cancellation_reason = p_cancellation_reason, updated_at = NOW()
        WHERE schedule_id = v_target_series_id OR schedule_id IN (SELECT id FROM public.schedules WHERE recurring_parent_id = v_target_series_id) OR (route_id IS NOT NULL AND route_id = v_sched.route_id);

        SELECT to_jsonb(s.*) INTO v_updated_record FROM public.schedules s WHERE id = v_target_series_id;

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Entire schedule series cancelled successfully.',
            'data', v_updated_record
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
