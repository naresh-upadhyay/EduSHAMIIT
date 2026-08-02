DROP TRIGGER IF EXISTS trigger_message_notification ON public.messages;
CREATE TRIGGER trigger_message_notification
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_message_notification_func();
