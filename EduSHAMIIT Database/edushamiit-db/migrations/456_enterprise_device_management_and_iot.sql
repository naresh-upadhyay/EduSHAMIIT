-- Migration 456: Enterprise Universal Device Management & IoT System
-- EduSHAMIIT Multi-Tenant Campus Management

CREATE TABLE IF NOT EXISTS device_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) NOT NULL,
    icon VARCHAR(100) DEFAULT 'devices',
    color VARCHAR(30) DEFAULT '#2563EB',
    description TEXT,
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_device_cat_school_code UNIQUE (school_id, code)
);

CREATE TABLE IF NOT EXISTS device_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    category_id UUID REFERENCES device_categories(id) ON DELETE SET NULL,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) NOT NULL,
    protocol VARCHAR(50) DEFAULT 'MQTT',
    icon VARCHAR(100) DEFAULT 'power',
    color VARCHAR(30) DEFAULT '#2563EB',
    default_capabilities JSONB DEFAULT '[]'::jsonb,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_device_type_school_code UNIQUE (school_id, code)
);

CREATE TABLE IF NOT EXISTS device_capabilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    capability_type VARCHAR(50) NOT NULL, -- power, level, temperature, mode, fan_speed, av_input, volume, lock_state, custom
    data_type VARCHAR(30) DEFAULT 'number', -- boolean, number, string, object
    min_value NUMERIC,
    max_value NUMERIC,
    step NUMERIC DEFAULT 1,
    unit VARCHAR(20),
    allowed_values JSONB DEFAULT '[]'::jsonb,
    schema JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_device_cap_school_code UNIQUE (school_id, code)
);

CREATE TABLE IF NOT EXISTS device_type_capabilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_type_id UUID NOT NULL REFERENCES device_types(id) ON DELETE CASCADE,
    capability_id UUID NOT NULL REFERENCES device_capabilities(id) ON DELETE CASCADE,
    is_required BOOLEAN DEFAULT FALSE,
    default_value JSONB DEFAULT '{}'::jsonb,
    CONSTRAINT uq_dev_type_cap UNIQUE (device_type_id, capability_id)
);

CREATE TABLE IF NOT EXISTS devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    campus_id UUID,
    building_id UUID REFERENCES buildings(id) ON DELETE SET NULL,
    floor_id UUID REFERENCES building_floors(id) ON DELETE SET NULL,
    room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
    device_type_id UUID REFERENCES device_types(id) ON DELETE SET NULL,
    device_name VARCHAR(150) NOT NULL,
    device_code VARCHAR(100) NOT NULL,
    ip_address VARCHAR(50),
    mac_address VARCHAR(50),
    mqtt_topic VARCHAR(255),
    mqtt_client_id VARCHAR(100),
    serial_number VARCHAR(100),
    firmware_version VARCHAR(50),
    vendor VARCHAR(100),
    installation_date DATE,
    last_heartbeat_at TIMESTAMPTZ,
    is_online BOOLEAN DEFAULT TRUE,
    power_state BOOLEAN DEFAULT TRUE,
    current_state JSONB DEFAULT '{}'::jsonb,
    operational_status VARCHAR(50) DEFAULT 'operational', -- operational, maintenance, fault, offline
    energy_rating VARCHAR(20),
    rated_power_watts NUMERIC DEFAULT 0,
    notes TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_by UUID,
    updated_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_devices_school_code UNIQUE (school_id, device_code)
);

CREATE TABLE IF NOT EXISTS device_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) NOT NULL,
    description TEXT,
    group_type VARCHAR(50) DEFAULT 'custom', -- room, floor, building, functional, custom
    icon VARCHAR(100) DEFAULT 'group',
    color VARCHAR(30) DEFAULT '#2563EB',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_device_group_school_code UNIQUE (school_id, code)
);

CREATE TABLE IF NOT EXISTS device_group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES device_groups(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_group_device UNIQUE (group_id, device_id)
);

CREATE TABLE IF NOT EXISTS device_commands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    command_type VARCHAR(100) NOT NULL,
    payload JSONB DEFAULT '{}'::jsonb,
    status VARCHAR(50) DEFAULT 'sent', -- pending, sent, acknowledged, failed
    mqtt_message_id VARCHAR(100),
    correlation_id VARCHAR(100),
    executed_by UUID,
    executed_at TIMESTAMPTZ DEFAULT NOW(),
    acknowledged_at TIMESTAMPTZ,
    response_payload JSONB,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS device_telemetry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    metric_name VARCHAR(50) NOT NULL,
    metric_value NUMERIC NOT NULL,
    unit VARCHAR(20),
    recorded_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS device_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    device_id UUID REFERENCES devices(id) ON DELETE SET NULL,
    alert_type VARCHAR(50) NOT NULL,
    severity VARCHAR(30) DEFAULT 'warning', -- critical, high, warning, info
    title VARCHAR(200) NOT NULL,
    description TEXT,
    is_resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS device_automation_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    trigger_type VARCHAR(50) NOT NULL, -- schedule, occupancy, threshold, manual
    trigger_condition JSONB DEFAULT '{}'::jsonb,
    action_payload JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN DEFAULT TRUE,
    execution_count INT DEFAULT 0,
    last_triggered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS device_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    days_of_week INT[] DEFAULT '{1,2,3,4,5}',
    start_time TIME NOT NULL,
    end_time TIME,
    target_type VARCHAR(50) DEFAULT 'device', -- device, group, scene
    target_id UUID,
    action_payload JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS device_scenes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) NOT NULL,
    description TEXT,
    icon VARCHAR(100) DEFAULT 'auto_awesome',
    color VARCHAR(30) DEFAULT '#2563EB',
    is_preset BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE,
    last_applied_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_device_scene_school_code UNIQUE (school_id, code)
);

CREATE TABLE IF NOT EXISTS device_scene_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scene_id UUID NOT NULL REFERENCES device_scenes(id) ON DELETE CASCADE,
    device_id UUID REFERENCES devices(id) ON DELETE CASCADE,
    group_id UUID REFERENCES device_groups(id) ON DELETE CASCADE,
    target_type VARCHAR(30) DEFAULT 'device', -- device, group
    capability_code VARCHAR(50) NOT NULL,
    target_value JSONB NOT NULL,
    execution_order INT DEFAULT 1,
    delay_ms INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_devices_school_id ON devices(school_id);
CREATE INDEX IF NOT EXISTS idx_devices_building_floor_room ON devices(building_id, floor_id, room_id);
CREATE INDEX IF NOT EXISTS idx_devices_type ON devices(device_type_id);
CREATE INDEX IF NOT EXISTS idx_devices_status ON devices(is_online, operational_status);
CREATE INDEX IF NOT EXISTS idx_device_commands_device ON device_commands(device_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_device_telemetry_device_metric ON device_telemetry(device_id, metric_name, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_device_alerts_school ON device_alerts(school_id, is_resolved, created_at DESC);
