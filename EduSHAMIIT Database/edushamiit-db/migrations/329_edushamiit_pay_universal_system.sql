-- Migration 329: EDU SHAMIIT PAY Universal Multi-Tenant Payment System
-- Supports two strictly separated payment ecosystems:
--   1. ECOSYSTEM 1: EduSHAMIIT Subscription Payments (Schools paying EduSHAMIIT corporate)
--   2. ECOSYSTEM 2: School Fee Collections (Parents paying School's own bank account)

-- 1. MERCHANT ACCOUNTS TABLE (Multi-tenant acquiring configurations)
CREATE TABLE IF NOT EXISTS public.merchant_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_type TEXT NOT NULL CHECK (owner_type IN ('EDUSHAMIIT', 'SCHOOL')),
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
  merchant_name TEXT NOT NULL,
  provider_code TEXT NOT NULL DEFAULT 'MOCK_SANDBOX', -- 'MOCK_SANDBOX', 'PAYU', 'CASHFREE', 'SBI_EPAY', 'ICICI_EAZYPAY', 'HDFC_SMARTHUB', 'AXIS_BANK'
  merchant_identifier TEXT NOT NULL, -- e.g. Merchant ID, Sub-merchant ID, Client ID
  credentials_encrypted JSONB NOT NULL DEFAULT '{}'::jsonb, -- encrypted API keys, secrets, salt
  settlement_bank_account JSONB NOT NULL DEFAULT '{}'::jsonb, -- {bank_name, account_number, ifsc, account_holder}
  upi_vpa TEXT, -- e.g. schoolname@bank or edushamiit@icici
  environment TEXT NOT NULL DEFAULT 'SANDBOX' CHECK (environment IN ('SANDBOX', 'TEST', 'PRODUCTION')),
  status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'PENDING_VERIFICATION', 'SUSPENDED')),
  is_default BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT chk_school_merchant CHECK (
    (owner_type = 'EDUSHAMIIT' AND school_id IS NULL) OR
    (owner_type = 'SCHOOL' AND school_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_merchant_accounts_school ON public.merchant_accounts(school_id);
CREATE INDEX IF NOT EXISTS idx_merchant_accounts_owner ON public.merchant_accounts(owner_type);
CREATE INDEX IF NOT EXISTS idx_merchant_accounts_provider ON public.merchant_accounts(provider_code);

-- Seed EduSHAMIIT Corporate Default Merchant Account if missing
INSERT INTO public.merchant_accounts (
  owner_type, school_id, merchant_name, provider_code, merchant_identifier, credentials_encrypted, settlement_bank_account, upi_vpa, environment, status, is_default
)
VALUES (
  'EDUSHAMIIT', NULL, 'EduSHAMIIT Technologies Pvt Ltd', 'MOCK_SANDBOX', 'EDUSHAMIIT-CORP-01',
  '{"api_key": "EDUSHAMIIT_CORP_KEY"}'::jsonb,
  '{"bank_name": "State Bank of India", "account_number": "00000011223344", "ifsc": "SBIN0001234", "account_holder": "EduSHAMIIT Corporate"}'::jsonb,
  'edushamiit@sbi', 'SANDBOX', 'ACTIVE', TRUE
)
ON CONFLICT DO NOTHING;


-- 2. ENRICH PAYMENT ORDERS TABLE FOR EDU SHAMIIT PAY
ALTER TABLE public.payment_orders
  ADD COLUMN IF NOT EXISTS ecosystem TEXT DEFAULT 'SUBSCRIPTION' CHECK (ecosystem IN ('SUBSCRIPTION', 'SCHOOL_FEE')),
  ADD COLUMN IF NOT EXISTS payment_type TEXT DEFAULT 'SUBSCRIPTION_PAYMENT',
  ADD COLUMN IF NOT EXISTS merchant_account_id UUID REFERENCES public.merchant_accounts(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS fee_invoice_id UUID REFERENCES public.fee_invoices(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS qr_code_payload TEXT,
  ADD COLUMN IF NOT EXISTS upi_intent_url TEXT,
  ADD COLUMN IF NOT EXISTS upi_vpa TEXT,
  ADD COLUMN IF NOT EXISTS upi_ref_no TEXT,
  ADD COLUMN IF NOT EXISTS settlement_status TEXT DEFAULT 'PENDING' CHECK (settlement_status IN ('PENDING', 'PROCESSING', 'SETTLED', 'FAILED', 'ON_HOLD')),
  ADD COLUMN IF NOT EXISTS settlement_id UUID,
  ADD COLUMN IF NOT EXISTS gross_amount NUMERIC(12,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS gateway_fee NUMERIC(12,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tax_on_fee NUMERIC(12,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS net_settlement_amount NUMERIC(12,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS reconciliation_status TEXT DEFAULT 'UNRECONCILED' CHECK (reconciliation_status IN ('UNRECONCILED', 'MATCHED', 'PARTIALLY_MATCHED', 'MISSING_IN_ERP', 'MISSING_AT_PROVIDER', 'AMOUNT_MISMATCH', 'DUPLICATE', 'SETTLEMENT_MISMATCH', 'EXCEPTION')),
  ADD COLUMN IF NOT EXISTS reconciliation_id UUID;

CREATE INDEX IF NOT EXISTS idx_payment_orders_ecosystem ON public.payment_orders(ecosystem);
CREATE INDEX IF NOT EXISTS idx_payment_orders_merchant_acc ON public.payment_orders(merchant_account_id);
CREATE INDEX IF NOT EXISTS idx_payment_orders_student ON public.payment_orders(student_id);
CREATE INDEX IF NOT EXISTS idx_payment_orders_fee_inv ON public.payment_orders(fee_invoice_id);
CREATE INDEX IF NOT EXISTS idx_payment_orders_reconciliation ON public.payment_orders(reconciliation_status);
CREATE INDEX IF NOT EXISTS idx_payment_orders_settlement ON public.payment_orders(settlement_status);


-- 3. PAYMENT SETTLEMENTS TABLE (Tracks disbursements to school or EduSHAMIIT bank accounts)
CREATE TABLE IF NOT EXISTS public.payment_settlements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  settlement_reference TEXT UNIQUE NOT NULL,
  ecosystem TEXT NOT NULL CHECK (ecosystem IN ('SUBSCRIPTION', 'SCHOOL_FEE')),
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
  merchant_account_id UUID REFERENCES public.merchant_accounts(id) ON DELETE SET NULL,
  provider_settlement_id TEXT,
  settlement_date DATE NOT NULL DEFAULT CURRENT_DATE,
  gross_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_fees NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_tax NUMERIC(12, 2) NOT NULL DEFAULT 0,
  net_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'SETTLED' CHECK (status IN ('PENDING', 'PROCESSING', 'SETTLED', 'FAILED', 'ON_HOLD')),
  bank_utr TEXT,
  bank_account_number TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_settlements_school ON public.payment_settlements(school_id);
CREATE INDEX IF NOT EXISTS idx_payment_settlements_ecosystem ON public.payment_settlements(ecosystem);
CREATE INDEX IF NOT EXISTS idx_payment_settlements_date ON public.payment_settlements(settlement_date DESC);


-- 4. PAYMENT REFUNDS TABLE (Lifecycle: REQUESTED -> APPROVED -> PROCESSING -> SUCCESS / FAILED)
CREATE TABLE IF NOT EXISTS public.payment_refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  refund_reference TEXT UNIQUE NOT NULL,
  payment_order_id UUID NOT NULL REFERENCES public.payment_orders(id) ON DELETE CASCADE,
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
  merchant_account_id UUID REFERENCES public.merchant_accounts(id) ON DELETE SET NULL,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  reason TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'REQUESTED' CHECK (status IN ('REQUESTED', 'APPROVED', 'PROCESSING', 'SUCCESS', 'FAILED', 'REJECTED')),
  provider_refund_id TEXT,
  requested_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  admin_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_payment_refunds_order ON public.payment_refunds(payment_order_id);
CREATE INDEX IF NOT EXISTS idx_payment_refunds_school ON public.payment_refunds(school_id);


-- 5. PAYMENT RECONCILIATIONS TABLE (Daily / Weekly / Monthly Reconciliation Batches)
CREATE TABLE IF NOT EXISTS public.payment_reconciliations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reconciliation_code TEXT UNIQUE NOT NULL,
  ecosystem TEXT NOT NULL CHECK (ecosystem IN ('SUBSCRIPTION', 'SCHOOL_FEE')),
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
  merchant_account_id UUID REFERENCES public.merchant_accounts(id) ON DELETE SET NULL,
  reconciliation_date DATE NOT NULL DEFAULT CURRENT_DATE,
  period_start TIMESTAMPTZ NOT NULL,
  period_end TIMESTAMPTZ NOT NULL,
  total_erp_records INT NOT NULL DEFAULT 0,
  total_erp_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_provider_records INT NOT NULL DEFAULT 0,
  total_provider_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  matched_count INT NOT NULL DEFAULT 0,
  matched_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  discrepancy_count INT NOT NULL DEFAULT 0,
  discrepancy_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'COMPLETED' CHECK (status IN ('RUNNING', 'COMPLETED', 'DISCREPANCIES_FOUND')),
  run_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_reconciliations_school ON public.payment_reconciliations(school_id);
CREATE INDEX IF NOT EXISTS idx_payment_reconciliations_date ON public.payment_reconciliations(reconciliation_date DESC);


-- 6. RECONCILIATION EXCEPTIONS TABLE (Individual discrepancies flagged during reconciliation)
CREATE TABLE IF NOT EXISTS public.reconciliation_exceptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reconciliation_id UUID NOT NULL REFERENCES public.payment_reconciliations(id) ON DELETE CASCADE,
  payment_order_id UUID REFERENCES public.payment_orders(id) ON DELETE SET NULL,
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
  exception_type TEXT NOT NULL CHECK (exception_type IN (
    'MISSING_IN_ERP', 'MISSING_AT_PROVIDER', 'AMOUNT_MISMATCH', 'DUPLICATE', 'SETTLEMENT_MISMATCH', 'REFUND_MISMATCH', 'OTHER'
  )),
  erp_amount NUMERIC(12, 2),
  provider_amount NUMERIC(12, 2),
  transaction_ref TEXT,
  discrepancy_details JSONB DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'INVESTIGATING', 'RESOLVED', 'WRITTEN_OFF')),
  resolved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  resolution_notes TEXT,
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reconciliation_exceptions_rec_id ON public.reconciliation_exceptions(reconciliation_id);
CREATE INDEX IF NOT EXISTS idx_reconciliation_exceptions_status ON public.reconciliation_exceptions(status);


-- 7. PAYMENT WEBHOOK EVENTS TABLE (Incoming raw webhook capture, replay protection, retry queue)
CREATE TABLE IF NOT EXISTS public.payment_webhook_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT NOT NULL,
  event_type TEXT NOT NULL,
  payload_hash TEXT UNIQUE NOT NULL, -- SHA256 of payload for idempotent replay prevention
  raw_payload JSONB NOT NULL,
  headers JSONB DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'RECEIVED' CHECK (status IN ('RECEIVED', 'PROCESSED', 'FAILED', 'DUPLICATE', 'IGNORED')),
  processing_attempts INT NOT NULL DEFAULT 1,
  error_message TEXT,
  payment_order_id UUID REFERENCES public.payment_orders(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_webhook_events_hash ON public.payment_webhook_events(payload_hash);
CREATE INDEX IF NOT EXISTS idx_webhook_events_status ON public.payment_webhook_events(status);
CREATE INDEX IF NOT EXISTS idx_webhook_events_created ON public.payment_webhook_events(created_at DESC);


-- 8. PAYMENT AUDIT LOGS TABLE
CREATE TABLE IF NOT EXISTS public.payment_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
  payment_order_id UUID REFERENCES public.payment_orders(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  action TEXT NOT NULL, -- e.g. 'PAYMENT_INITIATED', 'PAYMENT_VERIFIED', 'REFUND_REQUESTED', 'RECONCILIATION_RUN'
  entity_type TEXT NOT NULL, -- 'PAYMENT_ORDER', 'MERCHANT_ACCOUNT', 'REFUND', 'RECONCILIATION'
  entity_id TEXT NOT NULL,
  before_state JSONB DEFAULT '{}'::jsonb,
  after_state JSONB DEFAULT '{}'::jsonb,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_audit_logs_order ON public.payment_audit_logs(payment_order_id);
CREATE INDEX IF NOT EXISTS idx_payment_audit_logs_school ON public.payment_audit_logs(school_id);
CREATE INDEX IF NOT EXISTS idx_payment_audit_logs_created ON public.payment_audit_logs(created_at DESC);
