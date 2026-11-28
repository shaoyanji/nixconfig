#!/usr/bin/env bash
# cv-links-check.sh — prove in a real browser that every CV link downloads a PDF.
#
# WHY THIS EXISTS: two traps make a naive browser check lie about a download.
# Headless Chrome ships no PDF viewer, so navigating to a PDF URL renders a blank
# page that never settles — it reads as a hang rather than a failure. And a click
# on `a[download]` saves into ~/Downloads under the server's filename unless a
# download directory is set, so a checker watching its own path times out while
# the file sits somewhere else. This sets --download-path, clicks the real
# anchors, and judges the bytes.
#
# Usage: cv-links-check.sh [base-url]
#   ARTIFACT=/tmp/matt-site   hash-compare the live files against a built site
#   ARTIFACT= (set, empty)    skip that comparison. What CI needs: the published
#                             site is deployed by hand, so it trails the tree and
#                             a hash mismatch would mean "a deploy behind", not
#                             "a broken link".
set -euo pipefail

BASE="${1:-${BASE:-https://matt.bountystash.com}}"
ARTIFACT="${ARTIFACT-/tmp/matt-site}"
AB="${AGENT_BROWSER:-$(command -v 'agent-browser' || true)}"

[ -n "$AB" ] || { echo "cv-links-check: agent-browser is not on PATH" >&2; exit 1; }
command -v pdfinfo >/dev/null 2>&1 || { echo "cv-links-check: pdfinfo (poppler) missing" >&2; exit 1; }

# A reference built from another tree answers the wrong question: the live bytes
# would match yesterday's site, or disagree with a build nobody deployed. Refuse
# it before a request is made.
if [ -n "$ARTIFACT" ] && [ -e "$ARTIFACT" ]; then
  COPIES="$ARTIFACT=.#sites.matt-site" bash "$(dirname "${BASH_SOURCE[0]}")/site-copies-check.sh" || {
    echo "cv-links-check: $ARTIFACT is not this tree's build — run task matt:build" >&2
    exit 2
  }
fi

dir=$(mktemp -d)
trap 'rm -rf "$dir"; "$AB" close >/dev/null 2>&1 || true' EXIT

ok=0
fail=0
say_fail() { echo "FAIL $*"; fail=$((fail + 1)); }

echo "cv-links-check: $BASE"
echo "== headers (a download needs a PDF type; Pages sends no Content-Disposition) =="
for f in cv.pdf cv-de.pdf cv-energy.pdf cv-energy-de.pdf cv-software.pdf cv-software-de.pdf; do
  head=$(timeout 30 curl -fsSI "$BASE/$f" | tr -d '\r')
  code=$(printf '%s\n' "$head" | awk 'NR==1{print $2}')
  type=$(printf '%s\n' "$head" | awk 'tolower($1)=="content-type:"{print $2}')
  len=$(printf '%s\n' "$head" | awk 'tolower($1)=="content-length:"{print $2}')
  if [ "$code" = 200 ] && [ "$type" = application/pdf ] && [ "${len:-0}" -gt 10000 ]; then
    echo "ok   $f $code $type ${len}B"
    ok=$((ok + 1))
  else
    say_fail "$f: code=${code:-?} type=${type:-?} length=${len:-?}"
  fi
done

echo "== clicks in headless Chrome =="
# The first `open` of a fresh session can stall past its timeout and then work on
# the next call (measured 2026-11-21: `FAIL /: could not open`, and the same page
# opened on the following `check`). One warm-up plus one retry keeps that from
# turning into a red gate; a page that genuinely will not open still fails twice.
open_page() { # url
  timeout 120 "$AB" --download-path "$dir" open "$1" >/dev/null 2>&1 && return 0
  timeout 120 "$AB" --download-path "$dir" open "$1" >/dev/null 2>&1
}
open_page "$BASE" || true
check() { # page href expected-file
  local page=$1 href=$2 want=$3 pages hash built
  open_page "$BASE$page" || { say_fail "$page: could not open"; return; }
  rm -f "$dir/$want"
  timeout 120 "$AB" download "a.cv[href=\"$href\"]" "$dir/$want" >/dev/null 2>&1 || true
  if [ ! -s "$dir/$want" ]; then
    say_fail "$page -> $href: nothing saved"
    return
  fi
  if [ "$(head -c 4 "$dir/$want")" != "%PDF" ]; then
    say_fail "$want: not a PDF ($(file -b "$dir/$want"))"
    return
  fi
  pages=$(pdfinfo "$dir/$want" | awk '/^Pages/{print $2}')
  hash=$(sha256sum "$dir/$want" | cut -d' ' -f1)
  if [ -f "$ARTIFACT/$want" ]; then
    built=$(sha256sum "$ARTIFACT/$want" | cut -d' ' -f1)
    if [ "$hash" != "$built" ]; then
      say_fail "$want: live bytes differ from $ARTIFACT/$want"
      return
    fi
    echo "ok   $page -> $href  $want ${pages}p $(stat -c%s "$dir/$want")B sha ${hash:0:12} == artifact"
  else
    echo "ok   $page -> $href  $want ${pages}p $(stat -c%s "$dir/$want")B sha ${hash:0:12}"
  fi
  ok=$((ok + 1))
}

check / cv.pdf cv.pdf
check /de/ ../cv-de.pdf cv-de.pdf
check /work/nixos-fleet ../cv-software.pdf cv-software.pdf
check /work/energy-telemetry ../cv-energy.pdf cv-energy.pdf
check /brief/platform ../cv-software.pdf cv-software.pdf
check /de/work/nixos-fleet ../../cv-software-de.pdf cv-software-de.pdf
check /de/work/energy-telemetry ../../cv-energy-de.pdf cv-energy-de.pdf
check /de/brief/platform ../../cv-software-de.pdf cv-software-de.pdf

echo
echo "cv-links-check: $ok ok, $fail failed"
[ "$fail" -eq 0 ]
