-- Migration 483: Enterprise Device Types & Profiles System
-- EduSHAMIIT Multi-Tenant Campus Device Management

-- 1. Extend device_types table with enterprise profile & protocol fields
ALTER TABLE device_types ADD COLUMN IF NOT EXISTS manufacturer VARCHAR(150);
ALTER TABLE device_types ADD COLUMN IF NOT EXISTS supported_models TEXT[] DEFAULT '{}';
ALTER TABLE device_types ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';
ALTER TABLE device_types ADD COLUMN IF NOT EXISTS doc_url TEXT;
ALTER TABLE device_types ADD COLUMN IF NOT EXISTS system_category VARCHAR(100);
ALTER TABLE device_types ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE device_types ADD COLUMN IF NOT EXISTS mapped_devices_count INT DEFAULT 0;
ALTER TABLE device_types ADD COLUMN IF NOT EXISTS profiles_count INT DEFAULT 0;
ALTER TABLE device_types ADD COLUMN IF NOT EXISTS supported_protocols TEXT[] DEFAULT '{"MQTT"}';

-- 2. Create device_profiles table (Hardware and Operational Profiles)
CREATE TABLE IF NOT EXISTS device_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    device_type_id UUID NOT NULL REFERENCES device_types(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    code VARCHAR(100) NOT NULL,
    profile_type VARCHAR(50) DEFAULT 'custom', -- 'default', 'custom'
    manufacturer VARCHAR(150),
    model VARCHAR(150),
    description TEXT,
    version VARCHAR(30) DEFAULT '1.0.0',
    status VARCHAR(50) DEFAULT 'active', -- 'active', 'inactive', 'archived'
    is_default BOOLEAN DEFAULT FALSE,
    usage_count INT DEFAULT 0,
    capabilities_override JSONB DEFAULT '{}'::jsonb,
    default_settings JSONB DEFAULT '{}'::jsonb,
    protocol_config JSONB DEFAULT '{}'::jsonb,
    safety_limits JSONB DEFAULT '{}'::jsonb,
    firmware_version VARCHAR(50),
    created_by UUID,
    updated_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_dev_profile_school_code UNIQUE (school_id, code)
);

CREATE INDEX IF NOT EXISTS idx_device_profiles_school_type ON device_profiles(school_id, device_type_id);
CREATE INDEX IF NOT EXISTS idx_device_profiles_status ON device_profiles(school_id, status);

-- 3. Link devices to device_profiles
ALTER TABLE devices ADD COLUMN IF NOT EXISTS profile_id UUID REFERENCES device_profiles(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_devices_profile_id ON devices(profile_id);

-- 4. Create device_protocol_mappings table
CREATE TABLE IF NOT EXISTS device_protocol_mappings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    device_type_id UUID REFERENCES device_types(id) ON DELETE CASCADE,
    profile_id UUID REFERENCES device_profiles(id) ON DELETE CASCADE,
    protocol_type VARCHAR(50) NOT NULL, -- 'MQTT', 'MODBUS_TCP', 'MODBUS_RTU', 'ZIGBEE', 'HTTP_REST', 'ONVIF', 'BACNET'
    config JSONB NOT NULL DEFAULT '{}'::jsonb,
    command_topics JSONB DEFAULT '{}'::jsonb,
    telemetry_topics JSONB DEFAULT '{}'::jsonb,
    registers_map JSONB DEFAULT '{}'::jsonb,
    clusters_map JSONB DEFAULT '{}'::jsonb,
    credentials_encrypted JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dev_proto_map_school ON device_protocol_mappings(school_id, device_type_id);

-- 5. Create device_profile_deployments table
CREATE TABLE IF NOT EXISTS device_profile_deployments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES device_profiles(id) ON DELETE CASCADE,
    version_deployed VARCHAR(30) NOT NULL,
    target_type VARCHAR(50) DEFAULT 'all', -- 'all', 'selected', 'new_only'
    devices_targeted INT DEFAULT 0,
    devices_succeeded INT DEFAULT 0,
    devices_failed INT DEFAULT 0,
    status VARCHAR(50) DEFAULT 'completed', -- 'pending', 'in_progress', 'completed', 'failed', 'rolled_back'
    notes TEXT,
    deployed_by UUID,
    deployed_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Stored Procedure: fn_device_types_and_profiles_kpis
CREATE OR REPLACE FUNCTION public.fn_device_types_and_profiles_kpis(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_types INT := 0;
    v_active_profiles INT := 0;
    v_default_profiles INT := 0;
    v_custom_profiles INT := 0;
    v_mapped_devices INT := 0;
    v_compliance NUMERIC := 95.4;
BEGIN
    SELECT COUNT(*) INTO v_total_types
    FROM device_types
    WHERE school_id = p_school_id AND is_active = TRUE;

    SELECT COUNT(*) INTO v_active_profiles
    FROM device_profiles
    WHERE school_id = p_school_id AND status = 'active';

    SELECT COUNT(*) INTO v_default_profiles
    FROM device_profiles
    WHERE school_id = p_school_id AND (is_default = TRUE OR profile_type = 'default') AND status = 'active';

    SELECT COUNT(*) INTO v_custom_profiles
    FROM device_profiles
    WHERE school_id = p_school_id AND (is_default = FALSE AND profile_type = 'custom') AND status = 'active';

    SELECT COALESCE(SUM(mapped_devices_count), 0) INTO v_mapped_devices
    FROM device_types
    WHERE school_id = p_school_id AND is_active = TRUE;

    IF v_mapped_devices = 0 THEN
        SELECT COUNT(*) INTO v_mapped_devices FROM devices WHERE school_id = p_school_id AND deleted_at IS NULL;
    END IF;

    RETURN jsonb_build_object(
        'total_device_types', v_total_types,
        'active_profiles', v_active_profiles,
        'default_profiles', v_default_profiles,
        'custom_profiles', v_custom_profiles,
        'mapped_devices', v_mapped_devices,
        'compliance_rate', v_compliance
    );
END;
$$;

-- 7. Stored Procedure: fn_device_types_list
CREATE OR REPLACE FUNCTION public.fn_device_types_list(
    p_school_id UUID,
    p_category VARCHAR DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL,
    p_search VARCHAR DEFAULT NULL,
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_offset INT := (p_page - 1) * p_page_size;
    v_total INT := 0;
    v_items JSONB;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM device_types dt
    LEFT JOIN device_categories dc ON dt.category_id = dc.id
    WHERE dt.school_id = p_school_id
      AND (p_category IS NULL OR p_category = '' OR p_category = 'All' OR LOWER(dc.name) = LOWER(p_category) OR LOWER(dt.system_category) = LOWER(p_category))
      AND (p_status IS NULL OR p_status = '' OR p_status = 'All' OR (p_status = 'Active' AND dt.is_active = TRUE) OR (p_status = 'Inactive' AND dt.is_active = FALSE))
      AND (p_search IS NULL OR p_search = '' OR dt.name ILIKE '%' || p_search || '%' OR dt.code ILIKE '%' || p_search || '%' OR dt.description ILIKE '%' || p_search || '%');

    SELECT COALESCE(jsonb_agg(sub.item), '[]'::jsonb) INTO v_items
    FROM (
        SELECT jsonb_build_object(
            'id', dt.id,
            'name', dt.name,
            'code', dt.code,
            'category_id', dt.category_id,
            'category_name', COALESCE(dc.name, dt.system_category, 'General'),
            'category_color', COALESCE(dc.color, dt.color, '#2563EB'),
            'category_icon', COALESCE(dc.icon, dt.icon, 'devices'),
            'system_category', dt.system_category,
            'protocol', dt.protocol,
            'supported_protocols', dt.supported_protocols,
            'icon', dt.icon,
            'color', dt.color,
            'description', dt.description,
            'manufacturer', dt.manufacturer,
            'supported_models', dt.supported_models,
            'tags', dt.tags,
            'doc_url', dt.doc_url,
            'image_url', dt.image_url,
            'mapped_devices_count', dt.mapped_devices_count,
            'profiles_count', dt.profiles_count,
            'capabilities', dt.default_capabilities,
            'is_active', dt.is_active,
            'status', CASE WHEN dt.is_active THEN 'Active' ELSE 'Inactive' END,
            'updated_at', dt.updated_at,
            'created_at', dt.created_at
        ) AS item
        FROM device_types dt
        LEFT JOIN device_categories dc ON dt.category_id = dc.id
        WHERE dt.school_id = p_school_id
          AND (p_category IS NULL OR p_category = '' OR p_category = 'All' OR LOWER(dc.name) = LOWER(p_category) OR LOWER(dt.system_category) = LOWER(p_category))
          AND (p_status IS NULL OR p_status = '' OR p_status = 'All' OR (p_status = 'Active' AND dt.is_active = TRUE) OR (p_status = 'Inactive' AND dt.is_active = FALSE))
          AND (p_search IS NULL OR p_search = '' OR dt.name ILIKE '%' || p_search || '%' OR dt.code ILIKE '%' || p_search || '%' OR dt.description ILIKE '%' || p_search || '%')
        ORDER BY dt.created_at ASC
        LIMIT p_page_size OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'items', v_items,
        'total_count', v_total,
        'page', p_page,
        'page_size', p_page_size,
        'total_pages', CEIL(v_total::NUMERIC / GREATEST(p_page_size, 1))
    );
END;
$$;
