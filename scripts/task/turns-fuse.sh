#!/usr/bin/env bash
# turns-fuse.sh — the postgres projection of what the tree already holds.
#
# Three stores answer three different questions, and the fusion is a projection
# rather than a fourth store: the turn snapshot and the compiled note index load
# into SQL keyed by repo path, so postgres can join what the ledger, the app
# databases and AGENTS.nix each answer best. Nothing writes back upstream.
#
# Every statement is `insert … on conflict do nothing`, so a re-run is a no-op and
# a frame that already landed cannot be rewritten: append-only in the store, and
# append-only in the copy.
#
# Usage
#   turns-fuse.sh --sql      DDL and inserts, for `psql -f`
#   turns-fuse.sh --check    what a load would carry, as counts
#
# Env
#   TURNS=   snapshot path (default lib/agent-turns/turns.json)
#   NOTES=   a file holding `nix eval --json .#agentsNotes.index`; absent leaves
#            the note table out, which keeps a partial load honest
#
# Task: agents:turns:fuse
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
TURNS=${TURNS:-$ROOT/lib/agent-turns/turns.json}
NOTES=${NOTES:-}

[ -f "$TURNS" ] || { printf 'turns-fuse: no snapshot at %s\n' "$TURNS" >&2; exit 2; }

SQL='def sql: if . == null or . == "" then "\u0027\u0027"
       else "\u0027" + (tostring | gsub("\u0027"; "\u0027\u0027")) + "\u0027" end;
  .turns[] as $t
  | ("insert into turn (id, ts, source, subject, action, outcome, base_commit, branch) values ("
     + ([$t.id, $t.ts, $t.source, $t.subject, $t.action, $t.outcome, $t.base_commit, $t.branch]
        | map(sql) | join(", ")) + ") on conflict (id) do nothing;"),
    ($t.claims[]? | "insert into turn_claim (turn_id, area) values (\($t.id | sql), \(sql)) on conflict do nothing;"),
    ($t.files[]? | "insert into turn_file (turn_id, path) values (\($t.id | sql), \(sql)) on conflict do nothing;")'

NOTE_SQL='def sql: if . == null or . == "" then "\u0027\u0027"
       else "\u0027" + (tostring | gsub("\u0027"; "\u0027\u0027")) + "\u0027" end;
  to_entries[]
  | "insert into note (id, kind, status, claim, title, date) values (\(.key | sql), "
    + ([.value.kind, .value.status, .value.claim, .value.title, .value.date] | map(sql) | join(", "))
    + ") on conflict (id) do nothing;"'

case ${1:---check} in
--sql)
  cat <<'DDL'
create table if not exists turn (
  id text primary key,
  ts timestamptz not null,
  source text not null,
  subject text,
  action text,
  outcome text,
  base_commit text,
  branch text
);
create table if not exists turn_claim (
  turn_id text not null references turn(id),
  area text not null,
  primary key (turn_id, area)
);
create table if not exists turn_file (
  turn_id text not null references turn(id),
  path text not null,
  primary key (turn_id, path)
);
create table if not exists note (
  id text primary key,
  kind text,
  status text,
  claim text,
  title text,
  date date
);
create index if not exists turn_claim_area on turn_claim (area);
DDL
  jq -r "$SQL" "$TURNS"
  if [ -n "$NOTES" ] && [ -f "$NOTES" ]; then jq -r "$NOTE_SQL" "$NOTES"; fi
  ;;
--check)
  jq -r '
    "turns      \(.turns | length)",
    "claims     \([.turns[].claims[]?] | length)",
    "files      \([.turns[].files[]?] | length)",
    "generated  \(.generated // "unknown")",
    "pin        \(.pin[0:12])"' "$TURNS"
  if [ -n "$NOTES" ] && [ -f "$NOTES" ]; then
    jq -r '"notes      \(length)"' "$NOTES"
  else
    printf 'notes      not loaded (NOTES= absent)\n'
  fi
  ;;
*)
  printf 'usage: turns-fuse.sh --sql|--check\n' >&2
  exit 2
  ;;
esac
