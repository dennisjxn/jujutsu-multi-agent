# Module 2 — Everyday work against a Git remote

## Why this matters

Your agents' work ends up on GitHub (or another Git host) as branches and pull requests,
reviewed by people and CI that know nothing about jj. This module is the round trip: start a
task on the latest main, shape the result into clean changes, publish it as a Git branch, and
keep it current when main moves. Every command here is written the way an agent must run it,
with no editor and no interactive prompts.

## Objectives

After this module you will be able to:

- **M2.T** — Given the lab repository, carry a feature from first edit to a pushed bookmark that
  sits on top of the latest `main` as exactly two well-formed changes, such that
  `check.sh m2` passes.
- **M2.1** — Start, describe, finish, and amend changes non-interactively with `jj new`,
  `jj describe`, `jj commit`, and `jj squash`, including folding a fix into an earlier change.
- **M2.2** — Split one change into two by file paths without an interactive tool.
- **M2.3** — Move a stack of changes onto an updated main with `jj rebase`, choosing the correct
  source flag (`-r`, `-s`, `-b`) and destination flag (`-o`, `-A`, `-B`).
- **M2.4** — Create, move, and push bookmarks; fetch from a remote; and interpret tracked,
  moved (`*`), and remote (`@origin`) bookmark states.
- **M2.5** — Produce machine-readable output from jj with templates, including JSON.

## Prerequisites

Module 1 (M1.1–M1.4): the working-copy change, change IDs, reading `jj log`, and basic revsets.

---

## 2.1 A task, start to finish *(builds M2.1)*

Reset the lab so everyone starts from the same place:

```bash
lab.sh reset
cd ~/jj-lab/app
```

The task: add a `low_stock(threshold)` report to `inventory.py`, with a test and a line of
documentation.

**Start on the latest main.** `trunk()` is the remote's main branch, so this always starts a
task from a known base, no matter which change you were standing on:

```bash
jj new 'trunk()' -m "feat: add low_stock report"
```

```text
# output
Working copy  (@) now at: xxpzvoor 9640acc2 (empty) feat: add low_stock report
Parent commit (@-)      : oospxynm 75ce0285 main | initial inventory module
```

(`-m` may be given more than once: `jj describe -m "feat: title" -m "Longer explanation."`
produces a title, a blank line, and a body paragraph, with no editor.)

Describing the change *before* doing the work is a good habit for agents: anyone reading
`jj log` (including other agents) sees what the change is for while it is in progress.

**Do the work.** Append to `inventory.py`:

```python


def low_stock(threshold):
    """Names of items whose count is below threshold, sorted."""
    return sorted(name for name, qty in ITEMS.items() if qty < threshold)
```

Add a test to `test_inventory.py`, inside the `InventoryTest` class (just above the
`if __name__` line):

```python
    def test_low_stock(self):
        inventory.add_item("bolt", 1)
        inventory.add_item("nut", 9)
        self.assertEqual(inventory.low_stock(5), ["bolt"])
```

And append to `README.md`:

```markdown

## Reports

`low_stock(threshold)` lists items below a threshold.
```

Check the change:

```bash
python3 -m unittest -q
jj diff --summary
```

```text
# output (unittest's progress lines abridged)
OK
M README.md
M inventory.py
M test_inventory.py
```

`jj diff` shows the diff of `@` against its parent (add `-r <rev>` for another change,
`--summary` for file names only, `--git` for Git's diff format).

## 2.2 Splitting a change by paths *(builds M2.2)*

Reviewers prefer documentation separate from code. `jj split` divides one change into two.
Given file paths, it runs **without any interactive tool**: the listed paths go into the
*first* change (which gets the `-m` description), and everything else goes into a second
change on top that keeps the original description:

```bash
jj split -m "docs: document low_stock report" README.md
jj log -r 'trunk()..@'
```

```text
# output
Selected changes : xxpzvoor 8d810fb2 docs: document low_stock report
Remaining changes: opqtulku ac7f72c2 feat: add low_stock report
Working copy  (@) now at: opqtulku ac7f72c2 feat: add low_stock report
Parent commit (@-)      : xxpzvoor 8d810fb2 docs: document low_stock report

@  opqtulku you@example.com 2026-09-26 09:01:02 ac7f72c2
│  feat: add low_stock report
○  xxpzvoor you@example.com 2026-09-26 09:01:02 8d810fb2
│  docs: document low_stock report
~
```

Look at the change IDs: the *selected* part kept the original change ID (`xxpzvoor`), and
the remaining part is a new change (`opqtulku`). `@` followed the files you were working on.

Without paths, or with `-i`, `jj split` opens an interactive diff editor: never do that in an
agent. For hunk-level splits (part of one file) there is no built-in non-interactive route in
jj 0.45; split by file, or restructure the edits.

## 2.3 Folding a fix into an earlier change *(builds M2.1)*

The docstring could be clearer. In Git you would edit, `git commit --fixup`, and later
`git rebase -i --autosquash`. In jj, you make the fix in a new change and **squash** it into
its parent:

```bash
jj new                      # an empty, undescribed change on top of the feature
# edit the docstring in inventory.py to:
#     """Return the sorted names of items whose count is below threshold."""
jj squash
```

```text
# output
Working copy  (@) now at: wsyvmrwn 53c2393c (empty) (no description set)
Parent commit (@-)      : opqtulku a4b36ba1 feat: add low_stock report
```

`jj squash` moves the contents of `@` into `@-` and leaves a fresh empty `@`. Because the fix
change had *no description*, there was nothing to merge and jj asked nothing.

> **Trap: squashing between two described changes.** If both changes have descriptions,
> `jj squash` opens the editor so you can combine the two messages. In an agent without a
> terminal that either fails (`Failed to edit description`) or, with Module 0's agent mode,
> silently concatenates them: the feature's message becomes
> `feat: add low_stock report\n\nfixup`. Agents should use one of:
>
> - `jj squash -u` (keep the **destination's** description, discard the source's), or
> - `jj squash -m "<final message>"`.

`jj squash` is more general than "into the parent". The forms you will use:

| Command | Effect |
|---|---|
| `jj squash` | `@` into `@-` |
| `jj squash -u` | same, keep `@-`'s description |
| `jj squash --into <rev>` | `@` into any earlier change `<rev>`; descendants are rebased |
| `jj squash --from <a> --into <b> <paths>` | move only `<paths>` from `a` to `b` |

### Practice 2.1

Your stack is: trunk ← docs ← feat ← empty `@`. Without running anything, answer:

1. You notice a typo in `README.md` while standing on `@`. Which single command, after fixing the
   typo, puts the fix into the **docs** change (not the feat change)?
2. What happens to the feat change's commit ID when you do that? Its change ID?

<details><summary>Feedback</summary>

1. `jj squash --into xxpzvoor` (use your docs change's ID), or
   `jj squash --into 'description(substring:"docs: document")'`. The fix change has no
   description, so no prompt. Adding `-u` is harmless and a good agent habit.
2. The feat change is a descendant of docs, so it is rebased: new commit ID, same change ID.

</details>

## 2.4 Bookmarks and pushing *(builds M2.4)*

A **bookmark** is a named pointer to a change, and it is what becomes a Git branch on the
remote. Unlike a Git branch, a bookmark **does not move when you create new changes**. You
move it explicitly. This is deliberate: in a multi-agent repository you want to decide which
work a branch points at, not have it follow whatever an agent did last.

Create a bookmark on the feature (the change below the empty `@`) and push it:

```bash
jj bookmark create low-stock -r @-
jj git push --bookmark low-stock --dry-run
jj git push --bookmark low-stock
```

```text
# output
Created 1 bookmarks pointing to opqtulku a4b36ba1 low-stock | feat: add low_stock report
Changes to push to origin:
  bookmark: low-stock [add to a4b36ba181ec]
Dry-run requested, not pushing.
Changes to push to origin:
  bookmark: low-stock [add to a4b36ba181ec]
```

`jj git push --bookmark <name>` pushes the bookmark and the changes it needs. A bookmark pushed
this way becomes **tracked**: jj remembers its remote counterpart `low-stock@origin` and will
update it on later fetches and pushes. (In jj 0.42 and later there is no `--allow-new` flag;
older tutorials that use it are out of date.)

jj refuses to push a change that has no description or has an unresolved conflict. Treat those
refusals as a checklist, not an obstacle.

Other push forms you will meet: `jj git push -c @-` creates a bookmark with a generated name
for the change and pushes it (handy for quick pull requests); `jj git push --tracked` pushes
every tracked bookmark that moved.

To move a bookmark later, point it at another change:

```bash
jj bookmark set low-stock -r <change>      # create the bookmark, or move it if it exists
jj bookmark move low-stock --to <change>   # move an existing bookmark only
jj bookmark advance low-stock --to @-      # move it forward to a descendant, here @-
```

Without `--to`, `jj bookmark advance` moves the bookmark to `@`, which right after `jj new` or
`jj commit` is an empty change with no description (and jj refuses to push such a change), so give
it `--to`. `set` and `move` refuse to move a bookmark backwards or sideways (to a change that is not a
descendant of where it is) unless you add `--allow-backwards`; that protects published branches
from accidental rewinds.

A bookmark also follows its change when the change is rewritten (described, squashed into,
rebased), because it points at the change, not at one commit. You will see that in 2.5.

`jj bookmark list --all` shows local bookmarks and where each remote has them:

```text
# output
low-stock: opqtulku a4b36ba1 feat: add low_stock report
  @git: opqtulku a4b36ba1 feat: add low_stock report
  @origin: opqtulku a4b36ba1 feat: add low_stock report
main: oospxynm 75ce0285 initial inventory module
  @git: oospxynm 75ce0285 initial inventory module
  @origin: oospxynm 75ce0285 initial inventory module
```

(`@git` is the colocated Git repository's copy of the branch; you can ignore it.)

## 2.5 When main moves: fetch and rebase *(builds M2.3, M2.4)*

Simulate a teammate pushing to `main`, then fetch:

```bash
lab.sh teammate
jj git fetch
jj log
```

```text
# output (after the script's own line, "A teammate pushed …")
bookmark: main@origin [updated] tracked
@  wsyvmrwn you@example.com 2026-09-26 09:01:02 53c2393c
│  (empty) (no description set)
○  opqtulku you@example.com 2026-09-26 09:01:02 low-stock a4b36ba1
│  feat: add low_stock report
○  xxpzvoor you@example.com 2026-09-26 09:01:02 8d810fb2
│  docs: document low_stock report
│ ◆  xtkvsykn teammate@example.com 2026-09-26 09:01:08 main 6abf352c
├─╯  docs: add CONTRIBUTING.md
◆  oospxynm seed@example.com 2026-09-26 09:01:02 75ce0285
│  initial inventory module
~
```

Your stack now branches off an old main. Move it with `jj rebase`, which always takes one
**source** flag and one **destination** flag:

| Source flag | Moves |
|---|---|
| `-r <rev>` | only `<rev>`; its descendants stay behind, reattached to its parent |
| `-s <rev>` | `<rev>` and all its descendants |
| `-b <rev>` | the whole *branch* containing `<rev>`: every change not already on the destination (the usual choice for "move my work onto new main") |

| Destination flag | Puts the moved changes |
|---|---|
| `-o <rev>` (`--onto`) | on top of `<rev>` |
| `-A <rev>` (`--insert-after`) | between `<rev>` and its children |
| `-B <rev>` (`--insert-before`) | between `<rev>` and its parents |

(`-d`/`--destination` is the pre-0.36 spelling of `-o`. It is still accepted as an alias, but
newer documentation and this course use `-o`.)

```bash
jj rebase -b low-stock -o 'trunk()'
```

```text
# output
Rebased 3 commits to destination.
Working copy  (@) now at: wsyvmrwn 42de07df (empty) (no description set)
Parent commit (@-)      : opqtulku 6433a407 low-stock* | feat: add low_stock report
Added 1 files, modified 0 files, removed 0 files
```

The bookmark moved with its change (a bookmark points at a *change*, so a rebase carries it
along), and it is now marked `low-stock*`: the local bookmark differs from what the remote has.
Push again:

```bash
jj git push --bookmark low-stock
```

```text
# output
Changes to push to origin:
  bookmark: low-stock [move sideways from a4b36ba181ec to 6433a40777c8]
```

"Move sideways" is jj's term for a force-push: the new commit is not a descendant of the old one.
jj only does this if the remote bookmark is still where jj last saw it, the equivalent of
Git's `--force-with-lease`, so you cannot overwrite a teammate's push you have not fetched.

If the rebase had produced a conflict, it would still have succeeded, marking the affected
changes `(conflict)`, and the push would have been refused until you resolved them. Module 3
covers resolution.

### Practice 2.5

For each goal, write the `jj rebase` command:

1. Move only the docs change so it sits directly on `trunk()`, leaving the feat change where it is.
2. Move the docs change and everything above it onto `trunk()`.
3. Move an existing change `X` (say, one you made elsewhere) so it sits between the docs change and
   the feat change.

<details><summary>Feedback</summary>

1. `jj rebase -r <docs> -o 'trunk()'`. The feat change is reattached to docs' old parent.
2. `jj rebase -s <docs> -o 'trunk()'` (here `-b @` would do the same).
3. `jj rebase -r X -A <docs>` (or `-B <feat>`).

</details>

## 2.6 Output for machines *(builds M2.5)*

Agents and scripts should not parse the human-oriented log. jj has no `--json` flag;
instead every listing command takes `-T <template>`, a small expression language for output.
The function `json(...)` (jj 0.31+) serializes a value:

```bash
jj log --no-graph -r 'trunk()..@-' -T 'json(self) ++ "\n"'
```

```text
# output (one object per line; shortened here)
{"commit_id":"6433a407…","parents":["d9671e33…"],"change_id":"opqtulkuzmslwysmkwxzuylvsonlwmwv","description":"feat: add low_stock report\n","author":{"name":"…","email":"…","timestamp":"2026-09-26T09:01:02-05:00"},"committer":{…}}
{"commit_id":"d9671e33…","parents":["6abf352c…"],"change_id":"xxpzvoorkpsrxxvovuzytmnlwotlovxy","description":"docs: document low_stock report\n",…}
```

Or pick fields yourself: `++` concatenates, and keywords like `change_id`, `description`,
`bookmarks`, `empty`, and `conflict` are available:

```bash
jj log --no-graph -r 'trunk()..@-' \
  -T 'change_id.short(8) ++ "\t" ++ description.first_line() ++ "\t" ++ bookmarks ++ "\n"'
```

```text
# output
opqtulku	feat: add low_stock report	low-stock
xxpzvoor	docs: document low_stock report
```

`jj op log`, `jj workspace list`, `jj bookmark list`, and `jj diff` accept `-T` too. The MCP
server in Module 6 is built entirely on these templates.

---

## Knowledge check

1. *(M2.1)* An agent in agent mode (Module 0) runs `jj squash` to fold a change described
   "fix: typo" into its parent described "feat: add report". What is the result?
   - a) The parent keeps "feat: add report".
   - b) The parent's description becomes "feat: add report" followed by a blank line and "fix: typo".
   - c) jj refuses because both changes have descriptions.
   - d) The parent's description becomes "fix: typo".

2. *(M2.2)* You run `jj split -m "docs: readme" README.md` on a change described "feat: parser"
   containing `README.md` and `parser.py`. What do you get?
   - a) A first change "docs: readme" with README.md, and a second change on top, "feat: parser",
     with parser.py.
   - b) A first change "feat: parser" with parser.py, and a second "docs: readme" with README.md
     on top.
   - c) An interactive diff editor, because split is always interactive.
   - d) Two sibling changes, both on the original parent.

3. *(M2.3)* Main has moved. Your stack is three changes, the top one bookmarked `feature`. Which
   command moves all three onto the new main?
   - a) `jj rebase -r feature -o 'trunk()'`
   - b) `jj rebase -b feature -o 'trunk()'`
   - c) `jj rebase -o feature -b 'trunk()'`
   - d) `jj git pull`

4. *(M2.4)* You create bookmark `fix` on `@-`, then run `jj new` and do more work in a new change.
   Where is `fix`?
   - a) On the new change, because bookmarks follow your work like Git branches.
   - b) Still on the original change; bookmarks move only when you move them (or when their
     change is rewritten).
   - c) Deleted, because its change is no longer `@`.
   - d) On `@`, which is empty.

5. *(M2.4)* `jj git push --bookmark low-stock` prints `move sideways`. What does that tell you?
   - a) The push failed.
   - b) The push replaced the remote branch with a commit that is not its descendant (a
     force-push), which jj allowed because the remote was where jj last saw it.
   - c) jj pushed to a different remote than `origin`.
   - d) The bookmark was renamed.

6. *(M2.5)* A script needs the change ID and first description line of every change in your
   stack. Which is the most robust approach?
   - a) Parse `jj log` output with a regular expression.
   - b) `jj log --no-graph -r 'trunk()..@' -T 'change_id ++ "\t" ++ description.first_line() ++ "\n"'`
   - c) `jj log --json`
   - d) `git log --format='%H %s'`, since the repository is colocated.

### Answer key

1. **b.** With the editor set to `true`, jj accepts the pre-filled combined text. (a) is what
   `jj squash -u` does; (c) jj never refuses; (d) is not a behavior. Reread the trap box in 2.3.
2. **a.** The listed paths go in the *first* change with the new description; the rest stays on
   top with the original description. (b) reverses the order; (c) paths make it non-interactive;
   (d) is `jj split --parallel`. Reread 2.2.
3. **b.** `-b` selects the whole branch relative to the destination. (a) moves only the top change;
   (c) swaps the roles; (d) is not a jj command (fetch, then rebase). Reread 2.5.
4. **b.** Bookmarks don't advance on `jj new`. (a) is Git's model; (c) and (d) are not behaviors.
   Reread 2.4. (`jj bookmark set fix -r <rev>` or `jj bookmark advance fix --to <rev>` moves it.)
5. **b.** Sideways = non-fast-forward, guarded like `--force-with-lease`. (a) a failure is an
   error message; (c) and (d) are unrelated. Reread 2.5.
6. **b.** Templates are jj's stable machine interface. (a) breaks when the format changes; (c)
   does not exist; (d) misses the change ID and the working-copy change. Reread 2.6.

## Performance task

Reset the lab and complete the whole flow:

```bash
lab.sh reset
cd ~/jj-lab/app
```

1. Starting from `trunk()`, implement `low_stock(threshold)` with its test and a README note, as
   in 2.1. *(M2.1)*
2. Split it into a change `docs: document low_stock report` (README.md only) with
   `feat: add low_stock report` (inventory.py and test_inventory.py) on top. *(M2.2)*
3. Fold a docstring improvement into the feat change so that `inventory.py` contains exactly
   `"""Return the sorted names of items whose count is below threshold."""`, leaving no extra
   change behind. *(M2.1)*
4. Bookmark the feat change as `low-stock` and push it. *(M2.4)*
5. Run `lab.sh teammate`, fetch, rebase your work onto the new main, and push again. *(M2.3, M2.4)*
6. Confirm the tests pass on the pushed branch. *(M2.T)*

```bash
check.sh m2
```

The check reads the *remote* (`~/jj-lab/origin.git`), exactly as a reviewer or CI system would.

## Gate

Move on to Module 3 when `check.sh m2` passes and you scored at least 5 of 6 on the
knowledge check. If "stack is docs change, then feat change on top" fails, reread 2.2 and check
which change received `-m`. If "exactly two commits beyond main" fails, your fix is still a
separate change: `jj squash --from <fix> --into <feat> -u`, then push again. If question 1 was
wrong, reread the trap box in 2.3; this one causes real damage to agents' commit messages.
