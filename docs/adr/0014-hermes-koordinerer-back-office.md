# Hermes koordinerer back office og eskalerer kun det, den ikke selv kan

Status: besluttet af Magnus 18/11/2026. Detaljerne fastlægges i Spanien. Ændrer ADR-0010 og antagelse 3.

Back office er ikke et menneske, der godkender alt. Det er Hermes, som koordinerer alt, den kan: leverandørbriefs, opfølgning, påmindelser, næste mulighed ved afslag. Et menneske får kun det, Hermes eskalerer, fordi den ikke selv kan eller ikke må.

Hermes hører hjemme i back office og ikke hos gæsten (vurderingen 2/11): hukommelse om leverandører og drift er en fordel, mens gæsten skal mødes af en forudsigelig butler, der glemmer ved checkout.

## Afklares i Spanien

- Hvad må Hermes selv (fx bestillinger i kataloget til katalogpris hos en kendt leverandør), og hvad eskaleres altid (uden for kataloget, klager, ny leverandør, afvigende pris eller tid, alt med penge).
- Hvordan Hermes optræder i databasen: som godkender for de sikre kategorier, så `tap_approval()` og statusmaskinen (ADR-0007) bliver sikkerhedsnettet, og eskaleringskøen bliver den menneskelige godkendelseskø.

## Consequences

- Indtil det er bygget, kræver databasen stadig to tryk på alt. Intet er ændret i skemaet.
- Spor B bygger eskaleringskøen frem for en kø, hvor alt passerer.
- Vi gemmer stadig, hvad Hermes gjorde, og hvad mennesket rettede, så grænsen kan flyttes på data.
