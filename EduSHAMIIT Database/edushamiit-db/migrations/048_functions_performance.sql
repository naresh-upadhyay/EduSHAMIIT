CREATE OR REPLACE FUNCTION get_class_performance(p_school_id UUID, p_class TEXT)
RETURNS JSONB AS $$
DECLARE
  v_avg_score NUMERIC; v_avg_attendance NUMERIC; v_total_students INT;
  v_top_performers JSONB; v_at_risk JSONB;
BEGIN
  SELECT COUNT(*) INTO v_total_students FROM profiles WHERE school_id = p_school_id AND class = p_class AND role = 'student';
  SELECT COALESCE(AVG(r.marks_obtained / r.total_marks * 100), 0) INTO v_avg_score FROM results r JOIN profiles p ON r.student_id = p.id WHERE p.school_id = p_school_id AND p.class = p_class;
  SELECT COALESCE(AVG(CASE WHEN a.status = 'present' THEN 100 ELSE 0 END), 0) INTO v_avg_attendance FROM attendance a JOIN profiles p ON a.student_id = p.id WHERE p.school_id = p_school_id AND p.class = p_class;
  SELECT jsonb_agg(jsonb_build_object('name', sub.full_name, 'avg_score', sub.avg_score)) INTO v_top_performers FROM (SELECT p.full_name, AVG(r.marks_obtained / r.total_marks * 100) AS avg_score FROM profiles p JOIN results r ON p.id = r.student_id WHERE p.school_id = p_school_id AND p.class = p_class GROUP BY p.id, p.full_name ORDER BY avg_score DESC LIMIT 5) sub;
  SELECT jsonb_agg(jsonb_build_object('name', sub.full_name, 'avg_score', sub.avg_score, 'attendance', sub.att_pct)) INTO v_at_risk FROM (SELECT p.full_name, COALESCE(AVG(r.marks_obtained / r.total_marks * 100), 0) AS avg_score, COALESCE(AVG(CASE WHEN a.status = 'present' THEN 100 ELSE 0 END), 0) AS att_pct FROM profiles p LEFT JOIN results r ON p.id = r.student_id LEFT JOIN attendance a ON p.id = a.student_id WHERE p.school_id = p_school_id AND p.class = p_class GROUP BY p.id, p.full_name HAVING COALESCE(AVG(r.marks_obtained / r.total_marks * 100), 0) < 50 OR COALESCE(AVG(CASE WHEN a.status = 'present' THEN 100 ELSE 0 END), 0) < 75) sub;
  RETURN jsonb_build_object('school_id', p_school_id, 'class', p_class, 'total_students', v_total_students, 'avg_score', ROUND(v_avg_score, 1), 'avg_attendance', ROUND(v_avg_attendance, 1), 'top_performers', COALESCE(v_top_performers, '[]'::jsonb), 'at_risk_students', COALESCE(v_at_risk, '[]'::jsonb));
END;
$$ LANGUAGE plpgsql;
