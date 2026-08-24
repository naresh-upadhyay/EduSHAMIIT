-- ============================================================================
-- Migration: 306_fn_apply_leave_holiday_exclusion.sql
-- Description:
--   1. Drops legacy restrictive applicant_role_check constraint on leave_applications
--      so all roles (super_admin, admin, principal, teacher, staff, student) can apply for leaves.
--   2. Updates fn_apply_leave_request stored procedure to dynamically exclude
--      public holidays and institutional calendar holidays from billable leave duration.
--   3. Enforces that only active (pending / approved) leave requests block overlapping dates,
--      allowing users to re-apply on dates of cancelled or rejected leave requests.
-- ============================================================================

-- 1. Ensure restrictive check constraint is dropped on leave_applications
ALTER TABLE public.leave_applications DROP CONSTRAINT IF EXISTS leave_applications_applicant_role_check;

-- 2. Enhanced fn_apply_leave_request with Public Holiday Exclusions
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
    v_days NUMERIC(5, 1);
    v_leave_type_id UUID;
    v_req_id UUID;
    v_req_code VARCHAR(50);
    v_holiday_count INT := 0;
BEGIN
    -- 1. Validate dates
    IF p_end_date < p_start_date THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'End date cannot be earlier than start date');
    END IF;

    -- 2. Count distinct public holiday dates overlapping the requested date range
    SELECT COUNT(DISTINCT d::DATE) INTO v_holiday_count
    FROM generate_series(p_start_date::DATE, p_end_date::DATE, '1 day'::interval) d
    WHERE EXISTS (
        SELECT 1 FROM public.schedules s
        LEFT JOIN public.calendars c ON s.calendar_id = c.id
        WHERE s.school_id = p_school_id
          AND (c.name ILIKE '%Public Holiday%' OR s.schedule_type ILIKE '%holiday%' OR s.category ILIKE '%holiday%')
          AND s.deleted_at IS NULL
          AND d::DATE >= s.start_time::DATE
          AND d::DATE <= s.end_time::DATE
    );

    -- 3. Calculate days count (excluding public holidays)
    IF p_half_day_type IN ('FIRST_HALF', 'SECOND_HALF') THEN
        v_days := 0.5;
    ELSE
        v_days := GREATEST(0.5, (p_end_date - p_start_date + 1 - v_holiday_count))::NUMERIC(5, 1);
    END IF;

    -- 4. Fetch applicant role
    SELECT role INTO v_applicant_role FROM public.profiles WHERE id = p_applicant_id;
    IF v_applicant_role IS NULL THEN
        v_applicant_role := 'staff';
    END IF;

    -- 5. Check for overlapping approved/pending requests (ignored for cancelled/rejected)
    IF EXISTS (
        SELECT 1 FROM public.leave_applications
        WHERE applicant_id = p_applicant_id
          AND status IN ('pending', 'approved')
          AND NOT (end_date < p_start_date OR start_date > p_end_date)
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'You already have an active leave request covering these dates');
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

    -- 8. Update pending days in leave balance if balance record exists
    IF v_leave_type_id IS NOT NULL THEN
        UPDATE public.leave_balances
        SET pending_days = pending_days + v_days, updated_at = NOW()
        WHERE user_id = p_applicant_id AND leave_type_id = v_leave_type_id AND academic_year = '2026-2027';
    END IF;

    -- 9. Audit Log
    INSERT INTO public.leave_audit_logs (school_id, user_id, action, entity_type, entity_id, actor_id, new_value, reason)
    VALUES (p_school_id, p_applicant_id, 'APPLY', 'LEAVE_REQUEST', v_req_id, p_applicant_id,
            jsonb_build_object('request_code', v_req_code, 'leave_type', p_leave_type, 'days', v_days, 'holiday_count', v_holiday_count), p_reason);

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Leave application submitted successfully',
        'data', jsonb_build_object('id', v_req_id, 'request_code', v_req_code, 'days_count', v_days, 'holidays_excluded', v_holiday_count)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
