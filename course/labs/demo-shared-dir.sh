#!/usr/bin/env bash
# demo-shared-dir.sh — what happens when two agents share ONE working directory.
# Resets the lab, then runs two scripted "agents" in ~/jj-lab/app at the same time:
#   agent X writes x.txt, thinks for 2 seconds, then runs `jj commit -m "agent X: add x.txt"`
#   agent Y writes y.txt 1 second later, thinks for 2 seconds, then commits "agent Y: add y.txt"
# Then it prints which files ended up in which change.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JJ_LAB="${JJ_LAB:-$HOME/jj-lab}"
"$HERE/lab.sh" reset >/dev/null
cd "$JJ_LAB/app"
export JJ_AGENT=1
( echo "agent X was here" > x.txt; sleep 2; jj commit -m "agent X: add x.txt" >/dev/null 2>&1 ) &
( sleep 1; echo "agent Y was here" > y.txt; sleep 2; jj commit -m "agent Y: add y.txt" >/dev/null 2>&1 ) &
wait
echo "Changes after both agents finished (newest first):"
jj --no-pager log --no-graph -r 'trunk()..' \
  -T 'change_id.short(8) ++ "  " ++ if(description, description.first_line(), "(no description)") ++ "   files: " ++ self.diff().files().map(|f| f.path()).join(", ") ++ "\n"'
