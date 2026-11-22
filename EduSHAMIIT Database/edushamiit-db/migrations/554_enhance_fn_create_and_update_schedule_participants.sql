-- ============================================================================
-- Migration: 554_enhance_fn_create_and_update_schedule_participants.sql
-- Description:
--   Ensure fn_create_schedule and fn_update_schedule automatically extract audience
--   targeting parameters from p_data->'participants' when supplied as an array
--   of ParticipantAssignmentSchema objects.
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
    v_target_class_sections JSONB := '[]'::jsonb;
    v_target_users JSONB := '[]'::jsonb;
    v_p_elem JSONB;
    v_r_elem JSONB;
    v_rem_elem JSONB;
    v_sched_rec public.schedules%ROWTYPE;
    v_freq TEXT := 'none';
    v_interval INT := 1;
    v_end_type TEXT := 'never';
    v_end_count INT;
    v_end_date DATE;
    v_days JSONB := '[]'::jsonb;
    v_rec_obj JSONB;
    v_is_rec BOOLEAN := FALSE;
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
        WHERE (school_id = p_school_id OR school_id IS NULL)
          AND (owner_id = p_user_id OR type = 'personal')
          AND deleted_at IS NULL
        LIMIT 1;

        IF v_cal_id IS NULL THEN
            v_cal_id := gen_random_uuid();
            INSERT INTO public.calendars (id, school_id, name, color, type, is_default, owner_id, created_at, updated_at)
            VALUES (v_cal_id, p_school_id, 'My Calendar', '#4F46E5', 'personal', TRUE, p_user_id, NOW(), NOW());
        END IF;
    END IF;

    -- 2. Smart Conflict Detection
    IF NOT v_force_override THEN
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

    -- 3. Extract targeting parameters
    IF p_data->'target_roles' IS NOT NULL AND jsonb_typeof(p_data->'target_roles') = 'array' THEN
        v_target_roles := p_data->'target_roles';
    END IF;
    IF p_data->'target_classes' IS NOT NULL AND jsonb_typeof(p_data->'target_classes') = 'array' THEN
        v_target_classes := p_data->'target_classes';
    END IF;
    IF p_data->'target_class_sections' IS NOT NULL AND jsonb_typeof(p_data->'target_class_sections') = 'array' THEN
        v_target_class_sections := p_data->'target_class_sections';
    END IF;
    IF p_data->'target_user_ids' IS NOT NULL AND jsonb_typeof(p_data->'target_user_ids') = 'array' THEN
        v_target_users := p_data->'target_user_ids';
    END IF;

    -- Extract from participants array if provided
    IF p_data->'participants' IS NOT NULL AND jsonb_typeof(p_data->'participants') = 'array' THEN
        FOR v_p_elem IN SELECT * FROM jsonb_array_elements(p_data->'participants') LOOP
            IF v_p_elem->>'target_class' IS NOT NULL AND trim(v_p_elem->>'target_class') != '' THEN
                IF NOT (v_target_classes @> jsonb_build_array(trim(v_p_elem->>'target_class'))) THEN
                    v_target_classes := v_target_classes || jsonb_build_array(trim(v_p_elem->>'target_class'));
                END IF;
            END IF;
            IF v_p_elem->>'target_role' IS NOT NULL AND trim(v_p_elem->>'target_role') != '' THEN
                IF NOT (v_target_roles @> jsonb_build_array(trim(v_p_elem->>'target_role'))) THEN
                    v_target_roles := v_target_roles || jsonb_build_array(trim(v_p_elem->>'target_role'));
                END IF;
            END IF;
            IF v_p_elem->>'user_id' IS NOT NULL AND trim(v_p_elem->>'user_id') != '' THEN
                IF NOT (v_target_users @> jsonb_build_array(trim(v_p_elem->>'user_id'))) THEN
                    v_target_users := v_target_users || jsonb_build_array(trim(v_p_elem->>'user_id'));
                END IF;
            END IF;
            IF (v_p_elem->>'class_id' IS NOT NULL AND trim(v_p_elem->>'class_id') != '')
               OR (v_p_elem->>'section_id' IS NOT NULL AND trim(v_p_elem->>'section_id') != '') THEN
                v_target_class_sections := v_target_class_sections || jsonb_build_array(v_p_elem);
            END IF;
        END LOOP;
    END IF;

    IF jsonb_array_length(v_target_roles) > 0 THEN
        v_aud_type := 'role';
    ELSIF jsonb_array_length(v_target_class_sections) > 0 OR jsonb_array_length(v_target_classes) > 0 THEN
        v_aud_type := 'class_section';
    ELSIF (p_data->>'visibility') = 'institution_wide' THEN
        v_aud_type := 'all';
    END IF;

    IF p_data->>'route_id' IS NOT NULL AND (p_data->>'route_id') != '' THEN
        v_route_id := (p_data->>'route_id')::UUID;
    END IF;

    -- Recurrence rule parameters
    IF p_data->'recurrence' IS NOT NULL AND jsonb_typeof(p_data->'recurrence') = 'object' THEN
        v_rec_obj := p_data->'recurrence';
        v_freq := COALESCE(v_rec_obj->>'frequency', 'none');
        v_interval := COALESCE((v_rec_obj->>'interval')::INT, 1);
        v_end_type := COALESCE(v_rec_obj->>'end_type', 'never');
        v_end_count := (v_rec_obj->>'end_count')::INT;
        IF v_rec_obj->>'end_date' IS NOT NULL AND v_rec_obj->>'end_date' != '' THEN
            v_end_date := (v_rec_obj->>'end_date')::DATE;
        END IF;
        IF v_rec_obj->'days_of_week' IS NOT NULL AND jsonb_typeof(v_rec_obj->'days_of_week') = 'array' THEN
            v_days := v_rec_obj->'days_of_week';
        END IF;
    ELSE
        v_freq := COALESCE(p_data->>'frequency', 'none');
        v_interval := COALESCE((p_data->>'interval')::INT, 1);
        v_end_type := COALESCE(p_data->>'end_type', 'never');
        v_end_count := (p_data->>'end_count')::INT;
        IF p_data->>'end_date' IS NOT NULL AND p_data->>'end_date' != '' THEN
            v_end_date := (p_data->>'end_date')::DATE;
        END IF;
    END IF;

    v_is_rec := COALESCE((p_data->>'is_recurring')::BOOLEAN, (v_freq != 'none' AND v_freq IS NOT NULL));

    -- 4. Insert Schedule Master
    INSERT INTO public.schedules (
        id, school_id, calendar_id, title, description, schedule_type, category, color, priority,
        status, approval_status, start_time, end_time, is_all_day, timezone,
        location_name, location_address, building, room, landmark, latitude, longitude,
        virtual_meeting_url, virtual_meeting_provider, organizer_id, created_by, visibility,
        is_recurring, route_id, audience_type, target_roles, target_classes, target_class_sections, target_user_ids,
        metadata, created_at, updated_at
    ) VALUES (
        v_sched_id, p_school_id, v_cal_id,
        p_data->>'title',
        p_data->>'description',
        COALESCE(p_data->>'schedule_type', 'Meeting'),
        COALESCE(p_data->>'category', 'General'),
        COALESCE(p_data->>'color', '#4F46E5'),
        COALESCE(p_data->>'priority', 'normal'),
        'confirmed', 'approved',
        v_start_time, v_end_time,
        COALESCE((p_data->>'is_all_day')::BOOLEAN, FALSE),
        COALESCE(p_data->>'timezone', 'Asia/Kolkata'),
        p_data->>'location_name',
        p_data->>'location_address',
        p_data->>'building',
        p_data->>'room',
        p_data->>'landmark',
        (p_data->>'latitude')::DOUBLE PRECISION,
        (p_data->>'longitude')::DOUBLE PRECISION,
        p_data->>'virtual_meeting_url',
        p_data->>'virtual_meeting_provider',
        p_user_id, p_user_id,
        COALESCE(p_data->>'visibility', 'shared'),
        v_is_rec,
        v_route_id,
        v_aud_type,
        v_target_roles,
        v_target_classes,
        v_target_class_sections,
        v_target_users,
        COALESCE(p_data->'metadata', '{}'::jsonb),
        NOW(), NOW()
    ) RETURNING * INTO v_sched_rec;

    -- 5. Resolve & Insert Participants atomically with deduplication
    PERFORM public.fn_resolve_schedule_audience(
        p_school_id,
        v_sched_id,
        v_target_roles,
        v_target_classes,
        v_target_class_sections,
        v_target_users
    );

    -- 6. Insert Resource Bookings
    IF jsonb_array_length(COALESCE(p_data->'resources', '[]'::jsonb)) > 0 THEN
        FOR v_r_elem IN SELECT * FROM jsonb_array_elements(p_data->'resources') LOOP
            INSERT INTO public.resource_bookings (
                id, schedule_id, resource_id, start_time, end_time, status, created_at
            ) VALUES (
                gen_random_uuid(), v_sched_id,
                (v_r_elem->>'resource_id')::UUID,
                v_start_time, v_end_time,
                'confirmed', NOW()
            );
        END LOOP;
    END IF;

    -- 7. Insert Reminders
    IF jsonb_array_length(COALESCE(p_data->'reminders', '[]'::jsonb)) > 0 THEN
        FOR v_rem_elem IN SELECT * FROM jsonb_array_elements(p_data->'reminders') LOOP
            INSERT INTO public.schedule_reminders (
                id, schedule_id, minutes_before, channel, is_sent, created_at
            ) VALUES (
                gen_random_uuid(), v_sched_id,
                (v_rem_elem->>'minutes_before')::INT,
                COALESCE(v_rem_elem->>'channel', 'in_app'),
                FALSE, NOW()
            );
        END LOOP;
    END IF;

    -- 8. Recurrence Rule setup
    IF v_is_rec = TRUE AND v_freq != 'none' THEN
        INSERT INTO public.schedule_recurrence (
            id, schedule_id, frequency, interval, days_of_week, day_of_month, month_of_year,
            end_type, end_count, end_date, exceptions, created_at, updated_at
        ) VALUES (
            gen_random_uuid(), v_sched_id,
            v_freq,
            GREATEST(v_interval, 1),
            v_days,
            (COALESCE(v_rec_obj->>'day_of_month', p_data->>'day_of_month'))::INT,
            (COALESCE(v_rec_obj->>'month_of_year', p_data->>'month_of_year'))::INT,
            v_end_type,
            v_end_count,
            v_end_date,
            '[]'::jsonb,
            NOW(), NOW()
        )
        ON CONFLICT (schedule_id) DO UPDATE
        SET frequency = EXCLUDED.frequency,
            interval = EXCLUDED.interval,
            days_of_week = EXCLUDED.days_of_week,
            day_of_month = EXCLUDED.day_of_month,
            month_of_year = EXCLUDED.month_of_year,
            end_type = EXCLUDED.end_type,
            end_count = EXCLUDED.end_count,
            end_date = EXCLUDED.end_date,
            updated_at = NOW();
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Schedule created successfully.',
        'data', to_jsonb(v_sched_rec)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
