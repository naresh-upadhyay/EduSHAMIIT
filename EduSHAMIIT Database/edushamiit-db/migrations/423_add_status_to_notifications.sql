-- ============================================================================
-- Migration 423: Add Status Column to Notifications Table for System Alerts
-- ============================================================================

ALTER TABLE public.notifications 
ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'New';

-- Create index for status column
CREATE INDEX IF NOT EXISTS idx_notifications_status ON public.notifications(status);
