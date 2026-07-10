-- Migration 141: School Subscriptions and Mail Subscription Management

-- 1. Alter schools table to add SaaS subscription properties
ALTER TABLE schools ADD COLUMN IF NOT EXISTS subscription_status TEXT DEFAULT 'active';
ALTER TABLE schools ADD COLUMN IF NOT EXISTS subscription_tier TEXT DEFAULT 'premium';
ALTER TABLE schools ADD COLUMN IF NOT EXISTS subscription_start_date TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE schools ADD COLUMN IF NOT EXISTS subscription_end_date TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '1 year');
ALTER TABLE schools ADD COLUMN IF NOT EXISTS pricing_model TEXT DEFAULT 'per_student'; -- 'per_student', 'per_month', 'per_quarter', 'per_year'
ALTER TABLE schools ADD COLUMN IF NOT EXISTS pricing_rate NUMERIC DEFAULT 10.00;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS max_students INT DEFAULT 1000;

-- 2. Create school_mail_subscriptions table for transactional mail billing
CREATE TABLE IF NOT EXISTS school_mail_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id) ON DELETE CASCADE UNIQUE,
  enabled BOOLEAN DEFAULT TRUE,
  pricing_model TEXT DEFAULT 'per_email', -- 'per_email', 'monthly_flat', 'unlimited'
  rate_per_unit NUMERIC DEFAULT 0.10,
  monthly_limit INT DEFAULT 5000,
  emails_sent INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Seed mail subscriptions for existing schools
INSERT INTO school_mail_subscriptions (school_id, enabled, pricing_model, rate_per_unit, monthly_limit, emails_sent)
SELECT id, TRUE, 'per_email', 0.10, 5000, 150 FROM schools
ON CONFLICT (school_id) DO NOTHING;

-- 4. Enable RLS
ALTER TABLE school_mail_subscriptions ENABLE ROW LEVEL SECURITY;

-- 5. Policies
CREATE POLICY "allow_all_school_mail_subscriptions" ON school_mail_subscriptions
  USING (true) WITH CHECK (true);
