-- Database migration: 156_system_configuration.sql
-- Create system configurations table and seed default global parameters.

CREATE TABLE IF NOT EXISTS public.system_configurations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    
    -- General Settings - Basic Information
    system_name TEXT NOT NULL DEFAULT 'School ERP',
    system_title TEXT NOT NULL DEFAULT 'Next Generation School Management',
    system_logo TEXT,
    favicon TEXT,
    default_language TEXT NOT NULL DEFAULT 'English',
    default_timezone TEXT NOT NULL DEFAULT '(UTC+05:30) Asia/Kolkata',
    date_format TEXT NOT NULL DEFAULT 'May 24, 2025 (MMM DD, YYYY)',
    time_format TEXT NOT NULL DEFAULT '12 Hour (hh:mm AM/PM)',
    
    -- General Settings - System Preferences
    allow_new_registrations BOOLEAN NOT NULL DEFAULT true,
    maintenance_mode BOOLEAN NOT NULL DEFAULT false,
    multi_institution_support BOOLEAN NOT NULL DEFAULT true,
    data_anonymization BOOLEAN NOT NULL DEFAULT false,
    enable_two_factor BOOLEAN NOT NULL DEFAULT true,
    email_notifications BOOLEAN NOT NULL DEFAULT true,
    sms_notifications BOOLEAN NOT NULL DEFAULT true,
    auto_logout_minutes INT NOT NULL DEFAULT 30,
    session_timeout_minutes INT NOT NULL DEFAULT 120,
    
    -- General Settings - System Message
    login_page_message TEXT NOT NULL DEFAULT 'Welcome to School ERP. Please login with your credentials.',
    
    -- Other configurations tabs
    security_settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    email_sms_settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    modules_settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    appearance_settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    payments_settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    integrations_settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    backup_restore_settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    advanced_settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Partial indexes for unique constraints
CREATE UNIQUE INDEX IF NOT EXISTS unique_global_configuration ON public.system_configurations ((school_id IS NULL)) WHERE school_id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS unique_school_configuration ON public.system_configurations (school_id) WHERE school_id IS NOT NULL;

-- Enable RLS
ALTER TABLE public.system_configurations ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Allow read for all on system_configurations" ON public.system_configurations FOR SELECT USING (true);
CREATE POLICY "Allow write for all on system_configurations" ON public.system_configurations FOR ALL USING (true);

-- Seed global default settings
INSERT INTO public.system_configurations (
    id, school_id, system_name, system_title, default_language, default_timezone, date_format, time_format,
    allow_new_registrations, maintenance_mode, multi_institution_support, data_anonymization, enable_two_factor,
    email_notifications, sms_notifications, auto_logout_minutes, session_timeout_minutes, login_page_message,
    security_settings, email_sms_settings, modules_settings, appearance_settings, payments_settings,
    integrations_settings, backup_restore_settings, advanced_settings
) VALUES (
    'c0f1da7a-0000-0000-0000-000000000000',
    NULL,
    'School ERP',
    'Next Generation School Management',
    'English',
    '(UTC+05:30) Asia/Kolkata',
    'May 24, 2025 (MMM DD, YYYY)',
    '12 Hour (hh:mm AM/PM)',
    true,
    false,
    true,
    false,
    true,
    true,
    true,
    30,
    120,
    'Welcome to School ERP. Please login with your credentials.',
    '{"password_policy": "Strong", "session_limit": 5, "ip_whitelist": [], "failed_attempts_lockout": 5}'::jsonb,
    '{"smtp_host": "smtp.shamiit-infra.com", "smtp_port": 587, "sms_provider": "Twilio", "twilio_sender": "+1-888-SHAMIIT"}'::jsonb,
    '{"academics": true, "finance": true, "hr_payroll": true, "transport": true}'::jsonb,
    '{"theme": "Dark", "primary_color": "#4F46E5", "sidebar_layout": "Default"}'::jsonb,
    '{"currency": "INR", "payment_gateways": ["Razorpay", "Stripe"], "auto_invoice": true}'::jsonb,
    '{"biometric_sync": true, "zoom_integration": false, "google_classroom": false}'::jsonb,
    '{"auto_backup": true, "backup_interval": "Daily", "retention_days": 30}'::jsonb,
    '{"debug_mode": false, "query_caching": true}'::jsonb
) ON CONFLICT DO NOTHING;
