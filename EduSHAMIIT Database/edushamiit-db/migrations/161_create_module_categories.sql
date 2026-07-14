-- Migration 161: Create Module Categories table
-- EduSHAMIIT — Shami Innovation and Technologies LLP

CREATE TABLE IF NOT EXISTS module_categories (
    name TEXT PRIMARY KEY,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'Active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Seed default categories if they don't exist
INSERT INTO module_categories (name, description, status) VALUES
('Core', 'Core system administrative modules', 'Active'),
('Finance', 'Fee structures, invoices, payroll and accounts', 'Active'),
('Transport', 'Bus routes, vehicle tracking, transport fees', 'Active'),
('Resources', 'Library books cataloging and hostels booking', 'Active'),
('Academics', 'Exams scheduler, proctored examinations, and gradebook', 'Active'),
('Communication', 'Real-time chat, notice board, and SMS alerts', 'Active'),
('Others', 'Supplementary features and third party widgets', 'Active')
ON CONFLICT (name) DO NOTHING;
