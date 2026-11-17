#!/usr/bin/env bash
# The gate's verdict at three window widths and on a 40 k document, with the
# machine that produced it.
#
# A millisecond on a shared runner is noise; the verdict is not. Each width is
# compared with the table README.md publishes — 1 ms pass, 2 ms pass, 8 ms fail —
# so a change that moves the gate is a red build with the p99 beside it, rather
# than a paragraph somebody has to remember to re-read. The 4 ms width is left out
# on purpose: since the timer tax was removed it sits on the line, 4.18 ms in one
# run and 9.18 in another, so it is published as measured and not gated, because a
# row that flips its verdict on noise teaches nothing.
#
# The heavy row is the document instead of the window: 40 000 tokens, 600 edits,
# the 2 ms default. It is compared with the product's 5 ms target rather than with
# a table of verdicts, because that target is what the document has to meet, and
# it is where the tail lived before the reactor shards were charged for it.
#
# Two attempts per row: a verdict that disagrees with the table is reported only
# when every attempt agrees with each other, so a single noisy run is a footnote
# and a real move is a failure.
#
# The table was measured on four cores. Below MIN_CORES the verdicts say
# something about the machine, not about the gate, so they are recorded and
# published as advisory instead of failing a build: a two-core runner that
# cannot hold a 2 ms window is not a change in the software. The core count and
# CPU travel with every row and into the JSON record, so two runs a week apart
# are comparable without anyone remembering which box ran which.
#
# Output: one row per case here, a markdown table in $GITHUB_STEP_SUMMARY when
# that is set, and a JSON record at $SWEEP_JSON when that is set.
set -uo pipefail

BIN=${BIN:-./target/release/loom-cli}
DOC=${DOC:-10000}
EDITS=${EDITS:-200}
HEAVY=${HEAVY:-40000x600}
ATTEMPTS=${ATTEMPTS:-2}
WINDOWS=${WINDOWS:-"1 2 8"}
MIN_CORES=${MIN_CORES:-4}

heavy_doc=${HEAVY%x*}
heavy_edits=${HEAVY#*x}
case "${heavy_doc}${heavy_edits}" in
  '' | *[!0-9]*)
    printf 'HEAVY must be <tokens>x<edits>, e.g. 40000x600; got %s\n' "$HEAVY" >&2
    exit 2
    ;;
esac

cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 0)
case "$cores" in
  '' | *[!0-9]*) cores=0 ;;
esac
cpu=$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null)
[ -n "$cpu" ] || cpu=unknown
cpu_json=$(printf '%s' "$cpu" | tr -d '"\\')
kernel=$(uname -sr 2>/dev/null || echo unknown)

advisory=0
if [ "$cores" -lt "$MIN_CORES" ]; then
  advisory=1
fi

expected() {
  case "$1" in
    1 | 2) echo pass ;;
    *) echo fail ;;
  esac
}

printf 'machine: %s cores · %s · %s\n' "$cores" "$cpu" "$kernel"
printf 'gate:    edit → diff p99 at %s ms windows, %s edits on %s tokens, vs README.md\n' \
  "$WINDOWS" "$EDITS" "$DOC"
printf 'heavy:   %s edits on %s tokens at a 2 ms window, vs the 5 ms target itself\n' \
  "$heavy_edits" "$heavy_doc"
if [ "$advisory" -eq 1 ]; then
  printf 'note:    %s cores is below the %s the table came from: verdicts are advisory,\n' \
    "$cores" "$MIN_CORES"
  printf '         recorded and compared, but not failed, because this run measures the runner.\n'
fi
echo

table=""
json=""
drift=0

# One case, retried while its verdict disagrees with what the table says. Sets
# p50/p99/max/verdict and appends a row, a markdown line and a JSON object.
case_row() {
  w=$1
  d=$2
  n=$3
  want=$4
  label=$5
  tries=0
  while [ "$tries" -lt "$ATTEMPTS" ]; do
    tries=$((tries + 1))
    out=$("$BIN" bench --window "$w" --doc "$d" "$n" 2>&1)
    code=$?
    show=$(printf '%s\n' "$out" | grep 'single edit → diff' | tail -1)
    line=$(printf '%s\n' "$out" | grep 'vs target' | tail -1)
    p50=$(printf '%s\n' "$show" | sed -n 's/.*p50 \([0-9.]*\).*/\1/p')
    p99=$(printf '%s\n' "$show" | sed -n 's/.*p99 \([0-9.]*\).*/\1/p')
    max=$(printf '%s\n' "$show" | sed -n 's/.*max \([0-9.]*\).*/\1/p')
    case "$line" in
      *PASS*) verdict=pass ;;
      *FAIL*) verdict=fail ;;
      *)
        printf '%s did not run (exit %s):\n%s\n' "$label" "$code" "$out" >&2
        exit 2
        ;;
    esac
    [ "$verdict" = "$want" ] && break
  done
  mark=ok
  if [ "$verdict" != "$want" ]; then
    mark=CHANGED
    drift=1
  fi
  printf '%-12s expected %-4s measured %-4s %-8s p50 %s · p99 %s · max %s ms\n' \
    "$label" "$want" "$verdict" "$mark" "${p50:--}" "${p99:--}" "${max:--}"
  table="${table}| $label | $want | $verdict | ${p50:--} | ${p99:--} | ${max:--} | $tries |
"
  sep=""
  [ -n "$json" ] && sep=","
  json="${json}${sep}{\"case\":\"$label\",\"window_ms\":$w,\"doc\":$d,\"edits\":$n,\"want\":\"$want\",\"verdict\":\"$verdict\",\"p50_ms\":${p50:--1},\"p99_ms\":${p99:--1},\"max_ms\":${max:--1},\"attempts\":$tries}"
}

for w in $WINDOWS; do
  case_row "$w" "$DOC" "$EDITS" "$(expected "$w")" "$w ms"
done
case_row 2 "$heavy_doc" "$heavy_edits" pass "$HEAVY"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### bench sweep"
    echo
    echo "\`$cores\` cores · $cpu · $kernel"
    if [ "$advisory" -eq 1 ]; then
      echo
      echo "Below the $MIN_CORES cores the table came from: verdicts are advisory, not a gate."
    fi
    echo
    echo "| case | expected | measured | p50 | p99 | max | attempts |"
    echo "| --- | --- | --- | --- | --- | --- | --- |"
    printf '%s' "$table"
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [ -n "${SWEEP_JSON:-}" ]; then
  printf '{"cores":%s,"cpu":"%s","min_cores":%s,"advisory":%s,"kernel":"%s","doc":%s,"edits":%s,"heavy":"%s","cases":[%s]}\n' \
    "$cores" "$cpu_json" "$MIN_CORES" "$advisory" "$kernel" "$DOC" "$EDITS" "$HEAVY" "$json" \
    > "$SWEEP_JSON"
fi

if [ "$drift" -ne 0 ]; then
  if [ "$advisory" -eq 1 ]; then
    printf '\nverdict changed, but on %s cores this run is advisory: re-run where %s+ cores are free before editing the table\n' \
      "$cores" "$MIN_CORES" >&2
    exit 0
  fi
  printf '\nthe gate changed its answer: if the new verdict is the truth, update the table in README.md\n' >&2
  exit 1
fi
printf '\nthe gate answers as documented at %s ms windows (%s edits, %s tokens) on %s cores\n' \
  "$WINDOWS" "$EDITS" "$DOC" "$cores"
