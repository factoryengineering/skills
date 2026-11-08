# The Night Shift Log in the morning

The log is a Jinaga application reached through the Factual MCP server. Open a console, run `applications`, and open the one whose routing matches. **Its manifest carries the full action and view catalog with argument guidance, so run `describe <name>` there rather than trusting an argument list in this file.**

The review reads far more than it writes. The reads are in [reading-the-night.md](reading-the-night.md). This file covers the writes, and the console.

## Where the review sits

1. to 5. The coordinator: resolve, `startNightlySweep`, read, `considerIssue` and a finding, `dispatchWork` or `skipIssue`.
6. The worker: `openPullRequest`, `raiseQuestion`, or `findNoChange`.
7. **You, in phase 2: `answerQuestion` and `correctVerdict`**, and an outcome a worker failed to record.

## What you write, and only in phase 2

**`answerQuestion`**, once the answer is in the issue body. Take the `questionRef` from `unansweredQuestions`. Record the answer as the person gave it, and say where in the issue it now lives. Recording it is what takes the question off `unansweredQuestions`; it does not put the issue back in the queue.

**`correctVerdict`**, when the person finds that a conclusion the night recorded was wrong and no later piece of work is the source: a dispatch rationale that quoted a rule that does not exist, a finding that read an open pull request as merged, a skip whose reason was false. Take the `considerationRef` from `considerationsInSweep`. Say what was wrong and what is true instead. The coordinator reads corrections before it sequences, so a correction is how the morning teaches the night.

A defect in a skill is not a correction. It goes in the report as a protocol finding, for an issue against the skills' own repository, because a correction records what was true about one issue, and the fix to a rule belongs in the rule.

**An outcome the worker did not record**, only when the hosting platform shows it: `openPullRequest` for a worker pull request that exists, or `raiseQuestion` for a question the worker posted. Take the `dispatchRef` from `dispatchesAwaitingOutcome`. Begin the summary or text with `Recorded by the morning review:`, so a later reader can tell it was observed after the fact rather than reported by the worker. Never record `findNoChange` on a worker's behalf: nothing on the hosting platform shows that a worker concluded there was nothing to fix, and inferring it from silence records a result nobody reached.

**Never write a sweep, a consideration, a finding, a dispatch or a skip.** Those are the coordinator's record of its own decisions, and a morning that adds to them makes the night look as though it decided something it did not.

## Two console forms that cost a retry each

**A `call` yields a frame of named bindings, so it cannot be bound to one name.** Destructure what you need:

```
let { $answer } = call answerQuestion(question: $questions[0], text: "Use the per-tenant limit. Written into the issue under Build.")
```

**Every argument is named, and every variable carries `$`.** One statement per line.

## One console per phase

Open one console for phase 1's reads and **close it before you write the report.** The person may take an hour to read the report, and a console held open across that hour takes a slot from every run that starts in the meantime. Open a fresh one for phase 2's writes, and close it when they are done.

**`close_console` is the last log step of each phase, including one that stops early.** The pool is shared with every night-shift run in the practice, capped at 16 open consoles, and it heals far too slowly to lean on. `night-shift-coordinator`'s `night-shift-log.md` has the full account under *Close the console, on every exit path*, including what to do when `create_console` is refused: work in a candidate that is clean and holds no staged facts, and **never work in or close a dirty one**, because its staged facts belong to a run that is not yours.

**A console that staged facts and rolled them back still returns them from its own reads.** Check anything you wrote from a fresh console.

## When the log is unreachable

Unreachable means its tools are absent, or its connector needs authorization. A `console_limit` refusal is neither.

**Review anyway.** The hosting platform still says what is open, and the coordinator's report still says what the night did. Say at the top of the report that the log was not read, so the person knows the reasoning behind each dispatch is missing. In phase 2, list every answer and correction you could not record, so the person can record them once the log is back. An answer is never lost this way, because it is already in the issue body.
