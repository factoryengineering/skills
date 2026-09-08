# Reading and recording a sweep in the Night Shift Log

A run that leaves no trace teaches nothing, and a run that reads no trace repeats. The host keeps the artifacts — a pull request, a comment, a label — but not the judgments: what you considered and passed over, why you ordered the work as you did, what a verdict rested on. Those die with the container unless you record them, and they help nobody unless the next run reads them.

The log is a Jinaga application reached through the Factual MCP server. Open a console, run `applications`, and open the one whose routing matches. **Its manifest carries the full action catalog with argument guidance, so run `describe <action>` there rather than trusting an argument list in this file.**

This file is mechanics. The log is not an epilogue: you open it before the claim check and read it before you sequence.

## The whole shape, for orientation

You perform steps 1 to 5. The worker performs 6 and 7, in its own session, after yours has ended.

1. **`practicesForAdministrator`** — the entry point, before the claim check. Find the repository whose current name matches the one you are sweeping and take its reference.
2. **`startSweep`** — once per repository, before examining anything.
3. **The corrections view, and the previous sweep's considerations** by way of the sweeps view, before you sequence.
4. **`considerIssue`**, then exactly one finding action, matching what the claim check turned up.
5. **`dispatchWork` or `skipIssue`.** Creating the fact *is* the decision; there is no decision value to set.
6. `openPullRequest`, `raiseQuestion`, or `findNoChange`. *(worker)*
7. `answerQuestion`, or `correctVerdictFromWork`. *(worker, later)*

## Setup is not your job, and calling it is destructive

If no practice exists, or no repository in it matches the one you are sweeping, **stop and say so.** Creating a practice and registering a repository are one-time setup owned by `night-shift-setup`, and calling either speculatively mints a duplicate that splits the history across two records nothing joins.

More than one match is also a stop. Two practices, or two repositories carrying one name, mean an earlier setup ran twice, and guessing which to use writes this sweep into whichever you picked.

## The branch on a dispatch is a glob

`dispatchWork` takes a branch argument, and you cannot know the branch, because its slug is the worker's to choose. Write the pattern the worker's branch will match:

```
claude/issue-<N>-*
```

This is deliberate and the worker knows to expect it. The real branch arrives later on the worker's `openPullRequest` fact.

## Two console forms that cost a retry each

**A `call` yields a frame of named bindings, so it cannot be bound to one name.** Destructure what you need:

```
let { $sweep as $sweepA } = call startSweep($repository, $headCommit)
```

`let $sweepA = call startSweep(...)` is a parse error, not a runtime one, so it takes the whole batch with it.

**Every variable carries `$`,** including the bound name and a specification's own variables. One statement per line; `;` only joins two on one line. A view that reads like it takes no argument may still take one, so `describe` it rather than calling it bare.

## Rules about what goes in

- **Record what you skipped, not just what you dispatched.** A skip with its reason is the evidence the claim rule is working, and it is the only record that an issue was looked at at all.
- **Never record availability.** The hosting platform is the queue and the only authority on what is currently ready. The log holds what was observed and decided, and when. Storing "this issue is available" would create a second source of truth that can go stale, which is the exact failure the claim rule exists to catch.
- **Write a rationale you can support.** A rationale is your own account, so quote a rule only after reading it, and name the file it comes from. A confident paraphrase of a rule that does not exist reads as evidence to every later run.
- **If the server is unreachable, do the hosting-platform work anyway** and say in your final report that the run went unrecorded. A missing log entry is a gap; a blocked run is a worse one.
