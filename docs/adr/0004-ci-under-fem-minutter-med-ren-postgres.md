# CI på under fem minutter, med databasen testet på en ren Postgres

CI kører tre job samtidig: app (typecheck, lint, format, test), database (migrationer, seed og RLS-tests) og sikkerhed (gitleaks og `npm audit`). Database-jobbet bruger en almindelig Postgres-container plus en lille fil, der efterligner Supabases roller og `auth`-skema (`tests/db/00_supabase_shim.sql`), i stedet for at starte hele Supabase.

Hele Supabase i CI tager flere minutter at hente og starte. Den rene Postgres er klar på sekunder, og det er de samme SQL-filer, der kører lokalt med `npm run db:test`. Testene er skrevet i almindelig SQL uden ekstra værktøjer, så en nybegynder kan læse dem.

## Consequences

- Efterligningen er ikke Supabase. Det, der kun findes hos Supabase (Auth-serveren, API-laget, realtime), testes ikke i CI. Med Supabase Branching kører de rigtige migrationer desuden på en rigtig preview branch for hver PR.
- `tests/db/50_schema_rules.sql` er vores migrations-tjek: den afviser nye tabeller uden RLS, uden `organization_id`, uden policy, med rettigheder til `anon`, eller uden indeks på fremmednøgler.
- Sikkerhedsscanningen er bevidst simpel og gratis. GitHubs egen secret scanning og CodeQL er kun gratis på offentlige repoer.
