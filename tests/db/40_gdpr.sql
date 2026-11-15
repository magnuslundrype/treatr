-- GDPR: gæstedata anonymiseres efter opholdet. Tal og historik bliver.
begin;

-- Opholdet sluttede for 40 dage siden (grænsen er 30 dage).
update public.stays set check_in = current_date - 47, check_out = current_date - 40, status = 'completed'
where id = '00000000-0000-4000-a000-0000000000f1';

select test.as_role('service_role');
do $$
declare n int;
begin
  n := public.purge_expired_guest_data();
  perform test.ok(n = 1, 'præcis én gæst er forbi slettefristen');
  perform test.ok((select full_name = 'Anonymiseret gæst' and email is null and phone is null and anonymized_at is not null
                   from public.guests where id = '00000000-0000-4000-a000-0000000000e1'), 'navn, mail og telefon er væk');
  perform test.ok((select count(*) from public.messages where conversation_id = '00000000-0000-4000-a000-000000000101'
                   and (body <> '' or ai_suggested_body is not null or redacted_at is null)) = 0, 'beskedernes tekst er slettet');
  perform test.ok((select guest_notes is null and supplier_notes is null and guest_price_cents = 57000 from public.bookings where id = '00000000-0000-4000-a000-000000000121'),
    'bestillingens fritekst er væk, men beløbet er bevaret');
  perform test.ok((select count(*) from public.audit_log where action = 'gdpr.anonymize' and record_id = '00000000-0000-4000-a000-0000000000e1') = 1,
    'sletningen står i audit-loggen');
  perform test.ok((select count(*) from public.audit_log where old_data::text like '%Greta%' or new_data::text like '%Greta%' or new_data::text like '%vegetar%') = 0,
    'audit-loggen indeholder ikke gæstens persondata');
  perform test.ok((select full_name from public.guests where id = '00000000-0000-4000-b000-0000000000e1') = 'Hemmelig B-Gæst', 'gæster med kommende ophold røres ikke');
  perform test.ok(public.purge_expired_guest_data() = 0, 'anden kørsel finder ikke flere');
  perform test.ok(test.error_of('delete from public.audit_log') = '42501', 'audit-loggen kan ikke slettes, heller ikke af serveren');
end $$;

rollback;
