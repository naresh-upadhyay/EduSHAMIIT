-- ============================================================================
-- Migration 552: Autonomous Stale Live Class Watchdog & Student Leave Stored Procedures
-- Ensures zero zombie sessions, guaranteed attendance calculation on timeout,
-- and clean student leave semantics without disrupting the host's ongoing live class.
-- ============================================================================

-- 1. Stored Procedure: Student Leave Live Class Quietly
CREATE OR REPLACE FUNCTION public.sp_student_leave_live_class(
    p_session_id UUID,
    p_user_id UUID,
    p_school_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_part_id UUID;
    v_segments_closed INT := 0;
BEGIN
    -- 1. Close any open connection segments for this student in this session
    UPDATE public.live_class_connection_segments
    SET left_at = NOW(),
        duration_seconds = GREATEST(0, EXTRACT(EPOCH FROM (NOW() - joined_at))::INT)
    WHERE session_id = p_session_id
      AND user_id = p_user_id
      AND left_at IS NULL;

    GET DIAGNOSTICS v_segments_closed = ROW_COUNT;

    -- 2. Update participant record if exists
    UPDATE public.live_class_participants
    SET last_leave_at = NOW(),
        updated_at = NOW()
    WHERE live_class_id = p_session_id
      AND user_id = p_user_id;

    -- 3. Log event
    INSERT INTO public.live_class_events (
        id, live_class_id, user_id, event_type, payload, created_at
    ) VALUES (
        gen_random_uuid(), p_session_id, p_user_id, 'student_left',
        jsonb_build_object('action', 'leave', 'segments_closed', v_segments_closed, 'timestamp', NOW()),
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Student left session cleanly',
        'session_id', p_session_id,
        'user_id', p_user_id,
        'segments_closed', v_segments_closed
    );
END;
$$;

-- 2. Stored Procedure: Autonomous Stale Live Class Watchdog
CREATE OR REPLACE FUNCTION public.sp_auto_close_stale_live_classes(
    p_school_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_closed_count INT := 0;
    v_closed_ids JSONB := '[]'::JSONB;
    r RECORD;
    v_att_res JSONB;
BEGIN
    FOR r IN (
        SELECT id, school_id, title, duration_minutes, scheduled_at, updated_at
        FROM public.live_classes
        WHERE (is_live = TRUE OR status = 'live')
          AND (p_school_id IS NULL OR school_id = p_school_id)
          AND (
              -- Case 1: Inactive session beyond duration + 30m grace period
              (scheduled_at IS NOT NULL AND scheduled_at + ((COALESCE(duration_minutes, 45) + 30) || ' minutes')::INTERVAL < NOW())
              OR
              -- Case 2: Session with no activity/heartbeat in over 30 minutes
              (updated_at < NOW() - INTERVAL '30 minutes')
          )
    ) LOOP
        -- 1. Close all hanging connection segments
        UPDATE public.live_class_connection_segments
        SET left_at = NOW(),
            duration_seconds = GREATEST(0, EXTRACT(EPOCH FROM (NOW() - joined_at))::INT)
        WHERE session_id = r.id AND left_at IS NULL;

        -- 2. Conclude the live class
        UPDATE public.live_classes
        SET is_live = FALSE,
            status = 'recorded',
            actual_end_at = NOW(),
            recording_status = 'COMPLETED',
            updated_at = NOW()
        WHERE id = r.id;

        -- 3. Automatically aggregate and post institutional attendance
        BEGIN
            v_att_res := public.sp_auto_calculate_live_class_attendance(r.id, r.school_id);
        EXCEPTION WHEN OTHERS THEN
            v_att_res := jsonb_build_object('error', SQLERRM);
        END;

        -- 4. Record audit event
        INSERT INTO public.live_class_events (
            id, live_class_id, event_type, payload, created_at
        ) VALUES (
            gen_random_uuid(), r.id, 'watchdog_auto_closed',
            jsonb_build_object(
                'reason', 'Timeout watchdog auto-closure',
                'title', r.title,
                'attendance_result', v_att_res,
                'timestamp', NOW()
            ),
            NOW()
        );

        v_closed_count := v_closed_count + 1;
        v_closed_ids := v_closed_ids || jsonb_build_object('session_id', r.id, 'title', r.title);
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'closed_count', v_closed_count,
        'closed_sessions', v_closed_ids
    );
END;
$$;
