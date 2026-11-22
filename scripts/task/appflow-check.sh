#!/usr/bin/env bash
# appflow-check.sh — tracker hygiene: duplicate noise, and prep rows on dead requisitions.
#
#   appflow-check.sh   read-only; names every offending row and exits 1
#
# Both states accumulate because nothing else looks for them: a (company, role)
# pair where no row declares which one is real, and a `prep` row whose own status
# says the requisition closed. Both are already in the row list the API serves,
# so this needs no SQL role and no nix. The fix is never a query — it is
# `task agents:apps:set ID=… STATUS="Duplicate of …"`, or a closed status.
set -euo pipefail

api=${APPFLOW_API:-https://delphi.cloudforest-kardashev.ts.net:8450}

for cmd in curl jq; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "appflow-check: $cmd is required" >&2
    exit 2
  }
done

body=$(curl -sS --max-time 30 "$api/api/applications?lim=5000") || {
  echo "appflow-check: no answer from $api/api/applications" >&2
  exit 2
}
case "$body" in
  '['*) ;;
  *)
    echo "appflow-check: the row list did not answer JSON: $(printf '%s' "$body" | head -c 120)" >&2
    exit 2
    ;;
esac

# A row declares itself a duplicate by saying so in the status it carries; that
# is the convention the tracker already uses, so the check reads it rather than
# inventing a column.
report=$(jq -r '
  def declared: ((.status // "") | test("duplicate|merged into"; "i"));
  def dead: ((.status // "")
    | test("closed|filled|(no longer|not) (open|available|posted|accepting|active|live)|withdrawn|cancell?ed|\\b410\\b"; "i"));
  . as $rows
  | ([$rows[] | select((.stage // "") == "prep") | select(dead)]) as $deadprep
  | ([$rows | group_by([.company, .role])[]
      | select(length > 1)
      | select(all(.[]; declared | not))]) as $pairs
  | [
      "total=\($rows | length)",
      "prep=\([$rows[] | select((.stage // "") == "prep")] | length)",
      "pairs=\($pairs | length)",
      "deadprep=\($deadprep | length)",
      ($pairs[] | "PAIR \(.[0].company) · \(.[0].role) (\(length) rows: \([.[].id] | join(", ")))"),
      ($deadprep[] | "DEAD \(.id) — \((.status // "")[0:72])")
    ] | .[]
' <<<"$body")

total=$(sed -n 's/^total=//p' <<<"$report")
prep=$(sed -n 's/^prep=//p' <<<"$report")
pairs=$(sed -n 's/^pairs=//p' <<<"$report")
deadprep=$(sed -n 's/^deadprep=//p' <<<"$report")

# An API that answers an empty list would pass every assertion below.
if [ "${total:-0}" -eq 0 ]; then
  echo "appflow-check: the API answered an empty pipeline — refusing to pass a vacuous check" >&2
  exit 2
fi

fail=0
if [ "$pairs" -eq 0 ]; then
  echo "ok   $total applications, every duplicate pair declares its canonical row"
else
  echo "FAIL $pairs undeclared duplicate pair(s):" >&2
  sed -n 's/^PAIR //p' <<<"$report" | sed 's/^/       /' >&2
  fail=1
fi

if [ "$deadprep" -eq 0 ]; then
  echo "ok   $prep prep rows, none on a closed or filled requisition"
else
  echo "FAIL $deadprep prep row(s) whose status says the requisition is dead:" >&2
  sed -n 's/^DEAD //p' <<<"$report" | sed 's/^/       /' >&2
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "FAIL: tracker hygiene — close or dedupe the rows above (task agents:apps:set)." >&2
  exit 1
fi
echo "PASS: no duplicate noise, no prep row on a dead requisition."
