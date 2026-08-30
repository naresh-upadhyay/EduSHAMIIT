-- SCHOOLS (multi-school support)
CREATE TABLE IF NOT EXISTS schools (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  logo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed primary institute for the application
INSERT INTO schools (id, name, address, phone, logo_url)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  'EduSHAMIIT International Institute',
  'Knowledge Park III, Greater Noida, Uttar Pradesh 201306',
  '+91 98765 43210',
  'https://images.unsplash.com/photo-1546410531-bb4caa6b424d?w=150'
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  address = EXCLUDED.address,
  phone = EXCLUDED.phone;
