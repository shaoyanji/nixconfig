#!/usr/bin/env bash
# issue-ledger.sh — the running record of classified issues.
#
# `docs/issue-classes.md` is the vocabulary (trust · lint · assert · capacity)
# and `checks.policies` proves each class names a policy that holds it. This
# script is the other half: it records real issues in that vocabulary, so a class
# can be counted instead of remembered, and `xs-turn-post.sh` appends the turn's
# own line, so the ledger and the coordination log carry the same subject.
#
# One JSONL line per issue, append-only:
#   ~/.local/state/nixconfig/issue-ledger.jsonl
# Not committed: it is per-machine state like the xs queue, and the part worth
# keeping already goes to the turn log.
#
# Tasks: agents:ledger:record · agents:ledger:list · agents:ledger:check
# Exit: 0 ok, or nothing recorded yet · 1 an entry is not a classified issue ·
#       2 bad input (undeclared class, missing evidence or fix)
set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
DOC=${ISSUE_CLASSES_DOC:-$ROOT/docs/issue-classes.md}
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/nixconfig
LEDGER=${ISSUE_LEDGER:-$STATE_DIR/issue-ledger.jsonl}

fail() {
  local code=$1
  shift
  printf 'issue-ledger: %s\n' "$*" >&2
  case $code in
  2) exit 2 ;;
  *) exit 1 ;;
  esac
}

# The table's first column is the vocabulary. Reading it from the page is what
# keeps one home for the class names instead of a second list in this script.
classes() {
  grep -oE '^\| `[a-z]+` \|' "$DOC" | sed 's/[|` ]//g'
}

cap() { # cap <field> <value> <limit>
  [ "${#2}" -le "$3" ] || fail 2 "$1 is ${#2} characters; keep it to $3"
}

record() {
  local class=${CLASS:-}
  local declared
  declared=$(classes) || fail 1 "could not read the class table from $DOC"
  [ -n "$declared" ] || fail 1 "no classes parsed from $DOC"
  [ -n "$class" ] || fail 2 'CLASS is required: one of trust, lint, assert, capacity'
  grep -qx "$class" <<<"$declared" ||
    fail 2 "CLASS=$class is not declared in $DOC (declared: $(paste -sd' ' - <<<"$declared"))"

  local evidence=${EVIDENCE:-} fix=${FIX:-}
  [ -n "$evidence" ] || fail 2 'EVIDENCE is required: what proved the class'
  [ -n "$fix" ] || fail 2 'FIX is required: what made it stop'
  cap EVIDENCE "$evidence" 500
  cap FIX "$fix" 500
  cap SUBJECT "${SUBJECT:-}" 200

  local ts id source outcome
  ts=${TS:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}
  id=${ID:-$(cat /proc/sys/kernel/random/uuid)}
  source=${SOURCE:-$(whoami)}
  outcome=${OUTCOME:-done}
  cap SOURCE "$source" 64
  cap OUTCOME "$outcome" 300

  mkdir -p "$STATE_DIR"
  jq -n -c \
    --arg ts "$ts" \
    --arg id "$id" \
    --arg class "$class" \
    --arg source "$source" \
    --arg subject "${SUBJECT:-}" \
    --arg outcome "$outcome" \
    --arg evidence "$evidence" \
    --arg fix "$fix" \
    --arg commit "${COMMIT:-}" \
    '{ts: $ts, id: $id, class: $class, source: $source, subject: $subject,
      outcome: $outcome, evidence: $evidence, fix: $fix, commit: $commit}' \
    >>"$LEDGER"

  printf 'recorded  %s  %s  %s\n' "$class" "$ts" "${SUBJECT:-}"
}

list() {
  local filter=${CLASS:-} limit=${LIMIT:-20}
  [[ $limit =~ ^[0-9]+$ ]] || fail 2 "LIMIT must be a number: $limit"
  if [ ! -s "$LEDGER" ]; then
    printf 'ledger  %s\nissues  0\n' "$LEDGER"
    return 0
  fi
  printf 'ledger  %s\n' "$LEDGER"
  jq -r --arg c "$filter" '
    select($c == "" or .class == $c)
    | [.ts, .class, .source, .subject, .outcome, .fix] | @tsv
  ' "$LEDGER" | tail -n "$limit"
  jq -r '.class' "$LEDGER" | sort | uniq -c | sed 's/^ */class /'
}

check() {
  local declared
  declared=$(classes) || fail 1 "could not read the class table from $DOC"
  [ -n "$declared" ] || fail 1 "no classes parsed from $DOC"
  if [ ! -s "$LEDGER" ]; then
    printf 'ledger  %s\nissues  0  (nothing classified yet)\n' "$LEDGER"
    return 0
  fi

  local n=0 bad=0 line class
  while IFS= read -r line; do
    n=$((n + 1))
    if ! jq -e . >/dev/null 2>&1 <<<"$line"; then
      printf 'bad-line %s: not JSON\n' "$n" >&2
      bad=$((bad + 1))
      continue
    fi
    class=$(jq -r '.class // ""' <<<"$line")
    if ! grep -qx "$class" <<<"$declared"; then
      printf 'bad-line %s: class "%s" is not declared in %s\n' "$n" "$class" "$DOC" >&2
      bad=$((bad + 1))
      continue
    fi
    # An entry with no evidence or no fix records a symptom, not a class.
    if [ -z "$(jq -r '.evidence // ""' <<<"$line")" ] ||
      [ -z "$(jq -r '.fix // ""' <<<"$line")" ]; then
      printf 'bad-line %s: evidence or fix is empty\n' "$n" >&2
      bad=$((bad + 1))
    fi
  done <"$LEDGER"

  printf 'ledger  %s\nissues  %s\nbad     %s\n' "$LEDGER" "$n" "$bad"
  jq -r '.class' "$LEDGER" | sort | uniq -c | sed 's/^ */class /'
  [ "$bad" = 0 ] || exit 1
}

command=${1:-}
case $command in
record) record ;;
list) list ;;
check) check ;;
-h | --help | help)
  sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'
  ;;
*)
  printf 'issue-ledger: unknown command %s (record, list, check)\n' "${command:-<none>}" >&2
  exit 2
  ;;
esac
