-- TABIB.MA V18.3 — Doctor / Clinic operational notification center
-- Apply after schema_v18_2_notifications.sql.

alter table public.notification_queue
  add column if not exists priority text not null default 'info'
    check (priority in ('info','action_required','urgent'));
alter table public.notification_queue
  add column if not exists audience text not null default 'patient'
    check (audience in ('patient','doctor','clinic_staff','platform_admin'));
alter table public.notification_queue
  add column if not exists action_url text;

create index if not exists notification_queue_operational_idx
  on public.notification_queue(recipient_id, created_at desc)
  where channel = 'in_app' and audience in ('doctor','clinic_staff','platform_admin');

create table if not exists public.notification_templates_v18_3 (
  template_key text primary key,
  title text not null,
  body text not null,
  priority text not null check (priority in ('info','action_required','urgent')),
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.notification_templates_v18_3 enable row level security;
drop policy if exists notification_templates_v18_3_admin_read on public.notification_templates_v18_3;
create policy notification_templates_v18_3_admin_read on public.notification_templates_v18_3
  for select using (public.is_platform_admin());

insert into public.notification_templates_v18_3(template_key,title,body,priority) values
('staff.appointment.created','Nouveau rendez-vous','Un nouveau rendez-vous nécessite votre attention.','action_required'),
('staff.appointment.confirmed','Rendez-vous confirmé','Un rendez-vous a été confirmé dans votre agenda.','info'),
('staff.appointment.cancelled','Rendez-vous annulé','Un rendez-vous de votre agenda a été annulé.','action_required'),
('staff.appointment.rescheduled','Rendez-vous reprogrammé','Un rendez-vous de votre agenda a changé de créneau.','action_required'),
('staff.appointment.reminder_24h','Rappel agenda','Un rendez-vous est prévu demain.','info'),
('staff.appointment.reminder_2h','Rappel agenda','Un rendez-vous est prévu dans environ 2 heures.','info')
on conflict (template_key) do update set title=excluded.title, body=excluded.body, priority=excluded.priority, updated_at=now();

-- Only trusted server-side trigger code can create operational notifications.
create or replace function public.queue_staff_notification(
  p_recipient uuid,
  p_template text,
  p_appointment uuid,
  p_payload jsonb,
  p_scheduled timestamptz,
  p_audience text,
  p_priority text,
  p_action_url text,
  p_key text
) returns uuid language plpgsql security definer set search_path=public as $$
declare nid uuid;
begin
  if p_audience not in ('doctor','clinic_staff','platform_admin') then raise exception 'INVALID_AUDIENCE'; end if;
  if p_priority not in ('info','action_required','urgent') then raise exception 'INVALID_PRIORITY'; end if;
  insert into notification_queue(recipient_id,channel,template_key,appointment_id,payload,scheduled_at,idempotency_key,priority,audience,action_url)
  values(p_recipient,'in_app',p_template,p_appointment,coalesce(p_payload,'{}'::jsonb),p_scheduled,p_key,p_priority,p_audience,p_action_url)
  on conflict(idempotency_key) do nothing returning id into nid;
  return nid;
end $$;
revoke all on function public.queue_staff_notification(uuid,text,uuid,jsonb,timestamptz,text,text,text,text) from public;

grant execute on function public.queue_staff_notification(uuid,text,uuid,jsonb,timestamptz,text,text,text,text) to service_role;

create or replace function public.queue_staff_appointment_event() returns trigger
language plpgsql security definer set search_path=public as $$
declare
  template text;
  priority text;
  event_key text;
  p jsonb;
  action_url text;
  r record;
  recipient record;
  changed_slot boolean := false;
  status_changed boolean := false;
  clinic_id_for_event uuid;
begin
  if tg_op = 'INSERT' then
    template := 'staff.appointment.created';
    priority := 'action_required';
    event_key := 'created';
  else
    status_changed := new.status is distinct from old.status;
    changed_slot := new.start_at is distinct from old.start_at
      or new.end_at is distinct from old.end_at
      or new.location_id is distinct from old.location_id
      or new.room_id is distinct from old.room_id;
    if status_changed then
      template := 'staff.appointment.' || new.status::text;
      if new.status::text not in ('confirmed','cancelled','requested') then
        return new;
      end if;
      priority := case when new.status::text='cancelled' then 'action_required' else 'info' end;
      event_key := 'status:' || new.status::text;
    elsif changed_slot then
      template := 'staff.appointment.rescheduled';
      priority := 'action_required';
      event_key := 'rescheduled:' || new.start_at::text || ':' || new.end_at::text;
    else
      return new;
    end if;
  end if;

  p := jsonb_build_object(
    'appointment_id', new.id,
    'start_at', new.start_at,
    'end_at', new.end_at,
    'status', new.status,
    'clinic_id', new.clinic_id,
    'location_id', new.location_id,
    'room_id', new.room_id
  );
  action_url := '/doctor/agenda';

  -- Doctor recipient. doctor_profiles.id is the user/profile id in this schema.
  perform queue_staff_notification(
    new.doctor_id,
    template,
    new.id,
    p,
    now(),
    'doctor',
    priority,
    action_url,
    'staff:' || new.id || ':doctor:' || event_key
  );

  -- Active clinic owners/admins/secretaries get the same operational event.
  clinic_id_for_event := new.clinic_id;
  if clinic_id_for_event is not null then
    for recipient in
      select m.user_id, m.role::text as role
      from clinic_members m
      where m.clinic_id = clinic_id_for_event
        and m.status = 'active'
        and m.role::text in ('owner','clinic_admin','secretary')
    loop
      perform queue_staff_notification(
        recipient.user_id,
        template,
        new.id,
        p,
        now(),
        'clinic_staff',
        priority,
        '/clinic',
        'staff:' || new.id || ':clinic:' || recipient.user_id || ':' || event_key
      );
    end loop;
  end if;

  return new;
end $$;

drop trigger if exists trg_staff_appointment_notifications on public.appointments;
create trigger trg_staff_appointment_notifications
after insert or update of status,start_at,end_at,location_id,room_id on public.appointments
for each row execute function public.queue_staff_appointment_event();

-- Operational reminders are queued separately from patient preferences. They remain in-app only.
create or replace function public.queue_staff_appointment_reminders() returns void
language plpgsql security definer set search_path=public as $$
declare a record; recipient record;
begin
  for a in
    select id, doctor_id, clinic_id, start_at, end_at, status, location_id, room_id
    from appointments
    where status = 'confirmed'
      and start_at > now()
      and start_at <= now() + interval '25 hours'
  loop
    if a.start_at > now() + interval '23 hours' and a.start_at <= now() + interval '25 hours' then
      perform queue_staff_notification(a.doctor_id,'staff.appointment.reminder_24h',a.id,
        jsonb_build_object('appointment_id',a.id,'start_at',a.start_at,'end_at',a.end_at,'status',a.status,'location_id',a.location_id,'room_id',a.room_id),
        a.start_at-interval '24 hours','doctor','info','/doctor/agenda','staff:'||a.id||':doctor:reminder24');
      if a.clinic_id is not null then
        for recipient in select user_id from clinic_members where clinic_id=a.clinic_id and status='active' and role::text in ('owner','clinic_admin','secretary') loop
          perform queue_staff_notification(recipient.user_id,'staff.appointment.reminder_24h',a.id,
            jsonb_build_object('appointment_id',a.id,'start_at',a.start_at,'end_at',a.end_at,'status',a.status,'location_id',a.location_id,'room_id',a.room_id),
            a.start_at-interval '24 hours','clinic_staff','info','/clinic','staff:'||a.id||':clinic:'||recipient.user_id||':reminder24');
        end loop;
      end if;
    end if;
  end loop;
end $$;
revoke all on function public.queue_staff_appointment_reminders() from public;
grant execute on function public.queue_staff_appointment_reminders() to service_role;
