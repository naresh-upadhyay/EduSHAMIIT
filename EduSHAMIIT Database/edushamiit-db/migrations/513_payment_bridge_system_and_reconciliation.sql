-- ============================================================================
-- Migration 513: EduSHAMIIT Payment Bridge & Real-Time UPI Reconciliation
-- Supports:
-- 1. Dedicated Android Device Enrollment, Heartbeats & Key Rotation
-- 2. Android Notification Event Ingestion (Idempotent UUIDs, Paise Math)
-- 3. Payment Candidate Matching Engine (Unique Paise, Intent Tracking)
-- 4. Authoritative Bank Statement Import & Double-Entry Ledger Reconciliation
-- 5. Maker-Checker Manual Review, Unmatched Queue, and Immutable Audit Trail
-- ============================================================================

-- Clean up any legacy or incomplete payment bridge tables
DROP TABLE IF EXISTS public.payment_sync_logs CASCADE;
DROP TABLE IF EXISTS public.payment_audit_logs CASCADE;
DROP TABLE IF EXISTS public.payment_refunds CASCADE;
DROP TABLE IF EXISTS public.payment_manual_reviews CASCADE;
DROP TABLE IF EXISTS public.payment_unmatched_transactions CASCADE;
DROP TABLE IF EXISTS public.payment_reconciliation_matches CASCADE;
DROP TABLE IF EXISTS public.payment_reconciliation_runs CASCADE;
DROP TABLE IF EXISTS public.payment_bank_transactions CASCADE;
DROP TABLE IF EXISTS public.payment_transactions CASCADE;
DROP TABLE IF EXISTS public.payment_candidate_matches CASCADE;
DROP TABLE IF EXISTS public.payment_notification_duplicates CASCADE;
DROP TABLE IF EXISTS public.payment_notification_processing_logs CASCADE;
DROP TABLE IF EXISTS public.payment_notification_events CASCADE;
DROP TABLE IF EXISTS public.payment_intents CASCADE;
DROP TABLE IF EXISTS public.payment_bridge_monitored_apps CASCADE;
DROP TABLE IF EXISTS public.payment_bridge_settings CASCADE;
DROP TABLE IF EXISTS public.payment_bridge_device_heartbeats CASCADE;
DROP TABLE IF EXISTS public.payment_bridge_device_credentials CASCADE;
DROP TABLE IF EXISTS public.payment_bridge_devices CASCADE;

-- ----------------------------------------------------------------------------
-- 1. DEVICE REGISTRATION & CREDENTIAL MANAGEMENT
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_bridge_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    device_id VARCHAR(100) NOT NULL UNIQUE,
    device_name VARCHAR(150) NOT NULL,
    model VARCHAR(100) DEFAULT 'Android Device',
    android_version VARCHAR(50) DEFAULT 'Android 14',
    app_version VARCHAR(50) DEFAULT '1.0.0',
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, REVOKED, SUSPENDED
    is_online BOOLEAN NOT NULL DEFAULT TRUE,
    battery_level INTEGER DEFAULT 95,
    battery_optimization_disabled BOOLEAN NOT NULL DEFAULT TRUE,
    notification_access_granted BOOLEAN NOT NULL DEFAULT TRUE,
    listener_service_running BOOLEAN NOT NULL DEFAULT TRUE,
    last_heartbeat_at TIMESTAMPTZ DEFAULT NOW(),
    last_sync_at TIMESTAMPTZ DEFAULT NOW(),
    registered_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pb_devices_school_status ON public.payment_bridge_devices(school_id, status);
CREATE INDEX IF NOT EXISTS idx_pb_devices_last_sync ON public.payment_bridge_devices(last_sync_at);

CREATE TABLE IF NOT EXISTS public.payment_bridge_device_credentials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_pk UUID NOT NULL REFERENCES public.payment_bridge_devices(id) ON DELETE CASCADE,
    api_key_hash VARCHAR(255) NOT NULL,
    secret_token_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    rotated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pb_device_cred_active ON public.payment_bridge_device_credentials(device_pk, is_active);

CREATE TABLE IF NOT EXISTS public.payment_bridge_device_heartbeats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_pk UUID NOT NULL REFERENCES public.payment_bridge_devices(id) ON DELETE CASCADE,
    listener_active BOOLEAN NOT NULL DEFAULT TRUE,
    notification_access_granted BOOLEAN NOT NULL DEFAULT TRUE,
    battery_level INTEGER DEFAULT 100,
    pending_queue_count INTEGER DEFAULT 0,
    memory_usage_mb NUMERIC(10,2) DEFAULT 45.5,
    ip_address VARCHAR(100),
    heartbeat_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pb_heartbeats_device_ts ON public.payment_bridge_device_heartbeats(device_pk, heartbeat_timestamp DESC);

-- ----------------------------------------------------------------------------
-- 2. BRIDGE SETTINGS & MONITORED APPLICATIONS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_bridge_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE UNIQUE,
    sync_interval_seconds INTEGER NOT NULL DEFAULT 30,
    retry_interval_seconds INTEGER NOT NULL DEFAULT 60,
    duplicate_detection_window_minutes INTEGER NOT NULL DEFAULT 5,
    auto_start_on_boot BOOLEAN NOT NULL DEFAULT TRUE,
    max_local_queue_size INTEGER NOT NULL DEFAULT 1000,
    notification_retention_days INTEGER NOT NULL DEFAULT 30,
    server_url VARCHAR(255) NOT NULL DEFAULT 'https://erp.edushamiit.in/api/v1/payments',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.payment_bridge_monitored_apps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    app_name VARCHAR(100) NOT NULL,
    package_name VARCHAR(200) NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    icon_name VARCHAR(50) DEFAULT 'payment',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_pb_monitored_apps_pkg UNIQUE (school_id, package_name)
);

CREATE INDEX IF NOT EXISTS idx_pb_monitored_apps_enabled ON public.payment_bridge_monitored_apps(school_id, is_enabled);

-- ----------------------------------------------------------------------------
-- 3. PAYMENT INTENTS (ERP REQUESTS WITH UNIQUE PAISE)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_intents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    invoice_id UUID REFERENCES public.student_fee_invoices(id) ON DELETE CASCADE,
    intent_reference VARCHAR(100) NOT NULL UNIQUE,
    base_amount_paise BIGINT NOT NULL CHECK (base_amount_paise > 0),
    total_amount_paise BIGINT NOT NULL CHECK (total_amount_paise > 0),
    unique_paise INTEGER NOT NULL DEFAULT 0 CHECK (unique_paise >= 0 AND unique_paise < 100),
    currency VARCHAR(10) NOT NULL DEFAULT 'INR',
    upi_vpa VARCHAR(100) NOT NULL DEFAULT 'edushamiit@ybl',
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING', 
    -- PENDING, AWAITING_VERIFICATION, REVIEW_REQUIRED, VERIFIED_SUCCESS, EXPIRED, CANCELLED
    expires_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pb_intents_lookup ON public.payment_intents(school_id, status, total_amount_paise);
CREATE INDEX IF NOT EXISTS idx_pb_intents_student ON public.payment_intents(school_id, student_id);
CREATE INDEX IF NOT EXISTS idx_pb_intents_invoice ON public.payment_intents(school_id, invoice_id);

-- ----------------------------------------------------------------------------
-- 4. NOTIFICATION EVENTS & INGESTION QUEUE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_notification_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_uuid UUID NOT NULL UNIQUE, -- Device generated idempotent UUID
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    device_pk UUID REFERENCES public.payment_bridge_devices(id) ON DELETE SET NULL,
    device_id VARCHAR(100),
    source_package VARCHAR(200) NOT NULL,
    source_app VARCHAR(100) NOT NULL, -- PhonePe, Google Pay, Paytm, BHIM, etc.
    event_type VARCHAR(50) NOT NULL, -- PAYMENT_RECEIVED, PAYMENT_SENT, UNKNOWN
    amount_paise BIGINT NOT NULL, -- Integer paise e.g. 200034 = Rs 2000.34
    sender_name VARCHAR(200),
    masked_sender_identifier VARCHAR(100), -- "**** 9821"
    transaction_reference VARCHAR(150), -- "UPI/438729106731"
    notification_timestamp TIMESTAMPTZ NOT NULL,
    raw_title TEXT,
    raw_text TEXT,
    parser_version VARCHAR(50) NOT NULL DEFAULT '1.0.0',
    confidence_score VARCHAR(50) NOT NULL DEFAULT 'HIGH', -- HIGH, MEDIUM, LOW, UNPARSED
    parsing_status VARCHAR(50) NOT NULL DEFAULT 'PARSED', -- PARSED, UNPARSED, FAILED
    candidate_match_status VARCHAR(50) NOT NULL DEFAULT 'UNMATCHED', 
    -- MATCHED_CANDIDATE, UNMATCHED, DUPLICATE, IGNORED, REVIEW_REQUIRED
    matched_intent_id UUID REFERENCES public.payment_intents(id) ON DELETE SET NULL,
    sync_status VARCHAR(50) NOT NULL DEFAULT 'SYNCED', -- SYNC_PENDING, SYNCED, SYNC_FAILED
    is_duplicate BOOLEAN NOT NULL DEFAULT FALSE,
    duplicate_of_event_id UUID REFERENCES public.payment_notification_events(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pb_events_school_status ON public.payment_notification_events(school_id, candidate_match_status);
CREATE INDEX IF NOT EXISTS idx_pb_events_ref ON public.payment_notification_events(transaction_reference);
CREATE INDEX IF NOT EXISTS idx_pb_events_amount ON public.payment_notification_events(school_id, amount_paise);
CREATE INDEX IF NOT EXISTS idx_pb_events_ts ON public.payment_notification_events(school_id, notification_timestamp DESC);

CREATE TABLE IF NOT EXISTS public.payment_notification_processing_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_event_id UUID NOT NULL REFERENCES public.payment_notification_events(id) ON DELETE CASCADE,
    step_name VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL,
    message TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pb_proc_logs_event ON public.payment_notification_processing_logs(notification_event_id);

CREATE TABLE IF NOT EXISTS public.payment_notification_duplicates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    original_event_id UUID NOT NULL REFERENCES public.payment_notification_events(id) ON DELETE CASCADE,
    duplicate_event_uuid UUID NOT NULL,
    device_id VARCHAR(100),
    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reason TEXT
);

-- ----------------------------------------------------------------------------
-- 5. CANDIDATE MATCHES & TRANSACTIONS LEDGER
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_candidate_matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    notification_event_id UUID NOT NULL REFERENCES public.payment_notification_events(id) ON DELETE CASCADE,
    payment_intent_id UUID NOT NULL REFERENCES public.payment_intents(id) ON DELETE CASCADE,
    match_rule VARCHAR(100) NOT NULL, -- EXACT_UTR, UNIQUE_PAISE_MATCH, TIME_WINDOW_MATCH, MANUAL_ASSOCIATION
    match_score NUMERIC(5,2) NOT NULL DEFAULT 100.0,
    status VARCHAR(50) NOT NULL DEFAULT 'CANDIDATE', -- CANDIDATE, CONFIRMED, REJECTED, SUPERSEDED
    matched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    matched_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    review_notes TEXT,
    CONSTRAINT uq_pb_candidate_match UNIQUE(notification_event_id, payment_intent_id)
);

CREATE INDEX IF NOT EXISTS idx_pb_candidates_intent ON public.payment_candidate_matches(payment_intent_id);

CREATE TABLE IF NOT EXISTS public.payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    invoice_id UUID REFERENCES public.student_fee_invoices(id) ON DELETE SET NULL,
    payment_intent_id UUID REFERENCES public.payment_intents(id) ON DELETE SET NULL,
    notification_event_id UUID REFERENCES public.payment_notification_events(id) ON DELETE SET NULL,
    bank_transaction_id UUID, -- References payment_bank_transactions
    transaction_reference VARCHAR(150),
    amount_paise BIGINT NOT NULL CHECK (amount_paise > 0),
    base_fee_paise BIGINT NOT NULL CHECK (base_fee_paise >= 0),
    excess_paise BIGINT NOT NULL DEFAULT 0,
    payment_mode VARCHAR(50) NOT NULL DEFAULT 'UPI (PhonePe)',
    upi_app VARCHAR(100),
    masked_sender VARCHAR(100),
    payment_status VARCHAR(50) NOT NULL DEFAULT 'AWAITING_VERIFICATION',
    -- VERIFIED_SUCCESS, AWAITING_VERIFICATION, PENDING, UNMATCHED, REVIEW_REQUIRED, REFUND_PENDING, REFUNDED, FAILED, LATE_PAYMENT
    received_at TIMESTAMPTZ NOT NULL,
    matched_at TIMESTAMPTZ,
    verified_at TIMESTAMPTZ,
    verified_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reconciliation_source VARCHAR(100) DEFAULT 'BANK_STATEMENT',
    receipt_number VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pb_tx_school_status ON public.payment_transactions(school_id, payment_status);
CREATE INDEX IF NOT EXISTS idx_pb_tx_student ON public.payment_transactions(school_id, student_id);
CREATE INDEX IF NOT EXISTS idx_pb_tx_invoice ON public.payment_transactions(school_id, invoice_id);
CREATE INDEX IF NOT EXISTS idx_pb_tx_received_at ON public.payment_transactions(school_id, received_at DESC);

-- ----------------------------------------------------------------------------
-- 6. AUTHORITATIVE BANK TRANSACTIONS & RECONCILIATION
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_bank_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    account_number VARCHAR(100) NOT NULL,
    utr_number VARCHAR(150) NOT NULL,
    amount_paise BIGINT NOT NULL,
    transaction_type VARCHAR(20) NOT NULL DEFAULT 'CR', -- CR, DR
    transaction_date TIMESTAMPTZ NOT NULL,
    value_date DATE,
    narration TEXT,
    statement_file_id VARCHAR(200),
    is_reconciled BOOLEAN NOT NULL DEFAULT FALSE,
    reconciled_transaction_id UUID REFERENCES public.payment_transactions(id) ON DELETE SET NULL,
    imported_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_pb_bank_tx UNIQUE (school_id, utr_number, amount_paise)
);

CREATE INDEX IF NOT EXISTS idx_pb_bank_tx_lookup ON public.payment_bank_transactions(school_id, utr_number, is_reconciled);

CREATE TABLE IF NOT EXISTS public.payment_reconciliation_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    run_type VARCHAR(50) NOT NULL DEFAULT 'MANUAL_STATEMENT_IMPORT',
    total_candidates_processed INTEGER NOT NULL DEFAULT 0,
    total_verified INTEGER NOT NULL DEFAULT 0,
    total_unmatched INTEGER NOT NULL DEFAULT 0,
    total_review_required INTEGER NOT NULL DEFAULT 0,
    run_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.payment_reconciliation_matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reconciliation_run_id UUID REFERENCES public.payment_reconciliation_runs(id) ON DELETE CASCADE,
    transaction_id UUID NOT NULL REFERENCES public.payment_transactions(id) ON DELETE CASCADE,
    bank_transaction_id UUID NOT NULL REFERENCES public.payment_bank_transactions(id) ON DELETE CASCADE,
    match_rule VARCHAR(100) NOT NULL,
    reconciled_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 7. UNMATCHED QUEUE, MANUAL REVIEWS & REFUNDS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_unmatched_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    notification_event_id UUID NOT NULL REFERENCES public.payment_notification_events(id) ON DELETE CASCADE,
    amount_paise BIGINT NOT NULL,
    transaction_reference VARCHAR(150),
    source_app VARCHAR(100),
    sender_info VARCHAR(200),
    received_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'OPEN', -- OPEN, RESOLVED, IGNORED
    resolution_notes TEXT,
    resolved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pb_unmatched_school_status ON public.payment_unmatched_transactions(school_id, status);

CREATE TABLE IF NOT EXISTS public.payment_manual_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    notification_event_id UUID NOT NULL REFERENCES public.payment_notification_events(id) ON DELETE CASCADE,
    transaction_id UUID REFERENCES public.payment_transactions(id) ON DELETE CASCADE,
    review_reason VARCHAR(150) NOT NULL,
    possible_matches JSONB DEFAULT '[]'::jsonb,
    assigned_to UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'PENDING', -- PENDING, APPROVED, REJECTED
    reviewer_notes TEXT,
    reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pb_reviews_school_status ON public.payment_manual_reviews(school_id, status);

CREATE TABLE IF NOT EXISTS public.payment_refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    transaction_id UUID REFERENCES public.payment_transactions(id) ON DELETE SET NULL,
    student_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    refund_reference VARCHAR(100) NOT NULL UNIQUE,
    amount_paise BIGINT NOT NULL CHECK (amount_paise > 0),
    reason TEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'REFUND_PENDING', -- REFUND_PENDING, REFUNDED, REJECTED
    initiated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pb_refunds_school_status ON public.payment_refunds(school_id, status);

-- ----------------------------------------------------------------------------
-- 8. AUDIT LOGS & SYNC LOGS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    entity_type VARCHAR(100) NOT NULL,
    entity_id VARCHAR(100) NOT NULL,
    action VARCHAR(100) NOT NULL,
    previous_state JSONB,
    new_state JSONB,
    performed_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    ip_address VARCHAR(100),
    user_agent VARCHAR(200),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE IF EXISTS public.payment_audit_logs ADD COLUMN IF NOT EXISTS timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_pb_audit_school_ts ON public.payment_audit_logs(school_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_pb_audit_entity ON public.payment_audit_logs(entity_type, entity_id);

CREATE TABLE IF NOT EXISTS public.payment_sync_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_pk UUID REFERENCES public.payment_bridge_devices(id) ON DELETE CASCADE,
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    sync_type VARCHAR(50) NOT NULL DEFAULT 'BATCH_NOTIFICATION',
    batch_size INTEGER NOT NULL,
    successful_count INTEGER NOT NULL,
    failed_count INTEGER NOT NULL DEFAULT 0,
    duplicate_count INTEGER NOT NULL DEFAULT 0,
    duration_ms NUMERIC(10,2) DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pb_sync_logs_device ON public.payment_sync_logs(device_pk, created_at DESC);


-- ----------------------------------------------------------------------------
-- 9. SEED ESSENTIAL DATA FOR GREENWOOD HIGH SCHOOL
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    v_school_id UUID := '33333333-3333-3333-3333-333333333333';
    v_device_pk UUID := '44444444-4444-4444-4444-444444444444';
    v_student_seema UUID := '33333333-0000-0000-0000-000000000001';
    v_student_mohan UUID := '33333333-0000-0000-0000-000000000002';
    v_student_amit  UUID := '33333333-0000-0000-0000-000000000003';
    v_student_riya  UUID := '33333333-0000-0000-0000-000000000004';
    v_student_rohan UUID := '33333333-0000-0000-0000-000000000005';

    v_inv_seema UUID := '55555555-0000-0000-0000-000000000001';
    v_inv_mohan UUID := '55555555-0000-0000-0000-000000000002';
    v_inv_amit  UUID := '55555555-0000-0000-0000-000000000003';
    v_inv_riya  UUID := '55555555-0000-0000-0000-000000000004';
    v_inv_rohan UUID := '55555555-0000-0000-0000-000000000005';

    v_intent_seema UUID := '66666666-0000-0000-0000-000000000001';
    v_intent_mohan UUID := '66666666-0000-0000-0000-000000000002';
    v_intent_amit  UUID := '66666666-0000-0000-0000-000000000003';
    v_intent_rohan UUID := '66666666-0000-0000-0000-000000000005';

    v_event_seema UUID := '77777777-0000-0000-0000-000000000001';
    v_event_mohan UUID := '77777777-0000-0000-0000-000000000002';
    v_event_unmatched UUID := '77777777-0000-0000-0000-000000000003';
    v_event_ignored UUID := '77777777-0000-0000-0000-000000000004';
    v_event_rohan UUID := '77777777-0000-0000-0000-000000000005';
BEGIN
    -- 1. Ensure Greenwood High School
    IF NOT EXISTS (SELECT 1 FROM public.schools WHERE id = v_school_id) THEN
        INSERT INTO public.schools (id, name, address, phone, owner_email, owner_name, subscription_status, created_at)
        VALUES (v_school_id, 'Greenwood High School', 'Varthur Road, Bengaluru, Karnataka', '+91 80 2843 8900', 'finance@greenwoodhigh.edu.in', 'Principal Administrator', 'ACTIVE', NOW());
    END IF;

    -- 2. Seed Student Profiles
    INSERT INTO public.profiles (id, school_id, user_id, full_name, email, role, phone, created_at, updated_at)
    VALUES 
        (v_student_seema, v_school_id, 'u_seema_1042', 'Seema', 'seema.student@greenwoodhigh.edu.in', 'student', '+91 98210 11223', NOW(), NOW()),
        (v_student_mohan, v_school_id, 'u_mohan_1041', 'Mohan', 'mohan.student@greenwoodhigh.edu.in', 'student', '+91 77120 44556', NOW(), NOW()),
        (v_student_amit,  v_school_id, 'u_amit_1043',  'Amit',  'amit.student@greenwoodhigh.edu.in',  'student', '+91 99880 77665', NOW(), NOW()),
        (v_student_riya,  v_school_id, 'u_riya_1022',  'Riya',  'riya.student@greenwoodhigh.edu.in',  'student', '+91 98765 43210', NOW(), NOW()),
        (v_student_rohan, v_school_id, 'u_rohan_1039', 'Rohan', 'rohan.student@greenwoodhigh.edu.in', 'student', '+91 96631 88990', NOW(), NOW())
    ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name;

    -- 3. Seed Fee Invoices
    INSERT INTO public.student_fee_invoices (id, school_id, student_id, invoice_number, title, fee_type, due_date, subtotal, total_billed, paid_amount, balance_amount, status, created_at)
    VALUES
        (v_inv_seema, v_school_id, v_student_seema, 'INV-1042', 'Annual Tuition Fee', 'Tuition Fee', '2026-11-30', 2000.00, 2000.00, 2000.00, 0.00, 'Paid', NOW() - INTERVAL '2 days'),
        (v_inv_mohan, v_school_id, v_student_mohan, 'INV-1041', 'Annual Tuition Fee', 'Tuition Fee', '2026-11-30', 2000.00, 2000.00, 2000.00, 0.00, 'Paid', NOW() - INTERVAL '3 days'),
        (v_inv_amit,  v_school_id, v_student_amit,  'INV-1043', 'Annual Tuition Fee', 'Tuition Fee', '2026-11-30', 12000.00, 12000.00, 0.00, 12000.00, 'Pending', NOW() - INTERVAL '1 day'),
        (v_inv_riya,  v_school_id, v_student_riya,  'INV-1022', 'Library & Caution Deposit', 'Library', '2026-11-20', 500.00, 500.00, 500.00, 0.00, 'Paid', NOW() - INTERVAL '10 days'),
        (v_inv_rohan, v_school_id, v_student_rohan, 'INV-1039', 'Transport & Sports Fee', 'Transport', '2026-11-25', 3500.00, 3500.00, 3500.00, 0.00, 'Paid', NOW() - INTERVAL '4 days')
    ON CONFLICT (id) DO NOTHING;

    -- 4. Seed Settings
    INSERT INTO public.payment_bridge_settings (school_id, sync_interval_seconds, retry_interval_seconds, duplicate_detection_window_minutes, auto_start_on_boot, server_url)
    VALUES (v_school_id, 30, 60, 5, TRUE, 'https://erp.edushamiit.in/api/v1/payments')
    ON CONFLICT (school_id) DO UPDATE SET sync_interval_seconds = 30;

    -- 5. Seed Monitored Applications
    INSERT INTO public.payment_bridge_monitored_apps (school_id, app_name, package_name, is_enabled, icon_name)
    VALUES
        (v_school_id, 'PhonePe', 'com.phonepe.app', TRUE, 'phonepe'),
        (v_school_id, 'Google Pay', 'com.google.android.apps.nbu.paisa.user', TRUE, 'google_pay'),
        (v_school_id, 'Paytm', 'net.one97.paytm', TRUE, 'paytm'),
        (v_school_id, 'BHIM UPI', 'in.org.npci.upiapp', TRUE, 'bhim')
    ON CONFLICT (school_id, package_name) DO UPDATE SET is_enabled = EXCLUDED.is_enabled;

    -- 6. Seed Device
    INSERT INTO public.payment_bridge_devices (id, school_id, device_id, device_name, model, android_version, app_version, status, is_online, battery_level, last_sync_at)
    VALUES (v_device_pk, v_school_id, 'PB-AND-001', 'Greenwood Accounts Mobile Terminal', 'Pixel 8', 'Android 14', '1.0.0', 'ACTIVE', TRUE, 92, NOW())
    ON CONFLICT (device_id) DO UPDATE SET is_online = TRUE, last_sync_at = NOW();

    -- 7. Seed Payment Intents (with unique paise)
    INSERT INTO public.payment_intents (id, school_id, student_id, invoice_id, intent_reference, base_amount_paise, total_amount_paise, unique_paise, upi_vpa, status)
    VALUES
        (v_intent_seema, v_school_id, v_student_seema, v_inv_seema, 'EDU202611140042', 200000, 200034, 34, 'greenwoodhigh@ybl', 'VERIFIED_SUCCESS'),
        (v_intent_mohan, v_school_id, v_student_mohan, v_inv_mohan, 'EDU202611140041', 200000, 200005, 5, 'greenwoodhigh@ybl', 'VERIFIED_SUCCESS'),
        (v_intent_amit,  v_school_id, v_student_amit,  v_inv_amit,  'EDU202611140043', 1200000, 1200000, 0, 'greenwoodhigh@ybl', 'PENDING'),
        (v_intent_rohan, v_school_id, v_student_rohan, v_inv_rohan, 'EDU202611130039', 350000, 350000, 0, 'greenwoodhigh@ybl', 'VERIFIED_SUCCESS')
    ON CONFLICT (intent_reference) DO NOTHING;

    -- 8. Seed Notification Events (Exact matches from screenshots)
    INSERT INTO public.payment_notification_events (
        id, event_uuid, school_id, device_pk, device_id, source_package, source_app, event_type,
        amount_paise, sender_name, masked_sender_identifier, transaction_reference,
        notification_timestamp, raw_title, raw_text, parser_version, confidence_score,
        parsing_status, candidate_match_status, matched_intent_id, sync_status
    )
    VALUES
        (v_event_seema, '88888888-0000-0000-0000-000000000001', v_school_id, v_device_pk, 'PB-AND-001', 'com.phonepe.app', 'PhonePe', 'PAYMENT_RECEIVED',
         200034, 'Seema Parent', '**** 9821', 'UPI/438729106731', NOW() - INTERVAL '15 minutes', 'Payment Received', 'Received Rs 2000.34 from **** 9821 Ref: UPI/438729106731', '1.0.0', 'HIGH',
         'PARSED', 'MATCHED_CANDIDATE', v_intent_seema, 'SYNCED'),
        (v_event_mohan, '88888888-0000-0000-0000-000000000002', v_school_id, v_device_pk, 'PB-AND-001', 'com.google.android.apps.nbu.paisa.user', 'Google Pay', 'PAYMENT_RECEIVED',
         200005, 'Mohan Parent', '**** 7712', 'GPay-319870221', NOW() - INTERVAL '25 minutes', 'Payment Received', 'You received Rs 2000.05 from **** 7712 (Ref GPay-319870221)', '1.0.0', 'HIGH',
         'PARSED', 'MATCHED_CANDIDATE', v_intent_mohan, 'SYNCED'),
        (v_event_unmatched, '88888888-0000-0000-0000-000000000003', v_school_id, v_device_pk, 'PB-AND-001', 'com.phonepe.app', 'PhonePe', 'PAYMENT_RECEIVED',
         150000, 'Unknown Sender', '**** 2244', 'UPI/438721993421', NOW() - INTERVAL '40 minutes', 'Payment Received', 'Received Rs 1500.00 from **** 2244 Ref: UPI/438721993421', '1.0.0', 'HIGH',
         'PARSED', 'UNMATCHED', NULL, 'SYNCED'),
        (v_event_ignored, '88888888-0000-0000-0000-000000000004', v_school_id, v_device_pk, 'PB-AND-001', 'com.google.android.apps.nbu.paisa.user', 'Google Pay', 'PAYMENT_SENT',
         50000, 'Vendor Stationary', '**** 1100', 'GPay-88990011', NOW() - INTERVAL '70 minutes', 'Payment Sent', 'Paid Rs 500.00 to Vendor Stationary', '1.0.0', 'HIGH',
         'PARSED', 'IGNORED', NULL, 'SYNCED'),
        (v_event_rohan, '88888888-0000-0000-0000-000000000005', v_school_id, v_device_pk, 'PB-AND-001', 'com.phonepe.app', 'PhonePe', 'PAYMENT_RECEIVED',
         350000, 'Rohan Father', '**** 6631', 'UPI/438720554821', NOW() - INTERVAL '1 day', 'Payment Received', 'Received Rs 3500.00 from **** 6631 Ref: UPI/438720554821', '1.0.0', 'HIGH',
         'PARSED', 'MATCHED_CANDIDATE', v_intent_rohan, 'SYNCED')
    ON CONFLICT (event_uuid) DO NOTHING;

    -- 9. Seed Candidate Matches
    INSERT INTO public.payment_candidate_matches (school_id, notification_event_id, payment_intent_id, match_rule, match_score, status)
    VALUES
        (v_school_id, v_event_seema, v_intent_seema, 'UNIQUE_PAISE_MATCH', 100.0, 'CONFIRMED'),
        (v_school_id, v_event_mohan, v_intent_mohan, 'UNIQUE_PAISE_MATCH', 100.0, 'CONFIRMED'),
        (v_school_id, v_event_rohan, v_intent_rohan, 'EXACT_UTR', 100.0, 'CONFIRMED')
    ON CONFLICT (notification_event_id, payment_intent_id) DO NOTHING;

    -- 10. Seed Bank Transaction Evidence (Authoritative Proof)
    INSERT INTO public.payment_bank_transactions (id, school_id, account_number, utr_number, amount_paise, transaction_type, transaction_date, narration, is_reconciled)
    VALUES
        ('99999999-0000-0000-0000-000000000001', v_school_id, 'HDFC0001234-9876', 'UPI/438729106731', 200034, 'CR', NOW() - INTERVAL '14 minutes', 'UPI-SEEMA-FEE-438729106731', TRUE),
        ('99999999-0000-0000-0000-000000000002', v_school_id, 'HDFC0001234-9876', 'GPay-319870221', 200005, 'CR', NOW() - INTERVAL '24 minutes', 'UPI-MOHAN-FEE-319870221', TRUE),
        ('99999999-0000-0000-0000-000000000005', v_school_id, 'HDFC0001234-9876', 'UPI/438720554821', 350000, 'CR', NOW() - INTERVAL '1 day', 'UPI-ROHAN-FEE-438720554821', TRUE)
    ON CONFLICT (school_id, utr_number, amount_paise) DO NOTHING;

    -- 11. Seed Transactions (Matching the screenshots!)
    INSERT INTO public.payment_transactions (
        id, school_id, student_id, invoice_id, payment_intent_id, notification_event_id, bank_transaction_id,
        transaction_reference, amount_paise, base_fee_paise, excess_paise, payment_mode, upi_app, masked_sender,
        payment_status, received_at, matched_at, verified_at, receipt_number
    )
    VALUES
        ('aaaaaaaa-0000-0000-0000-000000000001', v_school_id, v_student_seema, v_inv_seema, v_intent_seema, v_event_seema, '99999999-0000-0000-0000-000000000001',
         'UPI/438729106731', 200034, 200000, 34, 'UPI (PhonePe)', 'PhonePe', '**** 9821',
         'VERIFIED_SUCCESS', NOW() - INTERVAL '15 minutes', NOW() - INTERVAL '15 minutes', NOW() - INTERVAL '14 minutes', 'RCP-2026-001042'),
        ('aaaaaaaa-0000-0000-0000-000000000002', v_school_id, v_student_mohan, v_inv_mohan, v_intent_mohan, v_event_mohan, '99999999-0000-0000-0000-000000000002',
         'GPay-319870221', 200005, 200000, 5, 'UPI (Google Pay)', 'Google Pay', '**** 7712',
         'VERIFIED_SUCCESS', NOW() - INTERVAL '25 minutes', NOW() - INTERVAL '25 minutes', NOW() - INTERVAL '24 minutes', 'RCP-2026-001041'),
        ('aaaaaaaa-0000-0000-0000-000000000003', v_school_id, NULL, NULL, NULL, v_event_unmatched, NULL,
         'UPI/438721993421', 150000, 150000, 0, 'UPI (PhonePe)', 'PhonePe', '**** 2244',
         'UNMATCHED', NOW() - INTERVAL '40 minutes', NULL, NULL, NULL),
        ('aaaaaaaa-0000-0000-0000-000000000004', v_school_id, v_student_amit, v_inv_amit, v_intent_amit, NULL, NULL,
         NULL, 1200000, 1200000, 0, 'UPI (Pending)', 'Pending Intent', '**** 0000',
         'PENDING', NOW() - INTERVAL '50 minutes', NULL, NULL, NULL),
        ('aaaaaaaa-0000-0000-0000-000000000005', v_school_id, v_student_riya, v_inv_riya, NULL, NULL, NULL,
         'RF-00018', 50000, 50000, 0, 'UPI (Refund)', 'Refund Processed', '**** 3321',
         'REFUNDED', NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day', 'REF-2026-000018'),
        ('aaaaaaaa-0000-0000-0000-000000000006', v_school_id, v_student_rohan, v_inv_rohan, v_intent_rohan, v_event_rohan, '99999999-0000-0000-0000-000000000005',
         'UPI/438720554821', 350000, 350000, 0, 'UPI (PhonePe)', 'PhonePe', '**** 6631',
         'VERIFIED_SUCCESS', NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day', 'RCP-2026-001039')
    ON CONFLICT (id) DO NOTHING;

    -- 12. Seed Refund record
    INSERT INTO public.payment_refunds (school_id, transaction_id, student_id, refund_reference, amount_paise, reason, status, processed_at)
    VALUES (v_school_id, 'aaaaaaaa-0000-0000-0000-000000000005', v_student_riya, 'RF-00018', 50000, 'Security caution deposit return on course completion', 'REFUNDED', NOW() - INTERVAL '1 day')
    ON CONFLICT (refund_reference) DO NOTHING;

    -- 13. Seed Unmatched record
    INSERT INTO public.payment_unmatched_transactions (school_id, notification_event_id, amount_paise, transaction_reference, source_app, sender_info, received_at, status)
    VALUES (v_school_id, v_event_unmatched, 150000, 'UPI/438721993421', 'PhonePe', '**** 2244', NOW() - INTERVAL '40 minutes', 'OPEN')
    ON CONFLICT DO NOTHING;

    -- 14. Seed Audit log
    INSERT INTO public.payment_audit_logs (school_id, entity_type, entity_id, action, performed_by, previous_state, new_state)
    VALUES 
        (v_school_id, 'TRANSACTION', 'aaaaaaaa-0000-0000-0000-000000000001', 'VERIFIED', 'SYSTEM_BANK_MATCH', '{"status": "AWAITING_VERIFICATION"}'::jsonb, '{"status": "VERIFIED_SUCCESS", "utr": "UPI/438729106731"}'::jsonb),
        (v_school_id, 'NOTIFICATION', '77777777-0000-0000-0000-000000000001', 'MATCHED', 'SYSTEM_MATCHER', '{"status": "PARSED"}'::jsonb, '{"status": "MATCHED_CANDIDATE", "intent": "EDU202611140042"}'::jsonb)
    ON CONFLICT DO NOTHING;

END $$;
