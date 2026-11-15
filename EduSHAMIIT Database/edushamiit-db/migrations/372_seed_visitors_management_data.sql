-- ============================================================================
-- Migration: 372_seed_visitors_management_data.sql
-- Description: Seed Dynamic Lookups, Locations, Profiles, Visits, Appointments,
--              Gate Passes, Restrictions, and Documents matching Screenshot.
-- ============================================================================

DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_admin_id UUID;
    v_v1_id UUID; v_v2_id UUID; v_v3_id UUID; v_v4_id UUID; v_v5_id UUID;
    v_v6_id UUID; v_v7_id UUID; v_v8_id UUID; v_v9_id UUID; v_v10_id UUID;
    v_blk1_id UUID; v_blk2_id UUID;
    v_visit1_id UUID; v_visit2_id UUID; v_visit3_id UUID;
    v_key_type_id UUID; v_key_purp_id UUID;
    v_cnt INT;
BEGIN
    -- 1. Grab an existing profile as creator/admin
    SELECT id INTO v_admin_id FROM public.profiles WHERE school_id = v_school_id LIMIT 1;
    IF v_admin_id IS NULL THEN
        v_admin_id := '10000000-0000-0000-0000-000000000001';
    END IF;

    -- 2. Ensure Lookups for Visitor Management
    -- VISITOR_TYPE
    SELECT id INTO v_key_type_id FROM public.lookup_keys WHERE school_id = v_school_id AND key_code = 'VISITOR_TYPE' AND deleted_at IS NULL LIMIT 1;
    IF v_key_type_id IS NULL THEN
        INSERT INTO public.lookup_keys (school_id, key_code, key_name, description, status)
        VALUES (v_school_id, 'VISITOR_TYPE', 'Visitor Type', 'Categories of campus visitors', 'ACTIVE')
        RETURNING id INTO v_key_type_id;
    END IF;

    IF v_key_type_id IS NOT NULL THEN
        INSERT INTO public.lookup_values (school_id, lookup_key_id, value_code, value_name, sort_order, status)
        SELECT v_school_id, v_key_type_id, val.code, val.name, val.s_order, 'ACTIVE'
        FROM (VALUES
            ('PARENT', 'Parent', 1),
            ('OFFICIAL', 'Official', 2),
            ('VENDOR', 'Vendor', 3),
            ('MAINTENANCE', 'Maintenance', 4),
            ('ALUMNI', 'Alumni', 5),
            ('RELATIVE', 'Relative', 6),
            ('DELIVERY', 'Delivery', 7),
            ('OTHER', 'Other', 8)
        ) AS val(code, name, s_order)
        WHERE NOT EXISTS (
            SELECT 1 FROM public.lookup_values
            WHERE school_id = v_school_id AND lookup_key_id = v_key_type_id AND value_code = val.code AND deleted_at IS NULL
        );
    END IF;

    -- VISITOR_PURPOSE
    SELECT id INTO v_key_purp_id FROM public.lookup_keys WHERE school_id = v_school_id AND key_code = 'VISITOR_PURPOSE' AND deleted_at IS NULL LIMIT 1;
    IF v_key_purp_id IS NULL THEN
        INSERT INTO public.lookup_keys (school_id, key_code, key_name, description, status)
        VALUES (v_school_id, 'VISITOR_PURPOSE', 'Visitor Purpose', 'Permitted visitor purposes', 'ACTIVE')
        RETURNING id INTO v_key_purp_id;
    END IF;

    IF v_key_purp_id IS NOT NULL THEN
        INSERT INTO public.lookup_values (school_id, lookup_key_id, value_code, value_name, sort_order, status)
        SELECT v_school_id, v_key_purp_id, val.code, val.name, val.s_order, 'ACTIVE'
        FROM (VALUES
            ('MEET_STUDENT', 'Meet Student', 1),
            ('LIBRARY_VISIT', 'Library Visit', 2),
            ('LAB_INSPECTION', 'Lab Inspection', 3),
            ('MATERIAL_DELIVERY', 'Material Delivery', 4),
            ('HOSTEL_VISIT', 'Hostel Visit', 5),
            ('PARCEL_DELIVERY', 'Parcel Delivery', 6),
            ('AC_SERVICING', 'AC Servicing', 7),
            ('CAREER_GUIDANCE', 'Career Guidance', 8),
            ('CAMPUS_VISIT', 'Campus Visit', 9),
            ('OFFICIAL_MEETING', 'Official Meeting', 10)
        ) AS val(code, name, s_order)
        WHERE NOT EXISTS (
            SELECT 1 FROM public.lookup_values
            WHERE school_id = v_school_id AND lookup_key_id = v_key_purp_id AND value_code = val.code AND deleted_at IS NULL
        );
    END IF;

    -- 3. Seed Access Locations
    INSERT INTO public.visitor_access_locations (school_id, location_name, location_code, location_type, is_entry_point, is_exit_point)
    SELECT v_school_id, loc.name, loc.code, loc.l_type, loc.is_in, loc.is_out
    FROM (VALUES
        ('Main Gate', 'LOC_MAIN_GATE', 'GATE', TRUE, TRUE),
        ('Reception Desk', 'LOC_RECEPTION', 'RECEPTION', TRUE, FALSE),
        ('Library', 'LOC_LIBRARY', 'LIBRARY', FALSE, FALSE),
        ('Science Lab', 'LOC_SCIENCE_LAB', 'LAB', FALSE, FALSE),
        ('Boys Hostel', 'LOC_BOYS_HOSTEL', 'HOSTEL', FALSE, FALSE),
        ('Girls Hostel', 'LOC_GIRLS_HOSTEL', 'HOSTEL', FALSE, FALSE),
        ('Auditorium', 'LOC_AUDITORIUM', 'AUDITORIUM', FALSE, FALSE),
        ('Admin Office', 'LOC_ADMIN_OFFICE', 'DEPARTMENT', FALSE, FALSE),
        ('Principal Office', 'LOC_PRINCIPAL_OFFICE', 'DEPARTMENT', FALSE, FALSE)
    ) AS loc(name, code, l_type, is_in, is_out)
    WHERE NOT EXISTS (
        SELECT 1 FROM public.visitor_access_locations WHERE school_id = v_school_id AND location_code = loc.code
    );

    -- 4. Helper lambda-like insertion for Profiles
    -- Clean existing sample profiles for test idempotency
    DELETE FROM public.visitor_documents WHERE school_id = v_school_id;
    DELETE FROM public.visitor_access_events WHERE school_id = v_school_id;
    DELETE FROM public.visitor_gate_passes WHERE school_id = v_school_id;
    DELETE FROM public.visitor_visits WHERE school_id = v_school_id;
    DELETE FROM public.visitor_appointments WHERE school_id = v_school_id;
    DELETE FROM public.visitor_restrictions WHERE school_id = v_school_id;
    DELETE FROM public.visitor_profiles WHERE school_id = v_school_id;

    -- V1: Mr. Rajesh Kumar
    INSERT INTO public.visitor_profiles (
        id, school_id, full_name, phone, alternate_phone, email, company, designation,
        visitor_type, id_type, id_number_masked, photo_url, notes
    ) VALUES (
        'f1000001-0000-0000-0000-000000000001', v_school_id, 'Mr. Rajesh Kumar',
        '+91 98765 43210', '+91 98765 43211', 'rajesh.kumar@email.com', 'Self Employed', 'Parent',
        'Parent', 'Aadhaar Card', 'XXXX-XXXX-1234',
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        'Regular visitor, father of Rahul Sharma Class 10 A'
    ) RETURNING id INTO v_v1_id;

    -- V2: Mrs. Anita Sharma
    INSERT INTO public.visitor_profiles (
        id, school_id, full_name, phone, email, visitor_type, id_type, id_number_masked, photo_url
    ) VALUES (
        'f1000001-0000-0000-0000-000000000002', v_school_id, 'Mrs. Anita Sharma',
        '+91 98765 43212', 'anita.sharma@email.com', 'Parent', 'Voter ID', 'XXXX-XXXX-5678',
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150'
    ) RETURNING id INTO v_v2_id;

    -- V3: Dr. Vikram Mehta
    INSERT INTO public.visitor_profiles (
        id, school_id, full_name, phone, company, designation, visitor_type, id_type, id_number_masked, photo_url
    ) VALUES (
        'f1000001-0000-0000-0000-000000000003', v_school_id, 'Dr. Vikram Mehta',
        '+91 98765 43213', 'State Education Board', 'Senior Inspector', 'Official', 'Passport', 'XXXX-XXXX-9012',
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150'
    ) RETURNING id INTO v_v3_id;

    -- V4: Mr. Suresh Patel
    INSERT INTO public.visitor_profiles (
        id, school_id, full_name, phone, company, designation, visitor_type, id_type, id_number_masked, photo_url
    ) VALUES (
        'f1000001-0000-0000-0000-000000000004', v_school_id, 'Mr. Suresh Patel',
        '+91 98765 43214', 'Apex Stationery & Supplies', 'Sales Executive', 'Vendor', 'Driving License', 'XXXX-XXXX-3456',
        'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150'
    ) RETURNING id INTO v_v4_id;

    -- V5: Ms. Priya Nair
    INSERT INTO public.visitor_profiles (
        id, school_id, full_name, phone, visitor_type, id_type, id_number_masked, photo_url
    ) VALUES (
        'f1000001-0000-0000-0000-000000000005', v_school_id, 'Ms. Priya Nair',
        '+91 98765 43215', 'Relative', 'Aadhaar Card', 'XXXX-XXXX-7890',
        'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150'
    ) RETURNING id INTO v_v5_id;

    -- V6: Delivery Team
    INSERT INTO public.visitor_profiles (
        id, school_id, full_name, phone, company, visitor_type, id_type, id_number_masked, photo_url
    ) VALUES (
        'f1000001-0000-0000-0000-000000000006', v_school_id, 'Delivery Team',
        '+91 98765 43216', 'BlueDart Logistics', 'Delivery', 'Employee ID', 'XXXX-XXXX-2345',
        'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150'
    ) RETURNING id INTO v_v6_id;

    -- V7: AC Service Team
    INSERT INTO public.visitor_profiles (
        id, school_id, full_name, phone, company, visitor_type, id_type, id_number_masked, photo_url
    ) VALUES (
        'f1000001-0000-0000-0000-000000000007', v_school_id, 'AC Service Team',
        '+91 98765 43217', 'CoolAir Technical Services', 'Maintenance', 'Driving License', 'XXXX-XXXX-6789',
        'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150'
    ) RETURNING id INTO v_v7_id;

    -- V8: Career Counselor
    INSERT INTO public.visitor_profiles (
        id, school_id, full_name, phone, company, designation, visitor_type, id_type, id_number_masked, photo_url
    ) VALUES (
        'f1000001-0000-0000-0000-000000000008', v_school_id, 'Career Counselor',
        '+91 98765 43218', 'EduPath Guidance Corp', 'Director', 'Official', 'PAN Card', 'XXXX-XXXX-0123',
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150'
    ) RETURNING id INTO v_v8_id;

    -- V9: Mr. Deepak Singh
    INSERT INTO public.visitor_profiles (
        id, school_id, full_name, phone, visitor_type, id_type, id_number_masked, photo_url
    ) VALUES (
        'f1000001-0000-0000-0000-000000000009', v_school_id, 'Mr. Deepak Singh',
        '+91 98765 43219', 'Parent', 'Aadhaar Card', 'XXXX-XXXX-4567',
        'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=150'
    ) RETURNING id INTO v_v9_id;

    -- V10: Ms. Kavita Rao
    INSERT INTO public.visitor_profiles (
        id, school_id, full_name, phone, visitor_type, id_type, id_number_masked, photo_url
    ) VALUES (
        'f1000001-0000-0000-0000-000000000010', v_school_id, 'Ms. Kavita Rao',
        '+91 98765 43220', 'Alumni', 'PAN Card', 'XXXX-XXXX-8901',
        'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150'
    ) RETURNING id INTO v_v10_id;

    -- 5. Seed Visits matching screenshot rows
    -- Row 1: Mr. Rajesh Kumar (Inside)
    INSERT INTO public.visitor_visits (
        id, school_id, visit_number, visitor_id, purpose, category,
        entry_location, destination, host_name, check_in_at, expected_out_at,
        status, vehicle_number, remarks, pass_reference
    ) VALUES (
        'f2000001-0000-0000-0000-000000000001', v_school_id, 'VIS-2024-001',
        v_v1_id, 'Meet Student', 'Parent', 'Main Gate', 'Main Gate',
        'Rahul Sharma (Class 10 A)', NOW() - interval '1 hour 45 minutes',
        NOW() + interval '1 hour 15 minutes', 'Inside', 'UP16 AB 1234',
        'Meeting regarding academic progress', 'GP-2024-001'
    ) RETURNING id INTO v_visit1_id;

    -- Row 2: Mrs. Anita Sharma (Inside)
    INSERT INTO public.visitor_visits (
        id, school_id, visit_number, visitor_id, purpose, category,
        entry_location, destination, host_name, check_in_at, expected_out_at,
        status, pass_reference
    ) VALUES (
        'f2000001-0000-0000-0000-000000000002', v_school_id, 'VIS-2024-002',
        v_v2_id, 'Library Visit', 'Parent', 'Main Gate', 'Library',
        'Ms. Neha Verma (Librarian)', NOW() - interval '1 hour',
        NOW() + interval '30 minutes', 'Inside', 'GP-2024-002'
    ) RETURNING id INTO v_visit2_id;

    -- Row 3: Dr. Vikram Mehta (Inside)
    INSERT INTO public.visitor_visits (
        id, school_id, visit_number, visitor_id, purpose, category,
        entry_location, destination, host_name, check_in_at, expected_out_at,
        status, pass_reference
    ) VALUES (
        'f2000001-0000-0000-0000-000000000003', v_school_id, 'VIS-2024-003',
        v_v3_id, 'Lab Inspection', 'Official', 'Main Gate', 'Science Lab',
        'Mr. Amit Singh (Lab Incharge)', NOW() - interval '2 hours',
        NOW() + interval '1 hour', 'Inside', 'GP-2024-003'
    ) RETURNING id INTO v_visit3_id;

    -- Row 4: Mr. Suresh Patel (Checked Out)
    INSERT INTO public.visitor_visits (
        id, school_id, visit_number, visitor_id, purpose, category,
        entry_location, destination, host_name, check_in_at, expected_out_at,
        actual_check_out_at, status, pass_reference
    ) VALUES (
        'f2000001-0000-0000-0000-000000000004', v_school_id, 'VIS-2024-004',
        v_v4_id, 'Material Delivery', 'Vendor', 'Main Gate', 'Main Gate',
        'Mr. Ramesh (Admin)', NOW() - interval '1 day 4 hours',
        NOW() - interval '1 day 3 hours', NOW() - interval '1 day 3 hours 10 minutes',
        'Checked Out', 'GP-2024-004'
    );

    -- Row 5: Ms. Priya Nair (Checked Out)
    INSERT INTO public.visitor_visits (
        id, school_id, visit_number, visitor_id, purpose, category,
        entry_location, destination, host_name, check_in_at, expected_out_at,
        actual_check_out_at, status, pass_reference
    ) VALUES (
        'f2000001-0000-0000-0000-000000000005', v_school_id, 'VIS-2024-005',
        v_v5_id, 'Hostel Visit', 'Relative', 'Main Gate', 'Girls Hostel',
        'Warden', NOW() - interval '1 day 5 hours',
        NOW() - interval '1 day 4 hours', NOW() - interval '1 day 4 hours 15 minutes',
        'Checked Out', 'GP-2024-005'
    );

    -- Row 6: Delivery Team (Checked Out)
    INSERT INTO public.visitor_visits (
        id, school_id, visit_number, visitor_id, purpose, category,
        entry_location, destination, host_name, check_in_at, expected_out_at,
        actual_check_out_at, status, pass_reference
    ) VALUES (
        'f2000001-0000-0000-0000-000000000006', v_school_id, 'VIS-2024-006',
        v_v6_id, 'Parcel Delivery', 'Delivery', 'Main Gate', 'Main Gate',
        'Security', NOW() - interval '1 day 7 hours',
        NOW() - interval '1 day 6 hours 30 minutes', NOW() - interval '1 day 6 hours 35 minutes',
        'Checked Out', 'GP-2024-006'
    );

    -- Row 7: AC Service Team (Overstay)
    INSERT INTO public.visitor_visits (
        id, school_id, visit_number, visitor_id, purpose, category,
        entry_location, destination, host_name, check_in_at, expected_out_at,
        status, remarks, pass_reference
    ) VALUES (
        'f2000001-0000-0000-0000-000000000007', v_school_id, 'VIS-2024-007',
        v_v7_id, 'AC Servicing', 'Maintenance', 'Main Gate', 'Boys Hostel',
        'Warden', NOW() - interval '5 hours',
        NOW() - interval '1 hour', 'Overstay', 'Servicing 32 split AC units', 'GP-2024-007'
    );

    -- Row 8: Career Counselor (Checked Out)
    INSERT INTO public.visitor_visits (
        id, school_id, visit_number, visitor_id, purpose, category,
        entry_location, destination, host_name, check_in_at, expected_out_at,
        actual_check_out_at, status, pass_reference
    ) VALUES (
        'f2000001-0000-0000-0000-000000000008', v_school_id, 'VIS-2024-008',
        v_v8_id, 'Career Guidance', 'Official', 'Main Gate', 'Auditorium',
        'Principal', NOW() - interval '2 days 3 hours',
        NOW() - interval '2 days 1 hour', NOW() - interval '2 days 1 hour',
        'Checked Out', 'GP-2024-008'
    );

    -- Row 9: Mr. Deepak Singh (Checked Out)
    INSERT INTO public.visitor_visits (
        id, school_id, visit_number, visitor_id, purpose, category,
        entry_location, destination, host_name, check_in_at, expected_out_at,
        actual_check_out_at, status, pass_reference
    ) VALUES (
        'f2000001-0000-0000-0000-000000000009', v_school_id, 'VIS-2024-009',
        v_v9_id, 'Meet Student', 'Parent', 'Main Gate', 'Main Gate',
        'Class 9 C', NOW() - interval '2 days 5 hours',
        NOW() - interval '2 days 4 hours', NOW() - interval '2 days 4 hours',
        'Checked Out', 'GP-2024-009'
    );

    -- Row 10: Ms. Kavita Rao (Checked Out)
    INSERT INTO public.visitor_visits (
        id, school_id, visit_number, visitor_id, purpose, category,
        entry_location, destination, host_name, check_in_at, expected_out_at,
        actual_check_out_at, status, pass_reference
    ) VALUES (
        'f2000001-0000-0000-0000-000000000010', v_school_id, 'VIS-2024-010',
        v_v10_id, 'Campus Visit', 'Alumni', 'Main Gate', 'Main Gate',
        'Admin', NOW() - interval '3 days 4 hours',
        NOW() - interval '3 days 2 hours', NOW() - interval '3 days 2 hours 15 minutes',
        'Checked Out', 'GP-2024-010'
    );

    -- Extra visits to match realistic totals (38 inside, 4 overstay, 62 today, 256 total)
    FOR i IN 11..256 LOOP
        INSERT INTO public.visitor_visits (
            school_id, visit_number, visitor_id, purpose, category,
            entry_location, destination, host_name, check_in_at, expected_out_at,
            actual_check_out_at, status, pass_reference
        ) VALUES (
            v_school_id, 'VIS-2024-' || LPAD(i::TEXT, 3, '0'),
            CASE WHEN i % 2 = 0 THEN v_v2_id ELSE v_v4_id END,
            CASE WHEN i % 4 = 0 THEN 'Meet Student' WHEN i % 4 = 1 THEN 'Library Visit' WHEN i % 4 = 2 THEN 'Lab Inspection' ELSE 'Material Delivery' END,
            CASE WHEN i % 5 = 0 THEN 'Parent' WHEN i % 5 = 1 THEN 'Official' WHEN i % 5 = 2 THEN 'Vendor' WHEN i % 5 = 3 THEN 'Maintenance' ELSE 'Alumni' END,
            'Main Gate',
            CASE WHEN i % 5 = 0 THEN 'Library' WHEN i % 5 = 1 THEN 'Science Lab' WHEN i % 5 = 2 THEN 'Boys Hostel' WHEN i % 5 = 3 THEN 'Girls Hostel' ELSE 'Admin Office' END,
            'Faculty Member',
            CASE WHEN i <= 62 THEN NOW() - ((i * 4) || ' minutes')::INTERVAL ELSE NOW() - ((i / 10) || ' days')::INTERVAL END,
            CASE
                WHEN i <= 38 THEN NOW() + interval '2 hours'
                WHEN i IN (39, 40, 41) THEN NOW() - interval '30 minutes'
                ELSE NOW() - interval '1 hour'
            END,
            CASE
                WHEN i <= 38 THEN NULL -- inside
                WHEN i IN (39, 40, 41) THEN NULL -- overstay
                ELSE NOW() - interval '30 minutes' -- completed
            END,
            CASE
                WHEN i <= 38 THEN 'Inside'
                WHEN i IN (39, 40, 41) THEN 'Overstay'
                ELSE 'Checked Out'
            END,
            'GP-2024-' || LPAD(i::TEXT, 3, '0')
        );
    END LOOP;

    -- 6. Seed Gate Pass for Visit 1
    INSERT INTO public.visitor_gate_passes (
        school_id, visit_id, pass_number, token_hash, status,
        issued_at, expires_at
    ) VALUES (
        v_school_id, v_visit1_id, 'GP-2024-001',
        md5('GP-2024-001' || v_visit1_id::TEXT),
        'ACTIVE', NOW() - interval '1 hour 45 minutes', NOW() + interval '1 hour 15 minutes'
    );

    -- 7. Seed Documents for Mr. Rajesh Kumar (matching screenshot: Documents (2))
    INSERT INTO public.visitor_documents (
        school_id, visitor_id, visit_id, document_name, document_type, file_url, verification_status
    ) VALUES
        (v_school_id, v_v1_id, v_visit1_id, 'Aadhaar_Card_Masked.pdf', 'ID Proof', 'https://edushamiit.internal/docs/aadhaar_masked_1234.pdf', 'VERIFIED'),
        (v_school_id, v_v1_id, v_visit1_id, 'Vehicle_RC_Copy.jpg', 'Vehicle Registration', 'https://edushamiit.internal/docs/rc_up16ab1234.jpg', 'VERIFIED');

    -- 8. Seed Scheduled Appointments (matching screenshot Scheduled tab)
    INSERT INTO public.visitor_appointments (
        school_id, appointment_number, visitor_id, host_name, host_department,
        purpose, destination, scheduled_date, scheduled_start_at, scheduled_end_at, status
    ) VALUES
        (v_school_id, 'APT-2024-001', v_v1_id, 'Rahul Sharma (Class 10 A)', 'Secondary School', 'Term Fee Discussion', 'Main Gate', CURRENT_DATE, NOW() + interval '2 hours', NOW() + interval '3 hours', 'APPROVED'),
        (v_school_id, 'APT-2024-002', v_v3_id, 'Director / Principal', 'Administration', 'Annual CBSE Accreditation Audit', 'Principal Office', CURRENT_DATE, NOW() + interval '4 hours', NOW() + interval '6 hours', 'APPROVED'),
        (v_school_id, 'APT-2024-003', v_v4_id, 'Mr. Ramesh (Admin)', 'Procurement', 'Laboratory Glassware Inspection', 'Science Lab', CURRENT_DATE, NOW() + interval '5 hours', NOW() + interval '6 hours', 'AWAITING_APPROVAL'),
        (v_school_id, 'APT-2024-004', v_v8_id, 'Career Cell Head', 'Academic Counseling', 'Class 12 Career Guidance Workshop', 'Auditorium', CURRENT_DATE + 1, NOW() + interval '1 day 2 hours', NOW() + interval '1 day 4 hours', 'APPROVED'),
        (v_school_id, 'APT-2024-005', v_v10_id, 'Alumni Relations Incharge', 'Alumni Cell', 'Annual Reunion Planning Committee', 'Admin Office', CURRENT_DATE + 2, NOW() + interval '2 days', NOW() + interval '2 days 1 hour', 'AWAITING_APPROVAL');

    -- Add extra today's scheduled to hit 12 scheduled today
    FOR i IN 6..14 LOOP
        INSERT INTO public.visitor_appointments (
            school_id, appointment_number, visitor_id, host_name, host_department,
            purpose, destination, scheduled_date, scheduled_start_at, scheduled_end_at, status
        ) VALUES (
            v_school_id, 'APT-2024-' || LPAD(i::TEXT, 3, '0'), v_v2_id,
            'Teacher Incharge', 'Academics', 'Academic Progress Review',
            'Main Gate', CURRENT_DATE, NOW() + ((i * 30) || ' minutes')::INTERVAL,
            NOW() + ((i * 30 + 30) || ' minutes')::INTERVAL,
            CASE WHEN i % 2 = 0 THEN 'APPROVED' ELSE 'AWAITING_APPROVAL' END
        );
    END LOOP;

    -- 9. Seed Blacklisted Visitors (matching screenshot Blacklisted tab)
    -- Blacklist 1: Disciplinary breach
    INSERT INTO public.visitor_profiles (
        id, school_id, full_name, phone, company, visitor_type, is_blacklisted
    ) VALUES (
        'f1000001-0000-0000-0000-000000000099', v_school_id, 'Rohan Verma',
        '+91 91234 56789', 'External Contractor', 'Contractor', TRUE
    ) RETURNING id INTO v_blk1_id;

    INSERT INTO public.visitor_restrictions (
        school_id, visitor_id, visitor_name, visitor_phone,
        scope_type, scope_name, reason_category, confidential_notes,
        status, requested_by_name, approved_by_name, effective_from, review_at
    ) VALUES (
        v_school_id, v_blk1_id, 'Rohan Verma', '+91 91234 56789',
        'INSTITUTION', 'Entire Institution', 'Prior access violation',
        'Attempted unauthorized photography in restricted examination cell on 04 April 2024. Incident logged by Chief Security Officer.',
        'ACTIVE', 'Security Desk Officer', 'Director / Principal',
        NOW() - interval '14 days', NOW() + interval '16 days'
    );

    -- Blacklist 2: Suspended access
    INSERT INTO public.visitor_profiles (
        id, school_id, full_name, phone, company, visitor_type, is_blacklisted
    ) VALUES (
        'f1000001-0000-0000-0000-000000000098', v_school_id, 'Sunil Grover',
        '+91 92345 67890', 'Grover Electricals', 'Vendor', TRUE
    ) RETURNING id INTO v_blk2_id;

    INSERT INTO public.visitor_restrictions (
        school_id, visitor_id, visitor_name, visitor_phone,
        scope_type, scope_name, reason_category, confidential_notes,
        status, requested_by_name, approved_by_name, effective_from, review_at
    ) VALUES (
        v_school_id, v_blk2_id, 'Sunil Grover', '+91 92345 67890',
        'BUILDING', 'Girls Hostel Block B', 'Unauthorized entry attempt',
        'Vendor entered residential area without required warden escort. Access restricted to administrative buildings only.',
        'ACTIVE', 'Hostel Warden', 'Campus Administrator',
        NOW() - interval '5 days', NOW() + interval '25 days'
    );

END $$;
