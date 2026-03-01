# Factory Engineering Skills

Skills for setting up and maintaining a [Factory Engineering](https://factoryengineering.dev) software factory across AI-assisted IDEs.

## Install

```bash
npx openskills install factoryengineering/skills
```

This installs both skills into `.claude/skills/` in your project. Claude Code, Cursor, and GitHub Copilot read `.claude/skills/` directly. Windsurf, Kilo Code, and Antigravity need a symlink to find them.

**Bash (macOS/Linux):**

```bash
# Windsurf
mkdir -p .windsurf && ln -s ../.claude/skills .windsurf/skills

# Kilo Code
mkdir -p .kilocode && ln -s ../.claude/skills .kilocode/skills

# Antigravity
mkdir -p .agent && ln -s ../.claude/skills .agent/skills
```

**PowerShell (Windows):**

```powershell
# Windsurf
New-Item -ItemType Directory -Force .windsurf
New-Item -ItemType SymbolicLink -Path .windsurf\skills -Target ..\.claude\skills

# Kilo Code
New-Item -ItemType Directory -Force .kilocode
New-Item -ItemType SymbolicLink -Path .kilocode\skills -Target ..\.claude\skills

# Antigravity
New-Item -ItemType Directory -Force .agent
New-Item -ItemType SymbolicLink -Path .agent\skills -Target ..\.claude\skills
```

Create symlinks only for the IDEs your team uses, then commit them. After that, ask your agent to set up command symlinks or sync Copilot prompts as needed.

## Skills

### factory-engineering

Cross-IDE configuration for commands, workflows, and skills. Establishes `.claude/commands/` and `.claude/skills/` as canonical locations and creates symlinks so every IDE finds them.

**Symlink mapping (commands):**

| IDE | Symlink created | Points to |
|-----|-----------------|-----------|
| Cursor | `.cursor/commands` | `.claude/commands` |
| Windsurf | `.windsurf/workflows` | `.claude/commands` |
| Kilo Code | `.kilocode/workflows` | `.claude/commands` |
| Antigravity | `.agent/workflows` | `.claude/commands` |

**Symlink mapping (skills):**

| IDE | Symlink created | Points to |
|-----|-----------------|-----------|
| Windsurf | `.windsurf/skills` | `.claude/skills` |
| Kilo Code | `.kilocode/skills` | `.claude/skills` |
| Antigravity | `.agent/skills` | `.claude/skills` |

Cursor and GitHub Copilot read `.claude/skills/` directly — no skills symlink needed.

**GitHub Copilot** uses `.prompt.md` files in `.github/prompts/`, so commands are synced rather than symlinked. A Python script handles the conversion.

**After installing, ask your agent:**

> Set up symlinks for Cursor and Windsurf.

The agent reads the factory-engineering skill, detects your IDEs, and runs the appropriate script. It will confirm before making changes and offer to copy existing content into the canonical folders if needed.

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
│   ├── symlinks.md                       # Symlink workflow and mapping tables
│   ├── sync-copilot-prompts.md           # Copilot sync workflow and frontmatter rules
│   ├── references/
│   │   └── prompt-files-spec.md          # VS Code prompt file spec summary
│   └── scripts/
│       ├── setup-symlinks.sh             # Bash symlink setup
│       ├── Setup-Symlinks.ps1            # PowerShell symlink setup
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
