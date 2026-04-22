-- ============================================================
-- Migration 088: Sample Payments Data
-- ============================================================

-- Add created_at if missing
ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- Backfill school_id from fees
UPDATE payments p
SET school_id = f.school_id
FROM fees f
WHERE p.fee_id = f.id
  AND p.school_id IS NULL;

-- Sample payments (proper UUID v4 format)
INSERT INTO payments (
  id, school_id, student_id, fee_id, amount, currency, status, payment_method,
  payment_gateway, transaction_id, upi_transaction_id, bank_ref_no,
  description, remarks, paid_at, verified_at, initiated_by, created_at
) VALUES
  -- Tuition fee Q1 - paid
  ('a1000001-0001-4001-8001-000000000001',
   '11111111-1111-1111-1111-111111111111',
   '10000000-0000-0000-0000-000000000002',
   'fee00001-0001-0001-0001-000000000001',
   15000.00, 'INR', 'success', 'upi', 'upi',
   'TXN20260401001', 'UPI2026040112345', 'HDFC20260401001',
   'Q1 Tuition Fee 2025-26', 'Paid via PhonePe',
   '2026-04-02T10:30:00Z', '2026-04-02T10:31:00Z',
   '10000000-0000-0000-0000-000000000002',
   '2026-04-01T10:00:00Z'),

  -- Library fee - paid via Razorpay
  ('a1000002-0002-4002-8002-000000000002',
   '11111111-1111-1111-1111-111111111111',
   '10000000-0000-0000-0000-000000000002',
   'fee00001-0001-0001-0001-000000000002',
   2000.00, 'INR', 'success', 'upi', 'razorpay',
   'TXN20260402001', 'UPI2026040212345', 'ICICI20260402001',
   'Annual Library Fee 2025-26', 'Paid via Google Pay',
   '2026-04-03T14:00:00Z', '2026-04-03T14:01:00Z',
   '10000000-0000-0000-0000-000000000002',
   '2026-04-02T09:00:00Z'),

  -- Lab fee - pending
  ('a1000003-0003-4003-8003-000000000003',
   '11111111-1111-1111-1111-111111111111',
   '10000000-0000-0000-0000-000000000002',
   'fee00001-0001-0001-0001-000000000003',
   3000.00, 'INR', 'pending', 'upi', 'upi',
   'TXN20260420001', NULL, NULL,
   'Q1 Lab Fee 2025-26', 'UPI link sent to student',
   NULL, NULL,
   '10000000-0000-0000-0000-000000000002',
   '2026-04-19T11:00:00Z'),

  -- Transport fee - failed
  ('a1000004-0004-4004-8004-000000000004',
   '11111111-1111-1111-1111-111111111111',
   '10000000-0000-0000-0000-000000000003',
   'fee00001-0001-0001-0001-000000000005',
   5000.00, 'INR', 'failed', 'upi', 'upi',
   'TXN20260405001', NULL, NULL,
   'Q1 Transport Fee 2025-26', 'Payment failed - bank declined',
   NULL, NULL,
   '10000000-0000-0000-0000-000000000003',
   '2026-04-05T08:00:00Z')
ON CONFLICT (id) DO UPDATE SET
  currency           = EXCLUDED.currency,
  description        = EXCLUDED.description,
  payment_gateway    = EXCLUDED.payment_gateway,
  school_id          = EXCLUDED.school_id,
  upi_transaction_id = EXCLUDED.upi_transaction_id,
  bank_ref_no        = EXCLUDED.bank_ref_no,
  remarks            = EXCLUDED.remarks,
  verified_at        = EXCLUDED.verified_at,
  status             = EXCLUDED.status;

-- Sync fees: mark paid ones correctly
UPDATE fees SET amount_paid = 15000.00, paid_at = '2026-04-02T10:31:00Z', status = 'paid'
  WHERE id = 'fee00001-0001-0001-0001-000000000001';

UPDATE fees SET amount_paid = 2000.00, paid_at = '2026-04-03T14:01:00Z', status = 'paid'
  WHERE id = 'fee00001-0001-0001-0001-000000000002';
