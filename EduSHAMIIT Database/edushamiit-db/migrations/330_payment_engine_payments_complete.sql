-- Migration 330: Complete EduSHAMIIT Pay Payment Engine Schema Enhancement
-- Adds payment_attempts, payer_type, payment_purpose, failure diagnostics,
-- retry tracking, and enterprise financial indexes.

-- 1. ENHANCE PAYMENT ORDERS TABLE
ALTER TABLE public.payment_orders
  ADD COLUMN IF NOT EXISTS payer_type TEXT DEFAULT 'STUDENT' CHECK (payer_type IN ('STUDENT', 'PARENT', 'SCHOOL', 'CUSTOMER', 'STAFF', 'OTHER')),
  ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'UPI', -- 'UPI', 'CARD', 'NETBANKING', 'WALLET', 'QR', 'BANK_TRANSFER', 'OTHER'
  ADD COLUMN IF NOT EXISTS payment_purpose TEXT DEFAULT 'STUDENT_FEE', -- 'STUDENT_FEE', 'SCHOOL_SUBSCRIPTION', 'ADMISSION', 'TRANSPORT', 'EXAMINATION', 'LIBRARY', 'HOSTEL', 'MISCELLANEOUS', 'OTHER'
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS due_date DATE,
  ADD COLUMN IF NOT EXISTS reference_number TEXT,
  ADD COLUMN IF NOT EXISTS bank_ref_no TEXT,
  ADD COLUMN IF NOT EXISTS failure_code TEXT,
  ADD COLUMN IF NOT EXISTS failure_message TEXT,
  ADD COLUMN IF NOT EXISTS retry_count INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS current_attempt_id UUID,
  ADD COLUMN IF NOT EXISTS total_refunded NUMERIC(12, 2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS refundable_amount NUMERIC(12, 2);

-- Set refundable_amount default for existing rows if null
UPDATE public.payment_orders
SET refundable_amount = amount - COALESCE(total_refunded, 0)
WHERE refundable_amount IS NULL;

-- 2. CREATE PAYMENT ATTEMPTS TABLE IF NOT EXISTS
CREATE TABLE IF NOT EXISTS public.payment_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_order_id UUID NOT NULL REFERENCES public.payment_orders(id) ON DELETE CASCADE,
  attempt_number INT NOT NULL DEFAULT 1,
  transaction_id TEXT UNIQUE NOT NULL,
  provider TEXT NOT NULL DEFAULT 'MOCK_SANDBOX', -- 'SBI_EPAY', 'ICICI_EAZYPAY', 'HDFC_SMARTHUB', 'PAYU', 'CASHFREE', 'MOCK_SANDBOX'
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  currency TEXT NOT NULL DEFAULT 'INR',
  payment_method TEXT DEFAULT 'UPI',
  status TEXT NOT NULL DEFAULT 'INITIATED' CHECK (status IN ('INITIATED', 'PENDING', 'PROCESSING', 'SUCCESS', 'FAILED', 'CANCELLED', 'EXPIRED')),
  provider_reference TEXT,
  provider_order_id TEXT,
  gateway_response_code TEXT,
  gateway_response_message TEXT,
  failure_reason TEXT,
  checkout_url TEXT,
  qr_payload TEXT,
  upi_intent_url TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

-- Indexes for fast retrieval
CREATE INDEX IF NOT EXISTS idx_payment_attempts_order ON public.payment_attempts(payment_order_id);
CREATE INDEX IF NOT EXISTS idx_payment_attempts_txn ON public.payment_attempts(transaction_id);
CREATE INDEX IF NOT EXISTS idx_payment_attempts_status ON public.payment_attempts(status);
CREATE INDEX IF NOT EXISTS idx_payment_attempts_created ON public.payment_attempts(created_at DESC);

-- 3. ENHANCE PAYMENT ORDERS PERFORMANCE INDEXES
CREATE INDEX IF NOT EXISTS idx_payment_orders_payer_type ON public.payment_orders(payer_type);
CREATE INDEX IF NOT EXISTS idx_payment_orders_payment_method ON public.payment_orders(payment_method);
CREATE INDEX IF NOT EXISTS idx_payment_orders_purpose ON public.payment_orders(payment_purpose);
CREATE INDEX IF NOT EXISTS idx_payment_orders_amount ON public.payment_orders(amount);
CREATE INDEX IF NOT EXISTS idx_payment_orders_due_date ON public.payment_orders(due_date);

-- 4. RLS POLICIES FOR PAYMENT ATTEMPTS
ALTER TABLE public.payment_attempts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "allow_all_payment_attempts_policy" ON public.payment_attempts USING (true) WITH CHECK (true);

-- 5. TRIGGER FOR UPDATING REFUNDABLE AMOUNT
CREATE OR REPLACE FUNCTION update_payment_refundable_amount()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.amount IS NOT NULL AND NEW.total_refunded IS NOT NULL THEN
    NEW.refundable_amount := GREATEST(0, NEW.amount - NEW.total_refunded);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_update_payment_refundable_amount'
  ) THEN
    CREATE TRIGGER trg_update_payment_refundable_amount
      BEFORE INSERT OR UPDATE OF amount, total_refunded ON public.payment_orders
      FOR EACH ROW EXECUTE FUNCTION update_payment_refundable_amount();
  END IF;
END $$;
