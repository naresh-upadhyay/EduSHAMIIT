-- ============================================================================
-- Migration: 455_seed_safety_compliance_data.sql
-- Description: Realistic Seed Data for Safety & Statutory Compliance
--              for Greenwood High School (school_id: 11111111-1111-1111-1111-111111111111).
-- ============================================================================

DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_b1 UUID;
    v_b2 UUID;
    v_b3 UUID;
    v_b4 UUID;
    v_b5 UUID;
    v_b6 UUID;
BEGIN
    SELECT id INTO v_b1 FROM public.buildings WHERE school_id = v_school_id AND code = 'B1' LIMIT 1;
    SELECT id INTO v_b2 FROM public.buildings WHERE school_id = v_school_id AND code = 'B2' LIMIT 1;
    SELECT id INTO v_b3 FROM public.buildings WHERE school_id = v_school_id AND code = 'B3' LIMIT 1;
    SELECT id INTO v_b4 FROM public.buildings WHERE school_id = v_school_id AND code = 'B4' LIMIT 1;
    SELECT id INTO v_b5 FROM public.buildings WHERE school_id = v_school_id AND code = 'B5' LIMIT 1;
    SELECT id INTO v_b6 FROM public.buildings WHERE school_id = v_school_id AND code = 'B6' LIMIT 1;

    -- 1. Statutory Compliance Certificates
    INSERT INTO public.compliance_certificates (
        school_id, certificate_code, title, category, issuing_authority,
        certificate_number, building_id, location_display, issue_date, expiry_date, status, notes
    ) VALUES
    (v_school_id, 'CERT-FIRE-2026', 'Fire Safety No Objection Certificate (Fire NOC)', 'Fire Safety', 'State Fire & Emergency Services', 'FS-NOC/DL/2025/9041', v_b1, 'Campus-wide (All Blocks)', '2025-04-10', '2026-04-09', 'Valid', 'Annual fire pump, riser, and smoke detector inspection completed.'),
    (v_school_id, 'CERT-STRUC-2026', 'Structural Stability Certificate', 'Building Stability', 'Municipal Corporation Civil Engineering Wing', 'PWD/STRUC/2024/1108', v_b1, 'B1 - Academic Block', '2024-06-15', '2027-06-14', 'Valid', '3-year triennial structural load certification.'),
    (v_school_id, 'CERT-WATER-2026', 'Potable Drinking Water Quality & Chlorination Certificate', 'Water Quality', 'District Public Health Engineering Lab', 'PHED/LAB/2026/0321', v_b5, 'Utility Block / Overhead Tanks', '2026-01-15', '2026-04-14', 'Expiring Soon', 'Bacteriological and TDS lab test report valid for 90 days. Renewal test sample due.'),
    (v_school_id, 'CERT-LIFT-01', 'Passenger Elevator Fitness & Safety License', 'Elevator & Lift Fitness', 'Department of Labour & Boiler Inspection', 'LIFT-INSP-2025-78A', v_b1, 'B1 - Academic Block (Lift A & B)', '2025-09-01', '2026-08-31', 'Valid', 'Quarterly load drop brake test verified by Otis.'),
    (v_school_id, 'CERT-ELEC-2026', 'Electrical Substation & Transformer Clearance NOC', 'Electrical Safety', 'State Electricity Regulatory Commission', 'DISCOM/SUB/2025/441', v_b5, 'Utility Block (Substation & DG)', '2025-07-20', '2026-07-19', 'Valid', 'Earthing pit resistance within 1.2 Ohms (compliant).'),
    (v_school_id, 'CERT-SAN-2026', 'School Sanitation & Hygiene Certificate', 'Sanitation & Hygiene', 'Chief Medical Officer (CMO) Health Dept', 'HEALTH/SCH/2025/890', NULL, 'Entire Campus Grounds', '2025-08-10', '2026-08-09', 'Valid', 'Comprehensive washroom hygiene and pest control certification.'),
    (v_school_id, 'CERT-ENV-2026', 'Pollution Control & Green Campus NOC', 'Pollution / Environmental NOC', 'State Pollution Control Board', 'SPCB/AIR-WATER/2025/112', NULL, 'Entire Campus Grounds', '2025-05-18', '2026-05-17', 'Expiring Soon', 'Rainwater harvesting and compost pit verification report.'),
    (v_school_id, 'CERT-LIFT-02', 'Hostel Passenger Elevator Safety License', 'Elevator & Lift Fitness', 'Department of Labour & Boiler Inspection', 'LIFT-INSP-2025-99B', v_b2, 'B2 - Senior Block', '2025-10-15', '2026-10-14', 'Valid', '6-monthly cable and governor test passed.')
    ON CONFLICT (school_id, certificate_code) DO NOTHING;

    -- 2. Safety Inspections
    INSERT INTO public.safety_inspections (
        school_id, inspection_code, title, category, building_id,
        location_display, inspector_name, inspector_role, inspection_date,
        status, compliance_score, findings, action_items, next_inspection_date
    ) VALUES
    (v_school_id, 'SI-2026-001', 'Campus-Wide Fire Extinguisher Pressure & Seal Audit', 'Fire Safety', v_b1, 'Academic Block / All Floors', 'Capt. Rajesh Varma', 'Fire Marshal', '2026-03-05', 'Passed', 98.0, 'All 48 ABC powder extinguishers pressurized and tagged properly.', '[]'::JSONB, '2026-06-05'),
    (v_school_id, 'SI-2026-002', 'Chemistry & Biology Lab Fume Hoods & Eye-Wash Audit', 'Lab & Chemical Safety', v_b1, 'Science Block / F1-102 & F1-103', 'Dr. Anand Kelkar', 'External Auditor', '2026-03-02', 'Needs Attention', 88.5, 'Secondary emergency eyewash station in Chem Lab 103 has reduced water pressure.', '[{"item":"Replace nozzle on eyewash station in Chem Lab","priority":"High"}]'::JSONB, '2026-03-25'),
    (v_school_id, 'SI-2026-003', 'Campus CCTV Coverage & DVR Recording Verification', 'CCTV & Physical Security', v_b5, 'Admin Block / Security Control Room', 'Vikramaditya Rao', 'Safety Officer', '2026-03-10', 'Passed', 96.0, 'All 124 perimeter and corridor cameras active with 30-day loop recording.', '[]'::JSONB, '2026-04-10'),
    (v_school_id, 'SI-2026-004', 'Electrical Distribution Boards & MCB Thermal Scan', 'Electrical Safety', v_b1, 'Academic Block / Ground Floor Main Panel', 'Deepak Verma', 'Senior Electrical Engineer', '2026-02-24', 'Passed', 94.0, 'Thermal infrared imaging showed normal operating temperatures below 42C across all busbars.', '[]'::JSONB, '2026-05-24'),
    (v_school_id, 'SI-2026-005', 'Sports Ground & Gymnasium Equipment Safety Check', 'Sports & Playground', v_b6, 'B6 - Sports Complex', 'Sunil Gavaskar K', 'Physical Education Incharge', '2026-03-08', 'Passed', 95.0, 'Goalpost anchors, basketball backboards, and gymnastics mats checked and secured.', '[]'::JSONB, '2026-04-08'),
    (v_school_id, 'SI-2026-006', 'Hostel Mess & Cafeteria Hygiene & Food Safety Audit', 'Food & Water Safety', v_b2, 'B2 - Senior Block / Mess Hall', 'Pooja Chhabra', 'FSSAI Certified Food Inspector', '2026-03-01', 'Passed', 97.5, 'Dry storage pest-free; refrigeration holding at 3.5C; food handlers wearing hairnets and gloves.', '[]'::JSONB, '2026-04-01')
    ON CONFLICT (school_id, inspection_code) DO NOTHING;

    -- 3. Safety Incidents
    INSERT INTO public.safety_incidents (
        school_id, incident_code, title, severity, incident_type,
        building_id, location_display, reported_by_name, reported_by_role,
        incident_time, status, description, immediate_action_taken, preventive_measures,
        victims_count, first_aid_provided, resolved_at, resolved_by_name
    ) VALUES
    (v_school_id, 'INC-2026-001', 'Minor Acid Splash on Hand during Titration Experiment', 'Medium', 'Lab Incident', v_b1, 'B1 / F1-103 Chemistry Lab', 'Dr. Anand Kelkar', 'Teacher', '2026-03-04 11:20:00+05:30', 'Resolved', 'Student had 5ml dilute HCl splash on left forearm while transferring beaker.', 'Immediate neutralisation with running cold water at eyewash sink and silver sulfadiazine ointment application.', 'Mandatory use of rubber lab gauntlets during all acid handling sessions.', 1, TRUE, '2026-03-04 12:00:00+05:30', 'Campus Medical Officer Dr. Sen'),
    (v_school_id, 'INC-2026-002', 'Slip and Ankle Sprain on Wet Staircase during Heavy Rain', 'Low', 'Slip, Trip & Fall', v_b1, 'Academic Block / Staircase West', 'Rohan Verma', 'Student', '2026-03-07 13:45:00+05:30', 'Resolved', 'Student slipped on rainwater tracked onto marble stairs from courtyard.', 'First aid ice pack applied; student taken to infirmary; crepe bandage secured.', 'Installed heavy duty anti-slip rubber treads on all exterior staircases.', 1, TRUE, '2026-03-07 14:30:00+05:30', 'Nurse Sarita'),
    (v_school_id, 'INC-2026-003', 'False Smoke Alarm Trigger in Physics Lab (Dust Ingress)', 'Low', 'Fire Alarm Trigger', v_b1, 'Academic Block / F1-102 Physics Lab', 'Security Desk', 'Staff', '2026-03-11 09:15:00+05:30', 'Resolved', 'Optical smoke detector triggered during ceiling fan dusting by cleaning staff.', 'Security inspected zone within 90 seconds, verified no fire, and reset panel.', 'Dust covers placed over optical detectors during deep cleaning operations.', 0, FALSE, '2026-03-11 09:30:00+05:30', 'Chief Warden Sharma'),
    (v_school_id, 'INC-2026-004', 'Broken Glass Pane on Window due to High Wind', 'Medium', 'Equipment Damage', v_b3, 'B3 - Library Block / Reading Room', 'Librarian Ghosh', 'Staff', '2026-03-09 16:10:00+05:30', 'Resolved', 'Wind gust caused unlatched upper casement window pane to crack.', 'Area cordoned off immediately; shards cleaned by janitorial team; pane replaced.', 'Fitted mechanical safety stays on all large casement windows.', 0, FALSE, '2026-03-10 11:00:00+05:30', 'Facilities Head')
    ON CONFLICT (school_id, incident_code) DO NOTHING;

    -- 4. Emergency Evacuation Drills
    INSERT INTO public.safety_drills (
        school_id, drill_code, title, drill_type, location_display,
        scheduled_date, conducted_date, status, participants_count,
        evacuation_time_seconds, target_time_seconds, coordinator_name,
        performance_rating, observations
    ) VALUES
    (v_school_id, 'DRL-2026-01', 'Annual Campus Mega Fire Evacuation Simulation', 'Fire Evacuation', 'All Campus Blocks (Assembly Area: Central Turf)', '2026-02-18', '2026-02-18', 'Completed', 1420, 138, 180, 'Capt. Rajesh Varma', 'Excellent', 'All 1420 students and staff evacuated to football turf assembly points within 2 min 18 sec. Roll call completed in 4 mins.'),
    (v_school_id, 'DRL-2026-02', 'High-Rise Hostel Emergency Night Evacuation Drill', 'Fire Evacuation', 'B2 - Senior Block / Hostel Wings', '2026-01-22', '2026-01-22', 'Completed', 380, 154, 180, 'Hostel Warden Singh', 'Good', 'Staircase lighting functioned on emergency inverter battery. Warden verified room clearance.'),
    (v_school_id, 'DRL-2026-03', 'Science Wing Chemical Emergency & Containment Drill', 'Chemical Spill Protocol', 'Science Labs / 1st & 2nd Floors', '2026-03-28', NULL, 'Scheduled', 120, 0, 120, 'Dr. Anand Kelkar', 'Good', 'Upcoming simulation with municipal HazMat advisory.')
    ON CONFLICT (school_id, drill_code) DO NOTHING;

END $$;
