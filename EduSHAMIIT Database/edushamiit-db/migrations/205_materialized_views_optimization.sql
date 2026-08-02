-- Migration: 205_materialized_views_optimization.sql
-- Description: Convert heavy multi-table dynamic aggregate views into high-performance Materialized Views with concurrent refresh support.

-- 1. Materialized View: Teacher Dashboard Aggregates
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_teacher_dashboard_summary AS
SELECT 
  t.school_id,
  t.teacher_id,
  COUNT(DISTINCT t.class) AS total_classes,
  COUNT(DISTINCT p.id) AS total_students,
  COALESCE(COUNT(DISTINCT hs.id), 0) AS pending_grading_tasks,
  NOW() AS last_refreshed_at
FROM public.timetable t
LEFT JOIN public.profiles p ON p.school_id = t.school_id AND p.class = t.class AND LOWER(p.role) = 'student'
LEFT JOIN public.homework h ON h.school_id = t.school_id AND h.teacher_id = t.teacher_id AND LOWER(h.status) = 'active'
LEFT JOIN public.homework_submissions hs ON hs.homework_id = h.id AND LOWER(hs.status) = 'submitted'
GROUP BY t.school_id, t.teacher_id;

-- Unique index required for REFRESH MATERIALIZED VIEW CONCURRENTLY
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_teacher_dash_pk ON public.mv_teacher_dashboard_summary(school_id, teacher_id);


-- 2. Materialized View: Student Performance Summaries
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_student_performance_summary AS
SELECT 
  p.id AS student_id,
  p.school_id,
  p.class,
  COALESCE(ROUND(AVG((r.marks_obtained::NUMERIC / NULLIF(r.total_marks, 0)) * 100.0), 2), 0.0) AS average_score_pct,
  COALESCE(COUNT(r.id), 0) AS total_exams_taken,
  COALESCE(ROUND(AVG(CASE WHEN LOWER(a.status) IN ('present', 'late') THEN 100.0 ELSE 0.0 END), 2), 0.0) AS attendance_pct,
  NOW() AS last_refreshed_at
FROM public.profiles p
LEFT JOIN public.results r ON r.student_id = p.id
LEFT JOIN public.attendance a ON a.student_id = p.id
WHERE LOWER(p.role) = 'student'
GROUP BY p.id, p.school_id, p.class;

-- Unique index required for REFRESH MATERIALIZED VIEW CONCURRENTLY
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_student_perf_pk ON public.mv_student_performance_summary(student_id);


-- 3. Stored Procedure to Concurrent Refresh All Materialized Views
CREATE OR REPLACE FUNCTION public.refresh_all_materialized_views()
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_teacher_dashboard_summary;
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_student_performance_summary;

  RETURN jsonb_build_object(
    'success', true,
    'refreshed_views', jsonb_build_array('mv_teacher_dashboard_summary', 'mv_student_performance_summary'),
    'refreshed_at', NOW()
  );
EXCEPTION WHEN OTHERS THEN
  -- Fallback to standard refresh if concurrent refresh fails on un-indexed rows
  REFRESH MATERIALIZED VIEW public.mv_teacher_dashboard_summary;
  REFRESH MATERIALIZED VIEW public.mv_student_performance_summary;

  RETURN jsonb_build_object(
    'success', true,
    'mode', 'standard_fallback',
    'refreshed_at', NOW()
  );
END;
$$;
