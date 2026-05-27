-- Migration: 105_messages_rls_policy.sql
-- Description: Drop old RLS policy and establish correct view_messages policy that supports group chats

-- 1. Clean up old restrictive/incomplete policies if they exist
DROP POLICY IF EXISTS view_own_messages ON public.messages;
DROP POLICY IF EXISTS view_messages ON public.messages;

-- 2. Create the unified selective view_messages policy
-- This allows users to read:
--  - Direct messages where they are the sender
--  - Direct messages where they are the receiver
--  - Group messages for groups they are a member of
CREATE POLICY view_messages ON public.messages
FOR SELECT
USING (
    (auth.uid() = sender_id) OR
    (auth.uid() = receiver_id) OR
    (
        group_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.group_members gm
            WHERE gm.group_id = messages.group_id
            AND gm.member_id = auth.uid()
        )
    )
);
