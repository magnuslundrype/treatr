-- Demo-data: én organisation med én villa. Kører ved `supabase db reset` (lokalt)
-- og når en preview branch oprettes. Kører ALDRIG i produktion.
-- Alt her er opdigtet. Læg aldrig rigtige gæster, priser eller leverandører i denne fil.
--
-- Demo-logins (kun lokalt og i previews, kodeord: treatr-demo):
--   owner@demo.treatr.test       ejer
--   backoffice@demo.treatr.test  back office
--   concierge@demo.treatr.test   concierge

-- ---------- Medarbejdere (Supabase Auth) ----------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
)
select
  '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email,
  crypt('treatr-demo', gen_salt('bf')), now(),
  '{"provider": "email", "providers": ["email"]}'::jsonb,
  jsonb_build_object('full_name', u.full_name), now(), now(), '', '', '', ''
from (values
  ('00000000-0000-4000-a000-0000000000a1'::uuid, 'owner@demo.treatr.test', 'Olivia Ejer'),
  ('00000000-0000-4000-a000-0000000000a2'::uuid, 'backoffice@demo.treatr.test', 'Bo Backoffice'),
  ('00000000-0000-4000-a000-0000000000a3'::uuid, 'concierge@demo.treatr.test', 'Carmen Concierge')
) as u (id, email, full_name);

insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), u.id, u.id::text, jsonb_build_object('sub', u.id::text, 'email', u.email), 'email', now(), now(), now()
from auth.users u
where u.email like '%@demo.treatr.test';

-- ---------- Organisation og roller ----------
insert into public.organizations (id, name, slug, default_locale)
values ('00000000-0000-4000-a000-000000000001', 'Demo Villas', 'demo', 'en');

insert into public.organization_members (organization_id, user_id, role) values
  ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-0000000000a1', 'owner'),
  ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-0000000000a2', 'back_office'),
  ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-0000000000a3', 'concierge');

-- ---------- Villa og faciliteter ----------
insert into public.villas (id, organization_id, name, slug, address_line, city, region, bedrooms, max_guests, description_i18n, house_rules_i18n)
values (
  '00000000-0000-4000-a000-0000000000b1', '00000000-0000-4000-a000-000000000001',
  'Villa Demo Sol', 'villa-demo-sol', 'Calle Ejemplo 1', 'Marbella', 'Andalucía', 5, 10,
  '{"es": "Villa de lujo con piscina y vistas al mar.", "en": "Luxury villa with pool and sea view.", "da": "Luksusvilla med pool og havudsigt."}',
  '{"es": "Sin fiestas después de las 23:00.", "en": "No parties after 23:00.", "da": "Ingen fester efter kl. 23."}'
);

insert into public.villa_amenities (organization_id, villa_id, key, name_i18n, details_i18n, sort_order) values
  ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-0000000000b1', 'pool',
   '{"es": "Piscina climatizada", "en": "Heated pool", "da": "Opvarmet pool"}',
   '{"en": "Heating takes 24 hours. Ask the butler the day before.", "da": "Opvarmning tager 24 timer. Spørg butleren dagen før."}', 1),
  ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-0000000000b1', 'wifi',
   '{"es": "Wifi", "en": "Wifi", "da": "Wifi"}',
   '{"en": "Network: VillaDemo. The password is on the card in the kitchen.", "da": "Netværk: VillaDemo. Koden står på kortet i køkkenet."}', 2),
  ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-0000000000b1', 'bbq',
   '{"es": "Barbacoa de gas", "en": "Gas barbecue", "da": "Gasgrill"}', '{}', 3),
  ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-0000000000b1', 'parking',
   '{"es": "Aparcamiento para 3 coches", "en": "Parking for 3 cars", "da": "Parkering til 3 biler"}', '{}', 4);

-- ---------- Servicekatalog ----------
insert into public.services (id, organization_id, category, name_i18n, description_i18n, default_price_cents, price_unit, lead_time_hours, upsell_eligible) values
  ('00000000-0000-4000-a000-0000000000c1', '00000000-0000-4000-a000-000000000001', 'chef',
   '{"es": "Chef privado", "en": "Private chef dinner", "da": "Privat kok til middag"}',
   '{"en": "Three-course dinner cooked in the villa.", "da": "Tre-retters middag lavet i villaen."}', 9500, 'per_person', 48, true),
  ('00000000-0000-4000-a000-0000000000c2', '00000000-0000-4000-a000-000000000001', 'transport',
   '{"es": "Traslado al aeropuerto", "en": "Airport transfer", "da": "Lufthavnstransport"}',
   '{"en": "Málaga airport to the villa, up to 7 people.", "da": "Málaga lufthavn til villaen, op til 7 personer."}', 14000, 'fixed', 24, false),
  ('00000000-0000-4000-a000-0000000000c3', '00000000-0000-4000-a000-000000000001', 'cleaning',
   '{"es": "Limpieza extra", "en": "Extra cleaning", "da": "Ekstra rengøring"}', '{}', 12000, 'fixed', 24, true),
  ('00000000-0000-4000-a000-0000000000c4', '00000000-0000-4000-a000-000000000001', 'experience',
   '{"es": "Paseo en barco", "en": "Private boat trip", "da": "Privat bådtur"}',
   '{"en": "Four hours with skipper from Puerto Banús.", "da": "Fire timer med skipper fra Puerto Banús."}', 85000, 'fixed', 72, true),
  ('00000000-0000-4000-a000-0000000000c5', '00000000-0000-4000-a000-000000000001', 'shopping',
   '{"es": "Compra antes de la llegada", "en": "Pre-arrival shopping", "da": "Indkøb før ankomst"}',
   '{"en": "We fill the fridge before you arrive. Groceries are billed at cost.", "da": "Vi fylder køleskabet før I kommer. Varerne afregnes til kostpris."}', 6000, 'fixed', 48, true);

-- Alle services tilbydes i villaen. Bådturen er dyrere her end standardprisen.
insert into public.villa_services (organization_id, villa_id, service_id, price_cents)
select s.organization_id, '00000000-0000-4000-a000-0000000000b1', s.id,
       case when s.id = '00000000-0000-4000-a000-0000000000c4' then 95000 end
from public.services s
where s.organization_id = '00000000-0000-4000-a000-000000000001';

-- ---------- Leverandører ----------
insert into public.suppliers (id, organization_id, name, contact_name, email, phone, preferred_channel, locale, commission_rate_bps) values
  ('00000000-0000-4000-a000-0000000000d1', '00000000-0000-4000-a000-000000000001', 'Chef Demo Marbella', 'Lucía Ejemplo', 'chef@suppliers.treatr.test', '+34600000001', 'whatsapp', 'es', 1500),
  ('00000000-0000-4000-a000-0000000000d2', '00000000-0000-4000-a000-000000000001', 'Traslados Demo', 'Javier Ejemplo', 'taxi@suppliers.treatr.test', '+34600000002', 'whatsapp', 'es', 1000),
  ('00000000-0000-4000-a000-0000000000d3', '00000000-0000-4000-a000-000000000001', 'Limpieza Demo', 'María Ejemplo', 'clean@suppliers.treatr.test', '+34600000003', 'sms', 'es', 0);

insert into public.supplier_services (organization_id, supplier_id, service_id, villa_id, cost_cents, priority) values
  ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-0000000000d1', '00000000-0000-4000-a000-0000000000c1', null, 7000, 1),
  ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-0000000000d2', '00000000-0000-4000-a000-0000000000c2', null, 9000, 1),
  ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-0000000000d3', '00000000-0000-4000-a000-0000000000c3', '00000000-0000-4000-a000-0000000000b1', 8000, 1);

-- ---------- En gæst, et ophold og en samtale ----------
insert into public.guests (id, organization_id, full_name, email, phone, locale)
values ('00000000-0000-4000-a000-0000000000e1', '00000000-0000-4000-a000-000000000001', 'Greta Demo-Gæst', 'greta@guests.treatr.test', '+4500000000', 'da');

insert into public.stays (id, organization_id, villa_id, primary_guest_id, check_in, check_out, party_size, status)
values ('00000000-0000-4000-a000-0000000000f1', '00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-0000000000b1',
        '00000000-0000-4000-a000-0000000000e1', current_date + 7, current_date + 14, 6, 'upcoming');

insert into public.conversations (id, organization_id, villa_id, stay_id, guest_id, channel, locale)
values ('00000000-0000-4000-a000-000000000101', '00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-0000000000b1',
        '00000000-0000-4000-a000-0000000000f1', '00000000-0000-4000-a000-0000000000e1', 'web', 'da');

insert into public.messages (id, organization_id, conversation_id, sender_type, status, body, locale)
values ('00000000-0000-4000-a000-000000000111', '00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000101',
        'guest', 'received', 'Hej! Kan vi få en kok til at lave middag til 6 den første aften?', 'da');

-- Butlerens forslag til svar: en kladde, der venter på to tryk i back office.
insert into public.messages (id, organization_id, conversation_id, sender_type, status, body, locale, ai_model)
values ('00000000-0000-4000-a000-000000000112', '00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000101',
        'butler_ai', 'draft', 'Det arrangerer jeg gerne. En privat kok til 6 personer koster 570 EUR. Skal jeg bestille til kl. 19:30?', 'da', 'demo');

-- Butlerens forslag til bestilling: også et forslag, der venter på to tryk.
insert into public.bookings (id, organization_id, villa_id, stay_id, service_id, supplier_id, conversation_id, source,
                             scheduled_start, quantity, party_size, guest_notes, supplier_notes, guest_price_cents, supplier_cost_cents)
values ('00000000-0000-4000-a000-000000000121', '00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-0000000000b1',
        '00000000-0000-4000-a000-0000000000f1', '00000000-0000-4000-a000-0000000000c1', '00000000-0000-4000-a000-0000000000d1',
        '00000000-0000-4000-a000-000000000101', 'guest_request',
        (current_date + 7) + time '19:30', 6, 6, 'Én vegetar.', 'Cena para 6 personas, 1 vegetariano.', 57000, 42000);

-- Et mersalgstilbud, som butleren har foreslået.
insert into public.upsell_offers (organization_id, stay_id, service_id, conversation_id, trigger_kind, variant, pitch, price_cents)
values ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-0000000000f1', '00000000-0000-4000-a000-0000000000c5',
        '00000000-0000-4000-a000-000000000101', 'pre_arrival', 'fridge-v1',
        'Skal vi fylde køleskabet, før I lander?', 6000);
