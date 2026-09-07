-- Tabib.ma V13 security hardening. Apply after V6-V12 migrations.

-- Prevent users from changing their own role. Only a trusted platform-admin path may do so.
create or replace function public.prevent_self_role_escalation()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is not null and NEW.role is distinct from OLD.role and not public.is_platform_admin() then
    raise exception 'ROLE_CHANGE_FORBIDDEN';
  end if;
  return NEW;
end;
$$;
drop trigger if exists trg_profiles_role_guard on public.profiles;
create trigger trg_profiles_role_guard before update on public.profiles
for each row execute function public.prevent_self_role_escalation();

-- Prevent arbitrary document recipients: only doctors and pharmacies can receive patient shares.
create or replace function public.validate_document_share_recipient()
returns trigger language plpgsql security definer set search_path = public
as $$
declare target_role public.user_role;
begin
  if NEW.shared_by <> auth.uid() then raise exception 'SHARE_ACTOR_FORBIDDEN'; end if;
  select role into target_role from public.profiles where id = NEW.shared_with;
  if target_role is null or target_role not in ('doctor','pharmacy') then raise exception 'INVALID_SHARE_RECIPIENT'; end if;
  if NEW.expires_at > now() + interval '30 days' then raise exception 'SHARE_EXPIRATION_TOO_LONG'; end if;
  return NEW;
end;
$$;
drop trigger if exists trg_document_share_guard on public.document_shares;
create trigger trg_document_share_guard before insert or update on public.document_shares
for each row execute function public.validate_document_share_recipient();

-- Never expose private operational tables through broad anonymous grants.
revoke all on table public.audit_logs from anon;
revoke all on table public.document_access_logs from anon;
revoke all on table public.patient_documents from anon;
revoke all on table public.document_shares from anon;
revoke all on table public.payments from anon;
revoke all on table public.payment_events from anon;
revoke all on table public.refunds from anon;
revoke all on table public.ledger_entries from anon;
revoke all on table public.billing_invoices from anon;

-- Audit helpers: only authenticated callers can write their own actor id; avoid secrets in metadata by convention.
create or replace function public.write_audit_event(p_action text, p_entity_type text, p_entity_id uuid, p_metadata jsonb default '{}'::jsonb)
returns bigint language plpgsql security definer set search_path = public
as $$
declare result bigint;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if length(coalesce(p_action,'')) > 120 or length(coalesce(p_entity_type,'')) > 80 then raise exception 'AUDIT_FIELD_TOO_LONG'; end if;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, metadata)
  values(auth.uid(), left(p_action,120), left(p_entity_type,80), p_entity_id, coalesce(p_metadata,'{}'::jsonb))
  returning id into result;
  return result;
end;
$$;
revoke all on function public.write_audit_event(text,text,uuid,jsonb) from public;
grant execute on function public.write_audit_event(text,text,uuid,jsonb) to authenticated;

comment on function public.write_audit_event(text,text,uuid,jsonb) is 'Audit only. Never pass secrets, tokens, document contents, diagnoses or other medical payloads.';

-- Protect appointment identity and timing from direct client mutation.
create or replace function public.prevent_appointment_tampering()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if NEW.patient_id is distinct from OLD.patient_id
     or NEW.doctor_id is distinct from OLD.doctor_id
     or NEW.start_at is distinct from OLD.start_at
     or NEW.end_at is distinct from OLD.end_at then
    raise exception 'APPOINTMENT_CORE_FIELDS_IMMUTABLE';
  end if;
  return NEW;
end;
$$;
drop trigger if exists trg_appointment_core_guard on public.appointments;
create trigger trg_appointment_core_guard before update on public.appointments
for each row execute function public.prevent_appointment_tampering();

-- Prevent non-admin direct verification/suspension changes through profile/doctor records.
create or replace function public.prevent_self_verification_tampering()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_platform_admin() then
    if TG_TABLE_NAME = 'doctor_profiles' and NEW.verified is distinct from OLD.verified then
      raise exception 'VERIFICATION_CHANGE_FORBIDDEN';
    end if;
    if TG_TABLE_NAME = 'clinics' and NEW.verified is distinct from OLD.verified then
      raise exception 'VERIFICATION_CHANGE_FORBIDDEN';
    end if;
    if TG_TABLE_NAME = 'pharmacies' and NEW.verified is distinct from OLD.verified then
      raise exception 'VERIFICATION_CHANGE_FORBIDDEN';
    end if;
  end if;
  return NEW;
end;
$$;
drop trigger if exists trg_doctor_verification_guard on public.doctor_profiles;
create trigger trg_doctor_verification_guard before update on public.doctor_profiles for each row execute function public.prevent_self_verification_tampering();
drop trigger if exists trg_clinic_verification_guard on public.clinics;
create trigger trg_clinic_verification_guard before update on public.clinics for each row execute function public.prevent_self_verification_tampering();
drop trigger if exists trg_pharmacy_verification_guard on public.pharmacies;
create trigger trg_pharmacy_verification_guard before update on public.pharmacies for each row execute function public.prevent_self_verification_tampering();

-- Correct the V10 directory view: doctor_profiles uses id as the profile/doctor identity.
drop view if exists public.clinic_team_directory;
create view public.clinic_team_directory with (security_invoker=true) as
select m.clinic_id,m.user_id,m.role,m.status,p.full_name,dp.specialty
from public.clinic_members m
join public.profiles p on p.id=m.user_id
left join public.doctor_profiles dp on dp.id=m.user_id;
