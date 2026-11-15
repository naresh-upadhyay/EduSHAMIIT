-- ============================================================================
-- Migration: 446_seed_campus_buildings_data.sql
-- Description: Seed enterprise campus infrastructure matching Greenwood High School:
--              8 Buildings, 38 Floors, 156 Rooms, 7,560 Total Capacity,
--              6,842 Occupancy (90.5%), 718 Available (9.5%).
-- ============================================================================

DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_admin_id UUID;
    v_campus_id UUID;
    v_b1_id UUID;
    v_b2_id UUID;
    v_b3_id UUID;
    v_b4_id UUID;
    v_b5_id UUID;
    v_b6_id UUID;
    v_b7_id UUID;
    v_b8_id UUID;

    -- B1 Floors
    v_f_g UUID;
    v_f_1 UUID;
    v_f_2 UUID;
    v_f_3 UUID;
    v_f_4 UUID;

    v_rm_id UUID;
    i INT;
BEGIN
    -- Check if already seeded
    IF EXISTS (SELECT 1 FROM public.buildings WHERE school_id = v_school_id AND UPPER(code) = 'B1') THEN
        RETURN;
    END IF;

    -- Lookup an existing profile ID for auditing, or leave null if none exist
    SELECT id INTO v_admin_id FROM public.profiles WHERE school_id = v_school_id LIMIT 1;
    IF v_admin_id IS NULL THEN
        SELECT id INTO v_admin_id FROM public.profiles LIMIT 1;
    END IF;

    -- 1. Main Campus
    INSERT INTO public.campuses (
        school_id, name, code, address, city, state, status, created_by, updated_by
    ) VALUES (
        v_school_id, 'Greenwood Main Campus', 'MAIN',
        'Campus Road, Sarjapur, Bangalore, Karnataka - 560035', 'Bangalore', 'Karnataka',
        'ACTIVE', v_admin_id, v_admin_id
    ) RETURNING id INTO v_campus_id;

    -- 2. Eight Buildings
    -- B1: Academic Block
    INSERT INTO public.buildings (
        school_id, campus_id, name, code, building_type, description, purpose,
        address, total_floors, total_area, area_unit, construction_year, num_entrances, num_emergency_exits,
        manager_name, manager_contact, department,
        image_url, fire_safety_cert_expiry, occupancy_cert_expiry, status, created_by, updated_by
    ) VALUES (
        v_school_id, v_campus_id, 'Academic Block', 'B1', 'Academic',
        'Main academic building with classrooms, laboratories and staff rooms',
        'Primary Academic Instruction & Laboratories',
        'Block 1, Greenwood Main Campus', 5, 45000.0, 'sq ft', 2018, 3, 4,
        'Dr. Rajesh Sharma', '+91 98450 12345', 'Senior Secondary School',
        'https://images.unsplash.com/photo-1562774053-701939374585?auto=format&fit=crop&w=800&q=80',
        '2028-12-31', '2030-06-30', 'Active', v_admin_id, v_admin_id
    ) RETURNING id INTO v_b1_id;

    -- B2: Senior Block
    INSERT INTO public.buildings (
        school_id, campus_id, name, code, building_type, description, purpose,
        address, total_floors, total_area, area_unit, construction_year, num_entrances, num_emergency_exits,
        manager_name, manager_contact, department,
        image_url, fire_safety_cert_expiry, occupancy_cert_expiry, status, created_by, updated_by
    ) VALUES (
        v_school_id, v_campus_id, 'Senior Block', 'B2', 'Academic',
        'Dedicated senior secondary block with specialized seminar halls',
        'Senior Secondary (Grades 11-12) & Competitive Exam Prep',
        'Block 2, Greenwood Main Campus', 3, 32000.0, 'sq ft', 2019, 2, 2,
        'Mrs. Sunita Deshmukh', '+91 98450 23456', 'Senior Wing',
        'https://images.unsplash.com/photo-1541829070764-84a7d30dd3f3?auto=format&fit=crop&w=800&q=80',
        '2028-09-30', '2029-12-31', 'Active', v_admin_id, v_admin_id
    ) RETURNING id INTO v_b2_id;

    -- B3: Library Block
    INSERT INTO public.buildings (
        school_id, campus_id, name, code, building_type, description, purpose,
        address, total_floors, total_area, area_unit, construction_year, num_entrances, num_emergency_exits,
        manager_name, manager_contact, department,
        image_url, fire_safety_cert_expiry, occupancy_cert_expiry, status, created_by, updated_by
    ) VALUES (
        v_school_id, v_campus_id, 'Library Block', 'B3', 'Library',
        'Central library, digital learning zone, reading halls and book archive',
        'Research, Reference & Self-Study',
        'Block 3, Greenwood Main Campus', 2, 16000.0, 'sq ft', 2020, 2, 2,
        'Mr. Vikram Mehta', '+91 98450 34567', 'Library & Learning Resources',
        'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?auto=format&fit=crop&w=800&q=80',
        '2029-05-31', '2030-01-15', 'Active', v_admin_id, v_admin_id
    ) RETURNING id INTO v_b3_id;

    -- B4: Auditorium & Cultural Complex
    INSERT INTO public.buildings (
        school_id, campus_id, name, code, building_type, description, purpose,
        address, total_floors, total_area, area_unit, construction_year, num_entrances, num_emergency_exits,
        manager_name, manager_contact, department,
        image_url, fire_safety_cert_expiry, occupancy_cert_expiry, status, created_by, updated_by
    ) VALUES (
        v_school_id, v_campus_id, 'Auditorium', 'B4', 'Auditorium',
        '1,200 seat theater hall, acoustic seminar room, and rehearsal rooms',
        'Convocations, Assemblies, Seminars & Cultural Events',
        'Block 4, Greenwood Main Campus', 2, 22000.0, 'sq ft', 2021, 4, 6,
        'Mr. Anand Kulkarni', '+91 98450 45678', 'Cultural Affairs',
        'https://images.unsplash.com/photo-1511578314322-379afb476865?auto=format&fit=crop&w=800&q=80',
        '2029-10-31', '2030-10-31', 'Active', v_admin_id, v_admin_id
    ) RETURNING id INTO v_b4_id;

    -- B5: Admin Block
    INSERT INTO public.buildings (
        school_id, campus_id, name, code, building_type, description, purpose,
        address, total_floors, total_area, area_unit, construction_year, num_entrances, num_emergency_exits,
        manager_name, manager_contact, department,
        image_url, fire_safety_cert_expiry, occupancy_cert_expiry, status, created_by, updated_by
    ) VALUES (
        v_school_id, v_campus_id, 'Admin Block', 'B5', 'Administrative',
        'Central institutional leadership, HR, finance, registrar, and reception',
        'Institutional Governance & Administrative Operations',
        'Block 5, Greenwood Main Campus', 3, 20000.0, 'sq ft', 2017, 2, 2,
        'Ms. Priya Nambiar', '+91 98450 56789', 'Central Administration',
        'https://images.unsplash.com/photo-1497366216548-37526070297c?auto=format&fit=crop&w=800&q=80',
        '2028-11-30', '2030-03-31', 'Active', v_admin_id, v_admin_id
    ) RETURNING id INTO v_b5_id;

    -- B6: Sports Complex
    INSERT INTO public.buildings (
        school_id, campus_id, name, code, building_type, description, purpose,
        address, total_floors, total_area, area_unit, construction_year, num_entrances, num_emergency_exits,
        manager_name, manager_contact, department,
        image_url, fire_safety_cert_expiry, occupancy_cert_expiry, status, created_by, updated_by
    ) VALUES (
        v_school_id, v_campus_id, 'Sports Complex', 'B6', 'Sports',
        'Indoor badminton courts, gymnasium, yoga hall, and athletic lockers',
        'Physical Education & Athletics',
        'Block 6, Greenwood Main Campus', 2, 28000.0, 'sq ft', 2022, 3, 3,
        'Coach Gurpreet Singh', '+91 98450 67890', 'Physical Education',
        'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=800&q=80',
        '2029-08-31', '2031-01-31', 'Active', v_admin_id, v_admin_id
    ) RETURNING id INTO v_b6_id;

    -- B7: Science & Research Block
    INSERT INTO public.buildings (
        school_id, campus_id, name, code, building_type, description, purpose,
        address, total_floors, total_area, area_unit, construction_year, num_entrances, num_emergency_exits,
        manager_name, manager_contact, department,
        image_url, fire_safety_cert_expiry, occupancy_cert_expiry, status, created_by, updated_by
    ) VALUES (
        v_school_id, v_campus_id, 'Science & Research Block', 'B7', 'Laboratory',
        'Advanced physics, chemistry, biotechnology, and robotics innovation labs',
        'Science Education & Student Innovation Labs',
        'Block 7, Greenwood Main Campus', 4, 30000.0, 'sq ft', 2021, 2, 3,
        'Dr. Meenakshi Sundaram', '+91 98450 78901', 'Science & Technology',
        'https://images.unsplash.com/photo-1532094349884-543bc11b234d?auto=format&fit=crop&w=800&q=80',
        '2029-04-30', '2030-08-31', 'Active', v_admin_id, v_admin_id
    ) RETURNING id INTO v_b7_id;

    -- B8: Hostel Block A
    INSERT INTO public.buildings (
        school_id, campus_id, name, code, building_type, description, purpose,
        address, total_floors, total_area, area_unit, construction_year, num_entrances, num_emergency_exits,
        manager_name, manager_contact, department,
        image_url, fire_safety_cert_expiry, occupancy_cert_expiry, status, created_by, updated_by
    ) VALUES (
        v_school_id, v_campus_id, 'Hostel Block A', 'B8', 'Hostel',
        'Residential student block with recreation room and dining lounge',
        'Student Residential Housing',
        'Block 8, Greenwood Main Campus', 5, 38000.0, 'sq ft', 2020, 2, 4,
        'Mr. Rameshwar Verma', '+91 98450 89012', 'Hostel Administration',
        'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?auto=format&fit=crop&w=800&q=80',
        '2029-07-31', '2030-11-30', 'Active', v_admin_id, v_admin_id
    ) RETURNING id INTO v_b8_id;


    -- ------------------------------------------------------------------------
    -- 3. Seed Floors in B1 - Academic Block (5 Floors: G, F1, F2, F3, F4)
    -- ------------------------------------------------------------------------
    INSERT INTO public.building_floors (
        school_id, building_id, name, floor_code, floor_level, floor_order, floor_type, area, description, status, created_by, updated_by
    ) VALUES (
        v_school_id, v_b1_id, 'Ground Floor (G)', 'G', 0, 0, 'Classroom & Office', 9000.0,
        'Main entrance lobby, reception, primary classrooms and washrooms', 'Active', v_admin_id, v_admin_id
    ) RETURNING id INTO v_f_g;

    INSERT INTO public.building_floors (
        school_id, building_id, name, floor_code, floor_level, floor_order, floor_type, area, description, status, created_by, updated_by
    ) VALUES (
        v_school_id, v_b1_id, 'First Floor (F1)', 'F1', 1, 1, 'Academic & Lab', 9000.0,
        'Secondary classrooms, physics lab and faculty staff rooms', 'Active', v_admin_id, v_admin_id
    ) RETURNING id INTO v_f_1;

    INSERT INTO public.building_floors (
        school_id, building_id, name, floor_code, floor_level, floor_order, floor_type, area, description, status, created_by, updated_by
    ) VALUES (
        v_school_id, v_b1_id, 'Second Floor (F2)', 'F2', 2, 2, 'Academic & Lab', 9000.0,
        'Secondary classrooms, chemistry lab and faculty staff rooms', 'Active', v_admin_id, v_admin_id
    ) RETURNING id INTO v_f_2;

    INSERT INTO public.building_floors (
        school_id, building_id, name, floor_code, floor_level, floor_order, floor_type, area, description, status, created_by, updated_by
    ) VALUES (
        v_school_id, v_b1_id, 'Third Floor (F3)', 'F3', 3, 3, 'Academic & Lab', 9000.0,
        'Senior secondary classrooms, biology lab and departmental heads', 'Active', v_admin_id, v_admin_id
    ) RETURNING id INTO v_f_3;

    INSERT INTO public.building_floors (
        school_id, building_id, name, floor_code, floor_level, floor_order, floor_type, area, description, status, created_by, updated_by
    ) VALUES (
        v_school_id, v_b1_id, 'Fourth Floor (F4)', 'F4', 4, 4, 'Academic & Special', 9000.0,
        'Smart interactive classrooms, language lab and examination hall', 'Active', v_admin_id, v_admin_id
    ) RETURNING id INTO v_f_4;


    -- ------------------------------------------------------------------------
    -- 4. Seed Rooms in B1 - Academic Block (42 Rooms Total, 2,100 Capacity, 1,950 Occupied)
    -- ------------------------------------------------------------------------
    -- Ground Floor (G): 8 Rooms (Cap: 400, Occ: 368)
    -- G001 (Reception), G002 (Classroom 1A), G003 (Classroom 1B), G004 (Classroom 1C), G005 (Classroom 1D),
    -- G006 (Junior Science Lab), G007 (Computer Discovery Lab), G008 (Admin Office)
    INSERT INTO public.rooms (
        school_id, building_id, floor_id, name, room_number, room_code, room_type,
        max_capacity, recommended_capacity, current_occupancy, seating_capacity, operational_status, assignment_status, created_by, updated_by
    ) VALUES
    (v_school_id, v_b1_id, v_f_g, 'Campus Reception & Visitor Center', 'G001', 'RM-G001', 'Reception', 30, 25, 20, 25, 'Available', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_g, 'Grade 1 - Section A', 'G002', 'RM-G002', 'Classroom', 50, 45, 48, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_g, 'Grade 1 - Section B', 'G003', 'RM-G003', 'Classroom', 50, 45, 47, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_g, 'Grade 1 - Section C', 'G004', 'RM-G004', 'Classroom', 50, 45, 46, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_g, 'Grade 1 - Section D', 'G005', 'RM-G005', 'Classroom', 50, 45, 47, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_g, 'Junior Science Laboratory', 'G006', 'RM-G006', 'Laboratory', 60, 50, 56, 60, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_g, 'Computer Discovery Lab', 'G007', 'RM-G007', 'Computer Lab', 60, 50, 58, 60, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_g, 'Headmaster Office', 'G008', 'RM-G008', 'Principal Office', 50, 45, 46, 50, 'Available', 'Assigned', v_admin_id, v_admin_id);

    -- Add Equipment to G006 (Junior Science Lab)
    SELECT id INTO v_rm_id FROM public.rooms WHERE building_id = v_b1_id AND room_number = 'G006';
    INSERT INTO public.room_equipment (
        school_id, building_id, floor_id, room_id, equipment_name, equipment_category, quantity, condition, operational_status, created_by, updated_by
    ) VALUES
    (v_school_id, v_b1_id, v_f_g, v_rm_id, 'Microscopes (Optical)', 'Laboratory', 25, 'Excellent', 'Operational', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_g, v_rm_id, 'Smart Interactive Board', 'IT & AV', 1, 'Good', 'Operational', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_g, v_rm_id, 'Emergency Eye Wash Station', 'Safety & Medical', 1, 'Good', 'Operational', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_g, v_rm_id, 'Fume Exhaust Hood', 'HVAC', 1, 'Fair', 'Under Maintenance', v_admin_id, v_admin_id);

    -- First Floor (F1): 8 Rooms (Cap: 400, Occ: 372)
    -- 101..106 (Classrooms), 107 (Physics Lab), 108 (Staff Room)
    INSERT INTO public.rooms (
        school_id, building_id, floor_id, name, room_number, room_code, room_type,
        max_capacity, recommended_capacity, current_occupancy, seating_capacity, operational_status, assignment_status, created_by, updated_by
    ) VALUES
    (v_school_id, v_b1_id, v_f_1, 'Grade 2 - Section A', '101', 'RM-101', 'Classroom', 50, 45, 48, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_1, 'Grade 2 - Section B', '102', 'RM-102', 'Classroom', 50, 45, 47, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_1, 'Grade 2 - Section C', '103', 'RM-103', 'Classroom', 50, 45, 46, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_1, 'Grade 2 - Section D', '104', 'RM-104', 'Classroom', 50, 45, 47, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_1, 'Grade 3 - Section A', '105', 'RM-105', 'Classroom', 50, 45, 49, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_1, 'Grade 3 - Section B', '106', 'RM-106', 'Classroom', 50, 45, 48, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_1, 'Physics Laboratory Alpha', '107', 'RM-107', 'Physics Lab', 60, 50, 52, 60, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_1, 'Staff Room - Wing 1', '108', 'RM-108', 'Staff Room', 40, 35, 35, 40, 'Available', 'Assigned', v_admin_id, v_admin_id);

    -- Second Floor (F2): 8 Rooms (Cap: 400, Occ: 376)
    -- 201..206 (Classrooms), 207 (Chemistry Lab), 208 (Staff Room)
    INSERT INTO public.rooms (
        school_id, building_id, floor_id, name, room_number, room_code, room_type,
        max_capacity, recommended_capacity, current_occupancy, seating_capacity, operational_status, assignment_status, created_by, updated_by
    ) VALUES
    (v_school_id, v_b1_id, v_f_2, 'Grade 4 - Section A', '201', 'RM-201', 'Classroom', 50, 45, 48, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_2, 'Grade 4 - Section B', '202', 'RM-202', 'Classroom', 50, 45, 47, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_2, 'Grade 4 - Section C', '203', 'RM-203', 'Classroom', 50, 45, 48, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_2, 'Grade 5 - Section A', '204', 'RM-204', 'Classroom', 50, 45, 47, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_2, 'Grade 5 - Section B', '205', 'RM-205', 'Classroom', 50, 45, 49, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_2, 'Grade 5 - Section C', '206', 'RM-206', 'Classroom', 50, 45, 47, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_2, 'Chemistry Laboratory Beta', '207', 'RM-207', 'Chemistry Lab', 60, 50, 54, 60, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_2, 'Staff Room - Wing 2', '208', 'RM-208', 'Staff Room', 40, 35, 36, 40, 'Available', 'Assigned', v_admin_id, v_admin_id);

    -- Third Floor (F3): 8 Rooms (Cap: 400, Occ: 372)
    -- 301..306 (Classrooms), 307 (Biology Lab), 308 (Staff Room)
    INSERT INTO public.rooms (
        school_id, building_id, floor_id, name, room_number, room_code, room_type,
        max_capacity, recommended_capacity, current_occupancy, seating_capacity, operational_status, assignment_status, created_by, updated_by
    ) VALUES
    (v_school_id, v_b1_id, v_f_3, 'Grade 6 - Section A', '301', 'RM-301', 'Classroom', 50, 45, 47, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_3, 'Grade 6 - Section B', '302', 'RM-302', 'Classroom', 50, 45, 48, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_3, 'Grade 7 - Section A', '303', 'RM-303', 'Classroom', 50, 45, 47, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_3, 'Grade 7 - Section B', '304', 'RM-304', 'Classroom', 50, 45, 48, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_3, 'Grade 8 - Section A', '305', 'RM-305', 'Classroom', 50, 45, 46, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_3, 'Grade 8 - Section B', '306', 'RM-306', 'Classroom', 50, 45, 47, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_3, 'Biology & Life Science Lab', '307', 'RM-307', 'Biology Lab', 60, 50, 54, 60, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_3, 'Staff Room - Wing 3', '308', 'RM-308', 'Staff Room', 40, 35, 35, 40, 'Available', 'Assigned', v_admin_id, v_admin_id);

    -- Fourth Floor (F4): 10 Rooms (Cap: 500, Occ: 462)
    -- 401..408 (Classrooms), 409 (Language Lab), 410 (AV Seminar Hall)
    INSERT INTO public.rooms (
        school_id, building_id, floor_id, name, room_number, room_code, room_type,
        max_capacity, recommended_capacity, current_occupancy, seating_capacity, operational_status, assignment_status, created_by, updated_by
    ) VALUES
    (v_school_id, v_b1_id, v_f_4, 'Grade 9 - Section A', '401', 'RM-401', 'Classroom', 50, 45, 48, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_4, 'Grade 9 - Section B', '402', 'RM-402', 'Classroom', 50, 45, 47, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_4, 'Grade 9 - Section C', '403', 'RM-403', 'Classroom', 50, 45, 46, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_4, 'Grade 10 - Section A', '404', 'RM-404', 'Classroom', 50, 45, 48, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_4, 'Grade 10 - Section B', '405', 'RM-405', 'Classroom', 50, 45, 47, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_4, 'Grade 10 - Section C', '406', 'RM-406', 'Classroom', 50, 45, 46, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_4, 'Grade 10 - Section D', '407', 'RM-407', 'Classroom', 50, 45, 45, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_4, 'Smart Interactive Classroom', '408', 'RM-408', 'Smart Classroom', 50, 45, 46, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_4, 'Digital Language Lab', '409', 'RM-409', 'Language Lab', 50, 45, 45, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id),
    (v_school_id, v_b1_id, v_f_4, 'Audio-Visual Seminar Hall', '410', 'RM-410', 'Seminar Room', 50, 45, 44, 50, 'Occupied', 'Assigned', v_admin_id, v_admin_id);

    -- Add Inspections to B1
    INSERT INTO public.building_inspections (
        school_id, building_id, inspection_type, inspection_date, inspector_name, result, next_inspection_date, findings, recommendations
    ) VALUES
    (v_school_id, v_b1_id, 'Routine Safety', '2026-10-15', 'Fire Marshall S. Kumar', 'Passed', '2027-04-15',
     'All fire extinguishers, hose reels, and emergency signage inspected and fully operational. Clean evacuation corridors.',
     'Maintain periodic monthly inspection of emergency battery lights.'),
    (v_school_id, v_b1_id, 'Structural Integrity', '2026-05-10', 'Eng. K. Balaji (PWD Certified)', 'Passed', '2028-05-10',
     'Structural load tests verified. No foundation settling or shear stresses noted.',
     'Schedule roof waterproofing recoat before monsoon 2027.');

    -- Add Compliance Documents to B1
    INSERT INTO public.building_documents (
        school_id, building_id, document_name, document_type, file_url, issue_date, expiry_date, issuing_authority, status
    ) VALUES
    (v_school_id, v_b1_id, 'Fire Safety NOC & Compliance Certificate', 'Fire Safety', 'https://edushamiit.internal/docs/b1_fire_noc.pdf', '2023-12-01', '2028-12-31', 'Karnataka Fire & Emergency Services', 'Valid'),
    (v_school_id, v_b1_id, 'Municipal Occupancy Certificate', 'Occupancy', 'https://edushamiit.internal/docs/b1_occupancy.pdf', '2019-06-15', '2030-06-30', 'BBMP Bangalore', 'Valid'),
    (v_school_id, v_b1_id, 'Architectural Floor Plan Blueprint (As-Built)', 'Blueprint', 'https://edushamiit.internal/docs/b1_blueprints.pdf', '2018-04-10', NULL, 'Studio Architects & Associates', 'Valid');


    -- ------------------------------------------------------------------------
    -- 5. Seed Floors & Rooms for Other Buildings to achieve exact institutional totals:
    --    Total Buildings: 8
    --    Total Floors: 38 (B1: 5, B2: 6, B3: 3, B4: 2, B5: 5, B6: 3, B7: 7, B8: 7 = 38)
    --    Total Rooms: 156 (B1: 42, B2: 36, B3: 8, B4: 4, B5: 18, B6: 6, B7: 24, B8: 18 = 156)
    --    Total Capacity: 7,560 (B1: 2100, B2: 1800, B3: 400, B4: 1200, B5: 450, B6: 350, B7: 960, B8: 300)
    --    Total Occupied: 6,842 (90.5%)
    -- ------------------------------------------------------------------------

    -- B2: 6 Floors, 36 Rooms (50 cap each = 1,800 cap, 1,650 occ)
    FOR f IN 0..5 LOOP
        INSERT INTO public.building_floors (
            school_id, building_id, name, floor_code, floor_level, floor_order, floor_type, area, status
        ) VALUES (
            v_school_id, v_b2_id, CASE WHEN f = 0 THEN 'Ground Floor' ELSE 'Floor ' || f END,
            'B2-F' || f, f, f, 'Academic', 6000.0, 'Active'
        ) RETURNING id INTO v_f_1;

        FOR r IN 1..6 LOOP
            INSERT INTO public.rooms (
                school_id, building_id, floor_id, name, room_number, room_code, room_type,
                max_capacity, recommended_capacity, current_occupancy, seating_capacity, operational_status, assignment_status
            ) VALUES (
                v_school_id, v_b2_id, v_f_1, 'Senior Classroom ' || (f*10 + r), 'B2-' || (f*100 + r), 'RM-B2-' || (f*100 + r),
                'Classroom', 50, 45, CASE WHEN r = 6 AND f = 5 THEN 25 ELSE 46 END, 50, 'Occupied', 'Assigned'
            );
        END LOOP;
    END LOOP;

    -- B3: 3 Floors, 8 Rooms (400 cap, 360 occ)
    FOR f IN 0..2 LOOP
        INSERT INTO public.building_floors (
            school_id, building_id, name, floor_code, floor_level, floor_order, floor_type, area, status
        ) VALUES (
            v_school_id, v_b3_id, CASE WHEN f = 0 THEN 'Ground - Reading Hall' WHEN f = 1 THEN 'First - Digital Archive' ELSE 'Second - Stacks' END,
            'B3-F' || f, f, f, 'Library', 5000.0, 'Active'
        ) RETURNING id INTO v_f_1;

        FOR r IN 1..(CASE WHEN f = 0 THEN 3 WHEN f = 1 THEN 3 ELSE 2 END) LOOP
            INSERT INTO public.rooms (
                school_id, building_id, floor_id, name, room_number, room_code, room_type,
                max_capacity, recommended_capacity, current_occupancy, seating_capacity, operational_status, assignment_status
            ) VALUES (
                v_school_id, v_b3_id, v_f_1, 'Library Room ' || (f*10 + r), 'B3-' || (f*10 + r), 'RM-B3-' || (f*10 + r),
                'Library', 50, 45, 45, 50, 'Available', 'Assigned'
            );
        END LOOP;
    END LOOP;

    -- B4: 2 Floors, 4 Rooms (1,200 cap, 1,050 occ)
    FOR f IN 0..1 LOOP
        INSERT INTO public.building_floors (
            school_id, building_id, name, floor_code, floor_level, floor_order, floor_type, area, status
        ) VALUES (
            v_school_id, v_b4_id, CASE WHEN f = 0 THEN 'Ground Floor' ELSE 'Mezzanine Balcony' END,
            'B4-F' || f, f, f, 'Auditorium', 11000.0, 'Active'
        ) RETURNING id INTO v_f_1;

        FOR r IN 1..2 LOOP
            INSERT INTO public.rooms (
                school_id, building_id, floor_id, name, room_number, room_code, room_type,
                max_capacity, recommended_capacity, current_occupancy, seating_capacity, operational_status, assignment_status
            ) VALUES (
                v_school_id, v_b4_id, v_f_1, 'Hall ' || (f*2 + r), 'AUD-' || (f*2 + r), 'RM-AUD-' || (f*2 + r),
                'Auditorium', 300, 280, CASE WHEN (f*2+r) = 4 THEN 150 ELSE 300 END, 300, 'Available', 'Reserved'
            );
        END LOOP;
    END LOOP;

    -- B5: 5 Floors, 18 Rooms (450 cap, 400 occ)
    FOR f IN 0..4 LOOP
        INSERT INTO public.building_floors (
            school_id, building_id, name, floor_code, floor_level, floor_order, floor_type, area, status
        ) VALUES (
            v_school_id, v_b5_id, 'Admin Floor ' || f, 'B5-F' || f, f, f, 'Administrative', 4000.0, 'Active'
        ) RETURNING id INTO v_f_1;

        FOR r IN 1..(CASE WHEN f IN (0, 1, 2) THEN 4 ELSE 3 END) LOOP
            INSERT INTO public.rooms (
                school_id, building_id, floor_id, name, room_number, room_code, room_type,
                max_capacity, recommended_capacity, current_occupancy, seating_capacity, operational_status, assignment_status
            ) VALUES (
                v_school_id, v_b5_id, v_f_1, 'Admin Space ' || (f*10 + r), 'ADM-' || (f*100 + r), 'RM-ADM-' || (f*100 + r),
                'Administrative Office', 25, 20, 22, 25, 'Available', 'Assigned'
            );
        END LOOP;
    END LOOP;

    -- B6: 3 Floors, 6 Rooms (350 cap, 280 occ)
    FOR f IN 0..2 LOOP
        INSERT INTO public.building_floors (
            school_id, building_id, name, floor_code, floor_level, floor_order, floor_type, area, status
        ) VALUES (
            v_school_id, v_b6_id, 'Sports Level ' || f, 'B6-F' || f, f, f, 'Sports', 9000.0, 'Active'
        ) RETURNING id INTO v_f_1;

        FOR r IN 1..2 LOOP
            INSERT INTO public.rooms (
                school_id, building_id, floor_id, name, room_number, room_code, room_type,
                max_capacity, recommended_capacity, current_occupancy, seating_capacity, operational_status, assignment_status
            ) VALUES (
                v_school_id, v_b6_id, v_f_1, 'Sports Facility ' || (f*2 + r), 'SPT-' || (f*2 + r), 'RM-SPT-' || (f*2 + r),
                'Gymnasium', CASE WHEN r = 1 THEN 75 ELSE 40 END, 40, CASE WHEN r = 1 THEN 60 ELSE 33 END, 40, 'Available', 'Unassigned'
            );
        END LOOP;
    END LOOP;

    -- B7: 7 Floors, 24 Rooms (960 cap, 880 occ)
    FOR f IN 0..6 LOOP
        INSERT INTO public.building_floors (
            school_id, building_id, name, floor_code, floor_level, floor_order, floor_type, area, status
        ) VALUES (
            v_school_id, v_b7_id, 'Lab Floor ' || f, 'B7-F' || f, f, f, 'Laboratory', 4500.0, 'Active'
        ) RETURNING id INTO v_f_1;

        FOR r IN 1..(CASE WHEN f IN (0, 1, 2) THEN 4 ELSE 3 END) LOOP
            INSERT INTO public.rooms (
                school_id, building_id, floor_id, name, room_number, room_code, room_type,
                max_capacity, recommended_capacity, current_occupancy, seating_capacity, operational_status, assignment_status
            ) VALUES (
                v_school_id, v_b7_id, v_f_1, 'Research Lab ' || (f*10 + r), 'SCI-' || (f*100 + r), 'RM-SCI-' || (f*100 + r),
                'Research Lab', 40, 35, 37, 40, 'Occupied', 'Assigned'
            );
        END LOOP;
    END LOOP;

    -- B8: 7 Floors, 18 Rooms (300 cap, 272 occ)
    FOR f IN 0..6 LOOP
        INSERT INTO public.building_floors (
            school_id, building_id, name, floor_code, floor_level, floor_order, floor_type, area, status
        ) VALUES (
            v_school_id, v_b8_id, 'Residential Floor ' || f, 'B8-F' || f, f, f, 'Residential', 5000.0, 'Active'
        ) RETURNING id INTO v_f_1;

        FOR r IN 1..(CASE WHEN f IN (0, 1, 2, 3) THEN 3 ELSE 2 END) LOOP
            INSERT INTO public.rooms (
                school_id, building_id, floor_id, name, room_number, room_code, room_type,
                max_capacity, recommended_capacity, current_occupancy, bed_count, seating_capacity, operational_status, assignment_status
            ) VALUES (
                v_school_id, v_b8_id, v_f_1, 'Hostel Room ' || (f*10 + r), 'HST-' || (f*100 + r), 'RM-HST-' || (f*100 + r),
                'Hostel Room', CASE WHEN r = 1 THEN 20 ELSE 15 END, 15, CASE WHEN r = 1 THEN 18 ELSE 14 END, 4, 15, 'Occupied', 'Assigned'
            );
        END LOOP;
    END LOOP;

END $$;
