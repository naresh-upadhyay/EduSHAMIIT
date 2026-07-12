-- Database migration: 149_infra_monitor.sql
-- Create Infrastructure and Telemetry Monitoring Schema & Seed Data

-- 1. Create Servers Table
CREATE TABLE IF NOT EXISTS public.infra_servers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    region VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'healthy',
    cpu_usage FLOAT NOT NULL DEFAULT 0.0,
    memory_usage FLOAT NOT NULL DEFAULT 0.0,
    disk_usage FLOAT NOT NULL DEFAULT 0.0,
    network_in_out FLOAT NOT NULL DEFAULT 0.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

-- Enable RLS and permissions
ALTER TABLE public.infra_servers ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.infra_servers TO anon, authenticated, service_role;
CREATE POLICY "Allow read/write access for all on infra_servers" ON public.infra_servers FOR ALL USING (true) WITH CHECK (true);

-- 2. Create Alerts Table
CREATE TABLE IF NOT EXISTS public.infra_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'warning',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

ALTER TABLE public.infra_alerts ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.infra_alerts TO anon, authenticated, service_role;
CREATE POLICY "Allow read/write access for all on infra_alerts" ON public.infra_alerts FOR ALL USING (true) WITH CHECK (true);

-- 3. Create Services Table
CREATE TABLE IF NOT EXISTS public.infra_services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'operational',
    uptime_percentage FLOAT NOT NULL DEFAULT 100.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

ALTER TABLE public.infra_services ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.infra_services TO anon, authenticated, service_role;
CREATE POLICY "Allow read/write access for all on infra_services" ON public.infra_services FOR ALL USING (true) WITH CHECK (true);

-- 4. Create School Telemetry Table
CREATE TABLE IF NOT EXISTS public.infra_school_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    log_date DATE NOT NULL DEFAULT CURRENT_DATE,
    avg_response_time_ms INTEGER NOT NULL DEFAULT 100,
    request_count_24h BIGINT NOT NULL DEFAULT 0,
    storage_used_bytes BIGINT NOT NULL DEFAULT 0,
    storage_total_bytes BIGINT NOT NULL DEFAULT 214748364800, -- 200 GB
    status VARCHAR(20) NOT NULL DEFAULT 'healthy',
    uptime_percentage FLOAT NOT NULL DEFAULT 100.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

ALTER TABLE public.infra_school_metrics ENABLE ROW LEVEL SECURITY;
GRANT ALL ON public.infra_school_metrics TO anon, authenticated, service_role;
CREATE POLICY "Allow read/write access for all on infra_school_metrics" ON public.infra_school_metrics FOR ALL USING (true) WITH CHECK (true);

-- Seed Data:
-- Clean existing
DELETE FROM public.infra_servers;
DELETE FROM public.infra_services;
DELETE FROM public.infra_alerts;
DELETE FROM public.infra_school_metrics;

-- Servers
INSERT INTO public.infra_servers (name, ip_address, region, status, cpu_usage, memory_usage, disk_usage, network_in_out) VALUES
('api-server-1', '10.0.0.4', 'Mumbai', 'healthy', 38.5, 58.2, 52.1, 32.4),
('api-server-2', '10.0.0.5', 'Mumbai', 'critical', 92.1, 88.4, 54.0, 78.5),
('db-node-primary', '10.0.0.10', 'Frankfurt', 'healthy', 42.0, 61.2, 54.0, 35.1),
('db-node-replica', '10.0.0.11', 'Oregon', 'warning', 65.4, 82.1, 78.5, 45.0),
('redis-cache', '10.0.0.20', 'São Paulo', 'healthy', 12.5, 44.0, 22.0, 18.0);

-- Services
INSERT INTO public.infra_services (name, status, uptime_percentage) VALUES
('API Gateway', 'operational', 99.99),
('Auth Service', 'operational', 99.98),
('Database Cluster', 'operational', 100.0),
('File Storage', 'operational', 99.95),
('Backup Service', 'operational', 99.90),
('Email Service', 'operational', 99.99),
('Payment Gateway', 'operational', 99.97),
('CDN', 'operational', 99.99);

-- Seed Metrics for all active schools across 7 days
INSERT INTO public.infra_school_metrics (school_id, log_date, avg_response_time_ms, request_count_24h, storage_used_bytes, storage_total_bytes, status, uptime_percentage)
SELECT 
    s.id as school_id,
    d::date as log_date,
    CASE 
        WHEN s.name = 'Shami Innovation Academy' THEN (110 + random() * 20)::int
        WHEN s.name = 'EduSHAMIIT International School' THEN (260 + random() * 30)::int
        WHEN s.name = 'KING INSTITUE' THEN (100 + random() * 15)::int
        WHEN s.name = 'YACU' THEN (540 + random() * 40)::int
        ELSE (125 + random() * 15)::int
    END as avg_response_time_ms,
    CASE 
        WHEN s.name = 'Shami Innovation Academy' THEN (2300000 + random() * 300000)::bigint
        WHEN s.name = 'EduSHAMIIT International School' THEN (1700000 + random() * 250000)::bigint
        WHEN s.name = 'KING INSTITUE' THEN (3100000 + random() * 200000)::bigint
        WHEN s.name = 'YACU' THEN (950000 + random() * 150000)::bigint
        ELSE (1200000 + random() * 200000)::bigint
    END as request_count_24h,
    CASE 
        WHEN s.name = 'Shami Innovation Academy' THEN (78 * 1024::bigint * 1024 * 1024 + random() * 2 * 1024 * 1024 * 1024)::bigint
        WHEN s.name = 'EduSHAMIIT International School' THEN (120 * 1024::bigint * 1024 * 1024 + random() * 5 * 1024 * 1024 * 1024)::bigint
        WHEN s.name = 'KING INSTITUE' THEN (95 * 1024::bigint * 1024 * 1024 + random() * 3 * 1024 * 1024 * 1024)::bigint
        WHEN s.name = 'YACU' THEN (180 * 1024::bigint * 1024 * 1024 + random() * 1 * 1024 * 1024 * 1024)::bigint
        ELSE (60 * 1024::bigint * 1024 * 1024 + random() * 2 * 1024 * 1024 * 1024)::bigint
    END as storage_used_bytes,
    214748364800::bigint as storage_total_bytes,
    CASE 
        WHEN s.name = 'YACU' THEN 'critical'
        WHEN s.name = 'EduSHAMIIT International School' THEN 'warning'
        ELSE 'healthy'
    END as status,
    CASE 
        WHEN s.name = 'YACU' THEN 97.32
        WHEN s.name = 'EduSHAMIIT International School' THEN 99.62
        WHEN s.name = 'KING INSTITUE' THEN 100.0
        ELSE 99.99
    END as uptime_percentage
FROM public.schools s, generate_series(CURRENT_DATE - INTERVAL '7 days', CURRENT_DATE, '1 day') d;

-- Seed Alerts
INSERT INTO public.infra_alerts (school_id, title, severity, created_at)
SELECT 
    s.id as school_id,
    CASE 
        WHEN s.name = 'Shami Innovation Academy' THEN 'High CPU usage on api-server-2'
        WHEN s.name = 'EduSHAMIIT International School' THEN 'Database connection failures'
        WHEN s.name = 'KING INSTITUE' THEN 'SSL certificate expires in 5 days'
        WHEN s.name = 'YACU' THEN 'High memory usage on db-cluster'
        ELSE 'Backup failed for hr-module'
    END as title,
    CASE 
        WHEN s.name = 'Shami Innovation Academy' OR s.name = 'YACU' OR s.name = 'KING JI TEST' THEN 'critical'
        ELSE 'warning'
    END as severity,
    now() - (random() * interval '4 hours')
FROM public.schools s;

-- 5. Optimization Indexes for High Performance
CREATE INDEX IF NOT EXISTS idx_infra_school_metrics_school_date ON public.infra_school_metrics(school_id, log_date);
CREATE INDEX IF NOT EXISTS idx_infra_alerts_school_id ON public.infra_alerts(school_id);

