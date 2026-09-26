# Module 3 — One agent, one workspace

## Why this matters

Parallel agents are the point of the exercise: three agents working for twenty minutes can
produce what one agent produces in an hour. They only pay off if their work stays separate while
they run and comes together cleanly afterwards. This module shows, with a script you run, exactly
how agents sharing one directory corrupt each other's changes; then it gives each agent its own
jj *workspace*, runs three at once, and integrates the results, conflicts included.

## Objectives

After this module you will be able to:

- **M3.T** — Given three tasks, give each of three agents its own workspace, run them concurrently,
  integrate their results into one tested, conflict-free, pushed bookmark named `integration`,
  and clean up, such that `check.sh m3` passes.
- **M3.1** — Demonstrate and explain why two agents sharing one working directory record each
  other's edits in the wrong change.
- **M3.2** — Create, list, address (`name@`), and forget workspaces, placing them outside the
  repository directory.
- **M3.3** — Predict which integration actions make another workspace stale, and repair a stale
  workspace.
- **M3.4** — Integrate several agents' changes as a linear stack or as a merge change, and choose
  between the two for a given situation.
- **M3.5** — Resolve a conflict recorded in a change by editing conflict markers, and confirm the
  resolution propagates to descendant changes.

## Prerequisites

Module 2: `jj new`, `jj commit`, `jj squash`, `jj rebase` with source and destination flags
(M2.1, M2.3), and bookmarks and pushing (M2.4).

---

## 3.1 The shared-directory problem, measured *(builds M3.1)*

Recall from Module 1 that every jj command begins by snapshotting the working directory into
`@`. Now put two agents in the same directory. Run:

```bash
demo-shared-dir.sh
```

The script resets the lab and starts two scripted agents at once in `~/jj-lab/app`. Agent X
writes `x.txt`, "thinks" for two seconds, and runs `jj commit -m "agent X: add x.txt"`. Agent Y
writes `y.txt` one second after X started, "thinks" for two seconds, and commits
`agent Y: add y.txt`.

```text
# output
Changes after both agents finished (newest first):
qyswktro  (no description)   files:
vpvqnsxq  agent Y: add y.txt   files:
snlostor  agent X: add x.txt   files: x.txt, y.txt
```

Agent X's commit contains **both** files; agent Y's commit is **empty**. When X ran
`jj commit`, the snapshot recorded everything on disk, including Y's `y.txt`. By the time Y
committed, its file already belonged to X's change. Neither agent did anything wrong, and both
reported success. The run is repeatable: it gives the same result every time, because it
depends only on the order of events, not on luck.

Real agents make this worse: they write many files over minutes, run commands that themselves call
jj (status checks, scripts, other tools), and commit at unpredictable times. Git in one directory has the same problem in a
different form (a shared index and a shared HEAD). The fix is the same idea in both systems:
separate directories.

## 3.2 Workspaces *(builds M3.2)*

A **workspace** is an additional working directory attached to the same repository. Each
workspace has:

- its own files on disk,
- its own working-copy change, written `<workspace-name>@` (your original directory is the
  workspace named `default`, so its change is `default@`),

and all workspaces share one set of changes, one set of bookmarks, and one operation log.

Reset the lab and create three workspaces, one per agent:

```bash
lab.sh reset
cd ~/jj-lab/app
mkdir -p ../app-ws
jj workspace add ../app-ws/validate --name validate -r 'trunk()'
jj workspace add ../app-ws/count    --name count    -r 'trunk()'
jj workspace add ../app-ws/docs     --name docs     -r 'trunk()'
```

```text
# output (first command)
Created workspace in "../app-ws/validate"
Working copy  (@) now at: srwvomrt 1a2e0050 (empty) (no description set)
Parent commit (@-)      : llrykkos c0f99051 main | initial inventory module
Added 4 files, modified 0 files, removed 0 files
```

Three details matter:

- **`mkdir -p` first.** `jj workspace add` does not create missing parent directories; without
  the `mkdir` you get `No such file or directory`.
- **Outside the repository.** The workspaces live in `~/jj-lab/app-ws/`, next to `app/`, not
  inside it. jj itself copes with a nested workspace (it skips any directory that contains a `.jj`
  folder when snapshotting), but nothing else does: in the outer directory, `git status` lists the
  nested copy as untracked (`?? agents/`), `grep -r` and editors' search find every function twice,
  test runners and linters may pick up the copy, and an agent working in the outer directory sees a
  second version of every file. Keep workspaces as siblings.
- **`-r` chooses the starting point.** Each new workspace gets a fresh empty working-copy change
  whose parent is `-r` (default: the parent of your current `@`). Tasks that depend on another
  agent's result can start from it, for example `-r 'validate@-'`.

List them and look at the graph:

```bash
jj workspace list
jj log -r 'working_copies()'
```

```text
# output (jj workspace list)
count: ../app-ws/count mloztkly 2e9a8296 (empty) (no description set)
default: . ylvzzvzk 561cc2ef (empty) (no description set)
docs: ../app-ws/docs mmxrrrzv 11d1e0b3 (empty) (no description set)
validate: ../app-ws/validate srwvomrt 1a2e0050 (empty) (no description set)

# output (jj log -r 'working_copies()', abridged)
@  ylvzzvzk you@example.com 2026-09-26 09:02:44 default@ 561cc2ef
│  (empty) (no description set)
~
○  mmxrrrzv you@example.com 2026-09-26 09:02:44 docs@ 11d1e0b3
│  (empty) (no description set)
~
○  mloztkly you@example.com 2026-09-26 09:02:44 count@ 2e9a8296
│  (empty) (no description set)
~
○  srwvomrt you@example.com 2026-09-26 09:02:44 validate@ 1a2e0050
│  (empty) (no description set)
~
```

`working_copies()` selects every workspace's `@`; `jj log` labels each one `name@`.

A workspace directory contains the project files and a small `.jj` folder that points back to
the main repository. In jj 0.45 it has **no `.git`**: Git commands fail there
(`fatal: not a git repository`), and the repository data (objects, operation log) lives in
the main workspace's `.jj/` and `.git/`. Module 5 shows why that matters for sandboxed agents.
(jj's unreleased 0.46 adds optional Git worktrees for workspaces; see Appendix C.)

### Running the agents

Start the three scripted agents concurrently, each in its own workspace. The trailing `&` runs
each in the background; `wait` waits for all three:

```bash
for a in validate count docs; do agent.sh $a ../app-ws/$a & done; wait
```

Each agent edits
files and finishes with `jj commit -m "<its message>"` in its own workspace.

```text
# output (order varies)
agent.sh [count] done in /home/you/jj-lab/app-ws/count: committed "feat: add item_count()"
agent.sh [docs] done in /home/you/jj-lab/app-ws/docs: committed "docs: clarify remove_item semantics"
agent.sh [validate] done in /home/you/jj-lab/app-ws/validate: committed "feat: reject non-positive quantities"
Concurrent modification detected, resolving automatically.
```

That last line is jj noticing that three processes wrote to the operation log at the same time.
jj's operation log is designed for this: each command records its operation without taking a
repository-wide lock, and the next command that sees several simultaneous "latest" operations
merges them. Because each agent touched only its own workspace's changes, the merge is trivial.
(Module 4 shows what happens when two agents rewrite the *same* change.)

```bash
jj log -r 'trunk()..'
```

```text
# output (abridged)
○  xyxuyrnr  validate@  (empty) (no description set)
○  srwvomrt             feat: reject non-positive quantities
○  sxouroql  count@     (empty) (no description set)
○  mloztkly             feat: add item_count()
○  xpxpotmw  docs@      (empty) (no description set)
○  mmxrrrzv             docs: clarify remove_item semantics
```

Three finished changes, each directly on `trunk()`, each with its agent's empty `@` on top. Each
agent's finished work is `<name>@-`, a revset that keeps working no matter what the change IDs are.

### Practice 3.2

Answer from the state above, then check with `jj log`:

1. Which revset selects all three finished task changes and nothing else?
2. You want a fourth agent to review the validate agent's work *with its changes present on disk*.
   Which `jj workspace add` command creates that workspace?

<details><summary>Feedback</summary>

1. `validate@- | count@- | docs@-`, or `working_copies()-  ~ trunk()` (parents of all working
   copies, minus trunk, which is `default@`'s parent here).
2. `jj workspace add ../app-ws/review --name review -r 'validate@-'`: the new workspace's
   empty `@` sits on top of the validate change, so its files include the validate edits.

</details>

## 3.3 Integrating: stack or merge *(builds M3.4)*

The three results are siblings. To publish them as one branch, one integrator (you, in the
`default` workspace) combines them. There are two shapes:

Read both before running anything; you will run only the first.

**A linear stack**: rebase the changes on top of each other.

```bash
# (don't run yet)
jj rebase -s 'count@-' -o 'validate@-'
jj rebase -s 'docs@-'  -o 'count@-'
```

**A merge change**: one change with several parents.

```bash
# (for comparison only; not used in this lab)
jj new 'validate@-' 'count@-' 'docs@-' -m "merge: integrate agents' work"
```

| | Linear stack | Merge change |
|---|---|---|
| History | One line; each change reviewable on its own | A merge commit with several parents |
| Agents' changes | Rewritten (rebased), so their workspaces go stale (3.4) | Untouched; agents can keep working |
| Conflicts | Appear in the specific change that conflicts, two sides at a time | All appear in the one merge change, possibly with 3 or more sides |
| Good for | Publishing a reviewable branch after agents finish | Testing the combination while agents are still running |

Conflicts with three or more sides can't be shown in Git's two-sided marker format, so jj falls
back to its own "snapshot" style for those files: one `+++++++` section per side and a `-------`
section per base, which is harder for people and models to edit. That is one more reason to integrate as a
stack when you are about to publish.

Use the linear stack. From `~/jj-lab/app` (the default workspace) run the two `jj rebase`
commands above:

```text
# output (second rebase)
Rebased 2 commits to destination.
New conflicts appeared in 1 commits:
  mmxrrrzv e935f9e2 (conflict) docs: clarify remove_item semantics
Hint: To resolve the conflicts, start by creating a commit on top of
the conflicted commit:
  jj new mmxrrrzv
Then use `jj resolve`, or edit the conflict markers in the file directly.
```

```bash
jj log -r 'trunk()..'
```

```text
# output (condensed to one line per change)
×  xpxpotmw  docs@  (conflict) (empty) (no description set)
×  mmxrrrzv         (conflict) docs: clarify remove_item semantics
│ ×  sxouroql  count@  (conflict) (empty) (no description set)
├─╯
×  mloztkly         (conflict) feat: add item_count()
│ ○  xyxuyrnr  validate@  (empty) (no description set)
├─╯
○  srwvomrt         feat: reject non-positive quantities
```

Both rebases **succeeded**. jj recorded the conflicts inside the changes and carried on; there is
no half-finished rebase to `--continue` or `--abort`. The first conflicted change is the count
change (both the validate and count agents added a test at the same spot in
`test_inventory.py`); everything above it shows `×` because it inherits that conflict, and the
docs change conflicts in its own right (it and the validate agent edited the same docstring).

## 3.4 Resolving conflicts *(builds M3.5)*

Resolve from the **bottom up**: fix the earliest conflicted change first, because its
resolution flows into every change above it.

```bash
jj new mloztkly            # your ID for "feat: add item_count()"
jj resolve --list
```

```text
# output
Working copy  (@) now at: … (conflict) (empty) (no description set)
Parent commit (@-)      : mloztkly 5a8235c8 (conflict) feat: add item_count()
Warning: There are unresolved conflicts at these paths:
test_inventory.py    2-sided conflict
test_inventory.py    2-sided conflict
```

(The path appears twice: once in `jj new`'s warning, once from `jj resolve --list`.)

`jj new <conflicted change>` gives you a scratch change on top, with the conflicted files on
disk. Open `test_inventory.py`:

```text
<<<<<<< srwvomrt 3dc49d99 "feat: reject non-positive quantities" (rebase destination)
    def test_rejects_non_positive(self):
        with self.assertRaises(ValueError):
            inventory.add_item("bolt", 0)

||||||| llrykkos c0f99051 "initial inventory module" (parents of rebased revision)
=======
    def test_item_count(self):
        inventory.add_item("bolt", 2)
        inventory.add_item("nut", 1)
        self.assertEqual(inventory.item_count(), 2)

>>>>>>> mloztkly 4e2e9a67 "feat: add item_count()" (rebased revision)
```

This is the Git style you configured in Module 0, with jj's labels:

| Marker line | Starts |
|---|---|
| `<<<<<<<` | the first side (here: the change you rebased onto) |
| `\|\|\|\|\|\|\|` | the common ancestor, the "base" (here: nothing, since both sides inserted new lines) |
| `=======` | the second side (here: the change being rebased) |
| `>>>>>>>` | end of the conflict |

Resolve by writing what the code should be and deleting all four marker lines and the base
section. Both tests should survive:

```python
    def test_rejects_non_positive(self):
        with self.assertRaises(ValueError):
            inventory.add_item("bolt", 0)

    def test_item_count(self):
        inventory.add_item("bolt", 2)
        inventory.add_item("nut", 1)
        self.assertEqual(inventory.item_count(), 2)

```

Then check and move the resolution into the conflicted change:

```bash
python3 -m unittest -q
jj squash
```

```text
# output
OK
Rebased 3 descendant commits.
Working copy  (@) now at: ozzouxku e74b8783 (empty) (no description set)
Parent commit (@-)      : psrsmpzx d378810d feat: add item_count()
Existing conflicts were resolved or abandoned from 1 commits.
There are still unresolved conflicts in rebased descendants.
Hint: To resolve the conflicts, start by creating a commit on top of
the conflicted commit:
  jj new nmmkqsxq
```

`jj squash` folds the scratch change into `feat: add item_count()`. That change is now clean, and
jj rebased its descendants: `count@` is no longer marked `×`. The docs change still shows `×`,
because it has its own conflict.

Repeat for the docs change: `jj new <docs change>`, open `inventory.py`:

```text
<<<<<<< … "feat: add item_count()" (rebase destination)
    """Remove qty units of name; return the new count."""
    if qty <= 0:
        raise ValueError("qty must be positive")
||||||| … "initial inventory module" (parents of rebased revision)
    """Remove qty units of name; return the new count."""
=======
    """Remove qty units of name; return the new count.

    Counts may go negative: a negative count records a backorder.
    """
>>>>>>> … "docs: clarify remove_item semantics" (rebased revision)
```

Read the base: the original docstring. One side added validation *after* it; the other side
*changed* it. A correct resolution keeps both intents:

```python
    """Remove qty units of name; return the new count.

    Counts may go negative: a negative count records a backorder.
    """
    if qty <= 0:
        raise ValueError("qty must be positive")
```

Then `python3 -m unittest -q` (now `OK`) and `jj squash`. `jj log -r 'trunk()..'` shows no `×`.

> **Resolving is a judgment call, not a text operation.** "Keep both sides" happened to be right
> twice here. When two agents implement the same behavior differently, keeping both produces
> duplicate or contradictory code that may still pass the tests. Always read the base section
> and decide what the combined code should do. This is exactly where to give an agent explicit
> instructions (Module 5) or keep a human in the loop.

## 3.5 Stale workspaces *(builds M3.3)*

You rebased the count and docs agents' changes from the `default` workspace. Their working-copy
changes (`count@`, `docs@`) were rewritten along with them, but the files in their directories
were not touched, since only a command run *in* a workspace updates that workspace's files.
Look:

```bash
cd ../app-ws/docs
jj status
```

```text
# output
Error: The working copy is stale (not updated since operation f09c05ec87e4).
Hint: Run `jj workspace update-stale` to update it.
```

A workspace is **stale** when its working-copy change was rewritten by another workspace. jj
refuses to run normal commands there, because snapshotting old files over the new change would
silently undo the other workspace's rewrite. The repair:

```bash
jj workspace update-stale
```

This rewrites the workspace's files to match the latest version of its working-copy change. Any
agent that sees the stale error should run it and continue; the plugin in Module 6 does it
automatically at session start. (A jj setting, `snapshot.auto-update-stale = true`, makes jj do it
on every command; it is off by default because a surprise file update under a running agent can
be as confusing as the error.)

Which actions make which workspaces stale? Rewrites of *another* workspace's `@` that change the
files it should have on disk: rebasing it or its ancestors onto different content (as here),
squashing content into it or into an ancestor, abandoning its parent. A rewrite that leaves its
files identical, such as re-describing its parent, is absorbed automatically and does not make
it stale. The validate workspace is not stale: its change was the rebase *destination*, not
rewritten.

### Practice 3.5

Without running anything: after the two rebases, which of `validate`, `count`, `docs`, and
`default` are stale?

<details><summary>Feedback</summary>

`count` and `docs`. The count change moved onto validate, and its `@` moved with it; the docs
change and its `@` moved onto count. `validate@` and `default@` were not rewritten. (Resolving
conflicts later rewrote `count@` and `docs@` again, which doesn't change the answer.)

</details>

## 3.6 Publish and clean up *(builds M3.2, M3.T)*

From the default workspace, bookmark the top of the stack, run the tests on it, and push:

```bash
cd ~/jj-lab/app
jj new 'docs@-'                    # look at the integrated result on disk
python3 -m unittest -q
jj bookmark create integration -r 'docs@-'
jj git push --bookmark integration
```

Then release the workspaces:

```bash
jj workspace forget validate count docs
rm -rf ../app-ws/validate ../app-ws/count ../app-ws/docs
```

`jj workspace forget` removes a workspace from the repository's bookkeeping. It deletes no files
and abandons no changes: each agent's work is already in the stack, and its empty `@` simply
stops being tracked (jj abandons discardable empty changes automatically).

---

## Knowledge check

1. *(M3.1)* Two agents share one directory. Agent A edits `a.py`; before A commits, agent B edits
   `b.py` and runs `jj status`. Then A runs `jj commit -m "A"`. Where is `b.py`'s edit?
   - a) In a separate change created for B by `jj status`.
   - b) In change "A", because the working-copy change contained both edits when A committed.
   - c) Nowhere; `jj status` is read-only.
   - d) In B's own change, because jj tracks which process edited which file.

2. *(M3.2)* You run `mkdir -p agents && jj workspace add ./agents/a --name a` from the repository
   root. What goes wrong?
   - a) Nothing; that is the recommended layout.
   - b) jj ignores the nested workspace when snapshotting, but Git, search tools, test runners, and any
     agent working in the default workspace see a second copy of the whole project inside it.
   - c) jj refuses to create a workspace inside the repository.
   - d) The default workspace's next snapshot records `agents/a/…` as ordinary files, so `@` suddenly
     contains a copy of the project.

3. *(M3.3)* You squash a fix into `agent-b@-` from the default workspace. Agent B's next command is
   `jj status`. What happens?
   - a) It works; squashing into `@-` doesn't touch `agent-b@`.
   - b) It fails with "The working copy is stale", because `agent-b@` was rebased onto the rewritten
     `agent-b@-`; B should run `jj workspace update-stale`.
   - c) B's edits are lost.
   - d) jj automatically merges the two versions of B's files.

4. *(M3.4)* Agents A and B are still working, and you want to run the full test suite on the
   combination of their finished changes so far without disturbing them. Which is appropriate?
   - a) `jj rebase -s B@- -o A@-`, then test.
   - b) `jj new A@- B@- -m "trial merge"` in the default workspace, then test.
   - c) `jj squash --from B@- --into A@-`, then test.
   - d) Ask both agents to stop and run `git merge`.

5. *(M3.5)* After a rebase, changes P (bottom), Q, and R (top) of a stack are all marked
   `(conflict)`. Only P has a conflict of its own. What should you do?
   - a) Resolve R first, since it is the change you will push.
   - b) Resolve P with `jj new P`, fix the files, `jj squash`; Q and R lose the inherited conflict.
   - c) Resolve all three separately.
   - d) Abandon Q and R, then resolve P.

6. *(M3.5)* In a Git-style conflict, what is between `|||||||` and `=======`?
   - a) The version from the change being rebased.
   - b) The common ancestor (base) that both sides started from.
   - c) jj's suggested resolution.
   - d) Lines both sides agree on.

### Answer key

1. **b.** `jj status` snapshotted both edits into the shared `@`; A's commit then described
   that `@`. (a) snapshots never create changes per process; (c) `jj status` *does* snapshot;
   (d) jj has no idea which process wrote a file. Reread 3.1.
2. **b.** jj skips directories containing `.jj`, but every other tool walks straight into the copy.
   (a) is the opposite of the advice; (c) jj allows it; (d) is a plausible guess that jj 0.45 does
   not do: it skips nested workspaces. Reread 3.2.
3. **b.** Rewriting `agent-b@-` rebases `agent-b@`, which makes B's workspace stale. (a) forgets
   automatic descendant rebasing; (c) the files are still on disk, and `update-stale` reconciles;
   (d) jj refuses rather than guessing. Reread 3.5.
4. **b.** A merge change leaves A's and B's changes untouched. (a) and (c) rewrite changes whose
   workspaces are in use, making them stale mid-task; (d) Git write commands bypass jj
   (Module 1.5). Reread 3.3.
5. **b.** Descendants inherit the earliest conflict; fixing it propagates. (a) wastes work and may
   be undone by the rebase from below; (c) and (d) are unnecessary. Reread 3.4.
6. **b.** The base. (a) is the section after `=======`; (c) and (d) do not exist. Reread 3.4.

## Performance task

```bash
lab.sh reset
cd ~/jj-lab/app
```

1. Create workspaces `validate`, `count`, and `docs` under `~/jj-lab/app-ws/`, each starting at
   `trunk()`. *(M3.2)*
2. Run the three scripted agents concurrently, one per workspace. *(M3.1)*
3. Integrate the three finished changes into one linear stack on top of `trunk()`, in any order
   you choose. *(M3.4)*
4. Resolve every conflict so that no change is marked `(conflict)`, both agents' intent survives
   in each resolution, and the tests pass at the top of the stack. *(M3.5)*
5. Repair any stale workspace you encounter (you may need to, depending on your order). *(M3.3)*
6. Bookmark the top of the stack as `integration`, push it, then forget all three workspaces and
   delete their directories. *(M3.2, M3.T)*

```bash
check.sh m3
```

## Gate

Move on to Module 4 when `check.sh m3` passes and you scored at least 5 of 6 on the
knowledge check. If "tests pass at origin/integration" fails, one of your resolutions dropped a
side: `jj diff -r <change>` on each change of the stack shows what each contributes. If you
missed question 1 or 2, rerun `demo-shared-dir.sh` and reread 3.1–3.2: the rest of the
course assumes one workspace per agent.
