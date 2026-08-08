-- ============================================================================
-- Migration 224: Universal Calendar, Timetable, and Scheduling Engine
-- Multi-tenant, enterprise-grade scheduling system with recurrence, assignments,
-- resource reservations, conflict detection, RSVP, reminders, and audit trail.
-- ============================================================================

-- 1. CALENDARS TABLE
CREATE TABLE IF NOT EXISTS public.calendars (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  color TEXT DEFAULT '#4F46E5',
  type TEXT DEFAULT 'personal', -- 'personal', 'academic', 'transport', 'hr', 'department', 'school_events', 'custom'
  is_system BOOLEAN DEFAULT FALSE,
  is_default BOOLEAN DEFAULT FALSE,
  is_archived BOOLEAN DEFAULT FALSE,
  owner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  visibility TEXT DEFAULT 'shared', -- 'private', 'shared', 'institution_wide', 'department_wide', 'role_wide', 'public'
  default_view TEXT DEFAULT 'week', -- 'day', '3day', 'week', 'month', 'agenda', 'timeline'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- 2. CALENDAR MEMBERS & PERMISSIONS
CREATE TABLE IF NOT EXISTS public.calendar_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  calendar_id UUID NOT NULL REFERENCES public.calendars(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  role_name TEXT,
  department TEXT,
  permission TEXT DEFAULT 'view_details', -- 'view_only', 'view_details', 'create_events', 'edit_events', 'delete_events', 'share_calendar', 'manage_calendar'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(calendar_id, user_id)
);

-- 3. SCHEDULE EVENT TYPES
CREATE TABLE IF NOT EXISTS public.schedule_event_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT NOT NULL, -- 'meeting', 'class', 'exam', 'assignment', 'training', 'trip', 'bus_route', 'pickup', 'drop', 'appointment', 'interview', 'holiday', 'leave', 'reminder', 'maintenance', 'task', 'school_event', 'custom'
  color TEXT DEFAULT '#4F46E5',
  icon TEXT DEFAULT 'event',
  requires_approval BOOLEAN DEFAULT FALSE,
  is_system BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. UNIVERSAL SCHEDULES
CREATE TABLE IF NOT EXISTS public.schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  calendar_id UUID NOT NULL REFERENCES public.calendars(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  schedule_type TEXT NOT NULL, -- 'Meeting', 'Class', 'Exam', 'Task', 'Reminder', 'Training', 'Trip', 'Bus Route', 'Leave', 'Holiday', etc.
  category TEXT DEFAULT 'General',
  color TEXT DEFAULT '#4F46E5',
  priority TEXT DEFAULT 'normal', -- 'low', 'normal', 'high', 'urgent'
  status TEXT DEFAULT 'scheduled', -- 'draft', 'scheduled', 'confirmed', 'pending', 'in_progress', 'completed', 'cancelled', 'declined', 'rescheduled', 'archived'
  approval_status TEXT DEFAULT 'not_required', -- 'not_required', 'pending', 'approved', 'rejected', 'changes_requested'
  approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  approved_at TIMESTAMPTZ,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  is_all_day BOOLEAN DEFAULT FALSE,
  timezone TEXT DEFAULT 'Asia/Kolkata',
  location_name TEXT,
  location_address TEXT,
  building TEXT,
  room TEXT,
  landmark TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  virtual_meeting_url TEXT,
  virtual_meeting_provider TEXT, -- 'google_meet', 'zoom', 'teams', 'custom'
  organizer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  visibility TEXT DEFAULT 'shared', -- 'private', 'shared', 'institution_wide', 'department_wide', 'role_wide', 'public', 'busy_only'
  is_recurring BOOLEAN DEFAULT FALSE,
  parent_schedule_id UUID REFERENCES public.schedules(id) ON DELETE SET NULL,
  original_start_time TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- 5. SCHEDULE RECURRENCE RULES
CREATE TABLE IF NOT EXISTS public.schedule_recurrence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES public.schedules(id) ON DELETE CASCADE,
  frequency TEXT NOT NULL, -- 'daily', 'weekly', 'monthly', 'yearly', 'custom'
  interval INT DEFAULT 1,
  days_of_week JSONB DEFAULT '[]'::jsonb, -- e.g. ["MO", "WE", "FR"]
  day_of_month INT,
  month_of_year INT,
  end_type TEXT DEFAULT 'never', -- 'never', 'after_count', 'until_date'
  end_count INT,
  end_date DATE,
  exceptions JSONB DEFAULT '[]'::jsonb, -- ISO timestamps of deleted or modified single instances
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. SCHEDULE PARTICIPANTS & ASSIGNMENTS
CREATE TABLE IF NOT EXISTS public.schedule_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES public.schedules(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_role TEXT,
  target_department TEXT,
  target_class TEXT,
  target_section TEXT,
  participant_type TEXT DEFAULT 'individual', -- 'individual', 'role', 'department', 'class_section', 'institution'
  participation_role TEXT DEFAULT 'required', -- 'required', 'optional', 'fyi'
  permission TEXT DEFAULT 'can_view', -- 'can_view', 'can_edit', 'can_invite', 'can_manage'
  rsvp_status TEXT DEFAULT 'pending', -- 'pending', 'accepted', 'declined', 'tentative'
  decline_reason TEXT,
  rsvp_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. CALENDAR RESOURCES (Rooms, Buses, Labs, Equipment)
CREATE TABLE IF NOT EXISTS public.calendar_resources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT NOT NULL,
  type TEXT NOT NULL, -- 'classroom', 'lab', 'auditorium', 'bus', 'vehicle', 'meeting_room', 'projector', 'computer_lab', 'sports_ground'
  capacity INT DEFAULT 1,
  building TEXT,
  room_number TEXT,
  is_exclusive BOOLEAN DEFAULT TRUE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. RESOURCE BOOKINGS
CREATE TABLE IF NOT EXISTS public.resource_bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES public.schedules(id) ON DELETE CASCADE,
  resource_id UUID NOT NULL REFERENCES public.calendar_resources(id) ON DELETE CASCADE,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  status TEXT DEFAULT 'confirmed', -- 'pending', 'confirmed', 'released', 'cancelled'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. SCHEDULE REMINDERS
CREATE TABLE IF NOT EXISTS public.schedule_reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES public.schedules(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  minutes_before INT NOT NULL, -- 0 (at time), 5, 10, 15, 30, 60, 1440 (1 day), etc.
  channel TEXT DEFAULT 'in_app', -- 'in_app', 'email', 'push', 'sms_whatsapp'
  is_sent BOOLEAN DEFAULT FALSE,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. SCHEDULE ATTACHMENTS
CREATE TABLE IF NOT EXISTS public.schedule_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES public.schedules(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_url TEXT NOT NULL,
  file_type TEXT,
  file_size INT DEFAULT 0,
  uploaded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. SCHEDULE COMMENTS & ACTIVITY
CREATE TABLE IF NOT EXISTS public.schedule_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES public.schedules(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  comment_text TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. SCHEDULE REVISIONS & VERSION HISTORY
CREATE TABLE IF NOT EXISTS public.schedule_revisions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id UUID NOT NULL REFERENCES public.schedules(id) ON DELETE CASCADE,
  version INT NOT NULL,
  changed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  change_summary TEXT NOT NULL,
  diff_data JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR HIGH PERFORMANCE
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_calendars_school_owner ON public.calendars(school_id, owner_id);
CREATE INDEX IF NOT EXISTS idx_calendars_type ON public.calendars(type);
CREATE INDEX IF NOT EXISTS idx_calendar_members_user ON public.calendar_members(user_id, calendar_id);

CREATE INDEX IF NOT EXISTS idx_schedules_school_timerange ON public.schedules(school_id, start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_schedules_calendar_timerange ON public.schedules(calendar_id, start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_schedules_created_by ON public.schedules(created_by);
CREATE INDEX IF NOT EXISTS idx_schedules_organizer ON public.schedules(organizer_id);
CREATE INDEX IF NOT EXISTS idx_schedules_status ON public.schedules(status);
CREATE INDEX IF NOT EXISTS idx_schedules_schedule_type ON public.schedules(schedule_type);
CREATE INDEX IF NOT EXISTS idx_schedules_deleted_at ON public.schedules(deleted_at);

CREATE INDEX IF NOT EXISTS idx_schedule_recurrence_schedule ON public.schedule_recurrence(schedule_id);
CREATE INDEX IF NOT EXISTS idx_schedule_participants_user_schedule ON public.schedule_participants(user_id, schedule_id);
CREATE INDEX IF NOT EXISTS idx_schedule_participants_role_dept ON public.schedule_participants(target_role, target_department);

CREATE INDEX IF NOT EXISTS idx_resource_bookings_resource_timerange ON public.resource_bookings(resource_id, start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_resource_bookings_schedule ON public.resource_bookings(schedule_id);

CREATE INDEX IF NOT EXISTS idx_schedule_reminders_user ON public.schedule_reminders(user_id, is_sent);
CREATE INDEX IF NOT EXISTS idx_schedule_comments_schedule ON public.schedule_comments(schedule_id);
CREATE INDEX IF NOT EXISTS idx_schedule_revisions_schedule ON public.schedule_revisions(schedule_id, version);

-- ============================================================================
-- SEED EVENT TYPES (SYSTEM DEFAULTS)
-- ============================================================================

INSERT INTO public.schedule_event_types (name, code, color, icon, requires_approval, is_system)
VALUES
  ('Meeting', 'meeting', '#4F46E5', 'groups', FALSE, TRUE),
  ('Class', 'class', '#10B981', 'school', FALSE, TRUE),
  ('Exam', 'exam', '#EF4444', 'assignment_turned_in', TRUE, TRUE),
  ('Task', 'task', '#06B6D4', 'check_circle', FALSE, TRUE),
  ('Reminder', 'reminder', '#F59E0B', 'notifications', FALSE, TRUE),
  ('Training', 'training', '#8B5CF6', 'model_training', FALSE, TRUE),
  ('Trip', 'trip', '#10B981', 'directions_bus', TRUE, TRUE),
  ('Bus Route', 'bus_route', '#3B82F6', 'alt_route', FALSE, TRUE),
  ('Pickup', 'pickup', '#059669', 'transfer_within_a_station', FALSE, TRUE),
  ('Drop', 'drop', '#D97706', 'departure_board', FALSE, TRUE),
  ('Appointment', 'appointment', '#6366F1', 'event_available', FALSE, TRUE),
  ('Interview', 'interview', '#EC4899', 'badge', FALSE, TRUE),
  ('Holiday', 'holiday', '#EF4444', 'celebration', FALSE, TRUE),
  ('Leave', 'leave', '#64748B', 'event_busy', TRUE, TRUE),
  ('Maintenance', 'maintenance', '#F97316', 'build', FALSE, TRUE),
  ('School Event', 'school_event', '#EC4899', 'festival', TRUE, TRUE),
  ('Custom Schedule', 'custom', '#8B5CF6', 'calendar_month', FALSE, TRUE)
ON CONFLICT DO NOTHING;
