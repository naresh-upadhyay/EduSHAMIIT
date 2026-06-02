-- ============================================================
-- Migration 109: Group Privacy (is_private column)
-- ============================================================

ALTER TABLE public.groups ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT FALSE;
