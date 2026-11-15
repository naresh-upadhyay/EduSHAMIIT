-- ============================================================================
-- Migration 498: Enterprise IoT Integrations & Gateways System
-- EduSHAMIIT Campus Management -> Device Management & Control -> Integrations & Gateways
-- ============================================================================

DO $$
BEGIN
    -- 1. Extend campus_iot_gateways table with full enterprise hardware specs
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'campus_iot_gateways') THEN
        ALTER TABLE public.campus_iot_gateways 
            ADD COLUMN IF NOT EXISTS protocols text DEFAULT 'MQTT, Modbus',
            ADD COLUMN IF NOT EXISTS serial_number varchar(100),
            ADD COLUMN IF NOT EXISTS model varchar(100) DEFAULT 'EdgeCore IoT-800',
            ADD COLUMN IF NOT EXISTS manufacturer varchar(100) DEFAULT 'Advantech / EdgeCore',
            ADD COLUMN IF NOT EXISTS hardware_version varchar(50) DEFAULT 'v1.4',
            ADD COLUMN IF NOT EXISTS uptime_display varchar(100) DEFAULT '15 days, 08:36:21 (99.6%)',
            ADD COLUMN IF NOT EXISTS firmware_update_available varchar(50) DEFAULT 'v2.4.0',
            ADD COLUMN IF NOT EXISTS data_throughput_mb_min numeric(8,2) DEFAULT 1.6;
    END IF;
END $$;

-- 2. Create iot_integrations table
CREATE TABLE IF NOT EXISTS public.iot_integrations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    name varchar(150) NOT NULL,
    type varchar(100) NOT NULL,
    category varchar(50) NOT NULL DEFAULT 'custom',
    provider varchar(100) DEFAULT 'Standard Provider',
    protocol varchar(100) NOT NULL,
    connection_mode varchar(50) DEFAULT 'Direct',
    assigned_gateway_id uuid REFERENCES public.campus_iot_gateways(id) ON DELETE SET NULL,
    connected_devices_count integer DEFAULT 0,
    status varchar(30) DEFAULT 'active',
    is_active boolean DEFAULT true,
    last_sync_at timestamptz DEFAULT now(),
    last_error text,
    config jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iot_integrations_school ON public.iot_integrations(school_id, status);

-- 3. Create iot_protocols table
CREATE TABLE IF NOT EXISTS public.iot_protocols (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    name varchar(100) NOT NULL,
    code varchar(50) NOT NULL,
    category varchar(50) DEFAULT 'Network Protocol',
    status varchar(30) DEFAULT 'Active',
    port integer DEFAULT 1883,
    version varchar(50) DEFAULT '1.0',
    driver_version varchar(50) DEFAULT 'v2.1.0',
    clients_or_devices_count integer DEFAULT 0,
    count_label varchar(50) DEFAULT 'devices',
    is_connected boolean DEFAULT true,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now()
);

-- 4. Create iot_discovered_devices table (For Device Discovery Tab)
CREATE TABLE IF NOT EXISTS public.iot_discovered_devices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    gateway_id uuid REFERENCES public.campus_iot_gateways(id) ON DELETE SET NULL,
    device_identifier varchar(120) NOT NULL,
    device_name varchar(150) NOT NULL,
    device_type varchar(80) NOT NULL,
    protocol varchar(50) NOT NULL,
    manufacturer varchar(100),
    model varchar(100),
    mac_address varchar(50),
    ip_address varchar(50),
    signal_strength_dbm integer DEFAULT -65,
    location_suggestion varchar(150),
    status varchar(30) DEFAULT 'newly_discovered', -- newly_discovered, identified, pending_approval, registered, rejected
    discovered_at timestamptz DEFAULT now()
);

-- 5. Create iot_webhooks table
CREATE TABLE IF NOT EXISTS public.iot_webhooks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    name varchar(150) NOT NULL,
    direction varchar(20) DEFAULT 'outgoing', -- incoming, outgoing
    endpoint_url text NOT NULL,
    event_types text[] DEFAULT ARRAY['device.status', 'device.alert', 'gateway.status'],
    secret_key_hash text,
    status varchar(30) DEFAULT 'active',
    retry_count integer DEFAULT 3,
    last_delivery_at timestamptz,
    last_status_code integer DEFAULT 200,
    created_at timestamptz DEFAULT now()
);

-- 6. Create iot_certificates table (For Security & Certificates Tab)
CREATE TABLE IF NOT EXISTS public.iot_certificates (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    name varchar(150) NOT NULL,
    cert_type varchar(50) DEFAULT 'client', -- ca, client, gateway, server
    subject varchar(200),
    issuer varchar(200),
    valid_from timestamptz DEFAULT now(),
    valid_until timestamptz DEFAULT (now() + interval '365 days'),
    status varchar(30) DEFAULT 'active', -- active, expiring_soon, expired, revoked
    thumbprint varchar(100),
    created_at timestamptz DEFAULT now()
);

-- 7. Create iot_integration_logs table (For Centralized Logs & Diagnostics Tab)
CREATE TABLE IF NOT EXISTS public.iot_integration_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    source varchar(80) NOT NULL, -- Gateway, Integration, MQTT, Protocol, Webhook
    severity varchar(20) DEFAULT 'info', -- info, warning, error, critical
    integration_id uuid REFERENCES public.iot_integrations(id) ON DELETE SET NULL,
    gateway_id uuid REFERENCES public.campus_iot_gateways(id) ON DELETE SET NULL,
    protocol varchar(50),
    event varchar(150) NOT NULL,
    message text NOT NULL,
    correlation_id varchar(100),
    created_at timestamptz DEFAULT now()
);

-- 8. Create iot_gateway_operations table (Tracks Reboots, Firmware Updates, Diagnostics)
CREATE TABLE IF NOT EXISTS public.iot_gateway_operations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    gateway_id uuid NOT NULL REFERENCES public.campus_iot_gateways(id) ON DELETE CASCADE,
    operation_type varchar(50) NOT NULL, -- restart, update_firmware, run_diagnostics, sync_time
    initiated_by varchar(100) DEFAULT 'Admin',
    status varchar(30) DEFAULT 'completed', -- pending, executing, completed, failed
    details jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now()
);

-- Enable RLS & Permissive Policies
ALTER TABLE public.iot_integrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.iot_protocols ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.iot_discovered_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.iot_webhooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.iot_certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.iot_integration_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.iot_gateway_operations ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    DROP POLICY IF EXISTS "Allow all for iot_integrations" ON public.iot_integrations;
    CREATE POLICY "Allow all for iot_integrations" ON public.iot_integrations FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow all for iot_protocols" ON public.iot_protocols;
    CREATE POLICY "Allow all for iot_protocols" ON public.iot_protocols FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow all for iot_discovered_devices" ON public.iot_discovered_devices;
    CREATE POLICY "Allow all for iot_discovered_devices" ON public.iot_discovered_devices FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow all for iot_webhooks" ON public.iot_webhooks;
    CREATE POLICY "Allow all for iot_webhooks" ON public.iot_webhooks FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow all for iot_certificates" ON public.iot_certificates;
    CREATE POLICY "Allow all for iot_certificates" ON public.iot_certificates FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow all for iot_integration_logs" ON public.iot_integration_logs;
    CREATE POLICY "Allow all for iot_integration_logs" ON public.iot_integration_logs FOR ALL USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow all for iot_gateway_operations" ON public.iot_gateway_operations;
    CREATE POLICY "Allow all for iot_gateway_operations" ON public.iot_gateway_operations FOR ALL USING (true) WITH CHECK (true);
END $$;

-- ============================================================================
-- SEED DATA (Matching Canonical Screenshots)
-- ============================================================================
DO $$
DECLARE
    sid UUID;
    gw1_id UUID := 'b1000000-0000-0000-0000-000000000001';
    gw2_id UUID := 'b1000000-0000-0000-0000-000000000002';
    gw3_id UUID := 'b1000000-0000-0000-0000-000000000003';
    gw4_id UUID := 'b1000000-0000-0000-0000-000000000004';
    gw5_id UUID := 'b1000000-0000-0000-0000-000000000005';
    gw6_id UUID := 'b1000000-0000-0000-0000-000000000006';
    gw7_id UUID := 'b1000000-0000-0000-0000-000000000007';
    gw8_id UUID := 'b1000000-0000-0000-0000-000000000008';
BEGIN
    SELECT id INTO sid FROM public.schools LIMIT 1;
    IF sid IS NULL THEN
        sid := '11111111-1111-1111-1111-111111111111'::UUID;
    END IF;

    -- Upsert the 8 Canonical Gateways
    INSERT INTO public.campus_iot_gateways (
        id, school_id, gateway_code, gateway_name, gateway_type, ip_address, mac_address, 
        protocol, protocols, location_path, status, is_online, connected_devices_count, 
        cpu_usage_pct, memory_usage_pct, temperature_celsius, uptime_seconds, uptime_display,
        firmware_version, firmware_update_available, data_throughput_mb_min, last_heartbeat_at
    ) VALUES
    (gw1_id, sid, 'GW-0001', 'GW-A01 (Main Block)', 'edge_router', '192.168.10.21', '00:1A:2B:3C:4D:5E',
     'mqtt', 'MQTT, Modbus (TCP)', 'Main Block', 'online', true, 28, 
     21.4, 44.8, 38.5, 1326981, '15 days, 08:36:21 (99.6%)', 'v2.3.1', 'v2.4.0', 2.8, '2025-01-10 14:18:00+00'),
    (gw2_id, sid, 'GW-0002', 'GW-A02 (Academic)', 'zigbee_coordinator', '192.168.10.22', '00:1A:2B:3C:4D:5F',
     'zigbee', 'MQTT, Zigbee', 'Academic Block (A)', 'online', true, 18, 
     18.2, 40.5, 36.2, 1253700, '14 days, 12:15:00 (99.2%)', 'v2.4.0', NULL, 1.9, '2025-01-10 14:17:00+00'),
    (gw3_id, sid, 'GW-0003', 'GW-A03 (Library)', 'modbus_bridge', '192.168.10.23', '00:1A:2B:3C:4D:60',
     'modbus', 'MQTT, Modbus', 'Library Block', 'online', true, 12, 
     15.0, 38.0, 35.0, 1917010, '22 days, 04:30:10 (99.8%)', 'v2.4.0', NULL, 1.2, '2025-01-10 14:17:00+00'),
    (gw4_id, sid, 'GW-0004', 'GW-A04 (Laboratory)', 'http_gateway', '192.168.10.24', '00:1A:2B:3C:4D:61',
     'http', 'MQTT, HTTP(S)', 'Laboratory Block', 'online', true, 16, 
     25.8, 48.2, 42.1, 929140, '10 days, 18:05:40 (98.9%)', 'v2.4.0', NULL, 1.8, '2025-01-10 14:16:00+00'),
    (gw5_id, sid, 'GW-0005', 'GW-A05 (Auditorium)', 'media_gateway', '192.168.10.25', '00:1A:2B:3C:4D:62',
     'rtsp', 'MQTT, RTSP', 'Auditorium', 'online', true, 20, 
     28.5, 52.0, 44.0, 1588935, '18 days, 09:22:15 (99.4%)', 'v2.4.0', NULL, 2.4, '2025-01-10 14:18:00+00'),
    (gw6_id, sid, 'GW-0006', 'GW-A06 (Admin)', 'cctv_bridge', '192.168.10.26', '00:1A:2B:3C:4D:63',
     'onvif', 'MQTT, ONVIF', 'Administrative Block', 'online', true, 14, 
     19.2, 41.5, 37.8, 2596200, '30 days, 01:10:00 (99.9%)', 'v2.4.0', NULL, 1.5, '2025-01-10 14:17:00+00'),
    (gw7_id, sid, 'GW-0007', 'GW-A07 (Sports)', 'wireless_hub', '192.168.10.27', '00:1A:2B:3C:4D:64',
     'zigbee', 'MQTT, Zigbee', 'Sports Complex', 'online', true, 8, 
     12.1, 32.4, 34.5, 1061100, '12 days, 06:45:00 (98.7%)', 'v2.4.0', NULL, 0.9, '2025-01-10 14:16:00+00'),
    (gw8_id, sid, 'GW-0008', 'GW-A08 (Hostel)', 'substation_bridge', '192.168.10.28', '00:1A:2B:3C:4D:65',
     'modbus', 'MQTT, Modbus', 'Hostel Block', 'offline', false, 0, 
     0.0, 0.0, 24.0, 0, '0 days, 00:00:00 (0.0%)', 'v2.2.8', 'v2.4.0', 0.0, '2025-01-10 11:42:00+00')
    ON CONFLICT (id) DO UPDATE SET
        gateway_name = EXCLUDED.gateway_name,
        gateway_code = EXCLUDED.gateway_code,
        ip_address = EXCLUDED.ip_address,
        protocol = EXCLUDED.protocol,
        protocols = EXCLUDED.protocols,
        location_path = EXCLUDED.location_path,
        status = EXCLUDED.status,
        is_online = EXCLUDED.is_online,
        connected_devices_count = EXCLUDED.connected_devices_count,
        uptime_display = EXCLUDED.uptime_display,
        firmware_version = EXCLUDED.firmware_version,
        firmware_update_available = EXCLUDED.firmware_update_available,
        last_heartbeat_at = EXCLUDED.last_heartbeat_at;

    -- Upsert the 6 Canonical Third-party Integrations
    INSERT INTO public.iot_integrations (
        id, school_id, name, type, category, provider, protocol, connection_mode, 
        assigned_gateway_id, connected_devices_count, status, is_active, last_sync_at
    ) VALUES
    ('c1000000-0000-0000-0000-000000000001', sid, 'Building Management System (BMS)', 'Facility Integration', 'bms', 'Schneider Electric', 'Modbus (TCP)', 'Direct', gw1_id, 6, 'active', true, '2025-01-10 14:10:00+00'),
    ('c1000000-0000-0000-0000-000000000002', sid, 'Access Control System', 'Security Integration', 'access_control', 'HID Global', 'HTTP(S) / API', 'Cloud API', gw6_id, 14, 'active', true, '2025-01-10 14:12:00+00'),
    ('c1000000-0000-0000-0000-000000000003', sid, 'CCTV / Video Management (VMS)', 'Surveillance Integration', 'vms', 'Hikvision / Milestone', 'ONVIF / RTSP', 'Hybrid', gw6_id, 22, 'active', true, '2025-01-10 14:11:00+00'),
    ('c1000000-0000-0000-0000-000000000004', sid, 'Energy Metering System', 'Energy Integration', 'energy', 'Schneider PowerLogic', 'Modbus (TCP)', 'Gateway Bridge', gw3_id, 8, 'active', true, '2025-01-10 14:09:00+00'),
    ('c1000000-0000-0000-0000-000000000005', sid, 'Notification Service (SMS/Email)', 'Communication', 'notification', 'Twilio / SendGrid', 'HTTP(S) / API', 'REST API', NULL, 12, 'active', true, '2025-01-10 14:08:00+00'),
    ('c1000000-0000-0000-0000-000000000006', sid, 'IoT Device Command Service', 'Core Integration', 'core', 'EduSHAMIIT Core Engine', 'MQTT', 'Direct Broker', gw1_id, 136, 'active', true, '2025-01-10 14:15:00+00')
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        type = EXCLUDED.type,
        protocol = EXCLUDED.protocol,
        status = EXCLUDED.status,
        last_sync_at = EXCLUDED.last_sync_at;

    -- Upsert the 6 Canonical Protocols
    DELETE FROM public.iot_protocols WHERE school_id = sid;
    INSERT INTO public.iot_protocols (
        school_id, name, code, category, status, port, version, driver_version, 
        clients_or_devices_count, count_label, is_connected
    ) VALUES
    (sid, 'MQTT', 'mqtt', 'Messaging Broker', 'Connected', 1883, 'v3.1.1 / v5.0', 'v2.4.1', 136, 'clients', true),
    (sid, 'Modbus (TCP/RTU)', 'modbus', 'Fieldbus Protocol', 'Active', 502, 'v1.2', 'v3.0.0', 6, 'devices', true),
    (sid, 'HTTP(S)', 'http', 'REST Web Services', 'Active', 443, 'HTTP/2', 'v1.8.2', 3, 'integrations', true),
    (sid, 'ONVIF (CCTV)', 'onvif', 'Video Surveillance', 'Active', 554, 'Profile S/G', 'v2.3.0', 22, 'cameras', true),
    (sid, 'RTSP (Video)', 'rtsp', 'Streaming Protocol', 'Active', 554, 'RFC 2326', 'v1.4.0', 18, 'streams', true),
    (sid, 'Zigbee', 'zigbee', 'Mesh Wireless', 'Active', 8443, 'Zigbee 3.0', 'v4.1.2', 14, 'devices', true);

    -- Seed Discovered Devices
    DELETE FROM public.iot_discovered_devices WHERE school_id = sid;
    INSERT INTO public.iot_discovered_devices (
        school_id, gateway_id, device_identifier, device_name, device_type, protocol, 
        manufacturer, model, mac_address, ip_address, signal_strength_dbm, location_suggestion, status
    ) VALUES
    (sid, gw1_id, 'DISC-LIGHT-091', 'Philips Hue Smart Troffer', 'Lighting', 'Zigbee', 'Philips', 'Hue Pro 60x60', '00:17:88:65:43:21', '192.168.10.191', -58, 'Main Block > Reception', 'newly_discovered'),
    (sid, gw2_id, 'DISC-METER-042', 'Schneider PowerLogic PM5300', 'Energy Meter', 'Modbus', 'Schneider', 'PM5350', '00:80:F4:11:22:33', '192.168.10.142', -52, 'Academic Block (A) > Electrical Room', 'identified'),
    (sid, gw5_id, 'DISC-CAM-008', 'Hikvision 4K PTZ Camera', 'CCTV', 'ONVIF', 'Hikvision', 'DS-2DE4425IW-DE', '00:40:8C:99:88:77', '192.168.10.208', -61, 'Auditorium > Stage Overhead', 'pending_approval'),
    (sid, gw4_id, 'DISC-ENV-014', 'Milesight IAQ Sensor (CO2/VOC)', 'Environment', 'Zigbee', 'Milesight', 'AM103L', '24:E1:24:60:11:04', '192.168.10.174', -66, 'Laboratory Block > Chemistry Lab', 'identified');

    -- Seed Webhooks
    DELETE FROM public.iot_webhooks WHERE school_id = sid;
    INSERT INTO public.iot_webhooks (
        school_id, name, direction, endpoint_url, event_types, status, last_delivery_at, last_status_code
    ) VALUES
    (sid, 'ERP Incident Management Webhook', 'outgoing', 'https://api.edushamiit.edu/v1/incidents/ingest', ARRAY['device.critical_fault', 'gateway.offline'], 'active', '2025-01-10 14:15:00+00', 200),
    (sid, 'Facility Security Alert Forwarder', 'outgoing', 'https://security.edushamiit.edu/alerts', ARRAY['access.breach', 'door.forced_open'], 'active', '2025-01-10 14:12:00+00', 200),
    (sid, 'BMS Telemetry Ingestion Endpoint', 'incoming', '/api/v1/integrations/webhooks/bms-inbound', ARRAY['bms.telemetry', 'hvac.sync'], 'active', '2025-01-10 14:10:00+00', 200);

    -- Seed Certificates
    DELETE FROM public.iot_certificates WHERE school_id = sid;
    INSERT INTO public.iot_certificates (
        school_id, name, cert_type, subject, issuer, status, thumbprint
    ) VALUES
    (sid, 'EduSHAMIIT Campus IoT Root CA', 'ca', 'CN=EduSHAMIIT IoT Root CA, O=EduSHAMIIT', 'CN=EduSHAMIIT Root CA', 'active', 'E4:92:A1:B8:3C:D0:1F:55:82:94:10:FA:9C:22:EE:71'),
    (sid, 'EMQX Mosquitto Broker Server TLS', 'server', 'CN=mqtt.edushamiit.internal', 'CN=EduSHAMIIT IoT Root CA', 'active', 'A1:33:4F:90:CC:12:88:BB:77:45:09:12:FE:54:11:29'),
    (sid, 'Gateway Fleet Mutual TLS Client', 'gateway', 'CN=gw-fleet.edushamiit.internal', 'CN=EduSHAMIIT IoT Root CA', 'active', '99:81:72:63:54:45:36:27:18:09:AA:BB:CC:DD:EE:FF');

    -- Seed Recent Integration Logs
    DELETE FROM public.iot_integration_logs WHERE school_id = sid;
    INSERT INTO public.iot_integration_logs (
        school_id, source, severity, integration_id, gateway_id, protocol, event, message, correlation_id, created_at
    ) VALUES
    (sid, 'Gateway', 'info', NULL, gw1_id, 'MQTT', 'Heartbeat Acknowledged', 'GW-A01 reported 28 healthy client telemetry links with 0 packet drops', 'CORR-GW001-9921', '2025-01-10 14:18:00+00'),
    (sid, 'Integration', 'info', 'c1000000-0000-0000-0000-000000000006', gw1_id, 'MQTT', 'Broker QoS 1 Verified', 'IoT Device Command Service publisher channel synchronized with 136 devices', 'CORR-MQTT-4412', '2025-01-10 14:15:00+00'),
    (sid, 'Integration', 'info', 'c1000000-0000-0000-0000-000000000002', gw6_id, 'HTTP(S)', 'Access Control Event Polled', 'HID Door controller access logs polled: 14 doors secured', 'CORR-ACC-8819', '2025-01-10 14:12:00+00'),
    (sid, 'Integration', 'info', 'c1000000-0000-0000-0000-000000000001', gw1_id, 'Modbus', 'BMS Register Sync OK', 'Modbus TCP polling cycle finished: 48 holding registers updated in 12ms', 'CORR-BMS-3310', '2025-01-10 14:10:00+00'),
    (sid, 'Gateway', 'warning', NULL, gw8_id, 'Modbus', 'Gateway Connection Timeout', 'GW-A08 (Hostel) missed 3 consecutive keep-alive intervals; marked offline', 'CORR-GW008-0114', '2025-01-10 11:42:00+00');

    -- Seed Gateway Operation
    INSERT INTO public.iot_gateway_operations (
        school_id, gateway_id, operation_type, initiated_by, status, details
    ) VALUES
    (sid, gw1_id, 'restart', 'Admin', 'completed', '{"reboot_time_sec": 4.2, "clients_reconnected": 28}'::jsonb);

END $$;
