-- ============================================================================
-- Migration 422: Fix Complaints Feedback Average Rating & Star Encoding
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
    v_raw_rating INT := COALESCE((p_payload->>'rating')::INT, 5);
    v_comment TEXT := p_payload->>'comment';
    v_quality INT := (p_payload->>'resolution_quality')::INT;
    v_response_rating INT := (p_payload->>'response_time_rating')::INT;
    v_behavior_rating INT := (p_payload->>'staff_behavior_rating')::INT;
    v_is_satisfied BOOLEAN := COALESCE((p_payload->>'is_satisfied')::BOOLEAN, TRUE);
    v_user_name VARCHAR(150);
    v_existing_history_id UUID;
    v_feedback_record RECORD;
    v_avg_rating NUMERIC(3,1);
    v_rating INT;
BEGIN
    SELECT COALESCE(full_name, 'Student') INTO v_user_name
    FROM public.profiles WHERE id = p_user_id;

    -- Calculate true average rating if sub-ratings are provided
    IF v_quality IS NOT NULL AND v_response_rating IS NOT NULL AND v_behavior_rating IS NOT NULL THEN
        v_avg_rating := ROUND((v_quality + v_response_rating + v_behavior_rating)::NUMERIC / 3.0, 1);
        v_rating := ROUND(v_avg_rating)::INT;
    ELSIF v_quality IS NOT NULL OR v_response_rating IS NOT NULL OR v_behavior_rating IS NOT NULL THEN
        v_avg_rating := ROUND((
            COALESCE(v_quality, v_raw_rating) + 
            COALESCE(v_response_rating, v_raw_rating) + 
            COALESCE(v_behavior_rating, v_raw_rating)
        )::NUMERIC / 3.0, 1);
        v_rating := ROUND(v_avg_rating)::INT;
    ELSE
        v_avg_rating := v_raw_rating::NUMERIC;
        v_rating := v_raw_rating;
    END IF;

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
      AND (event_title LIKE 'Requester submitted feedback%' OR event_title LIKE '%???%')
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_existing_history_id IS NOT NULL THEN
        -- Use CHR(9733) for Unicode star ★ to guarantee encoding safety across all clients
        UPDATE public.hostel_complaint_status_history
        SET event_title = 'Requester submitted feedback (' || TO_CHAR(v_avg_rating, 'FM9.0') || ' ' || CHR(9733) || ')',
            action_note = COALESCE(v_comment, 'Service rated by resident.'),
            created_at = NOW()
        WHERE id = v_existing_history_id;
    ELSE
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
            'Requester submitted feedback (' || TO_CHAR(v_avg_rating, 'FM9.0') || ' ' || CHR(9733) || ')',
            COALESCE(v_comment, 'Service rated by resident.')
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Feedback received. Thank you!',
        'feedback', jsonb_build_object(
            'id', v_feedback_record.id,
            'rating', v_feedback_record.rating,
            'average_rating', v_avg_rating,
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

-- Fix any legacy ??? in status history
UPDATE public.hostel_complaint_status_history
SET event_title = 'Requester submitted feedback (' || 
    CASE 
        WHEN f.resolution_quality IS NOT NULL AND f.response_time_rating IS NOT NULL AND f.staff_behavior_rating IS NOT NULL 
        THEN TO_CHAR(ROUND((f.resolution_quality + f.response_time_rating + f.staff_behavior_rating)::NUMERIC / 3.0, 1), 'FM9.0')
        ELSE f.rating::TEXT
    END || ' ' || CHR(9733) || ')'
FROM public.hostel_complaint_feedback f
WHERE hostel_complaint_status_history.complaint_id = f.complaint_id
  AND (hostel_complaint_status_history.event_title LIKE 'Requester submitted feedback%' 
       OR hostel_complaint_status_history.event_title LIKE '%???%');

CREATE OR REPLACE FUNCTION public.fn_hostel_complaints_get_by_id(p_school_id uuid, p_complaint_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $$
DECLARE
    v_complaint RECORD;
    v_comments JSONB := '[]'::JSONB;
    v_assignments JSONB := '[]'::JSONB;
    v_history JSONB := '[]'::JSONB;
    v_feedback JSONB := NULL;
    v_related_asset JSONB := NULL;
    v_sla_display TEXT;
BEGIN
    SELECT * INTO v_complaint
    FROM public.hostel_complaints
    WHERE id = p_complaint_id
      AND school_id = p_school_id
      AND deleted_at IS NULL;

    IF v_complaint.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Complaint not found or access denied');
    END IF;

    -- Calculate SLA string
    IF v_complaint.status IN ('RESOLVED', 'COMPLETED') THEN
        v_sla_display := 'Resolved';
    ELSIF v_complaint.resolution_due_at IS NULL THEN
        v_sla_display := 'No SLA';
    ELSIF v_complaint.resolution_due_at < NOW() THEN
        v_sla_display := CONCAT('Overdue by ',
                                EXTRACT(DAY FROM (NOW() - v_complaint.resolution_due_at))::INT, 'd ',
                                EXTRACT(HOUR FROM (NOW() - v_complaint.resolution_due_at))::INT, 'h');
    ELSE
        v_sla_display := CONCAT(EXTRACT(HOUR FROM (v_complaint.resolution_due_at - NOW()))::INT, 'h remaining');
    END IF;

    -- Get Comments
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', c.id,
            'author_user_id', c.author_user_id,
            'author_name', c.author_name,
            'author_role', c.author_role,
            'author_avatar', c.author_avatar,
            'comment_type', c.comment_type,
            'message', c.message,
            'attachments', c.attachments,
            'created_at', c.created_at
        ) ORDER BY c.created_at ASC
    ), '[]'::JSONB) INTO v_comments
    FROM public.hostel_complaint_comments c
    WHERE c.complaint_id = p_complaint_id
      AND c.deleted_at IS NULL;

    -- Get Assignments History
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', a.id,
            'assigned_user_id', a.assigned_user_id,
            'assigned_user_name', a.assigned_user_name,
            'assigned_user_role', a.assigned_user_role,
            'assignment_type', a.assignment_type,
            'assigned_by_name', a.assigned_by_name,
            'notes', a.notes,
            'status', a.status,
            'assigned_at', a.assigned_at
        ) ORDER BY a.assigned_at DESC
    ), '[]'::JSONB) INTO v_assignments
    FROM public.hostel_complaint_assignments a
    WHERE a.complaint_id = p_complaint_id;

    -- Get Audit / Status History
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', h.id,
            'actor_name', h.actor_name,
            'actor_role', h.actor_role,
            'from_status', h.from_status,
            'to_status', h.to_status,
            'event_title', h.event_title,
            'action_note', h.action_note,
            'metadata', h.metadata,
            'created_at', h.created_at
        ) ORDER BY h.created_at ASC
    ), '[]'::JSONB) INTO v_history
    FROM public.hostel_complaint_status_history h
    WHERE h.complaint_id = p_complaint_id;

    -- Feedback info with true average_rating
    SELECT jsonb_build_object(
        'id', f.id,
        'submitted_by_name', f.submitted_by_name,
        'rating', f.rating,
        'average_rating', CASE 
            WHEN f.resolution_quality IS NOT NULL AND f.response_time_rating IS NOT NULL AND f.staff_behavior_rating IS NOT NULL 
            THEN ROUND((f.resolution_quality + f.response_time_rating + f.staff_behavior_rating)::NUMERIC / 3.0, 1)
            ELSE f.rating::NUMERIC
        END,
        'resolution_quality', f.resolution_quality,
        'response_time_rating', f.response_time_rating,
        'staff_behavior_rating', f.staff_behavior_rating,
        'comment', f.comment,
        'is_satisfied', f.is_satisfied,
        'created_at', f.created_at
    ) INTO v_feedback
    FROM public.hostel_complaint_feedback f
    WHERE f.complaint_id = p_complaint_id;

    -- Build Asset Info if room exists
    IF v_complaint.room_id IS NOT NULL THEN
        SELECT jsonb_build_object(
            'room_id', r.id,
            'room_number', r.room_number,
            'room_type', r.room_type,
            'operational_status', r.operational_status,
            'cleanliness_status', r.cleanliness_status,
            'condition_status', r.condition_status
        ) INTO v_related_asset
        FROM public.hostel_rooms r
        WHERE r.id = v_complaint.room_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'complaint', to_jsonb(v_complaint) || jsonb_build_object('sla_display', v_sla_display),
        'comments', COALESCE(v_comments, '[]'::JSONB),
        'assignments', COALESCE(v_assignments, '[]'::JSONB),
        'history', COALESCE(v_history, '[]'::JSONB),
        'feedback', v_feedback,
        'related_asset', v_related_asset
    );
END;
$$;
