-- ============================================================
-- Migration 095: Add Auth User Deletion Helper Function
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_auth_user_id_by_email(email_addr text)
RETURNS uuid SECURITY DEFINER AS $$
BEGIN
    RETURN (SELECT id FROM auth.users WHERE email = email_addr LIMIT 1);
END;
$$ LANGUAGE plpgsql;
