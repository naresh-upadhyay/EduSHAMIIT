-- ============================================================================
-- Migration: 445_campus_buildings_stored_procedures.sql
-- Description: Production-Grade Stored Procedures and Functions for Campus Management:
--              1. fn_campus_get_kpis
--              2. fn_campus_list_buildings
--              3. fn_campus_get_building_details
--              4. fn_campus_upsert_building
--              5. fn_campus_archive_or_delete_building
--              6. fn_campus_list_floors
--              7. fn_campus_upsert_floor
--              8. fn_campus_delete_floor
--              9. fn_campus_list_rooms
--              10. fn_campus_get_room_details
--              11. fn_campus_upsert_room
--              12. fn_campus_bulk_create_rooms
--              13. fn_campus_bulk_import_rooms
--              14. fn_campus_upsert_equipment
--              15. fn_campus_delete_equipment
--              16. fn_campus_get_lookups
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Function: Campus KPIs Summary
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_campus_get_kpis(
    p_school_id UUID,
    p_campus_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_buildings INT := 0;
    v_total_floors INT := 0;
    v_total_rooms INT := 0;
    v_total_capacity INT := 0;
    v_occupied_rooms INT := 0;
    v_occupied_capacity INT := 0;
    v_available_rooms INT := 0;
    v_available_capacity INT := 0;
    v_occupancy_rate NUMERIC := 0.0;
    v_maintenance_rooms INT := 0;
    v_total_equipment INT := 0;
    v_equipment_not_working INT := 0;
BEGIN
    -- Buildings count
    SELECT COUNT(*)
    INTO v_total_buildings
    FROM public.buildings
    WHERE school_id = p_school_id
      AND deleted_at IS NULL
      AND (p_campus_id IS NULL OR campus_id = p_campus_id);

    -- Floors count
    SELECT COUNT(f.id)
    INTO v_total_floors
    FROM public.building_floors f
    JOIN public.buildings b ON f.building_id = b.id AND b.deleted_at IS NULL
    WHERE f.school_id = p_school_id
      AND f.deleted_at IS NULL
      AND (p_campus_id IS NULL OR b.campus_id = p_campus_id);

    -- Rooms aggregations
    SELECT 
        COUNT(r.id),
        COALESCE(SUM(r.max_capacity), 0),
        COALESCE(SUM(r.current_occupancy), 0),
        COUNT(CASE WHEN r.operational_status IN ('Occupied', 'Reserved') OR r.assignment_status IN ('Assigned', 'Reserved') THEN 1 END),
        COUNT(CASE WHEN r.operational_status = 'Available' THEN 1 END),
        COUNT(CASE WHEN r.operational_status = 'Under Maintenance' THEN 1 END)
    INTO 
        v_total_rooms,
        v_total_capacity,
        v_occupied_capacity,
        v_occupied_rooms,
        v_available_rooms,
        v_maintenance_rooms
    FROM public.rooms r
    JOIN public.buildings b ON r.building_id = b.id AND b.deleted_at IS NULL
    WHERE r.school_id = p_school_id
      AND r.deleted_at IS NULL
      AND (p_campus_id IS NULL OR b.campus_id = p_campus_id);

    -- Derived values
    v_available_capacity := GREATEST(0, v_total_capacity - v_occupied_capacity);
    IF v_total_capacity > 0 THEN
        v_occupancy_rate := ROUND((v_occupied_capacity::NUMERIC / v_total_capacity::NUMERIC) * 100.0, 1);
    ELSE
        v_occupancy_rate := 0.0;
    END IF;

    -- Equipment aggregations
    SELECT 
        COUNT(e.id),
        COUNT(CASE WHEN e.operational_status IN ('Not Working', 'Under Maintenance', 'Damaged', 'Degraded') THEN 1 END)
    INTO 
        v_total_equipment,
        v_equipment_not_working
    FROM public.room_equipment e
    JOIN public.buildings b ON e.building_id = b.id AND b.deleted_at IS NULL
    WHERE e.school_id = p_school_id
      AND e.deleted_at IS NULL
      AND (p_campus_id IS NULL OR b.campus_id = p_campus_id);

    RETURN jsonb_build_object(
        'total_buildings', v_total_buildings,
        'total_floors', v_total_floors,
        'total_rooms', v_total_rooms,
        'total_capacity', v_total_capacity,
        'occupied_rooms', v_occupied_rooms,
        'occupied_capacity', v_occupied_capacity,
        'available_rooms', v_available_rooms,
        'available_capacity', v_available_capacity,
        'occupancy_rate', v_occupancy_rate,
        'maintenance_rooms', v_maintenance_rooms,
        'total_equipment', v_total_equipment,
        'equipment_not_working', v_equipment_not_working
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 2. Function: List Buildings (Paginated with Aggregations)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_campus_list_buildings(
    p_school_id UUID,
    p_filters JSONB DEFAULT '{}'::JSONB,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search TEXT := TRIM(COALESCE(p_filters->>'search', ''));
    v_type TEXT := TRIM(COALESCE(p_filters->>'building_type', ''));
    v_status TEXT := TRIM(COALESCE(p_filters->>'status', ''));
    v_campus_id_txt TEXT := TRIM(COALESCE(p_filters->>'campus_id', ''));
    v_campus_id UUID := NULL;
    v_offset INT;
    v_total INT := 0;
    v_buildings JSONB := '[]'::JSONB;
BEGIN
    IF v_campus_id_txt <> '' THEN
        v_campus_id := v_campus_id_txt::UUID;
    END IF;

    v_offset := GREATEST(0, (COALESCE(p_page, 1) - 1) * COALESCE(p_page_size, 10));

    -- Total count
    SELECT COUNT(*)
    INTO v_total
    FROM public.buildings b
    WHERE b.school_id = p_school_id
      AND b.deleted_at IS NULL
      AND (v_campus_id IS NULL OR b.campus_id = v_campus_id)
      AND (v_type = '' OR LOWER(b.building_type) = LOWER(v_type))
      AND (v_status = '' OR LOWER(b.status) = LOWER(v_status))
      AND (
          v_search = '' OR
          b.name ILIKE '%' || v_search || '%' OR
          b.code ILIKE '%' || v_search || '%' OR
          COALESCE(b.description, '') ILIKE '%' || v_search || '%' OR
          COALESCE(b.manager_name, '') ILIKE '%' || v_search || '%' OR
          COALESCE(b.department, '') ILIKE '%' || v_search || '%'
      );

    -- Query items
    SELECT jsonb_agg(sub.item)
    INTO v_buildings
    FROM (
        SELECT jsonb_build_object(
            'id', b.id,
            'school_id', b.school_id,
            'campus_id', b.campus_id,
            'name', b.name,
            'code', b.code,
            'building_type', b.building_type,
            'description', b.description,
            'purpose', b.purpose,
            'address', b.address,
            'latitude', b.latitude,
            'longitude', b.longitude,
            'total_floors', COALESCE(f_agg.floor_count, b.total_floors),
            'total_area', b.total_area,
            'area_unit', b.area_unit,
            'construction_year', b.construction_year,
            'num_entrances', b.num_entrances,
            'num_emergency_exits', b.num_emergency_exits,
            'manager_name', b.manager_name,
            'manager_contact', b.manager_contact,
            'manager_user_id', b.manager_user_id,
            'department', b.department,
            'image_url', b.image_url,
            'fire_safety_cert_expiry', b.fire_safety_cert_expiry,
            'occupancy_cert_expiry', b.occupancy_cert_expiry,
            'status', b.status,
            'notes', b.notes,
            'metadata', b.metadata,
            'created_at', b.created_at,
            'updated_at', b.updated_at,
            'total_rooms', COALESCE(r_agg.room_count, 0),
            'total_capacity', COALESCE(r_agg.total_cap, 0),
            'current_occupancy', COALESCE(r_agg.curr_occ, 0),
            'occupancy_rate', CASE 
                WHEN COALESCE(r_agg.total_cap, 0) > 0 
                THEN ROUND((COALESCE(r_agg.curr_occ, 0)::NUMERIC / r_agg.total_cap::NUMERIC) * 100.0, 1) 
                ELSE 0.0 
            END,
            'last_inspection', insp_agg.last_inspection
        ) AS item
        FROM public.buildings b
        LEFT JOIN LATERAL (
            SELECT COUNT(*) AS floor_count
            FROM public.building_floors f
            WHERE f.building_id = b.id AND f.deleted_at IS NULL
        ) f_agg ON TRUE
        LEFT JOIN LATERAL (
            SELECT 
                COUNT(*) AS room_count,
                SUM(r.max_capacity) AS total_cap,
                SUM(r.current_occupancy) AS curr_occ
            FROM public.rooms r
            WHERE r.building_id = b.id AND r.deleted_at IS NULL
        ) r_agg ON TRUE
        LEFT JOIN LATERAL (
            SELECT jsonb_build_object(
                'date', i.inspection_date,
                'result', i.result,
                'type', i.inspection_type
            ) AS last_inspection
            FROM public.building_inspections i
            WHERE i.building_id = b.id
            ORDER BY i.inspection_date DESC
            LIMIT 1
        ) insp_agg ON TRUE
        WHERE b.school_id = p_school_id
          AND b.deleted_at IS NULL
          AND (v_campus_id IS NULL OR b.campus_id = v_campus_id)
          AND (v_type = '' OR LOWER(b.building_type) = LOWER(v_type))
          AND (v_status = '' OR LOWER(b.status) = LOWER(v_status))
          AND (
              v_search = '' OR
              b.name ILIKE '%' || v_search || '%' OR
              b.code ILIKE '%' || v_search || '%' OR
              COALESCE(b.description, '') ILIKE '%' || v_search || '%' OR
              COALESCE(b.manager_name, '') ILIKE '%' || v_search || '%' OR
              COALESCE(b.department, '') ILIKE '%' || v_search || '%'
          )
        ORDER BY b.code ASC, b.name ASC
        LIMIT COALESCE(p_page_size, 10)
        OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'success', TRUE,
        'total_count', v_total,
        'page', COALESCE(p_page, 1),
        'page_size', COALESCE(p_page_size, 10),
        'data', COALESCE(v_buildings, '[]'::JSONB)
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 3. Function: Get Building Details
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_campus_get_building_details(
    p_school_id UUID,
    p_building_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_bld RECORD;
    v_floors JSONB := '[]'::JSONB;
    v_inspections JSONB := '[]'::JSONB;
    v_documents JSONB := '[]'::JSONB;
    v_total_rooms INT := 0;
    v_total_capacity INT := 0;
    v_current_occupancy INT := 0;
    v_occupancy_rate NUMERIC := 0.0;
BEGIN
    SELECT * INTO v_bld
    FROM public.buildings
    WHERE id = p_building_id
      AND school_id = p_school_id
      AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Building not found.');
    END IF;

    -- Aggregate rooms
    SELECT 
        COUNT(*),
        COALESCE(SUM(max_capacity), 0),
        COALESCE(SUM(current_occupancy), 0)
    INTO v_total_rooms, v_total_capacity, v_current_occupancy
    FROM public.rooms
    WHERE building_id = p_building_id AND deleted_at IS NULL;

    IF v_total_capacity > 0 THEN
        v_occupancy_rate := ROUND((v_current_occupancy::NUMERIC / v_total_capacity::NUMERIC) * 100.0, 1);
    END IF;

    -- Floors breakdown
    SELECT jsonb_agg(sub.f_obj)
    INTO v_floors
    FROM (
        SELECT jsonb_build_object(
            'id', f.id,
            'name', f.name,
            'floor_code', f.floor_code,
            'floor_level', f.floor_level,
            'floor_order', f.floor_order,
            'floor_type', f.floor_type,
            'area', f.area,
            'status', f.status,
            'total_rooms', COALESCE(r_cnt.cnt, 0),
            'capacity', COALESCE(r_cnt.cap, 0),
            'occupancy', COALESCE(r_cnt.occ, 0),
            'occupancy_percentage', CASE 
                WHEN COALESCE(r_cnt.cap, 0) > 0 
                THEN ROUND((COALESCE(r_cnt.occ, 0)::NUMERIC / r_cnt.cap::NUMERIC) * 100.0, 1) 
                ELSE 0.0 
            END,
            'room_types_summary', COALESCE(r_types.summary_str, 'None')
        ) AS f_obj
        FROM public.building_floors f
        LEFT JOIN LATERAL (
            SELECT 
                COUNT(*) AS cnt,
                SUM(r.max_capacity) AS cap,
                SUM(r.current_occupancy) AS occ
            FROM public.rooms r
            WHERE r.floor_id = f.id AND r.deleted_at IS NULL
        ) r_cnt ON TRUE
        LEFT JOIN LATERAL (
            SELECT string_agg(t.t_entry, ', ') AS summary_str
            FROM (
                SELECT r.room_type || ' (' || COUNT(*) || ')' AS t_entry
                FROM public.rooms r
                WHERE r.floor_id = f.id AND r.deleted_at IS NULL
                GROUP BY r.room_type
                ORDER BY COUNT(*) DESC
            ) t
        ) r_types ON TRUE
        WHERE f.building_id = p_building_id AND f.deleted_at IS NULL
        ORDER BY f.floor_level ASC, f.floor_order ASC
    ) sub;

    -- Recent Inspections
    SELECT jsonb_agg(row_to_json(i))
    INTO v_inspections
    FROM (
        SELECT id, inspection_type, inspection_date, inspector_name, result, next_inspection_date, findings, status
        FROM public.building_inspections
        WHERE building_id = p_building_id
        ORDER BY inspection_date DESC
        LIMIT 5
    ) i;

    -- Documents
    SELECT jsonb_agg(row_to_json(d))
    INTO v_documents
    FROM (
        SELECT id, document_name, document_type, file_url, issue_date, expiry_date, issuing_authority, status
        FROM public.building_documents
        WHERE building_id = p_building_id AND deleted_at IS NULL
        ORDER BY created_at DESC
    ) d;

    RETURN jsonb_build_object(
        'success', TRUE,
        'building', row_to_json(v_bld),
        'summary', jsonb_build_object(
            'total_floors', COALESCE(jsonb_array_length(v_floors), v_bld.total_floors),
            'total_rooms', v_total_rooms,
            'total_capacity', v_total_capacity,
            'current_occupancy', v_current_occupancy,
            'occupancy_rate', v_occupancy_rate
        ),
        'floors', COALESCE(v_floors, '[]'::JSONB),
        'inspections', COALESCE(v_inspections, '[]'::JSONB),
        'documents', COALESCE(v_documents, '[]'::JSONB)
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 4. Function: Upsert Building
-- ----------------------------------------------------------------------------
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
    v_result RECORD;
BEGIN
    IF v_name = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Building name is required.');
    END IF;

    IF v_code = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Building code is required.');
    END IF;

    IF v_id_txt <> '' THEN
        v_id := v_id_txt::UUID;
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
        -- UPDATE
        UPDATE public.buildings SET
            name = v_name,
            code = v_code,
            building_type = v_building_type,
            description = p_payload->>'description',
            purpose = p_payload->>'purpose',
            address = p_payload->>'address',
            latitude = (p_payload->>'latitude')::NUMERIC,
            longitude = (p_payload->>'longitude')::NUMERIC,
            total_floors = v_total_floors,
            total_area = v_total_area,
            area_unit = v_area_unit,
            construction_year = (p_payload->>'construction_year')::INT,
            num_entrances = GREATEST(1, COALESCE((p_payload->>'num_entrances')::INT, 1)),
            num_emergency_exits = GREATEST(0, COALESCE((p_payload->>'num_emergency_exits')::INT, 1)),
            manager_name = p_payload->>'manager_name',
            manager_contact = p_payload->>'manager_contact',
            department = p_payload->>'department',
            image_url = p_payload->>'image_url',
            fire_safety_cert_expiry = (p_payload->>'fire_safety_cert_expiry')::DATE,
            occupancy_cert_expiry = (p_payload->>'occupancy_cert_expiry')::DATE,
            status = v_status,
            notes = p_payload->>'notes',
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = v_id AND school_id = p_school_id AND deleted_at IS NULL
        RETURNING * INTO v_result;

        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', FALSE, 'message', 'Building not found for update.');
        END IF;
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
            p_user_id,
            p_user_id
        ) RETURNING * INTO v_result;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Building saved successfully.',
        'data', row_to_json(v_result)
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 5. Function: Archive or Delete Building
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_campus_archive_or_delete_building(
    p_school_id UUID,
    p_building_id UUID,
    p_action TEXT,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_active_rooms INT := 0;
    v_active_assignments INT := 0;
BEGIN
    IF LOWER(p_action) = 'archive' THEN
        UPDATE public.buildings
        SET status = 'Archived', updated_by = p_user_id, updated_at = NOW()
        WHERE id = p_building_id AND school_id = p_school_id AND deleted_at IS NULL;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Building successfully archived.');
    ELSIF LOWER(p_action) = 'delete' THEN
        -- Check active rooms
        SELECT COUNT(*) INTO v_active_rooms
        FROM public.rooms
        WHERE building_id = p_building_id AND deleted_at IS NULL;

        IF v_active_rooms > 0 THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'message', 'Cannot delete building because it contains ' || v_active_rooms || ' active room(s). Please archive the building or delete/reassign the rooms first.'
            );
        END IF;

        -- Check assignments referencing rooms of this building
        SELECT COUNT(a.id) INTO v_active_assignments
        FROM public.room_assignments a
        JOIN public.rooms r ON a.room_id = r.id
        WHERE r.building_id = p_building_id AND a.deleted_at IS NULL AND a.status = 'Active';

        IF v_active_assignments > 0 THEN
            RETURN jsonb_build_object(
                'success', FALSE,
                'message', 'Cannot delete building with active room allocations. Please archive the building instead.'
            );
        END IF;

        -- Safe soft delete
        UPDATE public.buildings
        SET deleted_at = NOW(), deleted_by = p_user_id, status = 'Archived'
        WHERE id = p_building_id AND school_id = p_school_id AND deleted_at IS NULL;

        RETURN jsonb_build_object('success', TRUE, 'message', 'Building successfully deleted.');
    ELSE
        RETURN jsonb_build_object('success', FALSE, 'message', 'Invalid action: must be archive or delete.');
    END IF;
END;
$$;


-- ----------------------------------------------------------------------------
-- 6. Function: List Floors
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_campus_list_floors(
    p_school_id UUID,
    p_building_id UUID,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total INT := 0;
    v_offset INT;
    v_floors JSONB := '[]'::JSONB;
BEGIN
    v_offset := GREATEST(0, (COALESCE(p_page, 1) - 1) * COALESCE(p_page_size, 10));

    SELECT COUNT(*) INTO v_total
    FROM public.building_floors
    WHERE building_id = p_building_id 
      AND school_id = p_school_id 
      AND deleted_at IS NULL;

    SELECT jsonb_agg(sub.f_obj)
    INTO v_floors
    FROM (
        SELECT jsonb_build_object(
            'id', f.id,
            'school_id', f.school_id,
            'building_id', f.building_id,
            'name', f.name,
            'floor_code', f.floor_code,
            'floor_level', f.floor_level,
            'floor_order', f.floor_order,
            'floor_type', f.floor_type,
            'area', f.area,
            'description', f.description,
            'status', f.status,
            'notes', f.notes,
            'total_rooms', COALESCE(r_cnt.cnt, 0),
            'capacity', COALESCE(r_cnt.cap, 0),
            'occupancy', COALESCE(r_cnt.occ, 0),
            'occupancy_percentage', CASE 
                WHEN COALESCE(r_cnt.cap, 0) > 0 
                THEN ROUND((COALESCE(r_cnt.occ, 0)::NUMERIC / r_cnt.cap::NUMERIC) * 100.0, 1) 
                ELSE 0.0 
            END,
            'room_types_summary', COALESCE(r_types.summary_str, 'None'),
            'maintenance_count', COALESCE(r_cnt.maint_cnt, 0)
        ) AS f_obj
        FROM public.building_floors f
        LEFT JOIN LATERAL (
            SELECT 
                COUNT(*) AS cnt,
                SUM(r.max_capacity) AS cap,
                SUM(r.current_occupancy) AS occ,
                COUNT(CASE WHEN r.operational_status = 'Under Maintenance' THEN 1 END) AS maint_cnt
            FROM public.rooms r
            WHERE r.floor_id = f.id AND r.deleted_at IS NULL
        ) r_cnt ON TRUE
        LEFT JOIN LATERAL (
            SELECT string_agg(t.t_entry, ', ') AS summary_str
            FROM (
                SELECT r.room_type || ' (' || COUNT(*) || ')' AS t_entry
                FROM public.rooms r
                WHERE r.floor_id = f.id AND r.deleted_at IS NULL
                GROUP BY r.room_type
                ORDER BY COUNT(*) DESC
            ) t
        ) r_types ON TRUE
        WHERE f.building_id = p_building_id 
          AND f.school_id = p_school_id 
          AND f.deleted_at IS NULL
        ORDER BY f.floor_level ASC, f.floor_order ASC
        LIMIT COALESCE(p_page_size, 10)
        OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'success', TRUE,
        'total_count', v_total,
        'page', COALESCE(p_page, 1),
        'page_size', COALESCE(p_page_size, 10),
        'data', COALESCE(v_floors, '[]'::JSONB)
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 7. Function: Upsert Floor
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_campus_upsert_floor(
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
    v_bld_id UUID := (p_payload->>'building_id')::UUID;
    v_name TEXT := TRIM(COALESCE(p_payload->>'name', ''));
    v_floor_code TEXT := UPPER(TRIM(COALESCE(p_payload->>'floor_code', '')));
    v_floor_level INT := COALESCE((p_payload->>'floor_level')::INT, 0);
    v_floor_order INT := COALESCE((p_payload->>'floor_order')::INT, 0);
    v_floor_type TEXT := COALESCE(p_payload->>'floor_type', 'Standard');
    v_area NUMERIC := GREATEST(0.0, COALESCE((p_payload->>'area')::NUMERIC, 0.0));
    v_status TEXT := COALESCE(p_payload->>'status', 'Active');
    v_result RECORD;
BEGIN
    IF v_bld_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Building ID is required.');
    END IF;

    IF v_name = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Floor name is required.');
    END IF;

    IF v_floor_code = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Floor code is required.');
    END IF;

    IF v_id_txt <> '' THEN
        v_id := v_id_txt::UUID;
    END IF;

    -- Duplicate check in building
    IF EXISTS (
        SELECT 1 FROM public.building_floors 
        WHERE building_id = v_bld_id 
          AND UPPER(floor_code) = v_floor_code 
          AND (v_id IS NULL OR id <> v_id) 
          AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Floor code ' || v_floor_code || ' already exists in this building.');
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.building_floors 
        WHERE building_id = v_bld_id 
          AND floor_level = v_floor_level 
          AND (v_id IS NULL OR id <> v_id) 
          AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Floor level ' || v_floor_level || ' already exists in this building.');
    END IF;

    IF v_id IS NOT NULL THEN
        UPDATE public.building_floors SET
            name = v_name,
            floor_code = v_floor_code,
            floor_level = v_floor_level,
            floor_order = v_floor_order,
            floor_type = v_floor_type,
            area = v_area,
            description = p_payload->>'description',
            status = v_status,
            notes = p_payload->>'notes',
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = v_id AND school_id = p_school_id AND deleted_at IS NULL
        RETURNING * INTO v_result;

        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', FALSE, 'message', 'Floor not found.');
        END IF;
    ELSE
        INSERT INTO public.building_floors (
            school_id,
            building_id,
            name,
            floor_code,
            floor_level,
            floor_order,
            floor_type,
            area,
            description,
            status,
            notes,
            created_by,
            updated_by
        ) VALUES (
            p_school_id,
            v_bld_id,
            v_name,
            v_floor_code,
            v_floor_level,
            v_floor_order,
            v_floor_type,
            v_area,
            p_payload->>'description',
            v_status,
            p_payload->>'notes',
            p_user_id,
            p_user_id
        ) RETURNING * INTO v_result;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Floor saved successfully.',
        'data', row_to_json(v_result)
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 8. Function: Delete Floor
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_campus_delete_floor(
    p_school_id UUID,
    p_floor_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_room_count INT := 0;
BEGIN
    SELECT COUNT(*) INTO v_room_count
    FROM public.rooms
    WHERE floor_id = p_floor_id AND deleted_at IS NULL;

    IF v_room_count > 0 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Cannot delete floor containing ' || v_room_count || ' room(s). Please remove or reassign the rooms first.'
        );
    END IF;

    UPDATE public.building_floors
    SET deleted_at = NOW(), deleted_by = p_user_id, status = 'Inactive'
    WHERE id = p_floor_id AND school_id = p_school_id AND deleted_at IS NULL;

    RETURN jsonb_build_object('success', TRUE, 'message', 'Floor deleted successfully.');
END;
$$;


-- ----------------------------------------------------------------------------
-- 9. Function: List Rooms (Search, Multi-Filter & Pagination)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_campus_list_rooms(
    p_school_id UUID,
    p_filters JSONB DEFAULT '{}'::JSONB,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search TEXT := TRIM(COALESCE(p_filters->>'search', ''));
    v_bld_id_txt TEXT := TRIM(COALESCE(p_filters->>'building_id', ''));
    v_bld_id UUID := NULL;
    v_floor_id_txt TEXT := TRIM(COALESCE(p_filters->>'floor_id', ''));
    v_floor_id UUID := NULL;
    v_room_type TEXT := TRIM(COALESCE(p_filters->>'room_type', ''));
    v_op_status TEXT := TRIM(COALESCE(p_filters->>'operational_status', ''));
    v_assign_status TEXT := TRIM(COALESCE(p_filters->>'assignment_status', ''));
    v_min_cap INT := COALESCE((p_filters->>'min_capacity')::INT, 0);
    v_max_cap INT := COALESCE((p_filters->>'max_capacity')::INT, 999999);
    v_offset INT;
    v_total INT := 0;
    v_rooms JSONB := '[]'::JSONB;
BEGIN
    IF v_bld_id_txt <> '' THEN v_bld_id := v_bld_id_txt::UUID; END IF;
    IF v_floor_id_txt <> '' THEN v_floor_id := v_floor_id_txt::UUID; END IF;

    v_offset := GREATEST(0, (COALESCE(p_page, 1) - 1) * COALESCE(p_page_size, 10));

    SELECT COUNT(*) INTO v_total
    FROM public.rooms r
    JOIN public.buildings b ON r.building_id = b.id AND b.deleted_at IS NULL
    JOIN public.building_floors f ON r.floor_id = f.id AND f.deleted_at IS NULL
    WHERE r.school_id = p_school_id
      AND r.deleted_at IS NULL
      AND (v_bld_id IS NULL OR r.building_id = v_bld_id)
      AND (v_floor_id IS NULL OR r.floor_id = v_floor_id)
      AND (v_room_type = '' OR LOWER(r.room_type) = LOWER(v_room_type))
      AND (v_op_status = '' OR LOWER(r.operational_status) = LOWER(v_op_status))
      AND (v_assign_status = '' OR LOWER(r.assignment_status) = LOWER(v_assign_status))
      AND (r.max_capacity BETWEEN v_min_cap AND v_max_cap)
      AND (
          v_search = '' OR
          r.name ILIKE '%' || v_search || '%' OR
          r.room_number ILIKE '%' || v_search || '%' OR
          r.room_code ILIKE '%' || v_search || '%' OR
          b.name ILIKE '%' || v_search || '%' OR
          f.name ILIKE '%' || v_search || '%'
      );

    SELECT jsonb_agg(sub.item)
    INTO v_rooms
    FROM (
        SELECT jsonb_build_object(
            'id', r.id,
            'school_id', r.school_id,
            'building_id', r.building_id,
            'building_name', b.name,
            'building_code', b.code,
            'floor_id', r.floor_id,
            'floor_name', f.name,
            'floor_level', f.floor_level,
            'name', r.name,
            'room_number', r.room_number,
            'room_code', r.room_code,
            'room_type', r.room_type,
            'description', r.description,
            'purpose', r.purpose,
            'area', r.area,
            'area_unit', r.area_unit,
            'length', r.length,
            'width', r.width,
            'height', r.height,
            'max_capacity', r.max_capacity,
            'recommended_capacity', r.recommended_capacity,
            'current_occupancy', r.current_occupancy,
            'bed_count', r.bed_count,
            'seating_capacity', r.seating_capacity,
            'workstation_count', r.workstation_count,
            'num_doors', r.num_doors,
            'num_windows', r.num_windows,
            'operational_status', r.operational_status,
            'assignment_status', r.assignment_status,
            'is_differently_abled_accessible', r.is_differently_abled_accessible,
            'lift_proximity', r.lift_proximity,
            'emergency_exit_proximity', r.emergency_exit_proximity,
            'location_notes', r.location_notes,
            'image_url', r.image_url,
            'responsible_department', r.responsible_department,
            'responsible_person_name', r.responsible_person_name,
            'equipment_count', COALESCE(eq_agg.eq_cnt, 0),
            'equipment_not_working', COALESCE(eq_agg.not_working_cnt, 0),
            'equipment_summary', COALESCE(eq_agg.eq_str, 'None'),
            'created_at', r.created_at,
            'updated_at', r.updated_at
        ) AS item
        FROM public.rooms r
        JOIN public.buildings b ON r.building_id = b.id AND b.deleted_at IS NULL
        JOIN public.building_floors f ON r.floor_id = f.id AND f.deleted_at IS NULL
        LEFT JOIN LATERAL (
            SELECT 
                COUNT(*) AS eq_cnt,
                COUNT(CASE WHEN e.operational_status IN ('Not Working', 'Under Maintenance', 'Damaged') THEN 1 END) AS not_working_cnt,
                string_agg(e.equipment_name || ' (' || e.quantity || ')', ', ') AS eq_str
            FROM public.room_equipment e
            WHERE e.room_id = r.id AND e.deleted_at IS NULL
        ) eq_agg ON TRUE
        WHERE r.school_id = p_school_id
          AND r.deleted_at IS NULL
          AND (v_bld_id IS NULL OR r.building_id = v_bld_id)
          AND (v_floor_id IS NULL OR r.floor_id = v_floor_id)
          AND (v_room_type = '' OR LOWER(r.room_type) = LOWER(v_room_type))
          AND (v_op_status = '' OR LOWER(r.operational_status) = LOWER(v_op_status))
          AND (v_assign_status = '' OR LOWER(r.assignment_status) = LOWER(v_assign_status))
          AND (r.max_capacity BETWEEN v_min_cap AND v_max_cap)
          AND (
              v_search = '' OR
              r.name ILIKE '%' || v_search || '%' OR
              r.room_number ILIKE '%' || v_search || '%' OR
              r.room_code ILIKE '%' || v_search || '%' OR
              b.name ILIKE '%' || v_search || '%' OR
              f.name ILIKE '%' || v_search || '%'
          )
        ORDER BY r.room_number ASC, r.name ASC
        LIMIT COALESCE(p_page_size, 10)
        OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'success', TRUE,
        'total_count', v_total,
        'page', COALESCE(p_page, 1),
        'page_size', COALESCE(p_page_size, 10),
        'data', COALESCE(v_rooms, '[]'::JSONB)
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 10. Function: Get Room Details
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_campus_get_room_details(
    p_school_id UUID,
    p_room_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_rm RECORD;
    v_bld RECORD;
    v_flr RECORD;
    v_eq JSONB := '[]'::JSONB;
    v_assign JSONB := '[]'::JSONB;
    v_docs JSONB := '[]'::JSONB;
BEGIN
    SELECT * INTO v_rm
    FROM public.rooms
    WHERE id = p_room_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Room not found.');
    END IF;

    SELECT name, code, building_type INTO v_bld
    FROM public.buildings WHERE id = v_rm.building_id;

    SELECT name, floor_code, floor_level INTO v_flr
    FROM public.building_floors WHERE id = v_rm.floor_id;

    -- Equipment
    SELECT jsonb_agg(row_to_json(e))
    INTO v_eq
    FROM (
        SELECT id, equipment_name, equipment_category, asset_id, quantity, condition, operational_status, installation_date, last_service_date, next_service_date, remarks
        FROM public.room_equipment
        WHERE room_id = p_room_id AND deleted_at IS NULL
        ORDER BY equipment_category ASC, equipment_name ASC
    ) e;

    -- Assignments
    SELECT jsonb_agg(row_to_json(a))
    INTO v_assign
    FROM (
        SELECT id, reference_module, reference_name, assignment_purpose, start_date, end_date, status, assigned_to_name, notes
        FROM public.room_assignments
        WHERE room_id = p_room_id AND deleted_at IS NULL
        ORDER BY created_at DESC
    ) a;

    -- Documents
    SELECT jsonb_agg(row_to_json(d))
    INTO v_docs
    FROM (
        SELECT id, document_name, document_type, file_url, status
        FROM public.building_documents
        WHERE room_id = p_room_id AND deleted_at IS NULL
    ) d;

    RETURN jsonb_build_object(
        'success', TRUE,
        'room', row_to_json(v_rm),
        'building', row_to_json(v_bld),
        'floor', row_to_json(v_flr),
        'equipment', COALESCE(v_eq, '[]'::JSONB),
        'assignments', COALESCE(v_assign, '[]'::JSONB),
        'documents', COALESCE(v_docs, '[]'::JSONB)
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 11. Function: Upsert Room
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_campus_upsert_room(
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
    v_bld_id UUID := (p_payload->>'building_id')::UUID;
    v_floor_id UUID := (p_payload->>'floor_id')::UUID;
    v_room_num TEXT := TRIM(COALESCE(p_payload->>'room_number', ''));
    v_name TEXT := TRIM(COALESCE(p_payload->>'name', ''));
    v_room_code TEXT := UPPER(TRIM(COALESCE(p_payload->>'room_code', '')));
    v_room_type TEXT := COALESCE(p_payload->>'room_type', 'Classroom');
    v_max_cap INT := GREATEST(0, COALESCE((p_payload->>'max_capacity')::INT, 40));
    v_rec_cap INT := GREATEST(0, COALESCE((p_payload->>'recommended_capacity')::INT, 35));
    v_curr_occ INT := GREATEST(0, COALESCE((p_payload->>'current_occupancy')::INT, 0));
    v_bed_cnt INT := GREATEST(0, COALESCE((p_payload->>'bed_count')::INT, 0));
    v_seat_cnt INT := GREATEST(0, COALESCE((p_payload->>'seating_capacity')::INT, 40));
    v_wk_cnt INT := GREATEST(0, COALESCE((p_payload->>'workstation_count')::INT, 0));
    v_op_status TEXT := COALESCE(p_payload->>'operational_status', 'Available');
    v_assign_status TEXT := COALESCE(p_payload->>'assignment_status', 'Unassigned');
    v_result RECORD;
BEGIN
    IF v_bld_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Building ID is required.');
    END IF;

    IF v_floor_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Floor ID is required.');
    END IF;

    IF v_room_num = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Room number is required.');
    END IF;

    IF v_name = '' THEN
        v_name := 'Room ' || v_room_num;
    END IF;

    IF v_room_code = '' THEN
        v_room_code := 'RM-' || v_room_num;
    END IF;

    IF v_id_txt <> '' THEN
        v_id := v_id_txt::UUID;
    END IF;

    -- Verify floor belongs to building
    IF NOT EXISTS (
        SELECT 1 FROM public.building_floors 
        WHERE id = v_floor_id AND building_id = v_bld_id AND school_id = p_school_id AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Selected floor does not belong to the selected building.');
    END IF;

    -- Duplicate room number in building
    IF EXISTS (
        SELECT 1 FROM public.rooms 
        WHERE building_id = v_bld_id 
          AND UPPER(room_number) = UPPER(v_room_num) 
          AND (v_id IS NULL OR id <> v_id) 
          AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Room number ' || v_room_num || ' already exists in this building.');
    END IF;

    IF v_id IS NOT NULL THEN
        UPDATE public.rooms SET
            building_id = v_bld_id,
            floor_id = v_floor_id,
            name = v_name,
            room_number = v_room_num,
            room_code = v_room_code,
            room_type = v_room_type,
            description = p_payload->>'description',
            purpose = p_payload->>'purpose',
            area = GREATEST(0.0, COALESCE((p_payload->>'area')::NUMERIC, 0.0)),
            area_unit = COALESCE(p_payload->>'area_unit', 'sq ft'),
            length = GREATEST(0.0, COALESCE((p_payload->>'length')::NUMERIC, 0.0)),
            width = GREATEST(0.0, COALESCE((p_payload->>'width')::NUMERIC, 0.0)),
            height = GREATEST(0.0, COALESCE((p_payload->>'height')::NUMERIC, 0.0)),
            max_capacity = v_max_cap,
            recommended_capacity = v_rec_cap,
            current_occupancy = v_curr_occ,
            bed_count = v_bed_cnt,
            seating_capacity = v_seat_cnt,
            workstation_count = v_wk_cnt,
            num_doors = GREATEST(1, COALESCE((p_payload->>'num_doors')::INT, 1)),
            num_windows = GREATEST(0, COALESCE((p_payload->>'num_windows')::INT, 2)),
            operational_status = v_op_status,
            assignment_status = v_assign_status,
            is_differently_abled_accessible = COALESCE((p_payload->>'is_differently_abled_accessible')::BOOLEAN, TRUE),
            lift_proximity = COALESCE(p_payload->>'lift_proximity', 'Nearby'),
            emergency_exit_proximity = COALESCE(p_payload->>'emergency_exit_proximity', 'Direct Access'),
            location_notes = p_payload->>'location_notes',
            image_url = p_payload->>'image_url',
            responsible_department = p_payload->>'responsible_department',
            responsible_person_name = p_payload->>'responsible_person_name',
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = v_id AND school_id = p_school_id AND deleted_at IS NULL
        RETURNING * INTO v_result;

        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', FALSE, 'message', 'Room not found.');
        END IF;
    ELSE
        INSERT INTO public.rooms (
            school_id,
            building_id,
            floor_id,
            name,
            room_number,
            room_code,
            room_type,
            description,
            purpose,
            area,
            area_unit,
            length,
            width,
            height,
            max_capacity,
            recommended_capacity,
            current_occupancy,
            bed_count,
            seating_capacity,
            workstation_count,
            num_doors,
            num_windows,
            operational_status,
            assignment_status,
            is_differently_abled_accessible,
            lift_proximity,
            emergency_exit_proximity,
            location_notes,
            image_url,
            responsible_department,
            responsible_person_name,
            created_by,
            updated_by
        ) VALUES (
            p_school_id,
            v_bld_id,
            v_floor_id,
            v_name,
            v_room_num,
            v_room_code,
            v_room_type,
            p_payload->>'description',
            p_payload->>'purpose',
            GREATEST(0.0, COALESCE((p_payload->>'area')::NUMERIC, 0.0)),
            COALESCE(p_payload->>'area_unit', 'sq ft'),
            GREATEST(0.0, COALESCE((p_payload->>'length')::NUMERIC, 0.0)),
            GREATEST(0.0, COALESCE((p_payload->>'width')::NUMERIC, 0.0)),
            GREATEST(0.0, COALESCE((p_payload->>'height')::NUMERIC, 0.0)),
            v_max_cap,
            v_rec_cap,
            v_curr_occ,
            v_bed_cnt,
            v_seat_cnt,
            v_wk_cnt,
            GREATEST(1, COALESCE((p_payload->>'num_doors')::INT, 1)),
            GREATEST(0, COALESCE((p_payload->>'num_windows')::INT, 2)),
            v_op_status,
            v_assign_status,
            COALESCE((p_payload->>'is_differently_abled_accessible')::BOOLEAN, TRUE),
            COALESCE(p_payload->>'lift_proximity', 'Nearby'),
            COALESCE(p_payload->>'emergency_exit_proximity', 'Direct Access'),
            p_payload->>'location_notes',
            p_payload->>'image_url',
            p_payload->>'responsible_department',
            p_payload->>'responsible_person_name',
            p_user_id,
            p_user_id
        ) RETURNING * INTO v_result;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Room saved successfully.',
        'data', row_to_json(v_result)
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 12. Function: Bulk Create Rooms
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_campus_bulk_create_rooms(
    p_school_id UUID,
    p_payload JSONB,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_bld_id UUID := (p_payload->>'building_id')::UUID;
    v_floor_id UUID := (p_payload->>'floor_id')::UUID;
    v_room_type TEXT := COALESCE(p_payload->>'room_type', 'Classroom');
    v_capacity INT := GREATEST(0, COALESCE((p_payload->>'default_capacity')::INT, 40));
    v_room_numbers JSONB := p_payload->'room_numbers';
    v_facilities JSONB := p_payload->'common_facilities';
    v_num_item JSONB;
    v_num_str TEXT;
    v_new_room RECORD;
    v_fac_item JSONB;
    v_created_rooms JSONB := '[]'::JSONB;
    v_duplicates JSONB := '[]'::JSONB;
    v_created_cnt INT := 0;
BEGIN
    IF v_bld_id IS NULL OR v_floor_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Building ID and Floor ID are required.');
    END IF;

    IF v_room_numbers IS NULL OR jsonb_array_length(v_room_numbers) = 0 THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'At least one room number must be provided.');
    END IF;

    -- Validate floor belongs to building
    IF NOT EXISTS (
        SELECT 1 FROM public.building_floors 
        WHERE id = v_floor_id AND building_id = v_bld_id AND school_id = p_school_id AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Selected floor does not belong to the selected building.');
    END IF;

    -- Check for duplicates first
    FOR v_num_item IN SELECT * FROM jsonb_array_elements(v_room_numbers)
    LOOP
        v_num_str := TRIM(v_num_item #>> '{}');
        IF v_num_str <> '' AND EXISTS (
            SELECT 1 FROM public.rooms 
            WHERE building_id = v_bld_id 
              AND UPPER(room_number) = UPPER(v_num_str) 
              AND deleted_at IS NULL
        ) THEN
            v_duplicates := v_duplicates || to_jsonb(v_num_str);
        END IF;
    END LOOP;

    IF jsonb_array_length(v_duplicates) > 0 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'message', 'Duplicate room numbers found: ' || (v_duplicates::TEXT),
            'duplicates', v_duplicates
        );
    END IF;

    -- Insert rooms
    FOR v_num_item IN SELECT * FROM jsonb_array_elements(v_room_numbers)
    LOOP
        v_num_str := TRIM(v_num_item #>> '{}');
        IF v_num_str <> '' THEN
            INSERT INTO public.rooms (
                school_id,
                building_id,
                floor_id,
                name,
                room_number,
                room_code,
                room_type,
                max_capacity,
                recommended_capacity,
                seating_capacity,
                operational_status,
                created_by,
                updated_by
            ) VALUES (
                p_school_id,
                v_bld_id,
                v_floor_id,
                v_room_type || ' ' || v_num_str,
                v_num_str,
                'RM-' || v_num_str,
                v_room_type,
                v_capacity,
                GREATEST(0, v_capacity - 5),
                v_capacity,
                'Available',
                p_user_id,
                p_user_id
            ) RETURNING * INTO v_new_room;

            v_created_cnt := v_created_cnt + 1;
            v_created_rooms := v_created_rooms || jsonb_build_object(
                'id', v_new_room.id,
                'room_number', v_new_room.room_number,
                'name', v_new_room.name,
                'capacity', v_new_room.max_capacity
            );

            -- Add common facilities if provided
            IF v_facilities IS NOT NULL AND jsonb_array_length(v_facilities) > 0 THEN
                FOR v_fac_item IN SELECT * FROM jsonb_array_elements(v_facilities)
                LOOP
                    INSERT INTO public.room_equipment (
                        school_id,
                        building_id,
                        floor_id,
                        room_id,
                        equipment_name,
                        equipment_category,
                        quantity,
                        operational_status,
                        created_by,
                        updated_by
                    ) VALUES (
                        p_school_id,
                        v_bld_id,
                        v_floor_id,
                        v_new_room.id,
                        TRIM(v_fac_item #>> '{}'),
                        'General Fixture',
                        1,
                        'Operational',
                        p_user_id,
                        p_user_id
                    );
                END LOOP;
            END IF;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Successfully created ' || v_created_cnt || ' room(s).',
        'created_count', v_created_cnt,
        'rooms', v_created_rooms
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 13. Function: Bulk Import Rooms
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_campus_bulk_import_rooms(
    p_school_id UUID,
    p_rows JSONB,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_row JSONB;
    v_bld_code TEXT;
    v_floor_code TEXT;
    v_room_num TEXT;
    v_room_name TEXT;
    v_room_type TEXT;
    v_capacity INT;
    v_bld_id UUID;
    v_floor_id UUID;
    v_imported_cnt INT := 0;
    v_failed_cnt INT := 0;
    v_errors JSONB := '[]'::JSONB;
    v_row_idx INT := 0;
BEGIN
    FOR v_row IN SELECT * FROM jsonb_array_elements(p_rows)
    LOOP
        v_row_idx := v_row_idx + 1;
        v_bld_code := UPPER(TRIM(COALESCE(v_row->>'building_code', '')));
        v_floor_code := UPPER(TRIM(COALESCE(v_row->>'floor_code', '')));
        v_room_num := TRIM(COALESCE(v_row->>'room_number', ''));
        v_room_name := TRIM(COALESCE(v_row->>'room_name', ''));
        v_room_type := COALESCE(v_row->>'room_type', 'Classroom');
        v_capacity := GREATEST(0, COALESCE((v_row->>'capacity')::INT, 40));

        IF v_bld_code = '' OR v_floor_code = '' OR v_room_num = '' THEN
            v_failed_cnt := v_failed_cnt + 1;
            v_errors := v_errors || jsonb_build_object(
                'row', v_row_idx,
                'error', 'Missing building_code, floor_code, or room_number.'
            );
            CONTINUE;
        END IF;

        -- Resolve Building
        SELECT id INTO v_bld_id
        FROM public.buildings
        WHERE school_id = p_school_id AND UPPER(code) = v_bld_code AND deleted_at IS NULL;

        IF v_bld_id IS NULL THEN
            v_failed_cnt := v_failed_cnt + 1;
            v_errors := v_errors || jsonb_build_object(
                'row', v_row_idx,
                'error', 'Building not found for code: ' || v_bld_code
            );
            CONTINUE;
        END IF;

        -- Resolve Floor
        SELECT id INTO v_floor_id
        FROM public.building_floors
        WHERE building_id = v_bld_id AND UPPER(floor_code) = v_floor_code AND deleted_at IS NULL;

        IF v_floor_id IS NULL THEN
            v_failed_cnt := v_failed_cnt + 1;
            v_errors := v_errors || jsonb_build_object(
                'row', v_row_idx,
                'error', 'Floor not found for code: ' || v_floor_code || ' in building ' || v_bld_code
            );
            CONTINUE;
        END IF;

        -- Check duplicate
        IF EXISTS (
            SELECT 1 FROM public.rooms 
            WHERE building_id = v_bld_id AND UPPER(room_number) = UPPER(v_room_num) AND deleted_at IS NULL
        ) THEN
            v_failed_cnt := v_failed_cnt + 1;
            v_errors := v_errors || jsonb_build_object(
                'row', v_row_idx,
                'error', 'Room number ' || v_room_num || ' already exists in building ' || v_bld_code
            );
            CONTINUE;
        END IF;

        IF v_room_name = '' THEN
            v_room_name := v_room_type || ' ' || v_room_num;
        END IF;

        -- Insert room
        INSERT INTO public.rooms (
            school_id,
            building_id,
            floor_id,
            name,
            room_number,
            room_code,
            room_type,
            max_capacity,
            recommended_capacity,
            seating_capacity,
            operational_status,
            created_by,
            updated_by
        ) VALUES (
            p_school_id,
            v_bld_id,
            v_floor_id,
            v_room_name,
            v_room_num,
            'RM-' || v_room_num,
            v_room_type,
            v_capacity,
            GREATEST(0, v_capacity - 5),
            v_capacity,
            COALESCE(v_row->>'status', 'Available'),
            p_user_id,
            p_user_id
        );

        v_imported_cnt := v_imported_cnt + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', TRUE,
        'imported_count', v_imported_cnt,
        'failed_count', v_failed_cnt,
        'errors', v_errors
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 14. Function: Upsert Room Equipment
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_campus_upsert_equipment(
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
    v_room_id UUID := (p_payload->>'room_id')::UUID;
    v_name TEXT := TRIM(COALESCE(p_payload->>'equipment_name', ''));
    v_cat TEXT := COALESCE(p_payload->>'equipment_category', 'General Fixture');
    v_qty INT := GREATEST(1, COALESCE((p_payload->>'quantity')::INT, 1));
    v_cond TEXT := COALESCE(p_payload->>'condition', 'Good');
    v_op_status TEXT := COALESCE(p_payload->>'operational_status', 'Operational');
    v_bld_id UUID;
    v_floor_id UUID;
    v_result RECORD;
BEGIN
    IF v_room_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Room ID is required.');
    END IF;

    IF v_name = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Equipment name is required.');
    END IF;

    SELECT building_id, floor_id INTO v_bld_id, v_floor_id
    FROM public.rooms
    WHERE id = v_room_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF v_bld_id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Room not found.');
    END IF;

    IF v_id_txt <> '' THEN
        v_id := v_id_txt::UUID;
    END IF;

    IF v_id IS NOT NULL THEN
        UPDATE public.room_equipment SET
            equipment_name = v_name,
            equipment_category = v_cat,
            asset_id = NULLIF(p_payload->>'asset_id', '')::UUID,
            quantity = v_qty,
            condition = v_cond,
            operational_status = v_op_status,
            installation_date = (p_payload->>'installation_date')::DATE,
            last_service_date = (p_payload->>'last_service_date')::DATE,
            next_service_date = (p_payload->>'next_service_date')::DATE,
            remarks = p_payload->>'remarks',
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = v_id AND school_id = p_school_id AND deleted_at IS NULL
        RETURNING * INTO v_result;

        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', FALSE, 'message', 'Equipment record not found.');
        END IF;
    ELSE
        INSERT INTO public.room_equipment (
            school_id,
            building_id,
            floor_id,
            room_id,
            equipment_name,
            equipment_category,
            asset_id,
            quantity,
            condition,
            operational_status,
            installation_date,
            last_service_date,
            next_service_date,
            remarks,
            created_by,
            updated_by
        ) VALUES (
            p_school_id,
            v_bld_id,
            v_floor_id,
            v_room_id,
            v_name,
            v_cat,
            NULLIF(p_payload->>'asset_id', '')::UUID,
            v_qty,
            v_cond,
            v_op_status,
            (p_payload->>'installation_date')::DATE,
            (p_payload->>'last_service_date')::DATE,
            (p_payload->>'next_service_date')::DATE,
            p_payload->>'remarks',
            p_user_id,
            p_user_id
        ) RETURNING * INTO v_result;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Equipment saved successfully.',
        'data', row_to_json(v_result)
    );
END;
$$;


-- ----------------------------------------------------------------------------
-- 15. Function: Delete Room Equipment
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_campus_delete_equipment(
    p_school_id UUID,
    p_equipment_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.room_equipment
    SET deleted_at = NOW(), deleted_by = p_user_id
    WHERE id = p_equipment_id AND school_id = p_school_id AND deleted_at IS NULL;

    RETURN jsonb_build_object('success', TRUE, 'message', 'Equipment record removed.');
END;
$$;


-- ----------------------------------------------------------------------------
-- 16. Function: Get Lookups & Metadata
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_campus_get_lookups(
    p_school_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN jsonb_build_object(
        'building_types', jsonb_build_array(
            'Academic', 'Administrative', 'Residential', 'Hostel', 'Library',
            'Laboratory', 'Sports', 'Auditorium', 'Dining / Canteen', 'Medical',
            'Utility', 'Storage', 'Other'
        ),
        'building_statuses', jsonb_build_array(
            'Active', 'Under Construction', 'Under Renovation', 'Temporarily Closed', 'Inactive', 'Archived'
        ),
        'room_types', jsonb_build_array(
            'Classroom', 'Smart Classroom', 'Lecture Hall', 'Seminar Room', 'Examination Hall',
            'Physics Lab', 'Chemistry Lab', 'Biology Lab', 'Computer Lab', 'Language Lab', 'Research Lab',
            'Principal Office', 'Staff Room', 'Faculty Room', 'Reception', 'Meeting Room', 'Administrative Office',
            'Library', 'Reading Room', 'Digital Library', 'Book Storage',
            'Hostel Room', 'Dormitory', 'Warden Room', 'Guest Room', 'Common Room',
            'Washroom', 'Toilet', 'Bathroom', 'Accessible Washroom',
            'Electrical Room', 'Generator Room', 'Water Pump Room', 'Server Room', 'HVAC Room', 'Maintenance Room',
            'General Store', 'Equipment Store', 'Furniture Store', 'Laboratory Store', 'Inventory Warehouse',
            'Auditorium', 'Conference Hall', 'Canteen', 'Kitchen', 'Medical Room', 'Sports Room', 'Gymnasium',
            'Prayer / Multipurpose Room', 'Parking Space', 'Other'
        ),
        'room_statuses', jsonb_build_array(
            'Available', 'Occupied', 'Reserved', 'Under Maintenance', 'Temporarily Unavailable', 'Inactive'
        ),
        'assignment_statuses', jsonb_build_array(
            'Unassigned', 'Assigned', 'Partially Assigned', 'Reserved'
        ),
        'equipment_categories', jsonb_build_array(
            'Electrical', 'IT & AV', 'Furniture', 'Plumbing & Sanitation',
            'Safety & Medical', 'HVAC', 'Laboratory', 'General Fixture'
        ),
        'equipment_conditions', jsonb_build_array(
            'New', 'Excellent', 'Good', 'Fair', 'Poor', 'Damaged'
        ),
        'equipment_statuses', jsonb_build_array(
            'Operational', 'Not Working', 'Under Maintenance', 'Degraded', 'Decommissioned'
        ),
        'area_units', jsonb_build_array(
            'sq ft', 'sq m'
        )
    );
END;
$$;
