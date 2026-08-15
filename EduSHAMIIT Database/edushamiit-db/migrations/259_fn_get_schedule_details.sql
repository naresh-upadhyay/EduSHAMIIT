-- ============================================================================
-- Migration: 259_fn_get_schedule_details.sql
-- Description:
--   Implements stored procedure fn_get_schedule_details to atomically fetch
--   complete single schedule details including live participants, RSVP responses,
--   booked resources, discussion comments, reminders, recurrence rules, and
--   active vehicle trip status without direct raw SQL queries in API endpoints.
-- ============================================================================

DROP FUNCTION IF EXISTS public.fn_get_schedule_details(UUID, UUID, DATE);
DROP FUNCTION IF EXISTS public.fn_get_schedule_details(UUID, UUID);
DROP FUNCTION IF EXISTS public.fn_get_schedule_details(UUID);

CREATE OR REPLACE FUNCTION public.fn_get_schedule_details(
    p_school_id UUID,
    p_schedule_id UUID,
    p_target_instance_date DATE DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_rec JSONB;
    v_trip_id UUID;
    v_trip_status TEXT;
    v_inst_str TEXT;
    v_tz TEXT;
BEGIN
    SELECT to_jsonb(s.*) || jsonb_build_object(
        'calendar_name', c.name,
        'calendar_color', c.color,
        'calendar_type', c.type,
        'organizer_name', p.full_name,
        'organizer_avatar', p.avatar_url,
        'route_name', tr.route_name,
        'route_code', tr.route_code,
        'route_start_time', tr.start_time,
        'route_end_time', tr.end_time,
        'bus_number', v.bus_number,
        'registration_no', v.registration_no,
        'driver_name', d.name,
        'participants', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
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
            ))
            FROM public.schedule_participants sp
            LEFT JOIN public.profiles prof ON prof.id = sp.user_id
            WHERE sp.schedule_id = p_schedule_id
        ), '[]'::jsonb),
        'booked_resources', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'id', rb.id,
                'resource_id', rb.resource_id,
                'resource_name', cr.name,
                'resource_type', cr.type,
                'room_number', cr.room_number,
                'status', rb.status
            ))
            FROM public.resource_bookings rb
            LEFT JOIN public.calendar_resources cr ON cr.id = rb.resource_id
            WHERE rb.schedule_id = p_schedule_id
        ), '[]'::jsonb),
        'comments', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'id', sc.id,
                'user_id', sc.user_id,
                'comment_text', sc.comment_text,
                'full_name', p2.full_name,
                'avatar_url', p2.avatar_url,
                'created_at', sc.created_at
            ) ORDER BY sc.created_at ASC)
            FROM public.schedule_comments sc
            LEFT JOIN public.profiles p2 ON p2.id = sc.user_id
            WHERE sc.schedule_id = p_schedule_id
        ), '[]'::jsonb),
        'reminders', COALESCE((
            SELECT jsonb_agg(jsonb_build_object(
                'id', rem.id,
                'minutes_before', rem.minutes_before,
                'channel', rem.channel
            ))
            FROM public.schedule_reminders rem
            WHERE rem.schedule_id = p_schedule_id
        ), '[]'::jsonb),
        'recurrence', (
            SELECT jsonb_build_object(
                'id', sr.id,
                'frequency', sr.frequency,
                'interval', sr.interval,
                'days_of_week', sr.days_of_week,
                'day_of_month', sr.day_of_month,
                'month_of_year', sr.month_of_year,
                'end_type', sr.end_type,
                'end_count', sr.end_count,
                'end_date', sr.end_date
            )
            FROM public.schedule_recurrence sr
            WHERE sr.schedule_id = p_schedule_id
            LIMIT 1
        )
    ) INTO v_rec
    FROM public.schedules s
    LEFT JOIN public.calendars c ON c.id = s.calendar_id
    LEFT JOIN public.profiles p ON p.id = s.organizer_id
    LEFT JOIN public.transport_routes tr ON tr.id = s.route_id
    LEFT JOIN public.vehicles v ON v.id = tr.vehicle_id
    LEFT JOIN public.drivers d ON d.id = tr.driver_id
    WHERE s.id = p_schedule_id AND s.deleted_at IS NULL;

    IF v_rec IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Schedule not found');
    END IF;

    v_tz := COALESCE(v_rec->>'timezone', 'Asia/Kolkata');
    IF p_target_instance_date IS NOT NULL THEN
        v_inst_str := p_target_instance_date::TEXT;
        v_rec := jsonb_set(v_rec, '{original_instance_date}', to_jsonb(v_inst_str));
        v_rec := jsonb_set(v_rec, '{is_recurrence_instance}', 'true'::jsonb);
        v_rec := jsonb_set(v_rec, '{parent_schedule_id}', to_jsonb(p_schedule_id::TEXT));
    ELSE
        v_inst_str := COALESCE(v_rec->>'original_instance_date', to_char((v_rec->>'start_time')::TIMESTAMPTZ AT TIME ZONE v_tz, 'YYYY-MM-DD'));
    END IF;

    -- Resolve trip_id and trip_status
    IF v_rec->>'route_id' IS NOT NULL THEN
        SELECT vt.id, vt.status INTO v_trip_id, v_trip_status
        FROM public.vehicle_trips vt
        WHERE (vt.schedule_id = p_schedule_id OR (v_rec->>'recurring_parent_id' IS NOT NULL AND vt.schedule_id = (v_rec->>'recurring_parent_id')::UUID))
          AND (vt.schedule_instance_date = v_inst_str::DATE OR vt.start_date = v_inst_str)
        ORDER BY CASE WHEN vt.status IN ('in_progress', 'paused') THEN 1 WHEN vt.status = 'completed' THEN 2 ELSE 3 END, vt.updated_at DESC
        LIMIT 1;

        IF v_trip_id IS NOT NULL THEN
            v_rec := jsonb_set(v_rec, '{trip_id}', to_jsonb(v_trip_id::TEXT));
            v_rec := jsonb_set(v_rec, '{trip_status}', to_jsonb(v_trip_status));
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', v_rec
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
