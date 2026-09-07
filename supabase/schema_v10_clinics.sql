create extension if not exists pgcrypto;

create type public.clinic_member_role as enum ('owner','clinic_admin','secretary','doctor');
create type public.member_status as enum ('invited','active','suspended');

create table if not exists public.clinic_members (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.clinic_member_role not null,
  status public.member_status not null default 'active',
  created_at timestamptz not null default now(),
  unique(clinic_id,user_id)
);

create table if not exists public.clinic_locations (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  name text not null,
  address_line1 text not null,
  address_line2 text,
  city text not null,
  postal_code text,
  country_code text not null default 'MA',
  timezone text not null default 'Africa/Casablanca',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.clinic_rooms (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.clinic_locations(id) on delete cascade,
  name text not null,
  room_type text not null default 'consultation',
  capacity integer not null default 1 check(capacity > 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.clinic_doctor_assignments (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics(id) on delete cascade,
  doctor_id uuid not null references public.profiles(id) on delete cascade,
  location_id uuid references public.clinic_locations(id) on delete set null,
  room_id uuid references public.clinic_rooms(id) on delete set null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(clinic_id,doctor_id,location_id)
);

alter table public.appointments add column if not exists clinic_id uuid references public.clinics(id) on delete set null;
alter table public.appointments add column if not exists location_id uuid references public.clinic_locations(id) on delete set null;
alter table public.appointments add column if not exists room_id uuid references public.clinic_rooms(id) on delete set null;

create index if not exists idx_clinic_members_clinic on public.clinic_members(clinic_id);
create index if not exists idx_clinic_members_user on public.clinic_members(user_id);
create index if not exists idx_clinic_locations_clinic on public.clinic_locations(clinic_id);
create index if not exists idx_clinic_rooms_location on public.clinic_rooms(location_id);
create index if not exists idx_clinic_doctors_clinic on public.clinic_doctor_assignments(clinic_id,doctor_id);
create index if not exists idx_appointments_clinic on public.appointments(clinic_id,location_id,room_id);

create or replace function public.is_clinic_member(p_clinic uuid, p_roles public.clinic_member_role[] default null)
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.clinic_members m where m.clinic_id=p_clinic and m.user_id=auth.uid() and m.status='active' and (p_roles is null or m.role=any(p_roles)));
$$;

alter table public.clinic_members enable row level security;
alter table public.clinic_locations enable row level security;
alter table public.clinic_rooms enable row level security;
alter table public.clinic_doctor_assignments enable row level security;

create policy "members read own clinic" on public.clinic_members for select using (public.is_clinic_member(clinic_id));
create policy "admins manage members" on public.clinic_members for all using (public.is_clinic_member(clinic_id, array['owner','clinic_admin']::public.clinic_member_role[])) with check (public.is_clinic_member(clinic_id, array['owner','clinic_admin']::public.clinic_member_role[]));
create policy "members read locations" on public.clinic_locations for select using (public.is_clinic_member(clinic_id));
create policy "admins manage locations" on public.clinic_locations for all using (public.is_clinic_member(clinic_id, array['owner','clinic_admin']::public.clinic_member_role[])) with check (public.is_clinic_member(clinic_id, array['owner','clinic_admin']::public.clinic_member_role[]));
create policy "members read rooms" on public.clinic_rooms for select using (exists(select 1 from public.clinic_locations l where l.id=location_id and public.is_clinic_member(l.clinic_id)));
create policy "admins manage rooms" on public.clinic_rooms for all using (exists(select 1 from public.clinic_locations l where l.id=location_id and public.is_clinic_member(l.clinic_id, array['owner','clinic_admin']::public.clinic_member_role[]))) with check (exists(select 1 from public.clinic_locations l where l.id=location_id and public.is_clinic_member(l.clinic_id, array['owner','clinic_admin']::public.clinic_member_role[])));
create policy "members read doctor assignments" on public.clinic_doctor_assignments for select using (public.is_clinic_member(clinic_id));
create policy "admins manage doctor assignments" on public.clinic_doctor_assignments for all using (public.is_clinic_member(clinic_id, array['owner','clinic_admin']::public.clinic_member_role[])) with check (public.is_clinic_member(clinic_id, array['owner','clinic_admin']::public.clinic_member_role[]));

create or replace view public.clinic_team_directory with (security_invoker=true) as
select m.clinic_id,m.user_id,m.role,m.status,p.full_name,dp.specialty
from public.clinic_members m join public.profiles p on p.id=m.user_id left join public.doctor_profiles dp on dp.id=m.user_id;

comment on table public.clinic_members is 'Multi-tenant clinic membership and least-privilege roles.';
comment on table public.clinic_locations is 'Physical clinic sites; private operational data.';
comment on table public.clinic_rooms is 'Rooms/resources inside clinic locations.';
