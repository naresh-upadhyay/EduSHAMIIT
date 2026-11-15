-- Migration 377: Enhanced Visitor Visits Date Range Filtering
-- Updates fn_visitors_list_visits to support date_from and date_to filtering

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
    v_date_from TIMESTAMPTZ := NULL;
    v_date_to TIMESTAMPTZ := NULL;
    v_page INT := GREATEST(1, COALESCE((p_params->>'page')::INT, 1));
    v_page_size INT := GREATEST(1, LEAST(100, COALESCE((p_params->>'page_size')::INT, 10)));
    v_offset INT := (v_page - 1) * v_page_size;
    v_total_records INT := 0;
    v_records JSONB := '[]'::JSONB;
BEGIN
    -- Parse date boundaries if provided
    IF p_params->>'date_from' IS NOT NULL AND TRIM(p_params->>'date_from') != '' THEN
        BEGIN
            v_date_from := (p_params->>'date_from')::TIMESTAMPTZ;
        EXCEPTION WHEN OTHERS THEN
            v_date_from := NULL;
        END;
    END IF;

    IF p_params->>'date_to' IS NOT NULL AND TRIM(p_params->>'date_to') != '' THEN
        BEGIN
            v_date_to := (p_params->>'date_to')::TIMESTAMPTZ;
        EXCEPTION WHEN OTHERS THEN
            v_date_to := NULL;
        END;
    END IF;

    -- Count matching visits
    SELECT COUNT(*) INTO v_total_records
    FROM public.visitor_visits v
    JOIN public.visitor_profiles p ON v.visitor_id = p.id
    WHERE v.school_id = p_school_id
      AND (
          v_search = ''
          OR p.full_name ILIKE '%' || v_search || '%'
          OR p.phone ILIKE '%' || v_search || '%'
          OR COALESCE(p.company, '') ILIKE '%' || v_search || '%'
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
          OR (v_status = 'Inside' AND v.status = 'Inside' AND (v.expected_out_at IS NULL OR v.expected_out_at >= NOW()))
          OR (v_status = 'Checked Out' AND v.status = 'Checked Out')
          OR (v_status = 'Overstay' AND (v.status = 'Overstay' OR (v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < NOW())))
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
            'entry_location', v.entry_location,
            'host_name', v.host_name,
            'host_department', v.host_department,
            'check_in_at', to_char(v.check_in_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'expected_out_at', to_char(v.expected_out_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'actual_check_out_at', to_char(v.actual_check_out_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'status', CASE
                WHEN v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < NOW() THEN 'Overstay'
                ELSE v.status
            END,
            'vehicle_number', v.vehicle_number,
            'pass_reference', v.pass_reference,
            'remarks', v.remarks,
            'created_at', to_char(v.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        ) AS row_data
        FROM public.visitor_visits v
        JOIN public.visitor_profiles p ON v.visitor_id = p.id
        WHERE v.school_id = p_school_id
          AND (
              v_search = ''
              OR p.full_name ILIKE '%' || v_search || '%'
              OR p.phone ILIKE '%' || v_search || '%'
              OR COALESCE(p.company, '') ILIKE '%' || v_search || '%'
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
              OR (v_status = 'Inside' AND v.status = 'Inside' AND (v.expected_out_at IS NULL OR v.expected_out_at >= NOW()))
              OR (v_status = 'Checked Out' AND v.status = 'Checked Out')
              OR (v_status = 'Overstay' AND (v.status = 'Overstay' OR (v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < NOW())))
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
        ORDER BY v.check_in_at DESC NULLS LAST, v.created_at DESC
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
