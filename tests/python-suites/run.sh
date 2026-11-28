#!/usr/bin/env bash
# Regression fixture for `checks:suites` (scripts/task/python-suites.sh).
#
# The runner's failure mode is silence: a discoverer that matches nothing, or a
# suite whose failure it swallows, reports a clean run. So the fixture seeds a
# root with one passing and one failing suite and asserts the runner refuses at
# exit 1 naming the failing one, that a clean root is reported with its count,
# and that an empty root is exit 2 rather than a clean run.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
runner="$repo/scripts/task/python-suites.sh"
[ -f "$runner" ] || { echo "fixture: no $runner" >&2; exit 2; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/root/good" "$work/root/bad" "$work/clean/good" "$work/empty"

cat >"$work/root/good/test_ok.py" <<'PY'
import unittest


class Ok(unittest.TestCase):
    def test_true(self):
        self.assertTrue(True)
PY

cat >"$work/clean/good/test_ok.py" <<'PY'
import unittest


class Ok(unittest.TestCase):
    def test_true(self):
        self.assertTrue(True)
PY

cat >"$work/root/bad/test_broken.py" <<'PY'
import unittest


class Broken(unittest.TestCase):
    def test_false(self):
        self.assertEqual(1 + 1, 3)
PY

fail=0

out=$(SUITES_ROOT="$work/root" bash "$runner" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'bad'; then
  echo "ok   a failing suite is refused and named"
else
  echo "FAIL seeded root: rc=$rc — expected exit 1 naming bad"; echo "$out" | tail -8; fail=1
fi

out=$(SUITES_ROOT="$work/clean" bash "$runner" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '1 suite'; then
  echo "ok   a passing root is reported with its count"
else
  echo "FAIL clean root: rc=$rc — expected exit 0"; echo "$out" | tail -8; fail=1
fi

out=$(SUITES_ROOT="$work/empty" bash "$runner" 2>&1); rc=$?
if [ $rc -eq 2 ]; then
  echo "ok   an empty root refuses instead of passing"
else
  echo "FAIL empty root: rc=$rc — expected exit 2"; echo "$out" | tail -8; fail=1
fi

[ $fail -eq 0 ] && echo "python-suites:test: all cases pass"
exit $fail
