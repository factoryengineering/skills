# Factory Engineering Skills

Skills for setting up and maintaining a [Factory Engineering](https://factoryengineering.dev) software factory across AI-assisted IDEs.

## Install

```bash
npx openskills install factoryengineering/skills
```

This installs both skills into `.claude/skills/` in your project. Claude Code, Cursor, and GitHub Copilot read `.claude/skills/` directly. Windsurf, Kilo Code, and Antigravity need a copy of the skills folder.

**Bash (macOS/Linux):**

```bash
# Detect installed IDEs
bash .claude/skills/factory-engineering/scripts/sync-ide.sh --detect

# Sync to all detected IDEs (copies files from .claude/ to IDE folders)
bash .claude/skills/factory-engineering/scripts/sync-ide.sh --ide windsurf,kilocode,antigravity
```

**PowerShell (Windows):**

```powershell
# Detect installed IDEs
.\.claude\skills\factory-engineering\scripts\Sync-Ide.ps1 -Detect

# Sync to all detected IDEs
.\.claude\skills\factory-engineering\scripts\Sync-Ide.ps1 -Ide "windsurf,kilocode,antigravity"
```

Sync only for the IDEs your team uses, then commit the copied files. After that, ask your agent to sync command folders or Copilot prompts as needed.

**Manual alternative** (if you prefer not to use the script):

```bash
# Windsurf
mkdir -p .windsurf/skills && cp -R .claude/skills/. .windsurf/skills/

# Kilo Code
mkdir -p .kilocode/skills && cp -R .claude/skills/. .kilocode/skills/

# Antigravity
mkdir -p .agent/skills && cp -R .claude/skills/. .agent/skills/
```

> **Migrating from symlinks?** If you previously used symlinks, run the sync script with `--migrate` to convert them to copies. See the [migration guide](skills/factory-engineering/sync.md#migration-from-symlinks).

## Skills

### factory-engineering

Cross-IDE configuration for commands, workflows, and skills. Establishes `.claude/commands/` and `.claude/skills/` as canonical locations and copies files to IDE-specific folders so every IDE finds them.

**Sync mapping (commands):**

| IDE | Destination | Source |
|-----|-------------|--------|
| Cursor | `.cursor/commands/` | `.claude/commands/` |
| Windsurf | `.windsurf/workflows/` | `.claude/commands/` |
| Kilo Code | `.kilocode/workflows/` | `.claude/commands/` |
| Antigravity | `.agent/workflows/` | `.claude/commands/` |

**Sync mapping (skills):**

| IDE | Destination | Source |
|-----|-------------|--------|
| Windsurf | `.windsurf/skills/` | `.claude/skills/` |
| Kilo Code | `.kilocode/skills/` | `.claude/skills/` |
| Antigravity | `.agent/skills/` | `.claude/skills/` |

Cursor and GitHub Copilot read `.claude/skills/` directly — no skills copy needed.

**GitHub Copilot** uses `.prompt.md` files in `.github/prompts/`, so commands are synced (converted) rather than copied. A Python script handles the conversion.

**Keeping files in sync:** Install the pre-commit hook to auto-sync before each commit:

```bash
cp .claude/skills/factory-engineering/scripts/pre-commit-sync.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

Or re-run the sync script manually after changing canonical files.

**After installing, ask your agent:**

> Sync my commands and skills to Cursor and Windsurf.

The agent reads the factory-engineering skill, detects your IDEs, and runs the sync script. It will confirm before making changes and offer to merge existing content into the canonical folders if needed.

For GitHub Copilot, ask:

> Sync my commands to GitHub Copilot prompt files.

### skill-optimizer

Audits an existing skill against authoring best practices from the [Agent Skills](https://agentskills.io) open standard. Checks core quality, structure, scripts, and testing. Use after creating a skill with [skill-creator](https://github.com/anthropics/skills) to tighten and verify it.

## How It Fits Together

Factory Engineering organizes AI-assisted development into three layers:

| Layer | What it encodes | Stored in | Invoked with |
|-------|-----------------|-----------|--------------|
| **Skills** | Domain knowledge and standards | `.claude/skills/` | Auto-loaded by the agent |
| **Commands** | Repeatable single-agent task instructions | `.claude/commands/` | `/command @artifact` |
| **Workflows** | Multi-agent orchestration with branching and looping | `.claude/commands/` | `/workflow @artifact` |

This repository provides the **factory-engineering** skill that wires up the canonical folder structure across IDEs, and the **skill-optimizer** skill that keeps your skills sharp as they evolve.

## Repository Structure

```
skills/
├── factory-engineering/
│   ├── SKILL.md                          # Skill definition
│   ├── sync.md                           # Copy-based sync workflow (primary)
│   ├── symlinks.md                       # Symlink workflow (legacy fallback)
│   ├── sync-copilot-prompts.md           # Copilot sync workflow and frontmatter rules
│   ├── references/
│   │   └── prompt-files-spec.md          # VS Code prompt file spec summary
│   └── scripts/
│       ├── sync-ide.sh                   # Bash: copy-based IDE sync (primary)
│       ├── Sync-Ide.ps1                  # PowerShell: copy-based IDE sync (primary)
│       ├── pre-commit-sync.sh            # Pre-commit hook for auto-sync
│       ├── setup-symlinks.sh             # Bash: symlink-only setup (legacy)
│       ├── Setup-Symlinks.ps1            # PowerShell: symlink-only setup (legacy)
│       └── sync_copilot_prompts.py       # Copilot prompt sync
└── skill-optimizer/
    ├── SKILL.md                          # Skill definition
    └── references/
        ├── best-practices.md             # Authoring rules and checklist
        └── source.md                     # Links to Agent Skills ecosystem
```

## Learn More

- [Factory Engineering](https://factoryengineering.dev) — the full approach: skills, commands, workflows
- [Agent Skills specification](https://agentskills.io) — the open standard for skill packaging
- [OpenSkills CLI](https://www.npmjs.com/package/openskills) — install and manage skills
