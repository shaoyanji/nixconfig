#!/usr/bin/env bash
# apps-db.sh — the job pipeline through the archive API (Postgres on delphi).
#
# The database is the source of truth (`86bdb73b`); the workflow checkout at
# /srv/data/projects/antigravity-application-workflow is retired as a source and
# its applications.json is a historical copy. This wrapper exists so `task
# apps:*` reads and writes the rows from any tailnet host, instead of a checkout
# only frieren has.
#
# `stage` mirrors `stage_of` in modules/plugins/appflow/sync.py, because the
# endpoint takes the bucket rather than deriving it. Changing one without the
# other is the drift this comment exists to make visible.
#
# Usage: apps-db.sh <list|search|get|update|overview|queue|export|status|query> …
set -euo pipefail

api=${APPFLOW_API:-https://delphi.cloudforest-kardashev.ts.net:8450}
verb=${1:-help}
if [ "$#" -gt 0 ]; then shift; fi

stage='def stage:
  ( . // "" | ascii_downcase ) as $s
  | if ($s | test("interview|trial|warteliste")) then "interview"
    elif ($s | startswith("rejected")) then "rejected"
    elif (($s | startswith("applied")) or ($s | startswith("application received"))) then "applied"
    elif (($s | startswith("lead")) or ($s | startswith("rezi"))) then "lead"
    elif (($s | test("screening")) or ($s | test("follow-up required"))) then "screening"
    elif ($s | test("draft|packet|\\bjd\\b")) then "prep"
    else "other" end;'

rows() {
  # A terminal table, but a pipe still works: `column` only formats when present.
  if command -v column >/dev/null 2>&1; then
    column -t -s $'\t'
  else
    cat
  fi
}

usage() {
  cat >&2 <<'EOF'
usage: apps-db.sh <verb> [args]

  list                     every tracked application, newest activity first
  search <words…>          substring over id, company, role, status, next action
  get <id>                 one record and the mail linked to it
  update <id> --status S [--next-action N]
  overview                 stage counts
  queue                    messages waiting for agent:apps (the sync drains them hourly)
  export [file|-]          applications.json from the database (snake_case)
  status                   totals, newest change, queue depth
  query <sql>              read-only SQL against email_archive on delphi

The API is $APPFLOW_API (default: delphi's tailnet mount, port 8450).
EOF
}

case "$verb" in
  list)
    curl -fsS -G "$api/api/applications" --data-urlencode "lim=${LIM:-500}" \
      | jq -r "$stage"'["stage","updated","company","role","status","next","mail"],
        ([.[] | [.stage, ((.updatedAt // "")[0:10]), .company, .role, .status,
                 (.nextAction // ""), (.linkedMail // 0)]]) | @tsv' \
      | rows
    ;;

  search)
    q=${*:-}
    if [ -z "$q" ]; then usage; exit 2; fi
    curl -fsS -G "$api/api/applications" --data-urlencode "lim=5000" \
      | jq -r --arg q "$(printf '%s' "$q" | tr '[:upper:]' '[:lower:]')" "$stage"'
          .[] | select(([.id, .company, .role, .status, (.nextAction // "")] | join(" ") | ascii_downcase) | contains($q))
          | [.stage, ((.updatedAt // "")[0:10]), .company, .role, .status, (.nextAction // "")] | @tsv' \
      | rows
    ;;

  get)
    id=${1:-}
    if [ -z "$id" ]; then usage; exit 2; fi
    row=$(curl -fsS -G "$api/api/application-get" --data-urlencode "id=$id")
    if [ "$(printf '%s' "$row" | jq 'length')" = "0" ]; then
      echo "apps-db: no application $id" >&2
      exit 1
    fi
    printf '%s' "$row" | jq -r '.[0] | to_entries[]
      | select(.value != null and .value != "")
      | "\(.key): \(.value)"'
    echo
    echo "mail:"
    curl -fsS -G "$api/api/application-mail" \
      --data-urlencode "applicationId=$id" --data-urlencode "lim=${LIM:-20}" \
      | jq -r '(.[] | [((.sentAt // "")[0:10]), .tier, .matchedBy, .subject]) | @tsv' \
      | rows
    ;;

  update)
    id=${1:-}
    if [ -z "$id" ]; then usage; exit 2; fi
    shift
    status=""
    next=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --status) status=${2:-}; shift 2 ;;
        --next-action) next=${2:-}; shift 2 ;;
        *) echo "apps-db: unknown flag $1" >&2; exit 2 ;;
      esac
    done
    if [ -z "$status" ]; then
      echo "apps-db: update needs --status" >&2
      exit 2
    fi
    current=$(curl -fsS -G "$api/api/application-get" --data-urlencode "id=$id" | jq -c '.[0] // empty')
    if [ -z "$current" ]; then
      echo "apps-db: no application $id" >&2
      exit 1
    fi
    bucket=$(printf '%s' "$status" | jq -Rr "$stage"' stage')
    if [ -z "$next" ]; then
      next=$(printf '%s' "$current" | jq -r '.nextAction // ""')
      if [ "$bucket" = "rejected" ]; then next=none; fi
    fi
    payload=$(jq -cn --arg id "$id" --arg status "$status" --arg stage "$bucket" --arg next "$next" \
      '{id: $id, status: $status, stage: $stage, nextAction: $next}')
    curl -fsS -X POST -H 'content-type: application/json' -d "$payload" "$api/api/application-update" \
      | jq -r '.[0] | "\(.id)\t\(.stage)\t\(.status)\t\(.nextAction)"' \
      | rows
    ;;

  overview)
    curl -fsS "$api/api/application-pipeline" \
      | jq -r '["stage","applications","with next action"],
          (.[] | [.stage, .applications, .withNextAction]) | @tsv' \
      | rows
    ;;

  queue)
    curl -fsS -G "$api/api/agent-queue" \
      --data-urlencode "owner=agent:apps" --data-urlencode "lim=${LIM:-100}" \
      | jq -r '(.[] | [((.sentAt // "")[0:10]), .tier, .sender, .subject]) | @tsv' \
      | rows
    ;;

  export)
    out=${1:-}
    body=$(curl -fsS "$api/api/applications-export" | jq '[.[] | {
      id, company, role, category, language, fit, status,
      next_action: (.nextAction // ""),
      apply_url: (.applyUrl // ""),
      cover_letter_url: (.coverLetterUrl // ""),
      resume_url: (.resumeUrl // ""),
      gmail: (.gmail // ""),
      review_flag: (.reviewFlag // ""),
      notes: (.notes // ""),
      folder_path: (.folderPath // ""),
      message_id: (.messageId // ""),
      recruiter_email: (.recruiterEmail // ""),
      created_at: .createdAt,
      updated_at: .updatedAt
    }]')
    if [ -z "$out" ] || [ "$out" = "-" ]; then
      printf '%s\n' "$body"
    else
      printf '%s\n' "$body" >"$out"
      echo "exported $(printf '%s' "$body" | jq 'length') applications to $out" >&2
    fi
    ;;

  status)
    apps=$(curl -fsS -G "$api/api/applications" --data-urlencode "lim=5000")
    printf 'tracked:        %s\n' "$(printf '%s' "$apps" | jq 'length')"
    printf 'newest change:  %s\n' "$(printf '%s' "$apps" | jq -r 'max_by(.updatedAt).updatedAt // "—"')"
    printf 'linked mail:    %s\n' "$(printf '%s' "$apps" | jq '[.[].linkedMail] | add // 0')"
    printf 'open queue:     %s\n\n' "$(curl -fsS -G "$api/api/agent-queue" --data-urlencode "owner=agent:apps" --data-urlencode "lim=500" | jq 'length')"
    curl -fsS "$api/api/application-pipeline" \
      | jq -r '["stage","applications","with next action"],
          (.[] | [.stage, .applications, .withNextAction]) | @tsv' \
      | rows
    ;;

  query)
    sql=${*:-}
    if [ -z "$sql" ]; then usage; exit 2; fi
    if psql -d email_archive -Atc 'select 1' >/dev/null 2>&1; then
      exec psql -d email_archive -Atc "$sql"
    fi
    # The archive's role is not on every host, so the fallback is a one-shot
    # read on delphi. The pipe keeps the SQL out of the remote shell's quoting.
    printf '%s\n' "$sql" | ssh delphi "sudo -u postgres psql -d email_archive -At"
    ;;

  help | -h | --help)
    usage
    ;;

  *)
    echo "apps-db: unknown verb $verb" >&2
    usage
    exit 2
    ;;
esac
