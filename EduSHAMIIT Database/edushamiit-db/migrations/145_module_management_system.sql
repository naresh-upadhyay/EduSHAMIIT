-- Migration 145: Module Management System
-- EduSHAMIIT — Shami Innovation and Technologies LLP

-- 1. Create modules table
CREATE TABLE IF NOT EXISTS modules (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    icon TEXT,
    screens JSONB NOT NULL DEFAULT '[]'::jsonb,
    endpoints JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Populate core modules
INSERT INTO modules (id, name, description, icon, screens, endpoints, is_enabled) VALUES
('fee_management', 'Fee Management', 'Manage student fees, tuition ledgers, invoices and payroll.', 'payment', '["/admin/finance", "/admin/defaulters", "/student/fees", "/teacher/salary"]', '["/api/fees", "/api/payments", "/api/salary"]', true),
('bus_tracking', 'Bus Tracking', 'Real-time GPS tracking of school buses and route mapping.', 'directions_bus', '["/admin/infra", "/student/transport"]', '["/api/bus-routes", "/api/bus-locations", "/api/bus-stops"]', true),
('library_catalog', 'Library Catalog', 'Digital library registry, book cataloging and issuance tracking.', 'local_library', '["/student/library"]', '["/api/library-books", "/api/library-borrows"]', true),
('hostel_mgmt', 'Hostel Management', 'Hostel warden control, room allocation and boarding logs.', 'hotel', '[]', '[]', true),
('exam_system', 'Exam System', 'Online quiz engine, proctored examinations and gradebook.', 'assignment', '["/student/exams", "/student/online-exam", "/teacher/exams", "/teacher/gradebook"]', '["/api/exams", "/api/exam-questions", "/api/exam-submissions", "/api/exam-sessions"]', true),
('live_classes', 'Live Classes', 'Real-time interactive video lecturing and recording playback.', 'video_call', '["/student/live-classes", "/teacher/live-classes", "/teacher/live-session", "/live-room"]', '["/api/live-classes", "/api/livekit"]', true),
('chat_messaging', 'Chat/Messaging', 'Direct peer-to-peer and group messaging channels.', 'chat', '["/student/messaging", "/teacher/messaging"]', '["/api/messages"]', true),
('sports_club', 'Sports Club', 'Manage athletic events, tournament matches and records.', 'sports_soccer', '[]', '[]', true),
('staff_payroll', 'Staff Payroll', 'Generate salary slips and track teaching staff directories.', 'badge', '["/admin/staff"]', '["/api/staff", "/api/salary"]', true),
('biometric_gate', 'Biometric Gate', 'Smart IoT biometric attendance devices and check-in scanner.', 'fingerprint', '["/admin/gate-scanner"]', '["/api/iot-devices", "/api/iot-device-states"]', true),
('parent_app_portal', 'Parent App Portal', 'Parent access, child performance overview and reports.', 'family_restroom', '[]', '[]', true),
('sms_gateway', 'SMS Gateway', 'Configurable Twilio and SMTP gateways for notifications.', 'sms', '["/admin/apis"]', '["/api/notifications"]', true)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    screens = EXCLUDED.screens,
    endpoints = EXCLUDED.endpoints;

-- 3. Add module_toggles column to schools table
ALTER TABLE schools ADD COLUMN IF NOT EXISTS module_toggles JSONB;

-- 4. Initialize default module toggles for existing schools if null
UPDATE schools 
SET module_toggles = '{"fee_management": true, "bus_tracking": true, "library_catalog": true, "hostel_mgmt": true, "exam_system": true, "live_classes": true, "chat_messaging": true, "sports_club": true, "staff_payroll": true, "biometric_gate": true, "parent_app_portal": true, "sms_gateway": true}'::jsonb 
WHERE module_toggles IS NULL;
