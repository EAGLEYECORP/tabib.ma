-- Tabib.ma V11: national/platform operations
create type public.verification_status as enum ('pending','approved','rejected','suspended');

alter table public.profiles add column if not exists suspended_at timestamptz;
alter table public.profiles add column if not exists suspension_reason text;

create table if not exists public.professional_verifications (
  id uuid primary key default gen_random_uuid(),
  applicant_id uuid not null references public.profiles(id) on delete cascade,
  entity_type text not null check (entity_type in ('doctor','clinic','pharmacy')),
  entity_id uuid,
  status public.verification_status not null default 'pending',
  reviewer_id uuid references public.profiles(id),
  decision_note text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create table if not exists public.platform_cases (
  id uuid primary key default gen_random_uuid(),
  case_type text not null check (case_type in ('support','security','payment','verification','other')),
  subject text not null,
  description text,
  status text not null default 'open' check (status in ('open','in_progress','resolved','closed')),
  priority text not null default 'normal' check (priority in ('low','normal','high','critical')),
  reporter_id uuid references public.profiles(id),
  assignee_id uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.platform_actions (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.profiles(id),
  action text not null,
  target_type text not null,
  target_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.is_platform_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='platform_admin' and p.suspended_at is null); $$;

alter table public.professional_verifications enable row level security;
alter table public.platform_cases enable row level security;
alter table public.platform_actions enable row level security;

create policy "platform admins manage verifications" on public.professional_verifications for all using (public.is_platform_admin()) with check (public.is_platform_admin());
create policy "applicants read own verifications" on public.professional_verifications for select using (applicant_id=auth.uid());
create policy "platform admins manage cases" on public.platform_cases for all using (public.is_platform_admin()) with check (public.is_platform_admin());
create policy "platform admins read actions" on public.platform_actions for select using (public.is_platform_admin());
create policy "platform admins create actions" on public.platform_actions for insert with check (public.is_platform_admin() and actor_id=auth.uid());

create index if not exists professional_verifications_status_idx on public.professional_verifications(status, created_at desc);
create index if not exists platform_cases_status_idx on public.platform_cases(status, priority, created_at desc);
create index if not exists platform_actions_target_idx on public.platform_actions(target_type, target_id, created_at desc);
