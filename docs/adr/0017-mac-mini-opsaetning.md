# Mac mini: back office i Docker via Colima, to brugere, styres over Tailscale

Status: besluttet af Magnus 18/11/2026. Bygger på ADR-0014 til 0016.

## Beslutning

- **Ingen diskkryptering (FileVault fra),** så Mac'en starter og logger ind af sig selv efter et strømsvigt.
- **Brugeren `treatr`** (administrator, automatisk login) kører kun back office. Intet personligt Apple-id.
- **Back office kører i Docker:** Hermes som Treatrs egen profil i en container (`restart: unless-stopped`), samme opskrift som Brian (én compose-fil, imaget findes til arm64).
- **Colima i stedet for Docker Desktop.** Docker Desktop kører kun for én bruger ad gangen og starter først med en app. Colima er gratis, uden app, bruger de samme kommandoer og compose-filer og giver hver bruger sin egen Docker. Den startes som `brew services` for `treatr`, så den kører ved login.
- **Brugeren `magnus`** til VS Code og Claude Code med eget login under turen, med sin egen Colima. Slettes efter turen, så intet personligt bliver liggende.
- **Fjernadgang via Tailscale:** SSH og Skærmdeling. Anker arbejder på maskinen via SSH. Magnus' private Anker installeres ikke på Mac mini'en.
- Back office kører videre, mens en anden bruger er logget ind, så længe `treatr` ikke logges ud. Med 16 GB RAM er der plads til to Docker-miljøer samtidig.

## Afklares i Spanien

- Hvilken AI-model Hermes kører på, og hvem der betaler (en del af beslutningen om ejerskab).
- Hvor Hermes eskalerer til et menneske (fx en fælles Telegram-gruppe eller Mattermost).
- Hvem ejer Tailscale-netværket på sigt.

## Consequences

- Uden kryptering kan disken læses, hvis maskinen bliver stjålet. Derfor kun nøgler med begrænset adgang på maskinen, og de skiftes straks, hvis den forsvinder.
- Holdets egne laptops behøver heller ikke Docker Desktop: Colima på Mac, Docker Desktop med WSL på Windows. Test `npx supabase start` første dag.
- Ingen ændring i databasen.
