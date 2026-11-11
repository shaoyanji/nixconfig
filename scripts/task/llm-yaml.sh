#!/usr/bin/env bash
# llm-yaml.sh — turn a model's YAML answer into a document yq can parse, or fail.
#
# A chat model asked for YAML answers with ```yaml fences, a sentence in front and
# a closing remark behind. Regexing that at each call site is how a caller ends up
# with a half-cleaned document and a silent parse failure, so the cleaning lives
# here once and every lane that asks for YAML pipes through it.
#
# Candidates, in order, and the first that yq parses wins:
#   1. the body of the first fenced block — unambiguous, so it wins over any guess
#      about where a sentence ends and a document begins
#   2. the reply with fence lines removed and everything before the first key
#      thrown away — for bare YAML with a sentence in front
#   3. the reply as-is
#
# A one-word line such as "Note: ..." is a legal YAML key and cannot be told from
# prose by regex, which is exactly why the fenced block is tried first. Where
# there is no fence, the caller's shape check is the thing that catches a stray
# key, not this cleaner.
#
#   llm-yaml.sh [--map] < reply.txt > schema.yaml
#
# `--map` requires a mapping at the root. Without it, prose and its reply parse
# equally well — "I cannot do that." is a valid YAML scalar — so a caller that
# asked for a document-shaped answer passes `--map` and gets exit 1 instead of a
# scalar dressed as an answer.
#
# Exit: 0 YAML on stdout · 1 nothing usable parses · 2 yq missing, bad option
set -uo pipefail

ROOT="any"
case "${1:-}" in
  --map) ROOT="map" ;;
  '' | --any) ;;
  *)
    printf 'llm-yaml: unknown option %s (--map)\n' "$1" >&2
    exit 2
    ;;
esac

command -v yq >/dev/null 2>&1 || {
  printf 'llm-yaml: yq required\n' >&2
  exit 2
}

raw=$(cat)
if [ -z "$raw" ]; then
  printf 'llm-yaml: empty reply\n' >&2
  exit 1
fi
raw=$(printf '%s\n' "$raw" | sed -e 's/\x1b\[[0-9;?]*[a-zA-Z]//g' -e 's/\r//g')

# Fence lines go; the content between them stays.
fences_off() { sed -E 's/^[[:space:]]*```[A-Za-z0-9_-]*[[:space:]]*$//'; }
# Body of the first fenced block only.
first_block() { awk '/^[[:space:]]*```/ { if (inb) exit; inb = 1; next } inb'; }
# Everything before the document start is prose, comment or fence residue. A
# key is one token then a colon; "Here is the schema:" has spaces in the token
# and is not YAML, which is the case a naive `first line with a colon` gets wrong.
drop_prose() {
  awk '
    on { print; next }
    /^[[:space:]]*---[[:space:]]*$/ { print "---"; on = 1; next }
    /^[[:space:]]*[A-Za-z_][A-Za-z0-9_.-]*[[:space:]]*:/ { on = 1; print; next }
    /^[[:space:]]*-[[:space:]]/ { on = 1; print; next }
  '
}
trim_edges() {
  awk 'NF { if (!s) s = NR; e = NR } { l[NR] = $0 } END { for (i = s; i <= e; i++) print l[i] }'
}

clean_block() { printf '%s\n' "$1" | fences_off | drop_prose | trim_edges; }

emit_if_parseable() {
  [ -n "$1" ] || return 1
  printf '%s\n' "$1" | yq -e '.' >/dev/null 2>&1 || return 1
  if [ "$ROOT" = "map" ]; then
    printf '%s\n' "$1" | yq -e 'type == "!!map"' >/dev/null 2>&1 || return 1
  fi
  printf '%s\n' "$1"
}

for candidate in \
  "$(printf '%s\n' "$raw" | first_block | drop_prose | trim_edges)" \
  "$(clean_block "$raw")" \
  "$(printf '%s\n' "$raw" | trim_edges)"; do
  if emit_if_parseable "$candidate"; then
    exit 0
  fi
done

printf 'llm-yaml: no candidate in the reply parses as YAML\n' >&2
printf '%s\n' "$raw" | head -6 >&2
exit 1
