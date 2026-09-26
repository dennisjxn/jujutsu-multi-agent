# Module 7 — Capstone

## Why this matters

Each earlier module isolated one skill. Real work doesn't: you configure the repository, split the
work, run agents in parallel, get interrupted by something going wrong, integrate, and publish, all
in one sitting and in an order you choose. The capstone asks for all six course objectives at once,
under a small, realistic incident. If you can do this without the module pages open, you can run a
team of agents on a real repository.

## Objectives

The capstone assesses every course objective, **C1–C6** (see the [syllabus](README.md)). It
introduces no new material.

## Prerequisites

Modules 0–6, with every module's performance task passing. You need your own plugin copy from
Module 6 (for example `~/jj-plugin/jj-agents`).

Use real agents for some tasks if you have them; the scripted stand-in `agent.sh` can do any
task if you don't. The check is the same either way.

---

## The brief

You lead a small team of agents on the `inventory` project. Deliver a branch named **`release`** on
`origin` containing exactly these five changes on top of the latest `main`, in this order from the
bottom:

| # | Change description (first line, exact) | Work | Who |
|---|---|---|---|
| 1 | `chore: configure agents for jj` | The Module 5 configuration (AGENTS.md, CLAUDE.md, Claude settings, Codex rules, Kiro steering and agent), plus secret patterns in `.gitignore` | you |
| 2 | `feat: reject non-positive quantities` | `agent.sh validate` | agent `validate` |
| 3 | `feat: add item_count()` | `agent.sh count` | agent `count` |
| 4 | `feat: add low_stock report` | `agent.sh lowstock` (or a real agent: implement `low_stock(threshold)` with a test) | agent `lowstock` |
| 5 | `docs: document all public functions` | `agent.sh docsall`: writes `docs/API.md` from the functions present in `inventory.py`, so it must run on the **integrated** code | agent `docsall` |

Constraints:

- Every agent works in its own workspace; you work in `default`.
- Changes 2–4 are independent and run **in parallel**. Change 5 depends on 2–4.
- At the moment marked below, run `capstone.sh incident`. Diagnose and repair what it does
  before publishing, without discarding any agent's legitimate work.
- `release` must pass the tests, contain no conflict markers, and contain nothing that must not be
  published.
- When you are done, only the `default` workspace remains.

A suggested sequence (you may choose another):

1. `capstone.sh start`, then create change 1 in `~/jj-lab/app`.
2. Create workspaces `validate`, `count`, `lowstock`, each starting from change 1 (so every agent
   has `AGENTS.md`).
3. Run the three agents in parallel.
4. **Run `capstone.sh incident`.**
5. Diagnose with `jj op log`, `jj log`, `jj status` in each workspace; repair.
6. Integrate 2–4 as a linear stack on change 1, resolving conflicts; bring the stack up to date with
   `origin/main`.
7. Create workspace `docsall` on top of the integrated stack; run the docs agent.
8. Test, bookmark `release`, push; forget the workspaces and delete their directories.

## Rubric

Each row is a course objective. Your result is checked by

```bash
check.sh capstone ~/jj-plugin/jj-agents
```

which prints the numbered criteria below, each tagged with its objective.

| Objective | Weight | Criteria (all must PASS for "met") | Not met looks like | Exceeded looks like |
|---|---|---|---|---|
| **C1** Install and configure | 10% | 1. `check.sh setup` passes | an agent-mode setting applies to you, or no identity | you can explain each line of `50-agents.toml` |
| **C2** Everyday workflow | 15% | 2. `release` includes the teammate's commit on `main`; 3. exactly five changes beyond `main`, one purpose each | `release` based on stale main; stray fixup or "wip" changes | fixups folded with `jj squash -u`; descriptions have useful bodies |
| **C3** Parallel agents and integration | 25% | 4. all agent workspaces forgotten; 5. all five changes present, `docs/API.md` covers `low_stock` and `item_count`; 6. tests pass, no conflict markers | agents shared a directory; docs generated before integration; a resolution dropped one side | you can justify stack versus merge for this job |
| **C4** Diagnose and recover | 25% | 7. no divergent changes; 8. no visible change contains `.env.local`, and it is not published | repaired with `jj op restore` or repeated `jj undo`, rewinding agents; secret deleted but not ignored | you can name, for each incident, the operation that caused it |
| **C5** Configure the hosts | 15% | 9. release contains AGENTS.md, CLAUDE.md, `.claude/settings.json`, `.codex/rules/jj.rules`, `.kiro/steering/jj.md`, `.kiro/agents/jj-agent.json` | configuration missing or in a separate change | a live host run followed the protocol unprompted |
| **C6** Cross-host plugin | 10% | 10. `check.sh m6 <your plugin>` passes | plugin validates in one host only | installed and used in two or more hosts during the capstone |

"Met" on a row means every criterion in that row passes. The weights say how much each row matters
if you use the capstone to compare approaches or people; the checker itself reports pass/fail per
criterion.

## Reflection (not checked)

Write short answers; they are the part of the capstone that transfers to your real repositories:

1. For each of the three incident effects, which command in `jj op log` (workspace and arguments)
   caused it, and which repair did you choose over a broader one?
2. Where did your integration produce conflicts, and in each case, what did the base section tell
   you about the two agents' intents?
3. Which of the three control layers (instructions, permission rules, hooks/sandbox) would have
   prevented each incident in a real team, and which would only have detected it?

<details><summary>Hints (open only if stuck for more than 15 minutes)</summary>

- **Incident, part 1:** `jj git fetch`, then after integrating, `jj rebase -b <top> -o 'trunk()'`.
- **Incident, part 2:** look at `jj status` in *each* workspace. If your change 1 already ignored
  `.env*`, you will find the file on disk but not in any change: prevention worked. Otherwise, Module 4.6.
- **Incident, part 3:** `jj log -r 'divergent()'`; keep the version the `validate` workspace is on
  (its first line is the one the brief requires); `jj abandon '<id>/<n>::'` for the other.
- **Five changes exactly:** a `.gitignore` fix belongs in change 1:
  `jj squash --from <change with the fix> --into <change 1> .gitignore -u`.
- **docsall:** create its workspace with `-r` set to the top of the integrated stack, after
  resolving conflicts.

</details>

## Gate: finishing the course

You have completed the course when `check.sh capstone <your plugin>` prints
**All checks passed**. If a row is not met, the module to revisit is the one that builds that
objective: C1 → Module 0, C2 → Modules 1–2, C3 → Module 3, C4 → Module 4, C5 → Module 5,
C6 → Module 6. Reset with `capstone.sh start` and run the capstone again; it is designed to be
repeated, and a second run should take less than half the time of the first.
