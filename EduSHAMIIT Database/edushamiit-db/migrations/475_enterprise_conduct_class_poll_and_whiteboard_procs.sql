-- Migration 475: Stored Procedures for Conduct Class Poll Creation & Whiteboard Persistence
-- Author: EduSHAMIIT Enterprise Virtual Classroom Engine
-- Date: 2026-11-12

BEGIN;

-- 1. Stored Procedure: sp_create_and_launch_poll
CREATE OR REPLACE FUNCTION public.sp_create_and_launch_poll(
    p_session_id UUID,
    p_school_id UUID,
    p_teacher_id UUID,
    p_title TEXT,
    p_question TEXT,
    p_options JSONB,
    p_correct_option TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_poll_id UUID := gen_random_uuid();
    v_formatted_options JSONB := '[]'::jsonb;
    v_opt JSONB;
    v_result JSONB;
BEGIN
    -- Close any existing active polls for this session
    UPDATE public.live_class_polls
    SET status = 'CLOSED', updated_at = NOW()
    WHERE session_id = p_session_id AND status = 'ACTIVE';

    -- Format options with initial zero votes
    FOR v_opt IN SELECT * FROM jsonb_array_elements(p_options) LOOP
        v_formatted_options := v_formatted_options || jsonb_build_array(
            jsonb_build_object(
                'id', COALESCE(v_opt->>'id', 'opt_' || gen_random_uuid()::TEXT),
                'text', COALESCE(v_opt->>'text', v_opt->>'label', ''),
                'votes', COALESCE((v_opt->>'votes')::INT, 0),
                'percentage', 0
            )
        );
    END LOOP;

    -- Insert new active poll
    INSERT INTO public.live_class_polls (
        id, session_id, school_id, creator_id, title, question,
        poll_type, status, options, total_votes, correct_option_id,
        created_at, updated_at
    ) VALUES (
        v_new_poll_id, p_session_id, p_school_id, p_teacher_id,
        COALESCE(p_title, 'Quick Concept Poll'),
        p_question,
        'single_choice',
        'ACTIVE',
        v_formatted_options,
        0,
        p_correct_option,
        NOW(),
        NOW()
    );

    SELECT jsonb_build_object(
        'id', p.id,
        'session_id', p.session_id,
        'title', p.title,
        'question', p.question,
        'poll_type', p.poll_type,
        'status', p.status,
        'options', p.options,
        'total_votes', p.total_votes,
        'correct_option_id', p.correct_option_id,
        'created_at', p.created_at
    ) INTO v_result
    FROM public.live_class_polls p
    WHERE p.id = v_new_poll_id;

    RETURN v_result;
END;
$$;

-- 2. Stored Procedure: sp_save_whiteboard_canvas
CREATE OR REPLACE FUNCTION public.sp_save_whiteboard_canvas(
    p_session_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_canvas_data JSONB,
    p_teacher_only_mode BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_whiteboard_id UUID;
    v_result JSONB;
BEGIN
    SELECT id INTO v_whiteboard_id
    FROM public.live_class_whiteboards
    WHERE session_id = p_session_id
    LIMIT 1;

    IF v_whiteboard_id IS NULL THEN
        INSERT INTO public.live_class_whiteboards (
            session_id, school_id, canvas_data, teacher_only_mode, last_saved_by, updated_at
        ) VALUES (
            p_session_id, p_school_id, p_canvas_data, p_teacher_only_mode, p_user_id, NOW()
        )
        RETURNING id INTO v_whiteboard_id;
    ELSE
        UPDATE public.live_class_whiteboards
        SET canvas_data = p_canvas_data,
            teacher_only_mode = COALESCE(p_teacher_only_mode, teacher_only_mode),
            last_saved_by = p_user_id,
            updated_at = NOW()
        WHERE id = v_whiteboard_id;
    END IF;

    SELECT jsonb_build_object(
        'id', wb.id,
        'session_id', wb.session_id,
        'canvas_data', wb.canvas_data,
        'teacher_only_mode', wb.teacher_only_mode,
        'last_saved_by', wb.last_saved_by,
        'updated_at', wb.updated_at
    ) INTO v_result
    FROM public.live_class_whiteboards wb
    WHERE wb.id = v_whiteboard_id;

    RETURN v_result;
END;
$$;

COMMIT;
