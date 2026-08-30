-- Fleet Management Schema Enhancements to match designs

-- SET ROLE supabase_admin; -- commented out for cloud/container compatibility

-- Categories enhancements
ALTER TABLE vehicle_categories
  ADD COLUMN IF NOT EXISTS category_code      TEXT,
  ADD COLUMN IF NOT EXISTS transmission       TEXT DEFAULT 'Manual',
  ADD COLUMN IF NOT EXISTS luggage_capacity    TEXT DEFAULT '500 L',
  ADD COLUMN IF NOT EXISTS status             TEXT DEFAULT 'Active';

-- Documents enhancements
ALTER TABLE vehicle_documents
  ADD COLUMN IF NOT EXISTS uploaded_on        TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS uploaded_by        TEXT DEFAULT 'Transport Manager';

-- Insurance & Fitness enhancements
ALTER TABLE vehicle_insurance_fitness
  ADD COLUMN IF NOT EXISTS policy_type        TEXT DEFAULT 'Comprehensive',
  ADD COLUMN IF NOT EXISTS premium_amount     DECIMAL(10,2) DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS days_left          INT,
  ADD COLUMN IF NOT EXISTS issuing_authority  TEXT DEFAULT 'Regional Transport Office',
  ADD COLUMN IF NOT EXISTS certificate_copy_url TEXT;

-- GPS Devices enhancements
ALTER TABLE gps_devices
  ADD COLUMN IF NOT EXISTS imei_no            TEXT,
  ADD COLUMN IF NOT EXISTS battery_level      INT DEFAULT 100,
  ADD COLUMN IF NOT EXISTS signal_strength_pct INT DEFAULT 100,
  ADD COLUMN IF NOT EXISTS last_seen          TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS firmware_version    TEXT DEFAULT 'GTO6N_V7.2.1';

-- RESET ROLE;

-- Clear previous seeds to avoid duplicates, then seed high-fidelity mock data
DELETE FROM vehicle_documents;
DELETE FROM vehicle_insurance_fitness;
DELETE FROM gps_devices;
DELETE FROM vehicle_categories;

-- Seed categories matching the mockup
INSERT INTO vehicle_categories (id, name, category_code, description, capacity, fuel_type, transmission, luggage_capacity, status)
VALUES
  ('c1111111-1111-1111-1111-111111111111', 'AC Bus (52 Seater)', 'ACB-52', 'Air conditioned buses with 52 seating capacity. Used for long distance and comfort travel.', 52, 'Diesel', 'Manual', '500 L', 'Active'),
  ('c2222222-2222-2222-2222-222222222222', 'Non AC Bus (60 Seater)', 'NACB-60', 'Non Air Conditioned Bus with high capacity.', 60, 'Diesel', 'Manual', '600 L', 'Active'),
  ('c3333333-3333-3333-3333-333333333333', 'Mini Bus (32 Seater)', 'MIB-32', 'Compact mini bus for narrower city routes.', 32, 'Diesel', 'Manual', '300 L', 'Active'),
  ('c4444444-4444-4444-4444-444444444444', 'Tempo Traveller (17 Seater)', 'TT-17', 'Tempo Traveller for small batches & events.', 17, 'Diesel', 'Manual', '200 L', 'Active'),
  ('c5555555-5555-5555-5555-555555555555', 'Electric Bus (40 Seater)', 'EB-40', 'Eco-friendly zero emission electric bus.', 40, 'Electric', 'Automatic', '400 L', 'Active'),
  ('c6666666-6666-6666-6666-666666666666', 'Luxury Coach (45 Seater)', 'LC-45', 'Luxury Coach with reclining leather seats.', 45, 'Diesel', 'Automatic', '800 L', 'Inactive');

-- Seed insurance and fitness records matching mockup
INSERT INTO vehicle_insurance_fitness (
  id, vehicle_id, policy_no, provider, insurance_start, insurance_expiry, insurance_status,
  fitness_cert_no, fitness_expiry, fitness_status, pollution_cert_no, pollution_expiry, pollution_status,
  puc_no, permit_no, permit_expiry, policy_type, premium_amount, days_left, issuing_authority
)
SELECT
  gen_random_uuid(),
  r.id,
  'INS-' || lpad(floor(random()*999999)::text, 6, '0'),
  (ARRAY['SBI General Insurance', 'HDFC ERGO', 'ICICI Lombard', 'Bajaj Allianz'])[floor(random()*4)::int + 1],
  CURRENT_DATE - INTERVAL '6 months',
  CURRENT_DATE + (floor(random()*365)::int || ' days')::interval,
  'Valid',
  'FIT-' || lpad(floor(random()*999999)::text, 6, '0'),
  CURRENT_DATE + (floor(random()*365)::int || ' days')::interval,
  'Valid',
  'POL-' || lpad(floor(random()*999999)::text, 6, '0'),
  CURRENT_DATE + (floor(random()*365)::int || ' days')::interval,
  'Valid',
  'PUC-' || lpad(floor(random()*999999)::text, 6, '0'),
  'PER-' || lpad(floor(random()*999999)::text, 6, '0'),
  CURRENT_DATE + INTERVAL '12 months',
  (ARRAY['Comprehensive', 'Third Party', 'Standalone TP'])[floor(random()*3)::int + 1],
  round((random()*40000 + 10000)::numeric, 2),
  floor(random()*300 - 30)::int,
  'Regional Transport Office'
FROM bus_routes r;

-- Seed documents matching mockup
INSERT INTO vehicle_documents (id, vehicle_id, document_type, document_no, issued_date, expiry_date, status, uploaded_by)
SELECT
  gen_random_uuid(),
  r.id,
  doc.type,
  doc.no,
  CURRENT_DATE - INTERVAL '6 months',
  CURRENT_DATE + doc.expiry_offset,
  'Valid',
  'Transport Manager'
FROM bus_routes r
CROSS JOIN (
  VALUES
    ('Registration Certificate', 'RC-UP16-99218', INTERVAL '3 years'),
    ('Insurance Certificate', 'INS-7788-B', INTERVAL '8 months'),
    ('Pollution Under Control', 'PUC-9921-A', INTERVAL '5 months'),
    ('Fitness Certificate', 'FIT-992-B', INTERVAL '10 months'),
    ('Permit Certificate', 'PER-992-C', INTERVAL '11 months')
) AS doc(type, no, expiry_offset);

-- Seed GPS devices matching mockup
INSERT INTO gps_devices (id, device_id, imei_no, model, sim_no, operator, status, installation_date, battery_level, signal_strength_pct, last_seen, vehicle_id)
SELECT
  gen_random_uuid(),
  'GPSD-' || lpad(floor(random()*9999)::text, 4, '0'),
  '862345065432' || lpad(floor(random()*999)::text, 3, '0'),
  'GTO6N',
  '+91987654' || lpad(floor(random()*9999)::text, 4, '0'),
  (ARRAY['Jio', 'Airtel', 'Vi'])[floor(random()*3)::int + 1],
  (ARRAY['Active', 'Offline', 'Faulty'])[floor(random()*3)::int + 1],
  CURRENT_DATE - INTERVAL '1 year',
  floor(random()*40 + 60)::int,
  floor(random()*50 + 50)::int,
  NOW() - (random() * interval '2 hours'),
  r.id
FROM bus_routes r;
