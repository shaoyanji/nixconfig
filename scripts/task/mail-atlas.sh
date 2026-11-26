#!/usr/bin/env bash
# mail-atlas — read-only probe over the email archive that feeds the reader.
#
# The archive is NpgsqlRest on delphi: every route is a `.sql` file, and the
# deployed route set is whatever was last switched in. `probe` answers the one
# question the site cannot: is the mailbox still moving and is the queue
# draining? The rest of the verbs exist so that question can be followed up
# without hand-building URLs.
#
# The trap this file encodes: NpgsqlRest answers **404 for an undeclared query
# parameter**, which reads exactly like a route that is not deployed. Search
# takes `q` alone (the row cap is literal in the SQL), `list-emails` takes `lim`,
# and nothing else is ever appended — measured 2026-11-26: `?q=nixos&lim=2` was
# a 404 while `?q=nixos` answered.
#
# env: EMAIL_ARCHIVE_API (default the tailnet mount), MAIL_ATLAS_MAX_MAIL_AGE_H
# (48), MAIL_ATLAS_MAX_QUEUED_MIN (30), MAIL_ATLAS_TIMEOUT (15).
#
# Exit: 0 fine, 1 a check failed or a route refused, 2 bad usage.
set -uo pipefail

api=${EMAIL_ARCHIVE_API:-https://delphi.cloudforest-kardashev.ts.net:8450}
max_age_h=${MAIL_ATLAS_MAX_MAIL_AGE_H:-48}
max_queued_min=${MAIL_ATLAS_MAX_QUEUED_MIN:-30}
timeout_s=${MAIL_ATLAS_TIMEOUT:-15}

usage() {
  cat >&2 <<'EOF'
usage: mail-atlas.sh probe | stats | recent [N] | search <query> [--fuzzy] | routes

  probe    queue-health + stats: fails when mail is stale or the queue is stuck
  stats    the counters as one row
  recent   the newest N letters (default 5)
  search   full-text search (--fuzzy for the typo-tolerant route)
  routes   the deployed contract, sorted
EOF
}

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# get <path> — body in $tmp, `code` set. No `-f`: the status is the answer.
get() {
  code=$(curl -sS -m "$timeout_s" -o "$tmp" -w '%{http_code}' "$api$1" 2>/dev/null) || code=000
  [ "$code" = "000" ] && return 1
  return 0
}

fail_route() {
  echo "mail-atlas: $1 -> HTTP $code ${2:-}" >&2
  return 1
}

cmd_probe() {
  local reasons=() stats queue newest_age open_action queued_min letters tagged newest
  if ! get "/api/queue-health"; then
    echo "mail-atlas: /api/queue-health unreachable ($api)" >&2
    return 1
  fi
  [ "$code" = "200" ] || { fail_route /api/queue-health; return 1; }
  queue=$(jq -c '.[0] // {}' "$tmp")

  if ! get "/api/atlas-stats"; then
    echo "mail-atlas: /api/atlas-stats unreachable ($api)" >&2
    return 1
  fi
  [ "$code" = "200" ] || { fail_route /api/atlas-stats; return 1; }
  stats=$(jq -c '.[0] // {}' "$tmp")

  letters=$(printf '%s' "$stats" | jq -r '.letters // 0')
  tagged=$(printf '%s' "$stats" | jq -r '.tagged // 0')
  newest=$(printf '%s' "$stats" | jq -r '.newest // ""')
  newest_age=$(printf '%s' "$queue" | jq -r '.newestMailAgeH // 0')
  open_action=$(printf '%s' "$queue" | jq -r '.openAction // 0')
  queued_min=$(printf '%s' "$stats" | jq -r '.oldestQueuedMin // 0')

  [ "$letters" -gt 0 ] || reasons+=("the archive holds no letters")
  [ "$newest_age" -le "$max_age_h" ] || reasons+=("newest mail is ${newest_age}h old (ceiling ${max_age_h}h): the importer stopped")
  [ "$queued_min" -le "$max_queued_min" ] || reasons+=("a queued letter is ${queued_min}m old (ceiling ${max_queued_min}m): the drain stopped")

  jq -nc \
    --arg verdict "$([ ${#reasons[@]} -eq 0 ] && echo ok || echo degraded)" \
    --argjson letters "$letters" --argjson tagged "$tagged" --arg newest "$newest" \
    --argjson newest_mail_age_h "$newest_age" --argjson open_action "$open_action" \
    --argjson oldest_queued_min "$queued_min" \
    --args '{verdict: $verdict, letters: $letters, tagged: $tagged, newest: $newest,
             newest_mail_age_h: $newest_mail_age_h, open_action: $open_action,
             oldest_queued_min: $oldest_queued_min, reasons: $ARGS.positional}' "${reasons[@]}"

  [ ${#reasons[@]} -eq 0 ]
}

cmd_stats() {
  if ! get "/api/atlas-stats"; then
    echo "mail-atlas: /api/atlas-stats unreachable ($api)" >&2
    return 1
  fi
  [ "$code" = "200" ] || { fail_route /api/atlas-stats; return 1; }
  local stats
  stats=$(jq -c '.[0] // {}' "$tmp")
  if get "/api/queue-health" && [ "$code" = "200" ]; then
    jq -nc --argjson s "$stats" --argjson q "$(jq -c '.[0] // {}' "$tmp")" '$s + {queue: $q}'
  else
    printf '%s\n' "$stats"
  fi
}

cmd_recent() {
  local n=${1:-5}
  case "$n" in
    '' | *[!0-9]*)
      echo "mail-atlas: recent takes a whole number of letters" >&2
      return 2
      ;;
  esac
  # `lim` is required by the SQL and is the only declared parameter.
  if ! get "/api/list-emails?lim=$n"; then
    echo "mail-atlas: /api/list-emails unreachable ($api)" >&2
    return 1
  fi
  [ "$code" = "200" ] || { fail_route "/api/list-emails?lim=$n"; return 1; }
  jq -c '.' "$tmp"
}

cmd_search() {
  local query="" route="/api/emails-search"
  while [ $# -gt 0 ]; do
    case "$1" in
      --fuzzy) route="/api/emails-fuzzy" ;;
      --*)
        echo "mail-atlas: search does not take $1" >&2
        return 2
        ;;
      *) query=$1 ;;
    esac
    shift
  done
  [ -n "$query" ] || {
    echo "mail-atlas: search needs a query" >&2
    return 2
  }
  local encoded
  encoded=$(jq -rn --arg q "$query" '$q | @uri')
  # `q` alone: a second parameter turns the answer into a 404.
  if ! get "$route?q=$encoded"; then
    echo "mail-atlas: $route unreachable ($api)" >&2
    return 1
  fi
  [ "$code" = "200" ] || { fail_route "$route?q=$encoded"; return 1; }
  jq -c '.' "$tmp"
}

cmd_routes() {
  if ! get "/openapi.json"; then
    echo "mail-atlas: /openapi.json unreachable ($api)" >&2
    return 1
  fi
  [ "$code" = "200" ] || { fail_route /openapi.json; return 1; }
  jq -r '.paths | keys | sort | .[]' "$tmp"
}

command=${1:-}
[ $# -gt 0 ] && shift
case "$command" in
  probe) cmd_probe ;;
  stats) cmd_stats ;;
  recent) cmd_recent "$@" ;;
  search) cmd_search "$@" ;;
  routes) cmd_routes ;;
  "" | -h | --help) usage; exit 2 ;;
  *)
    echo "mail-atlas: unknown verb $command" >&2
    usage
    exit 2
    ;;
esac
