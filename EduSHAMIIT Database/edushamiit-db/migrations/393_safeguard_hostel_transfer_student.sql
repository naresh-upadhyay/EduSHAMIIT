-- Migration 393: Safeguard and synchronize hostel room & bed transfers
-- Robustly handles UUID validation, synthetic bed IDs, audit user safety, and automatic bed provisioning

CREATE OR REPLACE FUNCTION public.fn_hostel_transfer_student(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_admission_id UUID := NULL;
    v_allocation_id UUID := NULL;
    v_new_room_id UUID := NULL;
    v_new_bed_id UUID := NULL;
    v_target_bed_num TEXT := NULL;
    v_reason TEXT;
    v_alloc RECORD;
    v_new_room RECORD;
    v_new_bed RECORD;
    v_old_room_id UUID := NULL;
    v_old_bed_id UUID := NULL;
    v_audit_user_id UUID := NULL;
    v_target_cap INT;
    v_existing_beds_count INT;
BEGIN
    -- 1. Safeguard Audit User ID (Must exist in profiles to satisfy FK constraints)
    IF p_user_id IS NOT NULL AND EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
        v_audit_user_id := p_user_id;
    END IF;

    -- 2. Safely parse UUID fields with regex validation to prevent syntax errors
    IF (p_data->>'admission_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_admission_id := (p_data->>'admission_id')::UUID;
    END IF;

    IF (p_data->>'allocation_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_allocation_id := (p_data->>'allocation_id')::UUID;
    END IF;

    IF (p_data->>'new_room_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_new_room_id := (p_data->>'new_room_id')::UUID;
    ELSIF (p_data->>'target_room_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_new_room_id := (p_data->>'target_room_id')::UUID;
    END IF;

    IF (p_data->>'new_bed_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_new_bed_id := (p_data->>'new_bed_id')::UUID;
    ELSIF (p_data->>'target_bed_id') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        v_new_bed_id := (p_data->>'target_bed_id')::UUID;
    END IF;

    v_target_bed_num := NULLIF(TRIM(COALESCE(p_data->>'target_bed_number', p_data->>'bed_number', '')), '');
    v_reason := COALESCE(NULLIF(TRIM(p_data->>'reason'), ''), 'Student room transfer');

    IF v_new_room_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Target room ID is required for transfer');
    END IF;

    -- 3. Fetch active allocation record
    IF v_allocation_id IS NOT NULL THEN
        SELECT * INTO v_alloc FROM public.hostel_allocations 
        WHERE id = v_allocation_id AND school_id = p_school_id AND deleted_at IS NULL;
    ELSIF v_admission_id IS NOT NULL THEN
        SELECT * INTO v_alloc FROM public.hostel_allocations 
        WHERE admission_id = v_admission_id AND school_id = p_school_id 
          AND allocation_status IN ('CHECKED_IN', 'RESERVED', 'CONFIRMED', 'TEMPORARILY_RELOCATED')
          AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 1;
    END IF;

    IF v_alloc IS NULL THEN
        -- If no explicit allocation record exists, lookup active admission to initialize transfer
        IF v_admission_id IS NOT NULL THEN
            SELECT ha.id AS admission_id, ha.student_id, ha.academic_year, ha.hostel_id AS building_id,
                   0.00 AS deposit_amount, 'PAID' AS fee_status,
                   hr.id AS room_id, hr.monthly_fee
            INTO v_alloc
            FROM public.hostel_admissions ha
            LEFT JOIN public.hostel_rooms hr ON hr.id = ha.room_id
            WHERE ha.id = v_admission_id AND ha.school_id = p_school_id AND ha.deleted_at IS NULL;
        END IF;

        IF v_alloc IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'Active room allocation record not found for transfer');
        END IF;
    END IF;

    v_old_room_id := v_alloc.room_id;
    v_old_bed_id := v_alloc.bed_id;

    -- Prevent transferring to identical room
    IF v_old_room_id = v_new_room_id AND v_new_bed_id IS NOT NULL AND v_old_bed_id = v_new_bed_id THEN
        RETURN jsonb_build_object('success', false, 'message', 'Student is already assigned to this room and bed');
    END IF;

    -- 4. Verify target room
    SELECT * INTO v_new_room FROM public.hostel_rooms 
    WHERE id = v_new_room_id AND school_id = p_school_id AND deleted_at IS NULL;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Target room not found');
    END IF;

    IF NOT v_new_room.is_residential THEN
        RETURN jsonb_build_object('success', false, 'message', 'Cannot transfer to non-residential room');
    END IF;

    -- 5. Verify or resolve target bed
    IF v_new_bed_id IS NOT NULL THEN
        SELECT * INTO v_new_bed FROM public.hostel_beds 
        WHERE id = v_new_bed_id AND room_id = v_new_room_id AND deleted_at IS NULL;
        
        IF FOUND THEN
            IF v_new_bed.status = 'OCCUPIED' THEN
                RETURN jsonb_build_object('success', false, 'message', 'Selected bed is already occupied. Please choose a vacant bed.');
            END IF;
        ELSE
            -- Provided bed UUID not found in room; attempt fallback by target_bed_num
            v_new_bed_id := NULL;
        END IF;
    END IF;

    -- If bed not yet resolved, try resolving by bed_code or bed_number
    IF v_new_bed_id IS NULL AND v_target_bed_num IS NOT NULL THEN
        SELECT * INTO v_new_bed FROM public.hostel_beds
        WHERE room_id = v_new_room_id
          AND (bed_code = v_target_bed_num OR bed_code = 'Bed ' || v_target_bed_num OR bed_code ILIKE '%' || v_target_bed_num || '%')
          AND status = 'AVAILABLE'
          AND deleted_at IS NULL
        ORDER BY bed_code ASC LIMIT 1;

        IF FOUND THEN
            v_new_bed_id := v_new_bed.id;
        END IF;
    END IF;

    -- If bed still not resolved, pick first available bed in target room
    IF v_new_bed_id IS NULL THEN
        SELECT * INTO v_new_bed FROM public.hostel_beds 
        WHERE room_id = v_new_room_id AND status = 'AVAILABLE' AND deleted_at IS NULL 
        ORDER BY bed_code ASC LIMIT 1;
        
        IF FOUND THEN
            v_new_bed_id := v_new_bed.id;
        END IF;
    END IF;

    -- If no available bed exists in hostel_beds but room has available capacity, auto-provision
    IF v_new_bed_id IS NULL THEN
        v_target_cap := COALESCE(v_new_room.target_capacity, 1);
        SELECT COUNT(*) INTO v_existing_beds_count FROM public.hostel_beds WHERE room_id = v_new_room_id AND deleted_at IS NULL;
        
        IF v_existing_beds_count < v_target_cap OR (v_target_cap - COALESCE(v_new_room.current_occupancy, 0)) > 0 THEN
            INSERT INTO public.hostel_beds (
                school_id, building_id, floor_id, room_id, bed_code, bed_type,
                condition, status, monthly_fee, created_by, updated_by
            ) VALUES (
                p_school_id, v_new_room.building_id, v_new_room.floor_id, v_new_room_id,
                COALESCE(v_target_bed_num, 'Bed ' || (v_existing_beds_count + 1)),
                'Single', 'GOOD', 'AVAILABLE', COALESCE(v_new_room.monthly_fee, 6000.0),
                v_audit_user_id, v_audit_user_id
            ) RETURNING id, bed_code INTO v_new_bed_id, v_target_bed_num;
            
            SELECT * INTO v_new_bed FROM public.hostel_beds WHERE id = v_new_bed_id;
        ELSE
            RETURN jsonb_build_object('success', false, 'message', 'Target room has no vacant beds available');
        END IF;
    END IF;

    -- 6. Close Old Allocation if exists
    IF v_alloc.id IS NOT NULL THEN
        UPDATE public.hostel_allocations 
        SET allocation_status = 'CHECKED_OUT', actual_check_out_date = NOW(), updated_by = v_audit_user_id, updated_at = NOW()
        WHERE id = v_alloc.id;
    END IF;

    -- 7. Release Old Bed
    IF v_old_bed_id IS NOT NULL THEN
        UPDATE public.hostel_beds 
        SET status = 'AVAILABLE', updated_by = v_audit_user_id, updated_at = NOW() 
        WHERE id = v_old_bed_id;
    END IF;

    -- 8. Create New Allocation
    INSERT INTO public.hostel_allocations (
        school_id, admission_id, student_id, academic_year, building_id, floor_id,
        room_id, bed_id, allocation_status, check_in_date, monthly_fee, deposit_amount,
        fee_status, allocation_reason, created_by, updated_by
    ) VALUES (
        p_school_id, v_alloc.admission_id, v_alloc.student_id, v_alloc.academic_year,
        v_new_room.building_id, v_new_room.floor_id, v_new_room_id, v_new_bed_id,
        'CHECKED_IN', NOW(), v_new_room.monthly_fee, COALESCE(v_alloc.deposit_amount, 0.00),
        COALESCE(v_alloc.fee_status, 'PAID'), v_reason, v_audit_user_id, v_audit_user_id
    );

    -- 9. Occupy New Bed
    IF v_new_bed_id IS NOT NULL THEN
        UPDATE public.hostel_beds 
        SET status = 'OCCUPIED', updated_by = v_audit_user_id, updated_at = NOW() 
        WHERE id = v_new_bed_id;
    END IF;

    -- 10. Update Admission hostel_id if changed
    UPDATE public.hostel_admissions 
    SET hostel_id = v_new_room.building_id,
        updated_by = v_audit_user_id,
        updated_at = NOW()
    WHERE id = v_alloc.admission_id;

    -- 11. Log Activity Timeline
    INSERT INTO public.hostel_student_activities (
        school_id, student_id, admission_id, activity_type, title, description,
        badge_color, performed_by, performed_by_name
    ) VALUES (
        p_school_id, v_alloc.student_id, v_alloc.admission_id, 'ROOM_TRANSFER',
        'Room transferred',
        'Transferred to Room ' || v_new_room.room_number || ', Bed ' || COALESCE(v_new_bed.bed_code, v_target_bed_num, '1') || ' · ' || v_reason,
        'blue', v_audit_user_id, 'Hostel Administrator'
    );

    -- 12. Recalculate Occupancy
    IF v_old_room_id IS NOT NULL THEN
        PERFORM public.fn_hostel_recalculate_room(v_old_room_id);
    END IF;
    PERFORM public.fn_hostel_recalculate_room(v_new_room_id);

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Room transfer completed successfully',
        'new_room_number', v_new_room.room_number,
        'new_bed_code', COALESCE(v_new_bed.bed_code, v_target_bed_num, '1')
    );
END;
$$;
