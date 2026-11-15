# Treatr

Treatr er en AI-butler til luksusvillaer: gæster bestiller service gennem en chat, et menneske
godkender, og leverandører bekræfter via et link. Brug ordene herunder i kode, opgaver og samtaler.
Dansk ord først, navnet i koden i parentes.

## Language

**Organisation** (`organization`):
En kunde hos Treatr: en husejer eller et udlejningsbureau med en eller flere villaer. Al data tilhører præcis én organisation.
_Avoid_: tenant, konto, firma

**Villa** (`villa`):
Et hus, der lejes ud, og som butleren betjener.
_Avoid_: ejendom, property, bolig

**Facilitet** (`villa_amenity`):
Noget i villaen, som butleren kan svare på spørgsmål om, fx pool, wifi eller grill.
_Avoid_: feature, udstyr

**Gæst** (`guest`):
Den person, der bor i villaen og skriver til butleren. Har ikke login.
_Avoid_: kunde, bruger, lejer

**Ophold** (`stay`):
En gæsts periode i en villa, fra indtjekning til udtjekning.
_Avoid_: booking, reservation (de ord bruger vi ikke, fordi de forveksles med bestilling)

**Butleren** (`butler_ai`):
AI'en, der læser gæstens besked og foreslår svar, bestillinger og mersalg. Den sender aldrig noget selv.
_Avoid_: botten, assistenten, agenten

**Medarbejder** (`staff`):
Et menneske med login hos en organisation. Har én af tre roller: ejer, back office eller concierge.
_Avoid_: admin, operatør

**Back office** (`back_office`):
Rollen, der godkender, styrer katalog og leverandører og ser penge.

**Concierge** (`concierge`):
Rollen, der taler med gæster og laver forslag, men ikke kan godkende eller se penge.

**Service** (`service`):
Noget, en gæst kan bestille, fx privat kok, lufthavnstransport eller rengøring. Står i kataloget med en pris.
_Avoid_: produkt, ydelse, vare

**Katalog** (`services` og `villa_services`):
Listen over services i en organisation og prisen for hver service i hver villa.

**Leverandør** (`supplier`):
Den, der udfører en service, fx en kok eller et taxafirma. Har ikke login.
_Avoid_: partner, vendor, underleverandør

**Bestilling** (`booking`):
Én service til ét ophold på et bestemt tidspunkt. Går gennem statusmaskinen.
_Avoid_: ordre, reservation, opgave

**Forslag** (`proposed`):
En bestilling, der endnu ikke er godkendt. Kan komme fra butleren, gæsten eller en medarbejder.

**Godkendelse** (`approval`):
Et menneskes ja til en bestilling eller til en besked fra butleren. Kræver to tryk.
_Avoid_: review, accept

**To tryk** (`tap_approval`):
De to bevidste tryk, der skal til for en godkendelse: først Godkend, så Bekræft.

**Bekræftelseslink** (`confirmation_link`):
Linket, en leverandør får for at sige ja eller nej til en bestilling. Virker én gang og udløber.
_Avoid_: magic link, invitationslink

**Kladde** (`draft`):
En besked fra butleren, som venter på godkendelse og kan rettes af en medarbejder.

**Mersalg** (`upsell_offer`):
Et tilbud om en service, som gæsten ikke selv har bedt om.
_Avoid_: upsell, kampagne, anbefaling

**Afregnet** (`settled`):
Slutstatus for en bestilling: gæsten har betalt, og leverandøren har fået sit.

**Provision** (`commission`):
Det beløb, Treatr eller organisationen tjener på en bestilling.

**Anonymisering** (`anonymize_guest`):
At fjerne en gæsts persondata efter opholdet, mens bestillinger og beløb bliver.
_Avoid_: sletning (rækkerne slettes ikke)
