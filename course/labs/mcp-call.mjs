#!/usr/bin/env node
// mcp-call.mjs — talk to a stdio MCP server the way a host does, for checks and debugging.
// Usage:
//   node labs/mcp-call.mjs <server command...> -- list
//   node labs/mcp-call.mjs <server command...> -- call <tool> '<json arguments>'
// Example:
//   node labs/mcp-call.mjs node plugins/jj-agents/mcp/server.mjs -- call jj_status '{"workspace":"'$HOME'/jj-lab/app"}'
import { spawn } from "node:child_process";
const argv = process.argv.slice(2);
const sep = argv.indexOf("--");
if (sep < 1) { console.error("usage: mcp-call.mjs <server command...> -- list | call <tool> '<json>'"); process.exit(2); }
const [cmd, ...cmdArgs] = argv.slice(0, sep);
const [action, tool, json] = argv.slice(sep + 1);
const child = spawn(cmd, cmdArgs, { stdio: ["pipe", "pipe", "inherit"] });
let buf = ""; const waiters = new Map(); let id = 0;
child.stdout.on("data", (d) => { buf += d; let i; while ((i = buf.indexOf("\n")) >= 0) { const m = JSON.parse(buf.slice(0, i)); buf = buf.slice(i + 1); waiters.get(m.id)?.(m); } });
const rpc = (method, params) => new Promise((res) => { const n = ++id; waiters.set(n, res); child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id: n, method, params }) + "\n"); });
const timer = setTimeout(() => { console.error("timeout waiting for server"); process.exit(3); }, 30000);
await rpc("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "mcp-call", version: "1" } });
child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }) + "\n");
let code = 0;
if (action === "list") {
  const r = await rpc("tools/list", {});
  for (const t of r.result.tools) console.log(t.name);
} else if (action === "call") {
  const r = await rpc("tools/call", { name: tool, arguments: JSON.parse(json || "{}") });
  if (r.error) { console.error(r.error.message); code = 1; }
  else { console.log(r.result.content.map((c) => c.text).join("\n")); if (r.result.isError) code = 1; }
} else { console.error("action must be list or call"); code = 2; }
clearTimeout(timer); child.stdin.end(); child.kill(); process.exit(code);
