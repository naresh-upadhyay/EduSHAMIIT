-- ============================================================================
-- Migration 318: Unified Leave Deductions Engine & Policy Dynamic Sync
-- ============================================================================
-- 1. Updates fn_apply_leave_request:
--    - Accepts client calculated billable_days directly (p_billable_days).
--    - Uses official calendar events, schedules, and school_holidays for holiday exclusions.
--    - Eliminates strict blocking of historical overlaps, saving the exact calculated days.
-- 2. Updates fn_get_leave_dashboard_and_requests:
--    - Returns dynamic active leave type name and color via LATERAL join.
--    - Returns accurate total_count and pagination.
--    - Computes real-time available_days = allocated_days + carried_forward - approved_used - pending_days.
-- ============================================================================

DROP FUNCTION IF EXISTS public.fn_apply_leave_request(UUID, UUID, VARCHAR, DATE, DATE, TEXT, VARCHAR, TEXT, VARCHAR);
DROP FUNCTION IF EXISTS public.fn_apply_leave_request(UUID, UUID, VARCHAR, DATE, DATE, TEXT, VARCHAR, TEXT, VARCHAR, NUMERIC);
DROP FUNCTION IF EXISTS public.fn_apply_leave_request;

-- 1. Update fn_apply_leave_request
CREATE OR REPLACE FUNCTION public.fn_apply_leave_request(
    p_school_id UUID,
    p_applicant_id UUID,
    p_leave_type VARCHAR,
    p_start_date DATE,
    p_end_date DATE,
    p_reason TEXT,
    p_half_day_type VARCHAR DEFAULT 'FULL_DAY',
    p_attachment_url TEXT DEFAULT NULL,
    p_contact_number VARCHAR DEFAULT NULL,
    p_billable_days NUMERIC(5, 1) DEFAULT NULL
)
RETURNS JSONB AS $function$
DECLARE
    v_leave_type_id UUID;
    v_leave_type_name VARCHAR;
    v_annual_entitlement NUMERIC(5, 1);
    v_allow_half_day BOOLEAN;
    v_policy_roles TEXT[];
    v_applicant_role VARCHAR;
    v_total_days INT;
    v_billable_days NUMERIC(5, 1);
    v_holidays_count INT := 0;
    v_overlap_count INT := 0;
    v_cur_date DATE;
    v_is_holiday BOOLEAN;
    v_has_overlap BOOLEAN;
    v_actual_used NUMERIC(5, 1) := 0.0;
    v_actual_pending NUMERIC(5, 1) := 0.0;
    v_custom_allocated NUMERIC(5, 1);
    v_carried_forward NUMERIC(5, 1) := 0.0;
    v_effective_total NUMERIC(5, 1);
    v_available_balance NUMERIC(5, 1);
    v_req_id UUID;
    v_req_code VARCHAR;
    v_applicant_name VARCHAR;
    v_applicant_email VARCHAR;
    v_acad_year VARCHAR;
BEGIN
    -- Resolve dynamic academic year from start_date
    v_acad_year := public.fn_resolve_academic_year(p_start_date, p_school_id);

    -- Basic Validations
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Start date and end date are required.', 'error', 'Start date and end date are required.');
    END IF;

    IF p_start_date > p_end_date THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Start date cannot be after end date.', 'error', 'Start date cannot be after end date.');
    END IF;

    IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Reason for leave application is mandatory.', 'error', 'Reason for leave application is mandatory.');
    END IF;

    -- Fetch Applicant Details
    SELECT role, full_name, email, school_id
    INTO v_applicant_role, v_applicant_name, v_applicant_email, p_school_id
    FROM public.profiles
    WHERE id = p_applicant_id;

    IF v_applicant_role IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Applicant profile not found.', 'error', 'Applicant profile not found.');
    END IF;

    -- Fetch Leave Policy
    SELECT id, name, annual_entitlement, allow_half_day, applicable_roles
    INTO v_leave_type_id, v_leave_type_name, v_annual_entitlement, v_allow_half_day, v_policy_roles
    FROM public.leave_types
    WHERE (school_id = p_school_id OR school_id IS NULL)
      AND (UPPER(name) = UPPER(p_leave_type) OR UPPER(code) = UPPER(p_leave_type) OR id::TEXT = p_leave_type)
      AND is_active = TRUE
    ORDER BY (school_id = p_school_id) DESC, school_id NULLS LAST
    LIMIT 1;

    IF v_leave_type_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Invalid or inactive leave policy: ' || p_leave_type, 'error', 'Invalid or inactive leave policy: ' || p_leave_type);
    END IF;

    -- Enforce Strict Role Scoping (Zero Bypasses)
    IF v_policy_roles IS NOT NULL AND array_length(v_policy_roles, 1) > 0 THEN
        IF NOT (
            'all' = ANY(ARRAY(SELECT LOWER(r) FROM unnest(v_policy_roles) r))
            OR LOWER(v_applicant_role) = ANY(ARRAY(SELECT LOWER(r) FROM unnest(v_policy_roles) r))
        ) THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'message', 'Leave policy "' || v_leave_type_name || '" is not applicable for your role (' || v_applicant_role || ').',
                'error', 'Leave policy "' || v_leave_type_name || '" is not applicable for your role (' || v_applicant_role || ').'
            );
        END IF;
    END IF;

    -- Validate Half-Day
    IF p_half_day_type IN ('FIRST_HALF', 'SECOND_HALF') THEN
        IF p_start_date != p_end_date THEN
            RETURN jsonb_build_object('success', FALSE, 'message', 'Half-day leaves can only be applied for a single calendar day.', 'error', 'Half-day leaves can only be applied for a single calendar day.');
        END IF;
        IF NOT COALESCE(v_allow_half_day, TRUE) THEN
            RETURN jsonb_build_object('success', FALSE, 'message', 'Half-day leaves are not permitted for this leave type.', 'error', 'Half-day leaves are not permitted for this leave type.');
        END IF;
    END IF;

    -- Calculate Smart Calendar Exclusions
    v_total_days := (p_end_date - p_start_date) + 1;
    v_cur_date := p_start_date;

    WHILE v_cur_date <= p_end_date LOOP
        v_is_holiday := FALSE;
        v_has_overlap := FALSE;

        -- 1. Check official school events holidays
        SELECT EXISTS(
            SELECT 1 FROM public.events
            WHERE (school_id = p_school_id OR school_id IS NULL)
              AND (category ILIKE '%holiday%' OR category ILIKE '%holy%' OR category ILIKE '%vacation%' OR title ILIKE '%holiday%' OR title ILIKE '%vacation%' OR title ILIKE '%closed%' OR title ILIKE '%break%')
              AND v_cur_date BETWEEN event_date AND event_date
        ) INTO v_is_holiday;

        -- 2. Check calendar schedules holidays (Single + Recurring with schedule_recurrence)
        IF NOT v_is_holiday THEN
            SELECT EXISTS(
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
            -- Check overlap with approved or pending applications
            SELECT EXISTS(
                SELECT 1 FROM public.leave_applications
                WHERE applicant_id = p_applicant_id
                  AND LOWER(status) IN ('approved', 'pending')
                  AND v_cur_date BETWEEN start_date AND end_date
            ) INTO v_has_overlap;

            IF v_has_overlap THEN
                v_overlap_count := v_overlap_count + 1;
            END IF;
        END IF;

        v_cur_date := v_cur_date + 1;
    END LOOP;

    -- If client sent explicitly calculated billable_days, honor it directly!
    IF p_billable_days IS NOT NULL AND p_billable_days >= 0 THEN
        v_billable_days := p_billable_days;
    ELSIF p_half_day_type IN ('FIRST_HALF', 'SECOND_HALF') THEN
        IF v_holidays_count > 0 THEN
            RETURN jsonb_build_object('success', FALSE, 'message', 'Selected date is an official Holiday. No leave application is required.', 'error', 'Selected date is an official Holiday.');
        END IF;
        IF v_overlap_count > 0 THEN
            RETURN jsonb_build_object('success', FALSE, 'message', 'Selected date is already covered by an existing leave application.', 'error', 'Selected date is already covered by an existing leave application.');
        END IF;
        v_billable_days := 0.5;
    ELSE
        v_billable_days := GREATEST(0, (v_total_days - v_holidays_count - v_overlap_count))::NUMERIC(5, 1);
    END IF;

    IF v_billable_days <= 0 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'All selected dates are already covered by holidays (' || v_holidays_count || 'd) or active leave requests (' || v_overlap_count || 'd). No new leave days to apply.',
            'error', 'All selected dates are already covered by holidays or active leave requests.'
        );
    END IF;

    -- Fetch actual Used and Pending days from SSOT ledger
    SELECT COALESCE(SUM(billable_days), 0.0)
    INTO v_actual_used
    FROM public.leave_applications
    WHERE applicant_id = p_applicant_id
      AND (leave_type_id = v_leave_type_id OR UPPER(leave_type) = UPPER(v_leave_type_name))
      AND public.fn_resolve_academic_year(start_date, school_id) = v_acad_year
      AND LOWER(status) = 'approved';

    SELECT COALESCE(SUM(billable_days), 0.0)
    INTO v_actual_pending
    FROM public.leave_applications
    WHERE applicant_id = p_applicant_id
      AND (leave_type_id = v_leave_type_id OR UPPER(leave_type) = UPPER(v_leave_type_name))
      AND public.fn_resolve_academic_year(start_date, school_id) = v_acad_year
      AND LOWER(status) = 'pending';

    -- Fetch custom allocated days
    SELECT allocated_days, carried_forward_days
    INTO v_custom_allocated, v_carried_forward
    FROM public.leave_balances
    WHERE user_id = p_applicant_id
      AND leave_type_id = v_leave_type_id
      AND public.fn_normalize_academic_year(academic_year) = v_acad_year;

    v_effective_total := COALESCE(v_custom_allocated, v_annual_entitlement, 12.0) + COALESCE(v_carried_forward, 0.0);
    v_available_balance := GREATEST(0.0, v_effective_total - v_actual_used - v_actual_pending);

    IF v_billable_days > v_available_balance THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Insufficient leave balance. Requested: ' || v_billable_days || ' days, Available: ' || v_available_balance || ' days (Used: ' || v_actual_used || 'd, Pending: ' || v_actual_pending || 'd, Quota: ' || v_effective_total || 'd).',
            'error', 'Insufficient leave balance. Requested: ' || v_billable_days || ' days, Available: ' || v_available_balance || ' days (Used: ' || v_actual_used || 'd, Pending: ' || v_actual_pending || 'd, Quota: ' || v_effective_total || 'd).'
        );
    END IF;

    -- Generate Application Record
    v_req_id := gen_random_uuid();
    v_req_code := 'LV-' || TO_CHAR(CURRENT_DATE, 'YYYY') || '-' || LPAD((FLOOR(RANDOM() * 900) + 100)::TEXT, 3, '0');

    INSERT INTO public.leave_applications (
        id, school_id, applicant_id, applicant_role, leave_type_id, leave_type,
        start_date, end_date, billable_days, half_day_type,
        reason, status, attachment_url, contact_number, request_code,
        applied_at, created_at, updated_at
    )
    VALUES (
        v_req_id, p_school_id, p_applicant_id, v_applicant_role, v_leave_type_id, v_leave_type_name,
        p_start_date, p_end_date, v_billable_days, p_half_day_type,
        p_reason, 'pending', p_attachment_url, p_contact_number, v_req_code,
        NOW(), NOW(), NOW()
    );

    -- Log Audit Trail
    INSERT INTO public.attendance_audit_logs (
        school_id, user_id, action, record_type, record_id,
        new_value, reason
    )
    VALUES (
        p_school_id, p_applicant_id, 'LEAVE_APPLY', 'LEAVE_APPLICATION', v_req_id,
        jsonb_build_object('request_code', v_req_code, 'billable_days', v_billable_days, 'academic_year', v_acad_year),
        p_reason
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Leave application submitted successfully (' || v_billable_days || ' net billable days in ' || v_acad_year || ')',
        'data', jsonb_build_object(
            'id', v_req_id,
            'request_code', v_req_code,
            'academic_year', v_acad_year,
            'total_calendar_days', v_total_days,
            'holidays_excluded', v_holidays_count,
            'overlap_days_excluded', v_overlap_count,
            'billable_days', v_billable_days,
            'days_count', v_billable_days
        )
    );
END;
$function$ LANGUAGE plpgsql;

-- 2. Enhanced fn_get_leave_dashboard_and_requests with Dynamic Policy Sync
CREATE OR REPLACE FUNCTION public.fn_get_leave_dashboard_and_requests(
    p_school_id UUID,
    p_user_id UUID,
    p_user_type VARCHAR DEFAULT 'ALL',
    p_department VARCHAR DEFAULT 'ALL',
    p_status VARCHAR DEFAULT 'ALL',
    p_leave_type VARCHAR DEFAULT 'ALL',
    p_search VARCHAR DEFAULT '',
    p_from_date DATE DEFAULT NULL,
    p_to_date DATE DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_manager_id UUID DEFAULT NULL,
    p_academic_year VARCHAR DEFAULT NULL
)
RETURNS JSONB AS $function$
DECLARE
    v_user_role VARCHAR;
    v_kpi JSONB;
    v_requests JSONB;
    v_balance_summary JSONB;
    v_upcoming JSONB;
    v_total_requests INT;
    v_offset INT;
    v_search_pattern TEXT;
    v_acad_year VARCHAR;
BEGIN
    -- Determine target academic year
    IF p_academic_year IS NOT NULL AND UPPER(TRIM(p_academic_year)) != 'ALL' THEN
        v_acad_year := public.fn_normalize_academic_year(p_academic_year);
    ELSE
        v_acad_year := public.fn_resolve_academic_year(CURRENT_DATE, p_school_id);
    END IF;

    v_offset := GREATEST(0, (p_page - 1) * p_page_size);
    v_search_pattern := '%' || LOWER(TRIM(COALESCE(p_search, ''))) || '%';

    -- Get requesting user's role
    SELECT LOWER(role) INTO v_user_role FROM public.profiles WHERE id = p_user_id;

    -- 1. Compute KPI Cards strictly for the active academic year
    SELECT jsonb_build_object(
        'total_requests', COUNT(*),
        'approved_leaves', COUNT(*) FILTER (WHERE LOWER(la.status) = 'approved'),
        'pending_requests', COUNT(*) FILTER (WHERE LOWER(la.status) = 'pending'),
        'rejected_leaves', COUNT(*) FILTER (WHERE LOWER(la.status) = 'rejected'),
        'cancelled_leaves', COUNT(*) FILTER (WHERE LOWER(la.status) = 'cancelled'),
        'approved_percentage', ROUND((COUNT(*) FILTER (WHERE LOWER(la.status) = 'approved')::NUMERIC / GREATEST(COUNT(*), 1)::NUMERIC) * 100, 1),
        'pending_percentage', ROUND((COUNT(*) FILTER (WHERE LOWER(la.status) = 'pending')::NUMERIC / GREATEST(COUNT(*), 1)::NUMERIC) * 100, 1),
        'rejected_percentage', ROUND((COUNT(*) FILTER (WHERE LOWER(la.status) = 'rejected')::NUMERIC / GREATEST(COUNT(*), 1)::NUMERIC) * 100, 1),
        'cancelled_percentage', ROUND((COUNT(*) FILTER (WHERE LOWER(la.status) = 'cancelled')::NUMERIC / GREATEST(COUNT(*), 1)::NUMERIC) * 100, 1)
    )
    INTO v_kpi
    FROM public.leave_applications la
    JOIN public.profiles p ON p.id = la.applicant_id
    WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
      AND public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year
      AND (p_user_type = 'ALL' OR UPPER(COALESCE(la.applicant_role, p.role)) = UPPER(p_user_type))
      AND (p_department = 'ALL' OR UPPER(COALESCE(p.department, 'General')) = UPPER(p_department))
      AND (p_manager_id IS NULL OR p.manager_id = p_manager_id OR la.applicant_id = p_manager_id);

    -- 2. Compute Right Sidebar Balance Summary for p_user_id (Strict Role Scoping)
    SELECT COALESCE(jsonb_agg(b), '[]'::jsonb)
    INTO v_balance_summary
    FROM (
        SELECT
            lt.id AS leave_type_id,
            lt.name AS leave_type_name,
            lt.code AS leave_type_code,
            COALESCE(lt.color_hex, '#4F46E5') AS color_hex,
            lt.applicable_roles,
            v_acad_year AS academic_year,
            COALESCE(lb.allocated_days, lt.annual_entitlement, 12.0) AS allocated_days,
            COALESCE(
                (SELECT SUM(la.billable_days) 
                 FROM public.leave_applications la 
                 WHERE la.applicant_id = p_user_id 
                   AND (la.leave_type_id = lt.id OR UPPER(la.leave_type) = UPPER(lt.name))
                   AND public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year
                   AND LOWER(la.status) = 'approved'),
                lb.used_days,
                0.0
            ) AS used_days,
            COALESCE(
                (SELECT SUM(la.billable_days) 
                 FROM public.leave_applications la 
                 WHERE la.applicant_id = p_user_id 
                   AND (la.leave_type_id = lt.id OR UPPER(la.leave_type) = UPPER(lt.name))
                   AND public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year
                   AND LOWER(la.status) = 'pending'),
                lb.pending_days,
                0.0
            ) AS pending_days,
            GREATEST(0.0,
                (COALESCE(lb.allocated_days, lt.annual_entitlement, 12.0) + COALESCE(lb.carried_forward_days, 0.0)) -
                COALESCE(
                    (SELECT SUM(la.billable_days) 
                     FROM public.leave_applications la 
                     WHERE la.applicant_id = p_user_id 
                       AND (la.leave_type_id = lt.id OR UPPER(la.leave_type) = UPPER(lt.name))
                       AND public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year
                       AND LOWER(la.status) = 'approved'),
                    lb.used_days,
                    0.0
                ) -
                COALESCE(
                    (SELECT SUM(la.billable_days) 
                     FROM public.leave_applications la 
                     WHERE la.applicant_id = p_user_id 
                       AND (la.leave_type_id = lt.id OR UPPER(la.leave_type) = UPPER(lt.name))
                       AND public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year
                       AND LOWER(la.status) = 'pending'),
                    lb.pending_days,
                    0.0
                )
            ) AS available_days
        FROM public.leave_types lt
        LEFT JOIN public.leave_balances lb ON lb.leave_type_id = lt.id 
              AND lb.user_id = p_user_id 
              AND public.fn_normalize_academic_year(lb.academic_year) = v_acad_year
        WHERE lt.is_active = TRUE
          AND (lt.school_id = p_school_id OR lt.school_id IS NULL)
          AND (
              lt.applicable_roles IS NULL 
              OR array_length(lt.applicable_roles, 1) IS NULL
              OR array_length(lt.applicable_roles, 1) = 0
              OR 'all' = ANY(ARRAY(SELECT LOWER(r) FROM unnest(lt.applicable_roles) r))
              OR v_user_role = ANY(ARRAY(SELECT LOWER(r) FROM unnest(lt.applicable_roles) r))
          )
        ORDER BY lt.name ASC
    ) b;

    -- 3. Fetch Filtered Requests List with Pagination (LATERAL Join for Anti-Duplication)
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
            COALESCE(la.applicant_role, p.role) AS applicant_role,
            COALESCE(la.applicant_role, p.role) AS role,
            la.leave_type_id,
            COALESCE(lt.name, la.leave_type) AS leave_type,
            COALESCE(lt.color_hex, '#4F46E5') AS color_hex,
            COALESCE(lt.color_hex, '#4F46E5') AS leave_type_color,
            la.start_date,
            la.end_date,
            COALESCE(la.billable_days, la.duration_days, 1.0) AS billable_days,
            COALESCE(la.billable_days, la.duration_days, 1.0) AS days_count,
            la.duration_days,
            la.half_day_type,
            la.reason,
            la.status,
            la.attachment_url,
            la.contact_number,
            la.created_at,
            la.applied_at,
            la.approved_at,
            la.remarks,
            ap.full_name AS approved_by_name
        FROM public.leave_applications la
        JOIN public.profiles p ON p.id = la.applicant_id
        LEFT JOIN LATERAL (
            SELECT lt.name, lt.color_hex 
            FROM public.leave_types lt 
            WHERE (lt.id = la.leave_type_id OR UPPER(lt.name) = UPPER(la.leave_type)) 
              AND (lt.school_id = la.school_id OR lt.school_id IS NULL)
            ORDER BY (lt.id = la.leave_type_id) DESC, (lt.school_id IS NOT NULL) DESC
            LIMIT 1
        ) lt ON TRUE
        LEFT JOIN public.profiles ap ON ap.id = la.approved_by
        WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
          AND (v_acad_year IS NULL OR public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year)
          AND (p_user_type = 'ALL' OR UPPER(COALESCE(la.applicant_role, p.role)) = UPPER(p_user_type))
          AND (p_department = 'ALL' OR UPPER(COALESCE(p.department, 'General')) = UPPER(p_department))
          AND (p_status = 'ALL' OR LOWER(la.status) = LOWER(p_status))
          AND (p_leave_type = 'ALL' OR UPPER(la.leave_type) = UPPER(p_leave_type) OR (la.leave_type_id IS NOT NULL AND la.leave_type_id::TEXT = p_leave_type))
          AND (p_from_date IS NULL OR la.start_date >= p_from_date)
          AND (p_to_date IS NULL OR la.end_date <= p_to_date)
          AND (p_manager_id IS NULL OR p.manager_id = p_manager_id OR la.applicant_id = p_manager_id)
          AND (
              p_search IS NULL OR p_search = '' OR
              LOWER(COALESCE(la.request_code, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(p.full_name, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(p.employee_id, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(la.leave_type, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(la.reason, '')) LIKE v_search_pattern
          )
        ORDER BY la.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) r;

    -- Total Filtered Count strictly matching requests query
    SELECT COUNT(DISTINCT la.id)
    INTO v_total_requests
    FROM public.leave_applications la
    JOIN public.profiles p ON p.id = la.applicant_id
    WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
      AND (v_acad_year IS NULL OR public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year)
      AND (p_user_type = 'ALL' OR UPPER(COALESCE(la.applicant_role, p.role)) = UPPER(p_user_type))
      AND (p_department = 'ALL' OR UPPER(COALESCE(p.department, 'General')) = UPPER(p_department))
      AND (p_status = 'ALL' OR LOWER(la.status) = LOWER(p_status))
      AND (p_leave_type = 'ALL' OR UPPER(la.leave_type) = UPPER(p_leave_type) OR (la.leave_type_id IS NOT NULL AND la.leave_type_id::TEXT = p_leave_type))
      AND (p_from_date IS NULL OR la.start_date >= p_from_date)
      AND (p_to_date IS NULL OR la.end_date <= p_to_date)
      AND (p_manager_id IS NULL OR p.manager_id = p_manager_id OR la.applicant_id = p_manager_id)
      AND (
          p_search IS NULL OR p_search = '' OR
          LOWER(COALESCE(la.request_code, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(p.full_name, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(p.employee_id, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(la.leave_type, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(la.reason, '')) LIKE v_search_pattern
      );

    -- 4. Upcoming Leaves in next 30 days
    SELECT COALESCE(jsonb_agg(u), '[]'::jsonb)
    INTO v_upcoming
    FROM (
        SELECT
            la.id,
            la.applicant_id,
            p.full_name AS employee_name,
            p.full_name AS applicant_name,
            p.avatar_url,
            COALESCE(p.employee_id, SUBSTRING(p.id::TEXT FROM 1 FOR 8)) AS employee_id,
            COALESCE(p.department, 'General') AS department,
            COALESCE(lt.name, la.leave_type) AS leave_type,
            COALESCE(lt.color_hex, '#4F46E5') AS color_hex,
            la.start_date,
            la.end_date,
            CASE 
                WHEN la.start_date = la.end_date THEN TO_CHAR(la.start_date, 'DD Mon')
                WHEN TO_CHAR(la.start_date, 'Mon') = TO_CHAR(la.end_date, 'Mon') THEN TO_CHAR(la.start_date, 'DD') || ' - ' || TO_CHAR(la.end_date, 'DD Mon')
                ELSE TO_CHAR(la.start_date, 'DD Mon') || ' - ' || TO_CHAR(la.end_date, 'DD Mon')
            END AS date_range_formatted,
            COALESCE(la.billable_days, la.duration_days, 1.0) AS billable_days,
            la.status
        FROM public.leave_applications la
        JOIN public.profiles p ON p.id = la.applicant_id
        LEFT JOIN LATERAL (
            SELECT lt.name, lt.color_hex 
            FROM public.leave_types lt 
            WHERE (lt.id = la.leave_type_id OR UPPER(lt.name) = UPPER(la.leave_type)) 
              AND (lt.school_id = la.school_id OR lt.school_id IS NULL)
            ORDER BY (lt.id = la.leave_type_id) DESC, (lt.school_id IS NOT NULL) DESC
            LIMIT 1
        ) lt ON TRUE
        WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
          AND LOWER(la.status) = 'approved'
          AND la.start_date >= CURRENT_DATE
          AND la.start_date <= (CURRENT_DATE + INTERVAL '30 days')
          AND (p_manager_id IS NULL OR p.manager_id = p_manager_id OR la.applicant_id = p_manager_id)
        ORDER BY la.start_date ASC
        LIMIT 10
    ) u;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'academic_year', v_acad_year,
            'kpi', COALESCE(v_kpi, '{}'::jsonb),
            'balance_summary', COALESCE(v_balance_summary, '[]'::jsonb),
            'requests', COALESCE(v_requests, '[]'::jsonb),
            'upcoming_leaves', COALESCE(v_upcoming, '[]'::jsonb),
            'page', p_page,
            'page_size', p_page_size,
            'total_count', v_total_requests,
            'total_pages', CEIL(GREATEST(v_total_requests, 1)::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC),
            'pagination', jsonb_build_object(
                'page', p_page,
                'page_size', p_page_size,
                'total_count', v_total_requests,
                'total_pages', CEIL(GREATEST(v_total_requests, 1)::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)
            )
        )
    );
END;
$function$ LANGUAGE plpgsql;

-- 3. Synchronize leave_type string on historical leave_applications with active leave_types names
UPDATE public.leave_applications la
SET leave_type = lt.name
FROM public.leave_types lt
WHERE lt.id = la.leave_type_id
  AND la.leave_type != lt.name;
