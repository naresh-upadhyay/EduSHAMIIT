-- Migration: 120_enhance_live_class_comments.sql
-- Description: Add is_edited column to live_class_comments and enable Supabase Realtime replication on it.

-- 1. Add is_edited column if it doesn't exist
ALTER TABLE public.live_class_comments ADD COLUMN IF NOT EXISTS is_edited BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Enable Supabase Realtime replication on the live_class_comments table
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
    ) THEN
        -- Check if live_class_comments table is already in supabase_realtime
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND tablename = 'live_class_comments'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE live_class_comments;
        END IF;
    END IF;
END $$;
