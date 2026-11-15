# Multi-tenant: organization_id på alle tabeller, RLS og sammensatte fremmednøgler

Flere husejere og bureauer skal kunne bruge Treatr uden at se hinandens data. Alle tabeller har `organization_id`, RLS er slået til overalt, og policies bruger tre faste mønstre: medlem, leder (ejer og back office) og ejer. Medlemskab slås op gennem funktioner i skemaet `private`, som ikke er udstillet i API-et.

Derudover peger børnetabeller på deres forælder med en sammensat fremmednøgle `(organization_id, forælder_id)`. Så kan en bestilling i organisation A ikke pege på en villa i organisation B, heller ikke når koden kører med `service_role`, som går uden om RLS.

## Considered Options

- **Kun `organization_id` på toppen (villa) og join i hver policy:** færre kolonner, men langsommere policies og nemmere at lave en fejl i.
- **Et skema eller en database pr. kunde:** stærk adskillelse, men Supabase og migrationer bliver besværlige, og det er for tungt til en pilot.
- **Organisationen som claim i brugerens login-token:** hurtigt, men en bruger, der fjernes fra en organisation, beholder adgang, indtil tokenet udløber.

## Consequences

- Nye tabeller skal følge mønsteret. CI afviser dem ellers.
- `organization_id` gentages i alle tabeller. Det er prisen for enkle og hurtige policies.
- En organisation kan ikke slettes, kun arkiveres (`archived_at`), fordi audit-loggen peger på den.
