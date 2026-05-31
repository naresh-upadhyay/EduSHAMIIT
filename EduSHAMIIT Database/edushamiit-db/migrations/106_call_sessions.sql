-- Migration 106: Call Sessions — WebRTC Audio/Video Call CDR
-- EduSHAMIIT — Shami Innovation and Technologies LLP

CREATE TABLE IF NOT EXISTS call_sessions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id     UUID REFERENCES schools(id) ON DELETE CASCADE,
  caller_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  callee_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  call_type     TEXT NOT NULL CHECK (call_type IN ('audio', 'video')),
  status        TEXT NOT NULL DEFAULT 'ringing'
                CHECK (status IN ('ringing', 'answered', 'ended', 'rejected', 'missed')),
  started_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  answered_at   TIMESTAMPTZ,
  ended_at      TIMESTAMPTZ,
  duration_seconds INT GENERATED ALWAYS AS (
    CASE
      WHEN ended_at IS NOT NULL AND answered_at IS NOT NULL
      THEN EXTRACT(EPOCH FROM (ended_at - answered_at))::INT
      ELSE NULL
    END
  ) STORED
);

-- Indexes for call history queries
CREATE INDEX IF NOT EXISTS idx_call_sessions_caller ON call_sessions(caller_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_call_sessions_callee ON call_sessions(callee_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_call_sessions_school  ON call_sessions(school_id, started_at DESC);

-- Enable Supabase Realtime for call_sessions (for signaling status updates)
ALTER TABLE call_sessions REPLICA IDENTITY FULL;
