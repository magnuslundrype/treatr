-- RLS: en bruger fra organisation A kan ikke se eller røre data fra organisation B.
\set org_a '00000000-0000-4000-a000-000000000001'
\set org_b '00000000-0000-4000-b000-000000000001'

-- 0. Sikr at testen betyder noget: B har rækker i alle tabeller med organization_id.
do $$
declare t text; n int;
begin
  for t in
    select c.table_name from information_schema.columns c
    join pg_tables pt on pt.schemaname = c.table_schema and pt.tablename = c.table_name
    where c.table_schema = 'public' and c.column_name = 'organization_id'
      and c.table_name not in ('confirmation_links')  -- oprettes først i flow-testen
  loop
    execute format('select count(*) from public.%I where organization_id = %L', t, '00000000-0000-4000-b000-000000000001') into n;
    perform test.ok(n > 0, format('fixture: organisation B har rækker i %s', t));
  end loop;
end $$;

-- 1. Ejer i A ser intet fra B, i nogen tabel.
begin;
select test.login('00000000-0000-4000-a000-0000000000a1');
do $$
declare t text; n int;
begin
  for t in
    select c.table_name from information_schema.columns c
    join pg_tables pt on pt.schemaname = c.table_schema and pt.tablename = c.table_name
    where c.table_schema = 'public' and c.column_name = 'organization_id'
  loop
    execute format('select count(*) from public.%I where organization_id = %L', t, '00000000-0000-4000-b000-000000000001') into n;
    perform test.ok(n = 0, format('A-ejer ser 0 rækker fra B i %s', t));
  end loop;
  perform test.ok((select count(*) from public.organizations) = 1, 'A-ejer ser kun sin egen organisation');
  perform test.ok((select count(*) from public.villas) = 1, 'A-ejer ser kun sin egen villa');
  perform test.ok((select count(*) from public.profiles) = 3, 'A-ejer ser kun de 3 profiler i A');
  perform test.ok((select count(*) from public.messages where body like 'B:%') = 0, 'A-ejer ser ingen beskeder fra B');
  perform test.ok((select count(*) from public.upsell_performance) = 1, 'A-ejer ser kun egen mersalgsstatistik');
end $$;
rollback;

-- 2. Ejer i A kan ikke skrive i B.
begin;
select test.login('00000000-0000-4000-a000-0000000000a1');
do $$
declare n int;
begin
  perform test.ok(test.error_of($q$insert into public.villas (organization_id, name, slug)
    values ('00000000-0000-4000-b000-000000000001', 'Indbrud', 'indbrud')$q$) = '42501', 'A kan ikke oprette en villa i B');
  perform test.ok(test.error_of($q$insert into public.guests (organization_id, full_name)
    values ('00000000-0000-4000-b000-000000000001', 'Falsk gæst')$q$) = '42501', 'A kan ikke oprette en gæst i B');
  update public.villas set name = 'Overtaget' where organization_id = '00000000-0000-4000-b000-000000000001';
  get diagnostics n = row_count;
  perform test.ok(n = 0, 'A kan ikke rette en villa i B (0 rækker ramt)');
  delete from public.guests where organization_id = '00000000-0000-4000-b000-000000000001';
  get diagnostics n = row_count;
  perform test.ok(n = 0, 'A kan ikke slette en gæst i B (0 rækker ramt)');
  perform test.ok(test.error_of($q$update public.villas set organization_id = '00000000-0000-4000-b000-000000000001'$q$) = '42501',
    'A kan ikke flytte sin egen villa over i B');
  perform test.ok(test.error_of($q$select public.tap_approval((select id from public.approvals limit 1))$q$) is null,
    'A-ejer kan trykke på en godkendelse i sin egen organisation');
end $$;
rollback;

-- 2b. ...og heller ikke trykke på B's godkendelser.
begin;
select set_config('test.b_approval', (select id::text from public.approvals where organization_id = :'org_b' limit 1), true);
select test.login('00000000-0000-4000-a000-0000000000a1');
do $$
begin
  perform test.ok(test.error_of(format('select public.tap_approval(%L)', current_setting('test.b_approval'))) = '42501',
    'A kan ikke godkende noget i B');
end $$;
rollback;

-- 3. Ejer i B ser kun B.
begin;
select test.login('00000000-0000-4000-b000-0000000000a1');
do $$
begin
  perform test.ok((select count(*) from public.villas) = 1 and (select name from public.villas) = 'Villa B Secreta', 'B-ejer ser kun B''s villa');
  perform test.ok((select count(*) from public.guests where organization_id = '00000000-0000-4000-a000-000000000001') = 0, 'B-ejer ser ingen gæster fra A');
  perform test.ok((select count(*) from public.bookings) = 1, 'B-ejer ser kun B''s bestilling');
end $$;
rollback;

-- 4. En bruger uden organisation ser ingenting.
begin;
select test.login('00000000-0000-4000-c000-0000000000a1');
do $$
begin
  perform test.ok((select count(*) from public.organizations) = 0, 'bruger uden organisation ser ingen organisationer');
  perform test.ok((select count(*) from public.villas) = 0, 'bruger uden organisation ser ingen villaer');
  perform test.ok((select count(*) from public.messages) = 0, 'bruger uden organisation ser ingen beskeder');
  perform test.ok((select count(*) from public.profiles) = 1, 'bruger uden organisation ser kun sin egen profil');
end $$;
rollback;

-- 5. anon (ikke logget ind) har ingen adgang overhovedet.
begin;
select test.as_role('anon');
do $$
begin
  perform test.ok(test.error_of('select * from public.villas') = '42501', 'anon kan ikke læse villaer');
  perform test.ok(test.error_of('select * from public.confirmation_links') = '42501', 'anon kan ikke læse bekræftelseslinks');
  perform test.ok(test.error_of($q$select public.redeem_confirmation_link('x', 'confirm')$q$) = '42501', 'anon kan ikke kalde redeem_confirmation_link');
  perform test.ok(test.error_of($q$select * from public.peek_confirmation_link('x')$q$) = '42501', 'anon kan ikke kalde peek_confirmation_link');
end $$;
rollback;

-- 6. Roller inden for samme organisation: concierge ser ikke penge og kan ikke ændre kataloget.
begin;
select test.login('00000000-0000-4000-a000-0000000000a3');
do $$
declare n int;
begin
  perform test.ok((select count(*) from public.bookings) = 1, 'concierge ser bestillinger');
  perform test.ok((select count(*) from public.payments) = 0, 'concierge ser ikke betalinger');
  perform test.ok((select count(*) from public.audit_log) = 0, 'concierge ser ikke audit-log');
  perform test.ok((select count(*) from public.confirmation_links) = 0, 'concierge ser ikke bekræftelseslinks');
  perform test.ok(test.error_of($q$insert into public.services (organization_id, category, name_i18n, default_price_cents)
    values ('00000000-0000-4000-a000-000000000001', 'other', '{"en": "x"}', 1)$q$) = '42501', 'concierge kan ikke oprette services');
  update public.villa_services set price_cents = 1;
  get diagnostics n = row_count;
  perform test.ok(n = 0, 'concierge kan ikke ændre priser');
  perform test.ok(test.error_of($q$select public.tap_approval((select id from public.approvals limit 1))$q$) = '42501', 'concierge kan ikke godkende');
  perform test.ok(test.error_of($q$insert into public.organization_members (organization_id, user_id, role)
    values ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-c000-0000000000a1', 'owner')$q$) = '42501', 'concierge kan ikke tilføje medlemmer');
  perform test.ok(test.error_of($q$insert into public.messages (organization_id, conversation_id, sender_type, status, body)
    values ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000101', 'staff', 'sent', 'Hej fra Carmen')$q$) is null, 'concierge kan skrive til gæsten');
  perform test.ok(test.error_of($q$insert into public.messages (organization_id, conversation_id, sender_type, status, body)
    values ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000101', 'guest', 'received', 'forfalsket')$q$) = '42501', 'medarbejder kan ikke udgive sig for at være gæsten');
  perform test.ok(test.error_of($q$update public.messages set body = 'omskrevet' where sender_type = 'guest'$q$) = '23514', 'medarbejder kan ikke omskrive gæstens besked');
  perform test.ok(test.error_of($q$update public.messages set status = 'discarded' where sender_type = 'guest'$q$) = '23514', 'medarbejder kan ikke ændre status på gæstens besked');
end $$;
rollback;

-- 6b. Man kan ikke flytte sin egen notifikation over i en anden organisation.
begin;
insert into public.notifications (organization_id, recipient_type, recipient_user_id, channel, template_key)
values ('00000000-0000-4000-a000-000000000001', 'staff', '00000000-0000-4000-a000-0000000000a3', 'in_app', 'booking.needs_approval');
select test.login('00000000-0000-4000-a000-0000000000a3');
do $$
declare n int;
begin
  update public.notifications set status = 'read', read_at = now();
  get diagnostics n = row_count;
  perform test.ok(n = 1, 'man kan markere sin egen notifikation som læst (og kun sin egen)');
  perform test.ok(test.error_of($q$update public.notifications set organization_id = '00000000-0000-4000-b000-000000000001'$q$) = '42501',
    'man kan ikke flytte en notifikation over i en anden organisation');
end $$;
rollback;

-- 7. Back office ser penge, men ikke audit-log. Ejer ser audit-log. Sidste ejer kan ikke fjernes.
begin;
select test.login('00000000-0000-4000-a000-0000000000a2');
do $$ begin
  perform test.ok((select count(*) from public.payments) = 1, 'back office ser betalinger');
  perform test.ok((select count(*) from public.audit_log) = 0, 'back office ser ikke audit-log');
end $$;
rollback;
begin;
select test.login('00000000-0000-4000-a000-0000000000a1');
do $$ begin
  perform test.ok((select count(*) from public.audit_log) > 0, 'ejer ser audit-log');
  perform test.ok(test.error_of($q$delete from public.organization_members where role = 'owner'$q$) = '23514', 'sidste ejer kan ikke fjernes');
  perform test.ok(test.error_of($q$update public.audit_log set action = 'x'$q$) is null
    and (select count(*) from public.audit_log where action = 'x') = 0, 'ejer kan ikke rette i audit-log');
end $$;
rollback;

-- 8. Sammensatte fremmednøgler: selv serveren (uden RLS) kan ikke blande organisationer.
do $$ begin
  perform test.ok(test.error_of($q$insert into public.bookings (organization_id, villa_id, stay_id, service_id, scheduled_start, guest_price_cents)
    values ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-b000-0000000000b1', '00000000-0000-4000-a000-0000000000f1',
            '00000000-0000-4000-a000-0000000000c1', now(), 1)$q$) = '23503', 'en bestilling i A kan ikke pege på en villa i B');
  perform test.ok(test.error_of($q$insert into public.stays (organization_id, villa_id, primary_guest_id, check_in, check_out)
    values ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-0000000000b1', '00000000-0000-4000-b000-0000000000e1',
            current_date, current_date + 1)$q$) = '23503', 'et ophold i A kan ikke pege på en gæst i B');
end $$;
