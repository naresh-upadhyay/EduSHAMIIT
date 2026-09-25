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

  -- Delete cascading records
  DELETE FROM public.user_documents WHERE owner_id = p_user_id;
  DELETE FROM public.user_active_sessions WHERE user_id = p_user_id;
  DELETE FROM public.group_members WHERE user_id = p_user_id;
  DELETE FROM public.notifications WHERE user_id = p_user_id;
  DELETE FROM public.drivers WHERE profile_id = p_user_id;
  DELETE FROM public.password_resets WHERE user_id = p_user_id;
  DELETE FROM public.profiles WHERE id = p_user_id;

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
  -- Lookup profile by email or phone or user_id or id
  SELECT id, school_id, email, phone
  INTO v_user_id, v_school_id, v_email, v_phone
  FROM public.profiles
  WHERE (email = p_identifier OR phone = p_identifier OR id::text = p_identifier OR user_id = p_identifier)
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'User profile not found');
  END IF;

  -- Invalidate previous pending OTPs
  UPDATE public.password_resets
  SET status = 'used'
  WHERE user_id = v_user_id AND status = 'pending';

  -- Insert new password reset / OTP record
  INSERT INTO public.password_resets (
    school_id,
    user_id,
    otp,
    expires_at,
    status,
    created_at
  )
  VALUES (
    v_school_id,
    v_user_id,
    p_otp_code,
    NOW() + INTERVAL '15 minutes',
    'pending',
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
  v_reset_id UUID;
BEGIN
  -- Lookup profile by email or phone or user_id or id
  SELECT id INTO v_user_id
  FROM public.profiles
  WHERE (email = p_identifier OR phone = p_identifier OR id::text = p_identifier OR user_id = p_identifier)
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'User profile not found');
  END IF;

  -- Validate OTP matching token
  SELECT id INTO v_reset_id
  FROM public.password_resets
  WHERE user_id = v_user_id
    AND otp = p_otp_code
    AND status IN ('pending', 'verified')
    AND expires_at >= NOW()
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_reset_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Invalid or expired OTP code');
  END IF;

  -- Reset lockout and update last login
  UPDATE public.profiles
  SET last_failed_login = NULL,
      failed_login_attempts = 0,
      lockout_until = NULL,
      updated_at = NOW()
  WHERE id = v_user_id;

  -- Mark OTP as used
  UPDATE public.password_resets
  SET status = 'used'
  WHERE id = v_reset_id;

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

GRANT EXECUTE ON FUNCTION public.rpc_admin_delete_user_cascade(UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_process_send_login_otp(TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_process_verify_login_otp(TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_process_payment_webhook(UUID, TEXT, TEXT) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
