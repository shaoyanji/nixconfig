#!/usr/bin/env bash
# notes.sh — query the AGENTS.nix note projection (lib/agents-notes.nix).
#
# AGENTS.nix is the compiled home for the decisions, queue and design studies
# that used to be ARCHITECTURE.md / TODO.md / HANDOFF.md / EXPERIMENTS.md. This
# script is the human surface over `.#agentsNotes.json`; the machine surface is
# `nix eval .#agentsNotes.index` or `nix eval --json .#agentsNotes.json`.
#
# Usage: notes.sh list [STATUS] [KIND] | show ID | near Q [LIMIT]
#        | lineage ID | host HOST | module PATH | task TASK | doc DOC | search Q
# Env: FORMAT=json emits the selected notes as JSON instead of a table.
#
# `near` is the novel-task entry: it ranks notes against an intent so an agent
# that has never seen this repo can ask "has something like this been tried?"
# before writing. `lineage` is design provenance in both directions — where a
# note came from and what came out of it — and it is a LOOKUP, not a walk:
# lib/agents-notes.nix compiles the transitive closure, so a query costs jq.
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

# Status order for RANKING only: live work first, a solved area last. Relevance
# dominates, so this tie-break rarely decides anything — it exists so two equally
# relevant notes do not sort by id.
srank='{"IN FLIGHT":0,"OPEN":1,"ACCEPTED":2,"PROPOSED":3,"BLOCKED":4,"DELIVERED":5,"REJECTED":6,"SUPERSEDED":7}'

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
      | "\(.title)",
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
        (if (.from + .supersedes + .replacedBy + .descendants | length) > 0
         then "",
           (if (.from | length) > 0 then "from:        \(.from | join(", "))" else empty end),
           (if (.supersedes | length) > 0 then "supersedes:  \(.supersedes | join(", "))" else empty end),
           (if (.replacedBy | length) > 0 then "replaced by: \(.replacedBy | join(", "))" else empty end),
           (if (.descendants | length) > 0 then "led to:      \(.descendants | join(", "))" else empty end)
         else empty end),
        (if (.links | length) > 0 then "", "related: \(.links | join(", "))" else empty end),
        (if .body != "" then "", .body else empty end)
    ' <<<"$data"
    ;;
  near)
    q="${1:-}"
    limit="${2:-8}"
    [ -n "$q" ] || { echo "usage: notes.sh near Q=<intent> [LIMIT]" >&2; exit 2; }
    # One scorer, one formatter. The ranking program runs once; the table is a
    # projection of its output, so `FORMAT=json` and the default cannot disagree
    # about what ranks first.
    hits="$(jq -c --arg q "$q" --argjson limit "$limit" --argjson srank "$srank" '
      # Intent queries are sentences. Without a stopword list, "the"/"on"/"are"
      # count as matches and `matched/total` stops meaning anything — a thermal
      # note ranked 5/7 for "builds are too slow on the laptop" purely on noise.
      def stop: {a:1, an:1, and:1, are:1, as:1, at:1, be:1, but:1, by:1, can:1,
                 do:1, does:1, for:1, from:1, how:1, i:1, if:1, in:1, into:1, is:1,
                 it:1, its:1, me:1, my:1, need:1, of:1, on:1, or:1, should:1, so:1,
                 that:1, the:1, then:1, there:1, this:1, to:1, too:1, want:1, we:1,
                 what:1, when:1, why:1, with:1, you:1};
      # Both forms: the compound (`build-routing`, `nix-eval` are real names) and
      # its words. Compound-only tokenising is why a note titled "Build-routing
      # guard" did not match the query word "builds" — a title match scored as
      # nothing, so a body-only false positive outranked it.
      def toks: ascii_downcase
                | [(scan("[a-z0-9][a-z0-9:_./-]*")), (scan("[a-z0-9]+"))]
                | unique
                | map(. as $t | select(stop | has($t) | not));
      def near_tok($q; $t):
        ($q | length) as $ql | ($t | length) as $tl
        | ($t == $q)
          or ($ql >= 4 and $tl >= 4 and (($t | startswith($q)) or ($q | startswith($t))));
      # Fields that identify a note (id, title, summary, refs) are matched as
      # TOKENS; the body is matched as a substring. Two reasons: the body is the
      # weakest signal, so a false positive there costs nothing, and tokenising
      # 157 bodies is the whole cost of this query — `contains` runs in C.
      def strong($id; $n): [
        ($id | toks),
        ($n.title | toks),
        ($n.summary | toks),
        (($n.refs.modules + $n.refs.tasks + $n.refs.docs + $n.refs.hosts) | join(" ") | toks)
      ];
      [2, 3, 2, 3] as $w
      | . as $d
      | ($q | toks) as $qt
      | [ .notes | to_entries[]
          | .key as $id | .value as $n
          | strong($id; $n) as $sets
          | ($n.body | ascii_downcase) as $body
          | ([ $qt[] as $t
               | ([ range(0; 4) as $i
                    | select($sets[$i] | any(.[]; near_tok($t; .)))
                    | $w[$i] ] + (if ($body | contains($t)) then [1] else [] end)) as $hits
               | select(($hits | length) > 0)
               | {t: $t, w: ($hits | max)} ]) as $m
          | select(($m | length) > 0)
          | { id: $id,
              matched: ($m | length),
              total: ($qt | length),
              score: ([$m[].w] | add),
              status: $n.status,
              kind: $n.kind,
              title: $n.title,
              summary: $n.summary,
              from: $d.lineage[$id].from,
              ancestors: $d.lineage[$id].ancestors,
              descendants: $d.lineage[$id].descendants,
              refs: ($n.refs.tasks + $n.refs.modules) }
        ]
      | sort_by([-.matched, -.score, ($srank[.status] // 9)])
      | .[:$limit]
    ' <<<"$data")"
    if [ "${FORMAT:-}" = "json" ]; then
      printf '%s\n' "$hits"
      exit 0
    fi
    if [ "$(jq 'length' <<<"$hits")" -eq 0 ]; then
      echo "no note matches that intent — try fewer words, or 'ops:notes:search' for a phrase"
      exit 0
    fi
    printf '%-28s %-11s %-10s %s\n' "ID" "STATUS" "KIND" "TITLE"
    # The second line is one pre-joined string, not four tab-separated columns:
    # `IFS=$'\t'` treats tab as whitespace, so an empty field collapses and every
    # column after it shifts. One string cannot shift.
    jq -r '
      .[]
      | [ .id, .status, .kind, .title,
          ( [ "match \(.matched)/\(.total)",
              (if (.from | length) > 0 then "from " + (.from | join(",")) else empty end),
              (if (.descendants | length) > 0 then "led to " + (.descendants | join(",")) else empty end),
              (if (.refs | length) > 0 then "refs " + (.refs | join(", ")) else empty end) ]
            | map(select(. != "")) | join("  ·  ") ) ]
      | @tsv
    ' <<<"$hits" | while IFS=$'\t' read -r id status kind title second; do
      printf '%-28s %-11s %-10s %s\n' "$id" "$status" "$kind" "$title"
      printf '    %s\n' "$second"
    done
    ;;
  lineage)
    id="${1:-}"
    [ -n "$id" ] || { echo "usage: notes.sh lineage ID=<note>" >&2; exit 2; }
    if ! jq -e --arg id "$id" '.notes[$id] != null' <<<"$data" >/dev/null; then
      echo "notes: no note '$id' (near matches:)" >&2
      jq -r --arg id "$id" '.notes | keys[] | select(test($id; "i"))' <<<"$data" | head -8 >&2
      exit 1
    fi
    if [ "${FORMAT:-}" = "json" ]; then
      jq --arg id "$id" '.lineage[$id]' <<<"$data"
      exit 0
    fi
    jq -r --arg id "$id" '
      . as $d | .notes[$id] as $n | .lineage[$id] as $l
      | "\($n.title)",
        "\($n.status) · \($n.kind)\(if $n.date then " · \($n.date)" else "" end)",
        "",
        (if ($l.from | length) > 0
         then "from:        " + ([$l.from[] | . + " (" + ($d.notes[.].status) + ")"] | join(", "))
         else empty end),
        (if ($l.supersedes | length) > 0
         then "supersedes:  " + ([$l.supersedes[] | . + " (" + ($d.notes[.].status) + ")"] | join(", "))
         else empty end),
        (if ($l.replacedBy | length) > 0
         then "replaced by: " + ([$l.replacedBy[] | . + " (" + ($d.notes[.].status) + ")"] | join(", "))
         else empty end),
        (if ($l.ancestors | length) > 0 then "ancestry:    \($l.ancestors | join(" <- "))" else empty end),
        # A superseding note is a descendant too, but it already printed on the
        # `replaced by` line; the pair would read as two successors.
        (($l.descendants - $l.replacedBy) | if length > 0
         then "led to:      " + ([.[] | . + " (" + ($d.notes[.].status) + ")"] | join(", "))
         else "led to:      nothing yet — a frontier note: attach a new idea with `from`" end),
        "",
        "summary: \($n.summary)"
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
  doc)
    path="${1:-}"
    [ -n "$path" ] || { echo "usage: notes.sh doc DOC=<repo-relative path>" >&2; exit 2; }
    print_ids "$(jq -c --arg p "$path" '.byDoc[$p] // []' <<<"$data")"
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
    echo "notes: unknown mode '$MODE' (list|show|near|lineage|host|module|task|doc|search)" >&2
    exit 2
    ;;
esac
