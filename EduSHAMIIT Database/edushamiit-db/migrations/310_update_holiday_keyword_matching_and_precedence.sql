-- ============================================================================
-- Migration 310: Update Holiday Keyword Matching and Precedence for Leave Deductions
-- Ensures case-insensitive holiday keyword detection and holiday precedence
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_apply_leave_request(
    p_school_id uuid,
    p_applicant_id uuid,
    p_leave_type character varying,
    p_start_date date,
    p_end_date date,
    p_reason text,
    p_half_day_type character varying DEFAULT 'FULL_DAY'::character varying,
    p_attachment_url text DEFAULT NULL::text,
    p_contact_number text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
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

    -- 2. Count distinct public holiday & recurring holiday dates in range (Case-insensitive comprehensive holiday keyword matching)
    SELECT COUNT(DISTINCT d::DATE) INTO v_holiday_count
    FROM generate_series(p_start_date::DATE, p_end_date::DATE, '1 day'::interval) d
    WHERE EXISTS (
        SELECT 1 FROM public.schedules s
        LEFT JOIN public.calendars c ON s.calendar_id = c.id
        LEFT JOIN public.schedule_recurrence sr ON sr.schedule_id = s.id
        WHERE s.school_id = p_school_id
          AND s.deleted_at IS NULL
          AND (
              c.name ILIKE '%holiday%' OR c.name ILIKE '%holy%' OR c.name ILIKE '%vacation%' OR c.name ILIKE '%closure%'
              OR c.type ILIKE '%holiday%' OR c.type ILIKE '%school_events%'
              OR s.schedule_type ILIKE '%holiday%' OR s.schedule_type ILIKE '%holy%' OR s.schedule_type ILIKE '%vacation%' OR s.schedule_type ILIKE '%off%'
              OR s.category ILIKE '%holiday%' OR s.category ILIKE '%holy%' OR s.category ILIKE '%vacation%'
              OR s.title ILIKE '%holiday%' OR s.title ILIKE '%holy%' OR s.title ILIKE '%vacation%' OR s.title ILIKE '%closed%' OR s.title ILIKE '%off%'
              OR s.description ILIKE '%holiday%' OR s.description ILIKE '%holy%'
          )
          AND (
              -- Standard single/multi-day date match
              (
                  d::DATE >= (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE
                  AND d::DATE <= (s.end_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE
              )
              -- Recurring weekly/daily/monthly holiday rule match
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

    -- 3. Count distinct already applied active leave dates in range on NON-HOLIDAY days (Holiday takes precedence)
    SELECT COUNT(DISTINCT d::DATE) INTO v_overlap_count
    FROM generate_series(p_start_date::DATE, p_end_date::DATE, '1 day'::interval) d
    WHERE EXISTS (
        SELECT 1 FROM public.leave_applications la
        WHERE la.applicant_id = p_applicant_id
          AND la.status IN ('pending', 'approved')
          AND d::DATE >= la.start_date::DATE
          AND d::DATE <= la.end_date::DATE
    )
    AND NOT EXISTS (
        SELECT 1 FROM public.schedules s
        LEFT JOIN public.calendars c ON s.calendar_id = c.id
        LEFT JOIN public.schedule_recurrence sr ON sr.schedule_id = s.id
        WHERE s.school_id = p_school_id
          AND s.deleted_at IS NULL
          AND (
              c.name ILIKE '%holiday%' OR c.name ILIKE '%holy%' OR c.name ILIKE '%vacation%' OR c.name ILIKE '%closure%'
              OR c.type ILIKE '%holiday%' OR c.type ILIKE '%school_events%'
              OR s.schedule_type ILIKE '%holiday%' OR s.schedule_type ILIKE '%holy%' OR s.schedule_type ILIKE '%vacation%' OR s.schedule_type ILIKE '%off%'
              OR s.category ILIKE '%holiday%' OR s.category ILIKE '%holy%' OR s.category ILIKE '%vacation%'
              OR s.title ILIKE '%holiday%' OR s.title ILIKE '%holy%' OR s.title ILIKE '%vacation%' OR s.title ILIKE '%closed%' OR s.title ILIKE '%off%'
              OR s.description ILIKE '%holiday%' OR s.description ILIKE '%holy%'
          )
          AND (
              (
                  d::DATE >= (s.start_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE
                  AND d::DATE <= (s.end_time AT TIME ZONE COALESCE(s.timezone, 'Asia/Kolkata'))::DATE
              )
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

    -- 4. Calculate Net Billable Days
    IF p_half_day_type IN ('FIRST_HALF', 'SECOND_HALF') THEN
        IF v_holiday_count > 0 THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Selected date is an official Holiday. No leave application is required.');
        END IF;
        IF v_overlap_count > 0 THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'You already have an active leave request covering this date');
        END IF;
        v_net_days := 0.5;
    ELSE
        -- Ensure non-double deduction
        v_net_days := (v_total_days - v_holiday_count - v_overlap_count)::NUMERIC(5, 1);
        IF v_net_days <= 0 THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'error', 'All selected dates are already covered by holidays (' || v_holiday_count || 'd) or active leave requests (' || v_overlap_count || 'd). No new leave days to apply.'
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
$function$;
