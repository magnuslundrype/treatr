# Gæster og leverandører har links med token, ikke login

En gæst på ferie og en kok i Marbella skal ikke oprette en konto. Gæsten får et personligt chat-link, og leverandøren får et bekræftelseslink. Alt, hvad de gør, går gennem vores serverkode, som slår tokenet op og bruger `service_role`. Database-rollen `anon` har ingen rettigheder overhovedet, så API-et kan ikke bruges uden login.

Bekræftelseslinket: tokenet er 244 bit tilfældigt, kun en SHA-256-hash gemmes, det udløber (72 timer som standard), og det virker præcis én gang. Et nyt link til samme bestilling gør det gamle ugyldigt.

## Consequences

- **At åbne linket må ikke bekræfte noget.** WhatsApp, mailprogrammer og virusscannere åbner links på forhånd. Derfor viser GET kun siden (`peek_confirmation_link`), og først et tryk på knappen (POST) bruger tokenet (`redeem_confirmation_link`).
- Engangs-garantien ligger i databasen: én `UPDATE ... WHERE used_at IS NULL` kan kun lykkes én gang, også ved to samtidige tryk.
- Serverkoden med `service_role` er det farligste sted i systemet, fordi RLS ikke gælder der. Den samles i `src/lib/supabase/` og `src/app/c/`, som CODEOWNERS kræver en erfaren til at godkende.
- Begrænsning af antal forsøg (rate limiting) hører hjemme i serverkoden på `/c/` og `/g/` og er ikke bygget endnu.
- Ringer leverandøren i stedet, kan back office selv sætte status. Historikken viser, hvem der gjorde det.
