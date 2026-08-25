-- ============================================================================
-- Migration: 325_approved_leave_periods_and_attendance_math_matrix.sql
-- Description:
--   1. Automatically propagates approved leave to daily attendance & all periods
--      with leave application reason/remarks.
--   2. Implements the exact Period Situation vs Day Summary mathematical matrix:
--      - All NO_MARKED -> NO_MARKED
--      - All ON_LEAVE -> ON_LEAVE
--      - All ABSENT -> ABSENT
--      - Any official leave + other non-present periods -> ON_LEAVE
--      - Attendance >= 75% -> PRESENT
--      - Attendance 50% - <75% -> HALF_DAY
--      - Attendance < 50% -> ABSENT
--      - All attended but at least one LATE -> LATE
--      - All periods PRESENT -> PRESENT
--   3. Fixes Reset (NOT_MARKED) for individual periods and whole-day records.
-- ============================================================================

-- 0. FUNCTION: fn_get_class_academic_periods_for_date (With Accurate Calendar Recurrence & Exception Math)
CREATE OR REPLACE FUNCTION public.fn_get_class_academic_periods_for_date(
    p_school_id UUID,
    p_date DATE,
    p_class_id UUID,
    p_section_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_class_name TEXT;
    v_section_name TEXT;
    v_periods JSONB := '[]'::jsonb;
    v_sched_count INT := 0;
BEGIN
    SELECT name INTO v_class_name FROM public.academic_classes WHERE id = p_class_id;
    IF p_section_id IS NOT NULL THEN
        SELECT name INTO v_section_name FROM public.academic_sections WHERE id = p_section_id;
    END IF;

    -- Query schedules linked to Academic Calendar with Class-Section-Subject offerings
    WITH academic_schedules AS (
        SELECT DISTINCT ON (
            s.id, 
            COALESCE(sp.target_subject_id, sub_tcs.id, '00000000-0000-0000-0000-000000000000'::UUID),
            COALESCE(sp.section_id, sub_tcs.section_id, '00000000-0000-0000-0000-000000000000'::UUID)
        )
            s.id AS schedule_id,
            s.title AS schedule_title,
            s.description AS schedule_description,
            s.color AS schedule_color,
            s.start_time,
            s.end_time,
            s.timezone,
            s.organizer_id,
            p_org.full_name AS teacher_name,
            p_org.avatar_url AS teacher_avatar,
            COALESCE(sp.target_subject_id, sub_tcs.id, sub_direct.id) AS subject_id,
            COALESCE(sub_sp.name, sub_tcs.name, sp.target_subject, sub_direct.name, s.title) AS subject_name,
            COALESCE(sub_sp.code, sub_tcs.code, sub_direct.code, '') AS subject_code,
            COALESCE(sub_sp.color, sub_tcs.color, s.color, '#4F46E5') AS subject_color,
            COALESCE(sp.section_id, sub_tcs.section_id) AS section_id,
            COALESCE(sec_sp.name, sub_tcs.section_name, sp.target_section, '') AS section_name,
            (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::TIME AS local_start_time,
            (s.end_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::TIME AS local_end_time
        FROM public.schedules s
        JOIN public.calendars c ON c.id = s.calendar_id
        LEFT JOIN public.profiles p_org ON p_org.id = s.organizer_id
        LEFT JOIN public.schedule_recurrence rec ON rec.schedule_id = COALESCE(s.recurring_parent_id, s.id)
        -- Left join participants targeting class/section/subject
        LEFT JOIN public.schedule_participants sp ON sp.schedule_id = s.id 
             AND (
                 sp.class_id = p_class_id 
                 OR (v_class_name IS NOT NULL AND sp.target_class ILIKE v_class_name)
             )
             AND (
                 p_section_id IS NULL 
                 OR sp.section_id = p_section_id 
                 OR sp.section_id IS NULL 
                 OR (v_section_name IS NOT NULL AND sp.target_section ILIKE v_section_name)
             )
        LEFT JOIN public.academic_sections sec_sp ON sec_sp.id = sp.section_id
        LEFT JOIN public.academic_subjects sub_sp ON sub_sp.id = sp.target_subject_id
        -- Lateral join target_class_sections JSON array
        LEFT JOIN LATERAL (
            SELECT 
                (elem->>'subject_id')::UUID AS id,
                elem->>'subject_name' AS name,
                (elem->>'section_id')::UUID AS section_id,
                elem->>'section_name' AS section_name,
                '' AS code,
                NULL::TEXT AS color
            FROM jsonb_array_elements(COALESCE(s.target_class_sections, '[]'::jsonb)) elem
            WHERE (elem->>'class_id')::UUID = p_class_id
              AND (p_section_id IS NULL OR elem->>'section_id' IS NULL OR (elem->>'section_id')::UUID = p_section_id)
            LIMIT 1
        ) sub_tcs ON TRUE
        -- Direct subject lookup if title matches
        LEFT JOIN public.academic_subjects sub_direct ON (
            s.title ILIKE '%' || sub_direct.name || '%'
            AND sub_direct.school_id = p_school_id
        )
        WHERE s.school_id = p_school_id
          AND s.deleted_at IS NULL
          AND s.status NOT IN ('cancelled')
          -- Match Academic Calendar (case-insensitive name or type)
          AND (
              LOWER(TRIM(c.name)) LIKE '%academic%'
              OR LOWER(TRIM(c.type)) = 'academic'
              OR c.id = '52c2bc44-add3-4f10-9b43-51fa32570cf0'::UUID
          )
          -- Match Class & Section
          AND (
              sp.id IS NOT NULL
              OR EXISTS (
                  SELECT 1 FROM jsonb_array_elements(COALESCE(s.target_class_sections, '[]'::jsonb)) elem
                  WHERE (elem->>'class_id')::UUID = p_class_id
                    AND (p_section_id IS NULL OR elem->>'section_id' IS NULL OR (elem->>'section_id')::UUID = p_section_id)
              )
              OR (
                  v_class_name IS NOT NULL 
                  AND EXISTS (
                      SELECT 1 FROM jsonb_array_elements_text(COALESCE(s.target_classes, '[]'::jsonb)) tc
                      WHERE tc ILIKE v_class_name
                  )
              )
          )
          -- Date Active Check
          AND (
              (
                  (s.is_recurring = FALSE OR s.is_recurring IS NULL OR rec.id IS NULL)
                  AND DATE(s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata')) = p_date
              )
              OR (
                  s.is_recurring = TRUE
                  AND rec.id IS NOT NULL
                  AND p_date >= DATE(s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))
                  -- Check end_date limit for until_date / on_date
                  AND (
                      rec.end_type NOT IN ('until_date', 'on_date', 'until') 
                      OR rec.end_date IS NULL 
                      OR p_date <= rec.end_date
                  )
                  -- Check exceptions list (e.g. ["2026-08-20"])
                  AND NOT (COALESCE(rec.exceptions, '[]'::jsonb) ? to_char(p_date, 'YYYY-MM-DD'))
                  -- Check Frequency and End Count
                  AND (
                      (
                          rec.frequency = 'daily' 
                          AND (p_date - DATE(s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))) % GREATEST(COALESCE(rec.interval, 1), 1) = 0
                          AND (
                              rec.end_type != 'after_count' 
                              OR rec.end_count IS NULL 
                              OR (
                                  (p_date - DATE(s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))) / GREATEST(COALESCE(rec.interval, 1), 1) + 1
                                  - (
                                      SELECT COUNT(*) 
                                      FROM jsonb_array_elements_text(COALESCE(rec.exceptions, '[]'::jsonb)) exc_date
                                      WHERE exc_date::DATE >= DATE(s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))
                                        AND exc_date::DATE <= p_date
                                        AND (exc_date::DATE - DATE(s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))) % GREATEST(COALESCE(rec.interval, 1), 1) = 0
                                  )
                              ) <= rec.end_count
                          )
                      )
                      OR (
                          rec.frequency = 'weekdays' 
                          AND EXTRACT(ISODOW FROM p_date) BETWEEN 1 AND 5
                          AND (
                              rec.end_type != 'after_count' 
                              OR rec.end_count IS NULL
                          )
                      )
                      OR (
                          rec.frequency = 'weekly' 
                          AND (p_date - DATE(s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata')))/7 % GREATEST(COALESCE(rec.interval, 1), 1) = 0
                          AND (
                              COALESCE(rec.days_of_week, '[]'::jsonb) = '[]'::jsonb
                              OR rec.days_of_week ? UPPER(SUBSTRING(to_char(p_date, 'Day') FROM 1 FOR 2))
                          )
                          AND (
                              rec.end_type != 'after_count' 
                              OR rec.end_count IS NULL 
                              OR (
                                  (p_date - DATE(s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata')))/7 / GREATEST(COALESCE(rec.interval, 1), 1) + 1
                              ) <= rec.end_count
                          )
                      )
                      OR (
                          rec.frequency = 'monthly' 
                          AND EXTRACT(DAY FROM p_date) = EXTRACT(DAY FROM (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata')))
                          AND (
                              rec.end_type != 'after_count' 
                              OR rec.end_count IS NULL
                          )
                      )
                      OR (
                          rec.frequency = 'yearly'
                          AND EXTRACT(MONTH FROM p_date) = EXTRACT(MONTH FROM (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata')))
                          AND EXTRACT(DAY FROM p_date) = EXTRACT(DAY FROM (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata')))
                      )
                  )
                  -- Exclude if an explicit override exists on this date
                  AND NOT EXISTS (
                      SELECT 1 FROM public.schedules ovr
                      WHERE ovr.recurring_parent_id = s.id
                        AND ovr.original_instance_date = p_date
                        AND ovr.deleted_at IS NULL
                  )
                  -- Exclude if deleted instance exists
                  AND NOT EXISTS (
                      SELECT 1 FROM public.schedules del
                      WHERE (del.recurring_parent_id = s.id OR del.id = s.id)
                        AND del.deleted_at IS NOT NULL
                        AND COALESCE(del.original_instance_date, DATE(del.start_time AT TIME ZONE COALESCE(del.timezone, 'Asia/Kolkata'))) = p_date
                  )
              )
          )
        ORDER BY 
            s.id, 
            COALESCE(sp.target_subject_id, sub_tcs.id, '00000000-0000-0000-0000-000000000000'::UUID),
            COALESCE(sp.section_id, sub_tcs.section_id, '00000000-0000-0000-0000-000000000000'::UUID),
            s.start_time ASC
    ),
    ordered_schedules AS (
        SELECT 
            ROW_NUMBER() OVER (
                PARTITION BY COALESCE(section_id, '00000000-0000-0000-0000-000000000000'::UUID)
                ORDER BY local_start_time ASC, schedule_title ASC
            ) AS section_period_num,
            ROW_NUMBER() OVER (ORDER BY local_start_time ASC, schedule_title ASC) AS global_period_num,
            academic_schedules.*
        FROM academic_schedules
    ),
    period_aggregates AS (
        SELECT 
            os.schedule_id,
            CASE WHEN p_section_id IS NOT NULL THEN os.section_period_num ELSE os.global_period_num END AS period_number,
            'P' || (CASE WHEN p_section_id IS NOT NULL THEN os.section_period_num ELSE os.global_period_num END) AS period_label,
            os.section_period_num AS section_period_number,
            'P' || os.section_period_num AS section_period_label,
            os.section_id,
            os.section_name,
            to_char(os.local_start_time, 'HH12:MI AM') || ' - ' || to_char(os.local_end_time, 'HH12:MI AM') AS time_range,
            COALESCE(os.subject_id, gen_random_uuid()) AS subject_id,
            os.subject_name,
            os.subject_code,
            os.subject_color,
            os.teacher_name,
            os.teacher_avatar,
            os.schedule_title,
            EXISTS (
                SELECT 1 FROM public.attendance_period_records apr
                WHERE apr.school_id = p_school_id
                  AND apr.class_id = p_class_id
                  AND (p_section_id IS NULL OR apr.section_id = p_section_id OR apr.section_id IS NULL)
                  AND apr.attendance_date = p_date
                  AND (
                      apr.schedule_id = os.schedule_id 
                      OR apr.period_number = (CASE WHEN p_section_id IS NOT NULL THEN os.section_period_num ELSE os.global_period_num END)
                  )
            ) AS is_completed,
            EXISTS (
                SELECT 1 FROM public.attendance_period_records apr
                WHERE apr.school_id = p_school_id
                  AND apr.class_id = p_class_id
                  AND (p_section_id IS NULL OR apr.section_id = p_section_id OR apr.section_id IS NULL)
                  AND apr.attendance_date = p_date
                  AND (
                      apr.schedule_id = os.schedule_id 
                      OR apr.period_number = (CASE WHEN p_section_id IS NOT NULL THEN os.section_period_num ELSE os.global_period_num END)
                  )
                  AND apr.is_locked = TRUE
            ) AS is_locked,
            COALESCE(
                (
                    SELECT apr.status FROM public.attendance_period_records apr
                    WHERE apr.school_id = p_school_id
                      AND apr.class_id = p_class_id
                      AND (p_section_id IS NULL OR apr.section_id = p_section_id OR apr.section_id IS NULL)
                      AND apr.attendance_date = p_date
                      AND (
                          apr.schedule_id = os.schedule_id 
                          OR apr.period_number = (CASE WHEN p_section_id IS NOT NULL THEN os.section_period_num ELSE os.global_period_num END)
                      )
                    ORDER BY apr.updated_at DESC LIMIT 1
                ),
                'NOT_MARKED'
            ) AS status,
            (
                SELECT COUNT(*) FROM public.attendance_period_records apr
                WHERE apr.school_id = p_school_id
                  AND apr.class_id = p_class_id
                  AND (p_section_id IS NULL OR apr.section_id = p_section_id OR apr.section_id IS NULL)
                  AND apr.attendance_date = p_date
                  AND (
                      apr.schedule_id = os.schedule_id 
                      OR apr.period_number = (CASE WHEN p_section_id IS NOT NULL THEN os.section_period_num ELSE os.global_period_num END)
                  )
                  AND apr.status = 'PRESENT'
            ) AS present_count,
            (
                SELECT COUNT(*) FROM public.attendance_period_records apr
                WHERE apr.school_id = p_school_id
                  AND apr.class_id = p_class_id
                  AND (p_section_id IS NULL OR apr.section_id = p_section_id OR apr.section_id IS NULL)
                  AND apr.attendance_date = p_date
                  AND (
                      apr.schedule_id = os.schedule_id 
                      OR apr.period_number = (CASE WHEN p_section_id IS NOT NULL THEN os.section_period_num ELSE os.global_period_num END)
                  )
                  AND apr.status = 'ABSENT'
            ) AS absent_count,
            (
                SELECT COUNT(*) FROM public.attendance_period_records apr
                WHERE apr.school_id = p_school_id
                  AND apr.class_id = p_class_id
                  AND (p_section_id IS NULL OR apr.section_id = p_section_id OR apr.section_id IS NULL)
                  AND apr.attendance_date = p_date
                  AND (
                      apr.schedule_id = os.schedule_id 
                      OR apr.period_number = (CASE WHEN p_section_id IS NOT NULL THEN os.section_period_num ELSE os.global_period_num END)
                  )
                  AND apr.status = 'LATE'
            ) AS late_count
        FROM ordered_schedules os
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', pa.schedule_id,
                'schedule_id', pa.schedule_id,
                'period_number', pa.period_number,
                'period_label', pa.period_label,
                'section_period_number', pa.section_period_number,
                'section_period_label', pa.section_period_label,
                'section_id', pa.section_id,
                'section_name', pa.section_name,
                'subject_id', pa.subject_id,
                'subject_name', pa.subject_name,
                'subject_code', pa.subject_code,
                'subject_color', pa.subject_color,
                'time_range', pa.time_range,
                'teacher_name', pa.teacher_name,
                'teacher_avatar', pa.teacher_avatar,
                'schedule_title', pa.schedule_title,
                'is_completed', pa.is_completed,
                'is_locked', pa.is_locked,
                'status', pa.status,
                'present_count', pa.present_count,
                'absent_count', pa.absent_count,
                'late_count', pa.late_count
            ) ORDER BY pa.period_number ASC
        ),
        '[]'::jsonb
    ) INTO v_periods
    FROM period_aggregates pa;

    SELECT COALESCE(jsonb_array_length(v_periods), 0) INTO v_sched_count;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'schedules', v_periods,
            'count', v_sched_count,
            'source', 'academic_calendar'
        )
    );
END;
$$;


-- 1. HELPER FUNCTION: fn_calculate_composite_attendance_status
CREATE OR REPLACE FUNCTION public.fn_calculate_composite_attendance_status(
    p_total_periods BIGINT,
    p_present_count BIGINT,
    p_absent_count BIGINT,
    p_late_count BIGINT,
    p_leave_count BIGINT,
    p_half_day_count BIGINT,
    p_marked_count BIGINT
)
RETURNS VARCHAR
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_attended_score NUMERIC;
    v_pct NUMERIC;
BEGIN
    -- 1. All NOT_MARKED
    IF p_total_periods <= 0 OR p_marked_count <= 0 THEN
        RETURN 'NOT_MARKED';
    END IF;

    -- 2. All ON_LEAVE
    IF p_leave_count = p_total_periods THEN
        RETURN 'ON_LEAVE';
    END IF;

    -- 3. All ABSENT
    IF p_absent_count = p_total_periods THEN
        RETURN 'ABSENT';
    END IF;

    -- 4. All periods PRESENT
    IF p_present_count = p_total_periods THEN
        RETURN 'PRESENT';
    END IF;

    -- 5. All attended but at least one LATE
    IF (p_present_count + p_late_count) = p_total_periods 
       AND p_late_count > 0 
       AND p_absent_count = 0 
       AND p_leave_count = 0 
       AND p_half_day_count = 0 THEN
        RETURN 'LATE';
    END IF;

    -- 6. Any official leave + other non-present periods (e.g. Leave + Absent)
    IF p_leave_count > 0 AND p_present_count = 0 AND p_late_count = 0 THEN
        RETURN 'ON_LEAVE';
    END IF;

    -- 7. Percentage-based composite calculation
    -- Attended credit = Present (1.0) + Late (1.0) + Half Day (0.5)
    v_attended_score := p_present_count::NUMERIC + p_late_count::NUMERIC + (0.5 * p_half_day_count::NUMERIC);
    v_pct := (v_attended_score / GREATEST(p_total_periods, 1)::NUMERIC) * 100.0;

    IF v_pct >= 75.0 THEN
        RETURN 'PRESENT';
    ELSIF v_pct >= 50.0 THEN
        RETURN 'HALF_DAY';
    ELSE
        IF p_leave_count > 0 AND (p_absent_count > 0 OR p_half_day_count > 0) THEN
            RETURN 'ON_LEAVE';
        ELSE
            RETURN 'ABSENT';
        END IF;
    END IF;
END;
$$;


-- 2. FUNCTION: fn_quick_mark_student_period (With Reset / NOT_MARKED fix & Mathematical Matrix)
CREATE OR REPLACE FUNCTION public.fn_quick_mark_student_period(
    p_school_id UUID,
    p_user_id UUID,
    p_student_id UUID,
    p_date DATE,
    p_period_number INT,
    p_status VARCHAR,
    p_subject_id UUID DEFAULT NULL,
    p_schedule_id UUID DEFAULT NULL,
    p_remarks TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_class_id UUID;
    v_section_id UUID;
    v_status_norm VARCHAR := UPPER(TRIM(COALESCE(p_status, 'PRESENT')));
    v_total_sched_count INT := 0;
    v_student_marked_periods INT := 0;
    v_present_c INT := 0;
    v_absent_c INT := 0;
    v_late_c INT := 0;
    v_leave_c INT := 0;
    v_half_c INT := 0;
    v_composite_daily_status VARCHAR := 'NOT_MARKED';
BEGIN
    -- Resolve student's current class and section
    SELECT sca.class_id, sca.section_id INTO v_class_id, v_section_id
    FROM public.student_class_assignments sca
    WHERE sca.school_id = p_school_id AND sca.student_id = p_student_id AND sca.status = 'ACTIVE'
    LIMIT 1;

    IF v_class_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Active class assignment not found for student', 'code', 404);
    END IF;

    -- Count total scheduled periods for this specific student's section
    SELECT COALESCE(jsonb_array_length(public.fn_get_class_academic_periods_for_date(p_school_id, p_date, v_class_id, v_section_id)->'data'->'schedules'), 0)
    INTO v_total_sched_count;

    -- Delete existing period record for this period
    DELETE FROM public.attendance_period_records
    WHERE school_id = p_school_id
      AND student_id = p_student_id
      AND attendance_date = p_date
      AND period_number = p_period_number;

    -- Insert new period record if status is NOT_MARKED
    IF v_status_norm NOT IN ('NOT_MARKED', 'RESET', '') THEN
        INSERT INTO public.attendance_period_records (
            school_id, student_id, class_id, section_id,
            subject_id, schedule_id, attendance_date, period_number, status, remarks,
            is_locked, locked_by_all_day, created_by, updated_by, updated_at
        ) VALUES (
            p_school_id, p_student_id, v_class_id, v_section_id,
            p_subject_id, p_schedule_id, p_date, p_period_number, v_status_norm, TRIM(COALESCE(p_remarks, '')),
            FALSE, FALSE, p_user_id, p_user_id, NOW()
        );
    END IF;

    -- Count how many periods are now marked for this student
    SELECT 
        COUNT(DISTINCT period_number),
        COUNT(*) FILTER (WHERE status = 'PRESENT'),
        COUNT(*) FILTER (WHERE status = 'ABSENT'),
        COUNT(*) FILTER (WHERE status = 'LATE'),
        COUNT(*) FILTER (WHERE status = 'ON_LEAVE'),
        COUNT(*) FILTER (WHERE status = 'HALF_DAY')
    INTO v_student_marked_periods, v_present_c, v_absent_c, v_late_c, v_leave_c, v_half_c
    FROM public.attendance_period_records
    WHERE school_id = p_school_id
      AND student_id = p_student_id
      AND attendance_date = p_date
      AND status NOT IN ('NOT_MARKED', 'RESET', '');

    -- If 0 periods are marked, reset daily master record
    IF v_student_marked_periods = 0 THEN
        DELETE FROM public.attendance_daily_records
        WHERE school_id = p_school_id
          AND student_id = p_student_id
          AND attendance_date = p_date;
        v_composite_daily_status := 'NOT_MARKED';
    ELSE
        -- Compute mathematically sound composite status
        v_composite_daily_status := public.fn_calculate_composite_attendance_status(
            v_total_sched_count,
            v_present_c,
            v_absent_c,
            v_late_c,
            v_leave_c,
            v_half_c,
            v_student_marked_periods
        );

        INSERT INTO public.attendance_daily_records (
            school_id, student_id, class_id, section_id, attendance_date,
            status, remarks, is_locked, locked_by, locked_at, is_all_day,
            created_by, updated_by, updated_at
        ) VALUES (
            p_school_id, p_student_id, v_class_id, v_section_id, p_date,
            v_composite_daily_status, 'Updated from period attendance', (v_student_marked_periods >= v_total_sched_count AND v_total_sched_count > 0), p_user_id, NOW(), (v_student_marked_periods >= v_total_sched_count AND v_total_sched_count > 0),
            p_user_id, p_user_id, NOW()
        )
        ON CONFLICT (school_id, student_id, attendance_date) DO UPDATE SET
            status = EXCLUDED.status,
            remarks = EXCLUDED.remarks,
            is_locked = (v_student_marked_periods >= v_total_sched_count AND v_total_sched_count > 0),
            locked_by = EXCLUDED.locked_by,
            locked_at = EXCLUDED.locked_at,
            is_all_day = (v_student_marked_periods >= v_total_sched_count AND v_total_sched_count > 0),
            updated_by = EXCLUDED.updated_by,
            updated_at = NOW();
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Period attendance updated',
        'student_id', p_student_id,
        'period_number', p_period_number,
        'status', v_status_norm,
        'composite_daily_status', v_composite_daily_status
    );
END;
$$;


-- 2b. FUNCTION: fn_override_locked_attendance (Stored Procedure for Override and Unlock)
CREATE OR REPLACE FUNCTION public.fn_override_locked_attendance(
    p_school_id UUID,
    p_user_id UUID,
    p_record_id UUID,
    p_record_type VARCHAR, -- 'DAILY' or 'PERIOD'
    p_new_status VARCHAR,
    p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_rec_id UUID;
    v_old_status VARCHAR := 'NOT_MARKED';
    v_student_id UUID;
    v_class_id UUID;
    v_section_id UUID;
    v_att_date DATE;
    v_total_sched_count INT := 0;
    v_student_marked_periods INT := 0;
    v_present_c INT := 0;
    v_absent_c INT := 0;
    v_late_c INT := 0;
    v_leave_c INT := 0;
    v_half_c INT := 0;
    v_comp_status VARCHAR := 'NOT_MARKED';
BEGIN
    IF TRIM(COALESCE(p_reason, '')) = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'An override reason is mandatory', 'code', 400);
    END IF;

    IF UPPER(p_record_type) = 'DAILY' THEN
        -- Check if existing daily record matches by record ID or student_id
        SELECT id, status, student_id, attendance_date, class_id, section_id 
        INTO v_rec_id, v_old_status, v_student_id, v_att_date, v_class_id, v_section_id
        FROM public.attendance_daily_records 
        WHERE (id = p_record_id OR student_id = p_record_id) 
          AND school_id = p_school_id
        ORDER BY (id = p_record_id) DESC, attendance_date DESC, updated_at DESC
        LIMIT 1;

        IF v_rec_id IS NOT NULL THEN
            UPDATE public.attendance_daily_records SET
                status = UPPER(p_new_status),
                is_locked = FALSE,
                is_overridden = TRUE,
                override_reason = TRIM(p_reason),
                updated_by = p_user_id,
                updated_at = NOW()
            WHERE id = v_rec_id;

            -- Also update child period records to match overridden status and unlock them
            UPDATE public.attendance_period_records SET
                status = UPPER(p_new_status),
                is_locked = FALSE,
                is_overridden = TRUE,
                override_reason = TRIM(p_reason),
                updated_by = p_user_id,
                updated_at = NOW()
            WHERE school_id = p_school_id 
              AND student_id = v_student_id 
              AND attendance_date = v_att_date;
        ELSE
            -- Record does not exist yet; find student's active class assignment to create it
            SELECT sca.student_id, sca.class_id, sca.section_id 
            INTO v_student_id, v_class_id, v_section_id
            FROM public.student_class_assignments sca
            WHERE sca.student_id = p_record_id 
              AND sca.school_id = p_school_id
            LIMIT 1;

            IF v_student_id IS NOT NULL THEN
                INSERT INTO public.attendance_daily_records (
                    school_id, student_id, class_id, section_id, attendance_date,
                    status, is_locked, is_overridden, override_reason, marked_by, updated_by
                ) VALUES (
                    p_school_id, v_student_id, v_class_id, v_section_id, CURRENT_DATE,
                    UPPER(p_new_status), FALSE, TRUE, TRIM(p_reason), p_user_id, p_user_id
                )
                ON CONFLICT (school_id, student_id, attendance_date)
                DO UPDATE SET
                    status = UPPER(EXCLUDED.status),
                    is_locked = FALSE,
                    is_overridden = TRUE,
                    override_reason = EXCLUDED.override_reason,
                    updated_by = EXCLUDED.updated_by,
                    updated_at = NOW()
                RETURNING id, status INTO v_rec_id, v_old_status;
            ELSE
                RETURN jsonb_build_object('success', FALSE, 'error', 'Daily attendance record or student not found', 'code', 404);
            END IF;
        END IF;

    ELSE
        -- Period attendance override
        SELECT id, status, student_id, attendance_date, class_id, section_id 
        INTO v_rec_id, v_old_status, v_student_id, v_att_date, v_class_id, v_section_id
        FROM public.attendance_period_records 
        WHERE (id = p_record_id OR student_id = p_record_id) 
          AND school_id = p_school_id
        ORDER BY (id = p_record_id) DESC, attendance_date DESC, updated_at DESC
        LIMIT 1;

        IF v_rec_id IS NOT NULL THEN
            UPDATE public.attendance_period_records SET
                status = UPPER(p_new_status),
                is_locked = FALSE,
                is_overridden = TRUE,
                override_reason = TRIM(p_reason),
                overridden_by = p_user_id,
                updated_by = p_user_id,
                updated_at = NOW()
            WHERE id = v_rec_id;

            -- Recalculate composite daily status
            SELECT COALESCE(jsonb_array_length(public.fn_get_class_academic_periods_for_date(p_school_id, v_att_date, v_class_id, v_section_id)->'data'->'schedules'), 0)
            INTO v_total_sched_count;

            SELECT 
                COUNT(DISTINCT period_number),
                COUNT(*) FILTER (WHERE status = 'PRESENT'),
                COUNT(*) FILTER (WHERE status = 'ABSENT'),
                COUNT(*) FILTER (WHERE status = 'LATE'),
                COUNT(*) FILTER (WHERE status = 'ON_LEAVE'),
                COUNT(*) FILTER (WHERE status = 'HALF_DAY')
            INTO v_student_marked_periods, v_present_c, v_absent_c, v_late_c, v_leave_c, v_half_c
            FROM public.attendance_period_records
            WHERE school_id = p_school_id
              AND student_id = v_student_id
              AND attendance_date = v_att_date
              AND status NOT IN ('NOT_MARKED', 'RESET', '');

            v_comp_status := public.fn_calculate_composite_attendance_status(
                v_total_sched_count,
                v_present_c,
                v_absent_c,
                v_late_c,
                v_leave_c,
                v_half_c,
                v_student_marked_periods
            );

            UPDATE public.attendance_daily_records SET
                status = v_comp_status,
                is_locked = FALSE,
                is_overridden = TRUE,
                override_reason = TRIM(p_reason),
                updated_by = p_user_id,
                updated_at = NOW()
            WHERE school_id = p_school_id 
              AND student_id = v_student_id 
              AND attendance_date = v_att_date;
        ELSE
            RETURN jsonb_build_object('success', FALSE, 'error', 'Period attendance record not found', 'code', 404);
        END IF;
    END IF;

    -- Write Audit Record to attendance_audit_logs
    BEGIN
        INSERT INTO public.attendance_audit_logs (
            school_id, record_type, record_id, user_id, action, old_value, new_value, reason
        ) VALUES (
            p_school_id,
            UPPER(p_record_type),
            v_rec_id,
            p_user_id,
            'OVERRIDE',
            jsonb_build_object('status', COALESCE(v_old_status, 'NOT_MARKED')),
            jsonb_build_object('status', UPPER(p_new_status)),
            TRIM(p_reason)
        );
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Attendance overridden and unlocked successfully',
        'record_id', v_rec_id,
        'old_status', v_old_status,
        'new_status', UPPER(p_new_status)
    );
END;
$$;


-- 3. FUNCTION: fn_save_daily_attendance (Mathematical Matrix Integration)
CREATE OR REPLACE FUNCTION public.fn_save_daily_attendance(
    p_school_id UUID,
    p_user_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_date DATE;
    v_class_id UUID;
    v_section_id UUID;
    v_mode VARCHAR;
    v_records JSONB;
    v_item JSONB;
    v_student_id UUID;
    v_status VARCHAR;
    v_remarks TEXT;
    v_saved_count INT := 0;
    v_daily_id UUID;
    v_sched RECORD;
    v_student_periods JSONB;
    v_p_item JSONB;
    v_p_num INT;
    v_p_status VARCHAR;
    v_p_remarks TEXT;
    v_p_sub_id UUID;
    v_p_sched_id UUID;
    v_has_grid_periods BOOLEAN := FALSE;
    v_schedules_meta JSONB;
    v_total_sched_count INT := 0;
    v_present_c INT := 0;
    v_absent_c INT := 0;
    v_late_c INT := 0;
    v_leave_c INT := 0;
    v_half_c INT := 0;
    v_marked_c INT := 0;
    v_comp_status VARCHAR;
    v_selected_periods JSONB;
    v_selected_sched_ids JSONB;
    v_period_number INT;
    v_subject_id UUID;
    v_schedule_id UUID;
    v_p_elem JSONB;
BEGIN
    v_date := (p_payload->>'attendance_date')::DATE;
    v_class_id := (p_payload->>'class_id')::UUID;
    v_section_id := (p_payload->>'section_id')::UUID;
    v_mode := UPPER(COALESCE(p_payload->>'mode', 'ALL_DAY'));
    v_records := COALESCE(p_payload->'records', '[]'::JSONB);

    IF v_date IS NULL OR v_class_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'attendance_date and class_id are required', 'code', 400);
    END IF;

    -- Fetch schedules metadata for date/class/section
    SELECT COALESCE(public.fn_get_class_academic_periods_for_date(p_school_id, v_date, v_class_id, v_section_id)->'data'->'schedules', '[]'::JSONB)
    INTO v_schedules_meta;
    v_total_sched_count := COALESCE(jsonb_array_length(v_schedules_meta), 0);

    -- Check if records contain per-student period breakdowns from the grid
    SELECT EXISTS (
        SELECT 1 FROM jsonb_array_elements(v_records) elem
        WHERE elem ? 'periods' 
          AND elem->'periods' IS NOT NULL
          AND jsonb_typeof(elem->'periods') = 'array' 
          AND (SELECT COUNT(*) FROM jsonb_array_elements(elem->'periods')) > 0
    ) INTO v_has_grid_periods;

    -- =========================================================================
    -- BRANCH A: GRID-STATE SAVING
    -- =========================================================================
    IF v_has_grid_periods THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_records) LOOP
            v_student_id := NULLIF(TRIM(v_item->>'student_id'), '')::UUID;
            v_remarks := TRIM(COALESCE(v_item->>'remarks', ''));
            v_student_periods := v_item->'periods';

            IF v_student_id IS NOT NULL THEN
                -- Clean up existing period records for this student and date
                DELETE FROM public.attendance_period_records
                WHERE school_id = p_school_id
                  AND student_id = v_student_id
                  AND attendance_date = v_date;

                -- Reset counters
                v_present_c := 0;
                v_absent_c := 0;
                v_late_c := 0;
                v_leave_c := 0;
                v_half_c := 0;
                v_marked_c := 0;

                IF v_student_periods IS NOT NULL 
                   AND jsonb_typeof(v_student_periods) = 'array' 
                   AND (SELECT COUNT(*) FROM jsonb_array_elements(v_student_periods)) > 0 THEN
                    
                    FOR v_p_item IN SELECT * FROM jsonb_array_elements(v_student_periods) LOOP
                        v_p_num := (v_p_item->>'period_number')::INT;
                        v_p_status := UPPER(TRIM(COALESCE(v_p_item->>'status', 'PRESENT')));
                        v_p_remarks := TRIM(COALESCE(v_p_item->>'remarks', ''));
                        v_p_sub_id := NULLIF(TRIM(v_p_item->>'subject_id'), '')::UUID;
                        v_p_sched_id := NULLIF(TRIM(v_p_item->>'schedule_id'), '')::UUID;

                        IF v_p_status NOT IN ('NOT_MARKED', 'RESET', '') THEN
                            v_marked_c := v_marked_c + 1;
                            IF v_p_status = 'PRESENT' THEN v_present_c := v_present_c + 1;
                            ELSIF v_p_status = 'ABSENT' THEN v_absent_c := v_absent_c + 1;
                            ELSIF v_p_status = 'LATE' THEN v_late_c := v_late_c + 1;
                            ELSIF v_p_status = 'ON_LEAVE' THEN v_leave_c := v_leave_c + 1;
                            ELSIF v_p_status = 'HALF_DAY' THEN v_half_c := v_half_c + 1;
                            END IF;

                            -- Auto-resolve subject_id and schedule_id from schedule metadata if missing
                            IF v_p_num IS NOT NULL AND (v_p_sub_id IS NULL OR v_p_sched_id IS NULL) THEN
                                SELECT 
                                    COALESCE(v_p_sub_id, NULLIF(TRIM(s_elem->>'subject_id'), '')::UUID),
                                    COALESCE(v_p_sched_id, NULLIF(TRIM(s_elem->>'schedule_id'), '')::UUID)
                                INTO v_p_sub_id, v_p_sched_id
                                FROM jsonb_array_elements(v_schedules_meta) s_elem
                                WHERE (s_elem->>'period_number')::INT = v_p_num
                                LIMIT 1;
                            END IF;

                            INSERT INTO public.attendance_period_records (
                                school_id, student_id, class_id, section_id,
                                subject_id, schedule_id, attendance_date, period_number, status, remarks,
                                is_locked, locked_by_all_day, created_by, updated_by, updated_at
                            ) VALUES (
                                p_school_id, v_student_id, v_class_id, v_section_id,
                                v_p_sub_id, v_p_sched_id, v_date, v_p_num, v_p_status, v_p_remarks,
                                TRUE, (v_mode = 'ALL_DAY'), p_user_id, p_user_id, NOW()
                            );
                        END IF;
                    END LOOP;
                END IF;

                -- If 0 marked periods and status is NOT_MARKED, remove master daily record
                IF v_marked_c = 0 AND UPPER(TRIM(COALESCE(v_item->>'status', ''))) IN ('NOT_MARKED', 'RESET', '') THEN
                    DELETE FROM public.attendance_daily_records
                    WHERE school_id = p_school_id
                      AND student_id = v_student_id
                      AND attendance_date = v_date;
                ELSE
                    -- Calculate composite daily status mathematically
                    IF v_marked_c > 0 THEN
                        v_comp_status := public.fn_calculate_composite_attendance_status(
                            (SELECT COUNT(*) FROM jsonb_array_elements(v_student_periods)),
                            v_present_c,
                            v_absent_c,
                            v_late_c,
                            v_leave_c,
                            v_half_c,
                            v_marked_c
                        );
                    ELSE
                        v_comp_status := UPPER(TRIM(COALESCE(v_item->>'status', 'PRESENT')));
                    END IF;

                    INSERT INTO public.attendance_daily_records (
                        school_id, student_id, class_id, section_id, attendance_date,
                        status, remarks, is_locked, locked_by, locked_at, is_all_day,
                        created_by, updated_by, updated_at
                    ) VALUES (
                        p_school_id, v_student_id, v_class_id, v_section_id, v_date,
                        v_comp_status, v_remarks, TRUE, p_user_id, NOW(), (v_mode = 'ALL_DAY'),
                        p_user_id, p_user_id, NOW()
                    )
                    ON CONFLICT (school_id, student_id, attendance_date) DO UPDATE SET
                        status = EXCLUDED.status,
                        remarks = EXCLUDED.remarks,
                        is_locked = TRUE,
                        locked_by = EXCLUDED.locked_by,
                        locked_at = EXCLUDED.locked_at,
                        is_all_day = (v_mode = 'ALL_DAY'),
                        updated_by = EXCLUDED.updated_by,
                        updated_at = NOW();
                END IF;

                v_saved_count := v_saved_count + 1;
            END IF;
        END LOOP;

    -- =========================================================================
    -- BRANCH B: WHOLE DAY ATTENDANCE
    -- =========================================================================
    ELSIF v_mode = 'ALL_DAY' THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_records) LOOP
            v_student_id := NULLIF(TRIM(v_item->>'student_id'), '')::UUID;
            v_status := UPPER(TRIM(COALESCE(v_item->>'status', 'PRESENT')));
            v_remarks := TRIM(COALESCE(v_item->>'remarks', ''));

            IF v_student_id IS NOT NULL THEN
                IF v_status IN ('NOT_MARKED', 'RESET', '') THEN
                    DELETE FROM public.attendance_daily_records
                    WHERE school_id = p_school_id AND student_id = v_student_id AND attendance_date = v_date;

                    DELETE FROM public.attendance_period_records
                    WHERE school_id = p_school_id AND student_id = v_student_id AND attendance_date = v_date;
                ELSE
                    INSERT INTO public.attendance_daily_records (
                        school_id, student_id, class_id, section_id, attendance_date,
                        status, remarks, is_locked, locked_by, locked_at, is_all_day,
                        created_by, updated_by, updated_at
                    ) VALUES (
                        p_school_id, v_student_id, v_class_id, v_section_id, v_date,
                        v_status, v_remarks, TRUE, p_user_id, NOW(), TRUE,
                        p_user_id, p_user_id, NOW()
                    )
                    ON CONFLICT (school_id, student_id, attendance_date) DO UPDATE SET
                        status = EXCLUDED.status,
                        remarks = EXCLUDED.remarks,
                        is_locked = TRUE,
                        locked_by = EXCLUDED.locked_by,
                        locked_at = EXCLUDED.locked_at,
                        is_all_day = TRUE,
                        updated_by = EXCLUDED.updated_by,
                        updated_at = NOW();

                    -- Propagate to all scheduled periods for this student
                    IF v_total_sched_count > 0 THEN
                        DELETE FROM public.attendance_period_records
                        WHERE school_id = p_school_id
                          AND student_id = v_student_id
                          AND attendance_date = v_date;

                        FOR v_sched IN SELECT value AS elem FROM jsonb_array_elements(v_schedules_meta) LOOP
                            INSERT INTO public.attendance_period_records (
                                school_id, student_id, class_id, section_id,
                                subject_id, schedule_id, attendance_date, period_number, status, remarks,
                                is_locked, locked_by_all_day, created_by, updated_by, updated_at
                            ) VALUES (
                                p_school_id, v_student_id, v_class_id, v_section_id,
                                NULLIF(TRIM(v_sched.elem->>'subject_id'), '')::UUID,
                                NULLIF(TRIM(v_sched.elem->>'schedule_id'), '')::UUID,
                                v_date, (v_sched.elem->>'period_number')::INT, v_status, v_remarks,
                                TRUE, TRUE, p_user_id, p_user_id, NOW()
                            );
                        END LOOP;
                    END IF;
                END IF;

                v_saved_count := v_saved_count + 1;
            END IF;
        END LOOP;

    -- =========================================================================
    -- BRANCH C: MULTI_SCHEDULE / CUSTOM SELECTION
    -- =========================================================================
    ELSIF v_mode IN ('MULTI_SCHEDULE', 'CUSTOM_SELECTION') THEN
        v_selected_periods := COALESCE(p_payload->'selected_periods', '[]'::JSONB);
        v_selected_sched_ids := COALESCE(p_payload->'selected_schedule_ids', '[]'::JSONB);

        IF jsonb_array_length(v_selected_periods) = 0 AND jsonb_array_length(v_selected_sched_ids) > 0 THEN
            SELECT jsonb_agg(elem) INTO v_selected_periods
            FROM jsonb_array_elements(v_schedules_meta) elem
            WHERE elem->>'id' = ANY(ARRAY(SELECT jsonb_array_elements_text(v_selected_sched_ids)))
               OR elem->>'schedule_id' = ANY(ARRAY(SELECT jsonb_array_elements_text(v_selected_sched_ids)));
        END IF;

        IF v_selected_periods IS NULL OR jsonb_array_length(v_selected_periods) = 0 THEN
            v_selected_periods := v_schedules_meta;
        END IF;

        FOR v_item IN SELECT * FROM jsonb_array_elements(v_records) LOOP
            v_student_id := NULLIF(TRIM(v_item->>'student_id'), '')::UUID;
            v_status := UPPER(TRIM(COALESCE(v_item->>'status', 'PRESENT')));
            v_remarks := TRIM(COALESCE(v_item->>'remarks', ''));

            IF v_student_id IS NOT NULL THEN
                FOR v_p_elem IN SELECT * FROM jsonb_array_elements(v_selected_periods) LOOP
                    v_p_num := (v_p_elem->>'period_number')::INT;
                    v_p_sub_id := NULLIF(TRIM(v_p_elem->>'subject_id'), '')::UUID;
                    v_p_sched_id := NULLIF(TRIM(v_p_elem->>'schedule_id'), '')::UUID;

                    IF v_p_num IS NOT NULL THEN
                        DELETE FROM public.attendance_period_records
                        WHERE school_id = p_school_id
                          AND student_id = v_student_id
                          AND attendance_date = v_date
                          AND period_number = v_p_num;

                        IF v_status NOT IN ('NOT_MARKED', 'RESET', '') THEN
                            INSERT INTO public.attendance_period_records (
                                school_id, student_id, class_id, section_id,
                                subject_id, schedule_id, attendance_date, period_number, status, remarks,
                                is_locked, locked_by_all_day, created_by, updated_by, updated_at
                            ) VALUES (
                                p_school_id, v_student_id, v_class_id, v_section_id,
                                v_p_sub_id, v_p_sched_id, v_date, v_p_num, v_status, v_remarks,
                                TRUE, FALSE, p_user_id, p_user_id, NOW()
                            );
                        END IF;
                    END IF;
                END LOOP;

                -- Recompute composite daily record for this student
                SELECT 
                    COUNT(DISTINCT period_number),
                    COUNT(*) FILTER (WHERE status = 'PRESENT'),
                    COUNT(*) FILTER (WHERE status = 'ABSENT'),
                    COUNT(*) FILTER (WHERE status = 'LATE'),
                    COUNT(*) FILTER (WHERE status = 'ON_LEAVE'),
                    COUNT(*) FILTER (WHERE status = 'HALF_DAY')
                INTO v_marked_c, v_present_c, v_absent_c, v_late_c, v_leave_c, v_half_c
                FROM public.attendance_period_records
                WHERE school_id = p_school_id AND student_id = v_student_id AND attendance_date = v_date AND status NOT IN ('NOT_MARKED', 'RESET', '');

                IF v_marked_c = 0 THEN
                    DELETE FROM public.attendance_daily_records WHERE school_id = p_school_id AND student_id = v_student_id AND attendance_date = v_date;
                ELSE
                    v_comp_status := public.fn_calculate_composite_attendance_status(
                        v_total_sched_count,
                        v_present_c, v_absent_c, v_late_c, v_leave_c, v_half_c, v_marked_c
                    );
                    INSERT INTO public.attendance_daily_records (
                        school_id, student_id, class_id, section_id, attendance_date,
                        status, remarks, is_locked, locked_by, locked_at, is_all_day,
                        created_by, updated_by, updated_at
                    ) VALUES (
                        p_school_id, v_student_id, v_class_id, v_section_id, v_date,
                        v_comp_status, v_remarks, (v_marked_c >= v_total_sched_count AND v_total_sched_count > 0), p_user_id, NOW(), FALSE,
                        p_user_id, p_user_id, NOW()
                    )
                    ON CONFLICT (school_id, student_id, attendance_date) DO UPDATE SET
                        status = EXCLUDED.status,
                        remarks = EXCLUDED.remarks,
                        is_locked = (v_marked_c >= v_total_sched_count AND v_total_sched_count > 0),
                        updated_by = EXCLUDED.updated_by,
                        updated_at = NOW();
                END IF;

                v_saved_count := v_saved_count + 1;
            END IF;
        END LOOP;

    -- =========================================================================
    -- BRANCH D: SINGLE PERIOD ATTENDANCE
    -- =========================================================================
    ELSE
        v_period_number := COALESCE((p_payload->>'period_number')::INT, 1);
        v_subject_id := NULLIF(TRIM(p_payload->>'subject_id'), '')::UUID;
        v_schedule_id := NULLIF(TRIM(p_payload->>'schedule_id'), '')::UUID;

        FOR v_item IN SELECT * FROM jsonb_array_elements(v_records) LOOP
            v_student_id := NULLIF(TRIM(v_item->>'student_id'), '')::UUID;
            v_status := UPPER(TRIM(COALESCE(v_item->>'status', 'PRESENT')));
            v_remarks := TRIM(COALESCE(v_item->>'remarks', ''));
            v_period_number := COALESCE((v_item->>'period_number')::INT, v_period_number, 1);
            v_subject_id := COALESCE(NULLIF(TRIM(v_item->>'subject_id'), '')::UUID, v_subject_id);

            IF v_student_id IS NOT NULL THEN
                DELETE FROM public.attendance_period_records
                WHERE school_id = p_school_id
                  AND student_id = v_student_id
                  AND attendance_date = v_date
                  AND period_number = v_period_number;

                IF v_status NOT IN ('NOT_MARKED', 'RESET', '') THEN
                    INSERT INTO public.attendance_period_records (
                        school_id, student_id, class_id, section_id,
                        subject_id, schedule_id, attendance_date, period_number, status, remarks,
                        is_locked, locked_by_all_day, created_by, updated_by, updated_at
                    ) VALUES (
                        p_school_id, v_student_id, v_class_id, v_section_id,
                        v_subject_id, v_schedule_id, v_date, v_period_number, v_status, v_remarks,
                        TRUE, FALSE, p_user_id, p_user_id, NOW()
                    );
                END IF;

                -- Recompute composite daily record for this student
                SELECT 
                    COUNT(DISTINCT period_number),
                    COUNT(*) FILTER (WHERE status = 'PRESENT'),
                    COUNT(*) FILTER (WHERE status = 'ABSENT'),
                    COUNT(*) FILTER (WHERE status = 'LATE'),
                    COUNT(*) FILTER (WHERE status = 'ON_LEAVE'),
                    COUNT(*) FILTER (WHERE status = 'HALF_DAY')
                INTO v_marked_c, v_present_c, v_absent_c, v_late_c, v_leave_c, v_half_c
                FROM public.attendance_period_records
                WHERE school_id = p_school_id AND student_id = v_student_id AND attendance_date = v_date AND status NOT IN ('NOT_MARKED', 'RESET', '');

                IF v_marked_c = 0 THEN
                    DELETE FROM public.attendance_daily_records WHERE school_id = p_school_id AND student_id = v_student_id AND attendance_date = v_date;
                ELSE
                    v_comp_status := public.fn_calculate_composite_attendance_status(
                        v_total_sched_count,
                        v_present_c, v_absent_c, v_late_c, v_leave_c, v_half_c, v_marked_c
                    );
                    INSERT INTO public.attendance_daily_records (
                        school_id, student_id, class_id, section_id, attendance_date,
                        status, remarks, is_locked, locked_by, locked_at, is_all_day,
                        created_by, updated_by, updated_at
                    ) VALUES (
                        p_school_id, v_student_id, v_class_id, v_section_id, v_date,
                        v_comp_status, v_remarks, (v_marked_c >= v_total_sched_count AND v_total_sched_count > 0), p_user_id, NOW(), FALSE,
                        p_user_id, p_user_id, NOW()
                    )
                    ON CONFLICT (school_id, student_id, attendance_date) DO UPDATE SET
                        status = EXCLUDED.status,
                        remarks = EXCLUDED.remarks,
                        is_locked = (v_marked_c >= v_total_sched_count AND v_total_sched_count > 0),
                        updated_by = EXCLUDED.updated_by,
                        updated_at = NOW();
                END IF;

                v_saved_count := v_saved_count + 1;
            END IF;
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Attendance saved successfully',
        'saved_count', v_saved_count,
        'mode', v_mode
    );
END;
$$;


-- 4. FUNCTION: fn_get_daily_attendance_roster (With Approved Leave Auto-Marking & Math Matrix)
CREATE OR REPLACE FUNCTION public.fn_get_daily_attendance_roster(
    p_school_id UUID,
    p_date DATE,
    p_class_id UUID,
    p_section_id UUID DEFAULT NULL,
    p_mode VARCHAR DEFAULT 'ALL_DAY',
    p_period_number INT DEFAULT NULL,
    p_subject_id UUID DEFAULT NULL,
    p_search TEXT DEFAULT '',
    p_status_filter VARCHAR DEFAULT 'ALL',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_teacher_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_count INT := 0;
    v_offset INT;
    v_students JSONB;
    v_is_locked_all_day BOOLEAN := FALSE;
    v_locked_at TIMESTAMPTZ := NULL;
    v_locked_by_name TEXT := NULL;
    v_mode_norm VARCHAR := UPPER(COALESCE(p_mode, 'ALL_DAY'));
    v_schedules_json JSONB;
BEGIN
    v_offset := (p_page - 1) * p_page_size;

    -- Fetch scheduled periods metadata for this class/section/date
    SELECT COALESCE(public.fn_get_class_academic_periods_for_date(p_school_id, p_date, p_class_id, p_section_id)->'data'->'schedules', '[]'::JSONB)
    INTO v_schedules_json;

    -- Check if all-day attendance for this class/section/date is locked
    SELECT 
        COALESCE(BOOL_OR(a.is_locked), FALSE),
        MAX(a.locked_at),
        (
            SELECT p_sub.full_name 
            FROM public.attendance_daily_records a2 
            JOIN public.profiles p_sub ON p_sub.id = a2.locked_by 
            WHERE a2.school_id = p_school_id 
              AND a2.attendance_date = p_date 
              AND a2.class_id = p_class_id 
              AND (p_section_id IS NULL OR a2.section_id = p_section_id) 
              AND a2.is_locked = TRUE 
            LIMIT 1
        )
    INTO v_is_locked_all_day, v_locked_at, v_locked_by_name
    FROM public.attendance_daily_records a
    WHERE a.school_id = p_school_id
      AND a.attendance_date = p_date
      AND a.class_id = p_class_id
      AND (p_section_id IS NULL OR a.section_id = p_section_id);

    -- 1. Calculate Total Count
    WITH eligible_students AS (
        SELECT DISTINCT ON (sca.student_id)
            sca.student_id,
            sca.roll_number,
            sca.class_id,
            sca.section_id,
            p.full_name,
            p.admission_number,
            p.email
        FROM public.student_class_assignments sca
        JOIN public.profiles p ON p.id = sca.student_id AND (p.status IS NULL OR p.status != 'Deleted')
        WHERE sca.school_id = p_school_id
          AND sca.status = 'ACTIVE'
          AND sca.class_id = p_class_id
          AND (p_section_id IS NULL OR sca.section_id = p_section_id)
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_teacher_assignments cta
                  WHERE cta.teacher_id = p_teacher_id
                    AND cta.class_id = sca.class_id
                    AND (cta.section_id = sca.section_id OR cta.section_id IS NULL)
              )
          )
          AND (
              p_search = '' 
              OR p.full_name ILIKE '%' || p_search || '%' 
              OR p.email ILIKE '%' || p_search || '%'
              OR sca.roll_number ILIKE '%' || p_search || '%'
              OR p.admission_number ILIKE '%' || p_search || '%'
          )
    ),
    filtered_roster AS (
        SELECT es.student_id
        FROM eligible_students es
        LEFT JOIN public.attendance_daily_records adr ON adr.school_id = p_school_id 
             AND adr.student_id = es.student_id 
             AND adr.attendance_date = p_date
        LEFT JOIN LATERAL (
            SELECT * FROM public.attendance_period_records 
            WHERE school_id = p_school_id 
              AND student_id = es.student_id 
              AND attendance_date = p_date 
              AND (p_period_number IS NULL OR period_number = p_period_number)
              AND (p_subject_id IS NULL OR subject_id = p_subject_id)
            ORDER BY updated_at DESC 
            LIMIT 1
        ) apr ON v_mode_norm != 'ALL_DAY'
        WHERE (
            p_status_filter = 'ALL'
            OR (v_mode_norm = 'ALL_DAY' AND UPPER(COALESCE(adr.status, 'NOT_MARKED')) = UPPER(p_status_filter))
            OR (v_mode_norm != 'ALL_DAY' AND UPPER(COALESCE(apr.status, CASE WHEN adr.is_locked = TRUE THEN adr.status ELSE 'NOT_MARKED' END)) = UPPER(p_status_filter))
        )
    )
    SELECT COUNT(*) INTO v_total_count FROM filtered_roster;

    -- 2. Build Paginated Roster with Approved Leave Propagation & Section Isolation
    WITH eligible_students AS (
        SELECT DISTINCT ON (sca.student_id)
            sca.student_id,
            sca.roll_number,
            p.admission_number,
            sca.class_id,
            sca.section_id,
            p.full_name,
            p.avatar_url,
            p.email
        FROM public.student_class_assignments sca
        JOIN public.profiles p ON p.id = sca.student_id AND (p.status IS NULL OR p.status != 'Deleted')
        WHERE sca.school_id = p_school_id
          AND sca.status = 'ACTIVE'
          AND sca.class_id = p_class_id
          AND (p_section_id IS NULL OR sca.section_id = p_section_id)
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_teacher_assignments cta
                  WHERE cta.teacher_id = p_teacher_id
                    AND cta.class_id = sca.class_id
                    AND (cta.section_id = sca.section_id OR cta.section_id IS NULL)
              )
          )
          AND (
              p_search = '' 
              OR p.full_name ILIKE '%' || p_search || '%' 
              OR p.email ILIKE '%' || p_search || '%'
              OR sca.roll_number ILIKE '%' || p_search || '%'
              OR p.admission_number ILIKE '%' || p_search || '%'
          )
        ORDER BY sca.student_id, sca.assigned_at DESC NULLS LAST
    ),
    paginated_base AS (
        SELECT 
            es.student_id,
            es.roll_number,
            es.admission_number,
            es.full_name,
            es.avatar_url,
            es.class_id,
            COALESCE(c.name, '') AS class_name,
            es.section_id,
            COALESCE(s.name, '') AS section_name,
            adr.id AS daily_record_id,
            adr.status AS daily_status,
            adr.remarks AS daily_remarks,
            COALESCE(adr.is_locked, FALSE) AS daily_is_locked,
            COALESCE(adr.is_all_day, FALSE) AS daily_is_all_day,
            COALESCE(adr.is_overridden, FALSE) AS daily_is_overridden,
            adr.override_reason AS daily_override_reason,
            adr.updated_at AS daily_updated_at,
            (SELECT prof.full_name FROM public.profiles prof WHERE prof.id = adr.updated_by) AS daily_updated_by_name,
            EXISTS (
                SELECT 1 FROM public.leave_applications la
                WHERE la.applicant_id = es.student_id
                  AND la.status = 'approved'
                  AND p_date BETWEEN la.start_date AND la.end_date
            ) AS has_approved_leave,
            (
                SELECT la.reason FROM public.leave_applications la
                WHERE la.applicant_id = es.student_id
                  AND la.status = 'approved'
                  AND p_date BETWEEN la.start_date AND la.end_date
                ORDER BY la.created_at DESC
                LIMIT 1
            ) AS leave_reason
        FROM eligible_students es
        LEFT JOIN public.academic_classes c ON c.id = es.class_id
        LEFT JOIN public.academic_sections s ON s.id = es.section_id
        LEFT JOIN public.attendance_daily_records adr ON adr.school_id = p_school_id 
             AND adr.student_id = es.student_id 
             AND adr.attendance_date = p_date
        ORDER BY 
            CASE WHEN es.roll_number ~ '^[0-9]+$' THEN es.roll_number::INT ELSE 9999 END ASC,
            es.full_name ASC
        LIMIT p_page_size
        OFFSET v_offset
    ),
    student_periods_computed AS (
        SELECT 
            pb.*,
            -- Construct array of period objects strictly isolated to this student's section
            (
                SELECT COALESCE(
                    jsonb_agg(
                        jsonb_build_object(
                            'period_number', COALESCE((s_elem->>'section_period_number')::INT, (s_elem->>'period_number')::INT),
                            'period_label', COALESCE(s_elem->>'section_period_label', s_elem->>'period_label', 'P' || (s_elem->>'period_number')),
                            'subject_id', s_elem->>'subject_id',
                            'subject_name', s_elem->>'subject_name',
                            'subject_code', s_elem->>'subject_code',
                            'subject_color', s_elem->>'subject_color',
                            'schedule_id', s_elem->>'schedule_id',
                            'section_id', s_elem->>'section_id',
                            'section_name', s_elem->>'section_name',
                            'time_range', s_elem->>'time_range',
                            'teacher_name', s_elem->>'teacher_name',
                            'teacher_avatar', s_elem->>'teacher_avatar',
                            'status', CASE 
                                WHEN apr.id IS NOT NULL THEN UPPER(apr.status)
                                WHEN pb.daily_is_overridden = TRUE AND pb.daily_status IS NOT NULL THEN UPPER(pb.daily_status)
                                WHEN pb.has_approved_leave = TRUE THEN 'ON_LEAVE'
                                WHEN pb.daily_is_locked = TRUE AND pb.daily_is_all_day = TRUE THEN UPPER(pb.daily_status)
                                ELSE 'NOT_MARKED'
                            END,
                            'remarks', CASE 
                                WHEN apr.id IS NOT NULL THEN COALESCE(apr.remarks, '')
                                WHEN pb.daily_is_overridden = TRUE THEN COALESCE(pb.daily_remarks, '')
                                WHEN pb.has_approved_leave = TRUE THEN COALESCE(pb.leave_reason, 'Approved Leave')
                                WHEN pb.daily_is_locked = TRUE AND pb.daily_is_all_day = TRUE THEN COALESCE(pb.daily_remarks, '')
                                ELSE ''
                            END,
                            'is_locked', (COALESCE(apr.is_locked, FALSE) OR (apr.id IS NULL AND pb.daily_is_locked AND pb.daily_is_all_day) OR pb.has_approved_leave),
                            'locked_by_all_day', (COALESCE(apr.locked_by_all_day, FALSE) OR (apr.id IS NULL AND (pb.daily_is_locked AND pb.daily_is_all_day) OR pb.has_approved_leave)),
                            'is_overridden', (COALESCE(apr.is_overridden, FALSE) OR pb.daily_is_overridden),
                            'override_reason', COALESCE(apr.override_reason, pb.daily_override_reason),
                            'last_updated_at', COALESCE(apr.updated_at, pb.daily_updated_at),
                            'updated_by_name', COALESCE(
                                (SELECT prof.full_name FROM public.profiles prof WHERE prof.id = apr.updated_by),
                                pb.daily_updated_by_name
                            )
                        ) ORDER BY COALESCE((s_elem->>'section_period_number')::INT, (s_elem->>'period_number')::INT) ASC
                    ),
                    '[]'::JSONB
                )
                FROM jsonb_array_elements(v_schedules_json) s_elem
                LEFT JOIN LATERAL (
                    SELECT * FROM public.attendance_period_records a
                    WHERE a.school_id = p_school_id
                      AND a.student_id = pb.student_id
                      AND a.attendance_date = p_date
                      AND (
                          (s_elem->>'schedule_id' IS NOT NULL AND a.schedule_id = (s_elem->>'schedule_id')::UUID)
                          OR (s_elem->>'subject_id' IS NOT NULL AND a.subject_id = (s_elem->>'subject_id')::UUID)
                          OR a.period_number = COALESCE((s_elem->>'section_period_number')::INT, (s_elem->>'period_number')::INT)
                      )
                    ORDER BY a.updated_at DESC
                    LIMIT 1
                ) apr ON TRUE
                WHERE (
                    -- STRICT SECTION ISOLATION:
                    s_elem->>'section_id' IS NULL 
                    OR pb.section_id IS NULL
                    OR (s_elem->>'section_id')::UUID = pb.section_id
                )
            ) AS periods_list
        FROM paginated_base pb
    ),
    student_enriched AS (
        SELECT 
            sp.*,
            (SELECT COUNT(*) FROM jsonb_array_elements(sp.periods_list)) AS total_periods,
            (SELECT COUNT(*) FROM jsonb_array_elements(sp.periods_list) p WHERE p->>'status' NOT IN ('NOT_MARKED', 'RESET', '')) AS marked_periods,
            (SELECT COUNT(*) FROM jsonb_array_elements(sp.periods_list) p WHERE p->>'status' = 'PRESENT') AS present_count,
            (SELECT COUNT(*) FROM jsonb_array_elements(sp.periods_list) p WHERE p->>'status' = 'ABSENT') AS absent_count,
            (SELECT COUNT(*) FROM jsonb_array_elements(sp.periods_list) p WHERE p->>'status' = 'LATE') AS late_count,
            (SELECT COUNT(*) FROM jsonb_array_elements(sp.periods_list) p WHERE p->>'status' = 'ON_LEAVE') AS on_leave_count,
            (SELECT COUNT(*) FROM jsonb_array_elements(sp.periods_list) p WHERE p->>'status' = 'HALF_DAY') AS half_day_count
        FROM student_periods_computed sp
    ),
    final_roster AS (
        SELECT 
            se.student_id,
            se.roll_number,
            se.admission_number,
            se.full_name,
            se.avatar_url,
            se.class_id,
            se.class_name,
            se.section_id,
            se.section_name,
            se.daily_record_id AS attendance_record_id,
            -- Effective Status Calculation using Mathematical Matrix
            CASE 
                WHEN se.daily_is_overridden = TRUE AND se.daily_status IS NOT NULL THEN se.daily_status
                WHEN se.has_approved_leave = TRUE AND se.marked_periods = 0 THEN 'ON_LEAVE'
                WHEN se.total_periods > 0 AND se.marked_periods > 0 THEN
                    public.fn_calculate_composite_attendance_status(
                        se.total_periods,
                        se.present_count,
                        se.absent_count,
                        se.late_count,
                        se.on_leave_count,
                        se.half_day_count,
                        se.marked_periods
                    )
                WHEN se.daily_is_locked = TRUE AND se.daily_status IS NOT NULL THEN se.daily_status
                WHEN se.has_approved_leave = TRUE THEN 'ON_LEAVE'
                ELSE COALESCE(se.daily_status, 'NOT_MARKED')
            END AS status,
            COALESCE(
                (
                    SELECT p->>'status' 
                    FROM jsonb_array_elements(se.periods_list) p 
                    WHERE (p->>'period_number')::INT = COALESCE(p_period_number, 1) 
                    LIMIT 1
                ),
                CASE WHEN se.has_approved_leave = TRUE THEN 'ON_LEAVE' ELSE 'NOT_MARKED' END
            ) AS active_period_status,
            CASE
                WHEN se.daily_remarks IS NOT NULL AND se.daily_remarks != '' THEN se.daily_remarks
                WHEN se.has_approved_leave = TRUE THEN COALESCE(se.leave_reason, 'Approved Leave')
                ELSE ''
            END AS remarks,
            (se.daily_is_locked OR se.has_approved_leave) AS is_locked,
            (se.daily_is_locked OR se.has_approved_leave) AS locked_by_all_day,
            se.daily_is_overridden AS is_overridden,
            se.daily_override_reason AS override_reason,
            se.has_approved_leave,
            se.leave_reason,
            se.daily_updated_at AS last_updated_at,
            se.daily_updated_by_name AS updated_by_name,
            se.periods_list AS periods,
            jsonb_build_object(
                'total_periods', se.total_periods,
                'marked_periods', se.marked_periods,
                'not_marked_count', (se.total_periods - se.marked_periods),
                'present_count', se.present_count,
                'absent_count', se.absent_count,
                'late_count', se.late_count,
                'on_leave_count', se.on_leave_count,
                'half_day_count', se.half_day_count
            ) AS periods_summary
        FROM student_enriched se
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', student_id,
                'student_id', student_id,
                'roll_number', roll_number,
                'admission_number', admission_number,
                'full_name', full_name,
                'avatar_url', avatar_url,
                'class_id', class_id,
                'class_name', class_name,
                'section_id', section_id,
                'section_name', section_name,
                'attendance_record_id', attendance_record_id,
                'status', status,
                'remarks', remarks,
                'is_locked', is_locked,
                'locked_by_all_day', locked_by_all_day,
                'is_overridden', is_overridden,
                'override_reason', override_reason,
                'has_approved_leave', has_approved_leave,
                'leave_reason', leave_reason,
                'last_updated_at', last_updated_at,
                'updated_by_name', updated_by_name,
                'periods', periods,
                'periods_summary', periods_summary
            ) ORDER BY 
                CASE WHEN roll_number ~ '^[0-9]+$' THEN roll_number::INT ELSE 9999 END ASC,
                full_name ASC
        ),
        '[]'::JSONB
    ) INTO v_students
    FROM final_roster;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'students', v_students,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1)),
            'is_locked_all_day', v_is_locked_all_day,
            'locked_at', v_locked_at,
            'locked_by_name', v_locked_by_name,
            'schedules', v_schedules_json
        )
    );
END;
$$;
