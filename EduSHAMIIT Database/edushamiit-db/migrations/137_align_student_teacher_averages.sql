-- 137_align_student_teacher_averages.sql
-- Update student_profile_stats view to correctly calculate consolidated average using a dynamic weighted score (60% Exam, 40% HW).

-- SET ROLE supabase_admin; -- commented out for cloud migrations (non-superuser)

CREATE OR REPLACE VIEW public.student_profile_stats AS
WITH exam_stats AS (
  SELECT 
    p.id as student_id,
    COALESCE(
      (
        SELECT SUM(es.score)
        FROM public.exam_submissions es
        JOIN public.exams e ON es.exam_id = e.id
        WHERE es.student_id = p.id AND e.results_published_at IS NOT NULL AND e.school_id = p.school_id
      ), 0
    ) + COALESCE(
      (
        SELECT SUM(r.marks_obtained)
        FROM public.results r
        WHERE r.student_id = p.id AND r.school_id = p.school_id
      ), 0
    ) AS exam_obtained,
    COALESCE(
      (
        SELECT SUM(e.total_marks)
        FROM public.exam_submissions es
        JOIN public.exams e ON es.exam_id = e.id
        WHERE es.student_id = p.id AND e.results_published_at IS NOT NULL AND e.school_id = p.school_id
      ), 0
    ) + COALESCE(
      (
        SELECT SUM(r.total_marks)
        FROM public.results r
        WHERE r.student_id = p.id AND r.school_id = p.school_id
      ), 0
    ) AS exam_max
  FROM public.profiles p
  WHERE p.role = 'student'
),
hw_stats AS (
  SELECT 
    p.id as student_id,
    COALESCE(
      (
        SELECT SUM(hs.marks)
        FROM public.homework_submissions hs
        JOIN public.homework h ON hs.homework_id = h.id
        WHERE hs.student_id = p.id 
          AND h.school_id = p.school_id 
          AND h.class = p.class 
          AND h.status = 'active'
          AND hs.status = 'graded'
          AND hs.marks IS NOT NULL
      ), 0
    ) AS hw_obtained,
    COALESCE(
      (
        SELECT SUM(h.max_marks)
        FROM public.homework_submissions hs
        JOIN public.homework h ON hs.homework_id = h.id
        WHERE hs.student_id = p.id 
          AND h.school_id = p.school_id 
          AND h.class = p.class 
          AND h.status = 'active'
          AND hs.status = 'graded'
          AND hs.marks IS NOT NULL
      ), 0
    ) AS hw_max
  FROM public.profiles p
  WHERE p.role = 'student'
),
weighted_score AS (
  SELECT 
    e.student_id,
    CASE 
      WHEN e.exam_max > 0 AND h.hw_max > 0 THEN
        ROUND((((e.exam_obtained::NUMERIC / e.exam_max::NUMERIC) * 100 * 0.6) + ((h.hw_obtained::NUMERIC / h.hw_max::NUMERIC) * 100 * 0.4))::NUMERIC, 1)
      WHEN e.exam_max > 0 THEN
        ROUND(((e.exam_obtained::NUMERIC / e.exam_max::NUMERIC) * 100)::NUMERIC, 1)
      WHEN h.hw_max > 0 THEN
        ROUND(((h.hw_obtained::NUMERIC / h.hw_max::NUMERIC) * 100)::NUMERIC, 1)
      ELSE 0.0
    END as avg_score
  FROM exam_stats e
  JOIN hw_stats h ON e.student_id = h.student_id
)
SELECT
  p.id                                                      AS student_id,
  p.school_id,
  p.full_name,
  p.class,
  p.session,
  p.avatar_url,
  -- Average score from results (computed dynamically with 60% Exam, 40% HW weight)
  COALESCE(ws.avg_score, 0.0)                               AS avg_score,
  -- Attendance percentage (excluding void)
  COALESCE(
    ROUND(
      (
        (SELECT COUNT(*) FROM public.attendance a WHERE a.student_id = p.id AND a.school_id = p.school_id AND a.status IN ('present', 'late'))::NUMERIC
        / NULLIF((SELECT COUNT(*) FROM public.attendance a WHERE a.student_id = p.id AND a.school_id = p.school_id AND a.status IN ('present', 'absent', 'late')), 0)
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
LEFT JOIN weighted_score ws ON ws.student_id = p.id
WHERE p.role = 'student';

GRANT SELECT ON public.student_profile_stats TO authenticated, anon, service_role, postgres;

-- RESET ROLE; -- commented out for cloud migrations (non-superuser)
