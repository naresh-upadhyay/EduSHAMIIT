-- Database migration: 155_announcements.sql
-- Create Announcements schema with realistic sample data matching the mockup.

CREATE TABLE IF NOT EXISTS public.announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    audience TEXT[] NOT NULL,
    school_id UUID REFERENCES public.schools(id) ON DELETE SET NULL, -- NULL means 'All Institutions'
    priority TEXT NOT NULL DEFAULT 'Medium' CHECK (priority IN ('Low', 'Medium', 'High')),
    status TEXT NOT NULL DEFAULT 'Draft' CHECK (status IN ('Draft', 'Published', 'Scheduled', 'Expired')),
    published_at TIMESTAMP WITH TIME ZONE,
    scheduled_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_by_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Allow read for all on announcements" ON public.announcements FOR SELECT USING (true);
CREATE POLICY "Allow write for all on announcements" ON public.announcements FOR ALL USING (true);

-- Seed Announcements matching the mockup
INSERT INTO public.announcements (id, title, description, audience, school_id, priority, status, published_at, scheduled_at, expires_at, created_by_id, created_at) VALUES
(
  'a1a11111-1111-1111-1111-111111111111',
  'Fee Payment Reminder',
  'Last date for fee submission for May 2025',
  ARRAY['parent'],
  'e1f11111-1111-1111-1111-111111111111', -- Greenfield Public School
  'High',
  'Published',
  '2025-05-20 09:30:00+00',
  NULL,
  '2025-06-20 23:59:59+00',
  'd1af0000-0000-0000-0000-000000000000',
  '2025-05-20 09:00:00+00'
),
(
  'a2a22222-2222-2222-2222-222222222222',
  'Summer Vacation Notice',
  'School will remain closed for summer vacation.',
  ARRAY['student'],
  NULL, -- All Institutions
  'Medium',
  'Published',
  '2025-05-18 10:00:00+00',
  NULL,
  '2025-07-31 23:59:59+00',
  'd1af0000-0000-0000-0000-000000000000',
  '2025-05-18 09:00:00+00'
),
(
  'a3a33333-3333-3333-3333-333333333333',
  'Staff Meeting - May 25',
  'Monthly staff meeting is scheduled.',
  ARRAY['teacher'],
  'e1f33333-3333-3333-3333-333333333333', -- Bright Future Academy
  'Medium',
  'Scheduled',
  NULL,
  '2025-05-25 11:00:00+00',
  '2025-05-25 14:00:00+00',
  'd1af0000-0000-0000-0000-000000000000',
  '2025-05-20 10:00:00+00'
),
(
  'a4a44444-4444-4444-4444-444444444444',
  'New Library Books Available',
  'Check out the latest collection in our library.',
  ARRAY['student'],
  'e1f11111-1111-1111-1111-111111111111', -- Greenfield Public School
  'Low',
  'Published',
  '2025-05-17 16:45:00+00',
  NULL,
  '2025-06-17 23:59:59+00',
  'd1af0000-0000-0000-0000-000000000000',
  '2025-05-17 16:00:00+00'
),
(
  'a5a55555-5555-5555-5555-555555555555',
  'Holiday on May 26',
  'School will remain closed on account of Memorial Day.',
  ARRAY['parent'],
  'e1f22222-2222-2222-2222-222222222222', -- Sunrise International School
  'High',
  'Scheduled',
  NULL,
  '2025-05-26 00:00:00+00',
  '2025-05-26 23:59:59+00',
  'd1af0000-0000-0000-0000-000000000000',
  '2025-05-20 12:00:00+00'
),
(
  'a6a66666-6666-6666-6666-666666666666',
  'Exam Time Table Released',
  'Mid-term exam timetable is now available.',
  ARRAY['student'],
  NULL, -- All Institutions
  'High',
  'Published',
  '2025-05-15 14:15:00+00',
  NULL,
  '2025-06-15 23:59:59+00',
  'd1af0000-0000-0000-0000-000000000000',
  '2025-05-15 12:00:00+00'
),
(
  'a7a77777-7777-7777-7777-777777777777',
  'PTM Schedule',
  'Parent Teacher Meeting details for this month.',
  ARRAY['parent'],
  'e1f66666-6666-6666-6666-666666666666', -- St. Xavier's School
  'Medium',
  'Draft',
  NULL,
  NULL,
  NULL,
  'd1af0000-0000-0000-0000-000000000000',
  '2025-05-20 14:00:00+00'
),
(
  'a8a88888-8888-8888-8888-888888888888',
  'Sports Day Announcement',
  'Annual Sports Day will be held on 5th June.',
  ARRAY['student'],
  'e1f11111-1111-1111-1111-111111111111', -- Greenfield Public School
  'Low',
  'Scheduled',
  NULL,
  '2025-06-05 09:00:00+00',
  '2025-06-05 18:00:00+00',
  'd1af0000-0000-0000-0000-000000000000',
  '2025-05-20 15:00:00+00'
),
(
  'a9a99999-9999-9999-9999-999999999999',
  'System Maintenance',
  'ERP system will be down for maintenance.',
  ARRAY['teacher'],
  NULL, -- All Institutions
  'High',
  'Expired',
  '2025-05-10 01:00:00+00',
  NULL,
  '2025-05-10 05:00:00+00',
  'd1af0000-0000-0000-0000-000000000000',
  '2025-05-09 12:00:00+00'
),
(
  'a0a00000-0000-0000-0000-000000000000',
  'New Admission Open',
  'Admissions open for academic session 2025-26.',
  ARRAY['public'],
  'e1f33333-3333-3333-3333-333333333333', -- Bright Future Academy
  'Medium',
  'Expired',
  '2025-05-01 11:30:00+00',
  NULL,
  '2025-05-31 23:59:59+00',
  'd1af0000-0000-0000-0000-000000000000',
  '2025-04-30 10:00:00+00'
)
ON CONFLICT (id) DO NOTHING;
