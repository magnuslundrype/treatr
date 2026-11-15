# Rapport: Treatr-arkitektur

Kørt 15. november 2026. Alt ligger som filer i denne mappe og er committet lokalt. Der er
ikke pushet, deployet, oprettet konti eller købt noget.

## Hvad der er lavet

| Leverance       | Hvor                                                                                                                                                      |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1. Arkitektur   | `ARCHITECTURE.md`: antagelser, overblik, 4 mermaid-diagrammer, dataflow for én bestilling                                                                 |
| 2. Beslutninger | `docs/adr/`: 13 korte ADR'er                                                                                                                              |
| 3. Datamodel    | `docs/erd.md` (ERD), `supabase/migrations/0001_init.sql` (25 tabeller, 24 enums, 75 RLS-policies), `supabase/seed.sql` (demo-villa)                       |
| 4. GitHub       | `.github/`: ruleset som JSON, 3 workflows, PR-skabelon, CODEOWNERS, Dependabot. `scripts/setup-github.sh` slår det til.                                   |
| 5. Vejledninger | `CONTRIBUTING.md`, `docs/saadan-arbejder-vi.md` (én side), `docs/foerste-dag.md` (30 min), `AGENTS.md`, `CLAUDE.md`, `CODING_STANDARDS.md`, `GLOSSARY.md` |
| 6. Plan         | `docs/5-dages-plan.md`: fem spor med hver sine mapper, dag for dag                                                                                        |
| Ekstra          | `docs/opsaetning.md` (opsætning og priser), lokale git-hooks, Claude Code-hook, Next.js-skelet                                                            |

Ud over det, opgaven bad om, har jeg lagt et tomt Next.js-skelet i roden. Uden det kunne CI
og "første dag" ikke afprøves. Det er `create-next-app` uændret plus Vitest, Prettier og lefthook.

## Hvad der er afprøvet

- **Databasen:** migration og seed kørt mod en tom Postgres 16 og 17. 154 tjek er grønne, bl.a.:
  en bruger i organisation A ser 0 rækker fra organisation B i alle 23 tabeller med
  `organization_id` og kan ikke skrive i B; `anon` har ingen adgang; et bekræftelses-token
  bekræfter første gang og giver `already_used` anden gang; udløbne og erstattede links virker
  ikke; en bestilling kan ikke godkendes uden to tryk. Kør selv: `npm run db:test`.
- **Workflows:** `actionlint` uden fejl. PR-reglerne er kørt lokalt mod 8 eksempler. Gitleaks er
  kørt mod repoet (ingen fund) og mod en prøvefil med en Stripe-nøgle og en Supabase-nøgle (begge fundet).
- **Mermaid:** alle 5 diagrammer er tegnet med mermaid-cli uden syntaksfejl.
- **App-tjek:** `npm run check` (typecheck, lint, format, test) er grøn.
- **Hooks:** Claude-hooken er kørt mod 14 eksempler. Lefthook-konfigurationen er valideret.

**Ikke afprøvet:** workflows på GitHub, rulesettet, `scripts/setup-github.sh`, Linear-, Vercel-
og Supabase-integrationerne, og skemaet mod en rigtig Supabase (kun mod en efterligning af
Supabases roller og `auth`-skema). Testene fandt og rettede undervejs én fejl: audit-loggen
gemte leverandørnoten, som kan indeholde gæsteoplysninger.

## Antagelser

De otte antagelser om idéen står øverst i `ARCHITECTURE.md`. De vigtigste:

1. Gæsten skriver i en web-chat via et personligt link. WhatsApp kommer senere.
2. "To tryk" er én person, der trykker to gange. Kan ændres til to personer pr. organisation.
3. AI-beskeder og bestillinger kræver godkendelse. Beskeder, et menneske selv skriver, gør ikke.
4. Betaling sker uden for systemet i piloten.
5. Gæstedata anonymiseres 30 dage efter udtjekning. Skal bekræftes af en jurist.

Tekniske valg, jeg selv har truffet: Next.js 16 med npm i roden af repoet (ingen monorepo),
Linear-nøglen `TRE`, seed-data i `supabase/seed.sql` i stedet for i migrationen (så de ikke
havner i produktion), og Baseline Widely available som browsermål.

## Vigtigt fund: tre krav koster penge

På et privat repo håndhæver GitHub kun rulesets, CODEOWNERS og krav om review med **GitHub Team
(20 USD/md for 5)**. Supabase preview branches kræver **Pro (25 USD/md plus forbrug)**. Vercel
Hobby kan ikke deploye et holds private organisations-repo; det kræver **Pro (20 USD pr. plads)**.
Priserne er slået op 15. november 2026.

Jeg har derfor lavet to spor med de samme filer. Gratis-sporet virker fra dag 1 (CI, PR-regler,
testdatabase i CI, lokale hooks, alarm ved direkte push), men det opdager fejl i stedet for at
forhindre dem. Min anbefaling er at købe GitHub Team inden første dag. Detaljer i
`docs/opsaetning.md` og ADR-0002 og ADR-0003.

## Første dag i Spanien: tjekliste

Person A (den mest erfarne) tager punkt 1-9. Trin for trin i `docs/opsaetning.md`.

- [ ] 1. Beslut plan-niveau: GitHub Team nu? Supabase Pro og Vercel Pro nu eller senere?
- [ ] 2. Opret GitHub-organisation og privat repo. Læg mappen op som første commit. Slet først
      `input/`, `PROMPT.md`, `REPORT.md`, `DONE` og `start.sh`.
- [ ] 3. Opret teamet `erfarne`, og ret `@treatr/erfarne` i `.github/CODEOWNERS`.
- [ ] 4. Kør `bash scripts/setup-github.sh`. Tjek at et push direkte til `main` bliver afvist.
- [ ] 5. Linear: hold med nøglen `TRE`, GitHub-integration, automatik for status, én startopgave pr. person.
- [ ] 6. Supabase: projekt i EU, GitHub-integration med `main` som produktion. Slå branching til, hvis I har Pro.
- [ ] 7. Vercel: projekt fra repoet, Supabase-integration, `ANTHROPIC_API_KEY` og `APP_URL`.
- [ ] 8. Kør `npx supabase start` og log ind med `owner@demo.treatr.test` (kodeord i `seed.sql`).
      Det er første gang, skemaet møder en rigtig Supabase.
- [ ] 9. Åbn en test-PR og se, at `CI`, `PR-regler`, Vercel-preview og `Supabase Preview` dukker op.
- [ ] 10. Alle fem: følg `docs/foerste-dag.md` og få en "tilføj mig til holdet"-PR merget. Tag tid.
- [ ] 11. Læs de otte antagelser i `ARCHITECTURE.md` sammen, og ret dem, der er forkerte.
- [ ] 12. Eftermiddag: `/grill-me` om back office og om butleren, og opgaver i Linear til dag 2.

## De tre største risici

1. **Gratis-planerne håndhæver ikke reglerne.** Uden GitHub Team er `main` kun beskyttet af
   lokale hooks og en alarm. Uden Supabase Pro og Vercel Pro er der ingen preview pr. PR.
2. **`service_role` går uden om RLS.** Gæstechat, bekræftelsesside og butler kører på serveren
   med en nøgle, der kan se alle organisationer. Én glemt afgrænsning på `organization_id` kan
   vise én kundes data til en anden. Koden skal samles i `src/lib/supabase/` og reviewes af en erfaren.
3. **Skemaet er ikke kørt mod en rigtig Supabase.** Demo-logins i seed-filen og samspillet med
   Supabase Auth er uprøvet. Punkt 8 på tjeklisten afgør det på ti minutter.

## Klar og mangler

**Klar:** datamodel med regler og tests, CI og PR-regler, ruleset og opsætningsscript, hooks,
alle vejledninger, ADR'er, plan for ugen, og et skelet hvor alle tjek er grønne.

**Mangler:** alt, der kræver konti (repo, projekter, integrationer), selve appen (back office,
gæstechat, bekræftelsesside, butlerens AI-kald), afsendelse af beskeder, det daglige GDPR-job,
begrænsning af antal forsøg på token-siderne, og en jurists blik på GDPR-antagelserne.
