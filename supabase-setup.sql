-- ============================================================
-- NORK CAPITAL LENDING — PARTNER PORTAL DATABASE SETUP
-- Run this entire script in Supabase → SQL Editor → New Query → Run
-- ============================================================

-- 1. AFFILIATES TABLE (partner accounts)
create table if not exists affiliates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade unique,
  first_name text,
  last_name text,
  email text,
  phone text,
  business_name text,
  partner_type text default 'affiliate',   -- 'affiliate' or 'co-broker'
  role text default 'partner',             -- 'partner' or 'admin'
  status text default 'pending',           -- 'pending', 'active', 'suspended'
  created_at timestamptz default now()
);

-- 2. CLIENTS / DEALS TABLE (referrals submitted by partners)
create table if not exists clients (
  id uuid primary key default gen_random_uuid(),
  affiliate_id uuid references affiliates(id) on delete cascade,
  client_first_name text,
  client_last_name text,
  client_email text,
  client_phone text,
  company text,
  loan_type text,
  loan_amount numeric default 0,
  status text default 'Opportunity Submitted',
  commission numeric default 0,
  notes text,
  date_submitted date default current_date,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 3. ANNOUNCEMENTS TABLE (admin posts to partners)
create table if not exists announcements (
  id uuid primary key default gen_random_uuid(),
  title text,
  body text,
  posted_date date default current_date,
  created_at timestamptz default now()
);

-- ============================================================
-- ADMIN HELPER FUNCTION (security definer bypasses RLS)
-- ============================================================
create or replace function is_admin()
returns boolean as $$
  select exists(
    select 1 from affiliates
    where user_id = auth.uid() and role = 'admin'
  );
$$ language sql security definer stable;

-- ============================================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================================
alter table affiliates enable row level security;
alter table clients enable row level security;
alter table announcements enable row level security;

-- ---------- AFFILIATES POLICIES ----------
drop policy if exists "view own affiliate" on affiliates;
create policy "view own affiliate" on affiliates
  for select using (user_id = auth.uid() or is_admin());

drop policy if exists "insert own affiliate" on affiliates;
create policy "insert own affiliate" on affiliates
  for insert with check (user_id = auth.uid());

drop policy if exists "update own affiliate" on affiliates;
create policy "update own affiliate" on affiliates
  for update using (user_id = auth.uid() or is_admin());

drop policy if exists "admin delete affiliate" on affiliates;
create policy "admin delete affiliate" on affiliates
  for delete using (is_admin());

-- ---------- CLIENTS POLICIES ----------
drop policy if exists "view own clients" on clients;
create policy "view own clients" on clients
  for select using (
    affiliate_id in (select id from affiliates where user_id = auth.uid())
    or is_admin()
  );

drop policy if exists "insert own clients" on clients;
create policy "insert own clients" on clients
  for insert with check (
    affiliate_id in (select id from affiliates where user_id = auth.uid())
    or is_admin()
  );

drop policy if exists "admin update clients" on clients;
create policy "admin update clients" on clients
  for update using (is_admin());

drop policy if exists "admin delete clients" on clients;
create policy "admin delete clients" on clients
  for delete using (is_admin());

-- ---------- ANNOUNCEMENTS POLICIES ----------
drop policy if exists "read announcements" on announcements;
create policy "read announcements" on announcements
  for select using (auth.role() = 'authenticated');

drop policy if exists "admin write announcements" on announcements;
create policy "admin write announcements" on announcements
  for insert with check (is_admin());

drop policy if exists "admin update announcements" on announcements;
create policy "admin update announcements" on announcements
  for update using (is_admin());

drop policy if exists "admin delete announcements" on announcements;
create policy "admin delete announcements" on announcements
  for delete using (is_admin());

-- ============================================================
-- AFTER YOU SIGN UP YOUR OWN ACCOUNT IN THE PORTAL,
-- MAKE YOURSELF ADMIN by running this (replace the email):
--
--   update affiliates set role = 'admin', status = 'active'
--   where email = 'jp@thetrigon.com';
-- ============================================================

-- Optional: seed a welcome announcement
insert into announcements (title, body, posted_date)
values (
  'Welcome to the Nork Capital Partner Portal',
  'Your partner portal is now live. Submit new client opportunities, track your pipeline, and watch your commissions grow. Welcome to the team!',
  current_date
);
