-- Regler som ALLE migrationer skal overholde. Fejler denne fil i CI, mangler din migration noget.
do $$
declare r record; n int;
begin
  -- 1. RLS er slået til på alle tabeller.
  select count(*) into n from pg_tables where schemaname = 'public' and not rowsecurity;
  perform test.ok(n = 0, format('alle tabeller i public har RLS slået til (%s mangler)', n));
  for r in select tablename from pg_tables where schemaname = 'public' and not rowsecurity loop
    raise exception 'Tabellen public.% mangler: alter table ... enable row level security', r.tablename;
  end loop;

  -- 2. Alle tabeller hører til en organisation.
  for r in
    select t.tablename from pg_tables t
    where t.schemaname = 'public' and t.tablename not in ('organizations', 'profiles')
      and not exists (select 1 from information_schema.columns c
                      where c.table_schema = 'public' and c.table_name = t.tablename and c.column_name = 'organization_id' and c.is_nullable = 'NO')
      and t.tablename <> 'audit_log'  -- organization_id må være null for systemhændelser
  loop
    raise exception 'Tabellen public.% mangler kolonnen organization_id (not null)', r.tablename;
  end loop;
  perform test.ok(true, 'alle tabeller har organization_id');

  -- 3. Alle tabeller har mindst én policy (ellers kan ingen læse dem, og det er nok en fejl).
  for r in
    select t.tablename from pg_tables t
    where t.schemaname = 'public' and not exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = t.tablename)
  loop
    raise exception 'Tabellen public.% har ingen RLS-policies', r.tablename;
  end loop;
  perform test.ok(true, 'alle tabeller har mindst én policy');

  -- 4. Ingen policy gælder for anon eller for alle roller (public).
  select count(*) into n from pg_policies where schemaname = 'public' and (roles && array['anon', 'public']::name[]);
  perform test.ok(n = 0, 'ingen policy giver adgang til anon');

  -- 5. anon har ingen rettigheder på tabeller, views eller funktioner.
  select count(*) into n from information_schema.role_table_grants where table_schema = 'public' and grantee in ('anon', 'PUBLIC');
  perform test.ok(n = 0, format('anon har ingen rettigheder på tabeller og views (%s fundet)', n));
  select count(*) into n from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
  where ns.nspname in ('public', 'private') and (has_function_privilege('anon', p.oid, 'execute'));
  perform test.ok(n = 0, format('anon kan ikke køre nogen funktioner (%s fundet)', n));

  -- 6. security definer-funktioner skal have fast search_path (ellers kan de kapres).
  for r in
    select p.oid::regprocedure as fn from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname in ('public', 'private') and p.prosecdef
      and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')
  loop
    raise exception 'Funktionen % er security definer uden "set search_path"', r.fn;
  end loop;
  perform test.ok(true, 'alle security definer-funktioner har fast search_path');

  -- 7. Views skal følge RLS for den, der spørger.
  for r in
    select c.relname from pg_class c join pg_namespace ns on ns.oid = c.relnamespace
    where ns.nspname = 'public' and c.relkind = 'v'
      and not coalesce(c.reloptions @> array['security_invoker=true'], false)
  loop
    raise exception 'Viewet public.% mangler: with (security_invoker = true)', r.relname;
  end loop;
  perform test.ok(true, 'alle views bruger security_invoker');

  -- 8. Fremmednøgler skal have et indeks (ellers bliver sletning og joins langsomme).
  --    Undtagelse: "hvem gjorde det"-kolonner, der peger på profiles (medarbejdere slettes sjældent).
  for r in
    select c.conrelid::regclass as tbl, c.conname
    from pg_constraint c
    where c.contype = 'f' and c.connamespace = 'public'::regnamespace
      and c.confrelid <> 'public.profiles'::regclass
      and not exists (
        select 1 from pg_index i
        where i.indrelid = c.conrelid
          and (
            (i.indkey::int2[])[0:cardinality(c.conkey) - 1] @> c.conkey
            -- sammensat nøgle (organization_id, x_id): et indeks der starter med x_id er nok
            or (cardinality(c.conkey) = 2 and (i.indkey::int2[])[0] = c.conkey[2])
          )
      )
  loop
    raise exception 'Fremmednøglen % på % mangler et indeks', r.conname, r.tbl;
  end loop;
  perform test.ok(true, 'alle fremmednøgler har et indeks');
end $$;
