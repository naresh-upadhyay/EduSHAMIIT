-- ============================================================================
-- Migration 227: Schedule Cancellation Reason & Granular Permissions
-- Adds cancellation_reason to public.schedules table and updates permissions index
-- ============================================================================

-- 1. Add cancellation_reason to schedules table
ALTER TABLE public.schedules 
ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;

-- 2. Create index on status for quick filtering of cancelled/active schedules
CREATE INDEX IF NOT EXISTS idx_schedules_status ON public.schedules(status);

-- 3. Update permission values in schedule_participants if needed
-- Ensures 'read_write', 'read_only', 'can_edit', 'can_view' are indexed
CREATE INDEX IF NOT EXISTS idx_schedule_participants_perm ON public.schedule_participants(schedule_id, user_id, permission);
