-- ============================================================================
-- Migration 587: Visitors Management Single Source of Truth (KPIs <-> Grids)
-- ============================================================================
-- Ensures every KPI card, table header count, and pagination total across all
-- 3 Visitors Management tabs (All Visitors, Scheduled Visitors, Blacklisted Visitors)
-- shares identical filtering predicates (search, location, category/reason, date range)
-- and exact status definitions.
-- ============================================================================

-- 1. All Visitors KPIs (Aligned 1:1 with fn_visitors_list_visits)
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
    v_total_subtitle VARCHAR := 'All Time';
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

    v_search VARCHAR := TRIM(COALESCE(p_filter->>'search', ''));
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
    IF p_filter->>'date_from' IS NOT NULL AND p_filter->>'date_from' != '' THEN
        v_date_from := (p_filter->>'date_from')::TIMESTAMPTZ;
    END IF;
    IF p_filter->>'date_to' IS NOT NULL AND p_filter->>'date_to' != '' THEN
        v_date_to := (p_filter->>'date_to')::TIMESTAMPTZ;
    END IF;

    -- 1. Total Visitors (Exact match to fn_visitors_list_visits with status = All)
    SELECT COUNT(*) INTO v_total_visitors
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
          OR LOWER(TRIM(COALESCE(v.destination, ''))) = LOWER(TRIM(v_location))
          OR (COALESCE(v.destination, '') = '' AND LOWER(TRIM(COALESCE(v.entry_location, ''))) = LOWER(TRIM(v_location)))
      )
      AND (
          v_category = 'All'
          OR v_category = 'All Visitor Types'
          OR v.category = v_category
          OR p.visitor_type = v_category
      )
      AND (v_date_from IS NULL OR COALESCE(v.check_in_at, v.created_at) >= v_date_from)
      AND (v_date_to IS NULL OR COALESCE(v.check_in_at, v.created_at) <= v_date_to);

    IF v_date_from IS NOT NULL OR v_date_to IS NOT NULL THEN
        v_total_subtitle := CASE WHEN v_date_range_label != '' THEN v_date_range_label ELSE 'Selected Period' END;

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
                v_total_trend := CASE WHEN v_growth_pct >= 0 THEN '+' || v_growth_pct::int || '%' ELSE '-' || abs(v_growth_pct::int) || '%' END;
            ELSEIF v_total_visitors > 0 THEN
                v_total_trend := '+100%';
            ELSE
                v_total_trend := '+0%';
            END IF;
        ELSE
            v_total_trend := '+0%';
        END IF;
    ELSE
        v_total_subtitle := 'All Time';

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
            v_total_trend := CASE WHEN v_growth_pct >= 0 THEN '+' || v_growth_pct::int || '%' ELSE '-' || abs(v_growth_pct::int) || '%' END;
        ELSEIF v_curr_period_count > 0 THEN
            v_total_trend := '+100%';
        ELSE
            v_total_trend := '+0%';
        END IF;
    END IF;

    -- 2. Currently Inside (Exact match to fn_visitors_list_visits status = 'Inside')
    SELECT COUNT(*) INTO v_currently_inside
    FROM public.visitor_visits v
    JOIN public.visitor_profiles p ON v.visitor_id = p.id
    WHERE v.school_id = p_school_id
      AND v.actual_check_out_at IS NULL
      AND (v.status IN ('Inside', 'Overstay') OR (v.status = 'Blocked' AND v.check_in_at IS NOT NULL))
      AND p.is_blacklisted IS NOT TRUE
      AND NOT EXISTS (
          SELECT 1 FROM public.visitor_restrictions vr
          WHERE vr.visitor_id = v.visitor_id
            AND vr.school_id = v.school_id
            AND vr.status = 'ACTIVE'
            AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)
      )
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
          OR LOWER(TRIM(COALESCE(v.destination, ''))) = LOWER(TRIM(v_location))
          OR (COALESCE(v.destination, '') = '' AND LOWER(TRIM(COALESCE(v.entry_location, ''))) = LOWER(TRIM(v_location)))
      )
      AND (
          v_category = 'All'
          OR v_category = 'All Visitor Types'
          OR v.category = v_category
          OR p.visitor_type = v_category
      );

    -- 3. Checked In Today (or in selected date range)
    IF v_date_from IS NOT NULL OR v_date_to IS NOT NULL THEN
        SELECT COUNT(*) INTO v_checked_in_today
        FROM public.visitor_visits v
        JOIN public.visitor_profiles p ON v.visitor_id = p.id
        WHERE v.school_id = p_school_id
          AND v.check_in_at IS NOT NULL
          AND (v_date_from IS NULL OR v.check_in_at >= v_date_from)
          AND (v_date_to IS NULL OR v.check_in_at <= v_date_to)
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
              OR LOWER(TRIM(COALESCE(v.destination, ''))) = LOWER(TRIM(v_location))
              OR (COALESCE(v.destination, '') = '' AND LOWER(TRIM(COALESCE(v.entry_location, ''))) = LOWER(TRIM(v_location)))
          )
          AND (
              v_category = 'All'
              OR v_category = 'All Visitor Types'
              OR v.category = v_category
              OR p.visitor_type = v_category
          );
        v_checked_in_today_subtitle := 'In selected period';
    ELSE
        SELECT COUNT(*) INTO v_checked_in_today
        FROM public.visitor_visits v
        JOIN public.visitor_profiles p ON v.visitor_id = p.id
        WHERE v.school_id = p_school_id
          AND v.check_in_at >= v_today_start
          AND v.check_in_at < v_today_end
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
              OR LOWER(TRIM(COALESCE(v.destination, ''))) = LOWER(TRIM(v_location))
              OR (COALESCE(v.destination, '') = '' AND LOWER(TRIM(COALESCE(v.entry_location, ''))) = LOWER(TRIM(v_location)))
          )
          AND (
              v_category = 'All'
              OR v_category = 'All Visitor Types'
              OR v.category = v_category
              OR p.visitor_type = v_category
          );
        v_checked_in_today_subtitle := 'Till now';
    END IF;

    -- 4. Checked Out Today (or in selected date range)
    IF v_date_from IS NOT NULL OR v_date_to IS NOT NULL THEN
        SELECT COUNT(*) INTO v_checked_out_today
        FROM public.visitor_visits v
        JOIN public.visitor_profiles p ON v.visitor_id = p.id
        WHERE v.school_id = p_school_id
          AND (v.status = 'Checked Out' OR v.actual_check_out_at IS NOT NULL)
          AND (v_date_from IS NULL OR COALESCE(v.actual_check_out_at, v.check_in_at, v.created_at) >= v_date_from)
          AND (v_date_to IS NULL OR COALESCE(v.actual_check_out_at, v.check_in_at, v.created_at) <= v_date_to)
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
              OR LOWER(TRIM(COALESCE(v.destination, ''))) = LOWER(TRIM(v_location))
              OR (COALESCE(v.destination, '') = '' AND LOWER(TRIM(COALESCE(v.entry_location, ''))) = LOWER(TRIM(v_location)))
          )
          AND (
              v_category = 'All'
              OR v_category = 'All Visitor Types'
              OR v.category = v_category
              OR p.visitor_type = v_category
          );
        v_checked_out_today_subtitle := 'In selected period';
    ELSE
        SELECT COUNT(*) INTO v_checked_out_today
        FROM public.visitor_visits v
        JOIN public.visitor_profiles p ON v.visitor_id = p.id
        WHERE v.school_id = p_school_id
          AND v.actual_check_out_at IS NOT NULL
          AND v.actual_check_out_at >= v_today_start
          AND v.actual_check_out_at < v_today_end
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
              OR LOWER(TRIM(COALESCE(v.destination, ''))) = LOWER(TRIM(v_location))
              OR (COALESCE(v.destination, '') = '' AND LOWER(TRIM(COALESCE(v.entry_location, ''))) = LOWER(TRIM(v_location)))
          )
          AND (
              v_category = 'All'
              OR v_category = 'All Visitor Types'
              OR v.category = v_category
              OR p.visitor_type = v_category
          );
        v_checked_out_today_subtitle := 'Completed visits';
    END IF;

    -- 5. Overstay (Exact match to fn_visitors_list_visits status = 'Overstay')
    SELECT COUNT(*) INTO v_overstay
    FROM public.visitor_visits v
    JOIN public.visitor_profiles p ON v.visitor_id = p.id
    WHERE v.school_id = p_school_id
      AND v.actual_check_out_at IS NULL
      AND (
          v.status = 'Overstay'
          OR (v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < v_now)
      )
      AND p.is_blacklisted IS NOT TRUE
      AND NOT EXISTS (
          SELECT 1 FROM public.visitor_restrictions vr
          WHERE vr.visitor_id = v.visitor_id
            AND vr.school_id = v.school_id
            AND vr.status = 'ACTIVE'
            AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)
      )
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
          OR LOWER(TRIM(COALESCE(v.destination, ''))) = LOWER(TRIM(v_location))
          OR (COALESCE(v.destination, '') = '' AND LOWER(TRIM(COALESCE(v.entry_location, ''))) = LOWER(TRIM(v_location)))
      )
      AND (
          v_category = 'All'
          OR v_category = 'All Visitor Types'
          OR v.category = v_category
          OR p.visitor_type = v_category
      );

    -- 6. Scheduled Today (Exact match to fn_visitors_list_appointments 'Today')
    IF v_date_from IS NOT NULL OR v_date_to IS NOT NULL THEN
        SELECT COUNT(*) INTO v_scheduled_today
        FROM public.visitor_appointments a
        JOIN public.visitor_profiles p ON a.visitor_id = p.id
        WHERE a.school_id = p_school_id
          AND (v_date_from IS NULL OR a.scheduled_date >= (v_date_from::date))
          AND (v_date_to IS NULL OR a.scheduled_date <= (v_date_to::date))
          AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED')
          AND p.is_blacklisted IS NOT TRUE
          AND NOT EXISTS (
              SELECT 1 FROM public.visitor_restrictions vr
              WHERE vr.visitor_id = a.visitor_id
                AND vr.school_id = a.school_id
                AND vr.status = 'ACTIVE'
                AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)
          )
          AND (
              v_location = 'All'
              OR v_location = 'All Locations'
              OR LOWER(TRIM(COALESCE(a.destination, ''))) = LOWER(TRIM(v_location))
              OR a.destination ILIKE '%' || v_location || '%'
          )
          AND (
              v_category = 'All'
              OR v_category = 'All Visitor Types'
              OR p.visitor_type = v_category
          );
        v_scheduled_today_subtitle := 'In selected period';
    ELSE
        SELECT COUNT(*) INTO v_scheduled_today
        FROM public.visitor_appointments a
        JOIN public.visitor_profiles p ON a.visitor_id = p.id
        WHERE a.school_id = p_school_id
          AND a.scheduled_date = CURRENT_DATE
          AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED')
          AND p.is_blacklisted IS NOT TRUE
          AND NOT EXISTS (
              SELECT 1 FROM public.visitor_restrictions vr
              WHERE vr.visitor_id = a.visitor_id
                AND vr.school_id = a.school_id
                AND vr.status = 'ACTIVE'
                AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)
          )
          AND (
              v_location = 'All'
              OR v_location = 'All Locations'
              OR LOWER(TRIM(COALESCE(a.destination, ''))) = LOWER(TRIM(v_location))
              OR a.destination ILIKE '%' || v_location || '%'
          )
          AND (
              v_category = 'All'
              OR v_category = 'All Visitor Types'
              OR p.visitor_type = v_category
          );
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


-- 2. Align fn_visitors_list_visits date filtering when status = 'Checked Out'
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
    v_sort_by VARCHAR := LOWER(TRIM(COALESCE(p_params->>'sort_by', 'created_at')));
    v_sort_order VARCHAR := UPPER(TRIM(COALESCE(p_params->>'sort_order', 'DESC')));
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
          OR LOWER(TRIM(COALESCE(v.destination, ''))) = LOWER(TRIM(v_location))
          OR (COALESCE(v.destination, '') = '' AND LOWER(TRIM(COALESCE(v.entry_location, ''))) = LOWER(TRIM(v_location)))
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
          OR (v_status = 'Blocked' AND (
              v.actual_check_out_at IS NULL AND (
                  p.is_blacklisted = TRUE
                  OR EXISTS (
                      SELECT 1 FROM public.visitor_restrictions vr
                      WHERE vr.visitor_id = v.visitor_id
                        AND vr.school_id = v.school_id
                        AND vr.status = 'ACTIVE'
                        AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)
                  )
              )
          ))
          OR (v_status = 'Inside' AND v.actual_check_out_at IS NULL AND (v.status IN ('Inside', 'Overstay') OR (v.status = 'Blocked' AND v.check_in_at IS NOT NULL)) AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = v.visitor_id AND vr.school_id = v.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)))
          OR (v_status = 'Checked In' AND v.check_in_at IS NOT NULL)
          OR (v_status = 'Checked Out' AND (v.status = 'Checked Out' OR v.actual_check_out_at IS NOT NULL))
          OR (v_status = 'Overstay' AND v.actual_check_out_at IS NULL AND (v.status = 'Overstay' OR (v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < v_now)) AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = v.visitor_id AND vr.school_id = v.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)))
          OR (v_status = 'Scheduled' AND (v.status = 'Scheduled' OR (v.status = 'Blocked' AND v.check_in_at IS NULL)) AND v.actual_check_out_at IS NULL AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = v.visitor_id AND vr.school_id = v.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)))
          OR (v.status = v_status AND p.is_blacklisted IS NOT TRUE)
      )
      AND (
          v_date_from IS NULL
          OR (
              CASE
                  WHEN v_status = 'Checked Out' THEN COALESCE(v.actual_check_out_at, v.check_in_at, v.created_at) >= v_date_from
                  WHEN v_status = 'Checked In' THEN v.check_in_at >= v_date_from
                  ELSE COALESCE(v.check_in_at, v.created_at) >= v_date_from
              END
          )
      )
      AND (
          v_date_to IS NULL
          OR (
              CASE
                  WHEN v_status = 'Checked Out' THEN COALESCE(v.actual_check_out_at, v.check_in_at, v.created_at) <= v_date_to
                  WHEN v_status = 'Checked In' THEN v.check_in_at <= v_date_to
                  ELSE COALESCE(v.check_in_at, v.created_at) <= v_date_to
              END
          )
      );

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
            'location', COALESCE(v.destination, v.entry_location, 'Main Gate'),
            'destination', v.destination,
            'host_name', COALESCE(v.host_name, 'Staff Member'),
            'host_department', v.host_department,
            'check_in_at', to_char(v.check_in_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
            'expected_out_at', to_char(v.expected_out_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
            'actual_check_out_at', to_char(v.actual_check_out_at, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
            'status', CASE 
                WHEN v.actual_check_out_at IS NOT NULL THEN 'Checked Out'
                WHEN v.actual_check_out_at IS NULL AND (
                    p.is_blacklisted = TRUE 
                    OR EXISTS (
                        SELECT 1 FROM public.visitor_restrictions vr 
                        WHERE vr.visitor_id = v.visitor_id 
                          AND vr.school_id = v.school_id 
                          AND vr.status = 'ACTIVE' 
                          AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)
                    )
                ) THEN 'Blocked'
                WHEN v.status = 'Overstay' OR (v.status = 'Inside' AND v.actual_check_out_at IS NULL AND v.expected_out_at IS NOT NULL AND v.expected_out_at < v_now) THEN 'Overstay'
                WHEN v.status = 'Blocked' THEN CASE WHEN v.check_in_at IS NOT NULL THEN 'Inside' ELSE 'Scheduled' END
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
              OR LOWER(TRIM(COALESCE(v.destination, ''))) = LOWER(TRIM(v_location))
              OR (COALESCE(v.destination, '') = '' AND LOWER(TRIM(COALESCE(v.entry_location, ''))) = LOWER(TRIM(v_location)))
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
              OR (v_status = 'Blocked' AND (
                  v.actual_check_out_at IS NULL AND (
                      p.is_blacklisted = TRUE
                      OR EXISTS (
                          SELECT 1 FROM public.visitor_restrictions vr
                          WHERE vr.visitor_id = v.visitor_id
                            AND vr.school_id = v.school_id
                            AND vr.status = 'ACTIVE'
                            AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)
                      )
                  )
              ))
              OR (v_status = 'Inside' AND v.actual_check_out_at IS NULL AND (v.status IN ('Inside', 'Overstay') OR (v.status = 'Blocked' AND v.check_in_at IS NOT NULL)) AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = v.visitor_id AND vr.school_id = v.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)))
              OR (v_status = 'Checked Out' AND (v.status = 'Checked Out' OR v.actual_check_out_at IS NOT NULL))
              OR (v_status = 'Overstay' AND v.actual_check_out_at IS NULL AND (v.status = 'Overstay' OR (v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < v_now)) AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = v.visitor_id AND vr.school_id = v.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)))
              OR (v_status = 'Scheduled' AND (v.status = 'Scheduled' OR (v.status = 'Blocked' AND v.check_in_at IS NULL)) AND v.actual_check_out_at IS NULL AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = v.visitor_id AND vr.school_id = v.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= v_now)))
              OR (v.status = v_status AND p.is_blacklisted IS NOT TRUE)
          )
          AND (
              v_date_from IS NULL
              OR (
                  CASE
                      WHEN v_status = 'Checked Out' THEN COALESCE(v.actual_check_out_at, v.check_in_at, v.created_at) >= v_date_from
                      ELSE COALESCE(v.check_in_at, v.created_at) >= v_date_from
                  END
              )
          )
          AND (
              v_date_to IS NULL
              OR (
                  CASE
                      WHEN v_status = 'Checked Out' THEN COALESCE(v.actual_check_out_at, v.check_in_at, v.created_at) <= v_date_to
                      ELSE COALESCE(v.check_in_at, v.created_at) <= v_date_to
                  END
              )
          )
        ORDER BY 
            CASE WHEN v_sort_by = 'visitor_name' AND v_sort_order = 'ASC' THEN p.full_name END ASC,
            CASE WHEN v_sort_by = 'visitor_name' AND v_sort_order = 'DESC' THEN p.full_name END DESC,
            CASE WHEN v_sort_by IN ('visitor_type', 'type') AND v_sort_order = 'ASC' THEN v.category END ASC,
            CASE WHEN v_sort_by IN ('visitor_type', 'type') AND v_sort_order = 'DESC' THEN v.category END DESC,
            CASE WHEN v_sort_by = 'purpose' AND v_sort_order = 'ASC' THEN v.purpose END ASC,
            CASE WHEN v_sort_by = 'purpose' AND v_sort_order = 'DESC' THEN v.purpose END DESC,
            CASE WHEN v_sort_by IN ('location', 'destination') AND v_sort_order = 'ASC' THEN v.destination END ASC,
            CASE WHEN v_sort_by IN ('location', 'destination') AND v_sort_order = 'DESC' THEN v.destination END DESC,
            CASE WHEN v_sort_by IN ('host_name', 'host') AND v_sort_order = 'ASC' THEN v.host_name END ASC,
            CASE WHEN v_sort_by IN ('host_name', 'host') AND v_sort_order = 'DESC' THEN v.host_name END DESC,
            CASE WHEN v_sort_by = 'check_in_at' AND v_sort_order = 'ASC' THEN v.check_in_at END ASC NULLS LAST,
            CASE WHEN v_sort_by = 'check_in_at' AND v_sort_order = 'DESC' THEN v.check_in_at END DESC NULLS LAST,
            CASE WHEN v_sort_by = 'expected_out_at' AND v_sort_order = 'ASC' THEN v.expected_out_at END ASC NULLS LAST,
            CASE WHEN v_sort_by = 'expected_out_at' AND v_sort_order = 'DESC' THEN v.expected_out_at END DESC NULLS LAST,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'ASC' THEN v.status END ASC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'DESC' THEN v.status END DESC,
            v.created_at DESC
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


-- 3. Scheduled Visitors KPIs (Single Source of Truth with fn_visitors_list_appointments)
CREATE OR REPLACE FUNCTION public.fn_visitors_get_scheduled_kpis(
    p_school_id UUID,
    p_filter JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search VARCHAR := TRIM(COALESCE(p_filter->>'search', ''));
    v_location VARCHAR := TRIM(COALESCE(p_filter->>'location', 'All Locations'));
    v_category VARCHAR := TRIM(COALESCE(p_filter->>'category', 'All Visitor Types'));
    v_date_from TIMESTAMPTZ := NULL;
    v_date_to TIMESTAMPTZ := NULL;

    v_total_scheduled INT := 0;
    v_today INT := 0;
    v_this_week INT := 0;
    v_expected_visitors INT := 0;
    v_pending_approval INT := 0;
BEGIN
    IF p_filter->>'date_from' IS NOT NULL AND p_filter->>'date_from' != '' THEN
        v_date_from := (p_filter->>'date_from')::TIMESTAMPTZ;
    END IF;
    IF p_filter->>'date_to' IS NOT NULL AND p_filter->>'date_to' != '' THEN
        v_date_to := (p_filter->>'date_to')::TIMESTAMPTZ;
    END IF;

    WITH filtered_appointments AS (
        SELECT
            a.id,
            a.visitor_id,
            a.scheduled_date,
            a.expected_count,
            a.status,
            (
                p.is_blacklisted = TRUE
                OR EXISTS (
                    SELECT 1 FROM public.visitor_restrictions vr
                    WHERE vr.visitor_id = a.visitor_id
                      AND vr.school_id = a.school_id
                      AND vr.status = 'ACTIVE'
                      AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())
                )
            ) AS is_currently_blocked
        FROM public.visitor_appointments a
        JOIN public.visitor_profiles p ON a.visitor_id = p.id
        WHERE a.school_id = p_school_id
          AND (
              v_search = ''
              OR p.full_name ILIKE '%' || v_search || '%'
              OR p.phone ILIKE '%' || v_search || '%'
              OR a.appointment_number ILIKE '%' || v_search || '%'
              OR a.host_name ILIKE '%' || v_search || '%'
              OR a.purpose ILIKE '%' || v_search || '%'
              OR a.destination ILIKE '%' || v_search || '%'
          )
          AND (
              v_location = 'All Locations'
              OR v_location = 'All'
              OR v_location = ''
              OR LOWER(TRIM(COALESCE(a.destination, ''))) = LOWER(TRIM(v_location))
              OR a.destination ILIKE '%' || v_location || '%'
          )
          AND (
              v_category = 'All Visitor Types'
              OR v_category = 'All'
              OR v_category = ''
              OR p.visitor_type = v_category
          )
          AND (v_date_from IS NULL OR a.scheduled_date >= v_date_from::DATE)
          AND (v_date_to IS NULL OR a.scheduled_date <= v_date_to::DATE)
    )
    SELECT
        COUNT(*)::INT,
        COUNT(*) FILTER (
            WHERE scheduled_date = CURRENT_DATE
              AND status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED')
              AND NOT is_currently_blocked
        )::INT,
        COUNT(*) FILTER (
            WHERE scheduled_date >= CURRENT_DATE
              AND scheduled_date <= (CURRENT_DATE + interval '7 days')
              AND status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED')
              AND NOT is_currently_blocked
        )::INT,
        COALESCE(SUM(expected_count) FILTER (
            WHERE scheduled_date >= CURRENT_DATE
              AND scheduled_date <= (CURRENT_DATE + interval '7 days')
              AND status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED')
              AND NOT is_currently_blocked
        ), 0)::INT,
        COUNT(*) FILTER (
            WHERE status IN ('AWAITING_APPROVAL', 'PENDING')
              AND NOT is_currently_blocked
        )::INT
    INTO
        v_total_scheduled,
        v_today,
        v_this_week,
        v_expected_visitors,
        v_pending_approval
    FROM filtered_appointments;

    RETURN jsonb_build_object(
        'total_scheduled', v_total_scheduled,
        'total_subtitle', 'All scheduled records',
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

-- Backward-compatible 3-arg overload delegating to JSONB SSOT implementation
CREATE OR REPLACE FUNCTION public.fn_visitors_get_scheduled_kpis(
    p_school_id UUID,
    p_date_from TIMESTAMPTZ DEFAULT NULL,
    p_date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN public.fn_visitors_get_scheduled_kpis(
        p_school_id,
        jsonb_build_object(
            'date_from', p_date_from,
            'date_to', p_date_to
        )
    );
END;
$$;


-- Align Expected status filter in fn_visitors_list_appointments with Expected Visitors KPI (this week)
CREATE OR REPLACE FUNCTION public.fn_visitors_list_appointments(
    p_school_id UUID,
    p_params JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search VARCHAR := TRIM(COALESCE(p_params->>'search', ''));
    v_location VARCHAR := TRIM(COALESCE(p_params->>'location', 'All Locations'));
    v_category VARCHAR := TRIM(COALESCE(p_params->>'category', 'All Visitor Types'));
    v_status VARCHAR := TRIM(COALESCE(p_params->>'status', 'All Status'));
    v_sort_by VARCHAR := LOWER(TRIM(COALESCE(p_params->>'sort_by', 'scheduled_date')));
    v_sort_order VARCHAR := UPPER(TRIM(COALESCE(p_params->>'sort_order', 'ASC')));
    v_page INT := GREATEST(1, COALESCE((p_params->>'page')::INT, 1));
    v_page_size INT := GREATEST(1, LEAST(100, COALESCE((p_params->>'page_size')::INT, 10)));
    v_offset INT := (v_page - 1) * v_page_size;
    v_total_records INT := 0;
    v_records JSONB := '[]'::JSONB;
    v_date_from TIMESTAMPTZ := NULL;
    v_date_to TIMESTAMPTZ := NULL;
BEGIN
    IF p_params->>'date_from' IS NOT NULL AND p_params->>'date_from' != '' THEN
        v_date_from := (p_params->>'date_from')::TIMESTAMPTZ;
    END IF;
    IF p_params->>'date_to' IS NOT NULL AND p_params->>'date_to' != '' THEN
        v_date_to := (p_params->>'date_to')::TIMESTAMPTZ;
    END IF;

    SELECT COUNT(*) INTO v_total_records
    FROM public.visitor_appointments a
    JOIN public.visitor_profiles p ON a.visitor_id = p.id
    WHERE a.school_id = p_school_id
      AND (
          v_search = ''
          OR p.full_name ILIKE '%' || v_search || '%'
          OR p.phone ILIKE '%' || v_search || '%'
          OR a.appointment_number ILIKE '%' || v_search || '%'
          OR a.host_name ILIKE '%' || v_search || '%'
          OR a.purpose ILIKE '%' || v_search || '%'
          OR a.destination ILIKE '%' || v_search || '%'
      )
      AND (
          v_location = 'All Locations'
          OR v_location = 'All'
          OR v_location = ''
          OR LOWER(TRIM(COALESCE(a.destination, ''))) = LOWER(TRIM(v_location))
          OR a.destination ILIKE '%' || v_location || '%'
      )
      AND (
          v_category = 'All Visitor Types'
          OR v_category = 'All'
          OR v_category = ''
          OR p.visitor_type = v_category
      )
      AND (
          v_status = 'All Status'
          OR v_status = 'All'
          OR (v_status ILIKE 'Blocked' AND (
              p.is_blacklisted = TRUE
              OR EXISTS (
                  SELECT 1 FROM public.visitor_restrictions vr
                  WHERE vr.visitor_id = a.visitor_id
                    AND vr.school_id = a.school_id
                    AND vr.status = 'ACTIVE'
                    AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())
              )
          ))
          OR (v_status ILIKE 'Confirmed' AND a.status IN ('APPROVED', 'CONFIRMED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
          OR (v_status ILIKE 'Pending' AND a.status IN ('AWAITING_APPROVAL', 'PENDING') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
          OR (v_status ILIKE 'Today' AND a.scheduled_date = CURRENT_DATE AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
          OR (v_status ILIKE 'This Week' AND a.scheduled_date >= CURRENT_DATE AND a.scheduled_date <= (CURRENT_DATE + interval '7 days') AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
          OR (v_status ILIKE 'Expected' AND a.scheduled_date >= CURRENT_DATE AND a.scheduled_date <= (CURRENT_DATE + interval '7 days') AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
          OR (a.status ILIKE v_status AND p.is_blacklisted IS NOT TRUE)
      )
      AND (v_date_from IS NULL OR a.scheduled_date >= v_date_from::DATE)
      AND (v_date_to IS NULL OR a.scheduled_date <= v_date_to::DATE);

    SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_records
    FROM (
        SELECT jsonb_build_object(
            'id', a.id,
            'appointment_number', a.appointment_number,
            'visitor_id', a.visitor_id,
            'visitor_name', p.full_name,
            'photo_url', p.photo_url,
            'phone', p.phone,
            'visitor_type', p.visitor_type,
            'purpose', a.purpose,
            'location', a.destination,
            'destination', a.destination,
            'host_name', a.host_name,
            'host_department', a.host_department,
            'scheduled_date', to_char(a.scheduled_date, 'YYYY-MM-DD'),
            'scheduled_start_at', to_char(a.scheduled_start_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'scheduled_end_at', to_char(a.scheduled_end_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'status', CASE 
                WHEN p.is_blacklisted = TRUE 
                     OR EXISTS (
                         SELECT 1 FROM public.visitor_restrictions vr 
                         WHERE vr.visitor_id = a.visitor_id 
                           AND vr.school_id = a.school_id 
                           AND vr.status = 'ACTIVE' 
                           AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())
                     ) THEN 'Blocked'
                WHEN a.status IN ('APPROVED', 'CONFIRMED') THEN 'Confirmed'
                WHEN a.status IN ('AWAITING_APPROVAL', 'PENDING') THEN 'Pending'
                ELSE a.status
            END,
            'notes', a.notes,
            'remarks', a.notes,
            'rejection_reason', a.rejection_reason,
            'created_at', to_char(a.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        ) AS row_data
        FROM public.visitor_appointments a
        JOIN public.visitor_profiles p ON a.visitor_id = p.id
        WHERE a.school_id = p_school_id
          AND (
              v_search = ''
              OR p.full_name ILIKE '%' || v_search || '%'
              OR p.phone ILIKE '%' || v_search || '%'
              OR a.appointment_number ILIKE '%' || v_search || '%'
              OR a.host_name ILIKE '%' || v_search || '%'
              OR a.purpose ILIKE '%' || v_search || '%'
              OR a.destination ILIKE '%' || v_search || '%'
          )
          AND (
              v_location = 'All Locations'
              OR v_location = 'All'
              OR v_location = ''
              OR LOWER(TRIM(COALESCE(a.destination, ''))) = LOWER(TRIM(v_location))
              OR a.destination ILIKE '%' || v_location || '%'
          )
          AND (
              v_category = 'All Visitor Types'
              OR v_category = 'All'
              OR v_category = ''
              OR p.visitor_type = v_category
          )
          AND (
              v_status = 'All Status'
              OR v_status = 'All'
              OR (v_status ILIKE 'Blocked' AND (
                  p.is_blacklisted = TRUE
                  OR EXISTS (
                      SELECT 1 FROM public.visitor_restrictions vr
                      WHERE vr.visitor_id = a.visitor_id
                        AND vr.school_id = a.school_id
                        AND vr.status = 'ACTIVE'
                        AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())
                  )
              ))
              OR (v_status ILIKE 'Confirmed' AND a.status IN ('APPROVED', 'CONFIRMED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
              OR (v_status ILIKE 'Pending' AND a.status IN ('AWAITING_APPROVAL', 'PENDING') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
              OR (v_status ILIKE 'Today' AND a.scheduled_date = CURRENT_DATE AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
              OR (v_status ILIKE 'This Week' AND a.scheduled_date >= CURRENT_DATE AND a.scheduled_date <= (CURRENT_DATE + interval '7 days') AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
              OR (v_status ILIKE 'Expected' AND a.scheduled_date >= CURRENT_DATE AND a.scheduled_date <= (CURRENT_DATE + interval '7 days') AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
              OR (a.status ILIKE v_status AND p.is_blacklisted IS NOT TRUE)
          )
          AND (v_date_from IS NULL OR a.scheduled_date >= v_date_from::DATE)
          AND (v_date_to IS NULL OR a.scheduled_date <= v_date_to::DATE)
        ORDER BY 
            CASE WHEN v_sort_by = 'visitor_name' AND v_sort_order = 'ASC' THEN p.full_name END ASC,
            CASE WHEN v_sort_by = 'visitor_name' AND v_sort_order = 'DESC' THEN p.full_name END DESC,
            CASE WHEN v_sort_by IN ('visitor_type', 'type') AND v_sort_order = 'ASC' THEN p.visitor_type END ASC,
            CASE WHEN v_sort_by IN ('visitor_type', 'type') AND v_sort_order = 'DESC' THEN p.visitor_type END DESC,
            CASE WHEN v_sort_by = 'purpose' AND v_sort_order = 'ASC' THEN a.purpose END ASC,
            CASE WHEN v_sort_by = 'purpose' AND v_sort_order = 'DESC' THEN a.purpose END DESC,
            CASE WHEN v_sort_by IN ('location', 'destination') AND v_sort_order = 'ASC' THEN a.destination END ASC,
            CASE WHEN v_sort_by IN ('location', 'destination') AND v_sort_order = 'DESC' THEN a.destination END DESC,
            CASE WHEN v_sort_by IN ('host_name', 'host') AND v_sort_order = 'ASC' THEN a.host_name END ASC,
            CASE WHEN v_sort_by IN ('host_name', 'host') AND v_sort_order = 'DESC' THEN a.host_name END DESC,
            CASE WHEN v_sort_by IN ('scheduled_date', 'date', 'scheduled_start_at') AND v_sort_order = 'ASC' THEN a.scheduled_start_at END ASC,
            CASE WHEN v_sort_by IN ('scheduled_date', 'date', 'scheduled_start_at') AND v_sort_order = 'DESC' THEN a.scheduled_start_at END DESC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'ASC' THEN a.status END ASC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'DESC' THEN a.status END DESC,
            a.scheduled_date ASC, a.scheduled_start_at ASC
        LIMIT v_page_size OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'records', v_records,
        'pagination', jsonb_build_object(
            'page', v_page,
            'page_size', v_page_size,
            'total_records', v_total_records,
            'total_pages', CEIL(v_total_records::NUMERIC / GREATEST(1, v_page_size))
        )
    );
END;
$$;


-- 4. Blacklisted Visitors KPIs (Single Source of Truth using exact unique_restrictions CTE)
CREATE OR REPLACE FUNCTION public.fn_visitors_get_blacklisted_kpis(
    p_school_id UUID,
    p_filter JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search VARCHAR := TRIM(COALESCE(p_filter->>'search', ''));
    v_location VARCHAR := TRIM(COALESCE(p_filter->>'location', 'All'));
    v_reason VARCHAR := TRIM(COALESCE(p_filter->>'reason', p_filter->>'category', 'All'));
    v_date_from TIMESTAMPTZ := NULL;
    v_date_to TIMESTAMPTZ := NULL;

    v_total_blacklisted INT := 0;
    v_active_blocks INT := 0;
    v_expired_blocks INT := 0;
    v_attempted_entries INT := 0;
BEGIN
    IF p_filter->>'date_from' IS NOT NULL AND p_filter->>'date_from' != '' THEN
        v_date_from := (p_filter->>'date_from')::TIMESTAMPTZ;
    END IF;
    IF p_filter->>'date_to' IS NOT NULL AND p_filter->>'date_to' != '' THEN
        v_date_to := (p_filter->>'date_to')::TIMESTAMPTZ;
    END IF;

    WITH unique_restrictions AS (
        SELECT DISTINCT ON (
            RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10),
            COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')), ''), 'NONE'),
            COALESCE(NULLIF(TRIM(LOWER(p.email)), ''), 'NONE')
        )
            r.id,
            r.visitor_id,
            r.school_id,
            r.scope_type,
            r.scope_name,
            r.reason_category,
            r.status,
            r.created_at,
            p.full_name,
            p.phone
        FROM public.visitor_restrictions r
        JOIN public.visitor_profiles p ON r.visitor_id = p.id
        WHERE r.school_id = p_school_id
        ORDER BY RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10),
                 COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')), ''), 'NONE'),
                 COALESCE(NULLIF(TRIM(LOWER(p.email)), ''), 'NONE'),
                 CASE WHEN UPPER(r.status) = 'ACTIVE' THEN 1 ELSE 2 END,
                 r.created_at DESC
    ),
    filtered_restrictions AS (
        SELECT *
        FROM unique_restrictions ur
        WHERE (
              v_search = ''
              OR ur.full_name ILIKE '%' || v_search || '%'
              OR ur.phone ILIKE '%' || v_search || '%'
              OR ur.reason_category ILIKE '%' || v_search || '%'
              OR ur.scope_name ILIKE '%' || v_search || '%'
          )
          AND (
              v_location = 'All'
              OR v_location = 'All Locations'
              OR v_location = ''
              OR LOWER(TRIM(COALESCE(ur.scope_name, ''))) = LOWER(TRIM(v_location))
              OR ur.scope_name ILIKE '%' || v_location || '%'
              OR (v_location = 'Entire Campus' AND ur.scope_type = 'CAMPUS')
          )
          AND (
              v_reason = 'All'
              OR v_reason = 'All Block Reasons'
              OR v_reason = 'All Visitor Types'
              OR v_reason = ''
              OR LOWER(TRIM(COALESCE(ur.reason_category, ''))) = LOWER(TRIM(v_reason))
              OR ur.reason_category ILIKE '%' || v_reason || '%'
          )
          AND (v_date_from IS NULL OR ur.created_at >= v_date_from)
          AND (v_date_to IS NULL OR ur.created_at <= v_date_to)
    )
    SELECT
        COUNT(*)::INT,
        COUNT(*) FILTER (WHERE UPPER(status) = 'ACTIVE')::INT,
        COUNT(*) FILTER (WHERE UPPER(status) IN ('EXPIRED', 'LIFTED'))::INT
    INTO
        v_total_blacklisted,
        v_active_blocks,
        v_expired_blocks
    FROM filtered_restrictions;

    SELECT COUNT(*)::INT INTO v_attempted_entries
    FROM public.visitor_access_attempts a
    WHERE a.school_id = p_school_id
      AND a.outcome ILIKE 'Blocked%'
      AND (v_date_from IS NULL OR a.attempted_at >= v_date_from)
      AND (v_date_to IS NULL OR a.attempted_at <= v_date_to)
      AND (
          v_location = 'All'
          OR v_location = 'All Locations'
          OR v_location = ''
          OR LOWER(TRIM(COALESCE(a.location_name, ''))) = LOWER(TRIM(v_location))
          OR a.location_name ILIKE '%' || v_location || '%'
      );

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

-- Backward-compatible 3-arg overload delegating to JSONB SSOT implementation
CREATE OR REPLACE FUNCTION public.fn_visitors_get_blacklisted_kpis(
    p_school_id UUID,
    p_date_from TIMESTAMPTZ DEFAULT NULL,
    p_date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN public.fn_visitors_get_blacklisted_kpis(
        p_school_id,
        jsonb_build_object(
            'date_from', p_date_from,
            'date_to', p_date_to
        )
    );
END;
$$;


-- 5. Support 'Ended' (Expired + Lifted) and 'Attempted' status filters in fn_visitors_list_restrictions
CREATE OR REPLACE FUNCTION public.fn_visitors_list_restrictions(
    p_school_id UUID,
    p_params JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search VARCHAR := TRIM(COALESCE(p_params->>'search', ''));
    v_status VARCHAR := TRIM(COALESCE(p_params->>'status', 'All'));
    v_location VARCHAR := TRIM(COALESCE(p_params->>'location', 'All'));
    v_reason VARCHAR := TRIM(COALESCE(p_params->>'reason', p_params->>'category', 'All'));
    v_sort_by VARCHAR := LOWER(TRIM(COALESCE(p_params->>'sort_by', 'created_at')));
    v_sort_order VARCHAR := UPPER(TRIM(COALESCE(p_params->>'sort_order', 'DESC')));
    v_page INT := GREATEST(1, COALESCE((p_params->>'page')::INT, 1));
    v_page_size INT := GREATEST(1, LEAST(100, COALESCE((p_params->>'page_size')::INT, 10)));
    v_offset INT := (v_page - 1) * v_page_size;
    v_total_records INT := 0;
    v_records JSONB := '[]'::JSONB;
    v_date_from TIMESTAMPTZ := NULL;
    v_date_to TIMESTAMPTZ := NULL;
BEGIN
    IF p_params->>'date_from' IS NOT NULL AND p_params->>'date_from' != '' THEN
        v_date_from := (p_params->>'date_from')::TIMESTAMPTZ;
    END IF;
    IF p_params->>'date_to' IS NOT NULL AND p_params->>'date_to' != '' THEN
        v_date_to := (p_params->>'date_to')::TIMESTAMPTZ;
    END IF;

    WITH unique_restrictions AS (
        SELECT DISTINCT ON (
            RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10),
            COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')), ''), 'NONE'),
            COALESCE(NULLIF(TRIM(LOWER(p.email)), ''), 'NONE')
        )
            r.id,
            r.visitor_id,
            r.school_id,
            r.scope_type,
            r.scope_name,
            r.reason_category,
            r.confidential_notes,
            r.remarks,
            r.status,
            r.effective_from,
            r.blocked_on,
            r.valid_till_text,
            r.is_permanent,
            r.expires_at,
            r.review_at,
            r.requested_by_name,
            r.approved_by_name,
            r.lifted_by_name,
            r.lift_reason,
            r.created_at,
            p.full_name,
            p.phone,
            p.photo_url,
            p.email,
            p.id_type,
            p.id_number_masked
        FROM public.visitor_restrictions r
        JOIN public.visitor_profiles p ON r.visitor_id = p.id
        WHERE r.school_id = p_school_id
        ORDER BY RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10),
                 COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')), ''), 'NONE'),
                 COALESCE(NULLIF(TRIM(LOWER(p.email)), ''), 'NONE'),
                 CASE WHEN UPPER(r.status) = 'ACTIVE' THEN 1 ELSE 2 END,
                 r.created_at DESC
    )
    SELECT COUNT(*) INTO v_total_records
    FROM unique_restrictions ur
    WHERE (
          v_search = ''
          OR ur.full_name ILIKE '%' || v_search || '%'
          OR ur.phone ILIKE '%' || v_search || '%'
          OR ur.reason_category ILIKE '%' || v_search || '%'
          OR ur.scope_name ILIKE '%' || v_search || '%'
      )
      AND (
          v_status = 'All'
          OR v_status = 'All Status'
          OR (v_status ILIKE 'Ended' AND UPPER(ur.status) IN ('EXPIRED', 'LIFTED'))
          OR (v_status ILIKE 'Attempted' AND EXISTS (
              SELECT 1 FROM public.visitor_access_attempts aa
              WHERE aa.school_id = ur.school_id
                AND (aa.restriction_id = ur.id OR aa.visitor_id = ur.visitor_id)
                AND aa.outcome ILIKE 'Blocked%'
          ))
          OR UPPER(ur.status) = UPPER(v_status)
      )
      AND (
          v_location = 'All'
          OR v_location = 'All Locations'
          OR v_location = ''
          OR LOWER(TRIM(COALESCE(ur.scope_name, ''))) = LOWER(TRIM(v_location))
          OR ur.scope_name ILIKE '%' || v_location || '%'
          OR (v_location = 'Entire Campus' AND ur.scope_type = 'CAMPUS')
      )
      AND (
          v_reason = 'All'
          OR v_reason = 'All Block Reasons'
          OR v_reason = 'All Visitor Types'
          OR v_reason = ''
          OR LOWER(TRIM(COALESCE(ur.reason_category, ''))) = LOWER(TRIM(v_reason))
          OR ur.reason_category ILIKE '%' || v_reason || '%'
      )
      AND (v_date_from IS NULL OR ur.created_at >= v_date_from)
      AND (v_date_to IS NULL OR ur.created_at <= v_date_to);

    WITH unique_restrictions AS (
        SELECT DISTINCT ON (
            RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10),
            COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')), ''), 'NONE'),
            COALESCE(NULLIF(TRIM(LOWER(p.email)), ''), 'NONE')
        )
            r.id,
            r.visitor_id,
            r.school_id,
            r.scope_type,
            r.scope_name,
            r.reason_category,
            r.confidential_notes,
            r.remarks,
            r.status,
            r.effective_from,
            r.blocked_on,
            r.valid_till_text,
            r.is_permanent,
            r.expires_at,
            r.review_at,
            r.requested_by_name,
            r.approved_by_name,
            r.lifted_by_name,
            r.lift_reason,
            r.created_at,
            p.full_name,
            p.phone,
            p.photo_url,
            p.email,
            p.id_type,
            p.id_number_masked
        FROM public.visitor_restrictions r
        JOIN public.visitor_profiles p ON r.visitor_id = p.id
        WHERE r.school_id = p_school_id
        ORDER BY RIGHT(REGEXP_REPLACE(p.phone, '\D', '', 'g'), 10),
                 COALESCE(NULLIF(TRIM(REGEXP_REPLACE(p.id_number_masked, '\s+', '', 'g')), ''), 'NONE'),
                 COALESCE(NULLIF(TRIM(LOWER(p.email)), ''), 'NONE'),
                 CASE WHEN UPPER(r.status) = 'ACTIVE' THEN 1 ELSE 2 END,
                 r.created_at DESC
    )
    SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_records
    FROM (
        SELECT jsonb_build_object(
            'id', ur.id,
            'visitor_id', ur.visitor_id,
            'visitor_name', ur.full_name,
            'visitor_phone', ur.phone,
            'photo_url', ur.photo_url,
            'mobile_no', ur.phone,
            'phone', ur.phone,
            'email', COALESCE(ur.email, ''),
            'id_type', COALESCE(ur.id_type, 'Aadhaar Card'),
            'id_number', COALESCE(ur.id_number_masked, 'XXXX-XXXX-1234'),
            'id_number_masked', COALESCE(ur.id_number_masked, 'XXXX-XXXX-1234'),
            'scope_type', ur.scope_type,
            'scope_name', ur.scope_name,
            'reason_category', ur.reason_category,
            'confidential_notes', ur.confidential_notes,
            'remarks', ur.remarks,
            'status', ur.status,
            'effective_from', to_char(ur.effective_from, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'blocked_on', to_char(COALESCE(ur.blocked_on, ur.created_at), 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'valid_till', ur.valid_till_text,
            'valid_till_text', ur.valid_till_text,
            'is_permanent', ur.is_permanent,
            'expires_at', to_char(ur.expires_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'review_at', to_char(ur.review_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'requested_by_name', ur.requested_by_name,
            'approved_by_name', ur.approved_by_name,
            'blocked_by_name', COALESCE(ur.requested_by_name, 'Rahul Sharma (Security)'),
            'lifted_by_name', ur.lifted_by_name,
            'lift_reason', ur.lift_reason,
            'created_at', to_char(ur.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        ) AS row_data
        FROM unique_restrictions ur
        WHERE (
              v_search = ''
              OR ur.full_name ILIKE '%' || v_search || '%'
              OR ur.phone ILIKE '%' || v_search || '%'
              OR ur.reason_category ILIKE '%' || v_search || '%'
              OR ur.scope_name ILIKE '%' || v_search || '%'
          )
          AND (
              v_status = 'All'
              OR v_status = 'All Status'
              OR (v_status ILIKE 'Ended' AND UPPER(ur.status) IN ('EXPIRED', 'LIFTED'))
              OR (v_status ILIKE 'Attempted' AND EXISTS (
                  SELECT 1 FROM public.visitor_access_attempts aa
                  WHERE aa.school_id = ur.school_id
                    AND (aa.restriction_id = ur.id OR aa.visitor_id = ur.visitor_id)
                    AND aa.outcome ILIKE 'Blocked%'
              ))
              OR UPPER(ur.status) = UPPER(v_status)
          )
          AND (
              v_location = 'All'
              OR v_location = 'All Locations'
              OR v_location = ''
              OR LOWER(TRIM(COALESCE(ur.scope_name, ''))) = LOWER(TRIM(v_location))
              OR ur.scope_name ILIKE '%' || v_location || '%'
              OR (v_location = 'Entire Campus' AND ur.scope_type = 'CAMPUS')
          )
          AND (
              v_reason = 'All'
              OR v_reason = 'All Block Reasons'
              OR v_reason = 'All Visitor Types'
              OR v_reason = ''
              OR LOWER(TRIM(COALESCE(ur.reason_category, ''))) = LOWER(TRIM(v_reason))
              OR ur.reason_category ILIKE '%' || v_reason || '%'
          )
          AND (v_date_from IS NULL OR ur.created_at >= v_date_from)
          AND (v_date_to IS NULL OR ur.created_at <= v_date_to)
        ORDER BY 
            CASE WHEN v_sort_by IN ('name', 'visitor_name') AND v_sort_order = 'ASC' THEN ur.full_name END ASC,
            CASE WHEN v_sort_by IN ('name', 'visitor_name') AND v_sort_order = 'DESC' THEN ur.full_name END DESC,
            CASE WHEN v_sort_by IN ('phone', 'mobile_no') AND v_sort_order = 'ASC' THEN ur.phone END ASC,
            CASE WHEN v_sort_by IN ('phone', 'mobile_no') AND v_sort_order = 'DESC' THEN ur.phone END DESC,
            CASE WHEN v_sort_by IN ('id_number', 'id_number_masked') AND v_sort_order = 'ASC' THEN ur.id_number_masked END ASC,
            CASE WHEN v_sort_by IN ('id_number', 'id_number_masked') AND v_sort_order = 'DESC' THEN ur.id_number_masked END DESC,
            CASE WHEN v_sort_by IN ('reason', 'reason_category', 'block_reason') AND v_sort_order = 'ASC' THEN ur.reason_category END ASC,
            CASE WHEN v_sort_by IN ('reason', 'reason_category', 'block_reason') AND v_sort_order = 'DESC' THEN ur.reason_category END DESC,
            CASE WHEN v_sort_by IN ('location', 'scope_name') AND v_sort_order = 'ASC' THEN ur.scope_name END ASC,
            CASE WHEN v_sort_by IN ('location', 'scope_name') AND v_sort_order = 'DESC' THEN ur.scope_name END DESC,
            CASE WHEN v_sort_by = 'blocked_on' AND v_sort_order = 'ASC' THEN ur.blocked_on END ASC,
            CASE WHEN v_sort_by = 'blocked_on' AND v_sort_order = 'DESC' THEN ur.blocked_on END DESC,
            CASE WHEN v_sort_by = 'valid_till' AND v_sort_order = 'ASC' THEN ur.valid_till_text END ASC,
            CASE WHEN v_sort_by = 'valid_till' AND v_sort_order = 'DESC' THEN ur.valid_till_text END DESC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'ASC' THEN ur.status END ASC,
            CASE WHEN v_sort_by = 'status' AND v_sort_order = 'DESC' THEN ur.status END DESC,
            CASE WHEN UPPER(ur.status) = 'ACTIVE' THEN 1 ELSE 2 END,
            ur.created_at DESC
        LIMIT v_page_size OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'records', v_records,
        'pagination', jsonb_build_object(
            'total_records', v_total_records,
            'page', v_page,
            'page_size', v_page_size,
            'total_pages', CEIL(v_total_records::NUMERIC / GREATEST(1, v_page_size))
        )
    );
END;
$$;
