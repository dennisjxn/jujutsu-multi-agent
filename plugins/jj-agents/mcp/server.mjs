#!/usr/bin/env node
// jj-agents MCP server — a small, dependency-free Model Context Protocol server
// that exposes a deliberately limited set of Jujutsu (jj) operations to coding agents.
//
// Transport: stdio, newline-delimited JSON-RPC 2.0 (MCP stdio transport).
// Design rules:
//   * Every tool takes an explicit absolute `workspace` path. The server never
//     trusts its own working directory, because hosts start MCP servers in
//     different places (Codex Agent Plugins: the plugin root; Claude Code: the project).
//   * jj is executed with execFile (no shell), so arguments are never interpolated.
//   * No history-destroying or remote-mutating operations (push, abandon, undo,
//     op restore). Those stay with a human or an explicit CLI step.
//   * Every jj call runs non-interactively: no pager, no color, and JJ_EDITOR=true so an
//     unexpected editor launch exits immediately instead of hanging the agent.

import { execFile } from "node:child_process";
import { existsSync, statSync } from "node:fs";
import path from "node:path";
import readline from "node:readline";

const SERVER_INFO = { name: "jj-agents", version: "1.0.0" };
const SUPPORTED_PROTOCOLS = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"];
const JJ_BIN = process.env.JJ_AGENTS_JJ_BIN || "jj";
const TIMEOUT_MS = Number(process.env.JJ_AGENTS_TIMEOUT_MS || 60000);

// ---------- jj execution ----------

function runJj(cwd, args) {
  return new Promise((resolve) => {
    execFile(
      JJ_BIN,
      ["--no-pager", "--color=never", ...args],
      {
        cwd,
        timeout: TIMEOUT_MS,
        maxBuffer: 16 * 1024 * 1024,
        env: { ...process.env, JJ_EDITOR: "true", NO_COLOR: "1" },
      },
      (err, stdout, stderr) => {
        resolve({
          ok: !err,
          code: err ? (typeof err.code === "number" ? err.code : 1) : 0,
          stdout: stdout ?? "",
          stderr: stderr ?? "",
          missing: err && err.code === "ENOENT",
        });
      },
    );
  });
}

class ToolError extends Error {}

async function resolveWorkspace(input) {
  const ws = input?.workspace;
  if (typeof ws !== "string" || ws.length === 0) {
    throw new ToolError("`workspace` is required: pass the absolute path of your current jj workspace (your working directory).");
  }
  if (!path.isAbsolute(ws)) throw new ToolError(`\`workspace\` must be an absolute path, got: ${ws}`);
  if (!existsSync(ws) || !statSync(ws).isDirectory()) throw new ToolError(`No such directory: ${ws}`);
  const r = await runJj(ws, ["workspace", "root"]);
  if (r.missing) throw new ToolError(`The jj binary was not found (looked for "${JJ_BIN}" on PATH).`);
  if (!r.ok) throw new ToolError(`Not inside a jj workspace: ${ws}\n${r.stderr.trim()}`);
  return r.stdout.trim();
}

async function jj(root, args) {
  const r = await runJj(root, args);
  if (!r.ok) {
    let msg = `jj ${args.join(" ")} failed (exit ${r.code}):\n${r.stderr.trim()}`;
    if (/working copy is stale/i.test(r.stderr)) {
      msg += "\n\nThis workspace is stale (another workspace rewrote its commit). Call jj_update_stale, then retry.";
    }
    throw new ToolError(msg);
  }
  return [r.stdout, r.stderr].filter((s) => s.trim()).join("\n").trim();
}

// One JSON object per line; shaped further in JS.
const LOG_TEMPLATE =
  'json(change_id) ++ "\\t" ++ json(commit_id) ++ "\\t" ++ json(description) ++ "\\t" ++ ' +
  'json(local_bookmarks) ++ "\\t" ++ json(empty) ++ "\\t" ++ ' +
  'json(conflict) ++ "\\t" ++ json(immutable) ++ "\\t" ++ json(divergent) ++ "\\t" ++ json(author) ++ "\\n"';

// Map commit IDs to the workspaces that have them checked out. (Read from `jj workspace list`
// rather than the `working_copies` template keyword, which returned [] in some states in jj 0.45.)
async function workingCopyMap(root) {
  const out = await jj(root, ["workspace", "list", "-T", 'json(self) ++ "\\n"']);
  const map = new Map();
  for (const line of out.split("\n").filter(Boolean)) {
    const ws = JSON.parse(line);
    const list = map.get(ws.target.commit_id) ?? [];
    list.push(ws.name);
    map.set(ws.target.commit_id, list);
  }
  return map;
}

function parseLog(text, wcMap) {
  return text
    .split("\n")
    .filter((l) => l.trim())
    .map((line) => {
      const [change_id, commit_id, description, bookmarks, empty, conflict, immutable, divergent, author] =
        line.split("\t").map((f) => JSON.parse(f));
      return {
        change_id,
        change_id_short: change_id.slice(0, 8),
        commit_id: commit_id.slice(0, 12),
        summary: description.split("\n")[0],
        description,
        bookmarks: bookmarks.map((b) => b.name),
        working_copy_of: wcMap.get(commit_id) ?? [],
        empty,
        conflict,
        immutable,
        divergent,
        author: author?.email ?? null,
        timestamp: author?.timestamp ?? null,
      };
    });
}

const NAME_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/;
function checkName(kind, v) {
  if (typeof v !== "string" || !NAME_RE.test(v)) {
    throw new ToolError(`${kind} must match ${NAME_RE} (letters, digits, . _ -; max 64 chars). Got: ${JSON.stringify(v)}`);
  }
  return v;
}
function checkRevset(v, fallback) {
  const s = v ?? fallback;
  if (typeof s !== "string" || s.length === 0 || s.length > 500 || s.startsWith("-")) {
    throw new ToolError(`Invalid revset: ${JSON.stringify(v)}`);
  }
  return s;
}
function checkMessage(v) {
  if (typeof v !== "string" || v.trim().length === 0) throw new ToolError("`message` must be a non-empty string.");
  return v;
}

// ---------- tools ----------

const WS = {
  type: "string",
  description: "Absolute path of the jj workspace to operate in (your current working directory).",
};

const tools = [
  {
    name: "jj_status",
    description: "Show the working-copy change (@), its parents, changed files, and conflicts for one workspace. Read-only apart from jj's normal working-copy snapshot.",
    inputSchema: { type: "object", properties: { workspace: WS }, required: ["workspace"] },
    annotations: { readOnlyHint: true },
    run: async (a) => jj(await resolveWorkspace(a), ["status"]),
  },
  {
    name: "jj_log",
    description: "List changes as JSON (change_id, commit_id, summary, bookmarks, which workspaces have it checked out, empty/conflict/immutable/divergent flags). Default revset is jj's default log view.",
    inputSchema: {
      type: "object",
      properties: {
        workspace: WS,
        revset: { type: "string", description: "Revset to show, e.g. '@', 'trunk()..', 'working_copies()', 'conflicts()'. Omit for the default view." },
        limit: { type: "integer", minimum: 1, maximum: 200, default: 30 },
      },
      required: ["workspace"],
    },
    annotations: { readOnlyHint: true },
    run: async (a) => {
      const root = await resolveWorkspace(a);
      const args = ["log", "--no-graph", "-T", LOG_TEMPLATE, "-n", String(a.limit ?? 30)];
      if (a.revset) args.push("-r", checkRevset(a.revset));
      return JSON.stringify(parseLog(await jj(root, args), await workingCopyMap(root)), null, 2);
    },
  },
  {
    name: "jj_diff",
    description: "Show the diff of a revision (default @). summary=true returns only the list of changed paths.",
    inputSchema: {
      type: "object",
      properties: {
        workspace: WS,
        revision: { type: "string", default: "@" },
        summary: { type: "boolean", default: false },
      },
      required: ["workspace"],
    },
    annotations: { readOnlyHint: true },
    run: async (a) => {
      const root = await resolveWorkspace(a);
      const args = ["diff", "-r", checkRevset(a.revision, "@"), a.summary ? "--summary" : "--git"];
      return (await jj(root, args)) || "(no changes)";
    },
  },
  {
    name: "jj_describe",
    description: "Set the description (commit message) of a change, default @. Does not create a new change.",
    inputSchema: {
      type: "object",
      properties: { workspace: WS, message: { type: "string" }, revision: { type: "string", default: "@" } },
      required: ["workspace", "message"],
    },
    run: async (a) => jj(await resolveWorkspace(a), ["describe", "-r", checkRevset(a.revision, "@"), "-m", checkMessage(a.message)]),
  },
  {
    name: "jj_commit",
    description: "Finish the current change: give @ a description and start a new empty change on top of it (like 'jj commit -m'). Optionally restrict to paths; the rest stays in the new @.",
    inputSchema: {
      type: "object",
      properties: {
        workspace: WS,
        message: { type: "string" },
        paths: { type: "array", items: { type: "string" }, description: "Optional workspace-relative paths to include." },
      },
      required: ["workspace", "message"],
    },
    run: async (a) => {
      const root = await resolveWorkspace(a);
      const paths = (a.paths ?? []).map((p) => {
        if (typeof p !== "string" || p.startsWith("-") || path.isAbsolute(p)) throw new ToolError(`Invalid path: ${p}`);
        return p;
      });
      return jj(root, ["commit", "-m", checkMessage(a.message), ...(paths.length ? ["--", ...paths] : [])]);
    },
  },
  {
    name: "jj_new",
    description: "Start a new empty change on top of the given parents (default @) and check it out in this workspace. Use at the start of every task.",
    inputSchema: {
      type: "object",
      properties: {
        workspace: WS,
        parents: { type: "array", items: { type: "string" }, description: "Parent revsets, e.g. ['trunk()']. Default ['@']." },
        message: { type: "string" },
      },
      required: ["workspace"],
    },
    run: async (a) => {
      const root = await resolveWorkspace(a);
      const parents = (a.parents?.length ? a.parents : ["@"]).map((p) => checkRevset(p));
      const args = ["new", ...parents];
      if (a.message) args.push("-m", checkMessage(a.message));
      return jj(root, args);
    },
  },
  {
    name: "jj_workspace_add",
    description: "Create an isolated workspace (a separate directory with its own working-copy change) for a new agent or task. Default destination is a sibling folder '<repo>-ws/<name>' outside the repository.",
    inputSchema: {
      type: "object",
      properties: {
        workspace: { ...WS, description: "Absolute path of any existing workspace of the repository." },
        name: { type: "string", description: "Workspace name, e.g. 'agent-auth'." },
        revision: { type: "string", default: "trunk()", description: "Revset the new workspace's first change is based on." },
        destination: { type: "string", description: "Optional absolute destination directory." },
      },
      required: ["workspace", "name"],
    },
    run: async (a) => {
      const root = await resolveWorkspace(a);
      const name = checkName("name", a.name);
      const repoRoot = (await jj(root, ["workspace", "root", "--name", "default"]).catch(() => root)).trim();
      const dest = a.destination
        ? a.destination
        : path.join(path.dirname(repoRoot), `${path.basename(repoRoot)}-ws`, name);
      if (!path.isAbsolute(dest)) throw new ToolError("`destination` must be absolute.");
      if (existsSync(dest)) throw new ToolError(`Destination already exists: ${dest}`);
      const out = await jj(root, ["workspace", "add", "--name", name, "-r", checkRevset(a.revision, "trunk()"), dest]);
      return `${out}\n\nWorkspace path: ${dest}\nRun the agent for this task with its working directory set to that path.`;
    },
  },
  {
    name: "jj_workspace_list",
    description: "List all workspaces of the repository with their paths and working-copy changes (JSON).",
    inputSchema: { type: "object", properties: { workspace: WS }, required: ["workspace"] },
    annotations: { readOnlyHint: true },
    run: async (a) => {
      const root = await resolveWorkspace(a);
      const out = await jj(root, ["workspace", "list", "-T", 'json(self) ++ "\\t" ++ json(root) ++ "\\n"']);
      return JSON.stringify(
        out.split("\n").filter(Boolean).map((l) => {
          const [ws, wsRoot] = l.split("\t").map((f) => JSON.parse(f));
          return {
            name: ws.name,
            path: wsRoot,
            change_id: ws.target.change_id.slice(0, 8),
            commit_id: ws.target.commit_id.slice(0, 12),
            summary: ws.target.description.split("\n")[0],
          };
        }),
        null,
        2,
      );
    },
  },
  {
    name: "jj_workspace_forget",
    description: "Stop tracking a workspace (its working-copy change stays in history; files on disk are NOT deleted). Use after its work is integrated.",
    inputSchema: { type: "object", properties: { workspace: WS, name: { type: "string" } }, required: ["workspace", "name"] },
    run: async (a) => jj(await resolveWorkspace(a), ["workspace", "forget", checkName("name", a.name)]),
  },
  {
    name: "jj_update_stale",
    description: "Repair a stale workspace: update its files to the latest version of its working-copy change after another workspace rewrote it.",
    inputSchema: { type: "object", properties: { workspace: WS }, required: ["workspace"] },
    run: async (a) => {
      const ws = a?.workspace;
      if (typeof ws !== "string" || !path.isAbsolute(ws)) throw new ToolError("`workspace` must be an absolute path.");
      // resolveWorkspace would fail on a stale workspace, so call jj directly.
      const r = await runJj(ws, ["workspace", "update-stale"]);
      if (!r.ok) throw new ToolError(r.stderr.trim());
      return [r.stdout, r.stderr].filter((s) => s.trim()).join("\n").trim();
    },
  },
  {
    name: "jj_op_log",
    description: "Show recent operations (the repository's undo history), newest first, as JSON: id, time, workspace, description.",
    inputSchema: {
      type: "object",
      properties: { workspace: WS, limit: { type: "integer", minimum: 1, maximum: 100, default: 10 } },
      required: ["workspace"],
    },
    annotations: { readOnlyHint: true },
    run: async (a) => {
      const root = await resolveWorkspace(a);
      const t = 'json(id.short(12)) ++ "\\t" ++ json(time.end()) ++ "\\t" ++ json(workspace_name) ++ "\\t" ++ json(description) ++ "\\n"';
      const out = await jj(root, ["op", "log", "--no-graph", "-n", String(a.limit ?? 10), "-T", t]);
      return JSON.stringify(
        out.split("\n").filter(Boolean).map((l) => {
          const [id, time, workspace, description] = l.split("\t").map((f) => JSON.parse(f));
          return { id, time, workspace, description };
        }),
        null,
        2,
      );
    },
  },
  {
    name: "jj_conflicts",
    description: "List files with unresolved conflicts in a revision (default @).",
    inputSchema: { type: "object", properties: { workspace: WS, revision: { type: "string", default: "@" } }, required: ["workspace"] },
    annotations: { readOnlyHint: true },
    run: async (a) => {
      const root = await resolveWorkspace(a);
      const r = await runJj(root, ["resolve", "--list", "-r", checkRevset(a.revision, "@")]);
      if (r.ok) return r.stdout.trim();
      if (/no conflicts/i.test(r.stderr)) return "No conflicts.";
      throw new ToolError(r.stderr.trim());
    },
  },
  {
    name: "jj_bookmark_set",
    description: "Point a local bookmark (jj's name for a Git branch) at a revision. Refuses to move a bookmark backwards or sideways. Does not push.",
    inputSchema: {
      type: "object",
      properties: { workspace: WS, name: { type: "string" }, revision: { type: "string", default: "@-" } },
      required: ["workspace", "name"],
    },
    run: async (a) =>
      jj(await resolveWorkspace(a), ["bookmark", "set", checkName("name", a.name), "-r", checkRevset(a.revision, "@-")]),
  },
];

// ---------- JSON-RPC plumbing ----------

function send(msg) {
  process.stdout.write(JSON.stringify(msg) + "\n");
}

async function handle(msg) {
  const { id, method, params } = msg;
  const isRequest = id !== undefined && id !== null;
  try {
    switch (method) {
      case "initialize": {
        const requested = params?.protocolVersion;
        const protocolVersion = SUPPORTED_PROTOCOLS.includes(requested) ? requested : SUPPORTED_PROTOCOLS[0];
        return isRequest && send({
          jsonrpc: "2.0",
          id,
          result: {
            protocolVersion,
            capabilities: { tools: { listChanged: false } },
            serverInfo: SERVER_INFO,
            instructions:
              "Jujutsu (jj) tools for multi-agent work. Always pass `workspace` = your absolute working directory. One agent per workspace; start each task with jj_new; never run git write commands in a jj repo.",
          },
        });
      }
      case "ping":
        return isRequest && send({ jsonrpc: "2.0", id, result: {} });
      case "tools/list":
        return send({
          jsonrpc: "2.0",
          id,
          result: { tools: tools.map(({ run, ...t }) => t) },
        });
      case "tools/call": {
        const tool = tools.find((t) => t.name === params?.name);
        if (!tool) {
          return send({ jsonrpc: "2.0", id, error: { code: -32602, message: `Unknown tool: ${params?.name}` } });
        }
        try {
          const text = await tool.run(params.arguments ?? {});
          return send({ jsonrpc: "2.0", id, result: { content: [{ type: "text", text: text || "OK" }] } });
        } catch (e) {
          const text = e instanceof ToolError ? e.message : `Unexpected error: ${e?.stack || e}`;
          return send({ jsonrpc: "2.0", id, result: { content: [{ type: "text", text }], isError: true } });
        }
      }
      default:
        if (method?.startsWith("notifications/")) return; // e.g. notifications/initialized
        if (isRequest) send({ jsonrpc: "2.0", id, error: { code: -32601, message: `Method not found: ${method}` } });
    }
  } catch (e) {
    if (isRequest) send({ jsonrpc: "2.0", id, error: { code: -32603, message: String(e?.message || e) } });
  }
}

const rl = readline.createInterface({ input: process.stdin });
rl.on("line", (line) => {
  if (!line.trim()) return;
  let msg;
  try {
    msg = JSON.parse(line);
  } catch {
    return send({ jsonrpc: "2.0", id: null, error: { code: -32700, message: "Parse error" } });
  }
  handle(msg);
});
rl.on("close", () => process.exit(0));
