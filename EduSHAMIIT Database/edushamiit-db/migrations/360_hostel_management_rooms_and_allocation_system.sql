-- ============================================================================
-- Migration: 360_hostel_management_rooms_and_allocation_system.sql
-- Description: Complete Production-Grade Hostel Management System
--              Physical Hierarchy (Campuses, Buildings, Floors, Rooms/Spaces, Beds, Equipment/Facilities),
--              Allocation Engine (Assignments, Reservations, Transfers, Check-in/out, Rollovers),
--              Maintenance & Housekeeping, Multi-tenant Isolation, Dynamic Calculations & KPI Functions
-- ============================================================================

-- 1. Hostel Campuses (Optional grouping per institution)
CREATE TABLE IF NOT EXISTS public.hostel_campuses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(150) NOT NULL,
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, INACTIVE
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_campuses_school_code 
    ON public.hostel_campuses (school_id, UPPER(code)) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_hostel_campuses_school 
    ON public.hostel_campuses (school_id, status) 
    WHERE deleted_at IS NULL;


-- 2. Hostel Buildings / Blocks
CREATE TABLE IF NOT EXISTS public.hostel_buildings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    campus_id UUID REFERENCES public.hostel_campuses(id) ON DELETE SET NULL,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(150) NOT NULL,
    hostel_name VARCHAR(150) NOT NULL, -- e.g. "Boys Hostel A", "Girls Hostel A"
    gender_policy VARCHAR(20) NOT NULL DEFAULT 'BOYS', -- BOYS, GIRLS, COED, STAFF
    building_type VARCHAR(50) NOT NULL DEFAULT 'RESIDENTIAL', -- RESIDENTIAL, MIXED, STAFF_QUARTERS
    total_floors INT NOT NULL DEFAULT 1,
    address TEXT,
    description TEXT,
    photos JSONB NOT NULL DEFAULT '[]'::JSONB,
    accessibility JSONB NOT NULL DEFAULT '{"wheelchair_accessible": true, "elevators": true, "ramps": true}'::JSONB,
    emergency_facilities JSONB NOT NULL DEFAULT '{"fire_alarms": true, "extinguishers": true, "emergency_stairs": true}'::JSONB,
    wardens JSONB NOT NULL DEFAULT '[]'::JSONB,
    operational_status VARCHAR(30) NOT NULL DEFAULT 'OPERATIONAL', -- OPERATIONAL, MAINTENANCE, CLOSED, RENOVATION
    version INT NOT NULL DEFAULT 1,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_buildings_school_code 
    ON public.hostel_buildings (school_id, UPPER(code)) 
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_buildings_school_name 
    ON public.hostel_buildings (school_id, UPPER(name)) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_hostel_buildings_school_status 
    ON public.hostel_buildings (school_id, operational_status) 
    WHERE deleted_at IS NULL;


-- 3. Hostel Floors
CREATE TABLE IF NOT EXISTS public.hostel_floors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    building_id UUID NOT NULL REFERENCES public.hostel_buildings(id) ON DELETE CASCADE,
    floor_number INT NOT NULL, -- 0 = Ground Floor, 1 = 1st Floor, 2 = 2nd Floor, -1 = Basement
    floor_code VARCHAR(50) NOT NULL, -- 'G', '1', '2', 'B1'
    floor_name VARCHAR(100) NOT NULL, -- 'Ground Floor', '1st Floor', '2nd Floor'
    wing VARCHAR(50),
    evacuation_details TEXT,
    floor_plan_url VARCHAR(500),
    operational_status VARCHAR(30) NOT NULL DEFAULT 'OPERATIONAL', -- OPERATIONAL, MAINTENANCE, CLOSED
    version INT NOT NULL DEFAULT 1,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_floors_building_number 
    ON public.hostel_floors (building_id, floor_number) 
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_floors_building_code 
    ON public.hostel_floors (building_id, UPPER(floor_code)) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_hostel_floors_building 
    ON public.hostel_floors (school_id, building_id) 
    WHERE deleted_at IS NULL;


-- 4. Hostel Rooms / Spaces
CREATE TABLE IF NOT EXISTS public.hostel_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    building_id UUID NOT NULL REFERENCES public.hostel_buildings(id) ON DELETE CASCADE,
    floor_id UUID NOT NULL REFERENCES public.hostel_floors(id) ON DELETE CASCADE,
    room_number VARCHAR(50) NOT NULL, -- e.g. 'A-101', 'A-102'
    room_code VARCHAR(100) NOT NULL,  -- e.g. 'BHA-1-101'
    room_name VARCHAR(150),
    wing VARCHAR(50),
    room_type_id UUID REFERENCES public.lookup_values(id) ON DELETE SET NULL,
    room_type VARCHAR(100) NOT NULL DEFAULT 'Standard', -- Standard, Deluxe, Dormitory, Study Room, Toilet/Washroom, etc.
    is_residential BOOLEAN NOT NULL DEFAULT TRUE, -- TRUE for bedrooms/dorms; FALSE for washroom, study, pantry, etc.
    target_capacity INT NOT NULL DEFAULT 1, -- Derived capacity when beds exist; manual target when beds not yet added
    current_occupancy INT NOT NULL DEFAULT 0,
    room_size_sqm NUMERIC(8,2) DEFAULT 18.0,
    monthly_fee NUMERIC(10,2) DEFAULT 6000.0,
    gender_restriction VARCHAR(20) NOT NULL DEFAULT 'BOYS', -- BOYS, GIRLS, COED, ANY
    accessibility_features JSONB NOT NULL DEFAULT '[]'::JSONB,
    operational_status VARCHAR(30) NOT NULL DEFAULT 'AVAILABLE', -- AVAILABLE, OCCUPIED, MAINTENANCE, OUT_OF_SERVICE, OPERATIONAL
    cleanliness_status VARCHAR(30) NOT NULL DEFAULT 'CLEAN', -- CLEAN, NEEDS_CLEANING, IN_PROGRESS, INSPECTED
    condition_status VARCHAR(30) NOT NULL DEFAULT 'GOOD', -- GOOD, FAIR, NEEDS_REPAIR
    photos JSONB NOT NULL DEFAULT '[]'::JSONB,
    amenities JSONB NOT NULL DEFAULT '[]'::JSONB,
    map_coordinates JSONB DEFAULT '{"x": 0, "y": 0, "width": 100, "height": 80}'::JSONB,
    inspection_schedule TEXT,
    maintenance_rules TEXT,
    version INT NOT NULL DEFAULT 1,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_rooms_building_floor_number 
    ON public.hostel_rooms (building_id, floor_id, UPPER(room_number)) 
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_rooms_school_code 
    ON public.hostel_rooms (school_id, UPPER(room_code)) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_hostel_rooms_lookup 
    ON public.hostel_rooms (school_id, building_id, floor_id, operational_status) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_hostel_rooms_type 
    ON public.hostel_rooms (school_id, is_residential, room_type) 
    WHERE deleted_at IS NULL;


-- 5. Hostel Beds (Individual Inventory for Residential Rooms)
CREATE TABLE IF NOT EXISTS public.hostel_beds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    building_id UUID NOT NULL REFERENCES public.hostel_buildings(id) ON DELETE CASCADE,
    floor_id UUID NOT NULL REFERENCES public.hostel_floors(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES public.hostel_rooms(id) ON DELETE CASCADE,
    bed_code VARCHAR(50) NOT NULL, -- e.g. 'A-101-A', 'A-101-B', 'Bed 1'
    bed_type VARCHAR(50) NOT NULL DEFAULT 'Single', -- Single, Bunk (Lower), Bunk (Upper), Accessible
    dimensions VARCHAR(50) DEFAULT '3x6 ft',
    condition VARCHAR(30) NOT NULL DEFAULT 'GOOD', -- GOOD, FAIR, DAMAGED, NEEDS_REPLACEMENT
    status VARCHAR(30) NOT NULL DEFAULT 'AVAILABLE', -- AVAILABLE, RESERVED, OCCUPIED, BLOCKED, MAINTENANCE, OUT_OF_SERVICE, RETIRED
    fee_category VARCHAR(50) DEFAULT 'Standard',
    asset_id VARCHAR(100),
    monthly_fee NUMERIC(10,2),
    version INT NOT NULL DEFAULT 1,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_beds_room_code 
    ON public.hostel_beds (room_id, UPPER(bed_code)) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_hostel_beds_room_status 
    ON public.hostel_beds (school_id, room_id, status) 
    WHERE deleted_at IS NULL;


-- 6. Hostel Room Equipment and Facilities
CREATE TABLE IF NOT EXISTS public.hostel_room_equipment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    building_id UUID NOT NULL REFERENCES public.hostel_buildings(id) ON DELETE CASCADE,
    floor_id UUID NOT NULL REFERENCES public.hostel_floors(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES public.hostel_rooms(id) ON DELETE CASCADE,
    equipment_name VARCHAR(150) NOT NULL, -- 'Beds', 'Fans', 'AC', 'WiFi', 'Study Table', 'Wardrobe', 'Attached Washroom', 'Geyser', 'Television', 'Power Outlets', 'Lighting', 'Balcony', 'Housekeeping'
    equipment_category VARCHAR(50) NOT NULL DEFAULT 'FURNITURE', -- FURNITURE, ELECTRICAL, PLUMBING, ELECTRONICS, SAFETY, AMENITY
    equipment_type_id UUID REFERENCES public.lookup_values(id) ON DELETE SET NULL,
    quantity INT NOT NULL DEFAULT 1,
    asset_code VARCHAR(100),
    serial_number VARCHAR(100),
    status VARCHAR(30) NOT NULL DEFAULT 'GOOD', -- GOOD, WORKING, FAULTY, UNDER_REPAIR, NOT_AVAILABLE, REPLACED, OUT_OF_SERVICE
    is_critical BOOLEAN NOT NULL DEFAULT FALSE,
    installed_date DATE DEFAULT CURRENT_DATE,
    warranty_expiry DATE,
    last_inspection_date DATE,
    next_inspection_date DATE,
    notes TEXT,
    photos JSONB NOT NULL DEFAULT '[]'::JSONB,
    version INT NOT NULL DEFAULT 1,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_hostel_equipment_room 
    ON public.hostel_room_equipment (school_id, room_id, status) 
    WHERE deleted_at IS NULL;


-- 7. Hostel Student Allocations
CREATE TABLE IF NOT EXISTS public.hostel_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    academic_year VARCHAR(50) NOT NULL DEFAULT '2024 - 2025',
    building_id UUID NOT NULL REFERENCES public.hostel_buildings(id) ON DELETE CASCADE,
    floor_id UUID NOT NULL REFERENCES public.hostel_floors(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES public.hostel_rooms(id) ON DELETE CASCADE,
    bed_id UUID REFERENCES public.hostel_beds(id) ON DELETE SET NULL,
    allocation_status VARCHAR(30) NOT NULL DEFAULT 'CHECKED_IN', 
    -- REQUESTED, RESERVED, CONFIRMED, CHECKED_IN, TEMPORARILY_RELOCATED, CHECKED_OUT, CANCELLED, REJECTED, WAITLISTED
    requested_at TIMESTAMPTZ DEFAULT NOW(),
    reserved_until TIMESTAMPTZ,
    check_in_date TIMESTAMPTZ DEFAULT NOW(),
    check_out_date TIMESTAMPTZ,
    actual_check_out_date TIMESTAMPTZ,
    monthly_fee NUMERIC(10,2) DEFAULT 6000.0,
    deposit_amount NUMERIC(10,2) DEFAULT 10000.0,
    fee_status VARCHAR(30) NOT NULL DEFAULT 'PAID', -- PAID, PENDING, PARTIAL, WAIVED
    payment_reference VARCHAR(100),
    allocation_reason TEXT,
    special_needs TEXT,
    requested_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    documents JSONB NOT NULL DEFAULT '[]'::JSONB,
    version INT NOT NULL DEFAULT 1,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

-- Constraint: Individual bed can have AT MOST ONE active allocation
CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_active_bed_allocation 
    ON public.hostel_allocations (bed_id) 
    WHERE bed_id IS NOT NULL 
      AND deleted_at IS NULL 
      AND allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED');

-- Constraint: A student can have AT MOST ONE active allocation in a school + academic session
CREATE UNIQUE INDEX IF NOT EXISTS uq_hostel_active_student_allocation 
    ON public.hostel_allocations (school_id, student_id, academic_year) 
    WHERE deleted_at IS NULL 
      AND allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED');

CREATE INDEX IF NOT EXISTS idx_hostel_allocations_room 
    ON public.hostel_allocations (school_id, room_id, allocation_status) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_hostel_allocations_student 
    ON public.hostel_allocations (school_id, student_id) 
    WHERE deleted_at IS NULL;


-- 8. Allocation Event History (Immutable Audit Log)
CREATE TABLE IF NOT EXISTS public.hostel_allocation_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    allocation_id UUID REFERENCES public.hostel_allocations(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    room_id UUID REFERENCES public.hostel_rooms(id) ON DELETE SET NULL,
    bed_id UUID REFERENCES public.hostel_beds(id) ON DELETE SET NULL,
    event_type VARCHAR(50) NOT NULL, -- REQUESTED, APPROVED, REJECTED, RESERVED, CONFIRMED, CHECKED_IN, TRANSFERRED, SWAPPED, TEMP_RELOCATED, CHECKED_OUT, EXTENDED, CANCELLED
    from_room_id UUID REFERENCES public.hostel_rooms(id) ON DELETE SET NULL,
    from_bed_id UUID REFERENCES public.hostel_beds(id) ON DELETE SET NULL,
    to_room_id UUID REFERENCES public.hostel_rooms(id) ON DELETE SET NULL,
    to_bed_id UUID REFERENCES public.hostel_beds(id) ON DELETE SET NULL,
    reason TEXT,
    notes TEXT,
    performed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hostel_events_alloc 
    ON public.hostel_allocation_events (school_id, allocation_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_hostel_events_student 
    ON public.hostel_allocation_events (school_id, student_id, created_at DESC);


-- 9. Hostel Maintenance Tickets
CREATE TABLE IF NOT EXISTS public.hostel_maintenance_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    building_id UUID NOT NULL REFERENCES public.hostel_buildings(id) ON DELETE CASCADE,
    floor_id UUID REFERENCES public.hostel_floors(id) ON DELETE CASCADE,
    room_id UUID REFERENCES public.hostel_rooms(id) ON DELETE SET NULL,
    bed_id UUID REFERENCES public.hostel_beds(id) ON DELETE SET NULL,
    equipment_id UUID REFERENCES public.hostel_room_equipment(id) ON DELETE SET NULL,
    ticket_number VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    priority VARCHAR(20) NOT NULL DEFAULT 'MEDIUM', -- LOW, MEDIUM, HIGH, CRITICAL
    status VARCHAR(30) NOT NULL DEFAULT 'OPEN', -- OPEN, ASSIGNED, IN_PROGRESS, RESOLVED, VERIFIED, CLOSED, CANCELLED
    blocks_allocation BOOLEAN NOT NULL DEFAULT FALSE,
    assigned_to UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    vendor_name VARCHAR(150),
    estimated_cost NUMERIC(10,2) DEFAULT 0.0,
    actual_cost NUMERIC(10,2) DEFAULT 0.0,
    reported_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    sla_due_date TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    before_photos JSONB NOT NULL DEFAULT '[]'::JSONB,
    after_photos JSONB NOT NULL DEFAULT '[]'::JSONB,
    resolution_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_hostel_tickets_room 
    ON public.hostel_maintenance_tickets (school_id, room_id, status) 
    WHERE deleted_at IS NULL;


-- ============================================================================
-- BUSINESS LOGIC FUNCTIONS & PROCEDURES
-- ============================================================================

-- A. Synchronize Room Capacity, Occupancy & Status Helper
CREATE OR REPLACE FUNCTION public.fn_hostel_recalculate_room(p_room_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_active_beds INT := 0;
    v_occupied_beds INT := 0;
    v_is_residential BOOLEAN := TRUE;
    v_room_status VARCHAR(30) := 'AVAILABLE';
    v_maint_count INT := 0;
    v_active_allocations INT := 0;
BEGIN
    SELECT is_residential, operational_status INTO v_is_residential, v_room_status 
    FROM public.hostel_rooms 
    WHERE id = p_room_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- Count open maintenance tickets that block allocation
    SELECT COUNT(*) INTO v_maint_count
    FROM public.hostel_maintenance_tickets
    WHERE room_id = p_room_id AND deleted_at IS NULL AND blocks_allocation = TRUE AND status NOT IN ('RESOLVED', 'CLOSED', 'CANCELLED');

    IF NOT v_is_residential THEN
        -- Non-residential room (e.g. washroom, study room)
        IF v_maint_count > 0 THEN
            v_room_status := 'MAINTENANCE';
        ELSE
            v_room_status := 'OPERATIONAL';
        END IF;

        UPDATE public.hostel_rooms
        SET target_capacity = 0,
            current_occupancy = 0,
            operational_status = v_room_status,
            updated_at = NOW()
        WHERE id = p_room_id;
        RETURN;
    END IF;

    -- Residential room: count active beds
    SELECT COUNT(*) INTO v_active_beds
    FROM public.hostel_beds
    WHERE room_id = p_room_id AND deleted_at IS NULL AND status NOT IN ('RETIRED', 'OUT_OF_SERVICE');

    -- Count active allocations
    SELECT COUNT(*) INTO v_active_allocations
    FROM public.hostel_allocations
    WHERE room_id = p_room_id 
      AND deleted_at IS NULL 
      AND allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED');

    IF v_maint_count > 0 THEN
        v_room_status := 'MAINTENANCE';
    ELSIF v_active_allocations >= v_active_beds AND v_active_beds > 0 THEN
        v_room_status := 'OCCUPIED';
    ELSIF v_active_allocations > 0 THEN
        v_room_status := 'AVAILABLE'; -- Partially available
    ELSE
        v_room_status := 'AVAILABLE';
    END IF;

    UPDATE public.hostel_rooms
    SET target_capacity = GREATEST(v_active_beds, target_capacity),
        current_occupancy = v_active_allocations,
        operational_status = v_room_status,
        updated_at = NOW()
    WHERE id = p_room_id;
END;
$$;


-- B. KPI Card Aggregations (Top 6 KPI Cards in Screenshot)
CREATE OR REPLACE FUNCTION public.fn_hostel_get_kpis(
    p_school_id UUID,
    p_academic_year VARCHAR DEFAULT '2024 - 2025'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_buildings INT := 0;
    v_total_floors INT := 0;
    v_total_rooms INT := 0;
    v_residential_rooms INT := 0;
    v_total_beds INT := 0;
    v_available_beds INT := 0;
    v_occupied_beds INT := 0;
    v_reserved_beds INT := 0;
    v_maintenance_rooms INT := 0;
    v_occupied_rooms INT := 0;
    v_available_rooms INT := 0;
    v_equipment_faults INT := 0;
    v_occupancy_pct NUMERIC(5,1) := 0.0;
    v_available_pct NUMERIC(5,1) := 0.0;
BEGIN
    -- Buildings count
    SELECT COUNT(*) INTO v_total_buildings
    FROM public.hostel_buildings
    WHERE school_id = p_school_id AND deleted_at IS NULL;

    -- Floors count
    SELECT COUNT(*) INTO v_total_floors
    FROM public.hostel_floors
    WHERE school_id = p_school_id AND deleted_at IS NULL;

    -- Total rooms count
    SELECT COUNT(*) INTO v_total_rooms
    FROM public.hostel_rooms
    WHERE school_id = p_school_id AND deleted_at IS NULL;

    -- Residential rooms count
    SELECT COUNT(*) INTO v_residential_rooms
    FROM public.hostel_rooms
    WHERE school_id = p_school_id AND deleted_at IS NULL AND is_residential = TRUE;

    -- Maintenance rooms
    SELECT COUNT(*) INTO v_maintenance_rooms
    FROM public.hostel_rooms
    WHERE school_id = p_school_id AND deleted_at IS NULL AND operational_status = 'MAINTENANCE';

    -- Occupied & Available rooms
    SELECT COUNT(*) INTO v_occupied_rooms
    FROM public.hostel_rooms
    WHERE school_id = p_school_id AND deleted_at IS NULL AND is_residential = TRUE AND current_occupancy > 0;

    SELECT COUNT(*) INTO v_available_rooms
    FROM public.hostel_rooms
    WHERE school_id = p_school_id AND deleted_at IS NULL AND is_residential = TRUE AND operational_status = 'AVAILABLE' AND current_occupancy < target_capacity;

    -- Beds breakdown
    SELECT COUNT(*) INTO v_total_beds
    FROM public.hostel_beds
    WHERE school_id = p_school_id AND deleted_at IS NULL;

    SELECT COUNT(*) INTO v_occupied_beds
    FROM public.hostel_beds
    WHERE school_id = p_school_id AND deleted_at IS NULL AND status = 'OCCUPIED';

    SELECT COUNT(*) INTO v_available_beds
    FROM public.hostel_beds
    WHERE school_id = p_school_id AND deleted_at IS NULL AND status = 'AVAILABLE';

    SELECT COUNT(*) INTO v_reserved_beds
    FROM public.hostel_beds
    WHERE school_id = p_school_id AND deleted_at IS NULL AND status = 'RESERVED';

    -- Equipment faults
    SELECT COUNT(*) INTO v_equipment_faults
    FROM public.hostel_room_equipment
    WHERE school_id = p_school_id AND deleted_at IS NULL AND status IN ('FAULTY', 'UNDER_REPAIR', 'OUT_OF_SERVICE');

    -- Compute percentages
    IF (v_occupied_rooms + v_available_rooms) > 0 THEN
        v_occupancy_pct := ROUND((v_occupied_rooms::NUMERIC / (v_occupied_rooms + v_available_rooms)::NUMERIC) * 100.0, 1);
        v_available_pct := ROUND((v_available_rooms::NUMERIC / (v_occupied_rooms + v_available_rooms)::NUMERIC) * 100.0, 1);
    END IF;

    RETURN jsonb_build_object(
        'total_buildings', v_total_buildings,
        'total_floors', v_total_floors,
        'total_rooms', v_total_rooms,
        'residential_rooms', v_residential_rooms,
        'total_beds', v_total_beds,
        'available_beds', v_available_beds,
        'occupied_beds', v_occupied_beds,
        'reserved_beds', v_reserved_beds,
        'occupied_rooms', v_occupied_rooms,
        'available_rooms', v_available_rooms,
        'occupancy_percentage', v_occupancy_pct,
        'available_percentage', v_available_pct,
        'maintenance_rooms', v_maintenance_rooms,
        'equipment_faults', v_equipment_faults,
        'academic_year', p_academic_year
    );
END;
$$;


-- C. Structure Tree (Left Column Tree: Buildings -> Floors -> Rooms)
CREATE OR REPLACE FUNCTION public.fn_hostel_get_structure_tree(
    p_school_id UUID,
    p_search VARCHAR DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB := '[]'::JSONB;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', b.id,
                'name', b.name,
                'code', b.code,
                'hostel_name', b.hostel_name,
                'gender_policy', b.gender_policy,
                'floors_count', b.total_floors,
                'status', b.operational_status,
                'floors', (
                    SELECT COALESCE(
                        jsonb_agg(
                            jsonb_build_object(
                                'id', f.id,
                                'floor_number', f.floor_number,
                                'floor_code', f.floor_code,
                                'floor_name', f.floor_name,
                                'wing', f.wing,
                                'status', f.operational_status,
                                'rooms_count', (
                                    SELECT COUNT(*) 
                                    FROM public.hostel_rooms r 
                                    WHERE r.floor_id = f.id AND r.deleted_at IS NULL
                                ),
                                'rooms', (
                                    SELECT COALESCE(
                                        jsonb_agg(
                                            jsonb_build_object(
                                                'id', r.id,
                                                'room_number', r.room_number,
                                                'room_code', r.room_code,
                                                'room_type', r.room_type,
                                                'is_residential', r.is_residential,
                                                'status', r.operational_status,
                                                'capacity', r.target_capacity,
                                                'occupied', r.current_occupancy
                                            ) ORDER BY r.room_number ASC
                                        ),
                                        '[]'::JSONB
                                    )
                                    FROM public.hostel_rooms r
                                    WHERE r.floor_id = f.id 
                                      AND r.deleted_at IS NULL
                                      AND (p_search = '' OR r.room_number ILIKE '%' || p_search || '%' OR r.room_type ILIKE '%' || p_search || '%')
                                )
                            ) ORDER BY f.floor_number ASC
                        ),
                        '[]'::JSONB
                    )
                    FROM public.hostel_floors f
                    WHERE f.building_id = b.id AND f.deleted_at IS NULL
                )
            ) ORDER BY b.name ASC
        ),
        '[]'::JSONB
    ) INTO v_result
    FROM public.hostel_buildings b
    WHERE b.school_id = p_school_id 
      AND b.deleted_at IS NULL
      AND (
          p_search = '' 
          OR b.name ILIKE '%' || p_search || '%' 
          OR b.code ILIKE '%' || p_search || '%'
          OR EXISTS (
              SELECT 1 FROM public.hostel_rooms r 
              WHERE r.building_id = b.id AND r.deleted_at IS NULL AND (r.room_number ILIKE '%' || p_search || '%' OR r.room_type ILIKE '%' || p_search || '%')
          )
      );

    RETURN v_result;
END;
$$;


-- D. Paginated Rooms List (Center Column Grid/Table matching screenshot)
CREATE OR REPLACE FUNCTION public.fn_hostel_get_rooms(
    p_school_id UUID,
    p_search VARCHAR DEFAULT '',
    p_building_id UUID DEFAULT NULL,
    p_floor_id UUID DEFAULT NULL,
    p_room_type VARCHAR DEFAULT 'ALL',
    p_status VARCHAR DEFAULT 'ALL',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'room_number',
    p_sort_order VARCHAR DEFAULT 'ASC'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT := (GREATEST(p_page, 1) - 1) * p_page_size;
    v_total_records INT := 0;
    v_rooms JSONB := '[]'::JSONB;
    v_selected_context TEXT := 'All Rooms';
BEGIN
    -- Determine header context text e.g. "1st Floor, Boys Hostel A"
    IF p_floor_id IS NOT NULL THEN
        SELECT (f.floor_name || ', ' || b.name) INTO v_selected_context
        FROM public.hostel_floors f
        JOIN public.hostel_buildings b ON f.building_id = b.id
        WHERE f.id = p_floor_id;
    ELSIF p_building_id IS NOT NULL THEN
        SELECT b.name INTO v_selected_context
        FROM public.hostel_buildings b
        WHERE b.id = p_building_id;
    END IF;

    -- Count total records matching filter
    SELECT COUNT(*) INTO v_total_records
    FROM public.hostel_rooms r
    JOIN public.hostel_buildings b ON r.building_id = b.id
    JOIN public.hostel_floors f ON r.floor_id = f.id
    WHERE r.school_id = p_school_id
      AND r.deleted_at IS NULL
      AND (p_building_id IS NULL OR r.building_id = p_building_id)
      AND (p_floor_id IS NULL OR r.floor_id = p_floor_id)
      AND (
          p_search = '' 
          OR r.room_number ILIKE '%' || p_search || '%'
          OR r.room_code ILIKE '%' || p_search || '%'
          OR r.room_type ILIKE '%' || p_search || '%'
          OR b.name ILIKE '%' || p_search || '%'
          OR f.floor_name ILIKE '%' || p_search || '%'
      )
      AND (p_room_type = 'ALL' OR p_room_type = '' OR UPPER(TRIM(r.room_type)) = UPPER(TRIM(p_room_type)))
      AND (p_status = 'ALL' OR p_status = '' OR UPPER(TRIM(r.operational_status)) = UPPER(TRIM(p_status)));

    -- Fetch paginated items with enriched facilities, counts, and badges
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', r.id,
                'building_id', r.building_id,
                'building_name', b.name,
                'floor_id', r.floor_id,
                'floor_name', f.floor_name,
                'room_number', r.room_number,
                'room_code', r.room_code,
                'room_name', r.room_name,
                'room_type', r.room_type,
                'is_residential', r.is_residential,
                'capacity', CASE WHEN r.is_residential THEN r.target_capacity ELSE NULL END,
                'occupied', CASE WHEN r.is_residential THEN r.current_occupancy ELSE NULL END,
                'capacity_label', CASE WHEN r.is_residential THEN r.target_capacity::TEXT ELSE '-' END,
                'occupied_label', CASE WHEN r.is_residential THEN r.current_occupancy::TEXT ELSE '-' END,
                'status', r.operational_status,
                'cleanliness_status', r.cleanliness_status,
                'condition_status', r.condition_status,
                'room_size_sqm', r.room_size_sqm,
                'monthly_fee', r.monthly_fee,
                'gender_restriction', r.gender_restriction,
                'photos_count', jsonb_array_length(r.photos),
                'photos', r.photos,
                'facilities_summary', (
                    SELECT COALESCE(
                        jsonb_agg(
                            jsonb_build_object(
                                'name', eq.equipment_name,
                                'status', eq.status,
                                'quantity', eq.quantity
                            )
                        ),
                        '[]'::JSONB
                    )
                    FROM public.hostel_room_equipment eq
                    WHERE eq.room_id = r.id AND eq.deleted_at IS NULL
                )
            )
            ORDER BY 
                CASE WHEN LOWER(p_sort_by) = 'room_number' AND LOWER(p_sort_order) = 'asc' THEN r.room_number END ASC,
                CASE WHEN LOWER(p_sort_by) = 'room_number' AND LOWER(p_sort_order) = 'desc' THEN r.room_number END DESC,
                CASE WHEN LOWER(p_sort_by) = 'room_type' AND LOWER(p_sort_order) = 'asc' THEN r.room_type END ASC,
                CASE WHEN LOWER(p_sort_by) = 'room_type' AND LOWER(p_sort_order) = 'desc' THEN r.room_type END DESC,
                CASE WHEN LOWER(p_sort_by) = 'status' AND LOWER(p_sort_order) = 'asc' THEN r.operational_status END ASC,
                CASE WHEN LOWER(p_sort_by) = 'status' AND LOWER(p_sort_order) = 'desc' THEN r.operational_status END DESC,
                r.room_number ASC
        ),
        '[]'::JSONB
    ) INTO v_rooms
    FROM (
        SELECT r_sub.* 
        FROM public.hostel_rooms r_sub
        JOIN public.hostel_buildings b_sub ON r_sub.building_id = b_sub.id
        JOIN public.hostel_floors f_sub ON r_sub.floor_id = f_sub.id
        WHERE r_sub.school_id = p_school_id
          AND r_sub.deleted_at IS NULL
          AND (p_building_id IS NULL OR r_sub.building_id = p_building_id)
          AND (p_floor_id IS NULL OR r_sub.floor_id = p_floor_id)
          AND (
              p_search = '' 
              OR r_sub.room_number ILIKE '%' || p_search || '%'
              OR r_sub.room_code ILIKE '%' || p_search || '%'
              OR r_sub.room_type ILIKE '%' || p_search || '%'
              OR b_sub.name ILIKE '%' || p_search || '%'
              OR f_sub.floor_name ILIKE '%' || p_search || '%'
          )
          AND (p_room_type = 'ALL' OR p_room_type = '' OR UPPER(TRIM(r_sub.room_type)) = UPPER(TRIM(p_room_type)))
          AND (p_status = 'ALL' OR p_status = '' OR UPPER(TRIM(r_sub.operational_status)) = UPPER(TRIM(p_status)))
        ORDER BY r_sub.room_number ASC
        LIMIT p_page_size OFFSET v_offset
    ) r
    JOIN public.hostel_buildings b ON r.building_id = b.id
    JOIN public.hostel_floors f ON r.floor_id = f.id;

    RETURN jsonb_build_object(
        'data', v_rooms,
        'context_title', v_selected_context,
        'pagination', jsonb_build_object(
            'total_records', v_total_records,
            'page', p_page,
            'page_size', p_page_size,
            'total_pages', CEIL(v_total_records::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)
        )
    );
END;
$$;


-- E. Room Detail Inspector (Right Column Details matching screenshot)
CREATE OR REPLACE FUNCTION public.fn_hostel_get_room_detail(
    p_school_id UUID,
    p_room_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_room RECORD;
    v_beds JSONB := '[]'::JSONB;
    v_facilities JSONB := '[]'::JSONB;
    v_students JSONB := '[]'::JSONB;
    v_maintenance JSONB := '[]'::JSONB;
    v_history JSONB := '[]'::JSONB;
BEGIN
    SELECT 
        r.*, 
        b.name AS building_name,
        b.hostel_name,
        f.floor_name
    INTO v_room
    FROM public.hostel_rooms r
    JOIN public.hostel_buildings b ON r.building_id = b.id
    JOIN public.hostel_floors f ON r.floor_id = f.id
    WHERE r.id = p_room_id AND r.school_id = p_school_id AND r.deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Room not found');
    END IF;

    -- Fetch Beds
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', bd.id,
                'bed_code', bd.bed_code,
                'bed_type', bd.bed_type,
                'condition', bd.condition,
                'status', bd.status,
                'monthly_fee', bd.monthly_fee,
                'occupant', (
                    SELECT jsonb_build_object(
                        'student_id', p.id,
                        'full_name', p.full_name,
                        'email', p.email,
                        'avatar_url', p.avatar_url,
                        'check_in_date', a.check_in_date,
                        'allocation_id', a.id
                    )
                    FROM public.hostel_allocations a
                    JOIN public.profiles p ON a.student_id = p.id
                    WHERE a.bed_id = bd.id 
                      AND a.deleted_at IS NULL 
                      AND a.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED')
                    LIMIT 1
                )
            ) ORDER BY bd.bed_code ASC
        ),
        '[]'::JSONB
    ) INTO v_beds
    FROM public.hostel_beds bd
    WHERE bd.room_id = p_room_id AND bd.deleted_at IS NULL;

    -- Fetch Facilities / Equipment
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', eq.id,
                'name', eq.equipment_name,
                'category', eq.equipment_category,
                'quantity', eq.quantity,
                'status', eq.status,
                'is_critical', eq.is_critical,
                'notes', eq.notes
            ) ORDER BY eq.equipment_name ASC
        ),
        '[]'::JSONB
    ) INTO v_facilities
    FROM public.hostel_room_equipment eq
    WHERE eq.room_id = p_room_id AND eq.deleted_at IS NULL;

    -- Fetch Allocated Students
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'allocation_id', a.id,
                'student_id', p.id,
                'full_name', p.full_name,
                'email', p.email,
                'avatar_url', p.avatar_url,
                'roll_number', COALESCE(p.phone, 'STU-001'),
                'bed_code', COALESCE(bd.bed_code, 'Unassigned'),
                'status', a.allocation_status,
                'check_in_date', a.check_in_date,
                'fee_status', a.fee_status,
                'monthly_fee', a.monthly_fee
            ) ORDER BY a.check_in_date DESC
        ),
        '[]'::JSONB
    ) INTO v_students
    FROM public.hostel_allocations a
    JOIN public.profiles p ON a.student_id = p.id
    LEFT JOIN public.hostel_beds bd ON a.bed_id = bd.id
    WHERE a.room_id = p_room_id 
      AND a.deleted_at IS NULL 
      AND a.allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED');

    -- Fetch Maintenance Tickets
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', mt.id,
                'ticket_number', mt.ticket_number,
                'title', mt.title,
                'priority', mt.priority,
                'status', mt.status,
                'blocks_allocation', mt.blocks_allocation,
                'created_at', mt.created_at,
                'sla_due_date', mt.sla_due_date
            ) ORDER BY mt.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_maintenance
    FROM public.hostel_maintenance_tickets mt
    WHERE mt.room_id = p_room_id AND mt.deleted_at IS NULL;

    -- Fetch History / Events
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', ev.id,
                'event_type', ev.event_type,
                'student_name', p.full_name,
                'reason', ev.reason,
                'created_at', ev.created_at,
                'performed_by', pr.full_name
            ) ORDER BY ev.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_history
    FROM public.hostel_allocation_events ev
    JOIN public.profiles p ON ev.student_id = p.id
    LEFT JOIN public.profiles pr ON ev.performed_by = pr.id
    WHERE (ev.room_id = p_room_id OR ev.from_room_id = p_room_id OR ev.to_room_id = p_room_id)
    LIMIT 20;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'id', v_room.id,
            'room_number', v_room.room_number,
            'room_code', v_room.room_code,
            'room_name', v_room.room_name,
            'building_id', v_room.building_id,
            'building_name', v_room.building_name,
            'hostel_name', v_room.hostel_name,
            'floor_id', v_room.floor_id,
            'floor_name', v_room.floor_name,
            'room_type', v_room.room_type,
            'is_residential', v_room.is_residential,
            'capacity', v_room.target_capacity,
            'current_occupancy', v_room.current_occupancy,
            'room_size_sqm', v_room.room_size_sqm,
            'monthly_fee', v_room.monthly_fee,
            'status', v_room.operational_status,
            'cleanliness_status', v_room.cleanliness_status,
            'condition_status', v_room.condition_status,
            'gender_restriction', v_room.gender_restriction,
            'photos', v_room.photos,
            'amenities', v_room.amenities,
            'beds', v_beds,
            'facilities', v_facilities,
            'students', v_students,
            'maintenance', v_maintenance,
            'history', v_history
        )
    );
END;
$$;


-- F. Structure Creation & Mutation Functions
CREATE OR REPLACE FUNCTION public.fn_hostel_create_or_update_building(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID;
    v_code VARCHAR(50);
    v_name VARCHAR(150);
    v_hostel_name VARCHAR(150);
    v_gender VARCHAR(20);
    v_total_floors INT;
    v_description TEXT;
    v_status VARCHAR(30);
    v_record RECORD;
BEGIN
    v_id := (p_data->>'id')::UUID;
    v_code := TRIM(p_data->>'code');
    v_name := TRIM(p_data->>'name');
    v_hostel_name := COALESCE(TRIM(p_data->>'hostel_name'), v_name);
    v_gender := COALESCE(p_data->>'gender_policy', 'BOYS');
    v_total_floors := COALESCE((p_data->>'total_floors')::INT, 1);
    v_description := p_data->>'description';
    v_status := COALESCE(p_data->>'operational_status', 'OPERATIONAL');

    IF v_code IS NULL OR v_code = '' OR v_name IS NULL OR v_name = '' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Building code and name are required');
    END IF;

    IF v_id IS NOT NULL THEN
        UPDATE public.hostel_buildings
        SET code = v_code,
            name = v_name,
            hostel_name = v_hostel_name,
            gender_policy = v_gender,
            total_floors = v_total_floors,
            description = v_description,
            operational_status = v_status,
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = v_id AND school_id = p_school_id AND deleted_at IS NULL
        RETURNING * INTO v_record;
    ELSE
        INSERT INTO public.hostel_buildings (
            school_id, code, name, hostel_name, gender_policy, total_floors,
            description, operational_status, created_by, updated_by
        ) VALUES (
            p_school_id, v_code, v_name, v_hostel_name, v_gender, v_total_floors,
            v_description, v_status, p_user_id, p_user_id
        )
        RETURNING * INTO v_record;
    END IF;

    RETURN jsonb_build_object('success', true, 'data', to_jsonb(v_record));
END;
$$;


CREATE OR REPLACE FUNCTION public.fn_hostel_create_or_update_floor(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID;
    v_building_id UUID;
    v_floor_number INT;
    v_floor_code VARCHAR(50);
    v_floor_name VARCHAR(100);
    v_wing VARCHAR(50);
    v_status VARCHAR(30);
    v_record RECORD;
BEGIN
    v_id := (p_data->>'id')::UUID;
    v_building_id := (p_data->>'building_id')::UUID;
    v_floor_number := (p_data->>'floor_number')::INT;
    v_floor_code := TRIM(p_data->>'floor_code');
    v_floor_name := TRIM(p_data->>'floor_name');
    v_wing := p_data->>'wing';
    v_status := COALESCE(p_data->>'operational_status', p_data->>'status', 'OPERATIONAL');

    IF v_building_id IS NULL OR v_floor_number IS NULL OR v_floor_code IS NULL OR v_floor_name IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Building, floor number, code, and name are required');
    END IF;

    -- Normalize status
    IF UPPER(v_status) IN ('ACTIVE', 'AVAILABLE', 'OPERATIONAL') THEN
        v_status := 'OPERATIONAL';
    ELSIF UPPER(v_status) IN ('MAINTENANCE', 'UNDER REPAIR', 'UNDER_MAINTENANCE') THEN
        v_status := 'MAINTENANCE';
    ELSIF UPPER(v_status) IN ('INACTIVE', 'CLOSED') THEN
        v_status := 'CLOSED';
    END IF;

    -- Check for duplicate floor number in the same building
    IF EXISTS (
        SELECT 1 FROM public.hostel_floors 
        WHERE building_id = v_building_id 
          AND floor_number = v_floor_number 
          AND (v_id IS NULL OR id != v_id)
          AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Floor number ' || v_floor_number || ' already exists in this hostel building.'
        );
    END IF;

    -- Check for duplicate floor code in the same building
    IF EXISTS (
        SELECT 1 FROM public.hostel_floors 
        WHERE building_id = v_building_id 
          AND UPPER(floor_code) = UPPER(v_floor_code)
          AND (v_id IS NULL OR id != v_id)
          AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object(
            'success', false, 
            'message', 'Floor code "' || v_floor_code || '" already exists in this hostel building.'
        );
    END IF;

    IF v_id IS NOT NULL THEN
        UPDATE public.hostel_floors
        SET floor_number = v_floor_number,
            floor_code = v_floor_code,
            floor_name = v_floor_name,
            wing = v_wing,
            operational_status = v_status,
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = v_id AND school_id = p_school_id AND deleted_at IS NULL
        RETURNING * INTO v_record;
    ELSE
        INSERT INTO public.hostel_floors (
            school_id, building_id, floor_number, floor_code, floor_name, wing,
            operational_status, created_by, updated_by
        ) VALUES (
            p_school_id, v_building_id, v_floor_number, v_floor_code, v_floor_name, v_wing,
            v_status, p_user_id, p_user_id
        )
        RETURNING * INTO v_record;
    END IF;

    -- Keep building total_floors updated
    UPDATE public.hostel_buildings
    SET total_floors = (
        SELECT COUNT(*) FROM public.hostel_floors 
        WHERE building_id = v_building_id AND deleted_at IS NULL
    ),
    updated_at = NOW()
    WHERE id = v_building_id;

    RETURN jsonb_build_object('success', true, 'data', to_jsonb(v_record));
EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object(
        'success', false, 
        'message', 'A floor with number ' || v_floor_number || ' or code "' || v_floor_code || '" already exists in this building.'
    );
WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;


CREATE OR REPLACE FUNCTION public.fn_hostel_create_or_update_room(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID;
    v_building_id UUID;
    v_floor_id UUID;
    v_room_number VARCHAR(50);
    v_room_code VARCHAR(100);
    v_room_name VARCHAR(150);
    v_room_type VARCHAR(100);
    v_is_residential BOOLEAN;
    v_capacity INT;
    v_size NUMERIC(8,2);
    v_fee NUMERIC(10,2);
    v_gender VARCHAR(20);
    v_status VARCHAR(30);
    v_photos JSONB;
    v_amenities JSONB;
    v_record RECORD;
BEGIN
    v_id := (p_data->>'id')::UUID;
    v_building_id := (p_data->>'building_id')::UUID;
    v_floor_id := (p_data->>'floor_id')::UUID;
    v_room_number := TRIM(p_data->>'room_number');
    v_room_type := COALESCE(TRIM(p_data->>'room_type'), 'Standard');
    v_is_residential := COALESCE((p_data->>'is_residential')::BOOLEAN, 
                                 CASE WHEN v_room_type IN ('Toilet/Washroom', 'Pantry', 'Laundry', 'Storage', 'Electrical Room', 'Pump Room') THEN FALSE ELSE TRUE END);
    v_capacity := COALESCE((p_data->>'capacity')::INT, CASE WHEN v_is_residential THEN 3 ELSE 0 END);
    v_size := COALESCE((p_data->>'room_size_sqm')::NUMERIC, 18.0);
    v_fee := COALESCE((p_data->>'monthly_fee')::NUMERIC, 6000.0);
    v_gender := COALESCE(p_data->>'gender_restriction', 'BOYS');
    v_status := COALESCE(p_data->>'operational_status', 'AVAILABLE');
    v_photos := COALESCE(p_data->'photos', '[]'::JSONB);
    v_amenities := COALESCE(p_data->'amenities', '[]'::JSONB);
    v_room_code := COALESCE(TRIM(p_data->>'room_code'), v_room_number);

    IF v_building_id IS NULL OR v_floor_id IS NULL OR v_room_number IS NULL OR v_room_number = '' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Building, floor, and room number are required');
    END IF;

    IF v_id IS NOT NULL THEN
        UPDATE public.hostel_rooms
        SET room_number = v_room_number,
            room_code = v_room_code,
            room_type = v_room_type,
            is_residential = v_is_residential,
            target_capacity = v_capacity,
            room_size_sqm = v_size,
            monthly_fee = v_fee,
            gender_restriction = v_gender,
            operational_status = v_status,
            photos = v_photos,
            amenities = v_amenities,
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = v_id AND school_id = p_school_id AND deleted_at IS NULL
        RETURNING * INTO v_record;
    ELSE
        INSERT INTO public.hostel_rooms (
            school_id, building_id, floor_id, room_number, room_code, room_type,
            is_residential, target_capacity, room_size_sqm, monthly_fee, gender_restriction,
            operational_status, photos, amenities, created_by, updated_by
        ) VALUES (
            p_school_id, v_building_id, v_floor_id, v_room_number, v_room_code, v_room_type,
            v_is_residential, v_capacity, v_size, v_fee, v_gender,
            v_status, v_photos, v_amenities, p_user_id, p_user_id
        )
        RETURNING * INTO v_record;
    END IF;

    PERFORM public.fn_hostel_recalculate_room(v_record.id);

    RETURN jsonb_build_object('success', true, 'data', to_jsonb(v_record));
END;
$$;


-- G. Allocation Action: Assign Student to Room & Bed
CREATE OR REPLACE FUNCTION public.fn_hostel_assign_student(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student_id UUID;
    v_room_id UUID;
    v_bed_id UUID;
    v_academic_year VARCHAR(50);
    v_room RECORD;
    v_bed RECORD;
    v_student RECORD;
    v_existing_alloc RECORD;
    v_alloc_id UUID;
    v_monthly_fee NUMERIC(10,2);
    v_deposit NUMERIC(10,2);
BEGIN
    v_student_id := (p_data->>'student_id')::UUID;
    v_room_id := (p_data->>'room_id')::UUID;
    v_bed_id := (p_data->>'bed_id')::UUID;
    v_academic_year := COALESCE(TRIM(p_data->>'academic_year'), '2024 - 2025');

    IF v_student_id IS NULL OR v_room_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Student ID and Room ID are required');
    END IF;

    -- Verify student exists
    SELECT * INTO v_student FROM public.profiles WHERE id = v_student_id AND school_id = p_school_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Student profile not found');
    END IF;

    -- Check if student already has active allocation in this academic year
    SELECT * INTO v_existing_alloc
    FROM public.hostel_allocations
    WHERE school_id = p_school_id 
      AND student_id = v_student_id 
      AND academic_year = v_academic_year 
      AND deleted_at IS NULL 
      AND allocation_status IN ('RESERVED', 'CONFIRMED', 'CHECKED_IN', 'TEMPORARILY_RELOCATED');

    IF FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Student already has an active allocation for this session');
    END IF;

    -- Verify room
    SELECT * INTO v_room FROM public.hostel_rooms WHERE id = v_room_id AND school_id = p_school_id AND deleted_at IS NULL;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Room not found');
    END IF;

    IF NOT v_room.is_residential THEN
        RETURN jsonb_build_object('success', false, 'message', 'Cannot allocate students to non-residential spaces');
    END IF;

    -- Check bed if provided
    IF v_bed_id IS NOT NULL THEN
        SELECT * INTO v_bed FROM public.hostel_beds WHERE id = v_bed_id AND room_id = v_room_id AND deleted_at IS NULL;
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'message', 'Selected bed does not exist in this room');
        END IF;

        IF v_bed.status = 'OCCUPIED' THEN
            RETURN jsonb_build_object('success', false, 'message', 'Bed is already occupied');
        END IF;

        IF v_bed.status IN ('BLOCKED', 'MAINTENANCE', 'OUT_OF_SERVICE', 'RETIRED') THEN
            RETURN jsonb_build_object('success', false, 'message', 'Bed is currently not available for allocation');
        END IF;
    ELSE
        -- Auto-select first available bed in room if exists
        SELECT * INTO v_bed 
        FROM public.hostel_beds 
        WHERE room_id = v_room_id AND status = 'AVAILABLE' AND deleted_at IS NULL 
        ORDER BY bed_code ASC 
        LIMIT 1;
        
        IF FOUND THEN
            v_bed_id := v_bed.id;
        END IF;
    END IF;

    v_monthly_fee := COALESCE((p_data->>'monthly_fee')::NUMERIC, v_room.monthly_fee);
    v_deposit := COALESCE((p_data->>'deposit_amount')::NUMERIC, 10000.0);

    -- Create allocation record
    INSERT INTO public.hostel_allocations (
        school_id, student_id, academic_year, building_id, floor_id, room_id, bed_id,
        allocation_status, check_in_date, monthly_fee, deposit_amount, fee_status,
        allocation_reason, requested_by, approved_by, approved_at, created_by, updated_by
    ) VALUES (
        p_school_id, v_student_id, v_academic_year, v_room.building_id, v_room.floor_id, v_room_id, v_bed_id,
        'CHECKED_IN', NOW(), v_monthly_fee, v_deposit, 'PAID',
        p_data->>'allocation_reason', p_user_id, p_user_id, NOW(), p_user_id, p_user_id
    ) RETURNING id INTO v_alloc_id;

    -- Update bed status to OCCUPIED
    IF v_bed_id IS NOT NULL THEN
        UPDATE public.hostel_beds
        SET status = 'OCCUPIED', updated_by = p_user_id, updated_at = NOW()
        WHERE id = v_bed_id;
    END IF;

    -- Record Audit Event
    INSERT INTO public.hostel_allocation_events (
        school_id, allocation_id, student_id, room_id, bed_id, event_type,
        to_room_id, to_bed_id, reason, performed_by
    ) VALUES (
        p_school_id, v_alloc_id, v_student_id, v_room_id, v_bed_id, 'CHECKED_IN',
        v_room_id, v_bed_id, 'Initial Student Assignment', p_user_id
    );

    -- Recalculate room occupancy
    PERFORM public.fn_hostel_recalculate_room(v_room_id);

    RETURN jsonb_build_object(
        'success', true, 
        'message', 'Student allocated successfully',
        'allocation_id', v_alloc_id
    );
END;
$$;


-- H. Allocation Action: Check-Out Student
CREATE OR REPLACE FUNCTION public.fn_hostel_check_out(
    p_school_id UUID,
    p_user_id UUID,
    p_allocation_id UUID,
    p_reason TEXT DEFAULT 'Regular Check-Out'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_alloc RECORD;
BEGIN
    SELECT * INTO v_alloc 
    FROM public.hostel_allocations 
    WHERE id = p_allocation_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Allocation not found');
    END IF;

    IF v_alloc.allocation_status = 'CHECKED_OUT' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Student is already checked out');
    END IF;

    -- Update allocation record
    UPDATE public.hostel_allocations
    SET allocation_status = 'CHECKED_OUT',
        actual_check_out_date = NOW(),
        updated_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_allocation_id;

    -- Release bed
    IF v_alloc.bed_id IS NOT NULL THEN
        UPDATE public.hostel_beds
        SET status = 'AVAILABLE', updated_by = p_user_id, updated_at = NOW()
        WHERE id = v_alloc.bed_id;
    END IF;

    -- Record audit event
    INSERT INTO public.hostel_allocation_events (
        school_id, allocation_id, student_id, room_id, bed_id, event_type,
        from_room_id, from_bed_id, reason, performed_by
    ) VALUES (
        p_school_id, p_allocation_id, v_alloc.student_id, v_alloc.room_id, v_alloc.bed_id, 'CHECKED_OUT',
        v_alloc.room_id, v_alloc.bed_id, p_reason, p_user_id
    );

    -- Recalculate room occupancy
    PERFORM public.fn_hostel_recalculate_room(v_alloc.room_id);

    RETURN jsonb_build_object('success', true, 'message', 'Check-out completed successfully');
END;
$$;


-- I. Filter Options for Dropdowns
CREATE OR REPLACE FUNCTION public.fn_hostel_get_filter_options(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN jsonb_build_object(
        'hostels', (
            SELECT COALESCE(
                jsonb_agg(
                    jsonb_build_object('id', b.id, 'name', b.name, 'code', b.code)
                    ORDER BY b.name ASC
                ),
                '[]'::JSONB
            )
            FROM public.hostel_buildings b
            WHERE b.school_id = p_school_id AND b.deleted_at IS NULL
        ),
        'floors', (
            SELECT COALESCE(
                jsonb_agg(
                    jsonb_build_object('id', f.id, 'building_id', f.building_id, 'name', f.floor_name, 'number', f.floor_number)
                    ORDER BY f.floor_number ASC
                ),
                '[]'::JSONB
            )
            FROM public.hostel_floors f
            WHERE f.school_id = p_school_id AND f.deleted_at IS NULL
        ),
        'room_types', jsonb_build_array(
            'Standard', 'Deluxe', 'Dormitory', 'Study Room', 'Toilet/Washroom', 'Pantry', 'Laundry', 'Common Room'
        ),
        'statuses', jsonb_build_array(
            'AVAILABLE', 'OCCUPIED', 'MAINTENANCE', 'OPERATIONAL'
        )
    );
END;
$$;
