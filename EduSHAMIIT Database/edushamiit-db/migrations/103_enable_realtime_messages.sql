-- Migration: 103_enable_realtime_messages.sql
-- Description: Enable Supabase Realtime replication on the messages table

-- First check if the publication 'supabase_realtime' exists, and add the table 'messages' to it.
-- This ensures that changes to the 'messages' table are broadcast to subscribed clients in real-time.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
    ) THEN
        -- Check if messages table is already in supabase_realtime
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND tablename = 'messages'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE messages;
        END IF;
    END IF;
END $$;
