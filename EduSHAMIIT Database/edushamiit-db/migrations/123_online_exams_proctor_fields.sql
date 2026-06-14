-- ============================================================
-- Migration 123: Add Proctoring & Real-time Fields to Exam Sessions
-- Adds columns to track warnings, active question, ping status,
-- pausing, extra duration, and messages from the teacher.
-- ============================================================

ALTER TABLE exam_sessions 
ADD COLUMN IF NOT EXISTS warnings_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS active_question UUID REFERENCES exam_questions(id),
ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS last_ping TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS is_paused BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS extra_minutes INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS teacher_message TEXT;

-- Create an index to speed up querying by last_ping / online status
CREATE INDEX IF NOT EXISTS idx_exam_sessions_ping ON exam_sessions(last_ping);
