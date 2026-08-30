-- Migration: 200_db_stored_procedures_for_fastapi.sql
-- Description: Push heavy multi-query FastAPI operations into optimized PostgreSQL stored procedures (RPC functions).

-- 1. Enhanced Teacher Dashboard Summary RPC Function
DROP FUNCTION IF EXISTS public.get_teacher_dashboard_summary(UUID, UUID, INT) CASCADE;
DROP FUNCTION IF EXISTS public.get_teacher_dashboard_summary(UUID, UUID) CASCADE;
CREATE OR REPLACE FUNCTION public.get_teacher_dashboard_summary(
    p_school_id UUID, 
    p_teacher_id UUID, 
    p_day_of_week INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_profile JSONB;
    v_schedule JSONB;
    v_total_students BIGINT := 0;
    v_total_classes BIGINT := 0;
    v_pending_tasks BIGINT := 0;
    v_day INT;
BEGIN
    v_day := COALESCE(p_day_of_week, EXTRACT(DOW FROM CURRENT_DATE)::INT);

    -- Teacher profile
    SELECT to_jsonb(p) INTO v_profile FROM public.profiles p WHERE id = p_teacher_id;
    
    -- Today's schedule
    SELECT jsonb_agg(s) INTO v_schedule FROM (
        SELECT t.*, row_to_json(sub) as subjects
        FROM public.timetable t
        LEFT JOIN public.subjects sub ON t.subject_id = sub.id
        WHERE t.school_id = p_school_id AND t.teacher_id = p_teacher_id AND t.day_of_week = v_day
        ORDER BY t.start_time
    ) s;

    -- Total classes
    SELECT COUNT(DISTINCT class) INTO v_total_classes 
    FROM public.timetable 
    WHERE school_id = p_school_id AND teacher_id = p_teacher_id;

    -- Total students
    SELECT COUNT(p.id) INTO v_total_students 
    FROM public.profiles p
    WHERE p.school_id = p_school_id AND LOWER(p.role) = 'student' AND p.class IN (
        SELECT DISTINCT class FROM public.timetable WHERE school_id = p_school_id AND teacher_id = p_teacher_id
    );

    -- Pending homework grading tasks
    SELECT COUNT(hs.id) INTO v_pending_tasks 
    FROM public.homework_submissions hs
    JOIN public.homework h ON hs.homework_id = h.id
    WHERE h.school_id = p_school_id AND h.teacher_id = p_teacher_id AND LOWER(h.status) = 'active' AND LOWER(hs.status) = 'submitted';

    RETURN jsonb_build_object(
        'teacher', v_profile,
        'today_schedule', COALESCE(v_schedule, '[]'::jsonb),
        'stats', jsonb_build_object(
            'total_students', v_total_students,
            'total_classes', v_total_classes,
            'pending_tasks', v_pending_tasks
        )
    );
END;
$$;


-- 2. Enhanced Student Dashboard Summary RPC Function
DROP FUNCTION IF EXISTS public.get_student_dashboard_summary(UUID, UUID, INT) CASCADE;
DROP FUNCTION IF EXISTS public.get_student_dashboard_summary(UUID, UUID) CASCADE;
CREATE OR REPLACE FUNCTION public.get_student_dashboard_summary(
    p_school_id UUID, 
    p_student_id UUID, 
    p_day_of_week INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_profile JSONB;
    v_schedule JSONB;
    v_homework JSONB;
    v_att_total BIGINT := 0;
    v_att_present BIGINT := 0;
    v_att_pct NUMERIC := 0.0;
    v_unread_notifs INT := 0;
    v_day INT;
BEGIN
    v_day := COALESCE(p_day_of_week, EXTRACT(DOW FROM CURRENT_DATE)::INT);

    -- Student profile
    SELECT to_jsonb(p) INTO v_profile FROM public.profiles p WHERE id = p_student_id;
    
    -- Today's schedule
    SELECT jsonb_agg(s) INTO v_schedule FROM (
        SELECT t.*, row_to_json(sub) as subjects
        FROM public.timetable t
        LEFT JOIN public.subjects sub ON t.subject_id = sub.id
        WHERE t.school_id = p_school_id AND t.class = (v_profile->>'class') AND t.day_of_week = v_day
        ORDER BY t.start_time
    ) s;

    -- Pending homework
    SELECT jsonb_agg(h) INTO v_homework FROM (
        SELECT hw.*, row_to_json(sub) as subjects
        FROM public.homework hw
        LEFT JOIN public.subjects sub ON hw.subject_id = sub.id
        WHERE hw.school_id = p_school_id AND hw.class = (v_profile->>'class') AND LOWER(hw.status) = 'active'
        AND hw.due_date <= (CURRENT_DATE + INTERVAL '3 days')
        ORDER BY hw.due_date
    ) h;

    -- Attendance Stats
    SELECT COUNT(*) INTO v_att_total 
    FROM public.attendance 
    WHERE school_id = p_school_id AND student_id = p_student_id AND LOWER(status) IN ('present', 'absent', 'late');

    SELECT COUNT(*) INTO v_att_present 
    FROM public.attendance 
    WHERE school_id = p_school_id AND student_id = p_student_id AND LOWER(status) IN ('present', 'late');

    IF v_att_total > 0 THEN
        v_att_pct := ROUND((v_att_present::NUMERIC / v_att_total::NUMERIC) * 100.0, 2);
    ELSE
        v_att_pct := 100.0;
    END IF;

    -- Unread Notifications Count
    SELECT COUNT(*) INTO v_unread_notifs
    FROM public.notifications
    WHERE user_id = p_student_id AND (is_read = FALSE OR is_read IS NULL);

    RETURN jsonb_build_object(
        'profile', v_profile,
        'today_schedule', COALESCE(v_schedule, '[]'::jsonb),
        'pending_homework', COALESCE(v_homework, '[]'::jsonb),
        'attendance_percentage', v_att_pct,
        'unread_notifications_count', v_unread_notifs
    );
END;
$$;


-- 3. Vehicle Live Dashboard Summary RPC Function (Aggregated Superfast KPIs)
DROP FUNCTION IF EXISTS public.get_vehicle_dashboard_summary(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.get_vehicle_dashboard_summary() CASCADE;
CREATE OR REPLACE FUNCTION public.get_vehicle_dashboard_summary(p_school_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_total_vehicles INT := 0;
  v_on_route INT := 0;
  v_at_school INT := 0;
  v_returning INT := 0;
  v_delayed INT := 0;
  v_offline INT := 0;
  v_idle INT := 0;
  v_students_on_board INT := 0;
  v_active_trips INT := 0;
  v_completed_trips INT := 0;
  v_critical_alerts INT := 0;
  v_warning_alerts INT := 0;
  v_result JSONB;
BEGIN
  -- Vehicles Stats
  SELECT 
    COUNT(*),
    COALESCE(SUM(CASE WHEN LOWER(status) = 'active' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN LOWER(status) = 'maintenance' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN LOWER(status) = 'inactive' THEN 1 ELSE 0 END), 0)
  INTO v_total_vehicles, v_on_route, v_offline, v_idle
  FROM public.vehicles
  WHERE (p_school_id IS NULL OR school_id = p_school_id);

  -- Active Trips Stats
  SELECT 
    COALESCE(SUM(CASE WHEN LOWER(status) = 'in_progress' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN LOWER(status) = 'completed' THEN 1 ELSE 0 END), 0)
  INTO v_active_trips, v_completed_trips
  FROM public.vehicle_trips
  WHERE (p_school_id IS NULL OR school_id = p_school_id);

  -- Live Alerts Stats
  SELECT 
    COALESCE(SUM(CASE WHEN LOWER(severity) = 'critical' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN LOWER(severity) = 'warning' THEN 1 ELSE 0 END), 0)
  INTO v_critical_alerts, v_warning_alerts
  FROM public.vehicle_live_alerts
  WHERE (is_resolved = FALSE OR is_resolved IS NULL) AND (p_school_id IS NULL OR school_id = p_school_id);

  v_result := jsonb_build_object(
    'total_vehicles', v_total_vehicles,
    'on_route', v_on_route,
    'at_school', v_at_school,
    'returning', v_returning,
    'delayed', v_delayed,
    'offline', v_offline,
    'idle', v_idle,
    'students_on_board', v_students_on_board,
    'active_trips', v_active_trips,
    'completed_trips_today', v_completed_trips,
    'critical_alerts', v_critical_alerts,
    'warning_alerts', v_warning_alerts
  );

  RETURN v_result;
END;
$$;


-- 4. Fast Unread Notification Counter RPC Function
DROP FUNCTION IF EXISTS public.rpc_get_unread_notifications_count(UUID) CASCADE;
CREATE OR REPLACE FUNCTION public.rpc_get_unread_notifications_count(p_user_id UUID)
RETURNS INT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COUNT(*)::INT
  FROM public.notifications
  WHERE user_id = p_user_id AND (is_read = FALSE OR is_read IS NULL);
$$;


-- 5. Bulk Attendance Processor RPC Function
DROP FUNCTION IF EXISTS public.rpc_process_bulk_attendance(UUID, JSONB) CASCADE;
CREATE OR REPLACE FUNCTION public.rpc_process_bulk_attendance(p_school_id UUID, p_records JSONB)
RETURNS INT
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
  v_rec JSONB;
  v_count INT := 0;
BEGIN
  FOR v_rec IN SELECT * FROM jsonb_array_elements(p_records)
  LOOP
    INSERT INTO public.attendance (
      school_id,
      student_id,
      date,
      status,
      remarks,
      created_at,
      updated_at
    )
    VALUES (
      p_school_id,
      (v_rec->>'student_id')::UUID,
      COALESCE((v_rec->>'date')::DATE, CURRENT_DATE),
      COALESCE(v_rec->>'status', 'Present'),
      v_rec->>'remarks',
      NOW(),
      NOW()
    )
    ON CONFLICT (student_id, date) DO UPDATE
    SET status = EXCLUDED.status,
        remarks = EXCLUDED.remarks,
        updated_at = NOW();
        
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;
