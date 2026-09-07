-- TABIB.MA V18.2 — Notification & Communication Center
-- Apply after schema_v18_1_patient_account.sql and the V7 notification schema.

alter table public.notification_queue
  add column if not exists read_at timestamptz;

create index if not exists notification_queue_inbox_idx
  on public.notification_queue(recipient_id, channel, created_at desc)
  where channel = 'in_app';

create table if not exists public.notification_channel_consents (
  user_id uuid not null references public.profiles(id) on delete cascade,
  channel public.notification_channel not null,
  purpose text not null check (purpose in ('appointment_communications','marketing')),
  status text not null check (status in ('granted','revoked')),
  granted_at timestamptz,
  revoked_at timestamptz,
  source text not null default 'account_settings',
  updated_at timestamptz not null default now(),
  primary key (user_id, channel, purpose)
);

alter table public.notification_channel_consents enable row level security;
drop policy if exists notification_channel_consents_self on public.notification_channel_consents;
create policy notification_channel_consents_self on public.notification_channel_consents
  for all using (user_id = auth.uid() or public.is_platform_admin())
  with check (user_id = auth.uid() or public.is_platform_admin());

-- Keep templates declarative and free of patient/diagnostic content.
create table if not exists public.notification_templates (
  template_key text primary key,
  channel public.notification_channel not null,
  locale text not null default 'fr-MA',
  title text not null,
  body text not null,
  version integer not null default 1 check (version > 0),
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.notification_templates enable row level security;
drop policy if exists notification_templates_admin_read on public.notification_templates;
create policy notification_templates_admin_read on public.notification_templates
  for select using (public.is_platform_admin());

insert into public.notification_templates(template_key, channel, locale, title, body)
values
('appointment.created','in_app','fr-MA','Rendez-vous demandé','Votre rendez-vous a été enregistré.'),
('appointment.confirmed','in_app','fr-MA','Rendez-vous confirmé','Votre rendez-vous est confirmé.'),
('appointment.cancelled','in_app','fr-MA','Rendez-vous annulé','Votre rendez-vous a été annulé.'),
('appointment.rescheduled','in_app','fr-MA','Rendez-vous reprogrammé','Votre rendez-vous a été reprogrammé.'),
('appointment.reminder_24h','in_app','fr-MA','Rappel de rendez-vous','Votre rendez-vous est prévu demain.'),
('appointment.reminder_2h','in_app','fr-MA','Rappel de rendez-vous','Votre rendez-vous est prévu dans environ 2 heures.')
on conflict (template_key) do nothing;

-- Atomically mark an in-app notification read. No arbitrary recipient is accepted.
create or replace function public.mark_notification_read(p_notification uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare changed integer;
begin
  update notification_queue
     set read_at = coalesce(read_at, now()), updated_at = now()
   where id = p_notification
     and recipient_id = auth.uid()
     and channel = 'in_app'
     and status <> 'cancelled';
  get diagnostics changed = row_count;
  return changed = 1;
end $$;

revoke all on function public.mark_notification_read(uuid) from public;
grant execute on function public.mark_notification_read(uuid) to authenticated;
