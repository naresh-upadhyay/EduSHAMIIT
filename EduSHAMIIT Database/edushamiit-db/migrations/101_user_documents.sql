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

-- Seed sample documents for each category
INSERT INTO user_documents (id, school_id, owner_id, title, description, category, content, mime_type, created_at) VALUES
  ('d0000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   '10000000-0000-0000-0000-000000000002',
   'Newton''s Laws of Motion — AI Summary',
   'AI-generated summary of Newton''s three laws with examples.',
   'ai_generated',
   '# Newton''s Laws of Motion\n\n## First Law\nAn object at rest stays at rest...\n\n## Second Law\nF = ma...\n\n## Third Law\nFor every action there is an equal and opposite reaction.',
   'text/plain',
   NOW() - INTERVAL '2 days'),
  ('d0000002-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   '10000000-0000-0000-0000-000000000002',
   'Chemistry Notes — Periodic Table',
   'My personal notes on periodic table trends.',
   'my_uploads', NULL, 'application/pdf', NOW() - INTERVAL '5 days'),
  ('d0000003-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111',
   '20000000-0000-0000-0000-000000000002',
   'Mid-Term Exam Study Guide',
   'Shared by Mrs. Priya Sharma for all students.',
   'teacher_shared', NULL, 'application/pdf', NOW() - INTERVAL '1 day')
ON CONFLICT (id) DO NOTHING;
