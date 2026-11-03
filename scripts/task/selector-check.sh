#!/usr/bin/env bash
# selector-check.sh — measure the selector and gate the property that must hold.
#
# Batteries are TOON ([[flake/policies.nix#agent-boundary-is-toon]]): the labels
# are agent-authored, so they are decoded by the converter and strict-checked,
# never hand-parsed. A miscounted [n] or mangled quote fails here with the repair
# command, not in a silent zero-row answer.
#
# What M0 measures (docs/selector-daemon-predesign.md §8): the battery carries the
# gold QUERY OBJECT and the gold ROW SET, both derived from the compiled data. So
# the numbers are about the half a model cannot fix if it is wrong:
#
#   p         answered cases whose row set EQUALS gold / answered cases
#   coverage  answered / asked (a refusal is a valid answer, not a failure)
#   S         median save in seconds: (direct_bytes - answer_bytes)/4/50, where
#             answer_bytes is the TOON the agent reads and direct is the compiled
#             artifact it would otherwise have to load and scan
#   refusal   mean wall time of the abstain cases (the predesign's bar is 100 ms)
#   ev        p*S - (1-p)*1.2, the Kelly score flake/daemons.nix records
#
# The battery drives scripts/task/q.sh directly, not `task ops:q`: task startup is
# ~120 ms on every call and would be counted as the selector's cost, so the
# numbers here are the query and the executor, measured apart from the wrapper.
# Q_NO_SIDECAR=1 for the same reason: these are the numbers a host WITHOUT the
# resident unit gets, which is what the scoring should mean. The accelerator's
# parity and speed are `checks:selector:sidecar`'s question, not this gate's.
#
# Exit: 0 = every scored case correct and every abstain case refused; 1 = a wrong
# row set, an answered abstain, an unavailable registry on a scored case, or a
# battery that does not decode; 2 = usage (no battery / no q.sh).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BATTERY="${1:-$REPO/scripts/task/selector-battery.toon}"
Q="$REPO/scripts/task/q.sh"
export Q_NO_SIDECAR=1
COST=1.2
TOKEN_RATE=50.0
BYTES_PER_TOKEN=4.0

[ -f "$BATTERY" ] || {
  echo "selector-check: no battery at $BATTERY" >&2
  exit 2
}
[ -f "$Q" ] || {
  echo "selector-check: no executor at $Q" >&2
  exit 2
}

data="$(mktemp)"
err="$(mktemp)"
trap 'rm -f "$data" "$err"' EXIT

# The executor's own edge cases first: if a refusal class or the budget cut is
# broken, the battery below is measuring the wrong machine. It is offline and
# fixture-fed, so it costs nothing and runs on any host.
if ! bash "$Q" --self-test; then
  echo "selector-check: q.sh self-test failed" >&2
  exit 1
fi
echo

if ! toon -d "$BATTERY" >"$data" 2>"$err"; then
  echo "selector-check: the battery does not decode as TOON:" >&2
  cat "$err" >&2
  echo "  repair: task dev:toon:fix FILES=${BATTERY#"$REPO"/}" >&2
  exit 1
fi

now_ms() {
  if [ -n "${EPOCHREALTIME:-}" ]; then
    local t="${EPOCHREALTIME/./}"
    printf '%s' "$((t / 1000))"
  else
    date +%s%3N
  fi
}

asked=0
answered=0
correct=0
refused=0
skipped=0
weak_ok=0
unavailable=0
saves=()
refusal_ms=()
failures=""

while IFS= read -r row; do
  prompt="$(jq -r '.prompt' <<<"$row")"
  args="$(jq -r '.args' <<<"$row")"
  gold="$(jq -r '.rows' <<<"$row")"
  want_refuse="$(jq -r '.refuse' <<<"$row")"
  direct_bytes="$(jq -r '.direct_bytes' <<<"$row")"
  weak="$(jq -r '.weak' <<<"$row")"

  read -r -a argv <<<"$args"
  t0="$(now_ms)"
  # A refusal is an expected exit, not an error: capturing it outside `set -e`
  # is what lets an abstain case be a PASS.
  rc=0
  out="$(bash "$Q" "${argv[@]}" --json 2>/dev/null)" || rc=$?
  ms=$(($(now_ms) - t0))

  if [ "$rc" = 1 ]; then
    # A registry that does not exist here (the sentinel ledger on a host that
    # does not run fleet-sentinel) is not this battery's regression. A weak case
    # is skipped; a scored one is a failure, because a check may not pass by
    # being unable to run.
    if [ "$weak" = "yes" ]; then
      skipped=$((skipped + 1))
      printf '%-4s %-62s skipped (registry unavailable)\n' "SKIP" "$prompt"
      continue
    fi
    unavailable=$((unavailable + 1))
    failures="${failures}  UNAVAILABLE  ${prompt} (${args})\n"
    printf '%-4s %-62s registry unavailable\n' "FAIL" "$prompt"
    continue
  fi

  asked=$((asked + 1))

  if [ "$want_refuse" != "no" ]; then
    refused=$((refused + 1))
    refusal_ms+=("$ms")
    # The class matters: `schema` is a query the registry cannot express and
    # `empty` is a question the data does not answer. Getting the wrong one means
    # the refusal is a coincidence, not a contract.
    got="$(jq -r '.reason // "answered"' <<<"$out" 2>/dev/null || echo answered)"
    if [ "$rc" = 0 ] || [ "$got" != "$want_refuse" ]; then
      failures="${failures}  ANSWERED  ${prompt} (${args}) -> rc=${rc} ${got}\n"
      printf '%-4s %-62s refused as %s, wanted %s\n' "FAIL" "$prompt" "$got" "$want_refuse"
    else
      printf '%-4s %-62s %sms (%s)\n' "OK" "$prompt" "$ms" "$got"
    fi
    continue
  fi

  if [ "$rc" != 0 ]; then
    failures="${failures}  REFUSED  ${prompt} (${args}) -> rc=${rc}\n"
    printf '%-4s %-62s refused (rc=%s)\n' "FAIL" "$prompt" "$rc"
    continue
  fi

  got_ids="$(jq -r '[.rows[].id] | sort | join("|")' <<<"$out")"
  # LC_ALL=C: the gold set is compared byte-for-byte with jq's `sort`, and the
  # locale collation orders `doc:.agents/…` after `doc:AGENTS.md`, which made an
  # identical set look wrong.
  want_ids="$(printf '%s' "$gold" | tr '|' '\n' | LC_ALL=C sort -u | paste -sd'|')"
  bytes="$(jq -r '.bytes' <<<"$out")"

  # A weak case proves the registry answers at all — the ledger is host-local, so
  # there is no honest gold row set for it. It is never scored into p.
  if [ "$weak" = "yes" ]; then
    weak_ok=$((weak_ok + 1))
    printf '%-4s %-62s %s rows (weak, not scored)\n' "OK" "$prompt" "$(jq -r '.count' <<<"$out")"
    continue
  fi

  answered=$((answered + 1))

  if [ "$got_ids" = "$want_ids" ]; then
    correct=$((correct + 1))
    saves+=("$(awk -v d="$direct_bytes" -v b="$bytes" -v t="$BYTES_PER_TOKEN" -v r="$TOKEN_RATE" 'BEGIN {printf "%.4f", (d - b) / t / r}')")
    printf '%-4s %-62s %s B saved %s\n' "OK" "$prompt" "$((direct_bytes - bytes))" "$ms"
  else
    failures="${failures}  WRONG  ${prompt} (${args})\n    want: ${want_ids}\n    got:  ${got_ids}\n"
    printf '%-4s %-62s wrong row set\n' "FAIL" "$prompt"
  fi
done < <(jq -c '.[]' "$data")

median() {
  [ "$#" -gt 0 ] || {
    echo 0
    return
  }
  printf '%s\n' "$@" | sort -n | awk '{a[NR] = $1} END {print (NR % 2 ? a[(NR + 1) / 2] : (a[NR / 2] + a[NR / 2 + 1]) / 2)}'
}
mean() {
  [ "$#" -gt 0 ] || {
    echo 0
    return
  }
  printf '%s\n' "$@" | awk '{s += $1} END {printf "%.1f", s / NR}'
}

P=0
if [ "$answered" -gt 0 ]; then P="$(awk -v c="$correct" -v a="$answered" 'BEGIN {printf "%.4f", c / a}')"; fi
COV=0
if [ "$asked" -gt 0 ]; then COV="$(awk -v a="$answered" -v q="$asked" 'BEGIN {printf "%.4f", a / q}')"; fi
S="$(median ${saves[@]+"${saves[@]}"})"
REF="$(mean ${refusal_ms[@]+"${refusal_ms[@]}"})"
EV="$(awk -v p="$P" -v s="$S" -v c="$COST" 'BEGIN {printf "%.4f", p * s - (1 - p) * c}')"

echo
printf 'asked            : %s (+%s skipped)\n' "$asked" "$skipped"
printf 'answered         : %s of %s  (coverage %s; %s weak cases answered, not scored)\n' "$answered" "$asked" "$COV" "$weak_ok"
printf 'correct          : %s of %s  (p %s)\n' "$correct" "$answered" "$P"
printf 'S                : %ss median saved (TOON answer vs the compiled read)\n' "$S"
printf 'refusal          : %sms mean, %s cases\n' "$REF" "$refused"
printf 'ev               : %ss  (p*S - (1-p)*%ss)\n' "$EV" "$COST"

# --- stage 1 ----------------------------------------------------------------
# Built fresh into a temp dir, so a stale artifact can never pass this: the model
# is trained here, then asked the battery's own English prompts. The trainer's
# held-out number is the generalisation metric; the battery is "does it survive
# wording it was not templated from", and the compound cases are expected to miss
# because a one-filter object cannot express two constraints.
model_dir="$(mktemp -d)"
model="$model_dir/selector-nb.json"
stage1_status=0
if bash "$REPO/tools/selector/build.sh" "$model_dir" >"$model_dir/build.log" 2>&1; then
  held="$(jq -r '.metrics | "p \(.p) at coverage \(.coverage), \(.classes) templates, \(.test_pairs) held-out pairs"' "$model")"
  echo
  echo "stage 1          : $held (entity-held-out)"
  s1_asked=0
  s1_answered=0
  s1_correct=0
  s1_refused=0
  s1_abstained=0
  s1_wrong=""
  while IFS= read -r row; do
    prompt="$(jq -r '.prompt' <<<"$row")"
    gold="$(jq -r '.rows' <<<"$row")"
    want_refuse="$(jq -r '.refuse' <<<"$row")"
    weak="$(jq -r '.weak' <<<"$row")"
    if [ "$weak" = "yes" ]; then continue; fi
    s1_asked=$((s1_asked + 1))
    rc=0
    out="$(Q_MODEL="$model" bash "$Q" --question "$prompt" --json 2>/dev/null)" || rc=$?
    if [ "$want_refuse" != "no" ]; then
      # An abstain case must be DECLINED: answering it is the failure mode the
      # presdesign's 20 % abstain share exists to prevent.
      if [ "$rc" = 3 ]; then s1_abstained=$((s1_abstained + 1)); else
        s1_wrong="${s1_wrong}  ANSWERED  ${prompt} (rc=$rc)\n"
      fi
      continue
    fi
    if [ "$rc" != 0 ]; then
      # Declining a scorable question costs coverage, not correctness.
      s1_refused=$((s1_refused + 1))
      continue
    fi
    s1_answered=$((s1_answered + 1))
    got_ids="$(jq -r '[(.rows // [])[].id] | sort | join("|")' <<<"$out" 2>/dev/null || true)"
    want_ids="$(printf '%s' "$gold" | tr '|' '\n' | LC_ALL=C sort -u | paste -sd'|')"
    if [ "$got_ids" = "$want_ids" ]; then
      s1_correct=$((s1_correct + 1))
    else
      s1_wrong="${s1_wrong}  WRONG  ${prompt}\n    want: ${want_ids}\n    got:  ${got_ids}\n"
    fi
  done < <(jq -c '.[]' "$data")
  s1_p=0
  if [ "$s1_answered" -gt 0 ]; then
    s1_p="$(awk -v c="$s1_correct" -v a="$s1_answered" 'BEGIN {printf "%.4f", c / a}')"
  fi
  s1_cov="$(awk -v a="$s1_answered" -v q="$s1_asked" 'BEGIN {printf "%.4f", q ? a / q : 0}')"
  printf 'battery          : %s answered, %s correct (p %s), %s refused, %s abstain declined\n' \
    "$s1_answered" "$s1_correct" "$s1_p" "$s1_refused" "$s1_abstained"
  printf 'coverage         : %s of %s scored questions\n' "$s1_answered" "$s1_asked"
  if [ -n "$s1_wrong" ]; then
    printf '%b' "$s1_wrong"
  fi
  # M2's bar, and the predesign's: an answered-case p below 0.3 is not a selector.
  if awk -v p="$s1_p" 'BEGIN {exit !(p < 0.3)}'; then
    echo "stage 1          : p $s1_p is below the 0.3 floor"
    stage1_status=1
  fi
  if grep -q 'ANSWERED' <<<"$s1_wrong"; then
    stage1_status=1
  fi
else
  echo
  echo "stage 1          : not built (see $model_dir/build.log)"
  sed -n '1,3p' "$model_dir/build.log"
fi

if [ -n "$failures" ]; then
  echo
  printf '%b' "$failures"
  exit 1
fi
[ "$unavailable" -eq 0 ] || exit 1
[ "$stage1_status" -eq 0 ] || exit 1
echo "verdict          : every scored case correct, every abstain case refused"
