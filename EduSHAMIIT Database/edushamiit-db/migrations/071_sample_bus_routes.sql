-- Sample Bus Routes
INSERT INTO bus_routes (id, school_id, route_name, bus_number, driver_name, driver_phone, total_capacity, current_passengers, status) VALUES
  ('71000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Route A - North Delhi', 'DL-01-AB-1234', 'Rajesh Kumar', '+91-9876543001', 40, 25, 'active'),
  ('71000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Route B - South Delhi', 'DL-01-CD-5678', 'Suresh Singh', '+91-9876543002', 40, 20, 'active'),
  ('71000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'Route C - East Delhi', 'DL-01-EF-9012', 'Mahesh Yadav', '+91-9876543003', 35, 15, 'active'),
  ('71000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'Route D - West Delhi', 'DL-01-GH-3456', 'Ramesh Chand', '+91-9876543004', 40, 30, 'active')
ON CONFLICT (id) DO NOTHING;