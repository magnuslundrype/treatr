# Kørsel: Treatr-arkitektur (Fable 5.2)

Du arbejder i `/srv/work/treatr-architecture` (eget git-repo, kun lokale commits). Magnus er på vej til Spanien og har ikke computeren med; han kan følge med via Remote Control på telefonen. Hans beskeder vinder over denne fil.

Arbejd autonomt. Stil ingen spørgsmål undervejs: træf valgene selv, skriv antagelser og begrundelser ned. Ingen git push, intet deploy, ingen oprettelse af GitHub-repo, Vercel-projekt, Supabase-projekt eller Linear-workspace, ingen køb. Alt leveres som filer i denne mappe, klar til at blive lagt i holdets repo.

Kildemateriale ligger lokalt (MIT-licens): `input/mattpocock-skills/` og `input/karpathy-skills/CLAUDE.md`. Modern Web Guidance er installeret som skill (`.claude/skills/modern-web-guidance`); brug den til frontend-valg. Læs dem, før du skriver CLAUDE.md, AGENTS.md og CONTRIBUTING.md.

Verifikation (lean): migrationen skal kunne køres mod en lokal Postgres (`docker run --rm -d -p 55432:5432 -e POSTGRES_PASSWORD=x postgres:16`, stop den bagefter) med en lille RLS-test, der viser at en bruger fra organisation A ikke kan se data fra organisation B, og at et bekræftelses-token kun virker én gang. Workflows tjekkes med `actionlint` hvis det er nemt at hente, ellers yaml-syntaks. Mermaid skal være gyldigt. Ikke mere end det.

Når du er færdig: commit lokalt, skriv `REPORT.md` (kort på dansk: hvad der er lavet, antagelser, hvad holdet skal gøre første dag i Spanien som tjekliste, de 3 største risici) og til sidst filen `DONE` med `READY` eller `BLOCKED: <grund>`.

---

Du er lead-arkitekt for Treatr. Design den arkitektur, der passer bedst til os. Lav ikke hele appen.

PRODUKTET
Treatr er en AI-butler til luksusvillaer i Spanien. Gæsten skriver til butleren og bestiller service: kok, transport, rengøring, oplevelser, indkøb før ankomst. Butleren foreslår også mersalg. Fokus er service og mersalg, ikke dynamisk prissætning. Leverandøren bekræfter via et link uden login. Et menneske i back office godkender med to tryk, før noget bliver lovet til gæsten eller sendt til leverandøren. Pilot: Grandonklens villaer i sæson 2027, med menneske i loopet. Bagefter skal flere husejere og udlejningsbureauer kunne bruge det. Der er senere hardware i husene: Mac mini, tablet og Home Assistant.

HOLDET
Fem venner i én uge i Spanien (18.-23. nov), hvorefter vi arbejder videre hjemmefra. Nogle er erfarne udviklere, andre har aldrig lavet en pull request. Alle koder med AI-agenter (Claude Code m.fl.). Stakken er allerede valgt: GitHub, Vercel, Supabase og Linear. Vi snakker i Mattermost.

OPGAVE 1: AUTOMATISERET BRANCH-KONTROL (vigtigst)
Design et flow, hvor det er svært at gøre noget forkert, og hvor ingen skal huske regler:
- main er altid deploybar og beskyttet (GitHub rulesets): ingen direkte push, PR påkrævet, grønne checks, mindst ét review, squash merge, branches slettes automatisk.
- Linear-issue → branch-navn → PR kobles automatisk.
- Hver PR får sin egen Vercel-preview og sin egen Supabase preview branch med migrationer og seed-data, så ingen rører produktionsdata.
- CI i GitHub Actions: typecheck, lint, format, test, check af migrationer og en simpel sikkerhedsscan. Hurtigt, under 5 min.
- PR-skabelon, CODEOWNERS (fx kræver migrationer og RLS review af en erfaren) og labels efter størrelse. Små PR'er belønnes.
- En kort rettesnor for AI-agenter (AGENTS.md / CLAUDE.md i repoet), så agenterne følger samme regler.
- Et "første dag"-flow for en uerfaren: fra clone til første mergede PR på under 30 minutter.
Begrund hvert valg, og sig hvad vi bevidst springer over. Kun gratis eller indbyggede værktøjer. Betalte planer kun som klart markeret forslag.

OPGAVE 2: DATABASESTRUKTUR FOR DEN FULDE IDÉ
Supabase Postgres, multi-tenant fra dag 1 (organisation → villaer), RLS på alle tabeller. Dæk mindst: organisationer og roller (ejer, back office, concierge), villaer og deres faciliteter, gæster og ophold, samtaler og beskeder med butleren (inkl. AI-forslag og hvad mennesket rettede), servicekatalog og priser pr. villa, leverandører og hvad de tilbyder, bestillinger med en tydelig statusmaskine (forslag → godkendt → sendt → bekræftet af leverandør → leveret → afregnet), bekræftelseslinks (engangs-token, udløb, intet login), godkendelser med to tryk og hvem der trykkede, mersalg og hvad der virkede, betalinger og provision (kun struktur, ingen betalingsudbyder endnu), notifikationer, audit-log, flere sprog (es, en, da) og GDPR (sletning af gæstedata efter ophold). Gør plads til Home Assistant-hændelser, uden at bygge det nu.

OPGAVE 3: KVALITETSFLOW MED AGENTER (simpelt, ikke teknisk)
Byg et fast flow ind i repoet, som alle følger uden at skulle tænke over det:
- Grundregler fra Karpathy (github.com/forrestchang/andrej-karpathy-skills, MIT): læg de fire principper (tænk før du koder, simpelt først, kirurgiske ændringer, mål du kan tjekke) ind i repoets CLAUDE.md og AGENTS.md, sammen med vores projektregler. Kopiér ikke blindt: tilpas til Treatr og hold filen kort.
- Arbejdsgang fra Matt Pocock (github.com/mattpocock/skills, MIT). Brug kun disse 5 trin: /grill-me (afklar idéen før der bygges) → /to-spec og /to-tickets (til Linear) → /implement (én opgave ad gangen, med tests) → /code-review (følger regler + gør hvad opgaven bad om) → /retro (sidst på dagen, forbedr opsætningen). Nævn diagnosing-bugs og handoff som ekstra værktøj til de erfarne.
- Beskriv installationen én gang i CONTRIBUTING.md: `claude plugin install mattpocock-skills@claude-plugins-official`, derefter `/setup-matt-pocock-skills` med Linear som opgavesystem. Advar mod at installere samme samling på to måder.
- PR-skabelonen skal spejle flowet: link til Linear-opgave, hvad er ændret, bevis for at det virker, og om ændringen er nem eller svær at rulle tilbage.
- Lav en én-sides "Sådan arbejder vi" på dansk i hverdagssprog, som en uerfaren kan følge fra idé til merget PR.
- Frontend: brug Googles Modern Web Guidance (github.com/GoogleChrome/modern-web-guidance, Apache-2.0) til al HTML/CSS/klient-JS, så agenterne bruger moderne, tilgængelige browserfunktioner frem for gamle mønstre. Installér med `npx skills add googlechrome/modern-web-guidance --skill modern-web-guidance`, sæt DISABLE_TELEMETRY=1, og vælg et Baseline-mål.
- Brug hooks eller CI til det, der SKAL ske hver gang (tests, lint, migrations-check). CLAUDE.md er kun vejledning.

LEVERANCER (i repoet)
1. ARCHITECTURE.md: overblik, diagram (mermaid), dataflow for én bestilling fra gæstens besked til leverandørens bekræftelse.
2. docs/adr/: korte beslutninger, én pr. fil.
3. ERD i mermaid + supabase/migrations/0001_init.sql med tabeller, enums, indeks, RLS-policies og seed-data for én demo-villa.
4. .github/: rulesets beskrevet som JSON eller trin, workflows, PR-skabelon, CODEOWNERS.
5. CONTRIBUTING.md på dansk i hverdagssprog til den uerfarne, plus AGENTS.md til agenterne.
6. En plan for de 5 dage: hvad hver person kan tage parallelt uden at træde hinanden over tæerne.

REGLER FOR DIG
- Start med højst 8 åbne spørgsmål om idéen, og antag et svar på hvert, så du kan arbejde videre. Skriv antagelserne øverst i ARCHITECTURE.md.
- Vælg modne, almindelige værktøjer tæt på standard. Hellere simpelt og robust end smart.
- Ingen secrets i repoet. Brug .env.example.
- Slut med en kort liste: hvad der er klar, hvad der mangler, og de 3 største risici.
