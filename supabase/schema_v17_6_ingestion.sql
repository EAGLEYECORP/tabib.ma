-- V17.6 — controlled national directory ingestion
-- Run after V17.5. No patient data. Imports require an explicitly permitted source.
create table if not exists public.directory_import_manifests (
 id uuid primary key default gen_random_uuid(),
 run_id uuid not null references public.directory_import_runs(id) on delete cascade,
 file_name text,
 format text not null check(format in ('json','ndjson','csv')),
 input_sha256 text not null,
 parser_version text not null default 'v17.6',
 source_license_snapshot text,
 source_terms_snapshot text,
 rollback_available boolean not null default true,
 created_at timestamptz not null default now(),
 unique(input_sha256, parser_version)
);

create table if not exists public.directory_import_mutations (
 id bigint generated always as identity primary key,
 run_id uuid not null references public.directory_import_runs(id) on delete cascade,
 doctor_id uuid references public.directory_doctors(id) on delete set null,
 mutation_type text not null check(mutation_type in ('insert','update','merge')),
 before_row jsonb,
 after_row jsonb,
 source_record_key text,
 created_at timestamptz not null default now()
);

create index if not exists directory_import_manifests_run on public.directory_import_manifests(run_id);
create index if not exists directory_import_mutations_run on public.directory_import_mutations(run_id);
create index if not exists directory_import_mutations_doctor on public.directory_import_mutations(doctor_id);

alter table public.directory_import_manifests enable row level security;
alter table public.directory_import_mutations enable row level security;
create policy directory_manifests_admin on public.directory_import_manifests for all using (public.is_platform_admin()) with check (public.is_platform_admin());
create policy directory_mutations_admin on public.directory_import_mutations for all using (public.is_platform_admin()) with check (public.is_platform_admin());

-- Rollback is intentionally explicit and admin-only. It restores rows captured in the mutation log.
create or replace function public.rollback_directory_import(p_run_id uuid)
returns integer language plpgsql security definer set search_path=public as $$
declare m record; n integer:=0;
begin
 if not public.is_platform_admin() then raise exception 'FORBIDDEN'; end if;
 for m in select * from public.directory_import_mutations where run_id=p_run_id order by id desc loop
   if m.mutation_type='insert' then delete from public.directory_doctors where id=m.doctor_id; n:=n+1;
   elsif m.mutation_type='update' and m.before_row is not null then
     update public.directory_doctors set
       full_name=(m.before_row->>'full_name'), normalized_name=(m.before_row->>'normalized_name'), specialty=(m.before_row->>'specialty'), normalized_specialty=(m.before_row->>'normalized_specialty'), city=(m.before_row->>'city'), region=(m.before_row->>'region'), professional_address=(m.before_row->>'professional_address'), public_phone=(m.before_row->>'public_phone'), public_email=(m.before_row->>'public_email'), website_url=(m.before_row->>'website_url'), updated_at=now()
     where id=m.doctor_id; n:=n+1;
   end if;
 end loop;
 update public.directory_import_runs set status='rolled_back', finished_at=now() where id=p_run_id;
 return n;
end $$;
