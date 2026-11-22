-- 548_add_answer_key_to_sp_answer_live_class_question.sql
-- Ensure both legacy 'answer' field and modern 'reply'/'answers' fields are returned in JSON response

CREATE OR REPLACE FUNCTION public.sp_answer_live_class_question(
    p_question_id uuid,
    p_user_id uuid,
    p_answer text,
    p_author_name text DEFAULT NULL::text,
    p_author_role text DEFAULT NULL::text
)
RETURNS jsonb
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

    v_clean_name := COALESCE(v_pr.full_name, p_author_name, 'Instructor');
    v_clean_role := COALESCE(v_pr.role, p_author_role, 'Teacher');
    v_clean_email := v_pr.email;
    v_clean_phone := v_pr.phone;

    -- Build structured reply object
    v_new_reply := jsonb_build_object(
        'id', gen_random_uuid(),
        'author_id', p_user_id,
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
        'answer', TRIM(p_answer),
        'reply', v_new_reply,
        'answers', v_updated_answers
    );
END;
$$;
