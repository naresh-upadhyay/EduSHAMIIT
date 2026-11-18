-- ============================================================================
-- Migration 532: Add device_id to payment_bridge_monitored_apps and add custom parsers table
-- Author: Antigravity
-- Date: 2026-11-18
-- ============================================================================

-- 1. Add device_id to payment_bridge_monitored_apps if missing
ALTER TABLE public.payment_bridge_monitored_apps 
ADD COLUMN IF NOT EXISTS device_id VARCHAR(100);

-- 2. Create custom regex parsers table for fully dynamic parser studio persistence
CREATE TABLE IF NOT EXISTS public.payment_bridge_custom_parsers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    package_name VARCHAR(200) NOT NULL,
    app_name VARCHAR(100) NOT NULL DEFAULT 'Custom App',
    amount_regex TEXT,
    sender_regex TEXT,
    reference_regex TEXT,
    bank_regex TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_pb_custom_parsers_pkg UNIQUE (school_id, package_name)
);

CREATE INDEX IF NOT EXISTS idx_pb_custom_parsers_school_pkg 
ON public.payment_bridge_custom_parsers(school_id, package_name);
