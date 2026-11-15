-- ============================================================================
-- Migration: 444_enterprise_campus_buildings_and_rooms.sql
-- Description: Enterprise Campus Infrastructure Schema:
--              1. campuses (Multi-tenant campus / branch sites)
--              2. buildings (Multi-tenant buildings, blocks, facilities)
--              3. building_floors (Ordered floor hierarchy with basement support)
--              4. rooms (Independent physical spaces: classrooms, labs, offices, washrooms, utility, etc.)
--              5. room_equipment (Per-room equipment & asset tracking with individual status)
--              6. room_assignments (Cross-module reusable assignment references)
--              7. building_documents (Compliance, blueprint, and safety certificates)
--              8. building_inspections (Routine, fire safety, and structural inspections)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Campuses Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.campuses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    code VARCHAR(50) NOT NULL,
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100) DEFAULT 'India',
    postal_code VARCHAR(30),
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, INACTIVE, ARCHIVED
    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_campuses_school_code 
    ON public.campuses (school_id, UPPER(code)) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_campuses_school_status 
    ON public.campuses (school_id, status) 
    WHERE deleted_at IS NULL;


-- ----------------------------------------------------------------------------
-- 2. Buildings Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.buildings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    campus_id UUID REFERENCES public.campuses(id) ON DELETE SET NULL,
    name VARCHAR(150) NOT NULL,
    code VARCHAR(50) NOT NULL,
    building_type VARCHAR(50) NOT NULL DEFAULT 'Academic', -- Academic, Administrative, Residential, Hostel, Library, Laboratory, Sports, Auditorium, Dining / Canteen, Medical, Utility, Storage, Other
    description TEXT,
    purpose TEXT,
    address TEXT,
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    total_floors INT NOT NULL DEFAULT 1,
    total_area NUMERIC(12, 2) DEFAULT 0,
    area_unit VARCHAR(20) NOT NULL DEFAULT 'sq ft', -- sq ft, sq m
    construction_year INT,
    num_entrances INT DEFAULT 1,
    num_emergency_exits INT DEFAULT 1,
    manager_name VARCHAR(150),
    manager_contact VARCHAR(50),
    manager_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    department VARCHAR(100),
    image_url TEXT,
    fire_safety_cert_expiry DATE,
    occupancy_cert_expiry DATE,
    status VARCHAR(30) NOT NULL DEFAULT 'Active', -- Active, Under Construction, Under Renovation, Temporarily Closed, Inactive, Archived
    notes TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_buildings_school_code 
    ON public.buildings (school_id, UPPER(code)) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_buildings_school_status 
    ON public.buildings (school_id, status) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_buildings_type 
    ON public.buildings (school_id, building_type) 
    WHERE deleted_at IS NULL;


-- ----------------------------------------------------------------------------
-- 3. Building Floors Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.building_floors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    floor_code VARCHAR(50) NOT NULL,
    floor_level INT NOT NULL DEFAULT 0, -- e.g. -2: B2, -1: B1, 0: Ground, 1: 1st, 2: 2nd, etc.
    floor_order INT NOT NULL DEFAULT 0,
    floor_type VARCHAR(50) DEFAULT 'Standard',
    area NUMERIC(12, 2) DEFAULT 0,
    description TEXT,
    floor_plan_url TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'Active', -- Active, Under Maintenance, Under Renovation, Inactive
    notes TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_building_floors_code 
    ON public.building_floors (building_id, UPPER(floor_code)) 
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_building_floors_level 
    ON public.building_floors (building_id, floor_level) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_building_floors_order 
    ON public.building_floors (building_id, floor_level ASC, floor_order ASC) 
    WHERE deleted_at IS NULL;


-- ----------------------------------------------------------------------------
-- 4. Rooms Table (Physical Spaces)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    floor_id UUID NOT NULL REFERENCES public.building_floors(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    room_number VARCHAR(50) NOT NULL,
    room_code VARCHAR(50) NOT NULL,
    room_type VARCHAR(50) NOT NULL DEFAULT 'Classroom',
    description TEXT,
    purpose TEXT,
    area NUMERIC(10, 2) DEFAULT 0,
    area_unit VARCHAR(20) NOT NULL DEFAULT 'sq ft',
    length NUMERIC(10, 2) DEFAULT 0,
    width NUMERIC(10, 2) DEFAULT 0,
    height NUMERIC(10, 2) DEFAULT 0,
    max_capacity INT NOT NULL DEFAULT 40,
    recommended_capacity INT DEFAULT 35,
    current_occupancy INT NOT NULL DEFAULT 0,
    bed_count INT DEFAULT 0,
    seating_capacity INT DEFAULT 40,
    workstation_count INT DEFAULT 0,
    num_doors INT DEFAULT 1,
    num_windows INT DEFAULT 2,
    operational_status VARCHAR(30) NOT NULL DEFAULT 'Available', -- Available, Occupied, Reserved, Under Maintenance, Temporarily Unavailable, Inactive
    assignment_status VARCHAR(30) NOT NULL DEFAULT 'Unassigned', -- Unassigned, Assigned, Partially Assigned, Reserved
    is_differently_abled_accessible BOOLEAN NOT NULL DEFAULT TRUE,
    lift_proximity VARCHAR(50) DEFAULT 'Nearby',
    emergency_exit_proximity VARCHAR(50) DEFAULT 'Direct Access',
    location_notes TEXT,
    image_url TEXT,
    floor_plan_ref TEXT,
    responsible_department VARCHAR(100),
    responsible_person_name VARCHAR(150),
    responsible_person_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT chk_room_capacity_non_negative CHECK (max_capacity >= 0),
    CONSTRAINT chk_room_seating_non_negative CHECK (seating_capacity >= 0),
    CONSTRAINT chk_room_bed_non_negative CHECK (bed_count >= 0),
    CONSTRAINT chk_room_workstation_non_negative CHECK (workstation_count >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_rooms_building_number 
    ON public.rooms (building_id, UPPER(room_number)) 
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_rooms_school_code 
    ON public.rooms (school_id, UPPER(room_code)) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_rooms_floor 
    ON public.rooms (floor_id) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_rooms_building_status 
    ON public.rooms (building_id, operational_status) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_rooms_type 
    ON public.rooms (school_id, room_type) 
    WHERE deleted_at IS NULL;


-- ----------------------------------------------------------------------------
-- 5. Room Equipment & Facilities Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.room_equipment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    floor_id UUID NOT NULL REFERENCES public.building_floors(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    equipment_name VARCHAR(150) NOT NULL,
    equipment_category VARCHAR(100) NOT NULL DEFAULT 'General Fixture', -- Electrical, IT & AV, Furniture, Plumbing & Sanitation, Safety & Medical, HVAC, Laboratory, General Fixture
    asset_id UUID, -- Optional reference to Inventory Management Asset ID
    quantity INT NOT NULL DEFAULT 1,
    condition VARCHAR(30) NOT NULL DEFAULT 'Good', -- New, Excellent, Good, Fair, Poor, Damaged
    operational_status VARCHAR(30) NOT NULL DEFAULT 'Operational', -- Operational, Not Working, Under Maintenance, Degraded, Decommissioned
    installation_date DATE,
    last_service_date DATE,
    next_service_date DATE,
    remarks TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    CONSTRAINT chk_equipment_quantity_positive CHECK (quantity > 0)
);

CREATE INDEX IF NOT EXISTS idx_room_equipment_room 
    ON public.room_equipment (room_id) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_room_equipment_status 
    ON public.room_equipment (school_id, operational_status) 
    WHERE deleted_at IS NULL;


-- ----------------------------------------------------------------------------
-- 6. Room Assignments (Reusable Cross-Module Reference System)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.room_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    reference_module VARCHAR(50) NOT NULL, -- Academic, Timetable, Hostel, Library, Department, Event, Other
    reference_entity_id UUID,
    reference_name VARCHAR(150),
    assignment_purpose VARCHAR(150) NOT NULL DEFAULT 'General Allocation',
    start_date DATE,
    end_date DATE,
    start_time TIME,
    end_time TIME,
    day_of_week INT,
    status VARCHAR(30) NOT NULL DEFAULT 'Active', -- Active, Completed, Cancelled, Expired
    assigned_to_name VARCHAR(150),
    notes TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_room_assignments_room 
    ON public.room_assignments (room_id, status) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_room_assignments_module_entity 
    ON public.room_assignments (reference_module, reference_entity_id) 
    WHERE deleted_at IS NULL;


-- ----------------------------------------------------------------------------
-- 7. Building Documents Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.building_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL,
    document_name VARCHAR(200) NOT NULL,
    document_type VARCHAR(50) NOT NULL DEFAULT 'Compliance', -- Compliance, Certificate, Blueprint, Inspection, Maintenance, Fire Safety, Occupancy, Other
    file_url TEXT NOT NULL,
    file_size_bytes BIGINT DEFAULT 0,
    mime_type VARCHAR(100) DEFAULT 'application/pdf',
    issue_date DATE,
    expiry_date DATE,
    issuing_authority VARCHAR(150),
    status VARCHAR(30) NOT NULL DEFAULT 'Valid', -- Valid, Expired, Pending Renewal
    uploaded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_building_documents_building 
    ON public.building_documents (building_id) 
    WHERE deleted_at IS NULL;


-- ----------------------------------------------------------------------------
-- 8. Building Inspections Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.building_inspections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    inspection_type VARCHAR(50) NOT NULL DEFAULT 'Routine Safety', -- Routine Safety, Fire Safety, Structural, Electrical, Hygiene & Sanitation, HVAC
    inspection_date DATE NOT NULL DEFAULT CURRENT_DATE,
    inspector_name VARCHAR(150) NOT NULL,
    result VARCHAR(30) NOT NULL DEFAULT 'Passed', -- Passed, Passed with Observations, Failed, Action Required
    next_inspection_date DATE,
    findings TEXT,
    recommendations TEXT,
    attachments JSONB NOT NULL DEFAULT '[]'::JSONB,
    status VARCHAR(30) NOT NULL DEFAULT 'Completed', -- Scheduled, In Progress, Completed, Followup Needed
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_building_inspections_building 
    ON public.building_inspections (building_id, inspection_date DESC);
