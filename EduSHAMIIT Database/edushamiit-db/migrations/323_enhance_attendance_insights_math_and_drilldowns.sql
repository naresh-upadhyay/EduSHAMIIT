-- ============================================================================
-- Migration: 323_enhance_attendance_insights_math_and_drilldowns.sql
-- Description:
--   Comprehensive Attendance Insights & Analytics Engine.
--   Provides 100% mathematically calculated metrics:
--   1. Dynamic departments list sourced from public.lookup_values ('DEPARTMENT').
--   2. Dynamic roles list sourced from public.app_roles and public.profiles.
--   3. Subject-level scoping (p_subject_id) linking to attendance_period_records.
--   4. Rigorous KPI calculations with real delta comparisons vs previous period.
--   5. Real daily, weekly, and monthly trend series aggregated across actual records.
--   6. Live distribution donut breakdown (Present, Late, Half Day, Absent, On Leave).
--   7. Actual day-of-week averages (Sunday to Saturday).
--   8. Real top classes rankings without Cartesian join inflation.
--   9. Real top absentees / chronic absenteeism watchlist with true trailing consecutive absences.
--   10. Real department-wise staff attendance breakdown.
--   11. Actionable alerts generated from mathematical thresholds.
--   12. Complete Student/Employee profile drilldown with calendar records for heatmap.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_get_attendance_insights(
    p_school_id UUID,
    p_start_date DATE,
    p_end_date DATE,
    p_view_by VARCHAR DEFAULT 'OVERALL',
    p_role VARCHAR DEFAULT NULL,
    p_class_id UUID DEFAULT NULL,
    p_section_id UUID DEFAULT NULL,
    p_department VARCHAR DEFAULT NULL,
    p_subject_id UUID DEFAULT NULL,
    p_granularity VARCHAR DEFAULT 'monthly'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_s_date DATE;
    v_e_date DATE;
    v_period_days INT;
    v_prev_s_date DATE;
    v_prev_e_date DATE;
    v_view_by VARCHAR;
    v_granularity VARCHAR;
    v_dept VARCHAR;
    v_role VARCHAR;

    -- KPI counts
    v_tot_cur BIGINT := 0;
    v_pres_cur BIGINT := 0;
    v_abs_cur BIGINT := 0;
    v_late_cur BIGINT := 0;
    v_half_cur BIGINT := 0;
    v_leave_cur BIGINT := 0;

    v_tot_prev BIGINT := 0;
    v_pres_prev BIGINT := 0;
    v_abs_prev BIGINT := 0;
    v_late_prev BIGINT := 0;
    v_half_prev BIGINT := 0;
    v_leave_prev BIGINT := 0;

    v_cur_att_pct NUMERIC := 0.0;
    v_prev_att_pct NUMERIC := 0.0;
    v_overall_delta NUMERIC := 0.0;

    -- JSON return structures
    v_kpis JSONB;
    v_trend JSONB := '[]'::JSONB;
    v_distribution JSONB;
    v_top_classes JSONB := '[]'::JSONB;
    v_top_absentees JSONB := '[]'::JSONB;
    v_day_of_week JSONB := '[]'::JSONB;
    v_department_stats JSONB := '[]'::JSONB;
    v_available_depts JSONB := '[]'::JSONB;
    v_available_roles JSONB := '[]'::JSONB;
    v_alerts JSONB := '[]'::JSONB;

    v_spark_overall JSONB := '[]'::JSONB;
    v_spark_present JSONB := '[]'::JSONB;
    v_spark_absent JSONB := '[]'::JSONB;
    v_spark_late JSONB := '[]'::JSONB;
    v_spark_half JSONB := '[]'::JSONB;

    v_high_perf_classes INT := 0;
    v_low_perf_classes INT := 0;
    v_late_delta BIGINT := 0;
    v_late_delta_pct NUMERIC := 0.0;
BEGIN
    -- 1. Normalize dates and bounds
    v_e_date := COALESCE(p_end_date, CURRENT_DATE);
    v_s_date := COALESCE(p_start_date, v_e_date - INTERVAL '30 days')::DATE;
    IF v_s_date > v_e_date THEN
        v_s_date := p_end_date;
        v_e_date := p_start_date;
    END IF;

    v_period_days := GREATEST((v_e_date - v_s_date) + 1, 1);
    v_prev_e_date := v_s_date - INTERVAL '1 day';
    v_prev_s_date := v_prev_e_date - (v_period_days - 1);

    v_view_by := UPPER(COALESCE(NULLIF(TRIM(p_view_by), ''), 'OVERALL'));
    v_granularity := LOWER(COALESCE(NULLIF(TRIM(p_granularity), ''), 'monthly'));
    v_dept := NULLIF(TRIM(p_department), '');
    IF v_dept = 'ALL' OR v_dept = 'All Departments' THEN
        v_dept := NULL;
    END IF;
    v_role := NULLIF(TRIM(p_role), '');
    IF v_role = 'ALL' OR v_role = 'Overall' THEN
        v_role := NULL;
    END IF;

    -- 2. Fetch Available Departments from lookup_values
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'code', lv.value_code,
                'name', lv.value_name,
                'sort_order', lv.sort_order
            ) ORDER BY lv.sort_order ASC, lv.value_name ASC
        ),
        '[]'::JSONB
    )
    INTO v_available_depts
    FROM public.lookup_values lv
    JOIN public.lookup_keys lk ON lk.id = lv.lookup_key_id
    WHERE lk.school_id = p_school_id
      AND lk.key_code = 'DEPARTMENT'
      AND lv.status = 'ACTIVE'
      AND lv.deleted_at IS NULL;

    IF jsonb_array_length(v_available_depts) = 0 THEN
        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'code', lv.value_code,
                    'name', lv.value_name,
                    'sort_order', lv.sort_order
                ) ORDER BY lv.sort_order ASC, lv.value_name ASC
            ),
            '[]'::JSONB
        )
        INTO v_available_depts
        FROM public.lookup_values lv
        JOIN public.lookup_keys lk ON lk.id = lv.lookup_key_id
        WHERE lk.key_code = 'DEPARTMENT'
          AND lv.status = 'ACTIVE'
          AND lv.deleted_at IS NULL;
    END IF;

    -- 3. Fetch Available Roles from app_roles & profiles
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'code', r.role_code,
                'name', r.role_name,
                'display_name', r.role_display
            ) ORDER BY r.role_display ASC
        ),
        '[]'::JSONB
    )
    INTO v_available_roles
    FROM (
        SELECT DISTINCT
            COALESCE(ar.code, UPPER(p.role)) AS role_code,
            p.role AS role_name,
            COALESCE(ar.display_name, INITCAP(REPLACE(p.role, '_', ' '))) AS role_display
        FROM public.profiles p
        LEFT JOIN public.app_roles ar ON ar.name = p.role
        WHERE p.school_id = p_school_id
          AND p.role IS NOT NULL
          AND p.role != ''
          AND (p.status IS NULL OR p.status != 'Deleted')
    ) r;

    -- 4. Calculate Current & Previous Period KPIs
    -- 4A. Student Records (Current & Previous)
    IF v_view_by IN ('OVERALL', 'STUDENTS') AND (v_role IS NULL OR LOWER(v_role) = 'student') AND v_dept IS NULL THEN
        IF p_subject_id IS NOT NULL THEN
            -- Subject-specific period records
            SELECT 
                COUNT(*),
                COUNT(CASE WHEN UPPER(a.status) = 'PRESENT' THEN 1 END),
                COUNT(CASE WHEN UPPER(a.status) = 'ABSENT' THEN 1 END),
                COUNT(CASE WHEN UPPER(a.status) = 'LATE' THEN 1 END),
                COUNT(CASE WHEN UPPER(a.status) = 'HALF_DAY' THEN 1 END),
                COUNT(CASE WHEN UPPER(a.status) = 'ON_LEAVE' THEN 1 END)
            INTO 
                v_tot_cur, v_pres_cur, v_abs_cur, v_late_cur, v_half_cur, v_leave_cur
            FROM public.attendance_period_records a
            WHERE a.school_id = p_school_id
              AND a.attendance_date BETWEEN v_s_date AND v_e_date
              AND a.subject_id = p_subject_id
              AND (p_class_id IS NULL OR a.class_id = p_class_id)
              AND (p_section_id IS NULL OR a.section_id = p_section_id);

            SELECT 
                COUNT(*),
                COUNT(CASE WHEN UPPER(a.status) = 'PRESENT' THEN 1 END),
                COUNT(CASE WHEN UPPER(a.status) = 'ABSENT' THEN 1 END),
                COUNT(CASE WHEN UPPER(a.status) = 'LATE' THEN 1 END),
                COUNT(CASE WHEN UPPER(a.status) = 'HALF_DAY' THEN 1 END),
                COUNT(CASE WHEN UPPER(a.status) = 'ON_LEAVE' THEN 1 END)
            INTO 
                v_tot_prev, v_pres_prev, v_abs_prev, v_late_prev, v_half_prev, v_leave_prev
            FROM public.attendance_period_records a
            WHERE a.school_id = p_school_id
              AND a.attendance_date BETWEEN v_prev_s_date AND v_prev_e_date
              AND a.subject_id = p_subject_id
              AND (p_class_id IS NULL OR a.class_id = p_class_id)
              AND (p_section_id IS NULL OR a.section_id = p_section_id);
        ELSE
            -- Daily master records
            SELECT 
                COUNT(*),
                COUNT(CASE WHEN UPPER(a.status) = 'PRESENT' THEN 1 END),
                COUNT(CASE WHEN UPPER(a.status) = 'ABSENT' THEN 1 END),
                COUNT(CASE WHEN UPPER(a.status) = 'LATE' THEN 1 END),
                COUNT(CASE WHEN UPPER(a.status) = 'HALF_DAY' THEN 1 END),
                COUNT(CASE WHEN UPPER(a.status) = 'ON_LEAVE' THEN 1 END)
            INTO 
                v_tot_cur, v_pres_cur, v_abs_cur, v_late_cur, v_half_cur, v_leave_cur
            FROM public.attendance_daily_records a
            WHERE a.school_id = p_school_id
              AND a.attendance_date BETWEEN v_s_date AND v_e_date
              AND (p_class_id IS NULL OR a.class_id = p_class_id)
              AND (p_section_id IS NULL OR a.section_id = p_section_id);

            SELECT 
                COUNT(*),
                COUNT(CASE WHEN UPPER(a.status) = 'PRESENT' THEN 1 END),
                COUNT(CASE WHEN UPPER(a.status) = 'ABSENT' THEN 1 END),
                COUNT(CASE WHEN UPPER(a.status) = 'LATE' THEN 1 END),
                COUNT(CASE WHEN UPPER(a.status) = 'HALF_DAY' THEN 1 END),
                COUNT(CASE WHEN UPPER(a.status) = 'ON_LEAVE' THEN 1 END)
            INTO 
                v_tot_prev, v_pres_prev, v_abs_prev, v_late_prev, v_half_prev, v_leave_prev
            FROM public.attendance_daily_records a
            WHERE a.school_id = p_school_id
              AND a.attendance_date BETWEEN v_prev_s_date AND v_prev_e_date
              AND (p_class_id IS NULL OR a.class_id = p_class_id)
              AND (p_section_id IS NULL OR a.section_id = p_section_id);
        END IF;
    END IF;

    -- 4B. Staff Records (Current & Previous)
    IF (v_view_by IN ('OVERALL', 'STAFF') OR (v_role IS NOT NULL AND LOWER(v_role) != 'student')) AND p_class_id IS NULL AND p_section_id IS NULL AND p_subject_id IS NULL THEN
        SELECT 
            COALESCE(v_tot_cur, 0) + COUNT(a.id),
            COALESCE(v_pres_cur, 0) + COUNT(CASE WHEN UPPER(a.status) = 'PRESENT' THEN 1 END),
            COALESCE(v_abs_cur, 0) + COUNT(CASE WHEN UPPER(a.status) = 'ABSENT' THEN 1 END),
            COALESCE(v_late_cur, 0) + COUNT(CASE WHEN UPPER(a.status) = 'LATE' THEN 1 END),
            COALESCE(v_half_cur, 0) + COUNT(CASE WHEN UPPER(a.status) = 'HALF_DAY' THEN 1 END),
            COALESCE(v_leave_cur, 0) + COUNT(CASE WHEN UPPER(a.status) IN ('ON_LEAVE', 'WORK_FROM_HOME') THEN 1 END)
        INTO 
            v_tot_cur, v_pres_cur, v_abs_cur, v_late_cur, v_half_cur, v_leave_cur
        FROM public.attendance_staff_records a
        JOIN public.profiles p ON p.id = a.employee_id
        WHERE a.school_id = p_school_id
          AND a.attendance_date BETWEEN v_s_date AND v_e_date
          AND (v_dept IS NULL OR p.department ILIKE v_dept OR p.department ILIKE '%' || v_dept || '%')
          AND (v_role IS NULL OR LOWER(p.role) = LOWER(v_role) OR UPPER(p.role) = UPPER(v_role));

        SELECT 
            COALESCE(v_tot_prev, 0) + COUNT(a.id),
            COALESCE(v_pres_prev, 0) + COUNT(CASE WHEN UPPER(a.status) = 'PRESENT' THEN 1 END),
            COALESCE(v_abs_prev, 0) + COUNT(CASE WHEN UPPER(a.status) = 'ABSENT' THEN 1 END),
            COALESCE(v_late_prev, 0) + COUNT(CASE WHEN UPPER(a.status) = 'LATE' THEN 1 END),
            COALESCE(v_half_prev, 0) + COUNT(CASE WHEN UPPER(a.status) = 'HALF_DAY' THEN 1 END),
            COALESCE(v_leave_prev, 0) + COUNT(CASE WHEN UPPER(a.status) IN ('ON_LEAVE', 'WORK_FROM_HOME') THEN 1 END)
        INTO 
            v_tot_prev, v_pres_prev, v_abs_prev, v_late_prev, v_half_prev, v_leave_prev
        FROM public.attendance_staff_records a
        JOIN public.profiles p ON p.id = a.employee_id
        WHERE a.school_id = p_school_id
          AND a.attendance_date BETWEEN v_prev_s_date AND v_prev_e_date
          AND (v_dept IS NULL OR p.department ILIKE v_dept OR p.department ILIKE '%' || v_dept || '%')
          AND (v_role IS NULL OR LOWER(p.role) = LOWER(v_role) OR UPPER(p.role) = UPPER(v_role));
    END IF;

    -- Compute overall attendance percentage and deltas
    IF v_tot_cur > 0 THEN
        v_cur_att_pct := ROUND(((v_pres_cur + v_late_cur + (v_half_cur * 0.5))::NUMERIC / v_tot_cur::NUMERIC) * 100.0, 2);
    ELSE
        v_cur_att_pct := 0.0;
    END IF;

    IF v_tot_prev > 0 THEN
        v_prev_att_pct := ROUND(((v_pres_prev + v_late_prev + (v_half_prev * 0.5))::NUMERIC / v_tot_prev::NUMERIC) * 100.0, 2);
    ELSE
        v_prev_att_pct := 0.0;
    END IF;

    v_overall_delta := ROUND(v_cur_att_pct - v_prev_att_pct, 2);

    -- 5. Real 7-Bucket Sparkline Generation
    WITH interval_buckets AS (
        SELECT 
            b.bucket_idx,
            b.bucket_start,
            b.bucket_end
        FROM (
            SELECT 
                i AS bucket_idx,
                (v_s_date + (i * ((v_period_days::FLOAT) / 7.0))::INT)::DATE AS bucket_start,
                (v_s_date + ((i + 1) * ((v_period_days::FLOAT) / 7.0))::INT - 1)::DATE AS bucket_end
            FROM generate_series(0, 6) AS i
        ) b
    ),
    bucket_stats AS (
        SELECT 
            ib.bucket_idx,
            COUNT(rec.id) AS tot,
            COUNT(CASE WHEN UPPER(rec.status) = 'PRESENT' THEN 1 END) AS pres,
            COUNT(CASE WHEN UPPER(rec.status) = 'ABSENT' THEN 1 END) AS ab,
            COUNT(CASE WHEN UPPER(rec.status) = 'LATE' THEN 1 END) AS lt,
            COUNT(CASE WHEN UPPER(rec.status) = 'HALF_DAY' THEN 1 END) AS hd
        FROM interval_buckets ib
        LEFT JOIN (
            SELECT a.id, a.attendance_date, a.status
            FROM public.attendance_daily_records a
            WHERE a.school_id = p_school_id
              AND a.attendance_date BETWEEN v_s_date AND v_e_date
              AND (p_class_id IS NULL OR a.class_id = p_class_id)
              AND (p_section_id IS NULL OR a.section_id = p_section_id)
              AND (v_view_by IN ('OVERALL', 'STUDENTS'))
              AND p_subject_id IS NULL
            UNION ALL
            SELECT a.id, a.attendance_date, a.status
            FROM public.attendance_period_records a
            WHERE a.school_id = p_school_id
              AND a.attendance_date BETWEEN v_s_date AND v_e_date
              AND (p_class_id IS NULL OR a.class_id = p_class_id)
              AND (p_section_id IS NULL OR a.section_id = p_section_id)
              AND a.subject_id = p_subject_id
              AND (v_view_by IN ('OVERALL', 'STUDENTS'))
            UNION ALL
            SELECT a.id, a.attendance_date, a.status
            FROM public.attendance_staff_records a
            JOIN public.profiles p ON p.id = a.employee_id
            WHERE a.school_id = p_school_id
              AND a.attendance_date BETWEEN v_s_date AND v_e_date
              AND (v_dept IS NULL OR p.department ILIKE v_dept)
              AND (v_role IS NULL OR LOWER(p.role) = LOWER(v_role))
              AND (v_view_by IN ('OVERALL', 'STAFF') OR v_role IS NOT NULL)
              AND p_class_id IS NULL
              AND p_subject_id IS NULL
        ) rec ON rec.attendance_date BETWEEN ib.bucket_start AND ib.bucket_end
        GROUP BY ib.bucket_idx
        ORDER BY ib.bucket_idx ASC
    )
    SELECT 
        jsonb_agg(CASE WHEN tot > 0 THEN ROUND(((pres + lt + (hd * 0.5))::NUMERIC / tot::NUMERIC) * 100.0, 2) ELSE 0.0 END),
        jsonb_agg(pres),
        jsonb_agg(ab),
        jsonb_agg(lt),
        jsonb_agg(hd)
    INTO 
        v_spark_overall, v_spark_present, v_spark_absent, v_spark_late, v_spark_half
    FROM bucket_stats;

    v_spark_overall := COALESCE(v_spark_overall, '[]'::JSONB);
    v_spark_present := COALESCE(v_spark_present, '[]'::JSONB);
    v_spark_absent := COALESCE(v_spark_absent, '[]'::JSONB);
    v_spark_late := COALESCE(v_spark_late, '[]'::JSONB);
    v_spark_half := COALESCE(v_spark_half, '[]'::JSONB);

    -- Build KPIs JSON
    v_kpis := jsonb_build_object(
        'overall', jsonb_build_object(
            'value', v_cur_att_pct,
            'formatted', TO_CHAR(v_cur_att_pct, 'FM990.00') || '%',
            'delta_pct', v_overall_delta,
            'is_positive', (v_overall_delta >= 0),
            'label', 'vs previous period',
            'sparkline', v_spark_overall
        ),
        'present', jsonb_build_object(
            'value', v_pres_cur,
            'formatted', TO_CHAR(v_pres_cur, 'FM999,999,999'),
            'delta_count', (v_pres_cur - v_pres_prev),
            'is_positive', ((v_pres_cur - v_pres_prev) >= 0),
            'sparkline', v_spark_present
        ),
        'absent', jsonb_build_object(
            'value', v_abs_cur,
            'formatted', TO_CHAR(v_abs_cur, 'FM999,999,999'),
            'delta_count', (v_abs_cur - v_abs_prev),
            'is_positive', ((v_abs_cur - v_abs_prev) <= 0),
            'sparkline', v_spark_absent
        ),
        'late', jsonb_build_object(
            'value', v_late_cur,
            'formatted', TO_CHAR(v_late_cur, 'FM999,999,999'),
            'delta_count', (v_late_cur - v_late_prev),
            'is_positive', ((v_late_cur - v_late_prev) <= 0),
            'sparkline', v_spark_late
        ),
        'half_day', jsonb_build_object(
            'value', v_half_cur,
            'formatted', TO_CHAR(v_half_cur, 'FM999,999,999'),
            'delta_count', (v_half_cur - v_half_prev),
            'is_positive', ((v_half_cur - v_half_prev) <= 0),
            'sparkline', v_spark_half
        )
    );

    -- 6. Real Attendance Trend Series (Daily, Weekly, Monthly)
    IF v_granularity = 'daily' THEN
        WITH trend_raw AS (
            SELECT 
                d.dt::DATE AS point_date,
                TO_CHAR(d.dt, 'DD Mon') AS label,
                COUNT(rec.id) AS total,
                COUNT(CASE WHEN UPPER(rec.status) = 'PRESENT' THEN 1 END) AS present_count,
                COUNT(CASE WHEN UPPER(rec.status) = 'ABSENT' THEN 1 END) AS absent_count,
                COUNT(CASE WHEN UPPER(rec.status) = 'LATE' THEN 1 END) AS late_count,
                COUNT(CASE WHEN UPPER(rec.status) = 'HALF_DAY' THEN 1 END) AS half_day_count,
                COUNT(CASE WHEN UPPER(rec.status) IN ('ON_LEAVE', 'WORK_FROM_HOME') THEN 1 END) AS leave_count
            FROM generate_series(v_s_date, v_e_date, INTERVAL '1 day') AS d(dt)
            LEFT JOIN (
                SELECT a.id, a.attendance_date, a.status FROM public.attendance_daily_records a
                WHERE a.school_id = p_school_id AND a.attendance_date BETWEEN v_s_date AND v_e_date
                  AND (p_class_id IS NULL OR a.class_id = p_class_id)
                  AND (p_section_id IS NULL OR a.section_id = p_section_id)
                  AND (v_view_by IN ('OVERALL', 'STUDENTS'))
                  AND p_subject_id IS NULL
                UNION ALL
                SELECT a.id, a.attendance_date, a.status FROM public.attendance_period_records a
                WHERE a.school_id = p_school_id AND a.attendance_date BETWEEN v_s_date AND v_e_date
                  AND (p_class_id IS NULL OR a.class_id = p_class_id)
                  AND (p_section_id IS NULL OR a.section_id = p_section_id)
                  AND a.subject_id = p_subject_id
                  AND (v_view_by IN ('OVERALL', 'STUDENTS'))
                UNION ALL
                SELECT a.id, a.attendance_date, a.status FROM public.attendance_staff_records a
                JOIN public.profiles p ON p.id = a.employee_id
                WHERE a.school_id = p_school_id AND a.attendance_date BETWEEN v_s_date AND v_e_date
                  AND (v_dept IS NULL OR p.department ILIKE v_dept)
                  AND (v_role IS NULL OR LOWER(p.role) = LOWER(v_role))
                  AND (v_view_by IN ('OVERALL', 'STAFF') OR v_role IS NOT NULL)
                  AND p_class_id IS NULL
                  AND p_subject_id IS NULL
            ) rec ON rec.attendance_date = d.dt::DATE
            GROUP BY d.dt
            ORDER BY d.dt ASC
        )
        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'label', tr.label,
                    'date', tr.point_date,
                    'total', tr.total,
                    'present_count', tr.present_count,
                    'absent_count', tr.absent_count,
                    'late_count', tr.late_count,
                    'half_day_count', tr.half_day_count,
                    'leave_count', tr.leave_count,
                    'attendance_pct', CASE 
                        WHEN tr.total > 0 THEN 
                            ROUND(((tr.present_count + tr.late_count + (tr.half_day_count * 0.5))::NUMERIC / tr.total::NUMERIC) * 100.0, 2)
                        ELSE 0.0 
                    END,
                    'present_pct', CASE WHEN tr.total > 0 THEN ROUND((tr.present_count::NUMERIC / tr.total::NUMERIC) * 100.0, 2) ELSE 0.0 END,
                    'absent_pct', CASE WHEN tr.total > 0 THEN ROUND((tr.absent_count::NUMERIC / tr.total::NUMERIC) * 100.0, 2) ELSE 0.0 END,
                    'late_pct', CASE WHEN tr.total > 0 THEN ROUND((tr.late_count::NUMERIC / tr.total::NUMERIC) * 100.0, 2) ELSE 0.0 END,
                    'leave_pct', CASE WHEN tr.total > 0 THEN ROUND((tr.leave_count::NUMERIC / tr.total::NUMERIC) * 100.0, 2) ELSE 0.0 END
                )
            ),
            '[]'::JSONB
        )
        INTO v_trend
        FROM trend_raw tr;

    ELSIF v_granularity = 'weekly' THEN
        WITH trend_raw AS (
            SELECT 
                DATE_TRUNC('week', d.dt)::DATE AS point_date,
                'Wk ' || TO_CHAR(DATE_TRUNC('week', d.dt), 'DD Mon') AS label,
                COUNT(rec.id) AS total,
                COUNT(CASE WHEN UPPER(rec.status) = 'PRESENT' THEN 1 END) AS present_count,
                COUNT(CASE WHEN UPPER(rec.status) = 'ABSENT' THEN 1 END) AS absent_count,
                COUNT(CASE WHEN UPPER(rec.status) = 'LATE' THEN 1 END) AS late_count,
                COUNT(CASE WHEN UPPER(rec.status) = 'HALF_DAY' THEN 1 END) AS half_day_count,
                COUNT(CASE WHEN UPPER(rec.status) IN ('ON_LEAVE', 'WORK_FROM_HOME') THEN 1 END) AS leave_count
            FROM generate_series(v_s_date, v_e_date, INTERVAL '1 week') AS d(dt)
            LEFT JOIN (
                SELECT a.id, a.attendance_date, a.status FROM public.attendance_daily_records a
                WHERE a.school_id = p_school_id AND a.attendance_date BETWEEN v_s_date AND v_e_date
                  AND (p_class_id IS NULL OR a.class_id = p_class_id)
                  AND (p_section_id IS NULL OR a.section_id = p_section_id)
                  AND (v_view_by IN ('OVERALL', 'STUDENTS'))
                  AND p_subject_id IS NULL
                UNION ALL
                SELECT a.id, a.attendance_date, a.status FROM public.attendance_period_records a
                WHERE a.school_id = p_school_id AND a.attendance_date BETWEEN v_s_date AND v_e_date
                  AND (p_class_id IS NULL OR a.class_id = p_class_id)
                  AND (p_section_id IS NULL OR a.section_id = p_section_id)
                  AND a.subject_id = p_subject_id
                  AND (v_view_by IN ('OVERALL', 'STUDENTS'))
                UNION ALL
                SELECT a.id, a.attendance_date, a.status FROM public.attendance_staff_records a
                JOIN public.profiles p ON p.id = a.employee_id
                WHERE a.school_id = p_school_id AND a.attendance_date BETWEEN v_s_date AND v_e_date
                  AND (v_dept IS NULL OR p.department ILIKE v_dept)
                  AND (v_role IS NULL OR LOWER(p.role) = LOWER(v_role))
                  AND (v_view_by IN ('OVERALL', 'STAFF') OR v_role IS NOT NULL)
                  AND p_class_id IS NULL
                  AND p_subject_id IS NULL
            ) rec ON rec.attendance_date >= DATE_TRUNC('week', d.dt)::DATE AND rec.attendance_date < (DATE_TRUNC('week', d.dt) + INTERVAL '1 week')::DATE
            GROUP BY DATE_TRUNC('week', d.dt)
            ORDER BY DATE_TRUNC('week', d.dt) ASC
        )
        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'label', tr.label,
                    'date', tr.point_date,
                    'total', tr.total,
                    'present_count', tr.present_count,
                    'absent_count', tr.absent_count,
                    'late_count', tr.late_count,
                    'half_day_count', tr.half_day_count,
                    'leave_count', tr.leave_count,
                    'attendance_pct', CASE 
                        WHEN tr.total > 0 THEN 
                            ROUND(((tr.present_count + tr.late_count + (tr.half_day_count * 0.5))::NUMERIC / tr.total::NUMERIC) * 100.0, 2)
                        ELSE 0.0 
                    END,
                    'present_pct', CASE WHEN tr.total > 0 THEN ROUND((tr.present_count::NUMERIC / tr.total::NUMERIC) * 100.0, 2) ELSE 0.0 END,
                    'absent_pct', CASE WHEN tr.total > 0 THEN ROUND((tr.absent_count::NUMERIC / tr.total::NUMERIC) * 100.0, 2) ELSE 0.0 END,
                    'late_pct', CASE WHEN tr.total > 0 THEN ROUND((tr.late_count::NUMERIC / tr.total::NUMERIC) * 100.0, 2) ELSE 0.0 END,
                    'leave_pct', CASE WHEN tr.total > 0 THEN ROUND((tr.leave_count::NUMERIC / tr.total::NUMERIC) * 100.0, 2) ELSE 0.0 END
                )
            ),
            '[]'::JSONB
        )
        INTO v_trend
        FROM trend_raw tr;

    ELSE -- monthly
        WITH trend_raw AS (
            SELECT 
                DATE_TRUNC('month', d.dt)::DATE AS point_date,
                TO_CHAR(DATE_TRUNC('month', d.dt), 'Mon YYYY') AS label,
                COUNT(rec.id) AS total,
                COUNT(CASE WHEN UPPER(rec.status) = 'PRESENT' THEN 1 END) AS present_count,
                COUNT(CASE WHEN UPPER(rec.status) = 'ABSENT' THEN 1 END) AS absent_count,
                COUNT(CASE WHEN UPPER(rec.status) = 'LATE' THEN 1 END) AS late_count,
                COUNT(CASE WHEN UPPER(rec.status) = 'HALF_DAY' THEN 1 END) AS half_day_count,
                COUNT(CASE WHEN UPPER(rec.status) IN ('ON_LEAVE', 'WORK_FROM_HOME') THEN 1 END) AS leave_count
            FROM generate_series(DATE_TRUNC('month', v_s_date), DATE_TRUNC('month', v_e_date), INTERVAL '1 month') AS d(dt)
            LEFT JOIN (
                SELECT a.id, a.attendance_date, a.status FROM public.attendance_daily_records a
                WHERE a.school_id = p_school_id AND a.attendance_date BETWEEN v_s_date AND v_e_date
                  AND (p_class_id IS NULL OR a.class_id = p_class_id)
                  AND (p_section_id IS NULL OR a.section_id = p_section_id)
                  AND (v_view_by IN ('OVERALL', 'STUDENTS'))
                  AND p_subject_id IS NULL
                UNION ALL
                SELECT a.id, a.attendance_date, a.status FROM public.attendance_period_records a
                WHERE a.school_id = p_school_id AND a.attendance_date BETWEEN v_s_date AND v_e_date
                  AND (p_class_id IS NULL OR a.class_id = p_class_id)
                  AND (p_section_id IS NULL OR a.section_id = p_section_id)
                  AND a.subject_id = p_subject_id
                  AND (v_view_by IN ('OVERALL', 'STUDENTS'))
                UNION ALL
                SELECT a.id, a.attendance_date, a.status FROM public.attendance_staff_records a
                JOIN public.profiles p ON p.id = a.employee_id
                WHERE a.school_id = p_school_id AND a.attendance_date BETWEEN v_s_date AND v_e_date
                  AND (v_dept IS NULL OR p.department ILIKE v_dept)
                  AND (v_role IS NULL OR LOWER(p.role) = LOWER(v_role))
                  AND (v_view_by IN ('OVERALL', 'STAFF') OR v_role IS NOT NULL)
                  AND p_class_id IS NULL
                  AND p_subject_id IS NULL
            ) rec ON rec.attendance_date >= DATE_TRUNC('month', d.dt)::DATE AND rec.attendance_date < (DATE_TRUNC('month', d.dt) + INTERVAL '1 month')::DATE
            GROUP BY DATE_TRUNC('month', d.dt)
            ORDER BY DATE_TRUNC('month', d.dt) ASC
        )
        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'label', tr.label,
                    'date', tr.point_date,
                    'total', tr.total,
                    'present_count', tr.present_count,
                    'absent_count', tr.absent_count,
                    'late_count', tr.late_count,
                    'half_day_count', tr.half_day_count,
                    'leave_count', tr.leave_count,
                    'attendance_pct', CASE 
                        WHEN tr.total > 0 THEN 
                            ROUND(((tr.present_count + tr.late_count + (tr.half_day_count * 0.5))::NUMERIC / tr.total::NUMERIC) * 100.0, 2)
                        ELSE 0.0 
                    END,
                    'present_pct', CASE WHEN tr.total > 0 THEN ROUND((tr.present_count::NUMERIC / tr.total::NUMERIC) * 100.0, 2) ELSE 0.0 END,
                    'absent_pct', CASE WHEN tr.total > 0 THEN ROUND((tr.absent_count::NUMERIC / tr.total::NUMERIC) * 100.0, 2) ELSE 0.0 END,
                    'late_pct', CASE WHEN tr.total > 0 THEN ROUND((tr.late_count::NUMERIC / tr.total::NUMERIC) * 100.0, 2) ELSE 0.0 END,
                    'leave_pct', CASE WHEN tr.total > 0 THEN ROUND((tr.leave_count::NUMERIC / tr.total::NUMERIC) * 100.0, 2) ELSE 0.0 END
                )
            ),
            '[]'::JSONB
        )
        INTO v_trend
        FROM trend_raw tr;
    END IF;

    -- 7. Live Attendance Distribution Breakdown
    v_distribution := jsonb_build_object(
        'total', v_tot_cur,
        'present_count', v_pres_cur,
        'present_pct', CASE WHEN v_tot_cur > 0 THEN ROUND((v_pres_cur::NUMERIC / v_tot_cur::NUMERIC) * 100.0, 2) ELSE 0.0 END,
        'late_count', v_late_cur,
        'late_pct', CASE WHEN v_tot_cur > 0 THEN ROUND((v_late_cur::NUMERIC / v_tot_cur::NUMERIC) * 100.0, 2) ELSE 0.0 END,
        'half_day_count', v_half_cur,
        'half_day_pct', CASE WHEN v_tot_cur > 0 THEN ROUND((v_half_cur::NUMERIC / v_tot_cur::NUMERIC) * 100.0, 2) ELSE 0.0 END,
        'absent_count', v_abs_cur,
        'absent_pct', CASE WHEN v_tot_cur > 0 THEN ROUND((v_abs_cur::NUMERIC / v_tot_cur::NUMERIC) * 100.0, 2) ELSE 0.0 END,
        'leave_count', v_leave_cur,
        'leave_pct', CASE WHEN v_tot_cur > 0 THEN ROUND((v_leave_cur::NUMERIC / v_tot_cur::NUMERIC) * 100.0, 2) ELSE 0.0 END
    );

    -- 8. Real Top Classes with 100% Mathematically Accurate Rankings & Deltas
    WITH class_students AS (
        SELECT 
            sca.class_id,
            COUNT(DISTINCT sca.student_id) AS total_students
        FROM public.student_class_assignments sca
        WHERE sca.school_id = p_school_id 
          AND sca.status = 'ACTIVE'
        GROUP BY sca.class_id
    ),
    class_attendance_cur AS (
        SELECT 
            a.class_id,
            COUNT(a.id) AS total_records,
            COUNT(CASE WHEN UPPER(a.status) = 'PRESENT' THEN 1 END) AS present_cnt,
            COUNT(CASE WHEN UPPER(a.status) = 'ABSENT' THEN 1 END) AS absent_cnt,
            COUNT(CASE WHEN UPPER(a.status) = 'LATE' THEN 1 END) AS late_cnt,
            COUNT(CASE WHEN UPPER(a.status) = 'HALF_DAY' THEN 1 END) AS half_day_cnt,
            COUNT(CASE WHEN UPPER(a.status) IN ('ON_LEAVE', 'WORK_FROM_HOME') THEN 1 END) AS leave_cnt
        FROM public.attendance_daily_records a
        WHERE a.school_id = p_school_id 
          AND a.attendance_date BETWEEN v_s_date AND v_e_date
          AND p_subject_id IS NULL
        GROUP BY a.class_id
        UNION ALL
        SELECT 
            a.class_id,
            COUNT(a.id) AS total_records,
            COUNT(CASE WHEN UPPER(a.status) = 'PRESENT' THEN 1 END) AS present_cnt,
            COUNT(CASE WHEN UPPER(a.status) = 'ABSENT' THEN 1 END) AS absent_cnt,
            COUNT(CASE WHEN UPPER(a.status) = 'LATE' THEN 1 END) AS late_cnt,
            COUNT(CASE WHEN UPPER(a.status) = 'HALF_DAY' THEN 1 END) AS half_day_cnt,
            COUNT(CASE WHEN UPPER(a.status) IN ('ON_LEAVE', 'WORK_FROM_HOME') THEN 1 END) AS leave_cnt
        FROM public.attendance_period_records a
        WHERE a.school_id = p_school_id 
          AND a.attendance_date BETWEEN v_s_date AND v_e_date
          AND a.subject_id = p_subject_id
        GROUP BY a.class_id
    ),
    class_attendance_prev AS (
        SELECT 
            a.class_id,
            CASE 
                WHEN COUNT(a.id) > 0 THEN 
                    ROUND(((COUNT(CASE WHEN UPPER(a.status) = 'PRESENT' THEN 1 END) + COUNT(CASE WHEN UPPER(a.status) = 'LATE' THEN 1 END) + (COUNT(CASE WHEN UPPER(a.status) = 'HALF_DAY' THEN 1 END) * 0.5))::NUMERIC / COUNT(a.id)::NUMERIC) * 100.0, 2)
                ELSE 0.0
            END AS prev_attendance_pct
        FROM public.attendance_daily_records a
        WHERE a.school_id = p_school_id 
          AND a.attendance_date BETWEEN v_prev_s_date AND v_prev_e_date
          AND p_subject_id IS NULL
        GROUP BY a.class_id
        UNION ALL
        SELECT 
            a.class_id,
            CASE 
                WHEN COUNT(a.id) > 0 THEN 
                    ROUND(((COUNT(CASE WHEN UPPER(a.status) = 'PRESENT' THEN 1 END) + COUNT(CASE WHEN UPPER(a.status) = 'LATE' THEN 1 END) + (COUNT(CASE WHEN UPPER(a.status) = 'HALF_DAY' THEN 1 END) * 0.5))::NUMERIC / COUNT(a.id)::NUMERIC) * 100.0, 2)
                ELSE 0.0
            END AS prev_attendance_pct
        FROM public.attendance_period_records a
        WHERE a.school_id = p_school_id 
          AND a.attendance_date BETWEEN v_prev_s_date AND v_prev_e_date
          AND a.subject_id = p_subject_id
        GROUP BY a.class_id
    ),
    class_ranked AS (
        SELECT 
            ROW_NUMBER() OVER (
                ORDER BY 
                    (CASE WHEN COALESCE(ca.total_records, 0) > 0 THEN ROUND(((ca.present_cnt + ca.late_cnt + (ca.half_day_cnt * 0.5))::NUMERIC / ca.total_records::NUMERIC) * 100.0, 2) ELSE 0.0 END) DESC,
                    COALESCE(cs.total_students, 0) DESC,
                    c.display_order ASC,
                    c.name ASC
            ) AS rank,
            c.id AS class_id,
            c.name AS class_name,
            COALESCE(cs.total_students, 0) AS total_students,
            COALESCE(ca.total_records, 0) AS total_records,
            CASE 
                WHEN COALESCE(ca.total_records, 0) > 0 THEN 
                    ROUND(((ca.present_cnt + ca.late_cnt + (ca.half_day_cnt * 0.5))::NUMERIC / ca.total_records::NUMERIC) * 100.0, 2)
                ELSE 0.0
            END AS attendance_pct,
            COALESCE(ca.present_cnt, 0) AS present_cnt,
            COALESCE(ca.absent_cnt, 0) AS absent_cnt,
            COALESCE(ca.late_cnt, 0) AS late_cnt,
            COALESCE(ca.half_day_cnt, 0) AS half_day_cnt,
            ROUND(
                (CASE WHEN COALESCE(ca.total_records, 0) > 0 THEN ROUND(((ca.present_cnt + ca.late_cnt + (ca.half_day_cnt * 0.5))::NUMERIC / ca.total_records::NUMERIC) * 100.0, 2) ELSE 0.0 END)
                - COALESCE(cp.prev_attendance_pct, 0.0), 
                1
            ) AS trend_delta
        FROM public.academic_classes c
        LEFT JOIN class_students cs ON cs.class_id = c.id
        LEFT JOIN class_attendance_cur ca ON ca.class_id = c.id
        LEFT JOIN class_attendance_prev cp ON cp.class_id = c.id
        WHERE c.school_id = p_school_id 
          AND (c.deleted_at IS NULL OR c.status != 'ARCHIVED')
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'rank', cr.rank,
                'class_id', cr.class_id,
                'class_name', cr.class_name,
                'total_students', cr.total_students,
                'total_records', cr.total_records,
                'attendance_pct', cr.attendance_pct,
                'present', cr.present_cnt,
                'absent', cr.absent_cnt,
                'late', cr.late_cnt,
                'half_day', cr.half_day_cnt,
                'trend_delta', cr.trend_delta
            )
        ),
        '[]'::JSONB
    )
    INTO v_top_classes
    FROM class_ranked cr;

    -- 9. Real Chronic Absentees Watchlist with true consecutive trailing absences
    WITH active_assignments AS (
        SELECT DISTINCT ON (sca.student_id)
            sca.student_id,
            sca.class_id,
            sca.section_id,
            c.name AS class_name,
            s.name AS section_name
        FROM public.student_class_assignments sca
        JOIN public.academic_classes c ON c.id = sca.class_id
        LEFT JOIN public.academic_sections s ON s.id = sca.section_id
        WHERE sca.school_id = p_school_id AND sca.status = 'ACTIVE'
        ORDER BY sca.student_id, sca.assigned_at DESC
    ),
    person_attendance_agg AS (
        SELECT 
            rec.pid,
            COUNT(rec.id) AS total_marked_days,
            COUNT(CASE WHEN UPPER(rec.status) = 'ABSENT' THEN 1 END) AS absent_days,
            COUNT(CASE WHEN UPPER(rec.status) = 'LATE' THEN 1 END) AS late_days,
            COUNT(CASE WHEN UPPER(rec.status) = 'PRESENT' THEN 1 END) AS present_days,
            COUNT(CASE WHEN UPPER(rec.status) = 'HALF_DAY' THEN 1 END) AS half_days,
            COUNT(CASE WHEN UPPER(rec.status) IN ('ON_LEAVE', 'WORK_FROM_HOME') THEN 1 END) AS leave_days
        FROM (
            SELECT a.id, a.student_id AS pid, a.attendance_date, a.status 
            FROM public.attendance_daily_records a 
            WHERE a.school_id = p_school_id AND a.attendance_date BETWEEN v_s_date AND v_e_date
            UNION ALL
            SELECT a.id, a.employee_id AS pid, a.attendance_date, a.status 
            FROM public.attendance_staff_records a 
            WHERE a.school_id = p_school_id AND a.attendance_date BETWEEN v_s_date AND v_e_date
        ) rec
        GROUP BY rec.pid
    ),
    absentee_base AS (
        SELECT 
            p.id AS person_id,
            p.full_name AS name,
            p.avatar_url,
            p.role,
            COALESCE(aa.class_name, p.department, 'Staff') AS class_or_dept,
            COALESCE(aa.section_name, '') AS section_name,
            pa.total_marked_days,
            pa.absent_days,
            pa.late_days,
            pa.present_days,
            pa.half_days,
            pa.leave_days,
            CASE 
                WHEN pa.total_marked_days > 0 THEN 
                    ROUND(((pa.present_days + pa.late_days + (pa.half_days * 0.5))::NUMERIC / pa.total_marked_days::NUMERIC) * 100.0, 2)
                ELSE 100.0
            END AS attendance_pct
        FROM public.profiles p
        LEFT JOIN active_assignments aa ON aa.student_id = p.id
        JOIN person_attendance_agg pa ON pa.pid = p.id
        WHERE p.school_id = p_school_id
          AND (p.status IS NULL OR p.status != 'Deleted')
          AND pa.absent_days > 0
          AND (p_class_id IS NULL OR aa.class_id = p_class_id)
          AND (p_section_id IS NULL OR aa.section_id = p_section_id)
          AND (v_dept IS NULL OR p.department ILIKE v_dept)
          AND (v_role IS NULL OR LOWER(p.role) = LOWER(v_role))
    ),
    absentee_ranked AS (
        SELECT 
            ROW_NUMBER() OVER (ORDER BY ab.absent_days DESC, ab.attendance_pct ASC, ab.name ASC) AS rank,
            ab.person_id,
            ab.name,
            ab.avatar_url,
            ab.role,
            CASE WHEN ab.section_name != '' THEN ab.class_or_dept || ' - ' || ab.section_name ELSE ab.class_or_dept END AS class_name,
            ab.section_name,
            ab.absent_days,
            ab.total_marked_days,
            ab.present_days,
            ab.late_days,
            ab.attendance_pct,
            -- Accurate trailing consecutive streak calculation
            COALESCE(
                (
                    WITH latest_records AS (
                        SELECT r.attendance_date, UPPER(r.status) AS st,
                               ROW_NUMBER() OVER (ORDER BY r.attendance_date DESC) as rn
                        FROM (
                            SELECT attendance_date, status FROM public.attendance_daily_records WHERE student_id = ab.person_id AND school_id = p_school_id AND attendance_date BETWEEN v_s_date AND v_e_date
                            UNION ALL
                            SELECT attendance_date, status FROM public.attendance_staff_records WHERE employee_id = ab.person_id AND school_id = p_school_id AND attendance_date BETWEEN v_s_date AND v_e_date
                        ) r
                    ),
                    first_non_absent AS (
                        SELECT MIN(rn) AS min_rn FROM latest_records WHERE st != 'ABSENT'
                    )
                    SELECT CASE 
                        WHEN (SELECT min_rn FROM first_non_absent) IS NULL THEN (SELECT COUNT(*) FROM latest_records)
                        ELSE (SELECT min_rn FROM first_non_absent) - 1 
                    END
                ),
                1
            ) AS consecutive_absences
        FROM absentee_base ab
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'rank', ar.rank,
                'student_id', ar.person_id,
                'person_id', ar.person_id,
                'name', ar.name,
                'avatar_url', ar.avatar_url,
                'role', ar.role,
                'class_name', ar.class_name,
                'section_name', ar.section_name,
                'absent_days', ar.absent_days,
                'total_days', ar.total_marked_days,
                'present_days', ar.present_days,
                'late_days', ar.late_days,
                'attendance_pct', ar.attendance_pct,
                'consecutive_absences', ar.consecutive_absences
            )
        ),
        '[]'::JSONB
    )
    INTO v_top_absentees
    FROM absentee_ranked ar;

    -- 10. Actual Day of Week Distribution (Sun - Sat)
    WITH dow_records AS (
        SELECT 
            EXTRACT(DOW FROM rec.attendance_date)::INT AS dow_num,
            COUNT(rec.id) AS tot,
            COUNT(CASE WHEN UPPER(rec.status) = 'PRESENT' THEN 1 END) AS pres,
            COUNT(CASE WHEN UPPER(rec.status) = 'LATE' THEN 1 END) AS lt,
            COUNT(CASE WHEN UPPER(rec.status) = 'HALF_DAY' THEN 1 END) AS hd
        FROM (
            SELECT a.id, a.attendance_date, a.status FROM public.attendance_daily_records a
            WHERE a.school_id = p_school_id AND a.attendance_date BETWEEN v_s_date AND v_e_date
              AND (p_class_id IS NULL OR a.class_id = p_class_id)
              AND (p_section_id IS NULL OR a.section_id = p_section_id)
              AND (v_view_by IN ('OVERALL', 'STUDENTS'))
              AND p_subject_id IS NULL
            UNION ALL
            SELECT a.id, a.attendance_date, a.status FROM public.attendance_period_records a
            WHERE a.school_id = p_school_id AND a.attendance_date BETWEEN v_s_date AND v_e_date
              AND (p_class_id IS NULL OR a.class_id = p_class_id)
              AND (p_section_id IS NULL OR a.section_id = p_section_id)
              AND a.subject_id = p_subject_id
              AND (v_view_by IN ('OVERALL', 'STUDENTS'))
            UNION ALL
            SELECT a.id, a.attendance_date, a.status FROM public.attendance_staff_records a
            JOIN public.profiles p ON p.id = a.employee_id
            WHERE a.school_id = p_school_id AND a.attendance_date BETWEEN v_s_date AND v_e_date
              AND (v_dept IS NULL OR p.department ILIKE v_dept)
              AND (v_role IS NULL OR LOWER(p.role) = LOWER(v_role))
              AND (v_view_by IN ('OVERALL', 'STAFF') OR v_role IS NOT NULL)
              AND p_class_id IS NULL
              AND p_subject_id IS NULL
        ) rec
        GROUP BY EXTRACT(DOW FROM rec.attendance_date)::INT
    ),
    all_dow AS (
        SELECT 
            d.d_num,
            d.day_name,
            d.day_abbr,
            COALESCE(dr.tot, 0) AS total_records,
            COALESCE(dr.pres, 0) AS present_count,
            COALESCE(dr.lt, 0) AS late_count,
            CASE 
                WHEN COALESCE(dr.tot, 0) > 0 THEN 
                    ROUND(((COALESCE(dr.pres, 0) + COALESCE(dr.lt, 0) + (COALESCE(dr.hd, 0) * 0.5))::NUMERIC / dr.tot::NUMERIC) * 100.0, 2)
                ELSE 0.0
            END AS attendance_pct
        FROM (
            VALUES 
                (1, 'Monday', 'Mon'),
                (2, 'Tuesday', 'Tue'),
                (3, 'Wednesday', 'Wed'),
                (4, 'Thursday', 'Thu'),
                (5, 'Friday', 'Fri'),
                (6, 'Saturday', 'Sat'),
                (0, 'Sunday', 'Sun')
        ) AS d(d_num, day_name, day_abbr)
        LEFT JOIN dow_records dr ON dr.dow_num = d.d_num
        ORDER BY CASE WHEN d.d_num = 0 THEN 7 ELSE d.d_num END ASC
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'day_num', ad.d_num,
                'day_name', ad.day_name,
                'day_abbr', ad.day_abbr,
                'total_records', ad.total_records,
                'present_count', ad.present_count,
                'late_count', ad.late_count,
                'attendance_pct', ad.attendance_pct
            )
        ),
        '[]'::JSONB
    )
    INTO v_day_of_week
    FROM all_dow ad;

    -- 11. Real Department-Wise Staff Attendance Breakdown
    WITH dept_aggregated AS (
        SELECT 
            COALESCE(NULLIF(TRIM(p.department), ''), 'General / Unassigned') AS dept_name,
            COUNT(a.id) AS total_records,
            COUNT(CASE WHEN UPPER(a.status) = 'PRESENT' THEN 1 END) AS present_cnt,
            COUNT(CASE WHEN UPPER(a.status) = 'LATE' THEN 1 END) AS late_cnt,
            COUNT(CASE WHEN UPPER(a.status) = 'HALF_DAY' THEN 1 END) AS half_cnt,
            COUNT(CASE WHEN UPPER(a.status) = 'ABSENT' THEN 1 END) AS absent_cnt,
            COUNT(CASE WHEN UPPER(a.status) IN ('ON_LEAVE', 'WORK_FROM_HOME') THEN 1 END) AS leave_cnt,
            CASE 
                WHEN COUNT(a.id) > 0 THEN 
                    ROUND(((COUNT(CASE WHEN UPPER(a.status) = 'PRESENT' THEN 1 END) + COUNT(CASE WHEN UPPER(a.status) = 'LATE' THEN 1 END) + (COUNT(CASE WHEN UPPER(a.status) = 'HALF_DAY' THEN 1 END) * 0.5))::NUMERIC / COUNT(a.id)::NUMERIC) * 100.0, 2)
                ELSE 0.0
            END AS attendance_pct
        FROM public.profiles p
        LEFT JOIN public.attendance_staff_records a ON a.employee_id = p.id AND a.school_id = p_school_id AND a.attendance_date BETWEEN v_s_date AND v_e_date
        WHERE p.school_id = p_school_id
          AND (p.status IS NULL OR p.status != 'Deleted')
          AND LOWER(p.role) != 'student'
          AND (v_dept IS NULL OR p.department ILIKE v_dept)
          AND (v_role IS NULL OR LOWER(p.role) = LOWER(v_role))
        GROUP BY COALESCE(NULLIF(TRIM(p.department), ''), 'General / Unassigned')
        ORDER BY attendance_pct DESC, total_records DESC
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'department', da.dept_name,
                'total_records', da.total_records,
                'present_count', da.present_cnt,
                'absent_count', da.absent_cnt,
                'late_count', da.late_cnt,
                'leave_count', da.leave_cnt,
                'attendance_pct', da.attendance_pct
            )
        ),
        '[]'::JSONB
    )
    INTO v_department_stats
    FROM dept_aggregated da;

    -- 12. Mathematically Grounded Insights & Alerts
    SELECT COUNT(*) INTO v_high_perf_classes FROM jsonb_array_elements(v_top_classes) elem WHERE (elem->>'attendance_pct')::NUMERIC >= 95.0 AND (elem->>'total_records')::INT > 0;
    SELECT COUNT(*) INTO v_low_perf_classes FROM jsonb_array_elements(v_top_classes) elem WHERE (elem->>'attendance_pct')::NUMERIC > 0 AND (elem->>'attendance_pct')::NUMERIC < 85.0 AND (elem->>'total_records')::INT > 0;
    v_late_delta := v_late_cur - v_late_prev;
    IF v_late_prev > 0 THEN
        v_late_delta_pct := ROUND((v_late_delta::NUMERIC / v_late_prev::NUMERIC) * 100.0, 1);
    ELSE
        v_late_delta_pct := 0.0;
    END IF;

    v_alerts := jsonb_build_array(
        jsonb_build_object(
            'type', CASE WHEN v_high_perf_classes > 0 THEN 'EXCELLENT' ELSE 'INFO' END,
            'title', 'Top Class Performance',
            'message', CASE 
                WHEN v_high_perf_classes > 0 THEN v_high_perf_classes || ' classes achieved exceptional attendance (≥ 95%) during this period.'
                ELSE 'No classes achieved ≥ 95% attendance during this period.'
            END,
            'icon', 'check_circle'
        ),
        jsonb_build_object(
            'type', CASE WHEN v_low_perf_classes > 0 THEN 'WARNING' ELSE 'SUCCESS' END,
            'title', 'Attendance Risk Watch',
            'message', CASE 
                WHEN v_low_perf_classes > 0 THEN v_low_perf_classes || ' classes have attendance below 85%. Administrative follow-up is recommended.'
                ELSE 'Zero classes are below the 85% critical attendance threshold.'
            END,
            'icon', 'warning'
        ),
        jsonb_build_object(
            'type', CASE WHEN v_late_delta > 0 THEN 'WARNING' ELSE 'INFO' END,
            'title', 'Tardiness Trend',
            'message', CASE 
                WHEN v_late_delta > 0 THEN 'Late arrivals increased by ' || ABS(v_late_delta_pct) || '% (' || v_late_delta || ' additional late entries).'
                WHEN v_late_delta < 0 THEN 'Late arrivals decreased by ' || ABS(v_late_delta_pct) || '% (' || ABS(v_late_delta) || ' fewer late entries).'
                ELSE 'Late arrival volume remained stable compared to the previous period.'
            END,
            'icon', 'access_time'
        ),
        jsonb_build_object(
            'type', CASE WHEN v_overall_delta >= 0 THEN 'SUCCESS' ELSE 'INFO' END,
            'title', 'Period Trend Velocity',
            'message', CASE 
                WHEN v_overall_delta > 0 THEN 'Overall attendance increased by +' || v_overall_delta || '% compared to the preceding period.'
                WHEN v_overall_delta < 0 THEN 'Overall attendance shifted by ' || v_overall_delta || '% compared to the preceding period.'
                ELSE 'Overall attendance rate held consistent with the prior benchmark.'
            END,
            'icon', 'trending_up'
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'start_date', v_s_date,
            'end_date', v_e_date,
            'view_by', v_view_by,
            'role', v_role,
            'class_id', p_class_id,
            'section_id', p_section_id,
            'department', v_dept,
            'granularity', v_granularity,
            'kpis', v_kpis,
            'trend', v_trend,
            'distribution', v_distribution,
            'top_classes', v_top_classes,
            'top_absentees', v_top_absentees,
            'day_of_week', v_day_of_week,
            'department_stats', v_department_stats,
            'available_departments', v_available_depts,
            'available_roles', v_available_roles,
            'insights_alerts', v_alerts
        )
    );
END;
$$;


-- ============================================================================
-- Profile Drilldown & Heatmap Stored Procedure
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_get_student_insights_profile(
    p_school_id UUID,
    p_person_id UUID,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_s_date DATE;
    v_e_date DATE;
    v_profile RECORD;
    v_total_days BIGINT := 0;
    v_present_days BIGINT := 0;
    v_absent_days BIGINT := 0;
    v_late_days BIGINT := 0;
    v_half_days BIGINT := 0;
    v_leave_days BIGINT := 0;
    v_attendance_pct NUMERIC := 0.0;
    v_heatmap JSONB := '[]'::JSONB;
    v_history JSONB := '[]'::JSONB;
BEGIN
    v_e_date := COALESCE(p_end_date, CURRENT_DATE);
    v_s_date := COALESCE(p_start_date, v_e_date - INTERVAL '60 days')::DATE;

    -- 1. Fetch Profile
    SELECT 
        p.id, p.full_name, p.email, p.phone, p.avatar_url, p.role, p.department, p.admission_number,
        c.name AS class_name, s.name AS section_name, sca.roll_number
    INTO v_profile
    FROM public.profiles p
    LEFT JOIN public.student_class_assignments sca ON sca.student_id = p.id AND sca.status = 'ACTIVE'
    LEFT JOIN public.academic_classes c ON c.id = sca.class_id
    LEFT JOIN public.academic_sections s ON s.id = sca.section_id
    WHERE p.id = p_person_id AND p.school_id = p_school_id
    LIMIT 1;

    IF v_profile.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Profile not found');
    END IF;

    -- 2. Aggregate Stats in period
    SELECT 
        COUNT(rec.id),
        COUNT(CASE WHEN UPPER(rec.status) = 'PRESENT' THEN 1 END),
        COUNT(CASE WHEN UPPER(rec.status) = 'ABSENT' THEN 1 END),
        COUNT(CASE WHEN UPPER(rec.status) = 'LATE' THEN 1 END),
        COUNT(CASE WHEN UPPER(rec.status) = 'HALF_DAY' THEN 1 END),
        COUNT(CASE WHEN UPPER(rec.status) IN ('ON_LEAVE', 'WORK_FROM_HOME') THEN 1 END)
    INTO 
        v_total_days, v_present_days, v_absent_days, v_late_days, v_half_days, v_leave_days
    FROM (
        SELECT id, attendance_date, status FROM public.attendance_daily_records WHERE student_id = p_person_id AND school_id = p_school_id AND attendance_date BETWEEN v_s_date AND v_e_date
        UNION ALL
        SELECT id, attendance_date, status FROM public.attendance_staff_records WHERE employee_id = p_person_id AND school_id = p_school_id AND attendance_date BETWEEN v_s_date AND v_e_date
    ) rec;

    IF v_total_days > 0 THEN
        v_attendance_pct := ROUND(((v_present_days + v_late_days + (v_half_days * 0.5))::NUMERIC / v_total_days::NUMERIC) * 100.0, 2);
    ELSE
        v_attendance_pct := 100.0;
    END IF;

    -- 3. Detailed History Logs
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', rec.id,
                'date', rec.attendance_date,
                'status', rec.status,
                'remarks', COALESCE(rec.remarks, ''),
                'marked_at', rec.created_at,
                'is_overridden', COALESCE(rec.is_overridden, FALSE),
                'override_reason', COALESCE(rec.override_reason, '')
            ) ORDER BY rec.attendance_date DESC
        ),
        '[]'::JSONB
    )
    INTO v_history
    FROM (
        SELECT id, attendance_date, status, remarks, created_at, is_overridden, override_reason 
        FROM public.attendance_daily_records 
        WHERE student_id = p_person_id AND school_id = p_school_id AND attendance_date BETWEEN v_s_date AND v_e_date
        UNION ALL
        SELECT id, attendance_date, status, remarks, created_at, FALSE AS is_overridden, '' AS override_reason 
        FROM public.attendance_staff_records 
        WHERE employee_id = p_person_id AND school_id = p_school_id AND attendance_date BETWEEN v_s_date AND v_e_date
    ) rec;

    -- 4. 30-Day Heatmap Generation (Daily sequence)
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'date', d.dt::DATE,
                'day', TO_CHAR(d.dt, 'DD'),
                'day_name', TO_CHAR(d.dt, 'Dy'),
                'status', COALESCE(rec.status, 'NOT_MARKED')
            ) ORDER BY d.dt ASC
        ),
        '[]'::JSONB
    )
    INTO v_heatmap
    FROM generate_series((v_e_date - INTERVAL '29 days')::DATE, v_e_date, INTERVAL '1 day') AS d(dt)
    LEFT JOIN (
        SELECT a.attendance_date, a.status FROM public.attendance_daily_records a WHERE a.student_id = p_person_id AND a.school_id = p_school_id AND a.attendance_date BETWEEN (v_e_date - INTERVAL '29 days')::DATE AND v_e_date
        UNION ALL
        SELECT a.attendance_date, a.status FROM public.attendance_staff_records a WHERE a.employee_id = p_person_id AND a.school_id = p_school_id AND a.attendance_date BETWEEN (v_e_date - INTERVAL '29 days')::DATE AND v_e_date
    ) rec ON rec.attendance_date = d.dt::DATE;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'profile', jsonb_build_object(
                'id', v_profile.id,
                'full_name', v_profile.full_name,
                'email', v_profile.email,
                'phone', v_profile.phone,
                'avatar_url', v_profile.avatar_url,
                'role', v_profile.role,
                'department', v_profile.department,
                'admission_number', v_profile.admission_number,
                'class_name', v_profile.class_name,
                'section_name', v_profile.section_name,
                'roll_number', v_profile.roll_number
            ),
            'stats', jsonb_build_object(
                'total_days', v_total_days,
                'present_days', v_present_days,
                'absent_days', v_absent_days,
                'late_days', v_late_days,
                'half_days', v_half_days,
                'leave_days', v_leave_days,
                'attendance_pct', v_attendance_pct
            ),
            'heatmap', v_heatmap,
            'history', v_history
        )
    );
END;
$$;
