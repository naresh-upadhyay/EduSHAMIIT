-- ============================================================================
-- Migration: 447_enterprise_space_booking_system.sql
-- Description: Production-grade Space Booking System schema for EduSHAMIIT
--              Reuses campuses, buildings, building_floors, rooms, and profiles.
-- ============================================================================

-- 1. Enhance rooms with booking specific configuration
ALTER TABLE public.rooms 
ADD COLUMN IF NOT EXISTS is_bookable BOOLEAN NOT NULL DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS booking_buffer_minutes INT NOT NULL DEFAULT 15,
ADD COLUMN IF NOT EXISTS min_booking_duration_minutes INT NOT NULL DEFAULT 30,
ADD COLUMN IF NOT EXISTS max_booking_duration_minutes INT NOT NULL DEFAULT 480;

-- 2. Space Booking Recurring Series Master
CREATE TABLE IF NOT EXISTS public.space_booking_recurring_series (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    title VARCHAR(250) NOT NULL,
    recurrence_type VARCHAR(50) NOT NULL DEFAULT 'WEEKLY', -- DAILY, WEEKDAYS, WEEKLY, SELECTED_WEEKDAYS, BIWEEKLY, MONTHLY, SEMESTER, CUSTOM
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    days_of_week INT[] DEFAULT ARRAY[]::INT[], -- 1=Monday .. 7=Sunday
    interval INT NOT NULL DEFAULT 1,
    excluded_dates DATE[] DEFAULT ARRAY[]::DATE[],
    total_occurrences INT NOT NULL DEFAULT 0,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Space Bookings Table
CREATE TABLE IF NOT EXISTS public.space_bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    booking_ref VARCHAR(50) NOT NULL,
    title VARCHAR(250) NOT NULL,
    description TEXT,
    purpose VARCHAR(100) NOT NULL DEFAULT 'Academic', -- Club Activity, Workshop, Meeting, Practical, Practice, Lecture, Exam, Event, Other
    category VARCHAR(50) NOT NULL DEFAULT 'Academic',
    booking_type VARCHAR(50) NOT NULL DEFAULT 'Internal', -- Internal, External, Departmental
    priority VARCHAR(20) NOT NULL DEFAULT 'Normal', -- Normal, High, Urgent
    visibility VARCHAR(20) NOT NULL DEFAULT 'Public', -- Public, Private, Department

    -- Physical Infrastructure Hierarchy Foreign Keys (Reusing Existing)
    campus_id UUID REFERENCES public.campuses(id) ON DELETE SET NULL,
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    floor_id UUID NOT NULL REFERENCES public.building_floors(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,

    -- Date & Time Specifications
    booking_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    start_datetime TIMESTAMPTZ NOT NULL,
    end_datetime TIMESTAMPTZ NOT NULL,
    setup_minutes INT NOT NULL DEFAULT 0,
    cleanup_minutes INT NOT NULL DEFAULT 0,
    buffer_start_datetime TIMESTAMPTZ NOT NULL,
    buffer_end_datetime TIMESTAMPTZ NOT NULL,
    duration_minutes INT NOT NULL DEFAULT 60,
    timezone VARCHAR(50) NOT NULL DEFAULT 'Asia/Kolkata',

    -- Requester & Organizer Details
    organizer_name VARCHAR(150) NOT NULL,
    organizer_email VARCHAR(150),
    organizer_phone VARCHAR(50),
    organizer_role VARCHAR(50) NOT NULL DEFAULT 'Staff', -- Student, Faculty, Admin Office, IT Department, Cultural Committee, Other
    organizer_department VARCHAR(100),
    requested_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    attendee_count INT NOT NULL DEFAULT 1,

    -- Lifecycle & Approval State
    status VARCHAR(30) NOT NULL DEFAULT 'Pending', -- Draft, Submitted, Pending, Approved, Confirmed, Rejected, Cancelled, Checked In, In Use, Completed, No Show, Expired
    is_approved BOOLEAN NOT NULL DEFAULT FALSE,
    approval_level INT NOT NULL DEFAULT 1,
    approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    rejection_reason TEXT,
    cancellation_reason TEXT,
    cancelled_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    cancelled_at TIMESTAMPTZ,

    -- Actual Usage & Check-in / Check-out
    checked_in_at TIMESTAMPTZ,
    checked_in_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    checked_out_at TIMESTAMPTZ,
    checked_out_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    checkin_qr_code VARCHAR(100),
    space_condition_on_checkout VARCHAR(50) DEFAULT 'Good', -- Excellent, Good, Fair, Damaged
    checkout_remarks TEXT,

    -- Recurrence linkage
    is_recurring BOOLEAN NOT NULL DEFAULT FALSE,
    recurring_series_id UUID REFERENCES public.space_booking_recurring_series(id) ON DELETE SET NULL,
    recurrence_index INT DEFAULT 1,

    -- Resources, Amenities, and Notes
    special_instructions TEXT,
    amenities_required JSONB NOT NULL DEFAULT '[]'::JSONB,
    equipment_ids UUID[] DEFAULT ARRAY[]::UUID[],
    
    -- Audit & Soft-Delete
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,

    CONSTRAINT uq_booking_ref_per_school UNIQUE (school_id, booking_ref)
);

-- 4. Multi-level Approval Tracking
CREATE TABLE IF NOT EXISTS public.space_booking_approvals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    booking_id UUID NOT NULL REFERENCES public.space_bookings(id) ON DELETE CASCADE,
    step_number INT NOT NULL DEFAULT 1,
    approver_role VARCHAR(50) NOT NULL, -- e.g. 'Department Head', 'Campus Administrator'
    approver_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'Pending', -- Pending, Approved, Rejected, Changes_Requested
    comments TEXT,
    decided_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Audit & State Transition History
CREATE TABLE IF NOT EXISTS public.space_booking_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    booking_id UUID NOT NULL REFERENCES public.space_bookings(id) ON DELETE CASCADE,
    previous_status VARCHAR(30),
    new_status VARCHAR(30) NOT NULL,
    changed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    changed_by_name VARCHAR(150),
    reason TEXT,
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Blackout Dates & Maintenance Windows
CREATE TABLE IF NOT EXISTS public.space_booking_blackout_dates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    title VARCHAR(150) NOT NULL,
    reason VARCHAR(250),
    campus_id UUID REFERENCES public.campuses(id) ON DELETE CASCADE,
    building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE,
    room_id UUID REFERENCES public.rooms(id) ON DELETE CASCADE,
    start_datetime TIMESTAMPTZ NOT NULL,
    end_datetime TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Institutional Space Booking Settings
CREATE TABLE IF NOT EXISTS public.space_booking_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE UNIQUE,
    max_advance_booking_days INT NOT NULL DEFAULT 60,
    min_booking_notice_hours INT NOT NULL DEFAULT 2,
    default_buffer_minutes INT NOT NULL DEFAULT 15,
    working_hours_start TIME NOT NULL DEFAULT '08:00:00',
    working_hours_end TIME NOT NULL DEFAULT '18:00:00',
    allow_student_bookings BOOLEAN NOT NULL DEFAULT TRUE,
    require_approval_all_spaces BOOLEAN NOT NULL DEFAULT TRUE,
    auto_confirm_roles TEXT[] DEFAULT ARRAY['super_admin', 'admin', 'principal'],
    cancellation_deadline_hours INT NOT NULL DEFAULT 2,
    grace_period_minutes INT NOT NULL DEFAULT 15,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. Performance Indexes
CREATE INDEX IF NOT EXISTS idx_space_bookings_school_status ON public.space_bookings(school_id, status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_space_bookings_room_dates ON public.space_bookings(room_id, booking_date) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_space_bookings_buffer_range ON public.space_bookings(room_id, buffer_start_datetime, buffer_end_datetime) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_space_bookings_requested_by ON public.space_bookings(requested_by, status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_space_bookings_building_date ON public.space_bookings(building_id, booking_date) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_space_booking_approvals_booking ON public.space_booking_approvals(booking_id, status);
CREATE INDEX IF NOT EXISTS idx_space_booking_history_booking ON public.space_booking_status_history(booking_id, created_at DESC);
