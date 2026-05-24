-- Migration 099: Add Course High Fidelity Mockup Fields
-- EduSHAMIIT — Shami Innovation and Technologies LLP

ALTER TABLE courses
    ADD COLUMN IF NOT EXISTS syllabus_coverage JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS upcoming_topics JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS resources_text TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS chapters_count TEXT DEFAULT '';
