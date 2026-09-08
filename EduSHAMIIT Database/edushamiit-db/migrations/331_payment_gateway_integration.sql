-- Migration 331: Complete EduSHAMIIT Pay Payment Gateway Integration (PGI) Schema
-- Provides multi-tenant gateway configurations, routing engine, health checks,
-- webhook logs, and immutable gateway event audit trail.

-- 1. PAYMENT GATEWAYS TABLE
CREATE TABLE IF NOT EXISTS public.payment_gateways (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE, -- NULL for EduSHAMIIT Platform level
  provider TEXT NOT NULL CHECK (provider IN ('RAZORPAY', 'PAYU', 'CASHFREE', 'SBI', 'PAYPAL')),
  display_name TEXT NOT NULL,
  integration_type TEXT NOT NULL DEFAULT 'MERCHANT_API' CHECK (integration_type IN ('MERCHANT_API', 'UPI_QR')),
  environment TEXT NOT NULL DEFAULT 'SANDBOX' CHECK (environment IN ('SANDBOX', 'PRODUCTION')),
  status TEXT NOT NULL DEFAULT 'NOT_CONFIGURED' CHECK (status IN ('NOT_CONFIGURED', 'CONFIGURING', 'CONNECTED', 'ACTIVE', 'DISABLED', 'DEGRADED', 'ERROR', 'SUSPENDED')),
  is_default BOOLEAN NOT NULL DEFAULT false,
  merchant_identifier TEXT,
  credentials_encrypted JSONB NOT NULL DEFAULT '{}'::jsonb, -- Masked/Encrypted secret key envelope
  supported_methods TEXT[] NOT NULL DEFAULT ARRAY['UPI', 'CARD', 'NET_BANKING'],
  webhook_endpoint TEXT,
  webhook_secret_encrypted TEXT,
  last_health_check_at TIMESTAMPTZ,
  last_health_status TEXT CHECK (last_health_status IS NULL OR last_health_status IN ('SUCCESS', 'FAILED', 'WARNING')),
  last_health_latency_ms INTEGER,
  last_health_error TEXT,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Unique index per tenant, provider, and environment
CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_gateways_tenant_provider_env
  ON public.payment_gateways (COALESCE(school_id, '00000000-0000-0000-0000-000000000000'::uuid), provider, environment);

-- Partial index ensuring only one default gateway per tenant and environment
CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_gateways_single_default
  ON public.payment_gateways (COALESCE(school_id, '00000000-0000-0000-0000-000000000000'::uuid), environment)
  WHERE (is_default = true);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_payment_gateways_school ON public.payment_gateways(school_id);
CREATE INDEX IF NOT EXISTS idx_payment_gateways_provider ON public.payment_gateways(provider);
CREATE INDEX IF NOT EXISTS idx_payment_gateways_status ON public.payment_gateways(status);
CREATE INDEX IF NOT EXISTS idx_payment_gateways_env ON public.payment_gateways(environment);

-- 2. PAYMENT ROUTING RULES TABLE
CREATE TABLE IF NOT EXISTS public.payment_gateway_routing_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
  payment_type TEXT NOT NULL CHECK (payment_type IN ('SCHOOL_FEE', 'SUBSCRIPTION', 'ADMISSION', 'EXAM', 'HOSTEL', 'TRANSPORT', 'MISC', 'ALL')),
  payment_method TEXT NOT NULL CHECK (payment_method IN ('UPI', 'CARD', 'NET_BANKING', 'WALLET', 'QR', 'INTERNATIONAL', 'ALL')),
  gateway_id UUID NOT NULL REFERENCES public.payment_gateways(id) ON DELETE CASCADE,
  fallback_gateway_id UUID REFERENCES public.payment_gateways(id) ON DELETE SET NULL,
  priority INTEGER NOT NULL DEFAULT 1 CHECK (priority >= 1),
  is_active BOOLEAN NOT NULL DEFAULT true,
  conditions JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_routing_rules_school ON public.payment_gateway_routing_rules(school_id);
CREATE INDEX IF NOT EXISTS idx_routing_rules_type_method ON public.payment_gateway_routing_rules(payment_type, payment_method);
CREATE INDEX IF NOT EXISTS idx_routing_rules_priority ON public.payment_gateway_routing_rules(priority);

-- 3. GATEWAY HEALTH CHECKS TABLE
CREATE TABLE IF NOT EXISTS public.payment_gateway_health_checks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gateway_id UUID NOT NULL REFERENCES public.payment_gateways(id) ON DELETE CASCADE,
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('SUCCESS', 'FAILED', 'WARNING')),
  latency_ms INTEGER NOT NULL DEFAULT 0,
  error_message TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  checked_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_health_checks_gateway ON public.payment_gateway_health_checks(gateway_id);
CREATE INDEX IF NOT EXISTS idx_health_checks_checked_at ON public.payment_gateway_health_checks(checked_at DESC);

-- 4. GATEWAY EVENTS / AUDIT LOG TABLE
CREATE TABLE IF NOT EXISTS public.payment_gateway_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gateway_id UUID REFERENCES public.payment_gateways(id) ON DELETE CASCADE,
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  event_source TEXT NOT NULL DEFAULT 'SYSTEM',
  severity TEXT NOT NULL DEFAULT 'INFO' CHECK (severity IN ('INFO', 'WARNING', 'ERROR', 'CRITICAL')),
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gateway_events_gateway ON public.payment_gateway_events(gateway_id);
CREATE INDEX IF NOT EXISTS idx_gateway_events_school ON public.payment_gateway_events(school_id);
CREATE INDEX IF NOT EXISTS idx_gateway_events_created ON public.payment_gateway_events(created_at DESC);

-- 5. GATEWAY WEBHOOKS LOG TABLE
CREATE TABLE IF NOT EXISTS public.payment_gateway_webhooks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gateway_id UUID REFERENCES public.payment_gateways(id) ON DELETE SET NULL,
  provider TEXT NOT NULL,
  event_id TEXT,
  event_type TEXT,
  signature_verified BOOLEAN NOT NULL DEFAULT false,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  headers JSONB NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'PROCESSED' CHECK (status IN ('RECEIVED', 'PROCESSED', 'IGNORED_DUPLICATE', 'FAILED')),
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gateway_webhooks_gateway ON public.payment_gateway_webhooks(gateway_id);
CREATE INDEX IF NOT EXISTS idx_gateway_webhooks_event ON public.payment_gateway_webhooks(provider, event_id);
CREATE INDEX IF NOT EXISTS idx_gateway_webhooks_created ON public.payment_gateway_webhooks(created_at DESC);
