---
name: factory-engineering
description: Configures factory engineering across IDEs. Syncs .claude/commands and .claude/skills to where each IDE expects them (Cursor and GitHub Copilot read .claude/skills directly; Windsurf, Kilo Code, and Antigravity need copies for skills; Cursor and others need copies for commands). Default method copies files; symlinks available as fallback via --method=symlink. Syncs .claude/commands to GitHub Copilot prompt files (.github/prompts/*.prompt.md) for VS Code. Use when configuring slash commands or skills across IDEs, setting up .cursor/commands or .windsurf/workflows from .claude/commands, syncing commands for Copilot, or unifying command and skill folders.
---

# Factory Engineering

One skill for configuring commands, workflows, and skills across IDEs. Canonical locations: **`.claude/commands/`** (commands and workflows), **`.claude/skills/`** (skills).

**Installation:** `npx openskills install factoryengineering/skills`. Then ask the agent to sync IDE folders or sync Copilot prompts as needed.

---

## When to use

- **Sync (copy — recommended):** User wants slash commands or skills to work in Cursor, Windsurf, Kilo Code, or Antigravity from a single canonical folder. The sync script copies files from `.claude/commands` and `.claude/skills` to IDE-specific locations. Cursor and GitHub Copilot read `.claude/skills/` directly—no skills copy for them; the script creates skill copies only for Windsurf, Kilo Code, and Antigravity.
- **Sync (symlink — legacy fallback):** Same as above but using symlinks instead of copies. Use only when explicitly requested. Known issues: Cursor symlink bug, Windows Developer Mode requirement, inconsistent file-watching, cross-platform Git problems.
- **Sync Copilot prompts:** User uses GitHub Copilot (VS Code) and wants `/command-name` in Chat. Copilot uses `.github/prompts/*.prompt.md`, not `.claude/commands/*.md`. Sync converts commands to prompt files.

For Copilot commands, use sync (symlinks do not apply).

---

## Sync (copy)

Primary workflow, script options, conflict resolution, and mapping tables: **[sync.md](sync.md)**.

Run scripts from the **repository root**. Bash: `scripts/sync-ide.sh`. PowerShell: `scripts/Sync-Ide.ps1`. Use `--detect` / `-Detect` to list IDEs before syncing; use `--copy-existing` / `-CopyExisting` to merge existing target folders into the canonical folder first. Use `--dry-run` / `-DryRun` to preview changes. Use `--migrate` / `-Migrate` to convert existing symlinks to copies.

**Pre-commit hook:** Install `scripts/pre-commit-sync.sh` as `.git/hooks/pre-commit` to auto-sync before each commit.

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
