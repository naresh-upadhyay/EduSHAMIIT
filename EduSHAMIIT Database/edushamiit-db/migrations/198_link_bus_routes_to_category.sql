-- Migration 198: Add category_id to bus_routes and link categories with strict matching

ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS category_id UUID REFERENCES vehicle_categories(id) ON DELETE SET NULL;

-- 1. Reset category_id
UPDATE bus_routes SET category_id = NULL;

-- 2. Link specific vehicle models/types to category IDs strictly
UPDATE bus_routes SET vehicle_type = 'Mini Bus (32 Seater)', category_id = 'c3333333-3333-3333-3333-333333333333' WHERE bus_number IN ('UP16 ET 9753', 'UP16 ET 8899');
UPDATE bus_routes SET vehicle_type = 'AC Bus (52 Seater)', category_id = 'c1111111-1111-1111-1111-111111111111' WHERE bus_number IN ('UP16 ET 1122', 'UP16 ET 7788', 'UP16 ET 2468');
UPDATE bus_routes SET vehicle_type = 'Non AC Bus (60 Seater)', category_id = 'c2222222-2222-2222-2222-222222222222' WHERE bus_number IN ('UP16 ET 3344');
UPDATE bus_routes SET vehicle_type = 'Tempo Traveller (17 Seater)', category_id = 'c4444444-4444-4444-4444-444444444444' WHERE bus_number IN ('UP16 ET 5678');
UPDATE bus_routes SET vehicle_type = 'Luxury Coach (45 Seater)', category_id = 'c6666666-6666-6666-6666-666666666666' WHERE bus_number IN ('UP16 ET 1234');

-- 3. Link any remaining vehicles matching exact category name or code
UPDATE bus_routes b
SET category_id = c.id
FROM vehicle_categories c
WHERE b.category_id IS NULL
  AND (b.vehicle_type = c.name OR b.vehicle_type = c.category_code);
