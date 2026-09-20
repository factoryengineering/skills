# Reading and recording a sweep in the Night Shift Log

A run that leaves no trace teaches nothing, and a run that reads no trace repeats. The host keeps the artifacts — a pull request, a comment, a label — but not the judgments: what you considered and passed over, why you ordered the work as you did, what a verdict rested on. Those die with the container unless you record them, and they help nobody unless the next run reads them.

The log is a Jinaga application reached through the Factual MCP server. Open a console, run `applications`, and open the one whose routing matches. That console is yours to close, and *Close the console, on every exit path* below says when and why. **Its manifest carries the full action catalog with argument guidance, so run `describe <action>` there rather than trusting an argument list in this file.**

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

This is deliberate and the worker knows to expect it. **The log records no actual branch at all** — `PullRequestOpened` carries a number, a summary and a time, and no branch — so this glob is the only branch the log holds. What ties a dispatch to the work that came of it is the pull request number.

## Two console forms that cost a retry each

**A `call` yields a frame of named bindings, so it cannot be bound to one name.** Destructure what you need:

```
let { $sweep as $sweepA } = call startSweep($repository, $headCommit)
```

`let $sweepA = call startSweep(...)` is a parse error, not a runtime one, so it takes the whole batch with it.

**Every variable carries `$`,** including the bound name and a specification's own variables. One statement per line; `;` only joins two on one line. A view that reads like it takes no argument may still take one, so `describe` it rather than calling it bare.

## Close the console, on every exit path

**`close_console` is the last log step of every run, including a run that stops early.** The server caps one identity at 16 open consoles, and every routine in a practice runs as that same identity, so each run that leaves its console open takes a slot the next one needs. Consoles idle for five days have been seen still holding theirs, so nothing reclaims them on a nightly cadence. A practice that dispatches a few issues a night fills the pool inside a week.

**The paths that leak are the ones that stop early**, because the close sits at the bottom of a procedure they never reach. A stop because no practice or no repository matches, a stop because two do, a dry run that dispatches nothing, a sweep cut short by a failed fire. Close the console on each of them.

**A refused `create_console` is a full pool, not an unreachable server.** `console_limit` comes back with a `candidates` list, and the run continues on one of them: take a candidate whose `dirty` is false and whose `stagedFacts` is `0`, and work in that. **Never work in a dirty candidate, and never close a dirty one.** Its staged facts belong to a session that is not yours, and closing it discards them. The clean candidate you do take is yours for the run and you close it at the end, exactly as you would close one you had opened yourself.

**If every candidate is dirty the pool is genuinely exhausted, and that is still not an outage.** Do the hosting-platform work, and report the run unrecorded naming a full console pool as the reason. The two read alike in a report and have different remedies: a full pool was caused by earlier runs that did not close their consoles, and an outage belongs to whoever owns the connector.

## When the log is unreachable

**Unreachable means the server cannot be reached at all**, and it has exactly two shapes: its tools are absent from the session, or its connector reports that it needs authorization. A `console_limit` refusal is neither, because the server answered; a full pool is the section above, and so is a pool in which every candidate is dirty.

**Do the hosting-platform work anyway.** A missing log entry is a gap; a blocked run is a worse one.

**Then raise it where a person will see it the same day.** Send a push notification as well as saying it in your final report. A scheduled routine's final report lives in a session transcript that nobody reads by default, which is how a connector that had lost its authorization cost two consecutive unrecorded nights before anyone noticed. The notification names the repository, this session, and that the run is unrecorded.

**Send it before your first dispatch, not at the end.** An unrecorded `Dispatch` cannot be resolved by anything that later looks one up, so every worker you fire past this point stops for a reason its own transcript cannot explain, and each one reads as a separate mystery to whoever opens it. A reader who checks the log for the sweep finds none and concludes the issue was never dispatched. The notification is what joins them, and it is worth nothing after the night is over.

**Then send a second one when the sweep ends, listing every dispatch you fired while unrecorded**, each with its issue number and the session id the fire returned. Your final report carries that same list. It is the only record those dispatches have, and it is what lets a person record them afterwards or re-fire them. A push notification is one short line, so where the list will not fit, carry the count and the issue numbers and leave the session ids to the report.

## Rules about what goes in

- **Record what you skipped, not just what you dispatched.** A skip with its reason is the evidence the claim rule is working, and it is the only record that an issue was looked at at all.
- **Never record availability.** The hosting platform is the queue and the only authority on what is currently ready. The log holds what was observed and decided, and when. Storing "this issue is available" would create a second source of truth that can go stale, which is the exact failure the claim rule exists to catch.
- **Write a rationale you can support.** A rationale is your own account, so quote a rule only after reading it, and name the file it comes from. A confident paraphrase of a rule that does not exist reads as evidence to every later run.
- **If the server is unreachable, do the hosting-platform work anyway**, and raise the outage the same day rather than only in your final report. *When the log is unreachable* above says what counts as unreachable and what raising it takes.
