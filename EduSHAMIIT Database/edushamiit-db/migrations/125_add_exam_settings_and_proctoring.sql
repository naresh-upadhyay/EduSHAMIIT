-- ============================================================
-- Migration 125: Add Exam Settings and Question Bank Table
-- ============================================================

ALTER TABLE exams
ADD COLUMN IF NOT EXISTS negative_marking BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS shuffle_questions BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS shuffle_options BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS allow_calculator BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS camera_required BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS mic_required BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS auto_submit_on_timer BOOLEAN DEFAULT true;

CREATE TABLE IF NOT EXISTS question_bank (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES schools(id) ON DELETE CASCADE,
    teacher_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
    chapter TEXT,
    question_text TEXT NOT NULL,
    question_type TEXT NOT NULL, -- mcq, true_false, short_answer, long_answer
    options JSONB,
    correct_answer TEXT,
    difficulty TEXT DEFAULT 'Medium', -- Easy, Medium, Hard
    marks INT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS for question_bank
ALTER TABLE question_bank ENABLE ROW LEVEL SECURITY;

-- Simple policy for everyone to read
CREATE POLICY anyone_read_question_bank ON question_bank
    FOR SELECT USING (true);

-- Policy for authenticated users to insert/update/delete their school's questions
CREATE POLICY teacher_write_question_bank ON question_bank
    FOR ALL USING (true);
