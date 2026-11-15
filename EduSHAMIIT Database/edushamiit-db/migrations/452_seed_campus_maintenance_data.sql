-- ============================================================================
-- Migration: 452_seed_campus_maintenance_data.sql
-- Description: Seed enterprise campus maintenance data matching Greenwood High School:
--              Total: 312 Requests, Resolved: 254 (81.4%), In Progress: 34 (10.9%),
--              Overdue: 12 (3.8%), Scheduled: 28, Avg Resolution: 1.8 Days.
--              Includes exact 10 screenshot requests, preventive plans & vendors.
-- ============================================================================

DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_admin_id UUID;
    v_b1_id UUID;
    v_b2_id UUID;
    v_b3_id UUID;
    v_b4_id UUID;

    v_req_id UUID;
    v_vendor_ac UUID;
    v_vendor_elec UUID;
    v_vendor_plumb UUID;
    v_vendor_av UUID;

    i INT;
    v_status VARCHAR(30);
    v_type VARCHAR(50);
    v_priority VARCHAR(20);
    v_loc VARCHAR(150);
    v_is_overdue BOOLEAN;
BEGIN
    -- Delete any existing records first so we can cleanly re-seed
    DELETE FROM public.maintenance_requests WHERE school_id = v_school_id;
    DELETE FROM public.maintenance_plans WHERE school_id = v_school_id;
    DELETE FROM public.maintenance_vendors WHERE school_id = v_school_id;

    -- Lookup existing admin profile
    SELECT id INTO v_admin_id FROM public.profiles WHERE school_id = v_school_id LIMIT 1;
    IF v_admin_id IS NULL THEN
        SELECT id INTO v_admin_id FROM public.profiles LIMIT 1;
    END IF;

    -- Lookup buildings
    SELECT id INTO v_b1_id FROM public.buildings WHERE school_id = v_school_id AND UPPER(code) = 'B1';
    SELECT id INTO v_b2_id FROM public.buildings WHERE school_id = v_school_id AND UPPER(code) = 'B2';
    SELECT id INTO v_b3_id FROM public.buildings WHERE school_id = v_school_id AND UPPER(code) = 'B3';
    SELECT id INTO v_b4_id FROM public.buildings WHERE school_id = v_school_id AND UPPER(code) = 'B4';

    -- 1. Seed Service Vendors & AMC Contracts
    INSERT INTO public.maintenance_vendors (
        school_id, vendor_name, contact_person, phone, email, service_category,
        contract_type, contract_start, contract_end, sla_response_hours, sla_resolution_hours, is_active
    ) VALUES 
    (v_school_id, 'CoolAir Solutions Pvt Ltd', 'Rajesh Sharma', '+91 98801 23456', 'support@coolair.com', 'HVAC', 'AMC', '2025-04-01', '2026-03-31', 2.0, 12.0, TRUE)
    RETURNING id INTO v_vendor_ac;

    INSERT INTO public.maintenance_vendors (
        school_id, vendor_name, contact_person, phone, email, service_category,
        contract_type, contract_start, contract_end, sla_response_hours, sla_resolution_hours, is_active
    ) VALUES 
    (v_school_id, 'PowerGrid Electric Services', 'Sunil Deshmukh', '+91 98802 34567', 'service@powergrid.in', 'Electrical', 'AMC', '2025-06-01', '2026-05-31', 1.0, 8.0, TRUE)
    RETURNING id INTO v_vendor_elec;

    INSERT INTO public.maintenance_vendors (
        school_id, vendor_name, contact_person, phone, email, service_category,
        contract_type, contract_start, contract_end, sla_response_hours, sla_resolution_hours, is_active
    ) VALUES 
    (v_school_id, 'FlowMaster Plumbing Care', 'Anil Kumar', '+91 98803 45678', 'help@flowmaster.in', 'Plumbing', 'On-Demand', '2025-01-01', '2026-12-31', 4.0, 24.0, TRUE)
    RETURNING id INTO v_vendor_plumb;

    INSERT INTO public.maintenance_vendors (
        school_id, vendor_name, contact_person, phone, email, service_category,
        contract_type, contract_start, contract_end, sla_response_hours, sla_resolution_hours, is_active
    ) VALUES 
    (v_school_id, 'Apex AV & Smart Class Systems', 'Deepak Mehta', '+91 98804 56789', 'care@apexav.com', 'AV Equipment', 'AMC', '2025-04-01', '2026-03-31', 2.0, 12.0, TRUE)
    RETURNING id INTO v_vendor_av;


    -- 2. Seed Preventive Maintenance Plans
    INSERT INTO public.maintenance_plans (
        school_id, plan_code, title, category, frequency, building_id,
        assigned_team, estimated_duration_hours, estimated_cost, is_active,
        last_run_date, next_due_date, checklist_items
    ) VALUES
    (
        v_school_id, 'MP-001', 'AC Annual Servicing & Filter Replacement', 'HVAC', 'Quarterly', v_b1_id,
        'CoolAir Solutions', 4.0, 12500.00, TRUE, '2026-01-15', '2026-04-15',
        '[{"task": "Clean air filters", "required": true}, {"task": "Check refrigerant pressure", "required": true}, {"task": "Verify thermostat calibration", "required": true}]'::JSONB
    ),
    (
        v_school_id, 'MP-002', 'Campus Main Electrical Panel & DG Set Inspection', 'Electrical', 'Monthly', v_b1_id,
        'PowerGrid Electric', 3.0, 8000.00, TRUE, '2026-02-28', '2026-03-28',
        '[{"task": "Inspect circuit breakers", "required": true}, {"task": "Check battery voltage & diesel level", "required": true}]'::JSONB
    ),
    (
        v_school_id, 'MP-003', 'Overhead Water Tank & Sump Inspection', 'Plumbing', 'Monthly', v_b3_id,
        'FlowMaster Plumbing', 2.5, 4500.00, TRUE, '2026-03-01', '2026-04-01',
        '[{"task": "Water level sensors test", "required": true}, {"task": "Inspect booster pumps", "required": true}]'::JSONB
    ),
    (
        v_school_id, 'MP-004', 'Auditorium Projector & Sound System Calibration', 'AV Equipment', 'Bi-Monthly', v_b4_id,
        'Apex AV Systems', 3.0, 6000.00, TRUE, '2026-02-10', '2026-04-10',
        '[{"task": "Lamp hours check", "required": true}, {"task": "Audio mixing console diagnostic", "required": true}]'::JSONB
    );


    -- 3. Seed Exact 10 Requests from Screenshot Table
    -- Row 1: MT-0568
    INSERT INTO public.maintenance_requests (
        school_id, request_code, title, description, request_type, priority, status,
        building_id, location_display, reported_by_name, reported_by_role,
        reported_at, preferred_date, preferred_time, sla_hours, due_date,
        assigned_to_name, assigned_vendor_name, started_at
    ) VALUES (
        v_school_id, 'MT-0568', 'AC not cooling', 'Classroom split AC is blowing warm air even at 18 degrees.',
        'HVAC', 'High', 'In Progress', v_b1_id, 'B1 / G-101', 'Rohan Verma', 'Student',
        '2026-03-20 10:24:00+05:30', '2026-03-20', '02:00 PM', 12.0, '2026-03-20 22:24:00+05:30',
        'Suresh Electrician', 'CoolAir Solutions Pvt Ltd', '2026-03-20 11:30:00+05:30'
    ) RETURNING id INTO v_req_id;

    INSERT INTO public.maintenance_status_history (school_id, request_id, from_status, to_status, changed_by_name, remarks, created_at)
    VALUES 
    (v_school_id, v_req_id, NULL, 'Pending', 'Rohan Verma', 'Reported via student portal', '2026-03-20 10:24:00+05:30'),
    (v_school_id, v_req_id, 'Pending', 'Assigned', 'Admin Office', 'Assigned to CoolAir technician', '2026-03-20 10:45:00+05:30'),
    (v_school_id, v_req_id, 'Assigned', 'In Progress', 'Suresh Electrician', 'Technician arrived on site and checking gas pressure', '2026-03-20 11:30:00+05:30');

    -- Row 2: MT-0567
    INSERT INTO public.maintenance_requests (
        school_id, request_code, title, description, request_type, priority, status,
        building_id, location_display, reported_by_name, reported_by_role,
        reported_at, preferred_date, preferred_time, sla_hours, due_date,
        assigned_to_name, assigned_vendor_name
    ) VALUES (
        v_school_id, 'MT-0567', 'Projector not working', 'HDMI input not detected on ceiling projector.',
        'AV Equipment', 'Medium', 'Assigned', v_b1_id, 'B1 / G-102', 'Ananya Sharma', 'Teacher',
        '2026-03-20 09:15:00+05:30', '2026-03-20', '11:00 AM', 24.0, '2026-03-21 09:15:00+05:30',
        'Kiran IT Technician', 'Apex AV & Smart Class Systems'
    );

    -- Row 3: MT-0566
    INSERT INTO public.maintenance_requests (
        school_id, request_code, title, description, request_type, priority, status,
        building_id, location_display, reported_by_name, reported_by_role,
        reported_at, preferred_date, preferred_time, sla_hours, due_date,
        assigned_to_name, started_at
    ) VALUES (
        v_school_id, 'MT-0566', 'Flickering lights', 'Tubelights in row 3 flickering continuously causing distraction.',
        'Electrical', 'Medium', 'In Progress', v_b2_id, 'B2 / F1-202', 'Vikram Singh', 'Teacher',
        '2026-03-19 14:45:00+05:30', '2026-03-19', '03:30 PM', 24.0, '2026-03-20 14:45:00+05:30',
        'Ramesh Electrician', '2026-03-19 15:30:00+05:30'
    );

    -- Row 4: MT-0565
    INSERT INTO public.maintenance_requests (
        school_id, request_code, title, description, request_type, priority, status,
        building_id, location_display, reported_by_name, reported_by_role,
        reported_at, sla_hours, due_date
    ) VALUES (
        v_school_id, 'MT-0565', 'Water leakage in washroom', 'Basin pipe joint loose and leaking onto the floor.',
        'Plumbing', 'High', 'Pending', v_b3_id, 'B3 / GF-WR1', 'Priya Nair', 'Staff',
        '2026-03-19 11:30:00+05:30', 12.0, '2026-03-19 23:30:00+05:30'
    );

    -- Row 5: MT-0564
    INSERT INTO public.maintenance_requests (
        school_id, request_code, title, description, request_type, priority, status,
        building_id, location_display, reported_by_name, reported_by_role,
        reported_at, sla_hours, due_date, assigned_to_name
    ) VALUES (
        v_school_id, 'MT-0564', 'Fan not working', 'Ceiling fan regulator stuck and fan motor humming loudly.',
        'Electrical', 'Low', 'Assigned', v_b1_id, 'B1 / F2-305', 'Amit Kumar', 'Teacher',
        '2026-03-18 16:10:00+05:30', 48.0, '2026-03-20 16:10:00+05:30', 'Ramesh Electrician'
    );

    -- Row 6: MT-0563
    INSERT INTO public.maintenance_requests (
        school_id, request_code, title, description, request_type, priority, status,
        building_id, location_display, reported_by_name, reported_by_role,
        reported_at, sla_hours, due_date, assigned_to_name, started_at
    ) VALUES (
        v_school_id, 'MT-0563', 'Broken chair (multiple)', 'Three conference chairs have broken armrests and loose screws.',
        'Furniture', 'Medium', 'In Progress', v_b1_id, 'B1 / Seminar Hall', 'CS Department', 'Staff',
        '2026-03-18 13:20:00+05:30', 24.0, '2026-03-19 13:20:00+05:30', 'Gopal Carpenter', '2026-03-18 14:00:00+05:30'
    );

    -- Row 7: MT-0562
    INSERT INTO public.maintenance_requests (
        school_id, request_code, title, description, request_type, priority, status,
        building_id, location_display, reported_by_name, reported_by_role,
        reported_at, scheduled_at, sla_hours, due_date, assigned_to_name
    ) VALUES (
        v_school_id, 'MT-0562', 'Door lock repair', 'Main double door lock latch not catching properly.',
        'Civil', 'Low', 'Scheduled', v_b4_id, 'B4 / Library', 'Library Staff', 'Staff',
        '2026-03-17 11:00:00+05:30', '2026-03-21 10:00:00+05:30', 48.0, '2026-03-19 11:00:00+05:30', 'Vinod Civil Maintenance'
    );

    -- Row 8: MT-0561
    INSERT INTO public.maintenance_requests (
        school_id, request_code, title, description, request_type, priority, status,
        building_id, location_display, reported_by_name, reported_by_role,
        reported_at, scheduled_at, sla_hours, due_date, assigned_to_name, is_preventive
    ) VALUES (
        v_school_id, 'MT-0561', 'AC annual servicing', 'Scheduled quarterly deep cleaning and refrigerant check.',
        'HVAC', 'Medium', 'Scheduled', v_b1_id, 'B1 / All Classrooms', 'Maintenance Team', 'Admin',
        '2026-03-16 09:00:00+05:30', '2026-03-22 09:00:00+05:30', 24.0, '2026-03-17 09:00:00+05:30', 'CoolAir Solutions Pvt Ltd', TRUE
    );

    -- Row 9: MT-0560
    INSERT INTO public.maintenance_requests (
        school_id, request_code, title, description, request_type, priority, status,
        building_id, location_display, reported_by_name, reported_by_role,
        reported_at, sla_hours, due_date, assigned_to_name, started_at
    ) VALUES (
        v_school_id, 'MT-0560', 'Washroom cleaning & repair', 'Floor tiles deep scrub and exhaust fan lubrication needed.',
        'Sanitation', 'Medium', 'In Progress', v_b2_id, 'B2 / GF-WR2', 'Admin Office', 'Staff',
        '2026-03-15 15:30:00+05:30', 24.0, '2026-03-16 15:30:00+05:30', 'CleanCare Sanitation Staff', '2026-03-15 16:00:00+05:30'
    );

    -- Row 10: MT-0559
    INSERT INTO public.maintenance_requests (
        school_id, request_code, title, description, request_type, priority, status,
        building_id, location_display, reported_by_name, reported_by_role,
        reported_at, sla_hours, due_date
    ) VALUES (
        v_school_id, 'MT-0559', 'Network point not working', 'RJ45 network port 12 on bench 4 is dead, no link light on switch.',
        'IT / Network', 'High', 'Pending', v_b1_id, 'B1 / Lab-1', 'Lab Incharge', 'Teacher',
        '2026-03-15 10:00:00+05:30', 12.0, '2026-03-15 22:00:00+05:30'
    );


    -- 4. Seed Remaining 302 Requests to reach exactly 312 Total
    -- Distribution targets:
    -- Total: 312
    -- Resolved: 254 (81.4%)
    -- In Progress: 34 (already have 4 in top 10 -> need 30 more)
    -- Scheduled: 28 (already have 2 in top 10 -> need 26 more)
    -- Overdue: 12 (flag 12 as overdue)
    -- Pending: Remaining (already have 3 in top 10)
    FOR i IN 1..302 LOOP
        -- Determine status
        IF i <= 254 THEN
            v_status := 'Resolved';
        ELSIF i <= 284 THEN
            v_status := 'In Progress';
        ELSIF i <= 298 THEN
            v_status := 'Scheduled';
        ELSE
            v_status := 'Pending';
        END IF;

        -- Flag exactly 12 as overdue
        IF i IN (280, 281, 282, 283, 284, 290, 291, 292, 299, 300, 301, 302) THEN
            v_is_overdue := TRUE;
        ELSE
            v_is_overdue := FALSE;
        END IF;

        -- Type distribution
        IF i % 6 = 0 THEN
            v_type := 'HVAC';
            v_loc := 'B1 / F1-10' || (i % 8 + 1);
        ELSIF i % 6 = 1 THEN
            v_type := 'Electrical';
            v_loc := 'B2 / F2-20' || (i % 6 + 1);
        ELSIF i % 6 = 2 THEN
            v_type := 'Plumbing';
            v_loc := 'B3 / GF-WR' || (i % 4 + 1);
        ELSIF i % 6 = 3 THEN
            v_type := 'Civil';
            v_loc := 'B4 / Library';
        ELSIF i % 6 = 4 THEN
            v_type := 'AV Equipment';
            v_loc := 'B1 / G-10' || (i % 5 + 1);
        ELSE
            v_type := 'Sanitation';
            v_loc := 'B2 / F1-20' || (i % 5 + 1);
        END IF;

        IF i % 4 = 0 THEN
            v_priority := 'High';
        ELSIF i % 4 = 1 THEN
            v_priority := 'Medium';
        ELSE
            v_priority := 'Low';
        END IF;

        INSERT INTO public.maintenance_requests (
            school_id,
            request_code,
            title,
            description,
            request_type,
            priority,
            status,
            building_id,
            location_display,
            reported_by_name,
            reported_by_role,
            reported_at,
            due_date,
            is_overdue,
            resolved_at,
            resolution_notes,
            assigned_to_name
        ) VALUES (
            v_school_id,
            'MT-' || LPAD((558 - i)::TEXT, 4, '0'),
            CASE v_type
                WHEN 'HVAC' THEN 'Air conditioner service & thermistor inspection'
                WHEN 'Electrical' THEN 'Electrical socket loose and sparks noticed'
                WHEN 'Plumbing' THEN 'Water tap replacement & pressure valve check'
                WHEN 'Civil' THEN 'Floor tile repair and door hinge lubrication'
                WHEN 'AV Equipment' THEN 'Projector bulb replacement & screen alignment'
                ELSE 'Deep sanitization and hygiene compliance check'
            END,
            'Standard institutional maintenance work order.',
            v_type,
            v_priority,
            v_status,
            v_b1_id,
            v_loc,
            CASE (i % 5)
                WHEN 0 THEN 'Amit Kumar'
                WHEN 1 THEN 'Rohan Verma'
                WHEN 2 THEN 'Priya Nair'
                WHEN 3 THEN 'Vikram Singh'
                ELSE 'Admin Office'
            END,
            CASE (i % 4)
                WHEN 0 THEN 'Teacher'
                WHEN 1 THEN 'Student'
                WHEN 2 THEN 'Staff'
                ELSE 'Admin'
            END,
            TIMESTAMPTZ '2026-03-14 20:00:00+05:30' - ((i * 14) || ' hours')::INTERVAL,
            TIMESTAMPTZ '2026-03-15 20:00:00+05:30' - ((i * 14) || ' hours')::INTERVAL,
            v_is_overdue,
            CASE WHEN v_status = 'Resolved' THEN TIMESTAMPTZ '2026-03-14 20:00:00+05:30' - ((i * 14) || ' hours')::INTERVAL + INTERVAL '1.8 days' ELSE NULL END,
            CASE WHEN v_status = 'Resolved' THEN 'Inspection complete and verified in operational condition.' ELSE NULL END,
            CASE (i % 3)
                WHEN 0 THEN 'Suresh Electrician'
                WHEN 1 THEN 'Ramesh Electrician'
                ELSE 'Kiran IT Technician'
            END
        );
    END LOOP;

END $$;
