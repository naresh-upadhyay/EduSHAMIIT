-- Migration 391: Safeguard hostel admission against non-UUID bed IDs, missing audit profiles, and auto-provision beds if missing
-- Ensures robustness of fn_hostel_admit_student under all network/synthetic client conditions

-- 1. Ensure King Doe profile exists in public.profiles with valid status
INSERT INTO public.profiles (
    id, school_id, user_id, full_name, role, email, status, created_at, updated_at
) VALUES (
    '5198c4b0-f1cb-45db-9649-41688d0438ba',
    '11111111-1111-1111-1111-111111111111',
    'USR-KINGDOE',
    'King Doe',
    'super_admin',
    'mathematicsking888@gmail.com',
    'Active',
    NOW(),
    NOW()
) ON CONFLICT (id) DO UPDATE SET 
    full_name = EXCLUDED.full_name,
    role = EXCLUDED.role,
    email = EXCLUDED.email,
    status = EXCLUDED.status;

-- 2. Ensure deleted_at column exists on hostel_student_activities
ALTER TABLE public.hostel_student_activities ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

-- 2. Ultra-robust fn_hostel_admit_student
CREATE OR REPLACE FUNCTION public.fn_hostel_admit_student(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_student_id UUID;
    v_academic_year VARCHAR(50);
    v_hostel_id UUID;
    v_room_id UUID;
    v_bed_id UUID;
    v_admission_date DATE;
    v_boarding_type VARCHAR(50);
    v_hostel_type VARCHAR(50);
    v_fee_plan VARCHAR(100);
    v_monthly_fee NUMERIC(10,2);
    v_deposit_amount NUMERIC(10,2);
    v_fee_status VARCHAR(30);
    v_initial_payment_amount NUMERIC(10,2);
    v_special_notes TEXT;
    v_emergency_contact VARCHAR(100);
    v_student RECORD;
    v_existing_adm RECORD;
    v_room RECORD;
    v_bed RECORD;
    v_adm_id UUID;
    v_alloc_id UUID;
    v_adm_status VARCHAR(30) := 'ACTIVE';
    v_audit_user_id UUID := NULL;
    v_target_cap INT;
    v_existing_beds_count INT;
    v_new_bed_idx INT;
BEGIN
    -- Safeguard Audit User ID (Must exist in profiles to satisfy FK constraints)
    IF p_user_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
        v_audit_user_id := p_user_id;
    END IF;

    -- Safely parse UUID fields with regex validation to prevent syntax errors
    IF (p_data->>'student_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_student_id := (p_data->>'student_id')::UUID;
    ELSE
        RETURN jsonb_build_object('success', false, 'message', 'Invalid student ID format');
    END IF;

    v_academic_year := COALESCE(TRIM(p_data->>'academic_year'), '2024 - 2025');

    IF (p_data->>'hostel_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_hostel_id := (p_data->>'hostel_id')::UUID;
    ELSE
        v_hostel_id := NULL;
    END IF;

    IF (p_data->>'room_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_room_id := (p_data->>'room_id')::UUID;
    ELSE
        v_room_id := NULL;
    END IF;

    -- Safe bed_id parsing: only cast if valid UUID, otherwise allow NULL for auto-selection
    IF (p_data->>'bed_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_bed_id := (p_data->>'bed_id')::UUID;
    ELSE
        v_bed_id := NULL;
    END IF;

    v_admission_date := COALESCE((p_data->>'admission_date')::DATE, CURRENT_DATE);
    v_boarding_type := COALESCE(TRIM(p_data->>'boarding_type'), 'REGULAR');
    v_hostel_type := COALESCE(TRIM(p_data->>'hostel_type'), 'Standard');
    v_fee_plan := COALESCE(TRIM(p_data->>'fee_plan'), 'Monthly');
    v_monthly_fee := COALESCE((p_data->>'monthly_fee')::NUMERIC, 6000.0);
    v_deposit_amount := COALESCE((p_data->>'deposit_amount')::NUMERIC, 10000.0);
    v_fee_status := COALESCE(UPPER(TRIM(p_data->>'fee_status')), 'PAID');
    v_initial_payment_amount := COALESCE(
        (p_data->>'initial_payment_amount')::NUMERIC,
        CASE 
            WHEN v_fee_status = 'PAID' THEN (v_monthly_fee + v_deposit_amount)
            WHEN v_fee_status = 'PENDING' THEN 0.0
            ELSE 0.0
        END
    );
    v_special_notes := COALESCE(p_data->>'special_notes', p_data->>'remarks');
    v_emergency_contact := p_data->>'emergency_contact';

    -- Verify student exists in this school
    SELECT * INTO v_student FROM public.profiles 
    WHERE id = v_student_id AND school_id = p_school_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Student profile not found in current organization');
    END IF;

    -- Prevent duplicate active admissions in same session
    SELECT * INTO v_existing_adm 
    FROM public.hostel_admissions
    WHERE school_id = p_school_id 
      AND student_id = v_student_id 
      AND academic_year = v_academic_year 
      AND deleted_at IS NULL
      AND admission_status IN ('ACTIVE', 'AWAITING_ALLOCATION', 'ON_LEAVE');

    IF FOUND THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Student already has an active hostel admission (' || v_existing_adm.admission_status || ') for this academic session.'
        );
    END IF;

    -- Check if room is specified
    IF v_room_id IS NOT NULL THEN
        SELECT * INTO v_room FROM public.hostel_rooms 
        WHERE id = v_room_id AND school_id = p_school_id AND deleted_at IS NULL;
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'message', 'Specified hostel room not found');
        END IF;

        IF NOT v_room.is_residential THEN
            RETURN jsonb_build_object('success', false, 'message', 'Cannot allocate students to non-residential spaces');
        END IF;

        IF v_hostel_id IS NULL THEN
            v_hostel_id := v_room.building_id;
        END IF;

        -- Check if room beds exist in DB, if not auto-generate them
        SELECT COUNT(*) INTO v_existing_beds_count FROM public.hostel_beds WHERE room_id = v_room_id AND deleted_at IS NULL;
        v_target_cap := GREATEST(COALESCE(v_room.target_capacity, 1), 1);
        IF v_existing_beds_count < v_target_cap THEN
            FOR v_new_bed_idx IN (v_existing_beds_count + 1)..v_target_cap LOOP
                INSERT INTO public.hostel_beds (
                    school_id, room_id, bed_code, bed_number, bed_type, status,
                    monthly_fee, created_by, updated_by
                ) VALUES (
                    p_school_id, v_room_id, 'Bed ' || v_new_bed_idx, v_new_bed_idx::TEXT,
                    'Single', 'AVAILABLE', v_room.monthly_fee, v_audit_user_id, v_audit_user_id
                ) ON CONFLICT DO NOTHING;
            END LOOP;
        END IF;

        -- Validate bed if specified
        IF v_bed_id IS NOT NULL THEN
            SELECT * INTO v_bed FROM public.hostel_beds 
            WHERE id = v_bed_id AND room_id = v_room_id AND deleted_at IS NULL;
            IF NOT FOUND THEN
                -- If specified bed is not found, fallback to first available bed in room
                SELECT * INTO v_bed FROM public.hostel_beds 
                WHERE room_id = v_room_id AND status = 'AVAILABLE' AND deleted_at IS NULL 
                ORDER BY bed_code ASC LIMIT 1;
                IF FOUND THEN
                    v_bed_id := v_bed.id;
                ELSE
                    RETURN jsonb_build_object('success', false, 'message', 'No vacant beds available in this room');
                END IF;
            ELSIF v_bed.status = 'OCCUPIED' THEN
                RETURN jsonb_build_object('success', false, 'message', 'Selected bed is already occupied');
            ELSIF v_bed.status IN ('BLOCKED', 'MAINTENANCE', 'OUT_OF_SERVICE', 'RETIRED') THEN
                RETURN jsonb_build_object('success', false, 'message', 'Selected bed is currently unavailable for allocation');
            END IF;
        ELSE
            -- Pick first available bed in room
            SELECT * INTO v_bed FROM public.hostel_beds 
            WHERE room_id = v_room_id AND status = 'AVAILABLE' AND deleted_at IS NULL 
            ORDER BY bed_code ASC LIMIT 1;
            IF FOUND THEN
                v_bed_id := v_bed.id;
            ELSE
                RETURN jsonb_build_object('success', false, 'message', 'No vacant beds available in this room');
            END IF;
        END IF;

        v_adm_status := 'ACTIVE';
    ELSE
        -- No room allocated yet -> Awaiting Allocation status
        v_adm_status := 'AWAITING_ALLOCATION';
    END IF;

    -- 1. Create Hostel Admission Record with dynamic fee_status and initial_payment_amount
    INSERT INTO public.hostel_admissions (
        school_id, student_id, academic_year, hostel_id, admission_reference,
        admission_date, admission_status, boarding_type, hostel_type, fee_plan,
        monthly_fee, deposit_amount, fee_status, initial_payment_amount,
        emergency_contact_override, special_notes, created_by, updated_by
    ) VALUES (
        p_school_id, v_student_id, v_academic_year, v_hostel_id, 
        'ADM-' || TO_CHAR(NOW(), 'YYMM') || '-' || SUBSTRING(v_student_id::TEXT, 1, 4),
        v_admission_date, v_adm_status, v_boarding_type, v_hostel_type, v_fee_plan,
        v_monthly_fee, v_deposit_amount, v_fee_status, v_initial_payment_amount,
        v_emergency_contact, v_special_notes, v_audit_user_id, v_audit_user_id
    ) RETURNING id INTO v_adm_id;

    -- 2. If Room and Bed allocated, create allocation record
    IF v_room_id IS NOT NULL AND v_bed_id IS NOT NULL THEN
        INSERT INTO public.hostel_allocations (
            school_id, admission_id, student_id, academic_year, building_id, floor_id,
            room_id, bed_id, allocation_status, check_in_date, monthly_fee, deposit_amount,
            fee_status, initial_payment_amount, allocation_reason, created_by, updated_by
        ) VALUES (
            p_school_id, v_adm_id, v_student_id, v_academic_year, v_room.building_id, v_room.floor_id,
            v_room_id, v_bed_id, 'CHECKED_IN', NOW(), v_monthly_fee, v_deposit_amount,
            v_fee_status, v_initial_payment_amount, 'New Admission Allocation', v_audit_user_id, v_audit_user_id
        ) RETURNING id INTO v_alloc_id;

        -- Update Bed Status to OCCUPIED
        UPDATE public.hostel_beds 
        SET status = 'OCCUPIED', updated_by = v_audit_user_id, updated_at = NOW() 
        WHERE id = v_bed_id;

        -- Recalculate room occupancy
        PERFORM public.fn_hostel_recalculate_room(v_room_id);
    END IF;

    -- 3. Log Activity Timeline
    INSERT INTO public.hostel_student_activities (
        school_id, student_id, admission_id, activity_type, title, description,
        badge_color, performed_by, performed_by_name
    ) VALUES (
        p_school_id, v_student_id, v_adm_id, 'NEW_ADMISSION',
        'New admission',
        TO_CHAR(v_admission_date, 'DD Mon YYYY') || ' • Admitted to ' || COALESCE((SELECT name FROM public.hostel_buildings WHERE id = v_hostel_id), 'Hostel'),
        'purple', v_audit_user_id, 'Hostel Administrator'
    );

    IF v_room_id IS NOT NULL AND v_bed_id IS NOT NULL THEN
        INSERT INTO public.hostel_student_activities (
            school_id, student_id, admission_id, activity_type, title, description,
            badge_color, performed_by, performed_by_name
        ) VALUES (
            p_school_id, v_student_id, v_adm_id, 'ROOM_ALLOCATION',
            'Bed allocated',
            'Allocated to Room ' || COALESCE(v_room.room_number, '') || ', Bed ' || COALESCE((SELECT bed_code FROM public.hostel_beds WHERE id = v_bed_id), '1'),
            'green', v_audit_user_id, 'Hostel Administrator'
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Hostel student admitted successfully',
        'admission_id', v_adm_id,
        'allocation_id', v_alloc_id
    );
END;
$function$;

-- 3. Update fn_hostel_get_student_detail to query hostel_leave_outing_requests
CREATE OR REPLACE FUNCTION public.fn_hostel_get_student_detail(
    p_school_id UUID,
    p_admission_id UUID DEFAULT NULL,
    p_student_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
    IF p_admission_id IS NOT NULL THEN
        SELECT * INTO v_adm FROM public.hostel_admissions 
        WHERE id = p_admission_id AND school_id = p_school_id AND deleted_at IS NULL;
    ELSIF p_student_id IS NOT NULL THEN
        SELECT * INTO v_adm FROM public.hostel_admissions 
        WHERE student_id = p_student_id AND school_id = p_school_id AND deleted_at IS NULL
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

    -- 6. Fetch Leave / Outing History from hostel_leave_outing_requests
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', id,
                'leave_type', COALESCE(request_type, 'Leave'),
                'start_date', TO_CHAR(start_at, 'DD Mon YYYY'),
                'end_date', TO_CHAR(expected_return_at, 'DD Mon YYYY'),
                'status', status,
                'reason', reason
            ) ORDER BY created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_leave_history
    FROM public.hostel_leave_outing_requests
    WHERE (admission_id = v_adm.id OR student_id = v_adm.student_id)
      AND school_id = p_school_id
      AND deleted_at IS NULL
    LIMIT 10;

    -- 7. Fee Summary
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

    -- 8. Build Complete 360 Object
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
$$;

