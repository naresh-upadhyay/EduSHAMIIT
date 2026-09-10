-- ============================================================
-- Migration 096: Admin CRUD — Content Distribution & Column Additions
-- EduSHAMIIT — Shami Innovation and Technologies LLP
--
-- What this adds (no duplicates — all existing tables checked):
--   1.  content_distributions  NEW table (doesn't exist yet)
--   2.  salary                 ADD missing columns: allowances, month (text), net_pay, remarks, updated_at
--                              (015_salary.sql has amount/month(int)/status — we ADD the payroll cols)
--   3.  library_borrows        ADD: return_date (date), is_returned (bool)
--                              (027 has returned_at TIMESTAMPTZ — we add friendly aliases)
--   4.  student_transport      ADD UNIQUE constraint on (school_id, student_id) if missing
--   5.  study_materials        ADD: target_classes TEXT[], target_student_ids UUID[]
--   6.  notices                ADD: target_classes TEXT[], target_student_ids UUID[]
--   7.  homework               ADD: target_student_ids UUID[]
--   8.  live_classes           ADD: ended_at TIMESTAMPTZ
--   9.  attendance             ADD: corrected_by UUID, corrected_at TIMESTAMPTZ
--  10.  leave_applications     ADD: rejection_reason TEXT, reviewed_by UUID, reviewed_at TIMESTAMPTZ
-- ============================================================


-- -------------------------------------------------------
-- 1. content_distributions  (brand-new table)
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS content_distributions (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id                UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    content_type             TEXT NOT NULL,
    content_id               UUID,
    sender_id                UUID REFERENCES profiles(id) ON DELETE SET NULL,
    target_classes           TEXT[]   DEFAULT '{}',
    target_student_ids       UUID[]   DEFAULT '{}',
    include_parents          BOOLEAN  DEFAULT FALSE,
    resolved_recipient_count INT      DEFAULT 0,
    created_at               TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_content_dist_school  ON content_distributions (school_id);
CREATE INDEX IF NOT EXISTS idx_content_dist_type    ON content_distributions (content_type, school_id);
CREATE INDEX IF NOT EXISTS idx_content_dist_sender  ON content_distributions (sender_id);


-- -------------------------------------------------------
-- 2. salary — add payroll columns missing from 015_salary.sql
--    (015 has: amount, month INT, year, status, paid_at)
--    (089 added: basic_pay, hra, da, ta, deductions, net_pay, pay_period, payment_mode)
--    We add: allowances (alias for hra+da+ta), month_str (text YYYY-MM), remarks, updated_at
-- -------------------------------------------------------
ALTER TABLE salary
    ADD COLUMN IF NOT EXISTS allowances   NUMERIC(12, 2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS month_str    TEXT,           -- 'YYYY-MM' format for admin API
    ADD COLUMN IF NOT EXISTS remarks      TEXT,
    ADD COLUMN IF NOT EXISTS updated_at   TIMESTAMPTZ DEFAULT NOW();

-- Unique constraint: one payslip per teacher per month_str
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'salary_school_teacher_month_str_key'
          AND conrelid = 'salary'::regclass
    ) THEN
        ALTER TABLE salary ADD CONSTRAINT salary_school_teacher_month_str_key
            UNIQUE (school_id, teacher_id, month_str);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;


-- -------------------------------------------------------
-- 3. library_borrows — add friendly boolean return columns
--    (027 has: returned_at TIMESTAMPTZ, status TEXT)
-- -------------------------------------------------------
ALTER TABLE library_borrows
    ADD COLUMN IF NOT EXISTS return_date  DATE,
    ADD COLUMN IF NOT EXISTS is_returned  BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS due_date     DATE;


-- -------------------------------------------------------
-- 4. student_transport — add UNIQUE (school_id, student_id) if missing
-- -------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'student_transport_school_student_key'
          AND conrelid = 'student_transport'::regclass
    ) THEN
        ALTER TABLE student_transport ADD CONSTRAINT student_transport_school_student_key
            UNIQUE (school_id, student_id);
    END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;


-- -------------------------------------------------------
-- 5. study_materials — add distribution targeting columns
-- -------------------------------------------------------
ALTER TABLE study_materials
    ADD COLUMN IF NOT EXISTS target_classes      TEXT[],
    ADD COLUMN IF NOT EXISTS target_student_ids  UUID[];


-- -------------------------------------------------------
-- 6. notices — add distribution targeting columns
-- -------------------------------------------------------
ALTER TABLE notices
    ADD COLUMN IF NOT EXISTS target_classes      TEXT[],
    ADD COLUMN IF NOT EXISTS target_student_ids  UUID[];


-- -------------------------------------------------------
-- 7. homework — add individual student targeting
-- -------------------------------------------------------
ALTER TABLE homework
    ADD COLUMN IF NOT EXISTS target_student_ids  UUID[];


-- -------------------------------------------------------
-- 8. live_classes — add ended_at timestamp
-- -------------------------------------------------------
ALTER TABLE live_classes
    ADD COLUMN IF NOT EXISTS ended_at  TIMESTAMPTZ;


-- -------------------------------------------------------
-- 9. attendance — add correction audit columns
-- -------------------------------------------------------
ALTER TABLE attendance
    ADD COLUMN IF NOT EXISTS corrected_by   UUID REFERENCES profiles(id),
    ADD COLUMN IF NOT EXISTS corrected_at   TIMESTAMPTZ;


-- -------------------------------------------------------
-- 10. leave_applications — add review/rejection columns
--     (023 already has: reviewed_by, reviewed_at based on teacher.py usage)
--     We add: rejection_reason (may be missing)
-- -------------------------------------------------------
ALTER TABLE leave_applications
    ADD COLUMN IF NOT EXISTS rejection_reason  TEXT,
    ADD COLUMN IF NOT EXISTS reviewed_by       UUID REFERENCES profiles(id),
    ADD COLUMN IF NOT EXISTS reviewed_at       TIMESTAMPTZ;


-- -------------------------------------------------------
-- Indexes for new columns
-- -------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_content_dist_content_id ON content_distributions (content_id);
CREATE INDEX IF NOT EXISTS idx_salary_month_str        ON salary (month_str, school_id);

-- -------------------------------------------------------
-- 11. profiles — update check constraint to allow new roles
-- -------------------------------------------------------
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check CHECK (role IN (
    'student', 'parent', 'teacher', 'admin', 'student_admin', 'teacher_admin',
    'driver', 'superadmin', 'principal', 'accountant', 'librarian', 'staff',
    'clerk', 'guard', 'bus_driver', 'system_admin', 'support', 'director'
)) NOT VALID;

-- -------------------------------------------------------
-- Done — Migration 096 complete
-- -------------------------------------------------------
