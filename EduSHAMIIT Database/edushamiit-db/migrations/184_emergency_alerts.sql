-- Migration: 184_emergency_alerts.sql
-- Description: Create emergency alerts and emergency contacts tables for Emergency module

CREATE TABLE IF NOT EXISTS emergency_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    role_name TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    is_primary BOOLEAN DEFAULT false,
    icon_type TEXT DEFAULT 'admin',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS emergency_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    user_name TEXT,
    user_role TEXT,
    user_phone TEXT,
    alert_type TEXT NOT NULL DEFAULT 'SOS',
    title TEXT NOT NULL,
    description TEXT,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    status TEXT NOT NULL DEFAULT 'Active',
    severity TEXT NOT NULL DEFAULT 'Critical',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolved_by UUID
);

-- Seed initial default emergency contacts if none exist
INSERT INTO emergency_contacts (title, role_name, phone_number, is_primary, icon_type)
VALUES
    ('AC School Admin', 'School Admin', '+91 98765 43210', true, 'admin'),
    ('Transport Manager', 'Fleet Manager', '+91 91234 56789', false, 'transport'),
    ('Control Room', '24x7 Support', '+91 11223 34455', false, 'control'),
    ('School Principal', 'Principal', '+91 99887 66554', false, 'principal')
ON CONFLICT DO NOTHING;

-- Seed initial sample emergency alerts history
INSERT INTO emergency_alerts (title, alert_type, description, address, latitude, longitude, status, severity, created_at)
VALUES
    ('Traffic Incident at Sector 71', 'Traffic Incident', 'Minor collision on route near Sector 71 crossing', 'Sector 71 Crossing, Noida, UP 201301', 28.5700, 77.3700, 'Resolved', 'High', NOW() - INTERVAL '10 days'),
    ('Vehicle Breakdown - Bus UP16 ET 5678', 'Vehicle Breakdown', 'Engine overheating warning, bus stopped at community center', 'Sector 62 Community Center, Noida, UP 201301', 28.6200, 77.3600, 'Resolved', 'Warning', NOW() - INTERVAL '13 days'),
    ('Medical Emergency - Student Fever', 'Medical Emergency', 'Student feeling dizzy, medical assistance requested', 'Sector 63 Bus Stop, Noida, UP 201301', 28.5863, 77.3572, 'Cancelled', 'Info', NOW() - INTERVAL '16 days');
