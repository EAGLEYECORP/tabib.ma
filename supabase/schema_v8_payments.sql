-- TABIB.MA V8 — Payments & billing (provider-agnostic)
-- Apply after schema.sql and schema_v7_notifications.sql.
create extension if not exists pgcrypto;

do $$ begin create type public.payment_status as enum ('pending','requires_action','authorized','paid','failed','cancelled','refunded','partially_refunded'); exception when duplicate_object then null; end $$;
do $$ begin create type public.payment_kind as enum ('appointment','refund','commission','adjustment'); exception when duplicate_object then null; end $$;

create table if not exists public.pricing_rules (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid references public.doctor_profiles(id) on delete cascade,
  clinic_id uuid references public.clinics(id) on delete cascade,
  amount_mad numeric(12,2) not null check(amount_mad >= 0),
  currency text not null default 'MAD' check(currency='MAD'),
  active boolean not null default true,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  created_at timestamptz not null default now(),
  check(effective_to is null or effective_to > effective_from)
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  appointment_id uuid not null references public.appointments(id) on delete restrict,
  payer_id uuid not null references public.profiles(id) on delete restrict,
  payee_id uuid references public.profiles(id) on delete restrict,
  amount_mad numeric(12,2) not null check(amount_mad > 0),
  currency text not null default 'MAD' check(currency='MAD'),
  status public.payment_status not null default 'pending',
  provider text,
  provider_payment_id text,
  idempotency_key text not null unique,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  paid_at timestamptz,
  refunded_at timestamptz
);

create unique index if not exists payments_provider_payment_unique on public.payments(provider, provider_payment_id) where provider_payment_id is not null;
create index if not exists payments_appointment_idx on public.payments(appointment_id, created_at desc);
create index if not exists payments_payer_idx on public.payments(payer_id, created_at desc);

create table if not exists public.payment_events (
  id bigint generated always as identity primary key,
  payment_id uuid references public.payments(id) on delete set null,
  provider text not null,
  event_id text not null,
  event_type text not null,
  payload_hash text,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  processing_error text,
  unique(provider, event_id)
);

create table if not exists public.refunds (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete restrict,
  amount_mad numeric(12,2) not null check(amount_mad > 0),
  status public.payment_status not null default 'pending',
  provider_refund_id text,
  reason text,
  idempotency_key text not null unique,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.ledger_entries (
  id bigint generated always as identity primary key,
  payment_id uuid references public.payments(id) on delete set null,
  refund_id uuid references public.refunds(id) on delete set null,
  kind public.payment_kind not null,
  account_id uuid references public.profiles(id) on delete set null,
  amount_mad numeric(12,2) not null check(amount_mad <> 0),
  currency text not null default 'MAD' check(currency='MAD'),
  reference text,
  created_at timestamptz not null default now()
);

create table if not exists public.billing_invoices (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid references public.payments(id) on delete set null,
  appointment_id uuid references public.appointments(id) on delete set null,
  customer_id uuid not null references public.profiles(id) on delete restrict,
  invoice_number text not null unique,
  amount_mad numeric(12,2) not null check(amount_mad >= 0),
  tax_mad numeric(12,2) not null default 0 check(tax_mad >= 0),
  status text not null default 'issued' check(status in('draft','issued','paid','void')),
  issued_at timestamptz not null default now(),
  paid_at timestamptz
);

alter table public.pricing_rules enable row level security;
alter table public.payments enable row level security;
alter table public.payment_events enable row level security;
alter table public.refunds enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.billing_invoices enable row level security;

create policy pricing_public_read on public.pricing_rules for select using(active=true and (effective_to is null or effective_to>now()) and effective_from<=now());
create policy pricing_admin_all on public.pricing_rules for all using(public.is_platform_admin()) with check(public.is_platform_admin());
create policy payments_parties_read on public.payments for select using(payer_id=auth.uid() or payee_id=auth.uid() or exists(select 1 from appointments a where a.id=payments.appointment_id and (a.patient_id=auth.uid() or a.doctor_id=auth.uid())) or public.is_platform_admin());
create policy payment_events_admin_read on public.payment_events for select using(public.is_platform_admin());
create policy refunds_parties_read on public.refunds for select using(exists(select 1 from payments p where p.id=refunds.payment_id and (p.payer_id=auth.uid() or p.payee_id=auth.uid())) or public.is_platform_admin());
create policy ledger_admin_read on public.ledger_entries for select using(account_id=auth.uid() or public.is_platform_admin());
create policy invoices_customer_read on public.billing_invoices for select using(customer_id=auth.uid() or public.is_platform_admin());

create or replace function public.create_payment_intent(p_appointment_id uuid, p_amount_mad numeric, p_idempotency_key text)
returns public.payments
language plpgsql security definer set search_path=public
as $$
declare uid uuid := auth.uid(); p public.payments; ap public.appointments;
begin
  if uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_amount_mad <= 0 then raise exception 'INVALID_AMOUNT'; end if;
  select * into ap from appointments where id=p_appointment_id;
  if ap.id is null or ap.patient_id <> uid then raise exception 'APPOINTMENT_FORBIDDEN'; end if;
  if ap.status not in ('requested','confirmed') then raise exception 'APPOINTMENT_NOT_PAYABLE'; end if;
  if exists(select 1 from pricing_rules r where r.active=true and r.doctor_id=ap.doctor_id and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now())) then
    if not exists(select 1 from pricing_rules r where r.active=true and r.doctor_id=ap.doctor_id and r.effective_from<=now() and (r.effective_to is null or r.effective_to>now()) and r.amount_mad=p_amount_mad) then
      raise exception 'AMOUNT_NOT_AUTHORIZED';
    end if;
  end if;
  select * into p from payments where idempotency_key=p_idempotency_key;
  if p.id is not null then return p; end if;
  insert into payments(appointment_id,payer_id,payee_id,amount_mad,idempotency_key,status) values(ap.id,uid,ap.doctor_id,p_amount_mad,p_idempotency_key,'pending') returning * into p;
  return p;
end $$;

revoke all on function public.create_payment_intent(uuid,numeric,text) from public;
grant execute on function public.create_payment_intent(uuid,numeric,text) to authenticated;
