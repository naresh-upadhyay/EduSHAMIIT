-- ============================================================
-- Migration 126: Add Course Chapters and Course Topics Tables
-- ============================================================

CREATE TABLE IF NOT EXISTS course_chapters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE,
    course_id UUID REFERENCES courses(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    chapter_order INT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS course_topics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE,
    chapter_id UUID REFERENCES course_chapters(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    topic_order INT NOT NULL,
    content TEXT, -- Markdown or HTML content
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security (RLS)
ALTER TABLE course_chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_topics ENABLE ROW LEVEL SECURITY;

-- Create policies for course_chapters
CREATE POLICY anyone_read_course_chapters ON course_chapters
    FOR SELECT USING (true);

CREATE POLICY anyone_write_course_chapters ON course_chapters
    FOR ALL USING (true);

-- Create policies for course_topics
CREATE POLICY anyone_read_course_topics ON course_topics
    FOR SELECT USING (true);

CREATE POLICY anyone_write_course_topics ON course_topics
    FOR ALL USING (true);
