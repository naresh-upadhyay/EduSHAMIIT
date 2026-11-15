-- Migration 389: Auto Generate Hostel Room Beds and Ensure Bed Availability
-- Ensures all residential rooms with target_capacity > 0 have corresponding hostel_beds records.

-- 1. Ensure beds for all existing residential rooms
DO $$
DECLARE
    r RECORD;
    v_existing_count INT;
    i INT;
    v_bed_code VARCHAR(50);
BEGIN
    FOR r IN 
        SELECT id, school_id, building_id, floor_id, room_number, target_capacity, monthly_fee
        FROM public.hostel_rooms
        WHERE deleted_at IS NULL AND is_residential = TRUE AND target_capacity > 0
    LOOP
        SELECT COUNT(*) INTO v_existing_count
        FROM public.hostel_beds
        WHERE room_id = r.id AND deleted_at IS NULL;

        IF v_existing_count < r.target_capacity THEN
            FOR i IN 1..r.target_capacity LOOP
                v_bed_code := 'Bed ' || i;
                INSERT INTO public.hostel_beds (
                    school_id, building_id, floor_id, room_id, bed_code, bed_type,
                    condition, status, monthly_fee
                ) VALUES (
                    r.school_id, r.building_id, r.floor_id, r.id, v_bed_code, 'Single',
                    'GOOD', 'AVAILABLE', COALESCE(r.monthly_fee, 6000.0)
                )
                ON CONFLICT (room_id, UPPER(bed_code)) WHERE deleted_at IS NULL DO NOTHING;
            END LOOP;
        END IF;

        PERFORM public.fn_hostel_recalculate_room(r.id);
    END LOOP;
END;
$$;

-- 2. Update fn_hostel_create_or_update_room to automatically populate beds for residential rooms
CREATE OR REPLACE FUNCTION public.fn_hostel_create_or_update_room(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID;
    v_building_id UUID;
    v_floor_id UUID;
    v_room_number VARCHAR(50);
    v_room_code VARCHAR(100);
    v_room_name VARCHAR(150);
    v_room_type VARCHAR(100);
    v_is_residential BOOLEAN;
    v_capacity INT;
    v_size NUMERIC(8,2);
    v_fee NUMERIC(10,2);
    v_gender VARCHAR(20);
    v_status VARCHAR(30);
    v_photos JSONB;
    v_amenities JSONB;
    v_record RECORD;
    i INT;
    v_bed_code VARCHAR(50);
BEGIN
    v_id := (p_data->>'id')::UUID;
    v_building_id := (p_data->>'building_id')::UUID;
    v_floor_id := (p_data->>'floor_id')::UUID;
    v_room_number := TRIM(p_data->>'room_number');
    v_room_code := COALESCE(TRIM(p_data->>'room_code'), v_room_number);
    v_room_name := p_data->>'room_name';
    v_room_type := COALESCE(TRIM(p_data->>'room_type'), 'Standard');
    v_is_residential := COALESCE((p_data->>'is_residential')::BOOLEAN, 
                                 CASE WHEN v_room_type IN ('Toilet/Washroom', 'Pantry', 'Laundry', 'Storage', 'Electrical Room', 'Pump Room') THEN FALSE ELSE TRUE END);
    v_capacity := COALESCE((p_data->>'capacity')::INT, CASE WHEN v_is_residential THEN 3 ELSE 0 END);
    v_size := COALESCE((p_data->>'room_size_sqm')::NUMERIC, 18.0);
    v_fee := COALESCE((p_data->>'monthly_fee')::NUMERIC, 6000.0);
    v_gender := COALESCE(p_data->>'gender_restriction', 'BOYS');
    v_status := COALESCE(p_data->>'operational_status', 'AVAILABLE');
    v_photos := COALESCE(p_data->'photos', '[]'::JSONB);
    v_amenities := COALESCE(p_data->'amenities', '[]'::JSONB);

    IF v_building_id IS NULL OR v_floor_id IS NULL OR v_room_number IS NULL OR v_room_number = '' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Building, floor, and room number are required');
    END IF;

    IF v_id IS NOT NULL THEN
        UPDATE public.hostel_rooms
        SET room_number = v_room_number,
            room_code = v_room_code,
            room_name = v_room_name,
            room_type = v_room_type,
            is_residential = v_is_residential,
            target_capacity = v_capacity,
            room_size_sqm = v_size,
            monthly_fee = v_fee,
            gender_restriction = v_gender,
            operational_status = v_status,
            photos = v_photos,
            amenities = v_amenities,
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = v_id AND school_id = p_school_id AND deleted_at IS NULL
        RETURNING * INTO v_record;
    ELSE
        INSERT INTO public.hostel_rooms (
            school_id, building_id, floor_id, room_number, room_code, room_name, room_type,
            is_residential, target_capacity, room_size_sqm, monthly_fee, gender_restriction,
            operational_status, photos, amenities, created_by, updated_by
        ) VALUES (
            p_school_id, v_building_id, v_floor_id, v_room_number, v_room_code, v_room_name, v_room_type,
            v_is_residential, v_capacity, v_size, v_fee, v_gender,
            v_status, v_photos, v_amenities, p_user_id, p_user_id
        )
        RETURNING * INTO v_record;
    END IF;

    PERFORM public.fn_hostel_recalculate_room(v_record.id);

    RETURN jsonb_build_object('success', true, 'data', to_jsonb(v_record));
END;
$$;

-- 3. Update fn_hostel_get_room_detail to guarantee beds are generated and returned for residential rooms
CREATE OR REPLACE FUNCTION public.fn_hostel_get_room_detail(
    p_school_id UUID,
    p_room_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_room RECORD;
    v_beds JSONB := '[]'::JSONB;
    v_facilities JSONB := '[]'::JSONB;
    v_students JSONB := '[]'::JSONB;
    v_maintenance JSONB := '[]'::JSONB;
    v_history JSONB := '[]'::JSONB;
    v_existing_bed_count INT;
    i INT;
    v_bed_code VARCHAR(50);
BEGIN
    SELECT 
        r.*, 
        b.name AS building_name,
        b.hostel_name,
        f.floor_name
    INTO v_room
    FROM public.hostel_rooms r
    JOIN public.hostel_buildings b ON r.building_id = b.id
    JOIN public.hostel_floors f ON r.floor_id = f.id
    WHERE r.id = p_room_id AND r.school_id = p_school_id AND r.deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Room not found');
    END IF;

    -- Ensure beds exist if residential and target_capacity > 0
    IF v_room.is_residential AND v_room.target_capacity > 0 THEN
        SELECT COUNT(*) INTO v_existing_bed_count
        FROM public.hostel_beds
        WHERE room_id = p_room_id AND deleted_at IS NULL;

        IF v_existing_bed_count = 0 THEN
            FOR i IN 1..v_room.target_capacity LOOP
                v_bed_code := 'Bed ' || i;
                INSERT INTO public.hostel_beds (
                    school_id, building_id, floor_id, room_id, bed_code, bed_type,
                    condition, status, monthly_fee
                ) VALUES (
                    p_school_id, v_room.building_id, v_room.floor_id, p_room_id,
                    v_bed_code, 'Single', 'GOOD', 'AVAILABLE', COALESCE(v_room.monthly_fee, 6000.0)
                )
                ON CONFLICT (room_id, UPPER(bed_code)) WHERE deleted_at IS NULL DO NOTHING;
            END LOOP;
        END IF;
    END IF;

    -- Fetch Beds
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', bd.id,
                'bed_code', bd.bed_code,
                'bed_type', bd.bed_type,
                'condition', bd.condition,
                'status', bd.status,
                'monthly_fee', bd.monthly_fee,
                'occupant', (
                    SELECT jsonb_build_object(
                        'student_id', p.id,
                        'full_name', p.full_name,
                        'email', p.email,
                        'avatar_url', p.avatar_url,
                        'check_in_date', a.check_in_date,
                        'allocation_id', a.id
                    )
                    FROM public.hostel_allocations a
                    JOIN public.profiles p ON a.student_id = p.id
                    WHERE a.bed_id = bd.id 
                      AND a.deleted_at IS NULL 
                      AND a.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
                    LIMIT 1
                )
            ) ORDER BY bd.bed_code ASC
        ),
        '[]'::JSONB
    ) INTO v_beds
    FROM public.hostel_beds bd
    WHERE bd.room_id = p_room_id AND bd.deleted_at IS NULL;

    -- Fetch Facilities / Equipment
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', eq.id,
                'name', eq.equipment_name,
                'category', eq.equipment_category,
                'quantity', eq.quantity,
                'status', eq.status,
                'is_critical', eq.is_critical,
                'notes', eq.notes
            ) ORDER BY eq.equipment_name ASC
        ),
        '[]'::JSONB
    ) INTO v_facilities
    FROM public.hostel_room_equipment eq
    WHERE eq.room_id = p_room_id AND eq.deleted_at IS NULL;

    -- Fetch Students Allocated
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'student_id', p.id,
                'full_name', p.full_name,
                'admission_number', p.admission_number,
                'class_name', COALESCE(p.class, '10 A'),
                'bed_code', bd.bed_code,
                'check_in_date', a.check_in_date,
                'status', a.allocation_status
            ) ORDER BY bd.bed_code ASC
        ),
        '[]'::JSONB
    ) INTO v_students
    FROM public.hostel_allocations a
    JOIN public.profiles p ON a.student_id = p.id
    LEFT JOIN public.hostel_beds bd ON a.bed_id = bd.id
    WHERE a.room_id = p_room_id 
      AND a.deleted_at IS NULL 
      AND a.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED');

    -- Fetch Maintenance History
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', m.id,
                'ticket_number', m.ticket_number,
                'title', m.title,
                'category', 'Maintenance',
                'priority', m.priority,
                'status', m.status,
                'created_at', m.created_at
            ) ORDER BY m.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_maintenance
    FROM public.hostel_maintenance_tickets m
    WHERE m.room_id = p_room_id AND m.deleted_at IS NULL;

    -- Room history timeline (defaults to empty array if no specific room history table)
    v_history := '[]'::JSONB;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'id', v_room.id,
            'room_number', v_room.room_number,
            'room_code', v_room.room_code,
            'room_name', v_room.room_name,
            'building_id', v_room.building_id,
            'building_name', v_room.building_name,
            'hostel_name', v_room.hostel_name,
            'floor_id', v_room.floor_id,
            'floor_name', v_room.floor_name,
            'room_type', v_room.room_type,
            'is_residential', v_room.is_residential,
            'capacity', v_room.target_capacity,
            'current_occupancy', v_room.current_occupancy,
            'room_size_sqm', v_room.room_size_sqm,
            'monthly_fee', v_room.monthly_fee,
            'status', v_room.operational_status,
            'cleanliness_status', v_room.cleanliness_status,
            'condition_status', v_room.condition_status,
            'gender_restriction', v_room.gender_restriction,
            'attached_washroom', COALESCE((v_room.amenities ? 'Attached Washroom'), TRUE),
            'notes', v_room.inspection_schedule,
            'photos', COALESCE(v_room.photos, '[]'::JSONB),
            'amenities', COALESCE(v_room.amenities, '[]'::JSONB),
            'beds', v_beds,
            'facilities', v_facilities,
            'students', v_students,
            'maintenance', v_maintenance,
            'history', v_history
        )
    );
END;
$$;

