@AGENTS.md

## Kun for Claude Code

- Reglerne står i `AGENTS.md` ovenfor, så alle agenter læser det samme. Ret dem dér, ikke her.
- Hooken `.claude/hooks/guard.mjs` blokerer push til main, force push, `--no-verify`, ændring af
  mergede migrationer, skrivning i `.env`-filer og kommandoer mod produktion. Bliver du
  blokeret, så følg beskeden.
- Review-regler, som kun er relevante ved gennemsyn, står i `CODING_STANDARDS.md` (læses af `/code-review`).
