-- TABIB.MA V17.8 — Doctor/Clinic onboarding, claim & verification center
-- Professional directory only. Evidence is referenced by opaque IDs; never store document contents here.

create table if not exists public.directory_claim_reviews (
 id uuid primary key default gen_random_uuid(),
 claim_id uuid not null references public.directory_claims(id) on delete cascade,
 decision text not null check (decision in ('approved','rejected','needs_more_evidence')),
 reviewer_id uuid not null references public.profiles(id) on delete restrict,
 reason_code text not null check (reason_code in ('IDENTITY_CONFIRMED','PROFESSIONAL_STATUS_CONFIRMED','DUPLICATE_PROFILE','INSUFFICIENT_EVIDENCE','MISMATCH','OTHER')),
 reviewer_notes text,
 created_at timestamptz not null default now()
);

create index if not exists directory_claim_reviews_claim on public.directory_claim_reviews(claim_id, created_at desc);

alter table public.directory_claims add column if not exists claimant_role text check (claimant_role in ('doctor','clinic_admin','practice_manager'));
alter table public.directory_claims add column if not exists submitted_at timestamptz;
alter table public.directory_claims add column if not exists evidence_hash text;

create unique index if not exists one_pending_claim_per_doctor_claimant
 on public.directory_claims(doctor_id, claimant_id) where status='pending';

create or replace function public.submit_directory_claim(
 p_doctor_id uuid,
 p_evidence_type text,
 p_evidence_reference text,
 p_evidence_hash text default null,
 p_claimant_role text default 'doctor'
) returns uuid
language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_evidence_type not in ('account','professional_document','institutional_confirmation','other') then raise exception 'INVALID_EVIDENCE_TYPE'; end if;
 if p_claimant_role not in ('doctor','clinic_admin','practice_manager') then raise exception 'INVALID_CLAIMANT_ROLE'; end if;
 if p_evidence_reference is null or length(trim(p_evidence_reference)) < 3 or length(p_evidence_reference) > 200 then raise exception 'INVALID_EVIDENCE_REFERENCE'; end if;
 if p_evidence_hash is not null and length(p_evidence_hash) <> 64 then raise exception 'INVALID_EVIDENCE_HASH'; end if;
 if not exists(select 1 from public.directory_doctors where id=p_doctor_id and verification_status not in ('removed','suspended')) then raise exception 'PROFILE_NOT_CLAIMABLE'; end if;
 insert into public.directory_claims(doctor_id,claimant_id,evidence_type,evidence_reference,evidence_hash,claimant_role,status,submitted_at)
 values(p_doctor_id,auth.uid(),p_evidence_type,trim(p_evidence_reference),p_evidence_hash,p_claimant_role,'pending',now())
 returning id into v_id;
 return v_id;
end $$;

create or replace function public.review_directory_claim(
 p_claim_id uuid,
 p_decision text,
 p_reason_code text,
 p_notes text default null
) returns boolean
language plpgsql security definer set search_path=public as $$
declare c public.directory_claims;
begin
 if not public.is_platform_admin() then raise exception 'FORBIDDEN'; end if;
 if p_decision not in ('approved','rejected','needs_more_evidence') then raise exception 'INVALID_DECISION'; end if;
 if p_reason_code not in ('IDENTITY_CONFIRMED','PROFESSIONAL_STATUS_CONFIRMED','DUPLICATE_PROFILE','INSUFFICIENT_EVIDENCE','MISMATCH','OTHER') then raise exception 'INVALID_REASON'; end if;
 select * into c from public.directory_claims where id=p_claim_id for update;
 if c.id is null or c.status <> 'pending' then raise exception 'CLAIM_NOT_PENDING'; end if;
 insert into public.directory_claim_reviews(claim_id,decision,reviewer_id,reason_code,reviewer_notes)
 values(p_claim_id,p_decision,auth.uid(),p_reason_code,left(coalesce(p_notes,''),2000));
 update public.directory_claims set status=case when p_decision='approved' then 'approved' when p_decision='rejected' then 'rejected' else 'pending' end,
 reviewer_id=auth.uid(), reviewer_notes=left(coalesce(p_notes,''),2000), reviewed_at=now() where id=p_claim_id;
 if p_decision='approved' then
   update public.directory_doctors set profile_claimed_by=c.claimant_id, claimed_at=now(), verification_status=case when verification_status='source_verified' then 'claimed' else verification_status end, updated_at=now() where id=c.doctor_id;
 end if;
 return true;
end $$;

create or replace function public.verify_claimed_directory_doctor(p_doctor_id uuid, p_notes text default null)
returns boolean language plpgsql security definer set search_path=public as $$
begin
 if not public.is_platform_admin() then raise exception 'FORBIDDEN'; end if;
 if not exists(select 1 from public.directory_doctors where id=p_doctor_id and verification_status='claimed' and profile_claimed_by is not null) then raise exception 'NOT_CLAIMED'; end if;
 update public.directory_doctors set verification_status='verified', source_verified=true, verified_at=now(), updated_at=now() where id=p_doctor_id;
 insert into public.audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'directory.doctor.verified','directory_doctor',p_doctor_id,jsonb_build_object('notes',left(coalesce(p_notes,''),500)));
 return true;
end $$;

alter table public.directory_claim_reviews enable row level security;
create policy directory_claim_reviews_admin on public.directory_claim_reviews for all using (public.is_platform_admin()) with check (public.is_platform_admin());

revoke all on function public.submit_directory_claim(uuid,text,text,text,text) from public;
revoke all on function public.review_directory_claim(uuid,text,text,text) from public;
revoke all on function public.verify_claimed_directory_doctor(uuid,text) from public;
grant execute on function public.submit_directory_claim(uuid,text,text,text,text) to authenticated;
grant execute on function public.review_directory_claim(uuid,text,text,text) to authenticated;
grant execute on function public.verify_claimed_directory_doctor(uuid,text) to authenticated;
