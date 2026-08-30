-- Migration: 206_drop_all_redundant_tables_and_columns.sql
-- Description: Hard drop all redundant tables (bus_routes, bus_stops, bus_locations, system_alerts, announcements, smart_notifications) and drop duplicate columns in drivers.

-- ──────────────────────────────────────────────
-- 1. MIGRATE DATA TO PRIMARY TABLES BEFORE DROPPING
-- ──────────────────────────────────────────────

-- Ensure notifications table columns exist for compatibility
ALTER TABLE IF EXISTS public.notifications ADD COLUMN IF NOT EXISTS message TEXT;
ALTER TABLE IF EXISTS public.notifications ADD COLUMN IF NOT EXISTS category TEXT;

-- Migrate any announcements into notifications
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'announcements') THEN
    INSERT INTO public.notifications (school_id, title, body, type, is_read, created_at)
    SELECT school_id, title, COALESCE(description, title), 'announcement', FALSE, created_at
    FROM public.announcements
    ON CONFLICT DO NOTHING;
  END IF;
END $$;

-- Migrate any system_alerts into notifications
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'system_alerts') THEN
    INSERT INTO public.notifications (school_id, title, body, type, is_read, created_at)
    SELECT school_id, title, COALESCE(description, title), 'system_alert', COALESCE(is_read, FALSE), created_at
    FROM public.system_alerts
    ON CONFLICT DO NOTHING;
  END IF;
END $$;

-- Migrate bus_routes records into vehicles if not present
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'bus_routes') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'bus_routes' AND column_name = 'bus_number') THEN
      INSERT INTO public.vehicles (id, school_id, vehicle_no, seating_capacity, status)
      SELECT id, school_id, bus_number, COALESCE(total_capacity, 40), COALESCE(status, 'Active')
      FROM public.bus_routes
      ON CONFLICT (school_id, vehicle_no) DO NOTHING;
    END IF;
  END IF;
END $$;


-- ──────────────────────────────────────────────
-- 2. HARD DROP ALL REDUNDANT TABLES
-- ──────────────────────────────────────────────

DROP TABLE IF EXISTS public.bus_locations CASCADE;
DROP TABLE IF EXISTS public.bus_stops CASCADE;
DROP TABLE IF EXISTS public.bus_routes CASCADE;
DROP TABLE IF EXISTS public.smart_notifications CASCADE;
DROP TABLE IF EXISTS public.system_alerts CASCADE;
DROP TABLE IF EXISTS public.announcements CASCADE;


-- ──────────────────────────────────────────────
-- 3. DROP DUPLICATE COLUMNS IN DRIVERS TABLE
-- ──────────────────────────────────────────────

ALTER TABLE public.drivers DROP COLUMN IF EXISTS name CASCADE;
ALTER TABLE public.drivers DROP COLUMN IF EXISTS email CASCADE;
ALTER TABLE public.drivers DROP COLUMN IF EXISTS phone CASCADE;
ALTER TABLE public.drivers DROP COLUMN IF EXISTS photo_url CASCADE;
ALTER TABLE public.drivers DROP COLUMN IF EXISTS date_of_birth CASCADE;
ALTER TABLE public.drivers DROP COLUMN IF EXISTS blood_group CASCADE;
ALTER TABLE public.drivers DROP COLUMN IF EXISTS address CASCADE;


-- ──────────────────────────────────────────────
-- 4. CLEANUP VIEWS NO LONGER NEEDED
-- ──────────────────────────────────────────────

DROP VIEW IF EXISTS public.vw_all_user_notifications CASCADE;
DROP VIEW IF EXISTS public.vw_drivers CASCADE;


-- ──────────────────────────────────────────────
-- 5. RE-CREATE UNIFIED RPC FUNCTIONS FOR NOTIFICATIONS
-- ──────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.rpc_get_user_notifications(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.rpc_get_user_notifications(UUID) CASCADE;
CREATE OR REPLACE FUNCTION public.rpc_get_user_notifications(p_user_id UUID, p_school_id UUID DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_notifs JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', n.id,
      'title', n.title,
      'message', COALESCE(n.body, n.title),
      'category', COALESCE(n.type, 'General'),
      'is_read', COALESCE(n.is_read, FALSE),
      'created_at', n.created_at
    )
  ), '[]'::jsonb) INTO v_notifs
  FROM public.notifications n
  WHERE (n.user_id = p_user_id OR n.user_id IS NULL)
    AND (p_school_id IS NULL OR n.school_id = p_school_id)
  ORDER BY n.created_at DESC
  LIMIT 50;

  RETURN jsonb_build_object(
    'success', true,
    'notifications', v_notifs
  );
END;
$$;
