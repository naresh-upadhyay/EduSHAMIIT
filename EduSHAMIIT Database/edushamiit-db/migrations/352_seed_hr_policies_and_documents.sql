-- ============================================================================
-- Migration: 352_seed_hr_policies_and_documents.sql
-- Module: HR Management -> Policies & Documents
-- Description: Seed comprehensive institutional policies, categories, documents,
--              versions, acknowledgements, templates, and audit history.
-- ============================================================================

DO $$
DECLARE
    v_school_id UUID;
    v_admin_id UUID;
    v_cat_emp UUID;
    v_cat_acad UUID;
    v_cat_it UUID;
    v_cat_health UUID;
    v_cat_leave UUID;
    v_cat_fin UUID;
    v_cat_admin UUID;
    v_cat_other UUID;
    
    v_pol_handbook UUID;
    v_pol_leave UUID;
    v_pol_it UUID;
    v_pol_acad UUID;
    v_pol_safety UUID;
    v_pol_safechild UUID;
    v_pol_harass UUID;
    
    v_user_rec RECORD;
    v_today DATE := CURRENT_DATE;
BEGIN
    -- Pick first available school
    SELECT id INTO v_school_id FROM public.schools ORDER BY created_at ASC LIMIT 1;
    IF v_school_id IS NULL THEN
        v_school_id := '11111111-1111-1111-1111-111111111111'::uuid;
    END IF;

    -- Pick first admin profile
    SELECT id INTO v_admin_id FROM public.profiles WHERE school_id = v_school_id AND role IN ('super_admin', 'admin', 'hr') LIMIT 1;
    IF v_admin_id IS NULL THEN
        SELECT id INTO v_admin_id FROM public.profiles WHERE school_id = v_school_id LIMIT 1;
    END IF;

    -- 1. SEED CATEGORIES (Matching Screenshot Exactly)
    INSERT INTO public.hr_document_categories (id, school_id, name, code, description, icon, color_hex, bg_color_hex, sort_order, is_system)
    VALUES
    (gen_random_uuid(), v_school_id, 'Employee Policies', 'EMP_POL', 'HR policies, code of conduct, service rules, benefits.', 'people_alt_outlined', '#6366F1', '#EEF2FF', 1, true),
    (gen_random_uuid(), v_school_id, 'Academic Policies', 'ACAD_POL', 'Admission, examination, grading, curriculum guidelines.', 'calendar_month_outlined', '#0EA5E9', '#E0F2FE', 2, true),
    (gen_random_uuid(), v_school_id, 'IT & System Access', 'IT_POL', 'Software, security, access, acceptable usage.', 'computer_outlined', '#0284C7', '#E0F2FE', 3, true),
    (gen_random_uuid(), v_school_id, 'Health & Safety', 'HEALTH_POL', 'Safety guidelines, medical protocols, emergency plans.', 'verified_user_outlined', '#10B981', '#ECFDF5', 4, true),
    (gen_random_uuid(), v_school_id, 'Leave & Attendance', 'LEAVE_POL', 'Leave rules, attendance norms, biometric policies.', 'access_time_outlined', '#F59E0B', '#FEF3C7', 5, true),
    (gen_random_uuid(), v_school_id, 'Financial Policies', 'FIN_POL', 'Fee, reimbursement, procurement, expenses, audits.', 'account_balance_wallet_outlined', '#10B981', '#ECFDF5', 6, true),
    (gen_random_uuid(), v_school_id, 'Administration', 'ADMIN_POL', 'General administration, facilities, records, logistics.', 'business_outlined', '#8B5CF6', '#EDE9FE', 7, true),
    (gen_random_uuid(), v_school_id, 'Others', 'OTHER_POL', 'Miscellaneous documentation, guides, public notices.', 'folder_open_outlined', '#EC4899', '#FCE7F3', 8, true)
    ON CONFLICT (school_id, code) DO UPDATE 
    SET name = EXCLUDED.name, description = EXCLUDED.description, icon = EXCLUDED.icon, color_hex = EXCLUDED.color_hex, bg_color_hex = EXCLUDED.bg_color_hex;

    -- Fetch Category IDs
    SELECT id INTO v_cat_emp FROM public.hr_document_categories WHERE school_id = v_school_id AND code = 'EMP_POL';
    SELECT id INTO v_cat_acad FROM public.hr_document_categories WHERE school_id = v_school_id AND code = 'ACAD_POL';
    SELECT id INTO v_cat_it FROM public.hr_document_categories WHERE school_id = v_school_id AND code = 'IT_POL';
    SELECT id INTO v_cat_health FROM public.hr_document_categories WHERE school_id = v_school_id AND code = 'HEALTH_POL';
    SELECT id INTO v_cat_leave FROM public.hr_document_categories WHERE school_id = v_school_id AND code = 'LEAVE_POL';
    SELECT id INTO v_cat_fin FROM public.hr_document_categories WHERE school_id = v_school_id AND code = 'FIN_POL';
    SELECT id INTO v_cat_admin FROM public.hr_document_categories WHERE school_id = v_school_id AND code = 'ADMIN_POL';
    SELECT id INTO v_cat_other FROM public.hr_document_categories WHERE school_id = v_school_id AND code = 'OTHER_POL';

    -- 2. SEED POLICIES
    -- Policy 1: Employee Handbook 2026
    v_pol_handbook := gen_random_uuid();
    INSERT INTO public.hr_policies (
        id, school_id, policy_code, title, category_id, category_name, description,
        department, policy_owner_name, current_version, status, effective_date, review_date,
        expiry_date, audience_type, acknowledgement_required, acknowledgement_mandatory,
        acknowledgement_deadline, published_at, created_by
    ) VALUES (
        v_pol_handbook, v_school_id, 'POL-HR-2026-01', 'Employee Handbook 2026', v_cat_emp, 'Employee Policies',
        'Comprehensive institutional handbook detailing employment terms, ethics, standards of service, and staff rights.',
        'All Departments', 'Ramesh Kumar (HR Director)', '2.0', 'ACTIVE', v_today - INTERVAL '60 days',
        v_today + INTERVAL '305 days', v_today + INTERVAL '670 days', 'Entire Institute', true, true,
        v_today + INTERVAL '14 days', timezone('utc', now()) - INTERVAL '60 days', v_admin_id
    ) ON CONFLICT (school_id, policy_code) DO NOTHING;

    -- Versions for Handbook
    INSERT INTO public.hr_policy_versions (policy_id, school_id, version_number, title, description, content_html, change_summary, status, effective_date, created_by_name)
    VALUES
    (v_pol_handbook, v_school_id, '1.0', 'Employee Handbook 2025', 'Initial comprehensive employee guidelines handbook.', 
     '<h2>1. Introduction</h2><p>Welcome to EduSHAMIIT ERP Educational Institution. All staff are expected to uphold highest standards of academic integrity and institutional pride.</p><h3>2. Code of Professional Ethics</h3><p>Employees shall arrive punctually and maintain respect towards all learners.</p>',
     'Initial release for academic session 2025.', 'ARCHIVED', v_today - INTERVAL '400 days', 'HR Team'),
    (v_pol_handbook, v_school_id, '2.0', 'Employee Handbook 2026', 'Updated version with hybrid working guidelines and upgraded digital security norms.',
     '<h2>1. Institutional Vision</h2><p>Our commitment to excellence in technology and holistic education.</p><h2>2. Working Hours & Attendance</h2><p>Daily reporting standard is 08:30 AM to 04:30 PM with smart biometric attendance.</p><h2>3. Academic Integrity & Safeguarding</h2><p>Zero tolerance policy towards learner discrimination and violation of professional boundaries.</p>',
     'Major revision adding digital security clauses and maternity leave enhancements.', 'ACTIVE', v_today - INTERVAL '60 days', 'Ramesh Kumar')
    ON CONFLICT (policy_id, version_number) DO NOTHING;

    -- Policy 2: Leave & Attendance Policy
    v_pol_leave := gen_random_uuid();
    INSERT INTO public.hr_policies (
        id, school_id, policy_code, title, category_id, category_name, description,
        department, policy_owner_name, current_version, status, effective_date, review_date,
        expiry_date, audience_type, acknowledgement_required, acknowledgement_mandatory,
        acknowledgement_deadline, published_at, created_by
    ) VALUES (
        v_pol_leave, v_school_id, 'POL-HR-2026-02', 'Leave Application & Attendance Policy', v_cat_leave, 'Leave & Attendance',
        'Official institutional regulations governing earned leaves, casual leaves, medical emergencies, and approval hierarchies.',
        'All Departments', 'Anita Verma (HR Lead)', '1.2', 'ACTIVE', v_today - INTERVAL '45 days',
        v_today + INTERVAL '120 days', v_today + INTERVAL '400 days', 'Entire Institute', true, false,
        v_today + INTERVAL '30 days', timezone('utc', now()) - INTERVAL '45 days', v_admin_id
    ) ON CONFLICT (school_id, policy_code) DO NOTHING;

    -- Policy 3: IT & Cybersecurity Policy
    v_pol_it := gen_random_uuid();
    INSERT INTO public.hr_policies (
        id, school_id, policy_code, title, category_id, category_name, description,
        department, policy_owner_name, current_version, status, effective_date, review_date,
        expiry_date, audience_type, acknowledgement_required, acknowledgement_mandatory,
        acknowledgement_deadline, published_at, created_by
    ) VALUES (
        v_pol_it, v_school_id, 'POL-IT-2026-01', 'IT Access & Cybersecurity Policy', v_cat_it, 'IT & System Access',
        'Rules regarding password complexity, multi-factor authentication, enterprise network access, and data security.',
        'IT / Technical', 'Vikram Sen (IT Manager)', '1.0', 'ACTIVE', v_today - INTERVAL '30 days',
        v_today + INTERVAL '180 days', v_today + INTERVAL '335 days', 'Entire Institute', true, true,
        v_today + INTERVAL '7 days', timezone('utc', now()) - INTERVAL '30 days', v_admin_id
    ) ON CONFLICT (school_id, policy_code) DO NOTHING;

    -- Policy 4: Academic Conduct
    v_pol_acad := gen_random_uuid();
    INSERT INTO public.hr_policies (
        id, school_id, policy_code, title, category_id, category_name, description,
        department, policy_owner_name, current_version, status, effective_date, review_date,
        expiry_date, audience_type, acknowledgement_required, acknowledgement_mandatory,
        published_at, created_by
    ) VALUES (
        v_pol_acad, v_school_id, 'POL-ACAD-2026-01', 'Faculty Academic Conduct & Integrity', v_cat_acad, 'Academic Policies',
        'Teaching methodologies, fair examination grading standards, lesson planning submission, and syllabus timelines.',
        'Academics', 'Dr. Arvinder Singh (Academic Dean)', '1.1', 'ACTIVE', v_today - INTERVAL '20 days',
        v_today + INTERVAL '90 days', v_today + INTERVAL '345 days', 'Department', false, false,
        timezone('utc', now()) - INTERVAL '20 days', v_admin_id
    ) ON CONFLICT (school_id, policy_code) DO NOTHING;

    -- Policy 5: Health & Safety Guidelines
    v_pol_safety := gen_random_uuid();
    INSERT INTO public.hr_policies (
        id, school_id, policy_code, title, category_id, category_name, description,
        department, policy_owner_name, current_version, status, effective_date, review_date,
        expiry_date, audience_type, acknowledgement_required, published_at, created_by
    ) VALUES (
        v_pol_safety, v_school_id, 'POL-SAFE-2026-01', 'Campus Health & Safety Guidelines', v_cat_health, 'Health & Safety',
        'Laboratory safety, first aid protocols, disaster readiness drills, fire safety, and sanitation compliance.',
        'All Departments', 'Col. Rajesh Bakshi (Security Officer)', '1.0', 'ACTIVE', v_today - INTERVAL '15 days',
        v_today + INTERVAL '165 days', v_today + INTERVAL '350 days', 'Entire Institute', false,
        timezone('utc', now()) - INTERVAL '15 days', v_admin_id
    ) ON CONFLICT (school_id, policy_code) DO NOTHING;

    -- Policy 6: Child Safeguarding
    v_pol_safechild := gen_random_uuid();
    INSERT INTO public.hr_policies (
        id, school_id, policy_code, title, category_id, category_name, description,
        department, policy_owner_name, current_version, status, effective_date, review_date,
        audience_type, acknowledgement_required, acknowledgement_mandatory, published_at, created_by
    ) VALUES (
        v_pol_safechild, v_school_id, 'POL-SAFE-2026-02', 'Child Safeguarding & Protection Policy', v_cat_health, 'Health & Safety',
        'Mandatory statutory protection framework, emotional well-being protocols, and reporting of concerns.',
        'All Departments', 'Pooja Sharma (Counsellor)', '2.1', 'ACTIVE', v_today - INTERVAL '10 days',
        v_today + INTERVAL '170 days', 'Entire Institute', true, true,
        timezone('utc', now()) - INTERVAL '10 days', v_admin_id
    ) ON CONFLICT (school_id, policy_code) DO NOTHING;

    -- Policy 7: Anti-Harassment (Pending Review)
    v_pol_harass := gen_random_uuid();
    INSERT INTO public.hr_policies (
        id, school_id, policy_code, title, category_id, category_name, description,
        department, policy_owner_name, current_version, status, effective_date,
        audience_type, acknowledgement_required, created_by
    ) VALUES (
        v_pol_harass, v_school_id, 'POL-HR-2026-03', 'Workplace Anti-Harassment & POSH Policy', v_cat_emp, 'Employee Policies',
        'Prevention of sexual harassment, redressal committee guidelines, and non-retaliation assurance.',
        'All Departments', 'Sunita Rao (Legal Advisor)', '1.0', 'PENDING_REVIEW', v_today + INTERVAL '7 days',
        'Entire Institute', true, v_admin_id
    ) ON CONFLICT (school_id, policy_code) DO NOTHING;

    -- 3. SEED DOCUMENT LIBRARY (Matching exact table items from the screenshot!)
    INSERT INTO public.hr_documents (
        school_id, document_name, document_code, document_type, category_id, category_name,
        description, owner_name, department, current_version, file_name, file_extension,
        file_type, file_size_bytes, storage_path, access_level, issue_date, review_date, expiry_date, status, created_at, updated_at
    ) VALUES
    -- 1. Employee Handbook 2026 (PDF, 2.4 MB, v2.0)
    (v_school_id, 'Employee Handbook 2026', 'DOC-2026-01', 'Employee Document', v_cat_emp, 'Employee Policies',
     'Complete employee handbook and guidelines', 'Ramesh Kumar', 'Academics', 'v2.0',
     'employee_handbook_2026.pdf', 'pdf', 'PDF', 2516582, 'hr_documents/sample/employee_handbook_2026.pdf',
     'INSTITUTE_WIDE', v_today - INTERVAL '20 days', v_today + INTERVAL '300 days', v_today + INTERVAL '700 days', 'ACTIVE', now() - INTERVAL '20 days', now() - INTERVAL '20 days'),

    -- 2. Leave Application Form (DOCX, 856 KB, v1.2)
    (v_school_id, 'Leave Application Form', 'DOC-2026-02', 'HR Document', v_cat_leave, 'Leave & Attendance',
     'Standard leave application form', 'Anita Verma', 'Administration', 'v1.2',
     'leave_application_form.docx', 'docx', 'DOCX', 876544, 'hr_documents/sample/leave_application_form.docx',
     'INSTITUTE_WIDE', v_today - INTERVAL '22 days', v_today + INTERVAL '200 days', v_today + INTERVAL '365 days', 'ACTIVE', now() - INTERVAL '22 days', now() - INTERVAL '22 days'),

    -- 3. IT Access Request Form (DOCX, 1.2 MB, v1.0)
    (v_school_id, 'IT Access Request Form', 'DOC-2026-03', 'Compliance Document', v_cat_it, 'IT & System Access',
     'Request form for system access', 'Vikram Sen', 'IT / Technical', 'v1.0',
     'it_access_request_form.docx', 'docx', 'DOCX', 1258291, 'hr_documents/sample/it_access_request_form.docx',
     'INSTITUTE_WIDE', v_today - INTERVAL '24 days', v_today + INTERVAL '180 days', v_today + INTERVAL '365 days', 'ACTIVE', now() - INTERVAL '24 days', now() - INTERVAL '24 days'),

    -- 4. Fee Structure 2026-27 (PDF, 1.8 MB, v1.1)
    (v_school_id, 'Fee Structure 2026-27', 'DOC-2026-04', 'HR Document', v_cat_fin, 'Financial Policies',
     'Annual fee structure and payment details', 'Sanjay Gupta', 'Finance', 'v1.1',
     'fee_structure_2026_27.pdf', 'pdf', 'PDF', 1887436, 'hr_documents/sample/fee_structure_2026_27.pdf',
     'INSTITUTE_WIDE', v_today - INTERVAL '26 days', v_today + INTERVAL '250 days', v_today + INTERVAL '365 days', 'ACTIVE', now() - INTERVAL '26 days', now() - INTERVAL '26 days'),

    -- 5. Campus Safety Guidelines (PDF, 980 KB, v1.0)
    (v_school_id, 'Campus Safety Guidelines', 'DOC-2026-05', 'Compliance Document', v_cat_health, 'Health & Safety',
     'Safety rules and emergency procedures', 'Rajesh Bakshi', 'Administration', 'v1.0',
     'campus_safety_guidelines.pdf', 'pdf', 'PDF', 1003520, 'hr_documents/sample/campus_safety_guidelines.pdf',
     'INSTITUTE_WIDE', v_today - INTERVAL '28 days', v_today + INTERVAL '120 days', v_today + INTERVAL '365 days', 'ACTIVE', now() - INTERVAL '28 days', now() - INTERVAL '28 days'),

    -- 6. Academic Calendar 2026-27
    (v_school_id, 'Academic Calendar 2026-27', 'DOC-2026-06', 'HR Document', v_cat_acad, 'Academic Policies',
     'Session term dates, examinations, and holidays', 'Dr. Arvinder Singh', 'Academics', 'v1.0',
     'academic_calendar_2026_27.pdf', 'pdf', 'PDF', 3145728, 'hr_documents/sample/academic_calendar_2026_27.pdf',
     'INSTITUTE_WIDE', v_today - INTERVAL '30 days', v_today + INTERVAL '300 days', v_today + INTERVAL '365 days', 'ACTIVE', now() - INTERVAL '30 days', now() - INTERVAL '30 days'),

    -- 7. Non-Disclosure Agreement (NDA)
    (v_school_id, 'Employee Non-Disclosure Agreement', 'DOC-2026-07', 'Contract', v_cat_admin, 'Administration',
     'Standard confidentiality and non-disclosure deed for newly hired educators and staff.', 'Sunita Rao', 'Administration', 'v1.0',
     'employee_nda_standard.pdf', 'pdf', 'PDF', 645120, 'hr_documents/sample/employee_nda_standard.pdf',
     'HR_ONLY', v_today - INTERVAL '40 days', v_today + INTERVAL '300 days', v_today + INTERVAL '730 days', 'ACTIVE', now() - INTERVAL '40 days', now() - INTERVAL '40 days'),

    -- 8. Fire & Life Safety Certificate (Expiring Soon - 5 days)
    (v_school_id, 'Municipal Fire & Life Safety Certificate', 'DOC-2026-08', 'Compliance Document', v_cat_health, 'Health & Safety',
     'Statutory fire inspection clearance certificate for main campus academic blocks.', 'Rajesh Bakshi', 'Administration', 'v1.0',
     'fire_safety_clearance.pdf', 'pdf', 'PDF', 1450000, 'hr_documents/sample/fire_safety_clearance.pdf',
     'MANAGEMENT', v_today - INTERVAL '360 days', v_today + INTERVAL '5 days', v_today + INTERVAL '5 days', 'EXPIRING_SOON', now() - INTERVAL '45 days', now() - INTERVAL '2 days'),

    -- 9. Commercial Vehicle Insurance - Bus 04 (Expired 12 days ago)
    (v_school_id, 'School Bus 04 Commercial Vehicle Insurance', 'DOC-2026-09', 'Compliance Document', v_cat_admin, 'Administration',
     'Annual comprehensive commercial vehicle policy for student transport bus 04.', 'Mohan Lal', 'Transport', 'v1.0',
     'bus_04_insurance.pdf', 'pdf', 'PDF', 1228800, 'hr_documents/sample/bus_04_insurance.pdf',
     'HR_ONLY', v_today - INTERVAL '377 days', v_today - INTERVAL '12 days', v_today - INTERVAL '12 days', 'EXPIRED', now() - INTERVAL '50 days', now() - INTERVAL '12 days'),

    -- 10. Central Water Potability Testing Certificate (Expiring in 25 days)
    (v_school_id, 'Campus Water Potability & Hygiene Audit', 'DOC-2026-10', 'Compliance Document', v_cat_health, 'Health & Safety',
     'Quarterly biomedical water potability laboratory clearance certificate.', 'Col. Rajesh Bakshi', 'Administration', 'v1.0',
     'water_potability_certificate.pdf', 'pdf', 'PDF', 768000, 'hr_documents/sample/water_potability_certificate.pdf',
     'INSTITUTE_WIDE', v_today - INTERVAL '65 days', v_today + INTERVAL '25 days', v_today + INTERVAL '25 days', 'EXPIRING_SOON', now() - INTERVAL '65 days', now() - INTERVAL '3 days');

    -- 4. SEED DOCUMENT TEMPLATES
    INSERT INTO public.hr_document_templates (
        school_id, template_code, template_name, template_type, description, category_id, category_name, content_html, variables
    ) VALUES
    (v_school_id, 'TMPL-OFFER', 'Teacher Job Offer Letter', 'Offer Letter',
     'Standard institutional appointment and formal employment offer letter with salary breakup.', v_cat_admin, 'Administration',
     '<p>Dear <strong>{{employee_name}}</strong> (Emp ID: {{employee_id}}),</p><p>We are delighted to offer you the role of <strong>{{designation}}</strong> in the <strong>{{department}}</strong> department at <strong>{{institution_name}}</strong> effective from {{joining_date}}.</p><p>Your gross annual remuneration will be {{salary}} per annum.</p>',
     '["employee_name", "employee_id", "designation", "department", "joining_date", "salary", "institution_name"]'::jsonb),

    (v_school_id, 'TMPL-RELIEVING', 'Employee Relieving & Service Certificate', 'Relieving Letter',
     'Formal relieving letter and conduct clearance certificate issued upon resignation.', v_cat_admin, 'Administration',
     '<p>This is to certify that <strong>{{employee_name}}</strong> was employed with <strong>{{institution_name}}</strong> as {{designation}} from {{joining_date}} to {{relieving_date}}. During their tenure, conduct was satisfactory.</p>',
     '["employee_name", "employee_id", "designation", "department", "joining_date", "relieving_date", "institution_name"]'::jsonb),

    (v_school_id, 'TMPL-NDA', 'Institutional Non-Disclosure Agreement (NDA)', 'NDA',
     'Employee confidentiality and data privacy covenant governing student and institute data.', v_cat_it, 'IT & System Access',
     '<p>This Non-Disclosure Agreement binds <strong>{{employee_name}}</strong> to absolute confidentiality regarding student records, examinations, and trade secrets of <strong>{{institution_name}}</strong>.</p>',
     '["employee_name", "employee_id", "department", "institution_name"]'::jsonb)
    ON CONFLICT (school_id, template_code) DO NOTHING;

    -- 5. SEED REALISTIC ACKNOWLEDGEMENTS ACROSS EXISTING PROFILES
    FOR v_user_rec IN (
        SELECT id, full_name, email, role, department 
        FROM public.profiles 
        WHERE school_id = v_school_id 
        LIMIT 15
    ) LOOP
        -- Handbook Ack
        INSERT INTO public.hr_policy_acknowledgements (
            school_id, policy_id, version_number, user_id, user_name, user_email, user_role,
            department, assigned_at, deadline, status, is_mandatory, acknowledged_at, signature_text
        ) VALUES (
            v_school_id, v_pol_handbook, '2.0', v_user_rec.id, v_user_rec.full_name, v_user_rec.email,
            v_user_rec.role, COALESCE(v_user_rec.department, 'Academics'), v_today - INTERVAL '10 days',
            v_today + INTERVAL '14 days',
            CASE WHEN random() > 0.3 THEN 'ACKNOWLEDGED' ELSE 'PENDING' END,
            true,
            CASE WHEN random() > 0.3 THEN timezone('utc', now()) - INTERVAL '2 days' ELSE NULL END,
            v_user_rec.full_name
        ) ON CONFLICT (policy_id, version_number, user_id) DO NOTHING;

        -- IT Policy Ack
        INSERT INTO public.hr_policy_acknowledgements (
            school_id, policy_id, version_number, user_id, user_name, user_email, user_role,
            department, assigned_at, deadline, status, is_mandatory, acknowledged_at, signature_text
        ) VALUES (
            v_school_id, v_pol_it, '1.0', v_user_rec.id, v_user_rec.full_name, v_user_rec.email,
            v_user_rec.role, COALESCE(v_user_rec.department, 'Academics'), v_today - INTERVAL '15 days',
            v_today - INTERVAL '1 days',
            CASE WHEN random() > 0.5 THEN 'ACKNOWLEDGED' ELSE 'OVERDUE' END,
            true,
            CASE WHEN random() > 0.5 THEN timezone('utc', now()) - INTERVAL '5 days' ELSE NULL END,
            v_user_rec.full_name
        ) ON CONFLICT (policy_id, version_number, user_id) DO NOTHING;
    END LOOP;

    -- 6. SEED ACTIVITY TIMELINE
    INSERT INTO public.hr_document_activity (school_id, entity_type, entity_id, action, summary, created_at)
    VALUES
    (v_school_id, 'POLICY', v_pol_handbook, 'Published', 'Employee Handbook 2026 v2.0 published and distributed to institution.', now() - INTERVAL '20 days'),
    (v_school_id, 'DOCUMENT', (SELECT id FROM public.hr_documents WHERE school_id = v_school_id AND document_code = 'DOC-2026-01' LIMIT 1), 'Uploaded', 'Employee Handbook 2026 PDF uploaded by Ramesh Kumar.', now() - INTERVAL '20 days'),
    (v_school_id, 'DOCUMENT', (SELECT id FROM public.hr_documents WHERE school_id = v_school_id AND document_code = 'DOC-2026-02' LIMIT 1), 'Updated', 'Leave Application Form v1.2 updated with maternity leave annexure.', now() - INTERVAL '18 days'),
    (v_school_id, 'ACKNOWLEDGEMENT', v_pol_handbook, 'Reminded', 'Automated reminder sent to 14 pending staff members.', now() - INTERVAL '3 days');

END $$;
