# Module 1 — How jj thinks

## Why this matters

Most jj mistakes made by experienced Git users, and by agents trained mostly on Git, come from
carrying Git's model across: looking for a staging area, expecting branches to move by
themselves, treating a commit hash as a permanent name. jj's model is smaller than Git's, and
once you hold it, every later module (parallel agents, recovery) follows from it. This module
builds that model with commands you run and outputs you read.

## Objectives

After this module you will be able to:

- **M1.T** — Starting from a freshly reset lab, build a specified stack of two described changes
  with an empty working-copy change on top, using only jj commands, such that
  `check.sh m1` passes.
- **M1.1** — Explain how jj's working-copy change replaces Git's staging area, and predict what
  `jj status` reports after you edit files.
- **M1.2** — Distinguish a change ID from a commit ID, and predict which one stays the same when
  a change is rewritten.
- **M1.3** — Read `jj log` output: the working-copy marker, immutable changes, bookmarks, remote
  bookmarks, elided history, and conflict markers.
- **M1.4** — Write revsets (jj's query language for selecting changes) for a single change, its
  parents, a range, ancestors, and changes matching a description or a file.
- **M1.5** — Explain what Git sees in a colocated repository, and why a Git write command there
  changes jj's state.

## Prerequisites

Module 0 complete: `check.sh setup` passes and `lab.sh reset` has built your lab.

---

## 1.1 The working copy is a commit *(builds M1.1)*

Go to your lab and look around:

```bash
cd ~/jj-lab/app
ls -a
jj log
```

```text
# output
.  ..  .git  .gitignore  .jj  README.md  inventory.py  test_inventory.py

@  uxpsxunq you@example.com 2026-09-26 08:59:12 d803cb99
│  (empty) (no description set)
◆  nqsrswpt seed@example.com 2026-09-26 08:59:12 main 54bfd0f5
│  initial inventory module
~
```

Two things are already different from Git.

First, there are two metadata folders. `.jj/` is jj's; `.git/` is an ordinary Git repository.
This is a **colocated** repository: jj and Git share one working directory, and jj keeps the
Git repository up to date so Git tools keep working. Since jj 0.34, `jj git clone` and
`jj git init` create colocated repositories by default. Section 1.5 covers what that means.

Second, the top line, marked `@`, is a commit you never made. In jj, **the files in your
working directory always belong to a commit**, called the *working-copy commit* and written
`@`. It starts empty. Watch what happens when you edit a file:

```bash
printf '\nThis repository is the course lab.\n' >> README.md
jj status
```

```text
# output
Working copy changes:
M README.md
Working copy  (@) : uxpsxunq 726cb732 (no description set)
Parent commit (@-): nqsrswpt 54bfd0f5 main | initial inventory module
```

You did not run anything like `git add`. At the start of (almost) every command, jj takes a
**snapshot**: it records the current state of every file in the working directory into `@`.
The edit to `README.md` is already part of `@`. There is no staging area and no "untracked
but present" limbo for normal files: a new file is recorded as soon as any jj command runs
(files matched by `.gitignore` are the exception).

That single fact explains two behaviors you will rely on:

- **Nothing you do is lost.** Every snapshot is recorded, so even edits you never "committed"
  can be recovered (Module 4).
- **Whoever runs jj next decides what gets recorded.** If two agents edit files in the same
  directory, the next jj command either of them runs snapshots *both* agents' edits into the
  same `@`. Module 3 shows this happening and fixes it with workspaces.

### Naming and finishing a change

A commit in jj is usually called a **change**, for a reason section 1.2 explains. Give the
current change a description (jj's word for a commit message):

```bash
jj describe -m "docs: explain the lab"
```

Then start a new, empty change on top of it:

```bash
jj new
jj log
```

```text
# output
@  qzoytxkp you@example.com 2026-09-26 08:59:12 a29a9506
│  (empty) (no description set)
○  uxpsxunq you@example.com 2026-09-26 08:59:12 28a91391
│  docs: explain the lab
◆  nqsrswpt seed@example.com 2026-09-26 08:59:12 main 54bfd0f5
│  initial inventory module
~
```

`jj describe -m` then `jj new` is so common that it has a shortcut: `jj commit -m "<message>"`
does both. Note that `jj commit -m` sets the description of the **current** change `@`, whatever
it already says; it does not create a separate commit for "what changed since last time".

> **Trap to avoid.** In Git, `git commit -m "wip"` after some edits creates a *new* commit
> containing the edits. In jj, `jj commit -m "wip"` *renames* the change you are standing in.
> If `@` was your carefully described feature, it is now called "wip". The fix is
> `jj describe -m "<the old message>" -r @-`, and the prevention is to run `jj new` before
> starting unrelated work.

### Practice 1.1

In your lab, starting from the state above (an empty `@` on top of "docs: explain the lab"):

1. Create a file `NOTES.md` containing one line of text.
2. Before running any command, predict: which change contains `NOTES.md` right now?
3. Run `jj status`. Were you right?
4. Finish the change with the description `chore: add notes`, leaving an empty change on top.

<details><summary>Feedback</summary>

2. Trick question: right now, *no* change contains it. The file exists on disk, but no jj
   command has run since you created it, so no snapshot has recorded it.
3. `jj status` snapshots first, so it reports `A NOTES.md` in the working-copy change `@`.
4. `jj commit -m "chore: add notes"` (or `jj describe -m "chore: add notes"` then `jj new`).
   `jj log` should show `@` empty on top, then "chore: add notes", then "docs: explain the lab".

</details>

## 1.2 Change IDs and commit IDs *(builds M1.2)*

Look back at the outputs above. The change you described kept the name `uxpsxunq` across
three states, while the hexadecimal number next to it changed each time:

| Moment | Change ID | Commit ID |
|---|---|---|
| Fresh, empty | `uxpsxunq` | `d803cb99` |
| After editing README.md | `uxpsxunq` | `726cb732` |
| After `jj describe` | `uxpsxunq` | `28a91391` |

jj gives every change two identifiers:

- The **commit ID** (hexadecimal, like Git's hash) identifies one exact snapshot: these files,
  this description, these parents. Change anything and you get a new commit with a new ID. In a
  colocated repository this is the same hash Git shows.
- The **change ID** (letters `k` to `z`, so it can never be mistaken for hex) identifies the
  *change* across all its rewrites. When jj rewrites a commit (a new snapshot, a new description,
  a new parent), the new commit keeps the old change ID.

That is why jj talks about *changes*: the unit you work with is the evolving change, not any one
of its snapshots. Use change IDs when you tell jj (or an agent) which change to act on; they
stay valid while you work. jj prints the shortest unique prefix in bold (in a color terminal),
and you may type any unique prefix: `jj describe -r uxp -m ...` works.

### Rewrites carry descendants along

Rename the older change while standing on top of it (use *your* change ID for "docs: explain the
lab", from your `jj log`; IDs differ on every machine):

```bash
jj describe -r uxpsxunq -m "docs: explain the lab setup"
```

```text
# output
Rebased 2 descendant commits.
Working copy  (@) now at: nourxuqk 58643b25 (empty) (no description set)
Parent commit (@-)      : qzoytxkp 6d872499 chore: add notes
```

Rewriting a change produces a new commit, so every change on top of it now has a new parent,
and jj **rebases the descendants automatically**. No "interactive rebase" session, no
`--continue`. Their change IDs stay the same; their commit IDs change.

Put the original description back before moving on:

```bash
jj describe -r uxpsxunq -m "docs: explain the lab"
```

## 1.3 Reading `jj log` *(builds M1.3)*

The graph symbols carry meaning:

| Symbol | Meaning |
|---|---|
| `@` | The working-copy change of *this* workspace (the directory you are in) |
| `○` | An ordinary, mutable change |
| `◆` | An **immutable** change: `trunk()` (the remote's main branch; see 1.4), a tag, or a remote branch you have not started tracking (Module 2 explains tracking), together with their ancestors. jj refuses to rewrite it unless you pass `--ignore-immutable`. |
| `×` | A change with an unresolved **conflict** (the line also says `(conflict)`) |
| `~` | History continues beyond what is shown (elided) |

Labels on a line:

| Label | Meaning |
|---|---|
| `main` | A **bookmark**: jj's name for a Git branch. A named pointer to one change. |
| `main@origin` | Where that bookmark is on the remote named `origin`, as of your last fetch. Shown only when it differs from the local `main`. |
| `main*` | The local bookmark has moved since you last pushed it. |
| `(empty)` | The change has no file changes relative to its parent. |
| `(no description set)` | Nobody has described it yet. |
| `default@`, `agent-a@` | The working-copy change of a named workspace (Module 3). |
| `(divergent)` | Two versions of the same change exist (Module 4). |

By default `jj log` shows your mutable work, its immediate context, and `trunk()`, not the
whole history. `jj log -r 'all()'` shows everything.

## 1.4 Revsets: selecting changes *(builds M1.4)*

Almost every jj command takes `-r <revset>`. A **revset** is an expression that selects a set of
changes. You have already used the simplest ones, `@` and a change ID. The ones you will use
most:

| Revset | Selects |
|---|---|
| `@` | The working-copy change |
| `@-` | Its parent(s). `@--` is the grandparent. |
| `x-` | Parents of any revset `x` (for example `trunk()-`, or `description(substring:"docs")-`) |
| `x+` | Children of `x` |
| `trunk()` | The main branch of your remote (here `main@origin`) |
| `x..y` | Changes that are ancestors of `y` (including `y`) but not of `x`. `trunk()..@` = "my stack". |
| `::x` | `x` and all its ancestors |
| `x::` | `x` and all its descendants |
| `description(substring:"text")` | Changes whose description contains `text` |
| `files("path")` | Changes that modify `path` |
| `root()` | The virtual root change, ID `zzzzzzzz`, parent of everything |
| `x \| y`, `x & y`, `~x` | Union, intersection, complement |

Try a few in your lab. The `-T` option picks an output *template* (you will write your own in
Module 2); `--no-graph` removes the graph lines.

```bash
jj log -r 'trunk()..@'
jj log -r 'files("NOTES.md")'
jj log -r '@--'
```

Quote revsets in the shell: characters like `(`, `|`, `&`, and `~` mean something to Bash.

### Practice 1.4

Using your lab after Practice 1.1 (stack: trunk ← "docs: explain the lab" ← "chore: add notes"
← empty `@`), write the revset for each, predict the result, then run
`jj log --no-graph -r '<revset>' -T 'description.first_line() ++ "\n"'` to check:

1. The change that added `NOTES.md`, without using its ID or description.
2. Both of your described changes and nothing else.
3. The parent of "docs: explain the lab".

<details><summary>Feedback</summary>

1. `files("NOTES.md")` or `@-`.
2. `trunk()..@-`, or `trunk()..@ ~ @`, or `trunk()..@ ~ empty()`. The last one reads "my stack
   without empty changes", which stays correct even if `@` is not empty.
3. `@---`, or `trunk()`, or `description(substring:"docs: explain")-`: all select
   "initial inventory module".

</details>

## 1.5 What Git sees in a colocated repository *(builds M1.5)*

Ask Git about the same directory:

```bash
git status
git log --oneline -3
```

```text
# output (with the stack from Practice 1.1: two described changes and an empty @)
Not currently on any branch.
nothing to commit, working tree clean
39e2953 chore: add notes
c1f379f docs: explain the lab
54bfd0f initial inventory module
```

Three details:

- Git is on a **detached HEAD** pointing at `@-`, the parent of the working-copy change. jj
  keeps Git's HEAD there on purpose, and exports every change it makes to Git automatically.
- `git status` compares the files on disk with `@-`, so edits in `@` show up in Git as
  *unstaged changes* (new files are marked `A`, "intent to add"). The tree above is clean only
  because `@` is empty. This is why IDE diff views and Git-aware tools keep working in a
  colocated repository: to them, `@` looks like uncommitted work on top of `HEAD`. The index is
  managed by jj, though: never `git add` to it.
- Git **write** commands also work, and that is the hazard. jj imports whatever Git did at the
  start of its next command. For example, `git commit` in a colocated repository makes jj print
  `Reset the working copy parent to the new Git HEAD.` and move `@` onto Git's new commit. For a
  person at a terminal that is mostly harmless. For several agents it means a Git write by one
  agent can move the working copy under another, which is why Module 5 blocks Git write commands
  for agents.

Git's staging area, an in-progress `git rebase`, and Git's conflict state are simply ignored by
jj.

---

## Knowledge check

1. *(M1.1)* You edit `inventory.py` and immediately ask a colleague to run `jj log` in the same
   directory. What does their `jj log` show?
   - a) Your edit is not recorded, because you haven't run `jj commit`.
   - b) Your edit is recorded in `@`, because their `jj log` snapshotted the working directory.
   - c) Your edit is recorded in a new change created for them.
   - d) Their `jj log` fails because the working directory has uncommitted changes.

2. *(M1.2)* An agent reports "I finished commit `28a91391`." You then run
   `jj describe -r @- -m "better message"` on that change. Which reference should you use next
   time you need that change?
   - a) `28a91391`, because commit IDs are permanent.
   - b) The change ID shown next to it, because it survives the rewrite; `28a91391` now names the
     old version.
   - c) Either; jj updates commit IDs in place.
   - d) Neither; after a rewrite the change must be looked up by description.

3. *(M1.1, M1.2)* `@` is described "feat: add low_stock report" and contains your finished feature.
   You make an unrelated typo fix in README.md and run `jj commit -m "fix typo"`. What happened?
   - a) A new change "fix typo" containing only README.md was created on top of the feature.
   - b) The feature change was renamed "fix typo" and now also contains the README edit.
   - c) jj refused because `@` already had a description.
   - d) jj opened an editor asking which files belong to which change.

4. *(M1.3)* A line in `jj log` reads `◆  kpyroxtt teammate 2026-09-26 main@origin d5db4ad5`. Which
   statement is true?
   - a) You can run `jj describe -r kpyroxtt -m ...` freely; `◆` just marks a merge.
   - b) The change is immutable, and your local `main` bookmark is not on it.
   - c) The change has a conflict.
   - d) The change is your working-copy change in another workspace.

5. *(M1.4)* Which revset selects exactly the changes you have stacked on top of the main branch,
   including `@`?
   - a) `::@`
   - b) `@..trunk()`
   - c) `trunk()..@`
   - d) `trunk()::`

6. *(M1.5)* An agent in a colocated repository runs `git commit -am "wip"` while `@` contains
   your uncommitted edits in the same directory. What is the most accurate description?
   - a) Nothing happens to jj; jj ignores Git entirely.
   - b) Git creates a commit from the files on disk (your edits included); jj imports it at its
     next command and moves `@` on top of it.
   - c) Git refuses because HEAD is detached.
   - d) jj blocks the Git command because the repository is colocated.

### Answer key

1. **b.** Any jj command snapshots first. (a) is the Git mental model with a staging area;
   (c) snapshots go into the existing `@`; (d) jj has no "dirty tree" refusal. Reread 1.1.
2. **b.** Commit IDs name one exact version; the change ID follows the change. (a) and (c) are the
   Git model; (d) descriptions aren't unique identifiers. Reread 1.2.
3. **b.** `jj commit -m` describes the *current* change and then starts a new one. The README edit
   was already snapshotted into `@`. (a) is Git's behavior; (c) jj never refuses to re-describe;
   (d) only happens with `-i`. Reread the trap box in 1.1. Recover with
   `jj describe -r @- -m "feat: add low_stock report"`, then move the README edit out with
   `jj split` (Module 2).
4. **b.** `◆` marks an immutable change (here, because it is the remote's `main`), and
   `main@origin` appears only when the local `main` differs. (a) jj will refuse the rewrite;
   (c) conflicts are `×`; (d) workspace changes are labeled `name@`. Reread 1.3.
5. **c.** `x..y` = ancestors of `y` that are not ancestors of `x`. (a) includes all history;
   (b) is backwards (usually empty); (d) is trunk and everything after it, including other
   people's branches. Reread 1.4.
6. **b.** Git commits whatever is on disk; jj imports it on its next command. (a) jj imports
   Git's changes in colocated repositories; (c) Git commits on a detached HEAD without complaint;
   (d) jj cannot intercept Git; Module 5 adds that guard. Reread 1.5.

## Performance task

Reset the lab, then build this stack using only jj commands (plus your editor or shell to
change files):

```bash
lab.sh reset
cd ~/jj-lab/app
```

1. A change described exactly `docs: explain the lab` that modifies `README.md` (any text). *(M1.1)*
2. On top of it, a change described exactly `chore: add notes` that adds a new file `NOTES.md`
   and touches no other file. *(M1.2, M1.4)*
3. On top of that, an empty working-copy change `@`. *(M1.1)*
4. Both described changes are the only non-empty changes between `trunk()` and `@`. *(M1.3)*

Check your work:

```bash
check.sh m1
```

<details><summary>Solution sketch (open only after trying)</summary>

Edit README.md → `jj describe -m "docs: explain the lab"` → `jj new` → create NOTES.md →
`jj commit -m "chore: add notes"`. If `NOTES.md` ended up in the docs change, you created it
before running `jj new`; move it with `jj squash --from @- --into @ NOTES.md` (Module 2
explains `squash`) or reset and retry.

</details>

## Gate

Move on to Module 2 when `check.sh m1` passes and you scored at least 5 of 6 on the
knowledge check. If you missed question 3, redo Practice 1.1 and reread the trap box: this is
the single most common jj mistake, for people and agents alike. If you missed question 5,
redo Practice 1.4.
