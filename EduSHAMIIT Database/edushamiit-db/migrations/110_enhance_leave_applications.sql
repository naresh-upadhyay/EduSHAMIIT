-- 110_enhance_leave_applications.sql
-- Enhance leave_applications table and add sample upcoming/past data

-- Add missing columns if not present
ALTER TABLE leave_applications
  ADD COLUMN IF NOT EXISTS duration_days INTEGER GENERATED ALWAYS AS (
    (end_date - start_date + 1)
  ) STORED;

ALTER TABLE leave_applications
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- Index for faster lookup by applicant
CREATE INDEX IF NOT EXISTS idx_leave_applicant_id ON leave_applications(applicant_id);
CREATE INDEX IF NOT EXISTS idx_leave_status ON leave_applications(status);
CREATE INDEX IF NOT EXISTS idx_leave_school_id ON leave_applications(school_id);

-- Seed sample upcoming & past leaves dynamically for shamiitltd@gmail.com, teacher and student
DO $$
DECLARE
  v_school_id UUID;
  v_user_id UUID;
  v_student_id UUID;
  v_teacher_id UUID;
BEGIN
  -- Prioritize shamiitltd@gmail.com
  SELECT id, school_id INTO v_user_id, v_school_id 
  FROM public.profiles 
  WHERE email = 'shamiitltd@gmail.com' 
  LIMIT 1;

  IF v_school_id IS NULL THEN
    SELECT id INTO v_school_id FROM public.schools ORDER BY created_at ASC LIMIT 1;
  END IF;

  SELECT id INTO v_student_id FROM public.profiles WHERE role = 'student' AND (school_id = v_school_id OR school_id IS NULL) ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_teacher_id FROM public.profiles WHERE role = 'teacher' AND (school_id = v_school_id OR school_id IS NULL) ORDER BY created_at ASC LIMIT 1;

  IF v_student_id IS NULL THEN
    v_student_id := COALESCE(v_user_id, '00000000-0000-0000-0000-000000000001'::uuid);
  END IF;
  IF v_teacher_id IS NULL THEN
    v_teacher_id := v_student_id;
  END IF;

  IF v_school_id IS NOT NULL THEN
    -- Admin / User upcoming leaves
    IF v_user_id IS NOT NULL THEN
      INSERT INTO leave_applications (id, school_id, applicant_id, applicant_role, leave_type, start_date, end_date, reason, status, created_at)
      VALUES
        ('11000000-0000-0000-0000-000000000000', v_school_id, v_user_id, 'super_admin', 'Casual Leave', CURRENT_DATE + INTERVAL '5 days', CURRENT_DATE + INTERVAL '6 days', 'Attending international educational conference.', 'pending', NOW())
      ON CONFLICT (id) DO UPDATE SET applicant_id = EXCLUDED.applicant_id, school_id = EXCLUDED.school_id;
    END IF;

    -- Student upcoming leaves
    INSERT INTO leave_applications (id, school_id, applicant_id, applicant_role, leave_type, start_date, end_date, reason, status, created_at)
    VALUES
      ('11000000-0000-0000-0000-000000000001', v_school_id, v_student_id, 'student', 'Sick Leave', '2026-06-10', '2026-06-12', 'Not feeling well, doctor advised rest.', 'pending', NOW()),
      ('11000000-0000-0000-0000-000000000002', v_school_id, v_student_id, 'student', 'Family Event', '2026-06-20', '2026-06-21', 'Sister''s wedding ceremony.', 'approved', NOW()),
      ('11000000-0000-0000-0000-000000000003', v_school_id, v_student_id, 'student', 'Sports Competition', '2026-06-15', '2026-06-17', 'Selected for state-level basketball tournament.', 'pending', NOW()),
      ('11000000-0000-0000-0000-000000000004', v_school_id, v_student_id, 'student', 'Casual Leave', '2026-06-25', '2026-06-25', 'Personal work.', 'approved', NOW())
    ON CONFLICT (id) DO UPDATE SET applicant_id = EXCLUDED.applicant_id, school_id = EXCLUDED.school_id;

    -- Teacher upcoming leaves
    IF v_teacher_id IS NOT NULL THEN
      INSERT INTO leave_applications (id, school_id, applicant_id, applicant_role, leave_type, start_date, end_date, reason, status, created_at)
      VALUES
        ('11000000-0000-0000-0000-000000000005', v_school_id, v_teacher_id, 'teacher', 'Casual Leave', '2026-06-08', '2026-06-08', 'Personal work at home.', 'pending', NOW()),
        ('11000000-0000-0000-0000-000000000006', v_school_id, v_teacher_id, 'teacher', 'Sick Leave', '2026-06-18', '2026-06-19', 'Medical checkup and rest advised by doctor.', 'approved', NOW()),
        ('11000000-0000-0000-0000-000000000007', v_school_id, v_teacher_id, 'teacher', 'Earned Leave', '2026-06-28', '2026-06-30', 'Family vacation.', 'pending', NOW())
      ON CONFLICT (id) DO UPDATE SET applicant_id = EXCLUDED.applicant_id, school_id = EXCLUDED.school_id;
    END IF;

    -- Student past leaves
    INSERT INTO leave_applications (id, school_id, applicant_id, applicant_role, leave_type, start_date, end_date, reason, status, rejection_reason, created_at)
    VALUES
      ('11000000-0000-0000-0000-000000000010', v_school_id, v_student_id, 'student', 'Sick Leave', '2026-05-05', '2026-05-06', 'Severe headache and fever.', 'approved', NULL, '2026-05-03T09:00:00Z'),
      ('11000000-0000-0000-0000-000000000011', v_school_id, v_student_id, 'student', 'Casual Leave', '2026-05-12', '2026-05-12', 'Personal errand.', 'rejected', 'Insufficient reason provided.', '2026-05-10T10:00:00Z'),
      ('11000000-0000-0000-0000-000000000012', v_school_id, v_student_id, 'student', 'Family Event', '2026-04-18', '2026-04-19', 'Cousin''s engagement ceremony.', 'approved', NULL, '2026-04-15T11:00:00Z'),
      ('11000000-0000-0000-0000-000000000013', v_school_id, v_student_id, 'student', 'Urgent Work', '2026-04-28', '2026-04-28', 'Hospital visit for family member.', 'cancelled', NULL, '2026-04-27T08:00:00Z')
    ON CONFLICT (id) DO UPDATE SET applicant_id = EXCLUDED.applicant_id, school_id = EXCLUDED.school_id;

    -- Teacher past leaves
    IF v_teacher_id IS NOT NULL THEN
      INSERT INTO leave_applications (id, school_id, applicant_id, applicant_role, leave_type, start_date, end_date, reason, status, rejection_reason, created_at)
      VALUES
        ('11000000-0000-0000-0000-000000000014', v_school_id, v_teacher_id, 'teacher', 'Sick Leave', '2026-05-08', '2026-05-09', 'High fever and cold.', 'approved', NULL, '2026-05-06T09:00:00Z'),
        ('11000000-0000-0000-0000-000000000015', v_school_id, v_teacher_id, 'teacher', 'Earned Leave', '2026-05-22', '2026-05-24', 'Annual leave for personal travel.', 'approved', NULL, '2026-05-18T10:00:00Z'),
        ('11000000-0000-0000-0000-000000000016', v_school_id, v_teacher_id, 'teacher', 'Casual Leave', '2026-05-30', '2026-05-30', 'Personal work.', 'rejected', 'No substitute arranged.', '2026-05-28T14:00:00Z')
      ON CONFLICT (id) DO UPDATE SET applicant_id = EXCLUDED.applicant_id, school_id = EXCLUDED.school_id;
    END IF;
  END IF;
END $$;
