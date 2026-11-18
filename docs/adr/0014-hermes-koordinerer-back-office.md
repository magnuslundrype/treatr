# Hermes driver back office og godkender selv inden for regler, databasen håndhæver

Status: besluttet af Magnus 18/11/2026. Ændrer ADR-0010 og antagelse 3. Erstatter Sensei-rettelsen samme dag ("Hermes koordinerer, men godkender ikke"): uden ret til at godkende kan Hermes ikke vedligeholde driften.

Back office er Hermes. Den kører opgaver hele vejen igennem (e2e), også godkendelsen, når opgaven ligger inden for de regler, databasen håndhæver. Alt uden for reglerne eskaleres til et menneske, som godkender med to tryk (ADR-0007).

Hermes hører hjemme i back office og ikke hos gæsten: hukommelse om leverandører og drift er en fordel, mens gæsten skal mødes af en forudsigelig butler, der glemmer ved checkout (ADR-0016).

## Sådan godkender Hermes uden at tømme to-tryks-reglen

- **Reglerne ligger i databasen, ikke i Hermes.** En tabel med regler pr. organisation (fx kategori, maks. beløb, kendt leverandør, inden for kataloget, tidsrum). Hermes kalder en funktion som `agent_approve()`, som selv tjekker reglerne og afviser alt andet. Hermes kan aldrig kalde `tap_approval()`, som forbliver menneskets to tryk.
- **Hermes har sin egen rolle,** fx `agent`, som en almindelig Supabase Auth-bruger. Aldrig `service_role`. Login'et kan spærres på sekunder, hvis Mac mini'en forsvinder (ADR-0017).
- **Nødbremse:** én kontakt pr. organisation slår al automatisk godkendelse fra. Så går alt til to tryk igen.
- **Loft:** et maks. antal og beløb pr. døgn for Hermes' godkendelser.
- **Sporbarhed:** hver godkendelse fra Hermes står i audit-loggen med regel og begrundelse, så grænsen kan flyttes på data.

## Eksempler på opgaver Hermes kører e2e

- Bestilling fra kataloget til katalogpris hos en kendt leverandør: godkend, send brief, følg op, bekræft til gæsten.
- Leverandøren siger nej: tilbyd næste mulighed i samme kategori og prisleje.
- Ombooking eller aflysning inden for leverandørens egne vilkår.
- Drift af husene: overvåg Pi'erne, genstart, opdatér, sig til ved fejl.

Altid eskaleret: uden for kataloget, klager, ny leverandør, afvigende pris eller tid, alt med penge, alt der rører alarm, lås eller kameraer.

## Afklares i Spanien

- Den første liste over regler (hvilke kategorier, hvilke beløbsgrænser).
- Hvem der må ændre reglerne (forslag: kun `owner`, med to tryk).

## Consequences

- Kræver én ny migration (spor A): rolle `agent`, regeltabel, `agent_approve()`, nødbremse, loft og tests i CI. Indtil den er merget, kræver databasen to tryk på alt, også for Hermes.
- Spor B bygger eskaleringskøen frem for en kø, hvor alt passerer.
- Skemaets nuværende garanti "AI'en kan kun foreslå" bliver til "AI'en kan kun godkende inden for regler, databasen håndhæver".
