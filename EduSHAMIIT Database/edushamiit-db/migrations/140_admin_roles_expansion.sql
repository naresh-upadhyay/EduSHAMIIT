-- Ensure profiles_role_check constraint is dropped (roles are dynamically managed in app_roles)
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;

