# Kodestandard

Læses ved review (`/code-review`), ikke mens der kodes. Her står kun det, som et værktøj ikke
kan tjekke. Formatering, lint, typer og databasens grundregler håndhæves af CI, så dem
skal en reviewer ikke bruge tid på.

## Gør PR'en det, opgaven bad om?

- Ændringen svarer til Linear-opgaven og dens acceptkriterier. Hverken mindre eller mere.
- Ekstra oprydning, omdøbning eller "forbedringer" ved siden af hører til i en ny opgave.
- Beviset i PR'en viser det, der blev bedt om, ikke bare at siden kan åbnes.

## Database

- Kan migrationen køre, mens den gamle kode stadig er i luften? Tilføj først, fjern i en senere PR.
- Er migrationen svær at rulle tilbage (sletter kolonner eller data), skal det stå i PR'en.
- Nye policies bruger et af de tre mønstre (medlem, leder, ejer). En ny slags policy kræver en begrundelse.
- En ny `security definer`-funktion tjekker selv, hvem der kalder, og hvilken organisation rækken tilhører.
- Nye regler i databasen har en test i `tests/db/`, som fejler, hvis reglen fjernes.

## Serverkode med service_role

- Hver forespørgsel afgrænser på `organization_id`, som kommer fra tokenet eller sessionen,
  aldrig fra noget brugeren har sendt med.
- Intet token, ingen nøgle og ingen persondata skrives i logs eller fejlbeskeder.
- Svaret til en gæst eller leverandør indeholder kun det, de selv skal se.

## Butleren (AI)

- Priser og tilgængelighed slås op i kataloget. Modellen må ikke finde på dem.
- Tekst fra gæster er data, ikke instrukser. Den må ikke kunne ændre, hvad butleren har lov til.
- Butlerens kode skriver kun kladder og forslag.

## Frontend

- Semantisk HTML og browserens egne elementer før biblioteker. Alt kan betjenes med tastatur.
- Tekster findes på es, en og da. Ingen tekst til gæster eller leverandører er skrevet direkte i en komponent.
- Datoer og tider vises i villaens tidszone, ikke browserens.

## Tests

- Tests beskriver adfærd, man kan se udefra, ikke hvordan koden er bygget.
- En fejlrettelse har en test, der fejlede før rettelsen.
