-- Tabib.ma V18.0 — Patient booking experience hardening
-- Run after schema_v17_9_operations.sql.

create index if not exists idx_appointments_patient_created on public.appointments(patient_id, created_at desc);
create index if not exists idx_appointments_doctor_start_status on public.appointments(doctor_id, start_at, status);

create or replace function public.get_public_booking_slots(
  p_doctor_id uuid,
  p_from timestamptz,
  p_to timestamptz
) returns table(start_at timestamptz,end_at timestamptz)
language plpgsql stable security definer set search_path=public as $$
begin
  if p_to <= p_from then raise exception 'INVALID_TIME_RANGE'; end if;
  if p_from < now() then p_from := now(); end if;
  if p_to > p_from + interval '31 days' then raise exception 'BOOKING_WINDOW_TOO_LARGE'; end if;
  return query select s.start_at,s.end_at from public.get_available_slots(p_doctor_id,p_from,p_to) s
    where s.start_at > now()
    order by s.start_at;
end $$;

revoke all on function public.get_public_booking_slots(uuid,timestamptz,timestamptz) from public;
grant execute on function public.get_public_booking_slots(uuid,timestamptz,timestamptz) to anon, authenticated;

create or replace function public.book_appointment_v18(
  p_doctor_id uuid,
  p_start_at timestamptz,
  p_end_at timestamptz,
  p_reason text default null,
  p_clinic_id uuid default null,
  p_location_id uuid default null,
  p_room_id uuid default null
) returns public.appointments
language plpgsql security definer set search_path=public as $$
declare a public.appointments; uid uuid := auth.uid();
begin
  if uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_start_at <= now() then raise exception 'BOOKING_MUST_BE_FUTURE'; end if;
  if p_end_at <= p_start_at then raise exception 'INVALID_TIME_RANGE'; end if;
  if p_end_at > p_start_at + interval '4 hours' then raise exception 'BOOKING_TOO_LONG'; end if;
  if p_reason is not null and length(p_reason) > 1000 then raise exception 'REASON_TOO_LONG'; end if;
  if not exists(select 1 from public.doctor_profiles where id=p_doctor_id and verified=true) then raise exception 'DOCTOR_NOT_BOOKABLE'; end if;
  if not exists(select 1 from public.get_public_booking_slots(p_doctor_id,p_start_at,p_end_at) s where s.start_at=p_start_at and s.end_at=p_end_at) then raise exception 'SLOT_NOT_AVAILABLE'; end if;
  insert into public.appointments(patient_id,doctor_id,start_at,end_at,status,reason,clinic_id,location_id,room_id)
  values(uid,p_doctor_id,p_start_at,p_end_at,'requested',nullif(trim(p_reason),''),p_clinic_id,p_location_id,p_room_id)
  returning * into a;
  return a;
exception when exclusion_violation then raise exception 'SLOT_ALREADY_BOOKED';
end $$;

revoke all on function public.book_appointment_v18(uuid,timestamptz,timestamptz,text,uuid,uuid,uuid) from public;
grant execute on function public.book_appointment_v18(uuid,timestamptz,timestamptz,text,uuid,uuid,uuid) to authenticated;
