# Appendix C — Sources and version notes

## Versions verified (September 26, 2026)

| Tool | Version | How it was verified |
|---|---|---|
| Jujutsu (jj) | 0.45.1 (released 2026-09-03) | Every command in the course was run; all lab scripts and checks pass with reference solutions |
| Git | 2.43.0 | Lab runs |
| Claude Code | 2.1.283 | `claude plugin validate`, `claude plugin marketplace add`, `claude plugin install`, `claude plugin details`; hook input fields read from the shipped binary |
| OpenAI Codex CLI | 0.157.1 | `codex sandbox` (sandbox behavior), `codex execpolicy check` (rules), `codex plugin marketplace add` / `plugin add` / `plugin list`, `codex mcp list`; plugin, hook, and MCP loading read from source at commit e72da2b |
| Kiro | IDE 1.1.70, CLI 2.24.0 | Documentation only (kiro.dev, retrieved 2026-09-26); statements marked *(documented)* |
| Node.js | 22.22.2 | Plugin tests |

## What is coming (announced, not released)

From the jj changelog's *Unreleased* section on 2026-09-25, expected in 0.46:

- `jj workspace add --colocate` will create a real **Git worktree** for a workspace, so Git commands
  (and Git-assuming tools) will work inside secondary workspaces. `jj workspace forget` will remove it.
- A new `jj workspace remove` command.
- `jj git push` to several remotes at once.
- Minimum Git version rises to 2.42.
- `jj split` will use a single editor session for both descriptions (the non-interactive
  `jj split -m <msg> <paths>` form taught here is unaffected, but recheck after upgrading).

When 0.46 ships, the Codex writable-root advice in Module 5 may change for colocated secondary
workspaces; rerun `codex-jj --probe` after upgrading.

## Primary sources

**Jujutsu**
- Documentation (moved to this domain in 0.36): <https://docs.jj-vcs.dev/latest/>
- CLI reference: <https://docs.jj-vcs.dev/latest/cli-reference/>
- Configuration, including conditional scopes: <https://docs.jj-vcs.dev/latest/config/>
- Working copy and stale workspaces: <https://docs.jj-vcs.dev/latest/working-copy/>
- Operation log and concurrency: <https://docs.jj-vcs.dev/latest/operation-log/>, <https://docs.jj-vcs.dev/latest/technical/concurrency/>
- Divergent changes: <https://docs.jj-vcs.dev/latest/guides/divergence/>
- Git compatibility and colocation: <https://docs.jj-vcs.dev/latest/git-compatibility/>
- Changelog: <https://github.com/jj-vcs/jj/blob/v0.45.1/CHANGELOG.md>

**Claude Code**
- Plugins and plugin reference: <https://code.claude.com/docs/en/plugins>, <https://code.claude.com/docs/en/plugins-reference>
- Marketplaces: <https://code.claude.com/docs/en/plugin-marketplaces>
- Skills: <https://code.claude.com/docs/en/skills>
- Hooks (including WorktreeCreate/WorktreeRemove): <https://code.claude.com/docs/en/hooks>
- Permissions: <https://code.claude.com/docs/en/permissions>
- Worktrees: <https://code.claude.com/docs/en/worktrees>

**OpenAI Codex**
- Source: <https://github.com/openai/codex>
- Configuration, MCP, rules, hooks, plugins, skills, AGENTS.md, sandbox: <https://learn.chatgpt.com/docs/> (developers.openai.com/codex redirects there)
- Plugin build guide: <https://developers.openai.com/plugins/build/plugins>

**Kiro**
- MCP configuration: <https://kiro.dev/docs/mcp/configuration/>
- Powers: <https://kiro.dev/docs/powers/>, <https://kiro.dev/docs/powers/create/>
- Skills: <https://kiro.dev/docs/skills/>
- Steering: <https://kiro.dev/docs/steering/>
- Hooks: <https://kiro.dev/docs/hooks/>
- Custom agents: <https://kiro.dev/docs/custom-agents/configuration-reference/>
- Permissions: <https://kiro.dev/docs/permissions/>
- Changelog: <https://kiro.dev/changelog/>

**Open standards**
- Agent Skills: <https://agentskills.io/specification>
- Agent Plugins: <https://agent-plugins.org/>
- Model Context Protocol: <https://modelcontextprotocol.io/>

## Findings measured in this course that go beyond the documentation

- **Codex sandbox and jj.** Under `workspace-write`, `jj commit` in a colocated repository fails
  writing `.git/objects`; in a secondary workspace it also fails writing the main workspace's `.jj/repo`.
  Adding those as writable roots fixes it; a relative root in `.codex/config.toml` resolves against the
  `.codex` folder. (Module 5.4)
- **Codex Agent Plugins MCP servers start in the plugin folder** (`codex mcp list` shows `Cwd`), so MCP
  tools must take an explicit workspace path. (Module 6.4)
- **Undo rewinds files on disk**: undoing a snapshot operation removes the snapshotted edits from the
  directory (they remain in the operation log). (Module 4.3)
- **Re-describing another workspace's parent does not make it stale**; rebasing or squashing content
  does. (Module 3.5)
- **Squash between two described changes** fails without a terminal, or concatenates descriptions when
  the editor is `true`. (Module 2.3)
- **A template quirk:** in some states in jj 0.45.1, asking a commit in a `-T` template which
  workspaces have it checked out (the `working_copies` template keyword) returned an empty list,
  while the `working_copies()` revset from Module 3 was correct. The plugin's MCP server therefore
  reads that information from `jj workspace list` instead.

## Community work referenced

- Anthony Panozzo, "Avoid Losing Work with Jujutsu (jj) for AI Coding Agents" (2025-11-22) — uses the
  removed `jj obslog`; use `jj evolog`.
- Slava Kurilyak, "Parallel Claude Code with Jujutsu" (2025-07-22) — one workspace per agent.
- jj-hunk (<https://github.com/laulauland/jj-hunk>) — programmatic hunk selection for split/squash,
  listed in jj's community tools as useful for AI agents.
- Earlier jj MCP servers (keanemind/jj-mcp-server, Cyberistic/jj-mcp-server) exist but predate
  jj 0.45 syntax changes or wrap a different workspace tool; the course's server is written against 0.45.
