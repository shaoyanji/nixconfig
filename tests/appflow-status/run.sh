#!/usr/bin/env bash
# Regression fixture for the status-quality rule in scripts/task/appflow-check.sh.
#
# The gate reads the pipeline from the API in production; here it reads two
# files, so the rule is asserted rather than assumed: a status that only repeats
# its stage, an empty status and a placeholder status must each fail, and a
# described pipeline must pass. The other rules ride through the same feed — a
# dead prep row and a shared active mail still fail — which is what proves the
# fixture drives the real checks instead of a copy of them.
#
# Coverage is asserted both ways: a case listed in EXPECTED that no longer runs
# fails, and so does a case that runs without being listed.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
gate="$repo/scripts/task/appflow-check.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

for cmd in jq bash; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "fixture: $cmd is required" >&2
    exit 2
  }
done
[ -f "$gate" ] || {
  echo "fixture: $gate is missing" >&2
  exit 2
}

EXPECTED=(
  "a described pipeline passes"
  "a status that repeats its stage fails"
  "a status differing only in case fails"
  "an empty status fails"
  "a placeholder status fails"
  "a dead prep row still fails"
  "a shared active mail still fails"
  "a vacuous pipeline is refused"
  "a declared duplicate pair passes"
)

fail=0
ran=()

# case_run <name> <want-rc> <rows-json> [links-json] [needle]
#   `needle` is a string the report must name when the rule fires, so a failure
#   for the wrong reason cannot pass as the right one.
case_run() {
  local name="$1" want="$2" rows="$3" links="${4:-[]}" needle="${5:-}" out rc
  printf '%s' "$rows" >"$work/rows.json"
  printf '%s' "$links" >"$work/links.json"
  out=$(APPFLOW_ROWS="$work/rows.json" APPFLOW_LINKS="$work/links.json" bash "$gate" 2>&1)
  rc=$?
  ran+=("$name")
  if [ "$rc" != "$want" ]; then
    fail=1
    echo "FAIL $name: exit $rc, want $want ($(printf '%s' "$out" | tail -1))"
    return
  fi
  if [ -n "$needle" ] && ! grep -qF -- "$needle" <<<"$out"; then
    fail=1
    echo "FAIL $name: exit $rc but the report never said: $needle"
    return
  fi
  echo "ok   $name"
}

row() { # id stage status
  jq -nc --arg id "$1" --arg stage "$2" --arg status "$3" \
    '[{id: $id, company: "Acme", role: "SRE", stage: $stage, status: $status}]'
}

# --- the rule ------------------------------------------------------------
case_run "a described pipeline passes" 0 \
  "$(row ok-row applied "Applied 2026-11-22 — 1 mail linked")" \
  '[]' "ok   every status says more than its stage"

case_run "a status that repeats its stage fails" 1 \
  "$(row bare-row applied "applied")" \
  '[]' "bare-row"

case_run "a status differing only in case fails" 1 \
  "$(row shouty-row applied "APPLIED")" \
  '[]' "shouty-row"

case_run "an empty status fails" 1 \
  "$(row empty-row prep "")" \
  '[]' "empty-row"

case_run "a placeholder status fails" 1 \
  "$(row unknown-row other "unknown")" \
  '[]' "unknown-row"

# --- the rules that were already there, through the same feed ------------
case_run "a dead prep row still fails" 1 \
  "$(row dead-prep prep "Closed — requisition filled 2026-11-02")" \
  '[]' "dead-prep"

case_run "a shared active mail still fails" 1 \
  "$(row linked-row applied "Applied 2026-11-22 — 1 mail linked")" \
  '[{"messageId": "shared@example", "apps": 2}]' \
  "shared@example"

# --- the refusal ---------------------------------------------------------
case_run "a vacuous pipeline is refused" 2 '[]' '[]' "refusing to pass a vacuous check"

# --- the declared exception ----------------------------------------------
case_run "a declared duplicate pair passes" 0 \
  "$(jq -nc '[
    {id: "one", company: "Acme", role: "SRE", stage: "applied", status: "Applied 2026-11-22 — 1 mail linked"},
    {id: "two", company: "Acme", role: "SRE", stage: "other", status: "Duplicate of one"}
  ]')" \
  '[]' "every duplicate pair declares its canonical row"

# --- coverage, both ways -------------------------------------------------
ran_set="$(printf '%s\n' "${ran[@]}")"
expected_set="$(printf '%s\n' "${EXPECTED[@]}")"
for c in "${EXPECTED[@]}"; do
  if ! grep -qxF -- "$c" <<<"$ran_set"; then
    echo "FAIL coverage: expected case did not run: $c" >&2
    fail=1
  fi
done
for c in "${ran[@]}"; do
  if ! grep -qxF -- "$c" <<<"$expected_set"; then
    echo "FAIL coverage: case is not declared in EXPECTED: $c" >&2
    fail=1
  fi
done

if [ "$fail" != 0 ]; then
  echo "appflow-status fixture: FAILED" >&2
  exit 1
fi
echo "appflow-status fixture: ${#EXPECTED[@]} cases ok (all expected)"
