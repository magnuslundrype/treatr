# Et fast flow for agenter: fem trin, og hooks og CI til det, der skal ske hver gang

Alle på holdet koder med AI-agenter. For at holde kvaliteten ens bruger vi fire grundregler fra Andrej Karpathy (tænk før du koder, simpelt først, kirurgiske ændringer, mål du kan tjekke) og fem trin fra Matt Pococks skills: `/grill-me`, `/to-spec` og `/to-tickets`, `/implement`, `/code-review`, `/retro`. Begge er MIT-licenserede. Reglerne står kort i `AGENTS.md`, og `CLAUDE.md` henter den ind, så der kun er ét sted at rette.

Tekst i en fil er vejledning, som en agent kan overse. Alt, der skal ske hver gang, er derfor håndhævet et andet sted: lokale git-hooks, en Claude Code-hook, CI og rulesettet.

## Consequences

- Matt Pococks samling installeres som plugin (opdaterer sig selv). Den må ikke også installeres med `npx skills add`, for så findes alle skills to gange.
- Vi bruger kun de fem trin. Resten af samlingen (triage, wayfinder, tdd som selvstændig kommando osv.) er installeret, men ikke en del af vores flow. `diagnosing-bugs` og `handoff` er ekstra værktøj til de erfarne.
- Opgaver ligger i Linear, som samlingen ikke har indbygget støtte for. `docs/agents/issue-tracker.md` beskriver, hvordan agenten bruger Linear gennem Linears MCP-server.
- `/retro` sidst på dagen ender i højst én lille PR, der forbedrer opsætningen. Sådan vokser reglerne kun, når der er en grund.
