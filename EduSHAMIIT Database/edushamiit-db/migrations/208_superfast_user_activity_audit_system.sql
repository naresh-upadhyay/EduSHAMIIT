-- Migration: 208_superfast_user_activity_audit_system.sql
-- Description: Superfast PostgreSQL-native audit logging system using PL/pgSQL triggers and optimized RPC endpoints for personal user activity history.

-- ──────────────────────────────────────────────
-- 1. OPTIMIZE AUDIT_LOGS INDEXES & POLICIES (Table created in 153_audit_logs.sql)
-- ──────────────────────────────────────────────

-- Ensure columns exist via ALTER TABLE
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE SET NULL;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS changes JSONB;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- Fast B-Tree Indexes for User Activity History Retrieval
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_history ON public.audit_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_school_history ON public.audit_logs(school_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_event_module ON public.audit_logs(event_type, module);

-- Enable RLS on audit_logs
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users View Own Audit Logs" ON public.audit_logs;
CREATE POLICY "Users View Own Audit Logs" ON public.audit_logs
FOR SELECT USING (
  user_id = auth.uid() 
  OR public.get_user_school_id(auth.uid()) = school_id
);


-- ──────────────────────────────────────────────
-- 2. PL/pgSQL AUTOMATED GENERIC AUDIT TRIGGER FUNCTION
-- ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.proc_capture_table_audit_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_school_id UUID;
  v_user_name TEXT := 'System';
  v_user_email TEXT := 'system@schoolerp.com';
  v_user_role TEXT := 'System';
  v_action TEXT;
  v_event_type TEXT;
  v_changes JSONB := '{}'::jsonb;
  v_resource TEXT := '-';
BEGIN
  -- Determine user_id from NEW/OLD audit columns or auth.uid()
  IF (TG_OP = 'DELETE') THEN
    v_user_id := COALESCE(OLD.updated_by, OLD.created_by, auth.uid());
    v_school_id := OLD.school_id;
    v_event_type := 'Delete';
    v_action := 'Deleted Record in ' || TG_TABLE_NAME;
    v_changes := jsonb_build_object('old_data', to_jsonb(OLD));
    v_resource := COALESCE(OLD.id::text, '-');
  ELSIF (TG_OP = 'UPDATE') THEN
    v_user_id := COALESCE(NEW.updated_by, NEW.created_by, auth.uid());
    v_school_id := NEW.school_id;
    v_event_type := 'Update';
    v_action := 'Updated Record in ' || TG_TABLE_NAME;
    v_changes := jsonb_build_object('old_data', to_jsonb(OLD), 'new_data', to_jsonb(NEW));
    v_resource := COALESCE(NEW.id::text, '-');
  ELSE -- INSERT
    v_user_id := COALESCE(NEW.created_by, NEW.updated_by, auth.uid());
    v_school_id := NEW.school_id;
    v_event_type := 'Create';
    v_action := 'Created Record in ' || TG_TABLE_NAME;
    v_changes := jsonb_build_object('new_data', to_jsonb(NEW));
    v_resource := COALESCE(NEW.id::text, '-');
  END IF;

  -- Lookup User Profile Details if user_id is present
  IF v_user_id IS NOT NULL THEN
    SELECT full_name, email, role, COALESCE(v_school_id, school_id)
    INTO v_user_name, v_user_email, v_user_role, v_school_id
    FROM public.profiles
    WHERE id = v_user_id LIMIT 1;
  END IF;

  -- Insert Audit Record asynchronously inside DB engine
  INSERT INTO public.audit_logs (
    school_id,
    user_id,
    user_email,
    user_name,
    user_role,
    event_type,
    module,
    action,
    resource,
    resource_type,
    status,
    changes,
    created_at
  )
  VALUES (
    v_school_id,
    v_user_id,
    COALESCE(v_user_email, 'system@schoolerp.com'),
    COALESCE(v_user_name, 'System User'),
    COALESCE(v_user_role, 'User'),
    v_event_type,
    INITCAP(REPLACE(TG_TABLE_NAME, '_', ' ')),
    v_action,
    v_resource,
    TG_TABLE_NAME,
    'Success',
    v_changes,
    NOW()
  );

  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;


-- ──────────────────────────────────────────────
-- 3. ATTACH AUDIT TRIGGER TO CORE BUSINESS TABLES
-- ──────────────────────────────────────────────

DO $$
DECLARE
  tbl TEXT;
  audit_tables TEXT[] := ARRAY[
    'attendance', 'results', 'payments', 'fees', 'homework',
    'homework_submissions', 'exams', 'exam_submissions', 'leave_applications',
    'profiles', 'vehicles', 'transport_routes', 'driver_assignments', 'vehicle_trips'
  ];
BEGIN
  FOREACH tbl IN ARRAY audit_tables
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_capture ON public.%I;', tbl);
    EXECUTE format('CREATE TRIGGER trg_audit_capture AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.proc_capture_table_audit_event();', tbl);
  END LOOP;
END $$;


-- ──────────────────────────────────────────────
-- 4. SUPERFAST RPC ENDPOINT FOR PERSONAL USER ACTIVITY HISTORY
-- ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.rpc_get_user_my_activity_history(
  p_user_id UUID, 
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_activities JSONB;
  v_total INT := 0;
BEGIN
  SELECT COUNT(*) INTO v_total
  FROM public.audit_logs
  WHERE user_id = p_user_id;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', a.id,
      'event_type', a.event_type,
      'module', a.module,
      'action', a.action,
      'resource', a.resource,
      'resource_type', a.resource_type,
      'status', a.status,
      'ip_address', a.ip_address,
      'timestamp', a.created_at
    )
  ), '[]'::jsonb) INTO v_activities
  FROM (
    SELECT id, event_type, module, action, resource, resource_type, status, ip_address, created_at
    FROM public.audit_logs
    WHERE user_id = p_user_id
    ORDER BY created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) a;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', p_user_id,
    'total_activities', v_total,
    'activities', v_activities
  );
END;
$$;


-- ──────────────────────────────────────────────
-- 5. FAST AUTH ACTIVITY LOGGING RPC
-- ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.rpc_record_user_auth_activity(
  p_user_id UUID,
  p_event_type TEXT,
  p_ip_address TEXT DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL,
  p_status TEXT DEFAULT 'Success'
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
  v_school_id UUID;
  v_user_name TEXT := 'Unknown';
  v_user_email TEXT := 'unknown';
  v_user_role TEXT := 'User';
BEGIN
  IF p_user_id IS NOT NULL THEN
    SELECT school_id, full_name, email, role
    INTO v_school_id, v_user_name, v_user_email, v_user_role
    FROM public.profiles
    WHERE id = p_user_id LIMIT 1;
  END IF;

  INSERT INTO public.audit_logs (
    school_id,
    user_id,
    user_email,
    user_name,
    user_role,
    event_type,
    module,
    action,
    resource,
    ip_address,
    status,
    user_agent,
    created_at
  )
  VALUES (
    v_school_id,
    p_user_id,
    v_user_email,
    v_user_name,
    v_user_role,
    p_event_type,
    'Authentication',
    p_event_type,
    'User Session',
    p_ip_address,
    p_status,
    p_user_agent,
    NOW()
  );

  RETURN jsonb_build_object('success', true, 'recorded_at', NOW());
END;
$$;
