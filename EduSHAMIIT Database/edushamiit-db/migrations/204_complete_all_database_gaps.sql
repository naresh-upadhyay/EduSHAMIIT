-- Migration: 204_complete_all_database_gaps.sql
-- Description: Complete 100% gap remediation: Add missing indexes across live_classes, question_bank, course_chapters, audit_logs, support_tickets, emergency alerts, vehicles, add school_id multi-tenant isolation, and timestamp audit columns.

-- ──────────────────────────────────────────────
-- 1. ADD B-TREE INDEXES ON ALL REMAINING FOREIGN KEYS
-- ──────────────────────────────────────────────

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'bus_stops') THEN
    CREATE INDEX IF NOT EXISTS idx_bus_stops_school ON public.bus_stops(school_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'library_requests') THEN
    CREATE INDEX IF NOT EXISTS idx_lib_req_school ON public.library_requests(school_id);
    CREATE INDEX IF NOT EXISTS idx_lib_req_student ON public.library_requests(student_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notice_registrations') THEN
    CREATE INDEX IF NOT EXISTS idx_notice_regs_student ON public.notice_registrations(student_id);
  END IF;
END $$;

-- Live Classes Sub-tables Indexes
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_participants') THEN
    CREATE INDEX IF NOT EXISTS idx_lc_part_lc_id ON public.live_class_participants(live_class_id);
    CREATE INDEX IF NOT EXISTS idx_lc_part_user_id ON public.live_class_participants(user_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_attendance') THEN
    CREATE INDEX IF NOT EXISTS idx_lc_att_lc_id ON public.live_class_attendance(live_class_id);
    CREATE INDEX IF NOT EXISTS idx_lc_att_student_id ON public.live_class_attendance(student_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_chats') THEN
    CREATE INDEX IF NOT EXISTS idx_lc_chats_lc_id ON public.live_class_chats(live_class_id);
    CREATE INDEX IF NOT EXISTS idx_lc_chats_sender_id ON public.live_class_chats(sender_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_recordings') THEN
    CREATE INDEX IF NOT EXISTS idx_lc_rec_lc_id ON public.live_class_recordings(live_class_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_likes') THEN
    CREATE INDEX IF NOT EXISTS idx_lc_likes_lc_id ON public.live_class_likes(live_class_id);
    CREATE INDEX IF NOT EXISTS idx_lc_likes_user_id ON public.live_class_likes(user_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_ratings') THEN
    CREATE INDEX IF NOT EXISTS idx_lc_ratings_lc_id ON public.live_class_ratings(live_class_id);
    CREATE INDEX IF NOT EXISTS idx_lc_ratings_user_id ON public.live_class_ratings(user_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_chapters') THEN
    CREATE INDEX IF NOT EXISTS idx_lc_chap_school ON public.live_class_chapters(school_id);
    CREATE INDEX IF NOT EXISTS idx_lc_chap_lc_id ON public.live_class_chapters(live_class_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_resources') THEN
    CREATE INDEX IF NOT EXISTS idx_lc_res_school ON public.live_class_resources(school_id);
    CREATE INDEX IF NOT EXISTS idx_lc_res_lc_id ON public.live_class_resources(live_class_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_notes') THEN
    CREATE INDEX IF NOT EXISTS idx_lc_notes_school ON public.live_class_notes(school_id);
    CREATE INDEX IF NOT EXISTS idx_lc_notes_lc_id ON public.live_class_notes(live_class_id);
    CREATE INDEX IF NOT EXISTS idx_lc_notes_user_id ON public.live_class_notes(user_id);
  END IF;
END $$;

-- Academic LMS Sub-tables Indexes
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'question_bank') THEN
    CREATE INDEX IF NOT EXISTS idx_qb_school ON public.question_bank(school_id);
    CREATE INDEX IF NOT EXISTS idx_qb_teacher ON public.question_bank(teacher_id);
    CREATE INDEX IF NOT EXISTS idx_qb_subject ON public.question_bank(subject_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'course_chapters') THEN
    CREATE INDEX IF NOT EXISTS idx_c_chap_school ON public.course_chapters(school_id);
    CREATE INDEX IF NOT EXISTS idx_c_chap_course ON public.course_chapters(course_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'course_topics') THEN
    CREATE INDEX IF NOT EXISTS idx_c_top_school ON public.course_topics(school_id);
    CREATE INDEX IF NOT EXISTS idx_c_top_chapter ON public.course_topics(chapter_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'student_topic_progress') THEN
    CREATE INDEX IF NOT EXISTS idx_stp_school ON public.student_topic_progress(school_id);
    CREATE INDEX IF NOT EXISTS idx_stp_student ON public.student_topic_progress(student_id);
    CREATE INDEX IF NOT EXISTS idx_stp_topic ON public.student_topic_progress(topic_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'xp_transactions') THEN
    CREATE INDEX IF NOT EXISTS idx_xp_trans_school ON public.xp_transactions(school_id);
  END IF;
END $$;

-- Groups, Fleet, Emergency & Support Indexes
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'group_members') THEN
    CREATE INDEX IF NOT EXISTS idx_grp_mem_group_id ON public.group_members(group_id);
    CREATE INDEX IF NOT EXISTS idx_grp_mem_member_id ON public.group_members(member_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'blocked_users') THEN
    CREATE INDEX IF NOT EXISTS idx_block_users_blocker ON public.blocked_users(blocker_id);
    CREATE INDEX IF NOT EXISTS idx_block_users_blocked ON public.blocked_users(blocked_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'ai_chat_history') THEN
    CREATE INDEX IF NOT EXISTS idx_ai_chat_hist_user ON public.ai_chat_history(user_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'school_mail_subscriptions') THEN
    CREATE INDEX IF NOT EXISTS idx_mail_sub_school ON public.school_mail_subscriptions(school_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'audit_logs') THEN
    CREATE INDEX IF NOT EXISTS idx_audit_logs_school ON public.audit_logs(school_id);
    CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON public.audit_logs(user_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'it_support_tickets') THEN
    CREATE INDEX IF NOT EXISTS idx_it_tickets_school ON public.it_support_tickets(school_id);
    CREATE INDEX IF NOT EXISTS idx_it_tickets_req ON public.it_support_tickets(requested_by_id);
    CREATE INDEX IF NOT EXISTS idx_it_tickets_assign ON public.it_support_tickets(assigned_to_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'it_support_ticket_messages') THEN
    CREATE INDEX IF NOT EXISTS idx_it_msg_ticket ON public.it_support_ticket_messages(ticket_id);
    CREATE INDEX IF NOT EXISTS idx_it_msg_sender ON public.it_support_ticket_messages(sender_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'it_support_ticket_attachments') THEN
    CREATE INDEX IF NOT EXISTS idx_it_att_ticket ON public.it_support_ticket_attachments(ticket_id);
    CREATE INDEX IF NOT EXISTS idx_it_att_uploader ON public.it_support_ticket_attachments(uploaded_by);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vehicle_live_alerts') THEN
    CREATE INDEX IF NOT EXISTS idx_veh_alerts_trip ON public.vehicle_live_alerts(trip_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vehicle_documents') THEN
    CREATE INDEX IF NOT EXISTS idx_veh_docs_school ON public.vehicle_documents(school_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vehicle_insurance_fitness') THEN
    CREATE INDEX IF NOT EXISTS idx_veh_ins_school ON public.vehicle_insurance_fitness(school_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'gps_devices') THEN
    CREATE INDEX IF NOT EXISTS idx_gps_dev_school ON public.gps_devices(school_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'driver_assignments') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'driver_assignments' AND column_name = 'vehicle_id') THEN
      CREATE INDEX IF NOT EXISTS idx_drv_assign_veh ON public.driver_assignments(vehicle_id);
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'driver_assignments' AND column_name = 'route_id') THEN
      CREATE INDEX IF NOT EXISTS idx_drv_assign_route ON public.driver_assignments(route_id);
    END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'driver_violations') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'driver_violations' AND column_name = 'vehicle_id') THEN
      CREATE INDEX IF NOT EXISTS idx_drv_viol_veh ON public.driver_violations(vehicle_id);
    END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'student_trip_logs') THEN
    CREATE INDEX IF NOT EXISTS idx_stu_trip_log_school ON public.student_trip_logs(school_id);
    CREATE INDEX IF NOT EXISTS idx_stu_trip_log_stop ON public.student_trip_logs(stop_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trip_stop_logs') THEN
    CREATE INDEX IF NOT EXISTS idx_trip_stop_log_school ON public.trip_stop_logs(school_id);
    CREATE INDEX IF NOT EXISTS idx_trip_stop_log_stop ON public.trip_stop_logs(stop_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vehicles') THEN
    CREATE INDEX IF NOT EXISTS idx_vehicles_category ON public.vehicles(category_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'emergency_alerts') THEN
    CREATE INDEX IF NOT EXISTS idx_emg_alerts_school ON public.emergency_alerts(school_id);
    CREATE INDEX IF NOT EXISTS idx_emg_alerts_user ON public.emergency_alerts(user_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'emergency_contacts') THEN
    CREATE INDEX IF NOT EXISTS idx_emg_contacts_school ON public.emergency_contacts(school_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vault_secret_metadata') THEN
    CREATE INDEX IF NOT EXISTS idx_vault_meta_secret ON public.vault_secret_metadata(secret_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vault_secret_versions') THEN
    CREATE INDEX IF NOT EXISTS idx_vault_ver_secret ON public.vault_secret_versions(secret_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'announcements') THEN
    CREATE INDEX IF NOT EXISTS idx_announcements_school ON public.announcements(school_id);
    CREATE INDEX IF NOT EXISTS idx_announcements_creator ON public.announcements(created_by_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'system_alerts') THEN
    CREATE INDEX IF NOT EXISTS idx_system_alerts_creator ON public.system_alerts(created_by);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'module_requests') THEN
    CREATE INDEX IF NOT EXISTS idx_mod_req_mod ON public.module_requests(module_id);
    CREATE INDEX IF NOT EXISTS idx_mod_req_school ON public.module_requests(school_id);
  END IF;
END $$;


-- ──────────────────────────────────────────────
-- 2. ADD school_id TO ALL REMAINING MULTI-TENANT TABLES
-- ──────────────────────────────────────────────

ALTER TABLE IF EXISTS public.ai_chat_history ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE IF EXISTS public.group_members ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE IF EXISTS public.blocked_users ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE IF EXISTS public.live_class_participants ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE IF EXISTS public.live_class_attendance ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE IF EXISTS public.live_class_chats ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE IF EXISTS public.live_class_recordings ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE IF EXISTS public.live_class_likes ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
ALTER TABLE IF EXISTS public.live_class_ratings ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'ai_chat_history') THEN
    CREATE INDEX IF NOT EXISTS idx_ai_chat_hist_school ON public.ai_chat_history(school_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'group_members') THEN
    CREATE INDEX IF NOT EXISTS idx_group_mem_school ON public.group_members(school_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'blocked_users') THEN
    CREATE INDEX IF NOT EXISTS idx_blocked_users_school ON public.blocked_users(school_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_participants') THEN
    CREATE INDEX IF NOT EXISTS idx_lc_part_school ON public.live_class_participants(school_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_attendance') THEN
    CREATE INDEX IF NOT EXISTS idx_lc_att_school ON public.live_class_attendance(school_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_chats') THEN
    CREATE INDEX IF NOT EXISTS idx_lc_chats_school ON public.live_class_chats(school_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_recordings') THEN
    CREATE INDEX IF NOT EXISTS idx_lc_rec_school ON public.live_class_recordings(school_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_likes') THEN
    CREATE INDEX IF NOT EXISTS idx_lc_likes_school ON public.live_class_likes(school_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_ratings') THEN
    CREATE INDEX IF NOT EXISTS idx_lc_ratings_school ON public.live_class_ratings(school_id);
  END IF;
END $$;

-- Backfill school_id from user profiles or parent tables
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'ai_chat_history') THEN
    UPDATE public.ai_chat_history ac
    SET school_id = p.school_id
    FROM public.profiles p
    WHERE ac.school_id IS NULL AND ac.user_id = p.id;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_participants') THEN
    UPDATE public.live_class_participants lcp
    SET school_id = lc.school_id
    FROM public.live_classes lc
    WHERE lcp.school_id IS NULL AND lcp.live_class_id = lc.id;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_attendance') THEN
    UPDATE public.live_class_attendance lca
    SET school_id = lc.school_id
    FROM public.live_classes lc
    WHERE lca.school_id IS NULL AND lca.live_class_id = lc.id;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_chats') THEN
    UPDATE public.live_class_chats lcc
    SET school_id = lc.school_id
    FROM public.live_classes lc
    WHERE lcc.school_id IS NULL AND lcc.live_class_id = lc.id;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'live_class_recordings') THEN
    UPDATE public.live_class_recordings lcr
    SET school_id = lc.school_id
    FROM public.live_classes lc
    WHERE lcr.school_id IS NULL AND lcr.live_class_id = lc.id;
  END IF;
END $$;


-- ──────────────────────────────────────────────
-- 3. AUDIT TIMESTAMPS ON ALL REMAINING TABLES
-- ──────────────────────────────────────────────

ALTER TABLE IF EXISTS public.bus_routes ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE IF EXISTS public.bus_routes ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS public.bus_stops ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE IF EXISTS public.bus_stops ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS public.bus_locations ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS public.documents ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE IF EXISTS public.documents ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS public.student_transport ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS public.iot_devices ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS public.group_members ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();


-- ──────────────────────────────────────────────
-- 4. ENABLE RLS & TENANT POLICIES ON REMAINING TABLES
-- ──────────────────────────────────────────────

ALTER TABLE IF EXISTS public.ai_chat_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.blocked_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.live_class_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.live_class_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.live_class_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.live_class_recordings ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.live_class_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.live_class_ratings ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  t TEXT;
  rem_tables TEXT[] := ARRAY[
    'ai_chat_history', 'group_members', 'blocked_users', 'live_class_participants',
    'live_class_attendance', 'live_class_chats', 'live_class_recordings',
    'live_class_likes', 'live_class_ratings'
  ];
BEGIN
  FOREACH t IN ARRAY rem_tables
  LOOP
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = t) THEN
      EXECUTE format('
        DROP POLICY IF EXISTS "Tenant Isolation Policy" ON public.%I;
        CREATE POLICY "Tenant Isolation Policy" ON public.%I
        FOR ALL USING (
          school_id IS NULL OR school_id = public.get_user_school_id(auth.uid())
        );
      ', t, t);
    END IF;
  END LOOP;
END $$;
