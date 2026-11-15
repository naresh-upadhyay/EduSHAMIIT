-- 445_fix_candidate_heartbeat_sync_and_permissions.sql
-- Ensure candidate heartbeat ping returns real-time invigilator enforcement (camera_active, mic_active, teacher_message, warnings_count)

CREATE OR REPLACE FUNCTION public.rpc_record_candidate_heartbeat_and_event(
    p_school_id UUID,
    p_exam_id UUID,
    p_candidate_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_exam RECORD;
    v_mon RECORD;
    v_session RECORD;
    v_event_type TEXT := LOWER(NULLIF(BTRIM(p_payload->>'event_type'), ''));
    v_severity TEXT := LOWER(COALESCE(NULLIF(BTRIM(p_payload->>'severity'), ''), 'medium'));
    v_title TEXT;
    v_desc TEXT;
    v_det_source TEXT := COALESCE(NULLIF(BTRIM(p_payload->>'detection_source'), ''), 'browser');
    v_duration_sec INT := GREATEST(0, COALESCE((p_payload->>'duration_seconds')::INT, 0));
    v_logs JSONB;
    v_new_warnings INT;
    v_new_status TEXT;
    v_inc_id UUID;
    v_rem_sec INT;
    v_thresh INT := 3;
    v_pending_ann JSONB := '[]'::jsonb;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext(p_exam_id::TEXT || ':' || p_candidate_id::TEXT));

    SELECT id, school_id, duration_minutes INTO v_exam FROM public.exams WHERE id = p_exam_id LIMIT 1;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 404, 'error', 'Examination not found');
    END IF;
    IF p_school_id IS NOT NULL AND v_exam.school_id IS NOT NULL AND v_exam.school_id <> p_school_id THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 403, 'error', 'Tenant isolation violation');
    END IF;

    SELECT * INTO v_mon FROM public.exam_monitoring_sessions WHERE exam_id = p_exam_id LIMIT 1;
    v_thresh := GREATEST(1, COALESCE(v_mon.auto_flag_tab_switch_threshold, 3));

    SELECT * INTO v_session
    FROM public.exam_sessions
    WHERE exam_id = p_exam_id AND student_id = p_candidate_id
    ORDER BY started_at DESC NULLS LAST, created_at DESC
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 404, 'error', 'No active session found for candidate');
    END IF;

    v_logs := COALESCE(v_session.proctor_logs, '[]'::jsonb);
    v_new_warnings := COALESCE(v_session.warnings_count, 0);
    v_new_status := COALESCE(v_session.monitoring_status, 'ACTIVE');

    IF v_event_type IS NOT NULL AND v_event_type NOT IN ('', 'ping', 'heartbeat', 'telemetry') THEN
        v_title := COALESCE(NULLIF(BTRIM(p_payload->>'title'), ''), INITCAP(REPLACE(v_event_type, '_', ' ')));
        v_desc := COALESCE(NULLIF(BTRIM(p_payload->>'description'), ''), v_title);

        IF v_event_type IN ('tab_switch', 'window_blur', 'fullscreen_exit', 'multiple_faces', 'face_missing', 'audio_noise') THEN
            v_new_warnings := v_new_warnings + 1;
        END IF;

        INSERT INTO public.exam_incidents (
            school_id, exam_id, session_id, candidate_id,
            violation_type, severity, title, description,
            detection_source, duration_seconds, snapshot_url,
            event_metadata, status
        ) VALUES (
            COALESCE(v_exam.school_id, p_school_id), p_exam_id, v_session.id, p_candidate_id,
            v_event_type, v_severity, v_title, v_desc,
            v_det_source, v_duration_sec, p_payload->>'snapshot_url',
            p_payload, 'open'
        ) RETURNING id INTO v_inc_id;

        v_logs := jsonb_insert(v_logs, '{-1}', jsonb_build_object(
            'time', TO_CHAR(NOW() AT TIME ZONE 'UTC', 'HH24:MI:SS'),
            'event', v_title,
            'violation_type', v_event_type,
            'severity', v_severity
        ));

        IF v_new_status NOT IN ('PAUSED', 'UNDER_REVIEW') THEN
            IF v_new_warnings >= v_thresh OR v_severity = 'critical' THEN
                v_new_status := 'VIOLATION';
            ELSIF v_new_warnings > 0 THEN
                v_new_status := 'WARNING';
            END IF;
        END IF;
    END IF;

    UPDATE public.exam_sessions
    SET last_ping = NOW(),
        is_online = COALESCE((p_payload->>'is_online')::BOOLEAN, TRUE),
        disconnected_at = CASE WHEN COALESCE((p_payload->>'is_online')::BOOLEAN, TRUE) THEN NULL ELSE COALESCE(disconnected_at, NOW()) END,
        monitoring_status = CASE WHEN COALESCE((p_payload->>'is_paused')::BOOLEAN, is_paused, FALSE) THEN 'PAUSED' ELSE v_new_status END,
        warnings_count = v_new_warnings,
        proctor_logs = v_logs,
        camera_active = CASE 
            WHEN camera_active = FALSE THEN FALSE 
            ELSE COALESCE((p_payload->>'camera_active')::BOOLEAN, camera_active) 
        END,
        camera_permission_state = COALESCE(NULLIF(p_payload->>'camera_permission_state', ''), camera_permission_state),
        mic_active = CASE 
            WHEN mic_active = FALSE THEN FALSE 
            ELSE COALESCE((p_payload->>'mic_active')::BOOLEAN, mic_active) 
        END,
        mic_permission_state = COALESCE(NULLIF(p_payload->>'mic_permission_state', ''), mic_permission_state),
        screen_share_active = COALESCE((p_payload->>'screen_share_active')::BOOLEAN, screen_share_active),
        screen_share_state = COALESCE(NULLIF(p_payload->>'screen_share_state', ''), screen_share_state),
        livekit_connected = COALESCE((p_payload->>'livekit_connected')::BOOLEAN, livekit_connected),
        livekit_identity = COALESCE(NULLIF(p_payload->>'livekit_identity', ''), livekit_identity),
        network_status = COALESCE(NULLIF(UPPER(p_payload->>'network_status'), ''), network_status),
        latency_ms = COALESCE((p_payload->>'latency_ms')::INT, latency_ms),
        browser_info = COALESCE(NULLIF(p_payload->>'browser_info', ''), browser_info),
        device_info = CASE WHEN p_payload ? 'device_info' AND jsonb_typeof(p_payload->'device_info') = 'object'
                           THEN p_payload->'device_info' ELSE device_info END,
        answered_count = COALESCE((p_payload->>'answered_count')::INT, answered_count),
        marked_count = COALESCE((p_payload->>'marked_count')::INT, marked_count),
        current_question_index = COALESCE((p_payload->>'current_question_index')::INT, current_question_index),
        updated_at = NOW()
    WHERE id = v_session.id
    RETURNING * INTO v_session;

    v_rem_sec := public._compute_session_remaining_seconds(
        v_session.started_at, COALESCE(v_exam.duration_minutes, 60), COALESCE(v_session.extra_minutes, 0),
        COALESCE(v_session.paused_total_seconds, 0), COALESCE(v_session.is_paused, FALSE),
        v_session.paused_at, v_session.timer_pause_policy,
        v_session.monitoring_status,
        COALESCE(v_mon.status = 'PAUSED', FALSE), v_mon.paused_at
    );

    SELECT COALESCE(jsonb_agg(row_to_json(ua)), '[]'::jsonb)
    INTO v_pending_ann
    FROM (
        SELECT ann.id, ann.title, ann.message, ann.priority, ann.requires_acknowledgement, ann.created_at
        FROM public.exam_announcement_recipients ar
        JOIN public.exam_announcements ann ON ann.id = ar.announcement_id
        WHERE ar.exam_id = p_exam_id
          AND ar.candidate_id = p_candidate_id
          AND ar.acknowledged_at IS NULL
        ORDER BY ann.created_at DESC
        LIMIT 5
    ) ua;

    RETURN jsonb_build_object(
        'success', TRUE,
        'session_id', v_session.id,
        'monitoring_status', v_session.monitoring_status,
        'is_paused', COALESCE(v_session.is_paused, FALSE) OR COALESCE(v_mon.status = 'PAUSED', FALSE),
        'paused_reason', COALESCE(v_session.paused_reason, v_mon.pause_reason),
        'extra_minutes', COALESCE(v_session.extra_minutes, 0),
        'warnings_count', COALESCE(v_session.warnings_count, 0),
        'teacher_message', v_session.teacher_message,
        'camera_active', COALESCE(v_session.camera_active, FALSE),
        'camera_permission_state', v_session.camera_permission_state,
        'mic_active', COALESCE(v_session.mic_active, FALSE),
        'mic_permission_state', v_session.mic_permission_state,
        'screen_share_active', COALESCE(v_session.screen_share_active, FALSE),
        'screen_share_state', v_session.screen_share_state,
        'remaining_seconds', v_rem_sec,
        'expired', v_rem_sec <= 0,
        'incident_id', v_inc_id,
        'unacknowledged_announcements', v_pending_ann
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_record_candidate_heartbeat_and_event(UUID, UUID, UUID, JSONB) TO anon, authenticated, service_role, postgres;
NOTIFY pgrst, 'reload schema';

