-- Sample Schools
INSERT INTO schools (id, name, address, phone) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Shami Innovation Academy', '123 Education Street, Delhi', '+91-11-12345678'),
  ('22222222-2222-2222-2222-222222222222', 'EduSHAMIIT International School', '456 Knowledge Ave, Mumbai', '+91-22-98765432')
ON CONFLICT (id) DO NOTHING;