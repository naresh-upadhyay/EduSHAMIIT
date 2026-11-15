-- ============================================================================
-- Migration: 438_enterprise_live_exam_monitoring_schema.sql
-- Description: Enterprise Live Examination Monitoring & Invigilation Schema
--   Extends existing exam_sessions with real-time telemetry and monitoring
--   state machine, and creates relational tables for monitoring sessions,
--   incidents, invigilator actions, re-entry requests, time adjustments, and
--   live announcements. Idempotent & tenant-isolated.
-- ============================================================================

-- 1. Extend public.exam_sessions with enterprise monitoring telemetry
ALTER TABLE public.exam_sessions
    ADD COLUMN IF NOT EXISTS monitoring_status VARCHAR(40) NOT NULL DEFAULT 'ACTIVE',
    ADD COLUMN IF NOT EXISTS camera_permission_state VARCHAR(40) NOT NULL DEFAULT 'NOT_CHECKED',
    ADD COLUMN IF NOT EXISTS mic_permission_state VARCHAR(40) NOT NULL DEFAULT 'NOT_CHECKED',
    ADD COLUMN IF NOT EXISTS screen_share_state VARCHAR(40) NOT NULL DEFAULT 'NOT_SHARED',
    ADD COLUMN IF NOT EXISTS screen_share_active BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS livekit_connected BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS livekit_identity TEXT,
    ADD COLUMN IF NOT EXISTS network_status VARCHAR(30) NOT NULL DEFAULT 'GOOD',
    ADD COLUMN IF NOT EXISTS latency_ms INTEGER,
    ADD COLUMN IF NOT EXISTS paused_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS paused_total_seconds INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS paused_reason TEXT,
    ADD COLUMN IF NOT EXISTS timer_pause_policy VARCHAR(30) NOT NULL DEFAULT 'freeze',
    ADD COLUMN IF NOT EXISTS last_answer_sync_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS answered_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS marked_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS total_questions_snapshot INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS current_question_index INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS reentry_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS max_reentry_attempts INTEGER NOT NULL DEFAULT 2,
    ADD COLUMN IF NOT EXISTS browser_info TEXT,
    ADD COLUMN IF NOT EXISTS device_info JSONB NOT NULL DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS disconnected_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS terminated_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS terminated_reason TEXT,
    ADD COLUMN IF NOT EXISTS face_detected_count INTEGER DEFAULT 1;

-- Backfill canonical monitoring_status safely on existing rows where default applied
UPDATE public.exam_sessions
SET monitoring_status = CASE
    WHEN LOWER(COALESCE(status, '')) = 'terminated' THEN 'TERMINATED'
    WHEN LOWER(COALESCE(status, '')) = 'suspended' THEN 'TERMINATED'
    WHEN LOWER(COALESCE(status, '')) IN ('completed', 'submitted') THEN 'SUBMITTED'
    WHEN LOWER(COALESCE(status, '')) = 'auto_submitted' THEN 'AUTO_SUBMITTED'
    WHEN COALESCE(is_paused, FALSE) = TRUE THEN 'PAUSED'
    WHEN COALESCE(is_online, TRUE) = FALSE THEN 'DISCONNECTED'
    WHEN COALESCE(warnings_count, 0) >= 3 THEN 'VIOLATION'
    WHEN COALESCE(warnings_count, 0) > 0 THEN 'WARNING'
    ELSE 'ACTIVE'
END
WHERE monitoring_status = 'ACTIVE'
  AND (
    LOWER(COALESCE(status, '')) IN ('terminated', 'suspended', 'completed', 'submitted', 'auto_submitted')
    OR COALESCE(is_paused, FALSE) = TRUE
    OR COALESCE(is_online, TRUE) = FALSE
    OR COALESCE(warnings_count, 0) > 0
  );

CREATE INDEX IF NOT EXISTS idx_exam_sessions_monitoring_lookup
    ON public.exam_sessions (school_id, exam_id, monitoring_status);

CREATE INDEX IF NOT EXISTS idx_exam_sessions_exam_student_started
    ON public.exam_sessions (exam_id, student_id, started_at DESC);


-- 2. Exam-wide monitoring session & configuration state
CREATE TABLE IF NOT EXISTS public.exam_monitoring_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    exam_id UUID NOT NULL UNIQUE REFERENCES public.exams(id) ON DELETE CASCADE,
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    paused_at TIMESTAMPTZ,
    paused_total_seconds INTEGER NOT NULL DEFAULT 0,
    pause_reason TEXT,
    reentry_window_open BOOLEAN NOT NULL DEFAULT TRUE,
    extended_minutes INTEGER NOT NULL DEFAULT 0,
    livekit_room_name TEXT,
    auto_flag_tab_switch_threshold INTEGER NOT NULL DEFAULT 3,
    auto_flag_fullscreen_threshold INTEGER NOT NULL DEFAULT 2,
    heartbeat_timeout_seconds INTEGER NOT NULL DEFAULT 25,
    default_max_reentry_attempts INTEGER NOT NULL DEFAULT 2,
    monitoring_settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    started_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_exam_monitoring_sessions_school_exam
    ON public.exam_monitoring_sessions (school_id, exam_id);


-- 3. Relational proctoring violations & incident log
CREATE TABLE IF NOT EXISTS public.exam_incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    session_id UUID REFERENCES public.exam_sessions(id) ON DELETE SET NULL,
    candidate_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    violation_type VARCHAR(60) NOT NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'medium',
    title TEXT NOT NULL,
    description TEXT,
    detection_source VARCHAR(40) NOT NULL DEFAULT 'browser',
    status VARCHAR(30) NOT NULL DEFAULT 'open',
    duration_seconds INTEGER NOT NULL DEFAULT 0,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    assigned_to UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    escalated_to UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    resolved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    resolved_at TIMESTAMPTZ,
    resolution_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_exam_incidents_exam_occurred
    ON public.exam_incidents (school_id, exam_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_exam_incidents_candidate_status
    ON public.exam_incidents (exam_id, candidate_id, status);

CREATE INDEX IF NOT EXISTS idx_exam_incidents_severity_type
    ON public.exam_incidents (exam_id, severity, violation_type);


-- 4. Invigilator & exam-wide intervention audit trail
CREATE TABLE IF NOT EXISTS public.invigilator_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    session_id UUID REFERENCES public.exam_sessions(id) ON DELETE SET NULL,
    candidate_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    actor_name TEXT,
    actor_role TEXT,
    action_type VARCHAR(50) NOT NULL,
    scope VARCHAR(20) NOT NULL DEFAULT 'candidate',
    reason TEXT,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    idempotency_key VARCHAR(120),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_invigilator_actions_exam_created
    ON public.invigilator_actions (school_id, exam_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_invigilator_actions_candidate
    ON public.invigilator_actions (exam_id, candidate_id, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS uq_invigilator_actions_idempotency
    ON public.invigilator_actions (exam_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;


-- 5. Candidate re-entry approval workflow
CREATE TABLE IF NOT EXISTS public.candidate_reentry_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES public.exam_sessions(id) ON DELETE CASCADE,
    candidate_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status VARCHAR(30) NOT NULL DEFAULT 'pending',
    reason TEXT,
    disconnect_reason TEXT,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    review_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reentry_requests_exam_status
    ON public.candidate_reentry_requests (school_id, exam_id, status, requested_at DESC);


-- 6. Explicit time extension ledger
CREATE TABLE IF NOT EXISTS public.candidate_time_adjustments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES public.exam_sessions(id) ON DELETE CASCADE,
    candidate_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    minutes_added INTEGER NOT NULL CHECK (minutes_added BETWEEN 1 AND 180),
    reason TEXT NOT NULL,
    granted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    granted_by_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_time_adjustments_session
    ON public.candidate_time_adjustments (school_id, exam_id, session_id, created_at DESC);


-- 7. Live Examination Announcements & Read Acknowledgements
CREATE TABLE IF NOT EXISTS public.exam_announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    priority VARCHAR(20) NOT NULL DEFAULT 'normal',
    target_scope VARCHAR(30) NOT NULL DEFAULT 'all',
    target_candidate_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    requires_acknowledgement BOOLEAN NOT NULL DEFAULT FALSE,
    sent_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    sent_by_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_exam_announcements_exam_created
    ON public.exam_announcements (school_id, exam_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.exam_announcement_recipients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    announcement_id UUID NOT NULL REFERENCES public.exam_announcements(id) ON DELETE CASCADE,
    exam_id UUID NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
    candidate_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    delivered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    acknowledged_at TIMESTAMPTZ,
    UNIQUE (announcement_id, candidate_id)
);

CREATE INDEX IF NOT EXISTS idx_exam_announcement_recipients_candidate
    ON public.exam_announcement_recipients (exam_id, candidate_id, acknowledged_at);


-- 8. Attach updated_at triggers safely
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'auto_set_updated_at') THEN
        DROP TRIGGER IF EXISTS trg_auto_updated_at ON public.exam_monitoring_sessions;
        CREATE TRIGGER trg_auto_updated_at BEFORE UPDATE ON public.exam_monitoring_sessions
            FOR EACH ROW EXECUTE FUNCTION public.auto_set_updated_at();

        DROP TRIGGER IF EXISTS trg_auto_updated_at ON public.exam_incidents;
        CREATE TRIGGER trg_auto_updated_at BEFORE UPDATE ON public.exam_incidents
            FOR EACH ROW EXECUTE FUNCTION public.auto_set_updated_at();

        DROP TRIGGER IF EXISTS trg_auto_updated_at ON public.candidate_reentry_requests;
        CREATE TRIGGER trg_auto_updated_at BEFORE UPDATE ON public.candidate_reentry_requests
            FOR EACH ROW EXECUTE FUNCTION public.auto_set_updated_at();
    END IF;
END $$;


-- 9. Enable Row Level Security & tenant policies
ALTER TABLE public.exam_monitoring_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invigilator_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.candidate_reentry_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.candidate_time_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_announcement_recipients ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
    v_tbl TEXT;
BEGIN
    FOREACH v_tbl IN ARRAY ARRAY[
        'exam_monitoring_sessions',
        'exam_incidents',
        'invigilator_actions',
        'candidate_reentry_requests',
        'candidate_time_adjustments',
        'exam_announcements',
        'exam_announcement_recipients'
    ]
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS school_isolation_%I ON public.%I;', v_tbl, v_tbl);
        IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_user_school_id') THEN
            EXECUTE format(
                'CREATE POLICY school_isolation_%I ON public.%I USING (school_id = public.get_user_school_id());',
                v_tbl, v_tbl
            );
        ELSE
            EXECUTE format(
                'CREATE POLICY school_isolation_%I ON public.%I USING (TRUE);',
                v_tbl, v_tbl
            );
        END IF;
    END LOOP;
END $$;

