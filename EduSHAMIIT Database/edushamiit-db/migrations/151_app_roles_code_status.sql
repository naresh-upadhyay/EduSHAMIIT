-- Database migration: 151_app_roles_code_status.sql
-- Add code, status, and updated_at columns to public.app_roles table

ALTER TABLE public.app_roles ADD COLUMN IF NOT EXISTS code VARCHAR(100) UNIQUE;
ALTER TABLE public.app_roles ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'Active';
ALTER TABLE public.app_roles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now());

-- Update existing seeded roles to have uppercase role codes based on their name
UPDATE public.app_roles SET code = 'ROLE_' || UPPER(name) WHERE code IS NULL;
UPDATE public.app_roles SET status = 'Active' WHERE status IS NULL;

-- Make code NOT NULL now that it is fully populated
ALTER TABLE public.app_roles ALTER COLUMN code SET NOT NULL;

-- Add a trigger to automatically update updated_at timestamp on row modifications
CREATE OR REPLACE FUNCTION public.handle_app_roles_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc', now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_app_roles_updated_at ON public.app_roles;
CREATE TRIGGER set_app_roles_updated_at
    BEFORE UPDATE ON public.app_roles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_app_roles_updated_at();
