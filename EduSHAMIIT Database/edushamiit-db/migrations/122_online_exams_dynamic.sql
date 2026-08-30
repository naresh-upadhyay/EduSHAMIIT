-- ============================================================
-- Migration 122: Seed Dynamic Online Exam Data
-- Seeds online exams, questions, submissions, and active sessions
-- ============================================================

-- Drop check constraint if present to allow idempotent seeding across redesigns
ALTER TABLE IF EXISTS public.exam_questions DROP CONSTRAINT IF EXISTS chk_exam_question_type;

-- Seed realistic dynamic online exams, questions, submissions, and active sessions
DO $$
DECLARE
  v_school_id UUID;
  v_math_sub_id UUID;
  v_phys_sub_id UUID;
  v_teacher_id UUID;
  v_student_1 UUID;
  v_student_2 UUID;
  v_student_3 UUID;
  v_student_4 UUID;
BEGIN
  SELECT school_id INTO v_school_id FROM public.profiles WHERE email = 'shamiitltd@gmail.com' LIMIT 1;
  IF v_school_id IS NULL THEN
    SELECT id INTO v_school_id FROM public.schools ORDER BY created_at ASC LIMIT 1;
  END IF;
  SELECT id INTO v_math_sub_id FROM public.subjects WHERE school_id = v_school_id AND name ILIKE '%Math%' ORDER BY id ASC LIMIT 1;
  SELECT id INTO v_phys_sub_id FROM public.subjects WHERE school_id = v_school_id AND name ILIKE '%Phys%' ORDER BY id ASC LIMIT 1;
  
  IF v_math_sub_id IS NULL THEN
    SELECT id INTO v_math_sub_id FROM public.subjects ORDER BY id ASC LIMIT 1;
  END IF;
  IF v_phys_sub_id IS NULL THEN
    SELECT id INTO v_phys_sub_id FROM public.subjects ORDER BY id DESC LIMIT 1;
  END IF;

  SELECT id INTO v_teacher_id FROM public.profiles WHERE role = 'teacher' ORDER BY created_at ASC LIMIT 1;
  IF v_teacher_id IS NULL THEN
    SELECT id INTO v_teacher_id FROM public.profiles ORDER BY created_at ASC LIMIT 1;
  END IF;

  SELECT id INTO v_student_1 FROM public.profiles WHERE role = 'student' ORDER BY created_at ASC LIMIT 1 OFFSET 0;
  SELECT id INTO v_student_2 FROM public.profiles WHERE role = 'student' ORDER BY created_at ASC LIMIT 1 OFFSET 1;
  SELECT id INTO v_student_3 FROM public.profiles WHERE role = 'student' ORDER BY created_at ASC LIMIT 1 OFFSET 2;
  SELECT id INTO v_student_4 FROM public.profiles WHERE role = 'student' ORDER BY created_at ASC LIMIT 1 OFFSET 3;

  IF v_student_1 IS NULL THEN SELECT id INTO v_student_1 FROM public.profiles ORDER BY created_at ASC LIMIT 1; END IF;
  IF v_student_2 IS NULL THEN v_student_2 := v_student_1; END IF;
  IF v_student_3 IS NULL THEN v_student_3 := v_student_1; END IF;
  IF v_student_4 IS NULL THEN v_student_4 := v_student_1; END IF;

  IF v_school_id IS NOT NULL AND v_math_sub_id IS NOT NULL AND v_teacher_id IS NOT NULL THEN
    -- 1. Online Exams
    INSERT INTO exams (id, school_id, subject_id, teacher_id, title, description,
                       duration_minutes, total_marks, passing_marks, start_time, end_time, status,
                       exam_type, exam_category, exam_date, venue, target_classes, instructions, syllabus)
    VALUES
      ('a1000001-0000-0000-0000-000000000099', v_school_id, 
       v_math_sub_id, v_teacher_id,
       'Mathematics Online Term Exam', 'Advanced online mathematics proctored term examination covering Calculus and Trigonometry.',
       150, 100, 40, NOW() - INTERVAL '1 hour', NOW() + INTERVAL '2 hours', 'published',
       'online', 'Term Exam', CURRENT_DATE, 'Online Portal', '["X-A", "X-B"]'::jsonb,
       'Ensure camera and microphone permissions are enabled. Tab switching is monitored. 3 warnings will result in auto-submission.',
       'Calculus, Trigonometry, Vectors, Linear Algebra'),

      ('a1000001-0000-0000-0000-000000000100', v_school_id, 
       COALESCE(v_phys_sub_id, v_math_sub_id), v_teacher_id,
       'Physics Online Midterm Quiz', 'Proctored online quiz for Physics Chapter 3 (Electromagnetism).',
       60, 50, 20, NOW() + INTERVAL '1 day', NOW() + INTERVAL '1 day' + INTERVAL '1 hour', 'published',
       'online', 'Mid Term', CURRENT_DATE + INTERVAL '1 day', 'Online Portal', '["X-A"]'::jsonb,
       'No calculator allowed. Keep head in focus of the webcam.',
       'Electromagnetism, Electric Fields, Gauss Law')
    ON CONFLICT (id) DO NOTHING;

    -- 2. Exam Questions
    INSERT INTO exam_questions (id, exam_id, question_text, question_type, options, correct_answer, marks, order_number)
    VALUES
      ('91000001-0000-0000-0000-000000000001', 'a1000001-0000-0000-0000-000000000099', 
       'Evaluate the limit of (sin x)/x as x approaches 0.', 'single_select', 
       '["0", "1", "undefined", "infinity"]'::jsonb, '1', 10, 1),
      ('91000001-0000-0000-0000-000000000002', 'a1000001-0000-0000-0000-000000000099', 
       'Find the derivative of f(x) = 3x^2 + 5x at x = 2.', 'subjective', 
       null, '17', 15, 2),
      ('91000001-0000-0000-0000-000000000003', 'a1000001-0000-0000-0000-000000000099', 
       'State and prove the Fundamental Theorem of Calculus.', 'subjective', 
       null, null, 40, 3),
      ('91000001-0000-0000-0000-000000000004', 'a1000001-0000-0000-0000-000000000099', 
       'The derivative of sin(x) with respect to x is ________.', 'subjective', 
       null, 'cos(x)', 15, 4),
      ('91000001-0000-0000-0000-000000000005', 'a1000001-0000-0000-0000-000000000099', 
       'Assertion: The function f(x) = |x| is continuous at x = 0. Reason: The function f(x) = |x| is differentiable at x = 0.', 'single_select', 
       '["Both Assertion and Reason are true and Reason is correct explanation", "Both Assertion and Reason are true but Reason is not correct explanation", "Assertion is true but Reason is false", "Assertion is false but Reason is true"]'::jsonb, 
       'Assertion is true but Reason is false', 20, 5),
      ('91000001-0000-0000-0000-000000000006', 'a1000001-0000-0000-0000-000000000100', 
       'What is the SI unit of magnetic flux?', 'single_select', 
       '["Tesla", "Weber", "Henry", "Farad"]'::jsonb, 'Weber', 10, 1),
      ('91000001-0000-0000-0000-000000000007', 'a1000001-0000-0000-0000-000000000100', 
       'Calculate the force on a 2C charge moving at 3 m/s perpendicular to a 5T magnetic field.', 'subjective', 
       null, '30', 20, 2),
      ('91000001-0000-0000-0000-000000000100', 'a1000001-0000-0000-0000-000000000100', 
       'Explain Faraday''s Law of Electromagnetic Induction.', 'subjective', 
       null, null, 20, 3)
    ON CONFLICT (id) DO NOTHING;

    -- 3. Exam Submissions
    IF v_student_1 IS NOT NULL THEN
      INSERT INTO exam_submissions (id, exam_id, student_id, answers, score, submitted_at, graded_at, status)
      VALUES
        ('81000001-0000-0000-0000-000000000001', 'a1000001-0000-0000-0000-000000000099', 
         v_student_1, 
         '{"91000001-0000-0000-0000-000000000001": "1", "91000001-0000-0000-0000-000000000002": "17", "91000001-0000-0000-0000-000000000003": "The Fundamental Theorem of Calculus states...", "91000001-0000-0000-0000-000000000004": "cos(x)", "91000001-0000-0000-0000-000000000005": "Assertion is true but Reason is false"}'::jsonb,
         92.00, NOW() - INTERVAL '30 minutes', NOW() - INTERVAL '10 minutes', 'graded')
      ON CONFLICT (id) DO NOTHING;
    END IF;

    IF v_student_2 IS NOT NULL THEN
      INSERT INTO exam_submissions (id, exam_id, student_id, answers, score, submitted_at, graded_at, status)
      VALUES
        ('81000001-0000-0000-0000-000000000002', 'a1000001-0000-0000-0000-000000000099', 
         v_student_2, 
         '{"91000001-0000-0000-0000-000000000001": "1", "91000001-0000-0000-0000-000000000002": "15", "91000001-0000-0000-0000-000000000003": "FTC relates differentiation and integration...", "91000001-0000-0000-0000-000000000004": "cos(x)", "91000001-0000-0000-0000-000000000005": "Assertion is true but Reason is false"}'::jsonb,
         null, NOW() - INTERVAL '20 minutes', null, 'submitted')
      ON CONFLICT (id) DO NOTHING;
    END IF;

    -- 4. Exam Sessions
    IF v_student_3 IS NOT NULL THEN
      INSERT INTO exam_sessions (id, exam_id, student_id, started_at, ip_address, status)
      VALUES
        ('e1000001-0000-0000-0000-000000000999', 'a1000001-0000-0000-0000-000000000099', 
         v_student_3, NOW() - INTERVAL '15 minutes', '192.168.1.55'::inet, 'active')
      ON CONFLICT (id) DO NOTHING;
    END IF;

    IF v_student_4 IS NOT NULL THEN
      INSERT INTO exam_sessions (id, exam_id, student_id, started_at, ip_address, status)
      VALUES
        ('e1000001-0000-0000-0000-000000001000', 'a1000001-0000-0000-0000-000000000099', 
         v_student_4, NOW() - INTERVAL '20 minutes', '192.168.1.56'::inet, 'active')
      ON CONFLICT (id) DO NOTHING;
    END IF;

  END IF;
END $$;
