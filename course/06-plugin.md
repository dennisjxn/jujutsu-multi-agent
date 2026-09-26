# Module 6 — One plugin for three hosts

## Why this matters

In Module 5 you copied configuration into one repository by hand. That does not scale to a team,
to many repositories, or to keeping three hosts in step when the protocol changes. Each host now has
a **plugin** format: a folder that bundles instructions, tools, and hooks, installed once and updated
like any other package. In 2026 those formats converged enough that one folder can serve all three,
if you know exactly which file each host reads. This module takes the course's plugin, `jj-agents`,
apart; has you extend it; and installs and validates it in each host.

## Objectives

After this module you will be able to:

- **M6.T** — Starting from the course's `jj-agents` plugin, produce your own copy with a team
  conventions reference and an additional MCP tool, such that `check.sh m6 <your-plugin>` passes,
  and install it in every host you have.
- **M6.1** — Explain the Agent Plugins v1 and Claude Code plugin manifests, and state which files each
  host reads from a plugin folder that contains both.
- **M6.2** — Write a portable skill (`SKILL.md`) whose front matter every host accepts and whose body
  uses progressive disclosure.
- **M6.3** — Package an MCP server and configure it for each host, including how each host sets the
  server's working directory and expands path variables.
- **M6.4** — Package hooks for Claude Code and Codex, including Claude Code's `WorktreeCreate` and
  `WorktreeRemove`, and test hook scripts without a host.
- **M6.5** — Install the plugin in Claude Code, Codex, and Kiro, and validate it with each host's tools.

## Prerequisites

Module 5 (M5.1–M5.4): the three control layers and each host's configuration. You need Node.js 18+
(Module 0). Claude Code and Codex CLIs are optional; their validation steps are skipped if missing.

---

## 6.1 Four building blocks

A plugin is a folder that bundles some of these:

- A **skill** is a folder containing a `SKILL.md` file: Markdown instructions with a short header
  (front matter) giving a `name` and a `description`. The host shows the model only the name and
  description of every installed skill; when a task matches the description, the model loads the
  full `SKILL.md`, and it opens extra files the skill points to only if it needs them. That staged
  loading is called **progressive disclosure**: dozens of skills can be installed without filling
  the model's context. Skills follow an open standard, **Agent Skills** (agentskills.io), which all
  three hosts implement.
- An **MCP server** is a program that offers tools to an agent over the **Model Context Protocol**, an
  open protocol for connecting models to tools. A *stdio* server is started by the host as a child
  process and talks JSON-RPC over standard input and output. Each tool has a name, a description, and
  a JSON Schema for its arguments.
- A **hook** is a command the host runs at a defined moment (session start, before a tool call, …),
  with the event's details as JSON on standard input. A hook can add context or, for some events,
  block the action.
- A **manifest** is the JSON file that names the plugin and tells the host where its parts are.

## 6.2 Two manifests, three hosts *(builds M6.1)*

Open `$JJ_COURSE/plugins/jj-agents/`:

```text
jj-agents/
├── plugin.json                  Agent Plugins v1 manifest          → Codex, Kiro
├── .claude-plugin/plugin.json   Claude Code manifest               → Claude Code
├── skills/jj-multi-agent/       SKILL.md + references/             → all three
├── mcp.json                     Agent Plugins MCP configuration    → Codex, Kiro
├── .mcp.json                    Claude Code MCP configuration      → Claude Code
├── mcp/server.mjs               the MCP server itself
├── hooks/hooks.json             Claude Code hooks                  → Claude Code
├── hooks/codex-hooks.json       Codex hooks (named in plugin.json) → Codex
├── hooks/*.mjs                  hook scripts
├── templates/                   Module 5's files
└── tests/                       smoke tests
```

**Agent Plugins v1** (agent-plugins.org) is an open specification for a portable plugin: a root
`plugin.json` whose `$schema` identifies the version, a `skills/` folder, and an `mcp.json`.
Host-specific additions go under `extensions`, keyed by a reverse-domain name. Kiro adopted it for
**Powers** (Kiro's name for plugins) in August 2026; Codex reads it too.

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
  "name": "jj-agents",
  "version": "1.0.0",
  "description": "Jujutsu (jj) version control for teams of coding agents: …",
  "author": { "name": "jj-agents course" },
  "license": "MIT",
  "keywords": ["jj", "jujutsu", "version control", "vcs", "workspace", "multi-agent", …],
  "extensions": {
    "com.openai": { "hooks": "./hooks/codex-hooks.json" }
  }
}
```

The `name` must be lowercase letters, digits, dots, and hyphens. Kiro uses `keywords` to decide when to
activate the power, so list the words people actually type ("jj", "jujutsu", "workspace").
`extensions."com.openai"` is read only by Codex.

**Claude Code's manifest** lives at `.claude-plugin/plugin.json`. Only `name` is required, and the
standard folders (`skills/`, `hooks/hooks.json`, `.mcp.json`) are discovered automatically.

Which files does each host read from this folder? Verified against Claude Code 2.1.283 (with
`claude plugin details`) and Codex 0.157.1 (with `codex plugin list` and `codex mcp list`); Kiro from
its documentation:

| Host | Manifest it uses | Reads | Ignores |
|---|---|---|---|
| Claude Code | `.claude-plugin/plugin.json` | `skills/`, `.mcp.json`, `hooks/hooks.json` | `plugin.json`, `mcp.json` |
| Codex | `plugin.json` (first in its search order) | `skills/`, `mcp.json`, hooks named in `extensions."com.openai"` | `.claude-plugin/`, `.mcp.json`, `hooks/hooks.json` |
| Kiro *(documented)* | `plugin.json` | `skills/`, `mcp.json` | everything else |

Codex's search order for a manifest is: root `plugin.json` *with the Agent Plugins `$schema`*, then
`.codex-plugin/plugin.json`, then `.claude-plugin/plugin.json`. So Codex can install a plain Claude
Code plugin too; here the Agent Plugins manifest takes precedence. Codex can also read Claude Code's
**marketplace** file (`.claude-plugin/marketplace.json`), which is why one marketplace serves both.

Why two MCP files and two hooks files instead of one? Because the hosts disagree on details that
matter, covered next.

## 6.3 The skill *(builds M6.2)*

Open `skills/jj-multi-agent/SKILL.md`. Its front matter:

```yaml
---
name: jj-multi-agent
description: Version control with Jujutsu (jj) when one or more AI coding agents work in the same repository. Use whenever the repository has a .jj directory, the user mentions jj or Jujutsu, or the task involves committing, branching, rebasing, resolving conflicts, pushing, undoing, or running several agents in parallel (workspaces). Covers …
license: MIT
compatibility: Requires jj 0.45 or newer and git 2.41 or newer on PATH. …
metadata:
  version: "1.0.0"
  jj-version: "0.45"
---
```

**Portability rules:**

- Use only the six fields of the Agent Skills standard: `name`, `description`, `license`,
  `compatibility`, `metadata`, and the experimental `allowed-tools`. Claude Code accepts more
  (`argument-hint`, `model`, `disable-model-invocation`, …), but uploading a skill with those fields
  to claude.ai fails, Codex ignores them, and Kiro documents only the standard ones. This skill uses
  five and omits `allowed-tools` because the hosts treat it differently.
- `name` must match the folder name (up to 64 characters: lowercase letters, digits, single hyphens).
- `description` (up to 1,024 characters) is what the model sees *before* deciding to load the skill.
  Write it as a trigger: what the skill is for, and the concrete situations that should activate it
  ("the repository has a .jj directory", "committing, branching, rebasing…"). A vague description is
  the most common reason a skill never fires.

**Progressive disclosure in the body.** `SKILL.md` stays short (about 100 lines): the five facts that
change how an agent works, the non-interactive rules, the per-task loop, the workspace rule, a
symptom → action table, and the "never" list. Detail lives in `references/` and is named from the
body with the situation that warrants opening it:

| Reference | Opened when |
|---|---|
| `references/commands.md` | the agent needs an exact flag |
| `references/multi-agent.md` | provisioning workspaces, integrating, resolving conflicts |
| `references/recovery.md` | something looks wrong (stale, divergent, destroyed content, secret) |
| `references/hosts.md` | host-specific setup questions |

Each reference repeats nothing from `SKILL.md` that the agent already has, and every command in them
was run against jj 0.45.1.

## 6.4 The MCP server *(builds M6.3)*

Agents can run jj through their shell tool, so why an MCP server? Three reasons:

- **Structured output.** Tools return JSON built from jj templates (Module 2.6), so the agent doesn't
  parse human-oriented text.
- **A smaller blast radius.** The server exposes 13 tools: status, log, diff, describe, commit, new,
  workspace add/list/forget, update-stale, op log, conflicts, and bookmark set. No push, no undo, no
  abandon, no operation-log rewrites. Where shell access is restricted (for example a Kiro agent whose
  permissions deny `shell`), the agent can still do its jj work, and only that.
- **Workspace-correct by construction.** Every tool takes an explicit absolute `workspace` path.

That last point comes from a measured difference between hosts. A stdio server is started by the host
in *some* working directory, and the hosts don't agree which. Here is what `codex mcp list` prints once
the plugin is installed in Codex (you will install it in 6.6; before that, the command reports no
servers):

```text
# output (after installing the plugin in Codex)
Name  Command        Args  Env                                   Cwd                                                     Status   Auth
jj    jj-agents-mcp  -     PLUGIN_DATA=*****, PLUGIN_ROOT=*****  ~/.codex/plugins/cache/jj-agents-course/jj-agents/1.0.0  enabled  Unsupported
```

Codex starts Agent Plugins servers **in the plugin's own folder** (its default `cwd`), not in your
project. A server that assumed "the current directory is the repository" would operate on the plugin
folder. So `server.mjs` never trusts its working directory: each call names its workspace, and the
server checks it with `jj workspace root`.

Other design choices worth copying, visible in `mcp/server.mjs`:

- jj runs through `execFile` (no shell), so arguments are never interpreted by a shell.
- Every call adds `--no-pager --color=never` and sets `JJ_EDITOR=true`.
- Names and revsets are validated (`^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$` for names; revsets may not start
  with `-`, so they can't be mistaken for flags).
- The stale-workspace error is detected and the message tells the agent to call `jj_update_stale`.
- The server is dependency-free (Node's standard library only), so there is nothing to install or audit
  beyond one file.

### Inside `server.mjs`

You will add a tool in the performance task, so learn the file's shape now. It is one file of about
430 lines, in four parts:

| Lines (approx.) | Part | What to know |
|---|---|---|
| 28–75 | `runJj(cwd, args)`, `resolveWorkspace(input)`, `jj(root, args)` | `resolveWorkspace` validates the `workspace` argument and returns the workspace root; `jj(root, args)` runs `jj --no-pager --color=never <args>` there and returns its output, or throws a `ToolError` whose message the agent sees. |
| 80–145 | templates and validators | `LOG_TEMPLATE`, `checkName`, `checkRevset`, `checkMessage`; `WS` is the JSON Schema for the `workspace` argument, reused by every tool. |
| 150–365 | `const tools = [ … ]` | One object per tool: `name`, `description`, `inputSchema` (JSON Schema), optional `annotations`, and `run: async (a) => <string>`. `a` holds the arguments the model sent. Whatever string `run` returns is the tool result. |
| 366– | JSON-RPC plumbing | Answers `initialize`, `tools/list`, and `tools/call`; you never need to touch it. |

A complete read-only tool, `jj_op_log`, looks like this (abridged):

```js
{
  name: "jj_op_log",
  description: "Show recent operations (the repository's undo history), newest first, as JSON: …",
  inputSchema: { type: "object",
                 properties: { workspace: WS, limit: { type: "integer", minimum: 1, maximum: 100, default: 10 } },
                 required: ["workspace"] },
  annotations: { readOnlyHint: true },
  run: async (a) => {
    const root = await resolveWorkspace(a);
    const t = 'json(id.short(12)) ++ "\\t" ++ json(time.end()) ++ …';
    const out = await jj(root, ["op", "log", "--no-graph", "-n", String(a.limit ?? 10), "-T", t]);
    return JSON.stringify(out.split("\n").filter(Boolean).map(/* parse each line */), null, 2);
  },
},
```

About the backslashes in `"\\t"` and `"\\n"`: in JavaScript source, `\\` stands for one backslash
character, so jj's template language receives the escape sequences `"\t"` and `"\n"` and turns them
into a tab and a newline itself. (A single backslash would also work, because JavaScript would insert
a real tab or newline and jj accepts those inside a template string; the doubled form keeps the
template readable when it is logged or printed in an error.) When you add a tool, copy the pattern.

### Practice 6.4

With the lab reset (`lab.sh reset`), use `mcp-call.mjs` (it speaks MCP to a server the way a host
does) to answer each question, predicting the result first:

```bash
S="node $JJ_COURSE/plugins/jj-agents/mcp/server.mjs"
node "$JJ_COURSE/course/labs/mcp-call.mjs" $S -- call jj_status '{"workspace":"jj-lab/app"}'
node "$JJ_COURSE/course/labs/mcp-call.mjs" $S -- call jj_log '{"workspace":"'${JJ_LAB:-$HOME/jj-lab}'/app","revset":"trunk()..@"}'
node "$JJ_COURSE/course/labs/mcp-call.mjs" $S -- call jj_bookmark_set '{"workspace":"'${JJ_LAB:-$HOME/jj-lab}'/app","name":"--help"}'
```

<details><summary>Feedback</summary>

1. An error: `` `workspace` must be an absolute path, got: jj-lab/app ``. `resolveWorkspace` refuses
   relative paths, because the server's own working directory is not the agent's (the `Cwd` point
   above).
2. A JSON array with one object per change in your stack (here only the empty `@`), including
   `working_copy_of: ["default"]`.
3. An error from `checkName`: a name starting with `-` could be read by jj as a flag.

</details>

### Per-host configuration

**Claude Code** (`.mcp.json`) runs the server straight from the installed plugin, using the
`${CLAUDE_PLUGIN_ROOT}` variable, which Claude Code replaces with the plugin's install folder:

```json
{ "mcpServers": { "jj": { "command": "node", "args": ["${CLAUDE_PLUGIN_ROOT}/mcp/server.mjs"] } } }
```

Claude Code names the tools `mcp__plugin_jj-agents_jj__<tool>`, which is what the permission rule
`mcp__plugin_jj-agents_jj__*` from Module 5 matches.

**Codex and Kiro** (`mcp.json`, Agent Plugins format) require a `$schema` and a `type` per server, and
Codex accepts only a bare command name or a `./` path inside the plugin as `command`:

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json",
  "mcpServers": { "jj": { "type": "stdio", "command": "jj-agents-mcp", "args": [] } }
}
```

Codex also expands `${PLUGIN_ROOT}` in `args`, so `"command": "node", "args": ["${PLUGIN_ROOT}/mcp/server.mjs"]`
would work in Codex. Kiro's documentation shows no plugin-root variable, so this plugin uses a
bare command that works in both: `jj-agents-mcp`, installed on your PATH from the plugin's `mcp/`
folder:

```bash
npm install -g --install-links "$JJ_COURSE/plugins/jj-agents"/mcp
which jj-agents-mcp
```

(`--install-links` makes npm *copy* the folder; without it, npm links to it and the command breaks if
you move the course folder. If `npm install -g` fails with a permissions error, your npm global folder
is system-owned: either set a user prefix once with `npm config set prefix ~/.local` (a persistent npm setting; it
then installs into `~/.local/bin`, which you put on your PATH in Module 5), add `--prefix ~/.local`
to this one command, or run it with `sudo`.)

If you use only Claude Code, you can skip this install: Claude Code starts the server from the plugin
folder. In the tests below, replace `jj-agents-mcp` with
`node "$JJ_COURSE/plugins/jj-agents/mcp/server.mjs"`, which runs the same program.

### Test it without a host

`course/labs/mcp-call.mjs` speaks MCP to any stdio server exactly as a host does:

```bash
node "$JJ_COURSE/course/labs/mcp-call.mjs" jj-agents-mcp -- list
node "$JJ_COURSE/course/labs/mcp-call.mjs" jj-agents-mcp -- call jj_log '{"workspace":"'${JJ_LAB:-$HOME/jj-lab}'/app","revset":"@"}'
node "$JJ_COURSE/plugins/jj-agents/tests/mcp-smoke.mjs" "${JJ_LAB:-$HOME/jj-lab}/app"
```

```text
# output (last command, abridged)
PASS  initialize negotiates protocol
PASS  tools/list returns the 13 core tools  — jj_status, jj_log, jj_diff, …
PASS  jj_status succeeds  — The working copy has no changes.
PASS  jj_log returns JSON for @
PASS  jj_workspace_list returns JSON
PASS  jj_op_log returns JSON
PASS  relative workspace is rejected
PASS  unsafe bookmark name is rejected

All checks passed
```

## 6.5 The hooks *(builds M6.4)*

The plugin ships four hook scripts (Node.js, no dependencies):

| Script | Event | Behavior |
|---|---|---|
| `guard-git.mjs` | before a shell command (`PreToolUse`, tool `Bash`) | In a jj repository, blocks Git write commands (including `git -C . commit`, `cd x && git push`, env-prefixed forms) and tells the agent the jj equivalent. Read-only Git commands pass. |
| `session-start.mjs` | session start (`SessionStart`) | If the session opens in a jj workspace: repairs staleness, then prints the workspace name, `@`, the other agents' workspaces, and the key rules. Hosts add this text to the model's context. |
| `worktree-create.mjs` | Claude Code `WorktreeCreate` | Creates a jj workspace in `../<repo>-ws/claude-<name>` and prints its path. |
| `worktree-remove.mjs` | Claude Code `WorktreeRemove` | Forgets that workspace and deletes its folder; the agent's commits stay in history. |

Both Claude Code and Codex hooks receive the event as JSON on standard input (for a shell command:
`{"tool_name":"Bash","tool_input":{"command":"…"},"cwd":"…"}`) and use the same exit-code convention:
**exit 0** continues, **exit 2** blocks and shows the script's standard error to the model. That is why
one guard script serves both.

**Claude Code** (`hooks/hooks.json`) references scripts with `${CLAUDE_PLUGIN_ROOT}`:

```json
"PreToolUse": [
  { "matcher": "Bash",
    "hooks": [ { "type": "command", "command": "node \"${CLAUDE_PLUGIN_ROOT}/hooks/guard-git.mjs\"", "timeout": 10 } ] }
],
"WorktreeCreate": [
  { "hooks": [ { "type": "command", "command": "node \"${CLAUDE_PLUGIN_ROOT}/hooks/worktree-create.mjs\"", "timeout": 60 } ] }
]
```

`WorktreeCreate` has a strict contract: the input includes the requested `name`; the script must print
**only** the new directory's absolute path on standard output (diagnostics go to standard error), and
any non-zero exit aborts. The script puts workspaces *outside* the repository for the reason you
know from Module 3 (every tool except jj would see a nested copy of the project) plus one from
Claude Code: its
documentation says a hook-created directory without Git metadata is accepted only when no Git
repository contains it, and a colocated jj repository is a Git repository.

**Codex** (`hooks/codex-hooks.json`, named from `plugin.json`) uses the same JSON shape but a
separate file, for two reasons: `WorktreeCreate`/`WorktreeRemove` are Claude Code events that Codex
doesn't have, and Codex provides the plugin folder to hook commands as the environment variable
`$PLUGIN_ROOT` rather than substituting `${CLAUDE_PLUGIN_ROOT}` into the text:

```json
"PreToolUse": [
  { "matcher": "Bash",
    "hooks": [ { "type": "command", "command": "node \"$PLUGIN_ROOT/hooks/guard-git.mjs\"", "timeout": 10 } ] }
]
```

Codex runs a plugin's hooks only after you review and trust them in a session (`/hooks`).

**Kiro** is absent from this section on purpose. The Agent Plugins core has no hooks, and Kiro's hook
documentation (Module 5.5) leaves the blocking exit code unstated; Kiro relies on the permission rules
you configured.

### Test hooks without a host

```bash
node "$JJ_COURSE/plugins/jj-agents/tests/hooks-test.mjs"
```

```text
# output (abridged)
PASS  guard blocks: git commit -m x
PASS  guard blocks: cd sub && git commit -am 'y'
PASS  guard blocks: git -C . rebase main
…
PASS  guard allows: jj git push --bookmark x
PASS  guard allows: jj commit -m 'git commit message'
PASS  session-start prints orientation  — Jujutsu (jj) repository. You are in workspace "default" at …
PASS  WorktreeCreate prints one absolute path  — /tmp/…/repo-ws/claude-fix-login-bug
PASS  WorktreeCreate places workspace outside the repo
…
All checks passed
```

The test builds a throwaway jj repository and feeds each script the JSON a host would send. This is
the fastest way to develop hooks: no host, no model, no tokens.

## 6.6 Install and validate *(builds M6.5)*

The course folder has a marketplace file at `$JJ_COURSE/.claude-plugin/marketplace.json` listing
`plugins/jj-agents`. A **marketplace** is a catalog of plugins that a host can add and install from.

**Claude Code:**

```bash
cd "$JJ_COURSE"
claude plugin validate plugins/jj-agents
claude plugin marketplace add ./
claude plugin install jj-agents@jj-agents-course
claude plugin details jj-agents@jj-agents-course
```

```text
# output (last command, abridged)
jj for agent teams (jj-agents) 1.0.0
Component inventory
  Skills (1)  jj-multi-agent
  Hooks (4)  SessionStart, PreToolUse, WorktreeCreate, WorktreeRemove
  MCP servers (1)  jj
```

For a quick trial without installing: `claude --plugin-dir ./plugins/jj-agents`.

**Codex:**

```bash
codex plugin marketplace add ./
codex plugin add jj-agents@jj-agents-course
codex plugin list
codex mcp list
```

```text
# output (codex plugin list, marketplace header lines omitted)
PLUGIN                      STATUS              VERSION  SOURCE
jj-agents@jj-agents-course  installed, enabled  1.0.0    "$JJ_COURSE/plugins/jj-agents"
```

Codex copies the plugin into `~/.codex/plugins/cache/`; after you change your copy, run
`codex plugin add` again to refresh it. Start a session and use `/hooks` to trust the hooks.

**Kiro** *(documented)*: Powers panel (the lightning-bolt icon) → *Add Custom Power* →
*Import power from a folder* → choose `plugins/jj-agents`. Kiro reads `plugin.json`, `skills/`, and
`mcp.json`. Alternatively, copy just the skill to `~/.kiro/skills/jj-multi-agent/`; Kiro reads
standard skills there, and the custom agent from Module 5 lists that folder in its resources.

---

## Knowledge check

1. *(M6.1)* A plugin folder contains both `plugin.json` (with the Agent Plugins `$schema`) and
   `.claude-plugin/plugin.json`. Which manifest does Codex use?
   - a) `.claude-plugin/plugin.json`, because Codex is compatible with Claude Code plugins.
   - b) `plugin.json`, because it comes first in Codex's search order when it has the Agent Plugins `$schema`.
   - c) Both, merged.
   - d) Neither; Codex needs `.codex-plugin/plugin.json`.

2. *(M6.2)* You add `disable-model-invocation: true` to the skill's front matter. What is the portability
   consequence?
   - a) None; all hosts support it.
   - b) Claude Code honors it; uploading the skill to claude.ai fails; Codex and Kiro don't recognize it.
   - c) Every host rejects the skill.
   - d) Kiro honors it; Claude Code ignores it.

3. *(M6.2)* A skill never activates, although it is installed. What should you check first?
   - a) Whether its body is under 500 lines.
   - b) Whether its `description` names the concrete situations that should trigger it.
   - c) Whether it has a `license` field.
   - d) Whether its references are in Markdown.

4. *(M6.3)* An MCP tool that runs `jj status` in the server's current directory works in Claude Code
   but reports "There is no jj repo" in Codex. Why?
   - a) Codex doesn't pass environment variables to MCP servers.
   - b) Codex starts Agent Plugins servers with the plugin's folder as working directory.
   - c) jj isn't installed in Codex's sandbox.
   - d) Codex requires HTTP servers.

5. *(M6.4)* Your `WorktreeCreate` script prints `Created workspace in "…"` and then the path, both to
   standard output. What happens?
   - a) It works; Claude Code takes the last line.
   - b) Creation fails or uses a wrong path, because standard output must contain only the path.
   - c) Claude Code ignores the hook and creates a Git worktree.
   - d) The workspace is created inside the repository.

6. *(M6.4)* Why does the plugin need a separate Codex hooks file instead of reusing `hooks/hooks.json`?
   - a) Codex hooks use a different JSON structure entirely.
   - b) `hooks/hooks.json` contains Claude-only events and uses `${CLAUDE_PLUGIN_ROOT}` substitution;
      Codex supplies `$PLUGIN_ROOT` as an environment variable.
   - c) Codex doesn't support `PreToolUse`.
   - d) Codex hooks must be written in TOML.

### Answer key

1. **b.** Codex checks root `plugin.json` with the Agent Plugins `$schema` first. (a) is true only
   when there is no Agent Plugins manifest; (c) Codex uses one manifest, not a merge of both; (d) that is just one of the recognized locations.
   Reread 6.2.
2. **b.** It is a Claude Code extension field. (a), (c), (d) misstate each host. Reread 6.3.
3. **b.** The description is the only part the model sees before loading. (a) affects cost, not
   activation; (c) and (d) are irrelevant. Reread 6.3.
4. **b.** Verified with `codex mcp list`: `Cwd` is the plugin folder. (a), (c), (d) are false for this
   case. Reread 6.4.
5. **b.** The contract is "only the path on stdout". (a) is not the contract; (c) Claude Code reports
   the failure; (d) the location is decided by your script. Reread 6.5.
6. **b.** The JSON shape is the same; the events and the variable mechanism differ. (a) the shape is
   shared; (c) Codex has `PreToolUse`; (d) Codex also accepts JSON. Reread 6.5.

## Performance task

Build your own copy of the plugin and extend it:

1. Copy the plugin to a folder of your own:
   `mkdir -p ~/jj-plugin && cp -r "$JJ_COURSE/plugins/jj-agents" ~/jj-plugin/`. Keep the name
   `jj-agents` in both manifests. (If you rename it, change it in both, and remember that Claude Code
   tool names and the Module 5 permission rule `mcp__plugin_jj-agents_jj__*` contain the plugin name.) *(M6.1)*
2. Add `skills/jj-multi-agent/references/team.md` with at least two of your team's conventions
   (bookmark naming, workspace naming, which tests to run before `jj commit`), and add one line to
   `SKILL.md` saying when to open it. *(M6.2)*
3. Add an MCP tool `jj_evolog` to `mcp/server.mjs` that takes `workspace` and an optional `revision`
   (default `@`) and returns a JSON array with one object per version of the change. Use the template
   `json(self) ++ "\n"` with `jj evolog --no-graph`, and follow the pattern of `jj_op_log`. Note that
   for evolog, `json(self)` prints one object per version shaped `{"commit": {…}, "operation": {…}}`:
   the commit fields (`commit_id`, `description`, …) are inside `commit`. Run the jj command by hand
   first to see it. *(M6.3)*
4. Run both test scripts and `claude plugin validate` (if Claude Code is installed). *(M6.4, M6.5)*
5. Install your copy in every host you have, **replacing** the course's copy from 6.6 (two plugins
   named `jj-agents` would register every hook twice and clash on tool names):

   - Remove the course copy: `claude plugin uninstall jj-agents@jj-agents-course` and
     `codex plugin remove jj-agents@jj-agents-course` (for Kiro, remove the power in the Powers panel).
   - Point `jj-agents-mcp` at your server, since Codex and Kiro run that command:
     `npm install -g --install-links ~/jj-plugin/jj-agents/mcp`.
   - Claude Code and Codex install from a *marketplace*. Your plugin is already one level below
     `~/jj-plugin/` from step 1; create the folder with `mkdir -p ~/jj-plugin/.claude-plugin` and add
     the catalog file `~/jj-plugin/.claude-plugin/marketplace.json`:

   ```json
   {
     "name": "my-jj-plugins",
     "owner": { "name": "Your Name" },
     "description": "My team's jj plugins",
     "plugins": [ { "name": "jj-agents", "source": "./jj-agents", "description": "jj for agent teams" } ]
   }
   ```

   The marketplace `name` must differ from the course's (`jj-agents-course`). Then
   `claude plugin validate ~/jj-plugin`, `claude plugin marketplace add ~/jj-plugin`,
   `claude plugin install jj-agents@my-jj-plugins`; `codex plugin marketplace add ~/jj-plugin`,
   `codex plugin add jj-agents@my-jj-plugins`; in Kiro, *Import power from a folder* →
   `~/jj-plugin/jj-agents`. (For a one-session Claude Code trial, `claude --plugin-dir ~/jj-plugin/jj-agents`
   needs no marketplace.) *(M6.5)*

```bash
lab.sh reset                         # the MCP checks run against the lab repository
check.sh m6 ~/jj-plugin/jj-agents
```

<details><summary>Solution sketch for step 3 (open only after trying)</summary>

Add an entry to the `tools` array, before the closing `];`:

```js
{
  name: "jj_evolog",
  description: "Show every recorded version of one change (default @), newest first, as JSON.",
  inputSchema: { type: "object", properties: { workspace: WS, revision: { type: "string", default: "@" } }, required: ["workspace"] },
  annotations: { readOnlyHint: true },
  run: async (a) => {
    const root = await resolveWorkspace(a);
    const out = await jj(root, ["evolog", "--no-graph", "-r", checkRevset(a.revision, "@"), "-T", 'json(self) ++ "\\n"']);
    return JSON.stringify(out.split("\n").filter(Boolean).map((l) => {
      const e = JSON.parse(l);   // { commit: {...}, operation: {...} }
      return { commit_id: e.commit.commit_id.slice(0, 12), description: e.commit.description.split("\n")[0] };
    }), null, 2);
  },
},
```

</details>

## Gate

Move on to the capstone when `check.sh m6 <your-plugin>` passes and you scored at least 5 of 6 on
the knowledge check. If the `jj_evolog` checks fail, test the tool directly with
`node "$JJ_COURSE/course/labs/mcp-call.mjs" node <your-plugin>/mcp/server.mjs -- call jj_evolog '{"workspace":"'${JJ_LAB:-$HOME/jj-lab}'/app"}'`;
the error text is the server's message. If question 4 was wrong, reread 6.4: the same trap exists for
any MCP server you write for Codex.
