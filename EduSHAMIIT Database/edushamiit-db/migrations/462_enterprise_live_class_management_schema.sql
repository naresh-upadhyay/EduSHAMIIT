-- ============================================================================
-- Migration 462: Enterprise Live Class Management Schema Enhancements
-- Upgrades schema for Join & Conduct, Recordings, and Attendance Tracking.
-- Adds connection segments, settings, and relational links to academic classes,
-- sections, subjects, profiles, and attendance records.
-- ============================================================================

-- 1. ENHANCE live_classes TABLE
ALTER TABLE public.live_classes
    ADD COLUMN IF NOT EXISTS class_id UUID REFERENCES public.academic_classes(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS section_id UUID REFERENCES public.academic_sections(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS co_host_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS room_code VARCHAR(32),
    ADD COLUMN IF NOT EXISTS actual_start_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS actual_end_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS recording_enabled BOOLEAN DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS recording_status VARCHAR(50) DEFAULT 'IDLE',
    ADD COLUMN IF NOT EXISTS waiting_room_enabled BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS allow_student_share BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS allow_student_mic BOOLEAN DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS allow_student_cam BOOLEAN DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS allow_chat BOOLEAN DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS allow_reactions BOOLEAN DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS meeting_provider VARCHAR(50) DEFAULT 'livekit',
    ADD COLUMN IF NOT EXISTS provider_room_id VARCHAR(255),
    ADD COLUMN IF NOT EXISTS attendance_status VARCHAR(50) DEFAULT 'PENDING_REVIEW',
    ADD COLUMN IF NOT EXISTS attendance_marked_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 2. ENHANCE live_class_participants TABLE
ALTER TABLE public.live_class_participants
    ADD COLUMN IF NOT EXISTS participant_role VARCHAR(50) DEFAULT 'student',
    ADD COLUMN IF NOT EXISTS reconnection_count INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS participation_percentage NUMERIC(5,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS attendance_status VARCHAR(50) DEFAULT 'Absent',
    ADD COLUMN IF NOT EXISTS is_hand_raised BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS is_mic_muted BOOLEAN DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS is_cam_off BOOLEAN DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS connection_quality VARCHAR(50) DEFAULT 'good',
    ADD COLUMN IF NOT EXISTS first_join_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_leave_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 3. CREATE live_class_connection_segments TABLE FOR ACCURATE DISCONNECTION/RECONNECTION TRACKING
CREATE TABLE IF NOT EXISTS public.live_class_connection_segments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.live_classes(id) ON DELETE CASCADE,
    participant_id UUID REFERENCES public.live_class_participants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    duration_seconds INTEGER DEFAULT 0,
    disconnect_reason VARCHAR(100),
    connection_source VARCHAR(50) DEFAULT 'web',
    provider_event_id VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. ENHANCE live_class_recordings TABLE
ALTER TABLE public.live_class_recordings
    ADD COLUMN IF NOT EXISTS title VARCHAR(255),
    ADD COLUMN IF NOT EXISTS description TEXT,
    ADD COLUMN IF NOT EXISTS thumbnail_url TEXT,
    ADD COLUMN IF NOT EXISTS storage_provider VARCHAR(50) DEFAULT 'minio',
    ADD COLUMN IF NOT EXISTS storage_key VARCHAR(500),
    ADD COLUMN IF NOT EXISTS mime_type VARCHAR(100) DEFAULT 'video/mp4',
    ADD COLUMN IF NOT EXISTS processing_status VARCHAR(50) DEFAULT 'READY',
    ADD COLUMN IF NOT EXISTS visibility VARCHAR(50) DEFAULT 'CLASS',
    ADD COLUMN IF NOT EXISTS views_count INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS downloads_count INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS uploaded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS retention_days INTEGER DEFAULT 180,
    ADD COLUMN IF NOT EXISTS retention_until TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 5. ENHANCE live_class_attendance TABLE
ALTER TABLE public.live_class_attendance
    ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS class_id UUID REFERENCES public.academic_classes(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS section_id UUID REFERENCES public.academic_sections(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS subject_id UUID REFERENCES public.subjects(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS first_join_time TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_leave_time TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS effective_duration_seconds INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS participation_percentage NUMERIC(5,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS calculated_status VARCHAR(50),
    ADD COLUMN IF NOT EXISTS final_status VARCHAR(50),
    ADD COLUMN IF NOT EXISTS manual_override BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS override_reason TEXT,
    ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS remarks TEXT,
    ADD COLUMN IF NOT EXISTS daily_record_id UUID REFERENCES public.attendance_daily_records(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS period_record_id UUID REFERENCES public.attendance_period_records(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 6. CREATE live_class_settings TABLE
CREATE TABLE IF NOT EXISTS public.live_class_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE UNIQUE,
    min_attendance_percentage NUMERIC(5,2) DEFAULT 75.0,
    late_join_threshold_minutes INTEGER DEFAULT 10,
    early_leave_threshold_minutes INTEGER DEFAULT 10,
    auto_record_default BOOLEAN DEFAULT TRUE,
    cloud_storage_enabled BOOLEAN DEFAULT TRUE,
    default_retention_days INTEGER DEFAULT 180,
    recording_quality VARCHAR(50) DEFAULT 'HD (720p)',
    allow_student_download BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. PERFORMANCE INDEXES
CREATE INDEX IF NOT EXISTS idx_live_classes_school ON public.live_classes(school_id);
CREATE INDEX IF NOT EXISTS idx_live_classes_class_section ON public.live_classes(class_id, section_id);
CREATE INDEX IF NOT EXISTS idx_live_classes_status ON public.live_classes(status);
CREATE INDEX IF NOT EXISTS idx_live_classes_teacher ON public.live_classes(teacher_id);
CREATE INDEX IF NOT EXISTS idx_live_classes_scheduled_at ON public.live_classes(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_live_class_participants_session ON public.live_class_participants(live_class_id);
CREATE INDEX IF NOT EXISTS idx_live_class_participants_user ON public.live_class_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_live_class_segments_session ON public.live_class_connection_segments(session_id);
CREATE INDEX IF NOT EXISTS idx_live_class_segments_user ON public.live_class_connection_segments(user_id);
CREATE INDEX IF NOT EXISTS idx_live_class_attendance_session ON public.live_class_attendance(live_class_id);
CREATE INDEX IF NOT EXISTS idx_live_class_attendance_student ON public.live_class_attendance(student_id);
CREATE INDEX IF NOT EXISTS idx_live_class_recordings_session ON public.live_class_recordings(live_class_id);

-- 8. ROW LEVEL SECURITY (RLS)
ALTER TABLE public.live_class_connection_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_class_settings ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow authenticated read live_class_connection_segments') THEN
        CREATE POLICY "Allow authenticated read live_class_connection_segments" ON public.live_class_connection_segments FOR SELECT TO authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow authenticated insert live_class_connection_segments') THEN
        CREATE POLICY "Allow authenticated insert live_class_connection_segments" ON public.live_class_connection_segments FOR INSERT TO authenticated WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow authenticated update live_class_connection_segments') THEN
        CREATE POLICY "Allow authenticated update live_class_connection_segments" ON public.live_class_connection_segments FOR UPDATE TO authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Allow authenticated all live_class_settings') THEN
        CREATE POLICY "Allow authenticated all live_class_settings" ON public.live_class_settings FOR ALL TO authenticated USING (true);
    END IF;
END $$;
