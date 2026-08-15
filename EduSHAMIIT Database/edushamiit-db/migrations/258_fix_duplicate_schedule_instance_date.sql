-- ============================================================================
-- Migration: 258_fix_duplicate_schedule_instance_date.sql
-- Description:
--   Updates fn_duplicate_schedule to accept an optional p_target_instance_date.
--   When duplicating a specific occurrence from a recurring series (e.g. Tuesday Aug 11),
--   the duplicated schedule is created on that exact instance date/time instead of
--   jumping back to the parent series start date (Aug 10).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_duplicate_schedule(
    p_school_id UUID,
    p_user_id UUID,
    p_schedule_id UUID,
    p_target_instance_date DATE DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_src public.schedules%ROWTYPE;
    v_new_id UUID := gen_random_uuid();
    v_new_title TEXT;
    v_dup_rec public.schedules%ROWTYPE;
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_duration INTERVAL;
    v_tz TEXT;
BEGIN
    SELECT * INTO v_src
    FROM public.schedules
    WHERE id = p_schedule_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_src.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Schedule not found');
    END IF;

    v_tz := COALESCE(v_src.timezone, 'Asia/Kolkata');
    v_duration := COALESCE(v_src.end_time - v_src.start_time, INTERVAL '1 hour');

    IF p_target_instance_date IS NOT NULL THEN
        v_start_time := (p_target_instance_date::TEXT || ' ' || to_char((v_src.start_time AT TIME ZONE v_tz)::TIME, 'HH24:MI:SS'))::TIMESTAMP AT TIME ZONE v_tz;
        v_end_time := v_start_time + v_duration;
    ELSE
        v_start_time := v_src.start_time;
        v_end_time := v_src.end_time;
    END IF;

    v_new_title := v_src.title || ' (Copy)';

    INSERT INTO public.schedules (
        id, school_id, calendar_id, title, description, schedule_type, category, color, priority,
        status, approval_status, start_time, end_time, is_all_day, timezone,
        location_name, location_address, building, room, landmark, latitude, longitude,
        virtual_meeting_url, virtual_meeting_provider, organizer_id, created_by, visibility,
        is_recurring, recurring_parent_id, original_instance_date, recurrence_exception_type,
        route_id, audience_type, target_roles, target_classes, target_user_ids,
        metadata, created_at, updated_at
    ) VALUES (
        v_new_id, p_school_id, v_src.calendar_id, v_new_title, v_src.description, v_src.schedule_type,
        v_src.category, v_src.color, v_src.priority, 'confirmed', 'approved',
        v_start_time, v_end_time, v_src.is_all_day, v_tz,
        v_src.location_name, v_src.location_address, v_src.building, v_src.room, v_src.landmark, v_src.latitude, v_src.longitude,
        v_src.virtual_meeting_url, v_src.virtual_meeting_provider, p_user_id, p_user_id, v_src.visibility,
        FALSE, NULL, NULL, 'none',
        v_src.route_id, COALESCE(v_src.audience_type, 'individual'),
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

    -- Duplicate resources if any
    INSERT INTO public.resource_bookings (
        id, schedule_id, resource_id, start_time, end_time, status, created_at
    )
    SELECT gen_random_uuid(), v_new_id, resource_id, v_start_time, v_end_time, 'confirmed', NOW()
    FROM public.resource_bookings
    WHERE schedule_id = p_schedule_id;

    -- Create vehicle_trips if route_id is present
    IF v_src.route_id IS NOT NULL THEN
        INSERT INTO public.vehicle_trips (
            id, school_id, route_id, vehicle_id, driver_id, start_date, end_date,
            schedule_id, schedule_instance_date, start_time, end_time, scheduled_start,
            status, delay_minutes, created_at, updated_at
        ) VALUES (
            gen_random_uuid(), p_school_id, v_src.route_id,
            (SELECT vehicle_id FROM public.transport_routes WHERE id = v_src.route_id),
            (SELECT driver_id FROM public.transport_routes WHERE id = v_src.route_id),
            (v_start_time AT TIME ZONE v_tz)::DATE::TEXT,
            (v_end_time AT TIME ZONE v_tz)::DATE::TEXT,
            v_new_id, (v_start_time AT TIME ZONE v_tz)::DATE,
            to_char(v_start_time AT TIME ZONE v_tz, 'HH12:MI AM'),
            to_char(v_end_time AT TIME ZONE v_tz, 'HH12:MI AM'),
            v_start_time, 'scheduled', 0, NOW(), NOW()
        );
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Schedule duplicated successfully.',
        'data', to_jsonb(v_dup_rec)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
