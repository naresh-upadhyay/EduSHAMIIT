-- ============================================================
-- Migration 094: Parent-Student Relations
-- Many-to-many relationship between parents and students
-- ============================================================

CREATE TABLE IF NOT EXISTS parent_student_relations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  parent_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  relationship TEXT NOT NULL CHECK (relationship IN ('father','mother','guardian','other')),
  is_primary BOOLEAN DEFAULT FALSE,
  can_pickup BOOLEAN DEFAULT FALSE,
  approved BOOLEAN DEFAULT FALSE,
  approved_by UUID REFERENCES profiles(id),
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(parent_id, student_id)
);

-- Index for quick lookup of all children for a parent
CREATE INDEX idx_psr_parent_id ON parent_student_relations(parent_id) WHERE approved = TRUE;

-- Index for quick lookup of all parents for a student
CREATE INDEX idx_psr_student_id ON parent_student_relations(student_id) WHERE approved = TRUE;

-- Index for school-level queries
CREATE INDEX idx_psr_school_id ON parent_student_relations(school_id);

-- Enable RLS
ALTER TABLE parent_student_relations ENABLE ROW LEVEL SECURITY;
