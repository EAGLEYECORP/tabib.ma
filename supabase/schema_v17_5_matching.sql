-- TABIB.MA V17.5 — national matching: doctor ↔ practice ↔ clinic ↔ city
create extension if not exists pg_trgm;

create table if not exists public.directory_doctor_locations (
 id uuid primary key default gen_random_uuid(),
 doctor_id uuid not null references public.directory_doctors(id) on delete cascade,
 clinic_id uuid references public.clinics(id) on delete set null,
 clinic_location_id uuid references public.clinic_locations(id) on delete set null,
 location_name text,
 address_line1 text,
 postal_code text,
 city text not null,
 region text,
 country_code char(2) not null default 'MA' check(country_code='MA'),
 latitude numeric(9,6), longitude numeric(9,6),
 source_id uuid references public.directory_sources(id) on delete set null,
 source_record_key text,
 verified boolean not null default false,
 active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(doctor_id, clinic_id, clinic_location_id, city, address_line1)
);
create index if not exists ddl_city_idx on public.directory_doctor_locations(lower(city));
create index if not exists ddl_doctor_idx on public.directory_doctor_locations(doctor_id, active);
create index if not exists ddl_geo_idx on public.directory_doctor_locations(latitude, longitude) where active=true;

create table if not exists public.directory_match_candidates (
 id uuid primary key default gen_random_uuid(),
 doctor_id uuid not null references public.directory_doctors(id) on delete cascade,
 clinic_id uuid references public.clinics(id) on delete cascade,
 clinic_location_id uuid references public.clinic_locations(id) on delete cascade,
 match_type text not null check(match_type in ('doctor_clinic','doctor_location','doctor_profile')),
 score numeric(5,4) not null check(score between 0 and 1),
 evidence jsonb not null default '{}'::jsonb,
 status text not null default 'candidate' check(status in ('candidate','confirmed','rejected')),
 created_at timestamptz not null default now(), reviewed_at timestamptz,
 unique(doctor_id, clinic_id, clinic_location_id, match_type)
);
create index if not exists dmc_doctor_score_idx on public.directory_match_candidates(doctor_id, score desc);
create index if not exists dmc_clinic_idx on public.directory_match_candidates(clinic_id, score desc);

alter table public.directory_doctor_locations enable row level security;
alter table public.directory_match_candidates enable row level security;
create policy ddl_public_read on public.directory_doctor_locations for select using (active=true and (verified=true or public.is_platform_admin()));
create policy ddl_admin_all on public.directory_doctor_locations for all using(public.is_platform_admin()) with check(public.is_platform_admin());
create policy dmc_admin_all on public.directory_match_candidates for all using(public.is_platform_admin()) with check(public.is_platform_admin());

create or replace function public.search_directory_v17_5(
 p_query text default null, p_city text default null, p_specialty text default null,
 p_verified_only boolean default false, p_lat numeric default null, p_lng numeric default null,
 p_radius_km numeric default null, p_limit integer default 20, p_offset integer default 0
) returns table(
 doctor_id uuid, full_name text, specialty text, city text, region text,
 verification_status text, claimed boolean, clinic_name text, location_name text,
 latitude numeric, longitude numeric, rank numeric
) language sql stable security definer set search_path=public as $$
 with base as (
  select d.id, d.full_name, d.specialty, d.city, d.region, d.verification_status,
         (d.profile_claimed_by is not null) as claimed,
         coalesce(dl.city,d.city) as loc_city, dl.region as loc_region,
         c.name as clinic_name, dl.location_name, dl.latitude, dl.longitude,
         greatest(
           case when nullif(trim(p_query),'') is null then 0 else similarity(d.normalized_name, public.directory_normalize_text(p_query)) end,
           case when nullif(trim(p_query),'') is null then 0 else similarity(coalesce(d.normalized_specialty,''), public.directory_normalize_text(p_query)) end
         ) as text_rank
  from public.directory_doctors d
  left join public.directory_doctor_locations dl on dl.doctor_id=d.id and dl.active=true and dl.verified=true
  left join public.clinics c on c.id=dl.clinic_id
  where d.verification_status in ('source_verified','claimed','verified')
    and (not p_verified_only or d.verification_status='verified')
    and (nullif(trim(p_city),'') is null or public.directory_normalize_text(coalesce(dl.city,d.city))=public.directory_normalize_text(p_city))
    and (nullif(trim(p_specialty),'') is null or public.directory_normalize_text(coalesce(d.specialty,''))=public.directory_normalize_text(p_specialty))
    and (nullif(trim(p_query),'') is null or d.normalized_name % public.directory_normalize_text(p_query) or public.directory_normalize_text(coalesce(d.specialty,'')) % public.directory_normalize_text(p_query))
 )
 select id,full_name,specialty,loc_city,loc_region,verification_status,claimed,clinic_name,location_name,latitude,longitude,
        greatest(text_rank, case when p_lat is not null and p_lng is not null and latitude is not null and longitude is not null and p_radius_km is not null then
          case when (111.045 * sqrt(power(latitude-p_lat,2)+power((longitude-p_lng)*cos(radians(p_lat)),2))) <= p_radius_km then 0.25 else 0 end else 0 end)::numeric as rank
 from base
 order by rank desc, full_name asc
 limit greatest(1,least(coalesce(p_limit,20),100)) offset greatest(0,coalesce(p_offset,0));
$$;
revoke all on function public.search_directory_v17_5(text,text,text,boolean,numeric,numeric,numeric,integer,integer) from public;
