#!/usr/bin/env bash
# lab.sh — builds and resets the course lab. Usage: lab.sh <command>
#   reset        Recreate the lab: a bare Git "origin" with the sample project, and a jj clone in app/
#   teammate     Simulate a teammate pushing a new commit to origin/main
#   status       Print where the lab lives and what is in it
# The lab lives in $JJ_LAB (default: ~/jj-lab). Nothing outside that folder is touched.
set -euo pipefail
JJ_LAB="${JJ_LAB:-$HOME/jj-lab}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Git commands in this script run with a neutral config so personal settings
# (commit signing, hooks, templates) cannot break the lab.
g() { git -c commit.gpgsign=false -c tag.gpgsign=false -c core.hooksPath=/dev/null -c init.templateDir= "$@"; }

seed_project() {
  local dir="$1"
  cat > "$dir/inventory.py" <<'PY'
"""A tiny inventory module used throughout the course labs."""

ITEMS = {}


def add_item(name, qty):
    """Add qty units of name; return the new count."""
    ITEMS[name] = ITEMS.get(name, 0) + qty
    return ITEMS[name]


def remove_item(name, qty):
    """Remove qty units of name; return the new count."""
    ITEMS[name] = ITEMS.get(name, 0) - qty
    return ITEMS[name]


def total():
    """Total units across all items."""
    return sum(ITEMS.values())
PY
  cat > "$dir/test_inventory.py" <<'PY'
import unittest

import inventory


class InventoryTest(unittest.TestCase):
    def setUp(self):
        inventory.ITEMS.clear()

    def test_add(self):
        self.assertEqual(inventory.add_item("bolt", 3), 3)

    def test_remove(self):
        inventory.add_item("bolt", 3)
        self.assertEqual(inventory.remove_item("bolt", 1), 2)

    def test_total(self):
        inventory.add_item("bolt", 3)
        inventory.add_item("nut", 4)
        self.assertEqual(inventory.total(), 7)


if __name__ == "__main__":
    unittest.main()
PY
  cat > "$dir/README.md" <<'MD'
# inventory

A tiny inventory module used in the Jujutsu multi-agent course.

Run the tests with `python3 -m unittest -q`.
MD
  printf '__pycache__/\n*.pyc\n.env\n' > "$dir/.gitignore"
}

cmd_reset() {
  command -v jj >/dev/null || { echo "jj is not on your PATH. Finish Module 0, step 1 first." >&2; exit 1; }
  if [ -d "$JJ_LAB" ]; then
    # Remove any jj workspaces created by earlier labs so nothing points at a deleted repo.
    rm -rf "$JJ_LAB"
  fi
  mkdir -p "$JJ_LAB"
  g init -q --bare -b main "$JJ_LAB/origin.git"
  local seed; seed="$(mktemp -d)"
  g init -q -b main "$seed"
  seed_project "$seed"
  g -C "$seed" add -A
  g -C "$seed" -c user.name="Course Seed" -c user.email="seed@example.com" commit -q -m "initial inventory module"
  g -C "$seed" push -q "$JJ_LAB/origin.git" main 2>/dev/null
  rm -rf "$seed"
  (cd "$JJ_LAB" && jj git clone origin.git app >/dev/null 2>&1)
  echo "Lab ready:"
  echo "  remote : $JJ_LAB/origin.git   (a bare Git repository standing in for GitHub)"
  echo "  clone  : $JJ_LAB/app          (a colocated jj + Git repository — work here)"
}

cmd_teammate() {
  local tmp; tmp="$(mktemp -d)"
  g clone -q "$JJ_LAB/origin.git" "$tmp/c"
  cat > "$tmp/c/CONTRIBUTING.md" <<'MD'
# Contributing

Open a pull request against `main`. Run `python3 -m unittest -q` first.
MD
  g -C "$tmp/c" add -A
  g -C "$tmp/c" -c user.name="Teammate" -c user.email="teammate@example.com" commit -q -m "docs: add CONTRIBUTING.md"
  g -C "$tmp/c" push -q origin main 2>/dev/null
  rm -rf "$tmp"
  echo "A teammate pushed \"docs: add CONTRIBUTING.md\" to origin/main. Run: jj git fetch"
}

cmd_status() {
  echo "JJ_LAB=$JJ_LAB"
  [ -d "$JJ_LAB/app" ] && (cd "$JJ_LAB/app" && jj --no-pager log -r 'all()' -n 12) || echo "No lab yet: run lab.sh reset"
}

case "${1:-}" in
  reset) cmd_reset ;;
  teammate) cmd_teammate ;;
  status) cmd_status ;;
  *) sed -n '2,7p' "$0"; exit 2 ;;
esac
