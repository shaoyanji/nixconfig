#!/usr/bin/env bash
# Regression fixture for the CV-PDF link gate (scripts/task/site-links.sh).
#
# That gate runs inside the `matt-site` derivation, so a defect in it either ships
# or blocks every deploy. This is its fail-fast copy, and `checks:quick` runs it.
# The passing cases are the shapes the live site emits: two CVs linked from the
# root, a `../cv-de.pdf` relative link from `/de/`, and a fragment on a PDF
# anchor. The failing cases are every assertion the gate makes — an anchor that
# lost `download` (including one whose only such word is an attribute spelled
# `downloads`), a PDF no page links, a required PDF that was not shipped, a dead
# internal href, and a PDF anchor aimed at a file that does not exist, where the
# attribute must not excuse the dead target.
#
# The `--gap` pre-flight is exercised on both sides too: it passes a site whose
# anchors lost `download` (which is not its question), and fails on an unlinked
# PDF, an unshipped required PDF and a dead target.
#
# Coverage is asserted both ways: a case listed below that stops running, or one
# that runs without being listed, fails the fixture, so deleting an assertion
# cannot silently shrink the set.
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

expected="two linked CVs pass
a ../ relative link passes
a fragment on a PDF anchor passes
an anchor without download fails
a word merely containing download fails
an unlinked PDF fails
a required PDF that was not shipped fails
a dead internal link fails
a PDF anchor to a missing file fails
a gap check passes on a linked site
a gap check ignores a missing download attribute
a gap check fails on an unlinked PDF
a gap check fails on a required PDF not shipped
a gap check fails on a dead target"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
site="$tmp/site"

reset() {
  rm -rf "$site"
  mkdir -p "$site"
}

# Each case ships exactly the PDFs it links: a second CV in the artifact that the
# case does not link is an orphan, and the gate would fail it for that instead.
pdf() {
  mkdir -p "$site/$(dirname "$1")"
  printf '%%PDF-1.7\nfixture\n' >"$site/$1"
}

fail=0
cases=0
ran=()
mode=""
check() { # name page html want_rc needle [required PDF...]
  local name="$1" page="$2" html="$3" want="$4" needle="$5"
  shift 5
  local out rc
  cases=$((cases + 1))
  ran+=("$name")
  mkdir -p "$site/$(dirname "$page")"
  printf '%s\n' "$html" >"$site/$page"
  out="$(bash "$gate" ${mode:+"$mode"} "$site" "$@" 2>&1)"
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
pdf cv.pdf
pdf cv-de.pdf
check "two linked CVs pass" index.html \
  '<a class="cv" href="cv.pdf" download>CV</a>
<a class="cv" href="cv-de.pdf" download>Lebenslauf</a>' \
  0 "all 2 PDFs are linked" cv.pdf cv-de.pdf

reset
pdf cv-de.pdf
check "a ../ relative link passes" de/index.html \
  '<a class="cv" href="../cv-de.pdf" download>Lebenslauf</a>' \
  0 "every internal link resolves" cv-de.pdf

reset
pdf cv.pdf
check "a fragment on a PDF anchor passes" index.html \
  '<a class="cv" href="cv.pdf#page=1" download>CV</a>' \
  0 "all 1 PDF anchors download" cv.pdf

reset
pdf cv.pdf
check "an anchor without download fails" index.html \
  '<a class="cv" href="cv.pdf">CV</a>' \
  1 "has no download attribute" cv.pdf

reset
pdf cv.pdf
check "a word merely containing download fails" index.html \
  '<a class="cv" href="cv.pdf" data-note="downloads">CV</a>' \
  1 "has no download attribute" cv.pdf

reset
pdf cv.pdf
check "an unlinked PDF fails" index.html \
  '<p>nothing links the CV</p>' \
  1 "no page links cv.pdf" cv.pdf

reset
pdf cv.pdf
check "a required PDF that was not shipped fails" index.html \
  '<a class="cv" href="cv.pdf" download>CV</a>' \
  1 "required PDF not shipped cv-de.pdf" cv.pdf cv-de.pdf

reset
pdf cv.pdf
check "a dead internal link fails" index.html \
  '<a class="cv" href="cv-missing.pdf" download>CV</a>' \
  1 "broken" cv.pdf

reset
pdf cv.pdf
check "a PDF anchor to a missing file fails" index.html \
  '<a class="cv" href="cv.pdf" download>CV</a>
<a href="work/nonexistent/">case study</a>' \
  1 "broken" cv.pdf

reset
pdf cv.pdf
pdf cv-de.pdf
mode=--gap
check "a gap check passes on a linked site" index.html \
  '<a class="cv" href="cv.pdf" download>CV</a>
<a class="cv" href="cv-de.pdf" download>Lebenslauf</a>' \
  0 "no gaps" cv.pdf cv-de.pdf
mode=""

reset
pdf cv.pdf
mode=--gap
check "a gap check ignores a missing download attribute" index.html \
  '<a class="cv" href="cv.pdf">CV</a>' \
  0 "no gaps" cv.pdf
mode=""

reset
pdf cv.pdf
mode=--gap
check "a gap check fails on an unlinked PDF" index.html \
  '<p>nothing links the CV</p>' \
  1 "no page links cv.pdf" cv.pdf
mode=""

reset
pdf cv.pdf
mode=--gap
check "a gap check fails on a required PDF not shipped" index.html \
  '<a class="cv" href="cv.pdf" download>CV</a>' \
  1 "required PDF not shipped cv-de.pdf" cv.pdf cv-de.pdf
mode=""

reset
pdf cv.pdf
mode=--gap
check "a gap check fails on a dead target" index.html \
  '<a class="cv" href="cv-missing.pdf" download>CV</a>' \
  1 "broken" cv.pdf
mode=""

for name in "${ran[@]}"; do
  grep -qxF -- "$name" <<<"$expected" || { echo "FAIL unlisted case: ${name}"; fail=1; }
done
while IFS= read -r name; do
  [ -n "$name" ] || continue
  printf '%s\n' "${ran[@]}" | grep -qxF -- "$name" || { echo "FAIL case never ran: ${name}"; fail=1; }
done <<<"$expected"

echo "site-links fixture: ${cases} cases"
[ "$fail" = 0 ] || exit 1
