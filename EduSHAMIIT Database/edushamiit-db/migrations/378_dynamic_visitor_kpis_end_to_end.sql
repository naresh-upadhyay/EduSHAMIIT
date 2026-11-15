-- ============================================================================
-- Migration 378: Dynamic Visitor KPIs & End-to-End Accurate Metrics
-- ============================================================================
-- Purpose:
--   1. Replaces static/mismatched visitor dashboard KPI numbers with 100% dynamic,
--      filter-aware calculations (supporting date_from, date_to, date_range_label, location, category).
--   2. Dynamically calculates Total Visitors, trend percentage (comparing current vs preceding period),
--      and updates subtitles to match selected date ranges (e.g. 'Yesterday', 'Last 7 Days', 'This Month', 'All Time').
--   3. Accurately counts Currently Inside (all visitors physically on campus with actual_check_out_at IS NULL)
--      and Overstay (visitors whose expected_out_at has elapsed without checkout).
--   4. Aligns fn_visitors_list_visits so filtering by 'Inside' returns active visitors currently on campus,
--      filtering by 'Overstay' returns overstaying visitors, and record rows show accurate dynamic status badges.
--   5. Removes static dummy fallbacks from fn_visitors_get_scheduled_kpis and fn_visitors_get_blacklisted_kpis.
-- ============================================================================

-- Function 1: Filter-aware, Dynamic Visitor KPIs
CREATE OR REPLACE FUNCTION public.fn_visitors_get_kpis(
    p_school_id UUID,
    p_filter JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_visitors INT := 0;
    v_total_trend VARCHAR := '+0%';
    v_total_subtitle VARCHAR := 'This Month';
    v_currently_inside INT := 0;
    v_currently_inside_subtitle VARCHAR := 'On campus now';
    v_checked_in_today INT := 0;
    v_checked_in_today_subtitle VARCHAR := 'Till now';
    v_checked_out_today INT := 0;
    v_checked_out_today_subtitle VARCHAR := 'Completed visits';
    v_overstay INT := 0;
    v_overstay_subtitle VARCHAR := 'Exceeding allowed time';
    v_scheduled_today INT := 0;
    v_scheduled_today_subtitle VARCHAR := 'Upcoming visitors';

    v_date_from TIMESTAMPTZ := NULL;
    v_date_to TIMESTAMPTZ := NULL;
    v_date_range_label VARCHAR := TRIM(COALESCE(p_filter->>'date_range_label', ''));
    v_location VARCHAR := TRIM(COALESCE(p_filter->>'location', 'All'));
    v_category VARCHAR := TRIM(COALESCE(p_filter->>'category', 'All'));

    v_now TIMESTAMPTZ := NOW();
    v_today_start TIMESTAMPTZ := date_trunc('day', NOW());
    v_today_end TIMESTAMPTZ := v_today_start + interval '1 day';
    v_month_start TIMESTAMPTZ := date_trunc('month', NOW());
    v_prev_month_start TIMESTAMPTZ := v_month_start - interval '1 month';

    v_curr_period_count INT := 0;
    v_prev_period_count INT := 0;
    v_growth_pct NUMERIC := 0;
BEGIN
    -- Parse dates if provided in p_filter
    IF p_filter->>'date_from' IS NOT NULL AND p_filter->>'date_from' != '' THEN
        v_date_from := (p_filter->>'date_from')::TIMESTAMPTZ;
    END IF;
    IF p_filter->>'date_to' IS NOT NULL AND p_filter->>'date_to' != '' THEN
        v_date_to := (p_filter->>'date_to')::TIMESTAMPTZ;
    END IF;

    -- 1. Total Visitors & Dynamic Trend
    IF v_date_from IS NOT NULL OR v_date_to IS NOT NULL THEN
        SELECT COUNT(*) INTO v_total_visitors
        FROM public.visitor_visits v
        WHERE v.school_id = p_school_id
          AND (v_date_from IS NULL OR COALESCE(v.check_in_at, v.created_at) >= v_date_from)
          AND (v_date_to IS NULL OR COALESCE(v.check_in_at, v.created_at) <= v_date_to)
          AND (v_location = 'All' OR v_location = 'All Locations' OR v.destination = v_location OR v.entry_location = v_location)
          AND (v_category = 'All' OR v_category = 'All Visitor Types' OR v.category = v_category);

        IF v_date_range_label != '' THEN
            v_total_subtitle := v_date_range_label;
        ELSE
            v_total_subtitle := 'Selected Period';
        END IF;

        -- Trend compared to previous period of equal length
        IF v_date_from IS NOT NULL AND v_date_to IS NOT NULL THEN
            DECLARE
                v_duration INTERVAL := v_date_to - v_date_from;
            BEGIN
                SELECT COUNT(*) INTO v_prev_period_count
                FROM public.visitor_visits v
                WHERE v.school_id = p_school_id
                  AND COALESCE(v.check_in_at, v.created_at) >= (v_date_from - v_duration)
                  AND COALESCE(v.check_in_at, v.created_at) < v_date_from;
            END;

            IF v_prev_period_count > 0 THEN
                v_growth_pct := ROUND(((v_total_visitors - v_prev_period_count)::numeric / v_prev_period_count) * 100);
                IF v_growth_pct >= 0 THEN
                    v_total_trend := '+' || v_growth_pct::int || '%';
                ELSE
                    v_total_trend := '-' || abs(v_growth_pct::int) || '%';
                END IF;
            ELSEIF v_total_visitors > 0 THEN
                v_total_trend := '+100%';
            ELSE
                v_total_trend := '+0%';
            END IF;
        ELSE
            v_total_trend := '+0%';
        END IF;
    ELSE
        -- No date filter: All time count
        SELECT COUNT(*) INTO v_total_visitors
        FROM public.visitor_visits v
        WHERE v.school_id = p_school_id
          AND (v_location = 'All' OR v_location = 'All Locations' OR v.destination = v_location OR v.entry_location = v_location)
          AND (v_category = 'All' OR v_category = 'All Visitor Types' OR v.category = v_category);

        v_total_subtitle := 'All Time';

        -- Month-over-Month trend
        SELECT COUNT(*) INTO v_curr_period_count
        FROM public.visitor_visits v
        WHERE v.school_id = p_school_id
          AND COALESCE(v.check_in_at, v.created_at) >= v_month_start;

        SELECT COUNT(*) INTO v_prev_period_count
        FROM public.visitor_visits v
        WHERE v.school_id = p_school_id
          AND COALESCE(v.check_in_at, v.created_at) >= v_prev_month_start
          AND COALESCE(v.check_in_at, v.created_at) < v_month_start;

        IF v_prev_period_count > 0 THEN
            v_growth_pct := ROUND(((v_curr_period_count - v_prev_period_count)::numeric / v_prev_period_count) * 100);
            IF v_growth_pct >= 0 THEN
                v_total_trend := '+' || v_growth_pct::int || '%';
            ELSE
                v_total_trend := '-' || abs(v_growth_pct::int) || '%';
            END IF;
        ELSEIF v_curr_period_count > 0 THEN
            v_total_trend := '+100%';
        ELSE
            v_total_trend := '+0%';
        END IF;
    END IF;

    -- 2. Currently Inside (All visitors physically on campus with actual_check_out_at IS NULL)
    SELECT COUNT(*) INTO v_currently_inside
    FROM public.visitor_visits v
    WHERE v.school_id = p_school_id
      AND v.actual_check_out_at IS NULL
      AND v.status IN ('Inside', 'Overstay')
      AND (v_location = 'All' OR v_location = 'All Locations' OR v.destination = v_location OR v.entry_location = v_location)
      AND (v_category = 'All' OR v_category = 'All Visitor Types' OR v.category = v_category);

    -- 3. Checked In Today (or checked in during selected date range)
    IF v_date_from IS NOT NULL OR v_date_to IS NOT NULL THEN
        SELECT COUNT(*) INTO v_checked_in_today
        FROM public.visitor_visits v
        WHERE v.school_id = p_school_id
          AND (v_date_from IS NULL OR COALESCE(v.check_in_at, v.created_at) >= v_date_from)
          AND (v_date_to IS NULL OR COALESCE(v.check_in_at, v.created_at) <= v_date_to)
          AND (v_location = 'All' OR v_location = 'All Locations' OR v.destination = v_location OR v.entry_location = v_location)
          AND (v_category = 'All' OR v_category = 'All Visitor Types' OR v.category = v_category);
        v_checked_in_today_subtitle := 'In selected period';
    ELSE
        SELECT COUNT(*) INTO v_checked_in_today
        FROM public.visitor_visits v
        WHERE v.school_id = p_school_id
          AND v.check_in_at >= v_today_start
          AND v.check_in_at < v_today_end
          AND (v_location = 'All' OR v_location = 'All Locations' OR v.destination = v_location OR v.entry_location = v_location)
          AND (v_category = 'All' OR v_category = 'All Visitor Types' OR v.category = v_category);
        v_checked_in_today_subtitle := 'Till now';
    END IF;

    -- 4. Checked Out Today (or checked out during selected date range)
    IF v_date_from IS NOT NULL OR v_date_to IS NOT NULL THEN
        SELECT COUNT(*) INTO v_checked_out_today
        FROM public.visitor_visits v
        WHERE v.school_id = p_school_id
          AND v.actual_check_out_at IS NOT NULL
          AND (v_date_from IS NULL OR v.actual_check_out_at >= v_date_from)
          AND (v_date_to IS NULL OR v.actual_check_out_at <= v_date_to)
          AND (v_location = 'All' OR v_location = 'All Locations' OR v.destination = v_location OR v.entry_location = v_location)
          AND (v_category = 'All' OR v_category = 'All Visitor Types' OR v.category = v_category);
        v_checked_out_today_subtitle := 'In selected period';
    ELSE
        SELECT COUNT(*) INTO v_checked_out_today
        FROM public.visitor_visits v
        WHERE v.school_id = p_school_id
          AND v.actual_check_out_at >= v_today_start
          AND v.actual_check_out_at < v_today_end
          AND (v_location = 'All' OR v_location = 'All Locations' OR v.destination = v_location OR v.entry_location = v_location)
          AND (v_category = 'All' OR v_category = 'All Visitor Types' OR v.category = v_category);
        v_checked_out_today_subtitle := 'Completed visits';
    END IF;

    -- 5. Overstay (visitors on campus whose expected_out_at has passed OR marked Overstay)
    SELECT COUNT(*) INTO v_overstay
    FROM public.visitor_visits v
    WHERE v.school_id = p_school_id
      AND v.actual_check_out_at IS NULL
      AND (
          v.status = 'Overstay'
          OR (v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < v_now)
      )
      AND (v_location = 'All' OR v_location = 'All Locations' OR v.destination = v_location OR v.entry_location = v_location)
      AND (v_category = 'All' OR v_category = 'All Visitor Types' OR v.category = v_category);

    -- 6. Scheduled Today (or in selected period)
    IF v_date_from IS NOT NULL OR v_date_to IS NOT NULL THEN
        SELECT COUNT(*) INTO v_scheduled_today
        FROM public.visitor_appointments a
        WHERE a.school_id = p_school_id
          AND (v_date_from IS NULL OR a.scheduled_date >= (v_date_from::date))
          AND (v_date_to IS NULL OR a.scheduled_date <= (v_date_to::date))
          AND a.status NOT IN ('REJECTED', 'CANCELLED');
        v_scheduled_today_subtitle := 'In selected period';
    ELSE
        SELECT COUNT(*) INTO v_scheduled_today
        FROM public.visitor_appointments a
        WHERE a.school_id = p_school_id
          AND a.scheduled_date = CURRENT_DATE
          AND a.status IN ('AWAITING_APPROVAL', 'APPROVED');
        v_scheduled_today_subtitle := 'Upcoming visitors';
    END IF;

    RETURN jsonb_build_object(
        'total_visitors', v_total_visitors,
        'total_trend', v_total_trend,
        'total_subtitle', v_total_subtitle,
        'currently_inside', v_currently_inside,
        'currently_inside_subtitle', v_currently_inside_subtitle,
        'checked_in_today', v_checked_in_today,
        'checked_in_today_subtitle', v_checked_in_today_subtitle,
        'checked_out_today', v_checked_out_today,
        'checked_out_today_subtitle', v_checked_out_today_subtitle,
        'overstay', v_overstay,
        'overstay_subtitle', v_overstay_subtitle,
        'scheduled_today', v_scheduled_today,
        'scheduled_today_subtitle', v_scheduled_today_subtitle
    );
END;
$$;


-- Function 2: Updated List Visits with Exact Alignment for Status and Counts
CREATE OR REPLACE FUNCTION public.fn_visitors_list_visits(
    p_school_id UUID,
    p_params JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search VARCHAR := TRIM(COALESCE(p_params->>'search', ''));
    v_location VARCHAR := TRIM(COALESCE(p_params->>'location', 'All'));
    v_category VARCHAR := TRIM(COALESCE(p_params->>'category', 'All'));
    v_status VARCHAR := TRIM(COALESCE(p_params->>'status', 'All'));
    v_page INT := GREATEST(1, COALESCE((p_params->>'page')::INT, 1));
    v_page_size INT := GREATEST(1, LEAST(100, COALESCE((p_params->>'page_size')::INT, 10)));
    v_offset INT := (v_page - 1) * v_page_size;
    v_total INT := 0;
    v_records JSONB := '[]'::JSONB;
    v_date_from TIMESTAMPTZ := NULL;
    v_date_to TIMESTAMPTZ := NULL;
    v_now TIMESTAMPTZ := NOW();
BEGIN
    IF p_params->>'date_from' IS NOT NULL AND p_params->>'date_from' != '' THEN
        v_date_from := (p_params->>'date_from')::TIMESTAMPTZ;
    END IF;
    IF p_params->>'date_to' IS NOT NULL AND p_params->>'date_to' != '' THEN
        v_date_to := (p_params->>'date_to')::TIMESTAMPTZ;
    END IF;

    -- Count total records matching criteria
    SELECT COUNT(*) INTO v_total
    FROM public.visitor_visits v
    JOIN public.visitor_profiles p ON v.visitor_id = p.id
    WHERE v.school_id = p_school_id
      AND (
          v_search = ''
          OR p.full_name ILIKE '%' || v_search || '%'
          OR p.phone ILIKE '%' || v_search || '%'
          OR v.visit_number ILIKE '%' || v_search || '%'
          OR v.purpose ILIKE '%' || v_search || '%'
          OR COALESCE(v.host_name, '') ILIKE '%' || v_search || '%'
          OR COALESCE(v.vehicle_number, '') ILIKE '%' || v_search || '%'
          OR COALESCE(v.pass_reference, '') ILIKE '%' || v_search || '%'
      )
      AND (
          v_location = 'All'
          OR v_location = 'All Locations'
          OR v.destination = v_location
          OR v.entry_location = v_location
      )
      AND (
          v_category = 'All'
          OR v_category = 'All Visitor Types'
          OR v.category = v_category
          OR p.visitor_type = v_category
      )
      AND (
          v_status = 'All'
          OR v_status = 'All Status'
          OR (v_status = 'Inside' AND v.actual_check_out_at IS NULL AND v.status IN ('Inside', 'Overstay'))
          OR (v_status = 'Checked Out' AND (v.status = 'Checked Out' OR v.actual_check_out_at IS NOT NULL))
          OR (v_status = 'Overstay' AND v.actual_check_out_at IS NULL AND (v.status = 'Overstay' OR (v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < v_now)))
          OR v.status = v_status
      )
      AND (
          v_date_from IS NULL
          OR COALESCE(v.check_in_at, v.created_at) >= v_date_from
      )
      AND (
          v_date_to IS NULL
          OR COALESCE(v.check_in_at, v.created_at) <= v_date_to
      );

    -- Fetch paginated records
    SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_records
    FROM (
        SELECT jsonb_build_object(
            'id', v.id,
            'visit_number', v.visit_number,
            'visitor_id', v.visitor_id,
            'visitor_name', p.full_name,
            'photo_url', p.photo_url,
            'phone', p.phone,
            'visitor_type', v.category,
            'category', v.category,
            'purpose', v.purpose,
            'location', v.destination,
            'destination', v.destination,
            'host_name', COALESCE(v.host_name, 'Staff Member'),
            'host_department', v.host_department,
            'check_in_at', to_char(v.check_in_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
            'expected_out_at', to_char(v.expected_out_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
            'actual_check_out_at', to_char(v.actual_check_out_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
            'status', CASE 
                WHEN v.actual_check_out_at IS NOT NULL THEN 'Checked Out'
                WHEN v.status = 'Overstay' OR (v.status = 'Inside' AND v.actual_check_out_at IS NULL AND v.expected_out_at IS NOT NULL AND v.expected_out_at < v_now) THEN 'Overstay'
                ELSE v.status
            END,
            'vehicle_number', v.vehicle_number,
            'pass_reference', v.pass_reference,
            'remarks', v.remarks
        ) AS row_data
        FROM public.visitor_visits v
        JOIN public.visitor_profiles p ON v.visitor_id = p.id
        WHERE v.school_id = p_school_id
          AND (
              v_search = ''
              OR p.full_name ILIKE '%' || v_search || '%'
              OR p.phone ILIKE '%' || v_search || '%'
              OR v.visit_number ILIKE '%' || v_search || '%'
              OR v.purpose ILIKE '%' || v_search || '%'
              OR COALESCE(v.host_name, '') ILIKE '%' || v_search || '%'
              OR COALESCE(v.vehicle_number, '') ILIKE '%' || v_search || '%'
              OR COALESCE(v.pass_reference, '') ILIKE '%' || v_search || '%'
          )
          AND (
              v_location = 'All'
              OR v_location = 'All Locations'
              OR v.destination = v_location
              OR v.entry_location = v_location
          )
          AND (
              v_category = 'All'
              OR v_category = 'All Visitor Types'
              OR v.category = v_category
              OR p.visitor_type = v_category
          )
          AND (
              v_status = 'All'
              OR v_status = 'All Status'
              OR (v_status = 'Inside' AND v.actual_check_out_at IS NULL AND v.status IN ('Inside', 'Overstay'))
              OR (v_status = 'Checked Out' AND (v.status = 'Checked Out' OR v.actual_check_out_at IS NOT NULL))
              OR (v_status = 'Overstay' AND v.actual_check_out_at IS NULL AND (v.status = 'Overstay' OR (v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < v_now)))
              OR v.status = v_status
          )
          AND (
              v_date_from IS NULL
              OR COALESCE(v.check_in_at, v.created_at) >= v_date_from
          )
          AND (
              v_date_to IS NULL
              OR COALESCE(v.check_in_at, v.created_at) <= v_date_to
          )
        ORDER BY v.created_at DESC
        LIMIT v_page_size OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'records', v_records,
        'pagination', jsonb_build_object(
            'page', v_page,
            'page_size', v_page_size,
            'total', v_total,
            'total_pages', CEIL(v_total::NUMERIC / v_page_size)::INT
        )
    );
END;
$$;


-- Function 3: Scheduled Visitors KPIs (Zero Hardcoded Dummy Fallback)
CREATE OR REPLACE FUNCTION public.fn_visitors_get_scheduled_kpis(
    p_school_id UUID,
    p_date_from TIMESTAMPTZ DEFAULT NULL,
    p_date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_scheduled INT := 0;
    v_today INT := 0;
    v_this_week INT := 0;
    v_expected_visitors INT := 0;
    v_pending_approval INT := 0;
BEGIN
    SELECT COUNT(*) INTO v_total_scheduled
    FROM public.visitor_appointments
    WHERE school_id = p_school_id
      AND status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED')
      AND (p_date_from IS NULL OR scheduled_date >= (p_date_from::date))
      AND (p_date_to IS NULL OR scheduled_date <= (p_date_to::date));

    SELECT COUNT(*) INTO v_today
    FROM public.visitor_appointments
    WHERE school_id = p_school_id
      AND scheduled_date = CURRENT_DATE
      AND status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED');

    SELECT COUNT(*) INTO v_this_week
    FROM public.visitor_appointments
    WHERE school_id = p_school_id
      AND scheduled_date >= CURRENT_DATE
      AND scheduled_date <= (CURRENT_DATE + interval '7 days')
      AND status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED');

    SELECT COALESCE(SUM(expected_count), 0) INTO v_expected_visitors
    FROM public.visitor_appointments
    WHERE school_id = p_school_id
      AND scheduled_date >= CURRENT_DATE
      AND scheduled_date <= (CURRENT_DATE + interval '7 days')
      AND status NOT IN ('REJECTED', 'CANCELLED');

    SELECT COUNT(*) INTO v_pending_approval
    FROM public.visitor_appointments
    WHERE school_id = p_school_id
      AND status IN ('AWAITING_APPROVAL', 'PENDING');

    RETURN jsonb_build_object(
        'total_scheduled', v_total_scheduled,
        'total_subtitle', 'Upcoming visitors',
        'today', v_today,
        'today_subtitle', 'Scheduled for today',
        'this_week', v_this_week,
        'this_week_subtitle', 'Next 7 days',
        'expected_visitors', v_expected_visitors,
        'expected_subtitle', 'This week',
        'pending_approval', v_pending_approval,
        'pending_subtitle', 'Awaiting approval'
    );
END;
$$;


-- Function 4: Blacklisted Visitors KPIs (Zero Hardcoded Dummy Fallback)
CREATE OR REPLACE FUNCTION public.fn_visitors_get_blacklisted_kpis(
    p_school_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_blacklisted INT := 0;
    v_active_blocks INT := 0;
    v_expired_blocks INT := 0;
    v_attempted_entries INT := 0;
BEGIN
    SELECT COUNT(*) INTO v_total_blacklisted
    FROM public.visitor_restrictions
    WHERE school_id = p_school_id;

    SELECT COUNT(*) INTO v_active_blocks
    FROM public.visitor_restrictions
    WHERE school_id = p_school_id
      AND status = 'ACTIVE';

    SELECT COUNT(*) INTO v_expired_blocks
    FROM public.visitor_restrictions
    WHERE school_id = p_school_id
      AND status IN ('EXPIRED', 'LIFTED');

    SELECT COUNT(*) INTO v_attempted_entries
    FROM public.visitor_access_attempts
    WHERE school_id = p_school_id
      AND outcome = 'Blocked';

    RETURN jsonb_build_object(
        'total_blacklisted', v_total_blacklisted,
        'total_subtitle', 'Restricted from entry',
        'active_blocks', v_active_blocks,
        'active_subtitle', 'Currently restricted',
        'expired_blocks', v_expired_blocks,
        'expired_subtitle', 'Restriction ended',
        'attempted_entries', v_attempted_entries,
        'attempted_subtitle', 'Blocked at gate'
    );
END;
$$;
