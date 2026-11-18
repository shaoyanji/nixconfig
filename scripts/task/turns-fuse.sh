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
#   turns-fuse.sh --queries  the read-only joins an agent asks the projection
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
  def sqlarr: if . == null or length == 0 then "\u0027{}\u0027::text[]"
       else "array[" + (map(sql) | join(", ")) + "]" end;
  to_entries[]
  | "insert into note (id, kind, status, claim, title, date, modules) values (\(.key | sql), "
    + ([.value.kind, .value.status, .value.claim, .value.title, .value.date] | map(sql) | join(", "))
    + ", " + (.value.refs.modules | sqlarr)
    + ") on conflict (id) do update set modules = excluded.modules;"'

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
alter table note add column if not exists modules text[];
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
--queries)
  cat <<'SQL'
\echo '== subjects: turns, claims, files, last seen =='
select coalesce(t.subject, '(none)') as subject,
       count(distinct t.id) as turns,
       count(distinct c.area) as claims,
       count(distinct f.path) as files,
       max(t.ts)::date as last
from turn t
left join turn_claim c on c.turn_id = t.id
left join turn_file  f on f.turn_id = t.id
group by 1 order by turns desc, last desc;

\echo '== files: turns that touched each, and their subjects =='
select f.path, count(distinct f.turn_id) as turns,
       (array_agg(distinct t.subject))[1:3] as subjects
from turn_file f join turn t on t.id = f.turn_id
group by 1 order by turns desc, path;

\echo '== claims: areas by turns and outcome =='
select c.area, count(distinct c.turn_id) as turns,
       string_agg(distinct t.outcome, ', ') as outcomes
from turn_claim c join turn t on t.id = c.turn_id
group by 1 order by turns desc, area;

\echo '== the documented join: a note path against what turns touched =='
select n.kind, n.status, count(distinct n.id) as notes,
       count(distinct f.turn_id) as turns
from note n
left join turn_file f on f.path = any(n.modules)
group by 1, 2 order by notes desc;
SQL
  ;;
*)
  printf 'usage: turns-fuse.sh --sql|--check|--queries\n' >&2
  exit 2
  ;;
esac
