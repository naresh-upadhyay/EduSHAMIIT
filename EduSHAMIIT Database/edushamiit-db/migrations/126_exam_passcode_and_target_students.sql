-- Migration: 126_exam_passcode_and_target_students.sql
-- Description: Add passcode and target_students columns to exams table for security passcode protection and student targeting.
-- Author: Senior Architect

ALTER TABLE exams ADD COLUMN IF NOT EXISTS passcode TEXT;
ALTER TABLE exams ADD COLUMN IF NOT EXISTS target_students JSONB;
ALTER TABLE exams ADD COLUMN IF NOT EXISTS scope TEXT DEFAULT 'All Students';
