---
name: factory-engineering
description: Configures factory engineering across IDEs. Syncs .claude/commands and .claude/skills to where each IDE expects them (Cursor and GitHub Copilot read .claude/skills directly; Windsurf, Kilo Code, and Antigravity need copies for skills; Cursor and others need copies for commands). Default method copies files; symlinks available as fallback via --method=symlink. Syncs .claude/commands to GitHub Copilot prompt files (.github/prompts/*.prompt.md) for VS Code. Use when configuring slash commands or skills across IDEs, setting up .cursor/commands or .windsurf/workflows from .claude/commands, syncing commands for Copilot, or unifying command and skill folders.
---

# Factory Engineering

One skill for configuring commands, workflows, and skills across IDEs. Canonical locations: **`.claude/commands/`** (commands and workflows), **`.claude/skills/`** (skills).

**Installation:** `npx openskills install factoryengineering/skills`. Then ask the agent to sync IDE folders or sync Copilot prompts as needed.

---

## When to use

- **Sync (copy — recommended):** User wants slash commands or skills to work in Cursor, Windsurf, Kilo Code, or Antigravity from a single canonical folder. The sync script uses two phases: reverse-sync gathers changes from IDE locations into canonical, then forward-sync mirrors canonical to all targets. Edits made in any IDE folder are preserved. Cursor and GitHub Copilot read `.claude/skills/` directly—no skills sync for them; the script syncs skills only for Windsurf, Kilo Code, and Antigravity.
- **Sync (symlink — legacy fallback):** Same as above but using symlinks instead of copies. Use only when explicitly requested. Known issues: Cursor symlink bug, Windows Developer Mode requirement, inconsistent file-watching, cross-platform Git problems.
- **Sync Copilot prompts:** User uses GitHub Copilot (VS Code) and wants `/command-name` in Chat. Copilot uses `.github/prompts/*.prompt.md`, not `.claude/commands/*.md`. Sync converts commands to prompt files.

For Copilot commands, use sync (symlinks do not apply).

---

## Sync (copy)

Primary workflow, two-phase sync details, and mapping tables: **[sync.md](sync.md)**.

Run scripts from the **repository root**. Bash: `bash path/to/skill/scripts/sync-ide.sh`. PowerShell: `path/to/skill/scripts/Sync-Ide.ps1`. After installation the skill lives at `.claude/skills/factory-engineering/`. Use `--detect` / `-Detect` to list IDEs before syncing. Use `--dry-run` / `-DryRun` to preview changes. Use `--migrate` / `-Migrate` to convert existing symlinks to copies. Changes in any IDE folder are automatically gathered into canonical before syncing out.

**Pre-commit hook:** Install `path/to/skill/scripts/pre-commit-sync.sh` as `.git/hooks/pre-commit` to auto-sync before each commit.

---

## Symlinks (legacy fallback)

Symlink-only workflow and original scripts: **[symlinks.md](symlinks.md)**.

Symlinks are available via `--method=symlink` in the new sync scripts, or via the original `setup-symlinks.sh` / `Setup-Symlinks.ps1` scripts. Use only when explicitly requested—copy is the default and recommended approach.

---

## Sync commands to GitHub Copilot

Workflow, frontmatter rules, and batch script: **[sync-copilot-prompts.md](sync-copilot-prompts.md)**.

Prompt file spec (fields, variables, tips): **[references/prompt-files-spec.md](references/prompt-files-spec.md)**.

Batch sync from repo root: `python path/to/skill/scripts/sync_copilot_prompts.py [REPO_ROOT]`.

---

## Reference

- Project docs: `src/content/docs/commands.md`, `src/content/docs/skills.md`, `src/content/docs/workflows.md`.
