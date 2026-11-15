-- Migration 396: Fix Staff Monthly Leaves, Deduplicate Existing Leaves, and Prevent Overlapping Leaves
-- Author: Antigravity Team
-- Date: 2026-11-02

-- 1. Deduplicate existing overlapping/duplicate staff leaves (preserving 1 record)
DELETE FROM public.hostel_staff_leaves a
USING public.hostel_staff_leaves b
WHERE a.id > b.id
  AND a.profile_id = b.profile_id
  AND a.start_date = b.start_date
  AND a.end_date = b.end_date;

-- Ensure Suresh Kumar has exactly 1 valid seed leave for 02 Nov 2026 - 04 Nov 2026
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.hostel_staff_leaves 
        WHERE profile_id = '41000001-0000-0000-0000-000000000001'
          AND start_date = '2026-11-02'
          AND end_date = '2026-11-04'
          AND deleted_at IS NULL
    ) THEN
        INSERT INTO public.hostel_staff_leaves (
            id, school_id, profile_id, assignment_id, leave_type,
            start_date, end_date, days_count, reason,
            status, substitute_staff_name, emergency_contact, approved_by_name
        ) VALUES (
            'fd0ec277-9f56-42d1-b681-9794af510a01',
            '11111111-1111-1111-1111-111111111111',
            '41000001-0000-0000-0000-000000000001',
            '51000001-0000-0000-0000-000000000001',
            'Casual Leave',
            '2026-11-02',
            '2026-11-04',
            3.0,
            'Personal family engagement with pre-approved backup coverage',
            'COMPLETED',
            'Rajesh Sharma (Backup Warden)',
            '+91 98765 43210',
            'Hostel Administrator'
        ) ON CONFLICT (id) DO NOTHING;
    END IF;
END $$;

-- 2. Update fn_hostel_get_staff_detail to accurately compute monthly leaves across all valid statuses (APPROVED, COMPLETED, ACTIVE, ON_LEAVE)
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
    v_documents JSONB := '[]'::JSONB;
    v_leaves JSONB := '[]'::JSONB;
    v_monthly_leaves NUMERIC := 0.0;
    v_active_leave RECORD;
BEGIN
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

    -- 3. Audit Activities
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
    LIMIT 20;

    -- 4. Staff Documents
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
            'verified_at', TO_CHAR(d.verified_at, 'DD Mon YYYY, HH12:MI AM'),
            'notes', d.notes,
            'created_at', TO_CHAR(d.created_at, 'DD Mon YYYY, HH12:MI AM'),
            'formatted_date', TO_CHAR(d.created_at, 'DD Mon YYYY')
        ) ORDER BY d.created_at DESC
    ), '[]'::JSONB) INTO v_documents
    FROM public.hostel_staff_documents d
    WHERE d.school_id = p_school_id
      AND (d.profile_id = v_profile.id OR (v_assignment.id IS NOT NULL AND d.assignment_id = v_assignment.id))
      AND d.deleted_at IS NULL;

    -- 5. Staff Leaves
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
            'created_at', TO_CHAR(l.created_at, 'DD Mon YYYY')
        ) ORDER BY l.start_date DESC
    ), '[]'::JSONB) INTO v_leaves
    FROM public.hostel_staff_leaves l
    WHERE l.school_id = p_school_id
      AND (l.profile_id = v_profile.id OR (v_assignment.id IS NOT NULL AND l.assignment_id = v_assignment.id))
      AND l.deleted_at IS NULL;

    -- Calculate total monthly leave days taken within current calendar month across all valid taken/active leave statuses
    SELECT COALESCE(SUM(l.days_count), 0.0) INTO v_monthly_leaves
    FROM public.hostel_staff_leaves l
    WHERE l.school_id = p_school_id
      AND (l.profile_id = v_profile.id OR (v_assignment.id IS NOT NULL AND l.assignment_id = v_assignment.id))
      AND l.status IN ('APPROVED', 'COMPLETED', 'ACTIVE', 'ON_LEAVE')
      AND l.start_date <= (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE
      AND l.end_date >= DATE_TRUNC('month', CURRENT_DATE)::DATE
      AND l.deleted_at IS NULL;

    -- Check if active leave exists right now
    SELECT * INTO v_active_leave
    FROM public.hostel_staff_leaves
    WHERE school_id = p_school_id
      AND (profile_id = v_profile.id OR (v_assignment.id IS NOT NULL AND assignment_id = v_assignment.id))
      AND status IN ('APPROVED', 'ACTIVE', 'ON_LEAVE')
      AND CURRENT_DATE BETWEEN start_date AND end_date
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
                WHEN v_assignment.assignment_status = 'ON_LEAVE' OR v_assignment.duty_status = 'ON_LEAVE' OR v_active_leave.id IS NOT NULL THEN 'On Leave'
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

-- 3. Update fn_hostel_record_staff_leave with strict date overlap validation & safe actor FK handling
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
    v_start_date := COALESCE((p_data->>'start_date')::DATE, CURRENT_DATE);
    v_end_date := COALESCE((p_data->>'end_date')::DATE, v_start_date);

    IF v_end_date < v_start_date THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'End date cannot be earlier than start date');
    END IF;

    -- Overlap prevention: verify that no active, approved, or completed leave exists for the same staff overlapping these dates
    IF EXISTS (
        SELECT 1 FROM public.hostel_staff_leaves
        WHERE school_id = p_school_id
          AND profile_id = v_profile_id
          AND status IN ('APPROVED', 'COMPLETED', 'ACTIVE', 'ON_LEAVE')
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

    -- Update assignment status to ON_LEAVE if current date falls within leave period
    IF CURRENT_DATE BETWEEN v_start_date AND v_end_date AND v_assignment_id IS NOT NULL THEN
        UPDATE public.hostel_staff_assignments
        SET assignment_status = 'ON_LEAVE',
            duty_status = 'ON_LEAVE',
            updated_at = NOW(),
            updated_by = v_actor_profile_id
        WHERE id = v_assignment_id;
    END IF;

    -- Audit Activity
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

-- 4. Update fn_hostel_upload_staff_document with safe actor FK handling
CREATE OR REPLACE FUNCTION public.fn_hostel_upload_staff_document(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_profile_id UUID;
    v_assignment_id UUID;
    v_doc_name TEXT;
    v_doc_type TEXT;
    v_file_url TEXT;
    v_size INT;
    v_status TEXT;
    v_notes TEXT;
    v_doc_id UUID;
    v_staff_name TEXT;
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
        RETURN jsonb_build_object('success', FALSE, 'message', 'Profile or Assignment ID is required');
    END IF;

    v_doc_name := COALESCE(NULLIF(TRIM(p_data->>'document_name'), ''), 'Staff Document');
    v_doc_type := COALESCE(NULLIF(TRIM(p_data->>'document_type'), ''), 'Other');
    v_file_url := COALESCE(NULLIF(TRIM(p_data->>'file_url'), ''), 'https://documents.edushamiit.edu/staff/' || v_doc_name);
    v_size := COALESCE((p_data->>'file_size_bytes')::INT, 102400);
    v_status := COALESCE(NULLIF(TRIM(p_data->>'verification_status'), ''), 'VERIFIED');
    v_notes := NULLIF(TRIM(p_data->>'notes'), '');

    IF p_user_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
        v_actor_profile_id := p_user_id;
    END IF;

    INSERT INTO public.hostel_staff_documents (
        school_id, profile_id, assignment_id, document_name, document_type,
        file_url, file_size_bytes, mime_type, verification_status,
        verified_by, verified_by_name, verified_at, notes, uploaded_by
    ) VALUES (
        p_school_id, v_profile_id, v_assignment_id, v_doc_name, v_doc_type,
        v_file_url, v_size, COALESCE(p_data->>'mime_type', 'application/pdf'), v_status,
        v_actor_profile_id, 'Hostel Administrator', NOW(), v_notes, v_actor_profile_id
    ) RETURNING id INTO v_doc_id;

    -- Audit Activity
    SELECT full_name INTO v_staff_name FROM public.profiles WHERE id = v_profile_id;
    INSERT INTO public.hostel_staff_activities (
        school_id, assignment_id, profile_id, activity_type,
        title, description, badge_color, performed_by, performed_by_name
    ) VALUES (
        p_school_id, v_assignment_id, v_profile_id, 'DOCUMENT_UPLOAD',
        'Document Uploaded',
        'Uploaded ' || v_doc_name || ' (' || v_status || ')',
        'green', v_actor_profile_id, 'Hostel Administrator'
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Staff document uploaded successfully',
        'data', jsonb_build_object('id', v_doc_id)
    );
END;
$$;
