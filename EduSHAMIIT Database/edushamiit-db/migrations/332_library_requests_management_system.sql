-- ============================================================================
-- Migration: 332_library_requests_management_system.sql
-- Description: Enterprise Library Requests Management System
-- Multi-role workflows, Lookups, KPI stats, Status Transitions, Timeline, Comments, Attachments
-- ============================================================================

-- 1. Extend public.library_requests Table
DO $$
BEGIN
    -- Request Number (Human-readable unique code e.g. REQ-000256)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'request_number') THEN
        ALTER TABLE public.library_requests ADD COLUMN request_number VARCHAR(50);
    END IF;

    -- Requester User ID
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'requester_user_id') THEN
        ALTER TABLE public.library_requests ADD COLUMN requester_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
    END IF;

    -- Category & Format details
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'category_code') THEN
        ALTER TABLE public.library_requests ADD COLUMN category_code VARCHAR(50) DEFAULT 'BOOK';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'publisher') THEN
        ALTER TABLE public.library_requests ADD COLUMN publisher TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'edition') THEN
        ALTER TABLE public.library_requests ADD COLUMN edition TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'language') THEN
        ALTER TABLE public.library_requests ADD COLUMN language VARCHAR(50) DEFAULT 'English';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'preferred_format') THEN
        ALTER TABLE public.library_requests ADD COLUMN preferred_format VARCHAR(50) DEFAULT 'Physical';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'quantity') THEN
        ALTER TABLE public.library_requests ADD COLUMN quantity INT DEFAULT 1;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'required_by') THEN
        ALTER TABLE public.library_requests ADD COLUMN required_by DATE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'description') THEN
        ALTER TABLE public.library_requests ADD COLUMN description TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'additional_notes') THEN
        ALTER TABLE public.library_requests ADD COLUMN additional_notes TEXT;
    END IF;

    -- Availability State (Independent from request status)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'availability_status') THEN
        ALTER TABLE public.library_requests ADD COLUMN availability_status VARCHAR(30) DEFAULT 'CHECKING';
    END IF;

    -- Approval State (Independent from request status)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'approval_status') THEN
        ALTER TABLE public.library_requests ADD COLUMN approval_status VARCHAR(30) DEFAULT 'NOT_REQUIRED';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'approved_by') THEN
        ALTER TABLE public.library_requests ADD COLUMN approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'approved_at') THEN
        ALTER TABLE public.library_requests ADD COLUMN approved_at TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'approval_comments') THEN
        ALTER TABLE public.library_requests ADD COLUMN approval_comments TEXT;
    END IF;

    -- Assignment
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'assigned_to') THEN
        ALTER TABLE public.library_requests ADD COLUMN assigned_to UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'assigned_by') THEN
        ALTER TABLE public.library_requests ADD COLUMN assigned_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'assigned_at') THEN
        ALTER TABLE public.library_requests ADD COLUMN assigned_at TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'assignment_notes') THEN
        ALTER TABLE public.library_requests ADD COLUMN assignment_notes TEXT;
    END IF;

    -- Clarification
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'clarification_requested') THEN
        ALTER TABLE public.library_requests ADD COLUMN clarification_requested BOOLEAN DEFAULT FALSE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'clarification_message') THEN
        ALTER TABLE public.library_requests ADD COLUMN clarification_message TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'clarification_response') THEN
        ALTER TABLE public.library_requests ADD COLUMN clarification_response TEXT;
    END IF;

    -- Resolution & Cancellation
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'resolved_by') THEN
        ALTER TABLE public.library_requests ADD COLUMN resolved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'resolved_at') THEN
        ALTER TABLE public.library_requests ADD COLUMN resolved_at TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'resolution_notes') THEN
        ALTER TABLE public.library_requests ADD COLUMN resolution_notes TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'completed_by') THEN
        ALTER TABLE public.library_requests ADD COLUMN completed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'completed_at') THEN
        ALTER TABLE public.library_requests ADD COLUMN completed_at TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'canceled_by') THEN
        ALTER TABLE public.library_requests ADD COLUMN canceled_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'canceled_at') THEN
        ALTER TABLE public.library_requests ADD COLUMN canceled_at TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'cancellation_reason') THEN
        ALTER TABLE public.library_requests ADD COLUMN cancellation_reason TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'library_requests' AND column_name = 'borrow_id') THEN
        ALTER TABLE public.library_requests ADD COLUMN borrow_id UUID REFERENCES public.library_borrows(id) ON DELETE SET NULL;
    END IF;

    -- Make author column nullable if not already
    ALTER TABLE public.library_requests ALTER COLUMN author DROP NOT NULL;
END $$;

-- Indexes for library_requests
CREATE INDEX IF NOT EXISTS idx_lib_req_school_status ON public.library_requests(school_id, status);
CREATE INDEX IF NOT EXISTS idx_lib_req_number ON public.library_requests(school_id, request_number);
CREATE INDEX IF NOT EXISTS idx_lib_req_requester ON public.library_requests(requester_user_id);
CREATE INDEX IF NOT EXISTS idx_lib_req_assigned ON public.library_requests(assigned_to);
CREATE INDEX IF NOT EXISTS idx_lib_req_created ON public.library_requests(school_id, created_at DESC);

-- 2. Create Supporting Tables: Comments, Attachments, Status History
CREATE TABLE IF NOT EXISTS public.library_request_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    request_id UUID NOT NULL REFERENCES public.library_requests(id) ON DELETE CASCADE,
    author_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    comment TEXT NOT NULL,
    is_internal BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_lib_req_comments_req ON public.library_request_comments(request_id, created_at ASC);

CREATE TABLE IF NOT EXISTS public.library_request_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    request_id UUID NOT NULL REFERENCES public.library_requests(id) ON DELETE CASCADE,
    file_name TEXT NOT NULL,
    file_url TEXT NOT NULL,
    mime_type TEXT,
    file_size INT DEFAULT 0,
    uploaded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_lib_req_attach_req ON public.library_request_attachments(request_id);

CREATE TABLE IF NOT EXISTS public.library_request_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    request_id UUID NOT NULL REFERENCES public.library_requests(id) ON DELETE CASCADE,
    from_status VARCHAR(30),
    to_status VARCHAR(30) NOT NULL,
    changed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action TEXT,
    reason TEXT,
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_lib_req_history_req ON public.library_request_status_history(request_id, created_at ASC);


-- 3. Register Configurable Lookups
DO $$
DECLARE
    s_id UUID;
    k_cat_id UUID;
    k_type_id UUID;
    k_prio_id UUID;
    k_fmt_id UUID;
BEGIN
    FOR s_id IN (SELECT id FROM public.schools) LOOP
        -- A. Request Category
        INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status)
        VALUES (s_id, 'Library Request Category', 'LIBRARY_REQUEST_CATEGORY', 'Categories of resource & service requests in library', 'SYSTEM', 'category', 'ACTIVE')
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
        RETURNING id INTO k_cat_id;

        IF k_cat_id IS NULL THEN
            SELECT id INTO k_cat_id FROM public.lookup_keys WHERE school_id = s_id AND key_code = 'LIBRARY_REQUEST_CATEGORY' AND deleted_at IS NULL LIMIT 1;
        END IF;

        IF k_cat_id IS NOT NULL THEN
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, sort_order, status)
            VALUES 
                (k_cat_id, s_id, 'Book', 'BOOK', 1, 'ACTIVE'),
                (k_cat_id, s_id, 'E-Book', 'EBOOK', 2, 'ACTIVE'),
                (k_cat_id, s_id, 'Digital Resource', 'DIGITAL_RESOURCE', 3, 'ACTIVE'),
                (k_cat_id, s_id, 'Audiobook', 'AUDIOBOOK', 4, 'ACTIVE'),
                (k_cat_id, s_id, 'Journal / Magazine', 'JOURNAL_MAGAZINE', 5, 'ACTIVE'),
                (k_cat_id, s_id, 'Research Resource', 'RESEARCH_RESOURCE', 6, 'ACTIVE'),
                (k_cat_id, s_id, 'Membership', 'MEMBERSHIP', 7, 'ACTIVE'),
                (k_cat_id, s_id, 'Reservation', 'RESERVATION', 8, 'ACTIVE'),
                (k_cat_id, s_id, 'Acquisition', 'ACQUISITION', 9, 'ACTIVE'),
                (k_cat_id, s_id, 'Other', 'OTHER', 10, 'ACTIVE')
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
        END IF;

        -- B. Request Type
        INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status)
        VALUES (s_id, 'Library Request Type', 'LIBRARY_REQUEST_TYPE', 'Types of specific requests', 'SYSTEM', 'format_list_bulleted', 'ACTIVE')
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
        RETURNING id INTO k_type_id;

        IF k_type_id IS NULL THEN
            SELECT id INTO k_type_id FROM public.lookup_keys WHERE school_id = s_id AND key_code = 'LIBRARY_REQUEST_TYPE' AND deleted_at IS NULL LIMIT 1;
        END IF;

        IF k_type_id IS NOT NULL THEN
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, sort_order, status)
            VALUES 
                (k_type_id, s_id, 'Book', 'Book', 1, 'ACTIVE'),
                (k_type_id, s_id, 'E-Book', 'E-Book', 2, 'ACTIVE'),
                (k_type_id, s_id, 'Digital Resource', 'Digital Resource', 3, 'ACTIVE'),
                (k_type_id, s_id, 'Audiobook', 'Audiobook', 4, 'ACTIVE'),
                (k_type_id, s_id, 'Journal / Magazine', 'Journal / Magazine', 5, 'ACTIVE'),
                (k_type_id, s_id, 'Other', 'Other', 6, 'ACTIVE')
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
        END IF;

        -- C. Request Priority
        INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status)
        VALUES (s_id, 'Library Request Priority', 'LIBRARY_REQUEST_PRIORITY', 'Priorities of library requests', 'SYSTEM', 'priority_high', 'ACTIVE')
        ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
        RETURNING id INTO k_prio_id;

        IF k_prio_id IS NULL THEN
            SELECT id INTO k_prio_id FROM public.lookup_keys WHERE school_id = s_id AND key_code = 'LIBRARY_REQUEST_PRIORITY' AND deleted_at IS NULL LIMIT 1;
        END IF;

        IF k_prio_id IS NOT NULL THEN
            INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, sort_order, status)
            VALUES 
                (k_prio_id, s_id, 'Low', 'Low', 1, 'ACTIVE'),
                (k_prio_id, s_id, 'Medium', 'Medium', 2, 'ACTIVE'),
                (k_prio_id, s_id, 'High', 'High', 3, 'ACTIVE'),
                (k_prio_id, s_id, 'Urgent', 'Urgent', 4, 'ACTIVE')
            ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
        END IF;
    END LOOP;
END $$;



-- ============================================================================
-- STORED FUNCTION 1: Super Fast KPI Computation & Breakdown
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_get_request_kpis(
    p_school_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_role TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total BIGINT := 0;
    v_new BIGINT := 0;
    v_in_progress BIGINT := 0;
    v_resolved BIGINT := 0;
    v_rejected BIGINT := 0;
    v_canceled BIGINT := 0;
    v_type_counts JSONB;
    v_status_dist JSONB;
    v_recent_requests JSONB;
    v_is_requester_only BOOLEAN := false;
BEGIN
    IF p_role IS NOT NULL AND LOWER(p_role) IN ('student', 'parent') THEN
        v_is_requester_only := true;
    END IF;

    -- Total & Status counts
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE UPPER(r.status) IN ('NEW', 'PENDING')),
        COUNT(*) FILTER (WHERE UPPER(r.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS')),
        COUNT(*) FILTER (WHERE UPPER(r.status) IN ('RESOLVED', 'COMPLETED')),
        COUNT(*) FILTER (WHERE UPPER(r.status) = 'REJECTED'),
        COUNT(*) FILTER (WHERE UPPER(r.status) IN ('CANCELED', 'CANCELLED'))
    INTO v_total, v_new, v_in_progress, v_resolved, v_rejected, v_canceled
    FROM public.library_requests r
    WHERE r.school_id = p_school_id
      AND (NOT v_is_requester_only OR r.requester_user_id = p_user_id OR r.student_id = p_user_id);

    -- Request Types Breakdown (Deduplicated lookup types + any existing types in requests with REAL calculated counts)
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'type', t.type_name,
        'count', t.type_count
    )), '[]'::jsonb)
    INTO v_type_counts
    FROM (
        WITH raw_types AS (
            SELECT lv.value_name AS type_name, lv.sort_order AS sort_ord
            FROM public.lookup_values lv
            JOIN public.lookup_keys lk ON lv.lookup_key_id = lk.id
            WHERE lk.key_code = 'LIBRARY_REQUEST_TYPE'
              AND (lv.school_id = p_school_id OR lv.school_id IS NULL)
              AND lv.status = 'ACTIVE'
            UNION ALL
            SELECT DISTINCT r.request_type AS type_name, 999 AS sort_ord
            FROM public.library_requests r
            WHERE r.school_id = p_school_id AND r.request_type IS NOT NULL AND r.request_type != ''
        ),
        all_types AS (
            SELECT type_name, MIN(sort_ord) AS sort_ord
            FROM raw_types
            GROUP BY type_name
        )
        SELECT 
            at.type_name,
            COUNT(r.id) AS type_count
        FROM all_types at
        LEFT JOIN public.library_requests r ON (
            (LOWER(TRIM(r.request_type)) = LOWER(TRIM(at.type_name)))
            AND r.school_id = p_school_id
            AND (NOT v_is_requester_only OR r.requester_user_id = p_user_id OR r.student_id = p_user_id)
        )
        GROUP BY at.type_name, at.sort_ord
        ORDER BY at.sort_ord ASC, type_count DESC, at.type_name ASC
    ) t;

    -- Status Distribution with Percentages calculated directly from DB
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'status', s.status_name,
        'count', s.status_count,
        'percentage', CASE WHEN v_total > 0 THEN ROUND((s.status_count::numeric / v_total::numeric) * 100, 1) ELSE 0.0 END
    )), '[]'::jsonb)
    INTO v_status_dist
    FROM (
        SELECT 
            CASE 
                WHEN UPPER(r.status) IN ('NEW', 'PENDING') THEN 'New'
                WHEN UPPER(r.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS') THEN 'In Progress'
                WHEN UPPER(r.status) IN ('RESOLVED', 'COMPLETED') THEN 'Resolved'
                WHEN UPPER(r.status) = 'REJECTED' THEN 'Rejected'
                WHEN UPPER(r.status) IN ('CANCELED', 'CANCELLED') THEN 'Cancelled'
                ELSE INITCAP(r.status)
            END AS status_name,
            COUNT(*) AS status_count
        FROM public.library_requests r
        WHERE r.school_id = p_school_id
          AND (NOT v_is_requester_only OR r.requester_user_id = p_user_id OR r.student_id = p_user_id)
        GROUP BY 1
        ORDER BY status_count DESC
    ) s;

    -- Recent Requests for Side Panel (real records from DB)
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', r.id,
        'request_number', COALESCE(r.request_number, 'REQ-' || LPAD(r.id::text, 6, '0')),
        'title', r.title,
        'author', r.author,
        'requester_name', COALESCE(p.full_name, 'Member'),
        'request_type', COALESCE(r.request_type, 'Book'),
        'status', r.status,
        'priority', COALESCE(r.priority, 'Normal'),
        'created_at', r.created_at
    )), '[]'::jsonb)
    INTO v_recent_requests
    FROM (
        SELECT r.*
        FROM public.library_requests r
        WHERE r.school_id = p_school_id
          AND (NOT v_is_requester_only OR r.requester_user_id = p_user_id OR r.student_id = p_user_id)
        ORDER BY r.created_at DESC
        LIMIT 5
    ) r
    LEFT JOIN public.profiles p ON (r.requester_user_id = p.id OR r.student_id = p.id);

    RETURN jsonb_build_object(
        'total_requests', v_total,
        'new_requests', v_new,
        'in_progress', v_in_progress,
        'resolved', v_resolved,
        'rejected', v_rejected,
        'canceled', v_canceled,
        'type_counts', COALESCE(v_type_counts, '[]'::jsonb),
        'status_distribution', COALESCE(v_status_dist, '[]'::jsonb),
        'recent_requests', COALESCE(v_recent_requests, '[]'::jsonb)
    );
END;
$$;



-- ============================================================================
-- STORED FUNCTION 2: Paginated List Requests with Advanced Filters & Sorting
-- ============================================================================
DROP FUNCTION IF EXISTS public.fn_library_list_requests(uuid, text, text, text, text, text, text, date, date, integer, integer, text, text, uuid, text);

CREATE OR REPLACE FUNCTION public.fn_library_list_requests(
    p_school_id UUID,
    p_search TEXT DEFAULT NULL,
    p_subtab TEXT DEFAULT 'ALL',
    p_request_type TEXT DEFAULT 'ALL',
    p_status TEXT DEFAULT 'ALL',
    p_priority TEXT DEFAULT 'ALL',
    p_requested_by_role TEXT DEFAULT 'ALL',
    p_date_from DATE DEFAULT NULL,
    p_date_to DATE DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by TEXT DEFAULT 'created_at',
    p_sort_order TEXT DEFAULT 'DESC',
    p_current_user_id UUID DEFAULT NULL,
    p_current_user_role TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT;
    v_total INT := 0;
    v_items JSONB;
    v_is_requester_only BOOLEAN := false;
BEGIN
    IF p_current_user_role IS NOT NULL AND LOWER(p_current_user_role) IN ('student', 'parent') THEN
        v_is_requester_only := true;
    END IF;

    v_offset := (p_page - 1) * p_page_size;

    -- Count total matching records
    SELECT COUNT(*)
    INTO v_total
    FROM public.library_requests r
    LEFT JOIN public.library_members m ON r.member_id = m.id
    LEFT JOIN public.profiles p ON (r.requester_user_id = p.id OR r.student_id = p.id OR m.profile_id = p.id)
    LEFT JOIN public.library_books b ON r.book_id = b.id
    LEFT JOIN public.profiles a ON r.assigned_to = a.id
    WHERE r.school_id = p_school_id
      AND (
          NOT v_is_requester_only 
          OR r.requester_user_id = p_current_user_id 
          OR r.student_id = p_current_user_id
      )
      -- Subtab Filter
      AND (
          p_subtab IS NULL 
          OR UPPER(p_subtab) = 'ALL'
          OR (UPPER(p_subtab) = 'MY_REQUESTS' AND (r.requester_user_id = p_current_user_id OR r.student_id = p_current_user_id))
          OR (UPPER(p_subtab) = 'NEEDS_REVIEW' AND UPPER(r.status) IN ('NEW', 'PENDING'))
          OR (UPPER(p_subtab) = 'ASSIGNED_TO_ME' AND r.assigned_to = p_current_user_id)
          OR (UPPER(p_subtab) = 'NEW' AND UPPER(r.status) IN ('NEW', 'PENDING'))
          OR (UPPER(p_subtab) = 'ACTIVE' AND UPPER(r.status) = 'ACTIVE')
          OR (UPPER(p_subtab) = 'IN_PROGRESS' AND UPPER(r.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS'))
          OR (UPPER(p_subtab) = 'RESOLVED' AND UPPER(r.status) = 'RESOLVED')
          OR (UPPER(p_subtab) = 'COMPLETED' AND UPPER(r.status) = 'COMPLETED')
          OR (UPPER(p_subtab) = 'REJECTED' AND UPPER(r.status) = 'REJECTED')
          OR (UPPER(p_subtab) = 'CANCELED' AND UPPER(r.status) IN ('CANCELED', 'CANCELLED'))
      )
      -- Type Filter
      AND (
          p_request_type IS NULL 
          OR UPPER(p_request_type) = 'ALL' 
          OR UPPER(COALESCE(r.request_type, 'Book')) = UPPER(p_request_type)
      )
      -- Status Filter
      AND (
          p_status IS NULL 
          OR UPPER(p_status) = 'ALL'
          OR (UPPER(p_status) = 'NEW' AND UPPER(r.status) IN ('NEW', 'PENDING'))
          OR (UPPER(p_status) = 'IN_PROGRESS' AND UPPER(r.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS'))
          OR (UPPER(p_status) = 'CANCELLED' AND UPPER(r.status) IN ('CANCELED', 'CANCELLED'))
          OR UPPER(r.status) = UPPER(p_status)
      )
      -- Priority Filter
      AND (
          p_priority IS NULL 
          OR UPPER(p_priority) = 'ALL'
          OR UPPER(COALESCE(r.priority, 'NORMAL')) = UPPER(p_priority)
      )
      -- Role Filter (Dynamic match against profiles.role or app_roles.name / display_name / code)
      AND (
          p_requested_by_role IS NULL 
          OR UPPER(p_requested_by_role) = 'ALL'
          OR UPPER(COALESCE(p.role, 'student')) = UPPER(p_requested_by_role)
          OR UPPER(REPLACE(COALESCE(p.role, 'student'), '_', ' ')) = UPPER(REPLACE(p_requested_by_role, '_', ' '))
          OR EXISTS (
              SELECT 1 FROM public.app_roles ar
              WHERE UPPER(COALESCE(ar.status, 'ACTIVE')) = 'ACTIVE'
                AND (ar.name = p.role OR ar.code = p.role)
                AND (
                    UPPER(ar.name) = UPPER(p_requested_by_role)
                    OR UPPER(ar.display_name) = UPPER(p_requested_by_role)
                    OR UPPER(ar.code) = UPPER(p_requested_by_role)
                    OR UPPER(REPLACE(ar.name, '_', ' ')) = UPPER(REPLACE(p_requested_by_role, '_', ' '))
                )
          )
      )


      -- Date Range Filter
      AND (p_date_from IS NULL OR r.created_at::date >= p_date_from)
      AND (p_date_to IS NULL OR r.created_at::date <= p_date_to)
      -- Search query across title, request_number, isbn, author, member name, department
      AND (
          p_search IS NULL 
          OR r.title ILIKE '%' || p_search || '%'
          OR COALESCE(r.request_number, '') ILIKE '%' || p_search || '%'
          OR COALESCE(r.author, '') ILIKE '%' || p_search || '%'
          OR COALESCE(r.isbn, '') ILIKE '%' || p_search || '%'
          OR COALESCE(p.full_name, '') ILIKE '%' || p_search || '%'
          OR COALESCE(p.class, '') ILIKE '%' || p_search || '%'
          OR COALESCE(p.department, '') ILIKE '%' || p_search || '%'
          OR COALESCE(b.title, '') ILIKE '%' || p_search || '%'
      );

    -- Select paginated items
    SELECT jsonb_agg(row_to_json(t))
    INTO v_items
    FROM (
        SELECT 
            r.id,
            COALESCE(r.request_number, 'REQ-' || LPAD(r.id::text, 6, '0')) AS request_number,
            r.title,
            COALESCE(r.author, b.author, 'Unknown') AS author,
            r.isbn,
            r.publisher,
            r.edition,
            r.language,
            COALESCE(r.preferred_format, 'Physical') AS preferred_format,
            r.quantity,
            r.required_by,
            COALESCE(r.category_code, 'BOOK') AS category_code,
            COALESCE(r.request_type, 'Book') AS request_type,
            COALESCE(r.priority, 'Normal') AS priority,
            r.status,
            COALESCE(r.availability_status, 'CHECKING') AS availability_status,
            COALESCE(r.approval_status, 'NOT_REQUIRED') AS approval_status,
            r.reason,
            r.description,
            r.rejection_reason,
            r.cancellation_reason,
            r.clarification_requested,
            r.clarification_message,
            r.clarification_response,
            r.created_at,
            r.updated_at,
            r.resolved_at,
            r.completed_at,
            -- Requester details
            COALESCE(p.id, r.requester_user_id) AS requester_id,
            COALESCE(p.full_name, 'Member') AS requester_name,
            COALESCE(p.email, '') AS requester_email,
            COALESCE(p.avatar_url, '') AS requester_avatar,
            COALESCE(p.role, 'Student') AS requester_role,
            COALESCE(p.class, p.department, 'Class 9-A') AS requester_class,
            m.member_code,
            -- Book details if linked
            b.id AS book_id,
            b.title AS linked_book_title,
            COALESCE(b.cover_url, '') AS cover_url,
            COALESCE(b.available_copies, 0) AS book_available_copies,
            COALESCE(b.total_copies, 0) AS book_total_copies,
            COALESCE(b.shelf_location, 'A-12') AS shelf_location,
            -- Assigned Librarian details
            a.id AS assigned_to_id,
            COALESCE(a.full_name, 'Unassigned') AS assigned_to_name,
            COALESCE(a.avatar_url, '') AS assigned_to_avatar
        FROM public.library_requests r
        LEFT JOIN public.library_members m ON r.member_id = m.id
        LEFT JOIN public.profiles p ON (r.requester_user_id = p.id OR r.student_id = p.id OR m.profile_id = p.id)
        LEFT JOIN public.library_books b ON r.book_id = b.id
        LEFT JOIN public.profiles a ON r.assigned_to = a.id
        WHERE r.school_id = p_school_id
          AND (
              NOT v_is_requester_only 
              OR r.requester_user_id = p_current_user_id 
              OR r.student_id = p_current_user_id
          )
          -- Subtab Filter
          AND (
              UPPER(p_subtab) = 'ALL'
              OR (UPPER(p_subtab) = 'MY_REQUESTS' AND (r.requester_user_id = p_current_user_id OR r.student_id = p_current_user_id))
              OR (UPPER(p_subtab) = 'NEEDS_REVIEW' AND UPPER(r.status) IN ('NEW', 'PENDING'))
              OR (UPPER(p_subtab) = 'ASSIGNED_TO_ME' AND r.assigned_to = p_current_user_id)
              OR (UPPER(p_subtab) = 'NEW' AND UPPER(r.status) IN ('NEW', 'PENDING'))
              OR (UPPER(p_subtab) = 'ACTIVE' AND UPPER(r.status) = 'ACTIVE')
              OR (UPPER(p_subtab) = 'IN_PROGRESS' AND UPPER(r.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS'))
              OR (UPPER(p_subtab) = 'RESOLVED' AND UPPER(r.status) = 'RESOLVED')
              OR (UPPER(p_subtab) = 'COMPLETED' AND UPPER(r.status) = 'COMPLETED')
              OR (UPPER(p_subtab) = 'REJECTED' AND UPPER(r.status) = 'REJECTED')
              OR (UPPER(p_subtab) = 'CANCELED' AND UPPER(r.status) IN ('CANCELED', 'CANCELLED'))
          )
          -- Type Filter
          AND (
              UPPER(p_request_type) = 'ALL' 
              OR UPPER(COALESCE(r.request_type, 'Book')) = UPPER(p_request_type)
          )
          -- Status Filter
          AND (
              UPPER(p_status) = 'ALL'
              OR (UPPER(p_status) = 'NEW' AND UPPER(r.status) IN ('NEW', 'PENDING'))
              OR (UPPER(p_status) = 'IN_PROGRESS' AND UPPER(r.status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS'))
              OR (UPPER(p_status) = 'CANCELLED' AND UPPER(r.status) IN ('CANCELED', 'CANCELLED'))
              OR UPPER(r.status) = UPPER(p_status)
          )
          -- Priority Filter
          AND (
              UPPER(p_priority) = 'ALL'
              OR UPPER(COALESCE(r.priority, 'NORMAL')) = UPPER(p_priority)
          )
          -- Role Filter (Dynamic match against profiles.role or app_roles.name / display_name / code)
          AND (
              p_requested_by_role IS NULL 
              OR UPPER(p_requested_by_role) = 'ALL'
              OR UPPER(COALESCE(p.role, 'student')) = UPPER(p_requested_by_role)
              OR UPPER(REPLACE(COALESCE(p.role, 'student'), '_', ' ')) = UPPER(REPLACE(p_requested_by_role, '_', ' '))
              OR EXISTS (
                  SELECT 1 FROM public.app_roles ar
                  WHERE UPPER(COALESCE(ar.status, 'ACTIVE')) = 'ACTIVE'
                    AND (ar.name = p.role OR ar.code = p.role)
                    AND (
                        UPPER(ar.name) = UPPER(p_requested_by_role)
                        OR UPPER(ar.display_name) = UPPER(p_requested_by_role)
                        OR UPPER(ar.code) = UPPER(p_requested_by_role)
                        OR UPPER(REPLACE(ar.name, '_', ' ')) = UPPER(REPLACE(p_requested_by_role, '_', ' '))
                    )
              )
          )

          -- Date Range Filter
          AND (p_date_from IS NULL OR r.created_at::date >= p_date_from)
          AND (p_date_to IS NULL OR r.created_at::date <= p_date_to)
          -- Search query
          AND (
              p_search IS NULL 
              OR r.title ILIKE '%' || p_search || '%'
              OR COALESCE(r.request_number, '') ILIKE '%' || p_search || '%'
              OR COALESCE(r.author, '') ILIKE '%' || p_search || '%'
              OR COALESCE(r.isbn, '') ILIKE '%' || p_search || '%'
              OR COALESCE(p.full_name, '') ILIKE '%' || p_search || '%'
              OR COALESCE(p.class, '') ILIKE '%' || p_search || '%'
              OR COALESCE(p.department, '') ILIKE '%' || p_search || '%'
              OR COALESCE(b.title, '') ILIKE '%' || p_search || '%'
          )
        ORDER BY 
            CASE WHEN p_sort_by = 'request_number' AND p_sort_order = 'ASC' THEN r.request_number END ASC,
            CASE WHEN p_sort_by = 'request_number' AND p_sort_order = 'DESC' THEN r.request_number END DESC,
            CASE WHEN p_sort_by = 'title' AND p_sort_order = 'ASC' THEN r.title END ASC,
            CASE WHEN p_sort_by = 'title' AND p_sort_order = 'DESC' THEN r.title END DESC,
            CASE WHEN p_sort_by = 'status' AND p_sort_order = 'ASC' THEN r.status END ASC,
            CASE WHEN p_sort_by = 'status' AND p_sort_order = 'DESC' THEN r.status END DESC,
            CASE WHEN p_sort_by = 'created_at' AND p_sort_order = 'ASC' THEN r.created_at END ASC,
            r.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    ) t;

    RETURN jsonb_build_object(
        'items', COALESCE(v_items, '[]'::jsonb),
        'total', v_total,
        'page', p_page,
        'page_size', p_page_size,
        'total_pages', CEIL(v_total::numeric / GREATEST(p_page_size, 1)::numeric)::int
    );
END;
$$;


-- ============================================================================
-- STORED FUNCTION 3: Get Complete Request Detail with Timeline, Comments, Attachments
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_get_request_detail(
    p_school_id UUID,
    p_request_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_role TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req JSONB;
    v_timeline JSONB;
    v_comments JSONB;
    v_attachments JSONB;
    v_is_librarian BOOLEAN := false;
BEGIN
    IF p_role IS NOT NULL AND LOWER(p_role) IN ('librarian', 'library_manager', 'principal', 'director', 'super_admin', 'admin') THEN
        v_is_librarian := true;
    END IF;

    -- Fetch primary request info
    SELECT row_to_json(t)
    INTO v_req
    FROM (
        SELECT 
            r.*,
            COALESCE(r.request_number, 'REQ-' || LPAD(r.id::text, 6, '0')) AS formatted_request_number,
            -- Requester
            p.full_name AS requester_name,
            p.email AS requester_email,
            p.avatar_url AS requester_avatar,
            p.role AS requester_role,
            COALESCE(p.class, p.department, 'N/A') AS requester_class,
            m.member_code,
            -- Assigned Librarian
            a.full_name AS assigned_to_name,
            a.avatar_url AS assigned_to_avatar,
            -- Approved By
            ap.full_name AS approved_by_name,
            -- Resolved By
            rb.full_name AS resolved_by_name,
            -- Completed By
            cb.full_name AS completed_by_name,
            -- Linked Book Info
            b.title AS linked_book_title,
            b.author AS linked_book_author,
            COALESCE(b.isbn13, b.isbn10, b.isbn) AS linked_book_isbn,
            b.cover_url,
            b.total_copies,
            b.available_copies,
            b.shelf_location,
            b.rack_location
        FROM public.library_requests r

        LEFT JOIN public.library_members m ON r.member_id = m.id
        LEFT JOIN public.profiles p ON (r.requester_user_id = p.id OR r.student_id = p.id OR m.profile_id = p.id)
        LEFT JOIN public.library_books b ON r.book_id = b.id
        LEFT JOIN public.profiles a ON r.assigned_to = a.id
        LEFT JOIN public.profiles ap ON r.approved_by = ap.id
        LEFT JOIN public.profiles rb ON r.resolved_by = rb.id
        LEFT JOIN public.profiles cb ON r.completed_by = cb.id
        WHERE r.school_id = p_school_id AND r.id = p_request_id
    ) t;

    IF v_req IS NULL THEN
        RETURN NULL;
    END IF;

    -- Fetch Timeline / Status History
    SELECT jsonb_agg(row_to_json(h))
    INTO v_timeline
    FROM (
        SELECT 
            sh.id,
            sh.from_status,
            sh.to_status,
            sh.action,
            sh.reason,
            sh.comment,
            sh.created_at,
            p.full_name AS actor_name,
            p.role AS actor_role
        FROM public.library_request_status_history sh
        LEFT JOIN public.profiles p ON sh.changed_by = p.id
        WHERE sh.request_id = p_request_id
        ORDER BY sh.created_at ASC
    ) h;

    -- Fetch Comments (hide internal comments from student/parent requesters)
    SELECT jsonb_agg(row_to_json(c))
    INTO v_comments
    FROM (
        SELECT 
            rc.id,
            rc.comment,
            rc.is_internal,
            rc.created_at,
            p.id AS author_id,
            p.full_name AS author_name,
            p.role AS author_role,
            p.avatar_url AS author_avatar
        FROM public.library_request_comments rc
        LEFT JOIN public.profiles p ON rc.author_id = p.id
        WHERE rc.request_id = p_request_id
          AND (v_is_librarian OR rc.is_internal = false)
        ORDER BY rc.created_at ASC
    ) c;

    -- Fetch Attachments
    SELECT jsonb_agg(row_to_json(att))
    INTO v_attachments
    FROM (
        SELECT 
            ra.id,
            ra.file_name,
            ra.file_url,
            ra.mime_type,
            ra.file_size,
            ra.created_at,
            p.full_name AS uploaded_by_name
        FROM public.library_request_attachments ra
        LEFT JOIN public.profiles p ON ra.uploaded_by = p.id
        WHERE ra.request_id = p_request_id
        ORDER BY ra.created_at ASC
    ) att;

    RETURN jsonb_build_object(
        'request', v_req,
        'timeline', COALESCE(v_timeline, '[]'::jsonb),
        'comments', COALESCE(v_comments, '[]'::jsonb),
        'attachments', COALESCE(v_attachments, '[]'::jsonb)
    );
END;
$$;


-- ============================================================================
-- STORED FUNCTION 4: Create Library Request with Sequential Code Generation
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_create_request(
    p_school_id UUID,
    p_requester_user_id UUID,
    p_member_id UUID DEFAULT NULL,
    p_book_id UUID DEFAULT NULL,
    p_title TEXT DEFAULT NULL,
    p_author TEXT DEFAULT NULL,
    p_isbn TEXT DEFAULT NULL,
    p_publisher TEXT DEFAULT NULL,
    p_edition TEXT DEFAULT NULL,
    p_language TEXT DEFAULT 'English',
    p_category_code TEXT DEFAULT 'BOOK',
    p_request_type TEXT DEFAULT 'Book',
    p_preferred_format TEXT DEFAULT 'Physical',
    p_quantity INT DEFAULT 1,
    p_priority TEXT DEFAULT 'Medium',
    p_required_by DATE DEFAULT NULL,
    p_reason TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_req_num TEXT;
    v_seq_num INT;
    v_new_id UUID;
    v_final_title TEXT := p_title;
    v_final_author TEXT := p_author;
    v_final_isbn TEXT := p_isbn;
    v_member_id UUID := p_member_id;
    v_avail_status TEXT := 'CHECKING';
    v_appr_status TEXT := 'NOT_REQUIRED';
BEGIN
    -- Derive member_id if null
    IF v_member_id IS NULL AND p_requester_user_id IS NOT NULL THEN
        SELECT id INTO v_member_id FROM public.library_members 
        WHERE school_id = p_school_id AND profile_id = p_requester_user_id 
        LIMIT 1;
    END IF;

    -- If linked to existing book, pull book metadata
    IF p_book_id IS NOT NULL THEN
        SELECT 
            b.title, 
            b.author, 
            COALESCE(b.isbn13, b.isbn10, b.isbn),
            CASE WHEN b.available_copies > 0 THEN 'AVAILABLE' ELSE 'NOT_AVAILABLE' END
        INTO v_final_title, v_final_author, v_final_isbn, v_avail_status
        FROM public.library_books b 
        WHERE b.id = p_book_id AND b.school_id = p_school_id;
    END IF;

    IF v_final_title IS NULL OR TRIM(v_final_title) = '' THEN
        RAISE EXCEPTION 'Request title or selected book is required.';
    END IF;

    -- Generate sequential request code REQ-000256 or REQ-2026-000001
    SELECT COALESCE(MAX(SUBSTRING(request_number FROM '[0-9]+')::int), 256) + 1
    INTO v_seq_num
    FROM public.library_requests
    WHERE school_id = p_school_id;

    v_req_num := 'REQ-' || LPAD(v_seq_num::text, 6, '0');

    -- Insert request
    INSERT INTO public.library_requests (
        school_id, request_number, requester_user_id, member_id, student_id,
        book_id, title, author, isbn, publisher, edition, language,
        category_code, request_type, preferred_format, quantity, priority,
        required_by, reason, description, additional_notes,
        status, availability_status, approval_status,
        created_at, updated_at
    ) VALUES (
        p_school_id, v_req_num, p_requester_user_id, v_member_id, p_requester_user_id,
        p_book_id, v_final_title, v_final_author, v_final_isbn, p_publisher, p_edition, p_language,
        p_category_code, p_request_type, p_preferred_format, COATEST_INT(p_quantity, 1), p_priority,
        p_required_by, p_reason, p_description, p_notes,
        'NEW', v_avail_status, v_appr_status,
        NOW(), NOW()
    ) RETURNING id INTO v_new_id;

    -- Insert Initial Status History
    INSERT INTO public.library_request_status_history (
        school_id, request_id, from_status, to_status, changed_by, action, reason, created_at
    ) VALUES (
        p_school_id, v_new_id, NULL, 'NEW', p_requester_user_id, 'REQUEST_CREATED', 'Request submitted by user', NOW()
    );

    -- Log Activity
    INSERT INTO public.library_circulation_activities (
        school_id, activity_type, title, description, member_id, book_id, performed_by, created_at
    ) VALUES (
        p_school_id, 'REQUEST_CREATE', 'New Library Request Raised: ' || v_req_num, 
        'Requested: ' || v_final_title, v_member_id, p_book_id, p_requester_user_id, NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'request_id', v_new_id,
        'request_number', v_req_num,
        'message', 'Request ' || v_req_num || ' submitted successfully.'
    );
END;
$$;


-- Helper for positive integer fallback
CREATE OR REPLACE FUNCTION public.COATEST_INT(val INT, fallback INT)
RETURNS INT LANGUAGE sql IMMUTABLE AS $$ SELECT CASE WHEN val IS NOT NULL AND val > 0 THEN val ELSE fallback END; $$;


-- ============================================================================
-- STORED FUNCTION 5: Strict State Transition Machine with Audit
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_library_transition_request_status(
    p_school_id UUID,
    p_request_id UUID,
    p_to_status TEXT,
    p_changed_by UUID,
    p_reason TEXT DEFAULT NULL,
    p_comment TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_curr_status TEXT;
    v_new_status TEXT := UPPER(p_to_status);
    v_req_num TEXT;
    v_requester_id UUID;
    v_member_id UUID;
    v_book_id UUID;
    v_is_valid BOOLEAN := false;
BEGIN
    SELECT status, request_number, requester_user_id, member_id, book_id
    INTO v_curr_status, v_req_num, v_requester_id, v_member_id, v_book_id
    FROM public.library_requests
    WHERE id = p_request_id AND school_id = p_school_id;

    IF v_curr_status IS NULL THEN
        RAISE EXCEPTION 'Request not found.';
    END IF;

    v_curr_status := UPPER(v_curr_status);

    -- Map synonyms
    IF v_new_status = 'CANCELLED' THEN v_new_status := 'CANCELED'; END IF;
    IF v_new_status = 'IN PROGRESS' THEN v_new_status := 'IN_PROGRESS'; END IF;
    IF v_curr_status = 'IN PROGRESS' THEN v_curr_status := 'IN_PROGRESS'; END IF;

    -- Validate Transitions:
    -- NEW -> ACTIVE, REJECTED, CANCELED
    -- ACTIVE -> IN_PROGRESS, REJECTED, CANCELED
    -- IN_PROGRESS -> RESOLVED, REJECTED, CANCELED
    -- RESOLVED -> COMPLETED
    IF v_curr_status = 'NEW' AND v_new_status IN ('ACTIVE', 'IN_PROGRESS', 'REJECTED', 'CANCELED') THEN v_is_valid := true;
    ELSIF v_curr_status = 'ACTIVE' AND v_new_status IN ('IN_PROGRESS', 'RESOLVED', 'REJECTED', 'CANCELED') THEN v_is_valid := true;
    ELSIF v_curr_status = 'IN_PROGRESS' AND v_new_status IN ('RESOLVED', 'REJECTED', 'CANCELED', 'ACTIVE') THEN v_is_valid := true;
    ELSIF v_curr_status = 'RESOLVED' AND v_new_status IN ('COMPLETED', 'IN_PROGRESS') THEN v_is_valid := true;
    ELSIF v_curr_status = v_new_status THEN v_is_valid := true;
    END IF;

    IF NOT v_is_valid THEN
        RAISE EXCEPTION 'Invalid status transition from % to %.', v_curr_status, v_new_status;
    END IF;

    -- Update Request
    UPDATE public.library_requests
    SET 
        status = v_new_status,
        updated_at = NOW(),
        resolved_at = CASE WHEN v_new_status = 'RESOLVED' THEN NOW() ELSE resolved_at END,
        resolved_by = CASE WHEN v_new_status = 'RESOLVED' THEN p_changed_by ELSE resolved_by END,
        resolution_notes = CASE WHEN v_new_status = 'RESOLVED' AND p_comment IS NOT NULL THEN p_comment ELSE resolution_notes END,
        completed_at = CASE WHEN v_new_status = 'COMPLETED' THEN NOW() ELSE completed_at END,
        completed_by = CASE WHEN v_new_status = 'COMPLETED' THEN p_changed_by ELSE completed_by END,
        rejection_reason = CASE WHEN v_new_status = 'REJECTED' THEN COALESCE(p_reason, rejection_reason) ELSE rejection_reason END,
        canceled_at = CASE WHEN v_new_status = 'CANCELED' THEN NOW() ELSE canceled_at END,
        canceled_by = CASE WHEN v_new_status = 'CANCELED' THEN p_changed_by ELSE canceled_by END,
        cancellation_reason = CASE WHEN v_new_status = 'CANCELED' THEN COALESCE(p_reason, cancellation_reason) ELSE cancellation_reason END
    WHERE id = p_request_id AND school_id = p_school_id;

    -- Insert Status History
    INSERT INTO public.library_request_status_history (
        school_id, request_id, from_status, to_status, changed_by, action, reason, comment, created_at
    ) VALUES (
        p_school_id, p_request_id, v_curr_status, v_new_status, p_changed_by, 
        'STATUS_CHANGE', p_reason, p_comment, NOW()
    );

    -- Log Activity
    INSERT INTO public.library_circulation_activities (
        school_id, activity_type, title, description, member_id, book_id, performed_by, created_at
    ) VALUES (
        p_school_id, 'STATUS_' || v_new_status, 'Request ' || v_req_num || ' -> ' || v_new_status,
        COALESCE(p_comment, p_reason, 'Status changed'), v_member_id, v_book_id, p_changed_by, NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'request_id', p_request_id,
        'from_status', v_curr_status,
        'to_status', v_new_status,
        'message', 'Request status updated to ' || v_new_status
    );
END;
$$;


-- ============================================================================
-- 4. Seed Realistic Production Data Matching Screenshot
-- ============================================================================
DO $$
DECLARE
    s_id UUID;
    m_aarav UUID;
    m_diya UUID;
    m_rahul UUID;
    m_neha UUID;
    m_amit UUID;
    m_pooja UUID;
    m_karan UUID;
    m_rohan UUID;
    m_meera UUID;
    m_siddharth UUID;
BEGIN
    FOR s_id IN (SELECT id FROM public.schools) LOOP
        -- Ensure profiles exist or use existing
        -- 1. Aarav Sharma
        SELECT id INTO m_aarav FROM public.profiles WHERE LOWER(email) = LOWER('aarav.sharma.' || substr(s_id::text, 1, 8) || '@example.com') LIMIT 1;
        IF m_aarav IS NULL THEN
            INSERT INTO public.profiles (school_id, user_id, full_name, email, role, class, created_at, updated_at)
            VALUES (s_id, gen_random_uuid(), 'Aarav Sharma', 'aarav.sharma.' || substr(s_id::text, 1, 8) || '@example.com', 'student', 'Class 9-A', NOW(), NOW())
            RETURNING id INTO m_aarav;
        END IF;

        -- 2. Diya Singh
        SELECT id INTO m_diya FROM public.profiles WHERE LOWER(email) = LOWER('diya.singh.' || substr(s_id::text, 1, 8) || '@example.com') LIMIT 1;
        IF m_diya IS NULL THEN
            INSERT INTO public.profiles (school_id, user_id, full_name, email, role, class, created_at, updated_at)
            VALUES (s_id, gen_random_uuid(), 'Diya Singh', 'diya.singh.' || substr(s_id::text, 1, 8) || '@example.com', 'student', 'Class 10-B', NOW(), NOW())
            RETURNING id INTO m_diya;
        END IF;

        -- 3. Rahul Kumar
        SELECT id INTO m_rahul FROM public.profiles WHERE LOWER(email) = LOWER('rahul.kumar.' || substr(s_id::text, 1, 8) || '@example.com') LIMIT 1;
        IF m_rahul IS NULL THEN
            INSERT INTO public.profiles (school_id, user_id, full_name, email, role, class, department, created_at, updated_at)
            VALUES (s_id, gen_random_uuid(), 'Rahul Kumar', 'rahul.kumar.' || substr(s_id::text, 1, 8) || '@example.com', 'student', 'B.Tech - CSE', 'Computer Science', NOW(), NOW())
            RETURNING id INTO m_rahul;
        END IF;

        -- 4. Neha Verma
        SELECT id INTO m_neha FROM public.profiles WHERE LOWER(email) = LOWER('neha.verma.' || substr(s_id::text, 1, 8) || '@example.com') LIMIT 1;
        IF m_neha IS NULL THEN
            INSERT INTO public.profiles (school_id, user_id, full_name, email, role, class, created_at, updated_at)
            VALUES (s_id, gen_random_uuid(), 'Neha Verma', 'neha.verma.' || substr(s_id::text, 1, 8) || '@example.com', 'student', 'Class 11-A', NOW(), NOW())
            RETURNING id INTO m_neha;
        END IF;

        -- 5. Amit Sharma
        SELECT id INTO m_amit FROM public.profiles WHERE LOWER(email) = LOWER('amit.sharma.' || substr(s_id::text, 1, 8) || '@example.com') LIMIT 1;
        IF m_amit IS NULL THEN
            INSERT INTO public.profiles (school_id, user_id, full_name, email, role, department, created_at, updated_at)
            VALUES (s_id, gen_random_uuid(), 'Amit Sharma', 'amit.sharma.' || substr(s_id::text, 1, 8) || '@example.com', 'teacher', 'Teacher - Mathematics', NOW(), NOW())
            RETURNING id INTO m_amit;
        END IF;

        -- 6. Pooja Patel
        SELECT id INTO m_pooja FROM public.profiles WHERE LOWER(email) = LOWER('pooja.patel.' || substr(s_id::text, 1, 8) || '@example.com') LIMIT 1;
        IF m_pooja IS NULL THEN
            INSERT INTO public.profiles (school_id, user_id, full_name, email, role, class, department, created_at, updated_at)
            VALUES (s_id, gen_random_uuid(), 'Pooja Patel', 'pooja.patel.' || substr(s_id::text, 1, 8) || '@example.com', 'student', 'B.Tech - IT', 'Information Tech', NOW(), NOW())
            RETURNING id INTO m_pooja;
        END IF;

        -- 7. Karan Malhotra
        SELECT id INTO m_karan FROM public.profiles WHERE LOWER(email) = LOWER('karan.malhotra.' || substr(s_id::text, 1, 8) || '@example.com') LIMIT 1;
        IF m_karan IS NULL THEN
            INSERT INTO public.profiles (school_id, user_id, full_name, email, role, class, department, created_at, updated_at)
            VALUES (s_id, gen_random_uuid(), 'Karan Malhotra', 'karan.malhotra.' || substr(s_id::text, 1, 8) || '@example.com', 'student', 'MBA - Semester 2', 'Management', NOW(), NOW())
            RETURNING id INTO m_karan;
        END IF;

        -- 8. Rohan Mehta
        SELECT id INTO m_rohan FROM public.profiles WHERE LOWER(email) = LOWER('rohan.mehta.' || substr(s_id::text, 1, 8) || '@example.com') LIMIT 1;
        IF m_rohan IS NULL THEN
            INSERT INTO public.profiles (school_id, user_id, full_name, email, role, class, created_at, updated_at)
            VALUES (s_id, gen_random_uuid(), 'Rohan Mehta', 'rohan.mehta.' || substr(s_id::text, 1, 8) || '@example.com', 'student', 'Class 12-C', NOW(), NOW())
            RETURNING id INTO m_rohan;
        END IF;

        -- 9. Dr. Meera Joshi
        SELECT id INTO m_meera FROM public.profiles WHERE LOWER(email) = LOWER('meera.joshi.' || substr(s_id::text, 1, 8) || '@example.com') LIMIT 1;
        IF m_meera IS NULL THEN
            INSERT INTO public.profiles (school_id, user_id, full_name, email, role, department, created_at, updated_at)
            VALUES (s_id, gen_random_uuid(), 'Dr. Meera Joshi', 'meera.joshi.' || substr(s_id::text, 1, 8) || '@example.com', 'teacher', 'Faculty - ECE', NOW(), NOW())
            RETURNING id INTO m_meera;
        END IF;

        -- 10. Siddharth Jain
        SELECT id INTO m_siddharth FROM public.profiles WHERE LOWER(email) = LOWER('siddharth.jain.' || substr(s_id::text, 1, 8) || '@example.com') LIMIT 1;
        IF m_siddharth IS NULL THEN
            INSERT INTO public.profiles (school_id, user_id, full_name, email, role, class, department, created_at, updated_at)
            VALUES (s_id, gen_random_uuid(), 'Siddharth Jain', 'siddharth.jain.' || substr(s_id::text, 1, 8) || '@example.com', 'student', 'BCA - Semester 4', 'Computer Apps', NOW(), NOW())
            RETURNING id INTO m_siddharth;
        END IF;


        -- Delete old test requests for this school
        DELETE FROM public.library_requests WHERE school_id = s_id AND request_number LIKE 'REQ-00025%';
        DELETE FROM public.library_requests WHERE school_id = s_id AND request_number LIKE 'REQ-00024%';

        -- Seed 10 requests matching screenshot exact codes:
        -- REQ-000256: The Psychology of Money | Book | Aarav Sharma (Class 9-A) | High | New | 29 May 2026 10:15 AM
        INSERT INTO public.library_requests (
            school_id, request_number, requester_user_id, title, author, request_type, category_code, priority, status, availability_status, preferred_format, reason, created_at, updated_at
        ) VALUES (
            s_id, 'REQ-000256', m_aarav, 'The Psychology of Money', 'Morgan Housel', 'Book', 'BOOK', 'High', 'NEW', 'AVAILABLE', 'Physical', 'Required for personal reading and project preparation.', '2026-05-29 10:15:00+05:30', '2026-05-29 10:15:00+05:30'
        );

        -- REQ-000255: Atomic Habits | E-Book | Diya Singh (Class 10-B) | Medium | In Progress | 28 May 2026 09:30 AM
        INSERT INTO public.library_requests (
            school_id, request_number, requester_user_id, title, author, request_type, category_code, priority, status, availability_status, preferred_format, reason, created_at, updated_at
        ) VALUES (
            s_id, 'REQ-000255', m_diya, 'Atomic Habits', 'James Clear', 'E-Book', 'EBOOK', 'Medium', 'IN_PROGRESS', 'AVAILABLE', 'E-Book (Kindle)', 'Habit building module preparation.', '2026-05-28 09:30:00+05:30', '2026-05-29 11:20:00+05:30'
        );

        -- REQ-000254: Introduction to Machine Learning | Digital Resource | Rahul Kumar (B.Tech - CSE) | High | Resolved | 27 May 2026 04:45 PM
        INSERT INTO public.library_requests (
            school_id, request_number, requester_user_id, title, author, request_type, category_code, priority, status, availability_status, preferred_format, reason, created_at, updated_at
        ) VALUES (
            s_id, 'REQ-000254', m_rahul, 'Introduction to Machine Learning', 'Ethen Alpaydin', 'Digital Resource', 'DIGITAL_RESOURCE', 'High', 'RESOLVED', 'AVAILABLE', 'PDF', 'Semester project thesis reference.', '2026-05-27 16:45:00+05:30', '2026-05-28 14:10:00+05:30'
        );

        -- REQ-000253: Wings of Fire | Book | Neha Verma (Class 11-A) | Low | Completed | 25 May 2026 01:20 PM
        INSERT INTO public.library_requests (
            school_id, request_number, requester_user_id, title, author, request_type, category_code, priority, status, availability_status, preferred_format, reason, created_at, updated_at
        ) VALUES (
            s_id, 'REQ-000253', m_neha, 'Wings of Fire', 'A.P.J. Abdul Kalam', 'Book', 'BOOK', 'Low', 'COMPLETED', 'AVAILABLE', 'Physical', 'Science club autobiography reading.', '2026-05-25 13:20:00+05:30', '2026-05-27 10:00:00+05:30'
        );

        -- REQ-000252: Research Methodology | Book | Amit Sharma (Teacher - Mathematics) | Medium | In Progress | 24 May 2026 03:40 PM
        INSERT INTO public.library_requests (
            school_id, request_number, requester_user_id, title, author, request_type, category_code, priority, status, availability_status, preferred_format, reason, created_at, updated_at
        ) VALUES (
            s_id, 'REQ-000252', m_amit, 'Research Methodology', 'C.R. Kothari', 'Book', 'BOOK', 'Medium', 'IN_PROGRESS', 'NOT_AVAILABLE', 'Hard Copy', 'Department syllabus design.', '2026-05-24 15:40:00+05:30', '2026-05-26 09:15:00+05:30'
        );

        -- REQ-000251: Data Structures and Algorithms | Book | Pooja Patel (B.Tech - IT) | High | Rejected | 24 May 2026 09:10 AM
        INSERT INTO public.library_requests (
            school_id, request_number, requester_user_id, title, author, request_type, category_code, priority, status, availability_status, preferred_format, rejection_reason, created_at, updated_at
        ) VALUES (
            s_id, 'REQ-000251', m_pooja, 'Data Structures and Algorithms', 'Mark Allen Weiss', 'Book', 'BOOK', 'High', 'REJECTED', 'NOT_AVAILABLE', 'Physical', 'Duplicate request. 3 copies already in departmental reserve.', '2026-05-24 09:10:00+05:30', '2026-05-24 16:22:00+05:30'
        );

        -- REQ-000250: Financial Modelling | E-Book | Karan Malhotra (MBA - Semester 2) | Medium | Cancelled | 23 May 2026 02:05 PM
        INSERT INTO public.library_requests (
            school_id, request_number, requester_user_id, title, author, request_type, category_code, priority, status, availability_status, preferred_format, cancellation_reason, created_at, updated_at
        ) VALUES (
            s_id, 'REQ-000250', m_karan, 'Financial Modelling', 'Simon Benninga', 'E-Book', 'EBOOK', 'Medium', 'CANCELED', 'LICENSE_REQUIRED', 'E-Book (Kindle)', 'Found free chapter access via online university portal.', '2026-05-23 14:05:00+05:30', '2026-05-23 15:10:00+05:30'
        );

        -- REQ-000249: Python Crash Course | Book | Rohan Mehta (Class 12-C) | Low | Resolved | 22 May 2026 11:55 AM
        INSERT INTO public.library_requests (
            school_id, request_number, requester_user_id, title, author, request_type, category_code, priority, status, availability_status, preferred_format, reason, created_at, updated_at
        ) VALUES (
            s_id, 'REQ-000249', m_rohan, 'Python Crash Course', 'Eric Matthes', 'Book', 'BOOK', 'Low', 'RESOLVED', 'AVAILABLE', 'Physical', 'CBSE Computer Science practicals.', '2026-05-22 11:55:00+05:30', '2026-05-23 09:20:00+05:30'
        );

        -- REQ-000248: IEEE Xplore Access | Digital Resource | Dr. Meera Joshi (Faculty - ECE) | High | In Progress | 22 May 2026 10:05 AM
        INSERT INTO public.library_requests (
            school_id, request_number, requester_user_id, title, author, request_type, category_code, priority, status, availability_status, preferred_format, reason, created_at, updated_at
        ) VALUES (
            s_id, 'REQ-000248', m_meera, 'IEEE Xplore Access', 'IEEE Publications', 'Digital Resource', 'DIGITAL_RESOURCE', 'High', 'IN_PROGRESS', 'LICENSE_REQUIRED', 'Web Access', 'Faculty research paper submission for IEEE Transaction.', '2026-05-22 10:05:00+05:30', '2026-05-23 09:10:00+05:30'
        );

        -- REQ-000247: Design Patterns | E-Book | Siddharth Jain (BCA - Semester 4) | Low | Completed | 21 May 2026 04:50 PM
        INSERT INTO public.library_requests (
            school_id, request_number, requester_user_id, title, author, request_type, category_code, priority, status, availability_status, preferred_format, reason, created_at, updated_at
        ) VALUES (
            s_id, 'REQ-000247', m_siddharth, 'Design Patterns', 'Erich Gamma', 'E-Book', 'EBOOK', 'Low', 'COMPLETED', 'AVAILABLE', 'PDF', 'Software Engineering course.', '2026-05-21 16:50:00+05:30', '2026-05-22 11:40:00+05:30'
        );
    END LOOP;
END $$;


