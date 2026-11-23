#!/usr/bin/env bash
# Regression fixture for the image-daily publish gate
# (scripts/task/image-daily-gate.sh), wired as `gate` and run at the head of
# `publish`.
#
# A gate that cannot fail is no gate, so the failing input is checked out of
# history, not retyped: `470c9034^` is the engine that had no provider
# fallback and no unjudged circuit breaker — the tree that burned 43
# generations across 2026-11-22–23 while the account route was quota-dead and
# kept nothing. The gate must refuse that tree and accept the current one.
#
# Exit: 0 every case behaves, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd -P)"
cd "$repo" || exit 2

gate="$repo/scripts/task/image-daily-gate.sh"
[ -f "$gate" ] || { echo "fixture: $gate missing" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# The past tree: same file set, checked out of the commit before the fallback
# and breakers landed. Any file the past did not have is skipped — the gate
# fails on what is there, not on what is absent.
for f in "$repo"/scripts/task/image-daily*.sh; do
  b=$(basename "$f")
  git show "470c9034^:scripts/task/$b" >"$tmp/$b" 2>/dev/null || true
done
[ -s "$tmp/image-daily.sh" ] || { echo "fixture: cannot read the past dispatcher" >&2; exit 2; }

fail=0

# 1. The current tree passes.
if bash "$gate" "$repo/scripts/task" >/dev/null 2>&1; then
  echo "ok   current tree passes the gate"
else
  echo "FAIL current tree: gate refused the shipped family"
  fail=1
fi

# 2. The past mistake fails — no provider fallback, no breakers.
if bash "$gate" "$tmp" >/dev/null 2>&1; then
  echo "FAIL past tree (470c9034^): gate accepted the family that kept 0 of 43"
  fail=1
else
  echo "ok   past tree (470c9034^) fails the gate"
fi

# 3. Dispatch drift fails: remove one command file from a copy of the current
# tree and the agreement check must name it.
mkdir "$tmp/drift"
cp "$repo"/scripts/task/image-daily*.sh "$tmp/drift/"
rm "$tmp/drift/image-daily-adopt.sh"
if bash "$gate" "$tmp/drift" >/dev/null 2>&1; then
  echo "FAIL dropped command file: gate did not notice adopt is missing"
  fail=1
else
  echo "ok   a dropped command file fails the dispatch check"
fi

# 4. A stray file fails the other direction of the same check.
cp "$repo"/scripts/task/image-daily*.sh "$tmp/drift/"
printf '#!/usr/bin/env bash\n' >"$tmp/drift/image-daily-stray.sh"
if bash "$gate" "$tmp/drift" >/dev/null 2>&1; then
  echo "FAIL stray command file: gate did not notice image-daily-stray.sh"
  fail=1
else
  echo "ok   an undispatched command file fails the dispatch check"
fi

# 5. The dispatcher routes `gate` as a subcommand.
if bash "$repo/scripts/task/image-daily.sh" gate >/dev/null 2>&1; then
  echo "ok   image-daily.sh gate routes through the dispatcher"
else
  echo "FAIL image-daily.sh gate: dispatcher does not route it"
  fail=1
fi

exit "$fail"
