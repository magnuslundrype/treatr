# Hardware i husene: plads i skemaet nu, integration senere

Hardwaren er nu valgt i ADR-0015: en Raspberry Pi som hub i villaen (Home Assistant), en iPad og en Jabra-højttaler, mens Mac mini'en står som back office-server i Danmark. Vi bygger ingen integration nu, men to tabeller findes allerede: `devices` (hvad der står i hvilken villa) og `home_events` (rå hændelser med tidspunkt og jsonb-indhold). Samtaler har kanalen `tablet`, og mersalg har udløseren `home_event`.

Det koster næsten ingenting at reservere pladsen nu, og det betyder, at de første hændelser kan gemmes uden en ny migration. Alt derudover (hvordan huset taler med os, hvad butleren må styre) venter, til piloten har vist, hvad der er brug for.

## Consequences

- Kun serveren må skrive hændelser. Medarbejdere kan læse dem for deres egen organisation.
- Bliver `home_events` stor, skal den partitioneres på `occurred_at` og have en slettefrist.
- Hændelser fra et hus kan være persondata (hvornår nogen er hjemme). Det skal med i GDPR-vurderingen, før det tages i brug.
