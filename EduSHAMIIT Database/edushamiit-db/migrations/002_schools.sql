-- SCHOOLS (multi-school support)
CREATE TABLE IF NOT EXISTS schools (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  logo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO schools (id, name, address, phone) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Shami Innovation Academy', 'Sector 62, Noida, Uttar Pradesh, India', '+91 98765 43210'),
  ('22222222-2222-2222-2222-222222222222', 'EduSHAMIIT International School', 'Civil Lines, Delhi, India', '+91 98765 43211')
ON CONFLICT (id) DO NOTHING;

