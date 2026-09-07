-- TABIB.MA V7 — notification & communication layer (apply after schema.sql)
create extension if not exists pgcrypto;

do $$ begin create type public.notification_channel as enum ('in_app','email','sms','whatsapp'); exception when duplicate_object then null; end $$;
do $$ begin create type public.notification_status as enum ('queued','processing','sent','failed','cancelled'); exception when duplicate_object then null; end $$;

create table if not exists public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  in_app_enabled boolean not null default true,
  email_enabled boolean not null default true,
  sms_enabled boolean not null default true,
  whatsapp_enabled boolean not null default false,
  reminder_24h boolean not null default true,
  reminder_2h boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.notification_queue (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  channel public.notification_channel not null,
  template_key text not null,
  appointment_id uuid references public.appointments(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  scheduled_at timestamptz not null default now(),
  status public.notification_status not null default 'queued',
  attempts integer not null default 0 check(attempts >= 0 and attempts <= 10),
  provider_message_id text,
  last_error text,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  idempotency_key text not null unique
);
create index if not exists notification_queue_due_idx on public.notification_queue(status,scheduled_at);
create index if not exists notification_queue_recipient_idx on public.notification_queue(recipient_id,created_at desc);

create table if not exists public.notification_delivery_logs (
  id bigint generated always as identity primary key,
  notification_id uuid not null references public.notification_queue(id) on delete cascade,
  channel public.notification_channel not null,
  provider text,
  outcome text not null,
  provider_message_id text,
  error_code text,
  created_at timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;
alter table public.notification_queue enable row level security;
alter table public.notification_delivery_logs enable row level security;

create policy notification_preferences_self on public.notification_preferences for all using(user_id=auth.uid() or public.is_platform_admin()) with check(user_id=auth.uid() or public.is_platform_admin());
create policy notification_queue_self_read on public.notification_queue for select using(recipient_id=auth.uid() or public.is_platform_admin());
create policy notification_delivery_admin_read on public.notification_delivery_logs for select using(public.is_platform_admin());

create or replace function public.ensure_notification_preferences() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into notification_preferences(user_id) values(new.id) on conflict(user_id) do nothing; return new; end $$;
drop trigger if exists trg_profiles_notification_preferences on public.profiles;
create trigger trg_profiles_notification_preferences after insert on public.profiles for each row execute function public.ensure_notification_preferences();

create or replace function public.queue_notification(p_recipient uuid,p_channel public.notification_channel,p_template text,p_appointment uuid,p_payload jsonb,p_scheduled timestamptz,p_key text) returns uuid language plpgsql security definer set search_path=public as $$
declare nid uuid;
begin
  insert into notification_queue(recipient_id,channel,template_key,appointment_id,payload,scheduled_at,idempotency_key)
  values(p_recipient,p_channel,p_template,p_appointment,coalesce(p_payload,'{}'::jsonb),p_scheduled,p_key)
  on conflict(idempotency_key) do nothing returning id into nid;
  return nid;
end $$;

create or replace function public.queue_appointment_notifications() returns trigger language plpgsql security definer set search_path=public as $$
declare pref notification_preferences; email_ok boolean; sms_ok boolean; wa_ok boolean; inapp_ok boolean; p jsonb;
begin
  insert into notification_preferences(user_id) values(new.patient_id) on conflict(user_id) do nothing;
  select * into pref from notification_preferences where user_id=new.patient_id;
  inapp_ok := pref.in_app_enabled; email_ok := pref.email_enabled; sms_ok := pref.sms_enabled; wa_ok := pref.whatsapp_enabled;
  p := jsonb_build_object('appointment_id',new.id,'start_at',new.start_at,'end_at',new.end_at,'status',new.status);
  if inapp_ok then perform queue_notification(new.patient_id,'in_app','appointment.created',new.id,p,now(),'appt:'||new.id||':patient:in_app:created'); end if;
  if email_ok then perform queue_notification(new.patient_id,'email','appointment.created',new.id,p,now(),'appt:'||new.id||':patient:email:created'); end if;
  if sms_ok then perform queue_notification(new.patient_id,'sms','appointment.created',new.id,p,now(),'appt:'||new.id||':patient:sms:created'); end if;
  if wa_ok then perform queue_notification(new.patient_id,'whatsapp','appointment.created',new.id,p,now(),'appt:'||new.id||':patient:whatsapp:created'); end if;
  if pref.reminder_24h and new.start_at > now()+interval '24 hours' then
    if inapp_ok then perform queue_notification(new.patient_id,'in_app','appointment.reminder_24h',new.id,p,new.start_at-interval '24 hours','appt:'||new.id||':patient:inapp:r24'); end if;
    if email_ok then perform queue_notification(new.patient_id,'email','appointment.reminder_24h',new.id,p,new.start_at-interval '24 hours','appt:'||new.id||':patient:email:r24'); end if;
    if sms_ok then perform queue_notification(new.patient_id,'sms','appointment.reminder_24h',new.id,p,new.start_at-interval '24 hours','appt:'||new.id||':patient:sms:r24'); end if;
    if wa_ok then perform queue_notification(new.patient_id,'whatsapp','appointment.reminder_24h',new.id,p,new.start_at-interval '24 hours','appt:'||new.id||':patient:wa:r24'); end if;
  end if;
  if pref.reminder_2h and new.start_at > now()+interval '2 hours' then
    if inapp_ok then perform queue_notification(new.patient_id,'in_app','appointment.reminder_2h',new.id,p,new.start_at-interval '2 hours','appt:'||new.id||':patient:inapp:r2'); end if;
    if email_ok then perform queue_notification(new.patient_id,'email','appointment.reminder_2h',new.id,p,new.start_at-interval '2 hours','appt:'||new.id||':patient:email:r2'); end if;
    if sms_ok then perform queue_notification(new.patient_id,'sms','appointment.reminder_2h',new.id,p,new.start_at-interval '2 hours','appt:'||new.id||':patient:sms:r2'); end if;
    if wa_ok then perform queue_notification(new.patient_id,'whatsapp','appointment.reminder_2h',new.id,p,new.start_at-interval '2 hours','appt:'||new.id||':patient:wa:r2'); end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_appointment_notifications on public.appointments;
create trigger trg_appointment_notifications after insert on public.appointments for each row execute function public.queue_appointment_notifications();

create or replace function public.queue_appointment_status_notifications() returns trigger language plpgsql security definer set search_path=public as $$
declare pref notification_preferences; p jsonb;
begin
 if new.status = old.status then return new; end if;
 insert into notification_preferences(user_id) values(new.patient_id) on conflict(user_id) do nothing;
 select * into pref from notification_preferences where user_id=new.patient_id;
 p:=jsonb_build_object('appointment_id',new.id,'start_at',new.start_at,'end_at',new.end_at,'status',new.status);
 if pref.in_app_enabled then perform queue_notification(new.patient_id,'in_app','appointment.'||new.status::text,new.id,p,now(),'appt:'||new.id||':patient:inapp:status:'||new.status::text); end if;
 if pref.email_enabled then perform queue_notification(new.patient_id,'email','appointment.'||new.status::text,new.id,p,now(),'appt:'||new.id||':patient:email:status:'||new.status::text); end if;
 if pref.sms_enabled then perform queue_notification(new.patient_id,'sms','appointment.'||new.status::text,new.id,p,now(),'appt:'||new.id||':patient:sms:status:'||new.status::text); end if;
 if pref.whatsapp_enabled then perform queue_notification(new.patient_id,'whatsapp','appointment.'||new.status::text,new.id,p,now(),'appt:'||new.id||':patient:wa:status:'||new.status::text); end if;
 return new;
end $$;
drop trigger if exists trg_appointment_status_notifications on public.appointments;
create trigger trg_appointment_status_notifications after update of status on public.appointments for each row execute function public.queue_appointment_status_notifications();
