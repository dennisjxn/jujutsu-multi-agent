# jj command reference for agents (jj 0.45)

Every command below is non-interactive as written. Global flags useful in scripts:
`--no-pager`, `--color=never`, `--quiet`, `-R <path>` (operate on another workspace),
`--ignore-working-copy` (read without snapshotting).

## Looking

| Goal | Command |
|---|---|
| State of your working copy | `jj status` (alias `jj st`) |
| Your stack since trunk | `jj log -r 'trunk()..@'` |
| Everything, including other workspaces | `jj log -r 'all()' -n 30` |
| Every workspace's current change | `jj log -r 'working_copies()'` |
| Diff of a change | `jj diff -r <rev>` · paths only: `jj diff -r <rev> --summary` · Git format: `--git` |
| One change in full | `jj show <rev>` |
| History of one change (every rewrite) | `jj evolog -r <rev>` (add `--summary` for files) |
| Operation history (undo log) | `jj op log -n 20` · details: `jj op show <op-id>` |
| Conflicted files | `jj resolve --list -r <rev>` |
| JSON | `jj log --no-graph -r <revset> -T 'json(self) ++ "\n"'` |

## Revsets you will use

`@` your working-copy change · `@-` its parent · `<name>@` workspace `<name>`'s change ·
`trunk()` the main remote branch · `x..y` in y not in x · `::x` ancestors · `x::` descendants ·
`x-` parents · `x+` children · `working_copies()` · `conflicts()` · `divergent()` ·
`description(substring:"text")` · `files("path")` · `mine()` · `bookmarks()` ·
`<change-id>/<n>` one version of a divergent change.

## Changing

| Goal | Command |
|---|---|
| Start work on top of trunk | `jj new 'trunk()' -m "<msg>"` |
| Start work on top of the current change | `jj new -m "<msg>"` |
| Name the current change | `jj describe -m "<msg>"` (another: `-r <rev>`) |
| Finish the current change | `jj commit -m "<msg>"` |
| Finish only some paths | `jj commit -m "<msg>" <paths>` (the rest stays in the new `@`) |
| Move part of a change into its own change | `jj split -m "<first part msg>" <paths>` |
| Fold `@` into its parent | `jj squash -u` (keep parent's message) or `jj squash -m "<msg>"` |
| Move paths between changes | `jj squash --from <src> --into <dst> [-u] <paths>` |
| Resume editing an older change directly | `jj edit <rev>` (prefer `jj new <rev>` then `jj squash`) |
| Discard file changes in `@` | `jj restore <paths>` |
| Put a file back as it was in another revision | `jj restore --from <rev> [--into <rev>] <paths>` |
| Undo a change's edits, keep the (empty) change | `jj restore --changes-in <rev>` |
| Drop a change entirely | `jj abandon <rev>` (**ask first**) |
| Revert a published change | `jj revert -r <rev> -o @` |
| Copy a change elsewhere | `jj duplicate <rev> -o <dest>` |

## Moving changes

`jj rebase` needs a *source* flag and a *destination* flag:

- source: `-r <rev>` (only that change; its children move to its parent), `-s <rev>`
  (the change and its descendants), `-b <rev>` (the whole branch containing it, relative to the destination)
- destination: `-o <rev>` (onto), `-A <rev>` (insert after), `-B <rev>` (insert before)

Examples: `jj rebase -s agent-b@- -o agent-a@-` (stack B's work on A's) ·
`jj rebase -b @ -o 'trunk()'` (move your branch onto the latest trunk).
A merge change: `jj new <rev1> <rev2> -m "merge: <why>"`.

The older `-d/--destination` flag is still accepted as an alias of `-o/--onto`; use `-o`.

## Bookmarks and remotes

| Goal | Command |
|---|---|
| Fetch | `jj git fetch` |
| Create a bookmark | `jj bookmark create <name> -r <rev>` |
| Move a bookmark forward | `jj bookmark set <name> -r <rev>` (or `jj bookmark move`) |
| Advance a bookmark to a descendant | `jj bookmark advance <name> --to <rev>` (without `--to` it goes to `@`, often an empty change) |
| Push a bookmark | `jj git push --bookmark <name>` (**ask first**) |
| Push a change under a generated name | `jj git push -c <rev>` (**ask first**) |
| Preview a push | `jj git push --bookmark <name> --dry-run` |
| List bookmarks with remote state | `jj bookmark list --all` |

A bookmark shown as `name*` differs from its remote; `name??` is conflicted.
`jj git push` refuses conflicted commits and commits without descriptions; fix, don't override.

## Workspaces

| Goal | Command |
|---|---|
| Create | `mkdir -p ../<repo>-ws && jj workspace add ../<repo>-ws/<name> --name <name> -r 'trunk()'` |
| List | `jj workspace list` |
| Where am I | `jj workspace root` · main workspace: `jj workspace root --name default` |
| Repair after another workspace rewrote yours | `jj workspace update-stale` |
| Stop tracking (files stay on disk) | `jj workspace forget <name>` |

In jj 0.45 a secondary workspace has no `.git` of its own: Git commands fail there, and the
repository data lives in the main workspace's `.jj/` and `.git/`.

## Operation log

| Goal | Command |
|---|---|
| See operations (all workspaces) | `jj op log` |
| What did one operation change | `jj op show <op-id> -p` |
| Revert one specific operation | `jj op revert <op-id>` (**ask first**) |
| Revert the latest operation / re-apply it | `jj undo` / `jj redo` (**ask first**; repository-wide) |
| Return the whole repository to an earlier state | `jj op restore <op-id>` (**ask first**) |
| Read an old state without changing anything | `jj --at-op <op-id> log` |
