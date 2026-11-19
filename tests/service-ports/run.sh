#!/usr/bin/env bash
# Regression fixture for `checks:services:ports` (scripts/task/service-port-claims.sh).
# Each case is a temp inventory; the gate must fail on the two ways a record can
# lie (wrong number, no prose) and pass on the three ways it can be honest.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
gate="$repo/scripts/task/service-port-claims.sh"
[ -f "$gate" ] || { echo "fixture: $gate missing" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0
cases=0

run() { # name want_rc needle toml
  local name="$1" want="$2" needle="$3" body="$4" file out rc
  cases=$((cases + 1))
  file="$tmp/case${cases}.toml"
  printf '%s\n' "$body" >"$file"
  out="$(INVENTORY="$file" bash "$gate" 2>&1)"
  rc=$?
  if [ "$rc" != "$want" ]; then
    echo "FAIL ${name}: exit ${rc}, want ${want}"
    printf '%s\n' "$out" | sed 's/^/     /'
    fail=1
    return
  fi
  if [ -n "$needle" ] && ! grep -qF -- "$needle" <<<"$out"; then
    echo "FAIL ${name}: output lacks '${needle}'"
    printf '%s\n' "$out" | sed 's/^/     /'
    fail=1
    return
  fi
  echo "ok   ${name} (exit ${rc})"
}

run "record port the prose states passes" 0 "PASS: 1 ported" '
[hosts.a.software]
key_services = ["Thing (:5000)"]
services = [{ name = "thing", port = 5000 }]'

run "prose port written as words passes" 0 "PASS: 1 ported" '
[hosts.a.software]
key_services = ["OpenSSH daemon on port 8022"]
services = [{ name = "sshd", port = 8022 }]'

run "record port absent from prose fails" 1 "prose does not state it" '
[hosts.a.software]
key_services = ["Thing (:5000)"]
services = [{ name = "thing", port = 5001 }]'

run "boundary: 443 is not satisfied by :8443" 1 "prose does not state it" '
[hosts.a.software]
key_services = ["Harness (:8443)"]
services = [{ name = "nginx", port = 443 }]'

run "host with a ported record but no prose fails" 1 "no prose" '
[hosts.a.software]
services = [{ name = "thing", port = 5000 }]'

run "portless records are not judged" 0 "PASS: 1 ported" '
[hosts.a.software]
key_services = ["Docker", "Thing (:5000)"]
services = [{ name = "docker" }, { name = "thing", port = 5000 }]'

run "nothing to check is not a pass" 2 "no ported service records" '
[hosts.a.software]
key_services = ["Docker"]
services = [{ name = "docker" }]'

echo "service-ports fixture: ${cases} cases"
[ "$fail" = 0 ] || exit 1
