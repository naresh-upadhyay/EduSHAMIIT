CREATE TABLE IF NOT EXISTS bus_routes (  
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),  
  school_id UUID REFERENCES schools(id),  
  route_name TEXT NOT NULL,  
  bus_number TEXT,  
  driver_name TEXT,  
  driver_phone TEXT,  
  total_capacity INT DEFAULT 40,  
  current_passengers INT DEFAULT 0,  
  status TEXT DEFAULT 'active'  
);

-- Seed core bus routes for primary institute
INSERT INTO bus_routes (id, school_id, route_name, bus_number, driver_name, driver_phone, total_capacity, status)
VALUES
  ('a1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'Route 101 (Morning Express)', 'UP16 ET 1234', 'Ramesh Kumar', '9876543210', 52, 'active'),
  ('a2222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Route 102 (Evening Loop)', 'UP16 ET 5678', 'Sandeep Singh', '9812345678', 52, 'active'),
  ('a3333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Route 105 (City Central)', 'UP16 ET 9101', 'Ajay Pal', '9654321098', 60, 'active'),
  ('a4444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'Route 108 (Campus Direct)', 'UP16 ET 1122', 'Mohd. Imran', '9712345671', 52, 'active')
ON CONFLICT (id) DO NOTHING; 
