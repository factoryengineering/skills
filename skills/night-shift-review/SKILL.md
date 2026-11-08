---
name: night-shift-review
description: Reviews what the night shift produced, the morning after, across every tracked repository. Reads the night out of the Night Shift Log and the coordinator's report, reviews each worker pull request against the bar the night shift was held to, and recommends which to merge, which to modify, which to return to their issue and which to close, with an order to merge them in. Then, once the person approves, makes the modifications, records answers and corrections, and restacks after each merge. Use when a person starts the day by asking what the night shift did, which pull requests are ready, what order to merge them in, or how to fix the ones that are not; when a worker recorded a question that now has an answer; or when a worker pull request has stayed open across several nights.
---

# Night Shift Review

The night shift ends every run with a pull request open and a person's decision pending. This skill is how that decision gets made. A person runs it in the morning; nothing schedules it.

It works in two phases, and **nothing is written anywhere until the person has read the first phase's report and said which recommendations to carry out.** Reviewing is read-only. Applying is what the person approves, and nothing else.

Sweeping and dispatching belong to `night-shift-coordinator`. Working an issue belongs to `night-shift-worker`. Fixing an issue that was wrong belongs to `refining-issues`. Merging belongs to the person.

## When to use

- **A person asks what the night shift did**, or which of its pull requests are ready.
- **Pull requests are waiting to merge**, and the person wants an order that will not conflict.
- **A worker pull request needs changes** before it can merge.
- **A worker recorded a question**, and the person has an answer.
- **A worker pull request has stayed open across several nights.** Each night it costs a dispatch that no-ops, and only a person can end that.

---

## Before you start

Read `.night-shift/routines.md` in the coordinator's repository. It lists every tracked repository, and the coordinator's row names where the job publishes the coordinator's report. Read each tracked repository's `.night-shift/config.md` over the hosting API. Its `## Visibility`, `## Issue label`, `## Authority`, `## Before you fix`, `## Verification commands` and `## CI workflow` are what you review against.

**A missing configuration file or required heading stops the review of that repository, not of the morning.** Say which heading you could not find, review the rest, and recommend nothing for that repository's pull requests: without its headings you do not know the bar they were held to.

**Respect `## Visibility`.** The report stays in this session. Anything you post to an issue or a pull request follows the rule the heading states, and a private repository's contents never go into a public one.

```
Task Progress:
Phase 1 — review (read-only)
- [ ] Read .night-shift/routines.md and every tracked repository's .night-shift/config.md
- [ ] Read the night out of the log, and close the console
- [ ] Read the coordinator's report from where routines.md says it is published
- [ ] List every open worker pull request across the tracked repositories, from the hosting API
- [ ] Review each one, and give it one verdict
- [ ] Work out the merge order
- [ ] Write the report, and stop
Phase 2 — apply (only what the person approved)
- [ ] For each approved modification: liveness check, claim, change, verify, push, release
- [ ] Write each answer into its issue, then record it in the log
- [ ] Record each correction the person made
- [ ] After each merge the person makes: restack, confirm CI by event, confirm the issue closed
- [ ] Close the log console, whatever happened
- [ ] Report what was done, and what was not
```

---

## Phase 1: Review

### Read the night

Read **[reading-the-night.md](reading-the-night.md)**. It says which log views to read, how to find last night, what the coordinator's report holds that the log does not, and why the hosting platform still decides what is open.

**The log bounds what happened last night. The hosting platform bounds what is waiting.** Every open pull request on a worker branch is in scope, whichever night opened it. One left open from last week is costing a dispatch every night.

### Review each pull request

Read **[reviewing-a-pull-request.md](reviewing-a-pull-request.md)**. It holds each pull request to the same bar the worker was held to, using checks those skills already define, so the morning does not invent a second standard.

Give each pull request exactly one verdict.

| Verdict | When | What it leads to |
|---|---|---|
| **Merge** | Every acceptance clause is met by the diff, every check below holds, and nothing in it needs the person's decision | Its place in the merge order |
| **Modify, then merge** | The issue is right, and the pull request falls short of it in a way a small change fixes: a missed clause, a test that quotes its subject, a review thread left unaddressed, prose that will go stale | A named change, made in phase 2 if approved |
| **Return to the issue** | The pull request does what the issue says, and the issue says the wrong thing | A rewrite of the issue under `refining-issues`; the pull request is closed or reworked after |
| **Close** | The premise was wrong, the work is superseded, or the change belongs to a decision nobody has made | A recommendation to close, and why |

**Modify and return are different defects, and confusing them costs a night.** Patching a pull request to say something its issue does not leaves the next worker comparing the branch against the old acceptance, finding it unmet, and resuming to put it back. Where the fix changes what the issue asks for, the issue changes first.

**A deviation the worker reported is the person's decision, never yours.** A worker that followed the purpose of an instruction rather than its wording says so under its own heading. Put each one in front of the person with what the worker found and what it did instead. Do not give a pull request **Merge** while one of its deviations is undecided.

### Work out the merge order

Read **[merging.md](merging.md)**. It orders chains bottom-up and independent pull requests by the files they share, and says what has to happen after each merge for the next one to be ready.

### Write the report, and stop

Lead with what only the person can decide. A person reading a morning report has the least attention for its end.

1. **Decisions only you can make.** Reported deviations, recorded questions with their candidate answers, and any pull request that would amend a document `## Authority` names.
2. **Merge plan.** The pull requests to merge, in order, each with its issue and one line on why it is ready.
3. **Modify before merging.** Each with the change you would make and the clause or check it answers.
4. **Return to the issue.** Each with what the issue should say instead.
5. **Close.** Each with the reason.
6. **Issues to close.** Issues a worker verified as already resolved and recommended closing, and issues whose pull request the person is deferring. Say for each deferred one that it keeps drawing a dispatch every night until it merges, it is closed, or its queue label comes off.
7. **What the night left unfinished.** Dispatches with no outcome, failed fires, forked chains, and anything the coordinator ran unrecorded.
8. **New issues to consider.** Findings workers noted as out of scope.
9. **Protocol findings.** Anything that shows a skill was wrong rather than an issue, for an issue against the skills' own repository.

Then stop and wait. **The report is the whole of phase 1's output.** Do not comment, push, relabel or record anything while the person is reading it.

---

## Phase 2: Apply

Carry out what the person approved, item by item, and nothing they did not. An approval of the merge plan is not an approval of the modifications in it.

### Modify a pull request

1. **Check that no session is live on it**, with the four-row table in `night-shift-worker`'s *Before you start*: a claim on the issue inside six hours that is not released or stood down, a check run in progress, or a push, comment or review inside six hours. If one is, do not push. Report it, and leave the modification for when the session has stopped.
2. **Claim the issue** the way a worker does, with a token of your own: `Night shift: claimed (<token>).` A dispatch that arrives while you work then stands down instead of pushing a second fix.
3. **Check out the pull request's branch as it stands**, after `git fetch origin`. Push to that branch and no other, and never open a second pull request for the issue.
4. **If the change alters what the issue asks for, change the issue first**, under `refining-issues`. The next worker to read this branch checks its diff against the issue's acceptance and nothing else, so an issue and a branch that disagree is a branch a worker will try to put back.
5. **Make the change**, held to the same rules as the worker's: a regression test that can fail for a reason other than an edit to what it quotes, and no test totals in prose.
6. **Run every command under `## Verification commands` green**, in order, before you push.
7. **Push, then confirm CI ran on the new head by its `event`**, as `night-shift-worker`'s `stacking.md` describes.
8. **Comment on the pull request** saying what you changed and which clause or check it answers.
9. **Release the claim**: edit it to `Night shift: claimed (<token>), released.`

**Never rewrite history on a worker branch.** Bring a lower layer's changes into an upper one with a merge, not a rebase, so nothing needs a force push. A rewritten branch is one any session that holds a checkout of it can no longer push to.

### Record answers and corrections

Read **[night-shift-log.md](night-shift-log.md)**.

**An answer goes into the issue before it goes into the log.** The next worker reads the issue body and its comments; it never reads the log for answers. Write the answer into the body under `refining-issues`' *When an issue comes back from the night*, then record `answerQuestion`, which takes the question off `unansweredQuestions`. Moving the issue from `question` back to the queue label is the person's act, and they take it once they have read the body.

### After each merge

The person merges. After each one, before the next, follow *After each merge* in **[merging.md](merging.md)**: retarget the next layer up to the default branch if the host has not, bring the default branch into it, confirm its CI by `event`, re-read mergeability per pull request, and confirm the merged pull request's issue closed.

---

## Hard limits

- Never merge a pull request. Recommend an order; the person merges.
- Never apply the queue label, and never swap `question` back to it. Applying it asserts the issue is ready, and that assertion is the person's.
- Never close an issue or a pull request, and never remove a label, except on the person's explicit instruction for that item.
- Never write anything during phase 1: no comment, push, label, or log fact.
- Never push to a branch a live session holds, and never push to any branch but the pull request's own.
- Never force-push, and never rewrite history on a worker branch.
- Never skip, disable, or quarantine a test to get a green build.
- Never push an empty commit, and never close and reopen a pull request, to re-trigger CI.
- Never put a mutating call in a retry or fallback position. A shell `cmd-a || cmd-b` runs `cmd-b` when `cmd-a` merely prints something unexpected.
- End every comment you leave on an issue or a pull request with your agent attribution footer.
- Do not put model identifiers in commit messages, pull request text, or code comments.

## Resources

| Resource | Purpose |
|---|---|
| [reading-the-night.md](reading-the-night.md) | Finding last night in the log, the coordinator's report, and the open pull requests |
| [reviewing-a-pull-request.md](reviewing-a-pull-request.md) | The checks behind each verdict |
| [merging.md](merging.md) | The merge order, and what each merge requires of the next |
| [night-shift-log.md](night-shift-log.md) | The reads and writes the review makes, and closing the console |
