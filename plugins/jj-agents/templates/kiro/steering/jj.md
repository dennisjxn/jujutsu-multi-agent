---
inclusion: always
---

# Version control: Jujutsu (jj), not Git

This repository is managed with Jujutsu (`jj`), colocated with Git. Follow `AGENTS.md` at the
repository root; the rules that matter most are repeated here.

- Never run Git write commands (`git commit`, `git push`, `git add`, `git checkout`,
  `git rebase`, `git reset`, `git stash`, `git merge`). Read-only Git commands are fine.
- jj records every file you change automatically. There is no staging step.
- Start each task with `jj new 'trunk()' -m "<type>: <task>"` (or `jj new` to build on the
  current change). Finish it with `jj commit -m "<final message>"`.
- Always pass `-m` to `jj describe`, `jj commit`, `jj new`, `jj split`; use `jj squash -u`
  when folding a fix into a described change. Never let jj open an editor.
- Work only in your own workspace directory. Other agents' changes appear in `jj log` as
  `<name>@`; do not edit, rebase, or abandon them.
- Never run `jj undo`, `jj redo`, `jj abandon`, `jj op restore`, `jj op revert`, `jj op abandon`,
  or `jj git push` without asking the user: they affect every workspace, discard work, or
  publish it.
- If jj says the working copy is stale, run `jj workspace update-stale`.
- If a change shows `(conflict)`, resolve the markers in the files of a new change on top
  (`jj new <change>`), then `jj squash` the resolution into it.
