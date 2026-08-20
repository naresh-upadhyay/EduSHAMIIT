-- ============================================================================
-- Migration 270: Production-Ready Attendance Management System
-- Universal, multi-tenant, role-aware attendance architecture supporting:
-- 1. Student daily & period-level attendance
-- 2. Staff/employee attendance with manager hierarchy
-- 3. All-Day mode with automatic period propagation and atomic locking
-- 4. Locked schedule override workflow with audit history
-- 5. Leave integration (approved leave auto-sync & override warnings)
-- 6. Bulk operations, analytics/insights, and school settings
-- ============================================================================

-- Ensure helper profile columns exist
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS manager_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS department VARCHAR(100);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS designation VARCHAR(100);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS employee_id VARCHAR(50);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS admission_number VARCHAR(50);

-- 1. ATTENDANCE DAILY RECORDS (Master student attendance)
CREATE TABLE IF NOT EXISTS public.attendance_daily_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    class_id UUID REFERENCES public.academic_classes(id) ON DELETE SET NULL,
    section_id UUID REFERENCES public.academic_sections(id) ON DELETE SET NULL,
    attendance_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PRESENT', -- 'PRESENT', 'ABSENT', 'LATE', 'ON_LEAVE', 'HALF_DAY', 'NOT_MARKED'
    remarks TEXT,
    is_locked BOOLEAN DEFAULT FALSE,
    locked_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    locked_at TIMESTAMPTZ,
    is_all_day BOOLEAN DEFAULT TRUE,
    is_overridden BOOLEAN DEFAULT FALSE,
    override_reason TEXT,
    academic_year VARCHAR(20) DEFAULT '2026-27',
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_attendance_daily_student_date UNIQUE (school_id, student_id, attendance_date)
);

-- 2. ATTENDANCE PERIOD RECORDS (Period/schedule-level attendance)
CREATE TABLE IF NOT EXISTS public.attendance_period_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    daily_record_id UUID REFERENCES public.attendance_daily_records(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    class_id UUID REFERENCES public.academic_classes(id) ON DELETE SET NULL,
    section_id UUID REFERENCES public.academic_sections(id) ON DELETE SET NULL,
    schedule_id UUID,
    timetable_id UUID,
    subject_id UUID REFERENCES public.academic_subjects(id) ON DELETE SET NULL,
    attendance_date DATE NOT NULL,
    period_number INT NOT NULL DEFAULT 1,
    status VARCHAR(20) NOT NULL DEFAULT 'PRESENT',
    remarks TEXT,
    is_locked BOOLEAN DEFAULT FALSE,
    locked_by_all_day BOOLEAN DEFAULT FALSE,
    is_overridden BOOLEAN DEFAULT FALSE,
    override_reason TEXT,
    overridden_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. ATTENDANCE STAFF RECORDS (Employee / staff attendance)
CREATE TABLE IF NOT EXISTS public.attendance_staff_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PRESENT', -- 'PRESENT', 'ABSENT', 'LATE', 'HALF_DAY', 'ON_LEAVE', 'WORK_FROM_HOME', 'HOLIDAY', 'NOT_MARKED'
    check_in_time TIME,
    check_out_time TIME,
    is_wfh BOOLEAN DEFAULT FALSE,
    remarks TEXT,
    manager_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_attendance_staff_employee_date UNIQUE (school_id, employee_id, attendance_date)
);

-- 4. ATTENDANCE SETTINGS (School-level configuration)
CREATE TABLE IF NOT EXISTS public.attendance_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE UNIQUE,
    allow_late BOOLEAN DEFAULT TRUE,
    late_cutoff_minutes INT DEFAULT 15,
    require_absent_remark BOOLEAN DEFAULT FALSE,
    require_late_remark BOOLEAN DEFAULT FALSE,
    auto_mark_approved_leave BOOLEAN DEFAULT TRUE,
    lock_after_hours INT DEFAULT 24,
    allow_teacher_override_locked BOOLEAN DEFAULT FALSE,
    enable_notifications BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. ATTENDANCE AUDIT LOGS
CREATE TABLE IF NOT EXISTS public.attendance_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    record_type VARCHAR(50) NOT NULL, -- 'DAILY', 'PERIOD', 'STAFF', 'BULK', 'SETTINGS', 'LEAVE_OVERRIDE'
    record_id UUID,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL, -- 'CREATE', 'UPDATE', 'LOCK', 'UNLOCK', 'OVERRIDE', 'BULK_UPDATE', 'VOID'
    old_value JSONB,
    new_value JSONB,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for lightning fast queries & high concurrency
CREATE INDEX IF NOT EXISTS idx_att_daily_school_date_class ON public.attendance_daily_records(school_id, attendance_date, class_id, section_id);
CREATE INDEX IF NOT EXISTS idx_att_daily_student_date ON public.attendance_daily_records(student_id, attendance_date);
CREATE INDEX IF NOT EXISTS idx_att_daily_status ON public.attendance_daily_records(school_id, attendance_date, status);
CREATE INDEX IF NOT EXISTS idx_att_period_school_date ON public.attendance_period_records(school_id, attendance_date, class_id, section_id, period_number);
CREATE INDEX IF NOT EXISTS idx_att_period_student ON public.attendance_period_records(student_id, attendance_date);
CREATE INDEX IF NOT EXISTS idx_att_staff_school_date ON public.attendance_staff_records(school_id, attendance_date, status);
CREATE INDEX IF NOT EXISTS idx_att_staff_employee ON public.attendance_staff_records(employee_id, attendance_date);
CREATE INDEX IF NOT EXISTS idx_att_audit_school_date ON public.attendance_audit_logs(school_id, created_at DESC);


-- ============================================================================
-- STORED PROCEDURES & RPC FUNCTIONS
-- ============================================================================

-- Function: Get Attendance Dashboard Stats & Summary Cards
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
    -- Count Total Eligible Enrolled Students
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

    -- Count Today's Statuses from Daily Attendance Records
    SELECT 
        COUNT(CASE WHEN UPPER(a.status) = 'PRESENT' THEN 1 END),
        COUNT(CASE WHEN UPPER(a.status) = 'ABSENT' THEN 1 END),
        COUNT(CASE WHEN UPPER(a.status) = 'LATE' THEN 1 END),
        COUNT(CASE WHEN UPPER(a.status) = 'ON_LEAVE' THEN 1 END),
        COUNT(CASE WHEN UPPER(a.status) = 'HALF_DAY' THEN 1 END)
    INTO v_present, v_absent, v_late, v_on_leave, v_half_day
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
      );

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


-- Function: Get Daily Attendance Roster (Students with leave & schedule locks)
CREATE OR REPLACE FUNCTION public.fn_get_daily_attendance_roster(
    p_school_id UUID,
    p_date DATE,
    p_class_id UUID,
    p_section_id UUID DEFAULT NULL,
    p_mode VARCHAR DEFAULT 'ALL_DAY', -- 'ALL_DAY', 'PERIOD', 'MULTI_SCHEDULE'
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

    -- Count total matching students
    SELECT COUNT(*)
    INTO v_total_count
    FROM public.student_class_assignments sca
    JOIN public.profiles p ON p.id = sca.student_id AND (p.status IS NULL OR p.status != 'Deleted')
    LEFT JOIN public.academic_classes c ON c.id = sca.class_id
    LEFT JOIN public.academic_sections s ON s.id = sca.section_id
    LEFT JOIN public.attendance_daily_records adr ON adr.student_id = p.id AND adr.attendance_date = p_date AND adr.school_id = p_school_id
    LEFT JOIN public.attendance_period_records apr ON apr.student_id = p.id AND apr.attendance_date = p_date AND apr.school_id = p_school_id 
         AND (p_period_number IS NULL OR apr.period_number = p_period_number)
         AND (p_subject_id IS NULL OR apr.subject_id = p_subject_id)
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
      AND (
          p_status_filter = 'ALL'
          OR (p_mode = 'ALL_DAY' AND UPPER(COALESCE(adr.status, 'NOT_MARKED')) = UPPER(p_status_filter))
          OR (p_mode != 'ALL_DAY' AND UPPER(COALESCE(apr.status, adr.status, 'NOT_MARKED')) = UPPER(p_status_filter))
      );

    -- Build paginated roster with student profile, current attendance, leave detection, and audit info
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', p.id,
                'student_id', p.id,
                'full_name', p.full_name,
                'avatar_url', p.avatar_url,
                'roll_number', COALESCE(sca.roll_number, ''),
                'admission_number', COALESCE(p.admission_number, ''),
                'class_id', sca.class_id,
                'class_name', COALESCE(c.name, ''),
                'section_id', sca.section_id,
                'section_name', COALESCE(s.name, ''),
                'status', CASE 
                    WHEN p_mode = 'ALL_DAY' THEN COALESCE(adr.status, 'NOT_MARKED')
                    ELSE COALESCE(apr.status, adr.status, 'NOT_MARKED')
                END,
                'remarks', CASE 
                    WHEN p_mode = 'ALL_DAY' THEN COALESCE(adr.remarks, '')
                    ELSE COALESCE(apr.remarks, adr.remarks, '')
                END,
                'is_locked', CASE 
                    WHEN p_mode = 'ALL_DAY' THEN COALESCE(adr.is_locked, FALSE)
                    ELSE COALESCE(apr.is_locked, adr.is_locked, FALSE)
                END,
                'locked_by_all_day', COALESCE(apr.locked_by_all_day, FALSE),
                'is_overridden', CASE 
                    WHEN p_mode = 'ALL_DAY' THEN COALESCE(adr.is_overridden, FALSE)
                    ELSE COALESCE(apr.is_overridden, FALSE)
                END,
                'override_reason', CASE 
                    WHEN p_mode = 'ALL_DAY' THEN adr.override_reason
                    ELSE apr.override_reason
                END,
                'has_approved_leave', EXISTS (
                    SELECT 1 FROM public.leave_applications la
                    WHERE la.applicant_id = p.id
                      AND la.status = 'approved'
                      AND p_date BETWEEN la.start_date AND la.end_date
                ),
                'leave_reason', (
                    SELECT la.reason FROM public.leave_applications la
                    WHERE la.applicant_id = p.id
                      AND la.status = 'approved'
                      AND p_date BETWEEN la.start_date AND la.end_date
                    LIMIT 1
                ),
                'last_updated_at', CASE 
                    WHEN p_mode = 'ALL_DAY' THEN adr.updated_at
                    ELSE COALESCE(apr.updated_at, adr.updated_at)
                END,
                'updated_by_name', (
                    SELECT full_name FROM public.profiles 
                    WHERE id = CASE WHEN p_mode = 'ALL_DAY' THEN adr.updated_by ELSE COALESCE(apr.updated_by, adr.updated_by) END
                )
            ) ORDER BY 
                CASE WHEN sca.roll_number ~ '^\d+$' THEN sca.roll_number::INT ELSE 999999 END ASC,
                sca.roll_number ASC,
                p.full_name ASC
        ),
        '[]'::JSONB
    ) INTO v_students
    FROM (
        SELECT p.*, sca.roll_number, sca.class_id, sca.section_id
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
        ORDER BY 
            CASE WHEN sca.roll_number ~ '^\d+$' THEN sca.roll_number::INT ELSE 999999 END ASC,
            sca.roll_number ASC,
            p.full_name ASC
        LIMIT p_page_size OFFSET v_offset
    ) p
    JOIN public.student_class_assignments sca ON sca.student_id = p.id AND sca.class_id = p_class_id
    LEFT JOIN public.academic_classes c ON c.id = sca.class_id
    LEFT JOIN public.academic_sections s ON s.id = sca.section_id
    LEFT JOIN public.attendance_daily_records adr ON adr.student_id = p.id AND adr.attendance_date = p_date AND adr.school_id = p_school_id
    LEFT JOIN public.attendance_period_records apr ON apr.student_id = p.id AND apr.attendance_date = p_date AND apr.school_id = p_school_id 
         AND (p_period_number IS NULL OR apr.period_number = p_period_number)
         AND (p_subject_id IS NULL OR apr.subject_id = p_subject_id);

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


-- Function: Save Attendance (All Day / Single Period / Multi-Schedule)
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
    v_period_num INT := 1;
    v_periods_locked INT := 0;
    v_allow_override BOOLEAN := FALSE;
BEGIN
    v_date := (p_payload->>'attendance_date')::DATE;
    v_class_id := (p_payload->>'class_id')::UUID;
    v_section_id := (p_payload->>'section_id')::UUID;
    v_mode := COALESCE(p_payload->>'mode', 'ALL_DAY');
    v_records := COALESCE(p_payload->'records', '[]'::JSONB);
    v_allow_override := COALESCE((p_payload->>'allow_override')::BOOLEAN, FALSE);

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
                -- Upsert Master Daily Attendance Record (Locked by default)
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

                -- Propagate Attendance to All Applicable Scheduled Periods for this date
                -- Fetch timetable / class schedules for this class & section
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
                    -- Upsert Period Attendance Record locked by all-day
                    INSERT INTO public.attendance_period_records (
                        school_id, daily_record_id, student_id, class_id, section_id,
                        subject_id, attendance_date, period_number, status, remarks,
                        is_locked, locked_by_all_day, created_by, updated_by, updated_at
                    ) VALUES (
                        p_school_id, v_daily_id, v_student_id, v_class_id, v_section_id,
                        v_sched.subject_id, v_date, v_sched.p_num, v_status, v_remarks,
                        TRUE, TRUE, p_user_id, p_user_id, NOW()
                    )
                    ON CONFLICT DO NOTHING;

                    -- Update existing period record if not manually overridden
                    UPDATE public.attendance_period_records SET
                        status = v_status,
                        remarks = v_remarks,
                        is_locked = TRUE,
                        locked_by_all_day = TRUE,
                        updated_by = p_user_id,
                        updated_at = NOW()
                    WHERE school_id = p_school_id
                      AND student_id = v_student_id
                      AND attendance_date = v_date
                      AND period_number = v_sched.p_num
                      AND (is_overridden IS FALSE OR v_allow_override IS TRUE);

                    v_periods_locked := v_periods_locked + 1;
                END LOOP;

            ELSE
                -- Specific Period Mode
                v_period_num := COALESCE((v_item->>'period_number')::INT, (p_payload->>'period_number')::INT, 1);
                
                INSERT INTO public.attendance_period_records (
                    school_id, student_id, class_id, section_id,
                    subject_id, attendance_date, period_number, status, remarks,
                    is_locked, locked_by_all_day, created_by, updated_by, updated_at
                ) VALUES (
                    p_school_id, v_student_id, v_class_id, v_section_id,
                    (v_item->>'subject_id')::UUID, v_date, v_period_num, v_status, v_remarks,
                    FALSE, FALSE, p_user_id, p_user_id, NOW()
                )
                ON CONFLICT DO NOTHING;

                UPDATE public.attendance_period_records SET
                    status = v_status,
                    remarks = v_remarks,
                    updated_by = p_user_id,
                    updated_at = NOW()
                WHERE school_id = p_school_id
                  AND student_id = v_student_id
                  AND attendance_date = v_date
                  AND period_number = v_period_num;
            END IF;

            v_saved_count := v_saved_count + 1;
        END IF;
    END LOOP;

    -- Record Audit Trail
    INSERT INTO public.attendance_audit_logs (
        school_id, record_type, user_id, action, new_value, reason
    ) VALUES (
        p_school_id,
        CASE WHEN v_mode = 'ALL_DAY' THEN 'DAILY' ELSE 'PERIOD' END,
        p_user_id,
        'SAVE_ATTENDANCE',
        jsonb_build_object('mode', v_mode, 'date', v_date, 'class_id', v_class_id, 'students_count', v_saved_count),
        'Routine attendance submission'
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', CASE 
            WHEN v_mode = 'ALL_DAY' THEN 'All-day attendance saved and applied to all schedules'
            ELSE 'Period attendance saved successfully'
        END,
        'saved_count', v_saved_count,
        'mode', v_mode
    );
END;
$$;


-- Function: Override Locked Attendance (Requires Reason)
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
    v_old_status VARCHAR;
BEGIN
    IF TRIM(COALESCE(p_reason, '')) = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'An override reason is mandatory', 'code', 400);
    END IF;

    IF UPPER(p_record_type) = 'DAILY' THEN
        SELECT status INTO v_old_status FROM public.attendance_daily_records WHERE id = p_record_id AND school_id = p_school_id;
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Daily attendance record not found', 'code', 404);
        END IF;

        UPDATE public.attendance_daily_records SET
            status = UPPER(p_new_status),
            is_overridden = TRUE,
            override_reason = p_reason,
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = p_record_id;

    ELSE
        SELECT status INTO v_old_status FROM public.attendance_period_records WHERE id = p_record_id AND school_id = p_school_id;
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Period attendance record not found', 'code', 404);
        END IF;

        UPDATE public.attendance_period_records SET
            status = UPPER(p_new_status),
            is_overridden = TRUE,
            override_reason = p_reason,
            overridden_by = p_user_id,
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = p_record_id;
    END IF;

    -- Write Audit Record
    INSERT INTO public.attendance_audit_logs (
        school_id, record_type, record_id, user_id, action, old_value, new_value, reason
    ) VALUES (
        p_school_id,
        p_record_type,
        p_record_id,
        p_user_id,
        'OVERRIDE',
        jsonb_build_object('status', v_old_status),
        jsonb_build_object('status', p_new_status),
        p_reason
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Attendance overridden successfully',
        'record_id', p_record_id,
        'new_status', p_new_status
    );
END;
$$;


-- Function: Get Staff Attendance Roster
CREATE OR REPLACE FUNCTION public.fn_get_staff_attendance_roster(
    p_school_id UUID,
    p_date DATE,
    p_department VARCHAR DEFAULT 'ALL',
    p_role VARCHAR DEFAULT 'ALL',
    p_status VARCHAR DEFAULT 'ALL',
    p_search TEXT DEFAULT '',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_manager_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_count INT := 0;
    v_offset INT;
    v_staff JSONB;
BEGIN
    v_offset := (p_page - 1) * p_page_size;

    SELECT COUNT(*)
    INTO v_total_count
    FROM public.profiles p
    LEFT JOIN public.attendance_staff_records asr ON asr.employee_id = p.id AND asr.attendance_date = p_date AND asr.school_id = p_school_id
    WHERE p.school_id = p_school_id
      AND p.role IN ('teacher', 'faculty', 'instructor', 'staff', 'admin', 'principal', 'driver', 'librarian', 'accountant', 'security', 'hr', 'finance', 'transport', 'support', 'director', 'exam_ctrl')
      AND (p.status IS NULL OR p.status != 'Deleted')
      AND (p_department = 'ALL' OR p.department = p_department)
      AND (p_role = 'ALL' OR p.role = p_role)
      AND (p_status = 'ALL' OR UPPER(COALESCE(asr.status, 'NOT_MARKED')) = UPPER(p_status))
      AND (p_manager_id IS NULL OR p.manager_id = p_manager_id)
      AND (
          p_search = '' 
          OR p.full_name ILIKE '%' || p_search || '%' 
          OR p.email ILIKE '%' || p_search || '%'
          OR p.employee_id ILIKE '%' || p_search || '%'
      );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', p.id,
                'employee_id', p.id,
                'employee_code', COALESCE(p.employee_id, ''),
                'full_name', p.full_name,
                'email', p.email,
                'avatar_url', p.avatar_url,
                'role', p.role,
                'department', COALESCE(p.department, 'General'),
                'designation', COALESCE(p.designation, p.role),
                'status', COALESCE(asr.status, 'NOT_MARKED'),
                'check_in_time', asr.check_in_time,
                'check_out_time', asr.check_out_time,
                'is_wfh', COALESCE(asr.is_wfh, FALSE),
                'remarks', COALESCE(asr.remarks, ''),
                'manager_name', (SELECT full_name FROM public.profiles WHERE id = p.manager_id),
                'last_updated_at', asr.updated_at,
                'updated_by_name', (SELECT full_name FROM public.profiles WHERE id = asr.updated_by)
            ) ORDER BY p.full_name ASC
        ),
        '[]'::JSONB
    ) INTO v_staff
    FROM (
        SELECT p.*
        FROM public.profiles p
        LEFT JOIN public.attendance_staff_records asr ON asr.employee_id = p.id AND asr.attendance_date = p_date AND asr.school_id = p_school_id
        WHERE p.school_id = p_school_id
          AND p.role IN ('teacher', 'faculty', 'instructor', 'staff', 'admin', 'principal', 'driver', 'librarian', 'accountant', 'security', 'hr', 'finance', 'transport', 'support', 'director', 'exam_ctrl')
          AND (p.status IS NULL OR p.status != 'Deleted')
          AND (p_department = 'ALL' OR p.department = p_department)
          AND (p_role = 'ALL' OR p.role = p_role)
          AND (p_status = 'ALL' OR UPPER(COALESCE(asr.status, 'NOT_MARKED')) = UPPER(p_status))
          AND (p_manager_id IS NULL OR p.manager_id = p_manager_id)
          AND (
              p_search = '' 
              OR p.full_name ILIKE '%' || p_search || '%' 
              OR p.email ILIKE '%' || p_search || '%'
              OR p.employee_id ILIKE '%' || p_search || '%'
          )
        ORDER BY p.full_name ASC
        LIMIT p_page_size OFFSET v_offset
    ) p
    LEFT JOIN public.attendance_staff_records asr ON asr.employee_id = p.id AND asr.attendance_date = p_date AND asr.school_id = p_school_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'staff', v_staff,
            'total_count', v_total_count,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_count::FLOAT / GREATEST(p_page_size, 1))
        )
    );
END;
$$;


-- Function: Save Staff Attendance
CREATE OR REPLACE FUNCTION public.fn_save_staff_attendance(
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
    v_records JSONB;
    v_item JSONB;
    v_emp_id UUID;
    v_status VARCHAR;
    v_check_in TIME;
    v_check_out TIME;
    v_is_wfh BOOLEAN;
    v_remarks TEXT;
    v_saved_count INT := 0;
BEGIN
    v_date := (p_payload->>'attendance_date')::DATE;
    v_records := COALESCE(p_payload->'records', '[]'::JSONB);

    IF v_date IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'attendance_date is required', 'code', 400);
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(v_records) LOOP
        v_emp_id := (v_item->>'employee_id')::UUID;
        v_status := UPPER(TRIM(COALESCE(v_item->>'status', 'PRESENT')));
        v_check_in := (v_item->>'check_in_time')::TIME;
        v_check_out := (v_item->>'check_out_time')::TIME;
        v_is_wfh := COALESCE((v_item->>'is_wfh')::BOOLEAN, FALSE);
        v_remarks := TRIM(COALESCE(v_item->>'remarks', ''));

        IF v_emp_id IS NOT NULL THEN
            INSERT INTO public.attendance_staff_records (
                school_id, employee_id, attendance_date, status, check_in_time,
                check_out_time, is_wfh, remarks, created_by, updated_by, updated_at
            ) VALUES (
                p_school_id, v_emp_id, v_date, v_status, v_check_in,
                v_check_out, v_is_wfh, v_remarks, p_user_id, p_user_id, NOW()
            )
            ON CONFLICT (school_id, employee_id, attendance_date) DO UPDATE SET
                status = EXCLUDED.status,
                check_in_time = EXCLUDED.check_in_time,
                check_out_time = EXCLUDED.check_out_time,
                is_wfh = EXCLUDED.is_wfh,
                remarks = EXCLUDED.remarks,
                updated_by = EXCLUDED.updated_by,
                updated_at = NOW();

            v_saved_count := v_saved_count + 1;
        END IF;
    END LOOP;

    INSERT INTO public.attendance_audit_logs (
        school_id, record_type, user_id, action, new_value, reason
    ) VALUES (
        p_school_id, 'STAFF', p_user_id, 'SAVE_STAFF_ATTENDANCE',
        jsonb_build_object('date', v_date, 'count', v_saved_count),
        'Staff attendance submission'
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Staff attendance saved successfully',
        'saved_count', v_saved_count
    );
END;
$$;


-- Function: Get Attendance Insights & Chronic Absenteeism
CREATE OR REPLACE FUNCTION public.fn_get_attendance_insights(
    p_school_id UUID,
    p_start_date DATE DEFAULT (CURRENT_DATE - INTERVAL '30 days')::DATE,
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_class_id UUID DEFAULT NULL,
    p_section_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_overall_pct NUMERIC := 0.0;
    v_daily_trend JSONB;
    v_at_risk_students JSONB;
    v_class_comparison JSONB;
BEGIN
    -- Daily Trend
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'date', sub.dt,
                'present_count', sub.present_count,
                'absent_count', sub.absent_count,
                'late_count', sub.late_count,
                'attendance_pct', sub.attendance_pct
            ) ORDER BY sub.dt ASC
        ),
        '[]'::JSONB
    ) INTO v_daily_trend
    FROM (
        SELECT 
            d.dt::DATE as dt,
            COUNT(CASE WHEN UPPER(a.status) = 'PRESENT' THEN 1 END) as present_count,
            COUNT(CASE WHEN UPPER(a.status) = 'ABSENT' THEN 1 END) as absent_count,
            COUNT(CASE WHEN UPPER(a.status) = 'LATE' THEN 1 END) as late_count,
            CASE 
                WHEN COUNT(a.id) > 0 THEN ROUND((COUNT(CASE WHEN UPPER(a.status) IN ('PRESENT', 'LATE') THEN 1 END)::NUMERIC / COUNT(a.id)::NUMERIC) * 100.0, 1)
                ELSE 0.0
            END as attendance_pct
        FROM generate_series(p_start_date, p_end_date, INTERVAL '1 day') AS d(dt)
        LEFT JOIN public.attendance_daily_records a ON a.attendance_date = d.dt::DATE AND a.school_id = p_school_id
             AND (p_class_id IS NULL OR a.class_id = p_class_id)
             AND (p_section_id IS NULL OR a.section_id = p_section_id)
        GROUP BY d.dt
    ) sub;

    -- At Risk Students (Attendance < 75%)
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'student_id', sub.student_id,
                'full_name', sub.full_name,
                'avatar_url', sub.avatar_url,
                'class_name', sub.class_name,
                'section_name', sub.section_name,
                'roll_number', sub.roll_number,
                'total_days', sub.total_days,
                'present_days', sub.present_days,
                'absent_days', sub.absent_days,
                'attendance_pct', sub.attendance_pct
            ) ORDER BY sub.attendance_pct ASC
        ),
        '[]'::JSONB
    ) INTO v_at_risk_students
    FROM (
        SELECT 
            p.id as student_id,
            p.full_name,
            p.avatar_url,
            c.name as class_name,
            s.name as section_name,
            sca.roll_number,
            COUNT(a.id) as total_days,
            COUNT(CASE WHEN UPPER(a.status) = 'PRESENT' THEN 1 END) as present_days,
            COUNT(CASE WHEN UPPER(a.status) = 'ABSENT' THEN 1 END) as absent_days,
            ROUND((COUNT(CASE WHEN UPPER(a.status) IN ('PRESENT', 'LATE') THEN 1 END)::NUMERIC / NULLIF(COUNT(a.id), 0)::NUMERIC) * 100.0, 1) as attendance_pct
        FROM public.student_class_assignments sca
        JOIN public.profiles p ON p.id = sca.student_id AND (p.status IS NULL OR p.status != 'Deleted')
        LEFT JOIN public.academic_classes c ON c.id = sca.class_id
        LEFT JOIN public.academic_sections s ON s.id = sca.section_id
        LEFT JOIN public.attendance_daily_records a ON a.student_id = p.id AND a.school_id = p_school_id AND a.attendance_date BETWEEN p_start_date AND p_end_date
        WHERE sca.school_id = p_school_id AND sca.status = 'ACTIVE'
          AND (p_class_id IS NULL OR sca.class_id = p_class_id)
          AND (p_section_id IS NULL OR sca.section_id = p_section_id)
        GROUP BY p.id, p.full_name, p.avatar_url, c.name, s.name, sca.roll_number
        HAVING COUNT(a.id) > 0 AND (COUNT(CASE WHEN UPPER(a.status) IN ('PRESENT', 'LATE') THEN 1 END)::NUMERIC / COUNT(a.id)::NUMERIC) * 100.0 < 75.0
    ) sub;

    -- Class Comparisons
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'class_id', sub.class_id,
                'class_name', sub.class_name,
                'total_students', sub.total_students,
                'attendance_pct', sub.attendance_pct
            ) ORDER BY sub.display_order ASC, sub.class_name ASC
        ),
        '[]'::JSONB
    ) INTO v_class_comparison
    FROM (
        SELECT 
            c.id as class_id,
            c.name as class_name,
            c.display_order,
            COUNT(DISTINCT sca.student_id) as total_students,
            CASE 
                WHEN COUNT(a.id) > 0 THEN ROUND((COUNT(CASE WHEN UPPER(a.status) IN ('PRESENT', 'LATE') THEN 1 END)::NUMERIC / COUNT(a.id)::NUMERIC) * 100.0, 1)
                ELSE 0.0
            END as attendance_pct
        FROM public.academic_classes c
        LEFT JOIN public.student_class_assignments sca ON sca.class_id = c.id AND sca.status = 'ACTIVE'
        LEFT JOIN public.attendance_daily_records a ON a.class_id = c.id AND a.school_id = p_school_id AND a.attendance_date BETWEEN p_start_date AND p_end_date
        WHERE c.school_id = p_school_id AND (c.deleted_at IS NULL OR c.status != 'ARCHIVED')
        GROUP BY c.id, c.name, c.display_order
    ) sub;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'start_date', p_start_date,
            'end_date', p_end_date,
            'daily_trend', v_daily_trend,
            'at_risk_students', v_at_risk_students,
            'at_risk_count', jsonb_array_length(v_at_risk_students),
            'class_comparison', v_class_comparison
        )
    );
END;
$$;


-- Function: Get and Update Attendance Settings
CREATE OR REPLACE FUNCTION public.fn_get_attendance_settings(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_settings RECORD;
BEGIN
    SELECT * INTO v_settings FROM public.attendance_settings WHERE school_id = p_school_id;
    IF NOT FOUND THEN
        INSERT INTO public.attendance_settings (school_id) VALUES (p_school_id)
        RETURNING * INTO v_settings;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', row_to_json(v_settings)
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_update_attendance_settings(
    p_school_id UUID,
    p_user_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_settings RECORD;
BEGIN
    INSERT INTO public.attendance_settings (
        school_id, allow_late, late_cutoff_minutes, require_absent_remark,
        require_late_remark, auto_mark_approved_leave, lock_after_hours,
        allow_teacher_override_locked, enable_notifications, updated_at
    ) VALUES (
        p_school_id,
        COALESCE((p_payload->>'allow_late')::BOOLEAN, TRUE),
        COALESCE((p_payload->>'late_cutoff_minutes')::INT, 15),
        COALESCE((p_payload->>'require_absent_remark')::BOOLEAN, FALSE),
        COALESCE((p_payload->>'require_late_remark')::BOOLEAN, FALSE),
        COALESCE((p_payload->>'auto_mark_approved_leave')::BOOLEAN, TRUE),
        COALESCE((p_payload->>'lock_after_hours')::INT, 24),
        COALESCE((p_payload->>'allow_teacher_override_locked')::BOOLEAN, FALSE),
        COALESCE((p_payload->>'enable_notifications')::BOOLEAN, TRUE),
        NOW()
    )
    ON CONFLICT (school_id) DO UPDATE SET
        allow_late = EXCLUDED.allow_late,
        late_cutoff_minutes = EXCLUDED.late_cutoff_minutes,
        require_absent_remark = EXCLUDED.require_absent_remark,
        require_late_remark = EXCLUDED.require_late_remark,
        auto_mark_approved_leave = EXCLUDED.auto_mark_approved_leave,
        lock_after_hours = EXCLUDED.lock_after_hours,
        allow_teacher_override_locked = EXCLUDED.allow_teacher_override_locked,
        enable_notifications = EXCLUDED.enable_notifications,
        updated_at = NOW()
    RETURNING * INTO v_settings;

    INSERT INTO public.attendance_audit_logs (
        school_id, record_type, user_id, action, new_value, reason
    ) VALUES (
        p_school_id, 'SETTINGS', p_user_id, 'UPDATE_SETTINGS',
        row_to_json(v_settings)::JSONB, 'Updated school attendance rules'
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Settings updated successfully',
        'data', row_to_json(v_settings)
    );
END;
$$;
