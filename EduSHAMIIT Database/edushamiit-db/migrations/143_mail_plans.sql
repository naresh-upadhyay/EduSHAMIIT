-- Migration 143: Mail Subscription Plans support in Subscription Catalog

-- 1. Alter subscription_plans table to add plan_type
ALTER TABLE subscription_plans ADD COLUMN IF NOT EXISTS plan_type TEXT DEFAULT 'erp';

-- 2. Seed default mail server subscription plans
INSERT INTO subscription_plans (name, code, plan_type, price_per_month, price_per_year, features, discount_percent, offer_text)
VALUES
  ('SMTP Starter Mail', 'mail_starter', 'mail', 99.00, 999.00, '["Up to 5,000 emails/month", "Shared IP gateway", "Standard delivery rates", "Email report log"]'::jsonb, 0.00, 'Best for small schools'),
  ('SMTP Growth Mail', 'mail_growth', 'mail', 299.00, 2999.00, '["Up to 25,000 emails/month", "Dedicated IP gateway", "High priority delivery queue", "SMTP configuration dashboard"]'::jsonb, 15.00, 'Growth Offer: 15% Off!'),
  ('Enterprise Dedicated Mail', 'mail_enterprise', 'mail', 999.00, 9999.00, '["Unlimited email volume", "Custom domain configuration", "DMARC/DKIM signature setup", "99.9% uptime SLA"]'::jsonb, 0.00, 'Dedicated IP pool')
ON CONFLICT (code) DO NOTHING;
