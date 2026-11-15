-- ============================================================================
-- Migration: 361_seed_hostel_management_lookups_and_sample_data.sql
-- Description: Tenant-Scoped Lookups & Initial Screenshot-Accurate Sample Data
--              Matches EduSHAMIIT Approved Visual Reference for Boys Hostel A,
--              Floors, Rooms A-101 to A-110, Beds, Facilities & Occupancies
-- ============================================================================

DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_admin_id UUID := '38a93170-997b-4b4c-bc8e-256b93169c23';
    v_bha_id UUID;
    v_bhb_id UUID;
    v_gha_id UUID;
    v_ghb_id UUID;
    v_fl_g_id UUID;
    v_fl_1_id UUID;
    v_fl_2_id UUID;
    v_fl_3_id UUID;
    v_room_id UUID;
    v_bed_1_id UUID;
    v_bed_2_id UUID;
    v_bed_3_id UUID;
    v_student_1 UUID;
    v_student_2 UUID;
    v_student_3 UUID;
    v_i INT;
    v_room_num VARCHAR(50);
BEGIN
    -- Ensure admin profile fallback if 38a93170 doesn't exist
    SELECT id INTO v_admin_id FROM public.profiles WHERE school_id = v_school_id LIMIT 1;
    IF v_admin_id IS NULL THEN
        SELECT id INTO v_admin_id FROM public.profiles LIMIT 1;
    END IF;

    -- Fetch 3 active student IDs for allocations in A-101
    SELECT id INTO v_student_1 FROM public.profiles WHERE school_id = v_school_id AND role = 'student' LIMIT 1;
    SELECT id INTO v_student_2 FROM public.profiles WHERE school_id = v_school_id AND role = 'student' OFFSET 1 LIMIT 1;
    SELECT id INTO v_student_3 FROM public.profiles WHERE school_id = v_school_id AND role = 'student' OFFSET 2 LIMIT 1;

    -- 1. Create or ensure Buildings matching Screenshot
    -- Boys Hostel A
    INSERT INTO public.hostel_buildings (
        school_id, code, name, hostel_name, gender_policy, building_type, total_floors,
        description, operational_status, created_by, updated_by
    ) VALUES (
        v_school_id, 'BHA', 'Boys Hostel A', 'Boys Hostel A', 'BOYS', 'RESIDENTIAL', 4,
        'Main residential block for senior and junior boys with modern amenities and high-speed campus WiFi.',
        'OPERATIONAL', v_admin_id, v_admin_id
    )
    ON CONFLICT (school_id, UPPER(code)) WHERE deleted_at IS NULL
    DO UPDATE SET name = EXCLUDED.name, total_floors = 4
    RETURNING id INTO v_bha_id;

    -- Boys Hostel B
    INSERT INTO public.hostel_buildings (
        school_id, code, name, hostel_name, gender_policy, building_type, total_floors,
        description, operational_status, created_by, updated_by
    ) VALUES (
        v_school_id, 'BHB', 'Boys Hostel B', 'Boys Hostel B', 'BOYS', 'RESIDENTIAL', 4,
        'Secondary boys residential block with attached dining and recreation halls.',
        'OPERATIONAL', v_admin_id, v_admin_id
    )
    ON CONFLICT (school_id, UPPER(code)) WHERE deleted_at IS NULL
    DO UPDATE SET name = EXCLUDED.name, total_floors = 4
    RETURNING id INTO v_bhb_id;

    -- Girls Hostel A
    INSERT INTO public.hostel_buildings (
        school_id, code, name, hostel_name, gender_policy, building_type, total_floors,
        description, operational_status, created_by, updated_by
    ) VALUES (
        v_school_id, 'GHA', 'Girls Hostel A', 'Girls Hostel A', 'GIRLS', 'RESIDENTIAL', 4,
        'Secure residential hall for female students with round-the-clock warden support and biometric access.',
        'OPERATIONAL', v_admin_id, v_admin_id
    )
    ON CONFLICT (school_id, UPPER(code)) WHERE deleted_at IS NULL
    DO UPDATE SET name = EXCLUDED.name, total_floors = 4
    RETURNING id INTO v_gha_id;

    -- Girls Hostel B
    INSERT INTO public.hostel_buildings (
        school_id, code, name, hostel_name, gender_policy, building_type, total_floors,
        description, operational_status, created_by, updated_by
    ) VALUES (
        v_school_id, 'GHB', 'Girls Hostel B', 'Girls Hostel B', 'GIRLS', 'RESIDENTIAL', 4,
        'Girls hostel block B with modern study rooms and fitness lounge.',
        'OPERATIONAL', v_admin_id, v_admin_id
    )
    ON CONFLICT (school_id, UPPER(code)) WHERE deleted_at IS NULL
    DO UPDATE SET name = EXCLUDED.name, total_floors = 4
    RETURNING id INTO v_ghb_id;

    -- 2. Create Floors for Boys Hostel A (Ground, 1st, 2nd, 3rd)
    INSERT INTO public.hostel_floors (
        school_id, building_id, floor_number, floor_code, floor_name, wing, operational_status, created_by, updated_by
    ) VALUES (
        v_school_id, v_bha_id, 0, 'G', 'Ground Floor', 'Main Wing', 'OPERATIONAL', v_admin_id, v_admin_id
    )
    ON CONFLICT (building_id, floor_number) WHERE deleted_at IS NULL
    DO UPDATE SET floor_name = EXCLUDED.floor_name
    RETURNING id INTO v_fl_g_id;

    INSERT INTO public.hostel_floors (
        school_id, building_id, floor_number, floor_code, floor_name, wing, operational_status, created_by, updated_by
    ) VALUES (
        v_school_id, v_bha_id, 1, '1', '1st Floor', 'Main Wing', 'OPERATIONAL', v_admin_id, v_admin_id
    )
    ON CONFLICT (building_id, floor_number) WHERE deleted_at IS NULL
    DO UPDATE SET floor_name = EXCLUDED.floor_name
    RETURNING id INTO v_fl_1_id;

    INSERT INTO public.hostel_floors (
        school_id, building_id, floor_number, floor_code, floor_name, wing, operational_status, created_by, updated_by
    ) VALUES (
        v_school_id, v_bha_id, 2, '2', '2nd Floor', 'Main Wing', 'OPERATIONAL', v_admin_id, v_admin_id
    )
    ON CONFLICT (building_id, floor_number) WHERE deleted_at IS NULL
    DO UPDATE SET floor_name = EXCLUDED.floor_name
    RETURNING id INTO v_fl_2_id;

    INSERT INTO public.hostel_floors (
        school_id, building_id, floor_number, floor_code, floor_name, wing, operational_status, created_by, updated_by
    ) VALUES (
        v_school_id, v_bha_id, 3, '3', '3rd Floor', 'Main Wing', 'OPERATIONAL', v_admin_id, v_admin_id
    )
    ON CONFLICT (building_id, floor_number) WHERE deleted_at IS NULL
    DO UPDATE SET floor_name = EXCLUDED.floor_name
    RETURNING id INTO v_fl_3_id;

    -- Also ensure floors for BHB, GHA, GHB so tree has floors
    FOR v_i IN 0..3 LOOP
        INSERT INTO public.hostel_floors (school_id, building_id, floor_number, floor_code, floor_name, created_by)
        VALUES (v_school_id, v_bhb_id, v_i, v_i::TEXT, CASE WHEN v_i=0 THEN 'Ground Floor' ELSE v_i::TEXT || 'th Floor' END, v_admin_id)
        ON CONFLICT DO NOTHING;

        INSERT INTO public.hostel_floors (school_id, building_id, floor_number, floor_code, floor_name, created_by)
        VALUES (v_school_id, v_gha_id, v_i, v_i::TEXT, CASE WHEN v_i=0 THEN 'Ground Floor' ELSE v_i::TEXT || 'th Floor' END, v_admin_id)
        ON CONFLICT DO NOTHING;

        INSERT INTO public.hostel_floors (school_id, building_id, floor_number, floor_code, floor_name, created_by)
        VALUES (v_school_id, v_ghb_id, v_i, v_i::TEXT, CASE WHEN v_i=0 THEN 'Ground Floor' ELSE v_i::TEXT || 'th Floor' END, v_admin_id)
        ON CONFLICT DO NOTHING;
    END LOOP;

    -- 3. Create Rooms A-101 to A-110 on 1st Floor Boys Hostel A (Matches Screenshot Exactly)
    -- Room A-101 (Standard, Cap: 3, Occ: 3, Occupied)
    INSERT INTO public.hostel_rooms (
        school_id, building_id, floor_id, room_number, room_code, room_name, room_type, is_residential,
        target_capacity, current_occupancy, room_size_sqm, monthly_fee, gender_restriction, operational_status,
        photos, amenities, created_by, updated_by
    ) VALUES (
        v_school_id, v_bha_id, v_fl_1_id, 'A-101', 'BHA-1-101', 'Room A-101', 'Standard', TRUE,
        3, 3, 18.0, 6000.0, 'BOYS', 'OCCUPIED',
        '["https://images.unsplash.com/photo-1555854877-bab0e564b8d5?auto=format&fit=crop&w=800&q=80", "https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=800&q=80", "https://images.unsplash.com/photo-1595526114035-0d45ed16cfbf?auto=format&fit=crop&w=800&q=80"]'::JSONB,
        '["Attached Washroom", "WiFi", "Geyser", "Housekeeping"]'::JSONB,
        v_admin_id, v_admin_id
    )
    ON CONFLICT (building_id, floor_id, UPPER(room_number)) WHERE deleted_at IS NULL
    DO UPDATE SET current_occupancy = 3, target_capacity = 3, operational_status = 'OCCUPIED'
    RETURNING id INTO v_room_id;

    -- Beds for A-101
    INSERT INTO public.hostel_beds (school_id, building_id, floor_id, room_id, bed_code, bed_type, condition, status, monthly_fee)
    VALUES (v_school_id, v_bha_id, v_fl_1_id, v_room_id, 'Bed 1', 'Single', 'GOOD', 'OCCUPIED', 6000.0)
    ON CONFLICT (room_id, UPPER(bed_code)) WHERE deleted_at IS NULL DO UPDATE SET status = 'OCCUPIED'
    RETURNING id INTO v_bed_1_id;

    INSERT INTO public.hostel_beds (school_id, building_id, floor_id, room_id, bed_code, bed_type, condition, status, monthly_fee)
    VALUES (v_school_id, v_bha_id, v_fl_1_id, v_room_id, 'Bed 2', 'Single', 'GOOD', 'OCCUPIED', 6000.0)
    ON CONFLICT (room_id, UPPER(bed_code)) WHERE deleted_at IS NULL DO UPDATE SET status = 'OCCUPIED'
    RETURNING id INTO v_bed_2_id;

    INSERT INTO public.hostel_beds (school_id, building_id, floor_id, room_id, bed_code, bed_type, condition, status, monthly_fee)
    VALUES (v_school_id, v_bha_id, v_fl_1_id, v_room_id, 'Bed 3', 'Single', 'GOOD', 'OCCUPIED', 6000.0)
    ON CONFLICT (room_id, UPPER(bed_code)) WHERE deleted_at IS NULL DO UPDATE SET status = 'OCCUPIED'
    RETURNING id INTO v_bed_3_id;

    -- Equipment for A-101 (Matches Inspector: Beds (3) Good, Fans (3) Good, AC Not Available, WiFi Good, Study Table (3) Good, Wardrobe (3) Good, Attached Washroom Yes, Geyser Good, TV Not Available, Power Outlets Good, Lighting Good, Balcony Not Available, Housekeeping Good)
    INSERT INTO public.hostel_room_equipment (school_id, building_id, floor_id, room_id, equipment_name, equipment_category, quantity, status)
    VALUES 
        (v_school_id, v_bha_id, v_fl_1_id, v_room_id, 'Beds', 'FURNITURE', 3, 'GOOD'),
        (v_school_id, v_bha_id, v_fl_1_id, v_room_id, 'Fans', 'ELECTRICAL', 3, 'GOOD'),
        (v_school_id, v_bha_id, v_fl_1_id, v_room_id, 'AC', 'ELECTRICAL', 0, 'NOT_AVAILABLE'),
        (v_school_id, v_bha_id, v_fl_1_id, v_room_id, 'WiFi', 'ELECTRONICS', 1, 'GOOD'),
        (v_school_id, v_bha_id, v_fl_1_id, v_room_id, 'Study Table', 'FURNITURE', 3, 'GOOD'),
        (v_school_id, v_bha_id, v_fl_1_id, v_room_id, 'Wardrobe', 'FURNITURE', 3, 'GOOD'),
        (v_school_id, v_bha_id, v_fl_1_id, v_room_id, 'Attached Washroom', 'AMENITY', 1, 'GOOD'),
        (v_school_id, v_bha_id, v_fl_1_id, v_room_id, 'Geyser', 'PLUMBING', 1, 'GOOD'),
        (v_school_id, v_bha_id, v_fl_1_id, v_room_id, 'Television', 'ELECTRONICS', 0, 'NOT_AVAILABLE'),
        (v_school_id, v_bha_id, v_fl_1_id, v_room_id, 'Power Outlets', 'ELECTRICAL', 4, 'GOOD'),
        (v_school_id, v_bha_id, v_fl_1_id, v_room_id, 'Lighting', 'ELECTRICAL', 4, 'GOOD'),
        (v_school_id, v_bha_id, v_fl_1_id, v_room_id, 'Balcony', 'AMENITY', 0, 'NOT_AVAILABLE'),
        (v_school_id, v_bha_id, v_fl_1_id, v_room_id, 'Housekeeping', 'AMENITY', 1, 'GOOD')
    ON CONFLICT DO NOTHING;

    -- Allocations for A-101 if students found
    IF v_student_1 IS NOT NULL THEN
        INSERT INTO public.hostel_allocations (
            school_id, student_id, academic_year, building_id, floor_id, room_id, bed_id,
            allocation_status, check_in_date, monthly_fee, fee_status, created_by
        ) VALUES (
            v_school_id, v_student_1, '2024 - 2025', v_bha_id, v_fl_1_id, v_room_id, v_bed_1_id,
            'CHECKED_IN', NOW() - INTERVAL '30 days', 6000.0, 'PAID', v_admin_id
        ) ON CONFLICT DO NOTHING;
    END IF;

    IF v_student_2 IS NOT NULL THEN
        INSERT INTO public.hostel_allocations (
            school_id, student_id, academic_year, building_id, floor_id, room_id, bed_id,
            allocation_status, check_in_date, monthly_fee, fee_status, created_by
        ) VALUES (
            v_school_id, v_student_2, '2024 - 2025', v_bha_id, v_fl_1_id, v_room_id, v_bed_2_id,
            'CHECKED_IN', NOW() - INTERVAL '25 days', 6000.0, 'PAID', v_admin_id
        ) ON CONFLICT DO NOTHING;
    END IF;

    IF v_student_3 IS NOT NULL THEN
        INSERT INTO public.hostel_allocations (
            school_id, student_id, academic_year, building_id, floor_id, room_id, bed_id,
            allocation_status, check_in_date, monthly_fee, fee_status, created_by
        ) VALUES (
            v_school_id, v_student_3, '2024 - 2025', v_bha_id, v_fl_1_id, v_room_id, v_bed_3_id,
            'CHECKED_IN', NOW() - INTERVAL '20 days', 6000.0, 'PAID', v_admin_id
        ) ON CONFLICT DO NOTHING;
    END IF;

    -- Room A-102 (Standard, Cap: 3, Occ: 2, Available)
    INSERT INTO public.hostel_rooms (
        school_id, building_id, floor_id, room_number, room_code, room_type, is_residential,
        target_capacity, current_occupancy, room_size_sqm, monthly_fee, operational_status, created_by
    ) VALUES (
        v_school_id, v_bha_id, v_fl_1_id, 'A-102', 'BHA-1-102', 'Standard', TRUE,
        3, 2, 18.0, 6000.0, 'AVAILABLE', v_admin_id
    ) ON CONFLICT (building_id, floor_id, UPPER(room_number)) WHERE deleted_at IS NULL DO NOTHING;

    -- Room A-103 (Deluxe, Cap: 2, Occ: 2, Occupied)
    INSERT INTO public.hostel_rooms (
        school_id, building_id, floor_id, room_number, room_code, room_type, is_residential,
        target_capacity, current_occupancy, room_size_sqm, monthly_fee, operational_status, created_by
    ) VALUES (
        v_school_id, v_bha_id, v_fl_1_id, 'A-103', 'BHA-1-103', 'Deluxe', TRUE,
        2, 2, 22.0, 8500.0, 'OCCUPIED', v_admin_id
    ) ON CONFLICT (building_id, floor_id, UPPER(room_number)) WHERE deleted_at IS NULL DO NOTHING;

    -- Room A-104 (Standard, Cap: 3, Occ: 0, Available)
    INSERT INTO public.hostel_rooms (
        school_id, building_id, floor_id, room_number, room_code, room_type, is_residential,
        target_capacity, current_occupancy, room_size_sqm, monthly_fee, operational_status, created_by
    ) VALUES (
        v_school_id, v_bha_id, v_fl_1_id, 'A-104', 'BHA-1-104', 'Standard', TRUE,
        3, 0, 18.0, 6000.0, 'AVAILABLE', v_admin_id
    ) ON CONFLICT (building_id, floor_id, UPPER(room_number)) WHERE deleted_at IS NULL DO NOTHING;

    -- Room A-105 (Standard, Cap: 3, Occ: 3, Occupied)
    INSERT INTO public.hostel_rooms (
        school_id, building_id, floor_id, room_number, room_code, room_type, is_residential,
        target_capacity, current_occupancy, room_size_sqm, monthly_fee, operational_status, created_by
    ) VALUES (
        v_school_id, v_bha_id, v_fl_1_id, 'A-105', 'BHA-1-105', 'Standard', TRUE,
        3, 3, 18.0, 6000.0, 'OCCUPIED', v_admin_id
    ) ON CONFLICT (building_id, floor_id, UPPER(room_number)) WHERE deleted_at IS NULL DO NOTHING;

    -- Room A-106 (Study Room, Cap: 4, Occ: 2, Available)
    INSERT INTO public.hostel_rooms (
        school_id, building_id, floor_id, room_number, room_code, room_type, is_residential,
        target_capacity, current_occupancy, room_size_sqm, monthly_fee, operational_status, created_by
    ) VALUES (
        v_school_id, v_bha_id, v_fl_1_id, 'A-106', 'BHA-1-106', 'Study Room', TRUE,
        4, 2, 28.0, 4500.0, 'AVAILABLE', v_admin_id
    ) ON CONFLICT (building_id, floor_id, UPPER(room_number)) WHERE deleted_at IS NULL DO NOTHING;

    -- Room A-107 (Toilet/Washroom, Non-residential, Operational)
    INSERT INTO public.hostel_rooms (
        school_id, building_id, floor_id, room_number, room_code, room_type, is_residential,
        target_capacity, current_occupancy, room_size_sqm, monthly_fee, operational_status, created_by
    ) VALUES (
        v_school_id, v_bha_id, v_fl_1_id, 'A-107', 'BHA-1-107', 'Toilet/Washroom', FALSE,
        0, 0, 15.0, 0.0, 'OPERATIONAL', v_admin_id
    ) ON CONFLICT (building_id, floor_id, UPPER(room_number)) WHERE deleted_at IS NULL DO NOTHING;

    -- Room A-108 (Toilet/Washroom, Non-residential, Maintenance)
    INSERT INTO public.hostel_rooms (
        school_id, building_id, floor_id, room_number, room_code, room_type, is_residential,
        target_capacity, current_occupancy, room_size_sqm, monthly_fee, operational_status, created_by
    ) VALUES (
        v_school_id, v_bha_id, v_fl_1_id, 'A-108', 'BHA-1-108', 'Toilet/Washroom', FALSE,
        0, 0, 15.0, 0.0, 'MAINTENANCE', v_admin_id
    ) ON CONFLICT (building_id, floor_id, UPPER(room_number)) WHERE deleted_at IS NULL DO NOTHING;

    -- Room A-109 (Standard, Cap: 3, Occ: 1, Available)
    INSERT INTO public.hostel_rooms (
        school_id, building_id, floor_id, room_number, room_code, room_type, is_residential,
        target_capacity, current_occupancy, room_size_sqm, monthly_fee, operational_status, created_by
    ) VALUES (
        v_school_id, v_bha_id, v_fl_1_id, 'A-109', 'BHA-1-109', 'Standard', TRUE,
        3, 1, 18.0, 6000.0, 'AVAILABLE', v_admin_id
    ) ON CONFLICT (building_id, floor_id, UPPER(room_number)) WHERE deleted_at IS NULL DO NOTHING;

    -- Room A-110 (Standard, Cap: 3, Occ: 3, Occupied)
    INSERT INTO public.hostel_rooms (
        school_id, building_id, floor_id, room_number, room_code, room_type, is_residential,
        target_capacity, current_occupancy, room_size_sqm, monthly_fee, operational_status, created_by
    ) VALUES (
        v_school_id, v_bha_id, v_fl_1_id, 'A-110', 'BHA-1-110', 'Standard', TRUE,
        3, 3, 18.0, 6000.0, 'OCCUPIED', v_admin_id
    ) ON CONFLICT (building_id, floor_id, UPPER(room_number)) WHERE deleted_at IS NULL DO NOTHING;

END;
$$;
