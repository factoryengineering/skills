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

Stands up the night shift for an organization, from nothing to a running nightly sweep. Creates the Night Shift Log application from a committed seed of 53 definitions and its manifest, or upgrades one published from an earlier seed, registers the practice and each tracked repository exactly once, and writes the per-repository configuration the worker refuses to run without. Run once per organization, then once more per repository added.

### refining-issues

Turns a backlog issue into one an unattended night-shift agent can implement, and turns a coupled set into a chain that stacks. Encodes eight checks — five that decide whether one issue is ready, three that decide whether a set is independent — plus the five moves that fix a failed check. Reads `.night-shift/config.md`, so the documents an issue answers to are the repository's own. Install it in every repository that enlists in the night shift; a person runs it, nothing schedules it.

### night-shift-coordinator

Sweeps a labelled issue queue and decides what is genuinely available from the work artifacts rather than from the label, because a label goes stale the moment a pull request closes. Groups issues that touch the same files into chains instead of dispatching them side by side, then fires one working session per issue, bottom to top. Dispatches work and never performs it.

### night-shift-worker

Works one GitHub issue through to a stacked pull request, unattended. Reproduces the defect or verifies a fix that already merged, fixes with a regression test, resolves a base branch a concurrent session may not have pushed yet, registers the chain as a GitHub stack, drives CI green through one review round, then stops. Per-repository settings live in a `.night-shift/config.md` the skill refuses to run without, so the protocol stays the same across every repository you track.

Pairs with **night-shift-coordinator**, which sweeps the queue and dispatches the work, and **night-shift-setup**, which stands the system up.

### night-shift-review

Reviews what the night shift produced, the morning after, across every tracked repository. Reads the night out of the log and the coordinator's report, holds each worker pull request to the bar the worker was held to, and recommends which to merge, which to modify, which to return to their issue and which to close, with an order to merge them in. Writes nothing until the person approves; then makes the approved modifications, records answers and corrections, and restacks after each merge. Never merges. Install it beside the coordinator; a person runs it, nothing schedules it.

## The daily cycle

| When | Who | Skill | What comes out |
|---|---|---|---|
| Day | A person and an agent | `refining-issues` | Issues an agent holding nothing but the issue body can implement. The person reads each one against their goals and applies the queue label. |
| Night | The coordinator's job | `night-shift-coordinator` | One sweep per repository, filed under the night, and one dispatch per available issue |
| Night | One worker per issue | `night-shift-worker` | A stacked pull request, a recorded question, or a finding that nothing needed changing |
| Morning | A person and an agent | `night-shift-review` | A report: what to merge and in what order, what to modify, what to return to its issue. Then the approved changes. |
| Morning | The person | — | The merges, in the recommended order |

What the morning returns feeds the next day. An answered question and a returned pull request both go back through `refining-issues`, and the person relabels them. Findings a worker noted as out of scope become new issues.

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
│   ├── creating-the-log.md               # Publishing or upgrading the seed, practice and repository ceremony
│   ├── configuring-a-repository.md       # The eight required headings, with an example
│   ├── creating-the-routines.md          # The coordinator's job, the worker sessions, their prompts
│   └── log-model.factual                 # The log's definitions and manifest, in four batches
├── refining-issues/
│   ├── SKILL.md                          # Skill definition
│   └── references/
│       └── worked-example.md             # Every check and move over one invented backlog
├── night-shift-review/
│   ├── SKILL.md                          # Skill definition
│   ├── reading-the-night.md              # The log, the coordinator's report, the open pull requests
│   ├── reviewing-a-pull-request.md       # The checks behind each verdict
│   ├── merging.md                        # The merge order, and what each merge requires of the next
│   └── night-shift-log.md                # The review's reads and writes, and the console
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
