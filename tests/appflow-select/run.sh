#!/usr/bin/env bash
# Regression fixture for `modules/plugins/appflow/select.py`.
#
# The selector is the one place a CV is narrowed, so its contract is asserted
# rather than eyeballed on a real application: no role disappears, no line is
# invented, the cap holds, the role's own order survives, a role with nothing to
# say falls back visibly, a German description still reaches an English corpus,
# and the same input produces the same bytes. The corpus and the descriptions are
# fictional and committed, so this runs with no $HOME, no database and no nix —
# under a second, which is why it can be a check.
#
# Coverage is asserted in both directions: a case listed in EXPECTED that no
# longer runs fails, and so does a case that runs without being listed. Deleting
# an assertion therefore cannot pass as a smaller suite.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
selector="$repo/modules/plugins/appflow/select.py"
corpus="$here/fixtures/resume.json"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

command -v python3 >/dev/null 2>&1 || {
  echo "fixture: python3 is required" >&2
  exit 2
}
command -v jq >/dev/null 2>&1 || {
  echo "fixture: jq is required" >&2
  exit 2
}
[ -f "$selector" ] || {
  echo "fixture: $selector is missing" >&2
  exit 2
}
[ -f "$corpus" ] || {
  echo "fixture: $corpus is missing" >&2
  exit 2
}

EXPECTED=(
  "no description is a passthrough"
  "a projection says it is one"
  "highlights are capped"
  "a matching role keeps matching lines"
  "a role with no overlap keeps its lead line"
  "kept lines come from the corpus"
  "kept lines keep the role's order"
  "projects are capped and relevant"
  "an unrelated description still yields a CV"
  "skill groups survive with fewer keywords"
  "structure is not material"
  "a German description reaches the English corpus"
  "an inflection still names the same term"
  "the same input produces the same bytes"
  "an unreadable corpus is refused"
)

fail=0
ran=()

pass() {
  ran+=("$1")
  echo "ok   $1"
}
bad() {
  ran+=("$1")
  fail=1
  echo "FAIL $1: $2"
}

# Every run writes into the fixture's own directory, so a leftover file from one
# case cannot be read as the result of the next.
run() { # out args...
  local out="$1"
  shift
  python3 "$selector" --out "$work/$out" "$@" >"$work/$out.log" 2>&1
}

# assert <case> <jq filter> <file> [message [report]] — `$corpus` is always the
# fixture corpus, `$report` the audit trail when one was written.
assert() {
  local name="$1" filter="$2" file="$3" message="${4:-filter returned false}" report="${5:-}"
  local value
  if [ -n "$report" ]; then
    value="$(jq -r --slurpfile corpus "$corpus" --slurpfile report "$report" "$filter" "$work/$file" 2>&1)" || {
      bad "$name" "$file is not JSON: $value"
      return 1
    }
  else
    value="$(jq -r --slurpfile corpus "$corpus" "$filter" "$work/$file" 2>&1)" || {
      bad "$name" "$file is not JSON: $value"
      return 1
    }
  fi
  if [ "$value" = "true" ]; then
    pass "$name"
  else
    bad "$name" "$message (got: $value)"
  fi
}

# --- 1. no description: the corpus is the CV ------------------------------
if run plain.json --resume "$corpus"; then
  if diff -q <(jq -S . "$corpus") <(jq -S . "$work/plain.json") >/dev/null; then
    pass "no description is a passthrough"
  else
    bad "no description is a passthrough" "the projection differs from the corpus"
  fi
else
  bad "no description is a passthrough" "the run failed: $(cat "$work/plain.json.log")"
fi

# The projection must be labelled, and the passthrough must not claim to be one.
jq -S . "$corpus" >"$work/plain-copy.json"
if run plain-audit.json --resume "$corpus" --audit "$work/plain-audit.report"; then
  if jq -e '.mode == "passthrough"' "$work/plain-audit.report" >/dev/null &&
    jq -e '.meta.appflow == null' "$work/plain-audit.json" >/dev/null; then
    pass "a projection says it is one"
  else
    bad "a projection says it is one" "the passthrough was labelled or the audit was not"
  fi
else
  bad "a projection says it is one" "the run failed"
fi

# --- a real description ---------------------------------------------------
run jd.json --resume "$corpus" --jd "$here/fixtures/jd-kubernetes.txt" \
  --audit "$work/jd.report" --max-highlights 2 --max-projects 1 --max-keywords 1

assert "highlights are capped" '
  ([.work[].highlights | length] | all(. <= 2 and . >= 1))
' jd.json "a role kept more than the cap or lost every line"

assert "a matching role keeps matching lines" '
  [.work[] | select(.name == "Acme") | .highlights[] | test("Kubernetes")] | any
' jd.json "the Kubernetes role kept no Kubernetes line"

assert "a role with no overlap keeps its lead line" '
  (.work[] | select(.name == "Boxtop") | .highlights) == $corpus[0].work[1].highlights
  and ($report[0].work[] | select(.name == "Boxtop") | .matched == false)
' jd.json "the unrelated role was scored as matched or lost a line" "$work/jd.report"

assert "kept lines come from the corpus" '
  ([.work[] | .name] - ["Acme", "Boxtop"]) == []
  and (([.work[] | select(.name == "Acme") | .highlights[]] - $corpus[0].work[0].highlights) == [])
' jd.json "the projection contains a line the corpus does not"

assert "kept lines keep the role's order" '
  ([.work[] | select(.name == "Acme") | .highlights[]] as $kept
   | [$corpus[0].work[0].highlights[] | select(. as $h | $kept | index($h)) ] as $ordered
   | $ordered == $kept)
' jd.json "the kept lines were reordered by score"

assert "projects are capped and relevant" '
  (.projects | length) == 1 and .projects[0].name == "Sharded queue operator"
' jd.json "the cap did not hold or the wrong project survived"

assert "skill groups survive with fewer keywords" '
  ([.skills[] | .name] == ["Containers", "Systems"])
  and ([.skills[].keywords | length] | all(. == 1))
' jd.json "a skill group disappeared or a group kept more than the cap"

assert "structure is not material" '
  (.languages == $corpus[0].languages) and (.education == $corpus[0].education)
  and ([.work[].name] == ["Acme", "Boxtop"])
' jd.json "the filter touched languages, education or the list of roles"

# --- an unrelated description --------------------------------------------
run unrelated.json --resume "$corpus" --jd "$here/fixtures/jd-unrelated.txt" \
  --audit "$work/unrelated.report" --max-highlights 2 --max-projects 1
assert "an unrelated description still yields a CV" '
  ([.work[].highlights | length] | all(. >= 1)) and ((.projects | length) == 1)
' unrelated.json "a description matching nothing in the corpus produced an empty CV"

# --- German description against the English corpus -----------------------
run deutsch.json --resume "$corpus" --jd "$here/fixtures/jd-deutsch.txt" --max-highlights 1
assert "a German description reaches the English corpus" '
  ([.work[] | select(.name == "Acme") | .highlights[]] | join(" ")) | test("certificat|keys"; "i")
' deutsch.json "the glossary did not carry Verschlüsselung/Schlüssel onto certificates/keys"

# --- matching ------------------------------------------------------------
# A glossary entry is written once, in its citation form, and the corpus holds
# the conjugated one. Asserted on the matcher rather than through a fixture, so
# the rule itself is pinned: encryption/encrypted used to score zero, which made
# a correct glossary entry select nothing.
if python3 - "$selector" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("appflow_select", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
assert module.matches("encryption", "encrypted")
assert module.matches("operator", "operations")
assert module.matches("key", "keys")
assert module.matches("engineer", "engineering")
assert not module.matches("solar", "soldering")
assert not module.matches("risk", "brisk")
PY
then
  pass "an inflection still names the same term"
else
  bad "an inflection still names the same term" "the matcher lost an inflection, a plural or a negative case"
fi

# --- determinism ---------------------------------------------------------
run twice-a.json --resume "$corpus" --jd "$here/fixtures/jd-kubernetes.txt" --audit "$work/twice-a.report"
run twice-b.json --resume "$corpus" --jd "$here/fixtures/jd-kubernetes.txt" --audit "$work/twice-b.report"
if cmp -s "$work/twice-a.json" "$work/twice-b.json" && cmp -s "$work/twice-a.report" "$work/twice-b.report"; then
  pass "the same input produces the same bytes"
else
  bad "the same input produces the same bytes" "two identical runs differ"
fi

# --- refusal -------------------------------------------------------------
if python3 "$selector" --resume "$work/absent.json" --out "$work/never.json" >/dev/null 2>&1; then
  bad "an unreadable corpus is refused" "a missing corpus exited 0"
else
  rc=$?
  if [ "$rc" = 2 ]; then
    pass "an unreadable corpus is refused"
  else
    bad "an unreadable corpus is refused" "exit $rc, want 2"
  fi
fi

# --- coverage, both ways -------------------------------------------------
ran_set="$(printf '%s\n' "${ran[@]}")"
expected_set="$(printf '%s\n' "${EXPECTED[@]}")"
for c in "${EXPECTED[@]}"; do
  if ! grep -qxF -- "$c" <<<"$ran_set"; then
    echo "FAIL coverage: expected case did not run: ${c}" >&2
    fail=1
  fi
done
for c in "${ran[@]}"; do
  if ! grep -qxF -- "$c" <<<"$expected_set"; then
    echo "FAIL coverage: case is not declared in EXPECTED: ${c}" >&2
    fail=1
  fi
done

if [ "$fail" != 0 ]; then
  echo "appflow-select fixture: FAILED" >&2
  exit 1
fi
echo "appflow-select fixture: ${#EXPECTED[@]} cases ok (all expected)"
