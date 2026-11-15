-- ============================================================================
-- Migration: 433_enterprise_question_bank_system.sql
-- Description: Comprehensive Enterprise Question Bank System
--   1. Seed Question Bank Lookups (QUESTION_TYPE, QUESTION_DIFFICULTY,
--      QUESTION_STATUS, QUESTION_TAGS, QUESTION_SOURCE, QUESTION_LANGUAGE)
--      into public.lookup_keys and public.lookup_values for all active schools.
--   2. Extend question_bank table with rich enterprise metadata:
--      class_id, class_name, topic, question_code, title, negative_marks,
--      language_code, explanation, model_answer, rubric, tags, source_type,
--      source_reference, status, rejection_reason, version_number, usage_count,
--      approved_by, approved_at, is_active, deleted_at, attachments, child_questions.
--   3. Drop restrictive check constraints on question_type.
--   4. Create auxiliary tables: question_bank_versions, question_bank_history,
--      question_bank_usage, question_bank_import_jobs.
--   5. High performance indexes for multi-tenant querying, filtering, and search.
--   6. Seed realistic sample question bank data matching reference requirements.
-- ============================================================================

-- 1. DROP RESTRICTIVE CHECK CONSTRAINTS
ALTER TABLE public.question_bank DROP CONSTRAINT IF EXISTS chk_question_bank_type;
ALTER TABLE public.exam_questions DROP CONSTRAINT IF EXISTS chk_exam_question_type;

-- 2. EXTEND question_bank COLUMNS
ALTER TABLE public.question_bank
    ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS class_id UUID REFERENCES public.classes(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS section_id UUID REFERENCES public.academic_sections(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS academic_session_id UUID,
    ADD COLUMN IF NOT EXISTS class_name VARCHAR(100),
    ADD COLUMN IF NOT EXISTS topic VARCHAR(255),
    ADD COLUMN IF NOT EXISTS question_code VARCHAR(50),
    ADD COLUMN IF NOT EXISTS title VARCHAR(255),
    ADD COLUMN IF NOT EXISTS negative_marks NUMERIC(8,2) DEFAULT 0.0,
    ADD COLUMN IF NOT EXISTS language_code VARCHAR(20) DEFAULT 'en',
    ADD COLUMN IF NOT EXISTS explanation TEXT,
    ADD COLUMN IF NOT EXISTS model_answer TEXT,
    ADD COLUMN IF NOT EXISTS rubric JSONB DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS tags JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS source_type VARCHAR(50) DEFAULT 'teacher_created',
    ADD COLUMN IF NOT EXISTS source_reference TEXT,
    ADD COLUMN IF NOT EXISTS status VARCHAR(30) DEFAULT 'approved',
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
    ADD COLUMN IF NOT EXISTS version_number INT DEFAULT 1,
    ADD COLUMN IF NOT EXISTS usage_count INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS attachments JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS child_questions JSONB DEFAULT '[]'::jsonb;

-- 3. CREATE AUXILIARY TABLES
CREATE TABLE IF NOT EXISTS public.question_bank_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id UUID NOT NULL REFERENCES public.question_bank(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    snapshot JSONB NOT NULL,
    changed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    change_summary TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.question_bank_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id UUID NOT NULL REFERENCES public.question_bank(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL, -- created, updated, approved, rejected, archived, duplicated
    comments TEXT,
    performed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    performed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.question_bank_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id UUID NOT NULL REFERENCES public.question_bank(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    exam_id UUID REFERENCES public.exams(id) ON DELETE CASCADE,
    paper_title VARCHAR(255),
    academic_session VARCHAR(100),
    used_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.question_bank_import_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    uploaded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    file_name VARCHAR(255),
    file_path TEXT,
    status VARCHAR(30) DEFAULT 'completed', -- pending, processing, completed, failed
    total_rows INT DEFAULT 0,
    successful_rows INT DEFAULT 0,
    failed_rows INT DEFAULT 0,
    error_summary JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- 4. PERFORMANCE INDEXES
CREATE INDEX IF NOT EXISTS idx_qb_school_status ON public.question_bank(school_id, status);
CREATE INDEX IF NOT EXISTS idx_qb_school_type ON public.question_bank(school_id, question_type);
CREATE INDEX IF NOT EXISTS idx_qb_subject_diff ON public.question_bank(subject_id, difficulty);
CREATE INDEX IF NOT EXISTS idx_qb_class_name ON public.question_bank(class_name);
CREATE INDEX IF NOT EXISTS idx_qb_active_questions ON public.question_bank(school_id, is_active) WHERE is_active = true AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_qb_versions_qid ON public.question_bank_versions(question_id, version_number);
CREATE INDEX IF NOT EXISTS idx_qb_history_qid ON public.question_bank_history(question_id);
CREATE INDEX IF NOT EXISTS idx_qb_usage_qid ON public.question_bank_usage(question_id);

-- 5. SEED QUESTION BANK LOOKUPS ACROSS ALL SCHOOLS
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

        -- 5.1 QUESTION_TYPE
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'QUESTION_TYPE';
        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Question Type', 'QUESTION_TYPE', 'Configurable question types for examinations and question banks', 'SYSTEM', 'quiz_outlined', 'ACTIVE', v_admin_id)
            RETURNING id INTO v_key_id;
        END IF;

        INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by)
        VALUES
            (v_key_id, s.id, 'Multiple Choice (MCQ)', 'MCQ', 'Single-select multiple choice question with options', 'ACTIVE', 1, v_admin_id),
            (v_key_id, s.id, 'Multi Select', 'MULTI_SELECT', 'Multiple options may be correct with partial marking', 'ACTIVE', 2, v_admin_id),
            (v_key_id, s.id, 'Short Answer', 'SHORT_ANSWER', 'Concise textual answer (1-3 sentences or mathematical step)', 'ACTIVE', 3, v_admin_id),
            (v_key_id, s.id, 'Long Answer', 'LONG_ANSWER', 'Detailed explanation, derivation, or multi-step problem solving', 'ACTIVE', 4, v_admin_id),
            (v_key_id, s.id, 'True / False', 'TRUE_FALSE', 'Binary assertion validation question', 'ACTIVE', 5, v_admin_id),
            (v_key_id, s.id, 'Fill in the Blanks', 'FILL_BLANKS', 'Sentence with one or more blank placeholders', 'ACTIVE', 6, v_admin_id),
            (v_key_id, s.id, 'Match the Following', 'MATCH_FOLLOWING', 'Paired matching question across two columns', 'ACTIVE', 7, v_admin_id),
            (v_key_id, s.id, 'Assertion and Reason', 'ASSERTION_REASON', 'Evaluating statement assertion and supporting reason', 'ACTIVE', 8, v_admin_id),
            (v_key_id, s.id, 'Case Study / Passage', 'CASE_STUDY', 'Common context or comprehension passage with sub-questions', 'ACTIVE', 9, v_admin_id),
            (v_key_id, s.id, 'Numerical Problem', 'NUMERICAL', 'Quantitative computation with accepted numeric tolerance', 'ACTIVE', 10, v_admin_id),
            (v_key_id, s.id, 'Descriptive / Essay', 'DESCRIPTIVE', 'Comprehensive essay or subjective exposition with rubric', 'ACTIVE', 11, v_admin_id),
            (v_key_id, s.id, 'Diagram / Image Based', 'DIAGRAM', 'Question anchored on a visual diagram, map, or apparatus', 'ACTIVE', 12, v_admin_id),
            (v_key_id, s.id, 'Oral / Practical / Activity', 'PRACTICAL', 'Hands-on laboratory, viva voce, or project evaluation', 'ACTIVE', 13, v_admin_id)
        ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;

        -- 5.2 QUESTION_DIFFICULTY
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'QUESTION_DIFFICULTY';
        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Question Difficulty', 'QUESTION_DIFFICULTY', 'Taxonomy of question cognitive difficulty levels', 'SYSTEM', 'analytics_outlined', 'ACTIVE', v_admin_id)
            RETURNING id INTO v_key_id;
        END IF;

        INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by)
        VALUES
            (v_key_id, s.id, 'Very Easy', 'VERY_EASY', 'Basic recall or fundamental recognition', 'ACTIVE', 1, v_admin_id),
            (v_key_id, s.id, 'Easy', 'EASY', 'Direct standard conceptual application', 'ACTIVE', 2, v_admin_id),
            (v_key_id, s.id, 'Medium', 'MEDIUM', 'Analytical thinking and multi-step deduction', 'ACTIVE', 3, v_admin_id),
            (v_key_id, s.id, 'Hard', 'HARD', 'Complex problem solving requiring deep synthesis', 'ACTIVE', 4, v_admin_id),
            (v_key_id, s.id, 'Very Hard', 'VERY_HARD', 'Olympiad, competitive, or advanced university tier difficulty', 'ACTIVE', 5, v_admin_id)
        ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;

        -- 5.3 QUESTION_STATUS
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'QUESTION_STATUS';
        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Question Status', 'QUESTION_STATUS', 'Lifecycle and moderation status of question bank items', 'SYSTEM', 'check_circle_outline_rounded', 'ACTIVE', v_admin_id)
            RETURNING id INTO v_key_id;
        END IF;

        INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by)
        VALUES
            (v_key_id, s.id, 'Approved', 'APPROVED', 'Reviewed, approved, and ready for paper composition', 'ACTIVE', 1, v_admin_id),
            (v_key_id, s.id, 'Pending Review', 'PENDING_REVIEW', 'Awaiting academic HOD or coordinator peer review', 'ACTIVE', 2, v_admin_id),
            (v_key_id, s.id, 'Draft', 'DRAFT', 'Work in progress; visible solely to authoring teacher', 'ACTIVE', 3, v_admin_id),
            (v_key_id, s.id, 'Rejected', 'REJECTED', 'Returned to author with revision remarks', 'ACTIVE', 4, v_admin_id),
            (v_key_id, s.id, 'Archived', 'ARCHIVED', 'Deprecated question preserved strictly for historical audit', 'ACTIVE', 5, v_admin_id)
        ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;

        -- 5.4 QUESTION_TAGS
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'QUESTION_TAGS';
        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Question Tags', 'QUESTION_TAGS', 'Curricular and pedagogical categorization tags', 'SYSTEM', 'label_outlined', 'ACTIVE', v_admin_id)
            RETURNING id INTO v_key_id;
        END IF;

        INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by)
        VALUES
            (v_key_id, s.id, 'Important', 'IMPORTANT', 'High-yield examination topics', 'ACTIVE', 1, v_admin_id),
            (v_key_id, s.id, 'Previous Year', 'PREVIOUS_YEAR', 'Featured in prior national or state board examinations', 'ACTIVE', 2, v_admin_id),
            (v_key_id, s.id, 'Board Pattern', 'BOARD_PATTERN', 'Strictly formatted to standard board blueprint criteria', 'ACTIVE', 3, v_admin_id),
            (v_key_id, s.id, 'Conceptual', 'CONCEPTUAL', 'Focuses on fundamental core understanding', 'ACTIVE', 4, v_admin_id),
            (v_key_id, s.id, 'HOTS', 'HOTS', 'Higher Order Thinking Skills challenge questions', 'ACTIVE', 5, v_admin_id),
            (v_key_id, s.id, 'Competency Based', 'COMPETENCY_BASED', 'Real-world application and case scenarios', 'ACTIVE', 6, v_admin_id),
            (v_key_id, s.id, 'Practice', 'PRACTICE', 'Recommended for self-assessment and homework drill', 'ACTIVE', 7, v_admin_id),
            (v_key_id, s.id, 'Revision', 'REVISION', 'Quick pre-exam review material', 'ACTIVE', 8, v_admin_id)
        ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;

        -- 5.5 QUESTION_SOURCE
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'QUESTION_SOURCE';
        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Question Source', 'QUESTION_SOURCE', 'Provenance and bibliographic attribution of questions', 'SYSTEM', 'source_outlined', 'ACTIVE', v_admin_id)
            RETURNING id INTO v_key_id;
        END IF;

        INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by)
        VALUES
            (v_key_id, s.id, 'Teacher Created', 'TEACHER_CREATED', 'Authored directly by in-house faculty', 'ACTIVE', 1, v_admin_id),
            (v_key_id, s.id, 'Previous Year Paper', 'PREVIOUS_YEAR', 'Official past-year board examination question', 'ACTIVE', 2, v_admin_id),
            (v_key_id, s.id, 'Textbook', 'TEXTBOOK', 'Standard recommended textbook chapter exercise', 'ACTIVE', 3, v_admin_id),
            (v_key_id, s.id, 'External Reference', 'EXTERNAL_REFERENCE', 'Reputable coaching or academic publication', 'ACTIVE', 4, v_admin_id),
            (v_key_id, s.id, 'Imported', 'IMPORTED', 'Bulk imported from departmental spreadsheets', 'ACTIVE', 5, v_admin_id),
            (v_key_id, s.id, 'AI Generated', 'AI_GENERATED', 'Synthesized via AI curriculum assistant', 'ACTIVE', 6, v_admin_id)
        ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;

        -- 5.6 QUESTION_LANGUAGE
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'QUESTION_LANGUAGE';
        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Question Language', 'QUESTION_LANGUAGE', 'Instructional language of the question item', 'SYSTEM', 'translate_rounded', 'ACTIVE', v_admin_id)
            RETURNING id INTO v_key_id;
        END IF;

        INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by)
        VALUES
            (v_key_id, s.id, 'English', 'EN', 'English instructional language', 'ACTIVE', 1, v_admin_id),
            (v_key_id, s.id, 'Hindi', 'HI', 'Hindi instructional language', 'ACTIVE', 2, v_admin_id),
            (v_key_id, s.id, 'Sanskrit', 'SA', 'Sanskrit instructional language', 'ACTIVE', 3, v_admin_id),
            (v_key_id, s.id, 'French', 'FR', 'French language subject', 'ACTIVE', 4, v_admin_id),
            (v_key_id, s.id, 'Spanish', 'ES', 'Spanish language subject', 'ACTIVE', 5, v_admin_id)
        ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;

    END LOOP;
END $$;

-- 6. SEED REALISTIC HIGH QUALITY QUESTION BANK DATA (MATCHING REFERENCE UI)
DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_math_id UUID;
    v_physics_id UUID;
    v_chem_id UUID;
    v_eng_id UUID;
    v_teacher_id UUID;
    v_class_10_id UUID;
    v_class_9_id UUID;
BEGIN
    SELECT id INTO v_teacher_id FROM public.profiles WHERE school_id = v_school_id AND role IN ('teacher', 'admin', 'super_admin') LIMIT 1;
    IF v_teacher_id IS NULL THEN
        SELECT id INTO v_teacher_id FROM public.profiles LIMIT 1;
    END IF;

    SELECT id INTO v_class_10_id FROM public.classes WHERE school_id = v_school_id AND name ILIKE '%10%' LIMIT 1;
    SELECT id INTO v_class_9_id FROM public.classes WHERE school_id = v_school_id AND name ILIKE '%9%' LIMIT 1;

    SELECT id INTO v_math_id FROM public.subjects WHERE school_id = v_school_id AND name ILIKE '%Math%' LIMIT 1;
    IF v_math_id IS NULL THEN
        INSERT INTO public.subjects (school_id, name, class, teacher_id)
        VALUES (v_school_id, 'Mathematics', '10-A', v_teacher_id)
        RETURNING id INTO v_math_id;
    END IF;

    SELECT id INTO v_physics_id FROM public.subjects WHERE school_id = v_school_id AND name ILIKE '%Physics%' LIMIT 1;
    IF v_physics_id IS NULL THEN
        INSERT INTO public.subjects (school_id, name, class, teacher_id)
        VALUES (v_school_id, 'Physics', '10-A', v_teacher_id)
        RETURNING id INTO v_physics_id;
    END IF;

    SELECT id INTO v_chem_id FROM public.subjects WHERE school_id = v_school_id AND name ILIKE '%Chem%' LIMIT 1;
    IF v_chem_id IS NULL THEN
        INSERT INTO public.subjects (school_id, name, class, teacher_id)
        VALUES (v_school_id, 'Chemistry', '10-A', v_teacher_id)
        RETURNING id INTO v_chem_id;
    END IF;

    SELECT id INTO v_eng_id FROM public.subjects WHERE school_id = v_school_id AND name ILIKE '%Eng%' LIMIT 1;
    IF v_eng_id IS NULL THEN
        INSERT INTO public.subjects (school_id, name, class, teacher_id)
        VALUES (v_school_id, 'English', '10-A', v_teacher_id)
        RETURNING id INTO v_eng_id;
    END IF;

    -- Only seed if the question bank has fewer than 10 questions
    IF (SELECT count(*) FROM public.question_bank WHERE school_id = v_school_id) < 10 THEN
        -- Q1: What is the value of π?
        INSERT INTO public.question_bank (
            school_id, teacher_id, created_by, subject_id, class_id, class_name, chapter, topic,
            question_code, title, question_text, question_type, options, correct_answer,
            difficulty, marks, negative_marks, explanation, status, tags, source_type
        ) VALUES (
            v_school_id, v_teacher_id, v_teacher_id, v_math_id, v_class_10_id, 'Class 10', 'Circles', 'Circumference & Area',
            'QB-MATH-101', 'Value of Pi', 'What is the value of π?', 'mcq',
            '["2.14", "3.14", "4.14", "5.14"]'::jsonb, 'B',
            'Easy', 1, 0.0, 'Pi is an irrational mathematical constant approximately equal to 3.14159 or 22/7.', 'approved',
            '["Important", "Conceptual"]'::jsonb, 'teacher_created'
        );

        -- Q2: Which formula is used for area of a circle?
        INSERT INTO public.question_bank (
            school_id, teacher_id, created_by, subject_id, class_id, class_name, chapter, topic,
            question_code, title, question_text, question_type, options, correct_answer,
            difficulty, marks, negative_marks, explanation, status, tags, source_type
        ) VALUES (
            v_school_id, v_teacher_id, v_teacher_id, v_math_id, v_class_10_id, 'Class 10', 'Circles', 'Area Theorems',
            'QB-MATH-102', 'Area Formula of Circle', 'Which formula is used for area of a circle?', 'mcq',
            '["2πr", "πr²", "πd", "2πr²"]'::jsonb, 'B',
            'Easy', 1, 0.0, 'The area enclosed by a circle of radius r is πr².', 'approved',
            '["Board Pattern", "Important"]'::jsonb, 'teacher_created'
        );

        -- Q3: If a + b = 10, find the value of a.
        INSERT INTO public.question_bank (
            school_id, teacher_id, created_by, subject_id, class_id, class_name, chapter, topic,
            question_code, title, question_text, question_type, options, correct_answer,
            difficulty, marks, negative_marks, explanation, status, tags, source_type
        ) VALUES (
            v_school_id, v_teacher_id, v_teacher_id, v_math_id, v_class_10_id, 'Class 10', 'Algebra', 'Linear Equations',
            'QB-MATH-103', 'Simple Linear Isolation', 'If a + b = 10, find the value of a.', 'mcq',
            '["10 - b", "10 + b", "b - 10", "10b"]'::jsonb, 'A',
            'Medium', 1, 0.0, 'Subtracting b from both sides yields a = 10 - b.', 'approved',
            '["Practice"]'::jsonb, 'teacher_created'
        );

        -- Q4: Which of the following is a prime number?
        INSERT INTO public.question_bank (
            school_id, teacher_id, created_by, subject_id, class_id, class_name, chapter, topic,
            question_code, title, question_text, question_type, options, correct_answer,
            difficulty, marks, negative_marks, explanation, status, tags, source_type
        ) VALUES (
            v_school_id, v_teacher_id, v_teacher_id, v_math_id, v_class_10_id, 'Class 10', 'Number System', 'Prime Factorization',
            'QB-MATH-104', 'Prime Identification', 'Which of the following is a prime number?', 'mcq',
            '["4", "6", "7", "9"]'::jsonb, 'C',
            'Easy', 1, 0.0, '7 has no positive integer divisors other than 1 and itself, making it prime.', 'approved',
            '["Conceptual", "Revision"]'::jsonb, 'teacher_created'
        );

        -- Q5: Find the square root of 144.
        INSERT INTO public.question_bank (
            school_id, teacher_id, created_by, subject_id, class_id, class_name, chapter, topic,
            question_code, title, question_text, question_type, options, correct_answer,
            difficulty, marks, negative_marks, model_answer, explanation, status, tags, source_type
        ) VALUES (
            v_school_id, v_teacher_id, v_teacher_id, v_math_id, v_class_10_id, 'Class 10', 'Square Root', 'Radicals',
            'QB-MATH-105', 'Square Root of 144', 'Find the square root of 144.', 'short_answer', null, '12',
            'Easy', 2, 0.0, '√144 = 12 because 12 × 12 = 144.', 'Principal square root is positive 12.', 'approved',
            '["Board Pattern"]'::jsonb, 'teacher_created'
        );

        -- Q6: Prove that the sum of angles of a triangle is 180°.
        INSERT INTO public.question_bank (
            school_id, teacher_id, created_by, subject_id, class_id, class_name, chapter, topic,
            question_code, title, question_text, question_type, options, correct_answer,
            difficulty, marks, negative_marks, model_answer, explanation, status, tags, source_type
        ) VALUES (
            v_school_id, v_teacher_id, v_teacher_id, v_math_id, v_class_10_id, 'Class 10', 'Triangles', 'Angle Sum Property',
            'QB-MATH-106', 'Angle Sum Theorem', 'Prove that the sum of angles of a triangle is 180°.', 'long_answer', null, '180 degrees derivation',
            'Medium', 5, 0.0,
            'Let ABC be a triangle. Draw a line XY passing through A parallel to BC. Angle XAB + Angle BAC + Angle YAC = 180° (straight angle). Since XY is parallel to BC, Angle XAB = Angle B and Angle YAC = Angle C (alternate interior angles). Substituting gives: Angle A + Angle B + Angle C = 180°.',
            'Standard theorem proof with step-wise marks distribution.', 'approved',
            '["HOTS", "Important", "Board Pattern"]'::jsonb, 'teacher_created'
        );

        -- Q7: Discuss the applications of trigonometry in real life.
        INSERT INTO public.question_bank (
            school_id, teacher_id, created_by, subject_id, class_id, class_name, chapter, topic,
            question_code, title, question_text, question_type, options, correct_answer,
            difficulty, marks, negative_marks, model_answer, explanation, status, tags, source_type
        ) VALUES (
            v_school_id, v_teacher_id, v_teacher_id, v_math_id, v_class_10_id, 'Class 10', 'Trigonometry', 'Heights and Distances',
            'QB-MATH-107', 'Real World Trigonometry', 'Discuss the applications of trigonometry in real life.', 'long_answer', null, 'Comprehensive discussion',
            'Hard', 5, 0.0,
            'Trigonometry is extensively applied in: 1. Architecture and engineering for calculating load bearings and roof slopes. 2. Navigation, aviation, and GPS triangulation. 3. Measuring the height of inaccessible landmarks such as mountains and towers. 4. Physics and sound waves (sine and cosine wave synthesis).',
            'Requires at least 4 clear real-world examples with conceptual explanation.', 'approved',
            '["Competency Based", "Important"]'::jsonb, 'textbook'
        );

        -- Q8: Solve: x^2 - 5x + 6 = 0.
        INSERT INTO public.question_bank (
            school_id, teacher_id, created_by, subject_id, class_id, class_name, chapter, topic,
            question_code, title, question_text, question_type, options, correct_answer,
            difficulty, marks, negative_marks, model_answer, explanation, status, tags, source_type
        ) VALUES (
            v_school_id, v_teacher_id, v_teacher_id, v_math_id, v_class_10_id, 'Class 10', 'Quadratic Equations', 'Factoring Method',
            'QB-MATH-108', 'Quadratic Factoring', 'Solve: x² - 5x + 6 = 0.', 'short_answer', null, 'x = 2 or x = 3',
            'Medium', 2, 0.0,
            'x² - 5x + 6 = (x - 2)(x - 3) = 0. Therefore, x = 2 or x = 3.',
            'Splitting the middle term: product = 6, sum = -5. Factors are -2 and -3.', 'approved',
            '["Conceptual", "Practice"]'::jsonb, 'teacher_created'
        );

        -- Q9: Find the derivative of x^2.
        INSERT INTO public.question_bank (
            school_id, teacher_id, created_by, subject_id, class_id, class_name, chapter, topic,
            question_code, title, question_text, question_type, options, correct_answer,
            difficulty, marks, negative_marks, model_answer, explanation, status, tags, source_type
        ) VALUES (
            v_school_id, v_teacher_id, v_teacher_id, v_math_id, v_class_10_id, 'Class 10', 'Differentiation', 'Power Rule',
            'QB-MATH-109', 'Derivative of x squared', 'Find the derivative of x².', 'short_answer', null, '2x',
            'Medium', 2, 0.0,
            'Using the power rule: d/dx (x^n) = n * x^(n-1). For n = 2, d/dx (x²) = 2 * x^(2-1) = 2x.',
            'Power rule application.', 'approved',
            '["Conceptual"]'::jsonb, 'teacher_created'
        );

        -- Q10: What is the area of a triangle with base 10 cm and height 6 cm?
        INSERT INTO public.question_bank (
            school_id, teacher_id, created_by, subject_id, class_id, class_name, chapter, topic,
            question_code, title, question_text, question_type, options, correct_answer,
            difficulty, marks, negative_marks, model_answer, explanation, status, tags, source_type
        ) VALUES (
            v_school_id, v_teacher_id, v_teacher_id, v_math_id, v_class_9_id, 'Class 9', 'Triangles', 'Mensuration',
            'QB-MATH-110', 'Triangle Area Computation', 'What is the area of a triangle with base 10 cm and height 6 cm?', 'short_answer', null, '30 cm²',
            'Easy', 2, 0.0,
            'Area = 1/2 × base × height = 1/2 × 10 cm × 6 cm = 30 cm².',
            'Direct formula substitution.', 'approved',
            '["Practice", "Revision"]'::jsonb, 'teacher_created'
        );

        -- Q11: State Newton's Second Law of Motion.
        INSERT INTO public.question_bank (
            school_id, teacher_id, created_by, subject_id, class_id, class_name, chapter, topic,
            question_code, title, question_text, question_type, options, correct_answer,
            difficulty, marks, negative_marks, model_answer, explanation, status, tags, source_type
        ) VALUES (
            v_school_id, v_teacher_id, v_teacher_id, v_physics_id, v_class_10_id, 'Class 10', 'Force and Laws of Motion', 'Newtonian Mechanics',
            'QB-PHYS-201', 'Newton Second Law', 'State Newton''s Second Law of Motion and give its mathematical formulation.', 'short_answer', null, 'F = ma',
            'Medium', 3, 0.0,
            'The rate of change of momentum of an object is directly proportional to the applied unbalanced force in the direction of force. Mathematically: F = dp/dt = m(dv/dt) = ma.',
            'Statement: 1.5 marks, Mathematical derivation: 1.5 marks.', 'approved',
            '["Important", "Board Pattern"]'::jsonb, 'teacher_created'
        );

        -- Q12: Which gas is liberated when an acid reacts with an active metal?
        INSERT INTO public.question_bank (
            school_id, teacher_id, created_by, subject_id, class_id, class_name, chapter, topic,
            question_code, title, question_text, question_type, options, correct_answer,
            difficulty, marks, negative_marks, explanation, status, tags, source_type
        ) VALUES (
            v_school_id, v_teacher_id, v_teacher_id, v_chem_id, v_class_10_id, 'Class 10', 'Acids, Bases and Salts', 'Chemical Properties',
            'QB-CHEM-301', 'Acid Metal Reaction Gas', 'Which gas is liberated when an acid reacts with an active metal?', 'mcq',
            '["Oxygen", "Hydrogen", "Carbon Dioxide", "Nitrogen"]'::jsonb, 'B',
            'Easy', 1, 0.0,
            'Acid + Metal -> Salt + Hydrogen gas (H₂). It burns with a characteristic pop sound.', 'approved',
            '["Important", "Revision"]'::jsonb, 'textbook'
        );

    END IF;
END $$;
