# Opsætning: GitHub, Linear, Vercel og Supabase

Gøres én gang af den, der sætter repoet op (person A i [5-dages-planen](5-dages-plan.md)).
Regn med 60-90 minutter. Intet af det her er gjort på forhånd: der er ikke oprettet repo,
projekter eller konti, og der er ikke købt noget.

## 0. Vælg plan-niveau først

Tre af de ting, vi gerne vil have, koster penge på et privat repo (priser tjekket 15. nov. 2026).
Alt i repoet virker i begge spor. Forskellen er, om reglerne **håndhæves** eller kun **opdages**.

| Tjeneste | Gratis                                                                                                      | Betalt forslag                                                  | Hvad I får for pengene                                       |
| -------- | ----------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------ |
| GitHub   | Privat repo, Actions (2.000 min/md), Dependabot. **Rulesets, CODEOWNERS og krav om review håndhæves ikke.** | **GitHub Team: 4 USD pr. bruger pr. md (20 USD for 5)**         | main kan ikke brydes. Det vigtigste køb.                     |
| Supabase | 2 projekter, pauses efter en uges stilstand. **Ingen preview branches.**                                    | **Pro: 25 USD pr. md + ca. 0,013 USD pr. time pr. åben branch** | En frisk database pr. pull request. Ingen pause.             |
| Vercel   | Hobby: kun personlig og ikke-kommerciel. **Kan ikke deploye et holds private organisations-repo.**          | **Pro: 20 USD pr. plads pr. md (100 USD for 5)**                | Preview pr. pull request for alle, og produktion fra `main`. |
| Linear   | Gratis: ubegrænset antal medlemmer, 250 aktive opgaver, GitHub-integration                                  | Ikke nødvendigt nu                                              |                                                              |

**Anbefaling:** køb GitHub Team før første dag (20 USD om måneden). Det er det eneste, der gør
"svært at gøre noget forkert" til en kendsgerning. Tag Supabase Pro og Vercel Pro, når I vil
have previews. Samlet cirka 145 USD om måneden plus forbrug.

**Vil I starte helt gratis,** så virker dette stadig: CI og PR-regler på hver PR, en frisk
testdatabase i CI, lokale hooks, agent-hook og alarmen `Main-vagt`. I mangler så: at GitHub
afviser et direkte push, preview-links, og preview-databaser. Beviset i en PR bliver et
skærmbillede fra egen maskine. Spring trin 4 og 5 over, og kør appen lokalt.

## 1. GitHub (15 min)

- [ ] Opret en organisation og et **privat** repo `treatr`. Læg indholdet af denne mappe i det
      som første commit på `main`. Mappen `input/` og filerne `PROMPT.md`, `REPORT.md`, `DONE`
      og `start.sh` hører til arkitektur-kørslen og kan slettes først.
- [ ] Invitér de fire andre. Opret teamet **`erfarne`** med de 2-3 mest erfarne.
- [ ] Ret `@treatr/erfarne` i `.github/CODEOWNERS` til `@<jeres-organisation>/erfarne`.
- [ ] Kør opsætningen (squash merge, slet branches, ruleset): `gh auth login` og derefter `bash scripts/setup-github.sh`.
- [ ] Prøv det: `git commit --allow-empty -m test && git push origin main` skal blive **afvist**.
      (Kør `git reset --hard origin/main` bagefter.)
- [ ] Settings → Code security: slå Dependabot alerts til.

Bliver rulesettet afvist, er repoet på gratis-planen. Se trin 0.

## 2. Linear (10 min)

- [ ] Opret holdet **Treatr** med nøglen **`TRE`**. (Vælger I en anden nøgle, så sæt
      repo-variablen `LINEAR_TEAM_KEY` under Settings → Secrets and variables → Actions → Variables.)
- [ ] Settings → Integrations → GitHub: forbind organisationen og repoet.
- [ ] Slå automatik til i holdets indstillinger (Workflows / Pull request automation):
      branch eller PR åbnet → **In Progress**, PR merget → **Done**.
- [ ] Opret labelen `spec`.
- [ ] Opret én startopgave pr. person: "Tilføj <navn> til holdet" (se `docs/holdet/README.md`).
- [ ] Opret opgaverne fra [5-dages-planen](5-dages-plan.md), eller lad `/to-tickets` gøre det.

Koblingen virker sådan: branch-navnet indeholder `tre-123`, så finder Linear selv PR'en.
`Fixes TRE-123` i PR'ens beskrivelse lukker opgaven ved merge. CI afviser en PR uden nummer.

## 3. Supabase (15 min)

- [ ] Opret projektet `treatr` i en region i EU (fx Frankfurt). Gem database-kodeordet i jeres password manager.
- [ ] Project Settings → Integrations → GitHub: forbind repoet. Mappe: `supabase`. Produktions-branch: `main`.
      Slå "Deploy to production" til. Så køres migrationer automatisk, når en PR merges. Det virker på alle planer.
- [ ] Authentication: slå tilmelding fra (kun inviterede medarbejdere), og slå e-mail-login til.
- [ ] Tjek at tabellerne er oprettet efter første merge (Table Editor). `seed.sql` køres **ikke** i produktion.
- [ ] Opret jeres egen organisation og første ejer i produktion (SQL Editor): en række i `organizations`,
      en bruger under Authentication, og en række i `organization_members` med rollen `owner`.

## 4. Supabase preview branches (betalt, 10 min)

- [ ] Opgradér organisationen til Pro.
- [ ] Samme sted som GitHub-integrationen: slå **Automatic branching** til.
- [ ] Åbn en test-PR, der rører en fil under `supabase/`. Tjekket `Supabase Preview` skal dukke op
      på PR'en og blive grønt. Branchen har demo-villaen fra `seed.sql`.
- [ ] Sæt et forbrugsloft, og aftal at lukke gamle PR'er. En åben branch koster cirka 0,30 USD i døgnet.

## 5. Vercel (15 min)

- [ ] Opret et projekt fra GitHub-repoet (kræver Pro for et hold og et privat organisations-repo). Framework: Next.js. Ingen ændringer i build-indstillinger.
- [ ] Installér Supabase-integrationen fra Vercels markedsplads, og forbind Supabase-projektet til
      Vercel-projektet. Så sættes `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` og
      `SUPABASE_SERVICE_ROLE_KEY` automatisk, også for hver preview. Tjek at navnene passer med `.env.example`.
- [ ] Tilføj selv `ANTHROPIC_API_KEY` og `APP_URL` under Environment Variables (Production og Preview).
- [ ] Åbn en test-PR. Vercel skriver en kommentar med et preview-link.
- [ ] Settings → Deployment Protection: lad previews kræve Vercel-login. Demo-kodeordet i `seed.sql` står i repoet.

## 6. Agent-skills i repoet (5 min)

- [ ] `claude plugin install mattpocock-skills@claude-plugins-official`
- [ ] Kør `/setup-matt-pocock-skills` én gang. Vælg **Other** → "Linear". Filerne findes allerede
      (`docs/agents/`), så bekræft bare. Sig nej til at tilføje et afsnit i `CLAUDE.md`.
- [ ] Start `claude`, godkend Linear-forbindelsen (`.mcp.json`), og prøv: "Vis mine opgaver i Linear".

## 7. Mattermost (5 min, valgfrit)

- [ ] Opret kanalerne `treatr-review` (links til PR'er) og `treatr-alarm`.
- [ ] Vil I have beskeder fra GitHub ind i Mattermost, så brug Mattermosts GitHub-plugin. Det er gratis.

## 8. Prøv hele kæden

- [ ] Gennemfør [Første dag](foerste-dag.md) selv, fra clone til merge. Tag tid. Målet er under 30 minutter.
- [ ] `npx supabase start` lokalt, og log ind med `owner@demo.treatr.test`. Det er første gang,
      skemaet møder en rigtig Supabase, så sig til, hvis noget fejler.
