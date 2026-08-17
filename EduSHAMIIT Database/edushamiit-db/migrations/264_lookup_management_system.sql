-- ============================================================================
-- Migration 264: Universal Enterprise Lookup Management System for EduSHAMIIT ERP
-- Multi-Tenant, Independent Key-Value Engine with Creator Ownership & Auditing
-- ============================================================================

-- 1. Create Lookup Keys Table
CREATE TABLE IF NOT EXISTS public.lookup_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    key_name VARCHAR(150) NOT NULL,
    key_code VARCHAR(150) NOT NULL,
    description TEXT,
    key_type VARCHAR(20) NOT NULL DEFAULT 'CUSTOM', -- 'SYSTEM', 'CUSTOM'
    icon VARCHAR(100) DEFAULT 'folder_outlined',
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',    -- 'ACTIVE', 'INACTIVE'
    version INTEGER NOT NULL DEFAULT 1,
    created_by UUID NOT NULL REFERENCES public.profiles(id),
    updated_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ NULL,
    deleted_by UUID REFERENCES public.profiles(id)
);

-- Indexes for lookup_keys
CREATE UNIQUE INDEX IF NOT EXISTS uq_lookup_keys_school_code 
    ON public.lookup_keys (school_id, key_code) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_lookup_keys_school_status 
    ON public.lookup_keys (school_id, status) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_lookup_keys_created_by 
    ON public.lookup_keys (school_id, created_by) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_lookup_keys_key_type 
    ON public.lookup_keys (school_id, key_type) 
    WHERE deleted_at IS NULL;


-- 2. Create Lookup Values Table
CREATE TABLE IF NOT EXISTS public.lookup_values (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lookup_key_id UUID NOT NULL REFERENCES public.lookup_keys(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    value_name VARCHAR(150) NOT NULL,
    value_code VARCHAR(150) NOT NULL,
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- 'ACTIVE', 'INACTIVE'
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_by UUID NOT NULL REFERENCES public.profiles(id),
    updated_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ NULL,
    deleted_by UUID REFERENCES public.profiles(id)
);

-- Indexes for lookup_values
CREATE UNIQUE INDEX IF NOT EXISTS uq_lookup_values_key_code 
    ON public.lookup_values (lookup_key_id, value_code) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_lookup_values_key_sort 
    ON public.lookup_values (lookup_key_id, sort_order ASC, created_at ASC) 
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_lookup_values_school_status 
    ON public.lookup_values (school_id, status) 
    WHERE deleted_at IS NULL;


-- 3. Create Dynamic Usage Registry Table (Stores known module references)
CREATE TABLE IF NOT EXISTS public.lookup_usage_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    lookup_key_id UUID NOT NULL REFERENCES public.lookup_keys(id) ON DELETE CASCADE,
    lookup_value_id UUID NULL REFERENCES public.lookup_values(id) ON DELETE CASCADE,
    module_name VARCHAR(100) NOT NULL, -- 'Calendar', 'Notices', 'Transport', 'Users', 'Reports'
    table_name VARCHAR(100) NOT NULL,
    record_count INTEGER NOT NULL DEFAULT 0,
    last_synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_lookup_usage UNIQUE (school_id, lookup_key_id, lookup_value_id, module_name, table_name)
);

CREATE INDEX IF NOT EXISTS idx_lookup_usage_key ON public.lookup_usage_registry (lookup_key_id);
CREATE INDEX IF NOT EXISTS idx_lookup_usage_value ON public.lookup_usage_registry (lookup_value_id);


-- ============================================================================
-- 5. Stored Procedures & Functions
-- ============================================================================

-- Function: Calculate dynamic usage count for a lookup key or value
CREATE OR REPLACE FUNCTION public.fn_calculate_lookup_usage(
    p_school_id UUID,
    p_lookup_key_id UUID,
    p_lookup_value_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_key_code VARCHAR(150);
    v_val_code VARCHAR(150);
    v_usage_list JSONB := '[]'::JSONB;
    v_total_records INT := 0;
    v_modules_count INT := 0;
    v_cnt INT := 0;
BEGIN
    SELECT key_code INTO v_key_code 
    FROM public.lookup_keys 
    WHERE id = p_lookup_key_id AND school_id = p_school_id;

    IF p_lookup_value_id IS NOT NULL THEN
        SELECT value_code INTO v_val_code 
        FROM public.lookup_values 
        WHERE id = p_lookup_value_id AND lookup_key_id = p_lookup_key_id;
    END IF;

    -- Check Calendar / Events module usage safely
    IF (v_key_code = 'CALENDAR_CATEGORY' OR v_key_code = 'EVENT_CATEGORY') AND to_regclass('public.events') IS NOT NULL THEN
        BEGIN
            IF v_val_code IS NOT NULL THEN
                EXECUTE 'SELECT COUNT(*) FROM public.events WHERE school_id = $1 AND (category_code = $2 OR category = $2)' 
                INTO v_cnt USING p_school_id, v_val_code;
            ELSE
                EXECUTE 'SELECT COUNT(*) FROM public.events WHERE school_id = $1 AND (category IS NOT NULL OR category_code IS NOT NULL)' 
                INTO v_cnt USING p_school_id;
            END IF;
            IF v_cnt > 0 THEN
                v_usage_list := v_usage_list || jsonb_build_object('module', 'Calendar', 'records', v_cnt, 'table', 'events');
                v_total_records := v_total_records + v_cnt;
                v_modules_count := v_modules_count + 1;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- ignore
        END;
    END IF;

    -- Check Notice module usage safely
    IF (v_key_code = 'NOTICE_CATEGORY' OR v_key_code = 'CATEGORY') AND to_regclass('public.notices') IS NOT NULL THEN
        BEGIN
            IF v_val_code IS NOT NULL THEN
                EXECUTE 'SELECT COUNT(*) FROM public.notices WHERE school_id = $1 AND category = $2' 
                INTO v_cnt USING p_school_id, v_val_code;
            ELSE
                EXECUTE 'SELECT COUNT(*) FROM public.notices WHERE school_id = $1 AND category IS NOT NULL' 
                INTO v_cnt USING p_school_id;
            END IF;
            IF v_cnt > 0 THEN
                v_usage_list := v_usage_list || jsonb_build_object('module', 'Notices', 'records', v_cnt, 'table', 'notices');
                v_total_records := v_total_records + v_cnt;
                v_modules_count := v_modules_count + 1;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- ignore
        END;
    END IF;

    -- Check Vehicle / Transport module usage safely
    IF v_key_code = 'VEHICLE_CATEGORY' AND to_regclass('public.vehicles') IS NOT NULL THEN
        BEGIN
            IF v_val_code IS NOT NULL THEN
                EXECUTE 'SELECT COUNT(*) FROM public.vehicles WHERE school_id = $1 AND type = $2' 
                INTO v_cnt USING p_school_id, v_val_code;
            ELSE
                EXECUTE 'SELECT COUNT(*) FROM public.vehicles WHERE school_id = $1' 
                INTO v_cnt USING p_school_id;
            END IF;
            IF v_cnt > 0 THEN
                v_usage_list := v_usage_list || jsonb_build_object('module', 'Transport', 'records', v_cnt, 'table', 'vehicles');
                v_total_records := v_total_records + v_cnt;
                v_modules_count := v_modules_count + 1;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- ignore
        END;
    END IF;

    -- Check User Category usage safely
    IF v_key_code = 'USER_CATEGORY' AND to_regclass('public.profiles') IS NOT NULL THEN
        BEGIN
            IF v_val_code IS NOT NULL THEN
                EXECUTE 'SELECT COUNT(*) FROM public.profiles WHERE school_id = $1 AND role ILIKE $2' 
                INTO v_cnt USING p_school_id, v_val_code;
            ELSE
                EXECUTE 'SELECT COUNT(*) FROM public.profiles WHERE school_id = $1' 
                INTO v_cnt USING p_school_id;
            END IF;
            IF v_cnt > 0 THEN
                v_usage_list := v_usage_list || jsonb_build_object('module', 'Users', 'records', v_cnt, 'table', 'profiles');
                v_total_records := v_total_records + v_cnt;
                v_modules_count := v_modules_count + 1;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- ignore
        END;
    END IF;

    -- Include any custom entries in lookup_usage_registry
    IF to_regclass('public.lookup_usage_registry') IS NOT NULL THEN
        FOR v_cnt, v_key_code IN 
            SELECT record_count, module_name 
            FROM public.lookup_usage_registry 
            WHERE school_id = p_school_id 
              AND lookup_key_id = p_lookup_key_id 
              AND (p_lookup_value_id IS NULL OR lookup_value_id = p_lookup_value_id)
        LOOP
            v_usage_list := v_usage_list || jsonb_build_object('module', v_key_code, 'records', v_cnt);
            v_total_records := v_total_records + v_cnt;
            v_modules_count := v_modules_count + 1;
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'total_records', v_total_records,
        'modules_count', v_modules_count,
        'modules_summary', CASE 
            WHEN v_modules_count = 0 THEN '0 Modules'
            WHEN v_modules_count = 1 THEN (v_usage_list->0->>'module') || ' (1 Module)'
            ELSE (v_usage_list->0->>'module') || ' +' || (v_modules_count - 1)::TEXT || ' more (' || v_modules_count::TEXT || ' Modules)'
        END,
        'breakdown', v_usage_list
    );
END;
$$;


-- Function: Get Paginated Lookup Keys
CREATE OR REPLACE FUNCTION public.fn_get_lookup_keys(
    p_school_id UUID,
    p_user_id UUID,
    p_tab VARCHAR DEFAULT 'all',           -- 'all', 'active', 'inactive', 'system', 'custom'
    p_search VARCHAR DEFAULT '',
    p_status VARCHAR DEFAULT '',          -- 'ACTIVE', 'INACTIVE', ''
    p_created_by VARCHAR DEFAULT '',       -- 'all', 'my_keys', 'others', 'system'
    p_key_type VARCHAR DEFAULT '',         -- 'SYSTEM', 'CUSTOM', ''
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'created_at', -- 'key_name', 'key_code', 'created_at', 'values_count', 'status'
    p_sort_order VARCHAR DEFAULT 'DESC'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT;
    v_total_records INT := 0;
    v_total_pages INT := 0;
    v_items JSONB := '[]'::JSONB;
    v_user_role VARCHAR(50);
BEGIN
    SELECT role INTO v_user_role FROM public.profiles WHERE id = p_user_id;

    v_offset := (p_page - 1) * p_page_size;

    -- CTE for filtered keys
    WITH key_data AS (
        SELECT 
            k.id,
            k.school_id,
            k.key_name,
            k.key_code,
            k.description,
            k.key_type,
            k.icon,
            k.status,
            k.version,
            k.created_by,
            k.updated_by,
            k.created_at,
            k.updated_at,
            COALESCE(p.full_name, 'System') AS creator_name,
            (k.created_by = p_user_id OR v_user_role = 'super_admin') AS is_owner,
            COUNT(v.id) FILTER (WHERE v.deleted_at IS NULL) AS total_values_count,
            COUNT(v.id) FILTER (WHERE v.deleted_at IS NULL AND v.status = 'ACTIVE') AS active_values_count,
            COUNT(v.id) FILTER (WHERE v.deleted_at IS NULL AND v.status = 'INACTIVE') AS inactive_values_count
        FROM public.lookup_keys k
        LEFT JOIN public.profiles p ON p.id = k.created_by
        LEFT JOIN public.lookup_values v ON v.lookup_key_id = k.id
        WHERE k.school_id = p_school_id
          AND k.deleted_at IS NULL
          -- Tab filters
          AND (
            p_tab = 'all' OR p_tab = '' OR
            (p_tab = 'active' AND k.status = 'ACTIVE') OR
            (p_tab = 'inactive' AND k.status = 'INACTIVE') OR
            (p_tab = 'system' AND k.key_type = 'SYSTEM') OR
            (p_tab = 'custom' AND k.key_type = 'CUSTOM')
          )
          -- Search filter
          AND (
            p_search IS NULL OR TRIM(p_search) = '' OR
            k.key_name ILIKE '%' || TRIM(p_search) || '%' OR
            k.key_code ILIKE '%' || TRIM(p_search) || '%' OR
            COALESCE(k.description, '') ILIKE '%' || TRIM(p_search) || '%'
          )
          -- Status filter
          AND (
            p_status IS NULL OR TRIM(p_status) = '' OR p_status ILIKE 'all' OR
            k.status ILIKE TRIM(p_status)
          )
          -- Key Type filter
          AND (
            p_key_type IS NULL OR TRIM(p_key_type) = '' OR p_key_type ILIKE 'all' OR
            k.key_type ILIKE TRIM(p_key_type)
          )
          -- Created By filter
          AND (
            p_created_by IS NULL OR TRIM(p_created_by) = '' OR p_created_by ILIKE 'all' OR
            (p_created_by ILIKE 'my_keys' AND k.created_by = p_user_id) OR
            (p_created_by ILIKE 'others' AND k.created_by IS NOT NULL AND k.created_by != p_user_id) OR
            (p_created_by ILIKE 'system' AND (k.key_type = 'SYSTEM' OR k.created_by IS NULL))
          )
        GROUP BY k.id, p.full_name
    ),
    counted AS (
        SELECT COUNT(*) AS total FROM key_data
    ),
    sorted_paginated AS (
        SELECT kd.*
        FROM key_data kd
        ORDER BY 
            CASE WHEN p_sort_by = 'key_name' AND p_sort_order ILIKE 'ASC' THEN kd.key_name END ASC,
            CASE WHEN p_sort_by = 'key_name' AND p_sort_order ILIKE 'DESC' THEN kd.key_name END DESC,
            CASE WHEN p_sort_by = 'key_code' AND p_sort_order ILIKE 'ASC' THEN kd.key_code END ASC,
            CASE WHEN p_sort_by = 'key_code' AND p_sort_order ILIKE 'DESC' THEN kd.key_code END DESC,
            CASE WHEN p_sort_by = 'values_count' AND p_sort_order ILIKE 'ASC' THEN kd.total_values_count END ASC,
            CASE WHEN p_sort_by = 'values_count' AND p_sort_order ILIKE 'DESC' THEN kd.total_values_count END DESC,
            CASE WHEN p_sort_by = 'status' AND p_sort_order ILIKE 'ASC' THEN kd.status END ASC,
            CASE WHEN p_sort_by = 'status' AND p_sort_order ILIKE 'DESC' THEN kd.status END DESC,
            CASE WHEN p_sort_by = 'created_at' AND p_sort_order ILIKE 'ASC' THEN kd.created_at END ASC,
            CASE WHEN p_sort_by = 'created_at' AND p_sort_order ILIKE 'DESC' THEN kd.created_at END DESC,
            kd.created_at DESC
        LIMIT p_page_size OFFSET v_offset
    )
    SELECT 
        COALESCE(c.total, 0),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', sp.id,
                    'school_id', sp.school_id,
                    'key_name', sp.key_name,
                    'key_code', sp.key_code,
                    'description', sp.description,
                    'key_type', sp.key_type,
                    'icon', sp.icon,
                    'status', sp.status,
                    'version', sp.version,
                    'created_by', sp.created_by,
                    'creator_name', sp.creator_name,
                    'is_owner', sp.is_owner,
                    'total_values_count', sp.total_values_count,
                    'active_values_count', sp.active_values_count,
                    'inactive_values_count', sp.inactive_values_count,
                    'created_at', sp.created_at,
                    'updated_at', sp.updated_at,
                    'usage', public.fn_calculate_lookup_usage(p_school_id, sp.id)
                )
            ), 
            '[]'::JSONB
        )
    INTO v_total_records, v_items
    FROM counted c
    LEFT JOIN sorted_paginated sp ON TRUE
    GROUP BY c.total;

    IF v_total_records > 0 THEN
        v_total_pages := CEIL(v_total_records::NUMERIC / p_page_size::NUMERIC)::INT;
    ELSE
        v_total_pages := 0;
        v_items := '[]'::JSONB;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'page', p_page,
        'page_size', p_page_size,
        'total_records', v_total_records,
        'total_pages', v_total_pages,
        'data', v_items
    );
END;
$$;


-- Function: Get Single Lookup Key Detail with Statistics and Usage
CREATE OR REPLACE FUNCTION public.fn_get_lookup_key_detail(
    p_school_id UUID,
    p_user_id UUID,
    p_lookup_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_key RECORD;
    v_creator_name VARCHAR(150);
    v_is_owner BOOLEAN;
    v_user_role VARCHAR(50);
    v_total_val INT;
    v_active_val INT;
    v_inactive_val INT;
    v_usage JSONB;
BEGIN
    SELECT role INTO v_user_role FROM public.profiles WHERE id = p_user_id;

    SELECT k.*, p.full_name AS creator
    INTO v_key
    FROM public.lookup_keys k
    LEFT JOIN public.profiles p ON p.id = k.created_by
    WHERE k.id = p_lookup_id AND k.school_id = p_school_id AND k.deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Lookup Key not found');
    END IF;

    v_is_owner := (v_key.created_by = p_user_id OR v_user_role = 'super_admin');
    v_creator_name := COALESCE(v_key.creator, 'System');

    SELECT 
        COUNT(*) FILTER (WHERE deleted_at IS NULL),
        COUNT(*) FILTER (WHERE deleted_at IS NULL AND status = 'ACTIVE'),
        COUNT(*) FILTER (WHERE deleted_at IS NULL AND status = 'INACTIVE')
    INTO v_total_val, v_active_val, v_inactive_val
    FROM public.lookup_values
    WHERE lookup_key_id = p_lookup_id;

    v_usage := public.fn_calculate_lookup_usage(p_school_id, p_lookup_id);

    RETURN jsonb_build_object(
        'success', TRUE,
        'data', jsonb_build_object(
            'id', v_key.id,
            'school_id', v_key.school_id,
            'key_name', v_key.key_name,
            'key_code', v_key.key_code,
            'description', v_key.description,
            'key_type', v_key.key_type,
            'icon', v_key.icon,
            'status', v_key.status,
            'version', v_key.version,
            'created_by', v_key.created_by,
            'creator_name', v_creator_name,
            'is_owner', v_is_owner,
            'stats', jsonb_build_object(
                'total_values', v_total_val,
                'active_values', v_active_val,
                'inactive_values', v_inactive_val,
                'used_in_module', v_usage->>'modules_summary',
                'modules_count', (v_usage->>'modules_count')::INT,
                'total_records', (v_usage->>'total_records')::INT,
                'key_type', v_key.key_type
            ),
            'usage', v_usage,
            'created_at', v_key.created_at,
            'updated_at', v_key.updated_at
        )
    );
END;
$$;


-- Function: Get Paginated Lookup Values for a Key
CREATE OR REPLACE FUNCTION public.fn_get_lookup_values(
    p_school_id UUID,
    p_user_id UUID,
    p_lookup_id UUID,
    p_search VARCHAR DEFAULT '',
    p_status VARCHAR DEFAULT '',
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10,
    p_sort_by VARCHAR DEFAULT 'sort_order',
    p_sort_order VARCHAR DEFAULT 'ASC'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_offset INT;
    v_total_records INT := 0;
    v_total_pages INT := 0;
    v_items JSONB := '[]'::JSONB;
    v_key_owner_id UUID;
    v_user_role VARCHAR(50);
    v_is_owner BOOLEAN;
BEGIN
    SELECT created_by INTO v_key_owner_id 
    FROM public.lookup_keys 
    WHERE id = p_lookup_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Lookup Key not found');
    END IF;

    SELECT role INTO v_user_role FROM public.profiles WHERE id = p_user_id;
    v_is_owner := (v_key_owner_id = p_user_id OR v_user_role = 'super_admin');

    v_offset := (p_page - 1) * p_page_size;

    WITH val_data AS (
        SELECT 
            v.id,
            v.lookup_key_id,
            v.school_id,
            v.value_name,
            v.value_code,
            v.description,
            v.status,
            v.sort_order,
            v.created_by,
            COALESCE(p.full_name, 'System') AS creator_name,
            v.created_at,
            v.updated_at
        FROM public.lookup_values v
        LEFT JOIN public.profiles p ON p.id = v.created_by
        WHERE v.lookup_key_id = p_lookup_id
          AND v.school_id = p_school_id
          AND v.deleted_at IS NULL
          AND (
            p_search IS NULL OR TRIM(p_search) = '' OR
            v.value_name ILIKE '%' || TRIM(p_search) || '%' OR
            v.value_code ILIKE '%' || TRIM(p_search) || '%' OR
            COALESCE(v.description, '') ILIKE '%' || TRIM(p_search) || '%'
          )
          AND (
            p_status IS NULL OR TRIM(p_status) = '' OR p_status ILIKE 'all' OR
            v.status ILIKE TRIM(p_status)
          )
    ),
    counted AS (
        SELECT COUNT(*) AS total FROM val_data
    ),
    sorted_paginated AS (
        SELECT vd.*
        FROM val_data vd
        ORDER BY 
            CASE WHEN p_sort_by = 'sort_order' AND p_sort_order ILIKE 'ASC' THEN vd.sort_order END ASC,
            CASE WHEN p_sort_by = 'sort_order' AND p_sort_order ILIKE 'DESC' THEN vd.sort_order END DESC,
            CASE WHEN p_sort_by = 'value_name' AND p_sort_order ILIKE 'ASC' THEN vd.value_name END ASC,
            CASE WHEN p_sort_by = 'value_name' AND p_sort_order ILIKE 'DESC' THEN vd.value_name END DESC,
            CASE WHEN p_sort_by = 'value_code' AND p_sort_order ILIKE 'ASC' THEN vd.value_code END ASC,
            CASE WHEN p_sort_by = 'value_code' AND p_sort_order ILIKE 'DESC' THEN vd.value_code END DESC,
            CASE WHEN p_sort_by = 'status' AND p_sort_order ILIKE 'ASC' THEN vd.status END ASC,
            CASE WHEN p_sort_by = 'status' AND p_sort_order ILIKE 'DESC' THEN vd.status END DESC,
            CASE WHEN p_sort_by = 'created_at' AND p_sort_order ILIKE 'ASC' THEN vd.created_at END ASC,
            CASE WHEN p_sort_by = 'created_at' AND p_sort_order ILIKE 'DESC' THEN vd.created_at END DESC,
            vd.sort_order ASC, vd.created_at ASC
        LIMIT p_page_size OFFSET v_offset
    )
    SELECT 
        COALESCE(c.total, 0),
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', sp.id,
                    'lookup_key_id', sp.lookup_key_id,
                    'value_name', sp.value_name,
                    'value_code', sp.value_code,
                    'description', sp.description,
                    'status', sp.status,
                    'sort_order', sp.sort_order,
                    'created_by', sp.created_by,
                    'creator_name', sp.creator_name,
                    'created_at', sp.created_at,
                    'updated_at', sp.updated_at,
                    'usage', public.fn_calculate_lookup_usage(p_school_id, p_lookup_id, sp.id)
                )
            ), 
            '[]'::JSONB
        )
    INTO v_total_records, v_items
    FROM counted c
    LEFT JOIN sorted_paginated sp ON TRUE
    GROUP BY c.total;

    IF v_total_records > 0 THEN
        v_total_pages := CEIL(v_total_records::NUMERIC / p_page_size::NUMERIC)::INT;
    ELSE
        v_total_pages := 0;
        v_items := '[]'::JSONB;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'page', p_page,
        'page_size', p_page_size,
        'total_records', v_total_records,
        'total_pages', v_total_pages,
        'is_owner', v_is_owner,
        'data', v_items
    );
END;
$$;


-- Helper Function: Record Lookup Audit Log directly into centralized public.audit_logs
CREATE OR REPLACE FUNCTION public.fn_record_lookup_audit(
    p_school_id UUID,
    p_user_id UUID,
    p_event_type TEXT,
    p_action TEXT,
    p_resource TEXT,
    p_resource_type TEXT,
    p_lookup_key_id UUID,
    p_details JSONB DEFAULT '{}'::JSONB,
    p_before_state JSONB DEFAULT NULL,
    p_after_state JSONB DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_email TEXT;
    v_user_name TEXT;
    v_user_role TEXT;
BEGIN
    IF p_user_id IS NOT NULL THEN
        SELECT email, full_name, role 
        INTO v_user_email, v_user_name, v_user_role 
        FROM public.profiles 
        WHERE id = p_user_id;
    END IF;

    INSERT INTO public.audit_logs (
        school_id,
        user_id,
        user_email,
        user_name,
        user_role,
        event_type,
        module,
        action,
        resource,
        resource_type,
        status,
        changes,
        created_at
    ) VALUES (
        p_school_id,
        p_user_id,
        COALESCE(v_user_email, 'system@schoolerp.com'),
        COALESCE(v_user_name, 'System User'),
        COALESCE(v_user_role, 'staff'),
        p_event_type,
        'Lookup Management',
        p_action,
        p_resource,
        p_resource_type,
        'Success',
        jsonb_build_object(
            'lookup_key_id', p_lookup_key_id,
            'details', COALESCE(p_details, '{}'::JSONB),
            'before_state', p_before_state,
            'after_state', p_after_state
        ),
        NOW()
    );
EXCEPTION WHEN OTHERS THEN
    NULL;
END;
$$;


-- Function: Create Lookup Key + Optional Initial Values
CREATE OR REPLACE FUNCTION public.fn_create_lookup_key(
    p_school_id UUID,
    p_user_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_key_name VARCHAR(150);
    v_key_code VARCHAR(150);
    v_description TEXT;
    v_key_type VARCHAR(20);
    v_icon VARCHAR(100);
    v_status VARCHAR(20);
    v_key_id UUID;
    v_values JSONB;
    v_val JSONB;
    v_val_name VARCHAR(150);
    v_val_code VARCHAR(150);
    v_val_desc TEXT;
    v_val_status VARCHAR(20);
    v_sort INT := 1;
    v_created_val_count INT := 0;
BEGIN
    v_key_name := TRIM(COALESCE(p_payload->>'key_name', ''));
    v_key_code := UPPER(TRIM(COALESCE(p_payload->>'key_code', '')));
    v_description := TRIM(COALESCE(p_payload->>'description', ''));
    v_key_type := UPPER(TRIM(COALESCE(p_payload->>'key_type', 'CUSTOM')));
    v_icon := COALESCE(p_payload->>'icon', 'folder_outlined');
    v_status := UPPER(TRIM(COALESCE(p_payload->>'status', 'ACTIVE')));

    IF v_key_name = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Lookup key name is required');
    END IF;

    IF v_key_code = '' THEN
        -- Auto-generate key_code from key_name
        v_key_code := UPPER(REGEXP_REPLACE(v_key_name, '[^a-zA-Z0-9]+', '_', 'g'));
        v_key_code := TRIM(BOTH '_' FROM v_key_code);
    END IF;

    -- Check duplicate key_code within institution
    IF EXISTS (
        SELECT 1 FROM public.lookup_keys 
        WHERE school_id = p_school_id 
          AND key_code = v_key_code 
          AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object(
            'success', FALSE, 
            'error', 'A lookup key with code "' || v_key_code || '" already exists in this institution',
            'code', 409
        );
    END IF;

    -- Insert Key
    INSERT INTO public.lookup_keys (
        school_id, key_name, key_code, description, key_type, icon, status, created_by, version
    ) VALUES (
        p_school_id, v_key_name, v_key_code, v_description, v_key_type, v_icon, v_status, p_user_id, 1
    ) RETURNING id INTO v_key_id;

    -- Insert Initial Values if provided
    v_values := p_payload->'initial_values';
    IF v_values IS NOT NULL AND jsonb_typeof(v_values) = 'array' THEN
        FOR v_val IN SELECT * FROM jsonb_array_elements(v_values) LOOP
            v_val_name := TRIM(COALESCE(v_val->>'value_name', ''));
            v_val_code := UPPER(TRIM(COALESCE(v_val->>'value_code', '')));
            v_val_desc := TRIM(COALESCE(v_val->>'description', ''));
            v_val_status := UPPER(TRIM(COALESCE(v_val->>'status', 'ACTIVE')));

            IF v_val_name != '' THEN
                IF v_val_code = '' THEN
                    v_val_code := UPPER(REGEXP_REPLACE(v_val_name, '[^a-zA-Z0-9]+', '_', 'g'));
                    v_val_code := TRIM(BOTH '_' FROM v_val_code);
                END IF;

                INSERT INTO public.lookup_values (
                    lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by
                ) VALUES (
                    v_key_id, p_school_id, v_val_name, v_val_code, v_val_desc, v_val_status, v_sort, p_user_id
                ) ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;

                v_sort := v_sort + 1;
                v_created_val_count := v_created_val_count + 1;
            END IF;
        END LOOP;
    END IF;

    -- Centralized Audit Log
    PERFORM public.fn_record_lookup_audit(
        p_school_id, p_user_id, 'Create', 'Created Lookup Key', v_key_name, 'LOOKUP_KEY', v_key_id,
        jsonb_build_object('key_name', v_key_name, 'key_code', v_key_code, 'values_added', v_created_val_count),
        NULL,
        jsonb_build_object('id', v_key_id, 'key_name', v_key_name, 'key_code', v_key_code, 'status', v_status)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Lookup Key created successfully',
        'data', jsonb_build_object(
            'id', v_key_id,
            'key_name', v_key_name,
            'key_code', v_key_code,
            'key_type', v_key_type,
            'status', v_status,
            'initial_values_count', v_created_val_count
        )
    );
END;
$$;


-- Function: Update Lookup Key (Ownership & Concurrency Enforced)
CREATE OR REPLACE FUNCTION public.fn_update_lookup_key(
    p_school_id UUID,
    p_user_id UUID,
    p_lookup_id UUID,
    p_payload JSONB,
    p_version INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_curr RECORD;
    v_user_role VARCHAR(50);
    v_key_name VARCHAR(150);
    v_description TEXT;
    v_icon VARCHAR(100);
    v_status VARCHAR(20);
    v_new_version INT;
BEGIN
    SELECT role INTO v_user_role FROM public.profiles WHERE id = p_user_id;

    SELECT * INTO v_curr
    FROM public.lookup_keys
    WHERE id = p_lookup_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Lookup Key not found');
    END IF;

    -- Ownership Check: Only creator or super_admin can modify
    IF v_curr.created_by != p_user_id AND v_user_role != 'super_admin' THEN
        RETURN jsonb_build_object(
            'success', FALSE, 
            'error', 'You can view this lookup, but only its creator can modify it',
            'code', 403
        );
    END IF;

    -- Optimistic Concurrency Check
    IF p_version IS NOT NULL AND v_curr.version != p_version THEN
        RETURN jsonb_build_object(
            'success', FALSE, 
            'error', 'This lookup was updated by another user. Please refresh before saving.',
            'code', 409
        );
    END IF;

    v_key_name := TRIM(COALESCE(p_payload->>'key_name', v_curr.key_name));
    v_description := TRIM(COALESCE(p_payload->>'description', v_curr.description));
    v_icon := COALESCE(p_payload->>'icon', v_curr.icon);
    v_status := UPPER(TRIM(COALESCE(p_payload->>'status', v_curr.status)));
    v_new_version := v_curr.version + 1;

    UPDATE public.lookup_keys SET
        key_name = v_key_name,
        description = v_description,
        icon = v_icon,
        status = v_status,
        version = v_new_version,
        updated_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_lookup_id;

    -- Centralized Audit Log
    PERFORM public.fn_record_lookup_audit(
        p_school_id, p_user_id, 'Update', 'Updated Lookup Key', v_key_name, 'LOOKUP_KEY', p_lookup_id,
        jsonb_build_object('key_name', v_key_name, 'version', v_new_version),
        to_jsonb(v_curr),
        jsonb_build_object('key_name', v_key_name, 'description', v_description, 'status', v_status, 'version', v_new_version)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Lookup Key updated successfully',
        'data', jsonb_build_object(
            'id', p_lookup_id,
            'key_name', v_key_name,
            'key_code', v_curr.key_code,
            'status', v_status,
            'version', v_new_version
        )
    );
END;
$$;


-- Function: Delete / Deactivate Lookup Key
CREATE OR REPLACE FUNCTION public.fn_delete_lookup_key(
    p_school_id UUID,
    p_user_id UUID,
    p_lookup_id UUID,
    p_force_deactivate BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_curr RECORD;
    v_user_role VARCHAR(50);
    v_usage JSONB;
    v_records INT := 0;
BEGIN
    SELECT role INTO v_user_role FROM public.profiles WHERE id = p_user_id;

    SELECT * INTO v_curr
    FROM public.lookup_keys
    WHERE id = p_lookup_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Lookup Key not found');
    END IF;

    -- Ownership Check
    IF v_curr.created_by != p_user_id AND v_user_role != 'super_admin' THEN
        RETURN jsonb_build_object(
            'success', FALSE, 
            'error', 'You can view this lookup, but only its creator can delete it',
            'code', 403
        );
    END IF;

    -- Usage Check
    v_usage := public.fn_calculate_lookup_usage(p_school_id, p_lookup_id);
    v_records := (v_usage->>'total_records')::INT;

    IF v_records > 0 AND NOT p_force_deactivate THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'is_used', TRUE,
            'error', 'This lookup key is currently referenced by ' || (v_usage->>'modules_summary') || ' (' || v_records::TEXT || ' records). You can deactivate it instead.',
            'usage', v_usage,
            'code', 400
        );
    END IF;

    IF p_force_deactivate OR v_records > 0 THEN
        -- Deactivate instead of hard/soft delete
        UPDATE public.lookup_keys SET
            status = 'INACTIVE',
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = p_lookup_id;

        PERFORM public.fn_record_lookup_audit(
            p_school_id, p_user_id, 'Update', 'Deactivated Lookup Key', v_curr.key_name, 'LOOKUP_KEY', p_lookup_id,
            jsonb_build_object('reason', 'Deactivated due to module usage')
        );

        RETURN jsonb_build_object(
            'success', TRUE,
            'action', 'DEACTIVATED',
            'message', 'Lookup Key deactivated successfully because it is referenced by other modules'
        );
    ELSE
        -- Soft Delete Key + Associated Values
        UPDATE public.lookup_keys SET
            deleted_at = NOW(),
            deleted_by = p_user_id
        WHERE id = p_lookup_id;

        UPDATE public.lookup_values SET
            deleted_at = NOW(),
            deleted_by = p_user_id
        WHERE lookup_key_id = p_lookup_id AND deleted_at IS NULL;

        PERFORM public.fn_record_lookup_audit(
            p_school_id, p_user_id, 'Delete', 'Deleted Lookup Key', v_curr.key_name, 'LOOKUP_KEY', p_lookup_id,
            jsonb_build_object('key_name', v_curr.key_name, 'key_code', v_curr.key_code)
        );

        RETURN jsonb_build_object(
            'success', TRUE,
            'action', 'DELETED',
            'message', 'Lookup Key and all values deleted successfully'
        );
    END IF;
END;
$$;


-- Function: Create Lookup Value (Ownership Enforced)
CREATE OR REPLACE FUNCTION public.fn_create_lookup_value(
    p_school_id UUID,
    p_user_id UUID,
    p_lookup_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_key RECORD;
    v_user_role VARCHAR(50);
    v_val_name VARCHAR(150);
    v_val_code VARCHAR(150);
    v_description TEXT;
    v_status VARCHAR(20);
    v_sort INT;
    v_new_val_id UUID;
BEGIN
    SELECT role INTO v_user_role FROM public.profiles WHERE id = p_user_id;

    SELECT * INTO v_key 
    FROM public.lookup_keys 
    WHERE id = p_lookup_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Lookup Key not found');
    END IF;

    -- Ownership Check
    IF v_key.created_by != p_user_id AND v_user_role != 'super_admin' THEN
        RETURN jsonb_build_object(
            'success', FALSE, 
            'error', 'You can view this lookup, but only its creator can add values to it',
            'code', 403
        );
    END IF;

    v_val_name := TRIM(COALESCE(p_payload->>'value_name', ''));
    v_val_code := UPPER(TRIM(COALESCE(p_payload->>'value_code', '')));
    v_description := TRIM(COALESCE(p_payload->>'description', ''));
    v_status := UPPER(TRIM(COALESCE(p_payload->>'status', 'ACTIVE')));

    IF v_val_name = '' THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Value name is required');
    END IF;

    IF v_val_code = '' THEN
        v_val_code := UPPER(REGEXP_REPLACE(v_val_name, '[^a-zA-Z0-9]+', '_', 'g'));
        v_val_code := TRIM(BOTH '_' FROM v_val_code);
    END IF;

    -- Duplicate Check inside Lookup Key
    IF EXISTS (
        SELECT 1 FROM public.lookup_values 
        WHERE lookup_key_id = p_lookup_id 
          AND value_code = v_val_code 
          AND deleted_at IS NULL
    ) THEN
        RETURN jsonb_build_object(
            'success', FALSE, 
            'error', 'A value with code "' || v_val_code || '" already exists in this lookup key',
            'code', 409
        );
    END IF;

    -- Calculate next sort_order
    SELECT COALESCE(MAX(sort_order), 0) + 1 INTO v_sort
    FROM public.lookup_values
    WHERE lookup_key_id = p_lookup_id AND deleted_at IS NULL;

    IF p_payload->>'sort_order' IS NOT NULL THEN
        v_sort := (p_payload->>'sort_order')::INT;
    END IF;

    INSERT INTO public.lookup_values (
        lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by
    ) VALUES (
        p_lookup_id, p_school_id, v_val_name, v_val_code, v_description, v_status, v_sort, p_user_id
    ) RETURNING id INTO v_new_val_id;

    -- Update Key updated_at
    UPDATE public.lookup_keys SET updated_at = NOW(), updated_by = p_user_id WHERE id = p_lookup_id;

    -- Centralized Audit Log
    PERFORM public.fn_record_lookup_audit(
        p_school_id, p_user_id, 'Create', 'Created Lookup Value', v_val_name, 'LOOKUP_VALUE', p_lookup_id,
        jsonb_build_object('lookup_key_id', p_lookup_id, 'value_id', v_new_val_id, 'value_name', v_val_name, 'value_code', v_val_code)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Value added successfully',
        'data', jsonb_build_object(
            'id', v_new_val_id,
            'lookup_key_id', p_lookup_id,
            'value_name', v_val_name,
            'value_code', v_val_code,
            'status', v_status,
            'sort_order', v_sort
        )
    );
END;
$$;


-- Function: Update Lookup Value (Ownership Enforced)
CREATE OR REPLACE FUNCTION public.fn_update_lookup_value(
    p_school_id UUID,
    p_user_id UUID,
    p_value_id UUID,
    p_payload JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_val RECORD;
    v_key RECORD;
    v_user_role VARCHAR(50);
    v_val_name VARCHAR(150);
    v_val_desc TEXT;
    v_status VARCHAR(20);
    v_sort INT;
BEGIN
    SELECT role INTO v_user_role FROM public.profiles WHERE id = p_user_id;

    SELECT * INTO v_val 
    FROM public.lookup_values 
    WHERE id = p_value_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Lookup Value not found');
    END IF;

    SELECT * INTO v_key 
    FROM public.lookup_keys 
    WHERE id = v_val.lookup_key_id AND school_id = p_school_id AND deleted_at IS NULL;

    -- Ownership Check on Parent Key
    IF v_key.created_by != p_user_id AND v_user_role != 'super_admin' THEN
        RETURN jsonb_build_object(
            'success', FALSE, 
            'error', 'You can view this value, but only the lookup creator can modify it',
            'code', 403
        );
    END IF;

    v_val_name := TRIM(COALESCE(p_payload->>'value_name', v_val.value_name));
    v_val_desc := TRIM(COALESCE(p_payload->>'description', v_val.description));
    v_status := UPPER(TRIM(COALESCE(p_payload->>'status', v_val.status)));
    v_sort := COALESCE((p_payload->>'sort_order')::INT, v_val.sort_order);

    UPDATE public.lookup_values SET
        value_name = v_val_name,
        description = v_val_desc,
        status = v_status,
        sort_order = v_sort,
        updated_by = p_user_id,
        updated_at = NOW()
    WHERE id = p_value_id;

    UPDATE public.lookup_keys SET updated_at = NOW(), updated_by = p_user_id WHERE id = v_val.lookup_key_id;

    -- Centralized Audit Log
    PERFORM public.fn_record_lookup_audit(
        p_school_id, p_user_id, 'Update', 'Updated Lookup Value', v_val_name, 'LOOKUP_VALUE', v_val.lookup_key_id,
        jsonb_build_object('lookup_key_id', v_val.lookup_key_id, 'value_id', p_value_id, 'value_name', v_val_name, 'status', v_status),
        to_jsonb(v_val),
        jsonb_build_object('value_name', v_val_name, 'status', v_status, 'sort_order', v_sort)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Value updated successfully',
        'data', jsonb_build_object(
            'id', p_value_id,
            'value_name', v_val_name,
            'value_code', v_val.value_code,
            'status', v_status,
            'sort_order', v_sort
        )
    );
END;
$$;


-- Function: Delete / Deactivate Lookup Value (Usage & Ownership Enforced)
CREATE OR REPLACE FUNCTION public.fn_delete_lookup_value(
    p_school_id UUID,
    p_user_id UUID,
    p_value_id UUID,
    p_force_deactivate BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_val RECORD;
    v_key RECORD;
    v_user_role VARCHAR(50);
    v_usage JSONB;
    v_records INT := 0;
BEGIN
    SELECT role INTO v_user_role FROM public.profiles WHERE id = p_user_id;

    SELECT * INTO v_val 
    FROM public.lookup_values 
    WHERE id = p_value_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Lookup Value not found');
    END IF;

    SELECT * INTO v_key 
    FROM public.lookup_keys 
    WHERE id = v_val.lookup_key_id AND school_id = p_school_id AND deleted_at IS NULL;

    -- Ownership Check
    IF v_key.created_by != p_user_id AND v_user_role != 'super_admin' THEN
        RETURN jsonb_build_object(
            'success', FALSE, 
            'error', 'You can view this value, but only the lookup creator can delete it',
            'code', 403
        );
    END IF;

    -- Usage Check
    v_usage := public.fn_calculate_lookup_usage(p_school_id, v_val.lookup_key_id, p_value_id);
    v_records := (v_usage->>'total_records')::INT;

    IF v_records > 0 AND NOT p_force_deactivate THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'is_used', TRUE,
            'error', 'This value is currently used by ' || (v_usage->>'modules_summary') || ' (' || v_records::TEXT || ' records). You can deactivate it instead.',
            'usage', v_usage,
            'code', 400
        );
    END IF;

    IF p_force_deactivate OR v_records > 0 THEN
        UPDATE public.lookup_values SET
            status = 'INACTIVE',
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = p_value_id;

        PERFORM public.fn_record_lookup_audit(
            p_school_id, p_user_id, 'Update', 'Deactivated Lookup Value', v_val.value_name, 'LOOKUP_VALUE', v_val.lookup_key_id,
            jsonb_build_object('lookup_key_id', v_val.lookup_key_id, 'value_id', p_value_id, 'value_name', v_val.value_name, 'reason', 'Deactivated due to module usage')
        );

        RETURN jsonb_build_object(
            'success', TRUE,
            'action', 'DEACTIVATED',
            'message', 'Value deactivated successfully because it is referenced by other modules'
        );
    ELSE
        UPDATE public.lookup_values SET
            deleted_at = NOW(),
            deleted_by = p_user_id
        WHERE id = p_value_id;

        PERFORM public.fn_record_lookup_audit(
            p_school_id, p_user_id, 'Delete', 'Deleted Lookup Value', v_val.value_name, 'LOOKUP_VALUE', v_val.lookup_key_id,
            jsonb_build_object('lookup_key_id', v_val.lookup_key_id, 'value_id', p_value_id, 'value_name', v_val.value_name, 'value_code', v_val.value_code)
        );

        RETURN jsonb_build_object(
            'success', TRUE,
            'action', 'DELETED',
            'message', 'Value deleted successfully'
        );
    END IF;
END;
$$;


-- Function: Reorder Lookup Values (Ownership Enforced)
CREATE OR REPLACE FUNCTION public.fn_reorder_lookup_values(
    p_school_id UUID,
    p_user_id UUID,
    p_lookup_id UUID,
    p_ordered_value_ids UUID[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_key RECORD;
    v_user_role VARCHAR(50);
    v_id UUID;
    v_idx INT := 1;
BEGIN
    SELECT role INTO v_user_role FROM public.profiles WHERE id = p_user_id;

    SELECT * INTO v_key 
    FROM public.lookup_keys 
    WHERE id = p_lookup_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Lookup Key not found');
    END IF;

    -- Ownership Check
    IF v_key.created_by != p_user_id AND v_user_role != 'super_admin' THEN
        RETURN jsonb_build_object(
            'success', FALSE, 
            'error', 'You can view this lookup, but only its creator can reorder values',
            'code', 403
        );
    END IF;

    FOREACH v_id IN ARRAY p_ordered_value_ids LOOP
        UPDATE public.lookup_values SET
            sort_order = v_idx,
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = v_id AND lookup_key_id = p_lookup_id AND school_id = p_school_id;

        v_idx := v_idx + 1;
    END LOOP;

    -- Centralized Audit Log
    PERFORM public.fn_record_lookup_audit(
        p_school_id, p_user_id, 'Update', 'Reordered Lookup Values', p_lookup_id::TEXT, 'LOOKUP_KEY', p_lookup_id,
        jsonb_build_object('lookup_key_id', p_lookup_id, 'reordered_count', array_length(p_ordered_value_ids, 1))
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message', 'Values reordered successfully'
    );
END;
$$;


-- Function: Bulk Create Lookup Values (Ownership & Validation Enforced)
CREATE OR REPLACE FUNCTION public.fn_bulk_create_lookup_values(
    p_school_id UUID,
    p_user_id UUID,
    p_lookup_id UUID,
    p_values_array JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_key RECORD;
    v_user_role VARCHAR(50);
    v_val JSONB;
    v_val_name VARCHAR(150);
    v_val_code VARCHAR(150);
    v_val_desc TEXT;
    v_val_status VARCHAR(20);
    v_sort INT;
    v_created_ids UUID[] := ARRAY[]::UUID[];
    v_errors TEXT[] := ARRAY[]::TEXT[];
    v_idx INT := 0;
    v_new_id UUID;
BEGIN
    SELECT role INTO v_user_role FROM public.profiles WHERE id = p_user_id;

    SELECT * INTO v_key 
    FROM public.lookup_keys 
    WHERE id = p_lookup_id AND school_id = p_school_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Lookup Key not found');
    END IF;

    -- Ownership Check
    IF v_key.created_by != p_user_id AND v_user_role != 'super_admin' THEN
        RETURN jsonb_build_object(
            'success', FALSE, 
            'error', 'You can view this lookup, but only its creator can add values to it',
            'code', 403
        );
    END IF;

    SELECT COALESCE(MAX(sort_order), 0) INTO v_sort
    FROM public.lookup_values
    WHERE lookup_key_id = p_lookup_id AND deleted_at IS NULL;

    FOR v_val IN SELECT * FROM jsonb_array_elements(p_values_array) LOOP
        v_idx := v_idx + 1;
        v_val_name := TRIM(COALESCE(v_val->>'value_name', ''));
        v_val_code := UPPER(TRIM(COALESCE(v_val->>'value_code', '')));
        v_val_desc := TRIM(COALESCE(v_val->>'description', ''));
        v_val_status := UPPER(TRIM(COALESCE(v_val->>'status', 'ACTIVE')));

        IF v_val_name = '' THEN
            v_errors := array_append(v_errors, 'Row ' || v_idx::TEXT || ': Value name is required');
            CONTINUE;
        END IF;

        IF v_val_code = '' THEN
            v_val_code := UPPER(REGEXP_REPLACE(v_val_name, '[^a-zA-Z0-9]+', '_', 'g'));
            v_val_code := TRIM(BOTH '_' FROM v_val_code);
        END IF;

        -- Check duplicate
        IF EXISTS (
            SELECT 1 FROM public.lookup_values 
            WHERE lookup_key_id = p_lookup_id 
              AND value_code = v_val_code 
              AND deleted_at IS NULL
        ) THEN
            v_errors := array_append(v_errors, 'Row ' || v_idx::TEXT || ' (' || v_val_name || '): Code "' || v_val_code || '" already exists');
            CONTINUE;
        END IF;

        v_sort := v_sort + 1;

        INSERT INTO public.lookup_values (
            lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by
        ) VALUES (
            p_lookup_id, p_school_id, v_val_name, v_val_code, v_val_desc, v_val_status, v_sort, p_user_id
        ) RETURNING id INTO v_new_id;

        v_created_ids := array_append(v_created_ids, v_new_id);
    END LOOP;

    UPDATE public.lookup_keys SET updated_at = NOW(), updated_by = p_user_id WHERE id = p_lookup_id;

    -- Centralized Audit Log
    PERFORM public.fn_record_lookup_audit(
        p_school_id, p_user_id, 'Create', 'Imported Lookup Values', p_lookup_id::TEXT, 'LOOKUP_KEY', p_lookup_id,
        jsonb_build_object('lookup_key_id', p_lookup_id, 'total_rows', v_idx, 'imported_count', array_length(v_created_ids, 1), 'errors_count', array_length(v_errors, 1))
    );

    RETURN jsonb_build_object(
        'success', (array_length(v_created_ids, 1) > 0 OR array_length(v_errors, 1) IS NULL),
        'imported_count', COALESCE(array_length(v_created_ids, 1), 0),
        'total_rows', v_idx,
        'created_value_ids', v_created_ids,
        'errors', v_errors
    );
END;
$$;


-- Function: Generic Module Lookup Resolver (Fast API for Other ERP Modules)
CREATE OR REPLACE FUNCTION public.fn_get_lookup_by_code(
    p_school_id UUID,
    p_key_code VARCHAR,
    p_include_inactive BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_key RECORD;
    v_values JSONB;
BEGIN
    SELECT id, key_name, key_code, status, icon INTO v_key
    FROM public.lookup_keys
    WHERE school_id = p_school_id 
      AND UPPER(key_code) = UPPER(TRIM(p_key_code))
      AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Lookup code "' || p_key_code || '" not found');
    END IF;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', v.id,
                'code', v.value_code,
                'label', v.value_name,
                'description', v.description,
                'status', v.status,
                'sort_order', v.sort_order
            ) ORDER BY v.sort_order ASC, v.created_at ASC
        ),
        '[]'::JSONB
    ) INTO v_values
    FROM public.lookup_values v
    WHERE v.lookup_key_id = v_key.id
      AND v.deleted_at IS NULL
      AND (p_include_inactive OR v.status = 'ACTIVE');

    RETURN jsonb_build_object(
        'success', TRUE,
        'key', v_key.key_code,
        'key_name', v_key.key_name,
        'status', v_key.status,
        'values', v_values
    );
END;
$$;


-- Function: Get Audit Logs for a Lookup Key from Centralized Audit Logs
CREATE OR REPLACE FUNCTION public.fn_get_lookup_audit_logs(
    p_school_id UUID,
    p_lookup_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_logs JSONB;
BEGIN
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', a.id,
                'action', a.action,
                'entity_type', COALESCE(a.resource_type, 'LOOKUP_KEY'),
                'entity_id', COALESCE((a.changes->>'lookup_key_id')::UUID, p_lookup_id),
                'user_id', a.user_id,
                'user_name', COALESCE(a.user_name, p.full_name, 'System User'),
                'details', COALESCE(a.changes->'details', '{}'::JSONB),
                'before_state', a.changes->'before_state',
                'after_state', a.changes->'after_state',
                'created_at', a.created_at
            ) ORDER BY a.created_at DESC
        ),
        '[]'::JSONB
    ) INTO v_logs
    FROM public.audit_logs a
    LEFT JOIN public.profiles p ON p.id = a.user_id
    WHERE a.school_id = p_school_id
      AND (a.module = 'Lookup Management' OR a.resource_type IN ('LOOKUP_KEY', 'LOOKUP_VALUE'))
      AND (
        (a.changes->>'lookup_key_id') = p_lookup_id::TEXT OR
        a.resource = p_lookup_id::TEXT
      );

    RETURN jsonb_build_object('success', TRUE, 'data', v_logs);
END;
$$;


-- ============================================================================
-- 6. Seed Standard System Lookup Keys for All Existing Schools
-- ============================================================================

DO $$
DECLARE
    s RECORD;
    admin_id UUID;
    v_key_id UUID;
BEGIN
    FOR s IN SELECT id FROM public.schools LOOP
        -- Find default admin or creator for the school
        SELECT id INTO admin_id FROM public.profiles WHERE school_id = s.id LIMIT 1;
        IF admin_id IS NULL THEN
            SELECT id INTO admin_id FROM public.profiles LIMIT 1;
        END IF;

        IF admin_id IS NOT NULL THEN
            -- 1. CALENDAR_CATEGORY
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Calendar Category', 'CALENDAR_CATEGORY', 'Categories used for classifying calendar events.', 'SYSTEM', 'calendar_today_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Academic', 'ACADEMIC', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Event', 'EVENT', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Holiday', 'HOLIDAY', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Meeting', 'MEETING', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Examination', 'EXAMINATION', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Reminder', 'REMINDER', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'Personal', 'PERSONAL', 'ACTIVE', 7, admin_id),
                    (v_key_id, s.id, 'Birthday', 'BIRTHDAY', 'INACTIVE', 8, admin_id),
                    (v_key_id, s.id, 'Anniversary', 'ANNIVERSARY', 'ACTIVE', 9, admin_id),
                    (v_key_id, s.id, 'Sports', 'SPORTS', 'ACTIVE', 10, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 2. MODULE_CATEGORY
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Module Category', 'MODULE_CATEGORY', 'ERP module groupings and classification tags.', 'SYSTEM', 'grid_view_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Academic', 'ACADEMIC', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Administration', 'ADMINISTRATION', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Communication', 'COMMUNICATION', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Transport', 'TRANSPORT', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Finance', 'FINANCE', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Human Resources', 'HR', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'Analytics & BI', 'ANALYTICS', 'ACTIVE', 7, admin_id),
                    (v_key_id, s.id, 'Security & Core', 'SECURITY', 'ACTIVE', 8, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 3. VEHICLE_CATEGORY
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Vehicle Category', 'VEHICLE_CATEGORY', 'Classification of fleet and school transit vehicles.', 'CUSTOM', 'directions_bus_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'School Bus', 'SCHOOL_BUS', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Mini Bus', 'MINI_BUS', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Van', 'VAN', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Electric Bus', 'ELECTRIC_BUS', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Contract Vehicle', 'CONTRACT_VEHICLE', 'ACTIVE', 5, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 4. USER_CATEGORY
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'User Category', 'USER_CATEGORY', 'Primary user identity and role categories across the institute.', 'CUSTOM', 'people_outline_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Student', 'STUDENT', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Teacher', 'TEACHER', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Driver', 'DRIVER', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Parent', 'PARENT', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Transport Manager', 'TRANSPORT_MANAGER', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Principal', 'PRINCIPAL', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'Accountant', 'ACCOUNTANT', 'ACTIVE', 7, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 5. DOCUMENT_CATEGORY
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Document Category', 'DOCUMENT_CATEGORY', 'Standard document types for identity, admissions, and compliance.', 'SYSTEM', 'description_outlined', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Birth Certificate', 'BIRTH_CERTIFICATE', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Transfer Certificate', 'TRANSFER_CERTIFICATE', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Aadhaar Card', 'AADHAAR_CARD', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Passport Copy', 'PASSPORT_COPY', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Medical Fitness Certificate', 'MEDICAL_CERTIFICATE', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Previous Marksheet', 'PREVIOUS_MARKSHEET', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'Caste Certificate', 'CASTE_CERTIFICATE', 'ACTIVE', 7, admin_id),
                    (v_key_id, s.id, 'Income Certificate', 'INCOME_CERTIFICATE', 'ACTIVE', 8, admin_id),
                    (v_key_id, s.id, 'Address Proof', 'ADDRESS_PROOF', 'ACTIVE', 9, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 6. EXPENSE_CATEGORY
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Expense Category', 'EXPENSE_CATEGORY', 'Institutional expense and operational cost classification.', 'CUSTOM', 'receipt_long_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Fuel & Maintenance', 'FUEL_MAINTENANCE', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Laboratory Supplies', 'LAB_SUPPLIES', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Office Stationery', 'STATIONERY', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Electricity & Utilities', 'UTILITIES', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Staff Refreshments', 'REFRESHMENTS', 'ACTIVE', 5, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 7. LEAVE_CATEGORY
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Leave Category', 'LEAVE_CATEGORY', 'Faculty and student leave balance types.', 'SYSTEM', 'event_busy_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Casual Leave (CL)', 'CASUAL_LEAVE', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Medical Leave (ML)', 'MEDICAL_LEAVE', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Earned Leave (EL)', 'EARNED_LEAVE', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Maternity Leave', 'MATERNITY_LEAVE', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Duty Leave (OD)', 'DUTY_LEAVE', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Unpaid Leave', 'UNPAID_LEAVE', 'ACTIVE', 6, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 8. FEE_CATEGORY
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Fee Category', 'FEE_CATEGORY', 'Student fee ledger categories and fee component breakdowns.', 'SYSTEM', 'account_balance_wallet_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Tuition Fee', 'TUITION_FEE', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Transport Fee', 'TRANSPORT_FEE', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Admission Fee', 'ADMISSION_FEE', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Examination Fee', 'EXAMINATION_FEE', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Library Fee', 'LIBRARY_FEE', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Laboratory Fee', 'LABORATORY_FEE', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'Development Fee', 'DEVELOPMENT_FEE', 'ACTIVE', 7, admin_id),
                    (v_key_id, s.id, 'Sports Fee', 'SPORTS_FEE', 'ACTIVE', 8, admin_id),
                    (v_key_id, s.id, 'Hostel Fee', 'HOSTEL_FEE', 'ACTIVE', 9, admin_id),
                    (v_key_id, s.id, 'Annual Miscellaneous Fee', 'MISCELLANEOUS_FEE', 'ACTIVE', 10, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 9. TRANSPORT_ROUTE_TYPE
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Transport Route Type', 'TRANSPORT_ROUTE_TYPE', 'Classification for transit schedules and routes.', 'CUSTOM', 'alt_route_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Morning Pickup', 'MORNING_PICKUP', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Afternoon Drop', 'AFTERNOON_DROP', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Special Event Transit', 'SPECIAL_TRANSIT', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Excursion Route', 'EXCURSION_ROUTE', 'ACTIVE', 4, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 10. PRIORITY_LEVEL
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Priority Level', 'PRIORITY_LEVEL', 'System-wide priority tiers for tickets, notices, and tasks.', 'SYSTEM', 'flag_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Low', 'LOW', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Normal', 'NORMAL', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'High', 'HIGH', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Urgent / Critical', 'URGENT', 'ACTIVE', 4, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

        END IF;
    END LOOP;
END $$;
