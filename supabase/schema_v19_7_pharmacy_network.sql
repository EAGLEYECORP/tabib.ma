-- TABIB.MA V19.7 — pharmacy network, inventory visibility and fulfillment operations.
-- Production requires real pharmacy verification, licensing review, contracts and security testing.

alter table public.pharmacies add column if not exists license_reference text;
alter table public.pharmacies add column if not exists phone text;
alter table public.pharmacies add column if not exists latitude numeric(9,6);
alter table public.pharmacies add column if not exists longitude numeric(9,6);
alter table public.pharmacies add column if not exists service_radius_km numeric(6,2) not null default 10 check(service_radius_km > 0 and service_radius_km <= 100);
alter table public.pharmacies add column if not exists accepting_orders boolean not null default false;
alter table public.pharmacies add column if not exists verified_at timestamptz;

create table if not exists public.pharmacy_inventory_v19_7 (
  id uuid primary key default gen_random_uuid(),
  pharmacy_id uuid not null references public.pharmacies(id) on delete cascade,
  medication_id uuid not null references public.medication_catalog(id) on delete restrict,
  quantity_available numeric(12,2) not null default 0 check(quantity_available >= 0 and quantity_available <= 999999),
  availability_status text not null default 'unknown' check(availability_status in('unknown','available','low','out_of_stock','on_order')),
  updated_at timestamptz not null default now(),
  unique(pharmacy_id,medication_id)
);
create index if not exists pharmacy_inventory_medication_idx on public.pharmacy_inventory_v19_7(medication_id,availability_status);
create index if not exists pharmacies_geo_idx on public.pharmacies(latitude,longitude) where verified=true and accepting_orders=true;

alter table public.pharmacy_orders_v19_6 add column if not exists patient_note_ciphertext text;
alter table public.pharmacy_orders_v19_6 add column if not exists pickup_deadline timestamptz;
alter table public.pharmacy_orders_v19_6 add column if not exists rejection_reason_code text;

alter table public.pharmacy_inventory_v19_7 enable row level security;
create policy pharmacy_inventory_own_read on public.pharmacy_inventory_v19_7 for select to authenticated using(pharmacy_id=auth.uid());
create policy pharmacy_inventory_own_insert on public.pharmacy_inventory_v19_7 for insert to authenticated with check(pharmacy_id=auth.uid());
create policy pharmacy_inventory_own_update on public.pharmacy_inventory_v19_7 for update to authenticated using(pharmacy_id=auth.uid()) with check(pharmacy_id=auth.uid());

-- Public directory exposes only verified pharmacies that explicitly accept orders.
create or replace function public.search_pharmacies_v19_7(p_city text default null,p_medication_id uuid default null,p_lat numeric default null,p_lng numeric default null,p_limit integer default 20)
returns table(id uuid,name text,city text,address text,phone text,latitude numeric,longitude numeric,verified boolean,accepting_orders boolean,distance_km numeric,availability_status text)
language sql stable security invoker set search_path=public as $$
  with candidates as (
    select p.*, case when p_lat is not null and p_lng is not null and p.latitude is not null and p.longitude is not null then
      6371 * 2 * asin(sqrt(power(sin(radians(p.latitude-p_lat)/2),2)+cos(radians(p_lat))*cos(radians(p.latitude))*power(sin(radians(p.longitude-p_lng)/2),2))) else null end as d,
      case when p_medication_id is not null then i.availability_status else null end as a
    from public.pharmacies p
    left join public.pharmacy_inventory_v19_7 i on i.pharmacy_id=p.id and i.medication_id=p_medication_id
    where p.verified=true and p.accepting_orders=true and (p_city is null or lower(p.city)=lower(p_city))
  ) select id,name,city,address,phone,latitude,longitude,verified,accepting_orders,round(d::numeric,2),a from candidates
  order by case when d is null then 1 else 0 end,d nulls last,name limit greatest(1,least(coalesce(p_limit,20),50));
$$;
revoke all on function public.search_pharmacies_v19_7(text,uuid,numeric,numeric,integer) from public;
grant execute on function public.search_pharmacies_v19_7(text,uuid,numeric,numeric,integer) to anon,authenticated;

-- Atomic fulfillment transition. The prescription remains the source of truth.
create or replace function public.update_pharmacy_order_v19_7(p_order_id uuid,p_new_status text,p_reason_code text default null)
returns public.pharmacy_orders_v19_6 language plpgsql security definer set search_path=public as $$
declare o public.pharmacy_orders_v19_6; old text;
begin
  select * into o from public.pharmacy_orders_v19_6 where id=p_order_id and pharmacy_id=auth.uid() for update;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  old=o.status;
  if p_new_status not in('accepted','ready','dispensed','rejected','cancelled') then raise exception 'INVALID_STATUS'; end if;
  if (old,p_new_status) not in (('requested','accepted'),('requested','rejected'),('requested','cancelled'),('accepted','ready'),('accepted','cancelled'),('ready','dispensed'),('ready','cancelled')) then raise exception 'INVALID_TRANSITION'; end if;
  if p_new_status='rejected' and nullif(trim(coalesce(p_reason_code,'')),'') is null then raise exception 'REJECTION_REASON_REQUIRED'; end if;
  if p_new_status='dispensed' then
    if not exists(select 1 from public.prescriptions_v19_6 p where p.id=o.prescription_id and p.status='issued' and (p.expires_at is null or p.expires_at>now())) then raise exception 'PRESCRIPTION_NOT_ACTIVE'; end if;
  end if;
  update public.pharmacy_orders_v19_6 set status=p_new_status,rejection_reason_code=case when p_new_status='rejected' then p_reason_code else rejection_reason_code end,accepted_at=case when p_new_status='accepted' then now() else accepted_at end,ready_at=case when p_new_status='ready' then now() else ready_at end,dispensed_at=case when p_new_status='dispensed' then now() else dispensed_at end,cancelled_at=case when p_new_status in('cancelled','rejected') then now() else cancelled_at end,pickup_deadline=case when p_new_status='ready' then now()+interval '48 hours' else pickup_deadline end where id=o.id returning * into o;
  insert into public.pharmacy_order_events_v19_6(order_id,actor_id,from_status,to_status) values(o.id,auth.uid(),old,p_new_status);
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'pharmacy_order_status_changed','pharmacy_order',o.id,jsonb_build_object('version','v19.7','from',old,'to',p_new_status));
  return o;
end $$;
revoke all on function public.update_pharmacy_order_v19_7(uuid,text,text) from public;
grant execute on function public.update_pharmacy_order_v19_7(uuid,text,text) to authenticated;
