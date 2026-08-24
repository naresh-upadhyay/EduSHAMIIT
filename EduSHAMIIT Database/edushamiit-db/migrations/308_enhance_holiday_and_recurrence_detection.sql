-- ============================================================================
-- Migration: 308_enhance_holiday_and_recurrence_detection.sql
-- Description:
--   1. Enhances fn_apply_leave_request stored procedure to dynamically detect
--      both standard calendar holidays AND recurring holiday instances from schedule_recurrence.
--   2. Enforces case-insensitive holiday keyword matching across calendar name,
--      schedule type, category, and schedule title.
--   3. Guarantees 0 deduction for public holidays, recurring weekly holidays (e.g. SUN HOLY),
--      and active already-applied leave requests.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_apply_leave_request(
    p_school_id UUID,
    p_applicant_id UUID,
    p_leave_type VARCHAR,
    p_start_date DATE,
    p_end_date DATE,
    p_reason TEXT,
    p_half_day_type VARCHAR DEFAULT 'FULL_DAY',
    p_attachment_url TEXT DEFAULT NULL,
    p_contact_number TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_applicant_role VARCHAR;
    v_total_days INT;
    v_holiday_count INT := 0;
    v_overlap_count INT := 0;
    v_net_days NUMERIC(5, 1);
    v_leave_type_id UUID;
    v_req_id UUID;
    v_req_code VARCHAR(50);
BEGIN
    -- 1. Validate dates
    IF p_end_date < p_start_date THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'End date cannot be earlier than start date');
    END IF;

    v_total_days := (p_end_date - p_start_date + 1);

    -- 2. Count distinct public holiday & recurring holiday dates in range
    SELECT COUNT(DISTINCT d::DATE) INTO v_holiday_count
    FROM generate_series(p_start_date::DATE, p_end_date::DATE, '1 day'::interval) d
    WHERE EXISTS (
        -- Direct schedule match or recurring rule match
        SELECT 1 FROM public.schedules s
        LEFT JOIN public.calendars c ON s.calendar_id = c.id
        LEFT JOIN public.schedule_recurrence sr ON sr.schedule_id = s.id
        WHERE s.school_id = p_school_id
          AND s.deleted_at IS NULL
          AND (
              c.name ILIKE '%holiday%' OR c.name ILIKE '%holy%' OR c.type ILIKE '%holiday%'
              OR s.schedule_type ILIKE '%holiday%' OR s.schedule_type ILIKE '%holy%'
              OR s.category ILIKE '%holiday%' OR s.category ILIKE '%holy%'
              OR s.title ILIKE '%holiday%' OR s.title ILIKE '%holy%'
          )
          AND (
              -- Standard single/multi-day date match
              (
                  d::DATE >= (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE
                  AND d::DATE <= (s.end_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE
              )
              -- Recurring weekly holiday rule match (e.g. Sunday recurrence)
              OR (
                  sr.id IS NOT NULL
                  AND d::DATE >= (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE
                  AND (sr.end_date IS NULL OR d::DATE <= sr.end_date::DATE)
                  AND (
                      (sr.frequency = 'weekly' AND (
                          (sr.days_of_week IS NOT NULL AND jsonb_typeof(sr.days_of_week) = 'array' AND (
                              sr.days_of_week ? UPPER(TRIM(TO_CHAR(d::DATE, 'DY')))
                              OR sr.days_of_week ? SUBSTRING(UPPER(TRIM(TO_CHAR(d::DATE, 'DY'))) FROM 1 FOR 2)
                          ))
                          OR EXTRACT(DOW FROM d::DATE) = EXTRACT(DOW FROM (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE)
                      ))
                      OR (sr.frequency = 'daily' AND ((d::DATE - (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE) % GREATEST(sr.interval, 1) = 0))
                      OR (sr.frequency = 'monthly' AND EXTRACT(DAY FROM d::DATE) = EXTRACT(DAY FROM (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE))
                  )
              )
          )
    );

    -- 3. Count distinct already applied active leave dates in range (pending or approved)
    SELECT COUNT(DISTINCT d::DATE) INTO v_overlap_count
    FROM generate_series(p_start_date::DATE, p_end_date::DATE, '1 day'::interval) d
    WHERE EXISTS (
        SELECT 1 FROM public.leave_applications la
        WHERE la.applicant_id = p_applicant_id
          AND la.status IN ('pending', 'approved')
          AND d::DATE >= la.start_date::DATE
          AND d::DATE <= la.end_date::DATE
    );

    -- 4. Calculate Net Billable Days
    IF p_half_day_type IN ('FIRST_HALF', 'SECOND_HALF') THEN
        IF v_overlap_count > 0 THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'You already have an active leave request covering this date');
        END IF;
        IF v_holiday_count > 0 THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Selected date is an official Holiday. No leave application is required.');
        END IF;
        v_net_days := 0.5;
    ELSE
        -- Ensure non-double deduction
        v_net_days := (v_total_days - v_holiday_count - v_overlap_count)::NUMERIC(5, 1);
        IF v_net_days <= 0 THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'error', 'All selected dates are already covered by active leave requests (' || v_overlap_count || 'd) or holidays (' || v_holiday_count || 'd). No new leave days to apply.'
            );
        END IF;
    END IF;

    -- 5. Fetch applicant role
    SELECT role INTO v_applicant_role FROM public.profiles WHERE id = p_applicant_id;
    IF v_applicant_role IS NULL THEN
        v_applicant_role := 'staff';
    END IF;

    -- 6. Find Leave Type ID
    SELECT id INTO v_leave_type_id
    FROM public.leave_types
    WHERE (school_id = p_school_id OR school_id IS NULL)
      AND (name ILIKE p_leave_type OR code ILIKE p_leave_type)
    LIMIT 1;

    -- 7. Insert Leave Application
    INSERT INTO public.leave_applications (
        school_id, applicant_id, applicant_role, leave_type, leave_type_id,
        start_date, end_date, reason, half_day_type, attachment_url, contact_number,
        status, applied_at
    )
    VALUES (
        p_school_id, p_applicant_id, v_applicant_role, p_leave_type, v_leave_type_id,
        p_start_date, p_end_date, p_reason, p_half_day_type, p_attachment_url, p_contact_number,
        'pending', NOW()
    )
    RETURNING id, request_code INTO v_req_id, v_req_code;

    -- 8. Update pending days in leave balance with ONLY net billable days
    IF v_leave_type_id IS NOT NULL THEN
        UPDATE public.leave_balances
        SET pending_days = pending_days + v_net_days, updated_at = NOW()
        WHERE user_id = p_applicant_id AND leave_type_id = v_leave_type_id AND academic_year = '2026-2027';
    END IF;

    -- 9. Audit Log
    INSERT INTO public.leave_audit_logs (school_id, user_id, action, entity_type, entity_id, actor_id, new_value, reason)
    VALUES (
        p_school_id, p_applicant_id, 'APPLY', 'LEAVE_REQUEST', v_req_id, p_applicant_id,
        jsonb_build_object(
            'request_code', v_req_code,
            'leave_type', p_leave_type,
            'days', v_net_days,
            'total_calendar_days', v_total_days,
            'holiday_count', v_holiday_count,
            'overlap_count', v_overlap_count
        ),
        p_reason
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Leave application submitted successfully (' || v_net_days || ' net days)',
        'data', jsonb_build_object(
            'id', v_req_id,
            'request_code', v_req_code,
            'days_count', v_net_days,
            'total_calendar_days', v_total_days,
            'holidays_excluded', v_holiday_count,
            'overlap_days_excluded', v_overlap_count
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
