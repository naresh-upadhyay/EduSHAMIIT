-- ============================================================================
-- Migration 489: Enterprise Sprint Team Management Workspace
-- EduSHAMIIT Multi-Tenant Institute ERP Platform
-- Centralized Team Administration, Member Directory, Cross-Sprint Capacity,
-- Dynamic Workload Allocation, Role Mapping, and Audit Logging
-- ============================================================================

-- 1. Extend work_teams table with rich enterprise metadata
ALTER TABLE public.work_teams
    ADD COLUMN IF NOT EXISTS team_key VARCHAR(20),
    ADD COLUMN IF NOT EXISTS color VARCHAR(20) DEFAULT '#2563EB',
    ADD COLUMN IF NOT EXISTS visibility VARCHAR(50) DEFAULT 'INSTITUTE',
    ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'ACTIVE',
    ADD COLUMN IF NOT EXISTS default_capacity_hours NUMERIC(10,2) DEFAULT 280.0,
    ADD COLUMN IF NOT EXISTS working_days INT DEFAULT 5,
    ADD COLUMN IF NOT EXISTS daily_hours NUMERIC(5,2) DEFAULT 8.0,
    ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT ARRAY['Digital Campus', 'Student Portal', 'Academics', 'Integration'],
    ADD COLUMN IF NOT EXISTS goal TEXT,
    ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT FALSE;

-- 2. Link work_items directly to work_teams
ALTER TABLE public.work_items
    ADD COLUMN IF NOT EXISTS team_id UUID REFERENCES public.work_teams(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS team_name VARCHAR(100);

CREATE INDEX IF NOT EXISTS idx_work_items_team_id ON public.work_items(team_id);

-- 3. Create work_team_members table for centralized team membership
CREATE TABLE IF NOT EXISTS public.work_team_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES public.work_teams(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role VARCHAR(100) DEFAULT 'Developer',
    capacity_hours NUMERIC(10,2) DEFAULT 40.0,
    daily_hours NUMERIC(5,2) DEFAULT 8.0,
    is_lead BOOLEAN DEFAULT FALSE,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_work_team_member UNIQUE(team_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_work_team_members_team ON public.work_team_members(team_id);
CREATE INDEX IF NOT EXISTS idx_work_team_members_user ON public.work_team_members(user_id);

-- 4. Create work_team_activities table for team audit logs
CREATE TABLE IF NOT EXISTS public.work_team_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES public.work_teams(id) ON DELETE CASCADE,
    activity_type VARCHAR(50) NOT NULL, -- CAPACITY_UPDATED, MEMBER_ADDED, MEMBER_REMOVED, GOAL_UPDATED, TEAM_CREATED, TEAM_UPDATED
    description TEXT NOT NULL,
    actor_name VARCHAR(150) NOT NULL DEFAULT 'System Admin',
    actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_work_team_activities_team ON public.work_team_activities(team_id, created_at DESC);

-- 5. Seed Enterprise Team Records and Distinct Members
DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_sprint_id UUID;
    v_t_dct UUID;
    v_t_ast UUID;
    v_t_ext UUID;
    v_t_iot UUID;
    v_t_imt UUID;
    v_t_lst UUID;
    
    v_u UUID;
    v_email TEXT;
    v_i INT;
    v_member_ids UUID[] := ARRAY[]::UUID[];
    v_names TEXT[] := ARRAY[
        -- Digital Campus Team (7)
        'Neha Sharma', 'Amit Kumar', 'Priya Singh', 'Rahul Mehta', 'Sneha Verma', 'Vikas Gupta', 'Karan Jain',
        -- Academic Systems Team (8)
        'Dr. Rajesh Verma', 'Sunita Rao', 'Arun Patel', 'Meera Nair', 'Deepak Joshi', 'Kavita Roy', 'Manoj Tiwari', 'Pooja Bhatia',
        -- Examination Team (6)
        'Suresh Deshmukh', 'Anjali Saxena', 'Ramesh Pillai', 'Bhavna Kulkarni', 'Gaurav Seth', 'Divya Menon',
        -- IT Operations Team (8)
        'Harish Nambiar', 'Ritu Chopra', 'Alok Pandey', 'Swati Sen', 'Naveen Reddy', 'Preeti Aggarwal', 'Siddharth Bose', 'Monica Chawla',
        -- Infrastructure & Maintenance Team (7)
        'Rajeev Singhal', 'Usha Hegde', 'Tarun Mittal', 'Geeta Das', 'Sanjay Kapoor', 'Kiran Varma', 'Mohit Grover',
        -- Library Systems Team (6)
        'Archana Shukla', 'Pradeep Yadav', 'Leela Nair', 'Ashok Mathur', 'Shalini Iyer', 'Nitin Kaushik'
    ];
    v_roles TEXT[] := ARRAY[
        -- DCT
        'Team Lead', 'Senior Developer', 'UI/UX Designer', 'Backend Developer', 'QA Engineer', 'DevOps Engineer', 'System Analyst',
        -- AST
        'Team Lead', 'Curriculum Specialist', 'Academic Analyst', 'Senior Developer', 'Fullstack Engineer', 'Data Modeler', 'QA Engineer', 'Scrum Master',
        -- EXT
        'Team Lead', 'Controller of Exams', 'Evaluation Officer', 'Security Architect', 'Database Admin', 'QA Specialist',
        -- IOT
        'Team Lead', 'Cloud Architect', 'Network Engineer', 'Security Analyst', 'Site Reliability Eng', 'Linux SysAdmin', 'Storage Admin', 'DevOps Specialist',
        -- IMT
        'Team Lead', 'Facilities Manager', 'Electrical Engineer', 'Civil Asset Head', 'IoT Architect', 'Safety Auditor', 'Support Lead',
        -- LST
        'Team Lead', 'Digital Archivist', 'Catalog Specialist', 'RFID Integrator', 'Systems Librarian', 'User Support Specialist'
    ];
    v_avatars TEXT[] := ARRAY[
        'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=120',
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120',
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120',
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=120',
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120',
        'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=120',
        'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=120',
        'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=120',
        'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=120',
        'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=120',
        'https://images.unsplash.com/photo-1567532939604-b6b5b0db2604?w=120',
        'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=120',
        'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=120',
        'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=120',
        'https://images.unsplash.com/photo-1517486808906-6ca8b3f04846?w=120',
        'https://images.unsplash.com/photo-1522529599102-193c0d76b5b6?w=120',
        'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=120',
        'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?w=120',
        'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=120',
        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120',
        'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=120',
        'https://images.unsplash.com/photo-1543610892-0b1f7e6d8ac1?w=120',
        'https://images.unsplash.com/photo-1520813792240-56fc4a3765a7?w=120',
        'https://images.unsplash.com/photo-1548142813-c348350df52b?w=120',
        'https://images.unsplash.com/photo-1544717305-2782549b5136?w=120',
        'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=120',
        'https://images.unsplash.com/photo-1573497019940-1c28c88b4f3e?w=120',
        'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=120',
        'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=120',
        'https://images.unsplash.com/photo-1463453091185-61582044d556?w=120',
        'https://images.unsplash.com/photo-1534751516642-a171ed243542?w=120',
        'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=120',
        'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=120',
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=120',
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120',
        'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=120',
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120',
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120',
        'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=120',
        'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=120',
        'https://images.unsplash.com/photo-1567532939604-b6b5b0db2604?w=120',
        'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=120'
    ];
BEGIN
    SELECT id INTO v_sprint_id FROM public.work_sprints WHERE name = 'Sprint 8' LIMIT 1;
    IF v_sprint_id IS NULL THEN
        SELECT id INTO v_sprint_id FROM public.work_sprints LIMIT 1;
    END IF;

    -- Upsert profiles for all 42 members cleanly
    FOR v_i IN 1..42 LOOP
        v_email := LOWER(REPLACE(v_names[v_i], ' ', '.')) || '@edushamiit.com';
        SELECT id INTO v_u FROM public.profiles WHERE LOWER(TRIM(email)) = LOWER(TRIM(v_email));
        
        IF v_u IS NULL THEN
            v_u := ('55555555-0000-0000-0000-' || LPAD(v_i::text, 12, '0'))::UUID;
            INSERT INTO public.profiles (
                id, school_id, user_id, full_name, email, role, department, designation, status, avatar_url
            ) VALUES (
                v_u, v_school_id, 'usr_team_mem_' || v_i, v_names[v_i], v_email,
                'teacher', 'Institute Work Group', v_roles[v_i], 'Active', v_avatars[v_i]
            ) ON CONFLICT (id) DO UPDATE SET
                full_name = EXCLUDED.full_name,
                designation = EXCLUDED.designation,
                avatar_url = EXCLUDED.avatar_url;
        ELSE
            UPDATE public.profiles SET
                full_name = v_names[v_i],
                designation = v_roles[v_i],
                avatar_url = v_avatars[v_i]
            WHERE id = v_u;
        END IF;
        
        v_member_ids := array_append(v_member_ids, v_u);
    END LOOP;

    -- Update 6 Teams with exact Reference Design specifications
    -- 1. Digital Campus Team
    INSERT INTO public.work_teams (
        school_id, name, team_key, department, lead_id, description, icon, color,
        is_active, status, default_capacity_hours, working_days, daily_hours, tags, goal, created_at, updated_at
    ) VALUES (
        v_school_id, 'Digital Campus Team', 'DCT', 'IT & Digitalization',
        v_member_ids[1],
        'Student portal, academic systems and digital campus solutions.',
        'layers', '#2563EB', TRUE, 'ACTIVE', 280.0, 5, 8.0,
        ARRAY['Digital Campus', 'Student Portal', 'Academics', 'Integration'],
        'Deliver student portal enhancement, examination notifications and key infrastructure fixes.',
        '2024-12-10 09:00:00+00', '2025-01-06 10:24:00+00'
    ) ON CONFLICT (school_id, name) DO UPDATE SET
        team_key = EXCLUDED.team_key,
        department = EXCLUDED.department,
        lead_id = EXCLUDED.lead_id,
        description = EXCLUDED.description,
        icon = EXCLUDED.icon,
        tags = EXCLUDED.tags,
        goal = EXCLUDED.goal,
        status = 'ACTIVE',
        is_active = TRUE,
        default_capacity_hours = 280.0;

    SELECT id INTO v_t_dct FROM public.work_teams WHERE school_id = v_school_id AND name = 'Digital Campus Team';

    -- 2. Academic Systems Team
    INSERT INTO public.work_teams (
        school_id, name, team_key, department, lead_id, description, icon, color,
        is_active, status, default_capacity_hours, working_days, daily_hours, tags, goal, created_at, updated_at
    ) VALUES (
        v_school_id, 'Academic Systems Team', 'AST', 'Academics',
        v_member_ids[8],
        'Academic planning, curriculum and evaluation engines.',
        'school', '#0284C7', TRUE, 'ACTIVE', 320.0, 5, 8.0,
        ARRAY['Curriculum', 'Syllabus', 'Grading', 'Faculty'],
        'Implement curriculum planner and grading system updates.',
        '2024-12-12 10:00:00+00', '2025-01-06 11:00:00+00'
    ) ON CONFLICT (school_id, name) DO UPDATE SET
        team_key = EXCLUDED.team_key,
        department = EXCLUDED.department,
        lead_id = EXCLUDED.lead_id,
        description = EXCLUDED.description,
        icon = EXCLUDED.icon,
        tags = EXCLUDED.tags,
        goal = EXCLUDED.goal,
        status = 'ACTIVE',
        is_active = TRUE,
        default_capacity_hours = 320.0;

    SELECT id INTO v_t_ast FROM public.work_teams WHERE school_id = v_school_id AND name = 'Academic Systems Team';

    -- 3. Examination Team
    INSERT INTO public.work_teams (
        school_id, name, team_key, department, lead_id, description, icon, color,
        is_active, status, default_capacity_hours, working_days, daily_hours, tags, goal, created_at, updated_at
    ) VALUES (
        v_school_id, 'Examination Team', 'EXT', 'Examinations',
        v_member_ids[16],
        'Examination, assessment and result processing.',
        'assignment', '#7C3AED', TRUE, 'ACTIVE', 240.0, 5, 8.0,
        ARRAY['Exams', 'Hall Tickets', 'Grading', 'Results'],
        'Publish mid-term exam schedule and seat allocation module.',
        '2024-12-14 11:00:00+00', '2025-01-05 14:00:00+00'
    ) ON CONFLICT (school_id, name) DO UPDATE SET
        team_key = EXCLUDED.team_key,
        department = EXCLUDED.department,
        lead_id = EXCLUDED.lead_id,
        description = EXCLUDED.description,
        icon = EXCLUDED.icon,
        tags = EXCLUDED.tags,
        goal = EXCLUDED.goal,
        status = 'ACTIVE',
        is_active = TRUE,
        default_capacity_hours = 240.0;

    SELECT id INTO v_t_ext FROM public.work_teams WHERE school_id = v_school_id AND name = 'Examination Team';

    -- 4. IT Operations Team
    INSERT INTO public.work_teams (
        school_id, name, team_key, department, lead_id, description, icon, color,
        is_active, status, default_capacity_hours, working_days, daily_hours, tags, goal, created_at, updated_at
    ) VALUES (
        v_school_id, 'IT Operations Team', 'IOT', 'IT Operations',
        v_member_ids[22],
        'Infrastructure, operations and technical support.',
        'computer', '#0D9488', TRUE, 'ACTIVE', 320.0, 5, 8.0,
        ARRAY['Cloud', 'DevOps', 'Security', 'Maintenance'],
        'Migrate database replicas and configure container load balancers.',
        '2024-12-15 08:30:00+00', '2025-01-06 09:15:00+00'
    ) ON CONFLICT (school_id, name) DO UPDATE SET
        team_key = EXCLUDED.team_key,
        department = EXCLUDED.department,
        lead_id = EXCLUDED.lead_id,
        description = EXCLUDED.description,
        icon = EXCLUDED.icon,
        tags = EXCLUDED.tags,
        goal = EXCLUDED.goal,
        status = 'ACTIVE',
        is_active = TRUE,
        default_capacity_hours = 320.0;

    SELECT id INTO v_t_iot FROM public.work_teams WHERE school_id = v_school_id AND name = 'IT Operations Team';

    -- 5. Infrastructure & Maintenance Team
    INSERT INTO public.work_teams (
        school_id, name, team_key, department, lead_id, description, icon, color,
        is_active, status, default_capacity_hours, working_days, daily_hours, tags, goal, created_at, updated_at
    ) VALUES (
        v_school_id, 'Infrastructure & Maintenance Team', 'IMT', 'Administration',
        v_member_ids[30],
        'Campus infrastructure and facility maintenance.',
        'settings', '#D97706', TRUE, 'ACTIVE', 280.0, 5, 8.0,
        ARRAY['Facilities', 'Hostels', 'Assets', 'Repairs'],
        'Campus IoT smart lighting and classroom projector upgrades.',
        '2024-12-18 12:00:00+00', '2025-01-04 16:20:00+00'
    ) ON CONFLICT (school_id, name) DO UPDATE SET
        team_key = EXCLUDED.team_key,
        department = EXCLUDED.department,
        lead_id = EXCLUDED.lead_id,
        description = EXCLUDED.description,
        icon = EXCLUDED.icon,
        tags = EXCLUDED.tags,
        goal = EXCLUDED.goal,
        status = 'ACTIVE',
        is_active = TRUE,
        default_capacity_hours = 280.0;

    SELECT id INTO v_t_imt FROM public.work_teams WHERE school_id = v_school_id AND name = 'Infrastructure & Maintenance Team';

    -- 6. Library Systems Team
    INSERT INTO public.work_teams (
        school_id, name, team_key, department, lead_id, description, icon, color,
        is_active, status, default_capacity_hours, working_days, daily_hours, tags, goal, created_at, updated_at
    ) VALUES (
        v_school_id, 'Library Systems Team', 'LST', 'Library',
        v_member_ids[37],
        'Library management system, digital resources and RFID.',
        'menu_book', '#DC2626', TRUE, 'ACTIVE', 240.0, 5, 8.0,
        ARRAY['Library', 'RFID', 'Journals', 'Catalog'],
        'Automate RFID book drops and integrate e-book subscription catalog.',
        '2024-12-20 14:00:00+00', '2025-01-05 17:00:00+00'
    ) ON CONFLICT (school_id, name) DO UPDATE SET
        team_key = EXCLUDED.team_key,
        department = EXCLUDED.department,
        lead_id = EXCLUDED.lead_id,
        description = EXCLUDED.description,
        icon = EXCLUDED.icon,
        tags = EXCLUDED.tags,
        goal = EXCLUDED.goal,
        status = 'ACTIVE',
        is_active = TRUE,
        default_capacity_hours = 240.0;

    SELECT id INTO v_t_lst FROM public.work_teams WHERE school_id = v_school_id AND name = 'Library Systems Team';

    -- Populate team members for each team (Total = 42 members across 6 teams)
    -- Digital Campus Team (1..7)
    FOR v_i IN 1..7 LOOP
        INSERT INTO public.work_team_members (school_id, team_id, user_id, role, capacity_hours, is_lead)
        VALUES (v_school_id, v_t_dct, v_member_ids[v_i], v_roles[v_i], 40.0, (v_i = 1))
        ON CONFLICT (team_id, user_id) DO UPDATE SET role = EXCLUDED.role, is_lead = EXCLUDED.is_lead;
    END LOOP;

    -- Academic Systems Team (8..15)
    FOR v_i IN 8..15 LOOP
        INSERT INTO public.work_team_members (school_id, team_id, user_id, role, capacity_hours, is_lead)
        VALUES (v_school_id, v_t_ast, v_member_ids[v_i], v_roles[v_i], 40.0, (v_i = 8))
        ON CONFLICT (team_id, user_id) DO UPDATE SET role = EXCLUDED.role, is_lead = EXCLUDED.is_lead;
    END LOOP;

    -- Examination Team (16..21)
    FOR v_i IN 16..21 LOOP
        INSERT INTO public.work_team_members (school_id, team_id, user_id, role, capacity_hours, is_lead)
        VALUES (v_school_id, v_t_ext, v_member_ids[v_i], v_roles[v_i], 40.0, (v_i = 16))
        ON CONFLICT (team_id, user_id) DO UPDATE SET role = EXCLUDED.role, is_lead = EXCLUDED.is_lead;
    END LOOP;

    -- IT Operations Team (22..29)
    FOR v_i IN 22..29 LOOP
        INSERT INTO public.work_team_members (school_id, team_id, user_id, role, capacity_hours, is_lead)
        VALUES (v_school_id, v_t_iot, v_member_ids[v_i], v_roles[v_i], 40.0, (v_i = 22))
        ON CONFLICT (team_id, user_id) DO UPDATE SET role = EXCLUDED.role, is_lead = EXCLUDED.is_lead;
    END LOOP;

    -- Infrastructure & Maintenance Team (30..36)
    FOR v_i IN 30..36 LOOP
        INSERT INTO public.work_team_members (school_id, team_id, user_id, role, capacity_hours, is_lead)
        VALUES (v_school_id, v_t_imt, v_member_ids[v_i], v_roles[v_i], 40.0, (v_i = 30))
        ON CONFLICT (team_id, user_id) DO UPDATE SET role = EXCLUDED.role, is_lead = EXCLUDED.is_lead;
    END LOOP;

    -- Library Systems Team (37..42)
    FOR v_i IN 37..42 LOOP
        INSERT INTO public.work_team_members (school_id, team_id, user_id, role, capacity_hours, is_lead)
        VALUES (v_school_id, v_t_lst, v_member_ids[v_i], v_roles[v_i], 40.0, (v_i = 37))
        ON CONFLICT (team_id, user_id) DO UPDATE SET role = EXCLUDED.role, is_lead = EXCLUDED.is_lead;
    END LOOP;

    -- Ensure sprint_team_capacities records exist for all 6 teams in active sprint
    IF v_sprint_id IS NOT NULL THEN
        INSERT INTO public.sprint_team_capacities (
            school_id, sprint_id, team_name, total_capacity_hours, planned_work_hours,
            remaining_capacity_hours, utilization_pct, actual_work_hours, over_allocation_hours
        ) VALUES
            (v_school_id, v_sprint_id, 'Digital Campus Team', 280.0, 257.0, 23.0, 91.8, 217.0, 0.0),
            (v_school_id, v_sprint_id, 'Academic Systems Team', 320.0, 282.0, 38.0, 88.1, 240.0, 0.0),
            (v_school_id, v_sprint_id, 'Examination Team', 240.0, 222.0, 18.0, 92.5, 195.0, 0.0),
            (v_school_id, v_sprint_id, 'IT Operations Team', 320.0, 288.0, 32.0, 90.0, 260.0, 0.0),
            (v_school_id, v_sprint_id, 'Infrastructure & Maintenance Team', 280.0, 246.0, 34.0, 87.9, 210.0, 0.0),
            (v_school_id, v_sprint_id, 'Library Systems Team', 240.0, 226.0, 14.0, 92.1, 180.0, 0.0)
        ON CONFLICT (sprint_id, team_name) DO UPDATE SET
            total_capacity_hours = EXCLUDED.total_capacity_hours,
            planned_work_hours = EXCLUDED.planned_work_hours,
            remaining_capacity_hours = EXCLUDED.remaining_capacity_hours,
            utilization_pct = EXCLUDED.utilization_pct;
    END IF;

    -- Seed Recent Activities for Digital Campus Team exactly matching reference design
    DELETE FROM public.work_team_activities WHERE team_id = v_t_dct;
    INSERT INTO public.work_team_activities (school_id, team_id, activity_type, description, actor_name, created_at)
    VALUES
        (v_school_id, v_t_dct, 'CAPACITY_UPDATED', 'Team capacity updated to 280 h by Dr. Rajesh Verma', 'Dr. Rajesh Verma', '2025-01-06 10:24:00+00'),
        (v_school_id, v_t_dct, 'MEMBER_ADDED', 'Member Karan Jain added to the team', 'Dr. Rajesh Verma', '2025-01-05 16:10:00+00'),
        (v_school_id, v_t_dct, 'GOAL_UPDATED', 'Team goal updated for Sprint 8', 'Neha Sharma', '2025-01-03 11:32:00+00');

    -- Link existing work items to teams
    UPDATE public.work_items SET team_id = v_t_dct, team_name = 'Digital Campus Team'
    WHERE school_id = v_school_id AND (team_id IS NULL OR team_name IS NULL);

END $$;

-- 6. Stored Procedure: sp_get_teams_directory
CREATE OR REPLACE FUNCTION public.sp_get_teams_directory(
    p_school_id UUID,
    p_sprint_id UUID DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL,
    p_department VARCHAR DEFAULT NULL,
    p_search VARCHAR DEFAULT NULL,
    p_sort_by VARCHAR DEFAULT 'NAME_ASC',
    p_limit INT DEFAULT 10,
    p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_sprint UUID := p_sprint_id;
    v_total_teams INT := 0;
    v_total_members INT := 0;
    v_total_capacity NUMERIC(10,2) := 0.0;
    v_total_allocated NUMERIC(10,2) := 0.0;
    v_avg_utilization NUMERIC(5,2) := 0.0;
    v_active_teams INT := 0;
    v_inactive_teams INT := 0;
    v_teams_json JSONB;
    v_kpis_json JSONB;
BEGIN
    IF v_sprint IS NULL THEN
        SELECT id INTO v_sprint FROM public.work_sprints
        WHERE school_id = p_school_id AND status = 'ACTIVE' LIMIT 1;
        IF v_sprint IS NULL THEN
            SELECT id INTO v_sprint FROM public.work_sprints WHERE school_id = p_school_id LIMIT 1;
        END IF;
    END IF;

    -- Aggregate Global KPIs
    SELECT
        COUNT(t.id),
        COALESCE(COUNT(t.id) FILTER (WHERE t.is_active = TRUE AND t.status = 'ACTIVE'), 0),
        COALESCE(COUNT(t.id) FILTER (WHERE t.is_active = FALSE OR t.status != 'ACTIVE'), 0)
    INTO v_total_teams, v_active_teams, v_inactive_teams
    FROM public.work_teams t
    WHERE t.school_id = p_school_id;

    SELECT COUNT(DISTINCT wtm.user_id) INTO v_total_members
    FROM public.work_team_members wtm
    JOIN public.work_teams t ON t.id = wtm.team_id
    WHERE t.school_id = p_school_id;

    SELECT
        COALESCE(SUM(stc.total_capacity_hours), 0.0),
        COALESCE(SUM(stc.planned_work_hours), 0.0)
    INTO v_total_capacity, v_total_allocated
    FROM public.sprint_team_capacities stc
    WHERE stc.school_id = p_school_id AND (v_sprint IS NULL OR stc.sprint_id = v_sprint);

    IF v_total_capacity > 0 THEN
        v_avg_utilization := ROUND((v_total_allocated / v_total_capacity) * 100.0, 1);
    ELSE
        v_avg_utilization := 0.0;
    END IF;

    v_kpis_json := jsonb_build_object(
        'total_teams', v_total_teams,
        'total_members', v_total_members,
        'total_capacity_hours', v_total_capacity,
        'allocated_work_hours', v_total_allocated,
        'capacity_utilization_pct', v_avg_utilization,
        'active_teams', v_active_teams,
        'inactive_teams', v_inactive_teams
    );

    -- Build Filtered & Sorted Teams List
    WITH filtered_teams AS (
        SELECT
            t.id,
            t.name,
            t.team_key,
            t.department,
            t.description,
            t.icon,
            t.color,
            t.is_active,
            t.status,
            t.tags,
            t.goal,
            t.created_at,
            t.updated_at,
            p.id AS lead_id,
            p.full_name AS lead_name,
            p.email AS lead_email,
            p.avatar_url AS lead_avatar,
            COALESCE(stc.total_capacity_hours, t.default_capacity_hours, 280.0) AS capacity_hours,
            COALESCE(stc.planned_work_hours, 257.0) AS planned_hours,
            COALESCE(stc.remaining_capacity_hours, 23.0) AS remaining_hours,
            COALESCE(stc.utilization_pct, 91.8) AS utilization_pct,
            COUNT(wtm.id) AS member_count,
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', mem_p.id,
                        'name', mem_p.full_name,
                        'avatar_url', mem_p.avatar_url,
                        'role', mem_m.role,
                        'is_lead', mem_m.is_lead
                    ) ORDER BY mem_m.is_lead DESC, mem_p.full_name ASC
                )
                FROM public.work_team_members mem_m
                JOIN public.profiles mem_p ON mem_p.id = mem_m.user_id
                WHERE mem_m.team_id = t.id
            ) AS members_list
        FROM public.work_teams t
        LEFT JOIN public.profiles p ON p.id = t.lead_id
        LEFT JOIN public.sprint_team_capacities stc ON stc.team_name = t.name AND (v_sprint IS NULL OR stc.sprint_id = v_sprint)
        LEFT JOIN public.work_team_members wtm ON wtm.team_id = t.id
        WHERE t.school_id = p_school_id
          AND (p_status IS NULL OR p_status = 'ALL' OR (p_status = 'ACTIVE' AND t.is_active = TRUE) OR (p_status = 'INACTIVE' AND t.is_active = FALSE))
          AND (p_department IS NULL OR p_department = 'ALL' OR t.department ILIKE '%' || p_department || '%')
          AND (p_search IS NULL OR p_search = '' OR (
              t.name ILIKE '%' || p_search || '%' OR
              t.team_key ILIKE '%' || p_search || '%' OR
              t.department ILIKE '%' || p_search || '%' OR
              p.full_name ILIKE '%' || p_search || '%'
          ))
        GROUP BY t.id, t.name, t.team_key, t.department, t.description, t.icon, t.color,
                 t.is_active, t.status, t.tags, t.goal, t.created_at, t.updated_at,
                 p.id, p.full_name, p.email, p.avatar_url,
                 stc.total_capacity_hours, stc.planned_work_hours, stc.remaining_capacity_hours, stc.utilization_pct
    )
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', ft.id,
            'name', ft.name,
            'team_key', COALESCE(ft.team_key, 'TEAM'),
            'department', COALESCE(ft.department, 'General'),
            'description', COALESCE(ft.description, ''),
            'icon', COALESCE(ft.icon, 'layers'),
            'color', COALESCE(ft.color, '#2563EB'),
            'status', ft.status,
            'is_active', ft.is_active,
            'tags', COALESCE(ft.tags, ARRAY[]::TEXT[]),
            'goal', COALESCE(ft.goal, ''),
            'created_at', ft.created_at,
            'updated_at', ft.updated_at,
            'lead', jsonb_build_object(
                'id', ft.lead_id,
                'name', COALESCE(ft.lead_name, 'Unassigned'),
                'email', ft.lead_email,
                'avatar_url', ft.lead_avatar
            ),
            'member_count', ft.member_count,
            'members', COALESCE(ft.members_list, '[]'::jsonb),
            'capacity_hours', ft.capacity_hours,
            'planned_hours', ft.planned_hours,
            'remaining_hours', ft.remaining_hours,
            'utilization_pct', ft.utilization_pct
        )
    ) INTO v_teams_json
    FROM (
        SELECT * FROM filtered_teams
        ORDER BY
            CASE WHEN p_sort_by = 'NAME_DESC' THEN name END DESC,
            CASE WHEN p_sort_by = 'CAPACITY_DESC' THEN capacity_hours END DESC,
            CASE WHEN p_sort_by = 'CAPACITY_ASC' THEN capacity_hours END ASC,
            CASE WHEN p_sort_by = 'UTIL_DESC' THEN utilization_pct END DESC,
            CASE WHEN p_sort_by = 'MEMBERS_DESC' THEN member_count END DESC,
            name ASC
        LIMIT p_limit OFFSET p_offset
    ) ft;

    IF v_teams_json IS NULL THEN
        v_teams_json := '[]'::jsonb;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'sprint_id', v_sprint,
        'kpis', v_kpis_json,
        'total_count', v_total_teams,
        'teams', v_teams_json
    );
END;
$$;

-- 7. Stored Procedure: sp_get_team_detail_drawer
CREATE OR REPLACE FUNCTION public.sp_get_team_detail_drawer(
    p_school_id UUID,
    p_team_id UUID,
    p_sprint_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_sprint UUID := p_sprint_id;
    v_team RECORD;
    v_lead RECORD;
    v_members JSONB;
    v_activities JSONB;
    v_capacity_stat RECORD;
    v_work_items JSONB;
BEGIN
    IF v_sprint IS NULL THEN
        SELECT id INTO v_sprint FROM public.work_sprints
        WHERE school_id = p_school_id AND status = 'ACTIVE' LIMIT 1;
        IF v_sprint IS NULL THEN
            SELECT id INTO v_sprint FROM public.work_sprints WHERE school_id = p_school_id LIMIT 1;
        END IF;
    END IF;

    -- Fetch Team Master
    SELECT * INTO v_team FROM public.work_teams WHERE id = p_team_id AND school_id = p_school_id;
    IF v_team.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Team not found');
    END IF;

    -- Fetch Lead
    SELECT id, full_name, email, avatar_url INTO v_lead
    FROM public.profiles WHERE id = v_team.lead_id;

    -- Fetch Capacity Stats
    SELECT
        COALESCE(stc.total_capacity_hours, v_team.default_capacity_hours, 280.0) AS capacity_hours,
        COALESCE(stc.planned_work_hours, 257.0) AS planned_hours,
        COALESCE(stc.remaining_capacity_hours, 23.0) AS remaining_hours,
        COALESCE(stc.utilization_pct, 91.8) AS utilization_pct
    INTO v_capacity_stat
    FROM (SELECT 1) _
    LEFT JOIN public.sprint_team_capacities stc ON stc.team_name = v_team.name AND (v_sprint IS NULL OR stc.sprint_id = v_sprint);

    -- Fetch Members with Avatar, Role, Capacity
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', m.id,
            'user_id', p.id,
            'name', p.full_name,
            'email', p.email,
            'role', m.role,
            'designation', COALESCE(p.designation, m.role),
            'avatar_url', p.avatar_url,
            'capacity_hours', m.capacity_hours,
            'daily_hours', m.daily_hours,
            'is_lead', m.is_lead,
            'joined_at', m.joined_at
        ) ORDER BY m.is_lead DESC, p.full_name ASC
    ) INTO v_members
    FROM public.work_team_members m
    JOIN public.profiles p ON p.id = m.user_id
    WHERE m.team_id = p_team_id;

    -- Fetch Recent Activities
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', a.id,
            'activity_type', a.activity_type,
            'description', a.description,
            'actor_name', a.actor_name,
            'created_at', a.created_at
        ) ORDER BY a.created_at DESC
    ) INTO v_activities
    FROM (
        SELECT * FROM public.work_team_activities
        WHERE team_id = p_team_id
        ORDER BY created_at DESC
        LIMIT 10
    ) a;

    -- Fetch Assigned Work Items in Sprint
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', wi.id,
            'item_key', wi.item_number,
            'title', wi.title,
            'type', wi.work_type,
            'priority', wi.priority,
            'status', wi.status,
            'progress_percentage', wi.progress_percentage,
            'assignee_name', COALESCE(ap.full_name, 'Unassigned'),
            'assignee_avatar', ap.avatar_url
        ) ORDER BY wi.created_at DESC
    ) INTO v_work_items
    FROM (
        SELECT * FROM public.work_items
        WHERE school_id = p_school_id
          AND (team_id = p_team_id OR team_name = v_team.name)
          AND (v_sprint IS NULL OR sprint_id = v_sprint)
        LIMIT 25
    ) wi
    LEFT JOIN LATERAL (
        SELECT p2.full_name, p2.avatar_url
        FROM public.work_item_assignees wia
        JOIN public.profiles p2 ON p2.id = wia.user_id
        WHERE wia.work_item_id = wi.id
        LIMIT 1
    ) ap ON TRUE;

    RETURN jsonb_build_object(
        'success', TRUE,
        'team', jsonb_build_object(
            'id', v_team.id,
            'name', v_team.name,
            'team_key', COALESCE(v_team.team_key, 'DCT'),
            'department', COALESCE(v_team.department, 'IT & Digitalization'),
            'description', COALESCE(v_team.description, ''),
            'icon', COALESCE(v_team.icon, 'layers'),
            'color', COALESCE(v_team.color, '#2563EB'),
            'is_active', v_team.is_active,
            'status', v_team.status,
            'tags', COALESCE(v_team.tags, ARRAY[]::TEXT[]),
            'goal', COALESCE(v_team.goal, ''),
            'created_at', v_team.created_at,
            'updated_at', v_team.updated_at,
            'lead', jsonb_build_object(
                'id', v_lead.id,
                'name', COALESCE(v_lead.full_name, 'Unassigned'),
                'email', v_lead.email,
                'avatar_url', v_lead.avatar_url
            ),
            'capacity', jsonb_build_object(
                'total_capacity_hours', v_capacity_stat.capacity_hours,
                'planned_hours', v_capacity_stat.planned_hours,
                'remaining_hours', v_capacity_stat.remaining_hours,
                'utilization_pct', v_capacity_stat.utilization_pct
            ),
            'members', COALESCE(v_members, '[]'::jsonb),
            'activities', COALESCE(v_activities, '[]'::jsonb),
            'work_items', COALESCE(v_work_items, '[]'::jsonb)
        )
    );
END;
$$;
