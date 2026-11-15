-- ============================================================================
-- Migration 464: Seed Live Class Enterprise Data
-- Provides high-fidelity data matching user design screenshots for
-- Join & Conduct, Recordings, and Attendance tabs.
-- ============================================================================

DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_teacher_id UUID;
    v_class_10_id UUID;
    v_section_10a_id UUID;
    v_section_10b_id UUID;
    v_class_9_id UUID;
    v_section_9a_id UUID;
    v_section_9b_id UUID;
    v_class_11_id UUID;
    v_section_11a_id UUID;
    v_class_8_id UUID;
    v_section_8a_id UUID;
    v_section_8b_id UUID;
    v_class_12_id UUID;
    v_section_12b_id UUID;
    v_subj_math UUID;
    v_subj_sci UUID;
    v_subj_phy UUID;
    v_subj_chem UUID;
    v_subj_eng UUID;
    v_subj_bio UUID;
    v_subj_soc UUID;
    v_session_math_id UUID := 'c1000000-0000-0000-0000-000000000010';
    v_session_sci_id UUID := 'c1000000-0000-0000-0000-000000000009';
    v_session_phy_id UUID := 'c1000000-0000-0000-0000-000000000011';
    v_session_eng_id UUID := 'c1000000-0000-0000-0000-000000000008';
    v_session_chem_id UUID := 'c1000000-0000-0000-0000-000000000012';
    v_session_trig_id UUID := 'c1000000-0000-0000-0000-000000000014';
    v_session_bio_id UUID := 'c1000000-0000-0000-0000-000000000015';
    v_session_soc_id UUID := 'c1000000-0000-0000-0000-000000000016';
    v_stud_id UUID;
    i INT;
    v_names TEXT[] := ARRAY[
        'Aarav Sharma', 'Ananya Verma', 'Rohan Mehta', 'Priya Desai', 'Mohit Singh',
        'Sneha Kapoor', 'Kunal Bansal', 'Ishita Rao', 'Vivek Nair', 'Meera Iyer',
        'Aditya Joshi', 'Kavya Pillai', 'Arnav Gupta', 'Diya Chawla', 'Siddharth Roy',
        'Tanvi Kulkarni', 'Manish Pandey', 'Rhea Sengupta', 'Dev Patel', 'Pooja Hegde',
        'Harsh Vardhan', 'Anushka Sen', 'Gaurav Bhatt', 'Shruti Saxena', 'Akash Mallik',
        'Neha Tiwari', 'Rahul Dravid', 'Shreya Ghoshal', 'Nikhil Kamath', 'Bhavna Aggarwal',
        'Varun Dhawan', 'Simran Kaur', 'Rajesh Khanna', 'Deepika Nair', 'Aman Verma',
        'Sonia Gandhi', 'Karan Johar', 'Sunita Rao', 'Tarun Tahiliani', 'Mansi Parekh',
        'Zeeshan Ali', 'Farhan Akhtar'
    ];
BEGIN
    -- 1. Ensure Teacher Profile exists: R. Kumar
    SELECT id INTO v_teacher_id FROM public.profiles WHERE full_name ILIKE '%Kumar%' AND role = 'teacher' LIMIT 1;
    IF v_teacher_id IS NULL THEN
        v_teacher_id := 'aa000001-0000-0000-0000-000000000099';
        INSERT INTO public.profiles (id, user_id, school_id, full_name, email, role, class)
        VALUES (v_teacher_id, v_teacher_id, v_school_id, 'R. Kumar (Teacher)', 'r.kumar@edushamiit.com', 'teacher', '10A')
        ON CONFLICT (id) DO UPDATE SET full_name = 'R. Kumar (Teacher)';
    END IF;

    -- 2. Fetch or create Academic Classes
    SELECT id INTO v_class_10_id FROM public.academic_classes WHERE name ILIKE '%Class 10%' LIMIT 1;
    IF v_class_10_id IS NULL THEN
        INSERT INTO public.academic_classes (school_id, name, code, stage, status)
        VALUES (v_school_id, 'Class 10', 'CLS-10', 'SECONDARY', 'ACTIVE') RETURNING id INTO v_class_10_id;
    END IF;

    SELECT id INTO v_class_9_id FROM public.academic_classes WHERE name ILIKE '%Class 9%' LIMIT 1;
    IF v_class_9_id IS NULL THEN
        INSERT INTO public.academic_classes (school_id, name, code, stage, status)
        VALUES (v_school_id, 'Class 9', 'CLS-9', 'SECONDARY', 'ACTIVE') RETURNING id INTO v_class_9_id;
    END IF;

    SELECT id INTO v_class_11_id FROM public.academic_classes WHERE name ILIKE '%Class 11%' LIMIT 1;
    IF v_class_11_id IS NULL THEN
        INSERT INTO public.academic_classes (school_id, name, code, stage, status)
        VALUES (v_school_id, 'Class 11', 'CLS-11', 'HIGHER_SECONDARY', 'ACTIVE') RETURNING id INTO v_class_11_id;
    END IF;

    SELECT id INTO v_class_8_id FROM public.academic_classes WHERE name ILIKE '%Class 8%' LIMIT 1;
    IF v_class_8_id IS NULL THEN
        INSERT INTO public.academic_classes (school_id, name, code, stage, status)
        VALUES (v_school_id, 'Class 8', 'CLS-8', 'MIDDLE', 'ACTIVE') RETURNING id INTO v_class_8_id;
    END IF;

    SELECT id INTO v_class_12_id FROM public.academic_classes WHERE name ILIKE '%Class 12%' LIMIT 1;
    IF v_class_12_id IS NULL THEN
        INSERT INTO public.academic_classes (school_id, name, code, stage, status)
        VALUES (v_school_id, 'Class 12', 'CLS-12', 'HIGHER_SECONDARY', 'ACTIVE') RETURNING id INTO v_class_12_id;
    END IF;

    -- Sections
    SELECT id INTO v_section_10a_id FROM public.academic_sections WHERE class_id = v_class_10_id AND name ILIKE '%A%' LIMIT 1;
    IF v_section_10a_id IS NULL THEN
        INSERT INTO public.academic_sections (school_id, class_id, name, code)
        VALUES (v_school_id, v_class_10_id, '10-A', 'SEC-10A') RETURNING id INTO v_section_10a_id;
    END IF;

    SELECT id INTO v_section_10b_id FROM public.academic_sections WHERE class_id = v_class_10_id AND name ILIKE '%B%' LIMIT 1;
    IF v_section_10b_id IS NULL THEN
        INSERT INTO public.academic_sections (school_id, class_id, name, code)
        VALUES (v_school_id, v_class_10_id, '10-B', 'SEC-10B') RETURNING id INTO v_section_10b_id;
    END IF;

    SELECT id INTO v_section_9a_id FROM public.academic_sections WHERE class_id = v_class_9_id AND name ILIKE '%A%' LIMIT 1;
    IF v_section_9a_id IS NULL THEN
        INSERT INTO public.academic_sections (school_id, class_id, name, code)
        VALUES (v_school_id, v_class_9_id, '9-A', 'SEC-9A') RETURNING id INTO v_section_9a_id;
    END IF;

    SELECT id INTO v_section_9b_id FROM public.academic_sections WHERE class_id = v_class_9_id AND name ILIKE '%B%' LIMIT 1;
    IF v_section_9b_id IS NULL THEN
        INSERT INTO public.academic_sections (school_id, class_id, name, code)
        VALUES (v_school_id, v_class_9_id, '9-B', 'SEC-9B') RETURNING id INTO v_section_9b_id;
    END IF;

    SELECT id INTO v_section_11a_id FROM public.academic_sections WHERE class_id = v_class_11_id AND name ILIKE '%A%' LIMIT 1;
    IF v_section_11a_id IS NULL THEN
        INSERT INTO public.academic_sections (school_id, class_id, name, code)
        VALUES (v_school_id, v_class_11_id, '11-A', 'SEC-11A') RETURNING id INTO v_section_11a_id;
    END IF;

    SELECT id INTO v_section_8a_id FROM public.academic_sections WHERE class_id = v_class_8_id AND name ILIKE '%A%' LIMIT 1;
    IF v_section_8a_id IS NULL THEN
        INSERT INTO public.academic_sections (school_id, class_id, name, code)
        VALUES (v_school_id, v_class_8_id, '8-A', 'SEC-8A') RETURNING id INTO v_section_8a_id;
    END IF;

    SELECT id INTO v_section_8b_id FROM public.academic_sections WHERE class_id = v_class_8_id AND name ILIKE '%B%' LIMIT 1;
    IF v_section_8b_id IS NULL THEN
        INSERT INTO public.academic_sections (school_id, class_id, name, code)
        VALUES (v_school_id, v_class_8_id, '8-B', 'SEC-8B') RETURNING id INTO v_section_8b_id;
    END IF;

    SELECT id INTO v_section_12b_id FROM public.academic_sections WHERE class_id = v_class_12_id AND name ILIKE '%B%' LIMIT 1;
    IF v_section_12b_id IS NULL THEN
        INSERT INTO public.academic_sections (school_id, class_id, name, code)
        VALUES (v_school_id, v_class_12_id, '12-B', 'SEC-12B') RETURNING id INTO v_section_12b_id;
    END IF;

    -- 3. Subjects
    SELECT id INTO v_subj_math FROM public.subjects WHERE name ILIKE 'Mathematics' LIMIT 1;
    IF v_subj_math IS NULL THEN
        INSERT INTO public.subjects (school_id, name, icon, class) VALUES (v_school_id, 'Mathematics', '📐', '10A') RETURNING id INTO v_subj_math;
    END IF;

    SELECT id INTO v_subj_sci FROM public.subjects WHERE name ILIKE 'Science' LIMIT 1;
    IF v_subj_sci IS NULL THEN
        INSERT INTO public.subjects (school_id, name, icon, class) VALUES (v_school_id, 'Science', '🔬', '9B') RETURNING id INTO v_subj_sci;
    END IF;

    SELECT id INTO v_subj_phy FROM public.subjects WHERE name ILIKE 'Physics' LIMIT 1;
    IF v_subj_phy IS NULL THEN
        INSERT INTO public.subjects (school_id, name, icon, class) VALUES (v_school_id, 'Physics', '⚡', '11A') RETURNING id INTO v_subj_phy;
    END IF;

    SELECT id INTO v_subj_chem FROM public.subjects WHERE name ILIKE 'Chemistry' LIMIT 1;
    IF v_subj_chem IS NULL THEN
        INSERT INTO public.subjects (school_id, name, icon, class) VALUES (v_school_id, 'Chemistry', '🧪', '12B') RETURNING id INTO v_subj_chem;
    END IF;

    SELECT id INTO v_subj_eng FROM public.subjects WHERE name ILIKE 'English' LIMIT 1;
    IF v_subj_eng IS NULL THEN
        INSERT INTO public.subjects (school_id, name, icon, class) VALUES (v_school_id, 'English', '📖', '8A') RETURNING id INTO v_subj_eng;
    END IF;

    SELECT id INTO v_subj_bio FROM public.subjects WHERE name ILIKE 'Biology' LIMIT 1;
    IF v_subj_bio IS NULL THEN
        INSERT INTO public.subjects (school_id, name, icon, class) VALUES (v_school_id, 'Biology', '🧬', '9A') RETURNING id INTO v_subj_bio;
    END IF;

    SELECT id INTO v_subj_soc FROM public.subjects WHERE name ILIKE 'Social Science' LIMIT 1;
    IF v_subj_soc IS NULL THEN
        INSERT INTO public.subjects (school_id, name, icon, class) VALUES (v_school_id, 'Social Science', '🌍', '8B') RETURNING id INTO v_subj_soc;
    END IF;

    -- 4. Seed Live Classes
    -- A. Class 10 - A : Mathematics (Quadratic Equations) Live Now
    INSERT INTO public.live_classes (
        id, school_id, class_id, section_id, subject_id, teacher_id,
        title, description, duration_minutes, scheduled_at, actual_start_at,
        platform, is_live, status, max_participants, viewer_count,
        room_code, meeting_link, target_class, recording_enabled, recording_status
    ) VALUES (
        v_session_math_id, v_school_id, v_class_10_id, v_section_10a_id, v_subj_math, v_teacher_id,
        'Quadratic Equations', 'Standard Form, Discriminant, Quadratic Formula and Factorization Techniques',
        45, NOW() - INTERVAL '18 minutes', NOW() - INTERVAL '18 minutes',
        'In-App', TRUE, 'live', 45, 42,
        '10A-MATH', 'https://meet.edushamiit.com/cls/10A-math', '10A', TRUE, 'RECORDING'
    ) ON CONFLICT (id) DO UPDATE SET
        is_live = TRUE, status = 'live', recording_status = 'RECORDING',
        class_id = v_class_10_id, section_id = v_section_10a_id, subject_id = v_subj_math;

    -- B. Class 9 - B: Science (Next, Scheduled)
    INSERT INTO public.live_classes (
        id, school_id, class_id, section_id, subject_id, teacher_id,
        title, description, duration_minutes, scheduled_at,
        platform, is_live, status, max_participants, viewer_count,
        room_code, meeting_link, target_class, recording_enabled
    ) VALUES (
        v_session_sci_id, v_school_id, v_class_9_id, v_section_9b_id, v_subj_sci, v_teacher_id,
        'Matter and its Properties', 'States of Matter, Latent Heat, and Molecular Diffusion',
        45, NOW() + INTERVAL '45 minutes',
        'In-App', FALSE, 'scheduled', 45, 0,
        '9B-SCI', 'https://meet.edushamiit.com/cls/9B-sci', '9B', TRUE
    ) ON CONFLICT (id) DO NOTHING;

    -- C. Class 11 - A: Physics (Scheduled)
    INSERT INTO public.live_classes (
        id, school_id, class_id, section_id, subject_id, teacher_id,
        title, description, duration_minutes, scheduled_at,
        platform, is_live, status, max_participants, viewer_count,
        room_code, meeting_link, target_class, recording_enabled
    ) VALUES (
        v_session_phy_id, v_school_id, v_class_11_id, v_section_11a_id, v_subj_phy, v_teacher_id,
        'Units and Measurements', 'Dimensional Analysis and Error Calculations',
        45, NOW() + INTERVAL '2 hours',
        'In-App', FALSE, 'scheduled', 45, 0,
        '11A-PHY', 'https://meet.edushamiit.com/cls/11A-phy', '11A', TRUE
    ) ON CONFLICT (id) DO NOTHING;

    -- D. Class 8 - A: English (Scheduled)
    INSERT INTO public.live_classes (
        id, school_id, class_id, section_id, subject_id, teacher_id,
        title, description, duration_minutes, scheduled_at,
        platform, is_live, status, max_participants, viewer_count,
        room_code, meeting_link, target_class, recording_enabled
    ) VALUES (
        v_session_eng_id, v_school_id, v_class_8_id, v_section_8a_id, v_subj_eng, v_teacher_id,
        'English Literature - Poetry', 'Analysis of Daffodils by William Wordsworth',
        45, NOW() + INTERVAL '3.5 hours',
        'In-App', FALSE, 'scheduled', 45, 0,
        '8A-ENG', 'https://meet.edushamiit.com/cls/8A-eng', '8A', TRUE
    ) ON CONFLICT (id) DO NOTHING;

    -- E. Chemistry Class 12 - B (Recorded)
    INSERT INTO public.live_classes (
        id, school_id, class_id, section_id, subject_id, teacher_id,
        title, description, duration_minutes, scheduled_at,
        platform, is_live, status, max_participants, viewer_count,
        room_code, meeting_link, target_class, recording_enabled
    ) VALUES (
        v_session_chem_id, v_school_id, v_class_12_id, v_section_12b_id, v_subj_chem, v_teacher_id,
        'Organic Compounds - Intro', 'Alkanes, Alkenes, Alkynes nomenclature',
        48, NOW() - INTERVAL '2 days',
        'In-App', FALSE, 'recorded', 50, 95,
        '12B-CHEM', 'https://meet.edushamiit.com/cls/12B-chem', '12B', TRUE
    ) ON CONFLICT (id) DO NOTHING;

    -- F. Trigonometry Class 10 - B (Recorded)
    INSERT INTO public.live_classes (
        id, school_id, class_id, section_id, subject_id, teacher_id,
        title, description, duration_minutes, scheduled_at,
        platform, is_live, status, max_participants, viewer_count,
        room_code, meeting_link, target_class, recording_enabled
    ) VALUES (
        v_session_trig_id, v_school_id, v_class_10_id, v_section_10b_id, v_subj_math, v_teacher_id,
        'Introduction to Trigonometry', 'Trigonometric Ratios and Standard Angles',
        47, NOW() - INTERVAL '3 days',
        'In-App', FALSE, 'recorded', 45, 89,
        '10B-TRIG', 'https://meet.edushamiit.com/cls/10B-trig', '10B', TRUE
    ) ON CONFLICT (id) DO NOTHING;

    -- G. Biology Class 9 - A (Recorded)
    INSERT INTO public.live_classes (
        id, school_id, class_id, section_id, subject_id, teacher_id,
        title, description, duration_minutes, scheduled_at,
        platform, is_live, status, max_participants, viewer_count,
        room_code, meeting_link, target_class, recording_enabled
    ) VALUES (
        v_session_bio_id, v_school_id, v_class_9_id, v_section_9a_id, v_subj_bio, v_teacher_id,
        'Cell Structure and Function', 'Plant and Animal Cell Organelles under Electron Microscope',
        45, NOW() - INTERVAL '3 days',
        'In-App', FALSE, 'recorded', 45, 71,
        '9A-BIO', 'https://meet.edushamiit.com/cls/9A-bio', '9A', TRUE
    ) ON CONFLICT (id) DO NOTHING;

    -- H. Social Science Class 8 - B (Recorded)
    INSERT INTO public.live_classes (
        id, school_id, class_id, section_id, subject_id, teacher_id,
        title, description, duration_minutes, scheduled_at,
        platform, is_live, status, max_participants, viewer_count,
        room_code, meeting_link, target_class, recording_enabled
    ) VALUES (
        v_session_soc_id, v_school_id, v_class_8_id, v_section_8b_id, v_subj_soc, v_teacher_id,
        'Indian Freedom Movement', 'The Revolt of 1857 and Non-Cooperation Movement',
        43, NOW() - INTERVAL '4 days',
        'In-App', FALSE, 'recorded', 45, 52,
        '8B-SOC', 'https://meet.edushamiit.com/cls/8B-soc', '8B', TRUE
    ) ON CONFLICT (id) DO NOTHING;

    -- 5. Seed Recordings (Matching Image 2)
    -- 1. Quadratic Equations - Part 1
    INSERT INTO public.live_class_recordings (
        live_class_id, title, description, recording_url, duration, file_size,
        views_count, downloads_count, processing_status, visibility, created_at
    ) VALUES (
        v_session_math_id, 'Quadratic Equations - Part 1', 'Class 10 - A Mathematics Lecture on Quadratic Equations',
        'http://localhost:8000/storage/v1/object/public/live-classes/quadratic_equations_part1.mp4',
        2700, 282 * 1024 * 1024, 112, 45, 'Processed', 'CLASS', NOW() - INTERVAL '1 day'
    ) ON CONFLICT DO NOTHING;

    -- 2. Matter and its Properties
    INSERT INTO public.live_class_recordings (
        live_class_id, title, description, recording_url, duration, file_size,
        views_count, downloads_count, processing_status, visibility, created_at
    ) VALUES (
        v_session_sci_id, 'Matter and its Properties', 'Class 9 - B Science Lecture',
        'http://localhost:8000/storage/v1/object/public/live-classes/matter_and_properties.mp4',
        2640, 268 * 1024 * 1024, 76, 32, 'Processed', 'CLASS', NOW() - INTERVAL '1 day'
    ) ON CONFLICT DO NOTHING;

    -- 3. Units and Measurements
    INSERT INTO public.live_class_recordings (
        live_class_id, title, description, recording_url, duration, file_size,
        views_count, downloads_count, processing_status, visibility, created_at
    ) VALUES (
        v_session_phy_id, 'Units and Measurements', 'Class 11 - A Physics Lecture',
        'http://localhost:8000/storage/v1/object/public/live-classes/units_and_measurements.mp4',
        2760, 290 * 1024 * 1024, 68, 29, 'Processed', 'CLASS', NOW() - INTERVAL '1 day'
    ) ON CONFLICT DO NOTHING;

    -- 4. Organic Compounds - Intro
    INSERT INTO public.live_class_recordings (
        live_class_id, title, description, recording_url, duration, file_size,
        views_count, downloads_count, processing_status, visibility, created_at
    ) VALUES (
        v_session_chem_id, 'Organic Compounds - Intro', 'Class 12 - B Chemistry Lecture',
        'http://localhost:8000/storage/v1/object/public/live-classes/organic_compounds_intro.mp4',
        2880, 310 * 1024 * 1024, 95, 41, 'Processed', 'CLASS', NOW() - INTERVAL '2 days'
    ) ON CONFLICT DO NOTHING;

    -- 5. English Literature - Poetry
    INSERT INTO public.live_class_recordings (
        live_class_id, title, description, recording_url, duration, file_size,
        views_count, downloads_count, processing_status, visibility, created_at
    ) VALUES (
        v_session_eng_id, 'English Literature - Poetry', 'Class 8 - A English Lecture',
        'http://localhost:8000/storage/v1/object/public/live-classes/english_literature_poetry.mp4',
        2520, 260 * 1024 * 1024, 64, 18, 'Processed', 'CLASS', NOW() - INTERVAL '2 days'
    ) ON CONFLICT DO NOTHING;

    -- 6. Introduction to Trigonometry
    INSERT INTO public.live_class_recordings (
        live_class_id, title, description, recording_url, duration, file_size,
        views_count, downloads_count, processing_status, visibility, created_at
    ) VALUES (
        v_session_trig_id, 'Introduction to Trigonometry', 'Class 10 - B Mathematics Lecture',
        'http://localhost:8000/storage/v1/object/public/live-classes/intro_trigonometry.mp4',
        2820, 305 * 1024 * 1024, 89, 39, 'Processed', 'CLASS', NOW() - INTERVAL '3 days'
    ) ON CONFLICT DO NOTHING;

    -- 7. Cell Structure and Function
    INSERT INTO public.live_class_recordings (
        live_class_id, title, description, recording_url, duration, file_size,
        views_count, downloads_count, processing_status, visibility, created_at
    ) VALUES (
        v_session_bio_id, 'Cell Structure and Function', 'Class 9 - A Biology Lecture',
        'http://localhost:8000/storage/v1/object/public/live-classes/cell_structure_function.mp4',
        2700, 298 * 1024 * 1024, 71, 28, 'Processed', 'CLASS', NOW() - INTERVAL '3 days'
    ) ON CONFLICT DO NOTHING;

    -- 8. Indian Freedom Movement
    INSERT INTO public.live_class_recordings (
        live_class_id, title, description, recording_url, duration, file_size,
        views_count, downloads_count, processing_status, visibility, created_at
    ) VALUES (
        v_session_soc_id, 'Indian Freedom Movement', 'Class 8 - B Social Science Lecture',
        'http://localhost:8000/storage/v1/object/public/live-classes/indian_freedom_movement.mp4',
        2580, 262 * 1024 * 1024, 52, 22, 'Processed', 'CLASS', NOW() - INTERVAL '4 days'
    ) ON CONFLICT DO NOTHING;

    -- 6. Seed Students and Attendance (Matching Image 3)
    FOR i IN 1..42 LOOP
        v_stud_id := ('00000000-0000-0000-0000-' || LPAD(i::TEXT, 12, '0'))::UUID;
        
        -- Insert profile with roll number 1000 + i
        INSERT INTO public.profiles (
            id, user_id, school_id, full_name, email, role, class, roll_number
        ) VALUES (
            v_stud_id, v_stud_id, v_school_id, v_names[i],
            LOWER(REPLACE(v_names[i], ' ', '.')) || '@edushamiit.com',
            'student', '10A', (1000 + i)
        ) ON CONFLICT (id) DO UPDATE SET
            roll_number = (1000 + i),
            full_name = v_names[i];

        -- Participants and Attendance records
        IF i IN (3, 7, 10) THEN
            -- Absent students (Rohan Mehta 1003, Kunal Bansal 1007, Meera Iyer 1010)
            INSERT INTO public.live_class_participants (
                live_class_id, user_id, join_time, leave_time, duration,
                participant_role, attendance_status
            ) VALUES (
                v_session_math_id, v_stud_id, NULL, NULL, 0,
                'student', 'Absent'
            ) ON CONFLICT DO NOTHING;

            INSERT INTO public.live_class_attendance (
                live_class_id, student_id, school_id, class_id, section_id, subject_id,
                effective_duration_seconds, participation_percentage,
                attendance_status, calculated_status, final_status,
                remarks
            ) VALUES (
                v_session_math_id, v_stud_id, v_school_id, v_class_10_id, v_section_10a_id, v_subj_math,
                0, 0.0,
                'Absent', 'Absent', 'Absent',
                CASE WHEN i = 10 THEN 'Network Issue' ELSE 'Not Joined' END
            ) ON CONFLICT DO NOTHING;

        ELSE
            -- Present students (92.7% present rate)
            INSERT INTO public.live_class_participants (
                live_class_id, user_id, join_time, leave_time, duration,
                participant_role, attendance_status, reconnection_count,
                first_join_at, last_leave_at
            ) VALUES (
                v_session_math_id, v_stud_id,
                NOW() - INTERVAL '18 minutes', NOW(), 2640,
                'student', 'Present', CASE WHEN i % 5 = 0 THEN 1 ELSE 0 END,
                NOW() - INTERVAL '18 minutes', NOW()
            ) ON CONFLICT DO NOTHING;

            -- Create segments
            INSERT INTO public.live_class_connection_segments (
                session_id, user_id, joined_at, left_at, duration_seconds
            ) VALUES (
                v_session_math_id, v_stud_id,
                NOW() - INTERVAL '18 minutes', NOW(), 2640
            ) ON CONFLICT DO NOTHING;

            INSERT INTO public.live_class_attendance (
                live_class_id, student_id, school_id, class_id, section_id, subject_id,
                first_join_time, last_leave_time, effective_duration_seconds,
                participation_percentage, attendance_status, calculated_status, final_status,
                remarks
            ) VALUES (
                v_session_math_id, v_stud_id, v_school_id, v_class_10_id, v_section_10a_id, v_subj_math,
                NOW() - INTERVAL '18 minutes', NOW(), 2640,
                (90 + (i % 9))::NUMERIC,
                'Present', 'Present', 'Present',
                '-'
            ) ON CONFLICT DO NOTHING;
        END IF;
    END LOOP;

    -- Ensure Live Class Settings exist for school
    INSERT INTO public.live_class_settings (
        school_id, min_attendance_percentage, late_join_threshold_minutes,
        early_leave_threshold_minutes, auto_record_default, cloud_storage_enabled,
        default_retention_days, recording_quality, allow_student_download
    ) VALUES (
        v_school_id, 75.0, 10, 10, TRUE, TRUE, 180, 'HD (720p)', TRUE
    ) ON CONFLICT (school_id) DO UPDATE SET
        min_attendance_percentage = 75.0,
        cloud_storage_enabled = TRUE;

END $$;
