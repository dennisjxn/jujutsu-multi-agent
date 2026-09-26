# Module 0 — Setup

## Why this matters

Everything later in the course runs jj unattended: an agent types a jj command, nobody is
watching, and the command must finish on its own. A version-control tool that opens a text
editor or a pager (the program that shows long output one screen at a time) waits forever for
a keypress that never comes, and the agent stalls. This module installs the tools and gives jj
two personalities: interactive for you, non-interactive for agents, switched automatically.

## Objectives

After this module you will be able to:

- **M0.T** — On macOS or Linux, install and configure jj for both human and agent use, such that
  `check.sh setup` reports all checks passed.
- **M0.1** — Install jj 0.45 or newer, Git 2.41 or newer, Node.js 18 or newer, and Python 3, and
  confirm each version from the command line.
- **M0.2** — Set your jj identity and Git-style conflict markers in your user configuration.
- **M0.3** — Write a conditional configuration block that disables jj's editor and pager only
  when an agent is running jj, and demonstrate both behaviors.

## Prerequisites

None. You need a terminal, a text editor, and permission to install software.

---

## Step 1 — Install the tools *(builds M0.1)*

**jj** is distributed as a single binary. Use one of these:

```bash
# macOS or Linux with Homebrew
brew install jj

# Any platform with a Rust toolchain (compiles from source, about 5–10 minutes)
cargo install --locked --bin jj jj-cli

# Or download a prebuilt binary from https://github.com/jj-vcs/jj/releases
# (for example jj-v0.45.1-aarch64-apple-darwin.tar.gz), unpack it, and put `jj` on your PATH.
```

Other package managers (winget, Scoop, pacman, Nix, MacPorts) are listed at
<https://docs.jj-vcs.dev/latest/install-and-setup/>.

jj uses the `git` program for network operations (fetch and push) and needs **Git 2.41 or newer**.
The labs also need **Python 3** (the sample project is a small Python module) and, from Module 5
on, **Node.js 18 or newer** (the plugin's hooks and MCP server are Node scripts).

Check all four:

```bash
jj --version
git --version
node --version
python3 --version
```

```text
# output (your patch versions may be higher)
jj 0.45.1
git version 2.43.0
v22.22.2
Python 3.12.3
```

> **Version note.** jj releases monthly and still makes breaking changes before 1.0. This course
> was verified on 0.45.1 (released 2026-09-03). If you have a newer version, everything should
> still work; Appendix C lists the changes already announced for 0.46.

## Step 2 — Tell jj who you are *(builds M0.2)*

jj keeps its settings in TOML files (a simple `key = value` format). Your *user configuration*
applies to every repository. Set your identity:

```bash
jj config set --user user.name "Your Name"
jj config set --user user.email "you@example.com"
```

Do this **before** creating or cloning a repository. jj stamps your identity onto the first
working-copy change it creates; if the identity is missing at that moment, that change has an
empty author until it is next rewritten, and jj prints a warning suggesting
`jj metaedit --update-author` to fix it right away.

Now set one more option that the rest of the course depends on:

```bash
jj config set --user ui.conflict-marker-style git
```

When two changes edit the same lines, jj writes *conflict markers* into the file, as Git does.
jj's default marker style is a compact diff format of its own. The `git` style produces the
familiar `<<<<<<<` / `=======` / `>>>>>>>` blocks that every language model has seen millions
of times, which makes agents far more reliable at resolving conflicts. Module 3 explains the
markers in detail.

See where the file lives and what it contains:

```bash
jj config path --user
jj config list --user
```

```text
# output
/home/you/.config/jj/config.toml
user.name = "Your Name"
user.email = "you@example.com"
ui.conflict-marker-style = "git"
```

On both macOS and Linux the file is `~/.config/jj/config.toml` (or
`$XDG_CONFIG_HOME/jj/config.toml` if you set that variable).

## Step 3 — Give agents a non-interactive jj *(builds M0.3)*

Three jj behaviors are right for you and wrong for an agent:

| Setting | Default | Why it hurts an agent |
|---|---|---|
| `ui.editor` | `nano` on macOS/Linux | `jj describe` without `-m` opens an editor and waits for input |
| `ui.paginate` | `auto` | long output may be piped into `less`, which waits for keypresses |
| `ui.color` | `auto` | color codes waste tokens and confuse parsers when forced on |

(`ui.paginate = "auto"` only pages when output goes to a real terminal, which agent tools
usually don't provide, but some do. Turning it off costs nothing.)

You could set these globally, but then *you* lose your editor. Instead, use a **conditional
scope**: a block of settings that applies only when a condition holds. jj 0.39 and later can
condition on environment variables, and the three hosts each give you one to key on:

- **Claude Code** sets `CLAUDECODE=1` in every command its agent runs.
- **OpenAI Codex** sets `CODEX_THREAD_ID` in every command its agent runs.
- **Kiro** sets no documented variable, so you will set your own, `JJ_AGENT=1`, when you launch
  it (Module 5). You will also set `JJ_AGENT=1` for the other two hosts, for consistency.

jj also reads every `.toml` file in a `conf.d` folder next to your user config, in name order.
Put the agent settings in their own file there:

```bash
mkdir -p ~/.config/jj/conf.d
cat > ~/.config/jj/conf.d/50-agents.toml <<'EOF'
# Settings that apply only when a coding agent runs jj.
# Matches if ANY of the listed environment variables is set.
[[--scope]]
--when.environments = ["JJ_AGENT", "CLAUDECODE", "CODEX_THREAD_ID"]
[--scope.ui]
editor = "true"      # `true` is a program that exits immediately: no editor can block
paginate = "never"
color = "never"
EOF
```

Read the file top to bottom once. `[[--scope]]` starts a conditional block;
`--when.environments` lists the variables (a bare name means "is set to anything");
`[--scope.ui]` holds the `ui` settings that apply inside the block.

Setting the editor to `true` (the Unix command that does nothing and succeeds) means that if
an agent forgets `-m`, jj accepts the pre-filled text instead of hanging. You will still teach
agents to always pass `-m`, because accepting pre-filled text can silently produce a poor
message; the setting is a safety net, not the plan.

### Worked example: both personalities

```bash
jj config get ui.editor
JJ_AGENT=1 jj config get ui.editor
JJ_AGENT=1 jj config get ui.paginate
```

```text
# output
nano
true
never
```

The first line is your editor (it may be `vim` or something else if you set `$EDITOR`); the
other two show agent mode.

> **If the first command prints `true`:** you are probably reading this inside an agent's
> terminal (for example Claude Code's), which has already set `CLAUDECODE=1`. That is agent
> mode working. Check from a plain terminal, or run `env -u CLAUDECODE jj config get ui.editor`.

### Practice 0.1

Predict each output before running it, then check:

1. `CODEX_THREAD_ID=abc jj config get ui.color`
2. `JJ_AGENT= jj config get ui.editor` (the variable is set, but to an empty string)
3. `jj config get ui.color`

<details><summary>Feedback</summary>

1. `never`: any listed variable being set activates the scope.
2. `true`: a bare name in `--when.environments` means "set", and an empty string still counts
   as set.
3. `auto` (or whatever you configured): no listed variable is set.

</details>

## Step 4 — Put the lab scripts on your PATH

The course folder (the one containing `course/` and `plugins/`) has these scripts in
`course/labs/`:

| Script | What it does |
|---|---|
| `lab.sh reset` | Rebuilds the lab from scratch in `~/jj-lab` |
| `lab.sh teammate` | Simulates a teammate pushing to the lab's `main` (Module 2) |
| `demo-shared-dir.sh` | Shows two agents sharing one directory (Module 3) |
| `agent.sh <task> <dir>` | A scripted stand-in for a coding agent |
| `scenario.sh <name>` | Builds a broken state for Module 4 |
| `capstone.sh start` | Starts the Module 7 capstone |
| `check.sh <task>` | Checks a performance task and prints PASS/FAIL per criterion |

Every module runs these from inside the lab, so put them on your `PATH` and remember where the
course lives. Run this **once**, from the course folder (running it again adds duplicate lines to
your shell profile):

```bash
chmod +x course/labs/*.sh
echo "export JJ_COURSE=\"$PWD\"" >> ~/.bashrc          # zsh: ~/.zshrc; macOS bash: ~/.bash_profile
echo 'export PATH="$JJ_COURSE/course/labs:$PATH"' >> ~/.bashrc
source ~/.bashrc
# optional: export JJ_LAB="$HOME/somewhere/jj-lab"   (default: ~/jj-lab)
```

Check: `echo "$JJ_COURSE"` prints the course folder, and `which lab.sh` finds the script. From
now on, `$JJ_COURSE/plugins/jj-agents` is the plugin you study in Modules 5–6.

---

## Knowledge check

1. *(M0.3)* An agent runs `jj describe` without `-m` in a repository where no editor setting
   applies to it. What happens?
   - a) jj uses an empty description and continues.
   - b) jj opens the configured editor and waits for input that never comes.
   - c) jj refuses to run because it detects a non-interactive terminal.
   - d) jj copies the previous description.

2. *(M0.3)* You put `editor = "true"` directly under `[ui]` in `config.toml` instead of inside the
   scope. What is the consequence?
   - a) None; agents and humans both benefit.
   - b) jj rejects the configuration file.
   - c) Your own `jj describe` stops opening an editor, so you can no longer write multi-line
     descriptions interactively.
   - d) Only agents are affected, because humans always pass `-m`.

3. *(M0.2)* You cloned a repository, then set `user.email`. `jj log` shows your first
   working-copy change with an empty author. Why?
   - a) jj caches identity per terminal session.
   - b) The working-copy change was created during the clone, before the identity existed; setting
     config later affects only commits created or rewritten after that.
   - c) `user.email` must be set with `--repo`, not `--user`.
   - d) jj requires `user.name` to be set before `user.email`.

4. *(M0.2)* Why does this course switch `ui.conflict-marker-style` to `git`?
   - a) jj cannot resolve conflicts written in its own style.
   - b) Git-style markers are the format language models have seen most, which makes agents more
     reliable at editing them.
   - c) Git-style markers are required for pushing to GitHub.
   - d) It makes jj store conflicts in Git's format inside commits.

### Answer key

1. **b.** jj launches `ui.editor` and waits for it to exit. (a) is what `-m ""` would do;
   (c) jj has no such detection; (d) is not a jj behavior. Reread Step 3.
2. **c.** The setting applies to everyone. (a) ignores the cost to you; (b) the file is valid;
   (d) the setting doesn't know who is typing. Reread Step 3, the paragraph on conditional scopes.
3. **b.** The change was created by `jj git clone` with the identity available at that moment, and
   it hasn't been rewritten since.
   (a) there is no session cache; (c) `--user` is correct; (d) order does not matter. Reread
   Step 2. Fix it with `jj metaedit --update-author`.
4. **b.** It changes only how conflicts are *written into files* for editing. (a) jj parses its
   own style fine; (c) jj refuses to push conflicted commits by default (Module 2); (d) the storage
   inside commits is unaffected. Reread Step 2.

## Performance task

Run:

```bash
check.sh setup
```

Acceptance criteria (each is one or more `PASS` lines):

1. jj 0.45 or newer, Git 2.41 or newer, Node.js 18 or newer, and Python 3 are installed. *(M0.1)*
2. `user.name` and `user.email` are set. *(M0.2)*
3. `ui.conflict-marker-style` is `git`. *(M0.2)*
4. With `JJ_AGENT=1`, `ui.editor` is `true` and `ui.paginate` is `never`. *(M0.3)*
5. Without any agent variable, `ui.editor` is not `true`. *(M0.3)*

Then build the lab:

```bash
lab.sh reset
```

```text
# output
Lab ready:
  remote : /home/you/jj-lab/origin.git   (a bare Git repository standing in for GitHub)
  clone  : /home/you/jj-lab/app          (a colocated jj + Git repository — work here)
```

## Gate

Move on to Module 1 when `check.sh setup` prints **All checks passed** and
`lab.sh reset` prints **Lab ready**. If criterion 4 or 5 fails, the scope is in the wrong
place: compare your `50-agents.toml` with the one in Step 3 line by line. If criterion 1 fails
for Git, upgrade Git before continuing; jj's fetch and push will fail with older versions.
