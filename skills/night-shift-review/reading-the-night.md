# Reading the night

Three sources, each authoritative for one thing.

| Source | Authoritative for | Not authoritative for |
|---|---|---|
| The Night Shift Log | What each run considered, dispatched and skipped, and what each dispatch reported | What is open, merged or claimed now |
| The coordinator's report | What the log cannot hold: forked chains, repeated no-ops, failed fires, dispatches made while the log was unreachable | Anything it does not name |
| The hosting platform | What is open, merged, claimed or green now | Why any of it happened |

Read all three. A review that reads only the log trusts a record for a state it never held. A review that reads only the hosting platform finds the pull requests and none of the reasoning behind them.

## The log

The mechanics of opening a console, the two console forms that cost a retry each, and closing the console are in [night-shift-log.md](night-shift-log.md). The reads, in order:

1. **`practicesForAdministrator`**, passing `$me`. Take the `practiceRef`. No practice, or more than one, is a stop, exactly as it is for the coordinator.
2. **`nightsInPractice`** with that practice. Sort the rows by `date` and take the **two most recent**. A night is one UTC date. A run that started on the evening before a UTC midnight lands on the earlier date, so one night is not always enough, and two always are.
3. **`sweepsInNight`** for each of the two nights. One row per sweep, with its repository's current name. Expect one sweep per tracked repository per run. **A repository with no sweep on either night was not swept**, and that is a finding for the report: the coordinator skipped it, or a coordinator older than the Night period recorded it with `startSweep`, which files a sweep under no night.
4. **`considerationsInSweep`** for each sweep. This is the night in full: every issue examined, what the claim check found, whether it was dispatched or skipped and why, and each dispatch's outcome.
5. **`dispatchesAwaitingOutcome`** for each of the two nights. Each row is a dispatch with no pull request, no question and no finding of nothing to change.
6. **`unansweredQuestions`** with the practice. This one is practice-wide on purpose. A question stays open until someone answers it, and answering it is the only thing that takes it off the list, so the list is as long as the backlog of decisions and no longer.
7. **`correctedVerdicts`** with the practice. Report the corrections recorded since the earlier of the two nights; older ones are the coordinator's to read, not news.

**Do not read `sweepsInRepository` for a morning.** It lists every sweep a repository has ever had, and the morning needs two nights. It remains the way to reach a sweep the night-rooted views cannot see.

### A dispatch awaiting an outcome

A row means the worker is still running or stopped without recording. The hosting platform says which.

| What the hosting platform shows for the issue | What it means | Report it as |
|---|---|---|
| A live claim, a check run in progress, or a push inside six hours | The worker is still running | Running; nothing to do |
| A worker pull request, and no live session | The worker opened it and did not record it, **or** it predates this dispatch and the worker found it and stopped | A pull request to review like any other. An outcome you may record in phase 2 only if *Tying an artifact to its dispatch*, below, holds |
| A `question` label and the worker's question comment | The worker asked and did not record it, or the question predates this dispatch | A question for the person. An outcome you may record only under the same rule |
| A released claim and nothing else | The worker stopped without a pull request or a question | A finding: what its claim comment and the issue's latest comments say |
| Nothing at all | The worker never started, or never claimed | A finding: name the session id the dispatch recorded |

### Tying an artifact to its dispatch

A pull request or a question that exists is not evidence that this dispatch produced it. An issue whose pull request stayed open is dispatched again every night, and that night's worker finds the earlier pull request and stops. Recording the earlier one as the later dispatch's outcome credits it with work it did not do, and removes it from `dispatchesAwaitingOutcome`, where it belonged.

Tie the artifact to the dispatch only when all of these hold:
- **It was created after the dispatch's sweep started**: the pull request's `created_at`, or the question comment's time, is later than the sweep's `startedAt`.
- **No earlier artifact of its kind exists for the issue**: no worker pull request, open or closed, created before that sweep, or no worker question posted before it.
- **No other dispatch of the issue could have made it**: no later sweep in the two nights dispatched the same issue before the artifact appeared.

Where any of them fails, the case is ambiguous. Report it, and leave the dispatch unrecorded.

Never infer an outcome the hosting platform does not show. A dispatch with nothing behind it stays unrecorded; it belongs to one night, so it ages out of the next morning's read rather than piling up.

## The coordinator's report

The coordinator's row in `.night-shift/routines.md` names where its job publishes the report. **Find the runs from the job's own run history, not from the log**: every run since the start of the earlier of the two nights, including failed runs. A run made while the log was unreachable recorded no Night and no Sweep, so the log cannot lead you to it, and its report is the only record of its dispatches. Read the report of each run you find. When the log holds no Night at all, take the runs of the last 36 hours. **If the row names no place, say so in your report** rather than searching: an unnamed place is a setup defect for `night-shift-setup` to fix, and a guess finds the wrong run.

Carry each of these into your report, with the repository, the issue and the pull request:

- **A forked chain.** Two open pull requests on one worker branch base. A person decides which layer is right and closes or rebases the other.
- **A repeated no-op.** An issue whose open pull request draws a dispatch every night that finds nothing to do. The coordinator names what ends it: merging the pull request, closing the issue, or removing the label.
- **A failed fire.** The issue was not worked. Say whether it is in the queue for tonight.
- **An unrecorded run.** Every dispatch the coordinator fired while the log was unreachable, with its issue number and session id. Those have no `Dispatch` in the log, so nothing above found them.
- **The budget**, and any skip that leaned on it.

## The hosting platform

For each tracked repository:

1. **List open pull requests whose head branch matches `claude/issue-<number>-*`.** That is every worker pull request waiting on a person, whichever night opened it. Pass the open-state filter explicitly.
2. **Read each one individually** for `mergeable`, `merged_at`, its base branch and its head SHA. A list response omits `mergeable` and `merged` and renders both as their zero values, so a list read reports every pull request as unmergeable and unmerged alike.
3. **List every open issue carrying `question`**, and find the worker's question among its comments, with every comment after it. The question is rarely the latest comment once a person has started answering. Each issue matches a row of `unansweredQuestions`; one with no row was not recorded, and one with an answer below the question is ready for phase 2.
4. **List open issues carrying the queue label that hold a worker's closing recommendation**: a verification comment recommending closing, with no later comment from the maintainer. A worker that verified a merged fix often opens no pull request, so step 1 does not find these, and the log reaches them only if the recommendation came within the two nights.
5. **Read the claim comments on each issue** whose pull request you will recommend modifying. Phase 2 needs them, and the morning is when a recovery run is most likely to be live.

Run `git fetch origin` before you read any remote ref through git. A container can hold refs older than the tree it checked out.
