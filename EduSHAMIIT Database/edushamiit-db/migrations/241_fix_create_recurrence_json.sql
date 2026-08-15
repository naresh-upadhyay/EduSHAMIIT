-- ============================================================================
-- Migration: 241_fix_create_recurrence_json.sql
-- Description: Robust JSON recurrence parsing in fn_create_schedule
-- ============================================================================

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
    v_freq TEXT;
    v_is_rec BOOLEAN;
BEGIN
    v_start_time := public.parse_tz_timestamp(p_data->>'start_time', COALESCE(p_data->>'timezone', 'Asia/Kolkata'));
    v_end_time := public.parse_tz_timestamp(p_data->>'end_time', COALESCE(p_data->>'timezone', 'Asia/Kolkata'));
    v_force_override := COALESCE((p_data->>'force_override_conflicts')::BOOLEAN, FALSE);

    -- Extract frequency safely from top-level or recurrence object
    IF jsonb_typeof(p_data->'recurrence') = 'object' AND p_data->'recurrence'->>'frequency' IS NOT NULL THEN
        v_freq := p_data->'recurrence'->>'frequency';
    ELSE
        v_freq := COALESCE(p_data->>'frequency', 'none');
    END IF;

    v_is_rec := COALESCE((p_data->>'is_recurring')::BOOLEAN, FALSE) OR (v_freq != 'none');

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
                            'message', 'User ''' || v_usr_conflict.full_name || ''' has a schedule conflict with ''' || v_usr_conflict.sched_title || '''.'
                        );
                    END IF;
                END IF;
            END LOOP;
        END IF;

        IF jsonb_array_length(v_conflicts) > 0 THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'code', 'SCHEDULE_CONFLICT',
                'error', 'Schedule conflicts detected.',
                'conflicts', v_conflicts
            );
        END IF;
    END IF;

    -- 3. Audience targets
    IF p_data->'target_roles' IS NOT NULL AND jsonb_array_length(p_data->'target_roles') > 0 THEN
        v_target_roles := p_data->'target_roles';
    END IF;

    IF p_data->'target_classes' IS NOT NULL AND jsonb_array_length(p_data->'target_classes') > 0 THEN
        v_target_classes := p_data->'target_classes';
    END IF;

    IF p_data->'target_user_ids' IS NOT NULL AND jsonb_array_length(p_data->'target_user_ids') > 0 THEN
        v_target_users := p_data->'target_user_ids';
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
        COALESCE(p_data->>'visibility', 'shared'), v_is_rec,
        COALESCE(p_data->'metadata', '{}'::jsonb), v_aud_type, v_target_roles, v_target_classes, v_target_users, NOW(), NOW()
    ) RETURNING * INTO v_sched_rec;

    -- 5. Insert Recurrence Rule if applicable
    IF v_is_rec THEN
        INSERT INTO public.schedule_recurrence (
            id, schedule_id, frequency, interval, days_of_week, day_of_month, month_of_year,
            end_type, end_count, end_date, exceptions, created_at
        ) VALUES (
            gen_random_uuid(), v_sched_id,
            v_freq,
            COALESCE(
                CASE WHEN jsonb_typeof(p_data->'recurrence') = 'object' THEN (p_data->'recurrence'->>'interval')::INT ELSE NULL END,
                (p_data->>'interval')::INT, 1
            ),
            COALESCE(
                CASE WHEN jsonb_typeof(p_data->'recurrence') = 'object' THEN p_data->'recurrence'->'days_of_week' ELSE NULL END,
                p_data->'days_of_week', '[]'::jsonb
            ),
            (COALESCE(
                CASE WHEN jsonb_typeof(p_data->'recurrence') = 'object' THEN p_data->'recurrence'->>'day_of_month' ELSE NULL END,
                p_data->>'day_of_month'
            ))::INT,
            (COALESCE(
                CASE WHEN jsonb_typeof(p_data->'recurrence') = 'object' THEN p_data->'recurrence'->>'month_of_year' ELSE NULL END,
                p_data->>'month_of_year'
            ))::INT,
            COALESCE(
                CASE WHEN jsonb_typeof(p_data->'recurrence') = 'object' THEN p_data->'recurrence'->>'end_type' ELSE NULL END,
                p_data->>'end_type', 'never'
            ),
            (COALESCE(
                CASE WHEN jsonb_typeof(p_data->'recurrence') = 'object' THEN p_data->'recurrence'->>'end_count' ELSE NULL END,
                p_data->>'end_count'
            ))::INT,
            (COALESCE(
                CASE WHEN jsonb_typeof(p_data->'recurrence') = 'object' THEN p_data->'recurrence'->>'end_date' ELSE NULL END,
                p_data->>'end_date'
            ))::DATE,
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
                CASE WHEN v_p_elem->>'user_id' IS NOT NULL AND v_p_elem->>'user_id' != '' THEN (v_p_elem->>'user_id')::UUID ELSE NULL END,
                v_p_elem->>'target_role', v_p_elem->>'target_department', v_p_elem->>'target_class', v_p_elem->>'target_section',
                COALESCE(v_p_elem->>'participant_type', 'individual'),
                COALESCE(v_p_elem->>'participation_role', 'required'),
                COALESCE(v_p_elem->>'permission', 'can_view'),
                'pending', NOW()
            );
        END LOOP;
    END IF;

    -- 7. Insert Resources
    IF jsonb_array_length(COALESCE(p_data->'resources', '[]'::jsonb)) > 0 THEN
        FOR v_r_elem IN SELECT * FROM jsonb_array_elements(p_data->'resources') LOOP
            IF v_r_elem->>'resource_id' IS NOT NULL AND v_r_elem->>'resource_id' != '' THEN
                INSERT INTO public.resource_bookings (
                    id, schedule_id, resource_id, start_time, end_time, status, created_at
                ) VALUES (
                    gen_random_uuid(), v_sched_id, (v_r_elem->>'resource_id')::UUID, v_start_time, v_end_time, 'confirmed', NOW()
                );
            END IF;
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

    RETURN jsonb_build_object('success', TRUE, 'data', to_jsonb(v_sched_rec), 'message', 'Schedule created successfully.');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
