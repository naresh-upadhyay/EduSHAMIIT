-- ============================================================================
-- Migration 421: Fix Complaints Feedback Saving and History Deduplication
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_hostel_complaints_submit_feedback(
    p_school_id UUID,
    p_user_id UUID,
    p_complaint_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_rating INT := COALESCE((p_payload->>'rating')::INT, 5);
    v_comment TEXT := p_payload->>'comment';
    v_quality INT := (p_payload->>'resolution_quality')::INT;
    v_response_rating INT := (p_payload->>'response_time_rating')::INT;
    v_behavior_rating INT := (p_payload->>'staff_behavior_rating')::INT;
    v_is_satisfied BOOLEAN := COALESCE((p_payload->>'is_satisfied')::BOOLEAN, TRUE);
    v_user_name VARCHAR(150);
    v_existing_history_id UUID;
    v_feedback_record RECORD;
BEGIN
    SELECT COALESCE(full_name, 'Student') INTO v_user_name
    FROM public.profiles WHERE id = p_user_id;

    -- Upsert feedback record
    INSERT INTO public.hostel_complaint_feedback (
        complaint_id,
        school_id,
        submitted_by_user_id,
        submitted_by_name,
        rating,
        resolution_quality,
        response_time_rating,
        staff_behavior_rating,
        comment,
        is_satisfied
    ) VALUES (
        p_complaint_id,
        p_school_id,
        p_user_id,
        COALESCE(v_user_name, 'Requester'),
        v_rating,
        v_quality,
        v_response_rating,
        v_behavior_rating,
        v_comment,
        v_is_satisfied
    )
    ON CONFLICT (complaint_id) DO UPDATE
    SET rating = EXCLUDED.rating,
        resolution_quality = EXCLUDED.resolution_quality,
        response_time_rating = EXCLUDED.response_time_rating,
        staff_behavior_rating = EXCLUDED.staff_behavior_rating,
        comment = EXCLUDED.comment,
        is_satisfied = EXCLUDED.is_satisfied,
        created_at = NOW()
    RETURNING * INTO v_feedback_record;

    -- Update parent complaint timestamp
    UPDATE public.hostel_complaints
    SET updated_at = NOW()
    WHERE id = p_complaint_id;

    -- Avoid duplicate feedback entries in Timeline: check if an existing feedback timeline item exists
    SELECT id INTO v_existing_history_id
    FROM public.hostel_complaint_status_history
    WHERE complaint_id = p_complaint_id
      AND event_title LIKE 'Requester submitted feedback%'
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_existing_history_id IS NOT NULL THEN
        -- Update the existing timeline item rather than spamming multiple entries
        UPDATE public.hostel_complaint_status_history
        SET event_title = 'Requester submitted feedback (' || v_rating || '★)',
            action_note = COALESCE(v_comment, 'Service rated by resident.'),
            created_at = NOW()
        WHERE id = v_existing_history_id;
    ELSE
        -- Insert new timeline item
        INSERT INTO public.hostel_complaint_status_history (
            complaint_id,
            school_id,
            actor_user_id,
            actor_name,
            actor_role,
            to_status,
            event_title,
            action_note
        ) VALUES (
            p_complaint_id,
            p_school_id,
            p_user_id,
            COALESCE(v_user_name, 'Student'),
            'Student',
            'COMPLETED',
            'Requester submitted feedback (' || v_rating || '★)',
            COALESCE(v_comment, 'Service rated by resident.')
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Feedback received. Thank you!',
        'feedback', jsonb_build_object(
            'id', v_feedback_record.id,
            'rating', v_feedback_record.rating,
            'resolution_quality', v_feedback_record.resolution_quality,
            'response_time_rating', v_feedback_record.response_time_rating,
            'staff_behavior_rating', v_feedback_record.staff_behavior_rating,
            'comment', v_feedback_record.comment,
            'is_satisfied', v_feedback_record.is_satisfied,
            'submitted_by_name', v_feedback_record.submitted_by_name,
            'created_at', v_feedback_record.created_at
        )
    );
END;
$$;

-- Deduplicate any existing duplicate history entries keeping only the newest entry per complaint
DELETE FROM public.hostel_complaint_status_history h1
WHERE h1.event_title LIKE 'Requester submitted feedback%'
  AND h1.id NOT IN (
    SELECT DISTINCT ON (complaint_id) id
    FROM public.hostel_complaint_status_history
    WHERE event_title LIKE 'Requester submitted feedback%'
    ORDER BY complaint_id, created_at DESC
  );

