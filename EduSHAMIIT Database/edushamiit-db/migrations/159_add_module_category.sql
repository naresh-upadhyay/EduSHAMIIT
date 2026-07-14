-- Add module metadata columns to support the redesigned Modules Management screen
ALTER TABLE modules ADD COLUMN IF NOT EXISTS category text DEFAULT 'Core';
ALTER TABLE modules ADD COLUMN IF NOT EXISTS type text DEFAULT 'Feature';
ALTER TABLE modules ADD COLUMN IF NOT EXISTS version text DEFAULT 'v1.0.0';
ALTER TABLE modules ADD COLUMN IF NOT EXISTS developed_by text DEFAULT 'School ERP Team';

-- Update existing modules with realistic, descriptive categories and metadata
UPDATE modules SET category = 'Finance', type = 'Feature', version = 'v2.0.1', developed_by = 'School ERP Team' WHERE id = 'fee_management';
UPDATE modules SET category = 'Transport', type = 'Feature', version = 'v1.3.4', developed_by = 'School ERP Team' WHERE id = 'bus_tracking';
UPDATE modules SET category = 'Resources', type = 'Feature', version = 'v2.1.0', developed_by = 'School ERP Team' WHERE id = 'library_catalog';
UPDATE modules SET category = 'Hostel', type = 'Feature', version = 'v1.0.2', developed_by = 'School ERP Team' WHERE id = 'hostel_mgmt';
UPDATE modules SET category = 'Academics', type = 'Feature', version = 'v2.4.1', developed_by = 'School ERP Team' WHERE id = 'exam_system';
