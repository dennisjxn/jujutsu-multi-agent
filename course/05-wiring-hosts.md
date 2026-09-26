# Module 5 — Wiring Claude Code, Codex, and Kiro

## Why this matters

Everything so far worked because *you* typed the right jj commands. An agent types whatever its
training suggests, and its training is overwhelmingly Git. Left alone, an agent in a jj repository
will run `git add` and `git commit`, open editors, and cheerfully run `jj undo` to fix its own
mistake, rewinding every other agent. This module configures each host so that the right behavior
is the easy path and the dangerous behavior needs a human: shared instructions all three read,
permission rules each enforces, and, for Codex, a sandbox adjustment without which jj cannot work
at all.

## Objectives

After this module you will be able to:

- **M5.T** — Configure the lab repository so that Claude Code, Codex, and Kiro agents use jj safely,
  with the configuration committed to the repository, such that `check.sh m5` passes.
- **M5.1** — Write one `AGENTS.md` jj protocol that all three hosts read, and import it into
  Claude Code's `CLAUDE.md`.
- **M5.2** — Configure Claude Code permission rules and environment for jj, and predict whether a
  given command is allowed, asked about, or denied.
- **M5.3** — Diagnose why jj fails under Codex's default sandbox, fix it with extra writable roots,
  and write and test Codex command rules.
- **M5.4** — Configure Kiro with a steering file, permission rules, and a custom agent that loads the
  jj skill.
- **M5.5** — Map each host's built-in parallelism onto jj workspaces, and choose a safe pattern for a
  given multi-agent job.

## Prerequisites

Modules 0–4. In particular: agent mode and `JJ_AGENT` (M0.3), workspaces (M3.2), and why `jj undo`
and `jj op restore` are repository-wide (M4.2).

You do not need any of the three hosts installed to complete the performance task. If you have
Codex installed, one extra check runs; each section ends with an optional live test for hosts you
have.

---

## 5.1 Three layers of control

Each host gives you the same three kinds of control, under different names:

| Layer | What it does | Claude Code | Codex | Kiro |
|---|---|---|---|---|
| **Instructions** | Tells the model what to do. Soft: the model can ignore it. | `CLAUDE.md` | `AGENTS.md` | steering files, `AGENTS.md` |
| **Permission rules** | Allows, asks about, or refuses a command before it runs. Deterministic, but matches command *text*. | `permissions` in `settings.json` | `.rules` files | `permissions` rules |
| **Sandbox / hooks** | Limits what a running command can touch, or runs your own script before a tool call. | hooks | sandbox, hooks | hooks |

No layer is sufficient alone. Instructions are ignored under pressure; rules match text and can be
sidestepped (`git -C . commit` does not match a rule written for `git commit`); hooks and sandboxes
catch what gets through. You will configure the first two layers here and add hooks in Module 6.

The template files used below are in `$JJ_COURSE/plugins/jj-agents/templates/`.

## 5.2 One protocol for every agent: `AGENTS.md` *(builds M5.1)*

`AGENTS.md` is a plain Markdown file of instructions for coding agents, placed at the repository
root. Codex reads it (and nested `AGENTS.md` files down to the current directory); Kiro includes it
in every request *(documented)*. Claude Code reads `CLAUDE.md` instead, which can import another
file with a line of the form `@path`.

Copy the template into your lab and look at its structure:

```bash
lab.sh reset
cd ~/jj-lab/app
cp "$JJ_COURSE/plugins/jj-agents"/templates/shared/AGENTS.md AGENTS.md
printf '# Claude Code instructions\n\n@AGENTS.md\n' > CLAUDE.md
```

(`$JJ_COURSE` is the course folder; you set it in Module 0, step 4.)

The template is organized by what an agent must decide, not by jj feature:

- **Always**: the per-task loop from Module 2 (`jj new 'trunk()' -m`, `jj commit -m`), always
  `-m`, `jj squash -u`, stay in your own workspace, repair staleness, resolve conflicts in a
  new change on top.
- **Never, without asking the user first**: `jj undo`, `jj redo`, `jj op restore`/`revert`/`abandon`
  (Module 4: repository-wide), `jj abandon` or rewriting other agents' changes, `jj git push`.
- **Never**: Git write commands; writing secrets into the tree.

Two writing choices matter for models. Each rule says *why* in a few words ("these rewind the whole
repository, including other agents' workspaces"): models follow rules they can reason about more
reliably than bare prohibitions. And the commands are exact and copyable, including quoting
(`'trunk()'`), because a model that half-remembers a flag will guess the Git one.

Because `AGENTS.md` and `CLAUDE.md` are ordinary files, they are part of the repository: every
workspace created from a change that contains them has them too, so every agent sees the same
protocol.

## 5.3 Claude Code *(builds M5.2)*

Claude Code reads project settings from `.claude/settings.json`. Copy the template:

```bash
mkdir -p .claude
cp "$JJ_COURSE/plugins/jj-agents"/templates/claude/settings.json .claude/settings.json
```

Its three parts:

```json
{
  "env": { "JJ_AGENT": "1" },
  "permissions": {
    "allow": ["Bash(jj *)", "mcp__plugin_jj-agents_jj__*"],
    "ask":   ["Bash(jj undo *)", "Bash(jj redo *)", "Bash(jj abandon *)", "Bash(jj op restore *)",
              "Bash(jj op revert *)", "Bash(jj op abandon *)", "Bash(jj git push *)"],
    "deny":  ["Bash(git commit *)", "Bash(git push *)", "Bash(git pull *)", "Bash(git merge *)",
              "Bash(git rebase *)", "Bash(git reset *)", "Bash(git checkout *)", "Bash(git switch *)",
              "Bash(git stash *)", "Bash(git cherry-pick *)", "Bash(git add *)", "Bash(git worktree add *)"]
  }
}
```

- **`env`** sets environment variables for the commands Claude Code runs. `JJ_AGENT=1` activates
  your agent-mode scope from Module 0. (Claude Code also sets `CLAUDECODE=1` itself, which your scope
  already matches; setting `JJ_AGENT` too keeps all three hosts consistent.)
- **`Bash(jj *)`** is a rule for the shell tool: the command must start with `jj` followed by a
  space or end. The space matters: `Bash(jj *)` does not match a program called `jjq`. It also
  matches bare `jj`.
- **`mcp__plugin_jj-agents_jj__*`** pre-approves the tools of the MCP server you will install in
  Module 6. (An MCP server is a program that offers an agent extra tools through the Model Context
  Protocol; Module 6 explains it.)

**How Claude Code decides.** Rules are checked in the order **deny, then ask, then allow**; the first
list with a match decides. So `jj undo` matches both `Bash(jj *)` (allow) and `Bash(jj undo *)`
(ask), and Claude Code **asks**. For a compound command such as `cd x && git commit -m y`, each part
is checked separately: a deny or ask rule matching *any* part applies, and an allow rule must match
*every* part. Wrapped forms are not matched: `git -C . commit -m y` does not start with
`git commit`, so the deny rule misses it. Module 6's hook catches that case.

### Practice 5.3

With the settings above, predict allow, ask, or deny for each command:

1. `jj log -r 'trunk()..@'`
2. `jj git push --bookmark low-stock`
3. `jj git fetch && git pull`
4. `git -C . commit -m "x"`
5. `git status`

<details><summary>Feedback</summary>

1. **Allow**: matches `Bash(jj *)` and no deny or ask rule.
2. **Ask**: `Bash(jj git push *)` is an ask rule, checked before allow.
3. **Deny**: the second part matches `Bash(git pull *)`.
4. **Not matched by any of these rules**, so Claude Code falls back to its default handling of
   unlisted commands, which in the default permission mode means asking you. The deny rule does
   not catch it.
5. **Not matched by any of these rules** either. Claude Code treats some read-only commands as
   safe by default, so it may run without asking; add `"Bash(git status *)"` and other read-only
   Git commands to `allow` if you want to be certain.

</details>

**Worktrees.** Claude Code can isolate work in Git worktrees: `claude --worktree <name>`, subagents
declared with `isolation: worktree`, and the `/batch` command. In a jj repository you want jj
workspaces instead. Claude Code supports that through two hooks, `WorktreeCreate` and
`WorktreeRemove`, which replace its Git worktree logic with a script of your choice. The plugin in
Module 6 ships those scripts; for now, note that without them, Claude Code's worktree features create
Git worktrees that jj does not know about.

**Live test (optional, Claude Code installed).** Start `claude` in `~/jj-lab/app` and ask:
"Commit your changes with git." Claude Code should refuse the `git commit` (deny rule) and, having
read `CLAUDE.md`, offer `jj commit -m` instead.

## 5.4 OpenAI Codex *(builds M5.3)*

### The sandbox problem, measured

Codex runs commands inside a sandbox (on Linux, bubblewrap and Landlock; on macOS, Seatbelt).
The default mode for a project, **`workspace-write`**, lets commands write inside the project
directory, with protected exceptions: the top-level `.git` directory, `.codex`, and `.agents` stay
**read-only**. That protects Git history from a runaway agent, and it breaks jj: in a colocated
repository, jj writes new commits into `.git/objects`.

If you have Codex installed, see it for yourself with `codex sandbox`, which runs one command
inside Codex's sandbox without any model. The probe below uses `jj util snapshot`, which records the
working directory into `@` and nothing else, so it cannot disturb the files you copied in 5.2–5.3:

```bash
cd ~/jj-lab/app
echo "probe" > probe.txt
codex sandbox -c 'sandbox_mode="workspace-write"' -- jj util snapshot
```

```text
# output
Internal error: Failed to snapshot the working copy
Caused by:
1: Could not write object of type file
2: Could not create named temp file in '/home/you/jj-lab/app/.git/objects'
3: Read-only file system (os error 30) at path "/home/you/jj-lab/app/.git/objects/.tmpJSPn22"
```

It gets worse in a secondary workspace (Module 3). A workspace directory such as
`~/jj-lab/app-ws/agent-a` holds only files and a small `.jj` pointer; the repository data lives in
the main workspace's `.jj/repo` and `.git`, which are **outside** the directory Codex was started
in, so even `.jj` writes fail.

The fix is to add those directories as **writable roots**, extra directories the sandbox allows
writing to. An explicit writable root overrides the default `.git` protection:

```bash
codex sandbox -c 'sandbox_mode="workspace-write"' \
  -c "sandbox_workspace_write.writable_roots=[\"$HOME/jj-lab/app/.git\"]" \
  -- jj util snapshot
```

```text
# output
Snapshot complete.
```

Clean up by deleting the file (`rm probe.txt`); the next jj command records its removal.

Note the tradeoff you just made: `.git` is writable again for *every* command, including
`git commit`. The sandbox no longer blocks Git writes, so the command rules below and the hook in
Module 6 have to.

### `codex-jj`: a launcher that computes the roots

Writable roots are absolute paths and differ per workspace, so hard-coding them in a committed
config file does not work (a relative path in `.codex/config.toml` is resolved against the `.codex`
folder, and would point somewhere different in each workspace). The course provides a small
launcher, `codex-jj`, that finds the main workspace with `jj workspace root --name default` and
starts Codex with the right roots and with `JJ_AGENT=1` set for Codex's commands:

```bash
mkdir -p ~/.local/bin
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc   # once; skip if `echo $PATH` already lists it
cp "$JJ_COURSE/plugins/jj-agents"/templates/codex/codex-jj ~/.local/bin/
chmod +x ~/.local/bin/codex-jj
codex-jj --dry-run             # show the codex command it would run
codex-jj --probe               # prove jj can write here under the sandbox (changes nothing)
```

```text
# output (--probe in ~/jj-lab/app, the main workspace)
writable: /home/you/jj-lab/app/.jj
writable: /home/you/jj-lab/app/.git
JJ_AGENT=1 set

# output (--probe in a secondary workspace, e.g. ~/jj-lab/app-ws/agent-a)
writable: /home/you/jj-lab/app-ws/agent-a/.jj
writable: /home/you/jj-lab/app/.git
writable: /home/you/jj-lab/app/.jj/repo
JJ_AGENT=1 set
```

From now on, start Codex in a jj workspace with `codex-jj` (all `codex` arguments pass through, for
example `codex-jj exec "fix the failing test"`).

### Command rules

Codex **rules** are small files in Starlark (a Python-like configuration language) that decide
whether a command runs, prompts, or is forbidden, before the sandbox is even involved. Copy the
template into the repository:

```bash
mkdir -p .codex/rules
cp "$JJ_COURSE/plugins/jj-agents"/templates/codex/jj.rules .codex/rules/jj.rules
```

One rule from it:

```python
prefix_rule(
    pattern = ["git", ["commit", "push", "pull", "merge", "rebase", "reset", "checkout", "switch",
                       "stash", "cherry-pick", "add"]],
    decision = "forbidden",
    justification = "This is a Jujutsu (jj) repository. Use jj instead: jj commit -m, ...",
    match = [["git", "commit", "-m", "x"], ["git", "push"], ["git", "add", "."]],
    not_match = [["git", "status"], ["git", "log"], ["git", "diff"]],
)
```

`pattern` matches the start of the command: `"git"` followed by any one of the listed words. The
list is the same set of Git write commands that the Claude Code and Kiro templates deny, so all
three hosts enforce one policy (the Module 6 hook blocks a few more).
`decision` is `allow`, `prompt`, or `forbidden`; when several rules match, the strictest wins. The
`justification` is shown to the model, so write it as an instruction. `match` and `not_match` are
built-in tests: Codex refuses to load the file if an example disagrees with the pattern. The
template also prompts before `jj undo`, `jj redo`, `jj abandon`, `jj op restore/revert/abandon`,
and `jj git push`, and allows everyday jj commands.

Test rules without running anything:

```bash
codex execpolicy check --rules .codex/rules/jj.rules -- git commit -m x
codex execpolicy check --rules .codex/rules/jj.rules -- jj git push --bookmark x
codex execpolicy check --rules .codex/rules/jj.rules -- git -C . commit -m x
```

```text
# output (first line abridged)
{"matchedRules":[{"prefixRuleMatch":{"matchedPrefix":["git","commit"],"decision":"forbidden","justification":"This is a Jujutsu (jj) repository. …"}}],"decision":"forbidden"}
{"matchedRules":[…],"decision":"prompt"}
{"matchedRules":[]}
```

The third result is the same blind spot as Claude Code's: prefix rules match text, and `-C .` shifts
the words. Keep that in mind; Module 6's hook closes it.

Codex loads a project's `.codex/` folder (rules, config, hooks) **only if you have marked the
project trusted**. Codex asks the first time you start it in a directory; the answer is stored in
`~/.codex/config.toml` as `[projects."<path>"] trust_level = "trusted"`. A new jj workspace is a new
directory, so Codex asks again there. Alternatively, put the rules file in `~/.codex/rules/`, which
applies everywhere.

**Worktrees.** The Codex app and `codex --worktree` create Git worktrees (detached HEAD, under
`~/.codex/worktrees`). jj does not track those as workspaces. In a jj repository, create jj workspaces
yourself (Module 3) and start `codex-jj` in each.

**Live test (optional, Codex installed).** In `~/jj-lab/app`, run
`codex-jj exec "Add a one-line comment at the top of inventory.py and record the change with
version control."` The result should be a jj change with a description, and no Git commit.

## 5.5 Kiro *(builds M5.4)*

Kiro could not be run offline for this course; everything in this section follows Kiro's
documentation as of September 2026 *(documented)*. Kiro has an IDE and a CLI (`kiro-cli`); both read
the same `.kiro/` project folder.

### Steering file

A **steering file** is Kiro's instruction file: Markdown in `.kiro/steering/`, with front matter
(a small YAML header between `---` lines) saying when to include it. `inclusion: always` includes it
in every interaction. Kiro also reads `AGENTS.md`, but steering files are where Kiro users look first,
and they let you keep a short, always-on jj summary:

```bash
mkdir -p .kiro/steering
cp "$JJ_COURSE/plugins/jj-agents"/templates/kiro/steering/jj.md .kiro/steering/jj.md
head -3 .kiro/steering/jj.md
```

```text
---
inclusion: always
---
```

### Permission rules

Kiro's permission rules have the form *capability, match, effect*. The `shell` capability matches
command text with `*` wildcards; the effect is `allow`, `ask`, or `deny`; **deny beats ask beats
allow at every scope**, and compound commands (`&&`, `||`, `;`, `|`) are split and each part checked.
Rules can live in your user file `~/.kiro/settings/permissions.yaml`, or in a custom agent. The
template `templates/kiro/permissions.yaml` has the user-level version:

```yaml
rules:
  - capability: shell
    match: ["jj *"]
    effect: allow
  - capability: shell
    match: ["jj undo*", "jj redo*", "jj abandon*", "jj op restore*", "jj op revert*", "jj op abandon*", "jj git push*"]
    effect: ask
  - capability: shell
    match: ["git commit*", "git push*", "git pull*", "git merge*", "git rebase*", "git reset*", "git checkout*", "git switch*", "git stash*", "git cherry-pick*", "git add*", "git worktree add*"]
    effect: deny
```

By default Kiro allows read-only Git commands (`git status`, `git log`, `git diff`) and asks for
everything else, including every `jj` command, until you allow it.

### Custom agent

A **custom agent** is a named Kiro configuration: its own prompt, tools, resources, and permissions.
The template `templates/kiro/agents/jj-agent.json`:

```json
{
  "name": "jj-agent",
  "description": "Coding agent for Jujutsu (jj) repositories: uses jj for all version control, never git write commands.",
  "prompt": "You work in a Jujutsu (jj) repository. Follow the jj rules in the steering file and in AGENTS.md. Use the jj-multi-agent skill for any version-control task.",
  "tools": ["read", "write", "shell", "@jj"],
  "resources": [
    "file://AGENTS.md",
    "file://.kiro/steering/jj.md",
    "skill://.kiro/skills/*/SKILL.md",
    "skill://~/.kiro/skills/*/SKILL.md"
  ],
  "includeMcpJson": true,
  "permissions": { "rules": [ … the same three rules … ] }
}
```

Custom agents do **not** load steering files or skills unless listed in `resources`, which is why
they appear there. `"@jj"` grants the tools of an MCP server named `jj` (Module 6), and
`includeMcpJson` makes the agent use the servers from your `mcp.json` files.

```bash
mkdir -p .kiro/agents
cp "$JJ_COURSE/plugins/jj-agents"/templates/kiro/agents/jj-agent.json .kiro/agents/jj-agent.json
```

**Agent mode for Kiro.** Kiro sets no environment variable that identifies its commands, so start it
with `JJ_AGENT=1` in its environment: `JJ_AGENT=1 kiro-cli chat --agent jj-agent`. For the IDE, start
it from a terminal with the variable exported, so the IDE's commands inherit it. If you can't, the
steering file's rule "always pass `-m`" is your only protection against editor prompts.

**Hooks.** Kiro has `PreToolUse` hooks that can block a tool call, but its documentation does not
state which exit code blocks or which field of the hook's input holds the shell command. Until you
have verified both in your Kiro version, rely on permission rules, which are deterministic.

**Live test (optional, Kiro installed).** Run `JJ_AGENT=1 kiro-cli chat --agent jj-agent` in
`~/jj-lab/app` and ask it to commit a change with Git. The `git commit` should be denied.

## 5.6 Parallelism: each host's features versus jj workspaces *(builds M5.5)*

Every host now has a way to run agents in parallel. Map each onto jj before you use it:

| Host feature | What it isolates | In a jj repository |
|---|---|---|
| Claude Code subagents (default) | Conversation context only; same directory | Unsafe for parallel edits (Module 3.1). Fine for read-only research. |
| Claude Code `--worktree`, subagents with `isolation: worktree`, `/batch` | A separate directory per agent via `WorktreeCreate` | Safe **with** the plugin's hook (jj workspace); without it, Git worktrees jj does not track. |
| Codex app threads / `codex --worktree` | A Git worktree per thread | Git worktrees, not jj workspaces. Create jj workspaces and run `codex-jj` in each instead. |
| Codex cloud tasks | A cloud sandbox per task; results come back as pull requests | Independent of your local jj repository; fetch their branches with `jj git fetch`. |
| Kiro subagents | Conversation context; share the workspace files | Unsafe for parallel edits. |
| Kiro spec "Run all tasks" waves | Concurrent tasks in one directory | Unsafe for parallel edits; run one Kiro session per jj workspace instead. |
| Kiro autonomous agent / cloud sessions | A cloud sandbox per task; results as pull requests | Independent of the local repository, like Codex cloud. |

The pattern that works for all three hosts: **you (or a script) create one jj workspace per agent,
then start one agent session in each**. Host-level isolation is safe only where the host lets jj
create the directory (Claude Code with the hook).

---

## Knowledge check

1. *(M5.2)* A Claude Code settings file allows `Bash(jj *)` and asks for `Bash(jj op restore *)`.
   The agent runs `jj op restore 3f2a`. What happens?
   - a) It runs: the allow rule is broader and listed first.
   - b) Claude Code asks you, because ask rules are checked before allow rules.
   - c) It is denied, because it matches two rules.
   - d) It runs, because `op restore` is a subcommand and rules match only the first word.

2. *(M5.2)* Your deny list has `Bash(git commit *)`. Which command still gets past that rule?
   - a) `git commit -m x`
   - b) `cd src && git commit -am x`
   - c) `git -C . commit -m x`
   - d) `git commit`

3. *(M5.3)* In a colocated repository, jj commands inside Codex fail with "Read-only file system"
   under `.git/objects`. What is the cause?
   - a) jj is not installed inside the sandbox.
   - b) Codex's `workspace-write` sandbox keeps `.git` read-only, and jj writes Git objects there.
   - c) The repository is not trusted, so Codex mounts it read-only.
   - d) jj requires network access, which the sandbox blocks.

4. *(M5.3)* Why can't you commit a `.codex/config.toml` with
   `writable_roots = ["../.git"]` and be done?
   - a) Codex ignores `writable_roots` in project config.
   - b) Relative roots are resolved against the `.codex` folder, and in a secondary jj workspace the
     repository data is elsewhere, so the path is wrong there.
   - c) TOML does not allow relative paths.
   - d) `.git` can never be made writable in Codex.

5. *(M5.4)* A Kiro custom agent ignores your steering file. Most likely cause?
   - a) Steering files only work in the CLI.
   - b) Custom agents load steering and skills only when listed in `resources`.
   - c) The steering file needs `inclusion: manual`.
   - d) Kiro reads only `AGENTS.md`.

6. *(M5.5)* You want Kiro to implement four independent spec tasks in parallel in a jj repository.
   Which setup is safe?
   - a) "Run all tasks" in one Kiro session; the tasks run in parallel waves.
   - b) Four Kiro subagents in one session.
   - c) Four jj workspaces, one Kiro session started in each.
   - d) One Kiro session with four Git worktrees.

### Answer key

1. **b.** Order is deny, ask, allow. (a) order in the file is irrelevant; (c) matching two rules is
   normal; (d) rules match the whole command prefix. Reread 5.3.
2. **c.** The rule matches command text starting `git commit`; `-C .` changes the text. (a) and (d)
   match; (b) is split at `&&` and the second part matches. Reread 5.3.
3. **b.** The protected `.git` directory. (a) jj runs, then fails writing; (c) trust affects which
   config loads, not mounts; (d) local commits need no network. Reread 5.4.
4. **b.** The path is relative to `.codex/`, and secondary workspaces keep repository data in the main
   workspace. (a) project config does apply writable roots when the project is trusted (verified in
   this course); (c) and (d) are false. Reread 5.4, "codex-jj".
5. **b.** Custom agents need explicit `resources`. (a) both read `.kiro/`; (c) `always` is right;
   (d) Kiro reads both. Reread 5.5.
6. **c.** One session per workspace. (a) and (b) share one directory (Module 3.1); (d) Git worktrees
   are not jj workspaces. Reread 5.6.

## Performance task

In a freshly reset lab, configure the repository for all three hosts and commit the configuration.
The reset discards what you copied while reading 5.2–5.5; do it again here from the templates (it is
quick) and commit it:

```bash
lab.sh reset
cd ~/jj-lab/app
```

1. `AGENTS.md` at the root containing the jj protocol (at minimum `jj new` and `jj workspace`
   guidance), and a `CLAUDE.md` that imports it with `@AGENTS.md`. *(M5.1)*
2. `.claude/settings.json` that allows `Bash(jj *)`, denies at least `Bash(git commit *)` and
   `Bash(git push *)`, asks before history-rewinding jj commands, and sets `JJ_AGENT=1`. *(M5.2)*
3. `.codex/rules/jj.rules` that forbids `git commit` and does not forbid `jj commit`. *(M5.3)*
4. `codex-jj` on your PATH; if Codex is installed, `codex-jj --probe` succeeds in `~/jj-lab/app`. *(M5.3)*
5. `.kiro/steering/jj.md` with `inclusion: always`, and `.kiro/agents/jj-agent.json` whose permission
   rules deny `git commit`. *(M5.4)*
6. All of the above committed in one change described `chore: configure agents for jj`. *(M5.T)*

You may start from the templates, but read and adjust each file: the check verifies content, and
the capstone reuses this configuration (its reflection question 3 asks which layer would have
prevented each incident).

```bash
check.sh m5
```

Criterion M5.5 is assessed by knowledge-check question 6 and in the capstone.

## Gate

Move on to Module 6 when `check.sh m5` passes and you scored at least 5 of 6 on the knowledge
check. If the probe fails, run `codex-jj --dry-run` and compare the writable roots with the paths in
the error message. If question 1 or 2 was wrong, redo Practice 5.3: Module 6 builds on knowing exactly
what permission rules can and cannot catch.
