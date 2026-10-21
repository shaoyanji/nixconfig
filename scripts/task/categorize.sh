#!/usr/bin/env bash
# shellcheck shell=bash
# Categorize prose candidates with the decision engine, then GATE the query:
# a query that answers everything the same way, or cannot answer a case whose
# answer is known, has measured nothing and exits 1.
set -euo pipefail

ENDPOINT="${SYSTEMONE_URL:-https://delphi.cloudforest-kardashev.ts.net:8444}"
CATEGORIES='["policy-or-trap: a rule or failure mode that should fail a build","fleet-fact: an address, role or hardware detail that belongs in inventory","why-or-history: narrative explaining a decision","procedure: steps that should be a task","durable-explanation: reference material for docs"]'
UNIFORM=$(jq -n --argjson c "$CATEGORIES" '1 / ($c | length)')
HERE="$(cd "$(dirname "$0")" && pwd)"

case "${1:-}" in -h|--help) sed -n '2,6p' "$0"; exit 0 ;; esac
[ $# -gt 0 ] || { echo "categorize: give one or more paths" >&2; exit 2; }

ask() { # state -> answers JSON; a 400 is the caller's query error, not a dead engine
  local state="$1" body out
  body="$(jq -n --arg s "$state" --argjson c "$CATEGORIES" \
    '{state:$s, questions:{c:{type:"classify", instructions:"which channel owns this prose", criteria:$c}}}')"
  if ! out=$(curl -fsS --max-time 60 -H 'content-type: application/json' -d "$body" "$ENDPOINT/v1/systemone" 2>&1); then
    echo "categorize: engine refused or unreachable: $out" >&2
    exit 1
  fi
  printf '%s' "$out"
}

features() {
  local f="$1" c l ratio restated dup days hits claims blocks addrs
  c=$(grep -cE '^\s*#' "$f" || true)
  l=$(grep -c '' "$f" || true)
  ratio=$(awk -v c="$c" -v l="$l" 'BEGIN { printf "%.2f", (l ? c / l : 0) }')
  restated=$(grep -cE '^\s*#\s*(Enable|Set|Add|Use|Configure|This sets|Install)' "$f" || true)
  dup=0
  for w in $(grep -oE '[a-z][a-z0-9-]{6,}' "$f" | sort -u | head -40); do
    grep -qsi "$w" inventory.toml flake/policies.nix 2>/dev/null && dup=$((dup + 1))
  done
  days=$(( ( $(date +%s) - $(git log -1 --format=%ct -- "$f" 2>/dev/null || date +%s) ) / 86400 ))
  # Feature names avoid the option vocabulary: a key called `contains_rule` used
  # to match the word "rule" in an option label regardless of its value, which
  # made every candidate look like a policy. Weights must not be echoes.
  hits=$(grep -ciE 'must not|never|conflict|collision|bind: |belongs to|belongs in' "$f" || true)
  claims=$(grep -cE '[0-9]+ ?(ms|MiB|GiB|s|%)' "$f" || true)
  blocks=$(grep -c '```bash' "$f" || true)
  addrs=$(grep -cE '(192\.168\.[0-9]+\.[0-9]+|100\.[0-9]+\.[0-9]+\.[0-9]+|[a-z0-9-]+\.lan)' "$f" || true)
  printf 'comments=%s lines=%s ratio=%s restated=%s elsewhere=%s age_days=%s assertions=%s metrics=%s blocks=%s addresses=%s kind=%s' \
    "$c" "$l" "$ratio" "$restated" "$dup" "$days" "$hits" "$claims" "$blocks" "$addrs" \
    "$(case "$f" in *.nix) echo nix ;; *) echo markdown ;; esac)"
}

# CALIBRATION: known answers before any table. A miss means the token weighting
# is wrong for this corpus, and the table would be decoration.
calibrate() {
  local a b
  a=$(ask "this service must not bind 443 because nginx owns it and the switch fails the build" | jq -r '.answers.c.choice')
  b=$(ask "run these shell blocks in order to deploy the host, then verify the unit" | jq -r '.answers.c.choice')
  printf 'calibration: rule→%s | steps→%s\n' "${a%%:*}" "${b%%:*}" >&2
  case "$a" in policy-or-trap*) ;; *) echo "categorize: anchor(rule) read as $a" >&2; return 1 ;; esac
  case "$b" in procedure*) ;; *) echo "categorize: anchor(steps) read as $b" >&2; return 1 ;; esac
}

CALIBRATED=1
calibrate || CALIBRATED=0

rows="[]"
for f in "$@"; do
  [ -r "$f" ] || { echo "categorize: cannot read $f" >&2; exit 2; }
  state="$(features "$f")"
  cat_out="$(ask "$state")"
  rows="$(jq -c --arg f "$f" --arg s "$state" --argjson o "$cat_out" \
    '. + [{path:$f, category:$o.answers.c.choice, confidence:$o.answers.c.confidence, state:$s}]' <<<"$rows")"
done

distinct=$(jq '[.[].category] | unique | length' <<<"$rows")
top=$(jq '[.[].confidence] | max' <<<"$rows")

if [ "$CALIBRATED" -eq 0 ]; then
  echo "categorize: QUERY NOT CALIBRATED — table below is shape, not a verdict" >&2
fi
if [ "$distinct" -lt 2 ] || awk -v t="$top" -v u="$UNIFORM" 'BEGIN { exit !(t <= u + 0.01) }'; then
  echo "categorize: DOES NOT DISCRIMINATE — $distinct categories, max $top vs uniform $UNIFORM" >&2
  jq -r '.[] | "\(.confidence)\t\(.category)\t\(.path)"' <<<"$rows" >&2
  exit 1
fi

jq -r 'sort_by(-.confidence)[] | "\(.confidence * 100 | floor)%\t\(.category | split(":")[0])\t\(.path)"' <<<"$rows"
