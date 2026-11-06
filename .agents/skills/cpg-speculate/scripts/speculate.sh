#!/usr/bin/env bash
# speculate.sh — one speculative round: N models answer the same question in
# parallel, Jev picks the best, and the winner is all the caller reads.
#
# Usage: speculate.sh [--json] "question" [model ...]
# Default models are the four the plan actually serves (premium_only ids 403).
set -euo pipefail

json=0
if [ "${1:-}" = "--json" ]; then
  json=1
  shift
fi

question=${1:-}
if [ -z "$question" ]; then
  echo 'usage: speculate.sh [--json] "question" [model ...]' >&2
  exit 64
fi
shift || true

models=("$@")
if [ ${#models[@]} -eq 0 ]; then
  models=(gpt-6-luna mimo-v2.6-pro gemini-3.8-flash-l deepseek-v4-pro)
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Fan out. One prompt each, one process each: four prompts per round, and the
# 50/10m and 300/h windows are what caps the round rate, not the plan.
i=0
for m in "${models[@]}"; do
  (
    cpg chat -m "$m" -s "spec-$$-$i" "$question" >"$tmp/$i.out" 2>"$tmp/$i.err"
    echo $? >"$tmp/$i.rc"
  ) &
  i=$((i + 1))
done
wait

# Keep the ones that answered; a 403 or a timeout is a dropped speculative lane,
# not a reason to fail the round.
cand='{}'
crit='{}'
labels=()
kept_models=()
kept_idx=()
for i in "${!models[@]}"; do
  if [ "$(cat "$tmp/$i.rc" 2>/dev/null || echo 1)" != "0" ] || [ ! -s "$tmp/$i.out" ]; then
    diag=$(tail -1 "$tmp/$i.err" 2>/dev/null || true)
    [ -z "$diag" ] && diag=$(tail -1 "$tmp/$i.out" 2>/dev/null || true)
    echo "speculate: ${models[$i]} produced nothing (rc=$(cat "$tmp/$i.rc" 2>/dev/null || echo '?')) ${diag:0:120}" >&2
    continue
  fi
  # A reasoning model can open with an inline block; strip it so the grader
  # reads the answer and the caller does not receive the marker.
  if head -c 80 "$tmp/$i.out" | grep -q 'think>'; then
    sed -e '1,/<\/think>/d' "$tmp/$i.out" >"$tmp/$i.clean"
    if [ -s "$tmp/$i.clean" ]; then mv "$tmp/$i.clean" "$tmp/$i.out"; fi
  fi

  label="c${#labels[@]}"
  labels+=("$label")
  kept_models+=("${models[$i]}")
  kept_idx+=("$i")
  text=$(head -c 2000 "$tmp/$i.out")
  cand=$(jq -n --argjson prev "$cand" --arg k "$label" --arg v "$text" '$prev + {($k): $v}')
  crit=$(jq -n --argjson prev "$crit" --arg k "$label" --arg v "candidate $label, written by ${models[$i]}" '$prev + {($k): $v}')
done

if [ ${#labels[@]} -eq 0 ]; then
  echo "speculate: every lane failed; no round to grade" >&2
  exit 1
fi

if [ ${#labels[@]} -eq 1 ]; then
  # Nothing to choose between. Emitting it beats paying for a one-option Jev
  # call that can only return that option.
  if [ "$json" -eq 1 ]; then
    jq -n --arg q "$question" --arg m "${kept_models[0]}" --rawfile t "$tmp/${kept_idx[0]}.out" \
      '{question: $q, candidates: [{label: "c0", model: $m}], decision: null, winner: {label: "c0", model: $m, text: $t}}'
  else
    cat "$tmp/${kept_idx[0]}.out"
  fi
  exit 0
fi

request="$tmp/request.json"
jq -n --arg q "$question" --argjson cand "$cand" --argjson crit "$crit" \
  '{state: {question: $q, candidates: $cand},
    questions: {best: {type: "choice",
                       instructions: "Pick the candidate that answers the question most accurately, concretely and without invented facts. Prefer a specific claim over a hedge.",
                       criteria: $crit}}}' >"$request"

set +e
decision=$(jev-decide decide --provider typesafe "$request" 2>"$tmp/jev.err")
jev_rc=$?
set -e

# The decision is JSON or nothing; a stray error line would break --argjson.
if ! printf '%s' "$decision" | jq -e . >/dev/null 2>&1; then
  decision=""
fi

chosen=''
if [ "$jev_rc" -eq 0 ]; then
  chosen=$(printf '%s' "$decision" | jq -r '.decisions.best.value // empty')
elif [ "$jev_rc" -eq 2 ]; then
  # needs_review still names its top choice; a review is a signal, not a veto.
  chosen=$(printf '%s' "$decision" | jq -r '.decisions.best.value // empty')
  echo "speculate: Jev returned needs_review; using its top choice as a draft, not as a verdict" >&2
else
  echo "speculate: Jev failed (rc=$jev_rc), returning the first lane" >&2
fi

if [ -z "$chosen" ]; then
  chosen=${labels[0]}
fi

label_idx=${chosen#c}
out="$tmp/${kept_idx[$label_idx]:-${kept_idx[0]}}.out"
model=${kept_models[$label_idx]:-unknown}
status=$(printf '%s' "$decision" | jq -r '.decisions.best.status // "-"' 2>/dev/null || echo -)
prob=$(printf '%s' "$decision" | jq -r '(.decisions.best.probability // "-") | if type == "number" then (.*100|round/100) else . end' 2>/dev/null || echo -)
margin=$(printf '%s' "$decision" | jq -r '(.decisions.best.margin // "-") | if type == "number" then (.*100|round/100) else . end' 2>/dev/null || echo -)

echo "speculate: ${#labels[@]} lanes, Jev chose $chosen ($model) p=$prob m=$margin [$status]" >&2

if [ "$json" -eq 1 ]; then
  jq -n --arg q "$question" --argjson d "${decision:-null}" --arg l "$chosen" --arg m "$model" \
    --rawfile t "$out" --argjson cand "$cand" \
    '{question: $q, candidates: ($cand | keys), decision: $d.decisions.best, winner: {label: $l, model: $m, text: $t}}'
else
  cat "$out"
fi
