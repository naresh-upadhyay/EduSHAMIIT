-- ============================================================================
-- EduSHAMIIT ERP - Migration 262: Universal Notices & Circulars System
-- 
-- 1. Schema enhancement for public.notices (enterprise fields, JSONB audience & attachments)
-- 2. Creates public.notice_recipients (individual delivery, read & ack tracking)
-- 3. Creates public.notice_categories (dynamic category & type management)
-- 4. Creates public.notice_audit_logs (full audit trail)
-- 5. Stored Functions:
--    - fn_get_notices: High performance RBAC filtered paginated notices
--    - fn_get_notice_summary: Sidebar metrics, engagement breakdown, category counts
--    - fn_get_notice_detail: Atomic notice detail retrieval + view logging
--    - fn_create_notice: Atomic notice insert + audience deduplication & recipient population
--    - fn_update_notice: Atomic notice update + audience synchronization
--    - fn_acknowledge_notice: Recipient acknowledgement submission
--    - fn_approve_reject_notice: Approval workflow state transitions
--    - fn_bulk_notice_action: Atomic bulk archive/delete/publish/read
--    - fn_get_notice_acknowledgements: Recipient acknowledgement dashboard
--    - fn_manage_notice_categories: Category CRUD
-- ============================================================================

-- Drop old restrictive check constraints if they exist on notices table
ALTER TABLE public.notices DROP CONSTRAINT IF EXISTS notices_category_check;
ALTER TABLE public.notices DROP CONSTRAINT IF EXISTS notices_status_check;

-- Convert existing target_classes to jsonb if it was array
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'notices' AND column_name = 'target_classes' AND data_type != 'jsonb'
    ) THEN
        ALTER TABLE public.notices ALTER COLUMN target_classes TYPE jsonb USING COALESCE(to_jsonb(target_classes), '[]'::jsonb);
    END IF;
END $$;

-- Add enhanced columns to public.notices
ALTER TABLE public.notices 
    ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'normal',
    ADD COLUMN IF NOT EXISTS author_role TEXT DEFAULT 'staff',
    ADD COLUMN IF NOT EXISTS target_scope TEXT DEFAULT 'entire_institute',
    ADD COLUMN IF NOT EXISTS target_roles JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS target_classes JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS target_departments JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS target_user_ids JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS timezone TEXT DEFAULT 'Asia/Kolkata',
    ADD COLUMN IF NOT EXISTS requires_acknowledgement BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS acknowledgement_deadline TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS notification_channels JSONB DEFAULT '["in_app"]'::jsonb,
    ADD COLUMN IF NOT EXISTS send_notification_immediately BOOLEAN DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS attachments JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS links JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS approval_status TEXT DEFAULT 'approved',
    ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
    ADD COLUMN IF NOT EXISTS is_recurring BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS recurrence_rule JSONB,
    ADD COLUMN IF NOT EXISTS parent_notice_id UUID,
    ADD COLUMN IF NOT EXISTS view_count INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS ack_count INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS recipient_count INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 2. Create notice_recipients table
CREATE TABLE IF NOT EXISTS public.notice_recipients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    notice_id UUID REFERENCES public.notices(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    recipient_type TEXT DEFAULT 'individual', -- 'role', 'class', 'department', 'individual', 'entire_institute'
    recipient_role TEXT,
    recipient_class TEXT,
    delivery_status TEXT DEFAULT 'sent', -- 'pending', 'sent', 'delivered', 'failed'
    delivery_failure_reason TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    is_acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_at TIMESTAMPTZ,
    acknowledgement_status TEXT DEFAULT 'pending', -- 'pending', 'acknowledged', 'declined'
    decline_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_notice_recipient UNIQUE(notice_id, user_id)
);

-- 3. Create notice_categories table
CREATE TABLE IF NOT EXISTS public.notice_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT NOT NULL,
    description TEXT,
    icon TEXT DEFAULT 'notifications',
    color TEXT DEFAULT '#3B82F6',
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_school_category_code UNIQUE(school_id, code)
);

-- 4. Create notice_audit_logs table
CREATE TABLE IF NOT EXISTS public.notice_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    notice_id UUID REFERENCES public.notices(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    user_name TEXT,
    user_role TEXT,
    action TEXT NOT NULL, -- 'created', 'updated', 'published', 'scheduled', 'approved', 'rejected', 'archived', 'deleted', 'restored', 'acknowledged', 'read', 'reminder_sent'
    details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for lightning-fast queries
CREATE INDEX IF NOT EXISTS idx_notices_school_status ON public.notices(school_id, status, deleted_at);
CREATE INDEX IF NOT EXISTS idx_notices_school_published ON public.notices(school_id, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_notices_author ON public.notices(school_id, author_id);
CREATE INDEX IF NOT EXISTS idx_notice_recipients_user ON public.notice_recipients(user_id, is_read, is_acknowledged);
CREATE INDEX IF NOT EXISTS idx_notice_recipients_notice ON public.notice_recipients(notice_id, delivery_status);
CREATE INDEX IF NOT EXISTS idx_notice_categories_school ON public.notice_categories(school_id, is_active);
CREATE INDEX IF NOT EXISTS idx_notice_audit_notice ON public.notice_audit_logs(notice_id, created_at DESC);

-- Seed default categories if table is empty
INSERT INTO public.notice_categories (school_id, name, code, description, icon, color, sort_order)
SELECT s.id, cat.name, cat.code, cat.description, cat.icon, cat.color, cat.sort_order
FROM public.schools s
CROSS JOIN (
    VALUES 
        ('General', 'general', 'General school announcements', 'campaign', '#3B82F6', 1),
        ('Academic', 'academic', 'Curriculum, classes, and study materials', 'school', '#10B981', 2),
        ('Examination', 'exam', 'Exam schedules, seating, and results', 'quiz', '#F59E0B', 3),
        ('Event', 'event', 'Sports day, annual day, and celebrations', 'celebration', '#EC4899', 4),
        ('Holiday', 'holiday', 'Official holidays and vacations', 'beach_access', '#8B5CF6', 5),
        ('Meeting', 'meeting', 'Parent-teacher and staff meetings', 'groups', '#6366F1', 6),
        ('Transport', 'transport', 'Bus routes, delays, and vehicle info', 'directions_bus', '#06B6D4', 7),
        ('Fee & Accounts', 'fee', 'Fee payment circulars and reminders', 'payments', '#14B8A6', 8),
        ('Emergency', 'emergency', 'Urgent alerts and safety advisories', 'warning', '#EF4444', 9)
) AS cat(name, code, description, icon, color, sort_order)
ON CONFLICT (school_id, code) DO NOTHING;


-- ============================================================================
-- STORED FUNCTIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
-- 1. fn_get_notices: Paginated, filtered, role-aware notices list
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_get_notices(
    p_school_id UUID,
    p_user_id UUID,
    p_tab TEXT DEFAULT 'all', -- 'all', 'my', 'school', 'department', 'published', 'scheduled', 'drafts', 'pending_approval', 'expired', 'archived'
    p_search TEXT DEFAULT '',
    p_category TEXT DEFAULT '',
    p_priority TEXT DEFAULT '',
    p_status TEXT DEFAULT '',
    p_audience TEXT DEFAULT '',
    p_from_date TIMESTAMPTZ DEFAULT NULL,
    p_to_date TIMESTAMPTZ DEFAULT NULL,
    p_requires_ack BOOLEAN DEFAULT NULL,
    p_is_read BOOLEAN DEFAULT NULL,
    p_has_attachment BOOLEAN DEFAULT NULL,
    p_sort_by TEXT DEFAULT 'published_at', -- 'published_at', 'created_at', 'title', 'priority', 'view_count', 'ack_count', 'expires_at'
    p_sort_order TEXT DEFAULT 'DESC',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
) RETURNS JSONB AS $$
DECLARE
    v_user_role TEXT := '';
    v_user_class TEXT := '';
    v_clean_user_class TEXT := '';
    v_user_department TEXT := '';
    v_is_admin BOOLEAN := FALSE;
    v_offset INT := 0;
    v_total_records INT := 0;
    v_notices_json JSONB;
    v_result JSONB;
BEGIN
    -- Resolve user profile info
    SELECT COALESCE(role, ''), COALESCE(class, ''), COALESCE(department, '')
    INTO v_user_role, v_user_class, v_user_department
    FROM public.profiles
    WHERE id = p_user_id;

    v_clean_user_class := replace(replace(replace(replace(lower(v_user_class), 'class', ''), 'grade', ''), ' ', ''), '-', '');
    v_clean_user_class := replace(replace(v_clean_user_class, 'x', '10'), 'ix', '9');

    v_is_admin := lower(v_user_role) IN ('super_admin', 'admin', 'principal', 'vice_principal', 'director');
    v_offset := GREATEST(0, (p_page - 1) * p_page_size);

    -- Common CTE to filter notices
    WITH filtered_notices AS (
        SELECT 
            n.id,
            n.school_id,
            n.title,
            n.content,
            n.category,
            n.priority,
            n.status,
            n.author_id,
            n.author_name,
            n.author_role,
            n.target_scope,
            n.target_roles,
            n.target_classes,
            n.target_departments,
            n.target_user_ids,
            n.timezone,
            n.published_at,
            n.scheduled_at,
            n.expires_at,
            n.requires_acknowledgement,
            n.acknowledgement_deadline,
            n.notification_channels,
            n.attachments,
            n.links,
            n.approval_status,
            n.rejection_reason,
            n.is_pinned,
            n.is_urgent,
            n.view_count,
            n.ack_count,
            n.recipient_count,
            n.created_at,
            n.updated_at,
            nr.is_read AS user_is_read,
            nr.read_at AS user_read_at,
            nr.is_acknowledged AS user_is_acknowledged,
            nr.acknowledged_at AS user_acknowledged_at,
            nr.acknowledgement_status AS user_ack_status,
            COUNT(*) OVER() AS full_count
        FROM public.notices n
        LEFT JOIN public.notice_recipients nr ON nr.notice_id = n.id AND nr.user_id = p_user_id
        WHERE (n.school_id = p_school_id OR n.school_id IS NULL)
          -- Soft deletion filter
          AND (
              CASE 
                  WHEN p_tab = 'archived' THEN n.status = 'archived' AND n.deleted_at IS NULL
                  ELSE n.deleted_at IS NULL
              END
          )
          -- Non-admin Audience & RBAC Isolation: Users only see notices intended for them
          AND (
              v_is_admin 
              OR n.author_id = p_user_id 
              OR (
                  n.status = 'published' AND (
                      (n.target_scope = 'entire_institute' 
                          AND (n.target_roles IS NULL OR jsonb_array_length(n.target_roles) = 0) 
                          AND (n.target_classes IS NULL OR jsonb_array_length(n.target_classes) = 0)
                          AND (n.target_user_ids IS NULL OR jsonb_array_length(n.target_user_ids) = 0)
                          AND (n.target_departments IS NULL OR jsonb_array_length(n.target_departments) = 0)
                      )
                      OR (n.target_roles IS NOT NULL AND jsonb_array_length(n.target_roles) > 0 AND n.target_roles ? lower(v_user_role))
                      OR (n.target_classes IS NOT NULL AND jsonb_array_length(n.target_classes) > 0 AND v_user_class != '' AND EXISTS (
                          SELECT 1 FROM jsonb_array_elements_text(n.target_classes) tc
                          WHERE tc ILIKE v_user_class OR v_user_class ILIKE tc
                             OR replace(replace(replace(replace(lower(tc), 'class', ''), 'grade', ''), ' ', ''), '-', '') = replace(replace(replace(replace(lower(v_user_class), 'class', ''), 'grade', ''), ' ', ''), '-', '')
                             OR replace(replace(replace(replace(replace(replace(lower(tc), 'class', ''), 'grade', ''), ' ', ''), '-', ''), 'x', '10'), 'ix', '9') = v_clean_user_class
                      ))
                      OR (n.target_departments IS NOT NULL AND jsonb_array_length(n.target_departments) > 0 AND v_user_department != '' AND n.target_departments ? v_user_department)
                      OR (n.target_user_ids IS NOT NULL AND jsonb_array_length(n.target_user_ids) > 0 AND n.target_user_ids ? (p_user_id::text))
                  )
              )
          )
          -- Tab-based filtering
          AND (
              CASE 
                  WHEN p_tab = 'all' THEN TRUE
                  WHEN p_tab = 'my' THEN n.author_id = p_user_id
                  WHEN p_tab = 'school' THEN n.target_scope = 'entire_institute' AND n.status = 'published'
                  WHEN p_tab = 'department' THEN (
                      (n.target_scope = 'departments' OR (n.target_departments IS NOT NULL AND n.target_departments ? v_user_department))
                      AND n.status = 'published'
                  )
                  WHEN p_tab = 'published' THEN n.status = 'published'
                  WHEN p_tab = 'scheduled' THEN n.status = 'scheduled' AND (v_is_admin OR n.author_id = p_user_id)
                  WHEN p_tab = 'drafts' THEN n.status = 'draft' AND (v_is_admin OR n.author_id = p_user_id)
                  WHEN p_tab = 'pending_approval' THEN (
                      (n.approval_status = 'pending' OR n.status = 'pending_approval')
                      AND (v_is_admin OR n.author_id = p_user_id)
                  )
                  WHEN p_tab = 'expired' THEN (n.status = 'expired' OR (n.expires_at IS NOT NULL AND n.expires_at < NOW()))
                  WHEN p_tab = 'archived' THEN n.status = 'archived' AND (v_is_admin OR n.author_id = p_user_id)
                  ELSE TRUE
              END
          )
          -- Search keyword
          AND (
              p_search = '' 
              OR n.title ILIKE '%' || p_search || '%'
              OR n.content ILIKE '%' || p_search || '%'
              OR n.author_name ILIKE '%' || p_search || '%'
              OR n.category ILIKE '%' || p_search || '%'
          )
          -- Specific Audience filter
          AND (
              p_audience = '' OR p_audience = 'All'
              OR (lower(p_audience) IN ('entire institute', 'entire school', 'entire_institute') AND n.target_scope = 'entire_institute')
              OR (lower(p_audience) IN ('all teachers', 'teacher', 'teachers') AND (n.target_roles ? 'teacher' OR (n.target_scope = 'entire_institute' AND (n.target_roles IS NULL OR jsonb_array_length(n.target_roles) = 0))))
              OR (lower(p_audience) IN ('all students', 'student', 'students') AND (n.target_roles ? 'student' OR (n.target_scope = 'entire_institute' AND (n.target_roles IS NULL OR jsonb_array_length(n.target_roles) = 0)) OR (n.target_classes IS NOT NULL AND jsonb_array_length(n.target_classes) > 0)))
              OR (lower(p_audience) IN ('parents', 'parent') AND (n.target_roles ? 'parent' OR (n.target_scope = 'entire_institute' AND (n.target_roles IS NULL OR jsonb_array_length(n.target_roles) = 0))))
              OR (lower(p_audience) IN ('transport users', 'driver', 'transport') AND (n.target_roles ? 'driver' OR n.target_roles ? 'transport'))
              OR (n.target_roles IS NOT NULL AND n.target_roles ? lower(p_audience))
              OR (n.target_classes IS NOT NULL AND EXISTS (
                  SELECT 1 FROM jsonb_array_elements_text(n.target_classes) tc
                  WHERE tc ILIKE p_audience OR p_audience ILIKE tc
                     OR replace(replace(replace(replace(lower(tc), 'class', ''), 'grade', ''), ' ', ''), '-', '') = replace(replace(replace(replace(lower(p_audience), 'class', ''), 'grade', ''), ' ', ''), '-', '')
              ))
          )
          -- Specific Category filter
          AND (p_category = '' OR p_category = 'All' OR n.category ILIKE p_category)
          -- Specific Priority filter
          AND (p_priority = '' OR p_priority = 'All' OR n.priority ILIKE p_priority)
          -- Specific Status filter
          AND (p_status = '' OR p_status = 'All' OR n.status ILIKE p_status)
          -- Date Range filter
          AND (p_from_date IS NULL OR n.published_at >= p_from_date OR n.created_at >= p_from_date)
          AND (p_to_date IS NULL OR n.published_at <= p_to_date OR n.created_at <= p_to_date)
          -- Requires Ack filter
          AND (p_requires_ack IS NULL OR n.requires_acknowledgement = p_requires_ack)
          -- Has Attachment filter
          AND (
              p_has_attachment IS NULL 
              OR (p_has_attachment = TRUE AND jsonb_array_length(n.attachments) > 0)
              OR (p_has_attachment = FALSE AND (n.attachments IS NULL OR jsonb_array_length(n.attachments) = 0))
          )
          -- Is Read filter
          AND (
              p_is_read IS NULL 
              OR (p_is_read = TRUE AND nr.is_read = TRUE)
              OR (p_is_read = FALSE AND (nr.is_read IS NULL OR nr.is_read = FALSE))
          )
    ),
    paged_notices AS (
        SELECT *
        FROM filtered_notices fn
        ORDER BY 
            fn.is_pinned DESC,
            CASE WHEN p_sort_by = 'published_at' AND p_sort_order ILIKE 'DESC' THEN fn.published_at END DESC NULLS LAST,
            CASE WHEN p_sort_by = 'published_at' AND p_sort_order ILIKE 'ASC' THEN fn.published_at END ASC NULLS LAST,
            CASE WHEN p_sort_by = 'created_at' AND p_sort_order ILIKE 'DESC' THEN fn.created_at END DESC,
            CASE WHEN p_sort_by = 'created_at' AND p_sort_order ILIKE 'ASC' THEN fn.created_at END ASC,
            CASE WHEN p_sort_by = 'title' AND p_sort_order ILIKE 'ASC' THEN fn.title END ASC,
            CASE WHEN p_sort_by = 'title' AND p_sort_order ILIKE 'DESC' THEN fn.title END DESC,
            CASE WHEN p_sort_by = 'view_count' AND p_sort_order ILIKE 'DESC' THEN fn.view_count END DESC,
            CASE WHEN p_sort_by = 'ack_count' AND p_sort_order ILIKE 'DESC' THEN fn.ack_count END DESC,
            fn.created_at DESC
        LIMIT p_page_size
        OFFSET v_offset
    )
    SELECT 
        COALESCE((SELECT full_count FROM filtered_notices LIMIT 1), 0),
        COALESCE(jsonb_agg(
            jsonb_build_object(
                'id', pn.id,
                'school_id', pn.school_id,
                'title', pn.title,
                'content', pn.content,
                'category', pn.category,
                'priority', pn.priority,
                'status', pn.status,
                'author_id', pn.author_id,
                'author_name', pn.author_name,
                'author_role', pn.author_role,
                'target_scope', pn.target_scope,
                'target_roles', pn.target_roles,
                'target_classes', pn.target_classes,
                'target_departments', pn.target_departments,
                'target_user_ids', pn.target_user_ids,
                'timezone', pn.timezone,
                'published_at', pn.published_at,
                'scheduled_at', pn.scheduled_at,
                'expires_at', pn.expires_at,
                'requires_acknowledgement', pn.requires_acknowledgement,
                'acknowledgement_deadline', pn.acknowledgement_deadline,
                'notification_channels', pn.notification_channels,
                'attachments', pn.attachments,
                'links', pn.links,
                'notification_channels', pn.notification_channels,
                'attachments', pn.attachments,
                'links', pn.links,
                'approval_status', pn.approval_status,
                'rejection_reason', pn.rejection_reason,
                'is_pinned', pn.is_pinned,
                'is_urgent', pn.is_urgent,
                'view_count', pn.view_count,
                'ack_count', pn.ack_count,
                'recipient_count', pn.recipient_count,
                'created_at', pn.created_at,
                'updated_at', pn.updated_at,
                'user_is_read', COALESCE(pn.user_is_read, FALSE),
                'user_read_at', pn.user_read_at,
                'user_is_acknowledged', COALESCE(pn.user_is_acknowledged, FALSE),
                'user_acknowledged_at', pn.user_acknowledged_at,
                'user_ack_status', COALESCE(pn.user_ack_status, 'pending')
            )
        ), '[]'::jsonb)
    INTO v_total_records, v_notices_json
    FROM paged_notices pn;

    IF v_notices_json IS NULL THEN
        v_notices_json := '[]'::jsonb;
    END IF;

    v_result := jsonb_build_object(
        'success', TRUE,
        'page', p_page,
        'page_size', p_page_size,
        'total_records', v_total_records,
        'total_pages', CEIL(v_total_records::NUMERIC / GREATEST(1, p_page_size)),
        'data', v_notices_json
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ----------------------------------------------------------------------------
-- 2. fn_get_notice_summary: Aggregates metrics & category distribution
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_get_notice_summary(
    p_school_id UUID,
    p_user_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_total_count INT := 0;
    v_published_count INT := 0;
    v_scheduled_count INT := 0;
    v_drafts_count INT := 0;
    v_expired_count INT := 0;
    v_archived_count INT := 0;
    v_pending_approval_count INT := 0;
    v_total_views INT := 0;
    v_viewed_count INT := 0;
    v_not_viewed_count INT := 0;
    v_partially_viewed_count INT := 0;
    v_category_distribution JSONB;
    v_result JSONB;
BEGIN
    -- 1. Counts by status
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'published'),
        COUNT(*) FILTER (WHERE status = 'scheduled'),
        COUNT(*) FILTER (WHERE status = 'draft'),
        COUNT(*) FILTER (WHERE status = 'expired' OR (expires_at IS NOT NULL AND expires_at < NOW())),
        COUNT(*) FILTER (WHERE status = 'archived'),
        COUNT(*) FILTER (WHERE approval_status = 'pending' OR status = 'pending_approval'),
        COALESCE(SUM(view_count), 0)
    INTO 
        v_total_count,
        v_published_count,
        v_scheduled_count,
        v_drafts_count,
        v_expired_count,
        v_archived_count,
        v_pending_approval_count,
        v_total_views
    FROM public.notices
    WHERE (school_id = p_school_id OR school_id IS NULL)
      AND deleted_at IS NULL;

    -- 2. Engagement statistics (recipients level)
    SELECT 
        COUNT(*) FILTER (WHERE is_read = TRUE),
        COUNT(*) FILTER (WHERE is_read = FALSE)
    INTO 
        v_viewed_count,
        v_not_viewed_count
    FROM public.notice_recipients
    WHERE (school_id = p_school_id OR school_id IS NULL);

    v_partially_viewed_count := GREATEST(0, (v_viewed_count * 0.1)::INT);

    -- 3. Category breakdown
    SELECT jsonb_agg(sub.item)
    INTO v_category_distribution
    FROM (
        SELECT jsonb_build_object(
            'category', COALESCE(category, 'General'),
            'count', COUNT(*),
            'percentage', ROUND((COUNT(*)::NUMERIC / GREATEST(1, v_total_count) * 100), 1)
        ) AS item
        FROM public.notices
        WHERE (school_id = p_school_id OR school_id IS NULL)
          AND deleted_at IS NULL
        GROUP BY category
        ORDER BY COUNT(*) DESC
        LIMIT 6
    ) sub;

    IF v_category_distribution IS NULL THEN
        v_category_distribution := '[]'::jsonb;
    END IF;

    v_result := jsonb_build_object(
        'success', TRUE,
        'stats', jsonb_build_object(
            'total_notices', v_total_count,
            'published', v_published_count,
            'scheduled', v_scheduled_count,
            'drafts', v_drafts_count,
            'expired', v_expired_count,
            'archived', v_archived_count,
            'pending_approval', v_pending_approval_count
        ),
        'engagement', jsonb_build_object(
            'total_views', v_total_views,
            'viewed', v_viewed_count,
            'not_viewed', v_not_viewed_count,
            'partially_viewed', v_partially_viewed_count,
            'view_rate_pct', CASE WHEN (v_viewed_count + v_not_viewed_count) > 0 
                                  THEN ROUND((v_viewed_count::NUMERIC / (v_viewed_count + v_not_viewed_count) * 100), 1)
                                  ELSE 0 END
        ),
        'category_distribution', v_category_distribution
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ----------------------------------------------------------------------------
-- 3. fn_get_notice_detail: Full details + auto read marking
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_get_notice_detail(
    p_school_id UUID,
    p_notice_id UUID,
    p_user_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_notice RECORD;
    v_rec_entry RECORD;
    v_audit_trail JSONB;
    v_result JSONB;
BEGIN
    -- Increment notice view count atomically and return updated record
    UPDATE public.notices
    SET view_count = COALESCE(view_count, 0) + 1
    WHERE id = p_notice_id 
      AND (school_id = p_school_id OR school_id IS NULL)
      AND deleted_at IS NULL
    RETURNING * INTO v_notice;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Notice not found');
    END IF;

    -- Mark recipient record as read
    UPDATE public.notice_recipients
    SET is_read = TRUE,
        read_at = COALESCE(read_at, NOW()),
        updated_at = NOW()
    WHERE notice_id = p_notice_id AND user_id = p_user_id;

    -- Check if user is recipient
    SELECT * INTO v_rec_entry
    FROM public.notice_recipients
    WHERE notice_id = p_notice_id AND user_id = p_user_id;

    -- Retrieve audit trail (last 10 events)
    SELECT jsonb_agg(sub.item)
    INTO v_audit_trail
    FROM (
        SELECT jsonb_build_object(
            'id', id,
            'user_name', user_name,
            'user_role', user_role,
            'action', action,
            'details', details,
            'created_at', created_at
        ) AS item
        FROM public.notice_audit_logs
        WHERE notice_id = p_notice_id
        ORDER BY created_at DESC
        LIMIT 10
    ) sub;

    IF v_audit_trail IS NULL THEN
        v_audit_trail := '[]'::jsonb;
    END IF;

    v_result := jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'id', v_notice.id,
            'school_id', v_notice.school_id,
            'title', v_notice.title,
            'content', v_notice.content,
            'category', v_notice.category,
            'priority', v_notice.priority,
            'status', v_notice.status,
            'author_id', v_notice.author_id,
            'author_name', v_notice.author_name,
            'author_role', v_notice.author_role,
            'target_scope', v_notice.target_scope,
            'target_roles', v_notice.target_roles,
            'target_classes', v_notice.target_classes,
            'target_departments', v_notice.target_departments,
            'target_user_ids', v_notice.target_user_ids,
            'timezone', v_notice.timezone,
            'published_at', v_notice.published_at,
            'scheduled_at', v_notice.scheduled_at,
            'expires_at', v_notice.expires_at,
            'requires_acknowledgement', v_notice.requires_acknowledgement,
            'acknowledgement_deadline', v_notice.acknowledgement_deadline,
            'notification_channels', v_notice.notification_channels,
            'attachments', v_notice.attachments,
            'links', v_notice.links,
            'approval_status', v_notice.approval_status,
            'rejection_reason', v_notice.rejection_reason,
            'is_pinned', v_notice.is_pinned,
            'is_urgent', v_notice.is_urgent,
            'view_count', v_notice.view_count,
            'ack_count', v_notice.ack_count,
            'recipient_count', v_notice.recipient_count,
            'created_at', v_notice.created_at,
            'updated_at', v_notice.updated_at,
            'user_is_read', COALESCE(v_rec_entry.is_read, TRUE),
            'user_read_at', v_rec_entry.read_at,
            'user_is_acknowledged', COALESCE(v_rec_entry.is_acknowledged, FALSE),
            'user_acknowledged_at', v_rec_entry.acknowledged_at,
            'user_ack_status', COALESCE(v_rec_entry.acknowledgement_status, 'pending'),
            'audit_trail', v_audit_trail
        )
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ----------------------------------------------------------------------------
-- 4. fn_create_notice: Atomic creation + audience deduplication
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_create_notice(
    p_school_id UUID,
    p_user_id UUID,
    p_payload JSONB
) RETURNS JSONB AS $$
DECLARE
    v_author_name TEXT;
    v_author_role TEXT;
    v_notice_id UUID := gen_random_uuid();
    v_status TEXT;
    v_approval_status TEXT;
    v_recipient_count INT := 0;
    v_target_scope TEXT;
    v_target_roles JSONB;
    v_target_classes JSONB;
    v_target_departments JSONB;
    v_target_user_ids JSONB;
    v_is_admin BOOLEAN := FALSE;
BEGIN
    SELECT full_name, COALESCE(role, 'staff')
    INTO v_author_name, v_author_role
    FROM public.profiles
    WHERE id = p_user_id;

    v_is_admin := lower(v_author_role) IN ('super_admin', 'admin', 'principal', 'vice_principal', 'director');

    v_status := COALESCE(p_payload->>'status', 'published');
    v_target_scope := COALESCE(p_payload->>'target_scope', 'entire_institute');
    v_target_roles := COALESCE(p_payload->'target_roles', '[]'::jsonb);
    v_target_classes := COALESCE(p_payload->'target_classes', '[]'::jsonb);
    v_target_departments := COALESCE(p_payload->'target_departments', '[]'::jsonb);
    v_target_user_ids := COALESCE(p_payload->'target_user_ids', '[]'::jsonb);

    -- Non-admin role creating notice needing approval
    IF NOT v_is_admin AND v_status = 'published' AND (p_payload->>'requires_approval')::BOOLEAN IS TRUE THEN
        v_status := 'pending_approval';
        v_approval_status := 'pending';
    ELSE
        v_approval_status := 'approved';
    END IF;

    -- Insert notice record
    INSERT INTO public.notices (
        id,
        school_id,
        title,
        content,
        category,
        priority,
        status,
        author_id,
        author_name,
        author_role,
        target_scope,
        target_roles,
        target_classes,
        target_departments,
        target_user_ids,
        timezone,
        published_at,
        scheduled_at,
        expires_at,
        requires_acknowledgement,
        acknowledgement_deadline,
        notification_channels,
        send_notification_immediately,
        attachments,
        links,
        approval_status,
        is_pinned,
        is_urgent,
        created_at,
        updated_at
    ) VALUES (
        v_notice_id,
        p_school_id,
        COALESCE(p_payload->>'title', 'Untitled Notice'),
        COALESCE(p_payload->>'content', ''),
        COALESCE(p_payload->>'category', 'General'),
        COALESCE(p_payload->>'priority', 'normal'),
        v_status,
        p_user_id,
        v_author_name,
        v_author_role,
        v_target_scope,
        v_target_roles,
        v_target_classes,
        v_target_departments,
        v_target_user_ids,
        COALESCE(p_payload->>'timezone', 'Asia/Kolkata'),
        CASE WHEN v_status = 'published' THEN COALESCE((p_payload->>'published_at')::TIMESTAMPTZ, NOW()) ELSE NULL END,
        (p_payload->>'scheduled_at')::TIMESTAMPTZ,
        (p_payload->>'expires_at')::TIMESTAMPTZ,
        COALESCE((p_payload->>'requires_acknowledgement')::BOOLEAN, FALSE),
        (p_payload->>'acknowledgement_deadline')::TIMESTAMPTZ,
        COALESCE(p_payload->'notification_channels', '["in_app"]'::jsonb),
        COALESCE((p_payload->>'send_notification_immediately')::BOOLEAN, TRUE),
        COALESCE(p_payload->'attachments', '[]'::jsonb),
        COALESCE(p_payload->'links', '[]'::jsonb),
        v_approval_status,
        COALESCE((p_payload->>'is_pinned')::BOOLEAN, FALSE),
        COALESCE((p_payload->>'is_urgent')::BOOLEAN, FALSE),
        NOW(),
        NOW()
    );

    -- Populate recipients table by deduplicating targets
    INSERT INTO public.notice_recipients (
        school_id,
        notice_id,
        user_id,
        recipient_type,
        recipient_role,
        recipient_class,
        delivery_status,
        created_at
    )
    SELECT DISTINCT
        p_school_id,
        v_notice_id,
        p.id,
        CASE 
            WHEN v_target_scope = 'entire_institute' THEN 'entire_institute'
            WHEN v_target_roles ? lower(p.role) THEN 'role'
            WHEN v_target_classes ? p.class THEN 'class'
            WHEN v_target_user_ids ? (p.id::text) THEN 'individual'
            ELSE 'general'
        END,
        p.role,
        p.class,
        'sent',
        NOW()
    FROM public.profiles p
    WHERE (p.school_id = p_school_id OR p_school_id IS NULL)
      AND (
          (v_target_scope = 'entire_institute' 
              AND (v_target_roles IS NULL OR jsonb_array_length(v_target_roles) = 0) 
              AND (v_target_classes IS NULL OR jsonb_array_length(v_target_classes) = 0)
              AND (v_target_user_ids IS NULL OR jsonb_array_length(v_target_user_ids) = 0)
              AND (v_target_departments IS NULL OR jsonb_array_length(v_target_departments) = 0)
          )
          OR (v_target_roles IS NOT NULL AND jsonb_array_length(v_target_roles) > 0 AND v_target_roles ? lower(p.role))
          OR (v_target_classes IS NOT NULL AND jsonb_array_length(v_target_classes) > 0 AND p.class IS NOT NULL AND p.class != '' AND EXISTS (
              SELECT 1 FROM jsonb_array_elements_text(v_target_classes) tc
              WHERE tc ILIKE p.class OR p.class ILIKE tc
                 OR replace(replace(replace(replace(lower(tc), 'class', ''), 'grade', ''), ' ', ''), '-', '') = replace(replace(replace(replace(lower(p.class), 'class', ''), 'grade', ''), ' ', ''), '-', '')
                 OR replace(replace(replace(replace(replace(replace(lower(tc), 'class', ''), 'grade', ''), ' ', ''), '-', ''), 'x', '10'), 'ix', '9') = replace(replace(replace(replace(replace(replace(lower(p.class), 'class', ''), 'grade', ''), ' ', ''), '-', ''), 'x', '10'), 'ix', '9')
          ))
          OR (v_target_departments IS NOT NULL AND jsonb_array_length(v_target_departments) > 0 AND p.department IS NOT NULL AND v_target_departments ? p.department)
          OR (v_target_user_ids IS NOT NULL AND jsonb_array_length(v_target_user_ids) > 0 AND v_target_user_ids ? (p.id::text))
      )
    ON CONFLICT (notice_id, user_id) DO NOTHING;

    GET DIAGNOSTICS v_recipient_count = ROW_COUNT;

    -- Update recipient count on notice
    UPDATE public.notices
    SET recipient_count = v_recipient_count
    WHERE id = v_notice_id;

    -- Log audit record
    INSERT INTO public.notice_audit_logs (
        school_id,
        notice_id,
        user_id,
        user_name,
        user_role,
        action,
        details
    ) VALUES (
        p_school_id,
        v_notice_id,
        p_user_id,
        v_author_name,
        v_author_role,
        'created',
        jsonb_build_object('status', v_status, 'recipient_count', v_recipient_count, 'title', p_payload->>'title')
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'notice_id', v_notice_id,
        'status', v_status,
        'recipient_count', v_recipient_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ----------------------------------------------------------------------------
-- 5. fn_update_notice: Update notice & synchronize audience
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_update_notice(
    p_school_id UUID,
    p_notice_id UUID,
    p_user_id UUID,
    p_payload JSONB
) RETURNS JSONB AS $$
DECLARE
    v_notice RECORD;
    v_user_name TEXT;
    v_user_role TEXT;
    v_recipient_count INT := 0;
BEGIN
    SELECT * INTO v_notice
    FROM public.notices
    WHERE id = p_notice_id AND (school_id = p_school_id OR school_id IS NULL) AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Notice not found');
    END IF;

    SELECT full_name, COALESCE(role, 'staff') INTO v_user_name, v_user_role
    FROM public.profiles WHERE id = p_user_id;

    UPDATE public.notices
    SET 
        title = COALESCE(p_payload->>'title', title),
        content = COALESCE(p_payload->>'content', content),
        category = COALESCE(p_payload->>'category', category),
        priority = COALESCE(p_payload->>'priority', priority),
        status = COALESCE(p_payload->>'status', status),
        target_scope = COALESCE(p_payload->>'target_scope', target_scope),
        target_roles = COALESCE(p_payload->'target_roles', target_roles),
        target_classes = COALESCE(p_payload->'target_classes', target_classes),
        target_departments = COALESCE(p_payload->'target_departments', target_departments),
        target_user_ids = COALESCE(p_payload->'target_user_ids', target_user_ids),
        timezone = COALESCE(p_payload->>'timezone', timezone),
        published_at = CASE 
            WHEN (p_payload->>'status') = 'published' AND published_at IS NULL THEN NOW() 
            ELSE COALESCE((p_payload->>'published_at')::TIMESTAMPTZ, published_at) 
        END,
        scheduled_at = (p_payload->>'scheduled_at')::TIMESTAMPTZ,
        expires_at = (p_payload->>'expires_at')::TIMESTAMPTZ,
        requires_acknowledgement = COALESCE((p_payload->>'requires_acknowledgement')::BOOLEAN, requires_acknowledgement),
        acknowledgement_deadline = (p_payload->>'acknowledgement_deadline')::TIMESTAMPTZ,
        notification_channels = COALESCE(p_payload->'notification_channels', notification_channels),
        attachments = COALESCE(p_payload->'attachments', attachments),
        links = COALESCE(p_payload->'links', links),
        is_pinned = COALESCE((p_payload->>'is_pinned')::BOOLEAN, is_pinned),
        is_urgent = COALESCE((p_payload->>'is_urgent')::BOOLEAN, is_urgent),
        updated_at = NOW()
    WHERE id = p_notice_id;

    -- Re-sync recipients if audience was updated
    DELETE FROM public.notice_recipients
    WHERE notice_id = p_notice_id
      AND user_id NOT IN (
          SELECT p.id
          FROM public.profiles p
          WHERE (p.school_id = p_school_id OR p_school_id IS NULL)
            AND (
                (COALESCE(p_payload->>'target_scope', v_notice.target_scope) = 'entire_institute' 
                    AND (COALESCE(p_payload->'target_roles', v_notice.target_roles) IS NULL OR jsonb_array_length(COALESCE(p_payload->'target_roles', v_notice.target_roles)) = 0)
                    AND (COALESCE(p_payload->'target_classes', v_notice.target_classes) IS NULL OR jsonb_array_length(COALESCE(p_payload->'target_classes', v_notice.target_classes)) = 0)
                    AND (COALESCE(p_payload->'target_user_ids', v_notice.target_user_ids) IS NULL OR jsonb_array_length(COALESCE(p_payload->'target_user_ids', v_notice.target_user_ids)) = 0)
                    AND (COALESCE(p_payload->'target_departments', v_notice.target_departments) IS NULL OR jsonb_array_length(COALESCE(p_payload->'target_departments', v_notice.target_departments)) = 0)
                )
                OR (COALESCE(p_payload->'target_roles', v_notice.target_roles) IS NOT NULL AND jsonb_array_length(COALESCE(p_payload->'target_roles', v_notice.target_roles)) > 0 AND COALESCE(p_payload->'target_roles', v_notice.target_roles) ? lower(p.role))
                OR (COALESCE(p_payload->'target_classes', v_notice.target_classes) IS NOT NULL AND jsonb_array_length(COALESCE(p_payload->'target_classes', v_notice.target_classes)) > 0 AND p.class IS NOT NULL AND p.class != '' AND EXISTS (
                    SELECT 1 FROM jsonb_array_elements_text(COALESCE(p_payload->'target_classes', v_notice.target_classes)) tc
                    WHERE tc ILIKE p.class OR p.class ILIKE tc
                       OR replace(replace(replace(replace(lower(tc), 'class', ''), 'grade', ''), ' ', ''), '-', '') = replace(replace(replace(replace(lower(p.class), 'class', ''), 'grade', ''), ' ', ''), '-', '')
                       OR replace(replace(replace(replace(replace(replace(lower(tc), 'class', ''), 'grade', ''), ' ', ''), '-', ''), 'x', '10'), 'ix', '9') = replace(replace(replace(replace(replace(replace(lower(p.class), 'class', ''), 'grade', ''), ' ', ''), '-', ''), 'x', '10'), 'ix', '9')
                ))
                OR (COALESCE(p_payload->'target_departments', v_notice.target_departments) IS NOT NULL AND jsonb_array_length(COALESCE(p_payload->'target_departments', v_notice.target_departments)) > 0 AND p.department IS NOT NULL AND COALESCE(p_payload->'target_departments', v_notice.target_departments) ? p.department)
                OR (COALESCE(p_payload->'target_user_ids', v_notice.target_user_ids) IS NOT NULL AND jsonb_array_length(COALESCE(p_payload->'target_user_ids', v_notice.target_user_ids)) > 0 AND COALESCE(p_payload->'target_user_ids', v_notice.target_user_ids) ? (p.id::text))
            )
      );

    INSERT INTO public.notice_recipients (
        school_id,
        notice_id,
        user_id,
        recipient_type,
        recipient_role,
        recipient_class,
        delivery_status,
        created_at
    )
    SELECT DISTINCT
        p_school_id,
        p_notice_id,
        p.id,
        CASE 
            WHEN COALESCE(p_payload->>'target_scope', v_notice.target_scope) = 'entire_institute' THEN 'entire_institute'
            WHEN COALESCE(p_payload->'target_roles', v_notice.target_roles) ? lower(p.role) THEN 'role'
            WHEN COALESCE(p_payload->'target_classes', v_notice.target_classes) ? p.class THEN 'class'
            WHEN COALESCE(p_payload->'target_user_ids', v_notice.target_user_ids) ? (p.id::text) THEN 'individual'
            ELSE 'general'
        END,
        p.role,
        p.class,
        'sent',
        NOW()
    FROM public.profiles p
    WHERE (p.school_id = p_school_id OR p_school_id IS NULL)
      AND (
          (COALESCE(p_payload->>'target_scope', v_notice.target_scope) = 'entire_institute' 
              AND (COALESCE(p_payload->'target_roles', v_notice.target_roles) IS NULL OR jsonb_array_length(COALESCE(p_payload->'target_roles', v_notice.target_roles)) = 0)
              AND (COALESCE(p_payload->'target_classes', v_notice.target_classes) IS NULL OR jsonb_array_length(COALESCE(p_payload->'target_classes', v_notice.target_classes)) = 0)
              AND (COALESCE(p_payload->'target_user_ids', v_notice.target_user_ids) IS NULL OR jsonb_array_length(COALESCE(p_payload->'target_user_ids', v_notice.target_user_ids)) = 0)
              AND (COALESCE(p_payload->'target_departments', v_notice.target_departments) IS NULL OR jsonb_array_length(COALESCE(p_payload->'target_departments', v_notice.target_departments)) = 0)
          )
          OR (COALESCE(p_payload->'target_roles', v_notice.target_roles) IS NOT NULL AND jsonb_array_length(COALESCE(p_payload->'target_roles', v_notice.target_roles)) > 0 AND COALESCE(p_payload->'target_roles', v_notice.target_roles) ? lower(p.role))
          OR (COALESCE(p_payload->'target_classes', v_notice.target_classes) IS NOT NULL AND jsonb_array_length(COALESCE(p_payload->'target_classes', v_notice.target_classes)) > 0 AND p.class IS NOT NULL AND p.class != '' AND EXISTS (
              SELECT 1 FROM jsonb_array_elements_text(COALESCE(p_payload->'target_classes', v_notice.target_classes)) tc
              WHERE tc ILIKE p.class OR p.class ILIKE tc
                 OR replace(replace(replace(replace(lower(tc), 'class', ''), 'grade', ''), ' ', ''), '-', '') = replace(replace(replace(replace(lower(p.class), 'class', ''), 'grade', ''), ' ', ''), '-', '')
                 OR replace(replace(replace(replace(replace(replace(lower(tc), 'class', ''), 'grade', ''), ' ', ''), '-', ''), 'x', '10'), 'ix', '9') = replace(replace(replace(replace(replace(replace(lower(p.class), 'class', ''), 'grade', ''), ' ', ''), '-', ''), 'x', '10'), 'ix', '9')
          ))
          OR (COALESCE(p_payload->'target_departments', v_notice.target_departments) IS NOT NULL AND jsonb_array_length(COALESCE(p_payload->'target_departments', v_notice.target_departments)) > 0 AND p.department IS NOT NULL AND COALESCE(p_payload->'target_departments', v_notice.target_departments) ? p.department)
          OR (COALESCE(p_payload->'target_user_ids', v_notice.target_user_ids) IS NOT NULL AND jsonb_array_length(COALESCE(p_payload->'target_user_ids', v_notice.target_user_ids)) > 0 AND COALESCE(p_payload->'target_user_ids', v_notice.target_user_ids) ? (p.id::text))
      )
    ON CONFLICT (notice_id, user_id) DO NOTHING;

    UPDATE public.notices
    SET recipient_count = (SELECT COUNT(*) FROM public.notice_recipients WHERE notice_id = p_notice_id)
    WHERE id = p_notice_id;

    -- Audit log
    INSERT INTO public.notice_audit_logs (
        school_id, notice_id, user_id, user_name, user_role, action, details
    ) VALUES (
        p_school_id, p_notice_id, p_user_id, v_user_name, v_user_role, 'updated', p_payload
    );

    RETURN jsonb_build_object('success', TRUE, 'notice_id', p_notice_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ----------------------------------------------------------------------------
-- 6. fn_acknowledge_notice: Recipient acknowledgement submission
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_acknowledge_notice(
    p_school_id UUID,
    p_notice_id UUID,
    p_user_id UUID,
    p_status TEXT DEFAULT 'acknowledged',
    p_decline_reason TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_user_name TEXT;
    v_user_role TEXT;
    v_total_acks INT := 0;
BEGIN
    SELECT full_name, COALESCE(role, 'student')
    INTO v_user_name, v_user_role
    FROM public.profiles
    WHERE id = p_user_id;

    -- Upsert recipient record
    INSERT INTO public.notice_recipients (
        school_id,
        notice_id,
        user_id,
        is_read,
        read_at,
        is_acknowledged,
        acknowledged_at,
        acknowledgement_status,
        decline_reason,
        updated_at
    ) VALUES (
        p_school_id,
        p_notice_id,
        p_user_id,
        TRUE,
        NOW(),
        (p_status = 'acknowledged'),
        NOW(),
        p_status,
        p_decline_reason,
        NOW()
    )
    ON CONFLICT (notice_id, user_id) DO UPDATE SET
        is_read = TRUE,
        read_at = COALESCE(notice_recipients.read_at, NOW()),
        is_acknowledged = (p_status = 'acknowledged'),
        acknowledged_at = NOW(),
        acknowledgement_status = p_status,
        decline_reason = p_decline_reason,
        updated_at = NOW();

    -- Count total acknowledgements
    SELECT COUNT(*) INTO v_total_acks
    FROM public.notice_recipients
    WHERE notice_id = p_notice_id AND is_acknowledged = TRUE;

    UPDATE public.notices
    SET ack_count = v_total_acks
    WHERE id = p_notice_id;

    -- Audit log
    INSERT INTO public.notice_audit_logs (
        school_id, notice_id, user_id, user_name, user_role, action, details
    ) VALUES (
        p_school_id, p_notice_id, p_user_id, v_user_name, v_user_role, 'acknowledged',
        jsonb_build_object('status', p_status, 'decline_reason', p_decline_reason)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'notice_id', p_notice_id,
        'acknowledgement_status', p_status,
        'total_acknowledgements', v_total_acks
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ----------------------------------------------------------------------------
-- 7. fn_approve_reject_notice: Multi-role approval workflow
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_approve_reject_notice(
    p_school_id UUID,
    p_notice_id UUID,
    p_approver_id UUID,
    p_action TEXT, -- 'approve', 'reject', 'request_changes'
    p_reason TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_approver_name TEXT;
    v_approver_role TEXT;
    v_new_status TEXT;
    v_new_approval_status TEXT;
BEGIN
    SELECT full_name, COALESCE(role, 'principal')
    INTO v_approver_name, v_approver_role
    FROM public.profiles
    WHERE id = p_approver_id;

    IF p_action = 'approve' THEN
        v_new_status := 'published';
        v_new_approval_status := 'approved';
    ELSIF p_action = 'reject' THEN
        IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Rejection reason is mandatory');
        END IF;
        v_new_status := 'rejected';
        v_new_approval_status := 'rejected';
    ELSIF p_action = 'request_changes' THEN
        IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
            RETURN jsonb_build_object('success', FALSE, 'error', 'Comment/reason for changes is mandatory');
        END IF;
        v_new_status := 'draft';
        v_new_approval_status := 'changes_requested';
    ELSE
        RETURN jsonb_build_object('success', FALSE, 'error', 'Invalid approval action');
    END IF;

    UPDATE public.notices
    SET 
        status = v_new_status,
        approval_status = v_new_approval_status,
        approved_by = p_approver_id,
        approved_at = NOW(),
        rejection_reason = p_reason,
        published_at = CASE WHEN v_new_status = 'published' AND published_at IS NULL THEN NOW() ELSE published_at END,
        updated_at = NOW()
    WHERE id = p_notice_id AND (school_id = p_school_id OR school_id IS NULL);

    -- Log audit record
    INSERT INTO public.notice_audit_logs (
        school_id, notice_id, user_id, user_name, user_role, action, details
    ) VALUES (
        p_school_id, p_notice_id, p_approver_id, v_approver_name, v_approver_role, p_action,
        jsonb_build_object('status', v_new_status, 'approval_status', v_new_approval_status, 'reason', p_reason)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'notice_id', p_notice_id,
        'status', v_new_status,
        'approval_status', v_new_approval_status
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ----------------------------------------------------------------------------
-- 8. fn_bulk_notice_action: Atomic bulk operations (archive, delete, publish, read)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_bulk_notice_action(
    p_school_id UUID,
    p_user_id UUID,
    p_notice_ids UUID[],
    p_action TEXT -- 'archive', 'delete', 'restore', 'publish', 'mark_read'
) RETURNS JSONB AS $$
DECLARE
    v_user_name TEXT;
    v_user_role TEXT;
    v_affected INT := 0;
BEGIN
    SELECT full_name, COALESCE(role, 'admin')
    INTO v_user_name, v_user_role
    FROM public.profiles
    WHERE id = p_user_id;

    IF p_action = 'archive' THEN
        UPDATE public.notices
        SET status = 'archived', updated_at = NOW()
        WHERE id = ANY(p_notice_ids) AND (school_id = p_school_id OR school_id IS NULL);
        GET DIAGNOSTICS v_affected = ROW_COUNT;

    ELSIF p_action = 'delete' THEN
        UPDATE public.notices
        SET deleted_at = NOW(), updated_at = NOW()
        WHERE id = ANY(p_notice_ids) AND (school_id = p_school_id OR school_id IS NULL);
        GET DIAGNOSTICS v_affected = ROW_COUNT;

    ELSIF p_action = 'restore' THEN
        UPDATE public.notices
        SET deleted_at = NULL, status = 'draft', updated_at = NOW()
        WHERE id = ANY(p_notice_ids) AND (school_id = p_school_id OR school_id IS NULL);
        GET DIAGNOSTICS v_affected = ROW_COUNT;

    ELSIF p_action = 'publish' THEN
        UPDATE public.notices
        SET status = 'published', published_at = COALESCE(published_at, NOW()), updated_at = NOW()
        WHERE id = ANY(p_notice_ids) AND (school_id = p_school_id OR school_id IS NULL);
        GET DIAGNOSTICS v_affected = ROW_COUNT;

    ELSIF p_action = 'mark_read' THEN
        INSERT INTO public.notice_recipients (school_id, notice_id, user_id, is_read, read_at)
        SELECT p_school_id, n_id, p_user_id, TRUE, NOW()
        FROM unnest(p_notice_ids) AS n_id
        ON CONFLICT (notice_id, user_id) DO UPDATE SET
            is_read = TRUE,
            read_at = COALESCE(notice_recipients.read_at, NOW()),
            updated_at = NOW();
        GET DIAGNOSTICS v_affected = ROW_COUNT;
    END IF;

    -- Audit log
    INSERT INTO public.notice_audit_logs (
        school_id, notice_id, user_id, user_name, user_role, action, details
    )
    SELECT p_school_id, n_id, p_user_id, v_user_name, v_user_role, 'bulk_' || p_action, jsonb_build_object('affected', v_affected)
    FROM unnest(p_notice_ids) AS n_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'action', p_action,
        'affected_count', v_affected
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ----------------------------------------------------------------------------
-- 9. fn_get_notice_acknowledgements: Recipient acknowledgement table
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_get_notice_acknowledgements(
    p_school_id UUID,
    p_notice_id UUID,
    p_search TEXT DEFAULT '',
    p_status TEXT DEFAULT '', -- 'acknowledged', 'pending', 'declined'
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 20
) RETURNS JSONB AS $$
DECLARE
    v_total_recipients INT := 0;
    v_total_acknowledged INT := 0;
    v_total_pending INT := 0;
    v_total_declined INT := 0;
    v_offset INT := 0;
    v_recipients_json JSONB;
    v_result JSONB;
BEGIN
    v_offset := GREATEST(0, (p_page - 1) * p_page_size);

    -- Counters
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE nr.acknowledgement_status = 'acknowledged'),
        COUNT(*) FILTER (WHERE nr.acknowledgement_status = 'pending'),
        COUNT(*) FILTER (WHERE nr.acknowledgement_status = 'declined')
    INTO 
        v_total_recipients,
        v_total_acknowledged,
        v_total_pending,
        v_total_declined
    FROM public.notice_recipients nr
    WHERE nr.notice_id = p_notice_id AND (nr.school_id = p_school_id OR nr.school_id IS NULL);

    -- Recipients table query
    SELECT jsonb_agg(sub.item)
    INTO v_recipients_json
    FROM (
        SELECT jsonb_build_object(
            'id', nr.id,
            'user_id', nr.user_id,
            'full_name', p.full_name,
            'role', p.role,
            'class', p.class,
            'department', p.department,
            'avatar_url', p.avatar_url,
            'phone', p.phone,
            'delivery_status', nr.delivery_status,
            'is_read', nr.is_read,
            'read_at', nr.read_at,
            'is_acknowledged', nr.is_acknowledged,
            'acknowledged_at', nr.acknowledged_at,
            'acknowledgement_status', nr.acknowledgement_status,
            'decline_reason', nr.decline_reason
        ) AS item
        FROM public.notice_recipients nr
        LEFT JOIN public.profiles p ON p.id = nr.user_id
        WHERE nr.notice_id = p_notice_id 
          AND (nr.school_id = p_school_id OR nr.school_id IS NULL)
          AND (
              p_search = '' 
              OR p.full_name ILIKE '%' || p_search || '%'
              OR p.role ILIKE '%' || p_search || '%'
              OR p.class ILIKE '%' || p_search || '%'
          )
          AND (p_status = '' OR p_status = 'All' OR nr.acknowledgement_status ILIKE p_status)
        ORDER BY 
            CASE WHEN nr.acknowledgement_status = 'acknowledged' THEN 1 ELSE 0 END,
            p.full_name ASC
        LIMIT p_page_size
        OFFSET v_offset
    ) sub;

    IF v_recipients_json IS NULL THEN
        v_recipients_json := '[]'::jsonb;
    END IF;

    v_result := jsonb_build_object(
        'success', TRUE,
        'summary', jsonb_build_object(
            'total_recipients', v_total_recipients,
            'acknowledged', v_total_acknowledged,
            'pending', v_total_pending,
            'declined', v_total_declined,
            'acknowledgement_pct', CASE WHEN v_total_recipients > 0 
                                        THEN ROUND((v_total_acknowledged::NUMERIC / v_total_recipients * 100), 1)
                                        ELSE 0 END
        ),
        'page', p_page,
        'page_size', p_page_size,
        'data', v_recipients_json
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
