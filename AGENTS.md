# Treatr: regler for AI-agenter

Treatr er en AI-butler til luksusvillaer: gæsten skriver, butleren foreslår, et menneske
godkender med to tryk, leverandøren bekræfter via et link. Overblik: `ARCHITECTURE.md`.
Fagord: `GLOSSARY.md`. Beslutninger: `docs/adr/`. Hold denne fil kort; detaljer hører til i de filer.

## Fire grundregler

1. **Tænk før du koder.** Skriv dine antagelser. Er opgaven uklar, eller er der flere måder at
   forstå den på, så spørg i stedet for at vælge i stilhed. Er der en enklere løsning, så sig det.
2. **Simpelt først.** Den mindste kode, der løser opgaven i Linear. Ingen ekstra funktioner,
   ingen abstraktioner til engangsbrug, ingen "fleksibilitet" ingen bad om. Kan 200 linjer være 50, så skriv dem om.
3. **Kirurgiske ændringer.** Rør kun det, opgaven kræver. Ret ikke stil, kommentarer eller kode
   ved siden af. Ser du noget andet, der bør ordnes, så nævn det eller opret en Linear-opgave.
   Hver ændret linje skal kunne føres tilbage til opgaven.
4. **Mål du kan tjekke.** Gør opgaven til noget, der kan bevises: skriv en test, der fejler, og
   få den til at bestå. Kør `npm run check` (og `npm run db:test`, hvis du har rørt databasen),
   før du siger, du er færdig. Sig ærligt, hvad du ikke fik tjekket.

## Sådan arbejder vi

Én Linear-opgave ad gangen, på sin egen branch, i en lille pull request (helst under 200 linjer).

`/grill-me` → `/to-spec` og `/to-tickets` → `/implement` → `/code-review` → pull request → `/retro` sidst på dagen.

- Branch-navnet kopieres fra Linear og indeholder opgavens ID, fx `tre-123-leverandoer-link`.
- Pull requesten bruger skabelonen: Linear-opgave, hvad er ændret, bevis, rollback.
- Du merger ikke selv. Et menneske reviewer og merger.

## Projektregler

Reglerne herunder er også håndhævet af hooks, CI eller databasen. Bliver du stoppet, så ret
årsagen. Gå aldrig uden om (`--no-verify`, slå hooks fra, ændre en test så den består).

**Database**

- En migration, der ligger på `main`, ændres aldrig. Lav en ny: `npx supabase migration new <navn>`.
- Nye tabeller skal have `organization_id`, RLS, policies efter de tre mønstre i
  `supabase/migrations/0001_init.sql` og indeks på fremmednøgler. `anon` får aldrig rettigheder.
- Statusskift på bestillinger og godkendelse med to tryk sker gennem databasens funktioner
  (`tap_approval`, `issue_confirmation_link`, `redeem_confirmation_link`). Byg ikke en vej udenom.
- Ændrer du en regel i databasen, så ret testen i `tests/db/` i samme pull request.
- Penge er heltal i cent. Tekst til gæster og leverandører er `_i18n`-kolonner med `es`, `en`, `da`.

**Sikkerhed**

- Ingen secrets i repoet. Nye variabler skrives som tomme navne i `.env.example`.
- `service_role`-nøglen bruges kun i serverkode under `src/lib/supabase/`, aldrig i en
  klientkomponent og aldrig i en variabel, der starter med `NEXT_PUBLIC_`. Kode, der bruger
  den, skal altid afgrænse på `organization_id`.
- At åbne et link (GET) må aldrig ændre noget. Kun et tryk (POST) må bruge et token.
- Butleren (AI) opretter kun kladder og forslag. Den sender aldrig selv noget til en gæst eller leverandør.
- Læg aldrig rigtige gæster, leverandører eller priser i `supabase/seed.sql`, tests eller prompts.

**Frontend**

- Brug skillen `modern-web-guidance`, før du skriver HTML, CSS eller JavaScript til browseren.
- **Browser Support:** Baseline Widely available. Nyere funktioner (Baseline Newly available)
  må bruges, hvis siden stadig virker uden dem. Ingen polyfills.
- Brug browserens egne elementer (`<dialog>`, `<form>`, `<button>`, `<details>`) før et bibliotek.
- Leverandørens bekræftelsesside skal virke på en ældre telefon og uden JavaScript.

## Kommandoer

| Kommando            | Hvad                                                              |
| ------------------- | ----------------------------------------------------------------- |
| `npm run dev`       | Start appen på http://localhost:3000                              |
| `npm run check`     | Typecheck, lint, format og test. Det samme som CI.                |
| `npm run format`    | Ret formatering                                                   |
| `npm run db:test`   | Byg databasen fra bunden og kør RLS-tests (se `scripts/db-test.sh`) |
| `npx supabase start`| Lokal Supabase med migrationer og demo-data                       |
| `npx supabase db reset` | Nulstil den lokale database                                   |

## Agent skills

### Issue tracker

Opgaver ligger i Linear (hold `TRE`), ikke i GitHub Issues. Se `docs/agents/issue-tracker.md`.

### Domain docs

Single-context: `GLOSSARY.md` i roden og ADR'er i `docs/adr/`. Se `docs/agents/domain.md`.

<!-- BEGIN:nextjs-agent-rules -->

## This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->
