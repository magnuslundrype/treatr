# Statusmaskinen og to-tryks-godkendelsen håndhæves i databasen

Løftet til kunden er, at et menneske godkender, før noget loves til gæsten eller sendes til en leverandør. Det løfte må ikke afhænge af, at al app-kode (og alle agenter) husker reglen. Derfor ligger den i Postgres: en trigger tillader kun bestemte statusskift, en bestilling kan kun blive `approved` gennem `tap_approval()` kaldt to gange, og en AI-besked kan ikke få status `sent` uden en godkendelse.

Godkendelsen oprettes automatisk, når en bestilling eller en AI-kladde oprettes. Begge tryk gemmes med hvem og hvornår, sammen med et øjebliksbillede af det, der blev godkendt. Ændres pris, tid eller leverandør efter første tryk, starter godkendelsen forfra. Efter godkendelsen er de felter låst.

## Considered Options

- **Regler i app-koden:** nemmere at skrive, men én glemt kontrol i en ny side bryder løftet, og det opdages ikke.
- **To forskellige personer altid:** sikrere, men i piloten sidder der ofte kun én i back office. Det er en indstilling pr. organisation (`require_two_approvers`).

## Consequences

- Beskeder, et menneske selv skriver, kræver ikke godkendelse: mennesket er allerede i loopet.
- Vil man ændre en godkendt bestilling, annullerer man og laver et nyt forslag. Det er bevidst besværligt.
- Reglerne er dækket af `tests/db/30_booking_flow.sql`. Ændres statusmaskinen, ændres testen i samme PR.
