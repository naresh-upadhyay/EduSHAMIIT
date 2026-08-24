-- ============================================================================
-- Migration: 301_leave_and_permissions_enhancements.sql
-- Description:
--   1. Creates leave_types table with annual quota, carry-forward, encashment,
--      document requirements, and applicability rules.
--   2. Creates leave_balances table for user quotas per academic year.
--   3. Creates permission_requests table for short leaves / hourly permissions.
--   4. Creates leave_audit_logs table for immutable tracking.
--   5. Enhances leave_applications table with request_code, half_day_type, etc.
--   6. Implements stored procedures for dashboard, apply, action, balance adjust.
--   7. Seeds default leave types and initial balances for staff and students.
-- ============================================================================

-- 1. LEAVE TYPES TABLE
CREATE TABLE IF NOT EXISTS public.leave_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(20) NOT NULL,
    category VARCHAR(50) DEFAULT 'PAID', -- PAID, UNPAID, SPECIAL
    annual_entitlement NUMERIC(5, 1) DEFAULT 12.0,
    monthly_accrual BOOLEAN DEFAULT FALSE,
    carry_forward_allowed BOOLEAN DEFAULT TRUE,
    max_carry_forward NUMERIC(5, 1) DEFAULT 5.0,
    encashment_allowed BOOLEAN DEFAULT FALSE,
    max_encashable NUMERIC(5, 1) DEFAULT 0.0,
    doc_required BOOLEAN DEFAULT FALSE,
    doc_required_after_days NUMERIC(4, 1) DEFAULT 2.0,
    min_notice_days INT DEFAULT 0,
    max_consecutive_days INT DEFAULT 15,
    allow_half_day BOOLEAN DEFAULT TRUE,
    applicable_roles TEXT[] DEFAULT ARRAY['teacher', 'staff', 'admin', 'driver', 'librarian', 'hr', 'student'],
    color_hex VARCHAR(20) DEFAULT '#4F46E5',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_leave_type_school_code UNIQUE (school_id, code)
);

CREATE INDEX IF NOT EXISTS idx_leave_types_school ON public.leave_types(school_id, is_active);

-- 2. LEAVE BALANCES TABLE
CREATE TABLE IF NOT EXISTS public.leave_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    leave_type_id UUID NOT NULL REFERENCES public.leave_types(id) ON DELETE CASCADE,
    academic_year VARCHAR(20) DEFAULT '2026-2027',
    allocated_days NUMERIC(5, 1) DEFAULT 12.0,
    used_days NUMERIC(5, 1) DEFAULT 0.0,
    pending_days NUMERIC(5, 1) DEFAULT 0.0,
    carried_forward_days NUMERIC(5, 1) DEFAULT 0.0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_user_leave_balance UNIQUE (school_id, user_id, leave_type_id, academic_year)
);

CREATE INDEX IF NOT EXISTS idx_leave_balances_user ON public.leave_balances(school_id, user_id, academic_year);

-- 3. PERMISSION / SHORT LEAVE REQUESTS TABLE
CREATE TABLE IF NOT EXISTS public.permission_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    request_code VARCHAR(50),
    applicant_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    applicant_role VARCHAR(50) DEFAULT 'teacher',
    permission_type VARCHAR(100) NOT NULL, -- LATE_ARRIVAL, EARLY_DEPARTURE, SHORT_PERMISSION, MEDICAL, OFFICIAL, PERSONAL
    permission_date DATE NOT NULL,
    start_time TIME WITHOUT TIME ZONE NOT NULL,
    end_time TIME WITHOUT TIME ZONE NOT NULL,
    duration_hours NUMERIC(4, 2) DEFAULT 1.0,
    reason TEXT NOT NULL,
    status VARCHAR(50) DEFAULT 'PENDING', -- PENDING, APPROVED, REJECTED, CANCELLED
    approved_by UUID REFERENCES public.profiles(id),
    approved_at TIMESTAMPTZ,
    rejection_reason TEXT,
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_permission_requests_school ON public.permission_requests(school_id, permission_date, status);

-- 4. LEAVE AUDIT LOGS TABLE
CREATE TABLE IF NOT EXISTS public.leave_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id),
    action VARCHAR(100) NOT NULL, -- APPLY, APPROVE, REJECT, CANCEL, BALANCE_ADJUST, TYPE_CREATE, TYPE_UPDATE
    entity_type VARCHAR(50) NOT NULL, -- LEAVE_REQUEST, PERMISSION_REQUEST, LEAVE_BALANCE, LEAVE_TYPE
    entity_id UUID,
    actor_id UUID REFERENCES public.profiles(id),
    old_value JSONB,
    new_value JSONB,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_leave_audit_school ON public.leave_audit_logs(school_id, created_at DESC);

-- 5. ENHANCE LEAVE APPLICATIONS TABLE WITH EXTENDED COLUMNS
ALTER TABLE public.leave_applications
    ADD COLUMN IF NOT EXISTS request_code VARCHAR(50),
    ADD COLUMN IF NOT EXISTS leave_type_id UUID REFERENCES public.leave_types(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS half_day_type VARCHAR(50) DEFAULT 'FULL_DAY', -- FULL_DAY, FIRST_HALF, SECOND_HALF
    ADD COLUMN IF NOT EXISTS manager_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS contact_number VARCHAR(50),
    ADD COLUMN IF NOT EXISTS applied_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.leave_applications DROP CONSTRAINT IF EXISTS leave_applications_applicant_role_check;

-- Create sequence for sequential request codes if not exists
CREATE SEQUENCE IF NOT EXISTS public.seq_leave_request_code START WITH 63;

-- Auto generate request code on insert trigger if null
CREATE OR REPLACE FUNCTION public.trg_set_leave_request_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.request_code IS NULL OR NEW.request_code = '' THEN
        NEW.request_code := 'LV-' || TO_CHAR(COALESCE(NEW.start_date, CURRENT_DATE), 'YYYY') || '-' || LPAD(NEXTVAL('public.seq_leave_request_code')::TEXT, 3, '0');
    END IF;
    IF NEW.applied_at IS NULL THEN
        NEW.applied_at := NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_leave_request_code_trg ON public.leave_applications;
CREATE TRIGGER set_leave_request_code_trg
BEFORE INSERT ON public.leave_applications
FOR EACH ROW
EXECUTE FUNCTION public.trg_set_leave_request_code();

UPDATE public.leave_applications
SET request_code = 'LV-2026-' || LPAD(sub.rnum::TEXT, 3, '0')
FROM (
    SELECT id, ROW_NUMBER() OVER (ORDER BY created_at) as rnum
    FROM public.leave_applications
) sub
WHERE public.leave_applications.id = sub.id
  AND (public.leave_applications.request_code IS NULL OR public.leave_applications.request_code = '');


-- ============================================================================
-- 6. SEED DEFAULT LEAVE TYPES & USER BALANCES
-- ============================================================================
DO $$
DECLARE
    r_school RECORD;
    v_cl_id UUID;
    v_ml_id UUID;
    v_el_id UUID;
    v_sl_id UUID;
    v_co_id UUID;
    v_mat_id UUID;
    v_pat_id UUID;
    r_prof RECORD;
BEGIN
    FOR r_school IN (SELECT id FROM public.schools) LOOP
        -- Casual Leave (12 days)
        INSERT INTO public.leave_types (school_id, name, code, category, annual_entitlement, carry_forward_allowed, max_carry_forward, color_hex)
        VALUES (r_school.id, 'Casual Leave', 'CL', 'PAID', 12.0, TRUE, 5.0, '#10B981')
        ON CONFLICT (school_id, code) DO UPDATE SET annual_entitlement = 12.0, color_hex = '#10B981'
        RETURNING id INTO v_cl_id;

        -- Medical Leave (15 days)
        INSERT INTO public.leave_types (school_id, name, code, category, annual_entitlement, doc_required, doc_required_after_days, color_hex)
        VALUES (r_school.id, 'Medical Leave', 'ML', 'PAID', 15.0, TRUE, 2.0, '#EF4444')
        ON CONFLICT (school_id, code) DO UPDATE SET annual_entitlement = 15.0, color_hex = '#EF4444'
        RETURNING id INTO v_ml_id;

        -- Earned Leave (24 days)
        INSERT INTO public.leave_types (school_id, name, code, category, annual_entitlement, carry_forward_allowed, max_carry_forward, encashment_allowed, color_hex)
        VALUES (r_school.id, 'Earned Leave', 'EL', 'PAID', 24.0, TRUE, 15.0, TRUE, '#3B82F6')
        ON CONFLICT (school_id, code) DO UPDATE SET annual_entitlement = 24.0, color_hex = '#3B82F6'
        RETURNING id INTO v_el_id;

        -- Sick Leave (12 days)
        INSERT INTO public.leave_types (school_id, name, code, category, annual_entitlement, doc_required, color_hex)
        VALUES (r_school.id, 'Sick Leave', 'SL', 'PAID', 12.0, TRUE, '#F59E0B')
        ON CONFLICT (school_id, code) DO UPDATE SET annual_entitlement = 12.0, color_hex = '#F59E0B'
        RETURNING id INTO v_sl_id;

        -- Comp Off (10 days)
        INSERT INTO public.leave_types (school_id, name, code, category, annual_entitlement, color_hex)
        VALUES (r_school.id, 'Comp Off', 'CO', 'PAID', 10.0, '#8B5CF6')
        ON CONFLICT (school_id, code) DO UPDATE SET annual_entitlement = 10.0, color_hex = '#8B5CF6'
        RETURNING id INTO v_co_id;

        -- Maternity Leave (90 days)
        INSERT INTO public.leave_types (school_id, name, code, category, annual_entitlement, doc_required, color_hex)
        VALUES (r_school.id, 'Maternity Leave', 'MAT', 'SPECIAL', 90.0, TRUE, '#EC4899')
        ON CONFLICT (school_id, code) DO NOTHING;

        -- Paternity Leave (15 days)
        INSERT INTO public.leave_types (school_id, name, code, category, annual_entitlement, doc_required, color_hex)
        VALUES (r_school.id, 'Paternity Leave', 'PAT', 'SPECIAL', 15.0, TRUE, '#06B6D4')
        ON CONFLICT (school_id, code) DO NOTHING;

        -- Seed initial balances for each profile in this school
        FOR r_prof IN (SELECT id FROM public.profiles WHERE (school_id = r_school.id OR school_id IS NULL)) LOOP
            IF v_cl_id IS NOT NULL THEN
                INSERT INTO public.leave_balances (school_id, user_id, leave_type_id, academic_year, allocated_days, used_days, carried_forward_days)
                VALUES (r_school.id, r_prof.id, v_cl_id, '2026-2027', 12.0, 3.5, 0.0)
                ON CONFLICT (school_id, user_id, leave_type_id, academic_year) DO NOTHING;
            END IF;
            IF v_el_id IS NOT NULL THEN
                INSERT INTO public.leave_balances (school_id, user_id, leave_type_id, academic_year, allocated_days, used_days, carried_forward_days)
                VALUES (r_school.id, r_prof.id, v_el_id, '2026-2027', 24.0, 8.0, 0.0)
                ON CONFLICT (school_id, user_id, leave_type_id, academic_year) DO NOTHING;
            END IF;
            IF v_sl_id IS NOT NULL THEN
                INSERT INTO public.leave_balances (school_id, user_id, leave_type_id, academic_year, allocated_days, used_days, carried_forward_days)
                VALUES (r_school.id, r_prof.id, v_sl_id, '2026-2027', 12.0, 6.0, 0.0)
                ON CONFLICT (school_id, user_id, leave_type_id, academic_year) DO NOTHING;
            END IF;
            IF v_ml_id IS NOT NULL THEN
                INSERT INTO public.leave_balances (school_id, user_id, leave_type_id, academic_year, allocated_days, used_days, carried_forward_days)
                VALUES (r_school.id, r_prof.id, v_ml_id, '2026-2027', 15.0, 3.0, 0.0)
                ON CONFLICT (school_id, user_id, leave_type_id, academic_year) DO NOTHING;
            END IF;
            IF v_co_id IS NOT NULL THEN
                INSERT INTO public.leave_balances (school_id, user_id, leave_type_id, academic_year, allocated_days, used_days, carried_forward_days)
                VALUES (r_school.id, r_prof.id, v_co_id, '2026-2027', 10.0, 6.0, 0.0)
                ON CONFLICT (school_id, user_id, leave_type_id, academic_year) DO NOTHING;
            END IF;
        END LOOP;
    END LOOP;
END $$;


-- ============================================================================
-- 7. STORED PROCEDURE: fn_get_leave_dashboard_and_requests
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_get_leave_dashboard_and_requests(
    p_school_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_user_type VARCHAR DEFAULT 'ALL',
    p_department VARCHAR DEFAULT 'ALL',
    p_status VARCHAR DEFAULT 'ALL',
    p_leave_type VARCHAR DEFAULT 'ALL',
    p_search VARCHAR DEFAULT '',
    p_from_date DATE DEFAULT NULL,
    p_to_date DATE DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_manager_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_total_requests INT;
    v_approved_count INT;
    v_pending_count INT;
    v_rejected_count INT;
    v_cancelled_count INT;
    v_offset INT;
    v_requests JSONB;
    v_balance_summary JSONB;
    v_upcoming_leaves JSONB;
    v_search_pattern TEXT;
    v_current_user_id UUID;
BEGIN
    v_offset := (GREATEST(p_page, 1) - 1) * GREATEST(p_page_size, 1);
    v_search_pattern := '%' || LOWER(TRIM(COALESCE(p_search, ''))) || '%';
    v_current_user_id := p_user_id;

    -- 1. Aggregate KPI Counts
    SELECT
        COUNT(*)::INT,
        COUNT(*) FILTER (WHERE LOWER(la.status) = 'approved')::INT,
        COUNT(*) FILTER (WHERE LOWER(la.status) = 'pending')::INT,
        COUNT(*) FILTER (WHERE LOWER(la.status) = 'rejected')::INT,
        COUNT(*) FILTER (WHERE LOWER(la.status) = 'cancelled')::INT
    INTO
        v_total_requests,
        v_approved_count,
        v_pending_count,
        v_rejected_count,
        v_cancelled_count
    FROM public.leave_applications la
    JOIN public.profiles p ON p.id = la.applicant_id
    WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
      AND (p_manager_id IS NULL OR p.manager_id = p_manager_id);

    -- 2. Fetch Filtered Requests List with Pagination
    SELECT COALESCE(jsonb_agg(r), '[]'::jsonb)
    INTO v_requests
    FROM (
        SELECT
            la.id,
            la.request_code,
            la.applicant_id,
            p.full_name AS applicant_name,
            p.avatar_url,
            COALESCE(p.employee_id, 'EMP-' || SUBSTRING(p.id::TEXT FROM 1 FOR 4)) AS employee_code,
            COALESCE(la.applicant_role, p.role) AS applicant_role,
            COALESCE(p.department, 'General') AS department,
            COALESCE(p.designation, p.role) AS designation,
            la.leave_type,
            COALESCE(lt.color_hex, '#4F46E5') AS leave_type_color,
            la.start_date,
            la.end_date,
            CASE
                WHEN la.half_day_type IN ('FIRST_HALF', 'SECOND_HALF') THEN 0.5
                ELSE (la.end_date - la.start_date + 1)::NUMERIC(5, 1)
            END AS days_count,
            COALESCE(la.half_day_type, 'FULL_DAY') AS half_day_type,
            la.reason,
            la.status,
            la.remarks,
            la.rejection_reason,
            la.attachment_url,
            la.contact_number,
            COALESCE(la.applied_at, la.created_at) AS applied_at,
            ap.full_name AS approved_by_name,
            mgr.full_name AS manager_name
        FROM public.leave_applications la
        JOIN public.profiles p ON p.id = la.applicant_id
        LEFT JOIN public.leave_types lt ON (lt.name ILIKE la.leave_type AND (lt.school_id = p_school_id OR lt.school_id IS NULL))
        LEFT JOIN public.profiles ap ON ap.id = la.approved_by
        LEFT JOIN public.profiles mgr ON mgr.id = p.manager_id
        WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
          AND (p_manager_id IS NULL OR p.manager_id = p_manager_id)
          AND (UPPER(p_status) = 'ALL' OR UPPER(la.status) = UPPER(p_status))
          AND (UPPER(p_user_type) = 'ALL' OR UPPER(COALESCE(la.applicant_role, p.role)) = UPPER(p_user_type))
          AND (UPPER(p_department) = 'ALL' OR UPPER(COALESCE(p.department, 'General')) = UPPER(p_department))
          AND (UPPER(p_leave_type) = 'ALL' OR UPPER(la.leave_type) = UPPER(p_leave_type))
          AND (p_from_date IS NULL OR la.start_date >= p_from_date)
          AND (p_to_date IS NULL OR la.end_date <= p_to_date)
          AND (
              p_search IS NULL OR p_search = '' OR
              LOWER(p.full_name) LIKE v_search_pattern OR
              LOWER(COALESCE(p.employee_id, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(la.request_code, '')) LIKE v_search_pattern OR
              LOWER(COALESCE(p.department, '')) LIKE v_search_pattern OR
              LOWER(la.reason) LIKE v_search_pattern
          )
        ORDER BY la.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) r;

    -- 3. Balance Summary (for current user or default school quotas)
    SELECT COALESCE(jsonb_agg(b), '[]'::jsonb)
    INTO v_balance_summary
    FROM (
        SELECT
            lt.id AS leave_type_id,
            lt.name AS leave_type_name,
            lt.code AS leave_type_code,
            COALESCE(lt.color_hex, '#4F46E5') AS color_hex,
            COALESCE(lb.allocated_days, lt.annual_entitlement) AS allocated_days,
            COALESCE(lb.used_days, 0.0) AS used_days,
            COALESCE(lb.pending_days, 0.0) AS pending_days,
            GREATEST(COALESCE(lb.allocated_days, lt.annual_entitlement) - COALESCE(lb.used_days, 0.0) - COALESCE(lb.pending_days, 0.0), 0.0) AS available_days
        FROM public.leave_types lt
        LEFT JOIN public.leave_balances lb ON (lb.leave_type_id = lt.id AND (v_current_user_id IS NULL OR lb.user_id = v_current_user_id) AND lb.academic_year = '2026-2027')
        WHERE (lt.school_id = p_school_id OR lt.school_id IS NULL)
          AND lt.is_active = TRUE
        ORDER BY lt.created_at ASC
        LIMIT 6
    ) b;

    -- 4. Upcoming Leaves List
    SELECT COALESCE(jsonb_agg(u), '[]'::jsonb)
    INTO v_upcoming_leaves
    FROM (
        SELECT
            la.id,
            p.full_name AS employee_name,
            p.avatar_url,
            la.leave_type,
            la.start_date,
            la.end_date,
            TO_CHAR(la.start_date, 'DD Mon') || CASE WHEN la.start_date != la.end_date THEN ' - ' || TO_CHAR(la.end_date, 'DD Mon') ELSE '' END AS date_range_formatted
        FROM public.leave_applications la
        JOIN public.profiles p ON p.id = la.applicant_id
        WHERE (la.school_id = p_school_id OR la.school_id IS NULL)
          AND LOWER(la.status) = 'approved'
          AND la.end_date >= CURRENT_DATE
        ORDER BY la.start_date ASC
        LIMIT 5
    ) u;

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'kpi', jsonb_build_object(
                'total_requests', v_total_requests,
                'approved_leaves', v_approved_count,
                'pending_requests', v_pending_count,
                'rejected_leaves', v_rejected_count,
                'cancelled_leaves', v_cancelled_count,
                'approved_percentage', CASE WHEN v_total_requests > 0 THEN ROUND((v_approved_count::NUMERIC / v_total_requests::NUMERIC) * 100, 2) ELSE 0.0 END,
                'pending_percentage', CASE WHEN v_total_requests > 0 THEN ROUND((v_pending_count::NUMERIC / v_total_requests::NUMERIC) * 100, 2) ELSE 0.0 END,
                'rejected_percentage', CASE WHEN v_total_requests > 0 THEN ROUND((v_rejected_count::NUMERIC / v_total_requests::NUMERIC) * 100, 2) ELSE 0.0 END,
                'cancelled_percentage', CASE WHEN v_total_requests > 0 THEN ROUND((v_cancelled_count::NUMERIC / v_total_requests::NUMERIC) * 100, 2) ELSE 0.0 END
            ),
            'requests', v_requests,
            'balance_summary', v_balance_summary,
            'upcoming_leaves', v_upcoming_leaves,
            'page', p_page,
            'page_size', p_page_size,
            'total_count', v_total_requests,
            'total_pages', CEIL(v_total_requests::NUMERIC / GREATEST(p_page_size, 1)::NUMERIC)::INT
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- 8. STORED PROCEDURE: fn_apply_leave_request
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_apply_leave_request(
    p_school_id UUID,
    p_applicant_id UUID,
    p_leave_type VARCHAR,
    p_start_date DATE,
    p_end_date DATE,
    p_reason TEXT,
    p_half_day_type VARCHAR DEFAULT 'FULL_DAY',
    p_attachment_url TEXT DEFAULT NULL,
    p_contact_number TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_applicant_role VARCHAR;
    v_days NUMERIC(5, 1);
    v_leave_type_id UUID;
    v_req_id UUID;
    v_req_code VARCHAR(50);
BEGIN
    -- 1. Validate dates
    IF p_end_date < p_start_date THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'End date cannot be earlier than start date');
    END IF;

    -- Calculate days count
    IF p_half_day_type IN ('FIRST_HALF', 'SECOND_HALF') THEN
        v_days := 0.5;
    ELSE
        v_days := (p_end_date - p_start_date + 1)::NUMERIC(5, 1);
    END IF;

    -- 2. Fetch applicant role
    SELECT role INTO v_applicant_role FROM public.profiles WHERE id = p_applicant_id;
    IF v_applicant_role IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Applicant profile not found');
    END IF;

    -- 3. Check for overlapping approved/pending requests
    IF EXISTS (
        SELECT 1 FROM public.leave_applications
        WHERE applicant_id = p_applicant_id
          AND status IN ('pending', 'approved')
          AND NOT (end_date < p_start_date OR start_date > p_end_date)
    ) THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'You already have an active leave request covering these dates');
    END IF;

    -- 4. Find Leave Type ID
    SELECT id INTO v_leave_type_id
    FROM public.leave_types
    WHERE (school_id = p_school_id OR school_id IS NULL)
      AND (name ILIKE p_leave_type OR code ILIKE p_leave_type)
    LIMIT 1;

    -- 5. Insert Leave Application
    INSERT INTO public.leave_applications (
        school_id, applicant_id, applicant_role, leave_type, leave_type_id,
        start_date, end_date, reason, half_day_type, attachment_url, contact_number,
        status, applied_at
    )
    VALUES (
        p_school_id, p_applicant_id, v_applicant_role, p_leave_type, v_leave_type_id,
        p_start_date, p_end_date, p_reason, p_half_day_type, p_attachment_url, p_contact_number,
        'pending', NOW()
    )
    RETURNING id, request_code INTO v_req_id, v_req_code;

    -- 6. Update pending days in leave balance if balance record exists
    IF v_leave_type_id IS NOT NULL THEN
        UPDATE public.leave_balances
        SET pending_days = pending_days + v_days, updated_at = NOW()
        WHERE user_id = p_applicant_id AND leave_type_id = v_leave_type_id AND academic_year = '2026-2027';
    END IF;

    -- 7. Audit Log
    INSERT INTO public.leave_audit_logs (school_id, user_id, action, entity_type, entity_id, actor_id, new_value, reason)
    VALUES (p_school_id, p_applicant_id, 'APPLY', 'LEAVE_REQUEST', v_req_id, p_applicant_id,
            jsonb_build_object('request_code', v_req_code, 'leave_type', p_leave_type, 'days', v_days), p_reason);

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Leave application submitted successfully',
        'data', jsonb_build_object('id', v_req_id, 'request_code', v_req_code, 'days_count', v_days)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- 9. STORED PROCEDURE: fn_process_leave_action
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_process_leave_action(
    p_school_id UUID,
    p_leave_id UUID,
    p_action VARCHAR, -- APPROVE, REJECT, CANCEL
    p_actor_id UUID,
    p_remarks TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_leave RECORD;
    v_new_status VARCHAR(50);
    v_days NUMERIC(5, 1);
    v_cur_date DATE;
    v_class_id UUID;
    v_section_id UUID;
BEGIN
    SELECT * INTO v_leave FROM public.leave_applications WHERE id = p_leave_id;
    IF v_leave.id IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Leave application not found');
    END IF;

    IF v_leave.half_day_type IN ('FIRST_HALF', 'SECOND_HALF') THEN
        v_days := 0.5;
    ELSE
        v_days := (v_leave.end_date - v_leave.start_date + 1)::NUMERIC(5, 1);
    END IF;

    IF UPPER(p_action) = 'APPROVE' THEN
        v_new_status := 'approved';
    ELSIF UPPER(p_action) = 'REJECT' THEN
        v_new_status := 'rejected';
    ELSE
        v_new_status := 'cancelled';
    END IF;

    -- Update Leave Application Record
    UPDATE public.leave_applications
    SET
        status = v_new_status,
        approved_by = CASE WHEN v_new_status = 'approved' THEN p_actor_id ELSE approved_by END,
        approved_at = CASE WHEN v_new_status = 'approved' THEN NOW() ELSE approved_at END,
        reviewed_by = p_actor_id,
        reviewed_at = NOW(),
        rejection_reason = CASE WHEN v_new_status = 'rejected' THEN p_remarks ELSE rejection_reason END,
        remarks = COALESCE(p_remarks, remarks),
        updated_at = NOW()
    WHERE id = p_leave_id;

    -- Adjust Balances
    IF v_leave.leave_type_id IS NOT NULL THEN
        IF v_new_status = 'approved' THEN
            UPDATE public.leave_balances
            SET used_days = used_days + v_days,
                pending_days = GREATEST(pending_days - v_days, 0.0),
                updated_at = NOW()
            WHERE user_id = v_leave.applicant_id AND leave_type_id = v_leave.leave_type_id AND academic_year = '2026-2027';
        ELSE
            UPDATE public.leave_balances
            SET pending_days = GREATEST(pending_days - v_days, 0.0),
                updated_at = NOW()
            WHERE user_id = v_leave.applicant_id AND leave_type_id = v_leave.leave_type_id AND academic_year = '2026-2027';
        END IF;
    END IF;

    -- Synchronize with Attendance if Approved
    IF v_new_status = 'approved' THEN
        -- If student, find class & section
        IF LOWER(v_leave.applicant_role) = 'student' THEN
            SELECT class_id, section_id INTO v_class_id, v_section_id
            FROM public.student_class_assignments
            WHERE student_id = v_leave.applicant_id AND school_id = p_school_id
            LIMIT 1;

            v_cur_date := v_leave.start_date;
            WHILE v_cur_date <= v_leave.end_date LOOP
                INSERT INTO public.attendance_daily_records (
                    school_id, student_id, class_id, section_id, attendance_date, status, remarks, is_locked, is_all_day, created_by, updated_by
                )
                VALUES (
                    p_school_id, v_leave.applicant_id, v_class_id, v_section_id, v_cur_date, 'ON_LEAVE',
                    'Approved Leave: ' || v_leave.leave_type || ' (' || COALESCE(v_leave.reason, '') || ')', TRUE, TRUE, p_actor_id, p_actor_id
                )
                ON CONFLICT (school_id, student_id, attendance_date)
                DO UPDATE SET status = 'ON_LEAVE', remarks = EXCLUDED.remarks, is_locked = TRUE, updated_by = p_actor_id, updated_at = NOW();

                v_cur_date := v_cur_date + 1;
            END LOOP;
        ELSE
            -- Staff / Teacher / Driver / Admin Attendance synchronization
            v_cur_date := v_leave.start_date;
            WHILE v_cur_date <= v_leave.end_date LOOP
                INSERT INTO public.attendance_staff_records (
                    school_id, employee_id, attendance_date, status, remarks, created_by, updated_by
                )
                VALUES (
                    p_school_id, v_leave.applicant_id, v_cur_date, 'ON_LEAVE',
                    'Approved Leave: ' || v_leave.leave_type || ' (' || COALESCE(v_leave.reason, '') || ')', p_actor_id, p_actor_id
                )
                ON CONFLICT (school_id, employee_id, attendance_date)
                DO UPDATE SET status = 'ON_LEAVE', remarks = EXCLUDED.remarks, updated_by = p_actor_id, updated_at = NOW();

                v_cur_date := v_cur_date + 1;
            END LOOP;
        END IF;
    END IF;

    -- Audit Log
    INSERT INTO public.leave_audit_logs (school_id, user_id, action, entity_type, entity_id, actor_id, new_value, reason)
    VALUES (p_school_id, v_leave.applicant_id, UPPER(p_action), 'LEAVE_REQUEST', p_leave_id, p_actor_id,
            jsonb_build_object('status', v_new_status, 'request_code', v_leave.request_code), p_remarks);

    RETURN jsonb_build_object('success', TRUE, 'message', 'Leave request ' || v_new_status || ' successfully');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- 10. STORED PROCEDURE: fn_adjust_leave_balance
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_adjust_leave_balance(
    p_school_id UUID,
    p_user_id UUID,
    p_leave_type_id UUID,
    p_adjustment_days NUMERIC(5, 1),
    p_reason TEXT,
    p_actor_id UUID,
    p_academic_year VARCHAR DEFAULT '2026-2027'
)
RETURNS JSONB AS $$
DECLARE
    v_old_allocated NUMERIC(5, 1);
    v_new_allocated NUMERIC(5, 1);
BEGIN
    SELECT allocated_days INTO v_old_allocated
    FROM public.leave_balances
    WHERE school_id = p_school_id AND user_id = p_user_id AND leave_type_id = p_leave_type_id AND academic_year = p_academic_year;

    IF v_old_allocated IS NULL THEN
        v_old_allocated := 0.0;
        INSERT INTO public.leave_balances (school_id, user_id, leave_type_id, academic_year, allocated_days)
        VALUES (p_school_id, p_user_id, p_leave_type_id, p_academic_year, GREATEST(p_adjustment_days, 0.0))
        RETURNING allocated_days INTO v_new_allocated;
    ELSE
        v_new_allocated := GREATEST(v_old_allocated + p_adjustment_days, 0.0);
        UPDATE public.leave_balances
        SET allocated_days = v_new_allocated, updated_at = NOW()
        WHERE school_id = p_school_id AND user_id = p_user_id AND leave_type_id = p_leave_type_id AND academic_year = p_academic_year;
    END IF;

    -- Audit Log
    INSERT INTO public.leave_audit_logs (school_id, user_id, action, entity_type, entity_id, actor_id, old_value, new_value, reason)
    VALUES (
        p_school_id, p_user_id, 'BALANCE_ADJUST', 'LEAVE_BALANCE', p_leave_type_id, p_actor_id,
        jsonb_build_object('allocated_days', v_old_allocated),
        jsonb_build_object('allocated_days', v_new_allocated, 'adjustment', p_adjustment_days),
        p_reason
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Leave balance adjusted successfully',
        'data', jsonb_build_object('new_allocated_days', v_new_allocated, 'previous_allocated_days', v_old_allocated)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- 11. STORED PROCEDURE: fn_apply_permission_request
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_apply_permission_request(
    p_school_id UUID,
    p_applicant_id UUID,
    p_permission_type VARCHAR,
    p_date DATE,
    p_start_time TIME WITHOUT TIME ZONE,
    p_end_time TIME WITHOUT TIME ZONE,
    p_reason TEXT,
    p_duration_hours NUMERIC(4, 2) DEFAULT 1.0
)
RETURNS JSONB AS $$
DECLARE
    v_req_id UUID;
    v_req_code VARCHAR(50);
    v_role VARCHAR;
BEGIN
    SELECT role INTO v_role FROM public.profiles WHERE id = p_applicant_id;
    v_req_code := 'PRM-' || TO_CHAR(p_date, 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 900 + 100)::TEXT, 3, '0');

    INSERT INTO public.permission_requests (
        school_id, request_code, applicant_id, applicant_role, permission_type,
        permission_date, start_time, end_time, duration_hours, reason, status
    )
    VALUES (
        p_school_id, v_req_code, p_applicant_id, COALESCE(v_role, 'teacher'), p_permission_type,
        p_date, p_start_time, p_end_time, p_duration_hours, p_reason, 'PENDING'
    )
    RETURNING id INTO v_req_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Permission request submitted successfully',
        'data', jsonb_build_object('id', v_req_id, 'request_code', v_req_code)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
