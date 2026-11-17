-- 490_seed_locations_mapping_data.sql
-- Seed Canonical Location Hierarchy, Academic Block A Floor 1 Plan, Devices and Markers
-- Author: Principal IoT Solutions Architect

DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_bldg_acad_a UUID;
    v_bldg_acad_b UUID;
    v_bldg_admin UUID;
    v_bldg_lab UUID;
    v_bldg_lib UUID;
    v_bldg_aud UUID;
    v_bldg_sport UUID;
    v_floor_1 UUID := 'b8b4c4de-11e1-4d42-b4ad-27b86c8c823a';
    v_plan_id UUID := 'a1111111-aaaa-1111-aaaa-111111111111';
    v_room_101 UUID;
    v_room_102 UUID;
    v_room_103 UUID;
    v_room_104 UUID;
    v_room_corr UUID;
    v_room_105 UUID;
    v_room_106 UUID;
    v_room_107 UUID;
    v_type_cctv UUID;
    v_type_light UUID;
    v_type_hvac UUID;
    v_type_prj UUID;
    v_type_ap UUID;
    v_type_spk UUID;
    v_type_fan UUID;
BEGIN
    -- 1. Standardize building names to match screenshot hierarchy exactly
    UPDATE buildings SET name = 'Academic Block (A)', code = 'B1' WHERE code = 'B1' OR (name ILIKE '%Academic Block%A%' OR name = 'Academic Block');
    UPDATE buildings SET name = 'Academic Block (B)', code = 'B2' WHERE code = 'B2' OR (name ILIKE '%Academic Block%B%' OR name ILIKE '%Senior Block%');
    UPDATE buildings SET name = 'Admin Block', code = 'B5' WHERE code = 'B5' OR name ILIKE '%Admin Block%';
    UPDATE buildings SET name = 'Laboratories Block', code = 'B7' WHERE code = 'B7' OR name ILIKE '%Science & Research Block%' OR name ILIKE '%Lab%';
    UPDATE buildings SET name = 'Library Block', code = 'B3' WHERE code = 'B3' OR name ILIKE '%Library%';
    UPDATE buildings SET name = 'Auditorium Block', code = 'B4' WHERE code = 'B4' OR name ILIKE '%Auditorium%';
    UPDATE buildings SET name = 'Sports Complex', code = 'B6' WHERE code = 'B6' OR name ILIKE '%Sports%';

    SELECT id INTO v_bldg_acad_a FROM buildings WHERE school_id = v_school_id AND name = 'Academic Block (A)' LIMIT 1;
    IF v_bldg_acad_a IS NULL THEN
        INSERT INTO buildings (id, school_id, name, code, building_type, total_floors, status)
        VALUES ('2af829b6-81a4-469a-a91a-71f2bd390fc4', v_school_id, 'Academic Block (A)', 'B1', 'Academic', 4, 'Active')
        ON CONFLICT (id) DO UPDATE SET name = 'Academic Block (A)'
        RETURNING id INTO v_bldg_acad_a;
    END IF;

    -- Ensure Floor 1 of Academic Block (A) exists with id = v_floor_1
    IF NOT EXISTS (SELECT 1 FROM building_floors WHERE id = v_floor_1) THEN
        DELETE FROM building_floors WHERE building_id = v_bldg_acad_a AND floor_level = 1;
        INSERT INTO building_floors (id, school_id, building_id, name, floor_code, floor_level, status)
        VALUES (v_floor_1, v_school_id, v_bldg_acad_a, 'First Floor', '1F', 1, 'Active')
        ON CONFLICT (id) DO UPDATE SET name = 'First Floor', floor_code = '1F', floor_level = 1, building_id = v_bldg_acad_a;
    ELSE
        UPDATE building_floors 
        SET name = 'First Floor', floor_code = '1F', floor_level = 1, building_id = v_bldg_acad_a
        WHERE id = v_floor_1;
    END IF;

    -- Ensure Ground Floor and Second Floor exist for Academic Block (A)
    IF NOT EXISTS (SELECT 1 FROM building_floors WHERE building_id = v_bldg_acad_a AND floor_level = 0) THEN
        IF NOT EXISTS (SELECT 1 FROM building_floors WHERE id = '3d6c8096-d7b4-4f98-bc3d-c41d924d4d3d') THEN
            INSERT INTO building_floors (id, school_id, building_id, name, floor_code, floor_level, status)
            VALUES ('3d6c8096-d7b4-4f98-bc3d-c41d924d4d3d', v_school_id, v_bldg_acad_a, 'Ground Floor', 'GF', 0, 'Active');
        END IF;
    ELSE
        UPDATE building_floors 
        SET name = 'Ground Floor', floor_code = 'GF'
        WHERE building_id = v_bldg_acad_a AND floor_level = 0;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM building_floors WHERE building_id = v_bldg_acad_a AND floor_level = 2) THEN
        IF NOT EXISTS (SELECT 1 FROM building_floors WHERE id = '5122b423-c027-42b0-8e96-5b131b0ed94e') THEN
            INSERT INTO building_floors (id, school_id, building_id, name, floor_code, floor_level, status)
            VALUES ('5122b423-c027-42b0-8e96-5b131b0ed94e', v_school_id, v_bldg_acad_a, 'Second Floor', '2F', 2, 'Active');
        END IF;
    ELSE
        UPDATE building_floors 
        SET name = 'Second Floor', floor_code = '2F'
        WHERE building_id = v_bldg_acad_a AND floor_level = 2;
    END IF;

    -- 2. Populate Rooms on First Floor (14 Total Rooms / Spaces)
    -- Room A1-101
    INSERT INTO rooms (id, school_id, building_id, floor_id, name, room_number, room_code, room_type, max_capacity, operational_status)
    VALUES ('4a504056-6e58-46c3-b93c-75fabdae57ac', v_school_id, v_bldg_acad_a, v_floor_1, 'Classroom', 'A1-101', 'A1-101', 'Classroom', 40, 'Available')
    ON CONFLICT (id) DO UPDATE SET room_number = 'A1-101', name = 'Classroom'
    RETURNING id INTO v_room_101;

    -- Room A1-102
    INSERT INTO rooms (id, school_id, building_id, floor_id, name, room_number, room_code, room_type, max_capacity, operational_status)
    VALUES ('e740e824-ee65-4fc6-8e91-4807b158c89e', v_school_id, v_bldg_acad_a, v_floor_1, 'Classroom', 'A1-102', 'A1-102', 'Classroom', 40, 'Available')
    ON CONFLICT (id) DO UPDATE SET room_number = 'A1-102', name = 'Classroom'
    RETURNING id INTO v_room_102;

    -- Room A1-103
    INSERT INTO rooms (id, school_id, building_id, floor_id, name, room_number, room_code, room_type, max_capacity, operational_status)
    VALUES ('7a9cd5c9-de76-419f-9c80-8c4fe5d973aa', v_school_id, v_bldg_acad_a, v_floor_1, 'Classroom', 'A1-103', 'A1-103', 'Classroom', 40, 'Available')
    ON CONFLICT (id) DO UPDATE SET room_number = 'A1-103', name = 'Classroom'
    RETURNING id INTO v_room_103;

    -- Room A1-104
    INSERT INTO rooms (id, school_id, building_id, floor_id, name, room_number, room_code, room_type, max_capacity, operational_status)
    VALUES ('773252f5-a846-4a96-b909-6e1ef1389557', v_school_id, v_bldg_acad_a, v_floor_1, 'Classroom', 'A1-104', 'A1-104', 'Classroom', 40, 'Available')
    ON CONFLICT (id) DO UPDATE SET room_number = 'A1-104', name = 'Classroom'
    RETURNING id INTO v_room_104;

    -- Room A1-Common Area (Corridor)
    INSERT INTO rooms (id, school_id, building_id, floor_id, name, room_number, room_code, room_type, max_capacity, operational_status)
    VALUES ('a1c00000-0000-0000-0000-000000000001', v_school_id, v_bldg_acad_a, v_floor_1, 'Common Area', 'A1-Common Area', 'A1-CORR', 'Corridor', 100, 'Available')
    ON CONFLICT (id) DO UPDATE SET room_number = 'A1-Common Area', name = 'Common Area'
    RETURNING id INTO v_room_corr;

    -- Room A1-105 (Lab)
    INSERT INTO rooms (id, school_id, building_id, floor_id, name, room_number, room_code, room_type, max_capacity, operational_status)
    VALUES ('d651366c-ae8d-4819-a3d4-3234285b09ae', v_school_id, v_bldg_acad_a, v_floor_1, 'Lab', 'A1-105', 'A1-105', 'Laboratory', 35, 'Available')
    ON CONFLICT (id) DO UPDATE SET room_number = 'A1-105', name = 'Lab'
    RETURNING id INTO v_room_105;

    -- Room A1-106 (Lab)
    INSERT INTO rooms (id, school_id, building_id, floor_id, name, room_number, room_code, room_type, max_capacity, operational_status)
    VALUES ('f19f954a-6b41-4e11-8b97-f06c020b7c3e', v_school_id, v_bldg_acad_a, v_floor_1, 'Lab', 'A1-106', 'A1-106', 'Laboratory', 30, 'Available')
    ON CONFLICT (id) DO UPDATE SET room_number = 'A1-106', name = 'Lab'
    RETURNING id INTO v_room_106;

    -- Room A1-107 (Smart Class)
    INSERT INTO rooms (id, school_id, building_id, floor_id, name, room_number, room_code, room_type, max_capacity, operational_status)
    VALUES ('b293ed76-b7d9-4280-9223-f15bc598516c', v_school_id, v_bldg_acad_a, v_floor_1, 'Smart Class', 'A1-107', 'A1-107', 'Smart Classroom', 45, 'Available')
    ON CONFLICT (id) DO UPDATE SET room_number = 'A1-107', name = 'Smart Class'
    RETURNING id INTO v_room_107;

    -- Additional spaces to complete 14 rooms / spaces for First Floor
    INSERT INTO rooms (id, school_id, building_id, floor_id, name, room_number, room_code, room_type, max_capacity, operational_status)
    VALUES 
        ('d52c5fba-85a5-4dd6-9925-b6912c7e3b6d', v_school_id, v_bldg_acad_a, v_floor_1, 'Staff Room', 'A1-108', 'A1-108', 'Staff Room', 20, 'Available'),
        ('a1c00000-0000-0000-0000-000000000009', v_school_id, v_bldg_acad_a, v_floor_1, 'Seminar Room', 'A1-109', 'A1-109', 'Auditorium', 60, 'Available'),
        ('a1c00000-0000-0000-0000-000000000010', v_school_id, v_bldg_acad_a, v_floor_1, 'Faculty Lounge', 'A1-110', 'A1-110', 'Lounge', 15, 'Available'),
        ('a1c00000-0000-0000-0000-000000000011', v_school_id, v_bldg_acad_a, v_floor_1, 'Restroom East', 'A1-111', 'A1-111', 'Restroom', 10, 'Available'),
        ('a1c00000-0000-0000-0000-000000000012', v_school_id, v_bldg_acad_a, v_floor_1, 'Restroom West', 'A1-112', 'A1-112', 'Restroom', 10, 'Available'),
        ('a1c00000-0000-0000-0000-000000000014', v_school_id, v_bldg_acad_a, v_floor_1, 'Server & Hub Room', 'A1-114', 'A1-114', 'Utility', 5, 'Available')
    ON CONFLICT (id) DO NOTHING;

    -- 3. Resolve Device Types
    SELECT id INTO v_type_cctv FROM device_types WHERE code = 'cctv_camera' LIMIT 1;
    SELECT id INTO v_type_light FROM device_types WHERE code = 'lighting' LIMIT 1;
    SELECT id INTO v_type_hvac FROM device_types WHERE code = 'ac' LIMIT 1;
    SELECT id INTO v_type_prj FROM device_types WHERE code = 'projector' LIMIT 1;
    SELECT id INTO v_type_ap FROM device_types WHERE code = 'wifi_access_point' LIMIT 1;
    SELECT id INTO v_type_spk FROM device_types WHERE code = 'audio_speakers' LIMIT 1;
    SELECT id INTO v_type_fan FROM device_types WHERE code = 'fan' LIMIT 1;

    -- 4. Seed Canonical Devices matching Screenshot Table Rows (14 total)
    -- Row 1: CAM-A1-101 (CCTV)
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state, operational_status)
    VALUES ('c1c00000-0000-0000-0000-000000000001', v_school_id, v_bldg_acad_a, v_floor_1, v_room_101, v_type_cctv, 'CAM-A1-101', 'CAM-A1-101', true, true, 'operational')
    ON CONFLICT (school_id, device_code) DO UPDATE SET 
        building_id = EXCLUDED.building_id, floor_id = EXCLUDED.floor_id, room_id = EXCLUDED.room_id, device_type_id = EXCLUDED.device_type_id;

    -- Row 2: LIGHT-A1-101 (Lighting)
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state, operational_status)
    VALUES ('c1c00000-0000-0000-0000-000000000002', v_school_id, v_bldg_acad_a, v_floor_1, v_room_101, v_type_light, 'LIGHT-A1-101', 'LIGHT-A1-101', true, true, 'operational')
    ON CONFLICT (school_id, device_code) DO UPDATE SET 
        building_id = EXCLUDED.building_id, floor_id = EXCLUDED.floor_id, room_id = EXCLUDED.room_id, device_type_id = EXCLUDED.device_type_id;

    -- Row 3: AC-A1-101 (HVAC (AC))
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state, operational_status)
    VALUES ('c1c00000-0000-0000-0000-000000000003', v_school_id, v_bldg_acad_a, v_floor_1, v_room_101, v_type_hvac, 'AC-A1-101', 'AC-A1-101', true, true, 'operational')
    ON CONFLICT (school_id, device_code) DO UPDATE SET 
        building_id = EXCLUDED.building_id, floor_id = EXCLUDED.floor_id, room_id = EXCLUDED.room_id, device_type_id = EXCLUDED.device_type_id;

    -- Row 4: PRJ-A1-102 (Projector)
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state, operational_status)
    VALUES ('c1c00000-0000-0000-0000-000000000004', v_school_id, v_bldg_acad_a, v_floor_1, v_room_102, v_type_prj, 'PRJ-A1-102', 'PRJ-A1-102', true, true, 'operational')
    ON CONFLICT (school_id, device_code) DO UPDATE SET 
        building_id = EXCLUDED.building_id, floor_id = EXCLUDED.floor_id, room_id = EXCLUDED.room_id, device_type_id = EXCLUDED.device_type_id;

    -- Row 5: AP-A1-1F-01 (Access Point)
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state, operational_status)
    VALUES ('c1c00000-0000-0000-0000-000000000005', v_school_id, v_bldg_acad_a, v_floor_1, v_room_corr, v_type_ap, 'AP-A1-1F-01', 'AP-A1-1F-01', true, true, 'operational')
    ON CONFLICT (school_id, device_code) DO UPDATE SET 
        building_id = EXCLUDED.building_id, floor_id = EXCLUDED.floor_id, room_id = EXCLUDED.room_id, device_type_id = EXCLUDED.device_type_id;

    -- Row 6: SPK-A1-1F-01 (Audio / Speaker)
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state, operational_status)
    VALUES ('c1c00000-0000-0000-0000-000000000006', v_school_id, v_bldg_acad_a, v_floor_1, v_room_corr, v_type_spk, 'SPK-A1-1F-01', 'SPK-A1-1F-01', true, true, 'operational')
    ON CONFLICT (school_id, device_code) DO UPDATE SET 
        building_id = EXCLUDED.building_id, floor_id = EXCLUDED.floor_id, room_id = EXCLUDED.room_id, device_type_id = EXCLUDED.device_type_id;

    -- Rows 7-14: Complete 14 devices
    INSERT INTO devices (id, school_id, building_id, floor_id, room_id, device_type_id, device_name, device_code, is_online, power_state, operational_status)
    VALUES 
        ('c1c00000-0000-0000-0000-000000000007', v_school_id, v_bldg_acad_a, v_floor_1, v_room_102, v_type_light, 'LIGHT-A1-102', 'LIGHT-A1-102', true, true, 'operational'),
        ('c1c00000-0000-0000-0000-000000000008', v_school_id, v_bldg_acad_a, v_floor_1, v_room_103, v_type_light, 'LIGHT-A1-103', 'LIGHT-A1-103', true, true, 'operational'),
        ('c1c00000-0000-0000-0000-000000000009', v_school_id, v_bldg_acad_a, v_floor_1, v_room_103, v_type_hvac, 'AC-A1-103', 'AC-A1-103', true, true, 'operational'),
        ('c1c00000-0000-0000-0000-000000000010', v_school_id, v_bldg_acad_a, v_floor_1, v_room_104, v_type_light, 'LIGHT-A1-104', 'LIGHT-A1-104', true, true, 'operational'),
        ('c1c00000-0000-0000-0000-000000000011', v_school_id, v_bldg_acad_a, v_floor_1, v_room_104, v_type_fan, 'FAN-A1-104', 'FAN-A1-104', true, true, 'operational'),
        ('c1c00000-0000-0000-0000-000000000012', v_school_id, v_bldg_acad_a, v_floor_1, v_room_105, v_type_cctv, 'CAM-A1-105', 'CAM-A1-105', true, true, 'operational'),
        ('c1c00000-0000-0000-0000-000000000013', v_school_id, v_bldg_acad_a, v_floor_1, v_room_105, v_type_light, 'LIGHT-A1-105', 'LIGHT-A1-105', true, true, 'operational'),
        ('c1c00000-0000-0000-0000-000000000014', v_school_id, v_bldg_acad_a, v_floor_1, v_room_106, v_type_light, 'LIGHT-A1-106', 'LIGHT-A1-106', true, true, 'operational')
    ON CONFLICT (school_id, device_code) DO UPDATE SET 
        building_id = EXCLUDED.building_id, floor_id = EXCLUDED.floor_id, room_id = EXCLUDED.room_id, device_type_id = EXCLUDED.device_type_id;

    -- 5. Seed Floor Plan Asset for Academic Block (A) First Floor
    INSERT INTO floor_plan_assets (
        id, school_id, building_id, floor_id, title, version,
        dimensions_width, dimensions_height, scale_pixels_per_meter,
        rooms_layout
    ) VALUES (
        v_plan_id, v_school_id, v_bldg_acad_a, v_floor_1,
        'Academic Block (A) – First Floor Architectural Plan', 'v1.0',
        1200.0, 750.0, 25.0,
        '[
            {"room_id": "4a504056-6e58-46c3-b93c-75fabdae57ac", "code": "A1-101", "name": "Classroom", "x": 0.04, "y": 0.08, "w": 0.21, "h": 0.36},
            {"room_id": "e740e824-ee65-4fc6-8e91-4807b158c89e", "code": "A1-102", "name": "Classroom", "x": 0.27, "y": 0.08, "w": 0.21, "h": 0.36},
            {"room_id": "7a9cd5c9-de76-419f-9c80-8c4fe5d973aa", "code": "A1-103", "name": "Classroom", "x": 0.50, "y": 0.08, "w": 0.21, "h": 0.36},
            {"room_id": "773252f5-a846-4a96-b909-6e1ef1389557", "code": "A1-104", "name": "Classroom", "x": 0.73, "y": 0.08, "w": 0.23, "h": 0.36},
            {"room_id": "a1c00000-0000-0000-0000-000000000001", "code": "Corridor", "name": "Corridor", "x": 0.04, "y": 0.46, "w": 0.92, "h": 0.10},
            {"room_id": "d651366c-ae8d-4819-a3d4-3234285b09ae", "code": "A1-105", "name": "Lab", "x": 0.04, "y": 0.58, "w": 0.29, "h": 0.36},
            {"room_id": "f19f954a-6b41-4e11-8b97-f06c020b7c3e", "code": "A1-106", "name": "Lab", "x": 0.35, "y": 0.58, "w": 0.29, "h": 0.36},
            {"room_id": "b293ed76-b7d9-4280-9223-f15bc598516c", "code": "A1-107", "name": "Smart Class", "x": 0.66, "y": 0.58, "w": 0.30, "h": 0.36}
        ]'::jsonb
    ) ON CONFLICT (id) DO UPDATE SET 
        title = EXCLUDED.title,
        rooms_layout = EXCLUDED.rooms_layout;

    -- 6. Seed Floor Plan Markers for All 14 Mapped Devices
    DELETE FROM floor_plan_markers WHERE floor_plan_id = v_plan_id;

    -- A1-101: CCTV, Lighting, HVAC
    INSERT INTO floor_plan_markers (school_id, floor_plan_id, floor_id, room_id, device_id, pos_x, pos_y, marker_label)
    VALUES 
        (v_school_id, v_plan_id, v_floor_1, v_room_101, 'c1c00000-0000-0000-0000-000000000001', 0.11, 0.18, 'CAM-A1-101'),
        (v_school_id, v_plan_id, v_floor_1, v_room_101, 'c1c00000-0000-0000-0000-000000000002', 0.15, 0.28, 'LIGHT-A1-101'),
        (v_school_id, v_plan_id, v_floor_1, v_room_101, 'c1c00000-0000-0000-0000-000000000003', 0.19, 0.18, 'AC-A1-101');

    -- A1-102: Projector, Lighting
    INSERT INTO floor_plan_markers (school_id, floor_plan_id, floor_id, room_id, device_id, pos_x, pos_y, marker_label)
    VALUES 
        (v_school_id, v_plan_id, v_floor_1, v_room_102, 'c1c00000-0000-0000-0000-000000000004', 0.34, 0.22, 'PRJ-A1-102'),
        (v_school_id, v_plan_id, v_floor_1, v_room_102, 'c1c00000-0000-0000-0000-000000000007', 0.38, 0.28, 'LIGHT-A1-102');

    -- A1-103: Lighting, HVAC
    INSERT INTO floor_plan_markers (school_id, floor_plan_id, floor_id, room_id, device_id, pos_x, pos_y, marker_label)
    VALUES 
        (v_school_id, v_plan_id, v_floor_1, v_room_103, 'c1c00000-0000-0000-0000-000000000008', 0.57, 0.28, 'LIGHT-A1-103'),
        (v_school_id, v_plan_id, v_floor_1, v_room_103, 'c1c00000-0000-0000-0000-000000000009', 0.61, 0.18, 'AC-A1-103');

    -- A1-104: Lighting, Fan
    INSERT INTO floor_plan_markers (school_id, floor_plan_id, floor_id, room_id, device_id, pos_x, pos_y, marker_label)
    VALUES 
        (v_school_id, v_plan_id, v_floor_1, v_room_104, 'c1c00000-0000-0000-0000-000000000010', 0.80, 0.28, 'LIGHT-A1-104'),
        (v_school_id, v_plan_id, v_floor_1, v_room_104, 'c1c00000-0000-0000-0000-000000000011', 0.84, 0.20, 'FAN-A1-104');

    -- Corridor: Access Point, Speaker
    INSERT INTO floor_plan_markers (school_id, floor_plan_id, floor_id, room_id, device_id, pos_x, pos_y, marker_label)
    VALUES 
        (v_school_id, v_plan_id, v_floor_1, v_room_corr, 'c1c00000-0000-0000-0000-000000000005', 0.44, 0.50, 'AP-A1-1F-01'),
        (v_school_id, v_plan_id, v_floor_1, v_room_corr, 'c1c00000-0000-0000-0000-000000000006', 0.54, 0.50, 'SPK-A1-1F-01');

    -- A1-105 (Lab): CCTV, Lighting
    INSERT INTO floor_plan_markers (school_id, floor_plan_id, floor_id, room_id, device_id, pos_x, pos_y, marker_label)
    VALUES 
        (v_school_id, v_plan_id, v_floor_1, v_room_105, 'c1c00000-0000-0000-0000-000000000012', 0.14, 0.76, 'CAM-A1-105'),
        (v_school_id, v_plan_id, v_floor_1, v_room_105, 'c1c00000-0000-0000-0000-000000000013', 0.22, 0.76, 'LIGHT-A1-105');

    -- A1-106 (Lab): Lighting
    INSERT INTO floor_plan_markers (school_id, floor_plan_id, floor_id, room_id, device_id, pos_x, pos_y, marker_label)
    VALUES 
        (v_school_id, v_plan_id, v_floor_1, v_room_106, 'c1c00000-0000-0000-0000-000000000014', 0.48, 0.76, 'LIGHT-A1-106');

    -- Synchronize location_device_assignments
    INSERT INTO location_device_assignments (school_id, device_id, building_id, floor_id, room_id, status)
    SELECT d.school_id, d.id, d.building_id, d.floor_id, d.room_id, 'Mapped'
    FROM devices d
    WHERE d.floor_id = v_floor_1
    ON CONFLICT (device_id, is_primary) DO UPDATE SET 
        building_id = EXCLUDED.building_id, floor_id = EXCLUDED.floor_id, room_id = EXCLUDED.room_id;

END;
$$;
