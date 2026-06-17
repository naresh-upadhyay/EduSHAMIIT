-- Migration 130: Add camera_active and mic_active columns to exam_sessions table
ALTER TABLE exam_sessions 
ADD COLUMN IF NOT EXISTS camera_active BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS mic_active BOOLEAN DEFAULT true;
