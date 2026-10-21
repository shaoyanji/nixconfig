#!/usr/bin/env bash
# shellcheck shell=bash
# Turn a categorize table into a ROUTING PLAN — the apply step lives here, not in
# the categorizer, because the categorizer must stay read-only (policy
# [[flake/policies.nix#automation-is-earned]]). This script writes nothing: it
# checks that a `docs` row is reachable from a living document, and names the
# channel the prose would move to — so the move is a reviewed edit, never a side
# effect.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

CATEGORIZE="$HERE/categorize.sh"
LEDGER="${SUPERVISION_LEDGER:-.agents/supervision.jsonl}"
TMP="$(mktemp "${TMPDIR:-/tmp}/categorize-plan.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

case "${1:-}" in -h|--help) sed -n '2,10p' "$0"; exit 0 ;; esac
[ $# -gt 0 ] || { echo "categorize-apply: give one or more paths" >&2; exit 2; }

bash "$CATEGORIZE" "$@" > "$TMP" || { echo "categorize-apply: no table (the categorizer refused)" >&2; exit 1; }

# channel per category: where prose of that kind belongs, per AGENTS.md.
channel() {
  case "$1" in
    policy) echo "flake/policies.nix (a predicate, with a check that breaks)" ;;
    fact) echo "inventory.toml (compiled registry) — or the host's card if machine-private" ;;
    procedure) echo "docs/*.md + the owning taskfile shard; skills cite, not restate" ;;
    history) echo "docs/history/ (superseded narrative, never linked as current)" ;;
    docs) echo "docs/ (reference), linked from a living document" ;;
    *) echo "UNKNOWN" ;;
  esac
}

bad=0
printf '%-9s %-10s %s\n' "EVIDENCE" "CATEGORY" "PATH → CHANNEL"
while IFS=$'\t' read -r score cat path; do
  # A `docs` row has to be reachable from something a reader starts at, or the
  # plan is routing prose into a page nothing links to ([[flake/policies.nix#
  # no-orphan-docs]]). The evidence check is here, not in the categorizer,
  # because it is about routing rather than classification.
  note=""
  if [ "$cat" = "docs" ]; then
    linked=$(grep -rlF --exclude-dir=.git --exclude-dir=.crush --exclude=supervision.jsonl "$path" . \
      | grep -v "^./${path}$" | head -1 || true)
    if [ -z "$linked" ]; then
      note="  ← ORPHAN (nothing outside the ledger links this page)"
      bad=$((bad + 1))
    else
      note="  (linked from ${linked#./})"
    fi
  fi
  printf '%-9s %-10s %s → %s%s\n' "$score" "$cat" "$path" "$(channel "$cat")" "$note"
done < "$TMP"

agreements=0
judged=0
if [ -r "$LEDGER" ]; then
  judged=$(grep -c '"target"' "$LEDGER" || true)
  agreements=$(grep -c '"agree":true' "$LEDGER" || true)
fi
earned=no
[ "$agreements" -ge 5 ] && [ $((agreements * 2)) -ge "$judged" ] && earned=yes

echo
echo "supervision: $agreements agree / $((judged - agreements)) disagree of $judged — automation $earned"
[ "$bad" -eq 0 ] || { echo "categorize-apply: $bad docs row(s) are orphans — link or move them before routing into docs/" >&2; exit 1; }
