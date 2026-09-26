#!/usr/bin/env bash
# capstone.sh — drives the Module 7 capstone.
# Usage:
#   capstone.sh start      Reset the lab and print the brief
#   capstone.sh incident   Inject the mid-project incident (run it when the brief says to)
# Check your result with: check.sh capstone
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JJ_LAB="${JJ_LAB:-$HOME/jj-lab}"
q() { JJ_AGENT=1 jj "$@" >/dev/null 2>&1; }

case "${1:-}" in
  start)
    "$HERE/lab.sh" reset >/dev/null
    cat <<EOF
Capstone lab ready in $JJ_LAB/app. The brief is in Module 7, "The brief".
When the three first-wave agents have committed (step 3), run: capstone.sh incident
EOF
    ;;
  incident)
    cd "$JJ_LAB/app"
    ws="$(jj --no-pager workspace list -T 'name ++ "\n"')"
    for need in validate count lowstock; do
      echo "$ws" | grep -qx "$need" || { echo "capstone.sh: workspace \"$need\" not found. Create the first-wave workspaces first (Module 7, step 2)." >&2; exit 1; }
    done
    # 1. A teammate pushes to main.
    "$HERE/lab.sh" teammate >/dev/null
    # 2. The count agent leaves a credential file behind in its workspace.
    "$HERE/agent.sh" secret "$JJ_LAB/app-ws/count" >/dev/null
    # 3. Two processes reword the validate agent's finished change at the same moment.
    target="$(jj --no-pager log --no-graph -r 'validate@-' -T 'change_id.short(12)')"
    before="$(jj --no-pager op log --no-graph -n1 -T 'id.short(12)')"
    (cd "$JJ_LAB/app-ws/validate" && q describe -r "$target" -m "feat: reject non-positive quantities

add_item and remove_item raise ValueError when qty <= 0.")
    q --at-op="$before" describe -r "$target" -m "feat: validate quantities"
    q status
    cat <<'EOF'
Incident injected. Three things just happened, as they would in a real team:
  - someone pushed to origin/main;
  - one of your agents left something in its workspace that must never be published;
  - two processes rewrote the same change at the same time.
Diagnose each from jj's logs (Module 4), repair it, then continue with the brief.
EOF
    ;;
  *) sed -n '2,6p' "$0"; exit 2 ;;
esac
