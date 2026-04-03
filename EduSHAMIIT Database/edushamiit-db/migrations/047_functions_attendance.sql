-- Function: Get attendance statistics for a class
CREATE OR REPLACE FUNCTION get_attendance_stats(p_school_id UUID, p_class TEXT)
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
    COUNT(a.id) AS total_days,
    COUNT(CASE WHEN a.status = 'present' THEN 1 END) AS present_days,
    COUNT(CASE WHEN a.status = 'absent' THEN 1 END) AS absent_days,
    COUNT(CASE WHEN a.status = 'late' THEN 1 END) AS late_days,
    CASE WHEN COUNT(a.id) > 0 THEN
      ROUND(COUNT(CASE WHEN a.status = 'present' THEN 1 END)::NUMERIC / COUNT(a.id) * 100, 1)
    ELSE 0 END AS attendance_pct
  FROM profiles p
  LEFT JOIN attendance a ON p.id = a.student_id AND a.school_id = p_school_id
  WHERE p.school_id = p_school_id AND p.class = p_class AND p.role = 'student'
  GROUP BY p.id, p.full_name
  ORDER BY attendance_pct DESC;
END;
$$ LANGUAGE plpgsql;
