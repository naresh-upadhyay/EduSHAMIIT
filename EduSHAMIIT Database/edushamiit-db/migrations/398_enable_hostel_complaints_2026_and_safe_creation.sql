-- ============================================================================
-- Migration: 398_enable_hostel_complaints_2026_and_safe_creation.sql
-- Description: Ensures Hostel Complaints System is active, seeds 2026-2027 records,
--              and updates fn_hostel_complaints_create for robust cross-year and profile creation.
-- ============================================================================

-- 1. Ensure schema_migrations has 369, 370, 397, 398
INSERT INTO public.schema_migrations (version) VALUES 
    ('369_hostel_complaints_management_system.sql'),
    ('370_seed_hostel_complaints_data.sql'),
    ('397_fix_staff_edit_area_and_cleanup_dummy_documents.sql'),
    ('398_enable_hostel_complaints_2026_and_safe_creation.sql')
ON CONFLICT (version) DO NOTHING;

-- 2. Update fn_hostel_complaints_create to default to '2026 - 2027' and protect against missing reporter profiles
CREATE OR REPLACE FUNCTION public.fn_hostel_complaints_create(
    p_school_id UUID,
    p_user_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_complaint_id UUID := gen_random_uuid();
    v_complaint_number VARCHAR(50);
    v_next_num INT;
    v_year_str VARCHAR(10) := TO_CHAR(CURRENT_DATE, 'YYYY');
    v_academic_year VARCHAR(50) := COALESCE(p_payload->>'academic_year', '2026 - 2027');
    v_title VARCHAR(255) := TRIM(COALESCE(p_payload->>'title', ''));
    v_description TEXT := TRIM(COALESCE(p_payload->>'description', ''));
    v_category VARCHAR(100) := TRIM(COALESCE(p_payload->>'category', 'Other'));
    v_subcategory VARCHAR(100) := p_payload->>'subcategory';
    v_priority VARCHAR(20) := UPPER(COALESCE(p_payload->>'priority', 'MEDIUM'));
    v_hostel_id UUID := (p_payload->>'hostel_id')::UUID;
    v_hostel_name VARCHAR(150) := p_payload->>'hostel_name';
    v_building_id UUID := (p_payload->>'building_id')::UUID;
    v_building_name VARCHAR(150) := p_payload->>'building_name';
    v_floor_id UUID := (p_payload->>'floor_id')::UUID;
    v_floor_name VARCHAR(100) := p_payload->>'floor_name';
    v_room_id UUID := (p_payload->>'room_id')::UUID;
    v_room_number VARCHAR(50) := p_payload->>'room_number';
    v_bed_id UUID := (p_payload->>'bed_id')::UUID;
    v_bed_code VARCHAR(50) := p_payload->>'bed_code';
    v_facility_type VARCHAR(100) := COALESCE(p_payload->>'facility_type', 'Room');
    v_equipment_id UUID := (p_payload->>'equipment_id')::UUID;
    v_equipment_name VARCHAR(150) := p_payload->>'equipment_name';
    v_location_text VARCHAR(255) := p_payload->>'location_text';
    v_room_entry_permission BOOLEAN := COALESCE((p_payload->>'room_entry_permission')::BOOLEAN, TRUE);
    v_preferred_time VARCHAR(100) := COALESCE(p_payload->>'preferred_visit_time_text', p_payload->>'preferred_visit_time');
    v_thumbnail_url VARCHAR(500) := p_payload->>'thumbnail_url';
    v_attachments JSONB := COALESCE(p_payload->'attachments', '[]'::JSONB);
    v_reported_by_id UUID := COALESCE((p_payload->>'reported_by_user_id')::UUID, p_user_id);
    v_reporter_name VARCHAR(150);
    v_reporter_class VARCHAR(100);
    v_reporter_phone VARCHAR(50);
    v_reporter_email VARCHAR(150);
    v_reporter_avatar VARCHAR(500);
    v_reporter_role VARCHAR(50) := 'Student';
    v_duplicate_id UUID;
    v_res_minutes INT := 1440;
    v_resp_minutes INT := 240;
    v_response_due TIMESTAMPTZ;
    v_resolution_due TIMESTAMPTZ;
BEGIN
    IF v_title = '' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Complaint title is required');
    END IF;
    IF v_description = '' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Complaint description is required');
    END IF;

    -- Lookup reporter profile safely
    SELECT 
        COALESCE(full_name, 'Hostel Resident'),
        COALESCE(phone, ''),
        COALESCE(email, ''),
        COALESCE(avatar_url, ''),
        COALESCE(role, 'Student')
    INTO 
        v_reporter_name,
        v_reporter_phone,
        v_reporter_email,
        v_reporter_avatar,
        v_reporter_role
    FROM public.profiles
    WHERE id = v_reported_by_id;

    -- Fallback to first available profile if v_reported_by_id not found in profiles to prevent FK failure
    IF NOT FOUND OR v_reported_by_id IS NULL THEN
        SELECT id, COALESCE(full_name, 'Hostel Resident'), COALESCE(role, 'Student')
        INTO v_reported_by_id, v_reporter_name, v_reporter_role
        FROM public.profiles
        WHERE school_id = p_school_id OR school_id IS NULL
        LIMIT 1;
    END IF;

    IF v_reporter_name IS NULL OR TRIM(v_reporter_name) = '' THEN
        v_reporter_name := COALESCE(p_payload->>'reported_by_name', 'Hostel Resident');
    END IF;
    v_reporter_class := COALESCE(p_payload->>'reported_by_class', 'Class 10 A');

    -- Auto-fill hostel / building names if IDs provided
    IF v_hostel_id IS NOT NULL AND (v_hostel_name IS NULL OR v_hostel_name = '') THEN
        SELECT hostel_name INTO v_hostel_name FROM public.hostel_buildings WHERE id = v_hostel_id;
    END IF;
    IF v_room_id IS NOT NULL AND (v_room_number IS NULL OR v_room_number = '') THEN
        SELECT room_number INTO v_room_number FROM public.hostel_rooms WHERE id = v_room_id;
    END IF;

    -- Duplicate check: check if an identical open complaint exists for same room + equipment + category
    IF v_room_id IS NOT NULL AND v_equipment_name IS NOT NULL AND v_equipment_name != '' THEN
        SELECT id INTO v_duplicate_id
        FROM public.hostel_complaints
        WHERE school_id = p_school_id
          AND room_id = v_room_id
          AND equipment_name = v_equipment_name
          AND category = v_category
          AND status IN ('NEW', 'ACTIVE', 'IN_PROGRESS')
          AND deleted_at IS NULL
        LIMIT 1;

        IF v_duplicate_id IS NOT NULL AND (p_payload->>'force_create')::BOOLEAN IS NOT TRUE THEN
            RETURN jsonb_build_object(
                'success', false,
                'is_duplicate', true,
                'duplicate_id', v_duplicate_id,
                'message', 'An active complaint already exists for ' || v_equipment_name || ' in Room ' || COALESCE(v_room_number, '') || '. Provide confirmation to submit duplicate.'
            );
        END IF;
    END IF;

    -- Calculate SLA deadlines based on Priority
    CASE v_priority
        WHEN 'CRITICAL' THEN
            v_resp_minutes := 15;
            v_res_minutes := 120;
        WHEN 'URGENT' THEN
            v_resp_minutes := 30;
            v_res_minutes := 240;
        WHEN 'HIGH' THEN
            v_resp_minutes := 120;
            v_res_minutes := 720;
        WHEN 'MEDIUM' THEN
            v_resp_minutes := 240;
            v_res_minutes := 1440;
        ELSE
            v_resp_minutes := 480;
            v_res_minutes := 4320;
    END CASE;

    v_response_due := NOW() + (v_resp_minutes || ' minutes')::INTERVAL;
    v_resolution_due := NOW() + (v_res_minutes || ' minutes')::INTERVAL;

    -- Generate sequential human-readable Complaint Number HC-YYYY-XXXX
    SELECT COUNT(*) + 1 INTO v_next_num
    FROM public.hostel_complaints
    WHERE school_id = p_school_id;

    v_complaint_number := 'HC-' || v_year_str || '-' || LPAD(v_next_num::TEXT, 3, '0');

    -- Insert Complaint Record
    INSERT INTO public.hostel_complaints (
        id,
        school_id,
        complaint_number,
        academic_year,
        title,
        description,
        category,
        subcategory,
        priority,
        status,
        reported_by_user_id,
        reported_by_name,
        reported_by_role,
        reported_by_class,
        reported_by_phone,
        reported_by_email,
        reported_by_avatar,
        hostel_id,
        hostel_name,
        building_id,
        building_name,
        floor_id,
        floor_name,
        room_id,
        room_number,
        bed_id,
        bed_code,
        facility_type,
        equipment_id,
        equipment_name,
        location_text,
        source,
        response_due_at,
        resolution_due_at,
        preferred_visit_time_text,
        room_entry_permission,
        thumbnail_url,
        attachments,
        created_by,
        created_by_name
    ) VALUES (
        v_complaint_id,
        p_school_id,
        v_complaint_number,
        v_academic_year,
        v_title,
        v_description,
        v_category,
        v_subcategory,
        v_priority,
        'NEW',
        v_reported_by_id,
        v_reporter_name,
        v_reporter_role,
        v_reporter_class,
        v_reporter_phone,
        v_reporter_email,
        v_reporter_avatar,
        v_hostel_id,
        v_hostel_name,
        v_building_id,
        v_building_name,
        v_floor_id,
        v_floor_name,
        v_room_id,
        v_room_number,
        v_bed_id,
        v_bed_code,
        v_facility_type,
        v_equipment_id,
        v_equipment_name,
        COALESCE(v_location_text, v_hostel_name || ', ' || v_floor_name || ', Room ' || v_room_number),
        COALESCE(p_payload->>'source', 'STUDENT_PORTAL'),
        v_response_due,
        v_resolution_due,
        v_preferred_time,
        v_room_entry_permission,
        v_thumbnail_url,
        v_attachments,
        p_user_id,
        v_reporter_name
    );

    -- Log Timeline Activity
    INSERT INTO public.hostel_complaint_timeline (
        school_id,
        complaint_id,
        activity_type,
        title,
        description,
        performed_by_id,
        performed_by_name,
        performed_by_role
    ) VALUES (
        p_school_id,
        v_complaint_id,
        'CREATED',
        'Complaint Registered',
        'Complaint submitted: ' || v_title,
        p_user_id,
        v_reporter_name,
        v_reporter_role
    );

    RETURN jsonb_build_object(
        'success', true,
        'id', v_complaint_id,
        'complaint_number', v_complaint_number,
        'message', 'Complaint registered successfully with ID ' || v_complaint_number
    );
END;
$$;

