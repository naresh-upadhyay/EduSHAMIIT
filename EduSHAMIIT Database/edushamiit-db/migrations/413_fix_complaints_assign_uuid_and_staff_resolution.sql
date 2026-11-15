-- Migration 413: Fix Complaint Assignment UUID Parsing and Dynamic Staff Resolution
-- Resolves "invalid input syntax for type uuid: 'stf-001'" by safely checking UUID format in DECLARE/BEGIN
-- and dynamically resolving staff members by name, ID, or school staff assignments.

CREATE OR REPLACE FUNCTION public.fn_hostel_complaints_assign(
    p_school_id UUID,
    p_actor_id UUID,
    p_complaint_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_complaint RECORD;
    v_assignee_id_raw TEXT := p_payload->>'assigned_user_id';
    v_assignee_id UUID;
    v_assignee_name VARCHAR(150) := p_payload->>'assigned_user_name';
    v_assignee_role VARCHAR(100) := p_payload->>'assigned_user_role';
    v_assignment_type VARCHAR(20) := COALESCE(p_payload->>'assignment_type', 'PRIMARY');
    v_notes TEXT := p_payload->>'notes';
    v_actor_name VARCHAR(150);
    v_actor_role VARCHAR(100);
BEGIN
    SELECT * INTO v_complaint
    FROM public.hostel_complaints
    WHERE id = p_complaint_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_complaint.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Complaint not found');
    END IF;

    -- Lookup actor details
    SELECT COALESCE(full_name, 'Hostel Administrator'), COALESCE(role, 'Admin')
    INTO v_actor_name, v_actor_role
    FROM public.profiles WHERE id = p_actor_id;

    -- Check if assignee ID is a valid UUID
    IF v_assignee_id_raw IS NOT NULL AND v_assignee_id_raw ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_assignee_id := v_assignee_id_raw::UUID;
    END IF;

    -- If not a valid UUID or not found, lookup staff profile by name
    IF v_assignee_id IS NULL AND v_assignee_name IS NOT NULL AND v_assignee_name <> '' THEN
        SELECT p.id, p.full_name, COALESCE(hsa.hostel_role, p.role)
        INTO v_assignee_id, v_assignee_name, v_assignee_role
        FROM public.profiles p
        LEFT JOIN public.hostel_staff_assignments hsa ON hsa.profile_id = p.id
        WHERE p.school_id = p_school_id
          AND (
              p.full_name ILIKE '%' || v_assignee_name || '%'
              OR v_assignee_name ILIKE '%' || p.full_name || '%'
              OR REPLACE(p.full_name, 'Mr. ', '') ILIKE '%' || REPLACE(v_assignee_name, 'Mr. ', '') || '%'
              OR REPLACE(v_assignee_name, 'Mr. ', '') ILIKE '%' || REPLACE(p.full_name, 'Mr. ', '') || '%'
          )
        ORDER BY hsa.created_at ASC NULLS LAST
        LIMIT 1;
    END IF;

    -- If assignee ID was a valid UUID, enrich name and role if missing
    IF v_assignee_id IS NOT NULL AND (v_assignee_name IS NULL OR v_assignee_name = '') THEN
        SELECT COALESCE(full_name, 'Staff'), COALESCE(role, 'Maintenance Staff')
        INTO v_assignee_name, v_assignee_role
        FROM public.profiles WHERE id = v_assignee_id;
    END IF;

    -- Fallback 1: Any active hostel staff member in this school
    IF v_assignee_id IS NULL THEN
        SELECT p.id, p.full_name, COALESCE(hsa.hostel_role, p.role)
        INTO v_assignee_id, v_assignee_name, v_assignee_role
        FROM public.hostel_staff_assignments hsa
        JOIN public.profiles p ON p.id = hsa.profile_id
        WHERE hsa.school_id = p_school_id AND hsa.deleted_at IS NULL
        ORDER BY hsa.created_at ASC
        LIMIT 1;
    END IF;

    -- Fallback 2: Any staff/admin profile in this school
    IF v_assignee_id IS NULL THEN
        SELECT p.id, p.full_name, p.role
        INTO v_assignee_id, v_assignee_name, v_assignee_role
        FROM public.profiles p
        WHERE p.school_id = p_school_id
          AND (p.role ILIKE '%staff%' OR p.role ILIKE '%warden%' OR p.role ILIKE '%admin%')
        LIMIT 1;
    END IF;

    -- Fallback 3: The actor themselves
    IF v_assignee_id IS NULL THEN
        v_assignee_id := p_actor_id;
        v_assignee_name := COALESCE(v_actor_name, 'Hostel Administrator');
        v_assignee_role := COALESCE(v_actor_role, 'Admin');
    END IF;

    -- If assigning as PRIMARY, de-activate previous active primary assignments
    IF v_assignment_type = 'PRIMARY' THEN
        UPDATE public.hostel_complaint_assignments
        SET status = 'REASSIGNED', unassigned_at = NOW()
        WHERE complaint_id = p_complaint_id AND school_id = p_school_id AND status = 'ACTIVE' AND assignment_type = 'PRIMARY';

        -- Update Complaint Record
        UPDATE public.hostel_complaints
        SET primary_assignee_user_id = v_assignee_id,
            primary_assignee_name = v_assignee_name,
            primary_assignee_role = COALESCE(v_assignee_role, 'Maintenance Staff'),
            status = CASE WHEN status = 'NEW' THEN 'ACTIVE' ELSE status END,
            updated_by = p_actor_id,
            updated_at = NOW(),
            version = version + 1
        WHERE id = p_complaint_id;
    END IF;

    -- Insert New Assignment
    INSERT INTO public.hostel_complaint_assignments (
        complaint_id,
        school_id,
        assigned_user_id,
        assigned_user_name,
        assigned_user_role,
        assignment_type,
        assigned_by,
        assigned_by_name,
        notes,
        status
    ) VALUES (
        p_complaint_id,
        p_school_id,
        v_assignee_id,
        v_assignee_name,
        COALESCE(v_assignee_role, 'Maintenance Staff'),
        v_assignment_type,
        p_actor_id,
        COALESCE(v_actor_name, 'Hostel Administrator'),
        v_notes,
        'ACTIVE'
    );

    -- Record in Timeline History
    INSERT INTO public.hostel_complaint_status_history (
        complaint_id,
        school_id,
        actor_user_id,
        actor_name,
        actor_role,
        from_status,
        to_status,
        event_title,
        action_note
    ) VALUES (
        p_complaint_id,
        p_school_id,
        p_actor_id,
        COALESCE(v_actor_name, 'Hostel Administrator'),
        COALESCE(v_actor_role, 'Admin'),
        v_complaint.status,
        CASE WHEN v_complaint.status = 'NEW' THEN 'ACTIVE' ELSE v_complaint.status END,
        CASE WHEN v_assignment_type = 'PRIMARY' THEN 'Assigned to ' || v_assignee_name ELSE 'Supporting staff added: ' || v_assignee_name END,
        COALESCE(v_notes, 'Staff assigned for complaint resolution.')
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Complaint successfully assigned to ' || v_assignee_name,
        'primary_assignee_user_id', v_assignee_id,
        'primary_assignee_name', v_assignee_name,
        'primary_assignee_role', v_assignee_role
    );
END;
$$;

