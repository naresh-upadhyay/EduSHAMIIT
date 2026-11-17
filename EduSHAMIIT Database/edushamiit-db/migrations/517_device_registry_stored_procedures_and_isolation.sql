-- Migration 517: Device Registry Stored Procedures, Search & Sorting Enhancements, and KPI Function
-- Description:
-- 1. Updates sp_list_devices to support enhanced full-text search across Device Name, Device Code, MAC Address, IP Address, Room, Building, and Device Type.
-- 2. Adds sorting support for 'ip_address', 'location_path', 'status', and other fields.
-- 3. Creates fn_get_device_registry_kpis to compute real-time dynamic KPIs for the Device Registry fleet.

-- ----------------------------------------------------------------------------
-- 1. STORED PROCEDURE: sp_list_devices
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sp_list_devices(
    p_school_id UUID,
    p_search TEXT DEFAULT NULL,
    p_building_id TEXT DEFAULT NULL,
    p_floor_id TEXT DEFAULT NULL,
    p_room_id TEXT DEFAULT NULL,
    p_type_code TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by TEXT DEFAULT 'created_at',
    p_sort_order TEXT DEFAULT 'asc'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT;
    v_total INT;
    v_devices JSONB;
    v_bld_uuid UUID := NULL;
    v_floor_uuid UUID := NULL;
    v_room_uuid UUID := NULL;
BEGIN
    v_offset := GREATEST(0, (COALESCE(p_page, 1) - 1) * COALESCE(p_page_size, 10));

    -- Resolve building ID if provided as UUID or Code
    IF p_building_id IS NOT NULL AND p_building_id <> '' AND p_building_id <> 'All' AND p_building_id <> 'Entire Campus' THEN
        BEGIN
            v_bld_uuid := p_building_id::UUID;
        EXCEPTION WHEN OTHERS THEN
            SELECT id INTO v_bld_uuid
            FROM buildings
            WHERE school_id = p_school_id AND (code = p_building_id OR name ILIKE '%' || p_building_id || '%')
            LIMIT 1;
        END;
    END IF;

    -- Resolve floor ID if provided as UUID or Code
    IF p_floor_id IS NOT NULL AND p_floor_id <> '' AND p_floor_id <> 'All' THEN
        BEGIN
            v_floor_uuid := p_floor_id::UUID;
        EXCEPTION WHEN OTHERS THEN
            SELECT id INTO v_floor_uuid
            FROM building_floors
            WHERE school_id = p_school_id AND (floor_code = p_floor_id OR name ILIKE '%' || p_floor_id || '%')
            LIMIT 1;
        END;
    END IF;

    -- Resolve room ID if provided as UUID, Room Number, or Name
    IF p_room_id IS NOT NULL AND p_room_id <> '' AND p_room_id <> 'All' THEN
        BEGIN
            v_room_uuid := p_room_id::UUID;
        EXCEPTION WHEN OTHERS THEN
            SELECT id INTO v_room_uuid
            FROM rooms
            WHERE school_id = p_school_id AND (room_number = p_room_id OR room_code = p_room_id OR name ILIKE '%' || p_room_id || '%')
            LIMIT 1;
        END;
    END IF;

    -- Total count with multi-criteria filtering
    SELECT COUNT(*) INTO v_total
    FROM devices d
    LEFT JOIN device_types dt ON d.device_type_id = dt.id
    LEFT JOIN buildings b ON d.building_id = b.id
    LEFT JOIN building_floors f ON d.floor_id = f.id
    LEFT JOIN rooms r ON d.room_id = r.id
    WHERE d.school_id = p_school_id
      AND d.deleted_at IS NULL
      AND (p_search IS NULL OR p_search = '' OR 
           d.device_name ILIKE '%' || p_search || '%' OR 
           d.device_code ILIKE '%' || p_search || '%' OR
           d.ip_address ILIKE '%' || p_search || '%' OR
           d.mac_address ILIKE '%' || p_search || '%' OR
           dt.name ILIKE '%' || p_search || '%' OR
           b.name ILIKE '%' || p_search || '%' OR
           b.code ILIKE '%' || p_search || '%' OR
           r.name ILIKE '%' || p_search || '%' OR
           r.room_number ILIKE '%' || p_search || '%')
      AND (v_bld_uuid IS NULL OR d.building_id = v_bld_uuid OR d.floor_id IN (SELECT id FROM building_floors WHERE building_id = v_bld_uuid))
      AND (v_floor_uuid IS NULL OR d.floor_id = v_floor_uuid OR d.room_id IN (SELECT id FROM rooms WHERE floor_id = v_floor_uuid))
      AND (v_room_uuid IS NULL OR d.room_id = v_room_uuid)
      AND (p_type_code IS NULL OR p_type_code = '' OR p_type_code = 'All' OR dt.code ILIKE p_type_code OR dt.name ILIKE p_type_code)
      AND (p_status IS NULL OR p_status = '' OR p_status = 'All' OR 
           (p_status = 'online' AND d.is_online = TRUE) OR 
           (p_status = 'offline' AND (d.is_online = FALSE OR d.is_online IS NULL)));

    -- Select paginated and sorted records
    SELECT COALESCE(
        jsonb_agg(jsonb_build_object(
            'id', d_sub.id,
            'school_id', d_sub.school_id,
            'device_name', d_sub.device_name,
            'device_code', d_sub.device_code,
            'type_name', COALESCE(d_sub.type_name, 'Unknown'),
            'type_code', COALESCE(d_sub.type_code, 'unknown'),
            'type_icon', COALESCE(d_sub.type_icon, 'devices'),
            'building_id', d_sub.building_id,
            'building_code', d_sub.building_code,
            'building_name', d_sub.building_name,
            'floor_id', d_sub.floor_id,
            'floor_code', d_sub.floor_code,
            'floor_name', d_sub.floor_name,
            'room_id', d_sub.room_id,
            'room_number', d_sub.room_number,
            'room_name', d_sub.room_name,
            'location_display', CONCAT(
                COALESCE(d_sub.building_code, 'Campus'), ' > ', 
                COALESCE(d_sub.floor_code, 'Floor'), ' > ', 
                COALESCE(d_sub.room_number, 'Room')
            ),
            'is_online', COALESCE(d_sub.is_online, FALSE),
            'power_state', COALESCE(d_sub.power_state, FALSE),
            'current_state', COALESCE(d_sub.current_state, '{}'::jsonb),
            'operational_status', COALESCE(d_sub.operational_status, 'normal'),
            'ip_address', d_sub.ip_address,
            'mac_address', d_sub.mac_address,
            'mqtt_topic', d_sub.mqtt_topic,
            'last_heartbeat_at', d_sub.last_heartbeat_at,
            'rated_power_watts', d_sub.rated_power_watts,
            'created_at', d_sub.created_at
        )),
        '[]'::jsonb
    ) INTO v_devices
    FROM (
        SELECT 
            d.id, d.school_id, d.device_name, d.device_code,
            dt.name AS type_name, dt.code AS type_code, dt.icon AS type_icon,
            d.building_id, b.code AS building_code, b.name AS building_name,
            d.floor_id, f.floor_code, f.name AS floor_name,
            d.room_id, r.room_number, r.name AS room_name,
            d.is_online, d.power_state, d.current_state, d.operational_status,
            d.ip_address, d.mac_address, d.mqtt_topic, d.last_heartbeat_at,
            d.rated_power_watts, d.created_at
        FROM devices d
        LEFT JOIN device_types dt ON d.device_type_id = dt.id
        LEFT JOIN buildings b ON d.building_id = b.id
        LEFT JOIN building_floors f ON d.floor_id = f.id
        LEFT JOIN rooms r ON d.room_id = r.id
        WHERE d.school_id = p_school_id
          AND d.deleted_at IS NULL
          AND (p_search IS NULL OR p_search = '' OR 
               d.device_name ILIKE '%' || p_search || '%' OR 
               d.device_code ILIKE '%' || p_search || '%' OR
               d.ip_address ILIKE '%' || p_search || '%' OR
               d.mac_address ILIKE '%' || p_search || '%' OR
               dt.name ILIKE '%' || p_search || '%' OR
               b.name ILIKE '%' || p_search || '%' OR
               b.code ILIKE '%' || p_search || '%' OR
               r.name ILIKE '%' || p_search || '%' OR
               r.room_number ILIKE '%' || p_search || '%')
          AND (v_bld_uuid IS NULL OR d.building_id = v_bld_uuid OR d.floor_id IN (SELECT id FROM building_floors WHERE building_id = v_bld_uuid))
          AND (v_floor_uuid IS NULL OR d.floor_id = v_floor_uuid OR d.room_id IN (SELECT id FROM rooms WHERE floor_id = v_floor_uuid))
          AND (v_room_uuid IS NULL OR d.room_id = v_room_uuid)
          AND (p_type_code IS NULL OR p_type_code = '' OR p_type_code = 'All' OR dt.code ILIKE p_type_code OR dt.name ILIKE p_type_code)
          AND (p_status IS NULL OR p_status = '' OR p_status = 'All' OR 
               (p_status = 'online' AND d.is_online = TRUE) OR 
               (p_status = 'offline' AND (d.is_online = FALSE OR d.is_online IS NULL)))
        ORDER BY
            CASE WHEN p_sort_by = 'device_name' AND LOWER(p_sort_order) = 'asc' THEN d.device_name END ASC,
            CASE WHEN p_sort_by = 'device_name' AND LOWER(p_sort_order) = 'desc' THEN d.device_name END DESC,
            CASE WHEN p_sort_by = 'device_code' AND LOWER(p_sort_order) = 'asc' THEN d.device_code END ASC,
            CASE WHEN p_sort_by = 'device_code' AND LOWER(p_sort_order) = 'desc' THEN d.device_code END DESC,
            CASE WHEN p_sort_by = 'type_name' AND LOWER(p_sort_order) = 'asc' THEN dt.name END ASC,
            CASE WHEN p_sort_by = 'type_name' AND LOWER(p_sort_order) = 'desc' THEN dt.name END DESC,
            CASE WHEN (p_sort_by = 'location_display' OR p_sort_by = 'location_path') AND LOWER(p_sort_order) = 'asc' THEN b.code END ASC,
            CASE WHEN (p_sort_by = 'location_display' OR p_sort_by = 'location_path') AND LOWER(p_sort_order) = 'desc' THEN b.code END DESC,
            CASE WHEN (p_sort_by = 'is_online' OR p_sort_by = 'status') AND LOWER(p_sort_order) = 'asc' THEN d.is_online END ASC,
            CASE WHEN (p_sort_by = 'is_online' OR p_sort_by = 'status') AND LOWER(p_sort_order) = 'desc' THEN d.is_online END DESC,
            CASE WHEN p_sort_by = 'ip_address' AND LOWER(p_sort_order) = 'asc' THEN d.ip_address END ASC,
            CASE WHEN p_sort_by = 'ip_address' AND LOWER(p_sort_order) = 'desc' THEN d.ip_address END DESC,
            CASE WHEN (p_sort_by = 'created_at' OR p_sort_by IS NULL OR p_sort_by = '') AND LOWER(p_sort_order) = 'asc' THEN d.created_at END ASC,
            CASE WHEN (p_sort_by = 'created_at' OR p_sort_by IS NULL OR p_sort_by = '') AND LOWER(p_sort_order) = 'desc' THEN d.created_at END DESC,
            d.created_at DESC
        LIMIT COALESCE(p_page_size, 10)
        OFFSET v_offset
    ) d_sub;

    RETURN jsonb_build_object(
        'total', v_total,
        'page', COALESCE(p_page, 1),
        'page_size', COALESCE(p_page_size, 10),
        'devices', v_devices
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. STORED PROCEDURE: fn_get_device_registry_kpis
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_get_device_registry_kpis(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_devices INT := 0;
    v_online_devices INT := 0;
    v_offline_devices INT := 0;
    v_types_count INT := 0;
    v_buildings_count INT := 0;
    v_floors_count INT := 0;
    v_rooms_count INT := 0;
    v_online_pct NUMERIC := 95.0;
BEGIN
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE is_online = TRUE),
        COUNT(*) FILTER (WHERE is_online = FALSE OR is_online IS NULL),
        COUNT(DISTINCT device_type_id),
        COUNT(DISTINCT building_id),
        COUNT(DISTINCT floor_id),
        COUNT(DISTINCT room_id)
    INTO 
        v_total_devices,
        v_online_devices,
        v_offline_devices,
        v_types_count,
        v_buildings_count,
        v_floors_count,
        v_rooms_count
    FROM devices
    WHERE school_id = p_school_id AND deleted_at IS NULL;

    IF v_total_devices > 0 THEN
        v_online_pct := ROUND((v_online_devices::NUMERIC / v_total_devices::NUMERIC) * 100, 1);
    END IF;

    RETURN jsonb_build_object(
        'total_devices', v_total_devices,
        'online', v_online_devices,
        'offline', v_offline_devices,
        'online_percentage', v_online_pct,
        'device_types', v_types_count,
        'buildings_count', v_buildings_count,
        'floors_count', v_floors_count,
        'rooms_count', v_rooms_count,
        'locations_summary', CONCAT(v_buildings_count, ' Buildings • ', v_floors_count, ' Floors')
    );
END;
$$;
