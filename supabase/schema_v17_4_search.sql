-- Tabib.ma V17.4 national directory search/indexing layer
create extension if not exists pg_trgm;

create index if not exists doctors_directory_name_trgm_idx on public.doctors using gin ((coalesce(first_name,'') || ' ' || coalesce(last_name,'')) gin_trgm_ops);
create index if not exists doctors_directory_city_idx on public.doctors(city);
create index if not exists doctors_directory_specialty_idx on public.doctors(specialty);
create index if not exists doctors_directory_status_idx on public.doctors(verification_status);
create index if not exists doctor_locations_city_idx on public.doctor_locations(city);

create or replace function public.search_public_doctors(
  p_query text default null,
  p_city text default null,
  p_specialty text default null,
  p_verified_only boolean default false,
  p_limit integer default 20,
  p_offset integer default 0
) returns table (
  id uuid, first_name text, last_name text, specialty text, city text,
  verification_status text, source_verified_at timestamptz, rank real
) language sql stable security definer set search_path = public as $$
  select d.id, d.first_name, d.last_name, d.specialty, d.city,
         d.verification_status, d.source_verified_at,
         greatest(
           case when nullif(trim(p_query),'') is null then 0 else similarity(coalesce(d.first_name,'') || ' ' || coalesce(d.last_name,''), trim(p_query)) end,
           case when nullif(trim(p_query),'') is null then 0 else similarity(coalesce(d.specialty,''), trim(p_query)) end
         )::real as rank
  from public.doctors d
  where d.verification_status <> 'removed'
    and (not p_verified_only or d.verification_status in ('source_verified','claimed','verified'))
    and (nullif(trim(p_city),'') is null or lower(d.city)=lower(trim(p_city)))
    and (nullif(trim(p_specialty),'') is null or lower(d.specialty)=lower(trim(p_specialty)))
    and (nullif(trim(p_query),'') is null or
         (coalesce(d.first_name,'') || ' ' || coalesce(d.last_name,'')) ilike '%'||trim(p_query)||'%' or
         coalesce(d.specialty,'') ilike '%'||trim(p_query)||'%')
  order by rank desc, d.last_name asc, d.first_name asc
  limit greatest(1, least(p_limit,100)) offset greatest(0,p_offset);
$$;
revoke all on function public.search_public_doctors(text,text,text,boolean,integer,integer) from public;
