-- Migration 142: Subscription Plans, Expiry Alerts, Owner Contacts, and Mail Server Telemetry

-- 1. Alter schools table to add owner details and alert triggers
ALTER TABLE schools ADD COLUMN IF NOT EXISTS owner_email TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS owner_name TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS send_renewal_reminders BOOLEAN DEFAULT TRUE;

-- 2. Alter school_mail_subscriptions table to add server configurations and storage metrics
ALTER TABLE school_mail_subscriptions ADD COLUMN IF NOT EXISTS mail_host TEXT DEFAULT 'smtp.gmail.com';
ALTER TABLE school_mail_subscriptions ADD COLUMN IF NOT EXISTS mail_port INT DEFAULT 587;
ALTER TABLE school_mail_subscriptions ADD COLUMN IF NOT EXISTS mail_username TEXT;
ALTER TABLE school_mail_subscriptions ADD COLUMN IF NOT EXISTS mail_password TEXT;
ALTER TABLE school_mail_subscriptions ADD COLUMN IF NOT EXISTS mail_server_size_limit_mb NUMERIC DEFAULT 1024.00;
ALTER TABLE school_mail_subscriptions ADD COLUMN IF NOT EXISTS mail_server_size_used_mb NUMERIC DEFAULT 0.00;

-- Update existing seeded rows with defaults
UPDATE schools SET 
  owner_email = 'owner@shamiit.com',
  owner_name = 'Dr. Rajesh Shami'
WHERE id = '11111111-1111-1111-1111-111111111111';

UPDATE schools SET 
  owner_email = 'director@eduverse.org',
  owner_name = 'Prof. S. Malhotra'
WHERE id = '22222222-2222-2222-2222-222222222222';

-- 3. Create subscription_plans table
CREATE TABLE IF NOT EXISTS subscription_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  code TEXT UNIQUE NOT NULL,
  price_per_month NUMERIC DEFAULT 0.00,
  price_per_year NUMERIC DEFAULT 0.00,
  features JSONB DEFAULT '[]'::jsonb,
  discount_percent NUMERIC DEFAULT 0.00,
  offer_text TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default plans
INSERT INTO subscription_plans (name, code, price_per_month, price_per_year, features, discount_percent, offer_text)
VALUES
  ('Basic Plan', 'basic', 499.00, 4999.00, '["Core ERP Modules", "LMS access", "Up to 500 students", "Email support"]'::jsonb, 10.00, 'Starter Promo: 10% Off!'),
  ('Premium Plan', 'premium', 1199.00, 11999.00, '["Advanced Analytics", "IoT Node controller", "Up to 2000 students", "Priority 24/7 support", "Custom branding"]'::jsonb, 20.00, 'Festive Special: 20% Off!'),
  ('Enterprise Custom', 'enterprise', 4999.00, 49999.00, '["Unlimited students", "Dedicated server hosting", "Custom API Integrations", "Dedicated Account Manager"]'::jsonb, 0.00, 'Contact for tailored quotes')
ON CONFLICT (code) DO NOTHING;

-- Enable RLS
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "allow_all_subscription_plans" ON subscription_plans
  USING (true) WITH CHECK (true);
