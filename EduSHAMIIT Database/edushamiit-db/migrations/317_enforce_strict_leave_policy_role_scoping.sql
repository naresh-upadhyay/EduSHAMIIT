-- Migration 317: Enforce Strict Role-Scoping for Leave Policies & Balances
-- Purpose:
-- 1. Eliminates all super_admin / director bypasses for leave policy role-scoping.
-- 2. Guarantees that if a leave policy is assigned to 'teacher', it applies EXCLUSIVELY to users with the 'teacher' role.
-- 3. Ensures the Right Sidebar "Leave Balance Summary", the "Leave Balances" roster, and "Apply Leave" dialog ONLY show leave types applicable to that user's exact role.
-- 4. Purges non-applicable historical balance rows where the user has zero used/pending days for a role-restricted policy.

-- 1. Purge non-applicable balance records from public.leave_balances
DELETE FROM public.leave_balances lb
USING public.profiles p, public.leave_types lt
WHERE lb.user_id = p.id
  AND lb.leave_type_id = lt.id
  AND lt.applicable_roles IS NOT NULL
  AND array_length(lt.applicable_roles, 1) > 0
  AND NOT ('all' = ANY(ARRAY(SELECT LOWER(r) FROM unnest(lt.applicable_roles) r)))
  AND NOT (LOWER(p.role) = ANY(ARRAY(SELECT LOWER(r) FROM unnest(lt.applicable_roles) r)))
  AND COALESCE(lb.used_days, 0) = 0
  AND COALESCE(lb.pending_days, 0) = 0;

-- 2. Enhanced fn_apply_leave_request with Strict Role-Scoping (Zero Bypasses)
CREATE OR REPLACE FUNCTION public.fn_apply_leave_request(
    p_school_id UUID,
    p_applicant_id UUID,
    p_leave_type VARCHAR,
    p_start_date DATE,
    p_end_date DATE,
    p_reason TEXT,
    p_half_day_type VARCHAR DEFAULT 'FULL_DAY',
    p_attachment_url TEXT DEFAULT NULL,
    p_contact_number VARCHAR DEFAULT NULL
)
RETURNS JSONB AS $function$
DECLARE
    v_leave_type_id UUID;
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
    SELECT id, annual_entitlement, allow_half_day, applicable_roles
    INTO v_leave_type_id, v_annual_entitlement, v_allow_half_day, v_policy_roles
    FROM public.leave_types
    WHERE (school_id = p_school_id OR school_id IS NULL)
      AND (UPPER(name) = UPPER(p_leave_type) OR UPPER(code) = UPPER(p_leave_type))
      AND is_active = TRUE
    ORDER BY school_id NULLS LAST
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
                'message', 'Leave policy "' || p_leave_type || '" is not applicable for your role (' || v_applicant_role || ').',
                'error', 'Leave policy "' || p_leave_type || '" is not applicable for your role (' || v_applicant_role || ').'
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

    -- Calculate Smart Calendar Exclusions (Sundays, Official Holidays, Overlaps)
    v_total_days := (p_end_date - p_start_date) + 1;
    v_cur_date := p_start_date;

    WHILE v_cur_date <= p_end_date LOOP
        v_is_holiday := FALSE;
        v_has_overlap := FALSE;

        -- Check official Sunday holiday
        IF EXTRACT(DOW FROM v_cur_date) = 0 THEN
            v_is_holiday := TRUE;
        END IF;

        -- Check school calendar events / holidays
        IF NOT v_is_holiday THEN
            SELECT EXISTS(
                SELECT 1 FROM public.events
                WHERE (school_id = p_school_id OR school_id IS NULL)
                  AND event_type = 'HOLIDAY'
                  AND v_cur_date BETWEEN start_date::DATE AND end_date::DATE
            ) INTO v_is_holiday;
        END IF;

        IF NOT v_is_holiday THEN
            SELECT EXISTS(
                SELECT 1 FROM public.calendar_schedules
                WHERE (school_id = p_school_id OR school_id IS NULL)
                  AND is_active = TRUE
                  AND (
                      schedule_type = 'HOLIDAY'
                      OR (recurrence_rule->>'is_holiday')::BOOLEAN = TRUE
                      OR LOWER(title) LIKE '%holiday%'
                      OR LOWER(title) LIKE '%vacation%'
                  )
                  AND v_cur_date BETWEEN start_date::DATE AND end_date::DATE
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

    IF p_half_day_type IN ('FIRST_HALF', 'SECOND_HALF') THEN
        IF v_holidays_count > 0 THEN
            RETURN jsonb_build_object('success', FALSE, 'message', 'Cannot apply for a half-day leave on an official holiday or Sunday.', 'error', 'Cannot apply for a half-day leave on an official holiday or Sunday.');
        END IF;
        IF v_overlap_count > 0 THEN
            RETURN jsonb_build_object('success', FALSE, 'message', 'You already have an active leave application on this date.', 'error', 'You already have an active leave application on this date.');
        END IF;
        v_billable_days := 0.5;
    ELSE
        v_billable_days := GREATEST(0.0, (v_total_days - v_holidays_count - v_overlap_count)::NUMERIC(5, 1));
    END IF;

    IF v_billable_days <= 0.0 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'No billable leave days requested. The selected dates are already covered by holidays (' || v_holidays_count || 'd) or overlapping approved/pending leaves (' || v_overlap_count || 'd).',
            'error', 'No billable leave days requested. The selected dates are already covered by holidays (' || v_holidays_count || 'd) or overlapping approved/pending leaves (' || v_overlap_count || 'd).'
        );
    END IF;

    -- Dynamic Real-Time Balance Verification for Target Academic Year
    SELECT allocated_days, carried_forward_days
    INTO v_custom_allocated, v_carried_forward
    FROM public.leave_balances
    WHERE user_id = p_applicant_id
      AND leave_type_id = v_leave_type_id
      AND public.fn_normalize_academic_year(academic_year) = v_acad_year;

    v_effective_total := COALESCE(v_custom_allocated, v_annual_entitlement) + COALESCE(v_carried_forward, 0.0);

    SELECT COALESCE(SUM(la.billable_days), 0.0)
    INTO v_actual_used
    FROM public.leave_applications la
    WHERE la.applicant_id = p_applicant_id
      AND (la.leave_type_id = v_leave_type_id OR UPPER(la.leave_type) = UPPER(p_leave_type))
      AND public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year
      AND LOWER(la.status) = 'approved';

    SELECT COALESCE(SUM(la.billable_days), 0.0)
    INTO v_actual_pending
    FROM public.leave_applications la
    WHERE la.applicant_id = p_applicant_id
      AND (la.leave_type_id = v_leave_type_id OR UPPER(la.leave_type) = UPPER(p_leave_type))
      AND public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year
      AND LOWER(la.status) = 'pending';

    v_available_balance := v_effective_total - v_actual_used - v_actual_pending;

    IF v_billable_days > v_available_balance THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Insufficient leave balance. Requested: ' || v_billable_days || ' days, Available: ' || v_available_balance || ' days (Used: ' || v_actual_used || 'd, Pending: ' || v_actual_pending || 'd, Quota: ' || v_effective_total || 'd in ' || v_acad_year || ').',
            'error', 'Insufficient leave balance. Requested: ' || v_billable_days || ' days, Available: ' || v_available_balance || ' days (Used: ' || v_actual_used || 'd, Pending: ' || v_actual_pending || 'd, Quota: ' || v_effective_total || 'd in ' || v_acad_year || ').'
        );
    END IF;

    -- Insert Application Record (Trigger automatically synchronizes public.leave_balances)
    v_req_id := gen_random_uuid();

    INSERT INTO public.leave_applications (
        id, school_id, applicant_id, applicant_role, leave_type_id, leave_type,
        start_date, end_date, reason, half_day_type, attachment_url, contact_number,
        status, billable_days, holidays_count, overlap_days_count, created_at, updated_at
    )
    VALUES (
        v_req_id, p_school_id, p_applicant_id, v_applicant_role, v_leave_type_id, p_leave_type,
        p_start_date, p_end_date, p_reason, p_half_day_type, p_attachment_url, p_contact_number,
        'pending', v_billable_days, v_holidays_count, v_overlap_count, NOW(), NOW()
    )
    RETURNING request_code INTO v_req_code;

    -- Audit Log Entry
    INSERT INTO public.leave_audit_logs (school_id, user_id, action, entity_type, entity_id, actor_id, new_value, reason)
    VALUES (
        p_school_id, p_applicant_id, 'LEAVE_APPLY', 'LEAVE_APPLICATION', v_req_id, p_applicant_id,
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

-- 3. Strict Role-Scoping in fn_get_leave_dashboard_and_requests (Zero Bypasses in Balance Summary)
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
        v_acad_year := public.fn_resolve_academic_year(COALESCE(p_from_date, CURRENT_DATE), p_school_id);
    END IF;

    -- Fetch requester profile
    SELECT LOWER(COALESCE(role, '')) INTO v_user_role FROM public.profiles WHERE id = p_user_id;

    v_offset := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);
    v_search_pattern := '%' || LOWER(TRIM(COALESCE(p_search, ''))) || '%';

    -- 1. Compute KPI Cards strictly for the resolved academic year
    SELECT jsonb_build_object(
        'total_requests', COUNT(*),
        'pending_approvals', COUNT(*) FILTER (WHERE LOWER(la.status) = 'pending'),
        'pending_requests', COUNT(*) FILTER (WHERE LOWER(la.status) = 'pending'),
        'approved_leaves', COUNT(*) FILTER (WHERE LOWER(la.status) = 'approved'),
        'rejected_leaves', COUNT(*) FILTER (WHERE LOWER(la.status) = 'rejected'),
        'on_leave_today', (
            SELECT COUNT(DISTINCT applicant_id)
            FROM public.leave_applications
            WHERE (school_id = p_school_id OR school_id IS NULL)
              AND LOWER(status) = 'approved'
              AND CURRENT_DATE BETWEEN start_date AND end_date
        )
    )
    INTO v_kpi
    FROM public.leave_applications la
    JOIN public.profiles p ON p.id = la.applicant_id
    WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
      AND public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year
      AND (p_manager_id IS NULL OR p.manager_id = p_manager_id OR la.applicant_id = p_manager_id);

    -- 2. Compute Balance Summary strictly for policies matching the requester's role
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
            COALESCE(lb.allocated_days, lt.annual_entitlement) AS allocated_days,
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
                (COALESCE(lb.allocated_days, lt.annual_entitlement) + COALESCE(lb.carried_forward_days, 0.0)) -
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
            COALESCE(la.billable_days, la.duration_days, 1.0) AS billable_days,
            la.duration_days,
            la.half_day_type,
            la.reason,
            la.status,
            la.attachment_url,
            la.contact_number,
            la.created_at,
            la.approved_at,
            la.remarks,
            ap.full_name AS approved_by_name
        FROM public.leave_applications la
        JOIN public.profiles p ON p.id = la.applicant_id
        LEFT JOIN LATERAL (
            SELECT lt.color_hex 
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
            p.full_name AS applicant_name,
            p.avatar_url,
            COALESCE(p.employee_id, SUBSTRING(p.id::TEXT FROM 1 FOR 8)) AS employee_id,
            COALESCE(p.department, 'General') AS department,
            la.leave_type,
            COALESCE(lt.color_hex, '#4F46E5') AS color_hex,
            la.start_date,
            la.end_date,
            COALESCE(la.billable_days, la.duration_days, 1.0) AS billable_days,
            la.status
        FROM public.leave_applications la
        JOIN public.profiles p ON p.id = la.applicant_id
        LEFT JOIN LATERAL (
            SELECT lt.color_hex 
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

-- 4. Strict Role-Scoping in fn_get_leave_balances_paginated (Zero Bypasses in Balances Roster)
CREATE OR REPLACE FUNCTION public.fn_get_leave_balances_paginated(
    p_school_id UUID,
    p_academic_year VARCHAR DEFAULT NULL,
    p_department VARCHAR DEFAULT 'ALL',
    p_role VARCHAR DEFAULT 'ALL',
    p_search VARCHAR DEFAULT '',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB AS $function$
DECLARE
    v_offset INT;
    v_search_pattern TEXT;
    v_total_employees INT;
    v_employees JSONB;
    v_acad_year VARCHAR;
BEGIN
    -- Determine target academic year
    IF p_academic_year IS NOT NULL AND UPPER(TRIM(p_academic_year)) != 'ALL' THEN
        v_acad_year := public.fn_normalize_academic_year(p_academic_year);
    ELSE
        v_acad_year := public.fn_resolve_academic_year(CURRENT_DATE, p_school_id);
    END IF;

    v_offset := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);
    v_search_pattern := '%' || LOWER(TRIM(COALESCE(p_search, ''))) || '%';

    -- 1. Fast count matching ACTIVE employees belonging strictly to the school
    SELECT COUNT(p.id)::INT
    INTO v_total_employees
    FROM public.profiles p
    WHERE (
        (p_school_id IS NOT NULL AND p.school_id = p_school_id)
        OR (p_school_id IS NOT NULL AND p.school_id IS NULL AND p.role IN ('super_admin', 'director', 'owner', 'admin'))
        OR (p_school_id IS NULL)
    )
      AND LOWER(COALESCE(p.status, 'active')) = 'active'
      AND (UPPER(COALESCE(p_department, 'ALL')) = 'ALL' OR UPPER(COALESCE(p.department, 'General')) = UPPER(p_department))
      AND (UPPER(COALESCE(p_role, 'ALL')) = 'ALL' OR UPPER(COALESCE(p.role, 'staff')) = UPPER(p_role))
      AND (
          p_search IS NULL OR p_search = '' OR
          LOWER(COALESCE(p.full_name, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(p.email, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(p.employee_id, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(p.department, '')) LIKE v_search_pattern OR
          LOWER(COALESCE(p.role, '')) LIKE v_search_pattern
      );

    -- 2. Single-pass CTE joining active leave types and user balances with STRICT role-matching
    WITH paginated_users AS (
        SELECT p.id, p.full_name, p.role, p.avatar_url,
               COALESCE(p.employee_id, 'EMP-' || SUBSTRING(p.id::TEXT FROM 1 FOR 4)) AS employee_code,
               COALESCE(p.department, 'General') AS department,
               COALESCE(p.designation, p.role) AS designation
        FROM public.profiles p
        WHERE (
            (p_school_id IS NOT NULL AND p.school_id = p_school_id)
            OR (p_school_id IS NOT NULL AND p.school_id IS NULL AND p.role IN ('super_admin', 'director', 'owner', 'admin'))
            OR (p_school_id IS NULL)
        )
          AND LOWER(COALESCE(p.status, 'active')) = 'active'
          AND (UPPER(COALESCE(p_department, 'ALL')) = 'ALL' OR UPPER(COALESCE(p.department, 'General')) = UPPER(p_department))
          AND (UPPER(COALESCE(p_role, 'ALL')) = 'ALL' OR UPPER(COALESCE(p.role, 'staff')) = UPPER(p_role))
          AND (
              p_search IS NULL OR p_search = '' OR
              LOWER(COALESCE(p.full_name, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(p.email, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(p.employee_id, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(p.department, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(p.role, '')) LIKE v_search_pattern
          )
        ORDER BY p.full_name ASC, p.id ASC
        LIMIT p_page_size OFFSET v_offset
    ),
    deduped_active_leave_types AS (
        SELECT DISTINCT ON (LOWER(lt.code))
            lt.id, lt.name, lt.code, lt.annual_entitlement, lt.color_hex, lt.applicable_roles
        FROM public.leave_types lt
        WHERE (lt.school_id = p_school_id OR lt.school_id IS NULL)
          AND lt.is_active = TRUE
        ORDER BY LOWER(lt.code), (lt.school_id IS NOT NULL) DESC, lt.id ASC
    ),
    user_balances_agg AS (
        SELECT
            u.id AS employee_id,
            u.full_name,
            u.role,
            u.avatar_url,
            u.employee_code,
            u.department,
            u.designation,
            COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'id', COALESCE(lb.id, gen_random_uuid()),
                        'leave_type_id', lt.id,
                        'leave_type_name', lt.name,
                        'leave_type_code', lt.code,
                        'color_hex', COALESCE(lt.color_hex, '#4F46E5'),
                        'allocated_days', COALESCE(lb.allocated_days, lt.annual_entitlement),
                        'used_days', COALESCE(
                            (SELECT SUM(la.billable_days) 
                             FROM public.leave_applications la 
                             WHERE la.applicant_id = u.id 
                               AND (la.leave_type_id = lt.id OR UPPER(la.leave_type) = UPPER(lt.name))
                               AND public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year
                               AND LOWER(la.status) = 'approved'),
                            lb.used_days,
                            0.0
                        ),
                        'pending_days', COALESCE(
                            (SELECT SUM(la.billable_days) 
                             FROM public.leave_applications la 
                             WHERE la.applicant_id = u.id 
                               AND (la.leave_type_id = lt.id OR UPPER(la.leave_type) = UPPER(lt.name))
                               AND public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year
                               AND LOWER(la.status) = 'pending'),
                            lb.pending_days,
                            0.0
                        ),
                        'carried_forward_days', COALESCE(lb.carried_forward_days, 0.0),
                        'available_days', GREATEST(0.0,
                            (COALESCE(lb.allocated_days, lt.annual_entitlement) + COALESCE(lb.carried_forward_days, 0.0)) -
                            COALESCE(
                                (SELECT SUM(la.billable_days) 
                                 FROM public.leave_applications la 
                                 WHERE la.applicant_id = u.id 
                                   AND (la.leave_type_id = lt.id OR UPPER(la.leave_type) = UPPER(lt.name))
                                   AND public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year
                                   AND LOWER(la.status) = 'approved'),
                                lb.used_days,
                                0.0
                            ) -
                            COALESCE(
                                (SELECT SUM(la.billable_days) 
                                 FROM public.leave_applications la 
                                 WHERE la.applicant_id = u.id 
                                   AND (la.leave_type_id = lt.id OR UPPER(la.leave_type) = UPPER(lt.name))
                                   AND public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year
                                   AND LOWER(la.status) = 'pending'),
                                lb.pending_days,
                                0.0
                            )
                        )
                    )
                    ORDER BY lt.name ASC
                ) FILTER (WHERE lt.id IS NOT NULL),
                '[]'::jsonb
            ) AS balances,
            SUM(COALESCE(lb.allocated_days, lt.annual_entitlement) + COALESCE(lb.carried_forward_days, 0.0)) AS total_allocated,
            SUM(
                COALESCE(
                    (SELECT SUM(la.billable_days) 
                     FROM public.leave_applications la 
                     WHERE la.applicant_id = u.id 
                       AND (la.leave_type_id = lt.id OR UPPER(la.leave_type) = UPPER(lt.name))
                       AND public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year
                       AND LOWER(la.status) = 'approved'),
                    lb.used_days,
                    0.0
                )
            ) AS total_used,
            SUM(
                GREATEST(0.0,
                    (COALESCE(lb.allocated_days, lt.annual_entitlement) + COALESCE(lb.carried_forward_days, 0.0)) -
                    COALESCE(
                        (SELECT SUM(la.billable_days) 
                         FROM public.leave_applications la 
                         WHERE la.applicant_id = u.id 
                           AND (la.leave_type_id = lt.id OR UPPER(la.leave_type) = UPPER(lt.name))
                           AND public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year
                           AND LOWER(la.status) = 'approved'),
                        lb.used_days,
                        0.0
                    ) -
                    COALESCE(
                        (SELECT SUM(la.billable_days) 
                         FROM public.leave_applications la 
                         WHERE la.applicant_id = u.id 
                           AND (la.leave_type_id = lt.id OR UPPER(la.leave_type) = UPPER(lt.name))
                           AND public.fn_resolve_academic_year(la.start_date, la.school_id) = v_acad_year
                           AND LOWER(la.status) = 'pending'),
                        lb.pending_days,
                        0.0
                    )
                )
            ) AS total_available
        FROM paginated_users u
        CROSS JOIN deduped_active_leave_types lt
        LEFT JOIN public.leave_balances lb ON lb.user_id = u.id 
             AND lb.leave_type_id = lt.id
             AND public.fn_normalize_academic_year(lb.academic_year) = v_acad_year
        WHERE (
            lt.applicable_roles IS NULL 
            OR array_length(lt.applicable_roles, 1) IS NULL
            OR array_length(lt.applicable_roles, 1) = 0
            OR 'all' = ANY(ARRAY(SELECT LOWER(r) FROM unnest(lt.applicable_roles) r))
            OR LOWER(u.role) = ANY(ARRAY(SELECT LOWER(r) FROM unnest(lt.applicable_roles) r))
        )
        GROUP BY u.id, u.full_name, u.role, u.avatar_url, u.employee_code, u.department, u.designation
    )
    SELECT COALESCE(jsonb_agg(row_to_json(ub)), '[]'::jsonb)
    INTO v_employees
    FROM user_balances_agg ub;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'academic_year', v_acad_year,
            'employees', v_employees,
            'page', p_page,
            'page_size', p_page_size,
            'total_count', v_total_employees,
            'total_pages', CEIL(GREATEST(v_total_employees, 1)::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)
        )
    );
END;
$function$ LANGUAGE plpgsql;
