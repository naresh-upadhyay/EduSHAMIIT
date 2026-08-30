-- Migration 101: Create user_documents table for Documents Hub
-- EduSHAMIIT — Shami Innovation and Technologies LLP

CREATE TABLE IF NOT EXISTS user_documents (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id               TEXT NOT NULL,
  owner_id                UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  shared_with_id          UUID REFERENCES profiles(id) ON DELETE SET NULL,
  shared_by_id            UUID REFERENCES profiles(id) ON DELETE SET NULL,
  title                   TEXT NOT NULL,
  description             TEXT,
  category                TEXT NOT NULL DEFAULT 'my_uploads'
                            CHECK (category IN ('ai_generated','my_uploads','teacher_shared','chat_shared','school_notice')),
  file_url                TEXT,
  file_name               TEXT,
  file_size               BIGINT,
  mime_type               TEXT,
  storage_path            TEXT,
  content                 TEXT,
  source_chat_session_id  TEXT,
  created_at              TIMESTAMPTZ DEFAULT now(),
  updated_at              TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_documents_owner 
  ON user_documents (school_id, owner_id, category);
CREATE INDEX IF NOT EXISTS idx_user_documents_shared 
  ON user_documents (school_id, shared_with_id, category);
CREATE INDEX IF NOT EXISTS idx_user_documents_created 
  ON user_documents (created_at DESC);

-- Seed sample documents for logged-in user shamiitltd@gmail.com and primary school
DO $$
DECLARE
  v_school_id UUID;
  v_user_id UUID;
  v_teacher_id UUID;
BEGIN
  -- Prioritize shamiitltd@gmail.com as primary user
  SELECT id, school_id INTO v_user_id, v_school_id 
  FROM public.profiles 
  WHERE email = 'shamiitltd@gmail.com' 
  LIMIT 1;

  IF v_user_id IS NULL THEN
    SELECT id, school_id INTO v_user_id, v_school_id 
    FROM public.profiles 
    WHERE role = 'super_admin' 
    ORDER BY created_at ASC LIMIT 1;
  END IF;

  IF v_user_id IS NULL THEN
    SELECT id, school_id INTO v_user_id, v_school_id 
    FROM public.profiles 
    ORDER BY created_at ASC LIMIT 1;
  END IF;

  IF v_school_id IS NULL THEN
    SELECT id INTO v_school_id FROM public.schools ORDER BY created_at ASC LIMIT 1;
  END IF;

  SELECT id INTO v_teacher_id FROM public.profiles WHERE role = 'teacher' ORDER BY created_at ASC LIMIT 1;
  IF v_teacher_id IS NULL THEN
    v_teacher_id := v_user_id;
  END IF;

  IF v_school_id IS NOT NULL AND v_user_id IS NOT NULL THEN
    INSERT INTO user_documents (id, school_id, owner_id, title, description, category, content, mime_type, created_at)
    VALUES
      ('d0000001-0000-0000-0000-000000000001', v_school_id, v_user_id,
       'Newton''s Laws of Motion — AI Summary',
       'AI-generated summary of Newton''s three laws with examples.',
       'ai_generated',
       '# Newton''s Laws of Motion\n\n## First Law\nAn object at rest stays at rest...\n\n## Second Law\nF = ma...\n\n## Third Law\nFor every action there is an equal and opposite reaction.',
       'text/plain',
       NOW() - INTERVAL '2 days'),
      ('d0000002-0000-0000-0000-000000000002', v_school_id, v_user_id,
       'Chemistry Notes — Periodic Table',
       'My personal notes on periodic table trends.',
       'my_uploads', NULL, 'application/pdf', NOW() - INTERVAL '5 days'),
      ('d0000003-0000-0000-0000-000000000003', v_school_id, v_user_id,
       'Mid-Term Exam Study Guide & Syllabus',
       'Institutional study guide for examinations.',
       'teacher_shared', NULL, 'application/pdf', NOW() - INTERVAL '1 day')
    ON CONFLICT (id) DO UPDATE SET
      owner_id = EXCLUDED.owner_id,
      school_id = EXCLUDED.school_id;
  END IF;
END $$;
