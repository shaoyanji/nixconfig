#!/usr/bin/env bash
# check.sh — the three verbs over the check inventory (taskfiles/checks.toml).
#
#   check.sh list [leaf|host|cache]     the table, with each task's live description
#   check.sh verify                     every row names a task, every task has a row
#   check.sh run <kind> NAME=<task>     dispatch one row; the kind must match
#   check.sh host|leaf NAME=<task> HOST=    the same, with the verb as the kind
#
# The table is the inventory of gates and their kind. It is deliberately NOT a
# second copy of what a check does: the command, description and summary stay in
# the taskfile, and this script reads them from go-task. What the table owns is
# the one fact the taskfiles cannot express — whether a gate is a leaf (no
# input), a host gate (one host) or a cache gate (asks a substituter) — which is
# what makes three verbs enough.
#
# Exit: 0 clean · 1 the table and the tree disagree · 2 usage.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
table="$root/taskfiles/checks.toml"

die() {
  echo "check: $*" >&2
  exit 2
}

[ -f "$table" ] || die "no $table"

# One yq call, rows as `kind<TAB>name`.
rows() {
  yq -p toml -o tsv '.["check"][] | [.kind, .name] | @tsv' "$table"
}

# `<name>\t<desc>` from go-task, which is the only thing that knows a task's desc.
descs() {
  task --list-all --json 2>/dev/null |
    jq -r '.tasks[] | select(.name|startswith("checks:")) | [.name, (.desc // "")] | @tsv'
}

case "${1:-}" in
  list)
    kind="${2:-}"
    [ -z "$kind" ] || case "$kind" in leaf | host | cache) ;; *) die "unknown kind $kind" ;; esac
    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT
    descs >"$work/desc"
    rows | while IFS=$'\t' read -r k n; do
      [ -z "$kind" ] || [ "$k" = "$kind" ] || continue
      d=$(awk -F'\t' -v n="$n" '$1 == n {print $2}' "$work/desc")
      printf '%-6s %-40s %s\n' "$k" "$n" "$d"
    done
    ;;
  verify)
    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT
    rows >"$work/rows"
    descs | cut -f1 | sort >"$work/live"
    cut -f2 "$work/rows" | sort >"$work/tabled"
    fail=0
    while read -r n; do
      [ -n "$n" ] || continue
      echo "row names no task: $n" >&2
      fail=1
    done < <(comm -23 "$work/tabled" "$work/live")
    while read -r n; do
      [ -n "$n" ] || continue
      echo "task has no row (pick leaf|host|cache): $n" >&2
      fail=1
    done < <(comm -13 "$work/tabled" "$work/live")
    while IFS=$'\t' read -r k n; do
      case "$k" in leaf | host | cache) ;; *) echo "bad kind for $n: $k" >&2; fail=1 ;; esac
    done <"$work/rows"
    dups=$(cut -f2 "$work/rows" | sort | uniq -d)
    [ -z "$dups" ] || {
      echo "duplicate rows: $dups" >&2
      fail=1
    }
    [ "$fail" = 0 ] || exit 1
    printf 'check: %s rows, %s live tasks, no drift\n' "$(wc -l <"$work/tabled")" "$(wc -l <"$work/live")"
    ;;
  run | leaf | host | cache)
    if [ "$1" = run ]; then
      kind="${2:-}"
      shift 2
    else
      kind="$1"
      shift
    fi
    case "$kind" in leaf | host | cache) ;; *) die "unknown kind $kind" ;; esac
    name="${NAME:-}"
    host="${HOST:-}"
    if [ "$kind" = host ] && [ -z "$name" ]; then name=checks:host; fi
    if [ "$kind" = cache ] && [ -z "$name" ]; then name=checks:build:route; fi
    [ -n "$name" ] || die "NAME=<task> is required (see: task check:list $kind)"
    # No `exit` in the awk: under `pipefail` an early reader closes the pipe and
    # yq dies with SIGPIPE (141), which made a correct dispatch look like a
    # failure. The table is 93 rows, so scanning it whole costs nothing.
    row=$(rows | awk -F'\t' -v n="$name" '$2 == n {print $1}')
    [ -n "$row" ] || die "$name is not in the check inventory (task check:list)"
    [ "$row" = "$kind" ] || die "$name is a $row check, not $kind"
    if [ "$kind" = host ] || [ "$kind" = cache ]; then
      [ -n "$host" ] || die "HOST=<host> is required for a $kind check"
      exec task "$name" HOST="$host"
    fi
    exec task "$name"
    ;;
  *)
    die "usage: check.sh list [kind] | verify | run <kind> NAME= | leaf|host|cache NAME= [HOST=]"
    ;;
esac
