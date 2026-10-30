#!/usr/bin/env bash
# Export the agent-turn xs store as frames.jsonl plus cas/, the dump shape
# `xs import` reads.
#
# This is the backup hook, not a schedule: the cadence and the target host are
# Joiu's call (see the AGENTS.nix note), so this script only has to be callable.
#
# Restore into a fresh store (the same order the export wrote it):
#   for f in "$DUMP"/cas/*; do
#     xs cas-post "$STORE" < "$f"
#   done
#   while IFS= read -r line; do
#     printf '%s' "$line" | xs import "$STORE"
#   done < "$DUMP/frames.jsonl"
#
# Two xs traps, both measured against 0.14.2:
#   - `xs cat` fails with "Operation not permitted" when stdout is a regular
#     file; it has to be a pipe, hence `| cat`.
#   - `xs import` reads one frame per invocation, so the restore loop is per
#     line, not a single redirect.
set -euo pipefail

OUT="${1:-}"
if [ -z "$OUT" ]; then
  echo "usage: xs-agent-turns-export.sh <output-dir>" >&2
  exit 2
fi

STORE="${XS_STORE:-/var/lib/xs-agent-turns/store}"
XS="${XS:-xs}"

if [ -e "$OUT" ]; then
  echo "refusing to write into existing path: $OUT" >&2
  exit 1
fi

command -v "$XS" >/dev/null 2>&1 || {
  echo "xs not on PATH (set XS=/nix/store/.../bin/xs)" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo "jq not on PATH" >&2
  exit 1
}

mkdir -p "$OUT/cas"

# Every frame, verbatim, including xs.start markers: `xs import` restores ids.
"$XS" cat "$STORE" | cat > "$OUT/frames.jsonl"

# One file per distinct content hash, named base64url(hash). Upstream's xs.nu
# .export uses plain base64, whose '/' would be a path separator in a filename;
# frames.jsonl is byte-compatible either way, only the file names differ.
jq -r 'select(.hash != null) | .hash' "$OUT/frames.jsonl" |
  sort -u |
  while IFS= read -r hash; do
    name=$(printf '%s' "$hash" | base64 -w0 | tr '/+' '_-')
    "$XS" cas "$STORE" "$hash" | cat > "$OUT/cas/$name"
  done

printf 'exported %s frames, %s content objects to %s\n' \
  "$(wc -l < "$OUT/frames.jsonl")" \
  "$(find "$OUT/cas" -type f | wc -l)" \
  "$OUT"
