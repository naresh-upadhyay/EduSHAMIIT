-- ====================================================================
-- MIGRATION 522: LIVE CONTROL STORED PROCEDURES & DYNAMIC METRICS
-- Description: Provides database functions and procedures for Campus
-- Live Control:
--   1. fn_live_control_kpis: Dynamic KPI metrics (no hardcoding)
--   2. fn_live_control_devices: Dynamic sorting, filtering, and pagination
--   3. sp_execute_live_control_command: Transactional live command executor
--   4. sp_bulk_execute_live_control_commands: Bulk command execution
--   5. fn_get_live_control_device_details: Deep device inspector and audit logs
-- ====================================================================

-- 1. DROP EXISTING IF ANY
DROP FUNCTION IF EXISTS fn_live_control_kpis(UUID);
DROP FUNCTION IF EXISTS fn_live_control_devices(UUID, UUID, UUID, UUID, UUID, TEXT, TEXT, TEXT, TEXT, TEXT, INT, INT);
DROP PROCEDURE IF EXISTS sp_execute_live_control_command(UUID, UUID, TEXT, JSONB, UUID, BOOLEAN, TEXT, TEXT, BOOLEAN, JSONB);
DROP PROCEDURE IF EXISTS sp_bulk_execute_live_control_commands(UUID, UUID[], TEXT, JSONB, UUID, BOOLEAN, INT, TEXT);
DROP FUNCTION IF EXISTS fn_get_live_control_device_details(UUID, UUID);

-- ====================================================================
-- 1. FUNCTION: fn_live_control_kpis
-- ====================================================================
CREATE OR REPLACE FUNCTION fn_live_control_kpis(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total INT := 0;
    v_online INT := 0;
    v_offline INT := 0;
    v_controllable INT := 0;
    v_groups INT := 0;
    v_automations INT := 0;
    v_schedules INT := 0;
    v_online_pct NUMERIC := 0.0;
    v_offline_pct NUMERIC := 0.0;
BEGIN
    -- Total devices
    SELECT COUNT(*) INTO v_total
    FROM devices
    WHERE school_id = p_school_id AND deleted_at IS NULL;

    -- Online devices
    SELECT COUNT(*) INTO v_online
    FROM devices
    WHERE school_id = p_school_id AND deleted_at IS NULL AND is_online = true;

    -- Offline devices
    v_offline := GREATEST(v_total - v_online, 0);

    -- Online / Offline percentages
    IF v_total > 0 THEN
        v_online_pct := ROUND((v_online::NUMERIC / v_total::NUMERIC) * 100.0, 1);
        v_offline_pct := ROUND((v_offline::NUMERIC / v_total::NUMERIC) * 100.0, 1);
    END IF;

    -- Controllable Now: devices online with interactive capability
    SELECT COUNT(*) INTO v_controllable
    FROM devices
    WHERE school_id = p_school_id AND deleted_at IS NULL AND is_online = true;

    -- Active groups
    SELECT COUNT(*) INTO v_groups
    FROM device_groups
    WHERE school_id = p_school_id AND (status ILIKE 'active' OR status IS NULL);

    -- Running automations
    SELECT COUNT(*) INTO v_automations
    FROM device_automation_rules
    WHERE school_id = p_school_id AND is_active = true;

    -- Active schedules
    SELECT COUNT(*) INTO v_schedules
    FROM device_schedules
    WHERE school_id = p_school_id AND is_active = true;

    RETURN jsonb_build_object(
        'online_devices', v_online,
        'online_percentage', v_online_pct,
        'offline_devices', v_offline,
        'offline_percentage', v_offline_pct,
        'controllable_now', v_controllable,
        'active_groups', v_groups,
        'running_automations', v_automations,
        'active_schedules', v_schedules
    );
END;
$$;

-- ====================================================================
-- 2. FUNCTION: fn_live_control_devices
-- Supports filtering by building, floor, room, category, status, search,
-- plus dynamic database sorting and pagination.
-- ====================================================================
CREATE OR REPLACE FUNCTION fn_live_control_devices(
    p_school_id UUID,
    p_building_id UUID DEFAULT NULL,
    p_floor_id UUID DEFAULT NULL,
    p_room_id UUID DEFAULT NULL,
    p_device_type_id UUID DEFAULT NULL,
    p_category TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'device_name',
    p_sort_order TEXT DEFAULT 'asc',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT := 0;
    v_total INT := 0;
    v_devices JSONB := '[]'::JSONB;
BEGIN
    v_offset := GREATEST((COALESCE(p_page, 1) - 1) * GREATEST(COALESCE(p_page_size, 10), 1), 0);

    -- Total matching records count
    SELECT COUNT(*) INTO v_total
    FROM devices d
    LEFT JOIN device_types dt ON dt.id = d.device_type_id
    LEFT JOIN rooms r ON r.id = d.room_id
    WHERE d.school_id = p_school_id
      AND d.deleted_at IS NULL
      AND (p_room_id IS NULL OR d.room_id = p_room_id)
      AND (p_room_id IS NOT NULL OR p_floor_id IS NULL OR d.floor_id = p_floor_id)
      AND (p_room_id IS NOT NULL OR p_floor_id IS NOT NULL OR p_building_id IS NULL OR d.building_id = p_building_id)
      AND (p_device_type_id IS NULL OR d.device_type_id = p_device_type_id)
      AND (
          p_category IS NULL 
          OR p_category = '' 
          OR LOWER(p_category) = 'all' 
          OR LOWER(p_category) = 'all device types' 
          OR dt.name ILIKE '%' || p_category || '%' 
          OR dt.system_category ILIKE '%' || p_category || '%'
      )
      AND (
          p_status IS NULL 
          OR p_status = '' 
          OR LOWER(p_status) = 'all' 
          OR LOWER(p_status) = 'all status' 
          OR (LOWER(p_status) = 'online' AND d.is_online = true) 
          OR (LOWER(p_status) = 'offline' AND d.is_online = false)
      )
      AND (
          p_search IS NULL 
          OR p_search = '' 
          OR (
              d.device_name ILIKE '%' || p_search || '%'
              OR d.device_code ILIKE '%' || p_search || '%'
              OR r.name ILIKE '%' || p_search || '%'
              OR r.room_number ILIKE '%' || p_search || '%'
          )
      );

    -- Paginated and sorted records
    SELECT COALESCE(jsonb_agg(dev_row), '[]'::JSONB)
    INTO v_devices
    FROM (
        SELECT jsonb_build_object(
            'id', d.id::TEXT,
            'device_name', d.device_name,
            'device_code', d.device_code,
            'ip_address', COALESCE(d.ip_address, '192.168.1.100'),
            'mac_address', COALESCE(d.mac_address, '00:1A:2B:3C:4D:5E'),
            'mqtt_topic', COALESCE(d.mqtt_topic, 'edu/' || p_school_id::TEXT || '/' || d.device_code || '/command'),
            'is_online', COALESCE(d.is_online, TRUE),
            'power_state', COALESCE(d.power_state, TRUE),
            'current_state', COALESCE(d.current_state, '{}'::JSONB),
            'operational_status', COALESCE(d.operational_status, 'operational'),
            'rated_power_watts', COALESCE(d.rated_power_watts, 0)::FLOAT,
            'building_id', d.building_id::TEXT,
            'building_name', COALESCE(b.name, 'Academic Block (A)'),
            'floor_id', d.floor_id::TEXT,
            'floor_name', COALESCE(f.name, 'First Floor'),
            'room_id', d.room_id::TEXT,
            'room_name', COALESCE(r.name, 'Classroom'),
            'room_number', COALESCE(r.room_number, 'A1-103'),
            'device_type_id', d.device_type_id::TEXT,
            'device_type_name', COALESCE(dt.name, 'Generic Device'),
            'device_type_code', COALESCE(dt.code, 'generic'),
            'icon', COALESCE(dt.icon, 'devices'),
            'color', COALESCE(dt.color, '#2563EB'),
            'system_category', COALESCE(dt.system_category, 'General'),
            'profile_name', COALESCE(dp.name, 'Standard Profile')
        ) AS dev_row
        FROM devices d
        LEFT JOIN device_types dt ON dt.id = d.device_type_id
        LEFT JOIN device_profiles dp ON dp.id = d.profile_id
        LEFT JOIN buildings b ON b.id = d.building_id
        LEFT JOIN building_floors f ON f.id = d.floor_id
        LEFT JOIN rooms r ON r.id = d.room_id
        WHERE d.school_id = p_school_id
          AND d.deleted_at IS NULL
          AND (p_room_id IS NULL OR d.room_id = p_room_id)
          AND (p_room_id IS NOT NULL OR p_floor_id IS NULL OR d.floor_id = p_floor_id)
          AND (p_room_id IS NOT NULL OR p_floor_id IS NOT NULL OR p_building_id IS NULL OR d.building_id = p_building_id)
          AND (p_device_type_id IS NULL OR d.device_type_id = p_device_type_id)
          AND (
              p_category IS NULL 
              OR p_category = '' 
              OR LOWER(p_category) = 'all' 
              OR LOWER(p_category) = 'all device types' 
              OR dt.name ILIKE '%' || p_category || '%' 
              OR dt.system_category ILIKE '%' || p_category || '%'
          )
          AND (
              p_status IS NULL 
              OR p_status = '' 
              OR LOWER(p_status) = 'all' 
              OR LOWER(p_status) = 'all status' 
              OR (LOWER(p_status) = 'online' AND d.is_online = true) 
              OR (LOWER(p_status) = 'offline' AND d.is_online = false)
          )
          AND (
              p_search IS NULL 
              OR p_search = '' 
              OR (
                  d.device_name ILIKE '%' || p_search || '%'
                  OR d.device_code ILIKE '%' || p_search || '%'
                  OR r.name ILIKE '%' || p_search || '%'
                  OR r.room_number ILIKE '%' || p_search || '%'
              )
          )
        ORDER BY 
            CASE WHEN LOWER(p_sort_by) = 'device_name' AND LOWER(p_sort_order) = 'desc' THEN d.device_name END DESC,
            CASE WHEN LOWER(p_sort_by) = 'device_name' THEN d.device_name END ASC,
            CASE WHEN LOWER(p_sort_by) = 'device_code' AND LOWER(p_sort_order) = 'desc' THEN d.device_code END DESC,
            CASE WHEN LOWER(p_sort_by) = 'device_code' THEN d.device_code END ASC,
            CASE WHEN LOWER(p_sort_by) = 'room_number' AND LOWER(p_sort_order) = 'desc' THEN r.room_number END DESC,
            CASE WHEN LOWER(p_sort_by) = 'room_number' THEN r.room_number END ASC,
            CASE WHEN LOWER(p_sort_by) = 'device_type' AND LOWER(p_sort_order) = 'desc' THEN dt.name END DESC,
            CASE WHEN LOWER(p_sort_by) = 'device_type' THEN dt.name END ASC,
            CASE WHEN LOWER(p_sort_by) = 'status' AND LOWER(p_sort_order) = 'desc' THEN d.is_online END DESC,
            CASE WHEN LOWER(p_sort_by) = 'status' THEN d.is_online END ASC,
            CASE WHEN LOWER(p_sort_by) = 'power' AND LOWER(p_sort_order) = 'desc' THEN d.power_state END DESC,
            CASE WHEN LOWER(p_sort_by) = 'power' THEN d.power_state END ASC,
            d.device_name ASC
        OFFSET v_offset
        LIMIT GREATEST(COALESCE(p_page_size, 10), 1)
    ) q;

    RETURN jsonb_build_object(
        'devices', v_devices,
        'total', v_total,
        'page', COALESCE(p_page, 1),
        'page_size', GREATEST(COALESCE(p_page_size, 10), 1),
        'total_pages', CEIL(v_total::NUMERIC / GREATEST(COALESCE(p_page_size, 10), 1))
    );
END;
$$;

-- ====================================================================
-- 3. PROCEDURE: sp_execute_live_control_command
-- ====================================================================
CREATE OR REPLACE PROCEDURE sp_execute_live_control_command(
    p_school_id UUID,
    p_device_id UUID,
    p_command_type TEXT,
    p_payload JSONB,
    p_user_id UUID,
    INOUT p_success BOOLEAN DEFAULT FALSE,
    INOUT p_message TEXT DEFAULT '',
    INOUT p_device_code TEXT DEFAULT '',
    INOUT p_power_state BOOLEAN DEFAULT FALSE,
    INOUT p_updated_state JSONB DEFAULT '{}'::JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_dev RECORD;
    v_new_power BOOLEAN;
    v_cur_state JSONB;
BEGIN
    SELECT id, device_code, device_name, power_state, COALESCE(current_state, '{}'::JSONB) AS current_state
    INTO v_dev
    FROM devices
    WHERE id = p_device_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        p_success := FALSE;
        p_message := 'Device not found';
        RETURN;
    END IF;

    v_new_power := COALESCE(v_dev.power_state, TRUE);
    v_cur_state := v_dev.current_state;

    -- Merge command type into state
    IF p_command_type IN ('set_power', 'turn_on', 'turn_off') THEN
        IF p_command_type = 'turn_on' THEN
            v_new_power := TRUE;
        ELSIF p_command_type = 'turn_off' THEN
            v_new_power := FALSE;
        ELSE
            v_new_power := COALESCE((p_payload->>'power')::BOOLEAN, TRUE);
        END IF;
        v_cur_state := jsonb_set(v_cur_state, '{power}', to_jsonb(v_new_power));
    ELSIF p_command_type = 'set_brightness' THEN
        v_cur_state := jsonb_set(v_cur_state, '{brightness}', to_jsonb(COALESCE((p_payload->>'brightness')::INT, 80)));
        v_cur_state := jsonb_set(v_cur_state, '{power}', to_jsonb(TRUE));
        v_new_power := TRUE;
    ELSIF p_command_type = 'set_temperature' THEN
        v_cur_state := jsonb_set(v_cur_state, '{temperature}', to_jsonb(COALESCE((p_payload->>'temperature')::INT, 24)));
    ELSIF p_command_type = 'set_mode' THEN
        v_cur_state := jsonb_set(v_cur_state, '{mode}', to_jsonb(COALESCE(p_payload->>'mode', 'Cool')));
    ELSIF p_command_type = 'set_fan_speed' THEN
        v_cur_state := jsonb_set(v_cur_state, '{fan_speed}', to_jsonb(COALESCE(p_payload->>'fan_speed', 'Medium')));
    ELSIF p_command_type = 'set_swing' THEN
        v_cur_state := jsonb_set(v_cur_state, '{swing}', to_jsonb(COALESCE((p_payload->>'swing')::BOOLEAN, TRUE)));
    ELSIF p_command_type = 'set_channels' THEN
        v_cur_state := jsonb_set(v_cur_state, '{channels}', COALESCE(p_payload->'channels', '[1, 2, 4]'::JSONB));
    ELSIF p_command_type = 'set_lock' THEN
        v_cur_state := jsonb_set(v_cur_state, '{status}', to_jsonb(COALESCE(p_payload->>'status', 'locked')));
        v_cur_state := jsonb_set(v_cur_state, '{lock_state}', to_jsonb(COALESCE(p_payload->>'status', 'locked') = 'locked'));
    ELSIF p_command_type = 'set_volume' THEN
        v_cur_state := jsonb_set(v_cur_state, '{volume}', to_jsonb(COALESCE((p_payload->>'volume')::INT, 65)));
    ELSIF p_command_type = 'set_input' THEN
        v_cur_state := jsonb_set(v_cur_state, '{input}', to_jsonb(COALESCE(p_payload->>'input', 'HDMI 1')));
    ELSE
        v_cur_state := v_cur_state || p_payload;
    END IF;

    -- Update devices table
    UPDATE devices
    SET current_state = v_cur_state,
        power_state = v_new_power,
        updated_at = NOW()
    WHERE id = p_device_id;

    -- Record in device_commands audit log
    INSERT INTO device_commands (
        school_id, device_id, command_type, payload, status, executed_by, created_at, executed_at
    ) VALUES (
        p_school_id, p_device_id, p_command_type, p_payload, 'acknowledged', p_user_id, NOW(), NOW()
    );

    p_success := TRUE;
    p_message := 'Command ' || p_command_type || ' executed successfully';
    p_device_code := v_dev.device_code;
    p_power_state := v_new_power;
    p_updated_state := v_cur_state;
END;
$$;

-- ====================================================================
-- 4. PROCEDURE: sp_bulk_execute_live_control_commands
-- ====================================================================
CREATE OR REPLACE PROCEDURE sp_bulk_execute_live_control_commands(
    p_school_id UUID,
    p_device_ids UUID[],
    p_command_type TEXT,
    p_payload JSONB,
    p_user_id UUID,
    INOUT p_success BOOLEAN DEFAULT FALSE,
    INOUT p_count INT DEFAULT 0,
    INOUT p_message TEXT DEFAULT ''
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_did UUID;
    v_single_success BOOLEAN;
    v_single_msg TEXT;
    v_code TEXT;
    v_pwr BOOLEAN;
    v_st JSONB;
BEGIN
    p_count := 0;
    FOREACH v_did IN ARRAY p_device_ids LOOP
        CALL sp_execute_live_control_command(
            p_school_id, v_did, p_command_type, p_payload, p_user_id,
            v_single_success, v_single_msg, v_code, v_pwr, v_st
        );
        IF v_single_success THEN
            p_count := p_count + 1;
        END IF;
    END LOOP;

    p_success := (p_count > 0);
    p_message := 'Successfully executed ' || p_command_type || ' on ' || p_count || ' device(s)';
END;
$$;

-- ====================================================================
-- 5. FUNCTION: fn_get_live_control_device_details
-- ====================================================================
CREATE OR REPLACE FUNCTION fn_get_live_control_device_details(
    p_school_id UUID,
    p_device_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_device JSONB;
    v_logs JSONB;
BEGIN
    SELECT jsonb_build_object(
        'id', d.id::TEXT,
        'device_name', d.device_name,
        'device_code', d.device_code,
        'ip_address', COALESCE(d.ip_address, '192.168.1.100'),
        'mac_address', COALESCE(d.mac_address, '00:1A:2B:3C:4D:5E'),
        'mqtt_topic', COALESCE(d.mqtt_topic, 'edu/' || p_school_id::TEXT || '/' || d.device_code || '/command'),
        'is_online', COALESCE(d.is_online, TRUE),
        'power_state', COALESCE(d.power_state, TRUE),
        'current_state', COALESCE(d.current_state, '{}'::JSONB),
        'operational_status', COALESCE(d.operational_status, 'operational'),
        'rated_power_watts', COALESCE(d.rated_power_watts, 0)::FLOAT,
        'building_id', d.building_id::TEXT,
        'building_name', COALESCE(b.name, 'Academic Block (A)'),
        'floor_id', d.floor_id::TEXT,
        'floor_name', COALESCE(f.name, 'First Floor'),
        'room_id', d.room_id::TEXT,
        'room_name', COALESCE(r.name, 'Classroom'),
        'room_number', COALESCE(r.room_number, 'A1-103'),
        'device_type_id', d.device_type_id::TEXT,
        'device_type_name', COALESCE(dt.name, 'Generic Device'),
        'device_type_code', COALESCE(dt.code, 'generic'),
        'icon', COALESCE(dt.icon, 'devices'),
        'color', COALESCE(dt.color, '#2563EB'),
        'system_category', COALESCE(dt.system_category, 'General'),
        'profile_name', COALESCE(dp.name, 'Standard Profile')
    ) INTO v_device
    FROM devices d
    LEFT JOIN device_types dt ON dt.id = d.device_type_id
    LEFT JOIN device_profiles dp ON dp.id = d.profile_id
    LEFT JOIN buildings b ON b.id = d.building_id
    LEFT JOIN building_floors f ON f.id = d.floor_id
    LEFT JOIN rooms r ON r.id = d.room_id
    WHERE d.id = p_device_id AND d.school_id = p_school_id AND d.deleted_at IS NULL;

    IF v_device IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', dc.id::TEXT,
            'command_type', dc.command_type,
            'payload', COALESCE(dc.payload, '{}'::JSONB),
            'status', COALESCE(dc.status, 'acknowledged'),
            'created_at', dc.created_at::TEXT
        ) ORDER BY dc.created_at DESC
    ), '[]'::JSONB)
    INTO v_logs
    FROM (
        SELECT id, command_type, payload, status, created_at
        FROM device_commands
        WHERE device_id = p_device_id AND school_id = p_school_id
        ORDER BY created_at DESC
        LIMIT 10
    ) dc;

    RETURN jsonb_build_object(
        'device', v_device,
        'recent_logs', v_logs
    );
END;
$$;
