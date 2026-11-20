-- Migration 536: Enhance Payment Bridge Analytics, Time-Series Indexes, and Views
-- Supports SHAMIIT Payment Bridge Analytics Graphs (Hourly, Daily, Monthly, Yearly, Custom)

-- 1. Optimized composite indexes for payment reconciliation time ranges
CREATE INDEX IF NOT EXISTS idx_pt_school_status_received
ON public.payment_transactions (school_id, payment_status, received_at DESC);

CREATE INDEX IF NOT EXISTS idx_pne_school_status_timestamp
ON public.payment_notification_events (school_id, candidate_match_status, notification_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_pt_school_app_status
ON public.payment_transactions (school_id, upi_app, payment_status);

-- 2. Materialized / View aggregates for rapid analytics dashboard lookups
CREATE OR REPLACE VIEW public.view_payment_bridge_matched_summary AS
SELECT
    school_id,
    payment_status,
    DATE(received_at) AS tx_date,
    COUNT(*) AS tx_count,
    COALESCE(SUM(amount_paise), 0) AS total_paise
FROM public.payment_transactions
GROUP BY school_id, payment_status, DATE(received_at);

COMMENT ON VIEW public.view_payment_bridge_matched_summary IS 'Rapid rollups for SHAMIIT Payment Bridge Analytics Graphs';
