-- TABIB.MA V18.5 — Payment & Billing experience hardening
-- Run after V17.2 and V8 payment schema.

create unique index if not exists billing_invoice_payment_unique
  on public.billing_invoices(payment_id) where payment_id is not null;
create unique index if not exists refunds_provider_refund_unique
  on public.refunds(provider_refund_id) where provider_refund_id is not null;
create index if not exists billing_invoices_customer_idx
  on public.billing_invoices(customer_id, issued_at desc);

create or replace function public.get_authorized_appointment_price(p_appointment_id uuid)
returns numeric
language plpgsql security definer set search_path=public
as $$
declare uid uuid := auth.uid(); ap public.appointments; expected numeric;
begin
  if uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into ap from appointments where id=p_appointment_id;
  if ap.id is null or ap.patient_id <> uid then raise exception 'APPOINTMENT_FORBIDDEN'; end if;
  select r.amount_mad into expected from pricing_rules r
    where r.active=true and r.doctor_id=ap.doctor_id and r.effective_from<=now()
      and (r.effective_to is null or r.effective_to>now())
    order by r.effective_from desc limit 1;
  if expected is null then raise exception 'NO_ACTIVE_PRICE'; end if;
  return expected;
end $$;
revoke all on function public.get_authorized_appointment_price(uuid) from public;
grant execute on function public.get_authorized_appointment_price(uuid) to authenticated;

create or replace function public.issue_paid_invoice(p_payment_id uuid)
returns public.billing_invoices
language plpgsql security definer set search_path=public
as $$
declare uid uuid := auth.uid(); p public.payments; inv public.billing_invoices; n text;
begin
  if uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into p from payments where id=p_payment_id;
  if p.id is null then raise exception 'PAYMENT_NOT_FOUND'; end if;
  if p.payer_id<>uid and not public.is_platform_admin() then raise exception 'FORBIDDEN'; end if;
  if p.status <> 'paid' then raise exception 'PAYMENT_NOT_PAID'; end if;
  select * into inv from billing_invoices where payment_id=p.id limit 1;
  if inv.id is not null then return inv; end if;
  n := 'TAB-' || to_char(now(),'YYYYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10));
  insert into billing_invoices(payment_id,appointment_id,customer_id,invoice_number,amount_mad,tax_mad,status,issued_at,paid_at)
  values(p.id,p.appointment_id,p.payer_id,n,p.amount_mad,0,'paid',now(),coalesce(p.paid_at,now())) returning * into inv;
  return inv;
end $$;
revoke all on function public.issue_paid_invoice(uuid) from public;
grant execute on function public.issue_paid_invoice(uuid) to authenticated;

create or replace function public.refund_capacity(p_payment_id uuid)
returns numeric
language sql security definer set search_path=public
as $$
  select greatest(0, p.amount_mad - coalesce((select sum(r.amount_mad) from refunds r where r.payment_id=p.id and r.status in ('refunded','paid')),0))
  from payments p where p.id=p_payment_id;
$$;
revoke all on function public.refund_capacity(uuid) from public;
grant execute on function public.refund_capacity(uuid) to authenticated;
