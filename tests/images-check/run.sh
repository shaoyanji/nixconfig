#!/usr/bin/env bash
# Regression fixture for `task checks:images` (scripts/task/images-check.sh).
#
# The gate reads IMAGES_ROOT, so the failing input is a synthetic asset root —
# no worktree needed. The mistake is real: on 2026-11-26 a wall row carried a
# session-gated web.chatplayground.ai render URL (a 401 to anyone but its
# maker) because bankUpload had silently failed — exactly the drift this gate
# exists to refuse. A row present in urls.tsv but missing from the manifest is
# the other arm: an upload nothing can find.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
gate="$repo/scripts/task/images-check.sh"
[ -f "$gate" ] || { echo "fixture: $gate missing" >&2; exit 2; }

bank="https://res.cloudinary.com/fleet/image/upload/v1"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkroot() { # mkroot <dir> [extra tsv line] — a two-row clean root by default
  mkdir -p "$1/published"
  printf 'badge/a.png\t%s/assets/fleet/a.png\t10\n' "$bank" >"$1/published/urls.tsv"
  printf 'plates/b.png\t%s/assets/plates/b.png\t10\n' "$bank" >>"$1/published/urls.tsv"
  [ $# -gt 1 ] && printf '%s\n' "$2" >>"$1/published/urls.tsv"
  rows=$(grep -c . "$1/published/urls.tsv")
  {
    echo "{\"count\": $rows, \"assets\": ["
    awk -F'\t' '{printf "{\"path\": \"%s\", \"url\": \"%s\"},\n", $1, $2}' \
      "$1/published/urls.tsv" | sed '$ s/,$//'
    echo "]}"
  } >"$1/published/manifest.json"
}

fail=0

# 1. A clean root passes.
mkroot "$tmp/clean"
if IMAGES_ROOT="$tmp/clean" bash "$gate" >/dev/null 2>&1; then
  echo "ok   clean root passes"
else
  echo "FAIL clean root refused"; fail=1
fi

# 2. A session-gated URL — the real 2026-11-26 mistake — must fail, named.
mkroot "$tmp/session" $'wall/x.png\thttps://web.chatplayground.ai/api/files/x.png\t10'
out=$(IMAGES_ROOT="$tmp/session" bash "$gate" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'session-gated'; then
  echo "ok   session-gated URL refused, row named"
else
  echo "FAIL session-URL root: rc=$rc"; echo "$out" | tail -3; fail=1
fi

# 3. A row with no manifest asset must fail, named.
mkroot "$tmp/missing"
jq '.count -= 1 | .assets |= .[0:-1]' "$tmp/missing/published/manifest.json" \
  >"$tmp/missing/m.json" && mv "$tmp/missing/m.json" "$tmp/missing/published/manifest.json"
out=$(IMAGES_ROOT="$tmp/missing" bash "$gate" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q 'no asset'; then
  echo "ok   manifest-missing row refused, row named"
else
  echo "FAIL missing-row root: rc=$rc"; echo "$out" | tail -3; fail=1
fi

[ $fail -eq 0 ] && echo "images-check:test: all cases pass"
exit $fail
