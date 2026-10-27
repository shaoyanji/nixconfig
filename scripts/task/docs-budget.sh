#!/usr/bin/env bash
# docs-budget.sh — the living-document budgets (`.agents/SCHEMA.md` §2).
#
# One implementation behind every surface that asks the question:
#   task ops:docs:budget                  (human/agent)
#   checks.<system>.docs-budget           (nix flake check, and the CI job that
#                                          runs it on every push, doc-only included)
# It counts tracked files and builds nothing, so a doc-only change is gated
# without allocating a build runner.
#
# Exit: 0 every document within budget, 1 on a violation.
set -euo pipefail

# The flake check runs this from a store copy (no .git), so fall back to the
# script's own location; both resolve to the repository root.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if root="$(git -C "$here" rev-parse --show-toplevel 2>/dev/null)"; then
  cd "$root"
else
  cd "$here/../.."
fi

fail=0
check() {
  f="$1"
  max="$2"
  if [ ! -f "$f" ]; then
    echo "MISSING $f"
    fail=1
    return
  fi
  n=$(wc -l <"$f")
  if [ "$n" -gt "$max" ]; then
    echo "OVER  $f: $n > $max"
    fail=1
  else
    echo "ok    $f: $n / $max"
  fi
}

stub() {
  f="$1"
  max=10
  if [ ! -f "$f" ]; then
    echo "MISSING $f"
    fail=1
    return
  fi
  n=$(wc -l <"$f")
  if [ "$n" -gt "$max" ]; then
    echo "NOT-A-STUB $f: $n > $max lines (content belongs in AGENTS.nix)"
    fail=1
  elif ! grep -q 'AGENTS.nix' "$f"; then
    echo "NOT-A-STUB $f: does not point at AGENTS.nix"
    fail=1
  else
    echo "ok    $f: stub ($n lines) -> AGENTS.nix"
  fi
}

check AGENTS.md 1200
check MANUAL.md 1200
check AUDIT.md 150
stub ARCHITECTURE.md
stub TODO.md
stub HANDOFF.md
stub EXPERIMENTS.md

# Runbook class (`.agents/SCHEMA.md` §2), 400 lines: `docs/*.md` and `.agents/**/*.md`.
# The list is derived rather than hand-kept, because three runbooks drifted past the
# budget with nothing enumerating them: the hand-checked class above was green while
# `docs/dns-failover.md` sat at 618 lines. `docs/history/` is the archive and has no
# budget; skill bodies are `lib/skills.nix`'s to gate, so both are excluded here.
if git rev-parse --git-dir >/dev/null 2>&1; then
  runbooks="$(git ls-files 'docs/*.md' '.agents/**/*.md')"
else
  runbooks="$(find docs .agents -name '*.md' 2>/dev/null)"
fi
while read -r f; do
  [ -n "$f" ] || continue
  case "$f" in
    docs/history/* | .agents/skills/*) continue ;;
  esac
  check "$f" 400
done <<EOF
$runbooks
EOF

exit "$fail"
