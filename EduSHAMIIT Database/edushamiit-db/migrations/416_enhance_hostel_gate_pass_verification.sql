-- ============================================================================
-- Migration 416: Enhance Hostel Gate Pass Verification with Resilient Tokens,
-- IST Timezone formatting, and Security Clearance Actions
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_hostel_leave_outing_verify_gatepass(
    p_school_id UUID,
    p_identifier VARCHAR
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_clean_id VARCHAR;
    v_pass RECORD;
    v_req RECORD;
    v_prof RECORD;
    v_validity_status VARCHAR(30);
    v_is_valid BOOLEAN := false;
    v_message TEXT;
    v_suggested_action VARCHAR(20) := 'EXIT';
BEGIN
    v_clean_id := TRIM(p_identifier);
    IF v_clean_id LIKE '%/%' THEN
        v_clean_id := split_part(v_clean_id, '/', array_length(string_to_array(v_clean_id, '/'), 1));
    END IF;

    SELECT * INTO v_pass
    FROM public.hostel_gate_passes
    WHERE school_id = p_school_id
      AND (
          verification_token = v_clean_id 
          OR UPPER(pass_number) = UPPER(v_clean_id)
          OR verification_token = p_identifier
          OR UPPER(pass_number) = UPPER(p_identifier)
          OR qr_reference = p_identifier
          OR qr_reference ILIKE '%' || v_clean_id || '%'
      )
    ORDER BY generated_at DESC
    LIMIT 1;

    IF v_pass IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'is_valid', false,
            'valid', false,
            'validity', 'INVALID',
            'message', 'No valid hostel gate pass found matching: ' || p_identifier
        );
    END IF;

    SELECT * INTO v_req FROM public.hostel_leave_outing_requests WHERE id = v_pass.request_id;
    SELECT * INTO v_prof FROM public.profiles WHERE id = v_pass.student_id;

    -- Evaluate pass validity
    IF v_pass.status = 'CANCELED' OR (v_req IS NOT NULL AND v_req.status = 'CANCELED') THEN
        v_validity_status := 'CANCELED';
        v_is_valid := false;
        v_message := 'Gate pass has been cancelled.';
    ELSIF v_pass.status = 'USED' OR (v_req IS NOT NULL AND v_req.status IN ('RETURNED', 'COMPLETED')) THEN
        v_validity_status := 'USED';
        v_is_valid := true;
        v_message := 'Student journey has been completed (Returned).';
        v_suggested_action := 'RETURN';
    ELSIF NOW() > v_pass.valid_until THEN
        v_validity_status := 'EXPIRED';
        v_is_valid := false;
        v_message := 'Gate pass validity window expired at ' || TO_CHAR(v_pass.valid_until AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM') || ' IST.';
        v_suggested_action := 'EXIT';
    ELSIF v_req IS NOT NULL AND v_req.status = 'EXITED' THEN
        v_validity_status := 'VALID';
        v_is_valid := true;
        v_message := 'Student is currently outside campus. Ready for return clearance.';
        v_suggested_action := 'RETURN';
    ELSIF v_req IS NOT NULL AND v_req.status = 'APPROVED' THEN
        v_validity_status := 'VALID';
        v_is_valid := true;
        v_message := 'Gate pass is active and verified. Ready for departure clearance.';
        v_suggested_action := 'EXIT';
    ELSIF NOW() < v_pass.valid_from THEN
        v_validity_status := 'VALID';
        v_is_valid := true;
        v_message := 'Scheduled gate pass starting at ' || TO_CHAR(v_pass.valid_from AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM') || ' IST.';
        v_suggested_action := 'EXIT';
    ELSE
        v_validity_status := 'VALID';
        v_is_valid := true;
        v_message := 'Gate pass is verified and ready for security processing.';
        v_suggested_action := 'EXIT';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'is_valid', v_is_valid,
        'valid', v_is_valid,
        'validity', v_validity_status,
        'message', v_message,
        'suggested_action', v_suggested_action,
        'gate_pass', jsonb_build_object(
            'id', v_pass.id,
            'pass_number', v_pass.pass_number,
            'verification_token', v_pass.verification_token,
            'qr_reference', v_pass.qr_reference,
            'status', v_pass.status,
            'valid_from', v_pass.valid_from,
            'valid_until', v_pass.valid_until,
            'valid_from_formatted', TO_CHAR(v_pass.valid_from AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM'),
            'valid_until_formatted', TO_CHAR(v_pass.valid_until AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM'),
            'used_exit_at', v_pass.used_exit_at,
            'used_return_at', v_pass.used_return_at,
            'used_exit_at_formatted', CASE WHEN v_pass.used_exit_at IS NOT NULL THEN TO_CHAR(v_pass.used_exit_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM') ELSE NULL END,
            'used_return_at_formatted', CASE WHEN v_pass.used_return_at IS NOT NULL THEN TO_CHAR(v_pass.used_return_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM') ELSE NULL END,
            'generated_by_name', v_pass.generated_by_name
        ),
        'student', jsonb_build_object(
            'id', v_prof.id,
            'full_name', COALESCE(v_prof.full_name, 'Resident Student'),
            'avatar_url', v_prof.avatar_url,
            'class', COALESCE(v_prof.class, '10 A'),
            'roll_number', COALESCE(v_prof.roll_number::TEXT, '0101'),
            'admission_number', COALESCE(v_prof.admission_number, 'ADM-2024-001'),
            'father_name', v_prof.father_name,
            'father_phone', COALESCE(v_prof.father_phone, v_prof.phone, v_prof.emergency_contact_phone),
            'parent_phone', COALESCE(v_prof.father_phone, v_prof.phone, v_prof.emergency_contact_phone),
            'hostel_name', COALESCE(v_req.building_name, 'Hostel'),
            'room_number', COALESCE(v_req.room_number, '-')
        ),
        'request', jsonb_build_object(
            'id', v_req.id,
            'request_number', v_req.request_number,
            'request_type', v_req.request_type,
            'destination', v_req.destination,
            'reason', v_req.reason,
            'start_at', v_req.start_at,
            'expected_return_at', v_req.expected_return_at,
            'start_at_formatted', TO_CHAR(v_req.start_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM'),
            'expected_return_at_formatted', TO_CHAR(v_req.expected_return_at AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY, HH12:MI AM'),
            'status', v_req.status,
            'hostel_name', v_req.building_name,
            'room_number', v_req.room_number
        )
    );
END;
$$;
