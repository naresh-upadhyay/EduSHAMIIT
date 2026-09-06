-- Migration 339: Add financial_year column to library_books table
-- Ensures financial_year is cleanly persisted and updated on book records

DO $$
BEGIN
    ALTER TABLE public.library_books ADD COLUMN IF NOT EXISTS financial_year VARCHAR(50);
END $$;
