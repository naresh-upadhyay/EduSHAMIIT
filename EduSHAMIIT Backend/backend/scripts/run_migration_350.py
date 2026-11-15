import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
import asyncio
import datetime
import json
from app.api.recruitment import exec_sql

FULL_DDL = """
-- 1. ENHANCE EMPLOYEE ONBOARDING TABLE
ALTER TABLE public.employee_onboarding
    ADD COLUMN IF NOT EXISTS onboarding_code TEXT,
    ADD COLUMN IF NOT EXISTS department TEXT DEFAULT 'Academics',
    ADD COLUMN IF NOT EXISTS designation TEXT DEFAULT 'Teacher',
    ADD COLUMN IF NOT EXISTS employment_type TEXT DEFAULT 'Full-time',
    ADD COLUMN IF NOT EXISTS stage TEXT DEFAULT 'Offer Accepted',
    ADD COLUMN IF NOT EXISTS expected_joining_date DATE,
    ADD COLUMN IF NOT EXISTS actual_joining_date DATE,
    ADD COLUMN IF NOT EXISTS reporting_time TEXT DEFAULT '09:00 AM',
    ADD COLUMN IF NOT EXISTS reporting_location TEXT DEFAULT 'Main Campus - HR Dept',
    ADD COLUMN IF NOT EXISTS reporting_manager_id UUID,
    ADD COLUMN IF NOT EXISTS hr_owner_id UUID,
    ADD COLUMN IF NOT EXISTS probation_period_months INT DEFAULT 6,
    ADD COLUMN IF NOT EXISTS work_location TEXT DEFAULT 'Main Campus',
    ADD COLUMN IF NOT EXISTS shift TEXT DEFAULT 'General Shift',
    ADD COLUMN IF NOT EXISTS joining_status TEXT DEFAULT 'Expected',
    ADD COLUMN IF NOT EXISTS reschedule_reason TEXT,
    ADD COLUMN IF NOT EXISTS no_show_reason TEXT,
    ADD COLUMN IF NOT EXISTS satisfaction_score NUMERIC(4, 1) DEFAULT 92.0,
    ADD COLUMN IF NOT EXISTS template_name TEXT DEFAULT 'General Staff',
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS completion_override_reason TEXT;

-- 2. ONBOARDING DOCUMENTS TABLE
CREATE TABLE IF NOT EXISTS public.onboarding_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    onboarding_id UUID NOT NULL REFERENCES public.employee_onboarding(id) ON DELETE CASCADE,
    document_name TEXT NOT NULL,
    required_for TEXT DEFAULT 'All Employees',
    is_mandatory BOOLEAN DEFAULT true,
    status TEXT DEFAULT 'Pending',
    file_url TEXT,
    file_name TEXT,
    file_size_bytes BIGINT,
    uploaded_at TIMESTAMPTZ,
    verified_by UUID,
    verified_at TIMESTAMPTZ,
    rejection_reason TEXT,
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 3. ONBOARDING TASKS TABLE
CREATE TABLE IF NOT EXISTS public.onboarding_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    onboarding_id UUID NOT NULL REFERENCES public.employee_onboarding(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    category TEXT DEFAULT 'HR',
    assigned_to_id UUID,
    assigned_team TEXT DEFAULT 'HR Team',
    due_date DATE,
    priority TEXT DEFAULT 'Medium',
    status TEXT DEFAULT 'Pending',
    is_mandatory BOOLEAN DEFAULT true,
    completed_at TIMESTAMPTZ,
    completed_by UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 4. ONBOARDING ACTIVITIES TABLE
CREATE TABLE IF NOT EXISTS public.onboarding_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    onboarding_id UUID NOT NULL REFERENCES public.employee_onboarding(id) ON DELETE CASCADE,
    user_id UUID,
    action TEXT NOT NULL,
    description TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 5. ONBOARDING TEMPLATES TABLE
CREATE TABLE IF NOT EXISTS public.onboarding_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    department TEXT DEFAULT 'General',
    description TEXT,
    default_tasks JSONB DEFAULT '[]'::jsonb,
    default_documents JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 6. INDEXES
CREATE INDEX IF NOT EXISTS idx_emp_onb_school_stage ON public.employee_onboarding(school_id, stage);
CREATE INDEX IF NOT EXISTS idx_emp_onb_school_status ON public.employee_onboarding(school_id, status);
CREATE INDEX IF NOT EXISTS idx_emp_onb_candidate ON public.employee_onboarding(school_id, candidate_id);
CREATE INDEX IF NOT EXISTS idx_emp_onb_dept ON public.employee_onboarding(school_id, department);
CREATE INDEX IF NOT EXISTS idx_onb_docs_onb ON public.onboarding_documents(onboarding_id, status);
CREATE INDEX IF NOT EXISTS idx_onb_tasks_onb ON public.onboarding_tasks(onboarding_id, status);
CREATE INDEX IF NOT EXISTS idx_onb_act_onb ON public.onboarding_activities(onboarding_id, created_at DESC);
"""

TEMPLATES = [
    {
        "name": "Teaching Staff Onboarding",
        "department": "Academics",
        "description": "Comprehensive onboarding workflow for PGT, TGT, PRT teachers and academic educators.",
        "default_documents": [
            {"document_name": "Offer Letter", "required_for": "All Employees", "is_mandatory": True},
            {"document_name": "ID Proof (Aadhaar / Passport)", "required_for": "All Employees", "is_mandatory": True},
            {"document_name": "Educational Certificates & Degrees", "required_for": "Teaching Staff", "is_mandatory": True},
            {"document_name": "Experience & Relieving Letters", "required_for": "Teaching Staff", "is_mandatory": True},
            {"document_name": "Medical Fitness Certificate", "required_for": "All Employees", "is_mandatory": True},
            {"document_name": "Bank Account Details (Cancelled Cheque)", "required_for": "All Employees", "is_mandatory": True}
        ],
        "default_tasks": [
            {"title": "Collect Personal Documents", "category": "HR", "assigned_team": "HR Team", "days_offset": 1, "priority": "High", "is_mandatory": True},
            {"title": "IT Access & School Email Setup", "category": "IT", "assigned_team": "IT Team", "days_offset": 2, "priority": "High", "is_mandatory": True},
            {"title": "Orientation & Induction Session", "category": "Administration", "assigned_team": "Admin Team", "days_offset": 3, "priority": "Medium", "is_mandatory": True},
            {"title": "School Biometric & ID Card Issuance", "category": "Security", "assigned_team": "Security Team", "days_offset": 4, "priority": "Medium", "is_mandatory": True},
            {"title": "Curriculum Handover & Timetable Assignment", "category": "Department", "assigned_team": "Academic Head", "days_offset": 5, "priority": "High", "is_mandatory": True},
            {"title": "School Policy Acknowledgement & Handbook", "category": "HR", "assigned_team": "HR Team", "days_offset": 5, "priority": "Medium", "is_mandatory": True}
        ]
    },
    {
        "name": "Administrative Staff Onboarding",
        "department": "Administration",
        "description": "Onboarding pipeline for office executives, accountants, admissions, and coordinators.",
        "default_documents": [
            {"document_name": "Offer Letter", "required_for": "All Employees", "is_mandatory": True},
            {"document_name": "ID Proof & Address Proof", "required_for": "All Employees", "is_mandatory": True},
            {"document_name": "Highest Degree Qualification", "required_for": "Admin Staff", "is_mandatory": True},
            {"document_name": "Relieving Letter from Previous Employer", "required_for": "Admin Staff", "is_mandatory": True},
            {"document_name": "Bank Account & PAN Details", "required_for": "All Employees", "is_mandatory": True}
        ],
        "default_tasks": [
            {"title": "Document Collection & Background Verification", "category": "HR", "assigned_team": "HR Team", "days_offset": 1, "priority": "High", "is_mandatory": True},
            {"title": "ERP System Credentials & Access Rights", "category": "IT", "assigned_team": "IT Team", "days_offset": 2, "priority": "High", "is_mandatory": True},
            {"title": "Workstation & Telephone Allocation", "category": "Administration", "assigned_team": "Admin Team", "days_offset": 3, "priority": "Medium", "is_mandatory": True},
            {"title": "Department SOP & Process Walkthrough", "category": "Department", "assigned_team": "Admin Head", "days_offset": 4, "priority": "Medium", "is_mandatory": True}
        ]
    },
    {
        "name": "IT & Technical Staff Onboarding",
        "department": "IT / Technical",
        "description": "Setup workflow for lab assistants, IT engineers, systems admins and portal technicians.",
        "default_documents": [
            {"document_name": "Offer Letter", "required_for": "All Employees", "is_mandatory": True},
            {"document_name": "ID Proof & PAN Card", "required_for": "All Employees", "is_mandatory": True},
            {"document_name": "Technical Certifications & Degrees", "required_for": "IT Staff", "is_mandatory": True},
            {"document_name": "Bank Details", "required_for": "All Employees", "is_mandatory": True}
        ],
        "default_tasks": [
            {"title": "Identity Verification & Document Scrutiny", "category": "HR", "assigned_team": "HR Team", "days_offset": 1, "priority": "High", "is_mandatory": True},
            {"title": "Root / Admin Privileges & Hardware Provisioning", "category": "IT", "assigned_team": "IT Team", "days_offset": 1, "priority": "Urgent", "is_mandatory": True},
            {"title": "Network Security & Protocol Briefing", "category": "IT", "assigned_team": "Security Lead", "days_offset": 2, "priority": "High", "is_mandatory": True},
            {"title": "Asset Registry Sign-off", "category": "Administration", "assigned_team": "Admin Team", "days_offset": 3, "priority": "Medium", "is_mandatory": True}
        ]
    },
    {
        "name": "Transport & Support Staff Onboarding",
        "department": "Transport",
        "description": "Onboarding for school bus drivers, conductors, security officers, and estate personnel.",
        "default_documents": [
            {"document_name": "Offer Letter", "required_for": "All Employees", "is_mandatory": True},
            {"document_name": "Commercial Driving License / Badge", "required_for": "Transport Staff", "is_mandatory": True},
            {"document_name": "Police Clearance Certificate", "required_for": "Support Staff", "is_mandatory": True},
            {"document_name": "Medical Fitness & Eye Vision Certificate", "required_for": "All Drivers", "is_mandatory": True},
            {"document_name": "Bank Account Details", "required_for": "All Employees", "is_mandatory": True}
        ],
        "default_tasks": [
            {"title": "License & Commercial Badge Physical Verification", "category": "HR", "assigned_team": "HR Team", "days_offset": 1, "priority": "Urgent", "is_mandatory": True},
            {"title": "Route Training & Vehicle Telemetry Orientation", "category": "Department", "assigned_team": "Transport Manager", "days_offset": 2, "priority": "High", "is_mandatory": True},
            {"title": "Uniform & Biometric Device ID Issuance", "category": "Administration", "assigned_team": "Admin Team", "days_offset": 3, "priority": "Medium", "is_mandatory": True}
        ]
    }
]

async def migrate():
    print("🚀 Starting Onboarding Migration 350...")
    
    # 1. Execute Full DDL
    await exec_sql(FULL_DDL, fetch=False)
    print("✅ Schema tables, constraints, and indexes created successfully!")

    # 2. Get school ID
    schools = await exec_sql("SELECT id FROM public.schools LIMIT 1;")
    if not schools:
        print("❌ No schools found in database.")
        return
    school_id = str(schools[0]["id"])
    print(f"Target School ID: {school_id}")

    # 3. Seed Onboarding Templates
    for tmpl in TEMPLATES:
        await exec_sql("""
            INSERT INTO public.onboarding_templates (school_id, name, department, description, default_tasks, default_documents)
            VALUES (%s, %s, %s, %s, %s::jsonb, %s::jsonb);
        """, (
            school_id,
            tmpl["name"],
            tmpl["department"],
            tmpl["description"],
            json.dumps(tmpl["default_tasks"]),
            json.dumps(tmpl["default_documents"])
        ), fetch=False)
    print("✅ Onboarding templates seeded.")

    # 4. Fetch candidates
    candidates = await exec_sql("""
        SELECT c.id, c.full_name, c.email, c.phone, c.candidate_code
        FROM public.recruitment_candidates c
        WHERE c.school_id = %s AND c.is_deleted = false
        LIMIT 60;
    """, (school_id,))
    
    if len(candidates) < 48:
        candidates = await exec_sql("""
            SELECT c.id, c.full_name, c.email, c.phone, c.candidate_code
            FROM public.recruitment_candidates c
            LIMIT 60;
        """)

    print(f"Found {len(candidates)} candidates for onboarding distribution.")

    departments_pool = (
        ["Academics"] * 16 +
        ["Administration"] * 9 +
        ["IT / Technical"] * 8 +
        ["Finance"] * 6 +
        ["Transport"] * 5 +
        ["Others"] * 4
    )

    designations_map = {
        "Academics": ["Physics Teacher", "Computer Science Teacher", "Mathematics Teacher", "English Lecturer", "Biology Teacher"],
        "Administration": ["Front Office Executive", "Administrative Officer", "Admissions Coordinator", "Registrar"],
        "IT / Technical": ["IT Support Executive", "Network Administrator", "Lab Assistant", "Systems Engineer"],
        "Finance": ["Accountant", "Accounts Executive", "Fee Billing Officer"],
        "Transport": ["Transport Coordinator", "Senior Fleet Driver", "Vehicle Supervisor"],
        "Others": ["Librarian", "Campus Counselor", "Sports Coach"]
    }

    stages_plan = (
        [("Completed", "Completed")] * 27 +
        [("Training", "In Progress")] * 1 +
        [("IT Setup", "In Progress")] * 4 +
        [("Orientation", "In Progress")] * 6 +
        [("Document Collection", "In Progress")] * 1 +
        [("Document Collection", "Pending")] * 3 +
        [("Offer Accepted", "Pending")] * 6
    )

    # Clean existing test onboarding for clean sync
    await exec_sql("DELETE FROM public.onboarding_activities WHERE school_id = %s;", (school_id,), fetch=False)
    await exec_sql("DELETE FROM public.onboarding_documents WHERE school_id = %s;", (school_id,), fetch=False)
    await exec_sql("DELETE FROM public.onboarding_tasks WHERE school_id = %s;", (school_id,), fetch=False)
    await exec_sql("DELETE FROM public.employee_onboarding WHERE school_id = %s;", (school_id,), fetch=False)

    today = datetime.date(2026, 9, 9)

    for i in range(min(48, len(candidates))):
        cand = candidates[i]
        dept = departments_pool[i]
        desigs = designations_map.get(dept, ["Executive"])
        desig = desigs[i % len(desigs)]
        stage, status = stages_plan[i]
        onb_code = f"EMP{1267 + i}"
        joining_date = today + datetime.timedelta(days=(i - 20))
        
        # Insert onboarding record
        res = await exec_sql("""
            INSERT INTO public.employee_onboarding (
                school_id, candidate_id, onboarding_code, department, designation,
                employment_type, stage, status, joining_date, expected_joining_date,
                actual_joining_date, reporting_time, reporting_location, probation_period_months,
                work_location, shift, joining_status, satisfaction_score, template_name,
                completed_at
            ) VALUES (
                %s, %s, %s, %s, %s,
                'Full-time', %s, %s, %s, %s,
                %s, '09:00 AM', 'Main Campus - HR Dept', 6,
                'Main Campus', 'General Shift', %s, 92.0, %s,
                %s
            ) RETURNING id;
        """, (
            school_id,
            cand["id"],
            onb_code,
            dept,
            desig,
            stage,
            status,
            joining_date,
            joining_date,
            joining_date if status == "Completed" else None,
            "Joined" if status == "Completed" else "Expected",
            f"{dept} Onboarding",
            today if status == "Completed" else None
        ))
        
        onb_id = str(res[0]["id"])

        # Seed Documents for this record
        is_completed = (status == "Completed")
        doc_status_pool = ["Uploaded", "Verified"] if is_completed else (["Uploaded"] if stage in ["Orientation", "IT Setup", "Training"] else ["Pending", "Uploaded"])
        
        docs = [
            ("Offer Letter", "All Employees", "Verified" if is_completed else "Uploaded"),
            ("ID Proof", "All Employees", "Verified" if is_completed else "Uploaded"),
            ("Educational Certificates", "Teaching Staff" if dept == "Academics" else "All Employees", "Verified" if is_completed else (doc_status_pool[i % len(doc_status_pool)])),
            ("Medical Fitness Certificate", "All Employees", "Verified" if is_completed else "Uploaded"),
            ("Bank Account Details", "All Employees", "Verified" if is_completed else (doc_status_pool[(i + 1) % len(doc_status_pool)]))
        ]

        for doc_name, req_for, d_status in docs:
            await exec_sql("""
                INSERT INTO public.onboarding_documents (
                    school_id, onboarding_id, document_name, required_for, is_mandatory, status,
                    file_name, file_url, uploaded_at, verified_at
                ) VALUES (
                    %s, %s, %s, %s, true, %s,
                    %s, 'https://storage.edushamiit.edu/documents/sample.pdf',
                    now(), %s
                );
            """, (
                school_id,
                onb_id,
                doc_name,
                req_for,
                d_status,
                f"{doc_name.lower().replace(' ', '_')}.pdf",
                today if d_status == "Verified" else None
            ), fetch=False)

        # Seed Tasks for this record
        tasks = [
            ("Collect Personal Documents", "HR", "HR Team", -3, "High", "Completed" if is_completed or stage != "Offer Accepted" else "Overdue"),
            ("IT Access & Email Setup", "IT", "IT Team", 1, "High", "Completed" if is_completed or stage in ["Orientation", "IT Setup", "Training"] else "In Progress"),
            ("Orientation Session", "Administration", "Admin Team", 2, "Medium", "Completed" if is_completed or stage in ["Orientation", "IT Setup", "Training"] else "Pending"),
            ("ID Card & Access", "Security", "Security Team", 4, "Medium", "Completed" if is_completed else "Pending"),
            ("Policy Acknowledgement", "HR", "HR Team", 5, "Medium", "Completed" if is_completed else "In Progress")
        ]

        for t_title, t_cat, t_team, offset_days, priority, t_status in tasks:
            due = today + datetime.timedelta(days=offset_days)
            await exec_sql("""
                INSERT INTO public.onboarding_tasks (
                    school_id, onboarding_id, title, category, assigned_team, due_date, priority, status,
                    is_mandatory, completed_at
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, true, %s
                );
            """, (
                school_id,
                onb_id,
                t_title,
                t_cat,
                t_team,
                due,
                priority,
                t_status,
                today if t_status == "Completed" else None
            ), fetch=False)

        # Seed Activity log
        await exec_sql("""
            INSERT INTO public.onboarding_activities (school_id, onboarding_id, action, description, created_at)
            VALUES (%s, %s, 'Started', %s, now() - interval '%s hours');
        """, (
            school_id,
            onb_id,
            f"Onboarding initiated for {cand['full_name']} ({desig})",
            (48 - i) * 2
        ), fetch=False)

    print("🎉 Successfully seeded 48 realistic onboarding records with documents, tasks, and audit logs!")

if __name__ == "__main__":
    asyncio.run(migrate())
