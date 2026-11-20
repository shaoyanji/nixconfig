#!/usr/bin/env bash
# Regression fixture for the CV-PDF link gate (scripts/task/site-links.sh).
#
# That gate runs inside the `matt-site` derivation, so a defect in it either ships
# or blocks every deploy. This proves all four of its assertions on a temp site:
# a linked CV with `download` passes, an anchor that lost `download` fails, a PDF
# no page links fails, a required PDF that was not shipped fails, and a dead
# internal href fails. The `download` cases include a word that merely contains it
# (`downloads`), because the regex must not accept that as the attribute.
#
# Exit: 0 every case behaves, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
gate="$repo/scripts/task/site-links.sh"

[ -f "$gate" ] || {
  echo "fixture: $gate missing" >&2
  exit 2
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
site="$tmp/site"

reset() {
  rm -rf "$site"
  mkdir -p "$site"
  printf '%%PDF-1.7\nfixture\n' >"$site/cv.pdf"
}

fail=0
cases=0
check() { # name want_rc needle [required PDF...]
  local name="$1" want="$2" needle="$3"
  shift 3
  local out rc
  cases=$((cases + 1))
  out="$(bash "$gate" "$site" "$@" 2>&1)"
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

reset
cat >"$site/index.html" <<'HTML'
<a class="cv" href="cv.pdf" download>CV</a>
HTML
check "a linked, downloadable CV passes" 0 "every internal link resolves" cv.pdf

reset
cat >"$site/index.html" <<'HTML'
<a class="cv" href="cv.pdf">CV</a>
HTML
check "an anchor without download fails" 1 "has no download attribute" cv.pdf

reset
cat >"$site/index.html" <<'HTML'
<a class="cv" href="cv.pdf" data-note="downloads">CV</a>
HTML
check "a word merely containing download fails" 1 "has no download attribute" cv.pdf

reset
cat >"$site/index.html" <<'HTML'
<p>nothing links the CV</p>
HTML
check "an unlinked PDF fails" 1 "no page links cv.pdf" cv.pdf

reset
cat >"$site/index.html" <<'HTML'
<a class="cv" href="cv.pdf" download>CV</a>
HTML
check "a required PDF that was not shipped fails" 1 "required PDF not shipped cv-de.pdf" cv.pdf cv-de.pdf

reset
cat >"$site/index.html" <<'HTML'
<a class="cv" href="cv-missing.pdf" download>CV</a>
HTML
check "a dead internal link fails" 1 "broken" cv.pdf

echo "site-links fixture: ${cases} cases"
[ "$fail" = 0 ] || exit 1
