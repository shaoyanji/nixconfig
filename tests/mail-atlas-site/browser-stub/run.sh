#!/usr/bin/env bash
# Fixture for the mail-atlas drawer smoke with no browser at all.
#
# `tests/mail-atlas-site/run.sh` exists to catch a page that renders while a
# panel is empty, and its assertions are worth checking on a host that has no
# Chrome and no clanker either. `BROWSER_STUB` replaces `agent-browser` with the
# script below: `open` is a no-op, `eval` answers a canned payload, and the real
# verifier reads it exactly as it reads a browser's answer.
#
# A pass case proves the good payload still passes; the two mutated ones prove
# the verifier is still looking at the row count and the `#sources-open` button,
# which is the part a browser run would otherwise be the only witness to.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
smoke="$here/../run.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

[ -f "$smoke" ] || {
  echo "fixture: $smoke is missing" >&2
  exit 2
}

cat >"$work/browser" <<'SH'
#!/usr/bin/env bash
# The canned browser: `open <url>` succeeds quietly, `eval [--stdin] <js>`
# answers BROWSER_STUB_PAYLOAD the way agent-browser does — as a JSON *string*.
set -uo pipefail
[ "${1:-}" = "open" ] && exit 0
if [ "${1:-}" = "eval" ]; then
  shift
  [ "${1:-}" = "--stdin" ] && { cat >/dev/null; shift; }
  python3 -c 'import json,sys; print(json.dumps(open(sys.argv[1]).read()))' "$BROWSER_STUB_PAYLOAD"
  exit 0
fi
echo "canned browser: unexpected argv $*" >&2
exit 1
SH
chmod +x "$work/browser"

python3 - "$work" <<'PY'
import json, sys

work = sys.argv[1]
good = {
    "loaded": 3,
    "untaggedChip": "untagged 1",
    "untaggedRows": ["Someone no tag at all"],
    "untaggedPressed": "true",
    "afterClear": 3,
    "hub": "ci 2",
    "focus": "tag:ci",
    "cluster": 3,
    "focusAfter": "",
    "chipLabels": ["recent", "queries"],
    "recent": ["invoices"],
    "button": True,
    "open": True,
    "rows": 3,
    "domains": ["github.com", "mail.kleinanzeigen.de", "google.com"],
    "untagged": ["", "", "80 untagged"],
    "foot": "3 domains, 1178 letters",
    "q": "github.com",
    "afterOpen": False,
}
# Plain objects on disk; the canned browser is what quotes them, so the
# verifier meets the same shape a real `agent-browser eval` returns.
json.dump(good, open(f"{work}/good.json", "w"))
short = dict(good, rows=2)
json.dump(short, open(f"{work}/rows.json", "w"))
nobutton = dict(good, button=False)
json.dump(nobutton, open(f"{work}/button.json", "w"))
PY

EXPECTED=(
  "a good payload passes the drawer assertions"
  "a short row count fails"
  "a missing sources button fails"
)
ran=()
failed=0

run_case() {
  local case=$1 payload=$2 want=$3 needle=$4
  ran+=("$case")
  local code=0 out=""
  out=$(BROWSER_STUB="$work/browser" BROWSER_STUB_PAYLOAD="$work/$payload" \
    bash "$smoke" 2>&1) || code=$?
  if [ "$code" != "$want" ]; then
    printf 'FAIL %s: exit %s, expected %s\n' "$case" "$code" "$want" >&2
    printf '  output: %s\n' "$(printf '%s' "$out" | tail -3 | tr '\n' ' ')" >&2
    failed=1
  elif [ -n "$needle" ] && ! printf '%s' "$out" | grep -q "$needle"; then
    printf 'FAIL %s: output never said %s\n' "$case" "$needle" >&2
    printf '  output: %s\n' "$(printf '%s' "$out" | tail -3 | tr '\n' ' ')" >&2
    failed=1
  fi
}

run_case "a good payload passes the drawer assertions" good.json 0 "PASS sources drawer: 3 rows"
run_case "a short row count fails" rows.json 1 "expected 3 rows, saw 2"
run_case "a missing sources button fails" button.json 1 "#sources-open is missing"

for case in "${EXPECTED[@]}"; do
  seen=0
  for ran_case in "${ran[@]}"; do
    [ "$ran_case" = "$case" ] && seen=1
  done
  [ "$seen" = 1 ] || {
    printf 'FAIL %s: listed in EXPECTED but never ran\n' "$case" >&2
    failed=1
  }
done
for ran_case in "${ran[@]}"; do
  seen=0
  for case in "${EXPECTED[@]}"; do
    [ "$ran_case" = "$case" ] && seen=1
  done
  [ "$seen" = 1 ] || {
    printf 'FAIL %s: ran but is not in EXPECTED\n' "$ran_case" >&2
    failed=1
  }
done

if [ "$failed" != 0 ]; then
  echo "mail-atlas-site-stub: fixture failed" >&2
  exit 1
fi
printf 'ok   mail-atlas-site-stub: %d cases\n' "${#EXPECTED[@]}"
