# Ordering the merges

The person merges. Your part is an order in which every merge leaves the next one ready, and the steps between merges that keep it so.

## The order

**A chain merges bottom-up.** Closing keywords close an issue only when the pull request merges into the default branch, so an upper layer merged into the branch below it closes nothing, and its issue stays open and labelled. Merging bottom-up puts every layer onto the default branch in turn.

**A registered stack merges as one operation**, bottom-up, through the host's own stack merge. Recommend it as one item, and name the layers in it. If only some layers are ready, recommend merging up to the highest ready layer and say which stay open.

**An unregistered chain merges one layer at a time**, bottom first, with *After each merge* below between each.

**Independent pull requests that share no files merge in any order.** Put them first, because nothing after them depends on them.

**Independent pull requests that touch the same files conflict in whichever order they go.** Order them so that the one other issues' **Depends on** lines name goes first. Where none does, put the smaller diff first, because the larger one is more likely to absorb a conflict without a change of meaning. Say in the report which ones overlap, so the person expects the conflict.

**A pull request whose verdict is not Merge stays out of the order**, and so does every layer above it in its chain. Name what it is waiting for.

## After each merge

Do these before the person merges the next pull request. Each one is cheap, and skipping one is how a green pull request merges red.

**What the host does on its own depends on whether the chain is a registered stack.** Read the stack list (`register-stack.sh list`, in `night-shift-worker`) rather than the pull request body, which may not say.

- **A registered stack restacks itself.** When a lower layer merges, the host retargets the next layer up to the default branch and rebases its branch onto it on the server, whichever merge method was used and whether or not the lower branch was deleted. The force push fires `synchronize`, so CI runs on the rebased head from the pull request's own event. Nothing needs pushing. Your part is to confirm it happened: step 0, then steps 3 to 5.
- **An unregistered chain does not.** A host retargets an upper pull request on its own only when the lower branch is deleted, and it never rebases one. Do steps 1 to 5.

0. **Confirm the host's restack**, for a registered stack. Read the next layer's base individually, and its timeline (`issues/<number>/timeline`). The base must be the default branch, and the timeline must show `automatic_base_change_succeeded` followed by `head_ref_force_pushed`, both after the merge. Passing CI, a clean `mergeable` and a closed issue do not show this: a retarget without the rewrite, or someone else's push, satisfies all three. If either event is missing, or the timeline shows the base change failed, the host did not restack the layer. Report it, and treat the layer as an unregistered chain's: steps 1 and 2, under the same approval.
1. **Retarget the next layer up to the default branch**, for an unregistered chain whose host has not already done it. Read that pull request's base individually. With the lower branch kept, the upper one still targets it, and merging it then lands nothing on the default branch and closes nothing.
2. **Bring the default branch into that layer**, for an unregistered chain. Merge `origin/<default>` into the layer's branch and push. Use a merge, not a rebase: a squash or rebase merge wrote new commits, so the upper branch still carries the old ones, and merging resolves them without rewriting the branch. Where the host retargeted the layer to the default branch on its own, this step is still needed.
3. **Confirm CI ran on the new head by its `event`.** Read the pull request's head individually, then the run of the `## CI workflow` file for the branch, and match its `head_sha`. For a registered stack, the head is the host's rebased commit, not the one the review read. For an unregistered chain, a retarget alone fires `edited`, which the usual `opened`, `synchronize` and `reopened` triggers do not include, so only the push in step 2 brings a run.
4. **Re-read each remaining pull request individually for `mergeable`.** A merge can make any later one conflict. A list response does not carry the field, so a list read cannot tell you.
5. **Confirm the merged pull request's issue closed.** If it did not, its closing keyword did not fire, usually because it merged into a branch that is not the default. Report it, and leave the issue for the person to close. Either way, record the merge with `observeMerge`, so the pull request leaves `currentVerdicts`.

Steps 1 and 2 are phase 2 writes, so do them only once the person has approved the merge plan. A push to a worker branch takes the liveness check and the claim in *Modify a pull request*, in `SKILL.md`, like any other.

**A host's restack rewrites the upper branch.** Every commit on it has a new SHA, so a checkout made before the merge can no longer push to it. Before any later change to that layer, fetch and check out the branch afresh rather than pulling into an old checkout, and treat a head that moved without a push of yours as the host's restack before you treat it as a live session: its timeline says which.

## When a merge goes wrong

A conflict, a red check after a restack, or a merge that closed the wrong issue stops the plan at that point. Report what happened and what is still unmerged, and let the person decide whether the rest goes ahead.
