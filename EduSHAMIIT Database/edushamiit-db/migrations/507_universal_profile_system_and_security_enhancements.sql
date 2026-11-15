-- Migration 507: Universal Profile System & Enterprise Security Enhancements
-- Adds structured address, guardian relations, TOTP 2FA secret/codes, locale/preferences,
-- document verification metadata, and performance indexes.

DO $$
BEGIN
    -- 1. Profiles Table Enhancements
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS preferred_language VARCHAR(50) DEFAULT 'English (US)';
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS timezone VARCHAR(100) DEFAULT '(GMT +05:30) Asia/Kolkata';
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS preferred_theme VARCHAR(20) DEFAULT 'system';
        
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS address_line1 TEXT;
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS address_line2 TEXT;
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS city VARCHAR(100);
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS state VARCHAR(100);
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS pincode VARCHAR(20);
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS country VARCHAR(100) DEFAULT 'India';
        
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS guardian_relationship VARCHAR(50);
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS guardian_phone VARCHAR(30);
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS guardian_email VARCHAR(255);
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS guardian_address TEXT;
        
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS two_factor_secret TEXT;
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS two_factor_backup_codes JSONB DEFAULT '[]'::jsonb;
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT FALSE;
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone_verified BOOLEAN DEFAULT FALSE;
        ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS emergency_contact_relation VARCHAR(50);
    END IF;

    -- 2. Documents Table Enhancements
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'documents') THEN
        ALTER TABLE public.documents ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
        ALTER TABLE public.documents ADD COLUMN IF NOT EXISTS file_size BIGINT;
        ALTER TABLE public.documents ADD COLUMN IF NOT EXISTS mime_type VARCHAR(100);
    END IF;
END $$;

-- 3. Optimization Indexes
CREATE INDEX IF NOT EXISTS idx_documents_user_id ON public.documents(user_id);
CREATE INDEX IF NOT EXISTS idx_user_active_sessions_user_id ON public.user_active_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at_desc ON public.audit_logs(created_at DESC);
