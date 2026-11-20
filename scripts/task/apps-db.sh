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
# Usage: apps-db.sh <list|search|get|update|upsert|overview|queue|export|status|query|doctor> …
set -euo pipefail

api=${APPFLOW_API:-https://delphi.cloudforest-kardashev.ts.net:8450}
# The bare name resolves only where MagicDNS and an ssh alias both carry it;
# the tailnet FQDN answers from every client.
delphi_host=${DELPHI_HOST:-delphi.cloudforest-kardashev.ts.net}
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


# Every transport probe is bounded: a client that lacks a piece answers no in a
# few seconds, instead of sitting on Tailscale's interactive check until the
# shell gives up (measured 2026-11-16: 240 s on a single apps:query).
pg_local() { PGCONNECT_TIMEOUT=3 psql -w -d email_archive -Atc 'select 1' >/dev/null 2>&1; }
ssh_ok() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 8 ssh "${ssh_opts[@]}" "$delphi_host" true >/dev/null 2>&1
  else
    ssh "${ssh_opts[@]}" "$delphi_host" true >/dev/null 2>&1
  fi
}
ssh_opts=(-o BatchMode=yes -o NumberOfPasswordPrompts=0 -o ConnectTimeout=5)

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
  upsert [file|-]          upsert an application record (JSON on stdin or in a file)
  overview                 stage counts
  queue                    messages waiting for agent:apps (the sync drains them hourly)
  export [file|-]          applications.json from the database (snake_case)
  status                   totals, newest change, queue depth
  query <sql>              read-only SQL over the archive API; psql or ssh only as a fallback
  doctor                   which transports this client has, each probe bounded

The API is $APPFLOW_API (default: delphi's tailnet mount, port 8450).
SQL reaches delphi at $DELPHI_HOST (default: the tailnet FQDN).
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

  upsert)
    src=${1:-}
    if [ -n "$src" ] && [ "$src" != "-" ]; then
      [ -r "$src" ] || { echo "apps-db: cannot read $src" >&2; exit 2; }
      body=$(cat "$src")
    else
      body=$(cat)
    fi
    if [ -z "$body" ]; then
      echo "apps-db: upsert needs a JSON record on stdin or a file" >&2
      exit 2
    fi
    # The route answers 404 for a missing key, so every key is sent and a field
    # the caller omitted becomes null. Both spellings are accepted because the
    # export is snake_case and the API is camelCase, and the caller should not
    # have to remember which side of that line it is on.
    payload=$(printf '%s' "$body" | jq -c '
      def f($camel; $snake): (.[$camel] // .[$snake]);
      {
        id: .id,
        company: (.company // "unknown"),
        role: (.role // "unknown"),
        category: (.category // "other"),
        language: (.language // "en"),
        fit: (.fit // null),
        status: (.status // ""),
        stage: (.stage // ""),
        nextAction: f("nextAction"; "next_action"),
        applyUrl: f("applyUrl"; "apply_url"),
        coverLetterUrl: f("coverLetterUrl"; "cover_letter_url"),
        resumeUrl: f("resumeUrl"; "resume_url"),
        gmail: (.gmail // null),
        reviewFlag: f("reviewFlag"; "review_flag"),
        notes: (.notes // null),
        folderPath: f("folderPath"; "folder_path"),
        messageId: f("messageId"; "message_id"),
        recruiterEmail: f("recruiterEmail"; "recruiter_email"),
        createdAt: f("createdAt"; "created_at"),
        updatedAt: f("updatedAt"; "updated_at"),
        origin: (.origin // "manual")
      }') || { echo "apps-db: record is not valid JSON" >&2; exit 2; }
    if [ "$(printf '%s' "$payload" | jq -r '.id // ""')" = "" ]; then
      echo "apps-db: upsert needs an id" >&2
      exit 2
    fi
    curl -fsS -X POST -H 'content-type: application/json' -d "$payload" \
      "$api/api/application-upsert" \
      | jq -r '.[0] | "\(.id)\t\(.company)\t\(.stage)"' \
      | rows
    ;;

  query)
    sql=${*:-}
    if [ -z "$sql" ]; then usage; exit 2; fi
    # The read-only route is the transport every tailnet client has: it replaced
    # the ssh hop that stalled on a Tailscale auth check. A 404 means the archive
    # predates the route and 000 means it is unreachable, and only those two fall
    # through to SQL proper; a refusal from the route is the answer, not a retry.
    out=$(mktemp)
    trap 'rm -f "$out"' EXIT
    code=$(curl -sS -m 20 -o "$out" -w '%{http_code}' -X POST \
      -H 'content-type: application/json' \
      -d "$(jq -cn --arg q "$sql" '{q: $q}')" \
      "$api/api/pipeline-sql" 2>/dev/null || echo 000)
    case "$code" in
      2*)
        jq -r 'if length == 0 then empty
               else (.[0] | keys_unsorted | @tsv), (.[] | [.[]] | @tsv) end' "$out"
        exit 0
        ;;
      404 | 000) : ;;
      *)
        echo "apps-db: the archive refused the statement" >&2
        cat "$out" >&2
        exit 1
        ;;
    esac
    if pg_local; then
      exec psql -d email_archive -Atc "$sql"
    fi
    # SQL is the one verb the API does not expose, so it is the only one that may
    # need delphi itself. Probe before spending the caller's time: a client
    # without the role used to wait four minutes on an auth prompt.
    if ! ssh_ok; then
      echo "apps-db: no SQL transport on this host" >&2
      echo "apps-db: the archive role lives on delphi and ssh to $delphi_host is not answering" >&2
      echo "apps-db: pipeline verbs still work over the API — task apps:doctor says which" >&2
      exit 3
    fi
    # The pipe keeps the SQL out of the remote shell's quoting.
    printf '%s\n' "$sql" | ssh "${ssh_opts[@]}" "$delphi_host" \
      "sudo -u postgres psql -d email_archive -At"
    ;;

  doctor)
    # One call answers what this client can do, so nobody discovers a missing
    # transport by waiting for a timeout.
    if body=$(curl -fsS -m 6 "$api/api/application-pipeline" 2>&1); then
      printf 'api       reachable (%s stage(s)) — list, search, get, update, upsert, export\n' \
        "$(printf '%s' "$body" | jq 'length' 2>/dev/null || echo '?')"
    else
      printf 'api       UNREACHABLE — %s\n' "$(printf '%s' "$body" | head -1)"
    fi
    if curl -fsS -m 6 -X POST -H 'content-type: application/json' \
      -d '{"q":"select 1"}' "$api/api/pipeline-sql" >/dev/null 2>&1; then
      printf 'sql       over the API (/api/pipeline-sql) — apps:query runs anywhere\n'
    elif pg_local; then
      printf 'sql       local role answers — apps:query runs here\n'
    elif ssh_ok; then
      printf 'sql       over ssh to %s — apps:query runs here\n' "$delphi_host"
    else
      printf 'sql       absent — role is on delphi, ssh not answering; apps:query exits 3\n'
    fi
    if [ -d "${APPS_DIR:-/srv/data/projects/antigravity-application-workflow}" ]; then
      printf 'typst     checkout mounted — build, audit, followups\n'
    elif ssh -n -o BatchMode=yes -o ConnectTimeout=5 "${APPS_HOST:-frieren}" true 2>/dev/null; then
      printf 'typst     no checkout here — build, audit, followups delegate to %s over ssh\n' "${APPS_HOST:-frieren}"
    else
      printf 'typst     absent — no checkout and %s not answering; build, audit, followups exit 127\n' "${APPS_HOST:-frieren}"
    fi
    if [ -f "${PII_FILE:-$HOME/.config/appflow/pii.json}" ]; then
      printf 'pii       %s\n' "${PII_FILE:-$HOME/.config/appflow/pii.json}"
    else
      printf 'pii       absent — run task apps:pii:sync on this host\n'
    fi
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
