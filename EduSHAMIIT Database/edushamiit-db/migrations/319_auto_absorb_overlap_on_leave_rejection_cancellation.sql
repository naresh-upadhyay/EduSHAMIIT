-- ============================================================================
-- Migration 319: Dynamic Overlap Absorption & Rebalancing on Reject / Cancel
-- ============================================================================
-- When an older leave request (e.g. 03-05 Sep) is rejected or cancelled:
-- 1. Any newer active (pending or approved) superset/overlapping leave request
--    (e.g. 02-08 Sep) automatically re-absorbs the freed working days
--    (increasing its billable_days from 3d to 5d).
-- 2. Any non-overlapping freed days are returned to the available quota in leave_balances.
-- 3. Infallibly synchronizes used_days and pending_days.
-- ============================================================================

-- 1. Dynamic Applicant Leave Applications Recalculation Engine
CREATE OR REPLACE FUNCTION public.fn_recalculate_applicant_leave_applications(
    p_applicant_id UUID,
    p_school_id UUID DEFAULT NULL
)
RETURNS VOID AS $func$
DECLARE
    v_app RECORD;
    v_total_days INT;
    v_holidays_count INT;
    v_overlap_count INT;
    v_net_days NUMERIC(5, 1);
    v_cur_date DATE;
    v_is_holiday BOOLEAN;
    v_has_overlap BOOLEAN;
    v_acad_year VARCHAR;
    v_sch_id UUID;
BEGIN
    SELECT COALESCE(p_school_id, school_id, '11111111-1111-1111-1111-111111111111'::UUID)
    INTO v_sch_id
    FROM public.profiles
    WHERE id = p_applicant_id;

    -- Process all active applications (both 'approved' and 'pending') in chronological order of creation
    FOR v_app IN (
        SELECT *
        FROM public.leave_applications
        WHERE applicant_id = p_applicant_id
          AND LOWER(status) IN ('approved', 'pending')
        ORDER BY 
            CASE WHEN LOWER(status) = 'approved' THEN 0 ELSE 1 END ASC,
            created_at ASC, 
            applied_at ASC, 
            id ASC
    ) LOOP
        v_total_days := (v_app.end_date - v_app.start_date) + 1;
        v_holidays_count := 0;
        v_overlap_count := 0;
        v_cur_date := v_app.start_date;

        WHILE v_cur_date <= v_app.end_date LOOP
            v_is_holiday := FALSE;
            v_has_overlap := FALSE;

            -- 1. Check official school events holidays (case-insensitive)
            SELECT EXISTS(
                SELECT 1 FROM public.events
                WHERE (school_id = v_app.school_id OR school_id IS NULL)
                  AND (category ILIKE '%holiday%' OR category ILIKE '%holy%' OR category ILIKE '%vacation%' OR title ILIKE '%holiday%' OR title ILIKE '%vacation%' OR title ILIKE '%closed%' OR title ILIKE '%break%')
                  AND v_cur_date BETWEEN event_date AND event_date
            ) INTO v_is_holiday;

            -- 2. Check calendar schedules holidays (Single + Recurring with schedule_recurrence)
            IF NOT v_is_holiday THEN
                SELECT EXISTS(
                    SELECT 1 FROM public.schedules s
                    LEFT JOIN public.calendars c ON s.calendar_id = c.id
                    LEFT JOIN public.schedule_recurrence sr ON sr.schedule_id = s.id
                    WHERE (s.school_id = v_app.school_id OR s.school_id IS NULL)
                      AND s.deleted_at IS NULL
                      AND (
                          c.name ILIKE '%holiday%' OR c.name ILIKE '%holy%' OR c.name ILIKE '%vacation%' OR c.name ILIKE '%closure%'
                          OR c.type ILIKE '%holiday%' OR c.type ILIKE '%school_events%'
                          OR s.schedule_type ILIKE '%holiday%' OR s.schedule_type ILIKE '%holy%' OR s.schedule_type ILIKE '%vacation%' OR s.schedule_type ILIKE '%off%'
                          OR s.category ILIKE '%holiday%' OR s.category ILIKE '%holy%' OR s.category ILIKE '%vacation%'
                          OR s.title ILIKE '%holiday%' OR s.title ILIKE '%holy%' OR s.title ILIKE '%vacation%' OR s.title ILIKE '%closed%' OR s.title ILIKE '%off%' OR s.title ILIKE '%leave%' OR s.title ILIKE '%sunday%'
                          OR s.description ILIKE '%holiday%' OR s.description ILIKE '%holy%'
                      )
                      AND (
                          (
                              v_cur_date >= (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE
                              AND v_cur_date <= (s.end_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE
                          )
                          OR (
                              (s.is_recurring = TRUE OR sr.id IS NOT NULL)
                              AND v_cur_date >= (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE
                              AND (sr.end_date IS NULL OR v_cur_date <= sr.end_date::DATE)
                              AND (
                                  sr.frequency = 'daily'
                                  OR (sr.frequency = 'weekly' AND (
                                      (sr.days_of_week IS NOT NULL AND jsonb_typeof(sr.days_of_week) = 'array' AND (
                                          sr.days_of_week ? UPPER(TRIM(TO_CHAR(v_cur_date, 'DY')))
                                          OR sr.days_of_week ? SUBSTRING(UPPER(TRIM(TO_CHAR(v_cur_date, 'DY'))) FROM 1 FOR 2)
                                      ))
                                      OR EXTRACT(DOW FROM v_cur_date) = EXTRACT(DOW FROM (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE)
                                  ))
                                  OR (COALESCE(sr.frequency, 'weekly') = 'weekly' AND EXTRACT(DOW FROM v_cur_date) = EXTRACT(DOW FROM (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE))
                                  OR (sr.frequency = 'monthly' AND EXTRACT(DAY FROM v_cur_date) = EXTRACT(DAY FROM (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE))
                              )
                          )
                      )
                ) INTO v_is_holiday;
            END IF;

            IF v_is_holiday THEN
                v_holidays_count := v_holidays_count + 1;
            ELSE
                -- Check overlap ONLY with PRIOR active applications of the same applicant
                SELECT EXISTS(
                    SELECT 1 FROM public.leave_applications prior_la
                    WHERE prior_la.applicant_id = p_applicant_id
                      AND prior_la.id != v_app.id
                      AND LOWER(prior_la.status) IN ('approved', 'pending')
                      AND (
                          (LOWER(prior_la.status) = 'approved' AND LOWER(v_app.status) = 'pending')
                          OR (
                              LOWER(prior_la.status) = LOWER(v_app.status)
                              AND (prior_la.created_at < v_app.created_at OR (prior_la.created_at = v_app.created_at AND prior_la.id < v_app.id))
                          )
                      )
                      AND v_cur_date BETWEEN prior_la.start_date AND prior_la.end_date
                ) INTO v_has_overlap;

                IF v_has_overlap THEN
                    v_overlap_count := v_overlap_count + 1;
                END IF;
            END IF;

            v_cur_date := v_cur_date + 1;
        END LOOP;

        IF v_app.half_day_type IN ('FIRST_HALF', 'SECOND_HALF') THEN
            v_net_days := CASE WHEN v_holidays_count > 0 OR v_overlap_count > 0 THEN 0.0 ELSE 0.5 END;
        ELSE
            v_net_days := GREATEST(0, (v_total_days - v_holidays_count - v_overlap_count))::NUMERIC(5, 1);
        END IF;

        UPDATE public.leave_applications
        SET billable_days = v_net_days,
            holidays_count = v_holidays_count,
            overlap_days_count = v_overlap_count,
            updated_at = NOW()
        WHERE id = v_app.id
          AND (billable_days != v_net_days OR COALESCE(holidays_count, 0) != v_holidays_count OR COALESCE(overlap_days_count, 0) != v_overlap_count);
    END LOOP;
END;
$func$ LANGUAGE plpgsql;


-- 2. Enhanced fn_process_leave_action with Automatic Overlap Re-Absorption & Balances Recalculation
CREATE OR REPLACE FUNCTION public.fn_process_leave_action(
    p_school_id UUID,
    p_leave_id UUID,
    p_action VARCHAR,
    p_actor_id UUID,
    p_remarks TEXT DEFAULT NULL
)
RETURNS JSONB AS $function$
DECLARE
    v_leave RECORD;
    v_new_status VARCHAR;
    v_days NUMERIC(5, 1);
    v_cur_date DATE;
    v_class_id UUID;
    v_section_id UUID;
    v_annual_entitlement NUMERIC(5, 1);
    v_actual_used NUMERIC(5, 1);
    v_actual_pending NUMERIC(5, 1);
    v_acad_year VARCHAR;
    v_lt RECORD;
BEGIN
    SELECT la.*, p.role AS applicant_role, p.full_name AS applicant_name
    INTO v_leave
    FROM public.leave_applications la
    JOIN public.profiles p ON p.id = la.applicant_id
    WHERE la.id = p_leave_id;

    IF v_leave.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Leave application not found');
    END IF;

    IF v_leave.status != 'pending' THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Leave application has already been ' || v_leave.status);
    END IF;

    IF UPPER(p_action) = 'APPROVE' THEN
        v_new_status := 'approved';
    ELSIF UPPER(p_action) = 'REJECT' THEN
        v_new_status := 'rejected';
    ELSIF UPPER(p_action) = 'CANCEL' THEN
        v_new_status := 'cancelled';
    ELSE
        RETURN jsonb_build_object('success', FALSE, 'message', 'Invalid action: ' || p_action);
    END IF;

    -- 1. Update Current Application Status
    UPDATE public.leave_applications
    SET status = v_new_status,
        approved_by = CASE WHEN v_new_status = 'approved' THEN p_actor_id ELSE approved_by END,
        approved_at = CASE WHEN v_new_status = 'approved' THEN NOW() ELSE approved_at END,
        rejection_reason = CASE WHEN v_new_status = 'rejected' THEN p_remarks ELSE rejection_reason END,
        remarks = CASE WHEN p_remarks IS NOT NULL AND TRIM(p_remarks) != '' THEN p_remarks ELSE remarks END,
        updated_at = NOW()
    WHERE id = p_leave_id;

    -- 2. Dynamically Recalculate All Active Applications for Applicant (Auto-Absorb Freed Days!)
    PERFORM public.fn_recalculate_applicant_leave_applications(v_leave.applicant_id, COALESCE(p_school_id, v_leave.school_id));

    -- 3. Resolve Academic Year
    v_acad_year := public.fn_resolve_academic_year(v_leave.start_date, v_leave.school_id);

    -- 4. Synchronize & Recalculate Leave Balances for all active leave types of this applicant
    FOR v_lt IN (
        SELECT id, name, annual_entitlement
        FROM public.leave_types
        WHERE (school_id = v_leave.school_id OR school_id IS NULL)
          AND is_active = TRUE
    ) LOOP
        SELECT COALESCE(SUM(la.billable_days), 0.0)
        INTO v_actual_used
        FROM public.leave_applications la
        WHERE la.applicant_id = v_leave.applicant_id
          AND (la.leave_type_id = v_lt.id OR UPPER(la.leave_type) = UPPER(v_lt.name))
          AND public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year
          AND LOWER(la.status) = 'approved';

        SELECT COALESCE(SUM(la.billable_days), 0.0)
        INTO v_actual_pending
        FROM public.leave_applications la
        WHERE la.applicant_id = v_leave.applicant_id
          AND (la.leave_type_id = v_lt.id OR UPPER(la.leave_type) = UPPER(v_lt.name))
          AND public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year
          AND LOWER(la.status) = 'pending';

        INSERT INTO public.leave_balances (
            school_id, user_id, leave_type_id, academic_year,
            allocated_days, used_days, pending_days, carried_forward_days, updated_at
        )
        VALUES (
            COALESCE(p_school_id, v_leave.school_id, '11111111-1111-1111-1111-111111111111'::UUID),
            v_leave.applicant_id, 
            v_lt.id, 
            v_acad_year,
            COALESCE(v_lt.annual_entitlement, 12.0), 
            v_actual_used, 
            v_actual_pending, 
            0.0, 
            NOW()
        )
        ON CONFLICT (school_id, user_id, leave_type_id, academic_year)
        DO UPDATE SET
            allocated_days = EXCLUDED.allocated_days,
            used_days = EXCLUDED.used_days,
            pending_days = EXCLUDED.pending_days,
            updated_at = NOW();
    END LOOP;

    -- 5. Synchronize with Daily Attendance if Approved
    IF v_new_status = 'approved' THEN
        IF LOWER(COALESCE(v_leave.applicant_role, '')) = 'student' THEN
            SELECT class_id, section_id INTO v_class_id, v_section_id
            FROM public.student_class_assignments
            WHERE student_id = v_leave.applicant_id AND (school_id = p_school_id OR school_id IS NULL)
            LIMIT 1;

            v_cur_date := v_leave.start_date;
            WHILE v_cur_date <= v_leave.end_date LOOP
                INSERT INTO public.attendance_daily_records (
                    school_id, student_id, class_id, section_id, attendance_date, status, remarks, is_locked, is_all_day, created_by, updated_by
                )
                VALUES (
                    COALESCE(p_school_id, v_leave.school_id), v_leave.applicant_id, v_class_id, v_section_id, v_cur_date, 'ON_LEAVE',
                    'Approved Leave: ' || v_leave.leave_type || ' (' || COALESCE(v_leave.reason, '') || ')', TRUE, TRUE, p_actor_id, p_actor_id
                )
                ON CONFLICT (school_id, student_id, attendance_date)
                DO UPDATE SET status = 'ON_LEAVE', remarks = EXCLUDED.remarks, is_locked = TRUE, updated_by = p_actor_id, updated_at = NOW();

                v_cur_date := v_cur_date + 1;
            END LOOP;
        ELSE
            v_cur_date := v_leave.start_date;
            WHILE v_cur_date <= v_leave.end_date LOOP
                INSERT INTO public.attendance_staff_records (
                    school_id, employee_id, attendance_date, status, remarks, created_by, updated_by
                )
                VALUES (
                    COALESCE(p_school_id, v_leave.school_id), v_leave.applicant_id, v_cur_date, 'ON_LEAVE',
                    'Approved Leave: ' || v_leave.leave_type || ' (' || COALESCE(v_leave.reason, '') || ')', p_actor_id, p_actor_id
                )
                ON CONFLICT (school_id, employee_id, attendance_date)
                DO UPDATE SET status = 'ON_LEAVE', remarks = EXCLUDED.remarks, updated_by = p_actor_id, updated_at = NOW();

                v_cur_date := v_cur_date + 1;
            END LOOP;
        END IF;
    END IF;

    -- 6. Insert Immutable Audit Log
    INSERT INTO public.attendance_audit_logs (
        school_id, user_id, action, record_type, record_id,
        new_value, reason
    )
    VALUES (
        COALESCE(p_school_id, v_leave.school_id), v_leave.applicant_id, 
        'LEAVE_' || UPPER(v_new_status), 'LEAVE_APPLICATION', p_leave_id,
        jsonb_build_object('request_code', v_leave.request_code, 'action', p_action, 'actor_id', p_actor_id),
        p_remarks
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Leave request ' || v_new_status || ' successfully',
        'data', jsonb_build_object(
            'id', p_leave_id,
            'status', v_new_status,
            'request_code', v_leave.request_code
        )
    );
END;
$function$ LANGUAGE plpgsql;
