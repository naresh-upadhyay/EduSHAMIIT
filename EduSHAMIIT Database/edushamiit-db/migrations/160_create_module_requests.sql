-- Create module requests table
CREATE TABLE IF NOT EXISTS module_requests (
    id text PRIMARY KEY,
    module_id text NOT NULL REFERENCES modules(id) ON DELETE CASCADE,
    school_id uuid NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    requested_by_name text NOT NULL,
    requested_by_email text NOT NULL,
    reason text,
    additional_notes text,
    required_for text,
    expected_users text,
    priority text DEFAULT 'Medium',
    status text DEFAULT 'Pending', -- Pending, Approved, Rejected
    created_at timestamp with time zone DEFAULT now()
);

-- Seed module requests
INSERT INTO module_requests (id, module_id, school_id, requested_by_name, requested_by_email, reason, additional_notes, required_for, expected_users, priority, status, created_at)
VALUES 
('MR-2026-0001', 'biometric_gate', 'e1f11111-1111-1111-1111-111111111111', 'Mr. Rajesh Sharma', 'principal@greenfield.edu.in', 'To automate student presence and generate exit alerts.', 'This module is needed for upcoming academic session implementation.', '2026 - 2027 Academic Year', '250+', 'Medium', 'Pending', now() - interval '1 day'),
('MR-2026-0002', 'sports_club', '11111111-1111-1111-1111-111111111111', 'Anita Verma', 'sports@shamiinnovation.edu.in', 'To manage regional athletic meet and enrollments.', 'Need urgent approval for sports meet tracking.', '2026 - 2027 Academic Year', '100+', 'High', 'Pending', now() - interval '2 days'),
('MR-2026-0003', 'library_catalog', '22222222-2222-2222-2222-222222222222', 'Sister Maria', 'librarian@edushamiit.edu.in', 'Upgrade physical cataloging processes to digital scans.', 'Library expansion plan completed.', '2026 - 2027 Academic Year', '500+', 'Low', 'Approved', now() - interval '3 days'),
('MR-2026-0004', 'hostel_mgmt', 'b6fb303e-b495-49d7-9c6e-79778db07dfb', 'Fr. Thomas', 'warden@yacu.edu.in', 'Hostel warden control and boarding logs.', 'Requested for new hostel block.', '2026 - 2027 Academic Year', '150+', 'Medium', 'Rejected', now() - interval '4 days'),
('MR-2026-0005', 'exam_system', '2983e734-cd05-4e78-8592-1ced0db3aad1', 'Vikram Singh', 'exam@king.edu.in', 'Online quiz engine, proctored examinations and gradebook.', 'Need for term examinations.', '2026 - 2027 Academic Year', '300+', 'High', 'Pending', now() - interval '5 days');
