-- Migration: 166_system_alerts_and_notifications.sql
-- Create system alerts table and notifications settings

-- 1. Create system_alerts table
CREATE TABLE IF NOT EXISTS public.system_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100) NOT NULL, -- e.g., 'Institutions', 'Users', 'System', 'Examinations', 'Payments'
    priority VARCHAR(50) NOT NULL, -- e.g., 'Critical', 'High', 'Warning', 'Info'
    status VARCHAR(50) NOT NULL DEFAULT 'New', -- e.g., 'New', 'In Progress', 'Resolved'
    is_read BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

-- 2. Add system_alert_sounds to profiles (other notifications fields already present in profiles)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS system_alert_sounds BOOLEAN DEFAULT FALSE;

-- 3. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_system_alerts_school ON public.system_alerts(school_id);
CREATE INDEX IF NOT EXISTS idx_system_alerts_priority ON public.system_alerts(priority);
CREATE INDEX IF NOT EXISTS idx_system_alerts_status ON public.system_alerts(status);
CREATE INDEX IF NOT EXISTS idx_system_alerts_created_at ON public.system_alerts(created_at DESC);

-- 4. Insert mock alerts matching the screenshot
-- Noida/Delhi timezone is UTC+5:30. Let's insert timestamps relative to now.
INSERT INTO public.system_alerts (id, school_id, title, description, category, priority, status, is_read, created_at)
VALUES
(
  gen_random_uuid(), NULL, 
  '8 Institutions Pending Approval', 
  'New institution registrations are pending approval.', 
  'Institutions', 'Critical', 'New', FALSE, 
  NOW() - INTERVAL '10 minutes'
),
(
  gen_random_uuid(), NULL, 
  '23 Staff Accounts Inactive', 
  'Staff accounts inactive for more than 30 days.', 
  'Users', 'High', 'New', FALSE, 
  NOW() - INTERVAL '1 hour'
),
(
  gen_random_uuid(), NULL, 
  '2 Institutions Suspended', 
  'Institutions have been suspended due to policy violations.', 
  'Institutions', 'Critical', 'New', TRUE, 
  NOW() - INTERVAL '3 hours'
),
(
  gen_random_uuid(), NULL, 
  'System Backup Completed', 
  'Daily system backup completed successfully.', 
  'System', 'Info', 'Resolved', TRUE, 
  NOW() - INTERVAL '4 hours'
),
(
  gen_random_uuid(), NULL, 
  'High Database Usage', 
  'Database storage usage has crossed 80%.', 
  'System', 'Warning', 'In Progress', FALSE, 
  NOW() - INTERVAL '1 day'
),
(
  gen_random_uuid(), NULL, 
  'Exam Results Not Published', 
  '5 examinations have pending results.', 
  'Examinations', 'High', 'New', FALSE, 
  NOW() - INTERVAL '1 day' - INTERVAL '4 hours'
),
(
  gen_random_uuid(), NULL, 
  'Payment Gateway Issue', 
  'Some payments are failing due to gateway timeout.', 
  'Payments', 'Critical', 'In Progress', FALSE, 
  NOW() - INTERVAL '2 days'
),
(
  gen_random_uuid(), NULL, 
  'New Feature Update Available', 
  'A new version v2.5.1 is available for the system.', 
  'System', 'Info', 'Resolved', TRUE, 
  NOW() - INTERVAL '2 days' - INTERVAL '2 hours'
);
