-- ============================================================
-- Migration 108: Smart Message Notification Deduplication
-- Instead of creating a new notification for every message,
-- this trigger maintains ONE active (unread) notification per
-- conversation thread per user. When a new message arrives:
--   * If an unread notification for that conversation exists → UPDATE it
--   * Otherwise → INSERT a new notification
-- This prevents notification spam from rapid messaging.
-- Also limits body to 120 chars.
-- ============================================================

CREATE OR REPLACE FUNCTION public.trigger_message_notification_func() RETURNS TRIGGER AS $$
DECLARE
  sender_name TEXT;
  grp_name    TEXT;
  member_rec  RECORD;
  existing_id UUID;
BEGIN
  -- Resolve sender full name from profiles
  SELECT full_name INTO sender_name FROM public.profiles WHERE id = NEW.sender_id;
  IF sender_name IS NULL THEN
    sender_name := 'Someone';
  END IF;

  IF NEW.group_id IS NOT NULL THEN
    -- ── GROUP MESSAGE ──────────────────────────────────────────
    SELECT name INTO grp_name FROM public.groups WHERE id = NEW.group_id;
    IF grp_name IS NULL THEN grp_name := 'Group'; END IF;

    FOR member_rec IN
      SELECT member_id FROM public.group_members
      WHERE group_id = NEW.group_id AND member_id != NEW.sender_id
    LOOP
      -- Check for existing unread notification for this group for this member
      SELECT id INTO existing_id
      FROM public.notifications
      WHERE user_id     = member_rec.member_id
        AND type        = 'message'
        AND reference_id = NEW.group_id
        AND is_read     = FALSE
      ORDER BY created_at DESC
      LIMIT 1;

      IF existing_id IS NOT NULL THEN
        -- Update the existing notification to the latest message
        UPDATE public.notifications SET
          title      = 'New Group Message in ' || grp_name,
          body       = sender_name || ': ' || LEFT(NEW.content, 120),
          created_at = NOW()
        WHERE id = existing_id;
      ELSE
        -- Insert a fresh notification
        INSERT INTO public.notifications
          (school_id, user_id, title, body, type, reference_id, is_read, created_at)
        VALUES
          (NEW.school_id,
           member_rec.member_id,
           'New Group Message in ' || grp_name,
           sender_name || ': ' || LEFT(NEW.content, 120),
           'message',
           NEW.group_id,
           FALSE,
           NOW());
      END IF;
    END LOOP;

  ELSE
    -- ── DIRECT MESSAGE ─────────────────────────────────────────
    IF NEW.receiver_id IS NOT NULL AND NEW.receiver_id != NEW.sender_id THEN

      -- Check for existing unread notification from this sender to this receiver
      SELECT id INTO existing_id
      FROM public.notifications
      WHERE user_id     = NEW.receiver_id
        AND type        = 'message'
        AND reference_id = NEW.sender_id
        AND is_read     = FALSE
      ORDER BY created_at DESC
      LIMIT 1;

      IF existing_id IS NOT NULL THEN
        -- Update existing notification with latest message content
        UPDATE public.notifications SET
          title      = 'New Message from ' || sender_name,
          body       = LEFT(NEW.content, 120),
          created_at = NOW()
        WHERE id = existing_id;
      ELSE
        -- Insert a new notification for the receiver
        INSERT INTO public.notifications
          (school_id, user_id, title, body, type, reference_id, is_read, created_at)
        VALUES
          (NEW.school_id,
           NEW.receiver_id,
           'New Message from ' || sender_name,
           LEFT(NEW.content, 120),
           'message',
           NEW.sender_id,
           FALSE,
           NOW());
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-attach the trigger (function is replaced in-place; trigger still exists)
DROP TRIGGER IF EXISTS trigger_message_notification ON public.messages;
CREATE TRIGGER trigger_message_notification
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_message_notification_func();
