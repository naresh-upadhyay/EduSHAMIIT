-- ============================================================================
-- Migration 531: Canonical Access & Permissions System for Campus Device Management
-- Drops duplicate enterprise tables and unifies access control directly with
-- canonical `app_roles` (Roles Management) and `profiles` (User Management).
-- Provides stored procedures and functions for Dashboard, Dropdowns, Role Permissions Matrix,
-- User Access CRUD, Policies, Delegations, Requests, and Security Audit.
-- ============================================================================

-- 1. DROP DUPLICATE TABLES AND CLEAN UP OBSOLETE ENTERPRISE SCHEMAS
DROP TABLE IF EXISTS public.enterprise_security_audit_logs CASCADE;
DROP TABLE IF EXISTS public.enterprise_access_requests CASCADE;
DROP TABLE IF EXISTS public.enterprise_access_delegations CASCADE;
DROP TABLE IF EXISTS public.enterprise_access_policies CASCADE;
DROP TABLE IF EXISTS public.enterprise_user_access CASCADE;
DROP TABLE IF EXISTS public.enterprise_user_groups CASCADE;
DROP TABLE IF EXISTS public.enterprise_role_permissions CASCADE;
DROP TABLE IF EXISTS public.enterprise_permissions CASCADE;
DROP TABLE IF EXISTS public.enterprise_roles CASCADE;

-- 2. CREATE CANONICAL DEVICE ROLE PERMISSIONS (Linked to public.app_roles)
CREATE TABLE IF NOT EXISTS public.campus_device_role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id UUID NOT NULL REFERENCES public.app_roles(id) ON DELETE CASCADE,
    resource TEXT NOT NULL,
    can_view BOOLEAN DEFAULT true,
    can_control BOOLEAN DEFAULT false,
    can_configure BOOLEAN DEFAULT false,
    can_delete BOOLEAN DEFAULT false,
    can_execute BOOLEAN DEFAULT false,
    can_approve BOOLEAN DEFAULT false,
    can_export BOOLEAN DEFAULT false,
    location_scope TEXT DEFAULT 'All Locations',
    time_policy TEXT DEFAULT 'Allowed (24 x 7)',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(role_id, resource)
);

CREATE INDEX IF NOT EXISTS idx_campus_dev_role_perms_role ON public.campus_device_role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_campus_dev_role_perms_res ON public.campus_device_role_permissions(resource);

-- 3. CREATE CANONICAL DEVICE USER ACCESS (Linked to public.profiles & public.app_roles)
CREATE TABLE IF NOT EXISTS public.campus_device_user_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role_id UUID REFERENCES public.app_roles(id) ON DELETE SET NULL,
    building_id UUID REFERENCES public.buildings(id) ON DELETE SET NULL,
    floor_id UUID REFERENCES public.building_floors(id) ON DELETE SET NULL,
    location_scope TEXT DEFAULT 'All Locations',
    access_level TEXT DEFAULT 'Full Control',
    custom_permissions JSONB DEFAULT '[]'::jsonb,
    status TEXT DEFAULT 'Active',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_campus_dev_user_access_user ON public.campus_device_user_access(user_id);
CREATE INDEX IF NOT EXISTS idx_campus_dev_user_access_role ON public.campus_device_user_access(role_id);
CREATE INDEX IF NOT EXISTS idx_campus_dev_user_access_status ON public.campus_device_user_access(status);

-- 4. CREATE CANONICAL DEVICE ACCESS POLICIES (ABAC)
CREATE TABLE IF NOT EXISTS public.campus_device_access_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_name TEXT NOT NULL UNIQUE,
    policy_code TEXT NOT NULL UNIQUE,
    description TEXT,
    category TEXT NOT NULL,
    target_scope TEXT DEFAULT 'Entire Campus',
    conditions JSONB DEFAULT '{}'::jsonb,
    allowed_actions TEXT[] DEFAULT '{}'::text[],
    denied_actions TEXT[] DEFAULT '{}'::text[],
    priority INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    approval_required BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 5. CREATE CANONICAL DEVICE ACCESS DELEGATIONS
CREATE TABLE IF NOT EXISTS public.campus_device_access_delegations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delegatee_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    delegatee_name TEXT NOT NULL,
    delegatee_email TEXT,
    delegator_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    delegator_name TEXT NOT NULL,
    role_id UUID REFERENCES public.app_roles(id) ON DELETE SET NULL,
    assigned_role TEXT NOT NULL,
    location_scope TEXT NOT NULL,
    reason TEXT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    status TEXT DEFAULT 'Active',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 6. CREATE CANONICAL DEVICE ACCESS REQUESTS
CREATE TABLE IF NOT EXISTS public.campus_device_access_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    requester_name TEXT NOT NULL,
    requester_email TEXT,
    requested_role_id UUID REFERENCES public.app_roles(id) ON DELETE SET NULL,
    requested_role TEXT NOT NULL,
    resource TEXT NOT NULL,
    requested_scope TEXT NOT NULL,
    justification TEXT,
    urgency TEXT DEFAULT 'Normal',
    status TEXT DEFAULT 'Pending',
    reviewer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reviewer_name TEXT,
    review_comment TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 7. CREATE CANONICAL SECURITY AUDIT LOGS
CREATE TABLE IF NOT EXISTS public.campus_device_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL,
    actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    actor_name TEXT NOT NULL,
    actor_role TEXT,
    target_resource TEXT NOT NULL,
    action_details TEXT NOT NULL,
    ip_address TEXT DEFAULT '127.0.0.1',
    status TEXT DEFAULT 'Success',
    timestamp TIMESTAMPTZ DEFAULT now()
);

-- ============================================================================
-- SEED CANONICAL ROLE DEVICE PERMISSIONS FOR ALL ROLES IN app_roles
-- ============================================================================
DO $$
DECLARE
    r RECORD;
    res_list TEXT[] := ARRAY['Devices & Groups', 'Live Control', 'Scenes & Presets', 'Schedules', 'Automation Rules', 'Energy & Usage', 'Device Health', 'Integrations & Gateways', 'Access & Permissions', 'Audit Logs'];
    res TEXT;
BEGIN
    FOR r IN SELECT id, lower(name) as rname, lower(COALESCE(code, '')) as rcode FROM public.app_roles LOOP
        FOREACH res IN ARRAY res_list LOOP
            IF r.rname IN ('super_admin', 'superadmin') OR r.rcode LIKE '%SUPER_ADMIN%' THEN
                INSERT INTO public.campus_device_role_permissions (role_id, resource, can_view, can_control, can_configure, can_delete, can_execute, can_approve, can_export, location_scope, time_policy)
                VALUES (r.id, res, true, true, true, true, true, true, true, 'Entire Institution', 'Allowed (24 x 7)')
                ON CONFLICT (role_id, resource) DO UPDATE SET can_view=true, can_control=true, can_configure=true, can_delete=true, can_execute=true, can_approve=true, can_export=true;
            ELSIF r.rname IN ('admin', 'principal', 'director') OR r.rcode LIKE '%ADMIN%' THEN
                INSERT INTO public.campus_device_role_permissions (role_id, resource, can_view, can_control, can_configure, can_delete, can_execute, can_approve, can_export, location_scope, time_policy)
                VALUES (r.id, res, true, true, true, (res NOT IN ('Access & Permissions', 'Audit Logs')), true, true, true, 'All Campus Blocks', 'Allowed (24 x 7)')
                ON CONFLICT (role_id, resource) DO UPDATE SET can_view=true, can_control=true, can_configure=true;
            ELSIF r.rname IN ('security', 'campus_security') THEN
                INSERT INTO public.campus_device_role_permissions (role_id, resource, can_view, can_control, can_configure, can_delete, can_execute, can_approve, can_export, location_scope, time_policy)
                VALUES (r.id, res, true, (res IN ('Devices & Groups', 'Live Control', 'Device Health')), false, false, true, false, false, 'Security & Perimeter', 'Allowed (24 x 7)')
                ON CONFLICT (role_id, resource) DO UPDATE SET can_view=true;
            ELSIF r.rname IN ('teacher', 'teacher_admin') THEN
                INSERT INTO public.campus_device_role_permissions (role_id, resource, can_view, can_control, can_configure, can_delete, can_execute, can_approve, can_export, location_scope, time_policy)
                VALUES (r.id, res, (res IN ('Devices & Groups', 'Live Control', 'Scenes & Presets', 'Schedules', 'Energy & Usage')), (res IN ('Live Control', 'Scenes & Presets')), false, false, (res IN ('Scenes & Presets')), false, false, 'Classroom & Assigned Labs', 'Active Hours (07:00 - 18:00)')
                ON CONFLICT (role_id, resource) DO UPDATE SET can_view=true;
            ELSE
                INSERT INTO public.campus_device_role_permissions (role_id, resource, can_view, can_control, can_configure, can_delete, can_execute, can_approve, can_export, location_scope, time_policy)
                VALUES (r.id, res, true, false, false, false, false, false, false, 'Assigned Spaces Only', 'Operating Hours')
                ON CONFLICT (role_id, resource) DO NOTHING;
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- ============================================================================
-- SEED USER ACCESS OVERRIDES LINKING REAL PROFILES
-- ============================================================================
DO $$
DECLARE
    u RECORD;
    v_role_id UUID;
BEGIN
    FOR u IN SELECT id, full_name, email, role, department, designation FROM public.profiles WHERE role IN ('super_admin', 'admin', 'principal', 'teacher', 'security', 'hostel') LIMIT 25 LOOP
        SELECT id INTO v_role_id FROM public.app_roles WHERE lower(name) = lower(u.role) OR lower(code) = lower(u.role) LIMIT 1;
        
        INSERT INTO public.campus_device_user_access (
            user_id, role_id, location_scope, access_level, status, notes
        ) VALUES (
            u.id, 
            v_role_id, 
            CASE 
                WHEN lower(u.role) = 'super_admin' THEN 'Entire Institution'
                WHEN lower(u.role) = 'admin' THEN 'All Locations'
                WHEN lower(u.role) = 'security' THEN 'Gate & Security Perimeters'
                WHEN lower(u.role) = 'hostel' THEN 'Hostel Block'
                ELSE 'Academic Block (A)'
            END,
            CASE 
                WHEN lower(u.role) IN ('super_admin', 'admin') THEN 'Full Control'
                WHEN lower(u.role) IN ('security', 'teacher') THEN 'Operator'
                ELSE 'Monitor Only'
            END,
            'Active',
            'Sourced from canonical platform user profile'
        )
        ON CONFLICT (user_id) DO UPDATE SET 
            role_id = EXCLUDED.role_id,
            location_scope = EXCLUDED.location_scope,
            status = 'Active';
    END LOOP;
END $$;

-- Seed Sample ABAC Policies
INSERT INTO public.campus_device_access_policies (policy_name, policy_code, description, category, target_scope, allowed_actions, denied_actions, is_active, approval_required)
VALUES 
    ('Standard School Hours Device Control', 'POL-SCH-001', 'Staff and teachers may operate lighting and HVAC in designated classrooms between 07:00 and 18:00.', 'Time-based', 'Classrooms & Labs', ARRAY['device.read', 'device.power', 'scene.execute'], ARRAY['device.delete', 'firmware.update'], true, false),
    ('Critical Infrastructure High-Security Gateways', 'POL-CRIT-002', 'Only Super Admin and Institution Admin can restart IoT gateways or alter mutual TLS certificates.', 'Security', 'Gateways & Broker', ARRAY['gateway.read', 'gateway.restart', 'gateway.update'], ARRAY['*'], true, true),
    ('Emergency Override Protocol', 'POL-EMRG-003', 'Campus Security may override access control doors and triggers during verified emergency alarms.', 'Safety', 'Access Doors & Alarms', ARRAY['door.unlock_all', 'alarm.sound'], ARRAY[]::text[], true, false)
ON CONFLICT (policy_code) DO NOTHING;

-- Seed Sample Security Audit Log
INSERT INTO public.campus_device_audit_logs (event_type, actor_name, actor_role, target_resource, action_details, status)
VALUES 
    ('ROLE_PERMISSION_UPDATE', 'System Admin', 'Super Admin', 'Campus Device Control', 'Synchronized canonical role matrix with app_roles', 'Success'),
    ('USER_ACCESS_ASSIGNMENT', 'System Admin', 'Super Admin', 'Classroom Lighting', 'Assigned operator permissions to Academic Block A', 'Success');

-- ============================================================================
-- STORED FUNCTIONS & PROCEDURES
-- ============================================================================

-- Function 1: Dashboard Overview KPIs, Role Distribution & Permission Coverage
CREATE OR REPLACE FUNCTION public.fn_device_access_permissions_dashboard(p_school_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_users BIGINT;
    v_total_roles BIGINT;
    v_total_policies BIGINT;
    v_pending_requests BIGINT;
    v_total_delegations BIGINT;
    v_role_distribution JSONB;
    v_permission_coverage JSONB;
    v_kpis JSONB;
BEGIN
    -- 1. Total institutional users from profiles
    SELECT count(*) INTO v_total_users 
    FROM public.profiles 
    WHERE (p_school_id IS NULL OR school_id = p_school_id);

    -- 2. Total active roles from app_roles
    SELECT count(*) INTO v_total_roles 
    FROM public.app_roles 
    WHERE (status IS NULL OR lower(status) = 'active')
      AND (p_school_id IS NULL OR school_id = p_school_id OR school_id IS NULL);

    -- 3. Total active policies
    SELECT count(*) INTO v_total_policies 
    FROM public.campus_device_access_policies 
    WHERE is_active = true;

    -- 4. Pending access requests
    SELECT count(*) INTO v_pending_requests 
    FROM public.campus_device_access_requests 
    WHERE lower(status) = 'pending';

    -- 5. Active delegations
    SELECT count(*) INTO v_total_delegations 
    FROM public.campus_device_access_delegations 
    WHERE lower(status) = 'active' AND end_time > now();

    v_kpis := jsonb_build_object(
        'total_users', v_total_users,
        'total_roles', v_total_roles,
        'permission_policies', v_total_policies,
        'user_groups', (SELECT count(DISTINCT department) FROM public.profiles WHERE department IS NOT NULL AND department <> ''),
        'pending_requests', v_pending_requests,
        'access_health', 'Compliant',
        'active_delegations', v_total_delegations
    );

    -- Role distribution based on real user assignments in profiles
    SELECT jsonb_agg(
        jsonb_build_object(
            'name', COALESCE(ar.display_name, initcap(replace(p_role.role_name, '_', ' '))),
            'count', p_role.role_count,
            'percentage', ROUND((p_role.role_count::numeric / GREATEST(v_total_users, 1)) * 100, 1),
            'colorHex', CASE 
                WHEN lower(p_role.role_name) IN ('super_admin', 'admin') THEN '#1677F2'
                WHEN lower(p_role.role_name) IN ('facility_manager', 'director', 'principal') THEN '#10B981'
                WHEN lower(p_role.role_name) IN ('teacher', 'teacher_admin') THEN '#8B5CF6'
                WHEN lower(p_role.role_name) IN ('student', 'student_admin') THEN '#06B6D4'
                WHEN lower(p_role.role_name) IN ('security') THEN '#EF4444'
                ELSE '#F59E0B'
            END
        )
    ) INTO v_role_distribution
    FROM (
        SELECT COALESCE(role, 'Other') as role_name, count(*) as role_count 
        FROM public.profiles 
        WHERE (p_school_id IS NULL OR school_id = p_school_id)
        GROUP BY role 
        ORDER BY count(*) DESC 
        LIMIT 6
    ) p_role
    LEFT JOIN public.app_roles ar ON lower(ar.name) = lower(p_role.role_name) OR lower(ar.code) = lower(p_role.role_name);

    v_permission_coverage := jsonb_build_array(
        jsonb_build_object('domain', 'Device Control & Live State', 'percentage', 94),
        jsonb_build_object('domain', 'Configuration & Setup', 'percentage', 88),
        jsonb_build_object('domain', 'Automations & Scheduling', 'percentage', 91),
        jsonb_build_object('domain', 'Energy & Telemetry Metrics', 'percentage', 96),
        jsonb_build_object('domain', 'Device Diagnostics & Firmware', 'percentage', 84),
        jsonb_build_object('domain', 'Third-Party Integrations', 'percentage', 89)
    );

    RETURN jsonb_build_object(
        'success', true,
        'kpis', v_kpis,
        'role_distribution', COALESCE(v_role_distribution, '[]'::jsonb),
        'permission_coverage', v_permission_coverage
    );
END;
$$;


-- Function 2: Canonical Dropdowns Options (Roles from app_roles, Users from profiles, Locations from buildings)
CREATE OR REPLACE FUNCTION public.fn_device_access_dropdown_options(p_school_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_roles JSONB;
    v_users JSONB;
    v_locations JSONB;
BEGIN
    -- Roles dropdown list from app_roles
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', ar.id,
            'name', ar.name,
            'code', COALESCE(ar.code, upper(ar.name)),
            'display_name', COALESCE(ar.display_name, initcap(replace(ar.name, '_', ' '))),
            'description', COALESCE(ar.description, 'Platform role defined in Roles & Permissions'),
            'status', COALESCE(ar.status, 'Active'),
            'user_count', (
                SELECT count(*) 
                FROM public.profiles p 
                WHERE lower(p.role) = lower(ar.name) 
                   OR lower(p.role) = lower(ar.code)
            )
        ) ORDER BY COALESCE(ar.display_order, 999), ar.name
    ) INTO v_roles
    FROM public.app_roles ar
    WHERE (ar.status IS NULL OR lower(ar.status) = 'active')
      AND (p_school_id IS NULL OR ar.school_id = p_school_id OR ar.school_id IS NULL);

    -- Users dropdown list from profiles (real platform users from User Management)
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'full_name', p.full_name,
            'email', COALESCE(p.email, ''),
            'role', COALESCE(p.role, 'User'),
            'department', COALESCE(p.department, 'General'),
            'designation', COALESCE(p.designation, ''),
            'status', COALESCE(p.status, 'Active'),
            'avatar_url', p.avatar_url
        ) ORDER BY p.full_name ASC
    ) INTO v_users
    FROM (
        SELECT id, full_name, email, role, department, designation, status, avatar_url
        FROM public.profiles
        WHERE (p_school_id IS NULL OR school_id = p_school_id)
        ORDER BY full_name ASC
        LIMIT 250
    ) p;

    -- Locations dropdown list from real campus buildings
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', b.id,
            'name', b.name,
            'code', b.code
        ) ORDER BY b.name ASC
    ) INTO v_locations
    FROM public.buildings b
    WHERE (p_school_id IS NULL OR b.school_id = p_school_id);

    RETURN jsonb_build_object(
        'success', true,
        'roles', COALESCE(v_roles, '[]'::jsonb),
        'users', COALESCE(v_users, '[]'::jsonb),
        'locations', COALESCE(v_locations, '[]'::jsonb),
        'statuses', jsonb_build_array('All Status', 'Active', 'Inactive', 'Locked'),
        'access_levels', jsonb_build_array('Full Control', 'Operator', 'Monitor Only', 'Restricted')
    );
END;
$$;


-- Function 3: List Institutional Roles (from app_roles with user counts & matrix info)
CREATE OR REPLACE FUNCTION public.fn_list_device_roles(
    p_school_id UUID DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'priority',
    p_sort_asc BOOLEAN DEFAULT false,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);
    v_total_count BIGINT;
    v_items JSONB;
BEGIN
    -- Count matching roles
    SELECT count(*) INTO v_total_count
    FROM public.app_roles ar
    WHERE (p_school_id IS NULL OR ar.school_id = p_school_id OR ar.school_id IS NULL)
      AND (p_status IS NULL OR p_status = 'All Status' OR lower(ar.status) = lower(p_status))
      AND (
          p_search IS NULL OR p_search = '' 
          OR ar.name ILIKE '%' || p_search || '%'
          OR ar.display_name ILIKE '%' || p_search || '%'
          OR ar.description ILIKE '%' || p_search || '%'
      );

    -- Fetch paginated roles
    SELECT jsonb_agg(r_row) INTO v_items
    FROM (
        SELECT 
            ar.id,
            COALESCE(ar.display_name, initcap(replace(ar.name, '_', ' '))) AS role_name,
            COALESCE(ar.code, upper(ar.name)) AS role_code,
            COALESCE(ar.description, 'System enterprise role mapped with device permissions') AS description,
            (
                SELECT count(*)::int 
                FROM public.profiles p 
                WHERE lower(p.role) = lower(ar.name) 
                   OR lower(p.role) = lower(ar.code)
            ) AS users_count,
            CASE 
                WHEN lower(ar.name) IN ('super_admin', 'superadmin') THEN 'All permissions (Unlimited)'
                WHEN lower(ar.name) IN ('admin', 'principal', 'director') THEN 'Device, Config, Integration, Health'
                WHEN lower(ar.name) IN ('security') THEN 'CCTV, Access Doors, Alarms'
                WHEN lower(ar.name) IN ('teacher') THEN 'Live Control, Scenes, Schedules'
                WHEN lower(ar.name) IN ('hostel') THEN 'Hostel Live Control, Schedules'
                ELSE 'Telemetry View & Alerts'
            END AS key_permissions,
            COALESCE(ar.status, 'Active') AS status,
            CASE 
                WHEN lower(ar.name) IN ('super_admin', 'admin') THEN 'Entire Institution'
                WHEN lower(ar.name) IN ('security') THEN 'Security & Gates'
                WHEN lower(ar.name) IN ('teacher') THEN 'Assigned Classrooms'
                ELSE 'Assigned Locations'
            END AS location_scope,
            'All (within assigned locations)' AS device_types_scope,
            CASE 
                WHEN lower(ar.name) IN ('super_admin', 'admin', 'security') THEN 'Allowed (24 x 7)'
                ELSE 'Operating Hours (07:00 - 18:00)'
            END AS time_policy,
            'Web, Mobile, CLI' AS access_channel,
            CASE 
                WHEN lower(ar.name) IN ('super_admin', 'admin') THEN 100
                WHEN lower(ar.name) IN ('principal', 'director') THEN 90
                WHEN lower(ar.name) IN ('facility_manager') THEN 80
                WHEN lower(ar.name) IN ('security') THEN 70
                WHEN lower(ar.name) IN ('teacher') THEN 50
                ELSE 30
            END AS priority,
            COALESCE(ar.created_at, now()) AS created_at
        FROM public.app_roles ar
        WHERE (p_school_id IS NULL OR ar.school_id = p_school_id OR ar.school_id IS NULL)
          AND (p_status IS NULL OR p_status = 'All Status' OR lower(ar.status) = lower(p_status))
          AND (
              p_search IS NULL OR p_search = '' 
              OR ar.name ILIKE '%' || p_search || '%'
              OR ar.display_name ILIKE '%' || p_search || '%'
              OR ar.description ILIKE '%' || p_search || '%'
          )
        ORDER BY 
            CASE WHEN p_sort_by = 'role_name' AND p_sort_asc THEN COALESCE(ar.display_name, ar.name) END ASC,
            CASE WHEN p_sort_by = 'role_name' AND NOT p_sort_asc THEN COALESCE(ar.display_name, ar.name) END DESC,
            CASE WHEN p_sort_by = 'status' AND p_sort_asc THEN ar.status END ASC,
            CASE WHEN p_sort_by = 'status' AND NOT p_sort_asc THEN ar.status END DESC,
            CASE WHEN p_sort_by = 'priority' AND p_sort_asc THEN COALESCE(ar.display_order, 999) END ASC,
            CASE WHEN p_sort_by = 'priority' AND NOT p_sort_asc THEN COALESCE(ar.display_order, 999) END DESC,
            COALESCE(ar.display_order, 999) ASC,
            ar.name ASC
        LIMIT p_page_size OFFSET v_offset
    ) r_row;

    RETURN jsonb_build_object(
        'success', true,
        'total_count', v_total_count,
        'page', p_page,
        'page_size', p_page_size,
        'roles', COALESCE(v_items, '[]'::jsonb)
    );
END;
$$;


-- Function 4: Get Detailed Role Permissions Matrix
CREATE OR REPLACE FUNCTION public.fn_get_role_permissions_matrix(p_role_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_role_record RECORD;
    v_matrix JSONB;
BEGIN
    SELECT id, name, COALESCE(display_name, name) as dname, code, description 
    INTO v_role_record 
    FROM public.app_roles 
    WHERE id = p_role_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Role not found');
    END IF;

    SELECT jsonb_agg(
        jsonb_build_object(
            'resource', rp.resource,
            'can_view', rp.can_view,
            'can_control', rp.can_control,
            'can_configure', rp.can_configure,
            'can_delete', rp.can_delete,
            'can_execute', rp.can_execute,
            'can_approve', rp.can_approve,
            'can_export', rp.can_export,
            'location_scope', rp.location_scope,
            'time_policy', rp.time_policy
        ) ORDER BY rp.resource ASC
    ) INTO v_matrix
    FROM public.campus_device_role_permissions rp
    WHERE rp.role_id = p_role_id;

    RETURN jsonb_build_object(
        'success', true,
        'role', jsonb_build_object(
            'id', v_role_record.id,
            'name', v_role_record.name,
            'display_name', v_role_record.dname,
            'code', v_role_record.code,
            'description', v_role_record.description
        ),
        'permissions', COALESCE(v_matrix, '[]'::jsonb)
    );
END;
$$;


-- Procedure 5: Save or Update Role Permissions Matrix
CREATE OR REPLACE FUNCTION public.sp_save_role_permissions_matrix(
    p_role_id UUID,
    p_permissions JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    p_item JSONB;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.app_roles WHERE id = p_role_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Role not found');
    END IF;

    FOR p_item IN SELECT * FROM jsonb_array_elements(p_permissions) LOOP
        INSERT INTO public.campus_device_role_permissions (
            role_id, resource, can_view, can_control, can_configure, can_delete, 
            can_execute, can_approve, can_export, location_scope, time_policy, updated_at
        ) VALUES (
            p_role_id,
            p_item->>'resource',
            COALESCE((p_item->>'can_view')::boolean, true),
            COALESCE((p_item->>'can_control')::boolean, false),
            COALESCE((p_item->>'can_configure')::boolean, false),
            COALESCE((p_item->>'can_delete')::boolean, false),
            COALESCE((p_item->>'can_execute')::boolean, false),
            COALESCE((p_item->>'can_approve')::boolean, false),
            COALESCE((p_item->>'can_export')::boolean, false),
            COALESCE(p_item->>'location_scope', 'All Locations'),
            COALESCE(p_item->>'time_policy', 'Allowed (24 x 7)'),
            now()
        )
        ON CONFLICT (role_id, resource) DO UPDATE SET 
            can_view = EXCLUDED.can_view,
            can_control = EXCLUDED.can_control,
            can_configure = EXCLUDED.can_configure,
            can_delete = EXCLUDED.can_delete,
            can_execute = EXCLUDED.can_execute,
            can_approve = EXCLUDED.can_approve,
            can_export = EXCLUDED.can_export,
            location_scope = EXCLUDED.location_scope,
            time_policy = EXCLUDED.time_policy,
            updated_at = now();
    END LOOP;

    RETURN jsonb_build_object('success', true, 'message', 'Permissions matrix saved successfully');
END;
$$;


-- Function 6: List Real Institutional Users & Device Access Permissions (from profiles joined with app_roles & device access)
CREATE OR REPLACE FUNCTION public.fn_list_device_user_access(
    p_school_id UUID DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_role_id UUID DEFAULT NULL,
    p_role_name TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'full_name',
    p_sort_asc BOOLEAN DEFAULT true,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);
    v_total_count BIGINT;
    v_users JSONB;
BEGIN
    -- Count matching users from canonical profiles table
    SELECT count(*) INTO v_total_count
    FROM public.profiles p
    LEFT JOIN public.campus_device_user_access dua ON dua.user_id = p.id
    LEFT JOIN public.app_roles ar ON (dua.role_id = ar.id OR lower(ar.name) = lower(p.role) OR lower(ar.code) = lower(p.role))
    WHERE (p_school_id IS NULL OR p.school_id = p_school_id)
      AND (p_role_id IS NULL OR ar.id = p_role_id)
      AND (p_role_name IS NULL OR p_role_name = 'All Roles' OR lower(p.role) = lower(p_role_name) OR lower(COALESCE(ar.display_name, '')) = lower(p_role_name))
      AND (p_status IS NULL OR p_status = 'All Status' OR lower(COALESCE(dua.status, p.status, 'active')) = lower(p_status))
      AND (
          p_search IS NULL OR p_search = ''
          OR p.full_name ILIKE '%' || p_search || '%'
          OR p.email ILIKE '%' || p_search || '%'
          OR p.role ILIKE '%' || p_search || '%'
          OR COALESCE(p.department, '') ILIKE '%' || p_search || '%'
          OR COALESCE(dua.location_scope, '') ILIKE '%' || p_search || '%'
      );

    -- Fetch paginated users
    SELECT jsonb_agg(u_row) INTO v_users
    FROM (
        SELECT 
            p.id,
            p.full_name AS user_name,
            COALESCE(p.email, '') AS email,
            COALESCE(ar.display_name, initcap(replace(COALESCE(p.role, 'User'), '_', ' '))) AS role_name,
            COALESCE(p.department, 'General Staff') AS group_name,
            COALESCE(dua.location_scope, 
                CASE 
                    WHEN lower(p.role) = 'super_admin' THEN 'Entire Institution'
                    WHEN lower(p.role) = 'admin' THEN 'All Locations'
                    WHEN lower(p.role) = 'security' THEN 'Security & Gates'
                    ELSE 'Academic Block (A)'
                END
            ) AS location_scope,
            COALESCE(dua.access_level, 
                CASE 
                    WHEN lower(p.role) IN ('super_admin', 'admin') THEN 'Full Control'
                    WHEN lower(p.role) IN ('teacher', 'security') THEN 'Operator'
                    ELSE 'Monitor Only'
                END
            ) AS access_level,
            COALESCE(dua.status, p.status, 'Active') AS status,
            TO_CHAR(COALESCE(p.last_login, now()), 'DD Mon YYYY, HH12:MI AM') AS last_login,
            p.avatar_url,
            dua.building_id,
            dua.floor_id
        FROM public.profiles p
        LEFT JOIN public.campus_device_user_access dua ON dua.user_id = p.id
        LEFT JOIN public.app_roles ar ON (dua.role_id = ar.id OR lower(ar.name) = lower(p.role) OR lower(ar.code) = lower(p.role))
        WHERE (p_school_id IS NULL OR p.school_id = p_school_id)
          AND (p_role_id IS NULL OR ar.id = p_role_id)
          AND (p_role_name IS NULL OR p_role_name = 'All Roles' OR lower(p.role) = lower(p_role_name) OR lower(COALESCE(ar.display_name, '')) = lower(p_role_name))
          AND (p_status IS NULL OR p_status = 'All Status' OR lower(COALESCE(dua.status, p.status, 'active')) = lower(p_status))
          AND (
              p_search IS NULL OR p_search = ''
              OR p.full_name ILIKE '%' || p_search || '%'
              OR p.email ILIKE '%' || p_search || '%'
              OR p.role ILIKE '%' || p_search || '%'
              OR COALESCE(p.department, '') ILIKE '%' || p_search || '%'
              OR COALESCE(dua.location_scope, '') ILIKE '%' || p_search || '%'
          )
        ORDER BY 
            CASE WHEN p_sort_by = 'user_name' AND p_sort_asc THEN p.full_name END ASC,
            CASE WHEN p_sort_by = 'user_name' AND NOT p_sort_asc THEN p.full_name END DESC,
            CASE WHEN p_sort_by = 'role_name' AND p_sort_asc THEN p.role END ASC,
            CASE WHEN p_sort_by = 'role_name' AND NOT p_sort_asc THEN p.role END DESC,
            CASE WHEN p_sort_by = 'location_scope' AND p_sort_asc THEN COALESCE(dua.location_scope, 'All Locations') END ASC,
            CASE WHEN p_sort_by = 'location_scope' AND NOT p_sort_asc THEN COALESCE(dua.location_scope, 'All Locations') END DESC,
            CASE WHEN p_sort_by = 'status' AND p_sort_asc THEN COALESCE(dua.status, p.status, 'Active') END ASC,
            CASE WHEN p_sort_by = 'status' AND NOT p_sort_asc THEN COALESCE(dua.status, p.status, 'Active') END DESC,
            p.full_name ASC
        LIMIT p_page_size OFFSET v_offset
    ) u_row;

    RETURN jsonb_build_object(
        'success', true,
        'total_count', v_total_count,
        'page', p_page,
        'page_size', p_page_size,
        'users', COALESCE(v_users, '[]'::jsonb)
    );
END;
$$;


-- Procedure 7: Assign or Update User Device Access (Using User and Role Dropdowns)
CREATE OR REPLACE FUNCTION public.sp_assign_device_user_access(
    p_user_id UUID,
    p_role_id UUID DEFAULT NULL,
    p_location_scope TEXT DEFAULT 'All Locations',
    p_building_id UUID DEFAULT NULL,
    p_access_level TEXT DEFAULT 'Full Control',
    p_custom_permissions JSONB DEFAULT '[]'::jsonb,
    p_status TEXT DEFAULT 'Active'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_record RECORD;
    v_role_record RECORD;
BEGIN
    SELECT id, full_name, email, role, department INTO v_user_record 
    FROM public.profiles 
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Selected user not found in User Management profiles');
    END IF;

    IF p_role_id IS NOT NULL THEN
        SELECT id, name, COALESCE(display_name, name) as dname INTO v_role_record
        FROM public.app_roles
        WHERE id = p_role_id;
    END IF;

    -- Upsert user device access assignment
    INSERT INTO public.campus_device_user_access (
        user_id, role_id, building_id, location_scope, access_level, custom_permissions, status, updated_at
    ) VALUES (
        p_user_id,
        p_role_id,
        p_building_id,
        COALESCE(p_location_scope, 'All Locations'),
        COALESCE(p_access_level, 'Full Control'),
        COALESCE(p_custom_permissions, '[]'::jsonb),
        COALESCE(p_status, 'Active'),
        now()
    )
    ON CONFLICT (user_id) DO UPDATE SET 
        role_id = COALESCE(EXCLUDED.role_id, campus_device_user_access.role_id),
        building_id = COALESCE(EXCLUDED.building_id, campus_device_user_access.building_id),
        location_scope = EXCLUDED.location_scope,
        access_level = EXCLUDED.access_level,
        custom_permissions = EXCLUDED.custom_permissions,
        status = EXCLUDED.status,
        updated_at = now();

    -- Record Audit Log
    INSERT INTO public.campus_device_audit_logs (
        event_type, actor_id, actor_name, target_resource, action_details, status
    ) VALUES (
        'USER_PERMISSION_ASSIGN',
        p_user_id,
        v_user_record.full_name,
        'Device Access Permissions',
        'Updated device access: Scope=' || p_location_scope || ', Level=' || p_access_level,
        'Success'
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'User device permissions updated successfully',
        'user_id', p_user_id,
        'user_name', v_user_record.full_name,
        'role_name', COALESCE(v_role_record.dname, v_user_record.role),
        'location_scope', p_location_scope,
        'access_level', p_access_level,
        'status', p_status
    );
END;
$$;


-- Procedure 8: Revoke User Device Access
CREATE OR REPLACE FUNCTION public.sp_revoke_device_user_access(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.campus_device_user_access WHERE user_id = p_user_id;
    RETURN jsonb_build_object('success', true, 'message', 'User custom device access revoked');
END;
$$;


-- Procedure 9: Multi-Selection Bulk Actions on User Access
CREATE OR REPLACE FUNCTION public.sp_bulk_device_user_access_action(
    p_action TEXT,
    p_user_ids UUID[],
    p_role_id UUID DEFAULT NULL,
    p_location_scope TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count INT := 0;
BEGIN
    IF p_user_ids IS NULL OR array_length(p_user_ids, 1) = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'No users selected');
    END IF;

    IF lower(p_action) = 'activate' THEN
        UPDATE public.campus_device_user_access 
        SET status = 'Active', updated_at = now() 
        WHERE user_id = ANY(p_user_ids);
        GET DIAGNOSTICS v_count = ROW_COUNT;

    ELSIF lower(p_action) = 'deactivate' THEN
        UPDATE public.campus_device_user_access 
        SET status = 'Inactive', updated_at = now() 
        WHERE user_id = ANY(p_user_ids);
        GET DIAGNOSTICS v_count = ROW_COUNT;

    ELSIF lower(p_action) = 'update_scope' AND p_location_scope IS NOT NULL THEN
        UPDATE public.campus_device_user_access 
        SET location_scope = p_location_scope, updated_at = now() 
        WHERE user_id = ANY(p_user_ids);
        GET DIAGNOSTICS v_count = ROW_COUNT;

    ELSIF lower(p_action) = 'update_role' AND p_role_id IS NOT NULL THEN
        UPDATE public.campus_device_user_access 
        SET role_id = p_role_id, updated_at = now() 
        WHERE user_id = ANY(p_user_ids);
        GET DIAGNOSTICS v_count = ROW_COUNT;

    ELSIF lower(p_action) = 'revoke' THEN
        DELETE FROM public.campus_device_user_access 
        WHERE user_id = ANY(p_user_ids);
        GET DIAGNOSTICS v_count = ROW_COUNT;
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'Unrecognized bulk action: ' || p_action);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'action', p_action,
        'affected_rows', v_count,
        'message', 'Bulk ' || p_action || ' executed on ' || v_count || ' users'
    );
END;
$$;


-- Function 10: List Access Policies (ABAC)
CREATE OR REPLACE FUNCTION public.fn_list_device_access_policies(p_school_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_policies JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'policy_name', p.policy_name,
            'policy_code', p.policy_code,
            'description', p.description,
            'category', p.category,
            'target_scope', p.target_scope,
            'allowed_actions', p.allowed_actions,
            'denied_actions', p.denied_actions,
            'is_active', p.is_active,
            'priority', p.priority,
            'approval_required', p.approval_required,
            'created_at', p.created_at
        ) ORDER BY p.priority ASC, p.policy_name ASC
    ) INTO v_policies
    FROM public.campus_device_access_policies p;

    RETURN jsonb_build_object('success', true, 'policies', COALESCE(v_policies, '[]'::jsonb));
END;
$$;


-- Function 11: List Temporary Delegations
CREATE OR REPLACE FUNCTION public.fn_list_device_access_delegations(p_school_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_delegations JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', d.id,
            'delegatee_name', d.delegatee_name,
            'delegatee_email', d.delegatee_email,
            'delegator_name', d.delegator_name,
            'assigned_role', d.assigned_role,
            'location_scope', d.location_scope,
            'reason', d.reason,
            'start_time', TO_CHAR(d.start_time, 'YYYY-MM-DD HH24:MI'),
            'end_time', TO_CHAR(d.end_time, 'YYYY-MM-DD HH24:MI'),
            'status', d.status
        ) ORDER BY d.start_time DESC
    ) INTO v_delegations
    FROM public.campus_device_access_delegations d;

    RETURN jsonb_build_object('success', true, 'delegations', COALESCE(v_delegations, '[]'::jsonb));
END;
$$;


-- Function 12: List Access Requests
CREATE OR REPLACE FUNCTION public.fn_list_device_access_requests(p_school_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_requests JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', r.id,
            'requester_name', r.requester_name,
            'requester_email', r.requester_email,
            'requested_role', r.requested_role,
            'resource', r.resource,
            'requested_scope', r.requested_scope,
            'justification', r.justification,
            'urgency', r.urgency,
            'status', r.status,
            'reviewer_name', r.reviewer_name,
            'created_at', TO_CHAR(r.created_at, 'DD Mon YYYY, HH12:MI AM')
        ) ORDER BY r.created_at DESC
    ) INTO v_requests
    FROM public.campus_device_access_requests r;

    RETURN jsonb_build_object('success', true, 'requests', COALESCE(v_requests, '[]'::jsonb));
END;
$$;


-- Function 13: List Security Audit Logs
CREATE OR REPLACE FUNCTION public.fn_list_device_security_audit_logs(
    p_limit INT DEFAULT 50,
    p_search TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_logs JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', l.id,
            'event_type', l.event_type,
            'actor_name', l.actor_name,
            'actor_role', l.actor_role,
            'target_resource', l.target_resource,
            'action_details', l.action_details,
            'ip_address', l.ip_address,
            'status', l.status,
            'timestamp', TO_CHAR(l.timestamp, 'DD Mon YYYY, HH12:MI:SS AM')
        ) ORDER BY l.timestamp DESC
    ) INTO v_logs
    FROM (
        SELECT * FROM public.campus_device_audit_logs
        WHERE p_search IS NULL OR p_search = '' 
           OR actor_name ILIKE '%' || p_search || '%'
           OR event_type ILIKE '%' || p_search || '%'
           OR action_details ILIKE '%' || p_search || '%'
        ORDER BY timestamp DESC
        LIMIT p_limit
    ) l;

    RETURN jsonb_build_object('success', true, 'audit_logs', COALESCE(v_logs, '[]'::jsonb));
END;
$$;
