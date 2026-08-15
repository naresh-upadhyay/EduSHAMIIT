-- ============================================================================
-- Migration: 238_fix_recurrence_updates.sql
-- Description: Fix schedule recurrence updates and prevent duplicate schedules
-- ============================================================================

-- 1. Repair any existing schedules where a recurrence rule exists but is_recurring was set to FALSE
UPDATE public.schedules
SET is_recurring = TRUE, updated_at = NOW()
WHERE id IN (SELECT schedule_id FROM public.schedule_recurrence)
  AND deleted_at IS NULL
  AND is_recurring = FALSE;

-- 2. Update fn_update_schedule to enforce recurrence integrity
CREATE OR REPLACE FUNCTION public.fn_update_schedule(
    p_schedule_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB,
    p_recurrence_scope TEXT DEFAULT 'this_event',
    p_target_instance_date DATE DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_old public.schedules%ROWTYPE;
    v_updated public.schedules%ROWTYPE;
    v_master_parent_id UUID;
    v_ov_id UUID := gen_random_uuid();
    v_start_time TIMESTAMP WITH TIME ZONE;
    v_end_time TIMESTAMP WITH TIME ZONE;
    v_tz TEXT;
    v_freq TEXT;
    v_interval INT;
    v_end_type TEXT;
    v_end_date DATE;
    v_end_count INT;
    v_days JSONB;
    v_p_elem JSONB;
    v_r_elem JSONB;
    v_rem_elem JSONB;
    v_aud_type TEXT;
    v_target_roles TEXT[];
    v_target_classes TEXT[];
    v_target_users UUID[];
    v_duration INTERVAL;
    v_new_start TIMESTAMP WITH TIME ZONE;
    v_new_end TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Fetch original schedule
    SELECT * INTO v_old FROM public.schedules WHERE id = p_schedule_id AND deleted_at IS NULL;
    IF v_old.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Schedule not found or deleted.');
    END IF;

    v_tz := COALESCE(p_data->>'timezone', v_old.timezone, 'Asia/Kolkata');
    v_master_parent_id := COALESCE(v_old.recurring_parent_id, v_old.id);

    -- Parse audience targets
    v_aud_type := COALESCE(p_data->>'audience_type', v_old.audience_type, 'individual');
    v_target_roles := public.jsonb_array_to_text_array(p_data->'target_roles');
    v_target_classes := public.jsonb_array_to_text_array(p_data->'target_classes');
    v_target_users := public.jsonb_array_to_uuid_array(p_data->'target_user_ids');

    -- 1. SCOPE: ENTIRE SERIES (all_events) or Standalone Schedule
    IF p_recurrence_scope IN ('all_events', 'entire_series', 'this_and_following') OR NOT COALESCE(v_old.is_recurring, FALSE) THEN
        
        -- Parse start and end times
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

        -- Update master schedule row
        UPDATE public.schedules
        SET calendar_id = COALESCE((p_data->>'calendar_id')::UUID, calendar_id),
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
            is_recurring = CASE 
                WHEN p_data->>'frequency' = 'none' OR (p_data->>'is_recurring' IS NOT NULL AND (p_data->>'is_recurring')::BOOLEAN = FALSE AND p_data->>'frequency' IS NULL) THEN FALSE
                WHEN p_data->>'frequency' IS NOT NULL AND p_data->>'frequency' != 'none' THEN TRUE
                ELSE is_recurring 
            END,
            route_id = CASE WHEN p_data->>'route_id' IS NOT NULL AND p_data->>'route_id' != '' THEN (p_data->>'route_id')::UUID ELSE route_id END,
            metadata = COALESCE(p_data->'metadata', metadata),
            audience_type = v_aud_type,
            target_roles = v_target_roles,
            target_classes = v_target_classes,
            target_user_ids = v_target_users,
            updated_at = NOW()
        WHERE id = v_master_parent_id
        RETURNING * INTO v_updated;

        -- Update or insert recurrence details
        v_freq := COALESCE(p_data->>'frequency', 'none');
        IF v_freq != 'none' THEN
            v_interval := COALESCE((p_data->>'interval')::INT, 1);
            v_end_type := COALESCE(p_data->>'end_type', 'never');
            v_end_count := (p_data->>'end_count')::INT;
            IF p_data->>'end_date' IS NOT NULL AND p_data->>'end_date' != '' THEN
                v_end_date := (p_data->>'end_date')::DATE;
            END IF;
            v_days := COALESCE(p_data->'days_of_week', '[]'::jsonb);

            INSERT INTO public.schedule_recurrence (
                id, schedule_id, frequency, interval, days_of_week, end_type, end_count, end_date, created_at, updated_at
            ) VALUES (
                gen_random_uuid(), v_master_parent_id, v_freq, v_interval, v_days, v_end_type, v_end_count, v_end_date, NOW(), NOW()
            )
            ON CONFLICT (schedule_id) DO UPDATE
            SET frequency = EXCLUDED.frequency,
                interval = EXCLUDED.interval,
                days_of_week = EXCLUDED.days_of_week,
                end_type = EXCLUDED.end_type,
                end_count = EXCLUDED.end_count,
                end_date = EXCLUDED.end_date,
                updated_at = NOW();

            -- Ensure master is flagged as recurring
            UPDATE public.schedules SET is_recurring = TRUE WHERE id = v_master_parent_id;
        ELSIF p_data->>'frequency' = 'none' THEN
            DELETE FROM public.schedule_recurrence WHERE schedule_id = v_master_parent_id;
            UPDATE public.schedules SET is_recurring = FALSE WHERE id = v_master_parent_id;
        END IF;

        -- Update participants
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

        -- Update resource bookings
        IF p_data->'resources' IS NOT NULL AND jsonb_array_length(p_data->'resources') >= 0 THEN
            DELETE FROM public.resource_bookings WHERE schedule_id = v_master_parent_id;
            IF jsonb_array_length(p_data->'resources') > 0 THEN
                FOR v_r_elem IN SELECT * FROM jsonb_array_elements(p_data->'resources') LOOP
                    IF v_r_elem->>'resource_id' IS NOT NULL AND v_r_elem->>'resource_id' != '' THEN
                        INSERT INTO public.resource_bookings (
                            id, schedule_id, resource_id, start_time, end_time, status, created_at
                        ) VALUES (
                            gen_random_uuid(), v_master_parent_id, (v_r_elem->>'resource_id')::UUID, v_start_time, v_end_time, 'confirmed', NOW()
                        );
                    END IF;
                END LOOP;
            END IF;
        END IF;

        -- Update reminders
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

        RETURN jsonb_build_object('success', TRUE, 'message', 'Schedule updated successfully.', 'data', to_jsonb(v_updated));

    -- 2. SCOPE: THIS EVENT ONLY
    ELSIF p_recurrence_scope = 'this_event' AND p_target_instance_date IS NOT NULL THEN
        -- Add target date to master's exceptions array
        PERFORM public.exclude_recurring_occurrence(v_master_parent_id, p_target_instance_date);

        -- Ensure master parent retains is_recurring = TRUE
        UPDATE public.schedules SET is_recurring = TRUE WHERE id = v_master_parent_id;

        -- Soft delete any existing override row for this target date
        UPDATE public.schedules
        SET deleted_at = NOW(), status = 'cancelled', updated_at = NOW()
        WHERE recurring_parent_id = v_master_parent_id
          AND (original_instance_date = p_target_instance_date OR DATE(start_time AT TIME ZONE v_tz) = p_target_instance_date);

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

        -- Create override row with is_recurring = FALSE and recurring_parent_id set
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

        -- Copy participants
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

        -- Copy resources
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

        -- Copy reminders
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
    END IF;

    RETURN jsonb_build_object('success', FALSE, 'error', 'Invalid update parameters.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
