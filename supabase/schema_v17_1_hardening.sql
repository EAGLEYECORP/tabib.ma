-- Tabib.ma V17.1 security/compliance hardening. Apply after V14 scale.

-- Atomic notification claiming prevents two workers from sending the same queued item.
create or replace function public.claim_due_notifications(p_limit integer default 50)
returns table(id uuid)
language plpgsql security definer set search_path=public
as $$
begin
  if p_limit is null or p_limit < 1 or p_limit > 100 then raise exception 'INVALID_LIMIT'; end if;
  return query
  with picked as (
    select n.id
    from public.notification_queue n
    where n.status='queued' and n.scheduled_at<=now()
    order by n.scheduled_at asc
    for update skip locked
    limit p_limit
  )
  update public.notification_queue n
  set status='processing', attempts=n.attempts+1, updated_at=now()
  from picked
  where n.id=picked.id
  returning n.id;
end;
$$;
revoke all on function public.claim_due_notifications(integer) from public;
grant execute on function public.claim_due_notifications(integer) to service_role;

-- Do not allow anonymous access to notification operational data.
revoke all on table public.notification_queue from anon;
revoke all on table public.notification_delivery_logs from anon;

-- Refund idempotency and auditability.
create index if not exists idx_refunds_payment_created on public.refunds(payment_id,created_at);
create index if not exists idx_payment_events_payment_received on public.payment_events(payment_id,received_at desc);

comment on function public.claim_due_notifications(integer) is 'Atomically claims due notifications for a trusted worker; service_role only.';
