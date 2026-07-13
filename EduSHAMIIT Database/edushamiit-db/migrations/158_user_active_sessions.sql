-- Database migration: 158_user_active_sessions.sql
-- Create user active sessions table to track concurrent sessions per user.

CREATE TABLE IF NOT EXISTS public.user_active_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_user_active_sessions_user ON public.user_active_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_active_sessions_token ON public.user_active_sessions(token);
