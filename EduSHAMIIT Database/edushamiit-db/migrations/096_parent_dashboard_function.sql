-- ============================================================
-- Migration 096: Parent Dashboard Function
-- Aggregates student data for the parent dashboard view
-- ============================================================

CREATE OR REPLACE FUNCTION get_parent_dashboard_summary(
  p_school_id UUID,
  p_parent_id UUID,
  p_student_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_student JSONB;
  v_attendance_summary JSONB;
  v_recent_results JSONB;
  v_pending_fees JSONB;
  v_upcoming JSONB;
  v_attendance_pct NUMERIC;
  v_total_days BIGINT;
  v_present_days BIGINT;
BEGIN
  -- Verify parent-child relationship
  IF NOT EXISTS (
    SELECT 1 FROM parent_student_relations
    WHERE parent_id = p_parent_id
      AND student_id = p_student_id
      AND approved = TRUE
  ) THEN
    RAISE EXCEPTION 'Not authorized for this student';
  END IF;

  -- Student basic info
  SELECT jsonb_build_object(
    'id', p.id,
    'full_name', p.full_name,
    'class', p.class,
    'avatar_url', p.avatar_url,
    'roll_number', p.roll_number
  ) INTO v_student
  FROM profiles p WHERE p.id = p_student_id;

  -- Attendance summary (last 30 days)
  SELECT
    COUNT(*) AS total_days,
    COUNT(CASE WHEN status = 'present' THEN 1 END) AS present_days
  INTO v_total_days, v_present_days
  FROM attendance
  WHERE student_id = p_student_id
    AND school_id = p_school_id
    AND date >= CURRENT_DATE - INTERVAL '30 days';

  v_attendance_pct := CASE WHEN v_total_days > 0
    THEN ROUND(v_present_days::NUMERIC / v_total_days * 100, 1)
    ELSE 0 END;

  v_attendance_summary := jsonb_build_object(
    'total_days', v_total_days,
    'present_days', v_present_days,
    'attendance_pct', v_attendance_pct
  );

  -- Recent results (last 10)
  SELECT jsonb_agg(row_to_json(r.*)) INTO v_recent_results
  FROM (
    SELECT r.id, r.exam_type, r.marks_obtained, r.total_marks, r.grade,
           r.remarks, r.created_at, s.name AS subject_name, s.icon AS subject_icon
    FROM results r
    LEFT JOIN subjects s ON r.subject_id = s.id
    WHERE r.student_id = p_student_id AND r.school_id = p_school_id
    ORDER BY r.created_at DESC
    LIMIT 10
  ) r;

  -- Pending fees
  SELECT jsonb_agg(row_to_json(f.*)) INTO v_pending_fees
  FROM (
    SELECT id, fee_type, amount, due_date, fee_period, status
    FROM fees
    WHERE student_id = p_student_id AND school_id = p_school_id AND status = 'pending'
    ORDER BY due_date ASC
  ) f;

  -- Upcoming events and exams
  SELECT jsonb_build(
    'exams', COALESCE(
      (SELECT jsonb_agg(row_to_json(e.*))
       FROM (
         SELECT ex.id, ex.title, ex.start_time, s.name AS subject_name
         FROM exams ex
         LEFT JOIN subjects s ON ex.subject_id = s.id
         WHERE ex.school_id = p_school_id AND ex.start_time >= NOW()
         ORDER BY ex.start_time LIMIT 5
       ) e), '[]'::jsonb),
    'events', COALESCE(
      (SELECT jsonb_agg(row_to_json(ev.*))
       FROM (
         SELECT id, title, start_date, end_date, venue
         FROM events
         WHERE school_id = p_school_id AND start_date >= CURRENT_DATE
         ORDER BY start_date LIMIT 5
       ) ev), '[]'::jsonb)
  ) INTO v_upcoming;

  RETURN jsonb_build(
    'student', v_student,
    'attendance_summary', v_attendance_summary,
    'recent_results', COALESCE(v_recent_results, '[]'::jsonb),
    'pending_fees', COALESCE(v_pending_fees, '[]'::jsonb),
    'upcoming', v_upcoming
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
