-- ============================================================================
-- Migration: 371_universal_visitors_management_system.sql
-- Description: Complete Production-Grade Universal Visitors Management System
--              - Tables: visitor_profiles, visitor_visits, visitor_appointments,
--                visitor_gate_passes, visitor_restrictions, visitor_documents,
--                visitor_access_events, visitor_activity_logs, visitor_access_locations
--              - Stored Procedures / Functions for KPIs, Listing, Details,
--                Registration, Check-In, Check-Out, Extension, Gate Pass Verification,
--                Appointments & Approvals, Blacklist / Restrictions, and Analytics
--              - Multi-tenant Institution Isolation, Constraints & Performance Indexes
-- ============================================================================

-- 1. Create Visitor Profiles Table (Entity representing unique individuals)
CREATE TABLE IF NOT EXISTS public.visitor_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(50) NOT NULL,
    alternate_phone VARCHAR(50),
    email VARCHAR(150),
    company VARCHAR(150),
    designation VARCHAR(150),
    visitor_type VARCHAR(100) NOT NULL DEFAULT 'Guest', -- Parent, Official, Vendor, Relative, Delivery, Maintenance, Alumni, Guest, etc.
    id_type VARCHAR(100) DEFAULT 'Aadhaar Card', -- Aadhaar Card, PAN Card, Driving License, Voter ID, Passport, Other
    id_number_masked VARCHAR(100), -- e.g. 'XXXX-XXXX-1234'
    verification_status VARCHAR(50) NOT NULL DEFAULT 'VERIFIED', -- UNVERIFIED, PENDING, VERIFIED, REJECTED
    photo_url VARCHAR(500),
    notes TEXT,
    is_blacklisted BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    archived_at TIMESTAMPTZ
);

-- Unique index per institution + phone
CREATE UNIQUE INDEX IF NOT EXISTS uq_visitor_profiles_school_phone
    ON public.visitor_profiles (school_id, phone)
    WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_visitor_profiles_school_name
    ON public.visitor_profiles (school_id, LOWER(full_name))
    WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_visitor_profiles_school_type
    ON public.visitor_profiles (school_id, visitor_type)
    WHERE archived_at IS NULL;


-- 2. Create Visitor Access Locations Table (Configurable campus checkpoints)
CREATE TABLE IF NOT EXISTS public.visitor_access_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    location_name VARCHAR(150) NOT NULL,
    location_code VARCHAR(50) NOT NULL,
    location_type VARCHAR(50) NOT NULL DEFAULT 'CHECKPOINT', -- GATE, RECEPTION, DEPARTMENT, HOSTEL, LAB, LIBRARY, AUDITORIUM
    is_entry_point BOOLEAN NOT NULL DEFAULT TRUE,
    is_exit_point BOOLEAN NOT NULL DEFAULT TRUE,
    requires_special_approval BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_visitor_locations_school_code
    ON public.visitor_access_locations (school_id, UPPER(location_code));


-- 3. Create Visitor Appointments Table
CREATE TABLE IF NOT EXISTS public.visitor_appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    appointment_number VARCHAR(50) NOT NULL, -- e.g. 'APT-2024-001'
    visitor_id UUID NOT NULL REFERENCES public.visitor_profiles(id) ON DELETE CASCADE,
    host_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    host_name VARCHAR(150) NOT NULL,
    host_department VARCHAR(100),
    purpose VARCHAR(150) NOT NULL,
    destination VARCHAR(150) NOT NULL DEFAULT 'Main Gate',
    scheduled_date DATE NOT NULL,
    scheduled_start_at TIMESTAMPTZ NOT NULL,
    scheduled_end_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'AWAITING_APPROVAL', -- AWAITING_APPROVAL, APPROVED, REJECTED, CHECKED_IN, COMPLETED, CANCELLED, NO_SHOW
    approval_required BOOLEAN NOT NULL DEFAULT TRUE,
    approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    approved_by_name VARCHAR(150),
    approved_at TIMESTAMPTZ,
    rejection_reason TEXT,
    cancellation_reason TEXT,
    notes TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_visitor_appointments_number
    ON public.visitor_appointments (school_id, UPPER(appointment_number));

CREATE INDEX IF NOT EXISTS idx_visitor_appointments_school_date
    ON public.visitor_appointments (school_id, scheduled_date);

CREATE INDEX IF NOT EXISTS idx_visitor_appointments_status
    ON public.visitor_appointments (school_id, status);


-- 4. Create Visitor Visits Table (Core visit entity)
CREATE TABLE IF NOT EXISTS public.visitor_visits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    visit_number VARCHAR(50) NOT NULL, -- e.g. 'VIS-2024-001'
    visitor_id UUID NOT NULL REFERENCES public.visitor_profiles(id) ON DELETE CASCADE,
    appointment_id UUID REFERENCES public.visitor_appointments(id) ON DELETE SET NULL,
    visit_type VARCHAR(50) NOT NULL DEFAULT 'WALK_IN', -- WALK_IN, SCHEDULED
    purpose VARCHAR(150) NOT NULL,
    category VARCHAR(100) NOT NULL DEFAULT 'Guest', -- Parent, Official, Vendor, Relative, Delivery, Maintenance, Alumni
    entry_location VARCHAR(150) NOT NULL DEFAULT 'Main Gate',
    destination VARCHAR(150) NOT NULL DEFAULT 'Main Gate',
    additional_destinations JSONB NOT NULL DEFAULT '[]'::JSONB,
    host_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    host_name VARCHAR(150),
    host_department VARCHAR(100),
    host_phone VARCHAR(50),
    scheduled_start_at TIMESTAMPTZ,
    scheduled_end_at TIMESTAMPTZ,
    check_in_at TIMESTAMPTZ,
    expected_out_at TIMESTAMPTZ,
    actual_check_out_at TIMESTAMPTZ,
    status VARCHAR(50) NOT NULL DEFAULT 'Inside', -- Inside, Checked Out, Overstay, Scheduled, Awaiting Approval, Approved, Rejected, Cancelled, No Show
    approval_status VARCHAR(50) NOT NULL DEFAULT 'APPROVED', -- PENDING, APPROVED, REJECTED, NOT_REQUIRED
    checked_in_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    checked_in_by_name VARCHAR(150),
    checked_out_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    checked_out_by_name VARCHAR(150),
    exit_location VARCHAR(150),
    vehicle_number VARCHAR(50),
    vehicle_type VARCHAR(50),
    accompanying_count INT NOT NULL DEFAULT 0,
    items_carried TEXT,
    remarks TEXT,
    pass_reference VARCHAR(50),
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_visitor_visits_school_number
    ON public.visitor_visits (school_id, UPPER(visit_number));

CREATE INDEX IF NOT EXISTS idx_visitor_visits_school_status
    ON public.visitor_visits (school_id, status);

CREATE INDEX IF NOT EXISTS idx_visitor_visits_school_check_in
    ON public.visitor_visits (school_id, check_in_at DESC);

CREATE INDEX IF NOT EXISTS idx_visitor_visits_visitor_id
    ON public.visitor_visits (visitor_id);


-- 5. Create Visitor Gate Passes Table
CREATE TABLE IF NOT EXISTS public.visitor_gate_passes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    visit_id UUID NOT NULL REFERENCES public.visitor_visits(id) ON DELETE CASCADE,
    pass_number VARCHAR(50) NOT NULL, -- e.g. 'GP-2024-001'
    token_hash VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, USED, EXPIRED, REVOKED
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    revoked_reason TEXT,
    issued_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    print_count INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_visitor_gate_passes_number
    ON public.visitor_gate_passes (school_id, UPPER(pass_number));

CREATE INDEX IF NOT EXISTS idx_visitor_gate_passes_token
    ON public.visitor_gate_passes (token_hash);


-- 6. Create Visitor Restrictions Table (Blacklist / Security Flags)
CREATE TABLE IF NOT EXISTS public.visitor_restrictions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    visitor_id UUID NOT NULL REFERENCES public.visitor_profiles(id) ON DELETE CASCADE,
    visitor_name VARCHAR(150),
    visitor_phone VARCHAR(50),
    scope_type VARCHAR(50) NOT NULL DEFAULT 'INSTITUTION', -- INSTITUTION, CAMPUS, BUILDING, DEPARTMENT
    scope_id VARCHAR(100),
    scope_name VARCHAR(150) NOT NULL DEFAULT 'Entire Institution',
    reason_category VARCHAR(100) NOT NULL, -- Documented security incident, Prior access violation, Unauthorized entry attempt, Threat or harassment incident, Administrative restriction
    confidential_notes TEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, SUSPENDED, LIFTED, UNDER_REVIEW
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    review_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    requested_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    requested_by_name VARCHAR(150),
    approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    approved_by_name VARCHAR(150),
    lifted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    lifted_by_name VARCHAR(150),
    lifted_at TIMESTAMPTZ,
    lift_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_visitor_restrictions_school_status
    ON public.visitor_restrictions (school_id, status);

CREATE INDEX IF NOT EXISTS idx_visitor_restrictions_visitor_id
    ON public.visitor_restrictions (visitor_id);


-- 7. Create Visitor Documents Table
CREATE TABLE IF NOT EXISTS public.visitor_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    visitor_id UUID NOT NULL REFERENCES public.visitor_profiles(id) ON DELETE CASCADE,
    visit_id UUID REFERENCES public.visitor_visits(id) ON DELETE SET NULL,
    document_name VARCHAR(255) NOT NULL,
    document_type VARCHAR(100) NOT NULL, -- ID Proof, Authorization Letter, Vehicle Registration, Pass Photo, Work Order
    file_url VARCHAR(500) NOT NULL,
    file_size_bytes INT DEFAULT 0,
    verification_status VARCHAR(50) NOT NULL DEFAULT 'VERIFIED',
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_visitor_documents_visitor
    ON public.visitor_documents (visitor_id);


-- 8. Create Visitor Access Events Table (Multi-checkpoint tracking)
CREATE TABLE IF NOT EXISTS public.visitor_access_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    visit_id UUID NOT NULL REFERENCES public.visitor_visits(id) ON DELETE CASCADE,
    location_name VARCHAR(150) NOT NULL,
    event_type VARCHAR(50) NOT NULL, -- ENTRY, CHECKPOINT_ENTRY, CHECKPOINT_EXIT, EXIT, EXTENSION, PASS_ISSUED, INCIDENT_REPORTED
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    recorded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    recorded_by_name VARCHAR(150),
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_visitor_access_events_visit
    ON public.visitor_access_events (visit_id, occurred_at ASC);


-- 9. Create Visitor Activity Logs Table (Audit trail)
CREATE TABLE IF NOT EXISTS public.visitor_activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    entity_type VARCHAR(50) NOT NULL, -- VISITOR, VISIT, APPOINTMENT, GATE_PASS, RESTRICTION
    entity_id UUID NOT NULL,
    action VARCHAR(100) NOT NULL,
    actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    actor_name VARCHAR(150),
    details JSONB NOT NULL DEFAULT '{}'::JSONB,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_visitor_activity_logs_entity
    ON public.visitor_activity_logs (entity_id, timestamp DESC);


-- ============================================================================
-- STORED PROCEDURES & PL/pgSQL FUNCTIONS
-- ============================================================================

-- Function 1: Get Visitor Dashboard KPIs
CREATE OR REPLACE FUNCTION public.fn_visitors_get_kpis(
    p_school_id UUID,
    p_filter JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_visitors INT;
    v_currently_inside INT;
    v_checked_in_today INT;
    v_checked_out_today INT;
    v_overstay INT;
    v_scheduled_today INT;
    v_today_start TIMESTAMPTZ := date_trunc('day', NOW());
    v_today_end TIMESTAMPTZ := v_today_start + interval '1 day';
    v_month_start TIMESTAMPTZ := date_trunc('month', NOW());
BEGIN
    -- 1. Total visits
    SELECT COUNT(*) INTO v_total_visitors
    FROM public.visitor_visits
    WHERE school_id = p_school_id;

    -- 2. Currently Inside (status is Inside and expected_out_at >= NOW())
    SELECT COUNT(*) INTO v_currently_inside
    FROM public.visitor_visits
    WHERE school_id = p_school_id
      AND status = 'Inside'
      AND (expected_out_at IS NULL OR expected_out_at >= NOW());

    -- 3. Checked In Today
    SELECT COUNT(*) INTO v_checked_in_today
    FROM public.visitor_visits
    WHERE school_id = p_school_id
      AND check_in_at >= v_today_start
      AND check_in_at < v_today_end;

    -- 4. Checked Out Today
    SELECT COUNT(*) INTO v_checked_out_today
    FROM public.visitor_visits
    WHERE school_id = p_school_id
      AND actual_check_out_at >= v_today_start
      AND actual_check_out_at < v_today_end;

    -- 5. Overstay: visits still marked Inside whose expected_out_at has passed, OR status is explicitly 'Overstay'
    SELECT COUNT(*) INTO v_overstay
    FROM public.visitor_visits
    WHERE school_id = p_school_id
      AND actual_check_out_at IS NULL
      AND (
          status = 'Overstay'
          OR (status = 'Inside' AND expected_out_at IS NOT NULL AND expected_out_at < NOW())
      );

    -- 6. Scheduled Today: appointments for today that are not completed/cancelled
    SELECT COUNT(*) INTO v_scheduled_today
    FROM public.visitor_appointments
    WHERE school_id = p_school_id
      AND scheduled_date = CURRENT_DATE
      AND status IN ('AWAITING_APPROVAL', 'APPROVED');

    RETURN jsonb_build_object(
        'total_visitors', v_total_visitors,
        'total_trend', '↑ 12%',
        'total_subtitle', 'This Month',
        'currently_inside', v_currently_inside,
        'currently_inside_subtitle', 'On campus now',
        'checked_in_today', v_checked_in_today,
        'checked_in_today_subtitle', 'Till now',
        'checked_out_today', v_checked_out_today,
        'checked_out_today_subtitle', 'Completed visits',
        'overstay', v_overstay,
        'overstay_subtitle', 'Exceeding allowed time',
        'scheduled_today', v_scheduled_today,
        'scheduled_today_subtitle', 'Upcoming visitors'
    );
END;
$$;


-- Function 2: List Visits with Dynamic Search, Filters & Pagination
CREATE OR REPLACE FUNCTION public.fn_visitors_list_visits(
    p_school_id UUID,
    p_params JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search VARCHAR := TRIM(COALESCE(p_params->>'search', ''));
    v_location VARCHAR := TRIM(COALESCE(p_params->>'location', 'All'));
    v_category VARCHAR := TRIM(COALESCE(p_params->>'category', 'All'));
    v_status VARCHAR := TRIM(COALESCE(p_params->>'status', 'All'));
    v_page INT := GREATEST(1, COALESCE((p_params->>'page')::INT, 1));
    v_page_size INT := GREATEST(1, LEAST(100, COALESCE((p_params->>'page_size')::INT, 10)));
    v_offset INT := (v_page - 1) * v_page_size;
    v_total_records INT := 0;
    v_records JSONB := '[]'::JSONB;
BEGIN
    -- Count matching visits
    SELECT COUNT(*) INTO v_total_records
    FROM public.visitor_visits v
    JOIN public.visitor_profiles p ON v.visitor_id = p.id
    WHERE v.school_id = p_school_id
      AND (
          v_search = ''
          OR p.full_name ILIKE '%' || v_search || '%'
          OR p.phone ILIKE '%' || v_search || '%'
          OR COALESCE(p.company, '') ILIKE '%' || v_search || '%'
          OR v.visit_number ILIKE '%' || v_search || '%'
          OR v.purpose ILIKE '%' || v_search || '%'
          OR COALESCE(v.host_name, '') ILIKE '%' || v_search || '%'
          OR COALESCE(v.vehicle_number, '') ILIKE '%' || v_search || '%'
          OR COALESCE(v.pass_reference, '') ILIKE '%' || v_search || '%'
      )
      AND (
          v_location = 'All'
          OR v_location = 'All Locations'
          OR v.destination = v_location
          OR v.entry_location = v_location
      )
      AND (
          v_category = 'All'
          OR v_category = 'All Visitor Types'
          OR v.category = v_category
          OR p.visitor_type = v_category
      )
      AND (
          v_status = 'All'
          OR v_status = 'All Status'
          OR (v_status = 'Inside' AND v.status = 'Inside' AND (v.expected_out_at IS NULL OR v.expected_out_at >= NOW()))
          OR (v_status = 'Checked Out' AND v.status = 'Checked Out')
          OR (v_status = 'Overstay' AND (v.status = 'Overstay' OR (v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < NOW())))
          OR v.status = v_status
      );

    -- Fetch page rows
    SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_records
    FROM (
        SELECT jsonb_build_object(
            'id', v.id,
            'visit_number', v.visit_number,
            'visitor_id', v.visitor_id,
            'visitor_name', p.full_name,
            'photo_url', p.photo_url,
            'phone', p.phone,
            'visitor_type', v.category,
            'category', v.category,
            'purpose', v.purpose,
            'location', v.destination,
            'destination', v.destination,
            'entry_location', v.entry_location,
            'host_name', v.host_name,
            'host_department', v.host_department,
            'check_in_at', to_char(v.check_in_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'expected_out_at', to_char(v.expected_out_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'actual_check_out_at', to_char(v.actual_check_out_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'status', CASE
                WHEN v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < NOW() THEN 'Overstay'
                ELSE v.status
            END,
            'vehicle_number', v.vehicle_number,
            'pass_reference', v.pass_reference,
            'remarks', v.remarks,
            'created_at', to_char(v.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        ) AS row_data
        FROM public.visitor_visits v
        JOIN public.visitor_profiles p ON v.visitor_id = p.id
        WHERE v.school_id = p_school_id
          AND (
              v_search = ''
              OR p.full_name ILIKE '%' || v_search || '%'
              OR p.phone ILIKE '%' || v_search || '%'
              OR COALESCE(p.company, '') ILIKE '%' || v_search || '%'
              OR v.visit_number ILIKE '%' || v_search || '%'
              OR v.purpose ILIKE '%' || v_search || '%'
              OR COALESCE(v.host_name, '') ILIKE '%' || v_search || '%'
              OR COALESCE(v.vehicle_number, '') ILIKE '%' || v_search || '%'
              OR COALESCE(v.pass_reference, '') ILIKE '%' || v_search || '%'
          )
          AND (
              v_location = 'All'
              OR v_location = 'All Locations'
              OR v.destination = v_location
              OR v.entry_location = v_location
          )
          AND (
              v_category = 'All'
              OR v_category = 'All Visitor Types'
              OR v.category = v_category
              OR p.visitor_type = v_category
          )
          AND (
              v_status = 'All'
              OR v_status = 'All Status'
              OR (v_status = 'Inside' AND v.status = 'Inside' AND (v.expected_out_at IS NULL OR v.expected_out_at >= NOW()))
              OR (v_status = 'Checked Out' AND v.status = 'Checked Out')
              OR (v_status = 'Overstay' AND (v.status = 'Overstay' OR (v.status = 'Inside' AND v.expected_out_at IS NOT NULL AND v.expected_out_at < NOW())))
              OR v.status = v_status
          )
        ORDER BY v.check_in_at DESC NULLS LAST, v.created_at DESC
        LIMIT v_page_size OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'records', v_records,
        'pagination', jsonb_build_object(
            'total_records', v_total_records,
            'page', v_page,
            'page_size', v_page_size,
            'total_pages', CEIL(v_total_records::NUMERIC / GREATEST(1, v_page_size))
        )
    );
END;
$$;


-- Function 3: Get 360 Visit Details by ID (for Detail Drawer)
CREATE OR REPLACE FUNCTION public.fn_visitors_get_visit_details(
    p_school_id UUID,
    p_visit_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_visit RECORD;
    v_profile RECORD;
    v_documents JSONB := '[]'::JSONB;
    v_history JSONB := '[]'::JSONB;
    v_access_events JSONB := '[]'::JSONB;
    v_gate_pass RECORD;
    v_duration_text VARCHAR := '';
    v_duration_mins INT := 0;
BEGIN
    SELECT * INTO v_visit
    FROM public.visitor_visits
    WHERE id = p_visit_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Visit not found');
    END IF;

    SELECT * INTO v_profile
    FROM public.visitor_profiles
    WHERE id = v_visit.visitor_id AND school_id = p_school_id;

    -- Calculate duration
    IF v_visit.check_in_at IS NOT NULL THEN
        IF v_visit.actual_check_out_at IS NOT NULL THEN
            v_duration_mins := EXTRACT(EPOCH FROM (v_visit.actual_check_out_at - v_visit.check_in_at)) / 60;
            v_duration_text := (v_duration_mins / 60)::INT || ' hr ' || (v_duration_mins % 60)::INT || ' mins (completed)';
        ELSE
            v_duration_mins := EXTRACT(EPOCH FROM (NOW() - v_visit.check_in_at)) / 60;
            v_duration_text := (v_duration_mins / 60)::INT || ' hr ' || (v_duration_mins % 60)::INT || ' mins (ongoing)';
        END IF;
    END IF;

    -- Documents
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', id,
        'document_name', document_name,
        'document_type', document_type,
        'file_url', file_url,
        'verification_status', verification_status,
        'uploaded_at', to_char(uploaded_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
    )), '[]'::JSONB) INTO v_documents
    FROM public.visitor_documents
    WHERE visitor_id = v_profile.id AND school_id = p_school_id;

    -- History of previous visits
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', id,
        'visit_number', visit_number,
        'purpose', purpose,
        'host_name', host_name,
        'destination', destination,
        'check_in_at', to_char(check_in_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'actual_check_out_at', to_char(actual_check_out_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'status', status
    ) ORDER BY check_in_at DESC), '[]'::JSONB) INTO v_history
    FROM public.visitor_visits
    WHERE visitor_id = v_profile.id
      AND school_id = p_school_id
      AND id != p_visit_id;

    -- Access events
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', id,
        'location_name', location_name,
        'event_type', event_type,
        'occurred_at', to_char(occurred_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'recorded_by_name', recorded_by_name,
        'notes', notes
    ) ORDER BY occurred_at ASC), '[]'::JSONB) INTO v_access_events
    FROM public.visitor_access_events
    WHERE visit_id = p_visit_id AND school_id = p_school_id;

    -- Gate pass
    SELECT * INTO v_gate_pass
    FROM public.visitor_gate_passes
    WHERE visit_id = p_visit_id AND school_id = p_school_id
    ORDER BY created_at DESC LIMIT 1;

    RETURN jsonb_build_object(
        'success', true,
        'visit', jsonb_build_object(
            'id', v_visit.id,
            'visit_number', v_visit.visit_number,
            'visitor_id', v_visit.visitor_id,
            'purpose', v_visit.purpose,
            'category', v_visit.category,
            'entry_location', v_visit.entry_location,
            'destination', v_visit.destination,
            'host_name', v_visit.host_name,
            'host_department', v_visit.host_department,
            'check_in_at', to_char(v_visit.check_in_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'expected_out_at', to_char(v_visit.expected_out_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'actual_check_out_at', to_char(v_visit.actual_check_out_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'duration_text', v_duration_text,
            'status', CASE
                WHEN v_visit.status = 'Inside' AND v_visit.expected_out_at IS NOT NULL AND v_visit.expected_out_at < NOW() THEN 'Overstay'
                ELSE v_visit.status
            END,
            'vehicle_number', v_visit.vehicle_number,
            'remarks', v_visit.remarks,
            'pass_reference', v_visit.pass_reference,
            'gate_pass', CASE WHEN v_gate_pass.id IS NOT NULL THEN jsonb_build_object(
                'id', v_gate_pass.id,
                'pass_number', v_gate_pass.pass_number,
                'status', v_gate_pass.status,
                'expires_at', to_char(v_gate_pass.expires_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
            ) ELSE NULL END
        ),
        'visitor', jsonb_build_object(
            'id', v_profile.id,
            'full_name', v_profile.full_name,
            'phone', v_profile.phone,
            'alternate_phone', v_profile.alternate_phone,
            'email', v_profile.email,
            'company', v_profile.company,
            'designation', v_profile.designation,
            'visitor_type', v_profile.visitor_type,
            'id_type', v_profile.id_type,
            'id_number_masked', v_profile.id_number_masked,
            'photo_url', v_profile.photo_url,
            'is_blacklisted', v_profile.is_blacklisted
        ),
        'documents', v_documents,
        'visit_history', v_history,
        'access_events', v_access_events
    );
END;
$$;


-- Function 4: Register Visitor and Create Visit Record
CREATE OR REPLACE FUNCTION public.fn_visitors_register_and_visit(
    p_school_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_phone VARCHAR := TRIM(p_payload->>'phone');
    v_full_name VARCHAR := TRIM(p_payload->>'full_name');
    v_visitor_id UUID;
    v_is_blacklisted BOOLEAN := FALSE;
    v_active_restriction RECORD;
    v_visit_id UUID;
    v_visit_number VARCHAR;
    v_next_seq INT;
    v_auto_check_in BOOLEAN := COALESCE((p_payload->>'auto_check_in')::BOOLEAN, TRUE);
    v_check_in_time TIMESTAMPTZ := NULL;
    v_expected_out TIMESTAMPTZ := NULL;
    v_status VARCHAR := 'Inside';
    v_pass_id UUID;
    v_pass_number VARCHAR;
BEGIN
    IF v_phone = '' OR v_full_name = '' THEN
        RETURN jsonb_build_object('success', false, 'detail', 'Phone number and full name are required.');
    END IF;

    -- Check if visitor profile already exists for this institution
    SELECT id, is_blacklisted INTO v_visitor_id, v_is_blacklisted
    FROM public.visitor_profiles
    WHERE school_id = p_school_id AND phone = v_phone AND archived_at IS NULL;

    IF v_visitor_id IS NOT NULL THEN
        -- Profile exists: update details
        UPDATE public.visitor_profiles
        SET full_name = v_full_name,
            alternate_phone = COALESCE(p_payload->>'alternate_phone', alternate_phone),
            email = COALESCE(p_payload->>'email', email),
            company = COALESCE(p_payload->>'company', company),
            designation = COALESCE(p_payload->>'designation', designation),
            visitor_type = COALESCE(p_payload->>'visitor_type', visitor_type),
            id_type = COALESCE(p_payload->>'id_type', id_type),
            id_number_masked = COALESCE(p_payload->>'id_number_masked', id_number_masked),
            photo_url = COALESCE(p_payload->>'photo_url', photo_url),
            updated_at = NOW()
        WHERE id = v_visitor_id;
    ELSE
        -- Insert new visitor profile
        INSERT INTO public.visitor_profiles (
            school_id, full_name, phone, alternate_phone, email, company, designation,
            visitor_type, id_type, id_number_masked, verification_status, photo_url, notes
        ) VALUES (
            p_school_id, v_full_name, v_phone, p_payload->>'alternate_phone',
            p_payload->>'email', p_payload->>'company', p_payload->>'designation',
            COALESCE(p_payload->>'visitor_type', 'Parent'),
            COALESCE(p_payload->>'id_type', 'Aadhaar Card'),
            COALESCE(p_payload->>'id_number_masked', 'XXXX-XXXX-1234'),
            COALESCE(p_payload->>'verification_status', 'VERIFIED'),
            p_payload->>'photo_url', p_payload->>'notes'
        ) RETURNING id INTO v_visitor_id;
    END IF;

    -- Security Guard: Check active restriction
    SELECT * INTO v_active_restriction
    FROM public.visitor_restrictions
    WHERE school_id = p_school_id AND visitor_id = v_visitor_id AND status = 'ACTIVE'
    LIMIT 1;

    IF v_active_restriction.id IS NOT NULL THEN
        IF NOT COALESCE((p_payload->>'override_restriction')::BOOLEAN, FALSE) THEN
            RETURN jsonb_build_object(
                'success', false,
                'is_restricted', true,
                'detail', 'Visitor has an active access restriction: ' || v_active_restriction.reason_category || '. Security approval required.'
            );
        END IF;
    END IF;

    -- Generate sequential visit number
    SELECT COALESCE(MAX(SUBSTRING(visit_number FROM '[0-9]+$')::INT), 0) + 1 INTO v_next_seq
    FROM public.visitor_visits
    WHERE school_id = p_school_id;

    v_visit_number := 'VIS-' || to_char(NOW(), 'YYYY') || '-' || LPAD(v_next_seq::TEXT, 4, '0');

    IF v_auto_check_in THEN
        v_check_in_time := NOW();
        v_status := 'Inside';
        IF p_payload->>'expected_out_at' IS NOT NULL THEN
            v_expected_out := (p_payload->>'expected_out_at')::TIMESTAMPTZ;
        ELSE
            v_expected_out := v_check_in_time + interval '2 hours';
        END IF;
    ELSE
        v_status := 'Scheduled';
    END IF;

    -- Create visit record
    INSERT INTO public.visitor_visits (
        school_id, visit_number, visitor_id, visit_type, purpose, category,
        entry_location, destination, host_name, host_department, host_phone,
        check_in_at, expected_out_at, status, vehicle_number, vehicle_type,
        accompanying_count, items_carried, remarks, pass_reference
    ) VALUES (
        p_school_id, v_visit_number, v_visitor_id,
        COALESCE(p_payload->>'visit_type', 'WALK_IN'),
        COALESCE(p_payload->>'purpose', 'Meet Student'),
        COALESCE(p_payload->>'category', p_payload->>'visitor_type', 'Parent'),
        COALESCE(p_payload->>'entry_location', 'Main Gate'),
        COALESCE(p_payload->>'destination', 'Main Gate'),
        p_payload->>'host_name', p_payload->>'host_department', p_payload->>'host_phone',
        v_check_in_time, v_expected_out, v_status,
        p_payload->>'vehicle_number', p_payload->>'vehicle_type',
        COALESCE((p_payload->>'accompanying_count')::INT, 0),
        p_payload->>'items_carried', p_payload->>'remarks',
        'GP-' || v_next_seq::TEXT
    ) RETURNING id INTO v_visit_id;

    -- Auto generate gate pass
    v_pass_number := 'GP-' || to_char(NOW(), 'YYYY') || '-' || LPAD(v_next_seq::TEXT, 4, '0');
    INSERT INTO public.visitor_gate_passes (
        school_id, visit_id, pass_number, token_hash, status,
        issued_at, expires_at
    ) VALUES (
        p_school_id, v_visit_id, v_pass_number,
        encode(digest(v_pass_number || v_visit_id::TEXT, 'sha256'), 'hex'),
        'ACTIVE', NOW(), COALESCE(v_expected_out, NOW() + interval '4 hours')
    ) RETURNING id INTO v_pass_id;

    -- Update pass reference in visit
    UPDATE public.visitor_visits SET pass_reference = v_pass_number WHERE id = v_visit_id;

    -- Log entry event
    IF v_auto_check_in THEN
        INSERT INTO public.visitor_access_events (
            school_id, visit_id, location_name, event_type, occurred_at, notes
        ) VALUES (
            p_school_id, v_visit_id, COALESCE(p_payload->>'entry_location', 'Main Gate'),
            'ENTRY', NOW(), 'Checked in at registration.'
        );
    END IF;

    -- Log activity
    INSERT INTO public.visitor_activity_logs (
        school_id, entity_type, entity_id, action, details
    ) VALUES (
        p_school_id, 'VISIT', v_visit_id, 'REGISTERED',
        jsonb_build_object('visit_number', v_visit_number, 'full_name', v_full_name, 'phone', v_phone)
    );

    RETURN jsonb_build_object(
        'success', true,
        'visit_id', v_visit_id,
        'visitor_id', v_visitor_id,
        'visit_number', v_visit_number,
        'pass_number', v_pass_number,
        'status', v_status
    );
END;
$$;


-- Function 5: Check In an Existing Visit / Appointment
CREATE OR REPLACE FUNCTION public.fn_visitors_check_in(
    p_school_id UUID,
    p_visit_id UUID,
    p_payload JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_visit RECORD;
    v_expected_out TIMESTAMPTZ;
BEGIN
    SELECT * INTO v_visit
    FROM public.visitor_visits
    WHERE id = p_visit_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'detail', 'Visit not found.');
    END IF;

    IF v_visit.status = 'Inside' THEN
        RETURN jsonb_build_object('success', false, 'detail', 'Visitor is already checked in.');
    END IF;

    IF p_payload->>'expected_out_at' IS NOT NULL THEN
        v_expected_out := (p_payload->>'expected_out_at')::TIMESTAMPTZ;
    ELSE
        v_expected_out := NOW() + interval '2 hours';
    END IF;

    UPDATE public.visitor_visits
    SET status = 'Inside',
        check_in_at = NOW(),
        expected_out_at = v_expected_out,
        entry_location = COALESCE(p_payload->>'entry_location', entry_location),
        checked_in_by_name = p_payload->>'operator_name',
        updated_at = NOW(),
        version = version + 1
    WHERE id = p_visit_id;

    -- Record access event
    INSERT INTO public.visitor_access_events (
        school_id, visit_id, location_name, event_type, occurred_at, notes
    ) VALUES (
        p_school_id, p_visit_id, COALESCE(p_payload->>'entry_location', v_visit.entry_location),
        'ENTRY', NOW(), 'Check-in recorded.'
    );

    -- Log activity
    INSERT INTO public.visitor_activity_logs (
        school_id, entity_type, entity_id, action, details
    ) VALUES (
        p_school_id, 'VISIT', p_visit_id, 'CHECKED_IN',
        jsonb_build_object('operator', p_payload->>'operator_name')
    );

    RETURN jsonb_build_object('success', true, 'status', 'Inside', 'visit_id', p_visit_id);
END;
$$;


-- Function 6: Check Out a Visit
CREATE OR REPLACE FUNCTION public.fn_visitors_check_out(
    p_school_id UUID,
    p_visit_id UUID,
    p_payload JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_visit RECORD;
BEGIN
    SELECT * INTO v_visit
    FROM public.visitor_visits
    WHERE id = p_visit_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'detail', 'Visit not found.');
    END IF;

    IF v_visit.status = 'Checked Out' THEN
        RETURN jsonb_build_object('success', false, 'detail', 'Visitor has already checked out.');
    END IF;

    UPDATE public.visitor_visits
    SET status = 'Checked Out',
        actual_check_out_at = NOW(),
        exit_location = COALESCE(p_payload->>'exit_location', 'Main Gate'),
        checked_out_by_name = p_payload->>'operator_name',
        remarks = COALESCE(p_payload->>'remarks', remarks),
        updated_at = NOW(),
        version = version + 1
    WHERE id = p_visit_id;

    -- Invalidate / use gate pass
    UPDATE public.visitor_gate_passes
    SET status = 'USED'
    WHERE visit_id = p_visit_id AND school_id = p_school_id;

    -- Record access event
    INSERT INTO public.visitor_access_events (
        school_id, visit_id, location_name, event_type, occurred_at, notes
    ) VALUES (
        p_school_id, p_visit_id, COALESCE(p_payload->>'exit_location', 'Main Gate'),
        'EXIT', NOW(), 'Checked out successfully.'
    );

    -- Log activity
    INSERT INTO public.visitor_activity_logs (
        school_id, entity_type, entity_id, action, details
    ) VALUES (
        p_school_id, 'VISIT', p_visit_id, 'CHECKED_OUT',
        jsonb_build_object('operator', p_payload->>'operator_name')
    );

    RETURN jsonb_build_object('success', true, 'status', 'Checked Out', 'visit_id', p_visit_id);
END;
$$;


-- Function 7: Extend Visit Allowed Time
CREATE OR REPLACE FUNCTION public.fn_visitors_extend_visit(
    p_school_id UUID,
    p_visit_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_extension_minutes INT := COALESCE((p_payload->>'extension_minutes')::INT, 60);
    v_new_expected_out TIMESTAMPTZ;
    v_reason TEXT := COALESCE(p_payload->>'reason', 'Extension approved by host');
BEGIN
    SELECT (COALESCE(expected_out_at, NOW()) + (v_extension_minutes || ' minutes')::INTERVAL)
    INTO v_new_expected_out
    FROM public.visitor_visits
    WHERE id = p_visit_id AND school_id = p_school_id;

    IF v_new_expected_out IS NULL THEN
        RETURN jsonb_build_object('success', false, 'detail', 'Visit not found.');
    END IF;

    UPDATE public.visitor_visits
    SET expected_out_at = v_new_expected_out,
        status = 'Inside', -- Reset status to inside if it was overstay
        remarks = COALESCE(remarks || ' | ', '') || 'Extended by ' || v_extension_minutes || 'm (' || v_reason || ')',
        updated_at = NOW()
    WHERE id = p_visit_id;

    -- Extend gate pass expiry
    UPDATE public.visitor_gate_passes
    SET expires_at = v_new_expected_out
    WHERE visit_id = p_visit_id AND status = 'ACTIVE';

    -- Record access event
    INSERT INTO public.visitor_access_events (
        school_id, visit_id, location_name, event_type, occurred_at, notes
    ) VALUES (
        p_school_id, p_visit_id, 'Administrative Desk',
        'EXTENSION', NOW(), 'Visit extended by ' || v_extension_minutes || ' mins: ' || v_reason
    );

    RETURN jsonb_build_object(
        'success', true,
        'expected_out_at', to_char(v_new_expected_out, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'status', 'Inside'
    );
END;
$$;


-- Function 8: List Scheduled Appointments
CREATE OR REPLACE FUNCTION public.fn_visitors_list_appointments(
    p_school_id UUID,
    p_params JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search VARCHAR := TRIM(COALESCE(p_params->>'search', ''));
    v_status VARCHAR := TRIM(COALESCE(p_params->>'status', 'All'));
    v_page INT := GREATEST(1, COALESCE((p_params->>'page')::INT, 1));
    v_page_size INT := GREATEST(1, LEAST(100, COALESCE((p_params->>'page_size')::INT, 10)));
    v_offset INT := (v_page - 1) * v_page_size;
    v_total_records INT := 0;
    v_records JSONB := '[]'::JSONB;
BEGIN
    SELECT COUNT(*) INTO v_total_records
    FROM public.visitor_appointments a
    JOIN public.visitor_profiles p ON a.visitor_id = p.id
    WHERE a.school_id = p_school_id
      AND (
          v_search = ''
          OR p.full_name ILIKE '%' || v_search || '%'
          OR p.phone ILIKE '%' || v_search || '%'
          OR a.appointment_number ILIKE '%' || v_search || '%'
          OR a.host_name ILIKE '%' || v_search || '%'
          OR a.purpose ILIKE '%' || v_search || '%'
      )
      AND (
          v_status = 'All'
          OR v_status = 'All Status'
          OR a.status = v_status
      );

    SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_records
    FROM (
        SELECT jsonb_build_object(
            'id', a.id,
            'appointment_number', a.appointment_number,
            'visitor_id', a.visitor_id,
            'visitor_name', p.full_name,
            'phone', p.phone,
            'photo_url', p.photo_url,
            'company', p.company,
            'visitor_type', p.visitor_type,
            'host_name', a.host_name,
            'host_department', a.host_department,
            'purpose', a.purpose,
            'destination', a.destination,
            'scheduled_date', a.scheduled_date::TEXT,
            'scheduled_start_at', to_char(a.scheduled_start_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'scheduled_end_at', to_char(a.scheduled_end_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'status', a.status,
            'approved_by_name', a.approved_by_name,
            'rejection_reason', a.rejection_reason,
            'notes', a.notes,
            'created_at', to_char(a.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        ) AS row_data
        FROM public.visitor_appointments a
        JOIN public.visitor_profiles p ON a.visitor_id = p.id
        WHERE a.school_id = p_school_id
          AND (
              v_search = ''
              OR p.full_name ILIKE '%' || v_search || '%'
              OR p.phone ILIKE '%' || v_search || '%'
              OR a.appointment_number ILIKE '%' || v_search || '%'
              OR a.host_name ILIKE '%' || v_search || '%'
              OR a.purpose ILIKE '%' || v_search || '%'
          )
          AND (
              v_status = 'All'
              OR v_status = 'All Status'
              OR a.status = v_status
          )
        ORDER BY a.scheduled_start_at ASC
        LIMIT v_page_size OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'records', v_records,
        'pagination', jsonb_build_object(
            'total_records', v_total_records,
            'page', v_page,
            'page_size', v_page_size,
            'total_pages', CEIL(v_total_records::NUMERIC / GREATEST(1, v_page_size))
        )
    );
END;
$$;


-- Function 9: Schedule Appointment
CREATE OR REPLACE FUNCTION public.fn_visitors_schedule_appointment(
    p_school_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_phone VARCHAR := TRIM(p_payload->>'phone');
    v_full_name VARCHAR := TRIM(p_payload->>'full_name');
    v_visitor_id UUID;
    v_next_seq INT;
    v_appointment_number VARCHAR;
    v_apt_id UUID;
BEGIN
    IF v_phone = '' OR v_full_name = '' THEN
        RETURN jsonb_build_object('success', false, 'detail', 'Phone number and name are required.');
    END IF;

    -- Lookup or create visitor profile
    SELECT id INTO v_visitor_id
    FROM public.visitor_profiles
    WHERE school_id = p_school_id AND phone = v_phone AND archived_at IS NULL;

    IF v_visitor_id IS NULL THEN
        INSERT INTO public.visitor_profiles (
            school_id, full_name, phone, email, company, visitor_type
        ) VALUES (
            p_school_id, v_full_name, v_phone, p_payload->>'email',
            p_payload->>'company', COALESCE(p_payload->>'visitor_type', 'Parent')
        ) RETURNING id INTO v_visitor_id;
    END IF;

    -- Generate sequence number
    SELECT COALESCE(MAX(SUBSTRING(appointment_number FROM '[0-9]+$')::INT), 0) + 1 INTO v_next_seq
    FROM public.visitor_appointments
    WHERE school_id = p_school_id;

    v_appointment_number := 'APT-' || to_char(NOW(), 'YYYY') || '-' || LPAD(v_next_seq::TEXT, 4, '0');

    INSERT INTO public.visitor_appointments (
        school_id, appointment_number, visitor_id, host_name, host_department,
        purpose, destination, scheduled_date, scheduled_start_at, scheduled_end_at,
        status, notes
    ) VALUES (
        p_school_id, v_appointment_number, v_visitor_id,
        COALESCE(p_payload->>'host_name', 'Principal'),
        p_payload->>'host_department',
        COALESCE(p_payload->>'purpose', 'Parent Meeting'),
        COALESCE(p_payload->>'destination', 'Main Gate'),
        COALESCE((p_payload->>'scheduled_date')::DATE, CURRENT_DATE),
        COALESCE((p_payload->>'scheduled_start_at')::TIMESTAMPTZ, NOW() + interval '1 day'),
        COALESCE((p_payload->>'scheduled_end_at')::TIMESTAMPTZ, NOW() + interval '1 day 1 hour'),
        'AWAITING_APPROVAL',
        p_payload->>'notes'
    ) RETURNING id INTO v_apt_id;

    RETURN jsonb_build_object(
        'success', true,
        'appointment_id', v_apt_id,
        'appointment_number', v_appointment_number,
        'status', 'AWAITING_APPROVAL'
    );
END;
$$;


-- Function 10: Decide Appointment (Approve / Reject)
CREATE OR REPLACE FUNCTION public.fn_visitors_decide_appointment(
    p_school_id UUID,
    p_appointment_id UUID,
    p_decision VARCHAR, -- 'APPROVED' or 'REJECTED'
    p_reason TEXT DEFAULT NULL,
    p_decided_by_name VARCHAR DEFAULT 'Admin'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.visitor_appointments
    SET status = p_decision,
        approved_by_name = p_decided_by_name,
        approved_at = NOW(),
        rejection_reason = CASE WHEN p_decision = 'REJECTED' THEN p_reason ELSE NULL END,
        updated_at = NOW()
    WHERE id = p_appointment_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'detail', 'Appointment not found.');
    END IF;

    RETURN jsonb_build_object('success', true, 'status', p_decision);
END;
$$;


-- Function 11: List Restrictions (Blacklisted Visitors)
CREATE OR REPLACE FUNCTION public.fn_visitors_list_restrictions(
    p_school_id UUID,
    p_params JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_search VARCHAR := TRIM(COALESCE(p_params->>'search', ''));
    v_status VARCHAR := TRIM(COALESCE(p_params->>'status', 'All'));
    v_page INT := GREATEST(1, COALESCE((p_params->>'page')::INT, 1));
    v_page_size INT := GREATEST(1, LEAST(100, COALESCE((p_params->>'page_size')::INT, 10)));
    v_offset INT := (v_page - 1) * v_page_size;
    v_total_records INT := 0;
    v_records JSONB := '[]'::JSONB;
BEGIN
    SELECT COUNT(*) INTO v_total_records
    FROM public.visitor_restrictions r
    JOIN public.visitor_profiles p ON r.visitor_id = p.id
    WHERE r.school_id = p_school_id
      AND (
          v_search = ''
          OR p.full_name ILIKE '%' || v_search || '%'
          OR p.phone ILIKE '%' || v_search || '%'
          OR r.reason_category ILIKE '%' || v_search || '%'
          OR r.scope_name ILIKE '%' || v_search || '%'
      )
      AND (
          v_status = 'All'
          OR v_status = 'All Status'
          OR r.status = v_status
      );

    SELECT COALESCE(jsonb_agg(row_data), '[]'::JSONB) INTO v_records
    FROM (
        SELECT jsonb_build_object(
            'id', r.id,
            'visitor_id', r.visitor_id,
            'visitor_name', p.full_name,
            'visitor_phone', p.phone,
            'photo_url', p.photo_url,
            'scope_type', r.scope_type,
            'scope_name', r.scope_name,
            'reason_category', r.reason_category,
            'confidential_notes', r.confidential_notes,
            'status', r.status,
            'effective_from', to_char(r.effective_from, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'review_at', to_char(r.review_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'requested_by_name', r.requested_by_name,
            'approved_by_name', r.approved_by_name,
            'lifted_by_name', r.lifted_by_name,
            'lift_reason', r.lift_reason,
            'created_at', to_char(r.created_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        ) AS row_data
        FROM public.visitor_restrictions r
        JOIN public.visitor_profiles p ON r.visitor_id = p.id
        WHERE r.school_id = p_school_id
          AND (
              v_search = ''
              OR p.full_name ILIKE '%' || v_search || '%'
              OR p.phone ILIKE '%' || v_search || '%'
              OR r.reason_category ILIKE '%' || v_search || '%'
              OR r.scope_name ILIKE '%' || v_search || '%'
          )
          AND (
              v_status = 'All'
              OR v_status = 'All Status'
              OR r.status = v_status
          )
        ORDER BY r.created_at DESC
        LIMIT v_page_size OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'records', v_records,
        'pagination', jsonb_build_object(
            'total_records', v_total_records,
            'page', v_page,
            'page_size', v_page_size,
            'total_pages', CEIL(v_total_records::NUMERIC / GREATEST(1, v_page_size))
        )
    );
END;
$$;


-- Function 12: Create Restriction (Blacklist Visitor)
CREATE OR REPLACE FUNCTION public.fn_visitors_create_restriction(
    p_school_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_visitor_id UUID := (p_payload->>'visitor_id')::UUID;
    v_phone VARCHAR := TRIM(p_payload->>'phone');
    v_full_name VARCHAR := TRIM(p_payload->>'full_name');
    v_restriction_id UUID;
BEGIN
    -- If visitor_id not directly passed, locate or create profile
    IF v_visitor_id IS NULL THEN
        IF v_phone = '' OR v_full_name = '' THEN
            RETURN jsonb_build_object('success', false, 'detail', 'Phone number and full name are required to blacklist.');
        END IF;

        SELECT id INTO v_visitor_id
        FROM public.visitor_profiles
        WHERE school_id = p_school_id AND phone = v_phone AND archived_at IS NULL;

        IF v_visitor_id IS NULL THEN
            INSERT INTO public.visitor_profiles (
                school_id, full_name, phone, is_blacklisted
            ) VALUES (
                p_school_id, v_full_name, v_phone, TRUE
            ) RETURNING id INTO v_visitor_id;
        END IF;
    END IF;

    -- Mark visitor profile as blacklisted
    UPDATE public.visitor_profiles
    SET is_blacklisted = TRUE, updated_at = NOW()
    WHERE id = v_visitor_id;

    -- Insert restriction record
    INSERT INTO public.visitor_restrictions (
        school_id, visitor_id, visitor_name, visitor_phone,
        scope_type, scope_name, reason_category, confidential_notes,
        status, requested_by_name, approved_by_name, review_at
    ) VALUES (
        p_school_id, v_visitor_id, v_full_name, v_phone,
        COALESCE(p_payload->>'scope_type', 'INSTITUTION'),
        COALESCE(p_payload->>'scope_name', 'Entire Institution'),
        COALESCE(p_payload->>'reason_category', 'Documented security incident'),
        COALESCE(p_payload->>'confidential_notes', 'Security restriction applied.'),
        'ACTIVE',
        p_payload->>'requested_by_name',
        p_payload->>'approved_by_name',
        NOW() + interval '30 days'
    ) RETURNING id INTO v_restriction_id;

    -- Log activity
    INSERT INTO public.visitor_activity_logs (
        school_id, entity_type, entity_id, action, details
    ) VALUES (
        p_school_id, 'RESTRICTION', v_restriction_id, 'BLACKLISTED',
        jsonb_build_object('visitor_id', v_visitor_id, 'reason', p_payload->>'reason_category')
    );

    RETURN jsonb_build_object('success', true, 'restriction_id', v_restriction_id, 'status', 'ACTIVE');
END;
$$;


-- Function 13: Lift Restriction
CREATE OR REPLACE FUNCTION public.fn_visitors_lift_restriction(
    p_school_id UUID,
    p_restriction_id UUID,
    p_lifted_by_name VARCHAR,
    p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_visitor_id UUID;
    v_other_active INT := 0;
BEGIN
    SELECT visitor_id INTO v_visitor_id
    FROM public.visitor_restrictions
    WHERE id = p_restriction_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'detail', 'Restriction not found.');
    END IF;

    UPDATE public.visitor_restrictions
    SET status = 'LIFTED',
        lifted_by_name = p_lifted_by_name,
        lifted_at = NOW(),
        lift_reason = p_reason,
        updated_at = NOW()
    WHERE id = p_restriction_id;

    -- Check if any other active restrictions exist for this visitor
    SELECT COUNT(*) INTO v_other_active
    FROM public.visitor_restrictions
    WHERE school_id = p_school_id AND visitor_id = v_visitor_id AND status = 'ACTIVE';

    IF v_other_active = 0 THEN
        UPDATE public.visitor_profiles
        SET is_blacklisted = FALSE, updated_at = NOW()
        WHERE id = v_visitor_id;
    END IF;

    INSERT INTO public.visitor_activity_logs (
        school_id, entity_type, entity_id, action, details
    ) VALUES (
        p_school_id, 'RESTRICTION', p_restriction_id, 'LIFTED',
        jsonb_build_object('lifted_by', p_lifted_by_name, 'reason', p_reason)
    );

    RETURN jsonb_build_object('success', true, 'status', 'LIFTED');
END;
$$;


-- Function 14: Get Analytics Data (Distribution by Category & Location, Recent Visits)
CREATE OR REPLACE FUNCTION public.fn_visitors_get_analytics(
    p_school_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_categories JSONB;
    v_locations JSONB;
    v_recent JSONB;
    v_total_visits INT;
BEGIN
    SELECT COUNT(*) INTO v_total_visits
    FROM public.visitor_visits
    WHERE school_id = p_school_id;

    IF v_total_visits = 0 THEN
        v_total_visits := 1; -- avoid division by zero
    END IF;

    -- Category percentages
    SELECT COALESCE(jsonb_agg(cat_item), '[]'::JSONB) INTO v_categories
    FROM (
        SELECT jsonb_build_object(
            'category', category,
            'count', COUNT(*),
            'percentage', ROUND((COUNT(*)::NUMERIC / v_total_visits * 100)::NUMERIC, 0)::INT
        ) AS cat_item
        FROM public.visitor_visits
        WHERE school_id = p_school_id
        GROUP BY category
        ORDER BY COUNT(*) DESC
    ) c;

    -- Location breakdown for today
    SELECT COALESCE(jsonb_agg(loc_item), '[]'::JSONB) INTO v_locations
    FROM (
        SELECT jsonb_build_object(
            'location', destination,
            'count', COUNT(*)
        ) AS loc_item
        FROM public.visitor_visits
        WHERE school_id = p_school_id
        GROUP BY destination
        ORDER BY COUNT(*) DESC
        LIMIT 7
    ) l;

    -- Recent visits
    SELECT COALESCE(jsonb_agg(rec_item), '[]'::JSONB) INTO v_recent
    FROM (
        SELECT jsonb_build_object(
            'id', v.id,
            'visitor_name', p.full_name,
            'photo_url', p.photo_url,
            'purpose', v.purpose,
            'time', to_char(COALESCE(v.check_in_at, v.created_at), 'HH12:MI AM'),
            'status', v.status
        ) AS rec_item
        FROM public.visitor_visits v
        JOIN public.visitor_profiles p ON v.visitor_id = p.id
        WHERE v.school_id = p_school_id
        ORDER BY v.check_in_at DESC NULLS LAST, v.created_at DESC
        LIMIT 5
    ) r;

    RETURN jsonb_build_object(
        'categories', v_categories,
        'locations', v_locations,
        'recent_visitors', v_recent
    );
END;
$$;


-- Function 15: Search Existing Visitors Autocomplete
CREATE OR REPLACE FUNCTION public.fn_visitors_search_existing(
    p_school_id UUID,
    p_query VARCHAR
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_results JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', id,
        'full_name', full_name,
        'phone', phone,
        'email', email,
        'company', company,
        'visitor_type', visitor_type,
        'photo_url', photo_url,
        'is_blacklisted', is_blacklisted
    )), '[]'::JSONB) INTO v_results
    FROM public.visitor_profiles
    WHERE school_id = p_school_id
      AND archived_at IS NULL
      AND (
          full_name ILIKE '%' || p_query || '%'
          OR phone ILIKE '%' || p_query || '%'
          OR COALESCE(email, '') ILIKE '%' || p_query || '%'
          OR COALESCE(company, '') ILIKE '%' || p_query || '%'
      )
    LIMIT 10;

    RETURN v_results;
END;
$$;
