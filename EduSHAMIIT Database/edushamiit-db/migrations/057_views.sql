CREATE OR REPLACE VIEW dashboard_stats AS
SELECT
  p.school_id,
  COUNT(*) AS total_students,
  AVG(CASE WHEN a.status = 'present' THEN 100 ELSE 0 END) AS avg_attendance,
  AVG(r.marks_obtained / r.total_marks * 100) AS avg_score
FROM profiles p
LEFT JOIN attendance a ON p.id = a.student_id
LEFT JOIN results r ON p.id = r.student_id
WHERE p.role = 'student'
GROUP BY p.school_id;

CREATE OR REPLACE VIEW student_summary AS
SELECT
  p.id,
  p.school_id,
  p.full_name,
  p.class,
  p.roll_number,
  p.xp_points,
  p.learning_streak,
  COUNT(DISTINCT a.id) AS total_attendance_records,
  COUNT(DISTINCT CASE WHEN a.status = 'present' THEN a.id END) AS present_days,
  COALESCE(AVG(r.marks_obtained / r.total_marks * 100), 0) AS avg_score
FROM profiles p
LEFT JOIN attendance a ON p.id = a.student_id
LEFT JOIN results r ON p.id = r.student_id
WHERE p.role = 'student'
GROUP BY p.id, p.school_id, p.full_name, p.class, p.roll_number, p.xp_points, p.learning_streak;

CREATE OR REPLACE VIEW teacher_summary AS
SELECT
  p.id,
  p.school_id,
  p.full_name,
  p.department,
  p.designation,
  p.employee_id,
  p.rating,
  COUNT(DISTINCT s.id) AS subjects_taught,
  COUNT(DISTINCT h.id) AS homework_assigned
FROM profiles p
LEFT JOIN subjects s ON p.id = s.teacher_id
LEFT JOIN homework h ON p.id = h.teacher_id
WHERE p.role = 'teacher'
GROUP BY p.id, p.school_id, p.full_name, p.department, p.designation, p.employee_id, p.rating;