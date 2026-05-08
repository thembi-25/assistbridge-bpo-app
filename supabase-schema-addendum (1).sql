-- ============================================================
-- AssistBridge BPO — Schema Addendum
-- Run this AFTER the main supabase-schema.sql
-- ============================================================

-- 14. NOTIFICATIONS TABLE
CREATE TABLE public.notifications (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('task', 'message', 'payment', 'application', 'report', 'system')),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  href TEXT,
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX idx_notifications_read ON public.notifications(read);
CREATE INDEX idx_notifications_created ON public.notifications(created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_own" ON public.notifications
  FOR ALL USING (user_id = auth.uid() OR get_user_role() = 'admin');

-- 15. ACTIVITY LOGS TABLE
CREATE TABLE public.activity_logs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  entity_type TEXT,  -- 'task' | 'client' | 'staff' | 'invoice' etc.
  entity_id UUID,
  entity_name TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_activity_user ON public.activity_logs(user_id);
CREATE INDEX idx_activity_created ON public.activity_logs(created_at DESC);
CREATE INDEX idx_activity_entity ON public.activity_logs(entity_type, entity_id);

ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "activity_admin_only" ON public.activity_logs
  FOR SELECT USING (get_user_role() = 'admin');
CREATE POLICY "activity_insert_all" ON public.activity_logs
  FOR INSERT WITH CHECK (TRUE);

-- ============================================================
-- HELPER FUNCTION — Create notification
-- ============================================================
CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id UUID,
  p_type TEXT,
  p_title TEXT,
  p_body TEXT,
  p_href TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO public.notifications (user_id, type, title, body, href)
  VALUES (p_user_id, p_type, p_title, p_body, p_href)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- TRIGGER — Notify staff when task assigned
-- ============================================================
CREATE OR REPLACE FUNCTION public.notify_task_assigned()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_client_name TEXT;
BEGIN
  -- Only fire when staff_id is set/changed
  IF NEW.staff_id IS NOT NULL AND (OLD.staff_id IS NULL OR OLD.staff_id != NEW.staff_id) THEN
    -- Get user_id from staff record
    SELECT user_id INTO v_user_id FROM public.staff WHERE id = NEW.staff_id;
    SELECT company_name INTO v_client_name FROM public.clients WHERE id = NEW.client_id;

    IF v_user_id IS NOT NULL THEN
      PERFORM public.create_notification(
        v_user_id,
        'task',
        'New Task Assigned',
        format('You have been assigned: "%s" for %s', NEW.title, COALESCE(v_client_name, 'a client')),
        '/dashboard/staff/tasks'
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_task_assigned
  AFTER INSERT OR UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.notify_task_assigned();

-- ============================================================
-- TRIGGER — Notify client when task completed
-- ============================================================
CREATE OR REPLACE FUNCTION public.notify_task_completed()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    SELECT user_id INTO v_user_id FROM public.clients WHERE id = NEW.client_id;

    IF v_user_id IS NOT NULL THEN
      PERFORM public.create_notification(
        v_user_id,
        'task',
        'Task Completed ✅',
        format('"%s" has been completed by your team', NEW.title),
        '/dashboard/client/tasks'
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_task_completed
  AFTER UPDATE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.notify_task_completed();

-- ============================================================
-- TRIGGER — Notify admin when job application received
-- ============================================================
CREATE OR REPLACE FUNCTION public.notify_new_application()
RETURNS TRIGGER AS $$
DECLARE
  v_admin_ids UUID[];
BEGIN
  -- Get all admin user IDs
  SELECT ARRAY_AGG(id) INTO v_admin_ids FROM public.users WHERE role = 'admin';

  IF v_admin_ids IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, type, title, body, href)
    SELECT unnest(v_admin_ids), 'application',
      'New Job Application',
      format('%s applied for %s', NEW.name, NEW.role_applied),
      '/dashboard/admin/applications';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_new_application
  AFTER INSERT ON public.job_applications
  FOR EACH ROW EXECUTE FUNCTION public.notify_new_application();

-- ============================================================
-- TRIGGER — Notify admin on new service request
-- ============================================================
CREATE OR REPLACE FUNCTION public.notify_new_service_request()
RETURNS TRIGGER AS $$
DECLARE
  v_admin_ids UUID[];
BEGIN
  SELECT ARRAY_AGG(id) INTO v_admin_ids FROM public.users WHERE role = 'admin';

  IF v_admin_ids IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, type, title, body, href)
    SELECT unnest(v_admin_ids), 'system',
      'New Service Request',
      format('%s from %s is requesting services', NEW.contact_name, NEW.company_name),
      '/dashboard/admin/service-requests';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_new_service_request
  AFTER INSERT ON public.service_requests
  FOR EACH ROW EXECUTE FUNCTION public.notify_new_service_request();

-- ============================================================
-- TRIGGER — Notify on new message received
-- ============================================================
CREATE OR REPLACE FUNCTION public.notify_new_message()
RETURNS TRIGGER AS $$
DECLARE
  v_sender_name TEXT;
  v_role TEXT;
  v_href TEXT;
BEGIN
  SELECT name INTO v_sender_name FROM public.users WHERE id = NEW.sender_id;
  SELECT role INTO v_role FROM public.users WHERE id = NEW.receiver_id;

  v_href := CASE v_role
    WHEN 'admin' THEN '/dashboard/admin/messages'
    WHEN 'client' THEN '/dashboard/client/messages'
    ELSE '/dashboard/staff/messages'
  END;

  PERFORM public.create_notification(
    NEW.receiver_id,
    'message',
    'New Message',
    format('%s sent you a message', COALESCE(v_sender_name, 'Someone')),
    v_href
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_new_message
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_new_message();

-- ============================================================
-- STORAGE BUCKET setup (run in Supabase dashboard)
-- ============================================================
-- In Supabase Dashboard → Storage, create these buckets:
-- 1. "files"       — client uploaded files (private)
-- 2. "resumes"     — job application resumes (private)
-- 3. "training"    — training materials PDFs/videos (private)
-- 4. "avatars"     — user profile photos (public)

-- Storage policies (run after creating buckets):
-- INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);
-- INSERT INTO storage.buckets (id, name, public) VALUES ('files', 'files', false);
-- INSERT INTO storage.buckets (id, name, public) VALUES ('resumes', 'resumes', false);
-- INSERT INTO storage.buckets (id, name, public) VALUES ('training', 'training', false);
