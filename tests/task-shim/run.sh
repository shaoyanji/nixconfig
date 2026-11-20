#!/usr/bin/env bash
# Regression fixture for modules/user/task-shim.nix — the emitted ~/Taskfile.yml.
#
# A temp $HOME gets the same shim file the module ships and a
# Documents/nixconfig symlink at this checkout, then `task --list` must exit 0
# and name a repo task — that is the case the note's exit criteria ask to prove.
# The second case re-creates the measured 203 failure (a root task whose name
# collides with a flattened include) and must exit nonzero with "multiple
# tasks", so this gate is proved able to fail, not just able to pass.
#
# Exit: 0 both cases behave, 2 the fixture cannot run (no task binary, no shim).
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
shim="$repo/modules/user/task-shim.yml"

command -v task >/dev/null 2>&1 || { echo "fixture: no task binary on PATH" >&2; exit 2; }
[ -f "$shim" ] || { echo "fixture: $shim missing" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/Documents"
ln -s "$repo" "$tmp/Documents/nixconfig"
cp "$shim" "$tmp/Taskfile.yml"

fail=0
check() { # name want_rc needle
  local name="$1" want="$2" needle="$3" out rc
  out="$(cd "$tmp" && HOME="$tmp" task --list 2>&1)"
  rc=$?
  if [ "$rc" -ne "$want" ]; then
    echo "FAIL $name: want rc=$want got rc=$rc" >&2
    echo "$out" | head -5 >&2
    fail=1
  elif [ -n "$needle" ] && ! grep -q "$needle" <<<"$out"; then
    echo "FAIL $name: rc=$rc but output lacks '$needle'" >&2
    fail=1
  else
    echo "ok   $name"
  fi
}

check "shim alone lists repo tasks" 0 "checks:quick"

# The measured 203 class: the same taskfile flattened in twice names every
# task twice.
cat >>"$tmp/Taskfile.yml" <<'EOF'
    nixconfig2:
        taskfile: ~/Documents/nixconfig/Taskfile.yml
        dir: ~/Documents/nixconfig
        flatten: true
EOF
check "a duplicate flattened include fails" 203 "multiple tasks"

exit "$fail"
