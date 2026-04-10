# IDE Sync

Canonical **commands and workflows** live in **`.claude/commands/`**. Canonical **skills** live in **`.claude/skills/`**. Each IDE looks in different folders. The sync script copies files from canonical folders to IDE-specific locations so one set of files works everywhere.

**Supported IDEs:** Cursor, Windsurf, Kilo Code, Antigravity. Cursor and GitHub Copilot read `.claude/skills/` directly—no skills sync needed. For Copilot commands, use the separate sync workflow (see [sync-copilot-prompts.md](sync-copilot-prompts.md)).

**Why copy instead of symlink?** Symlinks have known issues: Cursor directory symlinks may not work ([documented bug](https://github.com/factoryengineering/skills/issues/1)), Windows requires Developer Mode for symlinks (often restricted in corporate environments), file-watching breaks in some IDEs with symlinked directories, and Git handles symlinks inconsistently across platforms. Copying avoids all of these. Symlinks remain available as a fallback via `--method=symlink`.

---

## Workflow for the agent

1. **Ensure canonical folders exist.** From the repository root: `mkdir -p .claude/commands .claude/skills` if needed.

2. **Determine which IDEs to support.**
   - If the user specified IDEs (e.g. "just Cursor"), use that list.
   - If not, **detect:** run the script with `--detect`. It checks for `.cursor`, `.windsurf`, `.kilocode`, `.agent` in the repo root.
   - If you detected IDEs, **confirm with the user** before proceeding; list them and ask which should receive synced files.

3. **Check for existing targets.** For each selected IDE:
   - **Existing symlink:** If a target is a symlink (from a previous setup), offer to convert it with `--migrate`.
   - **Non-canonical files:** If a target directory has files not present in the canonical folder, inform the user. Offer to merge them into canonical with `--copy-existing`.

4. **Sync files.** From repo root: Bash `scripts/sync-ide.sh` or PowerShell `scripts/Sync-Ide.ps1`. Pass IDEs (e.g. `--ide cursor,windsurf` or `-Ide "cursor,windsurf"`). Use `--type all` (default) for both commands and skills; `--type commands` or `--type skills` for one. Use `--dry-run` / `-DryRun` to preview.

5. **Set up ongoing sync** (recommend one):
   - **Pre-commit hook** (recommended): Install `scripts/pre-commit-sync.sh` as `.git/hooks/pre-commit` to auto-sync before each commit.
   - **Manual sync:** Re-run the script after changing canonical files.

6. **Commit.** Recommend committing synced files and any new files under `.claude/commands` or `.claude/skills`.

---

## Scripts

Run from the **repository root** (or pass `--repo-root` / `-RepoRoot`).

### Bash: `scripts/sync-ide.sh`

| Goal | Command |
|------|---------|
| Detect installed IDEs | `bash path/to/skill/scripts/sync-ide.sh --detect` |
| Sync all (copy) | `bash path/to/skill/scripts/sync-ide.sh --ide cursor,windsurf` |
| Sync commands only | `bash path/to/skill/scripts/sync-ide.sh --type commands --ide cursor` |
| Preview changes | `bash path/to/skill/scripts/sync-ide.sh --dry-run --ide cursor,windsurf` |
| Merge non-canonical files | Add `--copy-existing` |
| Migrate from symlinks | Add `--migrate` |
| Use symlinks (legacy) | Add `--method=symlink` |
| Non-repo root | `--repo-root /path/to/repo` |

### PowerShell: `scripts/Sync-Ide.ps1`

| Goal | Command |
|------|---------|
| Detect | `.\scripts\Sync-Ide.ps1 -Detect` |
| Sync all (copy) | `.\scripts\Sync-Ide.ps1 -Ide "cursor,windsurf"` |
| Sync commands only | `.\scripts\Sync-Ide.ps1 -Type commands -Ide cursor` |
| Preview changes | `.\scripts\Sync-Ide.ps1 -DryRun -Ide "cursor,windsurf"` |
| Merge non-canonical files | `-CopyExisting` |
| Migrate from symlinks | `-Migrate` |
| Use symlinks (legacy) | `-Method symlink` |
| Require symlinks (no junction) | `-NoJunctionFallback` (only with `-Method symlink`) |
| Repo root | `-RepoRoot C:\path\to\repo` |

PowerShell note: quote the IDE list (`-Ide "cursor,kilocode"`).

### Pre-commit hook: `scripts/pre-commit-sync.sh`

Auto-syncs canonical folders to IDE directories before each commit.

**Install:**

```bash
cp path/to/skill/scripts/pre-commit-sync.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

Or append the body of the script to an existing pre-commit hook.

---

## Sync mapping

**Commands and workflows** (canonical: `.claude/commands/`):

| IDE | Target (copy destination) | Source |
|-----|---------------------------|--------|
| Cursor | `.cursor/commands/` | `.claude/commands/` |
| Windsurf | `.windsurf/workflows/` | `.claude/commands/` |
| Kilo Code | `.kilocode/workflows/` | `.claude/commands/` |
| Antigravity | `.agent/workflows/` | `.claude/commands/` |

**Skills** (canonical: `.claude/skills/`). Cursor and GitHub Copilot read this path directly—no sync needed.

| IDE | Target (copy destination) | Source |
|-----|---------------------------|--------|
| Windsurf | `.windsurf/skills/` | `.claude/skills/` |
| Kilo Code | `.kilocode/skills/` | `.claude/skills/` |
| Antigravity | `.agent/skills/` | `.claude/skills/` |

Antigravity requires `.agent` to exist; the scripts create it when needed.

---

## Conflict resolution

When an IDE-specific folder contains files that don't exist in the canonical folder:

1. The script warns about each non-canonical file.
2. Use `--copy-existing` / `-CopyExisting` to merge them into the canonical folder before syncing.
3. Files merged into canonical become the source of truth for all IDEs.

---

## Migration from symlinks

If your project currently uses symlinks from a previous setup:

1. Run with `--migrate` / `-Migrate` plus `--ide <your-ides>` to convert symlinks to copies.
2. The script removes the symlink and copies canonical folder contents to the target directory.
3. Use `--dry-run` / `-DryRun` with `--migrate` to preview before making changes.

---

## Symlink fallback

Symlinks remain available via `--method=symlink` / `-Method symlink` for backward compatibility. Known issues:

- **Cursor:** Directory symlinks have a documented bug and may not function.
- **Windows:** Requires Developer Mode or elevated privileges; often restricted in corporate environments.
- **File watching:** Inconsistent behavior across IDEs with symlinked directories.
- **Git:** Cross-platform symlink handling is unreliable.

Use copy (the default) unless you have a specific reason for symlinks. See [symlinks.md](symlinks.md) for the legacy symlink-only workflow and the original setup scripts.
