#!/usr/bin/env bash
# The gate's verdict at four window widths.
#
# A millisecond on a shared runner is noise; the verdict is not. Each width is
# compared with the table README.md publishes — 1 ms pass, 2 ms pass, 4 ms fail,
# 8 ms fail — so a change that moves the gate is a red build with the p99 beside
# it, rather than a paragraph somebody has to remember to re-read.
#
# Two attempts per width: a verdict that disagrees with the table is reported
# only when both attempts agree with each other, so a single noisy run is a
# footnote and a real move is a failure.
set -uo pipefail

BIN=${BIN:-./target/release/loom-cli}
DOC=${DOC:-10000}
EDITS=${EDITS:-200}
ATTEMPTS=${ATTEMPTS:-2}
WINDOWS=${WINDOWS:-"1 2 4 8"}

expected() {
  case "$1" in
    1 | 2) echo pass ;;
    *) echo fail ;;
  esac
}

drift=0
for w in $WINDOWS; do
  want=$(expected "$w")
  verdict=""
  p99="-"
  attempt=1
  while [ "$attempt" -le "$ATTEMPTS" ]; do
    out=$("$BIN" bench --window "$w" --doc "$DOC" "$EDITS" 2>&1)
    code=$?
    line=$(printf '%s\n' "$out" | grep 'vs target' | tail -1)
    p99=$(printf '%s\n' "$out" | sed -n 's/.*edit → diff p99 \([0-9.]*\) ms.*/\1/p' | tail -1)
    case "$line" in
      *PASS*) verdict=pass ;;
      *FAIL*) verdict=fail ;;
      *)
        printf 'window %s ms did not run (exit %s):\n%s\n' "$w" "$code" "$out" >&2
        exit 2
        ;;
    esac
    [ -n "$p99" ] || p99="-"
    [ "$verdict" = "$want" ] && break
    attempt=$((attempt + 1))
  done
  mark=ok
  if [ "$verdict" != "$want" ]; then
    mark=CHANGED
    drift=1
  fi
  printf '%-8s expected %-4s measured %-4s %-8s p99 %s ms\n' "$w ms" "$want" "$verdict" "$mark" "$p99"
done

if [ "$drift" -ne 0 ]; then
  printf '\nthe gate changed its answer: if the new verdict is the truth, update the table in README.md\n' >&2
  exit 1
fi
printf '\nthe gate answers as documented at %s ms windows (%s edits, %s tokens)\n' \
  "$WINDOWS" "$EDITS" "$DOC"
