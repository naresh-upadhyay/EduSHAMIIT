-- Migration: 207_add_user_activity_and_audit_columns.sql
-- Description: Add created_by, updated_by, created_at, and updated_at user activity audit fields across all database tables.

DO $$
DECLARE
  tbl TEXT;
  active_tables TEXT[] := ARRAY['achievements', 'ai_chat_history', 'ai_insights', 'ai_predictions', 'ai_recommendations', 'api_gateway_configs', 'api_request_logs', 'app_roles', 'attendance', 'audit_logs', 'blocked_users', 'call_sessions', 'contact_queries', 'content_distributions', 'course_chapters', 'course_topics', 'courses', 'documents', 'driver_assignments', 'driver_documents', 'driver_performance', 'driver_training', 'driver_violations', 'drivers', 'emergency_alerts', 'emergency_contacts', 'event_registrations', 'events', 'exam_questions', 'exam_sessions', 'exam_submissions', 'exams', 'fees', 'gps_devices', 'grading_policies', 'group_members', 'groups', 'homework', 'homework_submissions', 'infra_alerts', 'infra_school_metrics', 'infra_servers', 'infra_services', 'iot_control_log', 'iot_device_states', 'iot_devices', 'iot_scheduled_actions', 'it_support_ticket_attachments', 'it_support_ticket_messages', 'it_support_tickets', 'knowledge_base', 'leave_applications', 'library_books', 'library_borrows', 'library_requests', 'live_class_attendance', 'live_class_chapters', 'live_class_chats', 'live_class_comments', 'live_class_likes', 'live_class_notes', 'live_class_participants', 'live_class_ratings', 'live_class_recordings', 'live_class_resources', 'live_classes', 'messages', 'module_categories', 'module_requests', 'modules', 'notice_registrations', 'notices', 'notifications', 'password_resets', 'payments', 'profiles', 'question_bank', 'results', 'salary', 'salary_advances', 'school_mail_subscriptions', 'school_payment_configs', 'schools', 'student_achievements', 'student_topic_progress', 'student_transport', 'student_trip_logs', 'study_materials', 'subjects', 'subscription_plans', 'system_configurations', 'timetable', 'transport_route_stops', 'transport_routes', 'trip_stop_logs', 'user_active_sessions', 'user_documents', 'user_settings', 'vault_secret_metadata', 'vault_secret_versions', 'vehicle_categories', 'vehicle_documents', 'vehicle_insurance_fitness', 'vehicle_live_alerts', 'vehicle_maintenance', 'vehicle_trips', 'vehicles', 'xp_transactions'];
BEGIN
  FOREACH tbl IN ARRAY active_tables
  LOOP
    -- 1. Add created_by
    EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;', tbl);

    -- 2. Add updated_by
    EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;', tbl);

    -- 3. Add created_at
    EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();', tbl);

    -- 4. Add updated_at
    EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();', tbl);

    -- 5. Add B-Tree Indexes for created_by and updated_by
    EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON public.%I(created_by);', 'idx_' || tbl || '_created_by', tbl);
    EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON public.%I(updated_by);', 'idx_' || tbl || '_updated_by', tbl);
  END LOOP;
END $$;

-- Create Trigger Function for Automated updated_at Refresh
CREATE OR REPLACE FUNCTION public.auto_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DO $$
DECLARE
  tbl TEXT;
  active_tables TEXT[] := ARRAY['achievements', 'ai_chat_history', 'ai_insights', 'ai_predictions', 'ai_recommendations', 'api_gateway_configs', 'api_request_logs', 'app_roles', 'attendance', 'audit_logs', 'blocked_users', 'call_sessions', 'contact_queries', 'content_distributions', 'course_chapters', 'course_topics', 'courses', 'documents', 'driver_assignments', 'driver_documents', 'driver_performance', 'driver_training', 'driver_violations', 'drivers', 'emergency_alerts', 'emergency_contacts', 'event_registrations', 'events', 'exam_questions', 'exam_sessions', 'exam_submissions', 'exams', 'fees', 'gps_devices', 'grading_policies', 'group_members', 'groups', 'homework', 'homework_submissions', 'infra_alerts', 'infra_school_metrics', 'infra_servers', 'infra_services', 'iot_control_log', 'iot_device_states', 'iot_devices', 'iot_scheduled_actions', 'it_support_ticket_attachments', 'it_support_ticket_messages', 'it_support_tickets', 'knowledge_base', 'leave_applications', 'library_books', 'library_borrows', 'library_requests', 'live_class_attendance', 'live_class_chapters', 'live_class_chats', 'live_class_comments', 'live_class_likes', 'live_class_notes', 'live_class_participants', 'live_class_ratings', 'live_class_recordings', 'live_class_resources', 'live_classes', 'messages', 'module_categories', 'module_requests', 'modules', 'notice_registrations', 'notices', 'notifications', 'password_resets', 'payments', 'profiles', 'question_bank', 'results', 'salary', 'salary_advances', 'school_mail_subscriptions', 'school_payment_configs', 'schools', 'student_achievements', 'student_topic_progress', 'student_transport', 'student_trip_logs', 'study_materials', 'subjects', 'subscription_plans', 'system_configurations', 'timetable', 'transport_route_stops', 'transport_routes', 'trip_stop_logs', 'user_active_sessions', 'user_documents', 'user_settings', 'vault_secret_metadata', 'vault_secret_versions', 'vehicle_categories', 'vehicle_documents', 'vehicle_insurance_fitness', 'vehicle_live_alerts', 'vehicle_maintenance', 'vehicle_trips', 'vehicles', 'xp_transactions'];
BEGIN
  FOREACH tbl IN ARRAY active_tables
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_auto_updated_at ON public.%I;', tbl);
    EXECUTE format('CREATE TRIGGER trg_auto_updated_at BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.auto_set_updated_at();', tbl);
  END LOOP;
END $$;