#!/usr/bin/env bash
# Repair TOON array lengths.
#
# The `[n]` in `items[12]{id,name}:` is a row count, not a label. An agent that
# writes TOON by hand counts the rows itself and gets it wrong; strict decode
# then refuses the whole document ("Expected 12 tabular rows, but found 14").
#
# This recomputes every length from the rows that are actually present: decode
# loosely (--no-strict ignores the declared length), then re-encode, which
# counts what it sees. Nothing else about the document is interpreted.
#
# It refuses two inputs instead of "repairing" them:
#   * a document starting with `{` — that is JSON; a TOON root object is `key:`
#     lines, and decoding JSON as TOON mangles it ({"a":1} becomes a 1-key map);
#   * anything whose loose decode is a bare scalar — `this is not toon` is a
#     valid TOON string, so it would otherwise round-trip and report success.
#
# Usage: toon-fix.sh [file.toon ...]     no arguments = stdin
# Exit:  0 = repaired or already correct; 1 = not a TOON document
set -euo pipefail

command -v toon >/dev/null 2>&1 || {
  echo "toon: not found on PATH (pkgs.llm-agents.toon)" >&2
  exit 1
}

# Count the `name[n]` headers so the repair can be reported, not just applied.
header_lengths() {
  grep -oE '^[[:space:]]*[A-Za-z0-9_.-]+\[[0-9]+\]' "$1" 2>/dev/null | sed 's/^[[:space:]]*//' || true
}

fix_file() {
  local file="$1" tmp raw err first
  tmp="$(mktemp)"
  raw="$(mktemp)"
  err="$(mktemp)"

  first="$(grep -m1 -v '^[[:space:]]*$' "$file" | cut -c1 || true)"
  if [ "$first" = "{" ]; then
    echo "FAIL $file: starts with '{', which is JSON; pipe it through 'toon -e'" >&2
    rm -f "$tmp" "$raw" "$err"
    return 1
  fi

  if ! toon -d --no-strict <"$file" >"$raw" 2>"$err"; then
    echo "FAIL $file: not a TOON document" >&2
    sed -n '1,3p' "$err" >&2
    rm -f "$tmp" "$raw" "$err"
    return 1
  fi

  if ! jq -e 'type == "object" or type == "array"' "$raw" >/dev/null 2>&1; then
    echo "FAIL $file: decodes to a bare value, not a TOON document" >&2
    rm -f "$tmp" "$raw" "$err"
    return 1
  fi

  toon -e <"$raw" >"$tmp"

  if cmp -s "$file" "$tmp"; then
    rm -f "$tmp" "$raw" "$err"
    return 0
  fi

  diff <(header_lengths "$file") <(header_lengths "$tmp") |
    grep -E '^[<>]' |
    sed 's/^< /  declared: /; s/^> /  counted:  /' || true

  # Write through the inode so a symlinked doc stays linked.
  cat "$tmp" >"$file"
  rm -f "$tmp" "$raw" "$err"
  echo "fixed $file"
  return 0
}

status=0
if [ "$#" -eq 0 ]; then
  stdin_doc="$(mktemp)"
  cat >"$stdin_doc"
  if fix_file "$stdin_doc" >/dev/null; then
    cat "$stdin_doc"
  else
    status=1
  fi
  rm -f "$stdin_doc"
else
  for file in "$@"; do
    fix_file "$file" || status=1
  done
fi

exit "$status"
