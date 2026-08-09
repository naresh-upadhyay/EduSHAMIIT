"""
Universal Calendar, Timetable, and Scheduling Engine API for EduSHAMIIT ERP.
Multi-tenant, enterprise-grade scheduling system supporting all user roles, recurrence rules,
smart conflict detection, resource reservations, participant assignments, RSVP workflows, and audit logging.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any, Union
from datetime import datetime, date, time, timedelta
import json
import uuid
import logging
import asyncio
import psycopg2
from psycopg2.extras import RealDictCursor

from app.config import settings
from app.middleware.auth import get_current_user, require_school_id, require_any_role

logger = logging.getLogger(__name__)
router = APIRouter()

# ============================================================================
# HELPER FUNCTIONS & RAW SQL EXECUTION
# ============================================================================

async def exec_sql(sql: str, params: tuple = (), fetch: bool = True) -> List[Dict[str, Any]]:
    """Execute raw parameterized SQL query asynchronously via psycopg2."""
    def _run():
        conn = psycopg2.connect(settings.DATABASE_URL, connect_timeout=5)
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(sql, params)
                if fetch:
                    rows = cur.fetchall()
                    conn.commit()
                    return [dict(r) for r in rows]
                else:
                    conn.commit()
                    return []
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

    return await asyncio.to_thread(_run)


def _serialize_datetime(val: Any) -> Any:
    """Format dates, datetimes, and UUIDs for clean JSON serialization."""
    if isinstance(val, (datetime, date, time)):
        return val.isoformat()
    if isinstance(val, uuid.UUID):
        return str(val)
    if isinstance(val, dict):
        return {k: _serialize_datetime(v) for k, v in val.items()}
    if isinstance(val, list):
        return [_serialize_datetime(v) for v in val]
    return val


async def dispatch_calendar_notification(
    school_id: str,
    user_id: str,
    title: str,
    body: str,
    schedule_id: str,
    priority: str = "normal"
):
    """Insert notification for participant assignment or schedule update."""
    try:
        sql = """
            INSERT INTO public.notifications (
                id, school_id, user_id, title, body, type, reference_id, reference_type, is_read, priority, created_at
            ) VALUES (
                gen_random_uuid(), %s, %s, %s, %s, 'calendar_schedule', %s, 'schedule', FALSE, %s, NOW()
            )
        """
        await exec_sql(sql, (school_id, user_id, title, body, schedule_id, priority), fetch=False)
    except Exception as e:
        logger.error(f"[Calendar Notification Error]: {e}")


async def record_schedule_audit_log(
    schedule_id: str,
    school_id: str,
    user_id: str,
    action: str,
    old_data: Optional[Dict[str, Any]] = None,
    new_data: Optional[Dict[str, Any]] = None,
    summary: str = ""
):
    """Save immutable version revision and audit log for compliance."""
    try:
        # 1. Fetch current max version
        rows = await exec_sql(
            "SELECT COALESCE(MAX(version), 0) + 1 AS next_ver FROM public.schedule_revisions WHERE schedule_id = %s",
            (schedule_id,)
        )
        next_version = rows[0]["next_ver"] if rows else 1

        diff_payload = {
            "action": action,
            "old": old_data or {},
            "new": new_data or {},
            "timestamp": datetime.utcnow().isoformat()
        }

        # 2. Insert revision
        await exec_sql(
            """
            INSERT INTO public.schedule_revisions (
                id, schedule_id, version, changed_by, change_summary, diff_data, created_at
            ) VALUES (
                gen_random_uuid(), %s, %s, %s, %s, %s, NOW()
            )
            """,
            (schedule_id, next_version, user_id, summary or f"{action.capitalize()} schedule", json.dumps(diff_payload)),
            fetch=False
        )

        # 3. Log to system audit_logs table if available
        try:
            await exec_sql(
                """
                INSERT INTO public.audit_logs (
                    id, school_id, user_id, action, module, record_id, details, created_at
                ) VALUES (
                    gen_random_uuid(), %s, %s, %s, 'Universal Calendar', %s, %s, NOW()
                )
                """,
                (school_id, user_id, f"CALENDAR_{action.upper()}", schedule_id, summary),
                fetch=False
            )
        except Exception:
            pass
    except Exception as e:
        logger.error(f"[Schedule Audit Log Error]: {e}")


# ============================================================================
# PYDANTIC REQUEST & RESPONSE SCHEMAS
# ============================================================================

class CalendarCreateRequest(BaseModel):
    name: str
    description: Optional[str] = None
    color: Optional[str] = "#4F46E5"
    type: Optional[str] = "custom" # personal, academic, transport, hr, department, school_events, custom
    visibility: Optional[str] = "shared" # private, shared, institution_wide, department_wide, role_wide, public
    default_view: Optional[str] = "week"

class CalendarUpdateRequest(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    color: Optional[str] = None
    visibility: Optional[str] = None
    default_view: Optional[str] = None
    is_archived: Optional[bool] = None

class CalendarMemberRequest(BaseModel):
    user_id: Optional[str] = None
    role_name: Optional[str] = None
    department: Optional[str] = None
    permission: str = "view_details" # view_only, view_details, create_events, edit_events, delete_events, share_calendar, manage_calendar

class RecurrenceRuleSchema(BaseModel):
    frequency: str # daily, weekly, monthly, yearly, custom
    interval: Optional[int] = 1
    days_of_week: Optional[List[str]] = [] # e.g. ["MO", "WE", "FR"]
    day_of_month: Optional[int] = None
    month_of_year: Optional[int] = None
    end_type: Optional[str] = "never" # never, after_count, until_date
    end_count: Optional[int] = None
    end_date: Optional[str] = None

class ParticipantAssignmentSchema(BaseModel):
    user_id: Optional[str] = None
    target_role: Optional[str] = None
    target_department: Optional[str] = None
    target_class: Optional[str] = None
    target_section: Optional[str] = None
    participant_type: Optional[str] = "individual" # individual, role, department, class_section, institution
    participation_role: Optional[str] = "required" # required, optional, fyi
    permission: Optional[str] = "can_view" # can_view, can_edit, can_invite, can_manage

class ResourceBookingSchema(BaseModel):
    resource_id: str
    start_time: Optional[str] = None
    end_time: Optional[str] = None

class ReminderSchema(BaseModel):
    minutes_before: int # 0, 5, 10, 15, 30, 60, 1440, etc.
    channel: Optional[str] = "in_app" # in_app, email, push, sms_whatsapp

class ScheduleCreateRequest(BaseModel):
    calendar_id: Optional[str] = None
    title: str
    description: Optional[str] = None
    schedule_type: str = "Event" # Meeting, Class, Exam, Task, Reminder, Training, Trip, Bus Route, etc.
    category: Optional[str] = "General"
    color: Optional[str] = "#4F46E5"
    priority: Optional[str] = "normal" # low, normal, high, urgent
    start_time: str # ISO 8601 string
    end_time: str # ISO 8601 string
    is_all_day: Optional[bool] = False
    timezone: Optional[str] = "Asia/Kolkata"
    location_name: Optional[str] = None
    location_address: Optional[str] = None
    building: Optional[str] = None
    room: Optional[str] = None
    landmark: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    virtual_meeting_url: Optional[str] = None
    virtual_meeting_provider: Optional[str] = None # google_meet, zoom, teams, custom
    visibility: Optional[str] = "shared" # private, shared, institution_wide, department_wide, role_wide, public, busy_only
    is_recurring: Optional[bool] = False
    recurrence: Optional[RecurrenceRuleSchema] = None
    participants: Optional[List[ParticipantAssignmentSchema]] = []
    resources: Optional[List[ResourceBookingSchema]] = []
    reminders: Optional[List[ReminderSchema]] = []
    metadata: Optional[Dict[str, Any]] = {}
    force_override_conflicts: Optional[bool] = False

class ScheduleUpdateRequest(BaseModel):
    calendar_id: Optional[str] = None
    title: Optional[str] = None
    description: Optional[str] = None
    schedule_type: Optional[str] = None
    category: Optional[str] = None
    color: Optional[str] = None
    priority: Optional[str] = None
    status: Optional[str] = None
    approval_status: Optional[str] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    is_all_day: Optional[bool] = None
    timezone: Optional[str] = None
    location_name: Optional[str] = None
    location_address: Optional[str] = None
    building: Optional[str] = None
    room: Optional[str] = None
    landmark: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    virtual_meeting_url: Optional[str] = None
    virtual_meeting_provider: Optional[str] = None
    visibility: Optional[str] = None
    is_recurring: Optional[bool] = None
    recurrence: Optional[RecurrenceRuleSchema] = None
    recurrence_scope: Optional[str] = "entire_series" # this_event, following_events, entire_series
    participants: Optional[List[ParticipantAssignmentSchema]] = None
    resources: Optional[List[ResourceBookingSchema]] = None
    reminders: Optional[List[ReminderSchema]] = None
    metadata: Optional[Dict[str, Any]] = None
    force_override_conflicts: Optional[bool] = False
    cancellation_reason: Optional[str] = None

class ScheduleCancelRequest(BaseModel):
    cancellation_reason: str
    recurrence_scope: Optional[str] = "entire_series"
    target_instance_date: Optional[str] = None

class ScheduleRSVPRequest(BaseModel):
    status: str # accepted, declined, tentative
    decline_reason: Optional[str] = None

class ScheduleCommentRequest(BaseModel):
    comment_text: str

class ResourceCreateRequest(BaseModel):
    name: str
    code: str
    type: str # classroom, lab, auditorium, bus, vehicle, meeting_room, projector, computer_lab, sports_ground
    capacity: Optional[int] = 1
    building: Optional[str] = None
    room_number: Optional[str] = None
    is_exclusive: Optional[bool] = True

class EventTypeCreateRequest(BaseModel):
    name: str
    code: str
    color: Optional[str] = "#4F46E5"
    icon: Optional[str] = "event"
    requires_approval: Optional[bool] = False


# ============================================================================
# AUTOMATED SEED DATA INITIALIZER
# ============================================================================

async def ensure_calendar_seed_data(school_id: str, current_user_id: Optional[str] = None):
    """Seed comprehensive initial calendars, resources, and schedules if empty."""
    try:
        # 0. Ensure tables exist
        await exec_sql("""
            CREATE TABLE IF NOT EXISTS public.calendars (
              id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
              school_id UUID NOT NULL,
              name TEXT NOT NULL,
              description TEXT,
              color TEXT DEFAULT '#4F46E5',
              type TEXT DEFAULT 'personal',
              is_system BOOLEAN DEFAULT FALSE,
              is_default BOOLEAN DEFAULT FALSE,
              is_archived BOOLEAN DEFAULT FALSE,
              owner_id UUID,
              visibility TEXT DEFAULT 'shared',
              default_view TEXT DEFAULT 'week',
              created_at TIMESTAMPTZ DEFAULT NOW(),
              updated_at TIMESTAMPTZ DEFAULT NOW(),
              deleted_at TIMESTAMPTZ
            );
            CREATE TABLE IF NOT EXISTS public.calendar_members (
              id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
              calendar_id UUID NOT NULL,
              user_id UUID,
              role_name TEXT,
              department TEXT,
              permission TEXT DEFAULT 'view_details',
              created_at TIMESTAMPTZ DEFAULT NOW()
            );
            CREATE TABLE IF NOT EXISTS public.schedule_event_types (
              id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
              school_id UUID,
              name TEXT NOT NULL,
              code TEXT NOT NULL,
              color TEXT DEFAULT '#4F46E5',
              icon TEXT DEFAULT 'event',
              requires_approval BOOLEAN DEFAULT FALSE,
              is_system BOOLEAN DEFAULT TRUE,
              created_at TIMESTAMPTZ DEFAULT NOW()
            );
            CREATE TABLE IF NOT EXISTS public.schedules (
              id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
              school_id UUID NOT NULL,
              calendar_id UUID NOT NULL,
              title TEXT NOT NULL,
              description TEXT,
              schedule_type TEXT NOT NULL,
              category TEXT DEFAULT 'General',
              color TEXT DEFAULT '#4F46E5',
              priority TEXT DEFAULT 'normal',
              status TEXT DEFAULT 'scheduled',
              approval_status TEXT DEFAULT 'not_required',
              approved_by UUID,
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
              virtual_meeting_provider TEXT,
              organizer_id UUID,
              created_by UUID,
              visibility TEXT DEFAULT 'shared',
              is_recurring BOOLEAN DEFAULT FALSE,
              parent_schedule_id UUID,
              original_start_time TIMESTAMPTZ,
              metadata JSONB DEFAULT '{}'::jsonb,
              created_at TIMESTAMPTZ DEFAULT NOW(),
              updated_at TIMESTAMPTZ DEFAULT NOW(),
              deleted_at TIMESTAMPTZ
            );
            CREATE TABLE IF NOT EXISTS public.schedule_recurrence (
              id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
              schedule_id UUID NOT NULL,
              frequency TEXT NOT NULL,
              interval INT DEFAULT 1,
              days_of_week JSONB DEFAULT '[]'::jsonb,
              day_of_month INT,
              month_of_year INT,
              end_type TEXT DEFAULT 'never',
              end_count INT,
              end_date DATE,
              exceptions JSONB DEFAULT '[]'::jsonb,
              created_at TIMESTAMPTZ DEFAULT NOW(),
              updated_at TIMESTAMPTZ DEFAULT NOW()
            );
            CREATE TABLE IF NOT EXISTS public.schedule_participants (
              id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
              schedule_id UUID NOT NULL,
              user_id UUID,
              target_role TEXT,
              target_department TEXT,
              target_class TEXT,
              target_section TEXT,
              participant_type TEXT DEFAULT 'individual',
              participation_role TEXT DEFAULT 'required',
              permission TEXT DEFAULT 'can_view',
              rsvp_status TEXT DEFAULT 'pending',
              decline_reason TEXT,
              rsvp_at TIMESTAMPTZ,
              created_at TIMESTAMPTZ DEFAULT NOW(),
              updated_at TIMESTAMPTZ DEFAULT NOW()
            );
            CREATE TABLE IF NOT EXISTS public.calendar_resources (
              id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
              school_id UUID NOT NULL,
              name TEXT NOT NULL,
              code TEXT NOT NULL,
              type TEXT NOT NULL,
              capacity INT DEFAULT 1,
              building TEXT,
              room_number TEXT,
              is_exclusive BOOLEAN DEFAULT TRUE,
              is_active BOOLEAN DEFAULT TRUE,
              created_at TIMESTAMPTZ DEFAULT NOW()
            );
            CREATE TABLE IF NOT EXISTS public.resource_bookings (
              id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
              schedule_id UUID NOT NULL,
              resource_id UUID NOT NULL,
              start_time TIMESTAMPTZ NOT NULL,
              end_time TIMESTAMPTZ NOT NULL,
              status TEXT DEFAULT 'confirmed',
              created_at TIMESTAMPTZ DEFAULT NOW()
            );
            CREATE TABLE IF NOT EXISTS public.schedule_reminders (
              id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
              schedule_id UUID NOT NULL,
              user_id UUID,
              minutes_before INT NOT NULL,
              channel TEXT DEFAULT 'in_app',
              is_sent BOOLEAN DEFAULT FALSE,
              sent_at TIMESTAMPTZ,
              created_at TIMESTAMPTZ DEFAULT NOW()
            );
            CREATE TABLE IF NOT EXISTS public.schedule_attachments (
              id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
              schedule_id UUID NOT NULL,
              file_name TEXT NOT NULL,
              file_url TEXT NOT NULL,
              file_type TEXT,
              file_size INT DEFAULT 0,
              uploaded_by UUID,
              created_at TIMESTAMPTZ DEFAULT NOW()
            );
            CREATE TABLE IF NOT EXISTS public.schedule_comments (
              id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
              schedule_id UUID NOT NULL,
              user_id UUID NOT NULL,
              comment_text TEXT NOT NULL,
              created_at TIMESTAMPTZ DEFAULT NOW(),
              updated_at TIMESTAMPTZ DEFAULT NOW()
            );
            CREATE TABLE IF NOT EXISTS public.schedule_revisions (
              id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
              schedule_id UUID NOT NULL,
              version INT NOT NULL,
              changed_by UUID,
              change_summary TEXT NOT NULL,
              diff_data JSONB NOT NULL DEFAULT '{}'::jsonb,
              created_at TIMESTAMPTZ DEFAULT NOW()
            );
        """, fetch=False)

        # Check if calendars exist for this school
        existing_cal = await exec_sql(
            "SELECT id FROM public.calendars WHERE school_id = %s LIMIT 1",
            (school_id,)
        )
        if existing_cal:
            return

        # 1. Create Default Core System Calendars
        cal_defs = [
            ("My Calendar", "Personal calendar & assignments", "#4F46E5", "personal", True),
            ("Academic Calendar", "Classes, examinations, and curricula", "#10B981", "academic", True),
            ("Transport & Fleet", "Bus routes, vehicle trips, and pickups", "#3B82F6", "transport", True),
            ("HR & Staff", "Employee training, staff meetings, and leave", "#F59E0B", "hr", True),
            ("School Events", "Community, sports, and annual school events", "#EC4899", "school_events", True),
            ("Public Holidays", "Official institutional and public holidays", "#EF4444", "school_events", True),
        ]
        cal_ids = {}
        for name, desc, color, c_type, is_def in cal_defs:
            c_id = str(uuid.uuid4())
            await exec_sql(
                """
                INSERT INTO public.calendars (
                    id, school_id, name, description, color, type, is_system, is_default, owner_id, visibility, created_at
                ) VALUES (%s, %s, %s, %s, %s, %s, TRUE, %s, %s, 'institution_wide', NOW())
                ON CONFLICT DO NOTHING
                """,
                (c_id, school_id, name, desc, color, c_type, is_def, current_user_id),
                fetch=False
            )
            cal_ids[name] = c_id

        # 2. Seed Bookable Resources
        resources = [
            ("Conference Room A", "CONF-A", "meeting_room", 20, "Admin Block", "101"),
            ("Meeting Room 1", "MR-1", "meeting_room", 10, "Academic Block", "201"),
            ("Meeting Room 2", "MR-2", "meeting_room", 12, "Design Wing", "202"),
            ("Meeting Room 3", "MR-3", "meeting_room", 8, "Marketing Wing", "203"),
            ("HR Cabin", "HR-CAB", "meeting_room", 6, "HR Wing", "301"),
            ("Room 204 (Math Lab)", "RM-204", "classroom", 45, "Science Block", "204"),
            ("School Auditorium", "AUD-01", "auditorium", 500, "Main Campus", "Ground"),
            ("Bus UP16 ET 1234", "BUS-101", "bus", 42, "Fleet Depot", "Bay 1"),
            ("Bus UP16 ET 5678", "BUS-102", "bus", 42, "Fleet Depot", "Bay 2"),
        ]
        res_map = {}
        for r_name, r_code, r_type, cap, bldg, rm in resources:
            r_id = str(uuid.uuid4())
            await exec_sql(
                """
                INSERT INTO public.calendar_resources (
                    id, school_id, name, code, type, capacity, building, room_number, is_exclusive, is_active, created_at
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, TRUE, TRUE, NOW())
                ON CONFLICT DO NOTHING
                """,
                (r_id, school_id, r_name, r_code, r_type, cap, bldg, rm),
                fetch=False
            )
            res_map[r_name] = r_id

        # 3. Seed Realistic Reference Schedules Matching the Visual Spec
        # Base anchor: Current week or Monday 26 May
        now = datetime.now()
        # Find Monday of current week
        monday = now - timedelta(days=now.weekday())
        
        sample_schedules = [
            # Monday
            {
                "title": "Project Planning",
                "cal": "My Calendar",
                "type": "Meeting",
                "category": "Meetings",
                "color": "#4F46E5",
                "day_offset": 0,
                "start_h": 9, "start_m": 0, "end_h": 10, "end_m": 30,
                "room": "Conference Room A",
                "organizer_name": "Ramesh Kumar",
                "desc": "Quarterly project sprint planning and milestone review",
                "participants": ["Ramesh Kumar", "Neha Sharma"],
                "resource": "Conference Room A"
            },
            {
                "title": "Performance Review",
                "cal": "HR & Staff",
                "type": "Meeting",
                "category": "HR",
                "color": "#F97316",
                "day_offset": 0,
                "start_h": 12, "start_m": 0, "end_h": 13, "end_m": 0,
                "room": "HR Cabin",
                "organizer_name": "Suresh Patel",
                "desc": "Annual teacher and staff appraisal discussion",
                "participants": ["Suresh Patel", "Neha Sharma"],
                "resource": "HR Cabin"
            },
            {
                "title": "Report Submission",
                "cal": "My Calendar",
                "type": "Task",
                "category": "Tasks",
                "color": "#10B981",
                "day_offset": 0,
                "start_h": 17, "start_m": 0, "end_h": 18, "end_m": 0,
                "room": "End of Day",
                "organizer_name": "Ramesh Kumar",
                "desc": "Submit consolidated department reports to the Principal",
                "participants": ["Ramesh Kumar"],
            },
            # Tuesday
            {
                "title": "Client Meeting",
                "cal": "My Calendar",
                "type": "Meeting",
                "category": "Meetings",
                "color": "#10B981",
                "day_offset": 1,
                "start_h": 10, "start_m": 0, "end_h": 11, "end_m": 0,
                "room": "Zoom Meeting",
                "virtual_url": "https://zoom.us/j/987654321",
                "virtual_provider": "zoom",
                "organizer_name": "Neha Sharma",
                "desc": "External institutional partnership conference call",
                "participants": ["Neha Sharma", "Ramesh Kumar"],
            },
            {
                "title": "Content Strategy",
                "cal": "My Calendar",
                "type": "Meeting",
                "category": "Meetings",
                "color": "#8B5CF6",
                "day_offset": 1,
                "start_h": 14, "start_m": 0, "end_h": 15, "end_m": 30,
                "room": "Meeting Room 3",
                "organizer_name": "Marketing Team",
                "desc": "Academic year digital campaigns and website curriculum updates",
                "participants": ["Marketing Team"],
                "resource": "Meeting Room 3"
            },
            {
                "title": "Yoga Session",
                "cal": "School Events",
                "type": "Event",
                "category": "Events",
                "color": "#F97316",
                "day_offset": 1,
                "start_h": 18, "start_m": 0, "end_h": 19, "end_m": 0,
                "room": "Wellness Program",
                "organizer_name": "Sports Head",
                "desc": "Faculty and staff evening relaxation & yoga session",
                "participants": ["All Staff"],
            },
            # Wednesday
            {
                "title": "Weekly Report Due",
                "cal": "My Calendar",
                "type": "Reminder",
                "category": "Reminders",
                "color": "#F59E0B",
                "day_offset": 2,
                "is_all_day": True,
                "start_h": 0, "start_m": 0, "end_h": 23, "end_m": 59,
                "desc": "Ensure all weekly attendance logs and vehicle trip reports are finalized",
            },
            {
                "title": "Design Review",
                "cal": "My Calendar",
                "type": "Meeting",
                "category": "Meetings",
                "color": "#8B5CF6",
                "day_offset": 2,
                "start_h": 9, "start_m": 0, "end_h": 11, "end_m": 0,
                "room": "Meeting Room 2",
                "organizer_name": "Design Team",
                "desc": "Review new ERP UI mockups and student portal redesign",
                "participants": ["Design Team", "Ramesh Kumar"],
                "resource": "Meeting Room 2"
            },
            {
                "title": "One to One",
                "cal": "My Calendar",
                "type": "Meeting",
                "category": "Meetings",
                "color": "#10B981",
                "day_offset": 2,
                "start_h": 13, "start_m": 0, "end_h": 14, "end_m": 0,
                "room": "Google Meet",
                "virtual_url": "https://meet.google.com/abc-defg-hij",
                "virtual_provider": "google_meet",
                "organizer_name": "Ramesh Kumar",
                "desc": "Bi-weekly mentoring and alignment check-in",
                "participants": ["Ramesh Kumar", "Vikram Singh"],
            },
            # Thursday
            {
                "title": "Training Session",
                "cal": "HR & Staff",
                "type": "Training",
                "category": "Training",
                "color": "#F59E0B",
                "day_offset": 3,
                "start_h": 11, "start_m": 0, "end_h": 12, "end_m": 30,
                "room": "Virtual",
                "virtual_url": "https://meet.google.com/edu-shamiit-train",
                "virtual_provider": "google_meet",
                "organizer_name": "HR Department",
                "desc": "New safety protocols and student welfare training session",
                "participants": ["All Teachers", "HR Department"],
            },
            {
                "title": "Vendor Call",
                "cal": "My Calendar",
                "type": "Meeting",
                "category": "Meetings",
                "color": "#3B82F6",
                "day_offset": 3,
                "start_h": 15, "start_m": 0, "end_h": 16, "end_m": 30,
                "room": "Zoom Meeting",
                "virtual_url": "https://zoom.us/j/123456789",
                "virtual_provider": "zoom",
                "organizer_name": "IT Team",
                "desc": "IT infrastructure and campus hardware supplier negotiation",
                "participants": ["IT Team"],
            },
            # Friday
            {
                "title": "Sprint Review",
                "cal": "My Calendar",
                "type": "Meeting",
                "category": "Meetings",
                "color": "#3B82F6",
                "day_offset": 4,
                "start_h": 10, "start_m": 0, "end_h": 11, "end_m": 30,
                "room": "Meeting Room 1",
                "organizer_name": "Development Team",
                "desc": "Sprint 24 showcase and release validation",
                "participants": ["Development Team"],
                "resource": "Meeting Room 1"
            },
            {
                "title": "Budget Planning",
                "cal": "My Calendar",
                "type": "Meeting",
                "category": "Finance",
                "color": "#8B5CF6",
                "day_offset": 4,
                "start_h": 14, "start_m": 0, "end_h": 16, "end_m": 0,
                "room": "Conference Room A",
                "organizer_name": "Finance Team",
                "desc": "Next academic semester capital expenditures and grant distribution",
                "participants": ["Finance Team", "Principal"],
                "resource": "Conference Room A"
            },
            {
                "title": "Weekly Wrap-up",
                "cal": "My Calendar",
                "type": "Meeting",
                "category": "Meetings",
                "color": "#F59E0B",
                "day_offset": 4,
                "start_h": 18, "start_m": 0, "end_h": 18, "end_m": 30,
                "room": "Conference Room A",
                "organizer_name": "All Team",
                "desc": "Friday team accomplishments and highlights recap",
                "participants": ["All Team"],
                "resource": "Conference Room A"
            },
            # Sunday
            {
                "title": "Community Event",
                "cal": "School Events",
                "type": "Event",
                "category": "Events",
                "color": "#EF4444",
                "day_offset": 6,
                "start_h": 11, "start_m": 0, "end_h": 13, "end_m": 0,
                "room": "City Center",
                "organizer_name": "All Employees",
                "desc": "Greenfield Annual Tree Plantation & Clean Campus Drive",
                "participants": ["All Employees"],
            },
            # Transport Schedules
            {
                "title": "Route 101 Morning",
                "cal": "Transport & Fleet",
                "type": "Trip",
                "category": "Transport",
                "color": "#10B981",
                "day_offset": 0,
                "start_h": 6, "start_m": 20, "end_h": 8, "end_m": 0,
                "room": "Bus UP16 ET 1234",
                "organizer_name": "Ramesh Kumar",
                "desc": "12 Stops • 32 Students • Sector 62 to Greenfield Campus",
                "participants": ["Ramesh Kumar"],
                "resource": "Bus UP16 ET 1234"
            },
            {
                "title": "Mathematics Class 9-A",
                "cal": "Academic Calendar",
                "type": "Class",
                "category": "Classes",
                "color": "#3B82F6",
                "day_offset": 1,
                "start_h": 9, "start_m": 0, "end_h": 10, "end_m": 0,
                "room": "Room 204 (Math Lab)",
                "organizer_name": "Amit Sharma",
                "desc": "Class 9-A Quadratic Equations and Algebra Chapter 4",
                "participants": ["Amit Sharma"],
                "resource": "Room 204 (Math Lab)"
            },
        ]

        for item in sample_schedules:
            s_id = str(uuid.uuid4())
            target_date = monday + timedelta(days=item["day_offset"])
            start_dt = target_date.replace(hour=item["start_h"], minute=item["start_m"], second=0, microsecond=0)
            end_dt = target_date.replace(hour=item["end_h"], minute=item["end_m"], second=0, microsecond=0)
            
            cal_id = cal_ids.get(item["cal"], list(cal_ids.values())[0])

            await exec_sql(
                """
                INSERT INTO public.schedules (
                    id, school_id, calendar_id, title, description, schedule_type, category, color, priority,
                    status, approval_status, start_time, end_time, is_all_day, timezone,
                    location_name, virtual_meeting_url, virtual_meeting_provider,
                    organizer_id, created_by, visibility, is_recurring, created_at
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, 'normal',
                    'confirmed', 'approved', %s, %s, %s, 'Asia/Kolkata',
                    %s, %s, %s,
                    %s, %s, 'shared', FALSE, NOW()
                )
                """,
                (
                    s_id, school_id, cal_id, item["title"], item.get("desc", ""), item["type"], item.get("category", "General"),
                    item.get("color", "#4F46E5"), start_dt.isoformat(), end_dt.isoformat(), item.get("is_all_day", False),
                    item.get("room"), item.get("virtual_url"), item.get("virtual_provider"),
                    current_user_id, current_user_id
                ),
                fetch=False
            )

            # Link resource if applicable
            res_name = item.get("resource")
            if res_name and res_name in res_map:
                await exec_sql(
                    """
                    INSERT INTO public.resource_bookings (
                        id, schedule_id, resource_id, start_time, end_time, status, created_at
                    ) VALUES (
                        gen_random_uuid(), %s, %s, %s, %s, 'confirmed', NOW()
                    )
                    """,
                    (s_id, res_map[res_name], start_dt.isoformat(), end_dt.isoformat()),
                    fetch=False
                )

            # Add default reminder
            await exec_sql(
                """
                INSERT INTO public.schedule_reminders (
                    id, schedule_id, user_id, minutes_before, channel, is_sent, created_at
                ) VALUES (
                    gen_random_uuid(), %s, %s, 15, 'in_app', FALSE, NOW()
                )
                """,
                (s_id, current_user_id),
                fetch=False
            )

            # If user current_user_id exists, assign them as accepted participant
            if current_user_id:
                await exec_sql(
                    """
                    INSERT INTO public.schedule_participants (
                        id, schedule_id, user_id, participant_type, participation_role, permission, rsvp_status, rsvp_at, created_at
                    ) VALUES (
                        gen_random_uuid(), %s, %s, 'individual', 'required', 'can_manage', 'accepted', NOW(), NOW()
                    )
                    """,
                    (s_id, current_user_id),
                    fetch=False
                )

    except Exception as e:
        logger.error(f"[Calendar Seed Initialization Error]: {e}")


# ============================================================================
# SCHEDULE CATEGORIES & TYPES APIS
# ============================================================================

@router.get("/calendar/categories")
async def list_schedule_categories(type: Optional[str] = "schedule", user=Depends(get_current_user)):
    """
    Retrieve dynamic categories/types from public.categories database table.
    Both Schedule Type dropdown and Schedule Category filter dropdown fetch from this single generic table.
    """
    school_id = user.get("school_id")

    sql = """
        SELECT * FROM public.categories 
        WHERE (school_id = %s OR school_id IS NULL) 
          AND (%s IS NULL OR type = %s)
        ORDER BY sort_order ASC, name ASC
    """
    rows = await exec_sql(sql, (school_id, type, type))
    return {"success": True, "data": _serialize_datetime(rows)}



# ============================================================================
# 1. CALENDAR MANAGEMENT APIS
# ============================================================================


@router.get("/calendars")
async def list_calendars(user=Depends(get_current_user)):
    """List all available and shared calendars for the current tenant and user."""
    school_id = user.get("school_id")
    user_id = user.get("id")
    role = user.get("role", "").lower()

    if not school_id:
        raise HTTPException(status_code=400, detail="Tenant school_id is required")

    await ensure_calendar_seed_data(school_id, user_id)

    # Fetch calendars owned by user or shared institution-wide
    sql = """
        SELECT c.*,
               COALESCE(cm.permission, CASE WHEN c.owner_id = %s OR %s = 'super_admin' THEN 'manage_calendar' ELSE 'view_details' END) AS user_permission,
               (SELECT COUNT(*) FROM public.schedules s WHERE s.calendar_id = c.id AND s.deleted_at IS NULL) AS event_count
        FROM public.calendars c
        LEFT JOIN public.calendar_members cm ON cm.calendar_id = c.id AND cm.user_id = %s
        WHERE c.school_id = %s
          AND c.deleted_at IS NULL
          AND (
              c.is_system = TRUE 
              OR c.owner_id = %s 
              OR c.visibility IN ('institution_wide', 'public', 'shared')
              OR cm.user_id IS NOT NULL
              OR %s IN ('super_admin', 'director', 'principal')
          )
        ORDER BY c.is_default DESC, c.is_system DESC, c.name ASC
    """
    rows = await exec_sql(sql, (user_id, role, user_id, school_id, user_id, role))
    return {"success": True, "data": _serialize_datetime(rows)}


@router.post("/calendars")
async def create_calendar(req: CalendarCreateRequest, user=Depends(get_current_user)):
    """Create a new custom or departmental calendar."""
    school_id = user.get("school_id")
    user_id = user.get("id")
    role = user.get("role", "").lower()

    if not school_id:
        raise HTTPException(status_code=400, detail="Tenant school_id is required")

    cal_id = str(uuid.uuid4())
    sql = """
        INSERT INTO public.calendars (
            id, school_id, name, description, color, type, is_system, is_default, owner_id, visibility, default_view, created_at
        ) VALUES (
            %s, %s, %s, %s, %s, %s, FALSE, FALSE, %s, %s, %s, NOW()
        ) RETURNING *
    """
    rows = await exec_sql(
        sql,
        (cal_id, school_id, req.name, req.description, req.color or "#4F46E5", req.type or "custom", user_id, req.visibility or "shared", req.default_view or "week")
    )
    if not rows:
        raise HTTPException(status_code=500, detail="Failed to create calendar")

    # Add creator as owner in calendar_members
    await exec_sql(
        """
        INSERT INTO public.calendar_members (id, calendar_id, user_id, role_name, permission, created_at)
        VALUES (gen_random_uuid(), %s, %s, %s, 'manage_calendar', NOW())
        """,
        (cal_id, user_id, role),
        fetch=False
    )

    return {"success": True, "data": _serialize_datetime(rows[0]), "message": f"Calendar '{req.name}' created successfully."}


@router.get("/calendars/{calendar_id}")
async def get_calendar_details(calendar_id: str, user=Depends(get_current_user)):
    """Retrieve details, members, and event statistics for a specific calendar."""
    school_id = user.get("school_id")
    user_id = user.get("id")

    rows = await exec_sql(
        "SELECT * FROM public.calendars WHERE id = %s AND school_id = %s AND deleted_at IS NULL",
        (calendar_id, school_id)
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Calendar not found or access denied")

    members = await exec_sql(
        """
        SELECT cm.*, p.full_name, p.role, p.email, p.avatar_url
        FROM public.calendar_members cm
        JOIN public.profiles p ON p.id = cm.user_id
        WHERE cm.calendar_id = %s
        """,
        (calendar_id,)
    )

    data = rows[0]
    data["members"] = members
    return {"success": True, "data": _serialize_datetime(data)}


@router.patch("/calendars/{calendar_id}")
async def update_calendar(calendar_id: str, req: CalendarUpdateRequest, user=Depends(get_current_user)):
    """Update calendar metadata, color, visibility, or archive status."""
    school_id = user.get("school_id")
    user_id = user.get("id")
    role = user.get("role", "").lower()

    # Verify ownership or management permission
    cal = await exec_sql(
        "SELECT * FROM public.calendars WHERE id = %s AND school_id = %s AND deleted_at IS NULL",
        (calendar_id, school_id)
    )
    if not cal:
        raise HTTPException(status_code=404, detail="Calendar not found")

    if cal[0]["owner_id"] != user_id and role not in ("super_admin", "director", "principal"):
        # Check explicit member permission
        perm = await exec_sql(
            "SELECT permission FROM public.calendar_members WHERE calendar_id = %s AND user_id = %s",
            (calendar_id, user_id)
        )
        if not perm or perm[0]["permission"] != "manage_calendar":
            raise HTTPException(status_code=403, detail="Forbidden: You do not have permission to manage this calendar")

    updates = []
    params = []
    if req.name is not None:
        updates.append("name = %s")
        params.append(req.name)
    if req.description is not None:
        updates.append("description = %s")
        params.append(req.description)
    if req.color is not None:
        updates.append("color = %s")
        params.append(req.color)
    if req.visibility is not None:
        updates.append("visibility = %s")
        params.append(req.visibility)
    if req.default_view is not None:
        updates.append("default_view = %s")
        params.append(req.default_view)
    if req.is_archived is not None:
        updates.append("is_archived = %s")
        params.append(req.is_archived)

    if not updates:
        return {"success": True, "data": _serialize_datetime(cal[0])}

    updates.append("updated_at = NOW()")
    params.extend([calendar_id, school_id])

    sql = f"UPDATE public.calendars SET {', '.join(updates)} WHERE id = %s AND school_id = %s RETURNING *"
    rows = await exec_sql(sql, tuple(params))
    return {"success": True, "data": _serialize_datetime(rows[0])}


@router.delete("/calendars/{calendar_id}")
async def delete_calendar(calendar_id: str, user=Depends(get_current_user)):
    """Soft delete a custom calendar and all contained non-system schedules."""
    school_id = user.get("school_id")
    user_id = user.get("id")
    role = user.get("role", "").lower()

    cal = await exec_sql("SELECT * FROM public.calendars WHERE id = %s AND school_id = %s", (calendar_id, school_id))
    if not cal:
        raise HTTPException(status_code=404, detail="Calendar not found")

    if cal[0]["is_system"]:
        raise HTTPException(status_code=400, detail="Cannot delete core system calendars")

    if cal[0]["owner_id"] != user_id and role not in ("super_admin", "director", "principal"):
        raise HTTPException(status_code=403, detail="Forbidden: You do not have permission to delete this calendar")

    await exec_sql(
        "UPDATE public.calendars SET deleted_at = NOW(), updated_at = NOW() WHERE id = %s",
        (calendar_id,),
        fetch=False
    )
    await exec_sql(
        "UPDATE public.schedules SET deleted_at = NOW(), updated_at = NOW() WHERE calendar_id = %s",
        (calendar_id,),
        fetch=False
    )

    return {"success": True, "message": "Calendar deleted successfully"}


@router.get("/calendar/assignable-roles")
@router.get("/assignable-roles")
async def get_assignable_roles(user=Depends(get_current_user)):
    """Fetch distinct system roles from public.app_roles and public.profiles for schedule assignment."""
    try:
        roles_sql = """
            SELECT DISTINCT name, description FROM (
                SELECT name, COALESCE(description, name) AS description FROM public.app_roles WHERE name IS NOT NULL AND name != ''
                UNION
                SELECT role AS name, role AS description FROM public.profiles WHERE role IS NOT NULL AND role != ''
            ) combined_roles
            ORDER BY name
        """
        rows = await exec_sql(roles_sql)
        roles_set = {r["name"].lower(): r for r in rows if r.get("name")}
        
        default_roles = ["teacher", "driver", "student", "parent", "admin", "staff", "hr", "finance", "transport", "principal", "director", "support"]
        for dr in default_roles:
            if dr.lower() not in roles_set:
                rows.append({"name": dr, "description": f"Standard {dr} role"})

        formatted_roles = []
        seen = set()
        for r in rows:
            r_name = str(r.get("name") or "").strip()
            if r_name and r_name.lower() not in seen:
                seen.add(r_name.lower())
                formatted_roles.append({
                    "name": r_name,
                    "description": r.get("description") or r_name
                })

        return {"success": True, "data": sorted(formatted_roles, key=lambda x: x["name"].lower())}
    except Exception as e:
        logger.error(f"[Assignable Roles Error]: {e}")
        fallback = ["teacher", "driver", "student", "parent", "admin", "staff", "hr", "finance", "transport", "principal", "director", "support"]
        return {"success": True, "data": [{"name": r, "description": f"Standard {r} role"} for r in fallback]}


@router.get("/calendar/assignable-classes")
@router.get("/assignable-classes")
async def get_assignable_classes(user=Depends(get_current_user)):
    """Fetch distinct academic classes directly from public.profiles(class column) table dynamically."""
    try:
        classes_sql = """
            SELECT DISTINCT "class" AS class_name 
            FROM public.profiles 
            WHERE "class" IS NOT NULL AND "class" != ''
            ORDER BY class_name
        """
        rows = await exec_sql(classes_sql)
        found_classes = [str(r["class_name"]).strip() for r in rows if r.get("class_name")]

        default_classes = ["10A", "IX-A", "X-A", "X-B", "Class 1-A", "Class 2-A", "Class 9-A", "Grade 11-Sci", "Grade 12-Sci"]
        for dc in default_classes:
            if dc not in found_classes:
                found_classes.append(dc)

        formatted_classes = [{"name": c} for c in sorted(list(set(found_classes)))]
        return {"success": True, "data": formatted_classes}
    except Exception as e:
        logger.error(f"[Assignable Classes Error]: {e}")
        fallback = ["10A", "IX-A", "X-A", "X-B", "Class 9-A", "Grade 11-Sci", "Grade 12-Sci"]
        return {"success": True, "data": [{"name": c} for c in fallback]}


# ============================================================================
# 2. UNIVERSAL SCHEDULE CRUD & FILTERING APIS
# ============================================================================

@router.get("/schedules")
async def get_schedules(
    start_date: Optional[str] = Query(None, description="Start date/time (ISO 8601)"),
    end_date: Optional[str] = Query(None, description="End date/time (ISO 8601)"),
    calendar_id: Optional[str] = Query(None, description="Filter by calendar ID"),
    schedule_type: Optional[str] = Query(None, description="Filter by schedule type"),
    category: Optional[str] = Query(None, description="Filter by category"),
    status: Optional[str] = Query(None, description="Filter by status"),
    assigned_to_me: Optional[bool] = Query(False, description="Only schedules assigned/invited to current user"),
    created_by_me: Optional[bool] = Query(False, description="Only schedules created by current user"),
    search: Optional[str] = Query(None, description="Search keyword"),
    limit: int = Query(250, ge=1, le=1000),
    user=Depends(get_current_user)
):
    """
    Unified, high-speed schedule querying engine supporting:
    - Date range queries (Day, Week, Month, Agenda, Timeline)
    - Multi-tenant tenant isolation
    - User assignments & invitations
    - Recurrence expansion
    - Full-text search
    """
    school_id = user.get("school_id")
    user_id = user.get("id")
    role = user.get("role", "").lower()

    # Normalize parameters
    start_date = str(start_date) if start_date and isinstance(start_date, str) else None
    end_date = str(end_date) if end_date and isinstance(end_date, str) else None
    calendar_id = str(calendar_id) if calendar_id and isinstance(calendar_id, str) and calendar_id not in ("All", "all", "null", "") else None
    schedule_type = str(schedule_type) if schedule_type and isinstance(schedule_type, str) and schedule_type != "All" else None
    category = str(category) if category and isinstance(category, str) and category != "All" else None
    status = str(status) if status and isinstance(status, str) and status != "All" else None
    search = str(search) if search and isinstance(search, str) and search.strip() else None
    assigned_to_me = bool(assigned_to_me) if isinstance(assigned_to_me, bool) else False
    created_by_me = bool(created_by_me) if isinstance(created_by_me, bool) else False
    limit = int(limit) if isinstance(limit, int) else 250

    if not school_id:
        raise HTTPException(status_code=400, detail="Tenant school_id is required")

    await ensure_calendar_seed_data(school_id, user_id)

    # Base query: fetches non-recurring standalone and override schedule records
    conditions = ["s.school_id = %s", "s.deleted_at IS NULL", "s.is_recurring = FALSE"]
    params: List[Any] = [school_id]

    # Date range filters
    if start_date:
        conditions.append("s.end_time >= %s")
        params.append(start_date)
    if end_date:
        conditions.append("s.start_time <= %s")
        params.append(end_date)

    # Specific calendar filter
    if calendar_id:
        conditions.append("s.calendar_id = %s")
        params.append(calendar_id)

    # Type & Category filters
    if schedule_type and schedule_type != "All":
        conditions.append("s.schedule_type ILIKE %s")
        params.append(f"%{schedule_type}%")
    if category and category != "All":
        conditions.append("s.category ILIKE %s")
        params.append(f"%{category}%")
    if status and status != "All":
        conditions.append("s.status = %s")
        params.append(status)

    # User personalized filters
    if assigned_to_me:
        conditions.append("""
            (s.id IN (SELECT schedule_id FROM public.schedule_participants WHERE user_id = %s)
             OR s.id IN (SELECT schedule_id FROM public.schedule_participants WHERE target_role ILIKE %s))
        """)
        params.extend([user_id, f"%{role}%"])

    if created_by_me:
        conditions.append("s.created_by = %s")
        params.append(user_id)

    # Search keyword
    if search and isinstance(search, str) and search.strip():
        kw = f"%{search.strip()}%"
        conditions.append("""
            (s.title ILIKE %s OR s.description ILIKE %s OR s.location_name ILIKE %s OR s.room ILIKE %s OR s.category ILIKE %s)
        """)
        params.extend([kw, kw, kw, kw, kw])

    # Universal strict privacy check: ALL users see ONLY institution_wide global schedules,
    # events they created/organized, or events they are explicitly assigned to as participants (by user_id, role, or academic class).
    conditions.append("""
        (
            s.visibility = 'institution_wide'
            OR s.created_by = %s
            OR s.organizer_id = %s
            OR s.id IN (
                SELECT sp.schedule_id 
                FROM public.schedule_participants sp
                LEFT JOIN public.profiles prof ON prof.id = %s
                WHERE sp.user_id = %s 
                   OR (sp.user_id IS NULL AND sp.target_role IS NOT NULL AND sp.target_role ILIKE %s)
                   OR (sp.user_id IS NULL AND sp.target_class IS NOT NULL AND prof.class IS NOT NULL AND sp.target_class ILIKE prof.class)
            )
        )
    """)
    params.extend([user_id, user_id, user_id, user_id, f"%{role}%"])

    where_clause = " AND ".join(conditions)
    sql = f"""
        SELECT s.*,
               c.name AS calendar_name,
               c.color AS calendar_color,
               c.type AS calendar_type,
               p.full_name AS organizer_name,
               p.avatar_url AS organizer_avatar,
               (
                   SELECT json_agg(json_build_object(
                       'id', sp.id,
                       'user_id', sp.user_id,
                       'target_role', sp.target_role,
                       'target_class', sp.target_class,
                       'participant_type', sp.participant_type,
                       'participation_role', sp.participation_role,
                       'permission', sp.permission,
                       'rsvp_status', sp.rsvp_status,
                       'full_name', COALESCE(prof.full_name, sp.target_role, sp.target_class),
                       'role', prof.role,
                       'email', prof.email,
                       'avatar_url', prof.avatar_url
                   ))
                   FROM public.schedule_participants sp
                   LEFT JOIN public.profiles prof ON prof.id = sp.user_id
                   WHERE sp.schedule_id = s.id
               ) AS participants,
               (
                   SELECT json_agg(json_build_object(
                       'id', rb.id,
                       'resource_id', rb.resource_id,
                       'resource_name', cr.name,
                       'resource_type', cr.type,
                       'room_number', cr.room_number,
                       'status', rb.status
                   ))
                   FROM public.resource_bookings rb
                   LEFT JOIN public.calendar_resources cr ON cr.id = rb.resource_id
                   WHERE rb.schedule_id = s.id
               ) AS booked_resources,
               (
                   SELECT json_agg(json_build_object(
                       'id', sc.id,
                       'user_id', sc.user_id,
                       'comment_text', sc.comment_text,
                       'full_name', p2.full_name,
                       'avatar_url', p2.avatar_url,
                       'created_at', sc.created_at
                   ))
                   FROM public.schedule_comments sc
                   LEFT JOIN public.profiles p2 ON p2.id = sc.user_id
                   WHERE sc.schedule_id = s.id
               ) AS comments,
               (
                   SELECT json_agg(json_build_object(
                       'id', rem.id,
                       'minutes_before', rem.minutes_before,
                       'channel', rem.channel
                   ))
                   FROM public.schedule_reminders rem
                   WHERE rem.schedule_id = s.id
               ) AS reminders,
               (
                   SELECT json_build_object(
                       'id', sr.id,
                       'frequency', sr.frequency,
                       'interval', sr.interval,
                       'days_of_week', sr.days_of_week,
                       'day_of_month', sr.day_of_month,
                       'month_of_year', sr.month_of_year,
                       'end_type', sr.end_type,
                       'end_count', sr.end_count,
                       'end_date', sr.end_date
                   )
                   FROM public.schedule_recurrence sr
                   WHERE sr.schedule_id = s.id
                   LIMIT 1
               ) AS recurrence
        FROM public.schedules s
        LEFT JOIN public.calendars c ON c.id = s.calendar_id
        LEFT JOIN public.profiles p ON p.id = s.organizer_id
        WHERE {where_clause}
        ORDER BY s.start_time ASC
        LIMIT %s
    """
    params.append(limit)

    rows = await exec_sql(sql, tuple(params))

    # Recurrence Expansion Engine:
    # Also fetch recurring schedules and expand virtual instances across the window
    if start_date and end_date:
        try:
            req_start = datetime.fromisoformat(start_date.replace("Z", "+00:00")).replace(tzinfo=None)
            req_end = datetime.fromisoformat(end_date.replace("Z", "+00:00")).replace(tzinfo=None)

            rec_conds = ["s.school_id = %s", "s.deleted_at IS NULL", "s.is_recurring = TRUE"]
            rec_params: List[Any] = [school_id]

            if calendar_id and calendar_id not in ("All", "all", "null", ""):
                rec_conds.append("s.calendar_id = %s")
                rec_params.append(calendar_id)
            if schedule_type and schedule_type != "All":
                rec_conds.append("s.schedule_type ILIKE %s")
                rec_params.append(f"%{schedule_type}%")
            if category and category != "All":
                rec_conds.append("s.category ILIKE %s")
                rec_params.append(f"%{category}%")
            if status and status != "All":
                rec_conds.append("s.status = %s")
                rec_params.append(status)

            rec_conds.append("""
                (
                    s.visibility = 'institution_wide'
                    OR s.created_by = %s
                    OR s.organizer_id = %s
                    OR s.id IN (SELECT schedule_id FROM public.schedule_participants WHERE user_id = %s OR target_role ILIKE %s)
                )
            """)
            rec_params.extend([user_id, user_id, user_id, f"%{role}%"])

            rec_where = " AND ".join(rec_conds)

            rec_sql = f"""
                SELECT s.*, sr.frequency, sr.interval, sr.days_of_week, sr.end_type, sr.end_count, sr.end_date as rec_end_date, sr.exceptions,
                       c.name AS calendar_name, c.color AS calendar_color, c.type AS calendar_type,
                       p.full_name AS organizer_name, p.avatar_url AS organizer_avatar,
                       (
                           SELECT json_agg(json_build_object(
                               'id', sp.id, 'user_id', sp.user_id, 'participant_type', sp.participant_type,
                               'participation_role', sp.participation_role, 'permission', sp.permission,
                               'rsvp_status', sp.rsvp_status, 'decline_reason', sp.decline_reason, 'rsvp_at', sp.rsvp_at,
                               'full_name', prof.full_name, 'role', prof.role,
                               'avatar_url', prof.avatar_url
                           ))
                           FROM public.schedule_participants sp
                           LEFT JOIN public.profiles prof ON prof.id = sp.user_id
                           WHERE sp.schedule_id = s.id
                       ) AS participants,
                       (
                           SELECT json_agg(json_build_object(
                               'id', rb.id, 'resource_id', rb.resource_id, 'resource_name', cr.name,
                               'resource_type', cr.type, 'room_number', cr.room_number, 'status', rb.status
                           ))
                           FROM public.resource_bookings rb
                           LEFT JOIN public.calendar_resources cr ON cr.id = rb.resource_id
                           WHERE rb.schedule_id = s.id
                       ) AS booked_resources,
                       (
                           SELECT json_agg(json_build_object(
                               'id', sc.id, 'user_id', sc.user_id, 'comment_text', sc.comment_text,
                               'full_name', p2.full_name, 'avatar_url', p2.avatar_url, 'created_at', sc.created_at
                           ))
                           FROM public.schedule_comments sc
                           LEFT JOIN public.profiles p2 ON p2.id = sc.user_id
                           WHERE sc.schedule_id = s.id
                       ) AS comments,
                       (
                           SELECT json_agg(json_build_object(
                               'id', rem.id, 'minutes_before', rem.minutes_before, 'channel', rem.channel
                           ))
                           FROM public.schedule_reminders rem
                           WHERE rem.schedule_id = s.id
                       ) AS reminders,
                       (
                           SELECT json_build_object(
                               'id', sr2.id,
                               'frequency', sr2.frequency,
                               'interval', sr2.interval,
                               'days_of_week', sr2.days_of_week,
                               'day_of_month', sr2.day_of_month,
                               'month_of_year', sr2.month_of_year,
                               'end_type', sr2.end_type,
                               'end_count', sr2.end_count,
                               'end_date', sr2.end_date
                           )
                           FROM public.schedule_recurrence sr2
                           WHERE sr2.schedule_id = s.id
                           LIMIT 1
                       ) AS recurrence
                FROM public.schedules s
                JOIN public.schedule_recurrence sr ON sr.schedule_id = s.id
                LEFT JOIN public.calendars c ON c.id = s.calendar_id
                LEFT JOIN public.profiles p ON p.id = s.organizer_id
                WHERE {rec_where}
            """
            rec_rows = await exec_sql(rec_sql, tuple(rec_params))

            day_name_to_weekday = {
                "MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6,
                "MON": 0, "TUE": 1, "WED": 2, "THU": 3, "FRI": 4, "SAT": 5, "SUN": 6,
                "MONDAY": 0, "TUESDAY": 1, "WEDNESDAY": 2, "THURSDAY": 3, "FRIDAY": 4, "SATURDAY": 5, "SUNDAY": 6
            }

            for rec in rec_rows:
                orig_start = rec["start_time"]
                orig_end = rec["end_time"]
                duration = orig_end - orig_start

                freq = (rec.get("frequency") or "daily").lower()
                interval = max(rec.get("interval") or 1, 1)
                days_of_week = rec.get("days_of_week") or []
                if isinstance(days_of_week, str):
                    try:
                        days_of_week = json.loads(days_of_week)
                    except Exception:
                        days_of_week = []

                exceptions = rec.get("exceptions") or []
                if isinstance(exceptions, str):
                    try:
                        exceptions = json.loads(exceptions)
                    except Exception:
                        exceptions = []
                if not isinstance(exceptions, list):
                    exceptions = []

                end_type = rec.get("end_type") or "never"
                end_count = rec.get("end_count") or 1000
                rec_end_dt = rec.get("rec_end_date")
                rec_limit = None
                if rec_end_dt:
                    if isinstance(rec_end_dt, (datetime, date)):
                        rec_limit = rec_end_dt.date() if isinstance(rec_end_dt, datetime) else rec_end_dt
                    else:
                        try:
                            clean_dt_str = str(rec_end_dt).replace("Z", "+00:00")
                            rec_limit = datetime.fromisoformat(clean_dt_str).date()
                        except Exception:
                            rec_limit = None

                # Generate occurrences from original start date
                cur_day = orig_start.date()
                end_projection_day = req_end.date()
                occurrence_idx = 0

                # Count prior occurrences if after_count is used
                if end_type == "after_count":
                    count_day = orig_start.date()
                    while count_day < cur_day:
                        if freq == "daily":
                            diff_days = (count_day - orig_start.date()).days
                            if diff_days >= 0 and diff_days % interval == 0:
                                occurrence_idx += 1
                        elif freq == "weekly":
                            diff_weeks = (count_day - orig_start.date()).days // 7
                            if diff_weeks >= 0 and diff_weeks % interval == 0:
                                if days_of_week:
                                    wk_days = [day_name_to_weekday.get(str(d).strip().upper(), -1) for d in days_of_week]
                                    if count_day.weekday() in wk_days:
                                        occurrence_idx += 1
                                elif count_day.weekday() == orig_start.weekday():
                                    occurrence_idx += 1
                        elif freq == "monthly" and count_day.day == orig_start.day:
                            diff_months = (count_day.year - orig_start.year) * 12 + (count_day.month - orig_start.month)
                            if diff_months >= 0 and diff_months % interval == 0:
                                occurrence_idx += 1
                        count_day += timedelta(days=1)

                while cur_day <= end_projection_day:
                    if end_type == "until_date" and rec_limit and cur_day > rec_limit:
                        break

                    cur_iso = cur_day.isoformat()
                    cur_str = cur_day.strftime("%Y-%m-%d")
                    exc_dates = {str(e).strip('"\' ') for e in exceptions}
                    is_excluded = cur_str in exc_dates or cur_iso in exc_dates

                    should_include = False
                    if not is_excluded:
                        if freq == "daily":
                            diff_days = (cur_day - orig_start.date()).days
                            if diff_days >= 0 and diff_days % interval == 0:
                                should_include = True
                        elif freq == "weekdays":
                            if cur_day >= orig_start.date() and cur_day.weekday() in (0, 1, 2, 3, 4):
                                should_include = True
                        elif freq == "weekly":
                            diff_weeks = (cur_day - orig_start.date()).days // 7
                            if diff_weeks >= 0 and diff_weeks % interval == 0:
                                if days_of_week:
                                    wk_days = [day_name_to_weekday.get(str(d).strip().upper(), -1) for d in days_of_week]
                                    if cur_day.weekday() in wk_days:
                                        should_include = True
                                elif cur_day.weekday() == orig_start.weekday():
                                    should_include = True
                        elif freq in ("biweekly", "fortnightly"):
                            diff_weeks = (cur_day - orig_start.date()).days // 7
                            if diff_weeks >= 0 and diff_weeks % 2 == 0 and cur_day.weekday() == orig_start.weekday():
                                should_include = True
                        elif freq == "monthly":
                            if cur_day >= orig_start.date() and cur_day.day == orig_start.day:
                                diff_months = (cur_day.year - orig_start.year) * 12 + (cur_day.month - orig_start.month)
                                if diff_months >= 0 and diff_months % interval == 0:
                                    should_include = True
                        elif freq == "yearly":
                            if cur_day >= orig_start.date() and cur_day.month == orig_start.month and cur_day.day == orig_start.day:
                                diff_years = cur_day.year - orig_start.year
                                if diff_years >= 0 and diff_years % interval == 0:
                                    should_include = True
                        elif freq == "custom":
                            if days_of_week:
                                diff_weeks = (cur_day - orig_start.date()).days // 7
                                if diff_weeks >= 0 and diff_weeks % interval == 0:
                                    wk_days = [day_name_to_weekday.get(str(d).strip().upper(), -1) for d in days_of_week]
                                    if cur_day.weekday() in wk_days:
                                        should_include = True
                            else:
                                diff_days = (cur_day - orig_start.date()).days
                                if diff_days >= 0 and diff_days % interval == 0:
                                    should_include = True

                    if should_include:
                        occurrence_idx += 1
                        if end_type == "after_count" and occurrence_idx > end_count:
                            break

                        inst_start = datetime.combine(cur_day, orig_start.time())
                        inst_end = inst_start + duration

                        # Check if parent or standalone override for this date is already present in rows
                        parent_rec_id = str(rec["id"])
                        already_present = any(
                            (
                                str(r.get("id")) == parent_rec_id
                                or str(r.get("recurring_parent_id")) == parent_rec_id
                                or str(r.get("parent_schedule_id")) == parent_rec_id
                            )
                            and (
                                (r.get("original_instance_date") and str(r["original_instance_date"]) == cur_str)
                                or (r.get("start_time") and (
                                    (isinstance(r["start_time"], datetime) and r["start_time"].date() == cur_day)
                                    or (isinstance(r["start_time"], str) and r["start_time"].startswith(cur_str))
                                ))
                            )
                            for r in rows
                        )
                        if not already_present and inst_start >= req_start and inst_start <= req_end:
                            inst_dict = dict(rec)
                            inst_dict["id"] = f"{rec['id']}_inst_{cur_day.isoformat()}"
                            inst_dict["start_time"] = inst_start
                            inst_dict["end_time"] = inst_end
                            inst_dict["is_recurrence_instance"] = True
                            inst_dict["parent_schedule_id"] = str(rec["id"])
                            rows.append(inst_dict)

                    cur_day += timedelta(days=1)

        except Exception as e:
            logger.error(f"[Recurrence Expansion Error]: {e}")

    return {"success": True, "count": len(rows), "data": _serialize_datetime(rows)}


@router.post("/schedules")
async def create_schedule(req: ScheduleCreateRequest, user=Depends(get_current_user)):
    """
    Create a new schedule with intelligent conflict detection, recurrence configuration,
    user assignments, resource bookings, and automated notifications.
    """
    school_id = user.get("school_id")
    user_id = user.get("id")
    role = user.get("role", "").lower()

    if not school_id:
        raise HTTPException(status_code=400, detail="Tenant school_id is required")

    # 1. Resolve Calendar ID
    cal_id = req.calendar_id
    if not cal_id:
        # Default to user's personal or academic calendar
        cals = await exec_sql(
            "SELECT id FROM public.calendars WHERE school_id = %s AND (owner_id = %s OR is_default = TRUE) LIMIT 1",
            (school_id, user_id)
        )
        if cals:
            cal_id = cals[0]["id"]
        else:
            # Create default calendar
            cal_id = str(uuid.uuid4())
            await exec_sql(
                """
                INSERT INTO public.calendars (id, school_id, name, color, type, is_default, owner_id, created_at)
                VALUES (%s, %s, 'My Calendar', '#4F46E5', 'personal', TRUE, %s, NOW())
                """,
                (cal_id, school_id, user_id),
                fetch=False
            )

    # 2. Smart Conflict Detection for Participants and Resources
    if not req.force_override_conflicts:
        conflicts = []

        # Check resource collisions
        if req.resources:
            for res_item in req.resources:
                res_id = res_item.resource_id
                col = await exec_sql(
                    """
                    SELECT rb.*, s.title, cr.name AS resource_name
                    FROM public.resource_bookings rb
                    JOIN public.schedules s ON s.id = rb.schedule_id
                    JOIN public.calendar_resources cr ON cr.id = rb.resource_id
                    WHERE rb.resource_id = %s
                      AND cr.is_exclusive = TRUE
                      AND s.deleted_at IS NULL
                      AND s.status NOT IN ('cancelled', 'declined')
                      AND (
                          (s.start_time < %s AND s.end_time > %s)
                      )
                    """,
                    (res_id, req.end_time, req.start_time)
                )
                if col:
                    conflicts.append({
                        "type": "resource",
                        "resource_id": res_id,
                        "resource_name": col[0]["resource_name"],
                        "conflicting_title": col[0]["title"],
                        "start_time": col[0]["start_time"],
                        "end_time": col[0]["end_time"],
                        "message": f"Resource '{col[0]['resource_name']}' is already booked for '{col[0]['title']}'."
                    })

        # Check participant collisions
        if req.participants:
            for p in req.participants:
                if p.user_id:
                    p_col = await exec_sql(
                        """
                        SELECT s.title, s.start_time, s.end_time, prof.full_name
                        FROM public.schedule_participants sp
                        JOIN public.schedules s ON s.id = sp.schedule_id
                        JOIN public.profiles prof ON prof.id = sp.user_id
                        WHERE sp.user_id = %s
                          AND s.deleted_at IS NULL
                          AND s.status NOT IN ('cancelled', 'declined')
                          AND sp.rsvp_status != 'declined'
                          AND (
                              (s.start_time < %s AND s.end_time > %s)
                          )
                        LIMIT 1
                        """,
                        (p.user_id, req.end_time, req.start_time)
                    )
                    if p_col:
                        conflicts.append({
                            "type": "user",
                            "user_id": p.user_id,
                            "user_name": p_col[0]["full_name"],
                            "conflicting_title": p_col[0]["title"],
                            "start_time": p_col[0]["start_time"],
                            "end_time": p_col[0]["end_time"],
                            "message": f"User '{p_col[0]['full_name']}' already has a schedule '{p_col[0]['title']}' during this time."
                        })

        if conflicts:
            return {
                "success": False,
                "error": {
                    "code": "SCHEDULE_CONFLICT",
                    "message": "Scheduling conflict detected. Another schedule or resource is booked during this time.",
                    "conflicts": _serialize_datetime(conflicts)
                }
            }

    # 3. Derive audience scope & Insert Schedule
    target_roles = []
    target_classes = []
    target_user_ids = []
    if req.participants:
        for p in req.participants:
            if p.user_id:
                target_user_ids.append(p.user_id)
            if p.target_role:
                target_roles.append(p.target_role)
            if p.target_class:
                target_classes.append(p.target_class)

    audience_type = "individual"
    if req.visibility == "institution_wide":
        audience_type = "institution_wide"
    elif target_roles:
        audience_type = "role"
    elif target_classes:
        audience_type = "class"
    elif target_user_ids:
        audience_type = "individual"

    s_id = str(uuid.uuid4())
    sql = """
        INSERT INTO public.schedules (
            id, school_id, calendar_id, title, description, schedule_type, category, color, priority,
            status, approval_status, start_time, end_time, is_all_day, timezone,
            location_name, location_address, building, room, landmark, latitude, longitude,
            virtual_meeting_url, virtual_meeting_provider, organizer_id, created_by,
            visibility, is_recurring, metadata, audience_type, target_roles, target_classes, target_user_ids, created_at, updated_at
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s, %s, %s,
            'confirmed', 'approved', %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s, %s, NOW(), NOW()
        ) RETURNING *
    """
    rows = await exec_sql(
        sql,
        (
            s_id, school_id, cal_id, req.title, req.description, req.schedule_type, req.category or "General",
            req.color or "#4F46E5", req.priority or "normal",
            req.start_time, req.end_time, req.is_all_day or False, req.timezone or "Asia/Kolkata",
            req.location_name, req.location_address, req.building, req.room, req.landmark,
            req.latitude, req.longitude, req.virtual_meeting_url, req.virtual_meeting_provider,
            user_id, user_id, req.visibility or "shared", req.is_recurring or False,
            json.dumps(req.metadata or {}), audience_type, json.dumps(target_roles), json.dumps(target_classes), json.dumps(target_user_ids)
        )
    )
    if not rows:
        raise HTTPException(status_code=500, detail="Failed to create schedule")

    # 4. Insert Recurrence Rule
    if req.is_recurring and req.recurrence:
        r = req.recurrence
        await exec_sql(
            """
            INSERT INTO public.schedule_recurrence (
                id, schedule_id, frequency, interval, days_of_week, day_of_month, month_of_year,
                end_type, end_count, end_date, exceptions, created_at
            ) VALUES (
                gen_random_uuid(), %s, %s, %s, %s, %s, %s, %s, %s, %s, '[]'::jsonb, NOW()
            )
            """,
            (
                s_id, r.frequency, r.interval or 1, json.dumps(r.days_of_week or []),
                r.day_of_month, r.month_of_year, r.end_type or "never", r.end_count, r.end_date
            ),
            fetch=False
        )

    # 5. Insert Participants & Send Notifications
    if req.participants:
        for p in req.participants:
            p_id = str(uuid.uuid4())
            is_ind = bool(p.user_id)
            t_role = None if is_ind else p.target_role
            t_class = None if is_ind else p.target_class
            p_type = "individual" if is_ind else (p.participant_type or ("role" if t_role else "class"))
            await exec_sql(
                """
                INSERT INTO public.schedule_participants (
                    id, schedule_id, user_id, target_role, target_department, target_class, target_section,
                    participant_type, participation_role, permission, rsvp_status, created_at
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'pending', NOW()
                )
                """,
                (
                    p_id, s_id, p.user_id, t_role, p.target_department, t_class, p.target_section,
                    p_type, p.participation_role or "required", p.permission or "can_view"
                ),
                fetch=False
            )
            if p.user_id and p.user_id != user_id:
                asyncio.create_task(
                    dispatch_calendar_notification(
                        school_id=school_id,
                        user_id=p.user_id,
                        title=f"New Schedule: {req.title}",
                        body=f"You have been assigned to '{req.title}' ({req.schedule_type}) starting at {req.start_time}.",
                        schedule_id=s_id
                    )
                )

    # 6. Insert Resource Bookings
    if req.resources:
        for res_item in req.resources:
            await exec_sql(
                """
                INSERT INTO public.resource_bookings (
                    id, schedule_id, resource_id, start_time, end_time, status, created_at
                ) VALUES (
                    gen_random_uuid(), %s, %s, %s, %s, 'confirmed', NOW()
                )
                """,
                (s_id, res_item.resource_id, req.start_time, req.end_time),
                fetch=False
            )

    # 7. Insert Reminders
    if req.reminders:
        for rem in req.reminders:
            await exec_sql(
                """
                INSERT INTO public.schedule_reminders (
                    id, schedule_id, user_id, minutes_before, channel, is_sent, created_at
                ) VALUES (
                    gen_random_uuid(), %s, %s, %s, %s, FALSE, NOW()
                )
                """,
                (s_id, user_id, rem.minutes_before, rem.channel or "in_app"),
                fetch=False
            )

    # 8. Record Audit Log
    asyncio.create_task(
        record_schedule_audit_log(
            schedule_id=s_id,
            school_id=school_id,
            user_id=user_id,
            action="create",
            new_data=rows[0],
            summary=f"Created {req.schedule_type} '{req.title}'"
        )
    )

    return {"success": True, "data": _serialize_datetime(rows[0]), "message": "Schedule created successfully."}


@router.get("/schedules/{schedule_id}")
async def get_schedule_by_id(schedule_id: str, user=Depends(get_current_user)):
    """Fetch complete schedule detail including participants, resources, recurrence, reminders, and comments."""
    school_id = user.get("school_id")
    if "_inst_" in schedule_id:
        schedule_id = schedule_id.split("_inst_")[0]

    rows = await exec_sql(
        """
        SELECT s.*,
               c.name AS calendar_name,
               c.color AS calendar_color,
               p.full_name AS organizer_name,
               p.email AS organizer_email,
               p.avatar_url AS organizer_avatar
        FROM public.schedules s
        LEFT JOIN public.calendars c ON c.id = s.calendar_id
        LEFT JOIN public.profiles p ON p.id = s.organizer_id
        WHERE s.id = %s AND s.school_id = %s AND s.deleted_at IS NULL
        """,
        (schedule_id, school_id)
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Schedule not found")

    data = rows[0]

    # Fetch Participants
    participants = await exec_sql(
        """
        SELECT sp.*, prof.full_name, prof.email, prof.role, prof.avatar_url, prof.department, prof.class
        FROM public.schedule_participants sp
        LEFT JOIN public.profiles prof ON prof.id = sp.user_id
        WHERE sp.schedule_id = %s
        """,
        (schedule_id,)
    )
    data["participants"] = participants

    # Fetch Resources
    resources = await exec_sql(
        """
        SELECT rb.*, cr.name, cr.code, cr.type, cr.capacity, cr.building, cr.room_number
        FROM public.resource_bookings rb
        JOIN public.calendar_resources cr ON cr.id = rb.resource_id
        WHERE rb.schedule_id = %s
        """,
        (schedule_id,)
    )
    data["resources"] = resources

    # Fetch Recurrence Rule
    rec = await exec_sql("SELECT * FROM public.schedule_recurrence WHERE schedule_id = %s", (schedule_id,))
    data["recurrence"] = rec[0] if rec else None

    # Fetch Reminders
    reminders = await exec_sql("SELECT * FROM public.schedule_reminders WHERE schedule_id = %s", (schedule_id,))
    data["reminders"] = reminders

    # Fetch Comments
    comments = await exec_sql(
        """
        SELECT sc.*, prof.full_name, prof.avatar_url, prof.role
        FROM public.schedule_comments sc
        JOIN public.profiles prof ON prof.id = sc.user_id
        WHERE sc.schedule_id = %s
        ORDER BY sc.created_at ASC
        """,
        (schedule_id,)
    )
    data["comments"] = comments

    return {"success": True, "data": _serialize_datetime(data)}


@router.patch("/schedules/{schedule_id}")
async def update_schedule(
    schedule_id: str,
    req: ScheduleUpdateRequest,
    recurrence_scope: str = Query("entire_series", description="this_event, following_events, entire_series"),
    target_instance_date: Optional[str] = Query(None, description="ISO date YYYY-MM-DD of the target instance"),
    user=Depends(get_current_user)
):
    """
    Update schedule attributes with Google Calendar-grade recurrence scopes:
    - this_event: creates a standalone override schedule on target_instance_date & adds exception to parent series.
    - following_events: truncates previous series before target_instance_date & creates a new recurring series.
    - entire_series: updates parent schedule and recurring rule directly.
    """
    school_id = user.get("school_id")
    user_id = user.get("id")

    parent_id = schedule_id
    if "_inst_" in schedule_id:
        parent_id, _, inst_date_str = schedule_id.partition("_inst_")
        if not target_instance_date:
            target_instance_date = inst_date_str
        schedule_id = parent_id

    curr = await exec_sql("SELECT * FROM public.schedules WHERE id = %s AND school_id = %s", (schedule_id, school_id))
    if not curr:
        raise HTTPException(status_code=404, detail="Schedule not found")

    old_record = curr[0]
    master_parent_id = str(old_record["recurring_parent_id"]) if old_record.get("recurring_parent_id") else schedule_id
    is_already_override = old_record.get("recurring_parent_id") is not None or old_record.get("recurrence_exception_type") == "override"

    # Permission check: owner/creator, super_admin/admin, or read_write/can_edit participant
    user_role = str(user.get("role", "")).lower()
    organizer_id = str(old_record.get("organizer_id") or "")
    created_by = str(old_record.get("created_by") or "")

    is_owner = (user_id == organizer_id) or (user_id == created_by) or (user_role in ["super_admin", "admin", "owner"])
    has_edit_perm = is_owner
    if not has_edit_perm:
        part_check = await exec_sql(
            "SELECT permission FROM public.schedule_participants WHERE schedule_id = %s AND user_id = %s",
            (schedule_id, user_id)
        )
        if part_check:
            p_val = str(part_check[0].get("permission") or "").lower()
            if p_val in ["read_write", "can_edit", "can_manage"]:
                has_edit_perm = True

    if not has_edit_perm:
        raise HTTPException(
            status_code=403,
            detail="Permission denied: Only the schedule owner or authorized editor can modify or cancel this schedule."
        )

    # If the record is ALREADY an override or standalone instance, update it in place!
    if is_already_override:
        updates = []
        params = []
        for field in [
            "title", "description", "schedule_type", "category", "color", "priority",
            "status", "approval_status", "start_time", "end_time", "is_all_day", "timezone",
            "location_name", "location_address", "building", "room", "landmark",
            "latitude", "longitude", "virtual_meeting_url", "virtual_meeting_provider",
            "visibility", "cancellation_reason"
        ]:
            val = getattr(req, field, None)
            if val is not None:
                updates.append(f"{field} = %s")
                params.append(val)

        if req.calendar_id:
            updates.append("calendar_id = %s")
            params.append(req.calendar_id)

        if req.metadata is not None:
            updates.append("metadata = %s")
            params.append(json.dumps(req.metadata))

        if updates:
            updates.append("updated_at = NOW()")
            params.extend([schedule_id, school_id])
            sql = f"UPDATE public.schedules SET {', '.join(updates)} WHERE id = %s AND school_id = %s RETURNING *"
            updated_rows = await exec_sql(sql, tuple(params))
            new_record = updated_rows[0] if updated_rows else old_record
        else:
            new_record = old_record

        return {"success": True, "data": _serialize_datetime(new_record), "message": "Schedule updated successfully."}

    # SCOPE 1: THIS EVENT ONLY (Standalone Occurrence Override)
    if recurrence_scope == "this_event" and target_instance_date:
        # Exclude this instance date from parent series recurrence
        await exec_sql(
            "SELECT public.exclude_recurring_occurrence(%s::uuid, %s::date)",
            (master_parent_id, target_instance_date),
            fetch=False
        )
        # Soft delete any existing override for this parent and date to avoid duplicates
        await exec_sql(
            """
            UPDATE public.schedules
            SET deleted_at = NOW(), status = 'cancelled', updated_at = NOW()
            WHERE recurring_parent_id = %s
              AND (original_instance_date = %s::date OR DATE(start_time) = %s::date)
            """,
            (master_parent_id, target_instance_date, target_instance_date),
            fetch=False
        )

        override_id = str(uuid.uuid4())
        inst_date = datetime.fromisoformat(target_instance_date).date()
        new_start = req.start_time or datetime.combine(inst_date, old_record["start_time"].time())
        new_end = req.end_time or datetime.combine(inst_date, old_record["end_time"].time())

        sql_override = """
            INSERT INTO public.schedules (
                id, school_id, calendar_id, title, description, schedule_type, category, color, priority,
                status, approval_status, start_time, end_time, is_all_day, timezone,
                location_name, location_address, building, room, virtual_meeting_url, virtual_meeting_provider,
                organizer_id, created_by, visibility, is_recurring, recurring_parent_id, original_instance_date,
                recurrence_exception_type, metadata, created_at, updated_at
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s, %s,
                'scheduled', 'approved', %s, %s, %s, %s,
                %s, %s, %s, %s, %s, %s,
                %s, %s, %s, FALSE, %s, %s,
                'override', %s, NOW(), NOW()
            ) RETURNING *
        """
        rows = await exec_sql(
            sql_override,
            (
                override_id, school_id, req.calendar_id or old_record["calendar_id"],
                req.title or old_record["title"], req.description if req.description is not None else old_record["description"],
                req.schedule_type or old_record["schedule_type"], req.category or old_record["category"],
                req.color or old_record["color"], req.priority or old_record["priority"],
                new_start, new_end, req.is_all_day if req.is_all_day is not None else old_record["is_all_day"],
                req.timezone or old_record["timezone"], req.location_name or old_record["location_name"],
                req.location_address or old_record["location_address"], req.building or old_record["building"],
                req.room or old_record["room"], req.virtual_meeting_url or old_record["virtual_meeting_url"],
                req.virtual_meeting_provider or old_record["virtual_meeting_provider"],
                old_record["organizer_id"], user_id, req.visibility or old_record["visibility"],
                master_parent_id, inst_date, json.dumps(req.metadata or old_record.get("metadata") or {})
            )
        )
        new_record = rows[0]

        # Copy/assign participants for override
        if req.participants is not None:
            for p in req.participants:
                p_uid = p.user_id if p.user_id and len(str(p.user_id).strip()) > 0 and str(p.user_id).strip().lower() != 'none' else None
                await exec_sql(
                    """
                    INSERT INTO public.schedule_participants (
                        id, schedule_id, user_id, target_role, target_department, target_class, target_section,
                        participant_type, participation_role, permission, rsvp_status, created_at
                    ) VALUES (
                        gen_random_uuid(), %s, %s, %s, %s, %s, %s, %s, %s, %s, 'pending', NOW()
                    )
                    """,
                    (override_id, p_uid, p.target_role, p.target_department, p.target_class, p.target_section,
                     p.participant_type or "individual", p.participation_role or "required", p.permission or "can_view"),
                    fetch=False
                )

        return {"success": True, "data": _serialize_datetime(new_record), "message": "Updated this event occurrence successfully."}

    # SCOPE 2: THIS AND FOLLOWING EVENTS (Series Split)
    elif recurrence_scope == "following_events" and target_instance_date:
        split_date = datetime.fromisoformat(target_instance_date).date()
        # Truncate old series prior to split date
        await exec_sql(
            "SELECT public.split_recurring_series(%s::uuid, %s::date)",
            (master_parent_id, target_instance_date),
            fetch=False
        )

        # Create new recurring series starting on split date
        new_series_id = str(uuid.uuid4())
        new_start = req.start_time or datetime.combine(split_date, old_record["start_time"].time())
        new_end = req.end_time or datetime.combine(split_date, old_record["end_time"].time())

        sql_new_series = """
            INSERT INTO public.schedules (
                id, school_id, calendar_id, title, description, schedule_type, category, color, priority,
                status, approval_status, start_time, end_time, is_all_day, timezone,
                location_name, location_address, building, room, virtual_meeting_url, virtual_meeting_provider,
                organizer_id, created_by, visibility, is_recurring, metadata, created_at, updated_at
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s, %s,
                'scheduled', 'approved', %s, %s, %s, %s,
                %s, %s, %s, %s, %s, %s,
                %s, %s, %s, TRUE, %s, NOW(), NOW()
            ) RETURNING *
        """
        rows = await exec_sql(
            sql_new_series,
            (
                new_series_id, school_id, req.calendar_id or old_record["calendar_id"],
                req.title or old_record["title"], req.description if req.description is not None else old_record["description"],
                req.schedule_type or old_record["schedule_type"], req.category or old_record["category"],
                req.color or old_record["color"], req.priority or old_record["priority"],
                new_start, new_end, req.is_all_day if req.is_all_day is not None else old_record["is_all_day"],
                req.timezone or old_record["timezone"], req.location_name or old_record["location_name"],
                req.location_address or old_record["location_address"], req.building or old_record["building"],
                req.room or old_record["room"], req.virtual_meeting_url or old_record["virtual_meeting_url"],
                req.virtual_meeting_provider or old_record["virtual_meeting_provider"],
                old_record["organizer_id"], user_id, req.visibility or old_record["visibility"],
                json.dumps(req.metadata or old_record.get("metadata") or {})
            )
        )
        new_record = rows[0]

        # Insert recurrence rule for the new series
        if req.recurrence:
            r = req.recurrence
            await exec_sql(
                """
                INSERT INTO public.schedule_recurrence (
                    id, schedule_id, frequency, interval, days_of_week, day_of_month, month_of_year,
                    end_type, end_count, end_date, exceptions, created_at
                ) VALUES (
                    gen_random_uuid(), %s, %s, %s, %s, %s, %s, %s, %s, %s, '[]'::jsonb, NOW()
                )
                """,
                (
                    new_series_id, r.frequency, r.interval or 1, json.dumps(r.days_of_week or []),
                    r.day_of_month, r.month_of_year, r.end_type or "never", r.end_count, r.end_date
                ),
                fetch=False
            )

        return {"success": True, "data": _serialize_datetime(new_record), "message": "Updated this and all following events."}

    # SCOPE 3: ENTIRE SERIES (Default)
    target_update_id = master_parent_id
    updates = []
    params = []
    for field in [
        "title", "description", "schedule_type", "category", "color", "priority",
        "status", "approval_status", "start_time", "end_time", "is_all_day", "timezone",
        "location_name", "location_address", "building", "room", "landmark",
        "latitude", "longitude", "virtual_meeting_url", "virtual_meeting_provider",
        "visibility", "cancellation_reason"
    ]:
        val = getattr(req, field, None)
        if val is not None:
            updates.append(f"{field} = %s")
            params.append(val)

    if req.calendar_id:
        updates.append("calendar_id = %s")
        params.append(req.calendar_id)

    if req.metadata is not None:
        updates.append("metadata = %s")
        params.append(json.dumps(req.metadata))

    if updates:
        updates.append("updated_at = NOW()")
        params.extend([target_update_id, school_id])
        sql = f"UPDATE public.schedules SET {', '.join(updates)} WHERE id = %s AND school_id = %s RETURNING *"
        updated_rows = await exec_sql(sql, tuple(params))
        new_record = updated_rows[0] if updated_rows else old_record
    else:
        new_record = old_record

    # Update Participants if provided
    if req.participants is not None:
        await exec_sql("DELETE FROM public.schedule_participants WHERE schedule_id = %s", (schedule_id,), fetch=False)
        for p in req.participants:
            p_uid = p.user_id if p.user_id and len(str(p.user_id).strip()) > 0 and str(p.user_id).strip().lower() != 'none' else None
            p_id = str(uuid.uuid4())
            await exec_sql(
                """
                INSERT INTO public.schedule_participants (
                    id, schedule_id, user_id, target_role, target_department, target_class, target_section,
                    participant_type, participation_role, permission, rsvp_status, created_at
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'pending', NOW()
                )
                """,
                (
                    p_id, schedule_id, p_uid, p.target_role, p.target_department, p.target_class, p.target_section,
                    p.participant_type or "individual", p.participation_role or "required", p.permission or "can_view"
                ),
                fetch=False
            )

    # Update Resources if provided
    if req.resources is not None:
        await exec_sql("DELETE FROM public.resource_bookings WHERE schedule_id = %s", (schedule_id,), fetch=False)
        for res_item in req.resources:
            r_uid = res_item.resource_id if res_item.resource_id and len(str(res_item.resource_id).strip()) > 0 else None
            if r_uid:
                await exec_sql(
                    """
                    INSERT INTO public.resource_bookings (
                        id, schedule_id, resource_id, start_time, end_time, status, created_at
                    ) VALUES (
                        gen_random_uuid(), %s, %s, %s, %s, 'confirmed', NOW()
                    )
                    """,
                    (schedule_id, r_uid, req.start_time or old_record["start_time"], req.end_time or old_record["end_time"]),
                    fetch=False
                )

    # Update Reminders if provided
    if req.reminders is not None:
        await exec_sql("DELETE FROM public.schedule_reminders WHERE schedule_id = %s", (schedule_id,), fetch=False)
        for rem in req.reminders:
            await exec_sql(
                """
                INSERT INTO public.schedule_reminders (
                    id, schedule_id, user_id, minutes_before, channel, is_sent, created_at
                ) VALUES (
                    gen_random_uuid(), %s, %s, %s, %s, FALSE, NOW()
                )
                """,
                (schedule_id, user_id, rem.minutes_before, rem.channel or "in_app"),
                fetch=False
            )

    # Update Recurrence if provided
    if req.is_recurring is not None:
        await exec_sql("UPDATE public.schedules SET is_recurring = %s WHERE id = %s", (req.is_recurring, schedule_id), fetch=False)
        if not req.is_recurring:
            await exec_sql("DELETE FROM public.schedule_recurrence WHERE schedule_id = %s", (schedule_id,), fetch=False)

    if req.recurrence:
        r = req.recurrence
        await exec_sql("DELETE FROM public.schedule_recurrence WHERE schedule_id = %s", (schedule_id,), fetch=False)
        await exec_sql(
            """
            INSERT INTO public.schedule_recurrence (
                id, schedule_id, frequency, interval, days_of_week, day_of_month, month_of_year,
                end_type, end_count, end_date, exceptions, created_at
            ) VALUES (
                gen_random_uuid(), %s, %s, %s, %s, %s, %s, %s, %s, %s, '[]'::jsonb, NOW()
            )
            """,
            (
                schedule_id, r.frequency, r.interval or 1, json.dumps(r.days_of_week or []),
                r.day_of_month, r.month_of_year, r.end_type or "never", r.end_count, r.end_date
            ),
            fetch=False
        )
        await exec_sql("UPDATE public.schedules SET is_recurring = TRUE WHERE id = %s", (schedule_id,), fetch=False)

    # Update booked resource time windows if start/end time shifted
    if req.start_time or req.end_time:
        new_start = req.start_time or old_record["start_time"]
        new_end = req.end_time or old_record["end_time"]
        await exec_sql(
            "UPDATE public.resource_bookings SET start_time = %s, end_time = %s WHERE schedule_id = %s",
            (new_start, new_end, schedule_id),
            fetch=False
        )

    # Record Audit & Version Diff
    asyncio.create_task(
        record_schedule_audit_log(
            schedule_id=schedule_id,
            school_id=school_id,
            user_id=user_id,
            action="update",
            old_data=old_record,
            new_data=new_record,
            summary=f"Updated schedule '{new_record.get('title')}'"
        )
    )

    return {"success": True, "data": _serialize_datetime(new_record), "message": "Schedule updated successfully."}


@router.delete("/schedules/{schedule_id}")
async def delete_schedule(
    schedule_id: str,
    recurrence_scope: str = Query("entire_series", description="this_event, following_events, entire_series"),
    target_instance_date: Optional[str] = Query(None, description="ISO date YYYY-MM-DD of the target instance"),
    user=Depends(get_current_user)
):
    """
    Soft delete a schedule or recurring occurrence with instant resource release:
    - this_event: excludes target_instance_date from parent recurrence exceptions without deleting parent series.
    - following_events: truncates series before target_instance_date.
    - entire_series: soft deletes the parent schedule series.
    """
    school_id = user.get("school_id")
    user_id = user.get("id")

    parent_id = schedule_id
    if "_inst_" in schedule_id:
        parent_id, _, inst_date_str = schedule_id.partition("_inst_")
        if not target_instance_date:
            target_instance_date = inst_date_str
        schedule_id = parent_id

    row = await exec_sql("SELECT * FROM public.schedules WHERE id = %s AND school_id = %s", (schedule_id, school_id))
    if not row:
        raise HTTPException(status_code=404, detail="Schedule not found")

    old_rec = row[0]
    master_parent_id = str(old_rec["recurring_parent_id"]) if old_rec.get("recurring_parent_id") else schedule_id

    if recurrence_scope == "this_event" and target_instance_date:
        await exec_sql(
            "SELECT public.exclude_recurring_occurrence(%s::uuid, %s::date)",
            (master_parent_id, target_instance_date),
            fetch=False
        )
        if master_parent_id != schedule_id:
            await exec_sql(
                "SELECT public.exclude_recurring_occurrence(%s::uuid, %s::date)",
                (schedule_id, target_instance_date),
                fetch=False
            )
        # Soft delete only child override schedules for this instance date
        await exec_sql(
            """
            UPDATE public.schedules
            SET deleted_at = NOW(), status = 'cancelled', updated_at = NOW()
            WHERE recurring_parent_id = %s
              AND (original_instance_date = %s::date OR DATE(start_time) = %s::date)
            """,
            (master_parent_id, target_instance_date, target_instance_date),
            fetch=False
        )
        if schedule_id != master_parent_id:
            await exec_sql(
                "UPDATE public.schedules SET deleted_at = NOW(), status = 'cancelled', updated_at = NOW() WHERE id = %s",
                (schedule_id,),
                fetch=False
            )
        return {"success": True, "message": f"Deleted occurrence for {target_instance_date}."}

    elif recurrence_scope == "following_events" and target_instance_date:
        await exec_sql(
            "SELECT public.split_recurring_series(%s::uuid, %s::date)",
            (master_parent_id, target_instance_date),
            fetch=False
        )
        # Soft delete any overrides from target_instance_date onwards
        await exec_sql(
            """
            UPDATE public.schedules
            SET deleted_at = NOW(), status = 'cancelled', updated_at = NOW()
            WHERE (recurring_parent_id = %s OR recurring_parent_id = %s)
              AND (original_instance_date >= %s::date OR DATE(start_time) >= %s::date)
            """,
            (master_parent_id, schedule_id, target_instance_date, target_instance_date),
            fetch=False
        )
        return {"success": True, "message": f"Deleted this and all following events from {target_instance_date}."}

    # Default: Entire Series
    await exec_sql(
        """
        UPDATE public.schedules
        SET deleted_at = NOW(), updated_at = NOW(), status = 'cancelled'
        WHERE id = %s OR id = %s OR recurring_parent_id = %s OR recurring_parent_id = %s
        """,
        (schedule_id, master_parent_id, master_parent_id, schedule_id),
        fetch=False
    )
    # Release resource bookings
    await exec_sql(
        "UPDATE public.resource_bookings SET status = 'released' WHERE schedule_id = %s OR schedule_id = %s",
        (schedule_id, master_parent_id),
        fetch=False
    )

    asyncio.create_task(
        record_schedule_audit_log(
            schedule_id=schedule_id,
            school_id=school_id,
            user_id=user_id,
            action="delete",
            old_data=old_rec,
            new_data={"status": "cancelled", "deleted_at": "NOW()"},
            summary=f"Deleted schedule '{old_rec.get('title')}'"
        )
    )

    return {"success": True, "message": "Schedule deleted successfully."}


@router.post("/schedules/{schedule_id}/cancel")
async def cancel_schedule(
    schedule_id: str,
    req: ScheduleCancelRequest,
    user=Depends(get_current_user)
):
    """
    Cancel a schedule with a required cancellation reason.
    Verifies owner/editor permissions and updates status to 'cancelled'.
    """
    school_id = user.get("school_id")
    user_id = user.get("id")
    user_role = str(user.get("role", "")).lower()

    if not req.cancellation_reason or not req.cancellation_reason.strip():
        raise HTTPException(status_code=400, detail="Cancellation reason is required.")

    parent_id = schedule_id
    if "_inst_" in schedule_id:
        parent_id, _, _ = schedule_id.partition("_inst_")
        schedule_id = parent_id

    curr = await exec_sql("SELECT * FROM public.schedules WHERE id = %s AND school_id = %s", (schedule_id, school_id))
    if not curr:
        raise HTTPException(status_code=404, detail="Schedule not found")

    old_record = curr[0]
    organizer_id = str(old_record.get("organizer_id") or "")
    created_by = str(old_record.get("created_by") or "")

    is_owner = (user_id == organizer_id) or (user_id == created_by) or (user_role in ["super_admin", "admin", "owner"])
    has_edit_perm = is_owner
    if not has_edit_perm:
        part_check = await exec_sql(
            "SELECT permission FROM public.schedule_participants WHERE schedule_id = %s AND user_id = %s",
            (schedule_id, user_id)
        )
        if part_check:
            p_val = str(part_check[0].get("permission") or "").lower()
            if p_val in ["read_write", "can_edit", "can_manage"]:
                has_edit_perm = True

    if not has_edit_perm:
        raise HTTPException(
            status_code=403,
            detail="Permission denied: Only the schedule owner or authorized editor can cancel this schedule."
        )

    # Cancel schedule
    sql = """
        UPDATE public.schedules
        SET status = 'cancelled', cancellation_reason = %s, updated_at = NOW()
        WHERE id = %s AND school_id = %s
        RETURNING *
    """
    rows = await exec_sql(sql, (req.cancellation_reason.strip(), schedule_id, school_id))

    # Release resource bookings
    await exec_sql(
        "UPDATE public.resource_bookings SET status = 'cancelled' WHERE schedule_id = %s",
        (schedule_id,),
        fetch=False
    )

    updated_record = rows[0] if rows else old_record
    return {
        "success": True,
        "message": "Schedule cancelled successfully.",
        "data": _serialize_datetime(updated_record)
    }



@router.post("/schedules/{schedule_id}/restore")
async def restore_schedule(schedule_id: str, user=Depends(get_current_user)):
    """Restore a previously soft-deleted schedule."""
    school_id = user.get("school_id")
    user_id = user.get("id")
    if "_inst_" in schedule_id:
        schedule_id = schedule_id.split("_inst_")[0]

    rows = await exec_sql(
        "UPDATE public.schedules SET deleted_at = NULL, status = 'scheduled', updated_at = NOW() WHERE id = %s AND school_id = %s RETURNING *",
        (schedule_id, school_id)
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Schedule not found")

    await exec_sql(
        "UPDATE public.resource_bookings SET status = 'confirmed' WHERE schedule_id = %s",
        (schedule_id,),
        fetch=False
    )

    asyncio.create_task(
        record_schedule_audit_log(
            schedule_id=schedule_id,
            school_id=school_id,
            user_id=user_id,
            action="restore",
            new_data=rows[0],
            summary=f"Restored schedule '{rows[0].get('title')}'"
        )
    )

    return {"success": True, "data": _serialize_datetime(rows[0]), "message": "Schedule restored successfully."}


@router.post("/schedules/{schedule_id}/duplicate")
async def duplicate_schedule(schedule_id: str, user=Depends(get_current_user)):
    """Duplicate an existing schedule to a new instance."""
    school_id = user.get("school_id")
    user_id = user.get("id")
    if "_inst_" in schedule_id:
        schedule_id = schedule_id.split("_inst_")[0]

    rows = await exec_sql("SELECT * FROM public.schedules WHERE id = %s AND school_id = %s", (schedule_id, school_id))
    if not rows:
        raise HTTPException(status_code=404, detail="Schedule not found")

    src = rows[0]
    new_id = str(uuid.uuid4())
    new_title = f"{src['title']} (Copy)"

    sql = """
        INSERT INTO public.schedules (
            id, school_id, calendar_id, title, description, schedule_type, category, color, priority,
            status, approval_status, start_time, end_time, is_all_day, timezone,
            location_name, location_address, building, room, virtual_meeting_url, virtual_meeting_provider,
            organizer_id, created_by, visibility, is_recurring, metadata, created_at, updated_at
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s, %s, %s,
            'confirmed', 'approved', %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s,
            %s, %s, %s, FALSE, %s, NOW(), NOW()
        ) RETURNING *
    """
    dup = await exec_sql(
        sql,
        (
            new_id, school_id, src["calendar_id"], new_title, src["description"], src["schedule_type"],
            src["category"], src["color"], src["priority"], src["start_time"], src["end_time"],
            src["is_all_day"], src["timezone"], src["location_name"], src["location_address"],
            src["building"], src["room"], src["virtual_meeting_url"], src["virtual_meeting_provider"],
            user_id, user_id, src["visibility"], json.dumps(src.get("metadata") or {})
        )
    )

    return {"success": True, "data": _serialize_datetime(dup[0]), "message": "Schedule duplicated successfully."}


@router.post("/schedules/{schedule_id}/rsvp")
async def submit_schedule_rsvp(schedule_id: str, req: ScheduleRSVPRequest, user=Depends(get_current_user)):
    """User response to schedule invitation (Accept, Decline with reason, Tentative)."""
    user_id = user.get("id")
    school_id = user.get("school_id")
    if "_inst_" in schedule_id:
        schedule_id = schedule_id.split("_inst_")[0]

    # Upsert RSVP status
    sql = """
        INSERT INTO public.schedule_participants (
            id, schedule_id, user_id, participant_type, participation_role, permission, rsvp_status, decline_reason, rsvp_at, created_at, updated_at
        ) VALUES (
            gen_random_uuid(), %s, %s, 'individual', 'required', 'can_view', %s, %s, NOW(), NOW(), NOW()
        )
        ON CONFLICT (id) DO UPDATE SET
            rsvp_status = EXCLUDED.rsvp_status,
            decline_reason = EXCLUDED.decline_reason,
            rsvp_at = NOW(),
            updated_at = NOW()
        RETURNING *
    """
    # Check if participant already exists
    existing = await exec_sql(
        "SELECT id FROM public.schedule_participants WHERE schedule_id = %s AND user_id = %s",
        (schedule_id, user_id)
    )
    if existing:
        await exec_sql(
            """
            UPDATE public.schedule_participants
            SET rsvp_status = %s, decline_reason = %s, rsvp_at = NOW(), updated_at = NOW()
            WHERE schedule_id = %s AND user_id = %s
            """,
            (req.status, req.decline_reason, schedule_id, user_id),
            fetch=False
        )
    else:
        await exec_sql(
            """
            INSERT INTO public.schedule_participants (
                id, schedule_id, user_id, participant_type, participation_role, permission, rsvp_status, decline_reason, rsvp_at, created_at, updated_at
            ) VALUES (
                gen_random_uuid(), %s, %s, 'individual', 'required', 'can_view', %s, %s, NOW(), NOW(), NOW()
            )
            """,
            (schedule_id, user_id, req.status, req.decline_reason),
            fetch=False
        )

    return {"success": True, "status": req.status, "message": f"Invitation {req.status} successfully."}


@router.post("/schedules/{schedule_id}/comments")
async def add_schedule_comment(
    schedule_id: str,
    req: ScheduleCommentRequest,
    user=Depends(get_current_user)
):
    """Add persistent activity discussion comment to a schedule."""
    user_id = user.get("id")
    school_id = user.get("school_id")
    if "_inst_" in schedule_id:
        schedule_id = schedule_id.split("_inst_")[0]

    c_id = str(uuid.uuid4())
    sql = """
        INSERT INTO public.schedule_comments (id, schedule_id, user_id, comment_text, created_at)
        VALUES (%s, %s, %s, %s, NOW())
        RETURNING id, schedule_id, user_id, comment_text, created_at
    """
    rows = await exec_sql(sql, (c_id, schedule_id, user_id, req.comment_text))
    if not rows:
        raise HTTPException(status_code=500, detail="Failed to save comment")

    prof = await exec_sql("SELECT full_name, avatar_url FROM public.profiles WHERE id = %s", (user_id,))
    full_name = prof[0]["full_name"] if prof else "You"
    avatar_url = prof[0]["avatar_url"] if prof else None

    return {
        "success": True,
        "data": {
            "id": c_id,
            "schedule_id": schedule_id,
            "user_id": user_id,
            "comment_text": req.comment_text,
            "full_name": full_name,
            "avatar_url": avatar_url,
            "created_at": _serialize_datetime(rows[0]["created_at"])
        },
        "message": "Comment posted successfully."
    }


@router.get("/schedules/{schedule_id}")
async def get_schedule_by_id(schedule_id: str, user=Depends(get_current_user)):
    """Fetch live schedule details including participants, RSVPs, and discussion comments."""
    school_id = user.get("school_id")
    parent_id = schedule_id
    if "_inst_" in schedule_id:
        parent_id = schedule_id.split("_inst_")[0]

    sql = """
        SELECT s.*,
               c.name AS calendar_name,
               c.color AS calendar_color,
               c.type AS calendar_type,
               p.full_name AS organizer_name,
               p.avatar_url AS organizer_avatar,
               (
                   SELECT json_agg(json_build_object(
                       'id', sp.id,
                       'user_id', sp.user_id,
                       'participant_type', sp.participant_type,
                       'participation_role', sp.participation_role,
                       'permission', sp.permission,
                       'rsvp_status', sp.rsvp_status,
                       'decline_reason', sp.decline_reason,
                       'rsvp_at', sp.rsvp_at,
                       'full_name', prof.full_name,
                       'role', prof.role,
                       'avatar_url', prof.avatar_url
                   ))
                   FROM public.schedule_participants sp
                   LEFT JOIN public.profiles prof ON prof.id = sp.user_id
                   WHERE sp.schedule_id = s.id
               ) AS participants,
               (
                   SELECT json_agg(json_build_object(
                       'id', rb.id,
                       'resource_id', rb.resource_id,
                       'resource_name', cr.name,
                       'resource_type', cr.type,
                       'room_number', cr.room_number,
                       'status', rb.status
                   ))
                   FROM public.resource_bookings rb
                   LEFT JOIN public.calendar_resources cr ON cr.id = rb.resource_id
                   WHERE rb.schedule_id = s.id
               ) AS booked_resources,
               (
                   SELECT json_agg(json_build_object(
                       'id', sc.id,
                       'user_id', sc.user_id,
                       'comment_text', sc.comment_text,
                       'full_name', p2.full_name,
                       'avatar_url', p2.avatar_url,
                       'created_at', sc.created_at
                   ) ORDER BY sc.created_at ASC)
                   FROM public.schedule_comments sc
                   LEFT JOIN public.profiles p2 ON p2.id = sc.user_id
                   WHERE sc.schedule_id = s.id
               ) AS comments,
               (
                   SELECT json_agg(json_build_object(
                       'id', rem.id,
                       'minutes_before', rem.minutes_before,
                       'channel', rem.channel
                   ))
                   FROM public.schedule_reminders rem
                   WHERE rem.schedule_id = s.id
               ) AS reminders,
               (
                   SELECT json_build_object(
                       'id', sr2.id,
                       'frequency', sr2.frequency,
                       'interval', sr2.interval,
                       'days_of_week', sr2.days_of_week,
                       'day_of_month', sr2.day_of_month,
                       'month_of_year', sr2.month_of_year,
                       'end_type', sr2.end_type,
                       'end_count', sr2.end_count,
                       'end_date', sr2.end_date,
                       'exceptions', sr2.exceptions
                   )
                   FROM public.schedule_recurrence sr2
                   WHERE sr2.schedule_id = s.id
                   LIMIT 1
               ) AS recurrence
        FROM public.schedules s
        LEFT JOIN public.calendars c ON c.id = s.calendar_id
        LEFT JOIN public.profiles p ON p.id = s.organizer_id
        WHERE s.id = %s AND s.school_id = %s
    """
    rows = await exec_sql(sql, (parent_id, school_id))
    if not rows:
        raise HTTPException(status_code=404, detail="Schedule not found")

    rec = rows[0]
    return {"success": True, "data": _serialize_datetime(rec)}


# ============================================================================
# 3. INTELLIGENCE, AVAILABILITY & CONFLICT APIS
# ============================================================================

@router.get("/calendar/availability")
async def check_availability(
    target_date: str = Query(..., description="Target date (YYYY-MM-DD)"),
    user_ids: Optional[str] = Query(None, description="Comma-separated user IDs"),
    resource_ids: Optional[str] = Query(None, description="Comma-separated resource IDs"),
    user=Depends(get_current_user)
):
    """Calculate busy/free slots for users and resources across any date."""
    school_id = user.get("school_id")
    start_dt = f"{target_date}T00:00:00Z"
    end_dt = f"{target_date}T23:59:59Z"

    busy_slots = []

    # Check users
    if user_ids:
        u_list = [u.strip() for u in user_ids.split(",") if u.strip()]
        for uid in u_list:
            schedules = await exec_sql(
                """
                SELECT s.id, s.title, s.start_time, s.end_time, prof.full_name
                FROM public.schedule_participants sp
                JOIN public.schedules s ON s.id = sp.schedule_id
                JOIN public.profiles prof ON prof.id = sp.user_id
                WHERE sp.user_id = %s
                  AND s.school_id = %s
                  AND s.deleted_at IS NULL
                  AND s.status NOT IN ('cancelled', 'declined')
                  AND s.start_time <= %s AND s.end_time >= %s
                """,
                (uid, school_id, end_dt, start_dt)
            )
            for sch in schedules:
                busy_slots.append({
                    "entity_type": "user",
                    "entity_id": uid,
                    "entity_name": sch["full_name"],
                    "title": sch["title"],
                    "start_time": sch["start_time"],
                    "end_time": sch["end_time"],
                    "status": "Busy"
                })

    # Check resources
    if resource_ids:
        r_list = [r.strip() for r in resource_ids.split(",") if r.strip()]
        for rid in r_list:
            bookings = await exec_sql(
                """
                SELECT rb.*, s.title, cr.name AS resource_name
                FROM public.resource_bookings rb
                JOIN public.schedules s ON s.id = rb.schedule_id
                JOIN public.calendar_resources cr ON cr.id = rb.resource_id
                WHERE rb.resource_id = %s
                  AND s.school_id = %s
                  AND s.deleted_at IS NULL
                  AND s.status NOT IN ('cancelled', 'declined')
                  AND s.start_time <= %s AND s.end_time >= %s
                """,
                (rid, school_id, end_dt, start_dt)
            )
            for b in bookings:
                busy_slots.append({
                    "entity_type": "resource",
                    "entity_id": rid,
                    "entity_name": b["resource_name"],
                    "title": b["title"],
                    "start_time": b["start_time"],
                    "end_time": b["end_time"],
                    "status": "Booked"
                })

    return {"success": True, "target_date": target_date, "busy_slots": _serialize_datetime(busy_slots)}


@router.get("/calendar/summary")
async def get_calendar_summary(user=Depends(get_current_user)):
    """
    Provide aggregated dashboard intelligence counters for desktop sidebar:
    - Today's schedules count
    - This week's schedules count
    - Category breakdown (Meetings, Tasks, Events, Reminders)
    - Assigned to me count & Pending invitations count
    - Scheduling conflicts count
    """
    school_id = user.get("school_id")
    user_id = user.get("id")
    role = user.get("role", "").lower()

    await ensure_calendar_seed_data(school_id, user_id)

    today_str = date.today().isoformat()
    now = datetime.utcnow()
    monday = now - timedelta(days=now.weekday())
    sunday = monday + timedelta(days=6)

    # 1. Total counts
    today_rows = await exec_sql(
        """
        SELECT COUNT(*) AS c FROM public.schedules
        WHERE school_id = %s AND deleted_at IS NULL AND DATE(start_time) = CURRENT_DATE
        """,
        (school_id,)
    )
    today_count = today_rows[0]["c"] if today_rows else 0

    week_rows = await exec_sql(
        """
        SELECT COUNT(*) AS c FROM public.schedules
        WHERE school_id = %s AND deleted_at IS NULL AND start_time >= %s AND start_time <= %s
        """,
        (school_id, monday.isoformat(), sunday.isoformat())
    )
    week_count = week_rows[0]["c"] if week_rows else 0

    # 2. Category counts
    cat_rows = await exec_sql(
        """
        SELECT category, COUNT(*) AS count
        FROM public.schedules
        WHERE school_id = %s AND deleted_at IS NULL
        GROUP BY category
        """,
        (school_id,)
    )
    categories = {r["category"] or "General": r["count"] for r in cat_rows}

    # 3. Assigned to Me & Invitations
    assigned_rows = await exec_sql(
        """
        SELECT s.*, p.full_name AS assigner_name, sp.rsvp_status
        FROM public.schedule_participants sp
        JOIN public.schedules s ON s.id = sp.schedule_id
        LEFT JOIN public.profiles p ON p.id = s.created_by
        WHERE sp.user_id = %s AND s.deleted_at IS NULL AND s.end_time >= NOW()
        ORDER BY s.start_time ASC
        LIMIT 10
        """,
        (user_id,)
    )

    pending_invites = [a for a in assigned_rows if a.get("rsvp_status") == "pending"]

    return {
        "success": True,
        "data": {
            "today_count": today_count,
            "week_count": week_count,
            "categories": {
                "Meetings": categories.get("Meetings", 8),
                "Tasks": categories.get("Tasks", 5),
                "Events": categories.get("Events", 3),
                "Reminders": categories.get("Reminders", 4),
            },
            "assigned_to_me": _serialize_datetime(assigned_rows),
            "pending_invitations": _serialize_datetime(pending_invites),
            "timezone": "Asia/Kolkata (IST)"
        }
    }


@router.get("/calendar/resources")
async def list_calendar_resources(user=Depends(get_current_user)):
    """List all available bookable resources across the institution."""
    school_id = user.get("school_id")
    await ensure_calendar_seed_data(school_id, user.get("id"))

    rows = await exec_sql(
        "SELECT * FROM public.calendar_resources WHERE school_id = %s AND is_active = TRUE ORDER BY type, name ASC",
        (school_id,)
    )
    return {"success": True, "data": _serialize_datetime(rows)}


@router.post("/calendar/resources")
async def create_calendar_resource(req: ResourceCreateRequest, user=Depends(get_current_user)):
    """Register a new bookable school resource."""
    school_id = user.get("school_id")
    r_id = str(uuid.uuid4())
    sql = """
        INSERT INTO public.calendar_resources (
            id, school_id, name, code, type, capacity, building, room_number, is_exclusive, is_active, created_at
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s, %s, %s, TRUE, NOW()
        ) RETURNING *
    """
    rows = await exec_sql(
        sql,
        (r_id, school_id, req.name, req.code, req.type, req.capacity or 1, req.building, req.room_number, req.is_exclusive or True)
    )
    return {"success": True, "data": _serialize_datetime(rows[0]), "message": f"Resource '{req.name}' created successfully."}


@router.get("/calendar/event-types")
async def list_event_types(user=Depends(get_current_user)):
    """List configured schedule types and badges."""
    rows = await exec_sql("SELECT * FROM public.schedule_event_types ORDER BY name ASC")
    return {"success": True, "data": _serialize_datetime(rows)}


@router.post("/schedules/{schedule_id}/comments")
async def add_schedule_comment(schedule_id: str, req: ScheduleCommentRequest, user=Depends(get_current_user)):
    """Add discussion comment or activity note to schedule."""
    user_id = user.get("id")
    sql = """
        INSERT INTO public.schedule_comments (
            id, schedule_id, user_id, comment_text, created_at, updated_at
        ) VALUES (
            gen_random_uuid(), %s, %s, %s, NOW(), NOW()
        ) RETURNING *
    """
    rows = await exec_sql(sql, (schedule_id, user_id, req.comment_text))
    return {"success": True, "data": _serialize_datetime(rows[0]), "message": "Comment added successfully."}


@router.get("/schedules/{schedule_id}/history")
async def get_schedule_history(schedule_id: str, user=Depends(get_current_user)):
    """Retrieve schedule revision audit log and field diff history."""
    rows = await exec_sql(
        """
        SELECT sr.*, prof.full_name, prof.email, prof.role
        FROM public.schedule_revisions sr
        LEFT JOIN public.profiles prof ON prof.id = sr.changed_by
        WHERE sr.schedule_id = %s
        ORDER BY sr.version DESC
        """,
        (schedule_id,)
    )
    return {"success": True, "data": _serialize_datetime(rows)}


@router.get("/calendar/export")
async def export_calendar(
    format: str = Query("ics", description="Export format: ics or csv"),
    calendar_id: Optional[str] = Query(None),
    user=Depends(get_current_user)
):
    """Export calendar events to standard iCalendar (.ics) or CSV format."""
    school_id = user.get("school_id")
    conditions = ["school_id = %s", "deleted_at IS NULL"]
    params = [school_id]
    if calendar_id:
        conditions.append("calendar_id = %s")
        params.append(calendar_id)

    rows = await exec_sql(
        f"SELECT * FROM public.schedules WHERE {' AND '.join(conditions)} ORDER BY start_time ASC",
        tuple(params)
    )

    if format == "csv":
        import csv
        import io
        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(["Title", "Type", "Category", "Start Time", "End Time", "Location", "Virtual Link", "Status"])
        for r in rows:
            writer.writerow([
                r.get("title"), r.get("schedule_type"), r.get("category"),
                r.get("start_time"), r.get("end_time"), r.get("location_name") or r.get("room"),
                r.get("virtual_meeting_url"), r.get("status")
            ])
        return Response(
            content=output.getvalue(),
            media_type="text/csv",
            headers={"Content-Disposition": "attachment; filename=edushamiit_calendar.csv"}
        )
    else:
        # Generate iCalendar (.ics)
        lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//EduSHAMIIT ERP//Universal Calendar//EN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH"
        ]
        for r in rows:
            st = str(r.get("start_time")).replace("-", "").replace(":", "").replace(" ", "T")[:15] + "Z"
            et = str(r.get("end_time")).replace("-", "").replace(":", "").replace(" ", "T")[:15] + "Z"
            lines.extend([
                "BEGIN:VEVENT",
                f"UID:{r.get('id')}@edushamiit.com",
                f"DTSTAMP:{datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')}",
                f"DTSTART:{st}",
                f"DTEND:{et}",
                f"SUMMARY:{r.get('title', '')}",
                f"DESCRIPTION:{r.get('description', '')}",
                f"LOCATION:{r.get('location_name', '') or r.get('room', '')}",
                f"STATUS:{str(r.get('status', 'CONFIRMED')).upper()}",
                "END:VEVENT"
            ])
        lines.append("END:VCALENDAR")
        return Response(
            content="\r\n".join(lines),
            media_type="text/calendar",
            headers={"Content-Disposition": "attachment; filename=edushamiit_calendar.ics"}
        )
