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

-- Seed module requests safely using existing schools
DO $$
DECLARE
    v_school_id uuid;
BEGIN
    SELECT id INTO v_school_id FROM schools LIMIT 1;
    
    IF v_school_id IS NOT NULL THEN
        INSERT INTO module_requests (id, module_id, school_id, requested_by_name, requested_by_email, reason, additional_notes, required_for, expected_users, priority, status, created_at)
        VALUES 
        ('MR-2026-0001', 'biometric_gate', v_school_id, 'Mr. Rajesh Sharma', 'principal@greenfield.edu.in', 'To automate student presence and generate exit alerts.', 'This module is needed for upcoming academic session implementation.', '2026 - 2027 Academic Year', '250+', 'Medium', 'Pending', now() - interval '1 day'),
        ('MR-2026-0002', 'sports_club', v_school_id, 'Anita Verma', 'sports@shamiinnovation.edu.in', 'To manage regional athletic meet and enrollments.', 'Need urgent approval for sports meet tracking.', '2026 - 2027 Academic Year', '100+', 'High', 'Pending', now() - interval '2 days'),
        ('MR-2026-0003', 'library_catalog', v_school_id, 'Sister Maria', 'librarian@edushamiit.edu.in', 'Upgrade physical cataloging processes to digital scans.', 'Library expansion plan completed.', '2026 - 2027 Academic Year', '500+', 'Low', 'Approved', now() - interval '3 days'),
        ('MR-2026-0004', 'hostel_mgmt', v_school_id, 'Fr. Thomas', 'warden@yacu.edu.in', 'Hostel warden control and boarding logs.', 'Requested for new hostel block.', '2026 - 2027 Academic Year', '150+', 'Medium', 'Rejected', now() - interval '4 days'),
        ('MR-2026-0005', 'exam_system', v_school_id, 'Vikram Singh', 'exam@king.edu.in', 'Online quiz engine, proctored examinations and gradebook.', 'Need for term examinations.', '2026 - 2027 Academic Year', '300+', 'High', 'Pending', now() - interval '5 days')
        ON CONFLICT (id) DO NOTHING;
    END IF;
END $$;
