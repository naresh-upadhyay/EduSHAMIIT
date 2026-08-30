-- Migration 135: Rule-Based Badge System
-- Adds rule-based fields to achievements and configures rules for badges

-- SET ROLE supabase_admin; -- commented out for cloud migrations (non-superuser)

ALTER TABLE public.achievements ADD COLUMN IF NOT EXISTS rule_type TEXT NULL;
ALTER TABLE public.achievements ADD COLUMN IF NOT EXISTS rule_params JSONB NULL;

-- 1. Academic Excellence (Score 90%+ in exams)
UPDATE public.achievements
SET rule_type = 'subject_average',
    rule_params = '{"min_average": 90.0}'::jsonb
WHERE id IN ('30000000-0000-0000-0000-000000000002', 'c2000001-0000-0000-0000-000000000001');

-- 2. streak (18-Day Streak)
UPDATE public.achievements
SET rule_type = 'streak_days',
    rule_params = '{"min_days": 18}'::jsonb
WHERE id IN ('30000000-0000-0000-0000-000000000003', 'c2000005-0000-0000-0000-000000000005');

-- 3. Homework Hero / Zero Late Submissions
UPDATE public.achievements
SET rule_type = 'homework_submissions',
    rule_params = '{"count": 5}'::jsonb
WHERE id = '30000000-0000-0000-0000-000000000004';

UPDATE public.achievements
SET rule_type = 'homework_submissions',
    rule_params = '{"count": 10}'::jsonb
WHERE id = 'c2000004-0000-0000-0000-000000000004';

-- 4. Perfect Attendance / 100% Attendance
UPDATE public.achievements
SET rule_type = 'attendance_pct',
    rule_params = '{"min_percentage": 100.0}'::jsonb
WHERE id IN ('30000000-0000-0000-0000-000000000005', 'c2000002-0000-0000-0000-000000000002', 'd011473a-706c-45d8-8488-19cf85d53fe5');

-- 4.1. Library Devotee (Borrowed and read 10+ books)
UPDATE public.achievements
SET rule_type = 'library_borrows',
    rule_params = '{"count": 10}'::jsonb
WHERE id = '94a98609-9921-4e3b-85a0-5ca9f1446f32';

-- 4.2. Science Prodigy (Average over 90% in multiple STEM subjects)
UPDATE public.achievements
SET rule_type = 'science_prodigy',
    rule_params = '{"min_average": 90.0, "min_subjects": 2}'::jsonb
WHERE id = 'd91a6bb0-fde9-409d-a2f5-c19b823b057b';


-- 5. Maths Top Scorer & Gold Medal Achievements (Dynamic School Lookup)
DO $$
DECLARE
  v_school_id UUID;
BEGIN
  SELECT school_id INTO v_school_id FROM public.profiles WHERE email = 'shamiitltd@gmail.com' LIMIT 1;
  IF v_school_id IS NULL THEN
    SELECT id INTO v_school_id FROM public.schools ORDER BY created_at ASC LIMIT 1;
  END IF;
  IF v_school_id IS NOT NULL THEN
    INSERT INTO public.achievements (id, school_id, name, description, icon, xp_reward, rarity, criteria, rule_type, rule_params)
    VALUES (
      '30000000-0000-0000-0000-000000000007',
      v_school_id,
      'Maths Top Scorer',
      'Get at least 90% average in Mathematics',
      '📐',
      350,
      'rare',
      'Maths Average >= 90%',
      'subject_average',
      '{"subject_name": "Mathematics", "min_average": 90.0}'::jsonb
    )
    ON CONFLICT (id) DO UPDATE SET
      rule_type = EXCLUDED.rule_type,
      rule_params = EXCLUDED.rule_params,
      name = EXCLUDED.name,
      description = EXCLUDED.description,
      icon = EXCLUDED.icon,
      xp_reward = EXCLUDED.xp_reward,
      rarity = EXCLUDED.rarity,
      criteria = EXCLUDED.criteria;

    INSERT INTO public.achievements (id, school_id, name, description, icon, xp_reward, rarity, criteria, rule_type, rule_params)
    VALUES (
      '30000000-0000-0000-0000-000000000008',
      v_school_id,
      'Gold Medal',
      'Achieve the maximum combined average in your class',
      '🥇',
      1000,
      'epic',
      'Maximum combined average in class',
      'class_topper',
      '{}'::jsonb
    )
    ON CONFLICT (id) DO UPDATE SET
      rule_type = EXCLUDED.rule_type,
      rule_params = EXCLUDED.rule_params,
      name = EXCLUDED.name,
      description = EXCLUDED.description,
      icon = EXCLUDED.icon,
      xp_reward = EXCLUDED.xp_reward,
      rarity = EXCLUDED.rarity,
      criteria = EXCLUDED.criteria;
  END IF;
END $$;

-- RESET ROLE; -- commented out for cloud migrations (non-superuser)
