# Recovery playbook

The operation log (`jj op log`) records every change to the repository by every workspace.
Nothing is lost until old operations are explicitly abandoned and garbage-collected. Before
any repair: read, then act, then read again.

```
jj op log -n 15                 # who did what, in which workspace (shown after the user@host)
jj op show <op-id> -p           # exactly what one operation changed
jj evolog -r <change> --summary # every recorded version of one change
```

## Stale working copy

Symptom: `Error: The working copy is stale (not updated since operation …)`.
Cause: another workspace rewrote this workspace's `@` in a way that changes its files
(for example rebased it onto new content, or squashed content into it or its ancestors).
Fix: `jj workspace update-stale`. Your files are updated to the latest version of `@`.

## An undo hit the wrong operation

`jj undo` reverts the latest operation in the whole repository. With several agents, that
may be another agent's operation. Fix:

1. `jj redo` — re-applies what the undo reverted.
2. Find the operation you actually meant: `jj op log` (look at the workspace name and args).
3. `jj op revert <that-op-id>` — reverts only that operation.

Prefer targeted repairs to rewinding: `jj op revert <op>` for one operation,
`jj restore --from <rev> <paths>` for files, `jj abandon <change>` for one change.
`jj op restore <op>` rewinds *everything*, every workspace included.

## Divergent change

Symptom: a change ID appears twice, marked `(divergent)`, shown as `<id>/0` and `<id>/1`
(and their descendants may be duplicated too).
Cause: two processes rewrote the same change starting from the same repository state, each without
seeing the other's rewrite (for example two agents describing it at the same moment).

1. `jj log -r 'divergent()'` — compare the versions (`jj diff -r <id>/0`, `jj diff -r <id>/1`).
2. Keep one, drop the other with everything built on it: `jj abandon '<id>/0::'`
   (after checking with the user). The offsets can renumber after each operation; re-read the log.
3. `jj log -r 'divergent()'` must print nothing.

`jj converge` (experimental in 0.45) can merge the versions automatically when their
descriptions agree; when they differ it needs an interactive session.

## A change destroyed good content

Symptom: a file was deleted or overwritten inside a change that also contains good work.

```
jj restore --from <good-rev> --into <bad-change> <paths>
```

Descendants are rebased automatically. Use `trunk()` or `<bad-change>-` as `<good-rev>`,
or a commit ID from `jj evolog`. To restore a file into `@`, omit `--into`.

## A secret was snapshotted

Every jj command snapshots every non-ignored file. A credential written to disk is therefore
in `@` and in each earlier snapshot of `@` listed by `jj evolog`.

1. Treat the credential as compromised: rotate it. Local history is not the only exposure
   (agent transcripts and logs may also contain it).
2. Ignore it: add the pattern (e.g. `.env*`) to `.gitignore`.
3. Stop tracking it: `jj file untrack <path>` (only works once the path is ignored).
4. Check: `jj log -r 'all()' -- <path>` prints nothing (no visible change contains it).

Hidden snapshots are local: `jj git push` only pushes visible commits reachable from pushed
bookmarks. Purging them locally (`jj op abandon`, `jj util gc`) discards undo history for every
workspace and can leave other workspaces unable to load; do it only with the user, with all
agents stopped.

## Prevention

- Ignore secrets and build output before agents start (`.gitignore`).
- `snapshot.max-new-file-size` (default 1 MiB) stops large new files from being tracked.
- `snapshot.auto-track` can restrict which new files are tracked automatically.
