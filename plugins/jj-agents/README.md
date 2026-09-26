# jj-agents

Jujutsu (jj) version control for teams of AI coding agents, packaged once for
**Claude Code**, **OpenAI Codex**, and **Kiro**.

| Component | What it does | Claude Code | Codex | Kiro |
|---|---|---|---|---|
| Skill `jj-multi-agent` | Teaches the agent the jj workflow, one-workspace-per-agent, integration, and recovery | yes | yes | yes |
| MCP server `jj` | 13 workspace-aware jj tools with JSON output; no push/undo/abandon | yes (`.mcp.json`) | yes (`mcp.json`) | yes (`mcp.json`) |
| Hook: git-write guard | Blocks `git commit`, `git push`, `git add`, … in jj repositories and names the jj equivalent | yes | yes | — |
| Hook: session start | Repairs a stale workspace and tells the agent which workspace it is in | yes | yes | — |
| Hooks: WorktreeCreate / WorktreeRemove | Make `claude --worktree`, `isolation: worktree` subagents, and `/batch` create jj workspaces | yes | — | — |
| `templates/` | AGENTS.md, Claude settings, Codex rules and `codex-jj` launcher, Kiro steering / agent / permissions | copy by hand | copy by hand | copy by hand |

Requirements: jj 0.45+, git 2.41+, Node.js 18+.

## Layout

```
jj-agents/
├── plugin.json                  Agent Plugins v1 manifest (read by Codex and Kiro)
├── .claude-plugin/plugin.json   Claude Code manifest
├── skills/jj-multi-agent/       SKILL.md + references/ (shared by all hosts)
├── mcp.json                     Agent Plugins MCP config (Codex, Kiro): runs `jj-agents-mcp`
├── .mcp.json                    Claude Code MCP config: runs mcp/server.mjs from the plugin
├── mcp/                         the MCP server (dependency-free Node.js) and its package.json
├── hooks/hooks.json             Claude Code hooks
├── hooks/codex-hooks.json       Codex hooks (referenced from plugin.json → extensions."com.openai")
├── hooks/*.mjs                  hook scripts
├── templates/                   per-host configuration to copy into repositories
└── tests/                       mcp-smoke.mjs, hooks-test.mjs
```

## Install

Run the install commands from the folder that contains `.claude-plugin/marketplace.json` and
`plugins/` (the course folder); run the test commands from this plugin folder.

First, for Codex and Kiro, put the MCP server's command on your PATH (Claude Code runs it from
the plugin folder and does not need this):

```bash
npm install -g --install-links ./plugins/jj-agents/mcp     # provides `jj-agents-mcp`
```

**Claude Code** (from the folder that contains `.claude-plugin/marketplace.json`):

```bash
claude plugin marketplace add ./
claude plugin install jj-agents@jj-agents-course
claude plugin details jj-agents@jj-agents-course
# or, for a one-off session:  claude --plugin-dir ./plugins/jj-agents
```

**Codex** (same folder; Codex reads Claude's marketplace file):

```bash
codex plugin marketplace add ./
codex plugin add jj-agents@jj-agents-course
codex plugin list
codex mcp list          # shows the plugin's `jj` server
```

Then start Codex and review the plugin's hooks with `/hooks` (Codex runs plugin hooks only after
you trust them). The plugin does not change Codex's sandbox: under the default `workspace-write`
mode, jj cannot write to `.git` (colocated repositories) or to the main workspace's `.jj`
(secondary workspaces). Launch Codex with `templates/codex/codex-jj`, which adds those as writable
roots.

**Kiro**: open the Powers panel → *Add Custom Power* → *Import power from a folder* → select
`plugins/jj-agents`. Kiro activates the power when a request mentions one of its keywords
(`jj`, `jujutsu`, `workspace`, …).

## Test

```bash
node tests/hooks-test.mjs
node tests/mcp-smoke.mjs /absolute/path/to/a/jj/workspace
claude plugin validate .
```

## Security notes

The git-write guard and the permission templates are guidance plus friction, not a sandbox:
an agent can still reach Git through scripts or `sh -c`. The MCP server runs jj with `execFile`
(no shell), requires an absolute `workspace` path, validates names and revsets, and exposes no
remote-publishing or history-rewinding operation.
