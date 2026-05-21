-- ============================================================
-- Migration 094: Add Teacher Profile Bio, Joining Date, and Specialization Columns
-- ============================================================

ALTER TABLE profiles 
  ADD COLUMN IF NOT EXISTS bio TEXT,
  ADD COLUMN IF NOT EXISTS joining_date DATE DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS specialization TEXT;
