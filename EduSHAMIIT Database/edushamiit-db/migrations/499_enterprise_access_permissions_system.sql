-- ============================================================================
-- Migration 499: Enterprise IoT & ERP Access & Permissions Management System
-- End-to-End RBAC, ABAC, Approval Workflows, Delegation, and Device Authorization
-- ============================================================================

-- 1. Enterprise Roles
CREATE TABLE IF NOT EXISTS public.enterprise_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_name TEXT NOT NULL UNIQUE,
    role_code TEXT NOT NULL UNIQUE,
    description TEXT,
    users_count INTEGER DEFAULT 0,
    key_permissions TEXT,
    status TEXT DEFAULT 'Active',
    is_system BOOLEAN DEFAULT false,
    role_category TEXT DEFAULT 'Operational',
    color_hex TEXT DEFAULT '#1677F2',
    icon_name TEXT DEFAULT 'admin_panel_settings',
    priority INTEGER DEFAULT 10,
    location_scope TEXT DEFAULT 'Assigned Locations',
    device_types_scope TEXT DEFAULT 'All (within assigned locations)',
    time_policy TEXT DEFAULT 'Allowed (24 x 7)',
    access_channel TEXT DEFAULT 'Web & Mobile',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Enterprise Permissions Registry
CREATE TABLE IF NOT EXISTS public.enterprise_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module TEXT NOT NULL,
    resource TEXT NOT NULL,
    action TEXT NOT NULL,
    permission_code TEXT NOT NULL UNIQUE,
    risk_level TEXT DEFAULT 'Low',
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Enterprise Role Permissions Matrix
CREATE TABLE IF NOT EXISTS public.enterprise_role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id UUID NOT NULL REFERENCES public.enterprise_roles(id) ON DELETE CASCADE,
    resource TEXT NOT NULL,
    can_view BOOLEAN DEFAULT true,
    can_create BOOLEAN DEFAULT false,
    can_edit BOOLEAN DEFAULT false,
    can_delete BOOLEAN DEFAULT false,
    can_execute BOOLEAN DEFAULT false,
    can_control BOOLEAN DEFAULT false,
    can_approve BOOLEAN DEFAULT false,
    can_export BOOLEAN DEFAULT false,
    UNIQUE(role_id, resource)
);

-- 4. Enterprise User Groups
CREATE TABLE IF NOT EXISTS public.enterprise_user_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_name TEXT NOT NULL UNIQUE,
    group_code TEXT NOT NULL UNIQUE,
    description TEXT,
    default_role_id UUID REFERENCES public.enterprise_roles(id) ON DELETE SET NULL,
    member_count INTEGER DEFAULT 0,
    status TEXT DEFAULT 'Active',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Enterprise User Access Assignments
CREATE TABLE IF NOT EXISTS public.enterprise_user_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    user_name TEXT NOT NULL,
    email TEXT,
    role_id UUID REFERENCES public.enterprise_roles(id) ON DELETE SET NULL,
    role_name TEXT NOT NULL,
    group_id UUID REFERENCES public.enterprise_user_groups(id) ON DELETE SET NULL,
    group_name TEXT,
    location_scope TEXT DEFAULT 'All Locations',
    status TEXT DEFAULT 'Active',
    last_login TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 6. Enterprise Access Policies (ABAC)
CREATE TABLE IF NOT EXISTS public.enterprise_access_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_name TEXT NOT NULL UNIQUE,
    policy_code TEXT NOT NULL UNIQUE,
    description TEXT,
    category TEXT NOT NULL,
    target_scope TEXT,
    conditions JSONB DEFAULT '{}'::jsonb,
    allowed_actions TEXT[] DEFAULT '{}'::text[],
    denied_actions TEXT[] DEFAULT '{}'::text[],
    priority INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    approval_required BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 7. Enterprise Access Delegations & Temporary Access
CREATE TABLE IF NOT EXISTS public.enterprise_access_delegations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delegatee_name TEXT NOT NULL,
    delegatee_email TEXT,
    delegator_name TEXT NOT NULL,
    assigned_role TEXT NOT NULL,
    location_scope TEXT NOT NULL,
    reason TEXT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    status TEXT DEFAULT 'Active',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 8. Enterprise Access Requests & Approval Workflows
CREATE TABLE IF NOT EXISTS public.enterprise_access_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_code TEXT NOT NULL UNIQUE,
    requester_name TEXT NOT NULL,
    requester_email TEXT,
    requested_role TEXT NOT NULL,
    requested_scope TEXT NOT NULL,
    duration TEXT NOT NULL,
    justification TEXT NOT NULL,
    priority TEXT DEFAULT 'Medium',
    status TEXT DEFAULT 'Pending',
    approver_name TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    reviewed_at TIMESTAMPTZ
);

-- 9. Enterprise Security Audit Logs
CREATE TABLE IF NOT EXISTS public.enterprise_security_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_name TEXT NOT NULL,
    role_name TEXT NOT NULL,
    action TEXT NOT NULL,
    resource TEXT NOT NULL,
    target TEXT NOT NULL,
    status TEXT DEFAULT 'Success',
    ip_address TEXT DEFAULT '192.168.1.100',
    correlation_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for lightning-fast queries
CREATE INDEX IF NOT EXISTS idx_ent_roles_name ON public.enterprise_roles(role_name);
CREATE INDEX IF NOT EXISTS idx_ent_roles_status ON public.enterprise_roles(status);
CREATE INDEX IF NOT EXISTS idx_ent_user_access_name ON public.enterprise_user_access(user_name);
CREATE INDEX IF NOT EXISTS idx_ent_user_access_role ON public.enterprise_user_access(role_name);
CREATE INDEX IF NOT EXISTS idx_ent_user_access_status ON public.enterprise_user_access(status);
CREATE INDEX IF NOT EXISTS idx_ent_audit_created ON public.enterprise_security_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ent_requests_status ON public.enterprise_access_requests(status);

-- ============================================================================
-- SEED DATA - EXACT MATCH TO CANONICAL SCREENSHOT
-- ============================================================================

-- 1. Seed 12 Canonical Roles
INSERT INTO public.enterprise_roles (id, role_name, role_code, description, users_count, key_permissions, status, is_system, role_category, color_hex, icon_name, priority, location_scope, device_types_scope, time_policy, access_channel)
VALUES
    ('c1000000-0000-0000-0000-000000000001', 'Super Admin', 'SUPER_ADMIN', 'Full access to all device modules and settings', 4, 'All permissions', 'Active', true, 'Administration', '#1677F2', 'security', 100, 'Entire Institution', 'All Devices', '24x7 Unrestricted', 'Web, Mobile, CLI'),
    ('c1000000-0000-0000-0000-000000000002', 'Device Administrator', 'DEVICE_ADMIN', 'Manage devices, groups, locations and integrations', 8, 'Device, Config, Integration', 'Active', true, 'Engineering', '#10B981', 'developer_board', 90, 'All Campus Locations', 'All Device Profiles', '24x7 Operations', 'Web & Mobile'),
    ('c1000000-0000-0000-0000-000000000003', 'Facility Manager', 'FACILITY_MANAGER', 'Operate and monitor devices for assigned locations (e.g., blocks, floors, rooms) and manage daily operations such as live control, scenes, schedules and basic automation.', 36, 'Live Control, Schedules, Scenes', 'Active', true, 'Operations', '#8B5CF6', 'business', 80, 'Assigned Locations (e.g., Academic Block A)', 'All (within assigned locations)', 'Allowed (24 x 7)', 'Web & Mobile'),
    ('c1000000-0000-0000-0000-000000000004', 'Maintenance Staff', 'MAINTENANCE_STAFF', 'Diagnostics and maintenance operations', 18, 'Health, Diagnostics, Firmware', 'Active', true, 'Maintenance', '#F59E0B', 'build', 70, 'Assigned Blocks & Utility Areas', 'HVAC, Power, Gateways', 'Working Hours (07:00 - 19:00)', 'Mobile & Web'),
    ('c1000000-0000-0000-0000-000000000005', 'Teacher', 'TEACHER', 'Basic control for classroom devices', 88, 'Live Control (Limited), Scenes', 'Active', true, 'Academic', '#06B6D4', 'school', 50, 'Assigned Classrooms & Labs', 'Lighting, AC, Projectors, Audio', 'Teaching Hours Only (07:30 - 17:30)', 'Web & Mobile'),
    ('c1000000-0000-0000-0000-000000000006', 'View Only', 'VIEW_ONLY', 'Read-only access to monitoring and reports', 42, 'View, Reports', 'Active', true, 'Auditing', '#64748B', 'visibility', 30, 'All Locations (Read Only)', 'All Devices (Telemetry Only)', 'Allowed (24 x 7)', 'Web Only'),
    ('c1000000-0000-0000-0000-000000000007', 'IT/IoT Administrator', 'IT_IOT_ADMIN', 'Manages MQTT brokers, gateways, credentials, and telemetry streams', 6, 'Gateways, MQTT, Certificates', 'Active', true, 'Engineering', '#3B82F6', 'router', 95, 'Entire Campus Fleet', 'Gateways, Meters, Edge Hubs', '24x7 Operations', 'Web & CLI'),
    ('c1000000-0000-0000-0000-000000000008', 'IoT Operator', 'IOT_OPERATOR', 'Routine device commanding and preset executions', 14, 'Live Control, Bulk Commands', 'Active', true, 'Operations', '#10B981', 'toggle_on', 60, 'Operational Zones', 'Smart Plugs, Lighting, Fans', 'Shift Hours', 'Web & Mobile'),
    ('c1000000-0000-0000-0000-000000000009', 'Security Officer', 'SECURITY_OFFICER', 'Campus physical security, access gates, and perimeter cctv oversight', 12, 'CCTV, Access Doors, Locks', 'Active', true, 'Security', '#EF4444', 'local_police', 75, 'Gates, Entrances, Corridors', 'Access Control Doors, CCTV', '24x7 Security Shifts', 'Mobile & Station'),
    ('c1000000-0000-0000-0000-000000000010', 'Department Head', 'DEPT_HEAD', 'Departmental device scheduling and energy approvals', 10, 'Schedules, Approvals, Energy', 'Active', true, 'Academic', '#EC4899', 'account_balance', 65, 'Department Buildings & Labs', 'Department Devices', 'Working Hours', 'Web Only'),
    ('c1000000-0000-0000-0000-000000000011', 'Campus Administrator', 'CAMPUS_ADMIN', 'Full control across designated campus branches', 3, 'Campus Full Access', 'Active', true, 'Administration', '#6366F1', 'domain', 90, 'Designated Campus', 'All Campus Devices', '24x7', 'Web & Mobile'),
    ('c1000000-0000-0000-0000-000000000012', 'Auditor', 'AUDITOR', 'Compliance verification and forensic audit reviews', 1, 'Audit Logs, Security Events', 'Active', true, 'Compliance', '#14B8A6', 'policy', 40, 'Entire Institution (Audit)', 'Log Streams, Access Logs', '24x7 Read-Only', 'Web Only')
ON CONFLICT (role_code) DO UPDATE SET
    role_name = EXCLUDED.role_name,
    description = EXCLUDED.description,
    users_count = EXCLUDED.users_count,
    key_permissions = EXCLUDED.key_permissions,
    status = EXCLUDED.status,
    location_scope = EXCLUDED.location_scope,
    device_types_scope = EXCLUDED.device_types_scope,
    time_policy = EXCLUDED.time_policy,
    access_channel = EXCLUDED.access_channel;

-- 2. Seed Permission Matrix for Roles (Sample Resources)
INSERT INTO public.enterprise_role_permissions (role_id, resource, can_view, can_create, can_edit, can_delete, can_execute, can_control, can_approve, can_export)
SELECT 
    r.id,
    res.resource,
    CASE WHEN r.role_code = 'VIEW_ONLY' THEN true ELSE true END,
    CASE WHEN r.role_code IN ('SUPER_ADMIN', 'DEVICE_ADMIN') THEN true ELSE false END,
    CASE WHEN r.role_code IN ('SUPER_ADMIN', 'DEVICE_ADMIN', 'FACILITY_MANAGER') THEN true ELSE false END,
    CASE WHEN r.role_code = 'SUPER_ADMIN' THEN true ELSE false END,
    CASE WHEN r.role_code IN ('SUPER_ADMIN', 'DEVICE_ADMIN', 'FACILITY_MANAGER', 'TEACHER', 'IOT_OPERATOR') THEN true ELSE false END,
    CASE WHEN r.role_code IN ('SUPER_ADMIN', 'DEVICE_ADMIN', 'FACILITY_MANAGER', 'TEACHER', 'MAINTENANCE_STAFF') THEN true ELSE false END,
    CASE WHEN r.role_code IN ('SUPER_ADMIN', 'DEPT_HEAD', 'CAMPUS_ADMIN') THEN true ELSE false END,
    CASE WHEN r.role_code IN ('SUPER_ADMIN', 'DEVICE_ADMIN', 'AUDITOR', 'VIEW_ONLY') THEN true ELSE false END
FROM public.enterprise_roles r
CROSS JOIN (
    VALUES 
        ('Device Registry'),
        ('Live Control'),
        ('Bulk Operations'),
        ('Schedules'),
        ('Scenes & Presets'),
        ('Energy & Usage'),
        ('Health & Diagnostics'),
        ('Integrations & Gateways'),
        ('Access & Permissions'),
        ('Audit Logs')
) AS res(resource)
ON CONFLICT (role_id, resource) DO NOTHING;

-- 3. Seed 18 User Groups
INSERT INTO public.enterprise_user_groups (id, group_name, group_code, description, member_count, status)
VALUES
    ('d1000000-0000-0000-0000-000000000001', 'IT Team', 'GRP_IT', 'Central IT Systems and IoT infrastructure engineers', 14, 'Active'),
    ('d1000000-0000-0000-0000-000000000002', 'Facility Team', 'GRP_FACILITY', 'Campus facility managers and floor superintendents', 36, 'Active'),
    ('d1000000-0000-0000-0000-000000000003', 'Teachers', 'GRP_TEACHERS', 'Faculty and teaching instructors with classroom device control', 88, 'Active'),
    ('d1000000-0000-0000-0000-000000000004', 'Maintenance', 'GRP_MAINTENANCE', 'Electricians, HVAC mechanics, and service contractors', 18, 'Active'),
    ('d1000000-0000-0000-0000-000000000005', 'Management', 'GRP_MANAGEMENT', 'Principals, deans, and senior executive leadership', 12, 'Active'),
    ('d1000000-0000-0000-0000-000000000006', 'Security Team', 'GRP_SECURITY', 'Physical perimeter and campus guard operations', 12, 'Active'),
    ('d1000000-0000-0000-0000-000000000007', 'Hostel Wardens', 'GRP_HOSTEL', 'Residential hostel device and energy supervisors', 10, 'Active'),
    ('d1000000-0000-0000-0000-000000000008', 'Lab Technicians', 'GRP_LAB_TECH', 'Science, physics, and computer laboratory managers', 16, 'Active'),
    ('d1000000-0000-0000-0000-000000000009', 'Library Staff', 'GRP_LIBRARY', 'Reading hall lighting and AC climate controllers', 8, 'Active'),
    ('d1000000-0000-0000-0000-000000000010', 'Sports Complex Staff', 'GRP_SPORTS', 'Stadium and athletic center floodlight operators', 6, 'Active'),
    ('d1000000-0000-0000-0000-000000000011', 'Auditorium AV Crew', 'GRP_AV_CREW', 'Sound, stage projectors, and lighting operators', 4, 'Active'),
    ('d1000000-0000-0000-0000-000000000012', 'Energy Auditors', 'GRP_ENERGY_AUDIT', 'Sustainability monitors and power consumption inspectors', 3, 'Active'),
    ('d1000000-0000-0000-0000-000000000013', 'Night Shift Operations', 'GRP_NIGHT_OPS', 'After-hours campus lockdown and emergency overseers', 5, 'Active'),
    ('d1000000-0000-0000-0000-000000000014', 'Academic Block A Staff', 'GRP_BLOCK_A', 'Staff based exclusively in Academic Block A', 22, 'Active'),
    ('d1000000-0000-0000-0000-000000000015', 'Academic Block B Staff', 'GRP_BLOCK_B', 'Staff based exclusively in Academic Block B', 20, 'Active'),
    ('d1000000-0000-0000-0000-000000000016', 'Administration Staff', 'GRP_ADMIN_STAFF', 'Registrar, accounts, and admissions office staff', 15, 'Active'),
    ('d1000000-0000-0000-0000-000000000017', 'Examination Cell', 'GRP_EXAM_CELL', 'Examination hall environmental and power controllers', 5, 'Active'),
    ('d1000000-0000-0000-0000-000000000018', 'External Contractors', 'GRP_CONTRACTORS', 'Temporary contracted technicians and vendors', 4, 'Active')
ON CONFLICT (group_code) DO NOTHING;

-- 4. Seed Canonical Recent Users Table (Exact match to screenshot Table 2)
INSERT INTO public.enterprise_user_access (id, user_name, email, role_name, group_name, location_scope, status, last_login)
VALUES
    ('e1000000-0000-0000-0000-000000000001', 'Amit Sharma', 'amit.sharma@edushamiit.edu', 'Device Administrator', 'IT Team', 'All Locations', 'Active', '2025-01-10 14:18:00+05:30'),
    ('e1000000-0000-0000-0000-000000000002', 'Priya Verma', 'priya.verma@edushamiit.edu', 'Facility Manager', 'Facility Team', 'Academic Block (A)', 'Active', '2025-01-10 13:56:00+05:30'),
    ('e1000000-0000-0000-0000-000000000003', 'Rohan Mehta', 'rohan.mehta@edushamiit.edu', 'Teacher', 'Teachers', 'A-101, A-102, A-103', 'Active', '2025-01-10 13:40:00+05:30'),
    ('e1000000-0000-0000-0000-000000000004', 'Neha Kapoor', 'neha.kapoor@edushamiit.edu', 'Maintenance Staff', 'Maintenance', 'Entire Campus', 'Active', '2025-01-10 12:10:00+05:30'),
    ('e1000000-0000-0000-0000-000000000005', 'Vikas Singh', 'vikas.singh@edushamiit.edu', 'View Only', 'Management', 'All Locations', 'Active', '2025-01-10 11:32:00+05:30'),
    ('e1000000-0000-0000-0000-000000000006', 'Dr. Arvind Swaminathan', 'arvind.s@edushamiit.edu', 'Super Admin', 'Management', 'Entire Institution', 'Active', '2025-01-10 10:15:00+05:30'),
    ('e1000000-0000-0000-0000-000000000007', 'Rajesh Kulkarni', 'rajesh.k@edushamiit.edu', 'Security Officer', 'Security Team', 'Gates & Entrances', 'Active', '2025-01-10 09:45:00+05:30'),
    ('e1000000-0000-0000-0000-000000000008', 'Sunita Rao', 'sunita.rao@edushamiit.edu', 'Teacher', 'Teachers', 'A-201, A-202', 'Active', '2025-01-10 09:12:00+05:30'),
    ('e1000000-0000-0000-0000-000000000009', 'Mohammad Tariq', 'tariq.m@edushamiit.edu', 'IT/IoT Administrator', 'IT Team', 'All Gateways', 'Active', '2025-01-10 08:30:00+05:30'),
    ('e1000000-0000-0000-0000-000000000010', 'Ananya Deshmukh', 'ananya.d@edushamiit.edu', 'Facility Manager', 'Facility Team', 'Library Block', 'Active', '2025-01-09 17:22:00+05:30')
ON CONFLICT (id) DO NOTHING;

-- Link role_id and group_id for seeded users
UPDATE public.enterprise_user_access u
SET role_id = r.id
FROM public.enterprise_roles r
WHERE u.role_name = r.role_name AND u.role_id IS NULL;

UPDATE public.enterprise_user_access u
SET group_id = g.id
FROM public.enterprise_user_groups g
WHERE u.group_name = g.group_name AND u.group_id IS NULL;

-- 5. Seed 6 Permission Policies (ABAC)
INSERT INTO public.enterprise_access_policies (id, policy_name, policy_code, description, category, target_scope, conditions, allowed_actions, denied_actions, priority, is_active, approval_required)
VALUES
    ('f1000000-0000-0000-0000-000000000001', 'Working Hours Access', 'POL_WORKING_HOURS', 'Restricts teacher device operation to instructional hours (07:30 - 17:30)', 'Time-Based', 'Teaching Staff', '{"time_start": "07:30", "time_end": "17:30", "days": ["Mon","Tue","Wed","Thu","Fri","Sat"]}'::jsonb, ARRAY['device.control.turn_on', 'device.control.turn_off', 'device.control.preset'], ARRAY['device.control.after_hours'], 10, true, false),
    ('f1000000-0000-0000-0000-000000000002', 'Location-Based Access', 'POL_LOCATION_BOUND', 'Limits facility staff and teachers strictly to assigned rooms/blocks', 'Location-Based', 'All Operational Roles', '{"enforce_hierarchy": true}'::jsonb, ARRAY['device.view.assigned', 'device.control.assigned'], ARRAY['device.control.unassigned'], 20, true, false),
    ('f1000000-0000-0000-0000-000000000003', 'Restricted Device Access', 'POL_RESTRICTED_DEV', 'Enforces high-privilege access for main power distribution, water pumps, and server racks', 'Critical Device', 'Engineering & Utility', '{"device_criticality": "Critical"}'::jsonb, ARRAY['device.view.status'], ARRAY['device.control.direct'], 30, true, true),
    ('f1000000-0000-0000-0000-000000000004', 'Bulk Operation Approval', 'POL_BULK_APPROVAL', 'Mandates multi-level approval for any mass operation affecting > 50 devices', 'Approval Workflow', 'Campus Wide', '{"threshold_devices": 50}'::jsonb, ARRAY['bulk.create'], ARRAY['bulk.instant_execute'], 40, true, true),
    ('f1000000-0000-0000-0000-000000000005', 'Firmware Update Authorization', 'POL_OTA_FIRMWARE', 'Restricts OTA firmware uploads exclusively to Device & IT Administrators with checksum verification', 'Device Security', 'Fleet Gateways & Meters', '{"require_checksum": true, "require_mfa": true}'::jsonb, ARRAY['firmware.upload', 'firmware.apply'], ARRAY['firmware.bypass'], 50, true, false),
    ('f1000000-0000-0000-0000-000000000006', 'Gateway Restart Protection', 'POL_GW_RESTART', 'Requires confirmation challenge and audit logging before physical gateway reboots', 'Gateway Operations', 'Campus Gateways', '{"cooldown_minutes": 15}'::jsonb, ARRAY['gateway.restart.prompted'], ARRAY['gateway.restart.silent'], 60, true, false)
ON CONFLICT (policy_code) DO NOTHING;

-- 6. Seed 4 Pending Access Requests
INSERT INTO public.enterprise_access_requests (id, request_code, requester_name, requester_email, requested_role, requested_scope, duration, justification, priority, status)
VALUES
    ('a1000000-0000-0000-0000-000000000001', 'REQ-2025-081', 'Dr. Ramesh Nair', 'ramesh.nair@edushamiit.edu', 'Facility Manager', 'Laboratories Block (Floors 1-3)', '7 Days', 'Conducting annual physics laboratory electrical safety audit', 'High', 'Pending'),
    ('a1000000-0000-0000-0000-000000000002', 'REQ-2025-082', 'Sneha Patil', 'sneha.patil@edushamiit.edu', 'IoT Operator', 'Auditorium Block', '24 Hours', 'Configuring stage projection and mood lighting for Annual Cultural Festival', 'Medium', 'Pending'),
    ('a1000000-0000-0000-0000-000000000003', 'REQ-2025-083', 'Farhan Akhtar', 'farhan.a@edushamiit.edu', 'Maintenance Staff', 'Hostel Block A (HVAC)', '3 Days', 'Servicing rooftop chiller unit and room thermostats', 'Urgent', 'Pending'),
    ('a1000000-0000-0000-0000-000000000004', 'REQ-2025-084', 'Kavita Menon', 'kavita.m@edushamiit.edu', 'Teacher', 'Smart Class A1-107', '1 Semester', 'Assigned additional robotics elective class needing display and power control', 'Low', 'Pending')
ON CONFLICT (request_code) DO NOTHING;

-- 7. Seed Active Delegations
INSERT INTO public.enterprise_access_delegations (id, delegatee_name, delegatee_email, delegator_name, assigned_role, location_scope, reason, start_time, end_time, status)
VALUES
    ('b2000000-0000-0000-0000-000000000001', 'Deepak Joshi', 'deepak.j@voltas.com', 'Amit Sharma', 'Maintenance Staff', 'Academic Block A & B', 'Quarterly HVAC Comprehensive Preventive Maintenance', now() - INTERVAL '1 day', now() + INTERVAL '2 days', 'Active'),
    ('b2000000-0000-0000-0000-000000000002', 'Alok Chandra', 'alok.c@edushamiit.edu', 'Priya Verma', 'Facility Manager', 'Main Block Ground Floor', 'Acting Facility Head during medical leave', now() - INTERVAL '2 days', now() + INTERVAL '5 days', 'Active')
ON CONFLICT (id) DO NOTHING;

-- 8. Seed Security Audit Logs
INSERT INTO public.enterprise_security_audit_logs (id, actor_name, role_name, action, resource, target, status, ip_address, correlation_id, created_at)
VALUES
    ('c2000000-0000-0000-0000-000000000001', 'Amit Sharma', 'Device Administrator', 'Role Modified', 'Roles', 'Facility Manager (Permissions Updated)', 'Success', '192.168.10.21', 'CORR-SEC-9101', '2025-01-10 14:15:22+05:30'),
    ('c2000000-0000-0000-0000-000000000002', 'Priya Verma', 'Facility Manager', 'Live Control Executed', 'Device A1-103', 'AC Unit Turned ON (24°C Cool)', 'Success', '192.168.10.45', 'CORR-SEC-9102', '2025-01-10 13:58:10+05:30'),
    ('c2000000-0000-0000-0000-000000000003', 'Dr. Arvind Swaminathan', 'Super Admin', 'Policy Enforced', 'Policies', 'Working Hours Policy Re-calibrated', 'Success', '192.168.1.1', 'CORR-SEC-9103', '2025-01-10 13:30:00+05:30'),
    ('c2000000-0000-0000-0000-000000000004', 'Unauthorized Agent', 'Unknown', 'Command Rejected', 'Main Gate Lock', 'Door Unlock without Elevate-MFA Blocked', 'Denied', '192.168.100.89', 'CORR-SEC-9104', '2025-01-10 12:45:18+05:30'),
    ('c2000000-0000-0000-0000-000000000005', 'Neha Kapoor', 'Maintenance Staff', 'Gateway Diagnostics', 'GW-A01', '5-Check Diagnostic Suite Executed Nominal', 'Success', '192.168.10.33', 'CORR-SEC-9105', '2025-01-10 12:12:05+05:30'),
    ('c2000000-0000-0000-0000-000000000006', 'Rohan Mehta', 'Teacher', 'Scene Activated', 'Classroom A1-102', 'Class Start Scene Dispatched', 'Success', '192.168.10.78', 'CORR-SEC-9106', '2025-01-10 11:20:40+05:30')
ON CONFLICT (id) DO NOTHING;
