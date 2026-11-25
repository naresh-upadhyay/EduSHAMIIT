-- ============================================================================
-- Migration 589: SHAMIIT SMS GATEWAY (Enterprise Multi-SIM SMS Gateway)
-- Company: SHAMIIT Innovation and Technologies LLP
-- Supports:
--   1. Gateway Device Registration, Token Rotation, Heartbeats & Health Telemetry
--   2. Real Android SIM Subscription Discovery & Conflict-Safe Configuration
--   3. Outbound / Inbound / Scheduled / Multipart SMS Messages & Job Leasing
--   4. Idempotent Event Reporting, Delivery Tracking & Real-Time Activity Feed
--   5. Automation Rules Engine & Execution History
--   6. DLT-Ready Message Templates & Variable Validation
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SMS GATEWAY DEVICES & TELEMETRY
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sms_gateway_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    device_id VARCHAR(120) NOT NULL UNIQUE,
    device_name VARCHAR(150) NOT NULL,
    model VARCHAR(120) DEFAULT 'Android Device',
    manufacturer VARCHAR(100) DEFAULT '',
    android_version VARCHAR(50) DEFAULT 'Android',
    app_version VARCHAR(50) DEFAULT '1.0.0',
    status VARCHAR(40) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, PAUSED, REVOKED, EMERGENCY_DISABLED
    is_online BOOLEAN NOT NULL DEFAULT FALSE,
    battery_level INTEGER DEFAULT 100,
    is_charging BOOLEAN NOT NULL DEFAULT FALSE,
    battery_optimization_disabled BOOLEAN NOT NULL DEFAULT FALSE,
    network_type VARCHAR(60) DEFAULT 'UNKNOWN',
    internet_connected BOOLEAN NOT NULL DEFAULT FALSE,
    uptime_seconds BIGINT NOT NULL DEFAULT 0,
    active_sim_slot INTEGER,
    active_subscription_id INTEGER,
    device_token_hash VARCHAR(255),
    token_issued_at TIMESTAMPTZ,
    last_heartbeat_at TIMESTAMPTZ,
    last_sync_at TIMESTAMPTZ,
    registered_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_devices_school_status
    ON public.sms_gateway_devices(school_id, status);
CREATE INDEX IF NOT EXISTS idx_sms_devices_last_heartbeat
    ON public.sms_gateway_devices(last_heartbeat_at DESC);

CREATE TABLE IF NOT EXISTS public.sms_gateway_device_heartbeats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_pk UUID NOT NULL REFERENCES public.sms_gateway_devices(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    is_online BOOLEAN NOT NULL DEFAULT TRUE,
    battery_level INTEGER DEFAULT 100,
    is_charging BOOLEAN NOT NULL DEFAULT FALSE,
    battery_optimization_disabled BOOLEAN NOT NULL DEFAULT FALSE,
    network_type VARCHAR(60) DEFAULT 'UNKNOWN',
    queue_size INTEGER NOT NULL DEFAULT 0,
    uptime_seconds BIGINT NOT NULL DEFAULT 0,
    active_sim_slot INTEGER,
    active_subscription_id INTEGER,
    api_latency_ms INTEGER,
    ip_address VARCHAR(100),
    heartbeat_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_heartbeats_device_ts
    ON public.sms_gateway_device_heartbeats(device_pk, heartbeat_timestamp DESC);

-- ----------------------------------------------------------------------------
-- 2. SIM INVENTORY & DEVICE CONFIGURATION
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sms_gateway_sims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    device_id VARCHAR(120) NOT NULL,
    subscription_id INTEGER NOT NULL,
    sim_slot_index INTEGER NOT NULL,
    carrier_name VARCHAR(120) NOT NULL DEFAULT 'Unknown Carrier',
    display_name VARCHAR(120) NOT NULL DEFAULT '',
    country_iso VARCHAR(16) DEFAULT '',
    phone_number VARCHAR(40),
    sim_state VARCHAR(40) NOT NULL DEFAULT 'UNKNOWN',
    network_operator VARCHAR(80) DEFAULT '',
    network_type VARCHAR(40) DEFAULT 'UNKNOWN',
    signal_strength_dbm INTEGER,
    signal_level INTEGER DEFAULT 0, -- 0..4
    signal_label VARCHAR(40) DEFAULT 'Unknown',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_data_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    usage_mode VARCHAR(30) NOT NULL DEFAULT 'SEND_RECEIVE', -- SEND_RECEIVE, SEND_ONLY, RECEIVE_ONLY
    balance_info VARCHAR(120) DEFAULT 'Not Available',
    validity_info VARCHAR(120) DEFAULT 'Not Available',
    sent_count INTEGER NOT NULL DEFAULT 0,
    received_count INTEGER NOT NULL DEFAULT 0,
    failed_count INTEGER NOT NULL DEFAULT 0,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_sms_sim_device_sub UNIQUE (device_id, subscription_id)
);

CREATE INDEX IF NOT EXISTS idx_sms_sims_school_device
    ON public.sms_gateway_sims(school_id, device_id, sim_slot_index);

CREATE TABLE IF NOT EXISTS public.sms_gateway_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    device_id VARCHAR(120) NOT NULL DEFAULT 'DEFAULT',
    preferred_sim_mode VARCHAR(30) NOT NULL DEFAULT 'SIM_1', -- SIM_1, SIM_2, MANUAL, AUTO_RULE
    preferred_subscription_id INTEGER,
    preferred_sim_slot INTEGER DEFAULT 0,
    secondary_subscription_id INTEGER,
    secondary_sim_slot INTEGER,
    auto_fallback_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    switch_on_unavailable BOOLEAN NOT NULL DEFAULT TRUE,
    switch_on_network_error BOOLEAN NOT NULL DEFAULT FALSE,
    switch_back_on_recover BOOLEAN NOT NULL DEFAULT TRUE,
    automated_messaging_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    incoming_forwarding_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    queue_sync_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    scheduled_processing_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    polling_interval_seconds INTEGER NOT NULL DEFAULT 15,
    message_expiration_seconds INTEGER NOT NULL DEFAULT 86400,
    retention_days INTEGER NOT NULL DEFAULT 90,
    emergency_disabled BOOLEAN NOT NULL DEFAULT FALSE,
    server_url VARCHAR(255) NOT NULL DEFAULT 'https://eduapi.shamiit.com',
    conflict_policy VARCHAR(60) NOT NULL DEFAULT 'DEVICE_TRUTH_FOR_SIM_BACKEND_FOR_RULES',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_sms_settings_school_device UNIQUE (school_id, device_id)
);

-- ----------------------------------------------------------------------------
-- 3. MESSAGE TEMPLATES (DLT & VARIABLE SAFE)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sms_gateway_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    template_name VARCHAR(150) NOT NULL,
    application_name VARCHAR(120) NOT NULL DEFAULT 'EduSHAMIIT',
    category VARCHAR(80) NOT NULL DEFAULT 'Notification',
    message_body TEXT NOT NULL,
    available_variables JSONB NOT NULL DEFAULT '[]'::jsonb,
    required_variables JSONB NOT NULL DEFAULT '[]'::jsonb,
    dlt_template_id VARCHAR(100),
    dlt_header VARCHAR(40),
    default_priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL',
    preferred_sim_slot INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_templates_school_active
    ON public.sms_gateway_templates(school_id, is_active);

-- ----------------------------------------------------------------------------
-- 4. AUTOMATION RULES & EXECUTION LOGS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sms_gateway_automation_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    rule_name VARCHAR(160) NOT NULL,
    application_name VARCHAR(120) NOT NULL,
    trigger_event VARCHAR(120) NOT NULL,
    recipient_mapping VARCHAR(160) NOT NULL DEFAULT 'parent_phone',
    template_id UUID REFERENCES public.sms_gateway_templates(id) ON DELETE SET NULL,
    message_template TEXT NOT NULL,
    preferred_sim_slot INTEGER,
    preferred_subscription_id INTEGER,
    priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    schedule_restriction JSONB NOT NULL DEFAULT '{}'::jsonb,
    webhook_url VARCHAR(500),
    execution_count INTEGER NOT NULL DEFAULT 0,
    last_triggered_at TIMESTAMPTZ,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_rules_school_app_trigger
    ON public.sms_gateway_automation_rules(school_id, application_name, trigger_event, is_active);

CREATE TABLE IF NOT EXISTS public.sms_gateway_rule_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    rule_id UUID NOT NULL REFERENCES public.sms_gateway_automation_rules(id) ON DELETE CASCADE,
    message_uuid VARCHAR(100),
    recipient_number VARCHAR(40),
    status VARCHAR(40) NOT NULL DEFAULT 'TRIGGERED',
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    error_detail TEXT,
    executed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_rule_exec_rule_ts
    ON public.sms_gateway_rule_executions(rule_id, executed_at DESC);

-- ----------------------------------------------------------------------------
-- 5. SMS MESSAGES (OUTBOUND JOBS, SCHEDULED & INBOUND LOGS)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sms_gateway_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    message_uuid VARCHAR(100) NOT NULL UNIQUE,
    device_id VARCHAR(120),
    direction VARCHAR(20) NOT NULL DEFAULT 'OUTBOUND', -- OUTBOUND, INBOUND
    sender_number VARCHAR(40),
    recipient_number VARCHAR(40) NOT NULL,
    message_body TEXT NOT NULL,
    encoding VARCHAR(20) NOT NULL DEFAULT 'GSM7', -- GSM7, UNICODE
    segment_count INTEGER NOT NULL DEFAULT 1,
    sending_sim_slot INTEGER,
    sending_subscription_id INTEGER,
    receiving_sim_slot INTEGER,
    receiving_subscription_id INTEGER,
    carrier_name VARCHAR(120),
    application_source VARCHAR(120) NOT NULL DEFAULT 'SMS Gateway App',
    reference_id VARCHAR(120),
    template_id UUID REFERENCES public.sms_gateway_templates(id) ON DELETE SET NULL,
    automation_rule_id UUID REFERENCES public.sms_gateway_automation_rules(id) ON DELETE SET NULL,
    priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL', -- LOW, NORMAL, HIGH, URGENT
    status VARCHAR(30) NOT NULL DEFAULT 'QUEUED', -- QUEUED, SCHEDULED, LEASED, SENDING, SENT, DELIVERED, FAILED, RECEIVED, EXPIRED
    delivery_report_requested BOOLEAN NOT NULL DEFAULT TRUE,
    scheduled_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    queued_at TIMESTAMPTZ DEFAULT NOW(),
    submitted_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    received_at TIMESTAMPTZ,
    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 2,
    failure_reason TEXT,
    sync_status VARCHAR(30) NOT NULL DEFAULT 'SYNCED', -- PENDING, SYNCED, CONFLICT
    part_statuses JSONB NOT NULL DEFAULT '[]'::jsonb,
    lease_token VARCHAR(120),
    leased_until TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_messages_school_status_created
    ON public.sms_gateway_messages(school_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sms_messages_school_dir_created
    ON public.sms_gateway_messages(school_id, direction, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sms_messages_lease
    ON public.sms_gateway_messages(status, scheduled_at, leased_until);
CREATE INDEX IF NOT EXISTS idx_sms_messages_ref
    ON public.sms_gateway_messages(school_id, reference_id);

-- ----------------------------------------------------------------------------
-- 6. REAL-TIME GATEWAY EVENTS & AUDIT FEED
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sms_gateway_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    event_uuid VARCHAR(100) NOT NULL UNIQUE,
    device_id VARCHAR(120),
    message_uuid VARCHAR(100),
    event_type VARCHAR(50) NOT NULL, -- SMS_RECEIVED, SMS_SUBMITTED, SMS_SENT, SMS_DELIVERED, SMS_FAILED, SIM_CHANGED, GATEWAY_CONNECTED, GATEWAY_DISCONNECTED, BACKEND_SYNCED, RULE_TRIGGERED
    title VARCHAR(200) NOT NULL,
    description TEXT,
    sim_slot INTEGER,
    subscription_id INTEGER,
    application_source VARCHAR(120),
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    event_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sms_events_school_ts
    ON public.sms_gateway_events(school_id, event_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_sms_events_msg
    ON public.sms_gateway_events(message_uuid);

-- Default settings row for primary school (no fake messages or fake SIMs)
INSERT INTO public.sms_gateway_settings (school_id, device_id)
VALUES ('11111111-1111-1111-1111-111111111111', 'DEFAULT')
ON CONFLICT (school_id, device_id) DO NOTHING;
