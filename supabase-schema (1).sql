-- ============================================================
-- AssistBridge BPO — Supabase Database Schema
-- Run this in your Supabase SQL editor
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. USERS TABLE (extends Supabase auth.users)
-- ============================================================
CREATE TABLE public.users (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL DEFAULT 'client' CHECK (role IN ('admin', 'client', 'staff')),
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. CLIENTS TABLE
-- ============================================================
CREATE TABLE public.clients (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  company_name TEXT NOT NULL,
  contact_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  plan TEXT NOT NULL DEFAULT 'starter' CHECK (plan IN ('starter', 'growth', 'professional')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('active', 'inactive', 'pending')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. STAFF TABLE
-- ============================================================
CREATE TABLE public.staff (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL,
  skills TEXT[] DEFAULT '{}',
  availability TEXT NOT NULL DEFAULT 'available' CHECK (availability IN ('available', 'busy', 'off')),
  hourly_rate DECIMAL(10, 2),
  bio TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. TASKS TABLE
-- ============================================================
CREATE TABLE public.tasks (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE NOT NULL,
  staff_id UUID REFERENCES public.staff(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
  priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
  deadline TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 5. JOB APPLICATIONS TABLE
-- ============================================================
CREATE TABLE public.job_applications (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  role_applied TEXT NOT NULL,
  experience TEXT,
  cover_letter TEXT,
  resume_url TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'approved', 'rejected')),
  reviewer_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 6. MESSAGES TABLE
-- ============================================================
CREATE TABLE public.messages (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  receiver_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  message TEXT NOT NULL,
  read BOOLEAN DEFAULT FALSE,
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 7. REPORTS TABLE
-- ============================================================
CREATE TABLE public.reports (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE NOT NULL,
  staff_id UUID REFERENCES public.staff(id) ON DELETE SET NULL,
  hours_worked DECIMAL(6, 2) NOT NULL DEFAULT 0,
  tasks_completed INTEGER NOT NULL DEFAULT 0,
  period_start TIMESTAMPTZ,
  period_end TIMESTAMPTZ,
  notes TEXT,
  highlights TEXT,
  challenges TEXT,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'sent')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 8. TRAINING MATERIALS TABLE
-- ============================================================
CREATE TABLE public.training_materials (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  type TEXT NOT NULL CHECK (type IN ('video', 'pdf', 'document')),
  url TEXT,
  assigned_roles TEXT[] DEFAULT '{}',
  duration_minutes INTEGER,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 9. TRAINING PROGRESS TABLE
-- ============================================================
CREATE TABLE public.training_progress (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  staff_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  material_id UUID REFERENCES public.training_materials(id) ON DELETE CASCADE NOT NULL,
  completed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMPTZ,
  UNIQUE(staff_id, material_id)
);

-- ============================================================
-- 10. SUBSCRIPTIONS TABLE
-- ============================================================
CREATE TABLE public.subscriptions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE NOT NULL,
  plan TEXT NOT NULL CHECK (plan IN ('starter', 'growth', 'professional')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'cancelled')),
  amount DECIMAL(10, 2) NOT NULL,
  billing_cycle TEXT DEFAULT 'monthly',
  start_date TIMESTAMPTZ DEFAULT NOW(),
  end_date TIMESTAMPTZ,
  next_billing_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 11. INVOICES TABLE
-- ============================================================
CREATE TABLE public.invoices (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  invoice_number TEXT UNIQUE NOT NULL,
  client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE NOT NULL,
  subscription_id UUID REFERENCES public.subscriptions(id),
  amount DECIMAL(10, 2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'sent', 'paid', 'overdue', 'cancelled')),
  issue_date TIMESTAMPTZ DEFAULT NOW(),
  due_date TIMESTAMPTZ,
  paid_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 12. TIME LOGS TABLE
-- ============================================================
CREATE TABLE public.time_logs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  staff_id UUID REFERENCES public.staff(id) ON DELETE CASCADE NOT NULL,
  client_id UUID REFERENCES public.clients(id) ON DELETE CASCADE NOT NULL,
  task_id UUID REFERENCES public.tasks(id) ON DELETE SET NULL,
  task_type TEXT,
  notes TEXT,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  hours_worked DECIMAL(6, 2),
  date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 13. SERVICE REQUESTS TABLE (public form submissions)
-- ============================================================
CREATE TABLE public.service_requests (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  company_name TEXT NOT NULL,
  contact_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  services TEXT[] NOT NULL,
  plan TEXT,
  goals TEXT,
  start_date TEXT,
  status TEXT DEFAULT 'new' CHECK (status IN ('new', 'contacted', 'converted', 'closed')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES for performance
-- ============================================================
CREATE INDEX idx_tasks_client_id ON public.tasks(client_id);
CREATE INDEX idx_tasks_staff_id ON public.tasks(staff_id);
CREATE INDEX idx_tasks_status ON public.tasks(status);
CREATE INDEX idx_messages_sender ON public.messages(sender_id);
CREATE INDEX idx_messages_receiver ON public.messages(receiver_id);
CREATE INDEX idx_messages_timestamp ON public.messages(timestamp DESC);
CREATE INDEX idx_reports_client_id ON public.reports(client_id);
CREATE INDEX idx_time_logs_staff_id ON public.time_logs(staff_id);
CREATE INDEX idx_time_logs_date ON public.time_logs(date DESC);

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.time_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_requests ENABLE ROW LEVEL SECURITY;

-- Helper function to get current user role
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT AS $$
  SELECT role FROM public.users WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- ============================================================
-- RLS POLICIES
-- ============================================================

-- USERS: Can view own profile; admins see all
CREATE POLICY "users_own_or_admin" ON public.users
  FOR ALL USING (id = auth.uid() OR get_user_role() = 'admin');

-- CLIENTS: Admins see all; clients see own record
CREATE POLICY "clients_admin_or_own" ON public.clients
  FOR ALL USING (get_user_role() = 'admin' OR user_id = auth.uid());

-- STAFF: Admins see all; staff see own record
CREATE POLICY "staff_admin_or_own" ON public.staff
  FOR ALL USING (get_user_role() = 'admin' OR user_id = auth.uid());

-- TASKS: Admin sees all; client sees own tasks; staff sees assigned tasks
CREATE POLICY "tasks_role_based" ON public.tasks
  FOR SELECT USING (
    get_user_role() = 'admin' OR
    client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()) OR
    staff_id IN (SELECT id FROM public.staff WHERE user_id = auth.uid())
  );
CREATE POLICY "tasks_admin_insert" ON public.tasks
  FOR INSERT WITH CHECK (get_user_role() IN ('admin', 'client'));
CREATE POLICY "tasks_admin_update" ON public.tasks
  FOR UPDATE USING (
    get_user_role() = 'admin' OR
    staff_id IN (SELECT id FROM public.staff WHERE user_id = auth.uid())
  );

-- MESSAGES: Users can see messages they sent or received
CREATE POLICY "messages_participants" ON public.messages
  FOR ALL USING (sender_id = auth.uid() OR receiver_id = auth.uid());

-- REPORTS: Admin sees all; client sees own; staff sees own
CREATE POLICY "reports_role_based" ON public.reports
  FOR SELECT USING (
    get_user_role() = 'admin' OR
    client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid()) OR
    staff_id IN (SELECT id FROM public.staff WHERE user_id = auth.uid())
  );
CREATE POLICY "reports_insert" ON public.reports
  FOR INSERT WITH CHECK (get_user_role() IN ('admin', 'staff'));

-- TRAINING MATERIALS: Admins manage; staff can view
CREATE POLICY "training_view" ON public.training_materials
  FOR SELECT USING (get_user_role() IN ('admin', 'staff'));
CREATE POLICY "training_admin_write" ON public.training_materials
  FOR INSERT WITH CHECK (get_user_role() = 'admin');
CREATE POLICY "training_admin_update" ON public.training_materials
  FOR UPDATE USING (get_user_role() = 'admin');

-- TRAINING PROGRESS: Staff see own; admins see all
CREATE POLICY "progress_own_or_admin" ON public.training_progress
  FOR ALL USING (staff_id = auth.uid() OR get_user_role() = 'admin');

-- JOB APPLICATIONS: Admins see all; public insert (no auth needed for submitting)
CREATE POLICY "applications_admin_read" ON public.job_applications
  FOR SELECT USING (get_user_role() = 'admin');
CREATE POLICY "applications_public_insert" ON public.job_applications
  FOR INSERT WITH CHECK (TRUE);

-- SERVICE REQUESTS: Admins see all; public insert
CREATE POLICY "service_requests_admin" ON public.service_requests
  FOR SELECT USING (get_user_role() = 'admin');
CREATE POLICY "service_requests_insert" ON public.service_requests
  FOR INSERT WITH CHECK (TRUE);

-- SUBSCRIPTIONS: Admin sees all; client sees own
CREATE POLICY "subscriptions_role" ON public.subscriptions
  FOR SELECT USING (
    get_user_role() = 'admin' OR
    client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid())
  );

-- INVOICES: Admin sees all; client sees own
CREATE POLICY "invoices_role" ON public.invoices
  FOR SELECT USING (
    get_user_role() = 'admin' OR
    client_id IN (SELECT id FROM public.clients WHERE user_id = auth.uid())
  );

-- TIME LOGS: Admin sees all; staff sees own
CREATE POLICY "timelogs_role" ON public.time_logs
  FOR ALL USING (
    get_user_role() = 'admin' OR
    staff_id IN (SELECT id FROM public.staff WHERE user_id = auth.uid())
  );

-- ============================================================
-- TRIGGERS — updated_at auto-update
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
CREATE TRIGGER clients_updated_at BEFORE UPDATE ON public.clients FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
CREATE TRIGGER staff_updated_at BEFORE UPDATE ON public.staff FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
CREATE TRIGGER tasks_updated_at BEFORE UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION handle_updated_at();

-- ============================================================
-- TRIGGER — auto-create user profile on signup
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, name, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'client')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- SEED DATA — Demo users and sample data
-- ============================================================

-- Note: Create auth users via Supabase Dashboard or Auth API first,
-- then their profiles are auto-created by the trigger above.

-- Sample training materials
INSERT INTO public.training_materials (title, description, type, assigned_roles, duration_minutes)
VALUES
  ('New Staff Onboarding Guide', 'Everything you need to know to get started at AssistBridge BPO.', 'pdf', ARRAY['Virtual Assistant', 'Customer Support', 'Call Center', 'Sales Development', 'Social Media Manager', 'Data Entry'], 45),
  ('Customer Support Best Practices', 'AssistBridge standards for professional customer communication.', 'video', ARRAY['Customer Support', 'Call Center'], 32),
  ('Social Media Tools Walkthrough', 'Deep dive into Hootsuite, Buffer, Canva, and other tools.', 'video', ARRAY['Social Media Manager'], 48),
  ('Data Security & Compliance', 'GDPR, data handling policies, and security protocols.', 'pdf', ARRAY['Virtual Assistant', 'Customer Support', 'Call Center', 'Sales Development', 'Social Media Manager', 'Data Entry', 'Finance & Accounting', 'IT Support'], 20),
  ('Cold Calling Script & Techniques', 'Proven outbound calling frameworks and objection handling.', 'pdf', ARRAY['Sales Development', 'Cold Calling'], 35),
  ('Client Communication Excellence', 'Best practices for professional client communication.', 'video', ARRAY['Virtual Assistant', 'Customer Support'], 25);
