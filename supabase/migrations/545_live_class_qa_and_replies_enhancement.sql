-- ============================================================================
-- Migration 545: Live Class Multi-Reply Q&A and Real User Profile Tooltip Metadata
-- ============================================================================

-- 1. Drop old 3-argument version of sp_answer_live_class_question
DROP FUNCTION IF EXISTS public.sp_answer_live_class_question(UUID, UUID, TEXT);

-- 2. Drop existing 5-argument version to ensure clean replacement
DROP FUNCTION IF EXISTS public.sp_answer_live_class_question(UUID, UUID, TEXT, TEXT, TEXT);

-- 3. Create comprehensive sp_answer_live_class_question supporting multi-user replies & contact details
CREATE OR REPLACE FUNCTION public.sp_answer_live_class_question(
    p_question_id UUID,
    p_user_id UUID,
    p_answer TEXT,
    p_author_name TEXT DEFAULT NULL,
    p_author_role TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pr RECORD;
    v_clean_name TEXT;
    v_clean_role TEXT;
    v_clean_email TEXT;
    v_clean_phone TEXT;
    v_new_reply JSONB;
    v_updated_answers JSONB;
BEGIN
    -- Fetch author profile details from public.profiles
    SELECT full_name, role, email, phone INTO v_pr
    FROM public.profiles
    WHERE id = p_user_id;

    v_clean_name := COALESCE(NULLIF(v_pr.full_name, ''), NULLIF(p_author_name, ''), 'Instructor');
    v_clean_role := COALESCE(NULLIF(v_pr.role, ''), NULLIF(p_author_role, ''), 'Teacher');
    v_clean_email := v_pr.email;
    v_clean_phone := v_pr.phone;

    v_new_reply := jsonb_build_object(
        'id', gen_random_uuid()::TEXT,
        'author_id', p_user_id::TEXT,
        'author_name', v_clean_name,
        'author_role', v_clean_role,
        'author_email', v_clean_email,
        'author_phone', v_clean_phone,
        'answer', TRIM(p_answer),
        'created_at', NOW()
    );

    -- Append reply to answers array and update question status
    UPDATE public.live_class_questions
    SET status = 'ANSWERED',
        answer = TRIM(p_answer),
        answered_by = p_user_id,
        answered_at = NOW(),
        answers = COALESCE(answers, '[]'::jsonb) || jsonb_build_array(v_new_reply),
        updated_at = NOW()
    WHERE id = p_question_id
    RETURNING answers INTO v_updated_answers;

    RETURN jsonb_build_object(
        'success', TRUE,
        'question_id', p_question_id,
        'status', 'ANSWERED',
        'reply', v_new_reply,
        'answers', v_updated_answers
    );
END;
$$;

-- 4. Create or replace sp_submit_live_class_question with profile resolution
CREATE OR REPLACE FUNCTION public.sp_submit_live_class_question(
    p_session_id UUID,
    p_school_id UUID,
    p_author_id UUID,
    p_author_name TEXT,
    p_author_role TEXT,
    p_question TEXT,
    p_is_anonymous BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_id UUID;
    v_result JSONB;
    v_pr RECORD;
    v_clean_name TEXT;
    v_clean_role TEXT;
    v_clean_email TEXT;
    v_clean_phone TEXT;
BEGIN
    SELECT full_name, role, email, phone INTO v_pr
    FROM public.profiles
    WHERE id = p_author_id;

    v_clean_name := COALESCE(NULLIF(v_pr.full_name, ''), NULLIF(p_author_name, ''), 'Student');
    IF v_clean_name IN ('Student', 'User', 'You') AND v_pr.full_name IS NOT NULL AND v_pr.full_name != '' THEN
        v_clean_name := v_pr.full_name;
    END IF;

    v_clean_role := COALESCE(NULLIF(v_pr.role, ''), NULLIF(p_author_role, ''), 'student');
    v_clean_email := v_pr.email;
    v_clean_phone := v_pr.phone;

    INSERT INTO public.live_class_questions (
        session_id, school_id, author_id, author_name, author_role,
        question, is_anonymous, status, upvotes_count, answers
    ) VALUES (
        p_session_id, p_school_id, p_author_id, v_clean_name, v_clean_role,
        p_question, p_is_anonymous, 'NEW', 0, '[]'::jsonb
    )
    RETURNING id INTO v_new_id;

    SELECT jsonb_build_object(
        'id', q.id,
        'session_id', q.session_id,
        'author_id', q.author_id,
        'author', CASE WHEN q.is_anonymous THEN 'Anonymous Student' ELSE q.author_name END,
        'author_role', q.author_role,
        'author_email', v_clean_email,
        'author_phone', v_clean_phone,
        'question', q.question,
        'upvotes', q.upvotes_count,
        'has_upvoted', FALSE,
        'status', q.status,
        'answered', FALSE,
        'answer', NULL,
        'answers', '[]'::jsonb,
        'is_pinned', FALSE,
        'created_at', q.created_at
    ) INTO v_result
    FROM public.live_class_questions q
    WHERE q.id = v_new_id;

    RETURN v_result;
END;
$$;

-- 5. Auto-heal any existing live_class_questions with generic placeholder author names
UPDATE public.live_class_questions q
SET author_name = p.full_name
FROM public.profiles p
WHERE q.author_id = p.id AND (q.author_name IS NULL OR q.author_name IN ('Student', 'User', 'You'));
