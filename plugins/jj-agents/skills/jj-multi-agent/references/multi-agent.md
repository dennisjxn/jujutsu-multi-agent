# Running several agents in one jj repository

## Why one workspace per agent

jj snapshots the working directory at the start of every command. If two agents share a
directory, agent A's `jj commit` snapshots agent B's half-written files into A's change, and
B's own commit ends up empty. Separate workspaces give each agent its own files and its own
working-copy change (`<name>@`), while sharing one repository, one operation log, and one
set of bookmarks.

## Provisioning (orchestrator or user)

```
cd <repo>                                  # the main (default) workspace
mkdir -p ../<repo>-ws
jj workspace add ../<repo>-ws/agent-a --name agent-a -r 'trunk()'
jj workspace add ../<repo>-ws/agent-b --name agent-b -r 'trunk()'
jj log -r 'working_copies()'               # agent-a@ and agent-b@ now exist
```

Keep workspaces **outside** the repository directory. jj skips a nested workspace when
snapshotting, but Git, search, test runners, and agents in the outer workspace would all see a
second copy of the project. Base each on the revision the task needs
(`-r 'trunk()'`, or another agent's result `-r 'agent-a@-'` for dependent work).

Then start each agent with its working directory set to its workspace.

## Inside a workspace (each agent)

Follow the per-task loop in SKILL.md. Rewrite only changes that are yours: `@`, and changes
you created in this session. Read other agents' work with `jj log -r '<name>@'` and
`jj diff -r '<name>@-'`, but do not describe, rebase, squash into, or abandon it.

## Integrating (one integrator, usually in the default workspace)

Option 1 — linear stack (reviewable history):

```
jj rebase -s agent-b@- -o agent-a@-        # B's finished work on top of A's
jj rebase -s agent-c@- -o agent-b@-
jj log -r 'trunk()..'                      # look for (conflict)
```

`-s` moves the finished change and its descendants, including the agent's empty `@`, so the
agent's workspace follows. That rewrite makes the agent's workspace stale; the agent (or you)
runs `jj workspace update-stale` there before its next command.

Option 2 — merge change (leaves agents' changes untouched):

```
jj new agent-a@- agent-b@- agent-c@- -m "merge: integrate agents' work"
```

Either way, run the tests on the result before creating a bookmark:

```
jj bookmark create integration -r <top change>
jj git push --bookmark integration          # after the user agrees
```

## Resolving a conflict

A conflicted change is marked `(conflict)` (and `×` in the graph). Its descendants are marked
too, because they inherit it. Resolve the **earliest** conflicted change first:

```
jj new <conflicted-change>                 # a scratch change on top
jj resolve --list                          # which files
# edit each file: keep both sides' intent, remove all marker lines
python3 -m unittest -q                     # or the project's tests
jj squash                                  # move the resolution into the conflicted change
```

With `ui.conflict-marker-style = "git"` the markers look like Git's:
`<<<<<<< side A` · `||||||| base` · `=======` · `>>>>>>> side B`. Everything between
`|||||||` and `=======` is the common ancestor: delete it together with the markers.

Resolution propagates: descendants are rebased onto the resolved change and their inherited
conflict disappears unless they conflict in their own right.

## Cleaning up

```
jj workspace forget agent-a agent-b agent-c
rm -rf ../<repo>-ws/agent-a ../<repo>-ws/agent-b ../<repo>-ws/agent-c
```

`forget` never deletes files and never abandons the agents' changes; their commits stay in
history.

## Hosts and isolation features

- Claude Code: `--worktree`, subagents with `isolation: worktree`, and `/batch` create Git
  worktrees unless a `WorktreeCreate` hook is configured. The jj-agents plugin's hook creates
  a jj workspace in `../<repo>-ws/claude-<name>` instead.
- OpenAI Codex: the app's and CLI's worktree features create Git worktrees, which jj does not
  track as workspaces. Create jj workspaces yourself and launch Codex in them (`codex-jj`).
- Kiro: subagents and parallel spec tasks share one working directory. Run parallel Kiro
  sessions in separate jj workspaces instead.
