-- ============================================================================
-- Migration: 506_exam_management_full_features_and_fixes.sql
-- Description: 
--  1. Fix candidate_id vs student_id / user_id mismatch in rpc_execute_invigilator_action.
--  2. Fix participant matching in _resolve_exam_roster.
--  3. Support instant invigilator actions across both profiles.id and profiles.user_id.
-- ============================================================================

-- 1. ENHANCE _resolve_exam_roster to resolve both profile.id and profile.user_id
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
    JOIN public.profiles p ON (p.id = pid.uid OR p.user_id = pid.uid)
    WHERE p.school_id = COALESCE(v_exam.school_id, p_school_id)
    ORDER BY p.id;
END;
$$;

-- 2. HELPER: _calculate_candidate_remaining_seconds
CREATE OR REPLACE FUNCTION public._calculate_candidate_remaining_seconds(
    p_started_at TIMESTAMPTZ,
    p_duration_minutes INT,
    p_extra_minutes INT,
    p_paused_total_seconds INT,
    p_is_paused BOOLEAN,
    p_paused_at TIMESTAMPTZ,
    p_monitoring_status TEXT,
    p_exam_is_paused BOOLEAN DEFAULT FALSE,
    p_exam_paused_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_total_sec INT;
    v_elapsed_sec INT;
    v_effective_now TIMESTAMPTZ;
BEGIN
    IF UPPER(COALESCE(p_monitoring_status, '')) IN ('SUBMITTED', 'AUTO_SUBMITTED', 'TERMINATED') THEN
        RETURN 0;
    END IF;

    v_total_sec := (COALESCE(p_duration_minutes, 60) + COALESCE(p_extra_minutes, 0)) * 60;
    IF p_started_at IS NULL THEN
        RETURN v_total_sec;
    END IF;

    IF COALESCE(p_is_paused, FALSE) AND p_paused_at IS NOT NULL THEN
        v_effective_now := p_paused_at;
    ELSIF COALESCE(p_exam_is_paused, FALSE) AND p_exam_paused_at IS NOT NULL THEN
        v_effective_now := p_exam_paused_at;
    ELSE
        v_effective_now := CLOCK_TIMESTAMP();
    END IF;

    v_elapsed_sec := GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (v_effective_now - p_started_at)))::INT - COALESCE(p_paused_total_seconds, 0));
    RETURN GREATEST(0, v_total_sec - v_elapsed_sec);
END;
$$;

-- 3. RE-IMPLEMENT rpc_execute_invigilator_action WITH DUAL UUID LOOKUP & PRESTART FALLBACK
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
    v_session_id UUID;
    v_target_user_id UUID;
    v_profile_id UUID;
BEGIN
    SELECT * INTO v_auth FROM public._can_monitor_exam(p_school_id, p_exam_id, p_actor_id, p_actor_role);
    IF NOT v_auth.allowed THEN
        RETURN jsonb_build_object('success', FALSE, 'status', v_auth.http_status, 'error', v_auth.denial_reason);
    END IF;

    -- Canonicalize aliases
    IF v_action IN ('disable_cam', 'turn_off_cam') THEN
        v_action := 'force_disable_cam';
    ELSIF v_action IN ('turn_on_cam', 'enable_camera') THEN
        v_action := 'enable_cam';
    ELSIF v_action IN ('mute_mic', 'turn_off_mic') THEN
        v_action := 'force_mute_mic';
    ELSIF v_action IN ('turn_on_mic', 'enable_mic', 'unmute_microphone') THEN
        v_action := 'unmute_mic';
    END IF;

    IF v_action NOT IN (
        'warn', 'pause', 'resume', 'extend_time', 'give_chance',
        'approve_reentry', 'reject_reentry', 'terminate', 'force_submit',
        'request_camera', 'request_mic', 'request_screen_share',
        'force_mute_mic', 'unmute_mic', 'force_disable_cam', 'enable_cam',
        'escalate', 'reopen'
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
    LOOP
        -- Dual UUID Resolution: match candidate by either profiles.id OR auth user_id
        SELECT 
            p.id,
            CASE 
                WHEN p.user_id IS NOT NULL AND p.user_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' 
                THEN p.user_id::UUID 
                ELSE NULL 
            END
        INTO v_profile_id, v_target_user_id
        FROM public.profiles p
        WHERE p.id = v_cid OR p.user_id = v_cid::TEXT
        LIMIT 1;

        IF v_profile_id IS NULL THEN
            v_profile_id := v_cid;
        END IF;
        IF v_target_user_id IS NULL THEN
            v_target_user_id := v_cid;
        END IF;

        SELECT * INTO v_session
        FROM public.exam_sessions
        WHERE exam_id = p_exam_id
          AND (
              student_id = v_cid 
              OR student_id = v_profile_id
              OR (v_target_user_id IS NOT NULL AND student_id = v_target_user_id)
          )
        ORDER BY started_at DESC NULLS LAST, created_at DESC
        LIMIT 1
        FOR UPDATE;

        IF NOT FOUND THEN
            -- Auto-create / record action so the command reaches candidate even before first answer submission
            INSERT INTO public.invigilator_actions (
                school_id, exam_id, candidate_id,
                actor_id, actor_name, actor_role, action_type, scope, reason, payload, idempotency_key
            ) VALUES (
                COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id, v_profile_id,
                p_actor_id, p_actor_name, p_actor_role, v_action, v_scope, v_reason,
                COALESCE(p_payload, '{}'::jsonb),
                CASE WHEN v_scope = 'candidate' THEN v_idem_key ELSE NULL END
            );

            v_results := v_results || jsonb_build_object(
                'candidate_id', v_cid,
                'student_id', v_target_user_id,
                'profile_id', v_profile_id,
                'monitoring_status', 'NOT_STARTED',
                'is_paused', (v_action = 'pause'),
                'warnings_count', CASE WHEN v_action = 'warn' THEN 1 ELSE 0 END,
                'extra_minutes', CASE WHEN v_action = 'extend_time' THEN v_minutes ELSE 0 END,
                'camera_active', (v_action = 'enable_cam'),
                'mic_active', (v_action = 'unmute_mic'),
                'teacher_message', v_reason
            );
            v_affected := v_affected + 1;
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
            UPDATE public.exam_sessions
            SET warnings_count = COALESCE(warnings_count, 0) + 1,
                monitoring_status = CASE WHEN monitoring_status IN ('SUBMITTED', 'AUTO_SUBMITTED', 'TERMINATED') THEN monitoring_status ELSE 'WARNING' END,
                teacher_message = v_reason,
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

            INSERT INTO public.exam_incidents (
                school_id, exam_id, session_id, candidate_id,
                violation_type, severity, title, description,
                detection_source, status
            ) VALUES (
                COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id, v_session.id, v_profile_id,
                'proctor_warning', 'high', 'Official Invigilator Warning', v_reason,
                'invigilator', 'warned'
            );

        ELSIF v_action = 'pause' THEN
            IF COALESCE(v_session.is_paused, FALSE) = FALSE THEN
                UPDATE public.exam_sessions
                SET is_paused = TRUE,
                    paused_at = NOW(),
                    paused_reason = v_reason,
                    timer_pause_policy = v_pause_policy,
                    monitoring_status = CASE WHEN monitoring_status IN ('SUBMITTED', 'AUTO_SUBMITTED', 'TERMINATED') THEN monitoring_status ELSE 'PAUSED' END,
                    teacher_message = v_reason,
                    updated_at = NOW()
                WHERE id = v_session.id
                RETURNING * INTO v_session;
            END IF;

        ELSIF v_action = 'resume' THEN
            IF COALESCE(v_session.is_paused, FALSE) = TRUE THEN
                IF v_session.paused_at IS NOT NULL AND v_session.timer_pause_policy = 'freeze' THEN
                    v_paused_delta := GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (NOW() - v_session.paused_at)))::INT);
                ELSE
                    v_paused_delta := 0;
                END IF;

                UPDATE public.exam_sessions
                SET is_paused = FALSE,
                    paused_total_seconds = COALESCE(paused_total_seconds, 0) + v_paused_delta,
                    paused_at = NULL,
                    paused_reason = NULL,
                    monitoring_status = CASE
                        WHEN COALESCE(warnings_count, 0) > 0 THEN 'WARNING'
                        ELSE 'ACTIVE'
                    END,
                    teacher_message = 'Session resumed by invigilator',
                    updated_at = NOW()
                WHERE id = v_session.id
                RETURNING * INTO v_session;
            END IF;

        ELSIF v_action = 'extend_time' THEN
            IF COALESCE(v_session.extra_minutes, 0) + v_minutes > 180 THEN
                v_errors := v_errors || jsonb_build_object(
                    'candidate_id', v_cid,
                    'error', 'Cumulative extra time cannot exceed 180 minutes'
                );
                CONTINUE;
            END IF;

            UPDATE public.exam_sessions
            SET extra_minutes = COALESCE(extra_minutes, 0) + v_minutes,
                teacher_message = format('+%s min extra time granted', v_minutes),
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

            INSERT INTO public.candidate_time_adjustments (
                school_id, exam_id, session_id, candidate_id,
                minutes_added, reason, granted_by, granted_by_name
            ) VALUES (
                COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id, v_session.id, v_profile_id,
                v_minutes, v_reason, p_actor_id, p_actor_name
            );

        ELSIF v_action = 'give_chance' THEN
            UPDATE public.exam_sessions
            SET warnings_count = GREATEST(0, COALESCE(warnings_count, 0) - 1),
                monitoring_status = CASE
                    WHEN GREATEST(0, COALESCE(warnings_count, 0) - 1) > 0 THEN 'WARNING'
                    ELSE 'ACTIVE'
                END,
                teacher_message = 'Extra chance granted by invigilator',
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

        ELSIF v_action = 'approve_reentry' THEN
            UPDATE public.exam_sessions
            SET monitoring_status = 'ACTIVE',
                is_online = TRUE,
                last_ping = NOW(),
                reentry_count = COALESCE(reentry_count, 0) + 1,
                teacher_message = 'Re-entry approved by invigilator',
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

            UPDATE public.candidate_reentry_requests
            SET status = 'approved',
                reviewed_by = p_actor_id,
                reviewed_at = NOW(),
                review_note = v_reason
            WHERE exam_id = p_exam_id AND (candidate_id = v_profile_id OR candidate_id = v_cid) AND status = 'pending';

        ELSIF v_action = 'reject_reentry' THEN
            UPDATE public.candidate_reentry_requests
            SET status = 'rejected',
                reviewed_by = p_actor_id,
                reviewed_at = NOW(),
                review_note = v_reason
            WHERE exam_id = p_exam_id AND (candidate_id = v_profile_id OR candidate_id = v_cid) AND status = 'pending';

            UPDATE public.exam_sessions
            SET teacher_message = 'Re-entry declined by invigilator',
                monitoring_status = 'TERMINATED',
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

        ELSIF v_action = 'terminate' THEN
            UPDATE public.exam_sessions
            SET status = 'terminated',
                monitoring_status = 'TERMINATED',
                ended_at = NOW(),
                terminated_at = NOW(),
                terminated_reason = v_reason,
                is_online = FALSE,
                camera_active = FALSE,
                mic_active = FALSE,
                screen_share_active = FALSE,
                livekit_connected = FALSE,
                camera_permission_state = 'STOPPED',
                mic_permission_state = 'STOPPED',
                screen_share_state = 'NOT_SHARED',
                teacher_message = 'Exam terminated by invigilator: ' || v_reason,
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

        ELSIF v_action = 'force_submit' THEN
            UPDATE public.exam_sessions
            SET status = 'completed',
                monitoring_status = 'SUBMITTED',
                ended_at = NOW(),
                is_online = FALSE,
                teacher_message = 'Exam submitted by invigilator',
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

            UPDATE public.exam_submissions
            SET status = 'submitted',
                submitted_at = NOW(),
                submission_type = 'proctor_forced'
            WHERE exam_id = p_exam_id AND student_id = v_session.student_id;

        ELSIF v_action = 'force_mute_mic' THEN
            UPDATE public.exam_sessions
            SET mic_active = FALSE,
                mic_permission_state = 'STOPPED',
                teacher_message = COALESCE(NULLIF(v_reason, 'Invigilator action'), 'Microphone muted by invigilator'),
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

        ELSIF v_action = 'unmute_mic' THEN
            UPDATE public.exam_sessions
            SET mic_active = TRUE,
                mic_permission_state = 'GRANTED',
                teacher_message = COALESCE(NULLIF(v_reason, 'Invigilator action'), 'Microphone enabled by invigilator'),
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

        ELSIF v_action = 'force_disable_cam' THEN
            UPDATE public.exam_sessions
            SET camera_active = FALSE,
                camera_permission_state = 'STOPPED',
                teacher_message = COALESCE(NULLIF(v_reason, 'Invigilator action'), 'Camera disabled by invigilator'),
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

        ELSIF v_action = 'enable_cam' THEN
            UPDATE public.exam_sessions
            SET camera_active = TRUE,
                camera_permission_state = 'GRANTED',
                teacher_message = COALESCE(NULLIF(v_reason, 'Invigilator action'), 'Camera enabled by invigilator'),
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
                COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id, v_session.id, v_profile_id,
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
                warnings_count = 0,
                is_paused = FALSE,
                teacher_message = 'Exam session reopened by invigilator. You may resume.',
                updated_at = NOW()
            WHERE id = v_session.id
            RETURNING * INTO v_session;

            UPDATE public.exam_submissions
            SET status = 'in_progress',
                submitted_at = NULL
            WHERE exam_id = p_exam_id AND student_id = v_session.student_id;
        END IF;

        v_rem_sec := public._calculate_candidate_remaining_seconds(
            v_session.started_at, v_exam_duration, v_session.extra_minutes,
            v_session.paused_total_seconds, v_session.is_paused, v_session.paused_at,
            v_session.monitoring_status,
            COALESCE(v_mon.status = 'PAUSED', FALSE), v_mon.paused_at
        );

        INSERT INTO public.invigilator_actions (
            school_id, exam_id, session_id, candidate_id,
            actor_id, actor_name, actor_role, action_type, scope, reason, payload, idempotency_key
        ) VALUES (
            COALESCE(v_auth.exam_school_id, p_school_id), p_exam_id, v_session.id, v_profile_id,
            p_actor_id, p_actor_name, p_actor_role, v_action, v_scope, v_reason,
            COALESCE(p_payload, '{}'::jsonb) || jsonb_build_object('monitoring_status', v_session.monitoring_status, 'remaining_seconds', v_rem_sec),
            CASE WHEN v_scope = 'candidate' THEN v_idem_key ELSE NULL END
        );

        v_results := v_results || jsonb_build_object(
            'candidate_id', v_cid,
            'student_id', COALESCE(v_target_user_id, v_session.student_id),
            'session_student_id', v_session.student_id,
            'profile_id', v_profile_id,
            'session_id', v_session.id,
            'monitoring_status', v_session.monitoring_status,
            'is_paused', COALESCE(v_session.is_paused, FALSE),
            'warnings_count', COALESCE(v_session.warnings_count, 0),
            'extra_minutes', COALESCE(v_session.extra_minutes, 0),
            'remaining_seconds', v_rem_sec,
            'camera_active', COALESCE(v_session.camera_active, FALSE),
            'camera_permission_state', v_session.camera_permission_state,
            'mic_active', COALESCE(v_session.mic_active, FALSE),
            'mic_permission_state', v_session.mic_permission_state,
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

GRANT EXECUTE ON FUNCTION public._resolve_exam_roster(UUID, UUID) TO anon, authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION public.rpc_execute_invigilator_action(UUID, UUID, UUID, TEXT, TEXT, TEXT, JSONB, JSONB) TO anon, authenticated, service_role, postgres;
NOTIFY pgrst, 'reload schema';
