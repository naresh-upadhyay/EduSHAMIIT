-- ============================================================================
-- Migration 534: Add Advanced Azure-DevOps Style Query Rules & Keywords to Custom Parsers
-- Author: Antigravity
-- Date: 2026-11-19
-- ============================================================================

ALTER TABLE public.payment_bridge_custom_parsers
ADD COLUMN IF NOT EXISTS rules_json TEXT,
ADD COLUMN IF NOT EXISTS title_match_mode VARCHAR(50) DEFAULT 'ANY',
ADD COLUMN IF NOT EXISTS title_match_value TEXT,
ADD COLUMN IF NOT EXISTS required_keywords TEXT,
ADD COLUMN IF NOT EXISTS ignore_keywords TEXT,
ADD COLUMN IF NOT EXISTS case_sensitive BOOLEAN DEFAULT FALSE;
