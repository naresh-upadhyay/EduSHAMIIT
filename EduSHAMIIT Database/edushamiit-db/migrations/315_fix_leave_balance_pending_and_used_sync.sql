-- ============================================================================
-- Migration 315: Dynamic Leave Balances Recalculation, Pending & Used Sync
-- Guarantees:
--  1. Real-time dynamic pending_days and used_days tracking for all leave types
--  2. Infallible Upsert in fn_apply_leave_request and fn_process_leave_action
--  3. Real-time balance summary calculation in fn_get_leave_dashboard_and_requests
--  4. Full historical synchronization of all existing leave balances
-- ============================================================================

DROP FUNCTION IF EXISTS public.fn_apply_leave_request(UUID, UUID, VARCHAR, DATE, DATE, TEXT, VARCHAR, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.fn_apply_leave_request(UUID, UUID, VARCHAR, DATE, DATE, TEXT, VARCHAR, TEXT, VARCHAR);
DROP FUNCTION IF EXISTS public.fn_apply_leave_request;

DROP FUNCTION IF EXISTS public.fn_process_leave_action(UUID, UUID, VARCHAR, UUID, TEXT);
DROP FUNCTION IF EXISTS public.fn_process_leave_action(UUID, UUID, UUID, VARCHAR, TEXT);
DROP FUNCTION IF EXISTS public.fn_process_leave_action;

DROP FUNCTION IF EXISTS public.fn_get_leave_dashboard_and_requests(UUID, INT, INT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, DATE, DATE, TEXT, UUID, UUID);
DROP FUNCTION IF EXISTS public.fn_get_leave_dashboard_and_requests(UUID, UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, DATE, DATE, INT, INT, UUID);
DROP FUNCTION IF EXISTS public.fn_get_leave_dashboard_and_requests;

-- 1. Full Synchronization of public.leave_balances from leave_applications
DO $$
DECLARE
    r RECORD;
    v_used NUMERIC(5, 1);
    v_pending NUMERIC(5, 1);
BEGIN
    FOR r IN (
        SELECT DISTINCT 
            p.id AS user_id, 
            COALESCE(p.school_id, '11111111-1111-1111-1111-111111111111'::UUID) AS school_id,
            lt.id AS leave_type_id,
            lt.annual_entitlement
        FROM public.profiles p
        CROSS JOIN public.leave_types lt
        WHERE LOWER(COALESCE(p.status, 'active')) = 'active'
          AND lt.is_active = TRUE
          AND (lt.school_id = p.school_id OR lt.school_id IS NULL OR p.school_id IS NULL)
    ) LOOP
        -- Calculate actual used days
        SELECT COALESCE(SUM(la.billable_days), 0.0)
        INTO v_used
        FROM public.leave_applications la
        WHERE la.applicant_id = r.user_id
          AND (la.leave_type_id = r.leave_type_id OR UPPER(la.leave_type) = UPPER((SELECT name FROM public.leave_types WHERE id = r.leave_type_id)))
          AND LOWER(la.status) = 'approved';

        -- Calculate actual pending days
        SELECT COALESCE(SUM(la.billable_days), 0.0)
        INTO v_pending
        FROM public.leave_applications la
        WHERE la.applicant_id = r.user_id
          AND (la.leave_type_id = r.leave_type_id OR UPPER(la.leave_type) = UPPER((SELECT name FROM public.leave_types WHERE id = r.leave_type_id)))
          AND LOWER(la.status) = 'pending';

        -- Upsert balance record
        INSERT INTO public.leave_balances (
            school_id, user_id, leave_type_id, academic_year,
            allocated_days, used_days, pending_days, carried_forward_days, updated_at
        )
        VALUES (
            r.school_id, r.user_id, r.leave_type_id, '2026-2027',
            r.annual_entitlement, v_used, v_pending, 0.0, NOW()
        )
        ON CONFLICT (school_id, user_id, leave_type_id, academic_year)
        DO UPDATE SET
            allocated_days = EXCLUDED.allocated_days,
            used_days = EXCLUDED.used_days,
            pending_days = EXCLUDED.pending_days,
            updated_at = NOW();
    END LOOP;
END;
$$;


-- 2. Enhanced fn_apply_leave_request with Schedules Calendar Detection & Bulletproof Balances Upsert
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
RETURNS JSONB AS $function$
DECLARE
    v_applicant_role VARCHAR;
    v_total_days INT;
    v_holiday_count INT := 0;
    v_overlap_count INT := 0;
    v_net_days NUMERIC(5, 1);
    v_available_days NUMERIC(5, 1) := 0.0;
    v_leave_type_id UUID;
    v_annual_entitlement NUMERIC(5, 1);
    v_policy_roles TEXT[];
    v_allow_half_day BOOLEAN;
    v_doc_required BOOLEAN;
    v_doc_required_after_days NUMERIC(5, 1);
    v_req_id UUID;
    v_req_code VARCHAR(50);
    v_actual_used NUMERIC(5, 1) := 0.0;
    v_actual_pending NUMERIC(5, 1) := 0.0;
BEGIN
    -- 1. Validate dates
    IF p_end_date < p_start_date THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'End date cannot be earlier than start date');
    END IF;

    v_total_days := (p_end_date - p_start_date + 1);

    -- 2. Count distinct public holiday & recurring holiday dates in range
    SELECT COUNT(DISTINCT d::DATE) INTO v_holiday_count
    FROM generate_series(p_start_date::DATE, p_end_date::DATE, '1 day'::interval) d
    WHERE EXISTS (
        SELECT 1 FROM public.schedules s
        LEFT JOIN public.calendars c ON s.calendar_id = c.id
        LEFT JOIN public.schedule_recurrence sr ON sr.schedule_id = s.id
        WHERE (s.school_id = p_school_id OR s.school_id IS NULL)
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

    -- 3. Count distinct already applied active leave dates in range on NON-HOLIDAY days (Scoped strictly to applicant)
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
        WHERE (s.school_id = p_school_id OR s.school_id IS NULL)
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
            RETURN jsonb_build_object('success', FALSE, 'message', 'Selected date is an official Holiday. No leave application is required.');
        END IF;
        IF v_overlap_count > 0 THEN
            RETURN jsonb_build_object('success', FALSE, 'message', 'You already have an active leave request covering this date');
        END IF;
        v_net_days := 0.5;
    ELSE
        v_net_days := (v_total_days - v_holiday_count - v_overlap_count)::NUMERIC(5, 1);
        IF v_net_days <= 0 THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'message', 'All selected dates are already covered by holidays (' || v_holiday_count || 'd) or active leave requests (' || v_overlap_count || 'd). No new leave days to apply.'
            );
        END IF;
    END IF;

    -- 5. Fetch applicant role
    SELECT role INTO v_applicant_role FROM public.profiles WHERE id = p_applicant_id;
    IF v_applicant_role IS NULL THEN
        SELECT name INTO v_applicant_role FROM public.app_roles WHERE UPPER(COALESCE(status, 'ACTIVE')) = 'ACTIVE' ORDER BY display_order ASC LIMIT 1;
    END IF;

    -- 6. Find Leave Type ID & Validate Role Applicability
    SELECT id, annual_entitlement, allow_half_day, doc_required, doc_required_after_days, applicable_roles
    INTO v_leave_type_id, v_annual_entitlement, v_allow_half_day, v_doc_required, v_doc_required_after_days, v_policy_roles
    FROM public.leave_types
    WHERE (school_id = p_school_id OR school_id IS NULL)
      AND (name ILIKE p_leave_type OR code ILIKE p_leave_type)
      AND is_active = TRUE
    ORDER BY (CASE WHEN school_id = p_school_id THEN 0 ELSE 1 END) ASC
    LIMIT 1;

    IF v_leave_type_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Leave policy "' || p_leave_type || '" does not exist or is inactive.'
        );
    END IF;

    -- Enforce Role Scoping
    IF v_policy_roles IS NOT NULL AND array_length(v_policy_roles, 1) > 0 AND NOT ('all' = ANY(v_policy_roles)) THEN
        IF NOT (
            LOWER(v_applicant_role) IN ('super_admin', 'director', 'owner')
            OR LOWER(v_applicant_role) = ANY(ARRAY(SELECT LOWER(r) FROM unnest(v_policy_roles) r))
        ) THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'message', 'Leave policy "' || p_leave_type || '" is not applicable for your role (' || v_applicant_role || ').',
                'error', 'Leave policy "' || p_leave_type || '" is not applicable for your role (' || v_applicant_role || ').'
            );
        END IF;
    END IF;

    -- 7. Document requirement check
    IF COALESCE(v_doc_required, FALSE) AND (v_net_days > COALESCE(v_doc_required_after_days, 0)) THEN
        IF p_attachment_url IS NULL OR TRIM(p_attachment_url) = '' THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'message', 'Supporting medical/document attachment is mandatory for leaves exceeding ' || v_doc_required_after_days || ' days'
            );
        END IF;
    END IF;

    -- 8. Check real-time available balance
    SELECT COALESCE(SUM(la.billable_days), 0.0)
    INTO v_actual_used
    FROM public.leave_applications la
    WHERE la.applicant_id = p_applicant_id
      AND (la.leave_type_id = v_leave_type_id OR UPPER(la.leave_type) = UPPER(p_leave_type))
      AND LOWER(la.status) = 'approved';

    SELECT COALESCE(SUM(la.billable_days), 0.0)
    INTO v_actual_pending
    FROM public.leave_applications la
    WHERE la.applicant_id = p_applicant_id
      AND (la.leave_type_id = v_leave_type_id OR UPPER(la.leave_type) = UPPER(p_leave_type))
      AND LOWER(la.status) = 'pending';

    v_available_days := GREATEST(v_annual_entitlement - v_actual_used - v_actual_pending, 0.0);

    IF v_net_days > v_available_days THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Insufficient leave balance. Requested: ' || v_net_days || ' days, Available: ' || v_available_days || ' days (Used: ' || v_actual_used || 'd, Pending: ' || v_actual_pending || 'd, Quota: ' || v_annual_entitlement || 'd).'
        );
    END IF;

    -- 9. Generate Request Code & Insert Application
    v_req_code := 'LV-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(FLOOR(RANDOM() * 900 + 100)::TEXT, 3, '0');

    INSERT INTO public.leave_applications (
        school_id, applicant_id, leave_type_id, leave_type,
        start_date, end_date, reason, half_day_type, attachment_url, contact_number,
        billable_days, holidays_count, overlap_days_count,
        status, created_at
    )
    VALUES (
        p_school_id, p_applicant_id, v_leave_type_id, p_leave_type,
        p_start_date, p_end_date, p_reason, p_half_day_type, p_attachment_url, p_contact_number,
        v_net_days, v_holiday_count, v_overlap_count,
        'pending', NOW()
    )
    RETURNING id, request_code INTO v_req_id, v_req_code;

    -- 10. Synchronize & Upsert Leave Balance
    INSERT INTO public.leave_balances (
        school_id, user_id, leave_type_id, academic_year,
        allocated_days, used_days, pending_days, carried_forward_days, updated_at
    )
    VALUES (
        p_school_id, p_applicant_id, v_leave_type_id, '2026-2027',
        v_annual_entitlement, v_actual_used, v_actual_pending + v_net_days, 0.0, NOW()
    )
    ON CONFLICT (school_id, user_id, leave_type_id, academic_year)
    DO UPDATE SET
        allocated_days = EXCLUDED.allocated_days,
        used_days = EXCLUDED.used_days,
        pending_days = EXCLUDED.pending_days,
        updated_at = NOW();

    -- 11. Audit Log
    INSERT INTO public.leave_audit_logs (school_id, user_id, action, entity_type, entity_id, actor_id, new_value, reason)
    VALUES (
        p_school_id, p_applicant_id, 'APPLY', 'LEAVE_REQUEST', v_req_id, p_applicant_id,
        jsonb_build_object(
            'request_code', v_req_code,
            'leave_type', p_leave_type,
            'billable_days', v_net_days,
            'total_calendar_days', v_total_days,
            'holiday_count', v_holiday_count,
            'overlap_count', v_overlap_count
        ),
        p_reason
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Leave application submitted successfully (' || v_net_days || ' net billable days)',
        'data', jsonb_build_object(
            'id', v_req_id,
            'request_code', v_req_code,
            'days_count', v_net_days,
            'billable_days', v_net_days,
            'total_calendar_days', v_total_days,
            'holidays_excluded', v_holiday_count,
            'overlap_days_excluded', v_overlap_count
        )
    );
END;
$function$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Enhanced fn_process_leave_action with Complete Balance Recalculation
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

    v_days := COALESCE(v_leave.billable_days, CASE WHEN v_leave.half_day_type IN ('FIRST_HALF', 'SECOND_HALF') THEN 0.5 ELSE (v_leave.end_date - v_leave.start_date + 1)::NUMERIC(5, 1) END);

    IF UPPER(p_action) = 'APPROVE' THEN
        v_new_status := 'approved';
    ELSIF UPPER(p_action) = 'REJECT' THEN
        v_new_status := 'rejected';
    ELSIF UPPER(p_action) = 'CANCEL' THEN
        v_new_status := 'cancelled';
    ELSE
        RETURN jsonb_build_object('success', FALSE, 'message', 'Invalid action: ' || p_action);
    END IF;

    -- Update Application Status
    UPDATE public.leave_applications
    SET status = v_new_status,
        approved_by = CASE WHEN v_new_status = 'approved' THEN p_actor_id ELSE approved_by END,
        approved_at = CASE WHEN v_new_status = 'approved' THEN NOW() ELSE approved_at END,
        rejection_reason = CASE WHEN v_new_status = 'rejected' THEN p_remarks ELSE rejection_reason END,
        updated_at = NOW()
    WHERE id = p_leave_id;

    -- Recalculate and Synchronize Balances for Applicant
    SELECT annual_entitlement INTO v_annual_entitlement
    FROM public.leave_types
    WHERE id = v_leave.leave_type_id;
    v_annual_entitlement := COALESCE(v_annual_entitlement, 12.0);

    SELECT COALESCE(SUM(la.billable_days), 0.0)
    INTO v_actual_used
    FROM public.leave_applications la
    WHERE la.applicant_id = v_leave.applicant_id
      AND (la.leave_type_id = v_leave.leave_type_id OR UPPER(la.leave_type) = UPPER(v_leave.leave_type))
      AND LOWER(la.status) = 'approved';

    SELECT COALESCE(SUM(la.billable_days), 0.0)
    INTO v_actual_pending
    FROM public.leave_applications la
    WHERE la.applicant_id = v_leave.applicant_id
      AND (la.leave_type_id = v_leave.leave_type_id OR UPPER(la.leave_type) = UPPER(v_leave.leave_type))
      AND LOWER(la.status) = 'pending';

    INSERT INTO public.leave_balances (
        school_id, user_id, leave_type_id, academic_year,
        allocated_days, used_days, pending_days, carried_forward_days, updated_at
    )
    VALUES (
        p_school_id, v_leave.applicant_id, v_leave.leave_type_id, '2026-2027',
        v_annual_entitlement, v_actual_used, v_actual_pending, 0.0, NOW()
    )
    ON CONFLICT (school_id, user_id, leave_type_id, academic_year)
    DO UPDATE SET
        allocated_days = EXCLUDED.allocated_days,
        used_days = EXCLUDED.used_days,
        pending_days = EXCLUDED.pending_days,
        updated_at = NOW();

    -- Synchronize with Attendance if Approved
    IF v_new_status = 'approved' THEN
        IF LOWER(v_leave.applicant_role) = 'student' THEN
            SELECT class_id, section_id INTO v_class_id, v_section_id
            FROM public.student_class_assignments
            WHERE student_id = v_leave.applicant_id AND school_id = p_school_id
            LIMIT 1;

            v_cur_date := v_leave.start_date;
            WHILE v_cur_date <= v_leave.end_date LOOP
                INSERT INTO public.attendance_daily_records (
                    school_id, student_id, class_id, section_id, attendance_date, status, remarks, is_locked, is_all_day, created_by, updated_by
                )
                VALUES (
                    p_school_id, v_leave.applicant_id, v_class_id, v_section_id, v_cur_date, 'ON_LEAVE',
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
                    p_school_id, v_leave.applicant_id, v_cur_date, 'ON_LEAVE',
                    'Approved Leave: ' || v_leave.leave_type || ' (' || COALESCE(v_leave.reason, '') || ')', p_actor_id, p_actor_id
                )
                ON CONFLICT (school_id, employee_id, attendance_date)
                DO UPDATE SET status = 'ON_LEAVE', remarks = EXCLUDED.remarks, updated_by = p_actor_id, updated_at = NOW();

                v_cur_date := v_cur_date + 1;
            END LOOP;
        END IF;
    END IF;

    -- Audit Log
    INSERT INTO public.leave_audit_logs (school_id, user_id, action, entity_type, entity_id, actor_id, new_value, reason)
    VALUES (p_school_id, v_leave.applicant_id, UPPER(p_action), 'LEAVE_REQUEST', p_leave_id, p_actor_id,
            jsonb_build_object('status', v_new_status, 'request_code', v_leave.request_code, 'billable_days', v_days), p_remarks);

    RETURN jsonb_build_object('success', TRUE, 'message', 'Leave request ' || v_new_status || ' successfully');
END;
$function$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. Enhanced fn_get_leave_dashboard_and_requests with Real-Time Dynamic Fallbacks
CREATE OR REPLACE FUNCTION public.fn_get_leave_dashboard_and_requests(
    p_school_id uuid DEFAULT NULL,
    p_user_id uuid DEFAULT NULL,
    p_user_type character varying DEFAULT 'ALL'::character varying,
    p_department character varying DEFAULT 'ALL'::character varying,
    p_status character varying DEFAULT 'ALL'::character varying,
    p_leave_type character varying DEFAULT 'ALL'::character varying,
    p_search character varying DEFAULT ''::character varying,
    p_from_date date DEFAULT NULL::date,
    p_to_date date DEFAULT NULL::date,
    p_page integer DEFAULT 1,
    p_page_size integer DEFAULT 10,
    p_manager_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_offset INT;
    v_total_requests INT := 0;
    v_approved_count INT := 0;
    v_pending_count INT := 0;
    v_rejected_count INT := 0;
    v_cancelled_count INT := 0;
    v_filtered_count INT := 0;
    v_search_pattern TEXT;
    v_requests JSONB;
    v_balance_summary JSONB;
    v_upcoming_leaves JSONB;
    v_user_role VARCHAR;
BEGIN
    v_offset := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);
    v_search_pattern := '%' || LOWER(TRIM(COALESCE(p_search, ''))) || '%';

    IF p_user_id IS NOT NULL THEN
        SELECT role INTO v_user_role FROM public.profiles WHERE id = p_user_id;
    END IF;

    -- 1. Total Counts for KPI
    SELECT
        COUNT(*)::INT,
        COUNT(*) FILTER (WHERE LOWER(la.status) = 'approved')::INT,
        COUNT(*) FILTER (WHERE LOWER(la.status) = 'pending')::INT,
        COUNT(*) FILTER (WHERE LOWER(la.status) = 'rejected')::INT,
        COUNT(*) FILTER (WHERE LOWER(la.status) = 'cancelled')::INT
    INTO
        v_total_requests,
        v_approved_count,
        v_pending_count,
        v_rejected_count,
        v_cancelled_count
    FROM public.leave_applications la
    JOIN public.profiles p ON p.id = la.applicant_id
    WHERE (p_school_id IS NULL OR la.school_id = p_school_id OR la.school_id IS NULL)
      AND (p_manager_id IS NULL OR p.manager_id = p_manager_id);

    -- 2. Count Matching Filtered Records
    SELECT COUNT(*)::INT
    INTO v_filtered_count
    FROM public.leave_applications la
    JOIN public.profiles p ON p.id = la.applicant_id
    WHERE (p_school_id IS NULL OR la.school_id = p_school_id OR la.school_id IS NULL)
      AND (p_manager_id IS NULL OR p.manager_id = p_manager_id)
      AND (UPPER(p_status) = 'ALL' OR UPPER(la.status) = UPPER(p_status))
      AND (UPPER(p_user_type) = 'ALL' OR UPPER(COALESCE(la.applicant_role, p.role)) = UPPER(p_user_type))
      AND (UPPER(p_department) = 'ALL' OR UPPER(COALESCE(p.department, 'General')) = UPPER(p_department))
      AND (UPPER(p_leave_type) = 'ALL' OR UPPER(la.leave_type) = UPPER(p_leave_type))
      AND (p_from_date IS NULL OR la.start_date >= p_from_date)
      AND (p_to_date IS NULL OR la.end_date <= p_to_date)
      AND (
          p_search IS NULL OR p_search = '' OR
          LOWER(p.full_name) LIKE v_search_pattern OR
          LOWER(COALESCE(p.employee_id, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(la.request_code, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(p.department, '')) LIKE v_search_pattern OR
          LOWER(la.reason) LIKE v_search_pattern
      );

    -- 3. Fetch Filtered Requests List with Pagination
    SELECT COALESCE(jsonb_agg(r), '[]'::jsonb)
    INTO v_requests
    FROM (
        SELECT
            la.id,
            la.request_code,
            la.applicant_id,
            p.full_name AS applicant_name,
            p.avatar_url,
            COALESCE(p.employee_id, SUBSTRING(p.id::TEXT FROM 1 FOR 8)) AS employee_id,
            COALESCE(p.department, 'General') AS department,
            COALESCE(la.applicant_role, p.role) AS role,
            la.leave_type_id,
            la.leave_type,
            COALESCE(lt.color_hex, '#4F46E5') AS color_hex,
            la.start_date,
            la.end_date,
            COALESCE(la.billable_days, CASE WHEN la.half_day_type IN ('FIRST_HALF', 'SECOND_HALF') THEN 0.5 ELSE (la.end_date - la.start_date + 1)::NUMERIC(5, 1) END) AS days_count,
            (la.end_date - la.start_date + 1)::INT AS total_calendar_days,
            COALESCE(la.holidays_count, 0) AS holidays_count,
            COALESCE(la.overlap_days_count, 0) AS overlap_days_count,
            la.half_day_type,
            la.reason,
            la.status,
            la.attachment_url,
            la.contact_number,
            la.created_at,
            la.approved_at,
            la.approved_by,
            la.rejection_reason
        FROM public.leave_applications la
        JOIN public.profiles p ON p.id = la.applicant_id
        LEFT JOIN public.leave_types lt ON lt.id = la.leave_type_id
        WHERE (p_school_id IS NULL OR la.school_id = p_school_id OR la.school_id IS NULL)
          AND (p_manager_id IS NULL OR p.manager_id = p_manager_id)
          AND (UPPER(p_status) = 'ALL' OR UPPER(la.status) = UPPER(p_status))
          AND (UPPER(p_user_type) = 'ALL' OR UPPER(COALESCE(la.applicant_role, p.role)) = UPPER(p_user_type))
          AND (UPPER(p_department) = 'ALL' OR UPPER(COALESCE(p.department, 'General')) = UPPER(p_department))
          AND (UPPER(p_leave_type) = 'ALL' OR UPPER(la.leave_type) = UPPER(p_leave_type))
          AND (p_from_date IS NULL OR la.start_date >= p_from_date)
          AND (p_to_date IS NULL OR la.end_date <= p_to_date)
          AND (
              p_search IS NULL OR p_search = '' OR
              LOWER(p.full_name) LIKE v_search_pattern OR
              LOWER(COALESCE(p.employee_id, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(la.request_code, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(p.department, '')) LIKE v_search_pattern OR
              LOWER(la.reason) LIKE v_search_pattern
          )
        ORDER BY la.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) r;

    -- 4. Balance Summary (Scoped to p_user_id & user role, with Real-Time Aggregation Fallback)
    WITH active_distinct_types AS (
        SELECT DISTINCT ON (LOWER(lt.code))
            lt.id, lt.name, lt.code, lt.color_hex, lt.annual_entitlement, lt.applicable_roles
        FROM public.leave_types lt
        WHERE (
            (p_school_id IS NOT NULL AND lt.school_id = p_school_id)
            OR (lt.school_id IS NULL)
        )
          AND lt.is_active = TRUE
        ORDER BY LOWER(lt.code) ASC, (CASE WHEN lt.school_id = p_school_id THEN 0 ELSE 1 END) ASC
    )
    SELECT COALESCE(jsonb_agg(b), '[]'::jsonb)
    INTO v_balance_summary
    FROM (
        SELECT
            adt.id AS leave_type_id,
            adt.name AS leave_type_name,
            adt.code AS leave_type_code,
            COALESCE(adt.color_hex, '#4F46E5') AS color_hex,
            COALESCE(lb.allocated_days, adt.annual_entitlement) AS allocated_days,
            COALESCE(
                lb.used_days,
                (SELECT COALESCE(SUM(la.billable_days), 0.0) FROM public.leave_applications la WHERE la.applicant_id = p_user_id AND (la.leave_type_id = adt.id OR UPPER(la.leave_type) = UPPER(adt.name) OR UPPER(la.leave_type) = UPPER(adt.code)) AND LOWER(la.status) = 'approved'),
                0.0
            ) AS used_days,
            COALESCE(
                lb.pending_days,
                (SELECT COALESCE(SUM(la.billable_days), 0.0) FROM public.leave_applications la WHERE la.applicant_id = p_user_id AND (la.leave_type_id = adt.id OR UPPER(la.leave_type) = UPPER(adt.name) OR UPPER(la.leave_type) = UPPER(adt.code)) AND LOWER(la.status) = 'pending'),
                0.0
            ) AS pending_days,
            GREATEST(
                COALESCE(lb.allocated_days, adt.annual_entitlement) + COALESCE(lb.carried_forward_days, 0.0)
                - COALESCE(lb.used_days, (SELECT COALESCE(SUM(la.billable_days), 0.0) FROM public.leave_applications la WHERE la.applicant_id = p_user_id AND (la.leave_type_id = adt.id OR UPPER(la.leave_type) = UPPER(adt.name) OR UPPER(la.leave_type) = UPPER(adt.code)) AND LOWER(la.status) = 'approved'), 0.0)
                - COALESCE(lb.pending_days, (SELECT COALESCE(SUM(la.billable_days), 0.0) FROM public.leave_applications la WHERE la.applicant_id = p_user_id AND (la.leave_type_id = adt.id OR UPPER(la.leave_type) = UPPER(adt.name) OR UPPER(la.leave_type) = UPPER(adt.code)) AND LOWER(la.status) = 'pending'), 0.0),
                0.0
            ) AS available_days,
            adt.applicable_roles
        FROM active_distinct_types adt
        LEFT JOIN public.leave_balances lb ON (lb.leave_type_id = adt.id AND (p_user_id IS NULL OR lb.user_id = p_user_id) AND lb.academic_year = '2026-2027')
        WHERE (
            p_user_id IS NULL
            OR v_user_role IS NULL
            OR adt.applicable_roles IS NULL 
            OR array_length(adt.applicable_roles, 1) IS NULL 
            OR array_length(adt.applicable_roles, 1) = 0
            OR 'all' = ANY(adt.applicable_roles)
            OR LOWER(v_user_role) = ANY(ARRAY(SELECT LOWER(r) FROM unnest(adt.applicable_roles) r))
        )
        ORDER BY adt.name ASC, adt.id ASC
    ) b;

    -- 5. Upcoming Leaves (Next 5 Approved Leaves)
    SELECT COALESCE(jsonb_agg(u), '[]'::jsonb)
    INTO v_upcoming_leaves
    FROM (
        SELECT
            la.id,
            p.full_name AS employee_name,
            p.avatar_url,
            la.leave_type,
            la.start_date,
            la.end_date,
            TO_CHAR(la.start_date, 'DD Mon') || CASE WHEN la.start_date != la.end_date THEN ' - ' || TO_CHAR(la.end_date, 'DD Mon') ELSE '' END AS date_range_formatted
        FROM public.leave_applications la
        JOIN public.profiles p ON p.id = la.applicant_id
        WHERE (p_school_id IS NULL OR la.school_id = p_school_id OR la.school_id IS NULL)
          AND LOWER(la.status) = 'approved'
          AND la.end_date >= CURRENT_DATE
        ORDER BY la.start_date ASC
        LIMIT 5
    ) u;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'kpi', jsonb_build_object(
                'total_requests', v_total_requests,
                'approved_leaves', v_approved_count,
                'pending_approvals', v_pending_count,
                'rejected_leaves', v_rejected_count,
                'cancelled_leaves', v_cancelled_count,
                'filtered_count', v_filtered_count
            ),
            'requests', v_requests,
            'balance_summary', v_balance_summary,
            'upcoming_leaves', v_upcoming_leaves,
            'page', p_page,
            'page_size', p_page_size,
            'total_count', v_filtered_count,
            'total_pages', GREATEST(CEIL(v_filtered_count::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)::INT, 1)
        )
    );
END;
$function$;
