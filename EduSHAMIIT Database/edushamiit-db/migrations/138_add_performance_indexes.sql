-- ============================================================
-- Migration 138: Add Performance Indexes
-- Based on analysis of common API query patterns
-- ============================================================

-- Messages: fast unread count & recipient inbox queries
DROP INDEX IF EXISTS idx_messages_receiver_filtered;
CREATE INDEX IF NOT EXISTS idx_messages_receiver_filtered
    ON messages(recipient_id, is_read, created_at DESC);

-- Notifications: fast unread count & user notification list
DROP INDEX IF EXISTS idx_notifications_user_filtered;
CREATE INDEX IF NOT EXISTS idx_notifications_user_filtered
    ON notifications(user_id, is_read, created_at DESC);

-- Exams: filtered by school + class + subject (common search pattern)
DROP INDEX IF EXISTS idx_exams_school_class_subject;
CREATE INDEX IF NOT EXISTS idx_exams_school_class_subject
    ON exams(school_id, class_id, subject_id);

-- Live classes: school + status + recency for dashboard
DROP INDEX IF EXISTS idx_live_classes_school_status_time;
CREATE INDEX IF NOT EXISTS idx_live_classes_school_status_time
    ON live_classes(school_id, status, created_at DESC);

-- AI Chat history: session-based lookups
DROP INDEX IF EXISTS idx_ai_chat_session;
CREATE INDEX IF NOT EXISTS idx_ai_chat_session
    ON ai_chat_history(user_id, session_id, created_at DESC);

-- Documents: school + folder hierarchy navigation
DROP INDEX IF EXISTS idx_documents_school_folder;
CREATE INDEX IF NOT EXISTS idx_documents_school_folder
    ON documents(school_id, folder_id);

-- XP Transactions: student activity timeline & totals
DROP INDEX IF EXISTS idx_xp_transactions_student_time;
CREATE INDEX IF NOT EXISTS idx_xp_transactions_student_time
    ON xp_transactions(student_id, created_at DESC);

-- Profiles: faster lookup by id + school_id combo
DROP INDEX IF EXISTS idx_profiles_id_school;
CREATE INDEX IF NOT EXISTS idx_profiles_id_school
    ON profiles(id, school_id);

-- Call sessions: student call history
DROP INDEX IF EXISTS idx_call_sessions_student;
CREATE INDEX IF NOT EXISTS idx_call_sessions_student
    ON call_sessions(student_id, created_at DESC);

-- Homework submissions: student submission history (for progress tracking)
DROP INDEX IF EXISTS idx_homework_sub_student_time;
CREATE INDEX IF NOT EXISTS idx_homework_sub_student_time
    ON homework_submissions(student_id, created_at DESC);

-- Course student progress: student progress tracking
DROP INDEX IF EXISTS idx_course_progress_student;
CREATE INDEX IF NOT EXISTS idx_course_progress_student
    ON course_student_progress(student_id, course_id);

-- Payments: student payment history
DROP INDEX IF EXISTS idx_payments_student_time;
CREATE INDEX IF NOT EXISTS idx_payments_student_time
    ON payments(student_id, created_at DESC);

-- Attendance: date-range queries (already has student+date, adding school+student+date)
DROP INDEX IF EXISTS idx_attendance_school_student_date;
CREATE INDEX IF NOT EXISTS idx_attendance_school_student_date
    ON attendance(school_id, student_id, date DESC);

-- Leaderboard: faster XP-based rankings
DROP INDEX IF EXISTS idx_profiles_xp_leaderboard;
CREATE INDEX IF NOT EXISTS idx_profiles_xp_leaderboard
    ON profiles(school_id, xp_points DESC, updated_at DESC);

-- Notifications: school-wide broadcast queries
DROP INDEX IF EXISTS idx_notifications_school_created;
CREATE INDEX IF NOT EXISTS idx_notifications_school_created
    ON notifications(school_id, created_at DESC);

-- Fees: due date + status for automated reminders
DROP INDEX IF EXISTS idx_fees_due_status;
CREATE INDEX IF NOT EXISTS idx_fees_due_status
    ON fees(school_id, due_date, status);

-- Salary: teacher payment history
DROP INDEX IF EXISTS idx_salary_teacher_time;
CREATE INDEX IF NOT EXISTS idx_salary_teacher_time
    ON salary(teacher_id, month DESC);