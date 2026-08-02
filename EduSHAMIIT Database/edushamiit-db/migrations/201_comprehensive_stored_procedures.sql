-- Migration: 201_comprehensive_stored_procedures.sql
-- Description: Comprehensive suite of PostgreSQL RPC stored procedures to push complex FastAPI business logic down into the database.

-- ──────────────────────────────────────────────
-- 1. STUDENT MODULE STORED PROCEDURES
-- ──────────────────────────────────────────────

-- 1.1 Student Profile & Stats RPC
CREATE OR REPLACE FUNCTION public.rpc_get_student_profile_and_stats(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_profile JSONB;
  v_school_id UUID;
  v_att_total BIGINT := 0;
  v_att_present BIGINT := 0;
  v_att_pct NUMERIC := 0.0;
  v_gpa NUMERIC := 0.0;
  v_pending_hw INT := 0;
  v_result JSONB;
BEGIN
  SELECT to_jsonb(p) INTO v_profile FROM public.profiles p WHERE id = p_student_id;
  IF v_profile IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Student not found');
  END IF;

  v_school_id := (v_profile->>'school_id')::UUID;

  -- Attendance Percentage
  SELECT COUNT(*), COALESCE(SUM(CASE WHEN LOWER(status) IN ('present', 'late') THEN 1 ELSE 0 END), 0)
  INTO v_att_total, v_att_present
  FROM public.attendance
  WHERE student_id = p_student_id;

  IF v_att_total > 0 THEN
    v_att_pct := ROUND((v_att_present::NUMERIC / v_att_total::NUMERIC) * 100.0, 2);
  ELSE
    v_att_pct := 100.0;
  END IF;

  -- Result GPA / Average Score
  SELECT COALESCE(ROUND(AVG((marks_obtained::NUMERIC / NULLIF(total_marks, 0)) * 100.0), 2), 0.0)
  INTO v_gpa
  FROM public.results
  WHERE student_id = p_student_id;

  -- Pending Homework
  SELECT COUNT(DISTINCT h.id) INTO v_pending_hw
  FROM public.homework h
  LEFT JOIN public.homework_submissions hs ON h.id = hs.homework_id AND hs.student_id = p_student_id
  WHERE (h.school_id = v_school_id OR h.school_id IS NULL) 
    AND h.class = (v_profile->>'class')
    AND hs.id IS NULL;

  v_result := jsonb_build_object(
    'success', true,
    'profile', v_profile,
    'attendance_percentage', v_att_pct,
    'average_score_pct', v_gpa,
    'pending_homework_count', v_pending_hw
  );

  RETURN v_result;
END;
$$;


-- 1.2 Student Exam Results RPC
CREATE OR REPLACE FUNCTION public.rpc_get_student_exam_results(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_results JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', r.id,
      'exam_id', r.exam_id,
      'subject_id', r.subject_id,
      'subject_name', COALESCE(s.name, 'Subject'),
      'marks_obtained', r.marks_obtained,
      'total_marks', r.total_marks,
      'percentage', ROUND((r.marks_obtained::NUMERIC / NULLIF(r.total_marks, 0)) * 100.0, 2),
      'grade', r.grade,
      'remarks', r.remarks,
      'created_at', r.created_at
    )
  ), '[]'::jsonb) INTO v_results
  FROM public.results r
  LEFT JOIN public.subjects s ON r.subject_id = s.id
  WHERE r.student_id = p_student_id;

  RETURN jsonb_build_object(
    'success', true,
    'student_id', p_student_id,
    'results', v_results
  );
END;
$$;


-- ──────────────────────────────────────────────
-- 2. TEACHER MODULE STORED PROCEDURES
-- ──────────────────────────────────────────────

-- 2.1 Teacher Classes & Enrolled Students Count RPC
CREATE OR REPLACE FUNCTION public.rpc_get_teacher_classes_detail(p_teacher_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_school_id UUID;
  v_classes JSONB;
BEGIN
  SELECT school_id INTO v_school_id FROM public.profiles WHERE id = p_teacher_id LIMIT 1;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'class_name', t.class,
      'subject_id', t.subject_id,
      'subject_name', COALESCE(s.name, 'General'),
      'student_count', (
        SELECT COUNT(p.id) FROM public.profiles p 
        WHERE p.school_id = v_school_id AND p.class = t.class AND LOWER(p.role) = 'student'
      )
    )
  ), '[]'::jsonb) INTO v_classes
  FROM (
    SELECT DISTINCT class, subject_id 
    FROM public.timetable 
    WHERE teacher_id = p_teacher_id AND (p_school_id IS NULL OR school_id = v_school_id)
  ) t
  LEFT JOIN public.subjects s ON t.subject_id = s.id;

  RETURN jsonb_build_object(
    'success', true,
    'teacher_id', p_teacher_id,
    'classes', v_classes
  );
END;
$$;


-- 2.2 Teacher Gradebook Roster RPC
CREATE OR REPLACE FUNCTION public.rpc_get_teacher_gradebook(
  p_school_id UUID, 
  p_class TEXT, 
  p_subject_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_roster JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'student_id', p.id,
      'roll_number', p.roll_number,
      'full_name', p.full_name,
      'email', p.email,
      'class', p.class,
      'section', p.section,
      'attendance_percentage', (
        SELECT COALESCE(ROUND(AVG(CASE WHEN LOWER(a.status) IN ('present', 'late') THEN 100.0 ELSE 0.0 END), 2), 0.0)
        FROM public.attendance a WHERE a.student_id = p.id
      ),
      'average_marks_pct', (
        SELECT COALESCE(ROUND(AVG((r.marks_obtained::NUMERIC / NULLIF(r.total_marks, 0)) * 100.0), 2), 0.0)
        FROM public.results r WHERE r.student_id = p.id AND (p_subject_id IS NULL OR r.subject_id = p_subject_id)
      )
    )
  ), '[]'::jsonb) INTO v_roster
  FROM public.profiles p
  WHERE p.school_id = p_school_id AND p.class = p_class AND LOWER(p.role) = 'student'
  ORDER BY p.roll_number, p.full_name;

  RETURN jsonb_build_object(
    'success', true,
    'class', p_class,
    'subject_id', p_subject_id,
    'roster', v_roster
  );
END;
$$;


-- ──────────────────────────────────────────────
-- 3. TRANSPORT & FLEET STORED PROCEDURES
-- ──────────────────────────────────────────────

-- 3.1 Route Management Details RPC
CREATE OR REPLACE FUNCTION public.rpc_get_route_management_details(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_routes JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', tr.id,
      'route_code', tr.route_code,
      'route_name', tr.route_name,
      'area_zone', tr.area_zone,
      'distance_km', tr.distance_km,
      'start_time', tr.start_time,
      'end_time', tr.end_time,
      'status', tr.status,
      'vehicle_no', COALESCE(v.vehicle_no, b.bus_number, 'Unassigned'),
      'driver_name', COALESCE(p.full_name, 'Unassigned'),
      'driver_phone', p.phone,
      'stops_count', (
        SELECT COUNT(id) FROM public.transport_route_stops trs WHERE trs.route_id = tr.id
      )
    )
  ), '[]'::jsonb) INTO v_routes
  FROM public.transport_routes tr
  LEFT JOIN public.vehicles v ON tr.vehicle_id = v.id
  LEFT JOIN public.bus_routes b ON tr.vehicle_id = b.id
  LEFT JOIN public.profiles p ON tr.driver_id = p.id
  WHERE tr.school_id = p_school_id
  ORDER BY tr.route_code;

  RETURN jsonb_build_object(
    'success', true,
    'school_id', p_school_id,
    'routes', v_routes
  );
END;
$$;


-- 3.2 Update Vehicle Location Telemetry Atomic RPC
CREATE OR REPLACE FUNCTION public.rpc_update_vehicle_location_telemetry(
  p_vehicle_id UUID,
  p_school_id UUID,
  p_latitude NUMERIC,
  p_longitude NUMERIC,
  p_speed_kmh NUMERIC DEFAULT 0.0,
  p_heading NUMERIC DEFAULT 0.0
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
  v_trip_id UUID;
BEGIN
  -- Insert into telemetry history table
  INSERT INTO public.bus_locations (
    school_id,
    route_id,
    latitude,
    longitude,
    speed,
    heading,
    timestamp
  )
  VALUES (
    p_school_id,
    p_vehicle_id,
    p_latitude,
    p_longitude,
    p_speed_kmh,
    p_heading,
    NOW()
  );

  -- Update active trip location if in progress
  UPDATE public.vehicle_trips
  SET current_latitude = p_latitude,
      current_longitude = p_longitude,
      current_speed_kmh = p_speed_kmh,
      updated_at = NOW()
  WHERE vehicle_id = p_vehicle_id 
    AND school_id = p_school_id 
    AND LOWER(status) = 'in_progress'
  RETURNING id INTO v_trip_id;

  -- Create high-speed alert if speed exceeds threshold (e.g. 60 km/h)
  IF p_speed_kmh > 65.0 THEN
    INSERT INTO public.vehicle_live_alerts (
      school_id,
      vehicle_id,
      trip_id,
      alert_type,
      severity,
      message,
      created_at
    )
    VALUES (
      p_school_id,
      p_vehicle_id,
      v_trip_id,
      'Overspeed',
      'Warning',
      'Vehicle exceeded speed limit: ' || ROUND(p_speed_kmh, 1)::TEXT || ' km/h',
      NOW()
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'vehicle_id', p_vehicle_id,
    'trip_id', v_trip_id,
    'updated_at', NOW()
  );
END;
$$;


-- ──────────────────────────────────────────────
-- 4. PAYMENTS & FEES STORED PROCEDURES
-- ──────────────────────────────────────────────

-- 4.1 Process Fee Payment Atomic RPC
CREATE OR REPLACE FUNCTION public.rpc_process_fee_payment(
  p_school_id UUID,
  p_student_id UUID,
  p_amount NUMERIC,
  p_payment_mode TEXT DEFAULT 'Online',
  p_transaction_id TEXT DEFAULT NULL,
  p_remarks TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
  v_payment_id UUID;
  v_receipt_no TEXT;
BEGIN
  v_receipt_no := 'REC-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM()*9999)::TEXT, 4, '0');

  INSERT INTO public.payments (
    school_id,
    student_id,
    amount,
    payment_mode,
    transaction_id,
    receipt_no,
    status,
    remarks,
    created_at
  )
  VALUES (
    p_school_id,
    p_student_id,
    p_amount,
    p_payment_mode,
    COALESCE(p_transaction_id, gen_random_uuid()::text),
    v_receipt_no,
    'Completed',
    p_remarks,
    NOW()
  )
  RETURNING id INTO v_payment_id;

  -- Create payment notification for student/parent
  INSERT INTO public.notifications (
    school_id,
    user_id,
    title,
    message,
    category,
    is_read,
    created_at
  )
  VALUES (
    p_school_id,
    p_student_id,
    'Payment Received',
    'Payment of ₹' || ROUND(p_amount, 2)::TEXT || ' received successfully. Receipt: ' || v_receipt_no,
    'Finance',
    FALSE,
    NOW()
  );

  RETURN jsonb_build_object(
    'success', true,
    'payment_id', v_payment_id,
    'receipt_no', v_receipt_no,
    'amount', p_amount,
    'status', 'Completed'
  );
END;
$$;


-- ──────────────────────────────────────────────
-- 5. ADMIN & SUPERADMIN ANALYTICS STORED PROCEDURES
-- ──────────────────────────────────────────────

-- 5.1 Superadmin Platform KPIs RPC
CREATE OR REPLACE FUNCTION public.rpc_get_superadmin_kpis()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_total_schools INT := 0;
  v_active_schools INT := 0;
  v_total_students INT := 0;
  v_total_teachers INT := 0;
  v_total_revenue NUMERIC := 0.0;
  v_result JSONB;
BEGIN
  SELECT COUNT(*), COALESCE(SUM(CASE WHEN LOWER(subscription_status) = 'active' THEN 1 ELSE 0 END), 0)
  INTO v_total_schools, v_active_schools
  FROM public.schools;

  SELECT COUNT(*) INTO v_total_students FROM public.profiles WHERE LOWER(role) = 'student';
  SELECT COUNT(*) INTO v_total_teachers FROM public.profiles WHERE LOWER(role) IN ('teacher', 'hod');

  SELECT COALESCE(SUM(amount), 0.0) INTO v_total_revenue FROM public.payments WHERE LOWER(status) = 'completed';

  v_result := jsonb_build_object(
    'success', true,
    'total_schools', v_total_schools,
    'active_schools', v_active_schools,
    'total_students', v_total_students,
    'total_teachers', v_total_teachers,
    'total_revenue', v_total_revenue,
    'timestamp', NOW()
  );

  RETURN v_result;
END;
$$;
