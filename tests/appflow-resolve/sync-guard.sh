#!/usr/bin/env bash
# Fixture for the sync.py write guard — the path `task agents:apps:set` takes.
# Offline: APPFLOW_ROWS stands in for the archive, no call reaches the network.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cat >"$work/rows.json" <<'JSON'
[{"id":"open-row","company":"Acme","role":"SRE","status":"Packet ready — nothing sent","stage":"prep"}]
JSON
export APPFLOW_ROWS="$work/rows.json"
export APPS_DB_WRITE_LOG="$work/writes.log"
unset APPS_DB_WRITE_MAX || true

python3 - "$root/modules/plugins/appflow/sync.py" "$work" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("appflow_sync", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
work = sys.argv[2]
fail = 0
def check(name, got, want):
    global fail
    print(f"  {'ok  ' if got == want else 'FAIL'} {name}" + ("" if got == want else f" (got {got}, wanted {want})"))
    if got != want: fail = 1

fp = m.write_fingerprint("Packet ready — nothing sent")
check("fingerprint is stable and 12 hex", (len(fp), fp == m.write_fingerprint("Packet ready — nothing sent")), (12, True))
check("no expectation is refused", m.guard_write("http://127.0.0.1:9", "open-row", "", "", False), 2)
check("a stage mismatch is refused", m.guard_write("http://127.0.0.1:9", "open-row", "other", "", False), 4)
check("a stale fingerprint is refused", m.guard_write("http://127.0.0.1:9", "open-row", "", "000000000000", False), 4)
check("the right fingerprint passes", m.guard_write("http://127.0.0.1:9", "open-row", "", fp, False), 0)
check("the right stage passes", m.guard_write("http://127.0.0.1:9", "open-row", "prep", "", False), 0)
check("an unknown row is refused", m.guard_write("http://127.0.0.1:9", "nope", "prep", "", False), 2)
check("force skips the expectation", m.guard_write("http://127.0.0.1:9", "open-row", "", "", True), 0)

log = f"{work}/ceiling.log"
open(log, "w").write("\n".join(f"{int(__import__('time').time())} id-{i}" for i in range(51)) + "\n")
__import__("os").environ["APPS_DB_WRITE_LOG"] = log
check("a runaway loop is refused", m.guard_write("http://127.0.0.1:9", "open-row", "prep", "", False), 5)
check("force overrides the ceiling", m.guard_write("http://127.0.0.1:9", "open-row", "prep", "", True), 0)
print("sync guard fixture: every case holds" if not fail else "sync guard fixture: a case does not hold")
sys.exit(fail)
PY
