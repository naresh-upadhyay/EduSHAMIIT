-- Database migration: 159_last_failed_login.sql
-- Add last_failed_login timestamp column to profiles table.

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS last_failed_login TIMESTAMP WITH TIME ZONE;
