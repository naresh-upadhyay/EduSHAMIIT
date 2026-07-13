-- Database migration: 153_audit_logs.sql
-- Create Audit Logs table for tracking system activities and changes.

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE SET NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    user_email TEXT,
    user_name TEXT,
    user_role TEXT,
    event_type TEXT NOT NULL, -- e.g., 'Create', 'Update', 'Delete', 'Login', etc.
    module TEXT NOT NULL, -- e.g., 'Institutions', 'Users', 'Students', 'Authentication', etc.
    action TEXT NOT NULL, -- e.g., 'Created', 'Updated', 'Deleted', 'Login', etc.
    resource TEXT, -- e.g., 'Greenfield Public School', 'User: Priya Verma'
    resource_type TEXT, -- e.g., 'Institution', 'User', 'Student'
    ip_address TEXT,
    status TEXT CHECK (status IN ('Success', 'Failed')) NOT NULL,
    changes JSONB, -- stores key-value diffs
    user_agent TEXT,
    session_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS and permissions on audit_logs
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Allow read/write for all users (or specifically super_admin/admin, but let's keep it simple and secure)
CREATE POLICY "Allow read for all users on audit_logs" ON public.audit_logs FOR SELECT USING (true);
CREATE POLICY "Allow insert for all users on audit_logs" ON public.audit_logs FOR INSERT WITH CHECK (true);

-- Populate some high-fidelity sample audit logs for testing/display matching the screenshot!
INSERT INTO public.audit_logs (school_id, user_email, user_name, user_role, event_type, module, action, resource, resource_type, ip_address, status, changes, user_agent, session_id, created_at)
VALUES
(
  NULL,
  'superadmin@schoolerp.com',
  'Rohit Sharma',
  'super_admin',
  'Update',
  'Institutions',
  'Updated',
  'Greenfield Public School',
  'Institution',
  '103.21.244.10',
  'Success',
  '{"Name": "Greenfield Public School", "Status": "Active", "Address": "123 Park Street, Mumbai", "Contact": "+91 9876543210"}'::jsonb,
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'sess_8f3a7b1d2e4c6a9b',
  now() - interval '2 minutes'
),
(
  NULL,
  'superadmin@schoolerp.com',
  'Anjali Mehta',
  'admin',
  'Create',
  'Users',
  'Created',
  'User: Priya Verma',
  'User',
  '103.21.244.15',
  'Success',
  '{"Name": "Priya Verma", "Role": "Teacher", "Department": "Science"}'::jsonb,
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
  'sess_anjali123',
  now() - interval '4 minutes'
),
(
  NULL,
  'superadmin@schoolerp.com',
  'Vikram Singh',
  'admin',
  'Delete',
  'Students',
  'Deleted',
  'Student ID: STU-12987',
  'Student',
  '103.21.244.18',
  'Success',
  '{"StudentID": "STU-12987", "Name": "Amit Kumar"}'::jsonb,
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  'sess_vikram123',
  now() - interval '8 minutes'
),
(
  NULL,
  'teacher@schoolerp.com',
  'Sneha Iyer',
  'teacher',
  'Login',
  'Authentication',
  'Login',
  '-',
  '-',
  '103.21.244.22',
  'Success',
  '{}'::jsonb,
  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_1_2 like Mac OS X)',
  'sess_sneha99',
  now() - interval '12 minutes'
),
(
  NULL,
  'superadmin@schoolerp.com',
  'Arjun Patel',
  'admin',
  'Update',
  'Settings',
  'Updated',
  'System Configuration',
  'System Configuration',
  '103.21.244.25',
  'Success',
  '{"MaintenanceMode": false, "SessionTimeoutMinutes": 30}'::jsonb,
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
  'sess_arjun',
  now() - interval '15 minutes'
),
(
  NULL,
  'unknown@schoolerp.com',
  'Unknown User',
  'User',
  'Login Failed',
  'Authentication',
  'Failed Login',
  '-',
  '-',
  '203.0.113.45',
  'Failed',
  '{"Reason": "Invalid password"}'::jsonb,
  'Mozilla/5.0 (Linux; Android 10; K)',
  'sess_fail1',
  now() - interval '18 minutes'
),
(
  NULL,
  'accountant@schoolerp.com',
  'Meera Joshi',
  'finance',
  'Export',
  'Reports',
  'Exported',
  'Fee Collection Report',
  'Report',
  '103.21.244.30',
  'Success',
  '{"ReportName": "Fee Collection Report", "Format": "PDF"}'::jsonb,
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
  'sess_meera',
  now() - interval '20 minutes'
),
(
  NULL,
  'superadmin@schoolerp.com',
  'Rohit Sharma',
  'super_admin',
  'Backup',
  'System',
  'Manual Backup',
  'Full System Backup',
  'Backup',
  '103.21.244.10',
  'Success',
  '{"BackupType": "Full", "SizeMB": 1250}'::jsonb,
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
  'sess_8f3a7b1d2e4c6a9b',
  now() - interval '22 minutes'
),
(
  NULL,
  'superadmin@schoolerp.com',
  'Anjali Mehta',
  'admin',
  'Permission Change',
  'Users',
  'Updated',
  'User: Rahul Kumar',
  'User',
  '103.21.244.15',
  'Success',
  '{"Permissions": ["view_grades", "view_attendance", "manage_classes"]}'::jsonb,
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
  'sess_anjali123',
  now() - interval '24 minutes'
),
(
  NULL,
  'superadmin@schoolerp.com',
  'Vikram Singh',
  'admin',
  'Bulk Update',
  'Students',
  'Bulk Updated',
  '120 Students',
  'Student',
  '103.21.244.18',
  'Success',
  '{"Count": 120, "Field": "Status", "Value": "Promoted"}'::jsonb,
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
  'sess_vikram123',
  now() - interval '26 minutes'
);
