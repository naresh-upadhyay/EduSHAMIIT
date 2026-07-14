-- Migration 158: Add status column to profiles table
-- Active, Inactive, Locked
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Active' CHECK (status IN ('Active', 'Inactive', 'Locked'));
