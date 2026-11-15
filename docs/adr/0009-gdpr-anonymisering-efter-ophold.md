# GDPR: gæstedata anonymiseres efter opholdet, og loggen gemmer aldrig fritekst

Gæstens persondata skal væk efter opholdet, men bestillinger og beløb skal blive af hensyn til bogføring og statistik over mersalg. Funktionen `purge_expired_guest_data()` kører dagligt og anonymiserer gæster, hvis seneste ophold sluttede for mere end organisationens frist siden (30 dage som standard): navn, mail og telefon fjernes, beskedernes tekst tømmes, og fritekst på bestillinger slettes. Rækkerne bliver.

Audit-loggen må ikke blive en bagdør til de slettede data. Derfor logger den aldrig beskeder, og for bestillinger og gæster udelader den fritekst-felterne. Loggen kan hverken rettes eller slettes.

## Consequences

- Det er antaget, at husejeren eller bureauet er dataansvarlig, og Treatr er databehandler. Fristen på 30 dage og hvad der må gemmes til bogføring, skal bekræftes af en jurist, før piloten får rigtige gæster.
- Samtaler sendes til en AI-udbyder. Det kræver en databehandleraftale og skal stå i privatlivsteksten til gæsten.
- "Hvad mennesket rettede" bevares som et ja/nej (`was_edited`) efter anonymisering, men selve teksterne forsvinder. Vil vi lære af rettelserne, skal det ske inden fristen.
- En gæst kan bede om sletning før tid: `gdpr_requests` registrerer det, og `anonymize_guest()` udfører det.
- Det daglige job er ikke sat op endnu.
