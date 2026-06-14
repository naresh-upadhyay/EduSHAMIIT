-- Migration: 127_add_exam_release_time.sql
-- Description: Add release_time column to exams table to separate scheduled releases from exam start/end times.
-- Author: Senior Architect

ALTER TABLE exams ADD COLUMN IF NOT EXISTS release_time TIMESTAMPTZ;
