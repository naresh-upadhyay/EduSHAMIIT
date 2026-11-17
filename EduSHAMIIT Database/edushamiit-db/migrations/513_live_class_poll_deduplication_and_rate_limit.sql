-- ============================================================================
-- Migration 513: Live Class Poll Multi-Click Deduplication & Rate Limit Lock
-- Author: EduSHAMIIT Enterprise Virtual Classroom Engine
-- Date: 2026-11-16
-- ============================================================================

-- 1. Upgrade sp_create_and_launch_poll with Atomic Deduplication Lock
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
    v_existing_poll_id UUID;
    v_new_poll_id UUID := gen_random_uuid();
    v_formatted_options JSONB := '[]'::jsonb;
    v_opt JSONB;
    v_result JSONB;
    v_clean_question TEXT := TRIM(COALESCE(p_question, ''));
    v_clean_title TEXT := TRIM(COALESCE(p_title, 'Quick Concept Poll'));
BEGIN
    IF v_clean_question = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Poll question cannot be empty');
    END IF;

    -- STEP 0: SESSION TRANSACTION ADVISORY LOCK
    -- Atomically serializes concurrent poll launches for the same session
    PERFORM pg_advisory_xact_lock(hashtext('poll_launch_' || p_session_id::TEXT));

    -- STEP 1: ATOMIC ANTI-DUPLICATE & RATE LIMIT CHECK
    -- If a poll with the exact same question is already ACTIVE, OR was created in the last 10 seconds for this session:
    -- Return the existing poll without closing it or inserting a duplicate!
    SELECT id INTO v_existing_poll_id
    FROM public.live_class_polls
    WHERE session_id = p_session_id
      AND LOWER(TRIM(question)) = LOWER(v_clean_question)
      AND (
          status = 'ACTIVE' 
          OR created_at >= (NOW() - INTERVAL '10 seconds')
      )
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_existing_poll_id IS NOT NULL THEN
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
            'created_at', p.created_at,
            'is_duplicate_suppressed', TRUE
        ) INTO v_result
        FROM public.live_class_polls p
        WHERE p.id = v_existing_poll_id;

        RETURN v_result;
    END IF;

    -- STEP 2: CLOSE ANY OLDER ACTIVE POLLS FOR THIS SESSION
    UPDATE public.live_class_polls
    SET status = 'CLOSED', updated_at = NOW()
    WHERE session_id = p_session_id AND status = 'ACTIVE';

    -- STEP 3: FORMAT POLL OPTIONS WITH INITIAL ZERO VOTES
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

    -- STEP 4: INSERT NEW ACTIVE POLL
    INSERT INTO public.live_class_polls (
        id, session_id, school_id, creator_id, title, question,
        poll_type, status, options, total_votes, correct_option_id,
        created_at, updated_at
    ) VALUES (
        v_new_poll_id, p_session_id, p_school_id, p_teacher_id,
        v_clean_title,
        v_clean_question,
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
        'created_at', p.created_at,
        'is_duplicate_suppressed', FALSE
    ) INTO v_result
    FROM public.live_class_polls p
    WHERE p.id = v_new_poll_id;

    RETURN v_result;
END;
$$;

-- 2. Cleanup any accidental duplicate zero-vote past polls with identical questions created within 15 seconds of an active poll
DELETE FROM public.live_class_polls p_old
WHERE p_old.status = 'CLOSED'
  AND p_old.total_votes = 0
  AND EXISTS (
      SELECT 1 FROM public.live_class_polls p_new
      WHERE p_new.session_id = p_old.session_id
        AND LOWER(TRIM(p_new.question)) = LOWER(TRIM(p_old.question))
        AND p_new.id <> p_old.id
        AND p_new.created_at >= p_old.created_at
        AND p_new.created_at <= (p_old.created_at + INTERVAL '15 seconds')
  );
