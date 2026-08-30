-- Migration: 215_auth_and_payment_webhook_procedures.sql
-- Description: Superfast atomic stored procedures for user deletion, OTP authentication flows, and payment webhook processing.

-- ──────────────────────────────────────────────
-- 1. STORED PROCEDURE: ADMIN CASCADE DELETE USER
-- ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.rpc_admin_delete_user_cascade(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'User ID required');
  END IF;

  -- Delete cascading records across all related tables
  DELETE FROM public.user_documents WHERE owner_id = p_user_id OR shared_with_id = p_user_id OR shared_by_id = p_user_id;
  DELETE FROM public.user_active_sessions WHERE user_id = p_user_id;
  DELETE FROM public.group_members WHERE member_id = p_user_id;
  DELETE FROM public.notifications WHERE user_id = p_user_id;
  DELETE FROM public.password_resets WHERE user_id = p_user_id;
  DELETE FROM public.attendance WHERE student_id = p_user_id;
  DELETE FROM public.exam_submissions WHERE student_id = p_user_id;
  DELETE FROM public.homework_submissions WHERE student_id = p_user_id;
  DELETE FROM public.student_transport WHERE student_id = p_user_id;
  DELETE FROM public.drivers WHERE profile_id = p_user_id;
  DELETE FROM public.profiles WHERE id = p_user_id;
  
  -- Also delete from auth.users if exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'users') THEN
    DELETE FROM auth.users WHERE id = p_user_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', p_user_id,
    'deleted_at', NOW()
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$;


-- ──────────────────────────────────────────────
-- 2. STORED PROCEDURE: SEND LOGIN OTP PROCESSOR
-- ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.rpc_process_send_login_otp(
  p_identifier TEXT,
  p_otp_code TEXT,
  p_ip_address TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_school_id UUID;
  v_email TEXT;
  v_phone TEXT;
BEGIN
  -- Lookup profile by email or phone
  SELECT id, school_id, email, phone
  INTO v_user_id, v_school_id, v_email, v_phone
  FROM public.profiles
  WHERE (email = p_identifier OR phone = p_identifier OR id::text = p_identifier)
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'User profile not found');
  END IF;

  -- Upsert password reset / OTP record
  INSERT INTO public.password_resets (
    school_id,
    user_id,
    email,
    token,
    created_at
  )
  VALUES (
    v_school_id,
    v_user_id,
    COALESCE(v_email, p_identifier),
    p_otp_code,
    NOW()
  );

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'email', v_email,
    'phone', v_phone,
    'created_at', NOW()
  );
END;
$$;


-- ──────────────────────────────────────────────
-- 3. STORED PROCEDURE: VERIFY LOGIN OTP PROCESSOR
-- ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.rpc_process_verify_login_otp(
  p_identifier TEXT,
  p_otp_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_valid BOOLEAN := FALSE;
BEGIN
  -- Validate OTP matching token
  SELECT user_id INTO v_user_id
  FROM public.password_resets
  WHERE (email = p_identifier OR user_id::text = p_identifier)
    AND token = p_otp_code
    AND created_at >= (NOW() - INTERVAL '15 minutes')
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Invalid or expired OTP code');
  END IF;

  -- Reset lockout and update last login
  UPDATE public.profiles
  SET last_failed_login = NULL,
      updated_at = NOW()
  WHERE id = v_user_id;

  -- Clean used OTP
  DELETE FROM public.password_resets WHERE user_id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'verified_at', NOW()
  );
END;
$$;


-- ──────────────────────────────────────────────
-- 4. STORED PROCEDURE: PAYMENT WEBHOOK PROCESSOR
-- ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.rpc_process_payment_webhook(
  p_payment_id UUID,
  p_transaction_id TEXT,
  p_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
  v_student_id UUID;
  v_school_id UUID;
  v_amount NUMERIC;
BEGIN
  UPDATE public.payments
  SET status = p_status,
      transaction_id = COALESCE(p_transaction_id, transaction_id),
      updated_at = NOW()
  WHERE id = p_payment_id
  RETURNING student_id, school_id, amount INTO v_student_id, v_school_id, v_amount;

  IF v_student_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Payment record not found');
  END IF;

  -- Update student fees ledger status if paid
  IF LOWER(p_status) = 'paid' OR LOWER(p_status) = 'success' THEN
    UPDATE public.fees
    SET status = 'Paid',
        updated_at = NOW()
    WHERE student_id = v_student_id AND school_id = v_school_id AND LOWER(status) = 'pending';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'payment_id', p_payment_id,
    'student_id', v_student_id,
    'amount', v_amount,
    'status', p_status
  );
END;
$$;
