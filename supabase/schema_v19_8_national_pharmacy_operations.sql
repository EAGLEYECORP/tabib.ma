-- TABIB.MA V19.8 — National Pharmacy Operations
-- Incremental migration from V19.7. No V19.7 tables are removed.
-- Server/database remains authoritative for tenant, role, state and prescription checks.

-- 1) Pharmacy ownership + staff membership
alter table public.pharmacies
  add column if not exists owner_user_id uuid references public.profiles(id) on delete restrict;

update public.pharmacies
set owner_user_id = id
where owner_user_id is null;

create table if not exists public.pharmacy_staff_v19_8 (
  pharmacy_id uuid not null references public.pharmacies(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check(role in ('owner','pharmacy_admin','pharmacist','assistant')),
  status text not null default 'active' check(status in ('active','suspended')),
  invited_at timestamptz,
  activated_at timestamptz,
  suspended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(pharmacy_id,user_id)
);

insert into public.pharmacy_staff_v19_8(pharmacy_id,user_id,role,status,activated_at)
select p.id,p.id,'owner','active',now()
from public.pharmacies p
on conflict(pharmacy_id,user_id) do update
set role='owner',status='active',activated_at=coalesce(public.pharmacy_staff_v19_8.activated_at,excluded.activated_at);

create index if not exists pharmacy_staff_user_idx_v19_8
  on public.pharmacy_staff_v19_8(user_id,status);

create table if not exists public.pharmacy_staff_invitations_v19_8 (
  id uuid primary key default gen_random_uuid(),
  pharmacy_id uuid not null references public.pharmacies(id) on delete cascade,
  email text not null,
  role text not null check(role in ('pharmacy_admin','pharmacist','assistant')),
  token_hash text not null unique,
  invited_by uuid not null references auth.users(id) on delete restrict,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists pharmacy_staff_invite_lookup_v19_8
  on public.pharmacy_staff_invitations_v19_8(lower(email),pharmacy_id)
  where accepted_at is null and revoked_at is null;

-- 2) Inventory: threshold + operational history
alter table public.pharmacy_inventory_v19_7
  add column if not exists reorder_threshold numeric(12,2) not null default 0
    check(reorder_threshold >= 0 and reorder_threshold <= 999999);

create table if not exists public.pharmacy_inventory_events_v19_8 (
  id bigint generated always as identity primary key,
  pharmacy_id uuid not null references public.pharmacies(id) on delete cascade,
  medication_id uuid not null references public.medication_catalog(id) on delete restrict,
  actor_user_id uuid references auth.users(id) on delete set null,
  operation text not null,
  quantity_before numeric(12,2),
  quantity_after numeric(12,2),
  reorder_threshold_before numeric(12,2),
  reorder_threshold_after numeric(12,2),
  created_at timestamptz not null default now()
);

-- 3) Exact V19.8 fulfillment state machine
alter table public.pharmacy_orders_v19_6
  drop constraint if exists pharmacy_orders_v19_6_status_check;
alter table public.pharmacy_orders_v19_6
  add constraint pharmacy_orders_v19_6_status_check
  check(status in('requested','accepted','preparing','ready','dispensed','rejected','cancelled'));

drop index if exists public.pharmacy_active_order_uq;
create unique index if not exists pharmacy_active_order_uq
  on public.pharmacy_orders_v19_6(prescription_id,pharmacy_id)
  where status in('requested','accepted','preparing','ready');
create index if not exists pharmacy_orders_v19_8_status_idx
  on public.pharmacy_orders_v19_6(pharmacy_id,status,created_at desc);

create table if not exists public.pharmacy_order_idempotency_v19_8 (
  pharmacy_id uuid not null references public.pharmacies(id) on delete cascade,
  idempotency_key text not null,
  order_id uuid not null references public.pharmacy_orders_v19_6(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(pharmacy_id,idempotency_key),
  check(length(idempotency_key) between 16 and 128)
);


-- 4) V19.8 audit stream: deliberately excludes clinical payload
create table if not exists public.pharmacy_audit_events_v19_8 (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users(id) on delete set null,
  pharmacy_id uuid not null references public.pharmacies(id) on delete cascade,
  operation text not null,
  entity_type text not null,
  entity_id uuid,
  timestamp timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);
create index if not exists pharmacy_audit_pharmacy_time_v19_8
  on public.pharmacy_audit_events_v19_8(pharmacy_id,timestamp desc);
alter table public.pharmacy_audit_events_v19_8 enable row level security;

-- 5) Notification queue bridge. Payloads must contain operational text only.
create table if not exists public.pharmacy_operational_notifications_v19_8 (
  id bigint generated always as identity primary key,
  pharmacy_id uuid not null references public.pharmacies(id) on delete cascade,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check(event_type in(
    'NEW_REQUEST','ORDER_ACCEPTED','ORDER_PREPARING','ORDER_READY',
    'ORDER_REJECTED','ORDER_CANCELLED','STOCK_ALERT')),
  entity_id uuid,
  message text not null check(length(message) <= 500),
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists pharmacy_notifications_recipient_v19_8
  on public.pharmacy_operational_notifications_v19_8(recipient_user_id,created_at desc);
alter table public.pharmacy_operational_notifications_v19_8 enable row level security;

-- Tenant helper. SECURITY DEFINER prevents policy recursion and only returns active membership.
create or replace function public.is_active_pharmacy_staff_v19_8(p_pharmacy_id uuid,p_user_id uuid default auth.uid())
returns boolean
language sql stable security definer set search_path=public
as $$
  select exists(
    select 1 from public.pharmacy_staff_v19_8 s
    where s.pharmacy_id=p_pharmacy_id and s.user_id=p_user_id and s.status='active'
  );
$$;

create or replace function public.pharmacy_staff_role_v19_8(p_pharmacy_id uuid,p_user_id uuid default auth.uid())
returns text
language sql stable security definer set search_path=public
as $$
  select s.role from public.pharmacy_staff_v19_8 s
  where s.pharmacy_id=p_pharmacy_id and s.user_id=p_user_id and s.status='active'
  limit 1;
$$;

create or replace function public.can_manage_pharmacy_staff_v19_8(p_pharmacy_id uuid,p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public
as $$
  select coalesce(public.pharmacy_staff_role_v19_8(p_pharmacy_id,p_user_id) in ('owner','pharmacy_admin'),false);
$$;

create or replace function public.can_fulfill_pharmacy_order_v19_8(p_pharmacy_id uuid,p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public
as $$
  select coalesce(public.pharmacy_staff_role_v19_8(p_pharmacy_id,p_user_id) in ('owner','pharmacy_admin','pharmacist','assistant'),false);
$$;

create or replace function public.can_dispense_pharmacy_order_v19_8(p_pharmacy_id uuid,p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public
as $$
  select coalesce(public.pharmacy_staff_role_v19_8(p_pharmacy_id,p_user_id) in ('owner','pharmacy_admin','pharmacist'),false);
$$;

revoke all on function public.is_active_pharmacy_staff_v19_8(uuid,uuid) from public;
revoke all on function public.pharmacy_staff_role_v19_8(uuid,uuid) from public;
revoke all on function public.can_manage_pharmacy_staff_v19_8(uuid,uuid) from public;
revoke all on function public.can_fulfill_pharmacy_order_v19_8(uuid,uuid) from public;
revoke all on function public.can_dispense_pharmacy_order_v19_8(uuid,uuid) from public;
grant execute on function public.is_active_pharmacy_staff_v19_8(uuid,uuid) to authenticated;
grant execute on function public.pharmacy_staff_role_v19_8(uuid,uuid) to authenticated;
grant execute on function public.can_manage_pharmacy_staff_v19_8(uuid,uuid) to authenticated;
grant execute on function public.can_fulfill_pharmacy_order_v19_8(uuid,uuid) to authenticated;
grant execute on function public.can_dispense_pharmacy_order_v19_8(uuid,uuid) to authenticated;

-- 6) Strict RLS: tenant is membership-derived, never client-selected.
drop policy if exists pharmacy_inventory_own_read on public.pharmacy_inventory_v19_7;
drop policy if exists pharmacy_inventory_own_insert on public.pharmacy_inventory_v19_7;
drop policy if exists pharmacy_inventory_own_update on public.pharmacy_inventory_v19_7;
create policy pharmacy_inventory_staff_read_v19_8 on public.pharmacy_inventory_v19_7
  for select to authenticated using(public.is_active_pharmacy_staff_v19_8(pharmacy_id));
-- All inventory mutation goes through update_pharmacy_inventory_v19_8; no client-supplied pharmacy_id is trusted.
revoke insert,update,delete on public.pharmacy_inventory_v19_7 from authenticated;

drop policy if exists pharmacy_orders_own_read on public.pharmacy_orders_v19_6;
create policy pharmacy_orders_staff_read_v19_8 on public.pharmacy_orders_v19_6
  for select to authenticated using(public.is_active_pharmacy_staff_v19_8(pharmacy_id));

create policy pharmacy_audit_staff_read_v19_8 on public.pharmacy_audit_events_v19_8
  for select to authenticated using(public.is_active_pharmacy_staff_v19_8(pharmacy_id));

create policy pharmacy_notifications_recipient_read_v19_8
  on public.pharmacy_operational_notifications_v19_8 for select to authenticated
  using(recipient_user_id=auth.uid() and public.is_active_pharmacy_staff_v19_8(pharmacy_id));
create policy pharmacy_notifications_recipient_update_v19_8
  on public.pharmacy_operational_notifications_v19_8 for update to authenticated
  using(recipient_user_id=auth.uid() and public.is_active_pharmacy_staff_v19_8(pharmacy_id))
  with check(recipient_user_id=auth.uid());

alter table public.pharmacy_staff_v19_8 enable row level security;
alter table public.pharmacy_staff_invitations_v19_8 enable row level security;

create policy pharmacy_staff_self_read_v19_8 on public.pharmacy_staff_v19_8
  for select to authenticated using(user_id=auth.uid() and status='active');
create policy pharmacy_staff_manager_read_v19_8 on public.pharmacy_staff_v19_8
  for select to authenticated using(public.can_manage_pharmacy_staff_v19_8(pharmacy_id));
create policy pharmacy_invite_manager_read_v19_8 on public.pharmacy_staff_invitations_v19_8
  for select to authenticated using(public.can_manage_pharmacy_staff_v19_8(pharmacy_id));

-- 7) Server-authoritative staff invitation. Token is stored hashed, never plaintext.
create or replace function public.invite_pharmacy_staff_v19_8(
  p_pharmacy_id uuid,p_email text,p_role text,p_token_hash text,p_expires_at timestamptz
)
returns public.pharmacy_staff_invitations_v19_8
language plpgsql security definer set search_path=public
as $$
declare r public.pharmacy_staff_invitations_v19_8; uid uuid:=auth.uid();
begin
  if uid is null or not public.can_manage_pharmacy_staff_v19_8(p_pharmacy_id,uid) then raise exception 'FORBIDDEN'; end if;
  if p_role not in('pharmacy_admin','pharmacist','assistant') then raise exception 'INVALID_ROLE'; end if;
  if p_email is null or length(trim(p_email))<3 or length(trim(p_email))>254 then raise exception 'INVALID_EMAIL'; end if;
  if p_token_hash is null or length(p_token_hash)<32 then raise exception 'INVALID_TOKEN'; end if;
  if p_expires_at<=now() or p_expires_at>now()+interval '7 days' then raise exception 'INVALID_EXPIRY'; end if;
  insert into public.pharmacy_staff_invitations_v19_8(pharmacy_id,email,role,token_hash,invited_by,expires_at)
  values(p_pharmacy_id,lower(trim(p_email)),p_role,p_token_hash,uid,p_expires_at) returning * into r;
  insert into public.pharmacy_audit_events_v19_8(actor_user_id,pharmacy_id,operation,entity_type,entity_id,metadata)
  values(uid,p_pharmacy_id,'STAFF_INVITED','pharmacy_staff_invitation',r.id,jsonb_build_object('role',p_role,'email',lower(trim(p_email))));
  return r;
end $$;

revoke all on function public.invite_pharmacy_staff_v19_8(uuid,text,text,text,timestamptz) from public;
grant execute on function public.invite_pharmacy_staff_v19_8(uuid,text,text,text,timestamptz) to authenticated;

create or replace function public.accept_pharmacy_staff_invitation_v19_8(p_token_hash text)
returns public.pharmacy_staff_v19_8
language plpgsql security definer set search_path=public
as $$
declare i public.pharmacy_staff_invitations_v19_8; r public.pharmacy_staff_v19_8; uid uuid:=auth.uid();
begin
  if uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into i from public.pharmacy_staff_invitations_v19_8
  where token_hash=p_token_hash and accepted_at is null and revoked_at is null and expires_at>now()
  for update;
  if not found then raise exception 'INVITATION_INVALID_OR_EXPIRED'; end if;
  if not exists(select 1 from auth.users u where u.id=uid and lower(u.email)=lower(i.email)) then raise exception 'INVITATION_EMAIL_MISMATCH'; end if;
  insert into public.pharmacy_staff_v19_8(pharmacy_id,user_id,role,status,invited_at,activated_at,updated_at)
  values(i.pharmacy_id,uid,i.role,'active',i.created_at,now(),now())
  on conflict(pharmacy_id,user_id) do update set role=excluded.role,status='active',activated_at=now(),suspended_at=null,updated_at=now()
  returning * into r;
  update public.pharmacy_staff_invitations_v19_8 set accepted_at=now() where id=i.id;
  insert into public.pharmacy_audit_events_v19_8(actor_user_id,pharmacy_id,operation,entity_type,entity_id,metadata)
  values(uid,i.pharmacy_id,'STAFF_ACTIVATED','pharmacy_staff',uid,jsonb_build_object('role',i.role));
  return r;
end $$;

revoke all on function public.accept_pharmacy_staff_invitation_v19_8(text) from public;
grant execute on function public.accept_pharmacy_staff_invitation_v19_8(text) to authenticated;

create or replace function public.change_pharmacy_staff_role_v19_8(p_pharmacy_id uuid,p_user_id uuid,p_role text)
returns public.pharmacy_staff_v19_8
language plpgsql security definer set search_path=public
as $$
declare r public.pharmacy_staff_v19_8;
begin
  if not public.can_manage_pharmacy_staff_v19_8(p_pharmacy_id) then raise exception 'FORBIDDEN'; end if;
  if p_role not in('pharmacy_admin','pharmacist','assistant') then raise exception 'INVALID_ROLE'; end if;
  if p_user_id=auth.uid() and public.pharmacy_staff_role_v19_8(p_pharmacy_id)='owner' then raise exception 'OWNER_ROLE_IMMUTABLE'; end if;
  update public.pharmacy_staff_v19_8 set role=p_role,updated_at=now()
  where pharmacy_id=p_pharmacy_id and user_id=p_user_id and status='active'
  returning * into r;
  if not found then raise exception 'STAFF_NOT_FOUND'; end if;
  insert into public.pharmacy_audit_events_v19_8(actor_user_id,pharmacy_id,operation,entity_type,entity_id,metadata)
  values(auth.uid(),p_pharmacy_id,'STAFF_ROLE_CHANGED','pharmacy_staff',p_user_id,jsonb_build_object('role',p_role));
  return r;
end $$;

create or replace function public.set_pharmacy_staff_status_v19_8(p_pharmacy_id uuid,p_user_id uuid,p_status text)
returns public.pharmacy_staff_v19_8
language plpgsql security definer set search_path=public
as $$
declare r public.pharmacy_staff_v19_8;
begin
  if not public.can_manage_pharmacy_staff_v19_8(p_pharmacy_id) then raise exception 'FORBIDDEN'; end if;
  if p_user_id=auth.uid() and public.pharmacy_staff_role_v19_8(p_pharmacy_id)='owner' then raise exception 'OWNER_CANNOT_BE_SUSPENDED'; end if;
  if p_status not in('active','suspended') then raise exception 'INVALID_STATUS'; end if;
  update public.pharmacy_staff_v19_8 set status=p_status,suspended_at=case when p_status='suspended' then now() else null end,updated_at=now()
  where pharmacy_id=p_pharmacy_id and user_id=p_user_id
  returning * into r;
  if not found then raise exception 'STAFF_NOT_FOUND'; end if;
  insert into public.pharmacy_audit_events_v19_8(actor_user_id,pharmacy_id,operation,entity_type,entity_id,metadata)
  values(auth.uid(),p_pharmacy_id,case when p_status='suspended' then 'STAFF_SUSPENDED' else 'STAFF_ACTIVATED' end,'pharmacy_staff',p_user_id,'{}'::jsonb);
  return r;
end $$;

create or replace function public.remove_pharmacy_staff_access_v19_8(p_pharmacy_id uuid,p_user_id uuid)
returns boolean language plpgsql security definer set search_path=public
as $$
begin
  if not public.can_manage_pharmacy_staff_v19_8(p_pharmacy_id) then raise exception 'FORBIDDEN'; end if;
  if p_user_id=auth.uid() or public.pharmacy_staff_role_v19_8(p_pharmacy_id,p_user_id)='owner' then raise exception 'OWNER_ACCESS_PROTECTED'; end if;
  delete from public.pharmacy_staff_v19_8 where pharmacy_id=p_pharmacy_id and user_id=p_user_id;
  if not found then raise exception 'STAFF_NOT_FOUND'; end if;
  insert into public.pharmacy_audit_events_v19_8(actor_user_id,pharmacy_id,operation,entity_type,entity_id,metadata)
  values(auth.uid(),p_pharmacy_id,'STAFF_ACCESS_REMOVED','pharmacy_staff',p_user_id,'{}'::jsonb);
  return true;
end $$;

revoke all on function public.change_pharmacy_staff_role_v19_8(uuid,uuid,text) from public;
revoke all on function public.set_pharmacy_staff_status_v19_8(uuid,uuid,text) from public;
revoke all on function public.remove_pharmacy_staff_access_v19_8(uuid,uuid) from public;
grant execute on function public.change_pharmacy_staff_role_v19_8(uuid,uuid,text) to authenticated;
grant execute on function public.set_pharmacy_staff_status_v19_8(uuid,uuid,text) to authenticated;
grant execute on function public.remove_pharmacy_staff_access_v19_8(uuid,uuid) to authenticated;

-- 8) Inventory write: pharmacy_id is derived from membership, never trusted from caller.
create or replace function public.update_pharmacy_inventory_v19_8(
  p_pharmacy_id uuid,p_medication_id uuid,p_quantity numeric,p_reorder_threshold numeric default 0
)
returns public.pharmacy_inventory_v19_7
language plpgsql security definer set search_path=public
as $$
declare uid uuid:=auth.uid(); pharmacy uuid; r public.pharmacy_inventory_v19_7; old_qty numeric; old_thr numeric;
begin
  pharmacy:=p_pharmacy_id;
  if pharmacy is null or not public.is_active_pharmacy_staff_v19_8(pharmacy,uid) then raise exception 'PHARMACY_MEMBERSHIP_REQUIRED'; end if;
  if not public.can_fulfill_pharmacy_order_v19_8(pharmacy,uid) then raise exception 'FORBIDDEN'; end if;
  if p_medication_id is null or not exists(select 1 from public.medication_catalog where id=p_medication_id) then raise exception 'MEDICATION_NOT_FOUND'; end if;
  if p_quantity is null or p_quantity<0 or p_quantity>999999 then raise exception 'INVALID_QUANTITY'; end if;
  if p_reorder_threshold is null or p_reorder_threshold<0 or p_reorder_threshold>999999 then raise exception 'INVALID_REORDER_THRESHOLD'; end if;
  select quantity_available,reorder_threshold into old_qty,old_thr
  from public.pharmacy_inventory_v19_7 where pharmacy_id=pharmacy and medication_id=p_medication_id for update;
  insert into public.pharmacy_inventory_v19_7(pharmacy_id,medication_id,quantity_available,reorder_threshold,availability_status,updated_at)
  values(pharmacy,p_medication_id,p_quantity,p_reorder_threshold,
    case when p_quantity=0 then 'out_of_stock' when p_quantity<=p_reorder_threshold then 'low' else 'available' end,now())
  on conflict(pharmacy_id,medication_id) do update set
    quantity_available=excluded.quantity_available,reorder_threshold=excluded.reorder_threshold,
    availability_status=excluded.availability_status,updated_at=now()
  returning * into r;
  insert into public.pharmacy_inventory_events_v19_8(pharmacy_id,medication_id,actor_user_id,operation,quantity_before,quantity_after,reorder_threshold_before,reorder_threshold_after)
  values(pharmacy,p_medication_id,uid,'INVENTORY_UPDATED',old_qty,r.quantity_available,old_thr,r.reorder_threshold);
  insert into public.pharmacy_audit_events_v19_8(actor_user_id,pharmacy_id,operation,entity_type,entity_id,metadata)
  values(uid,pharmacy,'INVENTORY_UPDATED','pharmacy_inventory',r.id,jsonb_build_object('medication_id',p_medication_id));
  if r.quantity_available<=r.reorder_threshold then
    insert into public.pharmacy_operational_notifications_v19_8(pharmacy_id,recipient_user_id,event_type,entity_id,message)
    select pharmacy,s.user_id,'STOCK_ALERT',r.id,'Alerte stock : une référence a atteint son seuil de réapprovisionnement.'
    from public.pharmacy_staff_v19_8 s where s.pharmacy_id=pharmacy and s.status='active';
  end if;
  return r;
end $$;

revoke all on function public.update_pharmacy_inventory_v19_8(uuid,uuid,numeric,numeric) from public;
grant execute on function public.update_pharmacy_inventory_v19_8(uuid,uuid,numeric,numeric) to authenticated;

-- 9) Authoritative order transition + final prescription/inventory validation.
create or replace function public.update_pharmacy_order_v19_8(
  p_order_id uuid,p_new_status text,p_reason_code text default null,p_idempotency_key text default null
)
returns public.pharmacy_orders_v19_6
language plpgsql security definer set search_path=public
as $$
declare
  o public.pharmacy_orders_v19_6; o2 public.pharmacy_orders_v19_6; old text; uid uuid:=auth.uid(); r public.prescriptions_v19_6; item record; inv record; pharmacy_role text;
begin
  if uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into o from public.pharmacy_orders_v19_6
  where id=p_order_id and public.is_active_pharmacy_staff_v19_8(pharmacy_id,uid)
  for update;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  if p_idempotency_key is not null then
    select o2.* into o2
    from public.pharmacy_order_idempotency_v19_8 k
    join public.pharmacy_orders_v19_6 o2 on o2.id=k.order_id
    where k.pharmacy_id=o.pharmacy_id and k.idempotency_key=p_idempotency_key;
    if found then return o2; end if;
  end if;
  old=o.status;
  if p_new_status not in('accepted','preparing','ready','dispensed','rejected','cancelled') then raise exception 'INVALID_STATUS'; end if;
  if (old,p_new_status) not in (
    ('requested','accepted'),('accepted','preparing'),('preparing','ready'),
    ('ready','dispensed'),('requested','rejected'),('requested','cancelled'),
    ('accepted','cancelled'),('preparing','cancelled')
  ) then raise exception 'INVALID_TRANSITION'; end if;
  if p_new_status='rejected' and nullif(trim(coalesce(p_reason_code,'')),'') is null then raise exception 'REJECTION_REASON_REQUIRED'; end if;
  if p_new_status in('accepted','preparing','ready','rejected','cancelled') and not public.can_fulfill_pharmacy_order_v19_8(o.pharmacy_id,uid) then raise exception 'FORBIDDEN'; end if;
  pharmacy_role:=public.pharmacy_staff_role_v19_8(o.pharmacy_id,uid);
  if p_new_status='dispensed' and not public.can_dispense_pharmacy_order_v19_8(o.pharmacy_id,uid) then raise exception 'FORBIDDEN'; end if;

  if p_new_status='dispensed' then
    select * into r from public.prescriptions_v19_6
    where id=o.prescription_id and status='issued'
      and (expires_at is null or expires_at>now()) for update;
    if not found then raise exception 'PRESCRIPTION_NOT_ACTIVE'; end if;

    if not exists(select 1 from public.prescription_items_v19_6 pi where pi.prescription_id=r.id) then raise exception 'PRESCRIPTION_EMPTY'; end if;

    -- Medication correspondence + quantity validation and atomic stock decrement.
    for item in select medication_id,quantity from public.prescription_items_v19_6 where prescription_id=r.id loop
      select * into inv from public.pharmacy_inventory_v19_7
      where pharmacy_id=o.pharmacy_id and medication_id=item.medication_id for update;
      if not found then raise exception 'MEDICATION_NOT_AVAILABLE'; end if;
      if inv.quantity_available<item.quantity then raise exception 'INSUFFICIENT_STOCK'; end if;
      update public.pharmacy_inventory_v19_7
      set quantity_available=quantity_available-item.quantity,
          availability_status=case
            when quantity_available-item.quantity=0 then 'out_of_stock'
            when quantity_available-item.quantity<=reorder_threshold then 'low'
            else 'available' end,
          updated_at=now()
      where id=inv.id;
      insert into public.pharmacy_inventory_events_v19_8(pharmacy_id,medication_id,actor_user_id,operation,quantity_before,quantity_after,reorder_threshold_before,reorder_threshold_after)
      values(o.pharmacy_id,item.medication_id,uid,'INVENTORY_DECREMENTED',inv.quantity_available,inv.quantity_available-item.quantity,inv.reorder_threshold,inv.reorder_threshold);
      if inv.quantity_available-item.quantity<=inv.reorder_threshold then
        insert into public.pharmacy_operational_notifications_v19_8(pharmacy_id,recipient_user_id,event_type,entity_id,message)
        select o.pharmacy_id,s.user_id,'STOCK_ALERT',inv.id,'Alerte stock : une référence a atteint son seuil de réapprovisionnement.'
        from public.pharmacy_staff_v19_8 s where s.pharmacy_id=o.pharmacy_id and s.status='active';
      end if;
    end loop;
  end if;

  update public.pharmacy_orders_v19_6
  set status=p_new_status,
      rejection_reason_code=case when p_new_status='rejected' then left(p_reason_code,80) else rejection_reason_code end,
      accepted_at=case when p_new_status='accepted' then now() else accepted_at end,
      ready_at=case when p_new_status='ready' then now() else ready_at end,
      dispensed_at=case when p_new_status='dispensed' then now() else dispensed_at end,
      cancelled_at=case when p_new_status='cancelled' then now() else cancelled_at end,
      pickup_deadline=case when p_new_status='ready' then now()+interval '48 hours' else pickup_deadline end
  where id=o.id returning * into o;

  insert into public.pharmacy_order_events_v19_6(order_id,actor_id,from_status,to_status)
  values(o.id,uid,old,p_new_status);

  insert into public.pharmacy_audit_events_v19_8(actor_user_id,pharmacy_id,operation,entity_type,entity_id,metadata)
  values(uid,o.pharmacy_id,
    case p_new_status when 'accepted' then 'ORDER_ACCEPTED' when 'preparing' then 'ORDER_PREPARING'
      when 'ready' then 'ORDER_READY' when 'dispensed' then 'ORDER_DISPENSED'
      when 'rejected' then 'ORDER_REJECTED' when 'cancelled' then 'ORDER_CANCELLED' end,
    'pharmacy_order',o.id,jsonb_build_object('from_status',old,'to_status',p_new_status));

  -- Operational notifications contain no prescription/medication content.
  insert into public.pharmacy_operational_notifications_v19_8(pharmacy_id,recipient_user_id,event_type,entity_id,message)
  select o.pharmacy_id,s.user_id,
    case p_new_status when 'accepted' then 'ORDER_ACCEPTED' when 'preparing' then 'ORDER_PREPARING'
      when 'ready' then 'ORDER_READY' when 'dispensed' then 'ORDER_READY'
      when 'rejected' then 'ORDER_REJECTED' when 'cancelled' then 'ORDER_CANCELLED' end,
    o.id,
    case p_new_status when 'accepted' then 'Une nouvelle demande a été acceptée.'
      when 'preparing' then 'Une demande est en préparation.'
      when 'ready' then 'Une commande est prête.'
      when 'dispensed' then 'Une commande a été délivrée.'
      when 'rejected' then 'Une demande a été rejetée.'
      when 'cancelled' then 'Une demande a été annulée.' end
  from public.pharmacy_staff_v19_8 s
  where s.pharmacy_id=o.pharmacy_id and s.status='active' and s.user_id<>uid;

  if p_idempotency_key is not null then
    insert into public.pharmacy_order_idempotency_v19_8(pharmacy_id,idempotency_key,order_id)
    values(o.pharmacy_id,p_idempotency_key,o.id)
    on conflict(pharmacy_id,idempotency_key) do nothing;
  end if;
  return o;
end $$;

revoke all on function public.update_pharmacy_order_v19_8(uuid,text,text,text) from public;
grant execute on function public.update_pharmacy_order_v19_8(uuid,text,text,text) to authenticated;

-- Explicitly revoke direct mutation of protected workflow tables from authenticated clients.
revoke insert,update,delete on public.pharmacy_orders_v19_6 from authenticated;
revoke insert,update,delete on public.pharmacy_order_events_v19_6 from authenticated;


-- 10) Server-derived pharmacy context and staff directory.
create or replace function public.get_my_pharmacy_context_v19_8()
returns table(pharmacy_id uuid,pharmacy_name text,city text,address text,role text,status text)
language sql stable security definer set search_path=public
as $$
  select p.id,p.name,p.city,p.address,s.role,s.status
  from public.pharmacy_staff_v19_8 s
  join public.pharmacies p on p.id=s.pharmacy_id
  where s.user_id=auth.uid() and s.status='active'
  order by p.name;
$$;

create or replace function public.get_pharmacy_staff_v19_8(p_pharmacy_id uuid)
returns table(user_id uuid,full_name text,email text,role text,status text,invited_at timestamptz,activated_at timestamptz,suspended_at timestamptz)
language sql stable security definer set search_path=public
as $$
  select s.user_id,pr.full_name,u.email,s.role,s.status,s.invited_at,s.activated_at,s.suspended_at
  from public.pharmacy_staff_v19_8 s
  join public.profiles pr on pr.id=s.user_id
  join auth.users u on u.id=s.user_id
  where s.pharmacy_id=p_pharmacy_id
    and public.can_manage_pharmacy_staff_v19_8(p_pharmacy_id)
  order by case s.role when 'owner' then 0 when 'pharmacy_admin' then 1 when 'pharmacist' then 2 else 3 end,pr.full_name;
$$;

revoke all on function public.get_my_pharmacy_context_v19_8() from public;
revoke all on function public.get_pharmacy_staff_v19_8(uuid) from public;
grant execute on function public.get_my_pharmacy_context_v19_8() to authenticated;
grant execute on function public.get_pharmacy_staff_v19_8(uuid) to authenticated;

-- 11) V19.8 patient -> pharmacy request wrapper: validates pharmacy target server-side and creates operational notification.
create or replace function public.request_pharmacy_order_v19_8(p_prescription_id uuid,p_pharmacy_id uuid)
returns public.pharmacy_orders_v19_6
language plpgsql security definer set search_path=public
as $$
declare p public.prescriptions_v19_6; o public.pharmacy_orders_v19_6;
begin
  select * into p from public.prescriptions_v19_6
  where id=p_prescription_id and patient_id=auth.uid();
  if not found then raise exception 'PRESCRIPTION_NOT_FOUND'; end if;
  if p.status<>'issued' or (p.expires_at is not null and p.expires_at<=now()) then raise exception 'PRESCRIPTION_NOT_ACTIVE'; end if;
  if not exists(select 1 from public.pharmacies where id=p_pharmacy_id and verified=true and accepting_orders=true) then
    raise exception 'PHARMACY_NOT_ACCEPTING_ORDERS';
  end if;
  select * into o from public.pharmacy_orders_v19_6
  where prescription_id=p.id and pharmacy_id=p_pharmacy_id
    and status in('requested','accepted','preparing','ready')
  order by created_at desc limit 1;
  if found then return o; end if;
  insert into public.pharmacy_orders_v19_6(prescription_id,pharmacy_id,status)
  values(p.id,p_pharmacy_id,'requested')
  returning * into o;
  insert into public.pharmacy_order_events_v19_6(order_id,actor_id,to_status)
  values(o.id,auth.uid(),'requested');
  insert into public.pharmacy_audit_events_v19_8(actor_user_id,pharmacy_id,operation,entity_type,entity_id,metadata)
  values(auth.uid(),p_pharmacy_id,'ORDER_REQUESTED','pharmacy_order',o.id,'{}'::jsonb);
  insert into public.pharmacy_operational_notifications_v19_8(pharmacy_id,recipient_user_id,event_type,entity_id,message)
  select p_pharmacy_id,s.user_id,'NEW_REQUEST',o.id,'Nouvelle demande à traiter.'
  from public.pharmacy_staff_v19_8 s
  where s.pharmacy_id=p_pharmacy_id and s.status='active';
  return o;
end $$;

revoke all on function public.request_pharmacy_order_v19_8(uuid,uuid) from public;
grant execute on function public.request_pharmacy_order_v19_8(uuid,uuid) to authenticated;
