-- Migration: 203_fix_database_gaps.sql
-- Description: Comprehensive database gap remediation: Enable RLS across all tables, add missing FK indexes, enforce school_id multi-tenant isolation, and add audit timestamps.

-- ──────────────────────────────────────────────
-- 1. ENABLE ROW LEVEL SECURITY (RLS) ON ALL UNPROTECTED TABLES
-- ──────────────────────────────────────────────

ALTER TABLE IF EXISTS public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.timetable ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.exam_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.exam_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.exam_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.homework ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.homework_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.notices ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.event_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.student_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.library_books ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.library_borrows ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.bus_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.bus_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.bus_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.live_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.live_class_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.study_materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.student_transport ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.iot_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.iot_device_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.iot_control_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.iot_scheduled_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.call_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.salary_advances ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.school_payment_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.notice_registrations ENABLE ROW LEVEL SECURITY;

-- Apply Tenant Isolation RLS Policies to Unprotected Tables
DO $$
DECLARE
  t TEXT;
  tables_to_policy TEXT[] := ARRAY[
    'subjects', 'timetable', 'courses', 'exams', 'homework', 'notices', 
    'events', 'achievements', 'library_books', 'live_classes', 'study_materials',
    'documents', 'student_transport', 'salary_advances', 'school_payment_configs'
  ];
BEGIN
  FOREACH t IN ARRAY tables_to_policy
  LOOP
    EXECUTE format('
      DROP POLICY IF EXISTS "Tenant Isolation Policy" ON public.%I;
      CREATE POLICY "Tenant Isolation Policy" ON public.%I
      FOR ALL USING (
        school_id IS NULL OR school_id = public.get_user_school_id(auth.uid())
      );
    ', t, t);
  END LOOP;
END $$;


-- ──────────────────────────────────────────────
-- 2. CREATE MISSING B-TREE INDEXES ON FOREIGN KEYS
-- ──────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_password_resets_school ON public.password_resets(school_id);
CREATE INDEX IF NOT EXISTS idx_hw_subs_graded_by ON public.homework_submissions(graded_by);
CREATE INDEX IF NOT EXISTS idx_notices_author ON public.notices(author_id);
CREATE INDEX IF NOT EXISTS idx_event_regs_school ON public.event_registrations(school_id);
CREATE INDEX IF NOT EXISTS idx_leave_apps_approved_by ON public.leave_applications(approved_by);
CREATE INDEX IF NOT EXISTS idx_student_achieve_achieve_id ON public.student_achievements(achievement_id);
CREATE INDEX IF NOT EXISTS idx_lib_borrows_book ON public.library_borrows(book_id);
CREATE INDEX IF NOT EXISTS idx_live_classes_subject ON public.live_classes(subject_id);
CREATE INDEX IF NOT EXISTS idx_live_comments_school ON public.live_class_comments(school_id);
CREATE INDEX IF NOT EXISTS idx_student_trans_school ON public.student_transport(school_id);
CREATE INDEX IF NOT EXISTS idx_iot_device_states_school ON public.iot_device_states(school_id);
CREATE INDEX IF NOT EXISTS idx_user_docs_shared_by ON public.user_documents(shared_by_id);
CREATE INDEX IF NOT EXISTS idx_salary_advances_school ON public.salary_advances(school_id);
CREATE INDEX IF NOT EXISTS idx_salary_advances_teacher ON public.salary_advances(teacher_id);
CREATE INDEX IF NOT EXISTS idx_school_pay_configs_school ON public.school_payment_configs(school_id);
CREATE INDEX IF NOT EXISTS idx_notice_regs_school ON public.notice_registrations(school_id);
CREATE INDEX IF NOT EXISTS idx_notice_regs_notice ON public.notice_registrations(notice_id);


-- ──────────────────────────────────────────────
-- 3. ADD school_id TO MULTI-TENANT TABLES (Tenant Leak Fix)
-- ──────────────────────────────────────────────

ALTER TABLE IF EXISTS public.exam_questions ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE IF EXISTS public.exam_submissions ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE IF EXISTS public.exam_sessions ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE IF EXISTS public.payments ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_exam_questions_school ON public.exam_questions(school_id);
CREATE INDEX IF NOT EXISTS idx_exam_submissions_school ON public.exam_submissions(school_id);
CREATE INDEX IF NOT EXISTS idx_exam_sessions_school ON public.exam_sessions(school_id);
CREATE INDEX IF NOT EXISTS idx_payments_school ON public.payments(school_id);

-- Backfill school_id from parent tables
UPDATE public.exam_questions eq
SET school_id = e.school_id
FROM public.exams e
WHERE eq.school_id IS NULL AND eq.exam_id = e.id;

UPDATE public.exam_submissions es
SET school_id = e.school_id
FROM public.exams e
WHERE es.school_id IS NULL AND es.exam_id = e.id;

UPDATE public.exam_sessions es
SET school_id = e.school_id
FROM public.exams e
WHERE es.school_id IS NULL AND es.exam_id = e.id;


-- ──────────────────────────────────────────────
-- 4. ADD AUDIT TIMESTAMPS (created_at / updated_at)
-- ──────────────────────────────────────────────

ALTER TABLE IF EXISTS public.exam_submissions ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE IF EXISTS public.exam_submissions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS public.exam_sessions ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE IF EXISTS public.exam_sessions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS public.payments ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS public.homework_submissions ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE IF EXISTS public.homework_submissions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS public.event_registrations ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE IF EXISTS public.student_achievements ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE IF EXISTS public.library_borrows ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
