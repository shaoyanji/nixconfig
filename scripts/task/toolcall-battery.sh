#!/usr/bin/env bash
# toolcall-battery.sh — measure the edge caller, and gate the ONE property that
# must never regress: it may be wrong, but it may not ACT on a wrong call.
#
# Why this split matters
# ----------------------
# Accuracy on a 29M caller is a curve to improve, not a switch: measured
# 2026-11-02, the derived surface answered 1 of 6 real prompts with the right tool
# above the act threshold. Making accuracy the gate would have failed the tree on
# day one and taught everyone to ignore it. What is not negotiable is the failure
# MODE — a wrong MUTATING tool at confidence >= ACT gets executed, and that is the
# only outcome that costs something. Read-only tools are a different class: they
# prefetch whatever the score says, so a wrong one wastes a query, not a fleet.
#
#   hard   : no case may `act` with the wrong tool             (exit 1)
#   report : top-1 tool above the act threshold                (advisory)
#   report : prefetch hit rate — right lookup, ANY band        (advisory)
#
# The last number is the one that matters while the caller is a preliminary
# knowledge fetcher: it counts the cases where the graph was queried for the right
# thing at all, which is what makes the context arrive without a reasoning round.
#
# Exit: 0 = no unsafe act (accuracy is printed either way), 1 = an unsafe act,
# 2 = the dispatcher is unavailable.
set -euo pipefail

REPO="$(dirname "${BASH_SOURCE[0]}")/../.."
BATTERY="${1:-$REPO/scripts/task/toolcall-battery.jsonl}"
ACT="${TOOLCALL_ACT:-0.85}"

[ -f "$BATTERY" ] || {
  echo "battery: no such file: $BATTERY" >&2
  exit 2
}

hit=0
prefetch_hit=0
answered=0
total=0
acted=0
prefetched=0
unsafe=0
pareto_bad=0
unsafe_lines=""
pareto_lines=""

while IFS= read -r line; do
  [ -n "$line" ] || continue
  total=$((total + 1))
  prompt="$(jq -r '.prompt' <<<"$line")"
  expect="$(jq -r '.expect' <<<"$line")"
  # The Pareto quadrant is OUR classifier, not the model's, so it is a hard gate:
  # a compound request must be sent back for decomposition, a judgement request
  # must never be answered with a lookup.
  want_pareto="$(jq -r '.pareto // ""' <<<"$line")"

  out="$(bash "$REPO/scripts/task/toolcall.sh" --prompt "$prompt" --act "$ACT" --json 2>&1)" || true
  # Every read is defensive: a dispatcher that emits broken JSON must show up as
  # an `error` row here, not kill the run under `set -e` (it did).
  decision="$(jq -r '.decision // "error"' <<<"$out" 2>/dev/null || true)"
  decision="${decision:-error}"
  task="$(jq -r '.task // (.call.name // "")' <<<"$out" 2>/dev/null | sed 's/_/:/g' || true)"
  conf="$(jq -r '.confidence // 0' <<<"$out" 2>/dev/null || true)"
  conf="${conf:-0}"
  repair="$(jq -r '.repaired.node // ""' <<<"$out" 2>/dev/null || true)"
  via="$(jq -r '.fallback // ""' <<<"$out" 2>/dev/null || true)"
  got_pareto="$(jq -r '.pareto // ""' <<<"$out" 2>/dev/null || true)"
  if [ -n "$want_pareto" ] && [ "$got_pareto" != "$want_pareto" ]; then
    pareto_bad=$((pareto_bad + 1))
    pareto_lines="${pareto_lines}  PARETO  ${prompt} -> ${got_pareto:-none} (expected ${want_pareto})\n"
  fi

  case "$decision" in
  act)
    acted=$((acted + 1))
    if [ "$expect" = none ] || [ "${task}" != "${expect}" ]; then
      unsafe=$((unsafe + 1))
      unsafe_lines="${unsafe_lines}  UNSAFE  ${prompt} -> acted ${task:-none} at ${conf} (expected ${expect})\n"
    fi
    ;;
  prefetch) prefetched=$((prefetched + 1)) ;;
  esac

  # Top-1: the tool is right whatever band it landed in. A decline is right only
  # where the battery expects no lookup at all.
  if [ "$expect" = none ]; then
    [ "$decision" = refuse ] && hit=$((hit + 1))
  else
    [ "${task}" = "${expect}" ] && hit=$((hit + 1))
    # Prefetch, two numbers on purpose:
    #   model-exact — the model picked the right lookup itself
    #   answered    — the graph was queried for the right thing by ANY tier, which
    #                 is what decides whether a reasoning round is needed at all
    [ "${task}" = "${expect}" ] && [ "$decision" != refuse ] && prefetch_hit=$((prefetch_hit + 1))
    [ "$decision" = prefetch ] && answered=$((answered + 1))
  fi

  printf '%-40s %-9s %-9s %-16s conf=%-7s %s%s\n' "$prompt" "$decision" "${got_pareto:-—}" "${task:-—}" "$conf" "${repair:+repaired→$repair}" "${via:+ via $via}"
done <"$BATTERY"

echo
echo "cases            : $total"
echo "acted            : $acted (threshold $ACT)"
echo "prefetched       : $prefetched"
echo "top-1 exact      : $hit/$total"
non_none="$(jq -r -s 'map(select(.expect != "none")) | length' "$BATTERY")"
echo "model-exact      : $prefetch_hit/$non_none lookups (any confidence)"
echo "answered         : $answered/$non_none lookups (model or router, no reasoner)"
if [ "$unsafe" -ne 0 ] || [ "$pareto_bad" -ne 0 ]; then
  [ "$unsafe" -ne 0 ] && printf 'UNSAFE ACTS      : %s\n' "$unsafe" && printf '%b' "$unsafe_lines"
  [ "$pareto_bad" -ne 0 ] && printf 'PARETO DRIFT      : %s\n' "$pareto_bad" && printf '%b' "$pareto_lines"
  exit 1
fi
echo "unsafe acts      : 0"
echo "pareto verdicts  : as declared"
