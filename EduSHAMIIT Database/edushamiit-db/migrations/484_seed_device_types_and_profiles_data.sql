-- Migration 484: Seed Realistic Enterprise Device Types & Profiles Matching Design Screenshot
-- EduSHAMIIT Multi-Tenant Campus Device Management

DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_cat_sec UUID;
    v_cat_av UUID;
    v_cat_net UUID;
    v_cat_pwr UUID;
    v_cat_auto UUID;
    v_cat_env UUID;
    v_cat_acc UUID;
    v_cat_water UUID;
    v_cat_infra UUID;
    v_cat_safe UUID;

    -- Dynamic Type IDs captured via RETURNING id
    v_type_cctv UUID;
    v_type_projector UUID;
    v_type_display UUID;
    v_type_ap UUID;
    v_type_plug UUID;
    v_type_light UUID;
    v_type_speaker UUID;
    v_type_ac UUID;
    v_type_fan UUID;
    v_type_env UUID;
    v_type_door UUID;
    v_type_gate UUID;
    v_type_barrier UUID;
    v_type_pump UUID;
    v_type_meter UUID;
    v_type_fire UUID;
    v_type_smoke UUID;
    v_type_biometric UUID;
    v_type_podium UUID;
    v_type_lift UUID;
    v_type_socket UUID;
    v_type_aqi UUID;
    v_type_sos UUID;
    v_type_weather UUID;

BEGIN
    -- 1. Ensure Categories exist with clean colors & codes
    INSERT INTO device_categories (school_id, name, code, icon, color, description)
    VALUES (v_school_id, 'Security', 'security', 'videocam', '#EF4444', 'Surveillance and perimeter defense')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, color = EXCLUDED.color
    RETURNING id INTO v_cat_sec;

    INSERT INTO device_categories (school_id, name, code, icon, color, description)
    VALUES (v_school_id, 'AV & Display', 'av_display', 'smart_display', '#8B5CF6', 'Classroom & auditorium audio/visual')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, color = EXCLUDED.color
    RETURNING id INTO v_cat_av;

    INSERT INTO device_categories (school_id, name, code, icon, color, description)
    VALUES (v_school_id, 'Network', 'network', 'wifi', '#0284C7', 'Campus networking & wireless APs')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, color = EXCLUDED.color
    RETURNING id INTO v_cat_net;

    INSERT INTO device_categories (school_id, name, code, icon, color, description)
    VALUES (v_school_id, 'Power & Energy', 'power_energy', 'bolt', '#F59E0B', 'Power distribution, switches & metering')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, color = EXCLUDED.color
    RETURNING id INTO v_cat_pwr;

    INSERT INTO device_categories (school_id, name, code, icon, color, description)
    VALUES (v_school_id, 'Building Automation', 'building_auto', 'lightbulb', '#2563EB', 'Automated architectural control')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, color = EXCLUDED.color
    RETURNING id INTO v_cat_auto;

    INSERT INTO device_categories (school_id, name, code, icon, color, description)
    VALUES (v_school_id, 'Environment', 'environment', 'thermostat', '#10B981', 'HVAC, air quality, sensors & climate')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, color = EXCLUDED.color
    RETURNING id INTO v_cat_env;

    INSERT INTO device_categories (school_id, name, code, icon, color, description)
    VALUES (v_school_id, 'Access Control', 'access_control', 'door_front_door', '#6366F1', 'Access barriers, gates & turnstiles')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, color = EXCLUDED.color
    RETURNING id INTO v_cat_acc;

    INSERT INTO device_categories (school_id, name, code, icon, color, description)
    VALUES (v_school_id, 'Water Management', 'water_mgmt', 'water_drop', '#06B6D4', 'Pumps, tanks & flow monitoring')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, color = EXCLUDED.color
    RETURNING id INTO v_cat_water;

    INSERT INTO device_categories (school_id, name, code, icon, color, description)
    VALUES (v_school_id, 'Infrastructure', 'infrastructure', 'apartment', '#64748B', 'Lifts, elevators & core utilities')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, color = EXCLUDED.color
    RETURNING id INTO v_cat_infra;

    INSERT INTO device_categories (school_id, name, code, icon, color, description)
    VALUES (v_school_id, 'Safety & Emergency', 'safety_emergency', 'warning', '#DC2626', 'Alarms, sirens & emergency hardware')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, color = EXCLUDED.color
    RETURNING id INTO v_cat_safe;

    -- 2. Clean Upsert 24 Device Types with ON CONFLICT (school_id, code)
    -- 1. CCTV
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_sec, 'CCTV', 'cctv_camera', 'ONVIF', 'videocam', '#EF4444', 'Security & Surveillance', 'IP/Network surveillance cameras', 1284, 6, '{"ONVIF","RTSP","HTTP(S)"}', '["Live View","PTZ Control","Recording","Snapshot","Motion Alert","Stream Share"]'::jsonb, TRUE, '2025-01-12 10:24:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_cctv;

    -- 2. Projector
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_av, 'Projector', 'projector', 'MQTT', 'videocam', '#8B5CF6', 'AV & Display', 'Classroom & auditorium projectors', 320, 4, '{"MQTT","RS232","PJLink"}', '["Power","Input Source","Brightness","Volume","Lamp Hours","Keystone"]'::jsonb, TRUE, '2025-01-11 14:15:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_projector;

    -- 3. Interactive Display
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_av, 'Interactive Display', 'interactive_display', 'MQTT', 'tv', '#8B5CF6', 'AV & Display', 'Smart boards & interactive panels', 412, 5, '{"MQTT","Android API","HDMI-CEC"}', '["Power","Touch Input","Screen Cast","Whiteboard","Annotation","Volume"]'::jsonb, TRUE, '2025-01-11 11:08:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_display;

    -- 4. Access Point
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_net, 'Access Point', 'wifi_access_point', 'SNMP', 'wifi', '#0284C7', 'Network Infrastructure', 'Wi-Fi access points (AP)', 650, 4, '{"SNMP","SSH","RADIUS"}', '["Client Count","Bandwidth Monitoring","SSID Broadcast","Channel Hop","Reboot"]'::jsonb, TRUE, '2025-01-10 16:20:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_ap;

    -- 5. Smart Plug / PDU
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_pwr, 'Smart Plug / PDU', 'smart_plug_pdu', 'MQTT', 'power', '#F59E0B', 'Power & Energy', 'Smart power control & metering', 586, 3, '{"MQTT","Zigbee","Modbus TCP"}', '["Power Relay","Current Sensing","Voltage Metering","Power Factor","Overload Cutoff"]'::jsonb, TRUE, '2025-01-10 09:40:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_plug;

    -- 6. Lighting
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_auto, 'Lighting', 'lighting', 'DALI', 'lightbulb', '#2563EB', 'Building Automation', 'Smart lighting (on/off, dimming, scene)', 1102, 8, '{"DALI","Zigbee","MQTT","KNX"}', '["Power","Brightness Dimmer","Color Temp","Scene Recall","Daylight Harvesting"]'::jsonb, TRUE, '2025-01-09 18:30:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_light;

    -- 7. Audio / Speaker
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_av, 'Audio / Speaker', 'audio_speakers', 'SIP', 'volume_up', '#8B5CF6', 'AV & Display', 'PA and classroom audio systems', 390, 5, '{"SIP","Dante","RTSP","MQTT"}', '["Master Volume","Zone Broadcast","Mute","Audio Input","Chime Trigger"]'::jsonb, TRUE, '2025-01-09 11:12:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_speaker;

    -- 8. HVAC (AC)
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_env, 'HVAC (AC)', 'ac', 'BACnet', 'ac_unit', '#10B981', 'Environment & Climate', 'Air conditioners (split/VRF)', 778, 6, '{"BACnet/IP","Modbus RTU","MQTT"}', '["Power","Temperature Setpoint","Operating Mode","Fan Speed","Swing Control","Eco Mode"]'::jsonb, TRUE, '2025-01-08 15:25:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_ac;

    -- 9. Fan
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_env, 'Fan', 'fan', 'MQTT', 'mode_fan', '#10B981', 'Environment & Climate', 'Ceiling / wall fans (smart)', 1396, 4, '{"MQTT","Zigbee","RF 433"}', '["Power","Speed Control (1-5)","Reverse Mode","Sleep Timer","Oscillation"]'::jsonb, TRUE, '2025-01-08 10:05:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_fan;

    -- 10. Environment Sensor
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_env, 'Environment Sensor', 'env_sensor', 'MQTT', 'thermostat', '#10B981', 'Environment & Climate', 'Temperature, humidity, CO2, AQI', 824, 5, '{"MQTT","BLE Mesh","Zigbee"}', '["Temperature Telemetry","Humidity Telemetry","CO2 PPM","IAQ Index","VOC Detection"]'::jsonb, TRUE, '2025-01-07 17:48:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_env;

    -- 11. Smart Door
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_sec, 'Smart Door', 'smart_door', 'OSDP', 'sensor_door', '#EF4444', 'Security & Access', 'Smart classroom & lab automated doors', 180, 3, '{"OSDP","MQTT","Wiegand"}', '["Lock/Unlock","Door Position","Auto Lock Timer","Obstruction Alert","Emergency Release"]'::jsonb, TRUE, '2025-01-06 14:20:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_door;

    -- 12. Automatic Gate
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_acc, 'Automatic Gate', 'auto_gate', 'Modbus RTU', 'door_front_door', '#6366F1', 'Access Control', 'Campus entrance & perimeter vehicle gates', 48, 3, '{"Modbus RTU","MQTT","Dry Contact Relay"}', '["Open Gate","Close Gate","Emergency Stop","Photocell Safety","Loop Detector"]'::jsonb, TRUE, '2025-01-05 11:15:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_gate;

    -- 13. Turnstile / Boom Barrier
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_acc, 'Turnstile Barrier', 'turnstile_barrier', 'TCP/IP', 'fence', '#6366F1', 'Access Control', 'Pedestrian turnstiles and boom barriers', 36, 2, '{"TCP/IP","Wiegand","MQTT"}', '["Pass Grant","Pass Deny","Anti-Tailgate","Free Exit Mode","Passage Counter"]'::jsonb, TRUE, '2025-01-04 16:30:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_barrier;

    -- 14. Water Pump
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_water, 'Water Pump', 'water_pump', 'Modbus TCP', 'water_drop', '#06B6D4', 'Water Management', 'Overhead tank & borewell automated pumps', 64, 3, '{"Modbus TCP","MQTT"}', '["Start/Stop","Dry Run Cutoff","Water Flow Rate","Tank Level Status","Pressure Bar"]'::jsonb, TRUE, '2025-01-03 13:10:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_pump;

    -- 15. Energy Meter
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_pwr, 'Energy Meter', 'energy_meter', 'Modbus RTU', 'speed', '#F59E0B', 'Power & Energy', '3-Phase sub-station & building energy meters', 112, 3, '{"Modbus RTU","DLMS","MQTT"}', '["Active Power (kW)","Apparent Power (kVA)","Power Factor","Total kWh","Peak Demand"]'::jsonb, TRUE, '2025-01-02 15:40:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_meter;

    -- 16. Fire Alarm
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_safe, 'Fire Alarm Panel', 'fire_alarm_panel', 'BACnet', 'campaign', '#DC2626', 'Safety & Emergency', 'Central addressable fire alarm panel', 145, 2, '{"BACnet/IP","Modbus","Relay Contact"}', '["Panel Normal","Zone Alarm","Silence Buzzer","Evacuation Siren","Trouble Alert"]'::jsonb, TRUE, '2025-01-02 09:15:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_fire;

    -- 17. Smoke Detector
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_safe, 'Smoke Detector', 'smoke_detector', 'Zigbee', 'detector_smoke', '#DC2626', 'Safety & Emergency', 'Opto-electric photoelectric smoke sensors', 210, 2, '{"Zigbee","LoRaWAN","Dry Contact"}', '["Smoke Obscuration","Battery Status","Tamper Warning","Chamber Clean Alert"]'::jsonb, TRUE, '2025-01-01 11:20:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_smoke;

    -- 18. Biometric Terminal
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_acc, 'Biometric Terminal', 'biometric_terminal', 'TCP/IP', 'fingerprint', '#6366F1', 'Access Control', 'Face & fingerprint staff/student check-in', 55, 2, '{"TCP/IP","HTTP REST","Wiegand"}', '["Punch Log","User Sync","Relay Trigger","Live Face Match","Audio Prompt"]'::jsonb, TRUE, '2024-12-30 08:30:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_biometric;

    -- 19. Digital Podium
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_av, 'Digital Podium', 'digital_podium', 'MQTT', 'co_present', '#8B5CF6', 'AV & Display', 'Lectern touch display, mic & switching hub', 42, 2, '{"MQTT","Telnet","RS485"}', '["Mic Master","Presentation Matrix","Screen Lift","Laptop HDMI Switch","Gooseneck Mute"]'::jsonb, TRUE, '2024-12-28 14:00:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_podium;

    -- 20. Lift Controller
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_infra, 'Lift Controller', 'lift_controller', 'BACnet', 'elevator', '#64748B', 'Infrastructure', 'Elevator call & floor status monitoring', 16, 2, '{"BACnet/IP","Modbus RTU"}', '["Current Floor","Direction Status","Door Open State","Fire Override Mode","Overload Alarm"]'::jsonb, TRUE, '2024-12-25 10:10:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_lift;

    -- 21. Smart Socket
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_pwr, 'Smart Socket', 'smart_socket', 'Zigbee', 'outlet', '#F59E0B', 'Power & Energy', 'Wall mounted 16A smart switch sockets', 340, 2, '{"Zigbee","MQTT"}', '["Relay Switch","Child Lock","Surge Protection","Power Metering"]'::jsonb, TRUE, '2024-12-20 11:35:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_socket;

    -- 22. Air Quality Monitor
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_env, 'Air Quality Monitor', 'aqi_monitor', 'MQTT', 'air', '#10B981', 'Environment & Climate', 'Classroom PM2.5, PM10 & TVOC monitor', 98, 2, '{"MQTT","BLE Mesh"}', '["PM2.5 ug/m3","PM10 ug/m3","CO2 PPM","Formaldehyde (HCHO)","AQI Score"]'::jsonb, TRUE, '2024-12-18 16:50:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_aqi;

    -- 23. Emergency SOS Alarm
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_safe, 'Emergency SOS Alarm', 'emergency_sos_alarm', 'MQTT', 'notification_important', '#DC2626', 'Safety & Emergency', 'Hostel & lab emergency pull cords & strobes', 32, 2, '{"MQTT","Dry Contact"}', '["Panic Trigger","Audio Strobe","Security Desk Notification","Acknowledge Reset"]'::jsonb, TRUE, '2024-12-15 13:40:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_sos;

    -- 24. Weather Station
    INSERT INTO device_types (school_id, category_id, name, code, protocol, icon, color, system_category, description, mapped_devices_count, profiles_count, supported_protocols, default_capabilities, is_active, updated_at)
    VALUES (v_school_id, v_cat_env, 'Weather Station', 'weather_station', 'Modbus RTU', 'wb_sunny', '#10B981', 'Environment & Climate', 'Rooftop meteorological weather observation', 12, 2, '{"Modbus RTU","MQTT"}', '["Wind Speed","Wind Direction","Solar Radiation","Barometric Pressure","Rainfall Gauge"]'::jsonb, TRUE, '2024-12-10 10:00:00+00')
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, category_id = EXCLUDED.category_id, system_category = EXCLUDED.system_category, mapped_devices_count = EXCLUDED.mapped_devices_count, profiles_count = EXCLUDED.profiles_count, supported_protocols = EXCLUDED.supported_protocols, default_capabilities = EXCLUDED.default_capabilities, description = EXCLUDED.description, is_active = TRUE
    RETURNING id INTO v_type_weather;

    -- 3. Seed Control Profiles (Total 76 Profiles: 24 Default + 52 Custom)
    -- Profiles for CCTV (6 Profiles matching screenshot: 2 Default, 4 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count, capabilities_override)
    VALUES 
        (v_school_id, v_type_cctv, 'Default CCTV Profile', 'prof_cctv_default', 'default', 'Hikvision', 'DS-2CD2143G2-I', 'General campus perimeter 1080p continuous recording', '1.0.0', 'active', TRUE, 842, '{"fps":25,"stream":"main","ir_mode":"auto"}'::jsonb),
        (v_school_id, v_type_cctv, 'PTZ Control Profile', 'prof_cctv_ptz', 'custom', 'Dahua', 'SD59230U-HNI', 'Grounds & stadium 30x optical zoom with preset patrols', '1.2.0', 'active', FALSE, 218, '{"ptz_speed":4,"patrol_preset":"loop_stadium"}'::jsonb),
        (v_school_id, v_type_cctv, 'High Security (24x7)', 'prof_cctv_highsec', 'custom', 'Axis', 'Q3517-LVE', 'Server room & exam vault 4K high bit-rate with tamper detection', '2.0.0', 'active', FALSE, 124, '{"fps":30,"motion_sensitivity":9,"tamper_alarm":true}'::jsonb),
        (v_school_id, v_type_cctv, 'Event Recording', 'prof_cctv_event', 'custom', 'Hikvision', 'DS-2CD2043G2', 'Motion-only triggered recording with 10s pre-buffer', '1.0.0', 'active', FALSE, 56, '{"mode":"motion_only","pre_buffer_sec":10}'::jsonb),
        (v_school_id, v_type_cctv, 'Low Bandwidth', 'prof_cctv_lowbw', 'custom', 'Uniview', 'IPC2122LR3', 'Sub-stream 720p 15fps H.265 optimized for remote hostels', '1.0.1', 'active', FALSE, 32, '{"codec":"H265","bitrate_kbps":1024,"resolution":"720p"}'::jsonb),
        (v_school_id, v_type_cctv, 'Public Area (Read-only)', 'prof_cctv_public', 'default', 'Hikvision', 'DS-2CD1123G0E', 'Cafeteria & corridor live view only without PTZ privileges', '1.1.0', 'active', TRUE, 12, '{"allow_ptz":false,"allow_recording_download":false}'::jsonb)
    ON CONFLICT (school_id, code) DO UPDATE SET name = EXCLUDED.name, usage_count = EXCLUDED.usage_count, profile_type = EXCLUDED.profile_type;

    -- Profiles for Projector (4 Profiles: 1 Default, 3 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_projector, 'Default Classroom Projector', 'prof_proj_default', 'default', 'Epson', 'EB-X06', 'Standard 3LCD 3600 lumens classroom setup', '1.0.0', 'active', TRUE, 220),
        (v_school_id, v_type_projector, 'Auditorium High-Lumen', 'prof_proj_auditorium', 'custom', 'Panasonic', 'PT-MZ880', '8000 lumens laser auditorium projection', '1.5.0', 'active', FALSE, 45),
        (v_school_id, v_type_projector, 'Lab Interactive Short Throw', 'prof_proj_shortthrow', 'custom', 'BenQ', 'MW855UST+', 'Ultra short throw interactive finger touch', '1.1.0', 'active', FALSE, 35),
        (v_school_id, v_type_projector, 'Eco Saver Classroom', 'prof_proj_eco', 'custom', 'Epson', 'EB-W51', 'Reduced brightness mode for morning sunlight classes', '1.0.0', 'active', FALSE, 20)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Interactive Display (5 Profiles: 1 Default, 4 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_display, 'Standard Interactive Panel', 'prof_disp_default', 'default', 'ViewSonic', 'IFP7550', '75-inch 4K multi-touch smart panel', '1.0.0', 'active', TRUE, 250),
        (v_school_id, v_type_display, 'Conference Room Display', 'prof_disp_conf', 'custom', 'Samsung', 'Flip Pro 85', 'Executive 85-inch whiteboard with wireless BYOD', '1.3.0', 'active', FALSE, 60),
        (v_school_id, v_type_display, 'STEM Robotics Lab Touch', 'prof_disp_stem', 'custom', 'Promethean', 'ActivPanel 9', 'Precision stylus dual pen STEM profile', '1.2.0', 'active', FALSE, 42),
        (v_school_id, v_type_display, 'Library Kiosk Display', 'prof_disp_kiosk', 'custom', 'LG', 'One:Quick', 'Locked kiosk mode for catalog browsing', '1.0.0', 'active', FALSE, 35),
        (v_school_id, v_type_display, 'Low Blue Light Mode', 'prof_disp_bluelight', 'custom', 'BenQ', 'Board Pro', 'Eye safety certified profile for junior classes', '1.0.0', 'active', FALSE, 25)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Access Point (4 Profiles: 1 Default, 3 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_ap, 'Campus Standard Wi-Fi 6', 'prof_ap_default', 'default', 'Aruba', 'AP-505', 'Dual-radio 802.11ax for standard classrooms', '1.0.0', 'active', TRUE, 420),
        (v_school_id, v_type_ap, 'High-Density Auditorium', 'prof_ap_hd', 'custom', 'Cisco Catalyst', '9130AX', 'High density 500+ client beamforming profile', '2.0.0', 'active', FALSE, 110),
        (v_school_id, v_type_ap, 'Hostel Bandwidth Restricted', 'prof_ap_hostel', 'custom', 'Ubiquiti UniFi', 'U6 Pro', 'Per-student bandwidth rate limiting profile', '1.1.0', 'active', FALSE, 80),
        (v_school_id, v_type_ap, 'Outdoor Sports Mesh', 'prof_ap_outdoor', 'custom', 'Aruba', 'AP-575', 'Weatherproof IP67 long-range campus mesh', '1.0.0', 'active', FALSE, 40)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Smart Plug / PDU (3 Profiles: 1 Default, 2 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_plug, 'Standard 16A Smart Plug', 'prof_plug_default', 'default', 'Schneider', 'Wiser 16A', 'Automatic load cutoff with power tracking', '1.0.0', 'active', TRUE, 380),
        (v_school_id, v_type_plug, 'Server Rack Metered PDU', 'prof_plug_pdu', 'custom', 'APC', 'AP8858', '32-outlet individual port switching PDU', '2.1.0', 'active', FALSE, 126),
        (v_school_id, v_type_plug, 'Laboratory Equipment Guard', 'prof_plug_lab', 'custom', 'Legrand', 'Smart PDU', 'Surge and high-leakage current breaker profile', '1.0.0', 'active', FALSE, 80)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Lighting (8 Profiles: 1 Default, 7 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_light, 'Standard Classroom LED (4000K)', 'prof_light_default', 'default', 'Philips', 'SmartBright DALI', 'Comfortable neutral white 4000K daylight sync', '1.0.0', 'active', TRUE, 650),
        (v_school_id, v_type_light, 'Corridor Motion-Triggered', 'prof_light_corridor', 'custom', 'Wipro', 'Smart DALI', '10% standby dimming, 100% on motion detection', '1.2.0', 'active', FALSE, 180),
        (v_school_id, v_type_light, 'Auditorium Scene Dimming', 'prof_light_auditorium', 'custom', 'Lutron', 'GRAFIK Eye', 'Pre-programmed Presentation, Speech, Movie scenes', '2.0.0', 'active', FALSE, 85),
        (v_school_id, v_type_light, 'Library Quiet Study (Warm 3000K)', 'prof_light_library', 'custom', 'Havells', 'Adore LED', 'Warm 3000K glare-free study lighting', '1.0.0', 'active', FALSE, 72),
        (v_school_id, v_type_light, 'Sports Floodlight (High Lux)', 'prof_light_sports', 'custom', 'Signify', 'ArenaVision', 'Daylight 5700K 500 Lux sports ground profile', '1.1.0', 'active', FALSE, 45),
        (v_school_id, v_type_light, 'Facade Architectural RGBW', 'prof_light_facade', 'custom', 'Color Kinetics', 'ColorBlast', 'Color washes for festivals and institutional events', '1.3.0', 'active', FALSE, 30),
        (v_school_id, v_type_light, 'Solar Streetlight Autopilot', 'prof_light_solar', 'custom', 'Tata Power Solar', 'SmartStreet', 'Dusk to dawn solar battery optimizing schedule', '1.0.0', 'active', FALSE, 25),
        (v_school_id, v_type_light, 'Emergency Egress Battery LED', 'prof_light_egress', 'custom', 'Schneider', 'Exiway Smart', 'Auto switch to battery upon grid power loss', '1.0.0', 'active', FALSE, 15)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Audio / Speaker (5 Profiles: 1 Default, 4 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_speaker, 'Classroom IP Ceiling Speaker', 'prof_spk_default', 'default', 'Ahuja', 'WS-661T', '20W SIP addressable ceiling speaker for bells & announcements', '1.0.0', 'active', TRUE, 260),
        (v_school_id, v_type_speaker, 'Auditorium Line Array Sound', 'prof_spk_linearray', 'custom', 'JBL Professional', 'CBT 70J-1', 'High fidelity concert & convocation speech system', '2.0.0', 'active', FALSE, 55),
        (v_school_id, v_type_speaker, 'Sports Field Long Range Horn', 'prof_spk_horn', 'custom', 'Bosch', 'LBC 3484/00', 'Weatherproof 50W outdoor public address horn', '1.0.0', 'active', FALSE, 35),
        (v_school_id, v_type_speaker, 'Corridor Bell & Chime', 'prof_spk_bell', 'custom', 'Barix', 'Exstreamer', 'Low latency period bell broadcast player', '1.1.0', 'active', FALSE, 25),
        (v_school_id, v_type_speaker, 'Emergency Evacuation Broadcast', 'prof_spk_evac', 'custom', 'Honeywell', 'INTEVIO', 'Priority override life-safety evacuation voice alarm', '1.0.0', 'active', FALSE, 15)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for HVAC (AC) (6 Profiles: 1 Default, 5 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_ac, 'Classroom Split AC (24°C Comfort)', 'prof_ac_default', 'default', 'Daikin', 'FTKM50', 'Auto cooling with 24°C lower bound for classroom efficiency', '1.0.0', 'active', TRUE, 460),
        (v_school_id, v_type_ac, 'Central VRF Block Chiller', 'prof_ac_vrf', 'custom', 'Voltas', 'V-SVRF', 'Central multi-zone variable refrigerant building loop', '2.0.0', 'active', FALSE, 140),
        (v_school_id, v_type_ac, 'Server Room Precision Cooling (18°C)', 'prof_ac_server', 'custom', 'Vertiv', 'Liebert CRV', 'Dual redundant 18°C 50% RH 24x7 precision control', '1.5.0', 'active', FALSE, 82),
        (v_school_id, v_type_ac, 'Auditorium High Capacity AHU', 'prof_ac_ahu', 'custom', 'Blue Star', 'DS Series AHU', 'Variable airflow AHU with CO2 fresh air damper modulation', '1.2.0', 'active', FALSE, 46),
        (v_school_id, v_type_ac, 'Library Silent Eco Cooling', 'prof_ac_library', 'custom', 'Mitsubishi Electric', 'MSY-GR', 'Ultra-quiet 19dB library study cooling profile', '1.0.0', 'active', FALSE, 32),
        (v_school_id, v_type_ac, 'Faculty Lounge Climate Control', 'prof_ac_faculty', 'custom', 'Hitachi', 'Kashikoi 200i', 'Individual user remote preference with occupancy timer', '1.0.0', 'active', FALSE, 18)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Fan (4 Profiles: 1 Default, 3 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_fan, 'Standard 5-Speed BLDC Fan', 'prof_fan_default', 'default', 'Atomberg', 'Renesa 1200mm', 'Energy-efficient 28W BLDC ceiling fan with smart remote', '1.0.0', 'active', TRUE, 980),
        (v_school_id, v_type_fan, 'Auditorium High Volume HVLS', 'prof_fan_hvls', 'custom', 'Big Ass Fans', 'Powerfoil X3.0', 'Large diameter 16ft slow moving air destratifier', '1.4.0', 'active', FALSE, 210),
        (v_school_id, v_type_fan, 'Hostel Timer Controlled Fan', 'prof_fan_hostel', 'custom', 'Havells', 'Stealth Air', 'Auto shutoff after 4 hours without room occupancy', '1.0.0', 'active', FALSE, 126),
        (v_school_id, v_type_fan, 'Lab Exhaust Fume Airflow', 'prof_fan_exhaust', 'custom', 'Crompton', 'Industrial Exhaust', 'Negative pressure ventilation extractor profile', '1.0.0', 'active', FALSE, 80)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Environment Sensor (5 Profiles: 1 Default, 4 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_env, 'Multi-Sensor Classroom Node', 'prof_env_default', 'default', 'Milesight', 'AM103', 'Indoor temp, humidity and CO2 sensor with E-ink display', '1.0.0', 'active', TRUE, 490),
        (v_school_id, v_type_env, 'Server Room Thermal Beacon', 'prof_env_server', 'custom', 'HW group', 'STE2 r2', 'Precision rack inlet and exhaust temperature monitors', '1.3.0', 'active', FALSE, 160),
        (v_school_id, v_type_env, 'Chemical Lab VOC & Gas Monitor', 'prof_env_chemlab', 'custom', 'Sensirion', 'SCD41/SGP40', 'Volatile organic compound and ammonia threshold detector', '1.1.0', 'active', FALSE, 94),
        (v_school_id, v_type_env, 'Hostel Room Comfort Monitor', 'prof_env_hostel', 'custom', 'Sonoff', 'SNZB-02P', 'Low power wireless zigbee temperature & humidity beacon', '1.0.0', 'active', FALSE, 52),
        (v_school_id, v_type_env, 'Library Humidity Preserver', 'prof_env_library', 'custom', 'TFA Dostmann', 'KlimaLogg', 'Book preservation 45-55% relative humidity monitor', '1.0.0', 'active', FALSE, 28)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Smart Door (3 Profiles: 1 Default, 2 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_door, 'Standard Maglock Access Door', 'prof_door_default', 'default', 'DORMA', 'EM-600', '600lbs electromagnetic fail-safe lock with motion exit sensor', '1.0.0', 'active', TRUE, 120),
        (v_school_id, v_type_door, 'High Security Lab Interlock', 'prof_door_lab', 'custom', 'Assa Abloy', 'Medeco Smart', 'Double door airlock interlock with RFID credential check', '2.0.0', 'active', FALSE, 42),
        (v_school_id, v_type_door, 'Hostel Night Auto-Lock', 'prof_door_hostel', 'custom', 'Yale', 'Smart Deadbolt', 'Auto scheduled lock at 10 PM with night warden override', '1.1.0', 'active', FALSE, 18)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Automatic Gate (3 Profiles: 1 Default, 2 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_gate, 'Main Campus Sliding Gate', 'prof_gate_default', 'default', 'FAAC', '746 ER', 'Heavy duty 600kg rack & pinion motorized perimeter gate', '1.0.0', 'active', TRUE, 26),
        (v_school_id, v_type_gate, 'Staff Parking Rapid Gate', 'prof_gate_rapid', 'custom', 'Came', 'BXV04', 'High speed telescopic gate with ANPR vehicle camera trigger', '1.2.0', 'active', FALSE, 14),
        (v_school_id, v_type_gate, 'Delivery & Service Gate', 'prof_gate_service', 'custom', 'BFT', 'Deimos Ultra', 'Commercial truck entrance gate with intercom gatekeeper switch', '1.0.0', 'active', FALSE, 8)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Turnstile Barrier (2 Profiles: 1 Default, 1 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_barrier, 'Standard Tripod Turnstile', 'prof_barr_default', 'default', 'ZKTeco', 'TS2000 Pro', 'Bi-directional anti-tailgate tripod turnstile with RFID reader', '1.0.0', 'active', TRUE, 24),
        (v_school_id, v_type_barrier, 'Vehicle Boom Barrier (ANPR)', 'prof_barr_boom', 'custom', 'Magnetic Autocontrol', 'Access Pro', 'High speed 1.3s boom barrier with optical vehicle loop safety', '1.5.0', 'active', FALSE, 12)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Water Pump (3 Profiles: 1 Default, 2 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_pump, 'Overhead Tank Transfer Pump', 'prof_pump_default', 'default', 'Kirloskar', 'Jalraaj 5HP', 'Float-switch automated tank replenishment pump', '1.0.0', 'active', TRUE, 38),
        (v_school_id, v_type_pump, 'Submersible Borewell Pump', 'prof_pump_borewell', 'custom', 'Grundfos', 'SP Series 10HP', 'Deep ground water extraction with dry run protection', '1.2.0', 'active', FALSE, 18),
        (v_school_id, v_type_pump, 'Firefighting Hydrant Booster', 'prof_pump_fire', 'custom', 'KSB', 'MegaCPK', 'Diesel-electric high pressure fire line booster pump', '2.0.0', 'active', FALSE, 8)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Energy Meter (3 Profiles: 1 Default, 2 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_meter, 'Building Mains 3-Phase Meter', 'prof_meter_default', 'default', 'Schneider', 'EM6400NG', 'Modbus class 0.5S digital multi-function power meter', '1.0.0', 'active', TRUE, 72),
        (v_school_id, v_type_meter, 'Solar Inverter Net-Meter', 'prof_meter_solar', 'custom', 'Secure Meters', 'Premier 300', 'Bi-directional rooftop solar generation export/import meter', '1.3.0', 'active', FALSE, 26),
        (v_school_id, v_type_meter, 'Hostel Floor Sub-Meter', 'prof_meter_hostel', 'custom', 'L&T', 'Quasar', 'DIN rail sub-metering for student hostel wing billing', '1.0.0', 'active', FALSE, 14)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Fire Alarm (2 Profiles: 1 Default, 1 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_fire, 'Addressable Loop Panel', 'prof_fire_default', 'default', 'Notifier by Honeywell', 'NFS2-640', 'Standard 2-loop addressable life-safety fire controller', '1.0.0', 'active', TRUE, 110),
        (v_school_id, v_type_fire, 'Hostel Repeater Panel', 'prof_fire_repeater', 'custom', 'Notifier', 'LCD-160', 'Secondary remote mimic annunciator panel for warden desk', '1.0.0', 'active', FALSE, 35)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Smoke Detector (2 Profiles: 1 Default, 1 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_smoke, 'Photoelectric Ceiling Sensor', 'prof_smoke_default', 'default', 'Apollo', 'Discovery 58000', 'Addressable optical smoke sensor with drift compensation', '1.0.0', 'active', TRUE, 160),
        (v_school_id, v_type_smoke, 'Kitchen High-Heat Detector', 'prof_smoke_kitchen', 'custom', 'System Sensor', '5600 Series', 'Fixed temp 57°C thermal sensor immune to cooking fumes', '1.0.0', 'active', FALSE, 50)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Biometric Terminal (2 Profiles: 1 Default, 1 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_biometric, 'AI Face Recognition Terminal', 'prof_bio_default', 'default', 'Hikvision', 'DS-K1T673DX', '0.2s visible light anti-spoofing face recognition reader', '1.0.0', 'active', TRUE, 38),
        (v_school_id, v_type_biometric, 'Staff Fingerprint & RFID Terminal', 'prof_bio_fingerprint', 'custom', 'Realtime', 'T52', 'Optical biometric fingerprint sensor with backup keypad', '1.0.0', 'active', FALSE, 17)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Digital Podium (2 Profiles: 1 Default, 1 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_podium, 'Interactive Lectern Standard', 'prof_podium_default', 'default', 'SmartMedia', 'Podium 24', 'Motorized height adjustment podium with 24" touch controller', '1.0.0', 'active', TRUE, 28),
        (v_school_id, v_type_podium, 'Auditorium Master Lectern', 'prof_podium_auditorium', 'custom', 'Crestron', 'Mercury Pod', 'Multi-source HDMI, Dante audio routing and stage lighting pad', '2.0.0', 'active', FALSE, 14)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Lift Controller (2 Profiles: 1 Default, 1 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_lift, 'Passenger Lift Elevator Group', 'prof_lift_default', 'default', 'Otis', 'Gen2 Life', 'Duplex collective passenger elevator group with ARD backup', '1.0.0', 'active', TRUE, 12),
        (v_school_id, v_type_lift, 'Hospital Bed / Service Lift', 'prof_lift_service', 'custom', 'KONE', 'MonoSpace 700', 'High tonnage service elevator with stretcher access lock', '1.0.0', 'active', FALSE, 4)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Smart Socket (2 Profiles: 1 Default, 1 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_socket, 'Standard Classroom Wall Socket', 'prof_sock_default', 'default', 'Anchor by Panasonic', 'Roma Smart 16A', 'Child-safe shuttered Wi-Fi 16A smart wall socket', '1.0.0', 'active', TRUE, 260),
        (v_school_id, v_type_socket, 'Computer Lab Heavy Load Socket', 'prof_sock_lab', 'custom', 'Legrand', 'Arteor Smart', 'Surge filtered 25A socket with thermal safety cutoff', '1.0.0', 'active', FALSE, 80)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Air Quality Monitor (2 Profiles: 1 Default, 1 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_aqi, 'Classroom Indoor Air Node', 'prof_aqi_default', 'default', 'Kaiterra', 'Sensedge Mini', 'Laser particle counter for PM2.5, PM10 and TVOC with cloud sync', '1.0.0', 'active', TRUE, 68),
        (v_school_id, v_type_aqi, 'Lab Fume Concentration Probe', 'prof_aqi_lab', 'custom', 'Aeroqual', 'Series 500', 'Specialized gas sensor head for ozone, chlorine and ammonia', '1.2.0', 'active', FALSE, 30)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Emergency SOS Alarm (2 Profiles: 1 Default, 1 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_sos, 'Hostel Wall Emergency Button', 'prof_sos_default', 'default', 'Securico', 'SOS-100', 'Dual-action latching push button with flash strobe notification', '1.0.0', 'active', TRUE, 22),
        (v_school_id, v_type_sos, 'Chemistry Lab Shower Pull Alarm', 'prof_sos_shower', 'custom', 'Guardian', 'Safety Station', 'Emergency eye-wash & deluge shower alarm switch', '1.0.0', 'active', FALSE, 10)
    ON CONFLICT (school_id, code) DO NOTHING;

    -- Profiles for Weather Station (2 Profiles: 1 Default, 1 Custom)
    INSERT INTO device_profiles (school_id, device_type_id, name, code, profile_type, manufacturer, model, description, version, status, is_default, usage_count)
    VALUES 
        (v_school_id, v_type_weather, 'Campus All-in-One Weather Station', 'prof_weather_default', 'default', 'Davis Instruments', 'Vantage Pro2', 'Solar-powered wireless meteorological sensor suite', '1.0.0', 'active', TRUE, 8),
        (v_school_id, v_type_weather, 'Sports Ground Solar Irradiance', 'prof_weather_sports', 'custom', 'Kipp & Zonen', 'SMP10', 'Pyranometer & UV radiation sensor for outdoor athletic safety', '1.0.0', 'active', FALSE, 4)
    ON CONFLICT (school_id, code) DO NOTHING;

END $$;
