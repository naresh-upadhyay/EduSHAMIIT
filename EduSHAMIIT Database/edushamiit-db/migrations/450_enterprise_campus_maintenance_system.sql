-- ============================================================================
-- Migration: 450_enterprise_campus_maintenance_system.sql
-- Description: Production-grade Campus Maintenance Management Schema for EduSHAMIIT
--              Reuses campuses, buildings, building_floors, rooms, room_equipment,
--              inventory_items, and profiles.
-- ============================================================================

-- 1. Maintenance Requests Master
CREATE TABLE IF NOT EXISTS public.maintenance_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    request_code VARCHAR(50) NOT NULL, -- e.g. 'MT-0568'
    title VARCHAR(255) NOT NULL, -- e.g. 'AC not cooling'
    description TEXT,
    request_type VARCHAR(50) NOT NULL DEFAULT 'HVAC', -- HVAC, Electrical, Plumbing, Civil, Furniture, AV Equipment, Sanitation, IT / Network, Other
    priority VARCHAR(20) NOT NULL DEFAULT 'Medium', -- High, Medium, Low, Critical
    status VARCHAR(30) NOT NULL DEFAULT 'Pending', -- Pending, Assigned, In Progress, Scheduled, On Hold, Awaiting Parts, Awaiting Vendor, Resolved, Closed, Cancelled

    -- Physical Infrastructure Location Hierarchy (Reused from Campus)
    campus_id UUID REFERENCES public.campuses(id) ON DELETE SET NULL,
    building_id UUID REFERENCES public.buildings(id) ON DELETE SET NULL,
    floor_id UUID REFERENCES public.building_floors(id) ON DELETE SET NULL,
    room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL,
    location_display VARCHAR(150) NOT NULL, -- e.g. 'B1 / G-101'
    specific_location TEXT, -- e.g. 'Near blackboard', 'Second row right'

    -- Equipment & Inventory Linkage (Reused)
    equipment_id UUID REFERENCES public.room_equipment(id) ON DELETE SET NULL,
    asset_id UUID REFERENCES public.inventory_items(id) ON DELETE SET NULL,

    -- Reporter Details
    reported_by_name VARCHAR(150) NOT NULL, -- e.g. 'Rohan Verma'
    reported_by_role VARCHAR(50) NOT NULL DEFAULT 'Student', -- Student, Teacher, Staff, Admin
    reported_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    preferred_date DATE,
    preferred_time VARCHAR(30),

    -- SLA & Assignment Details
    due_date TIMESTAMPTZ,
    sla_hours NUMERIC(6, 2) DEFAULT 24.0,
    is_overdue BOOLEAN NOT NULL DEFAULT FALSE,
    assigned_to_name VARCHAR(150),
    assigned_to_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    assigned_vendor_id UUID,
    assigned_vendor_name VARCHAR(150),

    -- Execution Timestamps
    scheduled_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    resolution_notes TEXT,

    -- Financials & Preventive linkage
    is_preventive BOOLEAN NOT NULL DEFAULT FALSE,
    plan_id UUID,
    estimated_cost NUMERIC(12, 2) DEFAULT 0.00,
    actual_cost NUMERIC(12, 2) DEFAULT 0.00,

    -- Files, Metadata & Auditing
    attachments JSONB NOT NULL DEFAULT '[]'::JSONB,
    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

-- Unique constraint on request_code per school
CREATE UNIQUE INDEX IF NOT EXISTS uq_maintenance_requests_school_code 
    ON public.maintenance_requests (school_id, UPPER(request_code)) 
    WHERE deleted_at IS NULL;

-- High-performance query indexes
CREATE INDEX IF NOT EXISTS idx_maintenance_requests_school_status 
    ON public.maintenance_requests (school_id, status) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_maintenance_requests_building 
    ON public.maintenance_requests (building_id) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_maintenance_requests_room 
    ON public.maintenance_requests (room_id) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_maintenance_requests_type 
    ON public.maintenance_requests (school_id, request_type) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_maintenance_requests_priority 
    ON public.maintenance_requests (school_id, priority) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_maintenance_requests_assigned 
    ON public.maintenance_requests (assigned_to_user_id) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_maintenance_requests_reported_at 
    ON public.maintenance_requests (school_id, reported_at DESC) 
    WHERE deleted_at IS NULL;


-- 2. Maintenance Status History (Audit Trail & State Machine Transitions)
CREATE TABLE IF NOT EXISTS public.maintenance_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    request_id UUID NOT NULL REFERENCES public.maintenance_requests(id) ON DELETE CASCADE,
    from_status VARCHAR(30),
    to_status VARCHAR(30) NOT NULL,
    changed_by_name VARCHAR(150) NOT NULL,
    changed_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_maintenance_status_history_request 
    ON public.maintenance_status_history (request_id, created_at ASC);


-- 3. Preventive Maintenance Plans Master
CREATE TABLE IF NOT EXISTS public.maintenance_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    plan_code VARCHAR(50) NOT NULL, -- e.g. 'MP-001'
    title VARCHAR(200) NOT NULL, -- e.g. 'AC Annual Servicing & Filter Replacement'
    category VARCHAR(50) NOT NULL DEFAULT 'HVAC',
    frequency VARCHAR(30) NOT NULL DEFAULT 'Monthly', -- Daily, Weekly, Monthly, Quarterly, Half-Yearly, Annually
    building_id UUID REFERENCES public.buildings(id) ON DELETE SET NULL,
    room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL,
    equipment_id UUID REFERENCES public.room_equipment(id) ON DELETE SET NULL,
    checklist_items JSONB NOT NULL DEFAULT '[]'::JSONB,
    assigned_team VARCHAR(100) DEFAULT 'Maintenance Team',
    assigned_technician_name VARCHAR(150),
    assigned_technician_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    estimated_duration_hours NUMERIC(4, 1) DEFAULT 2.0,
    estimated_cost NUMERIC(10, 2) DEFAULT 0.00,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_run_date DATE,
    next_due_date DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_maintenance_plans_school_code 
    ON public.maintenance_plans (school_id, UPPER(plan_code));


-- 4. Maintenance Vendors & Service Contracts (AMC / External Providers)
CREATE TABLE IF NOT EXISTS public.maintenance_vendors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    vendor_name VARCHAR(150) NOT NULL, -- e.g. 'CoolAir Solutions Pvt Ltd'
    contact_person VARCHAR(100),
    phone VARCHAR(30),
    email VARCHAR(100),
    service_category VARCHAR(100) NOT NULL DEFAULT 'HVAC',
    contract_type VARCHAR(50) NOT NULL DEFAULT 'AMC', -- AMC, Comprehensive AMC, On-Demand, Warranty
    contract_start DATE,
    contract_end DATE,
    sla_response_hours NUMERIC(4, 1) DEFAULT 4.0,
    sla_resolution_hours NUMERIC(4, 1) DEFAULT 24.0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- 5. Spare Parts Consumed (Inventory Integration)
CREATE TABLE IF NOT EXISTS public.maintenance_parts_consumed (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    request_id UUID NOT NULL REFERENCES public.maintenance_requests(id) ON DELETE CASCADE,
    item_id UUID REFERENCES public.inventory_items(id) ON DELETE SET NULL,
    item_name VARCHAR(150) NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    unit_cost NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    total_cost NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    consumed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_maintenance_parts_request 
    ON public.maintenance_parts_consumed (request_id);


-- ----------------------------------------------------------------------------
-- Row Level Security (RLS)
-- ----------------------------------------------------------------------------
ALTER TABLE public.maintenance_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_parts_consumed ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated read maintenance_requests" ON public.maintenance_requests;
DROP POLICY IF EXISTS "Allow authenticated insert maintenance_requests" ON public.maintenance_requests;
DROP POLICY IF EXISTS "Allow authenticated update maintenance_requests" ON public.maintenance_requests;
DROP POLICY IF EXISTS "Allow authenticated delete maintenance_requests" ON public.maintenance_requests;

CREATE POLICY "Allow authenticated read maintenance_requests" 
    ON public.maintenance_requests FOR SELECT USING (true);
CREATE POLICY "Allow authenticated insert maintenance_requests" 
    ON public.maintenance_requests FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow authenticated update maintenance_requests" 
    ON public.maintenance_requests FOR UPDATE USING (true);
CREATE POLICY "Allow authenticated delete maintenance_requests" 
    ON public.maintenance_requests FOR DELETE USING (true);

DROP POLICY IF EXISTS "Allow public on status history" ON public.maintenance_status_history;
DROP POLICY IF EXISTS "Allow public on maintenance plans" ON public.maintenance_plans;
DROP POLICY IF EXISTS "Allow public on maintenance vendors" ON public.maintenance_vendors;
DROP POLICY IF EXISTS "Allow public on maintenance parts" ON public.maintenance_parts_consumed;

CREATE POLICY "Allow public on status history" 
    ON public.maintenance_status_history FOR ALL USING (true);
CREATE POLICY "Allow public on maintenance plans" 
    ON public.maintenance_plans FOR ALL USING (true);
CREATE POLICY "Allow public on maintenance vendors" 
    ON public.maintenance_vendors FOR ALL USING (true);
CREATE POLICY "Allow public on maintenance parts" 
    ON public.maintenance_parts_consumed FOR ALL USING (true);
