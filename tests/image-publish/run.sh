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

# The same past tree at the depth the Go arms read: the gate resolves the
# contracts under <dir>/../../tools/{os,image-daily}, so the materialization
# mirrors the repo layout. At 470c9034^ neither tools/os nor tools/image-daily
# exists — the real tree makes every fallback arm dead, not the fixture's
# choice of files.
mkdir -p "$tmp/past"
git archive "470c9034^" scripts tools 2>/dev/null | tar -x -C "$tmp/past" || exit 2
pastdir="$tmp/past/scripts/task"
[ -s "$pastdir/image-daily.sh" ] || { echo "fixture: cannot read the past dispatcher" >&2; exit 2; }

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

# 2b. The same tree, materialized whole so the gate's tools/os and
# tools/image-daily arms are evaluated against real history — on 470c9034^
# neither exists, and the failure must name the provider fallback it could
# not find anywhere.
if bash "$gate" "$pastdir" >"$tmp/past.out" 2>&1; then
  echo "FAIL past tree whole (470c9034^): gate accepted it with the Go arms live"
  fail=1
elif grep -q 'provider fallback' "$tmp/past.out"; then
  echo "ok   past tree whole (470c9034^) fails, naming the missing provider fallback"
else
  echo "FAIL past tree whole (470c9034^): fails but not on the provider fallback"
  fail=1
fi

# 2c. The Go arm is load-bearing on the current tree: lib no longer carries
# modelProvider/GEMINI_API_KEY, so stripping them from tools/os must trip the
# same check the 0-of-43 burn motivated.
mkdir -p "$tmp/mut"
cp -r "$repo/scripts" "$tmp/mut/" "$repo/tools" "$tmp/mut/" 2>/dev/null
chmod -R u+w "$tmp/mut"
grep -rl 'modelProvider\|GEMINI_API_KEY' "$tmp/mut/tools/os" | xargs -r sed -i '/modelProvider\|GEMINI_API_KEY/d'
if bash "$gate" "$tmp/mut/scripts/task" >"$tmp/mut.out" 2>&1; then
  echo "FAIL tools/os without provider fallback: gate accepted a judge that dies with the account"
  fail=1
elif grep -q 'provider fallback' "$tmp/mut.out"; then
  echo "ok   tools/os stripped of the provider route fails, naming the fallback"
else
  echo "FAIL tools/os stripped: fails but not on the provider fallback"
  fail=1
fi

# 2d. The breaker arms are load-bearing: unjudged_streak lives in plates.sh
# AND tools/os today, so both must go before the gate can honestly pass — the
# failure names the circuit breaker the 0-of-43 burn motivated.
mkdir -p "$tmp/mut2"
cp -r "$repo/scripts" "$tmp/mut2/" "$repo/tools" "$tmp/mut2/" 2>/dev/null
chmod -R u+w "$tmp/mut2"
sed -i '/unjudged_streak/d' "$tmp/mut2/scripts/task/image-daily-plates.sh"
grep -rl 'unjudged_streak\|unjudgedStreak' "$tmp/mut2/tools/os" |
  xargs -r sed -i '/unjudged_streak\|unjudgedStreak/d'
if bash "$gate" "$tmp/mut2/scripts/task" >"$tmp/mut2.out" 2>&1; then
  echo "FAIL without breakers: gate accepted a lane that burns allowance unjudged"
  fail=1
elif grep -q 'circuit breaker' "$tmp/mut2.out"; then
  echo "ok   breakers stripped from shell+Go fails, naming the circuit breaker"
else
  echo "FAIL breakers stripped: fails but not on the circuit breaker"
  fail=1
fi

# 2e. The shrink-guard arm is load-bearing: publish_shrink_guard in publish.sh
# AND shrinkGuard in tools/os briefs.go must both go before it can pass — the
# failure names the guard the 2026-11-21 556-to-144 shrink motivated.
mkdir -p "$tmp/mut3"
cp -r "$repo/scripts" "$tmp/mut3/" "$repo/tools" "$tmp/mut3/" 2>/dev/null
chmod -R u+w "$tmp/mut3"
sed -i '/publish_shrink_guard/d' "$tmp/mut3/scripts/task/image-daily-publish.sh"
sed -i '/shrinkGuard/d' "$tmp/mut3/tools/os/internal/image/briefs.go"
if bash "$gate" "$tmp/mut3/scripts/task" >"$tmp/mut3.out" 2>&1; then
  echo "FAIL without shrink guard: gate accepted a publish that can halve the gallery"
  fail=1
elif grep -q 'shrink guard' "$tmp/mut3.out"; then
  echo "ok   shrink guard stripped from shell+Go fails, naming the guard"
else
  echo "FAIL shrink guard stripped: fails but not on the shrink guard"
  fail=1
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
