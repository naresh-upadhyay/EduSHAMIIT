-- Migration: 119_live_class_playback_features.sql
-- Description: Database tables and RLS policies for Live Class Playback Hub (Likes, Ratings, Chapters, Resources, Notes)

-- 1. Create live_class_likes table
CREATE TABLE IF NOT EXISTS public.live_class_likes (
    live_class_id UUID NOT NULL REFERENCES public.live_classes(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    is_dislike BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (live_class_id, user_id)
);

-- 2. Create live_class_ratings table
CREATE TABLE IF NOT EXISTS public.live_class_ratings (
    live_class_id UUID NOT NULL REFERENCES public.live_classes(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (live_class_id, user_id)
);

-- 3. Create live_class_chapters table
CREATE TABLE IF NOT EXISTS public.live_class_chapters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    live_class_id UUID NOT NULL REFERENCES public.live_classes(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    time_seconds INTEGER NOT NULL CHECK (time_seconds >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Create live_class_resources table
CREATE TABLE IF NOT EXISTS public.live_class_resources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    live_class_id UUID NOT NULL REFERENCES public.live_classes(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    file_url TEXT NOT NULL,
    file_size TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Create live_class_notes table
CREATE TABLE IF NOT EXISTS public.live_class_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    live_class_id UUID NOT NULL REFERENCES public.live_classes(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    notes_text TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (live_class_id, user_id)
);

-- Enable RLS
ALTER TABLE public.live_class_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_class_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_class_chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_class_resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_class_notes ENABLE ROW LEVEL SECURITY;

-- Create Policies
CREATE POLICY "Allow all select on live_class_likes" ON public.live_class_likes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow all insert on live_class_likes" ON public.live_class_likes FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow all update on live_class_likes" ON public.live_class_likes FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Allow all delete on live_class_likes" ON public.live_class_likes FOR DELETE TO authenticated USING (true);

CREATE POLICY "Allow all select on live_class_ratings" ON public.live_class_ratings FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow all insert on live_class_ratings" ON public.live_class_ratings FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow all update on live_class_ratings" ON public.live_class_ratings FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Allow all delete on live_class_ratings" ON public.live_class_ratings FOR DELETE TO authenticated USING (true);

CREATE POLICY "Allow all select on live_class_chapters" ON public.live_class_chapters FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow all insert on live_class_chapters" ON public.live_class_chapters FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow all update on live_class_chapters" ON public.live_class_chapters FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Allow all delete on live_class_chapters" ON public.live_class_chapters FOR DELETE TO authenticated USING (true);

CREATE POLICY "Allow all select on live_class_resources" ON public.live_class_resources FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow all insert on live_class_resources" ON public.live_class_resources FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow all update on live_class_resources" ON public.live_class_resources FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Allow all delete on live_class_resources" ON public.live_class_resources FOR DELETE TO authenticated USING (true);

CREATE POLICY "Allow all select on live_class_notes" ON public.live_class_notes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow all insert on live_class_notes" ON public.live_class_notes FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow all update on live_class_notes" ON public.live_class_notes FOR UPDATE TO authenticated USING (true);
CREATE POLICY "Allow all delete on live_class_notes" ON public.live_class_notes FOR DELETE TO authenticated USING (true);
