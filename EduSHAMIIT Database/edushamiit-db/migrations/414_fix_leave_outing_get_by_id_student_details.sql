-- Migration 414: Fix Leave & Outing get_by_id student detail fields
-- Ensures student_name, student_id, student_avatar, admission_number, roll_number,
-- class_name, section_name, hostel_name, and bed_number are returned at top level of data.

CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_get_by_id(
    p_school_id UUID,
    p_request_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req RECORD;
    v_prof RECORD;
    v_gate_pass JSONB := NULL;
    v_approvals JSONB := '[]'::JSONB;
    v_movement_logs JSONB := '[]'::JSONB;
    v_timeline JSONB := '[]'::JSONB;
BEGIN
    SELECT * INTO v_req
    FROM public.hostel_leave_outing_requests
    WHERE id = p_request_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_req IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Leave/Outing request not found');
    END IF;

    SELECT * INTO v_prof FROM public.profiles WHERE id = v_req.student_id;

    -- Fetch Gate Pass if generated
    SELECT jsonb_build_object(
        'id', gp.id,
        'pass_number', gp.pass_number,
        'verification_token', gp.verification_token,
        'qr_reference', gp.qr_reference,
        'status', gp.status,
        'valid_from', gp.valid_from,
        'valid_until', gp.valid_until,
        'generated_by_name', gp.generated_by_name,
        'generated_at', gp.generated_at,
        'used_exit_at', gp.used_exit_at,
        'used_return_at', gp.used_return_at
    ) INTO v_gate_pass
    FROM public.hostel_gate_passes gp
    WHERE gp.request_id = v_req.id
    ORDER BY gp.created_at DESC LIMIT 1;

    -- Fetch Approval Steps
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', ap.id,
                'approval_step', ap.approval_step,
                'approver_name', ap.approver_name,
                'approver_role', ap.approver_role,
                'action', ap.action,
                'remarks', ap.remarks,
                'acted_at', ap.acted_at
            ) ORDER BY ap.approval_step ASC
        ),
        '[]'::JSONB
    ) INTO v_approvals
    FROM public.hostel_leave_outing_approvals ap
    WHERE ap.request_id = v_req.id;

    -- Fetch Movement Logs
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', ml.id,
                'movement_type', ml.movement_type,
                'movement_time', ml.movement_time,
                'formatted_time', TO_CHAR(ml.movement_time AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM'),
                'gate', ml.gate,
                'verified_by_name', ml.verified_by_name,
                'is_overdue', ml.is_overdue,
                'remarks', ml.remarks
            ) ORDER BY ml.movement_time ASC
        ),
        '[]'::JSONB
    ) INTO v_movement_logs
    FROM public.hostel_movement_logs ml
    WHERE ml.request_id = v_req.id;

    -- Build Unified Visual Timeline
    v_timeline := jsonb_build_array(
        jsonb_build_object(
            'event', 'REQUEST_CREATED',
            'title', 'Request Created',
            'timestamp', TO_CHAR(v_req.created_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM'),
            'actor', COALESCE(v_req.created_by_name, v_prof.full_name),
            'status', 'COMPLETED'
        )
    );

    IF v_req.approved_at IS NOT NULL THEN
        v_timeline := v_timeline || jsonb_build_object(
            'event', 'APPROVED',
            'title', 'Approved by ' || COALESCE(v_req.approved_by_name, 'Warden'),
            'timestamp', TO_CHAR(v_req.approved_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM'),
            'actor', v_req.approved_by_name,
            'remarks', v_req.approval_remarks,
            'status', 'COMPLETED'
        );
    ELSIF v_req.status = 'REJECTED' THEN
        v_timeline := v_timeline || jsonb_build_object(
            'event', 'REJECTED',
            'title', 'Request Rejected',
            'timestamp', TO_CHAR(v_req.updated_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM'),
            'actor', COALESCE(v_req.approved_by_name, 'Warden'),
            'remarks', v_req.rejection_reason,
            'status', 'FAILED'
        );
    END IF;

    IF v_gate_pass IS NOT NULL THEN
        v_timeline := v_timeline || jsonb_build_object(
            'event', 'GATE_PASS_GENERATED',
            'title', 'Gate Pass Generated (' || (v_gate_pass->>'pass_number') || ')',
            'timestamp', TO_CHAR((v_gate_pass->>'generated_at')::TIMESTAMPTZ AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM'),
            'actor', v_gate_pass->>'generated_by_name',
            'status', 'COMPLETED'
        );
    END IF;

    IF v_req.actual_exit_at IS NOT NULL THEN
        v_timeline := v_timeline || jsonb_build_object(
            'event', 'EXITED',
            'title', 'Exited via ' || COALESCE(v_req.exit_gate, 'Main Gate'),
            'timestamp', TO_CHAR(v_req.actual_exit_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM'),
            'actor', v_req.exit_verified_by_name,
            'remarks', v_req.exit_remarks,
            'status', 'COMPLETED'
        );
    END IF;

    IF v_req.actual_return_at IS NOT NULL THEN
        v_timeline := v_timeline || jsonb_build_object(
            'event', 'RETURNED',
            'title', 'Returned via ' || COALESCE(v_req.return_gate, 'Main Gate'),
            'timestamp', TO_CHAR(v_req.actual_return_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM'),
            'actor', v_req.return_verified_by_name,
            'remarks', v_req.return_remarks,
            'status', 'COMPLETED'
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'data', (
            jsonb_build_object(
                'id', v_req.id,
                'request_number', v_req.request_number,
                'academic_year', v_req.academic_year,
                'student_id', v_req.student_id,
                'student_name', COALESCE(v_prof.full_name, 'Student'),
                'student_avatar', v_prof.avatar_url,
                'admission_number', COALESCE(v_prof.admission_number, 'ADM-0101'),
                'roll_number', COALESCE(v_prof.roll_number, '0101'),
                'class_name', COALESCE(v_prof.class, '10 A'),
                'section_name', COALESCE(split_part(v_prof.class, ' ', 2), 'A'),
                'hostel_name', COALESCE(v_req.building_name, 'Hostel'),
                'room_number', v_req.room_number,
                'bed_number', COALESCE(v_req.bed_code, 'Bed 1'),
                'bed_code', v_req.bed_code,
                'request_type', v_req.request_type,
                'request_subtype', v_req.request_subtype,
                'reason', v_req.reason,
                'destination', v_req.destination,
                'start_at', v_req.start_at,
                'expected_return_at', v_req.expected_return_at,
                'from_date_formatted', TO_CHAR(v_req.start_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM'),
                'to_date_formatted', TO_CHAR(v_req.expected_return_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM'),
                'requested_on_formatted', TO_CHAR(v_req.created_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY'),
                'actual_exit_at', v_req.actual_exit_at,
                'actual_return_at', v_req.actual_return_at,
                'status', CASE WHEN v_req.status = 'EXITED' AND v_req.expected_return_at < NOW() THEN 'OVERDUE_RETURN' ELSE v_req.status END,
                'is_emergency', v_req.is_emergency,
                'building_name', v_req.building_name
            ) || jsonb_build_object(
                'guardian_name', COALESCE(v_req.guardian_name, v_prof.father_name),
                'guardian_phone', COALESCE(v_req.guardian_phone, v_prof.father_phone),
                'guardian_relationship', v_req.guardian_relationship,
                'guardian_confirmation_required', v_req.guardian_confirmation_required,
                'guardian_confirmed', v_req.guardian_confirmed,
                'accompanied_by', v_req.accompanied_by,
                'companion_name', v_req.companion_name,
                'companion_phone', v_req.companion_phone,
                'companion_relation', v_req.companion_relation,
                'transport_mode', v_req.transport_mode,
                'vehicle_number', v_req.vehicle_number,
                'pickup_person_name', v_req.pickup_person_name,
                'pickup_person_phone', v_req.pickup_person_phone,
                'destination_address', v_req.destination_address,
                'special_instructions', v_req.special_instructions,
                'rejection_reason', v_req.rejection_reason,
                'cancellation_reason', v_req.cancellation_reason,
                'approved_by_name', v_req.approved_by_name,
                'approved_at', v_req.approved_at,
                'approval_remarks', v_req.approval_remarks,
                'exit_gate', v_req.exit_gate,
                'exit_verified_by_name', v_req.exit_verified_by_name,
                'exit_remarks', v_req.exit_remarks,
                'return_gate', v_req.return_gate,
                'return_verified_by_name', v_req.return_verified_by_name,
                'return_remarks', v_req.return_remarks,
                'documents', v_req.documents,
                'internal_notes', v_req.internal_notes,
                'version', v_req.version,
                'created_by_name', v_req.created_by_name,
                'created_at', v_req.created_at,
                'pass_number', v_gate_pass->>'pass_number',
                'gate_pass_id', v_gate_pass->>'id',
                'gate_pass_status', v_gate_pass->>'status',
                'verification_token', v_gate_pass->>'verification_token',
                'student', jsonb_build_object(
                    'id', v_prof.id,
                    'full_name', v_prof.full_name,
                    'avatar_url', v_prof.avatar_url,
                    'class', COALESCE(v_prof.class, '10 A'),
                    'roll_number', v_prof.roll_number,
                    'admission_number', v_prof.admission_number,
                    'father_name', v_prof.father_name,
                    'father_phone', v_prof.father_phone,
                    'mother_name', v_prof.mother_name,
                    'mother_phone', v_prof.mother_phone,
                    'email', v_prof.email,
                    'blood_group', v_prof.blood_group
                ),
                'gate_pass', v_gate_pass,
                'approvals', v_approvals,
                'movement_logs', v_movement_logs,
                'timeline', v_timeline
            )
        )
    );
END;
$$;

