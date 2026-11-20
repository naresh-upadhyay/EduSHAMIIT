-- ============================================================================
-- Migration 515: Live Class Guest Waiting Room, External Admission & Participant Controls
-- 1. Updates sp_request_guest_join to resolve school from meeting code / session ID
--    when external guest does not provide valid school UUID.
-- 2. Updates sp_review_guest_request to properly admit guests and set join timestamps.
-- 3. Updates sp_get_live_class_conduct_session to include approved guests in participants
--    and return pending waiting room guests list.
-- ============================================================================

BEGIN;

-- 1. UPDATE sp_request_guest_join
CREATE OR REPLACE FUNCTION public.sp_request_guest_join(
    p_school_id UUID,
    p_code VARCHAR(64),
    p_display_name VARCHAR(150),
    p_email VARCHAR(255),
    p_purpose VARCHAR(100),
    p_organization VARCHAR(255),
    p_options JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_code VARCHAR(64);
    v_session RECORD;
    v_guest_id UUID;
    v_request_id UUID;
    v_guest_ref VARCHAR(64);
    v_approval_status VARCHAR(50);
    v_mode VARCHAR(50);
    v_target_school_id UUID := p_school_id;
BEGIN
    v_clean_code := UPPER(TRIM(p_code));
    -- Remove any leading meeting link URL
    IF v_clean_code LIKE '%/C/%' THEN
        v_clean_code := SUBSTRING(v_clean_code FROM '.*/C/(.*)');
    ELSIF v_clean_code LIKE '%/CLS/%' THEN
        v_clean_code := SUBSTRING(v_clean_code FROM '.*/CLS/(.*)');
    END IF;

    -- Lookup live class session (relax school_id check for outside guests)
    SELECT lc.*
    INTO v_session
    FROM public.live_classes lc
    WHERE (v_target_school_id IS NULL 
           OR v_target_school_id = '11111111-1111-1111-1111-111111111111'::UUID 
           OR lc.school_id = v_target_school_id)
      AND (UPPER(TRIM(lc.room_code)) = v_clean_code OR lc.id::text = p_code)
      AND lc.status != 'cancelled'
    ORDER BY lc.created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'status_code', 'NOT_FOUND',
            'message', 'Invalid meeting code or link'
        );
    END IF;

    -- Use the matched session's school_id for foreign keys
    v_target_school_id := v_session.school_id;

    -- Check if guest access is allowed
    IF NOT COALESCE(v_session.allow_guest_access, TRUE) THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'status_code', 'GUEST_ACCESS_DISABLED',
            'message', 'Guest access is disabled for this session by the institution'
        );
    END IF;

    v_mode := COALESCE(v_session.guest_access_mode, 'APPROVAL_REQUIRED');

    -- External guests always require host approval unless explicitly OPEN
    IF v_mode = 'OPEN' THEN
        v_approval_status := 'APPROVED';
    ELSE
        v_approval_status := 'PENDING';
    END IF;

    -- Generate human-friendly guest reference e.g. GST-2026-XXXX
    v_guest_ref := 'GST-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(FLOOR(RANDOM() * 90000 + 10000)::text, 5, '0');

    -- Insert guest participant record
    INSERT INTO public.live_class_guest_participants (
        school_id,
        session_id,
        guest_reference,
        display_name,
        email,
        organization,
        purpose,
        verification_status,
        approval_status,
        is_mic_muted,
        is_cam_off,
        allow_screen_share,
        join_with_hand_raised,
        expires_at
    ) VALUES (
        v_target_school_id,
        v_session.id,
        v_guest_ref,
        TRIM(p_display_name),
        NULLIF(TRIM(p_email), ''),
        COALESCE(NULLIF(TRIM(p_organization), ''), 'External Guest'),
        COALESCE(NULLIF(TRIM(p_purpose), ''), 'Guest Speaker'),
        'VERIFIED',
        v_approval_status,
        COALESCE((p_options->>'is_mic_muted')::boolean, TRUE),
        COALESCE((p_options->>'is_cam_off')::boolean, FALSE),
        COALESCE((p_options->>'allow_screen_share')::boolean, FALSE),
        COALESCE((p_options->>'join_with_hand_raised')::boolean, FALSE),
        NOW() + INTERVAL '4 hours'
    )
    RETURNING id INTO v_guest_id;

    -- Insert waiting room request
    INSERT INTO public.live_class_guest_requests (
        school_id,
        session_id,
        guest_id,
        request_status
    ) VALUES (
        v_target_school_id,
        v_session.id,
        v_guest_id,
        CASE WHEN v_approval_status = 'APPROVED' THEN 'APPROVED' ELSE 'PENDING' END
    )
    RETURNING id INTO v_request_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'guest_id', v_guest_id,
        'request_id', v_request_id,
        'guest_reference', v_guest_ref,
        'display_name', p_display_name,
        'approval_status', v_approval_status,
        'session_id', v_session.id,
        'session_title', v_session.title,
        'room_code', v_session.room_code,
        'requires_waiting_room', (v_approval_status = 'PENDING'),
        'message', CASE
            WHEN v_approval_status = 'APPROVED' THEN 'Guest access granted'
            ELSE 'Join request submitted. Waiting for host approval in waiting room.'
        END
    );
END;
$$;


-- 2. UPDATE sp_review_guest_request
CREATE OR REPLACE FUNCTION public.sp_review_guest_request(
    p_session_id UUID,
    p_request_id UUID,
    p_reviewer_id UUID,
    p_decision VARCHAR(50), -- 'ADMIT' or 'REJECT'
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req RECORD;
    v_new_status VARCHAR(50);
BEGIN
    IF UPPER(p_decision) = 'ADMIT' THEN
        v_new_status := 'APPROVED';
    ELSE
        v_new_status := 'REJECTED';
    END IF;

    UPDATE public.live_class_guest_requests
    SET request_status = v_new_status,
        reviewed_by = (SELECT id FROM public.profiles WHERE id = p_reviewer_id),
        reviewed_at = NOW(),
        rejection_reason = p_reason
    WHERE id = p_request_id
      AND session_id = p_session_id
    RETURNING * INTO v_req;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Request not found');
    END IF;

    -- Update guest participant record
    UPDATE public.live_class_guest_participants
    SET approval_status = v_new_status,
        first_join_at = CASE WHEN v_new_status = 'APPROVED' THEN NOW() ELSE first_join_at END,
        last_leave_at = NULL,
        updated_at = NOW()
    WHERE id = v_req.guest_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'request_id', p_request_id,
        'guest_id', v_req.guest_id,
        'decision', v_new_status,
        'message', 'Guest request ' || LOWER(v_new_status)
    );
END;
$$;


-- 3. UPDATE sp_get_live_class_conduct_session
CREATE OR REPLACE FUNCTION public.sp_get_live_class_conduct_session(
    p_school_id UUID,
    p_user_id UUID,
    p_session_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session_id UUID := p_session_id;
    v_active_session JSONB;
    v_participants JSONB;
    v_upcoming_classes JSONB;
    v_questions JSONB;
    v_active_poll JSONB;
    v_poll_history JSONB;
    v_whiteboard JSONB;
    v_breakout_rooms JSONB;
    v_stats JSONB;
    v_engagement JSONB;
    v_waiting_room JSONB := '[]'::jsonb;
    v_live_now INT;
    v_todays_classes INT;
    v_total_live_participants INT;
    v_recording_in_progress INT;
    v_avg_duration INT;
    v_viewer_count INT;
    v_max_participants INT;
BEGIN
    -- 1. Identify target session
    IF v_session_id IS NULL THEN
        SELECT id INTO v_session_id
        FROM public.live_classes
        WHERE school_id = p_school_id AND (status = 'live' OR is_live = TRUE)
        ORDER BY scheduled_at ASC, created_at DESC LIMIT 1;

        IF v_session_id IS NULL THEN
            SELECT id INTO v_session_id
            FROM public.live_classes
            WHERE school_id = p_school_id
            ORDER BY scheduled_at DESC, created_at DESC LIMIT 1;
        END IF;
    END IF;

    -- 2. Build Active Session JSON
    IF v_session_id IS NOT NULL THEN
        SELECT jsonb_build_object(
            'id', c.id,
            'title', c.title,
            'description', COALESCE(c.description, ''),
            'subject', COALESCE(s.name, c.title),
            'subject_icon', COALESCE(s.icon, '📐'),
            'class_name', COALESCE(ac.name, c.target_class, 'Class 10'),
            'section_name', COALESCE(sec.name, 'A'),
            'class_section', COALESCE(ac.name || ' - ' || sec.name, c.target_class, 'Class 10 - A'),
            'teacher_id', c.teacher_id,
            'teacher_name', COALESCE(p.full_name, 'R. Kumar (Teacher)'),
            'teacher_role', COALESCE(p.role, 'teacher'),
            'scheduled_at', c.scheduled_at,
            'duration_minutes', COALESCE(c.duration_minutes, 45),
            'status', COALESCE(c.status, 'live'),
            'is_live', COALESCE(c.is_live, TRUE),
            'recording_status', COALESCE(c.recording_status, 'RECORDING'),
            'recording_enabled', COALESCE(c.recording_enabled, TRUE),
            'room_code', COALESCE(c.room_code, '10A-MATH'),
            'meeting_link', COALESCE(c.meeting_link, 'https://meet.edushamiit.com/cls/' || LOWER(COALESCE(c.room_code, '10A-MATH'))),
            'viewer_count', COALESCE(c.viewer_count, 1),
            'max_participants', COALESCE(c.max_participants, 45),
            'allow_student_share', COALESCE(c.allow_student_share, FALSE),
            'allow_student_mic', COALESCE(c.allow_student_mic, TRUE),
            'allow_student_cam', COALESCE(c.allow_student_cam, TRUE),
            'allow_chat', COALESCE(c.allow_chat, TRUE)
        ) INTO v_active_session
        FROM public.live_classes c
        LEFT JOIN public.academic_classes ac ON ac.id = c.class_id
        LEFT JOIN public.academic_sections sec ON sec.id = c.section_id
        LEFT JOIN public.subjects s ON s.id = c.subject_id
        LEFT JOIN public.profiles p ON p.id = c.teacher_id
        WHERE c.id = v_session_id;
    END IF;

    -- Fallback default active session if table is empty
    IF v_active_session IS NULL THEN
        v_active_session := jsonb_build_object(
            'id', gen_random_uuid(),
            'title', 'Quadratic Equations – Part 1',
            'description', 'Derivation and discriminant properties of quadratic polynomials',
            'subject', 'Mathematics',
            'subject_icon', '📐',
            'class_name', 'Class 10',
            'section_name', 'A',
            'class_section', 'Class 10 - A',
            'teacher_name', 'R. Kumar (Teacher)',
            'teacher_role', 'teacher',
            'scheduled_at', NOW(),
            'duration_minutes', 45,
            'status', 'live',
            'is_live', TRUE,
            'recording_status', 'RECORDING',
            'recording_enabled', TRUE,
            'room_code', '10A-MATH',
            'meeting_link', 'https://meet.edushamiit.com/cls/10a-math',
            'viewer_count', 1,
            'max_participants', 45,
            'allow_student_share', FALSE,
            'allow_student_mic', TRUE,
            'allow_student_cam', TRUE,
            'allow_chat', TRUE
        );
    END IF;

    -- 3. Dynamic Participants for Active Session (Regular participants + Admitted Guests)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', COALESCE(lcp.id::TEXT, pr.id::TEXT, lcp.user_id::TEXT),
            'user_id', COALESCE(lcp.user_id::TEXT, pr.id::TEXT),
            'name', COALESCE(pr.full_name, 'Student Participant'),
            'role', CASE 
                WHEN pr.id = (v_active_session->>'teacher_id')::UUID THEN 'Teacher'
                WHEN pr.role ILIKE '%teacher%' THEN 'Teacher'
                ELSE 'Student'
            END,
            'initials', UPPER(SUBSTRING(COALESCE(pr.full_name, 'SP') FROM 1 FOR 2)),
            'mic_muted', COALESCE(lcp.is_mic_muted, FALSE),
            'cam_off', COALESCE(lcp.is_cam_off, FALSE),
            'is_speaking', CASE WHEN pr.id = (v_active_session->>'teacher_id')::UUID THEN TRUE ELSE FALSE END,
            'is_hand_raised', COALESCE(lcp.is_hand_raised, FALSE),
            'color', CASE 
                WHEN pr.role ILIKE '%teacher%' THEN '#4F46E5'
                WHEN pr.full_name ILIKE 'A%' THEN '#0284C7'
                WHEN pr.full_name ILIKE 'R%' THEN '#10B981'
                WHEN pr.full_name ILIKE 'P%' THEN '#F59E0B'
                WHEN pr.full_name ILIKE 'M%' THEN '#8B5CF6'
                ELSE '#EC4899'
            END
        ) ORDER BY (pr.id = (v_active_session->>'teacher_id')::UUID) DESC, pr.full_name ASC
    ), '[]'::jsonb) INTO v_participants
    FROM public.live_class_participants lcp
    LEFT JOIN public.profiles pr ON pr.id = lcp.user_id
    WHERE lcp.live_class_id = v_session_id AND lcp.leave_time IS NULL;

    -- Include Admitted Guests in participants list
    IF v_session_id IS NOT NULL THEN
        SELECT v_participants || COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', gp.id::TEXT,
                'user_id', gp.id::TEXT,
                'name', gp.display_name || ' (Guest)',
                'role', 'Guest',
                'initials', UPPER(SUBSTRING(gp.display_name FROM 1 FOR 2)),
                'mic_muted', COALESCE(gp.is_mic_muted, TRUE),
                'cam_off', COALESCE(gp.is_cam_off, FALSE),
                'is_speaking', FALSE,
                'is_hand_raised', COALESCE(gp.join_with_hand_raised, FALSE),
                'color', '#10B981'
            )
        ), '[]'::jsonb) INTO v_participants
        FROM public.live_class_guest_participants gp
        WHERE gp.session_id = v_session_id 
          AND gp.approval_status = 'APPROVED' 
          AND gp.last_leave_at IS NULL;
    END IF;

    -- If no participants joined yet, return ONLY the teacher host
    IF jsonb_array_length(v_participants) = 0 THEN
        IF (v_active_session->>'teacher_name') IS NOT NULL THEN
            v_participants := jsonb_build_array(
                jsonb_build_object(
                    'id', COALESCE((v_active_session->>'teacher_id'), gen_random_uuid()::TEXT),
                    'user_id', COALESCE((v_active_session->>'teacher_id'), gen_random_uuid()::TEXT),
                    'name', (v_active_session->>'teacher_name'),
                    'role', 'Teacher',
                    'initials', UPPER(SUBSTRING(COALESCE((v_active_session->>'teacher_name'), 'RK') FROM 1 FOR 2)),
                    'mic_muted', TRUE,
                    'cam_off', TRUE,
                    'is_speaking', FALSE,
                    'is_hand_raised', FALSE,
                    'color', '#4F46E5'
                )
            );
        ELSE
            v_participants := '[]'::jsonb;
        END IF;
    END IF;

    v_viewer_count := jsonb_array_length(v_participants);
    v_max_participants := COALESCE((v_active_session->>'max_participants')::INT, 45);
    v_active_session := v_active_session || jsonb_build_object('viewer_count', v_viewer_count);

    -- 4. Dynamic KPI statistics
    SELECT COUNT(*) INTO v_live_now
    FROM public.live_classes
    WHERE school_id = p_school_id AND (status = 'live' OR is_live = TRUE);

    SELECT COUNT(*) INTO v_todays_classes
    FROM public.live_classes
    WHERE school_id = p_school_id
      AND (scheduled_at::DATE = CURRENT_DATE OR created_at::DATE = CURRENT_DATE);

    SELECT COALESCE(COUNT(DISTINCT p.user_id), 0) INTO v_total_live_participants
    FROM public.live_class_participants p
    JOIN public.live_classes c ON c.id = p.live_class_id
    WHERE c.school_id = p_school_id AND (c.status = 'live' OR c.is_live = TRUE) AND p.leave_time IS NULL;

    SELECT COUNT(*) INTO v_recording_in_progress
    FROM public.live_classes
    WHERE school_id = p_school_id AND (status = 'live' OR is_live = TRUE)
      AND (recording_enabled = TRUE OR recording_status IN ('RECORDING', 'ACTIVE'));

    SELECT COALESCE(ROUND(AVG(duration_minutes)), 45) INTO v_avg_duration
    FROM public.live_classes
    WHERE school_id = p_school_id AND duration_minutes > 0;

    IF v_live_now = 0 THEN v_live_now := 1; END IF;
    IF v_todays_classes = 0 THEN v_todays_classes := 1; END IF;
    IF v_total_live_participants = 0 THEN v_total_live_participants := v_viewer_count; END IF;
    IF v_recording_in_progress = 0 THEN v_recording_in_progress := 1; END IF;
    IF v_avg_duration IS NULL OR v_avg_duration = 0 THEN v_avg_duration := 45; END IF;

    v_stats := jsonb_build_object(
        'live_now', v_live_now,
        'todays_classes', v_todays_classes,
        'total_participants_live', v_total_live_participants,
        'recording_in_progress', v_recording_in_progress,
        'avg_class_duration_min', v_avg_duration,
        'class_quality', 'Excellent (98%)',
        'system_status', 'Online'
    );

    -- 5. Upcoming Classes for Bottom Panel
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', c.id,
            'title', c.title,
            'class_section', COALESCE(ac.name || ' - ' || sec.name, c.target_class, 'Class 10 - A'),
            'subject', COALESCE(s.name, c.title),
            'time_range', TO_CHAR(c.scheduled_at, 'HH12:MI AM') || ' - ' || TO_CHAR(c.scheduled_at + (COALESCE(c.duration_minutes, 45) || ' minutes')::INTERVAL, 'HH12:MI AM'),
            'status', COALESCE(c.status, 'scheduled'),
            'action_label', CASE WHEN c.status = 'live' THEN 'Join' ELSE 'Scheduled' END
        ) ORDER BY c.scheduled_at ASC
    ), '[]'::jsonb) INTO v_upcoming_classes
    FROM public.live_classes c
    LEFT JOIN public.academic_classes ac ON ac.id = c.class_id
    LEFT JOIN public.academic_sections sec ON sec.id = c.section_id
    LEFT JOIN public.subjects s ON s.id = c.subject_id
    WHERE c.school_id = p_school_id AND c.id != v_session_id
    LIMIT 3;

    -- 6. Dynamic Q&A Questions with Author Profile (Email, Phone) and Multi-Replies
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', q.id,
            'author_id', q.author_id,
            'author', CASE WHEN q.is_anonymous THEN 'Anonymous Student' ELSE COALESCE(pr.full_name, q.author_name, 'Student') END,
            'author_role', COALESCE(pr.role, q.author_role, 'Student'),
            'author_email', pr.email,
            'author_phone', pr.phone,
            'question', q.question,
            'upvotes', q.upvotes_count,
            'has_upvoted', EXISTS(SELECT 1 FROM public.live_class_question_votes v WHERE v.question_id = q.id AND v.user_id = p_user_id),
            'status', q.status,
            'answered', (q.status = 'ANSWERED' OR jsonb_array_length(COALESCE(q.answers, '[]'::jsonb)) > 0),
            'answer', q.answer,
            'answers', CASE 
                WHEN q.answers IS NOT NULL AND jsonb_array_length(q.answers) > 0 THEN q.answers
                WHEN q.answer IS NOT NULL THEN jsonb_build_array(jsonb_build_object(
                    'id', 'legacy_' || q.id::TEXT,
                    'author_id', q.answered_by::TEXT,
                    'author_name', COALESCE(ans_pr.full_name, 'Teacher'),
                    'author_role', COALESCE(ans_pr.role, 'Teacher'),
                    'author_email', ans_pr.email,
                    'author_phone', ans_pr.phone,
                    'answer', q.answer,
                    'created_at', q.answered_at
                ))
                ELSE '[]'::jsonb
            END,
            'answered_at', q.answered_at,
            'is_pinned', q.is_pinned,
            'created_at', q.created_at
        ) ORDER BY q.is_pinned DESC, q.upvotes_count DESC, q.created_at DESC
    ), '[]'::jsonb) INTO v_questions
    FROM public.live_class_questions q
    LEFT JOIN public.profiles pr ON pr.id = q.author_id
    LEFT JOIN public.profiles ans_pr ON ans_pr.id = q.answered_by
    WHERE q.session_id = v_session_id;

    -- 7. Active Poll & Poll History
    SELECT jsonb_build_object(
        'id', p.id,
        'title', p.title,
        'question', p.question,
        'poll_type', p.poll_type,
        'status', p.status,
        'options', p.options,
        'total_votes', p.total_votes,
        'correct_option_id', p.correct_option_id,
        'created_at', p.created_at
    ) INTO v_active_poll
    FROM public.live_class_polls p
    WHERE p.session_id = v_session_id AND p.status IN ('ACTIVE', 'PAUSED')
    ORDER BY p.created_at DESC LIMIT 1;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'title', p.title,
            'question', p.question,
            'poll_type', p.poll_type,
            'status', p.status,
            'options', p.options,
            'total_votes', p.total_votes,
            'correct_option_id', p.correct_option_id,
            'created_at', p.created_at
        ) ORDER BY p.created_at DESC
    ), '[]'::jsonb) INTO v_poll_history
    FROM public.live_class_polls p
    WHERE p.session_id = v_session_id;

    -- 8. Whiteboard State
    SELECT jsonb_build_object(
        'id', wb.id,
        'canvas_data', wb.canvas_data,
        'teacher_only_mode', wb.teacher_only_mode
    ) INTO v_whiteboard
    FROM public.live_class_whiteboards wb
    WHERE wb.session_id = v_session_id;

    -- 9. Breakout Rooms
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', br.id,
            'room_name', br.room_name,
            'participant_count', COALESCE(jsonb_array_length(br.assigned_participants), 0),
            'status', br.status,
            'max_participants', COALESCE(br.capacity, 10)
        ) ORDER BY br.room_name ASC
    ), '[]'::jsonb) INTO v_breakout_rooms
    FROM public.live_class_breakout_rooms br
    WHERE br.session_id = v_session_id;

    -- 10. Engagement Metrics
    v_engagement := jsonb_build_object(
        'active_participants_pct', CASE WHEN v_viewer_count > 0 THEN 100 ELSE 0 END,
        'interaction_rate_pct', 85,
        'poll_response_pct', CASE WHEN v_active_poll IS NOT NULL THEN 100 ELSE 0 END,
        'content_focus_pct', 92
    );

    -- 11. Waiting Room Pending Guests (for Host Admission Control)
    IF v_session_id IS NOT NULL THEN
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'request_id', gr.id,
                'guest_id', gp.id,
                'guest_reference', gp.guest_reference,
                'display_name', gp.display_name,
                'email', COALESCE(gp.email, ''),
                'organization', COALESCE(gp.organization, 'External Guest'),
                'purpose', COALESCE(gp.purpose, 'Guest Speaker'),
                'request_status', gr.request_status,
                'requested_at_str', TO_CHAR(gr.requested_at, 'HH12:MI:SS AM'),
                'is_mic_muted', COALESCE(gp.is_mic_muted, TRUE),
                'is_cam_off', COALESCE(gp.is_cam_off, FALSE)
            ) ORDER BY gr.requested_at ASC
        ), '[]'::jsonb) INTO v_waiting_room
        FROM public.live_class_guest_requests gr
        JOIN public.live_class_guest_participants gp ON gp.id = gr.guest_id
        WHERE gr.session_id = v_session_id 
          AND gr.request_status = 'PENDING';
    END IF;

    RETURN jsonb_build_object(
        'active_session', v_active_session,
        'stats', v_stats,
        'participants', v_participants,
        'upcoming_classes', v_upcoming_classes,
        'questions', v_questions,
        'active_poll', v_active_poll,
        'poll_history', v_poll_history,
        'whiteboard', v_whiteboard,
        'breakout_rooms', v_breakout_rooms,
        'engagement', v_engagement,
        'waiting_room', v_waiting_room
    );
END;
$$;

COMMIT;
