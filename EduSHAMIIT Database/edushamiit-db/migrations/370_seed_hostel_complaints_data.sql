-- ============================================================================
-- Migration: 370_seed_hostel_complaints_data.sql
-- Description: Realistic Seed Data for Hostel Complaints Management
--              Matches Screenshot (36 Total, 24 Resolved, 8 Pending, 4 Overdue,
--              6 High Priority, 14 Maintenance Related)
-- ============================================================================

DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_admin_id UUID := 'd1a22222-2222-2222-2222-222222222222';
    
    -- Student IDs
    v_s_rahul UUID := 'a1000001-0000-0000-0000-000000000001';
    v_s_sneha UUID := 'a1000001-0000-0000-0000-000000000002';
    v_s_karthik UUID := 'a1000001-0000-0000-0000-000000000003';
    v_s_ananya UUID := 'a1000001-0000-0000-0000-000000000004';
    v_s_vikram UUID := 'a1000001-0000-0000-0000-000000000005';
    v_s_pooja UUID := 'a1000001-0000-0000-0000-000000000006';
    v_s_aman UUID := 'a1000001-0000-0000-0000-000000000007';
    v_s_riya UUID := 'a1000001-0000-0000-0000-000000000008';
    v_s_dev UUID := 'a1000001-0000-0000-0000-000000000009';
    v_s_aditya UUID := 'a1000001-0000-0000-0000-000000000010';

    -- Hostel IDs
    v_h_bha UUID;
    v_h_bhb UUID;
    v_h_gha UUID;
    v_h_ghb UUID;

    -- Rooms
    v_r_a101 UUID;
    v_r_a102 UUID;
    v_r_b205 UUID;
    v_r_b206 UUID;
    v_r_g101 UUID;
    v_r_g203 UUID;
    v_r_g305 UUID;

    -- Complaint 1 UUID
    v_c1_id UUID := 'c0000001-0000-0000-0000-000000000001';
BEGIN
    -- Resolve Hostels
    SELECT id INTO v_h_bha FROM public.hostel_buildings WHERE UPPER(code) = 'BH-A' OR UPPER(name) LIKE '%BOYS HOSTEL A%' LIMIT 1;
    SELECT id INTO v_h_bhb FROM public.hostel_buildings WHERE UPPER(code) = 'BH-B' OR UPPER(name) LIKE '%BOYS HOSTEL B%' LIMIT 1;
    SELECT id INTO v_h_gha FROM public.hostel_buildings WHERE UPPER(code) = 'GH-A' OR UPPER(name) LIKE '%GIRLS HOSTEL A%' LIMIT 1;
    SELECT id INTO v_h_ghb FROM public.hostel_buildings WHERE UPPER(code) = 'GH-B' OR UPPER(name) LIKE '%GIRLS HOSTEL B%' LIMIT 1;

    -- Resolve Rooms
    SELECT id INTO v_r_a101 FROM public.hostel_rooms WHERE room_number = 'A-101' LIMIT 1;
    SELECT id INTO v_r_a102 FROM public.hostel_rooms WHERE room_number = 'A-102' LIMIT 1;
    SELECT id INTO v_r_b205 FROM public.hostel_rooms WHERE room_number = 'B-205' LIMIT 1;
    SELECT id INTO v_r_b206 FROM public.hostel_rooms WHERE room_number = 'B-206' LIMIT 1;
    SELECT id INTO v_r_g101 FROM public.hostel_rooms WHERE room_number = 'G-101' LIMIT 1;
    SELECT id INTO v_r_g203 FROM public.hostel_rooms WHERE room_number = 'G-203' LIMIT 1;
    SELECT id INTO v_r_g305 FROM public.hostel_rooms WHERE room_number = 'G-305' LIMIT 1;

    -- Clear existing test complaints for fresh baseline
    DELETE FROM public.hostel_complaints WHERE school_id = v_school_id;

    -- ========================================================================
    -- COMPLAINT 1: Water leakage in bathroom (Rahul Sharma, HC-2024-001)
    -- ========================================================================
    INSERT INTO public.hostel_complaints (
        id, school_id, complaint_number, academic_year, title, description,
        category, subcategory, priority, status,
        reported_by_user_id, reported_by_name, reported_by_role, reported_by_class,
        hostel_id, hostel_name, room_id, room_number,
        primary_assignee_name, primary_assignee_role,
        resolution_due_at, thumbnail_url, created_at, updated_at
    ) VALUES (
        v_c1_id, v_school_id, 'HC-2024-001', '2024 - 2025',
        'Water leakage in bathroom',
        'There is continuous water leakage from the wash basin tap in bathroom A-101. Water is wasting and the floor is always wet.',
        'Plumbing', 'Bathroom / Tap Leak', 'HIGH', 'ACTIVE',
        v_s_rahul, 'Rahul Sharma', 'Student', 'Class 10 A',
        v_h_bha, 'Boys Hostel A', v_r_a101, 'A-101',
        'Mr. Ramesh', 'Mr. Ramesh (Maintenance Staff)',
        NOW() + INTERVAL '2 days',
        'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?auto=format&fit=crop&w=300&q=80',
        '2024-05-12 10:30:00+00', '2024-05-12 11:00:00+00'
    );

    -- Timeline for Complaint 1
    INSERT INTO public.hostel_complaint_status_history (complaint_id, school_id, actor_name, actor_role, from_status, to_status, event_title, action_note, created_at)
    VALUES
    (v_c1_id, v_school_id, 'Rahul Sharma', 'Student', NULL, 'NEW', 'Complaint raised', 'by Rahul Sharma', '2024-05-12 10:30:00+00'),
    (v_c1_id, v_school_id, 'Hostel Administrator', 'Admin', 'NEW', 'ACTIVE', 'Assigned to Mr. Ramesh', 'by Hostel Administrator', '2024-05-12 11:00:00+00'),
    (v_c1_id, v_school_id, 'Mr. Ramesh', 'Staff', 'ACTIVE', 'IN_PROGRESS', 'In progress', 'Ramesh: Spare part ordered, will fix by tomorrow.', '2024-05-12 14:15:00+00'),
    (v_c1_id, v_school_id, 'Hostel Desk', 'System', 'IN_PROGRESS', 'RESOLVED', 'Pending student confirmation', 'Awaiting confirmation after resolution', '2024-05-13 09:00:00+00');

    -- Comments for Complaint 1
    INSERT INTO public.hostel_complaint_comments (complaint_id, school_id, author_user_id, author_name, author_role, comment_type, message, created_at)
    VALUES
    (v_c1_id, v_school_id, v_s_rahul, 'Rahul Sharma', 'Student', 'PUBLIC_UPDATE', 'Water is still leaking continuously please expedite.', '2024-05-12 11:30:00+00'),
    (v_c1_id, v_school_id, v_admin_id, 'Hostel Warden', 'Admin', 'INTERNAL_NOTE', 'Assigned Ramesh on priority ticket.', '2024-05-12 12:00:00+00'),
    (v_c1_id, v_school_id, v_admin_id, 'Mr. Ramesh', 'Staff', 'PUBLIC_UPDATE', 'Technician visited and replacement washer will be fitted today.', '2024-05-12 14:15:00+00');

    -- ========================================================================
    -- COMPLAINT 2: Fan not working (Sneha Iyer, HC-2024-002)
    -- ========================================================================
    INSERT INTO public.hostel_complaints (
        school_id, complaint_number, academic_year, title, description,
        category, priority, status,
        reported_by_user_id, reported_by_name, reported_by_role, reported_by_class,
        hostel_id, hostel_name, room_id, room_number,
        primary_assignee_name, primary_assignee_role,
        resolution_due_at, created_at
    ) VALUES (
        v_school_id, 'HC-2024-002', '2024 - 2025',
        'Fan not working', 'Ceiling fan in room G-203 has stopped rotating completely.',
        'Electrical', 'MEDIUM', 'IN_PROGRESS',
        v_s_sneha, 'Sneha Iyer', 'Student', 'Class 9 A',
        v_h_gha, 'Girls Hostel A', v_r_g203, 'G-203',
        'Suresh Electrician', 'Suresh Electrician (Maintenance)',
        NOW() + INTERVAL '1 day', '2024-05-11 16:15:00+00'
    );

    -- ========================================================================
    -- COMPLAINT 3: Untidy common area (Karthik Reddy, HC-2024-003)
    -- ========================================================================
    INSERT INTO public.hostel_complaints (
        school_id, complaint_number, academic_year, title, description,
        category, priority, status,
        reported_by_user_id, reported_by_name, reported_by_role, reported_by_class,
        hostel_id, hostel_name, room_id, room_number,
        primary_assignee_name, primary_assignee_role,
        resolved_at, resolution_summary, created_at
    ) VALUES (
        v_school_id, 'HC-2024-003', '2024 - 2025',
        'Untidy common area', 'Corridor on 2nd floor has dust and litter from yesterday evening.',
        'Housekeeping', 'LOW', 'RESOLVED',
        v_s_karthik, 'Karthik Reddy', 'Student', 'Class 10 B',
        v_h_bhb, 'Boys Hostel B', v_r_b205, 'B-205',
        'Mahesh Cleaners', 'Housekeeping Lead',
        '2024-05-10 11:30:00+00', 'Cleaned corridor and added extra trash bins.', '2024-05-10 08:20:00+00'
    );

    -- ========================================================================
    -- COMPLAINT 4: Broken study table (Ananya Patel, HC-2024-004)
    -- ========================================================================
    INSERT INTO public.hostel_complaints (
        school_id, complaint_number, academic_year, title, description,
        category, priority, status,
        reported_by_user_id, reported_by_name, reported_by_role, reported_by_class,
        hostel_id, hostel_name, room_id, room_number,
        resolution_due_at, created_at
    ) VALUES (
        v_school_id, 'HC-2024-004', '2024 - 2025',
        'Broken study table', 'Left leg of the wooden study table in G-101 is wobbling and cracked.',
        'Furniture', 'MEDIUM', 'NEW',
        v_s_ananya, 'Ananya Patel', 'Student', 'Class 11 A',
        v_h_ghb, 'Girls Hostel B', v_r_g101, 'G-101',
        NOW() + INTERVAL '3 days', '2024-05-09 14:45:00+00'
    );

    -- ========================================================================
    -- COMPLAINT 5: Frequent power cuts (Vikram Singh, HC-2024-005)
    -- ========================================================================
    INSERT INTO public.hostel_complaints (
        school_id, complaint_number, academic_year, title, description,
        category, priority, status,
        reported_by_user_id, reported_by_name, reported_by_role, reported_by_class,
        hostel_id, hostel_name, room_id, room_number,
        primary_assignee_name, resolution_due_at, created_at
    ) VALUES (
        v_school_id, 'HC-2024-005', '2024 - 2025',
        'Frequent power cuts', 'Power tripping continuously whenever multiple study lamps are on.',
        'Electrical', 'HIGH', 'IN_PROGRESS',
        v_s_vikram, 'Vikram Singh', 'Student', 'Class 10 A',
        v_h_bha, 'Boys Hostel A', v_r_a102, 'A-102',
        'Manoj Kumar', NOW() + INTERVAL '1 day', '2024-05-08 11:20:00+00'
    );

    -- ========================================================================
    -- COMPLAINT 6: AC not cooling (Pooja Mehta, HC-2024-006)
    -- ========================================================================
    INSERT INTO public.hostel_complaints (
        school_id, complaint_number, academic_year, title, description,
        category, priority, status,
        reported_by_user_id, reported_by_name, reported_by_role, reported_by_class,
        hostel_id, hostel_name, room_id, room_number,
        resolution_due_at, created_at
    ) VALUES (
        v_school_id, 'HC-2024-006', '2024 - 2025',
        'AC not cooling', 'Split AC running but blowing warm air in room G-305.',
        'AC/Heating', 'MEDIUM', 'ON_HOLD',
        v_s_pooja, 'Pooja Mehta', 'Student', 'Class 12 A',
        v_h_gha, 'Girls Hostel A', v_r_g305, 'G-305',
        NOW() - INTERVAL '1 day', '2024-05-07 17:10:00+00'
    );

    -- ========================================================================
    -- COMPLAINT 7: Mosquito issue (Aman Khan, HC-2024-007)
    -- ========================================================================
    INSERT INTO public.hostel_complaints (
        school_id, complaint_number, academic_year, title, description,
        category, priority, status,
        reported_by_user_id, reported_by_name, reported_by_role, reported_by_class,
        hostel_id, hostel_name, room_id, room_number,
        resolved_at, resolution_summary, created_at
    ) VALUES (
        v_school_id, 'HC-2024-007', '2024 - 2025',
        'Mosquito issue', 'Mesh on room window has a gap letting in mosquitoes.',
        'Pest Control', 'LOW', 'RESOLVED',
        v_s_aman, 'Aman Khan', 'Student', 'Class 10 C',
        v_h_bhb, 'Boys Hostel B', v_r_b206, 'B-206',
        '2024-05-06 16:00:00+00', 'Window mesh repaired and fumigation done.', '2024-05-06 09:00:00+00'
    );

    -- ========================================================================
    -- COMPLAINT 8: Toilet flush not working (Riya Nair, HC-2024-008)
    -- ========================================================================
    INSERT INTO public.hostel_complaints (
        school_id, complaint_number, academic_year, title, description,
        category, priority, status,
        reported_by_user_id, reported_by_name, reported_by_role, reported_by_class,
        hostel_id, hostel_name, room_id, room_number,
        resolution_due_at, created_at
    ) VALUES (
        v_school_id, 'HC-2024-008', '2024 - 2025',
        'Toilet flush not working', 'Flush button is stuck and water is overflowing.',
        'Plumbing', 'HIGH', 'NEW',
        v_s_riya, 'Riya Nair', 'Student', 'Class 11 B',
        v_h_ghb, 'Girls Hostel B', v_r_g203, 'G-203',
        NOW() + INTERVAL '12 hours', '2024-05-05 15:30:00+00'
    );

    -- ========================================================================
    -- COMPLAINT 9: Gate light not working (Dev Kumar, HC-2024-009)
    -- ========================================================================
    INSERT INTO public.hostel_complaints (
        school_id, complaint_number, academic_year, title, description,
        category, priority, status,
        reported_by_user_id, reported_by_name, reported_by_role, reported_by_class,
        hostel_id, hostel_name, room_number, facility_type,
        primary_assignee_name, resolution_due_at, created_at
    ) VALUES (
        v_school_id, 'HC-2024-009', '2024 - 2025',
        'Gate light not working', 'Outdoor floodlight at main entrance is dark causing safety concern.',
        'Electrical', 'MEDIUM', 'IN_PROGRESS',
        v_s_dev, 'Dev Kumar', 'Student', 'Class 9 C',
        v_h_bha, 'Boys Hostel A', 'Main Gate', 'Common Area',
        'Ashok Electrician', NOW() + INTERVAL '18 hours', '2024-05-04 19:15:00+00'
    );

    -- ========================================================================
    -- COMPLAINT 10: Food quality concern (Aditya Gupta, HC-2024-010)
    -- ========================================================================
    INSERT INTO public.hostel_complaints (
        school_id, complaint_number, academic_year, title, description,
        category, priority, status,
        reported_by_user_id, reported_by_name, reported_by_role, reported_by_class,
        hostel_id, hostel_name, room_number, facility_type,
        resolved_at, resolution_summary, created_at
    ) VALUES (
        v_school_id, 'HC-2024-010', '2024 - 2025',
        'Food quality concern', 'Chapati was undercooked during lunch service today.',
        'Food & Mess', 'LOW', 'RESOLVED',
        v_s_aditya, 'Aditya Gupta', 'Student', 'Class 12 A',
        v_h_gha, 'Girls Hostel A', 'Mess', 'Mess / Dining Area',
        '2024-05-03 16:30:00+00', 'Mess supervisor notified and cooking team retrained.', '2024-05-03 13:25:00+00'
    );

    -- ========================================================================
    -- SEED REMAINING COMPLAINTS (11 to 36) TO MATCH STATS:
    -- Total: 36, Resolved: 24, Pending: 8, Overdue: 4, High: 6, Maint: 14
    -- ========================================================================
    -- 22 more RESOLVED complaints (total resolved = 24)
    FOR i IN 11..32 LOOP
        INSERT INTO public.hostel_complaints (
            school_id, complaint_number, academic_year, title, description,
            category, priority, status,
            reported_by_user_id, reported_by_name, reported_by_role, reported_by_class,
            hostel_id, hostel_name, room_number,
            resolved_at, completed_at, resolution_summary, created_at
        ) VALUES (
            v_school_id, 'HC-2024-' || LPAD(i::TEXT, 3, '0'), '2024 - 2025',
            CASE (i % 6)
                WHEN 0 THEN 'Water dispenser empty'
                WHEN 1 THEN 'WiFi connection dropping'
                WHEN 2 THEN 'Curtain rod loose'
                WHEN 3 THEN 'Door handle squeaking'
                WHEN 4 THEN 'Geyser taking too long to heat'
                ELSE 'Dusty common reading room'
            END,
            'Routine hostel issue reported by resident and resolved promptly by warden team.',
            CASE (i % 6)
                WHEN 0 THEN 'Water Supply'
                WHEN 1 THEN 'Internet/WiFi'
                WHEN 2 THEN 'Furniture'
                WHEN 3 THEN 'Maintenance'
                WHEN 4 THEN 'Electrical'
                ELSE 'Housekeeping'
            END,
            CASE WHEN i = 11 THEN 'HIGH' ELSE 'LOW' END,
            CASE WHEN i % 2 = 0 THEN 'COMPLETED' ELSE 'RESOLVED' END,
            v_s_rahul, 'Resident Student', 'Student', 'Class 10 A',
            v_h_bha, 'Boys Hostel A', 'A-' || (100 + (i % 8)),
            NOW() - ((35 - i) || ' days')::INTERVAL,
            NOW() - ((34 - i) || ' days')::INTERVAL,
            'Issue inspected and repaired by campus team.',
            NOW() - ((36 - i) || ' days')::INTERVAL
        );
    END LOOP;

    -- 3 more OVERDUE complaints (total overdue = 4: c6 + c33, c34, c35)
    FOR i IN 33..35 LOOP
        INSERT INTO public.hostel_complaints (
            school_id, complaint_number, academic_year, title, description,
            category, priority, status,
            reported_by_user_id, reported_by_name, reported_by_role, reported_by_class,
            hostel_id, hostel_name, room_number,
            primary_assignee_name, resolution_due_at, sla_status, created_at
        ) VALUES (
            v_school_id, 'HC-2024-' || LPAD(i::TEXT, 3, '0'), '2024 - 2025',
            CASE i
                WHEN 33 THEN 'Main drainage blockage'
                WHEN 34 THEN 'Water tank valve replacement'
                ELSE 'Fire extinguisher inspection overdue'
            END,
            'Critical facility repair requiring external vendor dispatch.',
            CASE i
                WHEN 33 THEN 'Plumbing'
                WHEN 34 THEN 'Water Supply'
                ELSE 'Safety'
            END,
            CASE WHEN i = 33 THEN 'HIGH' ELSE 'MEDIUM' END,
            'ACTIVE',
            v_s_sneha, 'Sneha Iyer', 'Student', 'Class 9 A',
            v_h_gha, 'Girls Hostel A', 'G-102',
            'Vendor Lead', NOW() - ((36 - i) * 6 || ' hours')::INTERVAL,
            'OVERDUE',
            NOW() - ((38 - i) || ' days')::INTERVAL
        );
    END LOOP;

    -- Complaint 36: Final Active complaint
    INSERT INTO public.hostel_complaints (
        school_id, complaint_number, academic_year, title, description,
        category, priority, status,
        reported_by_user_id, reported_by_name, reported_by_role, reported_by_class,
        hostel_id, hostel_name, room_number,
        primary_assignee_name, resolution_due_at, created_at
    ) VALUES (
        v_school_id, 'HC-2024-036', '2024 - 2025',
        'Study room light tube flickering',
        'Fluorescent tube light in 1st floor study room is flickering and causing eye strain.',
        'Electrical', 'LOW', 'ACTIVE',
        v_s_karthik, 'Karthik Reddy', 'Student', 'Class 10 B',
        v_h_bhb, 'Boys Hostel B', 'B-101',
        'Suresh Electrician', NOW() + INTERVAL '2 days', NOW() - INTERVAL '4 hours'
    );

END $$;
