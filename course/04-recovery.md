# Module 4 — Recovery

## Why this matters

Agents make mistakes faster than people do, and with several running at once some of those
mistakes collide. The measure of a multi-agent setup is not whether things go wrong but how
cheaply you put them right, without throwing away the work of the agents that did nothing wrong.
jj records enough history to repair almost anything; this module teaches you to read that history
and pick the *narrowest* repair.

## Objectives

After this module you will be able to:

- **M4.T** — For each of five damaged multi-agent states (stale workspace, mistaken undo, divergent
  change, destructive agent edit, snapshotted secret), diagnose the cause from jj's logs and repair
  it with the least-destructive command, such that `check.sh m4-<scenario>` passes for all five.
- **M4.1** — Read `jj op log`, `jj op show`, and `jj evolog` to attribute a change in the repository
  to a specific operation, workspace, and command.
- **M4.2** — Explain why `jj undo` is repository-wide, and repair a mistaken undo with `jj redo`
  and `jj op revert`.
- **M4.3** — Resolve a divergent change by keeping one version and abandoning the other together
  with its descendants.
- **M4.4** — Restore content an agent destroyed into the change that lost it, with
  `jj restore --from --into`.
- **M4.5** — Contain a credential that jj snapshotted: rotate, ignore, untrack, verify, and explain
  what remains in local history.

## Prerequisites

Module 3: workspaces and `name@` (M3.2), staleness (M3.3). Module 1: change IDs versus commit
IDs (M1.2).

---

## 4.1 Three histories *(builds M4.1)*

jj keeps three kinds of history. Knowing which one answers your question is most of recovery.

| History | Answers | Command |
|---|---|---|
| **Change graph** | What does the code look like, and how are changes related? | `jj log` |
| **Evolution log** of one change | What were all the versions of *this* change? | `jj evolog -r <change>` |
| **Operation log** of the repository | What did each jj command do, in which workspace, in what order? | `jj op log`, `jj op show <op>` |

The **operation log** is the one Git has no equivalent for. Every jj command that changes
anything (including the automatic snapshot at the start of a command) records an *operation*: the
complete state of the repository afterwards (every visible change, bookmark, and each workspace's
`@`), plus who ran it, where, and with what arguments. One operation log is shared by all
workspaces. Here is one after two workspaces have been busy:

```text
# output of: jj op log -n 5   (long operation hashes shortened with …)
@  8d8a0b2f7af7 you@laptop default@ now, lasted 1 millisecond
│  undo: restore to operation f7edc73bde42…
│  args: jj undo
○  d32a1b5ac1a1 you@laptop count@ now, lasted 2 milliseconds
│  commit 4697487cb311a507f43c9f8255a8b5f16d44b8d7
│  args: jj commit -m 'feat: add item_count()'
○  f7edc73bde42 you@laptop count@ now, lasted 4 milliseconds
│  snapshot working copy
│  args: jj commit -m 'feat: add item_count()'
○  c5b750886983 you@laptop default@ now, lasted 4 milliseconds
│  commit 5e00e0bb78106eb594edb1a8a03a02a86c1eaeac
│  args: jj commit -m 'human: add meeting notes'
○  903d1ec08e43 you@laptop default@ now, lasted 3 milliseconds
│  snapshot working copy
│  args: jj commit -m 'human: add meeting notes'
```

Read each entry as: *operation ID*, *user@host*, **workspace** (`default@`, `count@`), time;
then what it did; then the exact command. `jj op show <op-id>` prints what one operation changed:

```text
# output of: jj op show c5b750886983
c5b750886983 you@laptop default@ now, lasted 4 milliseconds
commit 5e00e0bb78106eb594edb1a8a03a02a86c1eaeac
args: jj commit -m 'human: add meeting notes'

Changed commits:
○  + xnlmzuvs 30e7cb81 (empty) (no description set)
○  + xvmyusny 2f1f7c18 human: add meeting notes
   - xvmyusny/1 39a5aee3 (hidden) (no description set)

Changed working copy default@:
+ xnlmzuvs 30e7cb81 (empty) (no description set)
- xvmyusny/1 39a5aee3 (hidden) (no description set)
```

`+` lines are what the operation created, `-` lines what it replaced. `(hidden)` marks a version
that is no longer visible in `jj log` but still exists; `xvmyusny/1` means "the previous version
of change `xvmyusny`". Nothing an operation replaces is deleted.

The **evolution log** shows every version of one change, each with the operation that produced it:

```text
# output of: jj evolog -r ozrwwtsl --summary
○  ozrwwtsl … 9faab4a6
│  feat: add item_count(); clean up tests
│  -- operation 8902c81fc77b commit c15fea94…
○  ozrwwtsl/1 … c15fea94 (hidden)
│  (no description set)
│  -- operation 93e79a0a1295 snapshot working copy
│  M inventory.py
│  D test_inventory.py
○  ozrwwtsl/2 … d0cbf626 (hidden)
   (empty) (no description set)
   -- operation 8d58c4dd1672 create initial working-copy commit in workspace count
```

Here you can see the snapshot in which `test_inventory.py` was deleted, before the change even
had a description.

The discipline for every repair: **read** (op log, evolog, log), **act** with the narrowest
command, **read again** to confirm.

### Practice 4.1

In a freshly reset lab (`lab.sh reset`, then `cd ~/jj-lab/app`):

1. Edit `README.md`, then run `jj describe -m "docs: practice"`.
2. Run `jj op log -n 3`. Predict before looking: how many operations did your two steps create, and
   what are their descriptions?
3. Run `jj op show <id>` on the `describe` operation. Which change IDs appear, and which version is
   marked `(hidden)`?
4. Run `jj evolog -r @ --summary`. Match each version to an operation from step 2.

<details><summary>Feedback</summary>

2. Two: `snapshot working copy` (the `jj describe` command first recorded your README edit) and
   `describe commit …`. Editing a file creates no operation by itself; the next jj command does.
3. The same change ID appears twice: the new version (`+`) and the replaced version (`-`, marked
   `(hidden)`, written `<id>/1`).
4. The newest version comes from the describe operation, the one before from the snapshot, and the
   oldest (empty) from `lab.sh reset`'s clone.

</details>

## 4.2 Stale workspace *(builds M4.T; reviews M3.3)*

```bash
scenario.sh stale
cd ~/jj-lab/app-ws/count
jj status
```

You met this in Module 3: another workspace (here, you in `default`, rebasing the agent's work
onto a new main) rewrote this workspace's `@`. `jj workspace update-stale` repairs it. Check:
`check.sh m4-stale`.

## 4.3 An undo that hit the wrong operation *(builds M4.2)*

```bash
scenario.sh undo
cd ~/jj-lab/app
jj log -r 'all() ~ ::trunk()'
```

```text
# output
@  xrxryqpn … default@ (empty) (no description set)
○  pqpkkqpy …          human: add meeting notes
~
○  txlpyxmk … count@   (no description set)
~
```

The story: you committed meeting notes, then changed your mind and ran `jj undo`. But between
your commit and your undo, the count agent committed its feature. **`jj undo` reverts the latest
operation in the repository, whichever workspace ran it.** Your notes commit is still there; the
agent's commit was undone (its work is back to an undescribed working-copy change).

The operation log shows exactly this (it is the listing in 4.1). The repair has two steps:

1. **Put back what the undo took**: `jj redo` re-applies the operation the last undo reverted.
2. **Revert the operation you actually meant**: find it in `jj op log`. Two operations were run by
   your `jj commit` (workspace `default@`, args `jj commit -m 'human: add meeting notes'`): a
   `snapshot working copy` operation, then the operation whose description begins with **`commit`**.
   Revert the `commit` one; reverting the snapshot instead would undo the recording of your file,
   not the commit, and leave a divergent change behind.

```bash
jj redo
jj op log -n 8                     # find YOUR commit operation's ID
jj op revert <that-operation-id>
```

```text
# output (last command)
Reverted operation: c5b750886983 … commit 5e00e0bb…
Working copy  (@) now at: xvmyusny 39a5aee3 (no description set)
Parent commit (@-)      : twruuxnw d7f992df main | initial inventory module
```

Your notes are back to an undescribed working-copy change (`NOTES.md` still on disk), and the
agent's "feat: add item_count()" is intact.

`jj op revert <op>` applies the *inverse* of one operation on top of the current state, leaving
later operations alone. That makes it the right tool in a shared repository. Compare the tools:

| Command | Scope | Use when |
|---|---|---|
| `jj op revert <op>` | One named operation | You know which operation to take back |
| `jj undo` / `jj redo` | The latest operation, repository-wide | You are the only one working |
| `jj op restore <op>` | Everything: the whole repository returns to that operation's state | Last resort, with every agent stopped |

Undo also rewinds files on disk: undoing a snapshot operation puts the files back as they were
before that snapshot. Your edits are not lost (they are in the operation log), but they disappear
from the directory. This is why Module 5 makes agents *ask* before any of these commands.

Check: `check.sh m4-undo`.

## 4.4 A divergent change *(builds M4.3)*

```bash
scenario.sh divergent
cd ~/jj-lab/app
jj log -r 'divergent()'
```

```text
# output
○  lqmrsyut/0 … 65bb7e16 (divergent)
│  (empty) (no description set)
○  pommmkyo/0 … 31f52e14 (divergent)
│  feat: validate quantities in add/remove
~
○  lqmrsyut/1 … validate@ 0b89a50c (divergent)
│  (empty) (no description set)
○  pommmkyo/1 … 58b47501 (divergent)
│  feat: reject zero and negative quantities
~
```

**Divergence** means one change ID now has two visible versions. It happens when two jj commands
rewrite the same change starting from the same state, for example two agents re-describing a
shared change at the same moment. Neither command can see the other's work, both succeed, and the
next command merges the two operation-log branches ("reconcile divergent operations" in
`jj op log`). jj cannot know which rewrite you want, so it keeps both and marks them.

The suffixes `/0` and `/1` distinguish the versions (jj 0.37 and later). Descendants were rewritten
too, which is why the agent's empty `@` (`lqmrsyut`) is divergent as well.

The repair uses **`jj abandon <revset>`**, which removes changes from the visible history: each
abandoned change's children are rebased onto its parent, so its *edits* disappear from everything
built on it, and the abandoned commits become hidden (recoverable from the operation log, like any
other rewrite).

Find out who did what:

```bash
jj op log -n 4 --no-graph -T 'id.short(12) ++ "  " ++ self.workspace_name() ++ "  " ++ description.first_line() ++ "\n"'
```

```text
# output
ecfbf86ea827  default@  reconcile divergent operations
4bfb0cb61f84  validate@  describe commit 5a13460c…
ceae2b96e4ff  default@  describe commit 5a13460c…
e00283c3eb38  validate@  commit b2b04625…
```

Both `describe` operations started from the same commit `5a13460c`: that is the signature of
divergence. The repair: decide which version to keep, then abandon the other *and everything built
on it*. The revset `x::` means "x and all its descendants":

```bash
jj diff -r pommmkyo/0 --summary      # compare the versions if the content might differ
jj diff -r pommmkyo/1 --summary
jj abandon 'pommmkyo/0::'            # keep /1 (the one the validate agent's workspace is on)
jj log -r 'divergent()'              # must print nothing
```

Two cautions. First, the offsets are recomputed after every operation, so re-read `jj log` before
typing one. Second, prefer to keep the version that the agent's workspace (`validate@`) sits on;
abandoning the other leaves that workspace undisturbed.

jj 0.45 added `jj converge`, marked experimental, which tries to merge divergent versions
automatically. When the descriptions differ, as here, it needs an interactive session, so it is
not an agent tool yet.

Check: `check.sh m4-divergent`.

## 4.5 A destructive agent edit *(builds M4.4)*

```bash
scenario.sh wipe
cd ~/jj-lab/app-ws/count
jj log -r 'trunk()..@'
jj diff -r @-- --summary
```

```text
# output
@  mzuoykxs … count@ (empty) (no description set)
○  xxpmznmv …        docs: start a changelog
○  ozrwwtsl …        feat: add item_count(); clean up tests
~
M inventory.py
D test_inventory.py
```

The agent did useful work (`item_count()`), deleted the test file "to clean up" in the same
change, then built another change on top. Abandoning the change would throw away `item_count()`.
Instead, put the file back **into the change that deleted it**:

```bash
jj restore --from 'trunk()' --into ozrwwtsl test_inventory.py
```

```text
# output
Rebased 2 descendant commits.
Working copy  (@) now at: mzuoykxs 296421ad (empty) (no description set)
Parent commit (@-)      : xxpmznmv 3bd1803c docs: start a changelog
Added 1 files, modified 0 files, removed 0 files
```

`jj restore` makes the listed paths in `--into` identical to how they are in `--from`. The change
now only modifies `inventory.py`; the changelog change on top was rebased automatically; the file
reappeared on disk. `--from` can be any revision, including a hidden version from `jj evolog`
(use its commit ID). The related form `jj restore --changes-in <rev> <paths>` undoes what one change
did to those paths.

Two notes. The description "clean up tests" is now wrong: fix it with
`jj describe -r ozrwwtsl -m "feat: add item_count()"`. And you ran this *inside the agent's
workspace*, so its files were updated in place. Running the same command from `default` would
have left the count workspace stale.

Check: `check.sh m4-wipe`.

## 4.6 A snapshotted secret *(builds M4.5)*

```bash
scenario.sh secret
cd ~/jj-lab/app-ws/count
jj status
```

```text
# output
Working copy changes:
A .env.local
```

An agent wrote a credential file. The project's `.gitignore` covers `.env` but not `.env.local`,
so the next jj command snapshotted it into `@`. This is the flip side of "nothing is ever lost":
secrets aren't either.

Containment, in order:

1. **Rotate the credential.** Assume it is compromised. The agent's transcript, logs, and any tool
   output that displayed it are exposures you cannot clean up from jj.
2. **Ignore it**, so no future snapshot records it:
   `echo '.env.*' >> .gitignore`
3. **Stop tracking it** (only works once the path is ignored): `jj file untrack .env.local`
4. **Verify** no visible change contains it: `jj log -r 'all()' -- .env.local` prints nothing
   (jj may add a warning that no current file matches; that is expected).

The file stays on disk; jj just stops recording it. What remains is **local history**:

```text
# output of: jj evolog -r @ --summary
@  ynlnzmzu … count@ 6f6d0d8e
│  -- operation 093ad7d36e94 untrack paths
│  D .env.local
○  ynlnzmzu/1 … c5a86507 (hidden)
│  -- operation c18be4598ccd snapshot working copy
│  M .gitignore
○  ynlnzmzu/2 … 1dfa5f7e (hidden)
│  -- operation 9d183512e7af snapshot working copy
│  A .env.local
```

The hidden versions `ynlnzmzu/1` and `/2` still contain the file, in the repository's object store
on this machine. They are **not pushed**: `jj git push` sends only visible changes reachable from
the bookmarks you push. Purging them locally is possible (`jj op abandon` on the old operations,
then `jj util gc --expire=now`), but it discards the undo history of every workspace, and any
workspace whose last recorded operation was abandoned reports `Could not read working copy's
operation` until you run `jj workspace update-stale` in it. Do it only deliberately, with all agents
stopped; rotation is the real fix.

**Prevention** beats containment:

- Put secret patterns (`.env*`, `*.pem`, credential files) in `.gitignore` before agents start.
- `snapshot.max-new-file-size` (default 1 MiB) keeps large new files, such as build output or
  datasets, from being tracked automatically.
- `snapshot.auto-track` can limit which *new* files are tracked at all. Its value is a fileset
  (jj's path-pattern language), written as a TOML string, so it needs two layers of quotes on the
  command line:

  ```bash
  jj config set --repo snapshot.auto-track "'glob:\"src/**\" | glob:\"tests/**\"'"
  ```

  New files elsewhere then show up in `jj status` as `? Untracked paths` until you run
  `jj file track <path>`.

Check: `check.sh m4-secret`.

---

## Knowledge check

1. *(M4.1)* Which history tells you which workspace ran the command that rewrote a change?
   - a) `jj log`, from the author field.
   - b) `jj op log`, which records the workspace and arguments of every operation.
   - c) `git reflog`, since the repository is colocated.
   - d) `jj evolog`, which lists workspaces per version.

2. *(M4.2)* Two agents and you are working. You run `jj undo` to take back your last `jj describe`.
   What might it actually undo?
   - a) Always your own last operation; undo is per workspace.
   - b) The latest operation in the repository, which may be an agent's.
   - c) Your last operation, plus any agent operations that depend on it.
   - d) Nothing, if agents have run commands since; jj refuses.

3. *(M4.2)* Which command takes back exactly one known operation while keeping everything done
   after it?
   - a) `jj op restore <op>`
   - b) `jj undo`
   - c) `jj op revert <op>`
   - d) `jj abandon <op>`

4. *(M4.3)* `jj log` shows `kxq/0` and `kxq/1`, both `(divergent)`, each with a divergent child.
   You want to keep `kxq/1`. Which command removes the other version and its dependents?
   - a) `jj abandon kxq/0`
   - b) `jj abandon 'kxq/0::'`
   - c) `jj op restore` to before the divergence
   - d) `jj rebase -s kxq/0 -o kxq/1`

5. *(M4.4)* An agent's change `feat` added a function and deleted `config.yaml`. Changes have been
   built on top. What restores the file without losing the function or the later changes?
   - a) `jj abandon feat`
   - b) `jj restore --from feat- --into feat config.yaml`
   - c) `jj undo` until the file is back
   - d) `git checkout HEAD~1 -- config.yaml`

6. *(M4.5)* After ignoring and untracking `.env.local`, which statement is true?
   - a) The credential is gone from the repository entirely.
   - b) Earlier hidden snapshots on this machine still contain it, but a normal push does not send
     them; rotation is still required.
   - c) The next `jj git push` will upload the hidden snapshots.
   - d) The file has been deleted from disk.

### Answer key

1. **b.** The operation log records the workspace and arguments. (a) the author is the same
   person for every workspace; (c) Git knows nothing of jj's operations; (d) evolog lists
   versions and operations, and you must still look the operation up. Reread 4.1.
2. **b.** Undo is repository-wide. (a) is the misconception this module exists to fix; (c) and (d)
   are not behaviors. Reread 4.3.
3. **c.** `op revert` applies the inverse of one operation. (a) rewinds everything after it; (b)
   targets only the latest operation; (d) abandons *changes*, not operations. Reread the table in 4.3.
4. **b.** `x::` includes the descendants. (a) abandons only `kxq/0`; its divergent child is rebased
   onto `kxq/0`'s parent and stays divergent; (c) rewinds all work since, including other agents';
   (d) creates more duplicates. Reread 4.4.
5. **b.** Restore into the change that deleted it, from its parent. (a) loses the function; (c)
   rewinds other work and is repository-wide; (d) Git write commands in a jj repository move `@`
   unpredictably, and the file would land in the wrong change. Reread 4.5.
6. **b.** Hidden local versions remain; push sends only visible changes. (a) overstates it; (c) is
   false; (d) untrack never deletes the file. Reread 4.6.

## Performance task

Run each scenario, repair it, and check it. Each scenario resets the lab, so do them one at a time:

| # | Scenario | Criteria (all must PASS) |
|---|---|---|
| 1 | `scenario.sh stale` | workspace `count` usable; its work on the new main *(M4.T)* |
| 2 | `scenario.sh undo` | agent's change restored; your notes change taken back; `NOTES.md` still in `@` *(M4.2)* |
| 3 | `scenario.sh divergent` | no divergent changes; the validate change exists once *(M4.3)* |
| 4 | `scenario.sh wipe` | tests restored inside the feat change; `item_count()` and the changelog kept; tests pass *(M4.4)* |
| 5 | `scenario.sh secret` | `.env.local` ignored, untracked, in no visible change *(M4.5)* |

After each repair: `check.sh m4-stale` (then `m4-undo`, `m4-divergent`, `m4-wipe`, `m4-secret`).

For each scenario, also write one sentence naming the operation (from `jj op log`) that caused the
damage. The check can't grade that sentence; it is there so you practice diagnosis, not just the
fix.

## Gate

Move on to Module 5 when all five checks pass and you scored at least 5 of 6 on the knowledge check.
If you repaired a scenario with `jj op restore` or repeated `jj undo`, repeat it with the narrow
command from the relevant section: the checks accept any correct end state, but only the narrow
repairs are safe while agents are running. If question 2 or 3 was wrong, reread 4.3 before Module 5,
which turns that section into agent permissions.
