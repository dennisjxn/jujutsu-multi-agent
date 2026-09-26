#!/usr/bin/env node
// Smoke test for the jj-agents MCP server: speaks MCP over stdio exactly as a host would.
// Usage: node tests/mcp-smoke.mjs /absolute/path/to/a/jj/workspace
import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ws = process.argv[2];
if (!ws || !path.isAbsolute(ws)) {
  console.error("usage: node tests/mcp-smoke.mjs /absolute/path/to/jj/workspace");
  process.exit(2);
}
const server = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "mcp", "server.mjs");
const child = spawn(process.execPath, [server], { stdio: ["pipe", "pipe", "inherit"] });

let buf = "";
const waiters = new Map();
child.stdout.on("data", (d) => {
  buf += d;
  let i;
  while ((i = buf.indexOf("\n")) >= 0) {
    const line = buf.slice(0, i);
    buf = buf.slice(i + 1);
    const msg = JSON.parse(line);
    waiters.get(msg.id)?.(msg);
  }
});
let nextId = 1;
function call(method, params) {
  const id = nextId++;
  child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
  return new Promise((res) => waiters.set(id, res));
}

const results = [];
function check(name, cond, detail = "") {
  results.push(cond);
  console.log(`${cond ? "PASS" : "FAIL"}  ${name}${detail ? "  — " + detail : ""}`);
}

const init = await call("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "smoke", version: "0" } });
check("initialize negotiates protocol", init.result?.protocolVersion === "2025-06-18");
child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }) + "\n");

const list = await call("tools/list", {});
const names = list.result.tools.map((t) => t.name);
check("tools/list returns the 13 core tools", ["jj_status","jj_log","jj_diff","jj_describe","jj_commit","jj_new","jj_workspace_add","jj_workspace_list","jj_workspace_forget","jj_update_stale","jj_op_log","jj_conflicts","jj_bookmark_set"].every((n) => names.includes(n)), names.join(", "));

const st = await call("tools/call", { name: "jj_status", arguments: { workspace: ws } });
check("jj_status succeeds", !st.result.isError, st.result.content[0].text.split("\n")[0]);

const log = await call("tools/call", { name: "jj_log", arguments: { workspace: ws, revset: "@", limit: 1 } });
let parsed = null;
try { parsed = JSON.parse(log.result.content[0].text); } catch {}
check("jj_log returns JSON for @", Array.isArray(parsed) && parsed.length === 1 && parsed[0].working_copy_of.length >= 1);

const wl = await call("tools/call", { name: "jj_workspace_list", arguments: { workspace: ws } });
check("jj_workspace_list returns JSON", !wl.result.isError && JSON.parse(wl.result.content[0].text).length >= 1);

const op = await call("tools/call", { name: "jj_op_log", arguments: { workspace: ws, limit: 3 } });
check("jj_op_log returns JSON", !op.result.isError && JSON.parse(op.result.content[0].text).length >= 1, op.result.isError ? op.result.content[0].text : "");

const bad = await call("tools/call", { name: "jj_status", arguments: { workspace: "relative/path" } });
check("relative workspace is rejected", bad.result.isError === true);

const inj = await call("tools/call", { name: "jj_bookmark_set", arguments: { workspace: ws, name: "x; rm -rf /" } });
check("unsafe bookmark name is rejected", inj.result.isError === true);

child.stdin.end();
const failed = results.filter((r) => !r).length;
console.log(failed ? `\n${failed} check(s) failed` : "\nAll checks passed");
process.exit(failed ? 1 : 0);
