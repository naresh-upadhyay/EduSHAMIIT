-- Migration 328: PayU Payment Gateway & Universal Payment Architecture
-- Includes payment_orders, payment_attempts, payment_gateway_settings, payment_receipts tables and functions.

-- 1. PAYMENT ORDERS TABLE (Logical orders for subscription, registration, plan purchases)
CREATE TABLE IF NOT EXISTS public.payment_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  public_id TEXT UNIQUE NOT NULL DEFAULT ('ORD-' || upper(substr(md5(random()::text), 1, 10))),
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  provider TEXT NOT NULL DEFAULT 'PAYU', -- 'PAYU', 'CASHFREE'
  provider_environment TEXT NOT NULL DEFAULT 'TEST', -- 'TEST', 'PRODUCTION'
  transaction_id TEXT UNIQUE NOT NULL,
  provider_order_id TEXT,
  provider_payment_id TEXT,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  currency TEXT NOT NULL DEFAULT 'INR',
  purpose TEXT NOT NULL DEFAULT 'SCHOOL_REGISTRATION', -- 'SUBSCRIPTION', 'PLAN_PURCHASE', 'SCHOOL_REGISTRATION'
  plan_id UUID REFERENCES public.subscription_plans(id) ON DELETE SET NULL,
  plan_code TEXT,
  plan_name TEXT,
  billing_cycle TEXT DEFAULT 'monthly', -- 'monthly', 'yearly'
  customer_name TEXT NOT NULL,
  customer_email TEXT NOT NULL,
  customer_phone TEXT,
  status TEXT NOT NULL DEFAULT 'CREATED', -- 'CREATED', 'PENDING', 'PROCESSING', 'SUCCESS', 'FAILED', 'CANCELLED', 'EXPIRED', 'REFUNDED', 'PARTIALLY_REFUNDED', 'PAYMENT_REVIEW_REQUIRED'
  failure_reason TEXT,
  checkout_url TEXT,
  idempotency_key TEXT UNIQUE,
  provider_response JSONB DEFAULT '{}'::jsonb,
  provider_metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

-- Constraints
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'chk_payment_orders_status' AND table_name = 'payment_orders'
  ) THEN
    ALTER TABLE public.payment_orders ADD CONSTRAINT chk_payment_orders_status
      CHECK (status IN ('CREATED', 'PENDING', 'PROCESSING', 'SUCCESS', 'FAILED', 'CANCELLED', 'EXPIRED', 'REFUNDED', 'PARTIALLY_REFUNDED', 'PAYMENT_REVIEW_REQUIRED'));
  END IF;
END $$;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_payment_orders_school_id ON public.payment_orders (school_id);
CREATE INDEX IF NOT EXISTS idx_payment_orders_user_id ON public.payment_orders (user_id);
CREATE INDEX IF NOT EXISTS idx_payment_orders_transaction_id ON public.payment_orders (transaction_id);
CREATE INDEX IF NOT EXISTS idx_payment_orders_provider_order ON public.payment_orders (provider_order_id);
CREATE INDEX IF NOT EXISTS idx_payment_orders_status ON public.payment_orders (status);
CREATE INDEX IF NOT EXISTS idx_payment_orders_created_at ON public.payment_orders (created_at DESC);

-- 2. PAYMENT ATTEMPTS TABLE (Individual payment attempt logs per order)
CREATE TABLE IF NOT EXISTS public.payment_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_order_id UUID NOT NULL REFERENCES public.payment_orders(id) ON DELETE CASCADE,
  provider TEXT NOT NULL DEFAULT 'PAYU',
  attempt_number INT NOT NULL DEFAULT 1,
  transaction_id TEXT UNIQUE NOT NULL,
  status TEXT NOT NULL DEFAULT 'PENDING',
  amount NUMERIC(12, 2) NOT NULL,
  checkout_url TEXT,
  provider_reference TEXT,
  failure_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_payment_attempts_order_id ON public.payment_attempts (payment_order_id);
CREATE INDEX IF NOT EXISTS idx_payment_attempts_txn_id ON public.payment_attempts (transaction_id);

-- 3. PAYMENT GATEWAY SETTINGS TABLE (SuperAdmin provider credentials configuration)
CREATE TABLE IF NOT EXISTS public.payment_gateway_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT UNIQUE NOT NULL DEFAULT 'PAYU', -- 'PAYU', 'CASHFREE'
  environment TEXT NOT NULL DEFAULT 'TEST', -- 'TEST', 'PRODUCTION'
  merchant_key TEXT,
  merchant_secret TEXT,
  salt TEXT,
  webhook_secret TEXT,
  is_enabled BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default PayU settings record if missing
INSERT INTO public.payment_gateway_settings (provider, environment, is_enabled)
VALUES ('PAYU', 'TEST', TRUE)
ON CONFLICT (provider) DO NOTHING;

-- 4. PAYMENT RECEIPTS TABLE
CREATE TABLE IF NOT EXISTS public.payment_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_number TEXT UNIQUE NOT NULL,
  payment_order_id UUID UNIQUE REFERENCES public.payment_orders(id) ON DELETE CASCADE,
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  school_name TEXT NOT NULL,
  customer_name TEXT NOT NULL,
  plan_name TEXT NOT NULL,
  billing_cycle TEXT NOT NULL,
  amount NUMERIC(12, 2) NOT NULL,
  currency TEXT DEFAULT 'INR',
  payment_date TIMESTAMPTZ DEFAULT NOW(),
  payment_method TEXT DEFAULT 'PayU Hosted Checkout',
  transaction_id TEXT NOT NULL,
  provider_reference TEXT,
  receipt_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_receipts_school_id ON public.payment_receipts (school_id);
CREATE INDEX IF NOT EXISTS idx_payment_receipts_receipt_number ON public.payment_receipts (receipt_number);

-- 5. RLS Policies
ALTER TABLE public.payment_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_gateway_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_receipts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "allow_all_payment_orders" ON public.payment_orders USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_payment_attempts" ON public.payment_attempts USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_payment_gateway_settings" ON public.payment_gateway_settings USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_payment_receipts" ON public.payment_receipts USING (true) WITH CHECK (true);

-- Updated_at Trigger for payment_orders and settings
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_payment_orders_updated_at'
  ) THEN
    CREATE TRIGGER trg_payment_orders_updated_at
      BEFORE UPDATE ON public.payment_orders
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_payment_gateway_settings_updated_at'
  ) THEN
    CREATE TRIGGER trg_payment_gateway_settings_updated_at
      BEFORE UPDATE ON public.payment_gateway_settings
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;
