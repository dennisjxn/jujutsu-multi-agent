#!/usr/bin/env node
// Claude Code WorktreeCreate hook -> jj workspace.
// Claude Code calls this instead of `git worktree add` whenever it wants an isolated copy
// (claude --worktree, subagents with `isolation: worktree`, /batch).
// Contract (Claude Code 2.1.x): stdin JSON includes {"name": "...", "cwd": "..."};
// print the absolute path of the new directory on stdout; any non-zero exit aborts creation.
//
// Workspaces are created OUTSIDE the repository, in a sibling "<repo>-ws/" folder, for two reasons:
//   1. jj skips a nested workspace, but Git, search, test runners, and agents in the outer
//      workspace would all see a second copy of the project.
//   2. Claude Code's documentation says a hook-created directory without git metadata is accepted
//      only when no git repository contains it, and a colocated jj repo *is* a git repository.

import { execFileSync } from "node:child_process";
import { readFileSync, existsSync, mkdirSync } from "node:fs";
import path from "node:path";

const input = JSON.parse(readFileSync(0, "utf8") || "{}");
const raw = String(input.name || "").trim();
const name = raw.replace(/[^A-Za-z0-9._-]/g, "-").replace(/^[-.]+/, "").slice(0, 64) || `agent-${Date.now()}`;
const cwd = input.cwd || process.cwd();
const env = { ...process.env, JJ_EDITOR: "true", NO_COLOR: "1" };
const jj = (dir, ...args) =>
  execFileSync("jj", ["--no-pager", "--color=never", ...args], { cwd: dir, env, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });

try {
  const current = jj(cwd, "workspace", "root").trim();
  let repoRoot = current;
  try {
    repoRoot = jj(cwd, "workspace", "root", "--name", "default").trim();
  } catch {}
  const parent = path.join(path.dirname(repoRoot), `${path.basename(repoRoot)}-ws`);
  const dest = path.resolve(parent, `claude-${name}`);
  if (existsSync(dest)) throw new Error(`destination already exists: ${dest}`);
  mkdirSync(parent, { recursive: true });
  // Base the new workspace on the same parents as the current working-copy change, so the
  // agent starts from what the user is looking at (committed or not, @- is always safe).
  const out = execFileSync(
    "jj",
    ["--no-pager", "--color=never", "workspace", "add", "--name", `claude-${name}`, "-r", "@-", dest],
    { cwd, env, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] },
  );
  process.stderr.write(out); // diagnostics go to stderr; stdout must contain only the path
  process.stdout.write(dest + "\n");
  process.exit(0);
} catch (e) {
  process.stderr.write(`jj WorktreeCreate hook failed: ${String(e.stderr || e.message).trim()}\n`);
  process.exit(1);
}
