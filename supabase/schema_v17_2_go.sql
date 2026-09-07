-- Tabib.ma V17.2 production hardening
-- Payment amount must be server-authorized from an active pricing rule.
-- Run after schema_v8_payments.sql and V17.1 hardening.
create or replace function public.create_payment_intent(
  p_appointment_id uuid,
  p_amount_mad numeric,
  p_idempotency_key text
)
returns public.payments
language plpgsql
security definer
set search_path=public
as $$
declare
  uid uuid := auth.uid();
  p public.payments;
  ap public.appointments;
  expected_amount numeric;
begin
  if uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_amount_mad <= 0 then raise exception 'INVALID_AMOUNT'; end if;
  if p_idempotency_key is null or length(p_idempotency_key) < 16 or length(p_idempotency_key) > 128 then
    raise exception 'INVALID_IDEMPOTENCY_KEY';
  end if;

  select * into ap from appointments where id=p_appointment_id;
  if ap.id is null or ap.patient_id <> uid then raise exception 'APPOINTMENT_FORBIDDEN'; end if;
  if ap.status not in ('requested','confirmed') then raise exception 'APPOINTMENT_NOT_PAYABLE'; end if;

  select r.amount_mad into expected_amount
  from pricing_rules r
  where r.active=true
    and r.doctor_id=ap.doctor_id
    and r.effective_from<=now()
    and (r.effective_to is null or r.effective_to>now())
  order by r.effective_from desc
  limit 1;

  if expected_amount is null then raise exception 'NO_ACTIVE_PRICE'; end if;
  if p_amount_mad <> expected_amount then raise exception 'AMOUNT_NOT_AUTHORIZED'; end if;

  select * into p from payments where idempotency_key=p_idempotency_key;
  if p.id is not null then return p; end if;

  insert into payments(appointment_id,payer_id,payee_id,amount_mad,idempotency_key,status)
  values(ap.id,uid,ap.doctor_id,expected_amount,p_idempotency_key,'pending')
  returning * into p;
  return p;
end $$;

revoke all on function public.create_payment_intent(uuid,numeric,text) from public;
grant execute on function public.create_payment_intent(uuid,numeric,text) to authenticated;
