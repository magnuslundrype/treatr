# Første dag: fra clone til din første mergede PR

Målet er, at du har en ændring i `main` inden for 30 minutter, og at du har prøvet hele
flowet én gang. Opgaven er med vilje lille: du tilføjer dig selv til holdet.

## Hjemmefra (inden du rejser)

Det her tager tid at hente, så gør det på godt internet:

- [ ] Git: `git --version` virker
- [ ] Node 22 eller nyere: `node --version` viser v22 eller højere
- [ ] GitHub CLI: `gh --version` virker, og `gh auth login` er gennemført
- [ ] Claude Code (eller den agent, du bruger): `claude --version` virker
- [ ] Docker Desktop er installeret (bruges først efter din første PR)
- [ ] Du har sagt ja til invitationerne til GitHub, Linear og Mattermost

Bruger du Windows, så arbejd i WSL (Ubuntu). Så virker alle kommandoer som beskrevet.

## De 30 minutter

| Tid   | Trin                                |
| ----- | ----------------------------------- |
| 0-5   | 1. Hent koden                       |
| 5-8   | 2. Installér agentens værktøjer     |
| 8-10  | 3. Tjek at alt er grønt             |
| 10-12 | 4. Find din opgave og lav en branch |
| 12-18 | 5. Lav ændringen                    |
| 18-22 | 6. Send den op som pull request     |
| 22-30 | 7. Grønne flueben, review og merge  |

### 1. Hent koden (5 min)

```bash
gh repo clone <organisation>/treatr
cd treatr
npm install
```

`npm install` sætter også de lokale git-hooks op. Du skal ikke gøre mere.

### 2. Installér agentens værktøjer (3 min)

```bash
claude plugin install mattpocock-skills@claude-plugins-official
```

Start derefter `claude` i mappen og sig ja, når den spørger om projektets indstillinger og
om Linear. Første gang åbner Linear et login i din browser.

Installér ikke den samme samling på andre måder (fx `npx skills add mattpocock/skills`). Så
får du alle kommandoer to gange.

### 3. Tjek at alt er grønt (2 min)

```bash
npm run check
```

Du skal se, at typecheck, lint, format og test består. Gør de ikke det, så sig til i Mattermost,
inden du går videre. Det er ikke dig, der har gjort noget forkert.

### 4. Find din opgave og lav en branch (2 min)

I Linear ligger en opgave til dig: **"Tilføj <dit navn> til holdet"**. Åbn den, sæt dig selv
på, og tryk "Copy git branch name".

```bash
git switch -c <det-kopierede-navn>
```

Navnet ligner `tre-7-tilfoej-anna-til-holdet`. Nummeret er det, der kobler alt sammen.

### 5. Lav ændringen (6 min)

Skriv til agenten:

```
/implement TRE-7
```

Opgaven beder om en ny fil, `docs/holdet/<dit-fornavn>.md`, med dit navn, hvad du gerne vil
lave i ugen, og hvad du helst vil have hjælp til. Læs, hvad agenten skrev, og ret det, så det er dine ord.

Vil du hellere gøre det i hånden, så opret filen selv. Det er lige så godt.

### 6. Send den op (4 min)

```bash
git add -A
git commit -m "TRE-7 Tilføj Anna til holdet"
git push -u origin HEAD
```

Git viser et link. Tryk på det. Du lander på en side med en skabelon:

- **Linear-opgave:** skriv `Fixes TRE-7`
- **Hvad er ændret:** "Tilføjer mig selv til holdet."
- **Bevis for at det virker:** indsæt et skærmbillede af filen, eller skriv "npm run check er grøn hos mig"
- **Rollback:** sæt kryds ved "Nem"

Tryk "Create pull request".

### 7. Grønne flueben, review og merge (8 min)

1. Nederst på siden kører tjekkene. Vent, til `CI` og `PR-regler` er grønne (et par minutter).
   Er `PR-regler` rød, står der præcis, hvad der mangler i beskrivelsen. Ret den, så kører tjekket igen.
2. Skriv i Mattermost: "Min første PR: <link>". En af de andre trykker "Approve".
3. Tryk **"Squash and merge"**. Færdig.

Kig i Linear: din opgave har selv flyttet sig til "Done".

```bash
git switch main && git pull
```

Nu er du klar til en rigtig opgave. Læs [Sådan arbejder vi](saadan-arbejder-vi.md).

## Bagefter: få appen op at køre lokalt (10-20 min, mest ventetid)

```bash
cp .env.example .env.local
npx supabase start        # første gang henter den en del. Docker Desktop skal køre.
npx supabase status       # kopiér "API URL", "anon key" og "service_role key" over i .env.local
npm run dev
```

Åbn http://localhost:3000. Databasen har en demo-villa og tre demo-logins (se toppen af
`supabase/seed.sql`). Vil du starte forfra med databasen: `npx supabase db reset`.

## Hvis noget driller

| Det sker                              | Gør dette                                                                                         |
| ------------------------------------- | ------------------------------------------------------------------------------------------------- |
| "Du står på main" når du committer    | Lav en branch: `git switch -c <navn fra Linear>`. Dine ændringer følger med.                      |
| `git push` bliver afvist              | Du er nok på `main`. Se ovenfor.                                                                  |
| `PR-regler` er rød                    | Tryk på den og læs beskeden. Det er altid Linear-nummer, bevis, rollback eller størrelse.         |
| `CI` er rød                           | Tryk på det røde job, læs de sidste linjer, og giv dem til agenten: "CI fejler med dette: ..."    |
| Agenten siger "BLOKERET af guard.mjs" | Den prøvede noget, den ikke må. Læs beskeden. Det er som regel en fejl i dens plan, ikke hos dig. |
| `npx supabase start` fejler           | Kører Docker Desktop? Ellers skriv i Mattermost. Du kan godt lave din første PR uden.             |
