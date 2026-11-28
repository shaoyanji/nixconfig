#!/usr/bin/env bash
# Regression fixture for `task checks:nix:format`
# (scripts/task/nix-fmt.sh --check --all --tools alejandra).
#
# The format gate is repo-wide, not a host eval, so its host coverage is the
# files it scans. Damage one real projected host file of each kind — NixOS,
# darwin and standalone home — with whitespace alejandra cannot accept. All
# three must be named in one refusal; HEAD must stay clean.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
command -v git >/dev/null || { echo "fixture: no git" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'git -C "$repo" worktree remove --force "$tmp/wt" 2>/dev/null; rm -rf "$tmp"' EXIT

git -C "$repo" worktree add --detach "$tmp/wt" HEAD >/dev/null 2>&1 ||
  { echo "fixture: cannot add worktree" >&2; exit 2; }

if ! git -C "$repo" diff --quiet HEAD --; then
  git -C "$repo" diff --binary HEAD | git -C "$tmp/wt" apply --index ||
    { echo "fixture: cannot apply the checkout diff" >&2; exit 2; }
fi

python3 - "$tmp/wt" <<'PY' ||
from pathlib import Path
import sys
root = Path(sys.argv[1])
for rel in (
    "hosts/aceofspades/configuration.nix",
    "hosts/cassini/configuration.nix",
    "hosts/alarm.nix",
):
    path = root / rel
    text = path.read_text()
    if "{" not in text:
        raise SystemExit(f"{rel}: no opening brace to damage")
    path.write_text(text.replace("{", "{  ", 1))
PY
  { echo "fixture: cannot seed formatting damage" >&2; exit 2; }

fail=0
out=$(cd "$tmp/wt" && bash scripts/task/nix-fmt.sh --check --all --tools alejandra 2>&1); rc=$?
missing=""
for f in hosts/aceofspades/configuration.nix hosts/cassini/configuration.nix hosts/alarm.nix; do
  echo "$out" | grep -q "$f" || missing="$missing $f"
done
if [ $rc -eq 1 ] && [ -z "$missing" ]; then
  echo "ok   NixOS, darwin and home host files refused, all named"
else
  echo "FAIL seeded tree: rc=$rc — expected one alejandra refusal naming each host file"
  [ -z "$missing" ] || echo "missing:$missing"
  echo "$out" | tail -8
  fail=1
fi

if bash "$repo/scripts/task/nix-fmt.sh" --check --all --tools alejandra >/dev/null 2>&1; then
  echo "ok   HEAD passes"
else
  echo "FAIL HEAD: alejandra refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "nix-format:test: all cases pass"
exit $fail
