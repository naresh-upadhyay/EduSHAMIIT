-- Migration 547: Enhance fn_campus_upsert_building to support safe partial updates (e.g. image_url updates)
-- Prevents required-field rejections on PATCH/partial-PUT updates and prevents wiping existing fields

CREATE OR REPLACE FUNCTION public.fn_campus_upsert_building(
    p_school_id UUID,
    p_payload JSONB,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID := NULL;
    v_id_txt TEXT := TRIM(COALESCE(p_payload->>'id', ''));
    v_code TEXT := UPPER(TRIM(COALESCE(p_payload->>'code', '')));
    v_name TEXT := TRIM(COALESCE(p_payload->>'name', ''));
    v_building_type TEXT := COALESCE(p_payload->>'building_type', 'Academic');
    v_total_floors INT := GREATEST(1, COALESCE((p_payload->>'total_floors')::INT, 1));
    v_total_area NUMERIC := GREATEST(0.0, COALESCE((p_payload->>'total_area')::NUMERIC, 0.0));
    v_area_unit TEXT := COALESCE(p_payload->>'area_unit', 'sq ft');
    v_status TEXT := COALESCE(p_payload->>'status', 'Active');
    v_existing public.buildings%ROWTYPE;
    v_result RECORD;
    v_valid_user_id UUID := p_user_id;
BEGIN
    IF v_valid_user_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_valid_user_id) THEN
        v_valid_user_id := NULL;
    END IF;

    IF v_id_txt <> '' THEN
        v_id := v_id_txt::UUID;
    END IF;

    -- If updating an existing building, retrieve current row to support partial updates
    IF v_id IS NOT NULL THEN
        SELECT * INTO v_existing FROM public.buildings 
        WHERE id = v_id AND school_id = p_school_id AND deleted_at IS NULL;

        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', FALSE, 'message', 'Building not found for update.');
        END IF;

        -- Fallback to existing values if not explicitly provided in partial payload
        IF v_name = '' THEN
            v_name := v_existing.name;
        END IF;
        IF v_code = '' THEN
            v_code := v_existing.code;
        END IF;
        IF NOT (p_payload ? 'building_type') THEN
            v_building_type := v_existing.building_type;
        END IF;
        IF NOT (p_payload ? 'total_floors') THEN
            v_total_floors := v_existing.total_floors;
        END IF;
        IF NOT (p_payload ? 'total_area') THEN
            v_total_area := COALESCE(v_existing.total_area, 0.0);
        END IF;
        IF NOT (p_payload ? 'area_unit') THEN
            v_area_unit := COALESCE(v_existing.area_unit, 'sq ft');
        END IF;
        IF NOT (p_payload ? 'status') THEN
            v_status := v_existing.status;
        END IF;
    END IF;

    IF v_name = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Building name is required.');
    END IF;

    IF v_code = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Building code is required.');
    END IF;

    -- Duplicate code check
    IF EXISTS (
        SELECT 1 FROM public.buildings 
        WHERE school_id = p_school_id 
          AND UPPER(code) = v_code 
          AND (v_id IS NULL OR id <> v_id) 
          AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'A building with code ' || v_code || ' already exists in this institution.');
    END IF;

    IF v_id IS NOT NULL THEN
        -- UPDATE with key-presence check to preserve existing fields on partial update
        UPDATE public.buildings SET
            name = v_name,
            code = v_code,
            building_type = v_building_type,
            description = CASE WHEN p_payload ? 'description' THEN p_payload->>'description' ELSE v_existing.description END,
            purpose = CASE WHEN p_payload ? 'purpose' THEN p_payload->>'purpose' ELSE v_existing.purpose END,
            address = CASE WHEN p_payload ? 'address' THEN p_payload->>'address' ELSE v_existing.address END,
            latitude = CASE WHEN p_payload ? 'latitude' THEN (p_payload->>'latitude')::NUMERIC ELSE v_existing.latitude END,
            longitude = CASE WHEN p_payload ? 'longitude' THEN (p_payload->>'longitude')::NUMERIC ELSE v_existing.longitude END,
            total_floors = v_total_floors,
            total_area = v_total_area,
            area_unit = v_area_unit,
            construction_year = CASE WHEN p_payload ? 'construction_year' THEN (p_payload->>'construction_year')::INT ELSE v_existing.construction_year END,
            num_entrances = CASE WHEN p_payload ? 'num_entrances' THEN GREATEST(1, COALESCE((p_payload->>'num_entrances')::INT, 1)) ELSE v_existing.num_entrances END,
            num_emergency_exits = CASE WHEN p_payload ? 'num_emergency_exits' THEN GREATEST(0, COALESCE((p_payload->>'num_emergency_exits')::INT, 1)) ELSE v_existing.num_emergency_exits END,
            manager_name = CASE WHEN p_payload ? 'manager_name' THEN p_payload->>'manager_name' ELSE v_existing.manager_name END,
            manager_contact = CASE WHEN p_payload ? 'manager_contact' THEN p_payload->>'manager_contact' ELSE v_existing.manager_contact END,
            department = CASE WHEN p_payload ? 'department' THEN p_payload->>'department' ELSE v_existing.department END,
            image_url = CASE WHEN p_payload ? 'image_url' THEN p_payload->>'image_url' ELSE v_existing.image_url END,
            fire_safety_cert_expiry = CASE WHEN p_payload ? 'fire_safety_cert_expiry' THEN (p_payload->>'fire_safety_cert_expiry')::DATE ELSE v_existing.fire_safety_cert_expiry END,
            occupancy_cert_expiry = CASE WHEN p_payload ? 'occupancy_cert_expiry' THEN (p_payload->>'occupancy_cert_expiry')::DATE ELSE v_existing.occupancy_cert_expiry END,
            status = v_status,
            notes = CASE WHEN p_payload ? 'notes' THEN p_payload->>'notes' ELSE v_existing.notes END,
            updated_by = v_valid_user_id,
            updated_at = NOW()
        WHERE id = v_id AND school_id = p_school_id AND deleted_at IS NULL
        RETURNING * INTO v_result;

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Building updated successfully.',
            'data', to_jsonb(v_result)
        );
    ELSE
        -- INSERT
        INSERT INTO public.buildings (
            school_id,
            campus_id,
            name,
            code,
            building_type,
            description,
            purpose,
            address,
            latitude,
            longitude,
            total_floors,
            total_area,
            area_unit,
            construction_year,
            num_entrances,
            num_emergency_exits,
            manager_name,
            manager_contact,
            department,
            image_url,
            fire_safety_cert_expiry,
            occupancy_cert_expiry,
            status,
            notes,
            created_by,
            updated_by
        ) VALUES (
            p_school_id,
            NULLIF(p_payload->>'campus_id', '')::UUID,
            v_name,
            v_code,
            v_building_type,
            p_payload->>'description',
            p_payload->>'purpose',
            p_payload->>'address',
            (p_payload->>'latitude')::NUMERIC,
            (p_payload->>'longitude')::NUMERIC,
            v_total_floors,
            v_total_area,
            v_area_unit,
            (p_payload->>'construction_year')::INT,
            GREATEST(1, COALESCE((p_payload->>'num_entrances')::INT, 1)),
            GREATEST(0, COALESCE((p_payload->>'num_emergency_exits')::INT, 1)),
            p_payload->>'manager_name',
            p_payload->>'manager_contact',
            p_payload->>'department',
            p_payload->>'image_url',
            (p_payload->>'fire_safety_cert_expiry')::DATE,
            (p_payload->>'occupancy_cert_expiry')::DATE,
            v_status,
            p_payload->>'notes',
            v_valid_user_id,
            v_valid_user_id
        )
        RETURNING * INTO v_result;

        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Building created successfully.',
            'data', to_jsonb(v_result)
        );
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Error saving building: ' || SQLERRM);
END;
$$;
