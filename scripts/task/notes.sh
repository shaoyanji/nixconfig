#!/usr/bin/env bash
# notes.sh — query the AGENTS.nix note projection (lib/agents-notes.nix).
#
# AGENTS.nix is the compiled home for the decisions, queue and design studies
# that used to be ARCHITECTURE.md / TODO.md / HANDOFF.md / EXPERIMENTS.md. This
# script is the human surface over `.#agentsNotes.json`; the machine surface is
# `nix eval .#agentsNotes.index` or `nix eval --json .#agentsNotes.json`.
#
# Usage: notes.sh list [STATUS] [KIND] | show ID | host HOST | module PATH | search Q
# Env: FORMAT=json emits the selected notes as JSON instead of a table.
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$REPO"

MODE="${1:-list}"
shift 2>/dev/null || true

err="$(mktemp)"
trap 'rm -f "$err"' EXIT

if ! data="$(nix eval --json .#agentsNotes 2>"$err")"; then
  cat "$err" >&2
  echo "notes: could not evaluate .#agentsNotes" >&2
  exit 1
fi

ids() {
  # stdin: array of ids -> newline list
  jq -r '.[]'
}

print_ids() {
  local list="$1"
  local n
  n="$(jq 'length' <<<"$list")"
  if [ "$n" -eq 0 ]; then
    echo "no matching notes"
    return 0
  fi
  if [ "${FORMAT:-}" = "json" ]; then
    jq --argjson ids "$list" '.notes | with_entries(select(.key as $k | $ids | index($k)))' <<<"$data"
    return 0
  fi
  printf '%-28s %-11s %-10s %s\n' "ID" "STATUS" "KIND" "TITLE"
  jq -r --argjson ids "$list" '
    .notes
    | with_entries(select(.key as $k | $ids | index($k)))
    | to_entries
    | sort_by(.value.status, .value.id)
    | .[]
    | [.key, .value.status, .value.kind, .value.title] | @tsv
  ' <<<"$data" | while IFS=$'\t' read -r id status kind title; do
    printf '%-28s %-11s %-10s %s\n' "$id" "$status" "$kind" "$title"
  done
}

case "$MODE" in
  list)
    status="${1:-}"
    kind="${2:-}"
    list="$(jq -c --arg s "$status" --arg k "$kind" '
      [.notes | to_entries[]
       | select($s == "" or .value.status == $s)
       | select($k == "" or .value.kind == $k)
       | .key]
    ' <<<"$data")"
    print_ids "$list"
    ;;
  show)
    id="${1:-}"
    if [ -z "$id" ]; then
      echo "usage: notes.sh show ID=<id>   (see: notes.sh list)" >&2
      exit 2
    fi
    if ! jq -e --arg id "$id" '.notes[$id] != null' <<<"$data" >/dev/null; then
      echo "notes: no note '$id' (near matches:)" >&2
      jq -r --arg id "$id" '.notes | keys[] | select(test($id; "i"))' <<<"$data" | head -8 >&2
      exit 1
    fi
    if [ "${FORMAT:-}" = "json" ]; then
      jq --arg id "$id" '.notes[$id]' <<<"$data"
      exit 0
    fi
    jq -r --arg id "$id" '
      .notes[$id]
      | "# \(.title)",
        "",
        "\(.status)\(if .priority then " · \(.priority)" else "" end) · \(.kind)\(if .date then " · \(.date)" else "" end)",
        "",
        .summary,
        (if (.refs.hosts + .refs.modules + .refs.tasks + .refs.docs) | length > 0
         then "", "refs:",
           (if (.refs.hosts | length) > 0 then "  hosts:   \(.refs.hosts | join(", "))" else empty end),
           (if (.refs.modules | length) > 0 then "  modules: \(.refs.modules | join(", "))" else empty end),
           (if (.refs.tasks | length) > 0 then "  tasks:   \(.refs.tasks | join(", "))" else empty end),
           (if (.refs.docs | length) > 0 then "  docs:    \(.refs.docs | join(", "))" else empty end)
         else empty end),
        (if (.links | length) > 0 then "", "related: \(.links | join(", "))" else empty end),
        (if .body != "" then "", .body else empty end)
    ' <<<"$data"
    ;;
  host)
    host="${1:-}"
    [ -n "$host" ] || { echo "usage: notes.sh host HOST=<host>" >&2; exit 2; }
    print_ids "$(jq -c --arg h "$host" '.byHost[$h] // []' <<<"$data")"
    ;;
  module)
    path="${1:-}"
    [ -n "$path" ] || { echo "usage: notes.sh module PATH=<repo-relative path>" >&2; exit 2; }
    print_ids "$(jq -c --arg p "$path" '.byModule[$p] // []' <<<"$data")"
    ;;
  task)
    name="${1:-}"
    [ -n "$name" ] || { echo "usage: notes.sh task TASK=<task name>" >&2; exit 2; }
    print_ids "$(jq -c --arg t "$name" '.byTask[$t] // []' <<<"$data")"
    ;;
  search)
    q="${1:-}"
    [ -n "$q" ] || { echo "usage: notes.sh search Q=<text>" >&2; exit 2; }
    list="$(jq -c --arg q "$q" '
      [.notes | to_entries[]
       | select((.key + " " + .value.title + " " + .value.summary + " " + .value.body)
                | ascii_downcase | contains($q | ascii_downcase))
       | .key]
    ' <<<"$data")"
    print_ids "$list"
    ;;
  *)
    echo "notes: unknown mode '$MODE' (list|show|host|module|task|search)" >&2
    exit 2
    ;;
esac
