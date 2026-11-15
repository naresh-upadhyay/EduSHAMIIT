-- Migration 386: Fix location filter accuracy across all tabs, add grid sorting support, and enhance location/reason resolution
-- 1. Updates fn_visitors_list_visits: Fix location filter matching on destination rather than overriding on entry_location, add sorting parameters.
-- 2. Updates fn_visitors_list_appointments: Ensure robust case-insensitive location filtering and sorting.
-- 3. Updates fn_visitors_list_restrictions: Add location (scope_name/scope_type) and reason_category filtering, plus sorting support.

-- ============================================================================
-- 1. Enhanced fn_visitors_list_visits (Fixed Location Filtering & Sorting)
-- ============================================================================
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
      -- Fix: Location filter matches destination (the displayed institute location).
      -- Falls back to entry_location only when destination is unspecified.
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
              OR COALESCE(v.check_in_at, v.created_at) >= v_date_from
          )
          AND (
              v_date_to IS NULL
              OR COALESCE(v.check_in_at, v.created_at) <= v_date_to
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


-- ============================================================================
-- 2. Enhanced fn_visitors_list_appointments (Robust Location Filter & Sorting)
-- ============================================================================
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
          OR LOWER(TRIM(COALESCE(a.destination, ''))) = LOWER(TRIM(v_location))
          OR a.destination ILIKE '%' || v_location || '%'
      )
      AND (
          v_category = 'All Visitor Types'
          OR v_category = 'All'
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
          OR (v_status ILIKE 'Expected' AND a.scheduled_date >= CURRENT_DATE AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
          OR (a.status ILIKE v_status AND p.is_blacklisted IS NOT TRUE)
      )
      AND (
          v_date_from IS NULL
          OR a.scheduled_date >= v_date_from::DATE
      )
      AND (
          v_date_to IS NULL
          OR a.scheduled_date <= v_date_to::DATE
      );

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
              OR LOWER(TRIM(COALESCE(a.destination, ''))) = LOWER(TRIM(v_location))
              OR a.destination ILIKE '%' || v_location || '%'
          )
          AND (
              v_category = 'All Visitor Types'
              OR v_category = 'All'
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
              OR (v_status ILIKE 'Expected' AND a.scheduled_date >= CURRENT_DATE AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED') AND p.is_blacklisted IS NOT TRUE AND NOT EXISTS (SELECT 1 FROM public.visitor_restrictions vr WHERE vr.visitor_id = a.visitor_id AND vr.school_id = a.school_id AND vr.status = 'ACTIVE' AND (vr.expires_at IS NULL OR vr.expires_at >= NOW())))
              OR (a.status ILIKE v_status AND p.is_blacklisted IS NOT TRUE)
          )
          AND (
              v_date_from IS NULL
              OR a.scheduled_date >= v_date_from::DATE
          )
          AND (
              v_date_to IS NULL
              OR a.scheduled_date <= v_date_to::DATE
          )
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


-- ============================================================================
-- 3. Enhanced fn_visitors_list_restrictions (Added Location & Reason Filters + Sorting)
-- ============================================================================
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

    -- CTE to pick the single canonical restriction for each unique visitor by Mobile Number, Aadhaar, and Email:
    -- (Name CAN be the same for two different persons, but Mobile + Adhar + Email together defines the unique person)
    -- If a visitor has an ACTIVE restriction, pick that ACTIVE restriction.
    -- Otherwise, pick their most recent restriction (LIFTED or EXPIRED).
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
          OR UPPER(ur.status) = UPPER(v_status)
      )
      AND (
          v_location = 'All'
          OR v_location = 'All Locations'
          OR LOWER(TRIM(COALESCE(ur.scope_name, ''))) = LOWER(TRIM(v_location))
          OR ur.scope_name ILIKE '%' || v_location || '%'
          OR (v_location = 'Entire Campus' AND ur.scope_type = 'CAMPUS')
      )
      AND (
          v_reason = 'All'
          OR v_reason = 'All Block Reasons'
          OR v_reason = 'All Visitor Types'
          OR LOWER(TRIM(COALESCE(ur.reason_category, ''))) = LOWER(TRIM(v_reason))
          OR ur.reason_category ILIKE '%' || v_reason || '%'
      )
      AND (
          v_date_from IS NULL
          OR ur.created_at >= v_date_from
      )
      AND (
          v_date_to IS NULL
          OR ur.created_at <= v_date_to
      );

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
              OR UPPER(ur.status) = UPPER(v_status)
          )
          AND (
              v_location = 'All'
              OR v_location = 'All Locations'
              OR LOWER(TRIM(COALESCE(ur.scope_name, ''))) = LOWER(TRIM(v_location))
              OR ur.scope_name ILIKE '%' || v_location || '%'
              OR (v_location = 'Entire Campus' AND ur.scope_type = 'CAMPUS')
          )
          AND (
              v_reason = 'All'
              OR v_reason = 'All Block Reasons'
              OR v_reason = 'All Visitor Types'
              OR LOWER(TRIM(COALESCE(ur.reason_category, ''))) = LOWER(TRIM(v_reason))
              OR ur.reason_category ILIKE '%' || v_reason || '%'
          )
          AND (
              v_date_from IS NULL
              OR ur.created_at >= v_date_from
          )
          AND (
              v_date_to IS NULL
              OR ur.created_at <= v_date_to
          )
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
