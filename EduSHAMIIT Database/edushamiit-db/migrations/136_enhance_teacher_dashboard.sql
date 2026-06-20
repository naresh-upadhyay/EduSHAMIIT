-- 136_enhance_teacher_dashboard.sql
-- Recreate get_teacher_dashboard_summary to calculate student avg attendance, student avg score, and list pending tasks.

SET ROLE supabase_admin;

CREATE OR REPLACE FUNCTION public.get_teacher_dashboard_summary(p_school_id UUID, p_teacher_id UUID, p_day_of_week INT)
RETURNS JSONB AS $$
DECLARE
    v_profile JSONB;
    v_schedule JSONB;
    v_total_students BIGINT;
    v_total_classes BIGINT;
    v_pending_tasks BIGINT;
    v_attendance_pct NUMERIC;
    v_avg_score NUMERIC;
    v_pending_tasks_list JSONB;
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

    -- Get pending tasks count (homework submissions count)
    SELECT COUNT(hs.id) INTO v_pending_tasks FROM homework_submissions hs
    JOIN homework h ON hs.homework_id = h.id
    WHERE h.school_id = p_school_id AND h.teacher_id = p_teacher_id AND h.status = 'active' AND hs.status = 'submitted';

    -- Get average attendance of students in teacher's classes
    SELECT COALESCE(ROUND(AVG(sps.attendance_pct)::NUMERIC, 1), 0.0) INTO v_attendance_pct
    FROM public.student_profile_stats sps
    WHERE sps.school_id = p_school_id AND sps.class IN (
        SELECT DISTINCT class FROM timetable WHERE school_id = p_school_id AND teacher_id = p_teacher_id
    );

    -- Get average score of students in teacher's classes
    SELECT COALESCE(ROUND(AVG(sps.avg_score)::NUMERIC, 1), 0.0) INTO v_avg_score
    FROM public.student_profile_stats sps
    WHERE sps.school_id = p_school_id AND sps.class IN (
        SELECT DISTINCT class FROM timetable WHERE school_id = p_school_id AND teacher_id = p_teacher_id
    );

    -- Get pending tasks list
    SELECT COALESCE(jsonb_agg(t), '[]'::jsonb) INTO v_pending_tasks_list FROM (
        SELECT 
            h.id::TEXT as id,
            h.title,
            h.class as class,
            COALESCE(sub.icon, '📝') as icon,
            h.due_date::TEXT as due_date,
            h.status,
            COUNT(hs.id)::INT as count
        FROM homework h
        LEFT JOIN subjects sub ON h.subject_id = sub.id
        JOIN homework_submissions hs ON hs.homework_id = h.id
        WHERE h.school_id = p_school_id 
          AND h.teacher_id = p_teacher_id 
          AND h.status = 'active' 
          AND hs.status = 'submitted'
        GROUP BY h.id, sub.icon
    ) t;

    RETURN jsonb_build_object(
        'teacher', v_profile,
        'today_schedule', COALESCE(v_schedule, '[]'::jsonb),
        'pending_tasks', v_pending_tasks_list,
        'stats', jsonb_build_object(
            'total_students', v_total_students,
            'total_classes', v_total_classes,
            'pending_tasks', v_pending_tasks,
            'attendance_pct', v_attendance_pct,
            'avg_score', v_avg_score
        )
    );
END; $$ LANGUAGE plpgsql;

RESET ROLE;
