CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  title TEXT NOT NULL,
  description TEXT,
  event_date DATE,
  event_time TIME,
  venue TEXT,
  banner_url TEXT,
  gradient_colors JSONB,
  max_participants INT,
  current_participants INT DEFAULT 0,
  registration_deadline DATE,
  is_registration_open BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);