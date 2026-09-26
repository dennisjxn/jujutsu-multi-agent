#!/usr/bin/env node
// SessionStart hook: when a session opens inside a jj workspace, repair a stale working
// copy and print a short orientation that the host adds to the agent's context
// (Claude Code and Codex both add SessionStart stdout to context).
// Never blocks: always exits 0.

import { execFileSync } from "node:child_process";
import { readFileSync, existsSync } from "node:fs";
import path from "node:path";

let input = {};
try {
  input = JSON.parse(readFileSync(0, "utf8") || "{}");
} catch {}
const cwd = input.cwd || process.cwd();

function findJj(dir) {
  for (let d = path.resolve(dir); ; d = path.dirname(d)) {
    if (existsSync(path.join(d, ".jj"))) return d;
    if (path.dirname(d) === d) return null;
  }
}
const root = findJj(cwd);
if (!root) process.exit(0);

const env = { ...process.env, JJ_EDITOR: "true", NO_COLOR: "1" };
const jj = (...args) =>
  execFileSync("jj", ["--no-pager", "--color=never", ...args], { cwd: root, env, encoding: "utf8", timeout: 20000, stdio: ["ignore", "pipe", "pipe"] });

const lines = [];
try {
  try {
    jj("status");
  } catch (e) {
    if (/stale/i.test(String(e.stderr))) {
      jj("workspace", "update-stale");
      lines.push("Note: this workspace was stale (another workspace rewrote it); it has been updated.");
    } else throw e;
  }
  const here = jj("workspace", "root").trim();
  const all = jj("workspace", "list", "-T", 'name ++ "\\t" ++ root ++ "\\n"')
    .trim()
    .split("\n")
    .map((l) => l.split("\t"));
  const name = (all.find(([, r]) => path.resolve(root, r) === here) || [""])[0];
  const at = jj("log", "--no-graph", "-r", "@", "-T", 'change_id.short(8) ++ " " ++ if(description, description.first_line(), "(no description)") ++ if(empty, " [empty]", "") ++ if(conflict, " [CONFLICT]", "")').trim();
  const others = all.map(([n]) => n).filter((n) => n && n !== name);
  lines.push(
    `Jujutsu (jj) repository. You are in workspace "${name}" at ${root}.`,
    `Working-copy change @: ${at}`,
    others.length ? `Other workspaces (other agents): ${others.join(", ")}. Do not edit their changes; their @ are ${others.map((o) => o + "@").join(", ")}.` : "No other workspaces.",
    "Rules: use jj, not git write commands. Start each task with `jj new 'trunk()' -m \"<task>\"` (or `jj new`). Finish with `jj commit -m`. Never run `jj undo`/`jj op restore` without asking: they rewind every workspace.",
  );
} catch (e) {
  lines.push(`jj repository detected at ${root}, but jj failed: ${String(e.stderr || e.message).trim().split("\n")[0]}`);
}
process.stdout.write(lines.join("\n") + "\n");
process.exit(0);
