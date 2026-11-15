-- ============================================================================
-- Migration 509: Comprehensive AI Assistant & Chat Subsystem Enhancements
-- 1. Conversation Lifecycle & Metadata Tracking (Pinned, Archived, Context)
-- 2. Chat Message Attachments & Multi-modal Data Retention
-- 3. High-Performance Composite Indexes for Left Drawer & Chat History
-- 4. Attachment Storage Bucket Definition
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. AI CONVERSATIONS ENHANCEMENTS
-- ----------------------------------------------------------------------------
ALTER TABLE public.ai_conversations ADD COLUMN IF NOT EXISTS pinned_at TIMESTAMPTZ;
ALTER TABLE public.ai_conversations ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;
ALTER TABLE public.ai_conversations ADD COLUMN IF NOT EXISTS last_message TEXT;
ALTER TABLE public.ai_conversations ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.ai_conversations ADD COLUMN IF NOT EXISTS message_count INT DEFAULT 0;
ALTER TABLE public.ai_conversations ADD COLUMN IF NOT EXISTS active_context TEXT DEFAULT 'general';

-- Backfill last_message and last_message_at from ai_chat_history where missing
UPDATE public.ai_conversations c
SET 
    last_message = sub.content,
    last_message_at = sub.created_at
FROM (
    SELECT DISTINCT ON (session_id) session_id, content, created_at
    FROM public.ai_chat_history
    ORDER BY session_id, created_at DESC
) sub
WHERE c.id::text = sub.session_id::text
  AND (c.last_message IS NULL OR c.last_message = '');

-- ----------------------------------------------------------------------------
-- 2. AI CHAT HISTORY MULTI-MODAL & ATTACHMENT FIELDS
-- ----------------------------------------------------------------------------
ALTER TABLE public.ai_chat_history ADD COLUMN IF NOT EXISTS attachment_url TEXT;
ALTER TABLE public.ai_chat_history ADD COLUMN IF NOT EXISTS attachment_type TEXT;
ALTER TABLE public.ai_chat_history ADD COLUMN IF NOT EXISTS attachment_name TEXT;
ALTER TABLE public.ai_chat_history ADD COLUMN IF NOT EXISTS thought_process JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.ai_chat_history ADD COLUMN IF NOT EXISTS model_used TEXT DEFAULT 'groq-llama-3.3-70b';

-- ----------------------------------------------------------------------------
-- 3. HIGH-PERFORMANCE COMPOSITE INDEXES
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_ai_conversations_user_archived 
    ON public.ai_conversations(user_id, is_archived, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_ai_conversations_user_pinned 
    ON public.ai_conversations(user_id, is_pinned, pinned_at DESC);

CREATE INDEX IF NOT EXISTS idx_ai_conversations_school_user 
    ON public.ai_conversations(school_id, user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_ai_chat_history_session_created 
    ON public.ai_chat_history(session_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_ai_chat_history_user_role 
    ON public.ai_chat_history(user_id, role, created_at DESC);

-- ----------------------------------------------------------------------------
-- 4. STORAGE BUCKET FOR AI ATTACHMENTS (Supabase Storage)
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'ai-chat-attachments',
    'ai-chat-attachments',
    true,
    52428800, -- 50MB
    ARRAY[
        'image/png', 'image/jpeg', 'image/webp', 'image/gif',
        'application/pdf',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'text/plain', 'text/csv'
    ]
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 52428800;

-- Storage Policy: Allow public read of ai attachments
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' 
          AND policyname = 'Public Access for AI Chat Attachments'
    ) THEN
        CREATE POLICY "Public Access for AI Chat Attachments"
        ON storage.objects FOR SELECT
        USING (bucket_id = 'ai-chat-attachments');
    END IF;
END $$;
