-- ═══════════════════════════════════════════════════════════
--  OBLIGA — Supabase Schema
--  Run this entire file once in:
--  Supabase Dashboard → SQL Editor → New query → Run
-- ═══════════════════════════════════════════════════════════

-- ── Enable UUID extension (already on by default in Supabase) ──
create extension if not exists "uuid-ossp";


-- ═══════════════════════════════════════════════════════════
--  PROFILES
--  One row per user. Created on first sign-in / onboarding.
-- ═══════════════════════════════════════════════════════════
create table if not exists profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  name            text,
  streak          integer default 0,
  last_active     text,               -- stored as toDateString() string
  lang            text default 'en',
  birthday        jsonb,              -- { month: int, day: int }
  notif_prefs     jsonb default '{
    "upcoming":  true,
    "raincheck": true,
    "freeday":   true,
    "friends":   true,
    "birthday":  true,
    "digest":    true
  }'::jsonb,
  cal_connected   jsonb default '{
    "google":  false,
    "outlook": false,
    "apple":   false
  }'::jsonb,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

-- Auto-update updated_at
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger profiles_updated_at
  before update on profiles
  for each row execute function update_updated_at();


-- ═══════════════════════════════════════════════════════════
--  OBLIGATIONS
--  Core inbox items — bills, appointments, social plans, etc.
-- ═══════════════════════════════════════════════════════════
create table if not exists obligations (
  id          text primary key,       -- uses client-generated IDs (Date.now() strings)
  user_id     uuid not null references auth.users(id) on delete cascade,
  title       text not null,
  cat         text not null default 'home', -- bills | health | home | family | friends | work
  due         date,
  pri         text default 'normal',  -- high | normal | low
  done        boolean default false,
  rc          boolean default false,  -- rain checked
  rc_note     text,
  rc_date     date,
  recur_rule  jsonb,                  -- { type, interval, unit, days, ends, endDate }
  recur_next  date,
  note        text,
  time        text,                   -- HH:MM format
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

create index if not exists obligations_user_id_idx on obligations(user_id);
create index if not exists obligations_due_idx on obligations(due);
create index if not exists obligations_done_idx on obligations(done);

create trigger obligations_updated_at
  before update on obligations
  for each row execute function update_updated_at();


-- ═══════════════════════════════════════════════════════════
--  CHORES
--  Recurring household tasks with reset logic.
-- ═══════════════════════════════════════════════════════════
create table if not exists chores (
  id          text primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  title       text not null,
  cat         text default 'home',
  freq        text,                   -- daily | weekly | biweekly | monthly | custom
  last_done   date,
  next_due    date,
  note        text,
  created_at  timestamptz default now()
);

create index if not exists chores_user_id_idx on chores(user_id);


-- ═══════════════════════════════════════════════════════════
--  LISTS
--  Grocery lists and custom lists with items.
--  Stored as JSONB (entire list object) for simplicity.
-- ═══════════════════════════════════════════════════════════
create table if not exists lists (
  id          text primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  data        jsonb not null,         -- full list object { id, name, emoji, items: [...] }
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

create index if not exists lists_user_id_idx on lists(user_id);

create trigger lists_updated_at
  before update on lists
  for each row execute function update_updated_at();


-- ═══════════════════════════════════════════════════════════
--  ROW LEVEL SECURITY (RLS)
--  Each user can only read and write their own data.
--  This is enforced at the database level — not just in code.
-- ═══════════════════════════════════════════════════════════

-- Profiles
alter table profiles enable row level security;

create policy "Users can view own profile"
  on profiles for select
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on profiles for insert
  with check (auth.uid() = id);

create policy "Users can update own profile"
  on profiles for update
  using (auth.uid() = id);


-- Obligations
alter table obligations enable row level security;

create policy "Users can view own obligations"
  on obligations for select
  using (auth.uid() = user_id);

create policy "Users can insert own obligations"
  on obligations for insert
  with check (auth.uid() = user_id);

create policy "Users can update own obligations"
  on obligations for update
  using (auth.uid() = user_id);

create policy "Users can delete own obligations"
  on obligations for delete
  using (auth.uid() = user_id);


-- Chores
alter table chores enable row level security;

create policy "Users can view own chores"
  on chores for select
  using (auth.uid() = user_id);

create policy "Users can insert own chores"
  on chores for insert
  with check (auth.uid() = user_id);

create policy "Users can update own chores"
  on chores for update
  using (auth.uid() = user_id);

create policy "Users can delete own chores"
  on chores for delete
  using (auth.uid() = user_id);


-- Lists
alter table lists enable row level security;

create policy "Users can view own lists"
  on lists for select
  using (auth.uid() = user_id);

create policy "Users can insert own lists"
  on lists for insert
  with check (auth.uid() = user_id);

create policy "Users can update own lists"
  on lists for update
  using (auth.uid() = user_id);

create policy "Users can delete own lists"
  on lists for delete
  using (auth.uid() = user_id);


-- ═══════════════════════════════════════════════════════════
--  DONE — your schema is ready.
-- ═══════════════════════════════════════════════════════════
