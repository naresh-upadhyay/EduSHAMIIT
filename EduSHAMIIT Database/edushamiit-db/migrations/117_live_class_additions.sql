-- Migration: 117_live_class_additions.sql
-- Description: Add parent_id to live_class_comments for threaded replies and create storage bucket for live class recordings.

-- 1. Add parent_id to live_class_comments
ALTER TABLE live_class_comments 
ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES live_class_comments(id) ON DELETE CASCADE;

-- 2. Create storage bucket for live class recordings
INSERT INTO storage.buckets (id, name, public) 
VALUES ('live-class-recordings', 'live-class-recordings', true)
ON CONFLICT (id) DO NOTHING;

-- 3. Policy to allow authenticated users (teachers) to upload to 'live-class-recordings'
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'Teacher Insert Access to recordings'
    ) THEN
        CREATE POLICY "Teacher Insert Access to recordings" 
        ON storage.objects FOR INSERT 
        TO authenticated 
        WITH CHECK (
            bucket_id = 'live-class-recordings' AND 
            EXISTS (
                SELECT 1 FROM public.profiles 
                WHERE profiles.id = auth.uid() AND profiles.role = 'teacher'
            )
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'Public Read Access to recordings'
    ) THEN
        CREATE POLICY "Public Read Access to recordings" 
        ON storage.objects FOR SELECT 
        TO public 
        USING (bucket_id = 'live-class-recordings');
    END IF;
END
$$;
