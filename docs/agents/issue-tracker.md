# Issue tracker: Linear

Opgaver og specs for dette repo ligger i Linear, i holdet med nøglen `TRE`. Brug Linears
MCP-server (`linear` i `.mcp.json`; første gang beder den om login i browseren). Brug ikke
GitHub Issues og ikke `gh issue`.

## Conventions

- **Opret en opgave**: brug Linear-værktøjet til at oprette en issue i holdet `TRE` med titel
  og beskrivelse i markdown. Skriv på dansk.
- **Læs en opgave**: hent den på sit ID (fx `TRE-123`), inklusive beskrivelse og kommentarer.
- **Underopgave**: sæt forælder-opgaven som `parent`, når du opretter den.
- **Blokering**: brug Linears egen relation "blocked by". Kan relationen ikke sættes, så skriv
  `Blokeret af: TRE-12, TRE-13` øverst i beskrivelsen.
- **Kommentar**: tilføj en kommentar på opgaven. Brug det til spørgsmål og til at notere, hvad der blev besluttet.
- **Status**: lad Linear styre den. En branch med opgavens ID sætter den i gang, og en merget
  pull request lukker den. Flyt ikke selv en opgave til "Done".
- **Labels**: vi bruger ikke triage-labels. Opgaver, en agent kan tage, ligger i kolonnen "Todo".

## Kobling til git

- Branch-navnet skal indeholde opgavens ID: `tre-123-kort-navn`. Hent navnet fra opgaven i Linear
  ("Copy git branch name"), eller byg det af ID og en kort titel med små bogstaver og bindestreger.
- Pull requestens beskrivelse indeholder `Fixes TRE-123`. Så kobler Linear selv PR'en til
  opgaven og lukker den ved merge.
- Én opgave pr. pull request. CI afviser en PR uden et `TRE-` ID i branch-navn eller titel.

## When a skill says "publish to the issue tracker"

Opret en issue i Linear-holdet `TRE`. En spec fra `/to-spec` bliver én issue med labelen `spec`.
Opgaver fra `/to-tickets` bliver underopgaver af spec'en, oprettet i rækkefølge, så blokeringer kan pege på rigtige ID'er.

## When a skill says "fetch the relevant ticket"

Hent issuen fra Linear på dens ID, med beskrivelse og kommentarer.

## Hvis Linear ikke er tilgængelig

Sig det til mennesket og stop. Opret ikke opgaver som filer i repoet.
