# Beskyttelse af main

`main.json` er hele reglen for `main`, klar til import. Den gør dette:

| Regel                                                | Hvorfor                                                        |
| ---------------------------------------------------- | -------------------------------------------------------------- |
| Ingen direkte push, ingen force push, ingen sletning | main er altid deploybar                                        |
| Pull request påkrævet, kun squash merge              | én commit pr. opgave, nem at rulle tilbage med "Revert"        |
| Mindst 1 godkendelse, og den bortfalder ved ny push  | ingen kan snige ændringer ind efter review                     |
| CODEOWNERS skal godkende deres filer                 | migrationer, RLS og CI ses af en erfaren                       |
| Alle kommentarer skal være løst                      | review bliver ikke ignoreret                                   |
| Tjekkene `CI` og `PR-regler` skal være grønne        | typecheck, lint, format, test, migrationer, secrets, størrelse |
| Ingen undtagelser (`bypass_actors` er tom)           | heller ikke for administratorer                                |

## Slå det til (2 minutter)

Nemmest med scriptet, som også sætter squash merge og automatisk sletning af branches:

```bash
gh auth login
bash scripts/setup-github.sh
```

Eller i hånden: Settings → Rules → Rulesets → New ruleset → **Import a ruleset** → vælg `main.json`.

## Det koster penge på et privat repo

GitHub håndhæver kun rulesets, CODEOWNERS og påkrævede reviews på private repoer, når ejeren
betaler (tjekket 15. nov. 2026):

- **Organisation: GitHub Team, 4 USD pr. bruger pr. måned** (5 personer = 20 USD). Anbefalet.
- Personlig konto: GitHub Pro, 4 USD pr. måned for ejeren. Billigst, men repoet hænger på én person.
- Offentligt repo: gratis, men så er koden offentlig.

Uden betaling virker alt andet stadig: CI kører, PR-skabelonen bruges, lokale hooks stopper
commits på main, og workflowet `Main-vagt` opretter en alarm, hvis noget alligevel lander på
main uden en PR. Men GitHub **forhindrer** det ikke. Se ADR-0002.

## Ændringer

Ret `main.json` i en PR (CODEOWNERS kræver en erfaren), og kør `bash scripts/setup-github.sh`
igen efter merge. Scriptet opdaterer det eksisterende ruleset.
