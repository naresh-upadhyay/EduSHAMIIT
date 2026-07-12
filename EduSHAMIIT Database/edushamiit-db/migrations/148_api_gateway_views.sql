-- Database migration: 148_api_gateway_views.sql
-- Create API Gateway path aggregates and daily traffic views for exact real-time calculations.

-- 1. Path metrics aggregate view
CREATE OR REPLACE VIEW public.api_path_stats AS
SELECT 
    path,
    COUNT(*)::int as total_requests,
    COUNT(CASE WHEN status_code < 400 THEN 1 END)::int as success_requests,
    AVG(response_time_ms)::float as avg_response_time,
    COUNT(CASE WHEN status_code = 429 THEN 1 END)::int as rate_limit_hits
FROM public.api_request_logs
GROUP BY path;

-- Enable permissions on view
GRANT SELECT ON public.api_path_stats TO anon, authenticated, service_role;

-- 2. Daily traffic overview view
CREATE OR REPLACE VIEW public.api_daily_stats AS
SELECT 
    (created_at AT TIME ZONE 'UTC')::date as log_date,
    COUNT(*)::int as total_requests,
    COUNT(CASE WHEN status_code < 400 THEN 1 END)::int as success_requests,
    COUNT(CASE WHEN status_code >= 400 THEN 1 END)::int as failed_requests
FROM public.api_request_logs
GROUP BY (created_at AT TIME ZONE 'UTC')::date;

-- Enable permissions on view
GRANT SELECT ON public.api_daily_stats TO anon, authenticated, service_role;

-- 3. Optimization Indexes for High Performance
CREATE INDEX IF NOT EXISTS idx_api_request_logs_path ON public.api_request_logs(path);
CREATE INDEX IF NOT EXISTS idx_api_request_logs_created_at ON public.api_request_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_api_request_logs_status_code ON public.api_request_logs(status_code);

