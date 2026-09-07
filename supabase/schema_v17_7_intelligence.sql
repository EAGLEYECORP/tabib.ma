-- TABIB.MA V17.7 — directory intelligence: quality, freshness, geospatial ranking and stale-record detection
create extension if not exists pg_trgm;

alter table public.directory_doctors
  add column if not exists quality_score numeric(5,4) not null default 0,
  add column if not exists last_quality_at timestamptz,
  add column if not exists stale_after_days integer not null default 180;

alter table public.directory_doctor_locations
  add column if not exists geo_precision text check (geo_precision in ('exact','address','city','unknown'));

create table if not exists public.directory_quality_snapshots (
 id uuid primary key default gen_random_uuid(),
 doctor_id uuid not null references public.directory_doctors(id) on delete cascade,
 score numeric(5,4) not null check(score between 0 and 1),
 completeness numeric(5,4) not null check(completeness between 0 and 1),
 freshness numeric(5,4) not null check(freshness between 0 and 1),
 source_confidence numeric(5,4) not null check(source_confidence between 0 and 1),
 geo_confidence numeric(5,4) not null check(geo_confidence between 0 and 1),
 flags jsonb not null default '[]'::jsonb,
 calculated_at timestamptz not null default now()
);
create index if not exists dqs_doctor_time_idx on public.directory_quality_snapshots(doctor_id, calculated_at desc);

create table if not exists public.directory_stale_events (
 id uuid primary key default gen_random_uuid(),
 doctor_id uuid not null references public.directory_doctors(id) on delete cascade,
 last_seen_at timestamptz,
 detected_at timestamptz not null default now(),
 status text not null default 'open' check(status in ('open','reviewed','resolved')),
 reason text not null
);
create index if not exists dse_status_idx on public.directory_stale_events(status, detected_at desc);

create or replace function public.directory_quality_score(p_doctor_id uuid)
returns numeric language sql stable security definer set search_path=public as $$
with d as (select * from public.directory_doctors where id=p_doctor_id),
loc as (select count(*) n, count(*) filter(where latitude is not null and longitude is not null) geo from public.directory_doctor_locations where doctor_id=p_doctor_id and active=true),
src as (select count(*) n, max(observed_at) last_seen from public.directory_doctor_sources where doctor_id=p_doctor_id),
scores as (
 select
   ((case when nullif(trim(d.full_name),'') is not null then 0.25 else 0 end) +
    (case when nullif(trim(d.specialty),'') is not null then 0.15 else 0 end) +
    (case when nullif(trim(d.city),'') is not null then 0.10 else 0 end) +
    (case when nullif(trim(d.professional_address),'') is not null then 0.10 else 0 end) +
    (case when nullif(trim(d.public_phone),'') is not null then 0.05 else 0 end) +
    (case when nullif(trim(d.website_url),'') is not null then 0.05 else 0 end) +
    (case when coalesce(loc.geo,0)>0 then 0.10 else 0 end) +
    (case when d.verification_status='verified' then 0.20 when d.verification_status in ('claimed','source_verified') then 0.10 else 0 end)) as score,
   (case when src.last_seen is null then 0 else greatest(0::numeric, 1 - extract(epoch from (now()-src.last_seen))/(86400*d.stale_after_days)) end) as freshness
 from d cross join loc cross join src
)
select round(least(1, score * (0.7 + 0.3*freshness)),4) from scores;
$$;

create or replace function public.refresh_directory_quality(p_limit integer default 1000)
returns integer language plpgsql security definer set search_path=public as $$
declare r record; n integer:=0; s numeric;
begin
 for r in select id from public.directory_doctors where verification_status not in ('removed') order by updated_at desc limit greatest(1,least(coalesce(p_limit,1000),10000)) loop
   s:=public.directory_quality_score(r.id);
   update public.directory_doctors set quality_score=s,last_quality_at=now() where id=r.id;
   insert into public.directory_quality_snapshots(doctor_id,score,completeness,freshness,source_confidence,geo_confidence,flags)
   values(r.id,s,s,s,s,s,'[]'::jsonb);
   n:=n+1;
 end loop;
 return n;
end $$;

create or replace function public.detect_directory_stale(p_days integer default 180, p_limit integer default 10000)
returns integer language plpgsql security definer set search_path=public as $$
declare r record; n integer:=0;
begin
 for r in select d.id,d.source_last_seen_at from public.directory_doctors d where d.verification_status in ('source_verified','claimed','verified') and coalesce(d.source_last_seen_at,d.updated_at) < now() - make_interval(days=>greatest(1,p_days)) limit greatest(1,least(coalesce(p_limit,10000),50000)) loop
   insert into public.directory_stale_events(doctor_id,last_seen_at,reason)
   select r.id,r.source_last_seen_at,'NO_RECENT_SOURCE_OBSERVATION'
   where not exists(select 1 from public.directory_stale_events e where e.doctor_id=r.id and e.status='open');
   n:=n+1;
 end loop;
 return n;
end $$;

create or replace function public.search_directory_v17_7(
 p_query text default null, p_city text default null, p_specialty text default null,
 p_verified_only boolean default false, p_lat numeric default null, p_lng numeric default null,
 p_radius_km numeric default null, p_limit integer default 20, p_offset integer default 0
) returns table(doctor_id uuid,full_name text,specialty text,city text,region text,verification_status text,claimed boolean,clinic_name text,location_name text,latitude numeric,longitude numeric,rank numeric,quality_score numeric,distance_km numeric)
language sql stable security definer set search_path=public as $$
with candidates as (
 select d.id,d.full_name,d.specialty,d.city,d.region,d.verification_status,(d.profile_claimed_by is not null) claimed,c.name clinic_name,dl.location_name,dl.latitude,dl.longitude,d.quality_score,
 case when p_lat is not null and p_lng is not null and dl.latitude is not null and dl.longitude is not null then 111.045*sqrt(power(dl.latitude-p_lat,2)+power((dl.longitude-p_lng)*cos(radians(p_lat)),2)) end distance_km,
 greatest(case when nullif(trim(p_query),'') is null then 0 else similarity(d.normalized_name,public.directory_normalize_text(p_query)) end,case when nullif(trim(p_query),'') is null then 0 else similarity(coalesce(d.normalized_specialty,''),public.directory_normalize_text(p_query)) end) text_rank
 from public.directory_doctors d left join public.directory_doctor_locations dl on dl.doctor_id=d.id and dl.active=true and dl.verified=true left join public.clinics c on c.id=dl.clinic_id
 where d.verification_status in ('source_verified','claimed','verified') and (not p_verified_only or d.verification_status='verified')
 and (nullif(trim(p_city),'') is null or public.directory_normalize_text(coalesce(dl.city,d.city))=public.directory_normalize_text(p_city))
 and (nullif(trim(p_specialty),'') is null or public.directory_normalize_text(coalesce(d.specialty,''))=public.directory_normalize_text(p_specialty))
 and (nullif(trim(p_query),'') is null or d.normalized_name % public.directory_normalize_text(p_query) or public.directory_normalize_text(coalesce(d.specialty,'')) % public.directory_normalize_text(p_query))
), ranked as (
 select *, greatest(text_rank,case when distance_km is null or p_radius_km is null then 0 when distance_km<=p_radius_km then 0.25*(1-distance_km/greatest(p_radius_km,0.001)) else 0 end) + 0.20*coalesce(quality_score,0) as final_rank from candidates
)
select id,full_name,specialty,city,region,verification_status,claimed,clinic_name,location_name,latitude,longitude,round(final_rank,4),quality_score,distance_km from ranked
where p_radius_km is null or distance_km is null or distance_km<=p_radius_km order by final_rank desc,quality_score desc,full_name asc limit greatest(1,least(coalesce(p_limit,20),100)) offset greatest(0,coalesce(p_offset,0));
$$;
revoke all on function public.directory_quality_score(uuid) from public;
revoke all on function public.refresh_directory_quality(integer) from public;
revoke all on function public.detect_directory_stale(integer,integer) from public;
revoke all on function public.search_directory_v17_7(text,text,text,boolean,numeric,numeric,numeric,integer,integer) from public;
