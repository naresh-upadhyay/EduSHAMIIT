-- Achievements & XP Points System Database Migration
CREATE TABLE IF NOT EXISTS xp_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  amount INT NOT NULL,
  source_type TEXT NOT NULL, -- 'exam', 'homework', 'attendance', 'event_participation', 'event_prize', 'achievement', 'manual_penalty', 'teacher_task'
  source_id UUID,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Extend achievements with target_class to allow targeting specific classrooms
ALTER TABLE achievements ADD COLUMN IF NOT EXISTS target_class TEXT NULL;

-- Enable RLS
ALTER TABLE xp_transactions ENABLE ROW LEVEL SECURITY;

-- Policies (bypassed by backend service role connections, enforced for public API queries)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'xp_transactions' AND policyname = 'school_isolation_xp_transactions'
  ) THEN
    CREATE POLICY "school_isolation_xp_transactions" ON xp_transactions 
      USING (school_id = (SELECT school_id FROM profiles WHERE id = auth.uid()));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'xp_transactions' AND policyname = 'own_xp_transactions'
  ) THEN
    CREATE POLICY "own_xp_transactions" ON xp_transactions 
      FOR SELECT USING (auth.uid() = student_id);
  END IF;
END
$$;

-- Insert or update default templates
INSERT INTO achievements (id, school_id, name, description, icon, xp_reward, rarity, criteria) VALUES
  ('30000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Academic Excellence', 'Score 90%+ in any examination', '🏆', 500, 'rare', 'Score >= 90% in exam'),
  ('30000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', '18-Day Streak', 'Maintain learning streak for 18 days', '🔥', 300, 'uncommon', 'Streak >= 18 days'),
  ('30000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'Zero Late Submissions', 'Grade 5 homeworks on time', '✅', 200, 'common', '5 graded homeworks'),
  ('30000000-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', 'Perfect Attendance', 'Attend at least 10 classes', '📅', 400, 'rare', 'Attendance >= 10 classes')
ON CONFLICT (id) DO UPDATE SET 
  name = EXCLUDED.name, 
  description = EXCLUDED.description, 
  icon = EXCLUDED.icon, 
  xp_reward = EXCLUDED.xp_reward, 
  criteria = EXCLUDED.criteria;
