-- ============================================================
-- Migration 097: Add Event and Achievement Columns
-- EduSHAMIIT — Shami Innovation and Technologies LLP
--
-- Adds additional auditing and metadata columns to:
--   1.  events                ADD: category, is_mandatory, created_by
--   2.  student_achievements  ADD: awarded_by
-- ============================================================

-- -------------------------------------------------------
-- 1. events
-- -------------------------------------------------------
ALTER TABLE events
    ADD COLUMN IF NOT EXISTS category      TEXT DEFAULT 'General',
    ADD COLUMN IF NOT EXISTS is_mandatory  BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS created_by    UUID REFERENCES profiles(id) ON DELETE SET NULL;

-- -------------------------------------------------------
-- 2. student_achievements
-- -------------------------------------------------------
ALTER TABLE student_achievements
    ADD COLUMN IF NOT EXISTS awarded_by    UUID REFERENCES profiles(id) ON DELETE SET NULL;
