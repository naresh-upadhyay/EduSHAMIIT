-- Migration: 427_ai_assistant_enterprise_enhancements.sql
-- Enterprise AI Assistant Module Enhancements: Conversations, Tool Executions, Usage Tracking, Feedback, Attachments

-- 1. Conversation Metadata Table
CREATE TABLE IF NOT EXISTS public.ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT 'New Conversation',
    context_module TEXT DEFAULT 'general',
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    is_archived BOOLEAN NOT NULL DEFAULT false,
    model TEXT DEFAULT 'gemini-1.5-flash',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Backfill existing session IDs from ai_chat_history
INSERT INTO public.ai_conversations (id, school_id, user_id, title, created_at, updated_at)
SELECT DISTINCT ON (session_id)
    session_id AS id,
    school_id,
    user_id,
    COALESCE(NULLIF(SUBSTRING(content FROM 1 FOR 60), ''), 'Previous Chat') AS title,
    created_at,
    created_at AS updated_at
FROM public.ai_chat_history
WHERE session_id IS NOT NULL AND user_id IS NOT NULL
ORDER BY session_id, created_at ASC
ON CONFLICT (id) DO NOTHING;

-- 2. Enhance Existing ai_chat_history Table
ALTER TABLE public.ai_chat_history ADD COLUMN IF NOT EXISTS feedback_rating INT DEFAULT 0;
ALTER TABLE public.ai_chat_history ADD COLUMN IF NOT EXISTS feedback_text TEXT;
ALTER TABLE public.ai_chat_history ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'completed';
ALTER TABLE public.ai_chat_history ADD COLUMN IF NOT EXISTS tokens_used INT DEFAULT 0;
ALTER TABLE public.ai_chat_history ADD COLUMN IF NOT EXISTS duration_ms INT DEFAULT 0;
ALTER TABLE public.ai_chat_history ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.ai_chat_history ADD COLUMN IF NOT EXISTS parent_message_id UUID REFERENCES public.ai_chat_history(id) ON DELETE SET NULL;

-- 3. AI Attachments Table
CREATE TABLE IF NOT EXISTS public.ai_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    session_id UUID,
    message_id UUID REFERENCES public.ai_chat_history(id) ON DELETE CASCADE,
    file_name TEXT NOT NULL,
    file_type TEXT,
    file_size BIGINT,
    file_url TEXT,
    storage_path TEXT,
    extracted_text TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 4. AI Tool Execution Logs Table
CREATE TABLE IF NOT EXISTS public.ai_tool_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    session_id UUID,
    message_id UUID REFERENCES public.ai_chat_history(id) ON DELETE SET NULL,
    tool_name TEXT NOT NULL,
    input_params JSONB NOT NULL DEFAULT '{}'::jsonb,
    output_result JSONB,
    status TEXT NOT NULL DEFAULT 'completed', -- 'pending_confirmation', 'confirmed', 'completed', 'failed', 'cancelled'
    confirmed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    confirmed_at TIMESTAMP WITH TIME ZONE,
    execution_time_ms INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 5. AI Usage Tracking and Cost Management Table
CREATE TABLE IF NOT EXISTS public.ai_usage_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    session_id UUID,
    provider TEXT NOT NULL DEFAULT 'google',
    model TEXT NOT NULL DEFAULT 'gemini-1.5-flash',
    prompt_tokens INT NOT NULL DEFAULT 0,
    completion_tokens INT NOT NULL DEFAULT 0,
    total_tokens INT NOT NULL DEFAULT 0,
    estimated_cost NUMERIC(10, 6) DEFAULT 0,
    duration_ms INT DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'success',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 6. AI Message Feedback Table
CREATE TABLE IF NOT EXISTS public.ai_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    session_id UUID,
    message_id UUID REFERENCES public.ai_chat_history(id) ON DELETE CASCADE,
    rating INT NOT NULL CHECK (rating IN (-1, 1)), -- 1 = Like, -1 = Dislike
    feedback_text TEXT,
    category TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 7. AI Provider & Model Configuration Table
CREATE TABLE IF NOT EXISTS public.ai_provider_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    provider_name TEXT NOT NULL,
    model_name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    is_default BOOLEAN DEFAULT false,
    is_enabled BOOLEAN DEFAULT true,
    settings JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 8. Performance Indexes
CREATE INDEX IF NOT EXISTS idx_ai_conversations_user ON public.ai_conversations(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_school ON public.ai_conversations(school_id);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_pinned ON public.ai_conversations(user_id, is_pinned) WHERE is_pinned = true;
CREATE INDEX IF NOT EXISTS idx_ai_conversations_archived ON public.ai_conversations(user_id, is_archived) WHERE is_archived = true;

CREATE INDEX IF NOT EXISTS idx_ai_attachments_session ON public.ai_attachments(session_id);
CREATE INDEX IF NOT EXISTS idx_ai_attachments_user ON public.ai_attachments(user_id);

CREATE INDEX IF NOT EXISTS idx_ai_tool_executions_session ON public.ai_tool_executions(session_id);
CREATE INDEX IF NOT EXISTS idx_ai_tool_executions_user ON public.ai_tool_executions(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_tool_executions_tool ON public.ai_tool_executions(tool_name, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ai_usage_logs_school ON public.ai_usage_logs(school_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_usage_logs_user ON public.ai_usage_logs(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ai_feedback_message ON public.ai_feedback(message_id);

-- 9. Seed Default Provider Configurations if not present
INSERT INTO public.ai_provider_configs (provider_name, model_name, display_name, is_default, is_enabled)
VALUES
    ('google', 'gemini-1.5-flash', 'Gemini 1.5 Flash (Fast)', true, true),
    ('google', 'gemini-2.5-pro', 'Gemini 2.5 Pro (Deep Reasoning)', false, true),
    ('google', 'gemini-2.5-flash', 'Gemini 2.5 Flash', false, true),
    ('openai', 'gpt-4o', 'GPT-4o', false, true),
    ('anthropic', 'claude-3-5-sonnet', 'Claude 3.5 Sonnet', false, true)
ON CONFLICT DO NOTHING;

-- 10. Enable Row Level Security (RLS) on new tables
ALTER TABLE public.ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_tool_executions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_usage_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_provider_configs ENABLE ROW LEVEL SECURITY;

-- Dynamic RLS Policies
DROP POLICY IF EXISTS "Users can manage own conversations" ON public.ai_conversations;
CREATE POLICY "Users can manage own conversations" ON public.ai_conversations
    USING (auth.uid() = user_id OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Users can manage own attachments" ON public.ai_attachments;
CREATE POLICY "Users can manage own attachments" ON public.ai_attachments
    USING (auth.uid() = user_id OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Users can view own tool executions" ON public.ai_tool_executions;
CREATE POLICY "Users can view own tool executions" ON public.ai_tool_executions
    USING (auth.uid() = user_id OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Users can view own usage logs" ON public.ai_usage_logs;
CREATE POLICY "Users can view own usage logs" ON public.ai_usage_logs
    USING (auth.uid() = user_id OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Users can manage own feedback" ON public.ai_feedback;
CREATE POLICY "Users can manage own feedback" ON public.ai_feedback
    USING (auth.uid() = user_id OR auth.uid() IS NULL);

DROP POLICY IF EXISTS "Public can view enabled provider configs" ON public.ai_provider_configs;
CREATE POLICY "Public can view enabled provider configs" ON public.ai_provider_configs
    FOR SELECT USING (is_enabled = true);
