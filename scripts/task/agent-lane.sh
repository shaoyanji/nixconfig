#!/usr/bin/env bash
# agent-lane.sh — the routing contract the same way toon-io.sh is the emit
# contract: classify the question to the plane that answers it, dispatch, and
# only the residue reaches a model.
#
#   agent-lane.sh "what docs touch frieren"   classify + dispatch (TOON)
#   agent-lane.sh --corpus N                  N real xs subjects, selected rate
#   agent-lane.sh --dry "question"            the decision only, no dispatch
#
# The classifier is jev-decide (one forward pass, ~1 s, ~400 tokens — the cheap
# gate, per the jevdecide skill). `selected` dispatches deterministically;
# `needs_review` exits 2 — the signal to hand the question to a reasoner, the
# same contract toolcall.sh's CONFIRM band uses.
#
#   kg-structure    -> ops:ask (rules, then the named node's bundle — no model)
#   notes-design    -> notes.sh near
#   qmd-prose       -> qmd search -c nixconfig
#   eval-compiled   -> the compiled surfaces the question's claim kind names
#   ledger-episodic -> ops:ledger tail (frieren), else the xs turn log
#   residual        -> exit 2 by design: no lane, the question earns the model
#
# Exit: 0 answered by a lane, 2 needs_review/residual (call a reasoner),
# 1 = jev unreachable or bad input.
set -euo pipefail

REPO=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
. "$REPO/scripts/task/toon-io.sh"

MIN_P="${LANE_MIN_PROBABILITY:-0.8}"
MIN_M="${LANE_MIN_MARGIN:-0.15}"

labels() {
  cat <<'EOF'
{
  "kg-structure": "what touches what: which docs, skills, hosts or modules relate to a named entity; graph traversal questions",
  "notes-design": "decisions, proposals, open work, experiments and lineage — why something is the way it is; the AGENTS.nix record",
  "qmd-prose": "a concept, runbook or explanation somewhere in docs, skills or other markdown; semantic search over prose",
  "eval-compiled": "a fact with a compiler: inventory, modules, knobs, skill index, epistemics, prose budget — nix eval answers it",
  "ledger-episodic": "what happened or is happening: fleet events, health, sentinel ledger, journald, the xs turn log",
  "residual": "anything needing generation, judgement, code edits or free-form reasoning — no deterministic plane answers it"
}
EOF
}

classify() {  # classify <text> -> the decision object on stdout
  local crit
  crit=$(mktemp)
  labels >"$crit"
  jev-decide classify --provider typesafe --text "$1" --criteria "$crit" \
    --min-probability "$MIN_P" --min-margin "$MIN_M" 2>/dev/null
  local rc=$?
  rm -f "$crit"
  return $rc
}

dispatch() {  # dispatch <lane> <question> -> TOON answer on stdout
  local lane=$1 q=$2
  case "$lane" in
    kg-structure)
      task ops:ask Q="$q" FORMAT=json 2>/dev/null | jq -c '{route, results: (.results // .bundle // .)}'
      ;;
    notes-design)
      (cd "$REPO" && bash scripts/task/notes.sh near "$q" 6) | head -40
      ;;
    qmd-prose)
      command -v qmd >/dev/null 2>&1 || { echo '{"error":"qmd not on PATH"}'; return 1; }
      qmd search "$q" -c nixconfig --format json 2>/dev/null | jq -c '.[:8] // .'
      ;;
    eval-compiled)
      jq -cn --arg q "$q" '{
        question: $q,
        candidates: [".#inventory.hosts", ".#agentSkills", ".#agentsNotes",
                     ".#epistemics.table", ".#knowledgeGraph.graph", ".#proseBudget"],
        next: "nix eval --json <attr> | toon -e"}'
      ;;
    ledger-episodic)
      if [ -r /var/lib/fleet-sentinel/ledger.jsonl ]; then
        tail -n 20 /var/lib/fleet-sentinel/ledger.jsonl | jq -sc .
      else
        (cd "$REPO" && LIMIT=10 bash scripts/task/xs-turn-list.sh 2>/dev/null) | jq -c '{turns: .}' 2>/dev/null || echo '{"note":"no local ledger; xs list is text"}'
      fi
      ;;
    *)
      printf '{"error":"no lane for %s"}\n' "$lane" >&2
      return 1
      ;;
  esac
}

corpus() {  # corpus <n> -> classify N real xs subjects, rate table
  local n=${1:-20} i=0 selected=0 review=0 err=0 lane status decision q jevrc
  local rows
  rows=$(mktemp); : >"$rows"
  while IFS= read -r q && [ "$i" -lt "$n" ]; do
    [ -z "$q" ] && continue
    i=$((i + 1))
    # jev's exit mirrors the status: 0 selected, 2 needs_review — both answers.
    decision=$(classify "$q") && jevrc=0 || jevrc=$?
    if [ "$jevrc" -le 2 ] && printf '%s' "$decision" | jq -e . >/dev/null 2>&1; then
      lane=$(printf '%s' "$decision" | jq -r '.decisions.category.value // "?"')
      status=$(printf '%s' "$decision" | jq -r '.decisions.category.status // "?"')
      [ "$status" = "selected" ] && selected=$((selected + 1)) || review=$((review + 1))
      printf '%s' "$decision" | jq -c --arg q "$q" \
        '{q:$q, lane:.decisions.category.value, status:.decisions.category.status,
          p:(.decisions.category.probability // 0)}' >>"$rows"
    else
      err=$((err + 1))
    fi
  done < <(jq -r '.turns[] | .subject // empty' "$REPO/lib/agent-turns/turns.json" | tail -n "$n")
  jq -s --argjson s "$selected" --argjson r "$review" --argjson e "$err" --argjson n "$i" '
    {corpus: $n, selected: $s, needs_review: $r, errors: $e,
     rate: (if $n > 0 then ($s / $n) else 0 end), rows: .}' "$rows" | toon_emit
  rm -f "$rows"
}

dry=0; mode=""
while [ $# -gt 0 ]; do
  case "$1" in
    --corpus) mode=corpus; shift ;;
    --dry) dry=1; shift ;;
    --json) FORMAT=json; shift ;;
    *) break ;;
  esac
done

if [ "$mode" = corpus ]; then
  corpus "${1:-20}"
  exit 0
fi

q=${*:-}
[ -n "$q" ] || { echo "usage: agent-lane.sh \"question\" | --corpus N | --dry \"q\"" >&2; exit 2; }

decision=$(classify "$q") && jevrc=0 || jevrc=$?
# 0 selected, 2 needs_review — both are answers; only >2 or unparseable is a failure.
{ [ "$jevrc" -le 2 ] && printf '%s' "$decision" | jq -e . >/dev/null 2>&1; } || {
  echo "agent-lane: jev unreachable or no key (see jevdecide skill)" >&2; exit 1; }
lane=$(printf '%s' "$decision" | jq -r '.decisions.category.value // "residual"')
status=$(printf '%s' "$decision" | jq -r '.decisions.category.status // "needs_review"')
prob=$(printf '%s' "$decision" | jq -r '.decisions.category.probability // 0')
margin=$(printf '%s' "$decision" | jq -r '.decisions.category.margin // 0')

if [ "$dry" = 1 ]; then
  jq -cn --arg q "$q" --arg l "$lane" --arg s "$status" --argjson p "$prob" --argjson m "$margin" \
    '{q:$q, lane:$l, status:$s, probability:$p, margin:$m}' | toon_emit
  [ "$status" = "selected" ] && [ "$lane" != "residual" ]
  exit $?
fi

if [ "$status" != "selected" ] || [ "$lane" = "residual" ]; then
  jq -cn --arg q "$q" --arg l "$lane" --arg s "$status" --argjson p "$prob" \
    '{q:$q, lane:$l, status:$s, probability:$p, action:"hand to a reasoner — no deterministic lane"}' | toon_emit
  exit 2
fi

answer=$(dispatch "$lane" "$q") || answer='{"error":"lane dispatch failed"}'
jq -cn --arg q "$q" --arg l "$lane" --arg s "$status" --argjson p "$prob" \
  --argjson a "$answer" '{q:$q, lane:$l, status:$s, probability:$p, answer:$a}' | toon_emit
