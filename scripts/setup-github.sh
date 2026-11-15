#!/usr/bin/env bash
# Sætter GitHub-repoet op, så reglerne håndhæves af GitHub og ikke af hukommelsen.
# Køres én gang af en administrator (og igen, hvis .github/rulesets/main.json ændres).
#
#   gh auth login
#   bash scripts/setup-github.sh
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
echo "Repo: $REPO"

echo "== Kun squash merge, slet branch efter merge"
gh api -X PATCH "repos/$REPO" \
  -F allow_squash_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true \
  -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY >/dev/null

echo "== Auto-merge (merger selv, når review og tjek er grønne)"
gh api -X PATCH "repos/$REPO" -F allow_auto_merge=true >/dev/null \
  || echo "   Kunne ikke slås til (kræver betalt plan på private repoer). Fortsætter."

echo "== Ruleset for main"
existing=$(gh api "repos/$REPO/rulesets" -q '.[] | select(.name == "main er beskyttet") | .id' 2>/dev/null || true)
if [ -n "$existing" ]; then
  gh api -X PUT "repos/$REPO/rulesets/$existing" --input .github/rulesets/main.json >/dev/null && echo "   Opdateret."
elif gh api -X POST "repos/$REPO/rulesets" --input .github/rulesets/main.json >/dev/null; then
  echo "   Oprettet."
else
  echo "   FEJL: GitHub afviste rulesettet. På et privat repo kræver det GitHub Team (organisation)"
  echo "   eller GitHub Pro (personlig konto). Se .github/rulesets/README.md."
  exit 1
fi

echo "== Færdig. Tjek: Settings → Rules → Rulesets, og prøv 'git push origin main' (skal blive afvist)."
