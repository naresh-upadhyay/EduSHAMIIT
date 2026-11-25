-- 589: Fix leave_time tracking, prevent ended sessions from showing in join-conduct active banner,
-- and support auto-ending empty live meetings.

CREATE OR REPLACE FUNCTION public.sp_student_leave_live_class(
    p_session_id uuid,
    p_user_id uuid,
    p_school_id uuid
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_segments_closed INT := 0;
    v_remaining_participants INT := 0;
BEGIN
    -- 1. Close any open connection segments for this user in this session
    UPDATE public.live_class_connection_segments
    SET left_at = NOW(),
        duration_seconds = GREATEST(0, EXTRACT(EPOCH FROM (NOW() - joined_at))::INT)
    WHERE session_id = p_session_id
      AND user_id = p_user_id
      AND left_at IS NULL;

    GET DIAGNOSTICS v_segments_closed = ROW_COUNT;

    -- 2. Mark participant as having left cleanly (set BOTH leave_time and last_leave_at)
    UPDATE public.live_class_participants
    SET leave_time = COALESCE(leave_time, NOW()),
        last_leave_at = NOW(),
        updated_at = NOW()
    WHERE live_class_id = p_session_id
      AND user_id = p_user_id
      AND leave_time IS NULL;

    -- 3. Count remaining active participants in DB
    SELECT COUNT(*) INTO v_remaining_participants
    FROM public.live_class_participants p
    WHERE p.live_class_id = p_session_id
      AND p.leave_time IS NULL
      AND p.user_id != p_user_id;

    -- 4. Log leave event only if events audit table exists
    IF to_regclass('public.live_class_events') IS NOT NULL THEN
        INSERT INTO public.live_class_events (
            id, live_class_id, user_id, event_type, payload, created_at
        ) VALUES (
            gen_random_uuid(), p_session_id, p_user_id, 'participant_left',
            jsonb_build_object(
                'action', 'leave',
                'segments_closed', v_segments_closed,
                'remaining_participants', v_remaining_participants,
                'timestamp', NOW()
            ),
            NOW()
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Left session cleanly',
        'session_id', p_session_id,
        'user_id', p_user_id,
        'segments_closed', v_segments_closed,
        'remaining_participants', v_remaining_participants
    );
END;
$function$;


CREATE OR REPLACE FUNCTION public.sp_get_live_classes_join_conduct_kpis(
    p_school_id uuid,
    p_user_id uuid DEFAULT NULL::uuid,
    p_date_filter text DEFAULT 'today'::text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_my_classes_count INT := 0;
    v_ongoing_count INT := 0;
    v_upcoming_count INT := 0;
    v_completed_count INT := 0;
    v_total_students INT := 0;
    v_teaching_duration_minutes INT := 0;
    v_duration_str TEXT;
    v_conduct_session JSONB;
    v_live_session_id UUID;
    v_active_session JSONB := NULL;
    v_participants JSONB := '[]'::jsonb;
BEGIN
    SELECT COUNT(*) INTO v_my_classes_count
    FROM public.live_classes c
    WHERE (p_school_id IS NULL OR c.school_id = p_school_id)
      AND (p_user_id IS NULL OR c.teacher_id = p_user_id OR c.co_host_id = p_user_id)
      AND (
          LOWER(p_date_filter) = 'all'
          OR (LOWER(p_date_filter) = 'today' AND (c.scheduled_at::DATE = CURRENT_DATE OR c.created_at::DATE = CURRENT_DATE))
          OR (LOWER(p_date_filter) = 'this week' AND c.scheduled_at >= DATE_TRUNC('week', CURRENT_DATE))
          OR (LOWER(p_date_filter) = 'this month' AND c.scheduled_at >= DATE_TRUNC('month', CURRENT_DATE))
      );

    SELECT COUNT(*) INTO v_ongoing_count
    FROM public.live_classes c
    WHERE (p_school_id IS NULL OR c.school_id = p_school_id)
      AND (c.status = 'live' OR c.is_live = TRUE);

    SELECT COUNT(*) INTO v_upcoming_count
    FROM public.live_classes c
    WHERE (p_school_id IS NULL OR c.school_id = p_school_id)
      AND c.status IN ('upcoming', 'scheduled')
      AND c.status != 'live';

    SELECT COUNT(*) INTO v_completed_count
    FROM public.live_classes c
    WHERE (p_school_id IS NULL OR c.school_id = p_school_id)
      AND c.status IN ('completed', 'recorded');

    SELECT COUNT(*) INTO v_total_students
    FROM public.profiles
    WHERE (p_school_id IS NULL OR school_id = p_school_id)
      AND role = 'student'
      AND status = 'ACTIVE';

    IF v_total_students = 0 THEN
        SELECT COALESCE(SUM(c.viewer_count), 0) INTO v_total_students
        FROM public.live_classes c
        WHERE (p_school_id IS NULL OR c.school_id = p_school_id);
    END IF;

    SELECT COALESCE(SUM(c.duration_minutes), 0) INTO v_teaching_duration_minutes
    FROM public.live_classes c
    WHERE (p_school_id IS NULL OR c.school_id = p_school_id)
      AND (c.scheduled_at::DATE = CURRENT_DATE OR c.created_at::DATE = CURRENT_DATE)
      AND c.status IN ('live', 'completed', 'recorded');

    IF v_teaching_duration_minutes > 0 THEN
        v_duration_str := (v_teaching_duration_minutes / 60)::TEXT || ' h ' || (v_teaching_duration_minutes % 60)::TEXT || ' min';
    ELSE
        v_duration_str := '0 h 0 min';
    END IF;

    -- Fetch full conduct session context ONLY for an actually live session
    SELECT id INTO v_live_session_id
    FROM public.live_classes
    WHERE (p_school_id IS NULL OR school_id = p_school_id)
      AND (status = 'live' OR is_live = TRUE)
    ORDER BY scheduled_at ASC, created_at DESC
    LIMIT 1;

    IF v_live_session_id IS NOT NULL THEN
        v_conduct_session := public.sp_get_live_class_conduct_session(p_school_id, p_user_id, v_live_session_id);
        v_active_session := v_conduct_session->'active_session';
        v_participants := COALESCE(v_conduct_session->'participants', '[]'::jsonb);
    ELSE
        v_conduct_session := public.sp_get_live_class_conduct_session(p_school_id, p_user_id);
        v_active_session := NULL;
        v_participants := '[]'::jsonb;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'kpis', jsonb_build_object(
            'my_classes_today', v_my_classes_count,
            'todays_classes', v_my_classes_count,
            'ongoing_live', v_ongoing_count,
            'live_now', v_ongoing_count,
            'upcoming', v_upcoming_count,
            'completed', v_completed_count,
            'total_students', v_total_students,
            'teaching_duration_minutes', v_teaching_duration_minutes,
            'teaching_duration_display', v_duration_str
        ),
        'active_session', v_active_session,
        'participants', v_participants,
        'upcoming_classes', COALESCE(v_conduct_session->'upcoming_classes', '[]'::jsonb)
    );
END;
$function$;
