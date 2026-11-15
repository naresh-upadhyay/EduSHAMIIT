-- ============================================================================
-- Migration 510: Enterprise Live Class Management Full Features & Gaps Closure
-- Includes:
-- 1. Lookup values for LIVE_CLASS_STATUS, RECORDING_VISIBILITY, ATTENDANCE_OVERRIDE_REASON, ACADEMIC_YEAR
-- 2. Breakout rooms & participants schema
-- 3. Stored procedures for enrolled students, breakout rooms, settings, and filtered listings
-- ============================================================================

-- 1. ENSURE LOOKUP KEYS & VALUES EXIST
DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_key_id UUID;
BEGIN
    -- A. ACADEMIC_YEAR lookup key
    IF NOT EXISTS (SELECT 1 FROM public.lookup_keys WHERE key_code = 'ACADEMIC_YEAR') THEN
        INSERT INTO public.lookup_keys (id, school_id, key_code, key_name, description, status)
        VALUES (gen_random_uuid(), v_school_id, 'ACADEMIC_YEAR', 'Academic Session Year', 'Academic session financial years', 'ACTIVE')
        RETURNING id INTO v_key_id;
    ELSE
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE key_code = 'ACADEMIC_YEAR' LIMIT 1;
    END IF;

    -- Values for ACADEMIC_YEAR
    INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_code, value_name, sort_order, status)
    VALUES
        (gen_random_uuid(), v_key_id, v_school_id, 'AY_2024_25', '2024 - 2025', 1, 'ACTIVE'),
        (gen_random_uuid(), v_key_id, v_school_id, 'AY_2025_26', '2025 - 2026', 2, 'ACTIVE'),
        (gen_random_uuid(), v_key_id, v_school_id, 'AY_2026_27', '2026 - 2027', 3, 'ACTIVE'),
        (gen_random_uuid(), v_key_id, v_school_id, 'AY_2027_28', '2027 - 2028', 4, 'ACTIVE')
    ON CONFLICT DO NOTHING;

    -- B. LIVE_CLASS_STATUS lookup key
    IF NOT EXISTS (SELECT 1 FROM public.lookup_keys WHERE key_code = 'LIVE_CLASS_STATUS') THEN
        INSERT INTO public.lookup_keys (id, school_id, key_code, key_name, description, status)
        VALUES (gen_random_uuid(), v_school_id, 'LIVE_CLASS_STATUS', 'Live Class Status', 'Status lifecycle for live classes', 'ACTIVE')
        RETURNING id INTO v_key_id;
    ELSE
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE key_code = 'LIVE_CLASS_STATUS' LIMIT 1;
    END IF;

    -- Values for LIVE_CLASS_STATUS
    INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_code, value_name, sort_order, status)
    VALUES
        (gen_random_uuid(), v_key_id, v_school_id, 'ALL', 'All', 0, 'ACTIVE'),
        (gen_random_uuid(), v_key_id, v_school_id, 'LIVE', 'Live', 1, 'ACTIVE'),
        (gen_random_uuid(), v_key_id, v_school_id, 'UPCOMING', 'Upcoming', 2, 'ACTIVE'),
        (gen_random_uuid(), v_key_id, v_school_id, 'COMPLETED', 'Completed', 3, 'ACTIVE'),
        (gen_random_uuid(), v_key_id, v_school_id, 'SCHEDULED', 'Scheduled', 4, 'ACTIVE'),
        (gen_random_uuid(), v_key_id, v_school_id, 'CANCELLED', 'Cancelled', 5, 'ACTIVE'),
        (gen_random_uuid(), v_key_id, v_school_id, 'POSTPONED', 'Postponed', 6, 'ACTIVE')
    ON CONFLICT DO NOTHING;

    -- C. RECORDING_VISIBILITY lookup key
    IF NOT EXISTS (SELECT 1 FROM public.lookup_keys WHERE key_code = 'RECORDING_VISIBILITY') THEN
        INSERT INTO public.lookup_keys (id, school_id, key_code, key_name, description, status)
        VALUES (gen_random_uuid(), v_school_id, 'RECORDING_VISIBILITY', 'Recording Visibility', 'Access permissions for recorded classes', 'ACTIVE')
        RETURNING id INTO v_key_id;
    ELSE
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE key_code = 'RECORDING_VISIBILITY' LIMIT 1;
    END IF;

    -- Values for RECORDING_VISIBILITY
    INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_code, value_name, sort_order, status)
    VALUES
        (gen_random_uuid(), v_key_id, v_school_id, 'ALL', 'All', 0, 'ACTIVE'),
        (gen_random_uuid(), v_key_id, v_school_id, 'CLASS_ONLY', 'Class Only', 1, 'ACTIVE'),
        (gen_random_uuid(), v_key_id, v_school_id, 'PUBLIC', 'Public', 2, 'ACTIVE'),
        (gen_random_uuid(), v_key_id, v_school_id, 'PRIVATE', 'Private', 3, 'ACTIVE'),
        (gen_random_uuid(), v_key_id, v_school_id, 'RESTRICTED', 'Restricted', 4, 'ACTIVE')
    ON CONFLICT DO NOTHING;

    -- D. ATTENDANCE_OVERRIDE_REASON lookup key
    IF NOT EXISTS (SELECT 1 FROM public.lookup_keys WHERE key_code = 'ATTENDANCE_OVERRIDE_REASON') THEN
        INSERT INTO public.lookup_keys (id, school_id, key_code, key_name, description, status)
        VALUES (gen_random_uuid(), v_school_id, 'ATTENDANCE_OVERRIDE_REASON', 'Attendance Override Reason', 'Reasons for manual attendance override', 'ACTIVE')
        RETURNING id INTO v_key_id;
    ELSE
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE key_code = 'ATTENDANCE_OVERRIDE_REASON' LIMIT 1;
    END IF;

    -- Values for ATTENDANCE_OVERRIDE_REASON
    INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_code, value_name, sort_order, status)
    VALUES
        (gen_random_uuid(), v_key_id, v_school_id, 'TECHNICAL_ISSUE', 'Technical Issue / Disconnect', 1, 'ACTIVE'),
        (gen_random_uuid(), v_key_id, v_school_id, 'OFFLINE_ATTENDED', 'Joined Offline / Physical Class', 2, 'ACTIVE'),
        (gen_random_uuid(), v_key_id, v_school_id, 'MEDICAL_LEAVE', 'Excused Absence (Medical/Leave)', 3, 'ACTIVE'),
        (gen_random_uuid(), v_key_id, v_school_id, 'LATE_APPROVED', 'Late Join Approved', 4, 'ACTIVE'),
        (gen_random_uuid(), v_key_id, v_school_id, 'ADMIN_OVERRIDE', 'Other Administrative Reason', 5, 'ACTIVE')
    ON CONFLICT DO NOTHING;
END $$;


-- 2. BREAKOUT ROOMS SCHEMA
CREATE TABLE IF NOT EXISTS public.live_class_breakout_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.live_classes(id) ON DELETE CASCADE,
    room_name VARCHAR(255) NOT NULL,
    capacity INTEGER NOT NULL DEFAULT 8,
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, CLOSED
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.live_class_breakout_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    breakout_room_id UUID NOT NULL REFERENCES public.live_class_breakout_rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    status VARCHAR(50) DEFAULT 'JOINED',
    UNIQUE(breakout_room_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_breakout_rooms_session ON public.live_class_breakout_rooms(session_id);
CREATE INDEX IF NOT EXISTS idx_breakout_participants_room ON public.live_class_breakout_participants(breakout_room_id);


-- 3. STORED PROCEDURE: GET ENROLLED STUDENTS FOR A CLASS AND SECTION
CREATE OR REPLACE FUNCTION public.sp_get_enrolled_students_for_class_section(
    p_school_id UUID,
    p_class_id UUID,
    p_section_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_students JSONB;
BEGIN
    WITH raw_students AS (
        SELECT 
            p.id,
            COALESCE(p.user_id, p.id::TEXT) AS user_id,
            COALESCE(p.full_name, 'Student') AS name,
            COALESCE(sca.roll_number::TEXT, p.roll_number::TEXT, p.admission_number::TEXT, '10' || LPAD(ROW_NUMBER() OVER (ORDER BY p.full_name)::TEXT, 2, '0')) AS roll_number,
            p.email,
            p.avatar_url,
            'Enrolled' AS status
        FROM public.profiles p
        LEFT JOIN public.student_class_assignments sca ON sca.student_id = p.id
        WHERE (p.school_id = p_school_id OR p_school_id IS NULL)
          AND LOWER(COALESCE(p.role, '')) = 'student'
          AND (sca.class_id = p_class_id OR p_class_id IS NULL)
          AND (sca.section_id = p_section_id OR p_section_id IS NULL)
        ORDER BY roll_number, p.full_name
        LIMIT 50
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', id,
                'user_id', user_id,
                'name', name,
                'roll_number', roll_number,
                'email', email,
                'avatar_url', avatar_url,
                'status', status
            )
        ),
        '[]'::JSONB
    ) INTO v_students
    FROM raw_students;

    -- Fallback: if no class-specific assignments found, return active student profiles from school
    IF v_students IS NULL OR jsonb_array_length(v_students) = 0 THEN
        WITH fallback_students AS (
            SELECT 
                p.id,
                COALESCE(p.user_id, p.id::TEXT) AS user_id,
                COALESCE(p.full_name, 'Student') AS name,
                COALESCE(p.roll_number::TEXT, p.admission_number::TEXT, '10' || LPAD(ROW_NUMBER() OVER (ORDER BY p.full_name)::TEXT, 2, '0')) AS roll_number,
                p.email,
                p.avatar_url,
                'Enrolled' AS status
            FROM public.profiles p
            WHERE (p.school_id = p_school_id OR p_school_id IS NULL)
              AND LOWER(COALESCE(p.role, '')) = 'student'
            ORDER BY roll_number, p.full_name
            LIMIT 25
        )
        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', id,
                    'user_id', user_id,
                    'name', name,
                    'roll_number', roll_number,
                    'email', email,
                    'avatar_url', avatar_url,
                    'status', status
                )
            ),
            '[]'::JSONB
        ) INTO v_students
        FROM fallback_students;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'count', jsonb_array_length(v_students),
        'students', v_students
    );
END;
$$;


-- 4. STORED PROCEDURE: BREAKOUT ROOMS MANAGEMENT
CREATE OR REPLACE FUNCTION public.sp_create_live_class_breakout_room(
    p_school_id UUID,
    p_user_id UUID,
    p_session_id UUID,
    p_room_name VARCHAR(255),
    p_capacity INTEGER DEFAULT 8
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_room_id UUID;
    v_room JSONB;
BEGIN
    INSERT INTO public.live_class_breakout_rooms (
        school_id, session_id, room_name, capacity, status
    ) VALUES (
        p_school_id, p_session_id, p_room_name, COALESCE(p_capacity, 8), 'ACTIVE'
    ) RETURNING id INTO v_room_id;

    SELECT jsonb_build_object(
        'id', r.id,
        'sessionId', r.session_id,
        'name', r.room_name,
        'capacity', r.capacity,
        'status', r.status,
        'participants', '[]'::JSONB,
        'createdAt', r.created_at
    ) INTO v_room
    FROM public.live_class_breakout_rooms r
    WHERE r.id = v_room_id;

    RETURN jsonb_build_object('success', TRUE, 'room', v_room);
END;
$$;


CREATE OR REPLACE FUNCTION public.sp_get_live_class_breakout_rooms(
    p_session_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_rooms JSONB;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', r.id,
                'sessionId', r.session_id,
                'name', r.room_name,
                'capacity', r.capacity,
                'status', r.status,
                'participants', COALESCE((
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'id', p.id,
                            'name', COALESCE(p.full_name, 'Participant'),
                            'avatarUrl', p.avatar_url
                        )
                    )
                    FROM public.live_class_breakout_participants bp
                    JOIN public.profiles p ON p.id = bp.user_id
                    WHERE bp.breakout_room_id = r.id
                ), '[]'::JSONB),
                'createdAt', r.created_at
            )
            ORDER BY r.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_rooms
    FROM public.live_class_breakout_rooms r
    WHERE r.session_id = p_session_id
      AND r.status = 'ACTIVE';

    RETURN jsonb_build_object('success', TRUE, 'rooms', v_rooms);
END;
$$;


CREATE OR REPLACE FUNCTION public.sp_close_live_class_breakout_room(
    p_room_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.live_class_breakout_rooms
    SET status = 'CLOSED', updated_at = NOW()
    WHERE id = p_room_id;

    RETURN jsonb_build_object('success', TRUE, 'message', 'Breakout room closed successfully');
END;
$$;


-- 5. STORED PROCEDURE: UPDATE LIVE CLASS SETTINGS
CREATE OR REPLACE FUNCTION public.sp_update_live_class_session_settings(
    p_school_id UUID,
    p_user_id UUID,
    p_session_id UUID,
    p_settings JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.live_classes
    SET waiting_room_enabled = COALESCE((p_settings->>'waitingRoom')::BOOLEAN, waiting_room_enabled),
        allow_student_share = COALESCE((p_settings->>'allowScreenShare')::BOOLEAN, allow_student_share),
        allow_student_mic = COALESCE((p_settings->>'allowMic')::BOOLEAN, allow_student_mic),
        allow_student_cam = COALESCE((p_settings->>'allowCam')::BOOLEAN, allow_student_cam),
        allow_chat = COALESCE((p_settings->>'allowChat')::BOOLEAN, allow_chat),
        allow_reactions = COALESCE((p_settings->>'allowReactions')::BOOLEAN, allow_reactions),
        recording_enabled = COALESCE((p_settings->>'autoRecord')::BOOLEAN, recording_enabled),
        updated_at = NOW()
    WHERE id = p_session_id
      AND (school_id = p_school_id OR p_school_id IS NULL);

    RETURN jsonb_build_object('success', TRUE, 'message', 'Session settings updated successfully');
END;
$$;


-- 6. STORED PROCEDURE: REASSIGN HOST OR CO-HOST
CREATE OR REPLACE FUNCTION public.sp_reassign_live_class_host(
    p_school_id UUID,
    p_user_id UUID,
    p_session_id UUID,
    p_target_user_id UUID,
    p_role VARCHAR(50) DEFAULT 'host' -- 'host' or 'co_host'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF LOWER(p_role) = 'co_host' THEN
        UPDATE public.live_classes
        SET co_host_id = p_target_user_id, updated_at = NOW()
        WHERE id = p_session_id;
    ELSE
        UPDATE public.live_classes
        SET teacher_id = p_target_user_id, updated_at = NOW()
        WHERE id = p_session_id;
    END IF;

    -- Update participant record as host/co_host
    UPDATE public.live_class_participants
    SET participant_role = LOWER(p_role), updated_at = NOW()
    WHERE live_class_id = p_session_id AND user_id = p_target_user_id;

    RETURN jsonb_build_object('success', TRUE, 'message', 'Host role updated successfully');
END;
$$;
