# Frontend: moderne, indbyggede browserfunktioner med Baseline Widely available som mål

Agenter skriver ofte HTML, CSS og JavaScript, som var god skik for fem år siden. Vi bruger Googles Modern Web Guidance (Apache-2.0) som skill, så agenten slår op, før den skriver: `<dialog>` i stedet for hjemmelavede modaler, indbygget formularvalidering, container queries og tilgængelighed fra start. Skillen ligger i repoet under `.claude/skills/modern-web-guidance`, så alle får den ved clone.

Målet er **Baseline Widely available**: funktioner, der har virket i alle store browsere i mindst to et halvt år, bruges uden videre. Nyere funktioner (Baseline Newly available) må bruges, hvis siden stadig virker uden dem. Polyfills tilføjes ikke.

Det mål er valgt, fordi gæster bruger deres egen telefon, leverandører ofte en ældre Android, og tabletten i huset styrer vi ikke endnu.

## Consequences

- Bekræftelsessiden til leverandøren skal virke uden JavaScript: en almindelig formular med to knapper.
- Telemetri er slået fra med `DISABLE_TELEMETRY=1` i `.claude/settings.json`.
- Tailwind bruges til styling, fordi det følger med Next.js og er det, agenter kender bedst. Modern Web Guidance bestemmer stadig, hvilke HTML-elementer og browserfunktioner der bruges.
