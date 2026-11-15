-- ============================================================================
-- Migration 471: Seed Data for Join via Code Recent/Saved Codes & Guest Sessions
-- Exact match with mockups for Join via Code and Guest Join.
-- ============================================================================

DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_user_id UUID := '5198c4b0-f1cb-45db-9649-41688d0438ba'; -- King Doe (super_admin)
    v_admin_test_id UUID := '11111111-1111-1111-1111-111111111111';
    v_teacher_rk UUID;
BEGIN
    -- Ensure school exists
    INSERT INTO public.schools (id, name, created_at, updated_at)
    VALUES (v_school_id, 'Greenwood High School', NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;

    -- Lookup teacher or fallback to admin tester
    SELECT id INTO v_teacher_rk FROM public.profiles WHERE full_name ILIKE '%Kumar%' LIMIT 1;
    IF v_teacher_rk IS NULL THEN
        v_teacher_rk := v_admin_test_id;
    END IF;

    -- 1. SEED / UPDATE SESSIONS WITH GUEST CAPABILITIES
    -- Session 1: Class 10 - A : Mathematics (Guest Lecture)
    INSERT INTO public.live_classes (
        id, school_id, teacher_id, title, description, target_class, room_code,
        status, scheduled_at, duration_minutes, is_live, viewer_count, max_participants,
        meeting_link, allow_guest_access, guest_access_mode, waiting_room_enabled, recording_enabled
    ) VALUES (
        'c1000000-0000-0000-0000-000000000010'::UUID,
        v_school_id, v_teacher_rk, 'Quadratic Equations – Guest Lecture',
        'Guest lecture on Quadratic Equations and roots analysis with guest speakers',
        'Class 10 - A', '10A-MATH',
        'live', CURRENT_DATE + TIME '10:00:00', 45, TRUE, 42, 45,
        'https://meet.edushamiit.com/cls/10a-math', TRUE, 'APPROVAL_REQUIRED', TRUE, TRUE
    )
    ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        room_code = '10A-MATH',
        target_class = 'Class 10 - A',
        allow_guest_access = TRUE,
        guest_access_mode = 'APPROVAL_REQUIRED',
        waiting_room_enabled = TRUE;

    -- Session 2: Class 12 - B : Physics (Career in Physics – Expert Talk)
    INSERT INTO public.live_classes (
        id, school_id, teacher_id, title, description, target_class, room_code,
        status, scheduled_at, duration_minutes, is_live, viewer_count, max_participants,
        meeting_link, allow_guest_access, guest_access_mode, waiting_room_enabled, recording_enabled
    ) VALUES (
        'c1000000-0000-0000-0000-000000000021'::UUID,
        v_school_id, v_teacher_rk, 'Career in Physics – Expert Talk',
        'Career paths, quantum research, and industrial physics insights by Dr. S. Verma',
        'Class 12 - B', '11A-PHY',
        'upcoming', CURRENT_DATE + INTERVAL '3 days' + TIME '11:15:00', 45, FALSE, 0, 50,
        'https://meet.edushamiit.com/cls/11a-phy', TRUE, 'APPROVAL_REQUIRED', TRUE, TRUE
    )
    ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        room_code = '11A-PHY',
        target_class = 'Class 12 - B',
        allow_guest_access = TRUE,
        guest_access_mode = 'APPROVAL_REQUIRED',
        waiting_room_enabled = TRUE;

    -- Session 3: Class 11 - A : Chemistry (Industrial Applications of Chemistry)
    INSERT INTO public.live_classes (
        id, school_id, teacher_id, title, description, target_class, room_code,
        status, scheduled_at, duration_minutes, is_live, viewer_count, max_participants,
        meeting_link, allow_guest_access, guest_access_mode, waiting_room_enabled, recording_enabled
    ) VALUES (
        'c1000000-0000-0000-0000-000000000022'::UUID,
        v_school_id, v_teacher_rk, 'Industrial Applications of Chemistry',
        'Petrochemical, polymer, and pharmaceutical real-world chemistry by Prof. A. Sharma',
        'Class 11 - A', '12B-CHEM',
        'scheduled', CURRENT_DATE + INTERVAL '6 days' + TIME '14:00:00', 45, FALSE, 0, 50,
        'https://meet.edushamiit.com/cls/12b-chem', TRUE, 'OPEN', FALSE, TRUE
    )
    ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        room_code = '12B-CHEM',
        target_class = 'Class 11 - A',
        allow_guest_access = TRUE,
        guest_access_mode = 'OPEN';

    -- 2. SEED RECENT / SAVED MEETING CODES FOR KING DOE & ADMIN TESTER
    -- User 1: King Doe
    INSERT INTO public.live_class_recent_codes (user_id, meeting_code, class_subject, teacher_name, is_starred, last_joined_at)
    VALUES
        (v_user_id, '10A-MATH', 'Class 10 - A' || E'\n' || 'Mathematics', 'R. Kumar', TRUE, NOW()),
        (v_user_id, '11A-PHY', 'Class 11 - A' || E'\n' || 'Physics', 'S. Verma', FALSE, NOW() - INTERVAL '1 day'),
        (v_user_id, '8A-ENG', 'Class 8 - A' || E'\n' || 'English', 'P. Desai', FALSE, NOW() - INTERVAL '2 days'),
        (v_user_id, '12B-CHEM', 'Class 12 - B' || E'\n' || 'Chemistry', 'A. Sharma', FALSE, NOW() - INTERVAL '4 days')
    ON CONFLICT (user_id, meeting_code)
    DO UPDATE SET
        class_subject = EXCLUDED.class_subject,
        teacher_name = EXCLUDED.teacher_name,
        is_starred = EXCLUDED.is_starred,
        last_joined_at = EXCLUDED.last_joined_at;

    -- User 2: Admin Tester
    INSERT INTO public.live_class_recent_codes (user_id, meeting_code, class_subject, teacher_name, is_starred, last_joined_at)
    VALUES
        (v_admin_test_id, '10A-MATH', 'Class 10 - A' || E'\n' || 'Mathematics', 'R. Kumar', TRUE, NOW()),
        (v_admin_test_id, '11A-PHY', 'Class 11 - A' || E'\n' || 'Physics', 'S. Verma', FALSE, NOW() - INTERVAL '1 day'),
        (v_admin_test_id, '8A-ENG', 'Class 8 - A' || E'\n' || 'English', 'P. Desai', FALSE, NOW() - INTERVAL '2 days'),
        (v_admin_test_id, '12B-CHEM', 'Class 12 - B' || E'\n' || 'Chemistry', 'A. Sharma', FALSE, NOW() - INTERVAL '4 days')
    ON CONFLICT (user_id, meeting_code)
    DO UPDATE SET
        class_subject = EXCLUDED.class_subject,
        teacher_name = EXCLUDED.teacher_name,
        is_starred = EXCLUDED.is_starred,
        last_joined_at = EXCLUDED.last_joined_at;

END $$;
