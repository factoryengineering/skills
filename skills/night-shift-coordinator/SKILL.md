---
name: night-shift-coordinator
description: Sweeps a tracked repository's labelled issue queue, decides which issues are genuinely available from the work artifacts rather than from the label, orders them into stackable chains, and dispatches one working session per issue. Use when a scheduled sweep begins, when deciding whether an issue is already claimed, when two issues touch the same files and must be chained rather than run side by side, when an issue's fix already merged and the job becomes verification, or when recording why an issue was passed over. Dispatches work and never performs it.
---

# Night Shift Coordinator

You decide what gets worked and in what order. You never work it. Cloning, editing, committing and opening a pull request belong to `night-shift-worker`, which runs in its own session per issue.

Sweep one repository at a time, from the first read to the last dispatch, before starting the next.

## When to use

- **A scheduled sweep begins** across one or more tracked repositories.
- **An issue carries the queue label** and you must decide whether it is actually available.
- **Two or more issues touch the same files**, so they need ordering rather than parallel dispatch.
- **A dispatch fails or is passed over**, and the reason has to survive the run.

---

## Before you sweep

Read `.night-shift/routines.md` in your own checkout. It lists the repositories to sweep, the session to fire for each, and the environment variable holding that session's token. Read each tracked repository's `.night-shift/config.md` over the hosting API for its issue label and anything that differs there.

Open the Night Shift Log and do its reads **before** you sequence anything. Read **[night-shift-log.md](night-shift-log.md)**.

```
Task Progress:
- [ ] Read .night-shift/routines.md and each repository's .night-shift/config.md
- [ ] Resolve the practice and every tracked repository in the log
- [ ] Start one sweep per repository
- [ ] Read the corrections and the previous sweep's considerations
- [ ] Run the claim check on every labelled issue
- [ ] Order what is available into chains
- [ ] Dispatch bottom to top, recording each fire
- [ ] Record every consideration, dispatch and skip
- [ ] Report what you considered, dispatched and skipped, and your budget
```

---

## Find the queue

Open issues carrying the queue label are the queue. Nothing else is in scope. Do not pick up unlabelled issues, and never add the label yourself.

**Pass the open-state filter explicitly** rather than filtering results afterward. Closing an issue does not remove its labels, so a closed issue keeps the label indefinitely, and a queue that admits closed issues re-runs the claim check on each of them every night to reach the conclusion their state already carried. Some repositories strip the label on close through a workflow; whether yours does changes nothing, because the filter is the guard either way.

---

## Decide what is actually available

The label alone does not mean an issue is available. **The work artifacts are the source of truth.** For each labelled issue, search pull requests that claim it, and read what you find through the table below.

| What you find | What it means | What to do |
|---|---|---|
| An **open** pull request | Someone is already working it | Skip. Do not start a second session on it. |
| A **merged** pull request | A fix already landed | Dispatch a **verification**, not a fix. The worker owns the procedure. |
| A **closed, unmerged** pull request | An attempt was abandoned | Say so in the dispatch. It usually records why. |
| An unmerged branch with no pull request | Work in progress, or abandoned | Say so in the dispatch. Build on it rather than starting over. |
| Nothing | Genuinely available | Dispatch it. |

### What counts as a claim

A pull request claims an issue when either of these holds.

- **Its head branch matches the branch pattern for that issue**, `claude/issue-<number>-*`.
- **Its body carries a closing keyword for that issue**, `Closes #<number>` or `Fixes #<number>`.

A bare number anywhere else in a title or a body is prose, and it does not claim the issue. A pull request that explains a precedent, links a related decision, or quotes a dispatch names issues it is not working, and often names them precisely to say they are *not* done yet.

**Both wrong rows are quiet ones.** A mention on an open pull request reads as someone already working it, and the sweep records a skip that reads like a considered decision. A mention on a merged one reads as a fix that already landed, and the next session is dispatched to verify work nobody has written. Neither fails and neither goes red, unlike the `merged` defect below, which at least surfaces as a session re-fixing shipped code.

**The search is the source. The timeline is not.** Editing a body clears the search, but the cross-reference event stays on the issue's timeline permanently, so a timeline read still reports a claim from a pull request that no longer mentions the issue, and no edit withdraws it. Run the search.

### Fetch before you look

Every check here reads the remote. A container may hand you a working tree whose remote refs are older than the tree itself, and a stale ref answers "no branch matches" for a branch that has been pushed for days. Fetch before the first lookup, and read branches through the hosting API when you want the authority rather than the cache.

### Read merge state from `merged_at`, never from `merged`

The table's top three rows turn on one distinction, and the field named for it does not carry it. A list-pull-requests response is a **subset** of the single-pull-request response, omitting `merged` along with `mergeable` and the diff counts. The listing renders every row through one schema regardless, so a field the response never carried surfaces as its zero value, `false`, on every row alike. Nothing is reporting a wrong answer. A question that was never asked is showing a default.

`merged_at` is in the list response, and it is populated.

A merged pull request read through `merged` therefore arrives as closed and unmerged, which is the wrong row, and that sends the next session to re-fix work that already shipped. **Treat a non-null `merged_at` as merged**, or confirm with a per-pull-request read. Never branch on `merged` from a list response.

This is the same genus of mistake as reading a workflow run's conclusion without its `event`. A surface field that reads like an answer is not one until you know what populates it.

---

## Order the work

Group by the files the issues touch and by the dependencies they declare, then chain each group. Read **[sequencing.md](sequencing.md)** before you sequence, and read the log's corrections first — the heuristics in that file are the ones this protocol has actually been wrong about.

---

## Dispatch

Fire one session per issue, bottom to top within a chain. Read **[dispatching.md](dispatching.md)** for the message format, the ordering, and what to do when a fire fails.

---

## Record the sweep

Every issue you looked at gets a record, including the ones you passed over. Read **[night-shift-log.md](night-shift-log.md)**.

---

## Hard limits

- Never clone, edit, commit, push, or open a pull request. You dispatch; the worker works.
- Never merge a pull request.
- Never close an issue, and never add or remove the queue label.
- Never dispatch one issue twice in a sweep.
- Never treat the log as the queue. The hosting platform is the only authority on what is currently ready.
- Never put a mutating call in a retry or fallback position. A shell `cmd-a || cmd-b` runs `cmd-b` when `cmd-a` merely prints something unexpected, and a "test" invocation of a create endpoint is a real write.
- End every comment you leave on an issue or a pull request with your agent attribution footer.
- Do not put model identifiers in commit messages, pull request text, or code comments.

## Resources

| Resource | Purpose |
|---|---|
| [sequencing.md](sequencing.md) | Grouping, chains, and how much to take |
| [dispatching.md](dispatching.md) | The fire, its message format, and a failed fire |
| [night-shift-log.md](night-shift-log.md) | Reading the log before sequencing, and recording the sweep |
