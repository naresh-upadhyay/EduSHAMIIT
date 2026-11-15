-- ============================================================================
-- Migration: 439_enterprise_live_exam_monitoring_rpcs.sql
-- Description: PostgreSQL Stored Procedures (RPCs) for Enterprise Live Exam
--   Monitoring & Invigilation:
--     - Access control & roster resolution (_can_monitor_exam, _resolve_exam_roster)
--     - Stale heartbeat disconnection sweep (_sweep_stale_exam_sessions)
--     - Remaining-seconds calculation honoring pause freeze & extra minutes
--     - Overview KPIs & mutually-exclusive Donut summary (rpc_get_exam_monitoring_overview)
--     - Paginated/filtered/sorted live candidate roster (rpc_get_exam_monitoring_candidates)
--     - Candidate detail timeline/incidents/actions (rpc_get_exam_monitoring_candidate_detail)
--     - Atomic candidate telemetry & proctor event recording (rpc_record_candidate_heartbeat_and_event)
--     - Atomic single & bulk invigilator actions with idempotency & locking (rpc_execute_invigilator_action)
--     - Candidate re-entry request flow (rpc_request_candidate_reentry)
--     - Exam-wide controls (pause/resume/extend/close-reentry/emergency-submit) (rpc_execute_exam_wide_monitoring_control)
--     - Incidents listing & resolution workflow (rpc_get_exam_monitoring_incidents, rpc_resolve_exam_incident)
--     - Live announcements & candidate acks (rpc_create_exam_announcement, rpc_acknowledge_exam_announcement)
--     - Audit log & compliance export report (rpc_get_exam_monitoring_audit_logs, rpc_get_exam_monitoring_report)
-- ============================================================================

-- 1. Helper: Compute server-authoritative remaining seconds for a candidate session
CREATE OR REPLACE FUNCTION public._compute_session_remaining_seconds(
    p_started_at TIMESTAMPTZ,
    p_duration_minutes INT,
    p_extra_minutes INT,
    p_paused_total_seconds INT,
    p_is_paused BOOLEAN,
    p_paused_at TIMESTAMPTZ,
    p_timer_pause_policy TEXT,
    p_monitoring_status TEXT,
    p_exam_paused BOOLEAN DEFAULT FALSE,
    p_exam_paused_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_status TEXT := UPPER(COALESCE(p_monitoring_status, 'ACTIVE'));
    v_frozen_sec INT := GREATEST(0, COALESCE(p_paused_total_seconds, 0));
    v_effective_paused_at TIMESTAMPTZ;
    v_expires_at TIMESTAMPTZ;
BEGIN
    IF p_started_at IS NULL THEN
        RETURN GREATEST(0, COALESCE(p_duration_minutes, 60) * 60);
    END IF;

    IF v_status IN ('SUBMITTED', 'AUTO_SUBMITTED', 'TERMINATED') THEN
        RETURN 0;
    END IF;

    IF COALESCE(p_timer_pause_policy, 'freeze') = 'freeze' THEN
        IF COALESCE(p_is_paused, FALSE) AND p_paused_at IS NOT NULL THEN
            v_effective_paused_at := p_paused_at;
        ELSIF COALESCE(p_exam_paused, FALSE) AND p_exam_paused_at IS NOT NULL THEN
            v_effective_paused_at := p_exam_paused_at;
        END IF;

        IF v_effective_paused_at IS NOT NULL THEN
            v_frozen_sec := v_frozen_sec + GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (NOW() - v_effective_paused_at)))::INT);
        END IF;
    END IF;

    v_expires_at := p_started_at
        + ((GREATEST(1, COALESCE(p_duration_minutes, 60)) + GREATEST(0, COALESCE(p_extra_minutes, 0))) * INTERVAL '1 minute')
        + (v_frozen_sec * INTERVAL '1 second');

    RETURN GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (v_expires_at - NOW())))::INT);
END;
$$;


-- 2. Helper: Strict authorization check for live monitoring
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
    v_role TEXT := LOWER(BTRIM(COALESCE(p_actor_role, '')));
    v_purpose TEXT;
    v_mon_settings JSONB := '{}'::jsonb;
    v_is_targeted_candidate BOOLEAN := FALSE;
    v_is_assigned_invigilator BOOLEAN := FALSE;
BEGIN
    SELECT id, school_id, created_by, teacher_id, target_students, exam_purpose
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
        'super_admin', 'admin', 'principal', 'director', 'vice_principal',
        'exam_ctrl', 'exam_controller', 'academic_admin', 'teacher_admin',
        'student_admin', 'coordinator', 'hod'
    ) THEN
        RETURN QUERY SELECT TRUE, 200, NULL::TEXT, TRUE, v_exam.school_id, livekit_room;
        RETURN;
    END IF;

    -- Teachers / Staff / Faculty / Invigilators
    IF v_role IN ('teacher', 'staff', 'faculty', 'invigilator', 'proctor', 'hr') THEN
        v_purpose := LOWER(COALESCE(v_exam.exam_purpose, ''));

        IF p_actor_id IS NOT NULL AND (
            v_exam.created_by = p_actor_id
            OR v_exam.teacher_id = p_actor_id
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


-- 3. Helper: Resolve full roster of intended candidates & active participants
CREATE OR REPLACE FUNCTION public._resolve_exam_roster(
    p_school_id UUID,
    p_exam_id UUID
)
RETURNS TABLE (
    candidate_id UUID,
    full_name TEXT,
    role TEXT,
    class_name TEXT,
    roll_number INT,
    email TEXT,
    avatar_url TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_exam RECORD;
    v_has_target_students BOOLEAN := FALSE;
    v_has_target_classes BOOLEAN := FALSE;
    v_target_classes TEXT[] := ARRAY[]::TEXT[];
    v_purpose TEXT;
BEGIN
    SELECT id, school_id, target_students, target_classes, applicable_sections, exam_purpose, scope
    INTO v_exam
    FROM public.exams
    WHERE id = p_exam_id
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    IF v_exam.target_students IS NOT NULL AND jsonb_typeof(v_exam.target_students) = 'array'
       AND jsonb_array_length(v_exam.target_students) > 0 THEN
        v_has_target_students := TRUE;
    END IF;

    IF v_exam.target_classes IS NOT NULL AND jsonb_typeof(v_exam.target_classes) = 'array'
       AND jsonb_array_length(v_exam.target_classes) > 0 THEN
        v_has_target_classes := TRUE;
        SELECT COALESCE(ARRAY_AGG(DISTINCT LOWER(BTRIM(val))), ARRAY[]::TEXT[])
        INTO v_target_classes
        FROM (
            SELECT CASE
                WHEN jsonb_typeof(elem) = 'string' THEN elem #>> '{}'
                ELSE COALESCE(elem->>'name', elem->>'class', elem->>'class_name', '')
            END AS val
            FROM jsonb_array_elements(v_exam.target_classes) elem
        ) s
        WHERE BTRIM(val) <> '';
    END IF;

    v_purpose := LOWER(COALESCE(v_exam.exam_purpose, '') || ' ' || COALESCE(v_exam.scope, ''));

    RETURN QUERY
    WITH explicit_targets AS (
        SELECT DISTINCT elem::UUID AS uid
        FROM jsonb_array_elements_text(COALESCE(v_exam.target_students, '[]'::jsonb)) elem
        WHERE v_has_target_students
          AND elem ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    ),
    participant_ids AS (
        SELECT uid FROM explicit_targets
        UNION
        SELECT es.student_id FROM public.exam_sessions es WHERE es.exam_id = p_exam_id AND es.student_id IS NOT NULL
        UNION
        SELECT ep.student_id FROM public.exam_prestart_sessions ep WHERE ep.exam_id = p_exam_id AND ep.student_id IS NOT NULL
        UNION
        SELECT sub.student_id FROM public.exam_submissions sub WHERE sub.exam_id = p_exam_id AND sub.student_id IS NOT NULL
        UNION
        SELECT p.id
        FROM public.profiles p
        WHERE p.school_id = COALESCE(v_exam.school_id, p_school_id)
          AND (
              (v_has_target_classes AND LOWER(COALESCE(p.role, '')) = 'student' AND (
                  LOWER(BTRIM(COALESCE(p.class, ''))) = ANY(v_target_classes)
                  OR ('class ' || LOWER(BTRIM(COALESCE(p.class, '')))) = ANY(v_target_classes)
              ))
              OR (NOT v_has_target_students AND NOT v_has_target_classes AND LOWER(COALESCE(p.role, '')) = 'student'
                  AND v_purpose NOT LIKE '%onboarding%' AND v_purpose NOT LIKE '%teacher%')
          )
    )
    SELECT DISTINCT ON (p.id)
        p.id AS candidate_id,
        COALESCE(NULLIF(BTRIM(p.full_name), ''), p.email, 'Candidate') AS full_name,
        COALESCE(p.role, 'student') AS role,
        COALESCE(p.class, p.department, 'General') AS class_name,
        p.roll_number,
        p.email,
        p.avatar_url
    FROM participant_ids pid
    JOIN public.profiles p ON p.id = pid.uid
    WHERE p.school_id = COALESCE(v_exam.school_id, p_school_id)
    ORDER BY p.id;
END;
$$;


-- 4. Helper: Automatically mark stale active sessions as DISCONNECTED once beyond timeout
CREATE OR REPLACE FUNCTION public._sweep_stale_exam_sessions(
    p_school_id UUID,
    p_exam_id UUID
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_timeout_sec INT := 25;
    v_swept INT := 0;
    v_row RECORD;
BEGIN
    SELECT GREATEST(15, COALESCE(heartbeat_timeout_seconds, 25))
    INTO v_timeout_sec
    FROM public.exam_monitoring_sessions
    WHERE exam_id = p_exam_id
    LIMIT 1;

    FOR v_row IN
        SELECT es.id, es.student_id, es.school_id
        FROM public.exam_sessions es
        WHERE es.exam_id = p_exam_id
          AND (p_school_id IS NULL OR es.school_id = p_school_id)
          AND es.monitoring_status IN ('ACTIVE', 'WARNING', 'VIOLATION', 'RECONNECTING')
          AND es.ended_at IS NULL
          AND COALESCE(es.is_paused, FALSE) = FALSE
          AND es.last_ping IS NOT NULL
          AND es.last_ping < (NOW() - (v_timeout_sec * INTERVAL '1 second'))
        FOR UPDATE OF es SKIP LOCKED
    LOOP
        UPDATE public.exam_sessions
        SET monitoring_status = 'DISCONNECTED',
            is_online = FALSE,
            livekit_connected = FALSE,
            disconnected_at = COALESCE(disconnected_at, NOW()),
            updated_at = NOW()
        WHERE id = v_row.id;

        INSERT INTO public.exam_incidents (
            school_id, exam_id, session_id, candidate_id,
            violation_type, severity, title, description,
            detection_source, status, occurred_at
        ) VALUES (
            COALESCE(v_row.school_id, p_school_id),
            p_exam_id,
            v_row.id,
            v_row.student_id,
            'network_disconnect',
            'medium',
            'Candidate heartbeat lost / disconnected',
            format('No heartbeat received for %s seconds. Session marked Disconnected.', v_timeout_sec),
            'heartbeat',
            'open',
            NOW()
        );

        v_swept := v_swept + 1;
    END LOOP;

    RETURN v_swept;
END;
$$;


-- 5. RPC: Overview (Header context, 6 KPIs, Mutually-Exclusive Donut, Settings, Announcements)
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
        v_exam_remaining_sec := GREATEST(0, (COALESCE(v_exam.duration_minutes, 60) + COALESCE(v_mon.extended_minutes, 0)) * 60);
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
        ORDER BY es.student_id, es.started_at DESC NULLS LAST, es.created_at DESC
    ),
    latest_prestart AS (
        SELECT DISTINCT ON (ep.student_id)
            ep.student_id,
            ep.readiness_status
        FROM public.exam_prestart_sessions ep
        WHERE ep.exam_id = p_exam_id
        ORDER BY ep.student_id, ep.updated_at DESC
    ),
    candidate_bucket AS (
        SELECT
            r.candidate_id,
            CASE
                WHEN ls.student_id IS NULL THEN
                    CASE WHEN UPPER(COALESCE(lp.readiness_status, '')) = 'READY' THEN 'READY' ELSE 'NOT_STARTED' END
                ELSE UPPER(COALESCE(ls.monitoring_status, 'ACTIVE'))
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
            ann.requires_acknowledgement,
            ann.sent_by_name,
            ann.created_at,
            (SELECT COUNT(*)::INT FROM public.exam_announcement_recipients ar WHERE ar.announcement_id = ann.id) AS recipient_count,
            (SELECT COUNT(*)::INT FROM public.exam_announcement_recipients ar WHERE ar.announcement_id = ann.id AND ar.acknowledged_at IS NOT NULL) AS ack_count
        FROM public.exam_announcements ann
        WHERE ann.exam_id = p_exam_id
        ORDER BY ann.created_at DESC
        LIMIT 10
    ) a;

    RETURN jsonb_build_object(
        'success', TRUE,
        'exam', jsonb_build_object(
            'id', v_exam.id,
            'school_id', v_exam.school_id,
            'title', v_exam.title,
            'subject_name', v_exam.resolved_subject_name,
            'target_classes', COALESCE(v_exam.target_classes, '[]'::jsonb),
            'applicable_sections', COALESCE(v_exam.applicable_sections, '[]'::jsonb),
            'exam_date', v_exam.exam_date,
            'start_time', v_exam.start_time,
            'end_time', v_exam.end_time,
            'duration_minutes', COALESCE(v_exam.duration_minutes, 60),
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


-- 6. RPC: Paginated, Filtered & Sorted Candidate Monitoring Roster
CREATE OR REPLACE FUNCTION public.rpc_get_exam_monitoring_candidates(
    p_school_id UUID,
    p_exam_id UUID,
    p_actor_id UUID,
    p_actor_role TEXT,
    p_status TEXT DEFAULT NULL,
    p_violation_filter TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_class_filter TEXT DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 8,
    p_sort_by TEXT DEFAULT 'status_priority',
    p_sort_dir TEXT DEFAULT 'asc'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_auth RECORD;
    v_exam_duration INT := 60;
    v_total_questions INT := 0;
    v_exam_paused BOOLEAN := FALSE;
    v_exam_paused_at TIMESTAMPTZ;
    v_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_page_size INT := LEAST(100, GREATEST(1, COALESCE(p_page_size, 8)));
    v_offset INT;
    v_total INT := 0;
    v_items JSONB := '[]'::jsonb;
BEGIN
    SELECT * INTO v_auth FROM public._can_monitor_exam(p_school_id, p_exam_id, p_actor_id, p_actor_role);
    IF NOT v_auth.allowed THEN
        RETURN jsonb_build_object('success', FALSE, 'status', v_auth.http_status, 'error', v_auth.denial_reason);
    END IF;

    PERFORM public._sweep_stale_exam_sessions(COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id);

    SELECT COALESCE(duration_minutes, 60) INTO v_exam_duration FROM public.exams WHERE id = p_exam_id;
    SELECT COUNT(*)::INT INTO v_total_questions FROM public.exam_questions WHERE exam_id = p_exam_id;
    SELECT (status = 'PAUSED'), paused_at INTO v_exam_paused, v_exam_paused_at
    FROM public.exam_monitoring_sessions WHERE exam_id = p_exam_id LIMIT 1;

    v_offset := (v_page - 1) * v_page_size;

    WITH roster AS (
        SELECT * FROM public._resolve_exam_roster(COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id)
    ),
    latest_sessions AS (
        SELECT DISTINCT ON (es.student_id) es.*
        FROM public.exam_sessions es
        WHERE es.exam_id = p_exam_id
        ORDER BY es.student_id, es.started_at DESC NULLS LAST, es.created_at DESC
    ),
    latest_prestart AS (
        SELECT DISTINCT ON (ep.student_id) ep.*
        FROM public.exam_prestart_sessions ep
        WHERE ep.exam_id = p_exam_id
        ORDER BY ep.student_id, ep.updated_at DESC
    ),
    sub_stats AS (
        SELECT DISTINCT ON (sub.student_id)
            sub.student_id,
            sub.status AS submission_status,
            sub.submitted_at,
            sub.updated_at AS submission_updated_at,
            CASE
                WHEN jsonb_typeof(sub.answers) = 'object' THEN
                    (SELECT COUNT(*)::INT FROM jsonb_each(sub.answers) kv WHERE kv.value IS NOT NULL AND kv.value::TEXT NOT IN ('""', 'null', '[]', '{}'))
                ELSE 0
            END AS calc_answered_count
        FROM public.exam_submissions sub
        WHERE sub.exam_id = p_exam_id
        ORDER BY sub.student_id, sub.updated_at DESC
    ),
    inc_stats AS (
        SELECT
            ei.candidate_id,
            COUNT(*)::INT AS total_incidents,
            COUNT(*) FILTER (WHERE ei.status IN ('open', 'acknowledged', 'escalated'))::INT AS open_incidents,
            MAX(ei.occurred_at) AS last_incident_at,
            (ARRAY_AGG(ei.title ORDER BY ei.occurred_at DESC))[1] AS last_incident_title,
            (ARRAY_AGG(ei.severity ORDER BY ei.occurred_at DESC))[1] AS last_incident_severity
        FROM public.exam_incidents ei
        WHERE ei.exam_id = p_exam_id
        GROUP BY ei.candidate_id
    ),
    reentry_stats AS (
        SELECT DISTINCT ON (rr.candidate_id)
            rr.candidate_id,
            rr.id AS pending_request_id,
            rr.reason AS reentry_reason,
            rr.requested_at AS reentry_requested_at
        FROM public.candidate_reentry_requests rr
        WHERE rr.exam_id = p_exam_id AND rr.status = 'pending'
        ORDER BY rr.candidate_id, rr.requested_at DESC
    ),
    enriched AS (
        SELECT
            r.candidate_id,
            COALESCE(ls.id::TEXT, '') AS session_id,
            r.full_name,
            r.role,
            r.class_name,
            COALESCE(r.roll_number::TEXT, '') AS roll_number,
            r.email,
            r.avatar_url,
            CASE
                WHEN ls.id IS NULL THEN
                    CASE WHEN UPPER(COALESCE(lp.readiness_status, '')) = 'READY' THEN 'READY' ELSE 'NOT_STARTED' END
                ELSE UPPER(COALESCE(ls.monitoring_status, 'ACTIVE'))
            END AS monitoring_status,
            COALESCE(ls.status, 'not_started') AS session_status,
            COALESCE(ls.is_online, FALSE) AS is_online,
            COALESCE(ls.is_paused, FALSE) AS is_paused,
            ls.paused_reason,
            COALESCE(ls.warnings_count, 0) AS warnings_count,
            COALESCE(inc.total_incidents, 0) AS incidents_count,
            COALESCE(inc.open_incidents, 0) AS open_incidents_count,
            inc.last_incident_title,
            inc.last_incident_severity,
            COALESCE(inc.last_incident_at, ls.last_ping, lp.last_activity_at) AS last_activity_at,
            ls.started_at,
            ls.ended_at,
            ls.last_ping,
            COALESCE(ls.extra_minutes, 0) AS extra_minutes,
            COALESCE(ls.reentry_count, 0) AS reentry_count,
            COALESCE(ls.max_reentry_attempts, 2) AS max_reentry_attempts,
            COALESCE(ls.camera_active, FALSE) AS camera_active,
            COALESCE(ls.camera_permission_state, COALESCE(lp.camera_status, 'NOT_CHECKED')) AS camera_permission_state,
            COALESCE(ls.mic_active, FALSE) AS mic_active,
            COALESCE(ls.mic_permission_state, COALESCE(lp.microphone_status, 'NOT_CHECKED')) AS mic_permission_state,
            COALESCE(ls.screen_share_active, FALSE) AS screen_share_active,
            COALESCE(ls.screen_share_state, COALESCE(lp.screen_share_status, 'NOT_SHARED')) AS screen_share_state,
            COALESCE(ls.livekit_connected, FALSE) AS livekit_connected,
            COALESCE(ls.livekit_identity, 'candidate_' || r.candidate_id::TEXT) AS livekit_identity,
            COALESCE(ls.network_status, 'GOOD') AS network_status,
            ls.latency_ms,
            COALESCE(ls.face_detected_count, 1) AS face_detected_count,
            ls.browser_info,
            COALESCE(ls.device_info, '{}'::jsonb) AS device_info,
            COALESCE(ls.last_answer_sync_at, ss.submission_updated_at) AS last_answer_sync_at,
            GREATEST(COALESCE(ls.answered_count, 0), COALESCE(ss.calc_answered_count, 0)) AS answered_count,
            CASE WHEN COALESCE(ls.total_questions_snapshot, 0) > 0 THEN ls.total_questions_snapshot ELSE v_total_questions END AS total_questions,
            COALESCE(ls.current_question_index, 0) AS current_question_index,
            ls.teacher_message,
            rr.pending_request_id,
            rr.reentry_reason,
            rr.reentry_requested_at,
            public._compute_session_remaining_seconds(
                ls.started_at, v_exam_duration, COALESCE(ls.extra_minutes, 0),
                COALESCE(ls.paused_total_seconds, 0), COALESCE(ls.is_paused, FALSE),
                ls.paused_at, ls.timer_pause_policy,
                COALESCE(ls.monitoring_status, 'NOT_STARTED'),
                v_exam_paused, v_exam_paused_at
            ) AS remaining_seconds,
            CASE UPPER(COALESCE(ls.monitoring_status, 'NOT_STARTED'))
                WHEN 'VIOLATION' THEN 1
                WHEN 'DISCONNECTED' THEN 2
                WHEN 'WARNING' THEN 3
                WHEN 'UNDER_REVIEW' THEN 4
                WHEN 'PAUSED' THEN 5
                WHEN 'RECONNECTING' THEN 6
                WHEN 'ACTIVE' THEN 7
                WHEN 'READY' THEN 8
                WHEN 'NOT_STARTED' THEN 9
                WHEN 'SUBMITTED' THEN 10
                WHEN 'AUTO_SUBMITTED' THEN 11
                WHEN 'TERMINATED' THEN 12
                ELSE 99
            END AS priority_rank
        FROM roster r
        LEFT JOIN latest_sessions ls ON ls.student_id = r.candidate_id
        LEFT JOIN latest_prestart lp ON lp.student_id = r.candidate_id
        LEFT JOIN sub_stats ss ON ss.student_id = r.candidate_id
        LEFT JOIN inc_stats inc ON inc.candidate_id = r.candidate_id
        LEFT JOIN reentry_stats rr ON rr.candidate_id = r.candidate_id
    ),
    filtered AS (
        SELECT *
        FROM enriched e
        WHERE (
            p_status IS NULL OR BTRIM(p_status) = '' OR LOWER(p_status) IN ('all', 'all status')
            OR (LOWER(p_status) = 'in_exam' AND e.monitoring_status IN ('ACTIVE', 'READY'))
            OR (LOWER(p_status) = 'active' AND e.monitoring_status IN ('ACTIVE', 'WARNING', 'VIOLATION'))
            OR (LOWER(p_status) = 'warning' AND e.monitoring_status IN ('WARNING', 'RECONNECTING'))
            OR (LOWER(p_status) = 'violation' AND e.monitoring_status IN ('VIOLATION', 'UNDER_REVIEW'))
            OR (LOWER(p_status) = 'paused' AND e.monitoring_status = 'PAUSED')
            OR (LOWER(p_status) = 'disconnected' AND e.monitoring_status = 'DISCONNECTED')
            OR (LOWER(p_status) = 'not_started' AND e.monitoring_status IN ('NOT_STARTED', 'READY'))
            OR (LOWER(p_status) = 'completed' AND e.monitoring_status IN ('SUBMITTED', 'AUTO_SUBMITTED', 'TERMINATED'))
            OR UPPER(e.monitoring_status) = UPPER(p_status)
        )
        AND (
            p_violation_filter IS NULL OR BTRIM(p_violation_filter) = '' OR LOWER(p_violation_filter) IN ('all', 'all violations')
            OR (LOWER(p_violation_filter) IN ('with_violations', 'flagged') AND (e.warnings_count > 0 OR e.incidents_count > 0))
            OR (LOWER(p_violation_filter) IN ('clean', 'none', '0') AND e.warnings_count = 0 AND e.incidents_count = 0)
            OR (LOWER(p_violation_filter) = 'high' AND e.warnings_count >= 2)
            OR (LOWER(p_violation_filter) = 'pending_reentry' AND e.pending_request_id IS NOT NULL)
        )
        AND (
            p_class_filter IS NULL OR BTRIM(p_class_filter) = '' OR LOWER(p_class_filter) IN ('all', 'all students', 'all classes')
            OR LOWER(e.class_name) = LOWER(p_class_filter)
        )
        AND (
            p_search IS NULL OR BTRIM(p_search) = ''
            OR LOWER(e.full_name) LIKE '%' || LOWER(BTRIM(p_search)) || '%'
            OR LOWER(COALESCE(e.roll_number, '')) LIKE '%' || LOWER(BTRIM(p_search)) || '%'
            OR LOWER(COALESCE(e.email, '')) LIKE '%' || LOWER(BTRIM(p_search)) || '%'
            OR LOWER(COALESCE(e.class_name, '')) LIKE '%' || LOWER(BTRIM(p_search)) || '%'
        )
    ),
    counted AS (
        SELECT COUNT(*)::INT AS total_rows FROM filtered
    ),
    paged AS (
        SELECT f.*
        FROM filtered f
        ORDER BY
            CASE WHEN LOWER(p_sort_by) = 'name' AND LOWER(p_sort_dir) = 'desc' THEN f.full_name END DESC,
            CASE WHEN LOWER(p_sort_by) = 'name' AND LOWER(p_sort_dir) <> 'desc' THEN f.full_name END ASC,
            CASE WHEN LOWER(p_sort_by) = 'violations' AND LOWER(p_sort_dir) = 'asc' THEN f.warnings_count END ASC,
            CASE WHEN LOWER(p_sort_by) = 'violations' AND LOWER(p_sort_dir) <> 'asc' THEN f.warnings_count END DESC,
            CASE WHEN LOWER(p_sort_by) = 'roll' THEN f.roll_number END ASC,
            CASE WHEN LOWER(p_sort_by) NOT IN ('name', 'violations', 'roll') THEN f.priority_rank END ASC,
            f.full_name ASC
        LIMIT v_page_size OFFSET v_offset
    )
    SELECT
        (SELECT total_rows FROM counted),
        COALESCE(jsonb_agg(row_to_json(p)), '[]'::jsonb)
    INTO v_total, v_items
    FROM paged p;

    RETURN jsonb_build_object(
        'success', TRUE,
        'candidates', v_items,
        'pagination', jsonb_build_object(
            'page', v_page,
            'page_size', v_page_size,
            'total', COALESCE(v_total, 0),
            'total_pages', GREATEST(1, CEIL(COALESCE(v_total, 0)::NUMERIC / v_page_size)::INT)
        )
    );
END;
$$;


-- 7. RPC: Candidate Detail & Full Timeline for Right Panel / Inspector
CREATE OR REPLACE FUNCTION public.rpc_get_exam_monitoring_candidate_detail(
    p_school_id UUID,
    p_exam_id UUID,
    p_candidate_id UUID,
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
    v_profile RECORD;
    v_session RECORD;
    v_prestart RECORD;
    v_sub RECORD;
    v_mon RECORD;
    v_exam_duration INT := 60;
    v_total_questions INT := 0;
    v_answered INT := 0;
    v_rem_sec INT := 0;
    v_incidents JSONB := '[]'::jsonb;
    v_actions JSONB := '[]'::jsonb;
    v_reentries JSONB := '[]'::jsonb;
    v_time_adj JSONB := '[]'::jsonb;
BEGIN
    SELECT * INTO v_auth FROM public._can_monitor_exam(p_school_id, p_exam_id, p_actor_id, p_actor_role);
    IF NOT v_auth.allowed THEN
        RETURN jsonb_build_object('success', FALSE, 'status', v_auth.http_status, 'error', v_auth.denial_reason);
    END IF;

    SELECT id, full_name, role, class, roll_number, email, avatar_url
    INTO v_profile
    FROM public.profiles
    WHERE id = p_candidate_id
      AND (v_auth.exam_school_id IS NULL OR school_id = v_auth.exam_school_id)
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 404, 'error', 'Candidate not found in this institution');
    END IF;

    SELECT COALESCE(duration_minutes, 60) INTO v_exam_duration FROM public.exams WHERE id = p_exam_id;
    SELECT COUNT(*)::INT INTO v_total_questions FROM public.exam_questions WHERE exam_id = p_exam_id;
    SELECT * INTO v_mon FROM public.exam_monitoring_sessions WHERE exam_id = p_exam_id LIMIT 1;

    SELECT * INTO v_session
    FROM public.exam_sessions
    WHERE exam_id = p_exam_id AND student_id = p_candidate_id
    ORDER BY started_at DESC NULLS LAST, created_at DESC
    LIMIT 1;

    SELECT * INTO v_prestart
    FROM public.exam_prestart_sessions
    WHERE exam_id = p_exam_id AND student_id = p_candidate_id
    ORDER BY updated_at DESC
    LIMIT 1;

    SELECT * INTO v_sub
    FROM public.exam_submissions
    WHERE exam_id = p_exam_id AND student_id = p_candidate_id
    ORDER BY updated_at DESC
    LIMIT 1;

    IF v_sub.answers IS NOT NULL AND jsonb_typeof(v_sub.answers) = 'object' THEN
        SELECT COUNT(*)::INT INTO v_answered
        FROM jsonb_each(v_sub.answers) kv
        WHERE kv.value IS NOT NULL AND kv.value::TEXT NOT IN ('""', 'null', '[]', '{}');
    END IF;

    v_rem_sec := public._compute_session_remaining_seconds(
        v_session.started_at, v_exam_duration, COALESCE(v_session.extra_minutes, 0),
        COALESCE(v_session.paused_total_seconds, 0), COALESCE(v_session.is_paused, FALSE),
        v_session.paused_at, v_session.timer_pause_policy,
        COALESCE(v_session.monitoring_status, 'NOT_STARTED'),
        COALESCE(v_mon.status = 'PAUSED', FALSE), v_mon.paused_at
    );

    SELECT COALESCE(jsonb_agg(row_to_json(i) ORDER BY i.occurred_at DESC), '[]'::jsonb)
    INTO v_incidents
    FROM (
        SELECT id, violation_type, severity, title, description, detection_source, status,
               duration_seconds, occurred_at, metadata, resolved_at, resolution_note
        FROM public.exam_incidents
        WHERE exam_id = p_exam_id AND candidate_id = p_candidate_id
        ORDER BY occurred_at DESC
        LIMIT 50
    ) i;

    SELECT COALESCE(jsonb_agg(row_to_json(a) ORDER BY a.created_at DESC), '[]'::jsonb)
    INTO v_actions
    FROM (
        SELECT id, actor_name, actor_role, action_type, reason, payload, created_at
        FROM public.invigilator_actions
        WHERE exam_id = p_exam_id AND candidate_id = p_candidate_id
        ORDER BY created_at DESC
        LIMIT 50
    ) a;

    SELECT COALESCE(jsonb_agg(row_to_json(rr) ORDER BY rr.requested_at DESC), '[]'::jsonb)
    INTO v_reentries
    FROM (
        SELECT id, status, reason, disconnect_reason, requested_at, reviewed_at, review_note
        FROM public.candidate_reentry_requests
        WHERE exam_id = p_exam_id AND candidate_id = p_candidate_id
        ORDER BY requested_at DESC
        LIMIT 20
    ) rr;

    SELECT COALESCE(jsonb_agg(row_to_json(ta) ORDER BY ta.created_at DESC), '[]'::jsonb)
    INTO v_time_adj
    FROM (
        SELECT id, minutes_added, reason, granted_by_name, created_at
        FROM public.candidate_time_adjustments
        WHERE exam_id = p_exam_id AND candidate_id = p_candidate_id
        ORDER BY created_at DESC
        LIMIT 20
    ) ta;

    RETURN jsonb_build_object(
        'success', TRUE,
        'candidate', jsonb_build_object(
            'candidate_id', v_profile.id,
            'full_name', v_profile.full_name,
            'role', v_profile.role,
            'class_name', COALESCE(v_profile.class, 'General'),
            'roll_number', COALESCE(v_profile.roll_number::TEXT, ''),
            'email', v_profile.email,
            'avatar_url', v_profile.avatar_url,
            'session_id', v_session.id,
            'monitoring_status', COALESCE(v_session.monitoring_status, CASE WHEN v_prestart.readiness_status = 'READY' THEN 'READY' ELSE 'NOT_STARTED' END),
            'is_online', COALESCE(v_session.is_online, FALSE),
            'is_paused', COALESCE(v_session.is_paused, FALSE),
            'paused_reason', v_session.paused_reason,
            'warnings_count', COALESCE(v_session.warnings_count, 0),
            'extra_minutes', COALESCE(v_session.extra_minutes, 0),
            'remaining_seconds', v_rem_sec,
            'started_at', v_session.started_at,
            'ended_at', v_session.ended_at,
            'last_ping', v_session.last_ping,
            'last_answer_sync_at', COALESCE(v_session.last_answer_sync_at, v_sub.updated_at),
            'answered_count', GREATEST(COALESCE(v_session.answered_count, 0), v_answered),
            'marked_count', COALESCE(v_session.marked_count, 0),
            'total_questions', v_total_questions,
            'camera_active', COALESCE(v_session.camera_active, FALSE),
            'camera_permission_state', COALESCE(v_session.camera_permission_state, COALESCE(v_prestart.camera_status, 'NOT_CHECKED')),
            'mic_active', COALESCE(v_session.mic_active, FALSE),
            'mic_permission_state', COALESCE(v_session.mic_permission_state, COALESCE(v_prestart.microphone_status, 'NOT_CHECKED')),
            'screen_share_active', COALESCE(v_session.screen_share_active, FALSE),
            'screen_share_state', COALESCE(v_session.screen_share_state, COALESCE(v_prestart.screen_share_status, 'NOT_SHARED')),
            'livekit_connected', COALESCE(v_session.livekit_connected, FALSE),
            'livekit_identity', COALESCE(v_session.livekit_identity, 'candidate_' || v_profile.id::TEXT),
            'network_status', COALESCE(v_session.network_status, 'GOOD'),
            'latency_ms', v_session.latency_ms,
            'browser_info', COALESCE(v_session.browser_info, v_prestart.system_details->>'browser'),
            'device_info', COALESCE(v_session.device_info, v_prestart.system_details, '{}'::jsonb),
            'reentry_count', COALESCE(v_session.reentry_count, 0),
            'max_reentry_attempts', COALESCE(v_session.max_reentry_attempts, 2),
            'teacher_message', v_session.teacher_message
        ),
        'incidents', v_incidents,
        'actions', v_actions,
        'reentry_requests', v_reentries,
        'time_adjustments', v_time_adj
    );
END;
$$;


-- 8. RPC: Record Candidate Heartbeat, Live Telemetry & Proctoring Violation Events
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
        RETURN jsonb_build_object('success', FALSE, 'status', 404, 'error', 'No examination session found for candidate');
    END IF;

    -- Do not reactivate terminated or already submitted sessions via heartbeat
    IF UPPER(COALESCE(v_session.monitoring_status, '')) IN ('SUBMITTED', 'AUTO_SUBMITTED', 'TERMINATED') THEN
        RETURN jsonb_build_object(
            'success', TRUE,
            'session_id', v_session.id,
            'monitoring_status', v_session.monitoring_status,
            'is_paused', COALESCE(v_session.is_paused, FALSE),
            'terminated', UPPER(v_session.monitoring_status) = 'TERMINATED',
            'submitted', UPPER(v_session.monitoring_status) IN ('SUBMITTED', 'AUTO_SUBMITTED'),
            'remaining_seconds', 0
        );
    END IF;

    v_new_warnings := COALESCE(v_session.warnings_count, 0);
    v_new_status := UPPER(COALESCE(v_session.monitoring_status, 'ACTIVE'));
    IF v_new_status IN ('DISCONNECTED', 'RECONNECTING') AND NOT COALESCE(v_session.is_paused, FALSE) THEN
        v_new_status := CASE WHEN v_new_warnings >= v_thresh THEN 'VIOLATION'
                             WHEN v_new_warnings > 0 THEN 'WARNING'
                             ELSE 'ACTIVE' END;
    END IF;

    v_logs := COALESCE(v_session.proctor_logs, '[]'::jsonb);
    IF jsonb_typeof(v_logs) <> 'array' THEN
        v_logs := '[]'::jsonb;
    END IF;

    IF v_event_type IS NOT NULL THEN
        v_title := COALESCE(NULLIF(BTRIM(p_payload->>'title'), ''), INITCAP(REPLACE(v_event_type, '_', ' ')));
        v_desc := NULLIF(BTRIM(p_payload->>'description'), '');

        INSERT INTO public.exam_incidents (
            school_id, exam_id, session_id, candidate_id,
            violation_type, severity, title, description,
            detection_source, status, duration_seconds, occurred_at, metadata
        ) VALUES (
            COALESCE(v_exam.school_id, p_school_id), p_exam_id, v_session.id, p_candidate_id,
            v_event_type, v_severity, v_title, v_desc,
            v_det_source, 'open', v_duration_sec, NOW(), COALESCE(p_payload->'metadata', '{}'::jsonb)
        )
        RETURNING id INTO v_inc_id;

        IF v_severity IN ('medium', 'high', 'critical', 'warning') THEN
            v_new_warnings := v_new_warnings + 1;
        END IF;

        v_logs := v_logs || jsonb_build_array(jsonb_build_object(
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
        camera_active = COALESCE((p_payload->>'camera_active')::BOOLEAN, camera_active),
        camera_permission_state = COALESCE(NULLIF(p_payload->>'camera_permission_state', ''), camera_permission_state),
        mic_active = COALESCE((p_payload->>'mic_active')::BOOLEAN, mic_active),
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

    -- Unacknowledged urgent announcements addressed to candidate
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
        'remaining_seconds', v_rem_sec,
        'expired', v_rem_sec <= 0,
        'incident_id', v_inc_id,
        'unacknowledged_announcements', v_pending_ann
    );
END;
$$;


-- 9. RPC: Atomic Single or Bulk Invigilator Actions
CREATE OR REPLACE FUNCTION public.rpc_execute_invigilator_action(
    p_school_id UUID,
    p_exam_id UUID,
    p_actor_id UUID,
    p_actor_name TEXT,
    p_actor_role TEXT,
    p_action_type TEXT,
    p_candidate_ids JSONB,
    p_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_auth RECORD;
    v_action TEXT := LOWER(BTRIM(COALESCE(p_action_type, '')));
    v_idem_key TEXT := NULLIF(BTRIM(p_payload->>'idempotency_key'), '');
    v_existing_action RECORD;
    v_reason TEXT := COALESCE(NULLIF(BTRIM(p_payload->>'reason'), ''), NULLIF(BTRIM(p_payload->>'message'), ''), 'Invigilator action');
    v_minutes INT := COALESCE((p_payload->>'minutes')::INT, 15);
    v_pause_policy TEXT := LOWER(COALESCE(NULLIF(p_payload->>'timer_pause_policy', ''), 'freeze'));
    v_cid UUID;
    v_session RECORD;
    v_mon RECORD;
    v_paused_delta INT := 0;
    v_results JSONB := '[]'::jsonb;
    v_affected INT := 0;
    v_errors JSONB := '[]'::jsonb;
    v_scope TEXT;
    v_new_mon_status TEXT;
    v_exam_duration INT := 60;
    v_rem_sec INT := 0;
BEGIN
    SELECT * INTO v_auth FROM public._can_monitor_exam(p_school_id, p_exam_id, p_actor_id, p_actor_role);
    IF NOT v_auth.allowed THEN
        RETURN jsonb_build_object('success', FALSE, 'status', v_auth.http_status, 'error', v_auth.denial_reason);
    END IF;

    IF v_action NOT IN (
        'warn', 'pause', 'resume', 'extend_time', 'give_chance',
        'approve_reentry', 'reject_reentry', 'terminate', 'force_submit',
        'request_camera', 'request_mic', 'request_screen_share',
        'force_mute_mic', 'force_disable_cam', 'escalate', 'reopen'
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 400, 'error', format('Unsupported invigilator action: %s', p_action_type));
    END IF;

    IF v_idem_key IS NOT NULL THEN
        SELECT id, payload, created_at INTO v_existing_action
        FROM public.invigilator_actions
        WHERE exam_id = p_exam_id AND idempotency_key = v_idem_key
        LIMIT 1;
        IF FOUND THEN
            RETURN jsonb_build_object('success', TRUE, 'idempotent_replay', TRUE, 'action_id', v_existing_action.id, 'results', COALESCE(v_existing_action.payload->'results', '[]'::jsonb));
        END IF;
    END IF;

    IF p_candidate_ids IS NULL OR jsonb_typeof(p_candidate_ids) <> 'array' OR jsonb_array_length(p_candidate_ids) = 0 THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 400, 'error', 'At least one candidate_id is required');
    END IF;

    IF v_action = 'extend_time' AND (v_minutes < 1 OR v_minutes > 180) THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 400, 'error', 'Additional time must be between 1 and 180 minutes');
    END IF;

    v_scope := CASE WHEN jsonb_array_length(p_candidate_ids) > 1 THEN 'bulk' ELSE 'candidate' END;
    SELECT COALESCE(duration_minutes, 60) INTO v_exam_duration FROM public.exams WHERE id = p_exam_id;
    SELECT * INTO v_mon FROM public.exam_monitoring_sessions WHERE exam_id = p_exam_id LIMIT 1;

    FOR v_cid IN
        SELECT DISTINCT elem::UUID
        FROM jsonb_array_elements_text(p_candidate_ids) elem
        WHERE elem ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    LOOP
        PERFORM pg_advisory_xact_lock(hashtext(p_exam_id::TEXT || ':' || v_cid::TEXT));

        SELECT * INTO v_session
        FROM public.exam_sessions
        WHERE exam_id = p_exam_id AND student_id = v_cid
        ORDER BY started_at DESC NULLS LAST, created_at DESC
        LIMIT 1
        FOR UPDATE;

        IF NOT FOUND THEN
            v_errors := v_errors || jsonb_build_object('candidate_id', v_cid, 'error', 'Candidate has not started an exam session');
            CONTINUE;
        END IF;

        -- Enforce state machine conflict checks (cannot mutate finalized attempts unless reopen)
        IF UPPER(COALESCE(v_session.monitoring_status, '')) IN ('TERMINATED', 'SUBMITTED', 'AUTO_SUBMITTED')
           AND v_action NOT IN ('reopen') THEN
            IF jsonb_array_length(p_candidate_ids) = 1 THEN
                RETURN jsonb_build_object(
                    'success', FALSE,
                    'status', 409,
                    'error', format('Conflict: candidate session is already %s', v_session.monitoring_status)
                );
            ELSE
                v_errors := v_errors || jsonb_build_object('candidate_id', v_cid, 'error', format('Session already %s', v_session.monitoring_status));
                CONTINUE;
            END IF;
        END IF;

        IF v_action = 'warn' THEN
            v_new_mon_status := CASE
                WHEN COALESCE(v_session.is_paused, FALSE) THEN 'PAUSED'
                WHEN (COALESCE(v_session.warnings_count, 0) + 1) >= COALESCE(v_mon.auto_flag_tab_switch_threshold, 3) THEN 'VIOLATION'
                ELSE 'WARNING'
            END;

            UPDATE public.exam_sessions
            SET warnings_count = COALESCE(warnings_count, 0) + 1,
                teacher_message = v_reason,
                monitoring_status = v_new_mon_status,
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

            INSERT INTO public.exam_incidents (
                school_id, exam_id, session_id, candidate_id,
                violation_type, severity, title, description, detection_source, status
            ) VALUES (
                COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id, v_session.id, v_cid,
                'invigilator_flag', 'high', 'Official Invigilator Warning', v_reason, 'invigilator', 'open'
            );

        ELSIF v_action = 'pause' THEN
            IF NOT COALESCE(v_session.is_paused, FALSE) THEN
                UPDATE public.exam_sessions
                SET is_paused = TRUE,
                    paused_at = NOW(),
                    paused_reason = v_reason,
                    timer_pause_policy = v_pause_policy,
                    monitoring_status = 'PAUSED',
                    teacher_message = v_reason,
                    updated_at = NOW()
                WHERE id = v_session.id
                RETURNING * INTO v_session;
            END IF;

        ELSIF v_action = 'resume' THEN
            IF COALESCE(v_session.is_paused, FALSE) THEN
                v_paused_delta := CASE
                    WHEN COALESCE(v_session.timer_pause_policy, 'freeze') = 'freeze' AND v_session.paused_at IS NOT NULL
                    THEN GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (NOW() - v_session.paused_at)))::INT)
                    ELSE 0
                END;
                v_new_mon_status := CASE
                    WHEN COALESCE(v_session.warnings_count, 0) >= COALESCE(v_mon.auto_flag_tab_switch_threshold, 3) THEN 'VIOLATION'
                    WHEN COALESCE(v_session.warnings_count, 0) > 0 THEN 'WARNING'
                    ELSE 'ACTIVE'
                END;
                UPDATE public.exam_sessions
                SET is_paused = FALSE,
                    paused_at = NULL,
                    paused_total_seconds = COALESCE(paused_total_seconds, 0) + v_paused_delta,
                    paused_reason = NULL,
                    monitoring_status = v_new_mon_status,
                    teacher_message = NULLIF(p_payload->>'message', ''),
                    updated_at = NOW()
                WHERE id = v_session.id
                RETURNING * INTO v_session;
            END IF;

        ELSIF v_action = 'extend_time' THEN
            IF COALESCE(v_session.extra_minutes, 0) + v_minutes > 180 THEN
                IF jsonb_array_length(p_candidate_ids) = 1 THEN
                    RETURN jsonb_build_object('success', FALSE, 'status', 400, 'error', 'Cumulative extra time cannot exceed 180 minutes');
                END IF;
                v_errors := v_errors || jsonb_build_object('candidate_id', v_cid, 'error', 'Exceeds max 180 min extra time');
                CONTINUE;
            END IF;

            UPDATE public.exam_sessions
            SET extra_minutes = COALESCE(extra_minutes, 0) + v_minutes,
                teacher_message = format('+%s mins granted: %s', v_minutes, v_reason),
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

            INSERT INTO public.candidate_time_adjustments (
                school_id, exam_id, session_id, candidate_id, minutes_added, reason, granted_by, granted_by_name
            ) VALUES (
                COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id, v_session.id, v_cid, v_minutes, v_reason, p_actor_id, p_actor_name
            );

        ELSIF v_action = 'give_chance' THEN
            UPDATE public.exam_sessions
            SET warnings_count = GREATEST(0, COALESCE(warnings_count, 0) - 1),
                max_reentry_attempts = COALESCE(max_reentry_attempts, 2) + 1,
                is_paused = FALSE,
                paused_at = NULL,
                monitoring_status = CASE WHEN COALESCE(warnings_count, 0) - 1 > 0 THEN 'WARNING' ELSE 'ACTIVE' END,
                teacher_message = v_reason,
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

        ELSIF v_action = 'approve_reentry' THEN
            IF COALESCE(v_mon.reentry_window_open, TRUE) = FALSE AND COALESCE((p_payload->>'override')::BOOLEAN, FALSE) = FALSE THEN
                RETURN jsonb_build_object('success', FALSE, 'status', 409, 'error', 'Examination re-entry window is closed');
            END IF;

            UPDATE public.exam_sessions
            SET status = 'in_progress',
                monitoring_status = CASE
                    WHEN COALESCE(warnings_count, 0) >= COALESCE(v_mon.auto_flag_tab_switch_threshold, 3) THEN 'VIOLATION'
                    WHEN COALESCE(warnings_count, 0) > 0 THEN 'WARNING'
                    ELSE 'ACTIVE'
                END,
                is_paused = FALSE,
                paused_at = NULL,
                ended_at = NULL,
                disconnected_at = NULL,
                is_online = TRUE,
                reentry_count = COALESCE(reentry_count, 0) + 1,
                last_ping = NOW(),
                teacher_message = COALESCE(NULLIF(v_reason, 'Invigilator action'), 'Re-entry approved by invigilator'),
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

            UPDATE public.candidate_reentry_requests
            SET status = 'approved',
                reviewed_by = p_actor_id,
                reviewed_at = NOW(),
                review_note = v_reason
            WHERE exam_id = p_exam_id AND candidate_id = v_cid AND status = 'pending';

        ELSIF v_action = 'reject_reentry' THEN
            UPDATE public.candidate_reentry_requests
            SET status = 'rejected',
                reviewed_by = p_actor_id,
                reviewed_at = NOW(),
                review_note = v_reason
            WHERE exam_id = p_exam_id AND candidate_id = v_cid AND status = 'pending';

            UPDATE public.exam_sessions
            SET teacher_message = format('Re-entry rejected: %s', v_reason),
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

        ELSIF v_action IN ('terminate', 'force_submit') THEN
            v_new_mon_status := CASE WHEN v_action = 'terminate' THEN 'TERMINATED' ELSE 'AUTO_SUBMITTED' END;
            UPDATE public.exam_sessions
            SET status = CASE WHEN v_action = 'terminate' THEN 'terminated' ELSE 'completed' END,
                monitoring_status = v_new_mon_status,
                ended_at = NOW(),
                is_online = FALSE,
                is_paused = FALSE,
                terminated_at = CASE WHEN v_action = 'terminate' THEN NOW() ELSE terminated_at END,
                terminated_reason = CASE WHEN v_action = 'terminate' THEN v_reason ELSE terminated_reason END,
                teacher_message = v_reason,
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

        ELSIF v_action = 'force_mute_mic' THEN
            UPDATE public.exam_sessions
            SET mic_active = FALSE,
                teacher_message = COALESCE(NULLIF(v_reason, 'Invigilator action'), 'Microphone muted by invigilator'),
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

        ELSIF v_action = 'force_disable_cam' THEN
            UPDATE public.exam_sessions
            SET camera_active = FALSE,
                teacher_message = COALESCE(NULLIF(v_reason, 'Invigilator action'), 'Camera disabled by invigilator'),
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

        ELSIF v_action IN ('request_camera', 'request_mic', 'request_screen_share') THEN
            UPDATE public.exam_sessions
            SET teacher_message = COALESCE(NULLIF(v_reason, 'Invigilator action'), format('Invigilator requested %s check', REPLACE(v_action, 'request_', ''))),
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

        ELSIF v_action = 'escalate' THEN
            UPDATE public.exam_sessions
            SET monitoring_status = CASE WHEN monitoring_status IN ('PAUSED', 'SUBMITTED', 'AUTO_SUBMITTED', 'TERMINATED') THEN monitoring_status ELSE 'UNDER_REVIEW' END,
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

            INSERT INTO public.exam_incidents (
                school_id, exam_id, session_id, candidate_id,
                violation_type, severity, title, description,
                detection_source, status, escalated_to
            ) VALUES (
                COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id, v_session.id, v_cid,
                'invigilator_flag', 'critical', 'Escalated to Chief Invigilator', v_reason,
                'invigilator', 'escalated', NULLIF(p_payload->>'escalate_to', '')::UUID
            );

        ELSIF v_action = 'reopen' THEN
            UPDATE public.exam_sessions
            SET status = 'in_progress',
                monitoring_status = 'ACTIVE',
                ended_at = NULL,
                terminated_at = NULL,
                terminated_reason = NULL,
                is_paused = FALSE,
                paused_at = NULL,
                last_ping = NOW(),
                max_reentry_attempts = COALESCE(max_reentry_attempts, 2) + 1,
                teacher_message = COALESCE(NULLIF(v_reason, 'Invigilator action'), 'Session reopened by administrator'),
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;
        END IF;

        v_rem_sec := public._compute_session_remaining_seconds(
            v_session.started_at, v_exam_duration, COALESCE(v_session.extra_minutes, 0),
            COALESCE(v_session.paused_total_seconds, 0), COALESCE(v_session.is_paused, FALSE),
            v_session.paused_at, v_session.timer_pause_policy,
            v_session.monitoring_status,
            COALESCE(v_mon.status = 'PAUSED', FALSE), v_mon.paused_at
        );

        INSERT INTO public.invigilator_actions (
            school_id, exam_id, session_id, candidate_id,
            actor_id, actor_name, actor_role, action_type, scope, reason, payload, idempotency_key
        ) VALUES (
            COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id, v_session.id, v_cid,
            p_actor_id, p_actor_name, p_actor_role, v_action, v_scope, v_reason,
            COALESCE(p_payload, '{}'::jsonb) || jsonb_build_object('monitoring_status', v_session.monitoring_status, 'remaining_seconds', v_rem_sec),
            CASE WHEN v_scope = 'candidate' THEN v_idem_key ELSE NULL END
        );

        v_results := v_results || jsonb_build_object(
            'candidate_id', v_cid,
            'session_id', v_session.id,
            'monitoring_status', v_session.monitoring_status,
            'is_paused', COALESCE(v_session.is_paused, FALSE),
            'warnings_count', COALESCE(v_session.warnings_count, 0),
            'extra_minutes', COALESCE(v_session.extra_minutes, 0),
            'remaining_seconds', v_rem_sec,
            'teacher_message', v_session.teacher_message
        );
        v_affected := v_affected + 1;
    END LOOP;

    IF v_affected > 0 THEN
        INSERT INTO public.exam_activity_logs (
            school_id, exam_id, action, title, description, details, performed_by, performed_by_name, icon, color
        ) VALUES (
            COALESCE(v_auth.exam_school_id, p_school_id),
            p_exam_id,
            'proctor_' || v_action,
            'Invigilator Action: ' || INITCAP(REPLACE(v_action, '_', ' ')),
            format('%s (%s candidate(s)): %s', COALESCE(p_actor_name, 'Invigilator'), v_affected, v_reason),
            jsonb_build_object('action_type', v_action, 'affected_count', v_affected, 'candidate_ids', p_candidate_ids),
            p_actor_id,
            p_actor_name,
            CASE WHEN v_action IN ('terminate', 'force_submit') THEN 'gavel' WHEN v_action = 'warn' THEN 'warning' ELSE 'security' END,
            CASE WHEN v_action IN ('terminate', 'force_submit', 'escalate') THEN 'red' WHEN v_action = 'warn' THEN 'orange' ELSE 'blue' END
        );
    END IF;

    RETURN jsonb_build_object(
        'success', v_affected > 0 OR jsonb_array_length(v_errors) = 0,
        'action_type', v_action,
        'affected_count', v_affected,
        'results', v_results,
        'errors', v_errors
    );
END;
$$;


-- 10. RPC: Candidate submits re-entry request
CREATE OR REPLACE FUNCTION public.rpc_request_candidate_reentry(
    p_school_id UUID,
    p_exam_id UUID,
    p_candidate_id UUID,
    p_reason TEXT
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
    v_req_id UUID;
BEGIN
    SELECT id, school_id INTO v_exam FROM public.exams WHERE id = p_exam_id LIMIT 1;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 404, 'error', 'Examination not found');
    END IF;
    IF p_school_id IS NOT NULL AND v_exam.school_id IS NOT NULL AND v_exam.school_id <> p_school_id THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 403, 'error', 'Tenant isolation violation');
    END IF;

    SELECT * INTO v_mon FROM public.exam_monitoring_sessions WHERE exam_id = p_exam_id LIMIT 1;
    IF COALESCE(v_mon.reentry_window_open, TRUE) = FALSE THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 403, 'error', 'Examination re-entry window is closed');
    END IF;

    SELECT * INTO v_session
    FROM public.exam_sessions
    WHERE exam_id = p_exam_id AND student_id = p_candidate_id
    ORDER BY started_at DESC NULLS LAST, created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 404, 'error', 'No active or prior session found to rejoin');
    END IF;

    IF UPPER(COALESCE(v_session.monitoring_status, '')) IN ('SUBMITTED', 'AUTO_SUBMITTED', 'TERMINATED') THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 409, 'error', format('Cannot request re-entry for %s session', v_session.monitoring_status));
    END IF;

    -- Return existing pending request if already requested
    SELECT id INTO v_req_id
    FROM public.candidate_reentry_requests
    WHERE exam_id = p_exam_id AND candidate_id = p_candidate_id AND status = 'pending'
    ORDER BY requested_at DESC
    LIMIT 1;

    IF v_req_id IS NULL THEN
        INSERT INTO public.candidate_reentry_requests (
            school_id, exam_id, session_id, candidate_id, status, reason, disconnect_reason
        ) VALUES (
            COALESCE(v_exam.school_id, p_school_id), p_exam_id, v_session.id, p_candidate_id,
            'pending', COALESCE(NULLIF(BTRIM(p_reason), ''), 'Candidate requested examination re-entry'),
            v_session.paused_reason
        )
        RETURNING id INTO v_req_id;
    END IF;

    RETURN jsonb_build_object('success', TRUE, 'request_id', v_req_id, 'status', 'pending');
END;
$$;


-- 11. RPC: Exam-Wide Monitoring Controls (Pause All / Resume All / Extend / Close Re-entry / Emergency Submit)
CREATE OR REPLACE FUNCTION public.rpc_execute_exam_wide_monitoring_control(
    p_school_id UUID,
    p_exam_id UUID,
    p_actor_id UUID,
    p_actor_name TEXT,
    p_actor_role TEXT,
    p_control_action TEXT,
    p_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_auth RECORD;
    v_action TEXT := LOWER(BTRIM(COALESCE(p_control_action, '')));
    v_reason TEXT := COALESCE(NULLIF(BTRIM(p_payload->>'reason'), ''), 'Exam-wide invigilator control');
    v_minutes INT := COALESCE((p_payload->>'minutes')::INT, 15);
    v_mon RECORD;
    v_paused_delta INT := 0;
    v_affected INT := 0;
BEGIN
    SELECT * INTO v_auth FROM public._can_monitor_exam(p_school_id, p_exam_id, p_actor_id, p_actor_role);
    IF NOT v_auth.allowed THEN
        RETURN jsonb_build_object('success', FALSE, 'status', v_auth.http_status, 'error', v_auth.denial_reason);
    END IF;

    INSERT INTO public.exam_monitoring_sessions (school_id, exam_id, livekit_room_name, started_by, updated_by)
    VALUES (COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id, 'exam_' || p_exam_id::TEXT, p_actor_id, p_actor_id)
    ON CONFLICT (exam_id) DO NOTHING;

    SELECT * INTO v_mon FROM public.exam_monitoring_sessions WHERE exam_id = p_exam_id FOR UPDATE;

    IF v_action = 'pause_exam' THEN
        IF v_mon.status <> 'PAUSED' THEN
            UPDATE public.exam_monitoring_sessions
            SET status = 'PAUSED',
                paused_at = NOW(),
                pause_reason = v_reason,
                updated_by = p_actor_id
            WHERE exam_id = p_exam_id;

            UPDATE public.exam_sessions
            SET is_paused = TRUE,
                paused_at = COALESCE(paused_at, NOW()),
                paused_reason = v_reason,
                timer_pause_policy = 'freeze',
                monitoring_status = 'PAUSED',
                teacher_message = v_reason
            WHERE exam_id = p_exam_id
              AND monitoring_status IN ('ACTIVE', 'WARNING', 'VIOLATION', 'RECONNECTING');
            GET DIAGNOSTICS v_affected = ROW_COUNT;
        END IF;

    ELSIF v_action = 'resume_exam' THEN
        IF v_mon.status = 'PAUSED' THEN
            v_paused_delta := CASE
                WHEN v_mon.paused_at IS NOT NULL THEN GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (NOW() - v_mon.paused_at)))::INT)
                ELSE 0
            END;
            UPDATE public.exam_monitoring_sessions
            SET status = 'ACTIVE',
                paused_at = NULL,
                paused_total_seconds = COALESCE(paused_total_seconds, 0) + v_paused_delta,
                pause_reason = NULL,
                updated_by = p_actor_id
            WHERE exam_id = p_exam_id;

            UPDATE public.exam_sessions
            SET is_paused = FALSE,
                paused_total_seconds = COALESCE(paused_total_seconds, 0) + CASE
                    WHEN paused_at IS NOT NULL THEN GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (NOW() - paused_at)))::INT)
                    ELSE 0
                END,
                paused_at = NULL,
                paused_reason = NULL,
                monitoring_status = CASE
                    WHEN COALESCE(warnings_count, 0) >= COALESCE(v_mon.auto_flag_tab_switch_threshold, 3) THEN 'VIOLATION'
                    WHEN COALESCE(warnings_count, 0) > 0 THEN 'WARNING'
                    ELSE 'ACTIVE'
                END,
                teacher_message = NULLIF(p_payload->>'message', '')
            WHERE exam_id = p_exam_id
              AND monitoring_status = 'PAUSED';
            GET DIAGNOSTICS v_affected = ROW_COUNT;
        END IF;

    ELSIF v_action = 'extend_exam_deadline' THEN
        IF v_minutes < 1 OR v_minutes > 180 THEN
            RETURN jsonb_build_object('success', FALSE, 'status', 400, 'error', 'Extension minutes must be between 1 and 180');
        END IF;
        UPDATE public.exam_monitoring_sessions
        SET extended_minutes = COALESCE(extended_minutes, 0) + v_minutes,
            updated_by = p_actor_id
        WHERE exam_id = p_exam_id;

        UPDATE public.exam_sessions
        SET extra_minutes = COALESCE(extra_minutes, 0) + v_minutes,
            teacher_message = format('Exam extended by %s mins: %s', v_minutes, v_reason)
        WHERE exam_id = p_exam_id
          AND monitoring_status NOT IN ('SUBMITTED', 'AUTO_SUBMITTED', 'TERMINATED');
        GET DIAGNOSTICS v_affected = ROW_COUNT;

    ELSIF v_action = 'close_reentry' THEN
        UPDATE public.exam_monitoring_sessions SET reentry_window_open = FALSE, updated_by = p_actor_id WHERE exam_id = p_exam_id;

    ELSIF v_action = 'open_reentry' THEN
        UPDATE public.exam_monitoring_sessions SET reentry_window_open = TRUE, updated_by = p_actor_id WHERE exam_id = p_exam_id;

    ELSIF v_action = 'emergency_submit_all' THEN
        UPDATE public.exam_monitoring_sessions SET status = 'EMERGENCY_STOPPED', reentry_window_open = FALSE, updated_by = p_actor_id WHERE exam_id = p_exam_id;
        UPDATE public.exam_sessions
        SET status = 'completed',
            monitoring_status = 'AUTO_SUBMITTED',
            ended_at = NOW(),
            is_paused = FALSE,
            is_online = FALSE,
            teacher_message = v_reason
        WHERE exam_id = p_exam_id
          AND monitoring_status NOT IN ('SUBMITTED', 'AUTO_SUBMITTED', 'TERMINATED');
        GET DIAGNOSTICS v_affected = ROW_COUNT;

    ELSIF v_action = 'update_settings' THEN
        UPDATE public.exam_monitoring_sessions
        SET auto_flag_tab_switch_threshold = COALESCE((p_payload->>'auto_flag_tab_switch_threshold')::INT, auto_flag_tab_switch_threshold),
            auto_flag_fullscreen_threshold = COALESCE((p_payload->>'auto_flag_fullscreen_threshold')::INT, auto_flag_fullscreen_threshold),
            heartbeat_timeout_seconds = COALESCE((p_payload->>'heartbeat_timeout_seconds')::INT, heartbeat_timeout_seconds),
            default_max_reentry_attempts = COALESCE((p_payload->>'default_max_reentry_attempts')::INT, default_max_reentry_attempts),
            monitoring_settings = COALESCE(monitoring_settings, '{}'::jsonb) || COALESCE(p_payload->'monitoring_settings', '{}'::jsonb),
            updated_by = p_actor_id
        WHERE exam_id = p_exam_id;
    ELSE
        RETURN jsonb_build_object('success', FALSE, 'status', 400, 'error', format('Unsupported control action: %s', p_control_action));
    END IF;

    INSERT INTO public.invigilator_actions (
        school_id, exam_id, actor_id, actor_name, actor_role,
        action_type, scope, reason, payload
    ) VALUES (
        COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id, p_actor_id, p_actor_name, p_actor_role,
        v_action, 'exam', v_reason, COALESCE(p_payload, '{}'::jsonb) || jsonb_build_object('affected_count', v_affected)
    );

    INSERT INTO public.exam_activity_logs (
        school_id, exam_id, action, title, description, performed_by, performed_by_name, icon, color
    ) VALUES (
        COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id, v_action,
        'Exam Control: ' || INITCAP(REPLACE(v_action, '_', ' ')),
        format('%s executed %s (%s affected): %s', COALESCE(p_actor_name, 'Invigilator'), v_action, v_affected, v_reason),
        p_actor_id, p_actor_name,
        CASE WHEN v_action = 'emergency_submit_all' THEN 'emergency' ELSE 'settings' END,
        CASE WHEN v_action = 'emergency_submit_all' THEN 'red' ELSE 'blue' END
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'control_action', v_action,
        'affected_count', v_affected,
        'status', (SELECT status FROM public.exam_monitoring_sessions WHERE exam_id = p_exam_id)
    );
END;
$$;


-- 12. RPC: List & Filter Exam Incidents / Violation Reports
CREATE OR REPLACE FUNCTION public.rpc_get_exam_monitoring_incidents(
    p_school_id UUID,
    p_exam_id UUID,
    p_actor_id UUID,
    p_actor_role TEXT,
    p_severity TEXT DEFAULT NULL,
    p_violation_type TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_auth RECORD;
    v_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_page_size INT := LEAST(100, GREATEST(1, COALESCE(p_page_size, 20)));
    v_offset INT;
    v_total INT := 0;
    v_items JSONB := '[]'::jsonb;
    v_summary JSONB := '{}'::jsonb;
BEGIN
    SELECT * INTO v_auth FROM public._can_monitor_exam(p_school_id, p_exam_id, p_actor_id, p_actor_role);
    IF NOT v_auth.allowed THEN
        RETURN jsonb_build_object('success', FALSE, 'status', v_auth.http_status, 'error', v_auth.denial_reason);
    END IF;

    v_offset := (v_page - 1) * v_page_size;

    SELECT jsonb_build_object(
        'total', COUNT(*)::INT,
        'open', COUNT(*) FILTER (WHERE status = 'open')::INT,
        'acknowledged', COUNT(*) FILTER (WHERE status = 'acknowledged')::INT,
        'escalated', COUNT(*) FILTER (WHERE status = 'escalated')::INT,
        'resolved', COUNT(*) FILTER (WHERE status IN ('resolved', 'dismissed'))::INT,
        'critical', COUNT(*) FILTER (WHERE severity IN ('high', 'critical'))::INT
    ) INTO v_summary
    FROM public.exam_incidents
    WHERE exam_id = p_exam_id;

    WITH joined AS (
        SELECT
            ei.id,
            ei.exam_id,
            ei.session_id,
            ei.candidate_id,
            COALESCE(p.full_name, p.email, 'Candidate') AS candidate_name,
            COALESCE(p.roll_number::TEXT, '') AS roll_number,
            COALESCE(p.class, 'General') AS class_name,
            ei.violation_type,
            ei.severity,
            ei.title,
            ei.description,
            ei.detection_source,
            ei.status,
            ei.duration_seconds,
            ei.occurred_at,
            ei.metadata,
            ei.resolved_at,
            ei.resolution_note,
            rp.full_name AS resolved_by_name
        FROM public.exam_incidents ei
        LEFT JOIN public.profiles p ON p.id = ei.candidate_id
        LEFT JOIN public.profiles rp ON rp.id = ei.resolved_by
        WHERE ei.exam_id = p_exam_id
          AND (p_severity IS NULL OR BTRIM(p_severity) = '' OR LOWER(p_severity) = 'all' OR LOWER(ei.severity) = LOWER(p_severity))
          AND (p_violation_type IS NULL OR BTRIM(p_violation_type) = '' OR LOWER(p_violation_type) = 'all' OR LOWER(ei.violation_type) = LOWER(p_violation_type))
          AND (p_status IS NULL OR BTRIM(p_status) = '' OR LOWER(p_status) = 'all' OR LOWER(ei.status) = LOWER(p_status))
          AND (
              p_search IS NULL OR BTRIM(p_search) = ''
              OR LOWER(COALESCE(p.full_name, '')) LIKE '%' || LOWER(BTRIM(p_search)) || '%'
              OR LOWER(COALESCE(p.roll_number::TEXT, '')) LIKE '%' || LOWER(BTRIM(p_search)) || '%'
              OR LOWER(COALESCE(ei.title, '')) LIKE '%' || LOWER(BTRIM(p_search)) || '%'
          )
    ),
    counted AS (SELECT COUNT(*)::INT AS cnt FROM joined),
    paged AS (SELECT * FROM joined ORDER BY occurred_at DESC LIMIT v_page_size OFFSET v_offset)
    SELECT (SELECT cnt FROM counted), COALESCE(jsonb_agg(row_to_json(pg)), '[]'::jsonb)
    INTO v_total, v_items
    FROM paged pg;

    RETURN jsonb_build_object(
        'success', TRUE,
        'summary', COALESCE(v_summary, '{}'::jsonb),
        'incidents', v_items,
        'pagination', jsonb_build_object(
            'page', v_page,
            'page_size', v_page_size,
            'total', COALESCE(v_total, 0),
            'total_pages', GREATEST(1, CEIL(COALESCE(v_total, 0)::NUMERIC / v_page_size)::INT)
        )
    );
END;
$$;


-- 13. RPC: Resolve / Acknowledge / Escalate / Dismiss Incident
CREATE OR REPLACE FUNCTION public.rpc_resolve_exam_incident(
    p_school_id UUID,
    p_exam_id UUID,
    p_incident_id UUID,
    p_actor_id UUID,
    p_actor_name TEXT,
    p_actor_role TEXT,
    p_new_status TEXT,
    p_resolution_note TEXT DEFAULT NULL,
    p_assign_to UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_auth RECORD;
    v_status TEXT := LOWER(BTRIM(COALESCE(p_new_status, 'resolved')));
    v_inc RECORD;
BEGIN
    SELECT * INTO v_auth FROM public._can_monitor_exam(p_school_id, p_exam_id, p_actor_id, p_actor_role);
    IF NOT v_auth.allowed THEN
        RETURN jsonb_build_object('success', FALSE, 'status', v_auth.http_status, 'error', v_auth.denial_reason);
    END IF;

    IF v_status NOT IN ('open', 'acknowledged', 'resolved', 'dismissed', 'escalated') THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 400, 'error', 'Invalid incident status');
    END IF;

    UPDATE public.exam_incidents
    SET status = v_status,
        assigned_to = COALESCE(p_assign_to, assigned_to),
        resolved_by = CASE WHEN v_status IN ('resolved', 'dismissed') THEN p_actor_id ELSE resolved_by END,
        resolved_at = CASE WHEN v_status IN ('resolved', 'dismissed') THEN NOW() ELSE resolved_at END,
        resolution_note = COALESCE(NULLIF(BTRIM(p_resolution_note), ''), resolution_note),
        updated_at = NOW()
    WHERE id = p_incident_id AND exam_id = p_exam_id
    RETURNING * INTO v_inc;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 404, 'error', 'Incident not found');
    END IF;

    INSERT INTO public.invigilator_actions (
        school_id, exam_id, session_id, candidate_id, actor_id, actor_name, actor_role,
        action_type, scope, reason, payload
    ) VALUES (
        COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id, v_inc.session_id, v_inc.candidate_id,
        p_actor_id, p_actor_name, p_actor_role, 'incident_' || v_status, 'candidate',
        COALESCE(p_resolution_note, 'Incident status updated to ' || v_status),
        jsonb_build_object('incident_id', p_incident_id, 'new_status', v_status)
    );

    RETURN jsonb_build_object('success', TRUE, 'incident_id', v_inc.id, 'status', v_inc.status, 'resolved_at', v_inc.resolved_at);
END;
$$;


-- 14. RPC: Send Announcement to All or Subset of Candidates
CREATE OR REPLACE FUNCTION public.rpc_create_exam_announcement(
    p_school_id UUID,
    p_exam_id UUID,
    p_actor_id UUID,
    p_actor_name TEXT,
    p_actor_role TEXT,
    p_title TEXT,
    p_message TEXT,
    p_priority TEXT DEFAULT 'normal',
    p_target_scope TEXT DEFAULT 'all',
    p_target_candidate_ids JSONB DEFAULT '[]'::jsonb,
    p_requires_ack BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_auth RECORD;
    v_ann_id UUID;
    v_rec_ids UUID[] := ARRAY[]::UUID[];
    v_rec_count INT := 0;
    v_scope TEXT := LOWER(COALESCE(NULLIF(BTRIM(p_target_scope), ''), 'all'));
BEGIN
    SELECT * INTO v_auth FROM public._can_monitor_exam(p_school_id, p_exam_id, p_actor_id, p_actor_role);
    IF NOT v_auth.allowed THEN
        RETURN jsonb_build_object('success', FALSE, 'status', v_auth.http_status, 'error', v_auth.denial_reason);
    END IF;

    IF NULLIF(BTRIM(p_message), '') IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 400, 'error', 'Announcement message cannot be empty');
    END IF;

    INSERT INTO public.exam_announcements (
        school_id, exam_id, title, message, priority, target_scope,
        target_candidate_ids, requires_acknowledgement, sent_by, sent_by_name
    ) VALUES (
        COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id,
        COALESCE(NULLIF(BTRIM(p_title), ''), 'Examination Announcement'),
        BTRIM(p_message),
        LOWER(COALESCE(NULLIF(BTRIM(p_priority), ''), 'normal')),
        v_scope,
        COALESCE(p_target_candidate_ids, '[]'::jsonb),
        COALESCE(p_requires_ack, FALSE),
        p_actor_id,
        p_actor_name
    )
    RETURNING id INTO v_ann_id;

    WITH targets AS (
        SELECT DISTINCT r.candidate_id
        FROM public._resolve_exam_roster(COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id) r
        LEFT JOIN LATERAL (
            SELECT es.monitoring_status, es.warnings_count
            FROM public.exam_sessions es
            WHERE es.exam_id = p_exam_id AND es.student_id = r.candidate_id
            ORDER BY es.started_at DESC NULLS LAST LIMIT 1
        ) ls ON TRUE
        WHERE (v_scope = 'all')
           OR (v_scope = 'active' AND UPPER(COALESCE(ls.monitoring_status, '')) IN ('ACTIVE', 'WARNING', 'VIOLATION', 'PAUSED'))
           OR (v_scope = 'flagged' AND (COALESCE(ls.warnings_count, 0) > 0 OR UPPER(COALESCE(ls.monitoring_status, '')) IN ('WARNING', 'VIOLATION')))
           OR (v_scope = 'disconnected' AND UPPER(COALESCE(ls.monitoring_status, '')) = 'DISCONNECTED')
           OR (v_scope = 'selected' AND p_target_candidate_ids ? r.candidate_id::TEXT)
    )
    INSERT INTO public.exam_announcement_recipients (school_id, announcement_id, exam_id, candidate_id)
    SELECT COALESCE(v_auth.exam_school_id, p_school_id), v_ann_id, p_exam_id, candidate_id
    FROM targets
    ON CONFLICT (announcement_id, candidate_id) DO NOTHING;

    SELECT COALESCE(ARRAY_AGG(candidate_id), ARRAY[]::UUID[])
    INTO v_rec_ids
    FROM public.exam_announcement_recipients
    WHERE announcement_id = v_ann_id;
    v_rec_count := COALESCE(ARRAY_LENGTH(v_rec_ids, 1), 0);

    INSERT INTO public.invigilator_actions (
        school_id, exam_id, actor_id, actor_name, actor_role,
        action_type, scope, reason, payload
    ) VALUES (
        COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id, p_actor_id, p_actor_name, p_actor_role,
        'announcement', v_scope, BTRIM(p_message),
        jsonb_build_object('announcement_id', v_ann_id, 'recipient_count', v_rec_count, 'priority', p_priority)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'announcement_id', v_ann_id,
        'recipient_count', v_rec_count,
        'recipient_ids', to_jsonb(v_rec_ids)
    );
END;
$$;


-- 15. RPC: Candidate acknowledges an announcement
CREATE OR REPLACE FUNCTION public.rpc_acknowledge_exam_announcement(
    p_school_id UUID,
    p_exam_id UUID,
    p_announcement_id UUID,
    p_candidate_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.exam_announcement_recipients
    SET acknowledged_at = COALESCE(acknowledged_at, NOW())
    WHERE announcement_id = p_announcement_id
      AND exam_id = p_exam_id
      AND candidate_id = p_candidate_id
      AND (p_school_id IS NULL OR school_id = p_school_id);

    RETURN jsonb_build_object('success', TRUE, 'acknowledged_at', NOW());
END;
$$;


-- 16. RPC: Chronological Audit Log for Invigilation Panel
CREATE OR REPLACE FUNCTION public.rpc_get_exam_monitoring_audit_logs(
    p_school_id UUID,
    p_exam_id UUID,
    p_actor_id UUID,
    p_actor_role TEXT,
    p_action_type TEXT DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_auth RECORD;
    v_page INT := GREATEST(1, COALESCE(p_page, 1));
    v_page_size INT := LEAST(100, GREATEST(1, COALESCE(p_page_size, 30)));
    v_offset INT;
    v_total INT := 0;
    v_items JSONB := '[]'::jsonb;
BEGIN
    SELECT * INTO v_auth FROM public._can_monitor_exam(p_school_id, p_exam_id, p_actor_id, p_actor_role);
    IF NOT v_auth.allowed THEN
        RETURN jsonb_build_object('success', FALSE, 'status', v_auth.http_status, 'error', v_auth.denial_reason);
    END IF;

    v_offset := (v_page - 1) * v_page_size;

    WITH rows_cte AS (
        SELECT
            ia.id,
            ia.action_type,
            ia.scope,
            ia.reason,
            ia.actor_id,
            COALESCE(ia.actor_name, ap.full_name, 'Invigilator') AS actor_name,
            ia.actor_role,
            ia.candidate_id,
            COALESCE(cp.full_name, cp.email) AS candidate_name,
            COALESCE(cp.roll_number::TEXT, '') AS candidate_roll,
            ia.payload,
            ia.created_at
        FROM public.invigilator_actions ia
        LEFT JOIN public.profiles ap ON ap.id = ia.actor_id
        LEFT JOIN public.profiles cp ON cp.id = ia.candidate_id
        WHERE ia.exam_id = p_exam_id
          AND (p_action_type IS NULL OR BTRIM(p_action_type) = '' OR LOWER(p_action_type) = 'all' OR LOWER(ia.action_type) = LOWER(p_action_type))
    ),
    counted AS (SELECT COUNT(*)::INT AS cnt FROM rows_cte),
    paged AS (SELECT * FROM rows_cte ORDER BY created_at DESC LIMIT v_page_size OFFSET v_offset)
    SELECT (SELECT cnt FROM counted), COALESCE(jsonb_agg(row_to_json(pg)), '[]'::jsonb)
    INTO v_total, v_items
    FROM paged pg;

    RETURN jsonb_build_object(
        'success', TRUE,
        'logs', v_items,
        'pagination', jsonb_build_object(
            'page', v_page,
            'page_size', v_page_size,
            'total', COALESCE(v_total, 0),
            'total_pages', GREATEST(1, CEIL(COALESCE(v_total, 0)::NUMERIC / v_page_size)::INT)
        )
    );
END;
$$;


-- 17. RPC: Full Exportable Monitoring & Incident Report
CREATE OR REPLACE FUNCTION public.rpc_get_exam_monitoring_report(
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
    v_overview JSONB;
    v_candidates JSONB;
    v_incidents JSONB;
    v_logs JSONB;
BEGIN
    v_overview := public.rpc_get_exam_monitoring_overview(p_school_id, p_exam_id, p_actor_id, p_actor_role);
    IF COALESCE((v_overview->>'success')::BOOLEAN, FALSE) = FALSE THEN
        RETURN v_overview;
    END IF;

    v_candidates := public.rpc_get_exam_monitoring_candidates(p_school_id, p_exam_id, p_actor_id, p_actor_role, NULL, NULL, NULL, NULL, 1, 100, 'roll', 'asc');
    v_incidents := public.rpc_get_exam_monitoring_incidents(p_school_id, p_exam_id, p_actor_id, p_actor_role, NULL, NULL, NULL, NULL, 1, 100);
    v_logs := public.rpc_get_exam_monitoring_audit_logs(p_school_id, p_exam_id, p_actor_id, p_actor_role, NULL, 1, 100);

    RETURN jsonb_build_object(
        'success', TRUE,
        'generated_at', NOW(),
        'exam', v_overview->'exam',
        'kpis', v_overview->'kpis',
        'status_breakdown', v_overview->'status_breakdown',
        'candidates', COALESCE(v_candidates->'candidates', '[]'::jsonb),
        'incidents', COALESCE(v_incidents->'incidents', '[]'::jsonb),
        'audit_logs', COALESCE(v_logs->'logs', '[]'::jsonb)
    );
END;
$$;

