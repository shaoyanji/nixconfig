#!/usr/bin/env bash
# Fixture for `modules/plugins/appflow/career.py`.
#
# The tool is the writable half of "the database is the source of truth": if it
# cannot round-trip a corpus, the JSON files are still the source and the rows
# are a copy. So the assertions are about losslessness, not about a happy path:
#
#   1. import -> export reproduces the fixture document exactly, both languages,
#      including the difference between a field that is absent and one that is
#      empty, and the contact block the rows do not own;
#   2. every write sends every parameter the endpoint requires (a stub that
#      refuses a sparse body, as NpgsqlRest does), and `sort: null` appends;
#   3. `set` touches only the flags it is given, `add` refuses an id that exists,
#      `rm` refuses without `--yes`, and a row id shared by two languages needs
#      `--language` rather than a guess.
#
# Coverage is asserted in both directions: a case listed in EXPECTED that no
# longer runs fails, and so does a case that runs without being listed. Deleting
# an assertion therefore cannot pass as a smaller suite.
#
# No database, no nix, no network beyond loopback. Exit 0 = every case behaves,
# 1 = a case regressed, 2 = the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
cli="$repo/modules/plugins/appflow/career.py"
en="$here/fixtures/resume.json"
de="$here/fixtures/lebenslauf.json"

command -v python3 >/dev/null 2>&1 || {
  echo "fixture: python3 is required" >&2
  exit 2
}
command -v jq >/dev/null 2>&1 || {
  echo "fixture: jq is required" >&2
  exit 2
}
[ -f "$cli" ] && [ -f "$en" ] && [ -f "$de" ] || {
  echo "fixture: the CLI or a corpus fixture is missing" >&2
  exit 2
}

work=$(mktemp -d)
server=""
cleanup() {
  [ -n "$server" ] && kill "$server" 2>/dev/null
  rm -rf "$work"
}
trap cleanup EXIT

python3 "$here/api.py" >"$work/api.log" 2>&1 &
server=$!

port=""
for _ in $(seq 1 100); do
  port=$(sed -n 's/^PORT=//p' "$work/api.log")
  [ -n "$port" ] && break
  sleep 0.05
done
[ -n "$port" ] || {
  echo "fixture: the stub API did not start: $(cat "$work/api.log")" >&2
  exit 2
}
api="http://127.0.0.1:$port"

cli_run() {
  python3 "$cli" --api "$api" "$@" >"$work/out.log" 2>&1
}

state() {
  curl -sS --max-time 5 "$api/_state"
}

EXPECTED=(
  "the import stores every field"
  "an absent field stays absent"
  "the export reproduces the English corpus"
  "the export keeps what the rows do not own"
  "a second import is not a second set of rows"
  "the German import shares the English ids"
  "the export reproduces the German corpus"
  "a shared id needs a language"
  "set changes only the flags it is given"
  "set on a language leaves the other one alone"
  "set with no flags is refused"
  "an unknown id is refused"
  "add appends after the last row"
  "add refuses an id that exists"
  "rm without --yes is refused"
  "rm without --yes removes nothing"
  "rm with --yes removes the row"
  "the listing is in CV order"
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

# check <case> <expected> <actual>
check() {
  if [ "$2" = "$3" ]; then
    pass "$1"
  else
    bad "$1" "expected [$2], got [$3]"
  fi
}

# --- English import --------------------------------------------------------

cli_run import --from "$en" --language en
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "fixture: import en failed: $(cat "$work/out.log")" >&2
  exit 2
fi

rows=$(state)
check "the import stores every field" \
  $'Built a thing nobody needed.\nAdvised a client who did.|risk,Go|Founder|Northwind Consulting|2020-06-01|2025-08-19' \
  "$(jq -r '.career_role[] | select(.id == "role-northwind-consulting-2020")
     | [.highlights, .keywords, .position, .employer, .startDate, .endDate] | join("|")' <<<"$rows")"
check "an absent field stays absent" \
  "null|null|null" \
  "$(jq -r '.career_role[] | select(.id == "role-contoso-energy-2016")
     | [.summary, .highlights, .endDate] | map(if . == null then "null" else . end) | join("|")' <<<"$rows")"

# --- the round trip --------------------------------------------------------

cp "$en" "$work/roundtrip-en.json"
cli_run export --into "$work/roundtrip-en.json"
if diff -q <(jq -S . "$en") <(jq -S . "$work/roundtrip-en.json") >/dev/null; then
  pass "the export reproduces the English corpus"
else
  bad "the export reproduces the English corpus" "$(diff <(jq -S . "$en") <(jq -S . "$work/roundtrip-en.json") | head -12)"
fi

printf '{"basics": {"name": "Only Basics"}}\n' >"$work/bare.json"
cli_run export --into "$work/bare.json"
check "the export keeps what the rows do not own" \
  "Only Basics|2|2" \
  "$(jq -r '[.basics.name, (.work | length), (.projects | length)] | join("|")' "$work/bare.json")"

cli_run import --from "$en" --language en
check "a second import is not a second set of rows" \
  "2 2" \
  "$(state | jq -r '"\([.career_role[] | select(.language == "en")] | length) \([.career_project[] | select(.language == "en")] | length)"')"

# --- German ----------------------------------------------------------------

cli_run import --from "$de" --language de
check "the German import shares the English ids" \
  "project-nixconfig-2023,project-swirl-engine-2026,role-contoso-energy-2016,role-northwind-consulting-2020|Swirl Engine" \
  "$(state | jq -r '"\([.career_role[], .career_project[] | select(.language == "de") | .id] | unique | sort | join(","))|\([.career_project[] | select(.language == "de" and .id == "project-swirl-engine-2026")][0].resumeName)"')"

cp "$de" "$work/roundtrip-de.json"
cli_run export --into "$work/roundtrip-de.json" --language de
if diff -q <(jq -S . "$de") <(jq -S . "$work/roundtrip-de.json") >/dev/null; then
  pass "the export reproduces the German corpus"
else
  bad "the export reproduces the German corpus" "$(diff <(jq -S . "$de") <(jq -S . "$work/roundtrip-de.json") | head -12)"
fi

# --- set -------------------------------------------------------------------

cli_run set-role role-contoso-energy-2016 --position "Senior Analyst"
if [ $? -ne 0 ]; then
  pass "a shared id needs a language"
else
  bad "a shared id needs a language" "set without --language exited 0"
fi

cli_run set-role role-contoso-energy-2016 --language en --position "Senior Analyst"
after=$(state)
check "set changes only the flags it is given" \
  "Senior Analyst|Contoso Energy|null" \
  "$(jq -r '.career_role[] | select(.id == "role-contoso-energy-2016" and .language == "en")
     | [.position, .employer, (.highlights // "null")] | join("|")' <<<"$after")"
check "set on a language leaves the other one alone" \
  "Analyst" \
  "$(jq -r '.career_role[] | select(.id == "role-contoso-energy-2016" and .language == "de") | .position' <<<"$after")"

cli_run set-role role-contoso-energy-2016 --language en
check "set with no flags is refused" "2" "$?"

cli_run set-role role-nobody-1999 --language en --position "Nobody"
check "an unknown id is refused" "1" "$?"

# --- add -------------------------------------------------------------------

cli_run add-project --name "Kepler Orbit" --start 2026-01-01 --highlight "one" --highlight "two"
after=$(state)
check "add appends after the last row" \
  "project-kepler-orbit-2026|2|one"$'\n'"two|null" \
  "$(jq -r '.career_project[] | select(.id == "project-kepler-orbit-2026")
     | [.id, .sort, .highlights, (.entity // "null")] | join("|")' <<<"$after")"

cli_run add-project --name "Kepler Orbit" --start 2026-01-01
check "add refuses an id that exists" "1" "$?"

# --- rm --------------------------------------------------------------------

before=$(state | jq '[.career_project[]] | length')
cli_run rm-project project-kepler-orbit-2026
check "rm without --yes is refused" "2" "$?"
check "rm without --yes removes nothing" "$before" "$(state | jq '[.career_project[]] | length')"

cli_run rm-project project-kepler-orbit-2026 --yes
check "rm with --yes removes the row" "$((before - 1))" "$(state | jq '[.career_project[]] | length')"

# --- the listing -----------------------------------------------------------

first=$(python3 "$cli" --api "$api" roles --language en 2>/dev/null | head -1 | awk '{print $1}')
check "the listing is in CV order" "role-northwind-consulting-2020" "$first"

# --- coverage --------------------------------------------------------------

for case in "${EXPECTED[@]}"; do
  found=""
  for seen in "${ran[@]}"; do
    [ "$seen" = "$case" ] && found=1 && break
  done
  [ -n "$found" ] || bad "$case" "listed in EXPECTED but never ran"
done
for seen in "${ran[@]}"; do
  found=""
  for case in "${EXPECTED[@]}"; do
    [ "$seen" = "$case" ] && found=1 && break
  done
  [ -n "$found" ] || bad "$seen" "ran but is not in EXPECTED"
done
# A duplicated bad() also adds a second entry to `ran`; identical names are the
# only way that happens here, so a count mismatch is a mis-listed case.
if [ "${#ran[@]}" -ne "${#EXPECTED[@]}" ] && [ "$fail" -eq 0 ]; then
  bad "coverage" "ran ${#ran[@]} cases, expected ${#EXPECTED[@]}"
fi

if [ "$fail" -ne 0 ]; then
  echo "FAIL: the career tooling does not round-trip the corpus." >&2
  exit 1
fi
echo "PASS: import, export, set, add and rm agree with the fixture."
