#!/usr/bin/env node
// Tests for the jj-agents hook scripts. Creates a throwaway jj repository in a temp folder.
// Usage: node tests/hooks-test.mjs          (needs jj and git on PATH)
import { spawnSync, execFileSync } from "node:child_process";
import { mkdtempSync, existsSync, rmSync, realpathSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), "..");
const hook = (name) => path.join(root, "hooks", name);
const tmp = realpathSync(mkdtempSync(path.join(os.tmpdir(), "jj-agents-hooks-")));
const repo = path.join(tmp, "repo");
const plain = path.join(tmp, "plain");
const env = { ...process.env, JJ_USER: "Hook Test", JJ_EMAIL: "hooks@example.com", JJ_EDITOR: "true" };
delete env.CLAUDECODE;
execFileSync("jj", ["git", "init", repo], { env, stdio: "ignore" });
execFileSync("mkdir", ["-p", plain]);

let failed = 0;
function run(script, input) {
  return spawnSync(process.execPath, [hook(script)], { input: JSON.stringify(input), env, encoding: "utf8" });
}
function expect(name, cond, extra = "") {
  console.log(`${cond ? "PASS" : "FAIL"}  ${name}${extra ? "  — " + extra : ""}`);
  if (!cond) failed++;
}

// guard-git.mjs
const guard = (command, cwd = repo) => run("guard-git.mjs", { tool_name: "Bash", tool_input: { command }, cwd });
const blocked = [
  "git commit -m x",
  "git add .",
  "git push origin main",
  "cd sub && git commit -am 'y'",
  "GIT_AUTHOR_NAME=x git commit -m z",
  "git -C . rebase main",
  "git --no-pager checkout -b feature",
  "git stash",
  "git worktree add ../x",
];
const allowed = [
  "git status",
  "git log --oneline -5",
  "git diff HEAD",
  "jj git push --bookmark x",
  "jj commit -m 'git commit message'",
  "git branch",
  "git stash list",
  "echo 'run git commit later'",
];
for (const c of blocked) {
  const r = guard(c);
  expect(`guard blocks: ${c}`, r.status === 2 && /jj/.test(r.stderr));
}
for (const c of allowed) {
  const r = guard(c);
  expect(`guard allows: ${c}`, r.status === 0, r.status !== 0 ? r.stderr.split("\n")[0] : "");
}
expect("guard ignores non-jj directories", guard("git commit -m x", plain).status === 0);
expect("guard tolerates empty input", spawnSync(process.execPath, [hook("guard-git.mjs")], { input: "", env }).status === 0);

// session-start.mjs
const ss = run("session-start.mjs", { hook_event_name: "SessionStart", cwd: repo });
expect("session-start prints orientation", ss.status === 0 && /workspace "default"/.test(ss.stdout), ss.stdout.split("\n")[0]);
expect("session-start silent outside jj", run("session-start.mjs", { cwd: plain }).stdout === "");

// worktree-create.mjs / worktree-remove.mjs (Claude Code)
const wc = run("worktree-create.mjs", { hook_event_name: "WorktreeCreate", name: "fix login/bug", cwd: repo });
const created = wc.stdout.trim();
expect("WorktreeCreate prints one absolute path", wc.status === 0 && path.isAbsolute(created) && !created.includes("\n"), created || wc.stderr);
expect("WorktreeCreate places workspace outside the repo", created.startsWith(path.join(tmp, "repo-ws") + path.sep));
expect("WorktreeCreate made a jj workspace", existsSync(path.join(created, ".jj")));
const list = execFileSync("jj", ["--no-pager", "workspace", "list", "-T", 'name ++ "\\n"'], { cwd: repo, env, encoding: "utf8" });
expect("workspace is registered as claude-fix-login-bug", list.split("\n").includes("claude-fix-login-bug"), list.trim().replace(/\n/g, ", "));
const dup = run("worktree-create.mjs", { name: "fix login/bug", cwd: repo });
expect("WorktreeCreate refuses to overwrite an existing workspace", dup.status !== 0);
const wr = run("worktree-remove.mjs", { hook_event_name: "WorktreeRemove", worktree_path: created, cwd: repo });
expect("WorktreeRemove succeeds", wr.status === 0, wr.stderr.trim());
expect("WorktreeRemove deleted the directory", !existsSync(created));
const list2 = execFileSync("jj", ["--no-pager", "workspace", "list", "-T", 'name ++ "\\n"'], { cwd: repo, env, encoding: "utf8" });
expect("WorktreeRemove forgot the workspace", !list2.split("\n").includes("claude-fix-login-bug"));
const foreign = run("worktree-remove.mjs", { worktree_path: plain });
expect("WorktreeRemove leaves foreign directories alone", foreign.status === 0 && existsSync(plain));

rmSync(tmp, { recursive: true, force: true });
console.log(failed ? `\n${failed} check(s) failed` : "\nAll checks passed");
process.exit(failed ? 1 : 0);
