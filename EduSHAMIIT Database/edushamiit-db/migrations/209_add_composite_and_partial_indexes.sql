-- Migration: 209_add_composite_and_partial_indexes.sql
-- Description: Supercharge query execution speed using targeted Composite B-Tree Indexes and Partial Indexes.

-- ──────────────────────────────────────────────
-- 1. COMPOSITE INDEXES FOR FREQUENT DUAL-COLUMN FILTERS
-- ──────────────────────────────────────────────

-- Profiles lookup by school and role
CREATE INDEX IF NOT EXISTS idx_profiles_school_role ON public.profiles(school_id, role);
CREATE INDEX IF NOT EXISTS idx_profiles_school_class ON public.profiles(school_id, class);

-- Attendance query by student/school and date
CREATE INDEX IF NOT EXISTS idx_attendance_student_date ON public.attendance(student_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_attendance_school_date ON public.attendance(school_id, date DESC);

-- Payments lookup by school and status
CREATE INDEX IF NOT EXISTS idx_payments_school_status ON public.payments(school_id, status);
CREATE INDEX IF NOT EXISTS idx_payments_student_status ON public.payments(student_id, status);

-- Homework and Submissions composite queries
CREATE INDEX IF NOT EXISTS idx_homework_school_status ON public.homework(school_id, status);
CREATE INDEX IF NOT EXISTS idx_homework_sub_hw_student ON public.homework_submissions(homework_id, student_id);

-- Timetable class lookup
CREATE INDEX IF NOT EXISTS idx_timetable_school_class ON public.timetable(school_id, class);

-- Fleet Vehicle & Trip lookup
CREATE INDEX IF NOT EXISTS idx_vehicles_school_status ON public.vehicles(school_id, status);
CREATE INDEX IF NOT EXISTS idx_vehicle_trips_vehicle_date ON public.vehicle_trips(vehicle_id, created_at DESC);


-- ──────────────────────────────────────────────
-- 2. HIGH-PERFORMANCE PARTIAL INDEXES FOR ACTIVE/UNREAD STATES
-- ──────────────────────────────────────────────

-- Fast unread notifications retrieval
CREATE INDEX IF NOT EXISTS idx_notifications_unread 
ON public.notifications(user_id, created_at DESC) 
WHERE is_read = FALSE;

-- Fast absent attendance reporting
CREATE INDEX IF NOT EXISTS idx_attendance_absent_only 
ON public.attendance(school_id, date DESC) 
WHERE LOWER(status) = 'absent';

-- Fast active homework assignment retrieval
CREATE INDEX IF NOT EXISTS idx_homework_active 
ON public.homework(school_id, created_at DESC) 
WHERE LOWER(status) = 'active';

-- Fast pending payments retrieval
CREATE INDEX IF NOT EXISTS idx_payments_pending 
ON public.payments(school_id, student_id) 
WHERE LOWER(status) = 'pending';
