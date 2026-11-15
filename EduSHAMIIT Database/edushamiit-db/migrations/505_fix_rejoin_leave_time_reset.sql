CREATE OR REPLACE FUNCTION public.sp_record_participant_connection_event(
    p_session_id uuid,
    p_user_id uuid,
    p_event_type text,
    p_event_time timestamp with time zone DEFAULT now(),
    p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_participant_id UUID;
    v_open_segment_id UUID;
    v_seg_join TIMESTAMPTZ;
    v_seg_duration INT;
    v_total_duration INT;
    v_reconnection_count INT;
    v_result JSONB;
BEGIN
    SELECT id, COALESCE(reconnection_count, 0)
    INTO v_participant_id, v_reconnection_count
    FROM public.live_class_participants
    WHERE live_class_id = p_session_id AND user_id = p_user_id
    LIMIT 1;

    IF v_participant_id IS NULL THEN
        INSERT INTO public.live_class_participants (
            live_class_id, user_id, join_time, first_join_at,
            participant_role, reconnection_count, attendance_status
        ) VALUES (
            p_session_id, p_user_id, p_event_time, p_event_time,
            COALESCE(p_metadata->>'role', 'student'), 0, 'Present'
        ) RETURNING id INTO v_participant_id;
    END IF;

    IF p_event_type IN ('JOIN', 'REJOIN') THEN
        UPDATE public.live_class_participants
        SET leave_time = NULL,
            last_leave_at = NULL,
            reconnection_count = CASE WHEN p_event_type = 'REJOIN' THEN reconnection_count + 1 ELSE reconnection_count END,
            updated_at = NOW()
        WHERE id = v_participant_id;

        INSERT INTO public.live_class_connection_segments (
            session_id, participant_id, user_id, joined_at,
            connection_source, provider_event_id
        ) VALUES (
            p_session_id, v_participant_id, p_user_id, p_event_time,
            COALESCE(p_metadata->>'source', 'web'), p_metadata->>'event_id'
        );

    ELSIF p_event_type = 'LEAVE' THEN
        SELECT id, joined_at INTO v_open_segment_id, v_seg_join
        FROM public.live_class_connection_segments
        WHERE session_id = p_session_id AND user_id = p_user_id AND left_at IS NULL
        ORDER BY joined_at DESC LIMIT 1;

        IF v_open_segment_id IS NOT NULL THEN
            v_seg_duration := GREATEST(0, EXTRACT(EPOCH FROM (p_event_time - v_seg_join))::INT);
            UPDATE public.live_class_connection_segments
            SET left_at = p_event_time,
                duration_seconds = v_seg_duration,
                disconnect_reason = COALESCE(p_metadata->>'reason', 'client_leave')
            WHERE id = v_open_segment_id;
        END IF;

        SELECT COALESCE(SUM(duration_seconds), 0) INTO v_total_duration
        FROM public.live_class_connection_segments
        WHERE session_id = p_session_id AND user_id = p_user_id;

        UPDATE public.live_class_participants
        SET leave_time = p_event_time,
            last_leave_at = p_event_time,
            duration = v_total_duration,
            updated_at = NOW()
        WHERE id = v_participant_id;
    END IF;

    v_result := jsonb_build_object(
        'success', true,
        'participant_id', v_participant_id,
        'event_type', p_event_type,
        'session_id', p_session_id,
        'user_id', p_user_id
    );

    RETURN v_result;
END;
$$;
