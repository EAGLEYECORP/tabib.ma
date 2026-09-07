-- TABIB.MA V17.3 — National professional directory / ingestion / verification
-- Scope: public professional data only. No patient data. Import only from authorized/licensed sources.
create extension if not exists pg_trgm;
create extension if not exists unaccent;

do $$ begin create type public.directory_verification_status as enum ('unverified','source_verified','claimed','verified','suspended','removed'); exception when duplicate_object then null; end $$;

do $$ begin create type public.directory_import_status as enum ('dry_run','running','completed','failed','rolled_back'); exception when duplicate_object then null; end $$;

create table if not exists public.directory_sources (
 id uuid primary key default gen_random_uuid(),
 code text unique not null,
 name text not null,
 publisher text not null,
 source_url text,
 license_name text,
 terms_url text,
 robots_required boolean not null default true,
 permitted_for_import boolean not null default false,
 notes text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists public.directory_doctors (
 id uuid primary key default gen_random_uuid(),
 full_name text not null,
 normalized_name text not null,
 specialty text,
 normalized_specialty text,
 city text,
 region text,
 country_code char(2) not null default 'MA',
 professional_address text,
 public_phone text,
 public_email text,
 website_url text,
 source_verified boolean not null default false,
 verification_status public.directory_verification_status not null default 'unverified',
 profile_claimed_by uuid references public.profiles(id) on delete set null,
 claimed_at timestamptz,
 verified_at timestamptz,
 suspended_at timestamptz,
 removed_at timestamptz,
 source_last_seen_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check (country_code='MA'),
 check (length(trim(full_name)) between 2 and 160)
);

create table if not exists public.directory_doctor_sources (
 id uuid primary key default gen_random_uuid(),
 doctor_id uuid not null references public.directory_doctors(id) on delete cascade,
 source_id uuid not null references public.directory_sources(id) on delete restrict,
 source_record_key text not null,
 source_profile_url text,
 source_snapshot_hash text,
 observed_at timestamptz not null default now(),
 raw_public_fields jsonb not null default '{}'::jsonb,
 unique(source_id, source_record_key)
);

create table if not exists public.directory_claims (
 id uuid primary key default gen_random_uuid(),
 doctor_id uuid not null references public.directory_doctors(id) on delete cascade,
 claimant_id uuid not null references public.profiles(id) on delete cascade,
 evidence_type text not null check(evidence_type in ('account','professional_document','institutional_confirmation','other')),
 evidence_reference text,
 status text not null default 'pending' check(status in ('pending','approved','rejected','cancelled')),
 reviewer_id uuid references public.profiles(id) on delete set null,
 reviewer_notes text,
 created_at timestamptz not null default now(),
 reviewed_at timestamptz
);

create table if not exists public.directory_import_runs (
 id uuid primary key default gen_random_uuid(),
 source_id uuid not null references public.directory_sources(id) on delete restrict,
 mode text not null check(mode in ('dry_run','commit')),
 status public.directory_import_status not null default 'running',
 initiated_by uuid references public.profiles(id) on delete set null,
 input_sha256 text,
 records_seen integer not null default 0,
 records_accepted integer not null default 0,
 records_rejected integer not null default 0,
 records_new integer not null default 0,
 records_updated integer not null default 0,
 records_merged integer not null default 0,
 errors jsonb not null default '[]'::jsonb,
 started_at timestamptz not null default now(),
 finished_at timestamptz
);

create table if not exists public.directory_import_records (
 id bigint generated always as identity primary key,
 run_id uuid not null references public.directory_import_runs(id) on delete cascade,
 source_record_key text,
 action text not null check(action in ('accepted','rejected','new','updated','merged','duplicate','skipped')),
 doctor_id uuid references public.directory_doctors(id) on delete set null,
 reason text,
 payload_hash text,
 created_at timestamptz not null default now()
);

create index if not exists directory_doctors_name_trgm on public.directory_doctors using gin (normalized_name gin_trgm_ops);
create index if not exists directory_doctors_city_specialty on public.directory_doctors(city, normalized_specialty);
create index if not exists directory_doctors_status on public.directory_doctors(verification_status);
create index if not exists directory_sources_permitted on public.directory_sources(permitted_for_import);
create index if not exists directory_import_records_run on public.directory_import_records(run_id);

create or replace function public.directory_normalize_text(p text) returns text language sql immutable as $$
 select regexp_replace(lower(unaccent(coalesce(p,''))), '[^a-z0-9]+', ' ', 'g')::text;
$$;

create or replace function public.directory_search_doctors(p_query text default null, p_city text default null, p_specialty text default null, p_limit integer default 50)
returns setof public.directory_doctors language sql stable security definer set search_path=public as $$
 select d.* from public.directory_doctors d
 where d.verification_status in ('source_verified','claimed','verified')
 and (p_query is null or p_query='' or d.normalized_name % public.directory_normalize_text(p_query))
 and (p_city is null or p_city='' or public.directory_normalize_text(d.city)=public.directory_normalize_text(p_city))
 and (p_specialty is null or p_specialty='' or d.normalized_specialty=public.directory_normalize_text(p_specialty))
 order by similarity(d.normalized_name, public.directory_normalize_text(coalesce(p_query,d.full_name))) desc, d.full_name
 limit greatest(1, least(coalesce(p_limit,50),100));
$$;

alter table public.directory_sources enable row level security;
alter table public.directory_doctors enable row level security;
alter table public.directory_doctor_sources enable row level security;
alter table public.directory_claims enable row level security;
alter table public.directory_import_runs enable row level security;
alter table public.directory_import_records enable row level security;

create policy directory_sources_public on public.directory_sources for select using (permitted_for_import=true or public.is_platform_admin());
create policy directory_doctors_public on public.directory_doctors for select using (verification_status in ('source_verified','claimed','verified') or profile_claimed_by=auth.uid() or public.is_platform_admin());
create policy directory_claims_self_insert on public.directory_claims for insert with check (claimant_id=auth.uid());
create policy directory_claims_self_read on public.directory_claims for select using (claimant_id=auth.uid() or public.is_platform_admin());
create policy directory_claims_admin_update on public.directory_claims for update using (public.is_platform_admin()) with check (public.is_platform_admin());
create policy directory_runs_admin on public.directory_import_runs for all using (public.is_platform_admin()) with check (public.is_platform_admin());
create policy directory_records_admin on public.directory_import_records for select using (public.is_platform_admin());
create policy directory_source_rows_admin on public.directory_doctor_sources for select using (public.is_platform_admin());

insert into public.directory_sources(code,name,publisher,source_url,license_name,terms_url,permitted_for_import,notes)
values
('data_gov_ma','Morocco Open Data — Santé','Portail Open Data Maroc','https://www.data.gov.ma/','Open Data Commons Open Database License (where explicitly attached)','https://www.data.gov.ma/',true,'Use only datasets whose individual resource licence permits the intended reuse; health datasets are complementary and may not contain a complete physician registry.'),
('cnom_public','CNOM Maroc — public institutional pages','Conseil National de l’Ordre des Médecins','https://www.cnom-maroc.com/',null,'https://www.cnom-maroc.com/',false,'Institutional authority/reference. Do not automate extraction until the applicable terms/permission and technical access conditions are confirmed.'),
('doctor_self_claim','Médecin — déclaration directe','Tabib.ma',null,null,null,true,'Doctor-submitted/claimed profile; verification must be performed separately.')
on conflict(code) do update set updated_at=now();
