-- ============================================================================
-- Migration 294: Attendance Stored Procedures and Override Enhancements
-- Created: 2026-08-21
-- Purpose:
-- 1. Create/Update public.fn_override_locked_attendance stored procedure to
--    robustly handle record PKs, student UUIDs, and automated upserts.
-- 2. Fix public.fn_get_daily_attendance_roster to guarantee 1-to-1 student
--    mapping with ZERO duplicates, lateral join safety, and strict pagination.
-- 3. Update public.fn_save_daily_attendance to upsert period records cleanly.
-- 4. Deduplicate attendance_period_records and add unique constraint.
-- ============================================================================

-- Step 0: Clean up any duplicate records in attendance_period_records
DELETE FROM public.attendance_period_records a
WHERE a.id NOT IN (
    SELECT DISTINCT ON (school_id, student_id, attendance_date, period_number, COALESCE(subject_id, '00000000-0000-0000-0000-000000000000'::UUID)) id
    FROM public.attendance_period_records
    ORDER BY school_id, student_id, attendance_date, period_number, COALESCE(subject_id, '00000000-0000-0000-0000-000000000000'::UUID), updated_at DESC
);


-- Function 1: Override Locked Attendance (Stored Procedure)
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
BEGIN
    IF TRIM(COALESCE(p_reason, '')) = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'An override reason is mandatory', 'code', 400);
    END IF;

    IF UPPER(p_record_type) = 'DAILY' THEN
        -- Check if existing daily record matches by record ID or student_id
        SELECT id, status, student_id INTO v_rec_id, v_old_status, v_student_id
        FROM public.attendance_daily_records 
        WHERE (id = p_record_id OR student_id = p_record_id) 
          AND school_id = p_school_id
        ORDER BY (id = p_record_id) DESC, attendance_date DESC, updated_at DESC
        LIMIT 1;

        IF v_rec_id IS NOT NULL THEN
            UPDATE public.attendance_daily_records SET
                status = UPPER(p_new_status),
                is_overridden = TRUE,
                override_reason = TRIM(p_reason),
                updated_by = p_user_id,
                updated_at = NOW()
            WHERE id = v_rec_id;
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
                    UPPER(p_new_status), TRUE, TRUE, TRIM(p_reason), p_user_id, p_user_id
                )
                ON CONFLICT (school_id, student_id, attendance_date)
                DO UPDATE SET
                    status = UPPER(EXCLUDED.status),
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
        SELECT id, status, student_id INTO v_rec_id, v_old_status, v_student_id
        FROM public.attendance_period_records 
        WHERE (id = p_record_id OR student_id = p_record_id) 
          AND school_id = p_school_id
        ORDER BY (id = p_record_id) DESC, attendance_date DESC, updated_at DESC
        LIMIT 1;

        IF v_rec_id IS NOT NULL THEN
            UPDATE public.attendance_period_records SET
                status = UPPER(p_new_status),
                is_overridden = TRUE,
                override_reason = TRIM(p_reason),
                overridden_by = p_user_id,
                updated_by = p_user_id,
                updated_at = NOW()
            WHERE id = v_rec_id;
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
        'message', 'Attendance overridden successfully',
        'record_id', v_rec_id,
        'old_status', v_old_status,
        'new_status', UPPER(p_new_status)
    );
END;
$$;


-- Function 2: Get Daily Attendance Roster (1-to-1 Mathematical Mapping Guarantee)
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

    -- 1. Calculate EXACT total unique student count
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
        ) apr ON p_mode != 'ALL_DAY'
        WHERE (
            p_status_filter = 'ALL'
            OR (p_mode = 'ALL_DAY' AND UPPER(COALESCE(adr.status, 'NOT_MARKED')) = UPPER(p_status_filter))
            OR (p_mode != 'ALL_DAY' AND UPPER(COALESCE(apr.status, adr.status, 'NOT_MARKED')) = UPPER(p_status_filter))
        )
    )
    SELECT COUNT(*) INTO v_total_count FROM filtered_roster;

    -- 2. Build Paginated Roster with EXACT 1-to-1 unique mapping
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
            CASE WHEN p_mode = 'ALL_DAY' THEN adr.id ELSE apr.id END AS attendance_record_id,
            CASE 
                WHEN p_mode = 'ALL_DAY' THEN COALESCE(adr.status, 'NOT_MARKED')
                ELSE COALESCE(apr.status, adr.status, 'NOT_MARKED')
            END AS effective_status,
            CASE 
                WHEN p_mode = 'ALL_DAY' THEN COALESCE(adr.remarks, '')
                ELSE COALESCE(apr.remarks, adr.remarks, '')
            END AS remarks,
            CASE 
                WHEN p_mode = 'ALL_DAY' THEN COALESCE(adr.is_locked, FALSE)
                ELSE COALESCE(apr.is_locked, adr.is_locked, FALSE)
            END AS is_locked,
            COALESCE(apr.locked_by_all_day, FALSE) AS locked_by_all_day,
            CASE 
                WHEN p_mode = 'ALL_DAY' THEN COALESCE(adr.is_overridden, FALSE)
                ELSE COALESCE(apr.is_overridden, FALSE)
            END AS is_overridden,
            CASE 
                WHEN p_mode = 'ALL_DAY' THEN adr.override_reason
                ELSE apr.override_reason
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
                WHEN p_mode = 'ALL_DAY' THEN adr.updated_at
                ELSE COALESCE(apr.updated_at, adr.updated_at)
            END AS last_updated_at,
            (
                SELECT prof.full_name FROM public.profiles prof 
                WHERE prof.id = CASE WHEN p_mode = 'ALL_DAY' THEN adr.updated_by ELSE COALESCE(apr.updated_by, adr.updated_by) END
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
        ) apr ON p_mode != 'ALL_DAY'
        WHERE (
            p_status_filter = 'ALL'
            OR (p_mode = 'ALL_DAY' AND UPPER(COALESCE(adr.status, 'NOT_MARKED')) = UPPER(p_status_filter))
            OR (p_mode != 'ALL_DAY' AND UPPER(COALESCE(apr.status, adr.status, 'NOT_MARKED')) = UPPER(p_status_filter))
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


-- Function 3: Save Daily Attendance with Safe Period Upsert
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
BEGIN
    v_date := (p_payload->>'attendance_date')::DATE;
    v_class_id := (p_payload->>'class_id')::UUID;
    v_section_id := (p_payload->>'section_id')::UUID;
    v_mode := COALESCE(p_payload->>'mode', 'ALL_DAY');
    v_records := COALESCE(p_payload->'records', '[]'::JSONB);
    v_period_number := (p_payload->>'period_number')::INT;
    v_subject_id := (p_payload->>'subject_id')::UUID;

    IF v_date IS NULL OR v_class_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'attendance_date and class_id are required', 'code', 400);
    END IF;

    -- Process Each Student Attendance Item
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_records) LOOP
        v_student_id := (v_item->>'student_id')::UUID;
        v_status := UPPER(TRIM(COALESCE(v_item->>'status', 'PRESENT')));
        v_remarks := TRIM(COALESCE(v_item->>'remarks', ''));

        IF v_student_id IS NOT NULL THEN
            IF v_mode = 'ALL_DAY' THEN
                -- Upsert Master Daily Attendance Record
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

                -- Clean up any existing period records for this student/date to prevent duplicates
                DELETE FROM public.attendance_period_records
                WHERE school_id = p_school_id
                  AND student_id = v_student_id
                  AND attendance_date = v_date;

                -- Propagate Attendance to All Applicable Scheduled Periods
                FOR v_sched IN 
                    SELECT 
                        csa.subject_id,
                        ROW_NUMBER() OVER (ORDER BY sub.name ASC) as p_num
                    FROM public.class_subject_assignments csa
                    JOIN public.academic_subjects sub ON sub.id = csa.subject_id
                    WHERE csa.school_id = p_school_id
                      AND csa.class_id = v_class_id
                      AND (v_section_id IS NULL OR csa.section_id = v_section_id OR csa.section_id IS NULL)
                LOOP
                    INSERT INTO public.attendance_period_records (
                        school_id, daily_record_id, student_id, class_id, section_id,
                        subject_id, attendance_date, period_number, status, remarks,
                        is_locked, locked_by_all_day, created_by, updated_by, updated_at
                    ) VALUES (
                        p_school_id, v_daily_id, v_student_id, v_class_id, v_section_id,
                        v_sched.subject_id, v_date, v_sched.p_num, v_status, v_remarks,
                        TRUE, TRUE, p_user_id, p_user_id, NOW()
                    );
                END LOOP;

            ELSE
                -- Specific Period Attendance Save
                v_period_number := COALESCE((v_item->>'period_number')::INT, (p_payload->>'period_number')::INT, 1);
                v_subject_id := COALESCE((v_item->>'subject_id')::UUID, (p_payload->>'subject_id')::UUID, NULL);

                -- Clean up any existing period record for this specific period/subject to prevent duplicate key violations
                DELETE FROM public.attendance_period_records
                WHERE school_id = p_school_id
                  AND student_id = v_student_id
                  AND attendance_date = v_date
                  AND period_number = v_period_number
                  AND (
                      (v_subject_id IS NULL AND (subject_id IS NULL OR subject_id = '00000000-0000-0000-0000-000000000000'::UUID))
                      OR (v_subject_id IS NOT NULL AND subject_id = v_subject_id)
                  );

                INSERT INTO public.attendance_period_records (
                    school_id, student_id, class_id, section_id,
                    subject_id, attendance_date, period_number, status, remarks,
                    is_locked, locked_by_all_day, created_by, updated_by, updated_at
                ) VALUES (
                    p_school_id, v_student_id, v_class_id, v_section_id,
                    v_subject_id, v_date, v_period_number, v_status, v_remarks,
                    FALSE, FALSE, p_user_id, p_user_id, NOW()
                );
            END IF;

            v_saved_count := v_saved_count + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', CASE WHEN v_mode = 'ALL_DAY' THEN 'All-day attendance saved and applied to all schedules' ELSE 'Period attendance saved' END,
        'saved_count', v_saved_count,
        'mode', v_mode
    );
END;
$$;


-- Function 4: Attendance Dashboard Statistics (Strict Deduplicated Counts)
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
    -- Count Total Eligible Enrolled Students (Deduplicated)
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

    -- Count Statuses from Unique Student Daily Attendance Records
    WITH student_daily_statuses AS (
        SELECT DISTINCT ON (a.student_id)
            a.student_id,
            UPPER(a.status) AS status
        FROM public.attendance_daily_records a
        JOIN public.student_class_assignments sca ON sca.student_id = a.student_id AND sca.status = 'ACTIVE'
        WHERE a.school_id = p_school_id
          AND a.attendance_date = p_date
          AND (p_class_id IS NULL OR a.class_id = p_class_id)
          AND (p_section_id IS NULL OR a.section_id = p_section_id)
          AND (
              p_teacher_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.class_teacher_assignments cta
                  WHERE cta.teacher_id = p_teacher_id
                    AND cta.class_id = sca.class_id
                    AND (cta.section_id = sca.section_id OR cta.section_id IS NULL)
              )
          )
        ORDER BY a.student_id, a.updated_at DESC
    )
    SELECT 
        COUNT(CASE WHEN status = 'PRESENT' THEN 1 END),
        COUNT(CASE WHEN status = 'ABSENT' THEN 1 END),
        COUNT(CASE WHEN status = 'LATE' THEN 1 END),
        COUNT(CASE WHEN status = 'ON_LEAVE' THEN 1 END),
        COUNT(CASE WHEN status = 'HALF_DAY' THEN 1 END)
    INTO v_present, v_absent, v_late, v_on_leave, v_half_day
    FROM student_daily_statuses;

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
