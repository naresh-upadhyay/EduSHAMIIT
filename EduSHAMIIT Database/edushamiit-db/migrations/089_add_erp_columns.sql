-- ============================================================
-- Migration 089: Add Missing ERP Columns & Widen Constraints
-- Adds realistic columns needed by teacher.py API endpoints
-- Drops tight constraints, re-adds with wider spectrum
-- ============================================================

-- ─── 1. EXAMS: add teacher_id, exam_type, exam_category, exam_date, venue, target_classes ───

ALTER TABLE exams
  ADD COLUMN IF NOT EXISTS teacher_id       UUID REFERENCES profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS exam_type        TEXT DEFAULT 'offline',
  ADD COLUMN IF NOT EXISTS exam_category    TEXT DEFAULT 'Unit Test',
  ADD COLUMN IF NOT EXISTS exam_date        DATE,
  ADD COLUMN IF NOT EXISTS venue            TEXT,
  ADD COLUMN IF NOT EXISTS target_classes   JSONB,
  ADD COLUMN IF NOT EXISTS instructions     TEXT,
  ADD COLUMN IF NOT EXISTS syllabus         TEXT,
  ADD COLUMN IF NOT EXISTS updated_at       TIMESTAMPTZ DEFAULT NOW();

-- Drop old status constraint if exists, re-add with wider spectrum
DO $$
BEGIN
  -- Drop any existing check constraint on exams.status
  IF EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage
    WHERE table_name = 'exams' AND column_name = 'status'
  ) THEN
    EXECUTE (
      SELECT 'ALTER TABLE exams DROP CONSTRAINT ' || constraint_name
      FROM information_schema.constraint_column_usage
      WHERE table_name = 'exams' AND column_name = 'status'
      LIMIT 1
    );
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Indexes for exams
CREATE INDEX IF NOT EXISTS idx_exams_teacher_id   ON exams (teacher_id);
CREATE INDEX IF NOT EXISTS idx_exams_exam_date    ON exams (exam_date);
CREATE INDEX IF NOT EXISTS idx_exams_exam_type    ON exams (exam_type);

-- ─── 2. ATTENDANCE: add teacher_id, fix unique constraint ───

ALTER TABLE attendance
  ADD COLUMN IF NOT EXISTS teacher_id UUID REFERENCES profiles(id) ON DELETE SET NULL;

-- Drop old restrictive UNIQUE(student_id, date) and add per-subject constraint
DO $$
BEGIN
  -- Drop old unique constraint
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'attendance_student_id_date_key'
      AND conrelid = 'attendance'::regclass
  ) THEN
    ALTER TABLE attendance DROP CONSTRAINT attendance_student_id_date_key;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Add new unique constraint per school+student+subject+date
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'attendance_school_student_subject_date_key'
      AND conrelid = 'attendance'::regclass
  ) THEN
    ALTER TABLE attendance ADD CONSTRAINT attendance_school_student_subject_date_key
      UNIQUE (school_id, student_id, subject_id, date);
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_attendance_teacher_id ON attendance (teacher_id);

-- ─── 3. SALARY: add realistic payroll columns ───

ALTER TABLE salary
  ADD COLUMN IF NOT EXISTS basic_pay      NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS hra            NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS da             NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ta             NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS deductions     NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS net_pay        NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pay_period     TEXT,
  ADD COLUMN IF NOT EXISTS payment_mode   TEXT DEFAULT 'bank_transfer';

-- Drop old salary status constraint if exists, re-add wider
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.constraint_column_usage
    WHERE table_name = 'salary' AND column_name = 'status'
  ) THEN
    EXECUTE (
      SELECT 'ALTER TABLE salary DROP CONSTRAINT ' || constraint_name
      FROM information_schema.constraint_column_usage
      WHERE table_name = 'salary' AND column_name = 'status'
      LIMIT 1
    );
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ─── 4. STUDY_MATERIALS: drop tight CHECK, allow any material_type ───

DO $$
DECLARE
  cname TEXT;
BEGIN
  SELECT constraint_name INTO cname
  FROM information_schema.table_constraints tc
  JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
  WHERE tc.table_name = 'study_materials' AND tc.constraint_type = 'CHECK'
    AND cc.check_clause LIKE '%material_type%'
  LIMIT 1;

  IF cname IS NOT NULL THEN
    EXECUTE 'ALTER TABLE study_materials DROP CONSTRAINT ' || cname;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Add subject_id FK to study_materials (useful for ERP)
ALTER TABLE study_materials
  ADD COLUMN IF NOT EXISTS subject_id UUID REFERENCES subjects(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_study_materials_subject ON study_materials (subject_id);

-- ─── 5. LIVE_CLASSES: add meeting_link, max_participants ───

ALTER TABLE live_classes
  ADD COLUMN IF NOT EXISTS meeting_link      TEXT,
  ADD COLUMN IF NOT EXISTS max_participants  INT DEFAULT 100;

-- Drop old status CHECK on live_classes, re-add wider
DO $$
DECLARE
  cname TEXT;
BEGIN
  SELECT constraint_name INTO cname
  FROM information_schema.table_constraints tc
  JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
  WHERE tc.table_name = 'live_classes' AND tc.constraint_type = 'CHECK'
    AND cc.check_clause LIKE '%status%'
  LIMIT 1;

  IF cname IS NOT NULL THEN
    EXECUTE 'ALTER TABLE live_classes DROP CONSTRAINT ' || cname;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ─── 6. NOTICES: drop tight category CHECK, allow any category ───

DO $$
DECLARE
  cname TEXT;
BEGIN
  SELECT constraint_name INTO cname
  FROM information_schema.table_constraints tc
  JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
  WHERE tc.table_name = 'notices' AND tc.constraint_type = 'CHECK'
    AND cc.check_clause LIKE '%category%'
  LIMIT 1;

  IF cname IS NOT NULL THEN
    EXECUTE 'ALTER TABLE notices DROP CONSTRAINT ' || cname;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Drop tight status CHECK on notices
DO $$
DECLARE
  cname TEXT;
BEGIN
  SELECT constraint_name INTO cname
  FROM information_schema.table_constraints tc
  JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
  WHERE tc.table_name = 'notices' AND tc.constraint_type = 'CHECK'
    AND cc.check_clause LIKE '%status%'
  LIMIT 1;

  IF cname IS NOT NULL THEN
    EXECUTE 'ALTER TABLE notices DROP CONSTRAINT ' || cname;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ─── 7. LEAVE_APPLICATIONS: drop tight constraints ───

DO $$
DECLARE
  cname TEXT;
BEGIN
  SELECT constraint_name INTO cname
  FROM information_schema.table_constraints tc
  JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
  WHERE tc.table_name = 'leave_applications' AND tc.constraint_type = 'CHECK'
    AND cc.check_clause LIKE '%applicant_role%'
  LIMIT 1;

  IF cname IS NOT NULL THEN
    EXECUTE 'ALTER TABLE leave_applications DROP CONSTRAINT ' || cname;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
DECLARE
  cname TEXT;
BEGIN
  SELECT constraint_name INTO cname
  FROM information_schema.table_constraints tc
  JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
  WHERE tc.table_name = 'leave_applications' AND tc.constraint_type = 'CHECK'
    AND cc.check_clause LIKE '%status%'
  LIMIT 1;

  IF cname IS NOT NULL THEN
    EXECUTE 'ALTER TABLE leave_applications DROP CONSTRAINT ' || cname;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ─── 8. HOMEWORK_SUBMISSIONS: drop tight status CHECK ───

DO $$
DECLARE
  cname TEXT;
BEGIN
  SELECT constraint_name INTO cname
  FROM information_schema.table_constraints tc
  JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
  WHERE tc.table_name = 'homework_submissions' AND tc.constraint_type = 'CHECK'
    AND cc.check_clause LIKE '%status%'
  LIMIT 1;

  IF cname IS NOT NULL THEN
    EXECUTE 'ALTER TABLE homework_submissions DROP CONSTRAINT ' || cname;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ─── 9. PROFILES: drop tight role and gender constraints, add wider ───

DO $$
DECLARE
  cname TEXT;
BEGIN
  SELECT constraint_name INTO cname
  FROM information_schema.table_constraints tc
  JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
  WHERE tc.table_name = 'profiles' AND tc.constraint_type = 'CHECK'
    AND cc.check_clause LIKE '%role%'
  LIMIT 1;

  IF cname IS NOT NULL THEN
    EXECUTE 'ALTER TABLE profiles DROP CONSTRAINT ' || cname;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
DECLARE
  cname TEXT;
BEGIN
  SELECT constraint_name INTO cname
  FROM information_schema.table_constraints tc
  JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
  WHERE tc.table_name = 'profiles' AND tc.constraint_type = 'CHECK'
    AND cc.check_clause LIKE '%gender%'
  LIMIT 1;

  IF cname IS NOT NULL THEN
    EXECUTE 'ALTER TABLE profiles DROP CONSTRAINT ' || cname;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
DECLARE
  cname TEXT;
BEGIN
  SELECT constraint_name INTO cname
  FROM information_schema.table_constraints tc
  JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
  WHERE tc.table_name = 'profiles' AND tc.constraint_type = 'CHECK'
    AND cc.check_clause LIKE '%category%'
  LIMIT 1;

  IF cname IS NOT NULL THEN
    EXECUTE 'ALTER TABLE profiles DROP CONSTRAINT ' || cname;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- ─── 10. HOMEWORK: drop tight status constraint ───

DO $$
DECLARE
  cname TEXT;
BEGIN
  SELECT constraint_name INTO cname
  FROM information_schema.table_constraints tc
  JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
  WHERE tc.table_name = 'homework' AND tc.constraint_type = 'CHECK'
    AND cc.check_clause LIKE '%status%'
  LIMIT 1;

  IF cname IS NOT NULL THEN
    EXECUTE 'ALTER TABLE homework DROP CONSTRAINT ' || cname;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Done!
