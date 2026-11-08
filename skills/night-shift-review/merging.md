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

1. **Retarget the next layer up to the default branch**, if the merged one was a lower layer of an unregistered chain and the host has not already done it. Read that pull request's base individually. A host retargets an upper pull request on its own only when the lower branch is deleted, so with the lower branch kept, the upper one still targets it, and merging it then lands nothing on the default branch and closes nothing.
2. **Bring the default branch into that layer.** Merge `origin/<default>` into the layer's branch and push. Use a merge, not a rebase: a squash or rebase merge wrote new commits, so the upper branch still carries the old ones, and merging resolves them without rewriting the branch. Where the host retargeted the layer to the default branch on its own, this step is still needed.
3. **Confirm CI ran on the new head by its `event`.** Retargeting a pull request's base fires `edited`, which the usual `opened`, `synchronize` and `reopened` triggers do not include, so a retarget alone leaves the pull request showing checks from its old base. The push in step 2 fires `synchronize`. Read the run of the `## CI workflow` file for the branch and match its `head_sha`.
4. **Re-read each remaining pull request individually for `mergeable`.** A merge can make any later one conflict. A list response does not carry the field, so a list read cannot tell you.
5. **Confirm the merged pull request's issue closed.** If it did not, its closing keyword did not fire, usually because it merged into a branch that is not the default. Report it, and leave the issue for the person to close.

Steps 1 and 2 are phase 2 writes, so do them only once the person has approved the merge plan. A push to a worker branch takes the liveness check and the claim in *Modify a pull request*, in `SKILL.md`, like any other.

## When a merge goes wrong

A conflict, a red check after a restack, or a merge that closed the wrong issue stops the plan at that point. Report what happened and what is still unmerged, and let the person decide whether the rest goes ahead.
