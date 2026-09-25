-- ============================================================================
-- Migration: 359_hr_document_templates_and_lookups.sql
-- Module: HR Management -> Policies & Documents -> Templates & Dynamic Lookups
-- Description:
--   1. Relaxes restrictive CHECK constraints on public.hr_document_templates
--      to allow all dynamic template types and categories from lookup tables.
--   2. Adds is_preset, is_system flags to hr_document_templates.
--   3. Ensures HR_TEMPLATE_TYPE and HR_TEMPLATE_CATEGORY lookup keys and
--      rich institutional lookup values exist for all schools.
--   4. Seeds authentic, fully-fledged, professional enterprise templates
--      (Warning Letter, Offer Letter, Appointment Letter, Experience Letter,
--       Relieving Letter, NDA & Confidentiality, Code of Conduct,
--       Salary Increment & Promotion, Joining Checklist, HR Advance Form)
--      into public.hr_document_templates across all schools.
-- ============================================================================

-- 1. DROP RESTRICTIVE CHECK CONSTRAINT ON template_type
ALTER TABLE public.hr_document_templates 
    DROP CONSTRAINT IF EXISTS hr_document_templates_template_type_check;

-- Add is_preset and is_system columns if they do not exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'hr_document_templates' 
          AND column_name = 'is_preset'
    ) THEN
        ALTER TABLE public.hr_document_templates ADD COLUMN is_preset BOOLEAN DEFAULT false;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'hr_document_templates' 
          AND column_name = 'is_system'
    ) THEN
        ALTER TABLE public.hr_document_templates ADD COLUMN is_system BOOLEAN DEFAULT false;
    END IF;
END $$;

-- 2. SEED LOOKUP KEYS & VALUES FOR ALL SCHOOLS
DO $$
DECLARE
    s RECORD;
    admin_id UUID;
    v_type_key_id UUID;
    v_cat_key_id UUID;
BEGIN
    FOR s IN SELECT id FROM public.schools LOOP
        SELECT id INTO admin_id FROM public.profiles WHERE school_id = s.id LIMIT 1;
        IF admin_id IS NULL THEN
            SELECT id INTO admin_id FROM public.profiles LIMIT 1;
        END IF;

        IF admin_id IS NOT NULL THEN
            -- ----------------------------------------------------------------
            -- A. HR_TEMPLATE_TYPE Lookup Key
            -- ----------------------------------------------------------------
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'HR Template Type', 'HR_TEMPLATE_TYPE', 'Classification of official letterheads and reusable HR templates.',
                'SYSTEM', 'drafts_outlined', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_type_key_id;

            IF v_type_key_id IS NULL THEN
                SELECT id INTO v_type_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'HR_TEMPLATE_TYPE' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_type_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_type_key_id, s.id, 'Warning Letter', 'WARNING_LETTER', 'Formal disciplinary notice or performance corrective action warning.', 'ACTIVE', 1, admin_id),
                    (v_type_key_id, s.id, 'Offer Letter', 'OFFER_LETTER', 'Official employment offer letter with compensation breakdown.', 'ACTIVE', 2, admin_id),
                    (v_type_key_id, s.id, 'Appointment Letter', 'APPOINTMENT_LETTER', 'Legally binding employment contract with terms of service.', 'ACTIVE', 3, admin_id),
                    (v_type_key_id, s.id, 'Experience Letter', 'EXPERIENCE_LETTER', 'Service certificate confirming tenure, role, and conduct.', 'ACTIVE', 4, admin_id),
                    (v_type_key_id, s.id, 'Relieving Letter', 'RELIEVING_LETTER', 'Formal clearance letter and exit discharge confirmation.', 'ACTIVE', 5, admin_id),
                    (v_type_key_id, s.id, 'NDA & Confidentiality', 'NDA', 'Non-disclosure, student data privacy, and IP protection agreement.', 'ACTIVE', 6, admin_id),
                    (v_type_key_id, s.id, 'Code of Conduct', 'CODE_OF_CONDUCT', 'Institutional ethics, decorum, and child safety compliance policy.', 'ACTIVE', 7, admin_id),
                    (v_type_key_id, s.id, 'Salary Increment & Promotion', 'SALARY_INCREMENT', 'Annual merit review, appraisal order, and compensation revision.', 'ACTIVE', 8, admin_id),
                    (v_type_key_id, s.id, 'Joining Checklist', 'JOINING_CHECKLIST', 'Statutory document verification and onboarding audit checklist.', 'ACTIVE', 9, admin_id),
                    (v_type_key_id, s.id, 'HR Forms', 'HR_FORMS', 'Internal staff requisition, advance, or claim forms.', 'ACTIVE', 10, admin_id),
                    (v_type_key_id, s.id, 'Custom', 'CUSTOM', 'Custom institutional communication or certificate.', 'ACTIVE', 11, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

            -- ----------------------------------------------------------------
            -- B. HR_TEMPLATE_CATEGORY Lookup Key
            -- ----------------------------------------------------------------
            INSERT INTO public.lookup_keys (
                school_id, key_name, key_code, description, key_type, icon, status, created_by
            ) VALUES (
                s.id, 'HR Template Category', 'HR_TEMPLATE_CATEGORY', 'Functional categorization for HR documents and letter templates.',
                'SYSTEM', 'folder_open_outlined', 'ACTIVE', admin_id
            )
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL 
            DO UPDATE SET key_name = EXCLUDED.key_name, description = EXCLUDED.description
            RETURNING id INTO v_cat_key_id;

            IF v_cat_key_id IS NULL THEN
                SELECT id INTO v_cat_key_id FROM public.lookup_keys WHERE school_id = s.id AND key_code = 'HR_TEMPLATE_CATEGORY' AND deleted_at IS NULL LIMIT 1;
            END IF;

            IF v_cat_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_cat_key_id, s.id, 'Administration', 'ADMINISTRATION', 'Executive notices, service certificates, and general administrative orders.', 'ACTIVE', 1, admin_id),
                    (v_cat_key_id, s.id, 'Employee Policies', 'EMPLOYEE_POLICIES', 'Staff welfare, workplace ethics, and personnel standards.', 'ACTIVE', 2, admin_id),
                    (v_cat_key_id, s.id, 'Academic Policies', 'ACADEMIC_POLICIES', 'Pedagogical integrity, grading standards, and faculty requirements.', 'ACTIVE', 3, admin_id),
                    (v_cat_key_id, s.id, 'IT & System Access', 'IT_SYSTEM_ACCESS', 'Data confidentiality, network compliance, and system credentials.', 'ACTIVE', 4, admin_id),
                    (v_cat_key_id, s.id, 'Health & Safety', 'HEALTH_SAFETY', 'Campus health guidelines, first aid, and physical safety standards.', 'ACTIVE', 5, admin_id),
                    (v_cat_key_id, s.id, 'Leave & Attendance', 'LEAVE_ATTENDANCE', 'Attendance records, leave entitlements, and duty roster guidelines.', 'ACTIVE', 6, admin_id),
                    (v_cat_key_id, s.id, 'Financial Policies', 'FINANCIAL_POLICIES', 'Compensation reviews, expense advances, and payroll agreements.', 'ACTIVE', 7, admin_id),
                    (v_cat_key_id, s.id, 'Others', 'OTHERS', 'Miscellaneous institutional templates.', 'ACTIVE', 8, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL 
                DO UPDATE SET value_name = EXCLUDED.value_name, description = EXCLUDED.description, status = 'ACTIVE';
            END IF;

        END IF;
    END LOOP;
END $$;

-- 3. SEED DYNAMIC ENTERPRISE TEMPLATES INTO public.hr_document_templates
DO $$
DECLARE
    s RECORD;
    admin_id UUID;
    v_cat_admin UUID;
    v_cat_emp UUID;
    v_cat_it UUID;
    v_cat_fin UUID;
BEGIN
    FOR s IN SELECT id FROM public.schools LOOP
        SELECT id INTO admin_id FROM public.profiles WHERE school_id = s.id LIMIT 1;
        IF admin_id IS NULL THEN
            SELECT id INTO admin_id FROM public.profiles LIMIT 1;
        END IF;

        SELECT id INTO v_cat_admin FROM public.hr_document_categories WHERE school_id = s.id AND (code = 'CAT-ADMIN' OR name ILIKE '%Admin%') LIMIT 1;
        SELECT id INTO v_cat_emp FROM public.hr_document_categories WHERE school_id = s.id AND (code = 'CAT-EMP' OR name ILIKE '%Employee%') LIMIT 1;
        SELECT id INTO v_cat_it FROM public.hr_document_categories WHERE school_id = s.id AND (code = 'CAT-IT' OR name ILIKE '%IT%') LIMIT 1;
        SELECT id INTO v_cat_fin FROM public.hr_document_categories WHERE school_id = s.id AND (code = 'CAT-FIN' OR name ILIKE '%Finan%') LIMIT 1;

        -- 1. WARNING LETTER (Authentic Disciplinary Notice)
        INSERT INTO public.hr_document_templates (
            school_id, template_code, template_name, template_type, description,
            category_id, category_name, content_html, variables, is_preset, is_system, is_active, created_by
        ) VALUES (
            s.id, 'TMPL-WARN-01', 'Formal Disciplinary & Performance Warning Letter', 'Warning Letter',
            'Official institutional notice of misconduct or sustained performance shortfall with Corrective Action Plan (CAP).',
            v_cat_admin, 'Administration',
            '<p><strong>CONFIDENTIAL &amp; OFFICIAL NOTIFICATION</strong></p>
<p><strong>To:</strong> {{employee_name}}<br>
<strong>Staff Identification Code:</strong> {{employee_id}}<br>
<strong>Designation:</strong> {{designation}}<br>
<strong>Department:</strong> {{department}}<br>
<strong>Date of Notice:</strong> {{effective_date}}</p>

<p><strong>SUBJECT: FORMAL WRITTEN WARNING &mdash; {{warning_level}}</strong></p>

<p>Dear {{employee_name}},</p>

<p>This document serves as an official formal warning issued by the Disciplinary Authority and the Human Resources Division of <strong>{{institution_name}}</strong>. This notice follows formal inquiry regarding an incident / continued performance deviation observed on <strong>{{incident_date}}</strong>.</p>

<p><strong>1. Nature of Infraction &amp; Policy Violation:</strong><br>
The institution has observed infractions violating the following institutional code and policy guidelines:<br>
<em>{{policy_violated}}</em></p>

<p><strong>2. Detailed Findings &amp; Summary:</strong><br>
{{reason_for_warning}}</p>

<p><strong>3. Mandatory Corrective Action Plan (CAP):</strong><br>
To maintain standard academic and institutional integrity, you are required to comply with the following corrective directives:<br>
{{corrective_action_plan}}</p>

<p><strong>4. Formal Review Period &amp; Consequences:</strong><br>
Your performance, professional conduct, and adherence will be under active review for a period of <strong>{{review_period}}</strong>. Failure to demonstrate immediate and sustained improvement or any recurrence of similar violations during or after this period may result in severe disciplinary measures, up to and including suspension, withholding of annual increments, or termination of employment in accordance with the Institutional Service Bye-Laws.</p>

<p>Please sign and return a copy of this notification to Human Resources within 48 hours to acknowledge receipt.</p>

<br>
<p>Sincerely,</p>
<p><strong>{{hr_signatory_name}}</strong><br>
{{hr_signatory_title}}<br>
{{institution_name}}</p>

<br><hr><br>
<p><strong>EMPLOYEE ACKNOWLEDGEMENT &amp; RECEIPT:</strong></p>
<p>I acknowledge receipt of this formal warning. I understand the reasons outlined and the mandatory corrective actions required of me.</p>
<p>Signature: __________________________ &nbsp;&nbsp;&nbsp;&nbsp; Date: ____________________</p>',
            '["employee_name", "employee_id", "designation", "department", "effective_date", "warning_level", "incident_date", "policy_violated", "reason_for_warning", "corrective_action_plan", "review_period", "hr_signatory_name", "hr_signatory_title", "institution_name"]'::jsonb,
            true, true, true, admin_id
        )
        ON CONFLICT (school_id, template_code) DO UPDATE SET
            template_name = EXCLUDED.template_name,
            template_type = EXCLUDED.template_type,
            description = EXCLUDED.description,
            content_html = EXCLUDED.content_html,
            variables = EXCLUDED.variables,
            is_preset = true,
            is_active = true;

        -- 2. OFFER LETTER (Official Employment Offer)
        INSERT INTO public.hr_document_templates (
            school_id, template_code, template_name, template_type, description,
            category_id, category_name, content_html, variables, is_preset, is_system, is_active, created_by
        ) VALUES (
            s.id, 'TMPL-OFFER-01', 'Official Employment Offer Letter', 'Offer Letter',
            'Full official appointment offer with compensation breakdown, designation, and onboarding terms.',
            v_cat_admin, 'Administration',
            '<p><strong>PRIVATE &amp; CONFIDENTIAL</strong></p>
<p>Date: {{effective_date}}</p>

<p>To,<br>
<strong>{{employee_name}}</strong><br>
Email: {{email}} | Phone: {{phone}}</p>

<p><strong>SUBJECT: CONDITIONAL OFFER OF EMPLOYMENT</strong></p>

<p>Dear {{employee_name}},</p>

<p>We are delighted to extend to you an offer of employment with <strong>{{institution_name}}</strong> as <strong>{{designation}}</strong> in the <strong>{{department}}</strong> department. We were thoroughly impressed by your credentials, domain competence, and passion for educational excellence.</p>

<p><strong>Key Terms of the Offer:</strong></p>
<ul>
  <li><strong>Designation:</strong> {{designation}}</li>
  <li><strong>Department:</strong> {{department}}</li>
  <li><strong>Gross Compensation (CTC):</strong> {{salary}} per annum (subject to statutory taxes and deductions)</li>
  <li><strong>Reporting Manager:</strong> {{reporting_manager}}</li>
  <li><strong>Joining Date:</strong> On or before {{joining_date}}</li>
  <li><strong>Work Location:</strong> {{branch_name}}, {{institution_address}}</li>
  <li><strong>Probationary Period:</strong> {{probation_period}} from the effective date of joining</li>
</ul>

<p><strong>Contingencies &amp; Documentation:</strong><br>
This offer is contingent upon successful verification of your academic credentials, past employment background, statutory identity proofs, and medical fitness as per the Institutional Joining Checklist.</p>

<p>Please indicate your formal acceptance of this offer by signing the duplicate copy of this letter and returning it to Human Resources within 5 business days.</p>

<p>We look forward to welcoming you to our academic community.</p>

<br>
<p>Yours sincerely,</p>
<p><strong>{{hr_signatory_name}}</strong><br>
{{hr_signatory_title}}<br>
{{institution_name}}</p>

<br><hr><br>
<p><strong>ACCEPTANCE OF OFFER:</strong></p>
<p>I hereby accept the offer of employment as {{designation}} on the terms and conditions outlined above.</p>
<p>Signature: __________________________ &nbsp;&nbsp;&nbsp;&nbsp; Date: ____________________</p>',
            '["employee_name", "email", "phone", "effective_date", "designation", "department", "salary", "reporting_manager", "joining_date", "branch_name", "institution_address", "probation_period", "hr_signatory_name", "hr_signatory_title", "institution_name"]'::jsonb,
            true, true, true, admin_id
        )
        ON CONFLICT (school_id, template_code) DO UPDATE SET
            template_name = EXCLUDED.template_name,
            template_type = EXCLUDED.template_type,
            description = EXCLUDED.description,
            content_html = EXCLUDED.content_html,
            variables = EXCLUDED.variables,
            is_preset = true,
            is_active = true;

        -- 3. APPOINTMENT LETTER (Binding Employment Contract)
        INSERT INTO public.hr_document_templates (
            school_id, template_code, template_name, template_type, description,
            category_id, category_name, content_html, variables, is_preset, is_system, is_active, created_by
        ) VALUES (
            s.id, 'TMPL-APPT-01', 'Letter of Appointment & Terms of Service', 'Appointment Letter',
            'Legally binding appointment contract detailing scope of duties, probation, and termination clauses.',
            v_cat_admin, 'Administration',
            '<p><strong>APPOINTMENT CONTRACT &amp; SERVICE AGREEMENT</strong></p>
<p>Reference: {{employee_id}}/APPT/2026<br>
Date: {{effective_date}}</p>

<p>To,<br>
<strong>{{employee_name}}</strong><br>
Staff ID: {{employee_id}}<br>
Address: {{institution_address}}</p>

<p>Dear {{employee_name}},</p>

<p>The Governing Body and Management of <strong>{{institution_name}}</strong> are pleased to appoint you as <strong>{{designation}}</strong> in the <strong>{{department}}</strong> with effect from <strong>{{joining_date}}</strong>.</p>

<p><strong>1. Scope of Responsibilities &amp; Working Hours:</strong><br>
You will discharge all pedagogical, administrative, co-curricular, and examination duties assigned to you by your reporting authority. Working hours and roster shall conform to the institutional calendar.</p>

<p><strong>2. Remuneration &amp; Statutory Benefits:</strong><br>
Your gross salary is fixed at <strong>{{salary}}</strong> per annum. You are eligible for Provident Fund (EPF), Gratuity, Group Medical Insurance, and institutional leave entitlements as applicable.</p>

<p><strong>3. Probation &amp; Confirmation:</strong><br>
You will be on probation for a period of <strong>{{probation_period}}</strong>. Confirmation is contingent upon satisfactory evaluation of your classroom performance and institutional conduct.</p>

<p><strong>4. Notice Period &amp; Separation:</strong><br>
During probation, either party may terminate this agreement with 30 days notice. Post confirmation, the mandatory notice period shall be <strong>{{notice_period}}</strong>.</p>

<p><strong>5. Governing Code:</strong><br>
You agree to abide by the Institutional Code of Conduct, child protection policies (POSH/POCSO), and confidentiality guidelines.</p>

<br>
<p>By Order of Management,</p>
<p><strong>{{hr_signatory_name}}</strong><br>
{{hr_signatory_title}}<br>
{{institution_name}}</p>',
            '["employee_name", "employee_id", "effective_date", "designation", "department", "joining_date", "salary", "probation_period", "notice_period", "institution_address", "hr_signatory_name", "hr_signatory_title", "institution_name"]'::jsonb,
            true, true, true, admin_id
        )
        ON CONFLICT (school_id, template_code) DO UPDATE SET
            template_name = EXCLUDED.template_name,
            template_type = EXCLUDED.template_type,
            description = EXCLUDED.description,
            content_html = EXCLUDED.content_html,
            variables = EXCLUDED.variables,
            is_preset = true,
            is_active = true;

        -- 4. EXPERIENCE LETTER (Service & Conduct Certificate)
        INSERT INTO public.hr_document_templates (
            school_id, template_code, template_name, template_type, description,
            category_id, category_name, content_html, variables, is_preset, is_system, is_active, created_by
        ) VALUES (
            s.id, 'TMPL-EXP-01', 'Staff Experience & Conduct Certificate', 'Experience Letter',
            'Official institutional certificate confirming service tenure, designations held, and conduct.',
            v_cat_admin, 'Administration',
            '<p style="text-align: center;"><strong>TO WHOMSOEVER IT MAY CONCERN</strong></p>

<p>Date: {{effective_date}}</p>

<p>This is to certify that <strong>{{employee_name}}</strong> (Staff ID: <strong>{{employee_id}}</strong>) was employed as a full-time staff member at <strong>{{institution_name}}</strong> in the Department of <strong>{{department}}</strong>.</p>

<p><strong>Employment Record:</strong></p>
<ul>
  <li><strong>Designation:</strong> {{designation}}</li>
  <li><strong>Tenure of Service:</strong> From {{joining_date}} to {{last_working_day}}</li>
  <li><strong>Primary Duties:</strong> Instructional delivery, curriculum design, and department coordination.</li>
</ul>

<p>During their tenure with us, {{employee_name}} demonstrated sincere commitment, academic rigor, and exemplary teamwork. Their conduct and character were consistently found to be of the highest standard.</p>

<p>We extend our deepest appreciation for their contributions and wish them every success in their future endeavors.</p>

<br><br>
<p>Authorized Signatory,</p>
<p><strong>{{hr_signatory_name}}</strong><br>
{{hr_signatory_title}}<br>
{{institution_name}}</p>',
            '["employee_name", "employee_id", "effective_date", "designation", "department", "joining_date", "last_working_day", "hr_signatory_name", "hr_signatory_title", "institution_name"]'::jsonb,
            true, true, true, admin_id
        )
        ON CONFLICT (school_id, template_code) DO UPDATE SET
            template_name = EXCLUDED.template_name,
            template_type = EXCLUDED.template_type,
            description = EXCLUDED.description,
            content_html = EXCLUDED.content_html,
            variables = EXCLUDED.variables,
            is_preset = true,
            is_active = true;

        -- 5. RELIEVING LETTER (Exit Discharge & No-Dues Clearance)
        INSERT INTO public.hr_document_templates (
            school_id, template_code, template_name, template_type, description,
            category_id, category_name, content_html, variables, is_preset, is_system, is_active, created_by
        ) VALUES (
            s.id, 'TMPL-RELV-01', 'Formal Relieving Order & No-Dues Clearance', 'Relieving Letter',
            'Official discharge letter certifying resignation acceptance, last working day, and full settlement.',
            v_cat_admin, 'Administration',
            '<p>Date: {{effective_date}}</p>
<p>Ref: REL/{{employee_id}}/2026</p>

<p>To,<br>
<strong>{{employee_name}}</strong><br>
Staff ID: {{employee_id}}<br>
Designation: {{designation}}</p>

<p><strong>SUBJECT: RELIEVING ORDER &amp; FULL SETTLEMENT CLEARANCE</strong></p>

<p>Dear {{employee_name}},</p>

<p>Consequent to your resignation dated {{effective_date}}, this is to certify that you have been formally relieved of your duties and responsibilities as <strong>{{designation}}</strong> in the <strong>{{department}}</strong> department at <strong>{{institution_name}}</strong> at the close of institutional hours on <strong>{{last_working_day}}</strong>.</p>

<p><strong>Clearance &amp; Handover Status:</strong></p>
<ul>
  <li>All institutional property, academic records, digital credentials, and physical assets have been surrendered.</li>
  <li>Departmental handover has been vetted and approved by your Head of Department.</li>
  <li>All financial accounts, advances, and full-and-final dues have been processed and settled in full.</li>
</ul>

<p>We thank you for your service and wish you the very best in your future professional commitments.</p>

<br>
<p>Sincerely,</p>
<p><strong>{{hr_signatory_name}}</strong><br>
{{hr_signatory_title}}<br>
{{institution_name}}</p>',
            '["employee_name", "employee_id", "effective_date", "designation", "department", "last_working_day", "hr_signatory_name", "hr_signatory_title", "institution_name"]'::jsonb,
            true, true, true, admin_id
        )
        ON CONFLICT (school_id, template_code) DO UPDATE SET
            template_name = EXCLUDED.template_name,
            template_type = EXCLUDED.template_type,
            description = EXCLUDED.description,
            content_html = EXCLUDED.content_html,
            variables = EXCLUDED.variables,
            is_preset = true,
            is_active = true;

        -- 6. NDA & CONFIDENTIALITY AGREEMENT
        INSERT INTO public.hr_document_templates (
            school_id, template_code, template_name, template_type, description,
            category_id, category_name, content_html, variables, is_preset, is_system, is_active, created_by
        ) VALUES (
            s.id, 'TMPL-NDA-01', 'Non-Disclosure & Confidentiality Agreement (NDA)', 'NDA & Confidentiality',
            'Covenant securing student records, exam papers, institutional trade secrets, and intellectual property.',
            v_cat_it, 'IT & System Access',
            '<p style="text-align: center;"><strong>PROPRIETARY INFORMATION &amp; NON-DISCLOSURE AGREEMENT</strong></p>

<p>This Agreement is entered into on <strong>{{effective_date}}</strong> by and between <strong>{{institution_name}}</strong> and <strong>{{employee_name}}</strong> (Staff ID: {{employee_id}}).</p>

<p><strong>1. Confidential Information:</strong><br>
Confidential information includes student personal dossiers, academic test papers, question banks, tuition records, proprietary curriculum, internal ERP credentials, and research data.</p>

<p><strong>2. Non-Disclosure Obligations:</strong><br>
The Employee agrees to hold all Confidential Information in strictest confidence and shall not copy, disclose, publish, or transfer any data to third parties without prior written consent.</p>

<p><strong>3. Student Data Privacy (FERPA / DPDP):</strong><br>
Strict adherence to statutory privacy acts protecting student identity and health information is mandatory.</p>

<p><strong>4. Return of Property:</strong><br>
Upon termination of service, all data, laptops, tokens, and records must be promptly returned.</p>

<br>
<p><strong>IN WITNESS WHEREOF, the parties hereto have executed this Agreement:</strong></p>
<p>Institution Representative: _____________________ &nbsp;&nbsp;&nbsp;&nbsp; Employee: _____________________</p>',
            '["employee_name", "employee_id", "effective_date", "institution_name"]'::jsonb,
            true, true, true, admin_id
        )
        ON CONFLICT (school_id, template_code) DO UPDATE SET
            template_name = EXCLUDED.template_name,
            template_type = EXCLUDED.template_type,
            description = EXCLUDED.description,
            content_html = EXCLUDED.content_html,
            variables = EXCLUDED.variables,
            is_preset = true,
            is_active = true;

        -- 7. CODE OF CONDUCT & ETHICS
        INSERT INTO public.hr_document_templates (
            school_id, template_code, template_name, template_type, description,
            category_id, category_name, content_html, variables, is_preset, is_system, is_active, created_by
        ) VALUES (
            s.id, 'TMPL-ETHIC-01', 'Institutional Code of Conduct & Ethics Policy', 'Code of Conduct',
            'Pedagogical decorum, POCSO/POSH compliance, digital asset standards, and conflict of interest declarations.',
            v_cat_emp, 'Employee Policies',
            '<p style="text-align: center;"><strong>INSTITUTIONAL CODE OF ETHICS &amp; PROFESSIONAL CONDUCT</strong></p>

<p>As a staff member of <strong>{{institution_name}}</strong>, <strong>{{employee_name}}</strong> agrees to adhere to the following core tenets:</p>

<ol>
  <li><strong>Child Protection &amp; Safety:</strong> Zero tolerance for child abuse or endangerment; mandatory compliance with POCSO / POSH statutory frameworks.</li>
  <li><strong>Professional Integrity:</strong> Impartial evaluation, punctual attendance, respectful engagement with students, parents, and colleagues.</li>
  <li><strong>Use of Campus Resources:</strong> Institutional IT assets, network bandwidth, and classrooms must be used exclusively for authorized academic and administrative tasks.</li>
  <li><strong>Conflict of Interest:</strong> Private tutoring or outside commercial interests using institutional credentials is strictly prohibited.</li>
</ol>

<br>
<p>I confirm that I have read, understood, and agree to abide by these guidelines.</p>
<p>Staff Name: {{employee_name}} &nbsp;&nbsp;&nbsp;&nbsp; ID: {{employee_id}} &nbsp;&nbsp;&nbsp;&nbsp; Date: {{effective_date}}</p>',
            '["employee_name", "employee_id", "effective_date", "institution_name"]'::jsonb,
            true, true, true, admin_id
        )
        ON CONFLICT (school_id, template_code) DO UPDATE SET
            template_name = EXCLUDED.template_name,
            template_type = EXCLUDED.template_type,
            description = EXCLUDED.description,
            content_html = EXCLUDED.content_html,
            variables = EXCLUDED.variables,
            is_preset = true,
            is_active = true;

        -- 8. SALARY INCREMENT & PROMOTION ORDER
        INSERT INTO public.hr_document_templates (
            school_id, template_code, template_name, template_type, description,
            category_id, category_name, content_html, variables, is_preset, is_system, is_active, created_by
        ) VALUES (
            s.id, 'TMPL-INCR-01', 'Annual Salary Increment & Merit Promotion Order', 'Salary Increment & Promotion',
            'Annual performance appraisal letter detailing revised gross compensation, title advancement, and effective date.',
            v_cat_fin, 'Financial Policies',
            '<p>Date: {{effective_date}}</p>
<p>To,<br>
<strong>{{employee_name}}</strong><br>
Staff ID: {{employee_id}}<br>
Department: {{department}}</p>

<p><strong>SUBJECT: ANNUAL PERFORMANCE APPRAISAL &amp; COMPENSATION REVISION</strong></p>

<p>Dear {{employee_name}},</p>

<p>In recognition of your commendable performance and pedagogical excellence during the preceding academic appraisal cycle, the Management of <strong>{{institution_name}}</strong> is pleased to announce a revision in your compensation package.</p>

<p><strong>Revision Details:</strong></p>
<ul>
  <li><strong>Designation:</strong> {{designation}}</li>
  <li><strong>Revised Annual CTC:</strong> {{salary}}</li>
  <li><strong>Effective Date:</strong> {{effective_date}}</li>
</ul>

<p>We appreciate your continuous dedication to our students and institutional vision.</p>

<br>
<p>Warm regards,</p>
<p><strong>{{hr_signatory_name}}</strong><br>
{{hr_signatory_title}}<br>
{{institution_name}}</p>',
            '["employee_name", "employee_id", "designation", "department", "salary", "effective_date", "hr_signatory_name", "hr_signatory_title", "institution_name"]'::jsonb,
            true, true, true, admin_id
        )
        ON CONFLICT (school_id, template_code) DO UPDATE SET
            template_name = EXCLUDED.template_name,
            template_type = EXCLUDED.template_type,
            description = EXCLUDED.description,
            content_html = EXCLUDED.content_html,
            variables = EXCLUDED.variables,
            is_preset = true,
            is_active = true;

        -- 9. JOINING CHECKLIST & STATUTORY AUDIT
        INSERT INTO public.hr_document_templates (
            school_id, template_code, template_name, template_type, description,
            category_id, category_name, content_html, variables, is_preset, is_system, is_active, created_by
        ) VALUES (
            s.id, 'TMPL-JOIN-01', 'Staff Onboarding & Document Verification Audit', 'Joining Checklist',
            'Comprehensive Day 1 onboarding verification table auditing proofs of identity, qualifications, and compliance.',
            v_cat_admin, 'Administration',
            '<p style="text-align: center;"><strong>EMPLOYEE ONBOARDING &amp; STATUTORY DOCUMENT AUDIT</strong></p>

<p>Employee Name: <strong>{{employee_name}}</strong> &nbsp;&nbsp;&nbsp;&nbsp; Staff ID: <strong>{{employee_id}}</strong><br>
Designation: <strong>{{designation}}</strong> &nbsp;&nbsp;&nbsp;&nbsp; Department: <strong>{{department}}</strong><br>
Joining Date: <strong>{{joining_date}}</strong></p>

<table border="1" cellpadding="6" style="width: 100%; border-collapse: collapse;">
  <tr style="background-color: #f1f5f9;">
    <th>Item #</th>
    <th>Statutory Document Required</th>
    <th>Submitted (Y/N)</th>
    <th>Verification Status</th>
  </tr>
  <tr><td>1</td><td>Government Identity Proof (Aadhaar / Passport)</td><td>[ &nbsp; ]</td><td>Verified</td></tr>
  <tr><td>2</td><td>PAN Card / Tax Registration Document</td><td>[ &nbsp; ]</td><td>Verified</td></tr>
  <tr><td>3</td><td>Highest Academic Degree &amp; Marksheets</td><td>[ &nbsp; ]</td><td>Verified</td></tr>
  <tr><td>4</td><td>Prior Employment Relieving &amp; Experience Certificate</td><td>[ &nbsp; ]</td><td>Verified</td></tr>
  <tr><td>5</td><td>Police Verification / Character Certificate</td><td>[ &nbsp; ]</td><td>Verified</td></tr>
  <tr><td>6</td><td>Medical Fitness Certificate</td><td>[ &nbsp; ]</td><td>Verified</td></tr>
  <tr><td>7</td><td>Direct Deposit Bank Account Details &amp; Cancelled Cheque</td><td>[ &nbsp; ]</td><td>Verified</td></tr>
  <tr><td>8</td><td>Signed Institutional Non-Disclosure Agreement (NDA)</td><td>[ &nbsp; ]</td><td>Verified</td></tr>
</table>

<br>
<p>Audited By HR Officer: __________________________ &nbsp;&nbsp;&nbsp;&nbsp; Date: ____________________</p>',
            '["employee_name", "employee_id", "designation", "department", "joining_date"]'::jsonb,
            true, true, true, admin_id
        )
        ON CONFLICT (school_id, template_code) DO UPDATE SET
            template_name = EXCLUDED.template_name,
            template_type = EXCLUDED.template_type,
            description = EXCLUDED.description,
            content_html = EXCLUDED.content_html,
            variables = EXCLUDED.variables,
            is_preset = true,
            is_active = true;

    END LOOP;
END $$;
