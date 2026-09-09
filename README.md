# Factory Engineering Skills

Skills for setting up and maintaining a [Factory Engineering](https://factoryengineering.dev) software factory across AI-assisted IDEs.

## Install

```bash
npx openskills install factoryengineering/skills
```

This installs the skills into `.claude/skills/` in your project. Claude Code, Cursor, and GitHub Copilot read `.claude/skills/` directly. Windsurf, Kilo Code, and Antigravity need a copy of the skills folder:

```bash
# Windsurf
mkdir -p .windsurf/skills && cp -R .claude/skills/. .windsurf/skills/

# Kilo Code
mkdir -p .kilocode/skills && cp -R .claude/skills/. .kilocode/skills/

# Antigravity
mkdir -p .agent/skills && cp -R .claude/skills/. .agent/skills/
```

## Skills

### night-shift-setup

Stands up the night shift for an organization, from nothing to a running nightly sweep. Creates the Night Shift Log application from a committed seed of 47 definitions and its manifest, registers the practice and each tracked repository exactly once, and writes the per-repository configuration the worker refuses to run without. Run once per organization, then once more per repository added.

### night-shift-coordinator

Sweeps a labelled issue queue and decides what is genuinely available from the work artifacts rather than from the label, because a label goes stale the moment a pull request closes. Groups issues that touch the same files into chains instead of dispatching them side by side, then fires one working session per issue, bottom to top. Dispatches work and never performs it.

### night-shift-worker

Works one GitHub issue through to a stacked pull request, unattended. Reproduces the defect or verifies a fix that already merged, fixes with a regression test, resolves a base branch a concurrent session may not have pushed yet, registers the chain as a GitHub stack, drives CI green through one review round, then stops. Per-repository settings live in a `.night-shift/config.md` the skill refuses to run without, so the protocol stays the same across every repository you track.

Pairs with **night-shift-coordinator**, which sweeps the queue and dispatches the work, and **night-shift-setup**, which stands the system up.

## How It Fits Together

Factory Engineering organizes AI-assisted development into three layers:

| Layer | What it encodes | Stored in | Invoked with |
|-------|-----------------|-----------|--------------|
| **Skills** | Domain knowledge and standards | `.claude/skills/` | Auto-loaded by the agent |
| **Commands** | Repeatable single-agent task instructions | `.claude/commands/` | `/command @artifact` |
| **Workflows** | Multi-agent orchestration with branching and looping | `.claude/commands/` | `/workflow @artifact` |

This repository provides the **night-shift** skills that let a scheduled agent work a queue of labelled issues while nobody is watching.

## Repository Structure

```
skills/
├── night-shift-setup/
│   ├── SKILL.md                          # Skill definition
│   ├── creating-the-log.md               # Publishing the seed, practice and repository ceremony
│   ├── configuring-a-repository.md       # The eight required headings, with an example
│   ├── creating-the-routines.md          # Scheduled sessions and their loader prompts
│   └── log-model.factual                 # The log's definitions and manifest, in four batches
├── night-shift-coordinator/
│   ├── SKILL.md                          # Skill definition
│   ├── sequencing.md                     # Grouping, chains, and how much to take
│   ├── dispatching.md                    # The fire, its message format, a failed fire
│   └── night-shift-log.md                # Reading and recording a sweep
└── night-shift-worker/
    ├── SKILL.md                          # Skill definition
    ├── stacking.md                       # Base resolution, stack registration, run confirmation
    ├── verifying-a-merged-fix.md         # When a fix already landed
    ├── night-shift-log.md                # Recording a dispatch outcome
    └── scripts/
        └── register-stack.sh             # Registers a chain of PRs as a GitHub stack
```

## Learn More

- [Factory Engineering](https://factoryengineering.dev) — the full approach: skills, commands, workflows
- [Agent Skills specification](https://agentskills.io) — the open standard for skill packaging
- [OpenSkills CLI](https://www.npmjs.com/package/openskills) — install and manage skills
