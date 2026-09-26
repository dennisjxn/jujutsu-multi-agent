#!/usr/bin/env bash
# agent.sh — a scripted stand-in for an AI coding agent, so the labs run without a model.
# Usage: agent.sh <task> [directory]
#   Performs one task's file edits in <directory> (default: current directory), exactly as a
#   well-behaved agent following the course protocol would, then finishes with `jj commit`.
# Tasks:
#   validate   feat: reject non-positive quantities   (edits add_item/remove_item)
#   count      feat: add item_count()                  (appends a function and a test)
#   docs       docs: clarify remove_item semantics      (edits the remove_item docstring)
#   lowstock   feat: add low_stock report               (appends a function and a test; capstone)
#   docsall    docs: document all public functions      (writes docs/API.md from inventory.py; capstone)
#   secret     writes a fake credential to .env.local   (used in Module 4)
#   wipe       an agent that "cleans up" by deleting test_inventory.py (used in Module 4)
set -euo pipefail
task="${1:?usage: agent.sh <task> [directory]}"
dir="${2:-.}"
cd "$dir"
export JJ_AGENT=1   # agent mode: activates the non-interactive jj settings from Module 0

edit() { python3 - "$@"; }

case "$task" in
  validate)
    edit <<'PY'
p = "inventory.py"; s = open(p).read()
s = s.replace('''    """Add qty units of name; return the new count."""
    ITEMS[name]''', '''    """Add qty units of name; return the new count."""
    if qty <= 0:
        raise ValueError("qty must be positive")
    ITEMS[name]''')
s = s.replace('''    """Remove qty units of name; return the new count."""
    ITEMS[name]''', '''    """Remove qty units of name; return the new count."""
    if qty <= 0:
        raise ValueError("qty must be positive")
    ITEMS[name]''')
open(p, "w").write(s)
t = "test_inventory.py"; s = open(t).read()
s = s.replace('\n\nif __name__', '''
    def test_rejects_non_positive(self):
        with self.assertRaises(ValueError):
            inventory.add_item("bolt", 0)


if __name__''', 1)
open(t, "w").write(s)
PY
    msg="feat: reject non-positive quantities" ;;
  count)
    edit <<'PY'
p = "inventory.py"; s = open(p).read().rstrip("\n")
s += '''


def item_count():
    """Number of distinct items with a positive count."""
    return sum(1 for qty in ITEMS.values() if qty > 0)
'''
open(p, "w").write(s)
t = "test_inventory.py"; s = open(t).read()
s = s.replace('\n\nif __name__', '''
    def test_item_count(self):
        inventory.add_item("bolt", 2)
        inventory.add_item("nut", 1)
        self.assertEqual(inventory.item_count(), 2)


if __name__''', 1)
open(t, "w").write(s)
PY
    msg="feat: add item_count()" ;;
  docs)
    edit <<'PY'
p = "inventory.py"; s = open(p).read()
s = s.replace('''    """Remove qty units of name; return the new count."""
    ITEMS[name]''', '''    """Remove qty units of name; return the new count.

    Counts may go negative: a negative count records a backorder.
    """
    ITEMS[name]''')
open(p, "w").write(s)
PY
    msg="docs: clarify remove_item semantics" ;;
  lowstock)
    edit <<'PY'
p = "inventory.py"; s = open(p).read().rstrip("\n")
s += '''


def low_stock(threshold):
    """Return the sorted names of items whose count is below threshold."""
    return sorted(name for name, qty in ITEMS.items() if qty < threshold)
'''
open(p, "w").write(s)
t = "test_inventory.py"; s = open(t).read()
s = s.replace('\n\nif __name__', '''
    def test_low_stock(self):
        inventory.add_item("bolt", 1)
        inventory.add_item("nut", 9)
        self.assertEqual(inventory.low_stock(5), ["bolt"])


if __name__''', 1)
open(t, "w").write(s)
PY
    msg="feat: add low_stock report" ;;
  docsall)
    mkdir -p docs
    edit <<'PY'
import ast
tree = ast.parse(open("inventory.py").read())
lines = ["# inventory API", ""]
for node in tree.body:
    if isinstance(node, ast.FunctionDef) and not node.name.startswith("_"):
        args = ", ".join(a.arg for a in node.args.args)
        doc = (ast.get_docstring(node) or "").strip().splitlines()
        lines.append(f"## `{node.name}({args})`")
        lines.append("")
        lines.append(doc[0] if doc else "(undocumented)")
        lines.append("")
open("docs/API.md", "w").write("\n".join(lines))
PY
    msg="docs: document all public functions" ;;
  secret)
    printf 'API_TOKEN=sk-live-THIS-IS-A-FAKE-COURSE-SECRET\n' > .env.local
    echo "agent.sh: wrote .env.local (a fake credential)."
    jj status >/dev/null   # any jj command snapshots the working copy
    exit 0 ;;
  wipe)
    rm -f test_inventory.py
    echo "agent.sh: deleted test_inventory.py (\"cleaning up\")."
    msg="chore: clean up test files" ;;
  *) echo "unknown task: $task" >&2; exit 2 ;;
esac

jj commit -m "$msg" >/dev/null 2>&1
echo "agent.sh [$task] done in $(jj workspace root): committed \"$msg\""
