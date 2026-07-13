-- Database migration: 157_lockout_columns.sql
-- Add failed login attempts and lockout timestamp columns to profiles table.

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS failed_login_attempts INT NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS lockout_until TIMESTAMP WITH TIME ZONE;
