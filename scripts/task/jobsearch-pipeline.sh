#!/usr/bin/env bash
# The sweep-to-upsert chain as one run: fetch six boards, rank in-lane leads
# against the record, file the survivors, read the mail loop, post the turn.
#
# Every step is a primitive that already exists — the sweep is
# scripts/task/jobsearch-sweep.py, the write is `apps:scout` (the lane's own
# writer), the mail read is the archive API, the turn is `agents:xs:post`. This
# file only sequences them and reports what each one proved, so a sweep cannot
# skip the dedupe or claim a lead it never filed.
#
# There is no local fallback for the held list, on purpose. apps-db.sh caches
# nothing — it asks the API on every call — so when delphi is down the only
# local material is the row filenames under ~/.local/state/appflow/submissions.
# Measured 2026-11-26: a 149-name proxy cut from those slugs (employer part,
# role words trimmed) reported 93 new employers where the record reported 1, and
# that one, `Bundesamt fuer Migration und Fluechtlinge`, was the already-tracked
# `bamf-devops` row under its full name. A slug is not an employer name, so
# dedupe against one manufactures the duplicates apps:add exists to refuse; the
# sweep refuses instead.
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$here/../.." && pwd) || exit 1
cd "$root" || exit 1

boards="germantechjobs,weworkremotely,remoteok,berlinstartupjobs,stepstone,arbeitnow"
sweep="$(date +%F)"
days=7
limit=25
apply=0
mail=0
xs=0
gh=0

while [ $# -gt 0 ]; do
  case "$1" in
    --boards) boards=${2:-}; shift 2 ;;
    --sweep) sweep=${2:-}; shift 2 ;;
    --days) days=${2:-7}; shift 2 ;;
    --limit) limit=${2:-25}; shift 2 ;;
    --apply) apply=1; shift ;;
    --mail) mail=1; shift ;;
    --xs) xs=1; shift ;;
    --gh) gh=1; shift ;;
    -h | --help) sed -n '2,10p' "$0"; exit 0 ;;
    *)
      echo "jobsearch-pipeline: unknown flag $1" >&2
      exit 2
      ;;
  esac
done

command -v python3 >/dev/null 2>&1 || {
  echo "jobsearch-pipeline: python3 is required for the sweep" >&2
  exit 1
}

# apps:scout accepts four families; the title decides which, and the fallback is
# the lane's own name rather than a fifth value the writer would refuse.
family_of() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    *sre* | *reliability*) printf 'sre' ;;
    *platform*) printf 'platform' ;;
    *infra* | *kubernetes* | *cloud* | *network*) printf 'infrastructure' ;;
    *) printf 'devops' ;;
  esac
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
held="$work/held.txt"
ranked="$work/ranked.json"

# The record is the dedupe oracle, so it is read in full rather than from the
# 500-row list window: a window is why a first pass once reported 87 new leads
# where 35 were new.
LIM=5000 FORMAT=json bash scripts/task/apps-db.sh list 2>/dev/null |
  jq -r '.[].company' | sed 's/[[:space:]]*$//' >"$held"
held_count=$(wc -l <"$held")
if [ "$held_count" -lt 100 ]; then
  echo "jobsearch-pipeline: the record answered $held_count employers — that is no answer, not an empty market" >&2
  exit 1
fi

sweep_args=(--held "$held" --out "$ranked" --max-age "$days" --limit "$limit" --boards "$boards")
[ "$gh" = 1 ] && sweep_args+=(--gh)
python3 "$here/jobsearch-sweep.py" "${sweep_args[@]}" || exit 1

echo
echo "ranked targets (score = live postings x2 + GitHub recency x2)"
jq -r '.ranked[] | [.score, (.postings | length), (.fresh // "-"), .company,
        .postings[0].title, .postings[0].board] | @tsv' "$ranked" |
  if command -v column >/dev/null 2>&1; then column -t -s $'\t'; else cat; fi

rejected=$(jq -r '.rejected | length' "$ranked")
if [ "$rejected" -gt 0 ]; then
  echo
  echo "not filed ($rejected) — an unverifiable name is reported, never guessed:"
  jq -r '.rejected[] | [.company, .reason] | @tsv' "$ranked" |
    awk -F'\t' '!seen[$2]++ {print "  " $1 " — " $2}'
fi

filed=0
refused=0
failed=0
if [ "$apply" = 1 ]; then
  echo
  while IFS=$'\t' read -r company role url postings fresh; do
    [ -z "$company" ] && continue
    family=$(family_of "$role")
    id=$(printf '%s-%s' "$company" "$role" |
      tr '[:upper:]' '[:lower:]' |
      sed 's/[^a-z0-9]\+/-/g; s/^-//; s/-$//' | cut -c1-96)
    note="Sweep $sweep: $postings in-lane posting(s), newest ${fresh}d, $boards."
    out=$(task --silent apps:scout -- --family "$family" --company "$company" \
      --role "$role" --summary "$note" --url "$url" --sweep "$sweep" --id "$id" 2>&1)
    case $? in
      0) filed=$((filed + 1)); printf '  filed   %s (%s)\n' "$company" "$family" ;;
      2) refused=$((refused + 1)); printf '  refused %s (input refused — nothing written)\n' "$company" ;;
      *)
        failed=$((failed + 1))
        printf '  FAILED  %s — %s\n' "$company" "$(printf '%s' "$out" | tail -1 | cut -c1-120)"
        ;;
    esac
  done < <(jq -r '.ranked[] | select(.agency | not) | select(.postings[0].url != "") |
    [.company, .postings[0].title, .postings[0].url,
     (.postings | length), (.fresh // "-")] | @tsv' "$ranked")
  nolink=$(jq -r '[.ranked[] | select(.agency | not) | select(.postings[0].url == "")] | length' "$ranked")
  echo "  filed $filed, refused $refused, failed $failed, $nolink without an application link, at sweep $sweep"
fi

if [ "$mail" = 1 ]; then
  echo
  echo "mail loop"
  LIM=20 FORMAT=toon bash scripts/task/apps-db.sh queue 2>/dev/null | head -5
  since=$(date -u -d "$days days ago" +%F 2>/dev/null || date -u -v-"${days}"d +%F)
  unreflected=$(FORMAT=json bash scripts/task/apps-db.sh query \
    "select count(*) from public.emails e where e.sent_at >= date '$since' and e.sender not ilike '%loopcv%' and e.sender not ilike '%github%' and not exists (select 1 from public.application_mail m where m.message_id = e.message_id)" 2>/dev/null |
    jq -r '.[0].count // "?"' 2>/dev/null)
  echo "  unlinked reply-shaped mail since $since: ${unreflected:-unknown}"
  echo "  rules preview: task agents:apps:sync DRY=1 (nothing is written here)"
fi

if [ "$xs" = 1 ]; then
  echo
  task --silent agents:xs:post \
    SUBJECT="nixconfig:job-scout" \
    ACTION="Sweep $sweep: $(jq -r '.new' "$ranked") candidates, $filed filed, $refused refused" \
    RATIONALE="apps:sweep:pipeline ran the chain: six boards, lane filter, dedupe against the whole record, name validation before any write, then apps:scout for the survivors — the lane's own writer, so there is still one." \
    OUTCOME="done" && echo "  turn posted" || failed=$((failed + 1))
fi

echo
if [ "$failed" -gt 0 ]; then
  echo "jobsearch-pipeline: $failed step(s) failed"
  exit 1
fi
echo "jobsearch-pipeline: ok (record holds $held_count employers; $filed filed, $refused refused)"
exit 0
