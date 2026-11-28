#!/usr/bin/env bash
# Fixture for the portfolio UI assertions with no browser and no clanker.
#
# `run.sh` splits into a probe (what the page showed) and `verify.py` (whether
# that is working). This feeds `verify.py` canned probe answers through
# `BROWSER_STUB_PAYLOAD`, so the decision half is checkable on any host: the good
# payload passes, and two mutations prove the assertions still watch the metric
# cards and the writes the page is supposed to send.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
runner="$here/../run.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

[ -f "$runner" ] || {
  echo "fixture: $runner is missing" >&2
  exit 2
}

python3 - "$work" <<'PY'
import json, pathlib, sys

work = pathlib.Path(sys.argv[1])
base = work / "good"
base.mkdir()

jobs = {
    "loaded": 2,
    "metrics": {"metric-jobs": "12", "metric-companies": "5", "metric-remote": "7", "metric-fresh": "9"},
    "exports": ["/api/postings/export?format=csv", "/api/postings/export?format=json",
                "/api/postings/export?format=markdown"],
    "firstTitle": "Platform Engineer",
    "stageBadges": ["applied", "saved"],
    "detailOpen": True,
    "stageOptions": ["saved", "applied", "interview", "offer", "rejected", "archived"],
    "noteForm": True,
    "packetExport": "/api/postings/export?format=markdown&id=1",
    "journal": ["saved → applied moved by hand", "note recruiter call"],
    "afterStage": "interview",
    "journalAfterNote": ["note spoke to the hiring manager", "saved → applied moved by hand"],
    "filteredRows": 1,
}
deals = {
    "loaded": 2,
    "stats": ["2", "3", "14", "1"],
    "exports": ["/api/export.csv", "/api/deals/export", "/api/deals/feed.rss", "/api/deals/feed.atom"],
    "spark": True,
    "figures": "14 price points · 30 d 2 products falling 0 products rising −20% SSD 2TB",
    "window": "last 30 days · avg €199.00",
    "drops": ["drop €249.00 → €199.00 SSD 2TB dropped"],
    "alerts": 1,
    "toastAll": "Watchlist poll started",
    "toastOne": "Watchlist poll already running",
    "detailOpen": True,
    "historyBars": 2,
}
log_jobs = [
    {"method": "PATCH", "path": "/api/postings/1/stage", "body": {"stage": "interview", "follow_up_at": ""}},
    {"method": "POST", "path": "/api/postings/1/notes", "body": {"note": "spoke to the hiring manager"}},
]
log_deals = [
    {"method": "POST", "path": "/api/watchlists/poll", "body": {}},
    {"method": "POST", "path": "/api/watchlists/1/poll", "body": {}},
]

def write(name, document):
    (base / name).write_text(json.dumps(document))

write("jobs.json", jobs)
write("deals.json", deals)
write("log-jobs.json", log_jobs)
write("log-deals.json", log_deals)

bad_metrics = work / "bad-metrics"
bad_metrics.mkdir()
write = lambda name, document: (bad_metrics / name).write_text(json.dumps(document))
write("jobs.json", dict(jobs, metrics={"metric-jobs": "0", "metric-companies": "0",
                                       "metric-remote": "0", "metric-fresh": "0"}))
write("deals.json", deals)
write("log-jobs.json", log_jobs)
write("log-deals.json", log_deals)

no_patch = work / "no-patch"
no_patch.mkdir()
write = lambda name, document: (no_patch / name).write_text(json.dumps(document))
write("jobs.json", jobs)
write("deals.json", deals)
write("log-jobs.json", [log_jobs[1]])
write("log-deals.json", log_deals)
PY

EXPECTED=(
  "the good probe answers pass"
  "metric cards that read zero fail"
  "a missing stage PATCH fails"
)
ran=()
failed=0

run_case() {
  local case=$1 payload=$2 want=$3 needle=$4
  ran+=("$case")
  local code=0 out=""
  out=$(BROWSER_STUB=/bin/false BROWSER_STUB_PAYLOAD="$payload" bash "$runner" 2>&1) || code=$?
  if [ "$code" != "$want" ]; then
    printf 'FAIL %s: exit %s, expected %s\n' "$case" "$code" "$want" >&2
    printf '  output: %s\n' "$(printf '%s' "$out" | tail -3 | tr '\n' ' ')" >&2
    failed=1
  elif [ -n "$needle" ] && ! printf '%s' "$out" | grep -q "$needle"; then
    printf 'FAIL %s: output never said %s\n' "$case" "$needle" >&2
    printf '  output: %s\n' "$(printf '%s' "$out" | tail -3 | tr '\n' ' ')" >&2
    failed=1
  fi
}

run_case "the good probe answers pass" "$work/good" 0 "PASS jobs: 2 postings"
run_case "metric cards that read zero fail" "$work/bad-metrics" 1 "the metric cards read"
run_case "a missing stage PATCH fails" "$work/no-patch" 1 "no PATCH to the stage route"

for case in "${EXPECTED[@]}"; do
  seen=0
  for ran_case in "${ran[@]}"; do
    [ "$ran_case" = "$case" ] && seen=1
  done
  [ "$seen" = 1 ] || {
    printf 'FAIL %s: listed in EXPECTED but never ran\n' "$case" >&2
    failed=1
  }
done
for ran_case in "${ran[@]}"; do
  seen=0
  for case in "${EXPECTED[@]}"; do
    [ "$ran_case" = "$case" ] && seen=1
  done
  [ "$seen" = 1 ] || {
    printf 'FAIL %s: ran but is not in EXPECTED\n' "$ran_case" >&2
    failed=1
  }
done

if [ "$failed" != 0 ]; then
  echo "portfolio-ui-stub: fixture failed" >&2
  exit 1
fi
printf 'ok   portfolio-ui-stub: %d cases\n' "${#EXPECTED[@]}"
