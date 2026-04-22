-- ============================================================
-- Migration 087: Payments Table Enhancement (idempotent)
-- Adds: school_id, currency (default INR), description,
--       gateway_ref_id, upi_transaction_id, bank_ref_no,
--       payment_gateway, gateway_response, failure_reason,
--       verified_at, expires_at, refund_amount, refund_status
-- Also adds school_id to all tables that are missing it.
-- ============================================================

-- ─── 1. PAYMENTS: full realistic payment schema ──────────────

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS school_id          UUID REFERENCES schools(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS currency           TEXT NOT NULL DEFAULT 'INR',
  ADD COLUMN IF NOT EXISTS description        TEXT,
  ADD COLUMN IF NOT EXISTS gateway_ref_id     TEXT,
  ADD COLUMN IF NOT EXISTS upi_transaction_id TEXT,
  ADD COLUMN IF NOT EXISTS bank_ref_no        TEXT,
  ADD COLUMN IF NOT EXISTS payment_gateway    TEXT DEFAULT 'upi',
  ADD COLUMN IF NOT EXISTS gateway_response   JSONB,
  ADD COLUMN IF NOT EXISTS failure_reason     TEXT,
  ADD COLUMN IF NOT EXISTS verified_at        TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS expires_at         TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS refund_amount      NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS refund_status      TEXT DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS refund_at          TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS initiated_by       UUID REFERENCES profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS remarks            TEXT,
  ADD COLUMN IF NOT EXISTS ip_address         TEXT,
  ADD COLUMN IF NOT EXISTS updated_at         TIMESTAMPTZ DEFAULT NOW();

-- Normalise legacy status values before adding constraint
UPDATE payments SET status = 'success'     WHERE status = 'completed';
UPDATE payments SET status = 'failed'      WHERE status = 'failure';
UPDATE payments SET status = 'cancelled'   WHERE status IN ('canceled','void');
UPDATE payments SET status = 'pending'     WHERE status NOT IN ('pending','processing','success','failed','refunded','cancelled');

-- Status check constraint (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'payments_status_check' AND table_name = 'payments'
  ) THEN
    ALTER TABLE payments ADD CONSTRAINT payments_status_check
      CHECK (status IN ('pending','processing','success','failed','refunded','cancelled'));
  END IF;
END $$;

-- Refund status check
UPDATE payments SET refund_status = 'none' WHERE refund_status IS NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'payments_refund_status_check' AND table_name = 'payments'
  ) THEN
    ALTER TABLE payments ADD CONSTRAINT payments_refund_status_check
      CHECK (refund_status IN ('none','partial','full','processing'));
  END IF;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_payments_school_id       ON payments (school_id);
CREATE INDEX IF NOT EXISTS idx_payments_student_id      ON payments (student_id);
CREATE INDEX IF NOT EXISTS idx_payments_fee_id          ON payments (fee_id);
CREATE INDEX IF NOT EXISTS idx_payments_status          ON payments (status);
CREATE INDEX IF NOT EXISTS idx_payments_transaction_id  ON payments (transaction_id);
CREATE INDEX IF NOT EXISTS idx_payments_gateway_ref     ON payments (gateway_ref_id);
CREATE INDEX IF NOT EXISTS idx_payments_upi_txn         ON payments (upi_transaction_id);
CREATE INDEX IF NOT EXISTS idx_payments_paid_at         ON payments (paid_at);

-- ─── 2. FEES: add missing financial tracking columns ──────────

ALTER TABLE fees
  ADD COLUMN IF NOT EXISTS amount_paid    NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS discount       NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS late_fine      NUMERIC(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS currency       TEXT NOT NULL DEFAULT 'INR',
  ADD COLUMN IF NOT EXISTS description    TEXT,
  ADD COLUMN IF NOT EXISTS paid_at        TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at     TIMESTAMPTZ DEFAULT NOW();

-- ─── 3. SALARY: add financial metadata ───────────────────────

ALTER TABLE salary
  ADD COLUMN IF NOT EXISTS currency       TEXT NOT NULL DEFAULT 'INR',
  ADD COLUMN IF NOT EXISTS description    TEXT,
  ADD COLUMN IF NOT EXISTS bank_ref_no    TEXT,
  ADD COLUMN IF NOT EXISTS transaction_id TEXT,
  ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'bank_transfer',
  ADD COLUMN IF NOT EXISTS remarks        TEXT,
  ADD COLUMN IF NOT EXISTS updated_at     TIMESTAMPTZ DEFAULT NOW();

-- ─── 4. IOT_SCHEDULED_ACTIONS: add missing columns ───────────

ALTER TABLE iot_scheduled_actions
  ADD COLUMN IF NOT EXISTS created_by   UUID REFERENCES profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS updated_at   TIMESTAMPTZ DEFAULT NOW();

-- ─── 5. Add school_id to tables that are missing it ──────────

-- library_borrows
ALTER TABLE library_borrows
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_library_borrows_school ON library_borrows (school_id);

-- student_achievements
ALTER TABLE student_achievements
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_student_achievements_school ON student_achievements (school_id);

-- homework_submissions (safe: idempotent)
ALTER TABLE homework_submissions
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;

-- event_registrations (safe: idempotent)
ALTER TABLE event_registrations
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;

-- group_members
ALTER TABLE group_members
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_group_members_school ON group_members (school_id);

-- ─── 6. Auto updated_at trigger ──────────────────────────────

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_payments_updated_at'
  ) THEN
    CREATE TRIGGER trg_payments_updated_at
      BEFORE UPDATE ON payments
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'trg_fees_updated_at'
  ) THEN
    CREATE TRIGGER trg_fees_updated_at
      BEFORE UPDATE ON fees
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;
