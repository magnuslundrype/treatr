# Flere sprog: jsonb med es, en og da i samme kolonne

Katalog, faciliteter og husregler skal findes på spansk, engelsk og dansk. Oversat indhold gemmes i kolonner, der ender på `_i18n`, som et jsonb-objekt med nøglerne `es`, `en` og `da`. SQL-funktionen `i18n()` og `pickLocale()` i TypeScript henter teksten med samme fallback: ønsket sprog, så engelsk, spansk, dansk. Knapper og faste tekster i appen ligger i appens egne sprogfiler.

En separat oversættelsestabel er mere fleksibel, men kræver et join for hver tekst og er sværere at seede og rette i hånden. Med tre sprog er jsonb enklest.

## Consequences

- Gæster, leverandører og medarbejdere har hver et `locale`. Leverandøren får sin bekræftelsesside på sit sprog (spansk som standard), uanset gæstens sprog.
- Samtaler gemmes på gæstens sprog. Oversættelse til back office sker ved visning og gemmes ikke.
- Et fjerde sprog kræver en ændring af enum-typen `locale_code` og af tjekket `is_i18n()`.
