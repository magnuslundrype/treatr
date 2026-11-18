# Hardware i piloten: Pi som hub, Mac mini som back office, iPad og Jabra til stemmen

Status: besluttet af Magnus 18/11/2026. Hardwaren er købt. Præciserer ADR-0013 og ADR-0014.

| Enhed                     | Hvor                          | Rolle                                                                                                                          |
| ------------------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Raspberry Pi              | I villaen                     | Hub og indgang til husets netværk. Smart home-funktioner (Home Assistant) kører her og skriver til `devices` og `home_events`. |
| Mac mini                  | Med hjem til Danmark          | Server og back office. Hermes kører her og koordinerer (ADR-0014).                                                             |
| iPad                      | I villaen                     | Gæstens skærm i kiosk-mode.                                                                                                    |
| Jabra konferencehøjttaler | I villaen, koblet til iPad'en | Mikrofon og højttaler til stemmesamtalen, så hele rummet kan tale med huset.                                                   |

Smart home bliver en stor del af produktet. Derfor er Pi'en husets faste punkt, mens Mac mini'en ikke står i villaen.

## Afklares i Spanien

- **Netværk:** Pi'en er hub og gateway, men bør ikke selv være husets wifi-sender. Dens indbyggede wifi rækker ikke over en villa. Brug husets router eller et mesh-net til dækning, og lad Pi'en styre og overvåge.
- **Forbindelse Pi og Mac mini:** et privat netværk (fx Tailscale) mellem villa og Danmark, så intet i villaen er åbent mod internettet.
- **Hvis Mac mini'en er nede:** gæsten skal stadig kunne tale med butleren. Butleren kører i skyen (ADR-0001), og kun back office-koordineringen venter.
- **Mikrofon:** push-to-talk på iPad'en eller Jabraens knap, ikke en mikrofon der lytter hele tiden (vurderingen 2/11).

## Consequences

- Ingen ændring i databasen. `devices` og `home_events` findes allerede (ADR-0013).
- `devices` skal kunne registrere Pi, iPad og Jabra pr. villa.
