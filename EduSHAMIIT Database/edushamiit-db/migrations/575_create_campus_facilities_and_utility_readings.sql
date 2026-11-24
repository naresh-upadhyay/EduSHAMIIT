-- ============================================================================
-- Migration: 575_create_campus_facilities_and_utility_readings.sql
-- Description:
--   1. Create public.campus_facilities table for physical campus facilities
--      (sports complexes, specialized labs, auditoriums, cafeterias, etc.)
--   2. Create public.campus_utility_readings table for utility meters & telemetry
--   3. Grant full permissions to anon, authenticated, service_role
--   4. Seed initial realistic facilities and utility readings for schools
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Campus Facilities Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.campus_facilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    campus_id UUID REFERENCES public.campuses(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(100) NOT NULL,
    category VARCHAR(100) NOT NULL DEFAULT 'Specialized Laboratory',
    building_id UUID REFERENCES public.buildings(id) ON DELETE SET NULL,
    floor_id UUID REFERENCES public.building_floors(id) ON DELETE SET NULL,
    capacity INT DEFAULT 50,
    area NUMERIC(12, 2) DEFAULT 0.0,
    manager_name VARCHAR(150),
    manager_phone VARCHAR(50),
    manager_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'Operational',
    equipment_count INT DEFAULT 0,
    description TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_campus_facilities_school_code 
    ON public.campus_facilities (school_id, UPPER(code)) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_campus_facilities_school_status 
    ON public.campus_facilities (school_id, status) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_campus_facilities_school_building 
    ON public.campus_facilities (school_id, building_id) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_campus_facilities_school_floor 
    ON public.campus_facilities (school_id, floor_id) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_campus_facilities_school_category 
    ON public.campus_facilities (school_id, category) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_campus_facilities_school_created 
    ON public.campus_facilities (school_id, created_at DESC) 
    WHERE deleted_at IS NULL;


-- ----------------------------------------------------------------------------
-- 2. Campus Utility Readings Table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.campus_utility_readings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    utility_name VARCHAR(150) NOT NULL,
    utility_type VARCHAR(100) NOT NULL,
    reading_value VARCHAR(100) NOT NULL,
    metric_units VARCHAR(50) DEFAULT 'kWh',
    location VARCHAR(255) NOT NULL,
    recorded_by VARCHAR(150) NOT NULL,
    recorded_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status VARCHAR(50) NOT NULL DEFAULT 'Normal',
    notes TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_campus_utility_readings_school_type 
    ON public.campus_utility_readings (school_id, utility_type) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_campus_utility_readings_school_recorded 
    ON public.campus_utility_readings (school_id, recorded_at DESC) 
    WHERE deleted_at IS NULL;


-- ----------------------------------------------------------------------------
-- 3. Grants & Permissions
-- ----------------------------------------------------------------------------
GRANT ALL ON public.campus_facilities TO anon, authenticated, service_role;
GRANT ALL ON public.campus_utility_readings TO anon, authenticated, service_role;


-- ----------------------------------------------------------------------------
-- 4. Seed Realistic Initial Facilities and Utility Readings
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    r_school RECORD;
    v_bldg_b1 UUID;
    v_flr_b1 UUID;
    v_bldg_b3 UUID;
    v_flr_b3 UUID;
    v_bldg_b4 UUID;
    v_flr_b4 UUID;
    v_bldg_b6 UUID;
    v_flr_b6 UUID;
    v_bldg_b7 UUID;
    v_flr_b7 UUID;
BEGIN
    FOR r_school IN SELECT id FROM public.schools LOOP
        -- Locate buildings if available
        SELECT id INTO v_bldg_b1 FROM public.buildings WHERE school_id = r_school.id AND (code = 'B1' OR name ILIKE '%Academic Block (A)%') LIMIT 1;
        IF v_bldg_b1 IS NOT NULL THEN
            SELECT id INTO v_flr_b1 FROM public.building_floors WHERE building_id = v_bldg_b1 LIMIT 1;
        ELSE
            v_flr_b1 := NULL;
        END IF;

        SELECT id INTO v_bldg_b3 FROM public.buildings WHERE school_id = r_school.id AND (code = 'B3' OR name ILIKE '%Library%') LIMIT 1;
        IF v_bldg_b3 IS NOT NULL THEN
            SELECT id INTO v_flr_b3 FROM public.building_floors WHERE building_id = v_bldg_b3 LIMIT 1;
        ELSE
            v_flr_b3 := NULL;
        END IF;

        SELECT id INTO v_bldg_b4 FROM public.buildings WHERE school_id = r_school.id AND (code = 'B4' OR name ILIKE '%Auditorium%') LIMIT 1;
        IF v_bldg_b4 IS NOT NULL THEN
            SELECT id INTO v_flr_b4 FROM public.building_floors WHERE building_id = v_bldg_b4 LIMIT 1;
        ELSE
            v_flr_b4 := NULL;
        END IF;

        SELECT id INTO v_bldg_b6 FROM public.buildings WHERE school_id = r_school.id AND (code = 'B6' OR name ILIKE '%Sports%') LIMIT 1;
        IF v_bldg_b6 IS NOT NULL THEN
            SELECT id INTO v_flr_b6 FROM public.building_floors WHERE building_id = v_bldg_b6 LIMIT 1;
        ELSE
            v_flr_b6 := NULL;
        END IF;

        SELECT id INTO v_bldg_b7 FROM public.buildings WHERE school_id = r_school.id AND (code = 'B7' OR name ILIKE '%Laboratories%') LIMIT 1;
        IF v_bldg_b7 IS NOT NULL THEN
            SELECT id INTO v_flr_b7 FROM public.building_floors WHERE building_id = v_bldg_b7 LIMIT 1;
        ELSE
            v_flr_b7 := NULL;
        END IF;

        -- Insert Facilities
        INSERT INTO public.campus_facilities (
            school_id, name, code, category, building_id, floor_id,
            capacity, area, manager_name, manager_phone, status, description, equipment_count
        ) VALUES
        (r_school.id, 'Central Advanced Physics & AI Lab', 'FAC-LAB-01', 'Specialized Laboratory', v_bldg_b7, v_flr_b7, 60, 2400.0, 'Dr. Robert Oppen', '+91 98765 43210', 'Operational', 'High performance quantum and robotics lab', 45),
        (r_school.id, 'Olympic Standard Swimming & Athletics Arena', 'FAC-SPT-01', 'Sports Complex / Ground', v_bldg_b6, v_flr_b6, 300, 15000.0, 'Coach Marcus Vance', '+91 98765 43211', 'Operational', 'Heated Olympic 50m pool and all-weather sprint track', 12),
        (r_school.id, 'Main Grand Auditorium & Performing Arts Theatre', 'FAC-AUD-01', 'Auditorium & Amphitheater', v_bldg_b4, v_flr_b4, 850, 8500.0, 'Sarah Jenkins', '+91 98765 43212', 'Operational', 'Acoustically tuned hall with 4K projection and Dolby Atmos', 28),
        (r_school.id, 'Central Digital Learning Commons & Archive', 'FAC-LIB-01', 'Library & Learning Commons', v_bldg_b3, v_flr_b3, 200, 6000.0, 'Evelyn Reed', '+91 98765 43213', 'Operational', 'Collaborative study spaces with high-speed digital catalogue', 80),
        (r_school.id, 'Multi-Cuisine Student Cafeteria & Nutrition Hub', 'FAC-CAF-01', 'Dining & Cafeteria Hub', v_bldg_b1, v_flr_b1, 400, 7200.0, 'Chef Anthony Russo', '+91 98765 43214', 'Operational', 'HACCP certified hygienic dining hall serving fresh meals', 34),
        (r_school.id, 'Campus Emergency Health Center & Clinic', 'FAC-MED-01', 'Health Center & Clinic', v_bldg_b1, v_flr_b1, 25, 1200.0, 'Dr. Claire Adams', '+91 98765 43215', 'Operational', '24/7 First-aid emergency triage center with resident nurse', 18),
        (r_school.id, 'Robotics & Rapid Prototyping Workshop', 'FAC-ROB-01', 'Robotics & Fabrication Lab', v_bldg_b7, v_flr_b7, 45, 1800.0, 'Vikram Malhotra', '+91 98765 43216', 'Operational', 'Equipped with CNC mills, 3D printers and laser cutters', 52)
        ON CONFLICT (school_id, UPPER(code)) WHERE deleted_at IS NULL DO NOTHING;

        -- Insert Sample Utility Readings
        INSERT INTO public.campus_utility_readings (
            school_id, utility_name, utility_type, reading_value, metric_units, location, recorded_by, status, notes
        ) VALUES
        (r_school.id, 'Main Substation Grid Meter', 'Electricity', '245 kW', 'kWh', 'Substation A - North Gate', 'Rajesh Sharma', 'Normal', 'Peak load within expected thresholds'),
        (r_school.id, 'Rooftop Solar PV Array', 'Solar', '84 kWp', 'kWh', 'Academic Block A & B Roof', 'Rajesh Sharma', 'Normal', 'Generation performing at 98% efficiency'),
        (r_school.id, 'Primary Standby Generator Set 1', 'Diesel / Generator', '78% (1,560 L)', '%', 'Powerhouse - Yard', 'Suresh Kumar', 'Normal', 'Fuel level inspected and verified'),
        (r_school.id, 'Overhead Water Reservoir Tank', 'Water', '85,000 L', 'L', 'Central Utility Tower', 'Mahesh Patil', 'Normal', 'Water level at optimal operating capacity'),
        (r_school.id, 'Campus High-Speed Optical Fiber Ring', 'Network', '99.98% (1.0 Gbps)', 'Gbps', 'Central Server Room B5', 'IT Admin Team', 'Normal', 'Both uplink carriers online with zero jitter')
        ON CONFLICT DO NOTHING;
    END LOOP;
END $$;
