-- ============================================================
-- Migration 081: Groups & Group Members
-- Required by: /api/student/groups, /api/teacher/groups,
--              /api/student/groups/create, /api/teacher/groups/create
-- ============================================================

-- Groups table: study/class groups created by teachers or students
CREATE TABLE IF NOT EXISTS groups (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id   UUID REFERENCES schools(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  description TEXT,
  created_by  UUID REFERENCES profiles(id) ON DELETE SET NULL,
  avatar_url  TEXT,
  is_active   BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Group members: tracks which profiles belong to which group
CREATE TABLE IF NOT EXISTS group_members (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id   UUID REFERENCES groups(id) ON DELETE CASCADE,
  member_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
  role       TEXT DEFAULT 'member',   -- 'admin' | 'member'
  joined_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (group_id, member_id)
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_groups_school_id   ON groups (school_id);
CREATE INDEX IF NOT EXISTS idx_groups_created_by  ON groups (created_by);
CREATE INDEX IF NOT EXISTS idx_group_members_group ON group_members (group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_member ON group_members (member_id);

-- Backfill the FK on messages.group_id now that groups exists
-- (safe to run even if the FK already exists)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'messages_group_id_fkey'
      AND table_name = 'messages'
  ) THEN
    ALTER TABLE messages
      ADD CONSTRAINT messages_group_id_fkey
      FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE SET NULL;
  END IF;
END $$;
