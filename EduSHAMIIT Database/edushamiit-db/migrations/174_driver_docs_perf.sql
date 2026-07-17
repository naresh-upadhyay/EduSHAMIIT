-- Create driver_documents table
CREATE TABLE IF NOT EXISTS driver_documents (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id           UUID REFERENCES schools(id) ON DELETE CASCADE,
  driver_id           UUID REFERENCES drivers(id) ON DELETE CASCADE,
  document_type       TEXT NOT NULL, -- 'Driving License', 'Badge', 'Police Verification', 'Aadhaar Card', 'Medical Certificate', 'Fitness Certificate', 'Pollution Certificate', etc.
  document_no         TEXT NOT NULL,
  issued_date         DATE,
  expiry_date         DATE,
  status              TEXT NOT NULL DEFAULT 'Valid', -- 'Valid', 'Expiring Soon', 'Expired', 'Permanent'
  file_url            TEXT,
  file_name           TEXT,
  file_size           INT,
  issuing_authority   TEXT,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_driver_docs_school ON driver_documents(school_id);
CREATE INDEX IF NOT EXISTS idx_driver_docs_driver ON driver_documents(driver_id);

-- Create driver_performance table
CREATE TABLE IF NOT EXISTS driver_performance (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id              UUID REFERENCES schools(id) ON DELETE CASCADE,
  driver_id              UUID REFERENCES drivers(id) ON DELETE CASCADE UNIQUE,
  attendance_score       NUMERIC(3, 2) DEFAULT 5.0,
  safety_score           NUMERIC(3, 2) DEFAULT 5.0,
  route_adherence_score  NUMERIC(3, 2) DEFAULT 5.0,
  vehicle_care_score     NUMERIC(3, 2) DEFAULT 5.0,
  feedback_score         NUMERIC(3, 2) DEFAULT 5.0,
  trips_completed        INTEGER DEFAULT 0,
  recent_feedback        TEXT,
  recent_feedback_date   DATE,
  created_at             TIMESTAMPTZ DEFAULT NOW(),
  updated_at             TIMESTAMPTZ DEFAULT NOW()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_driver_perf_school ON driver_performance(school_id);
CREATE INDEX IF NOT EXISTS idx_driver_perf_driver ON driver_performance(driver_id);
