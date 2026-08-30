CREATE TABLE IF NOT EXISTS subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  name TEXT NOT NULL,
  icon TEXT,
  color TEXT,
  teacher_id UUID REFERENCES profiles(id),
  total_chapters INT DEFAULT 0,
  class TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed core subjects for primary institute
INSERT INTO subjects (id, school_id, name, icon, color, class, total_chapters)
VALUES
  ('cc000001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Mathematics', '📐', '#4F46E5', '10A', 14),
  ('cc000004-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'Physics', '🔬', '#06B6D4', '10A', 12),
  ('de23de6c-0574-4501-80cb-5bd150d8eac9', '11111111-1111-1111-1111-111111111111', 'Chemistry', '🧪', '#10B981', '10A', 10),
  ('5f45ac94-a452-42c4-bfa1-1538c2b0b1cb', '11111111-1111-1111-1111-111111111111', 'English', '📖', '#F59E0B', '10A', 16)
ON CONFLICT (id) DO NOTHING; 
