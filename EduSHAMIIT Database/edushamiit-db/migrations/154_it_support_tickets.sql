-- Database migration: 154_it_support_tickets.sql
-- Create IT Support Tickets, Messages, and Attachments schema with realistic sample data.

CREATE TABLE IF NOT EXISTS public.it_support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_code VARCHAR(50) UNIQUE NOT NULL,
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    subject TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL CHECK (category IN ('Login / Access', 'Academics', 'Fees', 'Documents', 'Notifications', 'Library', 'Transport', 'Performance', 'User Management', 'System', 'Others')),
    priority TEXT NOT NULL CHECK (priority IN ('Low', 'Medium', 'High')),
    status TEXT NOT NULL DEFAULT 'Open' CHECK (status IN ('Open', 'In Progress', 'Pending User', 'Resolved', 'Closed')),
    requested_by_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    assigned_to_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.it_support_ticket_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL REFERENCES public.it_support_tickets(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    message_type TEXT NOT NULL DEFAULT 'conversation' CHECK (message_type IN ('conversation', 'note')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.it_support_ticket_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL REFERENCES public.it_support_tickets(id) ON DELETE CASCADE,
    file_name TEXT NOT NULL,
    file_url TEXT NOT NULL,
    file_type TEXT,
    file_size INTEGER NOT NULL,
    uploaded_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.it_support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.it_support_ticket_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.it_support_ticket_attachments ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Allow read for all on tickets" ON public.it_support_tickets FOR SELECT USING (true);
CREATE POLICY "Allow write for all on tickets" ON public.it_support_tickets FOR ALL USING (true);

CREATE POLICY "Allow read for all on ticket messages" ON public.it_support_ticket_messages FOR SELECT USING (true);
CREATE POLICY "Allow write for all on ticket messages" ON public.it_support_ticket_messages FOR ALL USING (true);

CREATE POLICY "Allow read for all on ticket attachments" ON public.it_support_ticket_attachments FOR SELECT USING (true);
CREATE POLICY "Allow write for all on ticket attachments" ON public.it_support_ticket_attachments FOR ALL USING (true);

-- Seed schools if not existing
INSERT INTO public.schools (id, name, address, phone) VALUES
('e1f11111-1111-1111-1111-111111111111', 'Greenfield Public School', 'Sector 15, Gurgaon', '+91-124-4567890'),
('e1f22222-2222-2222-2222-222222222222', 'Sunrise International School', 'Whitefield, Bangalore', '+91-80-98765432'),
('e1f33333-3333-3333-3333-333333333333', 'Bright Future Academy', 'Salt Lake, Kolkata', '+91-33-22446688'),
('e1f44444-4444-4444-4444-444444444444', 'Genius Convent School', 'Anna Nagar, Chennai', '+91-44-11223344'),
('e1f55555-5555-5555-5555-555555555555', 'Holy Angels School', 'Bandra West, Mumbai', '+91-22-33445566'),
('e1f66666-6666-6666-6666-666666666666', 'St. Xavier''s School', 'Park Street, Kolkata', '+91-33-44556677'),
('e1f77777-7777-7777-7777-777777777777', 'Delhi Public School', 'Dwarka, Delhi', '+91-11-55667788'),
('e1f88888-8888-8888-8888-888888888888', 'Modern School', 'Barakhamba Road, Delhi', '+91-11-66778899'),
('e1f99999-9999-9999-9999-999999999999', 'Cambridge School', 'Indiranagar, Bangalore', '+91-80-77889900'),
('e1f00000-0000-0000-0000-000000000000', 'Apex International School', 'Malviya Nagar, Jaipur', '+91-141-88990011')
ON CONFLICT (id) DO NOTHING;

-- Seed profiles
INSERT INTO public.profiles (id, school_id, user_id, full_name, email, role, phone) VALUES
('d1a11111-1111-1111-1111-111111111111', 'e1f11111-1111-1111-1111-111111111111', 'USR-ANJALI', 'Anjali Mehta', 'anjali.mehta@schoolerp.com', 'teacher', '+91-9876543211'),
('d1a22222-2222-2222-2222-222222222222', 'e1f22222-2222-2222-2222-222222222222', 'USR-ROHIT', 'Rohit Sharma', 'rohit.sharma@schoolerp.com', 'admin', '+91-9876543212'),
('d1a33333-3333-3333-3333-333333333333', 'e1f33333-3333-3333-3333-333333333333', 'USR-PRIYA', 'Priya Verma', 'priya.verma@schoolerp.com', 'finance', '+91-9876543213'),
('d1a44444-4444-4444-4444-444444444444', 'e1f44444-4444-4444-4444-444444444444', 'USR-ARJUN', 'Arjun Patel', 'arjun.patel@schoolerp.com', 'teacher', '+91-9876543214'),
('d1a55555-5555-5555-5555-555555555555', 'e1f55555-5555-5555-5555-555555555555', 'USR-NEHA', 'Neha Singh', 'neha.singh@schoolerp.com', 'admin', '+91-9876543215'),
('d1a66666-6666-6666-6666-666666666666', 'e1f66666-6666-6666-6666-666666666666', 'USR-DEEPAK', 'Deepak Yadav', 'deepak.yadav@schoolerp.com', 'library', '+91-9876543216'),
('d1a77777-7777-7777-7777-777777777777', 'e1f77777-7777-7777-7777-777777777777', 'USR-MANISH', 'Manish Kumar', 'manish.kumar@schoolerp.com', 'transport', '+91-9876543217'),
('d1a88888-8888-8888-8888-888888888888', 'e1f88888-8888-8888-8888-888888888888', 'USR-VIKRAM', 'Vikram Singh', 'vikram.singh@schoolerp.com', 'admin', '+91-9876543218'),
('d1a99999-9999-9999-9999-999999999999', 'e1f99999-9999-9999-9999-999999999999', 'USR-SUNITA', 'Sunita Rawat', 'sunita.rawat@schoolerp.com', 'teacher', '+91-9876543219'),
('d1a00000-0000-0000-0000-000000000000', 'e1f00000-0000-0000-0000-000000000000', 'USR-SAURABH', 'Saurabh Jain', 'saurabh.jain@schoolerp.com', 'teacher', '+91-9876543220'),
('d1af0000-0000-0000-0000-000000000000', NULL, 'USR-RAHUL', 'Rahul IT Support', 'rahul.support@schoolerp.com', 'support', '+91-9876543221')
ON CONFLICT (id) DO NOTHING;

-- Seed Tickets
INSERT INTO public.it_support_tickets (id, ticket_code, school_id, subject, description, category, priority, status, requested_by_id, assigned_to_id, created_at, updated_at) VALUES
(
  'b1f11111-1111-1111-1111-111111111111',
  'TKT-2025-1567',
  'e1f11111-1111-1111-1111-111111111111',
  'Unable to login to ERP',
  'I am getting error while login with valid credentials.',
  'Login / Access',
  'High',
  'Open',
  'd1a11111-1111-1111-1111-111111111111',
  'd1af0000-0000-0000-0000-000000000000',
  timezone('utc'::text, now()) - interval '1 hour',
  timezone('utc'::text, now()) - interval '30 minutes'
),
(
  'b1f22222-2222-2222-2222-222222222222',
  'TKT-2025-1566',
  'e1f22222-2222-2222-2222-222222222222',
  'Student marks not showing',
  'Marks are not visible in report card view for primary class students.',
  'Academics',
  'Medium',
  'In Progress',
  'd1a22222-2222-2222-2222-222222222222',
  'd1af0000-0000-0000-0000-000000000000',
  timezone('utc'::text, now()) - interval '2 hours',
  timezone('utc'::text, now()) - interval '1 hour'
),
(
  'b1f33333-3333-3333-3333-333333333333',
  'TKT-2025-1565',
  'e1f33333-3333-3333-3333-333333333333',
  'Issue in fee payment',
  'Payment failed but amount deducted from bank account.',
  'Fees',
  'High',
  'Pending User',
  'd1a33333-3333-3333-3333-333333333333',
  NULL,
  timezone('utc'::text, now()) - interval '3 hours',
  timezone('utc'::text, now()) - interval '2 hours'
),
(
  'b1f44444-4444-4444-4444-444444444444',
  'TKT-2025-1564',
  'e1f44444-4444-4444-4444-444444444444',
  'Upload document not working',
  'Documents are not uploading in course material module.',
  'Documents',
  'Low',
  'In Progress',
  'd1a44444-4444-4444-4444-444444444444',
  'd1af0000-0000-0000-0000-000000000000',
  timezone('utc'::text, now()) - interval '4 hours',
  timezone('utc'::text, now()) - interval '3 hours'
),
(
  'b1f55555-5555-5555-5555-555555555555',
  'TKT-2025-1563',
  'e1f55555-5555-5555-5555-555555555555',
  'Email notifications not received',
  'Not getting emails for new admission confirmations.',
  'Notifications',
  'Medium',
  'Resolved',
  'd1a55555-5555-5555-5555-555555555555',
  NULL,
  timezone('utc'::text, now()) - interval '1 day',
  timezone('utc'::text, now()) - interval '12 hours'
),
(
  'b1f66666-6666-6666-6666-666666666666',
  'TKT-2025-1562',
  'e1f66666-6666-6666-6666-666666666666',
  'Library issue',
  'Book issue/return system is not working.',
  'Library',
  'Low',
  'Open',
  'd1a66666-6666-6666-6666-666666666666',
  NULL,
  timezone('utc'::text, now()) - interval '1 day',
  timezone('utc'::text, now()) - interval '1 day'
),
(
  'b1f77777-7777-7777-7777-777777777777',
  'TKT-2025-1561',
  'e1f77777-7777-7777-7777-777777777777',
  'Transport route not assigned',
  'Route allocation not saving for new students.',
  'Transport',
  'Medium',
  'Pending User',
  'd1a77777-7777-7777-7777-777777777777',
  NULL,
  timezone('utc'::text, now()) - interval '2 days',
  timezone('utc'::text, now()) - interval '1 day'
),
(
  'b1f88888-8888-8888-8888-888888888888',
  'TKT-2025-1560',
  'e1f88888-8888-8888-8888-888888888888',
  'System slow performance',
  'ERP is very slow since morning, taking time to load dashboards.',
  'Performance',
  'High',
  'In Progress',
  'd1a88888-8888-8888-8888-888888888888',
  'd1af0000-0000-0000-0000-000000000000',
  timezone('utc'::text, now()) - interval '2 days',
  timezone('utc'::text, now()) - interval '2 days'
),
(
  'b1f99999-9999-9999-9999-999999999999',
  'TKT-2025-1559',
  'e1f99999-9999-9999-9999-999999999999',
  'Request for new user',
  'Need new user credentials created for front office staff.',
  'User Management',
  'Low',
  'Resolved',
  'd1a99999-9999-9999-9999-999999999999',
  NULL,
  timezone('utc'::text, now()) - interval '3 days',
  timezone('utc'::text, now()) - interval '2 days'
),
(
  'b1f00000-0000-0000-0000-000000000000',
  'TKT-2025-1558',
  'e1f00000-0000-0000-0000-000000000000',
  'Backup not completed',
  'Daily backup is failing with database connection timeout.',
  'System',
  'High',
  'Closed',
  'd1a00000-0000-0000-0000-000000000000',
  'd1af0000-0000-0000-0000-000000000000',
  timezone('utc'::text, now()) - interval '4 days',
  timezone('utc'::text, now()) - interval '3 days'
)
ON CONFLICT (id) DO NOTHING;

-- Seed Messages
INSERT INTO public.it_support_ticket_messages (id, ticket_id, sender_id, message, message_type, created_at) VALUES
(
  'c1f11111-1111-1111-1111-111111111111',
  'b1f11111-1111-1111-1111-111111111111',
  'd1a11111-1111-1111-1111-111111111111',
  'I am unable to login to ERP. It shows "Invalid credentials" error.',
  'conversation',
  timezone('utc'::text, now()) - interval '1 hour'
),
(
  'c1f22222-2222-2222-2222-222222222222',
  'b1f11111-1111-1111-1111-111111111111',
  'd1af0000-0000-0000-0000-000000000000',
  'Please try resetting your password and let us know.',
  'conversation',
  timezone('utc'::text, now()) - interval '45 minutes'
),
(
  'c1f33333-3333-3333-3333-333333333333',
  'b1f11111-1111-1111-1111-111111111111',
  'd1a11111-1111-1111-1111-111111111111',
  'I tried but still facing the same issue.',
  'conversation',
  timezone('utc'::text, now()) - interval '30 minutes'
),
(
  'c1f44444-4444-4444-4444-444444444444',
  'b1f11111-1111-1111-1111-111111111111',
  'd1af0000-0000-0000-0000-000000000000',
  'Note: Check Auth logs for user. Might be a blocked profile.',
  'note',
  timezone('utc'::text, now()) - interval '25 minutes'
)
ON CONFLICT (id) DO NOTHING;

-- Seed Attachments
INSERT INTO public.it_support_ticket_attachments (id, ticket_id, file_name, file_url, file_size, created_at) VALUES
(
  'a1f11111-1111-1111-1111-111111111111',
  'b1f11111-1111-1111-1111-111111111111',
  'login_error_screenshot.png',
  'http://localhost:9000/support/login_error.png',
  125400,
  timezone('utc'::text, now()) - interval '1 hour'
)
ON CONFLICT (id) DO NOTHING;
