-- ============================================================================
-- Migration: 368_seed_hostel_leave_and_outing_data.sql
-- Description: Seed Production Lookups and Screenshot-Accurate Sample Data
--              Matches EduSHAMIIT Approved Visual Reference for Leave & Outing:
--              48 Total Requests, 32 Approved, 8 Pending, 4 Rejected, 15 Currently Out, 5 Due Today
-- ============================================================================

DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_admin_id UUID;
    v_warden_id UUID;
    v_key_leave_id UUID;
    v_key_outing_id UUID;
    v_key_trans_id UUID;
    
    -- Student IDs
    v_stu_rahul UUID;
    v_stu_sneha UUID;
    v_stu_karthik UUID;
    v_stu_ananya UUID;
    v_stu_vikram UUID;
    v_stu_pooja UUID;
    v_stu_aman UUID;
    v_stu_riya UUID;
    v_stu_dev UUID;
    v_stu_aditya UUID;
    
    -- Extra students for generating exact 48 requests
    v_students RECORD;
    v_req_id UUID;
    v_pass_id UUID;
    v_i INT := 1;
BEGIN
    -- Fetch Admin & Warden Profiles
    SELECT id INTO v_admin_id FROM public.profiles WHERE school_id = v_school_id AND role IN ('teacher', 'admin', 'super_admin') LIMIT 1;
    IF v_admin_id IS NULL THEN
        SELECT id INTO v_admin_id FROM public.profiles LIMIT 1;
    END IF;
    v_warden_id := v_admin_id;

    -- 1. Ensure Lookup Keys for Leave & Outing
    -- Leave Types Key
    INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, created_by, updated_by)
    VALUES (v_school_id, 'Hostel Leave Types', 'HOSTEL_LEAVE_TYPE', 'Configurable types for hostel leave', 'SYSTEM', v_admin_id, v_admin_id)
    ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL
    DO UPDATE SET key_name = EXCLUDED.key_name
    RETURNING id INTO v_key_leave_id;

    -- Outing Types Key
    INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, created_by, updated_by)
    VALUES (v_school_id, 'Hostel Outing Types', 'HOSTEL_OUTING_TYPE', 'Configurable types for hostel outings', 'SYSTEM', v_admin_id, v_admin_id)
    ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL
    DO UPDATE SET key_name = EXCLUDED.key_name
    RETURNING id INTO v_key_outing_id;

    -- Transport Modes Key
    INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, created_by, updated_by)
    VALUES (v_school_id, 'Hostel Transport Modes', 'HOSTEL_TRANSPORT_MODE', 'Modes of transport for movement', 'SYSTEM', v_admin_id, v_admin_id)
    ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL
    DO UPDATE SET key_name = EXCLUDED.key_name
    RETURNING id INTO v_key_trans_id;

    -- Seed Values for HOSTEL_LEAVE_TYPE
    INSERT INTO public.lookup_values (school_id, lookup_key_id, value_name, value_code, sort_order, created_by, updated_by) VALUES
    (v_school_id, v_key_leave_id, 'Home Leave', 'HOME_LEAVE', 1, v_admin_id, v_admin_id),
    (v_school_id, v_key_leave_id, 'Medical Leave', 'MEDICAL', 2, v_admin_id, v_admin_id),
    (v_school_id, v_key_leave_id, 'Emergency Leave', 'EMERGENCY', 3, v_admin_id, v_admin_id),
    (v_school_id, v_key_leave_id, 'Vacation', 'VACATION', 4, v_admin_id, v_admin_id),
    (v_school_id, v_key_leave_id, 'Family Event', 'FAMILY_EVENT', 5, v_admin_id, v_admin_id),
    (v_school_id, v_key_leave_id, 'Academic Travel', 'ACADEMIC', 6, v_admin_id, v_admin_id),
    (v_school_id, v_key_leave_id, 'Personal Leave', 'PERSONAL', 7, v_admin_id, v_admin_id),
    (v_school_id, v_key_leave_id, 'Other', 'OTHER', 8, v_admin_id, v_admin_id)
    ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;

    -- Seed Values for HOSTEL_OUTING_TYPE
    INSERT INTO public.lookup_values (school_id, lookup_key_id, value_name, value_code, sort_order, created_by, updated_by) VALUES
    (v_school_id, v_key_outing_id, 'Local Market', 'MARKET', 1, v_admin_id, v_admin_id),
    (v_school_id, v_key_outing_id, 'Medical Visit', 'MEDICAL', 2, v_admin_id, v_admin_id),
    (v_school_id, v_key_outing_id, 'Coaching / Tuition', 'COACHING', 3, v_admin_id, v_admin_id),
    (v_school_id, v_key_outing_id, 'Shopping', 'SHOPPING', 4, v_admin_id, v_admin_id),
    (v_school_id, v_key_outing_id, 'Bank / Official Work', 'BANK', 5, v_admin_id, v_admin_id),
    (v_school_id, v_key_outing_id, 'Meeting Guardian', 'GUARDIAN_MEET', 6, v_admin_id, v_admin_id),
    (v_school_id, v_key_outing_id, 'Religious Visit', 'RELIGIOUS', 7, v_admin_id, v_admin_id),
    (v_school_id, v_key_outing_id, 'Personal', 'PERSONAL', 8, v_admin_id, v_admin_id),
    (v_school_id, v_key_outing_id, 'Weekend Outing', 'WEEKEND', 9, v_admin_id, v_admin_id)
    ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;

    -- Seed Values for HOSTEL_TRANSPORT_MODE
    INSERT INTO public.lookup_values (school_id, lookup_key_id, value_name, value_code, sort_order, created_by, updated_by) VALUES
    (v_school_id, v_key_trans_id, 'Walk', 'WALK', 1, v_admin_id, v_admin_id),
    (v_school_id, v_key_trans_id, 'Auto Rickshaw', 'AUTO', 2, v_admin_id, v_admin_id),
    (v_school_id, v_key_trans_id, 'Cab / Taxi', 'CAB', 3, v_admin_id, v_admin_id),
    (v_school_id, v_key_trans_id, 'Bus', 'BUS', 4, v_admin_id, v_admin_id),
    (v_school_id, v_key_trans_id, 'Train', 'TRAIN', 5, v_admin_id, v_admin_id),
    (v_school_id, v_key_trans_id, 'Personal Vehicle', 'PERSONAL_VEHICLE', 6, v_admin_id, v_admin_id),
    (v_school_id, v_key_trans_id, 'Institution Vehicle', 'INSTITUTION_VEHICLE', 7, v_admin_id, v_admin_id)
    ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;

    -- 2. Seed Default Institutional Rules & Settings
    INSERT INTO public.hostel_leave_outing_settings (
        school_id, leave_allowed, outing_allowed, curfew_time, outing_start_time,
        max_outings_per_month, max_leave_days_per_term, guardian_approval_required,
        auto_gatepass_on_approval, late_return_grace_period_mins, updated_by
    ) VALUES (
        v_school_id, true, true, '20:00:00'::TIME, '06:00:00'::TIME,
        4, 15, false, true, 15, v_admin_id
    )
    ON CONFLICT (school_id) DO NOTHING;

    -- 3. Resolve Screenshot Students
    SELECT id INTO v_stu_rahul FROM public.profiles WHERE full_name ILIKE '%Rahul Sharma%' LIMIT 1;
    SELECT id INTO v_stu_sneha FROM public.profiles WHERE full_name ILIKE '%Sneha Iyer%' LIMIT 1;
    SELECT id INTO v_stu_karthik FROM public.profiles WHERE full_name ILIKE '%Karthik Reddy%' LIMIT 1;
    SELECT id INTO v_stu_ananya FROM public.profiles WHERE full_name ILIKE '%Ananya Patel%' LIMIT 1;
    SELECT id INTO v_stu_vikram FROM public.profiles WHERE full_name ILIKE '%Vikram Singh%' LIMIT 1;
    SELECT id INTO v_stu_pooja FROM public.profiles WHERE full_name ILIKE '%Pooja Mehta%' LIMIT 1;
    SELECT id INTO v_stu_aman FROM public.profiles WHERE full_name ILIKE '%Aman Khan%' LIMIT 1;
    SELECT id INTO v_stu_riya FROM public.profiles WHERE full_name ILIKE '%Riya Nair%' LIMIT 1;
    SELECT id INTO v_stu_dev FROM public.profiles WHERE full_name ILIKE '%Dev Kumar%' LIMIT 1;
    SELECT id INTO v_stu_aditya FROM public.profiles WHERE full_name ILIKE '%Aditya Gupta%' LIMIT 1;

    -- Clear existing requests for idempotency
    DELETE FROM public.hostel_movement_logs WHERE school_id = v_school_id;
    DELETE FROM public.hostel_gate_passes WHERE school_id = v_school_id;
    DELETE FROM public.hostel_leave_outing_approvals WHERE school_id = v_school_id;
    DELETE FROM public.hostel_leave_outing_requests WHERE school_id = v_school_id;

    -- =========================================================================
    -- Top 10 Primary Table Rows (Exact Screenshot Match)
    -- =========================================================================

    -- Row 1: Rahul Sharma | Class 10 A | 0101 | Boys Hostel A | A-101 | Leave | 10 May 2024 to 12 May 2024 | 3 days | Approved | Requested 08 May 2024
    IF v_stu_rahul IS NOT NULL THEN
        INSERT INTO public.hostel_leave_outing_requests (
            school_id, student_id, request_number, academic_year, request_type, request_subtype,
            reason, destination, start_at, expected_return_at, status, is_emergency,
            building_name, room_number, bed_code, guardian_name, guardian_phone,
            approved_by_name, approved_at, approval_remarks, created_at, created_by
        ) VALUES (
            v_school_id, v_stu_rahul, 'LOR-2024-0001', '2024 - 2025', 'LEAVE', 'Home Leave',
            'Family wedding ceremony in hometown', 'Jaipur, Rajasthan',
            '2024-05-10 09:00:00+05:30', '2024-05-12 18:00:00+05:30', 'APPROVED', false,
            'Boys Hostel A', 'A-101', 'Bed 1', 'Rajesh Sharma', '+91 98765 43210',
            'Warden', '2024-05-08 11:30:00+05:30', 'Approved. Return by 6 PM on Sunday.',
            '2024-05-08 09:15:00+05:30', v_stu_rahul
        ) RETURNING id INTO v_req_id;

        INSERT INTO public.hostel_gate_passes (
            school_id, request_id, student_id, pass_number, verification_token, qr_reference,
            status, valid_from, valid_until, generated_by_name, generated_at
        ) VALUES (
            v_school_id, v_req_id, v_stu_rahul, 'GP-2024-00001', 'EDUGP-RAHUL001', 'https://edushamiit.edu/gatepass/EDUGP-RAHUL001',
            'ACTIVE', '2024-05-10 08:00:00+05:30', '2024-05-12 20:00:00+05:30', 'Warden', '2024-05-08 11:31:00+05:30'
        );
    END IF;

    -- Row 2: Sneha Iyer | Class 9 A | 0201 | Girls Hostel A | G-101 | Outing | 11 May 2024 | 1 day | Pending | Requested 09 May 2024
    IF v_stu_sneha IS NOT NULL THEN
        INSERT INTO public.hostel_leave_outing_requests (
            school_id, student_id, request_number, academic_year, request_type, request_subtype,
            reason, destination, start_at, expected_return_at, status, is_emergency,
            building_name, room_number, bed_code, guardian_name, guardian_phone,
            created_at, created_by
        ) VALUES (
            v_school_id, v_stu_sneha, 'LOR-2024-0002', '2024 - 2025', 'OUTING', 'Market',
            'Stationery & project material purchase', 'City Center Mall',
            '2024-05-11 14:00:00+05:30', '2024-05-11 18:30:00+05:30', 'PENDING', false,
            'Girls Hostel A', 'G-101', 'Bed 1', 'Ramesh Iyer', '+91 98840 98765',
            '2024-05-09 10:20:00+05:30', v_stu_sneha
        );
    END IF;

    -- Row 3: Karthik Reddy | Class 10 B | 0102 | Boys Hostel A | A-102 | Leave | 05 May 2024 to 07 May 2024 | 3 days | Approved | Requested 03 May 2024
    IF v_stu_karthik IS NOT NULL THEN
        INSERT INTO public.hostel_leave_outing_requests (
            school_id, student_id, request_number, academic_year, request_type, request_subtype,
            reason, destination, start_at, expected_return_at, actual_exit_at, actual_return_at,
            status, is_emergency, building_name, room_number, bed_code, guardian_name, guardian_phone,
            approved_by_name, approved_at, approval_remarks, created_at, created_by
        ) VALUES (
            v_school_id, v_stu_karthik, 'LOR-2024-0003', '2024 - 2025', 'LEAVE', 'Medical Leave',
            'Orthopedic consultation & therapy', 'Hyderabad Care Hospital',
            '2024-05-05 08:00:00+05:30', '2024-05-07 19:00:00+05:30', '2024-05-05 08:15:00+05:30', '2024-05-07 18:40:00+05:30',
            'RETURNED', false, 'Boys Hostel A', 'A-102', 'Bed 2', 'Suresh Reddy', '+91 98450 11223',
            'Warden', '2024-05-03 14:00:00+05:30', 'Medical certificate approved.', '2024-05-03 11:00:00+05:30', v_stu_karthik
        ) RETURNING id INTO v_req_id;

        INSERT INTO public.hostel_gate_passes (
            school_id, request_id, student_id, pass_number, verification_token, qr_reference,
            status, valid_from, valid_until, generated_by_name, generated_at, used_exit_at, used_return_at
        ) VALUES (
            v_school_id, v_req_id, v_stu_karthik, 'GP-2024-00003', 'EDUGP-KARTHIK003', 'https://edushamiit.edu/gatepass/EDUGP-KARTHIK003',
            'USED', '2024-05-05 07:30:00+05:30', '2024-05-07 21:00:00+05:30', 'Warden', '2024-05-03 14:05:00+05:30',
            '2024-05-05 08:15:00+05:30', '2024-05-07 18:40:00+05:30'
        );
    END IF;

    -- Row 4: Ananya Patel | Class 11 A | 0202 | Girls Hostel B | G-203 | Outing | 12 May 2024 | 1 day | Pending | Requested 10 May 2024
    IF v_stu_ananya IS NOT NULL THEN
        INSERT INTO public.hostel_leave_outing_requests (
            school_id, student_id, request_number, academic_year, request_type, request_subtype,
            reason, destination, start_at, expected_return_at, status, is_emergency,
            building_name, room_number, bed_code, guardian_name, guardian_phone,
            created_at, created_by
        ) VALUES (
            v_school_id, v_stu_ananya, 'LOR-2024-0004', '2024 - 2025', 'OUTING', 'Meeting Guardian',
            'Meeting parents at local hotel', 'The Grand Palace Hotel',
            '2024-05-12 11:00:00+05:30', '2024-05-12 17:00:00+05:30', 'PENDING', false,
            'Girls Hostel B', 'G-203', 'Bed 1', 'Bhavin Patel', '+91 98250 55443',
            '2024-05-10 16:45:00+05:30', v_stu_ananya
        );
    END IF;

    -- Row 5: Vikram Singh | Class 11 A | 0103 | Boys Hostel B | B-205 | Leave | 28 Apr 2024 to 30 Apr 2024 | 3 days | Rejected | Requested 26 Apr 2024
    IF v_stu_vikram IS NOT NULL THEN
        INSERT INTO public.hostel_leave_outing_requests (
            school_id, student_id, request_number, academic_year, request_type, request_subtype,
            reason, destination, start_at, expected_return_at, status, is_emergency,
            building_name, room_number, bed_code, guardian_name, guardian_phone,
            approved_by_name, rejection_reason, created_at, created_by
        ) VALUES (
            v_school_id, v_stu_vikram, 'LOR-2024-0005', '2024 - 2025', 'LEAVE', 'Personal',
            'Friend birthday celebration', 'Resort, Outskirts',
            '2024-04-28 10:00:00+05:30', '2024-04-30 18:00:00+05:30', 'REJECTED', false,
            'Boys Hostel B', 'B-205', 'Bed 1', 'Manoj Singh', '+91 91234 56789',
            'Warden', 'Unexcused absence during pre-board test schedule.',
            '2024-04-26 14:15:00+05:30', v_stu_vikram
        );
    END IF;

    -- Row 6: Pooja Mehta | Class 12 A | 0203 | Girls Hostel B | G-203 | Outing | 15 May 2024 to 16 May 2024 | 2 days | Approved | Requested 12 May 2024
    IF v_stu_pooja IS NOT NULL THEN
        INSERT INTO public.hostel_leave_outing_requests (
            school_id, student_id, request_number, academic_year, request_type, request_subtype,
            reason, destination, start_at, expected_return_at, status, is_emergency,
            building_name, room_number, bed_code, guardian_name, guardian_phone,
            approved_by_name, approved_at, approval_remarks, created_at, created_by
        ) VALUES (
            v_school_id, v_stu_pooja, 'LOR-2024-0006', '2024 - 2025', 'OUTING', 'Coaching',
            'JEE Advanced mock test series', 'Allen Career Institute',
            '2024-05-15 08:30:00+05:30', '2024-05-16 18:00:00+05:30', 'APPROVED', false,
            'Girls Hostel B', 'G-203', 'Bed 2', 'Nitin Mehta', '+91 98200 12345',
            'Warden', '2024-05-13 09:30:00+05:30', 'Coaching permit verified.',
            '2024-05-12 11:20:00+05:30', v_stu_pooja
        ) RETURNING id INTO v_req_id;

        INSERT INTO public.hostel_gate_passes (
            school_id, request_id, student_id, pass_number, verification_token, qr_reference,
            status, valid_from, valid_until, generated_by_name, generated_at
        ) VALUES (
            v_school_id, v_req_id, v_stu_pooja, 'GP-2024-00006', 'EDUGP-POOJA006', 'https://edushamiit.edu/gatepass/EDUGP-POOJA006',
            'ACTIVE', '2024-05-15 08:00:00+05:30', '2024-05-16 19:30:00+05:30', 'Warden', '2024-05-13 09:31:00+05:30'
        );
    END IF;

    -- Row 7: Aman Khan | Class 10 C | 0104 | Boys Hostel B | B-206 | Leave | 18 May 2024 to 22 May 2024 | 5 days | Pending | Requested 14 May 2024
    IF v_stu_aman IS NOT NULL THEN
        INSERT INTO public.hostel_leave_outing_requests (
            school_id, student_id, request_number, academic_year, request_type, request_subtype,
            reason, destination, start_at, expected_return_at, status, is_emergency,
            building_name, room_number, bed_code, guardian_name, guardian_phone,
            created_at, created_by
        ) VALUES (
            v_school_id, v_stu_aman, 'LOR-2024-0007', '2024 - 2025', 'LEAVE', 'Home Leave',
            'Sibling engagement function in Lucknow', 'Lucknow, Uttar Pradesh',
            '2024-05-18 07:00:00+05:30', '2024-05-22 20:00:00+05:30', 'PENDING', false,
            'Boys Hostel B', 'B-206', 'Bed 1', 'Irfan Khan', '+91 97112 34455',
            '2024-05-14 15:10:00+05:30', v_stu_aman
        );
    END IF;

    -- Row 8: Riya Nair | Class 12 B | 0204 | Girls Hostel B | G-305 | Outing | 20 Apr 2024 | 1 day | Approved | Requested 18 Apr 2024
    IF v_stu_riya IS NOT NULL THEN
        INSERT INTO public.hostel_leave_outing_requests (
            school_id, student_id, request_number, academic_year, request_type, request_subtype,
            reason, destination, start_at, expected_return_at, actual_exit_at, actual_return_at,
            status, is_emergency, building_name, room_number, bed_code, guardian_name, guardian_phone,
            approved_by_name, approved_at, approval_remarks, created_at, created_by
        ) VALUES (
            v_school_id, v_stu_riya, 'LOR-2024-0008', '2024 - 2025', 'OUTING', 'Bank',
            'Bank account biometric KYC verification', 'State Bank of India Main Branch',
            '2024-04-20 10:00:00+05:30', '2024-04-20 14:00:00+05:30', '2024-04-20 10:05:00+05:30', '2024-04-20 13:45:00+05:30',
            'RETURNED', false, 'Girls Hostel B', 'G-305', 'Bed 1', 'Vijay Nair', '+91 98470 66778',
            'Warden', '2024-04-19 12:00:00+05:30', 'Approved.', '2024-04-18 16:30:00+05:30', v_stu_riya
        ) RETURNING id INTO v_req_id;

        INSERT INTO public.hostel_gate_passes (
            school_id, request_id, student_id, pass_number, verification_token, qr_reference,
            status, valid_from, valid_until, generated_by_name, generated_at, used_exit_at, used_return_at
        ) VALUES (
            v_school_id, v_req_id, v_stu_riya, 'GP-2024-00008', 'EDUGP-RIYA008', 'https://edushamiit.edu/gatepass/EDUGP-RIYA008',
            'USED', '2024-04-20 09:30:00+05:30', '2024-04-20 15:00:00+05:30', 'Warden', '2024-04-19 12:05:00+05:30',
            '2024-04-20 10:05:00+05:30', '2024-04-20 13:45:00+05:30'
        );
    END IF;

    -- Row 9: Dev Kumar | Class 9 C | 0105 | Boys Hostel A | A-105 | Leave | 02 May 2024 to 04 May 2024 | 3 days | Approved | Requested 29 Apr 2024
    IF v_stu_dev IS NOT NULL THEN
        INSERT INTO public.hostel_leave_outing_requests (
            school_id, student_id, request_number, academic_year, request_type, request_subtype,
            reason, destination, start_at, expected_return_at, actual_exit_at, actual_return_at,
            status, is_emergency, building_name, room_number, bed_code, guardian_name, guardian_phone,
            approved_by_name, approved_at, approval_remarks, created_at, created_by
        ) VALUES (
            v_school_id, v_stu_dev, 'LOR-2024-0009', '2024 - 2025', 'LEAVE', 'Academic Travel',
            'State Science Olympiad finals', 'National Science Centre, Delhi',
            '2024-05-02 06:30:00+05:30', '2024-05-04 21:00:00+05:30', '2024-05-02 06:40:00+05:30', '2024-05-04 20:30:00+05:30',
            'RETURNED', false, 'Boys Hostel A', 'A-105', 'Bed 1', 'Anil Kumar', '+91 98111 22334',
            'Warden', '2024-04-30 11:00:00+05:30', 'Approved for competition travel.', '2024-04-29 09:40:00+05:30', v_stu_dev
        ) RETURNING id INTO v_req_id;

        INSERT INTO public.hostel_gate_passes (
            school_id, request_id, student_id, pass_number, verification_token, qr_reference,
            status, valid_from, valid_until, generated_by_name, generated_at, used_exit_at, used_return_at
        ) VALUES (
            v_school_id, v_req_id, v_stu_dev, 'GP-2024-00009', 'EDUGP-DEV009', 'https://edushamiit.edu/gatepass/EDUGP-DEV009',
            'USED', '2024-05-02 06:00:00+05:30', '2024-05-04 22:00:00+05:30', 'Warden', '2024-04-30 11:05:00+05:30',
            '2024-05-02 06:40:00+05:30', '2024-05-04 20:30:00+05:30'
        );
    END IF;

    -- Row 10: Aditya Gupta | Class 12 A | 0106 | Boys Hostel A | A-106 | Outing | 25 May 2024 | 1 day | Pending | Requested 22 May 2024
    IF v_stu_aditya IS NOT NULL THEN
        INSERT INTO public.hostel_leave_outing_requests (
            school_id, student_id, request_number, academic_year, request_type, request_subtype,
            reason, destination, start_at, expected_return_at, status, is_emergency,
            building_name, room_number, bed_code, guardian_name, guardian_phone,
            created_at, created_by
        ) VALUES (
            v_school_id, v_stu_aditya, 'LOR-2024-0010', '2024 - 2025', 'OUTING', 'Personal',
            'Passport office appointment', 'Regional Passport Kendra',
            '2024-05-25 09:30:00+05:30', '2024-05-25 15:00:00+05:30', 'PENDING', false,
            'Boys Hostel A', 'A-106', 'Bed 1', 'Ravi Gupta', '+91 99887 76655',
            '2024-05-22 14:00:00+05:30', v_stu_aditya
        );
    END IF;

    -- =========================================================================
    -- Additional Rows to Match KPIs: Total: 48, Approved: 32, Pending: 8,
    -- Rejected: 4, Canceled: 4, Currently Out: 15, Due Today: 5, Overdue: 2
    -- =========================================================================

    -- Seed 15 EXITED students (Currently Out)
    FOR v_students IN (
        SELECT p.id, p.full_name, p.class, p.roll_number, b.name as building_name, r.room_number, bd.bed_code, p.father_name, p.father_phone
        FROM public.profiles p
        JOIN public.hostel_admissions ha ON ha.student_id = p.id AND ha.school_id = v_school_id
        LEFT JOIN public.hostel_allocations al ON al.student_id = p.id AND al.deleted_at IS NULL
        LEFT JOIN public.hostel_buildings b ON b.id = al.building_id
        LEFT JOIN public.hostel_rooms r ON r.id = al.room_id
        LEFT JOIN public.hostel_beds bd ON bd.id = al.bed_id
        WHERE p.school_id = v_school_id AND p.role = 'student'
          AND p.id NOT IN (v_stu_rahul, v_stu_sneha, v_stu_karthik, v_stu_ananya, v_stu_vikram, v_stu_pooja, v_stu_aman, v_stu_riya, v_stu_dev, v_stu_aditya)
        LIMIT 15
    ) LOOP
        v_i := v_i + 1;
        INSERT INTO public.hostel_leave_outing_requests (
            school_id, student_id, request_number, academic_year, request_type, request_subtype,
            reason, destination, start_at, expected_return_at, actual_exit_at, status, is_emergency,
            building_name, room_number, bed_code, guardian_name, guardian_phone,
            approved_by_name, approved_at, approval_remarks, exit_gate, exit_verified_by_name,
            created_at, created_by
        ) VALUES (
            v_school_id, v_students.id, 'LOR-2024-' || LPAD((10 + v_i)::TEXT, 4, '0'), '2024 - 2025',
            CASE WHEN v_i % 2 = 0 THEN 'OUTING' ELSE 'LEAVE' END,
            CASE WHEN v_i % 3 = 0 THEN 'Medical Visit' WHEN v_i % 2 = 0 THEN 'Market' ELSE 'Home Leave' END,
            'Authorized ' || CASE WHEN v_i % 2 = 0 THEN 'outing' ELSE 'leave' END || ' for academic and personal requirements',
            'City Market / Home',
            NOW() - (v_i * INTERVAL '2 hours'),
            -- 5 requests Due Today, 2 Overdue, others later
            CASE 
                WHEN v_i <= 2 THEN NOW() - INTERVAL '1 hour' -- 2 Overdue!
                WHEN v_i <= 7 THEN ((CURRENT_DATE::TEXT || ' 19:30:00+05:30')::TIMESTAMPTZ) -- 5 Due Today!
                ELSE NOW() + (v_i * INTERVAL '6 hours')
            END,
            NOW() - (v_i * INTERVAL '2 hours'),
            'EXITED', (v_i % 5 = 0),
            COALESCE(v_students.building_name, 'Boys Hostel A'),
            COALESCE(v_students.room_number, 'A-10' || (v_i % 9 + 1)),
            COALESCE(v_students.bed_code, 'Bed 1'),
            COALESCE(v_students.father_name, 'Parent'),
            COALESCE(v_students.father_phone, '+91 98000 0000' || v_i),
            'Warden', NOW() - INTERVAL '1 day', 'Approved and Gate pass issued.',
            'Main Gate', 'Gate Security',
            NOW() - INTERVAL '2 days', v_admin_id
        ) RETURNING id INTO v_req_id;

        INSERT INTO public.hostel_gate_passes (
            school_id, request_id, student_id, pass_number, verification_token, qr_reference,
            status, valid_from, valid_until, generated_by_name, generated_at, used_exit_at
        ) VALUES (
            v_school_id, v_req_id, v_students.id, 'GP-2024-' || LPAD((10 + v_i)::TEXT, 5, '0'),
            'EDUGP-TOKEN-' || v_i, 'https://edushamiit.edu/gatepass/EDUGP-TOKEN-' || v_i,
            'ACTIVE', NOW() - INTERVAL '1 day', NOW() + INTERVAL '2 days', 'Warden', NOW() - INTERVAL '1 day',
            NOW() - (v_i * INTERVAL '2 hours')
        ) RETURNING id INTO v_pass_id;

        INSERT INTO public.hostel_movement_logs (
            school_id, request_id, student_id, gate_pass_id, movement_type, movement_time, gate, verified_by_name
        ) VALUES (
            v_school_id, v_req_id, v_students.id, v_pass_id, 'EXIT', NOW() - (v_i * INTERVAL '2 hours'), 'Main Gate', 'Gate Security'
        );
    END LOOP;

    -- Seed Remaining Approved Requests to reach 32 approved total (Already have row 1, 6 + 15 currently out = 17 approved/exited + 3 returned = 20 approved; need 12 more)
    FOR v_students IN (
        SELECT p.id, p.full_name, p.class, p.roll_number, b.name as building_name, r.room_number, bd.bed_code, p.father_name, p.father_phone
        FROM public.profiles p
        JOIN public.hostel_admissions ha ON ha.student_id = p.id AND ha.school_id = v_school_id
        LEFT JOIN public.hostel_allocations al ON al.student_id = p.id AND al.deleted_at IS NULL
        LEFT JOIN public.hostel_buildings b ON b.id = al.building_id
        LEFT JOIN public.hostel_rooms r ON r.id = al.room_id
        LEFT JOIN public.hostel_beds bd ON bd.id = al.bed_id
        WHERE p.school_id = v_school_id AND p.role = 'student'
        LIMIT 12 OFFSET 15
    ) LOOP
        v_i := v_i + 1;
        INSERT INTO public.hostel_leave_outing_requests (
            school_id, student_id, request_number, academic_year, request_type, request_subtype,
            reason, destination, start_at, expected_return_at, status, is_emergency,
            building_name, room_number, bed_code, guardian_name, guardian_phone,
            approved_by_name, approved_at, approval_remarks, created_at, created_by
        ) VALUES (
            v_school_id, v_students.id, 'LOR-2024-' || LPAD((10 + v_i)::TEXT, 4, '0'), '2024 - 2025',
            CASE WHEN v_i % 2 = 0 THEN 'LEAVE' ELSE 'OUTING' END,
            'Weekend Outing',
            'General weekend outing and shopping',
            'City Center',
            NOW() + (v_i * INTERVAL '1 day'), NOW() + (v_i * INTERVAL '1 day' + INTERVAL '6 hours'),
            'APPROVED', false,
            COALESCE(v_students.building_name, 'Boys Hostel A'),
            COALESCE(v_students.room_number, 'A-201'),
            COALESCE(v_students.bed_code, 'Bed 1'),
            COALESCE(v_students.father_name, 'Guardian'),
            COALESCE(v_students.father_phone, '+91 98000 11111'),
            'Warden', NOW() - INTERVAL '1 day', 'Approved for scheduled travel.',
            NOW() - INTERVAL '2 days', v_admin_id
        );
    END LOOP;

    -- Seed 4 More Pending Requests to reach 8 total pending (Already have Sneha, Ananya, Aman, Aditya = 4)
    FOR v_students IN (
        SELECT p.id, p.full_name, p.class, p.roll_number, b.name as building_name, r.room_number, bd.bed_code, p.father_name, p.father_phone
        FROM public.profiles p
        JOIN public.hostel_admissions ha ON ha.student_id = p.id AND ha.school_id = v_school_id
        LEFT JOIN public.hostel_allocations al ON al.student_id = p.id AND al.deleted_at IS NULL
        LEFT JOIN public.hostel_buildings b ON b.id = al.building_id
        LEFT JOIN public.hostel_rooms r ON r.id = al.room_id
        LEFT JOIN public.hostel_beds bd ON bd.id = al.bed_id
        WHERE p.school_id = v_school_id AND p.role = 'student'
        LIMIT 4 OFFSET 30
    ) LOOP
        v_i := v_i + 1;
        INSERT INTO public.hostel_leave_outing_requests (
            school_id, student_id, request_number, academic_year, request_type, request_subtype,
            reason, destination, start_at, expected_return_at, status, is_emergency,
            building_name, room_number, bed_code, guardian_name, guardian_phone,
            created_at, created_by
        ) VALUES (
            v_school_id, v_students.id, 'LOR-2024-' || LPAD((10 + v_i)::TEXT, 4, '0'), '2024 - 2025',
            CASE WHEN v_i % 2 = 0 THEN 'OUTING' ELSE 'LEAVE' END,
            'Personal Work',
            'Visiting local market for personal supplies',
            'Local Town',
            NOW() + INTERVAL '2 days', NOW() + INTERVAL '2 days' + INTERVAL '8 hours',
            'PENDING', false,
            COALESCE(v_students.building_name, 'Boys Hostel A'),
            COALESCE(v_students.room_number, 'A-108'),
            COALESCE(v_students.bed_code, 'Bed 1'),
            COALESCE(v_students.father_name, 'Parent'),
            COALESCE(v_students.father_phone, '+91 98000 22222'),
            NOW() - INTERVAL '1 day', v_students.id
        );
    END LOOP;

    -- Seed 3 More Rejected Requests to reach 4 total rejected (Already have Vikram = 1)
    FOR v_students IN (
        SELECT p.id, p.full_name, p.class, p.roll_number, b.name as building_name, r.room_number, bd.bed_code, p.father_name, p.father_phone
        FROM public.profiles p
        JOIN public.hostel_admissions ha ON ha.student_id = p.id AND ha.school_id = v_school_id
        LEFT JOIN public.hostel_allocations al ON al.student_id = p.id AND al.deleted_at IS NULL
        LEFT JOIN public.hostel_buildings b ON b.id = al.building_id
        LEFT JOIN public.hostel_rooms r ON r.id = al.room_id
        LEFT JOIN public.hostel_beds bd ON bd.id = al.bed_id
        WHERE p.school_id = v_school_id AND p.role = 'student'
        LIMIT 3 OFFSET 34
    ) LOOP
        v_i := v_i + 1;
        INSERT INTO public.hostel_leave_outing_requests (
            school_id, student_id, request_number, academic_year, request_type, request_subtype,
            reason, destination, start_at, expected_return_at, status, is_emergency,
            building_name, room_number, bed_code, guardian_name, guardian_phone,
            approved_by_name, rejection_reason, created_at, created_by
        ) VALUES (
            v_school_id, v_students.id, 'LOR-2024-' || LPAD((10 + v_i)::TEXT, 4, '0'), '2024 - 2025',
            'LEAVE', 'Personal', 'Weekend night out without parental permission', 'Night Club / City',
            NOW() + INTERVAL '3 days', NOW() + INTERVAL '4 days', 'REJECTED', false,
            COALESCE(v_students.building_name, 'Boys Hostel A'),
            COALESCE(v_students.room_number, 'A-205'),
            COALESCE(v_students.bed_code, 'Bed 2'),
            COALESCE(v_students.father_name, 'Parent'),
            COALESCE(v_students.father_phone, '+91 98000 33333'),
            'Warden', 'Hostel curfew policy violation: night outings not permitted.',
            NOW() - INTERVAL '3 days', v_students.id
        );
    END LOOP;

    -- Seed 4 Canceled Requests to reach exactly 48 Total Requests
    FOR v_students IN (
        SELECT p.id, p.full_name, p.class, p.roll_number, b.name as building_name, r.room_number, bd.bed_code, p.father_name, p.father_phone
        FROM public.profiles p
        JOIN public.hostel_admissions ha ON ha.student_id = p.id AND ha.school_id = v_school_id
        LEFT JOIN public.hostel_allocations al ON al.student_id = p.id AND al.deleted_at IS NULL
        LEFT JOIN public.hostel_buildings b ON b.id = al.building_id
        LEFT JOIN public.hostel_rooms r ON r.id = al.room_id
        LEFT JOIN public.hostel_beds bd ON bd.id = al.bed_id
        WHERE p.school_id = v_school_id AND p.role = 'student'
        LIMIT 4 OFFSET 37
    ) LOOP
        v_i := v_i + 1;
        INSERT INTO public.hostel_leave_outing_requests (
            school_id, student_id, request_number, academic_year, request_type, request_subtype,
            reason, destination, start_at, expected_return_at, status, is_emergency,
            building_name, room_number, bed_code, guardian_name, guardian_phone,
            cancellation_reason, created_at, created_by
        ) VALUES (
            v_school_id, v_students.id, 'LOR-2024-' || LPAD((10 + v_i)::TEXT, 4, '0'), '2024 - 2025',
            'OUTING', 'Shopping', 'Travel plan canceled by student', 'City Market',
            NOW() + INTERVAL '5 days', NOW() + INTERVAL '5 days' + INTERVAL '4 hours', 'CANCELED', false,
            COALESCE(v_students.building_name, 'Girls Hostel A'),
            COALESCE(v_students.room_number, 'G-201'),
            COALESCE(v_students.bed_code, 'Bed 1'),
            COALESCE(v_students.father_name, 'Parent'),
            COALESCE(v_students.father_phone, '+91 98000 44444'),
            'Plan postponed due to classroom assignment deadline.',
            NOW() - INTERVAL '4 days', v_students.id
        );
    END LOOP;

    RAISE NOTICE 'Migration 368: Successfully seeded hostel leave and outing data with 48 requests.';
END $$;
