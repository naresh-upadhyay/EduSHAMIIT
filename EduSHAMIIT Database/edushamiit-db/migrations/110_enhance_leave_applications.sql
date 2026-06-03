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

-- ─── UPCOMING LEAVES (future dates from today ≈ 2026-06-02) ───────────────────

-- Student upcoming leaves
INSERT INTO leave_applications (id, school_id, applicant_id, applicant_role, leave_type, start_date, end_date, reason, status, created_at)
VALUES
  ('11000000-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111',
   '10000000-0000-0000-0000-000000000002',
   'student', 'Sick Leave',
   '2026-06-10', '2026-06-12',
   'Not feeling well, doctor advised rest.',
   'pending', NOW()),

  ('11000000-0000-0000-0000-000000000002',
   '11111111-1111-1111-1111-111111111111',
   '10000000-0000-0000-0000-000000000002',
   'student', 'Family Event',
   '2026-06-20', '2026-06-21',
   'Sister''s wedding ceremony.',
   'approved', NOW()),

  ('11000000-0000-0000-0000-000000000003',
   '11111111-1111-1111-1111-111111111111',
   '10000000-0000-0000-0000-000000000003',
   'student', 'Sports Competition',
   '2026-06-15', '2026-06-17',
   'Selected for state-level basketball tournament.',
   'pending', NOW()),

  ('11000000-0000-0000-0000-000000000004',
   '11111111-1111-1111-1111-111111111111',
   '10000000-0000-0000-0000-000000000004',
   'student', 'Casual Leave',
   '2026-06-25', '2026-06-25',
   'Personal work.',
   'approved', NOW())

ON CONFLICT (id) DO NOTHING;

-- Teacher upcoming leaves
INSERT INTO leave_applications (id, school_id, applicant_id, applicant_role, leave_type, start_date, end_date, reason, status, created_at)
VALUES
  ('11000000-0000-0000-0000-000000000005',
   '11111111-1111-1111-1111-111111111111',
   '20000000-0000-0000-0000-000000000002',
   'teacher', 'Casual Leave',
   '2026-06-08', '2026-06-08',
   'Personal work at home.',
   'pending', NOW()),

  ('11000000-0000-0000-0000-000000000006',
   '11111111-1111-1111-1111-111111111111',
   '20000000-0000-0000-0000-000000000002',
   'teacher', 'Sick Leave',
   '2026-06-18', '2026-06-19',
   'Medical checkup and rest advised by doctor.',
   'approved', NOW()),

  ('11000000-0000-0000-0000-000000000007',
   '11111111-1111-1111-1111-111111111111',
   '20000000-0000-0000-0000-000000000003',
   'teacher', 'Earned Leave',
   '2026-06-28', '2026-06-30',
   'Family vacation.',
   'pending', NOW())

ON CONFLICT (id) DO NOTHING;

-- ─── PAST LEAVES (past dates before 2026-06-02) ─────────────────────────────

-- Student past leaves
INSERT INTO leave_applications (id, school_id, applicant_id, applicant_role, leave_type, start_date, end_date, reason, status, rejection_reason, created_at)
VALUES
  ('11000000-0000-0000-0000-000000000010',
   '11111111-1111-1111-1111-111111111111',
   '10000000-0000-0000-0000-000000000002',
   'student', 'Sick Leave',
   '2026-05-05', '2026-05-06',
   'Severe headache and fever.',
   'approved', NULL, '2026-05-03T09:00:00Z'),

  ('11000000-0000-0000-0000-000000000011',
   '11111111-1111-1111-1111-111111111111',
   '10000000-0000-0000-0000-000000000002',
   'student', 'Casual Leave',
   '2026-05-12', '2026-05-12',
   'Personal errand.',
   'rejected', 'Insufficient reason provided.', '2026-05-10T10:00:00Z'),

  ('11000000-0000-0000-0000-000000000012',
   '11111111-1111-1111-1111-111111111111',
   '10000000-0000-0000-0000-000000000002',
   'student', 'Family Event',
   '2026-04-18', '2026-04-19',
   'Cousin''s engagement ceremony.',
   'approved', NULL, '2026-04-15T11:00:00Z'),

  ('11000000-0000-0000-0000-000000000013',
   '11111111-1111-1111-1111-111111111111',
   '10000000-0000-0000-0000-000000000002',
   'student', 'Urgent Work',
   '2026-04-28', '2026-04-28',
   'Hospital visit for family member.',
   'cancelled', NULL, '2026-04-27T08:00:00Z')

ON CONFLICT (id) DO NOTHING;

-- Teacher past leaves
INSERT INTO leave_applications (id, school_id, applicant_id, applicant_role, leave_type, start_date, end_date, reason, status, rejection_reason, created_at)
VALUES
  ('11000000-0000-0000-0000-000000000014',
   '11111111-1111-1111-1111-111111111111',
   '20000000-0000-0000-0000-000000000002',
   'teacher', 'Sick Leave',
   '2026-05-08', '2026-05-09',
   'High fever and cold.',
   'approved', NULL, '2026-05-06T09:00:00Z'),

  ('11000000-0000-0000-0000-000000000015',
   '11111111-1111-1111-1111-111111111111',
   '20000000-0000-0000-0000-000000000002',
   'teacher', 'Earned Leave',
   '2026-05-22', '2026-05-24',
   'Annual leave for personal travel.',
   'approved', NULL, '2026-05-18T10:00:00Z'),

  ('11000000-0000-0000-0000-000000000016',
   '11111111-1111-1111-1111-111111111111',
   '20000000-0000-0000-0000-000000000002',
   'teacher', 'Casual Leave',
   '2026-05-30', '2026-05-30',
   'Personal work.',
   'rejected', 'No substitute arranged.', '2026-05-28T14:00:00Z')

ON CONFLICT (id) DO NOTHING;
