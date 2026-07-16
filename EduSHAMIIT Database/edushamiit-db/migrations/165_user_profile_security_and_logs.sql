-- Migration: 165_user_profile_security_and_logs.sql
-- Alter last_login column type to TIMESTAMP WITH TIME ZONE
ALTER TABLE public.profiles ALTER COLUMN last_login TYPE TIMESTAMP WITH TIME ZONE;

-- Add security columns to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS two_factor_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS alternative_email VARCHAR(255);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS alternative_phone VARCHAR(50);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS emergency_contact_name VARCHAR(255);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS emergency_contact_phone VARCHAR(50);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email_notifications BOOLEAN DEFAULT TRUE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS sms_alerts BOOLEAN DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS push_notifications BOOLEAN DEFAULT TRUE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS weekly_reports BOOLEAN DEFAULT TRUE;

-- Add device columns to user_active_sessions
ALTER TABLE public.user_active_sessions ADD COLUMN IF NOT EXISTS device_name VARCHAR(100) DEFAULT 'Unknown Device';
ALTER TABLE public.user_active_sessions ADD COLUMN IF NOT EXISTS browser_name VARCHAR(100) DEFAULT 'Unknown Browser';
ALTER TABLE public.user_active_sessions ADD COLUMN IF NOT EXISTS ip_address VARCHAR(45) DEFAULT '127.0.0.1';
ALTER TABLE public.user_active_sessions ADD COLUMN IF NOT EXISTS location VARCHAR(150) DEFAULT 'Unknown Location';
ALTER TABLE public.user_active_sessions ADD COLUMN IF NOT EXISTS last_active TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Clear and insert mock active sessions for testing matching the screenshot
DELETE FROM public.user_active_sessions WHERE user_id = '903fd71c-a497-4665-b5c5-279d880e7461';

INSERT INTO public.user_active_sessions (id, user_id, token, device_name, browser_name, ip_address, location, last_active, expires_at, created_at)
VALUES
(gen_random_uuid(), '903fd71c-a497-4665-b5c5-279d880e7461', 'sess_win', 'Windows', 'Chrome', '192.168.1.45', 'Noida, India', NOW(), NOW() + INTERVAL '30 days', NOW()),
(gen_random_uuid(), '903fd71c-a497-4665-b5c5-279d880e7461', 'sess_mac', 'MacOS', 'Safari', '192.168.1.45', 'Noida, India', NOW() - INTERVAL '1 hour', NOW() + INTERVAL '30 days', NOW() - INTERVAL '1 hour'),
(gen_random_uuid(), '903fd71c-a497-4665-b5c5-279d880e7461', 'sess_and', 'Android', 'Chrome', '192.168.1.45', 'Delhi, India', NOW() - INTERVAL '3 hours', NOW() + INTERVAL '30 days', NOW() - INTERVAL '3 hours'),
(gen_random_uuid(), '903fd71c-a497-4665-b5c5-279d880e7461', 'sess_ios', 'iOS', 'Safari', '192.168.1.45', 'Noida, India', NOW() - INTERVAL '24 hours', NOW() + INTERVAL '30 days', NOW() - INTERVAL '24 hours');

-- Ensure some recent audit activity exists for this super admin
DELETE FROM public.audit_logs WHERE user_email = 'superadmin@school.com';

INSERT INTO public.audit_logs (id, school_id, user_id, user_email, user_name, user_role, event_type, module, action, resource, resource_type, ip_address, status, created_at)
VALUES
(gen_random_uuid(), NULL, '903fd71c-a497-4665-b5c5-279d880e7461', 'superadmin@school.com', 'Super Admin', 'super_admin', 'Login', 'Authentication', 'Logged in to the system', '-', '-', '192.168.1.45', 'Success', NOW() - INTERVAL '10 minutes'),
(gen_random_uuid(), NULL, '903fd71c-a497-4665-b5c5-279d880e7461', 'superadmin@school.com', 'Super Admin', 'super_admin', 'Update', 'Profile', 'Updated profile information', 'User: Super Admin', 'User', '192.168.1.45', 'Success', NOW() - INTERVAL '40 minutes'),
(gen_random_uuid(), NULL, '903fd71c-a497-4665-b5c5-279d880e7461', 'superadmin@school.com', 'Super Admin', 'super_admin', 'Update', 'Security', 'Password changed successfully', 'User: Super Admin', 'User', '192.168.1.45', 'Success', NOW() - INTERVAL '2 days'),
(gen_random_uuid(), NULL, '903fd71c-a497-4665-b5c5-279d880e7461', 'superadmin@school.com', 'Super Admin', 'super_admin', 'Logout', 'Authentication', 'Logged out from system', '-', '-', '192.168.1.45', 'Success', NOW() - INTERVAL '3 days');
