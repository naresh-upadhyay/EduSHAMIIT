-- Migration: 121_enable_realtime_comments_rls.sql
-- Description: Enable Row Level Security (RLS) on live_class_comments and create select policy to enable Supabase Realtime broadcast.

-- 1. Enable RLS on the live_class_comments table
ALTER TABLE public.live_class_comments ENABLE ROW LEVEL SECURITY;

-- 2. Create policy to allow anyone authenticated to view live class comments
DROP POLICY IF EXISTS anyone_read_comments ON public.live_class_comments;
CREATE POLICY "anyone_read_comments" ON public.live_class_comments FOR SELECT USING (true);

-- 3. Set replica identity to FULL to make sure delete payloads have complete column details
ALTER TABLE public.live_class_comments REPLICA IDENTITY FULL;
