-- ============================================================================
-- Migration 478: Enterprise Collaborative Whiteboard System
-- Extends public.live_class_whiteboards and creates multi-page, object,
-- operation-based CRDT/revision sync, snapshot, version history, permission,
-- asset, share, export, and audit trail infrastructure + stored procedures.
-- ============================================================================

BEGIN;

-- 1. ENHANCE EXISTING live_class_whiteboards TABLE (No duplicate table)
ALTER TABLE public.live_class_whiteboards
    DROP CONSTRAINT IF EXISTS live_class_whiteboards_session_id_key;

ALTER TABLE public.live_class_whiteboards
    ALTER COLUMN session_id DROP NOT NULL;

ALTER TABLE public.live_class_whiteboards
    ADD COLUMN IF NOT EXISTS title VARCHAR(255) NOT NULL DEFAULT 'Interactive Class Whiteboard',
    ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS owner_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE',
    ADD COLUMN IF NOT EXISTS current_revision BIGINT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS collaboration_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS presentation_mode BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS default_permissions JSONB NOT NULL DEFAULT '{"students_can_draw": false, "students_can_add_notes": true, "students_can_annotate": false, "follow_teacher_page": true}'::jsonb,
    ADD COLUMN IF NOT EXISTS template_type VARCHAR(100) DEFAULT 'blank',
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_lc_whiteboards_school_session
    ON public.live_class_whiteboards(school_id, session_id)
    WHERE deleted_at IS NULL;

-- 2. MULTI-PAGE WHITEBOARD PAGES
CREATE TABLE IF NOT EXISTS public.whiteboard_pages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    whiteboard_id UUID NOT NULL REFERENCES public.live_class_whiteboards(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL DEFAULT 'Page 1',
    page_order INTEGER NOT NULL DEFAULT 1,
    background_type VARCHAR(50) NOT NULL DEFAULT 'plain',
    background_config JSONB NOT NULL DEFAULT '{}'::jsonb,
    canvas_config JSONB NOT NULL DEFAULT '{"width": 2400, "height": 1600}'::jsonb,
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_wb_pages_board_order
    ON public.whiteboard_pages(whiteboard_id, page_order)
    WHERE deleted_at IS NULL;

-- 3. WHITEBOARD OBJECTS (Editable structured items per page)
CREATE TABLE IF NOT EXISTS public.whiteboard_objects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    whiteboard_id UUID NOT NULL REFERENCES public.live_class_whiteboards(id) ON DELETE CASCADE,
    page_id UUID NOT NULL REFERENCES public.whiteboard_pages(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    object_id VARCHAR(120) NOT NULL,
    object_type VARCHAR(60) NOT NULL,
    object_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    z_index INTEGER NOT NULL DEFAULT 0,
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_wb_page_object UNIQUE (page_id, object_id)
);

CREATE INDEX IF NOT EXISTS idx_wb_objects_page_active
    ON public.whiteboard_objects(page_id, z_index)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_wb_objects_board
    ON public.whiteboard_objects(whiteboard_id, updated_at);

-- 4. WHITEBOARD OPERATIONS (Ordered, idempotent sync log)
CREATE TABLE IF NOT EXISTS public.whiteboard_operations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    whiteboard_id UUID NOT NULL REFERENCES public.live_class_whiteboards(id) ON DELETE CASCADE,
    page_id UUID REFERENCES public.whiteboard_pages(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    operation_id UUID NOT NULL,
    revision BIGINT NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    operation_type VARCHAR(60) NOT NULL,
    object_id VARCHAR(120),
    operation_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_wb_operation UNIQUE (whiteboard_id, operation_id)
);

CREATE INDEX IF NOT EXISTS idx_wb_ops_board_rev
    ON public.whiteboard_operations(whiteboard_id, revision ASC);

-- 5. WHITEBOARD SNAPSHOTS
CREATE TABLE IF NOT EXISTS public.whiteboard_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    whiteboard_id UUID NOT NULL REFERENCES public.live_class_whiteboards(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    revision BIGINT NOT NULL,
    snapshot_data JSONB NOT NULL,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wb_snapshots_board_rev
    ON public.whiteboard_snapshots(whiteboard_id, revision DESC);

-- 6. WHITEBOARD PERMISSIONS (User or role scoped, plus student assignment areas)
CREATE TABLE IF NOT EXISTS public.whiteboard_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    whiteboard_id UUID NOT NULL REFERENCES public.live_class_whiteboards(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    role_ref VARCHAR(50),
    permission_type VARCHAR(50) NOT NULL DEFAULT 'VIEW',
    assigned_area JSONB,
    granted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_wb_perm_user
    ON public.whiteboard_permissions(whiteboard_id, user_id)
    WHERE user_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_wb_perm_role
    ON public.whiteboard_permissions(whiteboard_id, role_ref)
    WHERE role_ref IS NOT NULL AND user_id IS NULL;

-- 7. WHITEBOARD ASSETS (Object storage references - never stores binary blobs in PG)
CREATE TABLE IF NOT EXISTS public.whiteboard_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    whiteboard_id UUID NOT NULL REFERENCES public.live_class_whiteboards(id) ON DELETE CASCADE,
    page_id UUID REFERENCES public.whiteboard_pages(id) ON DELETE SET NULL,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    uploaded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    storage_key TEXT NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    mime_type VARCHAR(120) NOT NULL,
    file_size BIGINT NOT NULL DEFAULT 0,
    width INTEGER,
    height INTEGER,
    page_count INTEGER DEFAULT 1,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_wb_assets_board
    ON public.whiteboard_assets(whiteboard_id)
    WHERE deleted_at IS NULL;

-- 8. WHITEBOARD VERSION HISTORY & CHECKPOINTS
CREATE TABLE IF NOT EXISTS public.whiteboard_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    whiteboard_id UUID NOT NULL REFERENCES public.live_class_whiteboards(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    revision BIGINT NOT NULL,
    version_name VARCHAR(255) NOT NULL,
    is_checkpoint BOOLEAN NOT NULL DEFAULT FALSE,
    snapshot_id UUID NOT NULL REFERENCES public.whiteboard_snapshots(id) ON DELETE CASCADE,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_by_name VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wb_versions_board
    ON public.whiteboard_versions(whiteboard_id, created_at DESC);

-- 9. WHITEBOARD SHARES
CREATE TABLE IF NOT EXISTS public.whiteboard_shares (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    whiteboard_id UUID NOT NULL REFERENCES public.live_class_whiteboards(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    share_type VARCHAR(50) NOT NULL,
    target_id UUID,
    target_label VARCHAR(255),
    access_level VARCHAR(50) NOT NULL DEFAULT 'VIEW',
    share_token VARCHAR(120) UNIQUE,
    expires_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    shared_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wb_shares_board
    ON public.whiteboard_shares(whiteboard_id)
    WHERE revoked_at IS NULL;

-- 10. WHITEBOARD EXPORTS
CREATE TABLE IF NOT EXISTS public.whiteboard_exports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    whiteboard_id UUID NOT NULL REFERENCES public.live_class_whiteboards(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    requested_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    export_format VARCHAR(20) NOT NULL,
    scope VARCHAR(30) NOT NULL DEFAULT 'all_pages',
    storage_key TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'READY',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. WHITEBOARD AUDIT LOGS
CREATE TABLE IF NOT EXISTS public.whiteboard_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    whiteboard_id UUID NOT NULL REFERENCES public.live_class_whiteboards(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    user_name VARCHAR(255),
    action VARCHAR(100) NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wb_audit_board_time
    ON public.whiteboard_audit_logs(whiteboard_id, created_at DESC);

-- Enable RLS
ALTER TABLE public.whiteboard_pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whiteboard_objects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whiteboard_operations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whiteboard_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whiteboard_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whiteboard_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whiteboard_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whiteboard_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whiteboard_exports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whiteboard_audit_logs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'wb_pages_all') THEN
        CREATE POLICY wb_pages_all ON public.whiteboard_pages FOR ALL TO authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'wb_objects_all') THEN
        CREATE POLICY wb_objects_all ON public.whiteboard_objects FOR ALL TO authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'wb_ops_all') THEN
        CREATE POLICY wb_ops_all ON public.whiteboard_operations FOR ALL TO authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'wb_snaps_all') THEN
        CREATE POLICY wb_snaps_all ON public.whiteboard_snapshots FOR ALL TO authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'wb_perms_all') THEN
        CREATE POLICY wb_perms_all ON public.whiteboard_permissions FOR ALL TO authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'wb_assets_all') THEN
        CREATE POLICY wb_assets_all ON public.whiteboard_assets FOR ALL TO authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'wb_versions_all') THEN
        CREATE POLICY wb_versions_all ON public.whiteboard_versions FOR ALL TO authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'wb_shares_all') THEN
        CREATE POLICY wb_shares_all ON public.whiteboard_shares FOR ALL TO authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'wb_exports_all') THEN
        CREATE POLICY wb_exports_all ON public.whiteboard_exports FOR ALL TO authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'wb_audit_all') THEN
        CREATE POLICY wb_audit_all ON public.whiteboard_audit_logs FOR ALL TO authenticated USING (true);
    END IF;
END $$;

-- ============================================================================
-- STORED PROCEDURES & FUNCTIONS FOR COLLABORATIVE WHITEBOARD ENGINE
-- ============================================================================

-- Helper: Log audit entry
CREATE OR REPLACE FUNCTION public.sp_log_whiteboard_audit(
    p_whiteboard_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_action TEXT,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_name TEXT;
BEGIN
    SELECT full_name INTO v_user_name FROM public.profiles WHERE id = p_user_id LIMIT 1;
    INSERT INTO public.whiteboard_audit_logs (
        whiteboard_id, school_id, user_id, user_name, action, metadata
    ) VALUES (
        p_whiteboard_id, p_school_id, p_user_id, COALESCE(v_user_name, 'System'), p_action, COALESCE(p_metadata, '{}'::jsonb)
    );
END;
$$;

-- Helper: Check effective permission on a whiteboard
CREATE OR REPLACE FUNCTION public.sp_get_whiteboard_user_permission(
    p_whiteboard_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_user_role TEXT DEFAULT 'student'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_wb RECORD;
    v_perm RECORD;
    v_role_lower TEXT := LOWER(COALESCE(p_user_role, 'student'));
    v_effective TEXT := 'VIEW';
    v_assigned_area JSONB := NULL;
BEGIN
    SELECT id, school_id, owner_user_id, created_by, teacher_only_mode, collaboration_enabled, default_permissions
    INTO v_wb
    FROM public.live_class_whiteboards
    WHERE id = p_whiteboard_id AND school_id = p_school_id AND deleted_at IS NULL
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('allowed', FALSE, 'permission', 'NONE', 'reason', 'Whiteboard not found');
    END IF;

    -- Owner / Creator / Admin / Teacher / Superadmin have full OWNER/EDIT control
    IF v_wb.owner_user_id = p_user_id OR v_wb.created_by = p_user_id
       OR v_role_lower IN ('superadmin', 'admin', 'principal', 'teacher', 'co_teacher', 'faculty') THEN
        RETURN jsonb_build_object(
            'allowed', TRUE,
            'permission', 'OWNER',
            'can_edit', TRUE,
            'can_manage_pages', TRUE,
            'can_manage_permissions', v_role_lower NOT IN ('co_teacher'),
            'can_export', TRUE,
            'assigned_area', NULL
        );
    END IF;

    -- Check user-specific override
    SELECT permission_type, assigned_area INTO v_perm
    FROM public.whiteboard_permissions
    WHERE whiteboard_id = p_whiteboard_id AND user_id = p_user_id
    LIMIT 1;

    IF FOUND THEN
        v_effective := v_perm.permission_type;
        v_assigned_area := v_perm.assigned_area;
    ELSE
        -- Check role override
        SELECT permission_type, assigned_area INTO v_perm
        FROM public.whiteboard_permissions
        WHERE whiteboard_id = p_whiteboard_id AND LOWER(COALESCE(role_ref, '')) = v_role_lower
        LIMIT 1;

        IF FOUND THEN
            v_effective := v_perm.permission_type;
            v_assigned_area := v_perm.assigned_area;
        ELSIF COALESCE(v_wb.collaboration_enabled, FALSE) = TRUE
              AND COALESCE(v_wb.teacher_only_mode, TRUE) = FALSE
              AND COALESCE((v_wb.default_permissions->>'students_can_draw')::BOOLEAN, FALSE) = TRUE THEN
            v_effective := 'EDIT';
        ELSIF COALESCE(v_wb.collaboration_enabled, FALSE) = TRUE
              AND COALESCE((v_wb.default_permissions->>'students_can_annotate')::BOOLEAN, FALSE) = TRUE THEN
            v_effective := 'ANNOTATE';
        ELSE
            v_effective := 'VIEW';
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'allowed', v_effective <> 'NONE',
        'permission', v_effective,
        'can_edit', v_effective IN ('OWNER', 'EDIT', 'ANNOTATE', 'ASSIGNED_AREA'),
        'can_manage_pages', v_effective IN ('OWNER'),
        'can_manage_permissions', v_effective = 'OWNER',
        'can_export', v_effective <> 'NONE',
        'assigned_area', v_assigned_area
    );
END;
$$;

-- 1. List whiteboards for a school / session
CREATE OR REPLACE FUNCTION public.sp_list_whiteboards(
    p_school_id UUID,
    p_session_id UUID DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_items JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', wb.id,
            'session_id', wb.session_id,
            'school_id', wb.school_id,
            'title', COALESCE(wb.title, 'Class Whiteboard'),
            'description', COALESCE(wb.description, ''),
            'status', COALESCE(wb.status, 'ACTIVE'),
            'current_revision', COALESCE(wb.current_revision, 1),
            'teacher_only_mode', COALESCE(wb.teacher_only_mode, TRUE),
            'collaboration_enabled', COALESCE(wb.collaboration_enabled, TRUE),
            'presentation_mode', COALESCE(wb.presentation_mode, FALSE),
            'template_type', COALESCE(wb.template_type, 'blank'),
            'page_count', (SELECT COUNT(*) FROM public.whiteboard_pages wp WHERE wp.whiteboard_id = wb.id AND wp.deleted_at IS NULL),
            'object_count', (SELECT COUNT(*) FROM public.whiteboard_objects wo WHERE wo.whiteboard_id = wb.id AND wo.deleted_at IS NULL),
            'updated_at', wb.updated_at,
            'created_at', wb.created_at
        ) ORDER BY wb.updated_at DESC
    ), '[]'::jsonb) INTO v_items
    FROM public.live_class_whiteboards wb
    WHERE wb.school_id = p_school_id
      AND wb.deleted_at IS NULL
      AND (p_session_id IS NULL OR wb.session_id = p_session_id);

    RETURN v_items;
END;
$$;

-- 2. Create Whiteboard + Initial Pages
CREATE OR REPLACE FUNCTION public.sp_create_whiteboard(
    p_school_id UUID,
    p_session_id UUID,
    p_user_id UUID,
    p_title TEXT,
    p_template_type TEXT DEFAULT 'blank',
    p_collaboration_enabled BOOLEAN DEFAULT TRUE,
    p_description TEXT DEFAULT ''
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_wb_id UUID := gen_random_uuid();
    v_page_id UUID := gen_random_uuid();
    v_snap_id UUID := gen_random_uuid();
    v_bg_type TEXT := 'plain';
    v_page_title TEXT := 'Page 1';
    v_user_name TEXT;
BEGIN
    SELECT full_name INTO v_user_name FROM public.profiles WHERE id = p_user_id LIMIT 1;

    IF p_template_type IN ('graph', 'graph_paper') THEN
        v_bg_type := 'graph';
        v_page_title := '1. Graph Sheet';
    ELSIF p_template_type = 'engineering' THEN
        v_bg_type := 'engineering';
        v_page_title := '1. Engineering Diagram';
    ELSIF p_template_type IN ('math', 'mathematics') THEN
        v_bg_type := 'light_grid';
        v_page_title := '1. Concept & Equations';
    ELSIF p_template_type = 'music' THEN
        v_bg_type := 'music';
        v_page_title := '1. Music Staff';
    END IF;

    INSERT INTO public.live_class_whiteboards (
        id, session_id, school_id, title, description,
        created_by, owner_user_id, last_saved_by, status,
        current_revision, teacher_only_mode, collaboration_enabled,
        template_type, canvas_data, created_at, updated_at
    ) VALUES (
        v_wb_id, p_session_id, p_school_id,
        COALESCE(NULLIF(TRIM(p_title), ''), 'New Class Whiteboard'),
        COALESCE(p_description, ''),
        p_user_id, p_user_id, p_user_id, 'ACTIVE',
        1, NOT COALESCE(p_collaboration_enabled, TRUE), COALESCE(p_collaboration_enabled, TRUE),
        COALESCE(p_template_type, 'blank'),
        '{"version": 2}'::jsonb, NOW(), NOW()
    );

    INSERT INTO public.whiteboard_pages (
        id, whiteboard_id, school_id, title, page_order, background_type, created_by
    ) VALUES (
        v_page_id, v_wb_id, p_school_id, v_page_title, 1, v_bg_type, p_user_id
    );

    INSERT INTO public.whiteboard_snapshots (
        id, whiteboard_id, school_id, revision, snapshot_data, created_by
    ) VALUES (
        v_snap_id, v_wb_id, p_school_id, 1,
        jsonb_build_object(
            'pages', jsonb_build_array(
                jsonb_build_object('id', v_page_id, 'title', v_page_title, 'page_order', 1, 'background_type', v_bg_type, 'objects', '[]'::jsonb)
            )
        ),
        p_user_id
    );

    INSERT INTO public.whiteboard_versions (
        whiteboard_id, school_id, revision, version_name, is_checkpoint, snapshot_id, created_by, created_by_name
    ) VALUES (
        v_wb_id, p_school_id, 1, 'Initial Board Created', TRUE, v_snap_id, p_user_id, COALESCE(v_user_name, 'Teacher')
    );

    PERFORM public.sp_log_whiteboard_audit(v_wb_id, p_school_id, p_user_id, 'whiteboard.created', jsonb_build_object('title', p_title, 'template', p_template_type));

    RETURN public.sp_get_whiteboard_full(v_wb_id, p_school_id, p_user_id);
END;
$$;

-- 3. Get Full Whiteboard State (Pages + Active Objects + Permissions + Versions)
CREATE OR REPLACE FUNCTION public.sp_get_whiteboard_full(
    p_whiteboard_id UUID,
    p_school_id UUID,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_wb RECORD;
    v_pages JSONB;
    v_versions JSONB;
    v_permissions JSONB;
    v_user_role TEXT := 'teacher';
    v_my_perm JSONB;
BEGIN
    SELECT * INTO v_wb
    FROM public.live_class_whiteboards
    WHERE id = p_whiteboard_id AND school_id = p_school_id AND deleted_at IS NULL
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    IF p_user_id IS NOT NULL THEN
        SELECT COALESCE(role, 'student') INTO v_user_role FROM public.profiles WHERE id = p_user_id LIMIT 1;
    END IF;
    v_my_perm := public.sp_get_whiteboard_user_permission(p_whiteboard_id, p_school_id, p_user_id, v_user_role);

    -- Ensure at least 1 page exists for legacy whiteboards
    IF NOT EXISTS (SELECT 1 FROM public.whiteboard_pages WHERE whiteboard_id = p_whiteboard_id AND deleted_at IS NULL) THEN
        INSERT INTO public.whiteboard_pages (whiteboard_id, school_id, title, page_order, background_type, created_by)
        VALUES (p_whiteboard_id, p_school_id, '1. Main Board', 1, 'plain', p_user_id);
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', wp.id,
            'whiteboard_id', wp.whiteboard_id,
            'title', wp.title,
            'page_order', wp.page_order,
            'background_type', wp.background_type,
            'background_config', wp.background_config,
            'canvas_config', wp.canvas_config,
            'is_locked', wp.is_locked,
            'created_at', wp.created_at,
            'updated_at', wp.updated_at,
            'objects', COALESCE((
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', wo.object_id,
                        'db_id', wo.id,
                        'page_id', wo.page_id,
                        'type', wo.object_type,
                        'data', wo.object_data,
                        'z_index', wo.z_index,
                        'is_locked', wo.is_locked,
                        'created_by', wo.created_by,
                        'updated_at', wo.updated_at
                    ) ORDER BY wo.z_index ASC, wo.created_at ASC
                )
                FROM public.whiteboard_objects wo
                WHERE wo.page_id = wp.id AND wo.deleted_at IS NULL
            ), '[]'::jsonb)
        ) ORDER BY wp.page_order ASC, wp.created_at ASC
    ), '[]'::jsonb) INTO v_pages
    FROM public.whiteboard_pages wp
    WHERE wp.whiteboard_id = p_whiteboard_id AND wp.deleted_at IS NULL;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', wv.id,
            'revision', wv.revision,
            'version_name', wv.version_name,
            'is_checkpoint', wv.is_checkpoint,
            'snapshot_id', wv.snapshot_id,
            'created_by', wv.created_by,
            'created_by_name', COALESCE(wv.created_by_name, 'Teacher'),
            'created_at', wv.created_at
        ) ORDER BY wv.created_at DESC
    ), '[]'::jsonb) INTO v_versions
    FROM (
        SELECT * FROM public.whiteboard_versions
        WHERE whiteboard_id = p_whiteboard_id
        ORDER BY created_at DESC LIMIT 30
    ) wv;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', wpm.id,
            'user_id', wpm.user_id,
            'user_name', pr.full_name,
            'role_ref', wpm.role_ref,
            'permission_type', wpm.permission_type,
            'assigned_area', wpm.assigned_area,
            'updated_at', wpm.updated_at
        )
    ), '[]'::jsonb) INTO v_permissions
    FROM public.whiteboard_permissions wpm
    LEFT JOIN public.profiles pr ON pr.id = wpm.user_id
    WHERE wpm.whiteboard_id = p_whiteboard_id;

    RETURN jsonb_build_object(
        'id', v_wb.id,
        'session_id', v_wb.session_id,
        'school_id', v_wb.school_id,
        'title', COALESCE(v_wb.title, 'Class Whiteboard'),
        'description', COALESCE(v_wb.description, ''),
        'status', COALESCE(v_wb.status, 'ACTIVE'),
        'current_revision', COALESCE(v_wb.current_revision, 1),
        'teacher_only_mode', COALESCE(v_wb.teacher_only_mode, TRUE),
        'collaboration_enabled', COALESCE(v_wb.collaboration_enabled, TRUE),
        'presentation_mode', COALESCE(v_wb.presentation_mode, FALSE),
        'default_permissions', COALESCE(v_wb.default_permissions, '{}'::jsonb),
        'template_type', COALESCE(v_wb.template_type, 'blank'),
        'my_permission', v_my_perm,
        'pages', v_pages,
        'versions', v_versions,
        'permissions', v_permissions,
        'created_at', v_wb.created_at,
        'updated_at', v_wb.updated_at
    );
END;
$$;

-- 4. Apply Idempotent Whiteboard Operation
CREATE OR REPLACE FUNCTION public.sp_apply_whiteboard_operation(
    p_whiteboard_id UUID,
    p_page_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_operation_id UUID,
    p_operation_type TEXT,
    p_object_id TEXT,
    p_object_type TEXT,
    p_operation_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_existing_rev BIGINT;
    v_new_rev BIGINT;
    v_obj JSONB;
BEGIN
    -- 1. Idempotency check
    SELECT revision INTO v_existing_rev
    FROM public.whiteboard_operations
    WHERE whiteboard_id = p_whiteboard_id AND operation_id = p_operation_id
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'success', TRUE,
            'duplicate', TRUE,
            'revision', v_existing_rev,
            'operation_id', p_operation_id
        );
    END IF;

    -- 2. Lock board row and bump revision atomically
    UPDATE public.live_class_whiteboards
    SET current_revision = COALESCE(current_revision, 0) + 1,
        last_saved_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_whiteboard_id AND school_id = p_school_id AND deleted_at IS NULL
    RETURNING current_revision INTO v_new_rev;

    IF v_new_rev IS NULL THEN
        RETURN jsonb_build_object('success', FALSE, 'message', 'Whiteboard not found');
    END IF;

    -- 3. Mutate whiteboard_objects based on operation_type
    IF p_operation_type IN ('object.create', 'object.update') AND p_object_id IS NOT NULL THEN
        INSERT INTO public.whiteboard_objects (
            whiteboard_id, page_id, school_id, object_id, object_type,
            object_data, z_index, is_locked, created_by, created_at, updated_at, deleted_at
        ) VALUES (
            p_whiteboard_id, p_page_id, p_school_id, p_object_id, COALESCE(p_object_type, 'stroke'),
            COALESCE(p_operation_data->'data', p_operation_data),
            COALESCE((p_operation_data->>'z_index')::INT, 0),
            COALESCE((p_operation_data->>'is_locked')::BOOLEAN, FALSE),
            p_user_id, NOW(), NOW(), NULL
        )
        ON CONFLICT (page_id, object_id) DO UPDATE SET
            object_type = COALESCE(EXCLUDED.object_type, public.whiteboard_objects.object_type),
            object_data = EXCLUDED.object_data,
            z_index = COALESCE(EXCLUDED.z_index, public.whiteboard_objects.z_index),
            is_locked = COALESCE(EXCLUDED.is_locked, public.whiteboard_objects.is_locked),
            updated_at = NOW(),
            deleted_at = NULL;

    ELSIF p_operation_type = 'objects.batch_create' AND jsonb_typeof(p_operation_data->'objects') = 'array' THEN
        FOR v_obj IN SELECT * FROM jsonb_array_elements(p_operation_data->'objects') LOOP
            INSERT INTO public.whiteboard_objects (
                whiteboard_id, page_id, school_id, object_id, object_type,
                object_data, z_index, is_locked, created_by, created_at, updated_at, deleted_at
            ) VALUES (
                p_whiteboard_id, p_page_id, p_school_id,
                v_obj->>'id', COALESCE(v_obj->>'type', 'stroke'),
                COALESCE(v_obj->'data', '{}'::jsonb),
                COALESCE((v_obj->>'z_index')::INT, 0),
                COALESCE((v_obj->>'is_locked')::BOOLEAN, FALSE),
                p_user_id, NOW(), NOW(), NULL
            )
            ON CONFLICT (page_id, object_id) DO UPDATE SET
                object_data = EXCLUDED.object_data,
                z_index = EXCLUDED.z_index,
                is_locked = EXCLUDED.is_locked,
                updated_at = NOW(),
                deleted_at = NULL;
        END LOOP;

    ELSIF p_operation_type = 'object.delete' AND p_object_id IS NOT NULL THEN
        UPDATE public.whiteboard_objects
        SET deleted_at = NOW(), updated_at = NOW()
        WHERE page_id = p_page_id AND object_id = p_object_id;

    ELSIF p_operation_type = 'objects.batch_delete' AND jsonb_typeof(p_operation_data->'object_ids') = 'array' THEN
        UPDATE public.whiteboard_objects
        SET deleted_at = NOW(), updated_at = NOW()
        WHERE page_id = p_page_id
          AND object_id IN (SELECT jsonb_array_elements_text(p_operation_data->'object_ids'));

    ELSIF p_operation_type = 'page.clear' AND p_page_id IS NOT NULL THEN
        UPDATE public.whiteboard_objects
        SET deleted_at = NOW(), updated_at = NOW()
        WHERE page_id = p_page_id AND deleted_at IS NULL;
    END IF;

    -- 4. Append operation record
    INSERT INTO public.whiteboard_operations (
        whiteboard_id, page_id, school_id, operation_id, revision,
        user_id, operation_type, object_id, operation_data
    ) VALUES (
        p_whiteboard_id, p_page_id, p_school_id, p_operation_id, v_new_rev,
        p_user_id, p_operation_type, p_object_id, p_operation_data
    );

    -- Update page updated_at
    IF p_page_id IS NOT NULL THEN
        UPDATE public.whiteboard_pages SET updated_at = NOW() WHERE id = p_page_id;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'duplicate', FALSE,
        'revision', v_new_rev,
        'operation_id', p_operation_id
    );
END;
$$;

-- 5. Page Management Stored Procedures
CREATE OR REPLACE FUNCTION public.sp_create_whiteboard_page(
    p_whiteboard_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_title TEXT DEFAULT NULL,
    p_background_type TEXT DEFAULT 'plain',
    p_background_config JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_next_order INT;
    v_page_id UUID := gen_random_uuid();
    v_final_title TEXT;
    v_result JSONB;
BEGIN
    SELECT COALESCE(MAX(page_order), 0) + 1 INTO v_next_order
    FROM public.whiteboard_pages
    WHERE whiteboard_id = p_whiteboard_id AND deleted_at IS NULL;

    v_final_title := COALESCE(NULLIF(TRIM(p_title), ''), v_next_order::TEXT || '. Page ' || v_next_order::TEXT);

    INSERT INTO public.whiteboard_pages (
        id, whiteboard_id, school_id, title, page_order, background_type, background_config, created_by
    ) VALUES (
        v_page_id, p_whiteboard_id, p_school_id, v_final_title, v_next_order,
        COALESCE(p_background_type, 'plain'), COALESCE(p_background_config, '{}'::jsonb), p_user_id
    );

    UPDATE public.live_class_whiteboards
    SET current_revision = COALESCE(current_revision, 0) + 1, updated_at = NOW()
    WHERE id = p_whiteboard_id;

    PERFORM public.sp_log_whiteboard_audit(p_whiteboard_id, p_school_id, p_user_id, 'page.created', jsonb_build_object('page_id', v_page_id, 'title', v_final_title));

    SELECT jsonb_build_object(
        'id', wp.id,
        'whiteboard_id', wp.whiteboard_id,
        'title', wp.title,
        'page_order', wp.page_order,
        'background_type', wp.background_type,
        'background_config', wp.background_config,
        'canvas_config', wp.canvas_config,
        'is_locked', wp.is_locked,
        'objects', '[]'::jsonb
    ) INTO v_result
    FROM public.whiteboard_pages wp WHERE wp.id = v_page_id;

    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_duplicate_whiteboard_page(
    p_page_id UUID,
    p_whiteboard_id UUID,
    p_school_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_src RECORD;
    v_new_page_id UUID := gen_random_uuid();
    v_next_order INT;
    v_result JSONB;
BEGIN
    SELECT * INTO v_src FROM public.whiteboard_pages
    WHERE id = p_page_id AND whiteboard_id = p_whiteboard_id AND deleted_at IS NULL LIMIT 1;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    SELECT COALESCE(MAX(page_order), 0) + 1 INTO v_next_order
    FROM public.whiteboard_pages WHERE whiteboard_id = p_whiteboard_id AND deleted_at IS NULL;

    INSERT INTO public.whiteboard_pages (
        id, whiteboard_id, school_id, title, page_order, background_type, background_config, canvas_config, created_by
    ) VALUES (
        v_new_page_id, p_whiteboard_id, p_school_id, v_src.title || ' (Copy)', v_next_order,
        v_src.background_type, v_src.background_config, v_src.canvas_config, p_user_id
    );

    INSERT INTO public.whiteboard_objects (
        whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, is_locked, created_by
    )
    SELECT p_whiteboard_id, v_new_page_id, p_school_id,
           object_id || '_copy_' || SUBSTRING(gen_random_uuid()::TEXT, 1, 6),
           object_type, object_data, z_index, is_locked, p_user_id
    FROM public.whiteboard_objects
    WHERE page_id = p_page_id AND deleted_at IS NULL;

    PERFORM public.sp_log_whiteboard_audit(p_whiteboard_id, p_school_id, p_user_id, 'page.duplicated', jsonb_build_object('source_page_id', p_page_id, 'new_page_id', v_new_page_id));

    SELECT jsonb_build_object(
        'id', wp.id,
        'whiteboard_id', wp.whiteboard_id,
        'title', wp.title,
        'page_order', wp.page_order,
        'background_type', wp.background_type,
        'background_config', wp.background_config,
        'canvas_config', wp.canvas_config,
        'is_locked', wp.is_locked,
        'objects', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object('id', wo.object_id, 'db_id', wo.id, 'page_id', wo.page_id, 'type', wo.object_type, 'data', wo.object_data, 'z_index', wo.z_index, 'is_locked', wo.is_locked)
                ORDER BY wo.z_index ASC
            ) FROM public.whiteboard_objects wo WHERE wo.page_id = wp.id AND wo.deleted_at IS NULL
        ), '[]'::jsonb)
    ) INTO v_result FROM public.whiteboard_pages wp WHERE wp.id = v_new_page_id;

    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_reorder_whiteboard_pages(
    p_whiteboard_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_page_ids UUID[]
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_idx INT := 1;
    v_pid UUID;
BEGIN
    FOREACH v_pid IN ARRAY p_page_ids LOOP
        UPDATE public.whiteboard_pages
        SET page_order = v_idx, updated_at = NOW()
        WHERE id = v_pid AND whiteboard_id = p_whiteboard_id AND school_id = p_school_id;
        v_idx := v_idx + 1;
    END LOOP;

    PERFORM public.sp_log_whiteboard_audit(p_whiteboard_id, p_school_id, p_user_id, 'page.reordered', jsonb_build_object('order', p_page_ids));
    RETURN TRUE;
END;
$$;

-- 6. Snapshot & Named Version Checkpoint + Restore
CREATE OR REPLACE FUNCTION public.sp_create_whiteboard_snapshot(
    p_whiteboard_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_version_name TEXT DEFAULT NULL,
    p_is_checkpoint BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_rev BIGINT;
    v_full JSONB;
    v_snap_id UUID := gen_random_uuid();
    v_ver_id UUID := gen_random_uuid();
    v_user_name TEXT;
    v_ver_title TEXT;
BEGIN
    SELECT current_revision INTO v_rev FROM public.live_class_whiteboards
    WHERE id = p_whiteboard_id AND school_id = p_school_id AND deleted_at IS NULL LIMIT 1;

    IF v_rev IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT full_name INTO v_user_name FROM public.profiles WHERE id = p_user_id LIMIT 1;
    v_full := public.sp_get_whiteboard_full(p_whiteboard_id, p_school_id, p_user_id);

    INSERT INTO public.whiteboard_snapshots (
        id, whiteboard_id, school_id, revision, snapshot_data, created_by
    ) VALUES (
        v_snap_id, p_whiteboard_id, p_school_id, v_rev,
        jsonb_build_object('pages', v_full->'pages', 'title', v_full->>'title'),
        p_user_id
    );

    v_ver_title := COALESCE(NULLIF(TRIM(p_version_name), ''), 'Autosave Rev #' || v_rev::TEXT);

    INSERT INTO public.whiteboard_versions (
        id, whiteboard_id, school_id, revision, version_name, is_checkpoint, snapshot_id, created_by, created_by_name
    ) VALUES (
        v_ver_id, p_whiteboard_id, p_school_id, v_rev, v_ver_title, COALESCE(p_is_checkpoint, FALSE), v_snap_id, p_user_id, COALESCE(v_user_name, 'Teacher')
    );

    PERFORM public.sp_log_whiteboard_audit(p_whiteboard_id, p_school_id, p_user_id, 'version.created', jsonb_build_object('version_id', v_ver_id, 'revision', v_rev, 'name', v_ver_title));

    RETURN jsonb_build_object(
        'id', v_ver_id,
        'snapshot_id', v_snap_id,
        'revision', v_rev,
        'version_name', v_ver_title,
        'is_checkpoint', COALESCE(p_is_checkpoint, FALSE),
        'created_by_name', COALESCE(v_user_name, 'Teacher'),
        'created_at', NOW()
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_restore_whiteboard_version(
    p_whiteboard_id UUID,
    p_version_id UUID,
    p_school_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_ver RECORD;
    v_snap JSONB;
    v_page JSONB;
    v_obj JSONB;
    v_page_uuid UUID;
    v_new_rev BIGINT;
BEGIN
    SELECT v.id, v.version_name, s.snapshot_data INTO v_ver
    FROM public.whiteboard_versions v
    JOIN public.whiteboard_snapshots s ON s.id = v.snapshot_id
    WHERE v.id = p_version_id AND v.whiteboard_id = p_whiteboard_id AND v.school_id = p_school_id
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    v_snap := v_ver.snapshot_data;

    -- Save pre-restore safety checkpoint so later work is never destroyed
    PERFORM public.sp_create_whiteboard_snapshot(p_whiteboard_id, p_school_id, p_user_id, 'Pre-Restore Backup', TRUE);

    -- Soft-delete current objects & pages
    UPDATE public.whiteboard_objects SET deleted_at = NOW() WHERE whiteboard_id = p_whiteboard_id AND deleted_at IS NULL;
    UPDATE public.whiteboard_pages SET deleted_at = NOW() WHERE whiteboard_id = p_whiteboard_id AND deleted_at IS NULL;

    -- Re-hydrate pages and objects from snapshot
    IF jsonb_typeof(v_snap->'pages') = 'array' THEN
        FOR v_page IN SELECT * FROM jsonb_array_elements(v_snap->'pages') LOOP
            v_page_uuid := COALESCE((v_page->>'id')::UUID, gen_random_uuid());
            INSERT INTO public.whiteboard_pages (
                id, whiteboard_id, school_id, title, page_order, background_type, background_config, canvas_config, is_locked, deleted_at, updated_at
            ) VALUES (
                v_page_uuid, p_whiteboard_id, p_school_id,
                COALESCE(v_page->>'title', 'Restored Page'),
                COALESCE((v_page->>'page_order')::INT, 1),
                COALESCE(v_page->>'background_type', 'plain'),
                COALESCE(v_page->'background_config', '{}'::jsonb),
                COALESCE(v_page->'canvas_config', '{"width": 2400, "height": 1600}'::jsonb),
                COALESCE((v_page->>'is_locked')::BOOLEAN, FALSE),
                NULL, NOW()
            )
            ON CONFLICT (id) DO UPDATE SET
                title = EXCLUDED.title,
                page_order = EXCLUDED.page_order,
                background_type = EXCLUDED.background_type,
                background_config = EXCLUDED.background_config,
                is_locked = EXCLUDED.is_locked,
                deleted_at = NULL,
                updated_at = NOW();

            IF jsonb_typeof(v_page->'objects') = 'array' THEN
                FOR v_obj IN SELECT * FROM jsonb_array_elements(v_page->'objects') LOOP
                    INSERT INTO public.whiteboard_objects (
                        whiteboard_id, page_id, school_id, object_id, object_type, object_data, z_index, is_locked, deleted_at, updated_at
                    ) VALUES (
                        p_whiteboard_id, v_page_uuid, p_school_id,
                        v_obj->>'id', COALESCE(v_obj->>'type', 'stroke'),
                        COALESCE(v_obj->'data', '{}'::jsonb),
                        COALESCE((v_obj->>'z_index')::INT, 0),
                        COALESCE((v_obj->>'is_locked')::BOOLEAN, FALSE),
                        NULL, NOW()
                    )
                    ON CONFLICT (page_id, object_id) DO UPDATE SET
                        object_type = EXCLUDED.object_type,
                        object_data = EXCLUDED.object_data,
                        z_index = EXCLUDED.z_index,
                        is_locked = EXCLUDED.is_locked,
                        deleted_at = NULL,
                        updated_at = NOW();
                END LOOP;
            END IF;
        END LOOP;
    END IF;

    -- Bump revision
    UPDATE public.live_class_whiteboards
    SET current_revision = COALESCE(current_revision, 0) + 1, updated_at = NOW()
    WHERE id = p_whiteboard_id
    RETURNING current_revision INTO v_new_rev;

    PERFORM public.sp_log_whiteboard_audit(p_whiteboard_id, p_school_id, p_user_id, 'version.restored', jsonb_build_object('restored_version_id', p_version_id, 'new_revision', v_new_rev));

    RETURN public.sp_get_whiteboard_full(p_whiteboard_id, p_school_id, p_user_id);
END;
$$;

-- 7. Sync Since Revision
CREATE OR REPLACE FUNCTION public.sp_sync_whiteboard_since(
    p_whiteboard_id UUID,
    p_school_id UUID,
    p_since_revision BIGINT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_rev BIGINT;
    v_ops JSONB;
BEGIN
    SELECT current_revision INTO v_current_rev
    FROM public.live_class_whiteboards
    WHERE id = p_whiteboard_id AND school_id = p_school_id AND deleted_at IS NULL
    LIMIT 1;

    IF v_current_rev IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'operation_id', op.operation_id,
            'page_id', op.page_id,
            'revision', op.revision,
            'user_id', op.user_id,
            'operation_type', op.operation_type,
            'object_id', op.object_id,
            'operation_data', op.operation_data,
            'created_at', op.created_at
        ) ORDER BY op.revision ASC
    ), '[]'::jsonb) INTO v_ops
    FROM public.whiteboard_operations op
    WHERE op.whiteboard_id = p_whiteboard_id AND op.revision > COALESCE(p_since_revision, 0);

    RETURN jsonb_build_object(
        'whiteboard_id', p_whiteboard_id,
        'current_revision', v_current_rev,
        'since_revision', p_since_revision,
        'operations', v_ops
    );
END;
$$;

-- 8. Update Whiteboard Metadata & Collaborator Settings
CREATE OR REPLACE FUNCTION public.sp_update_whiteboard_meta(
    p_whiteboard_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_title TEXT DEFAULT NULL,
    p_collaboration_enabled BOOLEAN DEFAULT NULL,
    p_presentation_mode BOOLEAN DEFAULT NULL,
    p_teacher_only_mode BOOLEAN DEFAULT NULL,
    p_default_permissions JSONB DEFAULT NULL,
    p_status TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.live_class_whiteboards
    SET title = COALESCE(NULLIF(TRIM(p_title), ''), title),
        collaboration_enabled = COALESCE(p_collaboration_enabled, collaboration_enabled),
        presentation_mode = COALESCE(p_presentation_mode, presentation_mode),
        teacher_only_mode = COALESCE(p_teacher_only_mode, teacher_only_mode),
        default_permissions = COALESCE(p_default_permissions, default_permissions),
        status = COALESCE(p_status, status),
        last_saved_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_whiteboard_id AND school_id = p_school_id AND deleted_at IS NULL;

    PERFORM public.sp_log_whiteboard_audit(p_whiteboard_id, p_school_id, p_user_id, 'whiteboard.updated', jsonb_build_object(
        'title', p_title, 'collaboration_enabled', p_collaboration_enabled, 'presentation_mode', p_presentation_mode
    ));

    RETURN public.sp_get_whiteboard_full(p_whiteboard_id, p_school_id, p_user_id);
END;
$$;

-- 9. Update & Delete Whiteboard Page
CREATE OR REPLACE FUNCTION public.sp_update_whiteboard_page(
    p_page_id UUID,
    p_whiteboard_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_title TEXT DEFAULT NULL,
    p_background_type TEXT DEFAULT NULL,
    p_background_config JSONB DEFAULT NULL,
    p_is_locked BOOLEAN DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    UPDATE public.whiteboard_pages
    SET title = COALESCE(NULLIF(TRIM(p_title), ''), title),
        background_type = COALESCE(p_background_type, background_type),
        background_config = COALESCE(p_background_config, background_config),
        is_locked = COALESCE(p_is_locked, is_locked),
        updated_at = NOW()
    WHERE id = p_page_id AND whiteboard_id = p_whiteboard_id AND school_id = p_school_id AND deleted_at IS NULL;

    PERFORM public.sp_log_whiteboard_audit(p_whiteboard_id, p_school_id, p_user_id, 'page.updated', jsonb_build_object('page_id', p_page_id, 'title', p_title, 'background', p_background_type));

    SELECT jsonb_build_object(
        'id', wp.id,
        'whiteboard_id', wp.whiteboard_id,
        'title', wp.title,
        'page_order', wp.page_order,
        'background_type', wp.background_type,
        'background_config', wp.background_config,
        'canvas_config', wp.canvas_config,
        'is_locked', wp.is_locked
    ) INTO v_result FROM public.whiteboard_pages wp WHERE wp.id = p_page_id;

    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_delete_whiteboard_page(
    p_page_id UUID,
    p_whiteboard_id UUID,
    p_school_id UUID,
    p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM public.whiteboard_pages
    WHERE whiteboard_id = p_whiteboard_id AND deleted_at IS NULL;
    IF v_count <= 1 THEN
        RETURN FALSE;
    END IF;

    UPDATE public.whiteboard_pages
    SET deleted_at = NOW(), updated_at = NOW()
    WHERE id = p_page_id AND whiteboard_id = p_whiteboard_id AND school_id = p_school_id;

    PERFORM public.sp_log_whiteboard_audit(p_whiteboard_id, p_school_id, p_user_id, 'page.deleted', jsonb_build_object('page_id', p_page_id));
    RETURN TRUE;
END;
$$;

-- 10. Set Permission / Student Assignment Area
CREATE OR REPLACE FUNCTION public.sp_set_whiteboard_permission(
    p_whiteboard_id UUID,
    p_school_id UUID,
    p_granted_by UUID,
    p_target_user_id UUID DEFAULT NULL,
    p_target_role TEXT DEFAULT NULL,
    p_permission_type TEXT DEFAULT 'EDIT',
    p_assigned_area JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID;
BEGIN
    IF p_target_user_id IS NOT NULL THEN
        INSERT INTO public.whiteboard_permissions (
            whiteboard_id, school_id, user_id, permission_type, assigned_area, granted_by, updated_at
        ) VALUES (
            p_whiteboard_id, p_school_id, p_target_user_id, p_permission_type, p_assigned_area, p_granted_by, NOW()
        )
        ON CONFLICT (whiteboard_id, user_id) WHERE user_id IS NOT NULL DO UPDATE SET
            permission_type = EXCLUDED.permission_type,
            assigned_area = EXCLUDED.assigned_area,
            granted_by = EXCLUDED.granted_by,
            updated_at = NOW()
        RETURNING id INTO v_id;
    ELSIF p_target_role IS NOT NULL THEN
        INSERT INTO public.whiteboard_permissions (
            whiteboard_id, school_id, role_ref, permission_type, assigned_area, granted_by, updated_at
        ) VALUES (
            p_whiteboard_id, p_school_id, LOWER(p_target_role), p_permission_type, p_assigned_area, p_granted_by, NOW()
        )
        ON CONFLICT (whiteboard_id, role_ref) WHERE role_ref IS NOT NULL AND user_id IS NULL DO UPDATE SET
            permission_type = EXCLUDED.permission_type,
            assigned_area = EXCLUDED.assigned_area,
            granted_by = EXCLUDED.granted_by,
            updated_at = NOW()
        RETURNING id INTO v_id;
    END IF;

    PERFORM public.sp_log_whiteboard_audit(p_whiteboard_id, p_school_id, p_granted_by, 'permission.changed', jsonb_build_object(
        'target_user_id', p_target_user_id, 'target_role', p_target_role, 'permission_type', p_permission_type
    ));

    RETURN jsonb_build_object('success', TRUE, 'id', v_id, 'permission_type', p_permission_type);
END;
$$;

-- 11. Share Whiteboard
CREATE OR REPLACE FUNCTION public.sp_share_whiteboard(
    p_whiteboard_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_share_type TEXT,
    p_target_id UUID DEFAULT NULL,
    p_target_label TEXT DEFAULT '',
    p_access_level TEXT DEFAULT 'VIEW',
    p_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID := gen_random_uuid();
    v_token TEXT := 'wb_' || replace(gen_random_uuid()::TEXT, '-', '');
BEGIN
    INSERT INTO public.whiteboard_shares (
        id, whiteboard_id, school_id, share_type, target_id, target_label,
        access_level, share_token, expires_at, shared_by
    ) VALUES (
        v_id, p_whiteboard_id, p_school_id, p_share_type, p_target_id, p_target_label,
        COALESCE(p_access_level, 'VIEW'), v_token, p_expires_at, p_user_id
    );

    PERFORM public.sp_log_whiteboard_audit(p_whiteboard_id, p_school_id, p_user_id, 'whiteboard.shared', jsonb_build_object(
        'share_type', p_share_type, 'target_label', p_target_label, 'access_level', p_access_level
    ));

    RETURN jsonb_build_object(
        'id', v_id,
        'share_type', p_share_type,
        'target_id', p_target_id,
        'target_label', p_target_label,
        'access_level', p_access_level,
        'share_token', v_token,
        'expires_at', p_expires_at,
        'created_at', NOW()
    );
END;
$$;

-- 12. Register Asset & Record Export
CREATE OR REPLACE FUNCTION public.sp_register_whiteboard_asset(
    p_whiteboard_id UUID,
    p_page_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_storage_key TEXT,
    p_file_name TEXT,
    p_mime_type TEXT,
    p_file_size BIGINT,
    p_width INT DEFAULT NULL,
    p_height INT DEFAULT NULL,
    p_page_count INT DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO public.whiteboard_assets (
        id, whiteboard_id, page_id, school_id, uploaded_by,
        storage_key, file_name, mime_type, file_size, width, height, page_count
    ) VALUES (
        v_id, p_whiteboard_id, p_page_id, p_school_id, p_user_id,
        p_storage_key, p_file_name, p_mime_type, p_file_size, p_width, p_height, COALESCE(p_page_count, 1)
    );

    PERFORM public.sp_log_whiteboard_audit(p_whiteboard_id, p_school_id, p_user_id, 'asset.uploaded', jsonb_build_object('asset_id', v_id, 'file_name', p_file_name, 'mime_type', p_mime_type));

    RETURN jsonb_build_object(
        'id', v_id,
        'whiteboard_id', p_whiteboard_id,
        'page_id', p_page_id,
        'storage_key', p_storage_key,
        'file_name', p_file_name,
        'mime_type', p_mime_type,
        'file_size', p_file_size,
        'width', p_width,
        'height', p_height,
        'page_count', COALESCE(p_page_count, 1),
        'created_at', NOW()
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_record_whiteboard_export(
    p_whiteboard_id UUID,
    p_school_id UUID,
    p_user_id UUID,
    p_export_format TEXT,
    p_scope TEXT,
    p_storage_key TEXT,
    p_status TEXT DEFAULT 'READY'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO public.whiteboard_exports (
        id, whiteboard_id, school_id, requested_by, export_format, scope, storage_key, status
    ) VALUES (
        v_id, p_whiteboard_id, p_school_id, p_user_id, p_export_format, p_scope, p_storage_key, p_status
    );

    PERFORM public.sp_log_whiteboard_audit(p_whiteboard_id, p_school_id, p_user_id, 'whiteboard.exported', jsonb_build_object('format', p_export_format, 'scope', p_scope));

    RETURN jsonb_build_object('id', v_id, 'format', p_export_format, 'scope', p_scope, 'storage_key', p_storage_key, 'status', p_status, 'created_at', NOW());
END;
$$;

COMMIT;
