#!/usr/bin/env bash
# appflow-check.sh — tracker hygiene: duplicate noise, dead prep rows, bare status,
# shared active mail.
#
#   appflow-check.sh   read-only; names every offending row and exits 1
#
# Four states accumulate because nothing else looks for them: a (company, role)
# pair where no row declares which one is real, a `prep` row whose own status says
# the requisition closed, a status that only repeats its `stage` (or is empty, or
# is a placeholder like "unknown"), and one mail linked to two applications that
# are both still moving — the shape of a `discovered-*` twin whose company string
# differs from its canonical row, so the pair rule cannot see it. The first three
# come from the row list the API serves; the link question is one read-only query
# route. The fix is never a query — it is `task agents:apps:set ID=… STATUS="…"`.
#
# `APPFLOW_ROWS` and `APPFLOW_LINKS` read files instead of the API, which is how
# tests/appflow-status proves every rule can fail without a live archive.
set -euo pipefail

api=${APPFLOW_API:-https://delphi.cloudforest-kardashev.ts.net:8450}

for cmd in curl jq; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "appflow-check: $cmd is required" >&2
    exit 2
  }
done

if [ -n "${APPFLOW_ROWS:-}" ]; then
  body=$(cat "$APPFLOW_ROWS") || {
    echo "appflow-check: cannot read $APPFLOW_ROWS" >&2
    exit 2
  }
else
  body=$(curl -sS --max-time 30 "$api/api/applications?lim=5000") || {
    echo "appflow-check: no answer from $api/api/applications" >&2
    exit 2
  }
fi
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
  # Bare means the status carries no fact beyond the bucket it already sits in:
  # empty, identical to `stage`, or one of the placeholder tokens a row gets
  # before anyone has read the mail. The tracker derives stage from the status
  # text, so a status with no words is also a stage that cannot survive the next
  # edit.
  def bare: ((.stage // "") as $st
    | ((.status // "") | ascii_downcase | gsub("^\\s+|\\s+$"; "")) as $s
    | ($s == "" or $s == $st or $s == "unknown" or $s == "n/a" or $s == "-"));
  # An active row whose role is still the placeholder the discover rule writes
  # has no requisition to work against: the sync skips such a row by design
  # (`ambiguous-undiscovered`), so the only thing that moves it is a person
  # naming the role. Name it here instead of letting it sit at applied.
  def unnamed: ((.stage // "") as $st
    | ((.role // "") | ascii_downcase) as $r
    | (($st == "prep" or $st == "applied" or $st == "screening" or $st == "interview"
        or $st == "manual" or $st == "contacted") and $r == "undiscovered"));
  . as $rows
  | ([$rows[] | select((.stage // "") == "prep") | select(dead)]) as $deadprep
  | ([$rows[] | select(bare)]) as $bare
  | ([$rows[] | select(unnamed)]) as $unnamed
  | ([$rows | group_by([.company, .role])[]
      | select(length > 1)
      | select(all(.[]; declared | not))]) as $pairs
  | [
      "total=\($rows | length)",
      "prep=\([$rows[] | select((.stage // "") == "prep")] | length)",
      "pairs=\($pairs | length)",
      "deadprep=\($deadprep | length)",
      "bare=\($bare | length)",
      "unnamed=\($unnamed | length)",
      ($pairs[] | "PAIR \(.[0].company) · \(.[0].role) (\(length) rows: \([.[].id] | join(", ")))"),
      ($deadprep[] | "DEAD \(.id) — \((.status // "")[0:72])"),
      ($bare[] | "BARE \(.id) — stage=\(.stage) status=\((.status // "(empty)")[0:56])"),
      ($unnamed[] | "UNNAMED \(.id) — stage=\(.stage) role=\(.role)")
    ] | .[]
' <<<"$body")

total=$(sed -n 's/^total=//p' <<<"$report")
prep=$(sed -n 's/^prep=//p' <<<"$report")
pairs=$(sed -n 's/^pairs=//p' <<<"$report")
deadprep=$(sed -n 's/^deadprep=//p' <<<"$report")
bare=$(sed -n 's/^bare=//p' <<<"$report")
unnamed=$(sed -n 's/^unnamed=//p' <<<"$report")

# One mail, two applications, both still moving: a twin that never declared
# itself, which is how `discovered-materna` sat at `screening` beside its
# canonical row. Answered by the read-only query route the tracker publishes.
link_q="select am.message_id, count(distinct a.id) as apps
        from application_mail am join applications a on a.id = am.application_id
        where a.stage in ('prep','applied','screening','interview','manual','contacted')
        group by 1 having count(distinct a.id) > 1
        order by 2 desc"
if [ -n "${APPFLOW_LINKS:-}" ]; then
  links=$(cat "$APPFLOW_LINKS") || {
    echo "appflow-check: cannot read $APPFLOW_LINKS" >&2
    exit 2
  }
else
  links=$(curl -sS --max-time 30 -X POST -H 'content-type: application/json' \
    -d "$(jq -nc --arg q "$link_q" '{q:$q}')" "$api/api/pipeline-sql") || {
    echo "appflow-check: no answer from $api/api/pipeline-sql" >&2
    exit 2
  }
fi
case "$links" in
  '['*) ;;
  *)
    echo "appflow-check: the link query did not answer JSON: $(printf '%s' "$links" | head -c 160)" >&2
    exit 2
    ;;
esac
shared=$(jq 'length' <<<"$links")

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

if [ "$bare" -eq 0 ]; then
  echo "ok   every status says more than its stage"
else
  echo "FAIL $bare application(s) whose status repeats its stage, is empty, or is a placeholder:" >&2
  sed -n 's/^BARE //p' <<<"$report" | sed 's/^/       /' >&2
  fail=1
fi

if [ "$unnamed" -eq 0 ]; then
  echo "ok   every active application names a role"
else
  echo "FAIL $unnamed active application(s) whose role is still the undiscovered placeholder:" >&2
  sed -n 's/^UNNAMED //p' <<<"$report" | sed 's/^/       /' >&2
  fail=1
fi

if [ "$shared" -eq 0 ]; then
  echo "ok   no mail linked to two applications that are both still moving"
else
  echo "FAIL $shared message(s) linked to more than one active application:" >&2
  jq -r '.[] | "       \((.messageId // .message_id)[0:64]) → \(.apps) active rows"' <<<"$links" >&2
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "FAIL: tracker hygiene — close, dedupe or relink the rows above (task agents:apps:set)." >&2
  exit 1
fi
echo "PASS: no duplicate noise, no dead prep row, no bare status, no unnamed role, no shared active mail."
