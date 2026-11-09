#!/usr/bin/env bash
# Fixture for `modules/plugins/appflow/portfolio.py`.
#
# The portfolio is the second corpus on the same wire (tests/content-api), so the
# assertions are the same shape as `tests/career-cli` plus the two things this
# vocabulary adds: a `links` array that has to survive as objects rather than
# text, and a German corpus that names no English project and is therefore paired
# by position — a pairing that must refuse rather than shift by one.
#
#   1. import -> export reproduces the fixture document exactly, in both
#      languages, and leaves the profile, sections, skills and UI alone;
#   2. every write sends every parameter the endpoint requires;
#   3. add appends, set touches only its flags, rm waits for --yes, a translated
#      add needs --source-title, and a mismatched German import is refused.
#
# Coverage is asserted both ways. No database, no nix, loopback only. Exit 0 =
# every case behaves, 1 = a case regressed, 2 = the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
cli="$repo/modules/plugins/appflow/portfolio.py"
en="$here/fixtures/portfolio.json"
de="$here/fixtures/portfolio.de.json"

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

python3 "$here/../content-api/api.py" >"$work/api.log" 2>&1 &
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
  "links survive as label and href"
  "an absent field stays absent"
  "the export reproduces the English portfolio"
  "a re-export is byte-identical"
  "the export keeps what the rows do not own"
  "a second import is not a second set of rows"
  "the German import pairs by position"
  "the export reproduces the German portfolio"
  "the German re-export is byte-identical"
  "a German import that is not parallel is refused"
  "a refused German import writes nothing"
  "set changes only the flags it is given"
  "set with no flags is refused"
  "an unknown id is refused"
  "add appends after the last row"
  "add refuses an id that exists"
  "a translated add needs --source-title"
  "rm without --yes is refused"
  "rm without --yes removes nothing"
  "rm with --yes removes the row"
  "the listing is in page order"
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
  "Clean Energy Telemetry Platform|Lead Operations|2016 — 2020|O3 ENERGY|3|true|Python,PostgreSQL" \
  "$(jq -r '.portfolio_project[] | select(.id == "project-clean-energy-telemetry-platform")
     | [.title, .role, .period, .badge, .sector, .featured, .stack] | join("|")' <<<"$rows")"
check "links survive as label and href" \
  $'Discuss Architecture\tmailto:fictional@example.com?subject=Asset%20Operations' \
  "$(jq -r '.portfolio_project[] | select(.id == "project-clean-energy-telemetry-platform") | .links' <<<"$rows")"
check "an absent field stays absent" \
  "null|null|null|null" \
  "$(jq -r '.portfolio_project[] | select(.id == "project-fibonacci-streaming-automaton")
     | [.description, .highlights, .link, .links] | map(if . == null then "null" else . end) | join("|")' <<<"$rows")"

# --- the round trip --------------------------------------------------------

cp "$en" "$work/roundtrip-en.json"
cli_run export --into "$work/roundtrip-en.json"
if diff -q <(jq -S . "$en") <(jq -S . "$work/roundtrip-en.json") >/dev/null; then
  pass "the export reproduces the English portfolio"
else
  bad "the export reproduces the English portfolio" "$(diff <(jq -S . "$en") <(jq -S . "$work/roundtrip-en.json") | head -12)"
fi

# Byte-identical, not merely equal: the committed files are checked in, and an
# export that reorders keys turns every re-seed into a diff nobody can read.
if cmp -s "$en" "$work/roundtrip-en.json"; then
  pass "a re-export is byte-identical"
else
  bad "a re-export is byte-identical" "$(diff "$en" "$work/roundtrip-en.json" | head -12)"
fi

printf '{"profile": {"name": "Only Profile"}}\n' >"$work/bare.json"
cli_run export --into "$work/bare.json"
check "the export keeps what the rows do not own" \
  "Only Profile|3" \
  "$(jq -r '[.profile.name, (.projects | length)] | join("|")' "$work/bare.json")"

cli_run import --from "$en" --language en
check "a second import is not a second set of rows" \
  "3" \
  "$(state | jq -r '[.portfolio_project[] | select(.language == "en")] | length')"

# --- German ----------------------------------------------------------------

cli_run import --from "$de" --language de
check "the German import pairs by position" \
  "project-clean-energy-telemetry-platform|Clean Energy Telemetry Platform" \
  "$(state | jq -r '.portfolio_project[] | select(.language == "de" and .sort == 0)
     | [.id, .sourceTitle] | join("|")')"

cp "$de" "$work/roundtrip-de.json"
cli_run export --into "$work/roundtrip-de.json" --language de
if diff -q <(jq -S . "$de") <(jq -S . "$work/roundtrip-de.json") >/dev/null; then
  pass "the export reproduces the German portfolio"
else
  bad "the export reproduces the German portfolio" "$(diff <(jq -S . "$de") <(jq -S . "$work/roundtrip-de.json") | head -12)"
fi
if cmp -s "$de" "$work/roundtrip-de.json"; then
  pass "the German re-export is byte-identical"
else
  bad "the German re-export is byte-identical" "$(diff "$de" "$work/roundtrip-de.json" | head -12)"
fi

jq 'del(.projects[2])' "$de" >"$work/short-de.json"
before=$(state | jq '[.portfolio_project[] | select(.language == "de")] | length')
cli_run import --from "$work/short-de.json" --language de
if [ $? -ne 0 ]; then
  pass "a German import that is not parallel is refused"
else
  bad "a German import that is not parallel is refused" "a 2-project translation was accepted over 3 English rows"
fi
check "a refused German import writes nothing" "$before" \
  "$(state | jq '[.portfolio_project[] | select(.language == "de")] | length')"

# --- set -------------------------------------------------------------------

cli_run set-project project-clean-energy-telemetry-platform --language en --no-featured
after=$(state)
check "set changes only the flags it is given" \
  "false|Governed quantitative operations across \$100M+ in assets.|Discuss Architecture	mailto:fictional@example.com?subject=Asset%20Operations" \
  "$(jq -r '.portfolio_project[] | select(.id == "project-clean-energy-telemetry-platform" and .language == "en")
     | [.featured, .impact, .links] | join("|")' <<<"$after")"

cli_run set-project project-clean-energy-telemetry-platform --language en
check "set with no flags is refused" "2" "$?"

cli_run set-project project-nobody --language en --sector 1
check "an unknown id is refused" "1" "$?"

# --- add -------------------------------------------------------------------

cli_run add-project --title "Kepler Orbit" --sector 1 --stack Go --stack Nushell \
  --highlight "one" --highlight "two" --links "Repo=https://example.com/kepler"
after=$(state)
check "add appends after the last row" \
  "project-kepler-orbit|3|Go,Nushell|one"$'\n'"two|Repo	https://example.com/kepler" \
  "$(jq -r '.portfolio_project[] | select(.id == "project-kepler-orbit")
     | [.id, .sort, .stack, .highlights, .links] | join("|")' <<<"$after")"

cli_run add-project --title "Kepler Orbit"
check "add refuses an id that exists" "1" "$?"

cli_run add-project --title "Wirbel-Engine" --language de
check "a translated add needs --source-title" "2" "$?"

# --- rm --------------------------------------------------------------------

before=$(state | jq '[.portfolio_project[]] | length')
cli_run rm-project project-kepler-orbit
check "rm without --yes is refused" "2" "$?"
check "rm without --yes removes nothing" "$before" "$(state | jq '[.portfolio_project[]] | length')"

cli_run rm-project project-kepler-orbit --yes
check "rm with --yes removes the row" "$((before - 1))" "$(state | jq '[.portfolio_project[]] | length')"

# --- the listing -----------------------------------------------------------

first=$(python3 "$cli" --api "$api" projects --language en 2>/dev/null | head -1 | awk '{print $1}')
check "the listing is in page order" "project-clean-energy-telemetry-platform" "$first"

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
if [ "${#ran[@]}" -ne "${#EXPECTED[@]}" ] && [ "$fail" -eq 0 ]; then
  bad "coverage" "ran ${#ran[@]} cases, expected ${#EXPECTED[@]}"
fi

if [ "$fail" -ne 0 ]; then
  echo "FAIL: the portfolio tooling does not round-trip the corpus." >&2
  exit 1
fi
echo "PASS: import, export, set, add and rm agree with the fixture."
