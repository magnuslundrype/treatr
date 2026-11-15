# main beskyttes af et GitHub-ruleset, med et gratis sikkerhedsnet under

`main` skal altid kunne deployes. Reglerne ligger som kode i `.github/rulesets/main.json`: ingen direkte push, pull request påkrævet, ét review, CODEOWNERS for database og CI, kun squash merge, og to påkrævede tjek (`CI` og `PR-regler`). Ingen kan gå uden om, heller ikke administratorer.

GitHub håndhæver kun rulesets, CODEOWNERS og påkrævede reviews på private repoer, når ejeren betaler (tjekket 15. november 2026). Derfor to spor med de samme filer:

- **Anbefalet (betalt): GitHub Team, 4 USD pr. bruger pr. måned.** Så er reglerne umulige at bryde.
- **Gratis:** alt det, der ikke kræver betaling, virker stadig. CI og PR-regler kører og viser rødt, lokale git-hooks (lefthook) stopper commits og push på main, en Claude Code-hook stopper agenter, og workflowet `Main-vagt` opretter en alarm, hvis noget lander på main uden en PR. Det opdager fejl, men forhindrer dem ikke.

## Considered Options

- **Klassisk branch protection:** samme betalingskrav, og kan ikke ligge som en fil i repoet.
- **Offentligt repo:** gratis rulesets og gratis secret scanning, men koden bliver offentlig. Det er en forretningsbeslutning, ikke en teknisk.
- **Personlig konto med GitHub Pro (4 USD i alt):** billigst, men repoet hænger på én person, og der findes ingen teams til CODEOWNERS.
- **Kræve at branchen er opdateret før merge, eller merge queue:** fravalgt. Det giver ventetid for et lille hold, og merge queue kræver en dyrere plan. I stedet kører CI igen på `main` efter hver merge.

## Consequences

- Kun ét tjek pr. workflow er påkrævet (`CI` samler de tre job). Nye job kan tilføjes uden at røre rulesettet.
- Et review bortfalder, når der pushes igen. Det koster et ekstra klik, men ingen kan ændre koden efter godkendelsen.
- Små PR-er belønnes ved at være hurtigst at få igennem: labels `size/XS` til `size/XL` sættes automatisk, og over 800 linjer afvises, medmindre en erfaren sætter `stor-pr-godkendt`.
