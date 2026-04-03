CREATE TABLE IF NOT EXISTS live_classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
  teacher_id UUID REFERENCES profiles(id),
  title TEXT NOT NULL,
  description TEXT,
  scheduled_at TIMESTAMPTZ NOT NULL,
  duration_minutes INT DEFAULT 60,
  platform TEXT DEFAULT 'EduSHAMIIT',
  stream_url TEXT,
  recording_url TEXT,
  is_live BOOLEAN DEFAULT FALSE,
  viewer_count INT DEFAULT 0,
  target_class TEXT,
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('draft','scheduled','live','completed','recorded')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);