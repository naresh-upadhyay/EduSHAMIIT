-- ============================================================================
-- Migration: 441_enrich_exam_take_info_rpc.sql
-- Description: Enrich rpc_get_exam_take_info with resolved readiness policy,
--              camera_required, mic_required, screen_share_required, exam_type,
--              exam_mode, and normalized prestart_config so that Take Exam screen
--              properly connects to LiveKit proctoring and streams candidate camera.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_exam_take_info(
    p_exam_id UUID,
    p_user_id UUID,
    p_school_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_exam RECORD;
    v_exam_school_id UUID;
    v_subject_name TEXT;
    v_profile RECORD;
    v_target_classes JSONB;
    v_target_scope TEXT;

    v_sections JSONB;
    v_questions JSONB;
    v_total_q INT := 0;

    v_session RECORD;
    v_session_info JSONB := NULL;
    v_expires_at TIMESTAMPTZ;
    v_remaining_secs INT := 0;

    v_submission RECORD;
    v_saved_answers JSONB := '{}'::jsonb;
    v_is_submitted BOOLEAN := FALSE;
    v_submission_info JSONB := NULL;

    v_custom_inst TEXT;

    -- Enriched readiness & proctoring resolution
    v_raw_cfg JSONB;
    v_camera_mode TEXT;
    v_mic_mode TEXT;
    v_screen_mode TEXT;
    v_device_mode TEXT;
    v_readiness_policy JSONB;
    v_merged_prestart_cfg JSONB;
BEGIN
    SELECT e.*, s.name AS subj_name
    INTO v_exam
    FROM public.exams e
    LEFT JOIN public.subjects s ON e.subject_id = s.id
    WHERE e.id = p_exam_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 404, 'error', 'Examination not found');
    END IF;

    v_exam_school_id := COALESCE(v_exam.school_id, p_school_id);
    v_subject_name := COALESCE(NULLIF(BTRIM(v_exam.subj_name), ''), 'General');

    SELECT id, full_name, email, role, avatar_url, class AS prof_class, roll_number AS prof_roll
    INTO v_profile
    FROM public.profiles
    WHERE id = p_user_id;

    v_target_classes := CASE
        WHEN v_exam.target_classes IS NOT NULL AND jsonb_typeof(v_exam.target_classes) = 'array'
            THEN v_exam.target_classes
        ELSE '["General"]'::jsonb
    END;

    SELECT STRING_AGG(val, ', ') INTO v_target_scope
    FROM jsonb_array_elements_text(v_target_classes) AS t(val);
    v_target_scope := COALESCE(NULLIF(v_target_scope, ''), 'General');

    -- Resolve readiness policy and proctoring modes cleanly
    v_raw_cfg := COALESCE(v_exam.prestart_config, '{}'::jsonb);
    IF jsonb_typeof(v_raw_cfg) <> 'object' THEN
        v_raw_cfg := '{}'::jsonb;
    END IF;

    v_camera_mode := public._normalize_prestart_mode(
        CASE
            WHEN v_raw_cfg ? 'camera_mode' THEN v_raw_cfg->>'camera_mode'
            WHEN v_exam.camera_required IS NOT NULL THEN v_exam.camera_required::TEXT
            WHEN LOWER(COALESCE(v_exam.exam_type, '')) = 'online' THEN 'REQUIRED'
            WHEN LOWER(COALESCE(v_exam.exam_mode, '')) LIKE '%online%' THEN 'REQUIRED'
            ELSE 'REQUIRED'
        END,
        'REQUIRED'
    );

    v_mic_mode := public._normalize_prestart_mode(
        CASE
            WHEN v_raw_cfg ? 'microphone_mode' THEN v_raw_cfg->>'microphone_mode'
            WHEN v_raw_cfg ? 'mic_mode' THEN v_raw_cfg->>'mic_mode'
            WHEN v_exam.mic_required IS NOT NULL THEN v_exam.mic_required::TEXT
            WHEN LOWER(COALESCE(v_exam.exam_type, '')) = 'online' THEN 'REQUIRED'
            WHEN LOWER(COALESCE(v_exam.exam_mode, '')) LIKE '%online%' THEN 'REQUIRED'
            ELSE 'REQUIRED'
        END,
        'REQUIRED'
    );

    v_screen_mode := public._normalize_prestart_mode(
        COALESCE(
            v_raw_cfg->>'screen_share_mode',
            v_raw_cfg->>'screen_mode',
            CASE WHEN LOWER(COALESCE(v_exam.exam_mode, v_exam.exam_type, '')) IN ('online', 'online / proctored') THEN 'OPTIONAL'
            ELSE 'OPTIONAL' END
        ),
        'OPTIONAL'
    );

    v_device_mode := public._normalize_prestart_mode(
        COALESCE(v_raw_cfg->>'device_check_mode', 'REQUIRED'),
        'REQUIRED'
    );

    v_readiness_policy := jsonb_build_object(
        'camera_mode', v_camera_mode,
        'microphone_mode', v_mic_mode,
        'mic_mode', v_mic_mode,
        'screen_share_mode', v_screen_mode,
        'screen_mode', v_screen_mode,
        'device_check_mode', v_device_mode,
        'camera_required', (v_camera_mode = 'REQUIRED'),
        'microphone_required', (v_mic_mode = 'REQUIRED'),
        'mic_required', (v_mic_mode = 'REQUIRED'),
        'screen_sharing_required', (v_screen_mode = 'REQUIRED'),
        'screen_share_required', (v_screen_mode = 'REQUIRED'),
        'browser_check_required', (v_device_mode = 'REQUIRED'),
        'internet_check_required', (v_device_mode = 'REQUIRED'),
        'fullscreen_required', COALESCE((v_raw_cfg->>'fullscreen_required')::BOOLEAN, TRUE),
        'max_tab_switches', COALESCE((v_raw_cfg->>'max_tab_switches')::INT, 3),
        'instruction_acknowledgment_required', COALESCE((v_raw_cfg->>'acknowledgment_required')::BOOLEAN, TRUE)
    );

    v_merged_prestart_cfg := v_raw_cfg || v_readiness_policy;

    -- Sanitized questions (strictly excluding correct_answer and explanation)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', q.id,
            'section_id', q.section_id,
            'section_name', q.section_name,
            'order_number', q.order_number,
            'question_type', COALESCE(q.question_type, 'mcq'),
            'question_text', COALESCE(q.question_text, ''),
            'options', COALESCE(q.options, '[]'::jsonb),
            'marks', COALESCE(q.marks, 1),
            'negative_marks', COALESCE(q.negative_marks, 0.0),
            'difficulty', COALESCE(q.difficulty, 'Medium'),
            'chapter', COALESCE(q.chapter, ''),
            'snapshot_data', q.snapshot_data
        ) ORDER BY q.order_number ASC, q.created_at ASC
    ), '[]'::jsonb)
    INTO v_questions
    FROM public.exam_questions q
    WHERE q.exam_id = p_exam_id;

    v_total_q := jsonb_array_length(v_questions);

    -- Sections enriched with question counts
    SELECT COALESCE(jsonb_agg(
        to_jsonb(sec) || jsonb_build_object(
            'question_count', (
                SELECT COUNT(*)::INT FROM public.exam_questions q WHERE q.exam_id = p_exam_id AND q.section_id = sec.id
            )
        ) ORDER BY sec.sequence_number ASC
    ), '[]'::jsonb)
    INTO v_sections
    FROM public.exam_sections sec
    WHERE sec.exam_id = p_exam_id;

    IF jsonb_array_length(v_sections) = 0 AND v_total_q > 0 THEN
        v_sections := jsonb_build_array(
            jsonb_build_object(
                'id', 'sec-default',
                'name', 'Section A — General',
                'section_code', 'A',
                'sequence_number', 1,
                'instructions', 'Answer all questions in this section.',
                'total_questions', v_total_q
            )
        );
    END IF;

    -- Latest session state
    SELECT * INTO v_session
    FROM public.exam_sessions
    WHERE exam_id = p_exam_id AND student_id = p_user_id
    ORDER BY started_at DESC NULLS LAST, created_at DESC
    LIMIT 1;

    IF FOUND THEN
        v_expires_at := v_session.started_at + ((COALESCE(v_exam.duration_minutes, 90) + COALESCE(v_session.extra_minutes, 0)) || ' minutes')::INTERVAL;
        v_remaining_secs := GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (v_expires_at - NOW())))::INT);

        v_session_info := jsonb_build_object(
            'id', v_session.id,
            'status', COALESCE(v_session.status, 'in_progress'),
            'monitoring_status', COALESCE(v_session.monitoring_status, 'IN_EXAM'),
            'started_at', v_session.started_at,
            'expires_at', v_expires_at,
            'remaining_seconds', v_remaining_secs,
            'is_paused', COALESCE(v_session.is_paused, FALSE),
            'warnings_count', COALESCE(v_session.warnings_count, 0),
            'active_question', v_session.active_question,
            'camera_active', COALESCE(v_session.camera_active, FALSE),
            'camera_permission_state', v_session.camera_permission_state,
            'mic_active', COALESCE(v_session.mic_active, FALSE),
            'mic_permission_state', v_session.mic_permission_state,
            'screen_share_active', COALESCE(v_session.screen_share_active, FALSE),
            'screen_share_state', v_session.screen_share_state,
            'livekit_connected', COALESCE(v_session.livekit_connected, FALSE)
        );
    END IF;

    -- Submission state
    SELECT * INTO v_submission
    FROM public.exam_submissions
    WHERE exam_id = p_exam_id AND student_id = p_user_id
    LIMIT 1;

    IF FOUND THEN
        v_saved_answers := COALESCE(v_submission.answers, '{}'::jsonb);
        v_is_submitted := COALESCE(v_submission.status, '') IN ('submitted', 'graded', 'evaluated', 'auto_submitted');
        v_submission_info := jsonb_build_object(
            'id', v_submission.id,
            'score', v_submission.score,
            'status', v_submission.status,
            'submitted_at', v_submission.submitted_at
        );
    END IF;

    -- Custom instructions text
    SELECT STRING_AGG((row_num::TEXT || '. ' || COALESCE(description, '')), E'\n' ORDER BY row_num)
    INTO v_custom_inst
    FROM (
        SELECT description, ROW_NUMBER() OVER (ORDER BY display_order ASC, created_at ASC) AS row_num
        FROM public.exam_instructions
        WHERE exam_id = p_exam_id AND is_active = TRUE
    ) sub;

    RETURN jsonb_build_object(
        'success', TRUE,
        'school_id', v_exam_school_id,
        'data', jsonb_build_object(
            'exam', jsonb_build_object(
                'id', v_exam.id,
                'title', COALESCE(v_exam.title, 'Online Examination'),
                'subject', v_subject_name,
                'exam_type', COALESCE(v_exam.exam_type, 'online'),
                'exam_mode', COALESCE(v_exam.exam_mode, 'online'),
                'camera_required', (v_camera_mode <> 'DISABLED'),
                'mic_required', (v_mic_mode <> 'DISABLED'),
                'screen_share_required', (v_screen_mode = 'REQUIRED'),
                'duration_minutes', COALESCE(v_exam.duration_minutes, 90),
                'total_marks', COALESCE(v_exam.total_marks, 100),
                'passing_marks', COALESCE(v_exam.passing_marks, 33),
                'negative_marking', COALESCE(v_exam.negative_marking, FALSE),
                'shuffle_questions', COALESCE(v_exam.shuffle_questions, FALSE),
                'instructions', COALESCE(
                    NULLIF(v_custom_inst, ''),
                    NULLIF(v_exam.instructions, ''),
                    E'1. All questions are compulsory.\n2. Do not switch tabs or exit fullscreen.\n3. Your answers are automatically saved periodically.'
                ),
                'prestart_config', v_merged_prestart_cfg,
                'readiness_policy', v_readiness_policy,
                'target_classes', v_target_classes,
                'has_passcode', (NULLIF(BTRIM(v_exam.passcode), '') IS NOT NULL),
                'status', COALESCE(v_exam.status, 'scheduled')
            ),
            'candidate', jsonb_build_object(
                'id', COALESCE(v_profile.id, p_user_id),
                'name', COALESCE(NULLIF(v_profile.full_name, ''), NULLIF(v_profile.email, ''), 'Candidate'),
                'email', v_profile.email,
                'role', COALESCE(v_profile.role, 'student'),
                'avatar_url', v_profile.avatar_url,
                'class_name', COALESCE(NULLIF(v_profile.prof_class, ''), v_target_scope),
                'section_name', NULL,
                'roll_number', COALESCE(v_profile.prof_roll::TEXT, '-')
            ),
            'sections', v_sections,
            'questions', v_questions,
            'total_questions', v_total_q,
            'session', v_session_info,
            'saved_answers', v_saved_answers,
            'is_submitted', v_is_submitted,
            'submission', v_submission_info,
            'server_time', NOW()
        )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_get_exam_take_info(UUID, UUID, UUID) TO anon, authenticated, service_role, postgres;
NOTIFY pgrst, 'reload schema';
