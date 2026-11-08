# Reviewing a worker pull request

Every check here already exists in another night-shift skill. The morning applies the bar the night was held to, so a pull request is judged the same way at both ends, and a disagreement between them is a finding about one of the skills rather than a matter of taste.

Read the issue first, then the pull request. The issue says what was asked; the pull request body says what its author set out to do, and those can differ.

## The checks, in order

### 1. Deviations

Read the pull request's deviation heading first, if it has one. A worker that followed an instruction's purpose over its literal wording reports it there (*What these instructions serve*, in `night-shift-worker`).

For each one, say what the wording asked, what the worker found, and what it did instead, and say which kind it is:
- **A stale instruction carried out against current reality.** The worker is entitled to this, and the person usually confirms it.
- **A decision the worker took that was not its to take.** That is a question the worker should have raised. The pull request does not merge until the person decides.

Either way it goes in the report's first section.

### 2. Acceptance, clause by clause

Check each acceptance clause against **the diff on the branch**, not against the pull request body. This is the worker's own resume test (*Before you start*, in `night-shift-worker`), and what counts as met is what the config's `## Before you fix` says counts.

One unmet clause is not **Merge**. Whether it is **Modify** or **Return** depends on whether the clause is right.

### 3. Tests

- **Behaviour changed, so a regression test exists** that fails before the change and passes after.
- **No test can fail only because someone edited the thing it quotes.** A test that asserts a sentence, a default equal to the literal the source assigns, or a config line the config contains is a second copy of its subject. This is R5 in `refining-issues` and the worker's own rule. A copy is a **Modify**: remove the test, or replace it with one that derives one side.
- **Where the change is prose with nothing to derive**, the pull request says so and stands on review. That is correct, not a gap.

**Where the issue's acceptance asked for the copy, the defect is in the issue.** The verdict is **Return**, with R5's *Remove the freedom* as the rewrite.

### 4. Conformance

Where `## Authority` names documents, the pull request answers to the sections and principles the issue cites. A change that passes every test and offends a cited principle is not **Merge**.

**A pull request that changes a document `## Authority` names is an amendment**, which is the maintainer's decision by the route that heading names. Put it in the report's first section whatever else it does.

### 5. CI

- **Green on the current head**, read from the pull request itself. A check-run event can name a commit the branch has moved past.
- **From a run on this pull request.** Read the run of the workflow file `## CI workflow` names, scoped to the branch, and match its `head_sha`. Check its `event`: a run from a manual dispatch says the code passed, not that the pull request's own trigger checked it.
- **A red check that is red on the base too** is not this pull request's defect. Say so, and say whether it blocks the merge.

### 6. The stack

- **The base is right.** The bottom layer bases on the default branch; each layer above on the branch of the issue its dispatch named. A layer based on `main` while its lower layer is unmerged shows that layer's work as deletions.
- **Registered, or said to be unregistered.** A chain the worker could not register says so in its body and names the layer below.
- **No fork.** Two open pull requests on one base cannot both be right.

### 7. The review round

Every reviewer suggestion has a pushed commit or a reply on the thread saying why not. A thread left open with neither is a **Modify**. A reply that refuses a suggestion is a claim: check it against the repository before you accept it.

### 8. Scope

The diff holds the issue's change and nothing else. Findings outside the issue belong in the pull request as notes, and those notes go in the report's list of new issues to consider. A diff that widened to fix them is a **Modify**: split the extra change out.

### 9. What stays true

The body reports verification as which commands ran and that they held, names tests by description rather than position, and states no test totals or before-and-after counts (*Write what stays true*, in `night-shift-worker`). A number that is pinned to a commit or a run id is fine. A stale-prone number is a small **Modify**; it is never a reason to hold a merge on its own.

## Running the commands yourself

Run `## Verification commands` on the branch head when a verdict turns on it: a CI result you cannot read, a test you doubt can fail, a clause only a run can show. Running them changes nothing on the remote, so it belongs to phase 1. Say in the report which you ran and what held.

## Giving the verdict

State the verdict, then the one or two findings that decided it. A verdict without its reason cannot be checked, and the person will either trust it or redo the review.
