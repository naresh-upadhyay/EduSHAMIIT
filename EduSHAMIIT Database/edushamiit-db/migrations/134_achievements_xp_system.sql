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

-- Insert or update default templates dynamically for top school
DO $$
DECLARE
  v_school_id UUID;
BEGIN
  SELECT school_id INTO v_school_id FROM public.profiles WHERE email = 'shamiitltd@gmail.com' LIMIT 1;
  IF v_school_id IS NULL THEN
    SELECT id INTO v_school_id FROM public.schools ORDER BY created_at ASC LIMIT 1;
  END IF;
  IF v_school_id IS NOT NULL THEN
    INSERT INTO achievements (id, school_id, name, description, icon, xp_reward, rarity, criteria) VALUES
      ('30000000-0000-0000-0000-000000000002', v_school_id, 'Academic Excellence', 'Score 90%+ in any examination', '🏆', 500, 'rare', 'Score >= 90% in exam'),
      ('30000000-0000-0000-0000-000000000003', v_school_id, '18-Day Streak', 'Maintain learning streak for 18 days', '🔥', 300, 'uncommon', 'Streak >= 18 days'),
      ('30000000-0000-0000-0000-000000000004', v_school_id, 'Zero Late Submissions', 'Grade 5 homeworks on time', '✅', 200, 'common', '5 graded homeworks'),
      ('30000000-0000-0000-0000-000000000005', v_school_id, 'Perfect Attendance', 'Attend at least 10 classes', '📅', 400, 'rare', 'Attendance >= 10 classes')
    ON CONFLICT (id) DO UPDATE SET 
      name = EXCLUDED.name, 
      description = EXCLUDED.description, 
      icon = EXCLUDED.icon, 
      xp_reward = EXCLUDED.xp_reward, 
      criteria = EXCLUDED.criteria;
  END IF;
END $$;
