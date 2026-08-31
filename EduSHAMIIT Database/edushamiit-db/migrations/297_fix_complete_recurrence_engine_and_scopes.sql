-- ============================================================================
-- Migration: 297_fix_complete_recurrence_engine_and_scopes.sql
-- Description:
--   1. Ensures public.schedule_recurrence is always updated / inserted / deleted
--      atomically across all recurrence scopes (entire_series, this_event, following_events).
--   2. Preserves audience deduplication, class-section-subject allocations, and
--      resource / trip associations.
--   3. Supports all recurrence frequencies: daily, weekdays, weekly, monthly, yearly, custom.
--   4. Supports all recurrence end types: never, after_count, until_date.
-- ============================================================================

-- Ensure unique index on schedule_recurrence (schedule_id)
CREATE UNIQUE INDEX IF NOT EXISTS idx_schedule_recurrence_schedule_id
ON public.schedule_recurrence (schedule_id);

-- Ensure exceptions column has proper defaults
ALTER TABLE public.schedule_recurrence 
ALTER COLUMN exceptions SET DEFAULT '[]'::jsonb;

-- Helper function to exclude a date from recurring schedule
CREATE OR REPLACE FUNCTION public.exclude_recurring_occurrence(
    p_schedule_id UUID,
    p_instance_date DATE
) RETURNS VOID AS $$
DECLARE
    v_rec_id UUID;
    v_date_str TEXT := to_char(p_instance_date, 'YYYY-MM-DD');
BEGIN
    SELECT id INTO v_rec_id 
    FROM public.schedule_recurrence 
    WHERE schedule_id = p_schedule_id;

    IF v_rec_id IS NOT NULL THEN
        UPDATE public.schedule_recurrence
        SET exceptions = CASE 
            WHEN exceptions IS NULL OR exceptions = 'null'::jsonb THEN jsonb_build_array(v_date_str)
            WHEN exceptions ? v_date_str THEN exceptions
            ELSE exceptions || jsonb_build_array(v_date_str)
        END,
        updated_at = NOW()
        WHERE id = v_rec_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 1. Stored Procedure: fn_create_schedule (With complete recurrence handling)
CREATE OR REPLACE FUNCTION public.fn_create_schedule(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
) RETURNS JSONB AS $$
DECLARE
    v_sched_id UUID := gen_random_uuid();
    v_cal_id UUID;
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_route_id UUID := NULL;
    v_aud_type TEXT := 'individual';
    v_target_roles JSONB := '[]'::jsonb;
    v_target_classes JSONB := '[]'::jsonb;
    v_target_class_sections JSONB := '[]'::jsonb;
    v_target_users JSONB := '[]'::jsonb;
    v_force_override BOOLEAN := COALESCE((p_data->>'force_override_conflicts')::BOOLEAN, FALSE);
    v_conflicts JSONB := '[]'::jsonb;
    v_r_elem JSONB;
    v_rem_elem JSONB;
    v_res_conflict RECORD;
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
    -- 1. Parse timestamps & calendar
    v_start_time := public.parse_tz_timestamp(p_data->>'start_time', COALESCE(p_data->>'timezone', 'Asia/Kolkata'));
    v_end_time := public.parse_tz_timestamp(p_data->>'end_time', COALESCE(p_data->>'timezone', 'Asia/Kolkata'));

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

    -- 4. Extract recurrence parameters robustly
    IF jsonb_typeof(p_data->'recurrence') = 'object' THEN
        v_rec_obj := p_data->'recurrence';
        v_freq := COALESCE(v_rec_obj->>'frequency', 'none');
        v_interval := COALESCE((v_rec_obj->>'interval')::INT, 1);
        v_days := COALESCE(v_rec_obj->'days_of_week', '[]'::jsonb);
        v_end_type := COALESCE(v_rec_obj->>'end_type', 'never');
        v_end_count := (v_rec_obj->>'end_count')::INT;
        IF v_rec_obj->>'end_date' IS NOT NULL AND v_rec_obj->>'end_date' != '' THEN
            v_end_date := (v_rec_obj->>'end_date')::DATE;
        END IF;
    ELSIF p_data->>'frequency' IS NOT NULL THEN
        v_freq := p_data->>'frequency';
        v_interval := COALESCE((p_data->>'interval')::INT, 1);
        v_days := COALESCE(p_data->'days_of_week', '[]'::jsonb);
        v_end_type := COALESCE(p_data->>'end_type', 'never');
        v_end_count := (p_data->>'end_count')::INT;
        IF p_data->>'end_date' IS NOT NULL AND p_data->>'end_date' != '' THEN
            v_end_date := (p_data->>'end_date')::DATE;
        END IF;
    END IF;

    v_is_rec := COALESCE((p_data->>'is_recurring')::BOOLEAN, (v_freq != 'none' AND v_freq IS NOT NULL));

    -- 5. Insert Schedule Master
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

    -- 6. Resolve & Insert Participants atomically with deduplication
    PERFORM public.fn_resolve_schedule_audience(
        p_school_id,
        v_sched_id,
        v_target_roles,
        v_target_classes,
        v_target_class_sections,
        v_target_users
    );

    -- 7. Insert Resource Bookings
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

    -- 8. Insert Reminders
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

    -- 9. Recurrence Rule setup
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


-- 2. Stored Procedure: fn_update_schedule (Comprehensive Recurrence & Audience Resolution)
CREATE OR REPLACE FUNCTION public.fn_update_schedule(
    p_schedule_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB,
    p_recurrence_scope TEXT DEFAULT 'entire_series',
    p_target_instance_date DATE DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_old public.schedules%ROWTYPE;
    v_updated public.schedules%ROWTYPE;
    v_target_series_id UUID;
    v_new_id UUID := gen_random_uuid();
    v_master_start TIMESTAMPTZ;
    v_master_end TIMESTAMPTZ;
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_tz TEXT;
    v_effective_scope TEXT := p_recurrence_scope;
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
    v_target_class_sections JSONB := '[]'::jsonb;
    v_target_users JSONB := '[]'::jsonb;
    v_duration INTERVAL;
    v_new_start TIMESTAMP WITH TIME ZONE;
    v_new_end TIMESTAMP WITH TIME ZONE;
    v_new_payload_start TIMESTAMP WITH TIME ZONE;
    v_new_payload_end TIMESTAMP WITH TIME ZONE;
    v_target_date DATE;
    v_rec_obj JSONB;
    v_has_recurrence_in_payload BOOLEAN := FALSE;
    v_status TEXT;
    v_cancel_reason TEXT;
    v_route_id UUID;
BEGIN
    -- Fetch original schedule
    SELECT * INTO v_old 
    FROM public.schedules 
    WHERE id = p_schedule_id AND (school_id = p_school_id OR school_id IS NULL) AND deleted_at IS NULL;

    IF v_old.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Schedule not found or deleted.');
    END IF;

    v_tz := COALESCE(p_data->>'timezone', v_old.timezone, 'Asia/Kolkata');

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

    -- If target is a single non-recurring event and remains non-recurring, force entire_series scope
    IF NOT v_old.is_recurring AND v_old.recurring_parent_id IS NULL AND v_freq = 'none' THEN
        v_effective_scope := 'entire_series';
    END IF;

    -- Identify target series ID
    IF v_old.is_recurring THEN
        v_target_series_id := v_old.id;
    ELSE
        v_target_series_id := COALESCE(v_old.recurring_parent_id, v_old.id);
    END IF;

    v_target_date := COALESCE(p_target_instance_date, v_old.original_instance_date, (v_old.start_time AT TIME ZONE v_tz)::DATE);

    v_status := COALESCE(p_data->>'status', v_old.status, 'confirmed');
    v_cancel_reason := COALESCE(p_data->>'cancellation_reason', v_old.cancellation_reason);

    -- Parse audience targets
    v_target_roles := COALESCE(p_data->'target_roles', v_old.target_roles, '[]'::jsonb);
    v_target_classes := COALESCE(p_data->'target_classes', v_old.target_classes, '[]'::jsonb);
    v_target_class_sections := COALESCE(p_data->'target_class_sections', v_old.target_class_sections, '[]'::jsonb);
    v_target_users := COALESCE(p_data->'target_user_ids', v_old.target_user_ids, '[]'::jsonb);

    v_aud_type := v_old.audience_type;
    IF jsonb_array_length(v_target_roles) > 0 THEN
        v_aud_type := 'role';
    ELSIF jsonb_array_length(v_target_class_sections) > 0 OR jsonb_array_length(v_target_classes) > 0 THEN
        v_aud_type := 'class_section';
    ELSIF (COALESCE(p_data->>'visibility', v_old.visibility)) = 'institution_wide' THEN
        v_aud_type := 'all';
    END IF;

    IF p_data->>'route_id' IS NOT NULL THEN
        v_route_id := NULLIF(p_data->>'route_id', '')::UUID;
    ELSE
        v_route_id := v_old.route_id;
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

    -- Normalize days of week ONLY for weekly recurrence if empty
    IF v_freq = 'weekly' AND (v_days IS NULL OR jsonb_array_length(v_days) = 0) THEN
        v_days := jsonb_build_array(UPPER(SUBSTRING(to_char((COALESCE(v_old.start_time, NOW()) AT TIME ZONE v_tz), 'Day') FROM 1 FOR 2)));
    ELSIF v_freq = 'weekdays' THEN
        v_days := '["MO", "TU", "WE", "TH", "FR"]'::jsonb;
    END IF;

    -- ========================================================================
    -- 1. SCOPE: THIS EVENT ONLY ('this_event')
    -- ========================================================================
    IF v_effective_scope = 'this_event' AND v_target_date IS NOT NULL THEN
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

        -- Insert override row on new date/time with original_instance_date pointing to v_target_date
        INSERT INTO public.schedules (
            id, school_id, calendar_id, route_id, title, description, schedule_type, category, color, priority,
            status, approval_status, cancellation_reason, cancelled_at, cancelled_by,
            start_time, end_time, is_all_day, timezone,
            location_name, location_address, building, room, virtual_meeting_url, virtual_meeting_provider,
            organizer_id, created_by, visibility, is_recurring, recurring_parent_id, original_instance_date,
            recurrence_exception_type, metadata, audience_type, target_roles, target_classes, target_class_sections, target_user_ids, created_at, updated_at
        ) VALUES (
            v_new_id, p_school_id, COALESCE((p_data->>'calendar_id')::UUID, v_old.calendar_id),
            v_route_id,
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
            COALESCE(p_data->'metadata', v_old.metadata), v_aud_type, v_target_roles, v_target_classes, v_target_class_sections, v_target_users, NOW(), NOW()
        ) RETURNING * INTO v_updated;

        -- Transfer existing vehicle_trips for this date to v_new_id
        UPDATE public.vehicle_trips
        SET schedule_id = v_new_id,
            route_id = v_updated.route_id,
            vehicle_id = (SELECT vehicle_id FROM public.transport_routes WHERE id = v_updated.route_id),
            start_date = (v_new_start AT TIME ZONE v_tz)::DATE::TEXT,
            end_date = (v_new_end AT TIME ZONE v_tz)::DATE::TEXT,
            schedule_instance_date = (v_new_start AT TIME ZONE v_tz)::DATE,
            start_time = to_char(v_new_start AT TIME ZONE v_tz, 'HH12:MI AM'),
            end_time = to_char(v_new_end AT TIME ZONE v_tz, 'HH12:MI AM'),
            scheduled_start = v_new_start,
            status = CASE WHEN v_status = 'cancelled' THEN 'cancelled' ELSE status END,
            updated_at = NOW()
        WHERE (schedule_id = v_target_series_id OR schedule_id = p_schedule_id OR schedule_id IN (SELECT id FROM public.schedules WHERE recurring_parent_id = v_target_series_id))
          AND (schedule_instance_date = v_target_date OR start_date = v_target_date::TEXT);

        -- Exclude the original instance date from target series recurrence
        PERFORM public.exclude_recurring_occurrence(v_target_series_id, v_target_date);
        IF p_schedule_id != v_target_series_id THEN
            PERFORM public.exclude_recurring_occurrence(p_schedule_id, v_target_date);
        END IF;

        UPDATE public.schedules SET is_recurring = TRUE WHERE id = v_target_series_id;

        -- Soft delete previous single-event override rows for this date
        UPDATE public.schedules
        SET deleted_at = NOW(), status = 'cancelled', updated_at = NOW()
        WHERE (recurring_parent_id = v_target_series_id OR recurring_parent_id = p_schedule_id OR id = p_schedule_id)
          AND (original_instance_date = v_target_date OR DATE(start_time AT TIME ZONE v_tz) = v_target_date)
          AND (recurrence_exception_type = 'override' OR is_recurring = FALSE)
          AND id != v_new_id;

        -- Audience resolution for this override row
        PERFORM public.fn_resolve_schedule_audience(
            p_school_id,
            v_new_id,
            v_target_roles,
            v_target_classes,
            v_target_class_sections,
            v_target_users
        );

        -- Resources for this override
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

        -- Reminders for this override
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
    ELSIF v_effective_scope IN ('this_and_following', 'following_events') AND v_target_date IS NOT NULL THEN
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
            recurrence_exception_type, metadata, audience_type, target_roles, target_classes, target_class_sections, target_user_ids, created_at, updated_at
        ) VALUES (
            v_new_id, p_school_id, COALESCE((p_data->>'calendar_id')::UUID, v_old.calendar_id),
            v_route_id,
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
            COALESCE(p_data->'metadata', v_old.metadata), v_aud_type, v_target_roles, v_target_classes, v_target_class_sections, v_target_users, NOW(), NOW()
        ) RETURNING * INTO v_updated;

        -- Transfer existing vehicle_trips from target_date onwards to v_new_id
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

        -- Soft delete previous override rows from target_date onwards
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

        -- Audience resolution for this split series
        PERFORM public.fn_resolve_schedule_audience(
            p_school_id,
            v_new_id,
            v_target_roles,
            v_target_classes,
            v_target_class_sections,
            v_target_users
        );

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
    -- 3. SCOPE: ALL EVENTS IN SERIES ('all_events' / 'entire_series') OR SINGLE EVENT
    -- ========================================================================
    ELSE
        SELECT start_time, end_time INTO v_master_start, v_master_end
        FROM public.schedules
        WHERE id = v_target_series_id;

        IF v_master_start IS NULL THEN
            v_master_start := v_old.start_time;
            v_master_end := v_old.end_time;
        END IF;

        IF p_data->>'start_time' IS NOT NULL AND p_data->>'start_time' != '' THEN
            v_new_payload_start := public.parse_tz_timestamp(p_data->>'start_time', v_tz);
            IF p_data->>'end_time' IS NOT NULL AND p_data->>'end_time' != '' THEN
                v_new_payload_end := public.parse_tz_timestamp(p_data->>'end_time', v_tz);
            ELSE
                v_new_payload_end := v_new_payload_start + COALESCE(v_master_end - v_master_start, INTERVAL '1 hour');
            END IF;
            v_duration := COALESCE(v_new_payload_end - v_new_payload_start, v_master_end - v_master_start, INTERVAL '1 hour');

            IF NOT v_old.is_recurring THEN
                -- Single non-recurring event: update start and end time directly
                v_start_time := v_new_payload_start;
                v_end_time := v_new_payload_end;
            ELSIF v_old.timezone != v_tz OR (v_master_start AT TIME ZONE v_old.timezone)::DATE = (v_new_payload_start AT TIME ZONE v_tz)::DATE THEN
                -- Master start date or timezone changed for recurring series:
                v_start_time := v_new_payload_start;
                v_end_time := v_new_payload_end;
            ELSE
                -- Future instance clicked (e.g. Day 3) in same timezone: preserve Day 1 start date
                v_start_time := (((v_master_start AT TIME ZONE v_tz)::DATE)::TEXT || ' ' || to_char((v_new_payload_start AT TIME ZONE v_tz)::TIME, 'HH24:MI:SS'))::TIMESTAMP AT TIME ZONE v_tz;
                v_end_time := v_start_time + v_duration;
            END IF;
        ELSE
            v_start_time := v_master_start;
            v_end_time := v_master_end;
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
            route_id = v_route_id,
            metadata = COALESCE(p_data->'metadata', metadata),
            audience_type = v_aud_type,
            target_roles = v_target_roles,
            target_classes = v_target_classes,
            target_class_sections = v_target_class_sections,
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

        -- Update vehicle trips for single event or series start
        UPDATE public.vehicle_trips
        SET route_id = v_updated.route_id,
            vehicle_id = (SELECT vehicle_id FROM public.transport_routes WHERE id = v_updated.route_id),
            start_date = (v_start_time AT TIME ZONE v_tz)::DATE::TEXT,
            end_date = (v_end_time AT TIME ZONE v_tz)::DATE::TEXT,
            schedule_instance_date = (v_start_time AT TIME ZONE v_tz)::DATE,
            start_time = to_char(v_start_time AT TIME ZONE v_tz, 'HH12:MI AM'),
            end_time = to_char(v_end_time AT TIME ZONE v_tz, 'HH12:MI AM'),
            scheduled_start = v_start_time,
            status = CASE WHEN v_status = 'cancelled' THEN 'cancelled' ELSE status END,
            updated_at = NOW()
        WHERE schedule_id = v_target_series_id
          AND (schedule_instance_date = (v_old.start_time AT TIME ZONE v_old.timezone)::DATE OR schedule_instance_date = (v_start_time AT TIME ZONE v_tz)::DATE OR v_old.is_recurring = FALSE);

        -- Update or insert recurrence details for this series while PRESERVING exceptions
        IF v_freq != 'none' THEN
            IF EXISTS (SELECT 1 FROM public.schedule_recurrence WHERE schedule_id = v_target_series_id) THEN
                UPDATE public.schedule_recurrence
                SET frequency = v_freq,
                    interval = GREATEST(v_interval, 1),
                    days_of_week = v_days,
                    end_type = v_end_type,
                    end_count = v_end_count,
                    end_date = v_end_date,
                    exceptions = COALESCE(exceptions, '[]'::jsonb),
                    updated_at = NOW()
                WHERE schedule_id = v_target_series_id;
            ELSE
                INSERT INTO public.schedule_recurrence (
                    id, schedule_id, frequency, interval, days_of_week, end_type, end_count, end_date, exceptions, created_at, updated_at
                ) VALUES (
                    gen_random_uuid(), v_target_series_id, v_freq, GREATEST(v_interval, 1), v_days, v_end_type, v_end_count, v_end_date, '[]'::jsonb, NOW(), NOW()
                );
            END IF;
        ELSE
            -- Non-recurring now: remove recurrence rule
            DELETE FROM public.schedule_recurrence WHERE schedule_id = v_target_series_id;
        END IF;

        -- Atomically refresh Participants without duplication
        IF p_data->'target_class_sections' IS NOT NULL OR p_data->'target_roles' IS NOT NULL OR p_data->'target_user_ids' IS NOT NULL OR p_data->'participants' IS NOT NULL THEN
            DELETE FROM public.schedule_participants WHERE schedule_id = v_target_series_id;

            PERFORM public.fn_resolve_schedule_audience(
                p_school_id,
                v_target_series_id,
                v_target_roles,
                v_target_classes,
                v_target_class_sections,
                v_target_users
            );
        END IF;

        -- Refresh Resource Bookings
        IF p_data->'resources' IS NOT NULL THEN
            DELETE FROM public.resource_bookings WHERE schedule_id = v_target_series_id;
            IF jsonb_array_length(p_data->'resources') > 0 THEN
                FOR v_r_elem IN SELECT * FROM jsonb_array_elements(p_data->'resources') LOOP
                    IF v_r_elem->>'resource_id' IS NOT NULL AND v_r_elem->>'resource_id' != '' THEN
                        INSERT INTO public.resource_bookings (
                            id, schedule_id, resource_id, start_time, end_time, status, created_at
                        ) VALUES (
                            gen_random_uuid(), v_target_series_id,
                            (v_r_elem->>'resource_id')::UUID,
                            v_start_time, v_end_time,
                            'confirmed', NOW()
                        );
                    END IF;
                END LOOP;
            END IF;
        END IF;

        -- Refresh Reminders
        IF p_data->'reminders' IS NOT NULL THEN
            DELETE FROM public.schedule_reminders WHERE schedule_id = v_target_series_id;
            IF jsonb_array_length(p_data->'reminders') > 0 THEN
                FOR v_rem_elem IN SELECT * FROM jsonb_array_elements(p_data->'reminders') LOOP
                    INSERT INTO public.schedule_reminders (
                        id, schedule_id, minutes_before, channel, is_sent, created_at
                    ) VALUES (
                        gen_random_uuid(), v_target_series_id,
                        (v_rem_elem->>'minutes_before')::INT,
                        COALESCE(v_rem_elem->>'channel', 'in_app'),
                        FALSE, NOW()
                    );
                END LOOP;
            END IF;
        END IF;

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Schedule series updated successfully.',
            'data', to_jsonb(v_updated)
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Stored Procedure: fn_get_schedule_details (Return Recurrence for Master or Instance)
DROP FUNCTION IF EXISTS public.fn_get_schedule_details(UUID, UUID, DATE);
CREATE OR REPLACE FUNCTION public.fn_get_schedule_details(
    p_school_id UUID,
    p_schedule_id UUID,
    p_target_instance_date DATE DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_sched public.schedules%ROWTYPE;
    v_cal public.calendars%ROWTYPE;
    v_org public.profiles%ROWTYPE;
    v_participants JSONB := '[]'::jsonb;
    v_resources JSONB := '[]'::jsonb;
    v_reminders JSONB := '[]'::jsonb;
    v_comments JSONB := '[]'::jsonb;
    v_recurrence JSONB := NULL;
    v_res JSONB;
    v_trip_id UUID;
    v_trip_status TEXT;
    v_master_id UUID;
BEGIN
    SELECT * INTO v_sched
    FROM public.schedules
    WHERE id = p_schedule_id AND (school_id = p_school_id OR school_id IS NULL) AND deleted_at IS NULL;

    IF v_sched.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Schedule not found');
    END IF;

    v_master_id := COALESCE(v_sched.recurring_parent_id, v_sched.id);

    SELECT * INTO v_cal FROM public.calendars WHERE id = v_sched.calendar_id;
    SELECT * INTO v_org FROM public.profiles WHERE id = v_sched.organizer_id;

    -- Comments aggregation
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', sc.id,
            'schedule_id', sc.schedule_id,
            'user_id', sc.user_id,
            'comment_text', sc.comment_text,
            'user_name', p.full_name,
            'user_avatar', p.avatar_url,
            'created_at', sc.created_at,
            'updated_at', sc.updated_at
        ) ORDER BY sc.created_at ASC
    ), '[]'::jsonb)
    INTO v_comments
    FROM public.schedule_comments sc
    LEFT JOIN public.profiles p ON p.id = sc.user_id
    WHERE sc.schedule_id = p_schedule_id OR (v_sched.recurring_parent_id IS NOT NULL AND sc.schedule_id = v_sched.recurring_parent_id);

    -- Participants aggregation: Deduplicated, with clear full_name for group and individual items
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', sp.id,
            'user_id', sp.user_id,
            'target_role', sp.target_role,
            'target_class', sp.target_class,
            'target_section', sp.target_section,
            'target_subject_id', sp.target_subject_id,
            'target_subject', sp.target_subject,
            'class_id', sp.class_id,
            'section_id', sp.section_id,
            'participant_type', sp.participant_type,
            'participation_role', sp.participation_role,
            'permission', sp.permission,
            'rsvp_status', sp.rsvp_status,
            'decline_reason', sp.decline_reason,
            'rsvp_at', sp.rsvp_at,
            'full_name', COALESCE(
                p.full_name,
                CASE 
                    WHEN sp.target_subject IS NOT NULL THEN (sp.target_class || ' - ' || sp.target_section || ' • ' || sp.target_subject)
                    WHEN sp.target_section IS NOT NULL THEN (sp.target_class || ' - ' || sp.target_section)
                    WHEN sp.target_class IS NOT NULL THEN sp.target_class
                    WHEN sp.target_role IS NOT NULL THEN ('All ' || initcap(replace(sp.target_role, '_', ' ')))
                    ELSE 'Participant'
                END
            ),
            'email', p.email,
            'avatar_url', p.avatar_url,
            'role', COALESCE(p.role, sp.target_role, (
                CASE 
                    WHEN sp.target_subject IS NOT NULL THEN 'Subject Offering'
                    WHEN sp.target_section IS NOT NULL THEN 'Class-Section'
                    ELSE 'Group'
                END
            ))
        )
    ), '[]'::jsonb)
    INTO v_participants
    FROM (
        SELECT DISTINCT ON (COALESCE(sp_inner.user_id, sp_inner.id))
            sp_inner.*
        FROM public.schedule_participants sp_inner
        WHERE sp_inner.schedule_id = p_schedule_id
        ORDER BY COALESCE(sp_inner.user_id, sp_inner.id), sp_inner.created_at ASC
    ) sp
    LEFT JOIN public.profiles p ON p.id = sp.user_id;

    -- Resources aggregation
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', rb.id,
            'resource_id', rb.resource_id,
            'name', cr.name,
            'code', cr.code,
            'type', cr.type,
            'building', cr.building,
            'room_number', cr.room_number,
            'status', rb.status
        )
    ), '[]'::jsonb)
    INTO v_resources
    FROM public.resource_bookings rb
    JOIN public.calendar_resources cr ON cr.id = rb.resource_id
    WHERE rb.schedule_id = p_schedule_id;

    -- Reminders aggregation
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', sr.id,
            'minutes_before', sr.minutes_before,
            'channel', sr.channel,
            'is_sent', sr.is_sent
        )
    ), '[]'::jsonb)
    INTO v_reminders
    FROM public.schedule_reminders sr
    WHERE sr.schedule_id = p_schedule_id;

    -- Recurrence rule (Lookup from master if this is an instance / override)
    SELECT jsonb_build_object(
        'id', rec.id,
        'frequency', rec.frequency,
        'interval', rec.interval,
        'days_of_week', rec.days_of_week,
        'day_of_month', rec.day_of_month,
        'month_of_year', rec.month_of_year,
        'end_type', rec.end_type,
        'end_count', rec.end_count,
        'end_date', rec.end_date,
        'exceptions', rec.exceptions
    )
    INTO v_recurrence
    FROM public.schedule_recurrence rec
    WHERE rec.schedule_id = v_master_id;

    -- Real-time trip status if route linked
    IF v_sched.route_id IS NOT NULL THEN
        SELECT id, status INTO v_trip_id, v_trip_status
        FROM public.vehicle_trips
        WHERE (schedule_id = p_schedule_id OR (v_sched.recurring_parent_id IS NOT NULL AND schedule_id = v_sched.recurring_parent_id))
          AND (
              schedule_instance_date = COALESCE(p_target_instance_date, v_sched.original_instance_date, (v_sched.start_time AT TIME ZONE COALESCE(v_sched.timezone, 'Asia/Kolkata'))::DATE)
              OR start_date = COALESCE(p_target_instance_date::TEXT, v_sched.original_instance_date::TEXT, (v_sched.start_time AT TIME ZONE COALESCE(v_sched.timezone, 'Asia/Kolkata'))::DATE::TEXT)
          )
        ORDER BY CASE WHEN status IN ('in_progress', 'paused') THEN 1 WHEN status = 'completed' THEN 2 ELSE 3 END, updated_at DESC
        LIMIT 1;
    END IF;

    v_res := to_jsonb(v_sched) || jsonb_build_object(
        'calendar_name', v_cal.name,
        'calendar_color', v_cal.color,
        'organizer_name', v_org.full_name,
        'organizer_avatar', v_org.avatar_url,
        'is_recurring', (v_sched.is_recurring OR v_recurrence IS NOT NULL),
        'trip_id', v_trip_id,
        'trip_status', v_trip_status,
        'participants', v_participants,
        'resources', v_resources,
        'reminders', v_reminders,
        'recurrence', v_recurrence,
        'comments', v_comments
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', v_res
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
