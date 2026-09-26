#!/usr/bin/env node
// PreToolUse guard: stops an agent from running Git *write* commands inside a jj repository
// and tells it the jj equivalent. Works for Claude Code and Codex, which both send
// {"tool_name":"Bash","tool_input":{"command":"..."},"cwd":"..."} on stdin.
//
// Exit codes (same meaning in Claude Code and Codex):
//   0 = allow (nothing printed)
//   2 = block; stderr is shown to the agent as the reason
//
// This is guidance, not a security boundary: an agent can still reach git through
// a script, an alias, or `sh -c`. Pair it with permission rules (see templates/).

import { existsSync, readFileSync } from "node:fs";
import path from "node:path";

const JJ_EQUIVALENT = {
  add: "Nothing to stage: jj snapshots every file automatically. Just run `jj status`.",
  commit: "Use `jj commit -m \"message\"` (or `jj describe -m \"message\"` then `jj new`).",
  push: "Use `jj git push --bookmark <name>` (or `jj git push -c @-` to push the last finished change).",
  pull: "Use `jj git fetch`, then `jj rebase -o trunk()` if you need to move onto the new trunk.",
  fetch: "Use `jj git fetch`.",
  checkout: "Use `jj new <revision>` to start work on top of something, or `jj edit <revision>` to resume it.",
  switch: "Use `jj new <revision>`.",
  branch: "jj calls branches bookmarks: `jj bookmark list | create | set | move`.",
  merge: "Use `jj new <rev1> <rev2>` to create a merge change.",
  rebase: "Use `jj rebase -s <source> -o <destination>`.",
  reset: "Use `jj restore` to discard file changes, or `jj op log` + `jj op restore <id>` to rewind history.",
  restore: "Use `jj restore <paths>`.",
  stash: "No stash in jj: run `jj new` and your in-progress change stays where it is.",
  "cherry-pick": "Use `jj duplicate <revision> -o <destination>`.",
  revert: "Use `jj revert -r <revision> -o @`.",
  tag: "Use `jj tag set <name> -r <revision>`.",
  worktree: "Use `jj workspace add <path> --name <name>`.",
  am: "Apply patches with `jj new` and your patch tool, then `jj describe`.",
  "update-ref": "Use `jj bookmark set`.",
  clean: "Use `jj restore` for tracked files; untracked files are snapshotted by jj.",
};

function readStdin() {
  try {
    return readFileSync(0, "utf8");
  } catch {
    return "";
  }
}

function inJjRepo(start) {
  let dir = path.resolve(start || process.cwd());
  for (;;) {
    if (existsSync(path.join(dir, ".jj"))) return true;
    const parent = path.dirname(dir);
    if (parent === dir) return false;
    dir = parent;
  }
}

// Split a shell command line into simple commands (best effort) and return git subcommands.
function gitSubcommands(command) {
  const found = [];
  const segments = command.split(/&&|\|\||;|\||\n|\$\(|`/);
  for (const seg of segments) {
    const words = seg.trim().split(/\s+/).filter(Boolean);
    let i = 0;
    while (i < words.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(words[i])) i++; // env prefixes
    while (i < words.length && ["sudo", "command", "exec", "time", "nice"].includes(words[i])) i++;
    if (i >= words.length || !/(^|\/)git$/.test(words[i])) continue;
    i++;
    // skip global options such as -C <dir>, -c k=v, --no-pager
    while (i < words.length && words[i].startsWith("-")) {
      if (["-C", "-c", "--git-dir", "--work-tree", "--namespace"].includes(words[i])) i += 2;
      else i += 1;
    }
    if (i < words.length) found.push({ sub: words[i].replace(/^['"]|['"]$/g, ""), rest: words.slice(i + 1) });
  }
  return found;
}

// Read-only forms of otherwise-mutating subcommands.
function isReadOnly({ sub, rest }) {
  if (sub === "branch") return rest.length === 0 || rest.every((w) => ["-a", "-r", "--list", "-v", "-vv", "--show-current"].includes(w));
  if (sub === "tag") return rest.length === 0 || rest[0] === "-l" || rest[0] === "--list";
  if (sub === "stash") return rest[0] === "list" || rest[0] === "show";
  if (sub === "worktree") return rest[0] === "list";
  return false;
}

const input = (() => {
  try {
    return JSON.parse(readStdin() || "{}");
  } catch {
    return {};
  }
})();

const command = input?.tool_input?.command ?? input?.tool_input?.cmd ?? "";
if (typeof command !== "string" || !command.includes("git")) process.exit(0);
if (!inJjRepo(input.cwd)) process.exit(0);

for (const g of gitSubcommands(command)) {
  if (g.sub in JJ_EQUIVALENT && !isReadOnly(g)) {
    process.stderr.write(
      `Blocked: \`git ${g.sub}\` in a Jujutsu (jj) repository. Git write commands bypass jj's change tracking ` +
        `and can create divergent or orphaned work for other agents.\n${JJ_EQUIVALENT[g.sub]}\n` +
        `Read-only git commands (status, log, diff, show, blame) are fine.`,
    );
    process.exit(2);
  }
}
process.exit(0);
