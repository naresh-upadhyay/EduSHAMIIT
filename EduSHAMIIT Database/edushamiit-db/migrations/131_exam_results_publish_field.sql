-- ============================================================
-- Migration 131: Add exam results publishing fields
-- Adds results_published_at to exams and enriches exam_submissions
-- ============================================================

-- Add results_published_at to track when exam results were published to students
ALTER TABLE exams
  ADD COLUMN IF NOT EXISTS results_published_at TIMESTAMPTZ DEFAULT NULL;

-- Add remarks/feedback column to exam_submissions for teacher feedback
ALTER TABLE exam_submissions
  ADD COLUMN IF NOT EXISTS remarks TEXT DEFAULT NULL;

-- Add grade_letter column for letter grade (A+, A, B, C, D, F)
ALTER TABLE exam_submissions
  ADD COLUMN IF NOT EXISTS grade_letter TEXT DEFAULT NULL;

-- Add is_pass column for pass/fail determination
ALTER TABLE exam_submissions
  ADD COLUMN IF NOT EXISTS is_pass BOOLEAN DEFAULT NULL;

-- Add class_rank for ranking students within an exam
ALTER TABLE exam_submissions
  ADD COLUMN IF NOT EXISTS class_rank INTEGER DEFAULT NULL;

-- Index for quickly fetching published exam results
CREATE INDEX IF NOT EXISTS idx_exams_results_published_at ON exams(results_published_at) WHERE results_published_at IS NOT NULL;

-- Index for efficient submission score queries
CREATE INDEX IF NOT EXISTS idx_exam_submissions_exam_score ON exam_submissions(exam_id, score DESC NULLS LAST);
