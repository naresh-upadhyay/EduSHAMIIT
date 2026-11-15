-- ============================================================================
-- Migration 469: Seed Live Class "My Classes" Enterprise Dataset
-- Matches the classes shown in design:
-- 1. Class 10 - A | Mathematics | Quadratic Equations – Part 1 | Live
-- 2. Class 11 - A | Physics | Laws of Motion (Introduction) | Upcoming
-- 3. Class 8 - A | English | Poetry – The Road Not Taken | Upcoming
-- 4. Class 9 - B | Science | Matter and its Properties | Completed
-- 5. Class 12 - A | Chemistry | Organic Compounds – Introduction | Scheduled
-- ============================================================================

DO $$
DECLARE
    v_school_id UUID;
    v_teacher_id UUID;
    v_cohost_id UUID;
    v_sec_10a UUID;
    v_sec_11a UUID;
    v_sec_8a UUID;
    v_sec_9b UUID;
    v_sec_12a UUID;
    v_cls_10 UUID;
    v_cls_11 UUID;
    v_cls_8 UUID;
    v_cls_9 UUID;
    v_cls_12 UUID;
    v_sub_math UUID;
    v_sub_phys UUID;
    v_sub_eng UUID;
    v_sub_sci UUID;
    v_sub_chem UUID;
BEGIN
    SELECT id INTO v_school_id FROM public.schools LIMIT 1;
    IF v_school_id IS NULL THEN
        v_school_id := '11111111-1111-1111-1111-111111111111'::UUID;
    END IF;

    -- Teacher & Co-host
    SELECT id INTO v_teacher_id FROM public.profiles WHERE role IN ('teacher', 'admin', 'super_admin') LIMIT 1;
    IF v_teacher_id IS NULL THEN
        v_teacher_id := '11111111-1111-1111-1111-111111111111'::UUID;
    END IF;

    SELECT id INTO v_cohost_id FROM public.profiles WHERE id != v_teacher_id LIMIT 1;
    IF v_cohost_id IS NULL THEN
        v_cohost_id := v_teacher_id;
    END IF;

    -- Lookup classes & subjects
    SELECT id INTO v_cls_10 FROM public.academic_classes WHERE name ILIKE '%10%' LIMIT 1;
    SELECT id INTO v_cls_11 FROM public.academic_classes WHERE name ILIKE '%11%' LIMIT 1;
    SELECT id INTO v_cls_8 FROM public.academic_classes WHERE name ILIKE '%8%' LIMIT 1;
    SELECT id INTO v_cls_9 FROM public.academic_classes WHERE name ILIKE '%9%' LIMIT 1;
    SELECT id INTO v_cls_12 FROM public.academic_classes WHERE name ILIKE '%12%' LIMIT 1;

    SELECT id INTO v_sub_math FROM public.subjects WHERE name ILIKE '%math%' LIMIT 1;
    SELECT id INTO v_sub_phys FROM public.subjects WHERE name ILIKE '%phys%' LIMIT 1;
    SELECT id INTO v_sub_eng FROM public.subjects WHERE name ILIKE '%eng%' LIMIT 1;
    SELECT id INTO v_sub_sci FROM public.subjects WHERE name ILIKE '%sci%' LIMIT 1;
    SELECT id INTO v_sub_chem FROM public.subjects WHERE name ILIKE '%chem%' LIMIT 1;

    -- 1. Class 10 - A : Mathematics | Live
    INSERT INTO public.live_classes (
        id, school_id, class_id, section_id, subject_id, teacher_id, co_host_id,
        title, description, scheduled_at, duration_minutes, target_class,
        status, is_live, viewer_count, max_participants, room_code,
        meeting_link, recording_status, recording_enabled, attendance_status, created_at
    ) VALUES (
        'c1000000-0000-0000-0000-000000000010'::UUID,
        v_school_id, v_cls_10, NULL, v_sub_math, v_teacher_id, v_cohost_id,
        'Quadratic Equations – Part 1',
        'Standard form and quadratic formula derivation with step-by-step discriminant analysis',
        CURRENT_DATE + TIME '08:00:00',
        45, 'Class 10 - A',
        'live', TRUE, 42, 45, '10A-MATH',
        'https://meet.edushamiit.com/c/10A-math',
        'RECORDING', TRUE, 'Marked (92.7%)', NOW()
    ) ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        status = 'live',
        is_live = TRUE,
        viewer_count = 42,
        max_participants = 45,
        target_class = 'Class 10 - A',
        room_code = '10A-MATH',
        meeting_link = 'https://meet.edushamiit.com/c/10A-math',
        recording_status = 'RECORDING',
        scheduled_at = CURRENT_DATE + TIME '08:00:00';

    -- 2. Class 11 - A : Physics | Upcoming
    INSERT INTO public.live_classes (
        id, school_id, class_id, section_id, subject_id, teacher_id, co_host_id,
        title, description, scheduled_at, duration_minutes, target_class,
        status, is_live, viewer_count, max_participants, room_code,
        meeting_link, recording_status, recording_enabled, created_at
    ) VALUES (
        'c1000000-0000-0000-0000-000000000011'::UUID,
        v_school_id, v_cls_11, NULL, v_sub_phys, v_teacher_id, v_cohost_id,
        'Laws of Motion (Introduction)',
        'Newtonian mechanics, inertia, and free-body diagram applications',
        CURRENT_DATE + TIME '10:00:00',
        45, 'Class 11 - A',
        'upcoming', FALSE, 38, 40, '11A-PHYS',
        'https://meet.edushamiit.com/c/11A-phys',
        'IDLE', TRUE, NOW()
    ) ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        status = 'upcoming',
        is_live = FALSE,
        viewer_count = 38,
        max_participants = 40,
        target_class = 'Class 11 - A',
        room_code = '11A-PHYS',
        scheduled_at = CURRENT_DATE + TIME '10:00:00';

    -- 3. Class 8 - A : English | Upcoming
    INSERT INTO public.live_classes (
        id, school_id, class_id, section_id, subject_id, teacher_id, co_host_id,
        title, description, scheduled_at, duration_minutes, target_class,
        status, is_live, viewer_count, max_participants, room_code,
        meeting_link, recording_status, recording_enabled, created_at
    ) VALUES (
        'c1000000-0000-0000-0000-000000000012'::UUID,
        v_school_id, v_cls_8, NULL, v_sub_eng, v_teacher_id, v_cohost_id,
        'Poetry – The Road Not Taken',
        'Robert Frost poetic devices, symbolism, and moral dilemmas in decision making',
        CURRENT_DATE + TIME '11:15:00',
        45, 'Class 8 - A',
        'upcoming', FALSE, 40, 42, '8A-ENG',
        'https://meet.edushamiit.com/c/8A-eng',
        'IDLE', TRUE, NOW()
    ) ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        status = 'upcoming',
        is_live = FALSE,
        viewer_count = 40,
        max_participants = 42,
        target_class = 'Class 8 - A',
        room_code = '8A-ENG',
        scheduled_at = CURRENT_DATE + TIME '11:15:00';

    -- 4. Class 9 - B : Science | Completed
    INSERT INTO public.live_classes (
        id, school_id, class_id, section_id, subject_id, teacher_id, co_host_id,
        title, description, scheduled_at, duration_minutes, target_class,
        status, is_live, viewer_count, max_participants, room_code,
        meeting_link, recording_status, recording_enabled, created_at, ended_at
    ) VALUES (
        'c1000000-0000-0000-0000-000000000013'::UUID,
        v_school_id, v_cls_9, NULL, v_sub_sci, v_teacher_id, v_cohost_id,
        'Matter and its Properties',
        'Physical and chemical classification of states of matter and phase change latent heat',
        CURRENT_DATE + TIME '14:00:00',
        45, 'Class 9 - B',
        'completed', FALSE, 41, 41, '9B-SCI',
        'https://meet.edushamiit.com/c/9B-sci',
        'READY', TRUE, NOW(), CURRENT_DATE + TIME '14:45:00'
    ) ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        status = 'completed',
        is_live = FALSE,
        viewer_count = 41,
        max_participants = 41,
        target_class = 'Class 9 - B',
        room_code = '9B-SCI',
        scheduled_at = CURRENT_DATE + TIME '14:00:00';

    -- 5. Class 12 - A : Chemistry | Scheduled (Tomorrow)
    INSERT INTO public.live_classes (
        id, school_id, class_id, section_id, subject_id, teacher_id, co_host_id,
        title, description, scheduled_at, duration_minutes, target_class,
        status, is_live, viewer_count, max_participants, room_code,
        meeting_link, recording_status, recording_enabled, created_at
    ) VALUES (
        'c1000000-0000-0000-0000-000000000014'::UUID,
        v_school_id, v_cls_12, NULL, v_sub_chem, v_teacher_id, v_cohost_id,
        'Organic Compounds – Introduction',
        'Hybridization, IUPAC nomenclature, and electrophilic substitution mechanisms',
        (CURRENT_DATE + INTERVAL '1 day') + TIME '08:00:00',
        45, 'Class 12 - A',
        'scheduled', FALSE, 43, 45, '12A-CHEM',
        'https://meet.edushamiit.com/c/12A-chem',
        'IDLE', TRUE, NOW()
    ) ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        status = 'scheduled',
        is_live = FALSE,
        viewer_count = 43,
        max_participants = 45,
        target_class = 'Class 12 - A',
        room_code = '12A-CHEM',
        scheduled_at = (CURRENT_DATE + INTERVAL '1 day') + TIME '08:00:00';
END;
$$;
