-- Tabib.ma V18.1 — Patient account & appointment center
-- Apply after schema_v18_0_booking.sql.

create index if not exists idx_appointments_patient_status_start
  on public.appointments(patient_id, status, start_at);

-- Prevent patients/doctors from mutating appointment fields through the generic UPDATE policies.
create or replace function public.guard_appointment_updates_v18_1()
returns trigger
language plpgsql security definer set search_path=public
as $$
declare uid uuid := auth.uid();
begin
  if public.is_platform_admin() then return new; end if;
  if uid is null then raise exception 'AUTH_REQUIRED'; end if;

  if new.patient_id <> old.patient_id or new.doctor_id <> old.doctor_id
     or new.start_at <> old.start_at or new.end_at <> old.end_at
     or coalesce(new.reason,'') <> coalesce(old.reason,'')
     or new.clinic_id is distinct from old.clinic_id
     or new.location_id is distinct from old.location_id
     or new.room_id is distinct from old.room_id then
    raise exception 'APPOINTMENT_FIELDS_IMMUTABLE';
  end if;

  if uid = old.patient_id then
    if not (old.status in ('requested','confirmed') and new.status = 'cancelled') then
      raise exception 'PATIENT_STATUS_CHANGE_NOT_ALLOWED';
    end if;
  elsif uid = old.doctor_id then
    if not ((old.status = 'requested' and new.status in ('confirmed','cancelled'))
        or (old.status = 'confirmed' and new.status = 'cancelled')
        or (old.status = 'confirmed' and new.status in ('completed','no_show'))) then
      raise exception 'DOCTOR_STATUS_CHANGE_NOT_ALLOWED';
    end if;
  else
    raise exception 'APPOINTMENT_UPDATE_NOT_ALLOWED';
  end if;
  return new;
end $$;

drop trigger if exists trg_guard_appointment_updates_v18_1 on public.appointments;
create trigger trg_guard_appointment_updates_v18_1
before update on public.appointments
for each row execute function public.guard_appointment_updates_v18_1();

create or replace function public.cancel_patient_appointment_v18_1(p_appointment_id uuid)
returns public.appointments
language plpgsql security definer set search_path=public
as $$
declare a public.appointments; uid uuid := auth.uid();
begin
  if uid is null then raise exception 'AUTH_REQUIRED'; end if;
  update public.appointments
    set status='cancelled'
    where id=p_appointment_id and patient_id=uid and status in ('requested','confirmed')
    returning * into a;
  if a.id is null then raise exception 'APPOINTMENT_NOT_CANCELLABLE'; end if;
  return a;
end $$;
revoke all on function public.cancel_patient_appointment_v18_1(uuid) from public;
grant execute on function public.cancel_patient_appointment_v18_1(uuid) to authenticated;

create or replace function public.reschedule_patient_appointment_v18_1(
  p_appointment_id uuid,
  p_start_at timestamptz,
  p_end_at timestamptz
) returns public.appointments
language plpgsql security definer set search_path=public
as $$
declare old_a public.appointments; a public.appointments; uid uuid := auth.uid();
begin
  if uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_start_at <= now() then raise exception 'BOOKING_MUST_BE_FUTURE'; end if;
  if p_end_at <= p_start_at then raise exception 'INVALID_TIME_RANGE'; end if;
  if p_end_at > p_start_at + interval '4 hours' then raise exception 'BOOKING_TOO_LONG'; end if;

  select * into old_a from public.appointments
    where id=p_appointment_id and patient_id=uid and status in ('requested','confirmed')
    for update;
  if old_a.id is null then raise exception 'APPOINTMENT_NOT_RESCHEDULABLE'; end if;

  if not exists (
    select 1 from public.get_public_booking_slots(old_a.doctor_id,p_start_at,p_end_at) s
    where s.start_at=p_start_at and s.end_at=p_end_at
  ) then raise exception 'SLOT_NOT_AVAILABLE'; end if;

  update public.appointments
    set start_at=p_start_at, end_at=p_end_at
    where id=old_a.id
    returning * into a;
  return a;
exception when exclusion_violation then raise exception 'SLOT_ALREADY_BOOKED';
end $$;
revoke all on function public.reschedule_patient_appointment_v18_1(uuid,timestamptz,timestamptz) from public;
grant execute on function public.reschedule_patient_appointment_v18_1(uuid,timestamptz,timestamptz) to authenticated;
