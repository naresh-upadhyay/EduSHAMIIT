-- Database migration: 147_api_gateway.sql
-- Create API Gateway configurations and logs tracking schemas for metrics and monitoring.

-- 1. Create API Gateway Configurations table
CREATE TABLE IF NOT EXISTS public.api_gateway_configs (
    path_prefix TEXT PRIMARY KEY,
    api_name TEXT NOT NULL,
    category TEXT NOT NULL,
    version TEXT NOT NULL DEFAULT 'v1.0',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS and permissions on configurations
ALTER TABLE public.api_gateway_configs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow read for all users" ON public.api_gateway_configs FOR SELECT USING (true);
CREATE POLICY "Allow write for authenticated users" ON public.api_gateway_configs FOR ALL TO authenticated USING (true);

-- 2. Create API Request Logs table for monitoring metrics
CREATE TABLE IF NOT EXISTS public.api_request_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    path TEXT NOT NULL,
    method TEXT NOT NULL,
    status_code INT NOT NULL,
    response_time_ms FLOAT NOT NULL,
    ip_address TEXT,
    user_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS and permissions on request logs
ALTER TABLE public.api_request_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow read for all users on request logs" ON public.api_request_logs FOR SELECT USING (true);
CREATE POLICY "Allow insert for all users on request logs" ON public.api_request_logs FOR INSERT WITH CHECK (true);

-- 3. Populate default high-level API configurations
INSERT INTO public.api_gateway_configs (path_prefix, api_name, category, version, is_active) VALUES
('/api/auth', 'Authentication API', 'Authentication', 'v2.1', true),
('/api/student', 'Student Management API', 'Student', 'v2.3', true),
('/api/teacher', 'Academic API', 'Academic', 'v2.0', true),
('/api/payments', 'Finance API', 'Finance', 'v1.8', true),
('/api/chat', 'Communication API', 'Communication', 'v1.5', true),
('/api/library-books', 'Library API', 'Academic', 'v1.2', true),
('/api/admin/schools', 'Schools ERP Control API', 'Others', 'v1.0', true),
('/api/admin/students', 'Student Admin API', 'Student', 'v1.0', true),
('/api/admin/teachers', 'Teacher Admin API', 'Academic', 'v1.0', true)
ON CONFLICT (path_prefix) DO UPDATE SET
    api_name = EXCLUDED.api_name,
    category = EXCLUDED.category,
    version = EXCLUDED.version,
    is_active = EXCLUDED.is_active;

-- 4. Generate random sample metrics data for the last 7 days
INSERT INTO public.api_request_logs (path, method, status_code, response_time_ms, ip_address, created_at)
SELECT 
    CASE (random() * 7)::int
        WHEN 0 THEN '/api/auth/login'
        WHEN 1 THEN '/api/student/profile'
        WHEN 2 THEN '/api/teacher/classes'
        WHEN 3 THEN '/api/payments/checkout'
        WHEN 4 THEN '/api/chat/send'
        WHEN 5 THEN '/api/library-books/list'
        WHEN 6 THEN '/api/admin/schools'
        ELSE '/api/admin/students'
    END as path,
    CASE (random() * 2)::int
        WHEN 0 THEN 'GET'
        WHEN 1 THEN 'POST'
        ELSE 'PUT'
    END as method,
    CASE 
        WHEN random() < 0.95 THEN 200 -- 95% successful
        WHEN random() < 0.70 THEN 400 -- bad requests
        WHEN random() < 0.92 THEN 429 -- rate limit hits
        ELSE 500 -- internal errors
    END as status_code,
    (60 + random() * 240)::float as response_time_ms, -- Avg ~180ms
    '192.168.1.' || (random() * 254)::int as ip_address,
    now() - (random() * 7 || ' days')::interval as created_at
FROM generate_series(1, 1500);
