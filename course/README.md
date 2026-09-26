# Jujutsu for Multi-Agent Coding

### Version control for teams of AI coding agents with jj, Claude Code, Kiro, and OpenAI Codex

**Edition:** September 2026 · jj 0.45.1 · Claude Code 2.1.x · Codex CLI 0.157 · Kiro IDE 1.1 / Kiro CLI 2.24
**Format:** self-paced, 8 modules, about 13–14 hours including labs

---

## Who this course is for

You are a technically fluent professional (an engineer, architect, technical founder, or
technical investor who still builds) with graduate-level technical and business grounding.
You use Git every day: commit, branch, rebase, pull request. You have run at least one AI
coding agent (Claude Code, Kiro, or OpenAI Codex) from a terminal or an IDE. You have never
used Jujutsu.

You do **not** need all three agents. Every lab runs without any agent or model account:
a scripted stand-in (`agent.sh`) plays the agents, and each host's configuration is
verified with that host's own offline tools where one exists. Where a host offers no offline
check, the course says so and gives you the live test to run if you have that host.

## Why this matters

A coding agent is a fast, tireless contributor that edits many files, runs commands, and
occasionally does something destructive. Running several at once multiplies throughput and
multiplies three risks that Git handles poorly when the "developers" are processes on one
machine:

1. **Interference.** Two agents in one checkout overwrite each other's in-progress work.
   Git's answer (`git worktree`) gives each agent its own files and index, but branches and
   the stash stay shared, and nothing records work that was never committed.
2. **Unrecoverable mistakes.** An agent that runs `git reset --hard` or force-pushes can destroy
   work that was never committed.
3. **Integration cost.** Merging five agents' branches by hand erases much of the time they saved.

Jujutsu (command name `jj`) is an open-source, Git-compatible version-control system created
by Martin von Zweigbergk and developed at Google. Its design addresses all three: every edit is recorded
automatically, every repository operation is logged and reversible, conflicts are stored
instead of blocking you, and a repository can have many independent working directories
(*workspaces*) that share one history. It reads and writes ordinary Git repositories, so
GitHub, pull requests, and CI keep working unchanged.

This course teaches you to run that setup, not to admire it.

## What you will be able to do

After the course, you will be able to:

| ID | Course objective (what a graduate can do) |
|---|---|
| **C1** | From a fresh macOS or Linux machine, install jj 0.45 and configure it for both human and unattended agent use, such that the course's setup check passes. |
| **C2** | Given a Git-hosted repository, carry a feature from first edit to a pushed branch on top of the latest main using only jj commands, producing a history with one logical change per commit. |
| **C3** | Given work split across several agents, give each agent an isolated jj workspace, run them in parallel, and integrate their results into one conflict-free, tested, pushed branch with no agent's work lost. |
| **C4** | Given a damaged multi-agent repository (stale workspace, mistaken undo, divergent change, destructive agent edit, leaked secret), diagnose the cause from jj's operation log and change history and repair it without rewinding other agents' work. |
| **C5** | Configure Claude Code, Kiro, and OpenAI Codex so that an agent in a jj repository uses jj instead of Git write commands and can write to the repository under the host's sandbox, verified with each host's checks. |
| **C6** | Build one plugin folder that installs a jj skill, an MCP server, and safety hooks into all three hosts, and validate it with the hosts' tools and the provided tests. |

Terms you may not know yet (*skill*, *MCP server*, *hook*, *workspace*) are each defined in the
module that first uses them.

## How the course is built

Every module has the same shape, so you always know where you are:

1. **Why this matters**: one paragraph.
2. **Objectives**: what you will be able to do at the end, with IDs.
3. **Prerequisites**: which earlier objectives it relies on.
4. **Concept sections**, each tagged with the objectives it builds, each with a worked example
   before you practice.
5. **Practice** exercises between the concepts, with feedback (the capstone, Module 7, is all practice).
6. **Knowledge check**: multiple-choice questions whose wrong answers are common
   misconceptions. The answer key explains every option and tells you what to reread.
7. **Performance task**: a hands-on task with numbered acceptance criteria and a script that checks
   your result.
8. **Gate**: when you are ready for the next module, and what to redo if you are not.

### Conventions used throughout

- **Objective IDs.** `C1`–`C6` are the course objectives above. `M3.2` is Module 3's second
  objective; `M3.T` is Module 3's *terminal* objective, the capability the module exists to
  build. Sections carry tags like *(builds M3.2)* so you can see why you are reading them.
- **Acceptance criteria** are binary: each one is met or not met. Most are checked for you by
  `check.sh <task>`, which prints `PASS` or `FAIL` with the objective ID each line evidences.
- **Gates** are for you, not for a grader. They say "move on when…" and name the exact
  section to revisit if a particular objective is the blocker.
- **Command blocks.** Lines you type start without a prompt; lines of output are shown after
  a `# output` comment or in a separate block. Change IDs and hashes in sample output will
  differ on your machine; everything else should match.
- **"Your lab"** means the folder `~/jj-lab` (or whatever you set `JJ_LAB` to). The lab
  scripts never touch anything outside it.
- **Verified vs. documented.** Every command in this course was run against jj 0.45.1,
  Claude Code 2.1.283, and Codex CLI 0.157.1 on Linux in September 2026. Kiro could not be run
  offline; Kiro statements come from Kiro's documentation and are marked *(documented)*.

## Outcomes map

This table is the design of record: every course objective, the module objectives that build
it, and where it is assessed. The capstone rubric's rows are exactly C1–C6.

| Course objective | Built by | Assessed by |
|---|---|---|
| C1 Install and configure | M0.1, M0.2, M0.3 | `check.sh setup` (Module 0 task); capstone criterion 1 |
| C2 Everyday workflow | M1.1–M1.5, M2.1–M2.5 | Module 1 and 2 knowledge checks; `check.sh m1`, `check.sh m2`; capstone criteria 2–3 |
| C3 Parallel agents, integration | M3.1–M3.5 | Module 3 knowledge check; `check.sh m3`; capstone criteria 4–6 |
| C4 Diagnose and recover | M4.1–M4.5 | Module 4 knowledge check; `check.sh m4-*` (five scenarios); capstone criteria 7–8 |
| C5 Configure the hosts | M5.1–M5.5 | Module 5 knowledge check; `check.sh m5`; capstone criterion 9 |
| C6 Cross-host plugin | M6.1–M6.5 | Module 6 knowledge check; `check.sh m6`; capstone criterion 10 |

## Modules

| # | Module | Terminal objective | Time |
|---|---|---|---|
| 0 | [Setup](00-setup.md) | M0.T Configure jj for humans and agents; setup check passes | 45 min |
| 1 | [How jj thinks](01-how-jj-thinks.md) | M1.T Build a specified stack of changes with jj alone | 75 min |
| 2 | [Everyday work against a Git remote](02-everyday-workflow.md) | M2.T Carry a feature to a pushed branch on the latest main | 90 min |
| 3 | [One agent, one workspace](03-workspaces.md) | M3.T Run three agents in parallel and integrate their work | 120 min |
| 4 | [Recovery](04-recovery.md) | M4.T Diagnose and repair five damaged states | 90 min |
| 5 | [Wiring Claude Code, Codex, and Kiro](05-wiring-hosts.md) | M5.T Configure all three hosts for jj | 120 min |
| 6 | [One plugin for three hosts](06-plugin.md) | M6.T Build, install, and validate the cross-host plugin | 120 min |
| 7 | [Capstone](07-capstone.md) | All course objectives | 150 min |

Appendices: [A. Command and revset reference](appendix-a-reference.md) ·
[B. Glossary](appendix-b-glossary.md) · [C. Sources and version notes](appendix-c-sources.md)

## What you need

- macOS or Linux (Windows: use WSL2; the labs are Bash scripts).
- About 1 GB of free disk space, a terminal, and a text editor.
- The course folder: clone it with
  `git clone https://github.com/jacksodj/jujutsu-multi-agent.git`. It contains
  `course/` (these pages and `labs/`) and
  `plugins/jj-agents/` (the plugin you study in Modules 5–6). Keep them side by side: the
  labs refer to the plugin by relative path.
- Optional, for the live tests: Claude Code, OpenAI Codex CLI, and/or Kiro, each signed in.

Start with [Module 0](00-setup.md).
