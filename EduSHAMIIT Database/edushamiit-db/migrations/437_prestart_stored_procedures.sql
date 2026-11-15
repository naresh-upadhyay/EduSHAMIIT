-- ============================================================================
-- Migration: 437_prestart_stored_procedures.sql
-- Description: PostgreSQL Stored Procedures (RPC Functions) for Examination
--   Pre-Start Readiness, Setter Customization, Categorized Instructions CRUD,
--   and Take Exam Initialization — replacing inline multi-query FastAPI logic.
-- ============================================================================

-- 1. Helper: Normalize tri-state permission mode ('REQUIRED', 'OPTIONAL', 'DISABLED')
CREATE OR REPLACE FUNCTION public._normalize_prestart_mode(
    p_val TEXT,
    p_default TEXT DEFAULT 'REQUIRED'
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_norm TEXT;
BEGIN
    IF p_val IS NULL THEN
        RETURN p_default;
    END IF;
    v_norm := UPPER(BTRIM(p_val));
    IF v_norm IN ('REQUIRED', 'MANDATORY', 'YES', 'TRUE', '1') THEN
        RETURN 'REQUIRED';
    ELSIF v_norm IN ('OPTIONAL', 'RECOMMENDED') THEN
        RETURN 'OPTIONAL';
    ELSIF v_norm IN ('DISABLED', 'NONE', 'OFF', 'NO_NEED', 'NOT_REQUIRED', 'FALSE', '0') THEN
        RETURN 'DISABLED';
    END IF;
    RETURN p_default;
END;
$$;


-- 2. Helper: Determine whether caller is authorized as Exam Setter / Admin to customize an exam
CREATE OR REPLACE FUNCTION public._can_customize_exam_prestart(
    p_role TEXT,
    p_user_id UUID,
    p_created_by UUID,
    p_teacher_id UUID,
    p_target_students JSONB,
    p_exam_purpose TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_role TEXT := LOWER(BTRIM(COALESCE(p_role, '')));
    v_purpose TEXT := LOWER(COALESCE(p_exam_purpose, ''));
BEGIN
    IF v_role IN ('super_admin', 'admin', 'principal', 'exam_controller', 'coordinator', 'hod') THEN
        RETURN TRUE;
    END IF;

    IF v_role IN ('teacher', 'staff', 'faculty') THEN
        IF (p_created_by IS NOT NULL AND p_created_by = p_user_id)
           OR (p_teacher_id IS NOT NULL AND p_teacher_id = p_user_id) THEN
            RETURN TRUE;
        END IF;

        IF p_target_students IS NOT NULL
           AND jsonb_typeof(p_target_students) = 'array'
           AND EXISTS (
               SELECT 1 FROM jsonb_array_elements_text(p_target_students) elem
               WHERE elem = p_user_id::TEXT
           ) THEN
            RETURN FALSE;
        END IF;

        IF v_purpose LIKE '%onboarding%' OR v_purpose LIKE '%staff%' OR v_purpose LIKE '%teacher%' THEN
            RETURN FALSE;
        END IF;

        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;


-- 3. Helper: Built-in default warnings JSONB array
CREATE OR REPLACE FUNCTION public._default_prestart_warnings()
RETURNS JSONB
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT jsonb_build_array(
        'Do not switch tabs, open other applications or use external devices.',
        'Your screen, camera and microphone will be monitored throughout the exam according to exam policy.',
        'Any suspicious activity (e.g., tab switch, multiple screens, no face detected) may be flagged and reported to your teacher.',
        'Ensure you are in a quiet, well-lit environment and your face is clearly visible.',
        'Violation of exam rules may lead to cancellation of your exam.'
    );
$$;


-- 4. RPC: Get complete Exam Pre-Start Metadata, Dynamic Policy, Instructions & Session State
CREATE OR REPLACE FUNCTION public.rpc_get_exam_prestart_info(
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
    v_subject_name TEXT;
    v_profile RECORD;
    v_exam_school_id UUID;
    v_can_customize BOOLEAN := FALSE;

    v_target_classes JSONB;
    v_target_scope TEXT;

    v_total_q INT := 0;
    v_calc_marks INT := 0;

    v_raw_cfg JSONB;
    v_camera_mode TEXT;
    v_mic_mode TEXT;
    v_screen_mode TEXT;
    v_device_mode TEXT;
    v_fullscreen_req BOOLEAN := TRUE;
    v_max_tab_switches INT := 3;
    v_ack_req BOOLEAN := TRUE;
    v_readiness_policy JSONB;

    v_has_custom_inst BOOLEAN := FALSE;
    v_instructions JSONB;
    v_cat TEXT;
    v_cat_arr JSONB;
    v_default_inst JSONB;
    v_plain_lines JSONB;

    v_warnings JSONB;
    v_prestart_session JSONB;
    v_is_submitted BOOLEAN := FALSE;

    v_start_time_disp TEXT;
    v_end_time_disp TEXT;
    v_exam_date_disp TEXT;
    v_computed_end TIMESTAMPTZ;
BEGIN
    -- 1. Fetch exam & subject
    SELECT e.*, s.name AS subj_name
    INTO v_exam
    FROM public.exams e
    LEFT JOIN public.subjects s ON e.subject_id = s.id
    WHERE e.id = p_exam_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'status', 404,
            'error', 'Examination not found'
        );
    END IF;

    v_exam_school_id := COALESCE(v_exam.school_id, p_school_id);
    v_subject_name := COALESCE(NULLIF(BTRIM(v_exam.subj_name), ''), 'General');

    -- 2. Fetch caller profile
    SELECT id, full_name, email, role, avatar_url, class AS prof_class, roll_number AS prof_roll
    INTO v_profile
    FROM public.profiles
    WHERE id = p_user_id;

    v_can_customize := public._can_customize_exam_prestart(
        COALESCE(v_profile.role, 'student'),
        p_user_id,
        v_exam.created_by,
        v_exam.teacher_id,
        v_exam.target_students,
        v_exam.exam_purpose
    );

    -- Parse target classes cleanly
    v_target_classes := CASE
        WHEN v_exam.target_classes IS NOT NULL AND jsonb_typeof(v_exam.target_classes) = 'array'
            THEN v_exam.target_classes
        ELSE '[]'::jsonb
    END;

    SELECT STRING_AGG(val, ', ') INTO v_target_scope
    FROM jsonb_array_elements_text(v_target_classes) AS t(val);
    v_target_scope := COALESCE(NULLIF(v_target_scope, ''), NULLIF(v_exam.scope, ''), 'All Candidates');

    -- 3. Question counts & calculated marks
    SELECT COUNT(*)::INT, COALESCE(SUM(COALESCE(marks, 1)), 0)::INT
    INTO v_total_q, v_calc_marks
    FROM public.exam_questions
    WHERE exam_id = p_exam_id;

    IF v_total_q = 0 AND COALESCE(v_exam.total_questions_count, 0) > 0 THEN
        v_total_q := v_exam.total_questions_count;
    END IF;

    -- 4. Readiness policy (tri-state config overriding/enhancing legacy booleans)
    v_raw_cfg := COALESCE(v_exam.prestart_config, '{}'::jsonb);
    IF jsonb_typeof(v_raw_cfg) <> 'object' THEN
        v_raw_cfg := '{}'::jsonb;
    END IF;

    v_camera_mode := public._normalize_prestart_mode(
        CASE WHEN v_raw_cfg ? 'camera_mode' THEN v_raw_cfg->>'camera_mode'
             ELSE COALESCE(v_exam.camera_required::TEXT, 'true') END,
        'REQUIRED'
    );
    v_mic_mode := public._normalize_prestart_mode(
        CASE WHEN v_raw_cfg ? 'microphone_mode' THEN v_raw_cfg->>'microphone_mode'
             ELSE COALESCE(v_exam.mic_required::TEXT, 'true') END,
        'REQUIRED'
    );
    v_screen_mode := public._normalize_prestart_mode(
        COALESCE(
            v_raw_cfg->>'screen_share_mode',
            CASE WHEN LOWER(COALESCE(v_exam.exam_mode, '')) IN ('online', 'online / proctored')
                 THEN 'REQUIRED' ELSE 'OPTIONAL' END
        ),
        'OPTIONAL'
    );
    v_device_mode := public._normalize_prestart_mode(
        COALESCE(v_raw_cfg->>'device_check_mode', 'REQUIRED'),
        'REQUIRED'
    );
    v_fullscreen_req := COALESCE((v_raw_cfg->>'fullscreen_required')::BOOLEAN, TRUE);
    v_max_tab_switches := COALESCE((v_raw_cfg->>'max_tab_switches')::INT, 3);
    v_ack_req := COALESCE((v_raw_cfg->>'acknowledgment_required')::BOOLEAN, TRUE);

    v_readiness_policy := jsonb_build_object(
        'camera_mode', v_camera_mode,
        'microphone_mode', v_mic_mode,
        'screen_share_mode', v_screen_mode,
        'device_check_mode', v_device_mode,
        'camera_required', (v_camera_mode = 'REQUIRED'),
        'microphone_required', (v_mic_mode = 'REQUIRED'),
        'screen_sharing_required', (v_screen_mode = 'REQUIRED'),
        'browser_check_required', (v_device_mode = 'REQUIRED'),
        'internet_check_required', (v_device_mode = 'REQUIRED'),
        'fullscreen_required', v_fullscreen_req,
        'max_tab_switches', v_max_tab_switches,
        'instruction_acknowledgment_required', v_ack_req
    );

    -- 5. Categorized instructions (exam-specific -> school defaults -> built-in fallback)
    SELECT EXISTS (
        SELECT 1 FROM public.exam_instructions
        WHERE exam_id = p_exam_id AND is_active = TRUE
    ) INTO v_has_custom_inst;

    v_default_inst := jsonb_build_object(
        'general', jsonb_build_array(
            jsonb_build_object('order', 1, 'title', 'Read carefully', 'description', 'Read all questions carefully before answering.'),
            jsonb_build_object('order', 2, 'title', 'Question format', 'description', 'The exam consists of Multiple Choice, Multiple Select, Short Answer and Long Answer questions.'),
            jsonb_build_object('order', 3, 'title', 'Autosave', 'description', 'Answers are auto-saved as you attempt the questions.'),
            jsonb_build_object('order', 4, 'title', 'Question palette', 'description', 'Use the question palette to navigate between questions.'),
            jsonb_build_object('order', 5, 'title', 'Mark for review', 'description', 'You can mark a question for review and revisit it before final submission.'),
            jsonb_build_object('order', 6, 'title', 'Stable connection', 'description', 'Ensure a stable internet connection throughout the exam.'),
            jsonb_build_object('order', 7, 'title', 'Do not refresh', 'description', 'Do not refresh the page or close the browser during the exam.')
        ),
        'during_exam', jsonb_build_array(
            jsonb_build_object('order', 1, 'title', 'Live progress', 'description', 'Your progress is calculated automatically based on questions answered.'),
            jsonb_build_object('order', 2, 'title', 'Countdown timer', 'description', 'The server-authoritative timer counts down at the top right of the screen.'),
            jsonb_build_object('order', 3, 'title', 'Modify responses', 'description', 'You can change or clear your response at any time before final submission.')
        ),
        'proctoring', jsonb_build_array(
            jsonb_build_object('order', 1, 'title', 'Camera monitoring', 'description', 'Maintain a clear view of your face in front of the camera when proctoring is active.'),
            jsonb_build_object('order', 2, 'title', 'No tab switching', 'description', 'Do not switch tabs, minimize the browser or open external apps.'),
            jsonb_build_object('order', 3, 'title', 'Audio monitoring', 'description', 'Microphone monitors ambient environment for integrity compliance.')
        ),
        'technical', jsonb_build_array(
            jsonb_build_object('order', 1, 'title', 'Supported browsers', 'description', 'Supported browsers include Google Chrome, Microsoft Edge, and Firefox.'),
            jsonb_build_object('order', 2, 'title', 'Power supply', 'description', 'Keep your device connected to a reliable power source.'),
            jsonb_build_object('order', 3, 'title', 'Session storage', 'description', 'Do not clear cookies or session storage during the exam.')
        ),
        'submission', jsonb_build_array(
            jsonb_build_object('order', 1, 'title', 'Review answers', 'description', 'Review the summary of answered vs unanswered questions before confirming.'),
            jsonb_build_object('order', 2, 'title', 'Final submission', 'description', 'Final submission is irreversible and records your answers immediately.')
        )
    );

    v_instructions := '{}'::jsonb;
    FOREACH v_cat IN ARRAY ARRAY['general', 'during_exam', 'proctoring', 'technical', 'submission'] LOOP
        IF v_has_custom_inst THEN
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', ei.id::TEXT,
                    'title', COALESCE(ei.title, ''),
                    'description', COALESCE(ei.description, ''),
                    'order', COALESCE(ei.display_order, 0),
                    'is_mandatory', COALESCE(ei.is_mandatory, TRUE)
                ) ORDER BY ei.display_order ASC, ei.created_at ASC
            ), '[]'::jsonb)
            INTO v_cat_arr
            FROM public.exam_instructions ei
            WHERE ei.exam_id = p_exam_id
              AND ei.category = v_cat
              AND ei.is_active = TRUE;
        ELSE
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', ei.id::TEXT,
                    'title', COALESCE(ei.title, ''),
                    'description', COALESCE(ei.description, ''),
                    'order', COALESCE(ei.display_order, 0),
                    'is_mandatory', COALESCE(ei.is_mandatory, TRUE)
                ) ORDER BY ei.display_order ASC, ei.created_at ASC
            ), '[]'::jsonb)
            INTO v_cat_arr
            FROM public.exam_instructions ei
            WHERE ei.school_id = v_exam_school_id
              AND ei.exam_id IS NULL
              AND ei.category = v_cat
              AND ei.is_active = TRUE;
        END IF;

        IF jsonb_array_length(v_cat_arr) = 0 THEN
            v_cat_arr := v_default_inst->v_cat;
        END IF;

        v_instructions := jsonb_set(v_instructions, ARRAY[v_cat], v_cat_arr);
    END LOOP;

    -- Overlay plain text exam.instructions into General if present and no custom exam rows exist
    IF NOT v_has_custom_inst AND NULLIF(BTRIM(v_exam.instructions), '') IS NOT NULL THEN
        SELECT jsonb_agg(
            jsonb_build_object(
                'order', ordinality,
                'title', 'Rule ' || ordinality,
                'description', BTRIM(line)
            )
        )
        INTO v_plain_lines
        FROM regexp_split_to_table(v_exam.instructions, E'\r?\n') WITH ORDINALITY AS t(line, ordinality)
        WHERE BTRIM(line) <> '';

        IF v_plain_lines IS NOT NULL AND jsonb_array_length(v_plain_lines) > 0 THEN
            v_instructions := jsonb_set(v_instructions, ARRAY['general'], v_plain_lines);
        END IF;
    END IF;

    -- 6. Dynamic Warnings
    IF (v_raw_cfg ? 'warnings') AND jsonb_typeof(v_raw_cfg->'warnings') = 'array' THEN
        v_warnings := v_raw_cfg->'warnings';
    ELSE
        v_warnings := public._default_prestart_warnings();
    END IF;

    -- 7. Existing Pre-Start session & submission state
    SELECT to_jsonb(ps) INTO v_prestart_session
    FROM public.exam_prestart_sessions ps
    WHERE ps.exam_id = p_exam_id AND ps.student_id = p_user_id
    LIMIT 1;

    SELECT EXISTS (
        SELECT 1 FROM public.exam_submissions es
        WHERE es.exam_id = p_exam_id
          AND es.student_id = p_user_id
          AND es.status IN ('submitted', 'graded', 'evaluated', 'auto_submitted')
    ) INTO v_is_submitted;

    -- 8. Dynamic Date & Time formatting using real DB timestamps
    v_exam_date_disp := CASE
        WHEN v_exam.exam_date IS NOT NULL THEN TO_CHAR(v_exam.exam_date, 'Mon DD, YYYY')
        WHEN v_exam.start_time IS NOT NULL THEN TO_CHAR(v_exam.start_time AT TIME ZONE 'UTC', 'Mon DD, YYYY')
        ELSE '-'
    END;

    v_start_time_disp := CASE
        WHEN v_exam.start_time IS NOT NULL THEN
            TO_CHAR(v_exam.start_time AT TIME ZONE 'UTC', 'HH12:MI AM') || ', ' || v_exam_date_disp
        WHEN v_exam.exam_date IS NOT NULL THEN
            '09:00 AM, ' || v_exam_date_disp
        ELSE 'Flexible Window'
    END;

    IF v_exam.end_time IS NOT NULL THEN
        v_end_time_disp := TO_CHAR(v_exam.end_time AT TIME ZONE 'UTC', 'HH12:MI AM, Mon DD, YYYY');
    ELSIF v_exam.start_time IS NOT NULL THEN
        v_computed_end := v_exam.start_time + ((COALESCE(v_exam.duration_minutes, 120)) || ' minutes')::INTERVAL;
        v_end_time_disp := TO_CHAR(v_computed_end AT TIME ZONE 'UTC', 'HH12:MI AM, Mon DD, YYYY');
    ELSE
        v_end_time_disp := 'Self-Paced';
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'school_id', v_exam_school_id,
        'data', jsonb_build_object(
            'exam', jsonb_build_object(
                'id', v_exam.id,
                'title', COALESCE(v_exam.title, 'Untitled Examination'),
                'description', COALESCE(v_exam.description, ''),
                'subject', v_subject_name,
                'exam_category', COALESCE(NULLIF(v_exam.exam_category, ''), NULLIF(v_exam.paper_type, ''), 'Examination'),
                'exam_purpose', COALESCE(v_exam.exam_purpose, ''),
                'duration_minutes', COALESCE(v_exam.duration_minutes, 120),
                'total_marks', COALESCE(v_exam.total_marks, NULLIF(v_calc_marks, 0), 100),
                'passing_marks', COALESCE(v_exam.passing_marks, 33),
                'start_time', v_start_time_disp,
                'end_time', v_end_time_disp,
                'exam_date', v_exam_date_disp,
                'exam_mode', COALESCE(NULLIF(v_exam.exam_mode, ''), NULLIF(v_exam.exam_type, ''), 'Online'),
                'status', COALESCE(v_exam.status, 'scheduled'),
                'total_questions', v_total_q,
                'target_classes', v_target_classes,
                'target_scope', v_target_scope,
                'negative_marking', COALESCE(v_exam.negative_marking, FALSE),
                'allow_calculator', COALESCE(v_exam.allow_calculator, FALSE),
                'has_passcode', (NULLIF(BTRIM(v_exam.passcode), '') IS NOT NULL)
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
            'permissions', jsonb_build_object(
                'can_customize', v_can_customize,
                'is_read_only', NOT v_can_customize
            ),
            'readiness_policy', v_readiness_policy,
            'instructions', v_instructions,
            'has_custom_instructions', v_has_custom_inst,
            'warnings', v_warnings,
            'prestart_session', v_prestart_session,
            'is_submitted', v_is_submitted
        )
    );
END;
$$;


-- 5. RPC: Update Pre-Start Policy Configuration & Custom Warnings (Exam Setters Only)
CREATE OR REPLACE FUNCTION public.rpc_update_exam_prestart_config(
    p_exam_id UUID,
    p_user_id UUID,
    p_config JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_exam RECORD;
    v_role TEXT;
    v_name TEXT;
    v_can_customize BOOLEAN := FALSE;
    v_existing_cfg JSONB;
    v_camera_mode TEXT;
    v_mic_mode TEXT;
    v_screen_mode TEXT;
    v_device_mode TEXT;
    v_fullscreen_req BOOLEAN;
    v_max_tab_switches INT;
    v_ack_req BOOLEAN;
    v_warnings JSONB;
    v_new_cfg JSONB;
BEGIN
    SELECT * INTO v_exam FROM public.exams WHERE id = p_exam_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 404, 'error', 'Examination not found');
    END IF;

    SELECT role, full_name INTO v_role, v_name FROM public.profiles WHERE id = p_user_id;
    v_can_customize := public._can_customize_exam_prestart(
        COALESCE(v_role, 'student'),
        p_user_id,
        v_exam.created_by,
        v_exam.teacher_id,
        v_exam.target_students,
        v_exam.exam_purpose
    );

    IF NOT v_can_customize THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'status', 403,
            'error', 'Only exam setters or administrators can customize examination policies.'
        );
    END IF;

    v_existing_cfg := COALESCE(v_exam.prestart_config, '{}'::jsonb);
    IF jsonb_typeof(v_existing_cfg) <> 'object' THEN
        v_existing_cfg := '{}'::jsonb;
    END IF;

    v_camera_mode := public._normalize_prestart_mode(
        COALESCE(p_config->>'camera_mode', v_existing_cfg->>'camera_mode', 'REQUIRED'), 'REQUIRED'
    );
    v_mic_mode := public._normalize_prestart_mode(
        COALESCE(p_config->>'microphone_mode', v_existing_cfg->>'microphone_mode', 'REQUIRED'), 'REQUIRED'
    );
    v_screen_mode := public._normalize_prestart_mode(
        COALESCE(p_config->>'screen_share_mode', v_existing_cfg->>'screen_share_mode', 'OPTIONAL'), 'OPTIONAL'
    );
    v_device_mode := public._normalize_prestart_mode(
        COALESCE(p_config->>'device_check_mode', v_existing_cfg->>'device_check_mode', 'REQUIRED'), 'REQUIRED'
    );

    v_fullscreen_req := COALESCE(
        (p_config->>'fullscreen_required')::BOOLEAN,
        (v_existing_cfg->>'fullscreen_required')::BOOLEAN,
        TRUE
    );
    v_max_tab_switches := COALESCE(
        (p_config->>'max_tab_switches')::INT,
        (v_existing_cfg->>'max_tab_switches')::INT,
        3
    );
    v_ack_req := COALESCE(
        (p_config->>'acknowledgment_required')::BOOLEAN,
        (v_existing_cfg->>'acknowledgment_required')::BOOLEAN,
        TRUE
    );

    IF (p_config ? 'warnings') AND jsonb_typeof(p_config->'warnings') = 'array' THEN
        SELECT COALESCE(jsonb_agg(BTRIM(w)), '[]'::jsonb)
        INTO v_warnings
        FROM jsonb_array_elements_text(p_config->'warnings') AS w
        WHERE BTRIM(w) <> '';
    ELSIF (v_existing_cfg ? 'warnings') AND jsonb_typeof(v_existing_cfg->'warnings') = 'array' THEN
        v_warnings := v_existing_cfg->'warnings';
    ELSE
        v_warnings := public._default_prestart_warnings();
    END IF;

    v_new_cfg := v_existing_cfg || jsonb_build_object(
        'camera_mode', v_camera_mode,
        'microphone_mode', v_mic_mode,
        'screen_share_mode', v_screen_mode,
        'device_check_mode', v_device_mode,
        'fullscreen_required', v_fullscreen_req,
        'max_tab_switches', v_max_tab_switches,
        'acknowledgment_required', v_ack_req,
        'warnings', v_warnings
    );

    UPDATE public.exams
    SET prestart_config = v_new_cfg,
        camera_required = (v_camera_mode = 'REQUIRED'),
        mic_required = (v_mic_mode = 'REQUIRED'),
        updated_at = NOW(),
        updated_by = p_user_id
    WHERE id = p_exam_id;

    BEGIN
        INSERT INTO public.exam_activity_logs (
            school_id, exam_id, action, title, description, details, performed_by, performed_by_name
        ) VALUES (
            v_exam.school_id, p_exam_id, 'prestart_policy_updated',
            'Updated Pre-Start Proctoring Policy',
            'Exam setter updated camera/microphone/screen-share readiness policy.',
            v_new_cfg, p_user_id, COALESCE(v_name, 'Exam Setter')
        );
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'readiness_policy', jsonb_build_object(
                'camera_mode', v_camera_mode,
                'microphone_mode', v_mic_mode,
                'screen_share_mode', v_screen_mode,
                'device_check_mode', v_device_mode,
                'camera_required', (v_camera_mode = 'REQUIRED'),
                'microphone_required', (v_mic_mode = 'REQUIRED'),
                'screen_sharing_required', (v_screen_mode = 'REQUIRED'),
                'fullscreen_required', v_fullscreen_req,
                'max_tab_switches', v_max_tab_switches,
                'instruction_acknowledgment_required', v_ack_req
            ),
            'warnings', v_warnings
        )
    );
END;
$$;


-- 6. RPC: Atomically Save Per-Exam Categorized Instructions (Exam Setters Only)
CREATE OR REPLACE FUNCTION public.rpc_save_exam_prestart_instructions(
    p_exam_id UUID,
    p_user_id UUID,
    p_school_id UUID,
    p_instructions JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_exam RECORD;
    v_role TEXT;
    v_name TEXT;
    v_can_customize BOOLEAN := FALSE;
    v_exam_school_id UUID;
    v_cat TEXT;
    v_item JSONB;
    v_order INT;
    v_desc TEXT;
    v_title TEXT;
    v_mandatory BOOLEAN;
    v_count INT := 0;
BEGIN
    SELECT * INTO v_exam FROM public.exams WHERE id = p_exam_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 404, 'error', 'Examination not found');
    END IF;

    SELECT role, full_name INTO v_role, v_name FROM public.profiles WHERE id = p_user_id;
    v_can_customize := public._can_customize_exam_prestart(
        COALESCE(v_role, 'student'),
        p_user_id,
        v_exam.created_by,
        v_exam.teacher_id,
        v_exam.target_students,
        v_exam.exam_purpose
    );

    IF NOT v_can_customize THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'status', 403,
            'error', 'Only exam setters or administrators can modify exam instructions.'
        );
    END IF;

    IF p_instructions IS NULL OR jsonb_typeof(p_instructions) <> 'object' THEN
        RETURN jsonb_build_object('success', FALSE, 'status', 400, 'error', 'Invalid instructions payload.');
    END IF;

    v_exam_school_id := COALESCE(v_exam.school_id, p_school_id);

    DELETE FROM public.exam_instructions WHERE exam_id = p_exam_id;

    FOREACH v_cat IN ARRAY ARRAY['general', 'during_exam', 'proctoring', 'technical', 'submission'] LOOP
        IF (p_instructions ? v_cat) AND jsonb_typeof(p_instructions->v_cat) = 'array' THEN
            v_order := 0;
            FOR v_item IN SELECT * FROM jsonb_array_elements(p_instructions->v_cat) LOOP
                v_order := v_order + 1;
                IF jsonb_typeof(v_item) = 'object' THEN
                    v_desc := BTRIM(COALESCE(v_item->>'description', ''));
                    v_title := BTRIM(COALESCE(NULLIF(v_item->>'title', ''), 'Rule ' || v_order));
                    v_mandatory := COALESCE((v_item->>'is_mandatory')::BOOLEAN, TRUE);
                ELSE
                    v_desc := BTRIM(v_item #>> '{}');
                    v_title := 'Rule ' || v_order;
                    v_mandatory := TRUE;
                END IF;

                IF v_desc <> '' THEN
                    INSERT INTO public.exam_instructions (
                        id, school_id, exam_id, category, title, description, display_order, is_mandatory, is_active
                    ) VALUES (
                        gen_random_uuid(), v_exam_school_id, p_exam_id, v_cat, v_title, v_desc, v_order, v_mandatory, TRUE
                    );
                    v_count := v_count + 1;
                END IF;
            END LOOP;
        END IF;
    END LOOP;

    BEGIN
        INSERT INTO public.exam_activity_logs (
            school_id, exam_id, action, title, description, performed_by, performed_by_name
        ) VALUES (
            v_exam_school_id, p_exam_id, 'prestart_instructions_updated',
            'Updated Exam Instructions',
            'Exam setter saved ' || v_count || ' custom instructions.',
            p_user_id, COALESCE(v_name, 'Exam Setter')
        );
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    RETURN jsonb_build_object(
        'success', TRUE,
        'count', v_count,
        'message', 'Exam instructions updated successfully.'
    );
END;
$$;


-- 7. RPC: Record / Upsert Candidate System & Permission Check Results
CREATE OR REPLACE FUNCTION public.rpc_record_exam_prestart_checks(
    p_exam_id UUID,
    p_user_id UUID,
    p_school_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_exam_school_id UUID;
    v_now TIMESTAMPTZ := NOW();
BEGIN
    SELECT COALESCE(school_id, p_school_id) INTO v_exam_school_id
    FROM public.exams WHERE id = p_exam_id;

    v_exam_school_id := COALESCE(v_exam_school_id, p_school_id);

    INSERT INTO public.exam_prestart_sessions (
        id, school_id, exam_id, student_id,
        camera_status, microphone_status, screen_share_status, system_status,
        readiness_status, system_details, started_at, last_activity_at, created_at, updated_at
    ) VALUES (
        gen_random_uuid(), v_exam_school_id, p_exam_id, p_user_id,
        COALESCE(NULLIF(p_payload->>'camera_status', ''), 'NOT_CHECKED'),
        COALESCE(NULLIF(p_payload->>'microphone_status', ''), 'NOT_CHECKED'),
        COALESCE(NULLIF(p_payload->>'screen_share_status', ''), 'NOT_CHECKED'),
        COALESCE(NULLIF(p_payload->>'system_status', ''), 'NOT_CHECKED'),
        COALESCE(NULLIF(p_payload->>'readiness_status', ''), 'CHECKING'),
        COALESCE(p_payload->'system_details', '{}'::jsonb),
        v_now, v_now, v_now, v_now
    )
    ON CONFLICT (exam_id, student_id) DO UPDATE SET
        camera_status = COALESCE(NULLIF(p_payload->>'camera_status', ''), public.exam_prestart_sessions.camera_status),
        microphone_status = COALESCE(NULLIF(p_payload->>'microphone_status', ''), public.exam_prestart_sessions.microphone_status),
        screen_share_status = COALESCE(NULLIF(p_payload->>'screen_share_status', ''), public.exam_prestart_sessions.screen_share_status),
        system_status = COALESCE(NULLIF(p_payload->>'system_status', ''), public.exam_prestart_sessions.system_status),
        readiness_status = COALESCE(NULLIF(p_payload->>'readiness_status', ''), public.exam_prestart_sessions.readiness_status),
        system_details = CASE WHEN p_payload ? 'system_details' AND jsonb_typeof(p_payload->'system_details') = 'object'
                              THEN p_payload->'system_details'
                              ELSE public.exam_prestart_sessions.system_details END,
        last_activity_at = v_now,
        updated_at = v_now;

    RETURN jsonb_build_object('success', TRUE, 'saved_at', v_now);
END;
$$;


-- 8. RPC: Record / Upsert Candidate Rule Acknowledgment
CREATE OR REPLACE FUNCTION public.rpc_record_exam_prestart_acknowledgment(
    p_exam_id UUID,
    p_user_id UUID,
    p_school_id UUID,
    p_acknowledged BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_exam_school_id UUID;
    v_now TIMESTAMPTZ := NOW();
BEGIN
    SELECT COALESCE(school_id, p_school_id) INTO v_exam_school_id
    FROM public.exams WHERE id = p_exam_id;

    v_exam_school_id := COALESCE(v_exam_school_id, p_school_id);

    INSERT INTO public.exam_prestart_sessions (
        id, school_id, exam_id, student_id,
        acknowledged, acknowledged_at, started_at, last_activity_at, created_at, updated_at
    ) VALUES (
        gen_random_uuid(), v_exam_school_id, p_exam_id, p_user_id,
        COALESCE(p_acknowledged, TRUE),
        CASE WHEN COALESCE(p_acknowledged, TRUE) THEN v_now ELSE NULL END,
        v_now, v_now, v_now, v_now
    )
    ON CONFLICT (exam_id, student_id) DO UPDATE SET
        acknowledged = COALESCE(p_acknowledged, TRUE),
        acknowledged_at = CASE WHEN COALESCE(p_acknowledged, TRUE) THEN v_now ELSE NULL END,
        last_activity_at = v_now,
        updated_at = v_now;

    RETURN jsonb_build_object(
        'success', TRUE,
        'acknowledged', COALESCE(p_acknowledged, TRUE),
        'timestamp', v_now
    );
END;
$$;


-- 9. RPC: Get Complete Take Exam Info (Sanitized Questions, Sections, Session Timer, Prestart Config)
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
    ORDER BY started_at DESC
    LIMIT 1;

    IF FOUND THEN
        v_expires_at := v_session.started_at + ((COALESCE(v_exam.duration_minutes, 90) + COALESCE(v_session.extra_minutes, 0)) || ' minutes')::INTERVAL;
        v_remaining_secs := GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (v_expires_at - NOW())))::INT);

        v_session_info := jsonb_build_object(
            'id', v_session.id,
            'status', COALESCE(v_session.status, 'in_progress'),
            'started_at', v_session.started_at,
            'expires_at', v_expires_at,
            'remaining_seconds', v_remaining_secs,
            'is_paused', COALESCE(v_session.is_paused, FALSE),
            'warnings_count', COALESCE(v_session.warnings_count, 0),
            'active_question', v_session.active_question
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
                'prestart_config', COALESCE(v_exam.prestart_config, '{}'::jsonb),
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


-- Grant execute permissions cleanly across Supabase / PostgREST roles
GRANT EXECUTE ON FUNCTION public._normalize_prestart_mode(TEXT, TEXT) TO anon, authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION public._can_customize_exam_prestart(TEXT, UUID, UUID, UUID, JSONB, TEXT) TO anon, authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION public._default_prestart_warnings() TO anon, authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION public.rpc_get_exam_prestart_info(UUID, UUID, UUID) TO anon, authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION public.rpc_update_exam_prestart_config(UUID, UUID, JSONB) TO anon, authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION public.rpc_save_exam_prestart_instructions(UUID, UUID, UUID, JSONB) TO anon, authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION public.rpc_record_exam_prestart_checks(UUID, UUID, UUID, JSONB) TO anon, authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION public.rpc_record_exam_prestart_acknowledgment(UUID, UUID, UUID, BOOLEAN) TO anon, authenticated, service_role, postgres;
GRANT EXECUTE ON FUNCTION public.rpc_get_exam_take_info(UUID, UUID, UUID) TO anon, authenticated, service_role, postgres;

-- Notify PostgREST to reload schema cache immediately
NOTIFY pgrst, 'reload schema';
