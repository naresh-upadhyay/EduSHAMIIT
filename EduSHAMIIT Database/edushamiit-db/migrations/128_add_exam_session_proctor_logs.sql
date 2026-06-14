-- ============================================================
-- Migration 128: Add proctor_logs JSONB column to exam_sessions
-- ============================================================

ALTER TABLE exam_sessions 
ADD COLUMN proctor_logs JSONB DEFAULT '[]'::jsonb;
