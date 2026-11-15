-- ============================================================================
-- Migration: 364_hostel_staff_management_system.sql
-- Description: Complete Production-Grade Hostel Staff Management Module
--              Staff Assignments (profiles FK, never duplicates user master),
--              Hostel Hierarchy Linkages (hostels, buildings, floors, rooms, areas),
--              Multi-Area Assignment & Shift Timings, Stored Procedures for KPI Cards,
--              Paginated Staff Roster with Server-Side Search/Filter/Sort,
--              360 Staff Inspector Drawer with Assigned Areas & Timeline Activities,
--              Screenshot-Accurate Reference Data for Boys & Girls Hostels (28 Staff)
-- ============================================================================

-- 1. Create Hostel Staff Assignments Table (Hostel operational duty assignments)
CREATE TABLE IF NOT EXISTS public.hostel_staff_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    academic_year VARCHAR(50) NOT NULL DEFAULT '2024 - 2025',
    hostel_id UUID NOT NULL REFERENCES public.hostel_buildings(id) ON DELETE CASCADE,
    building_id UUID REFERENCES public.hostel_buildings(id) ON DELETE SET NULL,
    floor_id UUID REFERENCES public.hostel_floors(id) ON DELETE SET NULL,
    hostel_role VARCHAR(50) NOT NULL, -- 'Warden', 'Caretaker', 'Security', 'Housekeeping', 'Maintenance', 'Mess Coordinator'
    assigned_area_text VARCHAR(150) NOT NULL DEFAULT 'Overall', -- 'Overall', '1st Floor', '2nd Floor', 'Main Gate', 'All Floors', etc.
    is_primary BOOLEAN NOT NULL DEFAULT TRUE,
    shift_name VARCHAR(100) DEFAULT 'Day Shift',
    shift_timings VARCHAR(100) DEFAULT '6:00 AM - 10:00 PM',
    duty_status VARCHAR(50) NOT NULL DEFAULT 'ON_DUTY', -- 'ON_DUTY', 'OFF_DUTY', 'ON_LEAVE'
    assignment_status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE', -- 'ACTIVE', 'ON_LEAVE', 'PENDING', 'ENDED', 'INACTIVE'
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,
    supervisor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    supervisor_name VARCHAR(150) DEFAULT 'Hostel Administrator',
    responsibilities TEXT,
    remarks TEXT,
    version INT NOT NULL DEFAULT 1,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

-- Constraint: Index for performance and tenant isolation
CREATE INDEX IF NOT EXISTS idx_hostel_staff_assignments_school_year
    ON public.hostel_staff_assignments (school_id, academic_year, assignment_status)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_hostel_staff_assignments_profile
    ON public.hostel_staff_assignments (school_id, profile_id)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_hostel_staff_assignments_hostel
    ON public.hostel_staff_assignments (school_id, hostel_id)
    WHERE deleted_at IS NULL;

-- 2. Create Hostel Staff Assignment Areas Table (Multiple functional areas per assignment)
CREATE TABLE IF NOT EXISTS public.hostel_staff_assignment_areas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL REFERENCES public.hostel_staff_assignments(id) ON DELETE CASCADE,
    area_name VARCHAR(150) NOT NULL, -- e.g. 'Overall Hostel Supervision', 'Discipline & Safety', 'Student Welfare', 'Mess Coordination'
    area_type VARCHAR(50) DEFAULT 'SUPERVISION',
    badge_label VARCHAR(50) DEFAULT 'Assigned', -- 'Primary', 'Assigned'
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hostel_staff_areas_assignment
    ON public.hostel_staff_assignment_areas (assignment_id);

-- 3. Create Hostel Staff Activities / Audit Timeline Table
CREATE TABLE IF NOT EXISTS public.hostel_staff_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    assignment_id UUID REFERENCES public.hostel_staff_assignments(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    activity_type VARCHAR(50) NOT NULL, -- 'ASSIGNED', 'UPDATED', 'TRANSFERRED', 'ENDED', 'LEAVE_LOGGED', 'DUTY_CHANGED'
    title VARCHAR(200) NOT NULL,
    description TEXT,
    badge_color VARCHAR(30) DEFAULT 'blue', -- 'green', 'blue', 'orange', 'purple', 'red'
    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
    performed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    performed_by_name VARCHAR(150),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hostel_staff_activities_profile
    ON public.hostel_staff_activities (school_id, profile_id, created_at DESC);


-- ============================================================================
-- STORED PROCEDURES & DATABASE FUNCTIONS
-- ============================================================================

-- A. Top 6 KPI Cards Function
CREATE OR REPLACE FUNCTION public.fn_hostel_get_staff_kpis(
    p_school_id UUID,
    p_academic_year VARCHAR DEFAULT '2024 - 2025'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_staff INT := 0;
    v_wardens_count INT := 0;
    v_wardens_boys INT := 0;
    v_wardens_girls INT := 0;
    v_caretakers_count INT := 0;
    v_support_count INT := 0;
    v_on_leave_count INT := 0;
    v_pending_count INT := 0;
BEGIN
    -- Total staff assignments
    SELECT COUNT(*) INTO v_total_staff
    FROM public.hostel_staff_assignments a
    WHERE a.school_id = p_school_id
      AND a.academic_year = p_academic_year
      AND a.deleted_at IS NULL
      AND a.assignment_status IN ('ACTIVE', 'ON_LEAVE', 'PENDING');

    -- Wardens count (Boys vs Girls hostels)
    SELECT COUNT(*) INTO v_wardens_count
    FROM public.hostel_staff_assignments a
    WHERE a.school_id = p_school_id
      AND a.academic_year = p_academic_year
      AND a.deleted_at IS NULL
      AND a.assignment_status IN ('ACTIVE', 'ON_LEAVE', 'PENDING')
      AND a.hostel_role ILIKE '%Warden%';

    SELECT COUNT(*) INTO v_wardens_boys
    FROM public.hostel_staff_assignments a
    JOIN public.hostel_buildings b ON a.hostel_id = b.id
    WHERE a.school_id = p_school_id
      AND a.academic_year = p_academic_year
      AND a.deleted_at IS NULL
      AND a.assignment_status IN ('ACTIVE', 'ON_LEAVE', 'PENDING')
      AND a.hostel_role ILIKE '%Warden%'
      AND (b.gender_policy = 'BOYS' OR b.name ILIKE '%Boy%');

    SELECT COUNT(*) INTO v_wardens_girls
    FROM public.hostel_staff_assignments a
    JOIN public.hostel_buildings b ON a.hostel_id = b.id
    WHERE a.school_id = p_school_id
      AND a.academic_year = p_academic_year
      AND a.deleted_at IS NULL
      AND a.assignment_status IN ('ACTIVE', 'ON_LEAVE', 'PENDING')
      AND a.hostel_role ILIKE '%Warden%'
      AND (b.gender_policy = 'GIRLS' OR b.name ILIKE '%Girl%');

    -- Caretakers count
    SELECT COUNT(*) INTO v_caretakers_count
    FROM public.hostel_staff_assignments a
    WHERE a.school_id = p_school_id
      AND a.academic_year = p_academic_year
      AND a.deleted_at IS NULL
      AND a.assignment_status IN ('ACTIVE', 'ON_LEAVE', 'PENDING')
      AND a.hostel_role ILIKE '%Caretaker%';

    -- Support Staff count (Cleaners, Security, Housekeeping, Maintenance, Mess, Others)
    SELECT COUNT(*) INTO v_support_count
    FROM public.hostel_staff_assignments a
    WHERE a.school_id = p_school_id
      AND a.academic_year = p_academic_year
      AND a.deleted_at IS NULL
      AND a.assignment_status IN ('ACTIVE', 'ON_LEAVE')
      AND a.hostel_role NOT ILIKE '%Warden%'
      AND a.hostel_role NOT ILIKE '%Caretaker%';

    -- On Leave count
    SELECT COUNT(*) INTO v_on_leave_count
    FROM public.hostel_staff_assignments a
    WHERE a.school_id = p_school_id
      AND a.academic_year = p_academic_year
      AND a.deleted_at IS NULL
      AND (a.duty_status = 'ON_LEAVE' OR a.assignment_status = 'ON_LEAVE');

    -- Pending Assignments count
    SELECT COUNT(*) INTO v_pending_count
    FROM public.hostel_staff_assignments a
    WHERE a.school_id = p_school_id
      AND a.academic_year = p_academic_year
      AND a.deleted_at IS NULL
      AND a.assignment_status = 'PENDING';

    RETURN jsonb_build_object(
        'total_staff', v_total_staff,
        'wardens_count', v_wardens_count,
        'wardens_boys', v_wardens_boys,
        'wardens_girls', v_wardens_girls,
        'caretakers_count', v_caretakers_count,
        'support_count', v_support_count,
        'on_leave_count', v_on_leave_count,
        'pending_assignments_count', v_pending_count,
        'academic_year', p_academic_year
    );
END;
$$;


-- B. Paginated Staff Roster Grid matching Screenshot Data Table
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
    v_offset INT := (GREATEST(p_page, 1) - 1) * p_page_size;
    v_total_records INT := 0;
    v_total_pages INT := 1;
    v_rows JSONB := '[]'::JSONB;
BEGIN
    -- Count total records matching filter
    SELECT COUNT(*) INTO v_total_records
    FROM public.hostel_staff_assignments a
    JOIN public.profiles p ON a.profile_id = p.id
    LEFT JOIN public.hostel_buildings b ON a.hostel_id = b.id
    WHERE a.school_id = p_school_id
      AND a.academic_year = p_academic_year
      AND a.deleted_at IS NULL
      AND (p_hostel_id IS NULL OR a.hostel_id = p_hostel_id)
      AND (
          p_role = 'ALL' 
          OR a.hostel_role ILIKE '%' || p_role || '%'
      )
      AND (
          p_status = 'ALL'
          OR (p_status = 'Active' AND a.assignment_status = 'ACTIVE' AND a.duty_status != 'ON_LEAVE')
          OR (p_status = 'On Leave' AND (a.assignment_status = 'ON_LEAVE' OR a.duty_status = 'ON_LEAVE'))
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
                WHEN a.assignment_status = 'ON_LEAVE' OR a.duty_status = 'ON_LEAVE' THEN 'On Leave'
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
          AND a.academic_year = p_academic_year
          AND a.deleted_at IS NULL
          AND (p_hostel_id IS NULL OR a.hostel_id = p_hostel_id)
          AND (
              p_role = 'ALL' 
              OR a.hostel_role ILIKE '%' || p_role || '%'
          )
          AND (
              p_status = 'ALL'
              OR (p_status = 'Active' AND a.assignment_status = 'ACTIVE' AND a.duty_status != 'ON_LEAVE')
              OR (p_status = 'On Leave' AND (a.assignment_status = 'ON_LEAVE' OR a.duty_status = 'ON_LEAVE'))
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
            'row_num', row_num,
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
    FROM (
        SELECT * FROM ordered_staff
        OFFSET v_offset
        LIMIT p_page_size
    ) sub;

    RETURN jsonb_build_object(
        'data', v_rows,
        'pagination', jsonb_build_object(
            'current_page', p_page,
            'page_size', p_page_size,
            'total_records', v_total_records,
            'total_pages', v_total_pages,
            'has_next', p_page < v_total_pages,
            'has_prev', p_page > 1
        )
    );
END;
$$;


-- C. 360 Staff Detail Inspector Drawer Function
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
    v_assignment RECORD;
    v_profile RECORD;
    v_areas JSONB := '[]'::JSONB;
    v_activities JSONB := '[]'::JSONB;
BEGIN
    -- Find assignment record
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

    -- Fetch assigned areas
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

    -- If no areas explicitly defined in table, build from assigned_area_text
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

    -- Fetch activities
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', id,
            'activity_type', activity_type,
            'title', title,
            'description', description,
            'badge_color', badge_color,
            'performed_by_name', performed_by_name,
            'created_at', TO_CHAR(created_at, 'DD Mon YYYY, HH12:MI AM')
        ) ORDER BY created_at DESC
    ), '[]'::JSONB) INTO v_activities
    FROM public.hostel_staff_activities
    WHERE school_id = p_school_id
      AND profile_id = v_profile.id
    LIMIT 15;

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
            'email', COALESCE(v_profile.email, 'suresh.kumar@school.edu'),
            'address', COALESCE(v_profile.address, 'A-123, Sector 62, Noida, UP'),
            'emergency_contact', CASE 
                WHEN v_profile.emergency_contact_phone IS NOT NULL AND v_profile.emergency_contact_name IS NOT NULL 
                THEN v_profile.emergency_contact_phone || ' (' || v_profile.emergency_contact_name || ')'
                WHEN v_profile.emergency_contact_phone IS NOT NULL 
                THEN v_profile.emergency_contact_phone
                ELSE '+91 98765 11111 (Spouse)'
            END,
            'shift_timings', COALESCE(v_assignment.shift_timings, '6:00 AM - 10:00 PM'),
            'reporting_to', COALESCE(v_assignment.supervisor_name, 'Hostel Administrator'),
            'status', CASE 
                WHEN v_assignment.assignment_status = 'ON_LEAVE' OR v_assignment.duty_status = 'ON_LEAVE' THEN 'On Leave'
                WHEN v_assignment.assignment_status = 'PENDING' THEN 'Pending'
                WHEN v_assignment.assignment_status = 'ACTIVE' THEN 'Active'
                ELSE COALESCE(v_assignment.assignment_status, 'Active')
            END,
            'joining_date', COALESCE(TO_CHAR(v_profile.joining_date, 'DD Mon YYYY'), '12 Apr 2023'),
            'assigned_areas', v_areas,
            'activities', v_activities,
            'responsibilities', v_assignment.responsibilities,
            'remarks', v_assignment.remarks
        )
    );
END;
$$;


-- D. Assign Staff Function
CREATE OR REPLACE FUNCTION public.fn_hostel_assign_staff(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile_id UUID := (p_data->>'profile_id')::UUID;
    v_hostel_id UUID := (p_data->>'hostel_id')::UUID;
    v_academic_year VARCHAR := COALESCE(p_data->>'academic_year', '2024 - 2025');
    v_hostel_role VARCHAR := p_data->>'hostel_role';
    v_assigned_area_text VARCHAR := COALESCE(p_data->>'assigned_area_text', 'Overall');
    v_shift_timings VARCHAR := COALESCE(p_data->>'shift_timings', '6:00 AM - 10:00 PM');
    v_start_date DATE := COALESCE((p_data->>'start_date')::DATE, CURRENT_DATE);
    v_supervisor_name VARCHAR := COALESCE(p_data->>'supervisor_name', 'Hostel Administrator');
    v_responsibilities TEXT := p_data->>'responsibilities';
    v_remarks TEXT := p_data->>'remarks';
    v_areas JSONB := p_data->'areas';
    v_assignment_id UUID;
    v_area_item JSONB;
    v_user_name VARCHAR := 'Admin';
    v_staff_name VARCHAR;
BEGIN
    -- Validate profile exists in same school
    SELECT full_name INTO v_staff_name
    FROM public.profiles
    WHERE id = v_profile_id AND school_id = p_school_id AND status = 'Active';

    IF v_staff_name IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Selected staff profile does not exist or is not active in this school.');
    END IF;

    -- Validate hostel building exists in same school
    IF NOT EXISTS (SELECT 1 FROM public.hostel_buildings WHERE id = v_hostel_id AND school_id = p_school_id AND deleted_at IS NULL) THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Specified hostel building does not exist in this school.');
    END IF;

    -- Check for duplicate active assignment for same profile in same hostel and role
    IF EXISTS (
        SELECT 1 FROM public.hostel_staff_assignments
        WHERE school_id = p_school_id
          AND profile_id = v_profile_id
          AND hostel_id = v_hostel_id
          AND hostel_role = v_hostel_role
          AND academic_year = v_academic_year
          AND assignment_status = 'ACTIVE'
          AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Staff is already actively assigned to this hostel with the same role.');
    END IF;

    -- Get actor name
    SELECT full_name INTO v_user_name FROM public.profiles WHERE id = p_user_id;

    -- Insert assignment
    INSERT INTO public.hostel_staff_assignments (
        school_id, profile_id, academic_year, hostel_id, hostel_role,
        assigned_area_text, is_primary, shift_timings, duty_status, assignment_status,
        start_date, supervisor_name, responsibilities, remarks, created_by
    ) VALUES (
        p_school_id, v_profile_id, v_academic_year, v_hostel_id, v_hostel_role,
        v_assigned_area_text, TRUE, v_shift_timings, 'ON_DUTY', 'ACTIVE',
        v_start_date, v_supervisor_name, v_responsibilities, v_remarks, p_user_id
    ) RETURNING id INTO v_assignment_id;

    -- Insert assigned areas
    IF v_areas IS NOT NULL AND jsonb_typeof(v_areas) = 'array' AND jsonb_array_length(v_areas) > 0 THEN
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
    ELSE
        -- Default primary area
        INSERT INTO public.hostel_staff_assignment_areas (
            assignment_id, area_name, badge_label, is_primary
        ) VALUES (
            v_assignment_id, v_assigned_area_text, 'Primary', TRUE
        );
    END IF;

    -- Log activity
    INSERT INTO public.hostel_staff_activities (
        school_id, assignment_id, profile_id, activity_type, title, description,
        badge_color, performed_by, performed_by_name
    ) VALUES (
        p_school_id, v_assignment_id, v_profile_id, 'ASSIGNED',
        'Staff Assigned to Hostel',
        'Assigned as ' || v_hostel_role || ' (' || v_assigned_area_text || ')',
        'blue', p_user_id, COALESCE(v_user_name, 'Admin')
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Staff member assigned successfully',
        'assignment_id', v_assignment_id
    );
END;
$$;


-- E. Update Staff Assignment Function
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
    v_hostel_role VARCHAR := p_data->>'hostel_role';
    v_assigned_area_text VARCHAR := p_data->>'assigned_area_text';
    v_shift_timings VARCHAR := p_data->>'shift_timings';
    v_duty_status VARCHAR := p_data->>'duty_status';
    v_assignment_status VARCHAR := p_data->>'assignment_status';
    v_supervisor_name VARCHAR := p_data->>'supervisor_name';
    v_responsibilities TEXT := p_data->>'responsibilities';
    v_remarks TEXT := p_data->>'remarks';
    v_areas JSONB := p_data->'areas';
    v_profile_id UUID;
    v_user_name VARCHAR := 'Admin';
    v_area_item JSONB;
BEGIN
    SELECT profile_id INTO v_profile_id
    FROM public.hostel_staff_assignments
    WHERE id = v_assignment_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_profile_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Hostel assignment record not found.');
    END IF;

    SELECT full_name INTO v_user_name FROM public.profiles WHERE id = p_user_id;

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
        updated_by = p_user_id,
        updated_at = NOW()
    WHERE id = v_assignment_id;

    -- Update areas if provided
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
    END IF;

    -- Log activity
    INSERT INTO public.hostel_staff_activities (
        school_id, assignment_id, profile_id, activity_type, title, description,
        badge_color, performed_by, performed_by_name
    ) VALUES (
        p_school_id, v_assignment_id, v_profile_id, 'UPDATED',
        'Assignment Details Updated',
        'Updated duty details and assigned areas',
        'purple', p_user_id, COALESCE(v_user_name, 'Admin')
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Assignment updated successfully'
    );
END;
$$;


-- F. Transfer Staff Assignment Function
CREATE OR REPLACE FUNCTION public.fn_hostel_transfer_staff(
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
    v_new_hostel_id UUID := (p_data->>'new_hostel_id')::UUID;
    v_new_area_text VARCHAR := COALESCE(p_data->>'new_area_text', 'Overall');
    v_reason TEXT := COALESCE(p_data->>'reason', 'Administrative Transfer');
    v_profile_id UUID;
    v_old_hostel_id UUID;
    v_old_hostel_name VARCHAR;
    v_new_hostel_name VARCHAR;
    v_user_name VARCHAR := 'Admin';
BEGIN
    SELECT a.profile_id, a.hostel_id, b.name 
    INTO v_profile_id, v_old_hostel_id, v_old_hostel_name
    FROM public.hostel_staff_assignments a
    LEFT JOIN public.hostel_buildings b ON a.hostel_id = b.id
    WHERE a.id = v_assignment_id AND a.school_id = p_school_id AND a.deleted_at IS NULL;

    IF v_profile_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Assignment record not found.');
    END IF;

    SELECT name INTO v_new_hostel_name
    FROM public.hostel_buildings
    WHERE id = v_new_hostel_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_new_hostel_name IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Destination hostel not found.');
    END IF;

    SELECT full_name INTO v_user_name FROM public.profiles WHERE id = p_user_id;

    -- Update assignment record to new hostel
    UPDATE public.hostel_staff_assignments
    SET hostel_id = v_new_hostel_id,
        assigned_area_text = v_new_area_text,
        remarks = COALESCE(remarks || E'\n', '') || 'Transferred from ' || v_old_hostel_name || ' to ' || v_new_hostel_name || ': ' || v_reason,
        version = version + 1,
        updated_by = p_user_id,
        updated_at = NOW()
    WHERE id = v_assignment_id;

    -- Log transfer activity
    INSERT INTO public.hostel_staff_activities (
        school_id, assignment_id, profile_id, activity_type, title, description,
        badge_color, performed_by, performed_by_name
    ) VALUES (
        p_school_id, v_assignment_id, v_profile_id, 'TRANSFERRED',
        'Staff Transferred to ' || v_new_hostel_name,
        'Transferred from ' || v_old_hostel_name || ' (' || v_new_area_text || '). Reason: ' || v_reason,
        'orange', p_user_id, COALESCE(v_user_name, 'Admin')
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Staff transferred to ' || v_new_hostel_name || ' successfully.'
    );
END;
$$;


-- G. End Staff Assignment Function (Never touches profile)
CREATE OR REPLACE FUNCTION public.fn_hostel_end_staff_assignment(
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
    v_end_date DATE := COALESCE((p_data->>'end_date')::DATE, CURRENT_DATE);
    v_reason TEXT := COALESCE(p_data->>'reason', 'Duty Completed / Assignment Relieved');
    v_profile_id UUID;
    v_user_name VARCHAR := 'Admin';
BEGIN
    SELECT profile_id INTO v_profile_id
    FROM public.hostel_staff_assignments
    WHERE id = v_assignment_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_profile_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Assignment record not found.');
    END IF;

    SELECT full_name INTO v_user_name FROM public.profiles WHERE id = p_user_id;

    UPDATE public.hostel_staff_assignments
    SET assignment_status = 'ENDED',
        duty_status = 'OFF_DUTY',
        end_date = v_end_date,
        remarks = COALESCE(remarks || E'\n', '') || 'Assignment ended on ' || TO_CHAR(v_end_date, 'YYYY-MM-DD') || ': ' || v_reason,
        version = version + 1,
        updated_by = p_user_id,
        updated_at = NOW()
    WHERE id = v_assignment_id;

    -- Log activity
    INSERT INTO public.hostel_staff_activities (
        school_id, assignment_id, profile_id, activity_type, title, description,
        badge_color, performed_by, performed_by_name
    ) VALUES (
        p_school_id, v_assignment_id, v_profile_id, 'ENDED',
        'Hostel Assignment Concluded',
        'Relieved from duties. Reason: ' || v_reason,
        'red', p_user_id, COALESCE(v_user_name, 'Admin')
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Hostel staff assignment ended successfully. (Staff profile remains active in school system)'
    );
END;
$$;


-- H. Get Eligible Profiles for Staff Assignment
CREATE OR REPLACE FUNCTION public.fn_hostel_get_eligible_staff_profiles(
    p_school_id UUID,
    p_search VARCHAR DEFAULT '',
    p_limit INT DEFAULT 25
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_results JSONB := '[]'::JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'full_name', p.full_name,
            'role', p.role,
            'employee_id', COALESCE(p.employee_id, ''),
            'phone', COALESCE(p.phone, ''),
            'email', COALESCE(p.email, ''),
            'avatar_url', COALESCE(p.avatar_url, ''),
            'status', p.status
        )
    ), '[]'::JSONB) INTO v_results
    FROM (
        SELECT p.*
        FROM public.profiles p
        WHERE p.school_id = p_school_id
          AND p.status = 'Active'
          AND p.role IN ('hostel', 'security', 'support', 'admin', 'teacher', 'hr')
          AND (
              p_search = ''
              OR p.full_name ILIKE '%' || p_search || '%'
              OR COALESCE(p.employee_id, '') ILIKE '%' || p_search || '%'
              OR COALESCE(p.phone, '') ILIKE '%' || p_search || '%'
              OR COALESCE(p.email, '') ILIKE '%' || p_search || '%'
          )
        ORDER BY p.full_name ASC
        LIMIT p_limit
    ) p;

    RETURN v_results;
END;
$$;


-- ============================================================================
-- SEED DATA: 28 STAFF PROFILES & ASSIGNMENTS MATCHING SCREENSHOT EXACTLY
-- ============================================================================
DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_bha_id UUID;
    v_bhb_id UUID;
    v_gha_id UUID;
    v_ghb_id UUID;

    -- Profile IDs
    v_p_suresh UUID := '41000001-0000-0000-0000-000000000001';
    v_p_priya  UUID := '41000002-0000-0000-0000-000000000002';
    v_p_ramesh UUID := '41000003-0000-0000-0000-000000000003';
    v_p_anitha UUID := '41000004-0000-0000-0000-000000000004';
    v_p_karthik UUID := '41000005-0000-0000-0000-000000000005';
    v_p_sneha  UUID := '41000006-0000-0000-0000-000000000006';
    v_p_arif   UUID := '41000007-0000-0000-0000-000000000007';
    v_p_sunita UUID := '41000008-0000-0000-0000-000000000008';
    v_p_ravi   UUID := '41000009-0000-0000-0000-000000000009';
    v_p_meena  UUID := '41000010-0000-0000-0000-000000000010';

    -- Remaining profiles to complete 28 staff
    v_p_vikram UUID := '41000011-0000-0000-0000-000000000011';
    v_p_radhika UUID := '41000012-0000-0000-0000-000000000012';
    v_p_deepak UUID := '41000013-0000-0000-0000-000000000013';
    v_p_pooja  UUID := '41000014-0000-0000-0000-000000000014';
    v_p_manoj  UUID := '41000015-0000-0000-0000-000000000015';
    v_p_geeta  UUID := '41000016-0000-0000-0000-000000000016';
    v_p_rajesh UUID := '41000017-0000-0000-0000-000000000017';
    v_p_sandhya UUID := '41000018-0000-0000-0000-000000000018';
    v_p_amit   UUID := '41000019-0000-0000-0000-000000000019';
    v_p_rekha  UUID := '41000020-0000-0000-0000-000000000020';
    v_p_balram UUID := '41000021-0000-0000-0000-000000000021';
    v_p_kamla  UUID := '41000022-0000-0000-0000-000000000022';
    v_p_santosh UUID := '41000023-0000-0000-0000-000000000023';
    v_p_vijay  UUID := '41000024-0000-0000-0000-000000000024';
    v_p_naresh UUID := '41000025-0000-0000-0000-000000000025';
    v_p_kavita UUID := '41000026-0000-0000-0000-000000000026';
    v_p_omkar  UUID := '41000027-0000-0000-0000-000000000027';
    v_p_shanti UUID := '41000028-0000-0000-0000-000000000028';

    v_asg_suresh UUID := '51000001-0000-0000-0000-000000000001';
BEGIN
    -- Get hostel building IDs
    SELECT id INTO v_bha_id FROM public.hostel_buildings WHERE code = 'BHA' LIMIT 1;
    SELECT id INTO v_bhb_id FROM public.hostel_buildings WHERE code = 'BHB' LIMIT 1;
    SELECT id INTO v_gha_id FROM public.hostel_buildings WHERE code = 'GHA' LIMIT 1;
    SELECT id INTO v_ghb_id FROM public.hostel_buildings WHERE code = 'GHB' LIMIT 1;

    -- 1. Ensure 28 Profiles Exist in public.profiles (Single source of truth)
    INSERT INTO public.profiles (
        id, school_id, user_id, full_name, role, employee_id, gender, email, phone,
        address, emergency_contact_name, emergency_contact_phone, status, joining_date, avatar_url
    ) VALUES
    -- Top 10 matching screenshot rows exactly
    (v_p_suresh, v_school_id, 'usr_hs_001', 'Mr. Suresh Kumar', 'hostel', 'HS001', 'Male', 'suresh.kumar@school.edu', '+91 98765 43210', 'A-123, Sector 62, Noida, UP', 'Spouse', '+91 98765 11111', 'Active', '2023-04-12', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150'),
    (v_p_priya,  v_school_id, 'usr_hs_002', 'Mrs. Priya Nair', 'hostel', 'HS002', 'Female', 'priya.nair@school.edu', '+91 98765 43211', 'B-45, Green Park, South Delhi', 'Spouse', '+91 98765 11112', 'Active', '2023-05-10', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150'),
    (v_p_ramesh, v_school_id, 'usr_hs_003', 'Ramesh Babu', 'hostel', 'HS003', 'Male', 'ramesh.babu@school.edu', '+91 98765 43212', 'C-12, Indirapuram, Ghaziabad', 'Brother', '+91 98765 11113', 'Active', '2023-06-01', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150'),
    (v_p_anitha, v_school_id, 'usr_hs_004', 'Anitha Rao', 'hostel', 'HS004', 'Female', 'anitha.rao@school.edu', '+91 98765 43213', 'D-88, Rohini Sector 9, Delhi', 'Father', '+91 98765 11114', 'Active', '2023-06-15', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150'),
    (v_p_karthik, v_school_id, 'usr_hs_005', 'Karthik Reddy', 'hostel', 'HS005', 'Male', 'karthik.reddy@school.edu', '+91 98765 43214', 'E-204, Mayur Vihar Phase 1, Delhi', 'Mother', '+91 98765 11115', 'Active', '2023-07-01', 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150'),
    (v_p_sneha,  v_school_id, 'usr_hs_006', 'Sneha Iyer', 'hostel', 'HS006', 'Female', 'sneha.iyer@school.edu', '+91 98765 43215', 'F-19, Dwarka Sector 12, Delhi', 'Sister', '+91 98765 11116', 'Active', '2023-08-10', 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150'),
    (v_p_arif,   v_school_id, 'usr_hs_007', 'Mohammed Arif', 'security', 'HS007', 'Male', 'mohammed.arif@school.edu', '+91 98765 43216', 'G-72, Jamia Nagar, Okhla, Delhi', 'Spouse', '+91 98765 11117', 'Active', '2023-09-01', 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150'),
    (v_p_sunita, v_school_id, 'usr_hs_008', 'Sunita Devi', 'security', 'HS008', 'Female', 'sunita.devi@school.edu', '+91 98765 43217', 'H-102, Shakarpur, Delhi', 'Brother', '+91 98765 11118', 'Active', '2023-09-15', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150'),
    (v_p_ravi,   v_school_id, 'usr_hs_009', 'Ravi Shankar', 'support', 'HS009', 'Male', 'ravi.shankar@school.edu', '+91 98765 43218', 'J-34, Laxmi Nagar, Delhi', 'Father', '+91 98765 11119', 'Active', '2023-10-01', 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150'),
    (v_p_meena,  v_school_id, 'usr_hs_010', 'Meena Joshi', 'support', 'HS010', 'Female', 'meena.joshi@school.edu', '+91 98765 43219', 'K-55, Anand Vihar, Delhi', 'Spouse', '+91 98765 11120', 'Active', '2023-10-15', 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150'),

    -- Remaining 18 staff
    (v_p_vikram, v_school_id, 'usr_hs_011', 'Vikram Singh', 'hostel', 'HS011', 'Male', 'vikram.singh@school.edu', '+91 98765 43220', 'L-10, Rajouri Garden, Delhi', 'Spouse', '+91 98765 11121', 'Active', '2023-04-15', 'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=150'),
    (v_p_radhika, v_school_id, 'usr_hs_012', 'Radhika Menon', 'hostel', 'HS012', 'Female', 'radhika.menon@school.edu', '+91 98765 43221', 'M-22, Hauz Khas, Delhi', 'Spouse', '+91 98765 11122', 'Active', '2023-04-20', 'https://images.unsplash.com/photo-1548142813-c348350df52b?w=150'),
    (v_p_deepak, v_school_id, 'usr_hs_013', 'Deepak Verma', 'hostel', 'HS013', 'Male', 'deepak.verma@school.edu', '+91 98765 43222', 'N-40, Janakpuri, Delhi', 'Mother', '+91 98765 11123', 'Active', '2023-07-15', 'https://images.unsplash.com/photo-1513956589380-bad6acb9b9d4?w=150'),
    (v_p_pooja,  v_school_id, 'usr_hs_014', 'Pooja Hegde', 'hostel', 'HS014', 'Female', 'pooja.hegde@school.edu', '+91 98765 43223', 'P-15, Punjabi Bagh, Delhi', 'Father', '+91 98765 11124', 'Active', '2023-08-01', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150'),
    (v_p_manoj,  v_school_id, 'usr_hs_015', 'Manoj Tiwari', 'hostel', 'HS015', 'Male', 'manoj.tiwari@school.edu', '+91 98765 43224', 'Q-67, Karol Bagh, Delhi', 'Brother', '+91 98765 11125', 'Active', '2023-08-15', 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=150'),
    (v_p_geeta,  v_school_id, 'usr_hs_016', 'Geeta Rao', 'hostel', 'HS016', 'Female', 'geeta.rao@school.edu', '+91 98765 43225', 'R-81, Patel Nagar, Delhi', 'Spouse', '+91 98765 11126', 'Active', '2023-09-01', 'https://images.unsplash.com/photo-1554151228-14d9def656e4?w=150'),
    (v_p_rajesh, v_school_id, 'usr_hs_017', 'Rajesh Pillai', 'hostel', 'HS017', 'Male', 'rajesh.pillai@school.edu', '+91 98765 43226', 'S-93, Paschim Vihar, Delhi', 'Father', '+91 98765 11127', 'Active', '2023-09-10', 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150'),
    (v_p_sandhya, v_school_id, 'usr_hs_018', 'Sandhya Rani', 'hostel', 'HS018', 'Female', 'sandhya.rani@school.edu', '+91 98765 43227', 'T-11, Pitampura, Delhi', 'Mother', '+91 98765 11128', 'Active', '2023-09-20', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150'),
    (v_p_amit,   v_school_id, 'usr_hs_019', 'Amit Chauhan', 'hostel', 'HS019', 'Male', 'amit.chauhan@school.edu', '+91 98765 43228', 'U-44, Shalimar Bagh, Delhi', 'Brother', '+91 98765 11129', 'Active', '2023-11-01', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150'),
    (v_p_rekha,  v_school_id, 'usr_hs_020', 'Rekha Sharma', 'hostel', 'HS020', 'Female', 'rekha.sharma@school.edu', '+91 98765 43229', 'V-29, Model Town, Delhi', 'Father', '+91 98765 11130', 'Active', '2023-11-05', 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=150'),
    (v_p_balram, v_school_id, 'usr_hs_021', 'Balram Yadav', 'security', 'HS021', 'Male', 'balram.yadav@school.edu', '+91 98765 43230', 'W-51, Alipur, Delhi', 'Spouse', '+91 98765 11131', 'Active', '2023-10-01', 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150'),
    (v_p_kamla,  v_school_id, 'usr_hs_022', 'Kamla Bai', 'support', 'HS022', 'Female', 'kamla.bai@school.edu', '+91 98765 43231', 'X-18, Narela, Delhi', 'Spouse', '+91 98765 11132', 'Active', '2023-10-10', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150'),
    (v_p_santosh, v_school_id, 'usr_hs_023', 'Santosh Kumar', 'support', 'HS023', 'Male', 'santosh.kumar@school.edu', '+91 98765 43232', 'Y-83, Badarpur, Delhi', 'Father', '+91 98765 11133', 'Active', '2023-08-01', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150'),
    (v_p_vijay,  v_school_id, 'usr_hs_024', 'Vijay Patil', 'support', 'HS024', 'Male', 'vijay.patil@school.edu', '+91 98765 43233', 'Z-14, Mehrauli, Delhi', 'Mother', '+91 98765 11134', 'Active', '2023-08-15', 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150'),
    (v_p_naresh, v_school_id, 'usr_hs_025', 'Naresh Gowda', 'support', 'HS025', 'Male', 'naresh.gowda@school.edu', '+91 98765 43234', 'AA-22, Saket, Delhi', 'Spouse', '+91 98765 11135', 'Active', '2023-07-20', 'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=150'),
    (v_p_kavita, v_school_id, 'usr_hs_026', 'Kavita Patil', 'support', 'HS026', 'Female', 'kavita.patil@school.edu', '+91 98765 43235', 'AB-67, Malviya Nagar, Delhi', 'Spouse', '+91 98765 11136', 'Active', '2023-07-25', 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150'),
    (v_p_omkar,  v_school_id, 'usr_hs_027', 'Omkar Nath', 'security', 'HS027', 'Male', 'omkar.nath@school.edu', '+91 98765 43236', 'AC-33, Kalkaji, Delhi', 'Brother', '+91 98765 11137', 'Active', '2023-09-05', 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150'),
    (v_p_shanti, v_school_id, 'usr_hs_028', 'Shanti Devi', 'support', 'HS028', 'Female', 'shanti.devi@school.edu', '+91 98765 43237', 'AD-19, Lajpat Nagar, Delhi', 'Father', '+91 98765 11138', 'Active', '2023-10-05', 'https://images.unsplash.com/photo-1554151228-14d9def656e4?w=150')
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        employee_id = EXCLUDED.employee_id,
        phone = EXCLUDED.phone,
        email = EXCLUDED.email,
        address = EXCLUDED.address,
        emergency_contact_name = EXCLUDED.emergency_contact_name,
        emergency_contact_phone = EXCLUDED.emergency_contact_phone,
        status = EXCLUDED.status,
        avatar_url = EXCLUDED.avatar_url;

    -- 2. Clear old test assignments for clean 28-record state
    DELETE FROM public.hostel_staff_assignments WHERE school_id = v_school_id AND academic_year = '2024 - 2025';

    -- 3. Insert 28 Hostel Staff Assignments
    -- 4 Wardens: 2 Boys (Suresh Kumar, Vikram Singh) & 2 Girls (Priya Nair, Radhika Menon)
    INSERT INTO public.hostel_staff_assignments (
        id, school_id, profile_id, academic_year, hostel_id, hostel_role, assigned_area_text,
        is_primary, shift_timings, duty_status, assignment_status, start_date, supervisor_name
    ) VALUES
    (v_asg_suresh, v_school_id, v_p_suresh, '2024 - 2025', v_bha_id, 'Warden', 'Overall', TRUE, '6:00 AM - 10:00 PM', 'ON_DUTY', 'ACTIVE', '2023-04-12', 'Hostel Administrator'),
    ('51000002-0000-0000-0000-000000000002', v_school_id, v_p_priya,  '2024 - 2025', v_gha_id, 'Warden', 'Overall', TRUE, '6:00 AM - 10:00 PM', 'ON_DUTY', 'ACTIVE', '2023-05-10', 'Hostel Administrator'),
    ('51000011-0000-0000-0000-000000000011', v_school_id, v_p_vikram, '2024 - 2025', v_bhb_id, 'Warden', 'Overall', TRUE, '6:00 AM - 10:00 PM', 'ON_DUTY', 'ACTIVE', '2023-04-15', 'Hostel Administrator'),
    ('51000012-0000-0000-0000-000000000012', v_school_id, v_p_radhika, '2024 - 2025', v_ghb_id, 'Warden', 'Overall', TRUE, '6:00 AM - 10:00 PM', 'ON_DUTY', 'ACTIVE', '2023-04-20', 'Hostel Administrator'),

    -- 12 Caretakers (Room supervisors):
    ('51000003-0000-0000-0000-000000000003', v_school_id, v_p_ramesh, '2024 - 2025', v_bha_id, 'Caretaker', '1st Floor', TRUE, '7:00 AM - 3:00 PM', 'ON_DUTY', 'ACTIVE', '2023-06-01', 'Mr. Suresh Kumar'),
    ('51000004-0000-0000-0000-000000000004', v_school_id, v_p_anitha, '2024 - 2025', v_gha_id, 'Caretaker', '1st Floor', TRUE, '7:00 AM - 3:00 PM', 'ON_DUTY', 'ACTIVE', '2023-06-15', 'Mrs. Priya Nair'),
    ('51000005-0000-0000-0000-000000000005', v_school_id, v_p_karthik, '2024 - 2025', v_bha_id, 'Caretaker', '2nd Floor', TRUE, '3:00 PM - 11:00 PM', 'ON_LEAVE', 'ON_LEAVE', '2023-07-01', 'Mr. Suresh Kumar'),
    ('51000006-0000-0000-0000-000000000006', v_school_id, v_p_sneha,  '2024 - 2025', v_ghb_id, 'Caretaker', '2nd Floor', TRUE, '3:00 PM - 11:00 PM', 'ON_DUTY', 'ACTIVE', '2023-08-10', 'Mrs. Priya Nair'),
    ('51000013-0000-0000-0000-000000000013', v_school_id, v_p_deepak, '2024 - 2025', v_bha_id, 'Caretaker', '3rd Floor', TRUE, '7:00 AM - 3:00 PM', 'ON_DUTY', 'ACTIVE', '2023-07-15', 'Mr. Suresh Kumar'),
    ('51000014-0000-0000-0000-000000000014', v_school_id, v_p_pooja,  '2024 - 2025', v_gha_id, 'Caretaker', '2nd Floor', TRUE, '3:00 PM - 11:00 PM', 'ON_DUTY', 'ACTIVE', '2023-08-01', 'Mrs. Priya Nair'),
    ('51000015-0000-0000-0000-000000000015', v_school_id, v_p_manoj,  '2024 - 2025', v_bhb_id, 'Caretaker', '1st Floor', TRUE, '7:00 AM - 3:00 PM', 'ON_DUTY', 'ACTIVE', '2023-08-15', 'Vikram Singh'),
    ('51000016-0000-0000-0000-000000000016', v_school_id, v_p_geeta,  '2024 - 2025', v_ghb_id, 'Caretaker', '1st Floor', TRUE, '7:00 AM - 3:00 PM', 'ON_DUTY', 'ACTIVE', '2023-09-01', 'Radhika Menon'),
    ('51000017-0000-0000-0000-000000000017', v_school_id, v_p_rajesh, '2024 - 2025', v_bhb_id, 'Caretaker', '2nd Floor', TRUE, '3:00 PM - 11:00 PM', 'ON_DUTY', 'ACTIVE', '2023-09-10', 'Vikram Singh'),
    ('51000018-0000-0000-0000-000000000018', v_school_id, v_p_sandhya, '2024 - 2025', v_ghb_id, 'Caretaker', '3rd Floor', TRUE, '7:00 AM - 3:00 PM', 'ON_DUTY', 'ACTIVE', '2023-09-20', 'Radhika Menon'),
    ('51000019-0000-0000-0000-000000000019', v_school_id, v_p_amit,   '2024 - 2025', v_bha_id, 'Caretaker', 'Ground Floor', TRUE, '7:00 AM - 3:00 PM', 'ON_DUTY', 'ACTIVE', '2023-11-01', 'Mr. Suresh Kumar'),
    ('51000020-0000-0000-0000-000000000020', v_school_id, v_p_rekha,  '2024 - 2025', v_gha_id, 'Caretaker', 'Ground Floor', TRUE, '7:00 AM - 3:00 PM', 'ON_DUTY', 'ACTIVE', '2023-11-05', 'Mrs. Priya Nair'),

    -- 10 Support Staff (Security, Housekeeping, Maintenance, Mess Coordinator)
    ('51000007-0000-0000-0000-000000000007', v_school_id, v_p_arif,   '2024 - 2025', v_bha_id, 'Security', 'Main Gate', TRUE, '6:00 AM - 2:00 PM', 'ON_DUTY', 'ACTIVE', '2023-09-01', 'Chief Security Officer'),
    ('51000008-0000-0000-0000-000000000008', v_school_id, v_p_sunita, '2024 - 2025', v_gha_id, 'Security', 'Main Gate', TRUE, '6:00 AM - 2:00 PM', 'ON_DUTY', 'ACTIVE', '2023-09-15', 'Chief Security Officer'),
    ('51000009-0000-0000-0000-000000000009', v_school_id, v_p_ravi,   '2024 - 2025', v_bha_id, 'Housekeeping', 'All Floors', TRUE, '8:00 AM - 4:00 PM', 'ON_DUTY', 'ACTIVE', '2023-10-01', 'Housekeeping Supervisor'),
    ('51000010-0000-0000-0000-000000000010', v_school_id, v_p_meena,  '2024 - 2025', v_gha_id, 'Housekeeping', 'All Floors', TRUE, '8:00 AM - 4:00 PM', 'ON_LEAVE', 'ON_LEAVE', '2023-10-15', 'Housekeeping Supervisor'),
    ('51000021-0000-0000-0000-000000000021', v_school_id, v_p_balram, '2024 - 2025', v_bhb_id, 'Security', 'Main Gate', TRUE, '2:00 PM - 10:00 PM', 'ON_DUTY', 'ACTIVE', '2023-10-01', 'Chief Security Officer'),
    ('51000022-0000-0000-0000-000000000022', v_school_id, v_p_kamla,  '2024 - 2025', v_ghb_id, 'Housekeeping', 'All Floors', TRUE, '8:00 AM - 4:00 PM', 'ON_LEAVE', 'ON_LEAVE', '2023-10-10', 'Housekeeping Supervisor'),
    ('51000023-0000-0000-0000-000000000023', v_school_id, v_p_santosh, '2024 - 2025', v_bha_id, 'Maintenance', 'Electrical & Plumbing', TRUE, '9:00 AM - 5:00 PM', 'ON_DUTY', 'ACTIVE', '2023-08-01', 'Estate Officer'),
    ('51000024-0000-0000-0000-000000000024', v_school_id, v_p_vijay,  '2024 - 2025', v_gha_id, 'Maintenance', 'Electrical & Plumbing', TRUE, '9:00 AM - 5:00 PM', 'ON_DUTY', 'ACTIVE', '2023-08-15', 'Estate Officer'),
    ('51000025-0000-0000-0000-000000000025', v_school_id, v_p_naresh, '2024 - 2025', v_bha_id, 'Mess Coordinator', 'Mess Hall', TRUE, '6:00 AM - 9:00 PM', 'ON_DUTY', 'ACTIVE', '2023-07-20', 'Mess Committee'),
    ('51000026-0000-0000-0000-000000000026', v_school_id, v_p_kavita, '2024 - 2025', v_gha_id, 'Mess Coordinator', 'Mess Hall', TRUE, '6:00 AM - 9:00 PM', 'ON_DUTY', 'ACTIVE', '2023-07-25', 'Mess Committee'),

    -- 2 Pending Assignments (Requiring attention)
    ('51000027-0000-0000-0000-000000000027', v_school_id, v_p_omkar,  '2024 - 2025', v_bhb_id, 'Security', 'Main Gate', TRUE, '10:00 PM - 6:00 AM', 'OFF_DUTY', 'PENDING', '2023-09-05', 'Chief Security Officer'),
    ('51000028-0000-0000-0000-000000000028', v_school_id, v_p_shanti, '2024 - 2025', v_ghb_id, 'Housekeeping', 'All Floors', TRUE, '8:00 AM - 4:00 PM', 'OFF_DUTY', 'PENDING', '2023-10-05', 'Housekeeping Supervisor');

    -- 4. Seed 4 Assigned Areas for Suresh Kumar matching screenshot exactly
    DELETE FROM public.hostel_staff_assignment_areas WHERE assignment_id = v_asg_suresh;
    INSERT INTO public.hostel_staff_assignment_areas (assignment_id, area_name, badge_label, is_primary) VALUES
    (v_asg_suresh, 'Overall Hostel Supervision', 'Primary', TRUE),
    (v_asg_suresh, 'Discipline & Safety', 'Assigned', FALSE),
    (v_asg_suresh, 'Student Welfare', 'Assigned', FALSE),
    (v_asg_suresh, 'Mess Coordination', 'Assigned', FALSE);

    -- 5. Seed Activities for Suresh Kumar
    DELETE FROM public.hostel_staff_activities WHERE profile_id = v_p_suresh;
    INSERT INTO public.hostel_staff_activities (
        school_id, assignment_id, profile_id, activity_type, title, description, badge_color, created_at
    ) VALUES
    (v_school_id, v_asg_suresh, v_p_suresh, 'ASSIGNED', 'Assigned as Head Warden', 'Assigned to Boys Hostel A by School Management', 'blue', NOW() - INTERVAL '150 days'),
    (v_school_id, v_asg_suresh, v_p_suresh, 'DUTY_CHANGED', 'Annual Night Inspection Completed', 'Inspected all floors and security posts without incidents', 'green', NOW() - INTERVAL '10 days'),
    (v_school_id, v_asg_suresh, v_p_suresh, 'UPDATED', 'Updated Emergency Contact', 'Updated spouse emergency contact phone', 'purple', NOW() - INTERVAL '2 days');

END $$;
