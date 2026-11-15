-- ============================================================================
-- Migration 362: Seed Hostel Management Lookup Keys, Values, and Room Facilities
-- ============================================================================

DO $$
DECLARE
    r_school RECORD;
    v_key_id UUID;
BEGIN
    FOR r_school IN SELECT id FROM public.schools LOOP

        -- 1. ROOM_TYPE
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = r_school.id AND key_code = 'ROOM_TYPE';
        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (id, school_id, key_name, key_code, description, key_type, icon, status, version, created_at, updated_at)
            VALUES (gen_random_uuid(), r_school.id, 'Room Type', 'ROOM_TYPE', 'Hostel & Campus Room Classifications', 'SYSTEM', 'meeting_room_outlined', 'ACTIVE', 1, NOW(), NOW())
            RETURNING id INTO v_key_id;
        END IF;

        INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
        VALUES
            (gen_random_uuid(), v_key_id, r_school.id, 'Standard', 'STANDARD', 'Standard residential room with essential amenities', 'ACTIVE', 1, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Deluxe', 'DELUXE', 'Premium residential room with AC and attached washroom', 'ACTIVE', 2, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Super Deluxe', 'SUPER_DELUXE', 'Executive private suite with kitchenette and balcony', 'ACTIVE', 3, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Dormitory', 'DORMITORY', 'High-capacity shared hall with bunk beds', 'ACTIVE', 4, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Single Occupancy', 'SINGLE', 'Private single room for senior students and scholars', 'ACTIVE', 5, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Study Room', 'STUDY_ROOM', 'Quiet reading and collaborative study space', 'ACTIVE', 6, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Toilet/Washroom', 'TOILET_WASHROOM', 'Sanitary, restroom, and shower facility', 'ACTIVE', 7, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Common Room / Lounge', 'COMMON_ROOM', 'Recreation, TV, and indoor games room', 'ACTIVE', 8, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Mess / Dining Hall', 'MESS_DINING', 'Food court and dining facility', 'ACTIVE', 9, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Warden Office', 'WARDEN_OFFICE', 'Hostel superintendent administration office', 'ACTIVE', 10, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Medical / Sick Bay', 'MEDICAL_ROOM', 'First aid, clinic, and sick room', 'ACTIVE', 11, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Laundry Room', 'LAUNDRY', 'Washing machines and laundry facility', 'ACTIVE', 12, NOW(), NOW())
        ON CONFLICT DO NOTHING;

        -- 2. ROOM_FACILITY
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = r_school.id AND key_code = 'ROOM_FACILITY';
        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (id, school_id, key_name, key_code, description, key_type, icon, status, version, created_at, updated_at)
            VALUES (gen_random_uuid(), r_school.id, 'Room Facility & Features', 'ROOM_FACILITY', 'Hostel Room Equipment and Restroom Features', 'SYSTEM', 'inventory_2_outlined', 'ACTIVE', 1, NOW(), NOW())
            RETURNING id INTO v_key_id;
        END IF;

        INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
        VALUES
            (gen_random_uuid(), v_key_id, r_school.id, 'Western Toilet', 'WESTERN_TOILET', 'Ceramic WC with dual flush and health faucet', 'ACTIVE', 1, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Urinal', 'URINAL', 'Wall hung urinal with auto-flush', 'ACTIVE', 2, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Wash Basin', 'WASH_BASIN', 'Ceramic hand wash sink with mirror', 'ACTIVE', 3, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Shower', 'SHOWER', 'Overhead and hand shower unit', 'ACTIVE', 4, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Geyser', 'GEYSER', 'Instant water heater for hot water', 'ACTIVE', 5, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Mirror', 'MIRROR', 'Wall-mounted vanity mirror', 'ACTIVE', 6, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Exhaust Fan', 'EXHAUST_FAN', 'Ventilation exhaust fan', 'ACTIVE', 7, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Water Tap', 'WATER_TAP', 'Brass / chrome quarter-turn water faucet', 'ACTIVE', 8, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Hand Dryer', 'HAND_DRYER', 'Automatic warm air hand dryer', 'ACTIVE', 9, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Liquid Soap Dispenser', 'SOAP_DISPENSER', 'Wall mounted antibacterial soap dispenser', 'ACTIVE', 10, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Towel Rail', 'TOWEL_RAIL', 'Stainless steel bath towel holder', 'ACTIVE', 11, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Beds', 'BEDS', 'Ergonomic metal/wood bed frame with mattress', 'ACTIVE', 12, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Fans', 'FANS', 'High speed ceiling fan', 'ACTIVE', 13, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'AC', 'AC', 'Split air conditioner unit with remote', 'ACTIVE', 14, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'WiFi', 'WIFI', 'High speed gigabit wireless internet access', 'ACTIVE', 15, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Study Table', 'STUDY_TABLE', 'Personal study desk with drawer', 'ACTIVE', 16, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Wardrobe', 'WARDROBE', 'Lockable dual-door clothes closet', 'ACTIVE', 17, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Attached Washroom', 'ATTACHED_WASHROOM', 'Private ensuite bathroom facility', 'ACTIVE', 18, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Power Outlets', 'POWER_OUTLETS', 'Multi-plug electrical power sockets', 'ACTIVE', 19, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Lighting', 'LIGHTING', 'LED ceiling tube lights', 'ACTIVE', 20, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Balcony', 'BALCONY', 'Attached open-air private balcony', 'ACTIVE', 21, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Television', 'TELEVISION', 'Smart LED television display', 'ACTIVE', 22, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Housekeeping', 'HOUSEKEEPING', 'Daily room cleaning and sanitization', 'ACTIVE', 23, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Water Purifier', 'WATER_PURIFIER', 'RO UV drinking water filtration station', 'ACTIVE', 24, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'First Aid Kit', 'FIRST_AID_KIT', 'Emergency first aid supplies box', 'ACTIVE', 25, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Fire Extinguisher', 'FIRE_EXTINGUISHER', 'ABC dry chemical powder fire extinguisher', 'ACTIVE', 26, NOW(), NOW())
        ON CONFLICT DO NOTHING;

        -- 3. HOSTEL_GENDER_POLICY
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = r_school.id AND key_code = 'HOSTEL_GENDER_POLICY';
        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (id, school_id, key_name, key_code, description, key_type, icon, status, version, created_at, updated_at)
            VALUES (gen_random_uuid(), r_school.id, 'Hostel Gender Policy', 'HOSTEL_GENDER_POLICY', 'Gender restriction policy for buildings and rooms', 'SYSTEM', 'wc_outlined', 'ACTIVE', 1, NOW(), NOW())
            RETURNING id INTO v_key_id;
        END IF;

        INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
        VALUES
            (gen_random_uuid(), v_key_id, r_school.id, 'Boys Only', 'BOYS', 'Designated exclusively for male residents', 'ACTIVE', 1, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Girls Only', 'GIRLS', 'Designated exclusively for female residents', 'ACTIVE', 2, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Co-Ed', 'COED', 'Co-educational wing with separated secure floors', 'ACTIVE', 3, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Staff Quarters', 'STAFF', 'Faculty and residential staff quarters', 'ACTIVE', 4, NOW(), NOW())
        ON CONFLICT DO NOTHING;

        -- 4. HOSTEL_BED_TYPE
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = r_school.id AND key_code = 'HOSTEL_BED_TYPE';
        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (id, school_id, key_name, key_code, description, key_type, icon, status, version, created_at, updated_at)
            VALUES (gen_random_uuid(), r_school.id, 'Hostel Bed Type', 'HOSTEL_BED_TYPE', 'Bed configuration classifications', 'SYSTEM', 'hotel_outlined', 'ACTIVE', 1, NOW(), NOW())
            RETURNING id INTO v_key_id;
        END IF;

        INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
        VALUES
            (gen_random_uuid(), v_key_id, r_school.id, 'Single Bed', 'SINGLE', 'Standard 3x6 ft single cot bed', 'ACTIVE', 1, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Bunk Bed (Lower)', 'BUNK_LOWER', 'Lower tier of double decker bunk bed', 'ACTIVE', 2, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Bunk Bed (Upper)', 'BUNK_UPPER', 'Upper tier of double decker bunk bed with guard rails', 'ACTIVE', 3, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Double Bed', 'DOUBLE', 'King/Queen double cot bed for staff or couple suite', 'ACTIVE', 4, NOW(), NOW())
        ON CONFLICT DO NOTHING;

        -- 5. FACILITY_CONDITION
        SELECT id INTO v_key_id FROM public.lookup_keys WHERE school_id = r_school.id AND key_code = 'FACILITY_CONDITION';
        IF v_key_id IS NULL THEN
            INSERT INTO public.lookup_keys (id, school_id, key_name, key_code, description, key_type, icon, status, version, created_at, updated_at)
            VALUES (gen_random_uuid(), r_school.id, 'Facility Condition Status', 'FACILITY_CONDITION', 'Operating condition and service state of room equipment', 'SYSTEM', 'build_outlined', 'ACTIVE', 1, NOW(), NOW())
            RETURNING id INTO v_key_id;
        END IF;

        INSERT INTO public.lookup_values (id, lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_at, updated_at)
        VALUES
            (gen_random_uuid(), v_key_id, r_school.id, 'Good', 'GOOD', 'Fully operational in prime working condition', 'ACTIVE', 1, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Working', 'WORKING', 'Operational with normal wear and tear', 'ACTIVE', 2, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Faulty', 'FAULTY', 'Partially defective requiring technician service', 'ACTIVE', 3, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Under Repair', 'UNDER_REPAIR', 'Currently undergoing maintenance', 'ACTIVE', 4, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Not Available', 'NOT_AVAILABLE', 'Not installed or decommissioned', 'ACTIVE', 5, NOW(), NOW()),
            (gen_random_uuid(), v_key_id, r_school.id, 'Out of Service', 'OUT_OF_SERVICE', 'Permanently disabled awaiting replacement', 'ACTIVE', 6, NOW(), NOW())
        ON CONFLICT DO NOTHING;

    END LOOP;
END $$;
