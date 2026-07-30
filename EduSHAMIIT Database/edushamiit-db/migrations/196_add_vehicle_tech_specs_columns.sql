-- Migration 196: Add Technical & Vehicle Specs Columns to bus_routes
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS luggage_capacity VARCHAR(100) DEFAULT '500 L';
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS fuel_tank_capacity VARCHAR(100) DEFAULT '150 Liters';
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS transmission VARCHAR(50) DEFAULT 'Manual';
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS odometer_km INTEGER DEFAULT 45280;
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS speed_governor VARCHAR(100) DEFAULT 'Fitted (Max 60 km/h)';
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS cctv_installed VARCHAR(100) DEFAULT '4 HD Cameras (Active)';
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS panic_button VARCHAR(100) DEFAULT 'Installed & Working';
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS first_aid_expiry DATE;
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS fire_extinguisher_expiry DATE;
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS last_serviced_date DATE;
ALTER TABLE bus_routes ADD COLUMN IF NOT EXISTS ownership_type VARCHAR(100) DEFAULT 'School Owned';
