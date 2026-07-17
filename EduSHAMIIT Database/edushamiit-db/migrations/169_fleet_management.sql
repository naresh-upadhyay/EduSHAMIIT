-- Fleet Management Tables
-- Categories, Documents, Insurance, GPS Devices

-- 1. Vehicle Categories Table
CREATE TABLE IF NOT EXISTS vehicle_categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id   UUID REFERENCES schools(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  description TEXT,
  capacity    INT NOT NULL DEFAULT 52,
  fuel_type   TEXT DEFAULT 'Diesel',
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Vehicle Documents Table
CREATE TABLE IF NOT EXISTS vehicle_documents (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id       UUID REFERENCES schools(id) ON DELETE CASCADE,
  vehicle_id      UUID REFERENCES bus_routes(id) ON DELETE CASCADE,
  document_type   TEXT NOT NULL, -- 'Registration', 'Permit', 'Pollution Certificate', 'PUC Certificate', 'Fitness Certificate'
  document_no     TEXT NOT NULL,
  issued_date     DATE,
  expiry_date     DATE NOT NULL,
  status          TEXT NOT NULL DEFAULT 'Valid', -- 'Valid', 'Expired', 'Expiring Soon'
  document_url    TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Vehicle Insurance & Fitness Table
CREATE TABLE IF NOT EXISTS vehicle_insurance_fitness (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id              UUID REFERENCES schools(id) ON DELETE CASCADE,
  vehicle_id             UUID REFERENCES bus_routes(id) ON DELETE CASCADE,
  policy_no              TEXT,
  provider               TEXT,
  insurance_start        DATE,
  insurance_expiry       DATE,
  insurance_status       TEXT DEFAULT 'Valid',
  fitness_cert_no        TEXT,
  fitness_expiry         DATE,
  fitness_status         TEXT DEFAULT 'Valid',
  pollution_cert_no      TEXT,
  pollution_expiry       DATE,
  pollution_status       TEXT DEFAULT 'Valid',
  puc_no                 TEXT,
  permit_no              TEXT,
  permit_expiry          DATE,
  created_at             TIMESTAMPTZ DEFAULT NOW(),
  updated_at             TIMESTAMPTZ DEFAULT NOW()
);

-- 4. GPS Devices Table
CREATE TABLE IF NOT EXISTS gps_devices (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id         UUID REFERENCES schools(id) ON DELETE CASCADE,
  device_id         TEXT NOT NULL UNIQUE,
  model             TEXT,
  sim_no            TEXT,
  operator          TEXT,
  status            TEXT NOT NULL DEFAULT 'Active', -- 'Active', 'Inactive', 'Offline', 'Faulty'
  installation_date DATE,
  vehicle_id        UUID REFERENCES bus_routes(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_vehicle_cats_school        ON vehicle_categories(school_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_docs_vehicle       ON vehicle_documents(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_insurance_vehicle  ON vehicle_insurance_fitness(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_gps_devices_vehicle        ON gps_devices(vehicle_id);
CREATE INDEX IF NOT EXISTS idx_gps_devices_status         ON gps_devices(status);

-- Seed Sample Categories
INSERT INTO vehicle_categories (school_id, name, description, capacity, fuel_type)
SELECT 
  s.id,
  cat.name,
  cat.description,
  cat.capacity,
  cat.fuel_type
FROM schools s
CROSS JOIN (
  VALUES 
    ('AC Bus (52 Seats)', 'Luxury AC Bus with WiFi and CCTV', 52, 'Diesel'),
    ('AC Bus (32 Seats)', 'Medium size AC coach', 32, 'Diesel'),
    ('Non-AC Bus (60 Seats)', 'Standard transport bus', 60, 'Diesel'),
    ('Mini Bus (26 Seats)', 'Compact school shuttle', 26, 'Diesel'),
    ('Support Van', 'Staff & maintenance utility van', 8, 'Petrol')
) AS cat(name, description, capacity, fuel_type)
ON CONFLICT DO NOTHING;

-- Seed Sample Insurance and Fitness Records
INSERT INTO vehicle_insurance_fitness (school_id, vehicle_id, policy_no, provider, insurance_start, insurance_expiry, insurance_status, fitness_cert_no, fitness_expiry, fitness_status, pollution_cert_no, pollution_expiry, pollution_status, puc_no, permit_no, permit_expiry)
SELECT 
  r.school_id,
  r.id,
  'INS-' || lpad(floor(random()*999999)::text, 6, '0'),
  'HDFC Ergo General Insurance',
  CURRENT_DATE - INTERVAL '6 months',
  CURRENT_DATE + INTERVAL '6 months',
  'Valid',
  'FIT-' || lpad(floor(random()*999999)::text, 6, '0'),
  CURRENT_DATE + INTERVAL '8 months',
  'Valid',
  'POL-' || lpad(floor(random()*999999)::text, 6, '0'),
  CURRENT_DATE + INTERVAL '4 months',
  'Valid',
  'PUC-' || lpad(floor(random()*999999)::text, 6, '0'),
  'PER-' || lpad(floor(random()*999999)::text, 6, '0'),
  CURRENT_DATE + INTERVAL '12 months'
FROM bus_routes r
ON CONFLICT DO NOTHING;

-- Seed Sample Documents
INSERT INTO vehicle_documents (school_id, vehicle_id, document_type, document_no, expiry_date, status)
SELECT 
  r.school_id,
  r.id,
  doc.type,
  doc.no,
  CURRENT_DATE + doc.expiry_offset,
  'Valid'
FROM bus_routes r
CROSS JOIN (
  VALUES 
    ('Registration Certificate', 'REG-UP16-99218', INTERVAL '3 years'),
    ('National Permit', 'NP-3329-X', INTERVAL '1 year'),
    ('Pollution Under Control (PUC)', 'PUC-9921-A', INTERVAL '6 months'),
    ('Fitness Certificate', 'FIT-992-B', INTERVAL '10 months')
) AS doc(type, no, expiry_offset)
ON CONFLICT DO NOTHING;

-- Seed Sample GPS Devices
INSERT INTO gps_devices (school_id, device_id, model, sim_no, operator, status, installation_date, vehicle_id)
SELECT 
  r.school_id,
  'GPS-' || lpad(floor(random()*99999)::text, 5, '0'),
  'Teltonika FMB920',
  '+9198765' || lpad(floor(random()*99999)::text, 5, '0'),
  'Airtel IoT',
  'Active',
  CURRENT_DATE - INTERVAL '1 year',
  r.id
FROM bus_routes r
ON CONFLICT DO NOTHING;
