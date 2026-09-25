-- Migration: 354_seed_hr_training_and_learning.sql
-- Description: Realistic Seed Data for Greenfield International School matching the Training & Learning UI screenshot

DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_admin_id UUID := '38a93170-997b-4b4c-bc8e-256b93169c23';
    
    -- Category IDs
    v_cat_compliance UUID := gen_random_uuid();
    v_cat_prof_dev UUID := gen_random_uuid();
    v_cat_tech UUID := gen_random_uuid();
    v_cat_soft_skills UUID := gen_random_uuid();
    v_cat_safety UUID := gen_random_uuid();
    v_cat_leadership UUID := gen_random_uuid();
    
    -- Program IDs
    v_prog_excel UUID := gen_random_uuid();
    v_prog_psychology UUID := gen_random_uuid();
    v_prog_digital_mkt UUID := gen_random_uuid();
    v_prog_classroom UUID := gen_random_uuid();
    v_prog_cyber UUID := gen_random_uuid();
    v_prog_child_safety UUID := gen_random_uuid();
    v_prog_stem UUID := gen_random_uuid();
    v_prog_first_aid UUID := gen_random_uuid();
    v_prog_smart_tools UUID := gen_random_uuid();
    v_prog_communication UUID := gen_random_uuid();

    -- Learning Path IDs
    v_path_leadership UUID := gen_random_uuid();
    v_path_digital UUID := gen_random_uuid();
    v_path_teaching UUID := gen_random_uuid();
    v_path_soft_skills UUID := gen_random_uuid();
    v_path_compliance UUID := gen_random_uuid();

    -- Session IDs
    v_sess_1 UUID := gen_random_uuid();
    v_sess_2 UUID := gen_random_uuid();
    v_sess_3 UUID := gen_random_uuid();
    v_sess_4 UUID := gen_random_uuid();
    v_sess_5 UUID := gen_random_uuid();

    -- Top Employee IDs
    v_emp_ananya UUID := 'c14db11e-d97e-4108-9560-8e3443991121';
    v_emp_rahul UUID := '49b84281-888c-4c4d-ad9e-367c04270d34';
    v_emp_neha UUID := 'e22e3344-5566-7788-99aa-bbccddeeff00';
    v_emp_vikram UUID := 'f33f4455-6677-8899-aabb-ccddeeff0011';
    v_emp_pooja UUID := 'a44a5566-7788-99aa-bbcc-ddeeff001122';
    v_emp_amit UUID := 'b55b6677-8899-aabb-ccdd-eeff00112233';

BEGIN
    -- Clear previous seed if re-running
    DELETE FROM public.hr_training_activity WHERE school_id = v_school_id;
    DELETE FROM public.hr_training_feedback WHERE school_id = v_school_id;
    DELETE FROM public.hr_training_certificates WHERE school_id = v_school_id;
    DELETE FROM public.hr_training_attendance WHERE school_id = v_school_id;
    DELETE FROM public.hr_training_enrollments WHERE school_id = v_school_id;
    DELETE FROM public.hr_training_sessions WHERE school_id = v_school_id;
    DELETE FROM public.hr_training_learning_path_courses WHERE learning_path_id IN (SELECT id FROM public.hr_training_learning_paths WHERE school_id = v_school_id);
    DELETE FROM public.hr_training_learning_paths WHERE school_id = v_school_id;
    DELETE FROM public.hr_training_materials WHERE school_id = v_school_id;
    DELETE FROM public.hr_training_skill_gaps WHERE school_id = v_school_id;
    DELETE FROM public.hr_training_programs WHERE school_id = v_school_id;
    DELETE FROM public.hr_training_categories WHERE school_id = v_school_id;

    -- 1. Dynamic Training Categories
    INSERT INTO public.hr_training_categories (id, school_id, name, code, description, icon, color_hex, is_system, created_by) VALUES
    (v_cat_compliance, v_school_id, 'Compliance & Regulatory', 'COMPLIANCE', 'Mandatory safety, POSH, POCSO, and statutory school policies.', 'shield_outlined', '#EF4444', TRUE, v_admin_id),
    (v_cat_prof_dev, v_school_id, 'Professional Development', 'PROF_DEV', 'Teaching competency, NEP frameworks, and instructional pedagogy.', 'school_outlined', '#4F46E5', TRUE, v_admin_id),
    (v_cat_tech, v_school_id, 'Digital & Technology', 'TECH', 'ERP software, smart panels, AI tools, and IT cybersecurity.', 'devices_outlined', '#0284C7', TRUE, v_admin_id),
    (v_cat_soft_skills, v_school_id, 'Soft Skills & Communication', 'SOFT_SKILLS', 'Parent handling, empathetic communication, and conflict resolution.', 'chat_bubble_outline', '#EC4899', TRUE, v_admin_id),
    (v_cat_safety, v_school_id, 'Health, Safety & Medical', 'SAFETY', 'First aid, emergency response, fire safety, and transport safety.', 'favorite_border', '#10B981', TRUE, v_admin_id),
    (v_cat_leadership, v_school_id, 'Leadership & Management', 'LEADERSHIP', 'Department leadership, team coaching, and institution governance.', 'workspace_premium_outlined', '#F59E0B', TRUE, v_admin_id);

    -- 2. Structured Learning Paths (Matching Screenshot 5 Cards)
    INSERT INTO public.hr_training_learning_paths (id, school_id, title, subtitle, icon, color_hex, target_audience, total_courses, completed_courses, progress_percentage, enrolled_count, status, created_by) VALUES
    (v_path_leadership, v_school_id, 'Leadership Development Program', 'For teaching & non-teaching staff', 'groups_outlined', '#4F46E5', 'HODs and Supervisors', 20, 15, 75, 20, 'ACTIVE', v_admin_id),
    (v_path_digital, v_school_id, 'Digital Skills & Technology', 'Tools for modern education', 'laptop_mac_outlined', '#0284C7', 'All Academic Staff', 20, 12, 60, 20, 'ACTIVE', v_admin_id),
    (v_path_teaching, v_school_id, 'Teaching Excellence', 'Better teaching, better learning', 'psychology_outlined', '#10B981', 'Teachers & Assistants', 20, 18, 90, 20, 'ACTIVE', v_admin_id),
    (v_path_soft_skills, v_school_id, 'Soft Skills & Communication', 'Build better relationships', 'forum_outlined', '#EC4899', 'Front Office & Educators', 20, 9, 45, 20, 'ACTIVE', v_admin_id),
    (v_path_compliance, v_school_id, 'Compliance & Safety', 'Policies, safety & regulations', 'verified_user_outlined', '#F59E0B', 'All Employees', 20, 6, 30, 20, 'ACTIVE', v_admin_id);

    -- 3. Training Programs & Courses (Total 28 programs)
    -- Programs 1 to 5: Exactly as shown in the Screenshot Primary Table
    INSERT INTO public.hr_training_programs (
        id, school_id, program_code, title, category_id, category_name, training_type, description,
        is_mandatory, trainer_type, trainer_name, provider_name, target_audience, mode, location_or_link,
        start_date, end_date, start_time, end_time, duration_hours, duration_display, capacity,
        enrolled_count, completed_count, completion_rate, assessment_type, has_certificate, status, budget_cost
    ) VALUES
    (
        v_prog_excel, v_school_id, 'TRN-ADM-001', 'Advanced Excel', v_cat_tech, 'Digital & Technology',
        'Technical', 'Advanced spreadsheet modeling, pivot tables, and statistical formula training for institutional administration.',
        FALSE, 'Internal', 'Rohan Mehta', 'Greenfield IT Academy', 'Administration', 'Online',
        'https://meet.google.com/xyz-excel-trn', '2026-05-16', '2026-05-16', '10:00:00', '12:00:00',
        2.0, '2 Hours', 25, 18, 18, 100.0, 'Quiz', TRUE, 'COMPLETED', 15000.00
    ),
    (
        v_prog_psychology, v_school_id, 'TRN-TCH-002', 'Child Psychology', v_cat_prof_dev, 'Professional Development',
        'Professional Development', 'Understanding child developmental stages, classroom behavioral cues, and positive reinforcement.',
        FALSE, 'External', 'Dr. Priya Sen', 'Child Mind Institute India', 'Teaching', 'Workshop',
        'Seminar Hall A, Senior Block', '2026-05-17', '2026-05-17', '09:00:00', '17:00:00',
        8.0, '1 Day', 30, 24, 16, 66.7, 'Evaluation', TRUE, 'IN_PROGRESS', 35000.00
    ),
    (
        v_prog_digital_mkt, v_school_id, 'TRN-ADM-003', 'Digital Marketing Basics', v_cat_tech, 'Digital & Technology',
        'Professional Development', 'Social media best practices, campus event broadcasting, and modern institutional branding techniques.',
        FALSE, 'External', 'Amit Sharma', 'EdTech Growth Lab', 'Administration', 'Online',
        'https://meet.google.com/mkt-brand-live', '2026-05-19', '2026-05-19', '11:00:00', '14:00:00',
        3.0, '3 Hours', 20, 12, 12, 100.0, 'None', TRUE, 'COMPLETED', 20000.00
    ),
    (
        v_prog_classroom, v_school_id, 'TRN-TCH-004', 'Classroom Management', v_cat_prof_dev, 'Professional Development',
        'Professional Development', 'Empowering educators with proactive classroom management, student engagement, and conflict diffusion.',
        FALSE, 'Internal', 'Priya Singh', 'Senior Academic Council', 'Teaching', 'Workshop',
        'Auditorium B, Campus South', '2026-05-17', '2026-05-17', '14:00:00', '16:00:00',
        2.0, '1 Day', 25, 20, 0, 0.0, 'Assignment', TRUE, 'SCHEDULED', 18000.00
    ),
    (
        v_prog_cyber, v_school_id, 'TRN-SEC-005', 'Cybersecurity Awareness', v_cat_tech, 'Digital & Technology',
        'Compliance', 'Safeguarding student records, phishing defense, zero-trust password policies, and data privacy regulations.',
        TRUE, 'Internal', 'Neha Gupta', 'Greenfield IT & Security Cell', 'IT & Support', 'Online',
        'https://meet.google.com/sec-cyber-aware', '2026-05-21', '2026-05-21', '15:00:00', '17:00:00',
        2.0, '2 Hours', 20, 15, 0, 0.0, 'Quiz', TRUE, 'UPCOMING', 12000.00
    ),
    -- Programs 6 to 10: High-profile mandatory and specialized trainings
    (
        v_prog_child_safety, v_school_id, 'TRN-CMP-006', 'Child Safety & Safeguarding', v_cat_compliance, 'Compliance & Regulatory',
        'Compliance', 'Mandatory statutory compliance on POCSO, child protection, mental health safety, and mandatory reporting.',
        TRUE, 'Internal', 'HR & Child Welfare Committee', 'Greenfield Compliance Cell', 'All Staff', 'Offline',
        'Main Campus Auditorium', '2026-05-10', '2026-05-10', '09:00:00', '13:00:00',
        4.0, '4 Hours', 200, 186, 186, 100.0, 'Evaluation', TRUE, 'COMPLETED', 50000.00
    ),
    (
        v_prog_stem, v_school_id, 'TRN-TCH-007', 'Teaching Excellence in STEM', v_cat_prof_dev, 'Professional Development',
        'Professional Development', 'Hands-on experimental learning, robotic kits, and inquiry-based STEM pedagogical methods.',
        FALSE, 'External', 'Dr. Vikram Patel', 'National STEM Foundation', 'Academics', 'Hybrid',
        'Science Innovation Lab', '2026-05-24', '2026-05-25', '10:00:00', '16:00:00',
        16.0, '2 Days', 40, 32, 32, 100.0, 'Quiz', TRUE, 'COMPLETED', 60000.00
    ),
    (
        v_prog_first_aid, v_school_id, 'TRN-SFT-008', 'First Aid & Emergency Response', v_cat_safety, 'Health, Safety & Medical',
        'Safety', 'CPR certification, trauma management, burn care, and defibrillator usage on campus.',
        TRUE, 'External', 'St. John Ambulance Care', 'Red Cross & St. John', 'Support Staff', 'Offline',
        'Medical Infirmary Ground Floor', '2026-05-12', '2026-05-12', '09:00:00', '15:00:00',
        6.0, '6 Hours', 50, 42, 42, 100.0, 'Evaluation', TRUE, 'COMPLETED', 45000.00
    ),
    (
        v_prog_smart_tools, v_school_id, 'TRN-TCH-009', 'Smart Classroom Tools', v_cat_tech, 'Digital & Technology',
        'Technical', 'Interactive smart board features, digital stylus annotations, screen casting, and hybrid streaming.',
        FALSE, 'Internal', 'Vikram Patel', 'IT Dept', 'Teaching', 'Offline',
        'Digital Lab 3', '2026-05-24', '2026-05-24', '10:00:00', '12:00:00',
        2.0, '2 Hours', 30, 28, 0, 0.0, 'None', TRUE, 'UPCOMING', 15000.00
    ),
    (
        v_prog_communication, v_school_id, 'TRN-COM-010', 'Effective Communication Skills', v_cat_soft_skills, 'Soft Skills & Communication',
        'Soft Skills', 'Empathetic listening, constructive parent meetings, positive educator feedback, and de-escalation techniques.',
        FALSE, 'Internal', 'Amit Sharma', 'HR Development Cell', 'All Staff', 'Hybrid',
        'Conference Hall 2', '2026-05-19', '2026-05-19', '11:00:00', '13:00:00',
        2.0, '2 Hours', 40, 35, 0, 0.0, 'Quiz', TRUE, 'SCHEDULED', 22000.00
    );

    -- Additional 18 programs to reach exactly 28 programs (22 completed, 5 in progress, 1 upcoming)
    FOR i IN 11..28 LOOP
        INSERT INTO public.hr_training_programs (
            school_id, program_code, title, category_id, category_name, training_type, description,
            is_mandatory, trainer_type, trainer_name, provider_name, target_audience, mode,
            start_date, end_date, start_time, end_time, duration_hours, duration_display, capacity,
            enrolled_count, completed_count, completion_rate, assessment_type, has_certificate, status, budget_cost
        ) VALUES (
            v_school_id,
            'TRN-GEN-' || LPAD(i::text, 3, '0'),
            CASE i
                WHEN 11 THEN 'POSH & Workplace Dignity Workshop'
                WHEN 12 THEN 'NEP 2020 Holistic Assessment Framework'
                WHEN 13 THEN 'Defensive Driving for School Bus Staff'
                WHEN 14 THEN 'AI Assisted Curriculum Planning'
                WHEN 15 THEN 'Inclusive Education for Diverse Learners'
                WHEN 16 THEN 'Annual Fire Drill & Hazard Containment'
                WHEN 17 THEN 'Financial ERP Operations & Ledger Audit'
                WHEN 18 THEN 'Student Mental Health & Emotional First Aid'
                WHEN 19 THEN 'Biohazard Waste & Chemical Lab Safety'
                WHEN 20 THEN 'Digital Library Circulation & Koha Software'
                WHEN 21 THEN 'Formative Rubrics & Feedback Mechanisms'
                WHEN 22 THEN 'Institutional Conflict Mediation for HODs'
                WHEN 23 THEN 'Google Workspace for Educators Level 1'
                WHEN 24 THEN 'Sports Injury First Responder Training'
                WHEN 25 THEN 'Front-Desk Customer Excellence & Etiquette'
                WHEN 26 THEN 'Earthquake Safety & Disaster Action Protocol'
                WHEN 27 THEN 'Cross-Disciplinary Project Based Learning'
                ELSE 'Early Childhood Montessori Pedagogy'
            END,
            CASE (i % 6)
                WHEN 0 THEN v_cat_compliance
                WHEN 1 THEN v_cat_prof_dev
                WHEN 2 THEN v_cat_tech
                WHEN 3 THEN v_cat_soft_skills
                WHEN 4 THEN v_cat_safety
                ELSE v_cat_leadership
            END,
            CASE (i % 6)
                WHEN 0 THEN 'Compliance & Regulatory'
                WHEN 1 THEN 'Professional Development'
                WHEN 2 THEN 'Digital & Technology'
                WHEN 3 THEN 'Soft Skills & Communication'
                WHEN 4 THEN 'Health, Safety & Medical'
                ELSE 'Leadership & Management'
            END,
            'Professional Development',
            'Institutional staff capacity building and skill enhancement course.',
            (i % 3 = 0),
            'Internal', 'Senior Academic Faculty', 'Greenfield Learning Center', 'Academic Staff',
            CASE (i % 4) WHEN 0 THEN 'Online' WHEN 1 THEN 'Offline' WHEN 2 THEN 'Hybrid' ELSE 'Workshop' END,
            '2026-05-01', '2026-05-05', '10:00:00', '12:00:00', 3.0, '3 Hours', 30,
            20, 20, 100.0, 'Quiz', TRUE,
            CASE 
                WHEN i IN (11, 12, 13) THEN 'IN_PROGRESS'
                ELSE 'COMPLETED'
            END,
            15000.00
        );
    END LOOP;

    -- Link programs to learning paths
    INSERT INTO public.hr_training_learning_path_courses (learning_path_id, program_id, sequence_order) VALUES
    (v_path_leadership, v_prog_excel, 1),
    (v_path_leadership, v_prog_communication, 2),
    (v_path_digital, v_prog_excel, 1),
    (v_path_digital, v_prog_digital_mkt, 2),
    (v_path_digital, v_prog_smart_tools, 3),
    (v_path_digital, v_prog_cyber, 4),
    (v_path_teaching, v_prog_psychology, 1),
    (v_path_teaching, v_prog_classroom, 2),
    (v_path_teaching, v_prog_stem, 3),
    (v_path_soft_skills, v_prog_communication, 1),
    (v_path_compliance, v_prog_child_safety, 1),
    (v_path_compliance, v_prog_first_aid, 2),
    (v_path_compliance, v_prog_cyber, 3)
    ON CONFLICT DO NOTHING;

    -- 4. Upcoming Training Sessions (Matching Screenshot 5 Cards)
    INSERT INTO public.hr_training_sessions (id, school_id, program_id, session_title, session_date, start_time, end_time, time_display, trainer_name, location_or_link, capacity, attendance_count, status, created_by) VALUES
    (v_sess_1, v_school_id, v_prog_excel, 'Advanced Excel for Data Analysis', '2026-05-16', '10:00:00', '12:00:00', '10:00 AM - 12:00 PM', 'Rohan Mehta', 'https://meet.google.com/xyz-excel-trn', 25, 18, 'Scheduled', v_admin_id),
    (v_sess_2, v_school_id, v_prog_classroom, 'Classroom Management Strategies', '2026-05-17', '14:00:00', '16:00:00', '02:00 PM - 04:00 PM', 'Priya Singh', 'Auditorium B, South Wing', 30, 20, 'Scheduled', v_admin_id),
    (v_sess_3, v_school_id, v_prog_communication, 'Effective Communication Skills', '2026-05-19', '11:00:00', '13:00:00', '11:00 AM - 01:00 PM', 'Amit Sharma', 'Conference Hall 2', 40, 25, 'Scheduled', v_admin_id),
    (v_sess_4, v_school_id, v_prog_cyber, 'Cybersecurity Awareness', '2026-05-21', '15:00:00', '17:00:00', '03:00 PM - 05:00 PM', 'Neha Gupta', 'Online Live Portal', 30, 15, 'Scheduled', v_admin_id),
    (v_sess_5, v_school_id, v_prog_smart_tools, 'Smart Classroom Tools', '2026-05-24', '10:00:00', '12:00:00', '10:00 AM - 12:00 PM', 'Vikram Patel', 'Digital Lab 3', 35, 0, 'Upcoming', v_admin_id);

    -- 5. Top Performing Employees & Enrollments
    INSERT INTO public.hr_training_enrollments (
        school_id, program_id, employee_id, employee_code, employee_name, employee_email,
        department, designation, status, progress_pct, attended_sessions_count, assessment_score, assessment_status
    ) VALUES
    (v_school_id, v_prog_excel, v_emp_ananya, 'Emp1267', 'Ananya Sharma', 'ananya.sharma@greenfield.edu', 'Academics', 'Senior Mathematics Faculty', 'Completed', 100.0, 1, 98.0, 'Passed'),
    (v_school_id, v_prog_stem, v_emp_ananya, 'Emp1267', 'Ananya Sharma', 'ananya.sharma@greenfield.edu', 'Academics', 'Senior Mathematics Faculty', 'Completed', 100.0, 2, 95.0, 'Passed'),
    (v_school_id, v_prog_child_safety, v_emp_ananya, 'Emp1267', 'Ananya Sharma', 'ananya.sharma@greenfield.edu', 'Academics', 'Senior Mathematics Faculty', 'Completed', 100.0, 1, 100.0, 'Passed'),

    (v_school_id, v_prog_excel, v_emp_rahul, 'Emp1268', 'Rahul Verma', 'rahul.verma@greenfield.edu', 'Academics', 'Physics Faculty', 'Completed', 95.0, 1, 92.0, 'Passed'),
    (v_school_id, v_prog_digital_mkt, v_emp_rahul, 'Emp1268', 'Rahul Verma', 'rahul.verma@greenfield.edu', 'Academics', 'Physics Faculty', 'Completed', 95.0, 1, 90.0, 'Passed'),

    (v_school_id, v_prog_excel, v_emp_neha, 'Emp1269', 'Neha Singh', 'neha.singh@greenfield.edu', 'Administration', 'Office Administrator', 'Completed', 92.0, 1, 88.0, 'Passed'),
    (v_school_id, v_prog_classroom, v_emp_neha, 'Emp1269', 'Neha Singh', 'neha.singh@greenfield.edu', 'Administration', 'Office Administrator', 'In Progress', 90.0, 1, 85.0, 'Passed'),

    (v_school_id, v_prog_cyber, v_emp_vikram, 'Emp1270', 'Vikram Patel', 'vikram.patel@greenfield.edu', 'Finance', 'Accounts Officer', 'Completed', 88.0, 1, 85.0, 'Passed'),
    (v_school_id, v_prog_excel, v_emp_vikram, 'Emp1270', 'Vikram Patel', 'vikram.patel@greenfield.edu', 'Finance', 'Accounts Officer', 'Completed', 88.0, 1, 87.0, 'Passed'),

    (v_school_id, v_prog_first_aid, v_emp_pooja, 'Emp1271', 'Pooja Mehta', 'pooja.mehta@greenfield.edu', 'Transport', 'Transport Supervisor', 'Completed', 85.0, 1, 82.0, 'Passed'),
    (v_school_id, v_prog_child_safety, v_emp_pooja, 'Emp1271', 'Pooja Mehta', 'pooja.mehta@greenfield.edu', 'Transport', 'Transport Supervisor', 'Completed', 85.0, 1, 84.0, 'Passed');

    -- 6. Sample Attendance Record
    INSERT INTO public.hr_training_attendance (school_id, session_id, enrollment_id, employee_id, status, check_in_time, marked_by)
    SELECT v_school_id, v_sess_1, id, employee_id, 'Present', NOW(), v_admin_id
    FROM public.hr_training_enrollments
    WHERE program_id = v_prog_excel;

    -- 7. Issued Certificates
    INSERT INTO public.hr_training_certificates (
        school_id, certificate_number, program_id, employee_id, employee_name, program_title,
        issue_date, expiry_date, status, certificate_url, issued_by
    ) VALUES
    (v_school_id, 'CERT-EXC-2026-001', v_prog_excel, v_emp_ananya, 'Ananya Sharma', 'Advanced Excel for Data Analysis', CURRENT_DATE - INTERVAL '5 days', CURRENT_DATE + INTERVAL '360 days', 'VALID', '/assets/certificates/cert_001.pdf', v_admin_id),
    (v_school_id, 'CERT-SFT-2026-002', v_prog_child_safety, v_emp_ananya, 'Ananya Sharma', 'Child Safety & Safeguarding', CURRENT_DATE - INTERVAL '10 days', CURRENT_DATE + INTERVAL '355 days', 'VALID', '/assets/certificates/cert_002.pdf', v_admin_id),
    (v_school_id, 'CERT-EXC-2026-003', v_prog_excel, v_emp_rahul, 'Rahul Verma', 'Advanced Excel for Data Analysis', CURRENT_DATE - INTERVAL '4 days', CURRENT_DATE + INTERVAL '361 days', 'VALID', '/assets/certificates/cert_003.pdf', v_admin_id),
    (v_school_id, 'CERT-AID-2026-004', v_prog_first_aid, v_emp_pooja, 'Pooja Mehta', 'First Aid & Emergency Response', CURRENT_DATE - INTERVAL '15 days', CURRENT_DATE + INTERVAL '20 days', 'EXPIRING_SOON', '/assets/certificates/cert_004.pdf', v_admin_id),
    (v_school_id, 'CERT-CYB-2025-005', v_prog_cyber, v_emp_vikram, 'Vikram Patel', 'Cybersecurity Awareness', CURRENT_DATE - INTERVAL '400 days', CURRENT_DATE - INTERVAL '35 days', 'EXPIRED', '/assets/certificates/cert_005.pdf', v_admin_id);

    -- 8. Training Feedback
    INSERT INTO public.hr_training_feedback (school_id, program_id, employee_id, employee_name, rating, trainer_rating, content_rating, feedback_text) VALUES
    (v_school_id, v_prog_excel, v_emp_ananya, 'Ananya Sharma', 5, 5, 5, 'Exceptional workshop! Pivot table automation and VLOOKUP tricks will save our department hours.'),
    (v_school_id, v_prog_child_safety, v_emp_pooja, 'Pooja Mehta', 5, 5, 4, 'Very clear emergency protocol explanations. Every staff member must complete this.'),
    (v_school_id, v_prog_digital_mkt, v_emp_rahul, 'Rahul Verma', 4, 4, 4, 'Great insights on promoting STEM club science fairs on social platforms.');

    -- 9. Training Needs & Skill Gaps
    INSERT INTO public.hr_training_skill_gaps (school_id, department, skill_area, required_training_title, employees_count, urgency, status) VALUES
    (v_school_id, 'Teaching', 'Digital Pedagogy', 'Digital Classroom & Smart Tools', 12, 'High', 'Identified'),
    (v_school_id, 'Administration', 'Information Security', 'Cybersecurity & Data Protection', 8, 'Medium', 'Identified'),
    (v_school_id, 'Transport', 'Emergency Care', 'First Aid & Passenger Trauma Care', 6, 'High', 'Identified');

    -- 10. Recent Activity (Matching Screenshot 6 entries)
    INSERT INTO public.hr_training_activity (school_id, entity_type, entity_id, action, details, user_id, user_name, user_role, created_at) VALUES
    (v_school_id, 'PARTICIPANT', v_prog_excel::text, 'Completed', 'Ananya Sharma completed "Advanced Excel"', v_emp_ananya, 'Ananya Sharma', 'teacher', NOW() - INTERVAL '2 hours'),
    (v_school_id, 'PARTICIPANT', v_prog_cyber::text, 'Completed', 'Vikram Patel completed "Cybersecurity Awareness"', v_emp_vikram, 'Vikram Patel', 'accountant', NOW() - INTERVAL '1 day'),
    (v_school_id, 'PARTICIPANT', v_prog_digital_mkt::text, 'Enrolled', 'Rahul Verma enrolled in "Digital Marketing Basics"', v_emp_rahul, 'Rahul Verma', 'teacher', NOW() - INTERVAL '4 hours'),
    (v_school_id, 'PROGRAM', v_path_leadership::text, 'Joined', 'Pooja Mehta joined "Leadership Development Program"', v_emp_pooja, 'Pooja Mehta', 'driver', NOW() - INTERVAL '2 days'),
    (v_school_id, 'SESSION', v_prog_classroom::text, 'Attended', 'Neha Singh attended "Classroom Management"', v_emp_neha, 'Neha Singh', 'admin', NOW() - INTERVAL '1 day'),
    (v_school_id, 'PARTICIPANT', v_prog_smart_tools::text, 'Assigned', 'Amit Kumar assigned to "Smart Classroom Tools"', v_emp_amit, 'Amit Kumar', 'teacher', NOW() - INTERVAL '3 days');

END $$;
