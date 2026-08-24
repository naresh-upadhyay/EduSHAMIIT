-- ============================================================================
-- Migration 312: Role-Scoped Leave Policies & Applicant Role Validation
-- Allows configuring leave policies per role (from app_roles) and enforces role checks
-- ============================================================================

-- 1. Ensure applicable_roles column exists on leave_types with proper universal default
ALTER TABLE public.leave_types 
ADD COLUMN IF NOT EXISTS applicable_roles text[] DEFAULT ARRAY['all'::text];

-- 2. Update fn_apply_leave_request with strict role validation against applicable_roles
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
    v_available_days NUMERIC(5, 1) := 0.0;
    v_leave_type_id UUID;
    v_policy_roles TEXT[];
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

    -- 5. Fetch applicant role dynamically from profiles & app_roles
    SELECT role INTO v_applicant_role FROM public.profiles WHERE id = p_applicant_id;
    IF v_applicant_role IS NULL THEN
        SELECT name INTO v_applicant_role FROM public.app_roles WHERE UPPER(COALESCE(status, 'ACTIVE')) = 'ACTIVE' ORDER BY display_order ASC LIMIT 1;
    END IF;

    -- 6. Find Leave Type ID & Validate Role Applicability
    SELECT id, applicable_roles INTO v_leave_type_id, v_policy_roles
    FROM public.leave_types
    WHERE (school_id = p_school_id OR school_id IS NULL)
      AND (name ILIKE p_leave_type OR code ILIKE p_leave_type)
      AND is_active = TRUE
    LIMIT 1;

    IF v_leave_type_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Leave policy "' || p_leave_type || '" does not exist or is inactive.'
        );
    END IF;

    -- Enforce Role Scoping
    IF v_policy_roles IS NOT NULL AND array_length(v_policy_roles, 1) > 0 AND NOT ('all' = ANY(v_policy_roles)) THEN
        IF NOT (LOWER(v_applicant_role) = ANY(ARRAY(SELECT LOWER(r) FROM unnest(v_policy_roles) r))) THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'error', 'Leave policy "' || p_leave_type || '" is not applicable for your role (' || v_applicant_role || ').'
            );
        END IF;
    END IF;

    -- 7. Check Available Balance Guard
    SELECT (allocated_days + carried_forward_days - used_days - pending_days)
    INTO v_available_days
    FROM public.leave_balances
    WHERE user_id = p_applicant_id
      AND leave_type_id = v_leave_type_id
      AND academic_year = '2026-2027';

    IF v_available_days IS NOT NULL AND v_available_days < v_net_days THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Insufficient leave balance. You have ' || v_available_days || ' day(s) available, but this request requires ' || v_net_days || ' net day(s).'
        );
    END IF;

    -- 8. Generate Next Leave Request Code
    v_req_code := 'LV-' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD(FLOOR(RANDOM() * 900 + 100)::TEXT, 3, '0');

    -- 9. Insert Leave Application with Net Billable Days
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

    -- 10. Update pending days in leave balance with ONLY net billable days
    UPDATE public.leave_balances
    SET pending_days = pending_days + v_net_days, updated_at = NOW()
    WHERE user_id = p_applicant_id AND leave_type_id = v_leave_type_id AND academic_year = '2026-2027';

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
$function$;

-- 3. Update fn_get_leave_dashboard_and_requests to scope balance summary to applicant role
CREATE OR REPLACE FUNCTION public.fn_get_leave_dashboard_and_requests(
    p_school_id uuid,
    p_page integer DEFAULT 1,
    p_page_size integer DEFAULT 10,
    p_status character varying DEFAULT 'ALL'::character varying,
    p_user_type character varying DEFAULT 'ALL'::character varying,
    p_department character varying DEFAULT 'ALL'::character varying,
    p_leave_type character varying DEFAULT 'ALL'::character varying,
    p_from_date date DEFAULT NULL::date,
    p_to_date date DEFAULT NULL::date,
    p_search text DEFAULT NULL::text,
    p_manager_id uuid DEFAULT NULL::uuid,
    p_user_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_offset INT;
    v_total_requests INT;
    v_approved_count INT;
    v_pending_count INT;
    v_rejected_count INT;
    v_cancelled_count INT;
    v_filtered_count INT;
    v_requests JSONB;
    v_balance_summary JSONB;
    v_upcoming_leaves JSONB;
    v_search_pattern TEXT;
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
    WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
      AND (p_manager_id IS NULL OR p.manager_id = p_manager_id);

    -- 2. Count Matching Filtered Records
    SELECT COUNT(*)::INT
    INTO v_filtered_count
    FROM public.leave_applications la
    JOIN public.profiles p ON p.id = la.applicant_id
    WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
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
        WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
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

    -- 4. Balance Summary (Scoped to p_user_id & user role)
    SELECT COALESCE(jsonb_agg(b), '[]'::jsonb)
    INTO v_balance_summary
    FROM (
        SELECT
            lt.id AS leave_type_id,
            lt.name AS leave_type_name,
            lt.code AS leave_type_code,
            COALESCE(lt.color_hex, '#4F46E5') AS color_hex,
            COALESCE(lb.allocated_days, lt.annual_entitlement) AS allocated_days,
            COALESCE(lb.used_days, 0.0) AS used_days,
            COALESCE(lb.pending_days, 0.0) AS pending_days,
            GREATEST(COALESCE(lb.allocated_days, lt.annual_entitlement) + COALESCE(lb.carried_forward_days, 0.0) - COALESCE(lb.used_days, 0.0) - COALESCE(lb.pending_days, 0.0), 0.0) AS available_days,
            lt.applicable_roles
        FROM public.leave_types lt
        LEFT JOIN public.leave_balances lb ON (lb.leave_type_id = lt.id AND (p_user_id IS NULL OR lb.user_id = p_user_id) AND lb.academic_year = '2026-2027')
        WHERE (lt.school_id = p_school_id OR lt.school_id IS NULL)
          AND lt.is_active = TRUE
          AND (
              p_user_id IS NULL
              OR v_user_role IS NULL
              OR lt.applicable_roles IS NULL 
              OR array_length(lt.applicable_roles, 1) IS NULL 
              OR array_length(lt.applicable_roles, 1) = 0
              OR 'all' = ANY(lt.applicable_roles)
              OR LOWER(v_user_role) = ANY(ARRAY(SELECT LOWER(r) FROM unnest(lt.applicable_roles) r))
          )
        ORDER BY lt.created_at ASC
        LIMIT 6
    ) b;

    -- 5. Upcoming Leaves List
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
        WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
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
                'pending_requests', v_pending_count,
                'rejected_leaves', v_rejected_count,
                'cancelled_leaves', v_cancelled_count,
                'approved_percentage', CASE WHEN v_total_requests > 0 THEN ROUND((v_approved_count::NUMERIC / v_total_requests::NUMERIC) * 100, 2) ELSE 0.0 END,
                'pending_percentage', CASE WHEN v_total_requests > 0 THEN ROUND((v_pending_count::NUMERIC / v_total_requests::NUMERIC) * 100, 2) ELSE 0.0 END,
                'rejected_percentage', CASE WHEN v_total_requests > 0 THEN ROUND((v_rejected_count::NUMERIC / v_total_requests::NUMERIC) * 100, 2) ELSE 0.0 END,
                'cancelled_percentage', CASE WHEN v_total_requests > 0 THEN ROUND((v_cancelled_count::NUMERIC / v_total_requests::NUMERIC) * 100, 2) ELSE 0.0 END
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
