#!/usr/bin/env bash
# Fixture for the apps-db.sh write guard: a write must name the row it expects,
# and a loop past the ceiling is refused by count. Offline — APPFLOW_ROWS stands
# in for the archive, --dry never posts, and APPFLOW_API points at a closed port
# so a case cannot pass by reaching the hub.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
db="$root/scripts/task/apps-db.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export APPFLOW_ROWS="$work/rows.json"
export APPS_DB_WRITE_LOG="$work/writes.log"
export APPFLOW_API="http://127.0.0.1:9"
unset APPS_DB_WRITE_MAX || true

cat >"$APPFLOW_ROWS" <<'JSON'
[{"id":"open-row","company":"Acme","role":"SRE","status":"Packet ready — nothing sent","stage":"prep"},
 {"id":"dead-row","company":"Beta","role":"DevOps","status":"Closed 2026-11-24","stage":"other"}]
JSON

hash=$(printf '%s' 'Packet ready — nothing sent' | sha256sum | cut -c1-12)
fail=0
note() { printf '  %-4s %s\n' "$1" "$2"; }
check() { if [ "$2" = "$3" ]; then note ok "$1"; else note FAIL "$1 (got $2, wanted $3)"; fail=1; fi; }
run() { set +e; out=$("$db" update "$@" 2>&1); rc=$?; set -e; }

run open-row --status "Closed 2026-11-24"
check "an unguarded write is refused" "$rc" 2
case $out in *--expect-stage*--if-status*) note ok "the refusal names both guards" ;; *) note FAIL "the refusal names both guards: $out" ; fail=1 ;; esac
case $out in *--expect-stage\ prep*) note ok "the refusal quotes the row's stage" ;; *) note FAIL "the refusal quotes the row's stage: $out" ; fail=1 ;; esac

run open-row --status "Closed" --expect-stage other
check "a stage mismatch is refused" "$rc" 4

run open-row --status "Closed" --if-status 000000000000
check "a stale status fingerprint is refused" "$rc" 4

run open-row --status "Closed 2026-11-24 (lead review): dead" --if-status "$hash" --dry
check "a matching fingerprint passes" "$rc" 0
case $out in *'"stage": "other"'*) note ok "the payload carries the derived stage" ;; *) note FAIL "the payload carries the derived stage: $out" ; fail=1 ;; esac
check "a dry run records no write" "$( [ -f "$APPS_DB_WRITE_LOG" ] && wc -l <"$APPS_DB_WRITE_LOG" | tr -d ' ' || echo 0 )" 0

run dead-row --status "Closed again" --force --dry
check "--force alone is accepted" "$rc" 0

run nope --status "Closed" --force --dry
check "an unknown row exits 1" "$rc" 1

# --- upsert: the widest write gets the same expectation ---------------------
upsert_run() { set +e; out=$("$db" upsert "$@" 2>&1); rc=$?; set -e; }
: >"$APPS_DB_WRITE_LOG"
cat >"$work/existing.json" <<'JSON'
{"id":"open-row","company":"Acme","role":"SRE","status":"Closed 2026-11-24 (lead review): dead","stage":"other"}
JSON
upsert_run "$work/existing.json" --dry
check "an upsert of an existing row without a guard is refused" "$rc" 2
upsert_run "$work/existing.json" --if-status 000000000000 --dry
check "an upsert with a stale fingerprint is refused" "$rc" 4
upsert_run "$work/existing.json" --if-status "$hash" --dry
check "an upsert with the right fingerprint passes" "$rc" 0
cat >"$work/new.json" <<'JSON'
{"id":"brand-new","company":"New Co","role":"SRE","status":"lead: scouted","stage":"lead"}
JSON
upsert_run "$work/new.json" --dry
check "a new row needs --expect-absent" "$rc" 2
upsert_run "$work/new.json" --expect-absent --dry
check "--expect-absent allows a new row" "$rc" 0
upsert_run "$work/new.json" --force --dry
check "--force still allows a new row" "$rc" 0

# --- add: a new lead needs nothing, but an existing id is an overwrite ------
add_run() { set +e; out=$("$db" add "$@" 2>&1); rc=$?; set -e; }
: >"$APPS_DB_WRITE_LOG"
add_run --id brand-new-2 --company "New Co" --role SRE --dry
check "add of a new id needs no guard" "$rc" 0
add_run --id open-row --company Acme --role SRE --status "Closed" --dry
check "add of an existing id without a guard is refused" "$rc" 2
case $out in *--if-status*) note ok "the add refusal names the fingerprint flag" ;; *) note FAIL "the add refusal names the fingerprint flag: $out" ; fail=1 ;; esac
add_run --id open-row --company Acme --role SRE --status "Closed" --if-status 000000000000 --dry
check "add with a stale fingerprint is refused" "$rc" 4
add_run --id open-row --company Acme --role SRE --status "Closed" --expect-absent --dry
check "add declaring an existing row new is refused" "$rc" 2
add_run --id open-row --company Acme --role SRE --status "Closed" --if-status "$hash" --dry
check "add with the right fingerprint passes" "$rc" 0
add_run --id open-row --company Acme --role SRE --status "Closed" --force --dry
check "add with --force overwrites" "$rc" 0
check "no add case wrote" "$( [ -f "$APPS_DB_WRITE_LOG" ] && wc -l <"$APPS_DB_WRITE_LOG" | tr -d ' ' || echo 0 )" 0

now=$(date +%s)
for i in $(seq 1 51); do printf '%s id-%s\n' "$now" "$i"; done >"$APPS_DB_WRITE_LOG"
run open-row --status "Closed" --expect-stage prep --dry
check "a runaway loop is refused" "$rc" 5
case $out in *"loop, not a decision"*) note ok "the refusal says why" ;; *) note FAIL "the refusal says why" ; fail=1 ;; esac

printf '%s old\n' "$((now - 3600))" >"$APPS_DB_WRITE_LOG"
run open-row --status "Closed" --expect-stage prep --dry
check "entries outside the window do not count" "$rc" 0

for i in $(seq 1 51); do printf '%s id-%s\n' "$now" "$i"; done >"$APPS_DB_WRITE_LOG"
run open-row --status "Closed" --expect-stage prep --force --dry
check "--force overrides the ceiling" "$rc" 0

if [ "$fail" = 1 ]; then echo "apps-db guard fixture: a case does not hold"; exit 1; fi
echo "apps-db guard fixture: every case holds"
