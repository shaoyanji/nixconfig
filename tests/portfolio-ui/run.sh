#!/usr/bin/env bash
# Render the job-db-scraper and private-deals pages and assert their controls.
#
# The Go services embed `web/` byte for byte, so serving the source directory is
# the packaged page — no derivation to build and nothing to get stale. Each app
# gets its own stub API on its own port, because `app.js` calls absolute `/api/…`
# paths and the two pages must not share an origin.
#
# Browser backend:
#   default            `agent-browser` on this host; exit 2 when it is missing
#   CLANKER_BROWSER=1  the pages and stubs are copied to clanker, served on its
#                      loopback, and driven by its browser via
#                      `scripts/task/clanker-browser.sh`
#   BROWSER_STUB=path  replace the browser entirely (see browser-stub/run.sh)
#
# Exit: 0 every assertion holds, 1 one does not, 2 the fixture cannot run.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
cd "$repo" || exit 2

mode=local
case "${CLANKER_BROWSER:-}" in
  1) mode=clanker ;;
  0 | "") ;;
  *)
    echo "portfolio-ui: CLANKER_BROWSER takes 0 or 1, not $CLANKER_BROWSER" >&2
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
    echo "portfolio-ui: agent-browser not on PATH — install it, do not skip silently" >&2
    echo "portfolio-ui: or run with CLANKER_BROWSER=1 to use clanker's browser" >&2
    exit 2
  }
fi

reach() {
  bash "$repo/scripts/task/instabox.sh" ssh clanker "$@"
}

jobs_web="$repo/modules/services/job-db-scraper/web"
deals_web="$repo/modules/services/private-deals/web"
for dir in "$jobs_web" "$deals_web"; do
  [ -f "$dir/index.html" ] || {
    echo "portfolio-ui: $dir has no index.html" >&2
    exit 2
  }
done

# Canned mode: the fixture supplies what the probes would have said, and the
# assertions run exactly as they do against a browser — no server, no Chrome.
if [ -n "${BROWSER_STUB:-}" ] && [ -n "${BROWSER_STUB_PAYLOAD:-}" ]; then
  payload="$(python3 - "$BROWSER_STUB_PAYLOAD" <<'PY'
import json, pathlib, sys

dir = pathlib.Path(sys.argv[1])
def read(name, default):
    path = dir / name
    return json.loads(path.read_text()) if path.exists() else default

document = {
    "jobs": read("jobs.json", {}),
    "deals": read("deals.json", {}),
    "log": {"jobs": read("log-jobs.json", []), "deals": read("log-deals.json", [])},
}
print(json.dumps(document))
PY
)"
  printf '%s' "$payload" | python3 "$here/verify.py"
  exit $?
fi

work="$(mktemp -d /tmp/portfolio-ui.XXXXXX)"
remote_dir=""
local_pids=()
cleanup() {
  for pid in "${local_pids[@]:-}"; do
    [ -n "$pid" ] && kill "$pid" 2>/dev/null
  done
  if [ -n "$remote_dir" ]; then
    reach "for f in '$remote_dir'/jobs.pid '$remote_dir'/deals.pid; do p=\$(cat \$f 2>/dev/null); [ -n \"\$p\" ] && kill \"\$p\" 2>/dev/null; done; chmod -R u+w '$remote_dir' 2>/dev/null; rm -rf '$remote_dir'" >/dev/null 2>&1
  fi
  rm -rf "$work"
}
trap cleanup EXIT

cat >"$work/stub.py" <<'PY'
import json, sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit, parse_qs

ROOT, PORT, APP = sys.argv[1], int(sys.argv[2]), sys.argv[3]
WRITES = []
NOW = "2026-11-26T10:00:00Z"

JOBS = [
    {"id": 1, "title": "Platform Engineer", "company": "ACME", "location": "Berlin",
     "source": "ashby", "stage": "applied", "score": 88, "remote": True,
     "last_seen": NOW, "url": "https://acme.example/jobs/1",
     "description": "Own the platform.", "tags": ["k8s"], "lanes": ["platform"],
     "posted_at": "2026-11-20T09:00:00Z", "seen_count": 2},
    {"id": 2, "title": "Site Reliability Engineer", "company": "Globex",
     "location": "Remote", "source": "greenhouse", "stage": "saved", "score": 74,
     "remote": True, "last_seen": NOW, "url": "https://globex.example/jobs/2",
     "description": "Keep it up.", "tags": [], "lanes": ["sre"],
     "posted_at": "2026-11-22T09:00:00Z", "seen_count": 1},
]
NOTES = [{"note": "recruiter call", "created_at": NOW}]
HISTORY = [{"from_stage": "saved", "to_stage": "applied", "note": "moved by hand", "created_at": NOW}]

DEAL_ONE = {"id": 1, "title": "SSD 2TB", "merchant": "ACME", "source": "techbargains",
            "price": 199, "list_price": 249, "discount_pct": 20, "currency": "EUR",
            "category": "storage", "url": "https://acme.example/ssd",
            "snippet": "Cheapest this week", "description": "Fast NVMe.",
            "seen_count": 3, "last_seen": NOW}
DEAL_TWO = {"id": 2, "title": "Monitor 27in", "merchant": "Globex", "source": "techbargains",
            "price": 249, "currency": "EUR", "category": "display",
            "url": "https://globex.example/monitor", "snippet": "4K panel",
            "description": "IPS.", "seen_count": 1, "last_seen": NOW}


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def send_json(self, payload, status=200):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parts = urlsplit(self.path)
        path, query = parts.path, parse_qs(parts.query)
        if path == "/__log":
            return self.send_json(WRITES)
        if path == "/api/health":
            return self.send_json({"ok": True, "service": "job-db-scraper" if APP == "jobs" else "private-deals"})
        if APP == "jobs":
            if path == "/api/stats":
                return self.send_json({"active_postings": 12, "companies": 5, "remote": 7, "last_7_days": 9})
            if path == "/api/analytics":
                return self.send_json({
                    "active": 12, "avg_score": 72, "remote": 7, "unscored": 1,
                    "companies": [{"key": "acme", "name": "ACME", "postings": 3, "avg_score": 70}],
                    "lanes": [{"name": "platform", "postings": 2, "max_score": 88}],
                    "locations": [{"name": "Berlin", "count": 4}],
                    "sources": [{"name": "ashby", "count": 9}],
                    "score_bands": [{"band": "80+", "count": 3}],
                })
            if path == "/api/sources":
                return self.send_json({"configured": ["ashby"],
                                       "states": [{"source": "ashby", "postings": 9, "last_status": "ok"}]})
            if path == "/api/runs":
                return self.send_json({"runs": [{"source": "ashby", "status": "ok", "inserted": 9,
                                                 "updated": 1, "fetched": 10, "started_at": NOW}]})
            if path == "/api/scrape":
                return self.send_json({"running": False, "message": "idle"})
            if path == "/api/postings":
                stage = (query.get("stage") or [""])[0]
                rows = [j for j in JOBS if not stage or j["stage"] == stage]
                return self.send_json({"items": rows, "total": len(rows), "limit": 20, "offset": 0})
            if path.startswith("/api/postings/") and path.count("/") == 3:
                ident = int(path.rsplit("/", 1)[1])
                job = next((j for j in JOBS if j["id"] == ident), None)
                if job is None:
                    return self.send_json({"error": "posting not found"}, 404)
                return self.send_json({"posting": job, "stage_history": HISTORY, "notes": NOTES, "similar": []})
        else:
            if path == "/api/stats":
                return self.send_json({"deals": 2, "products": 3, "price_points": 14, "alerts_sent": 1})
            if path == "/api/analytics":
                return self.send_json({
                    "window_days": 30,
                    "history": {"currency": "EUR", "points": 14, "fell": 2, "rose": 0,
                                "avg_price": 199,
                                "daily": [{"min_price": 249}, {"min_price": 199}]},
                    "biggest_drops": [{"name": "SSD 2TB", "drop_pct": 20, "from": 249, "to": 199,
                                       "currency": "EUR", "points": 3}],
                    "top_discounts": [{"name": "SSD 2TB", "discount_pct": 20, "price": 199, "currency": "EUR"}],
                    "merchants": [{"name": "ACME", "deals": 2, "avg_discount": 15}],
                    "categories": [{"name": "storage", "deals": 1, "max_discount": 20}],
                })
            if path == "/api/deals":
                return self.send_json({"items": [DEAL_ONE, DEAL_TWO], "total": 2})
            if path.startswith("/api/deals/") and path.count("/") == 3:
                ident = int(path.rsplit("/", 1)[1])
                deal = next((d for d in (DEAL_ONE, DEAL_TWO) if d["id"] == ident), DEAL_ONE)
                return self.send_json({"deal": deal, "price_history": [
                    {"price": 249, "currency": "EUR", "captured_at": NOW},
                    {"price": 199, "currency": "EUR", "captured_at": NOW},
                ]})
            if path == "/api/products":
                return self.send_json({"items": [{"id": 1, "name": "SSD 2TB", "merchant": "ACME",
                                                  "current_price": 199, "currency": "EUR",
                                                  "target_price": 180}], "total": 1})
            if path == "/api/watchlists":
                return self.send_json({"items": [{"id": 1, "name": "Storage", "item_count": 2}], "total": 1})
            if path.startswith("/api/watchlists/") and path.endswith("/items"):
                return self.send_json({"items": [], "total": 0})
            if path == "/api/price-events":
                return self.send_json({"items": [{"previous_price": 249, "price": 199, "currency": "EUR",
                                                  "message": "SSD 2TB dropped", "created_at": NOW}]})
            if path == "/api/alerts":
                return self.send_json({"items": [{"deal_id": 1, "status": "sent", "product_name": "SSD 2TB",
                                                  "price": 199, "currency": "EUR", "reason": "target hit",
                                                  "watchlist": "Storage", "attempts": 1}]})
            if path == "/api/sources":
                return self.send_json({"configured": ["techbargains"],
                                       "states": [{"name": "techbargains", "last_status": "ok",
                                                   "total_fetched": 10}]})
            if path == "/api/ingest":
                return self.send_json({"running": False})
            if path == "/api/scrape":
                return self.send_json({"running": False, "message": "idle"})
        if path.startswith("/api/"):
            return self.send_json({"error": "not found"}, 404)
        super().do_GET()

    def do_write(self):
        length = int(self.headers.get("content-length") or 0)
        raw = self.rfile.read(length) if length else b""
        try:
            body = json.loads(raw or b"{}")
        except ValueError:
            body = {"raw": raw.decode("utf-8", "replace")}
        WRITES.append({"method": self.command, "path": urlsplit(self.path).path, "body": body})
        path = urlsplit(self.path).path
        if path == "/api/postings/1/stage":
            JOBS[0]["stage"] = body.get("stage", JOBS[0]["stage"])
            HISTORY.append({"from_stage": "applied", "to_stage": body.get("stage"),
                            "note": "from the page", "created_at": NOW})
            return self.send_json({"posting": JOBS[0]})
        if path == "/api/postings/1/notes":
            NOTES.insert(0, {"note": body.get("note", ""), "created_at": NOW})
            return self.send_json({"note": NOTES[0]})
        if path == "/api/watchlists/poll":
            return self.send_json({"accepted": True})
        if path.endswith("/poll"):
            return self.send_json({"accepted": False})
        return self.send_json({"ok": True})

    do_POST = do_write
    do_PATCH = do_write
    do_DELETE = do_write

    def log_message(self, *args):
        pass


ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
PY

cat >"$work/jobs.js" <<'JS'
(async () => {
  const out = {};
  const until = async (test, ms = 6000) => {
    const deadline = Date.now() + ms;
    while (Date.now() < deadline) {
      if (test()) return true;
      await new Promise((r) => setTimeout(r, 100));
    }
    return false;
  };
  const rows = () => [...document.querySelectorAll("#results article.job")];
  await until(() => rows().length === 2);
  out.loaded = rows().length;
  out.metrics = {};
  for (const id of ["metric-jobs", "metric-companies", "metric-remote", "metric-fresh"]) {
    out.metrics[id] = (document.getElementById(id)?.textContent || "").trim();
  }
  out.exports = [...document.querySelectorAll(".exports a")].map((a) => a.getAttribute("href"));
  out.firstTitle = rows()[0]?.querySelector("h2")?.textContent || "";
  out.stageBadges = rows().map((r) => (r.querySelector(".badge.stage")?.textContent || "").trim());

  rows()[0].querySelector("h2 button").click();
  const dialog = document.getElementById("detail");
  await until(() => dialog.open);
  out.detailOpen = dialog.open;
  out.stageOptions = [...document.querySelectorAll("#stageSelect option")].map((o) => o.value);
  out.noteForm = !!document.getElementById("noteForm");
  out.packetExport = document.querySelector("#detail-body a.api-link")?.getAttribute("href") || "";
  out.journal = [...document.querySelectorAll("#journal .journal-row")].map((r) => r.textContent.trim());

  const select = document.getElementById("stageSelect");
  select.value = "interview";
  document.getElementById("saveStage").click();
  await until(() => (rows()[0]?.querySelector(".badge.stage")?.textContent || "").trim() === "interview");
  out.afterStage = (rows()[0]?.querySelector(".badge.stage")?.textContent || "").trim();

  const field = document.getElementById("noteText");
  field.value = "spoke to the hiring manager";
  document.getElementById("noteForm").requestSubmit();
  await until(() => [...document.querySelectorAll("#journal .journal-row")]
    .some((r) => r.textContent.includes("spoke to the hiring manager")));
  out.journalAfterNote = [...document.querySelectorAll("#journal .journal-row")].map((r) => r.textContent.trim());

  document.getElementById("close-detail").click();
  const filter = document.getElementById("stage");
  filter.value = "interview";
  filter.dispatchEvent(new Event("change"));
  await until(() => rows().length === 1);
  out.filteredRows = rows().length;
  return JSON.stringify(out);
})()
JS

cat >"$work/deals.js" <<'JS'
(async () => {
  const out = {};
  const until = async (test, ms = 6000) => {
    const deadline = Date.now() + ms;
    while (Date.now() < deadline) {
      if (test()) return true;
      await new Promise((r) => setTimeout(r, 100));
    }
    return false;
  };
  const cards = () => [...document.querySelectorAll("#deals article.deal")];
  const toast = () => (document.getElementById("toast")?.textContent || "").trim();
  await until(() => cards().length === 2 && document.querySelector("#analytics svg.spark"));
  out.loaded = cards().length;
  out.stats = [...document.querySelectorAll("#stats .stat strong")].map((el) => el.textContent.trim());
  out.exports = [...document.querySelectorAll("a[href^='/api/']")].map((a) => a.getAttribute("href"));
  out.spark = !!document.querySelector("#analytics svg.spark");
  out.figures = (document.querySelector("#analytics .analytics-figures")?.textContent || "").replace(/\s+/g, " ").trim();
  out.window = (document.getElementById("analyticsWindow")?.textContent || "").trim();
  out.drops = [...document.querySelectorAll("#priceEvents .alert")].map((r) => r.textContent.trim());
  out.alerts = document.querySelectorAll("#alerts .alert").length;

  document.getElementById("pollWatchlists").click();
  await until(() => toast().includes("Watchlist poll started"));
  out.toastAll = toast();
  const one = document.querySelector("#watchlists .poll-list");
  if (one) one.click();
  await until(() => toast().includes("already running"));
  out.toastOne = toast();

  cards()[0].querySelector(".detail-button").click();
  const dialog = document.getElementById("detailDialog");
  await until(() => dialog.open);
  out.detailOpen = dialog.open;
  out.historyBars = document.querySelectorAll("#detail .history .bar").length;
  return JSON.stringify(out);
})()
JS

port_a=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
port_b=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')

if [ "$mode" = clanker ]; then
  cat >"$work/start.sh" <<'SH'
#!/usr/bin/env bash
# Records its own pid: `setsid -f` returns at once, so `$!` here is a fork that
# already exited, and a `pkill -f` cleanup would match its own argv.
here=$(cd "$(dirname "$0")" && pwd)
echo $$ >"$here/$1.pid"
exec python3 "$here/stub.py" "$here/$1-web" "$2" "$1" </dev/null >"$here/$1.log" 2>&1
SH
  remote_dir="$(reach 'd=$(mktemp -d /data/tmp/portfolio-ui.XXXXXX) && printf %s "$d"' 2>/dev/null)" || {
    echo "portfolio-ui: could not make a work dir on clanker" >&2
    exit 1
  }
  [ -n "$remote_dir" ] || {
    echo "portfolio-ui: clanker returned no work dir" >&2
    exit 1
  }
  echo "== copying the pages and the stub to clanker:$remote_dir"
  for pair in "jobs:$jobs_web" "deals:$deals_web"; do
    name=${pair%%:*}
    dir=${pair#*:}
    tar -C "$dir" -cf - . | reach "mkdir -p '$remote_dir/$name-web' && tar -C '$remote_dir/$name-web' -xf -" || {
      echo "portfolio-ui: $name did not copy to clanker" >&2
      exit 1
    }
  done
  reach "cat > '$remote_dir/stub.py'" <"$work/stub.py" || exit 1
  reach "cat > '$remote_dir/start.sh' && chmod +x '$remote_dir/start.sh'" <"$work/start.sh" || exit 1
  # The store's files are read-only and would be undeletable there.
  reach "chmod -R u+w '$remote_dir'" >/dev/null 2>&1
  reach "setsid -f bash '$remote_dir/start.sh' jobs $port_a" >/dev/null 2>&1
  reach "setsid -f bash '$remote_dir/start.sh' deals $port_b" >/dev/null 2>&1
  if ! reach "for i in \$(seq 1 60); do curl -sf -o /dev/null 'http://127.0.0.1:$port_a/api/health' && curl -sf -o /dev/null 'http://127.0.0.1:$port_b/api/health' && exit 0; sleep 0.25; done; exit 1" >/dev/null 2>&1; then
    echo "portfolio-ui: a stub on clanker did not answer ($port_a, $port_b)" >&2
    reach "cat '$remote_dir/jobs.log' '$remote_dir/deals.log' 2>/dev/null" >&2
    exit 1
  fi
else
  python3 "$work/stub.py" "$jobs_web" "$port_a" jobs >"$work/jobs.log" 2>&1 &
  local_pids+=("$!")
  python3 "$work/stub.py" "$deals_web" "$port_b" deals >"$work/deals.log" 2>&1 &
  local_pids+=("$!")
  for _ in $(seq 1 60); do
    curl -sf -o /dev/null "http://127.0.0.1:$port_a/api/health" &&
      curl -sf -o /dev/null "http://127.0.0.1:$port_b/api/health" && break
    sleep 0.1
  done
fi

get_log() {
  if [ "$mode" = clanker ]; then
    reach "curl -sS -m 10 'http://127.0.0.1:$1/__log'" 2>/dev/null
  else
    curl -sS -m 10 "http://127.0.0.1:$1/__log" 2>/dev/null
  fi
}

run_probe() {
  local name=$1 port=$2 script=$3
  echo "== driving a browser against the $name page"
  if [ -z "${BROWSER_STUB:-}" ]; then
    browser open "http://127.0.0.1:$port/" >/dev/null 2>&1
  fi
  if [ -n "${BROWSER_STUB:-}" ] || [ "$mode" = clanker ]; then
    # `instabox.sh exec` hands the command to an API, so nothing can be piped in:
    # the script travels as one argv, which the wrapper quotes.
    browser eval "$(cat "$script")" 2>/dev/null
  else
    browser eval --stdin <"$script" 2>/dev/null
  fi
}

# An answer ends with a blank line; the JSON is the last non-empty line.
jobs_raw="$(run_probe jobs "$port_a" "$work/jobs.js" | awk 'NF' | tail -1)"
deals_raw="$(run_probe deals "$port_b" "$work/deals.js" | awk 'NF' | tail -1)"

payload="$(python3 - "$jobs_raw" "$deals_raw" "$(get_log "$port_a")" "$(get_log "$port_b")" <<'PY'
import json, sys

jobs_raw, deals_raw, jobs_log, deals_log = sys.argv[1:5]


def unwrap(raw, what):
    if not raw.strip():
        print(f"portfolio-ui: the {what} probe returned nothing", file=sys.stderr)
        sys.exit(1)
    value = json.loads(raw)
    if isinstance(value, str):
        value = json.loads(value)
    return value


def writes(raw):
    if not raw.strip():
        return []
    try:
        return json.loads(raw)
    except ValueError:
        return []


print(json.dumps({
    "jobs": unwrap(jobs_raw, "jobs"),
    "deals": unwrap(deals_raw, "deals"),
    "log": {"jobs": writes(jobs_log), "deals": writes(deals_log)},
}))
PY
)"
[ -n "$payload" ] || {
  echo "portfolio-ui: the probes did not come back as one document" >&2
  exit 1
}
printf '%s' "$payload" | python3 "$here/verify.py"
