# Én Next.js-app på Vercel med Supabase som eneste backend

Stakken (GitHub, Vercel, Supabase, Linear) var valgt på forhånd. Vi bygger én Next.js-app (App Router, TypeScript) i roden af repoet, med npm som pakkehåndtering, og bruger Supabase til database, login og realtime. Ingen monorepo, ingen separate tjenester, ingen ORM: SQL-migrationer er sandheden, og appen bruger Supabase-klienten med genererede typer.

Fem personer med blandet erfaring og AI-agenter får mest ud af den opsætning, som har flest eksempler og færrest dele. npm er valgt frem for pnpm, fordi det følger med Node og ikke kræver et ekstra installationstrin for en nybegynder.

## Consequences

- Back office, gæstechat og bekræftelsesside ligger i samme app og deployes samlet. Det er bevidst: én preview viser hele flowet.
- Baggrundsarbejde (påmindelser, GDPR-oprydning, afsendelse af beskeder) kører som Vercel Cron og læser tabellen `notifications` som udbakke. Bliver det for småt, er en kø det næste skridt.
- Next.js 16 har ændret sig i forhold til det, agenter typisk husker. `AGENTS.md` beder dem læse dokumentationen i `node_modules/next/dist/docs/` først.
