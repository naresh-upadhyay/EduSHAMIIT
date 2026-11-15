-- ============================================================================
-- Migration 470: Enterprise Live Class Join via Code & Guest Join Module
-- Adds tables, constraints, indexes, and stored procedures for:
-- 1. Meeting code validation & previews
-- 2. Recent & saved (starred) meeting codes
-- 3. Guest participants, requests, invitations, and permissions
-- 4. Waiting room guest reviews & real-time admissions
-- 5. Upcoming guest sessions
-- ============================================================================

-- 1. ENHANCE live_classes WITH GUEST ACCESS AND CODE SETTINGS
ALTER TABLE public.live_classes
    ADD COLUMN IF NOT EXISTS allow_guest_access BOOLEAN DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS guest_access_mode VARCHAR(50) DEFAULT 'APPROVAL_REQUIRED',
    ADD COLUMN IF NOT EXISTS guest_email_verification_required BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS guest_max_participants INTEGER DEFAULT 10,
    ADD COLUMN IF NOT EXISTS is_locked BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS code_expires_at TIMESTAMPTZ;

-- 2. CREATE TABLE live_class_recent_codes (FOR RECENT / SAVED MEETING CODES)
CREATE TABLE IF NOT EXISTS public.live_class_recent_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    session_id UUID REFERENCES public.live_classes(id) ON DELETE CASCADE,
    meeting_code VARCHAR(32) NOT NULL,
    class_subject VARCHAR(150) NOT NULL,
    teacher_name VARCHAR(150) NOT NULL,
    is_starred BOOLEAN DEFAULT FALSE,
    last_joined_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_user_meeting_code UNIQUE(user_id, meeting_code)
);

CREATE INDEX IF NOT EXISTS idx_recent_codes_user ON public.live_class_recent_codes(user_id, is_starred, last_joined_at DESC);

-- 3. CREATE TABLE live_class_guest_participants
CREATE TABLE IF NOT EXISTS public.live_class_guest_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES public.live_classes(id) ON DELETE CASCADE,
    guest_reference VARCHAR(64) UNIQUE NOT NULL,
    display_name VARCHAR(150) NOT NULL,
    email VARCHAR(255),
    organization VARCHAR(255),
    designation VARCHAR(150),
    purpose VARCHAR(100) DEFAULT 'Guest Speaker',
    verification_status VARCHAR(50) DEFAULT 'VERIFIED',
    approval_status VARCHAR(50) DEFAULT 'PENDING',
    is_mic_muted BOOLEAN DEFAULT TRUE,
    is_cam_off BOOLEAN DEFAULT FALSE,
    allow_screen_share BOOLEAN DEFAULT FALSE,
    join_with_hand_raised BOOLEAN DEFAULT FALSE,
    first_join_at TIMESTAMPTZ,
    last_leave_at TIMESTAMPTZ,
    total_duration_seconds INTEGER DEFAULT 0,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_guest_participants_session ON public.live_class_guest_participants(session_id, approval_status);
CREATE INDEX IF NOT EXISTS idx_guest_participants_ref ON public.live_class_guest_participants(guest_reference);

-- 4. CREATE TABLE live_class_guest_requests (WAITING ROOM QUEUE)
CREATE TABLE IF NOT EXISTS public.live_class_guest_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES public.live_classes(id) ON DELETE CASCADE,
    guest_id UUID NOT NULL REFERENCES public.live_class_guest_participants(id) ON DELETE CASCADE,
    request_status VARCHAR(50) DEFAULT 'PENDING', -- PENDING, APPROVED, REJECTED, CANCELLED
    requested_at TIMESTAMPTZ DEFAULT NOW(),
    reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    rejection_reason TEXT,
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_guest_requests_sess_status ON public.live_class_guest_requests(session_id, request_status);

-- 5. CREATE TABLE live_class_guest_invitations
CREATE TABLE IF NOT EXISTS public.live_class_guest_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES public.live_classes(id) ON DELETE CASCADE,
    invited_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    guest_name VARCHAR(150),
    guest_email VARCHAR(255),
    organization VARCHAR(255),
    purpose VARCHAR(100) DEFAULT 'Guest Speaker',
    invitation_code VARCHAR(32) NOT NULL,
    invitation_status VARCHAR(50) DEFAULT 'ACTIVE', -- ACTIVE, USED, EXPIRED, REVOKED
    max_uses INTEGER DEFAULT 1,
    used_count INTEGER DEFAULT 0,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_guest_invitations_code ON public.live_class_guest_invitations(invitation_code, invitation_status);

-- 6. STORED PROCEDURE: sp_validate_live_class_code
-- Validates a meeting code, returns status, session info, and host details
CREATE OR REPLACE FUNCTION public.sp_validate_live_class_code(
    p_school_id UUID,
    p_user_id UUID,
    p_code VARCHAR(32)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_code VARCHAR(32);
    v_session RECORD;
    v_teacher RECORD;
    v_class_sec RECORD;
    v_can_join BOOLEAN := FALSE;
    v_waiting_required BOOLEAN := FALSE;
BEGIN
    v_clean_code := UPPER(TRIM(p_code));

    -- Lookup session by room_code or id
    SELECT lc.*
    INTO v_session
    FROM public.live_classes lc
    WHERE lc.school_id = p_school_id
      AND (UPPER(TRIM(lc.room_code)) = v_clean_code OR lc.id::text = p_code)
      AND lc.status != 'cancelled'
    ORDER BY lc.created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'status_code', 'NOT_FOUND',
            'message', 'Meeting code not found or session has been cancelled'
        );
    END IF;

    -- Check if meeting locked
    IF COALESCE(v_session.is_locked, FALSE) THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'status_code', 'LOCKED',
            'message', 'This live class has been locked by the host'
        );
    END IF;

    -- Check meeting status
    IF v_session.status = 'completed' THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'status_code', 'ENDED',
            'message', 'This live class has already ended',
            'session_id', v_session.id
        );
    END IF;

    -- Get Teacher / Host Profile
    SELECT id, full_name, role, avatar_url
    INTO v_teacher
    FROM public.profiles
    WHERE id = v_session.teacher_id;

    -- Get Class & Section Names
    SELECT
        ac.name AS class_name,
        asec.name AS section_name,
        s.name AS subject_name,
        COALESCE(s.icon, '📚') AS subject_icon
    INTO v_class_sec
    FROM public.live_classes lc
    LEFT JOIN public.academic_classes ac ON ac.id = lc.class_id
    LEFT JOIN public.academic_sections asec ON asec.id = lc.section_id
    LEFT JOIN public.subjects s ON s.id = lc.subject_id
    WHERE lc.id = v_session.id;

    -- Determine join eligibility
    IF v_session.status IN ('live', 'scheduled', 'upcoming', 'waiting') THEN
        v_can_join := TRUE;
    END IF;

    IF COALESCE(v_session.waiting_room_enabled, FALSE) AND v_session.teacher_id != p_user_id THEN
        v_waiting_required := TRUE;
    END IF;

    -- Automatically save/update in recent codes table for the authenticated user
    IF p_user_id IS NOT NULL THEN
        INSERT INTO public.live_class_recent_codes (
            user_id,
            session_id,
            meeting_code,
            class_subject,
            teacher_name,
            last_joined_at
        ) VALUES (
            p_user_id,
            v_session.id,
            v_clean_code,
            COALESCE(v_class_sec.class_name || ' - ' || v_class_sec.section_name, v_session.target_class, 'Class 10 - A'),
            COALESCE(v_teacher.full_name, 'R. Kumar (Teacher)'),
            NOW()
        )
        ON CONFLICT (user_id, meeting_code)
        DO UPDATE SET
            session_id = EXCLUDED.session_id,
            class_subject = EXCLUDED.class_subject,
            teacher_name = EXCLUDED.teacher_name,
            last_joined_at = NOW();
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'status_code', 'CAN_JOIN',
        'message', 'Meeting code verified successfully',
        'session', jsonb_build_object(
            'id', v_session.id,
            'title', v_session.title,
            'room_code', v_session.room_code,
            'class_section', COALESCE(v_class_sec.class_name || ' - ' || v_class_sec.section_name, v_session.target_class, 'Class 10 - A'),
            'subject', COALESCE(v_class_sec.subject_name, 'Mathematics'),
            'subject_icon', COALESCE(v_class_sec.subject_icon, '📐'),
            'topic', v_session.title,
            'description', v_session.description,
            'status', v_session.status,
            'is_live', (v_session.status = 'live'),
            'waiting_room_enabled', COALESCE(v_session.waiting_room_enabled, FALSE),
            'waiting_required', v_waiting_required,
            'recording_enabled', COALESCE(v_session.recording_enabled, TRUE),
            'scheduled_date', TO_CHAR(COALESCE(v_session.scheduled_at, NOW()), 'Dy, DD Mon YYYY'),
            'scheduled_time', TO_CHAR(COALESCE(v_session.scheduled_at, NOW()), 'HH12:MI AM') || ' - ' ||
                              TO_CHAR(COALESCE(v_session.scheduled_at, NOW()) + (COALESCE(v_session.duration_minutes, 45) || ' minutes')::interval, 'HH12:MI AM'),
            'duration_minutes', COALESCE(v_session.duration_minutes, 45),
            'meeting_link', COALESCE(v_session.meeting_link, 'https://meet.edushamiit.com/cls/' || LOWER(v_session.room_code)),
            'host_name', COALESCE(v_teacher.full_name, 'R. Kumar (Teacher)'),
            'host_role', COALESCE(v_teacher.role, 'Teacher')
        )
    );
END;
$$;

-- 7. STORED PROCEDURE: sp_get_recent_saved_meeting_codes
CREATE OR REPLACE FUNCTION public.sp_get_recent_saved_meeting_codes(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_items JSONB := '[]'::jsonb;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', rc.id,
                'session_id', rc.session_id,
                'meeting_code', rc.meeting_code,
                'class_subject', rc.class_subject,
                'teacher_name', rc.teacher_name,
                'is_starred', rc.is_starred,
                'last_joined_str', CASE
                    WHEN rc.last_joined_at::date = CURRENT_DATE THEN 'Today, ' || TO_CHAR(rc.last_joined_at, 'HH12:MI AM')
                    WHEN rc.last_joined_at::date = CURRENT_DATE - 1 THEN 'Yesterday, ' || TO_CHAR(rc.last_joined_at, 'HH12:MI AM')
                    ELSE TO_CHAR(rc.last_joined_at, 'DD Mon YYYY, HH12:MI AM')
                END
            ) ORDER BY rc.is_starred DESC, rc.last_joined_at DESC
        ),
        '[]'::jsonb
    )
    INTO v_items
    FROM public.live_class_recent_codes rc
    WHERE rc.user_id = p_user_id
    LIMIT 20;

    RETURN jsonb_build_object(
        'success', TRUE,
        'items', v_items
    );
END;
$$;

-- 8. STORED PROCEDURE: sp_toggle_saved_meeting_code
CREATE OR REPLACE FUNCTION public.sp_toggle_saved_meeting_code(
    p_user_id UUID,
    p_code VARCHAR(32),
    p_is_starred BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.live_class_recent_codes
    SET is_starred = p_is_starred
    WHERE user_id = p_user_id
      AND UPPER(TRIM(meeting_code)) = UPPER(TRIM(p_code));

    RETURN jsonb_build_object(
        'success', TRUE,
        'meeting_code', p_code,
        'is_starred', p_is_starred
    );
END;
$$;

-- 9. STORED PROCEDURE: sp_clear_recent_meeting_codes
CREATE OR REPLACE FUNCTION public.sp_clear_recent_meeting_codes(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Only delete non-starred recent codes
    DELETE FROM public.live_class_recent_codes
    WHERE user_id = p_user_id
      AND is_starred = FALSE;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Cleared recent meeting codes'
    );
END;
$$;

-- 10. STORED PROCEDURE: sp_request_guest_join
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
BEGIN
    v_clean_code := UPPER(TRIM(p_code));
    -- Remove any leading meeting link URL
    IF v_clean_code LIKE '%/C/%' THEN
        v_clean_code := SUBSTRING(v_clean_code FROM '.*/C/(.*)');
    ELSIF v_clean_code LIKE '%/CLS/%' THEN
        v_clean_code := SUBSTRING(v_clean_code FROM '.*/CLS/(.*)');
    END IF;

    -- Lookup live class session
    SELECT lc.*
    INTO v_session
    FROM public.live_classes lc
    WHERE lc.school_id = p_school_id
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

    -- Check if guest access is allowed
    IF NOT COALESCE(v_session.allow_guest_access, TRUE) THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'status_code', 'GUEST_ACCESS_DISABLED',
            'message', 'Guest access is disabled for this session by the institution'
        );
    END IF;

    v_mode := COALESCE(v_session.guest_access_mode, 'APPROVAL_REQUIRED');

    IF v_mode = 'OPEN' THEN
        v_approval_status := 'APPROVED';
    ELSE
        v_approval_status := 'PENDING';
    END IF;

    -- Generate human-friendly guest reference e.g. GST-2025-XXXX
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
        p_school_id,
        v_session.id,
        v_guest_ref,
        TRIM(p_display_name),
        NULLIF(TRIM(p_email), ''),
        NULLIF(TRIM(p_organization), ''),
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
        p_school_id,
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

-- 11. STORED PROCEDURE: sp_get_waiting_room_guests
CREATE OR REPLACE FUNCTION public.sp_get_waiting_room_guests(
    p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_guests JSONB := '[]'::jsonb;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'request_id', gr.id,
                'guest_id', gp.id,
                'guest_reference', gp.guest_reference,
                'display_name', gp.display_name,
                'email', gp.email,
                'organization', gp.organization,
                'purpose', gp.purpose,
                'request_status', gr.request_status,
                'requested_at_str', TO_CHAR(gr.requested_at, 'HH12:MI:SS AM'),
                'is_mic_muted', gp.is_mic_muted,
                'is_cam_off', gp.is_cam_off
            ) ORDER BY gr.requested_at ASC
        ),
        '[]'::jsonb
    )
    INTO v_guests
    FROM public.live_class_guest_requests gr
    JOIN public.live_class_guest_participants gp ON gp.id = gr.guest_id
    WHERE gr.session_id = p_session_id
      AND gr.request_status = 'PENDING';

    RETURN jsonb_build_object(
        'success', TRUE,
        'session_id', p_session_id,
        'waiting_count', jsonb_array_length(v_guests),
        'guests', v_guests
    );
END;
$$;

-- 12. STORED PROCEDURE: sp_review_guest_request
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
        reviewed_by = p_reviewer_id,
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

-- 13. STORED PROCEDURE: sp_get_upcoming_guest_sessions
CREATE OR REPLACE FUNCTION public.sp_get_upcoming_guest_sessions(
    p_school_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sessions JSONB := '[]'::jsonb;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', lc.id,
                'class_subject', COALESCE(ac.name || ' - ' || asec.name, lc.target_class, 'Class 10 - A'),
                'subject_name', COALESCE(s.name, 'General'),
                'topic', lc.title,
                'scheduled_date_str', TO_CHAR(COALESCE(lc.scheduled_at, NOW()), 'Dy, DD Mon YYYY'),
                'scheduled_time_str', TO_CHAR(COALESCE(lc.scheduled_at, NOW()), 'HH12:MI AM') || ' - ' ||
                                      TO_CHAR(COALESCE(lc.scheduled_at, NOW()) + (COALESCE(lc.duration_minutes, 45) || ' minutes')::interval, 'HH12:MI AM'),
                'host_name', COALESCE(p.full_name, 'Teacher'),
                'room_code', lc.room_code,
                'status', lc.status
            ) ORDER BY lc.scheduled_at ASC
        ),
        '[]'::jsonb
    )
    INTO v_sessions
    FROM public.live_classes lc
    LEFT JOIN public.academic_classes ac ON ac.id = lc.class_id
    LEFT JOIN public.academic_sections asec ON asec.id = lc.section_id
    LEFT JOIN public.subjects s ON s.id = lc.subject_id
    LEFT JOIN public.profiles p ON p.id = lc.teacher_id
    WHERE lc.school_id = p_school_id
      AND lc.status != 'cancelled'
      AND (lc.allow_guest_access = TRUE OR lc.title ILIKE '%guest%' OR lc.title ILIKE '%expert%')
    LIMIT 10;

    RETURN jsonb_build_object(
        'success', TRUE,
        'sessions', v_sessions
    );
END;
$$;
