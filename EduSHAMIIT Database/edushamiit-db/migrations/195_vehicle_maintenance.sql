-- Migration 195: Vehicle Maintenance Logs
CREATE TABLE IF NOT EXISTS vehicle_maintenance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES bus_routes(id) ON DELETE CASCADE,
    service_type VARCHAR(255) NOT NULL,
    vendor_workshop VARCHAR(255),
    service_date DATE NOT NULL DEFAULT CURRENT_DATE,
    completion_date DATE,
    cost DECIMAL(12,2) DEFAULT 0.00,
    odometer_km INTEGER DEFAULT 0,
    status VARCHAR(50) DEFAULT 'Completed',
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookup by vehicle_id and school_id
CREATE INDEX IF NOT EXISTS idx_vehicle_maintenance_vehicle_id ON vehicle_maintenance(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_maintenance_school_id ON vehicle_maintenance(school_id);

-- Enable RLS
ALTER TABLE vehicle_maintenance ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read on vehicle_maintenance" ON vehicle_maintenance FOR SELECT USING (true);
CREATE POLICY "Allow public insert on vehicle_maintenance" ON vehicle_maintenance FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update on vehicle_maintenance" ON vehicle_maintenance FOR UPDATE USING (true);
CREATE POLICY "Allow public delete on vehicle_maintenance" ON vehicle_maintenance FOR DELETE USING (true);

-- Sample Data for vehicle_maintenance
INSERT INTO vehicle_maintenance (school_id, vehicle_id, service_type, vendor_workshop, service_date, cost, odometer_km, status, description)
SELECT 
    b.school_id,
    b.id,
    'Routine Oil & Filter Change',
    'Tata Motors Authorized Service Center',
    CURRENT_DATE - INTERVAL '30 days',
    12400.00,
    42100,
    'Completed',
    'Replaced engine oil, oil filter, air filter, and top-up fluids.'
FROM bus_routes b
LIMIT 5
ON CONFLICT DO NOTHING;

INSERT INTO vehicle_maintenance (school_id, vehicle_id, service_type, vendor_workshop, service_date, cost, odometer_km, status, description)
SELECT 
    b.school_id,
    b.id,
    'Brake Pad Replacement & Alignment',
    'Bosch Auto Care Workshop',
    CURRENT_DATE - INTERVAL '90 days',
    18500.00,
    38400,
    'Completed',
    'Replaced front & rear brake pads, wheel alignment and balancing.'
FROM bus_routes b
LIMIT 5
ON CONFLICT DO NOTHING;

INSERT INTO vehicle_maintenance (school_id, vehicle_id, service_type, vendor_workshop, service_date, cost, odometer_km, status, description)
SELECT 
    b.school_id,
    b.id,
    'Full Engine Diagnostic & Tuning',
    'Tata Motors Authorized Workshop',
    CURRENT_DATE + INTERVAL '15 days',
    23220.00,
    45280,
    'Scheduled',
    'Scheduled comprehensive engine tune-up and AC servicing.'
FROM bus_routes b
LIMIT 5
ON CONFLICT DO NOTHING;
