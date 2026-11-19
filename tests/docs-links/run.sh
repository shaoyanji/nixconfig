#!/usr/bin/env bash
# Regression fixture for `checks:docs:links` (scripts/task/docs-links.sh).
#
# The audit that asked for this gate also warned about gates that cannot fail, so
# every class is exercised against a temp tree: a relative link to a real file
# passes, a relative link to nothing fails, a `file:///` absolute fails, a
# reference-style definition is judged the same way, `link-ok:` exempts its line,
# and web/anchor links are skipped rather than fetched or resolved.
#
# Exit: 0 every case behaves, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
gate="$repo/scripts/task/docs-links.sh"

[ -f "$gate" ] || { echo "fixture: $gate missing" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
: >"$tmp/exists.md"

fail=0
cases=0
run() { # name want_rc needle file-content
  local name="$1" want="$2" needle="$3" body="$4" page rc out
  cases=$((cases + 1))
  page="$tmp/case${cases}.md"
  printf '%s\n' "$body" >"$page"
  out="$(bash "$gate" "$page" 2>&1)"
  rc=$?
  if [ "$rc" != "$want" ]; then
    echo "FAIL ${name}: exit ${rc}, want ${want}"
    printf '%s\n' "$out" | sed 's/^/     /'
    fail=1
    return
  fi
  if [ -n "$needle" ] && ! grep -qF -- "$needle" <<<"$out"; then
    echo "FAIL ${name}: output lacks '${needle}'"
    printf '%s\n' "$out" | sed 's/^/     /'
    fail=1
    return
  fi
  echo "ok   ${name} (exit ${rc})"
}

run "relative link that resolves passes" 0 "PASS:" "[ok]($tmp/exists.md)"
run "relative link to nothing fails" 1 "links that resolve to nothing" "[dead](nowhere.md)"
run "absolute file link fails" 1 "machine-absolute links" "[local](file:///Volumes/data/projects/nixconfig/AGENTS.md)"
run "another user home fails" 1 "machine-absolute links" "[home](file:///home/someone/x.md)"
run "link-ok exempts the line" 0 "PASS:" "[moved](gone.md) link-ok: fixture proves the escape hatch"
run "web and anchor links are skipped" 0 "PASS:" $'[web](https://example.com/x)\n[anchor](#section)'
run "reference definition to a real file passes" 0 "PASS:" "$(printf '[ref]: %s' "$tmp/exists.md")"
run "reference definition to nothing fails" 1 "links that resolve to nothing" "[ref]: ../missing/elsewhere.md"

echo "docs-links fixture: ${cases} cases"
[ "$fail" = 0 ] || exit 1
