-- ============================================================================
-- Migration: 435_enterprise_examinations_system.sql
-- Description: Comprehensive Enterprise Examination Management System
--   1. Extend public.exams with enterprise fields: exam_code, academic_session,
--      applicable_sections, exam_mode, exam_purpose, passing_criteria,
--      grading_scheme_id, total_students_appeared, total_students_passed,
--      pass_percentage, average_score, highest_score, lowest_score,
--      is_published, results_published_at, schedule_status.
--   2. Create public.exam_schedules (subject-wise date sheets, halls, invigilators).
--   3. Create public.exam_marks_entries (multi-component marks entry & approval).
--   4. Create public.exam_grading_schemes and public.exam_grading_details.
--   5. Create public.exam_activity_logs (audit logging for all exam operations).
--   6. Performance indexes for fast querying, multi-tenancy, and conflict checking.
--   7. Seed lookup keys & values: EXAM_CATEGORY, EXAM_STATUS, EXAM_MODE,
--      ATTENDANCE_STATUS, GRADING_SCHEME.
--   8. Seed exact 24 exams, schedules, top performers, and audit activities
--      matching reference dashboard (media_1794288001777_d0272a47.jpg).
-- ============================================================================

-- 1. EXTEND public.exams
ALTER TABLE public.exams
    ADD COLUMN IF NOT EXISTS exam_code VARCHAR(50),
    ADD COLUMN IF NOT EXISTS academic_session VARCHAR(100) DEFAULT '2025-26',
    ADD COLUMN IF NOT EXISTS applicable_sections JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS exam_mode VARCHAR(50) DEFAULT 'offline',
    ADD COLUMN IF NOT EXISTS exam_purpose VARCHAR(100) DEFAULT 'Summative Assessment',
    ADD COLUMN IF NOT EXISTS passing_criteria JSONB DEFAULT '{"passing_percentage": 33, "theory_min": 25, "practical_min": 10}'::jsonb,
    ADD COLUMN IF NOT EXISTS grading_scheme_id UUID,
    ADD COLUMN IF NOT EXISTS total_students_appeared INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS total_students_passed INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS pass_percentage NUMERIC(5,2) DEFAULT 0.0,
    ADD COLUMN IF NOT EXISTS average_score NUMERIC(5,2) DEFAULT 0.0,
    ADD COLUMN IF NOT EXISTS highest_score NUMERIC(5,2) DEFAULT 0.0,
    ADD COLUMN IF NOT EXISTS lowest_score NUMERIC(5,2) DEFAULT 0.0,
    ADD COLUMN IF NOT EXISTS is_published BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS schedule_status VARCHAR(50) DEFAULT 'draft';

-- 2. CREATE public.exam_schedules TABLE
CREATE TABLE IF NOT EXISTS public.exam_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    academic_session VARCHAR(100) DEFAULT '2025-26',
    class_name VARCHAR(100) NOT NULL,
    section_name VARCHAR(100),
    subject_id UUID REFERENCES public.subjects(id) ON DELETE SET NULL,
    subject_name VARCHAR(150) NOT NULL,
    exam_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    duration_minutes INT DEFAULT 120,
    max_marks NUMERIC(8,2) DEFAULT 100.0,
    passing_marks NUMERIC(8,2) DEFAULT 33.0,
    exam_mode VARCHAR(50) DEFAULT 'offline',
    room_number VARCHAR(100),
    invigilator_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    invigilator_name VARCHAR(255),
    instructions TEXT,
    status VARCHAR(50) DEFAULT 'scheduled', -- scheduled, ongoing, completed, cancelled
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. CREATE public.exam_marks_entries TABLE
CREATE TABLE IF NOT EXISTS public.exam_marks_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    schedule_id UUID REFERENCES public.exam_schedules(id) ON DELETE SET NULL,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    subject_id UUID REFERENCES public.subjects(id) ON DELETE SET NULL,
    roll_number VARCHAR(50),
    admission_number VARCHAR(50),
    student_name VARCHAR(255),
    class_name VARCHAR(100),
    section_name VARCHAR(100),
    attendance_status VARCHAR(50) DEFAULT 'present', -- present, absent, medical_leave, exempted, malpractice, withheld
    theory_marks NUMERIC(8,2) DEFAULT 0.0,
    practical_marks NUMERIC(8,2) DEFAULT 0.0,
    internal_marks NUMERIC(8,2) DEFAULT 0.0,
    total_marks_obtained NUMERIC(8,2) DEFAULT 0.0,
    max_marks NUMERIC(8,2) DEFAULT 100.0,
    percentage NUMERIC(5,2) DEFAULT 0.0,
    grade VARCHAR(10),
    result_status VARCHAR(50) DEFAULT 'pass', -- pass, fail, withheld, exempted, absent
    remarks TEXT,
    approval_status VARCHAR(50) DEFAULT 'draft', -- draft, submitted, approved, locked, returned
    entered_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. CREATE GRADING SCHEME TABLES
CREATE TABLE IF NOT EXISTS public.exam_grading_schemes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.exam_grading_details (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scheme_id UUID NOT NULL REFERENCES public.exam_grading_schemes(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    grade VARCHAR(20) NOT NULL,
    min_percentage NUMERIC(5,2) NOT NULL,
    max_percentage NUMERIC(5,2) NOT NULL,
    grade_point NUMERIC(4,2) DEFAULT 0.0,
    remarks VARCHAR(255),
    is_passing BOOLEAN DEFAULT true,
    display_order INT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. CREATE ACTIVITY LOGS TABLE
CREATE TABLE IF NOT EXISTS public.exam_activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    exam_id UUID REFERENCES public.exams(id) ON DELETE CASCADE,
    action VARCHAR(100) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    details JSONB DEFAULT '{}'::jsonb,
    performed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    performed_by_name VARCHAR(255),
    icon VARCHAR(50) DEFAULT 'event_note',
    color VARCHAR(30) DEFAULT 'blue',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. PERFORMANCE INDEXES
CREATE INDEX IF NOT EXISTS idx_exam_schedules_school_date ON public.exam_schedules(school_id, exam_date);
CREATE INDEX IF NOT EXISTS idx_exam_schedules_exam ON public.exam_schedules(exam_id);
CREATE INDEX IF NOT EXISTS idx_exam_schedules_class ON public.exam_schedules(school_id, class_name);
CREATE INDEX IF NOT EXISTS idx_exam_marks_exam_student ON public.exam_marks_entries(exam_id, student_id);
CREATE INDEX IF NOT EXISTS idx_exam_marks_schedule ON public.exam_marks_entries(schedule_id);
CREATE INDEX IF NOT EXISTS idx_exam_activity_school ON public.exam_activity_logs(school_id, created_at DESC);

-- 7. SEED LOOKUP KEYS & VALUES
DO $$
DECLARE
    s RECORD;
    v_key_id UUID;
    v_admin_id UUID;
    v_scheme_id UUID;
BEGIN
    FOR s IN SELECT id FROM public.schools LOOP
        SELECT id INTO v_admin_id FROM public.profiles WHERE school_id = s.id AND role IN ('admin', 'super_admin') LIMIT 1;
        IF v_admin_id IS NULL THEN
            SELECT id INTO v_admin_id FROM public.profiles LIMIT 1;
        END IF;

        -- 7.1 EXAM_CATEGORY
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'EXAM_CATEGORY';
        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Exam Category', 'EXAM_CATEGORY', 'Standard classifications of school assessments', 'SYSTEM', 'event_note_outlined', 'ACTIVE', v_admin_id)
            RETURNING id INTO v_key_id;
        END IF;

        INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by)
        VALUES
            (v_key_id, s.id, 'Final Exam', 'FINAL_EXAM', 'Annual summative evaluation', 'ACTIVE', 1, v_admin_id),
            (v_key_id, s.id, 'Mid Term', 'MID_TERM', 'Half-yearly term assessment', 'ACTIVE', 2, v_admin_id),
            (v_key_id, s.id, 'Unit Test', 'UNIT_TEST', 'Periodic chapter test', 'ACTIVE', 3, v_admin_id),
            (v_key_id, s.id, 'Pre Board', 'PRE_BOARD', 'Pre-board preparatory exam', 'ACTIVE', 4, v_admin_id),
            (v_key_id, s.id, 'Half Yearly', 'HALF_YEARLY', 'Mid-session comprehensive test', 'ACTIVE', 5, v_admin_id),
            (v_key_id, s.id, 'Quarterly', 'QUARTERLY', 'Quarterly milestone exam', 'ACTIVE', 6, v_admin_id),
            (v_key_id, s.id, 'Practical Exam', 'PRACTICAL', 'Laboratory and viva exam', 'ACTIVE', 7, v_admin_id)
        ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;

        -- 7.2 EXAM_STATUS
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'EXAM_STATUS';
        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Exam Status', 'EXAM_STATUS', 'Lifecycle statuses of examinations', 'SYSTEM', 'flag_outlined', 'ACTIVE', v_admin_id)
            RETURNING id INTO v_key_id;
        END IF;

        INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by)
        VALUES
            (v_key_id, s.id, 'Scheduled', 'SCHEDULED', 'Exam scheduled and ready', 'ACTIVE', 1, v_admin_id),
            (v_key_id, s.id, 'Ongoing', 'ONGOING', 'Exam actively in progress', 'ACTIVE', 2, v_admin_id),
            (v_key_id, s.id, 'Completed', 'COMPLETED', 'Exam concluded', 'ACTIVE', 3, v_admin_id),
            (v_key_id, s.id, 'Draft', 'DRAFT', 'Exam in draft configuration', 'ACTIVE', 4, v_admin_id),
            (v_key_id, s.id, 'Evaluation Pending', 'EVALUATION_PENDING', 'Marks entry pending review', 'ACTIVE', 5, v_admin_id),
            (v_key_id, s.id, 'Published', 'PUBLISHED', 'Results published to students', 'ACTIVE', 6, v_admin_id),
            (v_key_id, s.id, 'Cancelled', 'CANCELLED', 'Exam officially cancelled', 'ACTIVE', 7, v_admin_id)
        ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;

        -- 7.3 DEFAULT CBSE GRADING SCHEME
        SELECT id INTO v_scheme_id FROM public.exam_grading_schemes WHERE school_id = s.id AND name = 'CBSE 9-Point Grading Scale';
        IF v_scheme_id IS NULL THEN
            INSERT INTO public.exam_grading_schemes (school_id, name, description, is_default)
            VALUES (s.id, 'CBSE 9-Point Grading Scale', 'Standard CBSE secondary assessment scale', true)
            RETURNING id INTO v_scheme_id;

            INSERT INTO public.exam_grading_details (scheme_id, school_id, grade, min_percentage, max_percentage, grade_point, remarks, is_passing, display_order)
            VALUES
                (v_scheme_id, s.id, 'A1', 91.0, 100.0, 10.0, 'Outstanding', true, 1),
                (v_scheme_id, s.id, 'A2', 81.0, 90.9, 9.0, 'Excellent', true, 2),
                (v_scheme_id, s.id, 'B1', 71.0, 80.9, 8.0, 'Very Good', true, 3),
                (v_scheme_id, s.id, 'B2', 61.0, 70.9, 7.0, 'Good', true, 4),
                (v_scheme_id, s.id, 'C1', 51.0, 60.9, 6.0, 'Above Average', true, 5),
                (v_scheme_id, s.id, 'C2', 41.0, 50.9, 5.0, 'Average', true, 6),
                (v_scheme_id, s.id, 'D', 33.0, 40.9, 4.0, 'Marginal Pass', true, 7),
                (v_scheme_id, s.id, 'E', 0.0, 32.9, 0.0, 'Needs Improvement', false, 8);
        END IF;

        -- 7.4 EXAM_MODE
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'EXAM_MODE';
        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Exam Mode', 'EXAM_MODE', 'Delivery mode of examination', 'SYSTEM', 'devices', 'ACTIVE', v_admin_id)
            RETURNING id INTO v_key_id;
        END IF;

        INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by)
        VALUES
            (v_key_id, s.id, 'Offline (Pen & Paper)', 'OFFLINE', 'Traditional written paper exam', 'ACTIVE', 1, v_admin_id),
            (v_key_id, s.id, 'Online (Computer Based)', 'ONLINE', 'CBT online proctored exam', 'ACTIVE', 2, v_admin_id),
            (v_key_id, s.id, 'Hybrid', 'HYBRID', 'Blended online and practical assessment', 'ACTIVE', 3, v_admin_id)
        ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;

        -- 7.5 ATTENDANCE_STATUS
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'ATTENDANCE_STATUS';
        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Exam Attendance Status', 'ATTENDANCE_STATUS', 'Student presence status for exams', 'SYSTEM', 'how_to_reg', 'ACTIVE', v_admin_id)
            RETURNING id INTO v_key_id;
        END IF;

        INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by)
        VALUES
            (v_key_id, s.id, 'Present', 'PRESENT', 'Student appeared in exam', 'ACTIVE', 1, v_admin_id),
            (v_key_id, s.id, 'Absent', 'ABSENT', 'Student absent without leave', 'ACTIVE', 2, v_admin_id),
            (v_key_id, s.id, 'Excused', 'EXCUSED', 'Medical or approved absence', 'ACTIVE', 3, v_admin_id),
            (v_key_id, s.id, 'Disqualified', 'DISQUALIFIED', 'Unfair means or malpractice', 'ACTIVE', 4, v_admin_id)
        ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;

    END LOOP;
END $$;

-- 8. SEED REFERENCE DASHBOARD DATA (24 EXAMS, KPIS, TOP PERFORMERS, ACTIVITIES)
DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_admin_id UUID;
    v_sub_math UUID;
    v_sub_sci UUID;
    v_sub_eng UUID;
    v_sub_soc UUID;
    v_flagship_id UUID;
BEGIN
    SELECT id INTO v_admin_id FROM public.profiles WHERE school_id = v_school_id AND role IN ('admin', 'super_admin') LIMIT 1;
    SELECT id INTO v_sub_math FROM public.subjects WHERE school_id = v_school_id AND name ILIKE '%Math%' LIMIT 1;
    SELECT id INTO v_sub_sci FROM public.subjects WHERE school_id = v_school_id AND name ILIKE '%Sci%' LIMIT 1;
    SELECT id INTO v_sub_eng FROM public.subjects WHERE school_id = v_school_id AND name ILIKE '%Eng%' LIMIT 1;
    SELECT id INTO v_sub_soc FROM public.subjects WHERE school_id = v_school_id AND name ILIKE '%Social%' LIMIT 1;

    IF v_sub_math IS NULL THEN SELECT id INTO v_sub_math FROM public.subjects WHERE school_id = v_school_id LIMIT 1; END IF;
    IF v_sub_sci IS NULL THEN v_sub_sci := v_sub_math; END IF;
    IF v_sub_eng IS NULL THEN v_sub_eng := v_sub_math; END IF;
    IF v_sub_soc IS NULL THEN v_sub_soc := v_sub_math; END IF;

    -- Update or ensure flagship Annual Examination 2025-26
    SELECT id INTO v_flagship_id FROM public.exams WHERE school_id = v_school_id AND title = 'Annual Examination 2025-26';
    IF v_flagship_id IS NOT NULL THEN
        UPDATE public.exams SET
            exam_code = 'EX-2026-001',
            exam_category = 'Final Exam',
            paper_type = 'Final Exam',
            status = 'scheduled',
            exam_date = '2026-03-15',
            start_time = '2026-03-15 09:00:00+00',
            end_time = '2026-03-15 11:00:00+00',
            duration_minutes = 120,
            total_marks = 100,
            passing_marks = 33,
            target_classes = '["Class 10"]'::jsonb,
            applicable_sections = '["10-A", "10-B"]'::jsonb,
            total_students_appeared = 120,
            total_students_passed = 116,
            pass_percentage = 96.67,
            average_score = 79.4,
            is_published = true
        WHERE id = v_flagship_id;
    END IF;

    -- Helper temporary table for reference exams (Total 24 exams: 3 upcoming, 1 ongoing, 20 completed)
    CREATE TEMP TABLE tmp_ref_exams (
        title TEXT,
        class_name TEXT,
        category TEXT,
        exam_date DATE,
        start_time_str TEXT,
        status TEXT,
        total_marks INT,
        appeared INT,
        passed INT,
        avg_score NUMERIC(5,2),
        pass_pct NUMERIC(5,2)
    ) ON COMMIT DROP;

    INSERT INTO tmp_ref_exams VALUES
        ('Mid Term Examination', 'Class 9', 'Mid Term', '2026-01-20', '09:00:00', 'completed', 100, 85, 82, 78.5, 96.4),
        ('Pre Board Examination', 'Class 12', 'Pre Board', '2026-01-10', '09:00:00', 'completed', 100, 65, 62, 81.2, 95.3),
        ('Half Yearly Examination', 'Class 8', 'Half Yearly', '2025-09-25', '09:00:00', 'completed', 100, 90, 87, 76.4, 96.6),
        ('Unit Test - 2', 'Class 7', 'Unit Test', '2025-08-30', '10:00:00', 'completed', 50, 92, 89, 79.0, 96.7),
        ('Unit Test - 1', 'Class 6', 'Unit Test', '2025-07-25', '10:00:00', 'completed', 50, 95, 92, 80.1, 96.8),
        ('Annual Examination 2024-25', 'Class 11', 'Final Exam', '2025-03-20', '09:00:00', 'completed', 100, 70, 67, 75.8, 95.7),
        ('Mid Term Examination', 'Class 10', 'Mid Term', '2024-12-15', '09:00:00', 'completed', 100, 118, 113, 77.3, 95.8),
        ('Pre Board Examination', 'Class 12', 'Pre Board', '2025-01-12', '09:00:00', 'completed', 100, 64, 61, 82.0, 95.3),
        ('Unit Test - 2', 'Class 5', 'Unit Test', '2024-11-30', '10:00:00', 'completed', 50, 88, 85, 83.4, 96.5),
        ('Unit Test - 1', 'Class 8', 'Unit Test', '2025-07-15', '10:00:00', 'completed', 50, 89, 86, 78.0, 96.6),
        ('Quarterly Assessment', 'Class 9', 'Quarterly', '2025-09-10', '09:00:00', 'completed', 50, 84, 80, 76.0, 95.2),
        ('Mid Term Examination', 'Class 7', 'Mid Term', '2025-10-14', '09:00:00', 'completed', 100, 91, 88, 77.8, 96.7),
        ('Practical Assessment', 'Class 12', 'Practical Exam', '2026-01-18', '09:00:00', 'completed', 30, 65, 65, 92.4, 100.0),
        ('Science Diagnostic Exam', 'Class 10', 'Unit Test', '2025-08-12', '09:00:00', 'completed', 50, 115, 110, 79.2, 95.6),
        ('Mathematics Olympiad Simulation', 'Class 10', 'Unit Test', '2025-11-05', '09:00:00', 'completed', 50, 112, 108, 81.5, 96.4),
        ('English Language Assessment', 'Class 9', 'Unit Test', '2025-10-22', '10:00:00', 'completed', 50, 85, 83, 84.1, 97.6),
        ('Social Sciences Half Yearly', 'Class 8', 'Half Yearly', '2025-09-28', '09:00:00', 'completed', 100, 89, 85, 75.2, 95.5),
        ('Computer Science Lab Exam', 'Class 11', 'Practical Exam', '2025-11-18', '11:00:00', 'completed', 50, 68, 67, 88.5, 98.5),
        ('Hindi Summative Assessment', 'Class 6', 'Quarterly', '2025-09-05', '09:00:00', 'completed', 50, 94, 91, 79.8, 96.8),
        ('Environmental Studies Test', 'Class 5', 'Unit Test', '2025-08-20', '10:00:00', 'completed', 50, 86, 84, 85.0, 97.6),
        -- 1 Ongoing Exam
        ('Class 10 Revision Mock Test', 'Class 10', 'Unit Test', CURRENT_DATE, '09:00:00', 'ongoing', 50, 118, 112, 78.5, 94.9),
        -- 2 Additional Upcoming Exams (making 3 upcoming total with Annual Exam)
        ('Senior Secondary Pre-Board II', 'Class 12', 'Pre Board', '2026-03-25', '09:00:00', 'scheduled', 100, 65, 62, 80.0, 95.0),
        ('Class 9 Annual Assessment', 'Class 9', 'Final Exam', '2026-03-28', '09:00:00', 'scheduled', 100, 85, 82, 77.0, 96.0);

    -- Insert into exams if not already present
    INSERT INTO public.exams (
        school_id, subject_id, title, description, duration_minutes, total_marks, passing_marks,
        exam_date, start_time, end_time, status, exam_type, exam_category, target_classes,
        applicable_sections, paper_type, paper_status, academic_session,
        schedule_status,
        total_students_appeared, total_students_passed, pass_percentage, average_score,
        is_published, created_by
    )
    SELECT
        v_school_id,
        v_sub_math,
        t.title,
        'Official institutional assessment for ' || t.class_name,
        120,
        t.total_marks,
        CAST(t.total_marks * 0.33 AS INT),
        t.exam_date,
        (t.exam_date || ' ' || t.start_time_str)::timestamptz,
        (t.exam_date || ' ' || t.start_time_str)::timestamptz + interval '2 hours',
        t.status,
        'offline',
        t.category,
        jsonb_build_array(t.class_name),
        '["A", "B"]'::jsonb,
        t.category,
        CASE WHEN t.status = 'scheduled' THEN 'Approved' ELSE 'Published' END,
        '2025-26',
        t.status,
        t.appeared,
        t.passed,
        t.pass_pct,
        t.avg_score,
        CASE WHEN t.status = 'completed' THEN true ELSE false END,
        v_admin_id
    FROM tmp_ref_exams t
    WHERE NOT EXISTS (
        SELECT 1 FROM public.exams WHERE school_id = v_school_id AND title = t.title AND target_classes = jsonb_build_array(t.class_name)
    );

    -- Seed Recent Activities
    DELETE FROM public.exam_activity_logs WHERE school_id = v_school_id;
    INSERT INTO public.exam_activity_logs (school_id, action, title, description, icon, color, created_at)
    VALUES
        (v_school_id, 'RESULTS_PUBLISHED', 'Mid Term Results Published', 'Class 9 • 01 Mar 2026, 04:30 PM', 'check_circle', 'green', '2026-03-01 16:30:00+00'),
        (v_school_id, 'EXAM_SCHEDULED', 'Annual Exam Scheduled', 'Class 10 • 01 Mar 2026, 11:20 AM', 'calendar_today', 'blue', '2026-03-01 11:20:00+00'),
        (v_school_id, 'QUESTION_PAPER_UPLOADED', 'Question Paper Uploaded', 'Class 12 • 28 Feb 2026, 05:15 PM', 'description', 'purple', '2026-02-28 17:15:00+00');

    -- Seed sample schedules for Annual Exam 2025-26 (Date Sheet)
    DELETE FROM public.exam_schedules WHERE exam_id = v_flagship_id;
    INSERT INTO public.exam_schedules (
        school_id, exam_id, academic_session, class_name, section_name, subject_id, subject_name,
        exam_date, start_time, end_time, duration_minutes, max_marks, passing_marks, room_number, invigilator_name, status
    ) VALUES
        (v_school_id, v_flagship_id, '2025-26', 'Class 10', 'A', v_sub_math, 'Mathematics', '2026-03-15', '09:00:00', '11:00:00', 120, 100, 33, 'Hall 101', 'Dr. Sharma', 'scheduled'),
        (v_school_id, v_flagship_id, '2025-26', 'Class 10', 'A', v_sub_sci, 'Science', '2026-03-18', '09:00:00', '11:00:00', 120, 100, 33, 'Hall 102', 'Prof. Verma', 'scheduled'),
        (v_school_id, v_flagship_id, '2025-26', 'Class 10', 'A', v_sub_eng, 'English Language', '2026-03-21', '09:00:00', '11:00:00', 120, 100, 33, 'Hall 103', 'Mrs. Gupta', 'scheduled'),
        (v_school_id, v_flagship_id, '2025-26', 'Class 10', 'A', v_sub_soc, 'Social Studies', '2026-03-24', '09:00:00', '11:00:00', 120, 100, 33, 'Hall 104', 'Mr. Singh', 'scheduled');

END $$;
