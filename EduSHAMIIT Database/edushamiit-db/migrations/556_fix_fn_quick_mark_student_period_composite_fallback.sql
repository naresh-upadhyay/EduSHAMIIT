-- ============================================================================
-- Migration: 556_fix_fn_quick_mark_student_period_composite_fallback.sql
-- Description:
--   Ensure fn_quick_mark_student_period uses GREATEST(v_total_sched_count, v_student_marked_periods)
--   so that days with extra/unregistered timetable schedules correctly compute composite daily status.
-- ============================================================================

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
    v_effective_total INT := 0;
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
        v_effective_total := GREATEST(v_total_sched_count, v_student_marked_periods);

        -- Compute mathematically sound composite status
        v_composite_daily_status := public.fn_calculate_composite_attendance_status(
            v_effective_total,
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
            v_composite_daily_status, 'Updated from period attendance', (v_student_marked_periods >= v_effective_total AND v_effective_total > 0), p_user_id, NOW(), (v_student_marked_periods >= v_effective_total AND v_effective_total > 0),
            p_user_id, p_user_id, NOW()
        )
        ON CONFLICT (school_id, student_id, attendance_date) DO UPDATE
        SET status = EXCLUDED.status,
            class_id = EXCLUDED.class_id,
            section_id = EXCLUDED.section_id,
            remarks = EXCLUDED.remarks,
            is_locked = EXCLUDED.is_locked,
            locked_by = EXCLUDED.locked_by,
            locked_at = EXCLUDED.locked_at,
            is_all_day = EXCLUDED.is_all_day,
            updated_by = EXCLUDED.updated_by,
            updated_at = NOW();
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Period ' || p_period_number || ' updated to ' || v_status_norm,
        'period_number', p_period_number,
        'period_status', v_status_norm,
        'composite_daily_status', v_composite_daily_status,
        'total_marked_periods', v_student_marked_periods,
        'total_scheduled_periods', v_total_sched_count
    );
END;
$$;
