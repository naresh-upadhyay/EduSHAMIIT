-- ============================================================================
-- Migration 216: Rename bus_routes table to vehicles & drop route_name column
-- ============================================================================

DO $$
BEGIN
    -- 1. Rename table from bus_routes to vehicles if bus_routes exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'bus_routes'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = 'vehicles'
        ) THEN
            ALTER TABLE public.bus_routes RENAME TO vehicles;
        END IF;
    END IF;

    -- 2. Drop route_name column from vehicles table if it exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'vehicles' AND column_name = 'route_name'
    ) THEN
        ALTER TABLE public.vehicles DROP COLUMN route_name;
    END IF;
END $$;

-- 3. Ensure Row Level Security (RLS) is enabled for vehicles table
ALTER TABLE IF EXISTS public.vehicles ENABLE ROW LEVEL SECURITY;

-- 4. Ensure RLS read policy exists for vehicles table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'vehicles' AND policyname = 'anyone_read_vehicles'
    ) THEN
        CREATE POLICY "anyone_read_vehicles" ON public.vehicles FOR SELECT USING (true);
    END IF;
END $$;
