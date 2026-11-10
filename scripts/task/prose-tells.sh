#!/usr/bin/env bash
# prose-tells.sh — the unslop vocabulary, as a gate (`.agents/skills/unslop`).
#
# The words are NOT in this file. modules/config/prose-tells.tsv is the one copy;
# this script and the skill both read it, so the gate and the procedure cannot
# disagree about which words are tells. A row is
# `rule<TAB>word<TAB>pattern<TAB>mode`, where mode is `gate` (a regex can judge
# it) or `reader` (it is listed for a human, because the word has a concrete
# sense here and a regex would produce the false positive that gets a gate
# switched off).
#
# One implementation behind every surface that asks the question:
#   task checks:prose                     (human/agent, and inside checks:quick)
#   task checks:prose VOCAB=1             print the list, grouped by rule
#   checks.<system>.prose-tells           (nix flake check, and the CI job that
#                                         runs on every push, doc-only included)
#
# A line may carry `prose-tell-ok: <reason>` when the word is the concrete one:
# a quoted vocabulary list, a product name, a command that scaffolds a file.
#
# Exit: 0 clean, 1 on any tell, 2 the list is missing or malformed.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if root="$(git -C "$here" rev-parse --show-toplevel 2>/dev/null)"; then
  cd "$root"
else
  cd "$here/../.."
fi

data="${PROSE_TELLS:-modules/config/prose-tells.tsv}"
if [ ! -r "$data" ]; then
  echo "prose-tells: cannot read $data (the vocabulary list)" >&2
  echo "  It is the source the gate and .agents/skills/unslop/SKILL.md share." >&2
  exit 2
fi

# A malformed row is silent otherwise: a `gate` row with an empty pattern matches
# every line, and a row with three fields drops the mode. Refuse both.
if ! awk -F'\t' '
  /^#/ { next }
  /^[[:space:]]*$/ { next }
  NF != 4 {
    printf "prose-tells: %s:%d: expected 4 tab-separated fields, got %d\n", FILENAME, FNR, NF
    bad = 1
    next
  }
  $1 !~ /^[0-9]+$/ {
    printf "prose-tells: %s:%d: rule \"%s\" is not a number\n", FILENAME, FNR, $1
    bad = 1
    next
  }
  $4 != "gate" && $4 != "reader" {
    printf "prose-tells: %s:%d: mode \"%s\" is not gate|reader\n", FILENAME, FNR, $4
    bad = 1
    next
  }
  $4 == "gate" && ($3 == "" || $3 == "-") {
    printf "prose-tells: %s:%d: a gate row needs a pattern\n", FILENAME, FNR
    bad = 1
    next
  }
  {
    rows++
  }
  END {
    if (rows == 0) {
      print "prose-tells: the vocabulary list has no rows"
      bad = 1
    }
    exit (bad ? 1 : 0)
  }
' "$data"; then
  exit 2
fi

if [ "${VOCAB:-}" = "1" ]; then
  awk -F'\t' '
    /^#/ || /^[[:space:]]*$/ { next }
    { printf "%-3s %-24s %s\n", $1, $2, $4 }
  ' "$data" | sort -n -k1,1
  exit 0
fi

# The archive keeps its voice, the unslop skill lists these words on purpose, and
# the persona files are written in a character's voice (rules 13 and 32 exempt
# them).
skip='docs/history/|\.agents/skills/unslop/SKILL\.md$|(^|/)SOUL\.md$'

# `projects/` is submodules: `git ls-files` does not list their files, but the
# store copy checked out by the flake check does, so the fallback excludes them
# or the same commit would scan two different sets. A submodule obeys its own
# prose rules.
if git rev-parse --git-dir >/dev/null 2>&1; then
  files="$(git ls-files '*.md' | grep -Ev "$skip" || true)"
else
  files="$(find . -name '*.md' -not -path './.git/*' -not -path './projects/*' | sed 's|^\./||' | grep -Ev "$skip" || true)"
fi

# One pass over the prose with fenced blocks removed: a word inside an example is
# the example's, and the line number must stay the file's, so the fence state is
# tracked per file and NR is printed.
stream="$(mktemp)"
trap 'rm -f "$stream"' EXIT
# shellcheck disable=SC2086 # the file list is newline-split on purpose
awk '
  FNR == 1 { fence = 0 }
  /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
  !fence && !/prose-tell-ok:/ { print FILENAME ":" FNR "\t" $0 }
' $files >"$stream"

total=0
while IFS=$'\t' read -r rule word pattern; do
  [ -n "$rule" ] || continue
  hits="$(grep -iE -- "$pattern" "$stream" || true)"
  [ -n "$hits" ] || continue
  while IFS= read -r hit; do
    where="${hit%%$'\t'*}"
    text="${hit#*$'\t'}"
    total=$((total + 1))
    printf 'TELL  rule=%s  %s  "%s"\n      %s\n' "$rule" "$where" "$word" "$text"
  done <<<"$hits"
done <<<"$(awk -F'\t' '!/^#/ && NF == 4 && $4 == "gate" {print $1 "\t" $2 "\t" $3}' "$data")"

if [ "$total" -eq 0 ]; then
  printf 'ok    %s prose files: no unslop vocabulary (the gate rows of %s)\n' \
    "$(printf '%s\n' $files | wc -l | tr -d ' ')" "$data"
  exit 0
fi

printf '\n%s tell(s). Rewrite the line, or carry `prose-tell-ok: <reason>` on it\nwhen the word is the concrete one.\nThe list is %s; print it with `task checks:prose VOCAB=1`.\n' "$total" "$data"
exit 1
