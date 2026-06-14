-- ============================================================
-- Migration 124: Fix exam_sessions table by adding school_id
-- ============================================================

-- 1. Add school_id column to exam_sessions
ALTER TABLE exam_sessions ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;

-- 2. Populate school_id for existing rows based on exams table
UPDATE exam_sessions es
SET school_id = e.school_id
FROM exams e
WHERE es.exam_id = e.id AND es.school_id IS NULL;

-- 3. Create a trigger function to automatically populate school_id if missing
CREATE OR REPLACE FUNCTION set_exam_session_school_id()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.school_id IS NULL THEN
        SELECT school_id INTO NEW.school_id
        FROM public.exams
        WHERE id = NEW.exam_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Create trigger to call this function BEFORE INSERT OR UPDATE
CREATE OR REPLACE TRIGGER tr_set_exam_session_school_id
BEFORE INSERT OR UPDATE ON exam_sessions
FOR EACH ROW
EXECUTE FUNCTION set_exam_session_school_id();

-- 5. Create index on school_id
CREATE INDEX IF NOT EXISTS idx_exam_sessions_school ON exam_sessions(school_id);
