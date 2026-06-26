-- 091_optimize_endpoints.sql
-- Optimizing teacher and student endpoints by consolidating queries into RPC functions

-- SET ROLE supabase_admin; -- commented out for cloud migrations (non-superuser)

-- 1. Teacher Classes with Student Counts (Fixes N+1 problem)
CREATE OR REPLACE FUNCTION get_teacher_classes_with_counts(p_school_id UUID, p_teacher_id UUID)
RETURNS TABLE (class TEXT, student_count BIGINT) AS $$
BEGIN
    RETURN QUERY
    WITH teacher_classes AS (
        SELECT DISTINCT t.class FROM timetable t
        WHERE t.school_id = p_school_id AND t.teacher_id = p_teacher_id
    )
    SELECT tc.class, COUNT(p.id)
    FROM teacher_classes tc
    LEFT JOIN profiles p ON p.class = tc.class AND p.school_id = p_school_id AND p.role = 'student'
    GROUP BY tc.class;
END; $$ LANGUAGE plpgsql;

-- 2. Teacher Dashboard Summary (Consolidates 6+ queries)
CREATE OR REPLACE FUNCTION get_teacher_dashboard_summary(p_school_id UUID, p_teacher_id UUID, p_day_of_week INT)
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_schedule JSONB;
    v_total_students BIGINT;
    v_total_classes BIGINT;
    v_pending_tasks BIGINT;
BEGIN
    -- Get profile
    SELECT to_jsonb(p) INTO v_profile FROM profiles p WHERE id = p_teacher_id;
    
    -- Get schedule
    SELECT jsonb_agg(s) INTO v_schedule FROM (
        SELECT t.*, row_to_json(sub) as subjects
        FROM timetable t
        LEFT JOIN subjects sub ON t.subject_id = sub.id
        WHERE t.school_id = p_school_id AND t.teacher_id = p_teacher_id AND t.day_of_week = p_day_of_week
        ORDER BY t.start_time
    ) s;

    -- Get total classes
    SELECT COUNT(DISTINCT class) INTO v_total_classes FROM timetable 
    WHERE school_id = p_school_id AND teacher_id = p_teacher_id;

    -- Get total students
    SELECT COUNT(p.id) INTO v_total_students FROM profiles p
    WHERE p.school_id = p_school_id AND p.role = 'student' AND p.class IN (
        SELECT DISTINCT class FROM timetable WHERE school_id = p_school_id AND teacher_id = p_teacher_id
    );

    -- Get pending tasks (homework submissions)
    SELECT COUNT(hs.id) INTO v_pending_tasks FROM homework_submissions hs
    JOIN homework h ON hs.homework_id = h.id
    WHERE h.school_id = p_school_id AND h.teacher_id = p_teacher_id AND h.status = 'active' AND hs.status = 'submitted';

    RETURN jsonb_build_object(
        'teacher', v_profile,
        'today_schedule', COALESCE(v_schedule, '[]'::jsonb),
        'stats', jsonb_build_object(
            'total_students', v_total_students,
            'total_classes', v_total_classes,
            'pending_tasks', v_pending_tasks
        )
    );
END; $$ LANGUAGE plpgsql;

-- 3. Student Dashboard Summary (Consolidates 7+ queries)
CREATE OR REPLACE FUNCTION get_student_dashboard_summary(p_school_id UUID, p_student_id UUID, p_day_of_week INT)
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_schedule JSONB;
    v_homework JSONB;
    v_att_total BIGINT;
    v_att_present BIGINT;
    v_latest_result JSONB;
    v_class_rank INT;
    
    v_exam_obtained FLOAT := 0;
    v_exam_max FLOAT := 0;
    v_sub_obtained FLOAT := 0;
    v_sub_max FLOAT := 0;
    v_legacy_obtained FLOAT := 0;
    v_legacy_max FLOAT := 0;
    v_hw_obtained FLOAT := 0;
    v_hw_max FLOAT := 0;
    v_exam_avg FLOAT := 0;
    v_hw_avg FLOAT := 0;
    v_combined_avg NUMERIC := 0;
BEGIN
    -- Get profile
    SELECT to_jsonb(p) INTO v_profile FROM profiles p WHERE id = p_student_id;
    
    -- Get schedule
    SELECT jsonb_agg(s) INTO v_schedule FROM (
        SELECT t.*, row_to_json(sub) as subjects
        FROM timetable t
        LEFT JOIN subjects sub ON t.subject_id = sub.id
        WHERE t.school_id = p_school_id AND t.class = (v_profile->>'class') AND t.day_of_week = p_day_of_week
        ORDER BY t.start_time
    ) s;

    -- Get pending homework
    SELECT jsonb_agg(h) INTO v_homework FROM (
        SELECT hw.*, row_to_json(sub) as subjects
        FROM homework hw
        LEFT JOIN subjects sub ON hw.subject_id = sub.id
        WHERE hw.school_id = p_school_id AND hw.class = (v_profile->>'class') AND hw.status = 'active'
        AND hw.due_date <= (CURRENT_DATE + INTERVAL '3 days')
        ORDER BY hw.due_date
    ) h;

    -- Attendance
    SELECT COUNT(*) INTO v_att_total FROM attendance WHERE school_id = p_school_id AND student_id = p_student_id AND status IN ('present', 'absent', 'late');
    SELECT COUNT(*) INTO v_att_present FROM attendance WHERE school_id = p_school_id AND student_id = p_student_id AND status IN ('present', 'late');

    -- Calculate Exam obtained and max marks (published exam submissions)
    SELECT COALESCE(SUM(es.score), 0), COALESCE(SUM(e.total_marks), 0)
    INTO v_sub_obtained, v_sub_max
    FROM exam_submissions es
    JOIN exams e ON es.exam_id = e.id
    WHERE es.student_id = p_student_id AND e.results_published_at IS NOT NULL AND e.school_id = p_school_id;

    -- Calculate Exam obtained and max marks (legacy results)
    SELECT COALESCE(SUM(r.marks_obtained), 0), COALESCE(SUM(r.total_marks), 0)
    INTO v_legacy_obtained, v_legacy_max
    FROM results r
    WHERE r.student_id = p_student_id AND r.school_id = p_school_id;

    v_exam_obtained := v_sub_obtained + v_legacy_obtained;
    v_exam_max := v_sub_max + v_legacy_max;

    -- Calculate Homework obtained and max marks (graded active homeworks for the student's class)
    SELECT COALESCE(SUM(hs.marks), 0), COALESCE(SUM(h.max_marks), 0)
    INTO v_hw_obtained, v_hw_max
    FROM homework_submissions hs
    JOIN homework h ON hs.homework_id = h.id
    WHERE hs.student_id = p_student_id 
      AND h.school_id = p_school_id 
      AND h.class = (v_profile->>'class') 
      AND h.status = 'active'
      AND hs.status = 'graded'
      AND hs.marks IS NOT NULL;

    -- Calculate weighted combined average (60% Exam, 40% HW)
    IF v_exam_max > 0 AND v_hw_max > 0 THEN
        v_exam_avg := (v_exam_obtained / v_exam_max) * 100;
        v_hw_avg := (v_hw_obtained / v_hw_max) * 100;
        v_combined_avg := ROUND(((v_exam_avg * 0.6) + (v_hw_avg * 0.4))::NUMERIC, 1);
    ELSIF v_exam_max > 0 THEN
        v_combined_avg := ROUND(((v_exam_obtained / v_exam_max) * 100)::NUMERIC, 1);
    ELSIF v_hw_max > 0 THEN
        v_combined_avg := ROUND(((v_hw_obtained / v_hw_max) * 100)::NUMERIC, 1);
    ELSE
        v_combined_avg := 0;
    END IF;

    -- Class Rank
    SELECT COUNT(*) + 1 INTO v_class_rank FROM profiles 
    WHERE school_id = p_school_id AND class = (v_profile->>'class') AND role = 'student' 
    AND xp_points > COALESCE((v_profile->>'xp_points')::INT, 0);

    RETURN jsonb_build_object(
        'user', jsonb_build_object(
            'full_name', v_profile->>'full_name',
            'class', v_profile->>'class',
            'xp_points', COALESCE((v_profile->>'xp_points')::INT, 0),
            'learning_streak', COALESCE((v_profile->>'learning_streak')::INT, 0),
            'avatar_url', v_profile->>'avatar_url'
        ),
        'stats', jsonb_build_object(
            'attendance_pct', CASE WHEN v_att_total > 0 THEN ROUND((v_att_present::FLOAT / v_att_total * 100)::NUMERIC, 1) ELSE 0 END,
            'avg_score', v_combined_avg,
            'class_rank', v_class_rank,
            'xp_points', COALESCE((v_profile->>'xp_points')::INT, 0)
        ),
        'today_schedule', COALESCE(v_schedule, '[]'::jsonb),
        'pending_homework', COALESCE(v_homework, '[]'::jsonb)
    );
END; $$ LANGUAGE plpgsql;

-- RESET ROLE; -- commented out for cloud migrations (non-superuser)
