-- Migration: 118_livekit_tables.sql
-- Description: Create tables for LiveKit Live Class integration

-- 1. Create live_class_participants table
CREATE TABLE IF NOT EXISTS public.live_class_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    live_class_id UUID NOT NULL REFERENCES public.live_classes(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    join_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    leave_time TIMESTAMP WITH TIME ZONE,
    duration INTEGER DEFAULT 0 -- in seconds
);

-- 2. Create live_class_attendance table
CREATE TABLE IF NOT EXISTS public.live_class_attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    live_class_id UUID NOT NULL REFERENCES public.live_classes(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    attendance_status TEXT NOT NULL CHECK (attendance_status IN ('Present', 'Partial', 'Absent')),
    duration INTEGER DEFAULT 0 -- total join duration in seconds
);

-- 3. Create live_class_chats table
CREATE TABLE IF NOT EXISTS public.live_class_chats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    live_class_id UUID NOT NULL REFERENCES public.live_classes(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Create live_class_recordings table
CREATE TABLE IF NOT EXISTS public.live_class_recordings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    live_class_id UUID NOT NULL REFERENCES public.live_classes(id) ON DELETE CASCADE,
    recording_url TEXT NOT NULL,
    duration INTEGER DEFAULT 0, -- in seconds
    file_size BIGINT DEFAULT 0
);

-- Enable RLS and create public policies
ALTER TABLE public.live_class_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_class_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_class_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_class_recordings ENABLE ROW LEVEL SECURITY;

-- Add policies
CREATE POLICY "Allow all select on live_class_participants" ON public.live_class_participants FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow all insert on live_class_participants" ON public.live_class_participants FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow all update on live_class_participants" ON public.live_class_participants FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Allow all select on live_class_attendance" ON public.live_class_attendance FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow all insert on live_class_attendance" ON public.live_class_attendance FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow all update on live_class_attendance" ON public.live_class_attendance FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Allow all select on live_class_chats" ON public.live_class_chats FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow all insert on live_class_chats" ON public.live_class_chats FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow all select on live_class_recordings" ON public.live_class_recordings FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow all insert on live_class_recordings" ON public.live_class_recordings FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow all delete on live_class_recordings" ON public.live_class_recordings FOR DELETE TO authenticated USING (true);
