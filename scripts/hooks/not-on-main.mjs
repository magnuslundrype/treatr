// Stopper commits og push direkte på main. Alt arbejde sker på en branch og går gennem en PR.
// (Gælder først når repoet har en main på GitHub, så den allerførste commit kan laves.)
import { execSync } from "node:child_process";

const git = (cmd) => {
  try {
    return execSync(`git ${cmd}`, { stdio: ["ignore", "pipe", "ignore"] })
      .toString()
      .trim();
  } catch {
    return "";
  }
};

const branch = git("rev-parse --abbrev-ref HEAD");
const mainExistsOnGitHub = git("rev-parse --verify --quiet refs/remotes/origin/main") !== "";

if (branch === "main" && mainExistsOnGitHub) {
  console.error(
    [
      "",
      "Du står på main. Her må man ikke committe eller pushe direkte.",
      "",
      "Gør sådan:",
      '  1. Åbn din opgave i Linear og tryk "Copy git branch name" (Ctrl/Cmd + Shift + .)',
      "  2. git switch -c <det-kopierede-navn>     fx tre-123-leverandoer-link",
      "  3. Commit igen. Dine ændringer følger med over på den nye branch.",
      "",
    ].join("\n"),
  );
  process.exit(1);
}
