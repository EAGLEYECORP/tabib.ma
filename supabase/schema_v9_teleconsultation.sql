create table if not exists public.teleconsultation_rooms (
 id uuid primary key default gen_random_uuid(),
 appointment_id uuid not null unique references public.appointments(id) on delete cascade,
 status text not null default 'scheduled' check (status in ('scheduled','active','ended','cancelled')),
 provider text not null default 'external',
 provider_room_id text,
 starts_at timestamptz,
 ends_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table public.teleconsultation_rooms enable row level security;
create policy "teleconsultation participants read" on public.teleconsultation_rooms for select using (
 exists (select 1 from public.appointments a where a.id=appointment_id and (a.patient_id=auth.uid() or a.doctor_id=auth.uid()))
);
create policy "teleconsultation participants create" on public.teleconsultation_rooms for insert with check (
 exists (select 1 from public.appointments a where a.id=appointment_id and a.status='confirmed' and (a.patient_id=auth.uid() or a.doctor_id=auth.uid()))
);
