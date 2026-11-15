-- ============================================================================
-- Migration: 453_enterprise_campus_safety_and_compliance.sql
-- Description: Production-Grade Safety, Security & Statutory Compliance Schema
--              for EduSHAMIIT Campus Management.
--              Includes Inspections, Incident Logs, Compliance Certificates,
--              Emergency Drills, and Safety Checklists.
-- ============================================================================

-- 1. Safety Inspections Table
CREATE TABLE IF NOT EXISTS public.safety_inspections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    inspection_code VARCHAR(50) NOT NULL, -- e.g. 'SI-2026-089'
    title VARCHAR(255) NOT NULL, -- e.g. 'Quarterly Fire Safety & Extinguisher Audit'
    category VARCHAR(60) NOT NULL DEFAULT 'Fire Safety', 
    -- 'Fire Safety', 'Electrical Safety', 'Lab & Chemical Safety', 'Structural Integrity', 
    -- 'Sanitation & Hygiene', 'CCTV & Physical Security', 'Sports & Playground', 'Food & Water Safety'
    
    building_id UUID REFERENCES public.buildings(id) ON DELETE SET NULL,
    floor_id UUID REFERENCES public.building_floors(id) ON DELETE SET NULL,
    room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL,
    location_display VARCHAR(150) NOT NULL, -- e.g. 'Academic Block / All Floors'

    inspector_name VARCHAR(150) NOT NULL, -- e.g. 'Capt. Rajesh Varma'
    inspector_role VARCHAR(80) NOT NULL DEFAULT 'Safety Officer', -- Safety Officer, External Auditor, Fire Marshal, Facilities Manager
    inspector_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    
    inspection_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status VARCHAR(40) NOT NULL DEFAULT 'Passed', -- 'Passed', 'Needs Attention', 'Critical Action', 'In Progress', 'Scheduled'
    compliance_score NUMERIC(5, 2) DEFAULT 95.0, -- e.g. 96.5%
    
    findings TEXT,
    action_items JSONB NOT NULL DEFAULT '[]'::JSONB,
    attachments JSONB NOT NULL DEFAULT '[]'::JSONB,
    next_inspection_date DATE,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_safety_inspections_school_code 
    ON public.safety_inspections(school_id, inspection_code);

CREATE INDEX IF NOT EXISTS idx_safety_inspections_category 
    ON public.safety_inspections(school_id, category, status) 
    WHERE deleted_at IS NULL;


-- 2. Safety & Security Incidents Table
CREATE TABLE IF NOT EXISTS public.safety_incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    incident_code VARCHAR(50) NOT NULL, -- e.g. 'INC-2026-014'
    title VARCHAR(255) NOT NULL, -- e.g. 'Chemical Fume Leak in Chemistry Lab 103'
    severity VARCHAR(30) NOT NULL DEFAULT 'Medium', -- 'Low', 'Medium', 'High', 'Critical'
    incident_type VARCHAR(60) NOT NULL DEFAULT 'Lab Incident',
    -- 'Slip, Trip & Fall', 'Minor Injury', 'Fire Alarm Trigger', 'Chemical / Hazard Spill', 
    -- 'Equipment Damage', 'Unauthorized Access', 'Medical Emergency', 'Electrical Spark', 'Other'

    building_id UUID REFERENCES public.buildings(id) ON DELETE SET NULL,
    floor_id UUID REFERENCES public.building_floors(id) ON DELETE SET NULL,
    room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL,
    location_display VARCHAR(150) NOT NULL, -- e.g. 'Science Block / F1-103'

    reported_by_name VARCHAR(150) NOT NULL, -- e.g. 'Dr. Anita Roy'
    reported_by_role VARCHAR(80) NOT NULL DEFAULT 'Faculty',
    reported_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    incident_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    status VARCHAR(40) NOT NULL DEFAULT 'Reported', -- 'Reported', 'Under Investigation', 'Action Taken', 'Resolved', 'Closed'
    description TEXT,
    immediate_action_taken TEXT,
    preventive_measures TEXT,
    victims_count INT NOT NULL DEFAULT 0,
    first_aid_provided BOOLEAN NOT NULL DEFAULT FALSE,
    attachments JSONB NOT NULL DEFAULT '[]'::JSONB,

    resolved_at TIMESTAMPTZ,
    resolved_by_name VARCHAR(150),
    resolved_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_safety_incidents_school_code 
    ON public.safety_incidents(school_id, incident_code);

CREATE INDEX IF NOT EXISTS idx_safety_incidents_severity 
    ON public.safety_incidents(school_id, severity, status) 
    WHERE deleted_at IS NULL;


-- 3. Statutory Compliance Certificates Table
CREATE TABLE IF NOT EXISTS public.compliance_certificates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    certificate_code VARCHAR(50) NOT NULL, -- e.g. 'CERT-FIRE-2026'
    title VARCHAR(255) NOT NULL, -- e.g. 'Fire Safety No Objection Certificate (Fire NOC)'
    category VARCHAR(60) NOT NULL DEFAULT 'Fire Safety',
    -- 'Fire Safety', 'Building Stability', 'Sanitation & Hygiene', 'Water Quality', 'Elevator & Lift Fitness', 'Pollution / Environmental NOC', 'Electrical Safety'
    
    issuing_authority VARCHAR(200) NOT NULL, -- e.g. 'State Fire & Emergency Services Dept'
    certificate_number VARCHAR(100) NOT NULL, -- e.g. 'NOC/FS/2026/89412'
    building_id UUID REFERENCES public.buildings(id) ON DELETE SET NULL,
    location_display VARCHAR(150) NOT NULL DEFAULT 'All Campus Buildings',

    issue_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'Valid', -- 'Valid', 'Expiring Soon', 'Expired', 'Renewal Pending'
    document_url TEXT,
    notes TEXT,

    reminder_days_before INT NOT NULL DEFAULT 30,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_compliance_certificates_school_code 
    ON public.compliance_certificates(school_id, certificate_code);

CREATE INDEX IF NOT EXISTS idx_compliance_certificates_status 
    ON public.compliance_certificates(school_id, status, expiry_date) 
    WHERE deleted_at IS NULL;


-- 4. Emergency Evacuation & Safety Drills Table
CREATE TABLE IF NOT EXISTS public.safety_drills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    drill_code VARCHAR(50) NOT NULL, -- e.g. 'DRL-2026-03'
    title VARCHAR(255) NOT NULL, -- e.g. 'Semi-Annual Campus Fire Evacuation Drill'
    drill_type VARCHAR(60) NOT NULL DEFAULT 'Fire Evacuation',
    -- 'Fire Evacuation', 'Earthquake Safety', 'Medical Emergency', 'Active Threat / Lockdown', 'Chemical Spill Protocol'

    building_id UUID REFERENCES public.buildings(id) ON DELETE SET NULL,
    location_display VARCHAR(150) NOT NULL DEFAULT 'Whole Campus (All Blocks)',

    scheduled_date DATE NOT NULL,
    conducted_date DATE,
    status VARCHAR(30) NOT NULL DEFAULT 'Scheduled', -- 'Scheduled', 'Completed', 'Cancelled', 'Rescheduled'
    
    participants_count INT NOT NULL DEFAULT 0,
    evacuation_time_seconds INT DEFAULT 0,
    target_time_seconds INT NOT NULL DEFAULT 180, -- Target: 3 minutes (180s)
    
    coordinator_name VARCHAR(150) NOT NULL, -- e.g. 'Major Vikramaditya (Retd)'
    coordinator_role VARCHAR(80) NOT NULL DEFAULT 'Chief Safety Officer',
    performance_rating VARCHAR(40) DEFAULT 'Good', -- 'Excellent', 'Good', 'Satisfactory', 'Needs Improvement'
    observations TEXT,
    action_items JSONB NOT NULL DEFAULT '[]'::JSONB,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    deleted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_safety_drills_school_code 
    ON public.safety_drills(school_id, drill_code);
