-- =====================================================================
-- Treatr 0001_init: hele datamodellen for den fulde idé
-- =====================================================================
-- Læs docs/erd.md for diagram og docs/adr/ for begrundelser.
--
-- Grundregler i dette skema (tjekkes af supabase/tests/ i CI):
--   1. Alle tabeller har organization_id og RLS slået til. Ingen undtagelser.
--   2. Rollen `anon` har ingen rettigheder overhovedet. Gæster og leverandører
--      logger ikke ind; de går gennem vores server med et token (ADR-0006).
--   3. Sammensatte fremmednøgler (organization_id, x_id) gør det umuligt at
--      pege på en række i en anden organisation, også for serverkode.
--   4. Statusskift på bestillinger styres af en trigger, ikke af app-kode.
--   5. Penge er heltal i cent. Tekster til gæster er jsonb {"es","en","da"}.
--
-- Rediger aldrig denne fil efter den er merget. Lav en ny migration.
-- =====================================================================

create schema if not exists private;
revoke all on schema private from public;

-- ---------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------
create type public.org_role as enum ('owner', 'back_office', 'concierge');
create type public.locale_code as enum ('es', 'en', 'da');
create type public.actor_type as enum ('staff', 'guest', 'supplier', 'ai', 'system');

create type public.stay_status as enum ('upcoming', 'in_house', 'completed', 'cancelled');

create type public.conversation_channel as enum ('web', 'whatsapp', 'sms', 'email', 'tablet');
create type public.conversation_status as enum ('open', 'closed');
create type public.message_sender as enum ('guest', 'butler_ai', 'staff', 'system');
-- received: fra gæsten. draft: AI-forslag der venter på et menneske.
create type public.message_status as enum ('received', 'draft', 'approved', 'sent', 'failed', 'discarded');

create type public.service_category as enum ('chef', 'transport', 'cleaning', 'experience', 'shopping', 'other');
create type public.price_unit as enum ('fixed', 'per_person', 'per_hour', 'per_day');

-- Statusmaskinen: forslag → godkendt → sendt → bekræftet → leveret → afregnet
create type public.booking_status as enum (
  'proposed',            -- forslag (fra AI, gæst eller medarbejder)
  'approved',            -- godkendt med to tryk i back office
  'sent',                -- sendt til leverandør med bekræftelseslink
  'supplier_confirmed',  -- leverandøren har sagt ja
  'supplier_declined',   -- leverandøren har sagt nej (kan foreslås igen)
  'delivered',           -- ydelsen er leveret
  'settled',             -- afregnet (slutstatus)
  'rejected',            -- afvist i back office (slutstatus)
  'cancelled'            -- annulleret (slutstatus)
);
create type public.booking_source as enum ('guest_request', 'upsell', 'staff');

create type public.approval_subject as enum ('booking', 'message');
create type public.approval_status as enum ('pending', 'first_tap', 'approved', 'rejected', 'superseded');

create type public.upsell_status as enum ('suggested', 'dismissed', 'shown', 'accepted', 'declined', 'expired');

create type public.payment_direction as enum ('guest_payment', 'supplier_payout', 'refund');
create type public.payment_status as enum ('pending', 'paid', 'failed', 'refunded', 'cancelled');
create type public.commission_kind as enum ('supplier_commission', 'platform_fee');
create type public.commission_status as enum ('accrued', 'invoiced', 'settled', 'void');

create type public.recipient_type as enum ('staff', 'guest', 'supplier');
create type public.notification_channel as enum ('in_app', 'email', 'sms', 'whatsapp', 'push');
create type public.notification_status as enum ('queued', 'sent', 'delivered', 'failed', 'read', 'cancelled');

create type public.gdpr_request_type as enum ('erasure', 'export');
create type public.device_kind as enum ('mac_mini', 'tablet', 'home_assistant', 'other');

-- ---------------------------------------------------------------------
-- Små hjælpefunktioner
-- ---------------------------------------------------------------------

-- Oversat tekst: et jsonb-objekt med kun nøglerne es, en, da.
create function public.is_i18n(t jsonb) returns boolean
language sql immutable
as $$ select jsonb_typeof(t) = 'object' and (t - array['es', 'en', 'da']) = '{}'::jsonb $$;

-- Hent tekst på et sprog. Fallback: ønsket sprog → en → es → da.
create function public.i18n(t jsonb, loc text) returns text
language sql immutable
as $$ select coalesce(nullif(t ->> loc, ''), nullif(t ->> 'en', ''), nullif(t ->> 'es', ''), nullif(t ->> 'da', '')) $$;

create function private.set_updated_at() returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- Hvem handler lige nu? Serverfunktioner kan sætte treatr.actor lokalt i transaktionen.
create function private.current_actor() returns public.actor_type
language sql stable
set search_path = ''
as $$
  select coalesce(
    nullif(current_setting('treatr.actor', true), '')::public.actor_type,
    case when (select auth.uid()) is not null then 'staff'::public.actor_type
         else 'system'::public.actor_type end
  )
$$;

-- ---------------------------------------------------------------------
-- Organisationer, profiler og roller
-- ---------------------------------------------------------------------
create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9-]{1,48}$'),
  default_locale public.locale_code not null default 'en',
  timezone text not null default 'Europe/Madrid',
  currency char(3) not null default 'EUR',
  -- GDPR: gæstedata anonymiseres så mange dage efter udtjekning.
  guest_data_retention_days int not null default 30 check (guest_data_retention_days between 0 and 3650),
  -- false: samme person må trykke begge gange. true: der kræves to forskellige personer.
  require_two_approvers boolean not null default false,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Én række pr. medarbejder-login. Oprettes automatisk når en bruger oprettes i Supabase Auth.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  locale public.locale_code not null default 'en',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.org_role not null,
  created_at timestamptz not null default now(),
  unique (organization_id, user_id)
);
create index organization_members_user_idx on public.organization_members (user_id);

-- RLS-hjælpere. Ligger i `private`, som ikke er udstillet i API'et.
-- security definer: de læser medlemskaber uden selv at blive fanget af RLS.
create function private.member_org_ids() returns setof uuid
language sql stable security definer
set search_path = ''
as $$
  select m.organization_id from public.organization_members m
  where m.user_id = (select auth.uid())
$$;

create function private.manager_org_ids() returns setof uuid
language sql stable security definer
set search_path = ''
as $$
  select m.organization_id from public.organization_members m
  where m.user_id = (select auth.uid()) and m.role in ('owner', 'back_office')
$$;

create function private.owner_org_ids() returns setof uuid
language sql stable security definer
set search_path = ''
as $$
  select m.organization_id from public.organization_members m
  where m.user_id = (select auth.uid()) and m.role = 'owner'
$$;

create function private.co_member_ids() returns setof uuid
language sql stable security definer
set search_path = ''
as $$
  select m2.user_id
  from public.organization_members m1
  join public.organization_members m2 on m2.organization_id = m1.organization_id
  where m1.user_id = (select auth.uid())
$$;

-- Profil oprettes automatisk ved ny bruger.
create function private.handle_new_user() returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- En organisation må aldrig stå uden ejer.
create function private.protect_last_owner() returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if old.role = 'owner'
     and (tg_op = 'DELETE' or new.role <> 'owner' or new.organization_id <> old.organization_id)
     and exists (select 1 from public.organizations o where o.id = old.organization_id)
     and not exists (
       select 1 from public.organization_members m
       where m.organization_id = old.organization_id and m.role = 'owner' and m.id <> old.id
     ) then
    raise exception 'Organisationen skal have mindst én ejer' using errcode = 'check_violation';
  end if;
  return coalesce(new, old);
end $$;

create trigger organization_members_protect_last_owner
  before update or delete on public.organization_members
  for each row execute function private.protect_last_owner();

-- ---------------------------------------------------------------------
-- Villaer og faciliteter
-- ---------------------------------------------------------------------
create table public.villas (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  name text not null,
  slug text not null check (slug ~ '^[a-z0-9][a-z0-9-]{1,48}$'),
  address_line text,
  city text,
  region text,
  country char(2) not null default 'ES',
  timezone text not null default 'Europe/Madrid',
  bedrooms int check (bedrooms >= 0),
  max_guests int check (max_guests > 0),
  description_i18n jsonb not null default '{}' check (public.is_i18n(description_i18n)),
  house_rules_i18n jsonb not null default '{}' check (public.is_i18n(house_rules_i18n)),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, slug),
  unique (organization_id, id)
);

-- Faciliteter og praktisk viden om huset. Det er butlerens "husmanual".
create table public.villa_amenities (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  villa_id uuid not null,
  key text not null check (key ~ '^[a-z0-9_]{1,40}$'),  -- fx pool, wifi, bbq
  name_i18n jsonb not null check (public.is_i18n(name_i18n)),
  details_i18n jsonb not null default '{}' check (public.is_i18n(details_i18n)),
  guest_visible boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (villa_id, key),
  foreign key (organization_id, villa_id) references public.villas (organization_id, id) on delete cascade
);
create index villa_amenities_org_idx on public.villa_amenities (organization_id);

-- ---------------------------------------------------------------------
-- Gæster og ophold
-- ---------------------------------------------------------------------
create table public.guests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  full_name text not null,
  email text,
  phone text,
  locale public.locale_code not null default 'en',
  notes text,
  marketing_consent boolean not null default false,
  anonymized_at timestamptz,   -- sat af GDPR-sletning; persondata er væk
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id)
);
create index guests_org_email_idx on public.guests (organization_id, lower(email));

create table public.stays (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  villa_id uuid not null,
  primary_guest_id uuid not null,
  check_in date not null,
  check_out date not null,
  party_size int check (party_size > 0),
  status public.stay_status not null default 'upcoming',
  external_ref text,              -- reference fra udlejningsplatform/bureau
  notes text,
  guest_token_hash text unique,   -- sha256 af gæstens chat-link. Rå token gemmes aldrig.
  purged_at timestamptz,          -- sat når gæstedata for opholdet er anonymiseret
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (check_out > check_in),
  unique (organization_id, id),
  foreign key (organization_id, villa_id) references public.villas (organization_id, id),
  foreign key (organization_id, primary_guest_id) references public.guests (organization_id, id)
);
create index stays_villa_dates_idx on public.stays (villa_id, check_in, check_out);
create index stays_guest_idx on public.stays (primary_guest_id);
create index stays_org_checkout_idx on public.stays (organization_id, check_out) where purged_at is null;

-- ---------------------------------------------------------------------
-- Servicekatalog, priser pr. villa, leverandører
-- ---------------------------------------------------------------------
create table public.services (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  category public.service_category not null,
  name_i18n jsonb not null check (public.is_i18n(name_i18n) and name_i18n <> '{}'),
  description_i18n jsonb not null default '{}' check (public.is_i18n(description_i18n)),
  default_price_cents int not null check (default_price_cents >= 0),
  price_unit public.price_unit not null default 'fixed',
  currency char(3) not null default 'EUR',
  lead_time_hours int not null default 24 check (lead_time_hours >= 0),
  upsell_eligible boolean not null default false,  -- må butleren foreslå den uopfordret?
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id)
);
create index services_org_category_idx on public.services (organization_id, category) where active;

-- Hvilke services tilbydes i hvilken villa, og til hvilken pris.
create table public.villa_services (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  villa_id uuid not null,
  service_id uuid not null,
  price_cents int check (price_cents >= 0),  -- null = brug services.default_price_cents
  available boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (villa_id, service_id),
  foreign key (organization_id, villa_id) references public.villas (organization_id, id) on delete cascade,
  foreign key (organization_id, service_id) references public.services (organization_id, id) on delete cascade
);
create index villa_services_service_idx on public.villa_services (service_id);
create index villa_services_org_idx on public.villa_services (organization_id);

create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  name text not null,
  contact_name text,
  email text,
  phone text,
  preferred_channel public.notification_channel not null default 'whatsapp',
  locale public.locale_code not null default 'es',
  tax_id text,
  commission_rate_bps int not null default 0 check (commission_rate_bps between 0 and 10000),
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id)
);

-- Hvad en leverandør tilbyder, evt. kun i én villa, og hvad det koster os.
create table public.supplier_services (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  supplier_id uuid not null,
  service_id uuid not null,
  villa_id uuid,                              -- null = alle villaer
  cost_cents int check (cost_cents >= 0),
  priority int not null default 1,            -- 1 = spørg denne først
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique nulls not distinct (supplier_id, service_id, villa_id),
  foreign key (organization_id, supplier_id) references public.suppliers (organization_id, id) on delete cascade,
  foreign key (organization_id, service_id) references public.services (organization_id, id) on delete cascade,
  foreign key (organization_id, villa_id) references public.villas (organization_id, id) on delete cascade
);
create index supplier_services_service_idx on public.supplier_services (service_id, priority);
create index supplier_services_org_idx on public.supplier_services (organization_id);
create index supplier_services_villa_idx on public.supplier_services (villa_id);

-- ---------------------------------------------------------------------
-- Samtaler og beskeder med butleren
-- ---------------------------------------------------------------------
create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  villa_id uuid not null,
  stay_id uuid,
  guest_id uuid not null,
  channel public.conversation_channel not null default 'web',
  status public.conversation_status not null default 'open',
  locale public.locale_code not null default 'en',
  assigned_to uuid references public.profiles (id) on delete set null,
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, villa_id) references public.villas (organization_id, id),
  foreign key (organization_id, stay_id) references public.stays (organization_id, id),
  foreign key (organization_id, guest_id) references public.guests (organization_id, id)
);
create index conversations_inbox_idx on public.conversations (organization_id, status, last_message_at desc);
create index conversations_stay_idx on public.conversations (stay_id);
create index conversations_guest_idx on public.conversations (guest_id);
create index conversations_villa_idx on public.conversations (villa_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  conversation_id uuid not null,
  sender_type public.message_sender not null,
  sender_user_id uuid references public.profiles (id) on delete set null,
  status public.message_status not null,
  body text not null,                 -- den endelige tekst (det gæsten ser, når status = sent)
  locale public.locale_code,
  -- AI-forslag og hvad mennesket rettede:
  ai_suggested_body text,             -- butlerens oprindelige forslag, ændres aldrig
  was_edited boolean not null default false,  -- sand hvis mennesket rettede forslaget
  ai_model text,
  ai_meta jsonb not null default '{}',        -- fx tokens, prompt-version, fundne intentioner
  sent_at timestamptz,
  redacted_at timestamptz,            -- sat af GDPR-sletning; body er tømt
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, conversation_id) references public.conversations (organization_id, id) on delete cascade
);
create index messages_conversation_idx on public.messages (conversation_id, created_at);
create index messages_org_drafts_idx on public.messages (organization_id, created_at) where status = 'draft';

-- ---------------------------------------------------------------------
-- Mersalg
-- ---------------------------------------------------------------------
create table public.upsell_offers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  stay_id uuid not null,
  service_id uuid not null,
  conversation_id uuid,
  message_id uuid,                    -- beskeden hvor tilbuddet blev vist
  trigger_kind text not null default 'in_conversation'
    check (trigger_kind in ('pre_arrival', 'arrival_day', 'mid_stay', 'in_conversation', 'home_event')),
  variant text,                       -- hvilken formulering/eksperiment (til "hvad virkede")
  pitch text,                         -- den konkrete tekst; slettes ved GDPR-anonymisering
  price_cents int not null check (price_cents >= 0),
  currency char(3) not null default 'EUR',
  status public.upsell_status not null default 'suggested',
  ai_model text,
  suggested_at timestamptz not null default now(),
  shown_at timestamptz,
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, stay_id) references public.stays (organization_id, id),
  foreign key (organization_id, service_id) references public.services (organization_id, id),
  foreign key (organization_id, conversation_id) references public.conversations (organization_id, id),
  foreign key (organization_id, message_id) references public.messages (organization_id, id)
);
create index upsell_offers_stay_idx on public.upsell_offers (stay_id);
create index upsell_offers_stats_idx on public.upsell_offers (organization_id, service_id, trigger_kind, status);
create index upsell_offers_conversation_idx on public.upsell_offers (conversation_id);
create index upsell_offers_message_idx on public.upsell_offers (message_id);

-- ---------------------------------------------------------------------
-- Bestillinger og statusmaskine
-- ---------------------------------------------------------------------
create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  villa_id uuid not null,
  stay_id uuid not null,
  service_id uuid not null,
  supplier_id uuid,                   -- skal være sat før bestillingen kan sendes
  conversation_id uuid,
  upsell_offer_id uuid,               -- sat hvis bestillingen kom fra et mersalgstilbud
  source public.booking_source not null default 'guest_request',
  status public.booking_status not null default 'proposed',
  scheduled_start timestamptz not null,
  scheduled_end timestamptz,
  quantity int not null default 1 check (quantity > 0),
  party_size int check (party_size > 0),
  details jsonb not null default '{}',   -- fri struktur, fx menu eller flynummer (kan indeholde persondata)
  guest_notes text,                      -- gæstens ønsker (kan indeholde persondata, fx allergier)
  supplier_notes text,                   -- det leverandøren ser på bekræftelsessiden (kan indeholde persondata)
  internal_notes text,
  guest_price_cents int not null check (guest_price_cents >= 0),
  supplier_cost_cents int not null default 0 check (supplier_cost_cents >= 0),
  margin_cents int generated always as (guest_price_cents - supplier_cost_cents) stored,
  currency char(3) not null default 'EUR',
  proposed_at timestamptz not null default now(),
  approved_at timestamptz,
  sent_at timestamptz,
  supplier_responded_at timestamptz,
  delivered_at timestamptz,
  settled_at timestamptz,
  closed_at timestamptz,                 -- afvist eller annulleret
  cancel_reason text,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (scheduled_end is null or scheduled_end > scheduled_start),
  unique (organization_id, id),
  foreign key (organization_id, villa_id) references public.villas (organization_id, id),
  foreign key (organization_id, stay_id) references public.stays (organization_id, id),
  foreign key (organization_id, service_id) references public.services (organization_id, id),
  foreign key (organization_id, supplier_id) references public.suppliers (organization_id, id),
  foreign key (organization_id, conversation_id) references public.conversations (organization_id, id),
  foreign key (organization_id, upsell_offer_id) references public.upsell_offers (organization_id, id)
);
create index bookings_org_status_idx on public.bookings (organization_id, status, scheduled_start);
create index bookings_stay_idx on public.bookings (stay_id);
create index bookings_villa_idx on public.bookings (villa_id, scheduled_start);
create index bookings_supplier_idx on public.bookings (supplier_id, scheduled_start);
create index bookings_service_idx on public.bookings (service_id);
create index bookings_conversation_idx on public.bookings (conversation_id);
create index bookings_upsell_idx on public.bookings (upsell_offer_id);

-- Historik over alle statusskift. Skrives kun af trigger.
create table public.booking_status_events (
  id bigint generated always as identity primary key,
  organization_id uuid not null,
  booking_id uuid not null,
  from_status public.booking_status,
  to_status public.booking_status not null,
  actor_type public.actor_type not null,
  actor_user_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  foreign key (organization_id, booking_id) references public.bookings (organization_id, id) on delete cascade
);
create index booking_status_events_booking_idx on public.booking_status_events (booking_id, created_at);
create index booking_status_events_org_idx on public.booking_status_events (organization_id);

-- ---------------------------------------------------------------------
-- Godkendelser med to tryk
-- ---------------------------------------------------------------------
-- Oprettes automatisk for hver ny bestilling og hvert AI-forslag til gæsten.
-- Ændres kun gennem tap_approval() og reject_approval().
create table public.approvals (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  subject_type public.approval_subject not null,
  booking_id uuid,
  message_id uuid,
  status public.approval_status not null default 'pending',
  first_tap_by uuid references public.profiles (id) on delete set null,
  first_tap_at timestamptz,
  second_tap_by uuid references public.profiles (id) on delete set null,
  second_tap_at timestamptz,
  rejected_by uuid references public.profiles (id) on delete set null,
  rejected_at timestamptz,
  reject_reason text,
  snapshot jsonb,                     -- præcis hvad der blev godkendt (pris, tid, leverandør / tekst)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (subject_type = 'booking' and booking_id is not null and message_id is null)
    or (subject_type = 'message' and message_id is not null and booking_id is null)
  ),
  check (status <> 'approved' or (first_tap_at is not null and second_tap_at is not null)),
  foreign key (organization_id, booking_id) references public.bookings (organization_id, id) on delete cascade,
  foreign key (organization_id, message_id) references public.messages (organization_id, id) on delete cascade
);
-- Højst én åben godkendelse pr. bestilling/besked.
create unique index approvals_open_booking_idx on public.approvals (booking_id) where status in ('pending', 'first_tap');
create unique index approvals_open_message_idx on public.approvals (message_id) where status in ('pending', 'first_tap');
create index approvals_queue_idx on public.approvals (organization_id, created_at) where status in ('pending', 'first_tap');
create index approvals_booking_idx on public.approvals (booking_id);
create index approvals_message_idx on public.approvals (message_id);

-- ---------------------------------------------------------------------
-- Bekræftelseslinks til leverandører (engangs-token, udløb, intet login)
-- ---------------------------------------------------------------------
create table public.confirmation_links (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  booking_id uuid not null,
  supplier_id uuid not null,
  token_hash text not null unique,    -- sha256 i hex. Det rå token findes kun i linket.
  expires_at timestamptz not null,
  used_at timestamptz,
  used_action text check (used_action in ('confirmed', 'declined')),
  used_note text,
  used_ip inet,
  revoked_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  check ((used_at is null) = (used_action is null)),
  foreign key (organization_id, booking_id) references public.bookings (organization_id, id) on delete cascade,
  foreign key (organization_id, supplier_id) references public.suppliers (organization_id, id)
);
create index confirmation_links_booking_idx on public.confirmation_links (booking_id);
create index confirmation_links_supplier_idx on public.confirmation_links (supplier_id);
create index confirmation_links_org_idx on public.confirmation_links (organization_id);

-- ---------------------------------------------------------------------
-- Betalinger og provision (kun struktur, ingen betalingsudbyder endnu)
-- ---------------------------------------------------------------------
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  booking_id uuid not null,
  direction public.payment_direction not null,
  amount_cents int not null check (amount_cents > 0),
  currency char(3) not null default 'EUR',
  status public.payment_status not null default 'pending',
  method text,                        -- fx bank_transfer, cash, card
  provider text,                      -- tom indtil vi vælger betalingsudbyder
  provider_reference text,
  due_at timestamptz,
  paid_at timestamptz,
  note text,
  recorded_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (organization_id, booking_id) references public.bookings (organization_id, id)
);
create index payments_booking_idx on public.payments (booking_id);
create index payments_org_status_idx on public.payments (organization_id, status);

create table public.commissions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  booking_id uuid not null,
  kind public.commission_kind not null,
  rate_bps int not null check (rate_bps between 0 and 10000),
  base_cents int not null check (base_cents >= 0),
  amount_cents int not null check (amount_cents >= 0),
  currency char(3) not null default 'EUR',
  status public.commission_status not null default 'accrued',
  settled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (booking_id, kind),
  foreign key (organization_id, booking_id) references public.bookings (organization_id, id)
);
create index commissions_org_status_idx on public.commissions (organization_id, status);

-- ---------------------------------------------------------------------
-- Notifikationer (udbakke: serveren læser køen og sender)
-- ---------------------------------------------------------------------
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  recipient_type public.recipient_type not null,
  recipient_user_id uuid references public.profiles (id) on delete cascade,
  guest_id uuid,
  supplier_id uuid,
  channel public.notification_channel not null,
  template_key text not null,         -- fx booking.needs_approval, supplier.confirmation_request
  locale public.locale_code not null default 'en',
  payload jsonb not null default '{}',
  booking_id uuid,
  status public.notification_status not null default 'queued',
  attempts int not null default 0,
  last_error text,
  scheduled_for timestamptz not null default now(),
  sent_at timestamptz,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (recipient_type = 'staff' and recipient_user_id is not null)
    or (recipient_type = 'guest' and guest_id is not null)
    or (recipient_type = 'supplier' and supplier_id is not null)
  ),
  foreign key (organization_id, guest_id) references public.guests (organization_id, id),
  foreign key (organization_id, supplier_id) references public.suppliers (organization_id, id),
  foreign key (organization_id, booking_id) references public.bookings (organization_id, id) on delete cascade
);
create index notifications_queue_idx on public.notifications (scheduled_for) where status = 'queued';
create index notifications_inbox_idx on public.notifications (recipient_user_id, created_at desc) where recipient_type = 'staff';
create index notifications_org_idx on public.notifications (organization_id);
create index notifications_booking_idx on public.notifications (booking_id);
create index notifications_guest_idx on public.notifications (guest_id);
create index notifications_supplier_idx on public.notifications (supplier_id);

-- ---------------------------------------------------------------------
-- Audit-log (kun tilføjelser) og GDPR
-- ---------------------------------------------------------------------
create table public.audit_log (
  id bigint generated always as identity primary key,
  organization_id uuid references public.organizations (id),
  actor_type public.actor_type not null,
  actor_user_id uuid,                 -- bevidst uden fremmednøgle: loggen overlever sletning af brugeren
  action text not null,               -- insert, update, delete eller et navn som gdpr.anonymize
  table_name text,
  record_id uuid,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);
create index audit_log_org_idx on public.audit_log (organization_id, created_at desc);
create index audit_log_record_idx on public.audit_log (table_name, record_id);

create function private.audit_log_immutable() returns trigger
language plpgsql
as $$
begin
  raise exception 'audit_log kan ikke ændres eller slettes' using errcode = 'insufficient_privilege';
end $$;

create trigger audit_log_no_change
  before update or delete on public.audit_log
  for each row execute function private.audit_log_immutable();

-- Generel audit-trigger. Argumenter = kolonner der IKKE må gemmes (persondata/hemmeligt).
-- Argumentet '__ids_only__' gemmer kun at noget skete, ikke indholdet.
create function private.audit_row() returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_old jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  v_new jsonb := case when tg_op in ('UPDATE', 'INSERT') then to_jsonb(new) end;
  v_row jsonb;
  v_org uuid;
begin
  v_row := coalesce(v_new, v_old);
  v_org := case when tg_table_name = 'organizations' then (v_row ->> 'id')::uuid
                else (v_row ->> 'organization_id')::uuid end;
  if tg_op = 'UPDATE' and v_old = v_new then
    return null;
  end if;
  if tg_nargs > 0 and tg_argv[0] = '__ids_only__' then
    v_old := null;
    v_new := null;
  elsif tg_nargs > 0 then
    v_old := v_old - tg_argv;
    v_new := v_new - tg_argv;
  end if;
  -- Hvis organisationen selv er ved at blive slettet, er der intet at logge på.
  if tg_op = 'DELETE' and not exists (select 1 from public.organizations o where o.id = v_org) then
    return null;
  end if;
  insert into public.audit_log (organization_id, actor_type, actor_user_id, action, table_name, record_id, old_data, new_data)
  values (v_org, private.current_actor(), (select auth.uid()), lower(tg_op), tg_table_name, (v_row ->> 'id')::uuid, v_old, v_new);
  return null;
end $$;

create table public.gdpr_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  guest_id uuid not null,
  request_type public.gdpr_request_type not null,
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  handled_by uuid references public.profiles (id) on delete set null,
  note text,
  created_at timestamptz not null default now(),
  foreign key (organization_id, guest_id) references public.guests (organization_id, id)
);
create index gdpr_requests_org_idx on public.gdpr_requests (organization_id, requested_at desc);
create index gdpr_requests_guest_idx on public.gdpr_requests (guest_id);

-- ---------------------------------------------------------------------
-- Plads til hardware i husene (Mac mini, tablet, Home Assistant). Bygges ikke nu.
-- ---------------------------------------------------------------------
create table public.devices (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  villa_id uuid not null,
  kind public.device_kind not null,
  name text not null,
  external_id text,                   -- fx Home Assistant instance-id
  last_seen_at timestamptz,
  meta jsonb not null default '{}',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, villa_id) references public.villas (organization_id, id) on delete cascade
);
create index devices_villa_idx on public.devices (villa_id);
create index devices_org_idx on public.devices (organization_id);

-- Rå hændelser fra huset. Kun serveren skriver. Partitionér på occurred_at hvis den bliver stor.
create table public.home_events (
  id bigint generated always as identity primary key,
  organization_id uuid not null,
  villa_id uuid not null,
  device_id uuid,
  event_type text not null,           -- fx state_changed, door.opened
  entity_id text,                     -- fx sensor.pool_temperature
  payload jsonb not null default '{}',
  occurred_at timestamptz not null,
  received_at timestamptz not null default now(),
  foreign key (organization_id, villa_id) references public.villas (organization_id, id) on delete cascade,
  foreign key (organization_id, device_id) references public.devices (organization_id, id) on delete cascade
);
create index home_events_villa_time_idx on public.home_events (villa_id, occurred_at desc);
create index home_events_org_idx on public.home_events (organization_id);
create index home_events_device_idx on public.home_events (device_id);

-- =====================================================================
-- Forretningsregler som triggere
-- =====================================================================

-- ---------- Bestillinger: statusmaskine ----------
create function private.bookings_guard() returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'proposed' then
      raise exception 'En ny bestilling skal starte som forslag (proposed), ikke %', new.status
        using errcode = 'check_violation';
    end if;
    new.created_by := coalesce(new.created_by, (select auth.uid()));
    return new;
  end if;

  -- Det, der blev godkendt, må ikke ændres bagefter. Start forfra med et nyt forslag.
  -- (Eneste undtagelse: GDPR-sletningen, som tømmer fritekst.)
  if old.status not in ('proposed', 'supplier_declined')
     and coalesce(current_setting('treatr.purge', true), '') <> 'on'
     and (new.villa_id, new.stay_id, new.service_id, new.supplier_id, new.scheduled_start, new.scheduled_end,
          new.quantity, new.party_size, new.guest_price_cents, new.supplier_cost_cents, new.currency, new.supplier_notes)
         is distinct from
         (old.villa_id, old.stay_id, old.service_id, old.supplier_id, old.scheduled_start, old.scheduled_end,
          old.quantity, old.party_size, old.guest_price_cents, old.supplier_cost_cents, old.currency, old.supplier_notes)
  then
    raise exception 'Bestillingen er allerede godkendt (%). Pris, tid, leverandør m.m. kan ikke ændres.', old.status
      using errcode = 'check_violation';
  end if;

  if new.status is distinct from old.status then
    if not (
      (old.status = 'proposed'           and new.status in ('approved', 'rejected', 'cancelled'))
      or (old.status = 'approved'           and new.status in ('sent', 'cancelled'))
      or (old.status = 'sent'               and new.status in ('supplier_confirmed', 'supplier_declined', 'cancelled'))
      or (old.status = 'supplier_declined'  and new.status in ('proposed', 'cancelled'))
      or (old.status = 'supplier_confirmed' and new.status in ('delivered', 'cancelled'))
      or (old.status = 'delivered'          and new.status = 'settled')
    ) then
      raise exception 'Ugyldigt statusskift for bestilling: % → %', old.status, new.status
        using errcode = 'check_violation';
    end if;

    if new.status = 'approved' and not exists (
      select 1 from public.approvals a where a.booking_id = new.id and a.status = 'approved'
    ) then
      raise exception 'En bestilling kan kun godkendes med to tryk (brug tap_approval)'
        using errcode = 'check_violation';
    end if;

    if new.status = 'sent' then
      if new.supplier_id is null then
        raise exception 'Vælg en leverandør før bestillingen sendes' using errcode = 'check_violation';
      end if;
      if not exists (
        select 1 from public.confirmation_links l
        where l.booking_id = new.id and l.used_at is null and l.revoked_at is null and l.expires_at > now()
      ) then
        raise exception 'En bestilling sendes med issue_confirmation_link(), som laver bekræftelseslinket'
          using errcode = 'check_violation';
      end if;
    end if;

    case new.status
      when 'proposed' then new.proposed_at := now(); new.approved_at := null; new.sent_at := null; new.supplier_responded_at := null;
      when 'approved' then new.approved_at := now();
      when 'sent' then new.sent_at := now();
      when 'supplier_confirmed' then new.supplier_responded_at := now();
      when 'supplier_declined' then new.supplier_responded_at := now();
      when 'delivered' then new.delivered_at := now();
      when 'settled' then new.settled_at := now();
      else new.closed_at := now();  -- rejected, cancelled
    end case;
  end if;

  new.updated_at := now();
  return new;
end $$;

create trigger bookings_guard
  before insert or update on public.bookings
  for each row execute function private.bookings_guard();

create function private.bookings_after() returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.booking_status_events (organization_id, booking_id, from_status, to_status, actor_type, actor_user_id)
    values (new.organization_id, new.id, null, new.status, private.current_actor(), (select auth.uid()));
    insert into public.approvals (organization_id, subject_type, booking_id)
    values (new.organization_id, 'booking', new.id);
    return null;
  end if;

  if new.status is distinct from old.status then
    insert into public.booking_status_events (organization_id, booking_id, from_status, to_status, actor_type, actor_user_id)
    values (new.organization_id, new.id, old.status, new.status, private.current_actor(), (select auth.uid()));

    if new.status = 'proposed' then
      -- Nyt forslag efter et nej fra leverandøren: den gamle godkendelse gælder ikke længere.
      update public.approvals set status = 'superseded'
      where booking_id = new.id and status in ('pending', 'first_tap', 'approved');
      insert into public.approvals (organization_id, subject_type, booking_id)
      values (new.organization_id, 'booking', new.id);
    elsif new.status in ('rejected', 'cancelled') then
      update public.approvals set status = 'superseded'
      where booking_id = new.id and status in ('pending', 'first_tap');
      update public.confirmation_links set revoked_at = now()
      where booking_id = new.id and used_at is null and revoked_at is null;
    end if;
  elsif new.status = 'proposed'
        and (new.service_id, new.supplier_id, new.scheduled_start, new.scheduled_end, new.quantity, new.party_size,
             new.guest_price_cents, new.supplier_cost_cents, new.supplier_notes)
            is distinct from
            (old.service_id, old.supplier_id, old.scheduled_start, old.scheduled_end, old.quantity, old.party_size,
             old.guest_price_cents, old.supplier_cost_cents, old.supplier_notes)
  then
    -- Forslaget blev ændret efter første tryk: begge tryk skal tages forfra.
    update public.approvals
    set status = 'pending', first_tap_by = null, first_tap_at = null
    where booking_id = new.id and status = 'first_tap';
  end if;
  return null;
end $$;

create trigger bookings_after
  after insert or update on public.bookings
  for each row execute function private.bookings_after();

-- ---------- Beskeder: AI-forslag skal godkendes før de sendes ----------
create function private.messages_guard() returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_purging boolean := coalesce(current_setting('treatr.purge', true), '') = 'on';
begin
  if tg_op = 'INSERT' then
    if new.sender_type = 'butler_ai' then
      if new.status <> 'draft' then
        raise exception 'Butlerens beskeder skal starte som kladde (draft) og godkendes af et menneske'
          using errcode = 'check_violation';
      end if;
      new.ai_suggested_body := coalesce(new.ai_suggested_body, new.body);
      new.was_edited := new.ai_suggested_body is distinct from new.body;
    elsif new.sender_type = 'guest' then
      new.status := 'received';
    elsif new.sender_type = 'staff' then
      new.sender_user_id := coalesce(new.sender_user_id, (select auth.uid()));
    end if;
    if new.status = 'sent' then
      new.sent_at := coalesce(new.sent_at, now());
    end if;
    return new;
  end if;

  if v_purging then
    return new;
  end if;

  if new.ai_suggested_body is distinct from old.ai_suggested_body
     or new.sender_type <> old.sender_type
     or new.conversation_id <> old.conversation_id then
    raise exception 'AI-forslag, afsender og samtale kan ikke ændres på en besked' using errcode = 'check_violation';
  end if;

  if new.body is distinct from old.body and old.status <> 'draft' then
    raise exception 'Teksten kan kun rettes mens beskeden er en kladde' using errcode = 'check_violation';
  end if;

  -- Status på gæstens og medarbejderes beskeder er leveringsstatus. Den sætter kun serveren.
  if new.sender_type <> 'butler_ai' and new.status is distinct from old.status and (select auth.uid()) is not null then
    raise exception 'Status på denne besked kan ikke ændres' using errcode = 'check_violation';
  end if;

  if new.sender_type = 'butler_ai' then
    new.was_edited := new.ai_suggested_body is distinct from new.body;
    if new.status is distinct from old.status then
      if not (
        (old.status = 'draft' and new.status in ('approved', 'discarded'))
        or (old.status = 'approved' and new.status in ('sent', 'failed'))
        or (old.status = 'failed' and new.status = 'sent')
      ) then
        raise exception 'Ugyldigt statusskift for butler-besked: % → %', old.status, new.status
          using errcode = 'check_violation';
      end if;
      if new.status = 'approved' and not exists (
        select 1 from public.approvals a where a.message_id = new.id and a.status = 'approved'
      ) then
        raise exception 'Butlerens besked kan kun godkendes med to tryk (brug tap_approval)'
          using errcode = 'check_violation';
      end if;
    end if;
  end if;

  if new.status = 'sent' and old.status <> 'sent' then
    new.sent_at := coalesce(new.sent_at, now());
  end if;
  new.updated_at := now();
  return new;
end $$;

create trigger messages_guard
  before insert or update on public.messages
  for each row execute function private.messages_guard();

create function private.messages_after() returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    update public.conversations set last_message_at = new.created_at where id = new.conversation_id;
    if new.sender_type = 'butler_ai' then
      insert into public.approvals (organization_id, subject_type, message_id)
      values (new.organization_id, 'message', new.id);
    end if;
  elsif new.sender_type = 'butler_ai' and new.status = 'draft' and new.body is distinct from old.body then
    -- Kladden blev rettet efter første tryk: tag begge tryk forfra.
    update public.approvals
    set status = 'pending', first_tap_by = null, first_tap_at = null
    where message_id = new.id and status = 'first_tap';
  elsif new.status = 'discarded' and old.status <> 'discarded' then
    update public.approvals set status = 'superseded'
    where message_id = new.id and status in ('pending', 'first_tap');
  end if;
  return null;
end $$;

create trigger messages_after
  after insert or update on public.messages
  for each row execute function private.messages_after();

-- ---------- updated_at ----------
do $$
declare t text;
begin
  foreach t in array array[
    'organizations', 'profiles', 'villas', 'villa_amenities', 'guests', 'stays', 'services', 'villa_services',
    'suppliers', 'supplier_services', 'conversations', 'upsell_offers', 'approvals', 'payments', 'commissions',
    'notifications', 'devices'
  ] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function private.set_updated_at()',
      t || '_set_updated_at', t);
  end loop;
end $$;

-- ---------- Audit ----------
create trigger organizations_audit after insert or update or delete on public.organizations
  for each row execute function private.audit_row();
create trigger organization_members_audit after insert or update or delete on public.organization_members
  for each row execute function private.audit_row();
create trigger services_audit after insert or update or delete on public.services
  for each row execute function private.audit_row();
create trigger villa_services_audit after insert or update or delete on public.villa_services
  for each row execute function private.audit_row();
create trigger suppliers_audit after insert or update or delete on public.suppliers
  for each row execute function private.audit_row();
create trigger bookings_audit after insert or update or delete on public.bookings
  for each row execute function private.audit_row('details', 'guest_notes', 'supplier_notes', 'internal_notes');
create trigger approvals_audit after insert or update or delete on public.approvals
  for each row execute function private.audit_row('snapshot');
create trigger confirmation_links_audit after insert or update or delete on public.confirmation_links
  for each row execute function private.audit_row('token_hash', 'used_note');
create trigger payments_audit after insert or update or delete on public.payments
  for each row execute function private.audit_row();
create trigger commissions_audit after insert or update or delete on public.commissions
  for each row execute function private.audit_row();
create trigger guests_audit after insert or update or delete on public.guests
  for each row execute function private.audit_row('__ids_only__');

-- =====================================================================
-- Funktioner som appen kalder (RPC)
-- =====================================================================

-- Ét tryk på en godkendelse. Første kald = første tryk, andet kald = andet tryk.
-- Efter andet tryk rykker bestillingen til 'approved' (eller beskeden til 'approved').
create function public.tap_approval(p_approval_id uuid) returns public.approvals
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_app public.approvals;
  v_two_people boolean;
begin
  if v_uid is null then
    raise exception 'Du skal være logget ind' using errcode = 'insufficient_privilege';
  end if;

  select * into v_app from public.approvals where id = p_approval_id for update;
  if not found or v_app.organization_id not in (select private.manager_org_ids()) then
    raise exception 'Kun ejer eller back office kan godkende' using errcode = 'insufficient_privilege';
  end if;

  if v_app.status = 'pending' then
    update public.approvals
    set status = 'first_tap', first_tap_by = v_uid, first_tap_at = now()
    where id = p_approval_id
    returning * into v_app;

  elsif v_app.status = 'first_tap' then
    select o.require_two_approvers into v_two_people
    from public.organizations o where o.id = v_app.organization_id;
    if v_two_people and v_app.first_tap_by = v_uid then
      raise exception 'Andet tryk skal komme fra en anden person end første tryk'
        using errcode = 'check_violation';
    end if;

    update public.approvals
    set status = 'approved', second_tap_by = v_uid, second_tap_at = now(),
        snapshot = case v_app.subject_type
          when 'booking' then (
            select jsonb_build_object(
              'service_id', b.service_id, 'supplier_id', b.supplier_id,
              'scheduled_start', b.scheduled_start, 'scheduled_end', b.scheduled_end,
              'quantity', b.quantity, 'party_size', b.party_size,
              'guest_price_cents', b.guest_price_cents, 'supplier_cost_cents', b.supplier_cost_cents,
              'currency', b.currency)
            from public.bookings b where b.id = v_app.booking_id)
          else (
            select jsonb_build_object('was_edited', m.was_edited, 'length', length(m.body))
            from public.messages m where m.id = v_app.message_id)
        end
    where id = p_approval_id
    returning * into v_app;

    if v_app.subject_type = 'booking' then
      update public.bookings set status = 'approved' where id = v_app.booking_id;
    else
      update public.messages set status = 'approved' where id = v_app.message_id;
    end if;

  else
    raise exception 'Godkendelsen er allerede afsluttet (%)', v_app.status using errcode = 'check_violation';
  end if;

  return v_app;
end $$;

create function public.reject_approval(p_approval_id uuid, p_reason text default null) returns public.approvals
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_app public.approvals;
begin
  if v_uid is null then
    raise exception 'Du skal være logget ind' using errcode = 'insufficient_privilege';
  end if;

  select * into v_app from public.approvals where id = p_approval_id for update;
  if not found or v_app.organization_id not in (select private.manager_org_ids()) then
    raise exception 'Kun ejer eller back office kan afvise' using errcode = 'insufficient_privilege';
  end if;
  if v_app.status not in ('pending', 'first_tap') then
    raise exception 'Godkendelsen er allerede afsluttet (%)', v_app.status using errcode = 'check_violation';
  end if;

  update public.approvals
  set status = 'rejected', rejected_by = v_uid, rejected_at = now(), reject_reason = p_reason
  where id = p_approval_id
  returning * into v_app;

  if v_app.subject_type = 'booking' then
    update public.bookings set status = 'rejected', cancel_reason = p_reason where id = v_app.booking_id;
  else
    update public.messages set status = 'discarded' where id = v_app.message_id;
  end if;
  return v_app;
end $$;

create function private.hash_token(p_token text) returns text
language sql immutable
set search_path = ''
as $$ select encode(sha256(convert_to(p_token, 'UTF8')), 'hex') $$;

-- Lav et bekræftelseslink til leverandøren og sæt bestillingen til 'sent'.
-- Returnerer det rå token ÉN gang. Kun hashen gemmes. Kaldes fra serveren.
create function public.issue_confirmation_link(p_booking_id uuid, p_ttl interval default interval '72 hours')
returns text
language plpgsql security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_booking public.bookings;
  v_token text;
begin
  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'Bestillingen findes ikke' using errcode = 'no_data_found';
  end if;
  -- Med brugerlogin: kun ejer/back office. Uden (service_role på serveren): tilladt.
  if v_uid is not null and v_booking.organization_id not in (select private.manager_org_ids()) then
    raise exception 'Kun ejer eller back office kan sende til leverandør' using errcode = 'insufficient_privilege';
  end if;
  if v_booking.status not in ('approved', 'sent') then
    raise exception 'Bestillingen skal være godkendt før den kan sendes (status er %)', v_booking.status
      using errcode = 'check_violation';
  end if;
  if v_booking.supplier_id is null then
    raise exception 'Vælg en leverandør før bestillingen sendes' using errcode = 'check_violation';
  end if;
  if p_ttl <= interval '0' or p_ttl > interval '30 days' then
    raise exception 'Udløb skal være mellem 0 og 30 dage' using errcode = 'check_violation';
  end if;

  -- Gamle, ubrugte links til samme bestilling virker ikke længere.
  update public.confirmation_links set revoked_at = now()
  where booking_id = p_booking_id and used_at is null and revoked_at is null;

  -- 244 bit tilfældighed fra to uuid v4 (kryptografisk tilfældige i Postgres).
  v_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');

  insert into public.confirmation_links (organization_id, booking_id, supplier_id, token_hash, expires_at, created_by)
  values (v_booking.organization_id, v_booking.id, v_booking.supplier_id, private.hash_token(v_token), now() + p_ttl, v_uid);

  if v_booking.status = 'approved' then
    update public.bookings set status = 'sent' where id = p_booking_id;
  end if;

  return v_token;
end $$;

-- Vis hvad linket handler om UDEN at bruge det. Bruges af GET-siden.
-- (Mailklienter og WhatsApp åbner links på forhånd; derfor må GET aldrig bekræfte noget.)
create function public.peek_confirmation_link(p_token text)
returns table (
  link_state text,          -- valid | used | expired | revoked | not_found | not_awaiting
  used_action text,
  expires_at timestamptz,
  supplier_name text,
  supplier_locale public.locale_code,
  service_name_i18n jsonb,
  villa_name text,
  villa_city text,
  scheduled_start timestamptz,
  scheduled_end timestamptz,
  quantity int,
  party_size int,
  supplier_notes text,
  supplier_cost_cents int,
  currency char(3)
)
language sql stable security definer
set search_path = ''
as $$
  select
    case
      when l.used_at is not null then 'used'
      when l.revoked_at is not null then 'revoked'
      when l.expires_at <= now() then 'expired'
      when b.status <> 'sent' then 'not_awaiting'
      else 'valid'
    end,
    l.used_action, l.expires_at, s.name, s.locale, sv.name_i18n, v.name, v.city,
    b.scheduled_start, b.scheduled_end, b.quantity, b.party_size, b.supplier_notes, b.supplier_cost_cents, b.currency
  from public.confirmation_links l
  join public.bookings b on b.id = l.booking_id
  join public.suppliers s on s.id = l.supplier_id
  join public.services sv on sv.id = b.service_id
  join public.villas v on v.id = b.villa_id
  where l.token_hash = private.hash_token(p_token)
  union all
  select 'not_found', null, null, null, null, null, null, null, null, null, null, null, null, null, null
  where not exists (select 1 from public.confirmation_links l where l.token_hash = private.hash_token(p_token))
$$;

-- Brug linket: leverandøren siger ja ('confirm') eller nej ('decline'). Virker præcis én gang.
-- Returnerer: confirmed | declined | already_used | expired | revoked | not_found | not_awaiting
create function public.redeem_confirmation_link(
  p_token text,
  p_action text,
  p_note text default null,
  p_ip inet default null
) returns text
language plpgsql security definer
set search_path = ''
as $$
declare
  v_hash text := private.hash_token(p_token);
  v_link public.confirmation_links;
  v_status public.booking_status;
  v_used_action text;
begin
  if p_action not in ('confirm', 'decline') then
    raise exception 'p_action skal være confirm eller decline' using errcode = 'invalid_parameter_value';
  end if;
  v_used_action := case p_action when 'confirm' then 'confirmed' else 'declined' end;

  -- Lås bestillingen først, så et samtidigt statusskift ikke kan snige sig ind.
  select b.status into v_status
  from public.confirmation_links l join public.bookings b on b.id = l.booking_id
  where l.token_hash = v_hash
  for update of b;
  if not found then
    return 'not_found';
  end if;

  select * into v_link from public.confirmation_links where token_hash = v_hash;
  if v_link.used_at is not null then return 'already_used'; end if;
  if v_link.revoked_at is not null then return 'revoked'; end if;
  if v_link.expires_at <= now() then return 'expired'; end if;
  if v_status <> 'sent' then return 'not_awaiting'; end if;

  -- Selve engangs-garantien: kun én opdatering kan ramme "used_at is null".
  update public.confirmation_links
  set used_at = now(), used_action = v_used_action, used_note = left(p_note, 2000), used_ip = p_ip
  where id = v_link.id and used_at is null and revoked_at is null and expires_at > now();
  if not found then
    return 'already_used';
  end if;

  perform set_config('treatr.actor', 'supplier', true);
  update public.bookings
  set status = case p_action when 'confirm' then 'supplier_confirmed' else 'supplier_declined' end::public.booking_status
  where id = v_link.booking_id;
  perform set_config('treatr.actor', '', true);

  return v_used_action;
end $$;

-- GDPR: fjern persondata for én gæst. Bestillinger og beløb bliver (bogføring), men uden navne og fritekst.
create function public.anonymize_guest(p_guest_id uuid, p_reason text default 'retention') returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_org uuid;
begin
  select organization_id into v_org from public.guests where id = p_guest_id for update;
  if not found then
    raise exception 'Gæsten findes ikke' using errcode = 'no_data_found';
  end if;

  perform set_config('treatr.purge', 'on', true);

  update public.messages m
  set body = '', ai_suggested_body = null, ai_meta = '{}', redacted_at = now()
  from public.conversations c
  where c.id = m.conversation_id and c.guest_id = p_guest_id and m.redacted_at is null;

  update public.bookings b
  set guest_notes = null, supplier_notes = null, details = '{}', internal_notes = null
  from public.stays s
  where s.id = b.stay_id and s.primary_guest_id = p_guest_id;

  update public.upsell_offers u
  set pitch = null
  from public.stays s
  where s.id = u.stay_id and s.primary_guest_id = p_guest_id;

  update public.notifications set payload = '{}' where guest_id = p_guest_id;

  update public.stays
  set notes = null, guest_token_hash = null, external_ref = null, purged_at = now()
  where primary_guest_id = p_guest_id;

  update public.guests
  set full_name = 'Anonymiseret gæst', email = null, phone = null, notes = null,
      marketing_consent = false, anonymized_at = now()
  where id = p_guest_id;

  perform set_config('treatr.purge', '', true);

  insert into public.audit_log (organization_id, actor_type, actor_user_id, action, table_name, record_id, new_data)
  values (v_org, private.current_actor(), (select auth.uid()), 'gdpr.anonymize', 'guests', p_guest_id,
          jsonb_build_object('reason', p_reason));
end $$;

-- GDPR: kør dagligt (cron). Anonymiserer gæster, hvis seneste ophold sluttede for mere end
-- organisationens guest_data_retention_days siden. Returnerer antal gæster.
create function public.purge_expired_guest_data() returns int
language plpgsql security definer
set search_path = ''
as $$
declare
  v_guest uuid;
  v_count int := 0;
begin
  for v_guest in
    select g.id
    from public.guests g
    join public.organizations o on o.id = g.organization_id
    where g.anonymized_at is null
      and exists (select 1 from public.stays s where s.primary_guest_id = g.id)
      and not exists (
        select 1 from public.stays s
        where s.primary_guest_id = g.id
          and s.status <> 'cancelled'
          and s.check_out + o.guest_data_retention_days >= current_date
      )
  loop
    perform public.anonymize_guest(v_guest, 'retention');
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;

-- Mersalg: hvad virkede? Følger RLS for den, der spørger (security_invoker).
create view public.upsell_performance
with (security_invoker = true)
as
select
  u.organization_id,
  u.service_id,
  u.trigger_kind,
  coalesce(u.variant, '') as variant,
  count(*) filter (where u.status <> 'dismissed') as offers,
  count(*) filter (where u.status in ('shown', 'accepted', 'declined', 'expired')) as shown,
  count(*) filter (where u.status = 'accepted') as accepted,
  round(
    count(*) filter (where u.status = 'accepted')::numeric
    / nullif(count(*) filter (where u.status in ('shown', 'accepted', 'declined', 'expired')), 0), 3
  ) as conversion_rate,
  coalesce(sum(b.guest_price_cents) filter (where b.status in ('delivered', 'settled')), 0) as delivered_revenue_cents
from public.upsell_offers u
left join public.bookings b on b.upsell_offer_id = u.id
group by u.organization_id, u.service_id, u.trigger_kind, coalesce(u.variant, '');

-- =====================================================================
-- Rettigheder
-- =====================================================================
-- anon: ingenting. authenticated: alt går gennem RLS nedenfor. service_role: kun serveren.
revoke all on all tables in schema public from anon, public;
revoke all on all sequences in schema public from anon, public;
revoke all on all functions in schema public from anon, public, authenticated;
revoke all on all functions in schema private from anon, public;

grant usage on schema public to authenticated, service_role;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;

grant usage on schema private to authenticated, service_role;
grant execute on function private.member_org_ids(), private.manager_org_ids(), private.owner_org_ids(),
  private.co_member_ids(), private.current_actor() to authenticated, service_role;

grant execute on function public.is_i18n(jsonb), public.i18n(jsonb, text) to authenticated, service_role;
grant execute on function public.tap_approval(uuid), public.reject_approval(uuid, text) to authenticated;
grant execute on function public.issue_confirmation_link(uuid, interval) to authenticated, service_role;
grant execute on function public.peek_confirmation_link(text) to service_role;
grant execute on function public.redeem_confirmation_link(text, text, text, inet) to service_role;
grant execute on function public.anonymize_guest(uuid, text), public.purge_expired_guest_data() to service_role;

-- =====================================================================
-- Row Level Security
-- =====================================================================
-- Tre faste mønstre. Brug dem også i nye migrationer:
--   medlem  = organization_id in (select private.member_org_ids())    alle roller
--   leder   = organization_id in (select private.manager_org_ids())   ejer + back office
--   ejer    = organization_id in (select private.owner_org_ids())
-- Der er ingen policies for anon, og service_role går uden om RLS (kun på serveren).

do $$
declare t text;
begin
  -- RLS på alle tabeller i public. CI fejler hvis en ny tabel mangler det.
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;

  -- Mønster A: alle medlemmer læser. Kun ledere opretter, retter og sletter. (Opsætning og katalog.)
  foreach t in array array['villas', 'villa_amenities', 'services', 'villa_services', 'suppliers', 'supplier_services', 'devices'] loop
    execute format('create policy %I on public.%I for select to authenticated using (organization_id in (select private.member_org_ids()))', t || '_select_member', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (organization_id in (select private.manager_org_ids()))', t || '_insert_manager', t);
    execute format('create policy %I on public.%I for update to authenticated using (organization_id in (select private.manager_org_ids())) with check (organization_id in (select private.manager_org_ids()))', t || '_update_manager', t);
    execute format('create policy %I on public.%I for delete to authenticated using (organization_id in (select private.manager_org_ids()))', t || '_delete_manager', t);
  end loop;

  -- Mønster B: alle medlemmer læser, opretter og retter. Kun ledere sletter. (Dagligt arbejde.)
  foreach t in array array['guests', 'stays', 'conversations', 'upsell_offers'] loop
    execute format('create policy %I on public.%I for select to authenticated using (organization_id in (select private.member_org_ids()))', t || '_select_member', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (organization_id in (select private.member_org_ids()))', t || '_insert_member', t);
    execute format('create policy %I on public.%I for update to authenticated using (organization_id in (select private.member_org_ids())) with check (organization_id in (select private.member_org_ids()))', t || '_update_member', t);
    execute format('create policy %I on public.%I for delete to authenticated using (organization_id in (select private.manager_org_ids()))', t || '_delete_manager', t);
  end loop;

  -- Mønster C: alle medlemmer læser. Ingen skriver direkte (kun triggere, RPC-funktioner og serveren).
  foreach t in array array['booking_status_events', 'approvals', 'home_events'] loop
    execute format('create policy %I on public.%I for select to authenticated using (organization_id in (select private.member_org_ids()))', t || '_select_member', t);
  end loop;

  -- Mønster D: kun ledere læser og skriver. (Penge og GDPR.)
  foreach t in array array['payments', 'commissions', 'gdpr_requests'] loop
    execute format('create policy %I on public.%I for select to authenticated using (organization_id in (select private.manager_org_ids()))', t || '_select_manager', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (organization_id in (select private.manager_org_ids()))', t || '_insert_manager', t);
    execute format('create policy %I on public.%I for update to authenticated using (organization_id in (select private.manager_org_ids())) with check (organization_id in (select private.manager_org_ids()))', t || '_update_manager', t);
  end loop;
end $$;

-- organizations: medlemmer læser, ejer retter. Oprettelse sker på serveren (onboarding).
create policy organizations_select_member on public.organizations for select to authenticated
  using (id in (select private.member_org_ids()));
create policy organizations_update_owner on public.organizations for update to authenticated
  using (id in (select private.owner_org_ids())) with check (id in (select private.owner_org_ids()));

-- profiles: dig selv og dine kolleger. Du kan kun rette din egen.
create policy profiles_select_self_or_colleague on public.profiles for select to authenticated
  using (id = (select auth.uid()) or id in (select private.co_member_ids()));
create policy profiles_update_self on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- organization_members: medlemmer ser holdet, ejer styrer det.
create policy organization_members_select_member on public.organization_members for select to authenticated
  using (organization_id in (select private.member_org_ids()));
create policy organization_members_insert_owner on public.organization_members for insert to authenticated
  with check (organization_id in (select private.owner_org_ids()));
create policy organization_members_update_owner on public.organization_members for update to authenticated
  using (organization_id in (select private.owner_org_ids())) with check (organization_id in (select private.owner_org_ids()));
create policy organization_members_delete_owner on public.organization_members for delete to authenticated
  using (organization_id in (select private.owner_org_ids()));

-- messages: medlemmer læser. Medarbejdere skriver egne beskeder og retter kladder.
-- AI-kladder og gæstebeskeder indsættes af serveren. Ingen sletter (GDPR-funktionen tømmer teksten).
create policy messages_select_member on public.messages for select to authenticated
  using (organization_id in (select private.member_org_ids()));
create policy messages_insert_staff on public.messages for insert to authenticated
  with check (
    organization_id in (select private.member_org_ids())
    and sender_type = 'staff'
    and (sender_user_id is null or sender_user_id = (select auth.uid()))
  );
create policy messages_update_member on public.messages for update to authenticated
  using (organization_id in (select private.member_org_ids()))
  with check (organization_id in (select private.member_org_ids()));

-- bookings: medlemmer læser og foreslår. Ledere retter. Concierge kan rette så længe det er et forslag.
-- Statusskift og godkendelse håndhæves af triggeren, uanset hvem der skriver.
create policy bookings_select_member on public.bookings for select to authenticated
  using (organization_id in (select private.member_org_ids()));
create policy bookings_insert_member on public.bookings for insert to authenticated
  with check (organization_id in (select private.member_org_ids()));
create policy bookings_update_manager on public.bookings for update to authenticated
  using (organization_id in (select private.manager_org_ids()))
  with check (organization_id in (select private.manager_org_ids()));
create policy bookings_update_proposed_member on public.bookings for update to authenticated
  using (organization_id in (select private.member_org_ids()) and status = 'proposed')
  with check (organization_id in (select private.member_org_ids()) and status = 'proposed');

-- confirmation_links: ledere kan se status (aldrig selve tokenet, det gemmes ikke).
create policy confirmation_links_select_manager on public.confirmation_links for select to authenticated
  using (organization_id in (select private.manager_org_ids()));

-- notifications: du ser dine egne, ledere ser alle i organisationen. Du kan markere dine egne som læst.
create policy notifications_select_own_or_manager on public.notifications for select to authenticated
  using (recipient_user_id = (select auth.uid()) or organization_id in (select private.manager_org_ids()));
create policy notifications_update_own on public.notifications for update to authenticated
  using (recipient_user_id = (select auth.uid()) and organization_id in (select private.member_org_ids()))
  with check (recipient_user_id = (select auth.uid()) and organization_id in (select private.member_org_ids()));

-- audit_log: kun ejer læser. Ingen skriver direkte.
create policy audit_log_select_owner on public.audit_log for select to authenticated
  using (organization_id in (select private.owner_org_ids()));

grant select on public.upsell_performance to authenticated, service_role;
