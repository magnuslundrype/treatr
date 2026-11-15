# Sådan bidrager du til Treatr

Skrevet til dig, der aldrig har lavet en pull request før. De erfarne kan nøjes med tabellerne.

- Første gang? Følg [Første dag](docs/foerste-dag.md). Du har en merget PR på 30 minutter.
- Den daglige arbejdsgang står på én side: [Sådan arbejder vi](docs/saadan-arbejder-vi.md).
- Hvorfor tingene er, som de er: [ARCHITECTURE.md](ARCHITECTURE.md) og [docs/adr/](docs/adr/).

## Kort fortalt

1. Alt arbejde starter med en opgave i Linear.
2. Én opgave = én branch = én lille pull request.
3. Ingen skriver direkte i `main`. Alt går gennem en pull request med grønne tjek og ét review.
4. Agenten hjælper dig, men du læser og står inde for det, du sender.
5. Du kan ikke ødelægge noget vigtigt. Reglerne stopper dig, før det sker.

## Installation (én gang)

### Værktøjer

Git, Node 22+, GitHub CLI (`gh`), Docker Desktop og Claude Code. På Windows: brug WSL.

```bash
gh repo clone <organisation>/treatr
cd treatr
npm install          # sætter også git-hooks op
npm run check        # skal være grøn
```

### Agent-skills

Vi bruger Matt Pococks skills til arbejdsgangen. Installér dem som plugin, så opdaterer de sig selv:

```bash
claude plugin install mattpocock-skills@claude-plugins-official
```

Repoet beder også selv Claude Code om at slå pluginet til (`.claude/settings.json`), så du kan
blive spurgt, første gang du åbner mappen. Sig ja.

**Installér ikke samme samling på to måder.** Har du allerede kørt `npx skills add mattpocock/skills`,
ligger der kopier i `.claude/skills/` eller `~/.claude/skills/`, og så findes hver kommando to gange.
Slet kopierne, og behold pluginet.

`/setup-matt-pocock-skills` skal køres én gang pr. repo, ikke pr. person. Den, der sætter repoet
op, kører den og vælger **Other** som opgavesystem og skriver "Linear". Resultatet ligger allerede
her: `docs/agents/issue-tracker.md`, `docs/agents/domain.md` og afsnittet "Agent skills" i `AGENTS.md`.
Vil kommandoen tilføje afsnittet til `CLAUDE.md`, så sig nej. Det står i `AGENTS.md`, som `CLAUDE.md` henter ind.

Vi bruger kun fem kommandoer fra samlingen. Resten kan du lade ligge.

| Kommando                         | Hvornår                                                          |
| -------------------------------- | ---------------------------------------------------------------- |
| `/grill-me`                      | Før der bygges: afklar idéen                                     |
| `/to-spec`, `/to-tickets`        | Gør samtalen til opgaver i Linear                                |
| `/implement TRE-123`             | Byg én opgave, med tests                                         |
| `/mattpocock-skills:code-review` | Gennemgang: følger den reglerne, og gør den det, opgaven bad om? |
| `/retro`                         | Sidst på dagen: forbedr opsætningen                              |

Skriv det lange navn `/mattpocock-skills:code-review`. Claude Code har sin egen `/code-review`, som
er en anden kommando. Ekstra til de erfarne: `/diagnosing-bugs` til svære fejl og `/handoff`, når en
opgave skal videre til en ny session eller en kollega.

### Frontend-skill

Googles Modern Web Guidance ligger allerede i repoet (`.claude/skills/modern-web-guidance`), så
du skal ikke installere noget. Agenten bruger den selv, når den skriver HTML, CSS eller JavaScript
til browseren. Skal den geninstalleres eller opdateres:

```bash
DISABLE_TELEMETRY=1 npx skills add googlechrome/modern-web-guidance --skill modern-web-guidance
```

Telemetri er slået fra for alle i `.claude/settings.json` (`DISABLE_TELEMETRY=1`). Vores mål for
browsere er Baseline Widely available (se ADR-0012).

### Lokal database

```bash
cp .env.example .env.local
npx supabase start
npx supabase status      # kopiér nøglerne over i .env.local
npm run dev
```

`.env.local` kommer aldrig i git. Læg aldrig nøgler eller kodeord i en fil, der bliver committet.

## Reglerne, og hvem der håndhæver dem

Du skal ikke huske dem. Du bliver stoppet med en forklaring.

| Regel                                                    | Hvor du bliver stoppet                                |
| -------------------------------------------------------- | ----------------------------------------------------- |
| Ingen commits eller push på `main`                       | Git-hook hos dig, agent-hook, og GitHub (ruleset)     |
| Koden er formateret og uden lint-fejl                    | Git-hook hos dig retter selv. CI tjekker igen.        |
| Typer og tests består                                    | Git-hook ved push. CI.                                |
| Databasen kan bygges fra bunden, og RLS-testene består   | CI (`Migrationer og RLS`). Lokalt: `npm run db:test`. |
| En migration på `main` ændres aldrig                     | Agent-hook og CI                                      |
| Ingen secrets i git                                      | CI (gitleaks). Agent-hook stopper skrivning i `.env`. |
| PR'en har Linear-nummer, bevis og rollback               | CI (`PR-regler`)                                      |
| PR'en er under 800 linjer                                | CI (`PR-regler`). Under 200 er målet.                 |
| Mindst ét review. En erfaren ved database, CI og regler. | GitHub (ruleset og CODEOWNERS)                        |
| Kun squash merge, og branchen slettes bagefter           | GitHub-indstilling                                    |
| Agenten deployer ikke og rører ikke rigtige databaser    | Agent-hook                                            |

Hooks hos dig er en hjælp. Det er CI og GitHub, der har det sidste ord.

## Små PR'er vinder

| Label     | Linjer    | Hvad det betyder                                                           |
| --------- | --------- | -------------------------------------------------------------------------- |
| `size/XS` | under 50  | Reviewes først. Ofte merget på minutter.                                   |
| `size/S`  | under 200 | Reviewes først.                                                            |
| `size/M`  | under 400 | Fint, men overvej at dele.                                                 |
| `size/L`  | under 800 | Del den op, hvis du kan.                                                   |
| `size/XL` | 800+      | Afvises. En erfaren kan sætte `stor-pr-godkendt`, hvis det ikke kan deles. |

Labels sættes automatisk. Lockfiler og genererede filer tæller ikke med.

## Ændringer i databasen

1. `npx supabase migration new kort_navn` laver en ny fil i `supabase/migrations/`.
2. Skriv SQL i den. Kopiér mønsteret fra en tabel, der ligner, i `0001_init.sql`.
3. `npx supabase db reset` kører alle migrationer lokalt. `npm run db:test` tjekker reglerne.
4. Ændrer du en regel (RLS, statusmaskine, godkendelse), så ret eller tilføj en test i `tests/db/`.
5. Åbn en PR. En erfaren skal godkende den (CODEOWNERS).

Ret aldrig i en migration, der allerede er merget. Lav en ny, der ændrer det, du vil have ændret.
Skriv i Mattermost, når du går i gang med en migration, så to ikke laver hver sin samtidig.

## Når noget går galt

| Det sker                                         | Gør dette                                                                                                       |
| ------------------------------------------------ | --------------------------------------------------------------------------------------------------------------- |
| Jeg har lavet ændringer på `main`                | `git switch -c <navn fra Linear>`. Ændringerne følger med.                                                      |
| Jeg har committet på `main` (men ikke pushet)    | `git switch -c <navn fra Linear>`, derefter `git branch -f main origin/main`.                                   |
| CI er rød                                        | Åbn det røde job, kopiér de sidste linjer til agenten, og bed den rette. Kør `npm run check` lokalt.            |
| Format-tjekket fejler                            | `npm run format`, commit, push.                                                                                 |
| Min branch har konflikter med `main`             | `git fetch origin && git merge origin/main`, og bed agenten hjælpe med konflikterne. Spørg, hvis du er i tvivl. |
| Preview viser en fejl                            | Tjek at `Supabase Preview` er grøn på PR'en. Luk og genåbn PR'en for at få en frisk database.                   |
| Noget gik i stykker i produktion efter min merge | Tryk "Revert" på PR'en og merge den. Sig det i Mattermost. Find fejlen bagefter.                                |
| Jeg kom til at committe en nøgle                 | Sig det med det samme i Mattermost. Nøglen skal skiftes; det er ikke nok at slette den.                         |
