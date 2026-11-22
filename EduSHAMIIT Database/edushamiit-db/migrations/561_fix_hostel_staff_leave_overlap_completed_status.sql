-- Migration 561: Fix Hostel Staff Leave Overlap Check to Include COMPLETED Status
-- Author: Antigravity Team

-- 1. Ensure Suresh Kumar seed leave is accurately recorded as 3.0 days (02 Nov 2026 - 04 Nov 2026)
UPDATE public.hostel_staff_leaves
SET start_date = '2026-11-02',
    end_date = '2026-11-04',
    days_count = 3.0,
    status = 'COMPLETED'
WHERE id = 'fd0ec277-9f56-42d1-b681-9794af510a01';

-- 2. Update fn_hostel_record_staff_leave to include 'COMPLETED' in overlap prevention check
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
