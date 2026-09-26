# Agent instructions

## Version control: Jujutsu (jj)

This repository uses Jujutsu (`jj`), colocated with Git. Several agents may work in it at
the same time, each in its own jj workspace. These rules keep their work separate and recoverable.

### Always
- Use `jj` for every version-control action. jj records every file you change automatically;
  there is no staging area and no `git add`.
- Work only inside your own workspace directory (`jj workspace root` prints it). Your current
  change is `@`; other agents' current changes appear in `jj log` as `<workspace-name>@`.
- Start a task on a fresh change: `jj new 'trunk()' -m "<type>: <what you are doing>"`.
- Finish a task: `jj commit -m "<type>: <final summary>"`. This leaves an empty `@` on top.
- Give every command that takes a message a `-m`. Fold a fix into the change below with
  `jj squash -u` (keeps that change's message). jj must never open an editor.
- Check state with `jj status` and `jj log -r 'trunk()..@'` before and after each step.
- If jj reports "The working copy is stale", run `jj workspace update-stale` and continue.
- If a change is marked `(conflict)`: `jj new <that change>`, edit the files to remove the
  conflict markers keeping both sides' intent, run the tests, then `jj squash`.

### Never, without asking the user first
- `jj undo`, `jj redo`, `jj op restore`, `jj op revert`, `jj op abandon`: these rewind the
  whole repository, including other agents' workspaces.
- `jj abandon`, or rewriting (`describe`, `rebase`, `squash --into`) any change that is not yours.
- `jj git push`: publishing is the user's decision.

### Never
- Git write commands: `git commit`, `git push`, `git pull`, `git add`, `git checkout`,
  `git switch`, `git rebase`, `git reset`, `git stash`, `git merge`, `git cherry-pick`,
  `git worktree add`. Read-only Git commands (`git status`, `git log`, `git diff`, `git show`,
  `git blame`) are fine.
- Writing secrets or credentials to files in the repository: every file is snapshotted.

### Commit messages
`<type>: <summary>` with type one of feat, fix, docs, test, refactor, chore.
