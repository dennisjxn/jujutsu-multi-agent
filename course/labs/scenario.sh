#!/usr/bin/env bash
# scenario.sh — builds a broken multi-agent state for Module 4 (Recovery).
# Usage: scenario.sh <name>
#   stale      Another workspace rewrote agent "count"'s change; its working copy is stale.
#   undo       You ran `jj undo` to take back your own commit — but an agent committed after you.
#   divergent  Two agents rewrote the same change at the same time; it now has two versions.
#   wipe       An agent deleted the test file in the same change as good work, then kept going.
#   secret     An agent wrote a credential file that jj snapshotted into history.
# Each scenario starts from a fresh lab (lab.sh reset) and prints what you are looking at.
# Check your fix with: check.sh m4-<name>
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JJ_LAB="${JJ_LAB:-$HOME/jj-lab}"
name="${1:?usage: scenario.sh stale|undo|divergent|wipe|secret}"
q() { JJ_AGENT=1 jj "$@" >/dev/null 2>&1; }

"$HERE/lab.sh" reset >/dev/null
cd "$JJ_LAB/app"
mkdir -p ../app-ws

case "$name" in
  stale)
    q workspace add ../app-ws/count --name count -r 'trunk()'
    "$HERE/agent.sh" count ../app-ws/count >/dev/null
    # A teammate moves main; you (in the default workspace) rebase the agent's work onto it.
    # That rewrites count@ — the agent's working-copy change — behind the agent's back.
    "$HERE/lab.sh" teammate >/dev/null
    q git fetch
    q rebase -s 'count@-' -o 'trunk()'
    echo "Scenario ready. You rebased agent \"count\"'s work onto the new main from $JJ_LAB/app."
    echo "Now run any jj command in the agent's workspace: cd $JJ_LAB/app-ws/count && jj status"
    ;;
  undo)
    q workspace add ../app-ws/count --name count -r 'trunk()'
    echo "Meeting notes: ship item_count() this week." > NOTES.md
    q commit -m "human: add meeting notes"
    "$HERE/agent.sh" count ../app-ws/count >/dev/null
    q undo
    echo "Scenario ready. You meant to take back your commit \"human: add meeting notes\"."
    echo "You ran \`jj undo\` in $JJ_LAB/app — but agent \"count\" had committed after you."
    echo "Goal: agent's \"feat: add item_count()\" restored; your notes change taken back (NOTES.md uncommitted in @)."
    ;;
  divergent)
    q workspace add ../app-ws/validate --name validate -r 'trunk()'
    "$HERE/agent.sh" validate ../app-ws/validate >/dev/null
    target="$(jj --no-pager log --no-graph -r 'validate@-' -T 'change_id.short(12)')"
    before="$(jj --no-pager op log --no-graph -n1 -T 'id.short(12)')"
    # Agent 1 (in its workspace) rewords its change...
    (cd ../app-ws/validate && q describe -r "$target" -m "feat: reject zero and negative quantities")
    # ...while agent 2, working from a view of the repo taken *before* that rewrite, also edits it.
    q --at-op="$before" describe -r "$target" -m "feat: validate quantities in add/remove"
    q status   # the next command merges the two operation-log branches
    echo "Scenario ready. Change $target was rewritten by two agents at once."
    echo "Look: cd $JJ_LAB/app && jj log -r 'divergent()'"
    ;;
  wipe)
    q workspace add ../app-ws/count --name count -r 'trunk()'
    (cd ../app-ws/count && JJ_AGENT=1 python3 - <<'PY'
p = "inventory.py"; s = open(p).read().rstrip("\n")
s += '''


def item_count():
    """Number of distinct items with a positive count."""
    return sum(1 for qty in ITEMS.values() if qty > 0)
'''
open(p, "w").write(s)
PY
    rm -f test_inventory.py
    q commit -m "feat: add item_count(); clean up tests"
    echo "# Changelog" > CHANGELOG.md
    q commit -m "docs: start a changelog")
    echo "Scenario ready. Agent \"count\" added item_count() AND deleted test_inventory.py in one change,"
    echo "then built another change on top. Goal: keep item_count() and the changelog; bring the tests back."
    ;;
  secret)
    q workspace add ../app-ws/count --name count -r 'trunk()'
    "$HERE/agent.sh" secret ../app-ws/count >/dev/null
    echo "Scenario ready. Agent \"count\" wrote .env.local containing a (fake) credential in $JJ_LAB/app-ws/count."
    echo "Goal: the file is no longer tracked, is ignored from now on, and no visible commit contains it."
    ;;
  *) echo "unknown scenario: $name" >&2; exit 2 ;;
esac
