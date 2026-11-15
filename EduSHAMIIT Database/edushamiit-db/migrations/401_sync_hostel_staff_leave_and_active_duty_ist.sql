-- =========================================================================
-- Migration 401: Dynamic Hostel Staff Leave & Active Duty Synchronization (IST Timezone)
-- Author: Antigravity Team
-- Date: 2026-11-03
-- Purpose:
--   1. Ensures all staff leave checks and duty statuses use IST timezone ('Asia/Kolkata').
--   2. Dynamically sets staff status to 'On Leave' when an approved leave covers today in IST.
--   3. When a staff member is Active on a leave date, automatically adjusts the leave date
--      (truncating end_date to yesterday in IST with days_count recalculated and status COMPLETED)
--      so active duty and leave records never conflict.
--   4. Keeps roster grid, detail drawer KPIs, and summary cards in 100% synchronization.
-- =========================================================================

-- 1. Helper function: Adjust leave dates for active staff members in IST
CREATE OR REPLACE FUNCTION public.fn_hostel_adjust_staff_leave_dates_for_active(
    p_school_id UUID,
    p_assignment_id UUID DEFAULT NULL,
    p_profile_id UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_ist_today DATE := (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;
    v_leave RECORD;
BEGIN
    FOR v_leave IN
        SELECT l.id, l.start_date, l.end_date, l.days_count, l.status, a.id AS assignment_id
        FROM public.hostel_staff_leaves l
        JOIN public.hostel_staff_assignments a ON (
            l.assignment_id = a.id 
            OR (l.profile_id = a.profile_id AND a.deleted_at IS NULL)
        )
        WHERE l.school_id = p_school_id
          AND (p_assignment_id IS NULL OR a.id = p_assignment_id OR l.assignment_id = p_assignment_id)
          AND (p_profile_id IS NULL OR a.profile_id = p_profile_id OR l.profile_id = p_profile_id)
          AND a.assignment_status = 'ACTIVE'
          AND a.duty_status NOT IN ('ON_LEAVE')
          AND l.deleted_at IS NULL
          AND l.status NOT IN ('CANCELLED', 'REJECTED')
          AND v_ist_today BETWEEN l.start_date AND l.end_date
    LOOP
        -- If leave began before today in IST, truncate end_date to yesterday so today is not a leave day
        IF v_leave.start_date < v_ist_today THEN
            UPDATE public.hostel_staff_leaves
            SET end_date = (v_ist_today - INTERVAL '1 day')::DATE,
                days_count = GREATEST(1.0, ((v_ist_today - INTERVAL '1 day')::DATE - v_leave.start_date + 1)::NUMERIC),
                status = 'COMPLETED',
                updated_at = NOW()
            WHERE id = v_leave.id;

        -- If leave was scheduled to start today in IST
        ELSIF v_leave.start_date = v_ist_today THEN
            IF v_leave.end_date > v_ist_today THEN
                -- Multi-day leave: defer start to tomorrow
                UPDATE public.hostel_staff_leaves
                SET start_date = (v_ist_today + INTERVAL '1 day')::DATE,
                    days_count = GREATEST(1.0, (v_leave.end_date - (v_ist_today + INTERVAL '1 day')::DATE + 1)::NUMERIC),
                    updated_at = NOW()
                WHERE id = v_leave.id;
            ELSE
                -- 1-day leave for today: user is active today, so cancel it
                UPDATE public.hostel_staff_leaves
                SET status = 'CANCELLED',
                    updated_at = NOW()
                WHERE id = v_leave.id;
            END IF;
        END IF;
    END LOOP;
END;
$$;


-- 2. Master synchronization function: Sync staff assignments and leave records in IST
CREATE OR REPLACE FUNCTION public.fn_hostel_sync_staff_leave_statuses_ist(
    p_school_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_ist_today DATE := (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;
BEGIN
    -- Step A: If staff member is ACTIVE, adjust any leave dates covering today in IST
    PERFORM public.fn_hostel_adjust_staff_leave_dates_for_active(p_school_id);

    -- Step B: For staff with an approved/active leave covering today in IST, set assignment to ON_LEAVE
    UPDATE public.hostel_staff_assignments a
    SET assignment_status = 'ON_LEAVE',
        duty_status = 'ON_LEAVE',
        updated_at = NOW()
    WHERE a.school_id = p_school_id
      AND a.deleted_at IS NULL
      AND a.assignment_status != 'ON_LEAVE'
      AND EXISTS (
          SELECT 1 FROM public.hostel_staff_leaves l
          WHERE l.school_id = p_school_id
            AND (l.assignment_id = a.id OR l.profile_id = a.profile_id)
            AND l.status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
            AND v_ist_today BETWEEN l.start_date AND l.end_date
            AND l.deleted_at IS NULL
      );

    -- Step C: For staff whose leave has passed (end_date < v_ist_today) and are currently marked ON_LEAVE:
    -- Complete past leaves
    UPDATE public.hostel_staff_leaves
    SET status = 'COMPLETED',
        updated_at = NOW()
    WHERE school_id = p_school_id
      AND status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
      AND end_date < v_ist_today
      AND deleted_at IS NULL;

    -- Return staff to ACTIVE duty if they have no current leave today
    UPDATE public.hostel_staff_assignments a
    SET assignment_status = 'ACTIVE',
        duty_status = 'ON_DUTY',
        updated_at = NOW()
    WHERE a.school_id = p_school_id
      AND a.deleted_at IS NULL
      AND (a.assignment_status = 'ON_LEAVE' OR a.duty_status = 'ON_LEAVE')
      AND NOT EXISTS (
          SELECT 1 FROM public.hostel_staff_leaves l
          WHERE l.school_id = p_school_id
            AND (l.assignment_id = a.id OR l.profile_id = a.profile_id)
            AND l.status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
            AND v_ist_today BETWEEN l.start_date AND l.end_date
            AND l.deleted_at IS NULL
      );
END;
$$;


-- 3. Update fn_hostel_get_staff_roster to use IST and dynamic leave status
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

    -- Fetch paginated results
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


-- 4. Update fn_hostel_get_staff_detail to use IST timezone and dynamic leave status
CREATE OR REPLACE FUNCTION public.fn_hostel_get_staff_detail(
    p_school_id UUID,
    p_assignment_id UUID,
    p_profile_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_ist_today DATE := (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;
    v_assignment RECORD;
    v_profile RECORD;
    v_areas JSONB := '[]'::JSONB;
    v_activities JSONB := '[]'::JSONB;
    v_documents JSONB := '[]'::JSONB;
    v_leaves JSONB := '[]'::JSONB;
    v_monthly_leaves NUMERIC := 0.0;
    v_active_leave RECORD;
BEGIN
    -- Synchronize leave statuses and adjust dates for active staff
    PERFORM public.fn_hostel_sync_staff_leave_statuses_ist(p_school_id);

    -- 1. Find assignment record
    SELECT a.*, b.name AS building_name
    INTO v_assignment
    FROM public.hostel_staff_assignments a
    LEFT JOIN public.hostel_buildings b ON a.hostel_id = b.id
    WHERE a.school_id = p_school_id
      AND (
          a.id = p_assignment_id 
          OR (p_profile_id IS NOT NULL AND a.profile_id = p_profile_id AND a.deleted_at IS NULL)
      )
      AND a.deleted_at IS NULL
    ORDER BY a.created_at DESC
    LIMIT 1;

    IF v_assignment.id IS NULL THEN
        -- Fallback: check profile directly
        SELECT * INTO v_profile FROM public.profiles WHERE id = COALESCE(p_profile_id, p_assignment_id);
        IF v_profile.id IS NULL THEN
            RETURN jsonb_build_object('success', FALSE, 'message', 'Staff profile or assignment not found');
        END IF;
    ELSE
        SELECT * INTO v_profile FROM public.profiles WHERE id = v_assignment.profile_id;
    END IF;

    -- 2. Assigned Areas
    IF v_assignment.id IS NOT NULL THEN
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', id,
                'area_name', area_name,
                'area_type', area_type,
                'badge_label', badge_label,
                'is_primary', is_primary
            ) ORDER BY is_primary DESC, created_at ASC
        ), '[]'::JSONB) INTO v_areas
        FROM public.hostel_staff_assignment_areas
        WHERE assignment_id = v_assignment.id;
    END IF;

    IF jsonb_array_length(v_areas) = 0 AND v_assignment.assigned_area_text IS NOT NULL THEN
        v_areas := jsonb_build_array(
            jsonb_build_object(
                'id', gen_random_uuid(),
                'area_name', v_assignment.assigned_area_text,
                'badge_label', 'Primary',
                'is_primary', TRUE
            )
        );
    END IF;

    -- 3. Audit Activities in IST
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', id,
            'activity_type', activity_type,
            'title', title,
            'description', description,
            'badge_color', badge_color,
            'performed_by_name', performed_by_name,
            'created_at', TO_CHAR(created_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM')
        ) ORDER BY created_at DESC
    ), '[]'::JSONB) INTO v_activities
    FROM public.hostel_staff_activities
    WHERE school_id = p_school_id
      AND profile_id = v_profile.id
    LIMIT 20;

    -- 4. Staff Documents in IST
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', d.id,
            'document_name', d.document_name,
            'document_type', d.document_type,
            'file_url', d.file_url,
            'file_size_bytes', COALESCE(d.file_size_bytes, 0),
            'mime_type', d.mime_type,
            'verification_status', d.verification_status,
            'verified_by_name', d.verified_by_name,
            'verified_at', TO_CHAR(d.verified_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM'),
            'notes', d.notes,
            'created_at', TO_CHAR(d.created_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM'),
            'formatted_date', TO_CHAR(d.created_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY')
        ) ORDER BY d.created_at DESC
    ), '[]'::JSONB) INTO v_documents
    FROM public.hostel_staff_documents d
    WHERE d.school_id = p_school_id
      AND (d.profile_id = v_profile.id OR (v_assignment.id IS NOT NULL AND d.assignment_id = v_assignment.id))
      AND d.deleted_at IS NULL;

    -- 5. Staff Leaves (Ordered by start_date DESC)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', l.id,
            'leave_type', l.leave_type,
            'start_date', TO_CHAR(l.start_date, 'DD Mon YYYY'),
            'end_date', TO_CHAR(l.end_date, 'DD Mon YYYY'),
            'raw_start_date', l.start_date,
            'raw_end_date', l.end_date,
            'days_count', l.days_count,
            'reason', l.reason,
            'status', l.status,
            'substitute_staff_name', COALESCE(l.substitute_staff_name, 'Unassigned / Backup Warden'),
            'emergency_contact', l.emergency_contact,
            'approved_by_name', l.approved_by_name,
            'created_at', TO_CHAR(l.created_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY')
        ) ORDER BY l.start_date DESC
    ), '[]'::JSONB) INTO v_leaves
    FROM public.hostel_staff_leaves l
    WHERE l.school_id = p_school_id
      AND (l.profile_id = v_profile.id OR (v_assignment.id IS NOT NULL AND l.assignment_id = v_assignment.id))
      AND l.deleted_at IS NULL;

    -- Calculate total monthly leave days taken within current calendar month in IST
    SELECT COALESCE(SUM(l.days_count), 0.0) INTO v_monthly_leaves
    FROM public.hostel_staff_leaves l
    WHERE l.school_id = p_school_id
      AND (l.profile_id = v_profile.id OR (v_assignment.id IS NOT NULL AND l.assignment_id = v_assignment.id))
      AND l.status IN ('APPROVED', 'COMPLETED', 'ACTIVE', 'ON_LEAVE')
      AND l.start_date <= (DATE_TRUNC('month', v_ist_today) + INTERVAL '1 month - 1 day')::DATE
      AND l.end_date >= DATE_TRUNC('month', v_ist_today)::DATE
      AND l.deleted_at IS NULL;

    -- Check if active leave exists right now in IST
    SELECT * INTO v_active_leave
    FROM public.hostel_staff_leaves
    WHERE school_id = p_school_id
      AND (profile_id = v_profile.id OR (v_assignment.id IS NOT NULL AND assignment_id = v_assignment.id))
      AND status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
      AND v_ist_today BETWEEN start_date AND end_date
      AND deleted_at IS NULL
    ORDER BY created_at DESC
    LIMIT 1;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'assignment_id', v_assignment.id,
            'profile_id', v_profile.id,
            'full_name', v_profile.full_name,
            'employee_id', COALESCE(v_profile.employee_id, 'HS001'),
            'avatar_url', COALESCE(v_profile.avatar_url, ''),
            'role', COALESCE(v_assignment.hostel_role, 'Warden'),
            'hostel_id', v_assignment.hostel_id,
            'hostel_name', COALESCE(v_assignment.building_name, 'Boys Hostel A'),
            'contact', COALESCE(v_profile.phone, '+91 98765 43210'),
            'email', COALESCE(v_profile.email, 'staff@edushamiit.edu'),
            'address', COALESCE(v_profile.address, 'A-123, Sector 62, Noida, UP'),
            'emergency_contact', CASE 
                WHEN v_profile.emergency_contact_phone IS NOT NULL AND v_profile.emergency_contact_name IS NOT NULL 
                THEN v_profile.emergency_contact_phone || ' (' || v_profile.emergency_contact_name || ')'
                WHEN v_profile.emergency_contact_phone IS NOT NULL 
                THEN v_profile.emergency_contact_phone
                ELSE '+91 98765 11111 (Emergency Contact)'
            END,
            'shift_timings', COALESCE(v_assignment.shift_timings, '8:00 AM - 10:00 PM'),
            'reporting_to', COALESCE(v_assignment.supervisor_name, 'Hostel Administrator'),
            'status', CASE 
                WHEN v_active_leave.id IS NOT NULL OR v_assignment.assignment_status = 'ON_LEAVE' OR v_assignment.duty_status = 'ON_LEAVE' THEN 'On Leave'
                WHEN v_assignment.assignment_status = 'PENDING' THEN 'Pending'
                WHEN v_assignment.assignment_status = 'ACTIVE' THEN 'Active'
                ELSE COALESCE(v_assignment.assignment_status, 'Active')
            END,
            'joining_date', COALESCE(TO_CHAR(v_profile.joining_date, 'DD Mon YYYY'), '15 Jul 2023'),
            'assigned_areas', v_areas,
            'activities', v_activities,
            'documents', v_documents,
            'leaves', v_leaves,
            'monthly_leaves_taken', v_monthly_leaves,
            'active_substitute_warden', COALESCE(v_active_leave.substitute_staff_name, 'Backup Warden'),
            'active_leave_reason', COALESCE(v_active_leave.reason, ''),
            'responsibilities', v_assignment.responsibilities,
            'remarks', v_assignment.remarks
        )
    );
END;
$$;


-- 5. Update fn_hostel_get_staff_kpis to use IST timezone and dynamic leave status
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
      AND a.assignment_status IN ('ACTIVE', 'ON_LEAVE', 'PENDING')
      AND a.hostel_role ILIKE '%Caretaker%';

    -- Support Staff count
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
            'academic_year', p_academic_year
        )
    );
END;
$$;


-- 6. Update fn_hostel_update_staff_assignment to auto-adjust leaves when staff is active
CREATE OR REPLACE FUNCTION public.fn_hostel_update_staff_assignment(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_assignment_id UUID := (p_data->>'assignment_id')::UUID;
    v_hostel_role VARCHAR := NULLIF(TRIM(p_data->>'hostel_role'), '');
    v_assigned_area_text VARCHAR := NULLIF(TRIM(p_data->>'assigned_area_text'), '');
    v_shift_timings VARCHAR := NULLIF(TRIM(p_data->>'shift_timings'), '');
    v_duty_status VARCHAR := NULLIF(TRIM(p_data->>'duty_status'), '');
    v_assignment_status VARCHAR := NULLIF(TRIM(p_data->>'assignment_status'), '');
    v_supervisor_name VARCHAR := NULLIF(TRIM(p_data->>'supervisor_name'), '');
    v_responsibilities TEXT := p_data->>'responsibilities';
    v_remarks TEXT := p_data->>'remarks';
    v_areas JSONB := p_data->'areas';
    v_profile_id UUID;
    v_user_name VARCHAR := 'Hostel Administrator';
    v_area_item JSONB;
    v_actor_profile_id UUID := NULL;
    v_ist_today DATE := (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;
BEGIN
    SELECT profile_id INTO v_profile_id
    FROM public.hostel_staff_assignments
    WHERE id = v_assignment_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_profile_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Hostel assignment record not found.');
    END IF;

    -- Safe actor check for profiles FK
    IF p_user_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
        v_actor_profile_id := p_user_id;
        SELECT full_name INTO v_user_name FROM public.profiles WHERE id = p_user_id;
    END IF;

    -- Update assignment record
    UPDATE public.hostel_staff_assignments
    SET hostel_role = COALESCE(v_hostel_role, hostel_role),
        assigned_area_text = COALESCE(v_assigned_area_text, assigned_area_text),
        shift_timings = COALESCE(v_shift_timings, shift_timings),
        duty_status = COALESCE(v_duty_status, duty_status),
        assignment_status = COALESCE(v_assignment_status, assignment_status),
        supervisor_name = COALESCE(v_supervisor_name, supervisor_name),
        responsibilities = COALESCE(v_responsibilities, responsibilities),
        remarks = COALESCE(v_remarks, remarks),
        version = version + 1,
        updated_by = v_actor_profile_id,
        updated_at = NOW()
    WHERE id = v_assignment_id;

    -- IF staff is active (duty_status ON_DUTY / ACTIVE, or assignment_status ACTIVE),
    -- adjust any leaves that cover today in IST so active status and leave dates do not conflict!
    IF v_duty_status IN ('ON_DUTY', 'ACTIVE') OR v_assignment_status = 'ACTIVE' THEN
        PERFORM public.fn_hostel_adjust_staff_leave_dates_for_active(p_school_id, v_assignment_id, v_profile_id);
    END IF;

    -- Update explicit areas if array is provided
    IF v_areas IS NOT NULL AND jsonb_typeof(v_areas) = 'array' AND jsonb_array_length(v_areas) > 0 THEN
        DELETE FROM public.hostel_staff_assignment_areas WHERE assignment_id = v_assignment_id;
        FOR v_area_item IN SELECT * FROM jsonb_array_elements(v_areas)
        LOOP
            INSERT INTO public.hostel_staff_assignment_areas (
                assignment_id, area_name, badge_label, is_primary
            ) VALUES (
                v_assignment_id,
                v_area_item->>'area_name',
                COALESCE(v_area_item->>'badge_label', 'Assigned'),
                COALESCE((v_area_item->>'is_primary')::BOOLEAN, FALSE)
            );
        END LOOP;
    ELSIF v_assigned_area_text IS NOT NULL AND TRIM(v_assigned_area_text) <> '' THEN
        IF EXISTS (SELECT 1 FROM public.hostel_staff_assignment_areas WHERE assignment_id = v_assignment_id AND is_primary = TRUE) THEN
            UPDATE public.hostel_staff_assignment_areas
            SET area_name = TRIM(v_assigned_area_text)
            WHERE assignment_id = v_assignment_id AND is_primary = TRUE;
        ELSIF EXISTS (SELECT 1 FROM public.hostel_staff_assignment_areas WHERE assignment_id = v_assignment_id) THEN
            UPDATE public.hostel_staff_assignment_areas
            SET area_name = TRIM(v_assigned_area_text), is_primary = TRUE
            WHERE id = (SELECT id FROM public.hostel_staff_assignment_areas WHERE assignment_id = v_assignment_id ORDER BY created_at ASC LIMIT 1);
        ELSE
            INSERT INTO public.hostel_staff_assignment_areas (
                assignment_id, area_name, badge_label, is_primary
            ) VALUES (
                v_assignment_id, TRIM(v_assigned_area_text), 'Primary', TRUE
            );
        END IF;
    END IF;

    -- Log activity in IST
    INSERT INTO public.hostel_staff_activities (
        school_id, assignment_id, profile_id, activity_type, title, description,
        badge_color, performed_by, performed_by_name
    ) VALUES (
        p_school_id, v_assignment_id, v_profile_id, 'ASSIGNMENT_UPDATED',
        'Assignment Details Updated',
        'Updated duty details and assigned area to ' || COALESCE(v_assigned_area_text, 'Default'),
        'blue', v_actor_profile_id, v_user_name
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Staff assignment updated successfully'
    );
END;
$$;


-- 7. Update fn_hostel_return_staff_to_duty to adjust leave dates in IST
CREATE OR REPLACE FUNCTION public.fn_hostel_return_staff_to_duty(
    p_school_id UUID,
    p_user_id UUID,
    p_assignment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_assign RECORD;
    v_ist_today DATE := (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;
    v_actor_profile_id UUID := NULL;
BEGIN
    SELECT * INTO v_assign FROM public.hostel_staff_assignments 
    WHERE id = p_assignment_id AND school_id = p_school_id AND deleted_at IS NULL;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Staff assignment not found');
    END IF;

    IF p_user_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
        v_actor_profile_id := p_user_id;
    END IF;

    -- Update assignment back to ACTIVE / ON_DUTY
    UPDATE public.hostel_staff_assignments
    SET assignment_status = 'ACTIVE',
        duty_status = 'ON_DUTY',
        updated_at = NOW(),
        updated_by = v_actor_profile_id
    WHERE id = p_assignment_id;

    -- Adjust any leaves covering today in IST: user is returning to active duty today,
    -- so truncate end_date to yesterday in IST and mark COMPLETED
    UPDATE public.hostel_staff_leaves
    SET end_date = (v_ist_today - INTERVAL '1 day')::DATE,
        days_count = GREATEST(1.0, ((v_ist_today - INTERVAL '1 day')::DATE - start_date + 1)::NUMERIC),
        status = 'COMPLETED',
        updated_at = NOW(),
        updated_by = v_actor_profile_id
    WHERE (assignment_id = p_assignment_id OR profile_id = v_assign.profile_id)
      AND status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
      AND start_date < v_ist_today
      AND end_date >= v_ist_today
      AND deleted_at IS NULL;

    -- Cancel any 1-day leave scheduled for today
    UPDATE public.hostel_staff_leaves
    SET status = 'CANCELLED',
        updated_at = NOW(),
        updated_by = v_actor_profile_id
    WHERE (assignment_id = p_assignment_id OR profile_id = v_assign.profile_id)
      AND status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
      AND start_date = v_ist_today
      AND end_date = v_ist_today
      AND deleted_at IS NULL;

    -- Audit Activity in IST
    INSERT INTO public.hostel_staff_activities (
        school_id, assignment_id, profile_id, activity_type,
        title, description, badge_color, performed_by, performed_by_name
    ) VALUES (
        p_school_id, v_assign.id, v_assign.profile_id, 'RETURN_TO_DUTY',
        'Returned to Active Duty',
        'Staff resumed active residential duty shifts on ' || TO_CHAR(v_ist_today, 'DD Mon YYYY') || '; leave dates adjusted.',
        'green', v_actor_profile_id, 'Hostel Administrator'
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Staff returned to active duty successfully. Leave dates adjusted.'
    );
END;
$$;


-- 8. Update fn_hostel_record_staff_leave to use IST timezone
CREATE OR REPLACE FUNCTION public.fn_hostel_record_staff_leave(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_ist_today DATE := (NOW() AT TIME ZONE 'Asia/Kolkata')::DATE;
    v_assignment_id UUID;
    v_profile_id UUID;
    v_leave_type TEXT;
    v_start_date DATE;
    v_end_date DATE;
    v_days NUMERIC(4, 1);
    v_reason TEXT;
    v_substitute TEXT;
    v_contact TEXT;
    v_leave_id UUID;
    v_actor_profile_id UUID := NULL;
BEGIN
    v_assignment_id := NULLIF(TRIM(p_data->>'assignment_id'), '')::UUID;
    v_profile_id := NULLIF(TRIM(p_data->>'profile_id'), '')::UUID;

    IF v_profile_id IS NULL AND v_assignment_id IS NOT NULL THEN
        SELECT profile_id INTO v_profile_id 
        FROM public.hostel_staff_assignments 
        WHERE id = v_assignment_id;
    END IF;

    IF v_profile_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Staff assignment or profile required');
    END IF;

    v_leave_type := COALESCE(NULLIF(TRIM(p_data->>'leave_type'), ''), 'Casual Leave');
    v_start_date := COALESCE((p_data->>'start_date')::DATE, v_ist_today);
    v_end_date := COALESCE((p_data->>'end_date')::DATE, v_start_date);

    IF v_end_date < v_start_date THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'End date cannot be earlier than start date');
    END IF;

    -- Overlap prevention: verify that no active or approved leave exists for the same staff overlapping these dates
    IF EXISTS (
        SELECT 1 FROM public.hostel_staff_leaves
        WHERE school_id = p_school_id
          AND profile_id = v_profile_id
          AND status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
          AND deleted_at IS NULL
          AND (start_date <= v_end_date AND end_date >= v_start_date)
    ) THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Staff member already has an active or recorded leave overlapping with the selected dates.'
        );
    END IF;

    v_days := GREATEST(1.0, (v_end_date - v_start_date + 1)::NUMERIC);
    v_reason := COALESCE(NULLIF(TRIM(p_data->>'reason'), ''), 'Authorized staff absence');
    v_substitute := COALESCE(NULLIF(TRIM(p_data->>'substitute_staff_name'), ''), 'Backup Warden');
    v_contact := COALESCE(NULLIF(TRIM(p_data->>'emergency_contact'), ''), '+91 98765 43210');

    -- Safe profile check for FK
    IF p_user_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
        v_actor_profile_id := p_user_id;
    END IF;

    INSERT INTO public.hostel_staff_leaves (
        school_id, profile_id, assignment_id, leave_type,
        start_date, end_date, days_count, reason,
        status, substitute_staff_name, emergency_contact,
        approved_by, approved_by_name, approved_at, created_by, updated_by
    ) VALUES (
        p_school_id, v_profile_id, v_assignment_id, v_leave_type,
        v_start_date, v_end_date, v_days, v_reason,
        'APPROVED', v_substitute, v_contact,
        v_actor_profile_id, 'Hostel Administrator', NOW(), v_actor_profile_id, v_actor_profile_id
    ) RETURNING id INTO v_leave_id;

    -- Update assignment status to ON_LEAVE if current date in IST falls within leave period
    IF v_ist_today BETWEEN v_start_date AND v_end_date AND v_assignment_id IS NOT NULL THEN
        UPDATE public.hostel_staff_assignments
        SET assignment_status = 'ON_LEAVE',
            duty_status = 'ON_LEAVE',
            updated_at = NOW(),
            updated_by = v_actor_profile_id
        WHERE id = v_assignment_id;
    END IF;

    -- Audit Activity in IST
    INSERT INTO public.hostel_staff_activities (
        school_id, assignment_id, profile_id, activity_type,
        title, description, badge_color, performed_by, performed_by_name
    ) VALUES (
        p_school_id, v_assignment_id, v_profile_id, 'LEAVE_RECORDED',
        'Staff Leave Recorded',
        v_leave_type || ' (' || v_days || ' days: ' || TO_CHAR(v_start_date, 'DD Mon') || ' - ' || TO_CHAR(v_end_date, 'DD Mon') || ') · Substitute: ' || v_substitute,
        'orange', v_actor_profile_id, 'Hostel Administrator'
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Staff leave recorded successfully',
        'data', jsonb_build_object('id', v_leave_id)
    );
END;
$$;


-- 9. Immediate Execution: Adjust existing active staff leaves and synchronize IST statuses
SELECT public.fn_hostel_sync_staff_leave_statuses_ist('11111111-1111-1111-1111-111111111111');
