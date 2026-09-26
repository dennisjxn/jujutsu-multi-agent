#!/usr/bin/env bash
# check.sh — self-check for the course's performance tasks.
# Usage: check.sh <task>
#   setup                    Module 0: tools installed and jj configured for humans and agents
#   m1                       Module 1: the two-change stack
#   m2                       Module 2: low-stock bookmark pushed on top of the teammate's main
#   m3                       Module 3: three agents' work integrated and pushed as "integration"
#   m4-stale | m4-undo | m4-divergent | m4-wipe | m4-secret
#                            Module 4: each recovery scenario repaired
#   m5                       Module 5: host configuration files in the lab repository
#   m6 <plugin-dir>          Module 6: the cross-host plugin
#   capstone <plugin-dir>    Module 7: the capstone (all course objectives)
# Each line prints PASS or FAIL with the objective ID it evidences. Exit status is the FAIL count.
set -uo pipefail
JJ_LAB="${JJ_LAB:-$HOME/jj-lab}"
APP="$JJ_LAB/app"
ORIGIN="$JJ_LAB/origin.git"
fails=0
pass() { printf 'PASS  %-6s %s\n' "$1" "$2"; }
fail() { printf 'FAIL  %-6s %s\n' "$1" "$2"; [ -n "${3:-}" ] && printf '      hint: %s\n' "$3"; fails=$((fails+1)); }
ok() { local id="$1" msg="$2" hint="$3"; shift 3; if "$@" >/dev/null 2>&1; then pass "$id" "$msg"; else fail "$id" "$msg" "$hint"; fi; }
jjq() { jj --no-pager --color=never "$@"; }
need_lab() { [ -d "$APP/.jj" ] || { echo "No lab at $APP. Run lab.sh reset first."; exit 1; }; }

# Run the unit tests in a snapshot of origin's <ref>.
tests_pass_at_origin() {
  local ref="$1" tmp; tmp="$(mktemp -d)"
  git --git-dir="$ORIGIN" archive "$ref" | tar -x -C "$tmp" || return 1
  (cd "$tmp" && python3 -m unittest -q) >/dev/null 2>&1; local rc=$?
  rm -rf "$tmp"; return $rc
}
origin_has() { git --git-dir="$ORIGIN" rev-parse --verify -q "refs/heads/$1" >/dev/null; }
origin_log() { git --git-dir="$ORIGIN" log --format=%s "$1"; }   # subjects, newest first
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

check_setup() {
  local v
  v="$(jj --version 2>/dev/null | awk '{print $2}' | cut -d- -f1)"
  if [ -n "$v" ] && version_ge "$v" 0.45.0; then pass M0.1 "jj $v installed (course written for 0.45.x)"; else fail M0.1 "jj 0.45 or newer on PATH (found: ${v:-none})" "Module 0, step 1"; fi
  v="$(git --version 2>/dev/null | awk '{print $3}')"
  if [ -n "$v" ] && version_ge "$v" 2.41.0; then pass M0.1 "git $v (jj needs 2.41+ for fetch/push)"; else fail M0.1 "git 2.41+ (found: ${v:-none})" "upgrade git"; fi
  v="$(node --version 2>/dev/null | tr -d v)"
  if [ -n "$v" ] && version_ge "$v" 18.0.0; then pass M0.1 "node $v (needed in Modules 5-6)"; else fail M0.1 "node 18+ (found: ${v:-none})" "install Node.js LTS"; fi
  ok M0.1 "python3 available (runs the lab project's tests)" "install Python 3" command -v python3
  local name email
  name="$(jjq config get user.name 2>/dev/null)"; email="$(jjq config get user.email 2>/dev/null)"
  if [ -n "$name" ] && [ -n "$email" ]; then pass M0.2 "jj identity: $name <$email>"; else fail M0.2 "jj user.name and user.email set" "jj config set --user user.name ... (Module 0, step 2)"; fi
  if [ "$(jjq config get ui.conflict-marker-style 2>/dev/null)" = "git" ]; then pass M0.2 "conflict markers use Git style"; else fail M0.2 "ui.conflict-marker-style = \"git\"" "Module 0, step 2"; fi
  if [ "$(env -u CLAUDECODE -u CODEX_THREAD_ID JJ_AGENT=1 jj config get ui.editor 2>/dev/null)" = "true" ] &&
     [ "$(env -u CLAUDECODE -u CODEX_THREAD_ID JJ_AGENT=1 jj config get ui.paginate 2>/dev/null)" = "never" ]; then
    pass M0.3 "agent mode (JJ_AGENT=1): no editor, no pager"
  else fail M0.3 "agent-mode scope active when JJ_AGENT is set" "create conf.d/50-agents.toml (Module 0, step 3)"; fi
  local human_editor
  human_editor="$(env -u CLAUDECODE -u CODEX_THREAD_ID -u JJ_AGENT jj config get ui.editor 2>/dev/null)"
  if [ "$human_editor" != "true" ]; then pass M0.3 "human mode keeps a real editor ($human_editor)"; else fail M0.3 "ui.editor=true only in agent mode" "move editor=\"true\" inside the [[--scope]] block"; fi
}

check_m1() {
  need_lab; cd "$APP"
  local n
  n="$(jjq log --no-graph -r 'trunk()..@- ~ empty()' -T '"x\n"' | wc -l | tr -d ' ')"
  [ "$n" = 2 ] && pass M1.T "exactly two non-empty changes between trunk() and @-" || fail M1.T "two non-empty changes on top of trunk() (found $n)" "Module 1, practice 3"
  local first second
  first="$(jjq log --no-graph -r 'roots(trunk()..@)' -T 'description.first_line()')"
  second="$(jjq log --no-graph -r '@-' -T 'description.first_line()')"
  [ "$first" = "docs: explain the lab" ] && pass M1.3 "first change is \"docs: explain the lab\"" || fail M1.3 "first change described \"docs: explain the lab\" (found \"$first\")" "jj describe -r <change> -m ..."
  [ "$second" = "chore: add notes" ] && pass M1.3 "second change is \"chore: add notes\"" || fail M1.3 "@- described \"chore: add notes\" (found \"$second\")"
  ok M1.1 "@ is an empty change on top" "run jj new" test "$(jjq log --no-graph -r @ -T 'if(empty,"e","n")')" = e
  ok M1.2 "NOTES.md is added in \"chore: add notes\" only" "keep files in the right change" test "$(jjq log --no-graph -r 'trunk()..@ & files("NOTES.md")' -T 'description.first_line() ++ "\n"')" = "chore: add notes"
}

check_m2() {
  need_lab
  if origin_has low-stock; then pass M2.4 "origin has bookmark low-stock"; else fail M2.4 "origin has bookmark low-stock" "jj bookmark create low-stock -r <feat change>; jj git push --bookmark low-stock"; return; fi
  local subjects; subjects="$(origin_log low-stock)"
  ok M2.4 "low-stock contains the teammate's commit (rebased onto new main)" "jj git fetch; jj rebase -b low-stock -o main; push again" \
     git --git-dir="$ORIGIN" merge-base --is-ancestor refs/heads/main refs/heads/low-stock
  local top2; top2="$(echo "$subjects" | head -2 | tr '\n' '|')"
  [ "$top2" = "feat: add low_stock report|docs: document low_stock report|" ] && pass M2.2 "stack is docs change, then feat change on top" || fail M2.2 "top two commits are feat (newest) then docs (found: $top2)" "jj split -m \"docs: ...\" README.md from the combined change"
  local n; n="$(git --git-dir="$ORIGIN" rev-list --count refs/heads/main..refs/heads/low-stock)"
  [ "$n" = 2 ] && pass M2.2 "exactly two commits beyond main (fixup squashed away)" || fail M2.2 "exactly two commits beyond main (found $n)" "jj squash the fix into its parent"
  local feat_files docs_files
  feat_files="$(git --git-dir="$ORIGIN" show --format= --name-only low-stock | sort | tr '\n' ' ')"
  docs_files="$(git --git-dir="$ORIGIN" show --format= --name-only low-stock~1 | sort | tr '\n' ' ')"
  [ "$docs_files" = "README.md " ] && pass M2.2 "docs commit touches only README.md" || fail M2.2 "docs commit touches only README.md (found: $docs_files)"
  [ "$feat_files" = "inventory.py test_inventory.py " ] && pass M2.2 "feat commit touches inventory.py and test_inventory.py" || fail M2.2 "feat commit touches only inventory.py and test_inventory.py (found: $feat_files)"
  ok M2.1 "docstring fix was squashed into the feat commit" "jj new; edit; jj squash" \
     sh -c "git --git-dir='$ORIGIN' show low-stock:inventory.py | grep -q 'Return the sorted names of items whose count is below threshold.'"
  ok M2.T "tests pass at origin/low-stock" "run python3 -m unittest -q in a workspace at low-stock" tests_pass_at_origin low-stock
}

check_m3() {
  need_lab; cd "$APP"
  if origin_has integration; then pass M3.T "origin has bookmark integration"; else fail M3.T "origin has bookmark integration" "jj bookmark create integration -r <top of stack>; jj git push --bookmark integration"; return; fi
  local s; s="$(origin_log main..integration)"
  for d in "feat: reject non-positive quantities" "feat: add item_count()" "docs: clarify remove_item semantics"; do
    echo "$s" | grep -qxF "$d" && pass M3.4 "integration contains \"$d\"" || fail M3.4 "integration contains \"$d\""
  done
  ok M3.5 "no conflict markers in integration" "resolve every conflicted change before pushing" \
     sh -c "! git --git-dir='$ORIGIN' grep -q -e '^<<<<<<<' -e '^>>>>>>>' integration --"
  ok M3.5 "tests pass at origin/integration" "fix the resolution so both sides' code and tests survive" tests_pass_at_origin integration
  local ws; ws="$(jjq workspace list -T 'name ++ "\n"' | tr '\n' ' ')"
  [ "$ws" = "default " ] && pass M3.2 "agent workspaces forgotten after integration" || fail M3.2 "only the default workspace remains (found: $ws)" "jj workspace forget validate count docs"
}

check_m4() {
  need_lab; cd "$APP"
  case "$1" in
    stale)
      ok M4.T "workspace count is usable (not stale)" "cd ../app-ws/count && jj workspace update-stale" sh -c "cd '$JJ_LAB/app-ws/count' && jj --no-pager status"
      ok M4.T "count's work sits on top of the new main" "" test -n "$(jjq log --no-graph -r 'count@- & trunk()+' -T 'change_id')"
      ;;
    undo)
      ok M4.2 "agent's \"feat: add item_count()\" is back" "jj redo (or jj op restore <op before your undo>)" \
         test -n "$(jjq log --no-graph -r 'description(exact:"feat: add item_count()\n")' -T change_id)"
      ok M4.2 "your \"human: add meeting notes\" change is taken back" "jj op revert <id of YOUR operation whose description starts with commit>" \
         test -z "$(jjq log --no-graph -r 'description(substring:"human: add meeting notes")' -T change_id)"
      ok M4.2 "NOTES.md still exists in your working copy" "" test -f "$APP/NOTES.md"
      ;;
    divergent)
      ok M4.3 "no divergent changes remain" "jj abandon <change-id>/1 (keep the version you want)" test -z "$(jjq log --no-graph -r 'divergent()' -T change_id)"
      ok M4.3 "the validate change still exists exactly once" "" \
         test "$(jjq log --no-graph -r 'validate@-' -T '"x"')" = x
      ;;
    wipe)
      ok M4.4 "test_inventory.py restored in the agent's stack" "jj restore --from 'trunk()' --into <feat change> test_inventory.py" \
         sh -c "cd '$JJ_LAB/app-ws/count' && jj --no-pager status >/dev/null && test -f test_inventory.py"
      ok M4.4 "item_count() kept" "" sh -c "grep -q 'def item_count' '$JJ_LAB/app-ws/count/inventory.py'"
      ok M4.4 "changelog change kept on top" "" test -n "$(jjq log --no-graph -r 'description(substring:"docs: start a changelog") & count@-' -T change_id)"
      ok M4.4 "the change that added item_count() no longer deletes the tests" "restore into the feat change, not a new one" \
         test -z "$(jjq log --no-graph -r 'description(substring:"feat: add item_count()") & files("test_inventory.py")' -T change_id)"
      ok M4.4 "tests pass in the agent's workspace" "" sh -c "cd '$JJ_LAB/app-ws/count' && python3 -m unittest -q"
      ;;
    secret)
      local ws="$JJ_LAB/app-ws/count"
      ok M4.5 "count workspace usable" "cd ../app-ws/count && jj workspace update-stale" sh -c "cd '$ws' && jj --no-pager status"
      ok M4.5 ".env.local is ignored" "add it (or .env*) to .gitignore" sh -c "cd '$ws' && git --git-dir='$APP/.git' --work-tree=. check-ignore -q .env.local"
      ok M4.5 ".env.local not in the working-copy change" "jj file untrack .env.local (after ignoring it)" \
         test -z "$(cd "$ws" && jjq file list -r @ .env.local 2>/dev/null)"
      ok M4.5 "no visible change touches .env.local" "" test -z "$(jjq log --no-graph -r 'all()' -T change_id -- .env.local 2>/dev/null)"
      ;;
    *) echo "unknown: m4-$1"; fails=$((fails+1));;
  esac
}

check_m5() {
  need_lab; cd "$APP"
  ok M5.1 "AGENTS.md exists and names the jj protocol" "Module 5.2" sh -c "grep -qi 'jj new' AGENTS.md && grep -qi 'jj workspace' AGENTS.md"
  ok M5.1 "CLAUDE.md imports AGENTS.md" "put @AGENTS.md in CLAUDE.md" grep -q '@AGENTS.md' CLAUDE.md
  if [ -f .claude/settings.json ]; then
    ok M5.2 ".claude/settings.json is valid JSON" "" node -e "JSON.parse(require('fs').readFileSync('.claude/settings.json','utf8'))"
    ok M5.2 "Claude: allows jj" "permissions.allow: \"Bash(jj *)\"" node -e "const s=JSON.parse(require('fs').readFileSync('.claude/settings.json','utf8'));process.exit((s.permissions?.allow||[]).includes('Bash(jj *)')?0:1)"
    ok M5.2 "Claude: denies git commit and git push" "" node -e "const d=(JSON.parse(require('fs').readFileSync('.claude/settings.json','utf8')).permissions?.deny)||[];process.exit(d.includes('Bash(git commit *)')&&d.includes('Bash(git push *)')?0:1)"
    ok M5.2 "Claude: sets JJ_AGENT=1" "env: {\"JJ_AGENT\": \"1\"}" node -e "const s=JSON.parse(require('fs').readFileSync('.claude/settings.json','utf8'));process.exit(s.env?.JJ_AGENT==='1'?0:1)"
  else fail M5.2 ".claude/settings.json exists" "Module 5.3"; fi
  if command -v codex-jj >/dev/null; then
    pass M5.3 "codex-jj launcher on PATH"
    if command -v codex >/dev/null; then
      ok M5.3 "Codex sandbox lets jj write here (codex-jj --probe)" "see Module 5.4" sh -c "codex-jj --probe"
    else pass M5.3 "codex not installed; probe skipped"; fi
  else fail M5.3 "codex-jj launcher on PATH" "copy $JJ_COURSE/plugins/jj-agents/templates/codex/codex-jj to ~/.local/bin (Module 5.4)"; fi
  if [ -f .codex/rules/jj.rules ]; then
    if command -v codex >/dev/null; then
      ok M5.3 "Codex rules forbid git commit" "prefix_rule(pattern=[\"git\", [\"commit\", ...]], decision=\"forbidden\")" \
         sh -c "codex execpolicy check --rules .codex/rules/jj.rules -- git commit -m x | grep -q forbidden"
      ok M5.3 "Codex rules do not forbid jj commit" "" \
         sh -c "! codex execpolicy check --rules .codex/rules/jj.rules -- jj commit -m x | grep -q forbidden"
    else pass M5.3 "Codex rules file present (codex not installed; not executed)"; fi
  else fail M5.3 ".codex/rules/jj.rules exists" "Module 5.4"; fi
  ok M5.T "configuration committed in a change described \"chore: configure agents for jj\"" "jj commit -m \"chore: configure agents for jj\"" \
     test -n "$(jjq log --no-graph -r 'description(substring:"chore: configure agents for jj") & files("AGENTS.md")' -T change_id)"
  ok M5.4 "Kiro: steering file present" "Module 5.5" test -f .kiro/steering/jj.md
  ok M5.4 "Kiro: steering is always included" "" grep -q '^inclusion: always' .kiro/steering/jj.md
  if [ -f .kiro/agents/jj-agent.json ]; then
    ok M5.4 "Kiro: agent JSON denies git commit" "permissions.rules with effect deny" node -e "const a=JSON.parse(require('fs').readFileSync('.kiro/agents/jj-agent.json','utf8'));const r=(a.permissions?.rules||[]).filter(x=>x.effect==='deny').flatMap(x=>x.match||[]);process.exit(r.some(m=>m.startsWith('git commit'))?0:1)"
  else fail M5.4 ".kiro/agents/jj-agent.json exists" "Module 5.5"; fi
}

check_m6() {
  local p="${1:-}"
  [ -n "$p" ] && [ -d "$p" ] || { echo "usage: check.sh m6 <plugin-dir>"; exit 1; }
  ok M6.1 "Agent Plugins manifest (plugin.json) with the v1 \$schema" "Module 6.2" \
     node -e "const m=JSON.parse(require('fs').readFileSync('$p/plugin.json','utf8'));process.exit(m['\$schema']==='https://agent-plugins.org/schemas/1.0.0/plugin.schema.json'&&/^[a-z0-9][a-z0-9.-]*[a-z0-9]\$/.test(m.name)?0:1)"
  ok M6.1 "Claude manifest (.claude-plugin/plugin.json) with the same name" "" \
     node -e "const a=JSON.parse(require('fs').readFileSync('$p/plugin.json','utf8'));const b=JSON.parse(require('fs').readFileSync('$p/.claude-plugin/plugin.json','utf8'));process.exit(a.name===b.name?0:1)"
  local skill; skill="$(ls -d "$p"/skills/*/ 2>/dev/null | head -1)"
  if [ -n "$skill" ] && [ -f "$skill/SKILL.md" ]; then
    local sname; sname="$(basename "$skill")"
    ok M6.2 "SKILL.md name matches its folder ($sname)" "frontmatter name: $sname" grep -qx "name: $sname" "$skill/SKILL.md"
    ok M6.2 "SKILL.md frontmatter uses only portable fields" "allowed: name, description, license, compatibility, metadata" \
       node -e "const t=require('fs').readFileSync('$skill/SKILL.md','utf8');const fm=t.split('---')[1]||'';const keys=fm.split('\n').filter(l=>/^[A-Za-z_-]+:/.test(l)).map(l=>l.split(':')[0]);process.exit(keys.every(k=>['name','description','license','compatibility','metadata'].includes(k))&&keys.includes('description')?0:1)"
    ok M6.2 "SKILL.md body under 500 lines (progressive disclosure)" "move detail into references/" test "$(wc -l < "$skill/SKILL.md")" -lt 500
    ok M6.2 "every references/ file named in SKILL.md exists" "create the file or fix the link" \
       sh -c "cd '$skill' && for r in \$(grep -o 'references/[A-Za-z0-9._-]*\.md' SKILL.md | sort -u); do test -f \"\$r\" || exit 1; done"
    ok M6.2 "SKILL.md links your team conventions (references/team.md)" "Module 6 task, step 2" \
       sh -c "grep -q 'references/team.md' '$skill/SKILL.md' && test -s '$skill/references/team.md'"
  else fail M6.2 "skills/<name>/SKILL.md present"; fi
  ok M6.3 "Agent Plugins mcp.json with the v1 \$schema and a stdio server" "" \
     node -e "const m=JSON.parse(require('fs').readFileSync('$p/mcp.json','utf8'));process.exit(m['\$schema']==='https://agent-plugins.org/schemas/1.0.0/mcp.schema.json'&&Object.values(m.mcpServers).every(s=>s.type==='stdio'||s.type==='streamable-http')?0:1)"
  ok M6.3 "Claude .mcp.json present" "" test -f "$p/.mcp.json"
  if [ -d "$APP/.jj" ] && [ -f "$p/tests/mcp-smoke.mjs" ]; then
    ok M6.3 "MCP server smoke test passes against the lab repo" "node $p/tests/mcp-smoke.mjs $APP" node "$p/tests/mcp-smoke.mjs" "$APP"
  fi
  local here; here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -d "$APP/.jj" ]; then
    ok M6.3 "MCP server lists a jj_evolog tool" "Module 6 task, step 3" \
       sh -c "node '$here/mcp-call.mjs' node '$p/mcp/server.mjs' -- list | grep -qx jj_evolog"
    ok M6.3 "jj_evolog returns a JSON array for @" "" \
       sh -c "node '$here/mcp-call.mjs' node '$p/mcp/server.mjs' -- call jj_evolog '{\"workspace\":\"$APP\",\"revision\":\"@\"}' | node -e 'let s=\"\";process.stdin.on(\"data\",d=>s+=d).on(\"end\",()=>process.exit(Array.isArray(JSON.parse(s))?0:1))'"
  fi
  if command -v jj-agents-mcp >/dev/null; then
    ok M6.5 "the jj-agents-mcp command on PATH (used by Codex and Kiro) is your server" "npm install -g --install-links <your-plugin>/mcp" \
       sh -c "node '$here/mcp-call.mjs' jj-agents-mcp -- list | grep -qx jj_evolog"
  fi
  if [ -f "$p/tests/hooks-test.mjs" ]; then ok M6.4 "hook tests pass" "node $p/tests/hooks-test.mjs" node "$p/tests/hooks-test.mjs"; fi
  if command -v claude >/dev/null; then ok M6.5 "claude plugin validate passes" "claude plugin validate $p" claude plugin validate "$p"; else echo "SKIP  M6.5   claude not installed"; fi
}

check_capstone() {
  local plugin="${1:-}"
  need_lab; cd "$APP"
  echo "== Criterion 1 (C1): setup"
  local sub; sub="$( (fails=0; check_setup; exit $fails) 2>&1 )" && pass C1 "1. setup check passes" || fail C1 "1. setup check passes" "check.sh setup"
  printf '%s\n' "$sub" | sed 's/^/     /' 
  if ! origin_has release; then fail C2 "origin has bookmark release" "Capstone step 8"; return; fi
  pass C2 "origin has bookmark release"
  ok C2 "2. release is on top of the latest origin/main (teammate's commit included)" "jj git fetch; jj rebase -b release -o 'trunk()'" \
     sh -c "git --git-dir='$ORIGIN' log --format=%s release | grep -qxF 'docs: add CONTRIBUTING.md'"
  local n; n="$(git --git-dir="$ORIGIN" rev-list --count refs/heads/main..refs/heads/release)"
  [ "$n" = 5 ] && pass C2 "3. exactly five changes beyond main (config + four tasks), one purpose each" || fail C2 "3. exactly five changes beyond main (found $n)" "squash fixups; one change per task"
  local ws; ws="$(jjq workspace list -T 'name ++ "\n"' | tr '\n' ' ')"
  [ "$ws" = "default " ] && pass C3 "4. all agent workspaces forgotten" || fail C3 "4. only the default workspace remains (found: $ws)"
  local s; s="$(origin_log main..release)"
  for d in "chore: configure agents for jj" "feat: reject non-positive quantities" "feat: add item_count()" "feat: add low_stock report" "docs: document all public functions"; do
    echo "$s" | grep -qxF "$d" && pass C3 "5. release contains \"$d\"" || fail C3 "5. release contains \"$d\""
  done
  ok C3 "5. docs/API.md documents low_stock and item_count (dependent task started from integrated work)" "start the docs agent's workspace from the integrated stack" \
     sh -c "git --git-dir='$ORIGIN' show release:docs/API.md | grep -q low_stock && git --git-dir='$ORIGIN' show release:docs/API.md | grep -q item_count"
  ok C3 "6. tests pass at origin/release" "" tests_pass_at_origin release
  ok C3 "6. no conflict markers at origin/release" "" sh -c "! git --git-dir='$ORIGIN' grep -q -e '^<<<<<<<' -e '^>>>>>>>' release --"
  ok C4 "7. no divergent changes" "Module 4.4" test -z "$(jjq log --no-graph -r 'divergent()' -T change_id)"
  ok C4 "8. no visible change contains .env.local" "Module 4.6" test -z "$(jjq log --no-graph -r 'all()' -T change_id -- .env.local 2>/dev/null)"
  ok C4 "8. .env.local not published" "" sh -c "! git --git-dir='$ORIGIN' cat-file -e release:.env.local 2>/dev/null"
  for f in AGENTS.md CLAUDE.md .claude/settings.json .codex/rules/jj.rules .kiro/steering/jj.md .kiro/agents/jj-agent.json; do
    ok C5 "9. release contains $f" "Module 5" sh -c "git --git-dir='$ORIGIN' cat-file -e release:$f"
  done
  if [ -n "$plugin" ]; then
    sub="$( (fails=0; check_m6 "$plugin"; exit $fails) 2>&1 )" && pass C6 "10. plugin check passes" || fail C6 "10. plugin check passes" "check.sh m6 $plugin"
    printf '%s\n' "$sub" | sed 's/^/     /' 
  else fail C6 "10. plugin checked" "run: check.sh capstone <your-plugin-dir>"; fi
}

task="${1:-}"; shift || true
case "$task" in
  setup) check_setup ;;
  m1) check_m1 ;;
  m2) check_m2 ;;
  m3) check_m3 ;;
  m4-*) check_m4 "${task#m4-}" ;;
  m5) check_m5 ;;
  m6) check_m6 "$@" ;;
  capstone) check_capstone "$@" ;;
  *) sed -n '2,15p' "$0"; exit 2 ;;
esac
echo
if [ "$fails" -eq 0 ]; then echo "All checks passed."; else echo "$fails check(s) failed."; fi
exit "$fails"
