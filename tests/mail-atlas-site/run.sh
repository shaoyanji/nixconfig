#!/usr/bin/env bash
# Canned smoke for the mail-atlas sources drawer: serve the SHIPPED site
# derivation, answer the API from canned rows, then drive a real browser.
#
# Why the derivation and not the source dir: the drawer's glyph comes from a font
# subset built in Nix, and the graph loads a wasm module — a smoke over `site/`
# would pass while the packaged page showed tofu and a missing module.
#
# Browser backend:
#   default            `agent-browser` on this host; exit 2 when it is missing
#   CLANKER_BROWSER=1  agent-browser on InstaBox clanker through
#                      `scripts/task/clanker-browser.sh`; the site and the stub
#                      are copied there and served on its loopback
#   CLANKER_BROWSER=0  force the local backend, even inside a clanker shell
#   BROWSER_STUB=path  replace the browser with a script (the fixture in
#                      `browser-stub/run.sh`); no browser is needed at all
#
# Exit: 0 the assertions pass, 1 they do not, 2 the fixture cannot run.
set -uo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo" || exit 2

mode=local
case "${CLANKER_BROWSER:-}" in
  1) mode=clanker ;;
  0 | "") ;;
  *)
    echo "mail-atlas-site: CLANKER_BROWSER takes 0 or 1, not $CLANKER_BROWSER" >&2
    exit 2
    ;;
esac

browser() {
  if [ -n "${BROWSER_STUB:-}" ]; then
    bash "$BROWSER_STUB" "$@"
  elif [ "$mode" = clanker ]; then
    bash "$repo/scripts/task/clanker-browser.sh" "$@"
  else
    agent-browser "$@"
  fi
}

if [ -z "${BROWSER_STUB:-}" ] && [ "$mode" = local ]; then
  command -v agent-browser >/dev/null || {
    echo "mail-atlas-site: agent-browser not on PATH — install it, do not skip silently" >&2
    echo "mail-atlas-site: or run with CLANKER_BROWSER=1 to use clanker's browser" >&2
    exit 2
  }
fi

if [ "$mode" = clanker ]; then
  command -v bash >/dev/null
  [ -f "$repo/scripts/task/instabox.sh" ] || {
    echo "mail-atlas-site: scripts/task/instabox.sh is missing" >&2
    exit 2
  }
fi

# reach <command...> — run on clanker over instabox's ssh.
reach() {
  bash "$repo/scripts/task/instabox.sh" ssh clanker "$@"
}

echo "== building the site derivation"
site="$(nix build --no-link --print-out-paths \
  ".#nixosConfigurations.delphi.config.services.nginx.virtualHosts.mail-atlas.root" 2>/dev/null)" || {
  echo "mail-atlas-site: the site derivation did not build" >&2
  exit 1
}

work="$(mktemp -d /tmp/mail-atlas-smoke.XXXXXX)"
remote_dir=""
cleanup() {
  [ -n "${stub_pid:-}" ] && kill "$stub_pid" 2>/dev/null
  # The pidfile the starter wrote, never a pattern: a `pkill -f` here matches
  # the cleanup command's own argv and kills the shell running it.
  if [ -n "$remote_dir" ]; then
    reach "p=\$(cat '$remote_dir/stub.pid' 2>/dev/null); [ -n \"\$p\" ] && kill \"\$p\" 2>/dev/null; chmod -R u+w '$remote_dir' 2>/dev/null; rm -rf '$remote_dir'" >/dev/null 2>&1
  fi
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

# Two letter with tags and one the taxonomy never placed: the untagged chip needs
# both kinds in the same page, and the graph needs a tag-hub with neighbours.
ROWS = [
    {"id": 1, "messageId": "m1", "sender": "GitHub <noreply@github.com>",
     "subject": "CI failure on main", "sentAt": "2026-11-26T09:00:00Z",
     "snippet": "build failed", "score": 0.9, "box": "inbox",
     "tags": ["ci", "github"], "categories": []},
    {"id": 2, "messageId": "m2", "sender": "Kleinanzeigen <noreply@mail.kleinanzeigen.de>",
     "subject": "your ad expires today", "sentAt": "2026-11-25T09:00:00Z",
     "snippet": "renew it", "score": 0.5, "box": "inbox",
     "tags": ["market"], "categories": []},
    {"id": 3, "messageId": "m3", "sender": "Someone <hello@example.com>",
     "subject": "no tag at all", "sentAt": "2026-11-24T09:00:00Z",
     "snippet": "hello", "score": 0.2, "box": "inbox",
     "tags": [], "categories": []},
]

ANSWERS = {
    "/api/atlas-senders": SENDERS,
    "/api/atlas-taxonomy": [],
    "/api/atlas-stats": {"letters": 1178, "inbox": 1178, "queued": 0, "tagged": 1100, "commands": 0},
    "/api/atlas-search": ROWS,
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

if [ "$mode" = clanker ]; then
  # clanker needs the bytes and the page; its browser cannot see this host's
  # loopback, and this host is not on clanker's tailnet.
  remote_dir="$(reach 'd=$(mktemp -d /data/tmp/mail-atlas-smoke.XXXXXX) && mkdir -p "$d/site" && printf %s "$d"' 2>/dev/null)" || {
    echo "mail-atlas-site: could not make a work dir on clanker" >&2
    exit 1
  }
  [ -n "$remote_dir" ] || {
    echo "mail-atlas-site: clanker returned no work dir" >&2
    exit 1
  }
  # A starter that records its own pid: `setsid -f` returns at once, so `$!` on
  # this side is the fork that already exited, and a `pkill -f` cleanup would
  # match the cleanup command itself. The pidfile is the only name that is true.
  cat >"$work/start.sh" <<'SH'
#!/usr/bin/env bash
here=$(cd "$(dirname "$0")" && pwd)
echo $$ >"$here/stub.pid"
exec python3 "$here/stub.py" "$here/site" "$1" </dev/null >"$here/stub.log" 2>&1
SH

  echo "== copying the site + stub to clanker:$remote_dir"
  tar -C "$site" -cf - . | reach "tar -C '$remote_dir/site' -xf -" || {
    echo "mail-atlas-site: the site did not copy to clanker" >&2
    exit 1
  }
  # The store's files are read-only and would be undeletable there; a copy owes
  # the host a writable directory it can clean up.
  reach "chmod -R u+w '$remote_dir'" >/dev/null 2>&1
  reach "cat > '$remote_dir/stub.py'" <"$work/stub.py" || {
    echo "mail-atlas-site: the stub did not copy to clanker" >&2
    exit 1
  }
  reach "cat > '$remote_dir/start.sh' && chmod +x '$remote_dir/start.sh'" <"$work/start.sh" || {
    echo "mail-atlas-site: the starter did not copy to clanker" >&2
    exit 1
  }
fi

port="$(python3 - <<'PY'
import random
print(random.randint(30000, 39000))
PY
)"

if [ "$mode" = clanker ]; then
  # A plain `&` keeps the ssh channel open until the stub dies (the session
  # waits on it), which reads as a hang; `setsid -f` forks and returns.
  reach "setsid -f bash '$remote_dir/start.sh' $port" >/dev/null 2>&1
  # One remote wait, not forty round trips: each instabox call costs ~2s.
  if ! reach "for i in \$(seq 1 40); do curl -sf -o /dev/null 'http://127.0.0.1:$port/api/atlas-stats' && exit 0; sleep 0.25; done; exit 1" >/dev/null 2>&1; then
    echo "mail-atlas-site: the stub on clanker did not answer on $port" >&2
    reach "cat '$remote_dir/stub.log' 2>/dev/null" >&2
    exit 1
  fi
else
  python3 "$work/stub.py" "$site" "$port" &
  stub_pid=$!
  for _ in $(seq 1 40); do
    curl -sf -o /dev/null "http://127.0.0.1:$port/api/atlas-stats" && break
    sleep 0.1
  done
fi

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
  // Triage and cluster first, so the drawer's query does not colour the state
  // these assertions read.
  const chips = () => [...document.querySelectorAll("#chips .chip")];
  const chipFor = (text) => chips().find((chip) => chip.textContent.trim().startsWith(text));
  const letters = () => [...document.querySelectorAll("#results li.letter")];
  await until(() => letters().length === 3);
  out.loaded = letters().length;
  out.untaggedChip = chipFor("untagged")?.textContent.trim() || "";
  chipFor("untagged")?.click();
  await until(() => letters().length === 1);
  out.untaggedRows = letters().map((li) => li.textContent.trim());
  out.untaggedPressed = chipFor("× untagged")?.getAttribute("aria-pressed") || "";
  chipFor("× untagged")?.click();
  await until(() => letters().length === 3);
  out.afterClear = letters().length;

  const canvas = document.getElementById("atlas-graph");
  const hub = document.querySelector("#view-tags .vt");
  out.hub = hub?.textContent.trim() || "";
  if (hub) {
    hub.dispatchEvent(new MouseEvent("mouseenter"));
    await new Promise((r) => setTimeout(r, 150));
    out.focus = canvas?.dataset.focus || "";
    out.cluster = canvas?.dataset.cluster || "";
    hub.dispatchEvent(new MouseEvent("mouseleave"));
    await new Promise((r) => setTimeout(r, 80));
    out.focusAfter = canvas?.dataset.focus || "";
  }

  const form = document.getElementById("search-form");
  const q = document.getElementById("q");
  q.value = "invoices";
  form.requestSubmit();
  // The chip for the query in flight is filtered out (a suggestion of what you
  // already typed is noise), so the stored list is what proves the search ran.
  await until(() => (localStorage.getItem("atlas.recent") || "").includes("invoices"));
  q.value = "";
  form.requestSubmit();
  await until(() => chips().some((c) => c.textContent.trim() === "invoices"));
  out.chipLabels = [...document.querySelectorAll("#chips .label")].map((l) => l.textContent.trim());
  out.recent = chips().map((c) => c.textContent.trim());

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

if [ -z "${BROWSER_STUB:-}" ]; then
  echo "== driving a browser against $site"
else
  echo "== driving the stub browser against $site"
fi
browser open "http://127.0.0.1:$port/" >/dev/null 2>&1
if [ -n "${BROWSER_STUB:-}" ] || [ "$mode" = clanker ]; then
  # `instabox.sh exec` hands the command to an API, so nothing can be piped
  # into it: the script travels as one argv, which the wrapper quotes.
  got="$(browser eval "$(cat "$work/probe.js")" 2>/dev/null)"
else
  got="$(browser eval --stdin <"$work/probe.js" 2>/dev/null)"
fi
# An answer ends with a blank line; taking `tail -1` would read that blank.
got="$(printf '%s\n' "$got" | awk 'NF' | tail -1)"

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
if data.get("loaded") != 3:
    fails.append(f"expected 3 letters on the first page, saw {data.get('loaded')}")
if "untagged" not in (data.get("untaggedChip") or ""):
    fails.append(f"no untagged chip: {data.get('untaggedChip')!r}")
if data.get("untaggedRows") and len(data["untaggedRows"]) != 1:
    fails.append(f"the untagged view kept {len(data['untaggedRows'])} rows: {data['untaggedRows']}")
elif data.get("untaggedRows") and "no tag at all" not in " ".join(data["untaggedRows"]):
    fails.append(f"the untagged view kept the wrong row: {data['untaggedRows']}")
if data.get("untaggedPressed") != "true":
    fails.append(f"the untagged chip does not read as pressed: {data.get('untaggedPressed')!r}")
if data.get("afterClear") != 3:
    fails.append(f"clearing the untagged chip did not restore the page: {data.get('afterClear')}")
if not (data.get("focus") or "").startswith("tag:"):
    fails.append(f"a rail tag did not focus its cluster: {data.get('focus')!r}")
if int(data.get("cluster") or 0) < 2:
    fails.append(f"the focused cluster has no neighbours: {data.get('cluster')!r}")
if data.get("focusAfter") != "":
    fails.append(f"the cluster stayed lit after the pointer left: {data.get('focusAfter')!r}")
if "recent" not in (data.get("chipLabels") or []):
    fails.append(f"no recent-queries row: chips {data.get('recent')} labels {data.get('chipLabels')}")
if "invoices" not in (data.get("recent") or []):
    fails.append(f"the last query is not offered back: {data.get('recent')}")
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
print(
    f"PASS sources drawer: {data['rows']} rows, first {data['domains'][0]}, click searched {data['q']}"
)
print(
    f"PASS triage + cluster: untagged kept {len(data['untaggedRows'])} of {data['loaded']}, "
    f"hub {data['hub']} lit {data['cluster']} nodes, recent {data['recent']}"
)
PY
