-- ============================================================================
-- Migration: 260_fn_schedule_comments_operations.sql
-- Description:
--   Implements stored procedures fn_add_schedule_comment and
--   fn_get_schedule_comments to atomically insert and retrieve discussion
--   activity and comments without direct raw SQL queries in API endpoints.
-- ============================================================================

DROP FUNCTION IF EXISTS public.fn_add_schedule_comment(UUID, UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS public.fn_add_schedule_comment(UUID, UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.fn_add_schedule_comment(
    p_school_id UUID,
    p_user_id UUID,
    p_schedule_id UUID,
    p_comment_text TEXT
) RETURNS JSONB AS $$
DECLARE
    v_comment_id UUID := gen_random_uuid();
    v_created_at TIMESTAMPTZ := NOW();
    v_full_name TEXT;
    v_avatar_url TEXT;
    v_role TEXT;
BEGIN
    SELECT full_name, avatar_url, role INTO v_full_name, v_avatar_url, v_role
    FROM public.profiles
    WHERE id = p_user_id;

    INSERT INTO public.schedule_comments (
        id, schedule_id, user_id, comment_text, created_at, updated_at
    ) VALUES (
        v_comment_id, p_schedule_id, p_user_id, p_comment_text, v_created_at, v_created_at
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Comment added successfully.',
        'data', jsonb_build_object(
            'id', v_comment_id,
            'schedule_id', p_schedule_id,
            'user_id', p_user_id,
            'comment_text', p_comment_text,
            'full_name', COALESCE(v_full_name, 'Unknown'),
            'avatar_url', v_avatar_url,
            'created_at', v_created_at
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


DROP FUNCTION IF EXISTS public.fn_get_schedule_comments(UUID, UUID);
DROP FUNCTION IF EXISTS public.fn_get_schedule_comments(UUID);

CREATE OR REPLACE FUNCTION public.fn_get_schedule_comments(
    p_school_id UUID,
    p_schedule_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_comments JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', sc.id,
        'schedule_id', sc.schedule_id,
        'user_id', sc.user_id,
        'comment_text', sc.comment_text,
        'full_name', COALESCE(p.full_name, 'Unknown'),
        'avatar_url', p.avatar_url,
        'created_at', sc.created_at
    ) ORDER BY sc.created_at ASC), '[]'::jsonb)
    INTO v_comments
    FROM public.schedule_comments sc
    LEFT JOIN public.profiles p ON p.id = sc.user_id
    WHERE sc.schedule_id = p_schedule_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', v_comments
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
