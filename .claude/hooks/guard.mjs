#!/usr/bin/env node
// Claude Code-hook (PreToolUse). Stopper de få ting, en agent ALDRIG må gøre i dette repo.
// Exit 2 = handlingen blokeres, og teksten på stderr vises for agenten.
// Reglerne i AGENTS.md er vejledning. Dette er håndhævelse. CI er det sidste net.
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";

let input;
try {
  input = JSON.parse(readFileSync(0, "utf8"));
} catch {
  process.exit(0);
}

const block = (reason) => {
  console.error(`BLOKERET af .claude/hooks/guard.mjs: ${reason}`);
  process.exit(2);
};

const tool = input.tool_name;
const args = input.tool_input ?? {};
const root = process.env.CLAUDE_PROJECT_DIR || input.cwd || process.cwd();

if (tool === "Bash") {
  const cmd = String(args.command ?? "");

  const rules = [
    [
      /\bgit\s+push\b[^|;&]*\s(origin\s+)?(HEAD:)?(main|master)\b/,
      "Push ikke til main. Push din branch og åbn en pull request (gh pr create).",
    ],
    [
      /\bgit\s+push\b[^|;&]*\s(--force(?!-with-lease)|-f)\b/,
      "Brug ikke force push. Hvis det er nødvendigt på din egen branch: --force-with-lease, og spørg et menneske først.",
    ],
    [
      /\bgit\s+(commit|push)\b[^|;&]*\s(--no-verify|-n)\b/,
      "Spring ikke git-hooks over. Ret fejlen, som hooken peger på.",
    ],
    [/\bLEFTHOOK=0\b|\bHUSKY=0\b/, "Slå ikke git-hooks fra. Ret fejlen, som hooken peger på."],
    [
      /\bgh\s+pr\s+merge\b[^|;&]*--admin\b/,
      "Merge ikke uden om reglerne. Vent på grønne tjek og et review.",
    ],
    [
      /\bsupabase\s+(db\s+push|migration\s+repair|db\s+reset\s+[^|;&]*--(linked|db-url))\b/,
      "Rør ikke en rigtig Supabase-database fra en agent. Migrationer rulles ud af GitHub-integrationen, når PR'en merges.",
    ],
    [/\bsupabase\s+[^|;&]*--db-url\b/, "Rør ikke en rigtig Supabase-database fra en agent."],
    [
      /\bvercel\b[^|;&]*--prod\b/,
      "Deploy ikke til produktion fra en agent. Produktion deployes automatisk fra main.",
    ],
  ];
  for (const [pattern, reason] of rules) {
    if (pattern.test(cmd)) block(reason);
  }

  // git push uden mål, mens man står på main
  if (/\bgit\s+push\b/.test(cmd)) {
    try {
      const branch = execFileSync("git", ["rev-parse", "--abbrev-ref", "HEAD"], {
        cwd: root,
        stdio: ["ignore", "pipe", "ignore"],
      })
        .toString()
        .trim();
      if (branch === "main")
        block("Du står på main. Lav en branch (git switch -c tre-123-kort-navn) og push den.");
    } catch {
      // ikke et git-repo: intet at beskytte
    }
  }
}

if (tool === "Edit" || tool === "Write" || tool === "MultiEdit" || tool === "NotebookEdit") {
  const file = String(args.file_path ?? args.notebook_path ?? "");
  const rel = path.relative(root, path.resolve(root, file)).split(path.sep).join("/");

  if (/(^|\/)\.env(\.|$)/.test(rel) && !rel.endsWith(".env.example")) {
    block(
      "Skriv ikke i .env-filer. Secrets hører hjemme lokalt hos mennesket og i Vercel/Supabase. Nye variabelnavne skrives i .env.example.",
    );
  }

  if (/^supabase\/migrations\/.+\.sql$/.test(rel)) {
    try {
      execFileSync("git", ["cat-file", "-e", `origin/main:${rel}`], { cwd: root, stdio: "ignore" });
      block(
        `${rel} ligger allerede på main og må ikke ændres. Lav en ny migration: npx supabase migration new <navn>.`,
      );
    } catch {
      // filen findes ikke på origin/main: det er en ny migration, og den må gerne rettes
    }
  }
}

process.exit(0);
