-- ============================================================================
-- Migration 443: Fix Exam Date, Time, Duration and Formatting for Live Monitoring Overview
-- EduSHAMIIT Enterprise School & College ERP
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_exam_monitoring_overview(
    p_school_id UUID,
    p_exam_id UUID,
    p_actor_id UUID,
    p_actor_role TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_auth RECORD;
    v_exam RECORD;
    v_mon RECORD;
    v_subject_name TEXT;
    v_total_questions INT := 0;
    v_total_students INT := 0;
    v_in_exam INT := 0;
    v_warning INT := 0;
    v_violation INT := 0;
    v_paused INT := 0;
    v_disconnected INT := 0;
    v_completed INT := 0;
    v_not_started INT := 0;
    v_online_in_exam INT := 0;
    v_in_progress INT := 0;
    v_open_incidents INT := 0;
    v_flagged_candidates INT := 0;
    v_pending_reentry INT := 0;
    v_exam_remaining_sec INT := 0;
    v_announcements JSONB := '[]'::jsonb;
    v_computed_end TIMESTAMPTZ;
    v_start_time_disp TEXT;
    v_end_time_disp TEXT;
    v_exam_date_disp TEXT;
    v_time_window_disp TEXT;
    v_duration_disp TEXT;
    v_dur_mins INT;
BEGIN
    SELECT * INTO v_auth FROM public._can_monitor_exam(p_school_id, p_exam_id, p_actor_id, p_actor_role);
    IF NOT v_auth.allowed THEN
        RETURN jsonb_build_object('success', FALSE, 'status', v_auth.http_status, 'error', v_auth.denial_reason);
    END IF;

    -- Ensure monitoring session row exists lazily
    INSERT INTO public.exam_monitoring_sessions (
        school_id, exam_id, livekit_room_name, started_by, updated_by
    ) VALUES (
        COALESCE(v_auth.exam_school_id, p_school_id),
        p_exam_id,
        'exam_' || p_exam_id::TEXT,
        p_actor_id,
        p_actor_id
    )
    ON CONFLICT (exam_id) DO NOTHING;

    PERFORM public._sweep_stale_exam_sessions(COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id);

    SELECT e.*, COALESCE(s.name, 'General') AS resolved_subject_name
    INTO v_exam
    FROM public.exams e
    LEFT JOIN public.subjects s ON s.id = e.subject_id
    WHERE e.id = p_exam_id;

    SELECT * INTO v_mon
    FROM public.exam_monitoring_sessions
    WHERE exam_id = p_exam_id;

    SELECT COUNT(*)::INT INTO v_total_questions
    FROM public.exam_questions
    WHERE exam_id = p_exam_id;

    v_dur_mins := COALESCE(v_exam.duration_minutes, 60);

    -- 1. Format Duration display string
    IF v_dur_mins >= 60 THEN
        IF (v_dur_mins % 60) = 0 THEN
            v_duration_disp := (v_dur_mins / 60)::TEXT || CASE WHEN (v_dur_mins / 60) = 1 THEN ' Hour' ELSE ' Hours' END;
        ELSE
            v_duration_disp := (v_dur_mins / 60)::TEXT || 'h ' || (v_dur_mins % 60)::TEXT || 'm';
        END IF;
    ELSE
        v_duration_disp := v_dur_mins::TEXT || ' Mins';
    END IF;

    -- 2. Format Exam Date display string
    v_exam_date_disp := CASE
        WHEN v_exam.exam_date IS NOT NULL THEN TO_CHAR(v_exam.exam_date, 'Mon DD, YYYY')
        WHEN v_exam.start_time IS NOT NULL THEN TO_CHAR(v_exam.start_time AT TIME ZONE 'UTC', 'Mon DD, YYYY')
        ELSE 'Scheduled'
    END;

    -- 3. Format Start Time display string (AT TIME ZONE 'UTC' preserves exact wall-clock hour entered)
    IF v_exam.start_time IS NOT NULL THEN
        v_start_time_disp := TO_CHAR(v_exam.start_time AT TIME ZONE 'UTC', 'HH12:MI AM');
    ELSE
        v_start_time_disp := '09:00 AM';
    END IF;

    -- 4. Format End Time display string
    IF v_exam.end_time IS NOT NULL THEN
        v_end_time_disp := TO_CHAR(v_exam.end_time AT TIME ZONE 'UTC', 'HH12:MI AM');
    ELSIF v_exam.start_time IS NOT NULL THEN
        v_computed_end := v_exam.start_time + (v_dur_mins || ' minutes')::INTERVAL;
        v_end_time_disp := TO_CHAR(v_computed_end AT TIME ZONE 'UTC', 'HH12:MI AM');
    ELSE
        v_end_time_disp := 'Auto-End';
    END IF;

    -- 5. Full time window range
    IF v_end_time_disp IS NOT NULL AND v_end_time_disp <> '' AND v_end_time_disp <> 'Auto-End' THEN
        v_time_window_disp := v_start_time_disp || ' - ' || v_end_time_disp;
    ELSE
        v_time_window_disp := v_start_time_disp;
    END IF;

    IF v_exam.end_time IS NOT NULL THEN
        v_exam_remaining_sec := GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (
            (v_exam.end_time + (COALESCE(v_mon.extended_minutes, 0) * INTERVAL '1 minute')
             + (COALESCE(v_mon.paused_total_seconds, 0) * INTERVAL '1 second')
             + CASE WHEN v_mon.status = 'PAUSED' AND v_mon.paused_at IS NOT NULL
                    THEN GREATEST(0, EXTRACT(EPOCH FROM (NOW() - v_mon.paused_at))) * INTERVAL '1 second'
                    ELSE INTERVAL '0 second' END)
            - NOW()
        )))::INT);
    ELSE
        v_exam_remaining_sec := GREATEST(0, (v_dur_mins + COALESCE(v_mon.extended_minutes, 0)) * 60);
    END IF;

    -- Compute mutually-exclusive status buckets per candidate across roster
    WITH roster AS (
        SELECT candidate_id FROM public._resolve_exam_roster(COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id)
    ),
    latest_sessions AS (
        SELECT DISTINCT ON (es.student_id)
            es.student_id,
            es.monitoring_status,
            es.is_online,
            es.is_paused,
            es.warnings_count
        FROM public.exam_sessions es
        WHERE es.exam_id = p_exam_id
        ORDER BY es.student_id, es.created_at DESC
    ),
    latest_prestart AS (
        SELECT DISTINCT ON (eps.student_id)
            eps.student_id,
            eps.readiness_status
        FROM public.exam_prestart_sessions eps
        WHERE eps.exam_id = p_exam_id
        ORDER BY eps.student_id, eps.updated_at DESC
    ),
    candidate_bucket AS (
        SELECT
            r.candidate_id,
            CASE
                WHEN ls.monitoring_status IN ('SUBMITTED', 'AUTO_SUBMITTED', 'TERMINATED') THEN ls.monitoring_status
                WHEN ls.is_paused = TRUE OR v_mon.status = 'PAUSED' THEN 'PAUSED'
                WHEN ls.monitoring_status = 'VIOLATION' THEN 'VIOLATION'
                WHEN ls.monitoring_status IN ('WARNING', 'UNDER_REVIEW') THEN 'WARNING'
                WHEN ls.monitoring_status = 'RECONNECTING' THEN 'RECONNECTING'
                WHEN ls.monitoring_status = 'DISCONNECTED' OR (ls.student_id IS NOT NULL AND COALESCE(ls.is_online, FALSE) = FALSE) THEN 'DISCONNECTED'
                WHEN ls.monitoring_status = 'ACTIVE' THEN 'ACTIVE'
                WHEN lp.readiness_status = 'READY_TO_START' THEN 'READY'
                ELSE 'NOT_STARTED'
            END AS mon_status,
            COALESCE(ls.is_online, FALSE) AS is_online,
            COALESCE(ls.warnings_count, 0) AS warnings_count
        FROM roster r
        LEFT JOIN latest_sessions ls ON ls.student_id = r.candidate_id
        LEFT JOIN latest_prestart lp ON lp.student_id = r.candidate_id
    )
    SELECT
        COUNT(*)::INT,
        COUNT(*) FILTER (WHERE mon_status IN ('ACTIVE', 'READY'))::INT,
        COUNT(*) FILTER (WHERE mon_status IN ('WARNING', 'RECONNECTING'))::INT,
        COUNT(*) FILTER (WHERE mon_status IN ('VIOLATION', 'UNDER_REVIEW'))::INT,
        COUNT(*) FILTER (WHERE mon_status = 'PAUSED')::INT,
        COUNT(*) FILTER (WHERE mon_status = 'DISCONNECTED')::INT,
        COUNT(*) FILTER (WHERE mon_status IN ('SUBMITTED', 'AUTO_SUBMITTED', 'TERMINATED'))::INT,
        COUNT(*) FILTER (WHERE mon_status = 'NOT_STARTED')::INT,
        COUNT(*) FILTER (WHERE mon_status IN ('ACTIVE', 'WARNING', 'VIOLATION', 'PAUSED') AND is_online = TRUE)::INT,
        COUNT(*) FILTER (WHERE mon_status IN ('ACTIVE', 'WARNING', 'VIOLATION', 'PAUSED', 'RECONNECTING'))::INT,
        COUNT(*) FILTER (WHERE warnings_count > 0 OR mon_status IN ('WARNING', 'VIOLATION', 'UNDER_REVIEW'))::INT
    INTO
        v_total_students,
        v_in_exam,
        v_warning,
        v_violation,
        v_paused,
        v_disconnected,
        v_completed,
        v_not_started,
        v_online_in_exam,
        v_in_progress,
        v_flagged_candidates
    FROM candidate_bucket;

    SELECT COUNT(*)::INT INTO v_open_incidents
    FROM public.exam_incidents
    WHERE exam_id = p_exam_id
      AND status IN ('open', 'acknowledged', 'escalated');

    SELECT COUNT(*)::INT INTO v_pending_reentry
    FROM public.candidate_reentry_requests
    WHERE exam_id = p_exam_id
      AND status = 'pending';

    SELECT COALESCE(jsonb_agg(row_to_json(a) ORDER BY a.created_at DESC), '[]'::jsonb)
    INTO v_announcements
    FROM (
        SELECT
            ann.id,
            ann.title,
            ann.message,
            ann.priority,
            ann.target_scope,
            ann.created_at,
            COALESCE(ann.sent_by_name, p.full_name, 'Invigilator') AS created_by_name
        FROM public.exam_announcements ann
        LEFT JOIN public.profiles p ON p.id = ann.sent_by
        WHERE ann.exam_id = p_exam_id
        ORDER BY ann.created_at DESC
        LIMIT 20
    ) a;

    RETURN jsonb_build_object(
        'success', TRUE,
        'exam', jsonb_build_object(
            'id', v_exam.id,
            'title', v_exam.title,
            'subject', v_exam.resolved_subject_name,
            'subject_name', v_exam.resolved_subject_name,
            'academic_session', COALESCE(v_exam.academic_session, '2025-2026'),
            'applicable_sections', COALESCE(v_exam.applicable_sections, '[]'::jsonb),
            'target_classes', COALESCE(v_exam.target_classes, '[]'::jsonb),
            'exam_date', v_exam_date_disp,
            'exam_date_raw', v_exam.exam_date,
            'start_time', v_start_time_disp,
            'start_time_raw', v_exam.start_time,
            'end_time', v_end_time_disp,
            'end_time_raw', v_exam.end_time,
            'time_window', v_time_window_disp,
            'duration_minutes', v_dur_mins,
            'duration_display', v_duration_disp,
            'total_marks', COALESCE(v_exam.total_marks, 100),
            'total_questions', CASE WHEN v_total_questions > 0 THEN v_total_questions ELSE COALESCE(v_exam.total_questions_count, 0) END,
            'exam_mode', COALESCE(v_exam.exam_mode, v_exam.exam_type, 'online'),
            'exam_type', COALESCE(v_exam.exam_type, 'online'),
            'exam_purpose', v_exam.exam_purpose,
            'status', COALESCE(v_exam.status, 'active'),
            'prestart_config', COALESCE(v_exam.prestart_config, '{}'::jsonb),
            'camera_required', COALESCE(v_exam.camera_required, TRUE),
            'mic_required', COALESCE(v_exam.mic_required, TRUE),
            'server_time_utc', NOW(),
            'exam_remaining_seconds', v_exam_remaining_sec
        ),
        'monitoring_session', jsonb_build_object(
            'id', v_mon.id,
            'status', v_mon.status,
            'paused_at', v_mon.paused_at,
            'paused_total_seconds', v_mon.paused_total_seconds,
            'pause_reason', v_mon.pause_reason,
            'reentry_window_open', v_mon.reentry_window_open,
            'extended_minutes', v_mon.extended_minutes,
            'livekit_room_name', COALESCE(v_mon.livekit_room_name, 'exam_' || p_exam_id::TEXT),
            'auto_flag_tab_switch_threshold', v_mon.auto_flag_tab_switch_threshold,
            'auto_flag_fullscreen_threshold', v_mon.auto_flag_fullscreen_threshold,
            'heartbeat_timeout_seconds', v_mon.heartbeat_timeout_seconds,
            'default_max_reentry_attempts', v_mon.default_max_reentry_attempts,
            'monitoring_settings', COALESCE(v_mon.monitoring_settings, '{}'::jsonb)
        ),
        'kpis', jsonb_build_object(
            'total_students', v_total_students,
            'online_in_exam', v_online_in_exam,
            'in_progress', v_in_progress,
            'violations', v_open_incidents,
            'flagged_candidates', v_flagged_candidates,
            'disconnected', v_disconnected,
            'completed', v_completed,
            'not_started', v_not_started,
            'pending_reentry_requests', v_pending_reentry
        ),
        'status_breakdown', jsonb_build_array(
            jsonb_build_object('key', 'in_exam', 'label', 'In Exam', 'count', v_in_exam, 'percentage', CASE WHEN v_total_students > 0 THEN ROUND((v_in_exam::NUMERIC / v_total_students) * 100, 1) ELSE 0 END),
            jsonb_build_object('key', 'warning', 'label', 'Warning', 'count', v_warning, 'percentage', CASE WHEN v_total_students > 0 THEN ROUND((v_warning::NUMERIC / v_total_students) * 100, 1) ELSE 0 END),
            jsonb_build_object('key', 'violation', 'label', 'Violation', 'count', v_violation, 'percentage', CASE WHEN v_total_students > 0 THEN ROUND((v_violation::NUMERIC / v_total_students) * 100, 1) ELSE 0 END),
            jsonb_build_object('key', 'paused', 'label', 'Paused', 'count', v_paused, 'percentage', CASE WHEN v_total_students > 0 THEN ROUND((v_paused::NUMERIC / v_total_students) * 100, 1) ELSE 0 END),
            jsonb_build_object('key', 'disconnected', 'label', 'Disconnected', 'count', v_disconnected, 'percentage', CASE WHEN v_total_students > 0 THEN ROUND((v_disconnected::NUMERIC / v_total_students) * 100, 1) ELSE 0 END),
            jsonb_build_object('key', 'completed', 'label', 'Completed', 'count', v_completed, 'percentage', CASE WHEN v_total_students > 0 THEN ROUND((v_completed::NUMERIC / v_total_students) * 100, 1) ELSE 0 END),
            jsonb_build_object('key', 'not_started', 'label', 'Not Started', 'count', v_not_started, 'percentage', CASE WHEN v_total_students > 0 THEN ROUND((v_not_started::NUMERIC / v_total_students) * 100, 1) ELSE 0 END)
        ),
        'announcements', v_announcements
    );
END;
$$;

-- Normalize role checking in helper to support super_admin, superadmin, admin, administrator, etc.
CREATE OR REPLACE FUNCTION public._can_monitor_exam(
    p_school_id UUID,
    p_exam_id UUID,
    p_actor_id UUID,
    p_actor_role TEXT
)
RETURNS TABLE (
    allowed BOOLEAN,
    http_status INT,
    denial_reason TEXT,
    exam_exists BOOLEAN,
    exam_school_id UUID,
    livekit_room TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_exam RECORD;
    v_role TEXT := REPLACE(LOWER(BTRIM(COALESCE(p_actor_role, ''))), '-', '_');
    v_purpose TEXT;
    v_mon_settings JSONB := '{}'::jsonb;
    v_is_targeted_candidate BOOLEAN := FALSE;
    v_is_assigned_invigilator BOOLEAN := FALSE;
BEGIN
    SELECT id, school_id, teacher_id, target_students, exam_purpose
    INTO v_exam
    FROM public.exams
    WHERE id = p_exam_id
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 404, 'Examination not found', FALSE, NULL::UUID, NULL::TEXT;
        RETURN;
    END IF;

    IF p_school_id IS NOT NULL AND v_exam.school_id IS NOT NULL AND v_exam.school_id <> p_school_id THEN
        RETURN QUERY SELECT FALSE, 403, 'Tenant isolation violation: examination belongs to another institution', TRUE, v_exam.school_id, NULL::TEXT;
        RETURN;
    END IF;

    SELECT COALESCE(monitoring_settings, '{}'::jsonb), COALESCE(livekit_room_name, 'exam_' || p_exam_id::TEXT)
    INTO v_mon_settings, livekit_room
    FROM public.exam_monitoring_sessions
    WHERE exam_id = p_exam_id
    LIMIT 1;

    IF livekit_room IS NULL THEN
        livekit_room := 'exam_' || p_exam_id::TEXT;
    END IF;

    -- Explicitly deny candidates / non-monitoring roles
    IF v_role IN ('student', 'parent', 'candidate', 'applicant', 'guest', 'anonymous') THEN
        RETURN QUERY SELECT FALSE, 403, 'Candidates are not authorized to monitor examinations', TRUE, v_exam.school_id, livekit_room;
        RETURN;
    END IF;

    -- Privileged ERP / exam controller roles within same school
    IF v_role IN (
        'super_admin', 'superadmin', 'admin', 'administrator', 'principal', 'director', 'vice_principal',
        'exam_ctrl', 'exam_controller', 'academic_admin', 'teacher_admin',
        'student_admin', 'coordinator', 'hod', 'exam_admin'
    ) THEN
        RETURN QUERY SELECT TRUE, 200, NULL::TEXT, TRUE, v_exam.school_id, livekit_room;
        RETURN;
    END IF;

    -- Teachers / Staff / Faculty / Invigilators
    IF v_role IN ('teacher', 'staff', 'faculty', 'invigilator', 'proctor', 'hr') THEN
        v_purpose := LOWER(COALESCE(v_exam.exam_purpose, ''));

        IF p_actor_id IS NOT NULL AND (
            v_exam.teacher_id = p_actor_id
        ) THEN
            RETURN QUERY SELECT TRUE, 200, NULL::TEXT, TRUE, v_exam.school_id, livekit_room;
            RETURN;
        END IF;

        IF p_actor_id IS NOT NULL AND v_mon_settings ? 'assigned_invigilator_ids'
           AND jsonb_typeof(v_mon_settings->'assigned_invigilator_ids') = 'array' THEN
            SELECT EXISTS (
                SELECT 1
                FROM jsonb_array_elements_text(v_mon_settings->'assigned_invigilator_ids') AS aid
                WHERE aid = p_actor_id::TEXT
            ) INTO v_is_assigned_invigilator;
        END IF;

        IF v_is_assigned_invigilator THEN
            RETURN QUERY SELECT TRUE, 200, NULL::TEXT, TRUE, v_exam.school_id, livekit_room;
            RETURN;
        END IF;

        -- Prevent an onboarding/staff examinee from monitoring their own onboarding test
        IF p_actor_id IS NOT NULL AND v_exam.target_students IS NOT NULL
           AND jsonb_typeof(v_exam.target_students) = 'array' THEN
            SELECT EXISTS (
                SELECT 1
                FROM jsonb_array_elements_text(v_exam.target_students) AS sid
                WHERE sid = p_actor_id::TEXT
            ) INTO v_is_targeted_candidate;
        END IF;

        IF v_is_targeted_candidate OR v_purpose LIKE '%onboarding%' OR v_purpose LIKE '%staff%' THEN
            RETURN QUERY SELECT FALSE, 403, 'Examinees cannot monitor an onboarding or assigned examination', TRUE, v_exam.school_id, livekit_room;
            RETURN;
        END IF;

        RETURN QUERY SELECT TRUE, 200, NULL::TEXT, TRUE, v_exam.school_id, livekit_room;
        RETURN;
    END IF;

    RETURN QUERY SELECT FALSE, 403, 'Insufficient permissions to monitor this examination', TRUE, v_exam.school_id, livekit_room;
END;
$$;
