-- Testdata: organisation B (en helt anden kunde) med sin egen bruger og et sæt rækker
-- i alle vigtige tabeller, plus en bruger uden nogen organisation.
begin;

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-b000-0000000000a1', 'owner@other.treatr.test', '{"full_name": "Bente B-Ejer"}'),
  ('00000000-0000-4000-b000-0000000000a2', 'second@other.treatr.test', '{"full_name": "Birk B-Backoffice"}'),
  ('00000000-0000-4000-c000-0000000000a1', 'nobody@nowhere.treatr.test', '{"full_name": "Ingen Organisation"}');

insert into public.organizations (id, name, slug) values ('00000000-0000-4000-b000-000000000001', 'Other Agency', 'other');
insert into public.organization_members (organization_id, user_id, role) values
  ('00000000-0000-4000-b000-000000000001', '00000000-0000-4000-b000-0000000000a1', 'owner'),
  ('00000000-0000-4000-b000-000000000001', '00000000-0000-4000-b000-0000000000a2', 'back_office');

insert into public.villas (id, organization_id, name, slug) values
  ('00000000-0000-4000-b000-0000000000b1', '00000000-0000-4000-b000-000000000001', 'Villa B Secreta', 'villa-b');
insert into public.villa_amenities (organization_id, villa_id, key, name_i18n) values
  ('00000000-0000-4000-b000-000000000001', '00000000-0000-4000-b000-0000000000b1', 'pool', '{"en": "Pool"}');
insert into public.services (id, organization_id, category, name_i18n, default_price_cents) values
  ('00000000-0000-4000-b000-0000000000c1', '00000000-0000-4000-b000-000000000001', 'chef', '{"en": "B chef"}', 10000);
insert into public.villa_services (organization_id, villa_id, service_id) values
  ('00000000-0000-4000-b000-000000000001', '00000000-0000-4000-b000-0000000000b1', '00000000-0000-4000-b000-0000000000c1');
insert into public.suppliers (id, organization_id, name) values
  ('00000000-0000-4000-b000-0000000000d1', '00000000-0000-4000-b000-000000000001', 'B Supplier');
insert into public.supplier_services (organization_id, supplier_id, service_id) values
  ('00000000-0000-4000-b000-000000000001', '00000000-0000-4000-b000-0000000000d1', '00000000-0000-4000-b000-0000000000c1');
insert into public.guests (id, organization_id, full_name, email) values
  ('00000000-0000-4000-b000-0000000000e1', '00000000-0000-4000-b000-000000000001', 'Hemmelig B-Gæst', 'secret@guests.treatr.test');
insert into public.stays (id, organization_id, villa_id, primary_guest_id, check_in, check_out) values
  ('00000000-0000-4000-b000-0000000000f1', '00000000-0000-4000-b000-000000000001', '00000000-0000-4000-b000-0000000000b1',
   '00000000-0000-4000-b000-0000000000e1', current_date + 1, current_date + 5);
insert into public.conversations (id, organization_id, villa_id, stay_id, guest_id) values
  ('00000000-0000-4000-b000-000000000101', '00000000-0000-4000-b000-000000000001', '00000000-0000-4000-b000-0000000000b1',
   '00000000-0000-4000-b000-0000000000f1', '00000000-0000-4000-b000-0000000000e1');
insert into public.messages (id, organization_id, conversation_id, sender_type, status, body) values
  ('00000000-0000-4000-b000-000000000111', '00000000-0000-4000-b000-000000000001', '00000000-0000-4000-b000-000000000101', 'guest', 'received', 'B: privat besked'),
  ('00000000-0000-4000-b000-000000000112', '00000000-0000-4000-b000-000000000001', '00000000-0000-4000-b000-000000000101', 'butler_ai', 'draft', 'B: AI-kladde');
insert into public.upsell_offers (organization_id, stay_id, service_id, price_cents) values
  ('00000000-0000-4000-b000-000000000001', '00000000-0000-4000-b000-0000000000f1', '00000000-0000-4000-b000-0000000000c1', 10000);
insert into public.bookings (id, organization_id, villa_id, stay_id, service_id, supplier_id, scheduled_start, guest_price_cents) values
  ('00000000-0000-4000-b000-000000000121', '00000000-0000-4000-b000-000000000001', '00000000-0000-4000-b000-0000000000b1',
   '00000000-0000-4000-b000-0000000000f1', '00000000-0000-4000-b000-0000000000c1', '00000000-0000-4000-b000-0000000000d1', now() + interval '2 days', 10000);
insert into public.payments (organization_id, booking_id, direction, amount_cents) values
  ('00000000-0000-4000-b000-000000000001', '00000000-0000-4000-b000-000000000121', 'guest_payment', 10000);
insert into public.commissions (organization_id, booking_id, kind, rate_bps, base_cents, amount_cents) values
  ('00000000-0000-4000-b000-000000000001', '00000000-0000-4000-b000-000000000121', 'supplier_commission', 1000, 10000, 1000);
insert into public.notifications (organization_id, recipient_type, recipient_user_id, channel, template_key) values
  ('00000000-0000-4000-b000-000000000001', 'staff', '00000000-0000-4000-b000-0000000000a1', 'in_app', 'booking.needs_approval');
insert into public.gdpr_requests (organization_id, guest_id, request_type) values
  ('00000000-0000-4000-b000-000000000001', '00000000-0000-4000-b000-0000000000e1', 'erasure');
insert into public.devices (id, organization_id, villa_id, kind, name) values
  ('00000000-0000-4000-b000-000000000131', '00000000-0000-4000-b000-000000000001', '00000000-0000-4000-b000-0000000000b1', 'home_assistant', 'B HA');
insert into public.home_events (organization_id, villa_id, device_id, event_type, occurred_at) values
  ('00000000-0000-4000-b000-000000000001', '00000000-0000-4000-b000-0000000000b1', '00000000-0000-4000-b000-000000000131', 'door.opened', now());

-- Organisation A (seed) får også en betaling, så vi kan teste at concierge ikke ser penge.
insert into public.payments (organization_id, booking_id, direction, amount_cents) values
  ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000121', 'guest_payment', 57000);

commit;
