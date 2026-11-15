-- Migration: 497_enterprise_device_health_diagnostics_system.sql
-- Description: Comprehensive Device Health & Diagnostics System for EduSHAMIIT ERP
-- Tracks device health, heartbeats, diagnostic sessions & results, health rules, 
-- IoT gateways, recovery operations, alerts, and 30-day trends.

BEGIN;

-- 1. Extend public.devices with health, uptime, latency, and gateway fields
ALTER TABLE public.devices 
ADD COLUMN IF NOT EXISTS health_status VARCHAR(30) DEFAULT 'healthy',
ADD COLUMN IF NOT EXISTS uptime_pct NUMERIC(5,2) DEFAULT 99.5,
ADD COLUMN IF NOT EXISTS response_latency_ms INT DEFAULT 45,
ADD COLUMN IF NOT EXISTS active_issues_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_diagnostic_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS gateway_id UUID,
ADD COLUMN IF NOT EXISTS current_issue TEXT;

CREATE INDEX IF NOT EXISTS idx_devices_health_status ON public.devices (school_id, health_status);
CREATE INDEX IF NOT EXISTS idx_devices_gateway_id ON public.devices (gateway_id);

-- 2. Create campus_iot_gateways table
CREATE TABLE IF NOT EXISTS public.campus_iot_gateways (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    gateway_code VARCHAR(100) NOT NULL,
    gateway_name VARCHAR(150) NOT NULL,
    gateway_type VARCHAR(50) NOT NULL DEFAULT 'mqtt',
    ip_address VARCHAR(50),
    mac_address VARCHAR(50),
    protocol VARCHAR(50) DEFAULT 'mqtt',
    building_id UUID REFERENCES buildings(id) ON DELETE SET NULL,
    floor_id UUID REFERENCES building_floors(id) ON DELETE SET NULL,
    room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
    location_path VARCHAR(200),
    status VARCHAR(30) DEFAULT 'online',
    is_online BOOLEAN DEFAULT true,
    last_heartbeat_at TIMESTAMPTZ DEFAULT now(),
    connected_devices_count INT DEFAULT 0,
    cpu_usage_pct NUMERIC(5,2) DEFAULT 18.5,
    memory_usage_pct NUMERIC(5,2) DEFAULT 42.0,
    temperature_celsius NUMERIC(5,2) DEFAULT 41.5,
    uptime_seconds BIGINT DEFAULT 3628800,
    firmware_version VARCHAR(50) DEFAULT 'v3.2.0',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT uq_campus_gateways_school_code UNIQUE (school_id, gateway_code)
);

CREATE INDEX IF NOT EXISTS idx_campus_gateways_school_status ON public.campus_iot_gateways (school_id, status);

-- Add foreign key constraint from devices to campus_iot_gateways
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'devices_gateway_id_fkey'
    ) THEN
        ALTER TABLE public.devices 
        ADD CONSTRAINT devices_gateway_id_fkey 
        FOREIGN KEY (gateway_id) REFERENCES public.campus_iot_gateways(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 3. Extend public.device_alerts with rich categorization and tracking
ALTER TABLE public.device_alerts
ADD COLUMN IF NOT EXISTS alert_category VARCHAR(50) DEFAULT 'connectivity',
ADD COLUMN IF NOT EXISTS status VARCHAR(30) DEFAULT 'new',
ADD COLUMN IF NOT EXISTS actual_reading VARCHAR(100),
ADD COLUMN IF NOT EXISTS expected_threshold VARCHAR(100),
ADD COLUMN IF NOT EXISTS last_occurrence_at TIMESTAMPTZ DEFAULT now(),
ADD COLUMN IF NOT EXISTS occurrence_count INT DEFAULT 1,
ADD COLUMN IF NOT EXISTS assigned_to_name VARCHAR(150),
ADD COLUMN IF NOT EXISTS notes JSONB DEFAULT '[]',
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_device_alerts_category_status ON public.device_alerts (school_id, alert_category, status);

-- 4. Create device_diagnostic_sessions table
CREATE TABLE IF NOT EXISTS public.device_diagnostic_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    session_code VARCHAR(100) NOT NULL,
    device_id UUID REFERENCES devices(id) ON DELETE CASCADE,
    gateway_id UUID REFERENCES campus_iot_gateways(id) ON DELETE SET NULL,
    session_type VARCHAR(50) DEFAULT 'single_device', -- single_device, bulk_devices, system_wide, gateway
    status VARCHAR(30) DEFAULT 'completed', -- queued, running, completed, warning, failed, cancelled
    overall_result VARCHAR(30) DEFAULT 'passed', -- passed, warning, failed, partial
    initiated_by_name VARCHAR(150) DEFAULT 'Admin',
    total_tests INT DEFAULT 0,
    passed_tests INT DEFAULT 0,
    warning_tests INT DEFAULT 0,
    failed_tests INT DEFAULT 0,
    skipped_tests INT DEFAULT 0,
    duration_ms INT DEFAULT 0,
    started_at TIMESTAMPTZ DEFAULT now(),
    completed_at TIMESTAMPTZ DEFAULT now(),
    summary_notes TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT uq_diagnostic_sessions_school_code UNIQUE (school_id, session_code)
);

CREATE INDEX IF NOT EXISTS idx_diagnostic_sessions_device ON public.device_diagnostic_sessions (device_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_diagnostic_sessions_school ON public.device_diagnostic_sessions (school_id, status);

-- 5. Create device_diagnostic_results table
CREATE TABLE IF NOT EXISTS public.device_diagnostic_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES device_diagnostic_sessions(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    test_code VARCHAR(100) NOT NULL,
    test_name VARCHAR(150) NOT NULL,
    test_category VARCHAR(50) NOT NULL, -- connectivity, hardware, telemetry, firmware, environmental
    status VARCHAR(30) NOT NULL, -- passed, warning, failed, skipped, unsupported, timed_out
    actual_value VARCHAR(255),
    expected_value VARCHAR(255),
    unit VARCHAR(30),
    duration_ms INT DEFAULT 0,
    error_code VARCHAR(50),
    error_message TEXT,
    recommended_action TEXT,
    executed_at TIMESTAMPTZ DEFAULT now(),
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_diagnostic_results_session ON public.device_diagnostic_results (session_id);
CREATE INDEX IF NOT EXISTS idx_diagnostic_results_device ON public.device_diagnostic_results (device_id, test_code);

-- 6. Create device_health_rules table
CREATE TABLE IF NOT EXISTS public.device_health_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    rule_name VARCHAR(150) NOT NULL,
    rule_code VARCHAR(100) NOT NULL,
    scope_type VARCHAR(50) NOT NULL DEFAULT 'global', -- global, device_type, device_group, location, device
    scope_name VARCHAR(150) DEFAULT 'Campus Wide',
    metric_name VARCHAR(100) NOT NULL,
    operator VARCHAR(20) NOT NULL, -- >, <, >=, <=, ==, !=, between, missing_for
    threshold_value NUMERIC(10,2) NOT NULL,
    threshold_secondary NUMERIC(10,2),
    duration_seconds INT DEFAULT 60,
    severity VARCHAR(30) NOT NULL DEFAULT 'warning', -- critical, high, warning, low, info
    is_active BOOLEAN DEFAULT true,
    trigger_count INT DEFAULT 0,
    last_triggered_at TIMESTAMPTZ,
    auto_resolve BOOLEAN DEFAULT true,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT uq_health_rules_school_code UNIQUE (school_id, rule_code)
);

CREATE INDEX IF NOT EXISTS idx_health_rules_school_active ON public.device_health_rules (school_id, is_active);

-- 7. Create device_recovery_operations table
CREATE TABLE IF NOT EXISTS public.device_recovery_operations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    operation_code VARCHAR(100) NOT NULL,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    action_type VARCHAR(50) NOT NULL, -- restart, reconnect, soft_reset, resync_time, clear_error, update_firmware, refresh_config
    status VARCHAR(30) DEFAULT 'executed', -- initiated, published, acknowledged, executed, failed, timed_out
    command_payload JSONB DEFAULT '{}',
    acknowledgement_payload JSONB DEFAULT '{}',
    initiated_by_name VARCHAR(150) DEFAULT 'Admin',
    error_message TEXT,
    initiated_at TIMESTAMPTZ DEFAULT now(),
    completed_at TIMESTAMPTZ DEFAULT now(),
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_recovery_operations_device ON public.device_recovery_operations (device_id, initiated_at DESC);

-- 8. Create device_health_snapshots table (30-day historical trend)
CREATE TABLE IF NOT EXISTS public.device_health_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL,
    total_devices INT NOT NULL DEFAULT 136,
    healthy_count INT NOT NULL DEFAULT 122,
    warning_count INT NOT NULL DEFAULT 8,
    critical_count INT NOT NULL DEFAULT 4,
    offline_count INT NOT NULL DEFAULT 2,
    avg_uptime_pct NUMERIC(5,2) DEFAULT 98.6,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT uq_health_snapshots_date UNIQUE (school_id, snapshot_date)
);

CREATE INDEX IF NOT EXISTS idx_health_snapshots_date ON public.device_health_snapshots (school_id, snapshot_date DESC);

-- 9. Add device_id foreign key to public.maintenance_requests if missing
ALTER TABLE public.maintenance_requests
ADD COLUMN IF NOT EXISTS device_id UUID REFERENCES public.devices(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_maintenance_requests_device_id ON public.maintenance_requests (device_id);

-- Enable RLS & Policies
ALTER TABLE public.campus_iot_gateways ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_diagnostic_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_diagnostic_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_health_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_recovery_operations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_health_snapshots ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Allow all for campus_iot_gateways" ON public.campus_iot_gateways;
    CREATE POLICY "Allow all for campus_iot_gateways" ON public.campus_iot_gateways FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow all for device_diagnostic_sessions" ON public.device_diagnostic_sessions;
    CREATE POLICY "Allow all for device_diagnostic_sessions" ON public.device_diagnostic_sessions FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow all for device_diagnostic_results" ON public.device_diagnostic_results;
    CREATE POLICY "Allow all for device_diagnostic_results" ON public.device_diagnostic_results FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow all for device_health_rules" ON public.device_health_rules;
    CREATE POLICY "Allow all for device_health_rules" ON public.device_health_rules FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow all for device_recovery_operations" ON public.device_recovery_operations;
    CREATE POLICY "Allow all for device_recovery_operations" ON public.device_recovery_operations FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow all for device_health_snapshots" ON public.device_health_snapshots;
    CREATE POLICY "Allow all for device_health_snapshots" ON public.device_health_snapshots FOR ALL USING (true) WITH CHECK (true);
END $$;

-- 10. SEEDING CANONICAL DATA FOR GREENWOOD HIGH SCHOOL
DO $$
DECLARE
    v_school_id UUID := '11111111-1111-1111-1111-111111111111';
    v_gw1 UUID := 'a1000000-0000-0000-0000-000000000001';
    v_gw2 UUID := 'a1000000-0000-0000-0000-000000000002';
    v_gw3 UUID := 'a1000000-0000-0000-0000-000000000003';
    v_gw4 UUID := 'a1000000-0000-0000-0000-000000000004';
    v_gw5 UUID := 'a1000000-0000-0000-0000-000000000005';
    v_b_acad UUID;
    v_b_lab UUID;
    v_b_lib UUID;
    v_b_admin UUID;
    v_dev_proj UUID;
    v_dev_ac1 UUID;
    v_dev_light1 UUID;
    v_dev_fan1 UUID;
    v_dev_display1 UUID;
    v_dev_door1 UUID;
    v_dev_cctv1 UUID;
    v_dev_ac_lab UUID;
    v_dev_light_b1 UUID;
    v_dev_fan_lib UUID;
    v_diag_sess1 UUID := 'b1000000-0000-0000-0000-000000000001';
    v_diag_sess2 UUID := 'b1000000-0000-0000-0000-000000000002';
    v_dt_id UUID;
    v_date DATE;
    i INT;
BEGIN
    SELECT id INTO v_b_acad FROM public.buildings WHERE school_id = v_school_id AND name ILIKE '%Academic%' LIMIT 1;
    SELECT id INTO v_b_lab FROM public.buildings WHERE school_id = v_school_id AND name ILIKE '%Lab%' LIMIT 1;
    SELECT id INTO v_b_lib FROM public.buildings WHERE school_id = v_school_id AND name ILIKE '%Library%' LIMIT 1;
    SELECT id INTO v_b_admin FROM public.buildings WHERE school_id = v_school_id AND name ILIKE '%Admin%' LIMIT 1;

    -- Seed 5 Gateways
    INSERT INTO public.campus_iot_gateways (id, school_id, gateway_code, gateway_name, gateway_type, ip_address, mac_address, protocol, location_path, status, is_online, connected_devices_count, cpu_usage_pct, memory_usage_pct, temperature_celsius, uptime_seconds, firmware_version)
    VALUES
    (v_gw1, v_school_id, 'GW-ADMIN-01', 'Main Campus MQTT Core Gateway', 'mqtt', '192.168.1.10', '00:1A:2B:3C:4D:01', 'mqtt', 'Administration Block > Server Room', 'online', true, 42, 22.4, 45.1, 39.8, 4147200, 'v3.2.0'),
    (v_gw2, v_school_id, 'GW-ACAD-01', 'Academic Block (A) Modbus Substation Bridge', 'modbus_tcp', '192.168.1.11', '00:1A:2B:3C:4D:02', 'modbus_tcp', 'Academic Block (A) > Electrical Room', 'online', true, 38, 16.8, 38.0, 42.1, 3888000, 'v2.8.4'),
    (v_gw3, v_school_id, 'GW-LAB-01', 'Laboratories Smart Sensor Coordinator', 'zigbee', '192.168.1.12', '00:1A:2B:3C:4D:03', 'zigbee', 'Laboratories Block > Server Rack', 'online', true, 26, 19.5, 41.2, 40.5, 3628800, 'v3.1.0'),
    (v_gw4, v_school_id, 'GW-LIB-01', 'Library & Auditorium IoT Gateway', 'mqtt', '192.168.1.13', '00:1A:2B:3C:4D:04', 'mqtt', 'Library Block > Control Center', 'online', true, 18, 14.2, 34.5, 38.2, 4320000, 'v3.2.0'),
    (v_gw5, v_school_id, 'GW-SEC-01', 'Perimeter & Access Control Coordinator', 'mqtt', '192.168.1.14', '00:1A:2B:3C:4D:05', 'mqtt', 'Main Block > Security Terminal', 'online', true, 12, 12.0, 29.8, 37.0, 5184000, 'v3.2.0')
    ON CONFLICT (school_id, gateway_code) DO UPDATE 
    SET status = EXCLUDED.status, is_online = EXCLUDED.is_online, connected_devices_count = EXCLUDED.connected_devices_count;

    -- Seed 6 Enterprise Health Rules
    INSERT INTO public.device_health_rules (school_id, rule_name, rule_code, scope_type, scope_name, metric_name, operator, threshold_value, duration_seconds, severity, is_active, trigger_count)
    VALUES
    (v_school_id, 'Heartbeat Loss & Offline Detection', 'RULE-OFFLINE-01', 'global', 'Campus Wide', 'heartbeat_offline_timeout', '>', 180, 180, 'critical', true, 14),
    (v_school_id, 'High Temperature Alert (Projector & Displays)', 'RULE-TEMP-01', 'device_type', 'Projector & Display', 'max_temperature_celsius', '>', 70, 120, 'warning', true, 5),
    (v_school_id, 'Weak Wi-Fi / Low Signal Warning (RSSI)', 'RULE-SIG-01', 'global', 'Campus Wide', 'signal_strength_rssi', '<', -80, 300, 'warning', true, 8),
    (v_school_id, 'AC / HVAC Operational Voltage Range', 'RULE-VOLT-01', 'device_type', 'AC / HVAC', 'voltage_rms', 'between', 210, 60, 'critical', true, 2),
    (v_school_id, 'Excessive Command Response Latency', 'RULE-LAT-01', 'global', 'Campus Wide', 'response_latency_ms', '>', 500, 60, 'warning', true, 19),
    (v_school_id, 'Door Sensor Low Battery Warning', 'RULE-BAT-01', 'device_type', 'Access Control', 'battery_percentage', '<', 15, 3600, 'warning', true, 3)
    ON CONFLICT (school_id, rule_code) DO NOTHING;

    -- Insert / Update the 10 Canonical Devices from Screenshot
    -- 1. AC Unit (A1-101)
    INSERT INTO public.devices (school_id, device_name, device_code, ip_address, is_online, health_status, uptime_pct, response_latency_ms, current_issue, notes, gateway_id, firmware_version)
    VALUES (v_school_id, 'AC Unit (A1-101)', 'DEV-AC-000101', '192.168.1.101', true, 'healthy', 99.6, 32, '-', 'Academic Block (A) > A1-101', v_gw2, 'v2.1.0')
    ON CONFLICT (school_id, device_code) DO UPDATE 
    SET device_name = EXCLUDED.device_name, health_status = 'healthy', uptime_pct = 99.6, current_issue = '-', is_online = true, notes = 'Academic Block (A) > A1-101'
    RETURNING id INTO v_dev_ac1;

    -- 2. Classroom Lights (A1-102)
    INSERT INTO public.devices (school_id, device_name, device_code, ip_address, is_online, health_status, uptime_pct, response_latency_ms, current_issue, notes, gateway_id, firmware_version)
    VALUES (v_school_id, 'Classroom Lights (A1-102)', 'DEV-LGT-000102', '192.168.1.102', true, 'healthy', 99.2, 28, '-', 'Academic Block (A) > A1-102', v_gw2, 'v1.4.2')
    ON CONFLICT (school_id, device_code) DO UPDATE 
    SET device_name = EXCLUDED.device_name, health_status = 'healthy', uptime_pct = 99.2, current_issue = '-', is_online = true, notes = 'Academic Block (A) > A1-102'
    RETURNING id INTO v_dev_light1;

    -- 3. Projector (A1-102) - Highlighted in screenshot
    INSERT INTO public.devices (school_id, device_name, device_code, ip_address, is_online, health_status, uptime_pct, response_latency_ms, current_issue, notes, gateway_id, firmware_version)
    VALUES (v_school_id, 'Projector (A1-102)', 'DEV-PRJ-000145', '192.168.1.145', true, 'warning', 96.1, 48, 'High temperature (72°C)', 'Academic Block (A) > A1-102', v_gw2, 'v2.4.1')
    ON CONFLICT (school_id, device_code) DO UPDATE 
    SET device_name = EXCLUDED.device_name, health_status = 'warning', uptime_pct = 96.1, current_issue = 'High temperature (72°C)', is_online = true, notes = 'Academic Block (A) > A1-102', firmware_version = 'v2.4.1'
    RETURNING id INTO v_dev_proj;

    -- 4. Ceiling Fan (A1-103)
    INSERT INTO public.devices (school_id, device_name, device_code, ip_address, is_online, health_status, uptime_pct, response_latency_ms, current_issue, notes, gateway_id, firmware_version)
    VALUES (v_school_id, 'Ceiling Fan (A1-103)', 'DEV-FAN-000103', '192.168.1.103', true, 'healthy', 99.8, 22, '-', 'Academic Block (A) > A1-103', v_gw2, 'v1.1.0')
    ON CONFLICT (school_id, device_code) DO UPDATE 
    SET device_name = EXCLUDED.device_name, health_status = 'healthy', uptime_pct = 99.8, current_issue = '-', is_online = true, notes = 'Academic Block (A) > A1-103'
    RETURNING id INTO v_dev_fan1;

    -- 5. Display (A1-104)
    INSERT INTO public.devices (school_id, device_name, device_code, ip_address, is_online, health_status, uptime_pct, response_latency_ms, current_issue, notes, gateway_id, firmware_version)
    VALUES (v_school_id, 'Display (A1-104)', 'DEV-DSP-000104', '192.168.1.104', true, 'critical', 87.4, 520, 'Not responding (timeout)', 'Academic Block (A) > A1-104', v_gw2, 'v2.0.1')
    ON CONFLICT (school_id, device_code) DO UPDATE 
    SET device_name = EXCLUDED.device_name, health_status = 'critical', uptime_pct = 87.4, current_issue = 'Not responding (timeout)', is_online = true, notes = 'Academic Block (A) > A1-104'
    RETURNING id INTO v_dev_display1;

    -- 6. Access Door (Main-A)
    INSERT INTO public.devices (school_id, device_name, device_code, ip_address, is_online, health_status, uptime_pct, response_latency_ms, current_issue, notes, gateway_id, firmware_version)
    VALUES (v_school_id, 'Access Door (Main-A)', 'DEV-DOR-000100', '192.168.1.105', true, 'warning', 95.8, 65, 'Low signal (RSSI -82 dBm)', 'Main Block > Entrance', v_gw5, 'v3.0.4')
    ON CONFLICT (school_id, device_code) DO UPDATE 
    SET device_name = EXCLUDED.device_name, health_status = 'warning', uptime_pct = 95.8, current_issue = 'Low signal (RSSI -82 dBm)', is_online = true, notes = 'Main Block > Entrance'
    RETURNING id INTO v_dev_door1;

    -- 7. CCTV (Corridor-A1)
    INSERT INTO public.devices (school_id, device_name, device_code, ip_address, is_online, health_status, uptime_pct, response_latency_ms, current_issue, notes, gateway_id, firmware_version)
    VALUES (v_school_id, 'CCTV (Corridor-A1)', 'DEV-CAM-000101', '192.168.1.106', true, 'healthy', 99.9, 15, '-', 'Academic Block (A) > Corridor', v_gw1, 'v4.1.2')
    ON CONFLICT (school_id, device_code) DO UPDATE 
    SET device_name = EXCLUDED.device_name, health_status = 'healthy', uptime_pct = 99.9, current_issue = '-', is_online = true, notes = 'Academic Block (A) > Corridor'
    RETURNING id INTO v_dev_cctv1;

    -- 8. AC Unit (Lab-01)
    INSERT INTO public.devices (school_id, device_name, device_code, ip_address, is_online, health_status, uptime_pct, response_latency_ms, current_issue, notes, gateway_id, firmware_version)
    VALUES (v_school_id, 'AC Unit (Lab-01)', 'DEV-AC-000201', '192.168.1.201', false, 'offline', 0.0, 0, 'Device offline (no heartbeat)', 'Laboratory Block (B) > Lab-01', v_gw3, 'v2.1.0')
    ON CONFLICT (school_id, device_code) DO UPDATE 
    SET device_name = EXCLUDED.device_name, health_status = 'offline', uptime_pct = 0.0, current_issue = 'Device offline (no heartbeat)', is_online = false, notes = 'Laboratory Block (B) > Lab-01'
    RETURNING id INTO v_dev_ac_lab;

    -- 9. Classroom Lights (B1-201)
    INSERT INTO public.devices (school_id, device_name, device_code, ip_address, is_online, health_status, uptime_pct, response_latency_ms, current_issue, notes, gateway_id, firmware_version)
    VALUES (v_school_id, 'Classroom Lights (B1-201)', 'DEV-LGT-000201', '192.168.1.202', true, 'healthy', 99.1, 26, '-', 'Academic Block (B) > B1-201', v_gw2, 'v1.4.2')
    ON CONFLICT (school_id, device_code) DO UPDATE 
    SET device_name = EXCLUDED.device_name, health_status = 'healthy', uptime_pct = 99.1, current_issue = '-', is_online = true, notes = 'Academic Block (B) > B1-201'
    RETURNING id INTO v_dev_light_b1;

    -- 10. Fan (Library-01)
    INSERT INTO public.devices (school_id, device_name, device_code, ip_address, is_online, health_status, uptime_pct, response_latency_ms, current_issue, notes, gateway_id, firmware_version)
    VALUES (v_school_id, 'Fan (Library-01)', 'DEV-FAN-000301', '192.168.1.301', true, 'healthy', 99.7, 18, '-', 'Library Block > Reading Hall', v_gw4, 'v1.1.0')
    ON CONFLICT (school_id, device_code) DO UPDATE 
    SET device_name = EXCLUDED.device_name, health_status = 'healthy', uptime_pct = 99.7, current_issue = '-', is_online = true, notes = 'Library Block > Reading Hall'
    RETURNING id INTO v_dev_fan_lib;

    -- Ensure remaining devices are registered to bring total count to 136 devices
    -- (122 healthy, 8 warning, 4 critical, 2 offline)
    FOR i IN 11..136 LOOP
        INSERT INTO public.devices (school_id, device_name, device_code, is_online, health_status, uptime_pct, response_latency_ms, current_issue, notes, gateway_id, firmware_version)
        VALUES (
            v_school_id,
            CASE (i % 7)
                WHEN 0 THEN 'AC Unit (Room ' || (100 + i) || ')'
                WHEN 1 THEN 'Classroom Light Grid ' || i
                WHEN 2 THEN 'Ceiling Fan (Room ' || (100 + i) || ')'
                WHEN 3 THEN 'Classroom Projector ' || i
                WHEN 4 THEN 'Interactive Display ' || i
                WHEN 5 THEN 'Smart Door Controller ' || i
                ELSE 'Security CCTV CAM-' || i
            END,
            'DEV-AUTO-' || LPAD(i::text, 4, '0'),
            CASE WHEN i IN (11, 12) THEN false ELSE true END,
            CASE 
                WHEN i IN (11, 12) THEN 'offline'
                WHEN i IN (13, 14, 15) THEN 'critical'
                WHEN i IN (16, 17, 18, 19, 20, 21) THEN 'warning'
                ELSE 'healthy'
            END,
            CASE WHEN i IN (11, 12) THEN 0.0 ELSE 98.5 + (i % 2) * 0.9 END,
            CASE WHEN i IN (11, 12) THEN 0 ELSE 25 + (i % 30) END,
            CASE 
                WHEN i IN (11, 12) THEN 'Device offline (no heartbeat)'
                WHEN i IN (13, 14, 15) THEN 'Command timeout / response failure'
                WHEN i IN (16, 17, 18, 19, 20, 21) THEN 'High operating temperature or warning threshold'
                ELSE '-'
            END,
            CASE (i % 4)
                WHEN 0 THEN 'Academic Block (A) > Room ' || (100 + i)
                WHEN 1 THEN 'Academic Block (B) > Room ' || (200 + i)
                WHEN 2 THEN 'Library Block > Floor ' || (1 + (i % 2))
                ELSE 'Laboratories Block > Lab ' || (1 + (i % 4))
            END,
            CASE (i % 5)
                WHEN 0 THEN v_gw1
                WHEN 1 THEN v_gw2
                WHEN 2 THEN v_gw3
                WHEN 3 THEN v_gw4
                ELSE v_gw5
            END,
            'v2.4.0'
        )
        ON CONFLICT (school_id, device_code) DO NOTHING;
    END LOOP;

    -- Seed 30-Day Historical Health Snapshots (12 Dec 2024 to 10 Jan 2025)
    FOR i IN 0..29 LOOP
        v_date := ('2024-12-12'::date + (i || ' days')::interval)::date;
        INSERT INTO public.device_health_snapshots (school_id, snapshot_date, total_devices, healthy_count, warning_count, critical_count, offline_count, avg_uptime_pct)
        VALUES (
            v_school_id,
            v_date,
            136,
            120 + (i % 5), -- between 120 and 124
            7 + (i % 3),   -- between 7 and 9
            3 + (i % 2),   -- between 3 and 4
            2,             -- 2 offline
            98.2 + (i * 0.02)
        )
        ON CONFLICT (school_id, snapshot_date) DO UPDATE 
        SET healthy_count = EXCLUDED.healthy_count, warning_count = EXCLUDED.warning_count, critical_count = EXCLUDED.critical_count, offline_count = EXCLUDED.offline_count, avg_uptime_pct = EXCLUDED.avg_uptime_pct;
    END LOOP;

    -- Seed Key Current Alerts (Matching Screenshot Key Alerts)
    INSERT INTO public.device_alerts (school_id, device_id, alert_type, severity, title, description, alert_category, status, actual_reading, expected_threshold, occurrence_count)
    VALUES
    (v_school_id, v_dev_ac_lab, 'device_offline', 'critical', 'Device not responding (Offline)', 'AC Unit (Lab-01) failed to send heartbeat for over 180 seconds.', 'connectivity', 'new', 'Last seen 11:42 AM', 'Timeout: 180s', 2),
    (v_school_id, v_dev_proj, 'high_temperature', 'warning', 'High temperature', 'Projector (A1-102) lamp core temperature reached 72°C.', 'environmental', 'new', '72°C', 'Max: 70°C', 1),
    (v_school_id, v_dev_door1, 'low_signal', 'warning', 'Low signal / connectivity', 'Access Door (Main-A) Wi-Fi RSSI dropped below -80 dBm.', 'connectivity', 'new', '-82 dBm', 'Min: -75 dBm', 3),
    (v_school_id, v_dev_proj, 'firmware_update', 'warning', 'Firmware update available', 'Firmware v2.5.0 available for Projector (A1-102). Current: v2.4.1.', 'firmware', 'new', 'v2.4.1', 'v2.5.0', 6),
    (v_school_id, v_dev_display1, 'diagnostics_recommended', 'info', 'Diagnostics recommended', 'Interactive Display (A1-104) had 4 consecutive command timeout events.', 'hardware', 'new', 'Timeout: 520ms', 'SLA: 150ms', 4)
    ON CONFLICT DO NOTHING;

    -- Seed Diagnostic Sessions & Results for Projector (A1-102)
    INSERT INTO public.device_diagnostic_sessions (id, school_id, session_code, device_id, gateway_id, session_type, status, overall_result, initiated_by_name, total_tests, passed_tests, warning_tests, failed_tests, skipped_tests, duration_ms, started_at, completed_at, summary_notes)
    VALUES
    (v_diag_sess1, v_school_id, 'DIAG-PRJ-20250110-01', v_dev_proj, v_gw2, 'single_device', 'completed', 'warning', 'King Doe (Admin)', 8, 6, 2, 0, 0, 1420, now() - interval '25 minutes', now() - interval '24 minutes', 'Projector connectivity and optics passed. Lamp core temperature warning detected at 72°C. Recommended filter cleaning.')
    ON CONFLICT (school_id, session_code) DO NOTHING;

    INSERT INTO public.device_diagnostic_results (session_id, device_id, test_code, test_name, test_category, status, actual_value, expected_value, unit, duration_ms, recommended_action)
    VALUES
    (v_diag_sess1, v_dev_proj, 'connectivity_ping', 'ICMP / Network Connectivity', 'connectivity', 'passed', '12', '< 50', 'ms', 85, 'None required'),
    (v_diag_sess1, v_dev_proj, 'mqtt_roundtrip', 'MQTT Command & Telemetry Echo', 'connectivity', 'passed', '48', '< 150', 'ms', 120, 'None required'),
    (v_diag_sess1, v_dev_proj, 'temp_lamp_core', 'Lamp Core & Thermal Sensor', 'environmental', 'warning', '72', '< 70', '°C', 190, 'Clean projector dust filter and check intake ventilation.'),
    (v_diag_sess1, v_dev_proj, 'temp_exhaust', 'Exhaust Air Temperature', 'environmental', 'passed', '54', '< 60', '°C', 160, 'Normal airflow detected.'),
    (v_diag_sess1, v_dev_proj, 'firmware_check', 'Firmware Integrity & Version', 'firmware', 'warning', 'v2.4.1', 'v2.5.0', 'version', 210, 'Apply OTA firmware update to v2.5.0.'),
    (v_diag_sess1, v_dev_proj, 'hdmi_edid', 'HDMI 1 & 2 EDID Handshake', 'hardware', 'passed', '1080p@60Hz', 'Valid Signal', 'mode', 240, 'Video processing engine stable.'),
    (v_diag_sess1, v_dev_proj, 'fan_rpm', 'Cooling Fan Tachometer', 'hardware', 'passed', '3450', '> 3000', 'RPM', 185, 'Fan speed within manufacturer tolerance.'),
    (v_diag_sess1, v_dev_proj, 'power_supply_dc', 'Internal DC Rail Regulation', 'hardware', 'passed', '12.05', '12.0 ± 0.5', 'V', 230, 'Power distribution clean.')
    ON CONFLICT DO NOTHING;

    -- Seed Maintenance Request for Projector
    INSERT INTO public.maintenance_requests (school_id, request_code, title, description, request_type, priority, status, location_display, reported_by_name, reported_by_role, device_id, is_preventive)
    VALUES
    (v_school_id, 'MR-PRJ-2025-001', 'Projector Dust Filter Cleaning & Thermal Inspection', 'Automated maintenance request created following thermal warning (72°C) on Projector (A1-102).', 'Electronics', 'Medium', 'Pending', 'Academic Block (A) > A1-102', 'King Doe (Admin)', 'Administrator', v_dev_proj, true)
    ON CONFLICT DO NOTHING;

END $$;

COMMIT;
