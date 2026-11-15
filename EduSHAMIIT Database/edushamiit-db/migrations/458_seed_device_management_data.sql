-- Migration 458: Seed Enterprise Device Management & IoT Data
-- Greenwood High School (Tenant: 11111111-1111-1111-1111-111111111111)

DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_b1_id UUID;
    v_b2_id UUID;
    v_b3_id UUID;
    v_b4_id UUID;
    v_b5_id UUID;
    v_b6_id UUID;
    v_f1_id UUID;
    v_room_101_id UUID;
    v_room_102_id UUID;
    v_room_103_id UUID;
    v_room_201_id UUID;
    
    v_cat_hvac UUID;
    v_cat_light UUID;
    v_cat_av UUID;
    v_cat_sec UUID;
    
    v_type_ac UUID;
    v_type_light UUID;
    v_type_fan UUID;
    v_type_power UUID;
    v_type_proj UUID;
    v_type_gate UUID;
    v_type_audio UUID;
    v_type_display UUID;
    v_type_other UUID;

    v_dev_ac UUID;
    v_dev_light UUID;
    v_dev_fan UUID;
    v_dev_proj UUID;
    v_dev_gate UUID;
BEGIN
    -- 1. Ensure building codes B1 to B6
    UPDATE buildings SET code = 'B1' WHERE school_id = v_school_id AND name ILIKE '%Academic Block%';
    UPDATE buildings SET code = 'B2' WHERE school_id = v_school_id AND name ILIKE '%Senior Block%';
    UPDATE buildings SET code = 'B3' WHERE school_id = v_school_id AND name ILIKE '%Library Block%';
    UPDATE buildings SET code = 'B4' WHERE school_id = v_school_id AND name ILIKE '%Auditorium%';
    UPDATE buildings SET code = 'B5' WHERE school_id = v_school_id AND name ILIKE '%Admin Block%';
    UPDATE buildings SET code = 'B6' WHERE school_id = v_school_id AND name ILIKE '%Sports Complex%';

    SELECT id INTO v_b1_id FROM buildings WHERE school_id = v_school_id AND code = 'B1' LIMIT 1;
    SELECT id INTO v_b2_id FROM buildings WHERE school_id = v_school_id AND code = 'B2' LIMIT 1;
    SELECT id INTO v_b3_id FROM buildings WHERE school_id = v_school_id AND code = 'B3' LIMIT 1;
    SELECT id INTO v_b4_id FROM buildings WHERE school_id = v_school_id AND code = 'B4' LIMIT 1;
    SELECT id INTO v_b5_id FROM buildings WHERE school_id = v_school_id AND code = 'B5' LIMIT 1;
    SELECT id INTO v_b6_id FROM buildings WHERE school_id = v_school_id AND code = 'B6' LIMIT 1;

    SELECT id INTO v_f1_id FROM building_floors WHERE building_id = v_b1_id AND (floor_code = 'F1' OR name ILIKE '%First%') LIMIT 1;
    SELECT id INTO v_room_101_id FROM rooms WHERE building_id = v_b1_id AND room_number = '101' LIMIT 1;
    SELECT id INTO v_room_102_id FROM rooms WHERE building_id = v_b1_id AND room_number = '102' LIMIT 1;
    SELECT id INTO v_room_103_id FROM rooms WHERE building_id = v_b1_id AND room_number = '103' LIMIT 1;
    SELECT id INTO v_room_201_id FROM rooms WHERE building_id = v_b1_id AND room_number = '201' LIMIT 1;

    -- 2. Categories
    INSERT INTO device_categories (school_id, name, code, icon, color, description, sort_order)
    VALUES 
    (v_school_id, 'Climate & Environment', 'climate', 'ac_unit', '#38BDF8', 'Air conditioning, HVAC, Fans and Thermostats', 1),
    (v_school_id, 'Lighting & Power', 'lighting_power', 'lightbulb', '#EAB308', 'Lamps, Smart switches, Plugs and Relays', 2),
    (v_school_id, 'Audio / Visual & Media', 'av_media', 'videocam', '#8B5CF6', 'Projectors, PA systems, Smart displays', 3),
    (v_school_id, 'Security & Access', 'security_access', 'door_front_door', '#F43F5E', 'Gates, Turnstiles, RFID Readers and Smart Locks', 4)
    ON CONFLICT (school_id, code) DO UPDATE SET updated_at = NOW();

    SELECT id INTO v_cat_hvac FROM device_categories WHERE school_id = v_school_id AND code = 'climate' LIMIT 1;
    SELECT id INTO v_cat_light FROM device_categories WHERE school_id = v_school_id AND code = 'lighting_power' LIMIT 1;
    SELECT id INTO v_cat_av FROM device_categories WHERE school_id = v_school_id AND code = 'av_media' LIMIT 1;
    SELECT id INTO v_cat_sec FROM device_categories WHERE school_id = v_school_id AND code = 'security_access' LIMIT 1;

    -- 3. Device Types
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, description)
    VALUES
    (v_school_id, v_cat_light, 'Lighting', 'lighting', 'MQTT', 'lightbulb', '#EAB308', 'Classroom & hallway smart lighting'),
    (v_school_id, v_cat_hvac, 'AC (HVAC)', 'ac', 'MQTT', 'ac_unit', '#38BDF8', 'Classroom & office split / central air conditioner'),
    (v_school_id, v_cat_hvac, 'Fan', 'fan', 'MQTT', 'mode_fan', '#06B6D4', 'Ceiling and ventilation fans'),
    (v_school_id, v_cat_light, 'Power & Switches', 'power_switches', 'MQTT', 'power', '#22C55E', 'Smart relays and power outlets'),
    (v_school_id, v_cat_av, 'Projector', 'projector', 'MQTT', 'videocam', '#8B5CF6', 'Interactive classroom projectors'),
    (v_school_id, v_cat_sec, 'Gate Controller', 'gate_controller', 'MQTT', 'door_front_door', '#F43F5E', 'Automated entry barriers and gates'),
    (v_school_id, v_cat_av, 'Audio / Speakers', 'audio_speakers', 'MQTT', 'volume_up', '#B45309', 'Public address and room speakers'),
    (v_school_id, v_cat_av, 'LED Display', 'led_display', 'MQTT', 'tv', '#EC4899', 'Digital signage and LED notice boards'),
    (v_school_id, v_cat_light, 'Others', 'others', 'MQTT', 'devices_other', '#64748B', 'Other smart campus devices')
    ON CONFLICT (school_id, code) DO UPDATE SET updated_at = NOW();

    SELECT id INTO v_type_ac FROM device_types WHERE school_id = v_school_id AND code = 'ac' LIMIT 1;
    SELECT id INTO v_type_light FROM device_types WHERE school_id = v_school_id AND code = 'lighting' LIMIT 1;
    SELECT id INTO v_type_fan FROM device_types WHERE school_id = v_school_id AND code = 'fan' LIMIT 1;
    SELECT id INTO v_type_power FROM device_types WHERE school_id = v_school_id AND code = 'power_switches' LIMIT 1;
    SELECT id INTO v_type_proj FROM device_types WHERE school_id = v_school_id AND code = 'projector' LIMIT 1;
    SELECT id INTO v_type_gate FROM device_types WHERE school_id = v_school_id AND code = 'gate_controller' LIMIT 1;
    SELECT id INTO v_type_audio FROM device_types WHERE school_id = v_school_id AND code = 'audio_speakers' LIMIT 1;
    SELECT id INTO v_type_display FROM device_types WHERE school_id = v_school_id AND code = 'led_display' LIMIT 1;
    SELECT id INTO v_type_other FROM device_types WHERE school_id = v_school_id AND code = 'others' LIMIT 1;

    -- 4. Device Capabilities
    INSERT INTO device_capabilities (school_id, code, name, capability_type, data_type, min_value, max_value, step, unit, allowed_values)
    VALUES
    (v_school_id, 'power', 'Power Toggle', 'power', 'boolean', NULL, NULL, NULL, NULL, '["on", "off"]'::jsonb),
    (v_school_id, 'brightness', 'Brightness Level', 'level', 'number', 0, 100, 1, '%', '[]'::jsonb),
    (v_school_id, 'temperature', 'Target Temperature', 'temperature', 'number', 16, 30, 1, '°C', '[]'::jsonb),
    (v_school_id, 'hvac_mode', 'HVAC Mode', 'mode', 'string', NULL, NULL, NULL, NULL, '["Cool", "Heat", "Fan", "Auto", "Dry"]'::jsonb),
    (v_school_id, 'fan_speed', 'Fan Speed', 'fan_speed', 'string', NULL, NULL, NULL, NULL, '["Low", "Medium", "High", "Auto"]'::jsonb),
    (v_school_id, 'av_input', 'Video Source Input', 'av_input', 'string', NULL, NULL, NULL, NULL, '["HDMI 1", "HDMI 2", "Type-C", "Wireless", "VGA"]'::jsonb),
    (v_school_id, 'volume', 'Audio Volume', 'volume', 'number', 0, 100, 1, '%', '[]'::jsonb),
    (v_school_id, 'gate_lock', 'Gate Lock State', 'lock_state', 'string', NULL, NULL, NULL, NULL, '["Lock", "Unlock"]'::jsonb),
    (v_school_id, 'gate_position', 'Gate Position', 'custom', 'string', NULL, NULL, NULL, NULL, '["Open", "Close"]'::jsonb)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- 5. Seed 5 Primary Sample Devices from the Screenshot in Room 101
    -- Device 1: AC-B1-F1-101-01
    INSERT INTO devices (
        school_id, building_id, floor_id, room_id, device_type_id,
        device_name, device_code, ip_address, mac_address, mqtt_topic,
        is_online, power_state, operational_status, rated_power_watts,
        current_state
    ) VALUES (
        v_school_id, v_b1_id, v_f1_id, v_room_101_id, v_type_ac,
        'AC-B1-F1-101-01', 'AC-B1-F1-101-01', '192.168.10.101', '00:1B:44:11:3A:B7',
        'edu/11111111-1111-1111-1111-111111111111/AC-B1-F1-101-01',
        TRUE, TRUE, 'operational', 1800,
        '{"power": true, "temperature": 24, "mode": "Cool", "fan_speed": "Medium"}'::jsonb
    ) ON CONFLICT (school_id, device_code) DO UPDATE SET
        is_online = TRUE, power_state = TRUE,
        current_state = '{"power": true, "temperature": 24, "mode": "Cool", "fan_speed": "Medium"}'::jsonb
    RETURNING id INTO v_dev_ac;

    -- Device 2: Light-B1-F1-101-A
    INSERT INTO devices (
        school_id, building_id, floor_id, room_id, device_type_id,
        device_name, device_code, ip_address, mac_address, mqtt_topic,
        is_online, power_state, operational_status, rated_power_watts,
        current_state
    ) VALUES (
        v_school_id, v_b1_id, v_f1_id, v_room_101_id, v_type_light,
        'Light-B1-F1-101-A', 'Light-B1-F1-101-A', '192.168.10.102', '00:1B:44:11:3A:C8',
        'edu/11111111-1111-1111-1111-111111111111/Light-B1-F1-101-A',
        TRUE, TRUE, 'operational', 80,
        '{"power": true, "brightness": 80}'::jsonb
    ) ON CONFLICT (school_id, device_code) DO UPDATE SET
        is_online = TRUE, power_state = TRUE,
        current_state = '{"power": true, "brightness": 80}'::jsonb
    RETURNING id INTO v_dev_light;

    -- Device 3: Fan-B1-F1-101-01
    INSERT INTO devices (
        school_id, building_id, floor_id, room_id, device_type_id,
        device_name, device_code, ip_address, mac_address, mqtt_topic,
        is_online, power_state, operational_status, rated_power_watts,
        current_state
    ) VALUES (
        v_school_id, v_b1_id, v_f1_id, v_room_101_id, v_type_fan,
        'Fan-B1-F1-101-01', 'Fan-B1-F1-101-01', '192.168.10.103', '00:1B:44:11:3A:D9',
        'edu/11111111-1111-1111-1111-111111111111/Fan-B1-F1-101-01',
        TRUE, TRUE, 'operational', 65,
        '{"power": true, "speed": "Medium"}'::jsonb
    ) ON CONFLICT (school_id, device_code) DO UPDATE SET
        is_online = TRUE, power_state = TRUE,
        current_state = '{"power": true, "speed": "Medium"}'::jsonb
    RETURNING id INTO v_dev_fan;

    -- Device 4: Proj-B1-F1-101
    INSERT INTO devices (
        school_id, building_id, floor_id, room_id, device_type_id,
        device_name, device_code, ip_address, mac_address, mqtt_topic,
        is_online, power_state, operational_status, rated_power_watts,
        current_state
    ) VALUES (
        v_school_id, v_b1_id, v_f1_id, v_room_101_id, v_type_proj,
        'Proj-B1-F1-101', 'Proj-B1-F1-101', '192.168.10.104', '00:1B:44:11:3A:EA',
        'edu/11111111-1111-1111-1111-111111111111/Proj-B1-F1-101',
        TRUE, TRUE, 'operational', 350,
        '{"power": true, "input": "HDMI 1", "volume": 70}'::jsonb
    ) ON CONFLICT (school_id, device_code) DO UPDATE SET
        is_online = TRUE, power_state = TRUE,
        current_state = '{"power": true, "input": "HDMI 1", "volume": 70}'::jsonb
    RETURNING id INTO v_dev_proj;

    -- Device 5: Gate-ENT-Main
    INSERT INTO devices (
        school_id, building_id, floor_id, room_id, device_type_id,
        device_name, device_code, ip_address, mac_address, mqtt_topic,
        is_online, power_state, operational_status, rated_power_watts,
        current_state
    ) VALUES (
        v_school_id, v_b1_id, v_f1_id, NULL, v_type_gate,
        'Gate-ENT-Main', 'Gate-ENT-Main', '192.168.10.105', '00:1B:44:11:3A:FB',
        'edu/11111111-1111-1111-1111-111111111111/Gate-ENT-Main',
        TRUE, TRUE, 'operational', 500,
        '{"position": "Closed", "locked": true}'::jsonb
    ) ON CONFLICT (school_id, device_code) DO UPDATE SET
        is_online = TRUE, power_state = TRUE,
        current_state = '{"position": "Closed", "locked": true}'::jsonb
    RETURNING id INTO v_dev_gate;

    -- Additional sample devices in Room 102 & 103 for paging & filtering
    INSERT INTO devices (school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state, current_state)
    VALUES
    (v_school_id, v_b1_id, v_f1_id, v_room_102_id, v_type_ac, 'AC-B1-F1-102-01', 'AC-B1-F1-102-01', TRUE, TRUE, '{"power": true, "temperature": 23, "mode": "Cool", "fan_speed": "High"}'::jsonb),
    (v_school_id, v_b1_id, v_f1_id, v_room_102_id, v_type_light, 'Light-B1-F1-102-A', 'Light-B1-F1-102-A', TRUE, TRUE, '{"power": true, "brightness": 90}'::jsonb),
    (v_school_id, v_b1_id, v_f1_id, v_room_103_id, v_type_fan, 'Fan-B1-F1-103-01', 'Fan-B1-F1-103-01', TRUE, FALSE, '{"power": false, "speed": "Low"}'::jsonb),
    (v_school_id, v_b1_id, v_f1_id, v_room_103_id, v_type_proj, 'Proj-B1-F1-103', 'Proj-B1-F1-103', TRUE, TRUE, '{"power": true, "input": "Type-C", "volume": 50}'::jsonb),
    (v_school_id, v_b2_id, NULL, NULL, v_type_ac, 'AC-B2-101-01', 'AC-B2-101-01', TRUE, TRUE, '{"power": true, "temperature": 22, "mode": "Cool", "fan_speed": "Auto"}'::jsonb),
    (v_school_id, v_b3_id, NULL, NULL, v_type_proj, 'Projector-B3-201', 'Projector-B3-201', FALSE, FALSE, '{"power": false, "offline_reason": "No response for 15 minutes"}'::jsonb),
    (v_school_id, v_b4_id, NULL, NULL, v_type_ac, 'AC-B4-105', 'AC-B4-105', TRUE, TRUE, '{"power": true, "temperature": 26, "fault": "Temperature sensor error"}'::jsonb),
    (v_school_id, v_b6_id, NULL, NULL, v_type_display, 'LED-B6-Hall', 'LED-B6-Hall', TRUE, TRUE, '{"power": true, "brightness": 100, "content": "Welcome to Greenwood Sports Complex"}'::jsonb)
    ON CONFLICT (school_id, device_code) DO NOTHING;

    -- 6. Active Automations matching screenshot
    INSERT INTO device_automation_rules (school_id, name, description, trigger_type, is_active, execution_count)
    VALUES
    (v_school_id, 'Auto off lights (Unoccupied)', 'Turn off classroom lights after 2 minutes of no occupancy', 'occupancy', TRUE, 4210),
    (v_school_id, 'AC Schedule (Academic Hours)', 'Run AC from 08:00 AM - 05:00 PM (Mon - Fri)', 'schedule', TRUE, 1280),
    (v_school_id, 'Low Power Mode (After Hours)', 'Reduce non-critical device power after 08:00 PM', 'schedule', TRUE, 890)
    ON CONFLICT DO NOTHING;

    -- 7. Scenes & Presets matching screenshot
    INSERT INTO device_scenes (school_id, name, code, description, icon, color, is_preset, is_active)
    VALUES
    (v_school_id, 'Classroom', 'classroom', 'AC + Lights + Projector', 'school', '#2563EB', TRUE, FALSE),
    (v_school_id, 'Lecture', 'lecture', 'AC + Lights + AV', 'podium', '#2563EB', TRUE, TRUE),
    (v_school_id, 'Examination', 'examination', 'Controlled & Quiet', 'edit_note', '#8B5CF6', TRUE, FALSE),
    (v_school_id, 'Event', 'event', 'Lights + Audio + Display', 'theater_comedy', '#EC4899', TRUE, FALSE),
    (v_school_id, 'Energy Save', 'energy_save', 'Optimized Mode', 'eco', '#10B981', TRUE, FALSE)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- 8. Recent Alerts & Events matching screenshot
    INSERT INTO device_alerts (school_id, alert_type, severity, title, description, is_resolved, created_at)
    VALUES
    (v_school_id, 'device_offline', 'critical', 'Device Offline - Projector-B3-201', 'No response for 15 minutes', FALSE, NOW() - INTERVAL '15 minutes'),
    (v_school_id, 'high_power', 'warning', 'High Power Usage - Lab-B2', '22% higher than normal', FALSE, NOW() - INTERVAL '51 minutes'),
    (v_school_id, 'device_fault', 'warning', 'Device Fault - AC-B4-105', 'Temperature sensor error', FALSE, NOW() - INTERVAL '84 minutes'),
    (v_school_id, 'new_device', 'info', 'New Device Added - LED-B6-Hall', 'Registered and online', FALSE, NOW() - INTERVAL '107 minutes')
    ON CONFLICT DO NOTHING;

END $$;
