-- ============================================================================
-- Migration: 434_enterprise_build_paper_system.sql
-- Description: Comprehensive Enterprise Build Paper System
--   1. Create public.exam_sections table for multi-section question papers.
--   2. Extend public.exam_questions with section_id, section_name,
--      question_bank_id, difficulty, chapter, negative_marks, explanation,
--      model_answer, is_mandatory, internal_choice_group_id, snapshot_data.
--   3. Extend public.exams with paper_type, paper_status, academic_session,
--      total_sections, total_questions_count.
--   4. Create public.exam_paper_blueprints and public.exam_paper_versions.
--   5. Seed lookup keys and values: PAPER_TYPE, PAPER_STATUS, SECTION_TYPE.
--   6. High performance indexes for multi-tenant querying and section ordering.
--   7. Seed/link the flagship "Annual Examination 2025-26" exam with Sections A, B, C
--      matching reference UI (media_1794287816503_8b897180.jpg).
-- ============================================================================

-- 1. CREATE public.exam_sections TABLE
CREATE TABLE IF NOT EXISTS public.exam_sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    section_code VARCHAR(50) DEFAULT 'A',
    description TEXT,
    instructions TEXT,
    sequence_number INT NOT NULL DEFAULT 1,
    marks_per_question NUMERIC(8,2) DEFAULT 1.0,
    max_marks NUMERIC(8,2) DEFAULT 0.0,
    min_attempt INT DEFAULT 0,
    max_attempt INT DEFAULT 0,
    is_optional BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. EXTEND public.exam_questions
ALTER TABLE public.exam_questions
    ADD COLUMN IF NOT EXISTS section_id UUID REFERENCES public.exam_sections(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS section_name VARCHAR(150),
    ADD COLUMN IF NOT EXISTS question_bank_id UUID REFERENCES public.question_bank(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS difficulty VARCHAR(50) DEFAULT 'Easy',
    ADD COLUMN IF NOT EXISTS chapter VARCHAR(255),
    ADD COLUMN IF NOT EXISTS negative_marks NUMERIC(8,2) DEFAULT 0.0,
    ADD COLUMN IF NOT EXISTS explanation TEXT,
    ADD COLUMN IF NOT EXISTS model_answer TEXT,
    ADD COLUMN IF NOT EXISTS is_mandatory BOOLEAN DEFAULT true,
    ADD COLUMN IF NOT EXISTS internal_choice_group_id UUID,
    ADD COLUMN IF NOT EXISTS snapshot_data JSONB DEFAULT '{}'::jsonb;

-- 3. EXTEND public.exams
ALTER TABLE public.exams
    ADD COLUMN IF NOT EXISTS paper_type VARCHAR(100) DEFAULT 'Final Exam',
    ADD COLUMN IF NOT EXISTS paper_status VARCHAR(50) DEFAULT 'Draft',
    ADD COLUMN IF NOT EXISTS academic_session VARCHAR(100) DEFAULT '2025-26',
    ADD COLUMN IF NOT EXISTS blueprint_id UUID,
    ADD COLUMN IF NOT EXISTS total_sections INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS total_questions_count INT DEFAULT 0;

-- 4. CREATE BLUEPRINT & VERSION HISTORY TABLES
CREATE TABLE IF NOT EXISTS public.exam_paper_blueprints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    class_name VARCHAR(100),
    subject_name VARCHAR(100),
    total_marks NUMERIC(8,2) DEFAULT 100.0,
    duration_minutes INT DEFAULT 120,
    distribution JSONB DEFAULT '[]'::jsonb,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.exam_paper_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    version_number INT NOT NULL DEFAULT 1,
    paper_title VARCHAR(255) NOT NULL,
    snapshot JSONB NOT NULL,
    saved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. PERFORMANCE INDEXES
CREATE INDEX IF NOT EXISTS idx_exam_sections_exam_seq ON public.exam_sections(exam_id, sequence_number);
CREATE INDEX IF NOT EXISTS idx_exam_questions_section ON public.exam_questions(section_id, order_number);
CREATE INDEX IF NOT EXISTS idx_exam_questions_exam_order ON public.exam_questions(exam_id, order_number);
CREATE INDEX IF NOT EXISTS idx_exam_paper_versions_exam ON public.exam_paper_versions(exam_id, version_number);

-- 6. SEED LOOKUP KEYS & VALUES FOR ALL SCHOOLS
DO $$
DECLARE
    s RECORD;
    v_key_id UUID;
    v_admin_id UUID;
BEGIN
    FOR s IN SELECT id FROM public.schools LOOP
        SELECT id INTO v_admin_id FROM public.profiles WHERE school_id = s.id AND role IN ('admin', 'super_admin') LIMIT 1;
        IF v_admin_id IS NULL THEN
            SELECT id INTO v_admin_id FROM public.profiles LIMIT 1;
        END IF;

        -- 6.1 PAPER_TYPE
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'PAPER_TYPE';
        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Paper Type', 'PAPER_TYPE', 'Classification of examination question papers', 'SYSTEM', 'description_outlined', 'ACTIVE', v_admin_id)
            RETURNING id INTO v_key_id;
        END IF;

        INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by)
        VALUES
            (v_key_id, s.id, 'Final Exam', 'FINAL_EXAM', 'Comprehensive end-of-year examination paper', 'ACTIVE', 1, v_admin_id),
            (v_key_id, s.id, 'Unit Test', 'UNIT_TEST', 'Periodic chapter-wise assessment paper', 'ACTIVE', 2, v_admin_id),
            (v_key_id, s.id, 'Half Yearly', 'HALF_YEARLY', 'Mid-session term examination paper', 'ACTIVE', 3, v_admin_id),
            (v_key_id, s.id, 'Annual Examination', 'ANNUAL_EXAM', 'Annual summative evaluation paper', 'ACTIVE', 4, v_admin_id),
            (v_key_id, s.id, 'Monthly Test', 'MONTHLY_TEST', 'Monthly continuous evaluation paper', 'ACTIVE', 5, v_admin_id),
            (v_key_id, s.id, 'Mock Test', 'MOCK_TEST', 'Simulated practice paper before board or finals', 'ACTIVE', 6, v_admin_id),
            (v_key_id, s.id, 'Practical Exam', 'PRACTICAL', 'Laboratory, viva, or clinical practical paper', 'ACTIVE', 7, v_admin_id),
            (v_key_id, s.id, 'Class Test', 'CLASS_TEST', 'Informal classroom spot or revision test', 'ACTIVE', 8, v_admin_id)
        ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;

        -- 6.2 PAPER_STATUS
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'PAPER_STATUS';
        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Paper Status', 'PAPER_STATUS', 'Workflow lifecycle status of question papers', 'SYSTEM', 'flag_outlined', 'ACTIVE', v_admin_id)
            RETURNING id INTO v_key_id;
        END IF;

        INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by)
        VALUES
            (v_key_id, s.id, 'Draft', 'DRAFT', 'Paper is being authored by teacher or coordinator', 'ACTIVE', 1, v_admin_id),
            (v_key_id, s.id, 'In Review', 'IN_REVIEW', 'Submitted to HOD or examination cell for review', 'ACTIVE', 2, v_admin_id),
            (v_key_id, s.id, 'Approved', 'APPROVED', 'Paper verified, proofread and approved for printing', 'ACTIVE', 3, v_admin_id),
            (v_key_id, s.id, 'Published', 'PUBLISHED', 'Released for active conduct or printed distribution', 'ACTIVE', 4, v_admin_id),
            (v_key_id, s.id, 'Archived', 'ARCHIVED', 'Historical examination paper preserved in archives', 'ACTIVE', 5, v_admin_id)
        ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;

        -- 6.3 SECTION_TYPE
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'SECTION_TYPE';
        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Section Type', 'SECTION_TYPE', 'Predefined section structural categories', 'SYSTEM', 'view_agenda_outlined', 'ACTIVE', v_admin_id)
            RETURNING id INTO v_key_id;
        END IF;

        INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by)
        VALUES
            (v_key_id, s.id, 'Multiple Choice Questions', 'MCQ_SECTION', 'Objective questions with multiple choices', 'ACTIVE', 1, v_admin_id),
            (v_key_id, s.id, 'Short Answer Questions', 'SHORT_SECTION', 'Concise short subjective or numerical steps', 'ACTIVE', 2, v_admin_id),
            (v_key_id, s.id, 'Long Answer Questions', 'LONG_SECTION', 'Detailed derivations, proofs, or essay solutions', 'ACTIVE', 3, v_admin_id),
            (v_key_id, s.id, 'Assertion and Reason', 'ASSERTION_REASON_SECTION', 'Logical evaluation of assertions and reasons', 'ACTIVE', 4, v_admin_id),
            (v_key_id, s.id, 'Case Study / Passage', 'CASE_STUDY_SECTION', 'Comprehension passage followed by sub-questions', 'ACTIVE', 5, v_admin_id),
            (v_key_id, s.id, 'Fill in the Blanks', 'FILL_BLANKS_SECTION', 'Cloze sentences with blank items', 'ACTIVE', 6, v_admin_id),
            (v_key_id, s.id, 'Match the Following', 'MATCHING_SECTION', 'Column-wise pair matching questions', 'ACTIVE', 7, v_admin_id)
        ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;

    END LOOP;
END $$;

-- 7. SEED FLAGSHIP EXAM & SECTIONS (ANNUAL EXAMINATION 2025-26)
DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_admin_id UUID;
    v_subject_id UUID;
    v_exam_id UUID;
    v_sec_a_id UUID;
    v_sec_b_id UUID;
    v_sec_c_id UUID;
    v_qb_id UUID;
BEGIN
    SELECT id INTO v_admin_id FROM public.profiles WHERE school_id = v_school_id AND role IN ('admin', 'super_admin') LIMIT 1;
    SELECT id INTO v_subject_id FROM public.subjects WHERE school_id = v_school_id AND name ILIKE '%Math%' LIMIT 1;
    IF v_subject_id IS NULL THEN
        SELECT id INTO v_subject_id FROM public.subjects WHERE school_id = v_school_id LIMIT 1;
    END IF;

    -- Check if Annual Examination 2025-26 already exists or create it
    SELECT id INTO v_exam_id FROM public.exams WHERE school_id = v_school_id AND title = 'Annual Examination 2025-26';
    IF v_exam_id IS NULL THEN
        INSERT INTO public.exams (
            school_id, subject_id, title, description, duration_minutes, total_marks, passing_marks,
            exam_date, start_time, end_time, status, exam_type, exam_category, target_classes,
            paper_type, paper_status, academic_session, instructions, created_by
        ) VALUES (
            v_school_id, v_subject_id, 'Annual Examination 2025-26', 'Comprehensive Annual Mathematics Assessment for Class 10',
            120, 100, 33, '2026-03-15', '2026-03-15 09:00:00+00', '2026-03-15 11:00:00+00',
            'in_progress', 'offline', 'Final Exam', '["Class 10"]'::jsonb,
            'Final Exam', 'Draft', '2025-26',
            '1. All questions are compulsory. 2. Section A contains 5 MCQs of 1 mark each. 3. Section B contains 5 short answer questions of 2 marks each. 4. Section C contains 2 long answer questions of 5 marks each. 5. Use of calculators is not permitted.',
            v_admin_id
        ) RETURNING id INTO v_exam_id;
    ELSE
        UPDATE public.exams SET
            paper_type = 'Final Exam',
            paper_status = 'Draft',
            academic_session = '2025-26',
            total_marks = 100,
            duration_minutes = 120,
            exam_date = '2026-03-15',
            target_classes = '["Class 10"]'::jsonb,
            instructions = '1. All questions are compulsory. 2. Section A contains 5 MCQs of 1 mark each. 3. Section B contains 5 short answer questions of 2 marks each. 4. Section C contains 2 long answer questions of 5 marks each. 5. Use of calculators is not permitted.'
        WHERE id = v_exam_id;
    END IF;

    -- SECTION A
    SELECT id INTO v_sec_a_id FROM public.exam_sections WHERE exam_id = v_exam_id AND section_code = 'A';
    IF v_sec_a_id IS NULL THEN
        INSERT INTO public.exam_sections (
            school_id, exam_id, name, section_code, sequence_number, marks_per_question, max_marks, instructions
        ) VALUES (
            v_school_id, v_exam_id, 'Section A – Multiple Choice Questions (1 Mark Each)', 'A', 1, 1.0, 5.0,
            'Choose the correct option among the given alternatives. Each question carries 1 mark.'
        ) RETURNING id INTO v_sec_a_id;
    END IF;

    -- SECTION B
    SELECT id INTO v_sec_b_id FROM public.exam_sections WHERE exam_id = v_exam_id AND section_code = 'B';
    IF v_sec_b_id IS NULL THEN
        INSERT INTO public.exam_sections (
            school_id, exam_id, name, section_code, sequence_number, marks_per_question, max_marks, instructions
        ) VALUES (
            v_school_id, v_exam_id, 'Section B – Short Answer Questions (2 Marks Each)', 'B', 2, 2.0, 10.0,
            'Answer each question clearly with supporting steps. Each question carries 2 marks.'
        ) RETURNING id INTO v_sec_b_id;
    END IF;

    -- SECTION C
    SELECT id INTO v_sec_c_id FROM public.exam_sections WHERE exam_id = v_exam_id AND section_code = 'C';
    IF v_sec_c_id IS NULL THEN
        INSERT INTO public.exam_sections (
            school_id, exam_id, name, section_code, sequence_number, marks_per_question, max_marks, instructions
        ) VALUES (
            v_school_id, v_exam_id, 'Section C – Long Answer Questions (5 Marks Each)', 'C', 3, 5.0, 10.0,
            'Solve with complete proofs and neat diagrams where applicable. Each question carries 5 marks.'
        ) RETURNING id INTO v_sec_c_id;
    END IF;

    -- Clear existing questions for clean seed if re-running
    DELETE FROM public.exam_questions WHERE exam_id = v_exam_id;

    -- INSERT SECTION A QUESTIONS (5 MCQs, 1 mark each)
    -- Q1
    SELECT id INTO v_qb_id FROM public.question_bank WHERE school_id = v_school_id AND question_text ILIKE '%value of π%' LIMIT 1;
    INSERT INTO public.exam_questions (
        exam_id, school_id, section_id, section_name, question_bank_id,
        question_text, question_type, options, correct_answer, marks, order_number, difficulty, chapter
    ) VALUES (
        v_exam_id, v_school_id, v_sec_a_id, 'Section A', v_qb_id,
        'What is the value of π?', 'mcq',
        '[{"id": "A", "text": "2.14"}, {"id": "B", "text": "3.14"}, {"id": "C", "text": "4.14"}, {"id": "D", "text": "5.14"}]'::jsonb,
        'B', 1, 1, 'Easy', 'Circles'
    );

    -- Q2
    SELECT id INTO v_qb_id FROM public.question_bank WHERE school_id = v_school_id AND question_text ILIKE '%area of a circle%' LIMIT 1;
    INSERT INTO public.exam_questions (
        exam_id, school_id, section_id, section_name, question_bank_id,
        question_text, question_type, options, correct_answer, marks, order_number, difficulty, chapter
    ) VALUES (
        v_exam_id, v_school_id, v_sec_a_id, 'Section A', v_qb_id,
        'Which formula is used for area of a circle?', 'mcq',
        '[{"id": "A", "text": "2πr"}, {"id": "B", "text": "πr²"}, {"id": "C", "text": "πd"}, {"id": "D", "text": "2πr²"}]'::jsonb,
        'B', 1, 2, 'Easy', 'Circles'
    );

    -- Q3
    SELECT id INTO v_qb_id FROM public.question_bank WHERE school_id = v_school_id AND question_text ILIKE '%If a + b = 10%' LIMIT 1;
    INSERT INTO public.exam_questions (
        exam_id, school_id, section_id, section_name, question_bank_id,
        question_text, question_type, options, correct_answer, marks, order_number, difficulty, chapter
    ) VALUES (
        v_exam_id, v_school_id, v_sec_a_id, 'Section A', v_qb_id,
        'If a + b = 10, find the value of a.', 'mcq',
        '[{"id": "A", "text": "10 - b"}, {"id": "B", "text": "10 + b"}, {"id": "C", "text": "b - 10"}, {"id": "D", "text": "10/b"}]'::jsonb,
        'A', 1, 3, 'Medium', 'Algebra'
    );

    -- Q4
    SELECT id INTO v_qb_id FROM public.question_bank WHERE school_id = v_school_id AND question_text ILIKE '%prime number%' LIMIT 1;
    INSERT INTO public.exam_questions (
        exam_id, school_id, section_id, section_name, question_bank_id,
        question_text, question_type, options, correct_answer, marks, order_number, difficulty, chapter
    ) VALUES (
        v_exam_id, v_school_id, v_sec_a_id, 'Section A', v_qb_id,
        'Which of the following is a prime number?', 'mcq',
        '[{"id": "A", "text": "4"}, {"id": "B", "text": "6"}, {"id": "C", "text": "7"}, {"id": "D", "text": "9"}]'::jsonb,
        'C', 1, 4, 'Easy', 'Number System'
    );

    -- Q5
    INSERT INTO public.exam_questions (
        exam_id, school_id, section_id, section_name, question_bank_id,
        question_text, question_type, options, correct_answer, marks, order_number, difficulty, chapter
    ) VALUES (
        v_exam_id, v_school_id, v_sec_a_id, 'Section A', NULL,
        'Find the square root of 144.', 'mcq',
        '[{"id": "A", "text": "10"}, {"id": "B", "text": "11"}, {"id": "C", "text": "12"}, {"id": "D", "text": "14"}]'::jsonb,
        'C', 1, 5, 'Easy', 'Square Root'
    );

    -- INSERT SECTION B QUESTIONS (5 Short answers, 2 marks each)
    -- Q6
    INSERT INTO public.exam_questions (
        exam_id, school_id, section_id, section_name, question_bank_id,
        question_text, question_type, options, correct_answer, marks, order_number, difficulty, chapter
    ) VALUES (
        v_exam_id, v_school_id, v_sec_b_id, 'Section B', NULL,
        'Find the value of x if 2x + 3 = 11.', 'short_answer',
        '[]'::jsonb, 'x = 4', 2, 1, 'Easy', 'Linear Equations'
    );

    -- Q7
    SELECT id INTO v_qb_id FROM public.question_bank WHERE school_id = v_school_id AND question_text ILIKE '%Solve: x² - 5x + 6 = 0%' LIMIT 1;
    INSERT INTO public.exam_questions (
        exam_id, school_id, section_id, section_name, question_bank_id,
        question_text, question_type, options, correct_answer, marks, order_number, difficulty, chapter
    ) VALUES (
        v_exam_id, v_school_id, v_sec_b_id, 'Section B', v_qb_id,
        'Solve: x^2 - 5x + 6 = 0.', 'short_answer',
        '[]'::jsonb, 'x = 2, 3', 2, 2, 'Medium', 'Quadratic Equations'
    );

    -- Q8
    INSERT INTO public.exam_questions (
        exam_id, school_id, section_id, section_name, question_bank_id,
        question_text, question_type, options, correct_answer, marks, order_number, difficulty, chapter
    ) VALUES (
        v_exam_id, v_school_id, v_sec_b_id, 'Section B', NULL,
        'Explain the Pythagorean theorem.', 'short_answer',
        '[]'::jsonb, 'In a right-angled triangle, hypotenuse² = base² + perpendicular²', 2, 3, 'Easy', 'Geometry'
    );

    -- Q9
    INSERT INTO public.exam_questions (
        exam_id, school_id, section_id, section_name, question_bank_id,
        question_text, question_type, options, correct_answer, marks, order_number, difficulty, chapter
    ) VALUES (
        v_exam_id, v_school_id, v_sec_b_id, 'Section B', NULL,
        'Find the perimeter of a rectangle of length 8 cm and breadth 5 cm.', 'short_answer',
        '[]'::jsonb, 'Perimeter = 2*(8+5) = 26 cm', 2, 4, 'Easy', 'Mensuration'
    );

    -- Q10
    SELECT id INTO v_qb_id FROM public.question_bank WHERE school_id = v_school_id AND question_text ILIKE '%area of a triangle with base 10%' LIMIT 1;
    INSERT INTO public.exam_questions (
        exam_id, school_id, section_id, section_name, question_bank_id,
        question_text, question_type, options, correct_answer, marks, order_number, difficulty, chapter
    ) VALUES (
        v_exam_id, v_school_id, v_sec_b_id, 'Section B', v_qb_id,
        'What is the area of a triangle with base 10 cm and height 6 cm?', 'short_answer',
        '[]'::jsonb, 'Area = 1/2 * 10 * 6 = 30 cm²', 2, 5, 'Easy', 'Triangles'
    );

    -- INSERT SECTION C QUESTIONS (2 Long answers, 5 marks each)
    -- Q11
    SELECT id INTO v_qb_id FROM public.question_bank WHERE school_id = v_school_id AND question_text ILIKE '%sum of angles of a triangle is 180%' LIMIT 1;
    INSERT INTO public.exam_questions (
        exam_id, school_id, section_id, section_name, question_bank_id,
        question_text, question_type, options, correct_answer, marks, order_number, difficulty, chapter
    ) VALUES (
        v_exam_id, v_school_id, v_sec_c_id, 'Section C', v_qb_id,
        'Prove that the sum of angles in a triangle is 180°.', 'long_answer',
        '[]'::jsonb, 'Draw a parallel line through the opposite vertex. Alternate interior angles are equal...', 5, 1, 'Medium', 'Triangles'
    );

    -- Q12
    SELECT id INTO v_qb_id FROM public.question_bank WHERE school_id = v_school_id AND question_text ILIKE '%applications of trigonometry in real life%' LIMIT 1;
    INSERT INTO public.exam_questions (
        exam_id, school_id, section_id, section_name, question_bank_id,
        question_text, question_type, options, correct_answer, marks, order_number, difficulty, chapter
    ) VALUES (
        v_exam_id, v_school_id, v_sec_c_id, 'Section C', v_qb_id,
        'Discuss the applications of trigonometry in real life.', 'long_answer',
        '[]'::jsonb, 'Trigonometry is used in astronomy, satellite navigation, surveying, architecture, computer graphics...', 5, 2, 'Hard', 'Trigonometry'
    );

    -- Update summary counters on exam
    UPDATE public.exams SET
        total_sections = 3,
        total_questions_count = 12
    WHERE id = v_exam_id;

END $$;
