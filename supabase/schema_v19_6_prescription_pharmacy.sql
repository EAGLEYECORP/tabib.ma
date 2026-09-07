-- TABIB.MA V19.6 — prescription lifecycle bound to the national medication catalog.
-- Clinical/legal review and real-world pharmacy integration remain mandatory before production.
create table if not exists public.prescriptions_v19_6 (
  id uuid primary key default gen_random_uuid(),
  appointment_id uuid not null references public.appointments(id) on delete restrict,
  patient_id uuid not null references public.profiles(id) on delete restrict,
  doctor_id uuid not null references public.doctor_profiles(id) on delete restrict,
  status text not null default 'draft' check(status in('draft','issued','cancelled','dispensed','expired')),
  issued_at timestamptz,
  expires_at timestamptz,
  signed_at timestamptz,
  signature_hash text,
  created_at timestamptz not null default now(),
  check((status='draft' and issued_at is null) or status<>'draft'),
  check(expires_at is null or issued_at is null or expires_at>issued_at)
);
create table if not exists public.prescription_items_v19_6 (
  id uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references public.prescriptions_v19_6(id) on delete cascade,
  medication_id uuid not null references public.medication_catalog(id) on delete restrict,
  quantity numeric(12,2) not null check(quantity>0 and quantity<=9999),
  dosage_instructions_ciphertext text,
  duration_days integer check(duration_days is null or duration_days between 1 and 365),
  substitution_allowed boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.pharmacy_orders_v19_6 (
  id uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references public.prescriptions_v19_6(id) on delete restrict,
  pharmacy_id uuid not null references public.pharmacies(id) on delete restrict,
  status text not null default 'requested' check(status in('requested','accepted','ready','dispensed','rejected','cancelled')),
  requested_at timestamptz not null default now(),
  accepted_at timestamptz,
  ready_at timestamptz,
  dispensed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now()
);
create table if not exists public.pharmacy_order_events_v19_6 (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.pharmacy_orders_v19_6(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  from_status text,
  to_status text not null,
  created_at timestamptz not null default now()
);
create unique index if not exists pharmacy_active_order_uq on public.pharmacy_orders_v19_6(prescription_id,pharmacy_id) where status in('requested','accepted','ready');
create index if not exists prescriptions_patient_idx on public.prescriptions_v19_6(patient_id,created_at desc);
create index if not exists prescriptions_doctor_idx on public.prescriptions_v19_6(doctor_id,created_at desc);
create index if not exists pharmacy_orders_pharmacy_idx on public.pharmacy_orders_v19_6(pharmacy_id,status,created_at desc);

alter table public.prescriptions_v19_6 enable row level security;
alter table public.prescription_items_v19_6 enable row level security;
alter table public.pharmacy_orders_v19_6 enable row level security;
alter table public.pharmacy_order_events_v19_6 enable row level security;

-- Patients: read their issued prescriptions and their own order status.
create policy prescriptions_patient_read on public.prescriptions_v19_6 for select to authenticated using(patient_id=auth.uid() and status in('issued','dispensed','expired'));
create policy prescription_items_patient_read on public.prescription_items_v19_6 for select to authenticated using(exists(select 1 from public.prescriptions_v19_6 p where p.id=prescription_id and p.patient_id=auth.uid() and p.status in('issued','dispensed','expired')));
create policy pharmacy_orders_patient_read on public.pharmacy_orders_v19_6 for select to authenticated using(exists(select 1 from public.prescriptions_v19_6 p where p.id=prescription_id and p.patient_id=auth.uid()));

-- Doctors: read/write only their own prescriptions; issuance is constrained by RPC below.
create policy prescriptions_doctor_read on public.prescriptions_v19_6 for select to authenticated using(doctor_id=auth.uid());
create policy prescriptions_doctor_insert on public.prescriptions_v19_6 for insert to authenticated with check(doctor_id=auth.uid());
create policy prescriptions_doctor_update on public.prescriptions_v19_6 for update to authenticated using(doctor_id=auth.uid()) with check(doctor_id=auth.uid());
create policy prescription_items_doctor_read on public.prescription_items_v19_6 for select to authenticated using(exists(select 1 from public.prescriptions_v19_6 p where p.id=prescription_id and p.doctor_id=auth.uid()));
create policy prescription_items_doctor_insert on public.prescription_items_v19_6 for insert to authenticated with check(exists(select 1 from public.prescriptions_v19_6 p where p.id=prescription_id and p.doctor_id=auth.uid() and p.status='draft'));

-- Pharmacy: only its own orders. Order creation/update is RPC-controlled to avoid status tampering.
create policy pharmacy_orders_own_read on public.pharmacy_orders_v19_6 for select to authenticated using(pharmacy_id=auth.uid());
create policy pharmacy_events_own_read on public.pharmacy_order_events_v19_6 for select to authenticated using(exists(select 1 from public.pharmacy_orders_v19_6 o where o.id=order_id and o.pharmacy_id=auth.uid()));

create or replace function public.issue_prescription_v19_6(p_prescription_id uuid,p_expires_at timestamptz)
returns public.prescriptions_v19_6 language plpgsql security definer set search_path=public as $$
declare r public.prescriptions_v19_6; item_count int;
begin
  select * into r from public.prescriptions_v19_6 where id=p_prescription_id and doctor_id=auth.uid() for update;
  if not found then raise exception 'PRESCRIPTION_NOT_FOUND'; end if;
  if r.status<>'draft' then raise exception 'PRESCRIPTION_NOT_DRAFT'; end if;
  if p_expires_at <= now() or p_expires_at > now()+interval '365 days' then raise exception 'INVALID_EXPIRY'; end if;
  select count(*) into item_count from public.prescription_items_v19_6 where prescription_id=r.id;
  if item_count=0 then raise exception 'PRESCRIPTION_EMPTY'; end if;
  update public.prescriptions_v19_6 set status='issued',issued_at=now(),signed_at=now(),expires_at=p_expires_at,signature_hash=encode(digest(r.id::text||':'||auth.uid()::text||':'||extract(epoch from now())::text,'sha256'),'hex') where id=r.id returning * into r;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'prescription_issued','prescription',r.id,jsonb_build_object('version','v19.6'));
  return r;
end $$;

create or replace function public.request_pharmacy_order_v19_6(p_prescription_id uuid,p_pharmacy_id uuid)
returns public.pharmacy_orders_v19_6 language plpgsql security definer set search_path=public as $$
declare p public.prescriptions_v19_6; o public.pharmacy_orders_v19_6;
begin
  select * into p from public.prescriptions_v19_6 where id=p_prescription_id and patient_id=auth.uid();
  if not found then raise exception 'PRESCRIPTION_NOT_FOUND'; end if;
  if p.status<>'issued' or (p.expires_at is not null and p.expires_at<=now()) then raise exception 'PRESCRIPTION_NOT_ACTIVE'; end if;
  if not exists(select 1 from public.profiles where id=p_pharmacy_id and role='pharmacy') then raise exception 'PHARMACY_NOT_FOUND'; end if;
  insert into public.pharmacy_orders_v19_6(prescription_id,pharmacy_id,status) values(p.id,p_pharmacy_id,'requested') returning * into o;
  insert into public.pharmacy_order_events_v19_6(order_id,actor_id,to_status) values(o.id,auth.uid(),'requested');
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'pharmacy_order_requested','pharmacy_order',o.id,jsonb_build_object('prescription_id',p.id));
  return o;
end $$;

create or replace function public.update_pharmacy_order_v19_6(p_order_id uuid,p_new_status text)
returns public.pharmacy_orders_v19_6 language plpgsql security definer set search_path=public as $$
declare o public.pharmacy_orders_v19_6; old text;
begin
  select * into o from public.pharmacy_orders_v19_6 where id=p_order_id and pharmacy_id=auth.uid() for update;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  old=o.status;
  if p_new_status not in('accepted','ready','dispensed','rejected','cancelled') then raise exception 'INVALID_STATUS'; end if;
  if (old,p_new_status) not in (('requested','accepted'),('requested','rejected'),('requested','cancelled'),('accepted','ready'),('accepted','cancelled'),('ready','dispensed'),('ready','cancelled')) then raise exception 'INVALID_TRANSITION'; end if;
  update public.pharmacy_orders_v19_6 set status=p_new_status,accepted_at=case when p_new_status='accepted' then now() else accepted_at end,ready_at=case when p_new_status='ready' then now() else ready_at end,dispensed_at=case when p_new_status='dispensed' then now() else dispensed_at end,cancelled_at=case when p_new_status in('cancelled','rejected') then now() else cancelled_at end where id=o.id returning * into o;
  insert into public.pharmacy_order_events_v19_6(order_id,actor_id,from_status,to_status) values(o.id,auth.uid(),old,p_new_status);
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'pharmacy_order_status_changed','pharmacy_order',o.id,jsonb_build_object('from',old,'to',p_new_status));
  return o;
end $$;

revoke all on function public.issue_prescription_v19_6(uuid,timestamptz) from public;
grant execute on function public.issue_prescription_v19_6(uuid,timestamptz) to authenticated;
revoke all on function public.request_pharmacy_order_v19_6(uuid,uuid) from public;
grant execute on function public.request_pharmacy_order_v19_6(uuid,uuid) to authenticated;
revoke all on function public.update_pharmacy_order_v19_6(uuid,text) from public;
grant execute on function public.update_pharmacy_order_v19_6(uuid,text) to authenticated;
