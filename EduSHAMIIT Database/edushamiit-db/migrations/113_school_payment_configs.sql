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

-- Seed configurations dynamically for all schools that exist
DO $$
DECLARE
  v_school RECORD;
  v_idx INT := 1;
BEGIN
  FOR v_school IN SELECT id, name FROM public.schools ORDER BY created_at ASC LOOP
    IF v_idx = 1 THEN
      INSERT INTO school_payment_configs (school_id, upi_id, bank_name, account_number, ifsc_code, account_holder_name)
      VALUES (v_school.id, 'shami.academy@okaxis', 'State Bank of India', '39871234567', 'SBIN0001234', COALESCE(v_school.name, 'Shami Innovation Academy'))
      ON CONFLICT (school_id) DO NOTHING;
    ELSIF v_idx = 2 THEN
      INSERT INTO school_payment_configs (school_id, upi_id, bank_name, account_number, ifsc_code, account_holder_name)
      VALUES (v_school.id, 'edushamiit@okhdfc', 'HDFC Bank', '50100234567890', 'HDFC0000123', COALESCE(v_school.name, 'EduSHAMIIT International School'))
      ON CONFLICT (school_id) DO NOTHING;
    ELSE
      INSERT INTO school_payment_configs (school_id, upi_id, bank_name, account_number, ifsc_code, account_holder_name)
      VALUES (v_school.id, 'payment.' || v_idx || '@oksbi', 'State Bank of India', '501000' || v_idx, 'SBIN0001234', COALESCE(v_school.name, 'School ' || v_idx))
      ON CONFLICT (school_id) DO NOTHING;
    END IF;
    v_idx := v_idx + 1;
  END LOOP;
END $$;

-- Enable RLS
ALTER TABLE school_payment_configs ENABLE ROW LEVEL SECURITY;

-- Allow select to authenticated users
DROP POLICY IF EXISTS "select_school_payment_configs" ON school_payment_configs;
CREATE POLICY "select_school_payment_configs" ON school_payment_configs
  FOR SELECT USING (true);
