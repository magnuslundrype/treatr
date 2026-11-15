# Domain Docs

Sådan bruger agent-skills repoets domæne-dokumentation.

## Læs disse, før du udforsker koden

- **`GLOSSARY.md`** i roden: Treatrs fagord på dansk, med navnet i koden i parentes.
- **`docs/adr/`**: læs de ADR'er, der handler om det område, du skal arbejde i.
- **`ARCHITECTURE.md`** og **`docs/erd.md`**: overblik og datamodel.

Layoutet er single-context: én `GLOSSARY.md` og én `docs/adr/` for hele repoet.

## Brug glossarets ord

Når du nævner et begreb i en opgave, en test, et variabelnavn eller en besked til mennesket,
så brug ordet fra `GLOSSARY.md`. Brug ikke de synonymer, glossaret fraråder (fx "booking" om
et ophold eller "ordre" om en bestilling). I kode bruges det engelske navn fra parentesen.

Mangler der et ord, er det et signal: enten er du ved at opfinde sprog, projektet ikke bruger,
eller også er der et hul. Nævn det for mennesket.

## Sig til, hvis du går imod en ADR

Går dit forslag imod en ADR, så sig det tydeligt i stedet for at overskrive den i stilhed:

> _Går imod ADR-0007 (to tryk i databasen), men det er værd at tage op igen, fordi…_

Nye ADR'er er korte: en titel og 1-3 sætninger om, hvad vi besluttede og hvorfor. Skriv kun en,
når beslutningen er svær at lave om, overraskende uden forklaring, og et reelt valg mellem alternativer.
