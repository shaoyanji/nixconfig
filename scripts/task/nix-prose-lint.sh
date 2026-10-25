#!/usr/bin/env bash
# Nix commentary gate: a comment may state a constraint or point at the one home
# of a fact — never carry the explanation itself.
#
# Why: a comment is the one thing nothing compiles. `.#knowledgeGraph`, qmd and
# the skills index are built from `docs/*.md`, `.agents/skills/*` and the compiled
# registry, so a fact written there is answerable (`task ops:kg:*`, `qmd search`)
# while the same fact written inside a `.nix` file is only findable by reading the
# module — which is what the agent should not have to do. Restating a fact that
# Nix already states is worse: two homes for one fact is a contradiction waiting
# to happen.
#
# Scope is the DIFF, not the corpus. Judging added lines only lets the rule start
# today instead of requiring 30-odd existing blocks to be rewritten first; the
# `--all` mode reports the backlog without failing anything.
#
# Usage:
#   nix-prose-lint.sh                 # staged .nix changes (pre-commit)
#   nix-prose-lint.sh --range A..B    # a commit range
#   nix-prose-lint.sh --all           # whole tracked corpus, advisory report
#   MIN=12 nix-prose-lint.sh          # raise the run length before it counts
#
# Exit: 0 clean (or advisory), 1 violations, 2 cannot run (not a git repo).
set -uo pipefail

MIN="${MIN:-8}"
MODE="staged"
RANGE=""
ADVISORY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --staged) MODE="staged" ;;
    --all) MODE="all" ;;
    --range)
      MODE="range"
      RANGE="${2:?--range needs A..B}"
      shift
      ;;
    --advisory) ADVISORY=1 ;;
    -h | --help)
      sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "nix-prose-lint: unknown argument $1" >&2
      exit 2
      ;;
  esac
  shift
done

git rev-parse --show-toplevel >/dev/null 2>&1 || {
  echo "nix-prose-lint: not inside a git repository" >&2
  exit 2
}
cd "$(git rev-parse --show-toplevel)" || exit 2

# A pointer is any of: a docs/ or .agents/ path, a policies.nix citation, a
# `task <name>` invocation, a `.#` flake attribute, a repo path, or AGENTS.md.
# Character classes instead of backslash escapes: awk warns about the latter and
# the program is fed through a heredoc, where an extra quoting layer is a bug.
POINTER='docs/|[.]agents/|flake/policies[.]nix#|task [a-z][a-z:-]*|[.]#|AGENTS[.]md|hosts/[a-z]|modules/|lib/|flake/|taskfiles/|scripts/'

DIFF_AWK=$(mktemp)
CORPUS_AWK=$(mktemp)
trap 'rm -f "$DIFF_AWK" "$CORPUS_AWK"' EXIT

cat >"$DIFF_AWK" <<'AWK'
/^\+\+\+ / { file = $2; sub(/^b\//, "", file); n = 0; ok = 0; lineno = 0; next }
/^@@ / {
  # @@ -a,b +c,d @@ — the added lines start at c.
  if (match($0, /\+[0-9]+/)) lineno = substr($0, RSTART + 1, RLENGTH - 1) + 0
  n = 0
  ok = 0
  next
}
/^\+/ {
  line = substr($0, 2)
  if (line ~ /^[[:space:]]*#/) {
    if (n == 0) start = lineno
    n++
    if (line ~ ptr) ok = 1
  } else {
    if (n >= min && !ok) printf "%s:%d  %d added comment lines, no home cited\n", file, start, n
    n = 0
    ok = 0
  }
  lineno++
  next
}
END {
  if (n >= min && !ok) printf "%s:%d  %d added comment lines, no home cited\n", file, start, n
}
AWK

cat >"$CORPUS_AWK" <<'AWK'
function flush() {
  if (n >= min && !ok) printf "%s:%d  %d comment lines, no home cited\n", name, start, n
  n = 0
  ok = 0
}
/^[[:space:]]*#/ {
  if (n == 0) start = FNR
  n++
  if ($0 ~ ptr) ok = 1
  next
}
{ flush() }
END { flush() }
AWK

scan() {
  awk -v min="$MIN" -v ptr="$POINTER" -f "$1"
}

case "$MODE" in
  all)
    VIOLATIONS=$(
      git ls-files '*.nix' | while IFS= read -r f; do
        awk -v min="$MIN" -v ptr="$POINTER" -v name="$f" -f "$CORPUS_AWK" "$f"
      done
    )
    ;;
  range) VIOLATIONS=$(git diff -U0 "$RANGE" -- '*.nix' | scan "$DIFF_AWK") ;;
  *) VIOLATIONS=$(git diff --cached -U0 -- '*.nix' | scan "$DIFF_AWK") ;;
esac

if [ -z "${VIOLATIONS//[$'\n\t ']/}" ]; then
  echo "nix commentary OK: no run of $MIN+ comment lines without a cited home"
  exit 0
fi

COUNT=$(printf '%s\n' "$VIOLATIONS" | grep -c . || true)
echo "$VIOLATIONS" | sed 's/^/  /'
echo
echo "nix commentary: $COUNT block(s) of $MIN+ comment lines explain a fact with no home."
echo "  A comment is compiled by nothing; the graph, qmd and the skills index are."
echo "  Keep the constraint in the .nix and move the narrative to:"
echo "    docs/<topic>.md           prose, answerable via qmd search -c nixconfig"
echo "    .agents/skills/<name>/    a procedure an agent must follow"
echo "    flake/policies.nix        a rule, as an enforced predicate"
echo "  Then leave one line here pointing at it — see"
echo "  [[flake/policies.nix#nix-header-budget]]."

if [ "$ADVISORY" -eq 1 ] || [ "$MODE" = "all" ]; then
  exit 0
fi
exit 1
