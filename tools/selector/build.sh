#!/usr/bin/env bash
# build.sh — stage 1 end to end: compiled registries -> dataset -> model -> metrics.
#
# The registries are not re-evaluated here: `q.sh --data` hands over the same
# cache the query surface reads, so a build costs one eval per registry per tree
# and nothing at all on the second run.
#
#   build.sh [OUTDIR] [--verify N]
#
# OUTDIR defaults to ~/.cache/nixconfig/selector. The artifact is machine state,
# never committed ([[flake/policies.nix#generated-not-tracked]]); `checks:selector`
# builds into a temp dir, so the gate cannot pass on a stale artifact.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
Q="$REPO/scripts/task/q.sh"
OUT="${1:-${XDG_CACHE_HOME:-$HOME/.cache}/nixconfig/selector}"
VERIFY=0
shift || true
while [ "$#" -gt 0 ]; do
  case "$1" in
    --verify) VERIFY="${2:-0}"; shift 2 ;;
    *) echo "build: unknown option '$1'" >&2; exit 2 ;;
  esac
done

mkdir -p "$OUT"

for reg in inventory notes tasks graph; do
  payload="$(bash "$Q" --data "$reg")" || {
    echo "build: no payload for $reg" >&2
    exit 1
  }
  cp "$payload" "$OUT/$reg.json"
  # The generator's three inputs all come from the executor: the schema says which
  # fields exist, the payload says which values they hold, and the searchable list
  # says what `touches` actually searches.
  bash "$Q" --schema "$reg" >"$OUT/$reg.schema"
  bash "$Q" --searchable "$reg" >"$OUT/$reg.searchable"
done

verify_args=()
[ "$VERIFY" -gt 0 ] && verify_args=(--verify "$VERIFY")

python3 "$REPO/tools/selector/dataset.py" \
  --data "$OUT" --out "$OUT/dataset.jsonl" --vocab "$OUT/vocab.json" "${verify_args[@]}"

python3 "$REPO/tools/selector/model.py" train \
  --dataset "$OUT/dataset.jsonl" --vocab "$OUT/vocab.json" --out "$OUT/selector-nb.json"

printf 'artifact: %s\n' "$OUT/selector-nb.json"
