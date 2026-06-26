-- ============================================================
-- Migration 115: Enhance Attendance Module
-- Correct calculations for void lectures, multiple marks/day (entire day + subject-wise),
-- and bulk/batch upserting attendance.
-- ============================================================

-- Elevate to supabase_admin to modify tables/views/functions
-- SET ROLE supabase_admin; -- commented out for cloud migrations (non-superuser)

-- 1. Drop old UNIQUE constraint
ALTER TABLE public.attendance DROP CONSTRAINT IF EXISTS attendance_school_student_subject_date_key;

-- 2. Create new UNIQUE index that treats NULL subject IDs as a single entry per day
CREATE UNIQUE INDEX IF NOT EXISTS UNIQUE_attendance_student_date_subject 
ON public.attendance (
  school_id, 
  student_id, 
  date, 
  COALESCE(subject_id, '00000000-0000-0000-0000-000000000000'::uuid)
);

-- 3. Recreate student_profile_stats view to correctly calculate attendance % excluding void lectures
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
  -- Attendance percentage (excluding void)
  COALESCE(
    ROUND(
      (
        SUM(CASE WHEN a.status IN ('present', 'late') THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(SUM(CASE WHEN a.status IN ('present', 'absent', 'late') THEN 1 ELSE 0 END), 0)
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

-- 4. Recreate get_attendance_stats RPC function to exclude void lectures from calculations
CREATE OR REPLACE FUNCTION public.get_attendance_stats(p_school_id UUID, p_class TEXT)
RETURNS TABLE (
  student_id UUID,
  full_name TEXT,
  total_days BIGINT,
  present_days BIGINT,
  absent_days BIGINT,
  late_days BIGINT,
  attendance_pct NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id AS student_id,
    p.full_name,
    COUNT(CASE WHEN a.status IN ('present', 'absent', 'late') THEN 1 END) AS total_days,
    COUNT(CASE WHEN a.status = 'present' THEN 1 END) AS present_days,
    COUNT(CASE WHEN a.status = 'absent' THEN 1 END) AS absent_days,
    COUNT(CASE WHEN a.status = 'late' THEN 1 END) AS late_days,
    CASE WHEN COUNT(CASE WHEN a.status IN ('present', 'absent', 'late') THEN 1 END) > 0 THEN
      ROUND(COUNT(CASE WHEN a.status IN ('present', 'late') THEN 1 END)::NUMERIC / COUNT(CASE WHEN a.status IN ('present', 'absent', 'late') THEN 1 END) * 100, 1)
    ELSE 0 END AS attendance_pct
  FROM profiles p
  LEFT JOIN attendance a ON p.id = a.student_id AND a.school_id = p_school_id
  WHERE p.school_id = p_school_id AND p.class = p_class AND p.role = 'student'
  GROUP BY p.id, p.full_name
  ORDER BY attendance_pct DESC;
END;
$$ LANGUAGE plpgsql;

-- 5. Create batch_upsert_attendance function
CREATE OR REPLACE FUNCTION public.batch_upsert_attendance(
  p_records JSONB
) RETURNS VOID AS $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT * FROM jsonb_to_recordset(p_records) AS x(
    school_id UUID,
    student_id UUID,
    subject_id UUID,
    teacher_id UUID,
    marked_by UUID,
    class TEXT,
    date DATE,
    status TEXT,
    remarks TEXT
  ) LOOP
    INSERT INTO public.attendance (
      school_id, student_id, subject_id, teacher_id, marked_by, class, date, status, remarks
    ) VALUES (
      r.school_id, r.student_id, r.subject_id, r.teacher_id, r.marked_by, r.class, r.date, r.status, r.remarks
    )
    ON CONFLICT (school_id, student_id, date, COALESCE(subject_id, '00000000-0000-0000-0000-000000000000'::uuid))
    DO UPDATE SET
      status = EXCLUDED.status,
      remarks = EXCLUDED.remarks,
      teacher_id = EXCLUDED.teacher_id,
      marked_by = EXCLUDED.marked_by,
      created_at = NOW();
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions on new view & function
GRANT SELECT ON public.student_profile_stats TO authenticated, anon, service_role, postgres;
GRANT EXECUTE ON FUNCTION public.batch_upsert_attendance(JSONB) TO authenticated, anon, service_role, postgres;

-- RESET ROLE; -- commented out for cloud migrations (non-superuser)
