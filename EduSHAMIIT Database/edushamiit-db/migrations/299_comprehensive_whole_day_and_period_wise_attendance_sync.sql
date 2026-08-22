-- ============================================================================
-- Migration: 299_comprehensive_whole_day_and_period_wise_attendance_sync.sql
-- Description:
--   1. Full bidirectional sync between Whole-Day attendance and Period-Wise attendance:
--      - If marked for Whole Day: all scheduled periods are automatically marked and locked.
--      - If marked for a particular period: user can still mark for Whole Day if not all
--        periods are completed yet.
--      - If all periods for that day are marked: Whole-Day attendance is automatically completed.
--   2. Updates fn_get_daily_attendance_roster to seamlessly display effective status
--      and lock states across ALL_DAY, PERIOD, and MULTI_SCHEDULE modes.
--   3. Updates fn_get_attendance_dashboard_stats to reflect live period-wise & daily attendance.
-- ============================================================================

-- 1. FUNCTION: fn_get_attendance_dashboard_stats (Period & Daily Aware)
CREATE OR REPLACE FUNCTION public.fn_get_attendance_dashboard_stats(
    p_school_id UUID,
    p_date DATE,
    p_class_id UUID DEFAULT NULL,
    p_section_id UUID DEFAULT NULL,
    p_teacher_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_students INT := 0;
    v_present INT := 0;
    v_absent INT := 0;
    v_late INT := 0;
    v_on_leave INT := 0;
    v_half_day INT := 0;
    v_not_marked INT := 0;
    v_pct NUMERIC := 0.0;
    v_day_summary JSONB;
BEGIN
    -- 1. Total Active Students Count
    SELECT COUNT(DISTINCT sca.student_id) INTO v_total_students
    FROM public.student_class_assignments sca
    JOIN public.profiles p ON p.id = sca.student_id AND (p.status IS NULL OR p.status != 'Deleted')
    WHERE sca.school_id = p_school_id
      AND sca.status = 'ACTIVE'
      AND (p_class_id IS NULL OR sca.class_id = p_class_id)
      AND (p_section_id IS NULL OR sca.section_id = p_section_id)
      AND (
          p_teacher_id IS NULL
          OR EXISTS (
              SELECT 1 FROM public.class_teacher_assignments cta
              WHERE cta.teacher_id = p_teacher_id
                AND cta.class_id = sca.class_id
                AND (cta.section_id = sca.section_id OR cta.section_id IS NULL)
          )
      );

    -- 2. Determine Effective Daily Status per Active Student
    WITH active_students AS (
        SELECT DISTINCT ON (sca.student_id)
            sca.student_id,
            sca.class_id,
            sca.section_id
        FROM public.student_class_assignments sca
        JOIN public.profiles p ON p.id = sca.student_id AND (p.status IS NULL OR p.status != 'Deleted')
        WHERE sca.school_id = p_school_id
          AND sca.status = 'ACTIVE'
          AND (p_class_id IS NULL OR sca.class_id = p_class_id)
          AND (p_section_id IS NULL OR sca.section_id = p_section_id)
    ),
    student_effective_status AS (
        SELECT 
            ast.student_id,
            CASE 
                -- 1. Check daily attendance record first
                WHEN adr.id IS NOT NULL AND adr.status IS NOT NULL AND adr.status != 'NOT_MARKED' THEN UPPER(adr.status)
                -- 2. Fall back to latest period attendance record
                WHEN apr.id IS NOT NULL AND apr.status IS NOT NULL AND apr.status != 'NOT_MARKED' THEN UPPER(apr.status)
                -- 3. Check approved leave
                WHEN EXISTS (
                    SELECT 1 FROM public.leave_applications la 
                    WHERE la.applicant_id = ast.student_id 
                      AND la.status = 'approved' 
                      AND p_date BETWEEN la.start_date AND la.end_date
                ) THEN 'ON_LEAVE'
                ELSE 'NOT_MARKED'
            END AS status
        FROM active_students ast
        LEFT JOIN public.attendance_daily_records adr ON adr.school_id = p_school_id
             AND adr.student_id = ast.student_id
             AND adr.attendance_date = p_date
        LEFT JOIN LATERAL (
            SELECT status, id 
            FROM public.attendance_period_records 
            WHERE school_id = p_school_id 
              AND student_id = ast.student_id 
              AND attendance_date = p_date
            ORDER BY updated_at DESC 
            LIMIT 1
        ) apr ON TRUE
    )
    SELECT
        COUNT(CASE WHEN status = 'PRESENT' THEN 1 END),
        COUNT(CASE WHEN status = 'ABSENT' THEN 1 END),
        COUNT(CASE WHEN status = 'LATE' THEN 1 END),
        COUNT(CASE WHEN status = 'ON_LEAVE' THEN 1 END),
        COUNT(CASE WHEN status = 'HALF_DAY' THEN 1 END)
    INTO v_present, v_absent, v_late, v_on_leave, v_half_day
    FROM student_effective_status;

    v_not_marked := GREATEST(0, v_total_students - (v_present + v_absent + v_late + v_on_leave + v_half_day));

    IF v_total_students > 0 THEN
        v_pct := ROUND(((v_present + v_late + (v_half_day * 0.5))::NUMERIC / v_total_students::NUMERIC) * 100.0, 1);
    ELSE
        v_pct := 0.0;
    END IF;

    v_day_summary := jsonb_build_object(
        'total_students', v_total_students,
        'marked_students', (v_present + v_absent + v_late + v_on_leave + v_half_day),
        'not_marked', v_not_marked,
        'present', v_present,
        'absent', v_absent,
        'late', v_late,
        'on_leave', v_on_leave,
        'half_day', v_half_day,
        'attendance_percentage', v_pct
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'overall_attendance_pct', v_pct,
            'total_students', v_total_students,
            'students_present', v_present,
            'students_absent', v_absent,
            'late_entries', v_late,
            'on_leave', v_on_leave,
            'half_day', v_half_day,
            'not_marked', v_not_marked,
            'day_summary', v_day_summary
        )
    );
END;
$$;


-- 2. FUNCTION: fn_get_daily_attendance_roster (Seamless Period & Whole Day Status Resolution)
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
BEGIN
    v_offset := (p_page - 1) * p_page_size;

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

    -- 2. Build Paginated Roster
    WITH eligible_students AS (
        SELECT DISTINCT ON (sca.student_id)
            sca.student_id,
            sca.roll_number,
            sca.class_id,
            sca.section_id,
            p.full_name,
            p.avatar_url,
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
        ORDER BY sca.student_id, sca.assigned_at DESC NULLS LAST
    ),
    paginated_roster AS (
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
            CASE 
                WHEN v_mode_norm = 'ALL_DAY' THEN adr.id 
                ELSE COALESCE(apr.id, adr.id) 
            END AS attendance_record_id,
            CASE 
                WHEN v_mode_norm = 'ALL_DAY' THEN COALESCE(adr.status, 'NOT_MARKED')
                -- If in period mode and a period record exists, use it;
                -- If no period record exists but daily attendance was marked for whole day, use whole day status
                ELSE COALESCE(apr.status, CASE WHEN adr.is_locked = TRUE THEN adr.status ELSE 'NOT_MARKED' END)
            END AS effective_status,
            CASE 
                WHEN v_mode_norm = 'ALL_DAY' THEN COALESCE(adr.remarks, '')
                ELSE COALESCE(apr.remarks, adr.remarks, '')
            END AS remarks,
            CASE 
                WHEN v_mode_norm = 'ALL_DAY' THEN COALESCE(adr.is_locked, FALSE)
                -- In period mode, if period record is locked OR whole day was locked, is_locked = true
                ELSE (COALESCE(apr.is_locked, FALSE) OR COALESCE(adr.is_locked, FALSE))
            END AS is_locked,
            (COALESCE(apr.locked_by_all_day, FALSE) OR (apr.id IS NULL AND COALESCE(adr.is_locked, FALSE))) AS locked_by_all_day,
            CASE 
                WHEN v_mode_norm = 'ALL_DAY' THEN COALESCE(adr.is_overridden, FALSE)
                ELSE COALESCE(apr.is_overridden, adr.is_overridden, FALSE)
            END AS is_overridden,
            CASE 
                WHEN v_mode_norm = 'ALL_DAY' THEN adr.override_reason
                ELSE COALESCE(apr.override_reason, adr.override_reason)
            END AS override_reason,
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
                LIMIT 1
            ) AS leave_reason,
            CASE 
                WHEN v_mode_norm = 'ALL_DAY' THEN adr.updated_at
                ELSE COALESCE(apr.updated_at, adr.updated_at)
            END AS last_updated_at,
            (
                SELECT prof.full_name FROM public.profiles prof 
                WHERE prof.id = CASE WHEN v_mode_norm = 'ALL_DAY' THEN adr.updated_by ELSE COALESCE(apr.updated_by, adr.updated_by) END
            ) AS updated_by_name
        FROM eligible_students es
        LEFT JOIN public.academic_classes c ON c.id = es.class_id
        LEFT JOIN public.academic_sections s ON s.id = es.section_id
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
        ORDER BY 
            CASE WHEN es.roll_number ~ '^[0-9]+$' THEN es.roll_number::INT ELSE 9999 END ASC,
            es.full_name ASC
        LIMIT p_page_size
        OFFSET v_offset
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', COALESCE(attendance_record_id, student_id),
                'student_id', student_id,
                'attendance_record_id', attendance_record_id,
                'full_name', full_name,
                'avatar_url', avatar_url,
                'roll_number', COALESCE(roll_number, ''),
                'admission_number', COALESCE(admission_number, ''),
                'class_id', class_id,
                'class_name', class_name,
                'section_id', section_id,
                'section_name', section_name,
                'status', effective_status,
                'remarks', remarks,
                'is_locked', is_locked,
                'locked_by_all_day', locked_by_all_day,
                'is_overridden', is_overridden,
                'override_reason', override_reason,
                'has_approved_leave', has_approved_leave,
                'leave_reason', leave_reason,
                'last_updated_at', last_updated_at,
                'updated_by_name', updated_by_name
            )
        ),
        '[]'::JSONB
    ) INTO v_students
    FROM paginated_roster;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'students', v_students,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::FLOAT / GREATEST(p_page_size, 1)),
            'is_locked_all_day', v_is_locked_all_day,
            'locked_at', v_locked_at,
            'locked_by_name', v_locked_by_name
        )
    );
END;
$$;


-- 3. FUNCTION: fn_save_daily_attendance (Complete Whole-Day & Period-Wise Bidirectional Sync)
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
    v_period_number INT;
    v_subject_id UUID;
    v_schedule_id UUID;
    v_selected_periods JSONB;
    v_period_item JSONB;
    v_selected_sched_ids JSONB;
    v_total_sched_count INT := 0;
    v_student_marked_periods INT := 0;
    v_distinct_statuses TEXT[];
    v_composite_daily_status VARCHAR;
BEGIN
    v_date := (p_payload->>'attendance_date')::DATE;
    v_class_id := (p_payload->>'class_id')::UUID;
    v_section_id := (p_payload->>'section_id')::UUID;
    v_mode := UPPER(COALESCE(p_payload->>'mode', 'ALL_DAY'));
    v_records := COALESCE(p_payload->'records', '[]'::JSONB);
    v_period_number := (p_payload->>'period_number')::INT;
    v_subject_id := (p_payload->>'subject_id')::UUID;
    v_schedule_id := (p_payload->>'schedule_id')::UUID;
    v_selected_periods := COALESCE(p_payload->'selected_periods', '[]'::JSONB);
    v_selected_sched_ids := COALESCE(p_payload->'selected_schedule_ids', '[]'::JSONB);

    IF v_date IS NULL OR v_class_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'attendance_date and class_id are required', 'code', 400);
    END IF;

    -- Count total scheduled academic periods for this class/section on this date
    SELECT COALESCE(jsonb_array_length(public.fn_get_class_academic_periods_for_date(p_school_id, v_date, v_class_id, v_section_id)->'data'->'schedules'), 0)
    INTO v_total_sched_count;

    -- =========================================================================
    -- MODE 1: ALL DAY ATTENDANCE
    -- Marks & locks Whole-Day + automatically marks & locks all periods of the day
    -- =========================================================================
    IF v_mode = 'ALL_DAY' THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_records) LOOP
            v_student_id := (v_item->>'student_id')::UUID;
            v_status := UPPER(TRIM(COALESCE(v_item->>'status', 'PRESENT')));
            v_remarks := TRIM(COALESCE(v_item->>'remarks', ''));

            IF v_student_id IS NOT NULL THEN
                -- Upsert Master Daily Record
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
                    updated_at = NOW()
                RETURNING id INTO v_daily_id;

                -- Delete existing period records for this student and date to cleanly overwrite
                DELETE FROM public.attendance_period_records
                WHERE school_id = p_school_id
                  AND student_id = v_student_id
                  AND attendance_date = v_date;

                -- Propagate to all resolved Academic Calendar periods for today with is_locked = TRUE and locked_by_all_day = TRUE
                FOR v_sched IN 
                    SELECT 
                        (elem->>'period_number')::INT AS p_num,
                        (elem->>'subject_id')::UUID AS sub_id,
                        (elem->>'schedule_id')::UUID AS s_id
                    FROM jsonb_array_elements(
                        (public.fn_get_class_academic_periods_for_date(p_school_id, v_date, v_class_id, v_section_id)->'data'->'schedules')
                    ) elem
                LOOP
                    INSERT INTO public.attendance_period_records (
                        school_id, daily_record_id, student_id, class_id, section_id,
                        subject_id, schedule_id, attendance_date, period_number, status, remarks,
                        is_locked, locked_by_all_day, created_by, updated_by, updated_at
                    ) VALUES (
                        p_school_id, v_daily_id, v_student_id, v_class_id, v_section_id,
                        v_sched.sub_id, v_sched.s_id, v_date, v_sched.p_num, v_status, v_remarks,
                        TRUE, TRUE, p_user_id, p_user_id, NOW()
                    );
                END LOOP;

                v_saved_count := v_saved_count + 1;
            END IF;
        END LOOP;

    -- =========================================================================
    -- MODE 2: CUSTOM SELECTION (Multi-Period Attendance)
    -- =========================================================================
    ELSIF v_mode IN ('MULTI_SCHEDULE', 'CUSTOM_SELECTION') THEN
        -- If selected_periods is empty but selected_schedule_ids is present, resolve period details
        IF jsonb_array_length(v_selected_periods) = 0 AND jsonb_array_length(v_selected_sched_ids) > 0 THEN
            SELECT jsonb_agg(elem) INTO v_selected_periods
            FROM jsonb_array_elements(
                (public.fn_get_class_academic_periods_for_date(p_school_id, v_date, v_class_id, v_section_id)->'data'->'schedules')
            ) elem
            WHERE elem->>'id' = ANY(ARRAY(SELECT jsonb_array_elements_text(v_selected_sched_ids)))
               OR elem->>'schedule_id' = ANY(ARRAY(SELECT jsonb_array_elements_text(v_selected_sched_ids)));
        END IF;

        -- For each selected period, apply student attendance
        IF v_selected_periods IS NOT NULL AND jsonb_array_length(v_selected_periods) > 0 THEN
            FOR v_period_item IN SELECT * FROM jsonb_array_elements(v_selected_periods) LOOP
                v_period_number := COALESCE((v_period_item->>'period_number')::INT, 1);
                v_subject_id := (v_period_item->>'subject_id')::UUID;
                v_schedule_id := (v_period_item->>'schedule_id')::UUID;

                FOR v_item IN SELECT * FROM jsonb_array_elements(v_records) LOOP
                    v_student_id := (v_item->>'student_id')::UUID;
                    v_status := UPPER(TRIM(COALESCE(v_item->>'status', 'PRESENT')));
                    v_remarks := TRIM(COALESCE(v_item->>'remarks', ''));

                    IF v_student_id IS NOT NULL THEN
                        -- Clean up any existing period record for this specific period/subject
                        DELETE FROM public.attendance_period_records
                        WHERE school_id = p_school_id
                          AND student_id = v_student_id
                          AND attendance_date = v_date
                          AND period_number = v_period_number
                          AND (
                              (v_schedule_id IS NOT NULL AND schedule_id = v_schedule_id)
                              OR (v_subject_id IS NULL OR subject_id = v_subject_id)
                          );

                        INSERT INTO public.attendance_period_records (
                            school_id, student_id, class_id, section_id,
                            subject_id, schedule_id, attendance_date, period_number, status, remarks,
                            is_locked, locked_by_all_day, created_by, updated_by, updated_at
                        ) VALUES (
                            p_school_id, v_student_id, v_class_id, v_section_id,
                            v_subject_id, v_schedule_id, v_date, v_period_number, v_status, v_remarks,
                            FALSE, FALSE, p_user_id, p_user_id, NOW()
                        );
                    END IF;
                END LOOP;
            END LOOP;
            v_saved_count := jsonb_array_length(v_records);
        END IF;

        -- Check auto-completion of Whole Day attendance for each student
        FOR v_item IN SELECT * FROM jsonb_array_elements(v_records) LOOP
            v_student_id := (v_item->>'student_id')::UUID;
            IF v_student_id IS NOT NULL THEN
                SELECT COUNT(DISTINCT period_number) INTO v_student_marked_periods
                FROM public.attendance_period_records
                WHERE school_id = p_school_id
                  AND student_id = v_student_id
                  AND attendance_date = v_date
                  AND status != 'NOT_MARKED';

                -- If all scheduled periods for this date have been marked, auto-complete Whole Day attendance
                IF v_total_sched_count > 0 AND v_student_marked_periods >= v_total_sched_count THEN
                    SELECT ARRAY_AGG(DISTINCT status) INTO v_distinct_statuses
                    FROM public.attendance_period_records
                    WHERE school_id = p_school_id AND student_id = v_student_id AND attendance_date = v_date;

                    IF 'ABSENT' = ANY(v_distinct_statuses) THEN
                        v_composite_daily_status := 'ABSENT';
                    ELSIF 'ON_LEAVE' = ANY(v_distinct_statuses) THEN
                        v_composite_daily_status := 'ON_LEAVE';
                    ELSIF 'HALF_DAY' = ANY(v_distinct_statuses) THEN
                        v_composite_daily_status := 'HALF_DAY';
                    ELSIF 'LATE' = ANY(v_distinct_statuses) THEN
                        v_composite_daily_status := 'LATE';
                    ELSE
                        v_composite_daily_status := 'PRESENT';
                    END IF;

                    INSERT INTO public.attendance_daily_records (
                        school_id, student_id, class_id, section_id, attendance_date,
                        status, remarks, is_locked, locked_by, locked_at, is_all_day,
                        created_by, updated_by, updated_at
                    ) VALUES (
                        p_school_id, v_student_id, v_class_id, v_section_id, v_date,
                        v_composite_daily_status, 'Auto-completed from period attendance', TRUE, p_user_id, NOW(), TRUE,
                        p_user_id, p_user_id, NOW()
                    )
                    ON CONFLICT (school_id, student_id, attendance_date) DO UPDATE SET
                        status = EXCLUDED.status,
                        is_locked = TRUE,
                        locked_by = EXCLUDED.locked_by,
                        locked_at = EXCLUDED.locked_at,
                        is_all_day = TRUE,
                        updated_by = EXCLUDED.updated_by,
                        updated_at = NOW();
                END IF;
            END IF;
        END LOOP;

    -- =========================================================================
    -- MODE 3: SINGLE PERIOD ATTENDANCE
    -- =========================================================================
    ELSE
        v_period_number := COALESCE((p_payload->>'period_number')::INT, 1);
        v_subject_id := (p_payload->>'subject_id')::UUID;
        v_schedule_id := (p_payload->>'schedule_id')::UUID;

        FOR v_item IN SELECT * FROM jsonb_array_elements(v_records) LOOP
            v_student_id := (v_item->>'student_id')::UUID;
            v_status := UPPER(TRIM(COALESCE(v_item->>'status', 'PRESENT')));
            v_remarks := TRIM(COALESCE(v_item->>'remarks', ''));
            v_period_number := COALESCE((v_item->>'period_number')::INT, v_period_number, 1);
            v_subject_id := COALESCE((v_item->>'subject_id')::UUID, v_subject_id);

            IF v_student_id IS NOT NULL THEN
                DELETE FROM public.attendance_period_records
                WHERE school_id = p_school_id
                  AND student_id = v_student_id
                  AND attendance_date = v_date
                  AND period_number = v_period_number
                  AND (
                      (v_schedule_id IS NOT NULL AND schedule_id = v_schedule_id)
                      OR (v_subject_id IS NULL OR subject_id = v_subject_id)
                  );

                INSERT INTO public.attendance_period_records (
                    school_id, student_id, class_id, section_id,
                    subject_id, schedule_id, attendance_date, period_number, status, remarks,
                    is_locked, locked_by_all_day, created_by, updated_by, updated_at
                ) VALUES (
                    p_school_id, v_student_id, v_class_id, v_section_id,
                    v_subject_id, v_schedule_id, v_date, v_period_number, v_status, v_remarks,
                    FALSE, FALSE, p_user_id, p_user_id, NOW()
                );

                -- Check if all periods are now complete for this student
                SELECT COUNT(DISTINCT period_number) INTO v_student_marked_periods
                FROM public.attendance_period_records
                WHERE school_id = p_school_id
                  AND student_id = v_student_id
                  AND attendance_date = v_date
                  AND status != 'NOT_MARKED';

                IF v_total_sched_count > 0 AND v_student_marked_periods >= v_total_sched_count THEN
                    SELECT ARRAY_AGG(DISTINCT status) INTO v_distinct_statuses
                    FROM public.attendance_period_records
                    WHERE school_id = p_school_id AND student_id = v_student_id AND attendance_date = v_date;

                    IF 'ABSENT' = ANY(v_distinct_statuses) THEN
                        v_composite_daily_status := 'ABSENT';
                    ELSIF 'ON_LEAVE' = ANY(v_distinct_statuses) THEN
                        v_composite_daily_status := 'ON_LEAVE';
                    ELSIF 'HALF_DAY' = ANY(v_distinct_statuses) THEN
                        v_composite_daily_status := 'HALF_DAY';
                    ELSIF 'LATE' = ANY(v_distinct_statuses) THEN
                        v_composite_daily_status := 'LATE';
                    ELSE
                        v_composite_daily_status := 'PRESENT';
                    END IF;

                    INSERT INTO public.attendance_daily_records (
                        school_id, student_id, class_id, section_id, attendance_date,
                        status, remarks, is_locked, locked_by, locked_at, is_all_day,
                        created_by, updated_by, updated_at
                    ) VALUES (
                        p_school_id, v_student_id, v_class_id, v_section_id, v_date,
                        v_composite_daily_status, 'Auto-completed from period attendance', TRUE, p_user_id, NOW(), TRUE,
                        p_user_id, p_user_id, NOW()
                    )
                    ON CONFLICT (school_id, student_id, attendance_date) DO UPDATE SET
                        status = EXCLUDED.status,
                        is_locked = TRUE,
                        locked_by = EXCLUDED.locked_by,
                        locked_at = EXCLUDED.locked_at,
                        is_all_day = TRUE,
                        updated_by = EXCLUDED.updated_by,
                        updated_at = NOW();
                END IF;

                v_saved_count := v_saved_count + 1;
            END IF;
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', CASE 
            WHEN v_mode = 'ALL_DAY' THEN 'All-day attendance saved and applied to all schedules' 
            WHEN v_mode IN ('MULTI_SCHEDULE', 'CUSTOM_SELECTION') THEN 'Attendance saved across all selected periods'
            ELSE 'Period attendance saved' 
        END,
        'saved_count', v_saved_count,
        'mode', v_mode
    );
END;
$$;
