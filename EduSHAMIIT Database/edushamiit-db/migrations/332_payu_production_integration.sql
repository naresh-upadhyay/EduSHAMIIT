-- Migration 332: Production-Grade PayU Payment Gateway Integration Enhancements
-- Adds extended credential columns, payment order lifecycle states, and idempotency indexes.

-- 1. Extend payment_gateways table with client ID and secrets if not present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'payment_gateways' AND column_name = 'client_id'
  ) THEN
    ALTER TABLE public.payment_gateways ADD COLUMN client_id TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'payment_gateways' AND column_name = 'success_url'
  ) THEN
    ALTER TABLE public.payment_gateways ADD COLUMN success_url TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'payment_gateways' AND column_name = 'failure_url'
  ) THEN
    ALTER TABLE public.payment_gateways ADD COLUMN failure_url TEXT;
  END IF;
END $$;

-- 2. Enhance payment_orders status check constraint if exists
DO $$
BEGIN
  ALTER TABLE public.payment_orders DROP CONSTRAINT IF EXISTS chk_payment_orders_status;
  ALTER TABLE public.payment_orders ADD CONSTRAINT chk_payment_orders_status
    CHECK (status IN (
      'CREATED', 'PAYU_CHECKOUT', 'PENDING', 'PROCESSING', 
      'SUCCESS', 'FAILED', 'CANCELLED', 'EXPIRED', 
      'REFUND_PENDING', 'REFUNDED', 'PARTIALLY_REFUNDED', 
      'RECONCILIATION_PENDING', 'RECONCILED', 'PAYMENT_AMOUNT_MISMATCH',
      'PAYMENT_REVIEW_REQUIRED'
    ));
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- 3. Ensure webhook idempotency tracking in payment_gateway_webhooks
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'payment_gateway_webhooks' AND column_name = 'payload_hash'
  ) THEN
    ALTER TABLE public.payment_gateway_webhooks ADD COLUMN payload_hash TEXT;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_gateway_webhooks_payload_hash 
  ON public.payment_gateway_webhooks(payload_hash);

-- 4. Audit Log Indexes for rapid query in PGI screen
CREATE INDEX IF NOT EXISTS idx_payment_audit_logs_order 
  ON public.payment_audit_logs(payment_order_id);
CREATE INDEX IF NOT EXISTS idx_payment_audit_logs_action 
  ON public.payment_audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_payment_audit_logs_created 
  ON public.payment_audit_logs(created_at DESC);
