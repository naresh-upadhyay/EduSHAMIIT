-- =========================================================================
-- Migration 403: Fix Hostel Staff KPIs and Grid Row Numbering
-- Author: Antigravity Team
-- Date: 2026-11-03
-- Purpose:
--   1. Fix row numbering in fn_hostel_get_staff_roster by explicitly returning
--      'row_num', row_num in jsonb_build_object so the grid # column shows sequential
--      numbers across all pages (1..10, 11..20, 21..30).
--   2. In fn_hostel_get_staff_kpis, return both 'pending_count' and
--      'pending_assignments_count' to ensure consistent deserialization across
--      all services and clients without falling back to mock or default values.
-- =========================================================================

-- 1. Update fn_hostel_get_staff_roster with 'row_num' in jsonb_build_object
CREATE OR REPLACE FUNCTION public.fn_hostel_get_staff_roster(
    p_school_id UUID,
    p_academic_year VARCHAR DEFAULT '2024 - 2025',
    p_search VARCHAR DEFAULT '',
    p_hostel_id UUID DEFAULT NULL,
    p_role VARCHAR DEFAULT 'ALL',
    p_status VARCHAR DEFAULT 'ALL',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'default',
    p_sort_order VARCHAR DEFAULT 'ASC'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_ist_today DATE := (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;
    v_offset INT := (GREATEST(p_page, 1) - 1) * p_page_size;
    v_total_records INT := 0;
    v_total_pages INT := 1;
    v_rows JSONB := '[]'::JSONB;
BEGIN
    -- Synchronize leave statuses and adjust dates for active staff
    PERFORM public.fn_hostel_sync_staff_leave_statuses_ist(p_school_id);

    -- Count total records matching filter
    SELECT COUNT(*) INTO v_total_records
    FROM public.hostel_staff_assignments a
    JOIN public.profiles p ON a.profile_id = p.id
    LEFT JOIN public.hostel_buildings b ON a.hostel_id = b.id
    WHERE a.school_id = p_school_id
      AND a.deleted_at IS NULL
      AND (
          p_academic_year = '' 
          OR a.academic_year = p_academic_year 
          OR a.academic_year = '2026 - 2027' 
          OR a.academic_year = '2024 - 2025'
      )
      AND (p_hostel_id IS NULL OR a.hostel_id = p_hostel_id)
      AND (
          p_role = 'ALL' 
          OR a.hostel_role ILIKE '%' || p_role || '%'
      )
      AND (
          p_status = 'ALL'
          OR (
              p_status = 'Active' 
              AND a.assignment_status = 'ACTIVE' 
              AND a.duty_status != 'ON_LEAVE'
              AND NOT EXISTS (
                  SELECT 1 FROM public.hostel_staff_leaves l
                  WHERE l.school_id = p_school_id
                    AND (l.profile_id = a.profile_id OR l.assignment_id = a.id)
                    AND l.status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
                    AND v_ist_today BETWEEN l.start_date AND l.end_date
                    AND l.deleted_at IS NULL
              )
          )
          OR (
              p_status = 'On Leave' 
              AND (
                  a.assignment_status = 'ON_LEAVE' 
                  OR a.duty_status = 'ON_LEAVE'
                  OR EXISTS (
                      SELECT 1 FROM public.hostel_staff_leaves l
                      WHERE l.school_id = p_school_id
                        AND (l.profile_id = a.profile_id OR l.assignment_id = a.id)
                        AND l.status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
                        AND v_ist_today BETWEEN l.start_date AND l.end_date
                        AND l.deleted_at IS NULL
                  )
              )
          )
          OR (p_status = 'Pending' AND a.assignment_status = 'PENDING')
          OR (p_status = a.assignment_status)
      )
      AND (
          p_search = '' 
          OR p.full_name ILIKE '%' || p_search || '%'
          OR COALESCE(p.employee_id, '') ILIKE '%' || p_search || '%'
          OR COALESCE(p.phone, '') ILIKE '%' || p_search || '%'
          OR a.hostel_role ILIKE '%' || p_search || '%'
          OR COALESCE(b.name, '') ILIKE '%' || p_search || '%'
          OR a.assigned_area_text ILIKE '%' || p_search || '%'
      );

    v_total_pages := GREATEST(CEIL(v_total_records::NUMERIC / GREATEST(p_page_size, 1)), 1);

    -- Fetch paginated results with explicit row numbering
    WITH ordered_staff AS (
        SELECT 
            a.id AS assignment_id,
            p.id AS profile_id,
            p.full_name AS name,
            COALESCE(p.employee_id, '') AS employee_id,
            COALESCE(p.avatar_url, '') AS photo_url,
            a.hostel_role AS role,
            a.hostel_id,
            COALESCE(b.name, 'Unassigned') AS hostel_name,
            COALESCE(b.code, '') AS hostel_code,
            a.assigned_area_text AS assigned_area,
            COALESCE(p.phone, '') AS contact,
            COALESCE(p.email, '') AS email,
            CASE 
                WHEN EXISTS (
                    SELECT 1 FROM public.hostel_staff_leaves l
                    WHERE l.school_id = p_school_id
                      AND (l.profile_id = a.profile_id OR l.assignment_id = a.id)
                      AND l.status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
                      AND v_ist_today BETWEEN l.start_date AND l.end_date
                      AND l.deleted_at IS NULL
                ) OR a.assignment_status = 'ON_LEAVE' OR a.duty_status = 'ON_LEAVE' THEN 'On Leave'
                WHEN a.assignment_status = 'PENDING' THEN 'Pending'
                WHEN a.assignment_status = 'ACTIVE' THEN 'Active'
                ELSE a.assignment_status
            END AS status,
            a.shift_timings,
            COALESCE(TO_CHAR(p.joining_date, 'DD Mon YYYY'), TO_CHAR(a.start_date, 'DD Mon YYYY')) AS joining_date,
            a.created_at,
            ROW_NUMBER() OVER (
                ORDER BY 
                    CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'ASC' THEN p.full_name END ASC,
                    CASE WHEN p_sort_by = 'name' AND UPPER(p_sort_order) = 'DESC' THEN p.full_name END DESC,
                    CASE WHEN p_sort_by = 'role' AND UPPER(p_sort_order) = 'ASC' THEN a.hostel_role END ASC,
                    CASE WHEN p_sort_by = 'role' AND UPPER(p_sort_order) = 'DESC' THEN a.hostel_role END DESC,
                    CASE WHEN p_sort_by = 'hostel' AND UPPER(p_sort_order) = 'ASC' THEN b.name END ASC,
                    CASE WHEN p_sort_by = 'hostel' AND UPPER(p_sort_order) = 'DESC' THEN b.name END DESC,
                    CASE WHEN p_sort_by = 'status' AND UPPER(p_sort_order) = 'ASC' THEN a.assignment_status END ASC,
                    CASE WHEN p_sort_by = 'status' AND UPPER(p_sort_order) = 'DESC' THEN a.assignment_status END DESC,
                    p.employee_id ASC NULLS LAST,
                    a.created_at ASC
            ) AS row_num
        FROM public.hostel_staff_assignments a
        JOIN public.profiles p ON a.profile_id = p.id
        LEFT JOIN public.hostel_buildings b ON a.hostel_id = b.id
        WHERE a.school_id = p_school_id
          AND a.deleted_at IS NULL
          AND (
              p_academic_year = '' 
              OR a.academic_year = p_academic_year 
              OR a.academic_year = '2026 - 2027' 
              OR a.academic_year = '2024 - 2025'
          )
          AND (p_hostel_id IS NULL OR a.hostel_id = p_hostel_id)
          AND (
              p_role = 'ALL' 
              OR a.hostel_role ILIKE '%' || p_role || '%'
          )
          AND (
              p_status = 'ALL'
              OR (
                  p_status = 'Active' 
                  AND a.assignment_status = 'ACTIVE' 
                  AND a.duty_status != 'ON_LEAVE'
                  AND NOT EXISTS (
                      SELECT 1 FROM public.hostel_staff_leaves l
                      WHERE l.school_id = p_school_id
                        AND (l.profile_id = a.profile_id OR l.assignment_id = a.id)
                        AND l.status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
                        AND v_ist_today BETWEEN l.start_date AND l.end_date
                        AND l.deleted_at IS NULL
                  )
              )
              OR (
                  p_status = 'On Leave' 
                  AND (
                      a.assignment_status = 'ON_LEAVE' 
                      OR a.duty_status = 'ON_LEAVE'
                      OR EXISTS (
                          SELECT 1 FROM public.hostel_staff_leaves l
                          WHERE l.school_id = p_school_id
                            AND (l.profile_id = a.profile_id OR l.assignment_id = a.id)
                            AND l.status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
                            AND v_ist_today BETWEEN l.start_date AND l.end_date
                            AND l.deleted_at IS NULL
                      )
                  )
              )
              OR (p_status = 'Pending' AND a.assignment_status = 'PENDING')
              OR (p_status = a.assignment_status)
          )
          AND (
              p_search = '' 
              OR p.full_name ILIKE '%' || p_search || '%'
              OR COALESCE(p.employee_id, '') ILIKE '%' || p_search || '%'
              OR COALESCE(p.phone, '') ILIKE '%' || p_search || '%'
              OR a.hostel_role ILIKE '%' || p_search || '%'
              OR COALESCE(b.name, '') ILIKE '%' || p_search || '%'
              OR a.assigned_area_text ILIKE '%' || p_search || '%'
          )
    )
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'row_num', row_num,
            'assignment_id', assignment_id,
            'profile_id', profile_id,
            'name', name,
            'employee_id', employee_id,
            'photo_url', photo_url,
            'role', role,
            'hostel_id', hostel_id,
            'hostel_name', hostel_name,
            'hostel_code', hostel_code,
            'assigned_area', assigned_area,
            'contact', contact,
            'email', email,
            'status', status,
            'shift_timings', shift_timings,
            'joining_date', joining_date
        )
    ), '[]'::JSONB) INTO v_rows
    FROM ordered_staff
    WHERE row_num > v_offset AND row_num <= (v_offset + p_page_size);

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', v_rows,
        'pagination', jsonb_build_object(
            'page', p_page,
            'page_size', p_page_size,
            'total_records', v_total_records,
            'total_pages', v_total_pages,
            'has_prev', p_page > 1,
            'has_next', p_page < v_total_pages
        )
    );
END;
$$;


-- 2. Update fn_hostel_get_staff_kpis with both pending_count and pending_assignments_count
CREATE OR REPLACE FUNCTION public.fn_hostel_get_staff_kpis(
    p_school_id UUID,
    p_academic_year VARCHAR DEFAULT '2024 - 2025'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_ist_today DATE := (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;
    v_total_staff INT := 0;
    v_wardens_count INT := 0;
    v_wardens_boys INT := 0;
    v_wardens_girls INT := 0;
    v_caretakers_count INT := 0;
    v_support_count INT := 0;
    v_on_leave_count INT := 0;
    v_pending_count INT := 0;
BEGIN
    -- Synchronize leave statuses and adjust dates for active staff
    PERFORM public.fn_hostel_sync_staff_leave_statuses_ist(p_school_id);

    -- Total staff assignments
    SELECT COUNT(*) INTO v_total_staff
    FROM public.hostel_staff_assignments a
    WHERE a.school_id = p_school_id
      AND a.deleted_at IS NULL
      AND (
          p_academic_year = '' 
          OR a.academic_year = p_academic_year 
          OR a.academic_year = '2026 - 2027' 
          OR a.academic_year = '2024 - 2025'
      )
      AND a.assignment_status IN ('ACTIVE', 'ON_LEAVE', 'PENDING');

    -- Wardens count (Boys vs Girls hostels)
    SELECT COUNT(*) INTO v_wardens_count
    FROM public.hostel_staff_assignments a
    WHERE a.school_id = p_school_id
      AND a.deleted_at IS NULL
      AND (
          p_academic_year = '' 
          OR a.academic_year = p_academic_year 
          OR a.academic_year = '2026 - 2027' 
          OR a.academic_year = '2024 - 2025'
      )
      AND a.assignment_status IN ('ACTIVE', 'ON_LEAVE', 'PENDING')
      AND a.hostel_role ILIKE '%Warden%';

    SELECT COUNT(*) INTO v_wardens_boys
    FROM public.hostel_staff_assignments a
    JOIN public.hostel_buildings b ON a.hostel_id = b.id
    WHERE a.school_id = p_school_id
      AND a.deleted_at IS NULL
      AND (
          p_academic_year = '' 
          OR a.academic_year = p_academic_year 
          OR a.academic_year = '2026 - 2027' 
          OR a.academic_year = '2024 - 2025'
      )
      AND a.assignment_status IN ('ACTIVE', 'ON_LEAVE', 'PENDING')
      AND a.hostel_role ILIKE '%Warden%'
      AND (b.gender_policy = 'BOYS' OR b.name ILIKE '%Boy%');

    SELECT COUNT(*) INTO v_wardens_girls
    FROM public.hostel_staff_assignments a
    JOIN public.hostel_buildings b ON a.hostel_id = b.id
    WHERE a.school_id = p_school_id
      AND a.deleted_at IS NULL
      AND (
          p_academic_year = '' 
          OR a.academic_year = p_academic_year 
          OR a.academic_year = '2026 - 2027' 
          OR a.academic_year = '2024 - 2025'
      )
      AND a.assignment_status IN ('ACTIVE', 'ON_LEAVE', 'PENDING')
      AND a.hostel_role ILIKE '%Warden%'
      AND (b.gender_policy = 'GIRLS' OR b.name ILIKE '%Girl%');

    -- Caretakers count
    SELECT COUNT(*) INTO v_caretakers_count
    FROM public.hostel_staff_assignments a
    WHERE a.school_id = p_school_id
      AND a.deleted_at IS NULL
      AND (
          p_academic_year = '' 
          OR a.academic_year = p_academic_year 
          OR a.academic_year = '2026 - 2027' 
          OR a.academic_year = '2024 - 2025'
      )
      AND a.assignment_status IN ('ACTIVE', 'ON_LEAVE')
      AND a.hostel_role ILIKE '%Caretaker%';

    -- Support staff count (Security, Housekeeping, Maintenance, Mess, Others)
    SELECT COUNT(*) INTO v_support_count
    FROM public.hostel_staff_assignments a
    WHERE a.school_id = p_school_id
      AND a.deleted_at IS NULL
      AND (
          p_academic_year = '' 
          OR a.academic_year = p_academic_year 
          OR a.academic_year = '2026 - 2027' 
          OR a.academic_year = '2024 - 2025'
      )
      AND a.assignment_status IN ('ACTIVE', 'ON_LEAVE')
      AND a.hostel_role NOT ILIKE '%Warden%'
      AND a.hostel_role NOT ILIKE '%Caretaker%';

    -- On Leave count in IST
    SELECT COUNT(*) INTO v_on_leave_count
    FROM public.hostel_staff_assignments a
    WHERE a.school_id = p_school_id
      AND a.deleted_at IS NULL
      AND (
          p_academic_year = '' 
          OR a.academic_year = p_academic_year 
          OR a.academic_year = '2026 - 2027' 
          OR a.academic_year = '2024 - 2025'
      )
      AND (
          a.duty_status = 'ON_LEAVE' 
          OR a.assignment_status = 'ON_LEAVE'
          OR EXISTS (
              SELECT 1 FROM public.hostel_staff_leaves l
              WHERE l.school_id = p_school_id
                AND (l.profile_id = a.profile_id OR l.assignment_id = a.id)
                AND l.status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
                AND v_ist_today BETWEEN l.start_date AND l.end_date
                AND l.deleted_at IS NULL
          )
      );

    -- Pending Assignments count
    SELECT COUNT(*) INTO v_pending_count
    FROM public.hostel_staff_assignments a
    WHERE a.school_id = p_school_id
      AND a.deleted_at IS NULL
      AND (
          p_academic_year = '' 
          OR a.academic_year = p_academic_year 
          OR a.academic_year = '2026 - 2027' 
          OR a.academic_year = '2024 - 2025'
      )
      AND a.assignment_status = 'PENDING';

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'total_staff', v_total_staff,
            'wardens_count', v_wardens_count,
            'wardens_boys', v_wardens_boys,
            'wardens_girls', v_wardens_girls,
            'caretakers_count', v_caretakers_count,
            'support_count', v_support_count,
            'on_leave_count', v_on_leave_count,
            'pending_count', v_pending_count,
            'pending_assignments_count', v_pending_count,
            'academic_year', p_academic_year
        )
    );
END;
$$;

