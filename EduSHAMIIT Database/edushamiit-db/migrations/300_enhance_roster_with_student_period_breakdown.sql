-- ============================================================================
-- Migration: 300_enhance_roster_with_student_period_breakdown.sql
-- Description:
--   1. Enhances fn_get_daily_attendance_roster to compute and return a full
--      'periods' array and 'periods_summary' for every student in the roster.
--   2. Mathematically sound composite status calculation:
--      - All periods PRESENT -> PRESENT
--      - All periods ABSENT -> ABSENT
--      - All periods ON_LEAVE -> ON_LEAVE
--      - Some periods PRESENT + Some ABSENT / LEAVE -> HALF_DAY
--      - Partial periods marked -> PARTIAL_PERIODS
--   3. Adds public.fn_quick_mark_student_period to instantly mark a student's
--      attendance for an individual period.
-- ============================================================================

-- 1. FUNCTION: fn_quick_mark_student_period
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
    v_composite_daily_status VARCHAR;
BEGIN
    -- Resolve student's current class and section
    SELECT sca.class_id, sca.section_id INTO v_class_id, v_section_id
    FROM public.student_class_assignments sca
    WHERE sca.school_id = p_school_id AND sca.student_id = p_student_id AND sca.status = 'ACTIVE'
    LIMIT 1;

    IF v_class_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Active class assignment not found for student', 'code', 404);
    END IF;

    -- Delete any existing record for this period
    DELETE FROM public.attendance_period_records
    WHERE school_id = p_school_id
      AND student_id = p_student_id
      AND attendance_date = p_date
      AND period_number = p_period_number;

    -- Insert new period record if status != 'NOT_MARKED'
    IF v_status_norm != 'NOT_MARKED' THEN
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

    -- Count total scheduled periods for class/section
    SELECT COALESCE(jsonb_array_length(public.fn_get_class_academic_periods_for_date(p_school_id, p_date, v_class_id, v_section_id)->'data'->'schedules'), 0)
    INTO v_total_sched_count;

    -- Count how many periods are now marked for this student
    SELECT COUNT(DISTINCT period_number) INTO v_student_marked_periods
    FROM public.attendance_period_records
    WHERE school_id = p_school_id
      AND student_id = p_student_id
      AND attendance_date = p_date
      AND status != 'NOT_MARKED';

    -- If all periods are marked, auto-complete whole-day attendance with mathematically accurate status
    IF v_total_sched_count > 0 AND v_student_marked_periods >= v_total_sched_count THEN
        SELECT 
            COUNT(*) FILTER (WHERE status = 'PRESENT'),
            COUNT(*) FILTER (WHERE status = 'ABSENT'),
            COUNT(*) FILTER (WHERE status = 'LATE'),
            COUNT(*) FILTER (WHERE status = 'ON_LEAVE'),
            COUNT(*) FILTER (WHERE status = 'HALF_DAY')
        INTO v_present_c, v_absent_c, v_late_c, v_leave_c, v_half_c
        FROM public.attendance_period_records
        WHERE school_id = p_school_id AND student_id = p_student_id AND attendance_date = p_date;

        IF v_absent_c = v_total_sched_count THEN
            v_composite_daily_status := 'ABSENT';
        ELSIF v_present_c = v_total_sched_count THEN
            v_composite_daily_status := 'PRESENT';
        ELSIF v_leave_c = v_total_sched_count THEN
            v_composite_daily_status := 'ON_LEAVE';
        ELSIF v_present_c > 0 AND (v_absent_c > 0 OR v_leave_c > 0 OR v_half_c > 0) THEN
            v_composite_daily_status := 'HALF_DAY';
        ELSIF v_half_c > 0 THEN
            v_composite_daily_status := 'HALF_DAY';
        ELSIF v_late_c > 0 THEN
            v_composite_daily_status := 'LATE';
        ELSE
            v_composite_daily_status := 'PRESENT';
        END IF;

        INSERT INTO public.attendance_daily_records (
            school_id, student_id, class_id, section_id, attendance_date,
            status, remarks, is_locked, locked_by, locked_at, is_all_day,
            created_by, updated_by, updated_at
        ) VALUES (
            p_school_id, p_student_id, v_class_id, v_section_id, p_date,
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


-- 2. FUNCTION: fn_get_daily_attendance_roster (Enhanced with Period Breakdown & Mathematical Composite Status)
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

    -- 2. Build Paginated Roster with Per-Student Period Breakdown
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
            -- Construct array of period objects using LATERAL subquery
            (
                SELECT COALESCE(
                    jsonb_agg(
                        jsonb_build_object(
                            'period_number', (s_elem->>'period_number')::INT,
                            'period_label', s_elem->>'period_label',
                            'subject_id', s_elem->>'subject_id',
                            'subject_name', s_elem->>'subject_name',
                            'subject_code', s_elem->>'subject_code',
                            'subject_color', s_elem->>'subject_color',
                            'schedule_id', s_elem->>'schedule_id',
                            'time_range', s_elem->>'time_range',
                            'teacher_name', s_elem->>'teacher_name',
                            'teacher_avatar', s_elem->>'teacher_avatar',
                            'status', CASE 
                                WHEN apr.id IS NOT NULL THEN UPPER(apr.status)
                                WHEN pb.daily_is_locked = TRUE THEN UPPER(pb.daily_status)
                                ELSE 'NOT_MARKED'
                            END,
                            'remarks', CASE 
                                WHEN apr.id IS NOT NULL THEN COALESCE(apr.remarks, '')
                                WHEN pb.daily_is_locked = TRUE THEN COALESCE(pb.daily_remarks, '')
                                ELSE ''
                            END,
                            'is_locked', (COALESCE(apr.is_locked, FALSE) OR pb.daily_is_locked),
                            'locked_by_all_day', (COALESCE(apr.locked_by_all_day, FALSE) OR (apr.id IS NULL AND pb.daily_is_locked)),
                            'is_overridden', (COALESCE(apr.is_overridden, FALSE) OR pb.daily_is_overridden),
                            'override_reason', COALESCE(apr.override_reason, pb.daily_override_reason),
                            'last_updated_at', COALESCE(apr.updated_at, pb.daily_updated_at),
                            'updated_by_name', COALESCE(
                                (SELECT prof.full_name FROM public.profiles prof WHERE prof.id = apr.updated_by),
                                pb.daily_updated_by_name
                            )
                        ) ORDER BY (s_elem->>'period_number')::INT ASC
                    ),
                    '[]'::JSONB
                )
                FROM jsonb_array_elements(v_schedules_json) s_elem
                LEFT JOIN LATERAL (
                    SELECT * FROM public.attendance_period_records a
                    WHERE a.school_id = p_school_id
                      AND a.student_id = pb.student_id
                      AND a.attendance_date = p_date
                      AND a.period_number = (s_elem->>'period_number')::INT
                    ORDER BY a.updated_at DESC
                    LIMIT 1
                ) apr ON TRUE
            ) AS periods_list
        FROM paginated_base pb
    ),
    student_enriched AS (
        SELECT 
            sp.*,
            -- Calculate count metrics from periods_list
            (SELECT COUNT(*) FROM jsonb_array_elements(sp.periods_list)) AS total_periods,
            (SELECT COUNT(*) FROM jsonb_array_elements(sp.periods_list) p WHERE p->>'status' != 'NOT_MARKED') AS marked_periods,
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
            -- Enhanced Effective Status Calculation
            CASE 
                WHEN v_mode_norm = 'ALL_DAY' THEN
                    CASE 
                        WHEN se.daily_is_locked = TRUE AND se.daily_status IS NOT NULL THEN se.daily_status
                        WHEN se.marked_periods > 0 AND se.marked_periods = se.total_periods THEN
                            CASE 
                                WHEN se.absent_count = se.total_periods THEN 'ABSENT'
                                WHEN se.present_count = se.total_periods THEN 'PRESENT'
                                WHEN se.on_leave_count = se.total_periods THEN 'ON_LEAVE'
                                WHEN se.present_count > 0 AND (se.absent_count > 0 OR se.on_leave_count > 0 OR se.half_day_count > 0) THEN 'HALF_DAY'
                                WHEN se.half_day_count > 0 THEN 'HALF_DAY'
                                WHEN se.late_count > 0 THEN 'LATE'
                                ELSE 'PRESENT'
                            END
                        WHEN se.marked_periods > 0 AND se.marked_periods < se.total_periods THEN 'PARTIAL_PERIODS'
                        ELSE 'NOT_MARKED'
                    END
                WHEN v_mode_norm = 'PERIOD' THEN
                    COALESCE(
                        (
                            SELECT p->>'status' 
                            FROM jsonb_array_elements(se.periods_list) p 
                            WHERE (p->>'period_number')::INT = COALESCE(p_period_number, 1) 
                            LIMIT 1
                        ),
                        'NOT_MARKED'
                    )
                ELSE -- MULTI_SCHEDULE / CUSTOM_SELECTION
                    CASE 
                        WHEN se.marked_periods > 0 AND se.marked_periods = se.total_periods THEN
                            CASE 
                                WHEN se.absent_count = se.total_periods THEN 'ABSENT'
                                WHEN se.present_count = se.total_periods THEN 'PRESENT'
                                WHEN se.on_leave_count = se.total_periods THEN 'ON_LEAVE'
                                WHEN se.present_count > 0 AND (se.absent_count > 0 OR se.on_leave_count > 0 OR se.half_day_count > 0) THEN 'HALF_DAY'
                                WHEN se.half_day_count > 0 THEN 'HALF_DAY'
                                WHEN se.late_count > 0 THEN 'LATE'
                                ELSE 'PRESENT'
                            END
                        WHEN se.marked_periods > 0 THEN 'PARTIAL_PERIODS'
                        ELSE 'NOT_MARKED'
                    END
            END AS effective_status,
            CASE 
                WHEN v_mode_norm = 'ALL_DAY' THEN COALESCE(se.daily_remarks, '')
                WHEN v_mode_norm = 'PERIOD' THEN COALESCE(
                    (SELECT p->>'remarks' FROM jsonb_array_elements(se.periods_list) p WHERE (p->>'period_number')::INT = COALESCE(p_period_number, 1) LIMIT 1),
                    se.daily_remarks, ''
                )
                ELSE COALESCE(se.daily_remarks, '')
            END AS remarks,
            CASE 
                WHEN v_mode_norm = 'ALL_DAY' THEN se.daily_is_locked
                WHEN v_mode_norm = 'PERIOD' THEN COALESCE(
                    (SELECT (p->>'is_locked')::BOOLEAN FROM jsonb_array_elements(se.periods_list) p WHERE (p->>'period_number')::INT = COALESCE(p_period_number, 1) LIMIT 1),
                    se.daily_is_locked
                )
                ELSE se.daily_is_locked
            END AS is_locked,
            CASE 
                WHEN v_mode_norm = 'ALL_DAY' THEN FALSE
                WHEN v_mode_norm = 'PERIOD' THEN COALESCE(
                    (SELECT (p->>'locked_by_all_day')::BOOLEAN FROM jsonb_array_elements(se.periods_list) p WHERE (p->>'period_number')::INT = COALESCE(p_period_number, 1) LIMIT 1),
                    se.daily_is_locked
                )
                ELSE se.daily_is_locked
            END AS locked_by_all_day,
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
                'updated_by_name', updated_by_name,
                'periods', periods,
                'periods_summary', periods_summary
            )
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
            'total_pages', CEIL(v_total_count::FLOAT / GREATEST(p_page_size, 1)),
            'is_locked_all_day', v_is_locked_all_day,
            'locked_at', v_locked_at,
            'locked_by_name', v_locked_by_name,
            'schedules', v_schedules_json
        )
    );
END;
$$;
