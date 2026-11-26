#!/usr/bin/env bash
# Canned smoke for the mail-atlas sources drawer: serve the SHIPPED site
# derivation, answer the API from canned rows, then drive a real browser.
#
# Why the derivation and not the source dir: the drawer's glyph comes from a font
# subset built in Nix, and the graph loads a wasm module — a smoke over `site/`
# would pass while the packaged page showed tofu and a missing module.
#
# Needs `agent-browser` on PATH (the `full` AI tier, or
# `nix shell github:numtide/llm-agents.nix#agent-browser -c tests/mail-atlas-site/run.sh`).
set -uo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo" || exit 2

command -v agent-browser >/dev/null || {
  echo "mail-atlas-site: agent-browser not on PATH — install it, do not skip silently" >&2
  exit 2
}

echo "== building the site derivation"
site="$(nix build --no-link --print-out-paths \
  ".#nixosConfigurations.delphi.config.services.nginx.virtualHosts.mail-atlas.root" 2>/dev/null)" || {
  echo "mail-atlas-site: the site derivation did not build" >&2
  exit 1
}

work="$(mktemp -d /tmp/mail-atlas-smoke.XXXXXX)"
cleanup() {
  [ -n "${stub_pid:-}" ] && kill "$stub_pid" 2>/dev/null
  rm -rf "$work"
}
trap cleanup EXIT

cat >"$work/stub.py" <<'PY'
import json, os, sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = sys.argv[1]
PORT = int(sys.argv[2])

SENDERS = [
    {"domain": "github.com", "letters": 648, "addresses": 2, "untagged": 0,
     "oldest": "2026-05-07T13:51:31Z", "newest": "2026-11-26T11:12:59Z"},
    {"domain": "mail.kleinanzeigen.de", "letters": 443, "addresses": 1, "untagged": 0,
     "oldest": "2026-06-25T10:17:46Z", "newest": "2026-11-20T23:28:10Z"},
    {"domain": "google.com", "letters": 87, "addresses": 12, "untagged": 80,
     "oldest": "2026-05-12T16:04:15Z", "newest": "2026-11-25T15:11:48Z"},
]

ANSWERS = {
    "/api/atlas-senders": SENDERS,
    "/api/atlas-taxonomy": [],
    "/api/atlas-stats": {"letters": 1178, "inbox": 1178, "queued": 0, "tagged": 1100, "commands": 0},
    "/api/atlas-search": {"total": 0, "hits": []},
    "/api/atlas-tags": [],
    "/api/atlas-actions": [],
}


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def do_GET(self):
        path = self.path.split("?")[0]
        if path in ANSWERS:
            body = json.dumps(ANSWERS[path]).encode()
            self.send_response(200)
            self.send_header("content-type", "application/json")
            self.send_header("content-length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if path.startswith("/api/"):
            self.send_response(404)
            self.send_header("content-length", "0")
            self.end_headers()
            return
        super().do_GET()

    def log_message(self, *args):
        pass


ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
PY

port="$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)"

python3 "$work/stub.py" "$site" "$port" &
stub_pid=$!

for _ in $(seq 1 40); do
  curl -sf -o /dev/null "http://127.0.0.1:$port/api/atlas-stats" && break
  sleep 0.1
done

cat >"$work/probe.js" <<'JS'
(async () => {
  const out = {};
  // The drawer fetches on open; a fixed sleep races a cold stub and a first
  // paint, so wait for the rows themselves.
  const until = async (test, ms = 4000) => {
    const deadline = Date.now() + ms;
    while (Date.now() < deadline) {
      if (test()) return true;
      await new Promise((r) => setTimeout(r, 100));
    }
    return false;
  };
  const button = document.getElementById("sources-open");
  out.button = !!button;
  if (!button) return JSON.stringify(out);
  button.click();
  const dialog = document.getElementById("sources");
  out.open = dialog.open;
  await until(() => document.querySelectorAll("#sources-list .src-row").length > 0);
  const rows = [...document.querySelectorAll("#sources-list .src-row")];
  out.rows = rows.length;
  out.domains = rows.map((r) => r.querySelector(".src-domain").textContent);
  out.untagged = rows.map((r) => r.querySelector(".untagged")?.textContent || "");
  out.foot = document.getElementById("sources-foot").textContent;
  if (rows.length) {
    rows[0].click();
    await new Promise((r) => setTimeout(r, 300));
    out.q = document.getElementById("q").value;
    out.afterOpen = dialog.open;
  }
  return JSON.stringify(out);
})()
JS

echo "== driving a browser against $site"
agent-browser open "http://127.0.0.1:$port/" >/dev/null 2>&1
got="$(agent-browser eval --stdin <"$work/probe.js" 2>/dev/null | tail -1)"

python3 - "$got" <<'PY'
import json, sys

raw = sys.argv[1].strip()
if not raw:
    print("mail-atlas-site: the browser returned nothing", file=sys.stderr)
    sys.exit(1)
try:
    data = json.loads(raw)
    # `eval` answers the JS value; a probe that returns a JSON string arrives
    # quoted, so unwrap it before reading fields.
    if isinstance(data, str):
        data = json.loads(data)
except ValueError:
    print(f"mail-atlas-site: the probe did not return JSON: {raw[:200]}", file=sys.stderr)
    sys.exit(1)

fails = []
if not data.get("button"):
    fails.append("#sources-open is missing")
if not data.get("open"):
    fails.append("the drawer did not open")
if data.get("rows") != 3:
    fails.append(f"expected 3 rows, saw {data.get('rows')}")
if (data.get("domains") or [None])[0] != "github.com":
    fails.append(f"volume sort is wrong: {data.get('domains')}")
if "80 untagged" not in " ".join(data.get("untagged") or []):
    fails.append(f"the untagged badge is missing: {data.get('untagged')}")
if "3 domains" not in (data.get("foot") or ""):
    fails.append(f"the summary line is wrong: {data.get('foot')!r}")
if data.get("q") != "github.com":
    fails.append(f"clicking a shore did not search it: {data.get('q')!r}")
if data.get("afterOpen") is not False:
    fails.append("the drawer stayed open after a row was chosen")

if fails:
    for line in fails:
        print(f"FAIL {line}", file=sys.stderr)
    sys.exit(1)
print(f"PASS sources drawer: {data['rows']} rows, first {data['domains'][0]}, click searched {data['q']}")
PY
