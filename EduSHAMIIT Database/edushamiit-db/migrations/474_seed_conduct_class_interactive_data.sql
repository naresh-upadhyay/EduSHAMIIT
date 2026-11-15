-- ============================================================================
-- Migration 474: Seed Conduct Class Interactive Data
-- Seeds initial questions, polls, and participants for live sessions
-- ============================================================================

DO $$
DECLARE
    v_school_id UUID;
    v_session_id UUID;
    v_teacher_id UUID;
    v_student1_id UUID;
    v_student2_id UUID;
    v_student3_id UUID;
BEGIN
    SELECT id INTO v_school_id FROM public.schools LIMIT 1;
    IF v_school_id IS NULL THEN
        INSERT INTO public.schools (id, name, created_at)
        VALUES ('00000000-0000-0000-0000-000000000001', 'Greenwood High School', NOW())
        RETURNING id INTO v_school_id;
    END IF;

    -- Find session 10A-MATH or create one
    SELECT id INTO v_session_id FROM public.live_classes WHERE room_code = '10A-MATH' LIMIT 1;
    IF v_session_id IS NULL THEN
        SELECT id INTO v_session_id FROM public.live_classes WHERE school_id = v_school_id LIMIT 1;
    END IF;

    -- Find or create teacher
    SELECT id INTO v_teacher_id FROM public.profiles WHERE role ILIKE '%teacher%' LIMIT 1;
    IF v_teacher_id IS NULL THEN
        INSERT INTO public.profiles (id, school_id, full_name, role)
        VALUES (gen_random_uuid(), v_school_id, 'R. Kumar (Teacher)', 'teacher')
        RETURNING id INTO v_teacher_id;
    END IF;

    -- Find or create students
    SELECT id INTO v_student1_id FROM public.profiles WHERE full_name ILIKE '%Ananya%' LIMIT 1;
    IF v_student1_id IS NULL THEN
        INSERT INTO public.profiles (id, school_id, full_name, role)
        VALUES (gen_random_uuid(), v_school_id, 'Ananya Sharma (Student)', 'student')
        RETURNING id INTO v_student1_id;
    END IF;

    SELECT id INTO v_student2_id FROM public.profiles WHERE full_name ILIKE '%Rohan%' LIMIT 1;
    IF v_student2_id IS NULL THEN
        INSERT INTO public.profiles (id, school_id, full_name, role)
        VALUES (gen_random_uuid(), v_school_id, 'Rohan Verma (Student)', 'student')
        RETURNING id INTO v_student2_id;
    END IF;

    SELECT id INTO v_student3_id FROM public.profiles WHERE full_name ILIKE '%Priya%' LIMIT 1;
    IF v_student3_id IS NULL THEN
        INSERT INTO public.profiles (id, school_id, full_name, role)
        VALUES (gen_random_uuid(), v_school_id, 'Priya Desai (Student)', 'student')
        RETURNING id INTO v_student3_id;
    END IF;

    IF v_session_id IS NOT NULL THEN
        -- 1. Seed Questions in live_class_questions
        DELETE FROM public.live_class_questions WHERE session_id = v_session_id;

        INSERT INTO public.live_class_questions (session_id, school_id, author_id, author_name, author_role, question, is_anonymous, is_pinned, upvotes_count, status, answer, answered_at)
        VALUES 
        (
            v_session_id, v_school_id, v_student3_id, 'Priya Desai', 'student',
            'Can we use quadratic formula for non-integer coefficients?',
            FALSE, TRUE, 5, 'ANSWERED',
            'Yes Priya, it holds for all complex coefficients provided a != 0.', NOW()
        ),
        (
            v_session_id, v_school_id, v_student2_id, 'Mohit Singh', 'student',
            'When is the discriminant zero?',
            FALSE, FALSE, 3, 'ANSWERED',
            'When both roots are real and identical.', NOW()
        ),
        (
            v_session_id, v_school_id, v_student1_id, 'Sneha Kapoor', 'student',
            'Will today’s live class recording be uploaded by 2 PM?',
            FALSE, FALSE, 8, 'NEW',
            NULL, NULL
        );

        -- 2. Seed Active Poll in live_class_polls
        DELETE FROM public.live_class_polls WHERE session_id = v_session_id;

        INSERT INTO public.live_class_polls (session_id, school_id, creator_id, title, question, poll_type, status, total_votes, correct_option_id, options)
        VALUES (
            v_session_id, v_school_id, v_teacher_id,
            'Quadratic Formula Discriminant Value',
            'What happens when b² - 4ac < 0 ?',
            'SINGLE_CHOICE', 'ACTIVE', 42, 'B',
            jsonb_build_array(
                jsonb_build_object('id', 'A', 'text', 'A. Two distinct real roots', 'votes', 12, 'is_correct', FALSE),
                jsonb_build_object('id', 'B', 'text', 'B. Two complex conjugate roots', 'votes', 28, 'is_correct', TRUE),
                jsonb_build_object('id', 'C', 'text', 'C. One repeated real root', 'votes', 2, 'is_correct', FALSE)
            )
        );

        -- 3. Seed Participants in live_class_participants
        DELETE FROM public.live_class_participants WHERE live_class_id = v_session_id;

        INSERT INTO public.live_class_participants (live_class_id, school_id, user_id, participant_role, is_mic_muted, is_cam_off, is_hand_raised, connection_quality)
        VALUES
        (v_session_id, v_school_id, v_teacher_id, 'Teacher', FALSE, FALSE, FALSE, 'excellent'),
        (v_session_id, v_school_id, v_student1_id, 'Student', TRUE, FALSE, FALSE, 'good'),
        (v_session_id, v_school_id, v_student2_id, 'Student', TRUE, FALSE, FALSE, 'good'),
        (v_session_id, v_school_id, v_student3_id, 'Student', TRUE, TRUE, FALSE, 'good');

        -- 4. Seed Whiteboard record
        DELETE FROM public.live_class_whiteboards WHERE session_id = v_session_id;

        INSERT INTO public.live_class_whiteboards (session_id, school_id, teacher_only_mode, canvas_data)
        VALUES (
            v_session_id, v_school_id, TRUE,
            jsonb_build_object(
                'formula_title', 'Quadratic Equations',
                'standard_form', 'ax² + bx + c = 0',
                'quadratic_formula', 'x = (-b ± √(b² - 4ac)) / 2a',
                'elements', jsonb_build_array()
            )
        );
    END IF;
END $$;
