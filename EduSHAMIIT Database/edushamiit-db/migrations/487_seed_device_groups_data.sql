-- Migration 487: Seed Enterprise Device Groups Data
-- EduSHAMIIT Multi-Tenant Campus Device Management

DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_group_id UUID;
    v_i INT;
BEGIN
    -- 1. Ensure primary school exists
    IF NOT EXISTS (SELECT 1 FROM schools WHERE id = v_school_id) THEN
        RETURN;
    END IF;

    -- Clean up old seed groups for school if needed to ensure exact 128 groups count
    DELETE FROM device_group_members WHERE group_id IN (SELECT id FROM device_groups WHERE school_id = v_school_id);
    DELETE FROM device_groups WHERE school_id = v_school_id;

    -- 2. Insert Top 10 Highlighted Groups from Screenshot

    -- Group 1: Classroom Lighting - Block A
    INSERT INTO device_groups (
        id, school_id, name, code, description, group_type, icon, color, status, location_scope,
        profile_name, member_count, online_count, offline_count, schedules_count, automations_count, scenes_count,
        sort_order, resolved_capabilities, advanced_controls, created_at, updated_at
    ) VALUES (
        'a1111111-0001-4000-8000-000000000001',
        v_school_id,
        'Classroom Lighting - Block A',
        'GRP-CLS-LGT-BLKA',
        'All lights in Classrooms (Block A) with unified control, scheduling and automation.',
        'Lighting',
        'lightbulb',
        '#F59E0B',
        'active',
        'Block A > Classrooms',
        'Default Lighting',
        96, 94, 2, 3, 2, 4,
        1,
        '{"power": {"supported": true, "universal": true, "type": "boolean"}, "brightness": {"supported": true, "universal": false, "type": "number", "min": 0, "max": 100, "unit": "%", "supported_count": 92}}'::jsonb,
        '[{"category": "Lighting", "count": 92, "online": 90, "offline": 2, "capabilities": ["power", "brightness", "color_temp"]}, {"category": "Smart Switch", "count": 4, "online": 4, "offline": 0, "capabilities": ["power"]}]'::jsonb,
        '2025-01-10 11:20:00+00',
        '2025-01-12 14:45:00+00'
    );

    -- Group 2: AC - Academic Block
    INSERT INTO device_groups (
        id, school_id, name, code, description, group_type, icon, color, status, location_scope,
        profile_name, member_count, online_count, offline_count, schedules_count, automations_count, scenes_count,
        sort_order, resolved_capabilities, advanced_controls, created_at, updated_at
    ) VALUES (
        'a1111111-0002-4000-8000-000000000002',
        v_school_id,
        'AC - Academic Block',
        'GRP-AC-ACAD-BLK',
        'HVAC units for academic rooms with temperature normalization and energy bounds.',
        'HVAC (AC)',
        'ac_unit',
        '#0284C7',
        'active',
        'Academic Block',
        'AC Standard',
        48, 46, 2, 4, 3, 2,
        2,
        '{"power": {"supported": true, "universal": true, "type": "boolean"}, "temperature": {"supported": true, "universal": true, "type": "number", "min": 18, "max": 28, "unit": "°C"}, "fan_speed": {"supported": true, "universal": true, "type": "enum", "options": ["Low", "Medium", "High", "Auto"]}}'::jsonb,
        '[{"category": "HVAC", "count": 48, "online": 46, "offline": 2, "capabilities": ["power", "temperature", "fan_speed", "mode"]}]'::jsonb,
        '2025-01-08 10:15:00+00',
        '2025-01-12 13:20:00+00'
    );

    -- Group 3: Projectors - Classrooms
    INSERT INTO device_groups (
        id, school_id, name, code, description, group_type, icon, color, status, location_scope,
        profile_name, member_count, online_count, offline_count, schedules_count, automations_count, scenes_count,
        sort_order, resolved_capabilities, advanced_controls, created_at, updated_at
    ) VALUES (
        'a1111111-0003-4000-8000-000000000003',
        v_school_id,
        'Projectors - Classrooms',
        'GRP-PROJ-CLS',
        'All classroom projectors across academic buildings with input routing.',
        'AV & Display',
        'videocam',
        '#8B5CF6',
        'active',
        'All Buildings > Classrooms',
        'Projector Base',
        72, 70, 2, 2, 1, 3,
        3,
        '{"power": {"supported": true, "universal": true, "type": "boolean"}, "input": {"supported": true, "universal": true, "type": "enum", "options": ["HDMI 1", "HDMI 2", "Type-C", "Wireless"]}, "volume": {"supported": true, "universal": true, "type": "number", "min": 0, "max": 100, "unit": "%"}}'::jsonb,
        '[{"category": "Projector", "count": 72, "online": 70, "offline": 2, "capabilities": ["power", "input", "volume", "freeze"]}]'::jsonb,
        '2025-01-07 09:30:00+00',
        '2025-01-11 16:10:00+00'
    );

    -- Group 4: CCTV - Campus Perimeter
    INSERT INTO device_groups (
        id, school_id, name, code, description, group_type, icon, color, status, location_scope,
        profile_name, member_count, online_count, offline_count, schedules_count, automations_count, scenes_count,
        sort_order, resolved_capabilities, advanced_controls, created_at, updated_at
    ) VALUES (
        'a1111111-0004-4000-8000-000000000004',
        v_school_id,
        'CCTV - Campus Perimeter',
        'GRP-CCTV-PERIM',
        'Perimeter surveillance cameras with AI motion analytics and stream broadcasting.',
        'Security',
        'videocam',
        '#EF4444',
        'active',
        'Campus > Perimeter',
        'High Security',
        64, 63, 1, 1, 4, 1,
        4,
        '{"stream": {"supported": true, "universal": true, "type": "boolean"}, "ptz": {"supported": true, "universal": false, "type": "action", "supported_count": 28}, "recording": {"supported": true, "universal": true, "type": "boolean"}}'::jsonb,
        '[{"category": "CCTV", "count": 64, "online": 63, "offline": 1, "capabilities": ["live_stream", "recording", "ptz", "snapshot"]}]'::jsonb,
        '2025-01-05 08:45:00+00',
        '2025-01-10 11:30:00+00'
    );

    -- Group 5: Wi-Fi - Student Zone
    INSERT INTO device_groups (
        id, school_id, name, code, description, group_type, icon, color, status, location_scope,
        profile_name, member_count, online_count, offline_count, schedules_count, automations_count, scenes_count,
        sort_order, resolved_capabilities, advanced_controls, created_at, updated_at
    ) VALUES (
        'a1111111-0005-4000-8000-000000000005',
        v_school_id,
        'Wi-Fi - Student Zone',
        'GRP-WIFI-STUDENT',
        'Access points for student areas with high-density bandwidth shaping.',
        'Network',
        'wifi',
        '#06B6D4',
        'active',
        'Library, Canteen, Common Areas',
        'Wi-Fi Standard',
        86, 85, 1, 1, 1, 1,
        5,
        '{"power": {"supported": true, "universal": true, "type": "boolean"}, "guest_network": {"supported": true, "universal": true, "type": "boolean"}}'::jsonb,
        '[{"category": "Access Point", "count": 86, "online": 85, "offline": 1, "capabilities": ["power", "ssid_broadcast", "client_isolation"]}]'::jsonb,
        '2025-01-05 11:00:00+00',
        '2025-01-09 15:15:00+00'
    );

    -- Group 6: Fans - Laboratories
    INSERT INTO device_groups (
        id, school_id, name, code, description, group_type, icon, color, status, location_scope,
        profile_name, member_count, online_count, offline_count, schedules_count, automations_count, scenes_count,
        sort_order, resolved_capabilities, advanced_controls, created_at, updated_at
    ) VALUES (
        'a1111111-0006-4000-8000-000000000006',
        v_school_id,
        'Fans - Laboratories',
        'GRP-FANS-LABS',
        'Ceiling/wall fans in all science and computing laboratories.',
        'Environment',
        'toys',
        '#10B981',
        'active',
        'All Buildings > Labs',
        'Fan Standard',
        52, 50, 2, 3, 2, 2,
        6,
        '{"power": {"supported": true, "universal": true, "type": "boolean"}, "fan_speed": {"supported": true, "universal": true, "type": "enum", "options": ["Low", "Medium", "High"]}}'::jsonb,
        '[{"category": "Fan", "count": 52, "online": 50, "offline": 2, "capabilities": ["power", "fan_speed", "oscillation"]}]'::jsonb,
        '2025-01-04 14:20:00+00',
        '2025-01-08 10:05:00+00'
    );

    -- Group 7: Doors - Restricted Areas
    INSERT INTO device_groups (
        id, school_id, name, code, description, group_type, icon, color, status, location_scope,
        profile_name, member_count, online_count, offline_count, schedules_count, automations_count, scenes_count,
        sort_order, resolved_capabilities, advanced_controls, created_at, updated_at
    ) VALUES (
        'a1111111-0007-4000-8000-000000000007',
        v_school_id,
        'Doors - Restricted Areas',
        'GRP-DOORS-RESTR',
        'Access-controlled doors for administrative, server rooms and examination vaults.',
        'Access Control',
        'lock',
        '#2563EB',
        'active',
        'Admin Block, Labs, Data Center',
        'Secure Access',
        18, 18, 0, 2, 5, 2,
        7,
        '{"lock_state": {"supported": true, "universal": true, "type": "enum", "options": ["Locked", "Unlocked", "Emergency Open"]}}'::jsonb,
        '[{"category": "Smart Door", "count": 18, "online": 18, "offline": 0, "capabilities": ["lock", "unlock", "emergency_open"]}]'::jsonb,
        '2025-01-03 16:50:00+00',
        '2025-01-08 09:40:00+00'
    );

    -- Group 8: Audio - Auditorium
    INSERT INTO device_groups (
        id, school_id, name, code, description, group_type, icon, color, status, location_scope,
        profile_name, member_count, online_count, offline_count, schedules_count, automations_count, scenes_count,
        sort_order, resolved_capabilities, advanced_controls, created_at, updated_at
    ) VALUES (
        'a1111111-0008-4000-8000-000000000008',
        v_school_id,
        'Audio - Auditorium',
        'GRP-AUD-AUDITORIUM',
        'PA and audio surround systems for central auditorium events.',
        'AV & Display',
        'volume_up',
        '#8B5CF6',
        'active',
        'Main Building > Auditorium',
        'Audio Standard',
        12, 12, 0, 1, 1, 4,
        8,
        '{"power": {"supported": true, "universal": true, "type": "boolean"}, "volume": {"supported": true, "universal": true, "type": "number", "min": 0, "max": 100, "unit": "%"}, "mute": {"supported": true, "universal": true, "type": "boolean"}}'::jsonb,
        '[{"category": "Audio / Speaker", "count": 12, "online": 12, "offline": 0, "capabilities": ["power", "volume", "mute", "source_select"]}]'::jsonb,
        '2025-01-02 13:10:00+00',
        '2025-01-07 17:25:00+00'
    );

    -- Group 9: Environment Sensors
    INSERT INTO device_groups (
        id, school_id, name, code, description, group_type, icon, color, status, location_scope,
        profile_name, member_count, online_count, offline_count, schedules_count, automations_count, scenes_count,
        sort_order, resolved_capabilities, advanced_controls, created_at, updated_at
    ) VALUES (
        'a1111111-0009-4000-8000-000000000009',
        v_school_id,
        'Environment Sensors',
        'GRP-ENV-SENSORS',
        'Temp, humidity, CO2, and AQI monitoring stations campus-wide.',
        'Environment',
        'thermostat',
        '#10B981',
        'active',
        'All Buildings',
        'Sensor Standard',
        36, 35, 1, 0, 3, 1,
        9,
        '{"telemetry": {"supported": true, "universal": true, "metrics": ["temperature", "humidity", "co2", "aqi"]}}'::jsonb,
        '[{"category": "Environment Sensor", "count": 36, "online": 35, "offline": 1, "capabilities": ["temperature_read", "humidity_read", "co2_read", "aqi_read"]}]'::jsonb,
        '2025-01-02 10:00:00+00',
        '2025-01-06 12:15:00+00'
    );

    -- Group 10: Smart Classroom - Set 1
    INSERT INTO device_groups (
        id, school_id, name, code, description, group_type, icon, color, status, location_scope,
        profile_name, member_count, online_count, offline_count, schedules_count, automations_count, scenes_count,
        sort_order, resolved_capabilities, advanced_controls, created_at, updated_at
    ) VALUES (
        'a1111111-0010-4000-8000-000000000010',
        v_school_id,
        'Smart Classroom - Set 1',
        'GRP-SMRT-CLS-01',
        'Integrated classroom control including lighting, AC, projector and audio.',
        'Composite',
        'devices',
        '#3B82F6',
        'active',
        'Block B > Classrooms',
        'Smart Classroom',
        24, 24, 0, 4, 4, 5,
        10,
        '{"power": {"supported": true, "universal": true, "type": "boolean"}}'::jsonb,
        '[{"category": "Lighting", "count": 12, "capabilities": ["power", "brightness"]}, {"category": "AC", "count": 4, "capabilities": ["power", "temperature", "mode"]}, {"category": "Projector", "count": 2, "capabilities": ["power", "input"]}, {"category": "Fan", "count": 6, "capabilities": ["power", "speed"]}]'::jsonb,
        '2025-01-01 09:00:00+00',
        '2025-01-05 16:45:00+00'
    );

    -- 3. Populate additional groups up to 128 total (118 active, 10 inactive)
    -- Remaining 108 active groups:
    FOR v_i IN 11..118 LOOP
        INSERT INTO device_groups (
            id, school_id, name, code, description, group_type, icon, color, status, location_scope,
            profile_name, member_count, online_count, offline_count, schedules_count, automations_count, scenes_count,
            sort_order, created_at, updated_at
        ) VALUES (
            gen_random_uuid(),
            v_school_id,
            CASE (v_i % 6)
                WHEN 0 THEN 'Academic Block F' || ((v_i % 4) + 1) || ' Fleet ' || v_i
                WHEN 1 THEN 'Library Level ' || ((v_i % 3) + 1) || ' Control ' || v_i
                WHEN 2 THEN 'Science Wing Lab ' || ((v_i % 8) + 101) || ' Group ' || v_i
                WHEN 3 THEN 'Sports Complex Zone ' || ((v_i % 5) + 1) || ' Devices'
                WHEN 4 THEN 'Hostel Block ' || CHR(65 + (v_i % 4)) || ' Utilities ' || v_i
                ELSE 'Administration Sector ' || ((v_i % 3) + 1) || ' Relays ' || v_i
            END,
            'GRP-FLEET-' || LPAD(v_i::TEXT, 4, '0'),
            'Automated device group for campus facility monitoring and zone load shedding.',
            CASE (v_i % 7)
                WHEN 0 THEN 'Lighting'
                WHEN 1 THEN 'HVAC (AC)'
                WHEN 2 THEN 'AV & Display'
                WHEN 3 THEN 'Security'
                WHEN 4 THEN 'Network'
                WHEN 5 THEN 'Environment'
                ELSE 'Composite'
            END,
            'grid_view',
            '#2563EB',
            'active',
            'Building ' || CHR(65 + (v_i % 6)) || ' > Floor ' || ((v_i % 3) + 1),
            'Standard Profile',
            65 + (v_i % 30),
            62 + (v_i % 28),
            (v_i % 4),
            (v_i % 3) + 1,
            (v_i % 4) + 1,
            (v_i % 3),
            v_i,
            NOW() - (v_i || ' hours')::INTERVAL,
            NOW() - ((v_i % 12) || ' hours')::INTERVAL
        );
    END LOOP;

    -- 10 Inactive groups:
    FOR v_i IN 119..128 LOOP
        INSERT INTO device_groups (
            id, school_id, name, code, description, group_type, icon, color, status, location_scope,
            profile_name, member_count, online_count, offline_count, schedules_count, automations_count, scenes_count,
            sort_order, created_at, updated_at
        ) VALUES (
            gen_random_uuid(),
            v_school_id,
            'Old Campus Zone ' || (v_i - 118) || ' [Decommissioned]',
            'GRP-ARCH-' || LPAD(v_i::TEXT, 4, '0'),
            'Decommissioned legacy fixture fleet scheduled for hardware replacement.',
            CASE (v_i % 4)
                WHEN 0 THEN 'Lighting'
                WHEN 1 THEN 'HVAC (AC)'
                WHEN 2 THEN 'Environment'
                ELSE 'Composite'
            END,
            'archive',
            '#64748B',
            'inactive',
            'Old Campus Wing ' || CHR(65 + (v_i % 3)),
            'Legacy Profile',
            30 + (v_i % 15),
            0,
            30 + (v_i % 15),
            0, 0, 0,
            v_i,
            NOW() - (v_i || ' days')::INTERVAL,
            NOW() - (v_i || ' days')::INTERVAL
        );
    END LOOP;

    -- 4. Connect actual registered devices to Group 1, 2, 3 for live control
    -- Connect lighting devices to Group 1 (Classroom Lighting - Block A)
    INSERT INTO device_group_members (group_id, device_id)
    SELECT 'a1111111-0001-4000-8000-000000000001', d.id
    FROM devices d
    LEFT JOIN device_types dt ON d.device_type_id = dt.id
    WHERE d.school_id = v_school_id AND (dt.code = 'lighting' OR d.device_name ILIKE '%Light%')
    ON CONFLICT DO NOTHING;

    -- Connect HVAC devices to Group 2 (AC - Academic Block)
    INSERT INTO device_group_members (group_id, device_id)
    SELECT 'a1111111-0002-4000-8000-000000000002', d.id
    FROM devices d
    LEFT JOIN device_types dt ON d.device_type_id = dt.id
    WHERE d.school_id = v_school_id AND (dt.code = 'ac' OR d.device_name ILIKE '%AC%')
    ON CONFLICT DO NOTHING;

    -- Connect other devices to Group 10 (Smart Classroom - Set 1)
    INSERT INTO device_group_members (group_id, device_id)
    SELECT 'a1111111-0010-4000-8000-000000000010', id
    FROM devices
    WHERE school_id = v_school_id
    LIMIT 6
    ON CONFLICT DO NOTHING;

END $$;
