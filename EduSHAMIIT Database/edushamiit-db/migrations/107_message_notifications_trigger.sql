-- ============================================================
-- Migration 107: Automatic Message Notifications trigger
-- Auto-generates notifications when new messages are inserted.
-- ============================================================

CREATE OR REPLACE FUNCTION public.trigger_message_notification_func() RETURNS TRIGGER AS $$
DECLARE
  sender_name TEXT;
  grp_name TEXT;
  member_record RECORD;
BEGIN
  -- 1. Resolve sender full name
  SELECT full_name INTO sender_name FROM public.profiles WHERE id = NEW.sender_id;
  IF sender_name IS NULL THEN
    sender_name := 'Someone';
  END IF;

  -- 2. Check if this is a group message or direct message
  IF NEW.group_id IS NOT NULL THEN
    -- Resolve group name
    SELECT name INTO grp_name FROM public.groups WHERE id = NEW.group_id;
    IF grp_name IS NULL THEN
      grp_name := 'Group';
    END IF;

    -- Loop through all group members except the sender
    FOR member_record IN 
      SELECT member_id FROM public.group_members WHERE group_id = NEW.group_id AND member_id != NEW.sender_id
    LOOP
      INSERT INTO public.notifications (
        school_id,
        user_id,
        title,
        body,
        type,
        reference_id,
        is_read,
        created_at
      ) VALUES (
        NEW.school_id,
        member_record.member_id,
        'New Group Message in ' || grp_name,
        sender_name || ': ' || NEW.content,
        'message',
        NEW.group_id,
        FALSE,
        NEW.created_at
      );
    END LOOP;
  ELSE
    -- Direct message: Send to receiver_id if it's not the sender themselves
    IF NEW.receiver_id IS NOT NULL AND NEW.receiver_id != NEW.sender_id THEN
      INSERT INTO public.notifications (
        school_id,
        user_id,
        title,
        body,
        type,
        reference_id,
        is_read,
        created_at
      ) VALUES (
        NEW.school_id,
        NEW.receiver_id,
        'New Message from ' || sender_name,
        NEW.content,
        'message',
        NEW.sender_id,
        FALSE,
        NEW.created_at
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_message_notification ON public.messages;
CREATE TRIGGER trigger_message_notification
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_message_notification_func();
