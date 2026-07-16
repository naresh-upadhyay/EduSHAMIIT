-- Migration 163: School Onboarding Enhancements
-- 1. Add board column to schools table
ALTER TABLE schools ADD COLUMN IF NOT EXISTS board TEXT;

-- 2. Ensure existing schools have active status
UPDATE schools SET subscription_status = 'active' WHERE subscription_status IS NULL;

-- 3. If there is a check constraint on subscription_status, make sure it allows 'new' and 'expired'
-- Since there was no check constraint created in 141, we don't need to drop any constraint.
