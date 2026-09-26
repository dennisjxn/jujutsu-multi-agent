---
name: jj-multi-agent
description: Version control with Jujutsu (jj) when one or more AI coding agents work in the same repository. Use whenever the repository has a .jj directory, the user mentions jj or Jujutsu, or the task involves committing, branching, rebasing, resolving conflicts, pushing, undoing, or running several agents in parallel (workspaces). Covers the per-task change workflow, one-workspace-per-agent isolation, integrating agents' work, and safe recovery with the operation log.
license: MIT
compatibility: Requires jj 0.45 or newer and git 2.41 or newer on PATH. Written for jj 0.45.x; works in Claude Code, OpenAI Codex, and Kiro.
metadata:
  version: "1.0.0"
  jj-version: "0.45"
---

# Jujutsu (jj) for coding agents

You are working in a Jujutsu repository. jj is Git-compatible: the repository is usually
*colocated* (it has both `.jj/` and `.git/`), and the remote is an ordinary Git remote.
Everything below uses jj commands only.

## Five facts that change how you work

1. **The working copy is a commit.** It is called `@`. Every jj command first snapshots
   your files into `@`. There is no staging area: do not look for `git add`.
2. **Changes have stable IDs.** A *change ID* (letters k–z, e.g. `kxryzmsp`) survives
   rewrites; a *commit ID* (hex) changes on every rewrite. Refer to changes by change ID.
3. **Descendants follow automatically.** Rewriting a change (describe, squash, rebase)
   rebases everything on top of it. Conflicts are recorded *in* commits, not a blocking state.
4. **Every operation is logged.** `jj op log` lists them; the log is shared by all workspaces.
   `jj undo` reverts the *latest* operation in the repository, which may be another agent's.
5. **Branches are called bookmarks** and do not move when you create new changes.

## Non-interactive rules (mandatory for agents)

- Pass `-m "<message>"` to `jj describe`, `jj commit`, and `jj split` (they open an editor
  without it), and to `jj new` so everyone can see what the change is for.
- Fold a fix into the change below with `jj squash -u` (keeps the destination's message)
  or give a message with `-m`. A bare `jj squash` between two described changes opens an editor.
- Split by paths, never interactively: `jj split -m "<first part>" <paths>` puts `<paths>` in
  the first change and the rest in a new change on top.
- If `JJ_AGENT=1` is set, the user's jj config disables the editor and pager for you. If a
  command still tries to open an editor, rerun it with `-m`.

## The per-task loop

```
jj status                                   # where am I? (also snapshots)
jj new 'trunk()' -m "feat: <task>"          # fresh change for this task (or: jj new)
# ... edit files, run tests ...
jj diff --summary                           # review what the change contains
jj commit -m "feat: <final summary>"        # finish; leaves an empty @ on top
jj log -r 'trunk()..@'                      # confirm the stack
```

Keep one logical change per task. Separate unrelated edits with `jj split`.

## Multiple agents: one workspace each

Agents must never share a working directory: a snapshot taken by one agent's command
captures the other agent's half-written files into the wrong change.

- Create a workspace per agent **outside** the repository directory:
  `mkdir -p ../<repo>-ws && jj workspace add ../<repo>-ws/<name> --name <name> -r 'trunk()'`
- Run each agent with its working directory set to its workspace.
- Refer to another workspace's current change as `<name>@` (e.g. `jj log -r 'agent-a@-'`).
- Only rewrite your own changes. Integration (rebasing, merging other agents' changes) is
  done by one integrator, usually from the `default` workspace.
- After integrating: `jj workspace forget <name>` and delete the directory.

Details, integration recipes, and conflict resolution: `references/multi-agent.md`.

## When something looks wrong

| Symptom | Do this |
|---|---|
| `The working copy is stale` | `jj workspace update-stale` |
| `(conflict)` on a change | `jj new <change>`, fix markers, run tests, `jj squash` |
| `(divergent)`, IDs shown as `<id>/0`, `<id>/1` | Two agents rewrote the same change; see `references/recovery.md` |
| A bookmark shown as `name??` | Conflicting bookmark moves; `jj bookmark set <name> -r <rev>` after checking with the user |
| A file you need was deleted by an earlier change | `jj restore --from <good-rev> --into <change> <path>` |
| You committed to the wrong change | `jj squash --from <src> --into <dst> <paths>` |
| "Won't push commit … since it has conflicts" | resolve first; never pass `--allow-conflicts` |

**Ask the user before** `jj undo`, `jj redo`, `jj op restore`, `jj op revert`,
`jj op abandon`, `jj abandon`, or `jj git push`. The first four rewind the repository for every
workspace; `jj op abandon` and `jj abandon` discard history or work; pushing publishes.
Full recovery playbook: `references/recovery.md`.

## Never

- Git write commands in a jj repository (`git commit`, `git add`, `git push`, `git checkout`,
  `git rebase`, `git reset`, `git stash`, `git merge`, `git worktree add`). Read-only Git
  commands are fine.
- Writing secrets into the repository tree: jj snapshots every non-ignored file, and old
  snapshots persist in `jj evolog` even after you delete the file.

## Machine-readable output

jj has no `--json` flag; use templates:
`jj log --no-graph -r '<revset>' -T 'json(self) ++ "\n"'` (one JSON object per commit).
If the jj MCP server from this plugin is available, prefer its tools (`jj_status`, `jj_log`,
`jj_workspace_add`, …): pass your absolute working directory as `workspace`.

Command reference with exact flags for jj 0.45: `references/commands.md`.
Host-specific setup (Claude Code, Codex, Kiro): `references/hosts.md`.
