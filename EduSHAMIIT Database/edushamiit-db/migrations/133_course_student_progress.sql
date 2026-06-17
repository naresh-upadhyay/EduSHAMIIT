-- ============================================================
-- Migration 133: Add Course Student Progress tracking
-- ============================================================

CREATE TABLE IF NOT EXISTS public.student_topic_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    topic_id UUID REFERENCES public.course_topics(id) ON DELETE CASCADE,
    completed BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(student_id, topic_id)
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.student_topic_progress ENABLE ROW LEVEL SECURITY;

-- Create policies for student_topic_progress
CREATE POLICY anyone_read_student_topic_progress ON public.student_topic_progress
    FOR SELECT USING (true);

CREATE POLICY anyone_write_student_topic_progress ON public.student_topic_progress
    FOR ALL USING (true);
