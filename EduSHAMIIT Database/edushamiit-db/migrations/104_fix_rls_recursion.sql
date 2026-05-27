-- Migration: 104_fix_rls_recursion.sql
-- Description: Redefine get_user_school_id() to bypass RLS recursion by using SECURITY DEFINER

CREATE OR REPLACE FUNCTION public.get_user_school_id()
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public
 STABLE
AS $function$
BEGIN
  RETURN (SELECT school_id FROM public.profiles WHERE id = auth.uid());
END;
$function$;
