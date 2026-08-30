-- ============================================================================
-- Migration: 233_fn_get_schedule_details_and_trip_status.sql
-- Description:
--   Creates PostgreSQL stored procedure `fn_get_schedule_details` to return
--   complete schedule details along with real-time vehicle trip status ('in_progress',
--   'paused', 'completed', 'scheduled') directly from database.
-- ============================================================================

DROP FUNCTION IF EXISTS public.fn_get_schedule_details(UUID, UUID, DATE);
DROP FUNCTION IF EXISTS public.fn_get_schedule_details;
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
    v_trip_id UUID;
    v_trip_status TEXT;
    v_target_date_str TEXT;
BEGIN
    IF p_target_date IS NOT NULL THEN
        v_target_date_str := p_target_date::text;
    END IF;

    -- 1. Resolve real-time active/latest trip status from vehicle_trips
    SELECT vt.id, vt.status
    INTO v_trip_id, v_trip_status
    FROM public.vehicle_trips vt
    JOIN public.schedules s ON s.id = p_schedule_id
    WHERE (vt.schedule_id = p_schedule_id OR (s.route_id IS NOT NULL AND vt.route_id = s.route_id))
      AND (
        (p_target_date IS NOT NULL AND (vt.schedule_instance_date = p_target_date OR vt.start_date = v_target_date_str OR vt.scheduled_start::date = p_target_date))
        OR (p_target_date IS NULL)
      )
    ORDER BY 
      CASE WHEN vt.status IN ('in_progress', 'paused') THEN 1 WHEN vt.status = 'completed' THEN 3 ELSE 2 END,
      vt.updated_at DESC, 
      vt.created_at DESC
    LIMIT 1;

    -- 2. Build complete schedule JSON object
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
        'start_time', s.start_time,
        'end_time', s.end_time,
        'is_all_day', s.is_all_day,
        'is_recurring', s.is_recurring,
        'status', s.status,
        'organizer_id', s.organizer_id,
        'organizer_name', p.full_name,
        'organizer_email', p.email,
        'organizer_avatar', p.avatar_url,
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
        'participants', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'id', sp.id,
                'user_id', sp.user_id,
                'participant_type', sp.participant_type,
                'participation_role', sp.participation_role,
                'permission', sp.permission,
                'rsvp_status', sp.rsvp_status,
                'decline_reason', sp.decline_reason,
                'rsvp_at', sp.rsvp_at,
                'full_name', COALESCE(prof.full_name, sp.target_role, sp.target_class),
                'role', prof.role,
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
    WHERE s.id = p_schedule_id AND (p_school_id IS NULL OR s.school_id = p_school_id) AND s.deleted_at IS NULL;

    RETURN v_result;
END;
$$;
