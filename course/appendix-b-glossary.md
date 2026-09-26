# Appendix B — Glossary

Terms are listed alphabetically, with the module where each is taught.

| Term | Meaning | Module |
|---|---|---|
| **Abandon** | `jj abandon <revset>`: remove changes from visible history; their children are rebased onto their parents, and the abandoned commits stay recoverable from the operation log. | 4 |
| **Agent mode** | This course's name for jj settings (no editor, no pager, no color) that apply only when `JJ_AGENT`, `CLAUDECODE`, or `CODEX_THREAD_ID` is set, via a conditional `[[--scope]]` in `~/.config/jj/conf.d/50-agents.toml`. | 0 |
| **Agent Plugins** | An open plugin specification (agent-plugins.org, v1.0.0): root `plugin.json` with a `$schema`, `skills/`, `mcp.json`, and vendor `extensions`. Read by Kiro (Powers) and Codex. | 6 |
| **Agent Skills** | An open standard (agentskills.io) for skills: a folder with `SKILL.md` whose front matter has `name` and `description`. Implemented by Claude Code, Codex, and Kiro. | 6 |
| **AGENTS.md** | A Markdown file of instructions for coding agents at a repository's root. Read by Codex and Kiro; Claude Code imports it from `CLAUDE.md`. | 5 |
| **Bookmark** | jj's name for a Git branch: a named pointer to a change. Does not move when you create new changes. | 2 |
| **Change** | jj's unit of work: a commit plus its identity across rewrites. | 1 |
| **Change ID** | The stable identifier of a change (letters k–z), kept across rewrites. | 1 |
| **Colocated repository** | A repository with both `.jj/` and `.git/` sharing one working directory; the default for `jj git init` / `jj git clone` since jj 0.34. | 1 |
| **Commit ID** | The hash of one exact version of a change (the same hash Git uses). Changes on every rewrite. | 1 |
| **Conditional scope** | A `[[--scope]]` block in jj configuration that applies only when its `--when.*` conditions hold. | 0 |
| **Conflict (first-class)** | A conflict recorded inside a commit instead of blocking the operation. Marked `(conflict)` / `×`; descendants inherit it until resolved. | 3 |
| **Conflict markers** | The `<<<<<<<` / `\|\|\|\|\|\|\|` / `=======` / `>>>>>>>` lines jj writes into a conflicted file (Git style, as configured in this course). The section after `\|\|\|\|\|\|\|` is the base. | 3 |
| **Custom agent (Kiro)** | A named Kiro configuration (`.kiro/agents/<name>.json`) with its own prompt, tools, resources, and permissions. | 5 |
| **Divergent change** | A change ID with two or more visible versions, created by concurrent rewrites of the same change. Shown as `<id>/0`, `<id>/1`. | 4 |
| **`@git`** | In `jj bookmark list --all`, the colocated Git repository's copy of a bookmark (its Git branch). Usually safe to ignore. | 2 |
| **Evolution log (evolog)** | Every recorded version of one change, with the operation that produced each. `jj evolog`. | 4 |
| **Fileset** | jj's path-pattern language (for example `glob:"src/**"`), used by `snapshot.auto-track` and file arguments. | 4 |
| **Hidden commit / version** | A commit that is no longer visible in `jj log` (for example the previous version of a rewritten change, shown as `<id>/1`), but still exists and can be restored. | 4 |
| **Hook** | A command a host runs at a defined event (session start, before a tool call, worktree creation), receiving the event as JSON on standard input; exit code 2 blocks in Claude Code and Codex. | 5, 6 |
| **Immutable change** | A change jj refuses to rewrite: by default `trunk()`, tags, and untracked remote bookmarks and their ancestors. Marked `◆`. | 1 |
| **Manifest** | The JSON file naming a plugin and its parts: `plugin.json` (Agent Plugins) or `.claude-plugin/plugin.json` (Claude Code). | 6 |
| **Marketplace** | A catalog of plugins a host can add and install from; `.claude-plugin/marketplace.json` is read by Claude Code and Codex. | 6 |
| **MCP (Model Context Protocol)** | An open protocol through which a host gives a model tools provided by a separate program, the MCP server. | 5, 6 |
| **JSON-RPC** | A simple request/response protocol encoded as JSON messages; MCP uses it. | 6 |
| **MCP server (stdio)** | An MCP server the host starts as a child process, speaking JSON-RPC over standard input/output ("stdio"), one message per line. | 6 |
| **Operation** | One recorded change to the whole repository state (visible changes, bookmarks, each workspace's `@`), with the workspace, user, and command that caused it. | 4 |
| **Operation log** | The history of operations, shared by all workspaces. `jj op log`. | 4 |
| **Permission rule** | A host rule that allows, asks about, or denies a tool call based on its text (Claude Code `permissions`, Codex `.rules`, Kiro `permissions`). | 5 |
| **Power (Kiro)** | Kiro's name for a plugin; since August 2026 in the Agent Plugins format. | 6 |
| **Progressive disclosure** | Loading instructions in stages: only a skill's name and description up front; the body when relevant; referenced files only when needed. | 6 |
| **Revset** | jj's expression language for selecting changes (`@`, `trunk()..@`, `files("x")`, …). | 1 |
| **Sandbox (Codex)** | The OS-level restriction on what Codex's commands may touch; `workspace-write` allows the project but keeps `.git`, `.codex`, `.agents` read-only. | 5 |
| **Skill** | A folder with `SKILL.md` instructions that a host loads when a task matches its description. | 6 |
| **Starlark** | A small Python-like configuration language; Codex `.rules` files are written in it. | 5 |
| **Snapshot** | jj recording the working directory's files into `@`, at the start of almost every command. | 1 |
| **Stale workspace** | A workspace whose working-copy change was rewritten by another workspace in a way that changes its files; repaired with `jj workspace update-stale`. | 3 |
| **Steering file (Kiro)** | A Markdown instruction file in `.kiro/steering/`, with front matter such as `inclusion: always`. | 5 |
| **Template** | jj's output expression language, used with `-T`; `json(...)` serializes values. | 2 |
| **Tracked bookmark** | A local bookmark linked to its remote counterpart (`name@origin`), updated by fetch and push. | 2 |
| **trunk()** | A revset alias for the remote's main branch (here `main@origin`). | 1 |
| **workspace-write** | Codex's default sandbox mode for projects: commands may write inside the project, except the protected `.git`, `.codex`, and `.agents` folders. | 5 |
| **Working-copy change (`@`)** | The change that holds the files currently in a workspace's directory. | 1 |
| **Workspace** | An additional working directory attached to the same repository, with its own `@` (`<name>@`) and shared history, bookmarks, and operation log. | 3 |
| **Writable root (Codex)** | An extra directory Codex's `workspace-write` sandbox allows writing to; an explicit root overrides the `.git` protection. | 5 |
