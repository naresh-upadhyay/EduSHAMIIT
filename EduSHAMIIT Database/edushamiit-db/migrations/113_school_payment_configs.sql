-- Migration 113: School Payment Configs
CREATE TABLE IF NOT EXISTS school_payment_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id) ON DELETE CASCADE UNIQUE,
  upi_id TEXT NOT NULL,
  bank_name TEXT NOT NULL,
  account_number TEXT NOT NULL,
  ifsc_code TEXT NOT NULL,
  account_holder_name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed configurations for both schools
INSERT INTO school_payment_configs (school_id, upi_id, bank_name, account_number, ifsc_code, account_holder_name) VALUES
  ('11111111-1111-1111-1111-111111111111', 'shami.academy@okaxis', 'State Bank of India', '39871234567', 'SBIN0001234', 'Shami Innovation Academy'),
  ('22222222-2222-2222-2222-222222222222', 'edushamiit@okhdfc', 'HDFC Bank', '50100234567890', 'HDFC0000123', 'EduSHAMIIT International School')
ON CONFLICT (school_id) DO NOTHING;

-- Enable RLS
ALTER TABLE school_payment_configs ENABLE ROW LEVEL SECURITY;

-- Allow select to authenticated users
CREATE POLICY "select_school_payment_configs" ON school_payment_configs
  FOR SELECT USING (true);
