-- Migration 144: Add mail_plan_code to school_mail_subscriptions
ALTER TABLE school_mail_subscriptions ADD COLUMN IF NOT EXISTS mail_plan_code TEXT DEFAULT 'mail_starter';
