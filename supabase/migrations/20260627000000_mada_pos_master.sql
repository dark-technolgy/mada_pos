-- ============================================================================
-- MADA SMART POS — MASTER SCHEMA (VERSION 1.0)
-- Purpose: Professional structure for Mada POS cloud backend.
-- ============================================================================

-- 1. EXTENSIONS
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- 2. CORE: PROFILES (User accounts for POS)
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  email text unique,
  full_name text,
  language text default 'ar',
  is_approved boolean default false,
  role text default 'cashier' check (role in ('admin', 'manager', 'cashier', 'viewer')),

  -- Tracking Data
  last_login timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

-- 3. AUDIT & TRACKING
create table if not exists public.audit_logs (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete set null,
  action text not null,
  metadata jsonb,
  created_at timestamp with time zone default now()
);

-- 4. APP MANAGEMENT: REMOTE CONFIG (Silent Updates & Maintenance)
create table if not exists public.remote_config (
  id int primary key default 1 check (id = 1),
  maintenance_mode boolean default false,
  maintenance_message text,
  min_version text default '1.0.0',
  latest_version text default '1.0.0',
  download_url text,
  release_notes text,
  updated_at timestamptz default now()
);

-- Insert default config
insert into public.remote_config (id, maintenance_mode, latest_version)
values (1, false, '1.0.0')
on conflict (id) do nothing;

-- 5. ADMIN MANAGEMENT
CREATE TABLE IF NOT EXISTS public.admin_users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  display_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 6. SECURITY: RLS
alter table public.profiles enable row level security;
alter table public.audit_logs enable row level security;
alter table public.remote_config enable row level security;
alter table public.admin_users enable row level security;

-- POLICIES
create policy "Users can view own profile" on public.profiles for select using (auth.uid() = id);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);
create policy "Public can read remote config" on public.remote_config for select using (true);
create policy "Admins can read own record" on public.admin_users for select using (auth.uid() = user_id);

-- 7. STORAGE BUCKETS
-- Create backups bucket (private)
insert into storage.buckets (id, name, public)
values ('backups', 'backups', false)
on conflict (id) do nothing;

-- Storage policies for backups
create policy "Users can manage own backups"
on storage.objects for all
using (bucket_id = 'backups' and (storage.foldername(name))[1] = auth.uid()::text);

-- 8. TRIGGERS & FUNCTIONS
-- Handle new user signup: create profile automatically
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, is_approved)
  VALUES (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    false -- Needs manual approval
  );
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 9. REALTIME
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
