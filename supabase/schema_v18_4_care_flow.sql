-- Tabib.ma V18.4 — Day-of-appointment operational lifecycle
-- Run after schema_v18_3_staff_notifications.sql.
-- Adds non-clinical operational states without storing clinical notes.

do $$ begin alter type public.appointment_status add value if not exists 'checked_in'; exception when duplicate_object then null; end $$;
do $$ begin alter type public.appointment_status add value if not exists 'in_consultation'; exception when duplicate_object then null; end $$;

create index if not exists idx_appointments_doctor_day_status
  on public.appointments(doctor_id, start_at, status);

create or replace function public.transition_appointment_operational(
  p_appointment_id uuid,
  p_target public.appointment_status
) returns public.appointments
language plpgsql security definer set search_path=public as $$
declare uid uuid := auth.uid(); a public.appointments; old_status public.appointment_status; allowed boolean := false;
begin
  if uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into a from public.appointments where id=p_appointment_id for update;
  if not found then raise exception 'APPOINTMENT_NOT_FOUND'; end if;
  old_status := a.status;
  if a.doctor_id <> uid and not public.is_platform_admin() and not exists (
    select 1 from public.clinic_members cm where cm.user_id=uid and cm.clinic_id=a.clinic_id and cm.role in ('owner','clinic_admin','secretary')
  ) then raise exception 'NOT_ALLOWED'; end if;

  allowed := (a.status='confirmed' and p_target='checked_in')
          or (a.status='checked_in' and p_target='in_consultation')
          or (a.status='in_consultation' and p_target='completed')
          or (a.status in ('requested','confirmed','checked_in','in_consultation') and p_target='no_show');
  if not allowed then raise exception 'INVALID_TRANSITION'; end if;

  update public.appointments set status=p_target where id=a.id returning * into a;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata)
    values(uid,'appointment.operational_transition','appointment',a.id,jsonb_build_object('from_status',old_status,'to_status',p_target));
  return a;
end $$;

revoke all on function public.transition_appointment_operational(uuid,public.appointment_status) from public;
grant execute on function public.transition_appointment_operational(uuid,public.appointment_status) to authenticated;
