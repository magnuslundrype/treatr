-- Statusmaskinen, to tryk og bekræftelseslink (engangs-token).
-- Hele filen kører i én transaktion og rulles tilbage til sidst.
begin;

create temp table t (k text primary key, v text);
grant all on t to authenticated, service_role;

-- ---------- 1. Nyt forslag fra back office ----------
select test.login('00000000-0000-4000-a000-0000000000a2');
do $$
declare v_booking uuid; v_approval uuid;
begin
  perform test.ok(test.error_of($q$insert into public.bookings (organization_id, villa_id, stay_id, service_id, supplier_id, status, scheduled_start, guest_price_cents)
    values ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-0000000000b1', '00000000-0000-4000-a000-0000000000f1',
            '00000000-0000-4000-a000-0000000000c2', '00000000-0000-4000-a000-0000000000d2', 'approved', now() + interval '8 days', 14000)$q$) = '23514',
    'en bestilling kan ikke oprettes direkte som godkendt');

  insert into public.bookings (organization_id, villa_id, stay_id, service_id, supplier_id, scheduled_start, guest_price_cents, supplier_cost_cents)
  values ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-0000000000b1', '00000000-0000-4000-a000-0000000000f1',
          '00000000-0000-4000-a000-0000000000c2', '00000000-0000-4000-a000-0000000000d2', now() + interval '8 days', 14000, 9000)
  returning id into v_booking;
  insert into t values ('booking', v_booking);

  select id into v_approval from public.approvals where booking_id = v_booking and status = 'pending';
  perform test.ok(v_approval is not null, 'en ny bestilling får automatisk en ventende godkendelse');
  insert into t values ('approval', v_approval);

  perform test.ok(test.error_of(format($q$update public.bookings set status = 'approved' where id = %L$q$, v_booking)) = '23514',
    'status kan ikke sættes til godkendt uden to tryk');
  perform test.ok(test.error_of(format($q$update public.bookings set status = 'sent' where id = %L$q$, v_booking)) = '23514',
    'et forslag kan ikke springe direkte til sendt');
  perform test.ok(test.error_of(format($q$update public.approvals set status = 'approved', first_tap_at = now(), second_tap_at = now() where id = %L$q$, v_approval)) is null
    and (select status from public.approvals where id = v_approval) = 'pending',
    'godkendelsen kan ikke rettes direkte i tabellen');
  perform test.ok(test.error_of(format('select public.issue_confirmation_link(%L)', v_booking)) = '23514',
    'der kan ikke laves bekræftelseslink før godkendelse');
end $$;

-- ---------- 2. To tryk ----------
do $$
declare v_booking uuid := (select v from t where k = 'booking'); v_approval uuid := (select v from t where k = 'approval');
begin
  perform public.tap_approval(v_approval);
  perform test.ok((select status from public.approvals where id = v_approval) = 'first_tap'
    and (select status from public.bookings where id = v_booking) = 'proposed', 'efter første tryk er bestillingen stadig et forslag');

  update public.bookings set guest_price_cents = 15000 where id = v_booking;
  perform test.ok((select status from public.approvals where id = v_approval) = 'pending'
    and (select first_tap_by from public.approvals where id = v_approval) is null, 'ændres prisen efter første tryk, starter godkendelsen forfra');

  perform public.tap_approval(v_approval);
  perform public.tap_approval(v_approval);
  perform test.ok((select status from public.approvals where id = v_approval) = 'approved'
    and (select second_tap_by from public.approvals where id = v_approval) = '00000000-0000-4000-a000-0000000000a2'
    and (select snapshot ->> 'guest_price_cents' from public.approvals where id = v_approval) = '15000',
    'andet tryk godkender og gemmer hvem der trykkede og hvad der blev godkendt');
  perform test.ok((select status from public.bookings where id = v_booking) = 'approved'
    and (select approved_at from public.bookings where id = v_booking) is not null, 'efter to tryk er bestillingen godkendt');
  perform test.ok(test.error_of(format('select public.tap_approval(%L)', v_approval)) = '23514', 'et tredje tryk afvises');
  perform test.ok(test.error_of(format('update public.bookings set guest_price_cents = 1 where id = %L', v_booking)) = '23514',
    'prisen kan ikke ændres efter godkendelse');
end $$;

-- ---------- 3. Send til leverandør: bekræftelseslink ----------
do $$
declare v_booking uuid := (select v from t where k = 'booking'); v_token text;
begin
  v_token := public.issue_confirmation_link(v_booking);
  insert into t values ('token', v_token);
  perform test.ok(length(v_token) = 64, 'linket får et langt tilfældigt token');
  perform test.ok((select status from public.bookings where id = v_booking) = 'sent', 'bestillingen er nu sendt');
  perform test.ok((select count(*) from public.confirmation_links where token_hash = v_token) = 0
    and (select count(*) from public.confirmation_links where booking_id = v_booking) = 1, 'det rå token gemmes ikke i databasen, kun en hash');
  perform test.ok(test.error_of(format($q$select public.redeem_confirmation_link(%L, 'confirm')$q$, v_token)) = '42501',
    'en logget-ind medarbejder kan ikke selv bruge leverandørens link');
end $$;

-- ---------- 4. Leverandøren bruger linket (serveren kalder som service_role) ----------
select test.as_role('service_role');
do $$
declare v_booking uuid := (select v from t where k = 'booking'); v_token text := (select v from t where k = 'token');
begin
  perform test.ok((select link_state from public.peek_confirmation_link(v_token)) = 'valid', 'peek: linket er gyldigt');
  perform test.ok((select status from public.bookings where id = v_booking) = 'sent', 'peek bruger ikke linket');
  perform test.ok((select link_state from public.peek_confirmation_link('forkert-token')) = 'not_found', 'peek: ukendt token findes ikke');
  perform test.ok(public.redeem_confirmation_link('forkert-token', 'confirm') = 'not_found', 'et forkert token virker ikke');

  perform test.ok(public.redeem_confirmation_link(v_token, 'confirm', 'Vale, confirmado', '203.0.113.7') = 'confirmed', 'FØRSTE brug af tokenet bekræfter');
  perform test.ok((select status from public.bookings where id = v_booking) = 'supplier_confirmed', 'bestillingen er bekræftet af leverandøren');

  perform test.ok(public.redeem_confirmation_link(v_token, 'confirm') = 'already_used', 'ANDEN brug af samme token afvises');
  perform test.ok(public.redeem_confirmation_link(v_token, 'decline') = 'already_used', 'tokenet kan heller ikke bruges til at fortryde');
  perform test.ok((select status from public.bookings where id = v_booking) = 'supplier_confirmed', 'status er uændret efter andet forsøg');
  perform test.ok((select link_state from public.peek_confirmation_link(v_token)) = 'used', 'peek: linket er brugt');
  perform test.ok((select actor_type from public.booking_status_events where booking_id = v_booking and to_status = 'supplier_confirmed') = 'supplier',
    'historikken viser at det var leverandøren');
end $$;

-- ---------- 5. Resten af vejen: leveret → afregnet ----------
select test.login('00000000-0000-4000-a000-0000000000a2');
do $$
declare v_booking uuid := (select v from t where k = 'booking');
begin
  perform test.ok(test.error_of(format($q$update public.bookings set status = 'settled' where id = %L$q$, v_booking)) = '23514', 'kan ikke afregnes før levering');
  update public.bookings set status = 'delivered' where id = v_booking;
  update public.bookings set status = 'settled' where id = v_booking;
  perform test.ok((select array_agg(to_status::text order by id) from public.booking_status_events where booking_id = v_booking)
    = array['proposed', 'approved', 'sent', 'supplier_confirmed', 'delivered', 'settled'], 'historikken indeholder hele forløbet i rækkefølge');
  perform test.ok(test.error_of(format($q$update public.bookings set status = 'cancelled' where id = %L$q$, v_booking)) = '23514', 'en afregnet bestilling kan ikke annulleres');
end $$;

-- ---------- 6. Udløb, nyt link og nej fra leverandøren (seed-bestillingen) ----------
select test.login('00000000-0000-4000-a000-0000000000a1');
do $$
declare v_booking uuid := '00000000-0000-4000-a000-000000000121'; v_approval uuid; v_token text;
begin
  select id into v_approval from public.approvals where booking_id = v_booking and status = 'pending';
  perform public.tap_approval(v_approval);
  perform public.tap_approval(v_approval);
  v_token := public.issue_confirmation_link(v_booking, interval '1 hour');
  insert into t values ('token_expired', v_token);
end $$;

reset role;
update public.confirmation_links set expires_at = now() - interval '1 minute'
where booking_id = '00000000-0000-4000-a000-000000000121';

select test.as_role('service_role');
do $$
declare v_booking uuid := '00000000-0000-4000-a000-000000000121'; v_old text := (select v from t where k = 'token_expired'); v_new text;
begin
  perform test.ok(public.redeem_confirmation_link(v_old, 'confirm') = 'expired', 'et udløbet token virker ikke');
  perform test.ok((select status from public.bookings where id = v_booking) = 'sent', 'bestillingen venter stadig på svar');

  v_new := public.issue_confirmation_link(v_booking);
  perform test.ok(public.redeem_confirmation_link(v_old, 'confirm') in ('revoked', 'expired'), 'det gamle link virker ikke efter et nyt er lavet');
  perform test.ok(public.redeem_confirmation_link(v_new, 'decline', 'No puedo ese día') = 'declined', 'leverandøren kan sige nej');
  perform test.ok((select status from public.bookings where id = v_booking) = 'supplier_declined', 'bestillingen er afvist af leverandøren');
end $$;

select test.login('00000000-0000-4000-a000-0000000000a2');
do $$
declare v_booking uuid := '00000000-0000-4000-a000-000000000121';
begin
  update public.bookings set status = 'proposed', supplier_id = null where id = v_booking;
  perform test.ok((select count(*) from public.approvals where booking_id = v_booking and status = 'pending') = 1
    and (select count(*) from public.approvals where booking_id = v_booking and status = 'superseded') = 1,
    'et nyt forslag kræver en ny godkendelse; den gamle gælder ikke');
  perform test.ok(test.error_of(format($q$update public.bookings set status = 'approved' where id = %L$q$, v_booking)) = '23514',
    'den gamle godkendelse kan ikke genbruges');
end $$;

-- ---------- 7. Krav om to forskellige personer ----------
reset role;
update public.organizations set require_two_approvers = true where id = '00000000-0000-4000-a000-000000000001';
select test.login('00000000-0000-4000-a000-0000000000a2');
do $$
declare v_approval uuid := (select id from public.approvals where booking_id = '00000000-0000-4000-a000-000000000121' and status = 'pending');
begin
  perform public.tap_approval(v_approval);
  perform test.ok(test.error_of(format('select public.tap_approval(%L)', v_approval)) = '23514', 'samme person kan ikke trykke to gange, når to personer kræves');
end $$;
select test.login('00000000-0000-4000-a000-0000000000a1');
do $$
declare v_approval uuid := (select id from public.approvals where booking_id = '00000000-0000-4000-a000-000000000121' and status = 'first_tap');
begin
  perform public.tap_approval(v_approval);
  perform test.ok((select status from public.bookings where id = '00000000-0000-4000-a000-000000000121') = 'approved', 'en anden person kan give andet tryk');
end $$;
reset role;
update public.organizations set require_two_approvers = false where id = '00000000-0000-4000-a000-000000000001';

-- ---------- 8. Butlerens besked til gæsten kræver også to tryk ----------
select test.login('00000000-0000-4000-a000-0000000000a2');
do $$
declare v_msg uuid := '00000000-0000-4000-a000-000000000112'; v_approval uuid;
begin
  select id into v_approval from public.approvals where message_id = v_msg and status = 'pending';
  perform test.ok(v_approval is not null, 'en AI-kladde får automatisk en ventende godkendelse');
  perform test.ok(test.error_of(format($q$update public.messages set status = 'sent' where id = %L$q$, v_msg)) = '23514', 'en AI-kladde kan ikke sendes uden godkendelse');
  perform test.ok(test.error_of(format($q$update public.messages set status = 'approved' where id = %L$q$, v_msg)) = '23514', 'en AI-kladde kan ikke godkendes uden to tryk');

  update public.messages set body = 'Det ordner jeg. Kokken kommer kl. 19:30.' where id = v_msg;
  perform test.ok((select was_edited from public.messages where id = v_msg)
    and (select ai_suggested_body from public.messages where id = v_msg) like 'Det arrangerer jeg gerne%', 'vi gemmer både AI-forslaget og at mennesket rettede det');

  perform public.tap_approval(v_approval);
  perform public.tap_approval(v_approval);
  perform test.ok((select status from public.messages where id = v_msg) = 'approved', 'efter to tryk er beskeden godkendt');
  perform test.ok(test.error_of(format($q$update public.messages set body = 'ændret bagefter' where id = %L$q$, v_msg)) = '23514', 'teksten kan ikke ændres efter godkendelse');
  update public.messages set status = 'sent' where id = v_msg;
  perform test.ok((select sent_at from public.messages where id = v_msg) is not null, 'en godkendt besked kan sendes');
end $$;

-- ---------- 9. Afvisning ----------
do $$
declare v_booking uuid; v_approval uuid;
begin
  insert into public.bookings (organization_id, villa_id, stay_id, service_id, scheduled_start, guest_price_cents)
  values ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-0000000000b1', '00000000-0000-4000-a000-0000000000f1',
          '00000000-0000-4000-a000-0000000000c4', now() + interval '9 days', 95000)
  returning id into v_booking;
  select id into v_approval from public.approvals where booking_id = v_booking;
  perform public.reject_approval(v_approval, 'For dyrt til denne gæst');
  perform test.ok((select status from public.bookings where id = v_booking) = 'rejected'
    and (select rejected_by from public.approvals where id = v_approval) = '00000000-0000-4000-a000-0000000000a2', 'afvisning lukker bestillingen og gemmer hvem der afviste');
end $$;

rollback;
