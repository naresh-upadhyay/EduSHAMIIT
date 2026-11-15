-- ============================================================================
-- Migration: 436_prestart_customization_policy.sql
-- Description: Complete Schema & Seed Data for Examination Pre-Start Instructions,
--   System Readiness Sessions, and Dynamic Setter Policy Configuration.
-- ============================================================================

-- 1. Ensure public.exams has prestart_config JSONB for granular tri-state policies & warnings
ALTER TABLE public.exams
ADD COLUMN IF NOT EXISTS prestart_config JSONB DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.exams.prestart_config IS 'Stores granular pre-start policy (camera_mode, microphone_mode, screen_share_mode, device_check_mode, fullscreen_required, max_tab_switches, acknowledgment_required, custom warnings)';

-- 2. Pre-start readiness sessions table
CREATE TABLE IF NOT EXISTS public.exam_prestart_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    session_token TEXT,
    camera_status VARCHAR(50) DEFAULT 'NOT_CHECKED',
    microphone_status VARCHAR(50) DEFAULT 'NOT_CHECKED',
    screen_share_status VARCHAR(50) DEFAULT 'NOT_CHECKED',
    system_status VARCHAR(50) DEFAULT 'NOT_CHECKED',
    readiness_status VARCHAR(50) DEFAULT 'NOT_READY',
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_at TIMESTAMPTZ,
    system_details JSONB DEFAULT '{}'::jsonb,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    last_activity_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_prestart_exam_student UNIQUE(exam_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_prestart_exam_student ON public.exam_prestart_sessions(exam_id, student_id);

-- 3. Categorized examination instructions table (school defaults + per-exam overrides)
CREATE TABLE IF NOT EXISTS public.exam_instructions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL,
    exam_id UUID REFERENCES public.exams(id) ON DELETE CASCADE,
    category VARCHAR(50) NOT NULL, -- 'general', 'during_exam', 'proctoring', 'technical', 'submission'
    title VARCHAR(255) NOT NULL,
    description TEXT,
    display_order INT DEFAULT 0,
    is_mandatory BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_instructions_exam_cat ON public.exam_instructions(exam_id, category);
CREATE INDEX IF NOT EXISTS idx_instructions_school_cat ON public.exam_instructions(school_id, category);

-- 4. Idempotent default instruction seeding for existing schools that have no defaults yet
DO $$
DECLARE
    v_school_id UUID;
BEGIN
    FOR v_school_id IN SELECT id FROM public.schools LOOP
        IF NOT EXISTS (
            SELECT 1 FROM public.exam_instructions WHERE school_id = v_school_id AND exam_id IS NULL
        ) THEN
            INSERT INTO public.exam_instructions (school_id, exam_id, category, title, description, display_order, is_mandatory, is_active)
            VALUES
                (v_school_id, NULL, 'general', 'Read carefully', 'Read all questions carefully before answering.', 1, TRUE, TRUE),
                (v_school_id, NULL, 'general', 'Question format', 'The exam consists of Multiple Choice, Multiple Select, Short Answer and Long Answer questions.', 2, TRUE, TRUE),
                (v_school_id, NULL, 'general', 'Marks distribution', 'Verify the total marks and marks assigned to each question before proceeding.', 3, TRUE, TRUE),
                (v_school_id, NULL, 'general', 'All questions compulsory', 'Attempt all required sections as per the question paper blueprint.', 4, TRUE, TRUE),
                (v_school_id, NULL, 'during_exam', 'Autosave active', 'Answers are auto-saved in the background as you attempt each question.', 1, TRUE, TRUE),
                (v_school_id, NULL, 'during_exam', 'Question palette', 'Use the question palette to jump between questions and view your progress.', 2, TRUE, TRUE),
                (v_school_id, NULL, 'during_exam', 'Mark for review', 'You can mark any question for review and revisit it before final submission.', 3, TRUE, TRUE),
                (v_school_id, NULL, 'during_exam', 'Timer awareness', 'Keep an eye on the server countdown timer at the top right of the workspace.', 4, TRUE, TRUE),
                (v_school_id, NULL, 'proctoring', 'Full screen mode', 'The examination workspace must remain in full screen throughout the test.', 1, TRUE, TRUE),
                (v_school_id, NULL, 'proctoring', 'No tab switching', 'Do not switch tabs, minimize the browser, or open other applications.', 2, TRUE, TRUE),
                (v_school_id, NULL, 'proctoring', 'Face visibility', 'Ensure your camera remains active and your face is clearly visible.', 3, TRUE, TRUE),
                (v_school_id, NULL, 'proctoring', 'Audio monitoring', 'Avoid background noise or conversations; microphone detects anomalous sounds.', 4, TRUE, TRUE),
                (v_school_id, NULL, 'technical', 'Browser requirement', 'Use a modern version of Google Chrome, Microsoft Edge, or Mozilla Firefox.', 1, TRUE, TRUE),
                (v_school_id, NULL, 'technical', 'Stable connection', 'Ensure a stable internet connection with at least 1 Mbps upload/download.', 2, TRUE, TRUE),
                (v_school_id, NULL, 'technical', 'Do not refresh', 'Do not press F5, reload the browser, or close the examination tab.', 3, TRUE, TRUE),
                (v_school_id, NULL, 'technical', 'Battery & Power', 'Keep your device connected to a power supply or ensure sufficient battery life.', 4, TRUE, TRUE),
                (v_school_id, NULL, 'submission', 'Review summary', 'Review your answered and unanswered questions in the confirmation dialog.', 1, TRUE, TRUE),
                (v_school_id, NULL, 'submission', 'Irreversible action', 'Once submitted, your answers cannot be altered or re-opened.', 2, TRUE, TRUE),
                (v_school_id, NULL, 'submission', 'Confirmation prompt', 'Click Confirm & Submit to finish and record your score securely.', 3, TRUE, TRUE);
        END IF;
    END LOOP;
END $$;
