#!/usr/bin/env bash
# Fixture for scripts/task/mail-atlas.sh — the probe that answers whether the
# mailbox is still moving, driven against a stub archive instead of delphi.
#
# The stub is built to behave like NpgsqlRest where that matters: an undeclared
# query parameter is a **404**, not a 400, so a search that appended `lim` would
# read as "route not deployed". One case asserts the CLI never does that, and
# another runs the same search with a space and an ampersand to prove the query
# is encoded rather than pasted.
#
# Coverage is asserted both ways: a case listed in EXPECTED that no longer runs
# fails, and so does a case that runs without being listed.
#
# Exit: 0 every case behaves, 1 a case regressed, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
cli="$repo/scripts/task/mail-atlas.sh"
work=$(mktemp -d)
stub_pid=""
cleanup() {
  [ -n "$stub_pid" ] && kill "$stub_pid" 2>/dev/null
  rm -rf "$work"
}
trap cleanup EXIT

for cmd in python3 jq curl bash; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "fixture: $cmd is required" >&2
    exit 2
  }
done
[ -f "$cli" ] || {
  echo "fixture: $cli is missing" >&2
  exit 2
}

cat >"$work/stub.py" <<'PY'
import json, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit, parse_qs

STATE = {"letters": 100, "tagged": 60, "newest": "2026-11-26T10:00:00+00",
         "newestMailAgeH": 1, "openAction": 3, "oldestQueuedMin": 0,
         "stats_missing": False, "echo_q": ""}


class H(BaseHTTPRequestHandler):
    def do_PUT(self):
        body = json.loads(self.rfile.read(int(self.headers["content-length"])))
        STATE.update(body)
        self.send_response(204)
        self.send_header("content-length", "0")
        self.end_headers()

    def do_GET(self):
        parts = urlsplit(self.path)
        params = set(parse_qs(parts.query).keys())
        if parts.path == "/api/queue-health":
            if params:
                return self.not_found()
            return self.json([{ "openPerson": 0, "openAction": STATE["openAction"],
                                "unmatchedFresh": 0, "newestMailAgeH": STATE["newestMailAgeH"],
                                "priorWeekMails": 9 }])
        if parts.path == "/api/atlas-stats":
            if STATE["stats_missing"]:
                return self.not_found()
            return self.json([{ "letters": STATE["letters"], "tags": 3, "tagged": STATE["tagged"],
                                "associations": 7, "newest": STATE["newest"], "inbox": STATE["letters"],
                                "queued": 0, "commands": 0,
                                "oldestPendingMin": 0,
                                "oldestQueuedMin": STATE["oldestQueuedMin"] }])
        if parts.path == "/api/list-emails":
            if params != {"lim"}:
                return self.not_found()
            lim = int(parse_qs(parts.query)["lim"][0])
            return self.json([{ "id": i, "sender": "A <a@example.com>",
                               "subject": f"letter {i}" } for i in range(lim)])
        if parts.path in ("/api/emails-search", "/api/emails-fuzzy"):
            if params != {"q"}:
                return self.not_found()
            STATE["echo_q"] = parse_qs(parts.query)["q"][0]
            return self.json([{ "id": 1, "subject": "hit", "q": STATE["echo_q"] }])
        if parts.path == "/openapi.json":
            return self.json({"paths": {"/api/queue-health": {}, "/api/atlas-stats": {},
                                       "/api/list-emails": {}, "/api/emails-search": {}}})
        self.not_found()

    def json(self, payload):
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def not_found(self):
        self.send_response(404)
        self.send_header("content-length", "0")
        self.end_headers()

    def log_message(self, *args):
        pass


ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY

port="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')"
python3 "$work/stub.py" "$port" &
stub_pid=$!
api="http://127.0.0.1:$port"
for _ in $(seq 1 50); do
  curl -sf -o /dev/null "$api/api/queue-health" && break
  sleep 0.1
done

EXPECTED=(
  "a healthy archive passes and reports its counters"
  "stale mail fails with the ceiling named"
  "a stuck queue fails"
  "an empty archive fails"
  "a missing stats route is named as a refusal"
  "search sends q and nothing else"
  "a query with a space and an ampersand is encoded"
  "recent defaults to five and refuses a non-number"
  "routes lists the deployed contract"
  "an unreachable archive is named"
)

ran=()
failed=0
code=0
out=""

set_state() {
  curl -sf -X PUT -H 'content-type: application/json' -d "$1" "$api/state" >/dev/null
}

run_cli() {
  local case=$1
  shift
  ran+=("$case")
  code=0
  out=$(EMAIL_ARCHIVE_API="$api" MAIL_ATLAS_TIMEOUT=5 bash "$cli" "$@" 2>&1) || code=$?
}

fail() {
  printf 'FAIL %s: %s\n' "$1" "$2" >&2
  [ -n "${out:-}" ] && printf '  output: %s\n' "$(printf '%s' "$out" | head -c 300)" >&2
  failed=1
}

case="a healthy archive passes and reports its counters"
run_cli "$case" probe
if [ "$code" != 0 ]; then
  fail "$case" "exit $code"
elif [ "$(printf '%s' "$out" | jq -r .verdict)" != "ok" ]; then
  fail "$case" "verdict $(printf '%s' "$out" | jq -r .verdict)"
elif [ "$(printf '%s' "$out" | jq -r .letters)" != "100" ]; then
  fail "$case" "letters $(printf '%s' "$out" | jq -r .letters)"
fi

case="stale mail fails with the ceiling named"
set_state '{"newestMailAgeH": 100}'
run_cli "$case" probe
if [ "$code" != 1 ]; then
  fail "$case" "exit $code, expected 1"
elif ! printf '%s' "$out" | grep -q "newest mail is 100h old"; then
  fail "$case" "the reason does not name the age"
elif ! printf '%s' "$out" | grep -q "ceiling 48h"; then
  fail "$case" "the reason does not name the ceiling"
fi
set_state '{"newestMailAgeH": 1}'

case="a stuck queue fails"
set_state '{"oldestQueuedMin": 120}'
run_cli "$case" probe
if [ "$code" != 1 ] || ! printf '%s' "$out" | grep -q "queued letter is 120m old"; then
  fail "$case" "exit $code"
fi
set_state '{"oldestQueuedMin": 0}'

case="an empty archive fails"
set_state '{"letters": 0}'
run_cli "$case" probe
if [ "$code" != 1 ] || ! printf '%s' "$out" | grep -q "holds no letters"; then
  fail "$case" "exit $code"
fi
set_state '{"letters": 100}'

case="a missing stats route is named as a refusal"
set_state '{"stats_missing": true}'
run_cli "$case" probe
if [ "$code" != 1 ] || ! printf '%s' "$out" | grep -q "/api/atlas-stats -> HTTP 404"; then
  fail "$case" "exit $code"
fi
set_state '{"stats_missing": false}'

case="search sends q and nothing else"
run_cli "$case" search nixos
if [ "$code" != 0 ]; then
  fail "$case" "exit $code — an extra parameter would have been a 404"
elif [ "$(printf '%s' "$out" | jq -r '.[0].q')" != "nixos" ]; then
  fail "$case" "the archive saw q=$(printf '%s' "$out" | jq -r '.[0].q')"
fi

case="a query with a space and an ampersand is encoded"
run_cli "$case" search "invoice & receipt"
if [ "$code" != 0 ]; then
  fail "$case" "exit $code"
elif [ "$(printf '%s' "$out" | jq -r '.[0].q')" != "invoice & receipt" ]; then
  fail "$case" "the archive decoded $(printf '%s' "$out" | jq -r '.[0].q')"
fi

case="recent defaults to five and refuses a non-number"
run_cli "$case" recent
if [ "$code" != 0 ] || [ "$(printf '%s' "$out" | jq 'length')" != "5" ]; then
  fail "$case" "default exit $code, rows $(printf '%s' "$out" | jq 'length' 2>/dev/null)"
fi
run_cli "$case" recent abc
if [ "$code" != 2 ]; then
  fail "$case" "a non-number gave exit $code, expected 2"
fi

case="routes lists the deployed contract"
run_cli "$case" routes
if [ "$code" != 0 ]; then
  fail "$case" "exit $code"
elif [ "$(printf '%s' "$out" | head -1)" != "/api/atlas-stats" ]; then
  fail "$case" "first route $(printf '%s' "$out" | head -1)"
elif [ "$(printf '%s' "$out" | grep -c .)" != "4" ]; then
  fail "$case" "route count $(printf '%s' "$out" | grep -c .)"
fi

case="an unreachable archive is named"
ran+=("$case")
code=0
out=$(EMAIL_ARCHIVE_API="http://127.0.0.1:9" MAIL_ATLAS_TIMEOUT=2 bash "$cli" probe 2>&1) || code=$?
if [ "$code" != 1 ] || ! printf '%s' "$out" | grep -q "unreachable"; then
  fail "$case" "exit $code"
fi

for case in "${EXPECTED[@]}"; do
  seen=0
  for ran_case in "${ran[@]}"; do
    [ "$ran_case" = "$case" ] && seen=1
  done
  [ "$seen" = 1 ] || fail "$case" "listed in EXPECTED but never ran"
done
for ran_case in "${ran[@]}"; do
  seen=0
  for case in "${EXPECTED[@]}"; do
    [ "$ran_case" = "$case" ] && seen=1
  done
  [ "$seen" = 1 ] || fail "$ran_case" "ran but is not in EXPECTED"
done

if [ "$failed" != 0 ]; then
  echo "mail-atlas-api: fixture failed" >&2
  exit 1
fi
printf 'ok   mail-atlas-api: %d cases\n' "${#EXPECTED[@]}"
