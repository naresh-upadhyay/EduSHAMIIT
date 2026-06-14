-- ============================================================
-- Migration 122: Seed Dynamic Online Exam Data
-- Seeds online exams, questions, submissions, and active sessions
-- ============================================================

-- ── 1. ONLINE EXAMS: Seed realistic online exams ──

INSERT INTO exams (id, school_id, subject_id, teacher_id, title, description,
                   duration_minutes, total_marks, passing_marks, start_time, end_time, status,
                   exam_type, exam_category, exam_date, venue, target_classes, instructions, syllabus)
VALUES
  ('a1000001-0000-0000-0000-000000000099', '11111111-1111-1111-1111-111111111111', 
   'cc000001-0000-0000-0000-000000000001', 'aa000001-0000-0000-0000-000000000001',
   'Mathematics Online Term Exam', 'Advanced online mathematics proctored term examination covering Calculus and Trigonometry.',
   150, 100, 40, NOW() - INTERVAL '1 hour', NOW() + INTERVAL '2 hours', 'published',
   'online', 'Term Exam', CURRENT_DATE, 'Online Portal', '["X-A", "X-B"]'::jsonb,
   'Ensure camera and microphone permissions are enabled. Tab switching is monitored. 3 warnings will result in auto-submission.',
   'Calculus, Trigonometry, Vectors, Linear Algebra'),

  ('a1000001-0000-0000-0000-000000000100', '11111111-1111-1111-1111-111111111111', 
   'cc000004-0000-0000-0000-000000000004', 'aa000002-0000-0000-0000-000000000002',
   'Physics Online Midterm Quiz', 'Proctored online quiz for Physics Chapter 3 (Electromagnetism).',
   60, 50, 20, NOW() + INTERVAL '1 day', NOW() + INTERVAL '1 day' + INTERVAL '1 hour', 'published',
   'online', 'Mid Term', CURRENT_DATE + INTERVAL '1 day', 'Online Portal', '["X-A"]'::jsonb,
   'No calculator allowed. Keep head in focus of the webcam.',
   'Electromagnetism, Electric Fields, Gauss Law')
ON CONFLICT (id) DO NOTHING;


-- ── 2. EXAM QUESTIONS: Seed questions for the online exams ──

INSERT INTO exam_questions (id, exam_id, question_text, question_type, options, correct_answer, marks, order_number)
VALUES
  -- Mathematics Exam Questions
  ('91000001-0000-0000-0000-000000000001', 'a1000001-0000-0000-0000-000000000099', 
   'Evaluate the limit of (sin x)/x as x approaches 0.', 'mcq', 
   '["0", "1", "undefined", "infinity"]'::jsonb, '1', 10, 1),

  ('91000001-0000-0000-0000-000000000002', 'a1000001-0000-0000-0000-000000000099', 
   'Find the derivative of f(x) = 3x^2 + 5x at x = 2.', 'numerical', 
   null, '17', 15, 2),

  ('91000001-0000-0000-0000-000000000003', 'a1000001-0000-0000-0000-000000000099', 
   'State and prove the Fundamental Theorem of Calculus.', 'subjective', 
   null, null, 40, 3),

  ('91000001-0000-0000-0000-000000000004', 'a1000001-0000-0000-0000-000000000099', 
   'The derivative of sin(x) with respect to x is ________.', 'fill_in_the_blank', 
   null, 'cos(x)', 15, 4),

  ('91000001-0000-0000-0000-000000000005', 'a1000001-0000-0000-0000-000000000099', 
   'Assertion: The function f(x) = |x| is continuous at x = 0. Reason: The function f(x) = |x| is differentiable at x = 0.', 'assertion_reason', 
   '["Both Assertion and Reason are true and Reason is correct explanation", "Both Assertion and Reason are true but Reason is not correct explanation", "Assertion is true but Reason is false", "Assertion is false but Reason is true"]'::jsonb, 
   'Assertion is true but Reason is false', 20, 5),

  -- Physics Exam Questions
  ('91000001-0000-0000-0000-000000000006', 'a1000001-0000-0000-0000-000000000100', 
   'What is the SI unit of magnetic flux?', 'mcq', 
   '["Tesla", "Weber", "Henry", "Farad"]'::jsonb, 'Weber', 10, 1),

  ('91000001-0000-0000-0000-000000000007', 'a1000001-0000-0000-0000-000000000100', 
   'Calculate the force on a 2C charge moving at 3 m/s perpendicular to a 5T magnetic field.', 'numerical', 
   null, '30', 20, 2),

  ('91000001-0000-0000-0000-000000000008', 'a1000001-0000-0000-0000-000000000100', 
   'Explain Faraday''s Law of Electromagnetic Induction.', 'subjective', 
   null, null, 20, 3)
ON CONFLICT (id) DO NOTHING;


-- ── 3. EXAM SUBMISSIONS: Seed test student submissions ──

INSERT INTO exam_submissions (id, exam_id, student_id, answers, score, submitted_at, graded_at, status)
VALUES
  -- Arjun Kumar (Graded Math Submission)
  ('81000001-0000-0000-0000-000000000001', 'a1000001-0000-0000-0000-000000000099', 
   'bb000001-0000-0000-0000-000000000001', 
   '{"91000001-0000-0000-0000-000000000001": "1", "91000001-0000-0000-0000-000000000002": "17", "91000001-0000-0000-0000-000000000003": "The Fundamental Theorem of Calculus states...", "91000001-0000-0000-0000-000000000004": "cos(x)", "91000001-0000-0000-0000-000000000005": "Assertion is true but Reason is false"}'::jsonb,
   92.00, NOW() - INTERVAL '30 minutes', NOW() - INTERVAL '10 minutes', 'graded'),

  -- Riya Gupta (Pending review Math Submission)
  ('81000001-0000-0000-0000-000000000002', 'a1000001-0000-0000-0000-000000000099', 
   'bb000002-0000-0000-0000-000000000002', 
   '{"91000001-0000-0000-0000-000000000001": "1", "91000001-0000-0000-0000-000000000002": "15", "91000001-0000-0000-0000-000000000003": "FTC relates differentiation and integration...", "91000001-0000-0000-0000-000000000004": "cos(x)", "91000001-0000-0000-0000-000000000005": "Assertion is true but Reason is false"}'::jsonb,
   null, NOW() - INTERVAL '20 minutes', null, 'submitted')
ON CONFLICT (id) DO NOTHING;


-- ── 4. EXAM SESSIONS: Seed active proctored sessions ──

INSERT INTO exam_sessions (id, exam_id, student_id, started_at, ip_address, status)
VALUES
  -- Active exam taking session for Vikram Joshi
  ('e1000001-0000-0000-0000-000000000999', 'a1000001-0000-0000-0000-000000000099', 
   'bb000005-0000-0000-0000-000000000005', NOW() - INTERVAL '15 minutes', '192.168.1.55'::inet, 'active'),

  -- Active exam taking session for Sanjay Mehta
  ('e1000001-0000-0000-0000-000000001000', 'a1000001-0000-0000-0000-000000000099', 
   'bb000003-0000-0000-0000-000000000003', NOW() - INTERVAL '20 minutes', '192.168.1.56'::inet, 'active')
ON CONFLICT (id) DO NOTHING;
