-- Tabib.ma V17.9 — Doctor/Clinic Operations hardening
-- Run after schema_v17_2_go.sql and existing clinic/appointment migrations.

create index if not exists idx_doctor_availability_active_day
  on public.doctor_availability(doctor_id, active, day_of_week, start_time);
create index if not exists idx_doctor_blocks_doctor_time
  on public.doctor_blocks(doctor_id, start_at, end_at);

-- A doctor may only manage their own schedule. Platform admins may manage operational data.
drop policy if exists doctor_availability_insert_self on public.doctor_availability;
create policy doctor_availability_insert_self on public.doctor_availability
  for insert with check (doctor_id = auth.uid() or public.is_platform_admin());

drop policy if exists doctor_availability_update_self on public.doctor_availability;
create policy doctor_availability_update_self on public.doctor_availability
  for update using (doctor_id = auth.uid() or public.is_platform_admin())
  with check (doctor_id = auth.uid() or public.is_platform_admin());

drop policy if exists doctor_availability_delete_self on public.doctor_availability;
create policy doctor_availability_delete_self on public.doctor_availability
  for delete using (doctor_id = auth.uid() or public.is_platform_admin());

-- Defensive booking wrapper: enforce future bookings and bounded consultation duration.
create or replace function public.book_appointment_v17_9(
  p_doctor_id uuid,
  p_start_at timestamptz,
  p_end_at timestamptz,
  p_reason text default null,
  p_clinic_id uuid default null,
  p_location_id uuid default null,
  p_room_id uuid default null
) returns public.appointments
language plpgsql security definer set search_path=public as $$
declare
  uid uuid := auth.uid();
  a public.appointments;
  duration interval := p_end_at - p_start_at;
begin
  if uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_start_at <= now() then raise exception 'BOOKING_MUST_BE_FUTURE'; end if;
  if p_end_at <= p_start_at then raise exception 'INVALID_TIME_RANGE'; end if;
  if duration > interval '4 hours' then raise exception 'BOOKING_TOO_LONG'; end if;
  if p_reason is not null and length(p_reason) > 1000 then raise exception 'REASON_TOO_LONG'; end if;
  if not exists(select 1 from public.doctor_profiles where id=p_doctor_id and verified=true) then raise exception 'DOCTOR_NOT_BOOKABLE'; end if;
  if p_clinic_id is not null and not exists(select 1 from public.doctor_clinics dc where dc.doctor_id=p_doctor_id and dc.clinic_id=p_clinic_id) then raise exception 'DOCTOR_NOT_ATTACHED_TO_CLINIC'; end if;
  if p_location_id is not null and p_clinic_id is null then raise exception 'LOCATION_REQUIRES_CLINIC'; end if;
  if p_room_id is not null and p_location_id is null then raise exception 'ROOM_REQUIRES_LOCATION'; end if;
  if not exists(select 1 from public.get_available_slots(p_doctor_id,p_start_at,p_end_at) s where s.start_at=p_start_at and s.end_at=p_end_at) then raise exception 'SLOT_NOT_AVAILABLE'; end if;
  insert into public.appointments(patient_id,doctor_id,start_at,end_at,status,reason,clinic_id,location_id,room_id)
    values(uid,p_doctor_id,p_start_at,p_end_at,'requested',p_reason,p_clinic_id,p_location_id,p_room_id)
    returning * into a;
  return a;
exception when exclusion_violation then raise exception 'SLOT_ALREADY_BOOKED';
end $$;

revoke all on function public.book_appointment_v17_9(uuid,timestamptz,timestamptz,text,uuid,uuid,uuid) from public;
grant execute on function public.book_appointment_v17_9(uuid,timestamptz,timestamptz,text,uuid,uuid,uuid) to authenticated;
