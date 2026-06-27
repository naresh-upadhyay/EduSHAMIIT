-- Migration 112: Salary Advance Table and Enhancements
-- Adds column for advance deduction to salary and creates salary_advances table.

ALTER TABLE salary
  ADD COLUMN IF NOT EXISTS advance_deduction NUMERIC(10,2) DEFAULT 0;

CREATE TABLE IF NOT EXISTS salary_advances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id) ON DELETE CASCADE,
  teacher_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  amount NUMERIC(10,2) NOT NULL,
  purpose_type TEXT NOT NULL,
  reason TEXT,
  status TEXT DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
  month INTEGER NOT NULL,
  year INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE salary_advances ENABLE ROW LEVEL SECURITY;

-- Create policies for direct client access (drop first to allow re-apply)
DROP POLICY IF EXISTS "own_salary_advances" ON salary_advances;
CREATE POLICY "own_salary_advances" ON salary_advances
  FOR SELECT USING (auth.uid() = teacher_id);

DROP POLICY IF EXISTS "insert_own_salary_advances" ON salary_advances;
CREATE POLICY "insert_own_salary_advances" ON salary_advances
  FOR INSERT WITH CHECK (auth.uid() = teacher_id);

DROP POLICY IF EXISTS "update_own_salary_advances" ON salary_advances;
CREATE POLICY "update_own_salary_advances" ON salary_advances
  FOR UPDATE USING (auth.uid() = teacher_id);
