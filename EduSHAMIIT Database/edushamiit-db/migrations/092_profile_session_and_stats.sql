-- ============================================================
-- Migration 092: Profile Session Column + Student Stats View
-- Required by student profile screen to show session,
-- avg score, attendance %, class rank, and badges count.
-- ============================================================

-- Elevate to supabase_admin to modify tables it owns
SET ROLE supabase_admin;

-- ─── 1. Add session column to profiles (if not exists) ───
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS session TEXT;

-- ─── 2. Add avatar_url column if somehow missing ───
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Reset role before creating view (view will be owned by supabase_admin via SET ROLE)
-- ─── 3. Create student_profile_stats view ───
CREATE OR REPLACE VIEW public.student_profile_stats AS
SELECT
  p.id                                                      AS student_id,
  p.school_id,
  p.full_name,
  p.class,
  p.session,
  p.avatar_url,
  -- Average score from results
  COALESCE(
    ROUND(
      AVG(
        CASE WHEN r.total_marks > 0
          THEN (r.marks_obtained::NUMERIC / r.total_marks::NUMERIC) * 100
          ELSE NULL
        END
      )::NUMERIC, 1
    ), 0
  )                                                         AS avg_score,
  -- Attendance percentage
  COALESCE(
    ROUND(
      (
        SUM(CASE WHEN a.status = 'present' THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(a.id), 0)
      ) * 100, 1
    ), 0
  )                                                         AS attendance_pct,
  -- Total badges earned
  COALESCE(
    (SELECT COUNT(*)::BIGINT FROM public.student_achievements sa
     WHERE sa.student_id = p.id AND sa.school_id = p.school_id), 0
  )                                                         AS badges_count,
  -- Class rank by xp_points (lower number = better)
  COALESCE(
    (
      SELECT COUNT(*) + 1
      FROM public.profiles p2
      WHERE p2.school_id = p.school_id
        AND p2.class = p.class
        AND p2.role = 'student'
        AND p2.xp_points > p.xp_points
    ), 1
  )                                                         AS class_rank
FROM public.profiles p
LEFT JOIN public.results r ON r.student_id = p.id AND r.school_id = p.school_id
LEFT JOIN public.attendance a ON a.student_id = p.id AND a.school_id = p.school_id
WHERE p.role = 'student'
GROUP BY p.id, p.school_id, p.full_name, p.class, p.session, p.avatar_url;

-- ─── 4. Grant access ───
GRANT SELECT ON public.student_profile_stats TO authenticated;
GRANT SELECT ON public.student_profile_stats TO anon;
GRANT SELECT ON public.student_profile_stats TO service_role;
GRANT SELECT ON public.student_profile_stats TO postgres;

RESET ROLE;
