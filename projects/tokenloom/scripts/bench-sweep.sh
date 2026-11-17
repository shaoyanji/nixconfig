#!/usr/bin/env bash
# The gate's verdict at four window widths, with the machine that produced it.
#
# A millisecond on a shared runner is noise; the verdict is not. Each width is
# compared with the table README.md publishes — 1 ms pass, 2 ms pass, 4 ms fail,
# 8 ms fail — so a change that moves the gate is a red build with the p99 beside
# it, rather than a paragraph somebody has to remember to re-read.
#
# Two attempts per width: a verdict that disagrees with the table is reported
# only when both attempts agree with each other, so a single noisy run is a
# footnote and a real move is a failure.
#
# The table was measured on four cores. Below MIN_CORES the verdicts say
# something about the machine, not about the gate, so they are recorded and
# published as advisory instead of failing a build: a two-core runner that
# cannot hold a 2 ms window is not a change in the software. The core count and
# CPU travel with every row and into the JSON record, so two runs a week apart
# are comparable without anyone remembering which box ran which.
#
# Output: one row per width here, a markdown table in $GITHUB_STEP_SUMMARY when
# that is set, and a JSON record at $SWEEP_JSON when that is set.
set -uo pipefail

BIN=${BIN:-./target/release/loom-cli}
DOC=${DOC:-10000}
EDITS=${EDITS:-200}
ATTEMPTS=${ATTEMPTS:-2}
WINDOWS=${WINDOWS:-"1 2 4 8"}
MIN_CORES=${MIN_CORES:-4}

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
printf 'gate:    edit → diff p99 at %s ms windows, %s edits on %s tokens, vs README.md'"'"'s table\n' \
  "$WINDOWS" "$EDITS" "$DOC"
if [ "$advisory" -eq 1 ]; then
  printf 'note:    %s cores is below the %s the table came from: verdicts are advisory,\n' \
    "$cores" "$MIN_CORES"
  printf '         recorded and compared, but not failed, because this run measures the runner.\n'
fi
echo

table=""
json=""
drift=0
for w in $WINDOWS; do
  want=$(expected "$w")
  verdict=""
  p50=""
  p99=""
  max=""
  tries=0
  attempt=1
  while [ "$attempt" -le "$ATTEMPTS" ]; do
    tries=$attempt
    out=$("$BIN" bench --window "$w" --doc "$DOC" "$EDITS" 2>&1)
    code=$?
    line=$(printf '%s\n' "$out" | grep 'vs target' | tail -1)
    show=$(printf '%s\n' "$out" | grep 'single edit → diff' | tail -1)
    p50=$(printf '%s\n' "$show" | sed -n 's/.*p50 \([0-9.]*\).*/\1/p')
    p99=$(printf '%s\n' "$show" | sed -n 's/.*p99 \([0-9.]*\).*/\1/p')
    max=$(printf '%s\n' "$show" | sed -n 's/.*max \([0-9.]*\).*/\1/p')
    case "$line" in
      *PASS*) verdict=pass ;;
      *FAIL*) verdict=fail ;;
      *)
        printf 'window %s ms did not run (exit %s):\n%s\n' "$w" "$code" "$out" >&2
        exit 2
        ;;
    esac
    [ "$verdict" = "$want" ] && break
    attempt=$((attempt + 1))
  done
  mark=ok
  if [ "$verdict" != "$want" ]; then
    mark=CHANGED
    drift=1
  fi
  printf '%-7s expected %-4s measured %-4s %-8s p50 %s · p99 %s · max %s ms\n' \
    "$w ms" "$want" "$verdict" "$mark" "${p50:--}" "${p99:--}" "${max:--}"
  table="${table}| $w ms | $want | $verdict | ${p50:--} | ${p99:--} | ${max:--} | ${tries} |
"
  sep=""
  [ -n "$json" ] && sep=","
  json="${json}${sep}{\"window_ms\":$w,\"want\":\"$want\",\"verdict\":\"$verdict\",\"p50_ms\":${p50:--1},\"p99_ms\":${p99:--1},\"max_ms\":${max:--1},\"attempts\":$tries}"
done

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
    echo "| window | expected | measured | p50 | p99 | max | attempts |"
    echo "| --- | --- | --- | --- | --- | --- | --- |"
    printf '%s' "$table"
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [ -n "${SWEEP_JSON:-}" ]; then
  printf '{"cores":%s,"cpu":"%s","min_cores":%s,"advisory":%s,"kernel":"%s","doc":%s,"edits":%s,"windows":[%s]}\n' \
    "$cores" "$cpu_json" "$MIN_CORES" "$advisory" "$kernel" "$DOC" "$EDITS" "$json" \
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
