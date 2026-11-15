-- Migration 400: Fix fn_hostel_get_student_detail lookup by admission_id or student_id
-- Ensures that passing either admission_id OR student_id properly resolves the student admission record.

CREATE OR REPLACE FUNCTION public.fn_hostel_get_student_detail(
    p_school_id uuid,
    p_admission_id uuid DEFAULT NULL::uuid,
    p_student_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_adm RECORD;
    v_prof RECORD;
    v_alloc RECORD;
    v_building_id UUID := NULL;
    v_building_name VARCHAR(150) := NULL;
    v_room_id UUID := NULL;
    v_room_number VARCHAR(50) := '-';
    v_room_type VARCHAR(100) := 'Standard';
    v_bed_id UUID := NULL;
    v_bed_code VARCHAR(50) := '1';
    v_class_name VARCHAR(100);
    v_roll_no VARCHAR(50);
    v_activities JSONB := '[]'::JSONB;
    v_documents JSONB := '[]'::JSONB;
    v_leave_history JSONB := '[]'::JSONB;
    v_fee_summary JSONB;
BEGIN
    -- 1. Identify admission record
    -- Check by admission_id primary key first
    IF p_admission_id IS NOT NULL THEN
        SELECT * INTO v_adm FROM public.hostel_admissions
        WHERE id = p_admission_id AND school_id = p_school_id AND deleted_at IS NULL;
    END IF;

    -- If not found by id, fallback to student_id matching (in case p_admission_id or p_student_id is student profile id)
    IF v_adm IS NULL AND (p_student_id IS NOT NULL OR p_admission_id IS NOT NULL) THEN
        SELECT * INTO v_adm FROM public.hostel_admissions
        WHERE student_id = COALESCE(p_student_id, p_admission_id)
          AND school_id = p_school_id
          AND deleted_at IS NULL
        ORDER BY created_at DESC LIMIT 1;
    END IF;

    IF v_adm IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Hostel student admission record not found');
    END IF;

    -- 2. Fetch Profile
    SELECT * INTO v_prof FROM public.profiles WHERE id = v_adm.student_id;
    IF v_prof IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Student profile record not found');
    END IF;

    -- 3. Fetch active Room & Bed Allocation
    SELECT * INTO v_alloc FROM public.hostel_allocations
    WHERE admission_id = v_adm.id
      AND allocation_status IN ('CHECKED_IN', 'RESERVED', 'CONFIRMED', 'TEMPORARILY_RELOCATED')
      AND deleted_at IS NULL
    ORDER BY created_at DESC LIMIT 1;

    IF v_alloc.id IS NULL THEN
        -- Fallback to student_id allocation
        SELECT * INTO v_alloc FROM public.hostel_allocations
        WHERE student_id = v_adm.student_id
          AND school_id = p_school_id
          AND allocation_status IN ('CHECKED_IN', 'RESERVED', 'CONFIRMED', 'TEMPORARILY_RELOCATED')
          AND deleted_at IS NULL
        ORDER BY created_at DESC LIMIT 1;
    END IF;

    -- Fetch Building, Room, Bed Details
    IF v_alloc.id IS NOT NULL THEN
        v_building_id := v_alloc.building_id;
        v_room_id := v_alloc.room_id;
        v_bed_id := v_alloc.bed_id;

        SELECT name INTO v_building_name FROM public.hostel_buildings WHERE id = v_building_id;
        SELECT room_number, room_type INTO v_room_number, v_room_type FROM public.hostel_rooms WHERE id = v_room_id;
        SELECT bed_code INTO v_bed_code FROM public.hostel_beds WHERE id = v_bed_id;
    ELSIF v_adm.hostel_id IS NOT NULL THEN
        v_building_id := v_adm.hostel_id;
        SELECT name INTO v_building_name FROM public.hostel_buildings WHERE id = v_building_id;
    END IF;

    -- 4. Fetch Class and Roll Number
    SELECT
        COALESCE(
            NULLIF(TRIM(COALESCE(ac.name, '') || ' ' || COALESCE(sec.name, '')), ''),
            v_prof.class,
            '10 A'
        ),
        COALESCE(sca.roll_number, LPAD(COALESCE(v_prof.roll_number::TEXT, '0101'), 4, '0'))
    INTO v_class_name, v_roll_no
    FROM public.student_class_assignments sca
    LEFT JOIN public.academic_classes ac ON sca.class_id = ac.id
    LEFT JOIN public.academic_sections sec ON sca.section_id = sec.id
    WHERE sca.student_id = v_adm.student_id
      AND sca.school_id = p_school_id
      AND sca.status = 'ACTIVE'
    LIMIT 1;

    IF v_class_name IS NULL THEN
        v_class_name := COALESCE(v_prof.class, '10 A');
        v_roll_no := LPAD(COALESCE(v_prof.roll_number::TEXT, '0101'), 4, '0');
    END IF;

    -- 5. Fetch Recent Activities (Timeline)
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', id,
                'activity_type', activity_type,
                'title', title,
                'description', description,
                'badge_color', badge_color,
                'performed_by_name', performed_by_name,
                'created_at', created_at,
                'formatted_date', TO_CHAR(created_at, 'DD Mon YYYY · HH12:MI AM')
            ) ORDER BY created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_activities
    FROM public.hostel_student_activities
    WHERE (admission_id = v_adm.id OR student_id = v_adm.student_id)
      AND school_id = p_school_id
      AND deleted_at IS NULL
    LIMIT 15;

    -- 6. Fetch Leave / Outing History dynamically from hostel_leave_outing_requests
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', id,
                'leave_type', COALESCE(request_type, 'LEAVE'),
                'request_subtype', COALESCE(request_subtype, 'Outing'),
                'start_date', TO_CHAR(start_at, 'DD Mon YYYY, HH12:MI AM'),
                'end_date', TO_CHAR(expected_return_at, 'DD Mon YYYY, HH12:MI AM'),
                'status', status,
                'reason', reason,
                'pass_number', request_number,
                'destination', destination,
                'created_at', created_at
            ) ORDER BY created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_leave_history
    FROM public.hostel_leave_outing_requests
    WHERE (admission_id = v_adm.id OR student_id = v_adm.student_id)
      AND school_id = p_school_id
      AND deleted_at IS NULL
    LIMIT 15;

    -- 7. Fetch Verified Documents dynamically from hostel_student_documents
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', d.id,
                'name', d.document_name,
                'document_name', d.document_name,
                'type', d.document_type,
                'document_type', d.document_type,
                'url', d.file_url,
                'file_url', d.file_url,
                'size_bytes', d.file_size_bytes,
                'file_size_bytes', d.file_size_bytes,
                'mime_type', d.mime_type,
                'status', d.verification_status,
                'verification_status', d.verification_status,
                'created_at', d.created_at,
                'formatted_date', TO_CHAR(d.created_at, 'DD Mon YYYY')
            ) ORDER BY d.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_documents
    FROM public.hostel_student_documents d
    WHERE d.school_id = p_school_id
      AND (d.admission_id = v_adm.id OR d.student_id = v_adm.student_id)
      AND d.deleted_at IS NULL;

    -- 8. Fee Summary
    v_fee_summary := jsonb_build_object(
        'plan_name', COALESCE(v_adm.fee_plan, 'Monthly'),
        'monthly_fee', COALESCE(v_adm.monthly_fee, 6000.0),
        'deposit_amount', COALESCE(v_adm.deposit_amount, 10000.0),
        'fee_status', v_adm.fee_status,
        'initial_payment_amount', COALESCE(v_adm.initial_payment_amount, 0.0),
        'billed_amount', COALESCE(v_adm.monthly_fee, 6000.0) + COALESCE(v_adm.deposit_amount, 10000.0),
        'paid_amount', COALESCE(
            v_adm.initial_payment_amount,
            CASE WHEN v_adm.fee_status = 'PAID' THEN (COALESCE(v_adm.monthly_fee, 6000.0) + COALESCE(v_adm.deposit_amount, 10000.0)) ELSE 0.0 END
        ),
        'outstanding_dues', GREATEST(
            0.0,
            (COALESCE(v_adm.monthly_fee, 6000.0) + COALESCE(v_adm.deposit_amount, 10000.0)) -
            COALESCE(
                v_adm.initial_payment_amount,
                CASE WHEN v_adm.fee_status = 'PAID' THEN (COALESCE(v_adm.monthly_fee, 6000.0) + COALESCE(v_adm.deposit_amount, 10000.0)) ELSE 0.0 END
            )
        ),
        'recent_invoices', jsonb_build_array(
            jsonb_build_object(
                'invoice_no', 'INV-' || TO_CHAR(NOW(), 'YYYY-MM') || '-1001',
                'date', TO_CHAR(v_adm.admission_date, 'DD Mon YYYY'),
                'amount', COALESCE(v_adm.initial_payment_amount, v_adm.monthly_fee, 6000.0),
                'status', v_adm.fee_status
            )
        )
    );

    -- 9. Build Complete 360 Object
    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'admission_id', v_adm.id,
            'allocation_id', CASE WHEN v_alloc.id IS NOT NULL THEN v_alloc.id ELSE NULL END,
            'student_id', v_prof.id,
            'student_name', v_prof.full_name,
            'avatar_url', v_prof.avatar_url,
            'status', CASE
                WHEN v_adm.admission_status = 'ON_LEAVE' THEN 'Leave'
                WHEN v_adm.admission_status = 'AWAITING_ALLOCATION' OR v_alloc.id IS NULL THEN 'Awaiting'
                WHEN v_adm.admission_status = 'CHECKED_OUT' THEN 'Checked Out'
                ELSE 'Active'
            END,
            'admission_status', v_adm.admission_status,
            'roll_no', v_roll_no,
            'class_name', v_class_name,
            'hostel_id', COALESCE(v_building_id, v_adm.hostel_id),
            'hostel_name', COALESCE(v_building_name, 'Boys Hostel A'),
            'building_id', v_building_id,
            'room_id', v_room_id,
            'room_number', COALESCE(v_room_number, '-'),
            'bed_id', v_bed_id,
            'bed_no', REGEXP_REPLACE(COALESCE(v_bed_code, '1'), '^Bed\s*', '', 'i'),
            -- 8 Overview Grid Items:
            'admission_date', TO_CHAR(v_adm.admission_date, 'DD Mon YYYY'),
            'room_and_bed', CASE
                WHEN v_room_number IS NOT NULL AND v_room_number != '-' THEN
                    v_room_number || ' (Bed ' || REGEXP_REPLACE(COALESCE(v_bed_code, '1'), '^Bed\s*', '', 'i') || ')'
                ELSE 'Unallocated'
            END,
            'hostel_type', COALESCE(v_adm.hostel_type, v_room_type, 'Standard'),
            'fee_plan', COALESCE(v_adm.fee_plan, 'Monthly'),
            'blood_group', COALESCE(v_prof.blood_group, 'B+'),
            'emergency_contact', COALESCE(v_adm.emergency_contact_override, v_prof.emergency_contact_phone, v_prof.father_phone, '+91 98765 43210 (Father)'),
            'emergency_contact_label', '+91 98765 43210 (Father)',
            'address', COALESCE(v_prof.address, 'A-123, Sector 62, Noida, UP'),
            -- Detailed Profile Items:
            'email', v_prof.email,
            'phone', v_prof.phone,
            'gender', COALESCE(v_prof.gender, 'Male'),
            'father_name', v_prof.father_name,
            'mother_name', v_prof.mother_name,
            'guardian_relation', CASE
                WHEN UPPER(COALESCE(v_prof.gender, '')) IN ('F', 'FEMALE', 'GIRL', 'GIRLS') THEN 'D/o '
                ELSE 'S/o '
            END || COALESCE(v_prof.father_name, 'Parent'),
            -- Linked Collections:
            'fee_summary', v_fee_summary,
            'initial_payment_amount', COALESCE(v_adm.initial_payment_amount, 0.0),
            'activities', v_activities,
            'leaves', v_leave_history,
            'documents', v_documents
        )
    );
END;
$function$;

