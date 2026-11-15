# Sådan arbejder vi

Én side. Fra idé til merget pull request. Følg trinnene i rækkefølge, så kan det ikke gå galt.

## De fem trin

| #   | Trin                  | Du skriver til agenten               | Hvad sker der                                                                                            | Færdig når                                |
| --- | --------------------- | ------------------------------------ | -------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| 1   | **Afklar idéen**      | `/grill-me`                          | Agenten stiller dig spørgsmål, til I er enige om, hvad der skal bygges. Du svarer. Der kodes ikke endnu. | Agenten har ikke flere spørgsmål.         |
| 2   | **Lav opgaver**       | `/to-spec` og derefter `/to-tickets` | Samtalen bliver til en beskrivelse og nogle små opgaver i Linear. Hver opgave kan laves på under en dag. | Opgaverne står i Linear med `TRE-` numre. |
| 3   | **Byg én opgave**     | `/implement TRE-123`                 | Agenten skriver en test først, så koden, og kører tjekkene. Kun den ene opgave.                          | `npm run check` er grøn.                  |
| 4   | **Få det gennemgået** | `/mattpocock-skills:code-review`     | To gennemgange: følger koden vores regler, og gør den det, opgaven bad om? Ret det, den finder.          | Ingen alvorlige fund tilbage.             |
| 5   | **Lær af dagen**      | `/retro`                             | Sidst på dagen: hvad drillede agenten? Resultatet er højst én lille forbedring af opsætningen.           | Én lille PR, eller "intet at ændre".      |

Mellem trin 4 og 5 åbner du en pull request. Det er dér, et menneske kigger med.

## Én opgave, fra start til slut

1. **Vælg en opgave i Linear** og sæt dig selv på. Tag kun én ad gangen.
2. **Kopiér branch-navnet fra Linear** (knappen "Copy git branch name", eller Ctrl/Cmd + Shift + .).
3. **Lav branchen:**
   ```bash
   git switch main && git pull
   git switch -c tre-123-det-kopierede-navn
   ```
4. **Byg** med `/implement TRE-123`. Læs med undervejs. Stop agenten, hvis den laver mere end opgaven.
5. **Gennemgå** med `/mattpocock-skills:code-review`, og læs selv hele ændringen igennem.
6. **Send den op:**
   ```bash
   git add -A
   git commit -m "TRE-123 Kort beskrivelse"
   git push -u origin HEAD
   ```
   Tryk på linket, som git viser, og udfyld skabelonen: opgave, hvad er ændret, bevis, rollback.
7. **Vent på grønne flueben.** Er noget rødt, så tryk på det, læs den sidste fejl, og bed agenten rette den.
8. **Bed om review** i Mattermost med et link til PR'en. Små PR'er bliver set først.
9. **Merge** (knappen "Squash and merge"), når der er et grønt review. Branchen slettes selv, Linear-opgaven lukkes selv, og ændringen går i produktion.

## Det, du ikke behøver at huske

Det her sker af sig selv, eller du bliver stoppet med en besked om, hvad der mangler:

- Du kan ikke pushe direkte til `main`.
- Koden bliver formateret, når du committer.
- Hver PR bliver tjekket: typer, lint, tests, database, secrets.
- Hver PR får sin egen prøveudgave af appen og sin egen database. Du kan ikke ødelægge rigtige data.
- En PR uden Linear-nummer, uden bevis eller på over 800 linjer bliver afvist.
- Ændringer i databasen og i reglerne kræver, at en erfaren godkender.

## Tre ting, du selv skal

1. **Start i Linear.** Ingen opgave, ingen kode.
2. **Hold det småt.** Under 200 linjer er godt. Er det større, så del opgaven.
3. **Læs det, agenten skrev.** Du har ansvaret for din PR, ikke agenten.

## Sidder du fast?

Sidder du fast i mere end 20 minutter, så skriv i Mattermost. Det er hurtigere for alle.
De erfarne har to ekstra værktøjer: `/diagnosing-bugs` til svære fejl og `/handoff` til at give
en opgave videre til en ny agent-session eller en kollega.
