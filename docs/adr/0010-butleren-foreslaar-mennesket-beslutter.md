# Butleren foreslår, mennesket beslutter

AI-butleren kører på serveren og kalder Claude gennem Anthropics API med gæstens besked, villaens katalog, priser og husmanual. Den kan kun gøre to ting: skrive en kladde til et svar (`messages` med status `draft`) og oprette et forslag til en bestilling eller et mersalg (`bookings` med status `proposed`, `upsell_offers` med status `suggested`). Den sender aldrig selv noget til en gæst eller en leverandør.

Det er valgt, fordi en forkert lovet kok eller en forkert pris er dyrere end et par minutters ventetid, og fordi piloten netop skal vise, hvor ofte mennesket retter. Databasen håndhæver det (ADR-0007), så en fejl i prompten ikke kan sende noget ud.

## Consequences

- Vi gemmer både AI-forslaget og det, mennesket sendte. Det er datagrundlaget for senere at lade butleren svare selv på de sikre spørgsmål (fx wifi-koden).
- Priser kommer fra kataloget, aldrig fra modellen. Butleren vælger en service, og prisen slås op.
- Modellen og prompt-versionen gemmes på hver besked (`ai_model`, `ai_meta`), så vi kan sammenligne.
