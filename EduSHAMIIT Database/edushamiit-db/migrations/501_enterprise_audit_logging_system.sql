-- ============================================================================
-- Migration 501: Enterprise Audit Logging and Activity Monitoring System
-- EduSHAMIIT Campus Management -> Device Management & Control -> Audit Logs
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Main Unified Enterprise Audit Logs Table
CREATE TABLE IF NOT EXISTS public.enterprise_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id VARCHAR(64) UNIQUE NOT NULL,
    correlation_id VARCHAR(128) NOT NULL,
    causation_id VARCHAR(128),
    school_id UUID REFERENCES schools(id) ON DELETE SET NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actor_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    actor_name VARCHAR(128) NOT NULL,
    actor_role VARCHAR(128) DEFAULT 'Administrator',
    event_type VARCHAR(64) NOT NULL,
    event_category VARCHAR(64) NOT NULL,
    action VARCHAR(128) NOT NULL,
    target_type VARCHAR(64) NOT NULL,
    target_name VARCHAR(255) NOT NULL,
    location_name VARCHAR(255) DEFAULT 'Academic Block (A)',
    details TEXT NOT NULL,
    result VARCHAR(32) NOT NULL DEFAULT 'Success',
    source VARCHAR(32) NOT NULL DEFAULT 'Web',
    ip_address VARCHAR(64) DEFAULT '192.168.1.100',
    user_agent TEXT DEFAULT 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    device_code VARCHAR(64),
    previous_state JSONB DEFAULT '{}'::jsonb,
    new_state JSONB DEFAULT '{}'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    hash VARCHAR(128),
    previous_hash VARCHAR(128),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_occurred_at ON public.enterprise_audit_logs (occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_school_occurred ON public.enterprise_audit_logs (school_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_category ON public.enterprise_audit_logs (event_category);
CREATE INDEX IF NOT EXISTS idx_audit_event_type ON public.enterprise_audit_logs (event_type);
CREATE INDEX IF NOT EXISTS idx_audit_actor_name ON public.enterprise_audit_logs (actor_name);
CREATE INDEX IF NOT EXISTS idx_audit_result ON public.enterprise_audit_logs (result);
CREATE INDEX IF NOT EXISTS idx_audit_source ON public.enterprise_audit_logs (source);
CREATE INDEX IF NOT EXISTS idx_audit_target_name ON public.enterprise_audit_logs (target_name);

-- 2. Audit Retention Policies Table
CREATE TABLE IF NOT EXISTS public.enterprise_audit_retention_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES schools(id) ON DELETE SET NULL,
    policy_name VARCHAR(128) NOT NULL,
    category VARCHAR(64) NOT NULL,
    retention_days INT NOT NULL DEFAULT 365,
    auto_archive BOOLEAN NOT NULL DEFAULT TRUE,
    archive_storage VARCHAR(128) DEFAULT 'Cold Storage / S3 Glacier',
    is_immutable BOOLEAN NOT NULL DEFAULT TRUE,
    last_archived_at TIMESTAMPTZ,
    status VARCHAR(32) NOT NULL DEFAULT 'Active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Audit Export Reports Table
CREATE TABLE IF NOT EXISTS public.enterprise_audit_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES schools(id) ON DELETE SET NULL,
    report_title VARCHAR(255) NOT NULL,
    report_type VARCHAR(64) NOT NULL,
    requested_by VARCHAR(128) NOT NULL,
    format VARCHAR(16) NOT NULL DEFAULT 'CSV',
    date_range VARCHAR(64) NOT NULL,
    records_count INT NOT NULL DEFAULT 0,
    file_size VARCHAR(32) NOT NULL DEFAULT '0 KB',
    download_url TEXT,
    status VARCHAR(32) NOT NULL DEFAULT 'Completed',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Audit Metrics Cache / Aggregations Table (For lightning-fast dashboard queries)
CREATE TABLE IF NOT EXISTS public.enterprise_audit_dashboard_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES schools(id) ON DELETE SET NULL,
    total_logs INT NOT NULL DEFAULT 24860,
    device_commands INT NOT NULL DEFAULT 12430,
    access_changes INT NOT NULL DEFAULT 1820,
    configuration_changes INT NOT NULL DEFAULT 3610,
    system_events INT NOT NULL DEFAULT 5720,
    security_events INT NOT NULL DEFAULT 280,
    trend_data JSONB NOT NULL DEFAULT '[]'::jsonb,
    top_activities JSONB NOT NULL DEFAULT '[]'::jsonb,
    user_summary JSONB NOT NULL DEFAULT '[]'::jsonb,
    device_summary JSONB NOT NULL DEFAULT '[]'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- SEED CANONICAL METRICS & AUDIT LOGS
-- ============================================================================

INSERT INTO public.enterprise_audit_dashboard_metrics (
    school_id, total_logs, device_commands, access_changes, configuration_changes, system_events, security_events,
    trend_data, top_activities, user_summary, device_summary, updated_at
)
VALUES (
    '11111111-1111-1111-1111-111111111111',
    24860, 12430, 1820, 3610, 5720, 280,
    '[
        {"date": "12 Dec", "count": 580},
        {"date": "15 Dec", "count": 740},
        {"date": "18 Dec", "count": 690},
        {"date": "21 Dec", "count": 780},
        {"date": "24 Dec", "count": 830},
        {"date": "27 Dec", "count": 760},
        {"date": "30 Dec", "count": 790},
        {"date": "02 Jan", "count": 920},
        {"date": "05 Jan", "count": 840},
        {"date": "08 Jan", "count": 890},
        {"date": "10 Jan", "count": 960}
    ]'::jsonb,
    '[
        {"activity": "Device ON/OFF", "count": 4320, "percentage": 17.4, "color": "0xFF2563EB"},
        {"activity": "Parameter Change", "count": 3210, "percentage": 12.9, "color": "0xFF0284C7"},
        {"activity": "Scene / Preset Run", "count": 1980, "percentage": 8.0, "color": "0xFF0D9488"},
        {"activity": "Schedule Execution", "count": 1650, "percentage": 6.6, "color": "0xFF7C3AED"},
        {"activity": "User Login / Logout", "count": 1420, "percentage": 5.7, "color": "0xFFD97706"}
    ]'::jsonb,
    '[
        {"user": "Admin", "role": "Super Admin", "operations": 10480, "success_rate": 99.4, "last_active": "10 Jan 2025, 02:18 PM"},
        {"user": "Vikas Singh", "role": "View Only", "operations": 4120, "success_rate": 99.8, "last_active": "10 Jan 2025, 01:40 PM"},
        {"user": "Neha Kapoor", "role": "Maintenance Staff", "operations": 3650, "success_rate": 98.7, "last_active": "10 Jan 2025, 02:10 PM"},
        {"user": "Rohan Mehta", "role": "Teacher", "operations": 2890, "success_rate": 99.1, "last_active": "10 Jan 2025, 02:16 PM"},
        {"user": "Priya Verma", "role": "Facility Manager", "operations": 2300, "success_rate": 100.0, "last_active": "10 Jan 2025, 02:17 PM"},
        {"user": "System", "role": "Automated Engine", "operations": 1420, "success_rate": 100.0, "last_active": "10 Jan 2025, 02:15 PM"}
    ]'::jsonb,
    '[
        {"category": "AC / HVAC Units", "commands": 6420, "success_rate": 99.2, "status": "Healthy", "online_devices": "24/26"},
        {"category": "Classroom Lighting", "commands": 4110, "success_rate": 99.8, "status": "Healthy", "online_devices": "36/40"},
        {"category": "Projectors & Displays", "commands": 1900, "success_rate": 97.4, "status": "Warning", "online_devices": "20/23"},
        {"category": "IoT Gateways & Hubs", "commands": 820, "success_rate": 100.0, "status": "Healthy", "online_devices": "7/8"}
    ]'::jsonb,
    NOW()
)
ON CONFLICT DO NOTHING;

-- Seed Retention Policies
INSERT INTO public.enterprise_audit_retention_policies (school_id, policy_name, category, retention_days, auto_archive, archive_storage, is_immutable, status)
VALUES
('11111111-1111-1111-1111-111111111111', 'Device Commands Retention', 'Device Command', 180, TRUE, 'Cold S3 Storage / Glacier', TRUE, 'Active'),
('11111111-1111-1111-1111-111111111111', 'Access & Security Compliance', 'Access & Permissions', 730, TRUE, 'Immutable WORM Storage (SOC2/ISO27001)', TRUE, 'Active'),
('11111111-1111-1111-1111-111111111111', 'Hardware Configuration History', 'Configuration Changes', 365, TRUE, 'Encrypted Institutional Archive', TRUE, 'Active'),
('11111111-1111-1111-1111-111111111111', 'Automation & Schedule Logs', 'Automation & Schedules', 90, TRUE, 'Standard Cold Storage', FALSE, 'Active'),
('11111111-1111-1111-1111-111111111111', 'System & Broker Event Trail', 'System Events', 120, TRUE, 'Compressed Syslog Storage', FALSE, 'Active'),
('11111111-1111-1111-1111-111111111111', 'Critical Security Audit Trail', 'Security & Alerts', 2555, TRUE, 'Immutable Blockchain-Anchored Vault', TRUE, 'Active')
ON CONFLICT DO NOTHING;

-- Seed Sample Reports
INSERT INTO public.enterprise_audit_reports (school_id, report_title, report_type, requested_by, format, date_range, records_count, file_size, status)
VALUES
('11111111-1111-1111-1111-111111111111', 'Monthly Device Control Audit Trail', 'Device Operations', 'Admin', 'PDF', '01 Dec 2024 - 31 Dec 2024', 12430, '4.2 MB', 'Completed'),
('11111111-1111-1111-1111-111111111111', 'Security & Access Permissions Review', 'Security Audit', 'Admin', 'XLSX', '01 Jan 2025 - 10 Jan 2025', 1820, '840 KB', 'Completed'),
('11111111-1111-1111-1111-111111111111', 'IoT Gateway Configuration Log', 'Configuration Changes', 'Rohan Mehta', 'CSV', '04 Jan 2025 - 10 Jan 2025', 3610, '1.1 MB', 'Completed')
ON CONFLICT DO NOTHING;

-- Seed the 10 Canonical Audit Entries Matching Screenshot Exactly
DELETE FROM public.enterprise_audit_logs WHERE event_id LIKE 'EVT-20250110-%';

INSERT INTO public.enterprise_audit_logs (
    event_id, correlation_id, causation_id, school_id, occurred_at, actor_name, actor_role,
    event_type, event_category, action, target_type, target_name, location_name,
    details, result, source, ip_address, device_code, previous_state, new_state, metadata, hash
)
VALUES
(
    'EVT-20250110-00010',
    'corr-cmd-ac-001',
    'user-click-live-control',
    '11111111-1111-1111-1111-111111111111',
    '2025-01-10 14:18:27+05:30',
    'Admin',
    'Super Admin',
    'Device Command',
    'device_command',
    'Turn ON',
    'device',
    'AC Unit (A1-101)',
    'Academic Block (A) > Room 101',
    'Mode: Cool, Temp: 24°C',
    'Success',
    'Web',
    '192.168.1.100',
    'DEV-AC-00101',
    '{"power": "off"}'::jsonb,
    '{"power": "on", "mode": "cool", "temperature": 24, "fan": "auto"}'::jsonb,
    '{"mqtt_topic": "edushamiit/campus/academic/a101/ac/set", "qos": 1, "ack_latency_ms": 42}'::jsonb,
    encode(digest('EVT-20250110-00010-hash', 'sha256'), 'hex')
),
(
    'EVT-20250110-00009',
    'corr-perm-grant-002',
    'user-role-assignment',
    '11111111-1111-1111-1111-111111111111',
    '2025-01-10 14:17:05+05:30',
    'Priya Verma',
    'Facility Manager',
    'Access Change',
    'access_change',
    'Grant Access',
    'device_group',
    'Device Group (Classroom AC)',
    'Academic Block (A)',
    'Role: Facility Manager',
    'Success',
    'Web',
    '192.168.1.105',
    NULL,
    '{"role": "view_only"}'::jsonb,
    '{"role": "facility_manager", "permissions": ["device.control", "scene.execute"]}'::jsonb,
    '{"granted_by": "priya.verma@schoolerp.com", "scope": "Academic Block (A)"}'::jsonb,
    encode(digest('EVT-20250110-00009-hash', 'sha256'), 'hex')
),
(
    'EVT-20250110-00008',
    'corr-cfg-gw-003',
    'gateway-config-update',
    '11111111-1111-1111-1111-111111111111',
    '2025-01-10 14:16:42+05:30',
    'Rohan Mehta',
    'Teacher',
    'Configuration',
    'configuration',
    'Update Configuration',
    'gateway',
    'Gateway (GW-A01)',
    'Main Block',
    'Heartbeat: 30s → 15s',
    'Success',
    'Web',
    '192.168.1.112',
    'GW-0001',
    '{"heartbeat_interval_sec": 30}'::jsonb,
    '{"heartbeat_interval_sec": 15}'::jsonb,
    '{"protocol": "Modbus TCP/MQTT", "firmware": "v2.3.1"}'::jsonb,
    encode(digest('EVT-20250110-00008-hash', 'sha256'), 'hex')
),
(
    'EVT-20250110-00007',
    'corr-sched-class-start-004',
    'cron-schedule-dispatcher',
    '11111111-1111-1111-1111-111111111111',
    '2025-01-10 14:15:28+05:30',
    'System',
    'Automated Engine',
    'Schedule',
    'schedule',
    'Schedule Executed',
    'scene',
    'Scene: Class Start',
    'Academic Block (A) > Room 101',
    'Location: A-101',
    'Success',
    'Scheduler',
    '127.0.0.1',
    NULL,
    '{"scene_state": "idle"}'::jsonb,
    '{"scene_state": "running", "steps_executed": 5}'::jsonb,
    '{"schedule_id": "SCH-001", "targets_count": 8, "execution_time_ms": 115}'::jsonb,
    encode(digest('EVT-20250110-00007-hash', 'sha256'), 'hex')
),
(
    'EVT-20250110-00006',
    'corr-cmd-prj-005',
    'mobile-app-remote-control',
    '11111111-1111-1111-1111-111111111111',
    '2025-01-10 14:10:11+05:30',
    'Neha Kapoor',
    'Maintenance Staff',
    'Device Command',
    'device_command',
    'Set Parameter',
    'device',
    'Projector (A1-102)',
    'Academic Block (A) > Room 102',
    'Input: HDMI, Brightness: 80%',
    'Success',
    'Mobile',
    '192.168.2.45',
    'DEV-PRJ-000145',
    '{"input": "VGA", "brightness": 60}'::jsonb,
    '{"input": "HDMI 1", "brightness": 80}'::jsonb,
    '{"app_version": "v3.2.0-flutter-android", "device_model": "Epson EB-2250U"}'::jsonb,
    encode(digest('EVT-20250110-00006-hash', 'sha256'), 'hex')
),
(
    'EVT-20250110-00005',
    'corr-sec-login-006',
    'auth-service-login-failed',
    '11111111-1111-1111-1111-111111111111',
    '2025-01-10 13:56:32+05:30',
    'Admin',
    'Super Admin',
    'Security Event',
    'security_event',
    'Failed Login',
    'user',
    'User: test.user',
    'External Network',
    'Invalid password (3rd attempt)',
    'Failed',
    'Web',
    '203.0.113.195',
    NULL,
    '{}'::jsonb,
    '{"login_attempts": 3, "account_status": "locked_temporary"}'::jsonb,
    '{"alert_sent": true, "geo_location": "New Delhi, IN", "threat_score": 78}'::jsonb,
    encode(digest('EVT-20250110-00005-hash', 'sha256'), 'hex')
),
(
    'EVT-20250110-00004',
    'corr-auto-energy-007',
    'sensor-threshold-trigger',
    '11111111-1111-1111-1111-111111111111',
    '2025-01-10 13:54:20+05:30',
    'System',
    'Automated Engine',
    'Automation',
    'automation',
    'Automation Triggered',
    'rule',
    'Energy Saving Rule',
    'Entire Campus',
    'Condition: After 6:00 PM',
    'Success',
    'Automation',
    '127.0.0.1',
    NULL,
    '{"rule_state": "armed"}'::jsonb,
    '{"rule_state": "executed", "affected_devices": 38}'::jsonb,
    '{"rule_id": "AUT-ENERGY-01", "power_saved_kwh": 14.8}'::jsonb,
    encode(digest('EVT-20250110-00004-hash', 'sha256'), 'hex')
),
(
    'EVT-20250110-00003',
    'corr-cmd-lights-008',
    'bulk-switch-off',
    '11111111-1111-1111-1111-111111111111',
    '2025-01-10 13:40:18+05:30',
    'Vikas Singh',
    'View Only',
    'Device Command',
    'device_command',
    'Turn OFF',
    'device_group',
    'Lighting Group (A1-F1)',
    'Academic Block (A) > Floor 1',
    '15 devices',
    'Success',
    'Web',
    '192.168.1.144',
    NULL,
    '{"power": "on", "count": 15}'::jsonb,
    '{"power": "off", "count": 15}'::jsonb,
    '{"bulk_operation_id": "BLK-9082", "latency_ms": 68}'::jsonb,
    encode(digest('EVT-20250110-00003-hash', 'sha256'), 'hex')
),
(
    'EVT-20250110-00002',
    'corr-fw-update-009',
    'ota-firmware-deployment',
    '11111111-1111-1111-1111-111111111111',
    '2025-01-10 13:32:47+05:30',
    'Admin',
    'Super Admin',
    'Firmware Update',
    'configuration',
    'Update Firmware',
    'gateway',
    'Gateway (GW-A02)',
    'Academic Block (A)',
    'v2.3.1 → v2.4.0',
    'Success',
    'Web',
    '192.168.1.100',
    'GW-0002',
    '{"firmware_version": "v2.3.1"}'::jsonb,
    '{"firmware_version": "v2.4.0", "status": "operational"}'::jsonb,
    '{"md5": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "reboot_sec": 14}'::jsonb,
    encode(digest('EVT-20250110-00002-hash', 'sha256'), 'hex')
),
(
    'EVT-20250110-00001',
    'corr-sys-mqtt-010',
    'broker-keepalive-watchdog',
    '11111111-1111-1111-1111-111111111111',
    '2025-01-10 13:20:03+05:30',
    'System',
    'Automated Engine',
    'System Event',
    'system_event',
    'Broker Reconnected',
    'broker',
    'MQTT Broker',
    'Docker Host / IoT Hub',
    'Uptime: 12d 04h 21m',
    'Success',
    'System',
    '127.0.0.1',
    'SRV-MQTT-01',
    '{"connection": "reconnecting"}'::jsonb,
    '{"connection": "connected", "active_clients": 136}'::jsonb,
    '{"broker_version": "Eclipse Mosquitto v2.0.18", "port": 1883, "ssl": true}'::jsonb,
    encode(digest('EVT-20250110-00001-hash', 'sha256'), 'hex')
);

-- Stored Procedure to append cryptographic audit log
CREATE OR REPLACE FUNCTION public.fn_record_enterprise_audit_log(
    p_school_id UUID,
    p_actor_name VARCHAR,
    p_actor_role VARCHAR,
    p_event_type VARCHAR,
    p_event_category VARCHAR,
    p_action VARCHAR,
    p_target_type VARCHAR,
    p_target_name VARCHAR,
    p_location_name VARCHAR,
    p_details TEXT,
    p_result VARCHAR,
    p_source VARCHAR,
    p_ip_address VARCHAR,
    p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
    v_prev_hash VARCHAR(128);
    v_new_hash VARCHAR(128);
    v_event_id VARCHAR(64);
BEGIN
    SELECT hash INTO v_prev_hash FROM public.enterprise_audit_logs ORDER BY occurred_at DESC, id DESC LIMIT 1;
    IF v_prev_hash IS NULL THEN
        v_prev_hash := 'GENESIS_BLOCK_0000000000000000000000000000000000000000000000000000000000000000';
    END IF;

    v_event_id := 'EVT-' || TO_CHAR(NOW(), 'YYYYMMDD-HH24MISS-') || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
    v_new_hash := encode(digest(v_prev_hash || ':' || v_event_id || ':' || p_action || ':' || p_target_name || ':' || NOW()::TEXT, 'sha256'), 'hex');

    INSERT INTO public.enterprise_audit_logs (
        event_id, correlation_id, causation_id, school_id, occurred_at,
        actor_name, actor_role, event_type, event_category, action,
        target_type, target_name, location_name, details, result,
        source, ip_address, metadata, hash, previous_hash
    ) VALUES (
        v_event_id, 'corr-' || gen_random_uuid()::TEXT, 'causation-direct', p_school_id, NOW(),
        p_actor_name, p_actor_role, p_event_type, p_event_category, p_action,
        p_target_type, p_target_name, p_location_name, p_details, p_result,
        p_source, p_ip_address, p_metadata, v_new_hash, v_prev_hash
    ) RETURNING id INTO v_id;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql;
