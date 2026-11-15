-- Migration 380: Align visitor appointments date filtering and display to timestamptz
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
      AND (p_date_from IS NULL OR COALESCE(scheduled_start_at, (scheduled_date::text || ' 00:00:00+00')::timestamptz) >= p_date_from)
      AND (p_date_to IS NULL OR COALESCE(scheduled_start_at, (scheduled_date::text || ' 23:59:59+00')::timestamptz) <= p_date_to);

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
          OR a.destination = v_location
      )
      AND (
          v_category = 'All Visitor Types'
          OR v_category = 'All'
          OR p.visitor_type = v_category
      )
      AND (
          v_status = 'All Status'
          OR v_status = 'All'
          OR (v_status ILIKE 'Confirmed' AND a.status IN ('APPROVED', 'CONFIRMED'))
          OR (v_status ILIKE 'Pending' AND a.status IN ('AWAITING_APPROVAL', 'PENDING'))
          OR (v_status ILIKE 'Today' AND a.scheduled_date = CURRENT_DATE AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED'))
          OR (v_status ILIKE 'This Week' AND a.scheduled_date >= CURRENT_DATE AND a.scheduled_date <= (CURRENT_DATE + interval '7 days') AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED'))
          OR (v_status ILIKE 'Expected' AND a.scheduled_date >= CURRENT_DATE AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED'))
          OR a.status ILIKE v_status
      )
      AND (
          v_date_from IS NULL
          OR COALESCE(a.scheduled_start_at, (a.scheduled_date::text || ' 00:00:00+00')::timestamptz) >= v_date_from
      )
      AND (
          v_date_to IS NULL
          OR COALESCE(a.scheduled_start_at, (a.scheduled_date::text || ' 23:59:59+00')::timestamptz) <= v_date_to
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
            'email', COALESCE(a.email, p.email, '-'),
            'visitor_type', p.visitor_type,
            'id_type', p.id_type,
            'id_number_masked', p.id_number_masked,
            'purpose', a.purpose,
            'location', a.destination,
            'destination', a.destination,
            'host_name', a.host_name,
            'host_department', a.host_department,
            'scheduled_date', to_char(COALESCE(a.scheduled_start_at, a.scheduled_date::timestamptz), 'DD Mon YYYY'),
            'scheduled_start_at', to_char(a.scheduled_start_at, 'HH12:MI AM'),
            'scheduled_end_at', to_char(a.scheduled_end_at, 'HH12:MI AM'),
            'time_window', to_char(COALESCE(a.scheduled_start_at, a.scheduled_date::timestamptz), 'DD Mon YYYY') || E'\n' || to_char(a.scheduled_start_at, 'HH12:MI AM') || ' - ' || to_char(a.scheduled_end_at, 'HH12:MI AM'),
            'expected_count', a.expected_count,
            'expected_visitors_text', COALESCE(a.expected_visitors_text, a.expected_count || ' (Expected)'),
            'vehicle_number', COALESCE(a.vehicle_number, '-'),
            'notes', COALESCE(a.notes, '-'),
            'status', CASE
                WHEN a.status IN ('APPROVED', 'CONFIRMED') THEN 'Confirmed'
                WHEN a.status IN ('AWAITING_APPROVAL', 'PENDING') THEN 'Pending'
                WHEN a.status = 'REJECTED' THEN 'Rejected'
                WHEN a.status = 'CANCELLED' THEN 'Cancelled'
                ELSE a.status
            END,
            'created_at', a.created_at
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
              OR a.destination = v_location
          )
          AND (
              v_category = 'All Visitor Types'
              OR v_category = 'All'
              OR p.visitor_type = v_category
          )
          AND (
              v_status = 'All Status'
              OR v_status = 'All'
              OR (v_status ILIKE 'Confirmed' AND a.status IN ('APPROVED', 'CONFIRMED'))
              OR (v_status ILIKE 'Pending' AND a.status IN ('AWAITING_APPROVAL', 'PENDING'))
              OR (v_status ILIKE 'Today' AND a.scheduled_date = CURRENT_DATE AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED'))
              OR (v_status ILIKE 'This Week' AND a.scheduled_date >= CURRENT_DATE AND a.scheduled_date <= (CURRENT_DATE + interval '7 days') AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED'))
              OR (v_status ILIKE 'Expected' AND a.scheduled_date >= CURRENT_DATE AND a.status NOT IN ('REJECTED', 'CANCELLED', 'COMPLETED'))
              OR a.status ILIKE v_status
          )
          AND (
              v_date_from IS NULL
              OR COALESCE(a.scheduled_start_at, (a.scheduled_date::text || ' 00:00:00+00')::timestamptz) >= v_date_from
          )
          AND (
              v_date_to IS NULL
              OR COALESCE(a.scheduled_start_at, (a.scheduled_date::text || ' 23:59:59+00')::timestamptz) <= v_date_to
          )
        ORDER BY a.scheduled_date DESC, a.scheduled_start_at DESC
        LIMIT v_page_size OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'records', v_records,
        'pagination', jsonb_build_object(
            'page', v_page,
            'page_size', v_page_size,
            'total', v_total_records,
            'total_records', v_total_records,
            'total_pages', CEIL(v_total_records::NUMERIC / v_page_size)::INT
        )
    );
END;
$$;
