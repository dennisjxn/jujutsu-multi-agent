# Host-specific notes

## All hosts

- Set `JJ_AGENT=1` in the agent's environment so the user's jj config can switch to
  agent mode (no editor, no pager). Claude Code also sets `CLAUDECODE=1` and Codex sets
  `CODEX_THREAD_ID` in commands they run; a course-style config scope matches any of the three.
- Repository instructions live in `AGENTS.md` (read by Codex and Kiro; Claude Code reads
  `CLAUDE.md`, which can import it with a line containing `@AGENTS.md`).

## Claude Code

- Permission rules: allow `Bash(jj *)`; put `Bash(jj undo *)`, `Bash(jj op restore *)`,
  `Bash(jj git push *)` under `ask`; deny `Bash(git commit *)`, `Bash(git push *)` and other Git
  writes. Deny and ask rules are checked before allow rules and match any part of a compound
  command. Wrapped forms such as `git -C . commit` are not matched: rules are guidance plus
  friction, not a sandbox.
- MCP tools from this plugin are named `mcp__plugin_jj-agents_jj__<tool>`.
- Worktree features (`claude --worktree`, subagent `isolation: worktree`, `/batch`) call the
  plugin's `WorktreeCreate` hook, which creates `../<repo>-ws/claude-<name>` as a jj workspace.

## OpenAI Codex

- The default `workspace-write` sandbox makes `.git` read-only. In a colocated repository jj
  must write Git objects there, and a secondary workspace stores its data in the main
  workspace's `.jj/` and `.git/`. Launch with `codex-jj` (adds those as writable roots) or
  pass `-c 'sandbox_workspace_write.writable_roots=["<main>/.git","<main>/.jj"]'`.
- Command rules (`.codex/rules/*.rules`) can forbid Git write commands:
  `prefix_rule(pattern=["git", ["commit","push",...]], decision="forbidden", justification="...")`.
  Test with `codex execpolicy check --rules <file> -- git commit -m x`.
- Codex's own worktree feature creates Git worktrees; do not mix it with jj workspaces.

## Kiro

- Steering file `.kiro/steering/jj.md` with `inclusion: always` carries the jj rules.
- Permission rules (`~/.kiro/settings/permissions.yaml` or an agent's `permissions`):
  allow `jj *`, ask for `jj undo*`/`jj op restore*`/`jj git push*`, deny `git commit*` and other
  Git writes. Deny wins over ask and allow at every scope.
- Kiro subagents and parallel spec-task waves share one working directory. For parallel
  work, open separate Kiro sessions, each in its own jj workspace.
- Custom agents load skills only when listed in `resources`
  (`skill://.kiro/skills/*/SKILL.md`).
