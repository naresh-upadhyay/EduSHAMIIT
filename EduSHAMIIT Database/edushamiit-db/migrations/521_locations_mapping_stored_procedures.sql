-- Migration 521: Locations & Mapping Enterprise Stored Procedures, Functions and Dynamic Sync
-- Replaces all inline queries in locations and mapping endpoints with robust stored procedures

-- ============================================================================
-- 1. Function: fn_get_locations_kpis
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_get_locations_kpis(p_school_id UUID DEFAULT '11111111-1111-1111-1111-111111111111'::UUID)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_buildings INT := 0;
    v_floors INT := 0;
    v_rooms INT := 0;
    v_total_devs INT := 0;
    v_mapped_devs INT := 0;
    v_unmapped_devs INT := 0;
    v_mapped_pct NUMERIC := 0.0;
    v_unmapped_pct NUMERIC := 0.0;
    v_loc_with_devs INT := 0;
    v_coverage_pct NUMERIC := 0.0;
BEGIN
    SELECT COUNT(*) INTO v_buildings FROM buildings WHERE school_id = p_school_id AND deleted_at IS NULL;
    SELECT COUNT(*) INTO v_floors FROM building_floors WHERE school_id = p_school_id AND deleted_at IS NULL;
    SELECT COUNT(*) INTO v_rooms FROM rooms WHERE school_id = p_school_id AND deleted_at IS NULL;
    
    SELECT COUNT(*) INTO v_total_devs FROM devices WHERE school_id = p_school_id AND deleted_at IS NULL;
    SELECT COUNT(*) INTO v_mapped_devs FROM devices WHERE school_id = p_school_id AND deleted_at IS NULL AND floor_id IS NOT NULL;
    v_unmapped_devs := GREATEST(0, v_total_devs - v_mapped_devs);
    
    IF v_total_devs > 0 THEN
        v_mapped_pct := ROUND((v_mapped_devs::NUMERIC / v_total_devs) * 100, 1);
        v_unmapped_pct := ROUND((v_unmapped_devs::NUMERIC / v_total_devs) * 100, 1);
    END IF;
    
    SELECT COUNT(DISTINCT room_id) INTO v_loc_with_devs 
    FROM devices 
    WHERE school_id = p_school_id AND deleted_at IS NULL AND room_id IS NOT NULL;
    
    IF v_rooms > 0 THEN
        v_coverage_pct := ROUND((v_loc_with_devs::NUMERIC / v_rooms) * 100, 1);
    END IF;
    
    RETURN jsonb_build_object(
        'buildings', v_buildings,
        'floors', v_floors,
        'rooms', v_rooms,
        'total_devices', v_total_devs,
        'mapped_devices', v_mapped_devs,
        'mapped_pct', v_mapped_pct,
        'unmapped_devices', v_unmapped_devs,
        'unmapped_pct', v_unmapped_pct,
        'locations_with_devices', v_loc_with_devs,
        'coverage_pct', v_coverage_pct
    );
END;
$$;


-- ============================================================================
-- 2. Function: fn_get_locations_hierarchy
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_get_locations_hierarchy(p_school_id UUID DEFAULT '11111111-1111-1111-1111-111111111111'::UUID)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_building_nodes JSONB := '[]'::JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(b_obj), '[]'::JSONB) INTO v_building_nodes
    FROM (
        SELECT jsonb_build_object(
            'id', b.id,
            'name', b.name,
            'code', COALESCE(b.code, ''),
            'building_type', COALESCE(b.building_type, 'Academic'),
            'device_count', COALESCE(b_devs.cnt, 0),
            'room_count', COALESCE(b_rooms.cnt, 0),
            'level', 1,
            'type', 'building',
            'children', COALESCE(floors_agg.floors, '[]'::JSONB)
        ) AS b_obj
        FROM buildings b
        LEFT JOIN LATERAL (
            SELECT COUNT(d.id) AS cnt 
            FROM devices d 
            WHERE d.building_id = b.id AND d.deleted_at IS NULL
        ) b_devs ON true
        LEFT JOIN LATERAL (
            SELECT COUNT(r.id) AS cnt 
            FROM rooms r 
            WHERE r.building_id = b.id AND r.deleted_at IS NULL
        ) b_rooms ON true
        LEFT JOIN LATERAL (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', f.id,
                    'building_id', f.building_id,
                    'name', f.name,
                    'code', COALESCE(f.floor_code, ''),
                    'level', COALESCE(f.floor_level, 0),
                    'device_count', COALESCE(f_devs.cnt, 0),
                    'room_count', COALESCE(f_rooms.cnt, 0),
                    'type', 'floor',
                    'children', COALESCE(rooms_agg.rooms, '[]'::JSONB)
                ) ORDER BY COALESCE(f.floor_level, 0) ASC
            ) AS floors
            FROM building_floors f
            LEFT JOIN LATERAL (
                SELECT COUNT(d.id) AS cnt 
                FROM devices d 
                WHERE d.floor_id = f.id AND d.deleted_at IS NULL
            ) f_devs ON true
            LEFT JOIN LATERAL (
                SELECT COUNT(r.id) AS cnt 
                FROM rooms r 
                WHERE r.floor_id = f.id AND r.deleted_at IS NULL
            ) f_rooms ON true
            LEFT JOIN LATERAL (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', r.id,
                        'name', COALESCE(r.room_number, '') || ' (' || COALESCE(r.name, '') || ')',
                        'code', COALESCE(r.room_number, ''),
                        'room_name', COALESCE(r.name, ''),
                        'room_type', COALESCE(r.room_type, 'Classroom'),
                        'floor_id', f.id,
                        'device_count', COALESCE(r_devs.cnt, 0),
                        'room_count', 0,
                        'level', 3,
                        'type', 'room',
                        'children', '[]'::JSONB
                    ) ORDER BY r.room_number ASC
                ) AS rooms
                FROM rooms r
                LEFT JOIN LATERAL (
                    SELECT COUNT(d.id) AS cnt 
                    FROM devices d 
                    WHERE d.room_id = r.id AND d.deleted_at IS NULL
                ) r_devs ON true
                WHERE r.floor_id = f.id AND r.deleted_at IS NULL
            ) rooms_agg ON true
            WHERE f.building_id = b.id AND f.deleted_at IS NULL
        ) floors_agg ON true
        WHERE b.school_id = p_school_id AND b.deleted_at IS NULL
        ORDER BY 
            CASE 
                WHEN POSITION('Admin' IN b.name) > 0 THEN 1
                WHEN POSITION('Academic Block (A)' IN b.name) > 0 THEN 2
                WHEN POSITION('Academic' IN b.name) > 0 THEN 3
                WHEN POSITION('Lab' IN b.name) > 0 THEN 4
                WHEN POSITION('Library' IN b.name) > 0 THEN 5
                WHEN POSITION('Auditorium' IN b.name) > 0 THEN 6
                WHEN POSITION('Sports' IN b.name) > 0 THEN 7
                ELSE 8
            END
    ) t;

    RETURN jsonb_build_object(
        'success', true,
        'tree', jsonb_build_object(
            'id', p_school_id,
            'name', 'Greenwood High School',
            'type', 'campus',
            'total_buildings', jsonb_array_length(v_building_nodes),
            'children', v_building_nodes
        )
    );
END;
$$;


-- ============================================================================
-- 3. Function: fn_get_location_details
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_get_location_details(
    p_floor_id UUID,
    p_school_id UUID DEFAULT '11111111-1111-1111-1111-111111111111'::UUID
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_floor RECORD;
    v_building RECORD;
    v_total_rooms INT := 0;
    v_mapped_devs INT := 0;
    v_unmapped_devs INT := 0;
    v_groups_assigned INT := 0;
    v_profiles_in_use INT := 0;
    v_loc_with_devs INT := 0;
    v_coverage_pct NUMERIC := 0.0;
    v_rooms_list JSONB := '[]'::JSONB;
    v_assigned_groups JSONB := '[]'::JSONB;
BEGIN
    SELECT f.id, f.name, f.floor_code, COALESCE(f.floor_level, 1) as floor_level, f.building_id
    INTO v_floor
    FROM building_floors f
    WHERE f.id = p_floor_id;

    IF v_floor.id IS NULL THEN
        SELECT f.id, f.name, f.floor_code, COALESCE(f.floor_level, 1) as floor_level, f.building_id
        INTO v_floor
        FROM building_floors f
        WHERE f.school_id = p_school_id AND f.deleted_at IS NULL
        ORDER BY f.floor_level ASC LIMIT 1;
    END IF;

    SELECT b.id, b.name, b.code
    INTO v_building
    FROM buildings b
    WHERE b.id = v_floor.building_id;

    -- Rooms on this floor
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', r.id,
            'room_number', r.room_number,
            'name', r.name,
            'room_type', r.room_type,
            'capacity', COALESCE(r.max_capacity, 40),
            'status', COALESCE(r.operational_status, 'Active'),
            'device_count', COALESCE(r_devs.cnt, 0)
        ) ORDER BY r.room_number ASC
    ), '[]'::JSONB), COUNT(*)
    INTO v_rooms_list, v_total_rooms
    FROM rooms r
    LEFT JOIN LATERAL (
        SELECT COUNT(d.id) AS cnt 
        FROM devices d 
        WHERE d.room_id = r.id AND d.deleted_at IS NULL
    ) r_devs ON true
    WHERE r.floor_id = v_floor.id AND r.deleted_at IS NULL;

    -- Mapped devices on this floor
    SELECT COUNT(*) INTO v_mapped_devs 
    FROM devices 
    WHERE floor_id = v_floor.id AND deleted_at IS NULL;

    -- Unmapped devices in school
    SELECT COUNT(*) INTO v_unmapped_devs 
    FROM devices 
    WHERE school_id = p_school_id AND (floor_id IS NULL OR room_id IS NULL) AND deleted_at IS NULL;

    -- Groups assigned to devices on this floor
    SELECT COUNT(DISTINCT dgm.group_id) INTO v_groups_assigned
    FROM devices d
    JOIN device_group_members dgm ON dgm.device_id = d.id
    WHERE d.floor_id = v_floor.id AND d.deleted_at IS NULL;

    -- Profiles in use on this floor
    SELECT COUNT(DISTINCT d.profile_id) INTO v_profiles_in_use
    FROM devices d
    WHERE d.floor_id = v_floor.id AND d.deleted_at IS NULL AND d.profile_id IS NOT NULL;

    -- Coverage of rooms with devices
    SELECT COUNT(DISTINCT room_id) INTO v_loc_with_devs
    FROM devices
    WHERE floor_id = v_floor.id AND deleted_at IS NULL AND room_id IS NOT NULL;

    IF v_total_rooms > 0 THEN
        v_coverage_pct := ROUND((v_loc_with_devs::NUMERIC / v_total_rooms) * 100, 1);
    END IF;

    -- Assigned groups list
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', g.id,
            'name', g.name,
            'code', COALESCE(g.code, ''),
            'type', COALESCE(g.group_type, 'Custom'),
            'device_count', COALESCE(g.member_count, 0)
        ) ORDER BY COALESCE(g.member_count, 0) DESC
    ), '[]'::JSONB) INTO v_assigned_groups
    FROM device_groups g
    WHERE (g.floor_id = v_floor.id OR g.floor_id IS NULL) 
      AND g.school_id = p_school_id 
      AND g.status = 'active'
    LIMIT 8;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'id', v_floor.id,
            'title', COALESCE(v_building.name, 'Academic Block (A)') || ' – ' || COALESCE(v_floor.name, 'Floor'),
            'building_id', v_building.id,
            'building_name', COALESCE(v_building.name, 'Academic Block (A)'),
            'location_type', 'Floor',
            'parent_location', COALESCE(v_building.name, 'Academic Block (A)'),
            'floor_no', v_floor.floor_level,
            'status', 'Active',
            'total_rooms', v_total_rooms,
            'mapped_devices', v_mapped_devs,
            'unmapped_devices', v_unmapped_devs,
            'groups_assigned', v_groups_assigned,
            'profiles_in_use', v_profiles_in_use,
            'coverage_pct', v_coverage_pct,
            'image_url', 'https://images.unsplash.com/photo-1562774053-701939374585?auto=format&fit=crop&w=600&q=80',
            'rooms', v_rooms_list,
            'assigned_groups', v_assigned_groups,
            'automations_count', 3,
            'scenes_count', 2
        )
    );
END;
$$;


-- ============================================================================
-- 4. Function: fn_get_location_devices (Paginated, Filtered & Sorted)
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_get_location_devices(
    p_school_id UUID DEFAULT '11111111-1111-1111-1111-111111111111'::UUID,
    p_floor_id UUID DEFAULT NULL,
    p_building_id UUID DEFAULT NULL,
    p_room_id UUID DEFAULT NULL,
    p_device_type TEXT DEFAULT 'All',
    p_group_id TEXT DEFAULT 'All',
    p_profile_id TEXT DEFAULT 'All',
    p_mapping_status TEXT DEFAULT 'All',
    p_search TEXT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'created_at',
    p_sort_order TEXT DEFAULT 'ASC',
    p_page INT DEFAULT 1,
    p_limit INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_offset INT;
    v_total_count INT := 0;
    v_total_pages INT := 1;
    v_items JSONB := '[]'::JSONB;
BEGIN
    v_offset := (GREATEST(1, p_page) - 1) * GREATEST(1, p_limit);

    -- Total count query
    SELECT COUNT(*) INTO v_total_count
    FROM devices d
    LEFT JOIN device_types dt ON dt.id = d.device_type_id
    LEFT JOIN rooms r ON r.id = d.room_id
    LEFT JOIN buildings b ON b.id = d.building_id
    LEFT JOIN building_floors f ON f.id = d.floor_id
    WHERE d.school_id = p_school_id
      AND d.deleted_at IS NULL
      AND (p_floor_id IS NULL OR d.floor_id = p_floor_id)
      AND (p_building_id IS NULL OR d.building_id = p_building_id)
      AND (p_room_id IS NULL OR d.room_id = p_room_id)
      AND (p_device_type IS NULL OR p_device_type = 'All' OR p_device_type ILIKE 'All%' OR dt.name ILIKE '%' || p_device_type || '%' OR dt.code ILIKE '%' || p_device_type || '%')
      AND (p_group_id IS NULL OR p_group_id = 'All' OR p_group_id ILIKE 'All%' OR d.id IN (
          SELECT dgm.device_id FROM device_group_members dgm 
          JOIN device_groups dg ON dg.id = dgm.group_id 
          WHERE dg.id::text = p_group_id OR dg.name ILIKE '%' || p_group_id || '%'
      ))
      AND (p_profile_id IS NULL OR p_profile_id = 'All' OR p_profile_id ILIKE 'All%' OR d.profile_id::text = p_profile_id OR dt.id IN (
          SELECT device_type_id FROM device_profiles WHERE id::text = p_profile_id OR name ILIKE '%' || p_profile_id || '%'
      ))
      AND (
          p_mapping_status IS NULL OR p_mapping_status = 'All' OR p_mapping_status ILIKE 'All%' OR
          (LOWER(p_mapping_status) = 'mapped' AND d.room_id IS NOT NULL) OR
          (LOWER(p_mapping_status) = 'unmapped' AND d.room_id IS NULL)
      )
      AND (
          p_search IS NULL OR p_search = '' OR
          d.device_name ILIKE '%' || p_search || '%' OR
          d.device_code ILIKE '%' || p_search || '%' OR
          r.room_number ILIKE '%' || p_search || '%' OR
          r.name ILIKE '%' || p_search || '%'
      );

    v_total_pages := GREATEST(1, CEIL(v_total_count::NUMERIC / GREATEST(1, p_limit))::INT);

    -- Fetch data rows
    SELECT COALESCE(jsonb_agg(dev_obj), '[]'::JSONB) INTO v_items
    FROM (
        SELECT jsonb_build_object(
            'id', d.id,
            'device_name', d.device_name,
            'device_code', d.device_code,
            'device_type', COALESCE(
                CASE 
                    WHEN dt.code ILIKE '%cctv%' THEN 'CCTV'
                    WHEN dt.code ILIKE '%light%' THEN 'Lighting'
                    WHEN dt.code IN ('ac', 'hvac') OR dt.name ILIKE '%ac%' OR dt.name ILIKE '%hvac%' THEN 'HVAC (AC)'
                    WHEN dt.code ILIKE '%proj%' THEN 'Projector'
                    WHEN dt.code ILIKE '%wifi%' OR dt.code ILIKE '%access%' THEN 'Access Point'
                    WHEN dt.code ILIKE '%audio%' OR dt.code ILIKE '%speaker%' THEN 'Audio / Speaker'
                    WHEN dt.code ILIKE '%fan%' THEN 'Fan'
                    ELSE dt.name
                END, 'Device'
            ),
            'device_type_code', COALESCE(dt.code, 'general'),
            'room_id', d.room_id,
            'room_space', CASE 
                WHEN r.room_number IS NOT NULL AND r.name IS NOT NULL AND r.name != r.room_number THEN r.room_number || ' (' || r.name || ')'
                WHEN r.room_number IS NOT NULL THEN r.room_number
                ELSE 'Unassigned'
            END,
            'location_path', COALESCE(b.name, 'Academic Block (A)') || ' > ' || COALESCE(f.floor_code, f.name, '1F'),
            'mapping_status', CASE WHEN d.room_id IS NOT NULL THEN 'Mapped' ELSE 'Unmapped' END,
            'is_online', COALESCE(d.is_online, true),
            'power_state', COALESCE(d.power_state, true)
        ) AS dev_obj
        FROM devices d
        LEFT JOIN device_types dt ON dt.id = d.device_type_id
        LEFT JOIN rooms r ON r.id = d.room_id
        LEFT JOIN buildings b ON b.id = d.building_id
        LEFT JOIN building_floors f ON f.id = d.floor_id
        WHERE d.school_id = p_school_id
          AND d.deleted_at IS NULL
          AND (p_floor_id IS NULL OR d.floor_id = p_floor_id)
          AND (p_building_id IS NULL OR d.building_id = p_building_id)
          AND (p_room_id IS NULL OR d.room_id = p_room_id)
          AND (p_device_type IS NULL OR p_device_type = 'All' OR p_device_type ILIKE 'All%' OR dt.name ILIKE '%' || p_device_type || '%' OR dt.code ILIKE '%' || p_device_type || '%')
          AND (p_group_id IS NULL OR p_group_id = 'All' OR p_group_id ILIKE 'All%' OR d.id IN (
              SELECT dgm.device_id FROM device_group_members dgm 
              JOIN device_groups dg ON dg.id = dgm.group_id 
              WHERE dg.id::text = p_group_id OR dg.name ILIKE '%' || p_group_id || '%'
          ))
          AND (p_profile_id IS NULL OR p_profile_id = 'All' OR p_profile_id ILIKE 'All%' OR d.profile_id::text = p_profile_id OR dt.id IN (
              SELECT device_type_id FROM device_profiles WHERE id::text = p_profile_id OR name ILIKE '%' || p_profile_id || '%'
          ))
          AND (
              p_mapping_status IS NULL OR p_mapping_status = 'All' OR p_mapping_status ILIKE 'All%' OR
              (LOWER(p_mapping_status) = 'mapped' AND d.room_id IS NOT NULL) OR
              (LOWER(p_mapping_status) = 'unmapped' AND d.room_id IS NULL)
          )
          AND (
              p_search IS NULL OR p_search = '' OR
              d.device_name ILIKE '%' || p_search || '%' OR
              d.device_code ILIKE '%' || p_search || '%' OR
              r.room_number ILIKE '%' || p_search || '%' OR
              r.name ILIKE '%' || p_search || '%'
          )
        ORDER BY
            CASE WHEN LOWER(p_sort_by) = 'device_name' AND LOWER(p_sort_order) = 'asc' THEN d.device_name END ASC,
            CASE WHEN LOWER(p_sort_by) = 'device_name' AND LOWER(p_sort_order) = 'desc' THEN d.device_name END DESC,
            CASE WHEN LOWER(p_sort_by) = 'device_code' AND LOWER(p_sort_order) = 'asc' THEN d.device_code END ASC,
            CASE WHEN LOWER(p_sort_by) = 'device_code' AND LOWER(p_sort_order) = 'desc' THEN d.device_code END DESC,
            CASE WHEN LOWER(p_sort_by) = 'device_type' AND LOWER(p_sort_order) = 'asc' THEN dt.name END ASC,
            CASE WHEN LOWER(p_sort_by) = 'device_type' AND LOWER(p_sort_order) = 'desc' THEN dt.name END DESC,
            CASE WHEN LOWER(p_sort_by) = 'room_space' AND LOWER(p_sort_order) = 'asc' THEN r.room_number END ASC,
            CASE WHEN LOWER(p_sort_by) = 'room_space' AND LOWER(p_sort_order) = 'desc' THEN r.room_number END DESC,
            CASE WHEN LOWER(p_sort_by) = 'mapping_status' AND LOWER(p_sort_order) = 'asc' THEN (d.room_id IS NOT NULL)::text END ASC,
            CASE WHEN LOWER(p_sort_by) = 'mapping_status' AND LOWER(p_sort_order) = 'desc' THEN (d.room_id IS NOT NULL)::text END DESC,
            d.created_at ASC
        LIMIT p_limit OFFSET v_offset
    ) t;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'devices', v_items,
            'total', v_total_count,
            'page', p_page,
            'limit', p_limit,
            'total_pages', v_total_pages
        )
    );
END;
$$;


-- ============================================================================
-- 5. Stored Procedure: sp_map_device_location
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_map_device_location(
    p_device_id UUID,
    p_building_id UUID,
    p_floor_id UUID,
    p_room_id UUID,
    p_school_id UUID DEFAULT '11111111-1111-1111-1111-111111111111'::UUID,
    p_user_id UUID DEFAULT NULL,
    p_mount_type TEXT DEFAULT 'Wall',
    p_mount_height NUMERIC DEFAULT 1.8,
    p_asset_tag TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Update device location
    UPDATE devices 
    SET building_id = p_building_id,
        floor_id = p_floor_id,
        room_id = p_room_id,
        updated_at = now()
    WHERE id = p_device_id AND school_id = p_school_id;

    -- Upsert primary location assignment
    INSERT INTO location_device_assignments (
        school_id, device_id, building_id, floor_id, room_id, is_primary,
        mount_type, mount_height_meters, asset_tag, install_notes, mapped_by, mapped_at, status
    ) VALUES (
        p_school_id, p_device_id, p_building_id, p_floor_id, p_room_id, true,
        p_mount_type, p_mount_height, p_asset_tag, p_notes, p_user_id, now(), 'Mapped'
    )
    ON CONFLICT (device_id, is_primary) DO UPDATE SET 
        building_id = EXCLUDED.building_id,
        floor_id = EXCLUDED.floor_id,
        room_id = EXCLUDED.room_id,
        mount_type = EXCLUDED.mount_type,
        mount_height_meters = EXCLUDED.mount_height_meters,
        asset_tag = EXCLUDED.asset_tag,
        install_notes = EXCLUDED.install_notes,
        mapped_at = now(),
        status = 'Mapped';

    -- Audit trail
    INSERT INTO location_device_assignment_history (
        school_id, device_id, action, to_building_id, to_floor_id, to_room_id, changed_by, notes
    ) VALUES (
        p_school_id, p_device_id, 'MAP', p_building_id, p_floor_id, p_room_id, p_user_id, COALESCE(p_notes, 'Mapped to location')
    );
END;
$$;


-- ============================================================================
-- 6. Stored Procedure: sp_bulk_map_devices
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_bulk_map_devices(
    p_device_ids UUID[],
    p_building_id UUID,
    p_floor_id UUID,
    p_room_id UUID,
    p_school_id UUID DEFAULT '11111111-1111-1111-1111-111111111111'::UUID,
    p_user_id UUID DEFAULT NULL,
    p_mount_type TEXT DEFAULT 'Wall',
    p_mount_height NUMERIC DEFAULT 1.8,
    p_asset_tag_prefix TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_did UUID;
    v_idx INT := 1;
    v_tag TEXT;
BEGIN
    FOREACH v_did IN ARRAY p_device_ids LOOP
        v_tag := NULL;
        IF p_asset_tag_prefix IS NOT NULL AND p_asset_tag_prefix <> '' THEN
            v_tag := p_asset_tag_prefix || '-' || LPAD(v_idx::TEXT, 3, '0');
        END IF;

        CALL sp_map_device_location(
            p_device_id := v_did,
            p_building_id := p_building_id,
            p_floor_id := p_floor_id,
            p_room_id := p_room_id,
            p_school_id := p_school_id,
            p_user_id := p_user_id,
            p_mount_type := p_mount_type,
            p_mount_height := p_mount_height,
            p_asset_tag := v_tag,
            p_notes := p_notes
        );
        v_idx := v_idx + 1;
    END LOOP;
END;
$$;


-- ============================================================================
-- 7. Stored Procedure: sp_relocate_device
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_relocate_device(
    p_device_id UUID,
    p_new_building_id UUID,
    p_new_floor_id UUID,
    p_new_room_id UUID,
    p_school_id UUID DEFAULT '11111111-1111-1111-1111-111111111111'::UUID,
    p_user_id UUID DEFAULT NULL,
    p_reason TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_b UUID;
    v_from_f UUID;
    v_from_r UUID;
BEGIN
    SELECT building_id, floor_id, room_id INTO v_from_b, v_from_f, v_from_r
    FROM devices WHERE id = p_device_id;

    -- Update device
    UPDATE devices
    SET building_id = p_new_building_id,
        floor_id = p_new_floor_id,
        room_id = p_new_room_id,
        updated_at = now()
    WHERE id = p_device_id AND school_id = p_school_id;

    -- Update assignment
    UPDATE location_device_assignments
    SET building_id = p_new_building_id,
        floor_id = p_new_floor_id,
        room_id = p_new_room_id,
        status = 'Mapped',
        updated_at = now()
    WHERE device_id = p_device_id;

    -- Update marker floor
    UPDATE floor_plan_markers
    SET floor_id = p_new_floor_id,
        room_id = p_new_room_id,
        updated_at = now()
    WHERE device_id = p_device_id;

    -- History
    INSERT INTO location_device_assignment_history (
        school_id, device_id, action, from_building_id, from_floor_id, from_room_id,
        to_building_id, to_floor_id, to_room_id, changed_by, notes
    ) VALUES (
        p_school_id, p_device_id, 'MOVE', v_from_b, v_from_f, v_from_r,
        p_new_building_id, p_new_floor_id, p_new_room_id, p_user_id, p_reason
    );
END;
$$;


-- ============================================================================
-- 8. Stored Procedure: sp_unmap_device_location
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_unmap_device_location(
    p_device_id UUID,
    p_school_id UUID DEFAULT '11111111-1111-1111-1111-111111111111'::UUID,
    p_user_id UUID DEFAULT NULL,
    p_reason TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_b UUID;
    v_from_f UUID;
    v_from_r UUID;
BEGIN
    SELECT building_id, floor_id, room_id INTO v_from_b, v_from_f, v_from_r
    FROM devices WHERE id = p_device_id;

    -- Unassign from device
    UPDATE devices 
    SET room_id = NULL,
        updated_at = now()
    WHERE id = p_device_id AND school_id = p_school_id;

    -- Update assignment status
    UPDATE location_device_assignments
    SET status = 'Unmapped',
        updated_at = now()
    WHERE device_id = p_device_id;

    -- Remove marker
    DELETE FROM floor_plan_markers WHERE device_id = p_device_id;

    -- Audit record
    INSERT INTO location_device_assignment_history (
        school_id, device_id, action, from_building_id, from_floor_id, from_room_id, changed_by, notes
    ) VALUES (
        p_school_id, p_device_id, 'UNMAP', v_from_b, v_from_f, v_from_r, p_user_id, p_reason
    );
END;
$$;


-- ============================================================================
-- 9. Stored Procedure: sp_bulk_unmap_devices
-- ============================================================================
CREATE OR REPLACE PROCEDURE sp_bulk_unmap_devices(
    p_device_ids UUID[],
    p_school_id UUID DEFAULT '11111111-1111-1111-1111-111111111111'::UUID,
    p_user_id UUID DEFAULT NULL,
    p_reason TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_did UUID;
BEGIN
    FOREACH v_did IN ARRAY p_device_ids LOOP
        CALL sp_unmap_device_location(
            p_device_id := v_did,
            p_school_id := p_school_id,
            p_user_id := p_user_id,
            p_reason := p_reason
        );
    END LOOP;
END;
$$;


-- ============================================================================
-- 10. Data Seeding: Seed 10 Real Devices on Fourth Floor (F4), 8 on Third Floor (F3), 12 on Ground Floor (G)
-- ============================================================================
DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111'::UUID;
    v_bldg_id UUID := 'd4b547da-ca46-4976-af82-c1b89ac6f0a7'::UUID; -- Academic Block (A)
    v_f4_id UUID := 'd1b49946-edcc-46e0-9d26-57c09dbb6306'::UUID;   -- Fourth Floor (F4)
    v_f3_id UUID := '2cb715e8-f221-45aa-b277-1cc7609e99ab'::UUID;   -- Third Floor (F3)
    v_fg_id UUID := '93293399-cfe5-42c7-8c25-9e19dbf39b9d'::UUID;   -- Ground Floor (G)
    
    -- Device Type IDs
    v_dt_cctv UUID := 'aefc4364-6c53-4754-b135-22d3941b9a91'::UUID;
    v_dt_proj UUID := '08b4c919-25df-4c05-b17a-476c9c199ca0'::UUID;
    v_dt_ap   UUID := 'bc351c93-f767-4900-ad9d-a6054fd78085'::UUID;
    v_dt_light UUID := '7df1efc1-e7c6-407b-b157-991d98d549cc'::UUID;
    v_dt_audio UUID := '151bb56a-f8b3-414b-b109-2f4dd2c88010'::UUID;
    v_dt_ac   UUID := '179e1352-b2ce-45e5-9c08-54c5fc6a8dfb'::UUID;
    v_dt_fan  UUID := 'cef1e745-3dfa-442a-a36d-b8b218cdb6e3'::UUID;

    -- Fourth Floor Rooms
    v_r401 UUID := '73a52cdc-5a31-4eeb-bf95-5497268a1ec4'::UUID;
    v_r402 UUID := '3acdd105-6b62-4aae-aa99-15456c4ec27b'::UUID;
    v_r403 UUID := 'b0f061a6-09a6-4ed1-a5d1-667310c918e8'::UUID;
    v_r404 UUID := '75e8fd30-297f-4727-9b95-a75f93aa7ade'::UUID;
    v_r405 UUID := '3f6bcbb0-3a58-46df-a87d-c07a95225001'::UUID;
    v_r406 UUID := 'e7047ea8-3469-4679-83ec-80ed90d4870a'::UUID;
    v_r407 UUID := 'f3da098a-c58b-47ba-9120-9f7a8e94034d'::UUID;
    v_r408 UUID := 'bc8546c0-5bfe-40d6-b2b7-def2e40aa156'::UUID;
    v_r409 UUID := 'ec710373-0b30-4fcf-bdeb-ccbe91770930'::UUID;
    v_r410 UUID := '44f41d60-5cfe-4bc4-9b9b-1f487d992c61'::UUID;

    -- Third Floor Rooms
    v_r301 UUID := 'b55b0b67-d53d-42f8-9f78-5e5b91611254'::UUID;
    v_r302 UUID := '2aff76d2-bc52-4e5c-9c0a-ddf1b4800097'::UUID;
    v_r303 UUID := '072573ac-82c5-4ee1-bbdd-0a71a4021d27'::UUID;
    v_r304 UUID := '9abd4155-a76e-4862-827a-69d4bfc8a29c'::UUID;
    v_r305 UUID := '25ce5ccf-6988-4d3e-b84b-30edfbf91568'::UUID;
    v_r306 UUID := '6969d39a-d0ec-4873-bbe3-31da3230489c'::UUID;
    v_r307 UUID := '0bdda3ad-7ded-4eae-b42d-3bb7b3944cd6'::UUID;
    v_r308 UUID := '5ef50ff4-23b5-4d81-a635-b342a04c725f'::UUID;

    -- Ground Floor Rooms
    v_rg1 UUID := 'a8efcaf1-f07c-4ef8-9ec6-7beb3686aa09'::UUID;
    v_rg2 UUID := '03f3f504-d598-40d9-97d7-1f0e894d4a74'::UUID;
    v_rg3 UUID := '5e0616b1-fd89-483b-a465-03225563d110'::UUID;
    v_rg4 UUID := '27f4cd9a-b38c-4e56-82f5-3db2980d0edb'::UUID;
    v_rg5 UUID := '6e4eef8f-c6d9-48a3-8f6e-d57aa97ffa6c'::UUID;
    v_rg6 UUID := '1e583343-2f86-4233-8dbd-e596f7021ddc'::UUID;
    v_rg7 UUID := '05e4c8b4-e8c3-4d66-be81-4da87983c6f3'::UUID;
    v_rg8 UUID := 'a5cc98f2-9028-4d07-85cd-f67336103060'::UUID;
    v_rg9 UUID := '15920570-2c95-4a3e-a924-c48e0077c3ac'::UUID;
    v_rg10 UUID := '8f7c7b76-9a37-4e64-bed9-4af18fe43200'::UUID;
    v_rg11 UUID := 'e6c54450-7145-46a6-b7e3-13ee17adea4e'::UUID;
    v_rg12 UUID := '861517df-ce1f-448b-bd2b-7de8392974bf'::UUID;

    v_d_id UUID;
BEGIN
    -- 1. SEED 10 DEVICES ON FOURTH FLOOR (F4)
    v_d_id := 'f4000000-0001-4000-8000-000000000001'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_f4_id, v_r401, v_dt_ac, 'Air Conditioner (401)', 'AC-A1-401', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_f4_id, room_id = v_r401, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_f4_id, v_r401, v_school_id, NULL, 'Wall', 2.2, 'AST-401-AC', 'Seeded');

    v_d_id := 'f4000000-0002-4000-8000-000000000002'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_f4_id, v_r401, v_dt_proj, 'Projector (401)', 'PRJ-A1-401', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_f4_id, room_id = v_r401, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_f4_id, v_r401, v_school_id, NULL, 'Ceiling', 2.8, 'AST-401-PRJ', 'Seeded');

    v_d_id := 'f4000000-0003-4000-8000-000000000003'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_f4_id, v_r402, v_dt_light, 'Classroom Light Panel (402)', 'LIGHT-A1-402', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_f4_id, room_id = v_r402, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_f4_id, v_r402, v_school_id, NULL, 'Ceiling', 2.7, 'AST-402-LGT', 'Seeded');

    v_d_id := 'f4000000-0004-4000-8000-000000000004'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_f4_id, v_r402, v_dt_fan, 'Ceiling Fan (402)', 'FAN-A1-402', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_f4_id, room_id = v_r402, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_f4_id, v_r402, v_school_id, NULL, 'Ceiling', 2.6, 'AST-402-FAN', 'Seeded');

    v_d_id := 'f4000000-0005-4000-8000-000000000005'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_f4_id, v_r403, v_dt_audio, 'PA Audio Speaker (403)', 'AUD-A1-403', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_f4_id, room_id = v_r403, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_f4_id, v_r403, v_school_id, NULL, 'Wall', 2.1, 'AST-403-AUD', 'Seeded');

    v_d_id := 'f4000000-0006-4000-8000-000000000006'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_f4_id, v_r404, v_dt_cctv, 'Security Camera (404)', 'CAM-A1-404', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_f4_id, room_id = v_r404, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_f4_id, v_r404, v_school_id, NULL, 'Wall', 2.5, 'AST-404-CAM', 'Seeded');

    v_d_id := 'f4000000-0007-4000-8000-000000000007'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_f4_id, v_r405, v_dt_ac, 'Air Conditioner (405)', 'AC-A1-405', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_f4_id, room_id = v_r405, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_f4_id, v_r405, v_school_id, NULL, 'Wall', 2.2, 'AST-405-AC', 'Seeded');

    v_d_id := 'f4000000-0008-4000-8000-000000000008'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_f4_id, v_r406, v_dt_light, 'Classroom Light Panel (406)', 'LIGHT-A1-406', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_f4_id, room_id = v_r406, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_f4_id, v_r406, v_school_id, NULL, 'Ceiling', 2.7, 'AST-406-LGT', 'Seeded');

    v_d_id := 'f4000000-0009-4000-8000-000000000009'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_f4_id, v_r407, v_dt_fan, 'Ceiling Fan (407)', 'FAN-A1-407', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_f4_id, room_id = v_r407, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_f4_id, v_r407, v_school_id, NULL, 'Ceiling', 2.6, 'AST-407-FAN', 'Seeded');

    v_d_id := 'f4000000-0010-4000-8000-000000000010'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_f4_id, v_r408, v_dt_ap, 'Wi-Fi AP Enterprise (408)', 'AP-A1-408', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_f4_id, room_id = v_r408, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_f4_id, v_r408, v_school_id, NULL, 'Ceiling', 2.8, 'AST-408-AP', 'Seeded');

    -- 2. SEED 8 DEVICES ON THIRD FLOOR (F3)
    v_d_id := 'f3000000-0001-4000-8000-000000000001'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_f3_id, v_r301, v_dt_ac, 'Air Conditioner (301)', 'AC-A1-301', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_f3_id, room_id = v_r301, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_f3_id, v_r301, v_school_id, NULL, 'Wall', 2.2, 'AST-301-AC', 'Seeded');

    v_d_id := 'f3000000-0002-4000-8000-000000000002'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_f3_id, v_r302, v_dt_light, 'Classroom Light Panel (302)', 'LIGHT-A1-302', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_f3_id, room_id = v_r302, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_f3_id, v_r302, v_school_id, NULL, 'Ceiling', 2.7, 'AST-302-LGT', 'Seeded');

    v_d_id := 'f3000000-0003-4000-8000-000000000003'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_f3_id, v_r303, v_dt_fan, 'Ceiling Fan (303)', 'FAN-A1-303', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_f3_id, room_id = v_r303, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_f3_id, v_r303, v_school_id, NULL, 'Ceiling', 2.6, 'AST-303-FAN', 'Seeded');

    v_d_id := 'f3000000-0004-4000-8000-000000000004'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_f3_id, v_r304, v_dt_proj, 'Projector (304)', 'PRJ-A1-304', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_f3_id, room_id = v_r304, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_f3_id, v_r304, v_school_id, NULL, 'Ceiling', 2.8, 'AST-304-PRJ', 'Seeded');

    v_d_id := 'f3000000-0005-4000-8000-000000000005'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_f3_id, v_r305, v_dt_audio, 'PA Audio Speaker (305)', 'AUD-A1-305', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_f3_id, room_id = v_r305, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_f3_id, v_r305, v_school_id, NULL, 'Wall', 2.1, 'AST-305-AUD', 'Seeded');

    v_d_id := 'f3000000-0006-4000-8000-000000000006'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_f3_id, v_r306, v_dt_cctv, 'Security Camera (306)', 'CAM-A1-306', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_f3_id, room_id = v_r306, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_f3_id, v_r306, v_school_id, NULL, 'Wall', 2.5, 'AST-306-CAM', 'Seeded');

    v_d_id := 'f3000000-0007-4000-8000-000000000007'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_f3_id, v_r307, v_dt_ac, 'Air Conditioner (307)', 'AC-A1-307', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_f3_id, room_id = v_r307, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_f3_id, v_r307, v_school_id, NULL, 'Wall', 2.2, 'AST-307-AC', 'Seeded');

    v_d_id := 'f3000000-0008-4000-8000-000000000008'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_f3_id, v_r308, v_dt_ap, 'Wi-Fi AP Enterprise (308)', 'AP-A1-308', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_f3_id, room_id = v_r308, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_f3_id, v_r308, v_school_id, NULL, 'Ceiling', 2.8, 'AST-308-AP', 'Seeded');

    -- 3. SEED 12 DEVICES ON GROUND FLOOR (G)
    v_d_id := 'fa000000-0001-4000-8000-000000000001'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_fg_id, v_rg1, v_dt_ac, 'Computer Lab AC (CL-1)', 'AC-A1-G-CL1', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_fg_id, room_id = v_rg1, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_fg_id, v_rg1, v_school_id, NULL, 'Wall', 2.2, 'AST-G01-AC', 'Seeded');

    v_d_id := 'fa000000-0002-4000-8000-000000000002'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_fg_id, v_rg1, v_dt_ap, 'Computer Lab AP (CL-1)', 'AP-A1-G-CL1', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_fg_id, room_id = v_rg1, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_fg_id, v_rg1, v_school_id, NULL, 'Ceiling', 2.8, 'AST-G01-AP', 'Seeded');

    v_d_id := 'fa000000-0003-4000-8000-000000000003'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_fg_id, v_rg2, v_dt_proj, 'Conf Room Projector (CR-1)', 'PRJ-A1-G-CR1', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_fg_id, room_id = v_rg2, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_fg_id, v_rg2, v_school_id, NULL, 'Ceiling', 2.8, 'AST-G02-PRJ', 'Seeded');

    v_d_id := 'fa000000-0004-4000-8000-000000000004'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_fg_id, v_rg3, v_dt_cctv, 'Reception CCTV (G001)', 'CAM-A1-G-001', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_fg_id, room_id = v_rg3, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_fg_id, v_rg3, v_school_id, NULL, 'Wall', 2.5, 'AST-G03-CAM', 'Seeded');

    v_d_id := 'fa000000-0005-4000-8000-000000000005'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_fg_id, v_rg4, v_dt_light, 'Classroom Lights (G002)', 'LIGHT-A1-G-002', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_fg_id, room_id = v_rg4, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_fg_id, v_rg4, v_school_id, NULL, 'Ceiling', 2.7, 'AST-G04-LGT', 'Seeded');

    v_d_id := 'fa000000-0006-4000-8000-000000000006'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_fg_id, v_rg5, v_dt_fan, 'Ceiling Fan (G003)', 'FAN-A1-G-003', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_fg_id, room_id = v_rg5, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_fg_id, v_rg5, v_school_id, NULL, 'Ceiling', 2.6, 'AST-G05-FAN', 'Seeded');

    v_d_id := 'fa000000-0007-4000-8000-000000000007'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_fg_id, v_rg6, v_dt_ac, 'Air Conditioner (G004)', 'AC-A1-G-004', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_fg_id, room_id = v_rg6, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_fg_id, v_rg6, v_school_id, NULL, 'Wall', 2.2, 'AST-G06-AC', 'Seeded');

    v_d_id := 'fa000000-0008-4000-8000-000000000008'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_fg_id, v_rg7, v_dt_audio, 'Speaker (G005)', 'AUD-A1-G-005', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_fg_id, room_id = v_rg7, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_fg_id, v_rg7, v_school_id, NULL, 'Wall', 2.1, 'AST-G07-AUD', 'Seeded');

    v_d_id := 'fa000000-0009-4000-8000-000000000009'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_fg_id, v_rg8, v_dt_cctv, 'Lab CCTV (G006)', 'CAM-A1-G-006', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_fg_id, room_id = v_rg8, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_fg_id, v_rg8, v_school_id, NULL, 'Wall', 2.5, 'AST-G08-CAM', 'Seeded');

    v_d_id := 'fa000000-0010-4000-8000-000000000010'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_fg_id, v_rg9, v_dt_light, 'Discovery Lab Lights (G007)', 'LIGHT-A1-G-007', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_fg_id, room_id = v_rg9, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_fg_id, v_rg9, v_school_id, NULL, 'Ceiling', 2.7, 'AST-G09-LGT', 'Seeded');

    v_d_id := 'fa000000-0011-4000-8000-000000000011'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_fg_id, v_rg10, v_dt_ac, 'Headmaster Office AC (G008)', 'AC-A1-G-008', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_fg_id, room_id = v_rg10, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_fg_id, v_rg10, v_school_id, NULL, 'Wall', 2.2, 'AST-G10-AC', 'Seeded');

    v_d_id := 'fa000000-0012-4000-8000-000000000012'::UUID;
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state)
    VALUES (v_d_id, v_school_id, v_bldg_id, v_fg_id, v_rg11, v_dt_ap, 'Lobby Wi-Fi AP (G-101)', 'AP-A1-G-101', true, true)
    ON CONFLICT (id) DO UPDATE SET floor_id = v_fg_id, room_id = v_rg11, building_id = v_bldg_id, deleted_at = NULL;
    CALL sp_map_device_location(v_d_id, v_bldg_id, v_fg_id, v_rg11, v_school_id, NULL, 'Ceiling', 2.8, 'AST-G11-AP', 'Seeded');

END;
$$;
