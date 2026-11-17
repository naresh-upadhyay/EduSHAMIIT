-- Migration 527: Add device_id to school_upi_accounts for hardware-bound Payment Bridge notifications
-- Authoritative architecture: multiple UPI accounts can link to the same Payment Bridge terminal device.

ALTER TABLE public.school_upi_accounts 
ADD COLUMN IF NOT EXISTS device_id VARCHAR(100);

CREATE INDEX IF NOT EXISTS idx_school_upi_accounts_device_id 
ON public.school_upi_accounts(school_id, device_id);

-- Optional: Link existing default campus UPI account to active terminal if available
UPDATE public.school_upi_accounts
SET device_id = 'PB-DEV-WEB001'
WHERE school_id = '11111111-1111-1111-1111-111111111111' 
  AND device_id IS NULL;
