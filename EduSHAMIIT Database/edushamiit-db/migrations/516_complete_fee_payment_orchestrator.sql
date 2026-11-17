-- ============================================================================
-- Migration 516: Complete Fee Payment Orchestrator, UPI & Bank Accounts,
-- Dynamic QR Unique-Paise Engine, and Payment Bridge Integration
-- ============================================================================

-- 1. INSTITUTION PAYMENT SETTINGS
CREATE TABLE IF NOT EXISTS public.institution_payment_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    online_collection_enabled BOOLEAN NOT NULL DEFAULT true,
    base_currency VARCHAR(10) NOT NULL DEFAULT 'INR',
    default_payment_method VARCHAR(50) NOT NULL DEFAULT 'UPI',
    institution_display_name VARCHAR(255),
    payment_description TEXT DEFAULT 'School tuition and academic fee collection',
    reference_prefix VARCHAR(50) NOT NULL DEFAULT 'EDU',
    receipt_prefix VARCHAR(50) NOT NULL DEFAULT 'REC-2026-',
    allow_partial_payments BOOLEAN NOT NULL DEFAULT true,
    allow_advance_payments BOOLEAN NOT NULL DEFAULT false,
    allow_multiple_payments BOOLEAN NOT NULL DEFAULT true,
    allow_student_self_pay BOOLEAN NOT NULL DEFAULT true,
    allow_offline_entry BOOLEAN NOT NULL DEFAULT true,
    qr_validity_minutes INTEGER NOT NULL DEFAULT 5,
    grace_period_minutes INTEGER NOT NULL DEFAULT 2,
    unique_paise_enabled BOOLEAN NOT NULL DEFAULT true,
    unique_paise_window_minutes INTEGER NOT NULL DEFAULT 10,
    max_additional_paise INTEGER NOT NULL DEFAULT 99,
    refund_policy_days INTEGER NOT NULL DEFAULT 7,
    auto_settle_on_bridge_notification BOOLEAN NOT NULL DEFAULT true,
    direct_bank_transfer_enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_institution_payment_settings_school UNIQUE (school_id)
);

-- 2. INSTITUTION UPI ACCOUNTS
CREATE TABLE IF NOT EXISTS public.school_upi_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    vpa VARCHAR(150) NOT NULL,
    display_name VARCHAR(150) NOT NULL,
    beneficiary_name VARCHAR(150) NOT NULL,
    bank_name VARCHAR(150),
    is_default BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    qr_enabled BOOLEAN NOT NULL DEFAULT true,
    intent_enabled BOOLEAN NOT NULL DEFAULT true,
    max_amount_paise BIGINT DEFAULT 10000000, -- ₹1,00,000 max UPI txn
    verification_status VARCHAR(50) NOT NULL DEFAULT 'VERIFIED',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_school_upi_vpa UNIQUE (school_id, vpa)
);

-- 3. INSTITUTION BANK ACCOUNTS
CREATE TABLE IF NOT EXISTS public.school_bank_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    account_nickname VARCHAR(150) NOT NULL,
    bank_name VARCHAR(150) NOT NULL,
    branch_name VARCHAR(150),
    account_holder_name VARCHAR(150) NOT NULL,
    account_number VARCHAR(100) NOT NULL,
    ifsc_code VARCHAR(50) NOT NULL,
    account_type VARCHAR(50) NOT NULL DEFAULT 'Current',
    currency VARCHAR(10) NOT NULL DEFAULT 'INR',
    campus_name VARCHAR(150),
    category_name VARCHAR(150) DEFAULT 'Tuition & General Fees',
    is_default BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    verification_status VARCHAR(50) NOT NULL DEFAULT 'VERIFIED',
    internal_remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. UPDATE PAYMENT INTENTS TABLE (Add grace, UTR, and receipt tracking)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'payment_intents' AND column_name = 'grace_expires_at'
    ) THEN
        ALTER TABLE public.payment_intents ADD COLUMN grace_expires_at TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'payment_intents' AND column_name = 'utr_number'
    ) THEN
        ALTER TABLE public.payment_intents ADD COLUMN utr_number VARCHAR(100);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'payment_intents' AND column_name = 'receipt_number'
    ) THEN
        ALTER TABLE public.payment_intents ADD COLUMN receipt_number VARCHAR(100);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'payment_intents' AND column_name = 'paid_at'
    ) THEN
        ALTER TABLE public.payment_intents ADD COLUMN paid_at TIMESTAMPTZ;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'payment_intents' AND column_name = 'payment_method'
    ) THEN
        ALTER TABLE public.payment_intents ADD COLUMN payment_method VARCHAR(50) DEFAULT 'UPI';
    END IF;

    -- Allow manual UTR review without mandatory notification_event_id
    ALTER TABLE public.payment_manual_reviews ALTER COLUMN notification_event_id DROP NOT NULL;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'payment_manual_reviews' AND column_name = 'intent_id'
    ) THEN
        ALTER TABLE public.payment_manual_reviews ADD COLUMN intent_id UUID REFERENCES public.payment_intents(id) ON DELETE CASCADE;
    END IF;
END $$;

-- 5. INDEXES FOR HIGH-PERFORMANCE 10-MINUTE UNIQUE PAISE LOOKUP
CREATE INDEX IF NOT EXISTS idx_payment_intents_unique_window 
ON public.payment_intents (school_id, total_amount_paise, created_at DESC)
WHERE status IN ('PENDING', 'AWAITING_VERIFICATION', 'COMPLETED', 'VERIFIED_SUCCESS');

CREATE INDEX IF NOT EXISTS idx_school_upi_accounts_lookup 
ON public.school_upi_accounts (school_id, is_active, is_default);

CREATE INDEX IF NOT EXISTS idx_school_bank_accounts_lookup 
ON public.school_bank_accounts (school_id, is_active, is_default);

-- 6. SEED ESSENTIAL INSTITUTION PAYMENT CONFIGURATIONS
DO $$
DECLARE
    r_school RECORD;
BEGIN
    FOR r_school IN SELECT id, name FROM public.schools LOOP
        -- Default Institution Payment Settings
        INSERT INTO public.institution_payment_settings (
            school_id, online_collection_enabled, base_currency, default_payment_method,
            institution_display_name, payment_description, reference_prefix, receipt_prefix,
            allow_partial_payments, allow_advance_payments, allow_multiple_payments,
            allow_student_self_pay, allow_offline_entry, qr_validity_minutes,
            grace_period_minutes, unique_paise_enabled, unique_paise_window_minutes,
            max_additional_paise, refund_policy_days, auto_settle_on_bridge_notification,
            direct_bank_transfer_enabled
        ) VALUES (
            r_school.id, true, 'INR', 'UPI',
            r_school.name, 'Academic Tuition & Institutional Fee Collection', 'EDU', 'REC-2026-',
            true, false, true,
            true, true, 5,
            2, true, 10,
            99, 7, true,
            true
        )
        ON CONFLICT (school_id) DO NOTHING;

        -- Default UPI Account
        INSERT INTO public.school_upi_accounts (
            school_id, vpa, display_name, beneficiary_name, bank_name,
            is_default, is_active, qr_enabled, intent_enabled, max_amount_paise,
            verification_status, notes
        ) VALUES (
            r_school.id, 
            LOWER(REGEXP_REPLACE(SPLIT_PART(r_school.name, ' ', 1), '[^a-zA-Z0-9]', '', 'g')) || '@okaxis',
            'Main Fee Collection UPI',
            r_school.name,
            'State Bank of India',
            true, true, true, true, 10000000,
            'VERIFIED', 'Primary institutional UPI receiving VPA for dynamic fee QR generation'
        )
        ON CONFLICT (school_id, vpa) DO NOTHING;

        -- Default Bank Account
        IF NOT EXISTS (SELECT 1 FROM public.school_bank_accounts WHERE school_id = r_school.id) THEN
            INSERT INTO public.school_bank_accounts (
                school_id, account_nickname, bank_name, branch_name,
                account_holder_name, account_number, ifsc_code, account_type,
                currency, campus_name, category_name, is_default, is_active,
                verification_status, internal_remarks
            ) VALUES (
                r_school.id, 'Main Tuition Collection Account', 'State Bank of India', 'Main Campus Branch',
                r_school.name, '39871234567', 'SBIN0001234', 'Current',
                'INR', 'Main Campus', 'Tuition & General Fees', true, true,
                'VERIFIED', 'Primary institutional bank account for direct wire, NEFT, RTGS, and IMPS'
            );
        END IF;

    END LOOP;
END $$;
