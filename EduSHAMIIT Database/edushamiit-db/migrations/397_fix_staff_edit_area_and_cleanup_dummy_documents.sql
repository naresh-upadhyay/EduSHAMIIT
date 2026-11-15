-- Migration 397: Fix Staff Assignment Editing, Sync Assigned Area to Assignment Areas, and Clean Up Dummy Seed Documents
-- Author: Antigravity Team
-- Date: 2026-11-02

-- 1. Clean up dummy placeholder documents seeded by earlier migrations
DELETE FROM public.hostel_staff_documents
WHERE file_url LIKE 'https://documents.edushamiit.edu/hostel_staff/%'
   OR file_url LIKE 'https://documents.edushamiit.edu/staff/%';

-- 2. Update fn_hostel_update_staff_assignment with safe actor FK handling and automatic assigned_area_text sync
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
        -- Synchronize assigned_area_text with primary area in hostel_staff_assignment_areas
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

    -- Log activity
    INSERT INTO public.hostel_staff_activities (
        school_id, assignment_id, profile_id, activity_type, title, description,
        badge_color, performed_by, performed_by_name
    ) VALUES (
        p_school_id, v_assignment_id, v_profile_id, 'UPDATED',
        'Assignment Details Updated',
        'Updated duty details and assigned area to ' || COALESCE(v_assigned_area_text, 'updated area'),
        'purple', v_actor_profile_id, COALESCE(v_user_name, 'Hostel Administrator')
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Assignment updated successfully'
    );
END;
$$;

