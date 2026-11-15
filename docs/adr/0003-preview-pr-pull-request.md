# Hver pull request får sin egen app og sin egen database

Ingen skal røre produktionsdata for at teste. Vercel laver en preview af appen for hver pull request, og Supabase Branching laver en frisk database til samme PR med alle migrationer og `supabase/seed.sql`. Supabase-integrationen til Vercel sætter selv previewens miljøvariabler, så de to passer sammen. Når PR-en merges, kører Supabase migrationerne mod produktion, og Vercel deployer `main`.

Det koster penge (tjekket 15. november 2026): Supabase Branching kræver Pro (25 USD om måneden plus cirka 0,013 USD i timen pr. åben branch), og Vercel kræver Pro (20 USD pr. plads pr. måned) for at et hold kan deploye fra et privat organisations-repo.

**Gratis fallback, som virker fra første dag:** hver PR får stadig sin egen database, bare i CI: jobbet `Migrationer og RLS` bygger en tom Postgres, kører alle migrationer og seed, og tester reglerne. Lokalt bruger man `npx supabase start`. Beviset i PR-en er så et skærmbillede fra ens egen maskine i stedet for et preview-link.

## Considered Options

- **Ét fælles staging-miljø:** billigere, men fem mennesker og deres agenter ville dele én database, og en halv migration fra én PR ville vælte de andre.
- **Egne Supabase-projekter pr. udvikler:** gratis-planen tillader for få projekter, og de pauses ved inaktivitet.

## Consequences

- Seed-data er opdigtet og må aldrig indeholde rigtige gæster. Demo-kodeordet i `seed.sql` giver adgang til previews, så previews må kun indeholde seed.
- Migrationer skal kunne køre, mens den gamle kode stadig er i luften (tilføj først, fjern senere), fordi database og app ikke deployes i samme øjeblik.
- En migration, der er merget, ændres aldrig. CI og en hook håndhæver det.
