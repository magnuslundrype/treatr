# Plan for ugen i Spanien (18.-23. november 2026)

Mål for ugen: **én bestilling hele vejen igennem** i en preview, fra gæstens besked til
leverandørens bekræftelse, med to tryk i back office. Ikke pænt, men ægte.

Fem arbejdsdage (onsdag til søndag). Mandag den 23. er hjemrejse og buffer.

## Sådan undgår vi at træde hinanden over tæerne

- **Hver person har sit eget spor og sine egne mapper.** Du retter i dine mapper. Skal du bruge
  noget i en andens, så bed om det i Mattermost eller lav en lille PR, som ejeren reviewer.
- **Databasen er fælles og går gennem person A.** Skemaet til hele idéen findes allerede
  (`0001_init.sql`), så de fleste opgaver kræver ingen migration. Har du brug for én, så sig det først.
- **Fælles filer rettes i små PR'er for sig:** `src/app/layout.tsx`, `src/lib/supabase/`, `package.json`.
  En PR, der kun tilføjer en afhængighed, er helt fin.
- **Aftalerne mellem sporene er databasens funktioner,** ikke hinandens kode: `tap_approval`,
  `issue_confirmation_link`, `peek_confirmation_link`, `redeem_confirmation_link`. De findes og er testet.

| Spor | Hvem                        | Ejer mapperne                                                | Leverer i ugen                                                      |
| ---- | --------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------- |
| A    | Erfaren (platform)          | `.github/`, `supabase/`, `tests/db/`, `src/lib/supabase/`    | Opsætning, login, database-klienter, review af alt med database     |
| B    | Erfaren (back office)       | `src/app/app/godkendelser/`, `src/app/app/bestillinger/`     | Godkendelseskø med to tryk, bestillingsliste, "send til leverandør" |
| C    | Erfaren eller øvet (butler) | `src/lib/butler/`, `src/app/api/butler/`                     | Gæstens besked → kladde og forslag fra Claude                       |
| D    | Ny (leverandørsiden)        | `src/app/c/`, `src/messages/`                                | Bekræftelsesside på es/en/da, beskedtekster                         |
| E    | Ny (villa og gæst)          | `src/app/app/villaer/`, `src/app/app/katalog/`, `src/app/g/` | Villa, faciliteter og katalog i back office, gæstens chat-side      |

D og E har hver en fast makker blandt A, B og C, som reviewer deres PR'er først.

## Dag for dag

### Dag 1, onsdag 18.: alle har en merget PR

| Spor | Formiddag                                                                           | Eftermiddag                                                                    |
| ---- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| A    | [Opsætning](opsaetning.md): GitHub, Linear, Supabase, Vercel. Rulesettet slået til. | Supabase-klienter i `src/lib/supabase/` (bruger-session og server), login-side |
| B    | Hjælper A. Prøver "første dag" som testperson.                                      | `/grill-me` om back office → `/to-spec` → `/to-tickets` i Linear               |
| C    | Hjælper D og E i gang.                                                              | `/grill-me` om butleren → spec og opgaver. Anthropic-nøgle i Vercel.           |
| D    | [Første dag](foerste-dag.md): første PR merget.                                     | Lokal Supabase op at køre. Læser `docs/erd.md` med sin makker.                 |
| E    | [Første dag](foerste-dag.md): første PR merget.                                     | Lokal Supabase op at køre. Læser `docs/erd.md` med sin makker.                 |

Færdig når: fem mergede "tilføj mig til holdet"-PR'er, og `main` kan ikke pushes til.

### Dag 2, torsdag 19.: skærme med seed-data

| Spor | Opgaver                                                                                                         |
| ---- | --------------------------------------------------------------------------------------------------------------- |
| A    | Layout og navigation i back office (bag login). Genererede database-typer (`src/lib/database.types.ts`).        |
| B    | Godkendelseskø: liste over ventende godkendelser fra seed. Vis bestilling eller kladde.                         |
| C    | Serverfunktion: gæstebesked ind → Claude → kladde (`messages`) og forslag (`bookings`). Test med seed-samtalen. |
| D    | Bekræftelsesside (`/c/[token]`): vis opgaven med `peek_confirmation_link`. Kun visning, ingen knapper endnu.    |
| E    | Back office: vis villa og faciliteter. Ret en facilitet.                                                        |

Færdig når: hver person kan vise sin skærm i en preview kl. 16:30.

### Dag 3, fredag 20.: de enkelte led virker

| Spor | Opgaver                                                                                    |
| ---- | ------------------------------------------------------------------------------------------ |
| A    | Realtime i back office (ny godkendelse dukker op). Hjælp og review.                        |
| B    | To tryk (`tap_approval`), afvis (`reject_approval`), ret kladde før godkendelse.           |
| C    | Butleren bruger katalog, priser og husmanual. Forslag til mersalg (`upsell_offers`).       |
| D    | Knapperne Ja og Nej (`redeem_confirmation_link`), sider for brugt, udløbet og ukendt link. |
| E    | Katalog: services og priser pr. villa. Gæstens chat-side (`/g/[token]`): vis samtalen.     |

Færdig når: to tryk flytter en bestilling til godkendt, og et link kan bekræftes præcis én gang i en preview.

### Dag 4, lørdag 21.: kæden hænger sammen

| Spor | Opgaver                                                                                                 |
| ---- | ------------------------------------------------------------------------------------------------------- |
| A    | Afsendelse: vælg én kanal (mail er nemmest) og send bekræftelseslinket. Dagligt job til GDPR-oprydning. |
| B    | "Send til leverandør" (`issue_confirmation_link`). Bestillingsliste med status og historik.             |
| C    | Godkendt svar sendes til gæsten. Gem model og prompt-version. Et lille sæt prøvebeskeder som test.      |
| D    | Oversættelser es/en/da for bekræftelsesside og beskeder. Afprøv på en rigtig telefon.                   |
| E    | Gæsten kan skrive i chatten. Beskeden lander i back office.                                             |

Færdig når: én bestilling går fra gæstens besked til leverandørens ja i en preview, uden håndholdt SQL.

### Dag 5, søndag 22.: demo og oprydning

- Formiddag: ret det, demoen afslører. Ingen nye funktioner.
- Kl. 14: demo for hinanden af hele flowet, på telefon og computer.
- Derefter: `/retro` for hele ugen. Hvad skal ændres i opsætningen, før vi arbejder hjemmefra?
- Sidst: opgaver til de næste fire uger i Linear. Hvem tager hvad hjemme.

### Mandag 23.: hjemrejse

Buffer. Ingen merges, medmindre noget er i stykker.

## Dagens rytme

| Tid   | Hvad                                                                          |
| ----- | ----------------------------------------------------------------------------- |
| 09:00 | 10 minutter foran Linear-tavlen: hvad tager jeg i dag, og hvad venter jeg på? |
| 09:15 | Arbejde. Review af små PR'er går forud for eget arbejde.                      |
| 13:00 | Frokost                                                                       |
| 16:30 | Vis-og-fortæl: hver person viser sin preview i 3 minutter.                    |
| 17:00 | `/retro`: højst én lille PR, der forbedrer opsætningen. Så er der fri.        |

## Det gør vi ikke i ugen

Betaling, WhatsApp, flere organisationer i brugerfladen, Home Assistant, pænt design, og
at lade butleren svare uden godkendelse. Skemaet har plads til det hele, men ugen handler om
at få kæden til at hænge sammen.
