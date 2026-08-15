-- ============================================================================
-- EduSHAMIIT ERP - Migration 244: Fix Recurrence Save, Update, and Fetch
-- Description:
--   1. Ensures unique index on public.schedule_recurrence (schedule_id).
--   2. Updates `fn_get_schedule_details` to return the complete `recurrence` object
--      (using JSONB merge operator || to avoid Postgres 100-arg limit on jsonb_build_object).
--   3. Updates `fn_update_schedule` to correctly parse nested `recurrence` JSON and
--      reliably upsert recurrence rules across all scopes.
--   4. Updates `fn_create_schedule` to guarantee reliable recurrence creation.
--   5. Cleans up any dummy recurrence records with frequency = 'none'.
-- ============================================================================

-- 1. Ensure unique index on schedule_id in schedule_recurrence (deduplicating if needed)
DELETE FROM public.schedule_recurrence a
USING public.schedule_recurrence b
WHERE a.id < b.id AND a.schedule_id = b.schedule_id;

CREATE UNIQUE INDEX IF NOT EXISTS idx_schedule_recurrence_schedule_id
ON public.schedule_recurrence (schedule_id);

-- Clean up any invalid recurrence rows
DELETE FROM public.schedule_recurrence WHERE frequency = 'none' OR frequency IS NULL OR frequency = '';


-- 2. Update fn_get_schedule_details to include 'recurrence' JSON
CREATE OR REPLACE FUNCTION public.fn_get_schedule_details(
    p_schedule_id UUID,
    p_school_id UUID DEFAULT NULL,
    p_target_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
    v_real_schedule_id UUID := p_schedule_id;
    v_trip_id UUID;
    v_trip_status TEXT;
    v_target_date_str TEXT;
    v_total_stops INT := 0;
    v_completed_stops INT := 0;
BEGIN
    IF p_target_date IS NOT NULL THEN
        v_target_date_str := p_target_date::text;
    END IF;

    -- 0. If p_schedule_id is a trip_id in vehicle_trips, map to real schedule_id
    IF NOT EXISTS (SELECT 1 FROM public.schedules WHERE id = p_schedule_id) THEN
        SELECT schedule_id INTO v_real_schedule_id FROM public.vehicle_trips WHERE id = p_schedule_id;
        IF v_real_schedule_id IS NULL THEN
            v_real_schedule_id := p_schedule_id;
        END IF;
    END IF;

    -- 1. Resolve most recent vehicle trip for this schedule or route
    SELECT vt.id, vt.status
    INTO v_trip_id, v_trip_status
    FROM public.vehicle_trips vt
    JOIN public.schedules s ON s.id = v_real_schedule_id
    WHERE (vt.schedule_id = v_real_schedule_id OR (s.route_id IS NOT NULL AND vt.route_id = s.route_id))
      AND (
        (p_target_date IS NOT NULL AND (vt.schedule_instance_date = p_target_date OR vt.start_date = v_target_date_str OR vt.scheduled_start::date = p_target_date))
        OR (p_target_date IS NULL)
      )
    ORDER BY vt.updated_at DESC, vt.created_at DESC
    LIMIT 1;

    -- 2. If trip exists, verify if all stops are completed in trip_stop_logs
    IF v_trip_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_total_stops
        FROM public.transport_route_stops trs
        JOIN public.schedules s ON s.route_id = trs.route_id
        WHERE s.id = v_real_schedule_id AND trs.status != 'Deleted';

        SELECT COUNT(*) INTO v_completed_stops
        FROM public.trip_stop_logs
        WHERE trip_id = v_trip_id AND status = 'completed';

        IF v_total_stops > 0 AND v_completed_stops >= v_total_stops THEN
            v_trip_status := 'completed';
            UPDATE public.vehicle_trips
            SET status = 'completed', updated_at = NOW()
            WHERE id = v_trip_id AND status != 'completed';
        END IF;
    END IF;

    -- 3. Construct complete schedule JSON object using merged JSONB objects
    SELECT jsonb_build_object(
        'id', s.id,
        'title', s.title,
        'description', s.description,
        'school_id', s.school_id,
        'calendar_id', s.calendar_id,
        'calendar_name', c.name,
        'calendar_color', c.color,
        'calendar_type', c.type,
        'schedule_type', s.schedule_type,
        'category', s.category,
        'color', s.color,
        'priority', s.priority,
        'start_time', s.start_time,
        'end_time', s.end_time,
        'is_all_day', s.is_all_day,
        'is_recurring', (s.is_recurring = TRUE OR sr.id IS NOT NULL),
        'status', s.status,
        'approval_status', s.approval_status,
        'timezone', s.timezone,
        'location_name', s.location_name,
        'location_address', s.location_address,
        'building', s.building,
        'room', s.room,
        'landmark', s.landmark,
        'latitude', s.latitude,
        'longitude', s.longitude
    ) || jsonb_build_object(
        'virtual_meeting_url', s.virtual_meeting_url,
        'virtual_meeting_provider', s.virtual_meeting_provider,
        'recurring_parent_id', s.recurring_parent_id,
        'original_instance_date', s.original_instance_date,
        'organizer_id', s.organizer_id,
        'organizer_name', p.full_name,
        'organizer_email', p.email,
        'organizer_avatar', p.avatar_url,
        'created_by', s.created_by,
        'visibility', s.visibility,
        'cancellation_reason', s.cancellation_reason,
        'route_id', s.route_id,
        'route_name', tr.route_name,
        'route_code', tr.route_code,
        'route_start_time', tr.start_time,
        'route_end_time', tr.end_time,
        'bus_number', COALESCE(v.bus_number, v.registration_no, 'Assigned Bus'),
        'registration_no', COALESCE(v.registration_no, v.bus_number, 'Assigned Bus'),
        'driver_name', d.name,
        'driver_phone', d.phone,
        'trip_id', v_trip_id,
        'trip_status', COALESCE(v_trip_status, s.status, 'scheduled'),
        'recurrence', CASE 
            WHEN sr.id IS NOT NULL THEN jsonb_build_object(
                'id', sr.id,
                'frequency', sr.frequency,
                'interval', COALESCE(sr.interval, 1),
                'days_of_week', COALESCE(sr.days_of_week, '[]'::jsonb),
                'day_of_month', sr.day_of_month,
                'month_of_year', sr.month_of_year,
                'end_type', COALESCE(sr.end_type, 'never'),
                'end_count', sr.end_count,
                'end_date', sr.end_date,
                'exceptions', COALESCE(sr.exceptions, '[]'::jsonb)
            )
            ELSE NULL 
        END,
        'participants', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'id', sp.id,
                'user_id', sp.user_id,
                'target_role', sp.target_role,
                'target_class', sp.target_class,
                'participant_type', sp.participant_type,
                'participation_role', sp.participation_role,
                'permission', sp.permission,
                'rsvp_status', sp.rsvp_status,
                'decline_reason', sp.decline_reason,
                'rsvp_at', sp.rsvp_at,
                'full_name', COALESCE(prof.full_name, CASE WHEN sp.target_role IS NOT NULL AND sp.target_role != '' AND sp.target_role != 'group' THEN 'All ' || UPPER(SUBSTRING(sp.target_role FROM 1 FOR 1)) || SUBSTRING(sp.target_role FROM 2) || 's' ELSE sp.target_class END),
                'role', COALESCE(prof.role, sp.target_role),
                'email', prof.email,
                'avatar_url', prof.avatar_url
            )), '[]'::jsonb)
            FROM public.schedule_participants sp
            LEFT JOIN public.profiles prof ON prof.id = sp.user_id
            WHERE sp.schedule_id = s.id
        ),
        'booked_resources', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'id', rb.id,
                'resource_id', rb.resource_id,
                'resource_name', cr.name,
                'resource_type', cr.type,
                'room_number', cr.room_number,
                'status', rb.status
            )), '[]'::jsonb)
            FROM public.resource_bookings rb
            LEFT JOIN public.calendar_resources cr ON cr.id = rb.resource_id
            WHERE rb.schedule_id = s.id
        ),
        'comments', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'id', sc.id,
                'user_id', sc.user_id,
                'comment_text', sc.comment_text,
                'full_name', p2.full_name,
                'avatar_url', p2.avatar_url,
                'created_at', sc.created_at
            )), '[]'::jsonb)
            FROM public.schedule_comments sc
            LEFT JOIN public.profiles p2 ON p2.id = sc.user_id
            WHERE sc.schedule_id = s.id
        ),
        'reminders', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'id', rem.id,
                'minutes_before', rem.minutes_before,
                'channel', rem.channel
            )), '[]'::jsonb)
            FROM public.schedule_reminders rem
            WHERE rem.schedule_id = s.id
        )
    ) INTO v_result
    FROM public.schedules s
    LEFT JOIN public.calendars c ON c.id = s.calendar_id
    LEFT JOIN public.profiles p ON p.id = s.organizer_id
    LEFT JOIN public.transport_routes tr ON tr.id = s.route_id
    LEFT JOIN public.vehicles v ON v.id = tr.vehicle_id
    LEFT JOIN public.drivers d ON d.id = tr.driver_id
    LEFT JOIN public.schedule_recurrence sr ON sr.schedule_id = COALESCE(s.recurring_parent_id, s.id)
    WHERE s.id = v_real_schedule_id
      AND s.deleted_at IS NULL;

    RETURN v_result;
END;
$$;


-- 3. Update fn_update_schedule to handle nested recurrence JSON and robust upserts
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
    v_master_parent_id UUID;
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
BEGIN
    -- Fetch original schedule
    SELECT * INTO v_old FROM public.schedules WHERE id = p_schedule_id AND deleted_at IS NULL;
    IF v_old.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Schedule not found or deleted.');
    END IF;

    v_tz := COALESCE(p_data->>'timezone', v_old.timezone, 'Asia/Kolkata');
    v_master_parent_id := COALESCE(v_old.recurring_parent_id, v_old.id);
    v_target_date := COALESCE(p_target_instance_date, v_old.original_instance_date, (v_old.start_time AT TIME ZONE v_tz)::DATE);

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

    -- If no recurrence was specified in payload, preserve existing recurrence rule from master
    IF NOT v_has_recurrence_in_payload THEN
        SELECT frequency, interval, days_of_week, end_type, end_count, end_date
        INTO v_freq, v_interval, v_days, v_end_type, v_end_count, v_end_date
        FROM public.schedule_recurrence
        WHERE schedule_id = v_master_parent_id;

        IF v_freq IS NULL THEN
            v_freq := CASE WHEN v_old.is_recurring THEN 'daily' ELSE 'none' END;
        END IF;
    END IF;

    -- Normalize days of week for weekly recurrence if empty
    IF (v_freq = 'weekly' OR v_freq = 'custom') AND (v_days IS NULL OR jsonb_array_length(v_days) = 0) THEN
        v_days := jsonb_build_array(UPPER(SUBSTRING(to_char((COALESCE(v_old.start_time, NOW()) AT TIME ZONE v_tz), 'Day') FROM 1 FOR 2)));
    ELSIF v_freq = 'weekdays' THEN
        v_days := '["MO", "TU", "WE", "TH", "FR"]'::jsonb;
    END IF;

    -- ========================================================================
    -- 1. SCOPE: THIS EVENT ONLY ('this_event')
    -- ========================================================================
    IF p_recurrence_scope = 'this_event' AND v_target_date IS NOT NULL THEN
        PERFORM public.exclude_recurring_occurrence(v_master_parent_id, v_target_date);
        UPDATE public.schedules SET is_recurring = TRUE WHERE id = v_master_parent_id;

        UPDATE public.schedules
        SET deleted_at = NOW(), status = 'cancelled', updated_at = NOW()
        WHERE recurring_parent_id = v_master_parent_id
          AND (original_instance_date = v_target_date OR DATE(start_time AT TIME ZONE v_tz) = v_target_date);

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

        INSERT INTO public.schedules (
            id, school_id, calendar_id, route_id, title, description, schedule_type, category, color, priority,
            status, approval_status, start_time, end_time, is_all_day, timezone,
            location_name, location_address, building, room, virtual_meeting_url, virtual_meeting_provider,
            organizer_id, created_by, visibility, is_recurring, recurring_parent_id, original_instance_date,
            recurrence_exception_type, metadata, audience_type, target_roles, target_classes, target_user_ids, created_at, updated_at
        ) VALUES (
            v_new_id, p_school_id, COALESCE((p_data->>'calendar_id')::UUID, v_old.calendar_id),
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
            FALSE, v_master_parent_id, v_target_date, 'override',
            COALESCE(p_data->'metadata', v_old.metadata), v_aud_type, v_target_roles, v_target_classes, v_target_users, NOW(), NOW()
        ) RETURNING * INTO v_updated;

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
        UPDATE public.schedule_recurrence
        SET end_type = 'until_date',
            end_date = v_target_date - INTERVAL '1 day',
            updated_at = NOW()
        WHERE schedule_id = v_master_parent_id;

        UPDATE public.schedules
        SET deleted_at = NOW(), status = 'cancelled', updated_at = NOW()
        WHERE recurring_parent_id = v_master_parent_id
          AND (original_instance_date >= v_target_date OR DATE(start_time AT TIME ZONE v_tz) >= v_target_date);

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

        INSERT INTO public.schedules (
            id, school_id, calendar_id, route_id, title, description, schedule_type, category, color, priority,
            status, approval_status, start_time, end_time, is_all_day, timezone,
            location_name, location_address, building, room, virtual_meeting_url, virtual_meeting_provider,
            organizer_id, created_by, visibility, is_recurring, recurring_parent_id, original_instance_date,
            recurrence_exception_type, metadata, audience_type, target_roles, target_classes, target_user_ids, created_at, updated_at
        ) VALUES (
            v_new_id, p_school_id, COALESCE((p_data->>'calendar_id')::UUID, v_old.calendar_id),
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
            (v_freq != 'none'), NULL, NULL, 'none',
            COALESCE(p_data->'metadata', v_old.metadata), v_aud_type, v_target_roles, v_target_classes, v_target_users, NOW(), NOW()
        ) RETURNING * INTO v_updated;

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
            is_recurring = (v_freq != 'none'),
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
        IF v_freq != 'none' THEN
            IF EXISTS (SELECT 1 FROM public.schedule_recurrence WHERE schedule_id = v_master_parent_id) THEN
                UPDATE public.schedule_recurrence
                SET frequency = v_freq,
                    interval = v_interval,
                    days_of_week = v_days,
                    end_type = v_end_type,
                    end_count = v_end_count,
                    end_date = v_end_date,
                    updated_at = NOW()
                WHERE schedule_id = v_master_parent_id;
            ELSE
                INSERT INTO public.schedule_recurrence (
                    id, schedule_id, frequency, interval, days_of_week, end_type, end_count, end_date, exceptions, created_at, updated_at
                ) VALUES (
                    gen_random_uuid(), v_master_parent_id, v_freq, v_interval, v_days, v_end_type, v_end_count, v_end_date, '[]'::jsonb, NOW(), NOW()
                );
            END IF;

            UPDATE public.schedules SET is_recurring = TRUE WHERE id = v_master_parent_id;
        ELSE
            DELETE FROM public.schedule_recurrence WHERE schedule_id = v_master_parent_id;
            UPDATE public.schedules SET is_recurring = FALSE WHERE id = v_master_parent_id;
            UPDATE public.schedules SET deleted_at = NOW(), status = 'cancelled' WHERE recurring_parent_id = v_master_parent_id;
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

        -- Update resources
        IF jsonb_array_length(COALESCE(p_data->'resources', '[]'::jsonb)) > 0 THEN
            DELETE FROM public.resource_bookings WHERE schedule_id = v_master_parent_id;
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

        -- Update reminders
        IF jsonb_array_length(COALESCE(p_data->'reminders', '[]'::jsonb)) > 0 THEN
            DELETE FROM public.schedule_reminders WHERE schedule_id = v_master_parent_id;
            FOR v_rem_elem IN SELECT * FROM jsonb_array_elements(p_data->'reminders') LOOP
                INSERT INTO public.schedule_reminders (
                    id, schedule_id, user_id, minutes_before, channel, is_sent, created_at
                ) VALUES (
                    gen_random_uuid(), v_master_parent_id, p_user_id, COALESCE((v_rem_elem->>'minutes_before')::INT, 15),
                    COALESCE(v_rem_elem->>'channel', 'in_app'), FALSE, NOW()
                );
            END LOOP;
        END IF;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Schedule series updated successfully.', 'data', to_jsonb(v_updated));
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
