#!/usr/bin/env bash
# prose-tells.sh — the unslop vocabulary, as a gate (`.agents/skills/unslop`).
#
# One implementation behind every surface that asks the question:
#   task checks:prose                     (human/agent, and inside checks:quick)
#   checks.<system>.prose-tells           (nix flake check, and the CI job that
#                                         runs on every push, doc-only included)
#
# Only the rules a regex can judge without guessing: the vocabulary list (7), the
# fancy ways to say "is" (8), curly quotes (19), chatbot phrases (20), filler
# (23), the abstract metaphor nouns (26) and the plain-word list (31). Rules 3,
# 5, 9, 10, 11, 12, 14-18, 27-30, 32 and 33 need a reader, and a gate that
# guesses at them produces the false positive that gets the gate switched off.
#
# A line may carry `prose-tell-ok: <reason>` when the word is the concrete one:
# a quoted vocabulary list, a product name, a command that scaffolds a file.
#
# Exit: 0 clean, 1 on any tell.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if root="$(git -C "$here" rev-parse --show-toplevel 2>/dev/null)"; then
  cd "$root"
else
  cd "$here/../.."
fi

# rule<TAB>pattern. The hint that goes with each rule lives in the unslop skill;
# repeating it here would be a second copy that drifts.
tells="$(
  cat <<'EOF'
7	\bcrucial\b
7	\bdelv(e|es|ed|ing)\b
7	\benduring\b
7	\benhanc(e|es|ed|ing|ement)\b
7	\bfoster(s|ed|ing)?\b
7	\bgarner(s|ed|ing)?\b
7	\binterplay\b
7	\bintricate\b
7	\blandscape\b
7	\bpivotal\b
7	\bshowcase(s|d|ing)?\b
7	\btapestry\b
7	\btestament\b
7	\bunderscore(s|d|ing)?\b
7	\bvibrant\b
7	\badditionally,
8	\bserves as\b
8	\bstands as\b
8	\bboasts\b
19	“|”|‘|’
20	\bi hope this helps\b
20	\blet me know if\b
20	\bgreat question\b
20	\byou'?re absolutely right\b
23	\bin order to\b
23	\bdue to the fact that\b
23	\bit is important to note\b
23	\bit'?s worth noting\b
23	\bat the end of the day\b
26	\bsubstrate\b
26	\bparadigm(s)?\b
26	\bnorth star\b
26	\bflywheel(s)?\b
26	\bbedrock\b
26	\bscaffolding\b
26	\bmodalit(y|ies)\b
26	\blocus\b
26	\bnexus\b
26	\brealm\b
31	\butiliz(e|es|ed|ing)\b
31	\bleverag(e|es|ed|ing)\b
31	\bfacilitat(e|es|ed|ing)\b
31	\bnumerous\b
31	\bmyriad\b
31	\bplethora\b
EOF
)"

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
while IFS=$'\t' read -r rule pattern; do
  [ -n "$rule" ] || continue
  hits="$(grep -iE -- "$pattern" "$stream" || true)"
  [ -n "$hits" ] || continue
  while IFS= read -r hit; do
    where="${hit%%$'\t'*}"
    text="${hit#*$'\t'}"
    # One line per distinct word: a sentence can carry four tells, and naming
    # them is what makes the report actionable.
    while IFS= read -r word; do
      [ -n "$word" ] || continue
      total=$((total + 1))
      printf 'TELL  rule=%s  %s  "%s"\n      %s\n' "$rule" "$where" "$word" "$text"
    done <<<"$(grep -oiE -- "$pattern" <<<"$text" | sort -u)"
  done <<<"$hits"
done <<<"$tells"

if [ "$total" -eq 0 ]; then
  printf 'ok    %s prose files: no unslop vocabulary (rules 7/8/19/20/23/26/31)\n' "$(printf '%s\n' $files | wc -l | tr -d ' ')"
  exit 0
fi

printf '\n%s tell(s). Rewrite the line, or carry `prose-tell-ok: <reason>` on it\nwhen the word is the concrete one. Procedure: .agents/skills/unslop/SKILL.md\n' "$total"
exit 1
