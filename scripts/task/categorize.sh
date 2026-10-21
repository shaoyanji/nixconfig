#!/usr/bin/env bash
# shellcheck shell=bash
# Categorize prose with FORCED BINARY choices, not a five-way guess.
#
# Forced binary: every question is "dark or light?", never "which of five
# shades?", and every pair is asked in both orders so a position effect shows up
# as a flip. Measured 2026-10-21 after the rewrite: "a fact about a machine" beat
# "commands to run in order" for BOTH a counts-only state and a prose snippet of
# actual commands, in both orders (11/11 pairs) — so the dominant weight is a
# label prior, not order and not state. The rule anchor still scores 4/10.
#
# That makes the engine unusable as a semantic classifier until its scorer
# weights state tokens (we own it: modules/services/systemone/engine.py, the
# `choice` path). The anchors below are what refuse to let a label prior become
# a table.
set -euo pipefail

ENGINE="${CATEGORIZE_ENGINE:-jev}"   # jev | julia
PROVIDER="${JEV_PROVIDER:-typesafe}"
ENDPOINT="${SYSTEMONE_URL:-https://delphi.cloudforest-kardashev.ts.net:8444}"
CRITERIA_FILE="$(mktemp "${TMPDIR:-/tmp}/categorize-criteria.XXXXXX.json")"
trap 'rm -f "$CRITERIA_FILE"' EXIT
HERE="$(cd "$(dirname "$0")" && pwd)"

# Short, oppositional labels: a binary question must look like a coin, not a menu.
declare -A LABEL=(
  [policy]="a rule the build should enforce"
  [fact]="a fact about a machine"
  [history]="why a decision was made"
  [procedure]="commands to run in order"
  [docs]="reference material to read"
)
CATS=(policy fact history procedure docs)

case "${1:-}" in -h|--help) sed -n '2,11p' "$0"; exit 0 ;; esac
[ $# -gt 0 ] || { echo "categorize: give one or more paths" >&2; exit 2; }

# jev: a calibrated classifier, so the five-way form is legitimate here. The
# duel machinery below only exists because julia-1's choice is label-biased.
jev_classify() {
  local text="$1"
  # Mutually exclusive by construction: each label names what the reader DOES
  # with the page, so "readable" cannot count as a category of its own. v2 —
  # v1 let `docs` absorb anything with prose in it (5 of 8 files), including a
  # routing table of commands and a host's own machine facts.
  jq -n '{
    policy:"an invariant or failure mode the build or a test enforces (must / must not)",
    fact:"a property of one machine — address, port, role, path, hardware — with no steps; belongs in inventory",
    history:"why a past decision was made, and what was rejected",
    procedure:"an ordered sequence of commands or decisions the reader executes, including routing tables of tasks",
    docs:"reference with neither commands, addresses nor invariants — prose you read once and do not execute"
  }' > "$CRITERIA_FILE"
  local out try
  for try in 1 2 3 4 5; do
    if out=$(jev-decide classify --provider "$PROVIDER" --text "$text" --criteria "$CRITERIA_FILE" --min-probability 0.5 2>&1); then
      printf '%s' "$out" | jq -r '[.decisions.category.value, (.decisions.category.probability // 0 | tostring)] | @tsv'
      return 0
    fi
    sleep $((try * 2))
  done
  printf 'jev-error\t0\n'
}

ask() { # state, optA, optB -> winner label
  local state="$1" a="$2" b="$3" body out
  body="$(jq -n --arg s "$state" --arg a "$a" --arg b "$b" \
    '{state:$s, questions:{c:{type:"choice", instructions:"pick one", criteria:[$a,$b]}}}')"
  if ! out=$(curl -fsS --max-time 30 -H 'content-type: application/json' -d "$body" "$ENDPOINT/v1/systemone" 2>&1); then
    echo "categorize: engine refused or unreachable: $out" >&2
    exit 1
  fi
  printf '%s' "$out" | jq -r '.answers.c.choice'
}

flipped=0
pairs=0
# duel: ask (a|b) and (b|a); a category scores only when both orders agree.
duel() {
  local state="$1" a="$2" b="$3" ab ba
  ab=$(ask "$state" "${LABEL[$a]}" "${LABEL[$b]}")
  ba=$(ask "$state" "${LABEL[$b]}" "${LABEL[$a]}")
  pairs=$((pairs + 1))
  if [ "$ab" = "${LABEL[$a]}" ] && [ "$ba" = "${LABEL[$a]}" ]; then echo "$a"
  elif [ "$ab" = "${LABEL[$b]}" ] && [ "$ba" = "${LABEL[$b]}" ]; then echo "$b"
  else flipped=$((flipped + 1)); echo "undecided"; fi
}

features() {
  local f="$1" c l ratio restated dup days hits claims blocks addrs
  c=$(grep -cE '^\s*#' "$f" || true); l=$(grep -c '' "$f" || true)
  ratio=$(awk -v c="$c" -v l="$l" 'BEGIN { printf "%.2f", (l ? c / l : 0) }')
  restated=$(grep -cE '^\s*#\s*(Enable|Set|Add|Use|Configure|This sets|Install)' "$f" || true)
  dup=0
  for w in $(grep -oE '[a-z][a-z0-9-]{6,}' "$f" | sort -u | head -40); do
    grep -qsi "$w" inventory.toml flake/policies.nix 2>/dev/null && dup=$((dup + 1))
  done
  # A staged-but-never-committed file has no log entry, and the empty command
  # substitution used to kill the whole table with "arithmetic syntax error".
  ts=$(git log -1 --format=%ct -- "$f" 2>/dev/null || true)
  [ -n "$ts" ] || ts=$(date +%s)
  days=$(( ( $(date +%s) - ts ) / 86400 ))
  hits=$(grep -ciE 'must not|never|conflict|collision|bind: |belongs to|belongs in' "$f" || true)
  claims=$(grep -cE '[0-9]+ ?(ms|MiB|GiB|s|%)' "$f" || true)
  blocks=$(grep -c '```bash' "$f" || true)
  addrs=$(grep -cE '(192\.168\.[0-9]+\.[0-9]+|100\.[0-9]+\.[0-9]+\.[0-9]+|[a-z0-9-]+\.lan)' "$f" || true)
  # `taskrefs` was the missing signal: rollback.md is a routing table of six
  # `task infra:*` calls and scored no command evidence at all without it.
  taskrefs=$(grep -coE 'task [a-z]+:[a-z:<>{}-]+' "$f" || true)
  printf 'comments=%s lines=%s ratio=%s restated=%s elsewhere=%s age_days=%s assertions=%s metrics=%s blocks=%s taskrefs=%s addresses=%s' \
    "$c" "$l" "$ratio" "$restated" "$dup" "$days" "$hits" "$claims" "$blocks" "$taskrefs" "$addrs"
}

# Calibration: known answers, asked the same way the table is asked.
calib=1
check() { # state, expected
  local s="$1" want="$2" score="" a b
  for i in "${!CATS[@]}"; do for j in "${!CATS[@]}"; do
    [ "$i" -lt "$j" ] && { r=$(duel "$s" "${CATS[$i]}" "${CATS[$j]}"); [ "$r" = "$want" ] && score="$score."; }
  done; done
  printf '%s\n' "${#score}"
}
rule_state="this service must not bind 443 because nginx owns it and the switch fails the build"
steps_state="step 1 ssh delphi step 2 sudo nixos-rebuild switch step 3 systemctl status then verify"
if [ "$ENGINE" = "jev" ]; then
  r_hit=$(jev_classify "$rule_state"); r_hit="${r_hit%%$'\t'*}"
  s_hit=$(jev_classify "$steps_state"); s_hit="${s_hit%%$'\t'*}"
  printf 'calibration: rule→%s | steps→%s\n' "$r_hit" "$s_hit" >&2
  [ "$r_hit" = "policy" ] && [ "$s_hit" = "procedure" ] || calib=0
  r_pts=1; s_pts=1
else
r_pts=$(check "$rule_state" policy); s_pts=$(check "$steps_state" procedure)
printf 'calibration: rule→%s/10 policy | steps→%s/10 procedure | position-flips %s/%s\n' \
  "$r_pts" "$s_pts" "$flipped" "$pairs" >&2
[ "$r_pts" -ge 1 ] && [ "$s_pts" -ge 1 ] || calib=0
fi

rows="[]"
for f in "$@"; do
  [ -r "$f" ] || { echo "categorize: cannot read $f" >&2; exit 2; }
  state="$(features "$f")"
  if [ "$ENGINE" = "jev" ]; then
    cat_j="$(jev_classify "$state")"
    label_j="${cat_j%%$'\t'*}"; prob_j="${cat_j##*$'\t'}"
    # The engine sees counts, not the page, so "does the reader execute this?"
    # was being answered by a feature that was never in the vector (task refs)
    # and a prior that called any host page a fact. Executable content is
    # therefore a RULE: enough command blocks or task references makes the page
    # a procedure, and the engine only classifies pages that carry none. This
    # fixed rollback.md, delphi.md and frieren.md, and it is falsifiable — a page
    # classified `procedure` by rule with no executable content fails the table.
    blocks_n=$(sed -n 's/.*blocks=\([0-9]*\).*/\1/p' <<<"$state")
    task_n=$(sed -n 's/.*taskrefs=\([0-9]*\).*/\1/p' <<<"$state")
    if [ "${blocks_n:-0}" -ge 2 ] || [ "${task_n:-0}" -ge 3 ]; then
      label_j=procedure; prob_j=0; basis=rule
      echo "categorize: rule procedure on $f (${blocks_n} command block(s), ${task_n} task ref(s))" >&2
    else
      basis=jev
    fi
    rows="$(jq -c --arg f "$f" --arg c "$label_j" --argjson s "$prob_j" --arg b "$basis" \
      '. + [{path:$f, category:$c, score:$s, basis:$b}]' <<<"$rows")"
    continue
  fi
  declare -A wins=()
  for c in "${CATS[@]}"; do wins[$c]=0; done
  for i in "${!CATS[@]}"; do for j in "${!CATS[@]}"; do
    [ "$i" -lt "$j" ] || continue
    r=$(duel "$state" "${CATS[$i]}" "${CATS[$j]}")
    [ "$r" != "undecided" ] && wins[$r]=$((wins[$r] + 1))
  done; done
  best=""; n=-1
  for c in "${CATS[@]}"; do [ "${wins[$c]}" -gt "$n" ] && { n=${wins[$c]}; best=$c; }; done
  rows="$(jq -c --arg f "$f" --arg c "$best" --argjson w "$n" \
    '. + [{path:$f, category:$c, score:($w / 4)}]' <<<"$rows")"
done

flip_pct=$((pairs ? flipped * 100 / pairs : 0))
[ "$calib" -eq 0 ] && echo "categorize: QUERY NOT CALIBRATED — table is shape, not a verdict" >&2
[ "$flip_pct" -gt 50 ] && { echo "categorize: POSITION-DOMINATED — $flip_pct% of pairs flipped under swap" >&2; exit 1; }

errors=$(jq '[.[] | select(.category == "jev-error")] | length' <<<"$rows")
[ "$errors" -eq 0 ] || { echo "categorize: ENGINE ERRORS on $errors file(s) — no table" >&2; exit 1; }
distinct=$(jq '[.[].category] | unique | length' <<<"$rows")
[ "$distinct" -ge 2 ] || { echo "categorize: DOES NOT DISCRIMINATE — every file read as one category" >&2; exit 1; }

# A rule row has no probability to show, and printing one would invent a number.
jq -r 'sort_by(-(.score // 0.5))[] | (if .basis == "rule" then "rule" else "\(.score * 100 | floor)%" end) + "\t" + .category + "\t" + .path' <<<"$rows"
