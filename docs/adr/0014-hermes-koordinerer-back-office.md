# Hermes koordinerer back office og eskalerer kun det, den ikke selv kan

Status: besluttet af Magnus 18/11/2026. Detaljerne fastlægges i Spanien. Ændrer ADR-0010 og antagelse 3. Præciseret efter Sensei-review 18/11: Hermes koordinerer, men godkender ikke.

Back office er ikke et menneske, der godkender alt. Det er Hermes, som koordinerer alt, den kan: leverandørbriefs, opfølgning, påmindelser, næste mulighed ved afslag. Et menneske får kun det, Hermes eskalerer, fordi den ikke selv kan eller ikke må.

Hermes hører hjemme i back office og ikke hos gæsten (vurderingen 2/11): hukommelse om leverandører og drift er en fordel, mens gæsten skal mødes af en forudsigelig butler, der glemmer ved checkout.

## Afklares i Spanien

- Hvad må Hermes selv (fx bestillinger i kataloget til katalogpris hos en kendt leverandør), og hvad eskaleres altid (uden for kataloget, klager, ny leverandør, afvigende pris eller tid, alt med penge).
- Hermes optræder i databasen som en almindelig bruger med rollen `concierge`: den læser samtaler og opretter forslag, men kan ikke kalde `tap_approval()` og rører ingen penge. Automatisk godkendelse af sikre kategorier (katalogpris, kendt leverandør) bliver en regel i databasen i en ny migration, ikke en rettighed hos Hermes. ADR-0007 gælder dermed ordret, også for Hermes.

## Consequences

- Indtil det er bygget, kræver databasen stadig to tryk på alt. Intet er ændret i skemaet.
- Spor B bygger eskaleringskøen frem for en kø, hvor alt passerer.
- Vi gemmer stadig, hvad Hermes gjorde, og hvad mennesket rettede, så grænsen kan flyttes på data.
- Hermes har aldrig `service_role`. På Mac mini'en ligger kun et concierge-login, som kan spærres i Supabase Auth, hvis maskinen forsvinder (ADR-0017).
