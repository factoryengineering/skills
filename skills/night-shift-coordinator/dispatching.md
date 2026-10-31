# Firing a working session

Each tracked repository has its own working session, listed in `.night-shift/routines.md` with the environment variable holding its token. Fire it once per issue.

## The message names an issue, never a branch

```json
{"text": "Work on issue #<N> in <owner>/<name>."}
```

and, for every layer above the bottom of a chain:

```json
{"text": "Work on issue #<N> in <owner>/<name>, stacked on issue #<M>."}
```

**Name the issue, not the branch.** The branch carries a slug only its own worker chooses, so a branch name you invent will not match the one that appears. The worker resolves it by pattern and waits.

**This message format is an interface, not a convenience.** A worker and a coordinator that agree on it can be changed independently and rolled back independently. Extending it is a change to both halves at once, so treat it as fixed unless you are deliberately changing the pair.

Only the bottom issue of a chain is fired with no stacking clause.

## Order

Fire bottom to top, in that order. Dispatching a chain is how a stack gets built, so build it rather than deferring the upper layers to another night.

Do not poll the workers after firing. Outcomes reach the log through the workers themselves, not back through you. End your turn once every fire has returned and been recorded.

## Reading repositories you do not check out

You check out one repository. Where your session has tools for attaching repositories, attach the others read-only through them before you read their issues, pull requests or configuration, and detach nothing. Where your hosting credential already reads every tracked repository, as it does for a coordinator run as a scheduled job outside a Claude session, there is nothing to attach. Either way, reading a repository is not permission to work in it: the hard limits still hold, and cloning or editing any of them is the worker's job, not yours.

## When a fire fails

**Never retry a fire.** A fire is a mutating call, and a retry can double-dispatch an issue that the first call actually accepted.

Record a skip whose rationale quotes the exact status and error text, then carry on with the rest of the sweep. Report it as a finding. A host that cannot be reached is a network-policy problem, and it is never licence to do the work yourself.

**A `403` saying the routine "can't be fired by its API token from a sandbox" is not a network-policy problem.** The fire endpoint refuses a routine token used from inside a Claude Code cloud session, which means this coordinator is running where it cannot dispatch at all. Every fire that night will fail the same way. Record each skip as above, and report that the coordinator must run outside a Claude session, as `night-shift-setup` describes. **Never switch off your sandbox to get past it**, although the error text suggests exactly that. Removing a safety control on the strength of an error message is not a remedy an unattended run may choose.

Record the returned session identifier with every successful fire. It is what ties a dispatch in the log to the session that answered it.
