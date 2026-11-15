-- ============================================================================
-- Migration 500: Sync Device Management Roles & Users with Roles Management (app_roles) & Users Management (profiles)
-- ============================================================================

-- 1. Insert / Upsert missing Device Management roles into public.app_roles
INSERT INTO public.app_roles (
    name, code, display_name, description, level, role_type, status, permissions, is_custom, inherit_permissions, display_order
) VALUES
('device_administrator', 'DEVICE_ADMIN', 'Device Administrator', 'Manage devices, groups, locations and integrations', 2, 'CUSTOM', 'Active', ARRAY['device:read', 'device:write', 'device:control', 'device:config', 'device:firmware'], true, true, 2),
('facility_manager', 'FACILITY_MANAGER', 'Facility Manager', 'Operate and monitor devices for assigned locations (e.g. blocks, floors, rooms)', 2, 'CUSTOM', 'Active', ARRAY['device:read', 'device:control', 'device:schedules', 'device:scenes', 'energy:view'], true, true, 3),
('maintenance_staff', 'MAINTENANCE_STAFF', 'Maintenance Staff', 'Diagnostics, device health monitoring and maintenance operations', 3, 'CUSTOM', 'Active', ARRAY['device:read', 'health:read', 'diagnostics:execute', 'firmware:update'], true, true, 4),
('view_only', 'VIEW_ONLY', 'View Only', 'Read-only access to device telemetry, monitoring and analytics reports', 4, 'CUSTOM', 'Active', ARRAY['device:read', 'reports:read', 'energy:view'], true, true, 5),
('it_iot_admin', 'IT_IOT_ADMIN', 'IT/IoT Administrator', 'Full control of IoT gateways, protocols, networks and device fleet', 2, 'CUSTOM', 'Active', ARRAY['gateway:manage', 'protocol:manage', 'device:all', 'security:manage'], true, true, 6),
('iot_operator', 'IOT_OPERATOR', 'IoT Operator', 'Day-to-day IoT operations, live controls and schedule execution', 3, 'CUSTOM', 'Active', ARRAY['device:control', 'schedules:execute', 'scenes:trigger'], true, true, 7),
('security_officer', 'SECURITY_OFFICER', 'Security Officer', 'Access control, door security, emergency lockdown and alarm monitoring', 3, 'CUSTOM', 'Active', ARRAY['access:lockdown', 'doors:control', 'cctv:view', 'alarms:respond'], true, true, 8),
('department_head', 'DEPT_HEAD', 'Department Head', 'Departmental device monitoring, occupancy schedules and energy review', 2, 'CUSTOM', 'Active', ARRAY['dept_devices:read', 'dept_devices:control', 'dept_energy:view'], true, true, 9),
('campus_administrator', 'CAMPUS_ADMIN', 'Campus Administrator', 'Campus-wide facility, space and energy automation management', 2, 'CUSTOM', 'Active', ARRAY['campus:all', 'energy:manage', 'spaces:control'], true, true, 10),
('auditor', 'AUDITOR', 'Auditor', 'Access compliance, telemetry logs, security events and audit trails', 3, 'CUSTOM', 'Active', ARRAY['audit:read', 'compliance:read', 'logs:export'], true, true, 11)
ON CONFLICT (name) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    status = 'Active';

-- 2. Populate public.profiles with the 238 users from enterprise_user_access
INSERT INTO public.profiles (
    id,
    user_id,
    full_name,
    email,
    role,
    department,
    status,
    phone,
    last_login,
    created_at,
    updated_at
)
SELECT
    eua.id,
    COALESCE(eua.email, eua.id::text),
    eua.user_name,
    eua.email,
    CASE 
        WHEN lower(eua.role_name) LIKE '%super admin%' THEN 'super_admin'
        WHEN lower(eua.role_name) LIKE '%device admin%' THEN 'device_administrator'
        WHEN lower(eua.role_name) LIKE '%facility%' THEN 'facility_manager'
        WHEN lower(eua.role_name) LIKE '%maintenance%' THEN 'maintenance_staff'
        WHEN lower(eua.role_name) LIKE '%teacher%' THEN 'teacher'
        WHEN lower(eua.role_name) LIKE '%view only%' THEN 'view_only'
        WHEN lower(eua.role_name) LIKE '%it%iot%' THEN 'it_iot_admin'
        WHEN lower(eua.role_name) LIKE '%iot operator%' THEN 'iot_operator'
        WHEN lower(eua.role_name) LIKE '%security%' THEN 'security_officer'
        WHEN lower(eua.role_name) LIKE '%dept%' OR lower(eua.role_name) LIKE '%head%' THEN 'department_head'
        WHEN lower(eua.role_name) LIKE '%campus admin%' THEN 'campus_administrator'
        WHEN lower(eua.role_name) LIKE '%auditor%' THEN 'auditor'
        ELSE 'view_only'
    END,
    COALESCE(eua.group_name, 'General'),
    COALESCE(eua.status, 'Active'),
    '+91 98765 ' || lpad((row_number() over (order by eua.id))::text, 5, '0'),
    COALESCE(eua.last_login, now()),
    COALESCE(eua.created_at, now()),
    now()
FROM public.enterprise_user_access eua
ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    role = EXCLUDED.role,
    department = EXCLUDED.department,
    status = EXCLUDED.status,
    last_login = EXCLUDED.last_login;

-- 3. Update enterprise_user_access.user_id = id so that user_id links directly to profiles.id
UPDATE public.enterprise_user_access eua
SET user_id = eua.id
WHERE user_id IS NULL;

-- 4. Add foreign key from enterprise_user_access.user_id to profiles.id
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_enterprise_user_access_profile'
    ) THEN
        ALTER TABLE public.enterprise_user_access
        ADD CONSTRAINT fk_enterprise_user_access_profile
        FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
    END IF;
END $$;
