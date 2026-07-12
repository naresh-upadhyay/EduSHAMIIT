-- Database migration: 152_app_roles_draft_permissions.sql
-- Add draft_permissions column to public.app_roles table to support draft vs published permissions workflow

ALTER TABLE public.app_roles ADD COLUMN IF NOT EXISTS draft_permissions TEXT[] DEFAULT '{}'::text[];

-- Initialize draft_permissions with current permissions so existing roles do not have empty drafts
UPDATE public.app_roles SET draft_permissions = permissions WHERE draft_permissions IS NULL OR draft_permissions = '{}'::text[];
