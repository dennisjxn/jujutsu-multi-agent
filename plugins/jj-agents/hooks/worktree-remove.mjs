#!/usr/bin/env node
// Claude Code WorktreeRemove hook -> jj workspace forget.
// stdin JSON includes {"worktree_path": "..."}.
// Only acts on directories this plugin created (<repo>-ws/claude-*); anything else is left alone.
// The workspace's working-copy change is NOT abandoned: its commits remain in history
// (find them with `jj log -r 'all()'` or `jj evolog`), so nothing an agent wrote is lost.

import { execFileSync } from "node:child_process";
import { readFileSync, rmSync, existsSync } from "node:fs";
import path from "node:path";

const input = JSON.parse(readFileSync(0, "utf8") || "{}");
const wt = input.worktree_path ? path.resolve(String(input.worktree_path)) : "";
const base = path.basename(wt);
if (!wt || !base.startsWith("claude-") || !path.basename(path.dirname(wt)).endsWith("-ws")) {
  process.stderr.write(`jj WorktreeRemove hook: not a jj-agents workspace, skipping: ${wt}\n`);
  process.exit(0);
}
const env = { ...process.env, JJ_EDITOR: "true", NO_COLOR: "1" };
try {
  if (existsSync(path.join(wt, ".jj"))) {
    // Snapshot any last edits before forgetting, so they are recorded in the op log.
    try {
      execFileSync("jj", ["--no-pager", "status"], { cwd: wt, env, stdio: "ignore" });
    } catch {}
    execFileSync("jj", ["--no-pager", "workspace", "forget", base], { cwd: wt, env, stdio: ["ignore", "ignore", "pipe"] });
  }
  rmSync(wt, { recursive: true, force: true });
  process.exit(0);
} catch (e) {
  process.stderr.write(`jj WorktreeRemove hook failed: ${String(e.stderr || e.message).trim()}\n`);
  process.exit(1);
}
