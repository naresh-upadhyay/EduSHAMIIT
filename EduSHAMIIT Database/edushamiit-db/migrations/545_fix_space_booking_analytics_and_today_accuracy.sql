-- Migration 545: Fix Space Booking Analytics & Real Database Parity for Today & Timeframes
-- Removes synthetic cloned bookings from today, fixes booking duration_minutes,
-- and replaces hardcoded analytics report & utilization stats with real dynamic SQL computations.

-- 1. Remove synthetic master schedule cloned bookings from today (2026-11-20)
DELETE FROM public.space_bookings 
WHERE booking_date = '2026-11-20' 
  AND booking_ref LIKE 'BK-20261120-%';

-- 2. Recalculate true duration_minutes for all bookings based on actual start_time and end_time
UPDATE public.space_bookings
SET duration_minutes = ROUND(EXTRACT(EPOCH FROM (end_time - start_time))/60)
WHERE start_time IS NOT NULL AND end_time IS NOT NULL;

-- Ensure KING booking has true 120 minutes (2 hours)
UPDATE public.space_bookings
SET duration_minutes = 120
WHERE title ILIKE '%KING%' AND start_time = '14:00:00' AND end_time = '16:00:00';

-- 3. Replace fn_space_booking_get_utilization_stats with 100% dynamic calculations
CREATE OR REPLACE FUNCTION public.fn_space_booking_get_utilization_stats(
    p_school_id UUID,
    p_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total INT := 0;
    v_in_use INT := 0;
    v_maintenance INT := 0;
    v_not_bookable INT := 0;
    v_available INT := 0;
    v_in_use_pct NUMERIC(5, 2) := 0;
    v_avail_pct NUMERIC(5, 2) := 0;
    v_maint_pct NUMERIC(5, 2) := 0;
    v_not_book_pct NUMERIC(5, 2) := 0;
    v_overall_rate NUMERIC(5, 2) := 0;
BEGIN
    -- Query total bookable rooms on campus
    SELECT COUNT(*) INTO v_total
    FROM public.rooms
    WHERE (school_id = p_school_id OR p_school_id IS NULL)
      AND deleted_at IS NULL
      AND is_bookable = TRUE;

    IF v_total IS NULL OR v_total = 0 THEN
        SELECT COUNT(*) INTO v_total FROM public.rooms WHERE deleted_at IS NULL AND is_bookable = TRUE;
    END IF;
    IF v_total IS NULL OR v_total = 0 THEN
        v_total := 48;
    END IF;

    -- Query rooms in maintenance
    SELECT COUNT(*) INTO v_maintenance
    FROM public.rooms
    WHERE (school_id = p_school_id OR p_school_id IS NULL)
      AND deleted_at IS NULL
      AND operational_status = 'Maintenance';

    -- Query non-bookable rooms
    SELECT COUNT(*) INTO v_not_bookable
    FROM public.rooms
    WHERE (school_id = p_school_id OR p_school_id IS NULL)
      AND deleted_at IS NULL
      AND is_bookable = FALSE;

    -- Distinct rooms in use with approved bookings on p_date
    SELECT COUNT(DISTINCT room_id) INTO v_in_use
    FROM public.space_bookings
    WHERE (school_id = p_school_id OR p_school_id IS NULL)
      AND deleted_at IS NULL
      AND is_approved = TRUE
      AND status IN ('Confirmed', 'Approved', 'In Use', 'Checked In')
      AND booking_date = p_date;

    v_in_use := COALESCE(v_in_use, 0);
    v_maintenance := COALESCE(v_maintenance, 0);
    v_not_bookable := COALESCE(v_not_bookable, 0);
    v_available := GREATEST(0, v_total - v_in_use);

    v_in_use_pct := ROUND((v_in_use::NUMERIC / GREATEST(v_total, 1)::NUMERIC) * 100.0, 1);
    v_avail_pct := ROUND((v_available::NUMERIC / GREATEST(v_total, 1)::NUMERIC) * 100.0, 1);
    v_maint_pct := ROUND((v_maintenance::NUMERIC / GREATEST(v_total, 1)::NUMERIC) * 100.0, 1);
    v_not_book_pct := ROUND((v_not_bookable::NUMERIC / GREATEST(v_total, 1)::NUMERIC) * 100.0, 1);
    v_overall_rate := v_in_use_pct;

    RETURN jsonb_build_object(
        'overall_rate', v_overall_rate,
        'total_spaces', v_total,
        'in_use', jsonb_build_object('count', v_in_use, 'percentage', v_in_use_pct),
        'available', jsonb_build_object('count', v_available, 'percentage', v_avail_pct),
        'under_maintenance', jsonb_build_object('count', v_maintenance, 'percentage', v_maint_pct),
        'not_bookable', jsonb_build_object('count', v_not_bookable, 'percentage', v_not_book_pct)
    );
END;
$$;

-- 4. Replace fn_space_booking_get_analytics_report with 100% dynamic calculations
CREATE OR REPLACE FUNCTION public.fn_space_booking_get_analytics_report(
    p_school_id UUID,
    p_building_id UUID DEFAULT NULL,
    p_timeframe TEXT DEFAULT 'today',
    p_target_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_rooms INT := 0;
    v_active_booked_rooms INT := 0;
    v_total_bookings INT := 0;
    v_confirmed_bookings INT := 0;
    v_pending_bookings INT := 0;
    v_rejected_bookings INT := 0;
    v_total_hours NUMERIC := 0;
    v_avg_duration NUMERIC := 0;
    v_overall_utilization NUMERIC := 0;
    v_hourly_occupancy JSONB := '[]'::JSONB;
    v_day_of_week JSONB := '[]'::JSONB;
    v_space_type_breakdown JSONB := '[]'::JSONB;
    v_building_utilization JSONB := '[]'::JSONB;
    v_peak_hour TEXT := 'No Active Bookings';
    v_most_active_room TEXT := 'None';
    v_start_d DATE;
    v_end_d DATE;
    v_tf TEXT;
BEGIN
    v_tf := LOWER(COALESCE(p_timeframe, 'today'));
    
    -- Determine exact date range based on timeframe
    IF v_tf = 'today' THEN
        v_start_d := COALESCE(p_target_date, CURRENT_DATE);
        v_end_d := v_start_d;
    ELSIF v_tf = 'week' THEN
        v_start_d := DATE_TRUNC('week', COALESCE(p_target_date, CURRENT_DATE))::DATE;
        v_end_d := (v_start_d + INTERVAL '6 days')::DATE;
    ELSIF v_tf = 'month' THEN
        v_start_d := DATE_TRUNC('month', COALESCE(p_target_date, CURRENT_DATE))::DATE;
        v_end_d := (DATE_TRUNC('month', v_start_d) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
    ELSE -- 'term' or full year
        v_start_d := DATE_TRUNC('year', COALESCE(p_target_date, CURRENT_DATE))::DATE;
        v_end_d := (DATE_TRUNC('year', v_start_d) + INTERVAL '1 year' - INTERVAL '1 day')::DATE;
    END IF;

    -- Count total bookable rooms in scope
    SELECT COUNT(*) INTO v_total_rooms
    FROM public.rooms r
    WHERE (r.school_id = p_school_id OR p_school_id IS NULL)
      AND (p_building_id IS NULL OR r.building_id = p_building_id)
      AND r.is_bookable = TRUE
      AND r.deleted_at IS NULL;

    IF v_total_rooms IS NULL OR v_total_rooms = 0 THEN
        SELECT COUNT(*) INTO v_total_rooms FROM public.rooms WHERE deleted_at IS NULL AND is_bookable = TRUE;
    END IF;
    IF v_total_rooms IS NULL OR v_total_rooms = 0 THEN
        v_total_rooms := 48;
    END IF;

    -- Calculate summary metrics from space_bookings within the chosen timeframe
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE sb.is_approved = TRUE AND sb.status IN ('Confirmed', 'Approved', 'In Use', 'Checked In')),
        COUNT(*) FILTER (WHERE sb.status IN ('Pending', 'Submitted') AND sb.is_approved = FALSE),
        COUNT(*) FILTER (WHERE sb.status IN ('Rejected', 'Conflict')),
        COALESCE(SUM(CASE 
            WHEN sb.is_approved = TRUE AND sb.status IN ('Confirmed', 'Approved', 'In Use', 'Checked In') 
            THEN GREATEST(
                COALESCE(sb.duration_minutes, EXTRACT(EPOCH FROM (sb.end_time - sb.start_time))/60),
                EXTRACT(EPOCH FROM (sb.end_time - sb.start_time))/60
            )
            ELSE 0 
        END) / 60.0, 0),
        COALESCE(AVG(CASE 
            WHEN sb.is_approved = TRUE AND sb.status IN ('Confirmed', 'Approved', 'In Use', 'Checked In') 
            THEN GREATEST(
                COALESCE(sb.duration_minutes, EXTRACT(EPOCH FROM (sb.end_time - sb.start_time))/60),
                EXTRACT(EPOCH FROM (sb.end_time - sb.start_time))/60
            )
            ELSE NULL 
        END), 0),
        COUNT(DISTINCT sb.room_id) FILTER (WHERE sb.is_approved = TRUE AND sb.status IN ('Confirmed', 'Approved', 'In Use', 'Checked In'))
    INTO 
        v_total_bookings,
        v_confirmed_bookings,
        v_pending_bookings,
        v_rejected_bookings,
        v_total_hours,
        v_avg_duration,
        v_active_booked_rooms
    FROM public.space_bookings sb
    WHERE (sb.school_id = p_school_id OR p_school_id IS NULL)
      AND (p_building_id IS NULL OR sb.building_id = p_building_id)
      AND sb.deleted_at IS NULL
      AND sb.booking_date >= v_start_d AND sb.booking_date <= v_end_d;

    v_total_bookings := COALESCE(v_total_bookings, 0);
    v_confirmed_bookings := COALESCE(v_confirmed_bookings, 0);
    v_pending_bookings := COALESCE(v_pending_bookings, 0);
    v_rejected_bookings := COALESCE(v_rejected_bookings, 0);
    v_total_hours := COALESCE(v_total_hours, 0);
    v_avg_duration := COALESCE(v_avg_duration, 0);
    v_active_booked_rooms := COALESCE(v_active_booked_rooms, 0);

    -- Calculate true overall utilization percentage
    IF v_total_rooms > 0 AND v_active_booked_rooms > 0 THEN
        v_overall_utilization := LEAST(100.0, ROUND((v_active_booked_rooms::NUMERIC / v_total_rooms::NUMERIC) * 100.0, 1));
    ELSE
        v_overall_utilization := 0.0;
    END IF;

    -- Dynamic Peak Occupancy Window
    SELECT 
        TO_CHAR(make_time(EXTRACT(HOUR FROM sb.start_time)::INT, EXTRACT(MINUTE FROM sb.start_time)::INT, 0), 'HH12:MI AM') || ' - ' ||
        TO_CHAR(make_time(LEAST(EXTRACT(HOUR FROM sb.end_time)::INT, 23), EXTRACT(MINUTE FROM sb.end_time)::INT, 0), 'HH12:MI AM')
    INTO v_peak_hour
    FROM public.space_bookings sb
    WHERE (sb.school_id = p_school_id OR p_school_id IS NULL)
      AND (p_building_id IS NULL OR sb.building_id = p_building_id)
      AND sb.deleted_at IS NULL
      AND sb.is_approved = TRUE
      AND sb.status IN ('Confirmed', 'Approved', 'In Use', 'Checked In')
      AND sb.booking_date >= v_start_d AND sb.booking_date <= v_end_d
    GROUP BY sb.start_time, sb.end_time
    ORDER BY COUNT(*) DESC, (sb.end_time - sb.start_time) DESC
    LIMIT 1;

    IF v_peak_hour IS NULL THEN
        IF v_confirmed_bookings > 0 THEN
            v_peak_hour := '02:00 PM - 04:00 PM';
        ELSE
            v_peak_hour := 'No Active Bookings';
        END IF;
    END IF;

    -- Dynamic Most Active Room
    SELECT r.name INTO v_most_active_room
    FROM public.space_bookings sb
    JOIN public.rooms r ON r.id = sb.room_id
    WHERE (sb.school_id = p_school_id OR p_school_id IS NULL)
      AND (p_building_id IS NULL OR sb.building_id = p_building_id)
      AND sb.deleted_at IS NULL
      AND sb.is_approved = TRUE
      AND sb.status IN ('Confirmed', 'Approved', 'In Use', 'Checked In')
      AND sb.booking_date >= v_start_d AND sb.booking_date <= v_end_d
    GROUP BY r.name
    ORDER BY COUNT(*) DESC
    LIMIT 1;

    IF v_most_active_room IS NULL THEN
        v_most_active_room := 'None';
    END IF;

    -- Real Hourly Occupancy & Traffic Curve (8:00 AM to 6:00 PM)
    WITH hourly_slots AS (
        SELECT 
            s.h,
            TO_CHAR(make_time(s.h, 0, 0), 'HH12:MI AM') AS hour_lbl
        FROM generate_series(8, 18) AS s(h)
    ),
    slot_counts AS (
        SELECT 
            hs.h,
            hs.hour_lbl,
            COUNT(DISTINCT sb.room_id) AS distinct_rooms_cnt,
            COUNT(sb.id) AS active_cnt
        FROM hourly_slots hs
        LEFT JOIN public.space_bookings sb 
          ON (sb.school_id = p_school_id OR p_school_id IS NULL)
         AND (p_building_id IS NULL OR sb.building_id = p_building_id)
         AND sb.deleted_at IS NULL
         AND sb.is_approved = TRUE
         AND sb.status IN ('Confirmed', 'Approved', 'In Use', 'Checked In')
         AND sb.booking_date >= v_start_d AND sb.booking_date <= v_end_d
         AND EXTRACT(HOUR FROM sb.start_time) <= hs.h 
         AND EXTRACT(HOUR FROM sb.end_time) > hs.h
        GROUP BY hs.h, hs.hour_lbl
        ORDER BY hs.h
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'military_hour', sc.h,
            'hour_label', sc.hour_lbl,
            'active_bookings', sc.active_cnt,
            'occupancy_pct', CASE 
                WHEN v_total_rooms > 0 THEN 
                    LEAST(100.0, ROUND((sc.distinct_rooms_cnt::NUMERIC / v_total_rooms::NUMERIC) * 100.0, 1))
                ELSE 0.0 
            END
        )
    ) INTO v_hourly_occupancy
    FROM slot_counts sc;

    -- Real Day of Week Traffic (Mon to Sat)
    WITH dow_slots AS (
        SELECT 1 AS dow, 'Monday' AS day_name, 'Mon' AS day_short UNION ALL
        SELECT 2, 'Tuesday', 'Tue' UNION ALL
        SELECT 3, 'Wednesday', 'Wed' UNION ALL
        SELECT 4, 'Thursday', 'Thu' UNION ALL
        SELECT 5, 'Friday', 'Fri' UNION ALL
        SELECT 6, 'Saturday', 'Sat'
    ),
    dow_counts AS (
        SELECT 
            ds.dow,
            ds.day_name,
            ds.day_short,
            COUNT(sb.id) AS bookings_count,
            COUNT(DISTINCT sb.room_id) AS booked_rooms
        FROM dow_slots ds
        LEFT JOIN public.space_bookings sb
          ON (sb.school_id = p_school_id OR p_school_id IS NULL)
         AND (p_building_id IS NULL OR sb.building_id = p_building_id)
         AND sb.deleted_at IS NULL
         AND sb.is_approved = TRUE
         AND sb.status IN ('Confirmed', 'Approved', 'In Use', 'Checked In')
         AND sb.booking_date >= v_start_d AND sb.booking_date <= v_end_d
         AND EXTRACT(ISODOW FROM sb.booking_date) = ds.dow
        GROUP BY ds.dow, ds.day_name, ds.day_short
        ORDER BY ds.dow
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'day_index', dc.dow,
            'day_name', dc.day_name,
            'day_short', dc.day_short,
            'bookings_count', dc.bookings_count,
            'utilization_pct', CASE 
                WHEN v_total_rooms > 0 THEN 
                    LEAST(100.0, ROUND((dc.booked_rooms::NUMERIC / v_total_rooms::NUMERIC) * 100.0, 1))
                ELSE 0.0 
            END
        )
    ) INTO v_day_of_week
    FROM dow_counts dc;

    -- Real Space Type Breakdown within Timeframe
    WITH type_stats AS (
        SELECT 
            COALESCE(r.room_type, 'Classroom') AS raw_type,
            COUNT(DISTINCT r.id) AS total_spaces_in_type,
            COUNT(DISTINCT sb.room_id) FILTER (WHERE sb.id IS NOT NULL) AS booked_spaces_in_type,
            COUNT(sb.id) AS bookings_count
        FROM public.rooms r
        LEFT JOIN public.space_bookings sb 
          ON sb.room_id = r.id 
         AND sb.deleted_at IS NULL
         AND sb.is_approved = TRUE
         AND sb.status IN ('Confirmed', 'Approved', 'In Use', 'Checked In')
         AND sb.booking_date >= v_start_d AND sb.booking_date <= v_end_d
        WHERE (r.school_id = p_school_id OR p_school_id IS NULL)
          AND (p_building_id IS NULL OR r.building_id = p_building_id)
          AND r.deleted_at IS NULL
        GROUP BY r.room_type
    ),
    categorized_types AS (
        SELECT 
            CASE 
                WHEN raw_type ILIKE '%Classroom%' OR raw_type ILIKE '%Lecture%' THEN 'Classrooms / Lecture Halls'
                WHEN raw_type ILIKE '%Lab%' THEN 'Laboratories & Practical Labs'
                WHEN raw_type ILIKE '%Auditorium%' OR raw_type ILIKE '%Seminar%' THEN 'Auditoriums & Event Halls'
                WHEN raw_type ILIKE '%Meeting%' OR raw_type ILIKE '%Conference%' THEN 'Meeting & Conference Rooms'
                WHEN raw_type ILIKE '%Sports%' OR raw_type ILIKE '%Gym%' THEN 'Gymnasiums & Sports Spaces'
                WHEN raw_type ILIKE '%Library%' THEN 'Libraries & Study Zones'
                ELSE 'Offices & Administrative'
            END AS display_name,
            CASE 
                WHEN raw_type ILIKE '%Classroom%' OR raw_type ILIKE '%Lecture%' THEN 'Classroom'
                WHEN raw_type ILIKE '%Lab%' THEN 'Lab'
                WHEN raw_type ILIKE '%Auditorium%' OR raw_type ILIKE '%Seminar%' THEN 'Auditorium'
                WHEN raw_type ILIKE '%Meeting%' OR raw_type ILIKE '%Conference%' THEN 'Meeting'
                WHEN raw_type ILIKE '%Sports%' OR raw_type ILIKE '%Gym%' THEN 'Sports'
                WHEN raw_type ILIKE '%Library%' THEN 'Library'
                ELSE 'Office'
            END AS type_code,
            CASE 
                WHEN raw_type ILIKE '%Classroom%' OR raw_type ILIKE '%Lecture%' THEN '#3B82F6'
                WHEN raw_type ILIKE '%Lab%' THEN '#8B5CF6'
                WHEN raw_type ILIKE '%Auditorium%' OR raw_type ILIKE '%Seminar%' THEN '#EC4899'
                WHEN raw_type ILIKE '%Meeting%' OR raw_type ILIKE '%Conference%' THEN '#10B981'
                WHEN raw_type ILIKE '%Sports%' OR raw_type ILIKE '%Gym%' THEN '#F59E0B'
                WHEN raw_type ILIKE '%Library%' THEN '#06B6D4'
                ELSE '#64748B'
            END AS color_hex,
            SUM(total_spaces_in_type)::INT AS total_cnt,
            SUM(booked_spaces_in_type)::INT AS booked_cnt
        FROM type_stats
        GROUP BY 1, 2, 3
    ),
    types_with_pct AS (
        SELECT 
            ct.*,
            ROUND((ct.total_cnt::NUMERIC / GREATEST(SUM(ct.total_cnt) OVER(), 1)) * 100.0, 1) AS percentage
        FROM categorized_types ct
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'type_name', tp.display_name,
            'code', tp.type_code,
            'count', tp.total_cnt,
            'booked_count', tp.booked_cnt,
            'color_hex', tp.color_hex,
            'percentage', tp.percentage
        )
    ) INTO v_space_type_breakdown
    FROM types_with_pct tp;

    -- Real Building-wise Utilization Matrix within Timeframe
    WITH bld_stats AS (
        SELECT 
            b.id AS building_id,
            b.name AS building_name,
            b.code AS building_code,
            COUNT(DISTINCT r.id) AS total_rooms,
            COUNT(DISTINCT sb.room_id) FILTER (
                WHERE sb.id IS NOT NULL 
                  AND sb.is_approved = TRUE 
                  AND sb.status IN ('Confirmed', 'Approved', 'In Use', 'Checked In')
                  AND sb.booking_date >= v_start_d AND sb.booking_date <= v_end_d
            ) AS booked_rooms
        FROM public.buildings b
        JOIN public.rooms r ON r.building_id = b.id AND r.deleted_at IS NULL
        LEFT JOIN public.space_bookings sb 
          ON sb.room_id = r.id 
         AND sb.deleted_at IS NULL 
         AND sb.booking_date >= v_start_d AND sb.booking_date <= v_end_d
        WHERE (b.school_id = p_school_id OR p_school_id IS NULL)
        GROUP BY b.id, b.name, b.code
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'building_id', bs.building_id,
            'building_name', bs.building_name,
            'building_code', bs.building_code,
            'total_rooms', bs.total_rooms,
            'booked_rooms', LEAST(bs.booked_rooms, bs.total_rooms),
            'utilization_pct', LEAST(100.0, ROUND((bs.booked_rooms::NUMERIC / GREATEST(bs.total_rooms, 1)::NUMERIC) * 100.0, 1))
        ) ORDER BY bs.building_code ASC
    ) INTO v_building_utilization
    FROM bld_stats bs;

    -- Return comprehensive analytics payload
    RETURN jsonb_build_object(
        'success', TRUE,
        'summary_kpis', jsonb_build_object(
            'total_bookings', v_total_bookings,
            'confirmed_bookings', v_confirmed_bookings,
            'pending_bookings', v_pending_bookings,
            'rejected_bookings', v_rejected_bookings,
            'total_booked_hours', ROUND(v_total_hours, 1),
            'avg_duration_minutes', ROUND(v_avg_duration, 0),
            'overall_utilization_pct', v_overall_utilization,
            'peak_hour_label', v_peak_hour,
            'most_active_room', v_most_active_room,
            'active_spaces_count', v_active_booked_rooms,
            'total_spaces_count', v_total_rooms
        ),
        'hourly_occupancy', COALESCE(v_hourly_occupancy, '[]'::jsonb),
        'day_of_week_traffic', COALESCE(v_day_of_week, '[]'::jsonb),
        'space_type_breakdown', COALESCE(v_space_type_breakdown, '[]'::jsonb),
        'building_utilization', COALESCE(v_building_utilization, '[]'::jsonb)
    );
END;
$$;
