-- KUN TIL TEST på en almindelig Postgres (lokalt og i CI). Køres ALDRIG mod Supabase.
-- Efterligner det, Supabase har i forvejen: rollerne anon/authenticated/service_role,
-- skemaet auth med auth.users og auth.uid(), og de brede standard-rettigheder
-- (så testen beviser, at vores migration selv lukker for anon).

do $$
begin
  if not exists (select from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
end $$;

create schema extensions;
create extension pgcrypto with schema extensions;
grant usage on schema extensions to anon, authenticated, service_role;

create schema auth;
grant usage on schema auth to anon, authenticated, service_role;

create table auth.users (
  instance_id uuid,
  id uuid primary key,
  aud varchar(255),
  role varchar(255),
  email varchar(255) unique,
  encrypted_password varchar(255),
  email_confirmed_at timestamptz,
  raw_app_meta_data jsonb,
  raw_user_meta_data jsonb,
  created_at timestamptz,
  updated_at timestamptz,
  confirmation_token varchar(255),
  email_change varchar(255),
  email_change_token_new varchar(255),
  recovery_token varchar(255)
);

create table auth.identities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  provider_id text not null,
  identity_data jsonb not null,
  provider text not null,
  last_sign_in_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz,
  unique (provider_id, provider)
);

create function auth.uid() returns uuid language sql stable as $$
  select nullif(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub', '')::uuid
$$;
create function auth.role() returns text language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'
$$;
grant execute on function auth.uid(), auth.role() to anon, authenticated, service_role;

-- Supabases standard: alt nyt i public bliver givet til alle tre roller.
grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;

-- Hjælpere til testene.
create schema test;
grant usage on schema test to anon, authenticated, service_role;

-- "Log ind" som en bruger resten af transaktionen (præcis som PostgREST gør det).
create function test.login(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true),
         set_config('role', 'authenticated', true)
$$;
create function test.as_role(p_role text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('role', p_role)::text, true),
         set_config('role', p_role, true)
$$;

-- Kør SQL og returnér fejlkoden (SQLSTATE), eller null hvis det gik godt.
create function test.error_of(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return null;
exception when others then
  return sqlstate;
end $$;

create function test.ok(p_condition boolean, p_name text) returns void language plpgsql as $$
begin
  if p_condition is not true then
    raise exception 'FEJL: %', p_name;
  end if;
  raise notice 'ok - %', p_name;
end $$;
grant execute on all functions in schema test to anon, authenticated, service_role;
