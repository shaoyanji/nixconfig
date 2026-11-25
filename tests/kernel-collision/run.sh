#!/usr/bin/env bash
# Regression fixture for checks:kernel:collision
# (scripts/task/kernel-collision-check.sh).
#
# A gate that cannot fail is no gate, so the failing input is a real past
# tree, not a retype: b8d2011 is `45dde4c9^`, where base-node.nix held
# `mkOverride 1500` — a tie with the option default in
# nixos/modules/system/boot/kernel.nix (also 1500). On that tree every
# baseline host without its own override failed eval; eisen was the one
# documented broken until 2026-10-19 [[AGENTS.nix#dormant-host-gates]].
# minyx shares the same tree but stays green — raspberry-pi/3's mkDefault
# (1000) wins outright, no tie — so the pair proves the gate flags only the
# collision, not a weaker definition.
#
# Exit: 0 every case behaves, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd -P)"
cd "$repo" || exit 2

gate="$repo/scripts/task/kernel-collision-check.sh"
[ -f "$gate" ] || { echo "fixture: $gate missing" >&2; exit 2; }
command -v nix >/dev/null || { echo "fixture: no nix" >&2; exit 2; }

PRE=b8d201144ab35c52f29fd90f9f912fbeab45960c # 45dde4c9^, mkOverride 1500
fail=0

# 1. The pre-fix tree: eisen must collide, minyx must not.
out=$(REV=$PRE HOSTS="eisen minyx" bash "$gate" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'COLLIDE eisen' &&
   echo "$out" | grep -q 'base-node.nix' && ! echo "$out" | grep -q 'COLLIDE minyx'; then
  echo "ok   $PRE: eisen COLLIDE (base-node vs option default), minyx clean"
else
  echo "FAIL $PRE: rc=$rc — expected eisen-only collision"; echo "$out" | tail -8
  fail=1
fi

# 2. The same pair at HEAD is clean.
if HOSTS="eisen minyx" bash "$gate" >/dev/null 2>&1; then
  echo "ok   HEAD: eisen + minyx clean"
else
  echo "FAIL HEAD: gate refused the live tree"; fail=1
fi

[ $fail -eq 0 ] && echo "kernel-collision:test: all cases pass"
exit $fail
