# Ordering a sweep into chains

## Read the log before you sequence

The heuristics below are the ones this protocol has actually been wrong about, and the log is where the corrections live. Read two things first:

- **The corrections view** — conclusions a later run disproved, and where the disproof came from. Read it *before trusting an ordering or attribution heuristic*, which is precisely what the rest of this file is.
- **The most recent sweep's considerations** — what was dispatched, on what rationale, and what came of it.

This is a read for **reasoning**, never for availability. The hosting platform remains the only authority on what is claimed, and the claim check still runs in full against it.

A rationale in the log is the record of what a run decided. It is not a citation of this document. When a log entry quotes a rule, check the rule here before you rely on it.

## Grouping

Group the available issues by the files they touch and by the dependencies they declare. Issues touching the same files are not independent, and dispatching them side by side from `main` produces conflicting patches for one root cause.

**A group is a chain, not a reason to skip.** Order the group so each layer sits above what it reads, and stack each layer on the one below.

Where two or more issues must land before a third, they do not block it. A pull request has one base, so put all of them in one chain in any order where none reads another's code, and stack the third on the topmost. **A chain is a linearization of the dependency graph, not a single file of strict prerequisites.**

Where one issue is plausibly a duplicate of another's root cause, put it last and have it verify before it fixes.

Across groups, dispatch in parallel freely.

## A lower neighbour counts as satisfied in three states, not two

Never dispatch an issue whose lower neighbour is in none of these. Skip it, and say which issue it was waiting on.

1. **Already merged.**
2. **Being dispatched in this same sweep.** The upper worker resolves the branch by pattern and waits for it.
3. **Carrying an unmerged branch, whether or not a pull request on it is still open.** This is the strongest of the three, because the branch already exists and the upper worker never waits at all.

**Do not confuse the claim check with the dependency check.** An open pull request on an issue means do not dispatch *that* issue a second time. It says nothing about the issue above it, which is released to stack rather than blocked.

## How much to take

The dispatching prompt sets the budget and states it. Take what you can carry, and **say in your report, and in every skip rationale that leans on it, what budget you were given.** A skip reason is only evidence if the constraint behind it is stated.

A skip that cites a budget nobody can find in the protocol or in the run's own report leaves no way to tell a considered limit from an improvisation.

**Depth is not a budget.** A layer whose base branch does not exist yet waits for it, and idle worker time is acceptable. Do not defer a layer to the next sweep to avoid waiting: one sweep that carries a chain to its top makes more progress than several sweeps that each add one layer.

When the budget forces a cut, drop the issue whose absence breaks no chain. An issue that nothing depends on and that depends on nothing is the cheapest thing to defer; the top of a chain is the next cheapest. Never drop a layer from the middle.
