-- ============================================================
-- Migration 090: Seed Salary & Enhanced Exam Data
-- Adds realistic salary records for teacher users
-- Updates existing exams with new ERP columns
-- ============================================================

-- ─── 1. SALARY: Seed 6 months of salary for existing teachers ───

INSERT INTO salary (school_id, teacher_id, amount, basic_pay, hra, da, ta, deductions, net_pay, month, year, status, pay_period, payment_mode, paid_at)
SELECT
  p.school_id,
  p.id,
  55000.00,
  35000.00,
  8750.00,
  7000.00,
  3000.00,
  4250.00,
  49500.00,
  m.month_num,
  2026,
  CASE WHEN m.month_num <= 3 THEN 'paid' ELSE 'pending' END,
  '2026-' || LPAD(m.month_num::TEXT, 2, '0'),
  'bank_transfer',
  CASE WHEN m.month_num <= 3 THEN ('2026-' || LPAD(m.month_num::TEXT, 2, '0') || '-28')::TIMESTAMPTZ ELSE NULL END
FROM profiles p
CROSS JOIN (SELECT generate_series(1,6) AS month_num) m
WHERE p.role = 'teacher'
  AND p.school_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM salary s
    WHERE s.teacher_id = p.id AND s.month = m.month_num AND s.year = 2026
  )
LIMIT 18;  -- max 3 teachers x 6 months

-- ─── 2. EXAMS: Update existing exams with new columns ───

UPDATE exams
SET teacher_id = (
      SELECT p.id FROM profiles p
      WHERE p.role = 'teacher' AND p.school_id = exams.school_id
      LIMIT 1
    ),
    exam_type = CASE
      WHEN title ILIKE '%unit%' OR title ILIKE '%class%' THEN 'offline'
      WHEN title ILIKE '%online%' THEN 'online'
      ELSE 'offline'
    END,
    exam_category = CASE
      WHEN title ILIKE '%unit%' THEN 'Unit Test'
      WHEN title ILIKE '%mid%' THEN 'Mid Term'
      WHEN title ILIKE '%final%' OR title ILIKE '%end%' THEN 'End Term'
      ELSE 'Class Test'
    END,
    exam_date = COALESCE(start_time::DATE, CURRENT_DATE + INTERVAL '7 days'),
    venue = 'Examination Hall'
WHERE teacher_id IS NULL;
